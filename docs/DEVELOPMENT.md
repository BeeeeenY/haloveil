# Development

## Prerequisites

In this project, “Preview” means `build/HaloVeil Preview.app`, the native windowed app with the status-file bridge. After source changes, update that app with `./tools/build-preview.command`, then reopen it. This builds only Preview and its private renderer; it does not build, install, or replace a standalone `.saver`, generate a release ZIP, or start background account collection.

For a separate browser check, open `web/index.html` or double-click `preview.command`. That command opens HTML directly and needs no build tools, but does not provide the native status-file bridge. Do not generate a new `.saver` or release ZIP until packaging is explicitly requested.

For native/release work, use macOS with Apple Command Line Tools or Xcode, plus Python 3. The build uses `clang`, `lipo`, `sips`, and `codesign` from the local developer tools and system. There is no npm install, web build framework, external font, server, or API key.

```sh
xcode-select --install
python3 --version
./build.command
```

## Layout

```text
source/          Native ScreenSaverView host, preview app, generated version header
web/             Bundled HTML, styles, Canvas animation, runtime, release metadata
assets/          Public preview image used in README and saver thumbnails
tests/           Native startup and lifecycle integration tests
tools/           Release packaging and local diagnostic export
preview.command  Open web/index.html without a build or background service
docs/            Installation, development, testing, licensing, release notes
downloads/       Installable ZIP and SHA-256 checksums, intentionally versioned
build/           Generated signed bundles and manifest; ignored by Git
.local/          Private test apps, reports, and diagnostic logs; ignored by Git
oldVersionBackup/ Protected local archive; ignored by Git, never modified
```

## Make changes

Edit the source files in `web/` and `source/`. `version.json` is the version/build source of truth. `build.command` generates `web/version.js`, `source/Version.h`, and `build/manifest.json`, compiles arm64 and x86_64 binaries, bundles the resources and notices, and signs both products locally.

For ordinary Preview changes, use `./tools/build-preview.command` instead. It snapshots the current web/native source, generates matching integrity metadata privately, compiles an Apple Silicon + Intel renderer inside the app, verifies the signature, then atomically replaces only `build/HaloVeil Preview.app`. Source release metadata and existing saver/download files stay untouched. Close and reopen an already running Preview to load the new copy.

Do not edit resources inside an already signed `.saver`. Rebuild the whole package instead. The native host verifies version metadata and web-resource hashes to reject mixed builds.

The build recreates only `build/HaloVeil.saver` and `build/HaloVeil Preview.app`; keep hand-written source outside generated product directories. Open the preview app for manual visual checks without installing it.

## Runtime behavior

### Preview visual profile

The development `build/HaloVeil Preview.app` and `web/index.html` default to the
`original` visual profile: device pixel ratio capped at `2`, no total canvas
pixel cap, and ring textures at `2.4`. The scene uses upstream preset `A`,
which matches the complete configuration exported from the user's running
original page. This includes `runnerCount: 45` and the preset's full art and
effect settings. Motion is `tempo: 1`, `ringSpeed: 1`, `ringPause: 1`, and
`camZoom: 1` (configured as `cameraIntensity`). These four values are shared
by all quality profiles in `web/settings.js`. Quality selection controls
rendering quality and frame targets; it does not change motion speed.
`web/animation.js` contains a single `ORIGINAL_CONFIG` for this 45-runner
scene. Unused 336/788-runner presets and their fallback paths are removed.
In a browser it draws on every animation frame instead of filtering callbacks to
60 FPS. The native Preview targets 60 FPS. Small canvases update every frame.
Individual runner strokes preserve upstream overlap brightness, color order,
and WebKit's per-stroke antialiasing. Canvas sizes are not reduced
automatically in this profile.
Beat-invalidated ring tiles also refresh as soon as they are visible, matching
upstream; the balanced profile retains its one-tile-per-frame update budget.

For an explicit comparison, add `?quality=balanced` to the file URL to use the
previous budget settings. `?quality=original` selects the fidelity profile.
The existing camera shots/interpolation, lifecycle cleanup, and duplicate-size
rebuild guard are retained. Upstream localStorage presets can differ from the
baked file defaults, so scene configuration is matched against the user's
exported runtime values. All quality profiles use the same confirmed preset
`A` configuration, including its 45 runners. Ring motion is random: equal
settings do not produce synchronized turns in two separately opened windows.

The Preview-only build marks its private renderer with `HaloVeilOriginalVisuals`.
It retains the single native 60 FPS clock, startup preparation, lifecycle cleanup,
and account-status file bridge. Original-quality Preview uses the complete
confirmed preset `A` configuration and full-resolution canvases. A windowed rAF
experiment was slower on the test Mac, so it is not used by the native Preview.
Release 1.1.0 screen savers and their Preview app both use the approved
`original` visual profile and the native clock. The saver bundle explicitly
sets `HaloVeilOriginalVisuals`; `balanced` remains an explicit browser
comparison option rather than the release default.
The main canvas is opaque because every frame paints its entire background;
intermediate buffers remain transparent. Completely empty glow buffers skip
the full-stage blur/composite pass. Motion, density, texture resolution, and
blur radius are unchanged by these drawing optimizations.
Matching the upstream parameters does not guarantee Chrome-equivalent frame
pacing in WKWebView. `getState().fps` is the requested target; `measuredFPS` and
frame gaps describe actual drawing callbacks, not physical presentation times.
Source edits reach the Preview app after `./tools/build-preview.command`; close
and reopen a running copy. `preview.command` opens only HTML and has no native
account-status bridge.

### Native host

The screen saver supplies its native animation clock and allows only one outstanding JavaScript frame operation. Both native paths prepare 37 frames before starting visible playback, then remove a short fade overlay. A geometry cache prevents the initial ResizeObserver callback from rebuilding an unchanged scene during playback.

The optional balanced profile caps its canvas at 800,000 pixels. UI text uses normal web layout. That profile keeps the configured particle count, batches compatible paths, spreads panel updates, and compacts retiring burst particles in one pass. Release 1.1.0 uses the original-quality profile shared with the approved Preview.

Each display has an in-process owner and a kernel file lease. The saver stops and unloads the web view on normal stop, view detachment, hidden/demoted windows, system stop notifications, and sleep. Callback generation checks prevent late navigation or warmup callbacks from restarting an old session. The last session can terminate the dedicated legacy screen saver extension; it never terminates the login/password process or the preview app.

## Agent status

Source builds include an optional Codex account usage panel. A separate collector reads `account/rateLimits/read` and atomically publishes a private snapshot to `~/Library/Application Support/HaloVeil/agent-status.json`. The native host validates it and passes display fields through a structured bridge, without opening network access in the web page. Other animation panels and counters remain demo data; task progress is not connected.

See [Codex status setup, meanings and host-access boundaries](CODEX-STATUS.md). File permissions must still be verified in the actual macOS saver host. Account collection (1 hour), file reads (5 seconds), and rendering remain independent.

## Test and package

Test the current Preview renderer without rebuilding a screen saver:

```sh
./tests/startup.command "$PWD/build/HaloVeil Preview.app/Contents/PlugIns/HaloVeilRenderer.bundle"
./tests/run.command "$PWD/build/HaloVeil Preview.app/Contents/PlugIns/HaloVeilRenderer.bundle"
```

Set `HALOVEIL_TEST_VISIBLE=1` for the startup check when evaluating rAF pacing;
WebKit can reduce callbacks for a window positioned outside the visible screen.
Reported frame counts measure draw submissions, not physical presentation.

The startup fixture uses Preview's actual default window dimensions and samples
10 seconds of playback. It reports 0–1, 1–3, 3–5, and 5–10 second intervals.
`HALOVEIL_TEST_EXPECTED_CONFIG=tests/fixtures/original-config.json` checks every
scene parameter against the user's full upstream export. Optional
`HALOVEIL_TEST_MIN_FPS=55` and `HALOVEIL_TEST_MAX_GAP_MS=50` enable explicit draw
callback pacing checks, reported separately from functional checks. Set
`HALOVEIL_TEST_CYCLES=1` and run the command in three separate processes for
three cold starts; the default runs three view sessions in one process.

For an explicitly requested screen saver/release build:

```sh
./tests/run.command
./tests/startup.command
python3 tools/package.py
```

Tests run native AppKit/WKWebView fixtures in offscreen windows. They do not lock the current desktop. Reports and snapshots stay in `.local/diagnostics/` and must not be committed; copy a reviewed, non-personal screenshot to `assets/preview.png` when refreshing the public preview.

All project paths are relative. The installed bundle locates web resources through its own bundle, so it does not depend on the source checkout's location.
