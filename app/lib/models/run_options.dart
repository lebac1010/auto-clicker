enum RunStopRule {
  none,
  loops,
  duration,
}

enum RunPerformanceMode {
  balanced,
  fast,
}

class RunOptions {
  const RunOptions({
    this.startDelaySec = 0,
    this.stopRule = RunStopRule.none,
    this.stopAfterLoops,
    this.stopAfterDurationSec,
    this.performanceMode = RunPerformanceMode.balanced,
  });

  final int startDelaySec;
  final RunStopRule stopRule;
  final int? stopAfterLoops;
  final int? stopAfterDurationSec;
  final RunPerformanceMode performanceMode;

  static const RunOptions defaults = RunOptions();

  RunOptions copyWith({
    int? startDelaySec,
    RunStopRule? stopRule,
    Object? stopAfterLoops = _runOptionsNoChange,
    Object? stopAfterDurationSec = _runOptionsNoChange,
    RunPerformanceMode? performanceMode,
  }) {
    return RunOptions(
      startDelaySec: startDelaySec ?? this.startDelaySec,
      stopRule: stopRule ?? this.stopRule,
      stopAfterLoops: identical(stopAfterLoops, _runOptionsNoChange)
          ? this.stopAfterLoops
          : stopAfterLoops as int?,
      stopAfterDurationSec: identical(stopAfterDurationSec, _runOptionsNoChange)
          ? this.stopAfterDurationSec
          : stopAfterDurationSec as int?,
      performanceMode: performanceMode ?? this.performanceMode,
    );
  }

  List<String> validate() {
    final errors = <String>[];
    if (startDelaySec < 0) {
      errors.add('Start delay must be greater than or equal to 0.');
    }
    if (stopRule == RunStopRule.loops) {
      final loops = stopAfterLoops;
      if (loops == null || loops < 1) {
        errors.add('Stop-after loops must be greater than or equal to 1.');
      }
    }
    if (stopRule == RunStopRule.duration) {
      final duration = stopAfterDurationSec;
      if (duration == null || duration < 1) {
        errors.add('Stop-after duration must be greater than or equal to 1 second.');
      }
    }
    return errors;
  }
}

const Object _runOptionsNoChange = Object();
