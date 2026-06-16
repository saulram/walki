import 'package:test/test.dart';
import 'package:walki/walki.dart';

void main() {
  group('WalkiConfig', () {
    test('fromYaml creates config with defaults', () {
      final yaml = <dynamic, dynamic>{
        'version': 1,
        'project': {'name': 'test-project'},
      };
      final config = WalkiConfig.fromYaml(yaml);
      expect(config.version, equals(1));
      expect(config.project.name, equals('test-project'));
      expect(config.limits.maxTurns, equals(8));
      expect(config.limits.requireOverMarker, isTrue);
      expect(config.decisions.promoteRequiresHuman, isTrue);
    });

    test('fromYaml with full config', () {
      final yaml = <dynamic, dynamic>{
        'version': 1,
        'project': {'name': 'my-project'},
        'agents': <dynamic, dynamic>{
          'codex': <dynamic, dynamic>{
            'role': 'implementer',
            'can': ['read', 'append'],
          },
        },
        'limits': <dynamic, dynamic>{
          'max_turns': 12,
          'require_over_marker': false,
        },
      };
      final config = WalkiConfig.fromYaml(yaml);
      expect(config.agents, contains('codex'));
      expect(config.agents['codex']!.role, equals('implementer'));
      expect(config.limits.maxTurns, equals(12));
      expect(config.limits.requireOverMarker, isFalse);
    });

    test('toYaml produces valid yaml map', () {
      const config = WalkiConfig(
        project: ProjectConfig(name: 'test'),
      );
      final yaml = config.toYaml();
      expect(yaml['version'], equals(1));
      expect(yaml['project'], isNotNull);
    });
  });

  group('AgentConfig', () {
    test('fromYaml creates implementer', () {
      final yaml = <dynamic, dynamic>{
        'role': 'implementer',
        'can': ['read', 'append', 'propose_decision'],
      };
      final config = AgentConfig.fromYaml(yaml);
      expect(config.role, equals('implementer'));
      expect(config.can, contains('read'));
    });

    test('factory constructors create proper roles', () {
      final impl = AgentConfig.implementer();
      expect(impl.role, equals('implementer'));
      expect(impl.can, contains('propose_decision'));

      final reviewer = AgentConfig.reviewer();
      expect(reviewer.role, equals('reviewer'));
      expect(reviewer.can, contains('challenge_decision'));

      final owner = AgentConfig.owner();
      expect(owner.role, equals('owner'));
      expect(owner.can, contains('accept_decision'));
    });
  });

  group('Channel', () {
    test('copyWith creates new channel with changes', () {
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.open,
        createdAt: DateTime(2026, 1, 1),
        participants: ['codex', 'claude'],
      );
      final updated = channel.copyWith(status: ChannelStatus.active);
      expect(updated.status, equals(ChannelStatus.active));
      expect(updated.id, equals('test'));
    });

    test('isOpen returns true for open and active', () {
      final open = Channel(
        id: 'test',
        status: ChannelStatus.open,
        createdAt: DateTime(2026, 1, 1),
        participants: [],
      );
      final active = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026, 1, 1),
        participants: [],
      );
      final closed = Channel(
        id: 'test',
        status: ChannelStatus.accepted,
        createdAt: DateTime(2026, 1, 1),
        participants: [],
      );
      expect(open.isOpen, isTrue);
      expect(active.isOpen, isTrue);
      expect(closed.isOpen, isFalse);
    });

    test('ChannelStatus fromString works', () {
      expect(ChannelStatus.fromString('open'), equals(ChannelStatus.open));
      expect(
        ChannelStatus.fromString('needs-human'),
        equals(ChannelStatus.needsHuman),
      );
      expect(
        ChannelStatus.fromString('accepted'),
        equals(ChannelStatus.accepted),
      );
    });
  });

  group('ChannelParser', () {
    test('parses basic channel', () {
      const parser = ChannelParser();
      final channel = parser.parse('''
# Walki Channel: test-channel

## Metadata

- id: test-channel
- status: open
- created_at: 2026-05-06T10:15:00Z
- participants: codex, claude
- max_turns: 8

## Working Rules

- Read before writing.
- Append only.

---

## 2026-05-06T10:15:00Z - codex - proposal

I propose something.

OVER

---
''');

      expect(channel.id, equals('test-channel'));
      expect(channel.status, equals(ChannelStatus.open));
      expect(channel.participants, contains('codex'));
      expect(channel.participants, contains('claude'));
      expect(channel.messages.length, equals(1));
      expect(channel.messages.first.agent, equals('codex'));
      expect(channel.messages.first.kind, equals(MessageKind.proposal));
      expect(channel.messages.first.endsWithOver, isTrue);
    });

    test('parses channel with multiple messages', () {
      const parser = ChannelParser();
      final channel = parser.parse('''
# Walki Channel: multi

## Metadata

- id: multi
- status: active
- created_at: 2026-05-06T10:15:00Z
- participants: codex, claude
- max_turns: 8

---

## 2026-05-06T10:15:00Z - codex - proposal

First proposal.

OVER

---

## 2026-05-06T10:16:00Z - claude - challenge

Challenge to proposal.

OVER

---

## 2026-05-06T10:17:00Z - codex - agreement

I agree.

OVER

---
''');

      expect(channel.messages.length, equals(3));
      expect(channel.messages[0].kind, equals(MessageKind.proposal));
      expect(channel.messages[1].kind, equals(MessageKind.challenge));
      expect(channel.messages[2].kind, equals(MessageKind.agreement));
    });
  });

  group('ChannelFormatter', () {
    test('format and round-trip', () {
      const formatter = ChannelFormatter();
      const parser = ChannelParser();

      final channel = Channel(
        id: 'round-trip',
        status: ChannelStatus.active,
        createdAt: DateTime(2026, 5, 6, 10, 15),
        participants: ['codex', 'claude'],
        prompt: 'Test prompt',
        workingRules: ['Read before writing.', 'Append only.'],
        messages: [
          ChannelMessage(
            agent: 'codex',
            kind: MessageKind.proposal,
            content: 'Test proposal',
            timestamp: DateTime(2026, 5, 6, 10, 16),
          ),
        ],
        maxTurns: 8,
      );

      final formatted = formatter.format(channel);
      final parsed = parser.parse(formatted);

      expect(parsed.id, equals('round-trip'));
      expect(parsed.status, equals(ChannelStatus.active));
      expect(parsed.participants, contains('codex'));
      expect(parsed.messages.length, equals(1));
      expect(parsed.messages.first.agent, equals('codex'));
    });
  });

  group('PermissionEngine', () {
    test('validates agent permissions', () {
      const engine = PermissionEngine();
      final implementer = AgentConfig.implementer();
      expect(engine.canPerformAction(implementer, 'read'), isTrue);
      expect(engine.canPerformAction(implementer, 'accept_decision'), isFalse);
    });

    test('detects closed channel', () {
      const engine = PermissionEngine();
      final implementer = AgentConfig.implementer();
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.accepted,
        createdAt: DateTime(2026, 1, 1),
        participants: ['codex'],
      );
      final violations = engine.validateMessage(implementer, channel, 'append');
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.contains('closed')), isTrue);
    });

    test('allows valid message on open channel', () {
      const engine = PermissionEngine();
      final implementer = AgentConfig.implementer();
      final channel = Channel(
        id: 'test',
        status: ChannelStatus.active,
        createdAt: DateTime(2026, 1, 1),
        participants: ['codex'],
      );
      final violations = engine.validateMessage(implementer, channel, 'append');
      expect(violations, isEmpty);
    });
  });

  group('Decision', () {
    test('toMarkdown generates valid markdown', () {
      final decision = Decision(
        channelId: 'auth',
        status: 'accepted',
        summary: 'Use tenant-scoped JWT claims',
        rationale: 'Middleware provides request context',
        risks: ['Token revocation is a separate concern'],
        requiredTests: ['Cross-tenant access attempts'],
        createdAt: DateTime(2026, 5, 6),
      );
      final md = decision.toMarkdown();
      expect(md, contains('# Decision: auth'));
      expect(md, contains('Use tenant-scoped JWT claims'));
      expect(md, contains('Token revocation'));
    });
  });

  group('Task', () {
    test('toMarkdown generates valid markdown', () {
      final task = Task(
        id: 'task-1',
        channelId: 'auth',
        description: 'Implement JWT tenant claims',
        status: 'proposed',
        decisionId: 'auth',
        acceptanceCriteria: ['All requests include tenant ID'],
        createdAt: DateTime(2026, 5, 6),
      );
      final md = task.toMarkdown();
      expect(md, contains('# Task: task-1'));
      expect(md, contains('Implement JWT tenant claims'));
    });
  });
}
