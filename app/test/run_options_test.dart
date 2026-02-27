import 'package:auto_clicker/models/run_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates loop stop rule', () {
    const options = RunOptions(
      stopRule: RunStopRule.loops,
      stopAfterLoops: 0,
    );
    final errors = options.validate();
    expect(errors, isNotEmpty);
  });

  test('validates duration stop rule', () {
    const options = RunOptions(
      stopRule: RunStopRule.duration,
      stopAfterDurationSec: 0,
    );
    final errors = options.validate();
    expect(errors, isNotEmpty);
  });

  test('accepts balanced defaults', () {
    const options = RunOptions.defaults;
    final errors = options.validate();
    expect(errors, isEmpty);
  });
}
