class AgentConfig {
  const AgentConfig({
    required this.role,
    this.description = '',
    this.can = const [],
  });

  final String role;
  final String description;
  final List<String> can;

  factory AgentConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return AgentConfig(
      role: yaml['role'] as String? ?? 'implementer',
      description: yaml['description'] as String? ?? '',
      can: (yaml['can'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  Map<String, dynamic> toYaml() => {
        'role': role,
        'description': description,
        'can': can,
      };

  static AgentConfig implementer({String description = ''}) {
    return AgentConfig(
      role: 'implementer',
      description: description,
      can: ['read', 'append', 'propose_decision', 'propose_task'],
    );
  }

  static AgentConfig reviewer({String description = ''}) {
    return AgentConfig(
      role: 'reviewer',
      description: description,
      can: [
        'read',
        'append',
        'challenge_decision',
        'propose_decision',
        'propose_task',
      ],
    );
  }

  static AgentConfig owner() {
    return const AgentConfig(
      role: 'owner',
      can: [
        'read',
        'append',
        'accept_decision',
        'reject_decision',
        'close_channel',
        'promote_to_sdd',
      ],
    );
  }
}