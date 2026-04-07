# SIGHT QA Run Sheet (Execution Checklist)

Date: 2026-04-07
Project: SIGHT Mobile App
Platforms: Android and iOS
Build Under Test: ______________________
Tester Name: ______________________
Device/OS: ______________________

## How To Use

For each test item:
- Mark status: [ ] Pass  [ ] Fail  [ ] Blocked  [ ] N/A
- Attach evidence (screenshot, screen recording, logs)
- Add notes and defect ID if failed

Template per item:
- Status: [ ] Pass  [ ] Fail  [ ] Blocked  [ ] N/A
- Evidence: ______________________
- Notes/Defect ID: ______________________

---

## 1. Build and Launch Gate

### 1.1 Project Sanity
- [ ] flutter pub get succeeds
- [ ] flutter analyze has no blocking errors
- [ ] Android debug build succeeds
- [ ] iOS debug build succeeds
- [ ] App launches on Android without crash
- [ ] App launches on iOS without crash

### 1.2 Startup Routing
- [ ] No session routes to Welcome screen
- [ ] Guardian session with PIN routes to Guardian Control Center
- [ ] Guardian session without PIN routes to Guardian Setup
- [ ] Child session routes to Child app flow

---

## 2. Screen Validation (Both Platforms)

## 2.1 Welcome Screen
- [ ] SIGHT title and subtitle render correctly
- [ ] Get Started navigates to Auth Options
- [ ] Layout is stable on small and large screens

## 2.2 Auth Options Screen
- [ ] Login button opens Login screen
- [ ] Register Guardian button opens Register screen
- [ ] Lumi shell renders without clipping/overflow

## 2.3 Login Screen
- [ ] Guardian/Child role switch changes visible inputs
- [ ] Guardian login success route is correct
- [ ] Guardian invalid credentials show proper error
- [ ] Child login success route is correct
- [ ] Child invalid credentials show proper error
- [ ] Continue button disables during loading

## 2.4 Register Guardian Screen
- [ ] Valid registration succeeds
- [ ] Duplicate guardian account is rejected with clear message
- [ ] Password mismatch shows validation error
- [ ] Invalid email path shows validation error
- [ ] Post-register route is correct (setup or dashboard)

## 2.5 Guardian Setup Screen
- [ ] Valid 4-digit PIN can be saved
- [ ] Non-digit PIN is rejected
- [ ] PIN not 4 digits is rejected
- [ ] PIN mismatch is rejected
- [ ] Mandatory setup blocks back navigation
- [ ] Success navigates to Guardian Control Center

## 2.6 Guardian Access Screen
- [ ] Authenticate with Biometrics succeeds when available
- [ ] Biometric cancel/failure keeps user on access screen
- [ ] Use Guardian PIN opens PIN dialog
- [ ] Valid PIN unlocks access
- [ ] Invalid PIN stays locked and shows error
- [ ] If no PIN configured, flow redirects to setup

## 2.7 Guardian Override Screen (Critical Lock)
- [ ] Screen appears on critical trigger
- [ ] Back navigation cannot dismiss lock
- [ ] Biometric unlock succeeds and returns to app
- [ ] Biometric failure does not unlock
- [ ] PIN unlock succeeds and returns to app
- [ ] Invalid PIN does not unlock
- [ ] Overlay-permission action appears when needed

## 2.8 Guardian Control Center Screen
- [ ] Screen loads preferences correctly
- [ ] Logout clears session and routes to auth
- [ ] Set Child opens dialog and saves valid numeric child ID
- [ ] Invalid child ID input is rejected
- [ ] Save Safety Settings persists local changes
- [ ] Save Safety Settings attempts server sync

Settings controls:
- [ ] Daily screen time slider updates and persists
- [ ] Distance alert slider updates and persists
- [ ] Critical lock slider updates and persists
- [ ] Blink threshold slider updates and persists
- [ ] Monitoring mode dropdown updates and persists
- [ ] Rule enforcement switch updates and persists
- [ ] Auto-enforce breaks switch updates and persists
- [ ] Weekend relaxed mode switch updates and persists
- [ ] Parent notifications switch updates and persists

Child account and shortcuts:
- [ ] Add Child dialog creates account successfully
- [ ] Add Child dialog validates bad input paths
- [ ] Open Add Child Screen button navigates correctly
- [ ] Child Dashboard button navigates correctly
- [ ] Connect Doctor button navigates correctly
- [ ] Change Guardian PIN dialog works for success/failure paths

## 2.9 Add Children Screen
- [ ] Back button returns correctly
- [ ] Create Child Account succeeds with valid inputs
- [ ] Non-numeric child ID rejected
- [ ] Missing guardian session handled with error
- [ ] Success shows generated child login code

## 2.10 Child Dashboard Screen
- [ ] Header and cards render correctly
- [ ] Back navigation returns correctly
- [ ] No overflow on small devices

## 2.11 Connect With Doctor Screen
- [ ] Doctor Name input accepts text
- [ ] Clinic Code input accepts text
- [ ] Optional Notes accepts multiline text
- [ ] Send Request shows confirmation snackbar
- [ ] Back navigation returns correctly

## 2.12 Home Screen
- [ ] Home UI renders without errors
- [ ] Informational cards/text are visible and readable

## 2.13 Tracking Screen
- [ ] Camera/tracking initializes
- [ ] Rule banner updates by alert state
- [ ] Alert overlays/messages show expected content
- [ ] No crash on pause/resume app lifecycle

## 2.14 Tasks Screen
- [ ] Tasks and score display correctly
- [ ] Completion indicators update correctly
- [ ] Guardian access icon opens Guardian Access screen

## 2.15 Calibration Screen
- [ ] Calibration screen opens
- [ ] Start Calibration action is responsive
- [ ] Cancel returns to previous screen

---

## 3. Navigation and Root App Shell

- [ ] Bottom navigation tabs switch correctly
- [ ] Correct page remains visible per selected tab
- [ ] No duplicate route stacking from tab interactions
- [ ] Root alert listener triggers lock only once per critical event burst

---

## 4. Security and Locking Behavior

## 4.1 Guardian PIN Rules
- [ ] PIN must be exactly 4 numeric digits
- [ ] Incorrect PIN always rejected
- [ ] PIN change requires valid current PIN
- [ ] New PIN cannot equal current PIN

## 4.2 Biometric Behavior
- [ ] Biometric capability check works
- [ ] Success unlocks protected path
- [ ] Cancel/fail leaves protected path locked

## 4.3 Critical Lock End-to-End
- [ ] Critical threshold triggers lock
- [ ] Duplicate triggers do not create duplicate lock surfaces
- [ ] Successful unlock clears lock state

---

## 5. Android Platform-Specific Checklist

## 5.1 Overlay Permission and Settings
- [ ] Overlay permission state detected correctly
- [ ] Missing permission path opens system settings
- [ ] Returning from settings updates overlay capability state

## 5.2 Method Channel Overlay Actions
- [ ] showCriticalOverlay succeeds
- [ ] hideCriticalOverlay succeeds
- [ ] isCriticalOverlayShowing reports accurately
- [ ] Error handling is graceful if method channel fails

## 5.3 OS-Wide Overlay Behavior
- [ ] Overlay remains visible above other apps when active
- [ ] Overlay clears after guardian unlock
- [ ] No crash during rapid foreground/background transitions with overlay active

---

## 6. iOS Platform-Specific Checklist

## 6.1 Biometric and Permission Behavior
- [ ] Face ID/Touch ID prompt appears with correct usage text
- [ ] Biometric success/failure behavior matches lock requirements

## 6.2 In-App Lock Constraints
- [ ] In-app lock remains stable through app lifecycle changes
- [ ] No unintended dismissal via gestures/back stack

---

## 7. Data, Persistence, and DB Migration

## 7.1 Session and Identity Persistence
- [ ] Guardian session persists after restart
- [ ] Child session persists after restart
- [ ] Active child context persists after restart
- [ ] Logout clears session and role identifiers

## 7.2 Preferences and Rules Persistence
- [ ] Guardian preferences reload correctly after restart
- [ ] Rule engine reflects persisted thresholds and active state

## 7.3 Offline Database Behavior
- [ ] DB initializes correctly on fresh install
- [ ] Migration path works (v1 to v2 where applicable)
- [ ] Raw events include child_id where expected
- [ ] Curated batches store sync metadata fields

---

## 8. Sync and API Checklist

## 8.1 API Configuration
- [ ] Missing API base URL surfaces clear error paths
- [ ] Valid API base URL enables sync calls

## 8.2 Session Limits Sync
- [ ] Pull session limits success maps values correctly
- [ ] Pull failure path handled without crash
- [ ] Push session limits success handled correctly
- [ ] Push failure path surfaces clear status

## 8.3 Metrics Sync
- [ ] Pending batches discovered correctly
- [ ] Sync success marks records as synced and stores remote ID
- [ ] Sync failure increments retry count and stores last error
- [ ] Sync attempts are resilient to network interruption

## 8.4 API Client Robustness
- [ ] GET/POST/PUT parse success payloads correctly
- [ ] Non-2xx responses surface useful errors
- [ ] Timeout behavior is handled gracefully

---

## 9. Service-Level Function Validation

## 9.1 Core Security Services
- [ ] GuardianAuthService: authenticateWithBiometrics
- [ ] GuardianAuthService: saveFallbackPin/loadFallbackPin/verifyFallbackPin
- [ ] GuardianSetupService: createGuardianPin/changeGuardianPin/verifyPinAccess

## 9.2 Guardian Control Services
- [ ] GuardianPreferencesService: load/save/pull/push
- [ ] RuleEngineService: initialize/evaluate/trigger/applyGuardianPreferences/triggerCriticalLock
- [ ] CriticalOverlayService: permission/show/hide/check/settings actions

## 9.3 Auth and Identity Services
- [ ] AuthAccountService: guardian register/auth, child create/auth/list
- [ ] AuthSessionService: save/load/clear token and role sessions
- [ ] ActiveChildContextService: initialize/get/set behavior

## 9.4 Data and Sync Services
- [ ] OfflineDatabaseService: schema and CRUD lifecycle
- [ ] LocalMetricsService: event logging, curation, background sync
- [ ] ServerSyncService: metric upload, session limits fetch/upsert
- [ ] ApiClientService and ApiConfigService: endpoint/headers/response parsing

## 9.5 Monitoring and Support Services
- [ ] DetectionService initialization and recovery paths
- [ ] MetricsService notifier updates
- [ ] BackgroundNotificationService start/refresh/stop behavior
- [ ] AppLifecycleService state tracking behavior
- [ ] GamificationService state updates and inventory writes

---

## 10. Buttons and Dialog Actions Audit

Run each action in at least one success path and one invalid/error path where applicable:
- [ ] Get Started
- [ ] Login
- [ ] Register Guardian
- [ ] Continue
- [ ] Create Guardian Account
- [ ] Save Guardian PIN
- [ ] Authenticate with Biometrics
- [ ] Use Guardian PIN
- [ ] Unlock (PIN dialogs)
- [ ] Cancel (dialogs)
- [ ] Guardian Unlock
- [ ] Enable Overlay Permission
- [ ] Set Child
- [ ] Save Safety Settings
- [ ] Add Child
- [ ] Open Add Child Screen
- [ ] Child Dashboard
- [ ] Connect Doctor
- [ ] Change Guardian PIN
- [ ] Send Request
- [ ] Logout
- [ ] Start Calibration
- [ ] Guardian Access icon from Tasks

---

## 11. Regression Sweep

- [ ] Home/Tracking/Tasks unaffected by auth and guardian updates
- [ ] Camera and detection stable after lock/unlock loops
- [ ] No duplicate lock routes under repeated critical events
- [ ] No crashes during rapid lifecycle transitions
- [ ] No data loss after restart for sessions, preferences, and pending sync queues

---

## 12. Test Execution Summary

Totals:
- Passed: ______
- Failed: ______
- Blocked: ______
- N/A: ______

Critical Defects:
1. ______________________
2. ______________________
3. ______________________

Release Recommendation:
- [ ] Go
- [ ] No-Go

Approver Name: ______________________
Approval Date: ______________________
