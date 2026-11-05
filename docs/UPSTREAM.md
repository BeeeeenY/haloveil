# Source provenance

Original work: **HALOFLUX by Ryder191 (RYDER CODE / Ms MAIKEBAIs CAT)**.

Source: <https://github.com/Ryder191/haloflux>.

HaloVeil 1.0.0 is derived from the local macOS adaptation 1.5.0 / build 6, whose actual full-screen startup and exit behavior were checked before this standalone packaging. That adaptation was built from a supplied HALOFLUX source snapshot. The exact original code commit was not recorded, so this project does not invent an upstream commit identifier.

The upstream `LICENSE` was checked on 2026-11-06. GitHub reported license blob SHA `8a612960aba716888ebd0740fecec11dbcf0c532`. The complete local license retained in this project has SHA-256:

```text
1fcfadc1261b748d289d124658aa7873d63c0c4e9178a839c5bd2cb87c0dd4fd
```

## Adaptation changes

- Native macOS saver and optional windowed preview application.
- Silent, offline bundled resources; no upstream music asset is distributed.
- Per-display instance ownership, cross-process locking, and retirement cleanup.
- Startup preparation, geometry-change deduplication, render batching, and canvas budgeting.
- Independent HaloVeil bundle/class names and non-personalized demo headings.
- Build, packaging, installation documentation, and automated integration tests.

The original artwork, layout, motion design, and animation foundation remain attributed to the upstream author. This project is not an official HALOFLUX release.
