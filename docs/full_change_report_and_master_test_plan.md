# SIGHT Mobile App: Full Change Report and Master Test Plan

Date: 2026-04-07
Project: SIGHT Flutter app
Platforms: Android and iOS

## 1. Executive Summary

This report consolidates all implementation work completed in the current modernization and parity cycle, and provides a complete, detailed test plan for screens, services, features, buttons, and key functions on both platforms.

Primary outcomes achieved:
- Guardian biometric override and strict lock mode implemented end-to-end.
- Android critical lock overlay and permission flow implemented via method channel integration.
- Guardian setup/access/control center implemented and integrated.
- Auth-first startup and role-based session routing implemented.
- Child account creation/login flow implemented.
- Local data model upgraded for server alignment (child linkage + sync states + retry/error metadata).
- Real API sync stack implemented for metrics and session limits (configurable by environment).
- Lumi screen parity started and completed for missing target screens, with shared Lumi visual shell integrated in auth and guardian flows.
- QA and schema alignment documentation produced and expanded.

## 2. Scope of Work Completed

### 2.1 Security and Guardian Enforcement
- Added guardian biometric authentication with PIN fallback.
- Enforced strict lock with non-dismissible behavior and guardian-only unlock path.
- Added guardian PIN management (create, verify, change).
- Added guardian access surface and guardian control center.
- Added guardian preferences to control enforcement and thresholds.

### 2.2 Rule Engine and Lock Triggers
- Rule engine now supports guardian-controlled active/inactive enforcement mode.
- Added critical lock trigger plumbing and duplicate-trigger protection.
- Added overlay message refinement to improve user-facing warnings.
- Root app now listens for screen-lock alert state and triggers lock path.

### 2.3 Android OS-Wide Overlay Integration
- Implemented method channel bridge for critical overlay commands.
- Added overlay show/hide/check/open-settings methods through service wrapper.
- Added overlay permission handling and recovery flow in lock screen path.

### 2.4 Auth and Session Architecture
- Added auth-first startup flow with session router.
- Added guardian registration/login.
- Added child login using code + password.
- Added persisted role-based session restoration and routing.

### 2.5 Child and Guardian Experience Expansion
- Added guardian setup screen and control center.
- Added child account creation from guardian context.
- Added Lumi parity screens missing in SIGHT:
  - Welcome
  - Add Child
  - Child Dashboard
  - Connect With Doctor
- Added navigation routes for new parity screens.

### 2.6 Data and Sync Modernization
- Added DB migration from v1 to v2.
- Added child_id and sync metadata to local entities.
- Added retry/error/remote ID state transitions for sync lifecycle.
- Replaced placeholder metric sync behavior with real HTTP sync pipeline.
- Added session_limits pull/push integration with server API.

### 2.7 Design Language Alignment
- Added shared Lumi shell widget.
- Applied Lumi shell styling to:
  - Welcome
  - Auth options
  - Login
  - Register guardian
  - Guardian control center
  - New parity screens

## 3. File-Level Implementation Inventory

### 3.1 New Screens Added
- lib/screens/welcome_screen.dart
- lib/screens/add_children_screen.dart
- lib/screens/child_dashboard_screen.dart
- lib/screens/connect_with_doctor_screen.dart
- lib/screens/auth/auth_options_screen.dart
- lib/screens/auth/login_screen.dart
- lib/screens/auth/register_guardian_screen.dart
- lib/screens/guardian_access_screen.dart
- lib/screens/guardian_control_center_screen.dart
- lib/screens/guardian_setup_screen.dart

### 3.2 Existing Screens Updated
- lib/screens/guardian_override_screen.dart
- lib/screens/tasks_screen.dart
- lib/screens/tracking_screen.dart
- lib/main.dart

### 3.3 New/Updated Services
- lib/services/guardian_auth_service.dart
- lib/services/guardian_setup_service.dart
- lib/services/guardian_preferences_service.dart
- lib/services/active_child_context_service.dart
- lib/services/auth_account_service.dart
- lib/services/auth_session_service.dart
- lib/services/critical_overlay_service.dart
- lib/services/api_config_service.dart
- lib/services/api_client_service.dart
- lib/services/server_sync_service.dart
- lib/services/local_metrics_service.dart
- lib/services/offline_database_service.dart
- lib/services/offline_models.dart
- lib/services/rule_engine_service.dart
- lib/services/gamification_service.dart

### 3.4 Native and Dependency Updates
- pubspec.yaml (local_auth/http/crypto and related updates)
- android/app/src/main/AndroidManifest.xml (biometric/overlay permissions)
- android/app/src/main/kotlin/.../MainActivity.kt (method channel + activity integration)
- ios/Runner/Info.plist (Face ID usage text)

### 3.5 Documentation Added
- docs/guardian_lock_qa_matrix.md
- docs/server_sync_cross_reference.md
- docs/full_change_report_and_master_test_plan.md (this file)

## 4. Architecture Outcomes and Capability Gains

### 4.1 Functional Capability Gains
- App now supports guardian-grade intervention flow under critical eye-strain conditions.
- Guardian can configure child safety thresholds and enforcement modes.
- Child and guardian have explicit auth roles and distinct startup destinations.
- Child identity context is now persisted and propagated to local/sync domains.

### 4.2 Operational/Quality Gains
- Sync path is observable with explicit pending/synced/failed states.
- DB migration support reduces risk when introducing new fields.
- Route structure supports parity expansion and feature layering.
- UI consistency improved in auth/guardian surfaces via shared shell.

## 5. Known Constraints and Follow-Up Recommendations

- Android overlay is platform-specific; iOS cannot provide true OS-wide overlay behavior.
- API operations depend on runtime environment variables and server availability.
- Some warning-level deprecations may exist (for example opacity helpers), but no blocking compile errors in recently modified files.
- Recommended next extension: apply Lumi shell to all remaining guardian screens for complete visual consistency.

---

## 6. Master Cross-Platform Test Plan

This section is a complete, execution-ready checklist.

### 6.1 Test Environment and Build Sanity

1. Run dependency restore: flutter pub get.
2. Run static analysis: flutter analyze.
3. Build Android debug and release variants.
4. Build iOS debug and release variants.
5. Confirm startup without crash on first launch.
6. Confirm startup without crash after app reinstall.

Expected:
- No compile/blocking analysis errors.
- App boots into Welcome when no session exists.

### 6.2 Global Navigation and Routing

Validate all named routes:
- /welcome
- /auth
- /child
- /guardian
- /guardian-setup
- /add-child
- /child-dashboard
- /connect-doctor

Test cases:
1. Open each route from valid entry points.
2. Back navigation behavior is correct and does not create route loops.
3. Route guard behavior works with and without valid session.
4. Session router sends:
   - No session -> Welcome
   - Guardian session with PIN -> Guardian Control Center
   - Guardian session without PIN -> Guardian Setup
   - Child session -> Child Root App

### 6.3 Screen-by-Screen Test Checklist (Both Platforms)

#### 6.3.1 Welcome Screen
File: lib/screens/welcome_screen.dart

Test:
1. Verify branding text renders correctly.
2. Tap Get Started button.
3. Confirm navigation to auth options.
4. Validate layout on small and large screens.

#### 6.3.2 Auth Options Screen
File: lib/screens/auth/auth_options_screen.dart

Buttons:
- Login
- Register Guardian

Test:
1. Tap Login and verify destination screen.
2. Tap Register Guardian and verify destination screen.
3. Confirm Lumi shell rendering and no overflow.

#### 6.3.3 Login Screen
File: lib/screens/auth/login_screen.dart

Controls:
- Segmented role switch (Guardian/Child)
- Guardian Email field
- Guardian Password field
- Child Login Code field
- Child Password field
- Continue button

Test:
1. Switch role tabs and verify field set changes.
2. Guardian login success path.
3. Guardian login invalid credentials path.
4. Child login success path.
5. Child login invalid credentials path.
6. Verify loading state disables duplicate submits.
7. Verify role-based route after success.

#### 6.3.4 Register Guardian Screen
File: lib/screens/auth/register_guardian_screen.dart

Controls:
- Guardian Email
- Password
- Confirm Password
- Create Guardian Account

Test:
1. Register success path.
2. Password mismatch validation.
3. Duplicate guardian registration validation.
4. Invalid email validation.
5. Post-registration route behavior to guardian setup/control center.

#### 6.3.5 Guardian Setup Screen
File: lib/screens/guardian_setup_screen.dart

Controls:
- Guardian PIN
- Confirm PIN
- Save Guardian PIN

Test:
1. Valid 4-digit PIN create flow.
2. Non-digit PIN rejected.
3. PIN length not equal to 4 rejected.
4. Mismatch PIN rejected.
5. Mandatory mode back navigation blocked.
6. Success route to guardian control center.

#### 6.3.6 Guardian Access Screen
File: lib/screens/guardian_access_screen.dart

Buttons:
- Authenticate with Biometrics
- Use Guardian PIN

Dialog buttons:
- Cancel
- Unlock

Test:
1. Biometric success unlock path.
2. Biometric cancel/failure path.
3. PIN dialog success path.
4. PIN invalid path.
5. No-PIN-configured fallback to setup screen.

#### 6.3.7 Guardian Override Screen (Critical Lock)
File: lib/screens/guardian_override_screen.dart

Buttons:
- Guardian Unlock (biometric)
- Use Guardian PIN
- Enable Overlay Permission (if shown)

Dialog buttons:
- Cancel
- Unlock

Test:
1. Lock appears when critical trigger occurs.
2. Back navigation is blocked while locked.
3. Biometric unlock success returns to app.
4. Biometric failure remains locked.
5. PIN unlock success returns to app.
6. Invalid PIN remains locked.
7. Overlay settings button opens settings when permission missing.

#### 6.3.8 Guardian Control Center Screen
File: lib/screens/guardian_control_center_screen.dart

Primary actions:
- Logout
- Set Child
- Save Safety Settings
- Add Child (dialog)
- Open Add Child Screen
- Child Dashboard
- Connect Doctor
- Change Guardian PIN

Dialog buttons:
- Set Active Child ID: Clear/Set
- Change Guardian PIN: Cancel/Update PIN
- Create Child Account: Cancel/Create

Settings to validate:
- Daily screen time limit slider
- Distance alert threshold slider
- Critical lock threshold slider
- Blink alert threshold slider
- Monitoring mode dropdown
- Rule enforcement active switch
- Auto-enforce eye breaks switch
- Weekend relaxed mode switch
- Parent notifications switch

Test:
1. Load existing preferences and child context.
2. Modify each slider and verify value reflects immediately.
3. Toggle each switch and verify persistence after restart.
4. Change monitoring mode and verify persistence.
5. Save settings and validate success/error status message.
6. Push session limits to server success path.
7. Push session limits to server failure path (network down).
8. Set active child ID with valid value.
9. Set active child ID invalid input validation.
10. Create child account in dialog (success/fail/validation).
11. Open Add Child Screen and return refresh behavior.
12. Open Child Dashboard route.
13. Open Connect Doctor route.
14. Change guardian PIN success and invalid current PIN path.
15. Logout clears session and returns to auth.

#### 6.3.9 Add Children Screen
File: lib/screens/add_children_screen.dart

Controls:
- Back
- Child Name
- Child Password
- Server Child ID (optional)
- Create Child Account

Test:
1. Create child success and display login code.
2. Missing guardian session handling.
3. Non-numeric child ID validation.
4. Empty required fields validation.
5. Loading state prevents duplicate submissions.

#### 6.3.10 Child Dashboard Screen
File: lib/screens/child_dashboard_screen.dart

Controls:
- Back
- Action cards list

Test:
1. Screen loads without overflow.
2. Action cards render and are tappable (if navigation is later added).
3. Back navigation returns correctly.

#### 6.3.11 Connect With Doctor Screen
File: lib/screens/connect_with_doctor_screen.dart

Controls:
- Back
- Doctor Name
- Clinic Code
- Optional Notes
- Send Request

Test:
1. Input fields accept and retain text during session.
2. Send Request shows confirmation snackbar.
3. Back navigation returns correctly.

#### 6.3.12 Home Screen
File: lib/screens/home_screen.dart

Test:
1. Dashboard content renders.
2. Instructional text and cards display correctly.
3. Theme compatibility check (light/dark if enabled).

#### 6.3.13 Tracking Screen
File: lib/screens/tracking_screen.dart

Test:
1. Camera feed and tracking overlay load.
2. Offline rule banner messaging for each alert level.
3. Overlay/warning visual states are correct.
4. No crashes while switching app lifecycle states.

#### 6.3.14 Tasks Screen
File: lib/screens/tasks_screen.dart

Test:
1. Task list and completion counters update correctly.
2. Guardian access icon opens Guardian Access screen.
3. Gamification values update from service notifiers.

#### 6.3.15 Calibration Screen
File: lib/screens/calibration_screen.dart

Buttons:
- Start Calibration
- Cancel

Test:
1. Screen opens and closes correctly.
2. Start calibration button behavior (placeholder or active logic).
3. Cancel returns to previous screen.

### 6.4 Bottom Navigation and Root App Behavior

Files:
- lib/main.dart
- lib/widgets/bottom_pill_nav.dart

Test:
1. Root tabs switch correctly (Home/Tracking/Tasks).
2. Current index state preserved while app active.
3. No duplicate pages in stack from tab switching.
4. Rule engine listener triggers lock only once per critical transition.

### 6.5 Android-Only Overlay and Permission Tests

Files:
- lib/services/critical_overlay_service.dart
- android MainActivity + Manifest integration

Test:
1. Overlay permission granted flow.
2. Overlay permission denied flow.
3. Open overlay settings path works.
4. showCriticalOverlay/hideCriticalOverlay/isCriticalOverlayShowing method calls function correctly.
5. Overlay remains over other apps when active.
6. Overlay disappears after successful guardian unlock.

### 6.6 iOS-Specific Lock and Biometric Tests

Files:
- iOS Info.plist + lock screens

Test:
1. Face ID/Touch ID prompt appears with configured usage description.
2. Biometric success unlocks correctly.
3. Biometric cancel/failure remains locked.
4. In-app lock path remains stable through background/foreground transitions.

### 6.7 Service-Level Test Checklist

#### 6.7.1 GuardianAuthService
Methods:
- canAuthenticate
- authenticateWithBiometrics
- loadFallbackPin
- saveFallbackPin
- verifyFallbackPin

Test:
1. canAuthenticate true/false behavior based on device capabilities.
2. saveFallbackPin accepts only numeric 4-digit PIN.
3. verifyFallbackPin true for exact match, false otherwise.

#### 6.7.2 GuardianSetupService
Methods:
- hasGuardianPin
- createGuardianPin
- changeGuardianPin
- verifyPinAccess

Test:
1. createGuardianPin validation matrix.
2. changeGuardianPin with invalid current pin.
3. changeGuardianPin with same current/new pin.
4. verifyPinAccess success/failure messaging.

#### 6.7.3 GuardianPreferencesService
Methods:
- loadPreferences
- savePreferences
- pullSessionLimitsFromServer
- pushSessionLimitsToServer

Test:
1. Defaults load when storage empty.
2. Save/load round-trip correctness.
3. Pull session limits success mapping correctness.
4. Pull failure error handling.
5. Push success and failure handling.

#### 6.7.4 RuleEngineService
Methods:
- initialize
- evaluateFromMetrics
- triggerOverlay
- applyGuardianPreferences
- triggerCriticalLock

Test:
1. Evaluate outputs for none/blink/red/screenLock thresholds.
2. Enforcement inactive mode bypasses lock and shows paused reason.
3. applyGuardianPreferences updates thresholds and saves cache.
4. triggerCriticalLock blocks duplicate activations.

#### 6.7.5 CriticalOverlayService
Methods:
- hasPermission
- ensurePermission
- showCriticalOverlay
- hideCriticalOverlay
- isCriticalOverlayShowing
- openOverlaySettings

Test:
1. Method channel returns expected booleans in all states.
2. Graceful handling when method channel throws.

#### 6.7.6 AuthAccountService
Methods:
- registerGuardian
- authenticateGuardian
- createChildAccount
- authenticateChild
- listChildrenForGuardian

Test:
1. Guardian registration validations.
2. Guardian auth success/failure.
3. Child account creation validations.
4. Unique login code generation.
5. Child auth success/failure.

#### 6.7.7 AuthSessionService
Methods:
- saveAccessToken/loadAccessToken/clearSession
- saveGuardianSession/saveChildSession
- loadUserSession
- clearUserSession

Test:
1. Guardian session persistence across restarts.
2. Child session persistence across restarts.
3. Session clear removes role and identifiers.
4. Mixed-role overwrite behavior is correct.

#### 6.7.8 ActiveChildContextService
Methods:
- initialize
- getActiveChildId
- setActiveChildId

Test:
1. Active child set/get works.
2. Null set clears storage key.
3. Value notifier updates reactively.

#### 6.7.9 OfflineDatabaseService
Methods to prioritize:
- initialize/onCreate/onUpgrade
- insert/load/delete raw events
- insert/load/mark curated batches
- addInventoryItem
- save/load calibration/rules/gamification state

Test:
1. Fresh DB create schema validity.
2. Upgrade path v1->v2 preserves old data and adds columns.
3. Pending batch query excludes synced records.
4. markBatchSyncAttempt/markBatchSynced/markBatchSyncFailed correctness.

#### 6.7.10 LocalMetricsService
Methods:
- initialize
- logRawEvent
- curateThirtyMinuteBatch
- attemptBackgroundSync
- dispose

Test:
1. Raw event insertion includes child_id.
2. Batch curation computes averages and derived fields.
3. Background sync success marks synced with remoteId.
4. Background sync failure increments retryCount and sets error.
5. Timer lifecycle start/stop behavior.

#### 6.7.11 ServerSyncService and API Client Stack
Methods:
- uploadMetricBatch
- fetchSessionLimits
- upsertSessionLimits
- ApiClientService get/post/put
- ApiConfigService endpoint/URI building

Test:
1. Missing API base URL returns clear failure.
2. HTTP 2xx parses and maps correctly.
3. HTTP error responses propagate detailed error context.
4. Timeout handling behavior is stable.
5. Child_id required constraints enforced.

#### 6.7.12 DetectionService, MetricsService, AppLifecycle, BackgroundNotification
Test:
1. Detection initialization/restart recovery.
2. Calibration constant load/save behavior.
3. Metrics notifiers update correctly from sample flow.
4. App lifecycle hooks do not crash in background/foreground transitions.
5. Background notification starts/stops and refresh paths are stable.

#### 6.7.13 GamificationService
Test:
1. initialize loads persisted state.
2. updatePetState logic transitions as expected.
3. Wallet transaction deducts XP and writes inventory with child_id.
4. Daily streak evaluation updates and persists.

### 6.8 Data Model and Persistence Validation

Files:
- lib/services/offline_models.dart
- lib/services/offline_database_service.dart

Validate:
1. LocalMetricEvent includes childId.
2. CuratedMetricBatch includes:
   - childId
   - strainEvents
   - screenTimeMinutes
   - syncState
   - retryCount
   - lastError
   - lastSyncAttemptAt
   - remoteId
3. SyncState enum transitions are valid and reversible by query logic.

### 6.9 Button and Dialog Action Coverage Matrix

Test all explicit button actions at least once in both success and failure/invalid-input paths:
- Get Started
- Login
- Register Guardian
- Continue
- Create Guardian Account
- Save Guardian PIN
- Authenticate with Biometrics
- Use Guardian PIN
- Unlock (PIN dialogs)
- Cancel (PIN dialogs)
- Guardian Unlock
- Enable Overlay Permission
- Set Child
- Save Safety Settings
- Add Child
- Open Add Child Screen
- Child Dashboard
- Connect Doctor
- Change Guardian PIN
- Send Request
- Logout
- Start Calibration
- Task/guardian access icon interactions

### 6.10 Regression and Stability Testing

1. Verify no regressions in Home/Tracking/Tasks after auth and guardian additions.
2. Verify camera and detection continue to operate after lock/unlock cycles.
3. Verify no duplicate critical lock screens on repeated critical events.
4. Verify app stability under rapid app lifecycle changes.
5. Verify no data loss after restart for:
   - user session
   - active child
   - guardian preferences
   - queued metric batches

### 6.11 Platform Differences Checklist

Android focus:
- Overlay permissions
- Overlay show/hide while app backgrounded
- Method channel resilience

iOS focus:
- Biometric prompt behavior
- In-app lock behavior (no OS-wide overlay)
- Face ID usage string and permission prompts

### 6.12 Recommended Test Execution Order

1. Build and static checks.
2. Auth and session routing.
3. Guardian setup/access/control center.
4. Critical lock and biometric/PIN paths.
5. Android overlay tests and iOS lock parity tests.
6. Child flows and Lumi parity screens.
7. Data persistence and sync lifecycle.
8. Regression on home/tracking/tasks and background behavior.

### 6.13 Evidence Collection Guidance

For each high-priority case capture:
- Screen recording for route and lock/unlock flow.
- Logs for sync and service failures.
- Screenshot for each error/validation branch.
- API response payload snapshots for server sync tests.

Pass criteria:
- No crashes in any tested path.
- All route and role guards behave correctly.
- Guardian lock is secure and recoverable by authorized methods only.
- Sync state transitions are accurate and recoverable on intermittent network.
- Android and iOS platform-specific behaviors align with intended constraints.

## 7. Completion Statement

The implemented work materially improves security enforcement, role-based access, operational sync readiness, and UI parity with Lumi references. The test plan above is comprehensive enough for feature QA, regression QA, and release readiness review on both Android and iOS.
