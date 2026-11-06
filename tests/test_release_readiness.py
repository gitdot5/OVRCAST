import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('readiness', ROOT / 'script/check_release_readiness.py')
readiness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(readiness)


class ReleaseReadinessTests(unittest.TestCase):
    def record(self, data):
        return {'version': '1.0', 'build': '5', 'sha256': hashlib.sha256(data).hexdigest(),
                'checks': {name: {'status': 'pass', 'evidence': 'Reviewed fixture evidence'} for name in readiness.REQUIRED}}

    def test_exact_artifact_and_all_evidence_are_required(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'candidate.zip'; archive.write_bytes(b'fixture archive')
            record = self.record(archive.read_bytes())
            self.assertEqual(readiness.blockers(record, {'version': '1.0', 'build': '5'}, archive), [])
            archive.write_bytes(b'different archive')
            self.assertTrue(readiness.blockers(record, {'version': '1.0', 'build': '5'}, archive))

    def test_pending_or_unsubstantiated_gate_cannot_pass(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'candidate.zip'; archive.write_bytes(b'fixture archive')
            for state, evidence in [('pending', ''), ('pass', ''), ('pass', None),
                                    ('pass', True), ('pass', {}), ('failed', 'Reviewed failure')]:
                record = self.record(archive.read_bytes())
                record['checks']['live_providers'] = {'status': state, 'evidence': evidence}
                self.assertTrue(readiness.blockers(record, {'version': '1.0', 'build': '5'}, archive))

    def test_old_build_or_missing_archive_cannot_pass(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'missing.zip'
            record = self.record(b'fixture archive')
            self.assertTrue(readiness.blockers(record, {'version': '1.0', 'build': '6'}, archive))


if __name__ == '__main__':
    unittest.main()
