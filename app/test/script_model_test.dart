import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScriptModel makeScript({DateTime? lastRunAt}) {
    final now = DateTime(2026, 2, 10, 10, 0, 0);
    return ScriptModel(
      id: 'scr_test',
      name: 'Test Script',
      type: ScriptType.multiTap,
      createdAt: now,
      updatedAt: now,
      lastRunAt: lastRunAt,
      defaultIntervalMs: 300,
      loopCount: 1,
      steps: const <ScriptStep>[
        ScriptStep(id: 'step_1', x: 0.5, y: 0.5, intervalMs: 100, enabled: true),
      ],
    );
  }

  test('copyWith keeps lastRunAt when not provided', () {
    final lastRunAt = DateTime(2026, 2, 10, 11, 0, 0);
    final source = makeScript(lastRunAt: lastRunAt);
    final updated = source.copyWith(name: 'Renamed');

    expect(updated.lastRunAt, lastRunAt);
  });

  test('copyWith can clear lastRunAt to null', () {
    final source = makeScript(lastRunAt: DateTime(2026, 2, 10, 11, 0, 0));
    final updated = source.copyWith(lastRunAt: null);

    expect(updated.lastRunAt, isNull);
  });

  test('json roundtrip keeps requireScreenOn and normalizes foreground package', () {
    final source = makeScript().copyWith(
      requireScreenOn: true,
      requireForegroundApp: '  com.example.target  ',
      minBatteryPct: 40,
    );
    final parsed = ScriptModel.fromJson(source.toJson());

    expect(parsed.requireScreenOn, isTrue);
    expect(parsed.requireForegroundApp, 'com.example.target');
    expect(parsed.minBatteryPct, 40);
  });
}
