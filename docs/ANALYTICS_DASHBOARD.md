# Analytics Dashboard KPIs

Version: 1.0
Date: 2026-02-09

## 1. North Star Metrics
1. Weekly Active Runners: users who run a script at least once per week.
2. Run Success Rate: successful runs / total runs.

## 2. Activation Funnel
1. app_opened -> onboarding_completed
2. onboarding_completed -> permission_accessibility_enabled
3. permission_accessibility_enabled -> permission_overlay_enabled
4. permission_overlay_enabled -> script_created
5. script_created -> script_run_started

## 3. Retention
1. D1, D7, D30 retention for users with at least one run.
2. Repeat run rate: users who run a script 3+ times within 7 days.

## 4. Reliability
1. Crash-free sessions.
2. Run success rate by device model.
3. Top error_event codes.
4. Mean time to STOP: time from stop click to stop confirmed.

## 5. Feature Usage
1. Recorder usage: recorder_started / active users.
2. Import/export usage: import_success and export_success per active user.
3. Average steps_count per script.

## 6. Performance
1. Run start latency: time from Start to first action.
2. Mean execution loop time by steps_count.
3. Foreground service uptime during run.

## 7. Suggested Dashboard Layout
1. Overview: WAU, Run Success, Crash-free.
2. Activation funnel.
3. Reliability by OEM.
4. Feature usage trends.
5. Error events table.
