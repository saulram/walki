/// Lifecycle states for a Walki debate channel.
enum ChannelStatus {
  /// Channel exists but has no activity yet.
  open,

  /// Channel has ongoing debate activity.
  active,

  /// Channel reached an accepted decision.
  accepted,

  /// Channel is blocked by a technical or process constraint.
  blocked,

  /// Channel needs explicit owner/human intervention.
  needsHuman,

  /// Channel lacks required context to continue.
  needsContext,

  /// Channel was replaced by a newer debate.
  superseded,

  /// Channel was intentionally stopped without resolution.
  abandoned,

  /// Channel decision has been promoted to a downstream artifact.
  promoted,

  /// Channel is closed and should not accept more messages.
  closed;

  /// Parses a kebab-case or camel-case status string.
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

  /// Serializes the status value as kebab-case for YAML/markdown metadata.
  String toYamlValue() => _camelToKebab(name);
}

/// Message categories used in channel entries.
enum MessageKind {
  /// A proposed approach or recommendation.
  proposal,

  /// A critical review of another proposal.
  challenge,

  /// A request for missing information.
  question,

  /// A follow-up detail that removes ambiguity.
  clarification,

  /// Explicit agreement with a prior point.
  agreement,

  /// Explicit disagreement with a prior point.
  objection,

  /// A decision record entry from an agent.
  decision,

  /// Additional context relevant to the debate.
  context,

  /// Condensed recap of channel progress.
  summary,

  /// Process or coordination note about the debate itself.
  meta;

  /// Parses a string into a [MessageKind], defaulting to [proposal].
  static MessageKind fromString(String value) {
    return MessageKind.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => MessageKind.proposal,
    );
  }
}

/// Single append-only message inside a debate channel.
class ChannelMessage {
  /// Creates a [ChannelMessage].
  const ChannelMessage({
    required this.agent,
    required this.kind,
    required this.content,
    required this.timestamp,
    this.endsWithOver = true,
  });

  /// Agent identifier that authored the message.
  final String agent;

  /// Type of message represented by this entry.
  final MessageKind kind;

  /// Free-form message body.
  final String content;

  /// Creation time of the message.
  final DateTime timestamp;

  /// Whether the entry ended with the `OVER` marker.
  final bool endsWithOver;
}

/// Structured decision block captured in a channel file.
class ChannelDecision {
  /// Creates a [ChannelDecision].
  const ChannelDecision({
    required this.status,
    required this.summary,
    this.rationale = '',
    this.risks = const [],
    this.implications = const [],
    this.requiredTests = const [],
    this.owner = '',
  });

  /// Decision status label, for example `proposed` or `accepted`.
  final String status;

  /// One-line or short decision statement.
  final String summary;

  /// Why the decision is preferred.
  final String rationale;

  /// Risks introduced by this decision.
  final List<String> risks;

  /// Expected downstream impacts of this decision.
  final List<String> implications;

  /// Required tests before implementation is complete.
  final List<String> requiredTests;

  /// Optional owner responsible for this decision.
  final String owner;
}

/// Complete in-memory representation of a Walki debate channel.
class Channel {
  /// Creates a [Channel].
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

  /// Channel identifier.
  final String id;

  /// Current lifecycle status.
  final ChannelStatus status;

  /// Timestamp when the channel was created.
  final DateTime createdAt;

  /// Agent identifiers allowed to participate.
  final List<String> participants;

  /// User prompt that initiated this debate.
  final String prompt;

  /// Paths or labels for loaded instructions applied to this channel.
  final List<String> loadedInstructions;

  /// Working rules shown at the top of the channel.
  final List<String> workingRules;

  /// Ordered messages appended by participants.
  final List<ChannelMessage> messages;

  /// Structured decisions recorded in the channel.
  final List<ChannelDecision> decisions;

  /// Maximum number of turns allowed for this debate.
  final int maxTurns;

  /// Number of messages currently in the channel.
  int get turnCount => messages.length;

  /// Whether the channel is still writable.
  bool get isOpen => status == ChannelStatus.open || status == ChannelStatus.active;

  /// Whether the channel is in a terminal state.
  bool get isClosed => !isOpen;

  /// Returns a copy with selected fields replaced.
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
