# Publish this project on GitHub

## First upload / 首次上传

The project folder is a standalone local Git repository. It has no configured remote and nothing has been published automatically.

本文件夹是独立的本地 Git 仓库，未设置远程仓库，也未自动上传任何内容。

1. Create an empty GitHub repository, or use GitHub Desktop's **Add Local Repository** and then **Publish repository**. / 在 GitHub 创建空仓库，或在 GitHub Desktop 中添加本地仓库并发布。
2. Upload or commit the project files. Keep `LICENSE`, `NOTICE`, all three README files, `source/`, `web/`, `assets/`, `docs/`, `tests/`, `tools/`, `build.command`, `version.json`, and `downloads/`. / 上传源码、说明、完整许可与 `downloads/` 安装包。
3. Do not generate a new MIT license on GitHub. The existing upstream license is required. / 不要在 GitHub 使用 MIT 模板覆盖现有许可。

The README uses a relative link to the versioned ZIP in `downloads/`. That link works under whichever owner/repository name you choose, without editing account-name placeholders or creating a GitHub Release first.

README 使用指向 `downloads/` 安装包的相对链接，不依赖 GitHub 用户名、仓库名或预先创建 Release，上传后即可下载。

## Rebuild a release

1. Update `version.json` and the versioned download links in the README/install documents.
2. Run `./build.command`, `./tests/run.command`, and `./tests/startup.command`.
3. Check the actual full-screen screen saver and review a fresh screenshot.
4. Run `python3 tools/package.py`. It verifies signatures and versions, creates the release ZIP, and writes `downloads/SHA256SUMS`.
5. Commit the source and versioned download, preserving the upstream attribution and license. Keep private reports, local test apps, generated build products, editor files, and OS metadata out of the upload.

## Optional GitHub Release

Create a release tag such as `v1.0.0` and attach `downloads/HaloVeil-1.0.0.zip` plus `downloads/SHA256SUMS`. Use the matching entry in `CHANGELOG.md` as release notes, and include the original author/source attribution and noncommercial restriction in the release description.

Releases are locally signed, not Apple-notarized. A notarized distribution would require the maintainer's own Apple Developer credentials and a separately tested signing/notarization process. No credentials are bundled in this repository.
