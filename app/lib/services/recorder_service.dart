import 'dart:async';

import 'package:auto_clicker/models/recorded_step.dart';
import 'package:auto_clicker/models/recorder_state.dart';
import 'package:flutter/services.dart';

class RecorderService {
  RecorderService._();

  static const MethodChannel _channel = MethodChannel('com.auto_clicker/controller');
  static const EventChannel _eventsChannel = EventChannel('com.auto_clicker/recorder_events');
  static final Stream<Map<String, dynamic>> _eventStream = _eventsChannel
      .receiveBroadcastStream()
      .map(_mapEvent)
      .asBroadcastStream();

  static Stream<Map<String, dynamic>> events() {
    return _eventStream;
  }

  static Future<bool> start({int countdownSec = 3}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startRecorder',
        <String, dynamic>{'countdownSec': countdownSec},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<RecordedStep>> stop() async {
    try {
      final map = await _channel.invokeMapMethod<dynamic, dynamic>('stopRecorder');
      if (map == null) {
        return const <RecordedStep>[];
      }
      final rawSteps = map['steps'] as List<dynamic>? ?? <dynamic>[];
      return rawSteps
          .whereType<Map>()
          .map((e) => RecordedStep.fromMap(Map<dynamic, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const <RecordedStep>[];
    }
  }

  static Future<bool> clear() async {
    try {
      final result = await _channel.invokeMethod<bool>('clearRecorder');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<RecorderState> getState() async {
    try {
      final state = await _channel.invokeMethod<String>('getRecorderState');
      return RecorderState.fromValue(state ?? 'idle');
    } catch (_) {
      return RecorderState.idle;
    }
  }

  static Map<String, dynamic> _mapEvent(dynamic event) {
    final map = Map<dynamic, dynamic>.from(event as Map);
    return map.map((key, value) => MapEntry(key.toString(), value));
  }
}
