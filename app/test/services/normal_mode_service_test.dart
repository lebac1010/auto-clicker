import 'package:auto_clicker/models/normal_quick_config.dart';
import 'package:auto_clicker/services/normal_mode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NormalModeService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('returns defaults when no config persisted', () async {
      final config = await NormalModeService.loadConfig();
      expect(config.intervalMs, NormalQuickConfig.defaults.intervalMs);
      expect(config.loopCount, NormalQuickConfig.defaults.loopCount);
      expect(config.startDelaySec, NormalQuickConfig.defaults.startDelaySec);
      expect(config.hasSingleTargetPoint, isFalse);
    });

    test('persists and restores config', () async {
      final target = NormalQuickConfig.defaults.copyWith(
        intervalMs: 500,
        loopCount: 4,
        startDelaySec: 2,
        singleTargetX: 0.12,
        singleTargetY: 0.34,
        multiTargetScriptId: 'scr_123',
      );
      await NormalModeService.saveConfig(target);

      final restored = await NormalModeService.loadConfig();
      expect(restored.intervalMs, 500);
      expect(restored.loopCount, 4);
      expect(restored.startDelaySec, 2);
      expect(restored.singleTargetX, 0.12);
      expect(restored.singleTargetY, 0.34);
      expect(restored.multiTargetScriptId, 'scr_123');
    });
  });
}
