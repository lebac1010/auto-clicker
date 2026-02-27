import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';

class ScriptSchemaMapper {
  const ScriptSchemaMapper._();

  static Map<String, dynamic> toSchemaV1(ScriptModel script) {
    final bool isInfinite = script.loopCount <= 0;
    return <String, dynamic>{
      'schemaVersion': '1.0',
      'id': script.id,
      'name': script.name,
      'type': script.type.value,
      'createdAt': script.createdAt.toUtc().toIso8601String(),
      'updatedAt': script.updatedAt.toUtc().toIso8601String(),
      'coordinateMode': 'normalized',
      'screen': <String, dynamic>{
        'widthPx': 1080,
        'heightPx': 2400,
        'densityDpi': 420,
        'rotation': 0,
        'insets': <String, dynamic>{
          'topPx': 0,
          'bottomPx': 0,
          'leftPx': 0,
          'rightPx': 0,
        },
      },
      'loop': <String, dynamic>{
        'mode': isInfinite ? 'infinite' : 'count',
        'count': isInfinite ? null : script.loopCount,
        'durationMs': null,
      },
      'defaults': <String, dynamic>{
        'intervalMs': script.defaultIntervalMs,
        'holdMs': 40,
        'jitterPx': 0,
        'randomDelayMsMin': 0,
        'randomDelayMsMax': 0,
      },
      'steps': script.steps.map(_stepToSchema).toList(),
      'conditions': _conditionsToSchema(script),
      'metadata': <String, dynamic>{'source': 'auto_clicker_app'},
    };
  }

  static Map<String, dynamic> _stepToSchema(ScriptStep step) {
    if (step.action == 'swipe' || step.action == 'multi_touch') {
      return <String, dynamic>{
        'id': step.id,
        'type': step.action,
        'x': step.x,
        'y': step.y,
        'x2': step.x2 ?? step.x,
        'y2': step.y2 ?? step.y,
        'durationMs': step.swipeDurationMs,
        'intervalMs': step.intervalMs,
        'enabled': step.enabled,
      };
    }
    return <String, dynamic>{
      'id': step.id,
      'type': step.action == 'double_tap' ? 'double_tap' : 'tap',
      'x': step.x,
      'y': step.y,
      'intervalMs': step.intervalMs,
      'holdMs': step.holdMs,
      'enabled': step.enabled,
    };
  }

  static Map<String, dynamic>? _conditionsToSchema(ScriptModel script) {
    final foregroundApp = script.requireForegroundApp?.trim();
    final hasForegroundApp = foregroundApp != null && foregroundApp.isNotEmpty;
    final hasTimeWindow =
        script.timeWindowStart != null &&
        script.timeWindowEnd != null &&
        script.timeWindowStart!.trim().isNotEmpty &&
        script.timeWindowEnd!.trim().isNotEmpty;
    final hasMinBattery = script.minBatteryPct != null;
    final hasRequireScreenOn = script.requireScreenOn;
    if (!script.requireCharging &&
        !hasRequireScreenOn &&
        !hasForegroundApp &&
        !hasMinBattery &&
        !hasTimeWindow) {
      return null;
    }
    return <String, dynamic>{
      'requireCharging': script.requireCharging,
      if (hasRequireScreenOn) 'requireScreenOn': true,
      if (hasForegroundApp) 'requireForegroundApp': foregroundApp,
      if (hasMinBattery) 'minBatteryPct': script.minBatteryPct,
      if (hasTimeWindow)
        'timeWindow': <String, dynamic>{
          'start': script.timeWindowStart,
          'end': script.timeWindowEnd,
        },
    };
  }

  static ScriptModel fromSchemaV1(
    Map<String, dynamic> map, {
    String? overrideId,
    String? overrideName,
  }) {
    _validateSchemaStrict(map);
    final now = DateTime.now();
    final defaults = Map<String, dynamic>.from(map['defaults'] as Map);
    final loop = Map<String, dynamic>.from(map['loop'] as Map);
    final rawSteps = map['steps'] as List<dynamic>;
    final steps = rawSteps.asMap().entries.map((entry) {
      final raw = entry.value;
      if (raw is! Map) {
        throw FormatException('Step at index ${entry.key} must be an object.');
      }
      final step = Map<String, dynamic>.from(raw);
      final type = step['type']?.toString() ?? 'tap';
      if (type != 'tap' &&
          type != 'double_tap' &&
          type != 'swipe' &&
          type != 'multi_touch' &&
          type != 'long_press') {
        throw const FormatException(
          'Only tap, double_tap, long_press, swipe, and multi_touch are supported in this phase.',
        );
      }
      final x = (step['x'] as num?)?.toDouble();
      final y = (step['y'] as num?)?.toDouble();
      if (x == null || y == null || x < 0 || x > 1 || y < 0 || y > 1) {
        throw const FormatException('Schema coordinates must be normalized between 0 and 1.');
      }
      final intervalMs =
          (step['intervalMs'] as num?)?.toInt() ??
          (defaults['intervalMs'] as num).toInt();
      final holdMs =
          (step['holdMs'] as num?)?.toInt() ??
          (defaults['holdMs'] as num).toInt();
      if (intervalMs < 0) {
        throw const FormatException('Step intervalMs must be >= 0.');
      }
      final durationMs = (step['durationMs'] as num?)?.toInt();
      if (holdMs < 0 || (durationMs != null && durationMs < 1)) {
        throw const FormatException('Step holdMs must be >= 0 and durationMs must be >= 1 when provided.');
      }
      final isGestureWithEnd = type == 'swipe' || type == 'multi_touch';
      final x2 = (step['x2'] as num?)?.toDouble();
      final y2 = (step['y2'] as num?)?.toDouble();
      if (isGestureWithEnd) {
        if (x2 == null || y2 == null || x2 < 0 || x2 > 1 || y2 < 0 || y2 > 1) {
          throw const FormatException('Swipe step must include normalized x2/y2.');
        }
      }
      final action = switch (type) {
        'double_tap' => 'double_tap',
        'swipe' => 'swipe',
        'multi_touch' => 'multi_touch',
        _ => 'tap',
      };
      final resolvedHoldMs = type == 'long_press' ? (durationMs ?? holdMs) : holdMs;
      return ScriptStep(
        id: step['id']?.toString() ?? 'step_${DateTime.now().microsecondsSinceEpoch}',
        action: action,
        x: x,
        y: y,
        x2: x2,
        y2: y2,
        intervalMs: intervalMs,
        holdMs: resolvedHoldMs,
        swipeDurationMs: durationMs ?? 250,
        enabled: step['enabled'] != false,
      );
    }).toList();

    final type = ScriptType.fromValue(map['type']?.toString() ?? 'multi_tap');
    final loopMode = loop['mode']?.toString() ?? 'count';
    final loopCount = switch (loopMode) {
      'count' => (loop['count'] as num?)?.toInt() ?? 1,
      'infinite' => 0,
      'duration' => 1,
      _ => 1,
    };
    final conditions = map['conditions'] is Map
        ? Map<String, dynamic>.from(map['conditions'] as Map)
        : const <String, dynamic>{};
    final foregroundAppRaw = conditions['requireForegroundApp']?.toString();
    final foregroundApp = foregroundAppRaw?.trim();
    final minBatteryPct = (conditions['minBatteryPct'] as num?)?.toInt();
    String? timeWindowStart;
    String? timeWindowEnd;
    final timeWindowRaw = conditions['timeWindow'];
    if (timeWindowRaw is Map) {
      final timeWindow = Map<String, dynamic>.from(timeWindowRaw);
      timeWindowStart = timeWindow['start']?.toString();
      timeWindowEnd = timeWindow['end']?.toString();
    }
    return ScriptModel(
      id: overrideId ?? map['id']?.toString() ?? 'scr_${now.millisecondsSinceEpoch}',
      name: overrideName ?? map['name']?.toString() ?? 'Imported Schema Script',
      type: type,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? now,
      lastRunAt: null,
      defaultIntervalMs: (defaults['intervalMs'] as num).toInt(),
      loopCount: loopCount < 0 ? 1 : loopCount,
      requireCharging: conditions['requireCharging'] == true,
      requireScreenOn: conditions['requireScreenOn'] == true,
      requireForegroundApp: foregroundApp == null || foregroundApp.isEmpty
          ? null
          : foregroundApp,
      minBatteryPct: minBatteryPct,
      timeWindowStart: timeWindowStart,
      timeWindowEnd: timeWindowEnd,
      steps: steps,
    );
  }

  static void _validateSchemaStrict(Map<String, dynamic> map) {
    const requiredTop = <String>{
      'schemaVersion',
      'id',
      'name',
      'type',
      'createdAt',
      'updatedAt',
      'coordinateMode',
      'screen',
      'loop',
      'defaults',
      'steps',
    };
    const allowedTop = <String>{
      'schemaVersion',
      'id',
      'name',
      'type',
      'createdAt',
      'updatedAt',
      'coordinateMode',
      'screen',
      'loop',
      'defaults',
      'steps',
      'conditions',
      'metadata',
    };
    final unknownTopKeys = map.keys.where((key) => !allowedTop.contains(key)).toList();
    if (unknownTopKeys.isNotEmpty) {
      throw FormatException('Unknown top-level keys: ${unknownTopKeys.join(', ')}');
    }
    for (final key in requiredTop) {
      if (!map.containsKey(key)) {
        throw FormatException('Missing required key: $key');
      }
    }
    if (map['schemaVersion']?.toString() != '1.0') {
      throw const FormatException('Unsupported schemaVersion. Expected 1.0');
    }
    if (map['coordinateMode']?.toString() != 'normalized') {
      throw const FormatException('Only normalized coordinateMode is supported.');
    }
    if (map['id'] is! String || (map['id'] as String).trim().isEmpty) {
      throw const FormatException('Invalid id');
    }
    if (map['name'] is! String || (map['name'] as String).trim().isEmpty) {
      throw const FormatException('Invalid name');
    }
    const allowedTypes = <String>{'single_tap', 'multi_tap', 'swipe', 'macro'};
    final type = map['type']?.toString();
    if (type == null || !allowedTypes.contains(type)) {
      throw const FormatException('Invalid script type');
    }
    if (DateTime.tryParse(map['createdAt']?.toString() ?? '') == null) {
      throw const FormatException('createdAt must be ISO date-time');
    }
    if (DateTime.tryParse(map['updatedAt']?.toString() ?? '') == null) {
      throw const FormatException('updatedAt must be ISO date-time');
    }
    if (map['screen'] is! Map) {
      throw const FormatException('screen must be an object');
    }
    if (map['loop'] is! Map) {
      throw const FormatException('loop must be an object');
    }
    if (map['defaults'] is! Map) {
      throw const FormatException('defaults must be an object');
    }
    _validateScreen(Map<String, dynamic>.from(map['screen'] as Map));
    _validateLoop(Map<String, dynamic>.from(map['loop'] as Map));
    _validateDefaults(Map<String, dynamic>.from(map['defaults'] as Map));
    if (map['conditions'] != null) {
      if (map['conditions'] is! Map) {
        throw const FormatException('conditions must be an object');
      }
      _validateConditions(Map<String, dynamic>.from(map['conditions'] as Map));
    }
    if (map['steps'] is! List || (map['steps'] as List).isEmpty) {
      throw const FormatException('Invalid steps array');
    }
    final rawSteps = map['steps'] as List<dynamic>;
    for (var i = 0; i < rawSteps.length; i += 1) {
      final raw = rawSteps[i];
      if (raw is! Map) {
        throw FormatException('Step at index $i must be an object');
      }
      _validateStep(Map<String, dynamic>.from(raw), i);
    }
  }

  static void _validateScreen(Map<String, dynamic> screen) {
    const required = <String>{'widthPx', 'heightPx', 'densityDpi', 'rotation', 'insets'};
    const allowed = <String>{'widthPx', 'heightPx', 'densityDpi', 'rotation', 'insets'};
    final unknownKeys = screen.keys.where((k) => !allowed.contains(k)).toList();
    if (unknownKeys.isNotEmpty) {
      throw FormatException('Unknown screen keys: ${unknownKeys.join(', ')}');
    }
    for (final key in required) {
      if (!screen.containsKey(key)) {
        throw FormatException('Missing required screen key: $key');
      }
    }
    final width = (screen['widthPx'] as num?)?.toInt();
    final height = (screen['heightPx'] as num?)?.toInt();
    final density = (screen['densityDpi'] as num?)?.toInt();
    final rotation = (screen['rotation'] as num?)?.toInt();
    if (width == null || width < 1) {
      throw const FormatException('screen.widthPx must be >= 1');
    }
    if (height == null || height < 1) {
      throw const FormatException('screen.heightPx must be >= 1');
    }
    if (density == null || density < 1) {
      throw const FormatException('screen.densityDpi must be >= 1');
    }
    if (rotation == null || !<int>{0, 90, 180, 270}.contains(rotation)) {
      throw const FormatException('screen.rotation must be one of 0,90,180,270');
    }
    final insetsRaw = screen['insets'];
    if (insetsRaw is! Map) {
      throw const FormatException('screen.insets must be an object');
    }
    final insets = Map<String, dynamic>.from(insetsRaw);
    const insetsRequired = <String>{'topPx', 'bottomPx', 'leftPx', 'rightPx'};
    const insetsAllowed = <String>{'topPx', 'bottomPx', 'leftPx', 'rightPx'};
    final unknownInsets = insets.keys.where((k) => !insetsAllowed.contains(k)).toList();
    if (unknownInsets.isNotEmpty) {
      throw FormatException('Unknown insets keys: ${unknownInsets.join(', ')}');
    }
    for (final key in insetsRequired) {
      if (!insets.containsKey(key)) {
        throw FormatException('Missing required insets key: $key');
      }
      final value = (insets[key] as num?)?.toInt();
      if (value == null || value < 0) {
        throw FormatException('Insets key $key must be >= 0');
      }
    }
  }

  static void _validateLoop(Map<String, dynamic> loop) {
    const required = <String>{'mode'};
    const allowed = <String>{'mode', 'count', 'durationMs'};
    final unknownKeys = loop.keys.where((k) => !allowed.contains(k)).toList();
    if (unknownKeys.isNotEmpty) {
      throw FormatException('Unknown loop keys: ${unknownKeys.join(', ')}');
    }
    for (final key in required) {
      if (!loop.containsKey(key)) {
        throw FormatException('Missing required loop key: $key');
      }
    }
    final mode = loop['mode']?.toString();
    if (!<String>{'infinite', 'count', 'duration'}.contains(mode)) {
      throw const FormatException('Invalid loop.mode');
    }
    if (mode == 'count') {
      final count = (loop['count'] as num?)?.toInt();
      if (count == null || count < 1) {
        throw const FormatException('loop.count must be >= 1 when mode=count');
      }
    }
    if (mode == 'duration') {
      final durationMs = (loop['durationMs'] as num?)?.toInt();
      if (durationMs == null || durationMs < 1) {
        throw const FormatException('loop.durationMs must be >= 1 when mode=duration');
      }
    }
  }

  static void _validateDefaults(Map<String, dynamic> defaults) {
    const required = <String>{
      'intervalMs',
      'holdMs',
      'jitterPx',
      'randomDelayMsMin',
      'randomDelayMsMax',
    };
    const allowed = <String>{
      'intervalMs',
      'holdMs',
      'jitterPx',
      'randomDelayMsMin',
      'randomDelayMsMax',
    };
    final unknownKeys = defaults.keys.where((k) => !allowed.contains(k)).toList();
    if (unknownKeys.isNotEmpty) {
      throw FormatException('Unknown defaults keys: ${unknownKeys.join(', ')}');
    }
    for (final key in required) {
      if (!defaults.containsKey(key)) {
        throw FormatException('Missing required defaults key: $key');
      }
    }
    final intervalMs = (defaults['intervalMs'] as num?)?.toInt();
    final holdMs = (defaults['holdMs'] as num?)?.toInt();
    final jitterPx = (defaults['jitterPx'] as num?)?.toInt();
    final delayMin = (defaults['randomDelayMsMin'] as num?)?.toInt();
    final delayMax = (defaults['randomDelayMsMax'] as num?)?.toInt();
    if (intervalMs == null || intervalMs < 1) {
      throw const FormatException('defaults.intervalMs must be >= 1');
    }
    if (holdMs == null || holdMs < 0) {
      throw const FormatException('defaults.holdMs must be >= 0');
    }
    if (jitterPx == null || jitterPx < 0) {
      throw const FormatException('defaults.jitterPx must be >= 0');
    }
    if (delayMin == null || delayMin < 0) {
      throw const FormatException('defaults.randomDelayMsMin must be >= 0');
    }
    if (delayMax == null || delayMax < 0) {
      throw const FormatException('defaults.randomDelayMsMax must be >= 0');
    }
    if (delayMax < delayMin) {
      throw const FormatException('defaults.randomDelayMsMax must be >= randomDelayMsMin');
    }
  }

  static void _validateStep(Map<String, dynamic> step, int index) {
    const required = <String>{'id', 'type', 'enabled'};
    for (final key in required) {
      if (!step.containsKey(key)) {
        throw FormatException('Missing required step key $key at index $index');
      }
    }
    final id = step['id'];
    if (id is! String || id.trim().isEmpty) {
      throw FormatException('Step id at index $index must be non-empty string');
    }
    if (step['enabled'] is! bool) {
      throw FormatException('Step enabled at index $index must be boolean');
    }
    final type = step['type']?.toString();
    if (type != 'tap' &&
        type != 'double_tap' &&
        type != 'swipe' &&
        type != 'multi_touch' &&
        type != 'long_press') {
      throw const FormatException(
        'Only tap, double_tap, long_press, swipe, and multi_touch are supported in this phase.',
      );
    }
    const allowedKeys = <String>{
      'id',
      'type',
      'enabled',
      'label',
      'intervalMs',
      'holdMs',
      'x',
      'y',
      'x2',
      'y2',
      'durationMs',
    };
    final unknownKeys = step.keys.where((k) => !allowedKeys.contains(k)).toList();
    if (unknownKeys.isNotEmpty) {
      throw FormatException('Unknown step keys at index $index: ${unknownKeys.join(', ')}');
    }
    final x = (step['x'] as num?)?.toDouble();
    final y = (step['y'] as num?)?.toDouble();
    if (x == null || x < 0 || x > 1 || y == null || y < 0 || y > 1) {
      throw FormatException('Step coordinates at index $index must be normalized between 0 and 1');
    }
    if (type == 'swipe' || type == 'multi_touch') {
      final x2 = (step['x2'] as num?)?.toDouble();
      final y2 = (step['y2'] as num?)?.toDouble();
      final duration = (step['durationMs'] as num?)?.toInt();
      if (x2 == null || x2 < 0 || x2 > 1 || y2 == null || y2 < 0 || y2 > 1) {
        throw FormatException('Step x2/y2 at index $index must be normalized between 0 and 1');
      }
      if (duration == null || duration < 1) {
        throw FormatException('Step durationMs at index $index must be >= 1');
      }
    } else {
      if (step.containsKey('x2') || step.containsKey('y2')) {
        throw FormatException('Step type $type at index $index must not contain x2/y2');
      }
    }
    if (type == 'long_press') {
      final duration = (step['durationMs'] as num?)?.toInt();
      if (duration == null || duration < 1) {
        throw FormatException('long_press durationMs at index $index must be >= 1');
      }
    }
    if (step.containsKey('intervalMs')) {
      final interval = (step['intervalMs'] as num?)?.toInt();
      if (interval == null || interval < 0) {
        throw FormatException('Step intervalMs at index $index must be >= 0');
      }
    }
    if (step.containsKey('holdMs')) {
      final hold = (step['holdMs'] as num?)?.toInt();
      if (hold == null || hold < 0) {
        throw FormatException('Step holdMs at index $index must be >= 0');
      }
    }
  }

  static void _validateConditions(Map<String, dynamic> conditions) {
    const allowed = <String>{
      'requireCharging',
      'requireForegroundApp',
      'requireScreenOn',
      'minBatteryPct',
      'timeWindow',
    };
    final unknownKeys = conditions.keys.where((k) => !allowed.contains(k)).toList();
    if (unknownKeys.isNotEmpty) {
      throw FormatException('Unknown conditions keys: ${unknownKeys.join(', ')}');
    }
    if (conditions.containsKey('requireCharging') &&
        conditions['requireCharging'] is! bool) {
      throw const FormatException('conditions.requireCharging must be boolean');
    }
    if (conditions.containsKey('requireScreenOn') &&
        conditions['requireScreenOn'] is! bool) {
      throw const FormatException('conditions.requireScreenOn must be boolean');
    }
    if (conditions.containsKey('requireForegroundApp') &&
        conditions['requireForegroundApp'] != null &&
        conditions['requireForegroundApp'] is! String) {
      throw const FormatException('conditions.requireForegroundApp must be string or null');
    }
    final foregroundAppRaw = conditions['requireForegroundApp']?.toString();
    final foregroundApp = foregroundAppRaw?.trim();
    if (foregroundApp != null && foregroundApp.isEmpty) {
      throw const FormatException('conditions.requireForegroundApp must not be empty when provided');
    }
    if (conditions.containsKey('minBatteryPct')) {
      if (conditions['minBatteryPct'] != null) {
        final minBattery = (conditions['minBatteryPct'] as num?)?.toInt();
        if (minBattery == null || minBattery < 0 || minBattery > 100) {
          throw const FormatException('conditions.minBatteryPct must be 0..100');
        }
      }
    }
    if (conditions.containsKey('timeWindow')) {
      final raw = conditions['timeWindow'];
      if (raw != null && raw is! Map) {
        throw const FormatException('conditions.timeWindow must be object');
      }
      if (raw is Map) {
        final timeWindow = Map<String, dynamic>.from(raw);
        final start = timeWindow['start']?.toString() ?? '';
        final end = timeWindow['end']?.toString() ?? '';
        final pattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
        if (!pattern.hasMatch(start) || !pattern.hasMatch(end)) {
          throw const FormatException('conditions.timeWindow requires HH:mm start/end');
        }
      }
    }
  }
}
