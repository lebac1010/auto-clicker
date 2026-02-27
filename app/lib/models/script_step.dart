class ScriptStep {
  const ScriptStep({
    required this.id,
    this.action = 'tap',
    required this.x,
    required this.y,
    this.x2,
    this.y2,
    required this.intervalMs,
    required this.enabled,
    this.holdMs = 40,
    this.swipeDurationMs = 250,
  });

  final String id;
  final String action;
  final double x;
  final double y;
  final double? x2;
  final double? y2;
  final int intervalMs;
  final bool enabled;
  final int holdMs;
  final int swipeDurationMs;

  ScriptStep copyWith({
    String? id,
    String? action,
    double? x,
    double? y,
    Object? x2 = _scriptStepNoChange,
    Object? y2 = _scriptStepNoChange,
    int? intervalMs,
    bool? enabled,
    int? holdMs,
    int? swipeDurationMs,
  }) {
    return ScriptStep(
      id: id ?? this.id,
      action: action ?? this.action,
      x: x ?? this.x,
      y: y ?? this.y,
      x2: identical(x2, _scriptStepNoChange) ? this.x2 : x2 as double?,
      y2: identical(y2, _scriptStepNoChange) ? this.y2 : y2 as double?,
      intervalMs: intervalMs ?? this.intervalMs,
      enabled: enabled ?? this.enabled,
      holdMs: holdMs ?? this.holdMs,
      swipeDurationMs: swipeDurationMs ?? this.swipeDurationMs,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'action': action,
      'x': x,
      'y': y,
      'x2': x2,
      'y2': y2,
      'intervalMs': intervalMs,
      'enabled': enabled,
      'holdMs': holdMs,
      'swipeDurationMs': swipeDurationMs,
    };
  }

  factory ScriptStep.fromJson(Map<String, dynamic> json) {
    return ScriptStep(
      id: json['id'] as String,
      action: json['action']?.toString() ?? 'tap',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      x2: (json['x2'] as num?)?.toDouble(),
      y2: (json['y2'] as num?)?.toDouble(),
      intervalMs: (json['intervalMs'] as num).toInt(),
      enabled: json['enabled'] == true,
      holdMs: (json['holdMs'] as num?)?.toInt() ?? 40,
      swipeDurationMs: (json['swipeDurationMs'] as num?)?.toInt() ?? 250,
    );
  }
}

const Object _scriptStepNoChange = Object();
