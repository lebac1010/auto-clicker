package com.sarmatcz.tapmacro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SchedulerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action.orEmpty()
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            SchedulerManager.reschedule(context.applicationContext)
        }
    }
}

