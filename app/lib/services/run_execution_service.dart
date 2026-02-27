import 'dart:async';

import 'package:auto_clicker/models/run_options.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/services/run_engine_service.dart';

class RunExecutionService {
  RunExecutionService({
    RunEngineGateway? runEngineGateway,
  }) : _runEngineGateway = runEngineGateway ?? const RunEngineServiceGateway();

  static final RunExecutionService instance = RunExecutionService();

  static const int _minIntervalMs = 1;
  static const double _fastModeIntervalScale = 0.7;

  final RunEngineGateway _runEngineGateway;
  StreamSubscription<Map<String, dynamic>>? _runSubscription;
  Timer? _durationStopTimer;
  String? _lastFailureMessage;
  String? _lastFailureCode;

  String? get lastFailureMessage => _lastFailureMessage;
  String? get lastFailureCode => _lastFailureCode;

  Future<void> dispose() async {
    _cancelDurationTimer();
    await _runSubscription?.cancel();
    _runSubscription = null;
  }

  Future<bool> runWithOptions(
    ScriptModel script,
    RunOptions options,
  ) async {
    _lastFailureMessage = null;
    _lastFailureCode = null;
    final validationErrors = options.validate();
    if (validationErrors.isNotEmpty) {
      throw FormatException(validationErrors.first);
    }

    _ensureRunListener();
    _cancelDurationTimer();

    if (options.startDelaySec > 0) {
      await Future<void>.delayed(Duration(seconds: options.startDelaySec));
    }

    final preparedScript = _applyOptions(script, options);
    final preflight = await _runEngineGateway.validateRunConditions(
      preparedScript,
    );
    if (!preflight.ok) {
      _lastFailureCode = preflight.code;
      _lastFailureMessage = preflight.message ?? 'Run conditions are not met.';
      return false;
    }
    final started = await _runEngineGateway.runScript(preparedScript);
    if (!started) {
      _lastFailureCode ??= 'RUN_START_FAILED';
      _lastFailureMessage ??= 'Unable to start run engine.';
      return false;
    }

    if (options.stopRule == RunStopRule.duration) {
      final durationSec = options.stopAfterDurationSec!;
      _durationStopTimer = Timer(Duration(seconds: durationSec), () {
        unawaited(_runEngineGateway.stop());
      });
    }
    return true;
  }

  ScriptModel _applyOptions(ScriptModel source, RunOptions options) {
    var target = source;

    if (options.performanceMode == RunPerformanceMode.fast) {
      target = target.copyWith(
        defaultIntervalMs: _scaledInterval(target.defaultIntervalMs),
        steps: target.steps.map(_scaledStepForFastMode).toList(),
      );
    }

    if (options.stopRule == RunStopRule.loops) {
      target = target.copyWith(loopCount: options.stopAfterLoops!);
    }

    return target;
  }

  ScriptStep _scaledStepForFastMode(ScriptStep step) {
    return step.copyWith(
      intervalMs: _scaledInterval(step.intervalMs),
    );
  }

  int _scaledInterval(int intervalMs) {
    final scaled = (intervalMs * _fastModeIntervalScale).round();
    return scaled < _minIntervalMs ? _minIntervalMs : scaled;
  }

  void _ensureRunListener() {
    _runSubscription ??= _runEngineGateway.events().listen((event) {
      final type = event['type']?.toString();
      if (type == 'runStopped') {
        _cancelDurationTimer();
        return;
      }
      if (type == 'state' && event['state']?.toString() == 'idle') {
        _cancelDurationTimer();
      }
    });
  }

  void _cancelDurationTimer() {
    _durationStopTimer?.cancel();
    _durationStopTimer = null;
  }
}
