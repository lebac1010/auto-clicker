import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:auto_clicker/services/script_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScriptModel makeScript({
    required int loopCount,
    List<ScriptStep> steps = const <ScriptStep>[
      ScriptStep(id: 'step_1', x: 0.4, y: 0.4, intervalMs: 100, enabled: true),
    ],
  }) {
    final now = DateTime(2026, 2, 11, 10, 0, 0);
    return ScriptModel(
      id: 'scr_validator',
      name: 'Validator Script',
      type: ScriptType.multiTap,
      createdAt: now,
      updatedAt: now,
      defaultIntervalMs: 300,
      loopCount: loopCount,
      steps: steps,
    );
  }

  test('accepts infinite loop mode encoded as loopCount = 0', () {
    final errors = ScriptValidator.validate(makeScript(loopCount: 0));
    expect(errors, isEmpty);
  });

  test('rejects negative loopCount', () {
    final errors = ScriptValidator.validate(makeScript(loopCount: -1));
    expect(errors, isNotEmpty);
  });

  test('rejects negative hold duration', () {
    final errors = ScriptValidator.validate(
      makeScript(
        loopCount: 1,
        steps: const <ScriptStep>[
          ScriptStep(
            id: 'step_1',
            x: 0.4,
            y: 0.4,
            intervalMs: 100,
            holdMs: -5,
            enabled: true,
          ),
        ],
      ),
    );
    expect(errors, isNotEmpty);
  });

  test('rejects unsupported step action', () {
    final errors = ScriptValidator.validate(
      makeScript(
        loopCount: 1,
        steps: const <ScriptStep>[
          ScriptStep(
            id: 'step_1',
            action: 'pinch',
            x: 0.4,
            y: 0.4,
            intervalMs: 100,
            holdMs: 40,
            enabled: true,
          ),
        ],
      ),
    );
    expect(errors, isNotEmpty);
  });

  test('accepts swipe step with end coordinates and duration', () {
    final errors = ScriptValidator.validate(
      makeScript(
        loopCount: 1,
        steps: const <ScriptStep>[
          ScriptStep(
            id: 'step_1',
            action: 'swipe',
            x: 0.2,
            y: 0.2,
            x2: 0.8,
            y2: 0.8,
            intervalMs: 100,
            swipeDurationMs: 300,
            enabled: true,
          ),
        ],
      ),
    );
    expect(errors, isEmpty);
  });

  test('accepts multi-touch step with second point', () {
    final errors = ScriptValidator.validate(
      makeScript(
        loopCount: 1,
        steps: const <ScriptStep>[
          ScriptStep(
            id: 'step_1',
            action: 'multi_touch',
            x: 0.2,
            y: 0.2,
            x2: 0.7,
            y2: 0.7,
            intervalMs: 120,
            swipeDurationMs: 180,
            enabled: true,
          ),
        ],
      ),
    );
    expect(errors, isEmpty);
  });

  test('rejects incomplete time window', () {
    final script = makeScript(loopCount: 1).copyWith(timeWindowStart: '22:00');
    final errors = ScriptValidator.validate(script);
    expect(errors, isNotEmpty);
  });

  test('rejects invalid foreground app package', () {
    final script = makeScript(
      loopCount: 1,
    ).copyWith(requireForegroundApp: 'not a package');
    final errors = ScriptValidator.validate(script);
    expect(errors, isNotEmpty);
  });

  test('rejects minBatteryPct out of range', () {
    final script = makeScript(loopCount: 1).copyWith(minBatteryPct: 150);
    final errors = ScriptValidator.validate(script);
    expect(errors, isNotEmpty);
  });
}
