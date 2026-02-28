import 'dart:async';

import 'package:auto_clicker/main.dart';
import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/normal_quick_config.dart';
import 'package:auto_clicker/models/permission_state.dart';
import 'package:auto_clicker/models/run_options.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';
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
  static const int _minSafeStartDelaySec = 2;
  final ScriptRepository _repository = ScriptRepository.instance;

  PermissionState _permissionState = PermissionState.fallback;
  NormalQuickConfig _config = NormalQuickConfig.defaults;
  List<ScriptModel> _scripts = <ScriptModel>[];
  bool _controllerRunning = false;
  bool _loading = true;
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

  bool get _isRunning => _runState == 'running';
  bool get _isPaused => _runState == 'paused';
  bool get _isRunActive => _isRunning || _isPaused;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final permissions = await PermissionService.getPermissionState();
    final config = await NormalModeService.loadConfig();
    final scripts = await _repository.listScripts();
    final selectedScriptId = _resolveSelectedScriptId(
      config.multiTargetScriptId,
      scripts,
    );
    final resolvedConfig = config.copyWith(multiTargetScriptId: selectedScriptId);
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
    if (preferred != null && scripts.any((script) => script.id == preferred)) {
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
    if (type == 'runStopped') {
      final stopReason = event['stopReason']?.toString();
      if (stopReason == 'loop_completed') {
        final completedLoops =
            (event['completedLoops'] as num?)?.toInt() ?? _config.loopCount;
        if (completedLoops > 0) {
          _showMessage(
            'Auto-stopped: completed $completedLoops loops. Press Start to run again.',
          );
        } else {
          _showMessage('Run completed. Press Start to run again.');
        }
      }
      return;
    }
    if (type == 'error') {
      final message = event['message']?.toString() ?? 'Unknown run error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    final loopController = TextEditingController(
      text: _config.loopCount.toString(),
    );
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
              decoration: const InputDecoration(
                labelText: 'Loop count (0 = infinite)',
              ),
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
    if (loopCount == null || loopCount < 0) {
      _showMessage('Loop count must be >= 0 (0 = infinite).');
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
      _showMessage(
        'A run is already active. Stop it before starting another one.',
      );
      return;
    }
    if (!_config.hasSingleTargetPoint) {
      _showMessage('Pick a target point first.');
      return;
    }
    if (!await _ensureRunPermissions()) {
      return;
    }
    final safeStartDelaySec = _config.startDelaySec < _minSafeStartDelaySec
        ? _minSafeStartDelaySec
        : _config.startDelaySec;
    if (safeStartDelaySec != _config.startDelaySec) {
      _showMessage(
        'Applying safe start delay of ${_minSafeStartDelaySec}s to prevent accidental touches.',
      );
    }
    final script = _buildSingleTargetScript();
    final started = await RunExecutionService.instance.runWithOptions(
      script,
      RunOptions(startDelaySec: safeStartDelaySec),
    );
    if (started) {
      final overlayStarted = await FloatingControllerService.start();
      if (!overlayStarted) {
        await RunEngineService.stop();
        await _refresh();
        _showMessage(
          'Could not open Floating Controller. Run stopped for safety.',
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
          'start_delay_sec': safeStartDelaySec,
          'stop_rule': 'none',
          'performance_mode': 'balanced',
          'screen_name': 'normal_home',
        },
      );
    }
    await _refresh();
    final failureCode = RunExecutionService.instance.lastFailureCode;
    if (!started && failureCode == 'RUN_START_SUPERSEDED') {
      return;
    }
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

  String get _multiTargetLabel {
    final selectedId = _config.multiTargetScriptId;
    if (selectedId == null) {
      return 'No script selected';
    }
    final selected = _scripts.where((script) => script.id == selectedId);
    if (selected.isEmpty) {
      return 'No script selected';
    }
    return selected.first.name;
  }

  Future<void> _openMultiTargetSelector() async {
    if (_scripts.isEmpty) {
      _showMessage('No scripts available. Create one in Advanced mode.');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView.builder(
          itemCount: _scripts.length,
          itemBuilder: (_, index) {
            final script = _scripts[index];
            final isSelected = script.id == _config.multiTargetScriptId;
            return ListTile(
              title: Text(script.name),
              subtitle: Text(script.type.label),
              trailing: isSelected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(script.id),
            );
          },
        ),
      ),
    );
    if (selected == null || selected == _config.multiTargetScriptId) {
      return;
    }
    await _saveConfig(_config.copyWith(multiTargetScriptId: selected));
  }

  Future<void> _runMultiTarget() async {
    if (_isRunActive) {
      _showMessage(
        'A run is already active. Stop it before starting another one.',
      );
      return;
    }
    final selectedId = _config.multiTargetScriptId;
    if (selectedId == null) {
      _showMessage('Select a script first.');
      return;
    }
    if (!await _ensureRunPermissions()) {
      return;
    }
    final script = await _repository.getScript(selectedId);
    if (script == null) {
      _showMessage('Selected script not found.');
      await _refresh();
      return;
    }
    final validationErrors = ScriptValidator.validate(script);
    if (validationErrors.isNotEmpty) {
      _showMessage(validationErrors.first);
      return;
    }
    final safeStartDelaySec = _config.startDelaySec < _minSafeStartDelaySec
        ? _minSafeStartDelaySec
        : _config.startDelaySec;
    if (safeStartDelaySec != _config.startDelaySec) {
      _showMessage(
        'Applying safe start delay of ${_minSafeStartDelaySec}s to prevent accidental touches.',
      );
    }
    final started = await RunExecutionService.instance.runWithOptions(
      script,
      RunOptions(startDelaySec: safeStartDelaySec),
    );
    if (started) {
      final overlayStarted = await FloatingControllerService.start();
      if (!overlayStarted) {
        await RunEngineService.stop();
        await _refresh();
        _showMessage(
          'Could not open Floating Controller. Run stopped for safety.',
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
          'start_delay_sec': safeStartDelaySec,
          'stop_rule': 'none',
          'performance_mode': 'balanced',
          'screen_name': 'normal_home',
        },
      );
    }
    await _refresh();
    final failureCode = RunExecutionService.instance.lastFailureCode;
    if (!started && failureCode == 'RUN_START_SUPERSEDED') {
      return;
    }
    _showMessage(
      started
          ? 'Multi target run started.'
          : (RunExecutionService.instance.lastFailureMessage ??
                'Unable to start run.'),
    );
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

  Future<void> _stopRun() async {
    await RunEngineService.stop();
    await _refresh();
  }

  Future<void> _resumeRunFromNormal() async {
    if (!_isPaused) {
      return;
    }
    if (!await _ensureRunPermissions()) {
      return;
    }
    final resumed = await RunEngineService.resume();
    if (!resumed) {
      await _refresh();
      _showMessage('Unable to resume run.');
      return;
    }
    final overlayStarted = await FloatingControllerService.start();
    if (!overlayStarted) {
      await RunEngineService.stop();
      await _refresh();
      _showMessage(
        'Could not open Floating Controller. Run stopped for safety.',
      );
      return;
    }
    await _refresh();
    _showMessage('Run resumed.');
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final needsPermissions = !_permissionState.hasCorePermissions;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TapMacro'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.of(context).pushNamed(AutoClickerApp.settingsRoute);
                  break;
                case 'permissions':
                  Navigator.of(
                    context,
                  ).pushNamed(AutoClickerApp.permissionsRoute);
                  break;
                case 'help':
                  Navigator.of(context).pushNamed(AutoClickerApp.helpRoute);
                  break;
                case 'advanced':
                  widget.onOpenAdvanced();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(
                value: 'permissions',
                child: Text('Permissions'),
              ),
              const PopupMenuItem(value: 'help', child: Text('Help')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'advanced',
                child: Text('Switch to Advanced'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (needsPermissions)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: const Text('Permissions required'),
                        subtitle: const Text(
                          'Tap to enable Accessibility & Overlay.',
                        ),
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AutoClickerApp.permissionsRoute);
                        },
                      ),
                    ),
                  if (needsPermissions) const SizedBox(height: 12),
                  if (_isRunActive)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.play_circle_filled),
                        title: Text('Run state ($_runState)'),
                        trailing: FilledButton(
                          onPressed: _stopRun,
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          child: const Text('Stop'),
                        ),
                      ),
                    ),
                  if (_isRunActive) const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildHeroCard(),
                        const SizedBox(height: 12),
                        _buildMultiTargetCard(),
                        const SizedBox(height: 12),
                        _buildQuickActionsCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard() {
    final hasPoint = _config.hasSingleTargetPoint;
    final pointLabel = hasPoint
        ? '(${_config.singleTargetX!.toStringAsFixed(3)}, ${_config.singleTargetY!.toStringAsFixed(3)})'
        : 'No point selected';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: _openSingleTargetSettings,
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Interval, loop, delay',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              height: 120,
              child: Material(
                shape: const CircleBorder(),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _pickSingleTargetPoint,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasPoint
                            ? Icons.my_location
                            : Icons.add_location_alt_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasPoint ? 'Change' : 'Pick Point',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                pointLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            if (hasPoint) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '${_config.intervalMs}ms · ${_config.loopCount == 0 ? 'infinite' : _config.loopCount} loops',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isRunning
                    ? null
                    : (_isPaused ? _resumeRunFromNormal : _runSingleTarget),
                child: Text(
                  _isRunning
                      ? 'RUNNING'
                      : (_isPaused ? 'RESUME' : 'START'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
            Text(
              'Multi Target',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _multiTargetLabel,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openMultiTargetSelector,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Select Script'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AutoClickerApp.scriptListRoute),
                  icon: const Icon(Icons.tune),
                  label: const Text('Manage Scripts'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isRunActive ? null : _runMultiTarget,
                child: const Text('START MULTI TARGET'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _toggleController,
                  icon: Icon(
                    _controllerRunning ? Icons.stop_circle : Icons.play_circle,
                  ),
                  label: Text(
                    _controllerRunning ? 'Stop Controller' : 'Start Controller',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AutoClickerApp.helpRoute),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Guide'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onOpenAdvanced,
                  icon: const Icon(Icons.tune),
                  label: const Text('Advanced'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
