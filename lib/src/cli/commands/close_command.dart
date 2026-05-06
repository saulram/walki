import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'dart:io';
import '../../channels/channel.dart';
import '../../channels/channel_formatter.dart';
import '../../channels/channel_parser.dart';
import '../../config/walki_config.dart';
import '../../storage/workspace.dart';

class CloseCommand extends Command<int> {
  CloseCommand({required this.logger}) {
    argParser.addOption(
      'status',
      abbr: 's',
      help: 'Close status: accepted, blocked, needs-human, abandoned, superseded',
      defaultsTo: 'accepted',
      allowed: ['accepted', 'blocked', 'needs-human', 'abandoned', 'superseded', 'needs-context'],
    );
  }

  final Logger logger;

  @override
  String get name => 'close';

  @override
  String get description => 'Close a debate channel.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();

    if (!workspace.isInitialized()) {
      logger.err('Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    final channelId = argResults?.rest.firstOrNull;
    if (channelId == null) {
      logger.err('Usage: walki close <channel> --status <status>');
      return 1;
    }

    final closeStatus = argResults?['status'] as String? ?? 'accepted';

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

    if (channel.isClosed) {
      logger.err('Channel "$channelId" is already closed.');
      return 1;
    }

    final newStatus = ChannelStatus.fromString(closeStatus);
    final updatedChannel = channel.copyWith(status: newStatus);

    final formatter = const ChannelFormatter();
    channelFile.writeAsStringSync(formatter.format(updatedChannel));

    logger.info(green.wrap('Closed channel: $channelId'));
    logger.info('Status: $closeStatus');

    if (channel.decisions.isNotEmpty) {
      final lastDecision = channel.decisions.last;
      logger.info('Decision recorded: ${lastDecision.summary}');
      logger.info('');
      logger.info('Tasks proposed: ${channel.messages.where((m) => m.kind == MessageKind.proposal).length}');
    }

    if (closeStatus == 'accepted') {
      logger.info('');
      logger.info('Promotion available: ${lightCyan.wrap('walki promote $channelId --to sdd-ai')}');
    }

    return 0;
  }
}