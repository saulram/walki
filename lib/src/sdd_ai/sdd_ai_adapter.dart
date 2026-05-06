import 'dart:io';
import 'package:path/path.dart' as p;
import '../config/walki_config.dart';

class SddAiAdapter {
  const SddAiAdapter();

  bool isAvailable([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    return Directory(p.join(dir, 'sdd-ai')).existsSync();
  }

  String createChangeFolder(String channelName, [String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final changeDir = p.join(dir, 'sdd-ai', 'changes', '$date-$channelName');

    Directory(changeDir).createSync(recursive: true);

    for (final filename in ['proposal.md', 'decisions.md', 'tasks.md', 'risks.md', 'promotion-plan.md']) {
      final title = filename.replaceAll('.md', '');
      final capitalized = title[0].toUpperCase() + title.substring(1);
      File(p.join(changeDir, filename)).writeAsStringSync('# $capitalized\n\n');
    }

    return changeDir;
  }

  String promoteDecision(
    String channelName,
    WalkiConfig config, [
    String? projectDir,
  ]) {
    final dir = projectDir ?? Directory.current.path;

    if (!isAvailable(dir)) {
      throw StateError('sdd-ai directory not found at ${p.join(dir, 'sdd-ai')}');
    }

    final changeDir = createChangeFolder(channelName, dir);

    final walkiChannel = File(
      p.join(dir, config.storage.channelDir, '$channelName.md'),
    );
    final walkiDecision = File(
      p.join(dir, config.storage.decisionDir, '$channelName.md'),
    );

    if (walkiChannel.existsSync()) {
      File(p.join(changeDir, 'walki.md')).writeAsStringSync(
        walkiChannel.readAsStringSync(),
      );
    }

    if (walkiDecision.existsSync()) {
      File(p.join(changeDir, 'decisions.md')).writeAsStringSync(
        walkiDecision.readAsStringSync(),
      );
    }

    return changeDir;
  }
}