import 'package:auto_clicker/config/feature_flags.dart';
import 'package:auto_clicker/main.dart';
import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/permission_state.dart';
import 'package:auto_clicker/models/run_options.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:auto_clicker/screens/run_options_screen.dart';
import 'package:auto_clicker/screens/script_editor_screen.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/floating_controller_service.dart';
import 'package:auto_clicker/services/permission_service.dart';
import 'package:auto_clicker/services/run_execution_service.dart';
import 'package:auto_clicker/services/run_engine_service.dart';
import 'package:auto_clicker/widgets/accessibility_disclosure_dialog.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AdvancedHomeScreen extends StatefulWidget {
  const AdvancedHomeScreen({super.key});

  @override
  State<AdvancedHomeScreen> createState() => _AdvancedHomeScreenState();
}

class _AdvancedHomeScreenState extends State<AdvancedHomeScreen>
    with WidgetsBindingObserver {
  PermissionState _permissionState = PermissionState.fallback;
  final ScriptRepository _repository = ScriptRepository.instance;
  List<ScriptModel> _recentScripts = <ScriptModel>[];
  bool _controllerRunning = false;
  String _runState = 'idle';
  int _currentStep = 0;
  int _currentLoop = 0;
  int _elapsedMs = 0;
  int _lastProgressUiUpdateAtMs = 0;
  int _lastProgressStep = -1;
  int _lastProgressLoop = -1;
  StreamSubscription<Map<String, dynamic>>? _runSub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runSub = RunEngineService.events().listen(_onRunEvent);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _runSub?.cancel();
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
    final state = await PermissionService.getPermissionState();
    final recent = await _repository.recentScripts();
    final running = await FloatingControllerService.isRunning();
    final runState = await RunEngineService.getRunState();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionState = state;
      _recentScripts = recent;
      _controllerRunning = running;
      _runState = runState;
      _loading = false;
    });
  }

  Future<void> _createQuickScript() async {
    final created = await _repository.createScript(
      name: 'Quick Script ${DateTime.now().millisecondsSinceEpoch}',
      type: ScriptType.multiTap,
    );
    AnalyticsService.logEvent(
      'script_created',
      parameters: <String, Object?>{
        'script_id': created.id,
        'script_type': created.type.name,
        'steps_count': created.steps.length,
        'screen_name': 'home',
      },
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScriptEditorScreen(scriptId: created.id),
      ),
    );
    await _refresh();
  }

  Future<void> _runScript(String id) async {
    if (!await _ensureRunPermissions()) {
      return;
    }
    final script = await _repository.getScript(id);
    if (script == null) {
      return;
    }
    final runOptions = await _openRunOptions(script);
    if (runOptions == null) {
      return;
    }
    await FloatingControllerService.start();
    final started = await RunExecutionService.instance.runWithOptions(
      script,
      runOptions,
    );
    if (started) {
      await _repository.markRun(id);
      AnalyticsService.logEvent(
        'script_run_started',
        parameters: <String, Object?>{
          'script_id': script.id,
          'script_type': script.type.name,
          'steps_count': script.steps.length,
          'loop_mode': script.loopCount > 0 ? 'count' : 'infinite',
          'source': 'home',
          'start_delay_sec': runOptions.startDelaySec,
          'stop_rule': runOptions.stopRule.name,
          'performance_mode': runOptions.performanceMode.name,
          'screen_name': 'home',
        },
      );
    }
    await _refresh();
    if (!mounted) {
      return;
    }
    final failureMessage = RunExecutionService.instance.lastFailureMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          started ? 'Run started' : (failureMessage ?? 'Unable to start run'),
        ),
      ),
    );
  }

  Future<RunOptions?> _openRunOptions(ScriptModel script) {
    return Navigator.of(context).push<RunOptions>(
      MaterialPageRoute<RunOptions>(
        builder: (_) => RunOptionsScreen(scriptName: script.name),
      ),
    );
  }

  Future<bool> _ensureRunPermissions() async {
    final permissions = await PermissionService.getPermissionState();
    if (permissions.hasCorePermissions) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    await _showRunPermissionDialog(permissions);
    await _refresh();
    return false;
  }

  Future<void> _showRunPermissionDialog(PermissionState state) async {
    final missing = <String>[];
    if (!state.accessibilityEnabled) {
      missing.add('Accessibility');
    }
    if (!state.overlayEnabled) {
      missing.add('Overlay');
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Text('Enable ${missing.join(' + ')} before running scripts.'),
        actions: [
          if (!state.accessibilityEnabled)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final accepted = await AccessibilityDisclosureDialog.confirm(
                  context,
                );
                if (!accepted) {
                  return;
                }
                await PermissionService.requestAccessibility();
              },
              child: const Text('Enable Accessibility'),
            ),
          if (!state.overlayEnabled)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await PermissionService.requestOverlay();
              },
              child: const Text('Enable Overlay'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleController() async {
    final wasRunning = _controllerRunning;
    if (!_permissionState.overlayEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Overlay permission is required first.')),
      );
      return;
    }
    final success = wasRunning
        ? await FloatingControllerService.stop()
        : await FloatingControllerService.start();
    await _refresh();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (wasRunning
                    ? 'Floating controller stopped'
                    : 'Floating controller started')
              : 'Unable to control floating overlay',
        ),
      ),
    );
  }

  Future<void> _pauseRun() async {
    await RunEngineService.pause();
    await _refresh();
  }

  Future<void> _resumeRun() async {
    await RunEngineService.resume();
    await _refresh();
  }

  Future<void> _stopRun() async {
    await RunEngineService.stop();
    await _refresh();
  }

  void _onRunEvent(Map<String, dynamic> event) {
    if (!mounted) {
      return;
    }
    final type = event['type']?.toString();
    if (type == 'state') {
      final nextState = event['state']?.toString() ?? 'idle';
      setState(() {
        _runState = nextState;
        if (nextState == 'idle') {
          _lastProgressUiUpdateAtMs = 0;
          _lastProgressStep = -1;
          _lastProgressLoop = -1;
        }
      });
      return;
    }
    if (type == 'runProgress') {
      final nextStep = ((event['stepIndex'] as num?)?.toInt() ?? 0) + 1;
      final nextLoop = (event['loopCount'] as num?)?.toInt() ?? 0;
      final nextElapsed = (event['elapsedMs'] as num?)?.toInt() ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final shouldSkipUiUpdate =
          nextStep == _lastProgressStep &&
          nextLoop == _lastProgressLoop &&
          nowMs - _lastProgressUiUpdateAtMs < 250;
      if (shouldSkipUiUpdate) {
        return;
      }
      setState(() {
        _runState = event['state']?.toString() ?? _runState;
        _currentStep = nextStep;
        _currentLoop = nextLoop;
        _elapsedMs = nextElapsed;
      });
      _lastProgressUiUpdateAtMs = nowMs;
      _lastProgressStep = nextStep;
      _lastProgressLoop = nextLoop;
      return;
    }
    if (type == 'error') {
      final message = event['message']?.toString() ?? 'Unknown run error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AutoClickerApp.settingsRoute);
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Open settings',
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'TapMacro Dashboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: 'Accessibility',
                      enabled: _permissionState.accessibilityEnabled,
                    ),
                    _StatusChip(
                      label: 'Overlay',
                      enabled: _permissionState.overlayEnabled,
                    ),
                    _StatusChip(
                      label: 'Notifications',
                      enabled: _permissionState.notificationsEnabled,
                    ),
                    _StatusChip(
                      label: 'Battery',
                      enabled: _permissionState.batteryOptimizationIgnored,
                    ),
                    _StatusChip(
                      label: 'Exact Alarm',
                      enabled: _permissionState.exactAlarmAllowed,
                    ),
                    _StatusChip(label: 'Run', enabled: _runState == 'running'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'State: $_runState - Step: $_currentStep - Loop: $_currentLoop - Elapsed: ${_elapsedMs}ms',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _permissionState.hasCorePermissions
                        ? _toggleController
                        : null,
                    child: Text(
                      _controllerRunning
                          ? 'Stop Floating Controller'
                          : 'Start Floating Controller',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _runState == 'running' ? _pauseRun : null,
                        child: const Text('Pause Run'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _runState == 'paused' ? _resumeRun : null,
                        child: const Text('Resume Run'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _runState != 'idle' ? _stopRun : null,
                        child: const Text('Stop Run'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamed(AutoClickerApp.scriptListRoute);
                    },
                    child: const Text('Open Script List'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AutoClickerApp.schedulerRoute);
                    },
                    child: const Text('Open Scheduler'),
                  ),
                ),
                if (FeatureFlags.recorderEnabled) const SizedBox(height: 10),
                if (FeatureFlags.recorderEnabled)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AutoClickerApp.recorderRoute);
                      },
                      child: const Text('Open Recorder'),
                    ),
                  ),
                if (FeatureFlags.dualFormatImportExportEnabled)
                  const SizedBox(height: 10),
                if (FeatureFlags.dualFormatImportExportEnabled)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AutoClickerApp.importExportRoute);
                      },
                      child: const Text('Import / Export'),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _createQuickScript,
                    child: const Text('Create New Script'),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Recent Scripts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_recentScripts.isEmpty)
                  const Text('No scripts yet.')
                else
                  ..._recentScripts.map(
                    (script) => Card(
                      child: ListTile(
                        title: Text(script.name),
                        subtitle: Text(script.type.label),
                        trailing: TextButton(
                          onPressed: () => _runScript(script.id),
                          child: const Text('Run'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: ${enabled ? 'ON' : 'OFF'}'),
      backgroundColor: enabled
          ? const Color(0xFFE5F4EF)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      side: BorderSide(
        color: enabled ? const Color(0xFF106B5A) : Colors.transparent,
      ),
    );
  }
}
