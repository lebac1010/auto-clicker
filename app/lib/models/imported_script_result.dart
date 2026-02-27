import 'package:auto_clicker/models/script_model.dart';

class ImportedScriptResult {
  const ImportedScriptResult({
    required this.scripts,
    required this.format,
  });

  final List<ScriptModel> scripts;
  final String format;
}
