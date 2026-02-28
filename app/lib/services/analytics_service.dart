import 'dart:async';

import 'package:auto_clicker/services/support_log_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

typedef AnalyticsParams = Map<String, Object?>;

abstract class AnalyticsAdapter {
  Future<void> log({
    required String eventName,
    required AnalyticsParams payload,
  });
}

class DebugAnalyticsAdapter implements AnalyticsAdapter {
  @override
  Future<void> log({
    required String eventName,
    required AnalyticsParams payload,
  }) async {
    debugPrint('analytics=$eventName payload=$payload');
  }
}

class SupportLogAnalyticsAdapter implements AnalyticsAdapter {
  @override
  Future<void> log({
    required String eventName,
    required AnalyticsParams payload,
  }) async {
    SupportLogService.logInfo('analytics', eventName, data: payload);
  }
}

class AnalyticsService {
  AnalyticsService._();

  static const MethodChannel _appInfoChannel = MethodChannel(
    'com.auto_clicker/app_info',
  );
  static const String _firstLaunchPrefKey = 'analytics_first_launch_done';
  static const Set<String> _alwaysAllowedKeys = <String>{'screen_name'};
  static const Map<String, Set<String>> _allowedByEvent = <String, Set<String>>{
    'app_opened': <String>{'launch_type'},
    'onboarding_completed': <String>{'slides_count'},
    'permission_accessibility_enabled': <String>{'from_screen'},
    'permission_overlay_enabled': <String>{'from_screen'},
    'script_created': <String>{'script_id', 'script_type', 'steps_count'},
    'script_run_started': <String>{
      'script_id',
      'script_type',
      'steps_count',
      'loop_mode',
      'source',
    },
    'home_mode_selected': <String>{'mode'},
    'script_run_stopped': <String>{'script_id', 'stop_reason', 'elapsed_ms'},
    'recorder_started': <String>{'countdown_sec'},
    'recorder_saved': <String>{'script_id', 'steps_count', 'duration_ms'},
    'export_success': <String>{'script_id', 'export_type'},
    'import_success': <String>{'import_type', 'scripts_count'},
    'error_event': <String>{'error_code', 'message'},
  };
  static const Map<String, Map<String, Set<String>>> _enumValueRules =
      <String, Map<String, Set<String>>>{
        'app_opened': <String, Set<String>>{
          'launch_type': <String>{'cold', 'warm'},
        },
        'script_run_started': <String, Set<String>>{
          'loop_mode': <String>{'infinite', 'count', 'duration'},
          'source': <String>{
            'home',
            'editor',
            'controller',
            'script_list',
            'normal',
          },
        },
        'home_mode_selected': <String, Set<String>>{
          'mode': <String>{'normal', 'advanced'},
        },
        'script_run_stopped': <String, Set<String>>{
          'stop_reason': <String>{
            'user',
            'loop_completed',
            'error',
            'permission_lost',
            'service_killed',
            'condition_unmet',
          },
        },
        'export_success': <String, Set<String>>{
          'export_type': <String>{'single', 'all'},
        },
        'import_success': <String, Set<String>>{
          'import_type': <String>{'single', 'all'},
        },
      };

  static final Uuid _uuid = const Uuid();
  static final List<AnalyticsAdapter> _adapters = <AnalyticsAdapter>[];

  static bool _initialized = false;
  static Future<void>? _initializeFuture;
  static String _sessionId = '';
  static bool _isFirstLaunch = false;
  static String _appVersion = 'unknown';
  static String _buildNumber = 'unknown';
  static String _deviceModel = 'unknown';
  static String _androidVersion = 'unknown';

  static Future<void> initialize({List<AnalyticsAdapter>? adapters}) {
    if (_initialized) {
      return Future<void>.value();
    }
    _initializeFuture ??= _initialize(adapters: adapters);
    return _initializeFuture!;
  }

  static void logEvent(
    String eventName, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) {
    unawaited(_logEventAsync(eventName, parameters));
  }

  static void logErrorEvent({
    required String code,
    required String message,
    required String screenName,
  }) {
    unawaited(
      _logEventAsync('error_event', <String, Object?>{
        'error_code': code,
        'message': message,
        'screen_name': screenName,
      }),
    );
  }

  static Future<void> _initialize({List<AnalyticsAdapter>? adapters}) async {
    _adapters
      ..clear()
      ..addAll(
        adapters ??
            <AnalyticsAdapter>[
              DebugAnalyticsAdapter(),
              SupportLogAnalyticsAdapter(),
            ],
      );
    _sessionId = 'sess_${_uuid.v4().replaceAll('-', '').substring(0, 16)}';
    await _loadFirstLaunchState();
    await _loadAppInfo();
    _initialized = true;
  }

  static Future<void> _loadFirstLaunchState() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyLaunched = prefs.getBool(_firstLaunchPrefKey) ?? false;
    _isFirstLaunch = !alreadyLaunched;
    if (!alreadyLaunched) {
      await prefs.setBool(_firstLaunchPrefKey, true);
    }
  }

  static Future<void> _loadAppInfo() async {
    try {
      final info = await _appInfoChannel.invokeMapMethod<String, dynamic>(
        'getAppInfo',
      );
      if (info == null) {
        return;
      }
      _appVersion = (info['appVersion'] as String?)?.trim().isNotEmpty == true
          ? info['appVersion'] as String
          : _appVersion;
      _buildNumber = (info['buildNumber'] as String?)?.trim().isNotEmpty == true
          ? info['buildNumber'] as String
          : _buildNumber;
      _deviceModel = (info['deviceModel'] as String?)?.trim().isNotEmpty == true
          ? info['deviceModel'] as String
          : _deviceModel;
      _androidVersion =
          (info['androidVersion'] as String?)?.trim().isNotEmpty == true
          ? info['androidVersion'] as String
          : _androidVersion;
    } catch (error, stackTrace) {
      SupportLogService.logError(
        'analytics',
        'Unable to load app info from native channel',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _logEventAsync(
    String eventName,
    Map<String, Object?> parameters,
  ) async {
    await initialize();
    final sanitized = _sanitizeEvent(eventName, parameters);
    for (final adapter in _adapters) {
      try {
        await adapter.log(eventName: eventName, payload: sanitized);
      } catch (error, stackTrace) {
        SupportLogService.logError(
          'analytics',
          'Analytics adapter failed',
          error: error,
          stackTrace: stackTrace,
          data: <String, Object?>{'event_name': eventName},
        );
      }
    }
  }

  static AnalyticsParams _sanitizeEvent(
    String eventName,
    Map<String, Object?> parameters,
  ) {
    final normalized = <String, Object?>{};
    for (final entry in parameters.entries) {
      final key = _toSnakeCase(entry.key);
      if (key.isEmpty) {
        continue;
      }
      normalized[key] = entry.value;
    }

    final allowed = <String>{
      ..._alwaysAllowedKeys,
      ...?_allowedByEvent[eventName],
    };
    final filtered = <String, Object?>{};
    for (final entry in normalized.entries) {
      if (entry.value == null) {
        continue;
      }
      if (!allowed.contains(entry.key)) {
        continue;
      }
      if (!_isValueAllowed(eventName, entry.key, entry.value)) {
        continue;
      }
      filtered[entry.key] = entry.value;
    }

    final screenName = (filtered['screen_name'] as String?)?.trim();

    return <String, Object?>{
      'event_name': eventName,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'session_id': _sessionId,
      'app_version': _appVersion,
      'build_number': _buildNumber,
      'device_model': _deviceModel,
      'android_version': _androidVersion,
      'is_first_launch': _isFirstLaunch,
      'screen_name': (screenName == null || screenName.isEmpty)
          ? 'unknown'
          : screenName,
      ...filtered,
    };
  }

  static String _toSnakeCase(String input) {
    final separated = input.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    );
    final normalized = separated
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase()
        .trim();
    return normalized.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static bool _isValueAllowed(String eventName, String key, Object? value) {
    final rulesByKey = _enumValueRules[eventName];
    final allowedValues = rulesByKey?[key];
    if (allowedValues == null) {
      return true;
    }
    final valueString = value?.toString().trim().toLowerCase();
    return valueString != null && allowedValues.contains(valueString);
  }

  @visibleForTesting
  static AnalyticsParams buildPayloadForTest(
    String eventName, {
    Map<String, Object?> parameters = const <String, Object?>{},
    String sessionId = 'sess_test',
    bool isFirstLaunch = false,
    String appVersion = 'test_app',
    String buildNumber = 'test_build',
    String deviceModel = 'test_device',
    String androidVersion = 'test_android',
  }) {
    final prevSession = _sessionId;
    final prevFirstLaunch = _isFirstLaunch;
    final prevAppVersion = _appVersion;
    final prevBuildNumber = _buildNumber;
    final prevDeviceModel = _deviceModel;
    final prevAndroidVersion = _androidVersion;

    _sessionId = sessionId;
    _isFirstLaunch = isFirstLaunch;
    _appVersion = appVersion;
    _buildNumber = buildNumber;
    _deviceModel = deviceModel;
    _androidVersion = androidVersion;

    final payload = _sanitizeEvent(eventName, parameters);

    _sessionId = prevSession;
    _isFirstLaunch = prevFirstLaunch;
    _appVersion = prevAppVersion;
    _buildNumber = prevBuildNumber;
    _deviceModel = prevDeviceModel;
    _androidVersion = prevAndroidVersion;

    return payload;
  }
}
