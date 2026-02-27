import 'dart:async';

import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/run_engine_service.dart';

class RunTelemetryService {
  RunTelemetryService({
    RunEngineGateway? runEngineGateway,
  }) : _runEngineGateway = runEngineGateway ?? const RunEngineServiceGateway();

  static final RunTelemetryService instance = RunTelemetryService();
  final RunEngineGateway _runEngineGateway;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _started = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _subscription = _runEngineGateway.events().listen(_onRunEvent);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  void _onRunEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    if (type == 'runStopped') {
      _trackRunStopped(event);
      return;
    }
    if (type == 'error') {
      final code = event['code']?.toString() ?? 'RUN_ERROR';
      final message = _safeErrorMessage(code);
      AnalyticsService.logErrorEvent(
        code: code,
        message: message,
        screenName: 'floating_controller',
      );
    }
  }

  void _trackRunStopped(Map<String, dynamic> event) {
    final scriptId = event['scriptId']?.toString();
    if (scriptId == null || scriptId.isEmpty) {
      return;
    }
    final elapsedMs = (event['elapsedMs'] as num?)?.toInt() ?? 0;
    final stopReason = normalizeStopReason(event['stopReason']?.toString());
    AnalyticsService.logEvent(
      'script_run_stopped',
      parameters: <String, Object?>{
        'script_id': scriptId,
        'stop_reason': stopReason,
        'elapsed_ms': elapsedMs < 0 ? 0 : elapsedMs,
        'screen_name': 'floating_controller',
      },
    );
  }

  static String normalizeStopReason(String? raw) {
    switch (raw) {
      case 'user':
        return 'user';
      case 'error':
        return 'error';
      case 'permission_lost':
        return 'permission_lost';
      case 'service_killed':
        return 'service_killed';
      case 'condition_unmet':
        return 'condition_unmet';
      default:
        return 'error';
    }
  }

  static String _safeErrorMessage(String code) {
    switch (code) {
      case 'CONDITION_FOREGROUND_APP':
        return 'Foreground app condition is not met.';
      case 'CONDITION_MIN_BATTERY':
        return 'Battery condition is not met.';
      case 'CONDITION_REQUIRE_CHARGING':
        return 'Charging condition is not met.';
      case 'CONDITION_REQUIRE_SCREEN_ON':
        return 'Screen-on condition is not met.';
      case 'CONDITION_TIME_WINDOW':
        return 'Time-window condition is not met.';
      case 'PERMISSION_LOST':
        return 'Accessibility permission was lost.';
      case 'SERVICE_DOWN':
        return 'Accessibility service is not active.';
      case 'DISPATCH_FAILED':
        return 'Gesture dispatch failed.';
      default:
        return 'Run engine reported an error.';
    }
  }
}
