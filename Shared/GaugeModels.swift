import Foundation

/// CNN's five sentiment bands, normalized to stable app-facing values.
public enum FearGreedRating: String, Codable, CaseIterable, Identifiable, Sendable {
    case extremeFear = "Extreme Fear"
    case fear = "Fear"
    case neutral = "Neutral"
    case greed = "Greed"
    case extremeGreed = "Extreme Greed"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    /// Derives CNN's sentiment band from a normalized 0...100 score.
    public init(score: Double) {
        guard score.isFinite else {
            self = .neutral
            return
        }

        switch min(max(score, 0), 100) {
        case ...25:
            self = .extremeFear
        case ..<45:
            self = .fear
        case ...55:
            self = .neutral
        case ..<75:
            self = .greed
        default:
            self = .extremeGreed
        }
    }

    /// Normalizes the spelling and capitalization used by the upstream API.
    /// Unknown or missing values are derived from `fallbackScore`.
    public static func normalized(
        _ value: String?,
        fallbackScore: Double
    ) -> FearGreedRating {
        guard let value else { return FearGreedRating(score: fallbackScore) }

        let words = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")

        switch words {
        case "extreme fear", "extremefear":
            return .extremeFear
        case "fear":
            return .fear
        case "neutral":
            return .neutral
        case "greed":
            return .greed
        case "extreme greed", "extremegreed":
            return .extremeGreed
        default:
            return FearGreedRating(score: fallbackScore)
        }
    }
}

/// A timestamped raw point in one of CNN's component series.
public struct GaugePoint: Codable, Hashable, Identifiable, Sendable {
    public let timestamp: Date
    public let value: Double

    public var id: Date { timestamp }

    public init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

/// A timestamped point in the normalized 0...100 overall index history.
public struct GaugeHistoryPoint: Codable, Hashable, Identifiable, Sendable {
    public let timestamp: Date
    public let score: Double
    public let rating: FearGreedRating

    public var id: Date { timestamp }
    public var displayScore: Int { Int(min(max(score, 0), 100).rounded()) }

    public init(timestamp: Date, score: Double, rating: FearGreedRating) {
        self.timestamp = timestamp
        self.score = score
        self.rating = rating
    }
}

/// Describes how a raw component value should be presented.
public enum GaugeValueFormat: String, Codable, CaseIterable, Sendable {
    case index
    case decimal
    case percentagePoints
    case ratio

    public func format(_ value: Double, compact: Bool = false) -> String {
        guard value.isFinite else { return "—" }

        let suffix: String
        let fractionDigits: ClosedRange<Int>

        switch self {
        case .index:
            suffix = ""
            fractionDigits = compact ? 0...1 : 0...2
        case .decimal:
            suffix = ""
            fractionDigits = 0...2
        case .percentagePoints:
            suffix = " pp"
            fractionDigits = 0...2
        case .ratio:
            suffix = ""
            fractionDigits = 2...2
        }

        if compact, abs(value) >= 1_000 {
            let scale: Double
            let abbreviation: String
            switch abs(value) {
            case 1_000_000_000...:
                scale = 1_000_000_000
                abbreviation = "B"
            case 1_000_000...:
                scale = 1_000_000
                abbreviation = "M"
            default:
                scale = 1_000
                abbreviation = "K"
            }
            return Self.number(
                value / scale,
                minimumFractionDigits: 0,
                maximumFractionDigits: 1
            ) + abbreviation + suffix
        }

        return Self.number(
            value,
            minimumFractionDigits: fractionDigits.lowerBound,
            maximumFractionDigits: fractionDigits.upperBound
        ) + suffix
    }

    private static func number(
        _ value: Double,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

/// One raw line rendered in an indicator chart.
public struct GaugeSeries: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let valueFormat: GaugeValueFormat
    public let points: [GaugePoint]

    public init(
        id: String,
        displayName: String,
        valueFormat: GaugeValueFormat,
        points: [GaugePoint]
    ) {
        self.id = id
        self.displayName = displayName
        self.valueFormat = valueFormat
        self.points = points
    }
}

/// Stable identities and presentation metadata for CNN's seven drivers.
public enum GaugeIndicatorKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case marketMomentum
    case stockPriceStrength
    case stockPriceBreadth
    case putCallOptions
    case marketVolatility
    case safeHavenDemand
    case junkBondDemand

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .marketMomentum: "Market Momentum"
        case .stockPriceStrength: "Stock Price Strength"
        case .stockPriceBreadth: "Stock Price Breadth"
        case .putCallOptions: "Put and Call Options"
        case .marketVolatility: "Market Volatility"
        case .safeHavenDemand: "Safe Haven Demand"
        case .junkBondDemand: "Junk Bond Demand"
        }
    }

    public var shortTitle: String {
        switch self {
        case .marketMomentum: "Momentum"
        case .stockPriceStrength: "Price Strength"
        case .stockPriceBreadth: "Breadth"
        case .putCallOptions: "Put–Call"
        case .marketVolatility: "Volatility"
        case .safeHavenDemand: "Safe Haven"
        case .junkBondDemand: "Junk Bonds"
        }
    }

    public var subtitle: String {
        switch self {
        case .marketMomentum:
            "S&P 500 versus its 125-day average"
        case .stockPriceStrength:
            "Net new NYSE 52-week highs and lows"
        case .stockPriceBreadth:
            "McClellan Volume Summation Index"
        case .putCallOptions:
            "Five-day put/call ratio"
        case .marketVolatility:
            "VIX versus its 50-day average"
        case .safeHavenDemand:
            "Stock return minus bond return"
        case .junkBondDemand:
            "High-yield versus investment-grade spread"
        }
    }

    public var explanation: String {
        switch self {
        case .marketMomentum:
            "This compares the S&P 500 with its rolling 125-day average. Sustained trading above the average points to stronger appetite for risk."
        case .stockPriceStrength:
            "This compares NYSE stocks reaching 52-week highs with those reaching lows. More highs indicate broad confidence; more lows indicate fear."
        case .stockPriceBreadth:
            "This tracks whether trading volume is flowing into advancing or declining NYSE stocks. Stronger participation in rising stocks signals greed."
        case .putCallOptions:
            "This compares demand for downside-protection puts with bullish calls. A higher ratio generally means investors are more defensive."
        case .marketVolatility:
            "This compares the VIX with its 50-day average. Elevated expected volatility usually accompanies uncertainty and fear."
        case .safeHavenDemand:
            "This compares recent stock and Treasury returns. When bonds outperform stocks, investors are typically seeking safety."
        case .junkBondDemand:
            "This measures the extra yield investors demand from riskier junk bonds. A wider spread indicates more concern about credit risk."
        }
    }

    public var valueFormat: GaugeValueFormat {
        switch self {
        case .marketMomentum, .stockPriceBreadth:
            .index
        case .marketVolatility:
            .decimal
        case .stockPriceStrength, .safeHavenDemand, .junkBondDemand:
            .percentagePoints
        case .putCallOptions:
            .ratio
        }
    }

    public var referenceValue: Double? {
        switch self {
        case .stockPriceStrength, .stockPriceBreadth, .safeHavenDemand:
            0
        case .putCallOptions:
            1
        case .marketMomentum, .marketVolatility, .junkBondDemand:
            nil
        }
    }

    internal var expectedSeriesIDs: [String] {
        switch self {
        case .marketMomentum:
            ["market_momentum_sp500", "market_momentum_sp125"]
        case .stockPriceStrength:
            ["stock_price_strength"]
        case .stockPriceBreadth:
            ["stock_price_breadth"]
        case .putCallOptions:
            ["put_call_options"]
        case .marketVolatility:
            ["market_volatility_vix", "market_volatility_vix_50"]
        case .safeHavenDemand:
            ["safe_haven_demand"]
        case .junkBondDemand:
            ["junk_bond_demand"]
        }
    }
}

/// Current normalized summary plus the raw chart series for one driver.
public struct GaugeIndicator: Codable, Hashable, Identifiable, Sendable {
    public let kind: GaugeIndicatorKind
    public let score: Double
    public let rating: FearGreedRating
    public let sourceUpdatedAt: Date?
    public let series: [GaugeSeries]
    public let isStale: Bool

    public var id: GaugeIndicatorKind { kind }
    public var displayScore: Int { Int(min(max(score, 0), 100).rounded()) }
    public var referenceValue: Double? { kind.referenceValue }

    public init(
        kind: GaugeIndicatorKind,
        score: Double,
        rating: FearGreedRating,
        sourceUpdatedAt: Date?,
        series: [GaugeSeries],
        isStale: Bool = false
    ) {
        self.kind = kind
        self.score = score
        self.rating = rating
        self.sourceUpdatedAt = sourceUpdatedAt
        self.series = series
        self.isStale = isStale
    }

    internal func replacing(series: [GaugeSeries], isStale: Bool) -> GaugeIndicator {
        GaugeIndicator(
            kind: kind,
            score: score,
            rating: rating,
            sourceUpdatedAt: sourceUpdatedAt,
            series: series,
            isStale: isStale
        )
    }

    public func markingStale() -> GaugeIndicator {
        replacing(series: series, isStale: true)
    }
}

/// A complete app/widget snapshot. Missing indicators are represented by their
/// absence from `indicators`, never by a synthetic zero score.
public struct GaugeSnapshot: Codable, Hashable, Sendable {
    public let currentScore: Double
    public let currentRating: FearGreedRating
    public let sourceUpdatedAt: Date
    public let history: [GaugeHistoryPoint]
    public let indicators: [GaugeIndicator]
    public let fetchedAt: Date
    public let isStale: Bool

    public var displayScore: Int { Int(min(max(currentScore, 0), 100).rounded()) }

    public init(
        currentScore: Double,
        currentRating: FearGreedRating,
        sourceUpdatedAt: Date,
        history: [GaugeHistoryPoint],
        indicators: [GaugeIndicator],
        fetchedAt: Date,
        isStale: Bool = false
    ) {
        self.currentScore = currentScore
        self.currentRating = currentRating
        self.sourceUpdatedAt = sourceUpdatedAt
        self.history = history.sorted { $0.timestamp < $1.timestamp }
        self.indicators = Self.ordered(indicators)
        self.fetchedAt = fetchedAt
        self.isStale = isStale
    }

    public func indicator(for kind: GaugeIndicatorKind) -> GaugeIndicator? {
        indicators.first { $0.kind == kind }
    }

    /// Fills absent indicators and absent/empty component series from a last-good
    /// snapshot. Any reused component is explicitly marked stale.
    public func mergingMissingIndicators(from cached: GaugeSnapshot?) -> GaugeSnapshot {
        guard let cached else { return self }

        var merged: [GaugeIndicator] = []

        for kind in GaugeIndicatorKind.allCases {
            let fresh = indicator(for: kind)
            let previous = cached.indicator(for: kind)

            guard let fresh else {
                if let previous {
                    merged.append(previous.markingStale())
                }
                continue
            }

            guard let previous else {
                merged.append(fresh)
                continue
            }

            var seriesByID = Dictionary(uniqueKeysWithValues: fresh.series.map { ($0.id, $0) })
            var reusedSeries = false
            for expectedID in kind.expectedSeriesIDs {
                let existing = seriesByID[expectedID]
                guard existing == nil || existing?.points.isEmpty == true,
                      let cachedSeries = previous.series.first(where: {
                          $0.id == expectedID && !$0.points.isEmpty
                      }) else {
                    continue
                }
                seriesByID[expectedID] = cachedSeries
                reusedSeries = true
            }

            let orderedSeries = kind.expectedSeriesIDs.compactMap { seriesByID[$0] }
            merged.append(
                fresh.replacing(
                    series: orderedSeries,
                    isStale: fresh.isStale || reusedSeries
                )
            )
        }

        return GaugeSnapshot(
            currentScore: currentScore,
            currentRating: currentRating,
            sourceUpdatedAt: sourceUpdatedAt,
            history: history,
            indicators: merged,
            fetchedAt: fetchedAt,
            isStale: isStale
        )
    }

    public func markingStale() -> GaugeSnapshot {
        GaugeSnapshot(
            currentScore: currentScore,
            currentRating: currentRating,
            sourceUpdatedAt: sourceUpdatedAt,
            history: history,
            indicators: indicators.map { $0.markingStale() },
            fetchedAt: fetchedAt,
            isStale: true
        )
    }

    private static func ordered(_ indicators: [GaugeIndicator]) -> [GaugeIndicator] {
        let firstByKind = indicators.reduce(into: [GaugeIndicatorKind: GaugeIndicator]()) {
            if $0[$1.kind] == nil { $0[$1.kind] = $1 }
        }
        return GaugeIndicatorKind.allCases.compactMap { firstByKind[$0] }
    }
}

public protocol GaugeDataFetching: Sendable {
    func fetch() async throws -> GaugeSnapshot
}
