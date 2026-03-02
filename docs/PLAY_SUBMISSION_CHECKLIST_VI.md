# Play Console Submission Checklist (VI)

Cap nhat: 2026-02-23

Tai lieu tong hop declaration + Data Safety draft:
- `docs/PLAY_PRE_SUBMIT_PACK_VI.md`

## 1) Khai bao bat buoc tren Play Console

1. App content -> Accessibility API declaration
   - Mo ta dung dung use-case: tu dong thao tac cham theo script do user cau hinh.
   - Khop voi in-app disclosure.
   - Upload video ngan (30-60s) quay:
     - Mo app
     - Man disclosure
     - Mo Accessibility settings
     - Bat service
     - Chay script mau

2. App content -> Exact alarm declaration
   - Mo ta use-case scheduler user-facing.
   - Neu exact alarm OFF, app co fallback (da co trong code).

3. Policy -> Privacy Policy URL
   - Dat URL public (https) vao Play Console.
   - Noi dung phai khop voi man `Privacy Policy` trong app.

4. App content -> Data safety
   - Kiem tra ky cac truong telemetry/logs.
   - Neu log chi local tren may, khai bao dung theo implementation.

## 2) Build/technical gate truoc khi upload

1. Chay local:
   - `flutter analyze`
   - `flutter test`
   - `flutter build appbundle --release`

2. Signing:
   - Tao upload key rieng (khong dung debug key).
   - Cau hinh signing release trong Gradle.

3. Verify manifest release:
   - `FOREGROUND_SERVICE_SPECIAL_USE` co trong permission.
   - `ExecutionForegroundService` co `foregroundServiceType="specialUse"`.

## 3) Metadata listing nen co

1. Short description + full description:
   - Nêu ro app duoc dung de tu dong thao tac cham theo script cua user.
   - Khong dung wording lien quan gian lan/cheat.

2. Screenshot:
   - Manh onboarding/disclosure
   - Permissions Hub
   - Script editor + scheduler

3. Contact:
   - Email support hoat dong.
