#!/usr/bin/env bash
#
# Rewrite version.json to the current sprites.dev release.
#
# This downloads no binary. The sha256 in the upstream manifest is the digest of
# the exact file fetchurl fetches, so the script converts three hex digests to
# SRI form and stops there.
#
# Do NOT resolve the version from client/release.txt or client/rc.txt. Both are
# legacy: release.txt is gone, and rc.txt is pinned at the last build of the old
# scheme. Reading either is what froze nixpkgs and jamiebrynes7/sprite-cli-nix.
#
# Exit codes:
#   0   version.json already names the current release, or it was rewritten
#   10  --check only: an update is available
#   1   anything went wrong
#
# Run it from the repository, or set SPRITE_VERSION_JSON to the target file.
set -euo pipefail

base="https://sprites-binaries.t3.storage.dev"

if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  root="$PWD"
fi
out="${SPRITE_VERSION_JSON:-$root/version.json}"

check_only=0
case "${1:-}" in
  --check) check_only=1 ;;
  "") ;;
  *)
    echo "usage: update-version.sh [--check]" >&2
    exit 1
    ;;
esac

for tool in curl jq nix; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "update-version: required command not found: $tool" >&2
    exit 1
  fi
done

version="$(curl -fsSL "$base/client/latest")"
if [ -z "$version" ]; then
  echo "update-version: $base/client/latest returned nothing" >&2
  exit 1
fi
# Guard the instrument. A wrong or truncated body must not become a version.
case "$version" in
  *[!0-9A-Za-z._-]* | "")
    echo "update-version: refusing an unusable version string: $version" >&2
    exit 1
    ;;
esac

current=""
if [ -f "$out" ]; then
  current="$(jq -r '.version // ""' "$out")"
fi

if [ "$version" = "$current" ]; then
  echo "sprite: already at $version"
  exit 0
fi

if [ "$check_only" -eq 1 ]; then
  echo "sprite: ${current:-none} -> $version (update available)"
  exit 10
fi

manifest="$(curl -fsSL "$base/client/$version/manifest.json")"

sri_for() {
  local asset="$1" digest
  digest="$(printf '%s' "$manifest" | jq -er --arg a "$asset" '.platforms[$a].digest')"
  if ! printf '%s' "$digest" | grep -Eq '^[0-9a-f]{64}$'; then
    echo "update-version: $asset digest is not a sha256: $digest" >&2
    exit 1
  fi
  nix hash convert --hash-algo sha256 --to sri "$digest"
}

darwin_aarch64="$(sri_for macos-aarch64)"
linux_x86_64="$(sri_for linux-x86_64)"
linux_aarch64="$(sri_for linux-aarch64)"

jq -n \
  --arg version "$version" \
  --arg da "$darwin_aarch64" \
  --arg lx "$linux_x86_64" \
  --arg la "$linux_aarch64" \
  '{
     version: $version,
     platforms: {
       "aarch64-darwin": { asset: "macos-aarch64", hash: $da },
       "x86_64-linux":   { asset: "linux-x86_64",  hash: $lx },
       "aarch64-linux":  { asset: "linux-aarch64", hash: $la }
     }
   }' > "$out"

echo "sprite: ${current:-none} -> $version"
