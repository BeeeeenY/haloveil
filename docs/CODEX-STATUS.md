# Codex account status / 用量接入

HaloVeil 1.1.0 and the current source include the optional Codex account panel and native file bridge. Account collection requires separate opt-in setup. Other panels and header counters remain a visual demo; the Codex panel shows account-wide limits, not the current chat's token count or agent progress.

HaloVeil 1.1.0 安装包及当前源码已包含可选的 Codex 账户用量面板和原生文件桥接，账户采集需要另行主动启用。其他面板及顶部计数仍为视觉演示。Codex 面板显示账户共享额度，不代表当前聊天的 token 数或任务进度。

The Codex panel occupies row 1, column 1; row 2, column 3 retains `12 AGENTS / DISPATCH` as a visual demo. Codex 用量位于第一行第一格；第二行第三格保留 `12 AGENTS / DISPATCH`，其中的 12 个 agent 仍为视觉演示。

## Enable / 启用

Account collection is opt-in and independent of the screen saver and Preview app. Normal browser previews do not start it. For a single snapshot, sign in to Codex with ChatGPT and run:

账户采集需要主动启用，与屏保和 Preview App 独立；日常浏览器预览不会启动它。只读取一次时，先在 Codex CLI 或桌面 App 中用 ChatGPT 登录，然后运行：

```sh
python3 tools/codex-status.py
```

Open `HaloVeil Preview.app` from the 1.1.0 download to display the snapshot without installing the saver. A plain browser has no native file bridge and displays `NO DATA`. Rebuilding native products from source is a separate, explicitly requested step.

打开 1.1.0 下载包内的 `HaloVeil Preview.app`，无需安装屏保即可显示快照；普通浏览器没有原生文件桥接，该面板显示 `NO DATA`。从源码重新构建原生程序是另行按需执行的步骤。

Only if you want continuous collection while logged in, explicitly install the background service:

只有希望登录期间持续采集时，才运行下面的后台安装命令。即使没有打开屏保或 Preview，它也会每 1 小时刷新：

```sh
python3 tools/codex-status.py --install --interval 3600
```

`--install` verifies a real account read, copies the collector outside the repository, and installs a per-user LaunchAgent. It refreshes immediately and every hour after login. It uses the existing Codex sign-in; there is no API-key setup or model inference. If auto-detection fails, add `--codex /absolute/path/to/codex`. Re-run installation after relocating the Codex app or Python interpreter.

`--install` 会先验证账户读取，将采集器复制到源码目录外，再启用用户级 LaunchAgent。登录后立即读取，并每 1 小时刷新。它沿用本机 Codex 登录，不需要 API key，也不会发起模型任务。找不到可执行文件时，可加 `--codex /absolute/path/to/codex`。移动 Codex App 或 Python 后，重新运行安装命令即可。

Fixed paths / 固定位置：

| File | Purpose |
| --- | --- |
| `~/Library/Application Support/HaloVeil/agent-status.json` | Private, atomic display snapshot / 只读显示快照 |
| `~/Library/Application Support/HaloVeil/codex-status.py` | Independent collector / 独立采集器 |
| `~/Library/Application Support/HaloVeil/collector.log` | Refresh success/failure log / 刷新日志 |
| `~/Library/LaunchAgents/dev.haloveil.codex-status.plist` | Per-user service / 用户级后台配置 |

To run once or keep a terminal collector running / 也可单次读取或在终端持续采集：

```sh
python3 tools/codex-status.py
python3 tools/codex-status.py --watch
```

To stop the background collector / 停止后台采集：

```sh
python3 tools/codex-status.py --uninstall
```

Uninstall leaves the last snapshot and log in place; delete them to remove saved telemetry. The screen saver never launches the collector itself.

卸载会保留最后的快照和日志，可手动删除。屏保本身只读文件，不启动采集器。

## Display meanings / 显示含义

- `2% used · 98% left`: consumed and remaining percentage for each returned quota window. Durations come from the response, e.g. `1W` or `5H`; they are not assumed. The panel displays the first two windows, with Codex first; its caption notes any additional windows.
- `RENEWS`: next automatic quota reset time, from `resetsAt`. It is independent of earned reset credits.
- `FULL RESET · 3 AVAILABLE`: server-reported available reset count.
- `NEXT KNOWN EXPIRY`: earliest future expiry among the returned available `codexRateLimits` reset details. This is the next known **券到期时间**, not the most recently granted reset or automatic renewal. The server may cap detail rows, so this is not a guarantee about undisclosed credits. No reset is ever consumed.
- `SYNCED`: snapshot is within the configured refresh interval plus a 15-minute grace period (75 minutes for the hourly collector). Legacy snapshots without an interval use 15 minutes. `STALE` means it is older. Missing, invalid, unreadable or future-dated snapshots show `NO DATA`. Unknown fields remain unknown. After a reported renewal/expiry passes, the display waits for fresh data instead of assuming a new balance.
- Dates use the Mac's local timezone, shown in the caption. Singapore is `Asia/Singapore` (UTC+8).

## Data flow and boundaries

The collector uses the documented [`account/rateLimits/read`](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt) RPC over a short-lived local `codex app-server` stdio process. It sends only initialization and the account read. Account IDs, reset-credit IDs, authentication files and credentials are not copied into the snapshot. Reading account state requires network access by Codex; the saver web page retains `connect-src 'none'`.

采集器通过官方本地协议读取账户信息，只输出经过筛选的百分比、额度窗口、时间和重置券数量，不输出凭据或账户标识。联网由采集器调用的 Codex 完成；屏保网页仍禁止联网。默认快照权限为 `0600`，写入采用原子替换；失败时保留原时间戳，防止旧数据伪装成新数据。

The native saver reads at most 64 KiB on a background queue every 5 seconds while running. It rejects symlinks, non-regular files, files owned by another user, and group/world-readable snapshots. It passes only validated display fields to JavaScript using a structured bridge. It stops polling with the view's existing lifecycle. Files must remain outside the signed `.saver` and `.app`; changing a snapshot does not require rebuilding.

Preview and offscreen WKWebView checks do not establish access inside every macOS screen saver host. Validate the installed saver on the target macOS version; a denied read shows `NO DATA`. For diagnostics, compare the independent Preview app with the real saver, check `collector.log`, the file's `0600` permissions, and its timestamp. Do not broaden credential-file permissions to fix a display issue.

## Tests

```sh
./tests/agent-status.command
./tests/run.command
HALOVEIL_TEST_AGENT_STATUS="$PWD/.local/codex-status/agent-status.json" ./tests/startup.command
```

The optional startup fixture path belongs to the test subclass only; production hosts always use the fixed path. To prepare a private test snapshot, use `python3 tools/codex-status.py --output .local/codex-status/agent-status.json`. To normalize an exported `account/rateLimits/read` result without networking, use `--input response.json --output snapshot.json`. Supply the response's result object, not its JSON-RPC envelope.
