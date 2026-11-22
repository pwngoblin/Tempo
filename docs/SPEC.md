# Status

| Area | State |
|---|---|
| CalendarCore (models, parser, sets, agenda, visibility, subscriptions, deep links) | done, 38 tests |
| Mac app: Day/Week/Month, command bar, sidebar, settings | done |
| Menu-bar countdown + popover (separate helper app) | done |
| iPhone app: Agenda, Week, Month, reminders, settings | done |
| Watch app: Now/Next, day list, event detail, quick add via iPhone | done |
| Widgets (iOS 8, Mac 7, watch 2) + complications | done |
| Custom widgets (Widgetry): editor, store, Custom widget on iOS + Mac | done, not tried on a real device |
| Signed builds (set `DEVELOPMENT_TEAM`) | works |

## Not done
- Custom widgets on watchOS; per-widget Calendar Set for custom widgets.
- Reminders in widgets; iCloud mirroring of Sets; localization (English only).
- Real-device checks: permissions, WatchConnectivity delivery, complications on a face.
