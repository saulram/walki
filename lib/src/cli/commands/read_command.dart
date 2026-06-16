import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'dart:io';
import '../../channels/channel_parser.dart';
import '../../config/walki_config.dart';
import '../../storage/workspace.dart';

class ReadCommand extends Command<int> {
  ReadCommand({required this.logger}) {
    argParser.addOption(
      'tail',
      abbr: 't',
      help: 'Show only last N messages',
    );
  }

  final Logger logger;

  @override
  String get name => 'read';

  @override
  String get description => 'Read a debate channel.';

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
      logger.err('Usage: walki read <channel>');
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

    final tailStr = argResults?['tail'] as String?;
    final tail = tailStr != null ? int.tryParse(tailStr) : null;

    if (tail != null && tail <= 0) {
      logger.err('--tail must be greater than zero.');
      return 1;
    }

    if (tail != null) {
      final messages = channel.messages.reversed.take(tail).toList().reversed;
      logger.info('Channel: ${channel.id} (last $tail messages)');
      logger.info('Status: ${channel.status.toYamlValue()}');
      logger.info('');
      for (final msg in messages) {
        final kindLabel = msg.kind.name;
        logger.info(
            '${cyan.wrap(msg.timestamp.toIso8601String())} - ${green.wrap(msg.agent)} - $kindLabel');
        logger.info(msg.content);
        logger.info('');
      }
    } else {
      logger.info(channelFile.readAsStringSync());
    }

    return 0;
  }
}
