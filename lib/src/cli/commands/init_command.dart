import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../agents/agent_prompts.dart';
import '../../agents/agent_registry.dart';
import '../../channels/channel.dart';
import '../../channels/channel_formatter.dart';
import '../../config/agent_config.dart';
import '../../config/walki_config.dart';
import '../../mcp/mcp_config_installer.dart';
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
    );
    argParser.addFlag(
      'sdd-ai',
      help: 'Enable sdd_ai integration',
      defaultsTo: false,
    );
    argParser.addFlag(
      'non-interactive',
      help: 'Skip the setup wizard and use defaults or explicit flags',
      defaultsTo: false,
    );
    argParser.addFlag(
      'wizard',
      help: 'Run the setup wizard even when explicit values are omitted',
      defaultsTo: false,
    );
  }

  final Logger logger;

  @override
  String get name => 'init';

  @override
  String get description =>
      'Initialize a Walki workspace in the current project.';

  @override
  List<String> get aliases => const ['i'];

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    final template = argResults!['template'] as String? ?? 'minimal';
    final agentsStr = argResults!['agents'] as String?;
    var sddAi = argResults!['sdd-ai'] as bool? ?? false;
    final nonInteractive = argResults!['non-interactive'] as bool? ?? false;
    final forceWizard = argResults!['wizard'] as bool? ?? false;
    final shouldRunWizard = !nonInteractive &&
        (forceWizard || (agentsStr == null && stdin.hasTerminal));

    var agentNames = (agentsStr ?? 'codex,claude')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Map<String, AgentConfig>? agentConfigs;
    var starterRules = <String>['security', 'code-style'];
    var draftRules = false;
    String? mcpAgent;

    if (workspace.isInitialized()) {
      logger.err(
          'Walki workspace already exists. Remove .walki/ first or use a different directory.');
      return 1;
    }

    if (shouldRunWizard) {
      final wizard = _runWizard(
        defaultAgents: agentNames,
        defaultSddAi: sddAi || template == 'sdd',
      );
      agentNames = wizard.agentConfigs.keys.toList();
      agentConfigs = wizard.agentConfigs;
      sddAi = wizard.sddAi;
      starterRules = wizard.starterRules;
      draftRules = wizard.draftRules;
      mcpAgent = wizard.mcpAgent;
    }

    final progress = logger.progress('Initializing Walki workspace');

    try {
      final dir = workspace.init(
        template: template,
        agentNames: agentNames,
        agentConfigs: agentConfigs,
        sddAi: sddAi,
        starterRules: starterRules,
      );

      progress.complete('Walki workspace initialized');

      logger.info('');
      logger.info('Created: ${green.wrap(dir)}');
      logger.info('');
      logger.info('Agents: ${agentNames.join(', ')}');
      if (sddAi || workspace.hasSddAi()) {
        logger.info('${green.wrap('sdd_ai integration: enabled')}');
      }
      if (draftRules) {
        final channelPath = _createRulesDraftChannel(
          WalkiConfig(
            project: ProjectConfig(name: p.basename(Directory.current.path)),
            agents: agentConfigs ?? _defaultAgentConfigs(agentNames),
          ),
          agentNames,
        );
        logger.info('${green.wrap('Rules draft channel:')} $channelPath');
      }
      if (mcpAgent != null) {
        final result = const McpConfigInstaller().install(agent: mcpAgent!);
        logger.info(
            '${green.wrap('MCP configured for $mcpAgent:')} ${result.path}');
      }
      logger.info('');
      logger.info('Next steps:');
      logger.info(
          '  1. ${lightCyan.wrap('walki debate <topic> "question"')} - Start a debate');
      logger.info(
          '  2. ${lightCyan.wrap('walki agent add <name> --role <role>')} - Add more agents');
      logger.info(
          '  3. ${lightCyan.wrap('walki rules edit <name>')} - Edit custom rules');
      logger.info(
          '  4. ${lightCyan.wrap('walki rules draft')} - Debate repo-specific rules');
      logger.info(
          '  5. ${lightCyan.wrap('walki mcp init --agent <agent>')} - Configure project MCP');

      return 0;
    } catch (e) {
      progress.fail('Failed to initialize workspace');
      logger.err(e.toString());
      return 1;
    }
  }

  _InitWizardResult _runWizard({
    required List<String> defaultAgents,
    required bool defaultSddAi,
  }) {
    logger.info(cyan.wrap('Walki setup wizard'));
    logger.info('');

    final detected = const AgentRegistry().detectInstalled();
    if (detected.isNotEmpty) {
      logger.info('Detected agents:');
      for (final agent in detected) {
        logger.info('  - ${agent.definition.id} (${agent.path})');
      }
    } else {
      logger.info('No supported agent CLIs detected on PATH.');
    }

    final detectedIds = detected.map((agent) => agent.definition.id).toList();
    final defaultIds = detectedIds.isEmpty ? defaultAgents : detectedIds;
    final selectedRaw = _prompt(
      'Agents to register [${defaultIds.join(',')}]',
      defaultValue: defaultIds.join(','),
    );
    final selected = selectedRaw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final registry = const AgentRegistry();
    final agentConfigs = <String, AgentConfig>{};
    for (final id in selected) {
      final definition = registry.definitionFor(id);
      final base = definition?.defaultConfig ?? AgentConfig.implementer();
      final role = _promptRole(
        id,
        defaultValue: base.role,
        logger: logger,
      );
      final description = _prompt(
        'Description for $id [${base.description}]',
        defaultValue: base.description,
      );
      agentConfigs[id] = AgentConfig.forRole(role, description: description);
    }

    final sddAi = _confirm(
      'Enable sdd_ai integration? [${defaultSddAi ? 'Y/n' : 'y/N'}] ',
      defaultValue: defaultSddAi,
    );
    final defaultRules = sddAi
        ? 'security,code-style,testing,sdd-ai'
        : 'security,code-style,testing';
    final rulesRaw =
        _prompt('Starter rules [$defaultRules]', defaultValue: defaultRules);
    final starterRules = rulesRaw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final draftRules = _confirm('Create a repo-rule draft debate now? [Y/n] ',
        defaultValue: true);
    String? mcpAgent;
    final supportedMcpAgents = selected
        .where((agent) => McpConfigInstaller.targets.containsKey(agent))
        .toList();
    if (supportedMcpAgents.isNotEmpty &&
        _confirm('Set up Walki MCP for one selected agent? [Y/n] ',
            defaultValue: true)) {
      final selectedMcpAgent = _prompt(
        'MCP agent [${supportedMcpAgents.first}]',
        defaultValue: supportedMcpAgents.first,
      );
      if (McpConfigInstaller.targets.containsKey(selectedMcpAgent)) {
        mcpAgent = selectedMcpAgent;
      } else {
        logger.info(
          yellow.wrap(
            'Skipping MCP setup: "$selectedMcpAgent" is not supported. Supported: ${McpConfigInstaller.targets.keys.join(', ')}',
          ),
        );
      }
    }

    return _InitWizardResult(
      agentConfigs: agentConfigs,
      sddAi: sddAi,
      starterRules: starterRules,
      draftRules: draftRules,
      mcpAgent: mcpAgent,
    );
  }

  String _createRulesDraftChannel(
      WalkiConfig config, List<String> participants) {
    final channelId = 'rules-bootstrap';
    final channelFile = File(p.join('.walki', 'channels', '$channelId.md'));
    if (channelFile.existsSync()) {
      return channelFile.path;
    }
    final instructionFiles = _detectInstructionFiles();
    final channel = Channel(
      id: channelId,
      status: ChannelStatus.open,
      createdAt: DateTime.now(),
      participants: participants,
      prompt: _rulesDraftPrompt(instructionFiles),
      loadedInstructions: instructionFiles,
      workingRules: const [
        'Read the detected instruction files before proposing rules.',
        'Propose concrete .walki/rules/*.md files.',
        'Use fenced blocks with ```walki-rule name=<rule-name>.',
        'Challenge vague, duplicate, or conflicting rules.',
        'Human approval is required before applying generated rules.',
      ],
      maxTurns: 6,
    );
    channelFile.parent.createSync(recursive: true);
    channelFile.writeAsStringSync(const ChannelFormatter().format(channel));
    return channelFile.path;
  }
}

class _InitWizardResult {
  const _InitWizardResult({
    required this.agentConfigs,
    required this.sddAi,
    required this.starterRules,
    required this.draftRules,
    this.mcpAgent,
  });

  final Map<String, AgentConfig> agentConfigs;
  final bool sddAi;
  final List<String> starterRules;
  final bool draftRules;
  final String? mcpAgent;
}

String _prompt(String label, {String defaultValue = ''}) {
  stdout.write('$label: ');
  final response = stdin.readLineSync()?.trim() ?? '';
  return response.isEmpty ? defaultValue : response;
}

bool _confirm(String label, {bool defaultValue = false}) {
  stdout.write(label);
  final response = stdin.readLineSync()?.trim().toLowerCase();
  if (response == null || response.isEmpty) {
    return defaultValue;
  }
  return response == 'y' || response == 'yes';
}

String _promptRole(
  String agentId, {
  required String defaultValue,
  required Logger logger,
}) {
  const roles = <String, String>{
    'implementer': 'implementation and tests',
    'reviewer': 'architecture review and constructive challenges',
    'owner': 'human decision-maker who accepts/closes/promotes',
  };

  logger.info('Available roles:');
  for (final entry in roles.entries) {
    logger.info('  - ${entry.key}: ${entry.value}');
  }

  while (true) {
    stdout.write('Role for $agentId [$defaultValue]: ');
    final response = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    final role = response.isEmpty ? defaultValue : response;
    if (roles.containsKey(role)) {
      return role;
    }
    logger.err(
      'Unknown role "$role". Choose one of: ${roles.keys.join(', ')}.',
    );
  }
}

Map<String, AgentConfig> _defaultAgentConfigs(List<String> agentNames) {
  return {
    for (final name in agentNames)
      name: AgentConfig.forRole(name == 'claude' ? 'reviewer' : 'implementer'),
  };
}

List<String> _detectInstructionFiles() {
  final files = <String>[];
  for (final candidate in [
    'AGENTS.md',
    'CLAUDE.md',
    'GEMINI.md',
    '.cursorrules',
    '.github/copilot-instructions.md',
    'README.md',
  ]) {
    if (File(candidate).existsSync()) {
      files.add(candidate);
    }
  }
  final existingRules = Directory('.walki/rules');
  if (existingRules.existsSync()) {
    files.addAll(existingRules
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'))
        .map((file) => file.path));
  }
  return files..sort();
}

String _rulesDraftPrompt(List<String> instructionFiles) {
  return '''Create a repo-specific Walki ruleset from the detected instruction files.

Detected files:
${instructionFiles.isEmpty ? '- none' : instructionFiles.map((file) => '- $file').join('\n')}

The proposer should read these files and propose focused .walki/rules/*.md files. The reviewer should challenge vague, duplicate, conflicting, or unenforceable rules.

When the debate has a final proposal, include each rule as a fenced block:

```walki-rule name=security
# Security Rules

- Concrete rule here.
```

Prefer small files such as project, code-style, testing, security, release, and sdd-ai when relevant.''';
}
