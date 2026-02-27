enum ScheduleType {
  daily,
  weekly,
  once;

  static ScheduleType fromValue(String value) {
    switch (value) {
      case 'daily':
        return ScheduleType.daily;
      case 'weekly':
        return ScheduleType.weekly;
      case 'once':
        return ScheduleType.once;
      default:
        return ScheduleType.daily;
    }
  }
}

const Object _scheduleModelNoChange = Object();

class ScheduleModel {
  const ScheduleModel({
    required this.id,
    required this.scriptId,
    required this.type,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.timeOfDay,
    this.weekdays = const <int>[],
    this.onceAt,
    this.lastTriggeredAt,
  });

  final String id;
  final String scriptId;
  final ScheduleType type;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? timeOfDay;
  final List<int> weekdays;
  final DateTime? onceAt;
  final DateTime? lastTriggeredAt;

  ScheduleModel copyWith({
    String? id,
    String? scriptId,
    ScheduleType? type,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? timeOfDay = _scheduleModelNoChange,
    List<int>? weekdays,
    Object? onceAt = _scheduleModelNoChange,
    Object? lastTriggeredAt = _scheduleModelNoChange,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      scriptId: scriptId ?? this.scriptId,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      timeOfDay: identical(timeOfDay, _scheduleModelNoChange)
          ? this.timeOfDay
          : timeOfDay as String?,
      weekdays: weekdays ?? this.weekdays,
      onceAt: identical(onceAt, _scheduleModelNoChange)
          ? this.onceAt
          : onceAt as DateTime?,
      lastTriggeredAt: identical(lastTriggeredAt, _scheduleModelNoChange)
          ? this.lastTriggeredAt
          : lastTriggeredAt as DateTime?,
    );
  }

  List<String> validate() {
    final errors = <String>[];
    if (scriptId.trim().isEmpty) {
      errors.add('Script is required.');
    }
    if (type == ScheduleType.once) {
      if (onceAt == null) {
        errors.add('One-time schedule requires date-time.');
      }
    } else {
      final value = timeOfDay?.trim() ?? '';
      final timeRegex = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
      if (!timeRegex.hasMatch(value)) {
        errors.add('Time of day must use HH:mm format.');
      }
      if (type == ScheduleType.weekly) {
        if (weekdays.isEmpty) {
          errors.add('Weekly schedule requires at least one weekday.');
        }
        final hasInvalidWeekday = weekdays.any(
          (day) => day < DateTime.monday || day > DateTime.sunday,
        );
        if (hasInvalidWeekday) {
          errors.add('Weekly schedule weekdays must be between 1 and 7.');
        }
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'scriptId': scriptId,
      'type': type.name,
      'enabled': enabled,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'timeOfDay': timeOfDay,
      'weekdays': weekdays,
      'onceAt': onceAt?.toUtc().toIso8601String(),
      'lastTriggeredAt': lastTriggeredAt?.toUtc().toIso8601String(),
    };
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    final weekdays = (json['weekdays'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<num>()
        .map((value) => value.toInt())
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();
    return ScheduleModel(
      id: json['id'] as String,
      scriptId: json['scriptId'] as String,
      type: ScheduleType.fromValue(json['type']?.toString() ?? 'daily'),
      enabled: json['enabled'] == true,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      timeOfDay: json['timeOfDay']?.toString(),
      weekdays: weekdays,
      onceAt: json['onceAt'] == null
          ? null
          : DateTime.parse(json['onceAt'] as String).toLocal(),
      lastTriggeredAt: json['lastTriggeredAt'] == null
          ? null
          : DateTime.parse(json['lastTriggeredAt'] as String).toLocal(),
    );
  }
}
