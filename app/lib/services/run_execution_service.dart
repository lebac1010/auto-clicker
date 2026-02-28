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
  int _startRequestToken = 0;

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

    final requestToken = ++_startRequestToken;

    try {
      final currentRunState = await _runEngineGateway.getRunState();
      if (_isStartRequestSuperseded(requestToken)) {
        return _markStartRequestSuperseded();
      }
      if (_isRunStateActive(currentRunState)) {
        _lastFailureCode = 'RUN_ALREADY_ACTIVE';
        _lastFailureMessage = 'A run is already active.';
        return false;
      }

      _ensureRunListener();
      _cancelDurationTimer();

      if (options.startDelaySec > 0) {
        await Future<void>.delayed(Duration(seconds: options.startDelaySec));
        if (_isStartRequestSuperseded(requestToken)) {
          return _markStartRequestSuperseded();
        }
        final delayedRunState = await _runEngineGateway.getRunState();
        if (_isStartRequestSuperseded(requestToken)) {
          return _markStartRequestSuperseded();
        }
        if (_isRunStateActive(delayedRunState)) {
          _lastFailureCode = 'RUN_ALREADY_ACTIVE';
          _lastFailureMessage = 'A run became active before this start request.';
          return false;
        }
      }

      final preparedScript = _applyOptions(script, options);
      final preflight = await _runEngineGateway.validateRunConditions(
        preparedScript,
      );
      if (_isStartRequestSuperseded(requestToken)) {
        return _markStartRequestSuperseded();
      }
      if (!preflight.ok) {
        _lastFailureCode = preflight.code;
        _lastFailureMessage = preflight.message ?? 'Run conditions are not met.';
        return false;
      }
      final started = await _runEngineGateway.runScript(preparedScript);
      if (_isStartRequestSuperseded(requestToken)) {
        if (started) {
          unawaited(_runEngineGateway.stop());
        }
        return _markStartRequestSuperseded();
      }
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
    } finally {
      // No-op: request superseding is tracked by token only.
    }
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
    if (step.intervalMs <= 0) {
      // Keep non-positive override so native layer can fall back to default interval.
      return step;
    }
    return step.copyWith(
      intervalMs: _scaledInterval(step.intervalMs),
    );
  }

  int _scaledInterval(int intervalMs) {
    final scaled = (intervalMs * _fastModeIntervalScale).round();
    return scaled < _minIntervalMs ? _minIntervalMs : scaled;
  }

  bool _isRunStateActive(String state) {
    return state == 'running' || state == 'paused';
  }

  bool _isStartRequestSuperseded(int requestToken) {
    return requestToken != _startRequestToken;
  }

  bool _markStartRequestSuperseded() {
    _lastFailureCode = 'RUN_START_SUPERSEDED';
    _lastFailureMessage =
        'Start request was replaced by a newer start request.';
    return false;
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
