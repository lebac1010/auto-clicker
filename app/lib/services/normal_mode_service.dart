import 'dart:convert';

import 'package:auto_clicker/models/normal_quick_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NormalModeService {
  NormalModeService._();

  static const String _configKey = 'normal_quick_config_v1';

  static Future<NormalQuickConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_configKey);
      if (raw == null || raw.trim().isEmpty) {
        return NormalQuickConfig.defaults;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NormalQuickConfig.fromJson(map);
    } catch (_) {
      return NormalQuickConfig.defaults;
    }
  }

  static Future<void> saveConfig(NormalQuickConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(config.toJson()));
    } catch (_) {
      // Ignore persistence failures to keep normal mode usable.
    }
  }
}
