#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h:h}"
TASK_BUNDLE="${1:-$TASK_ROOT/build/HaloVeil.saver}"
TASK_APP="$TASK_ROOT/.local/tests/lifecycle/LifecycleQA.app"
TASK_REPORT="$TASK_ROOT/.local/diagnostics/lifecycle-regression-repro-$(date +%Y%m%d-%H%M%S).json"
mkdir -p "$TASK_APP/Contents/MacOS" "$TASK_ROOT/.local/diagnostics"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -Werror -framework Foundation \
  "$TASK_ROOT/tests/LeaseProbe.m" -o "$TASK_APP/Contents/MacOS/LeaseProbe"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -Werror -framework Cocoa -framework ScreenSaver -framework WebKit \
  "$TASK_ROOT/tests/LifecycleQA.m" -o "$TASK_APP/Contents/MacOS/QA"
python3 - "$TASK_ROOT" "$TASK_APP" "$TASK_REPORT" "$TASK_BUNDLE" <<'PY'
from pathlib import Path
import sys,plistlib
root,app,report,bundle=map(Path,sys.argv[1:])
info={'CFBundleIdentifier':'dev.haloveil.lifecycleqa','CFBundleName':'HALOVEIL LifecycleQA','CFBundleExecutable':'QA','CFBundlePackageType':'APPL','NSHighResolutionCapable':True,'SaverPath':str(bundle.resolve()),'ReportPath':str(report)}
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
PY
codesign --force --sign - --timestamp=none "$TASK_APP"
HALOVEIL_TEST_HEADLESS=1 "$TASK_APP/Contents/MacOS/QA"
python3 - "$TASK_REPORT" <<'PY'
from pathlib import Path
import sys,json
path=Path(sys.argv[1]);report=json.loads(path.read_text())
print('PASS' if report.get('pass') else 'FAIL',path)
for cycle in report.get('cycles',[]): print(cycle['cycle'],round(cycle['fps'],2),'FPS')
raise SystemExit(0 if report.get('pass') else 1)
PY
