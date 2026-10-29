# Provider artwork

The public app bundles these three identification images in `provider-logos/`.
They are loaded locally, including in the full HTML board; no image requests
are made while viewing account data. Retrieved October 29, 2026.

| File | Source |
| --- | --- |
| codex.png | https://raw.githubusercontent.com/steipete/CodexBar/5f93dc3068b3bee3f8753f3772614cc2949c335d/Sources/CodexBar/Resources/Brand-ProviderIcon-codex.png |
| claude.png | https://claude.com/icon.png |
| antigravity.png | https://antigravity.google/assets/image/antigravity-logo.png |

Codex uses the terminal/bloom product icon, rather than the ChatGPT knot.
Claude uses its orange starburst. Antigravity uses its multicolor arch.
Codex artwork is retained from the public CodexBar resource at commit `5f93dc3068b3bee3f8753f3772614cc2949c335d`;
its MIT notice is in `LICENSES/CodexBar-MIT.txt`. Provider trademarks and artwork
remain owned by their respective owners and are not relicensed by OVRCAST.
The marks identify supported services and do not imply endorsement.

Private extracted images in `providers/` and `devices/` remain excluded from
public packages. Device views use macOS system symbols when those optional
local images are absent. Only the three files explicitly listed in the source
export allowlist are redistributed.
