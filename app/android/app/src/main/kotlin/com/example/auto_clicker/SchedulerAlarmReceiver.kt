package com.sarmatcz.tapmacro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SchedulerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val pendingResult = goAsync()
        SchedulerManager.onAlarm(context.applicationContext) {
            pendingResult.finish()
        }
    }
}

