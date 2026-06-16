import 'package:test/test.dart';
import 'package:walki/walki.dart';

void main() {
  group('PermissionEngine', () {
    const engine = PermissionEngine();

    test('implementer can read and append', () {
      final impl = AgentConfig.implementer();
      expect(engine.canPerformAction(impl, 'read'), isTrue);
      expect(engine.canPerformAction(impl, 'append'), isTrue);
      expect(engine.canPerformAction(impl, 'propose_decision'), isTrue);
      expect(engine.canPerformAction(impl, 'propose_task'), isTrue);
    });

    test('implementer cannot accept decisions', () {
      final impl = AgentConfig.implementer();
      expect(engine.canPerformAction(impl, 'accept_decision'), isFalse);
      expect(engine.canPerformAction(impl, 'reject_decision'), isFalse);
      expect(engine.canPerformAction(impl, 'close_channel'), isFalse);
      expect(engine.canPerformAction(impl, 'promote_to_sdd'), isFalse);
    });

    test('reviewer can challenge decisions', () {
      final reviewer = AgentConfig.reviewer();
      expect(engine.canPerformAction(reviewer, 'read'), isTrue);
      expect(engine.canPerformAction(reviewer, 'append'), isTrue);
      expect(engine.canPerformAction(reviewer, 'challenge_decision'), isTrue);
      expect(engine.canPerformAction(reviewer, 'propose_decision'), isTrue);
      expect(engine.canPerformAction(reviewer, 'accept_decision'), isFalse);
    });

    test('owner can accept decisions', () {
      final owner = AgentConfig.owner();
      expect(engine.canPerformAction(owner, 'read'), isTrue);
      expect(engine.canPerformAction(owner, 'accept_decision'), isTrue);
      expect(engine.canPerformAction(owner, 'reject_decision'), isTrue);
      expect(engine.canPerformAction(owner, 'close_channel'), isTrue);
      expect(engine.canPerformAction(owner, 'promote_to_sdd'), isTrue);
    });

    test(
        'validateMessage returns no violations for valid message on open channel',
        () {
      final impl = AgentConfig.implementer();
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026),
        participants: ['codex'],
      );
      final violations = engine.validateMessage(impl, channel, 'append');
      expect(violations, isEmpty);
    });

    test('validateMessage detects closed channel', () {
      final impl = AgentConfig.implementer();
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.accepted,
        createdAt: DateTime(2026),
        participants: ['codex'],
      );
      final violations = engine.validateMessage(impl, channel, 'append');
      expect(violations.any((v) => v.contains('closed')), isTrue);
    });

    test('validateMessage detects unauthorized action', () {
      final impl = AgentConfig.implementer();
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026),
        participants: ['codex'],
      );
      final violations =
          engine.validateMessage(impl, channel, 'accept_decision');
      expect(violations.any((v) => v.contains('cannot perform')), isTrue);
    });

    test(
      'validateMessage detects max messages per agent exceeded',
      () {
        final impl = AgentConfig.implementer();
        final messages = List.generate(
          4,
          (i) => ChannelMessage(
            agent: 'codex',
            kind: MessageKind.proposal,
            content: 'msg $i',
            timestamp: DateTime(2026, 5, 6, 10, i + 1),
          ),
        );
        final channel = Channel(
          id: 'test',
          status: ChannelStatus.active,
          createdAt: DateTime(2026),
          participants: ['codex'],
          messages: messages,
          maxTurns: 20,
        );
        final violations =
            engine.validateMessage(impl, channel, 'append', agentId: 'codex');
        expect(
          violations.any((v) => v.contains('maximum message count')),
          isTrue,
        );
      },
    );

    test('validateMessage detects max turns exceeded', () {
      final impl = AgentConfig.implementer();
      final messages = List.generate(
        8,
        (i) => ChannelMessage(
          agent: i.isEven ? 'codex' : 'claude',
          kind: MessageKind.proposal,
          content: 'msg $i',
          timestamp: DateTime(2026, 5, 6, 10, i + 1),
        ),
      );
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026),
        participants: ['codex', 'claude'],
        messages: messages,
        maxTurns: 8,
      );
      final violations = engine.validateMessage(impl, channel, 'append');
      expect(violations.any((v) => v.contains('maximum turn count')), isTrue);
    });

    test('validateChannelHealth detects missing OVER markers', () {
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026),
        participants: ['codex'],
        messages: [
          ChannelMessage(
            agent: 'codex',
            kind: MessageKind.proposal,
            content: 'No OVER',
            timestamp: DateTime(2026),
            endsWithOver: false,
          ),
        ],
      );
      final issues = engine.validateChannelHealth(channel);
      expect(issues.any((i) => i.contains('missing OVER')), isTrue);
    });

    test('validateChannelHealth detects messages with correct OVER', () {
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026),
        participants: ['codex'],
        messages: [
          ChannelMessage(
            agent: 'codex',
            kind: MessageKind.proposal,
            content: 'Has OVER',
            timestamp: DateTime(2026),
            endsWithOver: true,
          ),
        ],
      );
      final issues = engine.validateChannelHealth(channel);
      expect(issues.any((i) => i.contains('missing OVER')), isFalse);
    });

    test('validateChannelHealth detects unknown agents', () {
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026),
        participants: ['codex'],
        messages: [
          ChannelMessage(
            agent: 'unknown_agent',
            kind: MessageKind.proposal,
            content: 'Test',
            timestamp: DateTime(2026),
          ),
        ],
      );
      final issues = engine.validateChannelHealth(channel);
      expect(issues.any((i) => i.contains('Unknown agent')), isTrue);
    });

    test('validateChannelHealth detects no issues in healthy channel', () {
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026),
        participants: ['codex', 'claude'],
        messages: [
          ChannelMessage(
            agent: 'codex',
            kind: MessageKind.proposal,
            content: 'Test',
            timestamp: DateTime(2026, 5, 6, 10, 0),
          ),
          ChannelMessage(
            agent: 'claude',
            kind: MessageKind.challenge,
            content: 'Challenge',
            timestamp: DateTime(2026, 5, 6, 10, 5),
          ),
        ],
      );
      final issues = engine.validateChannelHealth(channel);
      expect(issues, isEmpty);
    });
  });
}
