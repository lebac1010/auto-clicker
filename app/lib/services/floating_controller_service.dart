import 'dart:async';

import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:flutter/services.dart';

class FloatingControllerService {
  FloatingControllerService._();

  static const MethodChannel _channel = MethodChannel('com.auto_clicker/controller');
  static const EventChannel _eventsChannel = EventChannel('com.auto_clicker/overlay_events');
  static final Stream<Map<String, dynamic>> _eventStream = _eventsChannel
      .receiveBroadcastStream()
      .map(_mapEvent)
      .asBroadcastStream();

  static Future<bool> start() async {
    try {
      final result = await _channel.invokeMethod<bool>('startFloatingController');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateRunMarkers(ScriptModel script) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'updateRunMarkers',
        <String, dynamic>{'script': script.toJson()},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopFloatingController');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isFloatingControllerRunning');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Stream<Map<String, dynamic>> events() {
    return _eventStream;
  }

  static Future<bool> startPointPicker() async {
    try {
      final result = await _channel.invokeMethod<bool>('startPointPicker');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startMarkerEditor(List<ScriptStep> steps) async {
    try {
      final points = steps
          .map(
            (step) => <String, dynamic>{
              'id': step.id,
              'x': step.x,
              'y': step.y,
            },
          )
          .toList();
      final result = await _channel.invokeMethod<bool>(
        'startMarkerEditor',
        <String, dynamic>{'points': points},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopMarkerEditor() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopMarkerEditor');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _mapEvent(dynamic event) {
    final map = Map<dynamic, dynamic>.from(event as Map);
    return map.map((key, value) => MapEntry(key.toString(), value));
  }
}
