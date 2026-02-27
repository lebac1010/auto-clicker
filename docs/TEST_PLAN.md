# Test Plan

Version: 1.0
Date: 2026-02-09

## 1. Test Matrix
1. Android 8, 9, 10, 11, 12, 13, 14
2. OEMs: Samsung, Xiaomi, Oppo, Vivo, Pixel
3. Devices with notch and without notch
4. Low RAM device class

## 2. Core Scenarios
1. First launch permissions flow
2. Create and run multi-point script
3. Pause and resume from floating controller
4. Emergency stop via volume key
5. Overlay revoke while running
6. Accessibility service killed and recovery
7. Rotation during run
8. Import and export JSON
9. Recorder timeline edit, insert, delete and save
10. Help screen support log export

## 3. Performance Tests
1. 30-minute continuous run with 3 points
2. 5-minute run with 10 points
3. Rapid start and stop 10 cycles

## 4. Usability Tests
1. Can a new user start a script within 2 minutes
2. Can a user add and reposition markers without confusion

## 5. Regression Checklist
1. Permissions state visible on Home
2. Script validation blocks missing points
3. STOP button always available
4. Foreground notification visible during run

## 6. Logging and Diagnostics
1. Export local logs from Help
2. Include device model, Android version, permission states

## 7. Phase 9 Automation Gate
1. Recorder flow integration maps recorded steps to `ScriptStep`.
2. Recorder mapped script can be persisted to repository.
3. Persisted recorder script appears in Script List source and passes validator.
4. Export all in `schemaV1` then import into clean repository.
5. Export all in `internal` then import into clean repository.
6. Imported scripts remain runnable (validator pass and enabled steps exist).
7. Mixed batch with one invalid script must fail.
8. Repository remains unchanged after failed batch import.

## 8. Phase 9 Manual OEM Smoke
1. Devices: Pixel + Samsung + Xiaomi.
2. Start run, then disable Accessibility from Settings.
3. Verify run moves to idle and user sees service-down error.
4. Start recorder countdown, then disable Accessibility.
5. Verify recorder moves to idle and partial timeline can still be saved.
6. Re-enable Accessibility and verify fresh run and fresh recording work.

## 9. Phase 10 Telemetry and Lifecycle
1. Launch app from cold start and verify `app_opened` has `launch_type=cold`.
2. Background app then resume and verify `app_opened` has `launch_type=warm`.
3. Start run then stop by user and verify `script_run_stopped` has `stop_reason=user`.
4. Start run then disable Accessibility permission and verify `stop_reason=permission_lost`.
5. Start run then force-kill Accessibility service and verify `stop_reason=service_killed`.
6. Trigger run dispatch error and verify `stop_reason=error`.
