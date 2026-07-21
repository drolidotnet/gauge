import AppIntents
import WidgetKit

/// The widget deliberately has no user-selectable options yet. Using an App
/// Intent configuration now keeps the widget ready for configuration options in
/// a later milestone without changing its stable WidgetKit kind.
struct GaugeConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Fear & Greed"
    static let description = IntentDescription(
        "Shows the current CNN Fear & Greed Index and its market indicators."
    )
}
