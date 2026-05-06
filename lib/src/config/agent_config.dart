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
