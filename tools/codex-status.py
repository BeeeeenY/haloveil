#!/usr/bin/env python3
"""Read Codex account limits without starting a turn; publish a private snapshot."""
import argparse
import json
import math
import os
from pathlib import Path
import plistlib
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time

DEFAULT_OUTPUT = Path.home() / "Library/Application Support/HaloVeil/agent-status.json"
DEFAULT_INTERVAL = 3600
MAX_BYTES = 65536


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def timestamp(value):
    return value if number(value) and 0 < value < 253402300800 else None


def normalize(raw, now=None, interval=None):
    """Allow-list display fields. Never publish account IDs, credit IDs or credentials."""
    now = time.time() if now is None else now
    if not isinstance(raw, dict):
        raise ValueError("Invalid account response")
    buckets = raw.get("rateLimitsByLimitId")
    if not isinstance(buckets, dict) or not buckets:
        legacy = raw.get("rateLimits")
        buckets = {"codex": legacy} if isinstance(legacy, dict) else {}
    limits = []
    for key in sorted(buckets, key=lambda k: (k != "codex", k))[:8]:
        bucket = buckets[key]
        if not isinstance(bucket, dict):
            continue
        windows = []
        for name in ("primary", "secondary"):
            window = bucket.get(name)
            if not isinstance(window, dict):
                continue
            used, duration = window.get("usedPercent"), window.get("windowDurationMins")
            windows.append({
                "name": name,
                "usedPercent": max(0, min(100, used)) if number(used) else None,
                "windowDurationMins": duration if number(duration) and duration > 0 else None,
                "resetsAt": timestamp(window.get("resetsAt")),
            })
        label = bucket.get("limitName") or key
        limits.append({"id": str(key)[:64], "name": str(label)[:64], "windows": windows})
    resets = raw.get("rateLimitResetCredits")
    reset = {"availableCount": None, "expiresAt": None, "detailsKnown": False}
    if isinstance(resets, dict):
        count = resets.get("availableCount")
        if isinstance(count, int) and not isinstance(count, bool) and count >= 0:
            reset["availableCount"] = count
        credits = resets.get("credits")
        reset["detailsKnown"] = isinstance(credits, list)
        expiries = [timestamp(c.get("expiresAt")) for c in credits or []
                    if isinstance(c, dict) and c.get("status") == "available"
                    and c.get("resetType") == "codexRateLimits"] if isinstance(credits, list) else []
        reset["expiresAt"] = min((t for t in expiries if t is not None and t > now), default=None)
    snapshot = {"schemaVersion": 1, "provider": "codex", "state": "ok", "fetchedAt": now,
                "limits": limits, "fullReset": reset}
    if interval is not None:
        snapshot["refreshIntervalSecs"] = interval
    return snapshot


def find_codex(explicit=None):
    if explicit:
        path = Path(explicit).expanduser()
        if path.is_file() and os.access(path, os.X_OK):
            return str(path.resolve())
        raise RuntimeError("The specified Codex executable is unavailable")
    candidates = [shutil.which("codex")]
    for root in (Path("/Applications"), Path.home() / "Applications"):
        for app in ("ChatGPT.app", "Codex.app", "Codex Dream Skin.app"):
            for binary in ("codex-cli/bin/codex", "codex", "bin/codex"):
                candidates.append(str(root / app / "Contents/Resources" / binary))
    for path in candidates:
        if path and Path(path).is_file() and os.access(path, os.X_OK):
            return str(Path(path).resolve())
    raise RuntimeError("Codex executable unavailable; specify --codex /absolute/path/to/codex")


def read_account(binary, timeout=30):
    # No model request, thread, turn, reset-consumption method, or API key is used.
    process = subprocess.Popen([binary, "app-server", "--listen", "stdio://"],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    buffer = b""
    deadline = time.monotonic() + timeout

    def send(message):
        process.stdin.write((json.dumps(message) + "\n").encode())
        process.stdin.flush()

    def receive(request_id):
        nonlocal buffer
        while time.monotonic() < deadline:
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                message = json.loads(line)
                if message.get("id") == request_id:
                    if "error" in message:
                        # Server errors can contain personal details; do not publish them.
                        raise RuntimeError("Codex rejected the account request; check sign-in and version")
                    return message["result"]
            if selector.select(max(0, deadline - time.monotonic())):
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError("Codex app-server closed; check sign-in and version")
                buffer += chunk
                if len(buffer) > 2 * 1024 * 1024:
                    raise RuntimeError("Codex response exceeded the size limit")
        raise RuntimeError("Codex account request timed out")

    try:
        send({"id": 1, "method": "initialize", "params": {
            "clientInfo": {"name": "haloveil_status", "title": "HaloVeil Status", "version": "1.0.0"}}})
        receive(1)
        send({"method": "initialized"})
        send({"id": 2, "method": "account/rateLimits/read"})
        return receive(2)
    finally:
        selector.close()
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=3)
        except ProcessLookupError:
            pass
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=3)
        for stream in (process.stdin, process.stdout):
            stream.close()


def write_snapshot(path, snapshot):
    path = Path(path).expanduser()
    data = json.dumps(snapshot, ensure_ascii=True, allow_nan=False, separators=(",", ":")).encode()
    if len(data) > MAX_BYTES:
        raise ValueError("Snapshot exceeded the size limit")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".agent-status-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)  # Readers see either the old or complete new snapshot.
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def service(install, binary=None, interval=DEFAULT_INTERVAL):
    """Install a per-user periodic collector independently of the repository."""
    label = "dev.haloveil.codex-status"
    domain = f"gui/{os.getuid()}"
    directory = DEFAULT_OUTPUT.parent
    helper = directory / "codex-status.py"
    plist = Path.home() / "Library/LaunchAgents" / (label + ".plist")
    if install:
        executable = find_codex(binary)
        # Verify account access before changing the user's service configuration.
        write_snapshot(DEFAULT_OUTPUT, normalize(read_account(executable), interval=interval))
        source = Path(__file__).read_bytes()
        helper.write_bytes(source)
        helper.chmod(0o600)
        logfile = directory / "collector.log"
        fd = os.open(logfile, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        os.close(fd)
        plist.parent.mkdir(parents=True, exist_ok=True)
        config = {"Label": label, "ProgramArguments": [str(Path(sys.executable).resolve()), str(helper),
                  "--codex", executable, "--interval", str(interval)], "RunAtLoad": True, "StartInterval": interval,
                  "ProcessType": "Background", "StandardOutPath": str(logfile), "StandardErrorPath": str(logfile)}
        plist.write_bytes(plistlib.dumps(config))
        plist.chmod(0o600)
    subprocess.run(["/bin/launchctl", "bootout", domain + "/" + label],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    if install:
        result = subprocess.run(["/bin/launchctl", "bootstrap", domain, str(plist)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode:
            raise RuntimeError("Could not start the user collector; run --watch manually")
        print(f"Installed Codex status collector (every {interval // 60} minutes, including after sign-in).")
    else:
        plist.unlink(missing_ok=True)
        helper.unlink(missing_ok=True)
        print("Stopped and removed the collector. The last snapshot and log are retained.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--codex", help="Codex executable (uses the existing ChatGPT sign-in)")
    parser.add_argument("--input", type=Path, help="Normalize an account/rateLimits/read JSON response instead")
    parser.add_argument("--watch", action="store_true", help="Refresh until stopped; default is one read")
    parser.add_argument("--interval", type=int, default=DEFAULT_INTERVAL,
                        help="Seconds between reads, including --install (default 3600; range 60–86400)")
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--install", action="store_true", help="Install a per-user collector (default: once an hour)")
    actions.add_argument("--uninstall", action="store_true", help="Stop and remove the per-user collector")
    args = parser.parse_args()
    if not 60 <= args.interval <= 86400 or (args.watch and args.input):
        parser.error("Use --interval 60–86400; --input cannot be combined with --watch")
    if args.install or args.uninstall:
        if args.input or args.watch or args.output != DEFAULT_OUTPUT:
            parser.error("Service actions use the default location and cannot be combined with --input/--watch/--output")
        try:
            service(args.install, args.codex, args.interval)
        except (RuntimeError, OSError) as error:
            print(str(error) if isinstance(error, RuntimeError) else "Collector setup failed; check permissions", file=sys.stderr)
            return 1
        return 0
    while True:
        try:
            raw = json.loads(args.input.read_text()) if args.input else read_account(find_codex(args.codex))
            write_snapshot(args.output, normalize(raw, interval=args.interval))
            print("Updated Codex usage snapshot.", flush=True)
        except (RuntimeError, OSError, ValueError, KeyError) as error:
            # Leave the last good snapshot intact: its original timestamp makes it stale.
            print("Codex status refresh failed: " + (str(error) if isinstance(error, RuntimeError)
                  else "check the input, executable and output permissions"), file=sys.stderr, flush=True)
            if not args.watch:
                return 1
        if not args.watch:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
