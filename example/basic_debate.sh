#!/usr/bin/env bash
set -euo pipefail

dart pub global activate walki

rm -rf walki-demo
mkdir walki-demo
cd walki-demo

walki init --agents codex,claude
walki debate auth "How should we implement auth?" --rules security,testing
walki say codex auth "I propose JWT plus refresh tokens." --kind proposal
walki say claude auth "Challenge: define token rotation and revocation." --kind challenge
walki summarize auth
walki close auth --status accepted
