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
- `lib/src/agents/` - Agent model
- `lib/src/decisions/` - Decision model
- `lib/src/tasks/` - Task model

## Commands

```bash
dart run bin/walki.dart init --agents codex,claude
dart run bin/walki.dart debate <id> "question"
dart run bin/walki.dart say <agent> <channel> "message" --kind proposal
dart run bin/walki.dart read <channel>
dart run bin/walki.dart status [channel]
dart run bin/walki.dart close <channel> --status accepted
dart run bin/walki.dart summarize <channel>
dart run bin/walki.dart doctor
dart run bin/walki.dart promote <channel> --to sdd-ai
dart run bin/walki.dart export <channel> --format json
dart run bin/walki.dart agent add <name> --role <role>
dart run bin/walki.dart rules add <name>
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