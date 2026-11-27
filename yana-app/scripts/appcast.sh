#!/usr/bin/env bash
# Signs the update and writes dist/updates/appcast.xml (with delta files from the earlier zips kept there).
# Usage: scripts/appcast.sh <version>   after scripts/package.sh <version>
# The private key stays in this Mac's Keychain, made once with Sparkle's generate_keys; it is never in the repo.
# SPARKLE_KEY_FILE=/path uses a key file instead (for trials with a throwaway key).
# Publish only .zip updates (see Package.swift).
set -euo pipefail
IFS=$'\n\t'

here="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "usage: appcast.sh 1.2.3" >&2
	exit 2
fi
tool="$here/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
zip="$here/dist/Yana-$version.zip"
updates="$here/dist/updates"
[[ -x "$tool" && -f "$zip" ]] || { echo "build first: scripts/package.sh $version" >&2; exit 2; }
mkdir -p "$updates"
cp "$zip" "$updates/"

prefix="${SPARKLE_DOWNLOAD_PREFIX:-https://github.com/Horonomos-laps/Yana-studio/releases/download/app-v$version/}"
args=("--download-url-prefix" "$prefix")
if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then args+=("--ed-key-file" "$SPARKLE_KEY_FILE"); fi
"$tool" "${args[@]}" "$updates"
echo "Upload to the app-v$version release: appcast.xml, Yana-$version.zip and the new .delta files in $updates"
