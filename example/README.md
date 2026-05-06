# Walki Example

This example shows the smallest useful Walki workflow: initialize a project,
open a debate, let two agents challenge each other, summarize the result, and
close the channel.

## Basic debate

```bash
dart pub global activate walki

mkdir walki-demo
cd walki-demo

walki init --agents codex,claude
walki debate auth "How should we implement auth?" --rules security,testing
walki say codex auth "I propose JWT plus refresh tokens." --kind proposal
walki say claude auth "Challenge: define token rotation and revocation." --kind challenge
walki summarize auth
walki close auth --status accepted
```

You can also run the script:

```bash
./example/basic_debate.sh
```

## MCP config

`mcp_opencode_config.json` contains a minimal MCP server configuration for
opencode-compatible clients.
