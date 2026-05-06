# 0.2.1

- Add PATH setup instructions to README for `dart pub global activate` users
- Remove compiled binaries and coverage files from package
- Add `.pubignore` to exclude non-essential files from pub.dev

# 0.2.0

- **MCP server**: Walki is now usable as an MCP tool by any MCP-compatible agent (opencode, Claude Desktop, etc.)
  - `walki_open_channel` - Create a new debate channel
  - `walki_read_channel` - Read channel messages
  - `walki_post_message` - Append a message to a channel
  - `walki_propose_decision` - Propose a decision in a channel
  - `walki_get_status` - Get workspace or channel status
  - `walki_close_channel` - Close a debate
  - `walki_promote_to_sdd` - Promote a decision to sdd-ai
- Permission enforcement via MCP: validates agent roles, closed channels, and turn limits
- STDIO and HTTP transport support for MCP server
- New binary: `walki-mcp` for running as an MCP server

# 0.1.1

- Fix `ChannelStatus.toYamlValue()` to properly convert camelCase to kebab-case (`needsHuman` → `needs-human`)
- Fix `PermissionEngine.validateMessage` to use agent ID instead of role for message counting
- Add comprehensive test suite: 131 tests covering all core modules
- Update README with agent roles, full CLI reference, and usage examples

# 0.1.0

Initial release of Walki - local coordination protocol for AI agents.

## Features

- **CLI**: 12 commands for managing agent debates
  - `walki init` - Initialize `.walki/` workspace
  - `walki agent add/list` - Manage agent identities and roles
  - `walki debate` - Create debate channels in Markdown
  - `walki say` - Append messages to channels
  - `walki read` - Read channel contents
  - `walki status` - Show workspace or channel status
  - `walki summarize` - Generate structured summary
  - `walki close` - Close a debate with a status
  - `walki promote` - Promote decisions to sdd-ai
  - `walki doctor` - Validate workspace integrity
  - `walki rules add/list` - Manage project rules
  - `walki export` - Export debates as Markdown or JSON

- **Markdown-first channels**: Debates are versionable, diffable Markdown files
- **Protocol permissions**: Role-based validation for agents (implementer, reviewer, owner)
- **Hierarchical instructions**: Load rules from global, project, domain, and channel levels
- **Channel parser/formatter**: Full round-trip Markdown parsing and generation
- **sdd-ai integration**: Detect sdd-ai directories and promote decisions
- **Agent prompts**: Auto-generated prompts per agent role for Codex, Claude, etc.