import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/services/analytics_service.dart';
import 'package:auto_clicker/services/run_engine_service.dart';
import 'package:auto_clicker/services/script_import_export_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({
    super.key,
    this.scriptId,
    this.availableScripts = const <ScriptModel>[],
  });

  final String? scriptId;
  final List<ScriptModel> availableScripts;

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  final ScriptRepository _repository = ScriptRepository.instance;
  final ScriptImportExportService _service = ScriptImportExportService.instance;
  final TextEditingController _importPathController = TextEditingController();
  ExportFormat _format = ExportFormat.schemaV1;
  List<ScriptModel> _scripts = const <ScriptModel>[];
  String? _routePreferredScriptId;
  String? _selectedScriptId;
  String _status = '';
  bool _busy = false;
  bool _loadingScripts = true;

  @override
  void initState() {
    super.initState();
    _routePreferredScriptId = widget.scriptId;
    _scripts = widget.availableScripts;
    _selectedScriptId = _resolveSelectedScriptId(widget.scriptId, _scripts);
    _refreshScripts();
  }

  @override
  void dispose() {
    _importPathController.dispose();
    super.dispose();
  }

  String? _resolveSelectedScriptId(
    String? preferred,
    List<ScriptModel> scripts,
  ) {
    if (scripts.isEmpty) {
      return null;
    }
    if (preferred != null && scripts.any((script) => script.id == preferred)) {
      return preferred;
    }
    return scripts.first.id;
  }

  Future<void> _refreshScripts() async {
    setState(() => _loadingScripts = true);
    final scripts = await _repository.listScripts(sortBy: ScriptSortBy.lastRun);
    if (!mounted) {
      return;
    }
    setState(() {
      _scripts = scripts;
      _selectedScriptId = _resolveSelectedScriptId(
        _selectedScriptId ?? _routePreferredScriptId,
        scripts,
      );
      _loadingScripts = false;
    });
  }

  Future<void> _exportOne() async {
    final runState = await RunEngineService.getRunState();
    if (runState != 'idle') {
      setState(() => _status = 'Stop current run before import/export.');
      return;
    }
    final id = _selectedScriptId;
    if (id == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final path = await _service.exportScript(id, _format);
      setState(() => _status = 'Exported to: $path');
      AnalyticsService.logEvent(
        'export_success',
        parameters: <String, Object?>{
          'script_id': id,
          'export_type': 'single',
          'screen_name': 'import_export',
        },
      );
    } catch (e) {
      setState(() => _status = 'Export failed: $e');
      AnalyticsService.logErrorEvent(
        code: 'EXPORT_FAILED',
        message: e.toString(),
        screenName: 'import_export',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportAll() async {
    final runState = await RunEngineService.getRunState();
    if (runState != 'idle') {
      setState(() => _status = 'Stop current run before import/export.');
      return;
    }
    setState(() => _busy = true);
    try {
      final path = await _service.exportAll(_format);
      setState(() => _status = 'Exported all to: $path');
      AnalyticsService.logEvent(
        'export_success',
        parameters: const <String, Object?>{
          'export_type': 'all',
          'screen_name': 'import_export',
        },
      );
    } catch (e) {
      setState(() => _status = 'Export all failed: $e');
      AnalyticsService.logErrorEvent(
        code: 'EXPORT_ALL_FAILED',
        message: e.toString(),
        screenName: 'import_export',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importFromPath() async {
    final runState = await RunEngineService.getRunState();
    if (runState != 'idle') {
      setState(() => _status = 'Stop current run before import/export.');
      return;
    }
    final path = _importPathController.text.trim();
    if (path.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.importFile(path);
      setState(
        () => _status =
            'Imported ${result.scripts.length} scripts (${result.format}).',
      );
      await _refreshScripts();
      AnalyticsService.logEvent(
        'import_success',
        parameters: <String, Object?>{
          'import_type': result.scripts.length > 1 ? 'all' : 'single',
          'scripts_count': result.scripts.length,
          'screen_name': 'import_export',
        },
      );
    } catch (e) {
      setState(() => _status = 'Import failed: $e');
      AnalyticsService.logErrorEvent(
        code: 'IMPORT_FAILED',
        message: e.toString(),
        screenName: 'import_export',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickImportFile() async {
    if (_busy) {
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }
      final path = result.files.single.path;
      if (path == null || path.trim().isEmpty) {
        setState(() {
          _status =
              'Selected file is not accessible. Please choose a local JSON file.';
        });
        return;
      }
      _importPathController.text = path;
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Unable to open file picker: $e');
      AnalyticsService.logErrorEvent(
        code: 'FILE_PICKER_FAILED',
        message: e.toString(),
        screenName: 'import_export',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasScriptSelection = _selectedScriptId != null && !_loadingScripts;
    return Scaffold(
      appBar: AppBar(title: const Text('Import / Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ExportFormat>(
            initialValue: _format,
            onChanged: (value) {
              if (value != null) {
                setState(() => _format = value);
              }
            },
            decoration: const InputDecoration(labelText: 'Export format'),
            items: const [
              DropdownMenuItem(
                value: ExportFormat.schemaV1,
                child: Text('Schema 1.0 JSON'),
              ),
              DropdownMenuItem(
                value: ExportFormat.internal,
                child: Text('Internal JSON'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedScriptId,
            hint: const Text('No scripts available'),
            onChanged: (value) => setState(() => _selectedScriptId = value),
            decoration: InputDecoration(
              labelText: 'Script',
              helperText: _loadingScripts ? 'Loading scripts...' : null,
            ),
            items: _scripts
                .map(
                  (script) => DropdownMenuItem<String>(
                    value: script.id,
                    child: Text(script.name),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy || !hasScriptSelection ? null : _exportOne,
                  child: const Text('Export Selected'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _exportAll,
                  child: const Text('Export All'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _importPathController,
            decoration: const InputDecoration(
              labelText: 'Import file path',
              hintText: r'Example: C:\path\scripts.json',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pickImportFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Choose JSON File'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _importFromPath,
              child: const Text('Import'),
            ),
          ),
          const SizedBox(height: 16),
          if (_status.isNotEmpty) Text(_status),
        ],
      ),
    );
  }
}
