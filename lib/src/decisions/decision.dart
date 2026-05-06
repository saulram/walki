class Decision {
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

  final String channelId;
  final String status;
  final String summary;
  final String rationale;
  final List<String> risks;
  final List<String> implications;
  final List<String> requiredTests;
  final String owner;
  final DateTime createdAt;

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