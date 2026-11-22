# Architecture

```
┌───────────────────────── CalendarCore (SwiftPM, no UI) ─────────────────────────┐
│ EventReader (non-actor)  ─┐     EventParser   MeetingLinkExtractor   DeepLink    │
│ EventStoreManager (@MainActor @Observable, wraps EventReader + writes)           │
│ CalendarSet / CalendarSetStore (App Group + optional iCloud KVS)                 │
│ Agenda (current/next/free/busy/byDay/layout)   TimelinePlanner                   │
└──────────────────────────────────────────────────────────────────────────────────┘
   ▲ used by apps (via EventStoreManager)        ▲ used by widgets (via EventReader only)
```
Widgets never create a `@MainActor` manager; they read through `EventReader` and hand value types
(`EventItem`, `RGBA`) to SwiftUI. `EventItem` is a Sendable/Codable snapshot of an `EKEvent`.

## Targets (`project.yml`, generated with XcodeGen)
| Target | Platform | Bundle ID | Sources |
|---|---|---|---|
| TempoMac | macOS 14 | `com.local.tempo` | Apps/macOS + Common, UI, UIRich, Intents, AppIntents |
| TempoMacWidgets | macOS ext | `com.local.tempo.widgets` | Widgets/macOS + Common, Intents, Widgets, WidgetsHome |
| TempoIOS | iOS 17 | `com.local.tempo.ios` | Apps/iOS + Common, UI, UIRich, Intents, AppIntents, WatchLink |
| TempoIOSWidgets | iOS ext | `com.local.tempo.ios.widgets` | Widgets/iOS + Common, Intents, Widgets, WidgetsHome |
| TempoWatch | watchOS 10 | `com.local.tempo.ios.watchkitapp` | Apps/watchOS + Common, UI, Intents, AppIntents, WatchLink |
| TempoWatchWidgets | watchOS ext | `…watchkitapp.widgets` | Widgets/watchOS + Common, Intents, Widgets |

`Shared/*` folders are *source groups compiled into each target* (not modules) so App Intents metadata
extraction works and watch builds can omit iOS-only code. Rule of thumb: a file lives in the narrowest group
that every consumer can compile.

## macOS menu bar = separate helper process
`TempoMenuBar` (bundle `com.local.tempo.menubar`, `LSUIElement`, no Dock icon) owns the `MenuBarExtra`. It is embedded at
`Tempo.app/Contents/Library/LoginItems/TempoMenuBar.app`. The main app starts it (`MenuBarHelper.ensureRunning`) when
"Show in menu bar" is on; quitting the main app does **not** stop it. "Start menu bar at login" registers it with `SMAppService.loginItem`.
The helper reads the same App Group prefs (polled every 3 s) and talks to the main app only through `tempo://` URLs
(`today`, `event/<id>`, `settings`). It needs its own Calendar permission (TCC is per app). Stop it with *Quit Menu Bar* in its popover or by turning the setting off.

## Data flow
1. **Change:** EventKit posts `.EKEventStoreChanged` → manager refreshes access/calendars → `revision += 1` →
   `WidgetCenter.reloadAllTimelines()`. Views call `manager.events(...)`, which reads `revision`, so Observation re-renders them.
2. **Widgets:** `TempoProvider.timeline` reads `TempoWidgetIntent` → `WidgetOptions`, fetches events through `EventReader`
   for the chosen set, builds entries at event boundaries via `TimelinePlanner`, reload policy `.after(...)`.
3. **Sets:** `CalendarSetStore` (App Group defaults) is the single source for app + widget extension on a device.
   Buttons in widgets run `SetActiveSetIntent` / `CycleSetIntent` in the extension process, update the store, reload timelines.
4. **Watch:** EventKit is read-only on watchOS. Quick-add → `WatchLink.sendAdd` (`transferUserInfo`) → iPhone parses with the
   original timestamp and saves → ack back. iPhone → watch: set definitions via `updateApplicationContext`.

## Security & privacy
- No network code, no analytics, no third-party packages.
- Sandbox + `com.apple.security.personal-information.calendars` on macOS; usage strings for Calendars/Reminders in every target.
- Meeting links: https/`zoommtg` only, exact domain match (suffix with a leading dot), SafeLinks unwrapped — see `MeetingLinkTests`.
- Deep links parse strictly (`DeepLink.init?(url:)`): unknown host/malformed path → nil; day links must match `yyyy-MM-dd`.
- Intents that mutate state (`SetActiveSetIntent`, `CycleSetIntent`) only touch the shared set preference, never events.
- WatchLink accepts only the `add` (String) and `sets` (Data → JSON-decoded `Payload`) keys; anything else is ignored.

## Concurrency notes
Package is built in Swift 5 language mode (`swiftLanguageMode(.v5)`) and apps use `SWIFT_VERSION 5.0`. `EventReader` is
`@unchecked Sendable` (EKEventStore is thread-safe for reads). `WatchLink` is `@MainActor`; delegate callbacks hop with `Task { @MainActor in }`.

## App Group on macOS
Mac targets use `$(TeamIdentifierPrefix)group.com.local.tempo` (a plain `group.` id isn't granted to a sandboxed Mac app by the automatic profile). The id is injected into Info.plist (`TempoAppGroup`) and read by `AppGroup.identifier`; iOS and watchOS keep `group.com.local.tempo`. An unsigned build (empty team) falls back to the plain id.
