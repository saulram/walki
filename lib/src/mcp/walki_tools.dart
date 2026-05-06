import 'dart:io';
import 'package:mcp_server/mcp_server.dart';
import '../channels/channel.dart';
import '../channels/channel_parser.dart';
import '../channels/channel_formatter.dart';
import '../config/walki_config.dart';
import '../sdd_ai/sdd_ai_adapter.dart';
import '../storage/workspace.dart';
import '../validation/permission_engine.dart';

void registerWalkiTools(Server server) {
  server.addTool(
    name: 'walki_open_channel',
    description: 'Open a new debate channel for agents to deliberate. Creates a Markdown file with metadata, instructions, and working rules. Returns the channel ID and agent prompts.',
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
          'description': 'Comma-separated list of agent names (e.g., "codex,claude")',
        },
        'rules': {
          'type': 'string',
          'description': 'Comma-separated list of rule files to load (e.g., "security,testing")',
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
    description: 'Read the contents of a debate channel. Returns the full Markdown content or a summary of the last N messages.',
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
    description: 'Post a message to a debate channel. The agent reads the channel, then appends a message. Every message ends with the OVER marker by default.',
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
          'enum': ['proposal', 'challenge', 'question', 'clarification', 'agreement', 'objection', 'decision', 'context', 'summary', 'meta'],
          'description': 'The kind of message (default: proposal)',
        },
      },
      'required': ['channel', 'agent', 'message'],
    },
    handler: _postMessage,
  );

  server.addTool(
    name: 'walki_propose_decision',
    description: 'Propose a decision for a debate channel. Records the decision with rationale, risks, and required tests.',
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
          'description': 'List of tests required before the decision can be accepted',
        },
      },
      'required': ['channel', 'agent', 'summary'],
    },
    handler: _proposeDecision,
  );

  server.addTool(
    name: 'walki_get_status',
    description: 'Get the status of a specific channel or overview of all channels in the workspace. Returns status, participants, turn count, and last action.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {
          'type': 'string',
          'description': 'Optional channel ID. If omitted, returns overview of all channels.',
        },
      },
    },
    handler: _getStatus,
  );

  server.addTool(
    name: 'walki_close_channel',
    description: 'Close a debate channel with a specific status (accepted, blocked, needs-human, abandoned). Prevents further messages.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {
          'type': 'string',
          'description': 'The channel ID to close',
        },
        'status': {
          'type': 'string',
          'enum': ['accepted', 'blocked', 'needs-human', 'abandoned', 'superseded', 'needs-context'],
          'description': 'The status to close the channel with (default: accepted)',
        },
      },
      'required': ['channel'],
    },
    handler: _closeChannel,
  );

  server.addTool(
    name: 'walki_promote_to_sdd',
    description: 'Promote a channel decision to sdd-ai or a decisions file. Creates change folders and copies the debate artifacts.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'channel': {
          'type': 'string',
          'description': 'The channel ID to promote',
        },
        'target': {
          'type': 'string',
          'enum': ['sdd-ai', 'decisions'],
          'description': 'Promotion target (default: sdd-ai)',
        },
      },
      'required': ['channel'],
    },
    handler: _promoteToSdd,
  );
}

Future<dynamic> _openChannel(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized()) {
    return _error('Walki workspace not initialized. Run walki init first.');
  }

  final id = args['id'] as String;
  final prompt = args['prompt'] as String;
  final agentsStr = args['agents'] as String? ?? '';
  final maxTurns = args['max_turns'] as int? ?? 8;

  WalkiConfig config;
  try {
    config = workspace.loadConfig();
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final participants = agentsStr.isNotEmpty
      ? agentsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
      : config.agents.keys.where((k) => k != 'human').toList();

  final channelFile = File('${config.storage.channelDir}/$id.md');
  if (channelFile.existsSync()) {
    return _error('Channel "$id" already exists.');
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
    id: id,
    status: ChannelStatus.open,
    createdAt: DateTime.now(),
    participants: participants,
    prompt: prompt,
    loadedInstructions: config.instructions.load,
    workingRules: workingRules,
    maxTurns: maxTurns,
  );

  final formatter = const ChannelFormatter();
  channelFile.writeAsStringSync(formatter.format(channel));

  final prompts = <String, String>{};
  for (final agentId in participants) {
    final agentConfig = config.agents[agentId];
    if (agentConfig != null) {
      prompts[agentId] = _generateAgentPrompt(agentId, agentConfig.role, id);
    }
  }

  return {
    'content': [
      {'type': 'text', 'text': 'Channel "$id" created with ${participants.length} participants and $maxTurns max turns.'},
    ],
    'channel_id': id,
    'status': 'open',
    'participants': participants,
    'max_turns': maxTurns,
    'prompts': prompts,
  };
}

Future<dynamic> _readChannel(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized()) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final tail = args['tail'] as int?;

  WalkiConfig config;
  try {
    config = workspace.loadConfig();
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final channelFile = File('${config.storage.channelDir}/$channelId.md');
  if (!channelFile.existsSync()) {
    return _error('Channel "$channelId" not found.');
  }

  final parser = const ChannelParser();
  final channel = parser.parse(channelFile.readAsStringSync());

  if (tail != null && tail < channel.messages.length) {
    final messages = channel.messages.reversed.take(tail).toList().reversed;
    final result = StringBuffer();
    result.writeln('Channel: ${channel.id} (last $tail messages)');
    result.writeln('Status: ${channel.status.toYamlValue()}');
    result.writeln();
    for (final msg in messages) {
      result.writeln('${msg.timestamp.toIso8601String()} - ${msg.agent} (${msg.kind.name}):');
      result.writeln(msg.content);
      result.writeln();
    }
    return {'content': [{'type': 'text', 'text': result.toString()}]};
  }

  return {
    'content': [{'type': 'text', 'text': channelFile.readAsStringSync()}],
  };
}

Future<dynamic> _postMessage(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized()) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final agent = args['agent'] as String;
  final message = args['message'] as String;
  final kind = args['kind'] as String? ?? 'proposal';

  WalkiConfig config;
  try {
    config = workspace.loadConfig();
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final channelFile = File('${config.storage.channelDir}/$channelId.md');
  if (!channelFile.existsSync()) {
    return _error('Channel "$channelId" not found.');
  }

  final parser = const ChannelParser();
  final channel = parser.parse(channelFile.readAsStringSync());

  if (channel.isClosed) {
    return _error('Channel "$channelId" is closed.');
  }

  final agentConfig = config.agents[agent];
  final permissionEngine = const PermissionEngine();
  if (agentConfig != null) {
    final violations = permissionEngine.validateMessage(
      agentConfig,
      channel,
      'append',
      agentId: agent,
    );
    if (violations.isNotEmpty) {
      return _error('Permission violations: ${violations.join("; ")}');
    }
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

  return {
    'content': [
      {'type': 'text', 'text': 'Message appended to channel "$channelId" by $agent ($kind). Turn ${updatedChannel.turnCount}/${channel.maxTurns}.'},
    ],
    'channel_id': channelId,
    'agent': agent,
    'kind': kind,
    'turn': updatedChannel.turnCount,
  };
}

Future<dynamic> _proposeDecision(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized()) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final agent = args['agent'] as String;
  final summary = args['summary'] as String;
  final rationale = args['rationale'] as String? ?? '';
  final risks = (args['risks'] as List<dynamic>?)?.cast<String>().toList() ?? [];
  final requiredTests = (args['required_tests'] as List<dynamic>?)?.cast<String>().toList() ?? [];

  WalkiConfig config;
  try {
    config = workspace.loadConfig();
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final channelFile = File('${config.storage.channelDir}/$channelId.md');
  if (!channelFile.existsSync()) {
    return _error('Channel "$channelId" not found.');
  }

  final parser = const ChannelParser();
  final channel = parser.parse(channelFile.readAsStringSync());

  if (channel.isClosed) {
    return _error('Channel "$channelId" is closed.');
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

  final updatedContent = channelFile.readAsStringSync() + decisionBlock;
  channelFile.writeAsStringSync(updatedContent);

  return {
    'content': [
      {'type': 'text', 'text': 'Decision proposed in channel "$channelId" by $agent: $summary'},
    ],
    'channel_id': channelId,
    'decision_status': 'proposed',
  };
}

Future<dynamic> _getStatus(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized()) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String?;

  WalkiConfig config;
  try {
    config = workspace.loadConfig();
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final formatter = const ChannelFormatter();

  if (channelId != null) {
    final channelFile = File('${config.storage.channelDir}/$channelId.md');
    if (!channelFile.existsSync()) {
      return _error('Channel "$channelId" not found.');
    }

    final parser = const ChannelParser();
    final channel = parser.parse(channelFile.readAsStringSync());

    return {
      'content': [
        {'type': 'text', 'text': formatter.formatStatus(channel)},
      ],
      'id': channel.id,
      'status': channel.status.toYamlValue(),
      'turns': channel.turnCount,
      'max_turns': channel.maxTurns,
      'participants': channel.participants,
    };
  }

  final channelsDir = Directory(config.storage.channelDir);
  final channels = <Map<String, dynamic>>[];

  if (channelsDir.existsSync()) {
    for (final file in channelsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.md'))) {
      final parser = const ChannelParser();
      final channel = parser.parse(file.readAsStringSync());
      channels.add({
        'id': channel.id,
        'status': channel.status.toYamlValue(),
        'turns': channel.turnCount,
        'max_turns': channel.maxTurns,
        'participants': channel.participants,
      });
    }
  }

  return {
    'content': [
      {'type': 'text', 'text': 'Project: ${config.project.name}\nChannels: ${channels.length}'},
    ],
    'channels': channels,
    'sdd_ai_enabled': config.sddAi.enabled,
  };
}

Future<dynamic> _closeChannel(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized()) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final status = args['status'] as String? ?? 'accepted';

  WalkiConfig config;
  try {
    config = workspace.loadConfig();
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  final channelFile = File('${config.storage.channelDir}/$channelId.md');
  if (!channelFile.existsSync()) {
    return _error('Channel "$channelId" not found.');
  }

  final parser = const ChannelParser();
  final channel = parser.parse(channelFile.readAsStringSync());

  if (channel.isClosed) {
    return _error('Channel "$channelId" is already closed.');
  }

  final newStatus = ChannelStatus.fromString(status);
  final updatedChannel = channel.copyWith(status: newStatus);

  final formatter = const ChannelFormatter();
  channelFile.writeAsStringSync(formatter.format(updatedChannel));

  return {
    'content': [
      {'type': 'text', 'text': 'Channel "$channelId" closed with status: $status'},
    ],
    'channel_id': channelId,
    'status': status,
  };
}

Future<dynamic> _promoteToSdd(Map<String, dynamic> args) async {
  final workspace = const Workspace();
  if (!workspace.isInitialized()) {
    return _error('Walki workspace not initialized.');
  }

  final channelId = args['channel'] as String;
  final target = args['target'] as String? ?? 'sdd-ai';

  WalkiConfig config;
  try {
    config = workspace.loadConfig();
  } catch (e) {
    return _error('Failed to load config: $e');
  }

  if (target == 'sdd-ai') {
    if (!workspace.hasSddAi()) {
      return _error('sdd-ai directory not found. Enable sdd-ai integration or use target "decisions".');
    }

    final adapter = const SddAiAdapter();
    try {
      final changeDir = adapter.promoteDecision(channelId, config);
      return {
        'content': [
          {'type': 'text', 'text': 'Decision promoted to sdd-ai: $changeDir'},
        ],
        'change_dir': changeDir,
      };
    } catch (e) {
      return _error('Failed to promote: $e');
    }
  }

  final channelFile = File('${config.storage.channelDir}/$channelId.md');
  final decisionFile = File('${config.storage.decisionDir}/$channelId.md');

  if (!channelFile.existsSync()) {
    return _error('Channel "$channelId" not found.');
  }

  decisionFile.parent.createSync(recursive: true);
  decisionFile.writeAsStringSync(channelFile.readAsStringSync());

  return {
    'content': [
      {'type': 'text', 'text': 'Decision promoted to: ${decisionFile.path}'},
    ],
    'path': decisionFile.path,
  };
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

Map<String, dynamic> _error(String message) {
  return {
    'content': [
      {'type': 'text', 'text': 'Error: $message'},
    ],
    'isError': true,
  };
}