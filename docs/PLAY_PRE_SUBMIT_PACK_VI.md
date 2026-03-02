# Play Store Pre-Submit Pack (VI)

Cap nhat: 2026-03-02
Muc tieu: bo tai lieu copy-paste nhanh cho Play Console truoc khi submit.
Huong dan lan dau upload:
`docs/PLAY_FIRST_UPLOAD_GUIDE_VI.md`

## 1) Snapshot san sang hien tai (PASS/FAIL)

1. PASS: Target API dat nguong Play requirement (`targetSdk >= 35`).
2. FAIL (blocker): Release signing dang dung debug key.
3. PASS: Da co in-app Accessibility disclosure + explicit consent.
4. FAIL (console blocker): Chua nop Accessibility declaration tren Play Console.
5. PASS: Da khai bao FGS `specialUse` trong manifest.
6. FAIL (console blocker): Chua nop Foreground service declaration tren Play Console.
7. PASS: Exact alarm use-case co trong app (scheduler user-facing).
8. FAIL (console blocker): Chua nop Exact alarm declaration tren Play Console.
9. FAIL (console blocker): Chua co Privacy Policy URL public de dien vao Play Console.
10. FAIL (console blocker): Data safety form chua khai.
11. PENDING: Chua chay gate cuoi `flutter analyze`, `flutter test`, `flutter build appbundle --release`.

## 2) Blockers phai xu ly truoc khi upload

1. Cau hinh upload keystore cho release (khong dung debug signing).
2. Tao URL Privacy Policy public (https) va dien vao Play Console.
3. Dien Accessibility declaration.
4. Dien Foreground service declaration.
5. Dien Exact alarm declaration.
6. Dien Data safety form.
7. Chay full pre-submit gate va luu log ket qua.

## 3) Mau khai bao Play Console (copy-paste)

### 3.1 Accessibility declaration (draft)

Use case:
TapMacro la cong cu automation do nguoi dung tu cau hinh. App dung Accessibility Service de thuc thi cac touch gesture (tap, double tap, swipe, multi-touch) trong script ma nguoi dung tu tao.

How service is triggered:
Chi hoat dong sau khi nguoi dung chu dong bat Accessibility Service va bam run script. Nguoi dung co the stop bat ky luc nao.

Data access scope:
Service duoc dung de gui gesture va ghi nhan click event phuc vu recorder. App khong duoc thiet ke de doc password, thong tin thanh toan, hay tin nhan rieng tu.

User disclosure:
Truoc khi mo Accessibility Settings, app hien disclosure dialog va yeu cau nguoi dung bam "I Agree".

### 3.2 Foreground service declaration (draft)

FGS type:
specialUse

Reason:
Khi script dang chay hoac recorder dang ghi, app can foreground notification lien tuc de thong bao trang thai thuc thi cho nguoi dung va cho phep dung app theo dung user expectation.

User benefit:
Nguoi dung nhin thay ro app dang automation/recording va co the dung thao tac nhanh qua UI.

### 3.3 Exact alarm declaration (draft)

Permission:
SCHEDULE_EXACT_ALARM

Reason:
App co tinh nang scheduler cho phep nguoi dung dat lich chay script vao thoi diem cu the (once/daily/weekly). Exact alarm duoc dung de kich hoat dung gio theo cau hinh nguoi dung.

User-facing behavior:
Nguoi dung tao, sua, xoa lich trong UI Scheduler. App chi kich hoat automation theo lich ma nguoi dung da tao.

### 3.4 Metadata listing wording an toan (draft)

Short description draft:
TapMacro giup ban tu dong hoa thao tac cham theo script tu cau hinh tren thiet bi Android.

Full description draft (rut gon):
TapMacro la cong cu macro tren Android cho phep tao script cham, swipe, multi-touch va dat lich chay. App chi thuc thi thao tac theo cau hinh do nguoi dung tao, kem disclosure ro rang cho Accessibility permission.

Khong dung trong listing:
1. Cac tu "cheat", "hack", "bypass", "bot farm", "auto win".
2. Mo ta nguyen tac vi pham policy cua app/nen tang khac.

## 4) Data Safety draft (dua tren code hien tai)

Luu y: day la draft ky thuat de dien form nhanh, khong thay the review phap ly/compliance.

1. Collected data:
   - Hien tai khong thay code gui du lieu toi server ben thu ba theo default implementation.
   - Analytics va support logs dang duoc ghi local tren thiet bi.
2. Shared data:
   - Khong co luong share tu dong toi ben thu ba trong code hien tai.
3. Optional export:
   - Nguoi dung co the tu tay export support log file.
   - Day la user-initiated action, khong phai auto-collection backend.
4. Neu sau nay tich hop backend analytics/crash:
   - Bat buoc cap nhat Data Safety form truoc khi release.
   - Cap nhat Privacy Policy URL va in-app policy.

## 5) Script quay video evidence cho review (30-60s)

1. Mo app lan dau.
2. Vao man disclosure, bam "I Agree".
3. Mo Accessibility Settings va bat service cua app.
4. Tao script tap don gian (1-2 step).
5. Bam Run, hien foreground notification va script chay.
6. Stop script.
7. (Neu can) Mo Scheduler va tao 1 lich mau.

## 6) Gate ky thuat truoc submit

1. `flutter analyze`
2. `flutter test`
3. `flutter build appbundle --release`
4. Kiem tra lai AndroidManifest trong artifact release:
   - `FOREGROUND_SERVICE_SPECIAL_USE`
   - `SCHEDULE_EXACT_ALARM`
   - `ExecutionForegroundService` co `foregroundServiceType="specialUse"`

## 7) Bang quyet dinh submit

Chi submit khi tat ca dieu kien duoi day = YES:

1. Release signing dung upload key = YES
2. Accessibility declaration + video = YES
3. FGS declaration = YES
4. Exact alarm declaration = YES
5. Privacy Policy URL public = YES
6. Data safety form = YES
7. analyze/test/build appbundle pass = YES
