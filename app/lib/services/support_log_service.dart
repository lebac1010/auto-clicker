import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SupportLogService {
  SupportLogService._();

  static const int _maxInMemoryEntries = 500;
  static final List<String> _entries = <String>[];
  static Future<void> _writeQueue = Future<void>.value();

  static void logInfo(String source, String message, {Map<String, Object?> data = const {}}) {
    _append('INFO', source, message, data: data);
  }

  static void logError(
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> data = const {},
  }) {
    final merged = <String, Object?>{
      ...data,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
    _append('ERROR', source, message, data: merged);
  }

  static Future<String> exportLogs({
    String reason = 'manual_export',
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    final dir = await _logsDir();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'generatedAt': now,
      'reason': reason,
      if (metadata.isNotEmpty) 'metadata': metadata,
      'entries': List<String>.from(_entries),
    };
    final file = File(
      '${dir.path}${Platform.pathSeparator}support_log_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file.path;
  }

  static void _append(
    String level,
    String source,
    String message, {
    required Map<String, Object?> data,
  }) {
    final row = jsonEncode(<String, dynamic>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'source': source,
      'message': message,
      'data': data,
    });
    _entries.add(row);
    if (_entries.length > _maxInMemoryEntries) {
      _entries.removeAt(0);
    }
    _writeQueue = _writeQueue.then((_) => _appendToSessionFile(row));
  }

  static Future<void> _appendToSessionFile(String row) async {
    try {
      final file = await _sessionFile();
      await file.writeAsString('$row\n', mode: FileMode.append);
    } catch (_) {
      // Keep logging non-blocking even when file writes fail.
    }
  }

  static Future<File> _sessionFile() async {
    final dir = await _logsDir();
    return File('${dir.path}${Platform.pathSeparator}session.log');
  }

  static Future<Directory> _logsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}support_logs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
