# Technical Architecture (Flutter + Android Native)

Version: 1.0
Date: 2026-02-09

## 1. High-Level Architecture
1. Flutter UI layer for screens, state, navigation.
2. Domain layer for script model, validation, and execution rules.
3. Data layer for persistence and import/export.
4. Android native services for Accessibility, overlay, and foreground execution.

## 2. Android Native Components
1. AccessibilityService
2. ForegroundService with persistent notification
3. Overlay window for bubble, panel, and markers
4. Gesture engine using AccessibilityService dispatchGesture
5. Recorder service for capturing events
6. BroadcastReceiver for permission state changes

## 3. Flutter Modules
1. ui for screens and widgets
2. state for app state and script editor state
3. domain for script validation and schema
4. data for local storage and IO
5. platform for MethodChannel and EventChannel bindings

## 4. Platform Channel Contract
### 4.1 MethodChannel Calls
1. startService
2. stopService
3. runScript
4. pauseScript
5. resumeScript
6. updateMarkers
7. requestOverlay
8. requestAccessibility
9. getPermissionState

### 4.2 EventChannel Streams
1. serviceStatusChanged
2. overlayStatusChanged
3. runProgress
4. errorEvents

## 5. Gesture Execution Strategy
1. Convert normalized coordinates to absolute using current screen metrics and insets.
2. Apply jitter and random delay if enabled.
3. Schedule steps with a single-threaded executor to avoid overlap.
4. Dispatch gestures via AccessibilityService dispatchGesture.
5. Enforce global STOP that cancels pending tasks.

## 6. Recorder Strategy
1. Start a recording session with a 3-second countdown.
2. Capture taps and delays via Accessibility events where available.
3. Allow manual correction in timeline editor.
4. Warn user about limitations on some OEMs.

## 7. Data Storage
1. Store scripts as JSON in app storage.
2. Maintain index for recent scripts.
3. Provide export and import via file picker.

## 8. Permissions Handling
1. Accessibility required before running.
2. Overlay required for controller.
3. Notification permission required for Android 13+.
4. Battery optimization ignore recommended.

## 9. Performance Targets
1. Run loop must keep UI thread idle.
2. STOP action must take effect within 1 second.
3. Overlay interaction must remain smooth at 60 fps.

## 10. Security and Privacy
1. Do not collect user data by default.
2. Provide local-only logs for support.
3. Avoid storing screen content or text.

## 11. Build Targets
1. minSdkVersion: 26 recommended
2. targetSdkVersion: latest stable
3. ABI: arm64-v8a, armeabi-v7a

## 12. Known Limitations
1. Recorder may not capture all gestures on all OEMs.
2. Split-screen and PiP may affect coordinate mapping.
