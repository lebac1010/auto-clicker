import 'package:auto_clicker/services/analytics_service.dart';
import 'package:flutter/widgets.dart';

class AppLifecycleAnalyticsService with WidgetsBindingObserver {
  AppLifecycleAnalyticsService._();

  static final AppLifecycleAnalyticsService instance = AppLifecycleAnalyticsService._();
  bool _started = false;
  bool _wasBackgrounded = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    if (!_started) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _wasBackgrounded = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_wasBackgrounded) {
        AnalyticsService.logEvent(
          'app_opened',
          parameters: const <String, Object?>{
            'launch_type': 'warm',
            'screen_name': 'home',
          },
        );
      }
      _wasBackgrounded = false;
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    }
  }
}
