import 'agent_config.dart';

class WalkiConfig {
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

  final int version;
  final ProjectConfig project;
  final StorageConfig storage;
  final Map<String, AgentConfig> agents;
  final InstructionConfig instructions;
  final LimitsConfig limits;
  final DecisionsConfig decisions;
  final SddAiConfig sddAi;

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

class ProjectConfig {
  const ProjectConfig({this.name = ''});

  final String name;

  factory ProjectConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return ProjectConfig(name: yaml['name'] as String? ?? '');
  }

  Map<String, dynamic> toYaml() => {'name': name};
}

class StorageConfig {
  const StorageConfig({
    this.primaryFormat = 'markdown',
    this.channelDir = '.walki/channels',
    this.decisionDir = '.walki/decisions',
    this.taskDir = '.walki/tasks',
    this.generatedStateDir = '.walki/state',
  });

  final String primaryFormat;
  final String channelDir;
  final String decisionDir;
  final String taskDir;
  final String generatedStateDir;

  factory StorageConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return StorageConfig(
      primaryFormat: yaml['primary_format'] as String? ?? 'markdown',
      channelDir: yaml['channel_dir'] as String? ?? '.walki/channels',
      decisionDir: yaml['decision_dir'] as String? ?? '.walki/decisions',
      taskDir: yaml['task_dir'] as String? ?? '.walki/tasks',
      generatedStateDir: yaml['generated_state_dir'] as String? ?? '.walki/state',
    );
  }

  Map<String, dynamic> toYaml() => {
        'primary_format': primaryFormat,
        'channel_dir': channelDir,
        'decision_dir': decisionDir,
        'task_dir': taskDir,
        'generated_state_dir': generatedStateDir,
      };
}

class InstructionConfig {
  const InstructionConfig({this.load = const []});

  final List<String> load;

  factory InstructionConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return InstructionConfig(
      load: (yaml['load'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  Map<String, dynamic> toYaml() => {'load': load};
}

class LimitsConfig {
  const LimitsConfig({
    this.maxTurns = 8,
    this.maxMessagesPerAgent = 4,
    this.maxDecisionsPerChannel = 5,
    this.requireOverMarker = true,
    this.stopOnConsensus = true,
    this.stopOnBlocked = true,
    this.stopOnMissingContext = true,
  });

  final int maxTurns;
  final int maxMessagesPerAgent;
  final int maxDecisionsPerChannel;
  final bool requireOverMarker;
  final bool stopOnConsensus;
  final bool stopOnBlocked;
  final bool stopOnMissingContext;

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

  Map<String, dynamic> toYaml() => {
        'max_turns': maxTurns,
        'max_messages_per_agent': maxMessagesPerAgent,
        'max_decisions_per_channel': maxDecisionsPerChannel,
        'require_over_marker': requireOverMarker,
        'stop_on_consensus': stopOnConsensus,
        'stop_on_blocked': stopOnBlocked,
        'stop_on_missing_context': stopOnMissingContext,
      };

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

class DecisionsConfig {
  const DecisionsConfig({
    this.requireRationale = true,
    this.requireRisks = true,
    this.requireTests = true,
    this.promoteRequiresHuman = true,
  });

  final bool requireRationale;
  final bool requireRisks;
  final bool requireTests;
  final bool promoteRequiresHuman;

  factory DecisionsConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return DecisionsConfig(
      requireRationale: yaml['require_rationale'] as bool? ?? true,
      requireRisks: yaml['require_risks'] as bool? ?? true,
      requireTests: yaml['require_tests'] as bool? ?? true,
      promoteRequiresHuman: yaml['promote_requires_human'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toYaml() => {
        'require_rationale': requireRationale,
        'require_risks': requireRisks,
        'require_tests': requireTests,
        'promote_requires_human': promoteRequiresHuman,
      };
}

class SddAiConfig {
  const SddAiConfig({
    this.enabled = false,
    this.changeDir = 'sdd-ai/changes',
    this.architectureDir = 'sdd-ai/architecture',
    this.specsDir = 'sdd-ai/specs',
  });

  final bool enabled;
  final String changeDir;
  final String architectureDir;
  final String specsDir;

  factory SddAiConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return SddAiConfig(
      enabled: yaml['enabled'] as bool? ?? false,
      changeDir: yaml['change_dir'] as String? ?? 'sdd-ai/changes',
      architectureDir: yaml['architecture_dir'] as String? ?? 'sdd-ai/architecture',
      specsDir: yaml['specs_dir'] as String? ?? 'sdd-ai/specs',
    );
  }

  Map<String, dynamic> toYaml() => {
        'enabled': enabled,
        'change_dir': changeDir,
        'architecture_dir': architectureDir,
        'specs_dir': specsDir,
      };
}