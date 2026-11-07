# Testing and validation

Release validation: 2026-11-07. Host: macOS Sonoma 14.4.1. Build: HaloVeil 1.1.0 / build 2, Apple Silicon + Intel universal products.

## Release 1.1.0

- All 56 confirmed scene values match the original preset A, including 45 runners.
- Current title/subtitle and all eight panel positions are preserved; ten layout/demo-agent checks passed.
- Seven offline collector contract tests, twelve native snapshot-reader checks, and nine quota-display checks passed. Collector service actions were mocked in a temporary home; no real service was installed or restarted.
- Eight lifecycle cycles / 88 checks passed, ending with zero sessions and zero web views.
- Both the saver and bundled Preview select the approved original-quality profile. Startup completes 37 warmup frames with one layout build.
- The final ZIP was checked for CRC, source/resource identity, executable permissions, version metadata and universal architectures. Native macOS extraction preserved both product signatures; the extracted saver was tested independently.
- The README image and settings thumbnail use the current layout with synthetic account data, not a personal account snapshot.

The records below describe earlier development checks and their limitations.

## Current Preview configuration

All 56 scene parameters match the user's exported HALOFLUX preset A, including
45 runners. Before the panel relocation, three independent visible startup processes at the actual Preview
window dimensions (1600 × 932 points, scale 2) passed configuration and pacing
checks. Across the 0–1, 1–3, 3–5, and 5–10 second intervals, measured drawing
callbacks were 59.5–61 per second, the maximum interval was 18 ms, and no interval
exceeded 33 ms. Each start completed 37 warmup frames with one layout build.
These measure drawing callbacks, not physical display presentation timestamps.

The updated layout passed 10 panel/agent checks and 7 quota-display checks with
a synthetic private snapshot: Codex at row 1/column 1 and twelve animated demo
agents at row 2/column 3. The standalone Preview's opening log recorded about
60 drawing callbacks per second with drawing P95 about 2 ms. Instrumented QA
runs also recorded transient 48–55 callback FPS during the first few seconds;
those runs did not meet the strict 55 FPS pacing gate, so functional success
must not be interpreted as a universal smoothness guarantee. The scene's full
56-parameter configuration and 45-runner count remained unchanged.

`downloads/HaloVeil-1.1.0.zip` is the current release. The 1.0.0 ZIP and
`oldVersionBackup/` remain unchanged historical builds.

## Automated lifecycle checks

**88 checks passed across 8 repeated start/stop cycles.** Final active state: zero sessions and zero web views. No progressive slowdown was observed in this run.

Coverage includes repeated start on the same view, explicit stop, detachment without stop, retained old-instance takeover, window hiding/demotion, simulated two-display ownership, sleep/wake, cross-process lease/claim, navigation cancellation, startup-preparation cancellation, deallocation, and rejection of mixed or corrupted resources.

Warmup cancellation checks that playback time remains zero, business timers remain stopped, and late callbacks do not revive a retired view.

## Startup sampling

Three independent WKWebView starts in one offscreen native QA app process:

| Start | Preparation | First 5 seconds: draw FPS | Maximum sampled gap | Layout builds |
| --- | ---: | ---: | ---: | ---: |
| 1 | 996 ms | 60.0 | 18 ms | 1 |
| 2 | 788 ms | 59.8 | 32 ms | 1 |
| 3 | 963 ms | 60.0 | 20 ms | 1 |

The preview screenshot was generated from the rebranded web content and visually checked. The final product then rebuilt its settings thumbnail from that screenshot. Public UI error text was translated to English; these string/resource changes do not change the measured animation algorithm. The final native products passed the lifecycle suite afterward.

## What these checks do not prove

- Draw submission samples are not physical display presentation timestamps or a guarantee of constant 60 FPS.
- Offscreen test windows do not replace actual full-screen/lock-screen verification.
- The inherited adaptation 1.5.0 was visually confirmed smooth in the actual system saver before this standalone branding; the newly named HaloVeil bundle has not been separately installed for a new real-host acceptance run.
- Display isolation uses simulated display IDs; no dual-physical-display claim is made.
- The minimum deployment target is macOS 12. Actual macOS compatibility beyond the tested system needs verification.

## Codex account panel (source builds)

Validated on 2026-11-06 using the installed Codex app-server and a private account snapshot. The collector successfully read live limits and earned-reset details. The independent per-user LaunchAgent completed its first scheduled run successfully, publishing a fresh `0600` snapshot at the fixed external path.

- 6 Python contract tests: reset eligibility/nearest future expiry, authoritative counts, missing fields, multiple buckets/windows, numeric validation and atomic private writes.
- 12 native file-reader checks: schema validation, field filtering, unknown numbers, private permissions, invalid/oversized JSON, symlinks and FIFO rejection.
- 7 native WKWebView UI checks: consumed/remaining percentage, stale snapshots, missing data, unknown fields, elapsed reset times, future timestamps and safe text rendering.
- Real snapshot values and dates reached the panel through the native bridge in all 3 startup cycles. Final startup samples: 916 / 884 / 941 ms to first frame; 60.0 / 60.0 / 60.2 draw FPS over the first 5 seconds; one layout build each. Snapshot visually checked.
- Existing 8-cycle lifecycle suite passed with zero remaining sessions/web views.

The installed macOS screen saver host's access to the external status directory has not been verified. Offscreen tests and the independent preview app do not establish sandbox access in that host. A rejected or missing file displays `NO DATA`; a snapshot older than 15 minutes displays `STALE`. See [setup and boundaries](CODEX-STATUS.md).

## Reproduce

```sh
./build.command
./tests/agent-status.command
./tests/run.command
./tests/startup.command
python3 tools/package.py
```

Private reports, temporary test apps, process identifiers, and machine paths are kept in `.local/` and excluded from the upload project. The published project contains this sanitized summary instead of raw diagnostic logs.
