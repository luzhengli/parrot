#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="Parrot.xcodeproj"
SCHEME="Parrot"
CONFIGURATION="Release"
DESTINATION="platform=macOS"
DERIVED_DATA_PATH="$ROOT_DIR/.DerivedData"
APP_NAME="Parrot.app"
APP_DISPLAY_NAME="Parrot"
RELEASE_CONFIG="$ROOT_DIR/Config/Release.xcconfig"
DIST_ROOT="$ROOT_DIR/Dist"

ALLOW_UNTAGGED=false
SKIP_BUILD=false

usage() {
  cat <<'USAGE'
Usage: Scripts/package-release.sh [--allow-untagged] [--skip-build]

Builds an unsigned GitHub-style macOS Release package for Parrot.

Default release mode:
  - Requires a clean git worktree.
  - Requires HEAD to match annotated or lightweight tag v<MARKETING_VERSION>.
  - Writes assets to Dist/v<MARKETING_VERSION>/.

Options:
  --allow-untagged  Allow a local dev package from the current commit.
                    Assets are written under Dist/dev-<shortsha>/ and include
                    dev+<shortsha> in the artifact version.
  --skip-build      Reuse the existing Release app from ./.DerivedData.
  -h, --help        Show this help.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --allow-untagged)
      ALLOW_UNTAGGED=true
      ;;
    --skip-build)
      SKIP_BUILD=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "error: required command is not available: $name" >&2
    exit 1
  fi
}

read_xcconfig_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value=$2
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      print value
      exit
    }
  ' "$RELEASE_CONFIG"
}

require_command git
require_command xcodebuild
require_command hdiutil
require_command ditto
require_command shasum
require_command plutil
require_command lipo

MARKETING_VERSION="$(read_xcconfig_value MARKETING_VERSION)"
BUILD_VERSION="$(read_xcconfig_value CURRENT_PROJECT_VERSION)"

if [[ -z "$MARKETING_VERSION" ]]; then
  echo "error: MARKETING_VERSION is missing in Config/Release.xcconfig" >&2
  exit 1
fi

if [[ -z "$BUILD_VERSION" ]]; then
  echo "error: CURRENT_PROJECT_VERSION is missing in Config/Release.xcconfig" >&2
  exit 1
fi

SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(\+([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?$'
if [[ ! "$MARKETING_VERSION" =~ $SEMVER_RE ]]; then
  echo "error: MARKETING_VERSION must follow SemVer: $MARKETING_VERSION" >&2
  exit 1
fi

if [[ ! "$BUILD_VERSION" =~ ^[0-9]+$ ]]; then
  echo "error: CURRENT_PROJECT_VERSION must be a positive integer: $BUILD_VERSION" >&2
  exit 1
fi

SHORT_SHA="$(git rev-parse --short HEAD)"
WORKTREE_STATE="clean"
if [[ -n "$(git status --porcelain)" ]]; then
  WORKTREE_STATE="dirty"
fi
RELEASE_TAG="v$MARKETING_VERSION"
RELEASE_LABEL="$RELEASE_TAG"
ARTIFACT_VERSION="$MARKETING_VERSION"
DIST_DIR="$DIST_ROOT/$RELEASE_TAG"

if [[ "$ALLOW_UNTAGGED" == false ]]; then
  if [[ "$WORKTREE_STATE" != "clean" ]]; then
    echo "error: refusing to create a formal release from a dirty worktree." >&2
    echo "       Commit or stash changes, then tag the release commit." >&2
    exit 1
  fi

  if ! git rev-parse -q --verify "refs/tags/$RELEASE_TAG" >/dev/null; then
    echo "error: expected release tag does not exist: $RELEASE_TAG" >&2
    echo "       Create it with: git tag -a $RELEASE_TAG -m \"Release $RELEASE_TAG\"" >&2
    exit 1
  fi

  TAG_COMMIT="$(git rev-list -n 1 "$RELEASE_TAG")"
  HEAD_COMMIT="$(git rev-parse HEAD)"
  if [[ "$TAG_COMMIT" != "$HEAD_COMMIT" ]]; then
    echo "error: HEAD does not match $RELEASE_TAG." >&2
    echo "       Checkout the tag or tag the current release commit before packaging." >&2
    exit 1
  fi
else
  RELEASE_LABEL="dev-$SHORT_SHA"
  ARTIFACT_VERSION="$MARKETING_VERSION-dev+$SHORT_SHA"
  if [[ "$WORKTREE_STATE" == "dirty" ]]; then
    RELEASE_LABEL="$RELEASE_LABEL-dirty"
    ARTIFACT_VERSION="$ARTIFACT_VERSION.dirty"
    echo "warning: creating a dev package from a dirty worktree."
  fi
  DIST_DIR="$DIST_ROOT/$RELEASE_LABEL"
fi

DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVELOPER_DIR" != */Xcode*.app/Contents/Developer ]]; then
  echo "warning: active developer directory is '$DEVELOPER_DIR'."
  echo "         If the build fails, run:"
  echo "         sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

if [[ "$SKIP_BUILD" == false ]]; then
  echo "=== Building unsigned Release ==="
  xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    clean build
else
  echo "=== Reusing existing Release build ==="
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: expected app bundle does not exist: $APP_PATH" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
BUNDLE_SHORT_VERSION="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")"
BUNDLE_BUILD_VERSION="$(plutil -extract CFBundleVersion raw "$INFO_PLIST")"

if [[ "$BUNDLE_SHORT_VERSION" != "$MARKETING_VERSION" ]]; then
  echo "error: app bundle version mismatch: expected $MARKETING_VERSION, got $BUNDLE_SHORT_VERSION" >&2
  exit 1
fi

if [[ "$BUNDLE_BUILD_VERSION" != "$BUILD_VERSION" ]]; then
  echo "error: app bundle build mismatch: expected $BUILD_VERSION, got $BUNDLE_BUILD_VERSION" >&2
  exit 1
fi

EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_DISPLAY_NAME"
ARCHS="$(lipo -archs "$EXECUTABLE_PATH" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
case "$ARCHS" in
  "arm64 x86_64"|"x86_64 arm64")
    ARCH_LABEL="universal"
    ;;
  "arm64")
    ARCH_LABEL="arm64"
    ;;
  "x86_64")
    ARCH_LABEL="x86_64"
    ;;
  *)
    ARCH_LABEL="$(echo "$ARCHS" | tr ' ' '-')"
    ;;
esac

ASSET_BASENAME="$APP_DISPLAY_NAME-$ARTIFACT_VERSION-macos-$ARCH_LABEL-unsigned"
ZIP_PATH="$DIST_DIR/$ASSET_BASENAME.zip"
DMG_PATH="$DIST_DIR/$ASSET_BASENAME.dmg"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"
NOTES_PATH="$DIST_DIR/RELEASE_NOTES.md"
DMG_STAGE="$DIST_DIR/.dmg-stage"

echo "=== Preparing Dist directory ==="
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR" "$DMG_STAGE"

echo "=== Creating zip ==="
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "=== Creating dmg ==="
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create \
  -volname "$APP_DISPLAY_NAME $ARTIFACT_VERSION" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null
rm -rf "$DMG_STAGE"

echo "=== Writing checksums ==="
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "=== Writing GitHub release notes ==="
cat > "$NOTES_PATH" <<NOTES
# $APP_DISPLAY_NAME $RELEASE_LABEL

Unsigned macOS release package for Parrot.

## Assets

- $(basename "$DMG_PATH")
- $(basename "$ZIP_PATH")
- $(basename "$CHECKSUM_PATH")

## Install

- DMG: open the image and drag \`$APP_NAME\` to \`Applications\`.
- ZIP: unzip the archive and move \`$APP_NAME\` to \`Applications\`.

## Verify

\`\`\`sh
shasum -a 256 -c SHA256SUMS.txt
\`\`\`

## macOS Gatekeeper

This build is unsigned and not notarized. macOS may block it with an
"unidentified developer" warning. For local testing, use right-click > Open.
If quarantine blocks a trusted local test build, remove the quarantine flag:

\`\`\`sh
xattr -dr com.apple.quarantine /path/to/$APP_NAME
\`\`\`

## Build metadata

- Version: $MARKETING_VERSION
- Build: $BUILD_VERSION
- Git label: $RELEASE_LABEL
- Commit: $(git rev-parse HEAD)
- Worktree: $WORKTREE_STATE
- Architecture: $ARCH_LABEL
- Signing: unsigned
NOTES

echo
echo "=== Release package ready ==="
echo "Label: $RELEASE_LABEL"
echo "Version: $MARKETING_VERSION"
echo "Build: $BUILD_VERSION"
echo "Commit: $(git rev-parse HEAD)"
echo "Worktree: $WORKTREE_STATE"
echo "Architecture: $ARCH_LABEL"
echo "DMG: $DMG_PATH"
echo "ZIP: $ZIP_PATH"
echo "Checksums: $CHECKSUM_PATH"
echo "Release notes: $NOTES_PATH"
