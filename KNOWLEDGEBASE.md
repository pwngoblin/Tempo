# Gotchas (read before changing things)

**Calendar data**
- Never write to the user's calendars while testing. Unit tests use plain values only.
- EventKit is read-only on watchOS; the watch sends quick-add text to the iPhone (WatchConnectivity).
- EventKit can't create subscribed calendars; we hand a `webcal://` URL to the system Calendar.

**macOS**
- No `TimelineView` in a `MenuBarExtra` label (infinite redraw, 2 GB RAM). Use a timer-fed model.
- Don't write to an observable store from a Binding you give a scene (stack overflow at launch).
- The menu bar lives in a separate helper app (`TempoMenuBar`) so it survives quitting Tempo.
- `.dynamicTypeSize` does nothing on macOS; "Interface size" is a layout zoom (`InterfaceScale`).
- **App Group id must be team-prefixed on Mac** (`$(TeamIdentifierPrefix)group.com.local.tempo`, read from Info.plist key `TempoAppGroup`). With the plain id, shared storage silently fails and file writes give NSCocoaErrorDomain 513.
- Test sandbox behaviour by launching with `open` (the binary run from a shell hides sandbox problems).
- `open tempo://…` may hit a stale copy (Xcode DerivedData). Use `open -a /full/path/Tempo.app tempo://…`.

**Widgets**
- Widgets are separate processes with their own permissions. In the simulator grant Calendar per bundle (`simctl privacy`).
- After reinstalling simulator apps, re-add widgets; reboot the simulator if widgets stay on the placeholder.
- Accessory families don't exist on macOS. watchOS needs `recommendations()`; keep it to one default entry (per-set entries crashed the extension).
- App Intents (widget pickers) must be defined in the widget target, not in a package.

**Signing**
- The number in a signing identity name is a person id. The Team ID is the certificate's OU.
- Automatic signing needs `-allowProvisioningUpdates` and an Apple ID in Xcode. Manual signing fails (App Group needs a profile).

**Process**
- Icon work: show several options instead of guessing.
- UI changes can't be verified on the user's real calendar; render with synthetic data or ask the owner.
