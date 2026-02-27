import 'package:auto_clicker/screens/help_screen.dart';
import 'package:auto_clicker/screens/home_shell_screen.dart';
import 'package:auto_clicker/screens/import_export_screen.dart';
import 'package:auto_clicker/screens/onboarding_screen.dart';
import 'package:auto_clicker/screens/permissions_hub_screen.dart';
import 'package:auto_clicker/screens/privacy_policy_screen.dart';
import 'package:auto_clicker/screens/recorder_screen.dart';
import 'package:auto_clicker/screens/settings_screen.dart';
import 'package:auto_clicker/screens/script_list_screen.dart';
import 'package:auto_clicker/screens/splash_screen.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/app_lifecycle_analytics_service.dart';
import 'package:auto_clicker/services/run_telemetry_service.dart';
import 'package:auto_clicker/services/scheduler_service.dart';
import 'package:auto_clicker/screens/scheduler_screen.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AnalyticsService.initialize();
  AppLifecycleAnalyticsService.instance.start();
  RunTelemetryService.instance.start();
  await SchedulerService.instance.start();
  runApp(const AutoClickerApp());
}

class AutoClickerApp extends StatelessWidget {
  const AutoClickerApp({super.key});

  static const String splashRoute = '/';
  static const String onboardingRoute = '/onboarding';
  static const String permissionsRoute = '/permissions';
  static const String homeRoute = '/home';
  static const String scriptListRoute = '/scripts';
  static const String recorderRoute = '/recorder';
  static const String schedulerRoute = '/scheduler';
  static const String importExportRoute = '/import-export';
  static const String settingsRoute = '/settings';
  static const String helpRoute = '/help';
  static const String privacyPolicyRoute = '/privacy-policy';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapMacro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF106B5A)),
        useMaterial3: true,
      ),
      initialRoute: splashRoute,
      routes: {
        splashRoute: (_) => const SplashScreen(),
        onboardingRoute: (_) => const OnboardingScreen(),
        permissionsRoute: (_) => const PermissionsHubScreen(),
        homeRoute: (_) => const HomeShellScreen(),
        scriptListRoute: (_) => const ScriptListScreen(),
        recorderRoute: (_) => const RecorderScreen(),
        schedulerRoute: (_) => const SchedulerScreen(),
        importExportRoute: (_) => const ImportExportScreen(),
        settingsRoute: (_) => const SettingsScreen(),
        helpRoute: (_) => const HelpScreen(),
        privacyPolicyRoute: (_) => const PrivacyPolicyScreen(),
      },
    );
  }
}
