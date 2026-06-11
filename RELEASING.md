# Releasing gh-notch

Releases are built by `.github/workflows/release.yml`, triggered by pushing a
`v*` tag. The same workflow handles both the unsigned (pre-enrollment) and the
signed + notarized (post-enrollment) cases.

## TL;DR

```bash
git tag v0.1.0
git push origin v0.1.0
```

A GitHub Release is created with a `.dmg` attached.

## Two modes

### Unsigned (today, before Apple Developer Program enrollment)

With no signing secrets configured, the workflow builds an **unsigned** DMG.
Users must bypass Gatekeeper manually: right-click the app → **Open** → **Open**.
This is fine for testing and early adopters, **not** for a public "just works"
release.

### Signed + notarized (after enrollment)

This is the requirement for a real public release — without it macOS Gatekeeper
blocks the app on other people's machines. It needs:

1. **A paid Apple Developer Program membership** ($99/yr) for GH S.R.L. — this is
   the gating business decision. A free Apple ID cannot sign for distribution.
2. A **Developer ID Application** certificate exported as a `.p12`.
3. An **app-specific password** for the Apple ID used to notarize.

Add these as repository secrets (Settings → Secrets and variables → Actions):

| Secret | What it is |
|---|---|
| `MACOS_CERTIFICATE_P12_BASE64` | `base64 -i DeveloperID.p12` output |
| `MACOS_CERTIFICATE_PASSWORD` | password set when exporting the .p12 |
| `MACOS_SIGNING_IDENTITY` | e.g. `Developer ID Application: GH S.R.L. (TEAMID)` |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_TEAM_ID` | 10-character team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | app-specific password from appleid.apple.com |

Once these exist, the next `v*` tag produces a signed, notarized, stapled DMG
that opens cleanly on any Mac.

## Distribution channels (later)

- **GitHub Releases** — the DMG is attached automatically.
- **Homebrew cask** — a `gh-notch.rb` cask pointing at the release DMG (the
  README already advertises `brew install --cask gh-notch`). Add once releases
  are signed.

## Status

- [x] Release workflow (builds + packages DMG)
- [x] Unsigned DMG path
- [ ] Apple Developer Program enrollment (blocks signed releases)
- [ ] Signing secrets configured
- [ ] First signed + notarized release
- [ ] Homebrew cask
