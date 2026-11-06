#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h:h}"
mkdir -p "$TASK_ROOT/.local/tests"
python3 "$TASK_ROOT/tests/test_codex_status.py"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Werror -framework Foundation \
  "$TASK_ROOT/tests/AgentStatusQA.m" -o "$TASK_ROOT/.local/tests/AgentStatusQA"
"$TASK_ROOT/.local/tests/AgentStatusQA"
