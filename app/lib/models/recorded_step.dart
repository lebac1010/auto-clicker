class RecordedStep {
  const RecordedStep({
    required this.index,
    required this.action,
    required this.x,
    required this.y,
    this.x2,
    this.y2,
    required this.delayMs,
    this.holdMs = 40,
    this.swipeDurationMs = 250,
    this.enabled = true,
  });

  final int index;
  final String action;
  final double x;
  final double y;
  final double? x2;
  final double? y2;
  final int delayMs;
  final int holdMs;
  final int swipeDurationMs;
  final bool enabled;

  RecordedStep copyWith({
    int? index,
    String? action,
    double? x,
    double? y,
    Object? x2 = _recordedStepNoChange,
    Object? y2 = _recordedStepNoChange,
    int? delayMs,
    int? holdMs,
    int? swipeDurationMs,
    bool? enabled,
  }) {
    return RecordedStep(
      index: index ?? this.index,
      action: action ?? this.action,
      x: x ?? this.x,
      y: y ?? this.y,
      x2: identical(x2, _recordedStepNoChange) ? this.x2 : x2 as double?,
      y2: identical(y2, _recordedStepNoChange) ? this.y2 : y2 as double?,
      delayMs: delayMs ?? this.delayMs,
      holdMs: holdMs ?? this.holdMs,
      swipeDurationMs: swipeDurationMs ?? this.swipeDurationMs,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'index': index,
      'action': action,
      'x': x,
      'y': y,
      'x2': x2,
      'y2': y2,
      'delayMs': delayMs,
      'holdMs': holdMs,
      'swipeDurationMs': swipeDurationMs,
      'enabled': enabled,
    };
  }

  factory RecordedStep.fromMap(Map<dynamic, dynamic> map) {
    return RecordedStep(
      index: (map['index'] as num?)?.toInt() ?? 0,
      action: map['action']?.toString() ?? 'tap',
      x: (map['x'] as num?)?.toDouble() ?? 0.5,
      y: (map['y'] as num?)?.toDouble() ?? 0.5,
      x2: (map['x2'] as num?)?.toDouble(),
      y2: (map['y2'] as num?)?.toDouble(),
      delayMs: (map['delayMs'] as num?)?.toInt() ?? 0,
      holdMs: (map['holdMs'] as num?)?.toInt() ?? 40,
      swipeDurationMs: (map['swipeDurationMs'] as num?)?.toInt() ?? 250,
      enabled: map['enabled'] != false,
    );
  }
}

const Object _recordedStepNoChange = Object();
