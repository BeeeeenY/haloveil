# Changelog

## 1.1.0 — 2026-11-07 · build 2

- Matched the confirmed original preset A: 45 runners and all 56 scene parameters, checked against `tests/fixtures/original-config.json` across quality profiles.
- Updated the headings to **BEN'S CONTROL ROOM** / **IDEAS IN MOTION**.
- Moved Codex usage to the first panel and restored the demo **12 AGENTS / DISPATCH** in panel 7 (row 2, column 3).
- Included the optional Codex account-status panel and native file bridge in the downloadable saver and Preview app. The collector remains separately opt-in, with hourly background collection available.
- Added a Preview-only build command and expanded startup checks for exact scene configuration, panel layout, demo-agent updates, and separate functional/pacing reports.
- Preserved startup preparation, per-display renderer ownership, exit cleanup, silent playback, and universal Apple Silicon + Intel builds.
- Packaged the 1.1.0 ZIP and latest-package checksum while retaining the historical 1.0.0 download.

## 1.0.0 — 2026-11-06

First standalone HaloVeil package, based on the validated HALOFLUX macOS adaptation 1.5.0 / build 6.

- Independent HaloVeil screen saver/preview names, native class, and bundle identifiers.
- Neutral public demo headings, without personal account or token-reset text.
- Silent offline playback with startup preparation and a short fade-in.
- Retained per-display instance ownership and complete retirement cleanup.
- Retained path batching, panel scheduling, bounded canvas size, and efficient particle retirement.
- English, Chinese, and bilingual README files; installation instructions explicitly selecting **Screen Saver → Other → HaloVeil**.
- Preserved full upstream license and attribution, with source provenance notes.
- Self-contained universal build, downloadable installation package, checksums, and native regression tests.

Modified from HALOFLUX by Ryder191 (RYDER CODE / Ms MAIKEBAIs CAT) — <https://github.com/Ryder191/haloflux>. Noncommercial use only.
