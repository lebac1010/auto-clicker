import 'package:auto_clicker/services/home_mode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeModeService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults to normal when no value exists', () async {
      final mode = await HomeModeService.loadPreferredMode();
      expect(mode, HomeMode.normal);
    });

    test('persists preferred mode', () async {
      await HomeModeService.savePreferredMode(HomeMode.advanced);
      final mode = await HomeModeService.loadPreferredMode();
      expect(mode, HomeMode.advanced);
    });

    test('prompt state can be marked seen and reset', () async {
      expect(await HomeModeService.shouldShowModePrompt(), isTrue);

      await HomeModeService.markModePromptSeen();
      expect(await HomeModeService.shouldShowModePrompt(), isFalse);

      await HomeModeService.resetModePrompt();
      expect(await HomeModeService.shouldShowModePrompt(), isTrue);
    });
  });
}
