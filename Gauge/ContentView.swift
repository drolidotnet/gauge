//
//  ContentView.swift
//  Gauge
//
//  Created by Oliver Drozdz on 1/7/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GaugeViewModel()
    var body: some View {
        GaugeMainView()
            .environmentObject(viewModel)
            .onAppear { viewModel.fetch() }
    }
}

#Preview {
    ContentView()
}
