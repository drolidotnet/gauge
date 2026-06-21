//
//  GaugeMainView.swift
//  Gauge
//
//  Created by Oliver Drozdz on 2/7/2025.
//

import SwiftUI

struct GaugeMainView: View {
    @EnvironmentObject var viewModel: GaugeViewModel
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Fear & Greed Index")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            GaugeDialView()
                .frame(height: 280)
                .environmentObject(viewModel)
//            Text("\(Int(viewModel.currentScore))  •  \(viewModel.currentRating)")
//                .font(.system(size: 28, weight: .semibold, design: .rounded))
//                .foregroundColor(.accentColor)
//                .padding(.vertical, 8)
            GaugeChartView()
                .frame(height: 120)
                .environmentObject(viewModel)
            if viewModel.isLoading {
                ProgressView().padding()
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red).padding()
            }
        }
        .padding()
//        .background(Color(.darkGray))
    }
}

#Preview {
    GaugeMainView()
        .environmentObject(GaugeViewModel.preview)
}
