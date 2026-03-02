# TapMacro Code Map (Agent Onboarding)

Version: 2026-03-02
Scope: Current code implementation in this repository

## 1) Muc tieu

Tai lieu nay map nhanh feature -> file de agent/dev moi:

1. Tim dung file can sua ngay.
2. Hieu duoc "nguon su that" cua tung flow.
3. Giam thoi gian lan dau vao codebase.

## 2) Entry points

1. Flutter app start: `app/lib/main.dart`
2. Flutter route root: `AutoClickerApp` trong `app/lib/main.dart`
3. Native channel bridge: `app/android/app/src/main/kotlin/com/example/auto_clicker/MainActivity.kt`
4. Native runtime cores:
   - `RunEngineManager.kt`
   - `OverlayController.kt`
   - `AutoClickAccessibilityService.kt`
   - `RecorderManager.kt`
   - `SchedulerManager.kt`

## 3) Feature -> file map

### 3.1 Boot + routing + mode shell

1. `app/lib/main.dart`
2. `app/lib/screens/splash_screen.dart`
3. `app/lib/screens/home_shell_screen.dart`
4. `app/lib/services/onboarding_service.dart`
5. `app/lib/services/home_mode_service.dart`

### 3.2 Permissions (Accessibility/Overlay/Notification/Battery/Exact Alarm)

1. `app/lib/screens/permissions_hub_screen.dart`
2. `app/lib/services/permission_service.dart`
3. `app/lib/models/permission_state.dart`
4. `app/lib/widgets/accessibility_disclosure_dialog.dart`
5. `app/android/app/src/main/kotlin/com/example/auto_clicker/MainActivity.kt`
6. `app/android/app/src/main/AndroidManifest.xml`

### 3.3 Run engine (manual run/pause/resume/stop + preflight)

1. `app/lib/services/run_execution_service.dart`
2. `app/lib/services/run_engine_service.dart`
3. `app/lib/models/run_options.dart`
4. `app/android/app/src/main/kotlin/com/example/auto_clicker/RunEngineManager.kt`
5. `app/android/app/src/main/kotlin/com/example/auto_clicker/AutoClickAccessibilityService.kt`

### 3.4 Floating controller + markers + emergency stop

1. `app/lib/services/floating_controller_service.dart`
2. `app/android/app/src/main/kotlin/com/example/auto_clicker/OverlayController.kt`
3. `app/lib/screens/home_screen.dart`
4. `app/lib/screens/normal_home_screen.dart`
5. `app/lib/screens/script_editor_screen.dart`

### 3.5 Recorder

1. `app/lib/screens/recorder_screen.dart`
2. `app/lib/services/recorder_service.dart`
3. `app/lib/services/recorded_script_mapper.dart`
4. `app/lib/models/recorded_step.dart`
5. `app/android/app/src/main/kotlin/com/example/auto_clicker/RecorderManager.kt`

### 3.6 Scheduler (daily/weekly/once, boot restore, alarm dispatch)

1. `app/lib/screens/scheduler_screen.dart`
2. `app/lib/services/scheduler_service.dart`
3. `app/lib/data/schedule_repository.dart`
4. `app/lib/models/schedule_model.dart`
5. `app/android/app/src/main/kotlin/com/example/auto_clicker/SchedulerManager.kt`
6. `app/android/app/src/main/kotlin/com/example/auto_clicker/SchedulerAlarmReceiver.kt`
7. `app/android/app/src/main/kotlin/com/example/auto_clicker/SchedulerBootReceiver.kt`

### 3.7 Script CRUD + editor + validation

1. `app/lib/screens/script_list_screen.dart`
2. `app/lib/screens/script_editor_screen.dart`
3. `app/lib/data/script_repository.dart`
4. `app/lib/models/script_model.dart`
5. `app/lib/models/script_step.dart`
6. `app/lib/models/script_type.dart`
7. `app/lib/services/script_validator.dart`

### 3.8 Import/Export + schema/internal mapping

1. `app/lib/screens/import_export_screen.dart`
2. `app/lib/services/script_import_export_service.dart`
3. `app/lib/services/script_schema_mapper.dart`
4. `app/lib/services/script_internal_mapper.dart`
5. `docs/SCRIPT_SCHEMA.md`
6. `docs/SCRIPT_SCHEMA.json`

### 3.9 Analytics + logs + settings

1. `app/lib/services/analytics_service.dart`
2. `app/lib/services/run_telemetry_service.dart`
3. `app/lib/services/app_lifecycle_analytics_service.dart`
4. `app/lib/services/support_log_service.dart`
5. `app/lib/screens/settings_screen.dart`
6. `app/lib/services/settings_service.dart`
7. `app/android/app/src/main/kotlin/com/example/auto_clicker/AppSettingsStore.kt`

### 3.10 Foreground execution state sync

1. `app/android/app/src/main/kotlin/com/example/auto_clicker/ExecutionStateSyncBridge.kt`
2. `app/android/app/src/main/kotlin/com/example/auto_clicker/ExecutionForegroundCoordinator.kt`
3. `app/android/app/src/main/kotlin/com/example/auto_clicker/ExecutionForegroundService.kt`

## 4) Screen -> run entry map

1. Advanced Home run: `app/lib/screens/home_screen.dart`
2. Normal Home single/multi run: `app/lib/screens/normal_home_screen.dart`
3. Script List run: `app/lib/screens/script_list_screen.dart`
4. Script Editor run/test-cycle: `app/lib/screens/script_editor_screen.dart`
5. Tat ca cac entry tren deu route qua `RunExecutionService.runWithOptions`.

## 5) Method/Event channels (thuc te)

MethodChannel:

1. `com.auto_clicker/permissions`
2. `com.auto_clicker/controller`
3. `com.auto_clicker/settings`
4. `com.auto_clicker/app_info`

EventChannel:

1. `com.auto_clicker/run_events`
2. `com.auto_clicker/overlay_events`
3. `com.auto_clicker/recorder_events`

## 6) Quick triage playbook

1. Run khong start:
   - `script_validator.dart` -> `run_execution_service.dart` -> `RunEngineManager.kt` -> `AutoClickAccessibilityService.kt`
2. Overlay/marker loi:
   - `floating_controller_service.dart` -> `OverlayController.kt`
3. Recorder miss event:
   - `RecorderManager.kt` -> `recorder_screen.dart` -> `recorded_script_mapper.dart`
4. Scheduler khong trigger:
   - `scheduler_screen.dart` -> `schedule_repository.dart` -> `SchedulerManager.kt` -> receivers + exact alarm permission
5. Import/export fail:
   - `script_import_export_service.dart` -> `script_schema_mapper.dart`/`script_internal_mapper.dart` -> `script_validator.dart`

## 7) Nguon su that

Uu tien theo thu tu:

1. Code implementation.
2. Unit/widget tests trong `app/test`.
3. `docs/PROJECT_STATUS.md`.
4. Doc spec cu (`docs/TECH_SPEC.md`, `docs/PRD.md`) neu con khop voi code.
