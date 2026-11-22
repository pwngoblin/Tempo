# Tempo

> **Rule: Claude never adds, edits or deletes calendar entries (see CLAUDE.md).**

Local-first calendar for macOS, iOS and watchOS on top of `EKEventStore`. No accounts, no network, no telemetry.
Bundle IDs: `com.local.tempo*` · App Group: `group.com.local.tempo` · URL scheme: `tempo://`

## Requirements
The [Widgetry](https://github.com/pwngoblin/Widgetry) package checked out as a sibling folder (`../Widgetry`). macOS with Xcode 16+ (Swift 5 language mode), [XcodeGen](https://github.com/yonaskolb/XcodeGen). Widgets and the menu-bar helper need a signed build (your own Apple Developer team, see below). The iOS/watchOS targets build for the simulator without signing.

## Build
```sh
brew install xcodegen          # once
xcodegen generate              # project.yml -> Tempo.xcodeproj (generated, git-ignored)
(cd Packages/CalendarCore && swift test)      # 38 unit tests, incl. the NLP parser
xcodebuild -project Tempo.xcodeproj -scheme Tempo-macOS -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
Schemes: `Tempo-macOS`, `Tempo-iOS` (embeds the watch app + widgets), `Tempo-watchOS`.
To run on a device/Mac with App Groups, set `DEVELOPMENT_TEAM` in `project.yml` and regenerate.

## What you can customize
Theme, accent, 12/24-hour, week start, week numbers, density, event-block style, hour height, work week, agenda length, default views, default event length/calendar, haptics, menu-bar countdown, per-calendar visibility, Calendar Sets, subscriptions, and every widget option — see docs/UX.md and docs/WIDGETS.md.

## Docs
[SPEC](docs/SPEC.md) · [ARCHITECTURE](docs/ARCHITECTURE.md) · [PARSER](docs/PARSER.md) · [WIDGETS](docs/WIDGETS.md) (all customization options) ·
[UX](docs/UX.md) · [TESTING](docs/TESTING.md) · [KNOWLEDGEBASE](KNOWLEDGEBASE.md) · [CLAUDE.md](CLAUDE.md)

## Layout
```
project.yml                      XcodeGen spec (6 targets)
Packages/CalendarCore/           EventKit wrapper, NL parser, Calendar Sets, meeting links, agenda math, deep links (+ tests)
Apps/{macOS,iOS,watchOS}/        app-specific UI (macOS: window, time grid, MenuBarExtra)
Shared/Common                    colors, month grid, time formatting          -> all targets
Shared/UI                        event row, QuickAdd + preview pill, set picker -> mac, iOS, watch
Shared/UIRich                    mini month, event editor, sets editor         -> mac, iOS
Shared/Intents                   CalendarSetEntity, widget config + button intents -> apps + widgets
Shared/AppIntents                AddEventIntent + Shortcuts                    -> apps
Shared/WatchLink                 WatchConnectivity bridge                      -> iOS, watch
Shared/Widgets                   TimelineProvider + Next Event widget/complications -> all widget targets
Shared/WidgetsHome               Month+Agenda, Set Switcher, Week Schedule     -> iOS/macOS widget targets
Widgets/{iOS,macOS,watchOS}      the @main WidgetBundle per extension
```
Targets: `TempoMac` + `TempoMacWidgets`, `TempoIOS` + `TempoIOSWidgets`, `TempoWatch` + `TempoWatchWidgets`.
Privacy keys (`NSCalendarsFullAccessUsageDescription`, `NSRemindersFullAccessUsageDescription`) and entitlements (sandbox, calendars, App Group) are declared in `project.yml`.

## Design decisions worth knowing
- **EventKit is read-only on watchOS** (`save`/`remove` are unavailable). Watch quick-add sends the phrase to the iPhone
  (`transferUserInfo`, queued), which parses and saves it with the original timestamp so "tomorrow" means what it meant when spoken.
  The iPhone also pushes Calendar Set definitions to the watch (`updateApplicationContext`) because the watch has its own App Group.
- **Calendar subscriptions** (Settings → Subscriptions, or the `+` next to *Calendars* in the Mac sidebar): EventKit can't create them, so Tempo validates the address (https/webcal only) and hands it to the system Calendar, which subscribes; the calendar then appears everywhere.
- **Calendar Sets** store `{id, title, source}` per calendar: `EKCalendar.calendarIdentifier` is device-local, so title+source is the cross-device match.
  Mac/iPhone can also mirror sets via iCloud key-value storage: enable the iCloud *Key-value storage* capability once you have a team (not enabled by default, since it needs a provisioning profile).
- **NL parser** is deterministic: custom rules first, `NSDataDetector` only as a fallback for numeric dates.
  Bare hour 1–6 ⇒ PM, 7–11 ⇒ AM (`at 5` ⇒ 17:00); `next fri` is strictly after today; a date without a time is all-day.
  Syntax: `#Calendar`, `@Place` / `@"Room 4B"`, `45m`, `1h30m`, `10-11am`, `11-1pm`, `22:00-01:00`, `Nov 25`, `2026-12-24`, `in 3 days`, `tonight`, `all day`.
- **Meeting links**: https only (plus `zoommtg`), exact provider domains (`evilzoom.us`/`zoom.us.evil.com` rejected), Outlook SafeLinks unwrapped.
- **Widget budgets**: timeline entries are placed only at event start/end and midnight (`TimelinePlanner`); countdowns use `Text(date, style: .timer)`,
  so there are no per-minute entries. watchOS: 2-day window, ≤10 entries, ≥30 min between reloads.
- **Widgets are fully customizable**: one `TempoWidgetIntent` (set, days, density, colors, tint, background, time format, countdown, inline text, week numbers, week-grid hours…) works on every widget and complication — see docs/WIDGETS.md.
- Accented/tinted + Always-On: colour elements are `.widgetAccentable()`; the rectangular complication drops its third line when `isLuminanceReduced`.
- Recurring events: the editor asks *this event / future events*. Drag-resize in the Mac grid always uses *this event*.

## Not verified yet
Built for all three platforms and unit-tested, but not launched on hardware: permission prompts, widget data access
(widgets rely on the app's Calendar grant; on macOS the extension has the calendars entitlement), complications on a real watch,
and watch ⇄ phone delivery need a signed run. Add an iPhone/Watch simulator pair or device to test WatchConnectivity.

## Custom widgets: Widgetry
Users can design their own widgets (Settings → Widgets) with a visual editor. The engine and editor are the separate Swift
package **Widgetry**, https://github.com/pwngoblin/Widgetry (currently private). `project.yml` references it as a local
package at `../Widgetry`, so **clone Widgetry next to this repo to build**. See docs/WIDGETS.md.

## License
MIT, see [LICENSE](LICENSE).
