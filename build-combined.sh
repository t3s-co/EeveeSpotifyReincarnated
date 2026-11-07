#!/usr/bin/env bash
set -euo pipefail
VANILLA_IPA="${1:-}"
[ -n "$VANILLA_IPA" ] && [ -f "$VANILLA_IPA" ] || { echo "usage: $0 <path/to/Spotify-vanilla.ipa>" >&2; exit 1; }

EEVEE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPOTIPW_DIR="${SPOTIPW_DIR:-$EEVEE_DIR/../spoti.pw-0.51.0/spoti.pw-0.51.0/tweak}"
OUT_DIR="$EEVEE_DIR/Outputs/IPAS"
mkdir -p "$OUT_DIR"

EEVEE_VER=$(grep -E '^Version:' "$EEVEE_DIR/control" | awk '{print $2}')
SPOTIPW_VER=$(cat "$SPOTIPW_DIR/../version.txt" 2>/dev/null || echo "0.22.0")
SPOT_VER=$(unzip -p "$VANILLA_IPA" 'Payload/Spotify.app/Info.plist' | plutil -extract CFBundleShortVersionString raw - 2>/dev/null || echo "unknown")
OUT_IPA="$OUT_DIR/Spotify-Combined-Eevee${EEVEE_VER}-SpotiPw${SPOTIPW_VER}-${SPOT_VER}.ipa"

[ -n "${THEOS:-}" ] || { [ -d "$HOME/theos" ] && export THEOS="$HOME/theos" || { echo "THEOS not set"; exit 1; }; }
color() { printf '\033[1;32m==> %s\033[0m\n' "$*"; }

color "1/8  Building spoti.pw..."
cd "$SPOTIPW_DIR"
THEOS_PACKAGE_SCHEME=rootless make package FINALPACKAGE=1
SPOTIPW_DEB=$(ls -t "$SPOTIPW_DIR/../packages/com.spotipw_"*.deb 2>/dev/null | head -1)
[ -n "$SPOTIPW_DEB" ] || { echo "spoti.pw deb not produced"; exit 1; }

color "2/8  Building EeveeSwiftProtobuf..."
cd "$EEVEE_DIR"
chmod +x Tools/SwiftProtobufBuild/build-eeveeswiftprotobuf.sh
Tools/SwiftProtobufBuild/build-eeveeswiftprotobuf.sh

color "3/8  Building EeveeSpotify..."
THEOS_PACKAGE_SCHEME=rootless make package FINALPACKAGE=1
EEVEE_DEB=$(ls -t "$EEVEE_DIR/packages/com.eevee.spotify_"*.deb 2>/dev/null | head -1)
[ -n "$EEVEE_DEB" ] || { echo "Eevee deb not produced"; exit 1; }

color "4/8  Building zxPluginsInject..."
chmod +x Tools/build-zxpi.sh
Tools/build-zxpi.sh >/dev/null

color "5/8  Extracting both .debs..."
EXTRACT_DIR="$EEVEE_DIR/Outputs/combined-extract"
rm -rf "$EXTRACT_DIR"; mkdir -p "$EXTRACT_DIR"
dpkg-deb -R "$SPOTIPW_DEB" "$EXTRACT_DIR/spotipw"
dpkg-deb -R "$EEVEE_DEB" "$EXTRACT_DIR/eevee"
SPOTIPW_DYLIB=$(find "$EXTRACT_DIR/spotipw" -name 'spotifyglass.dylib' | head -1)
EEVEE_DYLIB=$(find "$EXTRACT_DIR/eevee" -name 'EeveeSpotify.dylib' | head -1)
EEVEE_BUNDLE=$(find "$EXTRACT_DIR/eevee" -type d -name 'EeveeSpotify.bundle' | head -1)
EEVEE_FW=$(find "$EXTRACT_DIR/eevee" -type d -name 'EeveeSwiftProtobuf.framework' | head -1)
[ -n "$SPOTIPW_DYLIB" ] || { echo "spotifyglass.dylib not found"; exit 1; }
[ -n "$EEVEE_DYLIB" ]   || { echo "EeveeSpotify.dylib not found"; exit 1; }

color "6/8  cyan inject..."
INJECT=("$SPOTIPW_DYLIB" "$EEVEE_DYLIB")
[ -n "$EEVEE_FW" ]    && INJECT+=("$EEVEE_FW")
[ -n "$EEVEE_BUNDLE" ] && INJECT+=("$EEVEE_BUNDLE")
rm -f "$OUT_IPA"
cyan -i "$VANILLA_IPA" -o "$OUT_IPA" -f "${INJECT[@]}" -c 9 -m 15.0 -du

color "7/8  ipapatch zxPluginsInject..."
ipapatch --input "$OUT_IPA" --inplace --noconfirm --dylib "$EEVEE_DIR/packages/zxPluginsInject.dylib"

color "8/8  Cleanup & icons..."
cd "$OUT_DIR"
rm -rf Payload
unzip -q "$(basename "$OUT_IPA")"
rm -rf Payload/Spotify.app/Watch Payload/Spotify.app/com.apple.WatchPlaceholder 2>/dev/null || true
zip -qry "$(basename "$OUT_IPA")" Payload
rm -rf Payload
chmod +x "$EEVEE_DIR/Tools/alt-icons.sh"
"$EEVEE_DIR/Tools/alt-icons.sh" "$OUT_IPA"
color "Done!"
ls -lh "$OUT_IPA"
