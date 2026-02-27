package com.sarmatcz.tapmacro

import android.content.Context

object ExecutionForegroundCoordinator {
    fun sync(context: Context, runState: String, recorderState: String) {
        val isRunActive = runState == "running" || runState == "paused"
        val isRecorderActive = recorderState == "countdown" || recorderState == "recording"
        if (!isRunActive && !isRecorderActive) {
            ExecutionForegroundService.stop(context)
            return
        }

        val title: String
        val text: String
        when {
            runState == "running" -> {
                title = "TapMacro running"
                text = "Tap automation is executing."
            }
            runState == "paused" -> {
                title = "TapMacro paused"
                text = "Tap automation is paused."
            }
            recorderState == "countdown" -> {
                title = "Recorder countdown"
                text = "Recording will start shortly."
            }
            else -> {
                title = "Recorder active"
                text = "Capturing tap events."
            }
        }
        ExecutionForegroundService.startOrUpdate(context, title, text)
    }
}

