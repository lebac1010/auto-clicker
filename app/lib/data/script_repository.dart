import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum ScriptSortBy { lastRun, name, createdAt }

class ScriptRepository {
  ScriptRepository({
    Future<Directory> Function()? documentsDirectoryProvider,
    Uuid? uuid,
    Future<void> Function(File file, String content)? writeFile,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _uuid = uuid ?? const Uuid(),
       _writeFile = writeFile;

  static final ScriptRepository instance = ScriptRepository();
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Uuid _uuid;
  final Future<void> Function(File file, String content)? _writeFile;
  Future<void> _writeQueue = Future<void>.value();

  Future<List<ScriptModel>> listScripts({
    String query = '',
    ScriptType? type,
    ScriptSortBy sortBy = ScriptSortBy.lastRun,
  }) async {
    await _awaitPendingWrites();
    final scripts = await _loadScriptsUnlocked();
    var filtered = scripts.where((script) {
      final nameMatch = script.name.toLowerCase().contains(query.toLowerCase());
      final typeMatch = type == null || script.type == type;
      return nameMatch && typeMatch;
    }).toList();

    switch (sortBy) {
      case ScriptSortBy.lastRun:
        filtered.sort((a, b) {
          final aTime = a.lastRunAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.lastRunAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        break;
      case ScriptSortBy.name:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ScriptSortBy.createdAt:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return filtered;
  }

  Future<List<ScriptModel>> recentScripts({int limit = 5}) async {
    final scripts = await listScripts(sortBy: ScriptSortBy.lastRun);
    return scripts.take(limit).toList();
  }

  Future<ScriptModel> createScript({
    required String name,
    required ScriptType type,
  }) async {
    return _withWriteLock(() async {
      final now = DateTime.now();
      final script = ScriptModel(
        id: _id(),
        name: name,
        type: type,
        createdAt: now,
        updatedAt: now,
        defaultIntervalMs: 300,
        loopCount: 1,
        steps: const [],
        lastRunAt: null,
      );
      await _saveScriptUnlocked(script);
      return script;
    });
  }

  Future<void> saveScript(ScriptModel script) async {
    await _withWriteLock(() => _saveScriptUnlocked(script));
  }

  Future<void> saveAll(List<ScriptModel> scripts) async {
    await _withWriteLock(() async {
      for (final script in scripts) {
        await _saveScriptUnlocked(script);
      }
    });
  }

  Future<void> saveAtomically(List<ScriptModel> scripts) async {
    await _withWriteLock(() async {
      final previousById = <String, ScriptModel?>{};
      final writtenIds = <String>[];
      try {
        for (final script in scripts) {
          previousById[script.id] = await _getScriptUnlocked(script.id);
          await _saveScriptUnlocked(script);
          writtenIds.add(script.id);
        }
      } catch (e) {
        // Roll back each written script independently to avoid partial state.
        for (final id in writtenIds.reversed) {
          try {
            final previous = previousById[id];
            if (previous == null) {
              await _deleteScriptUnlocked(id);
            } else {
              await _saveScriptUnlocked(previous);
            }
          } catch (_) {
            // Best-effort rollback continues for remaining ids.
          }
        }
        rethrow;
      }
    });
  }

  Future<ScriptModel?> getScript(String id) async {
    await _awaitPendingWrites();
    return _getScriptUnlocked(id);
  }

  Future<bool> exists(String id) async {
    await _awaitPendingWrites();
    final file = await _scriptFile(id);
    return await file.exists();
  }

  Future<void> deleteScript(String id) async {
    await _withWriteLock(() => _deleteScriptUnlocked(id));
  }

  Future<void> duplicateScript(String id) async {
    await _withWriteLock(() async {
      final source = await _getScriptUnlocked(id);
      if (source == null) {
        return;
      }
      final now = DateTime.now();
      final copy = source.copyWith(
        id: _id(),
        name: '${source.name} Copy',
        createdAt: now,
        updatedAt: now,
        lastRunAt: null,
      );
      await _saveScriptUnlocked(copy);
    });
  }

  Future<void> markRun(String id) async {
    await _withWriteLock(() async {
      final script = await _getScriptUnlocked(id);
      if (script == null) {
        return;
      }
      final now = DateTime.now();
      await _saveScriptUnlocked(
        script.copyWith(
          updatedAt: now,
          lastRunAt: now,
        ),
      );
    });
  }

  Future<List<ScriptModel>> _loadScriptsUnlocked() async {
    final dir = await _scriptsDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return <ScriptModel>[];
    }

    final List<ScriptModel> scripts = [];
    await for (final entity in dir.list()) {
      if (entity is! File) {
        continue;
      }
      final file = entity;
      if (!file.path.endsWith('.json')) {
        continue;
      }
      try {
        final raw = await file.readAsString();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        scripts.add(ScriptModel.fromJson(data));
      } catch (_) {
        // Skip invalid script files.
      }
    }
    return scripts;
  }

  Future<void> _saveScriptUnlocked(ScriptModel script) async {
    final file = await _scriptFile(script.id);
    final content = jsonEncode(script.toJson());
    if (_writeFile != null) {
      await _writeFile(file, content);
      return;
    }
    await file.writeAsString(content);
  }

  Future<ScriptModel?> _getScriptUnlocked(String id) async {
    final file = await _scriptFile(id);
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return ScriptModel.fromJson(data);
  }

  Future<void> _deleteScriptUnlocked(String id) async {
    final file = await _scriptFile(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _scriptsDir() async {
    final docs = await _documentsDirectoryProvider();
    final dir = Directory('${docs.path}${Platform.pathSeparator}scripts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _scriptFile(String id) async {
    final dir = await _scriptsDir();
    return File('${dir.path}${Platform.pathSeparator}$id.json');
  }

  String _id() {
    return 'scr_${_uuid.v4().replaceAll('-', '')}';
  }

  Future<void> _awaitPendingWrites() async {
    await _writeQueue;
  }

  Future<T> _withWriteLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      }
    });
    return completer.future;
  }
}
