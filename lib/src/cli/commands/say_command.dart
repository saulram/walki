import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'dart:io';
import '../../channels/channel.dart';
import '../../channels/channel_formatter.dart';
import '../../channels/channel_parser.dart';
import '../../config/walki_config.dart';
import '../../validation/permission_engine.dart';
import '../../storage/workspace.dart';

class SayCommand extends Command<int> {
  SayCommand({required this.logger}) {
    argParser.addOption(
      'kind',
      abbr: 'k',
      help: 'Message kind',
      defaultsTo: 'proposal',
      allowed: [
        'proposal',
        'challenge',
        'question',
        'clarification',
        'agreement',
        'objection',
        'context',
        'summary',
        'meta',
      ],
    );
  }

  final Logger logger;

  @override
  String get name => 'say';

  @override
  String get description => 'Append a message to a debate channel.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();

    if (!workspace.isInitialized()) {
      logger.err('Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    final rest = argResults?.rest ?? [];
    if (rest.length < 3) {
      logger.err('Usage: walki say <agent> <channel> "message"');
      return 1;
    }

    final agent = rest[0];
    final channelId = rest[1];
    final message = rest.sublist(2).join(' ');
    final kind = argResults?['kind'] as String? ?? 'proposal';

    WalkiConfig config;
    try {
      config = workspace.loadConfig();
    } catch (e) {
      logger.err('Failed to load config: $e');
      return 1;
    }

    if (!config.agents.containsKey(agent)) {
      logger.err('Unknown agent "$agent". Registered agents: ${config.agents.keys.join(', ')}');
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
      logger.err('Channel "$channelId" is closed.');
      return 1;
    }

    final permissionEngine = const PermissionEngine();
    final agentConfig = config.agents[agent]!;
    final violations = permissionEngine.validateMessage(agentConfig, channel, 'append');

    if (violations.isNotEmpty) {
      for (final violation in violations) {
        logger.err(violation);
      }
      return 1;
    }

    final channelMessage = ChannelMessage(
      agent: agent,
      kind: MessageKind.fromString(kind),
      content: message,
      timestamp: DateTime.now(),
      endsWithOver: config.limits.requireOverMarker,
    );

    final formatter = const ChannelFormatter();

    final updatedChannel = channel.copyWith(
      status: channel.status == ChannelStatus.open ? ChannelStatus.active : channel.status,
      messages: [...channel.messages, channelMessage],
    );

    channelFile.writeAsStringSync(formatter.format(updatedChannel));

    logger.info(green.wrap('Message appended to channel "$channelId"'));
    logger.info('  Agent: $agent');
    logger.info('  Kind: $kind');
    logger.info('  Turn: ${updatedChannel.turnCount}/${channel.maxTurns}');

    return 0;
  }
}