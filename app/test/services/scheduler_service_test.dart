import 'package:auto_clicker/services/scheduler_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSchedulerGateway extends SchedulerGateway {
  bool throwOnStart = false;
  bool throwOnReschedule = false;
  bool throwOnStop = false;
  int startCalls = 0;
  int rescheduleCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> start() async {
    startCalls += 1;
    if (throwOnStart) {
      throw Exception('start failed');
    }
  }

  @override
  Future<void> reschedule() async {
    rescheduleCalls += 1;
    if (throwOnReschedule) {
      throw Exception('reschedule failed');
    }
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (throwOnStop) {
      throw Exception('stop failed');
    }
  }
}

void main() {
  test('delegates start/reschedule/stop to gateway', () async {
    final gateway = _FakeSchedulerGateway();
    final service = SchedulerService(gateway: gateway);

    await service.start();
    await service.reschedule();
    await service.stop();

    expect(gateway.startCalls, 1);
    expect(gateway.rescheduleCalls, 1);
    expect(gateway.stopCalls, 1);
  });

  test('swallows gateway exceptions to keep app flow alive', () async {
    final gateway = _FakeSchedulerGateway()
      ..throwOnStart = true
      ..throwOnReschedule = true
      ..throwOnStop = true;
    final service = SchedulerService(gateway: gateway);

    await service.start();
    await service.reschedule();
    await service.stop();

    expect(gateway.startCalls, 1);
    expect(gateway.rescheduleCalls, 1);
    expect(gateway.stopCalls, 1);
  });
}
