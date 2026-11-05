#!/bin/zsh
set -eu
TASK_ROOT="${0:A:h:h}"
TASK_DIAG="$TASK_ROOT/.local/diagnostics"
mkdir -p "$TASK_DIAG"
TASK_REPORT="$TASK_DIAG/screensaver-$(date +%Y%m%d-%H%M%S).json"
/usr/bin/log show --last 10m --style json \
  --predicate 'subsystem == "dev.haloveil.screensaver" AND (process BEGINSWITH "legacyScreenSaver" OR process == "ScreenSaverEngine")' \
  > "$TASK_REPORT" 2>&1 || true
print "诊断文件已保存：$TASK_REPORT"
print '这些是本机性能日志，不会上传。请先使用新版屏保至少 15 秒，退出后再导出。'
