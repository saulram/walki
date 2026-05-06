import 'package:test/test.dart';
import 'package:walki/walki.dart';

void main() {
  group('Agent', () {
    test('toMarkdown generates correct output for implementer', () {
      const agent = Agent(id: 'codex', role: 'implementer', can: ['read', 'append', 'propose_decision', 'propose_task']);
      final md = agent.toMarkdown();
      expect(md, contains('# Agent: codex'));
      expect(md, contains('- **Role**: implementer'));
      expect(md, contains('- **Can**'));
      expect(md, contains('implementation-oriented'));
    });

    test('toMarkdown generates correct output for reviewer', () {
      const agent = Agent(id: 'claude', role: 'reviewer', can: ['read', 'append', 'challenge_decision']);
      final md = agent.toMarkdown();
      expect(md, contains('# Agent: claude'));
      expect(md, contains('- **Role**: reviewer'));
      expect(md, contains('architecture and review-oriented'));
    });

    test('toMarkdown generates correct output for owner', () {
      const agent = Agent(id: 'human', role: 'owner', can: ['read', 'accept_decision']);
      final md = agent.toMarkdown();
      expect(md, contains('# Agent: human'));
      expect(md, contains('- **Role**: owner'));
      expect(md, contains('owner and decision-maker'));
    });

    test('toMarkdown includes description', () {
      const agent = Agent(id: 'codex', role: 'implementer', description: 'OpenAI agent', can: ['read']);
      final md = agent.toMarkdown();
      expect(md, contains('- **Description**: OpenAI agent'));
    });

    test('toMarkdown with no description shows no description', () {
      const agent = Agent(id: 'codex', role: 'implementer', can: ['read']);
      final md = agent.toMarkdown();
      expect(md, contains('- **Description**: No description'));
    });
  });

  group('Decision', () {
    test('toMarkdown generates all sections', () {
      final decision = Decision(
        channelId: 'auth',
        status: 'accepted',
        summary: 'Use JWT claims',
        rationale: 'Secure approach',
        risks: ['Token revocation', 'Key rotation'],
        implications: ['Migration needed', 'Dependency on auth service'],
        requiredTests: ['Cross-tenant access', 'Token expiration'],
        owner: 'human',
        createdAt: DateTime(2026, 5, 6),
      );
      final md = decision.toMarkdown();
      expect(md, contains('# Decision: auth'));
      expect(md, contains('- channel: auth'));
      expect(md, contains('- status: accepted'));
      expect(md, contains('- owner: human'));
      expect(md, contains('## Summary'));
      expect(md, contains('Use JWT claims'));
      expect(md, contains('## Rationale'));
      expect(md, contains('Secure approach'));
      expect(md, contains('## Risks'));
      expect(md, contains('- Token revocation'));
      expect(md, contains('## Implications'));
      expect(md, contains('- Migration needed'));
      expect(md, contains('## Required Tests'));
      expect(md, contains('- Cross-tenant access'));
    });

    test('toMarkdown omits empty sections', () {
      final decision = Decision(
        channelId: 'test',
        status: 'proposed',
        summary: 'Simple decision',
        rationale: 'Reason',
        createdAt: DateTime(2026),
      );
      final md = decision.toMarkdown();
      expect(md, contains('# Decision: test'));
      expect(md, isNot(contains('## Risks')));
      expect(md, isNot(contains('## Implications')));
      expect(md, isNot(contains('## Required Tests')));
    });

    test('owner defaults to pending when empty', () {
      final decision = Decision(
        channelId: 'test',
        status: 'proposed',
        summary: 'Test',
        rationale: 'Reason',
        owner: '',
        createdAt: DateTime(2026),
      );
      final md = decision.toMarkdown();
      expect(md, contains('- owner: pending'));
    });
  });

  group('Task', () {
    test('toMarkdown generates all sections', () {
      final task = Task(
        id: 'task-1',
        channelId: 'auth',
        description: 'Implement JWT middleware',
        status: 'proposed',
        decisionId: 'auth',
        suggestedOwner: 'codex',
        acceptanceCriteria: ['All requests authenticated', 'Token expires correctly'],
        createdAt: DateTime(2026, 5, 6),
      );
      final md = task.toMarkdown();
      expect(md, contains('# Task: task-1'));
      expect(md, contains('- channel: auth'));
      expect(md, contains('- decision: auth'));
      expect(md, contains('- status: proposed'));
      expect(md, contains('- suggested_owner: codex'));
      expect(md, contains('## Description'));
      expect(md, contains('Implement JWT middleware'));
      expect(md, contains('## Acceptance Criteria'));
      expect(md, contains('- All requests authenticated'));
    });

    test('toMarkdown omits acceptance criteria when empty', () {
      final task = Task(
        id: 'task-2',
        channelId: 'auth',
        description: 'Write tests',
        status: 'proposed',
        decisionId: 'auth',
        createdAt: DateTime(2026),
      );
      final md = task.toMarkdown();
      expect(md, contains('# Task: task-2'));
      expect(md, isNot(contains('## Acceptance Criteria')));
    });

    test('suggested owner defaults to pending', () {
      final task = Task(
        id: 'task-3',
        channelId: 'auth',
        description: 'Review',
        status: 'proposed',
        decisionId: 'auth',
        suggestedOwner: '',
        createdAt: DateTime(2026),
      );
      final md = task.toMarkdown();
      expect(md, contains('- suggested_owner: pending'));
    });
  });
}