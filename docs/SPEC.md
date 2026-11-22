# Spec & status

Original brief (condensed) and where each requirement lives. ✅ built + compiles · 🧪 unit-tested · ⚠️ deviates / needs a signed device run.

## 1. Shared package `CalendarCore`
| Requirement | Status | Where |
|---|---|---|
| Shared package for mac/iOS/watch + widgets, App Group `group.com.local.tempo` | ✅ | `Packages/CalendarCore`, `AppGroup.swift` |
| `EventStoreManager` (`@Observable`), `.fullAccess`, events + reminders | ✅ | `EventStoreManager.swift` (reminders: not on watchOS) |
| Observe `.EKEventStoreChanged` → refresh UI + `WidgetCenter.reloadAllTimelines()` | ✅ | `EventStoreManager.startObserving/bump` |
| CRUD + recurring spans (`.thisEvent`, `.futureEvents`) | ✅ ⚠️ | `create/update/delete`; **watchOS is read-only** (see KNOWLEDGEBASE) |
| Calendar Sets (All / Work / Personal …) | ✅ 🧪 | `CalendarSet.swift` |
| Deterministic NL parser (`NSDataDetector` + regex) with live preview pill | ✅ 🧪 | `EventParser.swift`, `Shared/UI/QuickAddView.swift` |
| Meeting-link extractor (Teams/Zoom/Webex/Meet) | ✅ 🧪 | `MeetingLink.swift` |

## 2. macOS
| Requirement | Status | Where |
|---|---|---|
| Day / Week time grid, now-line, drag-to-create, drag-to-resize | ✅ | `Apps/macOS/TimeGridView.swift` |
| Month view | ✅ | `MonthView.swift` |
| Quick-add command bar ⌘N / ⌘K | ✅ | `RootView.swift` (`CommandBar`), `TempoMacApp.swift` (`TempoCommands`) |
| `MenuBarExtra` live countdown ("GRC Sync · 12m") | ✅ | `MenuBar.swift` (`MenuBarLabel`) |
| Popover: mini month, today/tomorrow, set switcher, quick-add, Join | ✅ | `MenuBar.swift` (`MenuBarPopover`) |

## 3. iOS & watchOS
| Requirement | Status | Where |
|---|---|---|
| iOS Agenda, Week strip, Month, haptics, quick-add, Reminders | ✅ | `Apps/iOS` |
| watchOS today agenda, now/next countdown, set filter | ✅ | `Apps/watchOS` |
| watchOS voice/text quick-add (`AppIntent`/dictation) | ⚠️ | writes via iPhone (`Shared/WatchLink`, `Shared/AppIntents`) |
| Bounded timeline schedules | ✅ 🧪 | `TimelinePlanner` |

## 4. Widgets & complications
| Requirement | Status | Where |
|---|---|---|
| Split Month + Dense Agenda (M/L) | ✅ | `WidgetsHome/MonthAgendaWidget.swift` |
| Interactive Calendar Set Switcher | ✅ | `WidgetsHome/SetSwitcherWidget.swift`, `Intents/SetIntents.swift` |
| Current/Next + free-time (S/M, Lock Screen, watch families) | ✅ | `Widgets/NextEventWidget.swift` |
| Visual Week Schedule (L) | ✅ | `WidgetsHome/WeekScheduleWidget.swift` |
| AOD + accented/tinted rendering | ✅ ⚠️ | `.widgetAccentable()`, `isLuminanceReduced` — verify on hardware |
| **Fully customizable widgets (added)** | ✅ | `Intents/WidgetConfiguration.swift` — see `WIDGETS.md` |

## 5. Added after the first pass
| Item | Status | Where |
|---|---|---|
| Subscribe to calendars by URL (webcal/https ICS) | ✅ 🧪 ⚠️ | `CalendarSubscription.swift`, `UIRich/SubscriptionsView.swift`; hand-off to system Calendar (no API to subscribe silently) |
| Unsubscribe / list subscribed calendars | ✅ | `EventStoreManager.removeCalendar` (not watchOS) |
| iOS agenda restyle (time column, plain list, red "today") | ✅ | `Shared/UI/EventViews.swift`, `Apps/iOS/Screens.swift` |
| iOS Week = strip + day hour timeline | ✅ | `Apps/iOS/DayTimeline.swift` |
| **Deep app customization** (theme, accent, 12/24h, week start, week numbers, density, block style, hour height, work week, agenda length, default view/length/calendar, haptics, menu-bar options, calendar visibility) | ✅ 🧪 | `Shared/Common/AppPreferences.swift`, `Shared/UIRich/PreferencesViews.swift`, `CalendarVisibility` |
| More iOS widgets: Agenda, Month, Today Timeline, Today at a Glance (Lock Screen + watch) | ✅ ⚠️ | `Shared/WidgetsHome/MoreWidgets.swift`, `Shared/Widgets/TodayGlanceWidget.swift` |
| Custom app icon v2: time ring + calendar page (no SF Symbol; v1 waveform bars rejected) | ✅ | `Branding/make_icon.swift` (`swift make_icon.swift . final`) |
| **Menu bar survives quitting the app**: separate `TempoMenuBar` helper (LSUIElement) embedded as a login item; main app launches it, ⌘Q leaves it running | ✅ | `Apps/MenuBarHelper`, `Shared/MenuBar`, `Apps/macOS/MenuBarHelper.swift` |
| Signed builds (set `DEVELOPMENT_TEAM` in `project.yml`, App Group + sandbox, profiles via Xcode account) | ✅ | `project.yml`; widgets register with macOS only when signed |
| App icon: "Midnight grid, ring on today" (light/dark/tinted on iOS, dark on watch); macOS uses the calendar-page icon (white page, coral header, three colour bars) | ✅ ⚠️ | `Branding/make_icon.swift`, `Branding/mac_options.swift` |
| Release builds of all three apps | ✅ | `dist/` (git-ignored) |
| macOS window launch hang fixed (menu-bar label loop) | ✅ | `Shared/MenuBar/MenuBarUI.swift` (`MenuBarModel`) |

## 6. Plan items
Layout/targets/Info.plist keys/entitlements → `project.yml`, `ARCHITECTURE.md`. Parser unit tests → `CalendarCoreTests`.

## Not done / follow-ups
- Custom (user-designed) widgets: integrated via the Widgetry package (iOS + macOS). Not yet: watchOS, drag-to-reorder in the editor, per-widget Calendar Set choice (uses the active set), real-device verification.
- Signed on-device run (permissions, widget data access, WatchConnectivity delivery, complications on a face).
- iCloud key-value mirroring of Calendar Sets needs the capability + a team.
- Reminders aren't shown in widgets (would need a Reminders grant inside the extension).
- Notes (first 500 chars) and attendee count are carried in `EventItem` and shown on the detail cards (iOS/macOS) and the watch detail page; widgets never show notes.
- Localization: strings are English; formats are locale-aware.
