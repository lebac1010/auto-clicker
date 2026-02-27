# Information Architecture and User Flows

Version: 1.0
Date: 2026-02-09

## 1. Sitemap
1. Splash
2. Onboarding
3. Permissions Hub
4. Home
5. Script List
6. New Script Wizard
7. Script Editor
8. Floating Controller
9. Recorder Mode
10. Run Options
11. Scheduler
12. Settings
13. Import and Export
14. Pro and Paywall
15. Help and Troubleshooting
16. Error and Empty States

## 2. Primary User Flows
### 2.1 First Launch to First Run
1. Open app
2. Splash checks permissions
3. Onboarding slides
4. Permissions Hub
5. Enable Accessibility
6. Enable Overlay
7. Continue to Home
8. Create New Script
9. Add first point in overlay pick mode
10. Save script
11. Start Floating Controller
12. Run script

### 2.2 Quick Run of Recent Script
1. Open app
2. Home shows Recent Scripts
3. Tap Run
4. Floating Controller appears
5. Start execution
6. Stop using STOP control

### 2.3 Create Multi-Point Script
1. Home
2. Create New Script
3. Choose Multi Target
4. Set interval and loop
5. Add points via overlay pick mode
6. Reorder points
7. Save

### 2.4 Recorder to Script
1. Home
2. Recorder Mode
3. Countdown 3 seconds
4. Perform actions
5. Stop recording
6. Review timeline
7. Edit delays
8. Save as script

### 2.5 Permission Recovery Flow
1. User taps Run
2. App detects Accessibility OFF
3. Show blocking modal with deep link
4. User enables service
5. Return to app
6. Resume run

### 2.6 Import Script
1. Home
2. Import
3. Choose JSON file
4. Validate schema
5. Create script
6. Show success

## 3. Error and Empty State Flows
### 3.1 Script Without Points
1. User taps Run
2. Validate fails
3. Show empty state
4. CTA Add First Point

### 3.2 Overlay Permission Revoked
1. User starts run
2. Overlay permission missing
3. Show modal and deep link
4. Return to app

### 3.3 Service Killed
1. Execution stops unexpectedly
2. Detect service down
3. Show warning banner
4. Offer reopen settings

## 4. Navigation Rules
1. Permissions Hub blocks access to Home until Accessibility and Overlay are enabled.
2. Script Editor accessible only when a script exists.
3. Floating Controller can be launched from Home or Editor.
4. Recorder can be launched without an existing script.
