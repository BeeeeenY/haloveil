#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h:h}"
TASK_BUNDLE="${1:-$TASK_ROOT/build/HaloVeil.saver}"
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
"$TASK_APP/Contents/MacOS/QA" "$TASK_BUNDLE" "$TASK_REPORT"
python3 - "$TASK_REPORT" <<'PY'
from pathlib import Path
import json,sys,os,datetime,math
report_path=Path(sys.argv[1])
report=json.loads(report_path.read_text())
expected_path=os.environ.get('HALOVEIL_TEST_EXPECTED_CONFIG')
expected=json.loads(Path(expected_path).read_text()) if expected_path else None
def threshold(name):
    value=os.environ.get(name)
    if value is None:return None
    result=float(value)
    if not math.isfinite(result) or result<=0:raise SystemExit(name+' must be a positive finite number')
    return result
minimum_fps=threshold('HALOVEIL_TEST_MIN_FPS')
maximum_gap=threshold('HALOVEIL_TEST_MAX_GAP_MS')
gated=minimum_fps is not None or maximum_gap is not None
expected_cycles=int(os.environ.get('HALOVEIL_TEST_CYCLES','3'))
functional_passed=len(report['cycles'])==expected_cycles and report['requestedCycles']==expected_cycles
pacing_passed=True
print(report.get('note','Draw submission samples; not physical display presentation FPS.'))
print('Pacing gate:', {'minimumDrawCallbackFPS':minimum_fps,'maximumGapMS':maximum_gap} if gated else 'NOT REQUESTED (set HALOVEIL_TEST_MIN_FPS and/or HALOVEIL_TEST_MAX_GAP_MS)')
for cycle in report['cycles']:
    state=cycle['samples'][-1]['state']
    trace=(cycle.get('probe') or {}).get('frames',[])
    correct=state['layoutBuilds']==1 and state['warmupFrames']>=37 and not state['errors']
    if expected is not None:
        config_matches=all(sample['state'].get('config')==expected for sample in cycle['samples'])
        correct=correct and config_matches
        print('Cycle',cycle['cycle'],'exact configuration:', 'PASS' if config_matches else 'FAIL', '('+str(len(expected))+' values)')
        if not config_matches:
            actual=next(sample['state'].get('config') for sample in cycle['samples'] if sample['state'].get('config')!=expected)
            print('Expected configuration:',expected,'Actual:',actual)
    if os.environ.get('HALOVEIL_TEST_AGENT_STATUS'):
        fixture=json.loads(Path(os.environ['HALOVEIL_TEST_AGENT_STATUS']).read_text())
        agent=cycle['samples'][-1]['agent']
        correct=correct and agent['badge']=='SYNCED'
        count=fixture['fullReset']['availableCount']
        if count is not None: correct=correct and agent['count']==str(count)+' AVAILABLE'
        expiry=fixture['fullReset']['expiresAt']
        if expiry is not None:
            expected_expiry=datetime.datetime.fromtimestamp(expiry).strftime('%Y-%m-%d %H:%M')
            correct=correct and agent['expiry']=='NEXT KNOWN EXPIRY '+expected_expiry
    functional_passed=functional_passed and correct
    cycle['functionalPassed']=correct
    print('Cycle',cycle['cycle'],'functional checks:', 'PASS' if correct else 'FAIL',
          'prepare',round(cycle['firstFrameMS']),'ms; layouts',state['layoutBuilds'],
          'warmup frames',state['warmupFrames'],'geometry',cycle.get('geometry',{}))
    bins=[]
    for start,end in [(0,1),(1,3),(3,5),(5,10)]:
        frames=[frame for frame in trace if start*1000<=frame['at']<end*1000]
        gaps=sorted(frame['gap'] for frame in frames if frame['gap']>0)
        fps=len(frames)/(end-start)
        p95=gaps[min(len(gaps)-1,math.ceil(len(gaps)*.95)-1)] if gaps else None
        max_gap=max(gaps) if gaps else None
        over33=sum(gap>33 for gap in gaps)/len(gaps) if gaps else None
        covered=bool(trace) and trace[-1]['at']>=end*1000
        passed=covered and bool(gaps) and (minimum_fps is None or fps>=minimum_fps) and (maximum_gap is None or max_gap<=maximum_gap)
        if gated:pacing_passed=pacing_passed and passed
        row={'startSeconds':start,'endSeconds':end,'drawCallbackFPS':fps,'gapP95MS':p95,
             'maxGapMS':max_gap,'over33MSFraction':over33,'covered':covered,'gatePassed':passed if gated else None}
        bins.append(row)
        print(' ',str(start)+'–'+str(end)+'s:',round(fps,1),'draw callbacks/s;',
              'gap P95',round(p95,1) if p95 is not None else 'n/a','ms;',
              'max',round(max_gap,1) if max_gap is not None else 'n/a','ms;',
              '>33ms',str(round(over33*100,1))+'%' if over33 is not None else 'n/a',
              ('gate PASS' if passed else 'gate FAIL') if gated else '(not gated)')
    cycle['pacingBins']=bins
if report.get('statusChecks'):functional_passed=functional_passed and all(report['statusChecks'].values())
panel_checks=report.get('panelChecks',{})
functional_passed=functional_passed and bool(panel_checks) and all(value is True for value in panel_checks.values())
report['functionalPassed']=functional_passed
report['pacingGate']={'minimumDrawCallbackFPS':minimum_fps,'maximumGapMS':maximum_gap}
report['pacingPassed']=pacing_passed if gated else None
report_path.write_text(json.dumps(report,indent=2)+'\n')
print('Functional checks:', 'PASS' if functional_passed else 'FAIL')
print('Panel layout and demo-agent checks:',panel_checks)
print('Draw-callback pacing:', ('PASS' if pacing_passed else 'FAIL') if gated else 'NOT GATED; functional checks do not establish smooth playback')
if report.get('statusChecks'): print('Account status UI checks:',report['statusChecks'])
print('Report:',sys.argv[1])
raise SystemExit(0 if functional_passed and (not gated or pacing_passed) else 1)
PY
