import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:walki/src/cli/commands/init_command.dart';
import 'package:walki/src/cli/commands/agent_command.dart';
import 'package:walki/src/cli/commands/debate_command.dart';
import 'package:walki/src/cli/commands/say_command.dart';
import 'package:walki/src/cli/commands/read_command.dart';
import 'package:walki/src/cli/commands/status_command.dart';
import 'package:walki/src/cli/commands/summarize_command.dart';
import 'package:walki/src/cli/commands/close_command.dart';
import 'package:walki/src/cli/commands/promote_command.dart';
import 'package:walki/src/cli/commands/propose_decision_command.dart';
import 'package:walki/src/cli/commands/doctor_command.dart';
import 'package:walki/src/cli/commands/rules_command.dart';
import 'package:walki/src/cli/commands/export_command.dart';
import 'package:walki/src/cli/commands/mcp_command.dart';

void main(List<String> args) {
  final logger = Logger();
  final runner = CommandRunner<int>(
    'walki',
    'Local coordination protocol for AI agents.',
  )
    ..addCommand(InitCommand(logger: logger))
    ..addCommand(AgentCommand(logger: logger))
    ..addCommand(DebateCommand(logger: logger))
    ..addCommand(SayCommand(logger: logger))
    ..addCommand(ReadCommand(logger: logger))
    ..addCommand(StatusCommand(logger: logger))
    ..addCommand(SummarizeCommand(logger: logger))
    ..addCommand(CloseCommand(logger: logger))
    ..addCommand(PromoteCommand(logger: logger))
    ..addCommand(ProposeDecisionCommand(logger: logger))
    ..addCommand(DoctorCommand(logger: logger))
    ..addCommand(RulesCommand(logger: logger))
    ..addCommand(ExportCommand(logger: logger))
    ..addCommand(McpCommand(logger: logger));

  runner.run(args).catchError((Object error) {
    if (error is UsageException) {
      logger.err(error.message);
      logger.info(runner.usage);
      return 1;
    }
    logger.err(error.toString());
    return 1;
  });
}
