package com.sarmatcz.tapmacro

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.util.Calendar

class RunEngineManager private constructor() {
    private val logTag = "TapMacroRunEngine"
    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var stateListener: ((String) -> Unit)? = null
    private var cachedConditionSnapshot: ConditionSnapshot? = null
    @Volatile
    private var runState: RunState = RunState.IDLE
    private var script: ScriptPayload? = null
    private var lastScript: ScriptPayload? = null
    private var activeSteps: List<StepPayload> = emptyList()
    private var stepIndex = 0
    private var completedLoops = 0
    private var startedAtMs = 0L

    private val runner = object : Runnable {
        override fun run() {
            val currentScript = script
            if (currentScript == null || runState != RunState.RUNNING) {
                return
            }

            val currentSteps = activeSteps
            if (currentSteps.isEmpty()) {
                emitError("SCRIPT_INVALID", "Script has no enabled steps.")
                stop(StopReason.ERROR)
                return
            }

            if (stepIndex >= currentSteps.size) {
                stepIndex = 0
                completedLoops += 1
                if (currentScript.loopCount > 0 && completedLoops >= currentScript.loopCount) {
                    Log.i(
                        logTag,
                        "auto_stop reason=loop_completed scriptId=${currentScript.id} completedLoops=$completedLoops"
                    )
                    stop(StopReason.LOOP_COMPLETED)
                    return
                }
            }

            val step = currentSteps[stepIndex]
            val service = AutoClickAccessibilityService.instance
            if (service == null) {
                Log.w(logTag, "auto_stop reason=service_null scriptId=${currentScript.id}")
                stopDueToServiceDown(StopReason.SERVICE_KILLED)
                return
            }
            val conditionFailure = evaluateConditionFailure(service, currentScript)
            if (conditionFailure != null) {
                Log.w(
                    logTag,
                    "auto_stop reason=condition_unmet scriptId=${currentScript.id} code=${conditionFailure.code}"
                )
                emitError(conditionFailure.code, conditionFailure.message)
                stop(StopReason.CONDITION_UNMET)
                return
            }
            val dispatched = dispatchStep(service, step)
            if (!dispatched) {
                Log.e(
                    logTag,
                    "auto_stop reason=dispatch_failed scriptId=${currentScript.id} stepIndex=$stepIndex action=${step.action}"
                )
                emitError("DISPATCH_FAILED", "Unable to dispatch gesture.")
                stop(StopReason.ERROR)
                return
            }
            val elapsed = System.currentTimeMillis() - startedAtMs
            emitEvent(
                mapOf(
                    "type" to "runProgress",
                    "scriptId" to currentScript.id,
                    "stepIndex" to stepIndex,
                    "loopCount" to completedLoops,
                    "elapsedMs" to elapsed,
                    "state" to runState.value,
                    "x" to step.x,
                    "y" to step.y,
                    "dispatched" to dispatched
                )
            )

            stepIndex += 1
            val delay = if (step.intervalMs > 0) step.intervalMs else currentScript.defaultIntervalMs
            handler.postDelayed(this, delay.toLong())
        }
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun setStateListener(listener: ((String) -> Unit)?) {
        stateListener = listener
        listener?.invoke(runState.value)
    }

    fun runScript(payloadMap: Map<*, *>): Boolean {
        val payload = ScriptPayload.fromMap(payloadMap) ?: return false
        Log.i(
            logTag,
            "runScript requested scriptId=${payload.id} steps=${payload.steps.size} loopCount=${payload.loopCount}"
        )
        return runScriptPayload(payload, rememberAsLast = true)
    }

    fun startOrResume(): Boolean {
        Log.i(logTag, "startOrResume requested state=${runState.value}")
        return when (runState) {
            RunState.RUNNING -> true
            RunState.PAUSED -> resume()
            RunState.IDLE -> {
                val payload = lastScript
                if (payload == null) {
                    emitError("NO_LAST_SCRIPT", "No previous script available to start.")
                    Log.w(logTag, "startOrResume failed: no last script")
                    return false
                }
                Log.i(logTag, "startOrResume using lastScriptId=${payload.id}")
                runScriptPayload(payload, rememberAsLast = false)
            }
        }
    }

    private fun runScriptPayload(
        payload: ScriptPayload,
        rememberAsLast: Boolean
    ): Boolean {
        if (runState != RunState.IDLE) {
            emitError("RUN_ALREADY_ACTIVE", "Another run is already active.")
            Log.w(
                logTag,
                "runScript blocked scriptId=${payload.id}: state=${runState.value}"
            )
            return false
        }
        val failure = evaluatePreflightFailure(payload)
        if (failure != null) {
            emitError(failure.code, failure.message)
            Log.w(
                logTag,
                "runScript blocked scriptId=${payload.id} code=${failure.code} message=${failure.message}"
            )
            return false
        }
        val enabledSteps = payload.steps.filter { it.enabled }
        if (enabledSteps.isEmpty()) {
            emitError("SCRIPT_INVALID", "Script has no enabled steps.")
            Log.w(logTag, "runScript blocked scriptId=${payload.id}: no enabled steps")
            return false
        }
        if (rememberAsLast) {
            lastScript = payload
        }
        script = payload
        activeSteps = enabledSteps
        runState = RunState.RUNNING
        stepIndex = 0
        completedLoops = 0
        startedAtMs = System.currentTimeMillis()
        cachedConditionSnapshot = null
        emitState()
        handler.removeCallbacks(runner)
        handler.post(runner)
        Log.i(
            logTag,
            "runScript started scriptId=${payload.id} enabledSteps=${enabledSteps.size} loopCount=${payload.loopCount}"
        )
        return true
    }

    fun validateRunConditions(payloadMap: Map<*, *>): Map<String, Any> {
        val payload = ScriptPayload.fromMap(payloadMap)
            ?: return mapOf(
                "ok" to false,
                "code" to "SCRIPT_INVALID",
                "message" to "Invalid script payload."
            )
        val failure = evaluatePreflightFailure(payload)
        if (failure != null) {
            return mapOf(
                "ok" to false,
                "code" to failure.code,
                "message" to failure.message
            )
        }
        return mapOf("ok" to true)
    }

    fun pause(): Boolean {
        if (runState != RunState.RUNNING) {
            Log.w(logTag, "pause ignored state=${runState.value}")
            return false
        }
        runState = RunState.PAUSED
        handler.removeCallbacks(runner)
        emitState()
        Log.i(logTag, "pause success scriptId=${script?.id ?: "unknown"}")
        return true
    }

    fun resume(): Boolean {
        if (runState != RunState.PAUSED) {
            Log.w(logTag, "resume ignored state=${runState.value}")
            return false
        }
        runState = RunState.RUNNING
        cachedConditionSnapshot = null
        emitState()
        handler.post(runner)
        Log.i(logTag, "resume success scriptId=${script?.id ?: "unknown"}")
        return true
    }

    fun stop(reason: StopReason = StopReason.USER): Boolean {
        if (runState == RunState.IDLE) {
            Log.w(logTag, "stop ignored state=idle reason=${reason.value}")
            return false
        }
        val currentScriptId = script?.id
        val currentCompletedLoops = completedLoops
        val elapsed = if (startedAtMs > 0L) {
            (System.currentTimeMillis() - startedAtMs).coerceAtLeast(0L)
        } else {
            0L
        }
        handler.removeCallbacks(runner)
        runState = RunState.IDLE
        emitState()
        if (currentScriptId != null) {
            emitRunStopped(currentScriptId, reason, elapsed, currentCompletedLoops)
        }
        script = null
        activeSteps = emptyList()
        stepIndex = 0
        completedLoops = 0
        startedAtMs = 0L
        cachedConditionSnapshot = null
        Log.i(
            logTag,
            "stop success reason=${reason.value} scriptId=${currentScriptId ?: "unknown"} elapsedMs=$elapsed"
        )
        return true
    }

    fun getState(): String = runState.value

    fun onAccessibilityServiceConnected() {
        // No-op for now. Kept for symmetry and future extension.
    }

    fun onAccessibilityServiceDisconnected(reason: StopReason = StopReason.SERVICE_KILLED) {
        stopDueToServiceDown(reason)
    }

    private fun emitState() {
        stateListener?.invoke(runState.value)
        emitEvent(
            mapOf(
                "type" to "state",
                "state" to runState.value
            )
        )
    }

    private fun emitError(code: String, message: String) {
        emitEvent(
            mapOf(
                "type" to "error",
                "code" to code,
                "message" to message
            )
        )
    }

    private fun emitRunStopped(
        scriptId: String,
        reason: StopReason,
        elapsedMs: Long,
        completedLoops: Int
    ) {
        emitEvent(
            mapOf(
                "type" to "runStopped",
                "scriptId" to scriptId,
                "stopReason" to reason.value,
                "elapsedMs" to elapsedMs,
                "completedLoops" to completedLoops.coerceAtLeast(0)
            )
        )
    }

    private fun dispatchStep(service: AutoClickAccessibilityService, step: StepPayload): Boolean {
        val holdMs = step.holdMs.toLong().coerceAtLeast(1L)
        return when (step.action) {
            "double_tap" -> service.performDoubleTapNormalized(step.x, step.y, holdMs)
            "swipe" -> {
                val endX = step.x2 ?: step.x
                val endY = step.y2 ?: step.y
                service.performSwipeNormalized(
                    step.x,
                    step.y,
                    endX,
                    endY,
                    step.swipeDurationMs.toLong().coerceAtLeast(1L)
                )
            }
            "multi_touch" -> {
                val secondX = step.x2 ?: step.x
                val secondY = step.y2 ?: step.y
                service.performMultiTouchNormalized(
                    step.x,
                    step.y,
                    secondX,
                    secondY,
                    step.swipeDurationMs.toLong().coerceAtLeast(1L)
                )
            }
            else -> service.performTapNormalized(step.x, step.y, holdMs)
        }
    }

    private fun evaluatePreflightFailure(payload: ScriptPayload): RunFailure? {
        if (payload.steps.none { it.enabled }) {
            return RunFailure("SCRIPT_INVALID", "Script has no enabled steps.")
        }
        val service = AutoClickAccessibilityService.instance
            ?: return RunFailure("SERVICE_DOWN", "Accessibility service is not active.")
        return evaluateConditionFailure(service, payload)
    }

    private fun evaluateConditionFailure(
        service: AutoClickAccessibilityService,
        payload: ScriptPayload
    ): RunFailure? {
        val snapshot = loadConditionSnapshot(service)
        if (payload.requireCharging && !snapshot.isCharging) {
            return RunFailure(
                "CONDITION_REQUIRE_CHARGING",
                "Cannot run: device is not charging."
            )
        }
        if (payload.requireScreenOn && !snapshot.isScreenInteractive) {
            return RunFailure(
                "CONDITION_REQUIRE_SCREEN_ON",
                "Cannot run: screen is off."
            )
        }
        val minBatteryPct = payload.minBatteryPct
        if (minBatteryPct != null) {
            val currentBattery = snapshot.batteryPct
            if (currentBattery < minBatteryPct) {
                return RunFailure(
                    "CONDITION_MIN_BATTERY",
                    "Cannot run: battery ${currentBattery}% is below required ${minBatteryPct}%."
                )
            }
        }
        val requiredForegroundApp = payload.requireForegroundApp
        if (!requiredForegroundApp.isNullOrBlank()) {
            val activePackage = snapshot.foregroundPackage
            if (activePackage.isNullOrBlank() ||
                !activePackage.equals(requiredForegroundApp, ignoreCase = true)
            ) {
                val activeLabel = activePackage ?: "unknown"
                return RunFailure(
                    "CONDITION_FOREGROUND_APP",
                    "Cannot run: foreground app is $activeLabel (required $requiredForegroundApp)."
                )
            }
        }
        val start = payload.timeWindowStart
        val end = payload.timeWindowEnd
        if (start != null && end != null && !isWithinTimeWindow(start, end)) {
            return RunFailure(
                "CONDITION_TIME_WINDOW",
                "Cannot run: current time is outside allowed window $start-$end."
            )
        }
        return null
    }

    private fun loadConditionSnapshot(service: AutoClickAccessibilityService): ConditionSnapshot {
        val nowMs = System.currentTimeMillis()
        val cached = cachedConditionSnapshot
        if (cached != null && nowMs - cached.timestampMs <= conditionSnapshotTtlMs) {
            return cached
        }
        val context = service.applicationContext
        val snapshot = ConditionSnapshot(
            timestampMs = nowMs,
            isCharging = isDeviceCharging(context),
            batteryPct = currentBatteryPct(context),
            isScreenInteractive = isScreenInteractive(context),
            foregroundPackage = service.getForegroundPackageName()
        )
        cachedConditionSnapshot = snapshot
        return snapshot
    }

    private fun isDeviceCharging(context: Context): Boolean {
        val batteryStatus = context.registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        ) ?: return false
        val status = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        return status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
    }

    private fun currentBatteryPct(context: Context): Int {
        val batteryStatus = context.registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        ) ?: return 0
        val level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) {
            return 0
        }
        return ((level * 100f) / scale).toInt().coerceIn(0, 100)
    }

    private fun isScreenInteractive(context: Context): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return false
        return powerManager.isInteractive
    }

    private fun isWithinTimeWindow(start: String, end: String): Boolean {
        val startMin = parseTimeToMinutes(start) ?: return false
        val endMin = parseTimeToMinutes(end) ?: return false
        if (startMin == endMin) {
            return true
        }
        val now = Calendar.getInstance()
        val nowMin = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        return if (startMin < endMin) {
            nowMin in startMin..endMin
        } else {
            nowMin >= startMin || nowMin <= endMin
        }
    }

    private fun parseTimeToMinutes(value: String): Int? {
        val parts = value.trim().split(":")
        if (parts.size != 2) {
            return null
        }
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) {
            return null
        }
        return hour * 60 + minute
    }

    private fun emitEvent(event: Map<String, Any>) {
        eventSink?.success(event)
    }

    private fun stopDueToServiceDown(reason: StopReason) {
        if (runState == RunState.IDLE) {
            return
        }
        val code = if (reason == StopReason.PERMISSION_LOST) {
            "PERMISSION_LOST"
        } else {
            "SERVICE_DOWN"
        }
        Log.w(logTag, "stopDueToServiceDown reason=${reason.value} code=$code")
        emitError(code, "Accessibility service stopped.")
        stop(reason)
    }

    companion object {
        private const val conditionSnapshotTtlMs = 1_000L

        @Volatile
        private var instance: RunEngineManager? = null

        fun getInstance(): RunEngineManager {
            return instance ?: synchronized(this) {
                instance ?: RunEngineManager().also { instance = it }
            }
        }
    }
}

private enum class RunState(val value: String) {
    IDLE("idle"),
    RUNNING("running"),
    PAUSED("paused")
}

enum class StopReason(val value: String) {
    USER("user"),
    LOOP_COMPLETED("loop_completed"),
    ERROR("error"),
    PERMISSION_LOST("permission_lost"),
    SERVICE_KILLED("service_killed"),
    CONDITION_UNMET("condition_unmet")
}

private data class RunFailure(
    val code: String,
    val message: String
)

private data class ConditionSnapshot(
    val timestampMs: Long,
    val isCharging: Boolean,
    val batteryPct: Int,
    val isScreenInteractive: Boolean,
    val foregroundPackage: String?,
)

private data class ScriptPayload(
    val id: String,
    val defaultIntervalMs: Int,
    val loopCount: Int,
    val requireCharging: Boolean,
    val requireScreenOn: Boolean,
    val requireForegroundApp: String?,
    val minBatteryPct: Int?,
    val timeWindowStart: String?,
    val timeWindowEnd: String?,
    val steps: List<StepPayload>
) {
    companion object {
        fun fromMap(map: Map<*, *>): ScriptPayload? {
            val id = map["id"]?.toString() ?: return null
            val defaultIntervalMs = (map["defaultIntervalMs"] as? Number)?.toInt() ?: 300
            val loopCount = (map["loopCount"] as? Number)?.toInt() ?: 1
            val requireCharging = map["requireCharging"] == true
            val requireScreenOn = map["requireScreenOn"] == true
            val requireForegroundApp = map["requireForegroundApp"]
                ?.toString()
                ?.trim()
                ?.ifEmpty { null }
            val minBatteryRaw = (map["minBatteryPct"] as? Number)?.toInt()
            val minBatteryPct = if (minBatteryRaw != null && minBatteryRaw in 0..100) {
                minBatteryRaw
            } else {
                null
            }
            val timeWindowStart = map["timeWindowStart"]?.toString()?.trim()?.ifEmpty { null }
            val timeWindowEnd = map["timeWindowEnd"]?.toString()?.trim()?.ifEmpty { null }
            val rawSteps = map["steps"] as? List<*> ?: emptyList<Any>()
            val steps = rawSteps.mapNotNull { raw ->
                val stepMap = raw as? Map<*, *> ?: return@mapNotNull null
                StepPayload.fromMap(stepMap)
            }
            return ScriptPayload(
                id = id,
                defaultIntervalMs = defaultIntervalMs,
                loopCount = loopCount,
                requireCharging = requireCharging,
                requireScreenOn = requireScreenOn,
                requireForegroundApp = requireForegroundApp,
                minBatteryPct = minBatteryPct,
                timeWindowStart = timeWindowStart,
                timeWindowEnd = timeWindowEnd,
                steps = steps
            )
        }
    }
}

private data class StepPayload(
    val action: String,
    val x: Double,
    val y: Double,
    val x2: Double?,
    val y2: Double?,
    val intervalMs: Int,
    val holdMs: Int,
    val swipeDurationMs: Int,
    val enabled: Boolean
) {
    companion object {
        fun fromMap(map: Map<*, *>): StepPayload? {
            val action = map["action"]?.toString() ?: "tap"
            val x = (map["x"] as? Number)?.toDouble() ?: return null
            val y = (map["y"] as? Number)?.toDouble() ?: return null
            val x2 = (map["x2"] as? Number)?.toDouble()
            val y2 = (map["y2"] as? Number)?.toDouble()
            val intervalMs = (map["intervalMs"] as? Number)?.toInt() ?: 0
            val holdMs = (map["holdMs"] as? Number)?.toInt() ?: 40
            val swipeDurationMs = (map["swipeDurationMs"] as? Number)?.toInt() ?: 250
            val enabled = map["enabled"] == true
            return StepPayload(
                action = action,
                x = x,
                y = y,
                x2 = x2,
                y2 = y2,
                intervalMs = intervalMs,
                holdMs = holdMs,
                swipeDurationMs = swipeDurationMs,
                enabled = enabled
            )
        }
    }
}

