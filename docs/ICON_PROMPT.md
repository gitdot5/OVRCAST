# OVRCAST icon construction

The original vector artwork in `app/icon.svg` reflects the app's job: bring AI
allowances across accounts into one clear overview. Three account tracks share
an O-shaped ring. Each dark arc represents remaining capacity; the pale part
completes its track. The open center keeps the mark readable at small sizes.
These are illustrative proportions, not live readings or provider identities.

The palette is near-black `#171717`, warm ivory `#f5f4f0` and a pale neutral
`#d7d6d0`. A rounded native macOS tile has a transparent exterior, subtle edge
and shadow. No needle, traffic-light colors, provider logos or lettering.

The SVG is the editable master. `app/icon-master.png` and `app/icon_1024.png`
are its 1024-pixel renders. `app/build_icon.sh` packages the PNG into all standard
macOS ICNS sizes. The app loads the same bundled icon for its visible branding.

To edit the mark, modify the SVG, export a transparent 1024 by 1024 PNG as
`app/icon_1024.png`, then run `app/build_icon.sh`.
