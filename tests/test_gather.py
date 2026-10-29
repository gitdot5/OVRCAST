import json
import os
import sys
import tempfile
import subprocess
import unittest
from unittest.mock import patch
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import gather  # noqa: E402

NOW = datetime(2026, 10, 25, 1, 0, 0, tzinfo=timezone.utc)
GOOD = json.dumps({"collected_at": "2026-10-25T00:59:00Z", "codexbar": {"rows": [], "error": None}})
PREVIOUS = {"snapshot": {"collected_at": "2026-10-25T00:50:00Z"}, "fetch_error": None,
            "last_ok_at": "2026-10-25T00:50:30Z"}


class MergeFetchTest(unittest.TestCase):
    def test_good_fetch_replaces_the_snapshot(self):
        m = gather.merge_fetch(PREVIOUS, GOOD, None, NOW)
        self.assertEqual(m["snapshot"]["collected_at"], "2026-10-25T00:59:00Z")
        self.assertIsNone(m["fetch_error"])
        self.assertEqual(m["last_ok_at"], "2026-10-25T01:00:00Z")

    def test_failed_fetch_keeps_the_last_snapshot(self):
        m = gather.merge_fetch(PREVIOUS, None, "ssh timed out", NOW)
        self.assertEqual(m["snapshot"]["collected_at"], "2026-10-25T00:50:00Z")
        self.assertEqual(m["fetch_error"], "ssh timed out")
        self.assertEqual(m["last_ok_at"], "2026-10-25T00:50:30Z")

    def test_garbled_file_is_a_failure(self):
        m = gather.merge_fetch(PREVIOUS, "{not json", None, NOW)
        self.assertEqual(m["snapshot"]["collected_at"], "2026-10-25T00:50:00Z")
        self.assertIn("unreadable", m["fetch_error"])

    def test_credential_looking_file_is_refused(self):
        bad = GOOD.replace('"rows": []', '"rows": [{"refresh_token": "x"}]')
        m = gather.merge_fetch(PREVIOUS, bad, None, NOW)
        self.assertEqual(m["snapshot"]["collected_at"], "2026-10-25T00:50:00Z")
        self.assertIn("refused", m["fetch_error"])

    def test_first_failure_has_no_snapshot(self):
        m = gather.merge_fetch(None, None, "ssh timed out", NOW)
        self.assertIsNone(m["snapshot"])
        self.assertIsNone(m["last_ok_at"])


class FetchTest(unittest.TestCase):
    def test_oversized_local_snapshot_is_refused_before_decode(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "snapshot.json")
            with open(path, "wb") as stream:
                stream.write(b"x" * 1025)
            with patch.object(gather, "MAX_SNAPSHOT_BYTES", 1024):
                text, err = gather.fetch({"local_path": path})
            self.assertIsNone(text)
            self.assertIn("size limit", err)

    def test_local_machine_reads_the_file(self):
        d = tempfile.mkdtemp()
        p = os.path.join(d, "snapshot.json")
        with open(p, "w") as fh:
            fh.write(GOOD)
        text, err = gather.fetch({"local_path": p})
        self.assertEqual(text, GOOD)
        self.assertIsNone(err)

    def test_missing_local_file_is_an_error(self):
        text, err = gather.fetch({"local_path": "/nonexistent/usageboard/snapshot.json"})
        self.assertIsNone(text)
        self.assertIn("no snapshot", err)

    def test_failing_ssh_command_is_an_error(self):
        text, err = gather.fetch({"ssh": ["-F", "/dev/null", "-o", "BatchMode=yes", "-o", "ConnectTimeout=2",
                                          "-o", "HostName=127.0.0.1", "-o", "Port=1", "nohost"]})
        self.assertIsNone(text)
        self.assertTrue(err)


class BoundedCommandTest(unittest.TestCase):
    def test_combined_stream_limit_accepts_exact_boundary(self):
        result = gather.bounded_command([sys.executable, "-c",
            "import os; os.write(1,b'a'*512); os.write(2,b'b'*512)"], max_bytes=1024)
        self.assertEqual(result.stdout, "a" * 512)
        self.assertEqual(result.stderr, "b" * 512)
        self.assertEqual(result.returncode, 0)

    def test_stdout_and_stderr_both_count_toward_limit(self):
        for descriptor in (1, 2):
            with self.subTest(descriptor=descriptor), self.assertRaises(ValueError):
                gather.bounded_command([sys.executable, "-c",
                    "import os; os.write(%d,b'x'*2048)" % descriptor], max_bytes=1024)
        with self.assertRaises(ValueError):
            gather.bounded_command([sys.executable, "-c",
                "import os; os.write(1,b'a'*600); os.write(2,b'b'*600)"], max_bytes=1024)

    def test_quiet_process_still_has_a_deadline(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            gather.bounded_command([sys.executable, "-c", "import time; time.sleep(3)"], timeout=0.05)


class RunTest(unittest.TestCase):
    def test_failed_check_after_a_good_one_still_shows_numbers(self):
        import collect
        fix = os.path.join(HERE, "fixtures")
        d = tempfile.mkdtemp()
        snap_path = os.path.join(d, "snapshot.json")
        cfg_path = os.path.join(d, "config.json")
        with open(cfg_path, "w") as fh:
            json.dump({"timezone": "America/New_York", "machines": {"MacBook": {"local_path": snap_path}},
                       "expected": {"MacBook": {"Claude": "Team@example.com"}}}, fh)

        def put(name, when):
            with open(os.path.join(fix, name)) as fh:
                collect.write_atomic(snap_path, collect.build_snapshot(fh.read(), 0, None, when))

        put("macbook_raw.json", NOW)
        gather.run(now=NOW, verbose=False, config_path=cfg_path, state_dir=os.path.join(d, "state"), out_dir=d)
        later = datetime(2026, 10, 25, 1, 30, 0, tzinfo=timezone.utc)
        put("macbook_failing_raw.json", later)
        gather.run(now=later, verbose=False, config_path=cfg_path, state_dir=os.path.join(d, "state"), out_dir=d)
        with open(os.path.join(d, "board.txt")) as fh:
            text = fh.read()
        self.assertIn("81% left", text)
        self.assertIn("Latest check failed", text)
        self.assertTrue(os.path.exists(os.path.join(d, "board.html")))


if __name__ == "__main__":
    unittest.main()
