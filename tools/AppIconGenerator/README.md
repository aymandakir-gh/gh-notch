# AppIcon generator

The gh-notch app icon is generated programmatically (no Figma/Sketch source, no
binary design files to drift) so it stays fully reproducible from one Swift file.

The design: a dark squircle (superellipse, macOS Big Sur style) with a white
"notch" pill hanging from the top edge and a four-point AI sparkle — echoing the
command bar's `sparkle.magnifyingglass` motif. Shipped colorway: deep blue-indigo.

## Regenerate the shipped icon

From the repo root:

```bash
swift tools/AppIconGenerator/make_icon.swift
```

This rewrites the ten PNG slots in
`gh-notch/Resources/Assets.xcassets/AppIcon.appiconset/` in place.

## Explore colorway variants

```bash
swift tools/AppIconGenerator/make_icon.swift variants   # → /tmp/ghicon/variants/*.png
```

To ship a different colorway, change `shippedStyleIndex` in `make_icon.swift`
and regenerate.
