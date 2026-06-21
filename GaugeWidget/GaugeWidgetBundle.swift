//
//  GaugeWidgetBundle.swift
//  GaugeWidget
//
//  Created by Oliver Drozdz on 1/7/2025.
//

import WidgetKit
import SwiftUI

@main
struct GaugeWidgetBundle: WidgetBundle {
    var body: some Widget {
        GaugeWidget()
        GaugeHybridWidget()
    }
}
