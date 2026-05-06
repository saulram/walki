import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../channels/channel.dart';
import '../../channels/channel_formatter.dart';
import '../../config/walki_config.dart';
import '../../rules/instruction_loader.dart';
import '../../storage/workspace.dart';

class DebateCommand extends Command<int> {
  DebateCommand({required this.logger}) {
    argParser.addOption(
      'agents',
      abbr: 'a',
      help: 'Comma-separated list of agents to participate',
    );
    argParser.addOption(
      'rules',
      abbr: 'r',
      help: 'Comma-separated list of rule files to load',
    );
    argParser.addOption(
      'max-turns',
      abbr: 'm',
      help: 'Maximum number of turns per debate',
      defaultsTo: '8',
    );
    argParser.addFlag(
      'sdd-change',
      help: 'Create debate as sdd-ai change',
      defaultsTo: false,
    );
  }

  final Logger logger;

  @override
  String get name => 'debate';

  @override
  String get description => 'Create a new debate channel.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();

    if (!workspace.isInitialized()) {
      logger.err('Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    final rest = argResults?.rest ?? [];
    if (rest.length < 2) {
      logger.err('Usage: walki debate <id> "question"');
      return 1;
    }

    final channelId = rest[0];
    final prompt = rest.sublist(1).join(' ');

    WalkiConfig config;
    try {
      config = workspace.loadConfig();
    } catch (e) {
      logger.err('Failed to load config: $e');
      return 1;
    }

    final agentsStr = argResults?['agents'] as String?;
    final participants = agentsStr != null
        ? agentsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : config.agents.keys.where((k) => k != 'human').toList();

    final rulesStr = argResults?['rules'] as String?;
    final rules = rulesStr != null
        ? rulesStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final maxTurns = int.tryParse(argResults?['max-turns'] as String? ?? '8') ?? 8;
    final sddChange = argResults?['sdd-change'] as bool? ?? false;

    final channelFile = File(
      p.join(config.storage.channelDir, '$channelId.md'),
    );
    if (channelFile.existsSync()) {
      logger.err('Channel "$channelId" already exists.');
      return 1;
    }

    channelFile.parent.createSync(recursive: true);

    final instructionLoader = const InstructionLoader();
    final instructions = instructionLoader.load(
      projectDir: Directory.current.path,
      configPaths: config.instructions.load,
      channelPaths: rules.map((r) => p.join('.walki', 'rules', '$r.md')).toList(),
    );

    final workingRules = <String>[
      'Read before writing.',
      'Append only.',
      'End every message with OVER.',
      'Propose decisions explicitly.',
      'Include risks and tests.',
      'Stop on agreement, missing context, disagreement, or max turns.',
    ];

    final channel = Channel(
      id: channelId,
      status: ChannelStatus.open,
      createdAt: DateTime.now(),
      participants: participants,
      prompt: prompt,
      loadedInstructions: instructions.map((i) => i.path).toList(),
      workingRules: workingRules,
      maxTurns: maxTurns,
    );

    final formatter = const ChannelFormatter();
    channelFile.writeAsStringSync(formatter.format(channel));

    logger.info('${green.wrap('Created channel:')} ${channelFile.path}');
    logger.info('Participants: ${participants.join(', ')}');
    logger.info('Max turns: $maxTurns');
    if (instructions.isNotEmpty) {
      logger.info('Loaded rules:');
      for (final inst in instructions) {
        logger.info('  - ${inst.path} (${inst.source.label})');
      }
    }

    if (sddChange && config.sddAi.enabled) {
      logger.info('');
      logger.info('${yellow.wrap('sdd-ai change folder will be created on promote.')}');
    }

    logger.info('');
    for (final agentId in participants) {
      final agentConfig = config.agents[agentId];
      if (agentConfig != null) {
        logger.info('Prompt for ${cyan.wrap(agentId)}:');
        logger.info(_generateAgentPrompt(agentId, agentConfig.role, channelId));
        logger.info('');
      }
    }

    logger.info('Use ${lightCyan.wrap('walki say <agent> $channelId "message"')} to post messages.');

    return 0;
  }

  String _generateAgentPrompt(String agentId, String role, String channelId) {
    final roleDesc = role == 'implementer'
        ? 'implementation-oriented'
        : role == 'reviewer'
            ? 'architecture and review-oriented'
            : 'owner and decision-maker';
    final focus = role == 'implementer'
        ? 'Focus on implementation plan, edge cases, migrations, and tests.'
        : role == 'reviewer'
            ? 'Focus on architecture, security, correctness, maintainability, and tradeoffs. Challenge weak proposals constructively.'
            : 'You are the owner. Accept or reject decisions.';
    return 'You are $agentId, the $roleDesc agent in a Walki debate.\n\n'
        'Channel:\n.walki/channels/$channelId.md\n\n'
        'Read the entire channel before writing.\n'
        'Append only.\n'
        'End your message with OVER.\n'
        '$focus\n'
        'Do not accept final decisions without human confirmation.\n'
        'You may propose decisions.\n';
  }
}