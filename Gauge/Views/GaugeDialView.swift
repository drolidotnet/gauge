import SwiftUI

struct GaugeDialView: View {
    private static let sweepFraction: CGFloat = 220 / 360

    private let score: Double?
    private let rating: FearGreedRating?
    private let isStale: Bool
    private let lineWidth: CGFloat

    init(
        score: Double?,
        rating: FearGreedRating?,
        isStale: Bool = false,
        lineWidth: CGFloat = 25
    ) {
        self.score = score
        self.rating = rating
        self.isStale = isStale
        self.lineWidth = lineWidth
    }

    private var progress: Double {
        max(0, min((score ?? 0) / 100, 1))
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let radius = max(0, (diameter - lineWidth) / 2)
            // The dial is laid out in this local square before the square itself
            // is centered in the GeometryReader.
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            let markerAngle = Angle.degrees(160 + (220 * progress))
            let marker = CGPoint(
                x: center.x + radius * CGFloat(cos(markerAngle.radians)),
                y: center.y + radius * CGFloat(sin(markerAngle.radians))
            )

            ZStack {
                Circle()
                    // A regular stroke is centered on Circle's outer path. Inset
                    // the path so its centerline uses the same radius as marker.
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: Self.sweepFraction)
                    .stroke(
                        GaugePalette.mutedTrackColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(160))

                if score != nil {
                    Circle()
                        .inset(by: lineWidth / 2)
                        .trim(from: 0, to: Self.sweepFraction * CGFloat(progress))
                        .stroke(
                            GaugePalette.dialGradient,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(160))

                    Circle()
                        .fill(GaugePalette.scoreColor(score ?? 0))
                        .overlay {
                            Circle()
                                .stroke(Color(uiColor: .systemBackground), lineWidth: max(2, lineWidth * 0.12))
                        }
                        .frame(width: lineWidth * 0.72, height: lineWidth * 0.72)
                        .position(marker)
                        .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                }

                VStack(spacing: 5) {
                    if let score {
                        Text("\(Int(max(0, min(score, 100)).rounded()))")
                            .font(.system(size: diameter * 0.21, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: score))
                    } else {
                        Text("—")
                            .font(.system(size: diameter * 0.21, weight: .bold, design: .rounded))
                    }

                    Text(rating?.displayName ?? "Unavailable")
                        .font(.system(size: max(13, diameter * 0.075), weight: .semibold, design: .rounded))
                        .foregroundStyle(rating.map(GaugePalette.ratingColor) ?? Color.secondary)

                    if isStale {
                        Label("Stale", systemImage: "clock.badge.exclamationmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .offset(y: diameter * 0.035)
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
        guard let score, let rating else { return "Unavailable" }
        let staleSuffix = isStale ? ", stale" : ""
        return "\(Int(score.rounded())) out of 100, \(rating.displayName)\(staleSuffix)"
    }
}

#Preview("Dial") {
    GaugeDialView(score: 72, rating: .greed)
        .frame(width: 300, height: 300)
        .padding()
}

#Preview("Unavailable") {
    GaugeDialView(score: nil, rating: nil, isStale: true)
        .frame(width: 300, height: 300)
        .padding()
}
