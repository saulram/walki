import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../mcp/mcp_config_installer.dart';
import '../../storage/workspace.dart';

class McpCommand extends Command<int> {
  McpCommand({required this.logger}) {
    addSubcommand(McpInitSubcommand(logger: logger));
  }

  final Logger logger;

  @override
  String get name => 'mcp';

  @override
  String get description => 'Manage Walki MCP integration.';

  @override
  Future<int> run() async {
    logger.err('Please specify a subcommand: init');
    printUsage();
    return 1;
  }
}

class McpInitSubcommand extends Command<int> {
  McpInitSubcommand({required this.logger}) {
    argParser
      ..addOption(
        'agent',
        abbr: 'a',
        help: 'Agent to configure: claude, codex, gemini, or opencode',
        allowed: McpConfigInstaller.targets.keys.toList(),
      )
      ..addOption(
        'command',
        abbr: 'c',
        help: 'Command used by the MCP client to start Walki',
        defaultsTo: 'walki-mcp',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Replace an existing walki MCP server entry',
        defaultsTo: false,
      );
  }

  final Logger logger;

  @override
  String get name => 'init';

  @override
  String get description =>
      'Set up Walki MCP config for an agent in this project.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    if (!workspace.isInitialized()) {
      logger.err(
          'Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    final agent = argResults?['agent'] as String?;
    if (agent == null || agent.trim().isEmpty) {
      logger
          .err('Usage: walki mcp init --agent <claude|codex|gemini|opencode>');
      return 1;
    }

    final command = argResults?['command'] as String? ?? 'walki-mcp';
    final force = argResults?['force'] as bool? ?? false;
    try {
      final result = const McpConfigInstaller().install(
        agent: agent,
        command: command,
        force: force,
      );
      logger.info(green.wrap('Walki MCP configured for $agent.'));
      logger.info('${result.created ? 'Created' : 'Updated'}: ${result.path}');
      logger.info('Server: walki -> $command');
      return 0;
    } catch (e) {
      logger.err('Failed to configure MCP: $e');
      return 1;
    }
  }
}
