"""Release checks exercise the boundary between private files and shared source."""
import hashlib
from unittest.mock import patch
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('source_export', ROOT / 'script/export_source.py')
source_export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source_export)


class SourceExportTest(unittest.TestCase):
    def test_private_account_is_rejected_without_echoing_it(self):
        # Build the value in parts so the release scanner can scan its own tests.
        private = 'owner@' + 'private.invalid'
        with self.assertRaises(ValueError) as error:
            source_export.validate_text('sample.txt', private)
        self.assertNotIn(private, str(error.exception))

    def test_private_home_path_is_rejected(self):
        with self.assertRaises(ValueError):
            source_export.validate_text('sample.txt', '/Users/' + 'private-user/config')

    def test_credential_is_rejected_outside_the_exact_test_file(self):
        dummy = source_export.DUMMY_CREDENTIALS[0]
        with self.assertRaises(ValueError):
            source_export.validate_text('README.md', dummy)
        source_export.validate_text('tests/test_collect.py', dummy)

    def test_export_contains_license_and_excludes_private_material(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'source.zip'
            source_export.export(ROOT, output)
            with zipfile.ZipFile(output) as archive:
                names = archive.namelist()
                self.assertIn('usage_board/LICENSE', names)
                self.assertIn('usage_board/LICENSES/CodexBar-MIT.txt', names)
                self.assertIn('usage_board/config.json', names)
                self.assertIn('usage_board/SHA256SUMS', names)
                for provider in ('codex', 'claude', 'antigravity'):
                    self.assertIn('usage_board/assets/provider-logos/' + provider + '.png', names)
                for excluded in ('config.local.json', 'state/', '.git/', 'backups/',
                                 'assets/providers/', 'assets/devices/', 'DESIGN.md'):
                    self.assertFalse(any(excluded in name for name in names), excluded)
                self.assertEqual(archive.testzip(), None)

    def test_vendor_integrity_and_explicit_allowlist(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            vendor = root / 'vendor/OVRCASTCollector'
            vendor.mkdir(parents=True)
            public = vendor / 'LICENSE'
            public.write_text('Public upstream license')
            (vendor / 'private.local').write_text('unlisted private state')
            (vendor / '.build').mkdir()
            (vendor / '.build/artifact').write_text('generated output')
            digest = hashlib.sha256(public.read_bytes()).hexdigest()
            (vendor / 'FILE_MANIFEST.sha256').write_text(digest + '  LICENSE\n')
            with patch.object(source_export, 'FILES', ()), patch.object(source_export, 'TREES', {}):
                files = source_export.source_files(root)
                self.assertEqual(list(files), ['vendor/OVRCASTCollector/LICENSE'])
                public.write_text('tampered')
                with self.assertRaisesRegex(ValueError, 'integrity mismatch'):
                    source_export.source_files(root)


if __name__ == '__main__':
    unittest.main()
