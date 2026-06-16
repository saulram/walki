import 'dart:convert';
import 'dart:io';
import 'package:mcp_server/mcp_server.dart';
import 'package:path/path.dart' as p;
import '../agents/agent_prompts.dart';
import '../channels/channel.dart';
import '../channels/channel_parser.dart';
import '../channels/channel_formatter.dart';
import '../config/agent_config.dart';
import '../config/walki_config.dart';
import '../rules/instruction_loader.dart';
import '../sdd_ai/sdd_ai_adapter.dart';
import '../storage/workspace.dart';
import '../validation/permission_engine.dart';

String _projectDir = Directory.current.path;

void registerWalkiTools(Server server) {
  _projectDir = Directory.current.path;
  server.addTool(
    name: 'walki_open_channel',
    description:
        'Open a new debate channel for agents to deliberate. Creates a Markdown file with metadata, instructions, and working rules. Returns the channel ID and agent prompts.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'id': {
          'type': 'string',
          'description': 'Unique channel identifier (e.g., "auth-multitenant")',
        },
        'prompt': {
          'type': 'string',
          'description': 'The question or topic for the debate',
        },
        'agents': {
          'type': 'string',
          'description':
              'Comma-separated list of agent names (e.g., "codex,claude")',
        },
        'rules': {
          'type': 'string',
          'description':
              'Comma-separated list of rule files to load (e.g., "security,testing")',
        },
        'max_turns': {
          'type': 'integer',
          'description': 'Maximum number of turns for the debate (default: 8)',
        },
      },
      'required': ['id', 'prompt'],
    },
    handler: _openChannel,
  );

  server.addTool(
    name: 'walki_read_channel',
    description:
        'Read the contents of a debate channel. Returns the full Markdown content or a summary of the last N messages.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {
          'type': 'string',
          'description': 'The channel ID to read',
        },
        'tail': {
          'type': 'integer',
          'description': 'If specified, only return the last N messages',
        },
      },
      'required': ['channel'],
    },
    handler: _readChannel,
  );

  server.addTool(
    name: 'walki_post_message',
    description:
        'Post a message to a debate channel. The agent reads the channel, then appends a message. Every message ends with the OVER marker by default.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {
          'type': 'string',
          'description': 'The channel ID to post to',
        },
        'agent': {
          'type': 'string',
          'description': 'The name of the agent posting the message',
        },
        'message': {
          'type': 'string',
          'description': 'The message content to append',
        },
        'kind': {
          'type': 'string',
          'enum': [
            'proposal',
            'challenge',
            'question',
            'clarification',
            'agreement',
            'objection',
            'decision',
            'context',
            'summary',
            'meta'
          ],
          'description': 'The kind of message (default: proposal)',
        },
      },
      'required': ['channel', 'agent', 'message'],
    },
    handler: _postMessage,
  );

  server.addTool(
    name: 'walki_propose_decision',
    description:
        'Propose a decision for a debate channel. Records the decision with rationale, risks, and required tests.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {
          'type': 'string',
          'description': 'The channel ID',
        },
        'agent': {
          'type': 'string',
          'description': 'The agent proposing the decision',
        },
        'summary': {
          'type': 'string',
          'description': 'Summary of the decision',
        },
        'rationale': {
          'type': 'string',
          'description': 'Rationale for the decision',
        },
        'risks': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'List of risks associated with the decision',
        },
        'required_tests': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'List of tests required before the decision can be accepted',
        },
      },
      'required': ['channel', 'agent', 'summary'],
    },
    handler: _proposeDecision,
  );

  server.addTool(
    name: 'walki_get_status',
    description:
        'Get the status of a specific channel or overview of all channels in the workspace. Returns status, participants, turn count, and last action.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {
          'type': 'string',
          'description':
              'Optional channel ID. If omitted, returns overview of all channels.',
        },
      },
    },
    handler: _getStatus,
  );

  server.addTool(
    name: 'walki_close_channel',
    description:
        'Close a debate channel with a specific status (accepted, blocked, needs-human, abandoned). Prevents further messages.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {
          'type': 'string',
          'description': 'The channel ID to close',
        },
        'agent': {
          'type': 'string',
          'description': 'Agent requesting the close action',
        },
        'status': {
          'type': 'string',
          'enum': [
            'accepted',
            'blocked',
            'needs-human',
            'abandoned',
            'superseded',
            'needs-context'
          ],
          'description':
              'The status to close the channel with (default: accepted)',
        },
      },
      'required': ['channel', 'agent'],
    },
    handler: _closeChannel,
  );

  server.addTool(
    name: 'walki_promote_to_sdd',
    description:
        'Promote a channel decision to sdd-ai or a decisions file. Creates change folders and copies the debate artifacts.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {
          'type': 'string',
          'description': 'The channel ID to promote',
        },
        'agent': {
          'type': 'string',
          'description': 'Agent requesting the promotion',
        },
        'target': {
          'type': 'string',
          'enum': ['sdd-ai', 'decisions'],
          'description': 'Promotion target (default: sdd-ai)',
        },
      },
      'required': ['channel', 'agent'],
    },
    handler: _promoteToSdd,
  );

  server.addTool(
    name: 'walki_init_workspace',
    description:
        'Initialize a Walki workspace non-interactively. Fails if .walki already exists.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'agents': {
          'type': 'string',
          'description': 'Comma-separated agents (default: codex,claude)',
        },
        'template': {
          'type': 'string',
          'enum': ['minimal', 'sdd'],
          'description': 'Workspace template (default: minimal)',
        },
        'sdd_ai': {
          'type': 'boolean',
          'description': 'Enable sdd-ai integration',
        },
      },
    },
    handler: _initWorkspace,
  );

  server.addTool(
    name: 'walki_list_agents',
    description: 'List configured Walki agents.',
    inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
    handler: _listAgents,
  );

  server.addTool(
    name: 'walki_add_agent',
    description: 'Add a Walki agent with a role and optional description.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Agent ID'},
        'role': {
          'type': 'string',
          'enum': ['implementer', 'reviewer', 'owner'],
          'description': 'Agent role (default: implementer)',
        },
        'description': {
          'type': 'string',
          'description': 'Agent description',
        },
      },
      'required': ['id'],
    },
    handler: _addAgent,
  );

  server.addTool(
    name: 'walki_list_rules',
    description: 'List Walki rule files.',
    inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
    handler: _listRules,
  );

  server.addTool(
    name: 'walki_add_rule',
    description: 'Create a Walki rule file.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': 'Rule name'},
        'description': {
          'type': 'string',
          'description': 'Optional rule description',
        },
      },
      'required': ['name'],
    },
    handler: _addRule,
  );

  server.addTool(
    name: 'walki_show_rule',
    description: 'Read a Walki rule file.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': 'Rule name'},
      },
      'required': ['name'],
    },
    handler: _showRule,
  );

  server.addTool(
    name: 'walki_summarize_channel',
    description: 'Generate a structured summary of a debate channel.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {'type': 'string', 'description': 'Channel ID'},
      },
      'required': ['channel'],
    },
    handler: _summarizeChannel,
  );

  server.addTool(
    name: 'walki_export_channel',
    description: 'Export a debate channel as markdown or json.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {'type': 'string', 'description': 'Channel ID'},
        'format': {
          'type': 'string',
          'enum': ['markdown', 'json'],
          'description': 'Export format (default: markdown)',
        },
      },
      'required': ['channel'],
    },
    handler: _exportChannel,
  );

  server.addTool(
    name: 'walki_doctor',
    description: 'Run basic Walki workspace health checks.',
    inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
    handler: _doctor,
  );
}

Future<CallToolResult> _openChannel(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace not initialized. Run walki init first.');
  }

  final id = args['id'] as String;
  final prompt = args['prompt'] as String;
  final agentsStr = args['agents'] as String? ?? '';
  final rulesStr = args['rules'] as String? ?? '';
  final maxTurns = args['max_turns'] as int? ?? 8;
  final normalizedId = _sanitizeArtifactId(id);
  if (normalizedId == null) {
    return _error(
        'Invalid channel ID "$id". Use 1-128 characters: letters, numbers, ".", "_", "-".');
  }

  WalkiConfig config;
  try {
    config = workspace.loadConfig(_projectDir);
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final participants = agentsStr.isNotEmpty
      ? agentsStr
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList()
      : config.agents.keys.where((k) => k != 'human').toList();

  final rules = rulesStr
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final instructionLoader = const InstructionLoader();
  final instructions = instructionLoader.load(
    projectDir: _projectDir,
    configPaths: config.instructions.load,
    channelPaths:
        rules.map((r) => p.join(config.storage.rulesDir, '$r.md')).toList(),
  );

  final channelFile = _channelFileFor(config, normalizedId);
  if (channelFile.existsSync()) {
    return _error('Channel "$normalizedId" already exists.');
  }

  channelFile.parent.createSync(recursive: true);

  final workingRules = <String>[
    'Read before writing.',
    'Append only.',
    'End every message with OVER.',
    'Propose decisions explicitly.',
    'Include risks and tests.',
    'Stop on agreement, missing context, disagreement, or max turns.',
  ];

  final channel = Channel(
    id: normalizedId,
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

  final prompts = <String, String>{};
  for (final agentId in participants) {
    final agentConfig = config.agents[agentId];
    if (agentConfig != null) {
      prompts[agentId] =
          generateAgentPrompt(agentId, agentConfig, normalizedId);
    }
  }

  return CallToolResult(content: [
    TextContent(
        text:
            'Channel "$normalizedId" created with ${participants.length} participants and $maxTurns max turns.\n\nAgent prompts:\n${prompts.entries.map((e) => '${e.key}:\n${e.value}').join('\n\n')}'),
  ]);
}

Future<CallToolResult> _readChannel(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final tail = args['tail'] as int?;
  final normalizedChannelId = _sanitizeArtifactId(channelId);
  if (normalizedChannelId == null) {
    return _error(
        'Invalid channel ID "$channelId". Use 1-128 characters: letters, numbers, ".", "_", "-".');
  }

  WalkiConfig config;
  try {
    config = workspace.loadConfig(_projectDir);
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final channelFile = _channelFileFor(config, normalizedChannelId);
  if (!channelFile.existsSync()) {
    return _error('Channel "$normalizedChannelId" not found.');
  }

  final parser = const ChannelParser();
  final content = channelFile.readAsStringSync();
  final channel = parser.parse(content);

  if (tail != null && tail <= 0) {
    return _error('tail must be greater than zero.');
  }

  if (tail != null) {
    final messages = channel.messages.reversed.take(tail).toList().reversed;
    final result = StringBuffer();
    result.writeln('Channel: ${channel.id} (last $tail messages)');
    result.writeln('Status: ${channel.status.toYamlValue()}');
    result.writeln();
    for (final msg in messages) {
      result.writeln(
          '${msg.timestamp.toIso8601String()} - ${msg.agent} (${msg.kind.name}):');
      result.writeln(msg.content);
      result.writeln();
    }
    return CallToolResult(content: [TextContent(text: result.toString())]);
  }

  return CallToolResult(content: [TextContent(text: content)]);
}

Future<CallToolResult> _postMessage(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final agent = args['agent'] as String;
  final message = args['message'] as String;
  final kind = args['kind'] as String? ?? 'proposal';
  final normalizedChannelId = _sanitizeArtifactId(channelId);
  if (normalizedChannelId == null) {
    return _error(
        'Invalid channel ID "$channelId". Use 1-128 characters: letters, numbers, ".", "_", "-".');
  }

  WalkiConfig config;
  try {
    config = workspace.loadConfig(_projectDir);
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final channelFile = _channelFileFor(config, normalizedChannelId);
  if (!channelFile.existsSync()) {
    return _error('Channel "$normalizedChannelId" not found.');
  }

  final parser = const ChannelParser();
  final channelContent = channelFile.readAsStringSync();
  final channel = parser.parse(channelContent);

  if (channel.isClosed) {
    return _error('Channel "$normalizedChannelId" is closed.');
  }

  final agentConfig = config.agents[agent];
  if (agentConfig == null) {
    return _error('Unknown agent "$agent". Register the agent before posting.');
  }
  final permissionEngine = const PermissionEngine();
  final violations = permissionEngine.validateMessage(
    agentConfig,
    channel,
    'append',
    agentId: agent,
  );
  if (violations.isNotEmpty) {
    return _error('Permission violations: ${violations.join("; ")}');
  }

  final channelMessage = ChannelMessage(
    agent: agent,
    kind: MessageKind.fromString(kind),
    content: message,
    timestamp: DateTime.now(),
    endsWithOver: true,
  );

  final formatter = const ChannelFormatter();

  var content = channelContent;
  if (channel.status == ChannelStatus.open) {
    content = formatter.updateStatus(content, ChannelStatus.active);
  }
  content += formatter.formatAppendMessage(channelMessage);
  channelFile.writeAsStringSync(content);

  final turnCount = channel.messages.length + 1;
  return CallToolResult(content: [
    TextContent(
        text:
            'Message appended to channel "$normalizedChannelId" by $agent ($kind). Turn $turnCount/${channel.maxTurns}.'),
  ]);
}

Future<CallToolResult> _proposeDecision(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final agent = args['agent'] as String;
  final summary = args['summary'] as String;
  final rationale = args['rationale'] as String? ?? '';
  final risks =
      (args['risks'] as List<dynamic>?)?.cast<String>().toList() ?? [];
  final requiredTests =
      (args['required_tests'] as List<dynamic>?)?.cast<String>().toList() ?? [];
  final normalizedChannelId = _sanitizeArtifactId(channelId);
  if (normalizedChannelId == null) {
    return _error(
        'Invalid channel ID "$channelId". Use 1-128 characters: letters, numbers, ".", "_", "-".');
  }

  WalkiConfig config;
  try {
    config = workspace.loadConfig(_projectDir);
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final channelFile = _channelFileFor(config, normalizedChannelId);
  if (!channelFile.existsSync()) {
    return _error('Channel "$normalizedChannelId" not found.');
  }

  final parser = const ChannelParser();
  final channelContent = channelFile.readAsStringSync();
  final channel = parser.parse(channelContent);

  if (channel.isClosed) {
    return _error('Channel "$normalizedChannelId" is closed.');
  }

  final agentConfig = config.agents[agent];
  if (agentConfig == null) {
    return _error(
        'Unknown agent "$agent". Register the agent before proposing decisions.');
  }
  final permissionEngine = const PermissionEngine();
  if (!permissionEngine.canPerformAction(agentConfig, 'propose_decision')) {
    return _error(
        'Permission violations: Agent "${agentConfig.role}" cannot perform action "propose_decision"');
  }

  final decision = ChannelDecision(
    status: 'proposed',
    summary: summary,
    rationale: rationale,
    risks: risks,
    requiredTests: requiredTests,
  );

  final formatter = const ChannelFormatter();
  final decisionBlock = formatter.formatDecision(decision);

  final updatedContent = channelContent + decisionBlock;
  channelFile.writeAsStringSync(updatedContent);

  return CallToolResult(content: [
    TextContent(
        text:
            'Decision proposed in channel "$normalizedChannelId" by $agent: $summary'),
  ]);
}

Future<CallToolResult> _getStatus(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String?;

  WalkiConfig config;
  try {
    config = workspace.loadConfig(_projectDir);
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final formatter = const ChannelFormatter();

  if (channelId != null) {
    final normalizedChannelId = _sanitizeArtifactId(channelId);
    if (normalizedChannelId == null) {
      return _error(
          'Invalid channel ID "$channelId". Use 1-128 characters: letters, numbers, ".", "_", "-".');
    }

    final channelFile = _channelFileFor(config, normalizedChannelId);
    if (!channelFile.existsSync()) {
      return _error('Channel "$normalizedChannelId" not found.');
    }

    final parser = const ChannelParser();
    final channel = parser.parse(channelFile.readAsStringSync());

    return CallToolResult(content: [
      TextContent(text: formatter.formatStatus(channel)),
    ]);
  }

  final channelsDir = Directory(_absoluteDir(config.storage.channelDir));
  final channelSummaries = <String>[];

  if (channelsDir.existsSync()) {
    for (final file in channelsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))) {
      final parser = const ChannelParser();
      final channel = parser.parse(file.readAsStringSync());
      channelSummaries.add(
          '- ${channel.id}: ${channel.status.toYamlValue()} (${channel.turnCount}/${channel.maxTurns} turns) — ${channel.participants.join(", ")}');
    }
  }

  final result = StringBuffer();
  result.writeln('Project: ${config.project.name}');
  result.writeln('Channels: ${channelSummaries.length}');
  if (channelSummaries.isNotEmpty) {
    result.writeln();
    for (final s in channelSummaries) {
      result.writeln(s);
    }
  }

  return CallToolResult(content: [TextContent(text: result.toString())]);
}

Future<CallToolResult> _closeChannel(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final agent = args['agent'] as String;
  final status = args['status'] as String? ?? 'accepted';
  final normalizedChannelId = _sanitizeArtifactId(channelId);
  if (normalizedChannelId == null) {
    return _error(
        'Invalid channel ID "$channelId". Use 1-128 characters: letters, numbers, ".", "_", "-".');
  }

  WalkiConfig config;
  try {
    config = workspace.loadConfig(_projectDir);
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final channelFile = _channelFileFor(config, normalizedChannelId);
  if (!channelFile.existsSync()) {
    return _error('Channel "$normalizedChannelId" not found.');
  }

  final parser = const ChannelParser();
  final channelContent = channelFile.readAsStringSync();
  final channel = parser.parse(channelContent);

  if (channel.isClosed) {
    return _error('Channel "$normalizedChannelId" is already closed.');
  }

  final agentConfig = config.agents[agent];
  if (agentConfig == null) {
    return _error('Unknown agent "$agent".');
  }
  final permissionEngine = const PermissionEngine();
  if (!permissionEngine.canPerformAction(agentConfig, 'close_channel')) {
    return _error(
        'Permission violations: Agent "${agentConfig.role}" cannot perform action "close_channel"');
  }

  final newStatus = ChannelStatus.fromString(status);
  final formatter = const ChannelFormatter();
  var content = channelContent;
  content = formatter.updateStatus(content, newStatus);
  channelFile.writeAsStringSync(content);

  return CallToolResult(content: [
    TextContent(
        text: 'Channel "$normalizedChannelId" closed with status: $status'),
  ]);
}

Future<CallToolResult> _promoteToSdd(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final agent = args['agent'] as String;
  final target = args['target'] as String? ?? 'sdd-ai';
  final normalizedChannelId = _sanitizeArtifactId(channelId);
  if (normalizedChannelId == null) {
    return _error(
        'Invalid channel ID "$channelId". Use 1-128 characters: letters, numbers, ".", "_", "-".');
  }

  WalkiConfig config;
  try {
    config = workspace.loadConfig(_projectDir);
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final agentConfig = config.agents[agent];
  if (agentConfig == null) {
    return _error('Unknown agent "$agent".');
  }
  final permissionEngine = const PermissionEngine();
  if (!permissionEngine.canPerformAction(agentConfig, 'promote_to_sdd')) {
    return _error(
        'Permission violations: Agent "${agentConfig.role}" cannot perform action "promote_to_sdd"');
  }

  final channelFile = _channelFileFor(config, normalizedChannelId);
  if (!channelFile.existsSync()) {
    return _error('Channel "$normalizedChannelId" not found.');
  }
  final channel = const ChannelParser().parse(channelFile.readAsStringSync());
  if (channel.status != ChannelStatus.accepted) {
    return _error(
        'Channel "$normalizedChannelId" must be accepted before promotion. Current status: ${channel.status.toYamlValue()}');
  }
  if (channel.decisions.isEmpty) {
    return _error(
        'Channel "$normalizedChannelId" has no structured decision to promote.');
  }

  if (target == 'sdd-ai') {
    if (!workspace.hasSddAi(_projectDir)) {
      return _error(
          'sdd-ai directory not found. Enable sdd-ai integration or use target "decisions".');
    }

    final adapter = const SddAiAdapter();
    try {
      final changeDir = adapter.promoteDecision(normalizedChannelId, config);
      return CallToolResult(content: [
        TextContent(text: 'Decision promoted to sdd-ai: $changeDir'),
      ]);
    } catch (e) {
      return _error('Failed to promote: $e');
    }
  }

  final decisionFile = _decisionFileFor(config, normalizedChannelId);

  decisionFile.parent.createSync(recursive: true);
  decisionFile.writeAsStringSync(channelFile.readAsStringSync());

  return CallToolResult(content: [
    TextContent(text: 'Decision promoted to: ${decisionFile.path}'),
  ]);
}

Future<CallToolResult> _initWorkspace(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace already exists.');
  }
  final agents = (args['agents'] as String? ?? 'codex,claude')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final template = args['template'] as String? ?? 'minimal';
  final sddAi = args['sdd_ai'] as bool? ?? false;
  try {
    final dir = workspace.init(
      projectDir: _projectDir,
      template: template,
      agentNames: agents,
      sddAi: sddAi,
    );
    return CallToolResult(content: [
      TextContent(
          text:
              'Walki workspace initialized at $dir with agents: ${agents.join(', ')}'),
    ]);
  } catch (e) {
    return _error('Failed to initialize workspace: $e');
  }
}

Future<CallToolResult> _listAgents(Map<String, dynamic> args) async {
  final config = _loadConfigForMcp();
  if (config == null) {
    return _error('Walki workspace not initialized.');
  }
  if (config.agents.isEmpty) {
    return CallToolResult(
        content: [TextContent(text: 'No agents registered.')]);
  }
  final buffer = StringBuffer('Agents:\n');
  for (final entry in config.agents.entries) {
    buffer.writeln(
        '- ${entry.key}: ${entry.value.role}${entry.value.description.isEmpty ? '' : ' - ${entry.value.description}'}');
  }
  return CallToolResult(content: [TextContent(text: buffer.toString())]);
}

Future<CallToolResult> _addAgent(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace not initialized.');
  }

  // Management tools should generally be restricted or at least validated
  // if an agent ID is provided in the future. For now, we allow it but
  // we should be aware of who is calling.

  final id = args['id'] as String;
  final normalizedId = _sanitizeArtifactId(id);
  if (normalizedId == null) {
    return _error('Invalid agent ID "$id".');
  }
  final role = args['role'] as String? ?? 'implementer';
  final description = args['description'] as String? ?? '';
  final config = workspace.loadConfig();
  if (config.agents.containsKey(normalizedId)) {
    return _error('Agent "$normalizedId" already exists.');
  }
  final agentConfig = AgentConfig.forRole(role, description: description);
  final agents = Map<String, AgentConfig>.from(config.agents)
    ..[normalizedId] = agentConfig;
  workspace.saveConfig(config.copyWith(agents: agents));
  final file = _agentFileFor(normalizedId);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(generateAgentMarkdown(normalizedId, agentConfig));
  return CallToolResult(content: [
    TextContent(
        text: 'Agent "$normalizedId" added with role ${agentConfig.role}.'),
  ]);
}

Future<CallToolResult> _listRules(Map<String, dynamic> args) async {
  final config = _loadConfigForMcp();
  if (config == null) {
    return _error('Walki workspace not initialized.');
  }
  final dir = Directory(_absoluteDir(config.storage.rulesDir));
  if (!dir.existsSync()) {
    return CallToolResult(content: [TextContent(text: 'No rules found.')]);
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    return CallToolResult(content: [TextContent(text: 'No rules found.')]);
  }
  return CallToolResult(content: [
    TextContent(
        text:
            'Rules:\n${files.map((f) => '- ${p.basenameWithoutExtension(f.path)} (${f.path})').join('\n')}'),
  ]);
}

Future<CallToolResult> _addRule(Map<String, dynamic> args) async {
  final config = _loadConfigForMcp();
  if (config == null) {
    return _error('Walki workspace not initialized.');
  }
  final name = _sanitizeArtifactId(args['name'] as String);
  if (name == null) {
    return _error('Invalid rule name.');
  }
  final file = _ruleFileFor(config, name);
  if (file.existsSync()) {
    return _error('Rule "$name" already exists.');
  }
  final description = args['description'] as String? ?? '';
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(_newRuleContent(name, description));
  return CallToolResult(
      content: [TextContent(text: 'Rule "$name" created at ${file.path}.')]);
}

Future<CallToolResult> _showRule(Map<String, dynamic> args) async {
  final config = _loadConfigForMcp();
  if (config == null) {
    return _error('Walki workspace not initialized.');
  }
  final name = _sanitizeArtifactId(args['name'] as String);
  if (name == null) {
    return _error('Invalid rule name.');
  }
  final file = _ruleFileFor(config, name);
  if (!file.existsSync()) {
    return _error('Rule "$name" not found.');
  }
  return CallToolResult(content: [TextContent(text: file.readAsStringSync())]);
}

Future<CallToolResult> _summarizeChannel(Map<String, dynamic> args) async {
  final channelResult = _loadChannelForMcp(args['channel'] as String);
  if (channelResult.error != null) {
    return _error(channelResult.error!);
  }
  final channel = channelResult.channel!;
  final buffer = StringBuffer();
  buffer.writeln('# Summary: ${channel.id}');
  buffer.writeln();
  buffer.writeln('Status: ${channel.status.toYamlValue()}');
  buffer.writeln('Turns: ${channel.turnCount}/${channel.maxTurns}');
  buffer.writeln('Participants: ${channel.participants.join(', ')}');
  if (channel.prompt.isNotEmpty) {
    buffer.writeln('\n## Context\n');
    buffer.writeln(channel.prompt);
  }
  for (final kind in [
    MessageKind.proposal,
    MessageKind.challenge,
    MessageKind.agreement,
    MessageKind.decision
  ]) {
    final messages = channel.messages.where((m) => m.kind == kind).toList();
    if (messages.isEmpty) {
      continue;
    }
    buffer.writeln('\n## ${kind.name}\n');
    for (final message in messages) {
      buffer.writeln(
          '**${message.agent}** (${message.timestamp.toIso8601String()}):');
      buffer.writeln(message.content);
      buffer.writeln();
    }
  }
  if (channel.decisions.isNotEmpty) {
    buffer.writeln('\n## Decisions\n');
    for (final decision in channel.decisions) {
      buffer.writeln('- ${decision.status}: ${decision.summary}');
    }
  }
  return CallToolResult(content: [TextContent(text: buffer.toString())]);
}

Future<CallToolResult> _exportChannel(Map<String, dynamic> args) async {
  final channelResult = _loadChannelForMcp(args['channel'] as String);
  if (channelResult.error != null) {
    return _error(channelResult.error!);
  }
  final format = args['format'] as String? ?? 'markdown';
  if (format == 'markdown') {
    return CallToolResult(
        content: [TextContent(text: channelResult.file!.readAsStringSync())]);
  }
  return CallToolResult(
      content: [TextContent(text: _channelToJson(channelResult.channel!))]);
}

Future<CallToolResult> _doctor(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return _error('Walki workspace not initialized.');
  }
  final issues = <String>[];
  for (final dir in [
    'agents',
    'rules',
    'channels',
    'decisions',
    'tasks',
    'state',
    'locks'
  ]) {
    if (!Directory(p.join(_projectDir, '.walki', dir)).existsSync()) {
      issues.add('.walki/$dir/ directory missing.');
    }
  }
  WalkiConfig config;
  try {
    config = workspace.loadConfig(_projectDir);
  } catch (e) {
    return _error('Invalid config.yaml: $e');
  }
  for (final agent in config.agents.keys) {
    if (!_agentFileFor(agent).existsSync()) {
      issues.add('Agent "$agent" is in config but missing its agent file.');
    }
  }
  if (config.sddAi.enabled && !workspace.hasSddAi(_projectDir)) {
    issues.add('sdd-ai integration enabled but sdd-ai/ directory not found.');
  }
  final channelsDir = Directory(_absoluteDir(config.storage.channelDir));
  if (channelsDir.existsSync()) {
    final parser = const ChannelParser();
    final permissionEngine = const PermissionEngine();
    for (final file in channelsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))) {
      try {
        final channel = parser.parse(file.readAsStringSync());
        issues.addAll(permissionEngine
            .validateChannelHealth(channel)
            .map((issue) => 'Channel ${channel.id}: $issue'));
      } catch (e) {
        issues.add('Failed to parse ${file.path}: $e');
      }
    }
  }
  if (issues.isEmpty) {
    return CallToolResult(content: [
      TextContent(text: 'Walki workspace is healthy. No issues found.')
    ]);
  }
  return CallToolResult(content: [
    TextContent(
        text:
            'Found ${issues.length} issue(s):\n${issues.map((i) => '- $i').join('\n')}')
  ]);
}

final RegExp _artifactIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');

String? _sanitizeArtifactId(String raw) {
  final value = raw.trim();
  if (value.isEmpty ||
      value != raw ||
      !_artifactIdPattern.hasMatch(value) ||
      value.contains('..')) {
    return null;
  }
  return value;
}

String _absoluteDir(String dirPath) {
  if (p.isAbsolute(dirPath)) return p.normalize(dirPath);
  return p.normalize(p.join(_projectDir, dirPath));
}

File _safeMarkdownFile({
  required String baseDir,
  required String id,
}) {
  final normalizedBaseDir = _absoluteDir(baseDir);
  final candidate =
      p.normalize(p.absolute(p.join(normalizedBaseDir, '$id.md')));
  if (!p.isWithin(normalizedBaseDir, candidate)) {
    throw StateError('Resolved path escapes storage directory.');
  }
  return File(candidate);
}

File _channelFileFor(WalkiConfig config, String id) {
  return _safeMarkdownFile(baseDir: config.storage.channelDir, id: id);
}

File _decisionFileFor(WalkiConfig config, String id) {
  return _safeMarkdownFile(baseDir: config.storage.decisionDir, id: id);
}

File _ruleFileFor(WalkiConfig config, String id) {
  return _safeMarkdownFile(baseDir: config.storage.rulesDir, id: id);
}

File _agentFileFor(String id) {
  return _safeMarkdownFile(baseDir: '.walki/agents', id: id);
}

WalkiConfig? _loadConfigForMcp() {
  final workspace = const Workspace();
  if (!workspace.isInitialized(_projectDir)) {
    return null;
  }
  return workspace.loadConfig(_projectDir);
}

class _LoadedChannel {
  const _LoadedChannel({this.channel, this.file, this.error});

  final Channel? channel;
  final File? file;
  final String? error;
}

_LoadedChannel _loadChannelForMcp(String rawId) {
  final config = _loadConfigForMcp();
  if (config == null) {
    return const _LoadedChannel(error: 'Walki workspace not initialized.');
  }
  final id = _sanitizeArtifactId(rawId);
  if (id == null) {
    return _LoadedChannel(error: 'Invalid channel ID "$rawId".');
  }
  final file = _channelFileFor(config, id);
  if (!file.existsSync()) {
    return _LoadedChannel(error: 'Channel "$id" not found.');
  }
  try {
    return _LoadedChannel(
      channel: const ChannelParser().parse(file.readAsStringSync()),
      file: file,
    );
  } catch (e) {
    return _LoadedChannel(error: 'Failed to parse channel "$id": $e');
  }
}

String _newRuleContent(String name, String description) {
  final title = name
      .split('-')
      .map((word) =>
          word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
      .join(' ');
  return '# $title Rules\n\n${description.isNotEmpty ? '$description\n\n' : ''}- Add project-specific guidance here.\n';
}

String _channelToJson(Channel channel) {
  final data = {
    'id': channel.id,
    'status': channel.status.toYamlValue(),
    'created_at': channel.createdAt.toIso8601String(),
    'participants': channel.participants,
    'prompt': channel.prompt,
    'max_turns': channel.maxTurns,
    'messages': channel.messages
        .map(
          (m) => {
            'timestamp': m.timestamp.toIso8601String(),
            'agent': m.agent,
            'kind': m.kind.name,
            'content': m.content,
            'ends_with_over': m.endsWithOver,
          },
        )
        .toList(),
    'decisions': channel.decisions
        .map(
          (d) => {
            'status': d.status,
            'summary': d.summary,
            'rationale': d.rationale,
            'risks': d.risks,
            'required_tests': d.requiredTests,
          },
        )
        .toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

CallToolResult _error(String message) {
  return CallToolResult(
    content: [TextContent(text: 'Error: $message')],
    isError: true,
  );
}
