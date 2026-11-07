# Project workflow

- When the user says Preview, they mean `build/HaloVeil Preview.app`. Update that app with `./tools/build-preview.command`; `preview.command` is only the browser HTML shortcut.
- The current scene uses the user's confirmed original preset A: 45 runners. Keep its complete configuration aligned with `tests/fixtures/original-config.json` across every quality profile.
- For normal development, deliver `web/index.html` or a Preview app for review. Do not run saver/release builds or generate a new `.saver`/release ZIP unless the user explicitly requests packaging.
- `./preview.command` opens the current web source without building or installing anything. A plain browser preview does not have the native account-status file bridge.
- `oldVersionBackup/` is the user's protected archive. Leave its files and directories untouched; do not clean, reformat, or include it in commits. It is ignored by Git.
- Keep source, tests, licenses and the ZIP referenced by the public download links. Generated builds, test reports, extracted downloads, caches and OS metadata do not belong in commits.
- Background account collection is opt-in. Do not install, enable or restart its LaunchAgent as part of previewing or testing.
