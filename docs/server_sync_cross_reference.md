# LUMI Mobile ↔ Server Sync Cross-Reference

**Status:** Updated for thesis sprint (Jul 2026). Stale `/api/mobile/eye-health-metrics` defaults removed.

| Client call | Server route | Notes |
|-------------|--------------|--------|
| Metric batch upload | `POST /api/mobile/child/{id}/sync/metrics/batch` | Primary path (`ServerSyncService` + `forceSyncNow`) |
| Session limits push | `PUT /api/mobile/child/{id}/sync/limits` | Requires `device_timestamp` |
| Pet sync | `PUT /api/mobile/child/{id}/sync/pet` | LWW via `device_timestamp` |
| Calibration | `POST /api/mobile/child/{id}/sync/calibration` | Optional |
| Limits read | `GET /api/shared/child/{id}/limits` | Ownership / admin checked |
| Metrics read | `GET /api/shared/child/{id}/metrics` | Ownership / admin checked |

**Removed / not used:** prescriptions API, clinician permanent links, public child-register-by-email, email-only verify.

Screen time in curated batches is **1 minute only when Watch Area tracking is active**.
