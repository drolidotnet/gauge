//
//  GaugeChartView.swift
//  Gauge
//
//  Created by Oliver Drozdz on 2/7/2025.
//

import SwiftUI

struct GaugeChartView: View {
    @EnvironmentObject var viewModel: GaugeViewModel
    @State private var dragLocation: CGPoint? = nil
    @State private var selectedIndex: Int? = nil
    var body: some View {
        GeometryReader { geo in
            let data = viewModel.historicalData
            let maxY = data.map { $0.y }.max() ?? 100
            let minY = data.map { $0.y }.min() ?? 0
            let points = data.enumerated().map { (i, point) in
                CGPoint(
                    x: geo.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1)),
                    y: geo.size.height * CGFloat(1 - (point.y - minY) / max(1, maxY - minY))
                )
            }
            ZStack {
                // Background grid
                ForEach(0..<5) { i in
                    let y = geo.size.height * CGFloat(i) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                }
                // Line chart
                if points.count > 1 {
                    Path { path in
                        path.move(to: points.first ?? .zero)
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(
                        GaugeColor.scoreColor(viewModel.currentScore),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                }
                // Interactive marker
                if let selectedIndex = selectedIndex, data.indices.contains(selectedIndex) {
                    let pt = points[selectedIndex]
                    let value = data[selectedIndex].y
                    let rating = data[selectedIndex].rating.capitalized
                    VStack(spacing: 2) {
                        Text("\(Int(value))")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Text(rating)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .position(x: pt.x, y: pt.y - 24)
                    Circle()
                        .fill(GaugeColor.scoreColor(value))
                        .frame(width: 14, height: 14)
                        .position(pt)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragLocation = value.location
                    let x = value.location.x
                    let idx = Int(round(x / geo.size.width * CGFloat(max(data.count - 1, 1))))
                    if data.indices.contains(idx) {
                        selectedIndex = idx
                    }
                }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        selectedIndex = nil
                    }
                }
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.7))
                .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        )
    }
}

#Preview {
    GaugeChartView()
        .environmentObject(GaugeViewModel())
}
