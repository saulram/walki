import 'dart:io';

class EditorLauncher {
  const EditorLauncher();

  List<String> get candidates {
    final values = <String>[];
    final visual = Platform.environment['VISUAL'];
    final editor = Platform.environment['EDITOR'];
    if (visual != null && visual.trim().isNotEmpty) {
      values.add(visual.trim());
    }
    if (editor != null && editor.trim().isNotEmpty && editor.trim() != visual) {
      values.add(editor.trim());
    }
    values.addAll(['micro', 'nano', 'vim', 'vi']);
    return values;
  }

  String? resolve([String? requested]) {
    final options = requested == null || requested.trim().isEmpty
        ? candidates
        : [requested.trim(), ...candidates];

    for (final candidate in options) {
      final command = _splitCommand(candidate).firstOrNull;
      if (command == null) {
        continue;
      }
      if (_which(command) != null) {
        return candidate;
      }
    }
    return null;
  }

  Future<int> open(String filePath, {String? editor}) async {
    final resolved = resolve(editor);
    if (resolved == null) {
      throw StateError(
        'No editor found. Set VISUAL or EDITOR, or install micro, nano, vim, or vi.',
      );
    }

    final parts = _splitCommand(resolved);
    final executable = parts.first;
    final args = [...parts.skip(1), filePath];
    final process = await Process.start(
      executable,
      args,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  List<String> _splitCommand(String command) {
    return command
        .split(RegExp(r'\s+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  String? _which(String command) {
    final result = Process.runSync('which', [command]);
    if (result.exitCode != 0) {
      return null;
    }
    final output = result.stdout.toString().trim();
    return output.isEmpty ? null : output;
  }
}
