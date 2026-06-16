import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'dart:io';
import '../../channels/channel_formatter.dart';
import '../../channels/channel_parser.dart';
import '../../config/walki_config.dart';
import '../../storage/workspace.dart';

class StatusCommand extends Command<int> {
  StatusCommand({required this.logger});

  final Logger logger;

  @override
  String get name => 'status';

  @override
  String get description => 'Show workspace or channel status.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();

    if (!workspace.isInitialized()) {
      logger.err(
          'Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    WalkiConfig config;
    try {
      config = workspace.loadConfig();
    } catch (e) {
      logger.err('Failed to load config: $e');
      return 1;
    }

    final channelId = argResults?.rest.firstOrNull;

    if (channelId != null) {
      final channelFile = File(
        '${config.storage.channelDir}/$channelId.md',
      );
      if (!channelFile.existsSync()) {
        logger.err('Channel "$channelId" not found.');
        return 1;
      }

      final parser = const ChannelParser();
      final channel = parser.parse(channelFile.readAsStringSync());
      final formatter = const ChannelFormatter();
      logger.info(formatter.formatStatus(channel));
    } else {
      logger.info('Project: ${config.project.name}');
      logger.info('Agents: ${config.agents.keys.join(', ')}');
      logger.info('');

      final channelsDir = Directory(config.storage.channelDir);
      if (channelsDir.existsSync()) {
        final channelFiles = channelsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md'))
            .toList();

        if (channelFiles.isEmpty) {
          logger.info('No channels found.');
        } else {
          logger.info('Channels:');
          final parser = const ChannelParser();
          for (final file in channelFiles) {
            final channel = parser.parse(file.readAsStringSync());
            final statusIcon = channel.isOpen
                ? green.wrap('open')
                : yellow.wrap(channel.status.toYamlValue());
            logger.info(
              '  ${channel.id}: $statusIcon (${channel.turnCount}/${channel.maxTurns} turns)',
            );
          }
        }
      }

      logger.info('');
      if (workspace.hasSddAi()) {
        logger.info('sdd-ai: ${green.wrap('detected')}');
      }
    }

    return 0;
  }
}
