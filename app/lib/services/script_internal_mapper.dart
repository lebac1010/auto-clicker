import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';

class ScriptInternalMapper {
  const ScriptInternalMapper._();

  static Map<String, dynamic> toMap(ScriptModel script) {
    final internal = Map<String, dynamic>.from(script.toJson());
    // Internal format must not contain schema markers to avoid schema-path detection.
    internal.remove('schemaVersion');
    return internal;
  }

  static ScriptModel fromMap(
    Map<String, dynamic> map, {
    String? overrideId,
    String? overrideName,
  }) {
    final now = DateTime.now();
    final foregroundAppRaw = map['requireForegroundApp']?.toString();
    final foregroundApp = foregroundAppRaw?.trim();
    final rawSteps = map['steps'] as List<dynamic>? ?? <dynamic>[];
    final steps = rawSteps
        .whereType<Map>()
        .map((item) {
          final m = Map<String, dynamic>.from(item);
          return ScriptStep(
            id: m['id']?.toString() ?? 'step_${DateTime.now().microsecondsSinceEpoch}',
            action: m['action']?.toString() ?? 'tap',
            x: (m['x'] as num?)?.toDouble() ?? 0.5,
            y: (m['y'] as num?)?.toDouble() ?? 0.5,
            x2: (m['x2'] as num?)?.toDouble(),
            y2: (m['y2'] as num?)?.toDouble(),
            intervalMs: (m['intervalMs'] as num?)?.toInt() ?? 80,
            enabled: m['enabled'] != false,
            holdMs: (m['holdMs'] as num?)?.toInt() ?? 40,
            swipeDurationMs: (m['swipeDurationMs'] as num?)?.toInt() ?? 250,
          );
        })
        .toList();

    return ScriptModel(
      id: overrideId ?? map['id']?.toString() ?? 'scr_${now.millisecondsSinceEpoch}',
      name: overrideName ?? map['name']?.toString() ?? 'Imported Script',
      type: ScriptType.fromValue(map['type']?.toString() ?? 'multi_tap'),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? now,
      lastRunAt: DateTime.tryParse(map['lastRunAt']?.toString() ?? ''),
      defaultIntervalMs: (map['defaultIntervalMs'] as num?)?.toInt() ?? 300,
      loopCount: (map['loopCount'] as num?)?.toInt() ?? 1,
      requireCharging: map['requireCharging'] == true,
      requireScreenOn: map['requireScreenOn'] == true,
      requireForegroundApp: foregroundApp == null || foregroundApp.isEmpty
          ? null
          : foregroundApp,
      minBatteryPct: (map['minBatteryPct'] as num?)?.toInt(),
      timeWindowStart: map['timeWindowStart']?.toString(),
      timeWindowEnd: map['timeWindowEnd']?.toString(),
      steps: steps,
    );
  }
}
