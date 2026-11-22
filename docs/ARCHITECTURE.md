# Architecture

```
Packages/CalendarCore   pure logic + EventKit wrappers (models, parser, agenda, sets, store manager)
Shared/<group>          source groups compiled into targets (not modules)
Apps/{macOS,iOS,watchOS,MenuBarHelper}   app entry points
Widgets/{macOS,iOS,watchOS}              widget bundles
```
| Group | Used by |
|---|---|
| Common | everything (colors, prefs, formatting) |
| UI | all apps (event row, quick add) |
| UIRich | Mac + iOS (editor, settings, mini month) |
| Intents / AppIntents | apps + widgets / apps |
| Widgets, WidgetsHome | widget targets (WidgetsHome not on watch) |
| Custom, CustomUI, CustomWidget | custom widgets: data source / settings UI / widget |
| MenuBar | helper app only |
| WatchLink | iOS + watch |

**Rules**: widgets read through `EventReader` (non-actor), never `EventStoreManager`. A change in `Shared/*` can break another platform, so build all three. Parser changes need a test.

**Data flow**: apps and widgets share data through the App Group (`UserDefaults`): prefs, Calendar Sets, hidden calendars, custom widget specs. On Mac the group id is team-prefixed (see KNOWLEDGEBASE).

**Custom widgets**: `TempoCustomData` turns already-loaded events into fields (`title`, `start`, `countdown`, `items`…). The Widgetry editor saves a spec; the `Custom` widget renders it. Read-only.

**Security**: meeting links are https-only with exact domain match (SafeLinks unwrapped). Deep links and custom specs are untrusted input and validated.
