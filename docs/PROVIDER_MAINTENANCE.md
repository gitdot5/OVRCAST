# Provider compatibility maintenance

The collector is a maintained pinned fork. Upstream releases are reviewed and
imported deliberately; installing OVRCAST does not require a CodexBar app.

## For a provider report or upstream change

1. Reproduce using the affected OVRCAST build and that person's own connection.
   Record only provider, source mode, structured failure category and counts.
   Opening sign-in is not a successful usage check. Do not collect credentials.
2. Determine whether the source reports missing software, signed-out/expired or
   unreadable credentials, local Keychain access denial, rate limiting, network
   failure or a changed response schema. Do not hide these by switching accounts
   or authentication sources automatically.
3. Compare the relevant public upstream code and official provider documentation
   against `vendor/OVRCASTCollector/UPSTREAM.json` and the dependency pins. Review
   auth/storage changes, network destinations, CLI side effects and licensing.
4. Create a fictional regression in `native/Tests/UsageBoardMenuBarTests/Fixtures/`.
   Preserve field types and semantics while using example-domain identities and
   no real access/refresh tokens, cookies, hostnames or raw personal diagnostics.
   Test successful reads and the failure that triggered the report.
5. Run focused Swift tests, then full Swift/Python suites when code changes.
   The source exporter verifies all pinned vendor file hashes. Update the vendor
   manifest only after reviewing an intentional patch, never to silence drift.
6. Rebuild from the clean export, test packaged resources and both architectures,
   then run the real provider check. Sign/notarize and verify the exact release
   archive. Retain unknown/stale values until a new provider reading confirms them.

## Repeatable commands

```sh
swift test --package-path native --filter ProviderContractTests
swift test --package-path native -j 2
python3 -m unittest discover -s tests
python3 script/export_source.py
python3 script/verify_release.py FINAL_ARCHIVE --notarized
```

CI runs the fixture contracts on Intel and Apple Silicon without provider sign-in.
Live checks and a human-reviewed credential/permission flow are separate release
evidence. The fixture suite does not establish compatibility with every plan or
future provider response. Review again when a concrete upstream change or user
failure occurs; do not rotate working credentials as a maintenance routine.
