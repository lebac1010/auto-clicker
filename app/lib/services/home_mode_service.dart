import 'package:shared_preferences/shared_preferences.dart';

enum HomeMode {
  normal,
  advanced;

  static HomeMode fromValue(String? value) {
    if (value == 'advanced') {
      return HomeMode.advanced;
    }
    return HomeMode.normal;
  }

  String get value => this == HomeMode.advanced ? 'advanced' : 'normal';
}

class HomeModeService {
  HomeModeService._();

  static const String _preferredModeKey = 'home_preferred_mode';
  static const String _modePromptSeenKey = 'home_mode_prompt_seen';

  static Future<HomeMode> loadPreferredMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_preferredModeKey);
      return HomeMode.fromValue(raw);
    } catch (_) {
      return HomeMode.normal;
    }
  }

  static Future<void> savePreferredMode(HomeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredModeKey, mode.value);
    } catch (_) {
      // Ignore persistence failure to keep app navigation responsive.
    }
  }

  static Future<bool> shouldShowModePrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_modePromptSeenKey) ?? false;
      return !seen;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markModePromptSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_modePromptSeenKey, true);
    } catch (_) {
      // Ignore persistence failure.
    }
  }

  static Future<void> resetModePrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_modePromptSeenKey, false);
    } catch (_) {
      // Ignore persistence failure.
    }
  }
}
