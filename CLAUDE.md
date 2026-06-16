# Walki

Local coordination protocol for AI agents. Dart CLI tool.

## Architecture

- Language: Dart 3.5+
- CLI framework: `package:args` + `mason_logger`
- Storage: Markdown-first, YAML for generated state
- Config: `.walki/config.yaml`

## Key Modules

- `lib/src/cli/commands/` - CLI commands (init, agent, debate, say, read, status, close, promote, doctor, rules, export)
- `lib/src/config/` - WalkiConfig, AgentConfig
- `lib/src/channels/` - Channel model, ChannelParser, ChannelFormatter
- `lib/src/storage/` - Workspace initialization and management
- `lib/src/rules/` - InstructionLoader
- `lib/src/validation/` - PermissionEngine
- `lib/src/sdd_ai/` - SddAiAdapter
- `lib/src/agents/` - Agent model, prompt generation, and supported-agent registry
- `lib/src/decisions/` - Decision model
- `lib/src/tasks/` - Task model
- `lib/src/mcp/` - MCP server tools for channel debate, promotion, workspace init, agent/rule management, summaries, export, and doctor checks

## Commands

```bash
# CLI
dart run bin/walki.dart init --agents codex,claude
dart run bin/walki.dart init --non-interactive
dart run bin/walki.dart debate <id> "question"
dart run bin/walki.dart say <agent> <channel> "message" --kind proposal
dart run bin/walki.dart propose_decision <channel> "summary" --agent <agent>
dart run bin/walki.dart read <channel>
dart run bin/walki.dart status [channel]
dart run bin/walki.dart close <channel> --status accepted --agent human
dart run bin/walki.dart summarize <channel>
dart run bin/walki.dart doctor
dart run bin/walki.dart promote <channel> --to sdd-ai --agent human
dart run bin/walki.dart export <channel> --format json
dart run bin/walki.dart agent add/show/edit/tune/remove <name>
dart run bin/walki.dart rules add/show/edit/remove <name>
dart run bin/walki.dart rules draft
dart run bin/walki.dart rules apply <channel>
dart run bin/walki.dart mcp init --agent claude

# MCP server (STDIO)
dart run bin/walki_mcp.dart
```

## Testing

```bash
dart test
dart analyze
```

## Key Principles

- Markdown is source of truth, YAML/JSON only for generated state
- Append-only: agents never rewrite history
- Every message ends with OVER marker
- Human-mediated by default: agents propose, humans decide
- Local-first, git-native, agent-agnostic

## Build

```bash
dart compile exe bin/walki.dart -o walki
```
