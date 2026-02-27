# Auto Clicker Android (Flutter + Native) - PRD

Version: 1.0
Date: 2026-02-09
Owner: BA
Platform: Android only

## 1. Vision
Build the most reliable and easy-to-use auto clicker on Android with a floating controller, multi-point tapping, and macro replay. The app must feel safe, transparent, and stable across major OEMs.

## 2. Goals
1. Users can start an auto-tap script in under 30 seconds after first open.
2. Permission flow completion rate >= 70%.
3. Run success rate >= 95% for a 5-minute session.
4. Crash-free sessions >= 99.0%.

## 3. Non-Goals
1. iOS support.
2. Root-only features.
3. Game cheating optimization or bypassing app protections.

## 4. Personas
1. Casual user: needs simple repeated taps with minimal setup.
2. Power user: wants multi-point, macro, import/export.
3. Support user: needs troubleshooting guides and logs.

## 5. MVP Scope
1. Splash + routing by permission state.
2. Onboarding with clear permission explanations.
3. Permissions Hub for Accessibility and Overlay.
4. Home with quick actions and recent scripts.
5. Script list with search and basic actions.
6. Script editor for multi-point taps with global interval and loop.
7. Floating controller with Start, Pause, Stop, marker edit.
8. Recorder mode basic with timeline review.
9. Import and export JSON.
10. Settings minimal for overlay size and volume-key stop.

## 6. V1 Scope
1. Randomization, jitter, cooldowns.
2. Gestures beyond tap, including swipe and long press.
3. Run options and confirmation modal.
4. Scheduler and automation triggers.
5. Pro paywall and ads placements.
6. Advanced conditions and rules.

## 7. Key User Stories
1. As a new user, I want to see why permissions are needed so I can trust the app.
2. As a user, I want to add multiple points and set intervals quickly.
3. As a user, I want a floating controller that always gives me a STOP button.
4. As a power user, I want to export and import scripts.
5. As a user, I want the app to recover if the service is killed.

## 8. Functional Requirements by Screen
### 8.1 Splash
1. Check Accessibility state, Overlay permission, Battery optimization, Notifications.
2. Route to Permissions Hub if required permissions missing.
3. Route to Home if core permissions are ready.

### 8.2 Onboarding
1. 3 to 5 slides explaining features and permissions.
2. CTA to start permission setup.
3. Optional short tutorial link.

### 8.3 Permissions Hub
1. Cards for Accessibility and Overlay with status.
2. Deep links to system settings.
3. Continue button enabled only when Accessibility and Overlay are ON.
4. Troubleshooting link if app not visible in Accessibility.

### 8.4 Home
1. Quick actions for Floating Controller and Create Script.
2. Recent scripts list with Run and Edit.
3. Templates list for common patterns.
4. Status bar for permissions and running state.

### 8.5 Script List
1. Search by name.
2. Filter by type.
3. Sort by last run or name.
4. Item actions: Run, Edit, Duplicate, Export, Delete.

### 8.6 Script Editor
1. Targets tab with list of points, reorder, enable, delete.
2. Timing tab with interval and loop count.
3. Save, Run, Test Cycle, Validate.

### 8.7 Floating Controller
1. Bubble that opens a mini panel.
2. Start, Pause, Stop.
3. Markers for points with drag to reposition.
4. Always-visible STOP control.

### 8.8 Recorder Mode
1. Record taps and delays after countdown.
2. Review timeline list.
3. Edit or delete steps.
4. Save to script.

### 8.9 Settings
1. Overlay size and transparency.
2. Volume-key emergency stop toggle.
3. Privacy and permissions explanation.

### 8.10 Import and Export
1. Export a script to JSON.
2. Import JSON to create scripts.

## 9. Non-Functional Requirements
1. Accessibility service must keep running with a foreground notification during execution.
2. Overlay must stay responsive without blocking user input.
3. All actions must be interruptible within 1 second by STOP.
4. Maintain coordinate consistency across rotation and cutouts.
5. Store no personal data by default.

## 10. Permissions and Compliance
1. Accessibility required for gesture execution.
2. Overlay required for floating controller and markers.
3. Notification permission required on Android 13+ for foreground service.
4. Clear disclosure and no data collection statement.

## 11. Edge Cases
1. Overlay permission revoked while running.
2. Accessibility service killed by OEM.
3. Screen rotation changes coordinate mapping.
4. Split-screen or PiP mode.
5. Notch and display cutout offsets.

## 12. Analytics Events
1. app_opened
2. onboarding_completed
3. permission_accessibility_enabled
4. permission_overlay_enabled
5. script_created
6. script_run_started
7. script_run_stopped
8. recorder_started
9. recorder_saved
10. export_success
11. import_success
12. Event payload schema is defined in `docs/ANALYTICS_SCHEMA.md`.

## 13. Risks and Mitigations
1. OEM kills service. Mitigation: foreground service and OEM guide in Help.
2. Recorder limits. Mitigation: warning and fallback to manual editing.
3. Policy risk. Mitigation: clear usage policy and no-cheat language.

## 14. Open Questions
1. Minimum Android version target.
2. Is scheduler required for MVP or V1.
3. Monetization plan.

## 15. Acceptance Criteria
### 15.1 Splash
1. If Accessibility or Overlay is OFF, route to Permissions Hub within 2 seconds.
2. If Accessibility and Overlay are ON, route to Home within 2 seconds.
3. No crash when any permission state is unknown.

### 15.2 Onboarding
1. User can complete onboarding and land on Permissions Hub.
2. Skip goes directly to Permissions Hub.
3. Back from Permissions Hub does not re-open onboarding.

### 15.3 Permissions Hub
1. Accessibility and Overlay cards show correct real-time status.
2. Continue is disabled until Accessibility and Overlay are ON.
3. Each card opens the correct system settings screen.

### 15.4 Home
1. Quick Actions are visible and tappable.
2. Recent scripts list shows last 5 scripts or empty state.
3. Status bar reflects actual permission and run status.

### 15.5 Script List
1. Search filters by name within 300 ms for 100 scripts.
2. Filter and sort update list without app restart.
3. Delete requires confirmation and removes the script from storage.

### 15.6 Script Editor
1. Save is blocked if no enabled points exist.
2. Add Point opens overlay pick mode and returns with coordinates.
3. Validate reports missing data with a clear message.

### 15.7 Floating Controller
1. STOP is always visible while running.
2. Start, Pause, Stop commands apply within 1 second.
3. Marker drag updates point coordinates and persists after Save.

### 15.8 Recorder Mode
1. Countdown occurs before recording starts.
2. At least tap and delay events are recorded.
3. Recording can be stopped and saved without crash.

### 15.9 Settings
1. Overlay size and transparency changes apply immediately.
2. Volume-key stop toggle works during run.

### 15.10 Import and Export
1. Export produces valid JSON matching schema.
2. Import rejects invalid schema with user-facing error.
