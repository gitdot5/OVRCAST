# OVRCAST icon construction

The icon is original vector artwork in `app/icon.svg`: two interlocking black
circular ribbons on a warm ivory rounded macOS tile, with a generous central
opening and transparent exterior. The palette is near-black `#171717` and
warm ivory `#f5f4f0`, with a subtle native tile edge and shadow.

The SVG is the editable master. `app/icon-master.png` and `app/icon_1024.png`
are its 1024-pixel renders. `app/build_icon.sh` packages the PNG into all standard
macOS ICNS sizes. The app loads the same bundled icon for its visible branding.

To edit the mark, modify the SVG, export a transparent 1024 by 1024 PNG as
`app/icon_1024.png`, then run `app/build_icon.sh`.
