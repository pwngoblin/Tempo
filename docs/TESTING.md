# Testing & running

> **Never create, edit or delete calendar events/calendars while testing (see CLAUDE.md).** Unit tests are pure; UI checks are manual by the owner.

## Unit tests (38)
```sh
cd Packages/CalendarCore && swift test
```
Suites: `EventParserTests` (22), `MeetingLinkTests` (5), `AgendaTests` (5: current/next/free, busy chaining, busy merge, overlap layout, bounded timeline),
`SetAndLinkTests` (3: set matching, cycling, deep-link round trip), `SubscriptionTests` (2: accepted/rejected feed addresses), `VisibilityTests` (1).

## Build all
```sh
xcodegen generate
for s in "Tempo-macOS|platform=macOS" "Tempo-iOS|generic/platform=iOS Simulator" "Tempo-watchOS|generic/platform=watchOS Simulator"; do
  xcodebuild -project Tempo.xcodeproj -scheme "${s%%|*}" -destination "${s##*|}" CODE_SIGNING_ALLOWED=NO build
done
```
Products land in `~/Library/Developer/Xcode/DerivedData/Tempo-*/Build/Products/`.

## Release builds → `dist/`
```sh
xcodebuild -project Tempo.xcodeproj -scheme Tempo-macOS   -configuration Release -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Tempo.xcodeproj -scheme Tempo-iOS     -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Tempo.xcodeproj -scheme Tempo-watchOS -configuration Release -destination 'generic/platform=watchOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```
Copies: `dist/Tempo-macOS.app` (with widget extension), `dist/Tempo-iOS-simulator.app` (embeds widgets + watch app), `dist/Tempo-watchOS-simulator.app`.
Unsigned: the simulator apps run in simulators; the Mac app runs locally (right-click → Open if Gatekeeper complains). Device installs need a team.

## Run in simulators
```sh
xcrun simctl list pairs                              # find a booted iPhone + Watch pair
xcodebuild … -scheme Tempo-iOS     -destination "id=<phone>"
xcodebuild … -scheme Tempo-watchOS -destination "id=<watch>"
xcrun simctl install <phone> …/Debug-iphonesimulator/Tempo.app
xcrun simctl install <watch> …/Debug-watchsimulator/Tempo.app
xcrun simctl privacy <phone> grant calendar com.local.tempo.ios
xcrun simctl privacy <watch> grant calendar com.local.tempo.ios.watchkitapp
xcrun simctl launch <phone> com.local.tempo.ios ; xcrun simctl launch <watch> com.local.tempo.ios.watchkitapp
```
macOS: `open …/Debug/Tempo.app` (first launch shows the Calendar permission prompt).

## Manual checklist (needs a signed run)
- [ ] Calendar + Reminders prompts; denied state shows the access prompt
- [ ] Widget gallery lists 4 widgets; Edit Widget shows every option; options change rendering
- [ ] Set Switcher buttons change the set across widgets
- [ ] Lock Screen circular/rectangular/inline; tinted + Always-On
- [ ] watch complications (circular, corner, rectangular, inline) on a face
- [ ] watch quick-add arrives on iPhone (WatchConnectivity), ack returns
- [ ] Subscribe: enter a webcal/https feed → Calendar confirms → calendar appears in Tempo, widgets and watch
- [ ] Menu-bar countdown updates; Join opens the provider app
