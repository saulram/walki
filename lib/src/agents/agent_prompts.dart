import '../config/agent_config.dart';

/// Renders the Markdown file stored under `.walki/agents/<id>.md`.
String generateAgentMarkdown(String id, AgentConfig config) {
  final buffer = StringBuffer();
  buffer.writeln('# Agent: $id');
  buffer.writeln();
  buffer.writeln('- **ID**: $id');
  buffer.writeln('- **Role**: ${config.role}');
  if (config.description.isNotEmpty) {
    buffer.writeln('- **Description**: ${config.description}');
  }
  buffer.writeln('- **Can**:');
  for (final permission in config.can) {
    buffer.writeln('  - $permission');
  }
  buffer.writeln();
  buffer.writeln('## Debate Prompt');
  buffer.writeln();
  buffer.writeln(generateAgentPrompt(id, config, '<channel-name>'));
  return buffer.toString();
}

/// Renders a copy-paste prompt for an agent in a specific channel.
String generateAgentPrompt(String id, AgentConfig config, String channelId) {
  final roleDesc = switch (config.role) {
    'implementer' => 'implementation-oriented',
    'reviewer' => 'architecture and review-oriented',
    'owner' => 'owner and decision-maker',
    _ => config.role,
  };
  final focus = switch (config.role) {
    'implementer' =>
      'Focus on implementation plan, edge cases, migrations, and tests.',
    'reviewer' =>
      'Focus on architecture, security, correctness, maintainability, and tradeoffs. Challenge weak proposals constructively.',
    'owner' =>
      'You are the owner. Accept or reject decisions. Promote accepted decisions.',
    _ => config.description.isNotEmpty
        ? config.description
        : 'Follow your configured Walki permissions and participate constructively.',
  };

  return 'You are $id, the $roleDesc agent in a Walki debate.\n\n'
      'Channel:\n.walki/channels/$channelId.md\n\n'
      'Read the entire channel before writing.\n'
      'Append only.\n'
      'End your message with OVER.\n'
      '$focus\n'
      'If you created this channel or are the lead agent, you are the Coordinator. '
      'You should use Walki tools to invite participants (walki_add_agent) and manage turns. '
      'Walki is a protocol; you must coordinate the flow of the debate.\n'
      'Do not accept final decisions without human confirmation.\n'
      'You may propose decisions.\n';
}
