import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'dart:io';
import '../../channels/channel.dart';
import '../../channels/channel_parser.dart';
import '../../config/walki_config.dart';
import '../../storage/workspace.dart';
import 'dart:convert';

class ExportCommand extends Command<int> {
  ExportCommand({required this.logger}) {
    argParser.addOption(
      'format',
      abbr: 'f',
      help: 'Export format: markdown or json',
      defaultsTo: 'markdown',
      allowed: ['markdown', 'json'],
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output file path (defaults to stdout)',
    );
  }

  final Logger logger;

  @override
  String get name => 'export';

  @override
  String get description => 'Export a debate channel.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();

    if (!workspace.isInitialized()) {
      logger.err('Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    final channelId = argResults?.rest.firstOrNull;
    if (channelId == null) {
      logger.err('Usage: walki export <channel> --format <format>');
      return 1;
    }

    final format = argResults?['format'] as String? ?? 'markdown';
    final outputPath = argResults?['output'] as String?;

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
    final channel = parser.parse(channelFile.readAsStringSync());

    String output;

    if (format == 'json') {
      output = _toJson(channel);
    } else {
      output = channelFile.readAsStringSync();
    }

    if (outputPath != null) {
      File(outputPath).writeAsStringSync(output);
      logger.info(green.wrap('Exported to: $outputPath'));
    } else {
      logger.info(output);
    }

    return 0;
  }

  String _toJson(Channel channel) {
    final data = {
      'id': channel.id,
      'status': channel.status.toYamlValue(),
      'created_at': channel.createdAt.toIso8601String(),
      'participants': channel.participants,
      'prompt': channel.prompt,
      'max_turns': channel.maxTurns,
      'messages': channel.messages.map((ChannelMessage m) => {
        'timestamp': m.timestamp.toIso8601String(),
        'agent': m.agent,
        'kind': m.kind.name,
        'content': m.content,
        'ends_with_over': m.endsWithOver,
      },).toList(),
      'decisions': channel.decisions.map((ChannelDecision d) => {
        'status': d.status,
        'summary': d.summary,
        'rationale': d.rationale,
        'risks': d.risks,
        'required_tests': d.requiredTests,
      },).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}