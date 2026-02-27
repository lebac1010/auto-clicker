import 'package:auto_clicker/main.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/onboarding_service.dart';
import 'package:auto_clicker/services/permission_service.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.logEvent(
      'app_opened',
      parameters: const <String, Object?>{
        'launch_type': 'cold',
        'screen_name': 'splash',
      },
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final bool onboardingDone = await OnboardingService.isCompleted();
    final permissions = await PermissionService.getPermissionState();

    if (!mounted) {
      return;
    }

    final String route = !onboardingDone
        ? AutoClickerApp.onboardingRoute
        : permissions.hasCorePermissions
        ? AutoClickerApp.homeRoute
        : AutoClickerApp.permissionsRoute;

    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 64),
            SizedBox(height: 12),
            Text(
              'TapMacro',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
