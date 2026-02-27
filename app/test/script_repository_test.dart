import 'dart:io';

import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/models/script_step.dart';
import 'package:auto_clicker/models/script_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ac_repo_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ScriptRepository makeRepo({
    Future<void> Function(File file, String content)? writer,
  }) {
    return ScriptRepository(
      documentsDirectoryProvider: () async => tempDir,
      writeFile: writer,
    );
  }

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
        ScriptStep(id: 'step_1', x: 0.5, y: 0.5, intervalMs: 100, enabled: true),
      ],
    );
  }

  test('saveAtomically rolls back previously written files when later write fails', () async {
    var writeCount = 0;
    final repo = makeRepo(
      writer: (file, content) async {
        writeCount += 1;
        if (writeCount == 2) {
          throw const FileSystemException('injected write failure');
        }
        await file.writeAsString(content);
      },
    );

    final scripts = [
      makeScript('scr_one', 'One'),
      makeScript('scr_two', 'Two'),
    ];

    await expectLater(
      repo.saveAtomically(scripts),
      throwsA(isA<FileSystemException>()),
    );

    final remaining = await repo.listScripts();
    expect(remaining, isEmpty);
  });

  test('markRun updates both lastRunAt and updatedAt', () async {
    final repo = makeRepo();
    final script = makeScript('scr_mark', 'Mark');
    await repo.saveScript(script);

    await repo.markRun(script.id);
    final updated = await repo.getScript(script.id);

    expect(updated, isNotNull);
    expect(updated!.lastRunAt, isNotNull);
    expect(updated.updatedAt.isBefore(script.updatedAt), isFalse);
  });
}
