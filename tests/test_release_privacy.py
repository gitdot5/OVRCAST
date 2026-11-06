"""Release payloads must not carry account state or developer-specific metadata."""
import importlib.util
from pathlib import Path
import unittest
import io
import zipfile

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('release_verify', ROOT / 'script/verify_release.py')
release_verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_verify)


class ReleasePrivacyTest(unittest.TestCase):
    def test_private_home_metadata_is_rejected_without_echoing_it(self):
        private_path = '/Users/' + 'sample-owner/private-project'
        with self.assertRaises(ValueError) as result:
            release_verify.reject_private_payload('Contents/MacOS/App', private_path.encode())
        self.assertNotIn(private_path, str(result.exception))

    def test_private_account_files_are_rejected(self):
        for name in ['Contents/Resources/config.local.json', 'Contents/Resources/auth.json',
                     'Contents/Resources/.env', 'Contents/Resources/connection-readings.json', 'Contents/Resources/connection-health.json', 'Contents/Resources/overview.json', 'Contents/Resources/native-overview.json', 'Contents/Resources/history.json', 'Contents/Resources/signing.p12', 'Contents/Resources/snapshot.json']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                release_verify.reject_private_payload(name, b'{}')

    def test_credential_material_is_rejected_without_echoing_it(self):
        dummy = ('sk-' + 'A' * 32).encode()
        with self.assertRaises(ValueError) as result:
            release_verify.reject_private_payload('Contents/MacOS/App', dummy)
        self.assertNotIn(dummy.decode(), str(result.exception))

    def test_public_identifiers_are_not_treated_as_account_access(self):
        release_verify.reject_private_payload('Contents/Info.plist', b'com.weekthink.usageboard')
        release_verify.reject_private_payload('Contents/Resources/notice.txt', b'Developer ID Application; public certificate metadata')

    def test_archive_links_must_remain_inside_the_app(self):
        for name, target, allowed in [
            ('OVRCAST.app/Contents/Frameworks/Sparkle.framework/Versions/Current', 'B', True),
            ('OVRCAST.app/Contents/Frameworks/Sparkle.framework/Sparkle', 'Versions/Current/Sparkle', True),
            ('OVRCAST.app/Contents/bad', '../../../../outside', False),
            ('OVRCAST.app/Contents/bad', '/tmp/outside', False),
            ('../outside', None, False),
        ]:
            stream = io.BytesIO()
            with zipfile.ZipFile(stream, 'w') as archive:
                info = zipfile.ZipInfo(name)
                if target is not None: info.external_attr = 0o120777 << 16
                archive.writestr(info, target or '')
            stream.seek(0)
            with zipfile.ZipFile(stream) as archive:
                if allowed: release_verify.validate_archive_paths(archive)
                else:
                    with self.assertRaises(ValueError): release_verify.validate_archive_paths(archive)


if __name__ == '__main__':
    unittest.main()
