# Technical Spec (Flutter + Android Native)

Version: 1.0
Date: 2026-02-09
Scope: Android-only

## 1. Decisions
1. State management: Riverpod with StateNotifier.
2. Persistence: JSON files in app private storage with an index file.
3. Execution: AccessibilityService dispatchGesture driven by a background scheduler.
4. Overlay: native WindowManager overlay for bubble, panel, markers.

## 2. Flutter Package Structure
- `lib/main.dart` app entry.
- `lib/app/app.dart` root widget.
- `lib/app/router.dart` routes and guards.
- `lib/app/theme.dart` app theme.
- `lib/ui/screens/*` screen widgets.
- `lib/ui/widgets/*` reusable widgets.
- `lib/state/*` StateNotifier classes.
- `lib/domain/*` entities and validators.
- `lib/data/*` repositories and persistence.
- `lib/platform/*` method and event channel adapters.

## 3. Flutter State and Services
### 3.1 AppStateController
- Source of truth for permission states and run status.
- Subscribes to EventChannel for native status updates.

### 3.2 PermissionService
- Calls `getPermissionState` and exposes `PermissionState` model.
- Opens Android settings via platform channel.

### 3.3 ScriptRepository
- `listScripts()`, `getScript(id)`, `saveScript(script)`, `deleteScript(id)`.
- Stores each script as a JSON file in `scripts/`.
- Maintains `index.json` for fast listing and recents.

### 3.4 ScriptValidator
- Ensures at least one enabled step.
- Validates loop config.
- Validates coordinate ranges based on `coordinateMode`.

### 3.5 RunController
- High-level run control: `start`, `pause`, `stop`.
- Sends `runScript` payload to native.
- Handles `runProgress` and `errorEvents` from EventChannel.

## 4. Flutter Screens and Controllers
1. SplashScreen uses `PermissionService` to route.
2. OnboardingScreen is static content with CTA.
3. PermissionsHubScreen shows status cards and deep links.
4. HomeScreen uses `ScriptRepository` for recents.
5. ScriptListScreen uses `ScriptRepository` for list and search.
6. ScriptEditorScreen uses `ScriptEditorController` to modify script.
7. RecorderScreen uses `RecorderController` to manage record lifecycle.
8. SettingsScreen uses `SettingsController` for overlay and stop settings.

## 5. Android Native Components
### 5.1 AutoClickAccessibilityService
- Extends `AccessibilityService`.
- Handles `dispatchGesture` for taps and swipes.
- Handles `onKeyEvent` for volume stop when enabled.
- Exposes `startRun`, `pauseRun`, `stopRun` via binder.

### 5.2 AutoClickForegroundService
- Maintains foreground notification while running.
- Holds `ScriptRunner` instance.
- Receives commands from Flutter via MethodChannel.

### 5.3 OverlayController
- Manages bubble, panel, marker windows.
- Uses `WindowManager` and `TYPE_APPLICATION_OVERLAY`.
- Provides marker drag callbacks to Flutter via EventChannel.

### 5.4 GestureEngine
- `schedule(steps, loopConfig)` executes on `ScheduledExecutorService`.
- Applies random delay and jitter if enabled.
- Cancels pending tasks on STOP immediately.

### 5.5 ScriptRunner
- Validates and converts script payload to native model.
- Maintains `RunState`: Idle, Running, Paused.
- Calculates next step time and emits progress events.

### 5.6 RecorderController
- Starts recording session with countdown.
- Captures user gestures when possible.
- Generates step list with delays for editing.

### 5.7 PermissionWatcher
- BroadcastReceiver for overlay and accessibility changes.
- Emits state to Flutter through EventChannel.

### 5.8 ScreenMetricsProvider
- Reads display metrics, rotation, insets.
- Converts normalized coordinates to pixels.

## 6. Platform Channel Contract
### 6.1 MethodChannel
- `startService` -> void
- `stopService` -> void
- `runScript` -> payload: ScriptDTO
- `pauseScript` -> void
- `resumeScript` -> void
- `updateMarkers` -> payload: MarkerDTO[]
- `requestOverlay` -> open settings
- `requestAccessibility` -> open settings
- `getPermissionState` -> PermissionStateDTO
- `getScreenMetrics` -> ScreenMetricsDTO

### 6.2 EventChannel
- `serviceStatusChanged` -> { running: bool }
- `overlayStatusChanged` -> { enabled: bool }
- `runProgress` -> { scriptId, stepIndex, loopCount, elapsedMs }
- `errorEvents` -> { code, message }
- `markerMoved` -> { id, x, y }

## 7. Data Models
### 7.1 ScriptDTO
- Matches `docs/SCRIPT_SCHEMA.md`.

### 7.2 PermissionStateDTO
- `accessibilityEnabled`, `overlayEnabled`, `batteryUnrestricted`, `notificationsEnabled`.

### 7.3 ScreenMetricsDTO
- `widthPx`, `heightPx`, `densityDpi`, `rotation`, `insets`.

## 8. Coordinate Mapping
1. If `coordinateMode=normalized`, map `x` and `y` to pixels as:
   `px = insetLeft + x * (widthPx - insetLeft - insetRight)`
   `py = insetTop + y * (heightPx - insetTop - insetBottom)`
2. If `coordinateMode=absolute_px`, use `x` and `y` directly.
3. Apply jitter after mapping, clamped to safe bounds.

## 9. Threading
1. Flutter UI on main isolate.
2. JSON IO on background isolate.
3. Native: gesture scheduler on background executor.
4. Overlay window operations on main thread.

## 10. Error Handling
1. Map native errors to codes: `PERMISSION_MISSING`, `SERVICE_DOWN`, `SCRIPT_INVALID`, `OVERLAY_LOST`.
2. Flutter shows blocking modal for permission errors.
3. Logs stored locally for export.

## 11. Logging
1. `logs/` folder in app private storage.
2. Rotate logs by size and date.
3. Export via share intent.

## 12. Security and Privacy
1. No network calls by default.
2. No screen content capture.
3. Accessibility disclosure shown in onboarding.

## 13. Minimum Android Version
1. `minSdkVersion` 26 recommended.
2. `targetSdkVersion` latest stable.
