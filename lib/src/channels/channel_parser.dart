import 'channel.dart';

/// Parses Walki channel markdown into structured models.
class ChannelParser {
  /// Creates a [ChannelParser].
  const ChannelParser();

  /// Parses full channel markdown content into a [Channel].
  Channel parse(String markdown) {
    final lines = markdown.split('\n');
    var id = '';
    var status = ChannelStatus.open;
    var createdAt = DateTime.now();
    var participants = <String>[];
    var prompt = '';
    var loadedInstructions = <String>[];
    var workingRules = <String>[];
    var maxTurns = 8;
    final messages = <ChannelMessage>[];
    final decisions = <ChannelDecision>[];

    var section = '';
    var metadataBlock = false;
    var inDecision = false;
    var decisionStatus = '';
    var decisionSummary = StringBuffer();
    var decisionRationale = StringBuffer();
    var decisionRisks = <String>[];
    var decisionTests = <String>[];
    var inRationale = false;
    var inRisks = false;
    var inTests = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('# Walki Channel:')) {
        id = line.replaceFirst('# Walki Channel:', '').trim();
        continue;
      }

      if (line == '## Metadata') {
        metadataBlock = true;
        continue;
      }

      if (line.startsWith('## ') && line != '## Metadata') {
        if (metadataBlock) metadataBlock = false;

        if (line.startsWith('## Decision:')) {
          inDecision = true;
          decisionStatus = line.replaceFirst('## Decision:', '').trim();
          continue;
        }

        inDecision = false;
        inRationale = false;
        inRisks = false;
        inTests = false;

        final messageMatch = RegExp(
          r'^##\s+(\d{4}-\d{2}-\d{2}T[^\s]+)\s+-\s+(\S+)\s+-\s+(\S+)',
        ).firstMatch(line);

        if (messageMatch != null) {
          section = 'message';
          final timestamp = DateTime.parse(messageMatch[1]!);
          final agent = messageMatch[2]!;
          final kind = MessageKind.fromString(messageMatch[3]!);
          var content = StringBuffer();
          var endsWithOver = false;

          final timestampHeaderRegex = RegExp(r'^##\s+\d{4}-\d{2}-\d{2}T');
          for (var j = i + 1; j < lines.length; j++) {
            final msgLine = lines[j].trim();
            if (msgLine.startsWith('---') ||
                timestampHeaderRegex.hasMatch(msgLine) ||
                msgLine.startsWith('## Decision:') ||
                msgLine == '## Metadata' ||
                msgLine == '## User Prompt' ||
                msgLine == '## Working Rules' ||
                msgLine == '## Loaded Instructions') {
              i = j - 1;
              break;
            }
            if (msgLine == 'OVER') {
              endsWithOver = true;
              continue;
            }
            content.writeln(lines[j]);
          }

          messages.add(
            ChannelMessage(
              agent: agent,
              kind: kind,
              content: content.toString().trimRight(),
              timestamp: timestamp,
              endsWithOver: endsWithOver,
            ),
          );
          continue;
        }

        if (line == '## User Prompt') {
          section = 'prompt';
          continue;
        }
        if (line == '## Loaded Instructions') {
          section = 'instructions';
          continue;
        }
        if (line == '## Working Rules') {
          section = 'rules';
          continue;
        }
        continue;
      }

      if (metadataBlock && line.startsWith('- ')) {
        final keyValue = line.substring(2);
        final colonIndex = keyValue.indexOf(':');
        if (colonIndex > 0) {
          final key = keyValue.substring(0, colonIndex).trim();
          final value = keyValue.substring(colonIndex + 1).trim();
          switch (key) {
            case 'id':
              if (id.isEmpty) id = value;
            case 'status':
              status = ChannelStatus.fromString(value);
            case 'created_at':
              createdAt = DateTime.parse(value);
            case 'participants':
              participants = value.split(',').map((s) => s.trim()).toList();
            case 'max_turns':
              maxTurns = int.tryParse(value) ?? 8;
          }
        }
        continue;
      }

      if (inDecision) {
        if (line.startsWith('Rationale:') || line.startsWith('Rationale')) {
          inRationale = true;
          inRisks = false;
          inTests = false;
          final rest = line.replaceFirst(RegExp(r'^Rationale:?\s*'), '');
          if (rest.isNotEmpty) decisionRationale.writeln(rest);
          continue;
        }
        if (line.startsWith('Risks:') || line.startsWith('Risks')) {
          inRationale = false;
          inRisks = true;
          inTests = false;
          continue;
        }
        if (line.startsWith('Required tests:') ||
            line.startsWith('Required tests')) {
          inRationale = false;
          inRisks = false;
          inTests = true;
          continue;
        }
        if (line.startsWith('- ')) {
          final item = line.substring(2);
          if (inRisks) {
            decisionRisks.add(item);
          } else if (inTests) {
            decisionTests.add(item);
          } else if (inRationale) {
            decisionRationale.writeln(item);
          }
          continue;
        }
        if (line.isEmpty) continue;
        if (line.startsWith('---')) {
          decisions.add(
            ChannelDecision(
              status: decisionStatus,
              summary: decisionSummary.toString().trimRight(),
              rationale: decisionRationale.toString().trimRight(),
              risks: decisionRisks,
              requiredTests: decisionTests,
            ),
          );
          inDecision = false;
          decisionStatus = '';
          decisionSummary = StringBuffer();
          decisionRationale = StringBuffer();
          decisionRisks = [];
          decisionTests = [];
          continue;
        }
        decisionSummary.writeln(line);
        continue;
      }

      if (section == 'prompt') {
        if (line.isNotEmpty &&
            !line.startsWith('##') &&
            !line.startsWith('---')) {
          prompt = line;
        }
        continue;
      }

      if (section == 'instructions') {
        if (line.startsWith('- ') && line.length > 2) {
          loadedInstructions.add(line.substring(2));
        }
        continue;
      }

      if (section == 'rules') {
        if (line.startsWith('- ') && line.length > 2) {
          workingRules.add(line.substring(2));
        }
        continue;
      }
    }

    if (inDecision && decisionSummary.isNotEmpty) {
      decisions.add(
        ChannelDecision(
          status: decisionStatus,
          summary: decisionSummary.toString().trimRight(),
          rationale: decisionRationale.toString().trimRight(),
          risks: decisionRisks,
          requiredTests: decisionTests,
        ),
      );
    }

    return Channel(
      id: id,
      status: status,
      createdAt: createdAt,
      participants: participants,
      prompt: prompt,
      loadedInstructions: loadedInstructions,
      workingRules: workingRules,
      messages: messages,
      decisions: decisions,
      maxTurns: maxTurns,
    );
  }
}
