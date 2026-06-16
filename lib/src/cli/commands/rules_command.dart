import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../channels/channel.dart';
import '../../channels/channel_formatter.dart';
import '../../channels/channel_parser.dart';
import '../../cli/editor_launcher.dart';
import '../../config/walki_config.dart';
import '../../storage/workspace.dart';

class RulesCommand extends Command<int> {
  RulesCommand({required this.logger}) {
    addSubcommand(RulesAddSubcommand(logger: logger));
    addSubcommand(RulesListSubcommand(logger: logger));
    addSubcommand(RulesShowSubcommand(logger: logger));
    addSubcommand(RulesEditSubcommand(logger: logger));
    addSubcommand(RulesRemoveSubcommand(logger: logger));
    addSubcommand(RulesDraftSubcommand(logger: logger));
    addSubcommand(RulesApplySubcommand(logger: logger));
  }

  final Logger logger;

  @override
  String get name => 'rules';

  @override
  String get description => 'Manage project rules.';

  @override
  Future<int> run() async {
    logger.err(
        'Please specify a subcommand: add, list, show, edit, remove, draft, apply');
    printUsage();
    return 1;
  }
}

class RulesAddSubcommand extends Command<int> {
  RulesAddSubcommand({required this.logger}) {
    argParser.addOption(
      'description',
      abbr: 'd',
      help: 'Rule description',
      defaultsTo: '',
    );
  }

  final Logger logger;

  @override
  String get name => 'add';

  @override
  String get description => 'Add a new rule file.';

  @override
  Future<int> run() async {
    final loaded = _loadWorkspace(logger);
    if (loaded == null) {
      return 1;
    }
    final name = argResults?.rest.firstOrNull;
    if (name == null) {
      logger.err('Usage: walki rules add <name>');
      return 1;
    }
    final normalized = _normalizeRuleName(name);
    if (normalized == null) {
      logger.err(
          'Invalid rule name "$name". Use letters, numbers, dot, underscore, or dash.');
      return 1;
    }

    final ruleFile = _ruleFile(loaded.config, normalized);
    if (ruleFile.existsSync()) {
      logger.err('Rule "$normalized" already exists.');
      return 1;
    }

    final description = argResults?['description'] as String? ?? '';
    ruleFile.parent.createSync(recursive: true);
    ruleFile.writeAsStringSync(_newRuleContent(normalized, description));

    logger.info(green.wrap('Created rule: ${ruleFile.path}'));
    logger.info(
        'Edit this file with ${lightCyan.wrap('walki rules edit $normalized')}.');
    return 0;
  }
}

class RulesListSubcommand extends Command<int> {
  RulesListSubcommand({required this.logger});

  final Logger logger;

  @override
  String get name => 'list';

  @override
  String get description => 'List project rules.';

  @override
  Future<int> run() async {
    final loaded = _loadWorkspace(logger);
    if (loaded == null) {
      return 1;
    }
    final files = _ruleFiles(loaded.config);
    if (files.isEmpty) {
      logger.info('No rules found.');
      return 0;
    }

    logger.info('Rules:');
    for (final file in files) {
      final name = p.basenameWithoutExtension(file.path);
      final description = _firstBodyLine(file.readAsStringSync());
      logger.info(
          '  - $name (${file.path})${description == null ? '' : ' - $description'}');
    }
    return 0;
  }
}

class RulesShowSubcommand extends Command<int> {
  RulesShowSubcommand({required this.logger});

  final Logger logger;

  @override
  String get name => 'show';

  @override
  String get description => 'Show a project rule file.';

  @override
  Future<int> run() async {
    final file = _loadRuleFile(logger, argResults?.rest.firstOrNull);
    if (file == null) {
      return 1;
    }
    logger.info(file.readAsStringSync());
    return 0;
  }
}

class RulesEditSubcommand extends Command<int> {
  RulesEditSubcommand({required this.logger}) {
    argParser
      ..addOption('editor', help: 'Editor command to use')
      ..addFlag('create',
          abbr: 'c',
          help: 'Create the rule if it does not exist',
          defaultsTo: false);
  }

  final Logger logger;

  @override
  String get name => 'edit';

  @override
  String get description => 'Open a project rule file in your editor.';

  @override
  Future<int> run() async {
    final loaded = _loadWorkspace(logger);
    if (loaded == null) {
      return 1;
    }
    final name = argResults?.rest.firstOrNull;
    final normalized = name == null ? null : _normalizeRuleName(name);
    if (normalized == null) {
      logger.err('Usage: walki rules edit <name>');
      return 1;
    }
    final file = _ruleFile(loaded.config, normalized);
    if (!file.existsSync()) {
      final create = argResults?['create'] as bool? ?? false;
      if (!create &&
          !_confirm('Rule "$normalized" does not exist. Create it? [y/N] ')) {
        logger.info('Edit cancelled.');
        return 0;
      }
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(_newRuleContent(normalized, ''));
    }

    try {
      final exitCode = await const EditorLauncher().open(
        file.path,
        editor: argResults?['editor'] as String?,
      );
      if (exitCode != 0) {
        logger.err('Editor exited with code $exitCode.');
        return exitCode;
      }
    } catch (e) {
      logger.err(e.toString());
      logger.info('Rule file: ${file.path}');
      return 1;
    }
    logger.info(green.wrap('Rule "$normalized" saved.'));
    return 0;
  }
}

class RulesRemoveSubcommand extends Command<int> {
  RulesRemoveSubcommand({required this.logger}) {
    argParser.addFlag('yes',
        abbr: 'y', help: 'Skip confirmation', defaultsTo: false);
  }

  final Logger logger;

  @override
  String get name => 'remove';

  @override
  List<String> get aliases => const ['rm'];

  @override
  String get description => 'Remove a project rule file.';

  @override
  Future<int> run() async {
    final file = _loadRuleFile(logger, argResults?.rest.firstOrNull);
    if (file == null) {
      return 1;
    }
    final yes = argResults?['yes'] as bool? ?? false;
    if (!yes &&
        !_confirm(
            'Remove rule "${p.basenameWithoutExtension(file.path)}"? [y/N] ')) {
      logger.info('Removal cancelled.');
      return 0;
    }
    file.deleteSync();
    logger.info(green.wrap('Removed rule: ${file.path}'));
    return 0;
  }
}

class RulesDraftSubcommand extends Command<int> {
  RulesDraftSubcommand({required this.logger}) {
    argParser
      ..addOption('channel',
          abbr: 'c',
          help: 'Draft debate channel ID',
          defaultsTo: 'rules-bootstrap')
      ..addOption('agents',
          abbr: 'a', help: 'Comma-separated agents to draft and review rules')
      ..addOption('max-turns',
          abbr: 'm', help: 'Maximum debate turns', defaultsTo: '6');
  }

  final Logger logger;

  @override
  String get name => 'draft';

  @override
  String get description =>
      'Create a debate for agents to draft repo-specific rules.';

  @override
  Future<int> run() async {
    final loaded = _loadWorkspace(logger);
    if (loaded == null) {
      return 1;
    }
    final channelId = argResults?['channel'] as String? ?? 'rules-bootstrap';
    final agentsRaw = argResults?['agents'] as String?;
    final participants = agentsRaw == null || agentsRaw.trim().isEmpty
        ? loaded.config.agents.keys.where((agent) => agent != 'human').toList()
        : _splitList(agentsRaw);
    final maxTurns =
        int.tryParse(argResults?['max-turns'] as String? ?? '6') ?? 6;
    final channelFile =
        File(p.join(loaded.config.storage.channelDir, '$channelId.md'));
    if (channelFile.existsSync()) {
      logger.err('Channel "$channelId" already exists.');
      return 1;
    }

    final instructionFiles = _detectInstructionFiles();
    final prompt = _rulesDraftPrompt(instructionFiles);
    final channel = Channel(
      id: channelId,
      status: ChannelStatus.open,
      createdAt: DateTime.now(),
      participants: participants,
      prompt: prompt,
      loadedInstructions: instructionFiles,
      workingRules: const [
        'Read the detected instruction files before proposing rules.',
        'Propose concrete .walki/rules/*.md files.',
        'Use fenced blocks with ```walki-rule name=<rule-name>.',
        'Challenge vague, duplicate, or conflicting rules.',
        'Human approval is required before applying generated rules.',
      ],
      maxTurns: maxTurns,
    );
    channelFile.parent.createSync(recursive: true);
    channelFile.writeAsStringSync(const ChannelFormatter().format(channel));

    logger.info(green.wrap('Created rule draft channel: ${channelFile.path}'));
    logger.info('Participants: ${participants.join(', ')}');
    logger.info(
        'Detected instruction files: ${instructionFiles.isEmpty ? 'none' : instructionFiles.join(', ')}');
    logger.info(
        'After acceptance, run ${lightCyan.wrap('walki rules apply $channelId')}.');
    return 0;
  }
}

class RulesApplySubcommand extends Command<int> {
  RulesApplySubcommand({required this.logger}) {
    argParser.addFlag('yes',
        abbr: 'y', help: 'Skip confirmation', defaultsTo: false);
  }

  final Logger logger;

  @override
  String get name => 'apply';

  @override
  String get description => 'Apply accepted rule blocks from a draft debate.';

  @override
  Future<int> run() async {
    final loaded = _loadWorkspace(logger);
    if (loaded == null) {
      return 1;
    }
    final channelId = argResults?.rest.firstOrNull;
    if (channelId == null) {
      logger.err('Usage: walki rules apply <channel>');
      return 1;
    }
    final channelFile =
        File(p.join(loaded.config.storage.channelDir, '$channelId.md'));
    if (!channelFile.existsSync()) {
      logger.err('Channel "$channelId" not found.');
      return 1;
    }
    final content = channelFile.readAsStringSync();
    final channel = const ChannelParser().parse(content);
    if (channel.status != ChannelStatus.accepted) {
      logger.err(
          'Channel "$channelId" must be accepted before applying rules. Current status: ${channel.status.toYamlValue()}');
      return 1;
    }

    final rules = _extractRuleBlocks(content);
    if (rules.isEmpty) {
      logger.err(
          'No rule blocks found. Expected fenced blocks like ```walki-rule name=security.');
      return 1;
    }
    logger.info('Rules to apply: ${rules.keys.join(', ')}');
    final yes = argResults?['yes'] as bool? ?? false;
    if (!yes &&
        !_confirm(
            'Write these rules to ${loaded.config.storage.rulesDir}? [y/N] ')) {
      logger.info('Apply cancelled.');
      return 0;
    }
    for (final entry in rules.entries) {
      final file = _ruleFile(loaded.config, entry.key);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value.trimRight() + '\n');
      logger.info(green.wrap('Wrote ${file.path}'));
    }
    return 0;
  }
}

class _LoadedWorkspace {
  const _LoadedWorkspace(this.config);
  final WalkiConfig config;
}

_LoadedWorkspace? _loadWorkspace(Logger logger) {
  final workspace = const Workspace();
  if (!workspace.isInitialized()) {
    logger.err(
        'Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
    return null;
  }
  try {
    return _LoadedWorkspace(workspace.loadConfig());
  } catch (e) {
    logger.err('Failed to load config: $e');
    return null;
  }
}

File? _loadRuleFile(Logger logger, String? name) {
  final loaded = _loadWorkspace(logger);
  if (loaded == null) {
    return null;
  }
  final normalized = name == null ? null : _normalizeRuleName(name);
  if (normalized == null) {
    logger.err('Usage: walki rules <command> <name>');
    return null;
  }
  final file = _ruleFile(loaded.config, normalized);
  if (!file.existsSync()) {
    logger.err('Rule "$normalized" not found.');
    return null;
  }
  return file;
}

File _ruleFile(WalkiConfig config, String name) {
  return File(p.join(config.storage.rulesDir, '$name.md'));
}

List<File> _ruleFiles(WalkiConfig config) {
  final dir = Directory(config.storage.rulesDir);
  if (!dir.existsSync()) {
    return const [];
  }
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String? _normalizeRuleName(String raw) {
  final value = raw.trim().replaceAll(RegExp(r'\.md$'), '');
  if (value.isEmpty ||
      value.contains('..') ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value)) {
    return null;
  }
  return value;
}

String _newRuleContent(String name, String description) {
  final title = name
      .split('-')
      .map((word) =>
          word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
      .join(' ');
  return '# $title Rules\n\n${description.isNotEmpty ? '$description\n\n' : ''}- Add project-specific guidance here.\n';
}

String? _firstBodyLine(String content) {
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    return trimmed.length > 80 ? '${trimmed.substring(0, 77)}...' : trimmed;
  }
  return null;
}

bool _confirm(String label) {
  stdout.write(label);
  final response = stdin.readLineSync()?.trim().toLowerCase();
  return response == 'y' || response == 'yes';
}

List<String> _splitList(String raw) {
  return raw
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

List<String> _detectInstructionFiles() {
  final files = <String>[];
  final candidates = <String>[
    'AGENTS.md',
    'CLAUDE.md',
    'GEMINI.md',
    '.cursorrules',
    '.github/copilot-instructions.md',
    'README.md',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      files.add(candidate);
    }
  }
  final cursorRules = Directory('.cursor/rules');
  if (cursorRules.existsSync()) {
    files.addAll(
        cursorRules.listSync().whereType<File>().map((file) => file.path));
  }
  final existingRules = Directory('.walki/rules');
  if (existingRules.existsSync()) {
    files.addAll(existingRules
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .map((file) => file.path));
  }
  return files..sort();
}

String _rulesDraftPrompt(List<String> instructionFiles) {
  return '''Create a repo-specific Walki ruleset from the detected instruction files.

Detected files:
${instructionFiles.isEmpty ? '- none' : instructionFiles.map((file) => '- $file').join('\n')}

The proposer should read these files and propose focused .walki/rules/*.md files. The reviewer should challenge vague, duplicate, conflicting, or unenforceable rules.

When the debate has a final proposal, include each rule as a fenced block:

```walki-rule name=security
# Security Rules

- Concrete rule here.
```

Prefer small files such as project, code-style, testing, security, release, and sdd-ai when relevant.''';
}

Map<String, String> _extractRuleBlocks(String content) {
  final blocks = <String, String>{};
  final pattern =
      RegExp(r'```walki-rule\s+name=([A-Za-z0-9._-]+)\s*\n([\s\S]*?)```');
  for (final match in pattern.allMatches(content)) {
    final name = _normalizeRuleName(match.group(1)!);
    final body = match.group(2);
    if (name != null && body != null && body.trim().isNotEmpty) {
      blocks[name] = body;
    }
  }
  return blocks;
}
