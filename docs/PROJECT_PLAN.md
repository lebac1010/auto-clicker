# Project Execution Plan

Version: 1.0
Date: 2026-02-09
Scope: Android-only Auto Clicker (Flutter + Native)

## 1. Objectives
1. Deliver MVP that supports multi-point taps with floating controller and recorder.
2. Achieve crash-free sessions >= 99.0%.
3. Run success rate >= 95% for 5-minute sessions.

## 2. Team and Roles
1. Flutter Dev A: UI, navigation, state, data layer.
2. Flutter Dev B: Script editor, import/export, settings.
3. Android Dev: Accessibility service, overlay, gesture engine, recorder.
4. QA: Test execution, device matrix, regression.
5. BA/PM: Scope control, PRD updates, acceptance reviews.

## 3. Work Breakdown Structure (WBS)
### Phase 0 - Discovery and Setup (Week 1)
1. Lock PRD scope and acceptance criteria.
2. Finalize JSON schema and analytics event mapping.
3. Decide minSdkVersion and targetSdkVersion.
4. Scaffold Flutter project and native Android module.
5. Establish CI for build and lint.
Deliverables:
1. PRD v1.1 locked.
2. App boots on device with placeholder screen.
Dependencies:
1. Android dev machine and test device ready.

### Phase 1 - Permissions and Onboarding (Weeks 2-3)
1. Implement Splash routing by permission state.
2. Implement onboarding slides and CTA.
3. Implement Permissions Hub with deep links.
4. Implement permission state polling and updates.
Deliverables:
1. Permissions Hub functional.
2. Home screen reachable after core permissions.
Dependencies:
1. MethodChannel for permission states.

### Phase 2 - Script Model and Storage (Weeks 3-4)
1. Implement Script model and validator.
2. Implement Script repository with JSON storage.
3. Implement Script list and recent scripts.
Deliverables:
1. CRUD for scripts.
2. Search, filter, sort in Script list.

### Phase 3 - Script Editor (Weeks 4-6)
1. Implement Targets tab and point list.
2. Implement Add Point overlay pick flow.
3. Implement Timing tab settings.
4. Implement Save, Validate, Test cycle.
Deliverables:
1. Script editor functional for multi-point taps.
Dependencies:
1. Overlay pick mode from native.

### Phase 4 - Floating Controller (Weeks 6-8)
1. Implement overlay bubble and mini panel.
2. Implement Start, Pause, Stop actions.
3. Implement markers and drag updates.
4. Implement STOP always visible.
Deliverables:
1. Controller usable across apps.
Dependencies:
1. Overlay permission ON.

### Phase 5 - Gesture Engine (Weeks 6-8)
1. Implement ScriptRunner and scheduler.
2. Implement dispatchGesture and stop cancel.
3. Implement run progress events.
Deliverables:
1. Stable run with multi-point taps.
Dependencies:
1. Accessibility service ON.

### Phase 6 - Recorder (Weeks 8-9)
1. Implement record countdown.
2. Capture actions and delays.
3. Timeline editor basic.
4. Save to script.
Deliverables:
1. Recorder creates scripts.
Dependencies:
1. Gesture events capture on OEM test device.

### Phase 7 - Import and Export (Week 10)
1. Export JSON for single and all scripts.
2. Import JSON with schema validation.
3. Error handling for invalid schema.
Deliverables:
1. Import and export working.

### Phase 8 - Stability and QA (Weeks 11-12)
1. OEM device testing and bug fixes.
2. Performance tests and optimization.
3. Add Help and troubleshooting content.
Deliverables:
1. QA sign-off.
2. Performance benchmarks met.

### Phase 9 - Release Preparation (Week 13)
1. Final acceptance review.
2. App store listing assets.
3. Release build signed and validated.
Deliverables:
1. Release candidate.

## 4. Milestones and Gates
1. M1: Permissions flow complete.
2. M2: Script editor functional.
3. M3: Floating controller functional.
4. M4: Recorder and import/export functional.
5. M5: QA pass and release candidate.

## 5. Dependencies
1. Accessibility Service and overlay permissions must be approved by policy.
2. Overlay and gesture engine must be implemented in native.
3. Recorder viability depends on OEM behavior.

## 6. Risks and Mitigation
1. OEM kills service: implement foreground service and recovery.
2. Policy risk: clear disclosure and avoid cheating positioning.
3. Coordinate drift: store insets and re-map on rotation.

## 7. QA Strategy
1. Use `docs/QA_CHECKLIST.md` as regression.
2. Validate JSON schema on import.
3. Performance tests for 30-minute runs.

## 8. Timeline Summary
1. Total: 13 weeks (including buffer).
2. Buffer: 10% for OEM and policy issues.

## 9. Definition of Done
1. All acceptance criteria in PRD pass.
2. Crash-free sessions >= 99.0%.
3. Run success rate >= 95% for 5-minute run.
4. QA checklist 100% pass.
