# Development

## Prerequisites

Use macOS with Apple Command Line Tools or Xcode, plus Python 3. The build uses `clang`, `lipo`, `sips`, and `codesign` from the local developer tools and system. There is no npm install, web build framework, external font, server, or API key.

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
docs/            Installation, development, testing, licensing, release notes
downloads/       Installable ZIP and SHA-256 checksums, intentionally versioned
build/           Generated signed bundles and manifest; ignored by Git
.local/          Private test apps, reports, and diagnostic logs; ignored by Git
```

## Make changes

Edit the source files in `web/` and `source/`. `version.json` is the version/build source of truth. `build.command` generates `web/version.js`, `source/Version.h`, and `build/manifest.json`, compiles arm64 and x86_64 binaries, bundles the resources and notices, and signs both products locally.

Do not edit resources inside an already signed `.saver`. Rebuild the whole package instead. The native host verifies version metadata and web-resource hashes to reject mixed builds.

The build recreates only `build/HaloVeil.saver` and `build/HaloVeil Preview.app`; keep hand-written source outside generated product directories. Open the preview app for manual visual checks without installing it.

## Runtime behavior

The native host supplies the animation clock and allows only one outstanding JavaScript frame operation. Startup prepares 37 frames before starting visible playback, then removes a short fade overlay. A geometry cache prevents the initial ResizeObserver callback from rebuilding an unchanged scene during playback.

The main canvas is capped at 800,000 pixels. UI text uses normal web layout. The animation keeps the configured particle count, batches compatible paths, spreads panel updates, and compacts retiring burst particles in one pass.

Each display has an in-process owner and a kernel file lease. The saver stops and unloads the web view on normal stop, view detachment, hidden/demoted windows, system stop notifications, and sleep. Callback generation checks prevent late navigation or warmup callbacks from restarting an old session. The last session can terminate the dedicated legacy screen saver extension; it never terminates the login/password process or the preview app.

## Agent status

The demo is not connected to an agent. The page's content policy blocks network connections; the native host does not yet read external status data. Adding a `fetch()` alone does not implement integration.

A future integration should keep state outside the signed application bundle, use an explicitly configured data location or read-only loopback endpoint, and pass validated state through a native bridge. File permissions and networking must be checked in the actual macOS saver host. Render frequency and state-update frequency should remain separate.

## Test and package

```sh
./tests/run.command
./tests/startup.command
python3 tools/package.py
```

Tests run native AppKit/WKWebView fixtures in offscreen windows. They do not lock the current desktop. Reports and snapshots stay in `.local/diagnostics/` and must not be committed; copy a reviewed, non-personal screenshot to `assets/preview.png` when refreshing the public preview.

All project paths are relative. The installed bundle locates web resources through its own bundle, so it does not depend on the source checkout's location.
