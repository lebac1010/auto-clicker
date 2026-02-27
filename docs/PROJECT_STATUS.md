# Project Status (Living Document)

Version: 1.0  
Created: 2026-02-11  
Last Updated: 2026-02-27 (Overlay UI redesign: simple compact controls)  
Owner: Dev Team

Muc dich:

1. Theo doi trang thai toan du an theo phase.
2. Co mot nguon su that duy nhat cho `DONE / PARTIAL / NOT DONE`.
3. Cap nhat lien tuc sau moi batch de khong mat context.

---

## 1) Overall Snapshot

Trang thai tong quan hien tai:

1. Tien do uoc tinh: `82-86%` scope feature map ban dau.
2. Core MVP da hoat dong:
   - Permissions + onboarding
   - Script CRUD + editor co ban
   - Floating controller + run engine (tap/double_tap/swipe/multi-touch)
   - Recorder co ban
   - Import/export dual format
3. Chua hoan tat:
   - Paywall/ads
   - Release pipeline/CI + store prep

---

## 2) Phase Status Matrix

| Phase | Scope chinh | Status | Ghi chu |
|---|---|---|---|
| 1 | Splash + Onboarding + Permissions Hub | DONE | Route va deep link quyen da hoat dong |
| 2 | Script model + storage + list | DONE | CRUD, search/filter/sort da co |
| 3 | Script Editor | DONE | Da co tap/double tap/swipe/multi-touch + tab conditions co ban |
| 4 | Floating Controller | DONE | Bubble/panel/start/pause/stop + STOP always visible |
| 5 | Gesture Engine | DONE | Run progress/stop state da co; ho tro tap/double_tap/swipe/multi-touch |
| 6 | Recorder | DONE (basic) | Countdown + tap capture + timeline edit/insert/delete + save |
| 7 | Import/Export | DONE | Dual format schemaV1/internal + validate + conflict handling |
| 8 | Stability + QA hardening | DONE (code) | Logging/guard da day du; con lai la gate QA thu cong theo matrix |
| 9 | Release prep | NOT DONE | Chua co CI/CD signing/store release flow |
| 10 | Analytics hardening | DONE | Da them stop reason `condition_unmet`; test gate da pass |
| 11 | Scheduler + Conditions | DONE (code) | Da co daily/weekly/once + conditions: foreground app, min battery, require screen on; trigger bang OS alarm |

---

## 3) Detailed Status by Module

### 3.1 Flutter UI

`DONE`:

1. `app/lib/screens/splash_screen.dart`
2. `app/lib/screens/onboarding_screen.dart`
3. `app/lib/screens/permissions_hub_screen.dart`
4. `app/lib/screens/home_screen.dart`
5. `app/lib/screens/home_shell_screen.dart`
6. `app/lib/screens/normal_home_screen.dart`
7. `app/lib/screens/script_list_screen.dart`
8. `app/lib/screens/script_editor_screen.dart` (co ban)
9. `app/lib/screens/recorder_screen.dart` (co ban)
10. `app/lib/screens/import_export_screen.dart`
11. `app/lib/screens/settings_screen.dart`
12. `app/lib/screens/help_screen.dart`

`PARTIAL`:

1. Khong con partial UI layer o pham vi code.

### 3.2 Flutter Services

`DONE`:

1. `app/lib/services/permission_service.dart`
2. `app/lib/services/run_engine_service.dart`
3. `app/lib/services/floating_controller_service.dart`
4. `app/lib/services/recorder_service.dart`
5. `app/lib/services/script_import_export_service.dart`
6. `app/lib/services/script_schema_mapper.dart`
7. `app/lib/services/script_internal_mapper.dart`
8. `app/lib/services/settings_service.dart`
9. `app/lib/services/support_log_service.dart`
10. `app/lib/services/analytics_service.dart` (adapter + schema sanitize)
11. `app/lib/services/app_lifecycle_analytics_service.dart`
12. `app/lib/services/run_telemetry_service.dart`
13. `app/lib/services/normal_mode_service.dart`
14. `app/lib/services/home_mode_service.dart`

### 3.3 Android Native

`DONE`:

1. `app/android/app/src/main/kotlin/com/example/auto_clicker/MainActivity.kt`
2. `app/android/app/src/main/kotlin/com/example/auto_clicker/AutoClickAccessibilityService.kt`
3. `app/android/app/src/main/kotlin/com/example/auto_clicker/RunEngineManager.kt`
4. `app/android/app/src/main/kotlin/com/example/auto_clicker/OverlayController.kt`
5. `app/android/app/src/main/kotlin/com/example/auto_clicker/RecorderManager.kt`
6. `app/android/app/src/main/kotlin/com/example/auto_clicker/ExecutionForegroundService.kt`
7. `app/android/app/src/main/kotlin/com/example/auto_clicker/ExecutionForegroundCoordinator.kt`
8. `app/android/app/src/main/kotlin/com/example/auto_clicker/AppSettingsStore.kt`

`PARTIAL`:

1. Khong con partial native layer o pham vi code.

---

## 4) Functional Coverage vs Feature Map

### 4.1 Da co (DONE)

1. Core permissions flow.
2. Script CRUD + validation co ban.
3. Overlay picker + marker editor.
4. Run/pause/resume/stop.
5. Recorder tap timeline + save script.
6. Import/export dual format.
7. Help + export support logs.
8. Emergency stop (overlay STOP + volume key option).
9. Run options pre-flight (start delay, stop rule, performance mode).
10. Scheduler full (daily/weekly/once) voi OS-level alarm + boot restore.
11. Advanced conditions: `requireForegroundApp` + `minBatteryPct` (editor + mapper + native runtime).
12. Advanced condition: `requireScreenOn` (editor + mapper + native runtime).
13. Condition warning UX chi tiet theo tung ly do fail (charging/screen/app/battery/time-window).
14. Exact Alarm permission UX (Permissions Hub + Scheduler banner + Help shortcuts).
15. Testability foundation (gateway injection cho RunEngine/Scheduler services).
16. Perf/security hardening: condition snapshot cache, scheduler script lastRun sync, analytics source fix.
17. Accessibility disclosure/consent gate truoc khi mo Accessibility settings.
18. Scheduler hardening: run dispatch tren main thread + parse script loi tam thoi khong auto-disable schedule.
19. UI perf tuning: Script List search debounce + Home run-progress throttle.
20. Play policy hardening: FGS type declaration + in-app Privacy Policy + analytics error sanitization.

### 4.2 Co nhung chua day du (PARTIAL)

1. Cac muc con lai la verification/QA gate (khong phai implementation gap):
   - Re-run `analyze/test/build` sau batch moi nhat.
   - Chay smoke matrix OEM theo test plan.

### 4.3 Chua co (NOT DONE)

1. Ads integration.
2. Pro/paywall.
3. Bulk actions multi-select trong Script List.
4. Zip import/export + cloud sync.
5. CI/CD release pipeline.

---

## 5) Quality and Verification Status

Trang thai verification gan nhat:

1. `flutter test`: da pass truoc hardening pass 2.
2. `flutter analyze`: da pass truoc hardening pass 2.
3. `flutter build apk --debug`: da pass truoc hardening pass 2.

Gate can chay de khoa trang thai:

1. `flutter analyze`
2. `flutter test test/services/analytics_service_test.dart`
3. `flutter test test/script_validator_test.dart`
4. `flutter test test/script_mappers_test.dart`
5. `flutter test test/recorded_script_mapper_test.dart`
6. `flutter build apk --debug`

---

## 6) Open Issues / Risks

1. Scheduler exact alarm da co UX xin quyen, nhung user van co the tu choi tren mot so OEM.
2. Chua co CI build gate nen nguy co hoi quy khi merge batch tiep theo.
3. OEM behavior co the khac nhau cho recorder/accessibility event.

---

## 7) Next Batches (de xep hang uu tien)

1. Batch tiep theo A (Uu tien cao):
   - Chay gate verify sau batch scheduler/conditions:
     - `flutter analyze`
     - `flutter test`
     - `flutter build apk --debug`

2. Batch tiep theo B:
   - Day manh test suites:
     - Unit tests cho service layer con lai.
     - Widget tests cho `Scheduler`, `PermissionsHub`, `ScriptEditor`.

3. Batch tiep theo C:
   - Integration tests (`integration_test`) cho happy-path.
   - Lap scope release prep (CI/CD + signing).

---

## 8) Change Log

### 2026-02-11

1. Tao tai lieu status song `docs/PROJECT_STATUS.md`.
2. Snapshot hoa toan bo status hien tai theo phase.
3. Chot danh sach done/partial/not done de lam baseline cap nhat cac batch sau.
4. Hoan tat mot phan Phase 3:
   - Script Editor ho tro loop mode `infinite`.
   - Validator cho phep `loopCount = 0` (infinite).
   - Schema mapper giu duoc `loop.mode = infinite` qua import/export.
   - Them test cho validator va mapper lien quan infinite loop.
5. Hoan tat them mot phan gesture co ban:
   - Them `holdMs` vao `ScriptStep` model.
   - Script Editor cho phep sua `hold duration (ms)` cho moi point.
   - Them tab `Gestures` voi bulk apply hold duration cho tat ca points.
   - Native run engine dung `holdMs` de dispatch long-press theo duration.
   - Mapper + validator + test duoc cap nhat dong bo.
6. Hardening Help/Support:
   - Them OEM troubleshooting guide co ban trong Help screen.
   - Export support logs bo sung metadata runtime (permission state, run state, volume-key-stop setting).
7. Recorder parity hardening:
   - `RecordedStep` bo sung `holdMs` va luu/phuc hoi qua JSON/event.
   - Timeline dialog trong Recorder cho sua `Tap/Double Tap` va `hold duration`.
   - Mapper `RecordedScriptMapper` giu dung `action` va `holdMs` khi tao `ScriptStep`.
   - Them test bao ve fallback action unsupported ve `tap`.

### 2026-02-23

1. Dong code gap cho Script Editor phase:
   - Them gesture actions `swipe` va `multi_touch` end-to-end (model, editor UI, validator, mapper, native run engine).
   - Them tab `Conditions` trong editor: `requireCharging` + `timeWindow (HH:mm)`.
2. Native engine:
   - `AutoClickAccessibilityService` ho tro `performSwipeNormalized` va `performMultiTouchNormalized`.
   - `RunEngineManager` enforce runtime conditions (charging/time-window) va stop reason `condition_unmet`.
3. Import/export + schema/internal mapping:
   - Ho tro parse/serialize step `swipe` + `multi_touch`.
   - Ho tro parse/serialize conditions co ban.
4. Recorder hardening:
   - Timeline editor ho tro `swipe/multi_touch` manual step editing.
   - Mapper recorder -> script giu duoc end points + gesture duration.
5. Analytics hardening:
   - Bo sung `condition_unmet` vao telemetry normalization va analytics enum rules.
6. Verification:
   - Sau fix bo sung cho `script_validator` va `script_mappers_test`, `flutter test` da pass full suite.
7. Batch 1 (Run Options pre-flight):
   - Them `RunOptionsScreen` va `RunOptions` model.
   - Them `RunExecutionService` de xu ly start delay, stop rule, performance mode.
   - Moi entry run (`Home`, `Script List`, `Script Editor`) deu route qua pre-flight.
   - Bo sung unit test cho validation run options.
8. Batch 2 (Scheduler MVP + advanced conditions):
   - Them `ScheduleModel`, `ScheduleRepository`, `SchedulerService`, `SchedulerScreen` + route `'/scheduler'`.
   - Them quick entry Scheduler tu `Home` va `Script List`.
   - Fix deadlock write-lock trong `ScheduleRepository.markTriggered`.
   - Hoan tat condition `requireForegroundApp` va `minBatteryPct` end-to-end:
     - Editor tab Conditions.
     - `ScriptValidator`.
     - Mapper `SchemaV1` va `Internal`.
     - Native `RunEngineManager` runtime checks.
   - Them test bo sung cho validator/mapper conditions moi.
9. Batch 3 (condition `requireScreenOn`):
   - Mo rong `ScriptModel` + mapper internal/schema de luu `requireScreenOn`.
   - Script Editor tab Conditions them switch `Require screen ON`.
   - Native `RunEngineManager` them check `PowerManager.isInteractive`.
   - Bo sung test cho `ScriptModel` va mo rong assert mapper roundtrip.
10. Batch 4 (Scheduler full):
   - Bo scheduler polling trong Flutter, thay bang native `AlarmManager` backend.
   - Them `SchedulerManager`, `SchedulerAlarmReceiver`, `SchedulerBootReceiver`.
   - Tu dong restore schedule sau reboot/app update (`BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`).
   - MethodChannel them `startScheduler/rescheduleScheduler/stopScheduler`.
   - `SchedulerScreen` sau moi thay doi schedule se goi `reschedule`.
11. Batch 5 (Condition warning UX):
   - Native `RunEngineManager` tra ve code/message cu the cho moi condition fail.
   - MethodChannel them `validateRunConditions` de preflight truoc khi start run.
   - `RunExecutionService` luu last failure message.
   - `Home`, `Script List`, `Script Editor` hien thong bao loi condition cu the thay vi generic.
12. Batch 6 (Exact Alarm permission UX):
   - Mo rong `PermissionState` + `PermissionService` them `exactAlarmAllowed` va `requestExactAlarm`.
   - Native `MainActivity` expose state + deeplink toi `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`.
   - `PermissionsHubScreen` them card `Exact Alarm (recommended)`.
   - `SchedulerScreen` them warning banner + CTA enable exact alarm.
   - `HelpScreen` them shortcut exact alarm va log metadata `exact_alarm_allowed`.
13. Batch 7 (Testability foundation):
   - Them abstraction `RunEngineGateway` va `SchedulerGateway`.
   - `RunExecutionService`, `RunTelemetryService`, `SchedulerService` ho tro dependency injection.
   - Bo sung unit tests:
     - `test/services/run_execution_service_test.dart`
     - `test/services/scheduler_service_test.dart`
14. Batch 8 (Hardening sweep):
   - Native `RunEngineManager` cache condition snapshot 1s de giam system calls moi step.
   - Scheduler native cap nhat `lastRunAt/updatedAt` cua script khi trigger thanh cong.
   - Analytics allow source `script_list` cho event `script_run_started`.
   - Hardening scheduler boot receiver (`exported=false`) + log skip invalid schedule file.
   - Support log bo `flush=true` moi dong de giam I/O overhead.
15. Hardening pass 2:
   - Native scheduler:
     - Chay scheduler run tren main thread de tranh thao tac overlay o background thread.
     - Parse script loi tam thoi chi log/skip, khong auto-disable schedule.
   - Native run engine:
     - `double_tap` doi sang single gesture voi 2 stroke (tap-gap-tap).
     - Cache `enabledSteps` theo session thay vi filter moi step.
     - `runState` duoc danh dau `@Volatile` de an toan hon khi scheduler doc state.
   - Accessibility policy hardening:
     - Thu gon `accessibilityEventTypes` thanh `typeViewClicked|typeWindowStateChanged`.
     - Bo `flagRequestFilterKeyEvents` khoi accessibility config.
     - Them disclosure/consent dialog truoc khi mo Accessibility settings o cac entry UI.
   - Flutter perf/edge-case:
     - `ScriptListScreen` them search debounce 250ms.
     - `HomeScreen` throttle update UI theo `runProgress`.
   - `ScheduleModel` validate weekdays 1..7 va parse weekdays an toan hon.
16. Hardening pass 3 (Play policy blockers):
   - Android manifest:
     - Khai bao `FOREGROUND_SERVICE_SPECIAL_USE`.
     - `ExecutionForegroundService` khai bao `android:foregroundServiceType="specialUse"` + subtype property.
   - Build config:
     - Tang `compileSdk`/`targetSdk` toi toi thieu API 35.
     - Doi `applicationId` khoi placeholder thanh `com.sarmatcz.tapmacro`.
   - In-app policy UX:
     - Them man hinh `Privacy Policy` va quick entry tu Settings/Help.
   - Telemetry safety:
     - `RunTelemetryService` sanitize analytics error message theo code, tranh log chuoi chi tiet co the nhay cam.
17. Branding + package identity update:
   - Android `namespace` + `applicationId` doi thanh `com.sarmatcz.tapmacro`.
   - Cap nhat app title/label trong Flutter + Android manifest sang `TapMacro`.
   - Cap nhat user-facing strings lien quan (`Splash`, `Dashboard`, `Privacy Policy`, disclosure, foreground notification).
18. Documentation update:
   - Viet lai `docs/USER_GUIDE_VI.md` theo huong dan chi tiet cho nguoi moi.
   - Bo sung quy trinh test end-to-end, edge cases, checklist va mau bao loi.
19. Overlay UX fix:
   - Sua bubble `AC` de phan biet `tap` va `drag` bang `touchSlop`.
   - Tap bubble se toggle panel ngay; drag bubble van di chuyen duoc nhu truoc.
20. Home UX split (Normal + Advanced):
   - Them `HomeShellScreen` voi 2 tab `Normal` va `Advanced`.
   - Refactor home hien tai thanh `AdvancedHomeScreen` (giu nguyen hanh vi cho power user).
   - Them `NormalHomeScreen` voi flow don gian: 1 muc tieu, nhieu muc tieu, dung nhanh.
   - Them `NormalQuickConfig` + `NormalModeService` de luu cau hinh nhanh cho user pho thong.
   - Analytics bo sung event `home_mode_selected` va source `normal` cho `script_run_started`.
21. Normal mode hardening:
   - Chan run moi neu da co session dang `running/paused`.
   - Them toggle `Floating Controller` ngay trong Normal.
   - Them check `ScriptValidator` truoc khi run multi-target trong Normal.
   - Neu script invalid, mo nhanh `Advanced Editor` de user sua truc tiep.
22. Home mode preference + UX polish:
   - Them `HomeModeService` de luu mode mac dinh `Normal/Advanced`.
   - HomeShell bootstrap theo mode da luu + popup chon mode lan dau.
   - Settings them `Default Home Mode` va action `Show mode chooser again`.
   - Bo sung test cho `HomeModeService`, `NormalModeService`, `NormalQuickConfig` va analytics mode schema.
23. Overlay controller redesign:
   - Bubble `AC` + panel duoc thu gon, spacing gon va de thao tac bang mot tay.
   - Panel chuyen thanh action stack ro rang: `Resume`, `Pause`, `Stop`, `Hide/Show Markers`.
   - Nut emergency `STOP` doi sang dang pill gon gon, de nhin va bam nhanh.
24. Normal run safety fix:
   - `Normal` mode chi mo Floating Controller sau khi run start thanh cong.
   - Neu mo overlay that bai, app se stop run ngay de tranh chay "mu".
25. Overlay marker/run callback fix:
   - Bo marker mac dinh `1/2/3` khi bat controller de tranh gay nham cho single target.
   - Them channel `updateRunMarkers` de dong bo marker dung theo script dang run.

---

## 9) Quy tac cap nhat (bat buoc sau moi batch)

Sau moi batch, cap nhat cac muc sau trong file nay:

1. `Last Updated`.
2. `Phase Status Matrix` neu co thay doi status.
3. `Quality and Verification Status` voi ket qua lenh moi nhat.
4. `Change Log` them entry ngay-thang + noi dung thay doi.
5. `Next Batches` dieu chinh uu tien.

Definition:

1. `DONE`: da code + da verify qua gate lien quan.
2. `PARTIAL`: da code mot phan hoac chua verify day du.
3. `NOT DONE`: chua implement.

