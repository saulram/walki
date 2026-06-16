import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:walki/walki.dart';

void main() {
  late String tempDir;

  setUp(() async {
    tempDir =
        (await Directory.systemTemp.createTemp('walki_loader_test_')).path;
  });

  tearDown(() async {
    await Directory(tempDir).delete(recursive: true);
  });

  group('InstructionLoader', () {
    test('loads project instructions', () {
      final walkiDir = Directory(p.join(tempDir, '.walki'));
      walkiDir.createSync(recursive: true);
      File(p.join(tempDir, '.walki', 'instructions.md'))
          .writeAsStringSync('# Project Instructions\n\nBe concise.');

      final loader = const InstructionLoader();
      final instructions = loader.load(projectDir: tempDir);

      expect(
        instructions.any((i) => i.source == InstructionSource.project),
        isTrue,
      );
      expect(
        instructions
            .firstWhere((i) => i.source == InstructionSource.project)
            .content,
        contains('Be concise'),
      );
    });

    test('loads rule files', () {
      final rulesDir = Directory(p.join(tempDir, '.walki', 'rules'));
      rulesDir.createSync(recursive: true);
      File(p.join(tempDir, '.walki', 'rules', 'security.md'))
          .writeAsStringSync('# Security Rules\n\nNo plain text passwords.');

      final loader = const InstructionLoader();
      final instructions = loader.load(projectDir: tempDir);

      expect(
        instructions.any((i) => i.source == InstructionSource.domain),
        isTrue,
      );
      expect(
        instructions.any((i) => i.content.contains('No plain text passwords')),
        isTrue,
      );
    });

    test('loads config paths', () {
      Directory(p.join(tempDir, '.walki')).createSync(recursive: true);
      File(p.join(tempDir, '.walki', 'instructions.md'))
          .writeAsStringSync('Project');
      File(p.join(tempDir, 'custom-rules.md'))
          .writeAsStringSync('# Custom rules\n\nNo globals.');

      final loader = const InstructionLoader();
      final instructions = loader.load(
        projectDir: tempDir,
        configPaths: ['custom-rules.md'],
      );

      expect(
        instructions.any((i) => i.source == InstructionSource.config),
        isTrue,
      );
    });

    test('deduplicates paths', () {
      Directory(p.join(tempDir, '.walki')).createSync(recursive: true);
      File(p.join(tempDir, '.walki', 'instructions.md'))
          .writeAsStringSync('Project');

      final loader = const InstructionLoader();
      final instructions = loader.load(
        projectDir: tempDir,
        configPaths: ['.walki/instructions.md'],
      );

      final projectCount =
          instructions.where((i) => i.path.contains('instructions.md')).length;
      expect(projectCount, equals(1));
    });

    test('skips missing files silently', () {
      Directory(p.join(tempDir, '.walki')).createSync(recursive: true);

      final loader = const InstructionLoader();
      final instructions = loader.load(
        projectDir: tempDir,
        configPaths: ['nonexistent.md'],
      );

      expect(instructions.any((i) => i.path.contains('nonexistent')), isFalse);
    });

    test('skips empty files', () {
      Directory(p.join(tempDir, '.walki')).createSync(recursive: true);
      File(p.join(tempDir, '.walki', 'instructions.md'))
          .writeAsStringSync('   \n  \n');

      final loader = const InstructionLoader();
      final instructions = loader.load(projectDir: tempDir);

      expect(
        instructions.where((i) => i.source == InstructionSource.project),
        isEmpty,
      );
    });

    test('loads AGENTS.md if exists', () {
      Directory(p.join(tempDir, '.walki')).createSync(recursive: true);
      File(p.join(tempDir, 'AGENTS.md'))
          .writeAsStringSync('# Agent instructions');

      final loader = const InstructionLoader();
      final instructions = loader.load(projectDir: tempDir);

      expect(instructions.any((i) => i.path.endsWith('AGENTS.md')), isTrue);
    });

    test('loads CLAUDE.md if exists', () {
      Directory(p.join(tempDir, '.walki')).createSync(recursive: true);
      File(p.join(tempDir, '.walki', 'instructions.md'))
          .writeAsStringSync('Project');
      File(p.join(tempDir, 'CLAUDE.md'))
          .writeAsStringSync('# Claude instructions');

      final loader = const InstructionLoader();
      final instructions = loader.load(projectDir: tempDir);

      expect(instructions.any((i) => i.path.endsWith('CLAUDE.md')), isTrue);
    });

    test('generates agent instructions', () {
      Directory(p.join(tempDir, '.walki', 'rules')).createSync(recursive: true);
      File(p.join(tempDir, '.walki', 'instructions.md'))
          .writeAsStringSync('Be concise.');
      File(p.join(tempDir, '.walki', 'rules', 'security.md'))
          .writeAsStringSync('No plain text passwords.');
      File(p.join(tempDir, '.walki', 'rules', 'code-style.md'))
          .writeAsStringSync('Prefer small modules.');

      final loader = const InstructionLoader();
      final instructions = loader.load(projectDir: tempDir);
      final generated = loader.generateAgentInstructions(instructions);

      expect(generated, contains('Be concise'));
    });

    test('toMarkdownListItem returns correct format', () {
      const instruction = LoadedInstruction(
        path: '.walki/rules/security.md',
        source: InstructionSource.domain,
        content: 'Security rules',
      );
      expect(
        instruction.toMarkdownListItem(),
        equals('- .walki/rules/security.md (Domain rules)'),
      );
    });

    test('InstructionSource labels', () {
      expect(InstructionSource.protocol.label, equals('Protocol defaults'));
      expect(
        InstructionSource.global.label,
        equals('Global user instructions'),
      );
      expect(InstructionSource.project.label, equals('Project instructions'));
      expect(InstructionSource.domain.label, equals('Domain rules'));
      expect(InstructionSource.config.label, equals('Config instructions'));
      expect(InstructionSource.channel.label, equals('Channel instructions'));
      expect(InstructionSource.sddAi.label, equals('SDD-AI architecture'));
    });
  });
}
