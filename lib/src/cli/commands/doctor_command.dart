import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import '../../channels/channel.dart';
import '../../channels/channel_parser.dart';
import '../../validation/permission_engine.dart';
import '../../storage/workspace.dart';

class DoctorCommand extends Command<int> {
  DoctorCommand({required this.logger});

  final Logger logger;

  @override
  String get name => 'doctor';

  @override
  String get description => 'Validate Walki workspace integrity.';

  @override
  Future<int> run() async {
    final workspace = const Workspace();
    final issues = <String>[];

    if (!workspace.isInitialized()) {
      logger.err(
          'Walki workspace not initialized. Run ${lightCyan.wrap('walki init')} first.');
      return 1;
    }

    logger.info('${cyan.wrap('Checking Walki workspace...')}');
    logger.info('');

    final walkiDir = Directory('.walki');
    if (!walkiDir.existsSync()) {
      issues.add('.walki/ directory not found.');
    }

    final requiredDirs = [
      'agents',
      'rules',
      'channels',
      'decisions',
      'tasks',
      'state',
      'locks'
    ];
    for (final dir in requiredDirs) {
      if (!Directory('.walki/$dir').existsSync()) {
        issues.add('.walki/$dir/ directory missing.');
      }
    }

    final configFile = File('.walki/config.yaml');
    if (!configFile.existsSync()) {
      issues.add('.walki/config.yaml not found.');
    } else {
      try {
        final config = workspace.loadConfig();
        if (config.project.name.isEmpty) {
          issues.add('Project name is empty in config.');
        }
        if (config.agents.isEmpty) {
          issues.add('No agents registered in config.');
        }
      } catch (e) {
        issues.add('Invalid config.yaml: $e');
      }
    }

    final instructionsFile = File('.walki/instructions.md');
    if (!instructionsFile.existsSync()) {
      issues.add('.walki/instructions.md not found.');
    }

    try {
      final config = workspace.loadConfig();

      final channelsDir = Directory(config.storage.channelDir);
      if (channelsDir.existsSync()) {
        final channelFiles = channelsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md'))
            .toList();

        final parser = const ChannelParser();
        final permissionEngine = const PermissionEngine();

        for (final channelFile in channelFiles) {
          try {
            final channel = parser.parse(channelFile.readAsStringSync());

            final healthIssues =
                permissionEngine.validateChannelHealth(channel);
            for (final issue in healthIssues) {
              issues.add('Channel ${channel.id}: $issue');
            }

            if (channel.status == ChannelStatus.open &&
                channel.messages.isEmpty) {
              issues.add('Channel ${channel.id} is open but has no messages.');
            }

            if (channel.turnCount >= channel.maxTurns && channel.isOpen) {
              issues.add(
                  'Channel ${channel.id} has reached max turns but is still open.');
            }
          } catch (e) {
            issues.add('Failed to parse channel ${channelFile.path}: $e');
          }
        }
      }

      for (final agentEntry in config.agents.entries) {
        final agentFile = File('.walki/agents/${agentEntry.key}.md');
        if (!agentFile.existsSync()) {
          issues.add(
              'Agent "${agentEntry.key}" registered in config but .walki/agents/${agentEntry.key}.md not found.');
        }
      }

      if (config.sddAi.enabled && !workspace.hasSddAi()) {
        issues
            .add('sdd-ai integration enabled but sdd-ai/ directory not found.');
      }

      final locksDir = Directory('.walki/locks');
      if (locksDir.existsSync()) {
        final locks =
            locksDir.listSync().where((f) => f.path.endsWith('.lock')).toList();
        for (final lock in locks) {
          final content = File(lock.path).readAsStringSync();
          if (content.contains('expires_at:')) {
            final expiresMatch =
                RegExp(r'expires_at:\s*(.+)').firstMatch(content);
            if (expiresMatch != null) {
              final expires = DateTime.tryParse(expiresMatch[1]?.trim() ?? '');
              if (expires != null && expires.isBefore(DateTime.now())) {
                issues
                    .add('Stale lock: ${lock.path}. Lock expired at $expires.');
              }
            }
          }
        }
      }
    } catch (e) {
      issues.add('Error during workspace check: $e');
    }

    if (issues.isEmpty) {
      logger.info(green.wrap('Walki workspace is healthy. No issues found.'));
      return 0;
    } else {
      logger.info(yellow.wrap('Found ${issues.length} issue(s):'));
      logger.info('');
      for (final issue in issues) {
        logger.info('  ${red.wrap('x')} $issue');
      }
      logger.info('');
      logger.info(
          'Run ${lightCyan.wrap('walki doctor')} again after fixing these issues.');
      return 1;
    }
  }
}
