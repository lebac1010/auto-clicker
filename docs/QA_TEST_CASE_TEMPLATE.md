# QA Test Case Template

Version: 1.0
Date: 2026-02-09

## 1. Template Fields
- Test Case ID
- Title
- Priority: P0, P1, P2
- Type: Functional, Regression, Performance, Usability
- Preconditions
- Steps
- Expected Result
- Actual Result
- Status: Pass, Fail, Blocked
- Environment
- Device Model
- Android Version
- Build Version
- Attachments
- Notes

## 2. Example Test Case
Test Case ID: TC_PERM_001
Title: Accessibility permission card opens correct settings
Priority: P0
Type: Functional
Preconditions:
1. App installed.
2. Accessibility permission OFF.
Steps:
1. Open app.
2. Navigate to Permissions Hub.
3. Tap Accessibility card Enable button.
Expected Result:
1. System Accessibility Settings opens.
2. App listed in Accessibility services.
Actual Result:
Status:
Environment: Staging
Device Model: Pixel 7
Android Version: 14
Build Version: 1.0.0 (100)
Attachments:
Notes:

## 3. Suggested Test Case Set
1. TC_PERM_001 Accessibility card opens settings.
2. TC_PERM_002 Overlay card opens settings.
3. TC_PERM_003 Continue disabled until core permissions ON.
4. TC_HOME_001 Recent scripts empty state.
5. TC_EDITOR_001 Add point via overlay pick.
6. TC_RUN_001 STOP cancels within 1 second.
7. TC_REC_001 Recorder saves script.
8. TC_IMP_001 Import invalid JSON shows error.
9. TC_ROT_001 Rotation preserves marker positions.
10. TC_ERR_001 Overlay revoke during run shows modal.
