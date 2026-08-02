# LUMI Mobile App

**LUMI** is a Flutter eye-health companion for children: a **Watch Area** media sandbox with live blink/distance monitoring (Google ML Kit), local SQLite storage, and sync to the LUMI Laravel backend for parent and clinician review.

## Product surfaces

| Role | Features |
|------|----------|
| **Child** | Watch Area (YouTube / YouTube Kids / YouTube Playables), pet gamification, daily goals, blink/distance tracking |
| **Parent (Guardian)** | Account + child management, limits, charts, clinician share via OTP/QR |
| **Offline** | Metrics buffered in SQLite (`sight_local.db`) and synced when online |

Parents use the **mobile app only**. There is no guardian web portal.

## Tech stack

- Flutter / Dart 3.2+
- `google_mlkit_face_detection` (face mesh dual-pipeline **disabled** for performance)
- `sqflite` + `flutter_secure_storage`
- `webview_flutter` (allowlisted YouTube hosts)
- API base: `--dart-define=SIGHT_API_BASE_URL=https://your-host`

## Sync endpoints (aligned with Laravel)

- `POST /api/mobile/child/{id}/sync/metrics/batch`
- `PUT /api/mobile/child/{id}/sync/limits`
- `PUT /api/mobile/child/{id}/sync/pet`

Screen-time minutes are counted only while Watch Area tracking is active.

## Auth

- Guardian register → Gmail SMTP **OTP** email verification → PIN → onboarding
- Child login via login code + password
- Child create requires authenticated guardian token + real birthdate

## Run

```bash
cd SIGHT_Mobile_App/SIGHT
flutter pub get
flutter run --dart-define=SIGHT_API_BASE_URL=https://your-api-host
flutter test
```

## Docs

- [2-minute demo script](../../docs/LUMI_2MIN_DEMO_SCRIPT.md)
- [Thesis limitations](../../docs/LUMI_THESIS_LIMITATIONS.md)
