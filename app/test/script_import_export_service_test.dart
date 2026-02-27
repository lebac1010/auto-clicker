import 'dart:convert';
import 'dart:io';

import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:auto_clicker/services/script_import_export_service.dart';
import 'package:auto_clicker/services/script_schema_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late ScriptRepository repository;
  late ScriptImportExportService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ac_import_export_test_');
    repository = ScriptRepository(
      documentsDirectoryProvider: () async => tempDir,
    );
    service = ScriptImportExportService(
      repository: repository,
      exportsDirectoryProvider: () async =>
          Directory('${tempDir.path}${Platform.pathSeparator}exports'),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ScriptModel makeScript(String id, String name) {
    final now = DateTime(2026, 2, 10, 12, 0, 0);
    return ScriptModel(
      id: id,
      name: name,
      type: ScriptType.multiTap,
      createdAt: now,
      updatedAt: now,
      defaultIntervalMs: 300,
      loopCount: 1,
      steps: const [
        ScriptStep(id: 'step_1', x: 0.2, y: 0.3, intervalMs: 120, enabled: true),
      ],
    );
  }

  Future<String> writeJsonFile(String name, Map<String, dynamic> payload) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(jsonEncode(payload));
    return file.path;
  }

  test('import rejects payload with schemaVersion when schema fields are missing', () async {
    final path = await writeJsonFile('internal_like_schema.json', {
      'schemaVersion': '1.0',
      'id': 'scr_internal',
      'name': 'Internal Script',
      'type': 'multi_tap',
      'createdAt': '2026-02-10T12:00:00Z',
      'updatedAt': '2026-02-10T12:00:00Z',
      'defaultIntervalMs': 300,
      'loopCount': 1,
      'steps': [
        {
          'id': 'step_1',
          'x': 0.4,
          'y': 0.5,
          'intervalMs': 90,
          'enabled': true,
        },
      ],
    });

    await expectLater(
      service.importFile(path),
      throwsA(isA<FormatException>()),
    );

    final scripts = await repository.listScripts();
    expect(scripts, isEmpty);
  });

  test('import rejects malformed schema payload and keeps repository unchanged', () async {
    final path = await writeJsonFile('bad_schema.json', {
      'schemaVersion': '1.0',
      'id': 'scr_bad',
      'name': 'Bad',
      'type': 'multi_tap',
      'createdAt': '2026-02-10T12:00:00Z',
      'updatedAt': '2026-02-10T12:00:00Z',
      'coordinateMode': 'normalized',
      'screen': {
        'widthPx': 1080,
        'heightPx': 2400,
        'densityDpi': 420,
        'rotation': 0,
        'insets': {
          'topPx': 0,
          'bottomPx': 0,
          'leftPx': 0,
          'rightPx': 0,
        },
      },
      'loop': {
        'mode': 'count',
        'count': 1,
      },
      'defaults': {
        'intervalMs': 300,
        'holdMs': 40,
        'jitterPx': 0,
        'randomDelayMsMin': 0,
        'randomDelayMsMax': 0,
      },
      'steps': [
        {
          'id': 'step_1',
          'type': 'tap',
          // Missing x on purpose.
          'y': 0.3,
          'enabled': true,
        },
      ],
    });

    await expectLater(
      service.importFile(path),
      throwsA(isA<FormatException>()),
    );

    final scripts = await repository.listScripts();
    expect(scripts, isEmpty);
  });

  test('import resolves duplicate id and name deterministically', () async {
    final existing = makeScript('scr_dup', 'Duplicate Name');
    await repository.saveScript(existing);

    final path = await writeJsonFile('duplicate_internal.json', {
      'id': 'scr_dup',
      'name': 'Duplicate Name',
      'type': 'multi_tap',
      'createdAt': '2026-02-10T12:00:00Z',
      'updatedAt': '2026-02-10T12:00:00Z',
      'defaultIntervalMs': 300,
      'loopCount': 1,
      'steps': [
        {
          'id': 'step_1',
          'x': 0.2,
          'y': 0.2,
          'intervalMs': 100,
          'enabled': true,
        },
      ],
    });

    final result = await service.importFile(path);
    final imported = result.scripts.single;

    expect(imported.id, isNot('scr_dup'));
    expect(imported.id, startsWith('scr_dup_imported'));
    expect(imported.name, isNot('Duplicate Name'));
    expect(imported.name, startsWith('Duplicate Name (Imported'));
  });

  test('import detects schemaV1 payload and parses successfully', () async {
    final schema = ScriptSchemaMapper.toSchemaV1(makeScript('scr_schema', 'Schema Script'));
    final path = await writeJsonFile('schema_v1.json', schema);

    final result = await service.importFile(path);
    expect(result.format, 'schemaV1');
    expect(result.scripts.single.name, 'Schema Script');
  });

  test('import rejects unsupported schema version', () async {
    final path = await writeJsonFile('bad_schema_version.json', {
      'schemaVersion': '2.0',
      'id': 'scr_future',
      'name': 'Future Schema',
      'type': 'multi_tap',
      'steps': [],
    });

    await expectLater(
      service.importFile(path),
      throwsA(isA<FormatException>()),
    );
  });
}
