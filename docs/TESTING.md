# Testing and validation

Validation date: 2026-11-06. Host: macOS Sonoma 14.4.1. Build: HaloVeil 1.0.0 / build 1, Apple Silicon + Intel universal products.

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

## Reproduce

```sh
./build.command
./tests/run.command
./tests/startup.command
python3 tools/package.py
```

Private reports, temporary test apps, process identifiers, and machine paths are kept in `.local/` and excluded from the upload project. The published project contains this sanitized summary instead of raw diagnostic logs.
