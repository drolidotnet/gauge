import Foundation
import XCTest
@testable import Gauge

final class CNNFearGreedClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testDecodesNineRawObjectsIntoSevenOrderedIndicators() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = try makeClient().decode(Self.payload, fetchedAt: fetchedAt)

        XCTAssertEqual(snapshot.currentScore, 49.6, accuracy: 0.0001)
        XCTAssertEqual(snapshot.displayScore, 50)
        XCTAssertEqual(snapshot.currentRating, .neutral)
        XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
        XCTAssertEqual(
            snapshot.sourceUpdatedAt.timeIntervalSince1970,
            1_783_904_523.456,
            accuracy: 0.001
        )
        XCTAssertEqual(snapshot.indicators.map(\.kind), GaugeIndicatorKind.allCases)
        XCTAssertEqual(snapshot.indicators.flatMap(\.series).count, 9)
        XCTAssertEqual(snapshot.indicator(for: .marketMomentum)?.series.count, 2)
        XCTAssertEqual(snapshot.indicator(for: .marketVolatility)?.series.count, 2)
    }

    func testUsesTopLevelScoreAndRatingRatherThanRawPointValues() throws {
        let snapshot = try makeClient().decode(Self.payload)
        let strength = try XCTUnwrap(snapshot.indicator(for: .stockPriceStrength))

        XCTAssertEqual(strength.score, 62.4, accuracy: 0.0001)
        XCTAssertEqual(strength.displayScore, 62)
        XCTAssertEqual(strength.rating, .greed)
        XCTAssertEqual(strength.series.first?.points.first?.value, 1_234.5)
        XCTAssertNotEqual(strength.score, strength.series.first?.points.first?.value)
    }

    func testParsesISOMainTimestampAndEpochMillisecondComponentTimestamp() throws {
        let snapshot = try makeClient().decode(Self.payload)
        let momentum = try XCTUnwrap(snapshot.indicator(for: .marketMomentum))

        XCTAssertEqual(
            snapshot.sourceUpdatedAt.timeIntervalSince1970,
            1_783_904_523.456,
            accuracy: 0.001
        )
        XCTAssertEqual(
            try XCTUnwrap(momentum.sourceUpdatedAt).timeIntervalSince1970,
            1_783_900_000,
            accuracy: 0.001
        )
        XCTAssertEqual(
            try XCTUnwrap(momentum.series.first?.points.first).timestamp.timeIntervalSince1970,
            1_783_897_200,
            accuracy: 0.001
        )
    }

    func testDropsMalformedRawPointsWithoutDroppingSeries() throws {
        let snapshot = try makeClient().decode(Self.payload)
        let strength = try XCTUnwrap(snapshot.indicator(for: .stockPriceStrength))

        XCTAssertEqual(strength.series.count, 1)
        XCTAssertEqual(strength.series[0].points.count, 1)
    }

    func testMissingPairedObjectKeepsAvailableHalf() throws {
        let data = try payload(removing: "market_volatility_vix_50")
        let snapshot = try makeClient().decode(data)
        let volatility = try XCTUnwrap(snapshot.indicator(for: .marketVolatility))

        XCTAssertEqual(volatility.series.map(\.id), ["market_volatility_vix"])
        XCTAssertEqual(volatility.score, 67.8, accuracy: 0.0001)
    }

    func testInvalidComponentScoreDoesNotInvalidateMainIndex() throws {
        let data = try payload(settingScore: 101, for: "stock_price_strength")
        let snapshot = try makeClient().decode(data)

        XCTAssertEqual(snapshot.displayScore, 50)
        XCTAssertNil(snapshot.indicator(for: .stockPriceStrength))
        XCTAssertEqual(snapshot.indicators.count, 6)
    }

    func testInvalidMainScoreAndMalformedJSONFailTheWholeRequest() throws {
        XCTAssertThrowsError(
            try makeClient().decode(payload(settingScore: -1, for: "fear_and_greed"))
        ) { error in
            XCTAssertEqual(error as? CNNFearGreedClientError, .invalidPayload)
        }

        XCTAssertThrowsError(try makeClient().decode(Data("{".utf8))) { error in
            XCTAssertEqual(error as? CNNFearGreedClientError, .invalidPayload)
        }
    }

    func testFetchSendsBrowserHeadersAndFifteenSecondTimeout() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url, CNNFearGreedClient.endpoint)
            XCTAssertEqual(request.timeoutInterval, 15, accuracy: 0.001)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://www.cnn.com")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://www.cnn.com/")
            XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.contains("iPhone") == true)
            XCTAssertTrue(request.value(forHTTPHeaderField: "Accept")?.contains("application/json") == true)
            return (
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json; charset=utf-8"]
                )!,
                Self.payload
            )
        }

        let snapshot = try await makeClient().fetch()

        XCTAssertEqual(snapshot.displayScore, 50)
        XCTAssertEqual(snapshot.indicators.count, 7)
    }

    func testFetchRejectsHTTP418AndUnexpectedContent() async throws {
        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 418,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Self.payload
            )
        }

        do {
            _ = try await makeClient().fetch()
            XCTFail("Expected HTTP 418 to fail")
        } catch {
            XCTAssertEqual(error as? CNNFearGreedClientError, .unsuccessfulStatusCode(418))
        }

        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/html"]
                )!,
                Data("not json".utf8)
            )
        }

        do {
            _ = try await makeClient().fetch()
            XCTFail("Expected HTML to fail")
        } catch {
            XCTAssertEqual(
                error as? CNNFearGreedClientError,
                .unexpectedContentType("text/html")
            )
        }
    }

    func testFetchPropagatesTimeout() async throws {
        MockURLProtocol.handler = { _ in throw URLError(.timedOut) }

        do {
            _ = try await makeClient().fetch()
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
    }

    private func makeClient() -> CNNFearGreedClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return CNNFearGreedClient(
            session: URLSession(configuration: configuration),
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }

    private func payload(removing key: String) throws -> Data {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Self.payload) as? [String: Any]
        )
        object.removeValue(forKey: key)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func payload(settingScore score: Double, for key: String) throws -> Data {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Self.payload) as? [String: Any]
        )
        var metric = try XCTUnwrap(object[key] as? [String: Any])
        metric["score"] = score
        object[key] = metric
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static let payload = Data(
        #"""
        {
          "fear_and_greed": {
            "score": 49.6,
            "rating": "NEUTRAL",
            "timestamp": "2026-07-13T01:02:03.456Z"
          },
          "fear_and_greed_historical": {
            "timestamp": 1783900000000,
            "score": 49.6,
            "rating": "neutral",
            "data": [
              {"x": 1783897200000, "y": 48.4, "rating": "fear"},
              {"x": 1783899900000, "y": 49.6, "rating": "neutral"},
              {"x": 1783900000000, "y": 120, "rating": "extreme greed"}
            ]
          },
          "market_momentum_sp500": {
            "timestamp": 1783900000000,
            "score": 11.2,
            "rating": "extreme fear",
            "data": [{"x": 1783897200000, "y": 5600.25, "rating": "greed"}]
          },
          "market_momentum_sp125": {
            "timestamp": 1783900000000,
            "score": 11.2,
            "rating": "extreme fear",
            "data": [{"x": 1783897200000, "y": 5480.5, "rating": "fear"}]
          },
          "stock_price_strength": {
            "timestamp": 1783900000000,
            "score": 62.4,
            "rating": "greed",
            "data": [
              {"x": 1783897200000, "y": 1234.5, "rating": "extreme fear"},
              {"x": 1783899900000, "y": "bad"},
              null
            ]
          },
          "stock_price_breadth": {
            "timestamp": 1783900000000,
            "score": 53.2,
            "rating": "neutral",
            "data": [{"x": 1783897200000, "y": -245.75}]
          },
          "put_call_options": {
            "timestamp": 1783900000000,
            "score": 42.2,
            "rating": "fear",
            "data": [{"x": 1783897200000, "y": 0.82}]
          },
          "market_volatility_vix": {
            "timestamp": 1783900000000,
            "score": 67.8,
            "rating": "greed",
            "data": [{"x": 1783897200000, "y": 16.15}]
          },
          "market_volatility_vix_50": {
            "timestamp": 1783900000000,
            "score": 67.8,
            "rating": "greed",
            "data": [{"x": 1783897200000, "y": 18.9}]
          },
          "safe_haven_demand": {
            "timestamp": 1783900000000,
            "score": 76.2,
            "rating": "EXTREME_GREED",
            "data": [{"x": 1783897200000, "y": -2.3}]
          },
          "junk_bond_demand": {
            "timestamp": 1783900000000,
            "score": 33.8,
            "rating": "fear",
            "data": [{"x": 1783897200000, "y": 3.12}]
          }
        }
        """#.utf8
    )
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
