import json
import os
import stat
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from types import SimpleNamespace
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import collect  # noqa: E402

FIX = os.path.join(HERE, "fixtures")
NOW = datetime(2026, 10, 25, 1, 0, 0, tzinfo=timezone.utc)


def fixture(name):
    with open(os.path.join(FIX, name)) as fh:
        return fh.read()


class FindSecretTest(unittest.TestCase):
    def test_real_codexbar_output_is_clean(self):
        self.assertFalse(collect.find_secret(fixture("macbook_raw.json")))

    def test_jwt_is_caught(self):
        self.assertTrue(collect.find_secret('{"x":"eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc"}'))

    def test_anthropic_key_is_caught(self):
        self.assertTrue(collect.find_secret('{"note":"sk-ant-oat01-AAAAAAAAAAAAAAAA"}'))

    def test_token_field_name_is_caught(self):
        self.assertTrue(collect.find_secret('{"refresh_token": "x"}'))

    def test_error_text_mentioning_cookies_is_not_a_secret(self):
        self.assertFalse(collect.find_secret('{"message":"No Claude session key found in browser cookies."}'))


class ClaudeAuthPreflightTest(unittest.TestCase):
    def test_signed_out_profile_fails_fast_without_spawning_usage_pty(self):
        with patch('collect.claude_auth_status', return_value={'loggedIn': False}), patch('collect._codexbar') as cli:
            output, rc = collect.provider_usage('codexbar', 'claude', {'USAGEBOARD_CLAUDE_AUTH_CHECK': '1'})
            self.assertEqual(rc, 1)
            self.assertEqual(json.loads(output)[0]['error']['kind'], 'authentication')
            cli.assert_not_called()

    def test_signed_in_profile_uses_existing_usage_source(self):
        with patch('collect.claude_auth_status', return_value={'loggedIn': True}), patch('collect._codexbar', return_value=('[]', 0)) as cli:
            self.assertEqual(collect.provider_usage('codexbar', 'claude', {'USAGEBOARD_CLAUDE_AUTH_CHECK': '1'}), ('[]', 0))
            cli.assert_called_once()

    def test_public_auth_check_drops_unexpected_sensitive_fields(self):
        result = SimpleNamespace(stdout=json.dumps({'loggedIn': False, 'access_token': 'do-not-retain'}))
        with patch('collect.shutil.which', return_value='claude'), patch('collect.subprocess.run', return_value=result):
            self.assertEqual(collect.claude_auth_status({}), {'loggedIn': False})

    def test_auth_preflight_does_not_change_other_collectors(self):
        with patch('collect.claude_auth_status') as auth, patch('collect._codexbar', return_value=('[]', 0)):
            collect.provider_usage('codexbar', 'claude', {})
            auth.assert_not_called()


class BuildSnapshotTest(unittest.TestCase):
    def test_keeps_codexbar_rows(self):
        snap = collect.build_snapshot(fixture("macbook_raw.json"), 0, None, NOW)
        self.assertEqual([r["provider"] for r in snap["codexbar"]["rows"]], ["codex", "claude", "antigravity"])
        self.assertEqual(snap["collected_at"], "2026-10-25T01:00:00Z")
        self.assertIsNone(snap["codexbar"]["error"])

    def test_planted_token_drops_the_payload(self):
        bad = fixture("macbook_raw.json").replace('"Max"', '"sk-ant-oat01-AAAAAAAAAAAAAAAAAAAA"')
        snap = collect.build_snapshot(bad, 0, None, NOW)
        self.assertEqual(snap["codexbar"]["rows"], [])
        self.assertIn("refused", snap["codexbar"]["error"])
        self.assertNotIn("sk-ant", json.dumps(snap))

    def test_unreadable_output_is_reported(self):
        snap = collect.build_snapshot("Segmentation fault", 139, None, NOW)
        self.assertEqual(snap["codexbar"]["rows"], [])
        self.assertIn("139", snap["codexbar"]["error"])

    def test_provider_errors_exit_nonzero_but_rows_are_kept(self):
        snap = collect.build_snapshot(fixture("mini_raw.json"), 1, None, NOW)
        self.assertEqual(len(snap["codexbar"]["rows"]), 2)
        self.assertIsNone(snap["codexbar"]["error"])

    def test_rollout_reading_with_a_token_is_dropped(self):
        rl = {"observed_at": "x", "rate_limits": {"note": "Bearer abcdefghijklmnopqrstuvwxyz0123"}}
        snap = collect.build_snapshot("[]", 0, rl, NOW)
        self.assertIsNone(snap["codex_logs"])

    def test_rollout_reading_is_included(self):
        rl = {"observed_at": "2026-10-25T01:03:38Z", "rate_limits": {"plan_type": "pro"}}
        snap = collect.build_snapshot("[]", 0, rl, NOW)
        self.assertEqual(snap["codex_logs"], rl)


class PerProviderTest(unittest.TestCase):
    PROVIDERS = ('[{"enabled":true,"provider":"codex","defaultEnabled":true,"displayName":"Codex"},'
                 '{"enabled":false,"provider":"openai","defaultEnabled":false,"displayName":"OpenAI"},'
                 '{"enabled":true,"provider":"claude","defaultEnabled":false,"displayName":"Claude"}]')

    def rows_of(self, provider):
        return json.dumps([r for r in json.loads(fixture("macbook_raw.json")) if r["provider"] == provider])

    def test_enabled_providers_in_order(self):
        self.assertEqual(collect.enabled_providers(self.PROVIDERS), ["codex", "claude"])

    def test_enabled_providers_unreadable_is_empty(self):
        self.assertEqual(collect.enabled_providers("Error: config locked"), [])

    def test_slow_provider_does_not_lose_the_others(self):
        rows = collect.merge_provider_outputs({"codex": (self.rows_of("codex"), 0), "claude": ("", "timeout")})
        self.assertEqual([r["provider"] for r in rows], ["codex", "claude"])
        self.assertIn("usage", rows[0])
        self.assertIn("timed out", rows[1]["error"]["message"])

    def test_credential_in_one_provider_drops_only_that_provider(self):
        bad = self.rows_of("claude").replace('"Max"', '"sk-ant-oat01-AAAAAAAAAAAAAAAAAAAA"')
        rows = collect.merge_provider_outputs({"codex": (self.rows_of("codex"), 0), "claude": (bad, 0)})
        self.assertIn("usage", rows[0])
        self.assertIn("refused", rows[1]["error"]["message"])
        self.assertNotIn("sk-ant", json.dumps(rows))

    def test_unreadable_provider_output_becomes_an_error_row(self):
        rows = collect.merge_provider_outputs({"antigravity": ("Segmentation fault", 139)})
        self.assertEqual(rows[0]["provider"], "antigravity")
        self.assertIn("139", rows[0]["error"]["message"])


class LatestCodexRateLimitsTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.day = os.path.join(self.root, "2026", "10", "24")
        os.makedirs(self.day)

    def write(self, name, lines, mtime):
        path = os.path.join(self.day, name)
        with open(path, "w") as fh:
            fh.write("\n".join(lines) + "\n")
        os.utime(path, (mtime, mtime))

    def test_uses_last_usage_line_of_newest_file(self):
        line = fixture("codex_rollout_token_count_macbook.jsonl").strip()
        older = line.replace('"used_percent": 22.0', '"used_percent": 5.0').replace('"used_percent":22.0', '"used_percent":5.0')
        self.write("rollout-a.jsonl", [older], time.time() - 600)
        self.write("rollout-b.jsonl", ['{"type":"response_item","payload":{}}', line, '{"type":"event_msg","payload":{"type":"agent_message"}}'], time.time())
        got = collect.latest_codex_rate_limits(self.root, NOW)
        self.assertEqual(got["rate_limits"]["primary"]["used_percent"], 22.0)
        self.assertEqual(got["rate_limits"]["plan_type"], "promax")
        self.assertTrue(got["observed_at"].startswith("2026-10-2"))

    def test_none_when_no_sessions(self):
        self.assertIsNone(collect.latest_codex_rate_limits(self.root, NOW))

    def test_none_when_root_missing(self):
        self.assertIsNone(collect.latest_codex_rate_limits(os.path.join(self.root, "nope"), NOW))


class WriteAtomicTest(unittest.TestCase):
    def test_file_is_private_and_complete(self):
        d = tempfile.mkdtemp()
        path = os.path.join(d, "sub", "snapshot.json")
        collect.write_atomic(path, {"a": 1})
        with open(path) as fh:
            self.assertEqual(json.load(fh), {"a": 1})
        self.assertEqual(stat.S_IMODE(os.stat(path).st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(os.stat(os.path.dirname(path)).st_mode), 0o700)


if __name__ == "__main__":
    unittest.main()

class OwnedCollectorTest(unittest.TestCase):
    def test_explicit_helper_does_not_fall_back_when_missing(self):
        with patch('collect.os.path.isfile', return_value=False), patch('collect.shutil.which') as which:
            self.assertIsNone(collect.collector_executable({'OVRCAST_COLLECTOR_PATH': '/missing/helper'}))
            which.assert_not_called()

    def test_missing_bundled_helper_never_searches_codexbar(self):
        with patch('collect.collector_executable', return_value=None), patch('collect._claude_on_path'), patch('collect.shutil.which') as which:
            self.assertEqual(collect.run_codexbar(), ('', 'ovrcast-collector-not-found'))
            which.assert_not_called()

    def test_collection_uses_three_supported_providers(self):
        with patch('collect.collector_executable', return_value='/owned/helper'), patch('collect._claude_on_path'), patch('collect.provider_usage', return_value=('[]', 0)) as usage:
            collect.run_codexbar()
            self.assertEqual({c.args[1] for c in usage.call_args_list}, {'codex', 'claude', 'antigravity'})
            self.assertTrue(all(c.args[0] == '/owned/helper' for c in usage.call_args_list))

    def test_claude_uses_supported_oauth_without_cli_fallback(self):
        with patch('collect._codexbar', return_value=('[]', 0)) as run:
            collect.provider_usage('/owned/helper', 'claude', {})
            self.assertEqual(run.call_args.args[1][-2:], ['--source', 'oauth'])
