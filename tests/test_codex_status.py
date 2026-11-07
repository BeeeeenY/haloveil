"""Contract checks for account telemetry, reset selection and private file publishing."""
import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import plistlib

spec = importlib.util.spec_from_file_location("codex_status", Path(__file__).resolve().parents[1] / "tools/codex-status.py")
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class CodexStatusTests(unittest.TestCase):
    def test_service_interval_controls_schedule_and_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            output = home / "Library/Application Support/HaloVeil/agent-status.json"
            with patch.object(status, "DEFAULT_OUTPUT", output), patch.object(status.Path, "home", return_value=home), \
                    patch.object(status, "find_codex", return_value="/test/codex"), \
                    patch.object(status, "read_account", return_value={}), \
                    patch.object(status.subprocess, "run") as run:
                run.return_value.returncode = 0
                status.service(True, interval=3600)
                config = plistlib.loads((home / "Library/LaunchAgents/dev.haloveil.codex-status.plist").read_bytes())
                self.assertEqual(config["StartInterval"], 3600)
                self.assertEqual(config["ProgramArguments"][-2:], ["--interval", "3600"])
                self.assertNotIn("--watch", config["ProgramArguments"])
                self.assertFalse(config.get("KeepAlive", False))
                self.assertEqual(json.loads(output.read_text())["refreshIntervalSecs"], 3600)

    def test_real_fields_and_nearest_available_future_reset(self):
        raw = {"accountId": "private-account", "access_token": "private-token",
               "rateLimitsByLimitId": {"codex": {"primary": {"usedPercent": 2, "windowDurationMins": 10080, "resetsAt": 5000}}},
               "rateLimitResetCredits": {"availableCount": 7, "credits": [
                   {"id": "private-reset", "resetType": "codexRateLimits", "status": state, "expiresAt": expiry}
                   for state, expiry in [("available", 900), ("redeemed", 1100), ("available", 1500), ("available", 1200)]]}}
        snapshot = status.normalize(raw, now=1000)
        self.assertEqual(snapshot["fullReset"], {"availableCount": 7, "expiresAt": 1200, "detailsKnown": True})
        self.assertEqual(snapshot["limits"][0]["windows"][0]["usedPercent"], 2)
        self.assertNotIn("private", json.dumps(snapshot))

    def test_unknown_is_not_zero(self):
        snapshot = status.normalize({"rateLimits": {"primary": {}}}, now=1000)
        self.assertIsNone(snapshot["limits"][0]["windows"][0]["usedPercent"])
        self.assertIsNone(snapshot["fullReset"]["availableCount"])
        self.assertFalse(snapshot["fullReset"]["detailsKnown"])

    def test_count_only_and_empty_details_are_distinct(self):
        for credits, known in [(None, False), ([], True)]:
            result = status.normalize({"rateLimitResetCredits": {"availableCount": 3, "credits": credits}})
            self.assertEqual(result["fullReset"]["availableCount"], 3)
            self.assertEqual(result["fullReset"]["detailsKnown"], known)
            self.assertIsNone(result["fullReset"]["expiresAt"])

    def test_multiple_windows_and_buckets(self):
        snapshot = status.normalize({"rateLimitsByLimitId": {
            "other": {"primary": {"usedPercent": 40}},
            "codex": {"primary": {"usedPercent": 20}, "secondary": {"usedPercent": 60}}}})
        self.assertEqual([b["id"] for b in snapshot["limits"]], ["codex", "other"])
        self.assertEqual(len(snapshot["limits"][0]["windows"]), 2)

    def test_invalid_numbers_and_bounds(self):
        for value in [True, "20", float("nan"), float("inf"), None]:
            snapshot = status.normalize({"rateLimits": {"primary": {"usedPercent": value, "resetsAt": value}}})
            window = snapshot["limits"][0]["windows"][0]
            self.assertIsNone(window["usedPercent"])
            self.assertIsNone(window["resetsAt"])
        for value, expected in [(-3, 0), (101, 100)]:
            snapshot = status.normalize({"rateLimits": {"primary": {"usedPercent": value}}})
            self.assertEqual(snapshot["limits"][0]["windows"][0]["usedPercent"], expected)

    def test_atomic_private_snapshot_and_size_limit(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "status.json"
            status.write_snapshot(path, status.normalize({}))
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            before = path.read_bytes()
            with self.assertRaises(ValueError):
                status.write_snapshot(path, {"oversize": "x" * 65536})
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(list(Path(directory).iterdir()), [path])


if __name__ == "__main__":
    unittest.main()
