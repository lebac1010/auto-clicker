package com.sarmatcz.tapmacro

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.util.DisplayMetrics
import android.util.Log
import android.view.accessibility.AccessibilityManager
import android.view.KeyEvent
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import kotlin.math.roundToInt

class AutoClickAccessibilityService : AccessibilityService() {
    private val logTag = "TapMacroA11yService"
    private var disconnectionHandled = false
    @Volatile
    private var lastObservedPackageName: String? = null
    private val windowManager: WindowManager by lazy {
        getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        disconnectionHandled = false
        Log.i(logTag, "onServiceConnected")
        RunEngineManager.getInstance().onAccessibilityServiceConnected()
        RecorderManager.getInstance().onAccessibilityServiceConnected()
    }

    override fun onInterrupt() {
        // No-op.
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val accessibilityEvent = event ?: return
        lastObservedPackageName = accessibilityEvent.packageName?.toString()?.trim()?.ifEmpty { null }
        RecorderManager.getInstance().onAccessibilityEvent(accessibilityEvent)
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (!AppSettingsStore.isVolumeKeyStopEnabled(applicationContext)) {
            return super.onKeyEvent(event)
        }
        val volumePressed = event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_UP
        if (!volumePressed) {
            return super.onKeyEvent(event)
        }
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
            Log.i(logTag, "volume_key_stop triggered keyCode=${event.keyCode}")
            RunEngineManager.getInstance().stop()
            RecorderManager.getInstance().clear()
            OverlayController.getInstance(applicationContext).stop()
        }
        return true
    }

    override fun onDestroy() {
        handleServiceDisconnected()
        super.onDestroy()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        handleServiceDisconnected()
        return super.onUnbind(intent)
    }

    fun performTapNormalized(
        normalizedX: Double,
        normalizedY: Double,
        durationMs: Long = 40L,
    ): Boolean {
        val metrics = getRealDisplayMetrics()
        val clampedX = normalizedX.coerceIn(0.0, 1.0)
        val clampedY = normalizedY.coerceIn(0.0, 1.0)
        val maxX = (metrics.widthPixels - 1).coerceAtLeast(0)
        val maxY = (metrics.heightPixels - 1).coerceAtLeast(0)
        val xPx = (clampedX * maxX).roundToInt().toFloat()
        val yPx = (clampedY * maxY).roundToInt().toFloat()
        return performTapPx(xPx, yPx, durationMs)
    }

    fun getRealDisplayMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(metrics)
        return metrics
    }

    fun performTapPx(xPx: Float, yPx: Float, durationMs: Long = 40L): Boolean {
        val path = Path().apply {
            moveTo(xPx, yPx)
        }

        val gesture = GestureDescription.Builder()
            .addStroke(
                GestureDescription.StrokeDescription(path, 0L, durationMs.coerceAtLeast(1L))
            )
            .build()

        return dispatchGesture(gesture, null, null)
    }

    fun performDoubleTapNormalized(
        normalizedX: Double,
        normalizedY: Double,
        durationMs: Long = 40L,
        gapMs: Long = 80L,
    ): Boolean {
        val metrics = getRealDisplayMetrics()
        val clampedX = normalizedX.coerceIn(0.0, 1.0)
        val clampedY = normalizedY.coerceIn(0.0, 1.0)
        val maxX = (metrics.widthPixels - 1).coerceAtLeast(0)
        val maxY = (metrics.heightPixels - 1).coerceAtLeast(0)
        val xPx = (clampedX * maxX).roundToInt().toFloat()
        val yPx = (clampedY * maxY).roundToInt().toFloat()
        return performDoubleTapPx(xPx, yPx, durationMs, gapMs)
    }

    fun getForegroundPackageName(): String? {
        val rootPackage = rootInActiveWindow?.packageName?.toString()?.trim()?.ifEmpty { null }
        return rootPackage ?: lastObservedPackageName
    }

    fun performSwipeNormalized(
        startX: Double,
        startY: Double,
        endX: Double,
        endY: Double,
        durationMs: Long = 250L,
    ): Boolean {
        val metrics = getRealDisplayMetrics()
        val maxX = (metrics.widthPixels - 1).coerceAtLeast(0)
        val maxY = (metrics.heightPixels - 1).coerceAtLeast(0)
        val x1 = (startX.coerceIn(0.0, 1.0) * maxX).roundToInt().toFloat()
        val y1 = (startY.coerceIn(0.0, 1.0) * maxY).roundToInt().toFloat()
        val x2 = (endX.coerceIn(0.0, 1.0) * maxX).roundToInt().toFloat()
        val y2 = (endY.coerceIn(0.0, 1.0) * maxY).roundToInt().toFloat()
        val path = Path().apply {
            moveTo(x1, y1)
            lineTo(x2, y2)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(
                GestureDescription.StrokeDescription(path, 0L, durationMs.coerceAtLeast(1L))
            )
            .build()
        return dispatchGesture(gesture, null, null)
    }

    fun performMultiTouchNormalized(
        firstX: Double,
        firstY: Double,
        secondX: Double,
        secondY: Double,
        durationMs: Long = 180L,
    ): Boolean {
        val metrics = getRealDisplayMetrics()
        val maxX = (metrics.widthPixels - 1).coerceAtLeast(0)
        val maxY = (metrics.heightPixels - 1).coerceAtLeast(0)
        val x1 = (firstX.coerceIn(0.0, 1.0) * maxX).roundToInt().toFloat()
        val y1 = (firstY.coerceIn(0.0, 1.0) * maxY).roundToInt().toFloat()
        val x2 = (secondX.coerceIn(0.0, 1.0) * maxX).roundToInt().toFloat()
        val y2 = (secondY.coerceIn(0.0, 1.0) * maxY).roundToInt().toFloat()
        val firstPath = Path().apply { moveTo(x1, y1) }
        val secondPath = Path().apply { moveTo(x2, y2) }
        val gesture = GestureDescription.Builder()
            .addStroke(
                GestureDescription.StrokeDescription(
                    firstPath,
                    0L,
                    durationMs.coerceAtLeast(1L)
                )
            )
            .addStroke(
                GestureDescription.StrokeDescription(
                    secondPath,
                    0L,
                    durationMs.coerceAtLeast(1L)
                )
            )
            .build()
        return dispatchGesture(gesture, null, null)
    }

    private fun performDoubleTapPx(
        xPx: Float,
        yPx: Float,
        durationMs: Long,
        gapMs: Long,
    ): Boolean {
        val tapDuration = durationMs.coerceAtLeast(1L)
        val secondTapStart = tapDuration + gapMs.coerceAtLeast(1L)
        val firstPath = Path().apply { moveTo(xPx, yPx) }
        val secondPath = Path().apply { moveTo(xPx, yPx) }
        val gesture = GestureDescription.Builder()
            .addStroke(
                GestureDescription.StrokeDescription(firstPath, 0L, tapDuration)
            )
            .addStroke(
                GestureDescription.StrokeDescription(secondPath, secondTapStart, tapDuration)
            )
            .build()
        return dispatchGesture(gesture, null, null)
    }

    companion object {
        @Volatile
        var instance: AutoClickAccessibilityService? = null
            private set
    }

    private fun handleServiceDisconnected() {
        if (disconnectionHandled) {
            return
        }
        disconnectionHandled = true
        val stopReason = if (isAccessibilityEnabledForThisApp()) {
            StopReason.SERVICE_KILLED
        } else {
            StopReason.PERMISSION_LOST
        }
        if (instance === this) {
            instance = null
        }
        Log.w(logTag, "serviceDisconnected reason=${stopReason.value}")
        RunEngineManager.getInstance().onAccessibilityServiceDisconnected(stopReason)
        RecorderManager.getInstance().onAccessibilityServiceDisconnected()
    }

    private fun isAccessibilityEnabledForThisApp(): Boolean {
        return try {
            val manager = getSystemService(ACCESSIBILITY_SERVICE) as AccessibilityManager
            val enabledServices = manager.getEnabledAccessibilityServiceList(
                AccessibilityServiceInfo.FEEDBACK_ALL_MASK
            )
            enabledServices.any { service ->
                service.resolveInfo.serviceInfo.packageName == packageName
            }
        } catch (_: Exception) {
            false
        }
    }
}

