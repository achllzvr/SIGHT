# SIGHT Mobile x Server SQL Cross-Reference

Source schema reviewed: sight (2).sql

## 1) Table Ownership Map (Mobile-Relevant)

| Server Table | Mobile Owner | Current Status | Notes |
| --- | --- | --- | --- |
| user | Auth layer | Not integrated | Mobile currently has no online auth/token/session sync implementation. |
| guardian_profile | Guardian profile service | Not integrated | Mobile has guardian PIN and local controls, but no guardian profile sync yet. |
| child_profile | Child identity service | Partial | Mobile tracks metrics but does not persist server child identity/login_code/device_id/fcm_token. |
| guardian_child_link | Linking service | Not integrated | Needed for parent-child association resolution from API. |
| session_limits | Rule/guardian preferences services | Partial | Mobile has local guardian settings; field set does not yet fully mirror SQL columns. |
| eye_health_metrics | Local metrics curation service | Partial | Mobile has curated batches locally; not posted yet to server schema fields. |
| eye_health_score | Scoring service | Not integrated | Mobile computes XP/mood locally but does not write daily score/grade records to server. |
| virtual_pet | Gamification service | Partial | Local state exists; server field set is richer (currency, xp_points, streak date). |
| child_inventory | Gamification inventory service | Partial | Local inventory exists; column definitions differ and no child_id mapping yet. |
| clinician_patient_link | Doctor connection service | Not integrated | UI concept exists from attached Lumi flows; no sync service in SIGHT yet. |
| prescription | Doctor recommendation service | Not integrated | No local model or sync endpoint integration yet. |
| audit_logs | Server-only (admin/ops) | Not integrated | Mobile should emit events to backend endpoint if required. |

## 2) Direct Field-Level Mapping

## session_limits (critical for guardian controls)

Server fields:
- limit_id
- child_id
- daily_limit_minutes
- mode
- is_active
- harmful_distance_threshold
- critical_distance_threshold
- auto_enforce_breaks
- updated_at

Current mobile coverage:
- dailyScreenLimitMinutes -> daily_limit_minutes
- monitoringMode -> mode
- autoEnforceBreaks -> auto_enforce_breaks
- distanceAlertThresholdCm -> harmful_distance_threshold

Missing from mobile model:
- critical_distance_threshold (must be added explicitly)
- is_active
- child_id linkage for per-child controls
- server-side record ids and updated_at conflict handling

## eye_health_metrics

Server fields:
- metric_id
- child_id
- avg_blink_rate
- avg_distance
- strain_events
- timestamp
- screen_time_minutes

Current mobile coverage:
- curated_batches.averageBlinkRate -> avg_blink_rate
- curated_batches.averageDistanceCm -> avg_distance
- curated windowEnd -> timestamp (candidate)

Missing from mobile pipeline:
- child_id association
- strain_events calculation and persistence at batch level
- screen_time_minutes derivation and persistence
- remote sync queue status tied to server metric_id

## virtual_pet

Server fields:
- pet_id
- child_id
- pet_state
- currency
- xp_points
- current_streak_days
- last_streak_date
- updated_at

Current mobile coverage:
- sessionXp (local) -> xp_points (candidate)
- dailyStreak (local) -> current_streak_days (candidate)
- petMood (local enum) -> pet_state (requires explicit mapping table)

Missing:
- currency tracking model
- child_id association
- last_streak_date persistence compatible with server date semantics

## child_inventory

Server fields:
- inventory_id
- child_id
- item_name
- purchase_date

Current mobile local table:
- child_inventory(itemKey, itemName, cost, quantity, acquiredAt)

Gaps:
- child_id absent locally
- local cost/quantity/itemKey not represented server-side as provided
- requires either API transform or schema extension server-side

## child_profile

Server fields mobile must eventually populate/use:
- child_id
- login_code
- device_id
- last_sync
- calibration_baseline
- fcm_token

Current gap:
- mobile has calibration constant locally but no child_profile sync linkage

## 3) Required Mobile Service Additions for Full Sync

1. Auth/session service
- Sign-in/sign-up against user table APIs.
- Token storage and refresh.
- Role-aware routing (Guardian vs Child).

2. Child identity context service
- Persist active child_id.
- Attach child_id to every metrics, limits, pet, inventory payload.

3. Session limits sync service
- Pull: session_limits -> local guardian preferences + rule cache.
- Push: local guardian updates -> session_limits with optimistic concurrency.

4. Metrics sync service
- Transform curated_batches into eye_health_metrics payloads.
- Compute strain_events and screen_time_minutes before upload.
- Keep remote IDs and retry/backoff metadata.

5. Virtual pet sync service
- Map local petMood/sessionXp/streak to virtual_pet schema.
- Add missing currency and last_streak_date handling.

6. Guardian-child link and doctor link service
- Sync guardian_child_link and clinician_patient_link.
- Fetch prescriptions for child context.

## 4) Immediate Schema Alignment Tasks (High Priority)

1. Add criticalDistanceThresholdCm and isActive to local guardian preferences model.
2. Introduce childId in local entities that will sync (curated batches, inventory, limits).
3. Add SyncState metadata locally (pending, synced, failed, retryCount, lastError, remoteId).
4. Define deterministic enum mapping for petMood <-> pet_state and monitoringMode <-> mode.
5. Version local DB schema before introducing new sync columns.

## 5) Recommended API Payload Contracts (from current SQL)

- session_limits upsert payload:
  - child_id
  - daily_limit_minutes
  - mode
  - is_active
  - harmful_distance_threshold
  - critical_distance_threshold
  - auto_enforce_breaks

- eye_health_metrics create payload:
  - child_id
  - avg_blink_rate
  - avg_distance
  - strain_events
  - timestamp
  - screen_time_minutes

- virtual_pet upsert payload:
  - child_id
  - pet_state
  - currency
  - xp_points
  - current_streak_days
  - last_streak_date

## 6) Completion Checkpoint

The mobile app is now strong in local-first monitoring, guardian lock, and guardian controls UI.
To be production-complete against this SQL backend, the missing piece is the online sync/auth domain and child-linked server persistence lifecycle.
