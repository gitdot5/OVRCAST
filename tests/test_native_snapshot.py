import unittest
import json
from test_board import fleet, CONFIG, NOW, by_key
import board
import native_snapshot

class NativeSnapshotTest(unittest.TestCase):
    def test_authentication_failure_is_explicit_in_native_snapshot(self):
        machines = fleet()
        for row in machines['Mini']['snapshot']['codexbar']['rows']:
            if row.get('provider') == 'claude':
                row['error'] = {'kind': 'authentication', 'message': 'Claude usage sign-in required.'}
        accounts = board.build_accounts(machines, CONFIG, NOW)
        row = next(a for a in native_snapshot.build(accounts, NOW)['accounts'] if a['id'] == 'claude:personal@example.net')
        self.assertTrue(row['requiresSignIn'])
        self.assertEqual(row['status'], 'Sign in required')

    def test_preserves_all_accounts_and_quota_labels(self):
        accounts = board.build_accounts(fleet(), CONFIG, NOW)
        snapshot = native_snapshot.build(accounts, NOW)
        self.assertEqual(len(snapshot['accounts']), len(accounts))
        claude = next(a for a in snapshot['accounts'] if a['id'] == 'claude:team@example.com')
        self.assertEqual([q['label'] for q in claude['quotas']], ['5-hour', 'Weekly', 'Fable only'])
        self.assertEqual(snapshot['version'], 1)
        json.dumps(snapshot)

    def test_unknown_and_zero_reset_counts_stay_distinct(self):
        accounts = board.build_accounts(fleet(), CONFIG, NOW)
        accounts[0]['capacity'] = {'resets': {'available': 0}}
        snapshot = native_snapshot.build(accounts, NOW)
        rows = {a['id']: a for a in snapshot['accounts']}
        self.assertEqual(rows[accounts[0]['key']]['savedResets'], 0)
        self.assertTrue(any(a['savedResets'] is None for a in rows.values()))

    def test_failed_reading_is_not_fresh(self):
        accounts = board.build_accounts(fleet(), CONFIG, NOW)
        a = next(a for a in native_snapshot.build(accounts, NOW)['accounts'] if a['id'] == 'claude:personal@example.net')
        self.assertFalse(a['fresh'])
        self.assertNotEqual(a['status'], 'Available')
        self.assertTrue(all(p['value'] == 'Unknown' for p in a['credits']))
