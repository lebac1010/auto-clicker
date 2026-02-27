import 'package:flutter/services.dart';

class SettingsService {
  SettingsService._();

  static const MethodChannel _channel = MethodChannel('com.auto_clicker/settings');

  static Future<bool> getVolumeKeyStopEnabled() async {
    try {
      final state = await _channel.invokeMapMethod<dynamic, dynamic>('getSettingsState');
      final enabled = state?['volumeKeyStopEnabled'];
      return enabled == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setVolumeKeyStopEnabled(bool enabled) async {
    try {
      final state = await _channel.invokeMapMethod<dynamic, dynamic>(
        'setVolumeKeyStopEnabled',
        <String, dynamic>{'enabled': enabled},
      );
      return state?['volumeKeyStopEnabled'] == true;
    } catch (_) {
      return false;
    }
  }
}
