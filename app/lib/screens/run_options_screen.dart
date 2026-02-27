import 'package:auto_clicker/models/run_options.dart';
import 'package:flutter/material.dart';

class RunOptionsScreen extends StatefulWidget {
  const RunOptionsScreen({
    super.key,
    required this.scriptName,
    this.initialOptions = RunOptions.defaults,
  });

  final String scriptName;
  final RunOptions initialOptions;

  @override
  State<RunOptionsScreen> createState() => _RunOptionsScreenState();
}

class _RunOptionsScreenState extends State<RunOptionsScreen> {
  late final TextEditingController _startDelayController;
  late final TextEditingController _stopLoopsController;
  late final TextEditingController _stopDurationController;
  late RunStopRule _stopRule;
  late RunPerformanceMode _performanceMode;

  @override
  void initState() {
    super.initState();
    _startDelayController = TextEditingController(
      text: widget.initialOptions.startDelaySec.toString(),
    );
    _stopLoopsController = TextEditingController(
      text: (widget.initialOptions.stopAfterLoops ?? 1).toString(),
    );
    _stopDurationController = TextEditingController(
      text: (widget.initialOptions.stopAfterDurationSec ?? 60).toString(),
    );
    _stopRule = widget.initialOptions.stopRule;
    _performanceMode = widget.initialOptions.performanceMode;
  }

  @override
  void dispose() {
    _startDelayController.dispose();
    _stopLoopsController.dispose();
    _stopDurationController.dispose();
    super.dispose();
  }

  void _submit() {
    final startDelay = int.tryParse(_startDelayController.text.trim());
    final stopLoops = int.tryParse(_stopLoopsController.text.trim());
    final stopDuration = int.tryParse(_stopDurationController.text.trim());
    if (startDelay == null) {
      _showError('Start delay is invalid.');
      return;
    }
    final options = RunOptions(
      startDelaySec: startDelay,
      stopRule: _stopRule,
      stopAfterLoops: _stopRule == RunStopRule.loops ? stopLoops : null,
      stopAfterDurationSec: _stopRule == RunStopRule.duration
          ? stopDuration
          : null,
      performanceMode: _performanceMode,
    );
    final errors = options.validate();
    if (errors.isNotEmpty) {
      _showError(errors.first);
      return;
    }
    Navigator.of(context).pop(options);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run Options')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.scriptName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Configure pre-run options before starting automation.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _startDelayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Start delay (sec)',
              helperText: 'Wait before first action.',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RunStopRule>(
            initialValue: _stopRule,
            decoration: const InputDecoration(labelText: 'Stop rule'),
            items: const [
              DropdownMenuItem(
                value: RunStopRule.none,
                child: Text('Manual stop'),
              ),
              DropdownMenuItem(
                value: RunStopRule.loops,
                child: Text('Stop after loop count'),
              ),
              DropdownMenuItem(
                value: RunStopRule.duration,
                child: Text('Stop after duration'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _stopRule = value);
            },
          ),
          if (_stopRule == RunStopRule.loops) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _stopLoopsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Loop count',
                helperText: 'Stop after N loops.',
              ),
            ),
          ],
          if (_stopRule == RunStopRule.duration) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _stopDurationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (sec)',
                helperText: 'Auto stop after N seconds.',
              ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<RunPerformanceMode>(
            initialValue: _performanceMode,
            decoration: const InputDecoration(labelText: 'Performance mode'),
            items: const [
              DropdownMenuItem(
                value: RunPerformanceMode.balanced,
                child: Text('Balanced'),
              ),
              DropdownMenuItem(
                value: RunPerformanceMode.fast,
                child: Text('Fast (higher battery usage)'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _performanceMode = value);
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Before running',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('- Overlay will appear on top of other apps.'),
                  Text('- Accessibility service will perform touch gestures.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Start'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
