"""Release checks exercise the boundary between private files and shared source."""
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
                for excluded in ('config.local.json', 'state/', '.git/', 'backups/',
                                 'assets/providers/', 'assets/devices/', 'DESIGN.md'):
                    self.assertFalse(any(excluded in name for name in names), excluded)
                self.assertEqual(archive.testzip(), None)


if __name__ == '__main__':
    unittest.main()
