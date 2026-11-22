# Widgets

All fixed widgets share one configuration (`TempoWidgetIntent`): calendar set, days ahead, max events, all-day / locations / calendar names / meeting icon / following event, density, colors, tint, background, time format, countdown style, inline text, week numbers, week-grid hours, now line. Add an option in three places: intent parameter, `WidgetOptions`, the view that uses it.

| Widget | iOS | Mac | Watch |
|---|---|---|---|
| Next Event (small/medium, lock screen, complications) | yes | small/medium | yes |
| Today at a Glance | lock screen | no | yes |
| Agenda, Month+Agenda, Month, Day Timeline, Week Schedule | yes | yes | no |
| Set Switcher | yes | yes | no |
| **Custom** (your own design) | S/M/L | S/M/L | no |

Timelines are bounded (`TimelinePlanner`); countdowns use `Text(date, style: .timer)` so they tick without reloads.

## Custom widgets
Settings → **Widgets** → pick a template → edit in the visual editor → add the **Custom** widget and choose the design. The editor comes from the [Widgetry](https://github.com/pwngoblin/Widgetry) package (`../Widgetry`).

Fields you can use: text `title subtitle location calendar meeting when status heading`; dates `start end countdown freeUntil busyUntil`; numbers `progress minutes leftToday todayCount`; flags `isActive hasEvent hasLocation hasMeeting isFree`; lists `items today` (row fields `item.title item.start item.end item.when item.day item.location item.calendar`).

Designs live in the App Group's `UserDefaults` (`widgetry.specs.v1`). Data comes from the active Calendar Set, next 7 days.
