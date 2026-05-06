import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'dart:io';

class RulesCommand extends Command<int> {
  RulesCommand({required this.logger}) {
    addSubcommand(RulesAddSubcommand(logger: logger));
    addSubcommand(RulesListSubcommand(logger: logger));
  }

  final Logger logger;

  @override
  String get name => 'rules';

  @override
  String get description => 'Manage project rules.';

  @override
  Future<int> run() async {
    logger.err('Please specify a subcommand: add, list');
    printUsage();
    return 1;
  }
}

class RulesAddSubcommand extends Command<int> {
  RulesAddSubcommand({required this.logger}) {
    argParser.addOption(
      'description',
      abbr: 'd',
      help: 'Rule description',
      defaultsTo: '',
    );
  }

  final Logger logger;

  @override
  String get name => 'add';

  @override
  String get description => 'Add a new rule file.';

  @override
  Future<int> run() async {
    final name = argResults?.rest.firstOrNull;
    if (name == null) {
      logger.err('Usage: walki rules add <name>');
      return 1;
    }

    final description = argResults?['description'] as String? ?? '';
    final rulesDir = Directory('.walki/rules');
    final ruleFile = File('.walki/rules/$name.md');

    if (ruleFile.existsSync()) {
      logger.err('Rule "$name" already exists.');
      return 1;
    }

    rulesDir.createSync(recursive: true);
    ruleFile.writeAsStringSync('# ${name.split('-').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')} Rules\n\n${description.isNotEmpty ? '$description\n\n' : ''}');

    logger.info(green.wrap('Created rule: ${ruleFile.path}'));
    logger.info('Edit this file to add your project rules.');

    return 0;
  }
}

class RulesListSubcommand extends Command<int> {
  RulesListSubcommand({required this.logger});

  final Logger logger;

  @override
  String get name => 'list';

  @override
  String get description => 'List project rules.';

  @override
  Future<int> run() async {
    final rulesDir = Directory('.walki/rules');
    if (!rulesDir.existsSync()) {
      logger.info('No rules found.');
      return 0;
    }

    final ruleFiles = rulesDir.listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList();
    if (ruleFiles.isEmpty) {
      logger.info('No rules found.');
      return 0;
    }

    logger.info('Rules:');
    for (final file in ruleFiles) {
      final name = file.path.split('/').last.replaceAll('.md', '');
      logger.info('  - $name (${file.path})');
    }

    return 0;
  }
}