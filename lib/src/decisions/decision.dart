/// Persisted decision artifact derived from a debate channel.
class Decision {
  /// Creates a [Decision].
  const Decision({
    required this.channelId,
    required this.status,
    required this.summary,
    required this.rationale,
    this.risks = const [],
    this.implications = const [],
    this.requiredTests = const [],
    this.owner = '',
    required this.createdAt,
  });

  /// Source channel identifier.
  final String channelId;

  /// Decision status.
  final String status;

  /// Decision summary.
  final String summary;

  /// Decision rationale.
  final String rationale;

  /// Risks associated with this decision.
  final List<String> risks;

  /// Expected implications of this decision.
  final List<String> implications;

  /// Required tests for safe implementation.
  final List<String> requiredTests;

  /// Owner responsible for this decision.
  final String owner;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Serializes this decision to markdown.
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Decision: $channelId');
    buffer.writeln();
    buffer.writeln('- channel: $channelId');
    buffer.writeln('- status: $status');
    buffer.writeln('- created_at: ${createdAt.toUtc().toIso8601String()}');
    buffer.writeln('- owner: ${owner.isEmpty ? "pending" : owner}');
    buffer.writeln();

    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln(summary);
    buffer.writeln();

    buffer.writeln('## Rationale');
    buffer.writeln();
    buffer.writeln(rationale);
    buffer.writeln();

    if (risks.isNotEmpty) {
      buffer.writeln('## Risks');
      buffer.writeln();
      for (final risk in risks) {
        buffer.writeln('- $risk');
      }
      buffer.writeln();
    }

    if (implications.isNotEmpty) {
      buffer.writeln('## Implications');
      buffer.writeln();
      for (final imp in implications) {
        buffer.writeln('- $imp');
      }
      buffer.writeln();
    }

    if (requiredTests.isNotEmpty) {
      buffer.writeln('## Required Tests');
      buffer.writeln();
      for (final test in requiredTests) {
        buffer.writeln('- $test');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
