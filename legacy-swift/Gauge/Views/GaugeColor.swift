//
//  GaugeColor.swift
//  Gauge
//
//  Created by Oliver Drozdz on 2/7/2025.
//

import SwiftUI

struct GaugeColor {
    static func scoreColor(_ score: Double) -> Color {
        let clampedScore = max(0, min(score, 100))
        let t = clampedScore / 100.0
        let red: Double
        let green: Double
        if t < 0.5 {
            red = 1.0
            green = t * 1.0
        } else {
            red = 1.0 - (t - 0.5) * 2.0
            green = 0.5 + (t - 0.5) * 1.0
        }
        let adjustedRed = pow(red, 0.9)
        let adjustedGreen = pow(green, 0.9)
        return Color(red: adjustedRed, green: adjustedGreen, blue: 0)
    }
}
