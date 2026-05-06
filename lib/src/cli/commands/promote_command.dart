import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import '../../config/walki_config.dart';
import '../../sdd_ai/sdd_ai_adapter.dart';
import '../../storage/workspace.dart';

class PromoteCommand extends Command<int> {
  PromoteCommand({required this.logger}) {
    argParser.addOption(
      'to',
      abbr: 't',
      help: 'Promotion target',
      defaultsTo: 'sdd-ai',
      allowed: ['sdd-ai', 'decisions'],
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
      logger.err('Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    final channelId = argResults?.rest.firstOrNull;
    if (channelId == null) {
      logger.err('Usage: walki promote <channel> --to <target>');
      return 1;
    }

    final target = argResults?['to'] as String? ?? 'sdd-ai';

    WalkiConfig config;
    try {
      config = workspace.loadConfig();
    } catch (e) {
      logger.err('Failed to load config: $e');
      return 1;
    }

    if (config.decisions.promoteRequiresHuman) {
      logger.info(yellow.wrap('This action will promote the decision from channel "$channelId" to $target.'));
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
        logger.err('sdd-ai directory not found. Enable sdd-ai integration or use a different target.');
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
      final channelFile = File('${config.storage.channelDir}/$channelId.md');
      final decisionFile = File('${config.storage.decisionDir}/$channelId.md');

      if (!channelFile.existsSync()) {
        logger.err('Channel "$channelId" not found.');
        return 1;
      }

      decisionFile.parent.createSync(recursive: true);
      decisionFile.writeAsStringSync(channelFile.readAsStringSync());

      logger.info(green.wrap('Decision promoted to: ${decisionFile.path}'));
    }

    return 0;
  }
}