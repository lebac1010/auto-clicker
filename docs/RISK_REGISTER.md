# Risk Register

Version: 1.0
Date: 2026-02-09

## 1. Format
- Risk ID
- Description
- Impact: High, Medium, Low
- Likelihood: High, Medium, Low
- Mitigation
- Owner
- Status: Open, Mitigating, Closed

## 2. Risks
1. Risk ID: R001
   Description: Accessibility service killed by OEM.
   Impact: High
   Likelihood: High
   Mitigation: Foreground service, OEM guides, detection and recovery.
   Owner: Android Dev
   Status: Open

2. Risk ID: R002
   Description: Overlay permission revoked during run.
   Impact: High
   Likelihood: Medium
   Mitigation: Detect revoke, show modal, stop run safely.
   Owner: Flutter Dev
   Status: Open

3. Risk ID: R003
   Description: Coordinate mismatch on rotation or cutouts.
   Impact: High
   Likelihood: Medium
   Mitigation: Normalize coords, store insets, re-map on rotation.
   Owner: Android Dev
   Status: Open

4. Risk ID: R004
   Description: Recorder does not capture all gestures on some OEMs.
   Impact: Medium
   Likelihood: High
   Mitigation: Warn user, manual edit timeline, fallback to manual steps.
   Owner: Android Dev
   Status: Open

5. Risk ID: R005
   Description: Play Store policy risk for auto-click behavior.
   Impact: High
   Likelihood: Medium
   Mitigation: Clear disclosure, avoid cheating positioning, privacy statement.
   Owner: PM
   Status: Open

6. Risk ID: R006
   Description: Performance degradation with high step counts.
   Impact: Medium
   Likelihood: Medium
   Mitigation: Single-thread scheduler, rate limiting, warn users.
   Owner: Android Dev
   Status: Open

7. Risk ID: R007
   Description: Foreground notification blocked on Android 13+.
   Impact: Medium
   Likelihood: Medium
   Mitigation: Request notification permission, fallback UI warning.
   Owner: Flutter Dev
   Status: Open

8. Risk ID: R008
   Description: Import schema changes break older scripts.
   Impact: Medium
   Likelihood: Low
   Mitigation: Versioned schema and migration layer.
   Owner: Flutter Dev
   Status: Open

9. Risk ID: R009
   Description: User confusion about permissions causing drop-off.
   Impact: Medium
   Likelihood: Medium
   Mitigation: Clear onboarding and per-permission explanation.
   Owner: BA
   Status: Open

10. Risk ID: R010
    Description: Accessibility service conflicts with other overlays.
    Impact: Low
    Likelihood: Medium
    Mitigation: Detect overlay collision and show warning.
    Owner: Android Dev
    Status: Open
