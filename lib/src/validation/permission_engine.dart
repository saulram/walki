import '../config/agent_config.dart';
import '../channels/channel.dart';

class PermissionEngine {
  const PermissionEngine();

  bool canPerformAction(AgentConfig agent, String action) {
    return agent.can.contains(action);
  }

  List<String> validateMessage(
    AgentConfig agent,
    Channel channel,
    String action,
  ) {
    final violations = <String>[];

    if (!canPerformAction(agent, action)) {
      violations.add(
        'Agent "${agent.role}" cannot perform action "$action"',
      );
    }

    if (channel.isClosed) {
      violations.add(
        'Channel "${channel.id}" is closed. No new messages allowed.',
      );
    }

    final agentMessageCount =
        channel.messages.where((m) => m.agent == agent.role).length;
    if (agentMessageCount >= 4) {
      violations.add(
        'Agent "${agent.role}" has reached the maximum message count in this channel.',
      );
    }

    if (channel.turnCount >= channel.maxTurns) {
      violations.add(
        'Channel "${channel.id}" has reached the maximum turn count (${channel.maxTurns}).',
      );
    }

    return violations;
  }

  List<String> validateChannelHealth(Channel channel) {
    final issues = <String>[];

    final messagesWithoutOver = channel.messages
        .where((m) => !m.endsWithOver)
        .toList();
    if (messagesWithoutOver.isNotEmpty) {
      for (final msg in messagesWithoutOver) {
        issues.add(
          'Message from "${msg.agent}" at ${msg.timestamp.toIso8601String()} is missing OVER marker.',
        );
      }
    }

    final unknownAgents = channel.messages
        .map((m) => m.agent)
        .where((a) => !channel.participants.contains(a))
        .toSet();
    if (unknownAgents.isNotEmpty) {
      for (final agent in unknownAgents) {
        issues.add('Unknown agent "$agent" posted messages in this channel.');
      }
    }

    final timestamps = channel.messages.map((m) => m.timestamp).toList();
    for (var i = 1; i < timestamps.length; i++) {
      if (timestamps[i].isBefore(timestamps[i - 1])) {
        issues.add(
          'Non-monotonically increasing timestamp at message ${i + 1}.',
        );
      }
    }

    for (final decision in channel.decisions) {
      if (decision.status == 'accepted' && channel.participants.length > 1) {
        final decisionMessages = channel.messages
            .where((m) => m.kind == MessageKind.decision)
            .toList();
        if (decisionMessages.length < channel.participants.length - 1) {
          issues.add(
            'Decision "${decision.summary.substring(0, decision.summary.length.clamp(0, 50))}" '
            'may not have enough acknowledgment from all participants.',
          );
        }
      }
    }

    return issues;
  }
}