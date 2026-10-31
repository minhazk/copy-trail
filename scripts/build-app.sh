#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Copy Trail requires macOS 14+ and the Xcode command line tools." >&2
  exit 1
fi
configuration="${1:-debug}"
if [[ "$configuration" != debug && "$configuration" != release ]]; then
  echo "Usage: $0 [debug|release]" >&2
  exit 1
fi
build=(swift build -c "$configuration")
if [[ -n "${WORKSTATION_WORKERS:-}" ]]; then
  build+=(--jobs "$WORKSTATION_WORKERS")
fi
"${build[@]}"
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app="dist/Copy Trail.app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/CopyTrail" "$app/Contents/MacOS/CopyTrail"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "Built $PWD/$app"
