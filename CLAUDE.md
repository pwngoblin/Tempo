# 🚫 ABSOLUTE RULE: NEVER TOUCH THE USER'S CALENDAR DATA

Claude must NEVER add, modify, move or delete calendar events, reminders, calendars or subscriptions, on any device or simulator. The owner forbade it (2026-11-22). Nothing overrides this.
- No seed/demo events, no tests writing to `EKEventStore`, no automation that creates/edits/deletes.
- Never screenshot, copy, quote or describe the owner's real calendar contents. Use synthetic data or window-list checks.
- The app's create/edit features are for the user only. If something needs calendar data to verify, ask the owner.

# Tempo: working notes

Local-first calendar for macOS/iOS/watchOS (EventKit + WidgetKit). Read README.md, then docs/ARCHITECTURE.md and KNOWLEDGEBASE.md.

## Commands
- `xcodegen generate` after adding files or editing `project.yml`.
- `cd Packages/CalendarCore && swift test` (38 tests).
- Build all three schemes (docs/TESTING.md). A change in `Shared/*` can break another platform.

## Rules
- Use the narrowest source group. Watch can't compile `UIRich`, `WidgetsHome` or EventKit writes (`#if os(watchOS)`).
- Widgets read via `EventReader`, never `EventStoreManager`. New widget option = intent parameter + `WidgetOptions` + view.
- New user option = `AppPrefs` + control in `PreferencesViews.swift` + use it + a line in docs/UX.md.
- Parser changes need a test + a row in docs/PARSER.md.
- Meeting links, deep links and custom widget specs are untrusted input.
- Keep docs short. Update docs/SPEC.md status and KNOWLEDGEBASE.md when things change.
- Custom widgets: engine/editor live in the sibling repo Widgetry (`../Widgetry`). Keep Tempo's side thin (`Shared/Custom*`).
- No secrets, team IDs, emails or device ids in the repo (it's public).
