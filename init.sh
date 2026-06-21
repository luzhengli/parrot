#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="Parrot.xcodeproj"
SCHEME="Parrot"
CONFIGURATION="Debug"
DESTINATION="platform=macOS"

OPEN_XCODE=false
SKIP_BUILD=false

for arg in "$@"; do
  case "$arg" in
    --open)
      OPEN_XCODE=true
      ;;
    --skip-build)
      SKIP_BUILD=true
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./init.sh [--open] [--skip-build]

Bootstraps the Parrot macOS project for a fresh agent or developer session.

Options:
  --open        Open Parrot.xcodeproj in Xcode after checks.
  --skip-build  List project metadata but skip the Debug build.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Run ./init.sh --help for usage." >&2
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"

echo "=== Parrot initialization ==="
echo "Root: $ROOT_DIR"
echo "Project: $PROJECT_FILE"
echo "Scheme: $SCHEME"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is not available. Install full Xcode before continuing." >&2
  exit 1
fi

DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVELOPER_DIR" != *"/Xcode.app/Contents/Developer"* ]]; then
  echo "warning: active developer directory is '$DEVELOPER_DIR'."
  echo "If the build fails because Command Line Tools are selected, run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

echo
echo "=== Project metadata ==="
xcodebuild -list -project "$PROJECT_FILE"

if [[ "$SKIP_BUILD" == false ]]; then
  echo
  echo "=== Debug build ==="
  xcodebuild \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO \
    build
else
  echo
  echo "Skipping build because --skip-build was provided."
fi

if [[ "$OPEN_XCODE" == true ]]; then
  echo
  echo "=== Opening Xcode ==="
  open "$PROJECT_FILE"
fi

echo
echo "=== Environment ready ==="
echo "Next files to read: parrot-progress.md and feature_list.json"
