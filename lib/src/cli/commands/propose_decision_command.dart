import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../channels/channel.dart';
import '../../channels/channel_formatter.dart';
import '../../channels/channel_parser.dart';
import '../../config/walki_config.dart';
import '../../storage/workspace.dart';
import '../../validation/permission_engine.dart';

class ProposeDecisionCommand extends Command<int> {
  ProposeDecisionCommand({required this.logger}) {
    argParser
      ..addOption(
        'agent',
        abbr: 'a',
        help: 'Agent proposing the decision',
      )
      ..addOption(
        'rationale',
        abbr: 'r',
        help: 'Decision rationale',
        defaultsTo: '',
      )
      ..addOption(
        'risks',
        help: 'Comma-separated list of risks',
        defaultsTo: '',
      )
      ..addOption(
        'tests',
        help: 'Comma-separated list of required tests',
        defaultsTo: '',
      );
  }

  final Logger logger;

  @override
  String get name => 'propose_decision';

  @override
  List<String> get aliases => const ['propose-decision', 'decision'];

  @override
  String get description =>
      'Propose a structured decision for a debate channel.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    if (!workspace.isInitialized()) {
      logger.err(
          'Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    final rest = argResults?.rest ?? [];
    if (rest.length < 2) {
      logger.err(
          'Usage: walki propose_decision <channel> "summary" --agent <agent>');
      return 1;
    }

    final channelId = rest[0];
    final summary = rest.sublist(1).join(' ');
    final agent = argResults?['agent'] as String?;
    if (agent == null || agent.trim().isEmpty) {
      logger.err('Please specify the proposing agent with --agent <agent>.');
      return 1;
    }

    WalkiConfig config;
    try {
      config = workspace.loadConfig();
    } catch (e) {
      logger.err('Failed to load config: $e');
      return 1;
    }

    final channelFile = File('${config.storage.channelDir}/$channelId.md');
    if (!channelFile.existsSync()) {
      logger.err('Channel "$channelId" not found.');
      return 1;
    }

    final parser = const ChannelParser();
    final content = channelFile.readAsStringSync();
    final channel = parser.parse(content);
    if (channel.isClosed) {
      logger.err('Channel "$channelId" is closed.');
      return 1;
    }

    final agentConfig = config.agents[agent];
    if (agentConfig == null) {
      logger.err(
          'Unknown agent "$agent". Registered agents: ${config.agents.keys.join(', ')}');
      return 1;
    }
    final permissionEngine = const PermissionEngine();
    if (!permissionEngine.canPerformAction(agentConfig, 'propose_decision')) {
      logger.err('Agent "$agent" cannot perform action "propose_decision".');
      return 1;
    }

    final decision = ChannelDecision(
      status: 'proposed',
      summary: summary,
      rationale: argResults?['rationale'] as String? ?? '',
      risks: _splitList(argResults?['risks'] as String? ?? ''),
      requiredTests: _splitList(argResults?['tests'] as String? ?? ''),
    );

    final formatter = const ChannelFormatter();
    channelFile.writeAsStringSync(
      content + formatter.formatDecision(decision),
    );

    logger.info(green.wrap('Decision proposed in channel "$channelId"'));
    logger.info('Agent: $agent');
    logger.info('Summary: $summary');
    return 0;
  }

  List<String> _splitList(String raw) {
    return raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }
}
