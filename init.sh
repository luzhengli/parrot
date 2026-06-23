#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="Parrot.xcodeproj"
SCHEME="Parrot"
CONFIGURATION="Debug"
DESTINATION="platform=macOS"
DERIVED_DATA_PATH="$ROOT_DIR/.DerivedData"
BUNDLE_IDENTIFIER="com.example.parrot"
APP_NAME="Parrot.app"

OPEN_XCODE=false
SKIP_BUILD=false
RUN_APP=false
STOP_APP=false
RESET_SCREEN_CAPTURE=false
ALLOW_SIGNING=false

for arg in "$@"; do
  case "$arg" in
    --open)
      OPEN_XCODE=true
      ;;
    --run)
      RUN_APP=true
      STOP_APP=true
      ;;
    --stop)
      STOP_APP=true
      ;;
    --skip-build)
      SKIP_BUILD=true
      ;;
    --reset-screen-capture)
      RESET_SCREEN_CAPTURE=true
      ;;
    --signed)
      ALLOW_SIGNING=true
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./init.sh [--open] [--run] [--stop] [--skip-build] [--reset-screen-capture] [--signed]

Bootstraps the Parrot macOS project for a fresh agent or developer session.

Options:
  --open                  Open Parrot.xcodeproj in Xcode after checks.
  --run                   Stop old Parrot instances, build, and open the fixed Debug app.
  --stop                  Stop old Parrot instances before continuing.
  --skip-build            List project metadata but skip the Debug build.
  --reset-screen-capture  Reset macOS Screen Recording permission for Parrot.
  --signed                Build with normal Xcode signing instead of CODE_SIGNING_ALLOWED=NO.

Debug workflow:
  ./init.sh --run

The debug workflow always builds into ./.DerivedData and opens that exact app bundle
to avoid multiple DerivedData copies confusing macOS Screen Recording permissions or
Carbon global shortcut registration. The Debug app is ad-hoc signed with a stable
local designated requirement so Screen Recording grants can survive rebuilds.
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
echo "DerivedData: $DERIVED_DATA_PATH"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is not available. Install full Xcode before continuing." >&2
  exit 1
fi

DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVELOPER_DIR" != */Xcode*.app/Contents/Developer ]]; then
  echo "warning: active developer directory is '$DEVELOPER_DIR'."
  echo "If the build fails because Command Line Tools are selected, run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

echo
echo "=== Project metadata ==="
xcodebuild -list -project "$PROJECT_FILE"

stop_parrot() {
  echo
  echo "=== Stopping existing Parrot instances ==="
  osascript -e "tell application id \"$BUNDLE_IDENTIFIER\" to quit" >/dev/null 2>&1 || true
  sleep 0.5

  if pgrep -f "/$APP_NAME/Contents/MacOS/Parrot" >/dev/null 2>&1; then
    pkill -f "/$APP_NAME/Contents/MacOS/Parrot" || true
    sleep 0.5
  fi

  if pgrep -f "/$APP_NAME/Contents/MacOS/Parrot" >/dev/null 2>&1; then
    echo "warning: at least one Parrot process is still running:" >&2
    pgrep -fl "/$APP_NAME/Contents/MacOS/Parrot" >&2 || true
  else
    echo "No Parrot debug process is running."
  fi
}

if [[ "$STOP_APP" == true ]]; then
  stop_parrot
fi

if [[ "$RESET_SCREEN_CAPTURE" == true ]]; then
  echo
  echo "=== Resetting Screen Recording permission ==="
  tccutil reset ScreenCapture "$BUNDLE_IDENTIFIER" || true
  echo "Screen Recording permission reset for $BUNDLE_IDENTIFIER."
fi

if [[ "$SKIP_BUILD" == false ]]; then
  echo
  echo "=== Debug build ==="
  BUILD_ARGS=(
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH"
  )

  if [[ "$ALLOW_SIGNING" == false ]]; then
    BUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO)
  fi
  BUILD_ARGS+=(build)

  xcodebuild "${BUILD_ARGS[@]}"
elif [[ "$RUN_APP" == true ]]; then
  echo "error: --run cannot be combined with --skip-build because it must open a fresh fixed build." >&2
  exit 2
else
  echo
  echo "Skipping build because --skip-build was provided."
fi

sign_debug_app_for_local_tcc() {
  local app_path="$1"
  local info_plist="$app_path/Contents/Info.plist"

  if [[ ! -d "$app_path" ]]; then
    return
  fi

  local app_bundle_identifier
  app_bundle_identifier="$(plutil -extract CFBundleIdentifier raw "$info_plist")"
  if [[ "$app_bundle_identifier" != "$BUNDLE_IDENTIFIER" ]]; then
    echo "error: app bundle identifier mismatch: expected $BUNDLE_IDENTIFIER, got $app_bundle_identifier" >&2
    exit 1
  fi

  echo
  echo "=== Signing Debug app for local TCC identity ==="
  local debug_dylib="$app_path/Contents/MacOS/Parrot.debug.dylib"
  local preview_dylib="$app_path/Contents/MacOS/__preview.dylib"
  if [[ -f "$debug_dylib" ]]; then
    codesign --force --sign - "$debug_dylib"
  fi
  if [[ -f "$preview_dylib" ]]; then
    codesign --force --sign - "$preview_dylib"
  fi

  local code_requirement="=designated => identifier \"$BUNDLE_IDENTIFIER\""
  codesign --force --sign - --requirements "$code_requirement" "$app_path"
  codesign --verify --deep --strict --verbose=2 "$app_path"

  local designated_requirement
  designated_requirement="$(codesign -dr - "$app_path" 2>&1 | sed -n 's/^designated => //p')"
  if [[ "$designated_requirement" != "identifier \"$BUNDLE_IDENTIFIER\"" ]]; then
    echo "error: Debug app has an unstable designated requirement: $designated_requirement" >&2
    echo "       Screen Recording TCC grants must not be tied only to a per-build cdhash." >&2
    exit 1
  fi
}

if [[ "$SKIP_BUILD" == false && "$ALLOW_SIGNING" == false ]]; then
  sign_debug_app_for_local_tcc "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"
fi

if [[ "$RUN_APP" == true ]]; then
  APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"

  echo
  echo "=== Opening Debug app ==="
  echo "App: $APP_PATH"

  if [[ ! -d "$APP_PATH" ]]; then
    echo "error: expected app bundle does not exist: $APP_PATH" >&2
    exit 1
  fi

  open "$APP_PATH"
fi

if [[ "$OPEN_XCODE" == true ]]; then
  echo
  echo "=== Opening Xcode ==="
  open "$PROJECT_FILE"
fi

echo
echo "=== Environment ready ==="
echo "Next files to read: parrot-progress.md and feature_list.json"
