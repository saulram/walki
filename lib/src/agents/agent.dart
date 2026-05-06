class Agent {
  const Agent({
    required this.id,
    required this.role,
    this.description = '',
    this.can = const [],
  });

  final String id;
  final String role;
  final String description;
  final List<String> can;

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Agent: $id');
    buffer.writeln();
    buffer.writeln('- **ID**: $id');
    buffer.writeln('- **Role**: $role');
    buffer.writeln('- **Description**: ${description.isEmpty ? "No description" : description}');
    buffer.writeln('- **Can**:');
    for (final permission in can) {
      buffer.writeln('  - $permission');
    }
    buffer.writeln();

    buffer.writeln('## Prompt');
    buffer.writeln();
    buffer.writeln('You are $id, the ${_roleDescription()} agent in a Walki debate.');
    buffer.writeln();
    buffer.writeln('Rules:');
    buffer.writeln('- Read the entire channel before writing.');
    buffer.writeln('- Append only. Never overwrite previous messages.');
    buffer.writeln('- End your message with OVER.');
    buffer.writeln('- Make proposals explicit.');
    buffer.writeln('- Include risks and required tests.');
    buffer.writeln('- Stop when consensus is reached, context is missing, or human input is required.');
    buffer.writeln();

    return buffer.toString();
  }

  String _roleDescription() {
    switch (role) {
      case 'implementer':
        return 'implementation-oriented';
      case 'reviewer':
        return 'architecture and review-oriented';
      case 'owner':
        return 'owner and decision-maker';
      default:
        return role;
    }
  }
}