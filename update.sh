#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "[*] Polling upstream GitHub releases..."
RELEASES=$(curl -s https://api.github.com/repos/brave/brave-browser/releases?per_page=30)

get_asset() {
  local prefix=$1
  echo "$RELEASES" | jq -r "[.[].assets[] | select(.name != null) | select(.name | startswith(\"$prefix\") and endswith(\"_amd64.deb\"))] | .[0] // empty"
}

get_ver() { echo "$1" | jq -r '.name' | sed -E 's/.*_([0-9.]+)_amd64\.deb/\1/'; }
get_url() { echo "$1" | jq -r '.browser_download_url'; }
get_hash() { nix-hash --to-sri --type sha256 "$(nix-prefetch-url --type sha256 "$1")"; }

STABLE_ASSET=$(get_asset "brave-browser_")
BETA_ASSET=$(get_asset "brave-browser-beta_")
ORIGIN_ASSET=$(get_asset "brave-origin_")
ORIGIN_BETA_ASSET=$(get_asset "brave-origin-beta_")

cat >versions.json <<EOF
{
  "brave": {
    "version": "$(get_ver "$STABLE_ASSET")",
    "url": "$(get_url "$STABLE_ASSET")",
    "hash": "$(get_hash "$(get_url "$STABLE_ASSET")")"
  },
  "brave-beta": {
    "version": "$(get_ver "$BETA_ASSET")",
    "url": "$(get_url "$BETA_ASSET")",
    "hash": "$(get_hash "$(get_url "$BETA_ASSET")")"
  },
  "brave-origin": {
    "version": "$(get_ver "$ORIGIN_ASSET")",
    "url": "$(get_url "$ORIGIN_ASSET")",
    "hash": "$(get_hash "$(get_url "$ORIGIN_ASSET")")"
  },
  "brave-origin-beta": {
    "version": "$(get_ver "$ORIGIN_BETA_ASSET")",
    "url": "$(get_url "$ORIGIN_BETA_ASSET")",
    "hash": "$(get_hash "$(get_url "$ORIGIN_BETA_ASSET")")"
  }
}
EOF

echo "[+] configuration update complete."
