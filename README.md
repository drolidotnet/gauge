# Gauge

Gauge is a native SwiftUI iPhone app for CNN's Fear & Greed Index. It shows a
220-degree sentiment dial, the seven market indicators behind the headline
score, and 1M/3M/1Y Swift Charts with touch inspection.

The Home Screen widget supports small, medium, and large families. The large
family includes all seven normalized indicator summaries without loading the
raw chart history into WidgetKit. A circular Lock Screen widget uses the native
iOS accessory gauge to show the current score at a glance.

## Requirements

- Xcode 26 or later
- iOS 17 or later
- An Apple team that can provision App Group `group.com.drolidotnet.Gauge`

Both the app and widget targets already include the matching App Group
entitlement. The project is restricted to iPhone.

## Data and refresh behavior

The shared client reads CNN's public graph-data endpoint and maps its nine raw
component objects into seven ordered indicators. Full snapshots are written
atomically into the App Group container. Missing components reuse cached
last-good values and are visibly marked stale; failures are never represented
as a zero score.

Widgets reuse cache younger than 15 minutes, normally request another timeline
after 12 hours, and request a one-hour retry after a failed fetch. WidgetKit may
defer those dates according to its system refresh budget.

## Project layout

- `Shared/`: models, CNN client, cache, refresh policy, and dial palette
- `Gauge/`: cache-first dashboard, dial, indicator cards, and charts
- `GaugeWidget/`: App Intent timeline provider and all widget layouts
- `GaugeTests/`: decoding, failure, formatting, cache, range, and fallback tests

The generic endpoint/JSON editor, credentials, additional Lock Screen layouts,
and iPad support are intentionally reserved for later milestones.
