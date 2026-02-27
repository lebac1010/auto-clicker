import 'package:flutter/services.dart';

abstract class SchedulerGateway {
  const SchedulerGateway();

  Future<void> start();

  Future<void> reschedule();

  Future<void> stop();
}

class MethodChannelSchedulerGateway extends SchedulerGateway {
  const MethodChannelSchedulerGateway();

  static const MethodChannel _controllerChannel = MethodChannel(
    'com.auto_clicker/controller',
  );

  @override
  Future<void> start() async {
    await _controllerChannel.invokeMethod<bool>('startScheduler');
  }

  @override
  Future<void> reschedule() async {
    await _controllerChannel.invokeMethod<bool>('rescheduleScheduler');
  }

  @override
  Future<void> stop() async {
    await _controllerChannel.invokeMethod<bool>('stopScheduler');
  }
}

class SchedulerService {
  SchedulerService({
    SchedulerGateway? gateway,
  }) : _gateway = gateway ?? const MethodChannelSchedulerGateway();

  static final SchedulerService instance = SchedulerService();
  final SchedulerGateway _gateway;

  Future<void> start() async {
    try {
      await _gateway.start();
    } catch (_) {
      // Keep app usable even if scheduler backend is unavailable.
    }
  }

  Future<void> reschedule() async {
    try {
      await _gateway.reschedule();
    } catch (_) {
      // Keep app usable even if scheduler backend is unavailable.
    }
  }

  Future<void> stop() async {
    try {
      await _gateway.stop();
    } catch (_) {
      // Keep app usable even if scheduler backend is unavailable.
    }
  }
}
