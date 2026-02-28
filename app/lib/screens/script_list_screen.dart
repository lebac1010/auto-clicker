import 'dart:async';

import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/main.dart';
import 'package:auto_clicker/models/run_options.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:auto_clicker/screens/import_export_screen.dart';
import 'package:auto_clicker/screens/recorder_screen.dart';
import 'package:auto_clicker/screens/run_options_screen.dart';
import 'package:auto_clicker/screens/script_editor_screen.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/floating_controller_service.dart';
import 'package:auto_clicker/services/permission_service.dart';
import 'package:auto_clicker/services/run_execution_service.dart';
import 'package:auto_clicker/services/run_engine_service.dart';
import 'package:auto_clicker/widgets/accessibility_disclosure_dialog.dart';
import 'package:flutter/material.dart';

class ScriptListScreen extends StatefulWidget {
  const ScriptListScreen({super.key});

  @override
  State<ScriptListScreen> createState() => _ScriptListScreenState();
}

class _ScriptListScreenState extends State<ScriptListScreen> {
  static const int _minSafeStartDelaySec = 2;
  final ScriptRepository _repository = ScriptRepository.instance;
  final TextEditingController _searchController = TextEditingController();
  List<ScriptModel> _scripts = <ScriptModel>[];
  bool _loading = true;
  ScriptType? _selectedType;
  ScriptSortBy _sortBy = ScriptSortBy.lastRun;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _repository.listScripts(
      query: _searchController.text,
      type: _selectedType,
      sortBy: _sortBy,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _scripts = data;
      _loading = false;
    });
  }

  Future<void> _createScript() async {
    final result = await showDialog<_NewScriptPayload>(
      context: context,
      builder: (_) => const _CreateScriptDialog(),
    );
    if (result == null) {
      return;
    }
    final created = await _repository.createScript(
      name: result.name,
      type: result.type,
    );
    AnalyticsService.logEvent(
      'script_created',
      parameters: <String, Object?>{
        'script_id': created.id,
        'script_type': created.type.name,
        'steps_count': created.steps.length,
        'screen_name': 'script_list',
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
    await _load();
  }

  Future<void> _editScript(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ScriptEditorScreen(scriptId: id)),
    );
    if (!mounted) {
      return;
    }
    await _load();
  }

  Future<void> _deleteScript(String id) async {
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete script'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!approved) {
      return;
    }
    await _repository.deleteScript(id);
    await _load();
  }

  Future<void> _duplicateScript(String id) async {
    await _repository.duplicateScript(id);
    await _load();
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
    final resolvedRunOptions = runOptions.copyWith(
      startDelaySec: safeStartDelaySec,
    );
    final started = await RunExecutionService.instance.runWithOptions(
      script,
      resolvedRunOptions,
    );
    if (started) {
      final overlayStarted = await FloatingControllerService.start();
      if (!overlayStarted) {
        await RunEngineService.stop();
        await _load();
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
      await FloatingControllerService.updateRunMarkers(script);
      await _repository.markRun(id);
      AnalyticsService.logEvent(
        'script_run_started',
        parameters: <String, Object?>{
          'script_id': script.id,
          'script_type': script.type.name,
          'steps_count': script.steps.length,
          'loop_mode': script.loopCount > 0 ? 'count' : 'infinite',
          'source': 'script_list',
          'start_delay_sec': resolvedRunOptions.startDelaySec,
          'stop_rule': resolvedRunOptions.stopRule.name,
          'performance_mode': resolvedRunOptions.performanceMode.name,
          'screen_name': 'script_list',
        },
      );
    }
    await _load();
    if (!mounted) {
      return;
    }
    final failureCode = RunExecutionService.instance.lastFailureCode;
    if (!started && failureCode == 'RUN_START_SUPERSEDED') {
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

  Future<void> _openImportExport({String? scriptId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ImportExportScreen(scriptId: scriptId, availableScripts: _scripts),
      ),
    );
    if (!mounted) {
      return;
    }
    await _load();
  }

  Future<void> _recordNewScript() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RecorderScreen()));
    if (!mounted) {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scripts'),
        actions: [
          IconButton(
            tooltip: 'Scheduler',
            onPressed: () {
              Navigator.of(context).pushNamed(AutoClickerApp.schedulerRoute);
            },
            icon: const Icon(Icons.schedule_outlined),
          ),
          IconButton(
            tooltip: 'Recorder',
            onPressed: _recordNewScript,
            icon: const Icon(Icons.fiber_manual_record_outlined),
          ),
          IconButton(
            tooltip: 'Import / Export',
            onPressed: () => _openImportExport(),
            icon: const Icon(Icons.import_export_outlined),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createScript,
        icon: const Icon(Icons.add),
        label: const Text('New Script'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(
                  const Duration(milliseconds: 250),
                  _load,
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ScriptType?>(
                    initialValue: _selectedType,
                    items: <DropdownMenuItem<ScriptType?>>[
                      const DropdownMenuItem<ScriptType?>(
                        value: null,
                        child: Text('All Types'),
                      ),
                      ...ScriptType.values.map(
                        (type) => DropdownMenuItem<ScriptType?>(
                          value: type,
                          child: Text(type.label),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      _selectedType = value;
                      _load();
                    },
                    decoration: const InputDecoration(labelText: 'Filter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ScriptSortBy>(
                    initialValue: _sortBy,
                    items: const [
                      DropdownMenuItem(
                        value: ScriptSortBy.lastRun,
                        child: Text('Last Run'),
                      ),
                      DropdownMenuItem(
                        value: ScriptSortBy.name,
                        child: Text('Name'),
                      ),
                      DropdownMenuItem(
                        value: ScriptSortBy.createdAt,
                        child: Text('Created Date'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      _sortBy = value;
                      _load();
                    },
                    decoration: const InputDecoration(labelText: 'Sort'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _scripts.isEmpty
                  ? const Center(
                      child: Text('No scripts yet. Create your first script.'),
                    )
                  : ListView.separated(
                      itemCount: _scripts.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final script = _scripts[index];
                        return Card(
                          child: ListTile(
                            title: Text(script.name),
                            subtitle: Text(
                              '${script.type.label} - Updated ${_formatDate(script.updatedAt)}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'run') {
                                  await _runScript(script.id);
                                } else if (value == 'edit') {
                                  await _editScript(script.id);
                                } else if (value == 'duplicate') {
                                  await _duplicateScript(script.id);
                                } else if (value == 'export') {
                                  await _openImportExport(scriptId: script.id);
                                } else if (value == 'delete') {
                                  await _deleteScript(script.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(value: 'run', child: Text('Run')),
                                PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text('Duplicate'),
                                ),
                                PopupMenuItem(
                                  value: 'export',
                                  child: Text('Export'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                            onTap: () => _editScript(script.id),
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

  String _formatDate(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} $hour:$minute';
  }
}

class _CreateScriptDialog extends StatefulWidget {
  const _CreateScriptDialog();

  @override
  State<_CreateScriptDialog> createState() => _CreateScriptDialogState();
}

class _CreateScriptDialogState extends State<_CreateScriptDialog> {
  final TextEditingController _nameController = TextEditingController();
  ScriptType _selectedType = ScriptType.multiTap;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create script'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Script name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ScriptType>(
            initialValue: _selectedType,
            items: ScriptType.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedType = value);
              }
            },
            decoration: const InputDecoration(labelText: 'Type'),
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
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              return;
            }
            Navigator.of(
              context,
            ).pop(_NewScriptPayload(name: name, type: _selectedType));
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _NewScriptPayload {
  const _NewScriptPayload({required this.name, required this.type});

  final String name;
  final ScriptType type;
}
