enum RecorderState {
  idle('idle'),
  countdown('countdown'),
  recording('recording'),
  stopped('stopped');

  const RecorderState(this.value);
  final String value;

  static RecorderState fromValue(String value) {
    return RecorderState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => RecorderState.idle,
    );
  }
}
