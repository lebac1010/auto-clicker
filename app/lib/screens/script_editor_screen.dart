import 'dart:async';

import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/run_options.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/screens/run_options_screen.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/floating_controller_service.dart';
import 'package:auto_clicker/services/permission_service.dart';
import 'package:auto_clicker/services/run_execution_service.dart';
import 'package:auto_clicker/services/run_engine_service.dart';
import 'package:auto_clicker/services/script_validator.dart';
import 'package:auto_clicker/widgets/accessibility_disclosure_dialog.dart';
import 'package:flutter/material.dart';

class ScriptEditorScreen extends StatefulWidget {
  const ScriptEditorScreen({super.key, required this.scriptId});

  final String scriptId;

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  static const int _minSafeStartDelaySec = 2;
  final ScriptRepository _repository = ScriptRepository.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bulkHoldController = TextEditingController(
    text: '40',
  );
  final TextEditingController _timeWindowStartController =
      TextEditingController();
  final TextEditingController _timeWindowEndController =
      TextEditingController();
  final TextEditingController _foregroundAppController =
      TextEditingController();
  final TextEditingController _minBatteryPctController =
      TextEditingController();
  ScriptModel? _script;
  bool _loading = true;
  int _defaultIntervalMs = 300;
  int _loopCount = 1;
  _LoopMode _loopMode = _LoopMode.count;
  bool _requireCharging = false;
  bool _requireScreenOn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    FloatingControllerService.stopMarkerEditor();
    _nameController.dispose();
    _bulkHoldController.dispose();
    _timeWindowStartController.dispose();
    _timeWindowEndController.dispose();
    _foregroundAppController.dispose();
    _minBatteryPctController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final script = await _repository.getScript(widget.scriptId);
    if (!mounted) {
      return;
    }
    if (script == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _script = script;
      _nameController.text = script.name;
      _defaultIntervalMs = script.defaultIntervalMs;
      _loopMode = script.loopCount == 0 ? _LoopMode.infinite : _LoopMode.count;
      _loopCount = script.loopCount <= 0 ? 1 : script.loopCount;
      final hold = script.steps.isEmpty ? 40 : script.steps.first.holdMs;
      _bulkHoldController.text = hold.toString();
      _requireCharging = script.requireCharging;
      _requireScreenOn = script.requireScreenOn;
      _foregroundAppController.text = script.requireForegroundApp ?? '';
      _minBatteryPctController.text = script.minBatteryPct?.toString() ?? '';
      _timeWindowStartController.text = script.timeWindowStart ?? '';
      _timeWindowEndController.text = script.timeWindowEnd ?? '';
      _loading = false;
    });
  }

  ScriptModel get _workingScript {
    final current = _script!;
    return current.copyWith(
      name: _nameController.text.trim(),
      defaultIntervalMs: _defaultIntervalMs,
      loopCount: _loopMode == _LoopMode.infinite ? 0 : _loopCount,
      requireCharging: _requireCharging,
      requireScreenOn: _requireScreenOn,
      requireForegroundApp: _normalizeOptionalText(
        _foregroundAppController.text,
      ),
      minBatteryPct: _parseOptionalInt(
        _minBatteryPctController.text,
        invalidValue: -1,
      ),
      timeWindowStart: _normalizeOptionalText(_timeWindowStartController.text),
      timeWindowEnd: _normalizeOptionalText(_timeWindowEndController.text),
      updatedAt: DateTime.now(),
    );
  }

  String? _normalizeOptionalText(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _parseOptionalInt(String raw, {required int invalidValue}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed) ?? invalidValue;
  }

  Future<void> _save() async {
    final current = _workingScript;
    final errors = ScriptValidator.validate(current);
    if (errors.isNotEmpty) {
      _showValidation(errors);
      return;
    }
    await _repository.saveScript(current);
    if (!mounted) {
      return;
    }
    setState(() => _script = current);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Script saved')));
  }

  void _validateOnly() {
    final errors = ScriptValidator.validate(_workingScript);
    if (errors.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Validation passed')));
      return;
    }
    _showValidation(errors);
  }

  void _showValidation(List<String> errors) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Validation'),
        content: Text(errors.join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _markRun({required bool testCycle}) async {
    if (!await _ensureRunPermissions()) {
      return;
    }
    final baseScript = _workingScript;
    final runOptions = await _openRunOptions(baseScript, testCycle: testCycle);
    if (runOptions == null) {
      return;
    }
    final safeStartDelaySec = runOptions.startDelaySec < _minSafeStartDelaySec
        ? _minSafeStartDelaySec
        : runOptions.startDelaySec;
    if (safeStartDelaySec != runOptions.startDelaySec && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applying safe start delay of ${_minSafeStartDelaySec}s to prevent accidental touches.',
          ),
        ),
      );
    }
    final normalizedRunOptions = runOptions.copyWith(
      startDelaySec: safeStartDelaySec,
    );
    var current = baseScript;
    final errors = ScriptValidator.validate(current);
    if (errors.isNotEmpty) {
      _showValidation(errors);
      return;
    }
    await _repository.saveScript(current);
    final resolvedOptions = testCycle
        ? normalizedRunOptions.copyWith(
            stopRule: RunStopRule.loops,
            stopAfterLoops: 1,
            stopAfterDurationSec: null,
          )
        : normalizedRunOptions;
    var overlayStarted = false;
    final runStarted = await RunExecutionService.instance.runWithOptions(
      current,
      resolvedOptions,
    );
    if (runStarted) {
      overlayStarted = await FloatingControllerService.start();
      if (!overlayStarted) {
        await RunEngineService.stop();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open Floating Controller. Run has been stopped.',
            ),
          ),
        );
        return;
      }
      await FloatingControllerService.updateRunMarkers(current);
      await _repository.markRun(current.id);
      AnalyticsService.logEvent(
        'script_run_started',
        parameters: <String, Object?>{
          'script_id': current.id,
          'script_type': current.type.name,
          'steps_count': current.steps.length,
          'loop_mode': current.loopCount > 0 ? 'count' : 'infinite',
          'source': 'editor',
          'start_delay_sec': resolvedOptions.startDelaySec,
          'stop_rule': resolvedOptions.stopRule.name,
          'performance_mode': resolvedOptions.performanceMode.name,
          'screen_name': 'script_editor',
        },
      );
    }
    if (!mounted) {
      return;
    }
    final failureCode = RunExecutionService.instance.lastFailureCode;
    if (!runStarted && failureCode == 'RUN_START_SUPERSEDED') {
      return;
    }
    final failureMessage = RunExecutionService.instance.lastFailureMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          runStarted
              ? (testCycle ? 'Test cycle started' : 'Run started')
              : (failureMessage ?? 'Unable to start run.'),
        ),
      ),
    );
  }

  Future<RunOptions?> _openRunOptions(
    ScriptModel script, {
    required bool testCycle,
  }) {
    final initialOptions = testCycle
        ? const RunOptions(stopRule: RunStopRule.loops, stopAfterLoops: 1)
        : RunOptions.defaults;
    return Navigator.of(context).push<RunOptions>(
      MaterialPageRoute<RunOptions>(
        builder: (_) => RunOptionsScreen(
          scriptName: script.name,
          initialOptions: initialOptions,
        ),
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
    final missing = <String>[];
    if (!permissions.accessibilityEnabled) {
      missing.add('Accessibility');
    }
    if (!permissions.overlayEnabled) {
      missing.add('Overlay');
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Text('Enable ${missing.join(' + ')} before running scripts.'),
        actions: [
          if (!permissions.accessibilityEnabled)
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
          if (!permissions.overlayEnabled)
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
    return false;
  }

  Future<void> _addPoint() async {
    if (_script == null) {
      return;
    }
    final result = await _pickPointViaOverlay();
    if (result == null) {
      return;
    }
    setState(() {
      _script = _script!.copyWith(steps: [..._script!.steps, result]);
    });
  }

  Future<ScriptStep?> _pickPointViaOverlay() async {
    if (!await _ensureOverlayPermissionForEditor()) {
      return null;
    }
    final started = await FloatingControllerService.startPointPicker();
    if (!started) {
      if (!mounted) {
        return null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start overlay point picker.')),
      );
      return null;
    }
    if (!mounted) {
      return null;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pick a point in overlay, then press Confirm.'),
      ),
    );
    final event = await _awaitOverlayEvent(
      acceptedTypes: const <String>{'pick_result', 'pick_cancel', 'error'},
      timeout: const Duration(minutes: 2),
    );
    if (event == null) {
      return null;
    }
    final type = event['type']?.toString();
    if (type == 'pick_cancel') {
      return null;
    }
    if (type == 'error') {
      if (!mounted) {
        return null;
      }
      final message = event['message']?.toString() ?? 'Overlay picker failed.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return null;
    }
    final x = (event['x'] as num?)?.toDouble();
    final y = (event['y'] as num?)?.toDouble();
    if (x == null || y == null) {
      return null;
    }
    return ScriptStep(
      id: 'step_${DateTime.now().millisecondsSinceEpoch}',
      x: x.clamp(0, 1).toDouble(),
      y: y.clamp(0, 1).toDouble(),
      intervalMs: _defaultIntervalMs,
      holdMs: 40,
      enabled: true,
    );
  }

  Future<void> _editPointsWithOverlay() async {
    if (_script == null || _script!.steps.isEmpty) {
      return;
    }
    if (!await _ensureOverlayPermissionForEditor()) {
      return;
    }
    final started = await FloatingControllerService.startMarkerEditor(
      _script!.steps,
    );
    if (!started) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start marker editor overlay.')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Drag markers in overlay, then press Save.'),
      ),
    );
    final event = await _awaitOverlayEvent(
      acceptedTypes: const <String>{
        'markers_updated',
        'markers_cancelled',
        'error',
      },
      timeout: const Duration(minutes: 5),
    );
    await FloatingControllerService.stopMarkerEditor();
    if (event == null || !mounted) {
      return;
    }
    final type = event['type']?.toString();
    if (type == 'markers_cancelled') {
      return;
    }
    if (type == 'error') {
      final message = event['message']?.toString() ?? 'Marker editor failed.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final rawPoints = event['points'] as List<dynamic>? ?? <dynamic>[];
    if (rawPoints.isEmpty) {
      return;
    }
    final mapped = <String, ScriptStep>{};
    for (final step in _script!.steps) {
      mapped[step.id] = step;
    }
    for (final raw in rawPoints.whereType<Map>()) {
      final map = Map<dynamic, dynamic>.from(raw);
      final id = map['id']?.toString();
      final x = (map['x'] as num?)?.toDouble();
      final y = (map['y'] as num?)?.toDouble();
      if (id == null || x == null || y == null) {
        continue;
      }
      final existing = mapped[id];
      if (existing == null) {
        continue;
      }
      mapped[id] = existing.copyWith(
        x: x.clamp(0, 1).toDouble(),
        y: y.clamp(0, 1).toDouble(),
      );
    }
    final updatedSteps = _script!.steps
        .map((step) => mapped[step.id] ?? step)
        .toList();
    final updatedScript = _workingScript.copyWith(
      updatedAt: DateTime.now(),
      steps: updatedSteps,
    );
    final errors = ScriptValidator.validate(updatedScript);
    if (errors.isNotEmpty) {
      _showValidation(errors);
      return;
    }
    await _repository.saveScript(updatedScript);
    if (!mounted) {
      return;
    }
    setState(() => _script = updatedScript);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Marker positions saved.')));
  }

  Future<bool> _ensureOverlayPermissionForEditor() async {
    final permissions = await PermissionService.getPermissionState();
    if (permissions.overlayEnabled) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Overlay Required'),
        content: const Text(
          'Enable overlay permission to pick and edit points.',
        ),
        actions: [
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
    return false;
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

  Future<void> _editPoint(int index) async {
    final existing = _script!.steps[index];
    final result = await showDialog<ScriptStep>(
      context: context,
      builder: (_) => _PointDialog(initial: existing),
    );
    if (result == null) {
      return;
    }
    final copy = [..._script!.steps];
    copy[index] = result;
    setState(() => _script = _script!.copyWith(steps: copy));
  }

  void _removePoint(int index) {
    final copy = [..._script!.steps]..removeAt(index);
    setState(() => _script = _script!.copyWith(steps: copy));
  }

  void _togglePoint(int index, bool value) {
    final copy = [..._script!.steps];
    copy[index] = copy[index].copyWith(enabled: value);
    setState(() => _script = _script!.copyWith(steps: copy));
  }

  void _reorderPoint(int oldIndex, int newIndex) {
    final copy = [..._script!.steps];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = copy.removeAt(oldIndex);
    copy.insert(newIndex, item);
    setState(() => _script = _script!.copyWith(steps: copy));
  }

  void _applyHoldToAllPoints() {
    if (_script == null || _script!.steps.isEmpty) {
      return;
    }
    final hold = int.tryParse(_bulkHoldController.text.trim());
    if (hold == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid hold duration value.')),
      );
      return;
    }
    final normalizedHold = hold < 0 ? 0 : hold;
    final updated = _script!.steps
        .map((step) => step.copyWith(holdMs: normalizedHold))
        .toList();
    setState(() => _script = _script!.copyWith(steps: updated));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Applied hold duration to all points.')),
    );
  }

  String _describePoint(ScriptStep step) {
    if (step.action == 'swipe') {
      final x2 = step.x2 ?? step.x;
      final y2 = step.y2 ?? step.y;
      return 'Action: Swipe - Interval: ${step.intervalMs}ms - '
          'From: (${step.x.toStringAsFixed(3)}, ${step.y.toStringAsFixed(3)}) - '
          'To: (${x2.toStringAsFixed(3)}, ${y2.toStringAsFixed(3)}) - '
          'Duration: ${step.swipeDurationMs}ms';
    }
    if (step.action == 'multi_touch') {
      final x2 = step.x2 ?? step.x;
      final y2 = step.y2 ?? step.y;
      return 'Action: Multi-touch - Interval: ${step.intervalMs}ms - '
          'P1: (${step.x.toStringAsFixed(3)}, ${step.y.toStringAsFixed(3)}) - '
          'P2: (${x2.toStringAsFixed(3)}, ${y2.toStringAsFixed(3)}) - '
          'Duration: ${step.swipeDurationMs}ms';
    }
    return 'Action: ${_actionLabel(step.action)} - Interval: ${step.intervalMs}ms - Hold: ${step.holdMs}ms';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Script Editor'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Targets'),
              Tab(text: 'Settings'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _loading ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: _loading || _script == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Script name',
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [_buildTargetsTab(), _buildSettingsTab()],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                        FilledButton(
                          onPressed: () => _markRun(testCycle: false),
                          child: const Text('Run'),
                        ),
                        OutlinedButton(
                          onPressed: () => _markRun(testCycle: true),
                          child: const Text('Test cycle'),
                        ),
                        OutlinedButton(
                          onPressed: _validateOnly,
                          child: const Text('Validate'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTargetsTab() {
    final points = _script!.steps;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add),
                  label: const Text('Add point (overlay)'),
                ),
                OutlinedButton.icon(
                  onPressed: points.isEmpty ? null : _editPointsWithOverlay,
                  icon: const Icon(Icons.tune),
                  label: const Text('Edit via overlay'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: points.isEmpty
                ? const Center(child: Text('Add first point to continue.'))
                : ReorderableListView.builder(
                    itemCount: points.length,
                    onReorder: _reorderPoint,
                    itemBuilder: (_, index) {
                      final point = points[index];
                      return Card(
                        key: ValueKey(point.id),
                        child: ListTile(
                          title: Text(
                            'Point #${index + 1} (${point.x}, ${point.y})',
                          ),
                          subtitle: Text(_describePoint(point)),
                          leading: Switch(
                            value: point.enabled,
                            onChanged: (value) => _togglePoint(index, value),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _editPoint(index),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _removePoint(index),
                                icon: const Icon(Icons.delete_outline),
                              ),
                              const Icon(Icons.drag_handle),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final hasPoints = _script != null && _script!.steps.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Timing',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _defaultIntervalMs.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Global interval (ms)',
            helperText: 'Applied when point interval override is not set',
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null) {
              _defaultIntervalMs = parsed;
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<_LoopMode>(
          initialValue: _loopMode,
          decoration: const InputDecoration(labelText: 'Loop mode'),
          items: const [
            DropdownMenuItem(value: _LoopMode.count, child: Text('Count')),
            DropdownMenuItem(
              value: _LoopMode.infinite,
              child: Text('Infinite'),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _loopMode = value);
          },
        ),
        const SizedBox(height: 16),
        if (_loopMode == _LoopMode.count)
          TextFormField(
            initialValue: _loopCount.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Loop count',
              helperText: 'Set > 0 for count mode.',
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null) {
                _loopCount = parsed;
              }
            },
          )
        else
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Infinite loop enabled'),
            subtitle: Text('Script runs until you stop it manually.'),
          ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'Hold Duration',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Set hold duration in milliseconds for all points. '
          'Use 40ms for normal tap, larger values for long-press.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bulkHoldController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Hold duration (ms)'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: hasPoints ? _applyHoldToAllPoints : null,
          icon: const Icon(Icons.done_all),
          label: const Text('Apply to all points'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tip: Set action per point in point editor. Swipe uses x2/y2 and swipe duration.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _openConditionsSheet,
          icon: const Icon(Icons.tune),
          label: const Text('Advanced Conditions'),
        ),
      ],
    );
  }

  void _openConditionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Advanced Conditions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require charging'),
                  subtitle: const Text(
                    'Script only runs when device is charging or battery is full.',
                  ),
                  value: _requireCharging,
                  onChanged: (value) {
                    setSheetState(() => _requireCharging = value);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require screen ON'),
                  subtitle: const Text(
                    'Script only runs when screen is interactive/unlocked.',
                  ),
                  value: _requireScreenOn,
                  onChanged: (value) {
                    setSheetState(() => _requireScreenOn = value);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _foregroundAppController,
                  decoration: const InputDecoration(
                    labelText: 'Require foreground app package (optional)',
                    hintText: 'com.example.app',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'If set, script only runs when this app is currently in foreground.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _minBatteryPctController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum battery % (optional)',
                    hintText: '30',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use values 0-100. Leave empty to disable this condition.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Active time window (optional)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use HH:mm format. If left empty, script can run any time.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _timeWindowStartController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Start (HH:mm)',
                    hintText: '22:00',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _timeWindowEndController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'End (HH:mm)',
                    hintText: '06:00',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Overnight windows are supported (e.g., 22:00 -> 06:00).',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _actionLabel(String action) {
    return switch (action) {
      'double_tap' => 'Double Tap',
      'swipe' => 'Swipe',
      'multi_touch' => 'Multi-touch',
      _ => 'Tap',
    };
  }
}

enum _LoopMode { count, infinite }

class _PointDialog extends StatefulWidget {
  const _PointDialog({this.initial});

  final ScriptStep? initial;

  @override
  State<_PointDialog> createState() => _PointDialogState();
}

class _PointDialogState extends State<_PointDialog> {
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _x2Controller;
  late final TextEditingController _y2Controller;
  late final TextEditingController _intervalController;
  late final TextEditingController _holdController;
  late final TextEditingController _swipeDurationController;
  String _action = 'tap';
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _xController = TextEditingController(text: (initial?.x ?? 0.5).toString());
    _yController = TextEditingController(text: (initial?.y ?? 0.5).toString());
    _x2Controller = TextEditingController(
      text: (initial?.x2 ?? initial?.x ?? 0.5).toString(),
    );
    _y2Controller = TextEditingController(
      text: (initial?.y2 ?? initial?.y ?? 0.5).toString(),
    );
    _intervalController = TextEditingController(
      text: (initial?.intervalMs ?? 300).toString(),
    );
    _holdController = TextEditingController(
      text: (initial?.holdMs ?? 40).toString(),
    );
    _swipeDurationController = TextEditingController(
      text: (initial?.swipeDurationMs ?? 250).toString(),
    );
    _action = initial?.action ?? 'tap';
    _enabled = initial?.enabled ?? true;
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _x2Controller.dispose();
    _y2Controller.dispose();
    _intervalController.dispose();
    _holdController.dispose();
    _swipeDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add point' : 'Edit point'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _xController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'x (0..1)'),
          ),
          TextField(
            controller: _yController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'y (0..1)'),
          ),
          TextField(
            controller: _intervalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'interval (ms)'),
          ),
          TextField(
            controller: _holdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'hold duration (ms)'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _action,
            decoration: const InputDecoration(labelText: 'Action'),
            items: const [
              DropdownMenuItem(value: 'tap', child: Text('Tap')),
              DropdownMenuItem(value: 'double_tap', child: Text('Double Tap')),
              DropdownMenuItem(value: 'swipe', child: Text('Swipe')),
              DropdownMenuItem(
                value: 'multi_touch',
                child: Text('Multi-touch'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _action = value);
              }
            },
          ),
          if (_action == 'swipe' || _action == 'multi_touch') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _x2Controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'x2 (0..1)'),
            ),
            TextField(
              controller: _y2Controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'y2 (0..1)'),
            ),
            TextField(
              controller: _swipeDurationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _action == 'swipe'
                    ? 'swipe duration (ms)'
                    : 'touch duration (ms)',
              ),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final x = double.tryParse(_xController.text.trim());
            final y = double.tryParse(_yController.text.trim());
            final interval = int.tryParse(_intervalController.text.trim());
            final hold = int.tryParse(_holdController.text.trim());
            final x2 = double.tryParse(_x2Controller.text.trim());
            final y2 = double.tryParse(_y2Controller.text.trim());
            final swipeDuration = int.tryParse(
              _swipeDurationController.text.trim(),
            );
            if (x == null || y == null || interval == null || hold == null) {
              return;
            }
            if ((_action == 'swipe' || _action == 'multi_touch') &&
                (x2 == null || y2 == null || swipeDuration == null)) {
              return;
            }
            Navigator.of(context).pop(
              ScriptStep(
                id:
                    widget.initial?.id ??
                    'step_${DateTime.now().millisecondsSinceEpoch}',
                action: _action,
                x: x.clamp(0, 1).toDouble(),
                y: y.clamp(0, 1).toDouble(),
                x2: _action == 'swipe' || _action == 'multi_touch'
                    ? x2!.clamp(0, 1).toDouble()
                    : null,
                y2: _action == 'swipe' || _action == 'multi_touch'
                    ? y2!.clamp(0, 1).toDouble()
                    : null,
                intervalMs: interval,
                holdMs: hold < 0 ? 0 : hold,
                swipeDurationMs: _action == 'swipe' || _action == 'multi_touch'
                    ? (swipeDuration! < 1 ? 1 : swipeDuration)
                    : (widget.initial?.swipeDurationMs ?? 250),
                enabled: _enabled,
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
