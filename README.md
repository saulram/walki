# Walki

Local coordination protocol for AI agents.

Walki lets Codex, Claude Code, Gemini CLI, Cursor agents, and other AI coding agents deliberate through Markdown files inside your repo.

The goal is not endless agent chat. The goal is explicit, reviewable agreements before code changes.

```
agreement -> decision -> spec -> task
```

## Why

When you use multiple AI agents on the same project, they don't share context. You end up copying and pasting between tools, decisions get lost in chat history, and there's no audit trail for architectural choices.

Walki gives agents a shared space inside your repo where they can propose, challenge, and reach agreements. Every debate is a Markdown file. Every decision is versioned in git.

## Install

```bash
dart pub global activate walki
```

## Quick start

```bash
# Initialize Walki in your project
walki init --agents codex,claude

# Start a debate
walki debate auth "How should we implement multi-tenant auth?" \
  --rules security,testing \
  --max-turns 8

# Agent sends a message
walki say codex auth "I propose tenant-scoped JWT claims plus tenant resolver middleware."

# Another agent responds
walki say claude auth "I agree with tenant-scoped claims, but middleware alone is insufficient. Repository-level filtering is also needed."

# Check status
walki status auth

# Close debate
walki close auth --status accepted

# Promote to sdd_ai
walki promote auth --to sdd-ai
```

## How it works

### Workspace structure

```text
.walki/
├── config.yaml            # Project configuration
├── instructions.md         # Project-level agent rules
├── agents/
│   ├── codex.md           # Agent identity and role
│   ├── claude.md          # Agent identity and role
│   └── human.md           # Human owner role
├── rules/
│   ├── security.md        # Security constraints for agents
│   ├── code-style.md      # Code style rules
│   ├── testing.md         # Testing requirements
│   └── architecture.md    # Architecture rules
├── channels/
│   └── auth.md            # Debate channels (Markdown)
├── decisions/
│   └── auth.md            # Accepted decisions
├── tasks/
│   └── auth.md            # Tasks derived from decisions
├── state/
│   ├── index.yaml         # Generated state index
│   └── auth.yaml          # Per-channel state
└── locks/
    └── auth.lock          # Write locks
```

### Channel format

Each debate lives in a single Markdown file. Agents read the entire file, then append their message at the end. Every message ends with `OVER`.

```markdown
# Walki Channel: auth-multitenant

## Metadata

- id: auth-multitenant
- status: open
- created_at: 2026-05-06T10:15:00Z
- participants: codex, claude, human
- max_turns: 8

## Working Rules

- Read before writing.
- Append only.
- End every message with OVER.
- Propose decisions explicitly.
- Include risks and tests.
- Stop on agreement, missing context, disagreement, or max turns.

---

## 2026-05-06T10:15:00Z - codex - proposal

I propose tenant-scoped JWT claims plus tenant resolver middleware.

Risks:
- Token invalidation must be explicit.
- Cross-tenant access must be tested.

OVER

---

## 2026-05-06T10:18:00Z - claude - challenge

I agree with tenant-scoped claims, but middleware alone is insufficient.
We should enforce tenant constraints at repository/query level as well.

OVER

---

## Decision: accepted

Use tenant-scoped JWT claims, tenant resolver middleware, and repository-level tenant filtering.

Rationale:
- Middleware provides request context.
- Repository filtering reduces blast radius.
- Tests must cover cross-tenant access attempts.
```

### Debate lifecycle

A debate goes through defined states:

```
open -> active -> accepted -> promoted
                 -> blocked -> needs-human
                 -> needs-context -> active
                 -> abandoned
```

A debate stops when agents agree, disagree clearly, lack context, hit the turn limit, or a human intervenes.

## CLI reference

| Command | Description |
|---------|-------------|
| `walki init` | Initialize `.walki/` workspace |
| `walki agent add <id> --role <role>` | Register an agent |
| `walki debate <id> "question"` | Create a debate channel |
| `walki say <agent> <channel> "message"` | Append a message to a channel |
| `walki read <channel>` | Read channel messages |
| `walki status [channel]` | Show workspace or channel status |
| `walki summarize <channel>` | Generate structured summary |
| `walki close <channel> --status <status>` | Close a debate |
| `walki promote <channel> --to sdd-ai` | Promote decision to sdd_ai |
| `walki doctor` | Validate workspace integrity |
| `walki rules add <name>` | Create a new rule file |
| `walki export <channel> --format json` | Export debate |

## Key principles

- **Local-first**: No server required. Everything lives in your repo.
- **Markdown-first**: Humans and agents can read debates without special tools.
- **Append-only**: Agents add messages, never rewrite history.
- **Git-native**: Debates are diffable, reviewable in PRs.
- **Human-mediated**: Agents propose, humans decide.
- **Agent-agnostic**: Works with any agent that can read and write files.

## Custom instructions

Walki loads instructions in order of specificity:

1. Walki protocol defaults
2. Global user instructions (`~/.walki/instructions.md`)
3. Project instructions (`.walki/instructions.md`)
4. Domain rules (`.walki/rules/*.md`)
5. Channel-specific instructions
6. Agent role
7. User's current prompt

Create rules for your project:

```bash
walki rules add security
walki rules add code-style
walki rules add testing
```

## Integration with sdd_ai

When `sdd-ai/` exists in your repo, Walki can promote decisions to canonical architecture and specs:

```bash
walki promote auth --to sdd-ai
```

This creates files under `sdd-ai/changes/` and updates `sdd-ai/architecture/` and `sdd-ai/specs/`.

The boundary stays clear:

```
Walki debates. sdd_ai canonizes. flg executes.
```

## Architecture

Walki is a Dart CLI. Core modules:

- **Storage**: Read/write Markdown, manage workspace structure, handle locks
- **ChannelParser**: Parse Markdown channels, extract metadata, messages, decisions
- **InstructionLoader**: Load instructions hierarchically, expand globs, deduplicate
- **PermissionEngine**: Validate actions against protocol permissions
- **SddAiAdapter**: Detect sdd_ai, create change folders, promote decisions
- **MCP (future)**: Expose commands as MCP tools for agent-native usage

## Development

```bash
# Install dependencies
dart pub get

# Run tests
dart test

# Run linter
dart analyze

# Run locally
dart run bin/walki.dart init --agents codex,claude
```

## Roadmap

| Phase | Scope | Status |
|-------|-------|--------|
| 0 | Spike: validate protocol with Markdown files | Planned |
| 1 | CLI MVP: init, agent, debate, say, read, status, doctor | In progress |
| 2 | sdd_ai integration: debate, promote, change folders | Planned |
| 3 | MCP server: tools, permission enforcement | Planned |
| 4 | Skills/prompt packs for agents | Planned |
| 5 | Advanced UX: watch mode, TUI, search, semantic summaries | Planned |

## License

MIT