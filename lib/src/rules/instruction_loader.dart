import 'dart:io';
import 'package:path/path.dart' as p;

/// Loads debate instructions from global, project, and domain-specific paths.
class InstructionLoader {
  /// Creates an [InstructionLoader].
  const InstructionLoader();

  /// Loads instructions in precedence order and deduplicates by path.
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
          instructions.add(
            LoadedInstruction(
              path: path,
              source: source,
              content: content,
            ),
          );
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
      homeDir =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
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

  /// Builds a markdown bundle that can be sent as an agent prompt preamble.
  String generateAgentInstructions(List<LoadedInstruction> instructions) {
    final buffer = StringBuffer();
    for (final instruction in instructions) {
      buffer.writeln(
        '## ${instruction.source.label}: ${p.basename(instruction.path)}',
      );
      buffer.writeln();
      buffer.writeln(instruction.content);
      buffer.writeln();
    }
    return buffer.toString();
  }
}

/// Origin category for a loaded instruction file.
enum InstructionSource {
  /// Built-in protocol defaults.
  protocol('Protocol defaults'),

  /// User-level instructions in home directory.
  global('Global user instructions'),

  /// Project-level instructions.
  project('Project instructions'),

  /// Domain rules from `.walki/rules/`.
  domain('Domain rules'),

  /// Extra files configured in `config.yaml`.
  config('Config instructions'),

  /// Channel-specific instruction files.
  channel('Channel instructions'),

  /// Architecture guidance from `sdd-ai/`.
  sddAi('SDD-AI architecture');

  /// Creates an [InstructionSource] with a human-readable label.
  const InstructionSource(this.label);

  /// Display label used in generated instruction bundles.
  final String label;
}

/// Instruction file contents plus source metadata.
class LoadedInstruction {
  /// Creates a [LoadedInstruction].
  const LoadedInstruction({
    required this.path,
    required this.source,
    required this.content,
  });

  /// Absolute file path of the instruction.
  final String path;

  /// Source category used for precedence and reporting.
  final InstructionSource source;

  /// Full file contents.
  final String content;

  /// Formats this instruction as a markdown list item.
  String toMarkdownListItem() => '- $path (${source.label})';
}
