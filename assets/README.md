# Optional local identity artwork

The public source archive excludes the PNGs described below. Native views use
macOS system-symbol fallbacks and the HTML dashboard retains text labels when
optional images are absent. Third-party artwork is outside the project's MIT
license. Do not redistribute extracted images merely because they exist locally.

These PNGs are exported at 128 pixels from the installed native assets using
macOS `sips`. They are embedded in the generated HTML as data URIs; the board
makes no network requests for images.

| File | Local source |
| --- | --- |
| providers/codex.png | /Applications/ChatGPT.app/Contents/Resources/app.icns |
| providers/claude.png | /Applications/Claude.app/Contents/Resources/electron.icns |
| providers/antigravity.png | /Applications/Antigravity.app/Contents/Resources/icon.icns |
| devices/macbook.png | /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbookpro-16-2021-space-gray.icns |
| devices/mac-mini.png | /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macmini-2020.icns |
| devices/mac-studio.png | /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macstudio.icns |

Hardware images represent the machine family, not a verified generation or color.
Provider and Apple artwork retain their original ownership. These assets document
this private local prototype; commercial distribution rights are not established
by their availability on this Mac.
