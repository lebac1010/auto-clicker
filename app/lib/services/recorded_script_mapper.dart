import 'package:auto_clicker/models/recorded_step.dart';
import 'package:auto_clicker/models/script_step.dart';

class RecordedScriptMapper {
  const RecordedScriptMapper._();

  static const Set<String> _supportedActions = <String>{
    'tap',
    'double_tap',
    'swipe',
    'multi_touch',
  };

  static List<ScriptStep> toScriptSteps(
    List<RecordedStep> steps, {
    int zeroDelayFallbackMs = 80,
    String Function(int index)? idGenerator,
  }) {
    final base = DateTime.now().microsecondsSinceEpoch;
    return List<ScriptStep>.generate(steps.length, (index) {
      final step = steps[index];
      final action = _supportedActions.contains(step.action)
          ? step.action
          : 'tap';
      return ScriptStep(
        id: idGenerator?.call(index + 1) ?? 'step_${base}_${index + 1}',
        action: action,
        x: step.x,
        y: step.y,
        x2: action == 'swipe' || action == 'multi_touch'
            ? (step.x2 ?? step.x)
            : null,
        y2: action == 'swipe' || action == 'multi_touch'
            ? (step.y2 ?? step.y)
            : null,
        intervalMs: step.delayMs <= 0 ? zeroDelayFallbackMs : step.delayMs,
        holdMs: step.holdMs < 0 ? 0 : step.holdMs,
        swipeDurationMs: step.swipeDurationMs < 1 ? 1 : step.swipeDurationMs,
        enabled: step.enabled,
      );
    });
  }
}
