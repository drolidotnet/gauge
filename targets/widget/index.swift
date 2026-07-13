import WidgetKit
import SwiftUI

@main
struct GaugeWidgetBundle: WidgetBundle {
    var body: some Widget {
        GaugeWidget()
        GaugeHybridWidget()
    }
}
