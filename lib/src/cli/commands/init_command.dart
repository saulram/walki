import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import '../../storage/workspace.dart';

class InitCommand extends Command<int> {
  InitCommand({required this.logger}) {
    argParser.addOption(
      'template',
      abbr: 't',
      help: 'Template to use: minimal or sdd',
      defaultsTo: 'minimal',
      allowed: ['minimal', 'sdd'],
    );
    argParser.addOption(
      'agents',
      abbr: 'a',
      help: 'Comma-separated list of agent names',
      defaultsTo: 'codex,claude',
    );
    argParser.addFlag(
      'sdd-ai',
      help: 'Enable sdd_ai integration',
      defaultsTo: false,
    );
  }

  final Logger logger;

  @override
  String get name => 'init';

  @override
  String get description => 'Initialize a Walki workspace in the current project.';

  @override
  List<String> get aliases => const ['i'];

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    final template = argResults!['template'] as String? ?? 'minimal';
    final agentsStr = argResults!['agents'] as String? ?? 'codex,claude';
    final sddAi = argResults!['sdd-ai'] as bool? ?? false;
    final agentNames = agentsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (workspace.isInitialized()) {
      logger.err('Walki workspace already exists. Remove .walki/ first or use a different directory.');
      return 1;
    }

    final progress = logger.progress('Initializing Walki workspace');

    try {
      final dir = workspace.init(
        template: template,
        agentNames: agentNames,
        sddAi: sddAi,
      );

      progress.complete('Walki workspace initialized');

      logger.info('');
      logger.info('Created: ${green.wrap(dir)}');
      logger.info('');
      logger.info('Agents: ${agentNames.join(', ')}');
      if (sddAi || workspace.hasSddAi()) {
        logger.info('${green.wrap('sdd_ai integration: enabled')}');
      }
      logger.info('');
      logger.info('Next steps:');
      logger.info('  1. ${lightCyan.wrap('walki debate <topic> "question"')} - Start a debate');
      logger.info('  2. ${lightCyan.wrap('walki agent add <name> --role <role>')} - Add more agents');
      logger.info('  3. ${lightCyan.wrap('walki rules add <name>')} - Add custom rules');

      return 0;
    } catch (e) {
      progress.fail('Failed to initialize workspace');
      logger.err(e.toString());
      return 1;
    }
  }
}