import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../agents/agent_prompts.dart';
import '../../channels/channel_parser.dart';
import '../../cli/editor_launcher.dart';
import '../../config/agent_config.dart';
import '../../storage/artifact_id.dart';
import '../../storage/workspace.dart';

class AgentCommand extends Command<int> {
  AgentCommand({required this.logger}) {
    addSubcommand(AgentAddSubcommand(logger: logger));
    addSubcommand(AgentListSubcommand(logger: logger));
    addSubcommand(AgentShowSubcommand(logger: logger));
    addSubcommand(AgentPromptSubcommand(logger: logger));
    addSubcommand(AgentEditSubcommand(logger: logger));
    addSubcommand(AgentTuneSubcommand(logger: logger));
    addSubcommand(AgentRemoveSubcommand(logger: logger));
  }

  final Logger logger;

  @override
  String get name => 'agent';

  @override
  String get description => 'Manage agents in the Walki workspace.';

  @override
  Future<int> run() async {
    logger.err(
        'Please specify a subcommand: add, list, show, prompt, edit, tune, remove');
    printUsage();
    return 1;
  }
}

class AgentAddSubcommand extends Command<int> {
  AgentAddSubcommand({required this.logger}) {
    argParser.addOption(
      'role',
      abbr: 'r',
      help: 'Agent role: implementer, reviewer, or owner',
      defaultsTo: 'implementer',
      allowed: ['implementer', 'reviewer', 'owner'],
    );
    argParser.addOption(
      'description',
      abbr: 'd',
      help: 'Agent description',
      defaultsTo: '',
    );
  }

  final Logger logger;

  @override
  String get name => 'add';

  @override
  String get description => 'Add an agent to the Walki workspace.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    if (!_ensureInitialized(workspace, logger)) {
      return 1;
    }

    final agentId = argResults?.rest.firstOrNull;
    if (agentId == null) {
      logger.err(
          'Please provide an agent name: walki agent add <name> --role <role>');
      return 1;
    }
    if (normalizeArtifactId(agentId) == null) {
      logger.err(
          'Invalid agent name "$agentId". Use letters, numbers, dot, underscore, or dash.');
      return 1;
    }

    final role = argResults!['role'] as String? ?? 'implementer';
    final description = argResults!['description'] as String? ?? '';
    final agentConfig = AgentConfig.forRole(role, description: description);

    try {
      final config = workspace.loadConfig();
      if (config.agents.containsKey(agentId)) {
        logger.err('Agent "$agentId" already exists.');
        return 1;
      }

      final newAgents = Map<String, AgentConfig>.from(config.agents)
        ..[agentId] = agentConfig;
      workspace.saveConfig(config.copyWith(agents: newAgents));
      _writeAgentFile(agentId, agentConfig);

      logger.info(
          '${green.wrap('Agent "$agentId" added')} with role "${agentConfig.role}"');
      logger.info(
          'Agent file: ${lightCyan.wrap(p.join('.walki', 'agents', '$agentId.md'))}');
      logger.info('Prompt for $agentId:');
      logger.info(generateAgentPrompt(agentId, agentConfig, '<channel-name>'));
      return 0;
    } catch (e) {
      logger.err('Failed to add agent: $e');
      return 1;
    }
  }
}

class AgentListSubcommand extends Command<int> {
  AgentListSubcommand({required this.logger});

  final Logger logger;

  @override
  String get name => 'list';

  @override
  String get description => 'List agents in the Walki workspace.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    if (!_ensureInitialized(workspace, logger)) {
      return 1;
    }

    try {
      final config = workspace.loadConfig();
      if (config.agents.isEmpty) {
        logger.info('No agents registered.');
        return 0;
      }

      logger.info('Agents:');
      for (final entry in config.agents.entries) {
        logger.info('  ${green.wrap(entry.key)} (${entry.value.role})');
        if (entry.value.description.isNotEmpty) {
          logger.info('    ${entry.value.description}');
        }
      }
      return 0;
    } catch (e) {
      logger.err('Failed to list agents: $e');
      return 1;
    }
  }
}

class AgentShowSubcommand extends Command<int> {
  AgentShowSubcommand({required this.logger});

  final Logger logger;

  @override
  String get name => 'show';

  @override
  String get description => 'Show an agent configuration.';

  @override
  Future<int> run() async {
    final result = _loadAgent(logger, argResults?.rest.firstOrNull);
    if (result == null) {
      return 1;
    }
    logger.info('Agent: ${result.id}');
    logger.info('Role: ${result.config.role}');
    if (result.config.description.isNotEmpty) {
      logger.info('Description: ${result.config.description}');
    }
    logger.info('Permissions:');
    for (final permission in result.config.can) {
      logger.info('  - $permission');
    }
    return 0;
  }
}

class AgentPromptSubcommand extends Command<int> {
  AgentPromptSubcommand({required this.logger}) {
    argParser.addOption(
      'channel',
      abbr: 'c',
      help: 'Channel name to include in the prompt',
      defaultsTo: '<channel-name>',
    );
  }

  final Logger logger;

  @override
  String get name => 'prompt';

  @override
  String get description => 'Print the debate prompt for an agent.';

  @override
  Future<int> run() async {
    final result = _loadAgent(logger, argResults?.rest.firstOrNull);
    if (result == null) {
      return 1;
    }
    final channel = argResults?['channel'] as String? ?? '<channel-name>';
    logger.info(generateAgentPrompt(result.id, result.config, channel));
    return 0;
  }
}

class AgentEditSubcommand extends Command<int> {
  AgentEditSubcommand({required this.logger}) {
    argParser
      ..addOption(
        'role',
        abbr: 'r',
        help: 'New role: implementer, reviewer, or owner',
        allowed: ['implementer', 'reviewer', 'owner'],
      )
      ..addOption(
        'description',
        abbr: 'd',
        help: 'New description',
      )
      ..addOption(
        'can',
        help:
            'Comma-separated permissions. Defaults to role permissions if role changes.',
      );
  }

  final Logger logger;

  @override
  String get name => 'edit';

  @override
  String get description => 'Edit an agent role, description, and permissions.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    if (!_ensureInitialized(workspace, logger)) {
      return 1;
    }

    final agentId = argResults?.rest.firstOrNull;
    if (agentId == null) {
      logger.err('Usage: walki agent edit <name>');
      return 1;
    }
    if (normalizeArtifactId(agentId) == null) {
      logger.err(
          'Invalid agent name "$agentId". Use letters, numbers, dot, underscore, or dash.');
      return 1;
    }

    final config = workspace.loadConfig();
    final existing = config.agents[agentId];
    if (existing == null) {
      logger.err('Unknown agent "$agentId".');
      return 1;
    }

    final role = argResults?['role'] as String? ??
        _prompt('Role [${existing.role}]', defaultValue: existing.role);
    final description = argResults?['description'] as String? ??
        _prompt('Description [${existing.description}]',
            defaultValue: existing.description);
    final canRaw = argResults?['can'] as String? ??
        _prompt('Permissions comma-separated [${existing.can.join(',')}]',
            defaultValue: existing.can.join(','));
    final can = _splitList(canRaw);
    final roleConfig = AgentConfig.forRole(role, description: description);
    final edited = roleConfig.copyWith(can: can.isEmpty ? roleConfig.can : can);

    final agents = Map<String, AgentConfig>.from(config.agents)
      ..[agentId] = edited;
    workspace.saveConfig(config.copyWith(agents: agents));
    _writeAgentFile(agentId, edited);

    logger.info(green.wrap('Agent "$agentId" updated.'));
    return 0;
  }
}

class AgentTuneSubcommand extends Command<int> {
  AgentTuneSubcommand({required this.logger}) {
    argParser.addOption('editor', help: 'Editor command to use');
  }

  final Logger logger;

  @override
  String get name => 'tune';

  @override
  String get description =>
      'Open an agent file in your editor and sync basic metadata.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    if (!_ensureInitialized(workspace, logger)) {
      return 1;
    }

    final agentId = argResults?.rest.firstOrNull;
    if (agentId == null) {
      logger.err('Usage: walki agent tune <name>');
      return 1;
    }
    if (normalizeArtifactId(agentId) == null) {
      logger.err(
          'Invalid agent name "$agentId". Use letters, numbers, dot, underscore, or dash.');
      return 1;
    }

    final config = workspace.loadConfig();
    if (!config.agents.containsKey(agentId)) {
      logger.err('Unknown agent "$agentId".');
      return 1;
    }

    final file = File(p.join('.walki', 'agents', '$agentId.md'));
    if (!file.existsSync()) {
      _writeAgentFile(agentId, config.agents[agentId]!);
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
      logger.info('Agent file: ${file.path}');
      return 1;
    }

    final parsed =
        _parseAgentMarkdown(file.readAsStringSync()) ?? config.agents[agentId]!;
    final agents = Map<String, AgentConfig>.from(config.agents)
      ..[agentId] = parsed;
    workspace.saveConfig(config.copyWith(agents: agents));
    logger.info(green.wrap('Agent "$agentId" tuned and synced.'));
    return 0;
  }
}

class AgentRemoveSubcommand extends Command<int> {
  AgentRemoveSubcommand({required this.logger}) {
    argParser.addFlag('yes',
        abbr: 'y', help: 'Skip confirmation', defaultsTo: false);
  }

  final Logger logger;

  @override
  String get name => 'remove';

  @override
  List<String> get aliases => const ['rm'];

  @override
  String get description => 'Remove an agent from the Walki workspace.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    if (!_ensureInitialized(workspace, logger)) {
      return 1;
    }

    final agentId = argResults?.rest.firstOrNull;
    if (agentId == null) {
      logger.err('Usage: walki agent remove <name>');
      return 1;
    }
    if (normalizeArtifactId(agentId) == null) {
      logger.err(
          'Invalid agent name "$agentId". Use letters, numbers, dot, underscore, or dash.');
      return 1;
    }
    if (agentId == 'human') {
      logger.err('The human owner agent cannot be removed.');
      return 1;
    }

    final config = workspace.loadConfig();
    if (!config.agents.containsKey(agentId)) {
      logger.err('Unknown agent "$agentId".');
      return 1;
    }

    final references =
        _channelsMentioningAgent(config.storage.channelDir, agentId);
    if (references.isNotEmpty) {
      logger.info(yellow.wrap(
          'Agent "$agentId" appears in channels: ${references.join(', ')}'));
    }

    final yes = argResults?['yes'] as bool? ?? false;
    if (!yes && !_confirm('Remove agent "$agentId"? [y/N] ')) {
      logger.info('Removal cancelled.');
      return 0;
    }

    final agents = Map<String, AgentConfig>.from(config.agents)
      ..remove(agentId);
    workspace.saveConfig(config.copyWith(agents: agents));
    final file = File(p.join('.walki', 'agents', '$agentId.md'));
    if (file.existsSync()) {
      file.deleteSync();
    }
    logger.info(green.wrap('Agent "$agentId" removed.'));
    return 0;
  }
}

class _LoadedAgent {
  const _LoadedAgent(this.id, this.config);
  final String id;
  final AgentConfig config;
}

bool _ensureInitialized(Workspace workspace, Logger logger) {
  if (!workspace.isInitialized()) {
    logger.err(
        'Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
    return false;
  }
  return true;
}

_LoadedAgent? _loadAgent(Logger logger, String? agentId) {
  final workspace = const Workspace();
  if (!_ensureInitialized(workspace, logger)) {
    return null;
  }
  if (agentId == null) {
    logger.err('Usage: walki agent <command> <name>');
    return null;
  }
  if (normalizeArtifactId(agentId) == null) {
    logger.err(
        'Invalid agent name "$agentId". Use letters, numbers, dot, underscore, or dash.');
    return null;
  }
  final config = workspace.loadConfig();
  final agentConfig = config.agents[agentId];
  if (agentConfig == null) {
    logger.err(
        'Unknown agent "$agentId". Registered agents: ${config.agents.keys.join(', ')}');
    return null;
  }
  return _LoadedAgent(agentId, agentConfig);
}

void _writeAgentFile(String id, AgentConfig config) {
  final agentFile = File(p.join('.walki', 'agents', '$id.md'));
  agentFile.parent.createSync(recursive: true);
  agentFile.writeAsStringSync(generateAgentMarkdown(id, config));
}

String _prompt(String label, {String defaultValue = ''}) {
  stdout.write('$label: ');
  final response = stdin.readLineSync()?.trim() ?? '';
  return response.isEmpty ? defaultValue : response;
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

AgentConfig? _parseAgentMarkdown(String content) {
  final roleMatch =
      RegExp(r'^- \*\*Role\*\*: (.+)$', multiLine: true).firstMatch(content);
  if (roleMatch == null) {
    return null;
  }
  final descriptionMatch =
      RegExp(r'^- \*\*Description\*\*: (.+)$', multiLine: true)
          .firstMatch(content);
  final can = <String>[];
  final lines = content.split('\n');
  var inCan = false;
  for (final line in lines) {
    if (line.trim() == '- **Can**:') {
      inCan = true;
      continue;
    }
    if (inCan && line.startsWith('  - ')) {
      can.add(line.substring(4).trim());
      continue;
    }
    if (inCan && line.trim().isEmpty) {
      break;
    }
  }
  return AgentConfig(
    role: roleMatch.group(1)!.trim(),
    description: descriptionMatch?.group(1)?.trim() ?? '',
    can: can,
  );
}

List<String> _channelsMentioningAgent(String channelDir, String agentId) {
  final dir = Directory(channelDir);
  if (!dir.existsSync()) {
    return const [];
  }
  final parser = const ChannelParser();
  final matches = <String>[];
  for (final file in dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))) {
    final content = file.readAsStringSync();
    try {
      final channel = parser.parse(content);
      if (channel.participants.contains(agentId) ||
          channel.messages.any((m) => m.agent == agentId)) {
        matches.add(channel.id);
      }
    } catch (_) {
      if (content.contains(agentId)) {
        matches.add(p.basenameWithoutExtension(file.path));
      }
    }
  }
  return matches;
}
