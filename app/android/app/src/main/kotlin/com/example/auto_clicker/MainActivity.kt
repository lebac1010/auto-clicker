package com.sarmatcz.tapmacro

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.pm.PackageManager
import android.view.accessibility.AccessibilityManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.accessibilityservice.AccessibilityServiceInfo
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permissionChannelName = "com.auto_clicker/permissions"
    private val controllerChannelName = "com.auto_clicker/controller"
    private val settingsChannelName = "com.auto_clicker/settings"
    private val appInfoChannelName = "com.auto_clicker/app_info"
    private val runEventsChannelName = "com.auto_clicker/run_events"
    private val recorderEventsChannelName = "com.auto_clicker/recorder_events"
    private val overlayEventsChannelName = "com.auto_clicker/overlay_events"
    private val requestCodeNotifications = 12001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val overlayController = OverlayController.getInstance(applicationContext)
        val runEngineManager = RunEngineManager.getInstance()
        val recorderManager = RecorderManager.getInstance()

        overlayController.setRunCallbacks(
            onStart = { runEngineManager.resume() },
            onPause = { runEngineManager.pause() },
            onStop = { runEngineManager.stop() }
        )
        ExecutionStateSyncBridge.install(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPermissionState" -> result.success(getPermissionState())
                    "requestAccessibility" -> {
                        openAccessibilitySettings()
                        result.success(null)
                    }
                    "requestOverlay" -> {
                        openOverlaySettings()
                        result.success(null)
                    }
                    "requestNotification" -> {
                        openNotificationSettings()
                        result.success(null)
                    }
                    "requestBatteryOptimizationIgnore" -> {
                        openBatteryOptimizationSettings()
                        result.success(null)
                    }
                    "requestExactAlarm" -> {
                        openExactAlarmSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, controllerChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startFloatingController" -> result.success(overlayController.start())
                    "stopFloatingController" -> {
                        runEngineManager.stop()
                        overlayController.stop()
                        result.success(true)
                    }
                    "isFloatingControllerRunning" -> result.success(overlayController.isRunning())
                    "updateRunMarkers" -> {
                        val payload = call.argument<Map<*, *>>("script")
                        if (payload == null) {
                            result.success(false)
                        } else {
                            overlayController.updateRunMarkersFromScript(payload)
                            result.success(true)
                        }
                    }
                    "runScript" -> {
                        val payload = call.argument<Map<*, *>>("script")
                        if (payload == null) {
                            result.success(false)
                        } else {
                            overlayController.updateRunMarkersFromScript(payload)
                            result.success(runEngineManager.runScript(payload))
                        }
                    }
                    "validateRunConditions" -> {
                        val payload = call.argument<Map<*, *>>("script")
                        if (payload == null) {
                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "code" to "SCRIPT_INVALID",
                                    "message" to "Invalid script payload."
                                )
                            )
                        } else {
                            result.success(runEngineManager.validateRunConditions(payload))
                        }
                    }
                    "pauseScript" -> result.success(runEngineManager.pause())
                    "resumeScript" -> result.success(runEngineManager.resume())
                    "stopScript" -> result.success(runEngineManager.stop())
                    "getRunState" -> result.success(runEngineManager.getState())
                    "startRecorder" -> {
                        val countdownSec = call.argument<Int>("countdownSec") ?: 3
                        result.success(recorderManager.start(countdownSec))
                    }
                    "stopRecorder" -> result.success(recorderManager.stop())
                    "clearRecorder" -> result.success(recorderManager.clear())
                    "getRecorderState" -> result.success(recorderManager.getState())
                    "startPointPicker" -> result.success(overlayController.startPointPicker())
                    "startMarkerEditor" -> {
                        val points = call.argument<List<Map<*, *>>>("points") ?: emptyList()
                        result.success(overlayController.startMarkerEditor(points))
                    }
                    "stopMarkerEditor" -> result.success(overlayController.stopMarkerEditor())
                    "startScheduler" -> result.success(SchedulerManager.start(applicationContext))
                    "rescheduleScheduler" -> result.success(SchedulerManager.reschedule(applicationContext))
                    "stopScheduler" -> result.success(SchedulerManager.stop(applicationContext))
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, settingsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSettingsState" -> result.success(getSettingsState())
                    "setVolumeKeyStopEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        AppSettingsStore.setVolumeKeyStopEnabled(applicationContext, enabled)
                        result.success(getSettingsState())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appInfoChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppInfo" -> result.success(getAppInfo())
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, runEventsChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        RunEngineManager.getInstance().setEventSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        RunEngineManager.getInstance().setEventSink(null)
                    }
                }
            )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, recorderEventsChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        RecorderManager.getInstance().setEventSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        RecorderManager.getInstance().setEventSink(null)
                    }
                }
            )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, overlayEventsChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        overlayController.setEventSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        overlayController.setEventSink(null)
                    }
                }
            )
    }

    private fun getPermissionState(): Map<String, Boolean> {
        return mapOf(
            "accessibilityEnabled" to isAccessibilityEnabled(),
            "overlayEnabled" to Settings.canDrawOverlays(this),
            "notificationsEnabled" to isNotificationsEnabled(),
            "batteryOptimizationIgnored" to isIgnoringBatteryOptimization(),
            "exactAlarmAllowed" to isExactAlarmAllowed()
        )
    }

    private fun getSettingsState(): Map<String, Boolean> {
        return mapOf(
            "volumeKeyStopEnabled" to AppSettingsStore.isVolumeKeyStopEnabled(applicationContext)
        )
    }

    private fun getAppInfo(): Map<String, String> {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            mapOf(
                "appVersion" to (packageInfo.versionName ?: "unknown"),
                "buildNumber" to packageInfo.longVersionCode.toString(),
                "deviceModel" to (Build.MODEL ?: "unknown"),
                "androidVersion" to (Build.VERSION.RELEASE ?: "unknown")
            )
        } catch (_: Exception) {
            mapOf(
                "appVersion" to "unknown",
                "buildNumber" to "unknown",
                "deviceModel" to (Build.MODEL ?: "unknown"),
                "androidVersion" to (Build.VERSION.RELEASE ?: "unknown")
            )
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val manager = getSystemService(ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = manager.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK
        )
        return enabledServices.any { it.resolveInfo.serviceInfo.packageName == packageName }
    }

    private fun isNotificationsEnabled(): Boolean {
        val areEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return areEnabled
        }
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        return areEnabled && granted
    }

    private fun isIgnoringBatteryOptimization(): Boolean {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun isExactAlarmAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun openAccessibilitySettings() {
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        startActivity(intent)
    }

    private fun openNotificationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    requestCodeNotifications
                )
                return
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            startActivity(intent)
            return
        }
        startActivity(Intent(Settings.ACTION_SETTINGS))
    }

    private fun openBatteryOptimizationSettings() {
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        startActivity(intent)
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return
        }
        val intent = Intent(
            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
            Uri.parse("package:$packageName")
        )
        try {
            startActivity(intent)
        } catch (_: Exception) {
            val fallback = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            )
            startActivity(fallback)
        }
    }
}

