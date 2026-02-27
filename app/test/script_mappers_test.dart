import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:auto_clicker/services/script_internal_mapper.dart';
import 'package:auto_clicker/services/script_schema_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScriptModel makeScript() {
    final now = DateTime(2026, 2, 9);
    return ScriptModel(
      id: 'scr_1',
      name: 'Sample',
      type: ScriptType.multiTap,
      createdAt: now,
      updatedAt: now,
      defaultIntervalMs: 300,
      loopCount: 2,
      requireCharging: true,
      requireScreenOn: true,
      requireForegroundApp: 'com.example.target',
      minBatteryPct: 35,
      timeWindowStart: '22:00',
      timeWindowEnd: '06:00',
      steps: const [
        ScriptStep(
          id: 'step_1',
          action: 'swipe',
          x: 0.2,
          y: 0.3,
          x2: 0.8,
          y2: 0.7,
          intervalMs: 120,
          holdMs: 70,
          swipeDurationMs: 420,
          enabled: true,
        ),
      ],
    );
  }

  test('Schema mapper roundtrip', () {
    final script = makeScript();
    final map = ScriptSchemaMapper.toSchemaV1(script);
    final parsed = ScriptSchemaMapper.fromSchemaV1(map);
    expect(parsed.name, script.name);
    expect(parsed.steps.length, script.steps.length);
    expect(parsed.steps.first.x, closeTo(script.steps.first.x, 0.0001));
    expect(parsed.steps.first.action, 'swipe');
    expect(parsed.steps.first.x2, closeTo(script.steps.first.x2!, 0.0001));
    expect(parsed.steps.first.swipeDurationMs, script.steps.first.swipeDurationMs);
    expect(parsed.requireCharging, isTrue);
    expect(parsed.requireScreenOn, isTrue);
    expect(parsed.requireForegroundApp, 'com.example.target');
    expect(parsed.minBatteryPct, 35);
    expect(parsed.timeWindowStart, '22:00');
    expect(parsed.timeWindowEnd, '06:00');
  });

  test('Internal mapper roundtrip', () {
    final script = makeScript();
    final map = ScriptInternalMapper.toMap(script);
    final parsed = ScriptInternalMapper.fromMap(map);
    expect(parsed.name, script.name);
    expect(parsed.loopCount, script.loopCount);
    expect(parsed.steps.first.action, script.steps.first.action);
    expect(parsed.steps.first.intervalMs, script.steps.first.intervalMs);
    expect(parsed.steps.first.swipeDurationMs, script.steps.first.swipeDurationMs);
    expect(parsed.requireCharging, isTrue);
    expect(parsed.requireScreenOn, isTrue);
    expect(parsed.requireForegroundApp, 'com.example.target');
    expect(parsed.minBatteryPct, 35);
    expect(parsed.timeWindowStart, '22:00');
    expect(parsed.timeWindowEnd, '06:00');
  });

  test('Internal mapper output does not contain schemaVersion', () {
    final script = makeScript();
    final map = ScriptInternalMapper.toMap(script);
    expect(map.containsKey('schemaVersion'), isFalse);
  });

  test('Schema mapper preserves infinite loop mode', () {
    final script = makeScript().copyWith(loopCount: 0);
    final map = ScriptSchemaMapper.toSchemaV1(script);
    expect((map['loop'] as Map<String, dynamic>)['mode'], 'infinite');

    final parsed = ScriptSchemaMapper.fromSchemaV1(map);
    expect(parsed.loopCount, 0);
  });

  test('Internal mapper applies defaults when fields are missing', () {
    final parsed = ScriptInternalMapper.fromMap(<String, dynamic>{
      'name': 'Partial',
      'type': 'multi_tap',
    });
    expect(parsed.defaultIntervalMs, 300);
    expect(parsed.loopCount, 1);
  });

  test('Schema mapper rejects schema payload with unknown top-level keys', () {
    final script = makeScript();
    final map = ScriptSchemaMapper.toSchemaV1(script)
      ..['unexpected'] = true;

    expect(
      () => ScriptSchemaMapper.fromSchemaV1(map),
      throwsA(isA<FormatException>()),
    );
  });

  test('Schema mapper rejects malformed schema even with schemaVersion', () {
    final malformed = <String, dynamic>{
      'schemaVersion': '1.0',
      'id': 'scr_x',
      'name': 'Bad Script',
      'type': 'multi_tap',
      'createdAt': '2026-02-09T12:00:00Z',
      'updatedAt': '2026-02-09T12:00:00Z',
      'coordinateMode': 'normalized',
      'screen': <String, dynamic>{
        'widthPx': 1080,
        'heightPx': 2400,
        'densityDpi': 420,
        'rotation': 0,
        'insets': <String, dynamic>{
          'topPx': 0,
          'bottomPx': 0,
          'leftPx': 0,
          'rightPx': 0,
        },
      },
      'loop': <String, dynamic>{
        'mode': 'count',
        'count': 1,
      },
      'defaults': <String, dynamic>{
        'intervalMs': 300,
        'holdMs': 40,
        'jitterPx': 0,
        'randomDelayMsMin': 0,
        'randomDelayMsMax': 0,
      },
      'steps': [
        <String, dynamic>{
          'id': 'step_1',
          'type': 'tap',
          // Missing x on purpose
          'y': 0.2,
          'enabled': true,
        },
      ],
    };

    expect(
      () => ScriptSchemaMapper.fromSchemaV1(malformed),
      throwsA(isA<FormatException>()),
    );
  });

  test('Schema mapper rejects tap step with non-tap fields', () {
    final script = makeScript();
    final map = ScriptSchemaMapper.toSchemaV1(script);
    final steps = (map['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
    steps[0]['type'] = 'tap';
    steps[0].remove('durationMs');
    steps[0]['x2'] = 0.7;

    expect(
      () => ScriptSchemaMapper.fromSchemaV1(map),
      throwsA(isA<FormatException>()),
    );
  });

  test('Schema mapper supports multi_touch step', () {
    final now = DateTime(2026, 2, 9);
    final script = ScriptModel(
      id: 'scr_multi_touch',
      name: 'Multi touch',
      type: ScriptType.multiTap,
      createdAt: now,
      updatedAt: now,
      defaultIntervalMs: 300,
      loopCount: 1,
      steps: const [
        ScriptStep(
          id: 'step_mt',
          action: 'multi_touch',
          x: 0.2,
          y: 0.3,
          x2: 0.8,
          y2: 0.7,
          intervalMs: 100,
          swipeDurationMs: 160,
          enabled: true,
        ),
      ],
    );

    final map = ScriptSchemaMapper.toSchemaV1(script);
    final parsed = ScriptSchemaMapper.fromSchemaV1(map);
    expect(parsed.steps.first.action, 'multi_touch');
    expect(parsed.steps.first.x2, closeTo(0.8, 0.0001));
    expect(parsed.steps.first.swipeDurationMs, 160);
  });

  test('Schema mapper rejects empty requireForegroundApp', () {
    final script = makeScript();
    final map = ScriptSchemaMapper.toSchemaV1(script);
    final conditions = Map<String, dynamic>.from(
      map['conditions'] as Map<String, dynamic>,
    )..['requireForegroundApp'] = '   ';
    map['conditions'] = conditions;

    expect(
      () => ScriptSchemaMapper.fromSchemaV1(map),
      throwsA(isA<FormatException>()),
    );
  });
}
