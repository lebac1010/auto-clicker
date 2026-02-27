import 'dart:async';

import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/main.dart';
import 'package:auto_clicker/models/normal_quick_config.dart';
import 'package:auto_clicker/models/permission_state.dart';
import 'package:auto_clicker/models/run_options.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:auto_clicker/screens/script_editor_screen.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/floating_controller_service.dart';
import 'package:auto_clicker/services/normal_mode_service.dart';
import 'package:auto_clicker/services/permission_service.dart';
import 'package:auto_clicker/services/run_engine_service.dart';
import 'package:auto_clicker/services/run_execution_service.dart';
import 'package:auto_clicker/services/script_validator.dart';
import 'package:auto_clicker/widgets/accessibility_disclosure_dialog.dart';
import 'package:flutter/material.dart';

class NormalHomeScreen extends StatefulWidget {
  const NormalHomeScreen({super.key, required this.onOpenAdvanced});

  final VoidCallback onOpenAdvanced;

  @override
  State<NormalHomeScreen> createState() => _NormalHomeScreenState();
}

class _NormalHomeScreenState extends State<NormalHomeScreen>
    with WidgetsBindingObserver {
  final ScriptRepository _repository = ScriptRepository.instance;
  PermissionState _permissionState = PermissionState.fallback;
  NormalQuickConfig _config = NormalQuickConfig.defaults;
  List<ScriptModel> _scripts = <ScriptModel>[];
  bool _loading = true;
  bool _controllerRunning = false;
  String _runState = 'idle';
  StreamSubscription<Map<String, dynamic>>? _runSub;

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

  bool get _isRunActive => _runState == 'running' || _runState == 'paused';

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final permissions = await PermissionService.getPermissionState();
    final config = await NormalModeService.loadConfig();
    final scripts = await _repository.listScripts();
    final selectedScriptId = _resolveSelectedScriptId(
      config.multiTargetScriptId,
      scripts,
    );
    final resolvedConfig = config.copyWith(
      multiTargetScriptId: selectedScriptId,
    );
    if (resolvedConfig.multiTargetScriptId != config.multiTargetScriptId) {
      await NormalModeService.saveConfig(resolvedConfig);
    }
    final runState = await RunEngineService.getRunState();
    final controllerRunning = await FloatingControllerService.isRunning();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionState = permissions;
      _config = resolvedConfig;
      _scripts = scripts;
      _controllerRunning = controllerRunning;
      _runState = runState;
      _loading = false;
    });
  }

  String? _resolveSelectedScriptId(String? preferred, List<ScriptModel> scripts) {
    if (scripts.isEmpty) {
      return null;
    }
    final hasPreferred = preferred != null && scripts.any((s) => s.id == preferred);
    if (hasPreferred) {
      return preferred;
    }
    return scripts.first.id;
  }

  void _onRunEvent(Map<String, dynamic> event) {
    if (!mounted) {
      return;
    }
    final type = event['type']?.toString();
    if (type == 'state') {
      setState(() => _runState = event['state']?.toString() ?? 'idle');
      return;
    }
    if (type == 'error') {
      final message = event['message']?.toString() ?? 'Unknown run error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _saveConfig(NormalQuickConfig next) async {
    setState(() => _config = next);
    await NormalModeService.saveConfig(next);
  }

  Future<void> _openSingleTargetSettings() async {
    final intervalController = TextEditingController(
      text: _config.intervalMs.toString(),
    );
    final loopController = TextEditingController(text: _config.loopCount.toString());
    final delayController = TextEditingController(
      text: _config.startDelaySec.toString(),
    );
    final applied = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Single Target Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: intervalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Interval (ms)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: loopController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Loop count'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: delayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Start delay (sec)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (applied != true) {
      return;
    }
    final intervalMs = int.tryParse(intervalController.text.trim());
    final loopCount = int.tryParse(loopController.text.trim());
    final startDelaySec = int.tryParse(delayController.text.trim());
    if (intervalMs == null || intervalMs < 1) {
      _showMessage('Interval must be >= 1ms.');
      return;
    }
    if (loopCount == null || loopCount < 1) {
      _showMessage('Loop count must be >= 1.');
      return;
    }
    if (startDelaySec == null || startDelaySec < 0) {
      _showMessage('Start delay must be >= 0 seconds.');
      return;
    }
    await _saveConfig(
      _config.copyWith(
        intervalMs: intervalMs,
        loopCount: loopCount,
        startDelaySec: startDelaySec,
      ),
    );
    _showMessage('Settings saved.');
  }

  Future<void> _pickSingleTargetPoint() async {
    if (!await _ensureOverlayPermission()) {
      return;
    }
    final started = await FloatingControllerService.startPointPicker();
    if (!started) {
      _showMessage('Cannot open overlay point picker.');
      return;
    }
    _showMessage('Pick a point in overlay then press Confirm.');
    final event = await _awaitOverlayEvent(
      acceptedTypes: const <String>{'pick_result', 'pick_cancel', 'error'},
      timeout: const Duration(minutes: 2),
    );
    if (event == null) {
      return;
    }
    final type = event['type']?.toString();
    if (type == 'pick_cancel') {
      return;
    }
    if (type == 'error') {
      _showMessage(event['message']?.toString() ?? 'Point picker failed.');
      return;
    }
    final x = (event['x'] as num?)?.toDouble();
    final y = (event['y'] as num?)?.toDouble();
    if (x == null || y == null) {
      _showMessage('Cannot read point coordinates.');
      return;
    }
    await _saveConfig(
      _config.copyWith(
        singleTargetX: x.clamp(0, 1).toDouble(),
        singleTargetY: y.clamp(0, 1).toDouble(),
      ),
    );
    _showMessage('Target point saved.');
  }

  Future<Map<String, dynamic>?> _awaitOverlayEvent({
    required Set<String> acceptedTypes,
    required Duration timeout,
  }) async {
    final completer = Completer<Map<String, dynamic>?>();
    late final StreamSubscription<Map<String, dynamic>> subscription;
    subscription = FloatingControllerService.events().listen((event) {
      final type = event['type']?.toString() ?? '';
      if (!acceptedTypes.contains(type)) {
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(event);
      }
      subscription.cancel();
    });
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        subscription.cancel();
        return null;
      },
    );
  }

  Future<void> _runSingleTarget() async {
    if (_isRunActive) {
      _showMessage('A run is already active. Stop it before starting another one.');
      return;
    }
    if (!_config.hasSingleTargetPoint) {
      _showMessage('Pick a target point first.');
      return;
    }
    if (!await _ensureRunPermissions()) {
      return;
    }
    final script = _buildSingleTargetScript();
    final started = await RunExecutionService.instance.runWithOptions(
      script,
      RunOptions(startDelaySec: _config.startDelaySec),
    );
    if (started) {
      final overlayStarted = await FloatingControllerService.start();
      if (!overlayStarted) {
        await RunEngineService.stop();
        await _refresh();
        _showMessage(
          'Không thể mở Floating Controller, đã dừng run để đảm bảo an toàn.',
        );
        return;
      }
      await FloatingControllerService.updateRunMarkers(script);
      AnalyticsService.logEvent(
        'script_run_started',
        parameters: <String, Object?>{
          'script_id': script.id,
          'script_type': script.type.name,
          'steps_count': script.steps.length,
          'loop_mode': script.loopCount > 0 ? 'count' : 'infinite',
          'source': 'normal',
          'start_delay_sec': _config.startDelaySec,
          'stop_rule': 'none',
          'performance_mode': 'balanced',
          'screen_name': 'normal_home',
        },
      );
    }
    await _refresh();
    _showMessage(
      started
          ? 'Single target run started.'
          : (RunExecutionService.instance.lastFailureMessage ??
                'Unable to start run.'),
    );
  }

  ScriptModel _buildSingleTargetScript() {
    final now = DateTime.now();
    return ScriptModel(
      id: 'normal_single_${now.millisecondsSinceEpoch}',
      name: 'Normal Single Target',
      type: ScriptType.singleTap,
      createdAt: now,
      updatedAt: now,
      defaultIntervalMs: _config.intervalMs,
      loopCount: _config.loopCount,
      steps: [
        ScriptStep(
          id: 'normal_step_1',
          x: _config.singleTargetX!,
          y: _config.singleTargetY!,
          intervalMs: _config.intervalMs,
          enabled: true,
          holdMs: 40,
        ),
      ],
    );
  }

  Future<void> _runMultiTarget() async {
    if (_isRunActive) {
      _showMessage('A run is already active. Stop it before starting another one.');
      return;
    }
    final id = _config.multiTargetScriptId;
    if (id == null) {
      _showMessage('No script selected. Create a script first.');
      return;
    }
    if (!await _ensureRunPermissions()) {
      return;
    }
    final script = await _repository.getScript(id);
    if (script == null) {
      _showMessage('Selected script not found.');
      await _refresh();
      return;
    }
    final validation = ScriptValidator.validate(script);
    if (validation.isNotEmpty) {
      await _showInvalidScriptDialog(script, validation.first);
      return;
    }
    final started = await RunExecutionService.instance.runWithOptions(
      script,
      const RunOptions(),
    );
    if (started) {
      final overlayStarted = await FloatingControllerService.start();
      if (!overlayStarted) {
        await RunEngineService.stop();
        await _refresh();
        _showMessage(
          'Không thể mở Floating Controller, đã dừng run để đảm bảo an toàn.',
        );
        return;
      }
      await FloatingControllerService.updateRunMarkers(script);
      await _repository.markRun(script.id);
      AnalyticsService.logEvent(
        'script_run_started',
        parameters: <String, Object?>{
          'script_id': script.id,
          'script_type': script.type.name,
          'steps_count': script.steps.length,
          'loop_mode': script.loopCount > 0 ? 'count' : 'infinite',
          'source': 'normal',
          'start_delay_sec': 0,
          'stop_rule': 'none',
          'performance_mode': 'balanced',
          'screen_name': 'normal_home',
        },
      );
    }
    await _refresh();
    _showMessage(
      started
          ? 'Multi target run started.'
          : (RunExecutionService.instance.lastFailureMessage ??
                'Unable to start run.'),
    );
  }

  Future<void> _stopRun() async {
    await RunEngineService.stop();
    await _refresh();
  }

  Future<void> _toggleController() async {
    if (!_permissionState.overlayEnabled) {
      _showMessage('Overlay permission is required first.');
      return;
    }
    final wasRunning = _controllerRunning;
    final success = wasRunning
        ? await FloatingControllerService.stop()
        : await FloatingControllerService.start();
    await _refresh();
    if (!success) {
      _showMessage('Unable to change floating controller state.');
      return;
    }
    _showMessage(
      wasRunning
          ? 'Floating controller stopped.'
          : 'Floating controller started.',
    );
  }

  Future<void> _showInvalidScriptDialog(ScriptModel script, String reason) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Script is not runnable'),
        content: Text(
          'Script "${script.name}" cannot run from Normal mode.\n\nReason: $reason',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ScriptEditorScreen(scriptId: script.id),
                ),
              );
              await _refresh();
            },
            child: const Text('Open Advanced Editor'),
          ),
        ],
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
    await _showPermissionDialog(permissions);
    await _refresh();
    return false;
  }

  Future<bool> _ensureOverlayPermission() async {
    final permissions = await PermissionService.getPermissionState();
    if (permissions.overlayEnabled) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    await _showPermissionDialog(permissions);
    await _refresh();
    return false;
  }

  Future<void> _showPermissionDialog(PermissionState state) async {
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
        title: const Text('Missing required permission'),
        content: Text('Enable ${missing.join(' + ')} to continue.'),
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Normal'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh status',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PermissionCard(
                  state: _permissionState,
                  controllerRunning: _controllerRunning,
                  runState: _runState,
                  onOpenPermissions: () {
                    Navigator.of(context).pushNamed(AutoClickerApp.permissionsRoute);
                  },
                  onToggleController: _toggleController,
                  onStopRun: _runState == 'idle' ? null : _stopRun,
                ),
                const SizedBox(height: 12),
                _buildSingleTargetCard(),
                const SizedBox(height: 12),
                _buildMultiTargetCard(),
                const SizedBox(height: 12),
                _buildOtherCard(),
              ],
            ),
    );
  }

  Widget _buildSingleTargetCard() {
    final pointText = _config.hasSingleTargetPoint
        ? '(${_config.singleTargetX!.toStringAsFixed(3)}, ${_config.singleTargetY!.toStringAsFixed(3)})'
        : 'Not selected';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SINGLE TARGET MODE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text('Current point: $pointText'),
            Text('Interval: ${_config.intervalMs}ms - Loop: ${_config.loopCount}'),
            Text('Start delay: ${_config.startDelaySec}s'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openSingleTargetSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Settings'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickSingleTargetPoint,
                  icon: const Icon(Icons.my_location_outlined),
                  label: const Text('Pick Point'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isRunActive ? null : _runSingleTarget,
                child: Text(_isRunActive ? 'RUNNING' : 'START'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiTargetCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MULTI TARGET MODE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_scripts.isEmpty)
              const Text('No scripts yet. Create one in Script List.')
            else
              DropdownButtonFormField<String>(
                initialValue: _config.multiTargetScriptId,
                decoration: const InputDecoration(labelText: 'Script'),
                items: _scripts
                    .map(
                      (script) => DropdownMenuItem<String>(
                        value: script.id,
                        child: Text(script.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  _saveConfig(_config.copyWith(multiTargetScriptId: value));
                },
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AutoClickerApp.scriptListRoute);
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Settings'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AutoClickerApp.helpRoute);
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Guide'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AutoClickerApp.scriptListRoute);
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text('Manage Scripts'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _scripts.isEmpty || _isRunActive ? null : _runMultiTarget,
                child: Text(_isRunActive ? 'RUNNING' : 'START'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OTHER',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings),
              title: const Text('General Settings'),
              onTap: () {
                Navigator.of(context).pushNamed(AutoClickerApp.settingsRoute);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: const Text('Troubleshooting'),
              onTap: () {
                Navigator.of(context).pushNamed(AutoClickerApp.helpRoute);
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onOpenAdvanced,
                child: const Text('Open Advanced'),
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
    required this.state,
    required this.controllerRunning,
    required this.runState,
    required this.onOpenPermissions,
    required this.onToggleController,
    required this.onStopRun,
  });

  final PermissionState state;
  final bool controllerRunning;
  final String runState;
  final VoidCallback onOpenPermissions;
  final VoidCallback onToggleController;
  final VoidCallback? onStopRun;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(label: 'Accessibility', enabled: state.accessibilityEnabled),
                _StatusChip(label: 'Overlay', enabled: state.overlayEnabled),
                _StatusChip(label: 'Exact Alarm', enabled: state.exactAlarmAllowed),
                _StatusChip(label: 'Controller', enabled: controllerRunning),
                _StatusChip(label: 'Run', enabled: runState == 'running'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Run state: $runState'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onOpenPermissions,
                  child: const Text('Open Permissions'),
                ),
                OutlinedButton(
                  onPressed: onToggleController,
                  child: Text(
                    controllerRunning ? 'Stop Controller' : 'Start Controller',
                  ),
                ),
                OutlinedButton(
                  onPressed: onStopRun,
                  child: const Text('Stop Now'),
                ),
              ],
            ),
          ],
        ),
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
