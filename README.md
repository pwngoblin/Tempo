# Tempo

Local-first calendar for **macOS, iOS and watchOS** (SwiftUI, EventKit, WidgetKit). No accounts, no network, no tracking.

> Claude never adds, edits or deletes calendar entries (see CLAUDE.md).

## What it does
- Day / Week / Month on Mac; Agenda / Week / Month on iPhone; Now & Next on the watch.
- **Quick add**: type "Gym tomorrow 6pm #Personal" (offline parser). Or use the normal form.
- **Calendar Sets**: switch groups of calendars (Work, Personal…) everywhere.
- **Join button** for Zoom / Meet / Teams links. Menu-bar countdown (survives quitting the app).
- **Widgets & complications**, fully configurable, plus **custom widgets you design yourself** (Settings → Widgets).
- **Customizable**: theme, accent, density, interface size (⌘+ / ⌘−), week start, time format, and more.
- Subscribe to calendars by URL.

## Build
```sh
brew install xcodegen
git clone https://github.com/pwngoblin/Widgetry ../Widgetry   # custom-widget engine, sibling folder
xcodegen generate
(cd Packages/CalendarCore && swift test)
xcodebuild -project Tempo.xcodeproj -scheme Tempo-macOS -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Schemes: `Tempo-macOS`, `Tempo-iOS` (embeds watch app + widgets), `Tempo-watchOS`.
Widgets and the menu-bar helper need a signed build: put your Team ID in `DEVELOPMENT_TEAM` in `project.yml`.
Needs Xcode 16+.

## Docs
[SPEC](docs/SPEC.md) status · [ARCHITECTURE](docs/ARCHITECTURE.md) · [WIDGETS](docs/WIDGETS.md) · [UX](docs/UX.md) · [PARSER](docs/PARSER.md) · [TESTING](docs/TESTING.md) · [KNOWLEDGEBASE](KNOWLEDGEBASE.md) (gotchas)

Custom widgets are powered by [Widgetry](https://github.com/pwngoblin/Widgetry) (currently private).

MIT, see [LICENSE](LICENSE).
