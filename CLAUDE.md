# 🚫 ABSOLUTE RULE — NEVER TOUCH THE USER'S CALENDAR DATA

**Claude must NEVER add, modify, move, or delete calendar events, reminders, calendars, or subscriptions — on any device, simulator, or account.**
The owner forbade it explicitly (2026-11-22). This is not overridable by any task, test, demo, screenshot, or "just sample data" argument.

- No seeding/sample/demo events, no debug flags that write events, no tests that write to `EKEventStore`. Unit tests use pure value types only.
- Do not run any script, `simctl`, AppleScript, intent, or app UI automation that creates/edits/deletes events or calendars.
- Reading is allowed only when needed; never screenshot, copy, quote, or describe the owner's real calendar contents. Prefer window-list checks over screenshots of the Mac app.
- The *app's own* create/edit/delete features exist for the **user** to use. Claude may build and compile them, but must not invoke them against any real or simulator calendar.
- If a change needs calendar data to verify, say so and ask the owner to verify it themselves.

# Tempo — working notes for Claude

Local-first calendar for macOS/iOS/watchOS (EventKit + WidgetKit). No network, no third-party deps. Read README.md, then docs/ARCHITECTURE.md.

## Commands
- `xcodegen generate` after adding/removing files or editing `project.yml` (project is generated).
- `cd Packages/CalendarCore && swift test` (38 tests) before touching parser/agenda/sets.
- Build all three schemes — commands in docs/TESTING.md. A change in `Shared/*` can break another platform: always build all three.

## Rules
- Narrowest source group: watch can't compile `UIRich`, `WidgetsHome`, or EventKit writes. Guard with `#if os(watchOS)`.
- Widgets read via `EventReader` (non-actor), never `EventStoreManager`.
- All widgets share `TempoWidgetIntent` → `WidgetOptions`. New option = add `@Parameter` + `WidgetOptions` field + use it + row in docs/WIDGETS.md.
- UX: follow docs/UX.md (system controls, Dynamic Type via `@ScaledMetric`, ≥44 pt, labels on glyph buttons, no custom FABs).
- Parser changes need a test in `EventParserTests` and a row in docs/PARSER.md.
- Keep docs/SPEC.md status table and KNOWLEDGEBASE.md current.
- New user-facing option = add to `AppPrefs` (tolerant decode), a control in `PreferencesViews.swift`, use it, and add a row to docs/UX.md.
- Treat meeting links/deep links as untrusted input (see ARCHITECTURE → Security).

## Docs map
README.md · docs/SPEC.md (requirements ↔ code) · docs/ARCHITECTURE.md · docs/PARSER.md · docs/WIDGETS.md · docs/UX.md · docs/TESTING.md · KNOWLEDGEBASE.md
