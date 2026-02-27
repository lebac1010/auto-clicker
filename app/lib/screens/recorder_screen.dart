import 'dart:async';

import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/recorded_step.dart';
import 'package:auto_clicker/models/recorder_state.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/permission_service.dart';
import 'package:auto_clicker/services/recorded_script_mapper.dart';
import 'package:auto_clicker/services/recorder_service.dart';
import 'package:auto_clicker/services/support_log_service.dart';
import 'package:auto_clicker/widgets/accessibility_disclosure_dialog.dart';
import 'package:flutter/material.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  final ScriptRepository _repository = ScriptRepository.instance;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  RecorderState _state = RecorderState.idle;
  int _countdown = 0;
  List<RecordedStep> _steps = const <RecordedStep>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subscription = RecorderService.events().listen(_onRecorderEvent);
    _syncState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _syncState() async {
    final state = await RecorderService.getState();
    if (!mounted) {
      return;
    }
    setState(() => _state = state);
  }

  Future<void> _startRecorder() async {
    final permissions = await PermissionService.getPermissionState();
    if (!permissions.accessibilityEnabled) {
      if (!mounted) {
        return;
      }
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Accessibility Required'),
          content: const Text('Enable Accessibility Service before recording.'),
          actions: [
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
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _steps = const <RecordedStep>[];
    });
    final started = await RecorderService.start(countdownSec: 3);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (started) {
      AnalyticsService.logEvent(
        'recorder_started',
        parameters: const <String, Object?>{
          'countdown_sec': 3,
          'screen_name': 'recorder',
        },
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recorder started')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to start recorder')));
    }
  }

  Future<void> _stopRecorder() async {
    setState(() => _busy = true);
    final steps = await RecorderService.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _steps = steps;
      _state = RecorderState.stopped;
    });
  }

  Future<void> _saveAsScript() async {
    if (_steps.isEmpty) {
      return;
    }
    try {
      final script = await _repository.createScript(
        name: 'Recorded ${DateTime.now().millisecondsSinceEpoch}',
        type: ScriptType.macro,
      );
      final mappedSteps = RecordedScriptMapper.toScriptSteps(_steps);
      await _repository.saveScript(
        script.copyWith(
          updatedAt: DateTime.now(),
          steps: mappedSteps,
          defaultIntervalMs: 200,
          loopCount: 1,
        ),
      );
      if (!mounted) {
        return;
      }
      AnalyticsService.logEvent(
        'script_created',
        parameters: <String, Object?>{
          'script_id': script.id,
          'script_type': script.type.name,
          'steps_count': mappedSteps.length,
          'screen_name': 'recorder',
        },
      );
      AnalyticsService.logEvent(
        'recorder_saved',
        parameters: <String, Object?>{
          'script_id': script.id,
          'steps_count': mappedSteps.length,
          'duration_ms': _steps.fold<int>(0, (sum, step) => sum + step.delayMs),
          'screen_name': 'recorder',
        },
      );
      await RecorderService.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = RecorderState.idle;
        _steps = const <RecordedStep>[];
        _countdown = 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recorded script saved')));
    } catch (error, stackTrace) {
      AnalyticsService.logErrorEvent(
        code: 'RECORDER_SAVE_FAILED',
        message: error.toString(),
        screenName: 'recorder',
      );
      SupportLogService.logError(
        'recorder_screen',
        'Failed to save recorded script',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    }
  }

  Future<void> _discardSession() async {
    setState(() => _busy = true);
    await RecorderService.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _state = RecorderState.idle;
      _steps = const <RecordedStep>[];
      _countdown = 0;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recorder session discarded')));
  }

  void _deleteStep(int index) {
    final copy = [..._steps]..removeAt(index);
    setState(() => _steps = _normalizeSteps(copy));
  }

  Future<void> _editStep(int index) async {
    final existing = _steps[index];
    final updated = await showDialog<RecordedStep>(
      context: context,
      builder: (_) => _RecordedStepDialog(initial: existing),
    );
    if (updated == null) {
      return;
    }
    final copy = [..._steps];
    copy[index] = updated;
    setState(() => _steps = _normalizeSteps(copy));
  }

  Future<void> _insertStepBelow(int index) async {
    final base = _steps[index];
    final inserted = await showDialog<RecordedStep>(
      context: context,
      builder: (_) => _RecordedStepDialog(
        initial: base.copyWith(index: 0, delayMs: base.delayMs),
      ),
    );
    if (inserted == null) {
      return;
    }
    final copy = [..._steps];
    copy.insert(index + 1, inserted);
    setState(() => _steps = _normalizeSteps(copy));
  }

  Future<void> _insertStepAtEnd() async {
    final inserted = await showDialog<RecordedStep>(
      context: context,
      builder: (_) => const _RecordedStepDialog(),
    );
    if (inserted == null) {
      return;
    }
    final copy = [..._steps, inserted];
    setState(() => _steps = _normalizeSteps(copy));
  }

  List<RecordedStep> _normalizeSteps(List<RecordedStep> steps) {
    return steps.asMap().entries.map((entry) {
      return entry.value.copyWith(index: entry.key + 1);
    }).toList();
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'multi_touch':
        return 'Multi-touch';
      case 'swipe':
        return 'Swipe';
      case 'double_tap':
        return 'Double Tap';
      case 'tap':
      default:
        return 'Tap';
    }
  }

  void _onRecorderEvent(Map<String, dynamic> event) {
    if (!mounted) {
      return;
    }
    final type = event['type']?.toString();
    if (type == 'state') {
      final nextState = RecorderState.fromValue(
        event['state']?.toString() ?? 'idle',
      );
      setState(() {
        _state = nextState;
        if (nextState != RecorderState.countdown) {
          _countdown = 0;
        }
      });
      return;
    }
    if (type == 'countdown') {
      setState(
        () => _countdown = (event['remainingSec'] as num?)?.toInt() ?? 0,
      );
      return;
    }
    if (type == 'record_step') {
      final step = RecordedStep.fromMap(event);
      setState(() {
        _steps = [..._steps, step.copyWith(index: _steps.length + 1)];
      });
      return;
    }
    if (type == 'error') {
      final message = event['message']?.toString() ?? 'Recorder error';
      AnalyticsService.logErrorEvent(
        code: event['code']?.toString() ?? 'RECORDER_ERROR',
        message: message,
        screenName: 'recorder',
      );
      SupportLogService.logError(
        'recorder_screen',
        'Recorder event error',
        data: <String, Object?>{'message': message},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recorder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('State: ${_state.value}'),
            if (_state == RecorderState.countdown)
              Text('Countdown: $_countdown'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || _state == RecorderState.recording
                        ? null
                        : _startRecorder,
                    child: const Text('Start Recording'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || _state == RecorderState.idle
                        ? null
                        : _stopRecorder,
                    child: const Text('Stop Recording'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _steps.isEmpty ? null : _saveAsScript,
                    child: const Text('Save As Script'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _busy ||
                            (_state == RecorderState.idle && _steps.isEmpty)
                        ? null
                        : _discardSession,
                    child: const Text('Discard Session'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _steps.isEmpty ? null : _insertStepAtEnd,
                icon: const Icon(Icons.add),
                label: const Text('Insert Step'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Timeline (${_steps.length} steps)'),
            const SizedBox(height: 8),
            Expanded(
              child: _steps.isEmpty
                  ? const Center(child: Text('No recorded steps yet.'))
                  : ListView.separated(
                      itemCount: _steps.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final step = _steps[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              '#${step.index} ${_actionLabel(step.action)} (${step.x.toStringAsFixed(3)}, ${step.y.toStringAsFixed(3)})',
                            ),
                          subtitle: Text(
                              (step.action == 'swipe' ||
                                          step.action == 'multi_touch')
                                  ? 'Delay: ${step.delayMs} ms - ${(step.action == 'swipe') ? 'Swipe' : 'P2'}: (${(step.x2 ?? step.x).toStringAsFixed(3)}, ${(step.y2 ?? step.y).toStringAsFixed(3)}) in ${step.swipeDurationMs} ms - ${step.enabled ? 'Enabled' : 'Disabled'}'
                                  : 'Delay: ${step.delayMs} ms - Hold: ${step.holdMs} ms - ${step.enabled ? 'Enabled' : 'Disabled'}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editStep(index);
                                } else if (value == 'insert_below') {
                                  _insertStepBelow(index);
                                } else if (value == 'delete') {
                                  _deleteStep(index);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit Step'),
                                ),
                                PopupMenuItem(
                                  value: 'insert_below',
                                  child: Text('Insert Below'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                            onTap: () => _editStep(index),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordedStepDialog extends StatefulWidget {
  const _RecordedStepDialog({this.initial});

  final RecordedStep? initial;

  @override
  State<_RecordedStepDialog> createState() => _RecordedStepDialogState();
}

class _RecordedStepDialogState extends State<_RecordedStepDialog> {
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _x2Controller;
  late final TextEditingController _y2Controller;
  late final TextEditingController _delayController;
  late final TextEditingController _holdController;
  late final TextEditingController _swipeDurationController;
  String _action = 'tap';
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _xController = TextEditingController(
      text: (initial?.x ?? 0.5).toStringAsFixed(3),
    );
    _yController = TextEditingController(
      text: (initial?.y ?? 0.5).toStringAsFixed(3),
    );
    _x2Controller = TextEditingController(
      text: (initial?.x2 ?? initial?.x ?? 0.5).toStringAsFixed(3),
    );
    _y2Controller = TextEditingController(
      text: (initial?.y2 ?? initial?.y ?? 0.5).toStringAsFixed(3),
    );
    _delayController = TextEditingController(
      text: (initial?.delayMs ?? 100).toString(),
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
    _delayController.dispose();
    _holdController.dispose();
    _swipeDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Insert Step' : 'Edit Step'),
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
            controller: _delayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'delay (ms)'),
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
              DropdownMenuItem(value: 'multi_touch', child: Text('Multi-touch')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _action = value);
            },
          ),
          if (_action == 'swipe' || _action == 'multi_touch') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _x2Controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'x2 (0..1)'),
            ),
            TextField(
              controller: _y2Controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            final delay = int.tryParse(_delayController.text.trim());
            final hold = int.tryParse(_holdController.text.trim());
            final x2 = double.tryParse(_x2Controller.text.trim());
            final y2 = double.tryParse(_y2Controller.text.trim());
            final swipeDuration = int.tryParse(
              _swipeDurationController.text.trim(),
            );
            if (x == null || y == null || delay == null || hold == null) {
              return;
            }
            if ((_action == 'swipe' || _action == 'multi_touch') &&
                (x2 == null || y2 == null || swipeDuration == null)) {
              return;
            }
            Navigator.of(context).pop(
              RecordedStep(
                index: widget.initial?.index ?? 0,
                action: _action,
                x: x.clamp(0, 1).toDouble(),
                y: y.clamp(0, 1).toDouble(),
                x2: _action == 'swipe' || _action == 'multi_touch'
                    ? x2!.clamp(0, 1).toDouble()
                    : null,
                y2: _action == 'swipe' || _action == 'multi_touch'
                    ? y2!.clamp(0, 1).toDouble()
                    : null,
                delayMs: delay < 0 ? 0 : delay,
                holdMs: hold < 0 ? 0 : hold,
                swipeDurationMs:
                    _action == 'swipe' || _action == 'multi_touch'
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
