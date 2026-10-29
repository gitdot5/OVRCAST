# Security policy

## Supported versions

Security fixes target the latest published OVRCAST preview. Earlier previews
should be updated before reporting a problem.

## Report a vulnerability privately

Use the **Report a vulnerability** button in this repository's Security tab:
https://github.com/gitdot5/OVRCAST/security/advisories/new

Include the app version, macOS version, affected component and minimal
reproduction steps. Use example accounts and sanitized output. Never send
provider credentials, private snapshots, SSH keys or unredacted account logs.
Do not post sensitive reports in public issues.

## Trust boundaries

OVRCAST reads local usage through a separately installed CodexBar companion.
Optional remote reads use SSH aliases configured by the user. It does not
install SSH keys, trust unknown hosts, run an OVRCAST server, redeem resets,
buy credits or start model work. Provider tools have their own network and
credential behavior. Local snapshots contain private account and usage data.

Apple notarization and the release checks are bounded checks; source review has the scope and limits described below.

## Review status

An independent automated baseline reviewed all 60 text files in the initial
0.3.0 source release, followed by a bounded review of the 0.3.1 changes. The
review found one low-severity memory-exhaustion issue in optional legacy SSH
collection. Version 0.3.1 bounds combined stdout/stderr and local snapshot reads
to 4,000,000 bytes, preserves last-good readings on failure, and adds regression
tests. No other reportable finding was established in the reviewed source.
This is an automated source review, not an external human security certification.
