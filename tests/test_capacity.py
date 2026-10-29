import json
import unittest
from copy import deepcopy
from datetime import timedelta
from unittest.mock import patch
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import board
import capacity
import gather
from test_board import CONFIG, NOW, fleet, by_key


class CapacityTest(unittest.TestCase):
    def test_missing_reset_inventory_differs_from_zero(self):
        self.assertIsNone(capacity.normalize({})["resets"]["available"])
        self.assertEqual(capacity.normalize({"resetCredits": {"available": 0}})["resets"]["available"], 0)

    def test_claude_detail_rows_preserve_cloud_expiry_and_resets(self):
        raw = {"usage": {"details": [{"title": "Credits", "rows": [
            {"id": "claude-cloud-credits", "label": "Cloud credits", "value": "$0.00 of $50.00 remaining",
             "secondaryValue": "Expires 2026-11-01T00:00:00Z"},
            {"label": "Limit Reset Credits", "value": "2 available", "secondaryValue": "Next expiry tomorrow"}]}]}}
        extra = capacity.normalize(raw)
        self.assertEqual(extra["resets"]["available"], 2)
        pools = capacity.pools({"tool": "Claude", "capacity": extra}, NOW)
        self.assertEqual(pools[0][1], "$0.00 of $50.00 remaining")
        self.assertIn("Expires", pools[0][2])
        self.assertEqual(pools[2][1], "Unknown")

    def test_cached_cloud_credit_becomes_expired(self):
        extra = capacity.normalize({"usage": {"details": [{"rows": [{"id": "claude-cloud-credits",
            "value": "$50 remaining", "secondaryValue": "Expires 2026-10-24T00:00:00Z"}]}]}})
        self.assertEqual(capacity.pools({"tool": "Claude", "capacity": extra}, NOW)[0][1], "Expired")

    def test_malformed_optional_date_does_not_break_board(self):
        self.assertIsNone(board.parse_time("not a date"))

    def test_one_point_change_does_not_create_multi_day_warning(self):
        accounts = board.build_accounts(fleet(), CONFIG, NOW)
        history = {"codex:personal@example.net|weekly": [["2026-10-25T00:00:00Z", 21], ["2026-10-25T01:00:00Z", 22]]}
        board.attach_forecasts(accounts, history, NOW)
        self.assertIsNone(by_key(accounts)["codex:personal@example.net"]["forecast"])

    def test_failed_balance_read_does_not_claim_zero(self):
        extra = capacity.normalize({"credits": {"remaining": 0, "balanceReadSucceeded": False}})
        self.assertIsNone(extra["balance"])

    def test_invalid_numeric_values_are_unknown(self):
        for val in (True, -2, "NaN", "Infinity", None):
            self.assertIsNone(capacity.number(val))

    def test_extra_usage_keeps_currency_spend_cap_and_balance(self):
        extra = capacity.normalize({"usage": {"providerCost": {"used": 12.5, "limit": 30,
                                    "balance": 5, "currencyCode": "USD"}}})
        value = capacity.pools({"tool": "Claude", "capacity": extra})[1][1]
        self.assertIn("12.50 USD spent", value)
        self.assertIn("30.00 cap", value)
        self.assertIn("5.00 balance", value)

    def test_model_exhaustion_changes_account_status(self):
        a = by_key(board.build_accounts(fleet(), CONFIG, NOW))["claude:team@example.com"]
        a["others"][0]["used"] = 100
        self.assertEqual(board.account_status(a), ("critical", "Model limit reached"))

    def test_stale_and_failed_reads_never_get_forecasts(self):
        acc = board.build_accounts(fleet(), CONFIG, NOW)
        for a in acc:
            a["stale"] = True
        h = {"codex:work@example.org|weekly": [["2026-10-25T00:00:00Z", 76], ["2026-10-25T01:00:00Z", 90]]}
        board.attach_forecasts(acc, h, NOW)
        self.assertTrue(all(a["forecast"] is None for a in acc))

    def test_no_forecast_claim_before_unknown_reset(self):
        pts = [(NOW - timedelta(hours=1), 0), (NOW, 10)]
        self.assertFalse(board.forecast(pts, 10, None, NOW)["before_reset"])

    def test_rpc_usage_is_bound_to_reported_email_and_inventory(self):
        machines = fleet()
        machines["MacBook"]["snapshot"]["codex_account"] = {
            "email": "personal@example.net", "observed_at": board.iso(NOW),
            "rateLimits": {"primary": {"usedPercent": 4, "windowDurationMins": 10080,
                           "resetsAt": 1793599826}, "credits": {"balance": "0"}},
            "rateLimitResetCredits": {"availableCount": 2, "credits": []}}
        a = by_key(board.build_accounts(machines, CONFIG, NOW))["codex:personal@example.net"]
        self.assertEqual(a["source"], "Codex app server")
        self.assertEqual(a["capacity"]["resets"]["available"], 2)
        self.assertEqual(a["weekly"]["used"], 4)

    def test_old_state_without_billing_fields_still_renders(self):
        accounts = board.build_accounts(fleet(), CONFIG, NOW)
        for a in accounts:
            a.pop("capacity", None)
        page = board.render_html(accounts, CONFIG, NOW)
        self.assertIn("Resets available", page)
        self.assertIn("Unknown", page)

    def test_script_payload_cannot_close_script_tag(self):
        acc = board.build_accounts(fleet(), CONFIG, NOW)
        acc[0]["note"] = '</script><script>alert("x")</script>'
        page = board.render_html(acc, CONFIG, NOW)
        self.assertNotIn('</script><script>alert', page)
        self.assertIn('\\u003c/script>', page)

    def test_refresh_only_kicks_existing_usage_agents(self):
        config = {"machines": {"Local": {"local_path": "test"}}}
        with patch("gather.bounded_command") as run:
            run.return_value.returncode = 0
            self.assertEqual(gather.request_collection(config), [True])
            self.assertEqual(run.call_args.args[0][-1].split('/')[-1], "com.weekthink.usageboard.collect")


if __name__ == "__main__":
    unittest.main()
