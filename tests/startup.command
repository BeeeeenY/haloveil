#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h:h}"
TASK_APP="$TASK_ROOT/.local/tests/startup/StartupQA.app"
TASK_REPORT="$TASK_ROOT/.local/diagnostics/startup-repro-$(date +%Y%m%d-%H%M%S).json"
mkdir -p "$TASK_APP/Contents/MacOS" "$TASK_ROOT/.local/diagnostics"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -Werror \
  -framework Cocoa -framework ScreenSaver -framework WebKit \
  "$TASK_ROOT/tests/StartupQA.m" -o "$TASK_APP/Contents/MacOS/QA"
python3 - "$TASK_APP" <<'PY'
import plistlib,sys
from pathlib import Path
app=Path(sys.argv[1])
(app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'dev.haloveil.startupqa','CFBundleName':'HALOVEIL StartupQA','CFBundleExecutable':'QA','CFBundlePackageType':'APPL','NSHighResolutionCapable':True}))
PY
codesign --force --sign - --timestamp=none "$TASK_APP"
"$TASK_APP/Contents/MacOS/QA" "$TASK_ROOT/build/HaloVeil.saver" "$TASK_REPORT"
python3 - "$TASK_REPORT" <<'PY'
from pathlib import Path
import json,sys,os,datetime
report=json.loads(Path(sys.argv[1]).read_text())
passed=True
for cycle in report['cycles']:
    state=cycle['samples'][-1]['state']
    trace=[x for x in cycle['probe']['frames'] if x['at']<5000]
    correct=state['layoutBuilds']==1 and state['warmupFrames']>=37 and not state['errors']
    passed=passed and correct
    if os.environ.get('HALOVEIL_TEST_AGENT_STATUS'):
        fixture=json.loads(Path(os.environ['HALOVEIL_TEST_AGENT_STATUS']).read_text())
        agent=cycle['samples'][-1]['agent']
        passed=passed and agent['badge']=='SYNCED'
        count=fixture['fullReset']['availableCount']
        if count is not None: passed=passed and agent['count']==str(count)+' AVAILABLE'
        expiry=fixture['fullReset']['expiresAt']
        if expiry is not None:
            expected=datetime.datetime.fromtimestamp(expiry).strftime('%Y-%m-%d %H:%M')
            passed=passed and agent['expiry']=='NEXT KNOWN EXPIRY '+expected
    print('Cycle',cycle['cycle'],'prepare',round(cycle['firstFrameMS']),'ms; first 5 seconds',round(len(trace)/5,1),'FPS; max gap',round(max(x['gap'] for x in trace),1),'ms; layouts',state['layoutBuilds'],'builds')
print('Startup checks passed' if passed else 'Startup checks failed',sys.argv[1])
print('Offscreen draw submission samples, not physical display presentation FPS.')
if report.get('statusChecks'): print('Account status UI checks:',report['statusChecks'])
raise SystemExit(0 if passed else 1)
PY
