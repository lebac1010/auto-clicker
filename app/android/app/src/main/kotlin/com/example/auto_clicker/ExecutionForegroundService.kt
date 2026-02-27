package com.sarmatcz.tapmacro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class ExecutionForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: actionStartOrUpdate
        if (action == actionStop) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(extraTitle) ?: defaultTitle
        val text = intent?.getStringExtra(extraText) ?: defaultText
        startForeground(notificationId, buildNotification(title, text))
        return START_STICKY
    }

    private fun buildNotification(title: String, text: String): Notification {
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(channelId)
        if (existing != null) {
            return
        }
        val channel = NotificationChannel(
            channelId,
            "Execution",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows active TapMacro execution state."
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val channelId = "auto_clicker_execution"
        private const val notificationId = 1001
        private const val actionStartOrUpdate = "com.auto_clicker.execution.START_OR_UPDATE"
        private const val actionStop = "com.auto_clicker.execution.STOP"
        private const val extraTitle = "extra_title"
        private const val extraText = "extra_text"
        private const val defaultTitle = "TapMacro"
        private const val defaultText = "Execution is active."

        fun startOrUpdate(context: Context, title: String, text: String) {
            val intent = Intent(context, ExecutionForegroundService::class.java).apply {
                action = actionStartOrUpdate
                putExtra(extraTitle, title)
                putExtra(extraText, text)
            }
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (_: SecurityException) {
                // Ignore runtime notification denial errors to avoid crashing control flow.
            } catch (_: IllegalStateException) {
                // Ignore background-start restrictions when app is not foreground.
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, ExecutionForegroundService::class.java).apply {
                action = actionStop
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {
                // Ignore stop failures when service is not running.
            }
        }
    }
}

