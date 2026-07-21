import SwiftUI

struct GaugeMainView: View {
    @EnvironmentObject private var viewModel: GaugeViewModel
    @State private var selectedRange: GaugeChartRange = .oneMonth

    private let indicatorOrder: [GaugeIndicatorKind] = [
        .marketMomentum,
        .stockPriceStrength,
        .stockPriceBreadth,
        .putCallOptions,
        .marketVolatility,
        .safeHavenDemand,
        .junkBondDemand
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = viewModel.snapshot {
                    dashboard(snapshot)
                } else if viewModel.isInitialLoading || viewModel.isRefreshing {
                    initialLoading
                } else {
                    unavailable
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .task { await viewModel.load() }
    }

    private func dashboard(_ snapshot: GaugeSnapshot) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                dashboardHeader(snapshot)

                if snapshot.isStale || viewModel.errorMessage != nil {
                    staleBanner
                }

                GaugeDialView(
                    score: snapshot.currentScore,
                    rating: snapshot.currentRating,
                    isStale: snapshot.isStale || viewModel.errorMessage != nil
                )
                .frame(maxWidth: 340)
                .padding(.vertical, 6)

                indicatorsHeader

                ForEach(indicatorOrder, id: \.self) { kind in
                    GaugeIndicatorCardView(
                        kind: kind,
                        indicator: snapshot.indicator(for: kind),
                        range: selectedRange
                    )
                }

                GaugeHistoryChartView(history: snapshot.history, range: selectedRange)

                Text("Market data provided by CNN. Refresh timing is best effort.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func dashboardHeader(_ snapshot: GaugeSnapshot) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fear & Greed Index")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text("Updated \(snapshot.sourceUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                ZStack {
                    Image(systemName: "arrow.clockwise")
                        .opacity(viewModel.isRefreshing ? 0 : 1)
                    if viewModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(width: 38, height: 38)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRefreshing)
            .accessibilityLabel(viewModel.isRefreshing ? "Refreshing" : "Refresh market data")
        }
        .padding(.horizontal, 2)
    }

    private var indicatorsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("7 Market Indicators")
                    .font(.title3.bold())
                Text("The drivers behind the headline index")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GaugeRangePicker(selection: $selectedRange)
        }
        .padding(.top, 4)
        .padding(.horizontal, 2)
    }

    private var staleBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(.orange)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text("Showing saved data")
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.errorMessage ?? "This snapshot may be out of date. Pull down or tap refresh to try again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var initialLoading: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading market sentiment…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var unavailable: some View {
        ContentUnavailableView {
            Label("Fear & Greed unavailable", systemImage: "wifi.exclamationmark")
        } description: {
            Text(viewModel.errorMessage ?? "Market data could not be loaded and there is no saved snapshot yet.")
        } actions: {
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    GaugeMainView()
        .environmentObject(GaugeViewModel.preview)
}
