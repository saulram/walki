class Task {
  const Task({
    required this.id,
    required this.channelId,
    required this.description,
    required this.status,
    required this.decisionId,
    this.suggestedOwner = '',
    this.acceptanceCriteria = const [],
    required this.createdAt,
  });

  final String id;
  final String channelId;
  final String description;
  final String status;
  final String decisionId;
  final String suggestedOwner;
  final List<String> acceptanceCriteria;
  final DateTime createdAt;

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Task: $id');
    buffer.writeln();
    buffer.writeln('- channel: $channelId');
    buffer.writeln('- decision: $decisionId');
    buffer.writeln('- status: $status');
    buffer.writeln('- suggested_owner: ${suggestedOwner.isEmpty ? "pending" : suggestedOwner}');
    buffer.writeln('- created_at: ${createdAt.toUtc().toIso8601String()}');
    buffer.writeln();

    buffer.writeln('## Description');
    buffer.writeln();
    buffer.writeln(description);
    buffer.writeln();

    if (acceptanceCriteria.isNotEmpty) {
      buffer.writeln('## Acceptance Criteria');
      buffer.writeln();
      for (final criterion in acceptanceCriteria) {
        buffer.writeln('- $criterion');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}