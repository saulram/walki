/// Serializable configuration for an agent defined in `config.yaml`.
class AgentConfig {
  /// Creates an [AgentConfig].
  const AgentConfig({
    required this.role,
    this.description = '',
    this.can = const [],
  });

  /// Agent role name.
  final String role;

  /// Optional text describing the agent specialization.
  final String description;

  /// Allowed actions for this role.
  final List<String> can;

  /// Builds an [AgentConfig] from YAML data.
  factory AgentConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return AgentConfig(
      role: yaml['role'] as String? ?? 'implementer',
      description: yaml['description'] as String? ?? '',
      can: (yaml['can'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  /// Converts this config into YAML-compatible data.
  Map<String, dynamic> toYaml() => {
        'role': role,
        'description': description,
        'can': can,
      };

  /// Default permissions for implementation-focused agents.
  AgentConfig copyWith({
    String? role,
    String? description,
    List<String>? can,
  }) {
    return AgentConfig(
      role: role ?? this.role,
      description: description ?? this.description,
      can: can ?? this.can,
    );
  }

  /// Default permissions for implementation-focused agents.
  static AgentConfig implementer({String description = ''}) {
    return AgentConfig(
      role: 'implementer',
      description: description,
      can: ['read', 'append', 'propose_decision', 'propose_task'],
    );
  }

  /// Default permissions for review-focused agents.
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

  /// Default permissions for the human owner role.
  static AgentConfig owner({String description = ''}) {
    return AgentConfig(
      role: 'owner',
      description: description,
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

  /// Builds a default agent config for a known role.
  static AgentConfig forRole(String role, {String description = ''}) {
    return switch (role) {
      'implementer' => AgentConfig.implementer(description: description),
      'reviewer' => AgentConfig.reviewer(description: description),
      'owner' => AgentConfig.owner(description: description),
      _ => AgentConfig(
          role: role,
          description: description,
          can: ['read', 'append', 'propose_decision', 'propose_task'],
        ),
    };
  }
}
