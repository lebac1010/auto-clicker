# QA Checklist

Version: 1.0
Date: 2026-02-09

## 1. Installation and Launch
1. Install from APK and open successfully.
2. First launch shows Splash and routes correctly.
3. App resumes without crash after background.

## 2. Permissions Flow
1. Accessibility card opens correct settings screen.
2. Overlay card opens correct settings screen.
3. Continue disabled until Accessibility and Overlay are ON.
4. Permission status updates without restart.
5. Missing permission shows blocking modal on Run.

## 3. Onboarding
1. Swipe through all slides.
2. Skip leads to Permissions Hub.
3. Back from Permissions Hub does not re-open onboarding.

## 4. Home
1. Quick Actions visible and responsive.
2. Recent Scripts shows empty state when none.
3. Status bar reflects real permission state.

## 5. Script List
1. Search filters list within 300 ms for 100 scripts.
2. Filter and sort updates list.
3. Delete requires confirmation.
4. Delete removes JSON file and index entry.

## 6. Script Editor
1. Add Point opens overlay pick mode.
2. Added point appears with correct coordinates.
3. Reorder updates execution order.
4. Save blocked if no enabled point.
5. Validate shows clear error for missing data.

## 7. Floating Controller
1. Bubble appears with overlay permission granted.
2. Start, Pause, Stop apply within 1 second.
3. STOP always visible while running.
4. Marker drag updates coordinates.
5. Marker updates persist after Save.

## 8. Recorder
1. Countdown visible before record starts.
2. Tap events recorded with delays.
3. Stop and Save create a script.
4. Cancel does not create script.
5. Timeline supports edit step coordinates and delay.
6. Timeline supports insert step and preserves index ordering.

## 9. Import and Export
1. Export creates JSON file matching schema.
2. Import valid JSON creates script.
3. Import invalid JSON shows error.

## 10. Rotation and Insets
1. Rotation does not shift markers incorrectly.
2. Notch or cutout devices map coordinates correctly.

## 11. Error Recovery
1. Overlay revoke during run shows modal and stops.
2. Accessibility killed triggers warning and stops.
3. Volume-key stop cancels run.
4. Disable Accessibility permission during run reports stop reason `permission_lost`.
5. Service process interruption during run reports stop reason `service_killed`.

## 12. Performance
1. 30-minute run with 3 points completes without crash.
2. 5-minute run with 10 points does not ANR.
3. Rapid start-stop 10 cycles completes.

## 13. Phase 9 Release Gate
1. `test/phase9_integration_test.dart` passes.
2. Schema export-all import roundtrip keeps scripts runnable.
3. Internal export-all import roundtrip keeps scripts runnable.
4. Invalid batch import keeps repository unchanged.
5. Run and recorder recover to idle after Accessibility service is disabled.
6. Re-enable Accessibility and verify new run and recording session start successfully.
7. Manual smoke passed on Pixel, Samsung, and Xiaomi.

## 14. Help and Logs
1. Help screen opens from Settings.
2. Accessibility, Overlay, and Battery settings shortcuts open correctly.
3. Export Support Logs creates a file path and shows success message.

## 15. Analytics Reliability
1. `app_opened` logs `launch_type=cold` on cold start.
2. `app_opened` logs `launch_type=warm` when app resumes from background.
3. `script_run_stopped` contains `script_id`, `elapsed_ms`, and valid `stop_reason`.
