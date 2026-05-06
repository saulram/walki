import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import '../../config/agent_config.dart';
import '../../storage/workspace.dart';

class AgentCommand extends Command<int> {
  AgentCommand({required this.logger}) {
    addSubcommand(AgentAddSubcommand(logger: logger));
    addSubcommand(AgentListSubcommand(logger: logger));
  }

  final Logger logger;

  @override
  String get name => 'agent';

  @override
  String get description => 'Manage agents in the Walki workspace.';

  @override
  Future<int> run() async {
    logger.err('Please specify a subcommand: add, list');
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

    if (!workspace.isInitialized()) {
      logger.err('Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    final agentId = argResults?.rest.firstOrNull;
    if (agentId == null) {
      logger.err('Please provide an agent name: walki agent add <name> --role <role>');
      return 1;
    }

    final role = argResults!['role'] as String? ?? 'implementer';
    final description = argResults!['description'] as String? ?? '';

    AgentConfig agentConfig;
    switch (role) {
      case 'implementer':
        agentConfig = AgentConfig.implementer(description: description);
      case 'reviewer':
        agentConfig = AgentConfig.reviewer(description: description);
      case 'owner':
        agentConfig = AgentConfig.owner();
      default:
        agentConfig = AgentConfig(
          role: role,
          description: description,
          can: ['read', 'append', 'propose_decision', 'propose_task'],
        );
    }

    try {
      final config = workspace.loadConfig();
      if (config.agents.containsKey(agentId)) {
        logger.err('Agent "$agentId" already exists.');
        return 1;
      }

      final newAgents = Map<String, AgentConfig>.from(config.agents);
      newAgents[agentId] = agentConfig;

      workspace.saveConfig(config.copyWith(agents: newAgents));

      final agentFile = File(p.join('.walki', 'agents', '$agentId.md'));
      agentFile.parent.createSync(recursive: true);
      agentFile.writeAsStringSync(_generateAgentMarkdown(agentId, agentConfig));

      logger.info('${green.wrap('Agent "$agentId" added')} with role "${agentConfig.role}"');
      logger.info('');
      logger.info('Agent file: ${lightCyan.wrap(agentFile.path)}');
      logger.info('');
      logger.info('Permissions:');
      for (final perm in agentConfig.can) {
        logger.info('  - $perm');
      }
      logger.info('');
      logger.info('Prompt for $agentId:');
      logger.info(_generatePrompt(agentId, agentConfig));

      return 0;
    } catch (e) {
      logger.err('Failed to add agent: $e');
      return 1;
    }
  }

  String _generateAgentMarkdown(String id, AgentConfig config) {
    final buffer = StringBuffer();
    buffer.writeln('# Agent: $id');
    buffer.writeln();
    buffer.writeln('- **ID**: $id');
    buffer.writeln('- **Role**: ${config.role}');
    if (config.description.isNotEmpty) {
      buffer.writeln('- **Description**: ${config.description}');
    }
    buffer.writeln('- **Can**:');
    for (final perm in config.can) {
      buffer.writeln('  - $perm');
    }
    buffer.writeln();
    return buffer.toString();
  }

  String _generatePrompt(String id, AgentConfig config) {
    final roleDesc = config.role == 'implementer'
        ? 'implementation-oriented'
        : config.role == 'reviewer'
            ? 'architecture and review-oriented'
            : 'owner and decision-maker';
    final focus = config.role == 'implementer'
        ? 'Focus on implementation plan, edge cases, migrations, and tests.'
        : config.role == 'reviewer'
            ? 'Focus on architecture, security, correctness, maintainability, and tradeoffs. Challenge weak proposals constructively.'
            : 'You are the owner. Accept or reject decisions. Promote accepted decisions.';
    return 'You are $id, the $roleDesc agent in a Walki debate.\n\n'
        'Channel:\n.walki/channels/<channel-name>.md\n\n'
        'Read the entire channel before writing.\n'
        'Append only.\n'
        'End your message with OVER.\n'
        '$focus\n'
        'Do not accept final decisions without human confirmation.\n'
        'You may propose decisions.\n';
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

    if (!workspace.isInitialized()) {
      logger.err('Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
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