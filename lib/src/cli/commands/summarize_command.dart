import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'dart:io';
import '../../channels/channel.dart';
import '../../channels/channel_parser.dart';
import '../../config/walki_config.dart';
import '../../storage/workspace.dart';

class SummarizeCommand extends Command<int> {
  SummarizeCommand({required this.logger});

  final Logger logger;

  @override
  String get name => 'summarize';

  @override
  String get description => 'Generate a structured summary of a debate.';

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
      logger.err('Usage: walki summarize <channel>');
      return 1;
    }

    WalkiConfig config;
    try {
      config = workspace.loadConfig();
    } catch (e) {
      logger.err('Failed to load config: $e');
      return 1;
    }

    final channelFile = File(
      '${config.storage.channelDir}/$channelId.md',
    );
    if (!channelFile.existsSync()) {
      logger.err('Channel "$channelId" not found.');
      return 1;
    }

    final parser = const ChannelParser();
    final channel = parser.parse(channelFile.readAsStringSync());

    logger.info('# Summary: ${channel.id}');
    logger.info('');
    logger.info('Status: ${channel.status.toYamlValue()}');
    logger.info('Turns: ${channel.turnCount}/${channel.maxTurns}');
    logger.info('Participants: ${channel.participants.join(', ')}');
    logger.info('');

    if (channel.prompt.isNotEmpty) {
      logger.info('## Context');
      logger.info('');
      logger.info(channel.prompt);
      logger.info('');
    }

    if (channel.messages.isNotEmpty) {
      logger.info('## Proposals');
      logger.info('');
      for (final msg
          in channel.messages.where((m) => m.kind == MessageKind.proposal)) {
        logger.info('**${msg.agent}** (${msg.timestamp.toIso8601String()}):');
        logger.info(msg.content);
        logger.info('');
      }

      logger.info('## Challenges');
      logger.info('');
      for (final msg
          in channel.messages.where((m) => m.kind == MessageKind.challenge)) {
        logger.info('**${msg.agent}** (${msg.timestamp.toIso8601String()}):');
        logger.info(msg.content);
        logger.info('');
      }

      logger.info('## Agreements');
      logger.info('');
      for (final msg
          in channel.messages.where((m) => m.kind == MessageKind.agreement)) {
        logger.info('**${msg.agent}** (${msg.timestamp.toIso8601String()}):');
        logger.info(msg.content);
        logger.info('');
      }

      logger.info('## Decision Messages');
      logger.info('');
      for (final msg
          in channel.messages.where((m) => m.kind == MessageKind.decision)) {
        logger.info('**${msg.agent}** (${msg.timestamp.toIso8601String()}):');
        logger.info(msg.content);
        logger.info('');
      }
    }

    if (channel.decisions.isNotEmpty) {
      logger.info('## Decisions');
      logger.info('');
      for (final decision in channel.decisions) {
        logger.info('**${decision.status}**: ${decision.summary}');
        if (decision.risks.isNotEmpty) {
          logger.info('  Risks: ${decision.risks.join(', ')}');
        }
      }
      logger.info('');
    }

    logger.info('## Next action');
    logger.info('');
    if (channel.status == ChannelStatus.active) {
      final lastMsg = channel.messages.lastOrNull;
      if (lastMsg != null) {
        logger.info(
            'Last message from ${lastMsg.agent}. Waiting for other participants to respond.');
      }
    } else {
      logger.info(
          'Channel is ${channel.status.toYamlValue()}. No further action needed.');
    }

    return 0;
  }
}
