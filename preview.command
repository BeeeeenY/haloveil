#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h}"
open "$TASK_ROOT/web/index.html"
