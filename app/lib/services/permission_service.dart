import 'package:auto_clicker/models/permission_state.dart';
import 'package:flutter/services.dart';

class PermissionService {
  PermissionService._();

  static const MethodChannel _channel = MethodChannel(
    'com.auto_clicker/permissions',
  );

  static Future<PermissionState> getPermissionState() async {
    try {
      final Map<dynamic, dynamic>? data =
          await _channel.invokeMapMethod<dynamic, dynamic>('getPermissionState');
      if (data == null) {
        return PermissionState.fallback;
      }
      return PermissionState.fromMap(data);
    } catch (_) {
      return PermissionState.fallback;
    }
  }

  static Future<void> requestAccessibility() async {
    await _invoke('requestAccessibility');
  }

  static Future<void> requestOverlay() async {
    await _invoke('requestOverlay');
  }

  static Future<void> requestNotifications() async {
    await _invoke('requestNotification');
  }

  static Future<void> requestBatteryOptimizationIgnore() async {
    await _invoke('requestBatteryOptimizationIgnore');
  }

  static Future<void> requestExactAlarm() async {
    await _invoke('requestExactAlarm');
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Ignore method failures to avoid breaking permissions flow.
    }
  }
}
