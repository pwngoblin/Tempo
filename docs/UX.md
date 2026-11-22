# UX principles (Apple HIG)

Applied from the apple-hig skill (iOS 26/27 "Liquid Glass" generation; verify exact values on Apple).

## System-wide
- **System controls only** (segmented control, Menu, toolbar, sheets, popovers, `List`, `Form`); no custom chrome.
- **Semantic colors/materials**, calendar colors only for data. Light/dark automatic; no hard-coded text colors.
- **Dynamic Type**: text styles everywhere; circles/cells that hold text use `@ScaledMetric` (week-strip days, month cells).
- **Targets ≥ 44 pt** on iOS (month cells, week-strip days, toolbar buttons); glyph-only buttons have `accessibilityLabel`s;
  selected state exposed with `.isSelected` (never color alone).
- **Haptics** are semantic: `.success` on save, `.selection` on date change, soft impact on primary action.
- **Motion** is short (`.snappy`) and respects Reduce Motion via system animations.
- **Privacy**: purpose strings state that nothing leaves the device.

## iOS
- Primary action (`+`) lives in the toolbar, not a custom floating button; secondary actions in an overflow `Menu` (Today, Calendar Sets…).
- The set picker shows the **set name**, not just an icon.
- Tap an event → **detail sheet** (medium/large detents) with Join, map link, Edit; long-press → context menu (Join, Edit, Delete);
  swipe → Delete (non-recurring only; recurring goes through the editor's span choice).
- Empty states use `ContentUnavailableView`.

### iOS lists (revised)
Plain list, no card backgrounds. Day header = `TODAY  Sunday, Nov 22` (today in red). Rows: start time (semibold) over end time in a fixed
Dynamic-Type-scaled column, a 4 pt calendar-color bar, title (2 lines), place with a pin. Week mode = week strip + a real day hour grid
(side-by-side overlaps, now line, swipe left/right for adjacent days, tap → detail). Month = grid + the same list below.

## macOS
- Sidebar is a real `.sidebar` list with selection; toolbar actions are also menu commands (⌘N/⌘K new, ⌘T today, ⌘←/→, ⌘1/2/3 views, ⌘[ ⌘] sets).
- Click an event → **popover** card; Edit… opens the editor sheet; drag empty space to create, drag the bottom edge to resize (15-min snap).
- ⌘K command bar: material card, Esc dismisses, focus lands in the field.
- Menu-bar extra uses `.window` style popover; Join is the first, prominent control when a meeting is current or within 15 min.

## watchOS
- One primary action per screen (`+` in the top-trailing toolbar slot; a bottom-bar button floats over the first row), shallow hierarchy, Digital-Crown scrolling `List`.
- Background tints to the current/next event's color; large "NOW/NEXT" card with live system countdown.
- Quick-add is dictation-friendly (TextField); result confirmation arrives as a short line from the iPhone.
- Complications: one focused datum per family; corner uses a curved `widgetLabel`.

## Open design questions
- iOS: consider a tab bar (Agenda/Week/Month) vs. the segmented control; segmented kept because the three are views of one data set.
- macOS: calendar visibility toggles in the sidebar (currently read-only dots).
- Widgets: an in-app gallery that previews each option set.

## Customization (everything is the user's call)
All settings live in `AppPrefs` (JSON in the App Group, tolerant decoding, one `PrefsStore.shared` observable singleton that views read in `body`).
Widgets read the same values (`PrefsSnapshot`), so week start and 12/24-hour agree between app and widgets.

| Area | Options |
|---|---|
| Appearance | theme (system/light/dark), accent color (12), time format, first day of week, week numbers |
| Event style | density (compact/comfortable/spacious), block style (tinted/solid/outlined, live preview), end time, locations, Join button |
| Grid | hour height (0.7×–1.8×), opens scrolled to hour, work-week-only (Mac), all-day strip (Mac) |
| Views | iPhone: opens in Agenda/Week/Month, agenda days (7–60), reminders; Mac: opens in Day/Week/Month |
| New events | default length, default calendar, haptics |
| Menu bar (Mac) | show/hide, show title, countdown format (12m / 12 min), title length, Join lead time |
| Calendars | show/hide per calendar (apps + widgets + menu bar), Calendar Sets, subscriptions |
| Reset | "Reset All Customization…" (never touches calendar data) |

Hiding a calendar only filters what Tempo shows (`CalendarVisibility`); it never edits the calendar.

## Quick add (redesigned)
Large field with a leading icon and clear button → a **preview card** (calendar-coloured edge, title, chips for time / place / calendar) → an explicit **Add** button (also Return). While nothing parses, tappable example phrases fill the field (they never create anything). Watch: compact preview plus a "Send to iPhone" button.

## Information density (watch + widgets)
- **Watch app:** the Now/Next card shows time range, place, meeting provider, a live progress bar for the current event and a "Then …" line. The list header reads "Today · N left · Free/Busy until …", a Tomorrow section follows, and tapping any row opens a detail page (calendar, duration, place, meeting host, repeat, countdown). Rows show place or meeting provider.
- **Small Next Event widget:** now honours the existing toggles — Locations, Calendar names, Meeting icon, Following event — and adds a progress bar for the current event plus duration. Turn them on/off per widget in Edit Widget.

## Add (Apple-Calendar style)
The Mac command bar (⌘N/⌘K) and the iOS Add sheet open `AddEventView`, modelled on Apple Calendar's New Event sheet: a grouped form (title, location, all-day, start/end, calendar) with Cancel / Add. Its first row is a **quick-entry field** ("Type it: Gym tomorrow 6pm") that fills the fields as you type; everything stays editable. There is no mode switch. The watch and the menu-bar popover keep the compact `QuickAddView`. An **Event | Reminder** segment under the quick-entry field switches the form to a single Due date for reminders.

## Interface size (make it smaller)
Settings → Layout → **Interface size**: Extra compact / Compact / Default / Large.
- **macOS** has no Dynamic Type, so the main window is zoomed as a whole (0.8× / 0.9× / 1× / 1.15×) — more of the calendar fits when smaller. Shortcuts: **⌘+** zoom in, **⌘−** zoom out, **⌘0** actual size (View menu). Settings and system popovers keep their normal size.
- **iOS** maps the step to Dynamic Type (xSmall / small / system / xLarge) plus control size; *Default* follows the system text size.
- Independent from **Density** (row padding), **Hour height** and the per-widget Density option, so they can be combined.
