#!/bin/bash
# Full-module type-check of the app sources against the CommandLineTools macOS SDK.
# Catches type errors locally without Xcode (XCTest targets still need CI: the CLT
# toolchain ships no XCTest module). #Preview blocks are stripped in a temp copy —
# the CLT toolchain has no PreviewsMacros plugin. Usage: tools/typecheck.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macos14.0"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Mirror app sources, stripping top-level `#Preview {` ... `}` blocks (closing
# brace at column 0 — the repo's preview convention).
while IFS= read -r f; do
  mkdir -p "$TMP/$(dirname "$f")"
  awk '
    /^#Preview/ { skip = 1; next }
    skip && /^\}/ { skip = 0; next }
    !skip { print }
  ' "$f" > "$TMP/$f"
done < <(find gh-notch -name '*.swift' | sort)

cd "$TMP"
# shellcheck disable=SC2046
xcrun swiftc -typecheck \
  -sdk "$SDK" \
  -target "$TARGET" \
  -parse-as-library \
  $(find gh-notch -name '*.swift' | sort)

echo "typecheck OK ($(find gh-notch -name '*.swift' | wc -l | tr -d ' ') files)"
