import 'package:auto_clicker/main.dart';
import 'package:auto_clicker/models/permission_state.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/permission_service.dart';
import 'package:auto_clicker/widgets/accessibility_disclosure_dialog.dart';
import 'package:flutter/material.dart';

class PermissionsHubScreen extends StatefulWidget {
  const PermissionsHubScreen({super.key});

  @override
  State<PermissionsHubScreen> createState() => _PermissionsHubScreenState();
}

class _PermissionsHubScreenState extends State<PermissionsHubScreen>
    with WidgetsBindingObserver {
  PermissionState _state = PermissionState.fallback;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final permissions = await PermissionService.getPermissionState();
    _trackPermissionChanges(_state, permissions);
    if (!mounted) {
      return;
    }
    setState(() {
      _state = permissions;
      _loading = false;
    });
  }

  Future<void> _goHome() async {
    await _refresh();
    if (!mounted) {
      return;
    }
    if (_state.hasCorePermissions) {
      Navigator.of(context).pushReplacementNamed(AutoClickerApp.homeRoute);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enable Accessibility and Overlay before continuing.'),
      ),
    );
  }

  void _trackPermissionChanges(
    PermissionState previous,
    PermissionState current,
  ) {
    if (!previous.accessibilityEnabled && current.accessibilityEnabled) {
      AnalyticsService.logEvent(
        'permission_accessibility_enabled',
        parameters: const <String, Object?>{
          'from_screen': 'permissions_hub',
          'screen_name': 'permissions_hub',
        },
      );
    }
    if (!previous.overlayEnabled && current.overlayEnabled) {
      AnalyticsService.logEvent(
        'permission_overlay_enabled',
        parameters: const <String, Object?>{
          'from_screen': 'permissions_hub',
          'screen_name': 'permissions_hub',
        },
      );
    }
  }

  void _showTroubleshoot() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Troubleshoot Accessibility'),
        content: const Text(
          'If the app does not appear in Accessibility Settings, restart the app, '
          'reopen Settings, and check if another security app is blocking access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PermissionCard(
                    title: 'Accessibility Service',
                    enabled: _state.accessibilityEnabled,
                    actionLabel: 'Enable',
                    onTap: () async {
                      final accepted =
                          await AccessibilityDisclosureDialog.confirm(context);
                      if (!accepted) {
                        return;
                      }
                      await PermissionService.requestAccessibility();
                      await _refresh();
                    },
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    title: 'Draw over other apps',
                    enabled: _state.overlayEnabled,
                    actionLabel: 'Allow',
                    onTap: () async {
                      await PermissionService.requestOverlay();
                      await _refresh();
                    },
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    title: 'Ignore Battery Optimization',
                    enabled: _state.batteryOptimizationIgnored,
                    actionLabel: 'Allow',
                    onTap: () async {
                      await PermissionService.requestBatteryOptimizationIgnore();
                      await _refresh();
                    },
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    title: 'Notifications',
                    enabled: _state.notificationsEnabled,
                    actionLabel: 'Allow',
                    onTap: () async {
                      await PermissionService.requestNotifications();
                      await _refresh();
                    },
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    title: 'Exact Alarm (recommended)',
                    enabled: _state.exactAlarmAllowed,
                    actionLabel: 'Allow',
                    onTap: () async {
                      await PermissionService.requestExactAlarm();
                      await _refresh();
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _showTroubleshoot,
                      child: const Text(
                        'Troubleshoot: app not visible in Accessibility?',
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _state.hasCorePermissions ? _goHome : null,
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.title,
    required this.enabled,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final bool enabled;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(enabled ? 'Status: ON' : 'Status: OFF'),
                ],
              ),
            ),
            OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
