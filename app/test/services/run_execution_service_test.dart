import 'dart:async';

import 'package:auto_clicker/models/run_options.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:auto_clicker/services/run_engine_service.dart';
import 'package:auto_clicker/services/run_execution_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRunEngineGateway extends RunEngineGateway {
  _FakeRunEngineGateway();

  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  RunConditionValidationResult validationResult =
      const RunConditionValidationResult(ok: true);
  bool runScriptResult = true;
  ScriptModel? lastRunScript;
  int validateCalls = 0;
  int runCalls = 0;

  @override
  Stream<Map<String, dynamic>> events() => _eventsController.stream;

  @override
  Future<String> getRunState() async => 'idle';

  @override
  Future<bool> pause() async => true;

  @override
  Future<bool> resume() async => true;

  @override
  Future<bool> runScript(ScriptModel script) async {
    runCalls += 1;
    lastRunScript = script;
    return runScriptResult;
  }

  @override
  Future<bool> stop() async => true;

  @override
  Future<RunConditionValidationResult> validateRunConditions(
    ScriptModel script,
  ) async {
    validateCalls += 1;
    return validationResult;
  }

  Future<void> dispose() async {
    await _eventsController.close();
  }
}

void main() {
  ScriptModel makeScript() {
    final now = DateTime(2026, 2, 24, 9, 0, 0);
    return ScriptModel(
      id: 'scr_run_exec',
      name: 'Run Exec Test',
      type: ScriptType.multiTap,
      createdAt: now,
      updatedAt: now,
      defaultIntervalMs: 100,
      loopCount: 5,
      steps: const <ScriptStep>[
        ScriptStep(
          id: 'step_1',
          x: 0.2,
          y: 0.3,
          intervalMs: 50,
          enabled: true,
        ),
      ],
    );
  }

  late _FakeRunEngineGateway gateway;
  late RunExecutionService service;

  setUp(() {
    gateway = _FakeRunEngineGateway();
    service = RunExecutionService(runEngineGateway: gateway);
  });

  tearDown(() async {
    await service.dispose();
    await gateway.dispose();
  });

  test('returns false and exposes condition failure from preflight', () async {
    gateway.validationResult = const RunConditionValidationResult(
      ok: false,
      code: 'CONDITION_MIN_BATTERY',
      message: 'Cannot run: battery 10% is below required 30%.',
    );

    final started = await service.runWithOptions(makeScript(), RunOptions.defaults);

    expect(started, isFalse);
    expect(service.lastFailureCode, 'CONDITION_MIN_BATTERY');
    expect(
      service.lastFailureMessage,
      'Cannot run: battery 10% is below required 30%.',
    );
    expect(gateway.runCalls, 0);
  });

  test('applies loop stop rule and fast performance scaling before run', () async {
    gateway.validationResult = const RunConditionValidationResult(ok: true);
    gateway.runScriptResult = true;

    final started = await service.runWithOptions(
      makeScript(),
      const RunOptions(
        stopRule: RunStopRule.loops,
        stopAfterLoops: 2,
        performanceMode: RunPerformanceMode.fast,
      ),
    );

    expect(started, isTrue);
    final prepared = gateway.lastRunScript;
    expect(prepared, isNotNull);
    expect(prepared!.loopCount, 2);
    expect(prepared.defaultIntervalMs, 70);
    expect(prepared.steps.single.intervalMs, 35);
    expect(service.lastFailureCode, isNull);
    expect(service.lastFailureMessage, isNull);
  });

  test('throws FormatException for invalid run options before preflight', () async {
    final invalidOptions = const RunOptions(
      stopRule: RunStopRule.loops,
      stopAfterLoops: 0,
    );

    await expectLater(
      () => service.runWithOptions(makeScript(), invalidOptions),
      throwsA(isA<FormatException>()),
    );
    expect(gateway.validateCalls, 0);
    expect(gateway.runCalls, 0);
  });

  test('returns generic failure message when run engine start fails', () async {
    gateway.validationResult = const RunConditionValidationResult(ok: true);
    gateway.runScriptResult = false;

    final started = await service.runWithOptions(makeScript(), RunOptions.defaults);

    expect(started, isFalse);
    expect(service.lastFailureCode, 'RUN_START_FAILED');
    expect(service.lastFailureMessage, 'Unable to start run engine.');
  });
}
