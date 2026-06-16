import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../agents/agent_prompts.dart';
import '../config/walki_config.dart';
import '../config/agent_config.dart';
import 'artifact_id.dart';

/// Filesystem operations for creating and managing a `.walki/` workspace.
class Workspace {
  /// Creates a [Workspace].
  const Workspace();

  /// Root directory name used by Walki.
  static const String walkiDir = '.walki';

  /// Workspace configuration filename.
  static const String configFileName = 'config.yaml';

  /// Project-level instructions filename.
  static const String instructionsFileName = 'instructions.md';

  /// Relative directory for agent metadata files.
  static const String agentsDir = 'agents';

  /// Relative directory for debate rules files.
  static const String rulesDir = 'rules';

  /// Relative directory for channel markdown files.
  static const String channelsDir = 'channels';

  /// Relative directory for promoted decision files.
  static const String decisionsDir = 'decisions';

  /// Relative directory for generated task files.
  static const String tasksDir = 'tasks';

  /// Relative directory for generated state files.
  static const String stateDir = 'state';

  /// Relative directory for channel lock files.
  static const String locksDir = 'locks';

  /// Returns whether a `.walki/` workspace exists.
  bool isInitialized([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    return Directory(p.join(dir, walkiDir)).existsSync();
  }

  /// Returns whether an `sdd-ai/` directory exists in the project.
  bool hasSddAi([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    return Directory(p.join(dir, 'sdd-ai')).existsSync();
  }

  /// Loads and parses `.walki/config.yaml`.
  ///
  /// Throws [StateError] if the workspace is not initialized.
  WalkiConfig loadConfig([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final configFile = File(p.join(dir, walkiDir, configFileName));
    if (!configFile.existsSync()) {
      throw StateError(
        'Walki workspace not initialized. Run `walki init` first.',
      );
    }
    final content = configFile.readAsStringSync();
    final yaml = loadYaml(content) as Map;
    return WalkiConfig.fromYaml(yaml);
  }

  /// Saves [config] into `.walki/config.yaml`.
  void saveConfig(WalkiConfig config, [String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final configFile = File(p.join(dir, walkiDir, configFileName));
    final yamlContent = _mapToYamlString(config.toYaml());
    configFile.writeAsStringSync(yamlContent);
  }

  /// Creates a new Walki workspace and returns the absolute workspace path.
  String init({
    String? projectDir,
    String template = 'minimal',
    List<String> agentNames = const ['codex', 'claude'],
    Map<String, AgentConfig>? agentConfigs,
    bool sddAi = false,
    List<String>? starterRules,
  }) {
    final dir = projectDir ?? Directory.current.path;
    final projectName = p.basename(dir);

    final baseDir = p.join(dir, walkiDir);
    if (Directory(baseDir).existsSync()) {
      throw StateError('Walki workspace already exists at $baseDir');
    }

    Directory(p.join(dir, walkiDir)).createSync();
    Directory(p.join(dir, walkiDir, agentsDir)).createSync();
    Directory(p.join(dir, walkiDir, rulesDir)).createSync();
    Directory(p.join(dir, walkiDir, channelsDir)).createSync();
    Directory(p.join(dir, walkiDir, decisionsDir)).createSync();
    Directory(p.join(dir, walkiDir, tasksDir)).createSync();
    Directory(p.join(dir, walkiDir, stateDir)).createSync();
    Directory(p.join(dir, walkiDir, locksDir)).createSync();

    final agents = <String, AgentConfig>{};
    final configuredAgents = agentConfigs ?? <String, AgentConfig>{};
    final effectiveAgentNames = configuredAgents.isNotEmpty
        ? configuredAgents.keys.toList()
        : agentNames;
    for (final name in effectiveAgentNames) {
      if (normalizeArtifactId(name) == null) {
        throw ArgumentError.value(name, 'agentNames', 'Invalid agent ID.');
      }
      final agentConfig = configuredAgents[name] ??
          (name == 'codex'
              ? AgentConfig.implementer()
              : name == 'claude'
                  ? AgentConfig.reviewer()
                  : AgentConfig(
                      role: 'implementer',
                      can: [
                        'read',
                        'append',
                        'propose_decision',
                        'propose_task',
                      ],
                    ));
      agents[name] = agentConfig;
      File(p.join(dir, walkiDir, agentsDir, '$name.md'))
          .writeAsStringSync(generateAgentMarkdown(name, agentConfig));
    }
    agents['human'] = AgentConfig.owner();
    File(p.join(dir, walkiDir, agentsDir, 'human.md'))
        .writeAsStringSync(generateAgentMarkdown('human', AgentConfig.owner()));

    final config = WalkiConfig(
      project: ProjectConfig(name: projectName),
      agents: agents,
      sddAi: SddAiConfig(enabled: sddAi || template == 'sdd' || hasSddAi(dir)),
    );
    saveConfig(config, dir);

    File(p.join(dir, walkiDir, instructionsFileName))
        .writeAsStringSync(_defaultInstructions);

    final rulesToCreate = starterRules ?? ['security', 'code-style'];
    if (template == 'minimal' || template == 'sdd') {
      for (final ruleName in rulesToCreate) {
        final rulePath = p.join(dir, walkiDir, rulesDir, '$ruleName.md');
        final content = switch (ruleName) {
          'security' => _defaultSecurityRules,
          'code-style' => _defaultCodeStyleRules,
          'testing' => _defaultTestingRules,
          'sdd-ai' => _defaultSddAiRules,
          _ => _defaultNamedRule(ruleName),
        };
        File(rulePath).writeAsStringSync(content);
      }
    }

    File(p.join(dir, walkiDir, stateDir, 'index.yaml'))
        .writeAsStringSync('channels: []\ndecisions: []\ntasks: []\n');

    return baseDir;
  }

  String _mapToYamlString(Map<String, dynamic> map, [int indent = 0]) {
    final buffer = StringBuffer();
    final prefix = '  ' * indent;

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        buffer.writeln('$prefix$key:');
        buffer.write(_mapToYamlString(value, indent + 1));
      } else if (value is List) {
        buffer.writeln('$prefix$key:');
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            buffer.writeln('$prefix  - ');
            buffer.write(_mapToYamlString(item, indent + 2));
          } else {
            buffer.writeln('$prefix  - $item');
          }
        }
      } else if (value is String) {
        if (value.contains('\n') ||
            value.contains(':') ||
            value.contains('#')) {
          buffer.writeln('$prefix$key: "$value"');
        } else {
          buffer.writeln('$prefix$key: $value');
        }
      } else if (value is bool) {
        buffer.writeln('$prefix$key: ${value.toString()}');
      } else {
        buffer.writeln('$prefix$key: $value');
      }
    }

    return buffer.toString();
  }

  static const _defaultInstructions = '''# Walki Project Instructions

All agent debates must follow these rules:

- Prefer simple architecture over clever abstractions.
- Every accepted decision must include risks.
- Every implementation proposal must include tests.
- Security-sensitive changes require explicit security review.
- Do not propose new dependencies unless necessary.
''';

  static const _defaultSecurityRules = '''# Security Rules

For auth, payments, user data, permissions, or encryption:

- Identify abuse cases.
- Identify data leakage risks.
- Require test coverage for negative cases.
- Never accept a proposal without rollback strategy.
- Prefer deny-by-default authorization.
''';

  static const _defaultCodeStyleRules = '''# Code Style Rules

- Prefer small modules.
- Avoid global mutable state.
- Keep public APIs documented.
- Do not introduce frameworks without justification.
- Prefer existing project patterns.
''';

  static const _defaultTestingRules = '''# Testing Rules

- Add targeted tests for behavior changes.
- Run the smallest relevant test suite before full validation.
- Include negative cases for permission, auth, parsing, and data-boundary changes.
- Document any checks that could not be run and why.
''';

  static const _defaultSddAiRules = '''# sdd-ai Rules

- Promote only accepted Walki decisions into sdd-ai artifacts.
- Include rationale, risks, implementation tasks, and required validation.
- Keep generated specs actionable enough for any supported agent to implement.
- Do not bypass human acceptance before promotion.
''';

  static String _defaultNamedRule(String name) {
    final title = name
        .split('-')
        .map(
          (word) =>
              word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
    return '# $title Rules\n\n- Add project-specific guidance here.\n';
  }
}
