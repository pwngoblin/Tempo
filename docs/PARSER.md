# Natural-language quick add

`EventParser.parse(_:now:)` is pure and deterministic (inject `calendar`, `now`). Each recognised span is blanked from a working
copy of the string (UTF-16 ranges preserved, returned as `tokens`); what remains is the title (connectors like *at/on/from* trimmed;
empty → "New Event").

| Syntax | Meaning | Example |
|---|---|---|
| `#Name` | target calendar (exact → prefix → contains match; underscores = spaces) | `#Personal` |
| `@Place`, `@"Room 4B"` | location (`@` + a letter, so `@6pm` is a time) | `@Dr_Smith` |
| `today`, `tomorrow`, `tmrw`, `tonight` (→ 20:00), `day after tomorrow` | relative day | |
| `mon`…`sun`, `next fri`, `this fri`, `on fri` | weekday: bare = today or next; `next` = strictly after today | |
| `in 3 days`, `in 2 weeks` | offset | |
| `Nov 25`, `25 Nov`, `2026-12-24` | date (past month/day rolls to next year; invalid like `Feb 30` rejected) | |
| `18:00-19:30`, `10-11am`, `11-1pm`, `10pm-1am`, `from 9 to 10` | time range (shared am/pm inferred; crossing midnight allowed) | |
| `10am`, `18:00`, `at 5`, `noon`, `midnight` | start time; bare hour 1–6 → PM, 7–11 → AM, `06:00`/`18:00` = 24h | |
| `45m`, `1h`, `1h30m`, `1.5h`, `for 2 hours` | duration (default 60 min) | |
| `all day` | all-day event | |

Date rules: time but no day → today if still in the future, else tomorrow. Day but no time → all-day (or 09:00 if a duration is
given). Nothing at all → next whole hour. Fallback: when no rule found a date, `NSDataDetector(.date)` is tried (e.g. `12/31/2027 9am`);
its wall-clock parts are read in the detector's zone and rebuilt in the parser's calendar so results stay deterministic across zones.

The preview pill (`PreviewPill`) shows title, resolved calendar (color + name), `summary` ("Fri, Nov 28 · 10:00 – 10:45") and location.
Tests: `Packages/CalendarCore/Tests/CalendarCoreTests/EventParserTests.swift` (22 cases, fixed `now` = Sat 2026-11-21 10:00 UTC).
