# Homebrew cask for gh-notch.
#
# Until releases are code-signed + notarized, sha256 is left unchecked and the
# app is unsigned (right-click → Open on first launch). Once a signed DMG ships,
# pin `version` + real `sha256` per release.
#
# The release workflow always names the asset `gh-notch.dmg`, so this cask
# tracks the stable /releases/latest/download URL and needs no per-version
# edits while releases are unsigned.
#
# Install (via a tap repo named `homebrew-tap`):
#   brew tap aymandakir-gh/tap
#   brew install --cask gh-notch
cask "gh-notch" do
  version :latest
  sha256 :no_check

  url "https://github.com/aymandakir-gh/gh-notch/releases/latest/download/gh-notch.dmg"
  name "gh-notch"
  desc "Open-source macOS notch utility with a local-first AI command bar"
  homepage "https://github.com/aymandakir-gh/gh-notch"

  depends_on macos: ">= :sonoma"

  app "gh-notch.app"

  zap trash: [
    "~/Library/Preferences/company.gh.notch.plist",
  ]
end
