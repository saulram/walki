import 'package:test/test.dart';
import 'package:walki/walki.dart';

void main() {
  group('ChannelStatus', () {
    test('fromString for all statuses', () {
      expect(ChannelStatus.fromString('open'), equals(ChannelStatus.open));
      expect(ChannelStatus.fromString('active'), equals(ChannelStatus.active));
      expect(ChannelStatus.fromString('accepted'), equals(ChannelStatus.accepted));
      expect(ChannelStatus.fromString('blocked'), equals(ChannelStatus.blocked));
      expect(ChannelStatus.fromString('needs-human'), equals(ChannelStatus.needsHuman));
      expect(ChannelStatus.fromString('needs-context'), equals(ChannelStatus.needsContext));
      expect(ChannelStatus.fromString('superseded'), equals(ChannelStatus.superseded));
      expect(ChannelStatus.fromString('abandoned'), equals(ChannelStatus.abandoned));
      expect(ChannelStatus.fromString('promoted'), equals(ChannelStatus.promoted));
      expect(ChannelStatus.fromString('closed'), equals(ChannelStatus.closed));
    });

    test('fromString with unknown value defaults to open', () {
      expect(ChannelStatus.fromString('unknown'), equals(ChannelStatus.open));
      expect(ChannelStatus.fromString(''), equals(ChannelStatus.open));
    });

    test('toYamlValue converts camelCase to kebab-case', () {
      expect(ChannelStatus.needsHuman.toYamlValue(), equals('needs-human'));
      expect(ChannelStatus.needsContext.toYamlValue(), equals('needs-context'));
      expect(ChannelStatus.open.toYamlValue(), equals('open'));
      expect(ChannelStatus.active.toYamlValue(), equals('active'));
      expect(ChannelStatus.accepted.toYamlValue(), equals('accepted'));
    });
  });

  group('MessageKind', () {
    test('fromString for all kinds', () {
      expect(MessageKind.fromString('proposal'), equals(MessageKind.proposal));
      expect(MessageKind.fromString('challenge'), equals(MessageKind.challenge));
      expect(MessageKind.fromString('question'), equals(MessageKind.question));
      expect(MessageKind.fromString('clarification'), equals(MessageKind.clarification));
      expect(MessageKind.fromString('agreement'), equals(MessageKind.agreement));
      expect(MessageKind.fromString('objection'), equals(MessageKind.objection));
      expect(MessageKind.fromString('decision'), equals(MessageKind.decision));
      expect(MessageKind.fromString('context'), equals(MessageKind.context));
      expect(MessageKind.fromString('summary'), equals(MessageKind.summary));
      expect(MessageKind.fromString('meta'), equals(MessageKind.meta));
    });

    test('fromString with unknown defaults to proposal', () {
      expect(MessageKind.fromString('unknown'), equals(MessageKind.proposal));
    });

    test('fromString is case insensitive', () {
      expect(MessageKind.fromString('PROPOSAL'), equals(MessageKind.proposal));
      expect(MessageKind.fromString('Challenge'), equals(MessageKind.challenge));
    });
  });

  group('ChannelMessage', () {
    test('creates message with all fields', () {
      final msg = ChannelMessage(
        agent: 'codex',
        kind: MessageKind.proposal,
        content: 'Test content',
        timestamp: DateTime(2026, 5, 6),
        endsWithOver: true,
      );
      expect(msg.agent, equals('codex'));
      expect(msg.kind, equals(MessageKind.proposal));
      expect(msg.content, equals('Test content'));
      expect(msg.endsWithOver, isTrue);
    });

    test('defaults endsWithOver to true', () {
      final msg = ChannelMessage(
        agent: 'codex',
        kind: MessageKind.proposal,
        content: 'Test',
        timestamp: DateTime(2026),
      );
      expect(msg.endsWithOver, isTrue);
    });
  });

  group('ChannelDecision', () {
    test('creates decision with all fields', () {
      final decision = ChannelDecision(
        status: 'accepted',
        summary: 'Use JWT claims',
        rationale: 'Best approach',
        risks: ['Token revocation'],
        implications: ['Migration needed'],
        requiredTests: ['Cross-tenant access'],
        owner: 'human',
      );
      expect(decision.status, equals('accepted'));
      expect(decision.summary, equals('Use JWT claims'));
      expect(decision.risks, contains('Token revocation'));
      expect(decision.implications, contains('Migration needed'));
      expect(decision.requiredTests, contains('Cross-tenant access'));
      expect(decision.owner, equals('human'));
    });

    test('defaults empty lists', () {
      const decision = ChannelDecision(
        status: 'proposed',
        summary: 'Test',
        rationale: 'Reason',
      );
      expect(decision.risks, isEmpty);
      expect(decision.implications, isEmpty);
      expect(decision.requiredTests, isEmpty);
      expect(decision.owner, equals(''));
    });
  });

  group('Channel', () {
    test('creates channel with required fields', () {
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.open,
        createdAt: DateTime(2026),
        participants: ['codex', 'claude'],
      );
      expect(channel.id, equals('test'));
      expect(channel.status, equals(ChannelStatus.open));
      expect(channel.participants, contains('codex'));
      expect(channel.messages, isEmpty);
      expect(channel.decisions, isEmpty);
      expect(channel.prompt, equals(''));
      expect(channel.loadedInstructions, isEmpty);
      expect(channel.workingRules, isEmpty);
      expect(channel.maxTurns, equals(8));
    });

    test('isOpen is true for open and active', () {
      final open = Channel(id: 't', status: ChannelStatus.open, createdAt: DateTime(2026), participants: []);
      final active = Channel(id: 't', status: ChannelStatus.active, createdAt: DateTime(2026), participants: []);
      final accepted = Channel(id: 't', status: ChannelStatus.accepted, createdAt: DateTime(2026), participants: []);
      final blocked = Channel(id: 't', status: ChannelStatus.blocked, createdAt: DateTime(2026), participants: []);
      final closed = Channel(id: 't', status: ChannelStatus.closed, createdAt: DateTime(2026), participants: []);
      expect(open.isOpen, isTrue);
      expect(active.isOpen, isTrue);
      expect(accepted.isOpen, isFalse);
      expect(blocked.isOpen, isFalse);
      expect(closed.isOpen, isFalse);
    });

    test('isClosed is inverse of isOpen', () {
      final open = Channel(id: 't', status: ChannelStatus.open, createdAt: DateTime(2026), participants: []);
      final accepted = Channel(id: 't', status: ChannelStatus.accepted, createdAt: DateTime(2026), participants: []);
      expect(open.isClosed, isFalse);
      expect(accepted.isClosed, isTrue);
    });

    test('turnCount returns message count', () {
      final channel = Channel(
        id: 't',
        status: ChannelStatus.open,
        createdAt: DateTime(2026),
        participants: [],
        messages: [
          ChannelMessage(agent: 'a', kind: MessageKind.proposal, content: '1', timestamp: DateTime(2026)),
          ChannelMessage(agent: 'b', kind: MessageKind.challenge, content: '2', timestamp: DateTime(2026)),
          ChannelMessage(agent: 'a', kind: MessageKind.agreement, content: '3', timestamp: DateTime(2026)),
        ],
      );
      expect(channel.turnCount, equals(3));
    });

    test('copyWith preserves unchanged fields', () {
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.open,
        createdAt: DateTime(2026, 5, 6),
        participants: ['codex'],
        prompt: 'Question?',
        maxTurns: 10,
      );
      final updated = channel.copyWith(status: ChannelStatus.active);
      expect(updated.id, equals('test'));
      expect(updated.status, equals(ChannelStatus.active));
      expect(updated.participants, contains('codex'));
      expect(updated.prompt, equals('Question?'));
      expect(updated.maxTurns, equals(10));
    });

    test('copyWith can update participants', () {
      final channel = Channel(
        id: 't',
        status: ChannelStatus.open,
        createdAt: DateTime(2026),
        participants: ['codex'],
      );
      final updated = channel.copyWith(participants: ['codex', 'claude', 'gemini']);
      expect(updated.participants.length, equals(3));
      expect(updated.participants, contains('gemini'));
    });

    test('copyWith can add messages', () {
      final channel = Channel(
        id: 't',
        status: ChannelStatus.open,
        createdAt: DateTime(2026),
        participants: [],
      );
      final msg = ChannelMessage(
        agent: 'codex',
        kind: MessageKind.proposal,
        content: 'New message',
        timestamp: DateTime(2026),
      );
      final updated = channel.copyWith(messages: [...channel.messages, msg]);
      expect(updated.messages.length, equals(1));
      expect(updated.messages.first.content, equals('New message'));
    });
  });
}