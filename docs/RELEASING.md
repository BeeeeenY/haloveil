# Publish this project on GitHub

## Upload source changes / 上传源码改动

The local repository is connected to `https://github.com/BeeeeenY/haloveil.git` on `main`. Local edits are not uploaded automatically. The current release is **1.1.0 / build 2**. For normal development, review `web/index.html` or `build/HaloVeil Preview.app` first; build a saver or release ZIP only when packaging is explicitly requested.

本地仓库已连接 `https://github.com/BeeeeenY/haloveil.git`，当前分支为 `main`。本地修改不会自动上传；当前发布版为 **1.1.0 / build 2**。日常开发先通过 `web/index.html` 或 `build/HaloVeil Preview.app` 确认效果，明确要求发布安装包后再构建屏保和更新 ZIP。

1. Review the changes in GitHub Desktop or `git status`. Commit and push when ready. / 在 GitHub Desktop 或 `git status` 中检查改动，确认后提交并推送。
2. Keep `LICENSE`, `NOTICE`, both README files, `AGENTS.md`, `source/`, `web/`, `assets/`, `docs/`, `tests/`, `tools/`, `preview.command`, `build.command`, `version.json`, and `downloads/`. / 保留源码、测试、预览入口、说明、完整许可与下载文件。
3. Do not generate a new MIT license on GitHub. The existing upstream license is required. / 不要在 GitHub 使用 MIT 模板覆盖现有许可。
4. `oldVersionBackup/` is a protected local archive and must remain ignored and untouched. `build/`, `.local/`, caches, extracted packages and OS metadata are also excluded. / `oldVersionBackup/` 是受保护的本地旧版备份，不修改、不上传；构建文件、测试报告、缓存、解压副本和系统杂项同样不上传。

README and install guides use the direct-download URL for `downloads/HaloVeil-1.1.0.zip`. Keep that tracked ZIP and `downloads/SHA256SUMS` in the repository. Keep `downloads/HaloVeil-1.0.0.zip` for the historical download links; the latest `SHA256SUMS` lists only the new package. A source-only update does not change a downloadable binary. If the repository, default branch or release filename changes, update all four primary download links.

README 与安装说明统一使用 `downloads/HaloVeil-1.1.0.zip` 的直接下载地址，新 ZIP 与 `downloads/SHA256SUMS` 必须保留并上传。`downloads/HaloVeil-1.0.0.zip` 保留给历史下载链接；最新版 `SHA256SUMS` 仅列出新包。仅上传源码不会更新安装包；仓库、默认分支或文件名变化后，需同步更新四处主要下载链接。

Release 1.1.0 uses the confirmed preset A / 45-runner configuration, with all 56 values matching `tests/fixtures/original-config.json`. Preserve **BEN'S CONTROL ROOM** / **IDEAS IN MOTION**, Codex in panel 1, and the demo **12 AGENTS / DISPATCH** in panel 7. The package includes the optional Codex native bridge; packaging must not enable account collection.

1.1.0 使用已确认的 A 预设和 45 个 runner，完整 56 项参数与 `tests/fixtures/original-config.json` 一致。保留 **BEN'S CONTROL ROOM** / **IDEAS IN MOTION** 标题、第一格 Codex 用量和第七格演示用的 **12 AGENTS / DISPATCH**。发布包包含可选的 Codex 原生桥接；打包过程不启用账户采集。

## Rebuild a release

1. Update `version.json` (`1.1.0`, build `2` for this release) and the versioned download links in the README/install documents.
2. Run `./build.command`, `./tests/run.command`, and `./tests/startup.command`.
3. Check the actual full-screen screen saver and review a fresh screenshot.
4. Run `python3 tools/package.py`. It verifies signatures and versions, creates the release ZIP, and writes `downloads/SHA256SUMS` for the latest package only. Preserve the historical 1.0.0 ZIP.
5. Commit the source and versioned download, preserving the upstream attribution and license. Keep private reports, local test apps, generated build products, editor files, and OS metadata out of the upload.

## Optional GitHub Release

Create the release tag `v1.1.0` and attach `downloads/HaloVeil-1.1.0.zip` plus `downloads/SHA256SUMS`. Use the matching entry in `CHANGELOG.md` as release notes, and include the original author/source attribution and noncommercial restriction in the release description.

Releases are locally signed, not Apple-notarized. A notarized distribution would require the maintainer's own Apple Developer credentials and a separately tested signing/notarization process. No credentials are bundled in this repository.
