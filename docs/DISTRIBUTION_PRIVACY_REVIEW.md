# Distribution privacy review — November 3, 2026

Scope: accidental exposure of the publisher's accounts, API credentials and
private OVRCAST data through public releases and repository history. This is a
focused distribution check, not a new independent audit of all collector code.

## Results

- Downloaded and SHA-256 verified all 28 assets from the seven releases through
  0.4.2. Inspected 5,655 archive entries/Git objects, including 1,311 public source
  blobs, published tags and the public pull-request head.
- No user account credential, private signing key, SSH key or private OVRCAST
  snapshot/configuration file was established in those downloads or source blobs.
- Compared 13 private OVRCAST configuration/state file fingerprints: no exact
  private-file matches. Private account email and unique host checks found no
  payload/source matches. Generic Mac-family labels and /dev/null were excluded
  as non-private matches.
- Reviewed the 22 token/credential-shaped candidate groups in context. They were
  synthetic test inputs, schema/storage-key strings, interpolation/error text or
  compiler build-path metadata. Discovered values were not used to contact any
  service or test account access.
- OCR reviewed all four distinct bundled preview images: only example-domain
  emails or privacy labels, with Demo/example markings.
- Configured remote computers are empty for a new native install. The shared
  config.json has a local path relative to the downloader's home, empty account
  expectations and no private SSH target or credential.
- Provider authentication resolves the running user's provider software, home
  directory, environment and local Keychain. It does not reference the
  publisher's account state. Optional SSH reads require the downloader's own
  configured alias and credentials, with host-key checks and forwarding disabled.
- No publisher-hosted usage backend or account-access credential is provided to
  downloaders. The bundled collector rejects its server and mutation entrypoints.

## Metadata hardening in 0.4.3

The 0.4.1 and 0.4.2 GUI binaries contained compiler source/build paths identifying
an earlier developer home directory. These paths do not contain file contents or
authenticate an account. Version 0.4.3 rebuilds the GUI from the clean temporary
source export and passes the new binary/resource payload check for developer
home paths, private filenames and credential-shaped material.

The release verifier now rejects these categories before distribution. Four
regressions cover private files, home-path metadata, credential-shaped bytes,
and permitted public identifiers. All 98 Python tests passed; application Swift
logic is unchanged from the 68-test, hosted-CI-validated 0.4.2 release.

The source/export and both executable architecture slices are verified; the
final app is Developer ID signed, Apple notarized and Gatekeeper assessed.
Published asset checksums are compared before and after publication.

## Public publisher information

Developer ID certificate identity, Apple Team ID, GitHub identity and historical
Git authorship remain public attribution. Public certificates and OAuth client
identifiers are not account passwords or private signing keys. Future commits
in this public checkout use the GitHub no-reply address. Historical attribution
was not rewritten and older immutable builds may retain the build metadata
noted above. This review does not claim publisher anonymity or zero software
vulnerabilities.

Private OVRCAST state, provider credentials and SSH configuration remain local.
Users must connect their own accounts; downloading OVRCAST does not transfer
access to the publisher's accounts, devices, API allowance or billing.
