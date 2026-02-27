# Script JSON Schema

Version: 1.0
Date: 2026-02-09

## 1. Design Principles
1. Stable across screen rotation and cutouts.
2. Backward compatible with schemaVersion.
3. Friendly for export and import.

## 2. Core Fields
- schemaVersion: string
- id: string
- name: string
- type: enum
- createdAt: ISO 8601
- updatedAt: ISO 8601
- coordinateMode: enum
- screen: object
- loop: object
- defaults: object
- steps: array
- conditions: object optional
- metadata: object optional

## 3. Enums
- type: single_tap, multi_tap, swipe, macro
- coordinateMode: normalized, absolute_px
- loop.mode: infinite, count, duration
- step.type: tap, long_press, swipe, wait

## 4. Screen Object
- widthPx: number
- heightPx: number
- densityDpi: number
- rotation: 0, 90, 180, 270
- insets: topPx, bottomPx, leftPx, rightPx

## 5. Step Fields
- id: string
- type: enum
- x: number
- y: number
- x2: number optional for swipe
- y2: number optional for swipe
- durationMs: number optional
- intervalMs: number optional
- enabled: boolean
- label: string optional

## 6. Example
```json
{
  "schemaVersion": "1.0",
  "id": "scr_001",
  "name": "Farm Loop",
  "type": "multi_tap",
  "createdAt": "2026-02-09T12:00:00Z",
  "updatedAt": "2026-02-09T12:00:00Z",
  "coordinateMode": "normalized",
  "screen": {
    "widthPx": 1080,
    "heightPx": 2400,
    "densityDpi": 420,
    "rotation": 0,
    "insets": { "topPx": 80, "bottomPx": 0, "leftPx": 0, "rightPx": 0 }
  },
  "loop": {
    "mode": "count",
    "count": 200,
    "durationMs": null
  },
  "defaults": {
    "intervalMs": 300,
    "holdMs": 40,
    "jitterPx": 4,
    "randomDelayMsMin": 0,
    "randomDelayMsMax": 50
  },
  "steps": [
    {
      "id": "step_1",
      "type": "tap",
      "x": 0.35,
      "y": 0.62,
      "intervalMs": 250,
      "enabled": true,
      "label": "Point A"
    },
    {
      "id": "step_2",
      "type": "tap",
      "x": 0.62,
      "y": 0.62,
      "intervalMs": 250,
      "enabled": true,
      "label": "Point B"
    }
  ],
  "conditions": {
    "requireForegroundApp": null,
    "requireScreenOn": true,
    "minBatteryPct": 15,
    "timeWindow": null
  },
  "metadata": {
    "tags": ["farm", "tap"],
    "notes": "Demo script"
  }
}
```
