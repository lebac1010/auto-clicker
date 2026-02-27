package com.sarmatcz.tapmacro

import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.EventChannel

class RecorderManager private constructor() {
    private val handler = Handler(Looper.getMainLooper())
    private var state: RecorderState = RecorderState.IDLE
    private var sink: EventChannel.EventSink? = null
    private var stateListener: ((String) -> Unit)? = null
    private var countdownRemaining = 0
    private var lastEventAt = 0L
    private var lastRecordedSignature = ""
    private var lastRecordedEventTime = 0L
    private val steps = mutableListOf<Map<String, Any>>()

    fun setEventSink(eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    fun setStateListener(listener: ((String) -> Unit)?) {
        stateListener = listener
        listener?.invoke(state.value)
    }

    fun getState(): String = state.value

    fun onAccessibilityServiceConnected() {
        // No-op for now. Recorder stays idle after reconnection.
    }

    fun onAccessibilityServiceDisconnected() {
        if (state != RecorderState.COUNTDOWN && state != RecorderState.RECORDING) {
            return
        }
        handler.removeCallbacksAndMessages(null)
        countdownRemaining = 0
        lastEventAt = 0L
        lastRecordedSignature = ""
        lastRecordedEventTime = 0L
        state = RecorderState.IDLE
        emitError("RECORDER_SERVICE_DOWN", "Accessibility service stopped.")
        emitState()
    }

    fun start(countdownSec: Int): Boolean {
        if (state == RecorderState.RECORDING || state == RecorderState.COUNTDOWN) {
            return false
        }
        if (AutoClickAccessibilityService.instance == null) {
            emitError("RECORDER_UNSUPPORTED", "Accessibility service is not active.")
            return false
        }
        handler.removeCallbacksAndMessages(null)
        steps.clear()
        lastEventAt = 0L
        lastRecordedSignature = ""
        lastRecordedEventTime = 0L
        countdownRemaining = countdownSec.coerceAtLeast(0)
        if (countdownRemaining == 0) {
            state = RecorderState.RECORDING
            emitState()
            return true
        }
        state = RecorderState.COUNTDOWN
        emitState()
        runCountdownTick()
        return true
    }

    fun stop(): Map<String, Any> {
        handler.removeCallbacksAndMessages(null)
        if (state != RecorderState.IDLE) {
            state = RecorderState.STOPPED
            emitState()
        }
        return mapOf(
            "steps" to steps.toList()
        )
    }

    fun clear(): Boolean {
        handler.removeCallbacksAndMessages(null)
        countdownRemaining = 0
        steps.clear()
        lastEventAt = 0L
        lastRecordedSignature = ""
        lastRecordedEventTime = 0L
        if (state != RecorderState.IDLE) {
            state = RecorderState.IDLE
            emitState()
        }
        return true
    }

    fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (state != RecorderState.RECORDING) {
            return
        }
        if (event.eventType != AccessibilityEvent.TYPE_VIEW_CLICKED) {
            return
        }

        val source = event.source ?: return
        try {
            val bounds = Rect()
            source.getBoundsInScreen(bounds)
            val service = AutoClickAccessibilityService.instance ?: run {
                onAccessibilityServiceDisconnected()
                return
            }
            val metrics = service.getRealDisplayMetrics()
            if (metrics.widthPixels <= 1 || metrics.heightPixels <= 1) {
                return
            }
            val maxX = (metrics.widthPixels - 1).toFloat()
            val maxY = (metrics.heightPixels - 1).toFloat()
            val centerX = bounds.exactCenterX().coerceIn(0f, maxX)
            val centerY = bounds.exactCenterY().coerceIn(0f, maxY)
            val normalizedX = (centerX / maxX).toDouble().coerceIn(0.0, 1.0)
            val normalizedY = (centerY / maxY).toDouble().coerceIn(0.0, 1.0)
            val now = System.currentTimeMillis()
            val signature = buildEventSignature(event, bounds)
            val eventTime = event.eventTime
            if (signature == lastRecordedSignature && eventTime == lastRecordedEventTime) {
                return
            }
            val delay = if (lastEventAt == 0L) 0 else (now - lastEventAt).toInt().coerceAtLeast(0)
            lastEventAt = now
            lastRecordedSignature = signature
            lastRecordedEventTime = eventTime
            val step = mapOf(
                "type" to "record_step",
                "index" to (steps.size + 1),
                "action" to "tap",
                "x" to normalizedX,
                "y" to normalizedY,
                "delayMs" to delay,
                "enabled" to true
            )
            steps.add(step)
            sink?.success(step)
        } finally {
            source.recycle()
        }
    }

    private fun runCountdownTick() {
        if (AutoClickAccessibilityService.instance == null) {
            onAccessibilityServiceDisconnected()
            return
        }
        emitCountdown()
        if (countdownRemaining <= 0) {
            state = RecorderState.RECORDING
            emitState()
            return
        }
        handler.postDelayed({
            countdownRemaining -= 1
            runCountdownTick()
        }, 1000L)
    }

    private fun emitCountdown() {
        sink?.success(
            mapOf(
                "type" to "countdown",
                "remainingSec" to countdownRemaining
            )
        )
    }

    private fun emitState() {
        stateListener?.invoke(state.value)
        sink?.success(
            mapOf(
                "type" to "state",
                "state" to state.value
            )
        )
    }

    private fun emitError(code: String, message: String) {
        sink?.success(
            mapOf(
                "type" to "error",
                "code" to code,
                "message" to message
            )
        )
    }

    private fun buildEventSignature(event: AccessibilityEvent, bounds: Rect): String {
        val packageName = event.packageName?.toString() ?: ""
        val className = event.className?.toString() ?: ""
        return "$packageName|$className|${bounds.left},${bounds.top},${bounds.right},${bounds.bottom}"
    }

    companion object {
        @Volatile
        private var instance: RecorderManager? = null

        fun getInstance(): RecorderManager {
            return instance ?: synchronized(this) {
                instance ?: RecorderManager().also { instance = it }
            }
        }
    }
}

private enum class RecorderState(val value: String) {
    IDLE("idle"),
    COUNTDOWN("countdown"),
    RECORDING("recording"),
    STOPPED("stopped")
}

