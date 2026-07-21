import SwiftUI

/// Cross-target colors for dials, ratings, charts, and widget tiles.
public enum GaugePalette {
    public static let fear = Color(red: 0.91, green: 0.18, blue: 0.20)
    public static let neutral = Color(red: 0.95, green: 0.68, blue: 0.10)
    public static let greed = Color(red: 0.10, green: 0.68, blue: 0.34)

    public static let gradientStops: [Gradient.Stop] = [
        .init(color: fear, location: 0),
        .init(color: neutral, location: 0.5),
        .init(color: greed, location: 1)
    ]

    /// A 220-degree gradient in the circle's unrotated coordinate space.
    /// Dial views rotate the trimmed circle to the lower-left endpoint.
    public static var dialGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: gradientStops),
            center: .center,
            startAngle: .zero,
            endAngle: .degrees(220)
        )
    }

    public static var mutedTrackColor: Color {
        Color.secondary.opacity(0.18)
    }

    public static func scoreColor(_ score: Double) -> Color {
        guard score.isFinite else { return neutral }
        let progress = min(max(score, 0), 100) / 100

        if progress <= 0.5 {
            return interpolate(
                from: (0.91, 0.18, 0.20),
                to: (0.95, 0.68, 0.10),
                progress: progress * 2
            )
        }
        return interpolate(
            from: (0.95, 0.68, 0.10),
            to: (0.10, 0.68, 0.34),
            progress: (progress - 0.5) * 2
        )
    }

    public static func ratingColor(_ rating: FearGreedRating) -> Color {
        switch rating {
        case .extremeFear:
            scoreColor(12.5)
        case .fear:
            scoreColor(35)
        case .neutral:
            scoreColor(50)
        case .greed:
            scoreColor(65)
        case .extremeGreed:
            scoreColor(87.5)
        }
    }

    private static func interpolate(
        from: (red: Double, green: Double, blue: Double),
        to: (red: Double, green: Double, blue: Double),
        progress: Double
    ) -> Color {
        Color(
            red: from.red + ((to.red - from.red) * progress),
            green: from.green + ((to.green - from.green) * progress),
            blue: from.blue + ((to.blue - from.blue) * progress)
        )
    }
}
