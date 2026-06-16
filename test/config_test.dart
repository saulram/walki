import 'package:test/test.dart';
import 'package:walki/walki.dart';

void main() {
  group('WalkiConfig', () {
    test('fromYaml creates config with all defaults', () {
      final yaml = <dynamic, dynamic>{
        'version': 1,
        'project': {'name': 'test'},
      };
      final config = WalkiConfig.fromYaml(yaml);
      expect(config.version, equals(1));
      expect(config.project.name, equals('test'));
      expect(config.storage.primaryFormat, equals('markdown'));
      expect(config.storage.channelDir, equals('.walki/channels'));
      expect(config.storage.decisionDir, equals('.walki/decisions'));
      expect(config.storage.taskDir, equals('.walki/tasks'));
      expect(config.storage.generatedStateDir, equals('.walki/state'));
      expect(config.agents, isEmpty);
      expect(config.instructions.load, isEmpty);
      expect(config.limits.maxTurns, equals(8));
      expect(config.limits.maxMessagesPerAgent, equals(4));
      expect(config.limits.maxDecisionsPerChannel, equals(5));
      expect(config.limits.requireOverMarker, isTrue);
      expect(config.limits.stopOnConsensus, isTrue);
      expect(config.limits.stopOnBlocked, isTrue);
      expect(config.limits.stopOnMissingContext, isTrue);
      expect(config.decisions.requireRationale, isTrue);
      expect(config.decisions.requireRisks, isTrue);
      expect(config.decisions.requireTests, isTrue);
      expect(config.decisions.promoteRequiresHuman, isTrue);
      expect(config.sddAi.enabled, isFalse);
      expect(config.sddAi.changeDir, equals('sdd-ai/changes'));
      expect(config.sddAi.architectureDir, equals('sdd-ai/architecture'));
      expect(config.sddAi.specsDir, equals('sdd-ai/specs'));
    });

    test('fromYaml with full config', () {
      final yaml = <dynamic, dynamic>{
        'version': 2,
        'project': {'name': 'my-project'},
        'storage': {
          'primary_format': 'markdown',
          'channel_dir': '.walki/channels',
          'decision_dir': '.walki/decisions',
          'task_dir': '.walki/tasks',
          'generated_state_dir': '.walki/state',
        },
        'agents': <dynamic, dynamic>{
          'codex': <dynamic, dynamic>{
            'role': 'implementer',
            'description': 'Implementation agent',
            'can': ['read', 'append', 'propose_decision'],
          },
          'claude': <dynamic, dynamic>{
            'role': 'reviewer',
            'can': ['read', 'append', 'challenge_decision'],
          },
        },
        'instructions': <dynamic, dynamic>{
          'load': ['.walki/rules/security.md'],
        },
        'limits': <dynamic, dynamic>{
          'max_turns': 12,
          'max_messages_per_agent': 5,
          'max_decisions_per_channel': 3,
          'require_over_marker': false,
          'stop_on_consensus': false,
          'stop_on_blocked': false,
          'stop_on_missing_context': false,
        },
        'decisions': <dynamic, dynamic>{
          'require_rationale': false,
          'require_risks': false,
          'require_tests': false,
          'promote_requires_human': false,
        },
        'sdd_ai': <dynamic, dynamic>{
          'enabled': true,
          'change_dir': 'sdd-ai/changes',
          'architecture_dir': 'sdd-ai/arch',
          'specs_dir': 'sdd-ai/specs',
        },
      };
      final config = WalkiConfig.fromYaml(yaml);
      expect(config.version, equals(2));
      expect(config.project.name, equals('my-project'));
      expect(config.agents, contains('codex'));
      expect(config.agents['codex']!.role, equals('implementer'));
      expect(
        config.agents['codex']!.description,
        equals('Implementation agent'),
      );
      expect(config.agents['codex']!.can, contains('propose_decision'));
      expect(config.agents, contains('claude'));
      expect(config.agents['claude']!.role, equals('reviewer'));
      expect(config.agents['claude']!.can, contains('challenge_decision'));
      expect(config.instructions.load, equals(['.walki/rules/security.md']));
      expect(config.limits.maxTurns, equals(12));
      expect(config.limits.maxMessagesPerAgent, equals(5));
      expect(config.limits.maxDecisionsPerChannel, equals(3));
      expect(config.limits.requireOverMarker, isFalse);
      expect(config.limits.stopOnConsensus, isFalse);
      expect(config.decisions.requireRationale, isFalse);
      expect(config.sddAi.enabled, isTrue);
      expect(config.sddAi.architectureDir, equals('sdd-ai/arch'));
    });

    test('fromYaml with empty map uses defaults', () {
      final config = WalkiConfig.fromYaml({});
      expect(config.version, equals(1));
      expect(config.project.name, equals(''));
      expect(config.agents, isEmpty);
      expect(config.limits.maxTurns, equals(8));
    });

    test('toYaml round-trip preserves values', () {
      const config = WalkiConfig(
        project: ProjectConfig(name: 'round-trip'),
        limits: LimitsConfig(maxTurns: 10),
        sddAi: SddAiConfig(enabled: true),
      );
      final yaml = config.toYaml();
      final restored = WalkiConfig.fromYaml(yaml);
      expect(restored.project.name, equals('round-trip'));
      expect(restored.limits.maxTurns, equals(10));
      expect(restored.sddAi.enabled, isTrue);
    });

    test('copyWith preserves unchanged values', () {
      const config = WalkiConfig(project: ProjectConfig(name: 'test'));
      final updated = config.copyWith(
        limits: const LimitsConfig(maxTurns: 20),
      );
      expect(updated.project.name, equals('test'));
      expect(updated.limits.maxTurns, equals(20));
      expect(updated.limits.requireOverMarker, isTrue);
    });
  });

  group('StorageConfig', () {
    test('fromYaml with defaults', () {
      final config = StorageConfig.fromYaml({});
      expect(config.primaryFormat, equals('markdown'));
      expect(config.channelDir, equals('.walki/channels'));
    });

    test('fromYaml with custom values', () {
      final config = StorageConfig.fromYaml({
        'primary_format': 'json',
        'channel_dir': '/custom/channels',
      });
      expect(config.primaryFormat, equals('json'));
      expect(config.channelDir, equals('/custom/channels'));
    });

    test('toYaml', () {
      const config = StorageConfig(primaryFormat: 'markdown');
      final yaml = config.toYaml();
      expect(yaml['primary_format'], equals('markdown'));
    });
  });

  group('LimitsConfig', () {
    test('copyWith', () {
      const config = LimitsConfig();
      final updated = config.copyWith(maxTurns: 20, stopOnConsensus: false);
      expect(updated.maxTurns, equals(20));
      expect(updated.stopOnConsensus, isFalse);
      expect(updated.maxMessagesPerAgent, equals(4));
    });
  });

  group('ProjectConfig', () {
    test('fromYaml with name', () {
      final config = ProjectConfig.fromYaml({'name': 'my-app'});
      expect(config.name, equals('my-app'));
    });

    test('fromYaml empty uses default', () {
      final config = ProjectConfig.fromYaml({});
      expect(config.name, equals(''));
    });

    test('toYaml', () {
      const config = ProjectConfig(name: 'hello');
      expect(config.toYaml(), equals({'name': 'hello'}));
    });
  });

  group('InstructionConfig', () {
    test('fromYaml with load list', () {
      final config = InstructionConfig.fromYaml({
        'load': ['.walki/rules/security.md', '.walki/rules/testing.md'],
      });
      expect(config.load.length, equals(2));
      expect(config.load.first, equals('.walki/rules/security.md'));
    });

    test('fromYaml empty', () {
      final config = InstructionConfig.fromYaml({});
      expect(config.load, isEmpty);
    });

    test('toYaml', () {
      const config = InstructionConfig(load: ['a.md', 'b.md']);
      final yaml = config.toYaml();
      expect(yaml['load'], equals(['a.md', 'b.md']));
    });
  });

  group('DecisionsConfig', () {
    test('fromYaml defaults', () {
      final config = DecisionsConfig.fromYaml({});
      expect(config.requireRationale, isTrue);
      expect(config.requireRisks, isTrue);
      expect(config.requireTests, isTrue);
      expect(config.promoteRequiresHuman, isTrue);
    });

    test('toYaml', () {
      const config = DecisionsConfig();
      final yaml = config.toYaml();
      expect(yaml['require_rationale'], isTrue);
    });
  });

  group('SddAiConfig', () {
    test('fromYaml defaults', () {
      final config = SddAiConfig.fromYaml({});
      expect(config.enabled, isFalse);
      expect(config.changeDir, equals('sdd-ai/changes'));
    });

    test('toYaml', () {
      const config = SddAiConfig(enabled: true);
      final yaml = config.toYaml();
      expect(yaml['enabled'], isTrue);
    });
  });

  group('AgentConfig', () {
    test('fromYaml creates implementer', () {
      final config = AgentConfig.fromYaml({
        'role': 'implementer',
        'description': 'Test agent',
        'can': ['read', 'append'],
      });
      expect(config.role, equals('implementer'));
      expect(config.description, equals('Test agent'));
      expect(config.can, contains('read'));
    });

    test('fromYaml with defaults', () {
      final config = AgentConfig.fromYaml({});
      expect(config.role, equals('implementer'));
      expect(config.description, equals(''));
      expect(config.can, isEmpty);
    });

    test('toYaml', () {
      final config = AgentConfig.implementer(description: 'Test');
      final yaml = config.toYaml();
      expect(yaml['role'], equals('implementer'));
      expect(yaml['description'], equals('Test'));
      expect(yaml['can'], isA<List<String>>());
    });

    test('factory constructors create proper roles', () {
      final impl = AgentConfig.implementer();
      expect(impl.role, equals('implementer'));
      expect(impl.can, contains('propose_decision'));

      final reviewer = AgentConfig.reviewer();
      expect(reviewer.role, equals('reviewer'));
      expect(reviewer.can, contains('challenge_decision'));

      final owner = AgentConfig.owner();
      expect(owner.role, equals('owner'));
      expect(owner.can, contains('accept_decision'));
    });

    test('implementer with description', () {
      final impl = AgentConfig.implementer(description: 'Code writer');
      expect(impl.description, equals('Code writer'));
    });

    test('reviewer with description', () {
      final rev = AgentConfig.reviewer(description: 'Architecture reviewer');
      expect(rev.description, equals('Architecture reviewer'));
    });
  });
}
