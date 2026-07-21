import Foundation

public enum CNNFearGreedClientError: Error, Equatable, LocalizedError, Sendable {
    case invalidResponse
    case unsuccessfulStatusCode(Int)
    case unexpectedContentType(String?)
    case emptyResponse
    case invalidPayload

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "CNN returned a response that was not HTTP."
        case let .unsuccessfulStatusCode(statusCode):
            "CNN returned HTTP status \(statusCode)."
        case let .unexpectedContentType(contentType):
            "CNN returned an unexpected content type: \(contentType ?? "missing")."
        case .emptyResponse:
            "CNN returned an empty response."
        case .invalidPayload:
            "CNN returned data in an unsupported format."
        }
    }
}

/// Fetches and maps CNN's Fear & Greed graph payload into target-shared models.
public final class CNNFearGreedClient: GaugeDataFetching, @unchecked Sendable {
    public static let endpoint = URL(
        string: "https://production.dataviz.cnn.io/index/fearandgreed/graphdata"
    )!

    private let session: URLSession
    private let endpointURL: URL
    private let now: @Sendable () -> Date

    public init(
        session: URLSession = .shared,
        endpoint: URL = CNNFearGreedClient.endpoint,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.session = session
        self.endpointURL = endpoint
        self.now = now
    }

    public func fetch() async throws -> GaugeSnapshot {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 "
                + "Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://www.cnn.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.cnn.com", forHTTPHeaderField: "Origin")

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw CNNFearGreedClientError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw CNNFearGreedClientError.unsuccessfulStatusCode(response.statusCode)
        }

        let mimeType = response.mimeType?.lowercased()
        guard let mimeType,
              mimeType == "application/json"
                || mimeType == "text/json"
                || mimeType.hasSuffix("+json") else {
            throw CNNFearGreedClientError.unexpectedContentType(response.mimeType)
        }
        guard !data.isEmpty else {
            throw CNNFearGreedClientError.emptyResponse
        }

        return try decode(data, fetchedAt: now())
    }

    /// Exposed for deterministic decoding tests and offline fixtures.
    public func decode(_ data: Data, fetchedAt: Date? = nil) throws -> GaugeSnapshot {
        guard !data.isEmpty else {
            throw CNNFearGreedClientError.emptyResponse
        }

        let payload: RootPayload
        do {
            payload = try JSONDecoder().decode(RootPayload.self, from: data)
        } catch {
            throw CNNFearGreedClientError.invalidPayload
        }

        let fetchedAt = fetchedAt ?? now()
        guard let current = payload.current,
              let currentScore = Self.normalizedScore(current.score) else {
            throw CNNFearGreedClientError.invalidPayload
        }

        let sourceUpdatedAt = Self.isoDate(current.timestamp)
            ?? payload.history.flatMap { Self.epochMillisecondsDate($0.timestamp) }
            ?? fetchedAt

        let history = (payload.history?.data ?? []).compactMap { point -> GaugeHistoryPoint? in
            guard let timestamp = Self.epochMillisecondsDate(point.x),
                  let score = Self.normalizedScore(point.y) else {
                return nil
            }
            return GaugeHistoryPoint(
                timestamp: timestamp,
                score: score,
                rating: .normalized(point.rating, fallbackScore: score)
            )
        }

        let definitions: [IndicatorDefinition] = [
            IndicatorDefinition(
                kind: .marketMomentum,
                sources: [
                    SeriesSource(
                        payload: payload.marketMomentumSP500,
                        id: "market_momentum_sp500",
                        displayName: "S&P 500"
                    ),
                    SeriesSource(
                        payload: payload.marketMomentumSP125,
                        id: "market_momentum_sp125",
                        displayName: "125-day average"
                    )
                ]
            ),
            IndicatorDefinition(
                kind: .stockPriceStrength,
                sources: [
                    SeriesSource(
                        payload: payload.stockPriceStrength,
                        id: "stock_price_strength",
                        displayName: "Net new highs/lows"
                    )
                ]
            ),
            IndicatorDefinition(
                kind: .stockPriceBreadth,
                sources: [
                    SeriesSource(
                        payload: payload.stockPriceBreadth,
                        id: "stock_price_breadth",
                        displayName: "Volume summation"
                    )
                ]
            ),
            IndicatorDefinition(
                kind: .putCallOptions,
                sources: [
                    SeriesSource(
                        payload: payload.putCallOptions,
                        id: "put_call_options",
                        displayName: "Put/call ratio"
                    )
                ]
            ),
            IndicatorDefinition(
                kind: .marketVolatility,
                sources: [
                    SeriesSource(
                        payload: payload.marketVolatilityVIX,
                        id: "market_volatility_vix",
                        displayName: "VIX"
                    ),
                    SeriesSource(
                        payload: payload.marketVolatilityVIX50,
                        id: "market_volatility_vix_50",
                        displayName: "50-day average"
                    )
                ]
            ),
            IndicatorDefinition(
                kind: .safeHavenDemand,
                sources: [
                    SeriesSource(
                        payload: payload.safeHavenDemand,
                        id: "safe_haven_demand",
                        displayName: "Stocks minus bonds"
                    )
                ]
            ),
            IndicatorDefinition(
                kind: .junkBondDemand,
                sources: [
                    SeriesSource(
                        payload: payload.junkBondDemand,
                        id: "junk_bond_demand",
                        displayName: "Yield spread"
                    )
                ]
            )
        ]

        return GaugeSnapshot(
            currentScore: currentScore,
            currentRating: .normalized(current.rating, fallbackScore: currentScore),
            sourceUpdatedAt: sourceUpdatedAt,
            history: history,
            indicators: definitions.compactMap(Self.indicator),
            fetchedAt: fetchedAt,
            isStale: false
        )
    }

    private static func indicator(from definition: IndicatorDefinition) -> GaugeIndicator? {
        let availablePayloads = definition.sources.compactMap(\.payload)
        guard let summary = availablePayloads.first(where: {
            normalizedScore($0.score) != nil
        }), let score = normalizedScore(summary.score) else {
            return nil
        }

        let series = definition.sources.compactMap { source -> GaugeSeries? in
            guard let payload = source.payload else { return nil }
            let points = payload.data.compactMap { point -> GaugePoint? in
                guard let timestamp = epochMillisecondsDate(point.x), point.y.isFinite else {
                    return nil
                }
                return GaugePoint(timestamp: timestamp, value: point.y)
            }
            .sorted { $0.timestamp < $1.timestamp }

            return GaugeSeries(
                id: source.id,
                displayName: source.displayName,
                valueFormat: definition.kind.valueFormat,
                points: points
            )
        }

        let sourceUpdatedAt = availablePayloads
            .compactMap { epochMillisecondsDate($0.timestamp) }
            .max()

        return GaugeIndicator(
            kind: definition.kind,
            score: score,
            rating: .normalized(summary.rating, fallbackScore: score),
            sourceUpdatedAt: sourceUpdatedAt,
            series: series,
            isStale: false
        )
    }

    private static func normalizedScore(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...100).contains(value) else { return nil }
        return value
    }

    private static func epochMillisecondsDate(_ value: Double?) -> Date? {
        guard let value, value.isFinite, value > 0 else { return nil }
        let seconds = value / 1_000
        guard seconds.isFinite else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func isoDate(_ value: String?) -> Date? {
        guard let value else { return nil }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}

private struct IndicatorDefinition {
    let kind: GaugeIndicatorKind
    let sources: [SeriesSource]
}

private struct SeriesSource {
    let payload: MetricPayload?
    let id: String
    let displayName: String
}

private struct RootPayload: Decodable {
    let current: CurrentPayload?
    let history: MetricPayload?
    let marketMomentumSP500: MetricPayload?
    let marketMomentumSP125: MetricPayload?
    let stockPriceStrength: MetricPayload?
    let stockPriceBreadth: MetricPayload?
    let putCallOptions: MetricPayload?
    let marketVolatilityVIX: MetricPayload?
    let marketVolatilityVIX50: MetricPayload?
    let safeHavenDemand: MetricPayload?
    let junkBondDemand: MetricPayload?

    enum CodingKeys: String, CodingKey {
        case current = "fear_and_greed"
        case history = "fear_and_greed_historical"
        case marketMomentumSP500 = "market_momentum_sp500"
        case marketMomentumSP125 = "market_momentum_sp125"
        case stockPriceStrength = "stock_price_strength"
        case stockPriceBreadth = "stock_price_breadth"
        case putCallOptions = "put_call_options"
        case marketVolatilityVIX = "market_volatility_vix"
        case marketVolatilityVIX50 = "market_volatility_vix_50"
        case safeHavenDemand = "safe_haven_demand"
        case junkBondDemand = "junk_bond_demand"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        current = try? container.decode(CurrentPayload.self, forKey: .current)
        history = try? container.decode(MetricPayload.self, forKey: .history)
        marketMomentumSP500 = try? container.decode(MetricPayload.self, forKey: .marketMomentumSP500)
        marketMomentumSP125 = try? container.decode(MetricPayload.self, forKey: .marketMomentumSP125)
        stockPriceStrength = try? container.decode(MetricPayload.self, forKey: .stockPriceStrength)
        stockPriceBreadth = try? container.decode(MetricPayload.self, forKey: .stockPriceBreadth)
        putCallOptions = try? container.decode(MetricPayload.self, forKey: .putCallOptions)
        marketVolatilityVIX = try? container.decode(MetricPayload.self, forKey: .marketVolatilityVIX)
        marketVolatilityVIX50 = try? container.decode(MetricPayload.self, forKey: .marketVolatilityVIX50)
        safeHavenDemand = try? container.decode(MetricPayload.self, forKey: .safeHavenDemand)
        junkBondDemand = try? container.decode(MetricPayload.self, forKey: .junkBondDemand)
    }
}

private struct CurrentPayload: Decodable {
    let score: Double?
    let rating: String?
    let timestamp: String?

    enum CodingKeys: CodingKey {
        case score
        case rating
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try? container.decode(Double.self, forKey: .score)
        rating = try? container.decode(String.self, forKey: .rating)
        timestamp = try? container.decode(String.self, forKey: .timestamp)
    }
}

private struct MetricPayload: Decodable {
    let timestamp: Double?
    let score: Double?
    let rating: String?
    let data: [RawPoint]

    enum CodingKeys: CodingKey {
        case timestamp
        case score
        case rating
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try? container.decode(Double.self, forKey: .timestamp)
        score = try? container.decode(Double.self, forKey: .score)
        rating = try? container.decode(String.self, forKey: .rating)
        data = (try? container.decode(LossyArray<RawPoint>.self, forKey: .data).elements) ?? []
    }
}

private struct RawPoint: Decodable {
    let x: Double
    let y: Double
    let rating: String?

    enum CodingKeys: CodingKey {
        case x
        case y
        case rating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        rating = try? container.decode(String.self, forKey: .rating)
        guard x.isFinite, y.isFinite else {
            throw DecodingError.dataCorruptedError(
                forKey: .y,
                in: container,
                debugDescription: "Point values must be finite."
            )
        }
    }
}

/// Decodes each array element independently, allowing malformed chart points
/// to be skipped without invalidating the enclosing payload.
private struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Element] = []
        while !container.isAtEnd {
            let elementDecoder = try container.superDecoder()
            if let element = try? Element(from: elementDecoder) {
                decoded.append(element)
            }
        }
        elements = decoded
    }
}
