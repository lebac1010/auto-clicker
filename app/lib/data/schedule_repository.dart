import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_clicker/models/schedule_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ScheduleRepository {
  ScheduleRepository({
    Future<Directory> Function()? documentsDirectoryProvider,
    Uuid? uuid,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _uuid = uuid ?? const Uuid();

  static final ScheduleRepository instance = ScheduleRepository();

  final Future<Directory> Function() _documentsDirectoryProvider;
  final Uuid _uuid;
  Future<void> _writeQueue = Future<void>.value();

  Future<List<ScheduleModel>> listSchedules() async {
    await _awaitPendingWrites();
    final dir = await _schedulesDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return <ScheduleModel>[];
    }
    final schedules = <ScheduleModel>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      try {
        final raw = await entity.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        schedules.add(ScheduleModel.fromJson(json));
      } catch (_) {
        // Skip invalid schedule file.
      }
    }
    schedules.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return schedules;
  }

  Future<ScheduleModel?> getSchedule(String id) async {
    await _awaitPendingWrites();
    return _getScheduleUnlocked(id);
  }

  Future<ScheduleModel> createSchedule({
    required String scriptId,
    required ScheduleType type,
    String? timeOfDay,
    List<int> weekdays = const <int>[],
    DateTime? onceAt,
  }) {
    return _withWriteLock(() async {
      final now = DateTime.now();
      final model = ScheduleModel(
        id: 'sch_${_uuid.v4().replaceAll('-', '')}',
        scriptId: scriptId,
        type: type,
        enabled: true,
        createdAt: now,
        updatedAt: now,
        timeOfDay: timeOfDay,
        weekdays: weekdays,
        onceAt: onceAt,
      );
      await _saveScheduleUnlocked(model);
      return model;
    });
  }

  Future<void> saveSchedule(ScheduleModel schedule) async {
    await _withWriteLock(() async {
      await _saveScheduleUnlocked(schedule);
    });
  }

  Future<void> deleteSchedule(String id) async {
    await _withWriteLock(() async {
      final file = await _scheduleFile(id);
      if (await file.exists()) {
        await file.delete();
      }
    });
  }

  Future<void> markTriggered(String id, DateTime at) async {
    await _withWriteLock(() async {
      final current = await _getScheduleUnlocked(id);
      if (current == null) {
        return;
      }
      final updated = current.copyWith(
        updatedAt: at,
        lastTriggeredAt: at,
      );
      await _saveScheduleUnlocked(updated);
    });
  }

  Future<void> _saveScheduleUnlocked(ScheduleModel schedule) async {
    final errors = schedule.validate();
    if (errors.isNotEmpty) {
      throw FormatException(errors.first);
    }
    final file = await _scheduleFile(schedule.id);
    await file.writeAsString(jsonEncode(schedule.toJson()));
  }

  Future<Directory> _schedulesDir() async {
    final docs = await _documentsDirectoryProvider();
    final dir = Directory('${docs.path}${Platform.pathSeparator}schedules');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _scheduleFile(String id) async {
    final dir = await _schedulesDir();
    return File('${dir.path}${Platform.pathSeparator}$id.json');
  }

  Future<ScheduleModel?> _getScheduleUnlocked(String id) async {
    final file = await _scheduleFile(id);
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ScheduleModel.fromJson(json);
  }

  Future<void> _awaitPendingWrites() async {
    await _writeQueue;
  }

  Future<T> _withWriteLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
