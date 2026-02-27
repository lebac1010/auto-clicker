import 'package:auto_clicker/models/normal_quick_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NormalQuickConfig', () {
    test('defaults are valid', () {
      final config = NormalQuickConfig.defaults;
      expect(config.intervalMs, 300);
      expect(config.loopCount, 10);
      expect(config.startDelaySec, 0);
      expect(config.hasSingleTargetPoint, isFalse);
    });

    test('fromJson normalizes invalid numbers', () {
      final parsed = NormalQuickConfig.fromJson(<String, dynamic>{
        'intervalMs': -1,
        'loopCount': 0,
        'startDelaySec': -10,
      });

      expect(parsed.intervalMs, 1);
      expect(parsed.loopCount, 1);
      expect(parsed.startDelaySec, 0);
    });

    test('copyWith updates single target point', () {
      final updated = NormalQuickConfig.defaults.copyWith(
        singleTargetX: 0.25,
        singleTargetY: 0.5,
      );

      expect(updated.hasSingleTargetPoint, isTrue);
      expect(updated.singleTargetX, 0.25);
      expect(updated.singleTargetY, 0.5);
    });
  });
}
