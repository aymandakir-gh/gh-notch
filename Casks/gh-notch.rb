# Homebrew cask for gh-notch.
#
# Until releases are code-signed + notarized, sha256 is left unchecked and the
# app is unsigned (right-click → Open on first launch). Once a signed DMG ships,
# replace `sha256 :no_check` with the real checksum.
#
# Install (after the first release is published, via a tap repo named
# `homebrew-tap`):
#   brew tap aymandakir-gh/tap
#   brew install --cask gh-notch
cask "gh-notch" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/aymandakir-gh/gh-notch/releases/download/v#{version}/gh-notch-v#{version}.dmg"
  name "gh-notch"
  desc "Open-source macOS notch utility with a local-first AI command bar"
  homepage "https://github.com/aymandakir-gh/gh-notch"

  depends_on macos: ">= :sonoma"

  app "gh-notch.app"

  zap trash: [
    "~/Library/Preferences/company.gh.notch.plist",
  ]
end
