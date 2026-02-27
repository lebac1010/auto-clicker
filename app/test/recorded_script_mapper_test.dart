import 'package:auto_clicker/models/recorded_step.dart';
import 'package:auto_clicker/services/recorded_script_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps recorded steps to script steps preserving coordinates and enabled state', () {
    final recorded = <RecordedStep>[
      const RecordedStep(
        index: 1,
        action: 'double_tap',
        x: 0.25,
        y: 0.75,
        delayMs: 120,
        holdMs: 90,
        enabled: true,
      ),
      const RecordedStep(
        index: 2,
        action: 'tap',
        x: 0.5,
        y: 0.5,
        delayMs: 80,
        enabled: false,
      ),
    ];

    final mapped = RecordedScriptMapper.toScriptSteps(
      recorded,
      idGenerator: (index) => 'step_$index',
    );

    expect(mapped, hasLength(2));
    expect(mapped.first.id, 'step_1');
    expect(mapped.first.action, 'double_tap');
    expect(mapped.first.x, closeTo(0.25, 0.0001));
    expect(mapped.first.y, closeTo(0.75, 0.0001));
    expect(mapped.first.intervalMs, 120);
    expect(mapped.first.holdMs, 90);
    expect(mapped.first.enabled, isTrue);

    expect(mapped[1].id, 'step_2');
    expect(mapped[1].enabled, isFalse);
  });

  test('uses fallback interval for zero or negative delays', () {
    final recorded = <RecordedStep>[
      const RecordedStep(
        index: 1,
        action: 'tap',
        x: 0.2,
        y: 0.2,
        delayMs: 0,
      ),
      const RecordedStep(
        index: 2,
        action: 'tap',
        x: 0.3,
        y: 0.3,
        delayMs: -10,
      ),
    ];

    final mapped = RecordedScriptMapper.toScriptSteps(
      recorded,
      zeroDelayFallbackMs: 77,
      idGenerator: (index) => 'mapped_$index',
    );

    expect(mapped.first.intervalMs, 77);
    expect(mapped[1].intervalMs, 77);
  });

  test('falls back to tap when recorded action is unsupported', () {
    final recorded = <RecordedStep>[
      const RecordedStep(
        index: 1,
        action: 'pinch',
        x: 0.4,
        y: 0.4,
        delayMs: 100,
        holdMs: 20,
      ),
    ];

    final mapped = RecordedScriptMapper.toScriptSteps(
      recorded,
      idGenerator: (index) => 'step_$index',
    );

    expect(mapped.first.action, 'tap');
    expect(mapped.first.holdMs, 20);
  });

  test('maps swipe recorded step to swipe script step', () {
    final recorded = <RecordedStep>[
      const RecordedStep(
        index: 1,
        action: 'swipe',
        x: 0.1,
        y: 0.2,
        x2: 0.9,
        y2: 0.8,
        delayMs: 200,
        swipeDurationMs: 350,
      ),
    ];

    final mapped = RecordedScriptMapper.toScriptSteps(
      recorded,
      idGenerator: (index) => 'step_$index',
    );

    expect(mapped.first.action, 'swipe');
    expect(mapped.first.x2, closeTo(0.9, 0.0001));
    expect(mapped.first.y2, closeTo(0.8, 0.0001));
    expect(mapped.first.swipeDurationMs, 350);
  });

  test('maps multi-touch recorded step to multi-touch script step', () {
    final recorded = <RecordedStep>[
      const RecordedStep(
        index: 1,
        action: 'multi_touch',
        x: 0.2,
        y: 0.3,
        x2: 0.7,
        y2: 0.6,
        delayMs: 150,
        swipeDurationMs: 190,
      ),
    ];
    final mapped = RecordedScriptMapper.toScriptSteps(
      recorded,
      idGenerator: (index) => 'step_$index',
    );
    expect(mapped.first.action, 'multi_touch');
    expect(mapped.first.x2, closeTo(0.7, 0.0001));
    expect(mapped.first.y2, closeTo(0.6, 0.0001));
    expect(mapped.first.swipeDurationMs, 190);
  });
}
