package com.sarmatcz.tapmacro

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

object SchedulerManager {
    private const val tag = "SchedulerManager"
    private const val alarmAction = "com.sarmatcz.tapmacro.SCHEDULER_ALARM"
    private const val alarmRequestCode = 30201
    private const val dueRetryMs = 60_000L
    private const val busyRetryMs = 30_000L
    private const val minLeadMs = 5_000L
    private const val startRunTimeoutMs = 3_000L

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val isoUtcFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    fun start(context: Context): Boolean {
        val appContext = context.applicationContext
        ExecutionStateSyncBridge.install(appContext)
        ensureOverlayCallbacks(appContext)
        executor.execute {
            runCatching { dispatchAndScheduleNext(appContext) }
                .onFailure { Log.e(tag, "start failed", it) }
        }
        return true
    }

    fun reschedule(context: Context): Boolean {
        val appContext = context.applicationContext
        ExecutionStateSyncBridge.install(appContext)
        ensureOverlayCallbacks(appContext)
        executor.execute {
            runCatching { dispatchAndScheduleNext(appContext) }
                .onFailure { Log.e(tag, "reschedule failed", it) }
        }
        return true
    }

    fun stop(context: Context): Boolean {
        cancelAlarm(context.applicationContext)
        return true
    }

    fun onAlarm(context: Context, onComplete: (() -> Unit)? = null) {
        val appContext = context.applicationContext
        ExecutionStateSyncBridge.install(appContext)
        ensureOverlayCallbacks(appContext)
        executor.execute {
            try {
                dispatchAndScheduleNext(appContext)
            } catch (error: Throwable) {
                Log.e(tag, "alarm handling failed", error)
            } finally {
                onComplete?.invoke()
            }
        }
    }

    private fun dispatchAndScheduleNext(context: Context) {
        val now = System.currentTimeMillis()
        val schedules = loadSchedules(context)
        val runState = RunEngineManager.getInstance().getState()
        if (runState == "idle") {
            dispatchDueSchedules(context, schedules, now)
        }
        val nextAt = computeNextCheckAt(schedules, System.currentTimeMillis(), runState)
        if (nextAt == null) {
            cancelAlarm(context)
            return
        }
        scheduleAlarm(context, nextAt)
    }

    private fun dispatchDueSchedules(
        context: Context,
        schedules: List<StoredSchedule>,
        nowMs: Long
    ) {
        for (schedule in schedules) {
            if (!schedule.enabled || !isDueNow(schedule, nowMs)) {
                continue
            }
            val payload = try {
                loadScriptPayload(context, schedule.scriptId)
            } catch (error: Throwable) {
                Log.w(tag, "Skip schedule ${schedule.id}: script parse failed", error)
                continue
            }
            if (payload == null) {
                disableSchedule(schedule, nowMs)
                continue
            }
            val started = startScheduledRunOnMainThread(context, payload)
            if (started) {
                markTriggered(schedule, nowMs)
                markScriptRun(context, schedule.scriptId, nowMs)
                return
            }
        }
    }

    private fun startScheduledRunOnMainThread(
        context: Context,
        payload: Map<String, Any>
    ): Boolean {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            return startScheduledRunOnMain(context, payload)
        }
        val latch = CountDownLatch(1)
        var started = false
        mainHandler.post {
            started = startScheduledRunOnMain(context, payload)
            latch.countDown()
        }
        val completed = latch.await(startRunTimeoutMs, TimeUnit.MILLISECONDS)
        if (!completed) {
            Log.w(tag, "Timed out waiting for scheduled run start on main thread")
            return false
        }
        return started
    }

    private fun startScheduledRunOnMain(context: Context, payload: Map<String, Any>): Boolean {
        val overlayController = OverlayController.getInstance(context)
        val overlayStarted = overlayController.start()
        if (overlayStarted) {
            overlayController.updateRunMarkersFromScript(payload)
        }
        return RunEngineManager.getInstance().runScript(payload)
    }

    private fun computeNextCheckAt(
        schedules: List<StoredSchedule>,
        nowMs: Long,
        runState: String
    ): Long? {
        if (schedules.none { it.enabled }) {
            return null
        }
        if (runState != "idle") {
            return nowMs + busyRetryMs
        }
        var next: Long? = null
        for (schedule in schedules) {
            if (!schedule.enabled) {
                continue
            }
            val candidate = computeScheduleNextCheckAt(schedule, nowMs) ?: continue
            if (next == null || candidate < next) {
                next = candidate
            }
        }
        return next
    }

    private fun computeScheduleNextCheckAt(schedule: StoredSchedule, nowMs: Long): Long? {
        if (isDueNow(schedule, nowMs)) {
            return nowMs + dueRetryMs
        }
        return when (schedule.type) {
            "daily" -> nextDailyOccurrenceAt(schedule.timeOfDay, nowMs)
            "weekly" -> nextWeeklyOccurrenceAt(schedule.timeOfDay, schedule.weekdays, nowMs)
            "once" -> {
                val onceAt = schedule.onceAtMs ?: return null
                if (onceAt <= nowMs) nowMs + dueRetryMs else onceAt
            }
            else -> null
        }
    }

    private fun isDueNow(schedule: StoredSchedule, nowMs: Long): Boolean {
        return when (schedule.type) {
            "daily" -> {
                val hm = parseHourMinute(schedule.timeOfDay) ?: return false
                if (isTriggeredOnSameDay(schedule.lastTriggeredAtMs, nowMs)) {
                    return false
                }
                nowMs >= todayAt(hm.first, hm.second, nowMs)
            }
            "weekly" -> {
                val hm = parseHourMinute(schedule.timeOfDay) ?: return false
                val nowCalendar = Calendar.getInstance()
                nowCalendar.timeInMillis = nowMs
                val nowWeekday = toDartWeekday(nowCalendar)
                if (!schedule.weekdays.contains(nowWeekday)) {
                    return false
                }
                if (isTriggeredOnSameDay(schedule.lastTriggeredAtMs, nowMs)) {
                    return false
                }
                nowMs >= todayAt(hm.first, hm.second, nowMs)
            }
            "once" -> {
                val onceAt = schedule.onceAtMs ?: return false
                if (schedule.lastTriggeredAtMs != null && schedule.lastTriggeredAtMs >= onceAt) {
                    return false
                }
                nowMs >= onceAt
            }
            else -> false
        }
    }

    private fun nextDailyOccurrenceAt(timeOfDay: String?, nowMs: Long): Long? {
        val hm = parseHourMinute(timeOfDay) ?: return null
        val today = todayAt(hm.first, hm.second, nowMs)
        return if (today > nowMs) today else today + 24 * 60 * 60 * 1000L
    }

    private fun nextWeeklyOccurrenceAt(
        timeOfDay: String?,
        weekdays: Set<Int>,
        nowMs: Long
    ): Long? {
        if (weekdays.isEmpty()) {
            return null
        }
        val hm = parseHourMinute(timeOfDay) ?: return null
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = nowMs
        for (offset in 0..7) {
            val probe = calendar.clone() as Calendar
            probe.add(Calendar.DAY_OF_YEAR, offset)
            val weekday = toDartWeekday(probe)
            if (!weekdays.contains(weekday)) {
                continue
            }
            probe.set(Calendar.HOUR_OF_DAY, hm.first)
            probe.set(Calendar.MINUTE, hm.second)
            probe.set(Calendar.SECOND, 0)
            probe.set(Calendar.MILLISECOND, 0)
            val candidate = probe.timeInMillis
            if (candidate > nowMs) {
                return candidate
            }
        }
        return null
    }

    private fun todayAt(hour: Int, minute: Int, nowMs: Long): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = nowMs
        calendar.set(Calendar.HOUR_OF_DAY, hour)
        calendar.set(Calendar.MINUTE, minute)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    private fun isTriggeredOnSameDay(lastTriggeredAtMs: Long?, nowMs: Long): Boolean {
        if (lastTriggeredAtMs == null) {
            return false
        }
        val a = Calendar.getInstance().apply { timeInMillis = lastTriggeredAtMs }
        val b = Calendar.getInstance().apply { timeInMillis = nowMs }
        return a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
            a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
    }

    private fun toDartWeekday(calendar: Calendar): Int {
        return when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            Calendar.SUNDAY -> 7
            else -> 1
        }
    }

    private fun parseHourMinute(value: String?): Pair<Int, Int>? {
        val text = value?.trim().orEmpty()
        if (text.isEmpty()) {
            return null
        }
        val parts = text.split(":")
        if (parts.size != 2) {
            return null
        }
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) {
            return null
        }
        return hour to minute
    }

    private fun scheduleAlarm(context: Context, triggerAtMs: Long) {
        val intent = Intent(context, SchedulerAlarmReceiver::class.java).apply {
            action = alarmAction
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = (triggerAtMs.coerceAtLeast(System.currentTimeMillis() + minLeadMs))
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    at,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, at, pendingIntent)
            }
        } catch (_: SecurityException) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, at, pendingIntent)
            }
        }
    }

    private fun cancelAlarm(context: Context) {
        val intent = Intent(context, SchedulerAlarmReceiver::class.java).apply {
            action = alarmAction
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
    }

    private fun loadSchedules(context: Context): List<StoredSchedule> {
        val dir = File(appFlutterDir(context), "schedules")
        if (!dir.exists()) {
            return emptyList()
        }
        val files = dir.listFiles { file -> file.isFile && file.name.endsWith(".json") } ?: return emptyList()
        return files.mapNotNull { file ->
            runCatching {
                val json = JSONObject(file.readText())
                parseStoredSchedule(file, json)
            }.getOrElse {
                Log.w(tag, "Skip invalid schedule file: ${file.name}", it)
                null
            }
        }.sortedBy { it.updatedAtMs ?: 0L }
    }

    private fun parseStoredSchedule(file: File, json: JSONObject): StoredSchedule? {
        val id = json.optString("id", "").trim()
        val scriptId = json.optString("scriptId", "").trim()
        val type = json.optString("type", "").trim()
        if (id.isEmpty() || scriptId.isEmpty() || type.isEmpty()) {
            return null
        }
        if (type != "daily" && type != "weekly" && type != "once") {
            return null
        }
        val weekdays = mutableSetOf<Int>()
        val weekdaysArray = json.optJSONArray("weekdays") ?: JSONArray()
        for (index in 0 until weekdaysArray.length()) {
            val day = weekdaysArray.optInt(index, -1)
            if (day in 1..7) {
                weekdays.add(day)
            }
        }
        return StoredSchedule(
            file = file,
            json = json,
            id = id,
            scriptId = scriptId,
            type = type,
            enabled = json.optBoolean("enabled", false),
            timeOfDay = json.optString("timeOfDay", "").trim().ifEmpty { null },
            weekdays = weekdays,
            onceAtMs = parseIsoUtcToEpochMs(json.opt("onceAt")?.toString()),
            lastTriggeredAtMs = parseIsoUtcToEpochMs(json.opt("lastTriggeredAt")?.toString()),
            updatedAtMs = parseIsoUtcToEpochMs(json.opt("updatedAt")?.toString()),
        )
    }

    private fun markTriggered(schedule: StoredSchedule, nowMs: Long) {
        val nowIso = formatIsoUtc(nowMs)
        schedule.json.put("updatedAt", nowIso)
        schedule.json.put("lastTriggeredAt", nowIso)
        if (schedule.type == "once") {
            schedule.json.put("enabled", false)
        }
        runCatching {
            schedule.file.writeText(schedule.json.toString())
        }.onFailure {
            Log.e(tag, "Failed to update schedule ${schedule.id}", it)
        }
    }

    private fun disableSchedule(schedule: StoredSchedule, nowMs: Long) {
        val nowIso = formatIsoUtc(nowMs)
        schedule.json.put("enabled", false)
        schedule.json.put("updatedAt", nowIso)
        runCatching {
            schedule.file.writeText(schedule.json.toString())
        }.onFailure {
            Log.e(tag, "Failed to disable schedule ${schedule.id}", it)
        }
    }

    private fun markScriptRun(context: Context, scriptId: String, nowMs: Long) {
        val scriptsDir = File(appFlutterDir(context), "scripts")
        val file = File(scriptsDir, "$scriptId.json")
        if (!file.exists()) {
            return
        }
        val nowIso = formatIsoUtc(nowMs)
        runCatching {
            val json = JSONObject(file.readText())
            json.put("lastRunAt", nowIso)
            json.put("updatedAt", nowIso)
            file.writeText(json.toString())
        }.onFailure {
            Log.e(tag, "Failed to update script run timestamp for $scriptId", it)
        }
    }

    private fun loadScriptPayload(context: Context, scriptId: String): Map<String, Any>? {
        val scriptsDir = File(appFlutterDir(context), "scripts")
        val file = File(scriptsDir, "$scriptId.json")
        if (!file.exists()) {
            return null
        }
        val json = JSONObject(file.readText())
        return jsonObjectToMap(json)
    }

    private fun jsonObjectToMap(json: JSONObject): Map<String, Any> {
        val map = linkedMapOf<String, Any>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.opt(key) ?: continue
            if (value == JSONObject.NULL) {
                continue
            }
            when (value) {
                is JSONObject -> map[key] = jsonObjectToMap(value)
                is JSONArray -> map[key] = jsonArrayToList(value)
                is Number, is Boolean, is String -> map[key] = value
                else -> map[key] = value.toString()
            }
        }
        return map
    }

    private fun jsonArrayToList(array: JSONArray): List<Any> {
        val list = mutableListOf<Any>()
        for (index in 0 until array.length()) {
            val value = array.opt(index) ?: continue
            if (value == JSONObject.NULL) {
                continue
            }
            when (value) {
                is JSONObject -> list.add(jsonObjectToMap(value))
                is JSONArray -> list.add(jsonArrayToList(value))
                is Number, is Boolean, is String -> list.add(value)
                else -> list.add(value.toString())
            }
        }
        return list
    }

    private fun formatIsoUtc(epochMs: Long): String {
        synchronized(isoUtcFormatter) {
            return isoUtcFormatter.format(epochMs)
        }
    }

    private fun parseIsoUtcToEpochMs(value: String?): Long? {
        val text = value?.trim().orEmpty()
        if (text.isEmpty()) {
            return null
        }
        val normalized = normalizeIsoFraction(text)
        val patterns = listOf(
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXX"
        )
        for (pattern in patterns) {
            val parser = SimpleDateFormat(pattern, Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
            val parsed = runCatching { parser.parse(normalized) }.getOrNull() ?: continue
            return parsed.time
        }
        return null
    }

    private fun normalizeIsoFraction(value: String): String {
        val matcher = Regex("""\.(\d{4,})(Z|[+-]\d\d:\d\d)$""").find(value) ?: return value
        val full = matcher.groupValues[0]
        val fraction = matcher.groupValues[1].take(3)
        val suffix = matcher.groupValues[2]
        return value.replace(full, ".$fraction$suffix")
    }

    private fun appFlutterDir(context: Context): File {
        val parent = context.filesDir.parentFile
        return File(parent, "app_flutter")
    }

    private fun ensureOverlayCallbacks(context: Context) {
        val runEngine = RunEngineManager.getInstance()
        OverlayController.getInstance(context).setRunCallbacks(
            onStart = { runEngine.resume() },
            onPause = { runEngine.pause() },
            onStop = { runEngine.stop() }
        )
    }
}

private data class StoredSchedule(
    val file: File,
    val json: JSONObject,
    val id: String,
    val scriptId: String,
    val type: String,
    val enabled: Boolean,
    val timeOfDay: String?,
    val weekdays: Set<Int>,
    val onceAtMs: Long?,
    val lastTriggeredAtMs: Long?,
    val updatedAtMs: Long?,
)

