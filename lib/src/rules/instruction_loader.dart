import 'dart:io';
import 'package:path/path.dart' as p;

class InstructionLoader {
  const InstructionLoader();

  List<LoadedInstruction> load({
    required String projectDir,
    List<String> configPaths = const [],
    List<String> channelPaths = const [],
  }) {
    final instructions = <LoadedInstruction>[];
    final seen = <String>{};

    void addIfNotSeen(String path, InstructionSource source) {
      final file = File(path);
      if (file.existsSync() && !seen.contains(path)) {
        seen.add(path);
        final content = file.readAsStringSync();
        if (content.trim().isNotEmpty) {
          instructions.add(LoadedInstruction(
            path: path,
            source: source,
            content: content,
          ),);
        }
      }
    }

    void addGlob(String pattern, InstructionSource source) {
      final dir = Directory(p.dirname(pattern));
      if (!dir.existsSync()) return;
      final glob = p.basename(pattern);
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final basename = p.basename(entity.path);
          if (_globMatch(glob, basename)) {
            addIfNotSeen(entity.path, source);
          }
        }
      }
    }

    String? homeDir;
    try {
      homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    } catch (_) {}

    if (homeDir != null) {
      addIfNotSeen(
        p.join(homeDir, '.walki', 'instructions.md'),
        InstructionSource.global,
      );
    }

    addIfNotSeen(
      p.join(projectDir, '.walki', 'instructions.md'),
      InstructionSource.project,
    );

    addGlob(
      p.join(projectDir, '.walki', 'rules', '*.md'),
      InstructionSource.domain,
    );

    if (Directory(p.join(projectDir, 'sdd-ai', 'architecture')).existsSync()) {
      addGlob(
        p.join(projectDir, 'sdd-ai', 'architecture', '*.md'),
        InstructionSource.sddAi,
      );
    }

    for (final configPath in configPaths) {
      addIfNotSeen(
        p.join(projectDir, configPath),
        InstructionSource.config,
      );
    }

    for (final channelPath in channelPaths) {
      addIfNotSeen(
        p.join(projectDir, channelPath),
        InstructionSource.channel,
      );
    }

    addIfNotSeen(
      p.join(projectDir, 'AGENTS.md'),
      InstructionSource.project,
    );
    addIfNotSeen(
      p.join(projectDir, 'CLAUDE.md'),
      InstructionSource.project,
    );
    addIfNotSeen(
      p.join(projectDir, 'GEMINI.md'),
      InstructionSource.project,
    );

    return instructions;
  }

  bool _globMatch(String pattern, String name) {
    if (pattern == '*.md') return name.endsWith('.md');
    if (pattern == '*') return true;
    return name == pattern;
  }

  String generateAgentInstructions(List<LoadedInstruction> instructions) {
    final buffer = StringBuffer();
    for (final instruction in instructions) {
      buffer.writeln('## ${instruction.source.label}: ${p.basename(instruction.path)}');
      buffer.writeln();
      buffer.writeln(instruction.content);
      buffer.writeln();
    }
    return buffer.toString();
  }
}

enum InstructionSource {
  protocol('Protocol defaults'),
  global('Global user instructions'),
  project('Project instructions'),
  domain('Domain rules'),
  config('Config instructions'),
  channel('Channel instructions'),
  sddAi('SDD-AI architecture');

  const InstructionSource(this.label);
  final String label;
}

class LoadedInstruction {
  const LoadedInstruction({
    required this.path,
    required this.source,
    required this.content,
  });

  final String path;
  final InstructionSource source;
  final String content;

  String toMarkdownListItem() => '- $path (${source.label})';
}