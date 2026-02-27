import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';

const Object _scriptModelNoChange = Object();

class ScriptModel {
  const ScriptModel({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.defaultIntervalMs,
    required this.loopCount,
    required this.steps,
    this.requireCharging = false,
    this.requireScreenOn = false,
    this.requireForegroundApp,
    this.minBatteryPct,
    this.timeWindowStart,
    this.timeWindowEnd,
    this.lastRunAt,
  });

  final String id;
  final String name;
  final ScriptType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRunAt;
  final int defaultIntervalMs;
  final int loopCount;
  final List<ScriptStep> steps;
  final bool requireCharging;
  final bool requireScreenOn;
  final String? requireForegroundApp;
  final int? minBatteryPct;
  final String? timeWindowStart;
  final String? timeWindowEnd;

  ScriptModel copyWith({
    String? id,
    String? name,
    ScriptType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? lastRunAt = _scriptModelNoChange,
    int? defaultIntervalMs,
    int? loopCount,
    List<ScriptStep>? steps,
    bool? requireCharging,
    bool? requireScreenOn,
    Object? requireForegroundApp = _scriptModelNoChange,
    Object? minBatteryPct = _scriptModelNoChange,
    Object? timeWindowStart = _scriptModelNoChange,
    Object? timeWindowEnd = _scriptModelNoChange,
  }) {
    return ScriptModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRunAt: identical(lastRunAt, _scriptModelNoChange)
          ? this.lastRunAt
          : lastRunAt as DateTime?,
      defaultIntervalMs: defaultIntervalMs ?? this.defaultIntervalMs,
      loopCount: loopCount ?? this.loopCount,
      steps: steps ?? this.steps,
      requireCharging: requireCharging ?? this.requireCharging,
      requireScreenOn: requireScreenOn ?? this.requireScreenOn,
      requireForegroundApp:
          identical(requireForegroundApp, _scriptModelNoChange)
          ? this.requireForegroundApp
          : requireForegroundApp as String?,
      minBatteryPct: identical(minBatteryPct, _scriptModelNoChange)
          ? this.minBatteryPct
          : minBatteryPct as int?,
      timeWindowStart: identical(timeWindowStart, _scriptModelNoChange)
          ? this.timeWindowStart
          : timeWindowStart as String?,
      timeWindowEnd: identical(timeWindowEnd, _scriptModelNoChange)
          ? this.timeWindowEnd
          : timeWindowEnd as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final normalizedForegroundApp = requireForegroundApp?.trim();
    return <String, dynamic>{
      'schemaVersion': '1.0',
      'id': id,
      'name': name,
      'type': type.value,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'lastRunAt': lastRunAt?.toUtc().toIso8601String(),
      'defaultIntervalMs': defaultIntervalMs,
      'loopCount': loopCount,
      'steps': steps.map((e) => e.toJson()).toList(),
      'requireCharging': requireCharging,
      'requireScreenOn': requireScreenOn,
      'requireForegroundApp':
          normalizedForegroundApp == null || normalizedForegroundApp.isEmpty
          ? null
          : normalizedForegroundApp,
      'minBatteryPct': minBatteryPct,
      'timeWindowStart': timeWindowStart,
      'timeWindowEnd': timeWindowEnd,
    };
  }

  factory ScriptModel.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'] as List<dynamic>? ?? <dynamic>[];
    final foregroundAppRaw = json['requireForegroundApp']?.toString();
    final foregroundApp = foregroundAppRaw?.trim();
    return ScriptModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ScriptType.fromValue(json['type'] as String? ?? 'multi_tap'),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      lastRunAt: json['lastRunAt'] == null
          ? null
          : DateTime.parse(json['lastRunAt'] as String).toLocal(),
      defaultIntervalMs: (json['defaultIntervalMs'] as num?)?.toInt() ?? 300,
      loopCount: (json['loopCount'] as num?)?.toInt() ?? 1,
      steps: rawSteps
          .whereType<Map>()
          .map((e) => ScriptStep.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      requireCharging: json['requireCharging'] == true,
      requireScreenOn: json['requireScreenOn'] == true,
      requireForegroundApp: foregroundApp == null || foregroundApp.isEmpty
          ? null
          : foregroundApp,
      minBatteryPct: (json['minBatteryPct'] as num?)?.toInt(),
      timeWindowStart: json['timeWindowStart']?.toString(),
      timeWindowEnd: json['timeWindowEnd']?.toString(),
    );
  }
}
