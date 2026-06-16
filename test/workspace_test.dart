import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:walki/walki.dart';

void main() {
  late String tempDir;

  setUp(() async {
    tempDir = (await Directory.systemTemp.createTemp('walki_test_')).path;
  });

  tearDown(() async {
    await Directory(tempDir).delete(recursive: true);
  });

  group('Workspace', () {
    test('init creates full workspace structure', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex', 'claude']);

      expect(Directory(p.join(tempDir, '.walki')).existsSync(), isTrue);
      expect(
        Directory(p.join(tempDir, '.walki', 'agents')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(tempDir, '.walki', 'rules')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(tempDir, '.walki', 'channels')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(tempDir, '.walki', 'decisions')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(tempDir, '.walki', 'tasks')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(tempDir, '.walki', 'state')).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(tempDir, '.walki', 'locks')).existsSync(),
        isTrue,
      );

      expect(
        File(p.join(tempDir, '.walki', 'config.yaml')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'instructions.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'agents', 'codex.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'agents', 'claude.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'agents', 'human.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'rules', 'security.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'rules', 'code-style.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'state', 'index.yaml')).existsSync(),
        isTrue,
      );
    });

    test('init with custom agent names', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['gemini', 'devon']);

      final config = workspace.loadConfig(tempDir);
      expect(config.agents, contains('gemini'));
      expect(config.agents, contains('devon'));
      expect(config.agents, contains('human'));
      expect(
        File(p.join(tempDir, '.walki', 'agents', 'gemini.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'agents', 'devon.md')).existsSync(),
        isTrue,
      );
    });

    test('init throws if already initialized', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex']);
      expect(
        () => workspace.init(projectDir: tempDir, agentNames: ['codex']),
        throwsStateError,
      );
    });

    test('isInitialized detects workspace', () {
      final workspace = const Workspace();
      expect(workspace.isInitialized(tempDir), isFalse);
      workspace.init(projectDir: tempDir, agentNames: ['codex']);
      expect(workspace.isInitialized(tempDir), isTrue);
    });

    test('loadConfig reads config correctly', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex', 'claude']);

      final config = workspace.loadConfig(tempDir);
      expect(config.agents, contains('codex'));
      expect(config.agents, contains('claude'));
      expect(config.agents, contains('human'));
      expect(config.agents['codex']!.role, equals('implementer'));
      expect(config.agents['claude']!.role, equals('reviewer'));
      expect(config.agents['human']!.role, equals('owner'));
    });

    test('loadConfig throws if not initialized', () {
      final workspace = const Workspace();
      expect(
        () => workspace.loadConfig(tempDir),
        throwsStateError,
      );
    });

    test('saveConfig updates config', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex']);

      var config = workspace.loadConfig(tempDir);
      config = config.copyWith(limits: const LimitsConfig(maxTurns: 20));
      workspace.saveConfig(config, tempDir);

      final reloaded = workspace.loadConfig(tempDir);
      expect(reloaded.limits.maxTurns, equals(20));
    });

    test('hasSddAi detects sdd-ai directory', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex']);
      expect(workspace.hasSddAi(tempDir), isFalse);

      Directory(p.join(tempDir, 'sdd-ai')).createSync();
      expect(workspace.hasSddAi(tempDir), isTrue);
    });

    test('init with sdd-ai flag', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex'], sddAi: true);

      final config = workspace.loadConfig(tempDir);
      expect(config.sddAi.enabled, isTrue);
    });

    test('init with sdd template enables sdd-ai integration', () {
      final workspace = const Workspace();
      workspace
          .init(projectDir: tempDir, template: 'sdd', agentNames: ['codex']);

      final config = workspace.loadConfig(tempDir);
      expect(config.sddAi.enabled, isTrue);
    });

    test('init with custom agent configs writes configured metadata', () {
      final workspace = const Workspace();
      workspace.init(
        projectDir: tempDir,
        agentConfigs: {
          'opencode':
              AgentConfig.implementer(description: 'Repository implementer'),
          'gemini': AgentConfig.reviewer(description: 'Planning reviewer'),
        },
      );

      final config = workspace.loadConfig(tempDir);
      expect(
        config.agents['opencode']!.description,
        equals('Repository implementer'),
      );
      expect(config.agents['gemini']!.role, equals('reviewer'));

      final opencodeFile =
          File(p.join(tempDir, '.walki', 'agents', 'opencode.md'))
              .readAsStringSync();
      expect(opencodeFile, contains('Repository implementer'));
      expect(opencodeFile, contains('## Debate Prompt'));
    });

    test('init with starter rules controls generated rules', () {
      final workspace = const Workspace();
      workspace.init(
        projectDir: tempDir,
        agentNames: ['codex'],
        starterRules: ['testing', 'sdd-ai'],
      );

      expect(
        File(p.join(tempDir, '.walki', 'rules', 'testing.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'rules', 'sdd-ai.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir, '.walki', 'rules', 'security.md')).existsSync(),
        isFalse,
      );
    });

    test('init creates instructions.md with content', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex']);

      final content =
          File(p.join(tempDir, '.walki', 'instructions.md')).readAsStringSync();
      expect(content, contains('simple architecture'));
      expect(content, contains('risks'));
      expect(content, contains('tests'));
    });

    test('init creates security.md rules', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex']);

      final content = File(p.join(tempDir, '.walki', 'rules', 'security.md'))
          .readAsStringSync();
      expect(content, contains('Security Rules'));
      expect(content, contains('abuse cases'));
      expect(content, contains('deny-by-default'));
    });

    test('init creates code-style.md rules', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex']);

      final content = File(p.join(tempDir, '.walki', 'rules', 'code-style.md'))
          .readAsStringSync();
      expect(content, contains('Code Style Rules'));
      expect(content, contains('small modules'));
    });

    test('agent markdown files have correct role', () {
      final workspace = const Workspace();
      workspace.init(projectDir: tempDir, agentNames: ['codex']);

      final codexContent = File(p.join(tempDir, '.walki', 'agents', 'codex.md'))
          .readAsStringSync();
      expect(codexContent, contains('implementer'));

      final humanContent = File(p.join(tempDir, '.walki', 'agents', 'human.md'))
          .readAsStringSync();
      expect(humanContent, contains('owner'));
    });
  });
}
