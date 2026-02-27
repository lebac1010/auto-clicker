package com.sarmatcz.tapmacro

import android.content.Context

object ExecutionStateSyncBridge {
    @Volatile
    private var installed = false

    fun install(context: Context) {
        if (installed) {
            return
        }
        synchronized(this) {
            if (installed) {
                return
            }
            val appContext = context.applicationContext
            val runEngineManager = RunEngineManager.getInstance()
            val recorderManager = RecorderManager.getInstance()
            runEngineManager.setStateListener { runState ->
                ExecutionForegroundCoordinator.sync(appContext, runState, recorderManager.getState())
            }
            recorderManager.setStateListener { recorderState ->
                ExecutionForegroundCoordinator.sync(appContext, runEngineManager.getState(), recorderState)
            }
            ExecutionForegroundCoordinator.sync(
                appContext,
                runEngineManager.getState(),
                recorderManager.getState()
            )
            installed = true
        }
    }
}

