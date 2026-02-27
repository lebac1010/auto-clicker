import 'package:auto_clicker/main.dart';
import 'package:auto_clicker/services/permission_service.dart';
import 'package:auto_clicker/services/run_engine_service.dart';
import 'package:auto_clicker/services/settings_service.dart';
import 'package:auto_clicker/services/support_log_service.dart';
import 'package:auto_clicker/widgets/accessibility_disclosure_dialog.dart';
import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  bool _exporting = false;
  String _status = '';

  Future<void> _exportLogs() async {
    if (_exporting) {
      return;
    }
    setState(() {
      _exporting = true;
      _status = '';
    });
    try {
      final permissions = await PermissionService.getPermissionState();
      final runState = await RunEngineService.getRunState();
      final volumeKeyStopEnabled = await SettingsService.getVolumeKeyStopEnabled();
      final path = await SupportLogService.exportLogs(
        metadata: <String, Object?>{
          'accessibility_enabled': permissions.accessibilityEnabled,
          'overlay_enabled': permissions.overlayEnabled,
          'notifications_enabled': permissions.notificationsEnabled,
          'battery_optimization_ignored': permissions.batteryOptimizationIgnored,
          'exact_alarm_allowed': permissions.exactAlarmAllowed,
          'run_state': runState,
          'volume_key_stop_enabled': volumeKeyStopEnabled,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Logs exported: $path');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support logs exported successfully.')),
      );
    } catch (error, stackTrace) {
      SupportLogService.logError(
        'help_screen',
        'Failed to export support logs',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Export failed: $error');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Troubleshooting')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              title: Text('Run does not start'),
              subtitle: Text(
                'Check Accessibility and Overlay permissions. '
                'Disable battery optimization for stability.',
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: ListTile(
              title: Text('Recorder misses taps'),
              subtitle: Text(
                'Some apps or OEM builds restrict events. '
                'Try recording on a simpler screen and edit timeline manually.',
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: ListTile(
              title: Text('Service stops unexpectedly'),
              subtitle: Text(
                'Re-enable Accessibility service and keep the app unrestricted in battery settings.',
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: ListTile(
              title: Text('OEM Guides'),
              subtitle: Text(
                'Xiaomi/MIUI: set app to No restrictions and lock in Recents.\n'
                'Samsung: set Battery to Unrestricted and allow pop-up windows.\n'
                'Oppo/Vivo: allow Auto-start and Background activity.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final accepted = await AccessibilityDisclosureDialog.confirm(
                context,
              );
              if (!accepted) {
                return;
              }
              await PermissionService.requestAccessibility();
            },
            icon: const Icon(Icons.accessibility_new),
            label: const Text('Open Accessibility Settings'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => PermissionService.requestOverlay(),
            icon: const Icon(Icons.layers_outlined),
            label: const Text('Open Overlay Settings'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => PermissionService.requestBatteryOptimizationIgnore(),
            icon: const Icon(Icons.battery_charging_full),
            label: const Text('Open Battery Optimization Settings'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => PermissionService.requestExactAlarm(),
            icon: const Icon(Icons.schedule),
            label: const Text('Open Exact Alarm Settings'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(AutoClickerApp.privacyPolicyRoute);
            },
            icon: const Icon(Icons.privacy_tip_outlined),
            label: const Text('Open Privacy Policy'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportLogs,
            icon: const Icon(Icons.download_outlined),
            label: Text(_exporting ? 'Exporting...' : 'Export Support Logs'),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_status),
          ],
        ],
      ),
    );
  }
}
