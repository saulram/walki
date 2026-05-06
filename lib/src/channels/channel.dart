enum ChannelStatus {
  open,
  active,
  accepted,
  blocked,
  needsHuman,
  needsContext,
  superseded,
  abandoned,
  promoted,
  closed;

  static ChannelStatus fromString(String value) {
    final normalized = value.toLowerCase();
    for (final status in ChannelStatus.values) {
      final statusKebab = _camelToKebab(status.name);
      if (statusKebab == normalized || status.name.toLowerCase() == normalized) {
        return status;
      }
    }
    return ChannelStatus.open;
  }

  static String _camelToKebab(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '-${match.group(0)!.toLowerCase()}',
    );
  }

  String toYamlValue() => name.replaceAll('_', '-');
}

enum MessageKind {
  proposal,
  challenge,
  question,
  clarification,
  agreement,
  objection,
  decision,
  context,
  summary,
  meta;

  static MessageKind fromString(String value) {
    return MessageKind.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => MessageKind.proposal,
    );
  }
}

class ChannelMessage {
  const ChannelMessage({
    required this.agent,
    required this.kind,
    required this.content,
    required this.timestamp,
    this.endsWithOver = true,
  });

  final String agent;
  final MessageKind kind;
  final String content;
  final DateTime timestamp;
  final bool endsWithOver;
}

class ChannelDecision {
  const ChannelDecision({
    required this.status,
    required this.summary,
    this.rationale = '',
    this.risks = const [],
    this.implications = const [],
    this.requiredTests = const [],
    this.owner = '',
  });

  final String status;
  final String summary;
  final String rationale;
  final List<String> risks;
  final List<String> implications;
  final List<String> requiredTests;
  final String owner;
}

class Channel {
  const Channel({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.participants,
    this.prompt = '',
    this.loadedInstructions = const [],
    this.workingRules = const [],
    this.messages = const [],
    this.decisions = const [],
    this.maxTurns = 8,
  });

  final String id;
  final ChannelStatus status;
  final DateTime createdAt;
  final List<String> participants;
  final String prompt;
  final List<String> loadedInstructions;
  final List<String> workingRules;
  final List<ChannelMessage> messages;
  final List<ChannelDecision> decisions;
  final int maxTurns;

  int get turnCount => messages.length;

  bool get isOpen => status == ChannelStatus.open || status == ChannelStatus.active;
  bool get isClosed => !isOpen;

  Channel copyWith({
    ChannelStatus? status,
    List<String>? participants,
    String? prompt,
    List<String>? loadedInstructions,
    List<String>? workingRules,
    List<ChannelMessage>? messages,
    List<ChannelDecision>? decisions,
    int? maxTurns,
  }) {
    return Channel(
      id: id,
      status: status ?? this.status,
      createdAt: createdAt,
      participants: participants ?? this.participants,
      prompt: prompt ?? this.prompt,
      loadedInstructions: loadedInstructions ?? this.loadedInstructions,
      workingRules: workingRules ?? this.workingRules,
      messages: messages ?? this.messages,
      decisions: decisions ?? this.decisions,
      maxTurns: maxTurns ?? this.maxTurns,
    );
  }
}