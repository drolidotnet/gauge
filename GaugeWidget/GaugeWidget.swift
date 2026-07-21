import SwiftUI
import WidgetKit

struct GaugeWidget: Widget {
    static let kind = "GaugeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: GaugeConfigurationIntent.self,
            provider: GaugeWidgetProvider()
        ) { entry in
            GaugeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Fear & Greed Index")
        .description("See market sentiment on your Home or Lock Screen, plus all seven indicators in the large widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

struct GaugeWidgetEntryView: View {
    let entry: GaugeWidgetEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var usesFullColor: Bool {
        renderingMode == .fullColor
    }

    var body: some View {
        if family == .accessoryCircular {
            accessoryCircularView
                .containerBackground(for: .widget) {
                    Color.clear
                }
        } else {
            homeScreenView
        }
    }

    private var homeScreenView: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                smallView
            }
        }
        .padding(contentPadding)
        .containerBackground(for: .widget) {
            ZStack {
                Color(uiColor: .secondarySystemBackground)

                if usesFullColor {
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.10),
                            Color.clear,
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }

    private var contentPadding: CGFloat {
        switch family {
        case .systemSmall:
            6
        case .systemMedium:
            14
        case .systemLarge:
            13
        case .accessoryCircular:
            0
        default:
            12
        }
    }

    private var smallView: some View {
        ZStack(alignment: .topTrailing) {
            GaugeWidgetDial(
                score: entry.score,
                rating: entry.rating,
                usesFullColor: usesFullColor,
                style: .compact,
                showsRating: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer(minLength: 0)

                Text(entry.rating ?? "Unavailable")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(sentimentColor(for: entry.score))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        Capsule(style: .continuous)
                            .fill(sentimentColor(for: entry.score).opacity(0.12))
                    }
                    .widgetAccentable()
                    .accessibilityHidden(true)
                    .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if entry.isStale {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(3)
                    .accessibilityLabel("Stale data")
            }
        }
    }

    @ViewBuilder
    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            if let score = entry.score, score.isFinite {
                let clampedScore = min(max(score, 0), 100)

                Gauge(value: clampedScore, in: 0...100) {
                    Text("Fear and Greed Index")
                } currentValueLabel: {
                    Text("\(Int(clampedScore.rounded()))")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                }
                .gaugeStyle(.accessoryCircular)
                .labelsHidden()
                .widgetAccentable()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Fear and Greed Index")
                .accessibilityValue(accessoryAccessibilityValue)
            } else {
                ZStack {
                    Circle()
                        .trim(from: 0, to: 220.0 / 360.0)
                        .stroke(
                            Color.secondary.opacity(0.55),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(160))
                        .padding(4)

                    Text("—")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Fear and Greed Index")
                .accessibilityValue("Unavailable")
            }
        }
    }

    private var accessoryAccessibilityValue: String {
        guard let score = entry.score, score.isFinite else { return "Unavailable" }
        let clampedScore = min(max(score, 0), 100)
        let staleSuffix = entry.isStale ? ", stale" : ""
        return "\(Int(clampedScore.rounded())) out of 100, \(entry.rating ?? "rating unavailable")\(staleSuffix)"
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            GaugeWidgetDial(
                score: entry.score,
                rating: entry.rating,
                usesFullColor: usesFullColor,
                style: .regular
            )
            .frame(width: 125, height: 125)

            VStack(alignment: .leading, spacing: 7) {
                Text("CNN Fear & Greed Index")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Current market sentiment")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                GaugeWidgetFreshness(
                    updatedAt: entry.updatedAt,
                    isStale: entry.isStale
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var largeView: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("CNN Fear & Greed Index")
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 4)

                GaugeWidgetFreshness(
                    updatedAt: entry.updatedAt,
                    isStale: entry.isStale
                )
            }

            HStack(spacing: 14) {
                GaugeWidgetDial(
                    score: entry.score,
                    rating: entry.rating,
                    usesFullColor: usesFullColor,
                    style: .reduced
                )
                .frame(width: 106, height: 106)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.rating ?? "Unavailable")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(sentimentColor(for: entry.score))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Text("7 market indicators")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    if entry.score == nil {
                        Text("A new fetch will be attempted automatically.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            indicatorGrid
        }
    }

    private var indicatorGrid: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                indicatorTile(.marketMomentum)
                indicatorTile(.stockPriceStrength)
            }

            GridRow {
                indicatorTile(.stockPriceBreadth)
                indicatorTile(.putCallOptions)
            }

            GridRow {
                indicatorTile(.marketVolatility)
                indicatorTile(.safeHavenDemand)
            }

            GridRow {
                indicatorTile(.junkBondDemand)
                    .gridCellColumns(2)
            }
        }
    }

    private func indicatorTile(_ kind: GaugeIndicatorKind) -> some View {
        GaugeWidgetIndicatorTile(
            kind: kind,
            indicator: entry.indicator(for: kind),
            usesFullColor: usesFullColor
        )
    }

    private func sentimentColor(for score: Double?) -> Color {
        guard let score else { return .secondary }
        return usesFullColor ? GaugePalette.scoreColor(score) : .accentColor
    }
}

private struct GaugeWidgetFreshness: View {
    let updatedAt: Date?
    let isStale: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isStale ? "clock.badge.exclamationmark" : "clock")
                .accessibilityHidden(true)

            if let updatedAt {
                if isStale {
                    Text("Stale")
                }

                Text(updatedAt, style: .relative)
            } else {
                Text("Unavailable")
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let updatedAt else { return "Update time unavailable" }
        let prefix = isStale ? "Stale data, last updated" : "Updated"
        return "\(prefix) \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct GaugeWidgetIndicatorTile: View {
    let kind: GaugeIndicatorKind
    let indicator: GaugeWidgetIndicator?
    let usesFullColor: Bool

    private var tileColor: Color {
        guard let score = indicator?.score else { return .secondary }
        return usesFullColor ? GaugePalette.scoreColor(score) : .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(kind.shortTitle)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 2)

                if indicator?.isStale == true {
                    Image(systemName: "clock")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }

            if let indicator, let score = indicator.score {
                Text("\(Int(score.rounded())) · \(indicator.rating ?? "Unavailable")")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(tileColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            } else {
                Text("Unavailable")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 27, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tileColor.opacity(indicator?.score == nil ? 0.06 : 0.13))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tileColor.opacity(0.16), lineWidth: 0.5)
        }
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let indicator, let score = indicator.score else {
            return "\(kind.title), unavailable"
        }

        let staleSuffix = indicator.isStale ? ", stale" : ""
        return "\(kind.title), score \(Int(score.rounded())) out of 100, \(indicator.rating ?? "rating unavailable")\(staleSuffix)"
    }
}

private struct GaugeWidgetDial: View {
    enum Style {
        case compact
        case regular
        case reduced

        var lineWidth: CGFloat {
            switch self {
            case .compact: 12
            case .regular: 11
            case .reduced: 9
            }
        }

        var scoreScale: CGFloat {
            switch self {
            case .compact: 0.34
            case .regular: 0.24
            case .reduced: 0.23
            }
        }

        var ratingScale: CGFloat {
            switch self {
            case .compact: 0.085
            case .regular: 0.080
            case .reduced: 0.078
            }
        }
    }

    let score: Double?
    let rating: String?
    let usesFullColor: Bool
    let style: Style
    let showsRating: Bool

    init(
        score: Double?,
        rating: String?,
        usesFullColor: Bool,
        style: Style,
        showsRating: Bool = true
    ) {
        self.score = score
        self.rating = rating
        self.usesFullColor = usesFullColor
        self.style = style
        self.showsRating = showsRating
    }

    private let arcFraction = 220.0 / 360.0
    private let startAngle = 160.0

    private var progress: Double {
        max(0, min((score ?? 0) / 100, 1))
    }

    private var displayScore: Int? {
        score.map { Int(min(max($0, 0), 100).rounded()) }
    }

    private var endpointColor: Color {
        guard let score else { return .secondary }
        return usesFullColor ? GaugePalette.scoreColor(score) : .accentColor
    }

    private var dialGradient: AngularGradient {
        if usesFullColor {
            GaugePalette.dialGradient
        } else {
            AngularGradient(
                colors: [Color.accentColor.opacity(0.48), .accentColor],
                center: .center,
                startAngle: .zero,
                endAngle: .degrees(220)
            )
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let radius = max(0, (diameter - style.lineWidth) / 2)
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            let angle = Angle.degrees(startAngle + (220 * progress))
            let marker = CGPoint(
                x: center.x + radius * CGFloat(cos(angle.radians)),
                y: center.y + radius * CGFloat(sin(angle.radians))
            )

            ZStack {
                Circle()
                    .inset(by: style.lineWidth / 2)
                    .trim(from: 0, to: arcFraction)
                    .stroke(
                        usesFullColor ? GaugePalette.mutedTrackColor : Color.secondary.opacity(0.16),
                        style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(startAngle))

                if score != nil {
                    Circle()
                        .inset(by: style.lineWidth / 2)
                        .trim(from: 0, to: arcFraction * progress)
                        .stroke(
                            dialGradient,
                            style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(startAngle))
                        .widgetAccentable()

                    Circle()
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: style.lineWidth * 0.88, height: style.lineWidth * 0.88)
                        .overlay {
                            Circle()
                                .fill(endpointColor)
                                .padding(style.lineWidth * 0.18)
                        }
                        .position(marker)
                        .widgetAccentable()
                }

                VStack(spacing: 2) {
                    if let displayScore {
                        Text("\(displayScore)")
                            .font(.system(
                                size: diameter * style.scoreScale,
                                weight: .bold,
                                design: .rounded
                            ))
                    } else {
                        Text("—")
                            .font(.system(
                                size: diameter * style.scoreScale,
                                weight: .bold,
                                design: .rounded
                            ))
                    }

                    if showsRating {
                        Text(rating ?? "Unavailable")
                            .font(.system(
                                size: max(9, diameter * style.ratingScale),
                                weight: .semibold,
                                design: .rounded
                            ))
                            .foregroundStyle(endpointColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.66)
                    }
                }
                .padding(.horizontal, style.lineWidth + 2)
                .offset(y: showsRating ? diameter * 0.045 : -diameter * 0.035)
            }
            .frame(width: diameter, height: diameter)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fear and Greed Index")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let displayScore else { return "Unavailable" }
        return "\(displayScore) out of 100, \(rating ?? "rating unavailable")"
    }
}

#Preview(as: .systemSmall) {
    GaugeWidget()
} timeline: {
    GaugeWidgetEntry.preview
    GaugeWidgetEntry.unavailable
}

#Preview(as: .systemMedium) {
    GaugeWidget()
} timeline: {
    GaugeWidgetEntry.preview
}

#Preview(as: .systemLarge) {
    GaugeWidget()
} timeline: {
    GaugeWidgetEntry.preview
}

#Preview(as: .accessoryCircular) {
    GaugeWidget()
} timeline: {
    GaugeWidgetEntry.preview
    GaugeWidgetEntry.unavailable
}
