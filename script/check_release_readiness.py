#!/usr/bin/env python3
"""Check the exact candidate against the stable or manual-preview release gates.

This checks the acceptance record; it does not replace the underlying tests.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REQUIRED = {'local_tests', 'hosted_build', 'package_integrity', 'live_providers',
            'notification_delivery', 'updater_dialogs', 'upgrade_recovery',
            'intel_runtime', 'minimum_macos', 'sleep_network_endurance',
            'accessibility', 'resource_use', 'opt_in_beta', 'agent_interface', 'token_activity'}
MANUAL_PREVIEW_DEFERRED = {'sleep_network_endurance', 'accessibility', 'resource_use', 'opt_in_beta'}


def blockers(record, version, artifact, *, manual_preview=False):
    result = []
    if (record.get('version'), record.get('build')) != (version['version'], version['build']):
        result.append('Acceptance record belongs to a different app version/build')
    required = REQUIRED
    if manual_preview:
        approved_hash = record.get('manualPreview', {}).get('approvedSha256')
        if not approved_hash or approved_hash != record.get('sha256'):
            result.append('Manual preview approval must match the accepted archive SHA-256')
        required = REQUIRED - MANUAL_PREVIEW_DEFERRED
    checks = record.get('checks', {})
    for name in sorted(required):
        check = checks.get(name, {})
        evidence = check.get('evidence')
        if check.get('status') != 'pass' or not isinstance(evidence, str) or not evidence.strip():
            result.append(name + ': reviewed passing evidence is required')
    if not artifact.is_file():
        result.append('Candidate archive is missing')
    elif record.get('sha256') != hashlib.sha256(artifact.read_bytes()).hexdigest():
        result.append('Candidate archive does not match the accepted SHA-256')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--manual-preview', action='store_true',
                        help='Check a GitHub prerelease for direct download only, with no update feed')
    args = parser.parse_args()
    record = json.loads((ROOT / 'app/release-readiness.json').read_text())
    version = json.loads((ROOT / 'app/version.json').read_text())
    problems = blockers(record, version, args.archive, manual_preview=args.manual_preview)
    print(json.dumps({'publicationAllowed': not problems, 'blockers': problems}, indent=2))
    raise SystemExit(1 if problems else 0)
