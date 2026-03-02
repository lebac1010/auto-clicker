# Store Policy Checklist (Google Play)

Last updated: 2026-02-23

## 0) Pre-submit pack

1. Tai lieu thao tac submit + mau khai bao:
   - `docs/PLAY_PRE_SUBMIT_PACK_VI.md`

## 1) Accessibility (high priority)

1. In-app disclosure must be shown before opening Accessibility settings.
   - Status: DONE (dialog with explicit consent `I Agree`).
2. Accessibility scope must be minimal for declared use case.
   - Status: PARTIAL
   - Done: narrowed events to `typeViewClicked|typeWindowStateChanged`, removed key-event filter flag.
   - Pending: final policy wording review in all app copy + listing text.
3. Play Console Accessibility declaration must match real behavior.
   - Status: NOT DONE (manual Console step).
4. Prepare review evidence (short video + clear steps).
   - Status: NOT DONE.

## 2) User Data / Privacy

1. Privacy policy URL (public) in Play Console.
   - Status: NOT DONE.
2. Data safety form aligned with telemetry/support log fields.
   - Status: NOT DONE.
3. In-app explanation of what is and is not collected.
   - Status: DONE (disclosure dialog + in-app Privacy Policy screen).

## 3) Foreground Service (Android 14+)

1. Foreground service type must be declared in manifest.
   - Status: DONE (`specialUse` + subtype property added).
2. Ensure Play Console declaration matches service behavior.
   - Status: NOT DONE (manual Console step).

## 4) Exact Alarm

1. Exact alarm declared only for user-facing schedule use case.
   - Status: DONE (feature exists + UX fallback).
2. Play Console declaration for exact alarm use case.
   - Status: NOT DONE (manual Console step).

## 5) Release Readiness

1. Replace placeholder app identity.
   - `applicationId` updated to `com.sarmatcz.tapmacro`.
   - Status: DONE.
2. Configure release signing (upload/app signing key).
   - Status: NOT DONE (debug signing still configured).
3. Target API level must meet current Play requirement.
   - Status: DONE in code (`targetSdk >= 35`).
4. Final pre-submit gate:
   - `flutter analyze`
   - `flutter test`
   - `flutter build apk --release` (or `aab`)
   - Status: PENDING user run.

