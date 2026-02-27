import 'dart:async';

import 'package:auto_clicker/models/script_model.dart';
import 'package:flutter/services.dart';

class RunConditionValidationResult {
  const RunConditionValidationResult({
    required this.ok,
    this.code,
    this.message,
  });

  final bool ok;
  final String? code;
  final String? message;
}

abstract class RunEngineGateway {
  const RunEngineGateway();

  Stream<Map<String, dynamic>> events();

  Future<bool> runScript(ScriptModel script);

  Future<RunConditionValidationResult> validateRunConditions(ScriptModel script);

  Future<bool> pause();

  Future<bool> resume();

  Future<bool> stop();

  Future<String> getRunState();
}

class RunEngineServiceGateway extends RunEngineGateway {
  const RunEngineServiceGateway();

  @override
  Stream<Map<String, dynamic>> events() => RunEngineService.events();

  @override
  Future<bool> runScript(ScriptModel script) => RunEngineService.runScript(script);

  @override
  Future<RunConditionValidationResult> validateRunConditions(
    ScriptModel script,
  ) => RunEngineService.validateRunConditions(script);

  @override
  Future<bool> pause() => RunEngineService.pause();

  @override
  Future<bool> resume() => RunEngineService.resume();

  @override
  Future<bool> stop() => RunEngineService.stop();

  @override
  Future<String> getRunState() => RunEngineService.getRunState();
}

class RunEngineService {
  RunEngineService._();

  static const MethodChannel _controllerChannel = MethodChannel(
    'com.auto_clicker/controller',
  );
  static const EventChannel _eventsChannel = EventChannel(
    'com.auto_clicker/run_events',
  );
  static final Stream<Map<String, dynamic>> _eventStream = _eventsChannel
      .receiveBroadcastStream()
      .map(_mapEvent)
      .asBroadcastStream();

  static Stream<Map<String, dynamic>> events() {
    return _eventStream;
  }

  static Future<bool> runScript(ScriptModel script) async {
    try {
      final result = await _controllerChannel.invokeMethod<bool>(
        'runScript',
        <String, dynamic>{'script': script.toJson()},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<RunConditionValidationResult> validateRunConditions(
    ScriptModel script,
  ) async {
    try {
      final response = await _controllerChannel.invokeMapMethod<String, dynamic>(
        'validateRunConditions',
        <String, dynamic>{'script': script.toJson()},
      );
      final ok = response?['ok'] == true;
      return RunConditionValidationResult(
        ok: ok,
        code: response?['code']?.toString(),
        message: response?['message']?.toString(),
      );
    } catch (_) {
      return const RunConditionValidationResult(
        ok: false,
        code: 'RUN_VALIDATION_FAILED',
        message: 'Unable to validate run conditions.',
      );
    }
  }

  static Future<bool> pause() async {
    try {
      final result = await _controllerChannel.invokeMethod<bool>('pauseScript');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> resume() async {
    try {
      final result = await _controllerChannel.invokeMethod<bool>('resumeScript');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      final result = await _controllerChannel.invokeMethod<bool>('stopScript');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> getRunState() async {
    try {
      final result = await _controllerChannel.invokeMethod<String>('getRunState');
      return result ?? 'idle';
    } catch (_) {
      return 'idle';
    }
  }

  static Map<String, dynamic> _mapEvent(dynamic event) {
    final map = Map<dynamic, dynamic>.from(event as Map);
    return map.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
}
