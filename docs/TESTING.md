# Testing & running

Never create, edit or delete calendar data while testing. Unit tests use plain values only; UI checks are manual.

```sh
(cd Packages/CalendarCore && swift test)      # 38 tests
xcodegen generate
for s in "Tempo-macOS|platform=macOS" "Tempo-iOS|generic/platform=iOS Simulator" "Tempo-watchOS|generic/platform=watchOS Simulator"; do
  xcodebuild -project Tempo.xcodeproj -scheme "${s%%|*}" -destination "${s##*|}" CODE_SIGNING_ALLOWED=NO build
done
```
Signed Mac build (widgets + menu bar): add `-allowProvisioningUpdates DEVELOPMENT_TEAM=<your team>`.

Simulators: install the iOS/watch `.app` with `xcrun simctl install`, launch with `xcrun simctl launch <udid> com.local.tempo.ios` (watch: `com.local.tempo.ios.watchkitapp`). Grant Calendar to the app and its widget bundle with `xcrun simctl privacy <udid> grant calendar <bundle id>`.
Mac: launch with `open` (not the raw binary) when checking sandbox behaviour.
