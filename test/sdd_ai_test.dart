import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:walki/walki.dart';

void main() {
  late String tempDir;

  setUp(() async {
    tempDir = (await Directory.systemTemp.createTemp('walki_sdd_test_')).path;
  });

  tearDown(() async {
    await Directory(tempDir).delete(recursive: true);
  });

  group('SddAiAdapter', () {
    test('isAvailable returns false when no sdd-ai directory', () {
      const adapter = SddAiAdapter();
      expect(adapter.isAvailable(tempDir), isFalse);
    });

    test('isAvailable returns true when sdd-ai directory exists', () {
      Directory(p.join(tempDir, 'sdd-ai')).createSync();
      const adapter = SddAiAdapter();
      expect(adapter.isAvailable(tempDir), isTrue);
    });

    test('createChangeFolder creates directory structure', () {
      Directory(p.join(tempDir, 'sdd-ai')).createSync();
      const adapter = SddAiAdapter();

      final changeDir = adapter.createChangeFolder('auth', tempDir);

      expect(Directory(changeDir).existsSync(), isTrue);
      expect(File(p.join(changeDir, 'proposal.md')).existsSync(), isTrue);
      expect(File(p.join(changeDir, 'decisions.md')).existsSync(), isTrue);
      expect(File(p.join(changeDir, 'tasks.md')).existsSync(), isTrue);
      expect(File(p.join(changeDir, 'risks.md')).existsSync(), isTrue);
      expect(File(p.join(changeDir, 'promotion-plan.md')).existsSync(), isTrue);
    });

    test('createChangeFolder names directory with date and channel', () {
      Directory(p.join(tempDir, 'sdd-ai')).createSync();
      const adapter = SddAiAdapter();

      final changeDir = adapter.createChangeFolder('auth', tempDir);

      expect(changeDir, contains('auth'));
      expect(changeDir, contains('2026'));
    });

    test('createChangeFolder creates files with proper headers', () {
      Directory(p.join(tempDir, 'sdd-ai')).createSync();
      const adapter = SddAiAdapter();

      final changeDir = adapter.createChangeFolder('auth', tempDir);

      final proposal = File(p.join(changeDir, 'proposal.md')).readAsStringSync();
      expect(proposal, contains('# Proposal'));
    });

    test('promoteDecision throws when sdd-ai not available', () {
      const adapter = SddAiAdapter();
      const config = WalkiConfig(project: ProjectConfig(name: 'test'));

      expect(
        () => adapter.promoteDecision('auth', config, tempDir),
        throwsStateError,
      );
    });

    test('promoteDecision copies channel and decision files', () {
      Directory(p.join(tempDir, 'sdd-ai')).createSync(recursive: true);
      Directory(p.join(tempDir, '.walki', 'channels')).createSync(recursive: true);
      Directory(p.join(tempDir, '.walki', 'decisions')).createSync(recursive: true);

      File(p.join(tempDir, '.walki', 'channels', 'auth.md')).writeAsStringSync('# Walki Channel: auth\n\nDebate content');
      File(p.join(tempDir, '.walki', 'decisions', 'auth.md')).writeAsStringSync('# Decision: auth\n\nDecision content');

      const adapter = SddAiAdapter();
      const config = WalkiConfig(project: ProjectConfig(name: 'test'));

      final changeDir = adapter.promoteDecision('auth', config, tempDir);

      expect(Directory(changeDir).existsSync(), isTrue);
      final walkiContent = File(p.join(changeDir, 'walki.md')).readAsStringSync();
      expect(walkiContent, contains('Debate content'));

      final decisionsContent = File(p.join(changeDir, 'decisions.md')).readAsStringSync();
      expect(decisionsContent, contains('Decision content'));
    });
  });
}