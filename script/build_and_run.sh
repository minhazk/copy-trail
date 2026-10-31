#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Run this script on a Mac. Linux supports source editing only." >&2
  exit 1
fi
mode="${1:-run}"
case "$mode" in
  run|--verify|--debug|--logs) ;;
  *) echo "Usage: $0 [run|--verify|--debug|--logs]" >&2; exit 2 ;;
esac
app="$PWD/dist/Copy Trail.app"
binary="$app/Contents/MacOS/CopyTrail"
# Stop only this checkout's app, preserving instances from other workspaces.
for pid in $(pgrep -x CopyTrail || true); do
  if [[ "$(ps -p "$pid" -o comm=)" == "$binary" ]]; then
    kill "$pid"
  fi
done
if [[ -x "$HOME/.local/bin/resource-run" ]]; then
  "$HOME/.local/bin/resource-run" --kind build -- ./scripts/build-app.sh
else
  ./scripts/build-app.sh
fi
case "$mode" in
  --debug) exec lldb -- "$binary" ;;
  --logs)
    open "$app"
    exec /usr/bin/log stream --info --style compact --predicate 'process == "CopyTrail"'
    ;;
  --verify)
    open "$app"
    sleep 2
    for pid in $(pgrep -x CopyTrail || true); do
      if [[ "$(ps -p "$pid" -o comm=)" == "$binary" ]]; then
        echo "Copy Trail is running (PID $pid)."
        exit 0
      fi
    done
    echo "Copy Trail did not remain running." >&2
    exit 1
    ;;
  *) open "$app" ;;
esac
