import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import '../../channels/channel.dart';
import '../../channels/channel_parser.dart';
import '../../config/walki_config.dart';
import '../../sdd_ai/sdd_ai_adapter.dart';
import '../../storage/workspace.dart';
import '../../validation/permission_engine.dart';

class PromoteCommand extends Command<int> {
  PromoteCommand({required this.logger}) {
    argParser.addOption(
      'to',
      abbr: 't',
      help: 'Promotion target',
      defaultsTo: 'sdd-ai',
      allowed: ['sdd-ai', 'decisions'],
    );
    argParser.addOption(
      'agent',
      abbr: 'a',
      help: 'Agent requesting the promotion (defaults to human)',
      defaultsTo: 'human',
    );
    argParser.addFlag(
      'yes',
      abbr: 'y',
      help: 'Skip the interactive promotion confirmation',
      defaultsTo: false,
    );
  }

  final Logger logger;

  @override
  String get name => 'promote';

  @override
  String get description => 'Promote a decision to sdd-ai or another target.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();

    if (!workspace.isInitialized()) {
      logger.err(
          'Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    final channelId = argResults?.rest.firstOrNull;
    if (channelId == null) {
      logger.err('Usage: walki promote <channel> --to <target>');
      return 1;
    }

    final target = argResults?['to'] as String? ?? 'sdd-ai';
    final agent = argResults?['agent'] as String? ?? 'human';
    final yes = argResults?['yes'] as bool? ?? false;

    WalkiConfig config;
    try {
      config = workspace.loadConfig();
    } catch (e) {
      logger.err('Failed to load config: $e');
      return 1;
    }

    final agentConfig = config.agents[agent];
    if (agentConfig == null) {
      logger.err(
          'Unknown agent "$agent". Registered agents: ${config.agents.keys.join(', ')}');
      return 1;
    }
    final permissionEngine = const PermissionEngine();
    if (!permissionEngine.canPerformAction(agentConfig, 'promote_to_sdd')) {
      logger.err('Agent "$agent" cannot perform action "promote_to_sdd".');
      return 1;
    }

    final channelFile = File('${config.storage.channelDir}/$channelId.md');
    if (!channelFile.existsSync()) {
      logger.err('Channel "$channelId" not found.');
      return 1;
    }
    final channelContent = channelFile.readAsStringSync();
    final channel = const ChannelParser().parse(channelContent);
    if (channel.status != ChannelStatus.accepted) {
      logger.err(
          'Channel "$channelId" must be accepted before promotion. Current status: ${channel.status.toYamlValue()}');
      return 1;
    }
    if (channel.decisions.isEmpty) {
      logger.err(
          'Channel "$channelId" has no structured decision to promote. Use walki propose_decision first.');
      return 1;
    }

    if (config.decisions.promoteRequiresHuman && !yes) {
      logger.info(yellow.wrap(
          'This action will promote the decision from channel "$channelId" to $target.'));
      logger.info('Please confirm this promotion.');
      stdout.write('Confirm promotion? [y/N] ');
      final response = stdin.readLineSync();
      if (response?.toLowerCase() != 'y') {
        logger.info('Promotion cancelled.');
        return 0;
      }
    }

    if (target == 'sdd-ai') {
      if (!workspace.hasSddAi()) {
        logger.err(
            'sdd-ai directory not found. Enable sdd-ai integration or use a different target.');
        return 1;
      }

      final adapter = const SddAiAdapter();
      try {
        final changeDir = adapter.promoteDecision(channelId, config);
        logger.info(green.wrap('Decision promoted to sdd-ai:'));
        logger.info('  Change folder: $changeDir');
      } catch (e) {
        logger.err('Failed to promote: $e');
        return 1;
      }
    } else if (target == 'decisions') {
      final decisionFile = File('${config.storage.decisionDir}/$channelId.md');

      decisionFile.parent.createSync(recursive: true);
      decisionFile.writeAsStringSync(channelContent);

      logger.info(green.wrap('Decision promoted to: ${decisionFile.path}'));
    }

    return 0;
  }
}
