import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/run_telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsService payload schema', () {
    test('includes common fields and keeps allowed params', () {
      final payload = AnalyticsService.buildPayloadForTest(
        'script_run_started',
        parameters: const <String, Object?>{
          'scriptId': 'scr_1',
          'scriptType': 'multiTap',
          'stepsCount': 3,
          'loopMode': 'count',
          'source': 'home',
          'screenName': 'home',
          'unexpectedKey': 'ignored',
        },
      );

      expect(payload['event_name'], 'script_run_started');
      expect(payload['session_id'], 'sess_test');
      expect(payload['app_version'], 'test_app');
      expect(payload['build_number'], 'test_build');
      expect(payload['device_model'], 'test_device');
      expect(payload['android_version'], 'test_android');
      expect(payload['is_first_launch'], false);
      expect(payload['script_id'], 'scr_1');
      expect(payload['script_type'], 'multiTap');
      expect(payload['steps_count'], 3);
      expect(payload['loop_mode'], 'count');
      expect(payload['source'], 'home');
      expect(payload['screen_name'], 'home');
      expect(payload.containsKey('unexpectedKey'), isFalse);
      expect(payload.containsKey('unexpected_key'), isFalse);
      expect(payload.containsKey('timestamp'), isTrue);
    });

    test('drops enum values outside schema', () {
      final payload = AnalyticsService.buildPayloadForTest(
        'script_run_started',
        parameters: const <String, Object?>{
          'loop_mode': 'forever',
          'source': 'invalid_source',
          'screen_name': 'home',
        },
      );

      expect(payload.containsKey('loop_mode'), isFalse);
      expect(payload.containsKey('source'), isFalse);
      expect(payload['screen_name'], 'home');
    });

    test('accepts script_list source for script_run_started', () {
      final payload = AnalyticsService.buildPayloadForTest(
        'script_run_started',
        parameters: const <String, Object?>{
          'loop_mode': 'count',
          'source': 'script_list',
          'screen_name': 'script_list',
        },
      );

      expect(payload['source'], 'script_list');
    });

    test('accepts normal source for script_run_started', () {
      final payload = AnalyticsService.buildPayloadForTest(
        'script_run_started',
        parameters: const <String, Object?>{
          'loop_mode': 'count',
          'source': 'normal',
          'screen_name': 'normal_home',
        },
      );

      expect(payload['source'], 'normal');
    });

    test('home_mode_selected keeps only valid mode enum', () {
      final validPayload = AnalyticsService.buildPayloadForTest(
        'home_mode_selected',
        parameters: const <String, Object?>{
          'mode': 'advanced',
          'screen_name': 'home_shell',
        },
      );
      expect(validPayload['mode'], 'advanced');

      final invalidPayload = AnalyticsService.buildPayloadForTest(
        'home_mode_selected',
        parameters: const <String, Object?>{
          'mode': 'expert',
          'screen_name': 'home_shell',
        },
      );
      expect(invalidPayload.containsKey('mode'), isFalse);
    });
  });

  group('RunTelemetryService reason normalization', () {
    test('maps unsupported reason to error', () {
      expect(RunTelemetryService.normalizeStopReason('unknown'), 'error');
      expect(RunTelemetryService.normalizeStopReason(null), 'error');
    });

    test('passes supported stop reasons', () {
      expect(RunTelemetryService.normalizeStopReason('user'), 'user');
      expect(RunTelemetryService.normalizeStopReason('error'), 'error');
      expect(
        RunTelemetryService.normalizeStopReason('permission_lost'),
        'permission_lost',
      );
      expect(
        RunTelemetryService.normalizeStopReason('service_killed'),
        'service_killed',
      );
      expect(
        RunTelemetryService.normalizeStopReason('condition_unmet'),
        'condition_unmet',
      );
    });
  });
}
