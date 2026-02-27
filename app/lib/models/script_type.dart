enum ScriptType {
  singleTap('single_tap', 'Single Tap'),
  multiTap('multi_tap', 'Multi Tap'),
  swipe('swipe', 'Swipe'),
  macro('macro', 'Macro');

  const ScriptType(this.value, this.label);

  final String value;
  final String label;

  static ScriptType fromValue(String value) {
    return ScriptType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ScriptType.multiTap,
    );
  }
}
