# Analytics Naming and Payload Mapping

Version: 1.0
Date: 2026-02-09

## 1. Naming Rules
1. Firebase: use lowercase with underscores, max 40 chars.
2. Amplitude: use snake_case for event names and properties.
3. Keep event names identical across tools.
4. Use `screen_name` and `source` consistently.

## 2. Common Properties
1. `app_version`
2. `build_number`
3. `device_model`
4. `android_version`
5. `session_id`
6. `is_first_launch`
7. `screen_name`

## 3. Event Mapping
### 3.1 app_opened
Firebase event: `app_opened`
Amplitude event: `app_opened`
Properties:
1. `launch_type` enum cold, warm

### 3.2 onboarding_completed
Firebase event: `onboarding_completed`
Amplitude event: `onboarding_completed`
Properties:
1. `slides_count` integer

### 3.3 permission_accessibility_enabled
Firebase event: `permission_accessibility_enabled`
Amplitude event: `permission_accessibility_enabled`
Properties:
1. `from_screen` string

### 3.4 permission_overlay_enabled
Firebase event: `permission_overlay_enabled`
Amplitude event: `permission_overlay_enabled`
Properties:
1. `from_screen` string

### 3.5 script_created
Firebase event: `script_created`
Amplitude event: `script_created`
Properties:
1. `script_id` string
2. `script_type` enum
3. `steps_count` integer

### 3.6 script_run_started
Firebase event: `script_run_started`
Amplitude event: `script_run_started`
Properties:
1. `script_id` string
2. `script_type` enum
3. `steps_count` integer
4. `loop_mode` enum infinite, count, duration
5. `source` enum home, editor, controller

### 3.7 script_run_stopped
Firebase event: `script_run_stopped`
Amplitude event: `script_run_stopped`
Properties:
1. `script_id` string
2. `stop_reason` enum user, error, permission_lost, service_killed
3. `elapsed_ms` integer

### 3.8 recorder_started
Firebase event: `recorder_started`
Amplitude event: `recorder_started`
Properties:
1. `countdown_sec` integer

### 3.9 recorder_saved
Firebase event: `recorder_saved`
Amplitude event: `recorder_saved`
Properties:
1. `script_id` string
2. `steps_count` integer
3. `duration_ms` integer

### 3.10 export_success
Firebase event: `export_success`
Amplitude event: `export_success`
Properties:
1. `export_type` enum single, all
2. `script_id` string optional

### 3.11 import_success
Firebase event: `import_success`
Amplitude event: `import_success`
Properties:
1. `import_type` enum single, all
2. `scripts_count` integer

### 3.12 error_event
Firebase event: `error_event`
Amplitude event: `error_event`
Properties:
1. `error_code` string
2. `message` string
3. `screen_name` string

## 4. Screen Names
1. `splash`
2. `onboarding`
3. `permissions_hub`
4. `home`
5. `script_list`
6. `script_editor`
7. `recorder`
8. `settings`
9. `import_export`
10. `floating_controller`
