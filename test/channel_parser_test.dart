import 'package:test/test.dart';
import 'package:walki/walki.dart';

void main() {
  group('ChannelParser', () {
    const parser = ChannelParser();

    test('parses minimal channel', () {
      final channel = parser.parse('''
# Walki Channel: test

## Metadata

- id: test
- status: open
- created_at: 2026-05-06T10:15:00Z
- participants: codex
- max_turns: 4

---
''');

      expect(channel.id, equals('test'));
      expect(channel.status, equals(ChannelStatus.open));
      expect(channel.participants, equals(['codex']));
      expect(channel.maxTurns, equals(4));
      expect(channel.messages, isEmpty);
      expect(channel.decisions, isEmpty);
    });

    test('parses channel with user prompt', () {
      final channel = parser.parse('''
# Walki Channel: auth

## Metadata

- id: auth
- status: open
- created_at: 2026-05-06T10:15:00Z
- participants: codex, claude
- max_turns: 8

## User Prompt

How should we implement auth?

---
''');

      expect(channel.id, equals('auth'));
      expect(channel.prompt, equals('How should we implement auth?'));
    });

    test('parses channel with loaded instructions', () {
      final channel = parser.parse('''
# Walki Channel: test

## Metadata

- id: test
- status: open
- created_at: 2026-05-06T10:15:00Z
- participants: codex
- max_turns: 8

## Loaded Instructions

- .walki/instructions.md
- .walki/rules/security.md

---
''');

      expect(channel.loadedInstructions.length, equals(2));
      expect(channel.loadedInstructions, contains('.walki/instructions.md'));
      expect(channel.loadedInstructions, contains('.walki/rules/security.md'));
    });

    test('parses channel with working rules', () {
      final channel = parser.parse('''
# Walki Channel: test

## Metadata

- id: test
- status: open
- created_at: 2026-05-06T10:15:00Z
- participants: codex
- max_turns: 8

## Working Rules

- Read before writing.
- Append only.
- End every message with OVER.

---
''');

      expect(channel.workingRules.length, equals(3));
      expect(channel.workingRules.first, equals('Read before writing.'));
    });

    test('parses channel with messages', () {
      final channel = parser.parse('''
# Walki Channel: test

## Metadata

- id: test
- status: active
- created_at: 2026-05-06T10:15:00Z
- participants: codex, claude
- max_turns: 8

---

## 2026-05-06T10:15:00Z - codex - proposal

I propose tenant-scoped JWT claims.

OVER

---

## 2026-05-06T10:18:00Z - claude - challenge

Middleware alone is insufficient.

OVER

---

''');

      expect(channel.messages.length, equals(2));
      expect(channel.messages[0].agent, equals('codex'));
      expect(channel.messages[0].kind, equals(MessageKind.proposal));
      expect(channel.messages[0].content, contains('tenant-scoped JWT claims'));
      expect(channel.messages[0].endsWithOver, isTrue);
      expect(channel.messages[1].agent, equals('claude'));
      expect(channel.messages[1].kind, equals(MessageKind.challenge));
    });

    test('parses channel with decision', () {
      final channel = parser.parse('''
# Walki Channel: test

## Metadata

- id: test
- status: accepted
- created_at: 2026-05-06T10:15:00Z
- participants: codex, claude
- max_turns: 8

---

## Decision: accepted

Use tenant-scoped JWT claims, tenant resolver middleware, and repository-level tenant filtering.

Rationale:
- Middleware provides request context.
- Repository filtering reduces blast radius.

Risks:
- Token revocation remains a separate concern.
- Data migrations must preserve tenant IDs.

Required tests:
- Cross-tenant read attempt fails.
- Cross-tenant write attempt fails.

---
''');

      expect(channel.decisions.length, equals(1));
      expect(channel.decisions[0].status, equals('accepted'));
      expect(channel.decisions[0].summary, contains('tenant-scoped JWT claims'));
      expect(channel.decisions[0].rationale, contains('Middleware provides request context'));
      expect(channel.decisions[0].risks.length, equals(2));
      expect(channel.decisions[0].requiredTests.length, equals(2));
    });

    test('parses all channel statuses', () {
      for (final status in ['open', 'active', 'accepted', 'blocked', 'needs-human', 'needs-context', 'abandoned', 'superseded', 'promoted', 'closed']) {
        final channel = parser.parse('''
# Walki Channel: test

## Metadata

- id: test
- status: $status
- created_at: 2026-05-06T10:15:00Z
- participants: codex
- max_turns: 8

---
''');
        expect(channel.status.toYamlValue(), equals(status));
      }
    });

    test('parses all message kinds', () {
      final kinds = ['proposal', 'challenge', 'question', 'clarification', 'agreement', 'objection', 'decision', 'context', 'summary', 'meta'];
      for (final kind in kinds) {
        final channel = parser.parse('''
# Walki Channel: test

## Metadata

- id: test
- status: active
- created_at: 2026-05-06T10:15:00Z
- participants: codex
- max_turns: 8

---

## 2026-05-06T10:15:00Z - codex - $kind

Content here.

OVER

---
''');
        expect(channel.messages[0].kind, equals(MessageKind.fromString(kind)));
      }
    });

    test('parses channel without OVER marker', () {
      final channel = parser.parse('''
# Walki Channel: test

## Metadata

- id: test
- status: active
- created_at: 2026-05-06T10:15:00Z
- participants: codex
- max_turns: 8

---

## 2026-05-06T10:15:00Z - codex - proposal

Message without OVER marker.

---
''');

      expect(channel.messages.length, equals(1));
      expect(channel.messages[0].endsWithOver, isFalse);
    });

    test('handles empty channel', () {
      final channel = parser.parse('# Walki Channel: empty\n\n## Metadata\n\n- id: empty\n- status: open\n- created_at: 2026-05-06T10:15:00Z\n- participants: codex\n- max_turns: 8\n\n---\n');
      expect(channel.id, equals('empty'));
      expect(channel.messages, isEmpty);
      expect(channel.decisions, isEmpty);
    });
  });

  group('ChannelFormatter', () {
    const formatter = ChannelFormatter();

    test('formats basic channel', () {
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.open,
        createdAt: DateTime(2026, 5, 6, 10, 15),
        participants: ['codex', 'claude'],
        prompt: 'How to implement auth?',
        workingRules: ['Read before writing.', 'Append only.'],
        maxTurns: 8,
      );
      final md = formatter.format(channel);
      expect(md, contains('# Walki Channel: test'));
      expect(md, contains('- id: test'));
      expect(md, contains('- status: open'));
      expect(md, contains('How to implement auth?'));
      expect(md, contains('- Read before writing.'));
    });

    test('formats channel with messages', () {
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026, 5, 6),
        participants: ['codex'],
        messages: [
          ChannelMessage(
            agent: 'codex',
            kind: MessageKind.proposal,
            content: 'Test proposal',
            timestamp: DateTime(2026, 5, 6, 10, 15),
          ),
        ],
        maxTurns: 8,
      );
      final md = formatter.format(channel);
      expect(md, contains('- codex - proposal'));
      expect(md, contains('Test proposal'));
      expect(md, contains('OVER'));
    });

    test('formatStatus shows key information', () {
      final channel = Channel(
        id: 'auth',
        status: ChannelStatus.active,
        createdAt: DateTime(2026, 5, 6),
        participants: ['codex', 'claude'],
        messages: [
          ChannelMessage(agent: 'claude', kind: MessageKind.challenge, content: 'Test', timestamp: DateTime(2026, 5, 6)),
        ],
        maxTurns: 8,
      );
      final status = formatter.formatStatus(channel);
      expect(status, contains('Channel: auth'));
      expect(status, contains('Status: active'));
      expect(status, contains('Turns: 1/8'));
      expect(status, contains('Participants: codex, claude'));
    });

    test('formatStatus with decisions', () {
      final channel = Channel(
        id: 'auth',
        status: ChannelStatus.accepted,
        createdAt: DateTime(2026, 5, 6),
        participants: ['codex'],
        decisions: [
          ChannelDecision(status: 'accepted', summary: 'Use JWT claims', rationale: 'Secure'),
        ],
        maxTurns: 8,
      );
      final status = formatter.formatStatus(channel);
      expect(status, contains('Use JWT claims'));
    });

    test('formatAppendMessage creates correct block', () {
      final msg = ChannelMessage(
        agent: 'codex',
        kind: MessageKind.proposal,
        content: 'New idea here',
        timestamp: DateTime(2026, 5, 6, 12, 0),
      );
      final result = formatter.formatAppendMessage(msg);
      expect(result, contains('---'));
      expect(result, contains('- codex - proposal'));
      expect(result, contains('New idea here'));
      expect(result, contains('OVER'));
    });

    test('formatDecision creates decision block', () {
      final decision = ChannelDecision(
        status: 'accepted',
        summary: 'Use JWT claims',
        rationale: 'Secure approach',
        risks: ['Token revocation'],
        requiredTests: ['Cross-tenant access'],
      );
      final result = formatter.formatDecision(decision);
      expect(result, contains('Decision: accepted'));
      expect(result, contains('Use JWT claims'));
      expect(result, contains('Rationale:'));
      expect(result, contains('Secure approach'));
      expect(result, contains('Risks:'));
      expect(result, contains('- Token revocation'));
      expect(result, contains('Required tests:'));
    });

    test('formatDecision without optional fields', () {
      final decision = ChannelDecision(
        status: 'proposed',
        summary: 'Simple decision',
        rationale: '',
      );
      final result = formatter.formatDecision(decision);
      expect(result, contains('Decision: proposed'));
      expect(result, contains('Simple decision'));
    });

    test('round-trip preserves data', () {
      final original = Channel(
        id: 'round-trip',
        status: ChannelStatus.active,
        createdAt: DateTime(2026, 5, 6, 10, 15, 30),
        participants: ['codex', 'claude'],
        prompt: 'Auth question',
        loadedInstructions: ['.walki/rules/security.md'],
        workingRules: ['Read before writing.', 'Append only.'],
        messages: [
          ChannelMessage(agent: 'codex', kind: MessageKind.proposal, content: 'Proposal text', timestamp: DateTime(2026, 5, 6, 10, 20)),
          ChannelMessage(agent: 'claude', kind: MessageKind.challenge, content: 'Challenge text', timestamp: DateTime(2026, 5, 6, 10, 25)),
        ],
        maxTurns: 8,
      );
      const formatter = ChannelFormatter();
      const parser = ChannelParser();
      final formatted = formatter.format(original);
      final parsed = parser.parse(formatted);

      expect(parsed.id, equals('round-trip'));
      expect(parsed.status, equals(ChannelStatus.active));
      expect(parsed.participants, contains('codex'));
      expect(parsed.participants, contains('claude'));
      expect(parsed.prompt, equals('Auth question'));
      expect(parsed.loadedInstructions, contains('.walki/rules/security.md'));
      expect(parsed.workingRules.length, equals(2));
      expect(parsed.messages.length, equals(2));
      expect(parsed.messages[0].agent, equals('codex'));
      expect(parsed.messages[0].kind, equals(MessageKind.proposal));
      expect(parsed.messages[1].agent, equals('claude'));
      expect(parsed.messages[1].kind, equals(MessageKind.challenge));
    });
  });
}