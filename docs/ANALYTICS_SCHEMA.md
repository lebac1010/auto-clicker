# Analytics Event Schema

Version: 1.0
Date: 2026-02-09

## 1. Common Fields
1. `eventName` string.
2. `timestamp` ISO 8601.
3. `sessionId` string.
4. `appVersion` string.
5. `buildNumber` string.
6. `deviceModel` string.
7. `androidVersion` string.
8. `isFirstLaunch` boolean.

## 2. Events
### 2.1 app_opened
1. Trigger: app process cold start or warm start to foreground.
2. Required fields: common fields.
3. Optional fields: `launchType` enum cold, warm.
4. Example:
```json
{
  "eventName": "app_opened",
  "timestamp": "2026-02-09T12:00:00Z",
  "sessionId": "sess_001",
  "appVersion": "1.0.0",
  "buildNumber": "100",
  "deviceModel": "Pixel 7",
  "androidVersion": "14",
  "isFirstLaunch": true,
  "launchType": "cold"
}
```

### 2.2 onboarding_completed
1. Trigger: user finishes onboarding and lands on Permissions Hub.
2. Required fields: common fields.
3. Optional fields: `slidesCount` integer.

### 2.3 permission_accessibility_enabled
1. Trigger: Accessibility toggled to ON.
2. Required fields: common fields.
3. Optional fields: `fromScreen` string.

### 2.4 permission_overlay_enabled
1. Trigger: Overlay permission toggled to ON.
2. Required fields: common fields.
3. Optional fields: `fromScreen` string.

### 2.5 script_created
1. Trigger: script saved for the first time.
2. Required fields: common fields.
3. Optional fields: `scriptId`, `scriptType`, `stepsCount`.

### 2.6 script_run_started
1. Trigger: run starts from Home, Editor, or Floating Controller.
2. Required fields: common fields.
3. Optional fields: `scriptId`, `scriptType`, `stepsCount`, `loopMode`.

### 2.7 script_run_stopped
1. Trigger: run stops by user or error.
2. Required fields: common fields.
3. Optional fields: `scriptId`, `stopReason` enum user, error, permission_lost, service_killed, `elapsedMs`.

### 2.8 recorder_started
1. Trigger: recorder countdown completes and recording begins.
2. Required fields: common fields.
3. Optional fields: `countdownSec`.

### 2.9 recorder_saved
1. Trigger: recorder session saved to script.
2. Required fields: common fields.
3. Optional fields: `scriptId`, `stepsCount`, `durationMs`.

### 2.10 export_success
1. Trigger: export completed without error.
2. Required fields: common fields.
3. Optional fields: `scriptId`, `exportType` enum single, all.

### 2.11 import_success
1. Trigger: import completed without error.
2. Required fields: common fields.
3. Optional fields: `importType` enum single, all, `scriptsCount`.

### 2.12 error_event
1. Trigger: app shows blocking error or native error emitted.
2. Required fields: common fields.
3. Optional fields: `errorCode`, `message`, `screen`.
