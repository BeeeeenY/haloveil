#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h}"
TASK_BUILD="$(mktemp -d "${TMPDIR:-/tmp/}haloveil-build.XXXXXX")"
trap 'rm -rf "$TASK_BUILD"' EXIT
TASK_SAVER="$TASK_ROOT/build/HaloVeil.saver"
TASK_PREVIEW="$TASK_ROOT/build/HaloVeil Preview.app"
python3 - "$TASK_ROOT" <<'PYVERSION'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1])
release=json.loads((root/'version.json').read_text())
web=root/'web'
base=hashlib.sha256()
for f in sorted(web.iterdir()):
    if not f.is_file() or f.name=='version.js':continue
    base.update(f.name.encode()+b'\0'+f.read_bytes())
release['assetDigest']=base.hexdigest()
(web/'version.js').write_text('window.HALOVEIL_RELEASE=Object.freeze('+json.dumps(release,separators=(',',':'))+');\n')
manifest={'web/'+f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(web.iterdir()) if f.is_file()}
data=json.dumps(manifest,sort_keys=True,separators=(',',':')).encode()
(root/'build').mkdir(exist_ok=True)
(root/'build/manifest.json').write_bytes(data)
header='#define HALOVEIL_VERSION @"'+release['version']+'"\n#define HALOVEIL_BUILD '+str(release['build'])+'\n#define HALOVEIL_ASSET_DIGEST @"'+release['assetDigest']+'"\n#define HALOVEIL_MANIFEST_SHA @"'+hashlib.sha256(data).hexdigest()+'"\n'
(root/'source/Version.h').write_text(header)
PYVERSION
# These two paths contain generated products only. Rebuild them from scratch
# so renamed resources and executables cannot survive an incremental copy.
rm -rf "$TASK_SAVER" "$TASK_PREVIEW"
mkdir -p "$TASK_SAVER/Contents/MacOS" "$TASK_SAVER/Contents/Resources"
mkdir -p "$TASK_PREVIEW/Contents/MacOS" "$TASK_PREVIEW/Contents/PlugIns"
for TASK_ARCH in arm64 x86_64; do
  xcrun clang -arch "$TASK_ARCH" -mmacosx-version-min=12.0 -fobjc-arc -O2 \
    -Wall -Wextra -Wno-unused-parameter -Werror -bundle \
    -framework Cocoa -framework ScreenSaver -framework WebKit \
    "$TASK_ROOT/source/HaloVeilView.m" -o "$TASK_BUILD/saver-$TASK_ARCH"
  xcrun clang -arch "$TASK_ARCH" -mmacosx-version-min=12.0 -fobjc-arc -O2 \
    -Wall -Wextra -Wno-unused-parameter -Werror \
    -framework Cocoa -framework ScreenSaver \
    "$TASK_ROOT/source/Preview.m" -o "$TASK_BUILD/preview-$TASK_ARCH"
done
lipo -create "$TASK_BUILD/saver-arm64" "$TASK_BUILD/saver-x86_64" \
  -output "$TASK_SAVER/Contents/MacOS/HaloVeil"
lipo -create "$TASK_BUILD/preview-arm64" "$TASK_BUILD/preview-x86_64" \
  -output "$TASK_PREVIEW/Contents/MacOS/HaloVeilPreview"
ditto "$TASK_ROOT/web" "$TASK_SAVER/Contents/Resources/web"
cp "$TASK_ROOT/LICENSE" "$TASK_SAVER/Contents/Resources/LICENSE"
cp "$TASK_ROOT/NOTICE" "$TASK_SAVER/Contents/Resources/NOTICE"
cp "$TASK_ROOT/build/manifest.json" "$TASK_SAVER/Contents/Resources/manifest.json"
sips -Z 960 "$TASK_ROOT/assets/preview.png" \
  --out "$TASK_SAVER/Contents/Resources/thumbnail.png" >/dev/null
python3 - "$TASK_SAVER" "$TASK_PREVIEW" "$TASK_ROOT/version.json" <<'PY'
import plistlib
import json
import sys
from pathlib import Path
release=json.loads(Path(sys.argv[3]).read_text())
common = {'CFBundleDevelopmentRegion':'en','CFBundleInfoDictionaryVersion':'6.0',
          'CFBundleShortVersionString':release['version'],'CFBundleVersion':str(release['build']),
          'LSMinimumSystemVersion':'12.0',
          'NSHumanReadableCopyright':'Modified from HALOFLUX by Ryder191 (RYDER CODE / Ms MAIKEBAIs CAT). https://github.com/Ryder191/haloflux — Noncommercial use only.'}
saver = dict(common, CFBundleIdentifier='dev.haloveil.screensaver',
             CFBundleName='HaloVeil', CFBundleDisplayName='HaloVeil',
             CFBundleExecutable='HaloVeil', CFBundlePackageType='BNDL',
             NSPrincipalClass='HaloVeilView', SSENeedsAnimationTimer=True)
preview = dict(common, CFBundleIdentifier='dev.haloveil.preview',
               CFBundleName='HaloVeil Preview', CFBundleDisplayName='HaloVeil Preview',
               CFBundleExecutable='HaloVeilPreview', CFBundlePackageType='APPL',
               NSPrincipalClass='NSApplication', NSHighResolutionCapable=True)
for root, data in [(sys.argv[1], saver), (sys.argv[2], preview)]:
    with (Path(root)/'Contents/Info.plist').open('wb') as file:
        plistlib.dump(data, file)
PY
codesign --force --sign - --timestamp=none "$TASK_SAVER"
ditto "$TASK_SAVER" "$TASK_PREVIEW/Contents/PlugIns/HaloVeil.saver"
codesign --force --sign - --timestamp=none "$TASK_PREVIEW"
codesign --verify --deep --strict "$TASK_SAVER"
codesign --verify --deep --strict "$TASK_PREVIEW"
print 'Built HaloVeil.saver and HaloVeil Preview.app (Apple Silicon + Intel).'
