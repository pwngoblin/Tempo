# UX

Follow Apple's HIG: system controls, Dynamic Type via `@ScaledMetric`, targets ≥ 44 pt, labels on icon buttons, no custom FABs.

- **Add**: Apple-Calendar-style sheet. First row is a quick-entry field ("Gym tomorrow 6pm") that fills the form; Event | Reminder switch. Watch and menu-bar popover use the compact quick add.
- **Settings**: iPhone = Apple-Settings-style list with icon tiles; Mac = tabs (General, Views, Layout, Menu Bar, Calendars, Sets, Widgets, Subscriptions). `tempo://widgets` opens the Widgets screen.
- **Interface size** (Settings → Layout): Extra compact / Compact / Default / Large. Mac zooms the whole window (⌘+ ⌘− ⌘0); iOS maps to Dynamic Type; Default follows the system.
- **Density, hour height, event block style, show end time / location / Join button**: per-user options in Settings → Layout.
- **Event details**: time, place (opens Maps), Join, calendar, repeat, people invited, notes. Widgets never show notes.
- **Watch**: Now/Next card with progress and "Then…", day list with "N left · Free/Busy until…", Tomorrow, tap for detail.
- New option = add to `AppPrefs` (tolerant decoding), a control in `PreferencesViews.swift`, use it, document here.
