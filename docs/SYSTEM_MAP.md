# TapMacro System Map (1-page)

Version: 2026-02-28
Scope: Current implementation in this repository

## 1) Muc tieu tai lieu

Tai lieu nay tom tat nhanh kien truc va luong chay chinh de dev moi co the:

1. Biet module nao giu vai tro gi.
2. Lanh dao duoc duong di du lieu tu UI -> native -> runtime.
3. Tim dung file khi can sua bug hoac them feature.

## 2) Kien truc tong quan

App duoc tach thanh 4 lop chinh:

1. Flutter UI: screens/widgets, dieu huong va thao tac nguoi dung.
2. Flutter services/domain: run options, validator, mapper, analytics, settings.
3. Flutter data: repositories luu JSON local cho scripts/schedules.
4. Android native: Accessibility + Overlay + RunEngine + Recorder + Scheduler (AlarmManager).

## 3) Entry points quan trong

1. Flutter app start: `app/lib/main.dart`
2. Flutter route root: `AutoClickerApp` trong `app/lib/main.dart`
3. Native bridge root: `app/android/app/src/main/kotlin/com/example/auto_clicker/MainActivity.kt`
4. Native runtime core:
`RunEngineManager.kt`, `OverlayController.kt`, `AutoClickAccessibilityService.kt`, `SchedulerManager.kt`, `RecorderManager.kt`

## 4) Channel contract (thuc te)

MethodChannel:

1. `com.auto_clicker/permissions`: get state + open settings permissions.
2. `com.auto_clicker/controller`: run/pause/resume/stop, overlay start/stop, marker editor, recorder, scheduler.
3. `com.auto_clicker/settings`: volume-key emergency stop.
4. `com.auto_clicker/app_info`: app/build/device info cho analytics payload.

EventChannel:

1. `com.auto_clicker/run_events`: `state`, `runProgress`, `runStopped`, `error`.
2. `com.auto_clicker/overlay_events`: point picker, marker editor, overlay errors.
3. `com.auto_clicker/recorder_events`: recorder state/countdown/record_step/error.

## 5) 3 luong chay quan trong nhat

### A. Manual run (Normal/Advanced/Editor/ScriptList)

1. Screen tao hoac chon `ScriptModel`.
2. `RunExecutionService.runWithOptions` validate options.
3. `RunExecutionService` preflight qua `RunEngineService.validateRunConditions`.
4. Neu ok: native `runScript` trong `RunEngineManager`.
5. Flutter mo `FloatingControllerService.start` va dong bo markers.
6. Native `RunEngineManager` loop step, dispatch gesture qua `AutoClickAccessibilityService`.
7. Event run duoc day nguoc ve Flutter qua `run_events`.

### B. Scheduler run (OS alarm)

1. Flutter save schedule trong `ScheduleRepository` + goi `SchedulerService.reschedule`.
2. Native `SchedulerManager` doc file schedule/script trong `app_flutter`.
3. Alarm den `SchedulerAlarmReceiver` -> `SchedulerManager.onAlarm`.
4. Scheduler start overlay + `RunEngineManager.runScript`.
5. Schedule/script timestamps duoc cap nhat (`lastTriggeredAt`, `lastRunAt`).

### C. Recorder -> Script

1. Flutter goi `RecorderService.start(countdownSec)`.
2. Native `RecorderManager` vao state countdown/recording.
3. Accessibility event `TYPE_VIEW_CLICKED` duoc map thanh `record_step`.
4. Flutter editor timeline cho phep sua/chen/xoa.
5. `RecordedScriptMapper` chuyen `RecordedStep` -> `ScriptStep`.
6. Luu thanh script qua `ScriptRepository`.

## 6) Data model va persistence

Script storage:

1. Model: `ScriptModel`, `ScriptStep`, `ScriptType`.
2. Repo: `app/lib/data/script_repository.dart`
3. Du lieu luu tung file JSON trong thu muc `scripts` (app documents dir).

Schedule storage:

1. Model: `ScheduleModel`, `ScheduleType`.
2. Repo: `app/lib/data/schedule_repository.dart`
3. Du lieu luu tung file JSON trong thu muc `schedules`.

Import/export:

1. `ScriptImportExportService`: export/import `schemaV1` va `internal`.
2. `ScriptSchemaMapper` va `ScriptInternalMapper` map du lieu qua lai.
3. Import bat buoc validate va save atomically.

## 7) Safety va stop paths

1. Overlay emergency STOP (`OverlayController`) + debounce anti self-stop.
2. Volume-key stop (`AutoClickAccessibilityService.onKeyEvent`) khi duoc bat trong settings.
3. Run preflight conditions: charging, screen on, foreground app, battery, time window.
4. Service disconnect tu dong stop va phat stop reason (`permission_lost` hoac `service_killed`).

## 8) Thu tu doc code de vao du an nhanh

1. `app/lib/main.dart`
2. `app/lib/screens/home_shell_screen.dart`
3. `app/lib/screens/normal_home_screen.dart` + `app/lib/screens/home_screen.dart`
4. `app/lib/services/run_execution_service.dart` + `run_engine_service.dart`
5. `app/android/.../MainActivity.kt`
6. `app/android/.../RunEngineManager.kt`
7. `app/android/.../OverlayController.kt`
8. `app/android/.../SchedulerManager.kt`
9. `app/android/.../RecorderManager.kt`
10. `app/lib/data/script_repository.dart` + `schedule_repository.dart`

## 9) Nguon su that khi co xung dot tai lieu

Uu tien theo thu tu:

1. Code implementation.
2. Test cases trong `app/test`.
3. `docs/PROJECT_STATUS.md`.
4. Cac doc spec cu (`TECH_SPEC.md`, ...).

## 10) Code map tham chieu nhanh

Neu can map feature -> file de sua nhanh, doc them:

1. `docs/CODE_MAP.md`
