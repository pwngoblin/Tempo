# Widgets & complications

Every widget uses **one** configuration intent, `TempoWidgetIntent` (`Shared/Intents/WidgetConfiguration.swift`), so any option can be
tuned on any widget: long-press → *Edit Widget* (iOS/macOS) or edit the complication on the watch face. Options that don't apply to a
widget or family are ignored. The intent is snapshotted into `WidgetOptions` (`Shared/Widgets/WidgetOptions.swift`) before rendering.

## Widgets
| Widget (`kind`) | Families | Platforms |
|---|---|---|
| Agenda (`TempoAgenda`) | systemSmall, Medium, Large, **ExtraLarge** (iPad) | iOS, macOS (no XL) |
| Month (`TempoMonth`) — big grid, tap a day | systemLarge, **ExtraLarge** (iPad) | iOS, macOS (L) |
| Today Timeline (`TempoDayTimeline`) — hour grid + now line | systemMedium, systemLarge | iOS, macOS |
| Today at a Glance (`TempoTodayGlance`) — ring of events left | accessoryCircular, Rectangular, Inline · accessoryCorner (watch) | iOS, watchOS |
| Next Event (`TempoNextEvent`) | systemSmall, systemMedium · accessoryCircular, Rectangular, Inline · **accessoryCorner** (watch) | iOS, macOS (S/M), watchOS (accessory + corner) |
| Month + Agenda (`TempoMonthAgenda`) | systemMedium, systemLarge | iOS, macOS |
| Calendar Sets switcher (`TempoSetSwitcher`) — interactive buttons | systemMedium, systemLarge | iOS, macOS |
| Week Schedule (`TempoWeekSchedule`) | systemLarge | iOS, macOS |

Taps deep-link with `tempo://…` (`event/<id>`, `day/yyyy-MM-dd`, `today`, `set/<uuid>`, `add?text=`).

## Options
| Option | Values | Applies to |
|---|---|---|
| Calendar Set | any set / empty = follow active | all except the switcher (always active set) |
| Days ahead | 1–14 (watch: capped at 2) | agenda lists, switcher |
| Max events | 0 = fit to size, 1–20 | agenda lists |
| All-day events | on/off | all |
| Locations · Calendar names | on/off (comfortable density only) | agenda lines |
| Meeting icon | on/off | agenda lines |
| Following event | on/off | Next Event medium, rectangular |
| Density | compact (15 pt rows) / comfortable (19 pt) | agenda lines |
| Colors | calendar colors / single tint / monochrome | all colored elements |
| Tint | blue, red, orange, yellow, green, mint, teal, indigo, purple, pink | tint style, switcher chips, today marker, tinted background |
| Background | system / tinted / none | home-screen & desktop widgets |
| Time format | system / 12-hour / 24-hour | all times |
| Countdown | live timer / relative / hidden | Next Event (small, medium, circular next-ring) |
| Inline text | smart / next·time / next·countdown / free-busy until | accessoryInline |
| Week numbers | on/off | month grid |
| Fit hours · from · to · now line | auto or fixed hour range, now line on/off | Week Schedule |

Watch complications can't show an editor on the iPhone, so `TempoProvider.recommendations()` offers the active set plus one pinned
recommendation per custom set (up to 4); further tuning is done on the face.

## Rendering rules
- `containerBackground(for: .widget)` everywhere; accessory families use `AccessoryWidgetBackground`/clear.
- Colored elements (bars, dots, today marker, chips) carry `.widgetAccentable()` so accented/tinted modes recolor them instead of
  clashing; text stays `.primary/.secondary`.
- Always-On: `isLuminanceReduced` drops the third line of the rectangular complication.
- Live countdowns use `Text(date, style: .timer)` / `ProgressView(timerInterval:)`: no per-minute timeline entries.
- Every glyph-only control has an accessibility label; the circular complication gets a spoken summary.

## Timelines (`TimelinePlanner`)
Entries only at: now, each event start/end in the horizon, next midnight; capped (iOS/macOS 24 entries, 24 h horizon, ≥15 min
between reloads; watchOS 10 entries, 12 h, ≥30 min). Reload policy `.after(max(lastEntry, now+minReload))`. Event changes in the app
trigger `reloadAllTimelines()`.

## Data access caveat
Widgets read EventKit directly in the extension. This needs the app's Calendar grant and, on macOS, the calendars sandbox
entitlement in the extension (declared). Verify on a signed build.

- **Complications (rectangular):** Next Event shows place (or meeting provider, or the following event) under the time; Today at a Glance adds "Busy/Free until …".

## Custom widgets (Widgetry)
Besides the fixed widgets above, users can **design their own**: Settings → **Widgets** (Mac tab / iPhone "Custom Widgets") → New Widget → pick a template → edit in the visual editor (live preview, outline, inspector). Then add the **Custom** widget from the gallery (small / medium / large, iPhone + Mac) and choose which design it shows. Engine and editor come from the sibling package **Widgetry** (https://github.com/pwngoblin/Widgetry; `project.yml` references it at `../Widgetry`, so clone it next to this repo).

- Specs are stored in the App Group's shared `UserDefaults` (`widgetry.specs.v1`) via `TempoSpecStore`; saving reloads widget timelines. (A file in the group container fails on the Mac with NSCocoaErrorDomain 513 when the app is launched normally — see KNOWLEDGEBASE.)
- The editor shows the widget on a wallpaper (tap an element to select it), a palette of elements, an outline, and an inspector: text size/weight/design/italic/uppercase, theme or custom hex colours, fills with rounded corners, opacity, fixed size, padding, spacing/alignment, show/hide conditions, and a solid or gradient widget background.
- `TempoCustomData` (`Shared/Custom`) is the calendar data source. It only reads events already loaded through `EventReader` for the active Calendar Set (next 7 days).
- Fields: text `title subtitle location calendar meeting when status heading`, dates `start end countdown freeUntil busyUntil`, numbers `progress minutes leftToday todayCount`, flags `isActive hasEvent hasLocation hasMeeting isFree`, lists `items today` (rows: `item.title start end when day location calendar`).
- The entity picker/intent/provider live in `Shared/CustomWidget` (App Intents must be in the extension target). Not on watchOS yet.
