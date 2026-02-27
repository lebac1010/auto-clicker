import 'dart:convert';
import 'dart:io';

import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/imported_script_result.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/services/script_internal_mapper.dart';
import 'package:auto_clicker/services/script_schema_mapper.dart';
import 'package:auto_clicker/services/script_validator.dart';
import 'package:path_provider/path_provider.dart';

enum ExportFormat { schemaV1, internal }

class ScriptImportExportService {
  ScriptImportExportService({
    ScriptRepository? repository,
    Future<Directory> Function()? exportsDirectoryProvider,
  }) : _repository = repository ?? ScriptRepository.instance,
       _exportsDirectoryProvider = exportsDirectoryProvider;

  static final ScriptImportExportService instance = ScriptImportExportService();
  final ScriptRepository _repository;
  final Future<Directory> Function()? _exportsDirectoryProvider;

  Future<String> exportScript(String id, ExportFormat format) async {
    final script = await _repository.getScript(id);
    if (script == null) {
      throw const FormatException('Script not found');
    }
    final map = format == ExportFormat.schemaV1
        ? ScriptSchemaMapper.toSchemaV1(script)
        : ScriptInternalMapper.toMap(script);
    final dir = await _exportsDir();
    final ext = format == ExportFormat.schemaV1 ? 'schema.json' : 'internal.json';
    final file = File('${dir.path}${Platform.pathSeparator}${script.id}.$ext');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    return file.path;
  }

  Future<String> exportAll(ExportFormat format) async {
    final scripts = await _repository.listScripts(sortBy: ScriptSortBy.createdAt);
    final list = scripts
        .map(
          (script) => format == ExportFormat.schemaV1
              ? ScriptSchemaMapper.toSchemaV1(script)
              : ScriptInternalMapper.toMap(script),
        )
        .toList();
    final root = <String, dynamic>{
      'format': format.name,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'scripts': list,
    };
    final dir = await _exportsDir();
    final file = File(
      '${dir.path}${Platform.pathSeparator}scripts_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(root));
    return file.path;
  }

  Future<ImportedScriptResult> importFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('Import file not found');
    }
    final raw = await file.readAsString();
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid import payload');
    }
    final map = Map<String, dynamic>.from(decoded);
    final scripts = <ScriptModel>[];
    String detectedFormat = 'internal';

    final existing = await _repository.listScripts(sortBy: ScriptSortBy.createdAt);
    final usedIds = existing.map((s) => s.id).toSet();
    final usedNames = existing.map((s) => s.name).toSet();

    if (map.containsKey('scripts') && map['scripts'] is List) {
      final rawScripts = map['scripts'] as List<dynamic>;
      if (rawScripts.isEmpty) {
        throw const FormatException('Import list is empty');
      }
      String? batchFormat;
      for (final item in rawScripts) {
        if (item is! Map) {
          throw const FormatException('Each script entry must be an object');
        }
        final payload = Map<String, dynamic>.from(item);
        final isSchema = _detectSchemaPayload(payload);
        final itemFormat = isSchema ? 'schemaV1' : 'internal';
        if (batchFormat == null) {
          batchFormat = itemFormat;
        } else if (batchFormat != itemFormat) {
          throw const FormatException('Mixed import formats are not supported');
        }
        final script = _parseSingleImport(
          payload,
          isSchema: isSchema,
          usedIds: usedIds,
          usedNames: usedNames,
        );
        scripts.add(script);
      }
      detectedFormat = batchFormat ?? map['format']?.toString() ?? detectedFormat;
    } else {
      final isSchema = _detectSchemaPayload(map);
      final single = _parseSingleImport(
        map,
        isSchema: isSchema,
        usedIds: usedIds,
        usedNames: usedNames,
      );
      scripts.add(single);
      detectedFormat = isSchema ? 'schemaV1' : 'internal';
    }

    await _repository.saveAtomically(scripts);
    return ImportedScriptResult(scripts: scripts, format: detectedFormat);
  }

  ScriptModel _parseSingleImport(
    Map<String, dynamic> map, {
    required bool isSchema,
    required Set<String> usedIds,
    required Set<String> usedNames,
  }) {
    var script = isSchema
        ? ScriptSchemaMapper.fromSchemaV1(map)
        : ScriptInternalMapper.fromMap(map);
    script = script.copyWith(
      id: _resolveUniqueId(script.id, usedIds),
      name: _resolveUniqueName(script.name, usedNames),
    );
    usedIds.add(script.id);
    usedNames.add(script.name);
    final errors = ScriptValidator.validate(script);
    if (errors.isNotEmpty) {
      throw FormatException(errors.first);
    }
    return script;
  }

  bool _detectSchemaPayload(Map<String, dynamic> map) {
    if (!map.containsKey('schemaVersion')) {
      return false;
    }
    final version = map['schemaVersion']?.toString();
    if (version == null || version.trim().isEmpty) {
      throw const FormatException('Invalid schemaVersion value');
    }
    if (version != '1.0') {
      throw FormatException('Unsupported schemaVersion: $version');
    }
    return true;
  }

  String _resolveUniqueId(String original, Set<String> usedIds) {
    if (!usedIds.contains(original)) {
      return original;
    }
    var index = 1;
    var candidate = '${original}_imported';
    while (usedIds.contains(candidate)) {
      index += 1;
      candidate = '${original}_imported_$index';
    }
    return candidate;
  }

  String _resolveUniqueName(String original, Set<String> usedNames) {
    if (!usedNames.contains(original)) {
      return original;
    }
    var index = 1;
    var candidate = '$original (Imported)';
    while (usedNames.contains(candidate)) {
      index += 1;
      candidate = '$original (Imported $index)';
    }
    return candidate;
  }

  Future<Directory> _exportsDir() async {
    final provider = _exportsDirectoryProvider;
    final dir = provider != null
        ? await provider()
        : Directory(
            '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}exports',
          );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
