#!/bin/zsh
set -euo pipefail
TASK_ROOT="${0:A:h:h}"
mkdir -p "$TASK_ROOT/build"
TASK_STAGE="$(mktemp -d "$TASK_ROOT/build/.preview-build.XXXXXX")"
trap 'rm -rf "$TASK_STAGE"' EXIT
TASK_PREVIEW="$TASK_STAGE/HaloVeil Preview.app"
TASK_RENDERER="$TASK_PREVIEW/Contents/PlugIns/HaloVeilRenderer.bundle"
mkdir -p "$TASK_RENDERER/Contents/MacOS" "$TASK_RENDERER/Contents/Resources" \
  "$TASK_PREVIEW/Contents/MacOS" "$TASK_STAGE/source"

# Snapshot source and generate integrity metadata privately. Preview development
# must not rewrite the source release metadata or create a standalone .saver.
cp "$TASK_ROOT/source/HaloVeilView.m" "$TASK_ROOT/source/HaloVeilView.h" \
  "$TASK_ROOT/source/AgentStatus.h" "$TASK_STAGE/source/"
ditto "$TASK_ROOT/web" "$TASK_RENDERER/Contents/Resources/web"
python3 - "$TASK_ROOT" "$TASK_STAGE" "$TASK_RENDERER" "$TASK_PREVIEW" <<'PY'
from pathlib import Path
import hashlib
import json
import plistlib
import sys

root, stage, renderer, preview = map(Path, sys.argv[1:])
release = json.loads((root / 'version.json').read_text())
web = renderer / 'Contents/Resources/web'
digest = hashlib.sha256()
for file in sorted(web.iterdir()):
    if file.is_file() and file.name not in {'version.js', '.DS_Store'} and not file.name.startswith('._'):
        digest.update(file.name.encode() + b'\0' + file.read_bytes())
release['assetDigest'] = digest.hexdigest()
(web / 'version.js').write_text(
    'window.HALOVEIL_RELEASE=Object.freeze(' +
    json.dumps(release, separators=(',', ':')) + ');\n')
manifest = {'web/' + file.name: hashlib.sha256(file.read_bytes()).hexdigest()
            for file in sorted(web.iterdir()) if file.is_file()
            and file.name != '.DS_Store' and not file.name.startswith('._')}
data = json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()
(renderer / 'Contents/Resources/manifest.json').write_bytes(data)
(stage / 'source/Version.h').write_text(
    '#define HALOVEIL_VERSION @"' + release['version'] + '"\n' +
    '#define HALOVEIL_BUILD ' + str(release['build']) + '\n' +
    '#define HALOVEIL_ASSET_DIGEST @"' + release['assetDigest'] + '"\n' +
    '#define HALOVEIL_MANIFEST_SHA @"' + hashlib.sha256(data).hexdigest() + '"\n')
common = {
    'CFBundleDevelopmentRegion': 'en',
    'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleShortVersionString': release['version'],
    'CFBundleVersion': str(release['build']),
    'LSMinimumSystemVersion': '12.0',
    'NSHumanReadableCopyright':
        'Modified from HALOFLUX by Ryder191 (RYDER CODE / Ms MAIKEBAIs CAT). '
        'https://github.com/Ryder191/haloflux — Noncommercial use only.',
}
renderer_info = dict(common, CFBundleIdentifier='dev.haloveil.preview.renderer',
    CFBundleName='HaloVeil Preview Renderer', CFBundleExecutable='HaloVeilRenderer',
    CFBundlePackageType='BNDL', NSPrincipalClass='HaloVeilView', SSENeedsAnimationTimer=True,
    HaloVeilOriginalVisuals=True)
preview_info = dict(common, CFBundleIdentifier='dev.haloveil.preview',
    CFBundleName='HaloVeil Preview', CFBundleDisplayName='HaloVeil Preview',
    CFBundleExecutable='HaloVeilPreview', CFBundlePackageType='APPL',
    NSPrincipalClass='NSApplication', NSHighResolutionCapable=True)
for bundle, info in ((renderer, renderer_info), (preview, preview_info)):
    with (bundle / 'Contents/Info.plist').open('wb') as file:
        plistlib.dump(info, file)
PY

for TASK_ARCH in arm64 x86_64; do
  xcrun clang -arch "$TASK_ARCH" -mmacosx-version-min=12.0 -fobjc-arc -O2 \
    -Wall -Wextra -Wno-unused-parameter -Werror -bundle \
    -framework Cocoa -framework ScreenSaver -framework WebKit \
    "$TASK_STAGE/source/HaloVeilView.m" -o "$TASK_STAGE/renderer-$TASK_ARCH"
  xcrun clang -arch "$TASK_ARCH" -mmacosx-version-min=12.0 -fobjc-arc -O2 \
    -Wall -Wextra -Wno-unused-parameter -Werror \
    -framework Cocoa -framework ScreenSaver \
    "$TASK_ROOT/source/Preview.m" -o "$TASK_STAGE/preview-$TASK_ARCH"
done
lipo -create "$TASK_STAGE/renderer-arm64" "$TASK_STAGE/renderer-x86_64" \
  -output "$TASK_RENDERER/Contents/MacOS/HaloVeilRenderer"
lipo -create "$TASK_STAGE/preview-arm64" "$TASK_STAGE/preview-x86_64" \
  -output "$TASK_PREVIEW/Contents/MacOS/HaloVeilPreview"
cp "$TASK_ROOT/LICENSE" "$TASK_ROOT/NOTICE" "$TASK_RENDERER/Contents/Resources/"
sips -Z 960 "$TASK_ROOT/assets/preview.png" \
  --out "$TASK_RENDERER/Contents/Resources/thumbnail.png" >/dev/null
codesign --force --sign - --timestamp=none "$TASK_RENDERER"
codesign --force --sign - --timestamp=none "$TASK_PREVIEW"
codesign --verify --deep --strict "$TASK_PREVIEW"

# Both paths live in build/, so the app replacement is a same-volume atomic
# exchange. The old app moves into TASK_STAGE and is removed by the exit trap.
python3 - "$TASK_PREVIEW" "$TASK_ROOT/build/HaloVeil Preview.app" <<'PY'
from pathlib import Path
import ctypes
import os
import sys

staged, destination = map(Path, sys.argv[1:])
if destination.exists():
    libc = ctypes.CDLL(None, use_errno=True)
    swap = libc.renameatx_np
    swap.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    swap.restype = ctypes.c_int
    if swap(-2, os.fsencode(staged), -2, os.fsencode(destination), 2) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), str(destination))
else:
    staged.rename(destination)
PY
print 'Updated build/HaloVeil Preview.app (Apple Silicon + Intel).'
print 'No standalone screen saver or release ZIP was built or installed.'
