package com.sarmatcz.tapmacro

import android.content.Context

object AppSettingsStore {
    private const val prefsName = "auto_clicker_settings"
    private const val keyVolumeKeyStopEnabled = "volume_key_stop_enabled"

    fun isVolumeKeyStopEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        return prefs.getBoolean(keyVolumeKeyStopEnabled, false)
    }

    fun setVolumeKeyStopEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(keyVolumeKeyStopEnabled, enabled).apply()
    }
}

