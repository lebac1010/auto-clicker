import 'dart:convert';
import 'dart:io';

import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:auto_clicker/models/recorded_step.dart';
import 'package:auto_clicker/services/recorded_script_mapper.dart';
import 'package:auto_clicker/services/script_internal_mapper.dart';
import 'package:auto_clicker/services/script_import_export_service.dart';
import 'package:auto_clicker/services/script_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sourceDir;
  late Directory targetDir;
  late ScriptRepository sourceRepo;
  late ScriptRepository targetRepo;
  late ScriptImportExportService sourceImportExport;
  late ScriptImportExportService targetImportExport;

  setUp(() async {
    sourceDir = await Directory.systemTemp.createTemp('ac_phase9_src_');
    targetDir = await Directory.systemTemp.createTemp('ac_phase9_dst_');
    sourceRepo = ScriptRepository(documentsDirectoryProvider: () async => sourceDir);
    targetRepo = ScriptRepository(documentsDirectoryProvider: () async => targetDir);
    sourceImportExport = ScriptImportExportService(
      repository: sourceRepo,
      exportsDirectoryProvider: () async =>
          Directory('${sourceDir.path}${Platform.pathSeparator}exports'),
    );
    targetImportExport = ScriptImportExportService(
      repository: targetRepo,
      exportsDirectoryProvider: () async =>
          Directory('${targetDir.path}${Platform.pathSeparator}exports'),
    );
  });

  tearDown(() async {
    if (await sourceDir.exists()) {
      await sourceDir.delete(recursive: true);
    }
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
  });

  ScriptModel makeScript({
    required String id,
    required String name,
    required int stepCount,
  }) {
    final now = DateTime(2026, 2, 10, 12, 0, 0);
    final steps = List<ScriptStep>.generate(stepCount, (index) {
      final point = 0.2 + (index * 0.1);
      final normalizedPoint = point.clamp(0.0, 1.0).toDouble();
      return ScriptStep(
        id: 'step_${index + 1}',
        x: normalizedPoint,
        y: normalizedPoint,
        intervalMs: 100 + (index * 10),
        enabled: true,
      );
    });
    return ScriptModel(
      id: id,
      name: name,
      type: ScriptType.multiTap,
      createdAt: now,
      updatedAt: now,
      defaultIntervalMs: 300,
      loopCount: 1,
      steps: steps,
    );
  }

  Future<void> seedSourceScripts() async {
    await sourceRepo.saveScript(makeScript(id: 'scr_a', name: 'Alpha', stepCount: 2));
    await sourceRepo.saveScript(makeScript(id: 'scr_b', name: 'Beta', stepCount: 3));
  }

  test('recorder mapped steps can be persisted and become runnable script', () async {
    final recorded = <RecordedStep>[
      const RecordedStep(
        index: 1,
        action: 'double_tap',
        x: 0.31,
        y: 0.62,
        delayMs: 140,
        holdMs: 85,
      ),
      const RecordedStep(
        index: 2,
        action: 'tap',
        x: 0.55,
        y: 0.21,
        delayMs: 90,
        holdMs: 40,
      ),
    ];

    final created = await sourceRepo.createScript(
      name: 'Recorded Session',
      type: ScriptType.macro,
    );
    final mappedSteps = RecordedScriptMapper.toScriptSteps(recorded);
    final saved = created.copyWith(
      updatedAt: DateTime.now(),
      steps: mappedSteps,
      defaultIntervalMs: 200,
      loopCount: 1,
    );
    await sourceRepo.saveScript(saved);

    final listed = await sourceRepo.listScripts();
    expect(listed.length, 1);
    expect(listed.first.name, 'Recorded Session');
    expect(listed.first.steps.length, 2);
    expect(listed.first.steps.first.action, 'double_tap');
    expect(listed.first.steps.first.holdMs, 85);
    expect(ScriptValidator.validate(listed.first), isEmpty);
  });

  test('schema export-all then import keeps scripts runnable', () async {
    await seedSourceScripts();
    final exportPath = await sourceImportExport.exportAll(ExportFormat.schemaV1);
    final result = await targetImportExport.importFile(exportPath);

    expect(result.format, 'schemaV1');
    expect(result.scripts.length, 2);
    for (final script in result.scripts) {
      expect(script.steps.any((step) => step.enabled), isTrue);
      expect(ScriptValidator.validate(script), isEmpty);
    }

    final targetScripts = await targetRepo.listScripts(sortBy: ScriptSortBy.name);
    expect(targetScripts.map((s) => s.name).toList(), ['Alpha', 'Beta']);
  });

  test('internal export-all then import keeps scripts runnable', () async {
    await seedSourceScripts();
    final exportPath = await sourceImportExport.exportAll(ExportFormat.internal);
    final exportedRoot = jsonDecode(await File(exportPath).readAsString()) as Map<String, dynamic>;
    final exportedScripts = exportedRoot['scripts'] as List<dynamic>;
    final firstScript = Map<String, dynamic>.from(exportedScripts.first as Map);
    expect(firstScript.containsKey('schemaVersion'), isFalse);

    final result = await targetImportExport.importFile(exportPath);

    expect(result.format, 'internal');
    expect(result.scripts.length, 2);
    for (final script in result.scripts) {
      expect(script.steps.any((step) => step.enabled), isTrue);
      expect(ScriptValidator.validate(script), isEmpty);
    }
  });

  test('batch import is atomic when one script is invalid', () async {
    final invalidBatchFile = File(
      '${sourceDir.path}${Platform.pathSeparator}mixed_batch.json',
    );
    final payload = <String, dynamic>{
      'format': 'internal',
      'scripts': [
        ScriptInternalMapper.toMap(makeScript(id: 'scr_ok', name: 'Valid', stepCount: 1)),
        <String, dynamic>{
          'id': 'scr_bad',
          'name': 'Invalid',
          'type': 'multi_tap',
          'createdAt': '2026-02-10T12:00:00Z',
          'updatedAt': '2026-02-10T12:00:00Z',
          'defaultIntervalMs': 300,
          'loopCount': 1,
          'steps': [
            {
              'id': 'step_bad',
              'x': 9.9,
              'y': 0.5,
              'intervalMs': 80,
              'enabled': true,
            },
          ],
        },
      ],
    };
    await invalidBatchFile.writeAsString(jsonEncode(payload));

    await expectLater(
      targetImportExport.importFile(invalidBatchFile.path),
      throwsA(isA<FormatException>()),
    );

    final targetScripts = await targetRepo.listScripts();
    expect(targetScripts, isEmpty);
  });
}
