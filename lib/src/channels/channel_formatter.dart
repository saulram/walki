import 'channel.dart';

class ChannelFormatter {
  const ChannelFormatter();

  String format(Channel channel) {
    final buffer = StringBuffer();

    buffer.writeln('# Walki Channel: ${channel.id}');
    buffer.writeln();
    buffer.writeln('## Metadata');
    buffer.writeln();
    buffer.writeln('- id: ${channel.id}');
    buffer.writeln('- status: ${channel.status.toYamlValue()}');
    buffer.writeln('- created_at: ${channel.createdAt.toUtc().toIso8601String()}');
    buffer.writeln('- participants: ${channel.participants.join(', ')}');
    buffer.writeln('- max_turns: ${channel.maxTurns}');
    buffer.writeln();

    if (channel.prompt.isNotEmpty) {
      buffer.writeln('## User Prompt');
      buffer.writeln();
      buffer.writeln(channel.prompt);
      buffer.writeln();
    }

    if (channel.loadedInstructions.isNotEmpty) {
      buffer.writeln('## Loaded Instructions');
      buffer.writeln();
      for (final instruction in channel.loadedInstructions) {
        buffer.writeln('- $instruction');
      }
      buffer.writeln();
    }

    if (channel.workingRules.isNotEmpty) {
      buffer.writeln('## Working Rules');
      buffer.writeln();
      for (final rule in channel.workingRules) {
        buffer.writeln('- $rule');
      }
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln();

    for (final message in channel.messages) {
      buffer.writeln(
        '## ${message.timestamp.toUtc().toIso8601String()} - ${message.agent} - ${message.kind.name}',
      );
      buffer.writeln();
      buffer.writeln(message.content);
      buffer.writeln();
      if (message.endsWithOver) {
        buffer.writeln('OVER');
        buffer.writeln();
      }
      buffer.writeln('---');
      buffer.writeln();
    }

    for (final decision in channel.decisions) {
      buffer.writeln('## Decision: ${decision.status}');
      buffer.writeln();
      buffer.writeln(decision.summary);
      buffer.writeln();
      if (decision.rationale.isNotEmpty) {
        buffer.writeln('Rationale:');
        buffer.writeln();
        buffer.writeln(decision.rationale);
        buffer.writeln();
      }
      if (decision.risks.isNotEmpty) {
        buffer.writeln('Risks:');
        for (final risk in decision.risks) {
          buffer.writeln('- $risk');
        }
        buffer.writeln();
      }
      if (decision.requiredTests.isNotEmpty) {
        buffer.writeln('Required tests:');
        for (final test in decision.requiredTests) {
          buffer.writeln('- $test');
        }
        buffer.writeln();
      }
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString().trimRight() + '\n';
  }

  String formatAppendMessage(ChannelMessage message) {
    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('## ${message.timestamp.toUtc().toIso8601String()} - ${message.agent} - ${message.kind.name}');
    buffer.writeln();
    buffer.writeln(message.content);
    buffer.writeln();
    if (message.endsWithOver) {
      buffer.writeln('OVER');
      buffer.writeln();
    }
    buffer.writeln('---');
    buffer.writeln();

    return buffer.toString();
  }

  String updateStatus(String content, ChannelStatus newStatus) {
    return content.replaceFirst(
      RegExp(r'- status: \S+'),
      '- status: ${newStatus.toYamlValue()}',
    );
  }

  String formatDecision(ChannelDecision decision) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('## Decision: ${decision.status}');
    buffer.writeln();
    buffer.writeln(decision.summary);
    buffer.writeln();
    if (decision.rationale.isNotEmpty) {
      buffer.writeln('Rationale:');
      buffer.writeln();
      buffer.writeln(decision.rationale);
      buffer.writeln();
    }
    if (decision.risks.isNotEmpty) {
      buffer.writeln('Risks:');
      for (final risk in decision.risks) {
        buffer.writeln('- $risk');
      }
      buffer.writeln();
    }
    if (decision.requiredTests.isNotEmpty) {
      buffer.writeln('Required tests:');
      for (final test in decision.requiredTests) {
        buffer.writeln('- $test');
      }
      buffer.writeln();
    }
    buffer.writeln('---');
    buffer.writeln();

    return buffer.toString();
  }

  String formatStatus(Channel channel) {
    final buffer = StringBuffer();
    buffer.writeln('Channel: ${channel.id}');
    buffer.writeln('Status: ${channel.status.toYamlValue()}');
    buffer.writeln('Turns: ${channel.turnCount}/${channel.maxTurns}');
    buffer.writeln('Participants: ${channel.participants.join(', ')}');

    if (channel.decisions.isNotEmpty) {
      final lastDecision = channel.decisions.last;
      buffer.writeln('Current decision: ${lastDecision.status}');
      buffer.writeln('  ${lastDecision.summary}');
    }

    if (channel.messages.isNotEmpty) {
      final lastMessage = channel.messages.last;
      buffer.writeln('Last message: ${lastMessage.agent} (${lastMessage.kind.name})');
    }

    return buffer.toString();
  }
}