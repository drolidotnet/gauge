//
//  GaugeDialView.swift
//  Gauge
//
//  Created by Oliver Drozdz on 2/7/2025.
//

import SwiftUI

struct GaugeDialView: View {
    @EnvironmentObject var viewModel: GaugeViewModel

//    func scoreColor(_ score: Double) -> Color {
//        let clampedScore = max(0, min(score, 100))
//        let t = clampedScore / 100.0
//        let red: Double
//        let green: Double
//        if t < 0.5 {
//            red = 1.0
//            green = t * 1.0
//        } else {
//            red = 1.0 - (t - 0.5) * 2.0
//            green = 0.5 + (t - 0.5) * 1.0
//        }
//        let adjustedRed = pow(red, 0.9)
//        let adjustedGreen = pow(green, 0.9)
//        return Color(red: adjustedRed, green: adjustedGreen, blue: 0)
//    }

    var body: some View {
        let color = GaugeColor.scoreColor(viewModel.currentScore)
        let sweep: CGFloat = 200.0 / 360.0
        let startAngle: Double = -190 // degrees, so -100 to +100 is 200deg sweep
        ZStack {
            Circle()
                .trim(from: 0, to: sweep)
                .stroke(Color.gray.opacity(0.15), lineWidth: 24)
                .rotationEffect(.degrees(startAngle))
            Circle()
                .trim(from: 0, to: CGFloat(min(viewModel.currentScore / 100, 1)) * sweep)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 24, lineCap: .butt)
                )
                .rotationEffect(.degrees(startAngle))
//                .animation(.spring(response: 0.7, dampingFraction: 0.7), value: viewModel.currentScore)
            VStack(spacing: 4) {
                Text("\(Int(viewModel.currentScore))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(viewModel.currentRating)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.7))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

#Preview {
    GaugeDialView()
        .environmentObject(GaugeViewModel.preview)
}
