# Guardian Lock QA Matrix

This matrix covers the recent biometric override, fallback PIN, and critical lock updates.

## Scope
- Guardian biometric unlock
- Guardian PIN fallback
- Android system overlay lock
- In-app iOS lock path
- Permission handling and recovery
- Rule-triggered duplicate lock prevention
- App lifecycle and navigation stability

## Test Matrix

| ID | Area | Platform | Preconditions | Steps | Expected Result | Evidence to Capture | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| QA-01 | Build sanity | Android | Fresh checkout, dependencies installed | Run `flutter pub get`, `flutter analyze`, and a debug build | No new errors; app builds successfully | Analyzer output, build log | High |
| QA-02 | Build sanity | iOS | Xcode available, pods installed | Run iOS build/debug launch | No new errors; app starts on device or simulator | Xcode build log | High |
| QA-03 | Biometric availability | Android | Device with fingerprint or face unlock enabled | Open guardian lock screen and tap Guardian Unlock | OS biometric prompt appears | Screenshot or screen recording | High |
| QA-04 | Biometric availability | iOS | Device with Face ID or Touch ID enabled | Open guardian lock screen and tap Guardian Unlock | OS biometric prompt appears | Screenshot or screen recording | High |
| QA-05 | Biometric success | Android | Biometric enrolled and permission granted | Authenticate successfully | Guardian screen closes and returns to prior app state | Screen recording | High |
| QA-06 | Biometric success | iOS | Biometric enrolled | Authenticate successfully | Guardian screen closes and returns to prior app state | Screen recording | High |
| QA-07 | Biometric cancel | Android | Biometric enrolled | Open prompt and cancel it | Screen remains locked; no navigation occurs | Screen recording | High |
| QA-08 | Biometric cancel | iOS | Biometric enrolled | Open prompt and cancel it | Screen remains locked; no navigation occurs | Screen recording | High |
| QA-09 | Biometric failure | Android | Biometric enrolled | Fail authentication several times | Screen remains locked and responsive | Screen recording | High |
| QA-10 | Biometric failure | iOS | Biometric enrolled | Fail authentication several times | Screen remains locked and responsive | Screen recording | High |
| QA-11 | PIN fallback success | Android | Guardian PIN stored in secure storage | Tap Use PIN, enter correct 4-digit PIN | Screen unlocks and overlay hides | Screen recording | High |
| QA-12 | PIN fallback success | iOS | Guardian PIN stored in secure storage | Tap Use PIN, enter correct 4-digit PIN | Screen unlocks and returns to app | Screen recording | High |
| QA-13 | PIN fallback invalid | Android | Guardian PIN stored | Enter wrong 4-digit PIN | Dialog shows invalid PIN and stays locked | Screenshot | High |
| QA-14 | PIN fallback invalid | iOS | Guardian PIN stored | Enter wrong 4-digit PIN | Dialog shows invalid PIN and stays locked | Screenshot | High |
| QA-15 | PIN format validation | Android | Guardian lock active | Enter 3 digits, 5 digits, letters, and spaces | Only 4 numeric digits are accepted; invalid input is rejected | Screenshots | Medium |
| QA-16 | PIN format validation | iOS | Guardian lock active | Enter 3 digits, 5 digits, letters, and spaces | Only 4 numeric digits are accepted; invalid input is rejected | Screenshots | Medium |
| QA-17 | Critical rule trigger | Android | Metrics can be simulated or threshold crossed | Force distance <= critical threshold or blink rate <= lock threshold | Critical lock is triggered | Screen recording, logs | High |
| QA-18 | Critical rule trigger | iOS | Metrics can be simulated or threshold crossed | Force distance <= critical threshold or blink rate <= lock threshold | In-app guardian lock is triggered | Screen recording, logs | High |
| QA-19 | Duplicate lock prevention | Android | App running, alert state can be triggered repeatedly | Fire screenLock state multiple times rapidly | Only one guardian screen or overlay appears | Screen recording, logs | High |
| QA-20 | Duplicate lock prevention | iOS | App running | Fire screenLock state multiple times rapidly | Only one guardian screen appears | Screen recording, logs | High |
| QA-21 | Android overlay permission granted | Android | SYSTEM_ALERT_WINDOW granted | Trigger critical lock | Native overlay appears above other apps | Screen recording | High |
| QA-22 | Android overlay permission missing | Android | SYSTEM_ALERT_WINDOW revoked | Trigger critical lock | App surfaces enable-overlay permission path | Screenshot, system settings capture | High |
| QA-23 | Android OS-wide behavior | Android | Overlay permission granted | Open another app while lock is active | Overlay remains visible above other app | Screen recording | High |
| QA-24 | Overlay dismiss recovery | Android | Overlay active | Authenticate successfully | Overlay hides and app returns to previous state | Screen recording | High |
| QA-25 | Back navigation blocked | Android | Guardian screen visible | Press physical back button | Screen does not dismiss | Screen recording | High |
| QA-26 | Back navigation blocked | iOS | Guardian screen visible | Swipe back or use navigation gesture | Screen does not dismiss | Screen recording | High |
| QA-27 | App lifecycle | Android | Guardian screen active | Background and foreground the app | Lock state remains stable; no crash or duplicate route | Screen recording, logs | Medium |
| QA-28 | App lifecycle | iOS | Guardian screen active | Background and foreground the app | Lock state remains stable; no crash or duplicate route | Screen recording, logs | Medium |
| QA-29 | Restart persistence | Android | PIN stored, overlay permission state known | Terminate and relaunch app | PIN still works; permission state is respected | Logs, screen recording | Medium |
| QA-30 | Restart persistence | iOS | PIN stored | Terminate and relaunch app | PIN still works after restart | Logs, screen recording | Medium |
| QA-31 | Main app regression | Android | App unlocked and operational | Open Home, Tracking, and Tasks screens | Existing app flows still work | Screenshots | High |
| QA-32 | Main app regression | iOS | App unlocked and operational | Open Home, Tracking, and Tasks screens | Existing app flows still work | Screenshots | High |
| QA-33 | Overlay escalation | Android | Warning and blink-bubble states available | Trigger warning state, then critical state | Warning overlay shows first; critical lock supersedes it | Screen recording | Medium |
| QA-34 | Overlay escalation | iOS | Warning and blink-bubble states available | Trigger warning state, then critical state | Warning overlay shows first; critical lock supersedes it | Screen recording | Medium |
| QA-35 | Permission denial | Android | Camera or biometric permissions denied | Trigger relevant flow | App fails gracefully without crash | Screenshot, logs | Medium |
| QA-36 | Permission denial | iOS | Camera or biometric permissions denied | Trigger relevant flow | App fails gracefully without crash | Screenshot, logs | Medium |

## Manual Test Notes
- Use a physical Android device for overlay validation. Emulator behavior is not sufficient for the OS-wide overlay check.
- Use a physical iPhone for Face ID and Touch ID validation. Simulator biometric behavior is only a partial check.
- If the guardian PIN is not yet set, verify the app documents or surfaces that state clearly instead of failing silently.
- Capture logs when testing duplicate lock prevention and permission recovery, because those are the most likely integration failures.

## Pass Criteria
- No crashes during lock activation, unlock, or permission recovery.
- Exactly one lock surface is active at a time.
- Biometric unlock and PIN fallback both work end-to-end.
- Android overlay remains visible above other apps when permission is granted.
- iOS behavior remains stable even though it cannot provide a true system-wide overlay.

## Suggested Execution Order
1. Build sanity and dependency checks.
2. Biometric unlock success and failure.
3. PIN fallback success and failure.
4. Overlay permission and Android cross-app behavior.
5. Duplicate lock prevention and lifecycle tests.
6. Regression pass across the rest of the app.
