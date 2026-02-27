import 'package:auto_clicker/models/script_model.dart';

class ScriptValidator {
  const ScriptValidator._();

  static List<String> validate(ScriptModel script) {
    final errors = <String>[];
    final foregroundApp = script.requireForegroundApp?.trim();
    final hasForegroundApp = foregroundApp != null && foregroundApp.isNotEmpty;
    if (script.name.trim().isEmpty) {
      errors.add('Script name is required.');
    }
    if (script.defaultIntervalMs <= 0) {
      errors.add('Default interval must be greater than 0.');
    }
    if (script.loopCount < 0) {
      errors.add('Loop count must be 0 (infinite) or greater than 0.');
    }
    if (hasForegroundApp && !_isValidPackageName(foregroundApp)) {
      errors.add('Foreground app must be a valid package name (e.g. com.example.app).');
    }
    final minBattery = script.minBatteryPct;
    if (minBattery != null && (minBattery < 0 || minBattery > 100)) {
      errors.add('Minimum battery must be between 0 and 100.');
    }
    final hasStart =
        script.timeWindowStart != null &&
        script.timeWindowStart!.trim().isNotEmpty;
    final hasEnd =
        script.timeWindowEnd != null &&
        script.timeWindowEnd!.trim().isNotEmpty;
    if (hasStart != hasEnd) {
      errors.add('Time window requires both start and end (HH:mm).');
    }
    if (hasStart &&
        hasEnd &&
        !_isValidTimeWindow(script.timeWindowStart!, script.timeWindowEnd!)) {
      errors.add('Time window must use HH:mm format and valid values.');
    }
    if (script.steps.where((step) => step.enabled).isEmpty) {
      errors.add('Add at least one enabled point.');
    }
    final invalidPoint = script.steps.any(
      (step) => step.x < 0 || step.x > 1 || step.y < 0 || step.y > 1,
    );
    if (invalidPoint) {
      errors.add('Point coordinates must be between 0 and 1.');
    }
    final invalidHold = script.steps.any((step) => step.holdMs < 0);
    if (invalidHold) {
      errors.add('Hold duration must be greater than or equal to 0.');
    }
    final invalidSwipeRange = script.steps.any((step) {
      if (step.action != 'swipe' && step.action != 'multi_touch') {
        return false;
      }
      final endX = step.x2;
      final endY = step.y2;
      return endX == null || endY == null || endX < 0 || endX > 1 || endY < 0 || endY > 1;
    });
    if (invalidSwipeRange) {
      errors.add('Swipe and multi_touch steps must include normalized x2/y2.');
    }
    final invalidSwipeDuration = script.steps.any(
      (step) =>
          (step.action == 'swipe' || step.action == 'multi_touch') &&
          step.swipeDurationMs < 1,
    );
    if (invalidSwipeDuration) {
      errors.add('Gesture duration must be greater than or equal to 1.');
    }
    final invalidAction = script.steps.any((step) {
      return step.action != 'tap' &&
          step.action != 'double_tap' &&
          step.action != 'swipe' &&
          step.action != 'multi_touch';
    });
    if (invalidAction) {
      errors.add('Step action must be tap, double_tap, swipe, or multi_touch.');
    }
    return errors;
  }

  static bool _isValidTimeWindow(String start, String end) {
    final pattern = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
    return pattern.hasMatch(start.trim()) && pattern.hasMatch(end.trim());
  }

  static bool _isValidPackageName(String value) {
    final pattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z0-9_]+)+$');
    return pattern.hasMatch(value);
  }
}
