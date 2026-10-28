import json
import os
import sys
import unittest
from datetime import datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import board  # noqa: E402
import collect  # noqa: E402

FIX = os.path.join(HERE, "fixtures")
UTC = timezone.utc
NOW = datetime(2026, 10, 25, 1, 0, 0, tzinfo=UTC)

CONFIG = {
    "timezone": "America/New_York",
    "expected": {
        "MacBook": {"Claude": "Team@example.com", "Codex": "personal@example.net", "Antigravity": "team@example.com"},
        "Mini": {"Claude": "personal@example.net", "Codex": "team@example.com"},
        "Studio": {"Claude": "work@example.org", "Codex": "work@example.org"},
    },
    "plans": {"codex:personal@example.net": "Pro $500", "claude:team@example.com": "Max 20x"},
    "also_used_by": {"codex:team@example.com": ["Windows PC (retired)"]},
}

STUDIO_LOGS = {
    "observed_at": "2026-10-25T01:03:38.464Z",
    "rate_limits": {"limit_id": "codex", "limit_name": None,
                    "primary": {"used_percent": 90.0, "window_minutes": 10080, "resets_at": 1793470204},
                    "secondary": None,
                    "credits": {"has_credits": False, "unlimited": False, "balance": "0"},
                    "individual_limit": None, "spend_control_reached": None, "plan_type": "pro",
                    "rate_limit_reached_type": None},
}


def snap(name, rc=0, logs=None, collected=NOW):
    with open(os.path.join(FIX, name)) as fh:
        return collect.build_snapshot(fh.read(), rc, logs, collected)


def machine(snapshot, fetch_error=None):
    return {"snapshot": snapshot, "fetch_error": fetch_error, "last_ok_at": snapshot["collected_at"]}


def fleet():
    return {
        "MacBook": machine(snap("macbook_raw.json")),
        "Mini": machine(snap("mini_raw.json", rc=1)),
        "Studio": machine(snap("studio_raw.json", rc=4, logs=STUDIO_LOGS)),
    }


def by_key(accounts):
    return {a["key"]: a for a in accounts}


def t(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)


class BuildAccountsTest(unittest.TestCase):
    def setUp(self):
        self.acc = by_key(board.build_accounts(fleet(), CONFIG, NOW))

    def test_claude_has_five_hour_weekly_and_model_rows(self):
        a = self.acc["claude:team@example.com"]
        self.assertEqual(a["five_hour"]["used"], 20)
        self.assertEqual(a["five_hour"]["resets_at"], t("2026-10-25T03:39:00Z"))
        self.assertEqual(a["weekly"]["used"], 19)
        self.assertEqual([(o["label"], o["used"]) for o in a["others"]], [("Fable only", 13)])
        self.assertEqual(a["plan"], "Max 20x")
        self.assertEqual(a["machines"], ["MacBook"])
        self.assertIsNone(a["error"])

    def test_codex_has_weekly_only_and_credits(self):
        a = self.acc["codex:personal@example.net"]
        self.assertIsNone(a["five_hour"])
        self.assertEqual(a["weekly"]["used"], 22)
        self.assertEqual(a["weekly"]["resets_at"], t("2026-10-30T17:42:16Z"))
        self.assertAlmostEqual(a["credits"], 28326.32, places=1)
        self.assertEqual(a["plan"], "Pro $500")
        self.assertEqual(a["source"], "CodexBar")

    def test_antigravity_keeps_labeled_windows_without_duplicate_summaries(self):
        a = self.acc["antigravity:team@example.com"]
        self.assertEqual(a["weekly"]["label"], "Gemini Models")
        self.assertEqual([o["label"] for o in a["others"]], ["Claude and GPT"])

    def test_failed_reading_is_shown_against_the_expected_login(self):
        a = self.acc["claude:personal@example.net"]
        self.assertEqual(a["machines"], ["Mini"])
        self.assertIsNotNone(a["error"])
        self.assertIsNone(a["weekly"])

    def test_codex_falls_back_to_codex_logs(self):
        a = self.acc["codex:work@example.org"]
        self.assertEqual(a["source"], "Codex logs")
        self.assertEqual(a["weekly"]["used"], 90)
        self.assertEqual(a["weekly"]["resets_at"], t("2026-10-31T18:10:04Z"))
        self.assertEqual(a["credits"], 0.0)
        self.assertIsNone(a["error"])

    def test_also_used_by_is_listed(self):
        self.assertEqual(self.acc["codex:team@example.com"]["machines"], ["Mini", "Windows PC (retired)"])


class MergeAndStatusTest(unittest.TestCase):
    def test_same_account_on_two_machines_is_one_row(self):
        two = {"MacBook": machine(snap("macbook_raw.json")), "Spare": machine(snap("macbook_raw.json"))}
        acc = by_key(board.build_accounts(two, CONFIG, NOW))
        self.assertEqual(acc["codex:personal@example.net"]["machines"], ["MacBook", "Spare"])

    def test_unexpected_login_is_flagged(self):
        cfg = json.loads(json.dumps(CONFIG))
        cfg["expected"]["MacBook"]["Codex"] = "other@example.com"
        acc = by_key(board.build_accounts({"MacBook": machine(snap("macbook_raw.json"))}, cfg, NOW))
        self.assertIn("other@example.com", acc["codex:personal@example.net"]["note"])

    def test_old_reading_is_stale(self):
        m = {"MacBook": machine(snap("macbook_raw.json"))}
        fresh = by_key(board.build_accounts(m, CONFIG, NOW + timedelta(minutes=5)))
        old = by_key(board.build_accounts(m, CONFIG, NOW + timedelta(minutes=15)))
        self.assertFalse(fresh["claude:team@example.com"]["stale"])
        self.assertTrue(old["claude:team@example.com"]["stale"])

    def test_unreachable_machine_keeps_last_numbers_and_says_so(self):
        m = {"MacBook": machine(snap("macbook_raw.json"), fetch_error="ssh timed out")}
        a = by_key(board.build_accounts(m, CONFIG, NOW))["claude:team@example.com"]
        self.assertEqual(a["weekly"]["used"], 19)
        self.assertIn("unreachable", a["note"])

    def test_machine_without_any_reading_still_shows_its_logins(self):
        m = {"Studio": {"snapshot": None, "fetch_error": "ssh timed out", "last_ok_at": None}}
        acc = by_key(board.build_accounts(m, CONFIG, NOW))
        self.assertEqual(sorted(acc), ["claude:work@example.org", "codex:work@example.org"])
        self.assertIsNotNone(acc["codex:work@example.org"]["error"])

    def test_timed_out_check_still_lists_every_expected_login(self):
        s = collect.build_snapshot("", "timeout", None, NOW)
        acc = by_key(board.build_accounts({"MacBook": machine(s)}, CONFIG, NOW))
        self.assertEqual(sorted(acc), ["antigravity:team@example.com", "claude:team@example.com",
                                       "codex:personal@example.net"])
        self.assertIn("timeout", acc["claude:team@example.com"]["error"])

    def test_passed_reset_is_marked(self):
        later = t("2026-10-25T03:45:00Z")
        a = by_key(board.build_accounts({"MacBook": machine(snap("macbook_raw.json"))}, CONFIG, later))
        self.assertTrue(a["claude:team@example.com"]["five_hour"]["reset_passed"])
        self.assertFalse(a["claude:team@example.com"]["weekly"]["reset_passed"])


class OfflineAndCarryForwardTest(unittest.TestCase):
    LATER = NOW + timedelta(minutes=30)

    def good(self):
        return board.build_accounts({"MacBook": machine(snap("macbook_raw.json"))}, CONFIG, NOW)

    def failing(self):
        s = snap("macbook_failing_raw.json", rc=1, collected=self.LATER)
        return board.build_accounts({"MacBook": machine(s)}, CONFIG, self.LATER)

    def roundtrip(self, last_good):
        return json.loads(json.dumps(last_good))

    def test_offline_antigravity_is_a_problem_not_a_full_limit(self):
        a = by_key(self.failing())["antigravity:team@example.com"]
        self.assertIsNone(a["weekly"])
        self.assertEqual(a["others"], [])
        self.assertIn("not running", a["error"])

    def test_failed_reading_keeps_the_last_good_numbers(self):
        last_good = {}
        board.carry_forward(self.good(), last_good, NOW)
        acc = by_key(board.carry_forward(self.failing(), self.roundtrip(last_good), self.LATER))
        a = acc["claude:team@example.com"]
        self.assertIsNone(a["error"])
        self.assertEqual(a["weekly"]["used"], 19)
        self.assertEqual(a["observed_at"], t("2026-10-25T00:59:16Z"))
        self.assertTrue(a["stale"])
        self.assertIn("Missing Current session", a["note"])

    def test_carried_reading_rechecks_resets(self):
        last_good = {}
        board.carry_forward(self.good(), last_good, NOW)
        after_reset = t("2026-10-25T03:45:00Z")
        s = snap("macbook_failing_raw.json", rc=1, collected=after_reset)
        failing = board.build_accounts({"MacBook": machine(s)}, CONFIG, after_reset)
        a = by_key(board.carry_forward(failing, self.roundtrip(last_good), after_reset))["claude:team@example.com"]
        self.assertTrue(a["five_hour"]["reset_passed"])

    def test_last_good_older_than_six_hours_is_not_used(self):
        last_good = {}
        board.carry_forward(self.good(), last_good, NOW)
        much_later = NOW + timedelta(hours=7)
        s = snap("macbook_failing_raw.json", rc=1, collected=much_later)
        failing = board.build_accounts({"MacBook": machine(s)}, CONFIG, much_later)
        a = by_key(board.carry_forward(failing, self.roundtrip(last_good), much_later))["claude:team@example.com"]
        self.assertIsNotNone(a["error"])

    def test_newer_good_reading_replaces_the_last_good(self):
        last_good = {}
        board.carry_forward(self.good(), last_good, NOW)
        newer = json.loads(open(os.path.join(FIX, "macbook_raw.json")).read())
        newer[1]["usage"]["secondary"]["usedPercent"] = 25
        newer[1]["usage"]["updatedAt"] = "2026-10-25T01:20:00Z"
        s = collect.build_snapshot(json.dumps(newer), 0, None, self.LATER)
        acc = board.build_accounts({"MacBook": machine(s)}, CONFIG, self.LATER)
        a = by_key(board.carry_forward(acc, last_good, self.LATER))["claude:team@example.com"]
        self.assertEqual(a["weekly"]["used"], 25)
        self.assertEqual(last_good["claude:team@example.com"]["weekly"]["used"], 25)

    def test_older_log_fallback_does_not_replace_a_newer_codexbar_reading(self):
        last_good = {}
        board.carry_forward(self.good(), last_good, NOW)
        logs = {"observed_at": "2026-10-25T00:40:00Z",
                "rate_limits": {"primary": {"used_percent": 21.0, "window_minutes": 10080, "resets_at": 1793382136}}}
        s = snap("macbook_failing_raw.json", rc=1, logs=logs, collected=self.LATER)
        acc = board.build_accounts({"MacBook": machine(s)}, CONFIG, self.LATER)
        a = by_key(board.carry_forward(acc, last_good, self.LATER))["codex:personal@example.net"]
        self.assertEqual(a["source"], "CodexBar")
        self.assertEqual(a["weekly"]["used"], 22)


class ForecastTest(unittest.TestCase):
    RESET = t("2026-10-31T18:10:00Z")

    def test_steady_burn_runs_out_before_reset(self):
        pts = [(t("2026-10-24T18:00:00Z"), 0), (t("2026-10-24T19:00:00Z"), 14)]
        f = board.forecast(pts, 14, self.RESET, t("2026-10-24T19:00:00Z"))
        self.assertLess(abs((f["eta"] - t("2026-10-25T01:08:34Z")).total_seconds()), 60)
        self.assertTrue(f["before_reset"])

    def test_points_before_a_reset_are_ignored(self):
        pts = [(t("2026-10-24T18:00:00Z"), 50), (t("2026-10-24T18:30:00Z"), 60),
               (t("2026-10-24T18:40:00Z"), 2), (t("2026-10-24T19:10:00Z"), 8)]
        f = board.forecast(pts, 8, self.RESET, t("2026-10-24T19:10:00Z"))
        self.assertLess(abs((f["eta"] - t("2026-10-25T02:50:00Z")).total_seconds()), 60)

    def test_too_short_a_span_gives_no_forecast(self):
        pts = [(t("2026-10-24T18:00:00Z"), 10), (t("2026-10-24T18:10:00Z"), 12)]
        self.assertIsNone(board.forecast(pts, 12, self.RESET, t("2026-10-24T18:10:00Z")))

    def test_flat_usage_gives_no_forecast(self):
        pts = [(t("2026-10-24T18:00:00Z"), 10), (t("2026-10-24T19:00:00Z"), 10)]
        self.assertIsNone(board.forecast(pts, 10, self.RESET, t("2026-10-24T19:00:00Z")))

    def test_burn_that_outlasts_the_reset_is_not_flagged(self):
        pts = [(t("2026-10-24T18:00:00Z"), 0), (t("2026-10-24T19:00:00Z"), 1)]
        f = board.forecast(pts, 1, t("2026-10-25T00:00:00Z"), t("2026-10-24T19:00:00Z"))
        self.assertFalse(f["before_reset"])

    def test_steady_burn_shows_a_warning_on_the_account(self):
        acc = board.build_accounts(fleet(), CONFIG, NOW)
        history = {"codex:work@example.org|weekly": [["2026-10-25T00:00:00Z", 76], ["2026-10-25T01:00:00Z", 90]]}
        board.attach_forecasts(acc, history, NOW)
        a = by_key(acc)["codex:work@example.org"]
        self.assertTrue(a["forecast"]["before_reset"])
        self.assertIn("Runs out", board.render_text(acc, CONFIG, NOW))
        self.assertIsNone(by_key(acc)["codex:personal@example.net"]["forecast"])


class HistoryTest(unittest.TestCase):
    def test_same_reading_is_recorded_once_and_old_points_pruned(self):
        acc = board.build_accounts({"MacBook": machine(snap("macbook_raw.json"))}, CONFIG, NOW)
        h = {"claude:team@example.com|weekly": [["2026-10-23T00:00:00Z", 5]]}
        h = board.update_history(h, acc, NOW)
        h = board.update_history(h, acc, NOW)
        self.assertEqual(h["claude:team@example.com|weekly"], [["2026-10-25T00:59:16Z", 19]])


class RenderTest(unittest.TestCase):
    def setUp(self):
        self.acc = board.build_accounts(fleet(), CONFIG, NOW)

    def test_text_lists_most_urgent_first_with_percent_left(self):
        out = board.render_text(self.acc, CONFIG, NOW)
        self.assertIn("10% left", out)
        self.assertIn("78% left", out)
        self.assertLess(out.index("work@example.org"), out.index("personal@example.net"))

    def test_reset_times_are_local_12_hour(self):
        out = board.render_text(self.acc, CONFIG, NOW)
        self.assertIn("Fri 10/30 1:42 PM", out)

    def test_html_escapes_provider_text(self):
        m = fleet()
        m["Mini"]["snapshot"]["codexbar"]["rows"][1]["error"]["message"] = "<script>alert(1)</script>"
        page = board.render_html(board.build_accounts(m, CONFIG, NOW), CONFIG, NOW)
        self.assertNotIn("<script>alert", page)
        self.assertIn("&lt;script&gt;", page)


if __name__ == "__main__":
    unittest.main()
