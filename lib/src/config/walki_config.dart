import 'agent_config.dart';

/// Root configuration model for a Walki workspace.
class WalkiConfig {
  /// Creates a [WalkiConfig].
  const WalkiConfig({
    this.version = 1,
    required this.project,
    this.storage = const StorageConfig(),
    this.agents = const {},
    this.instructions = const InstructionConfig(),
    this.limits = const LimitsConfig(),
    this.decisions = const DecisionsConfig(),
    this.sddAi = const SddAiConfig(),
  });

  /// Config schema version.
  final int version;

  /// Project-level metadata.
  final ProjectConfig project;

  /// Storage layout configuration.
  final StorageConfig storage;

  /// Registered agents keyed by identifier.
  final Map<String, AgentConfig> agents;

  /// Instruction loading configuration.
  final InstructionConfig instructions;

  /// Debate constraints and stopping limits.
  final LimitsConfig limits;

  /// Decision validation and promotion requirements.
  final DecisionsConfig decisions;

  /// sdd-ai integration settings.
  final SddAiConfig sddAi;

  /// Builds [WalkiConfig] from YAML data.
  factory WalkiConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    final agentsRaw = yaml['agents'] as Map<dynamic, dynamic>? ?? {};
    final agents = <String, AgentConfig>{};
    for (final entry in agentsRaw.entries) {
      agents[entry.key as String] = AgentConfig.fromYaml(entry.value as Map<dynamic, dynamic>);
    }

    return WalkiConfig(
      version: yaml['version'] as int? ?? 1,
      project: ProjectConfig.fromYaml(yaml['project'] as Map<dynamic, dynamic>? ?? {}),
      storage: StorageConfig.fromYaml(yaml['storage'] as Map<dynamic, dynamic>? ?? {}),
      agents: agents,
      instructions: InstructionConfig.fromYaml(yaml['instructions'] as Map<dynamic, dynamic>? ?? {}),
      limits: LimitsConfig.fromYaml(yaml['limits'] as Map<dynamic, dynamic>? ?? {}),
      decisions: DecisionsConfig.fromYaml(yaml['decisions'] as Map<dynamic, dynamic>? ?? {}),
      sddAi: SddAiConfig.fromYaml(yaml['sdd_ai'] as Map<dynamic, dynamic>? ?? {}),
    );
  }

  /// Converts this config into YAML-compatible data.
  Map<String, dynamic> toYaml() {
    return {
      'version': version,
      'project': project.toYaml(),
      'storage': storage.toYaml(),
      'agents': agents.map((k, v) => MapEntry(k, v.toYaml())),
      'instructions': instructions.toYaml(),
      'limits': limits.toYaml(),
      'decisions': decisions.toYaml(),
      'sdd_ai': sddAi.toYaml(),
    };
  }

  /// Returns a copy with selected fields replaced.
  WalkiConfig copyWith({
    ProjectConfig? project,
    StorageConfig? storage,
    Map<String, AgentConfig>? agents,
    InstructionConfig? instructions,
    LimitsConfig? limits,
    DecisionsConfig? decisions,
    SddAiConfig? sddAi,
  }) {
    return WalkiConfig(
      version: version,
      project: project ?? this.project,
      storage: storage ?? this.storage,
      agents: agents ?? this.agents,
      instructions: instructions ?? this.instructions,
      limits: limits ?? this.limits,
      decisions: decisions ?? this.decisions,
      sddAi: sddAi ?? this.sddAi,
    );
  }
}

/// Project identity values.
class ProjectConfig {
  /// Creates a [ProjectConfig].
  const ProjectConfig({this.name = ''});

  /// Project name.
  final String name;

  /// Builds [ProjectConfig] from YAML data.
  factory ProjectConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return ProjectConfig(name: yaml['name'] as String? ?? '');
  }

  /// Converts this config into YAML-compatible data.
  Map<String, dynamic> toYaml() => {'name': name};
}

/// Filesystem paths and primary format used by Walki artifacts.
class StorageConfig {
  /// Creates a [StorageConfig].
  const StorageConfig({
    this.primaryFormat = 'markdown',
    this.channelDir = '.walki/channels',
    this.decisionDir = '.walki/decisions',
    this.taskDir = '.walki/tasks',
    this.generatedStateDir = '.walki/state',
  });

  /// Canonical storage format, currently `markdown`.
  final String primaryFormat;

  /// Relative directory for channel files.
  final String channelDir;

  /// Relative directory for promoted decision files.
  final String decisionDir;

  /// Relative directory for task files.
  final String taskDir;

  /// Relative directory for generated state files.
  final String generatedStateDir;

  /// Builds [StorageConfig] from YAML data.
  factory StorageConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return StorageConfig(
      primaryFormat: yaml['primary_format'] as String? ?? 'markdown',
      channelDir: yaml['channel_dir'] as String? ?? '.walki/channels',
      decisionDir: yaml['decision_dir'] as String? ?? '.walki/decisions',
      taskDir: yaml['task_dir'] as String? ?? '.walki/tasks',
      generatedStateDir: yaml['generated_state_dir'] as String? ?? '.walki/state',
    );
  }

  /// Converts this config into YAML-compatible data.
  Map<String, dynamic> toYaml() => {
        'primary_format': primaryFormat,
        'channel_dir': channelDir,
        'decision_dir': decisionDir,
        'task_dir': taskDir,
        'generated_state_dir': generatedStateDir,
      };
}

/// Explicit extra instruction files to load during debates.
class InstructionConfig {
  /// Creates an [InstructionConfig].
  const InstructionConfig({this.load = const []});

  /// Relative file paths loaded as additional instructions.
  final List<String> load;

  /// Builds [InstructionConfig] from YAML data.
  factory InstructionConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return InstructionConfig(
      load: (yaml['load'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  /// Converts this config into YAML-compatible data.
  Map<String, dynamic> toYaml() => {'load': load};
}

/// Debate lifecycle limits and stop conditions.
class LimitsConfig {
  /// Creates a [LimitsConfig].
  const LimitsConfig({
    this.maxTurns = 8,
    this.maxMessagesPerAgent = 4,
    this.maxDecisionsPerChannel = 5,
    this.requireOverMarker = true,
    this.stopOnConsensus = true,
    this.stopOnBlocked = true,
    this.stopOnMissingContext = true,
  });

  /// Maximum turns allowed per channel.
  final int maxTurns;

  /// Maximum messages allowed per agent.
  final int maxMessagesPerAgent;

  /// Maximum structured decisions allowed per channel.
  final int maxDecisionsPerChannel;

  /// Whether each message must end with the `OVER` marker.
  final bool requireOverMarker;

  /// Whether debate should stop on consensus.
  final bool stopOnConsensus;

  /// Whether debate should stop when blocked.
  final bool stopOnBlocked;

  /// Whether debate should stop when context is missing.
  final bool stopOnMissingContext;

  /// Builds [LimitsConfig] from YAML data.
  factory LimitsConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return LimitsConfig(
      maxTurns: yaml['max_turns'] as int? ?? 8,
      maxMessagesPerAgent: yaml['max_messages_per_agent'] as int? ?? 4,
      maxDecisionsPerChannel: yaml['max_decisions_per_channel'] as int? ?? 5,
      requireOverMarker: yaml['require_over_marker'] as bool? ?? true,
      stopOnConsensus: yaml['stop_on_consensus'] as bool? ?? true,
      stopOnBlocked: yaml['stop_on_blocked'] as bool? ?? true,
      stopOnMissingContext: yaml['stop_on_missing_context'] as bool? ?? true,
    );
  }

  /// Converts this config into YAML-compatible data.
  Map<String, dynamic> toYaml() => {
        'max_turns': maxTurns,
        'max_messages_per_agent': maxMessagesPerAgent,
        'max_decisions_per_channel': maxDecisionsPerChannel,
        'require_over_marker': requireOverMarker,
        'stop_on_consensus': stopOnConsensus,
        'stop_on_blocked': stopOnBlocked,
        'stop_on_missing_context': stopOnMissingContext,
      };

  /// Returns a copy with selected fields replaced.
  LimitsConfig copyWith({
    int? maxTurns,
    int? maxMessagesPerAgent,
    int? maxDecisionsPerChannel,
    bool? requireOverMarker,
    bool? stopOnConsensus,
    bool? stopOnBlocked,
    bool? stopOnMissingContext,
  }) {
    return LimitsConfig(
      maxTurns: maxTurns ?? this.maxTurns,
      maxMessagesPerAgent: maxMessagesPerAgent ?? this.maxMessagesPerAgent,
      maxDecisionsPerChannel: maxDecisionsPerChannel ?? this.maxDecisionsPerChannel,
      requireOverMarker: requireOverMarker ?? this.requireOverMarker,
      stopOnConsensus: stopOnConsensus ?? this.stopOnConsensus,
      stopOnBlocked: stopOnBlocked ?? this.stopOnBlocked,
      stopOnMissingContext: stopOnMissingContext ?? this.stopOnMissingContext,
    );
  }
}

/// Decision-quality requirements enforced by protocol conventions.
class DecisionsConfig {
  /// Creates a [DecisionsConfig].
  const DecisionsConfig({
    this.requireRationale = true,
    this.requireRisks = true,
    this.requireTests = true,
    this.promoteRequiresHuman = true,
  });

  /// Whether rationale is required for accepted decisions.
  final bool requireRationale;

  /// Whether risks are required for accepted decisions.
  final bool requireRisks;

  /// Whether required tests are mandatory in decision records.
  final bool requireTests;

  /// Whether promotion requires explicit human approval.
  final bool promoteRequiresHuman;

  /// Builds [DecisionsConfig] from YAML data.
  factory DecisionsConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return DecisionsConfig(
      requireRationale: yaml['require_rationale'] as bool? ?? true,
      requireRisks: yaml['require_risks'] as bool? ?? true,
      requireTests: yaml['require_tests'] as bool? ?? true,
      promoteRequiresHuman: yaml['promote_requires_human'] as bool? ?? true,
    );
  }

  /// Converts this config into YAML-compatible data.
  Map<String, dynamic> toYaml() => {
        'require_rationale': requireRationale,
        'require_risks': requireRisks,
        'require_tests': requireTests,
        'promote_requires_human': promoteRequiresHuman,
      };
}

/// Integration settings for repos that contain an `sdd-ai/` tree.
class SddAiConfig {
  /// Creates an [SddAiConfig].
  const SddAiConfig({
    this.enabled = false,
    this.changeDir = 'sdd-ai/changes',
    this.architectureDir = 'sdd-ai/architecture',
    this.specsDir = 'sdd-ai/specs',
  });

  /// Enables sdd-ai integration features.
  final bool enabled;

  /// Base directory where change folders are created.
  final String changeDir;

  /// Directory for promoted architecture artifacts.
  final String architectureDir;

  /// Directory for promoted specification artifacts.
  final String specsDir;

  /// Builds [SddAiConfig] from YAML data.
  factory SddAiConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return SddAiConfig(
      enabled: yaml['enabled'] as bool? ?? false,
      changeDir: yaml['change_dir'] as String? ?? 'sdd-ai/changes',
      architectureDir: yaml['architecture_dir'] as String? ?? 'sdd-ai/architecture',
      specsDir: yaml['specs_dir'] as String? ?? 'sdd-ai/specs',
    );
  }

  /// Converts this config into YAML-compatible data.
  Map<String, dynamic> toYaml() => {
        'enabled': enabled,
        'change_dir': changeDir,
        'architecture_dir': architectureDir,
        'specs_dir': specsDir,
      };
}
