# Release Process

Parrot uses SemVer and GitHub-style release assets for local unsigned macOS
packages. A formal release is built from a tagged, clean commit.

## Versioning

- Product versions use SemVer in `Config/Release.xcconfig`:
  `MARKETING_VERSION = X.Y.Z`.
- macOS build numbers use `CURRENT_PROJECT_VERSION` and must be incremented for
  each formal release build.
- Git tags use `v<MARKETING_VERSION>`, for example `v0.1.0`.
- Pre-release versions are allowed with SemVer labels such as `0.2.0-rc.1`.

Use these bump rules:

- PATCH: bug fixes, packaging fixes, copy changes, and reliability updates.
- MINOR: new user-visible features that remain backward compatible.
- MAJOR: compatibility-breaking product or data changes. Avoid `1.0.0` until
  the app behavior and persistence formats are stable enough to support.

## Formal Release

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
   `Config/Release.xcconfig`.
2. Run the normal project verification that matches the scope of the release.
3. Commit all release changes. The worktree must be clean.
4. Create an annotated tag that matches the SemVer version:

   ```sh
   git tag -a v0.1.0 -m "Release v0.1.0"
   ```

5. Build packages from the tagged commit:

   ```sh
   Scripts/package-release.sh
   ```

The script writes assets to `Dist/vX.Y.Z/`.

## Local Dev Package

Use a dev package to validate packaging before creating a formal tag:

```sh
Scripts/package-release.sh --allow-untagged
```

Dev packages are written to `Dist/dev-<shortsha>/` and include
`dev+<shortsha>` in the artifact version. Do not upload dev packages as formal
GitHub releases.

## GitHub Release Format

Use this format when creating a GitHub Release:

- Tag: `vX.Y.Z`
- Title: `Parrot vX.Y.Z`
- Assets: `.dmg`, `.zip`, and `SHA256SUMS.txt`
- Body: copy `Dist/vX.Y.Z/RELEASE_NOTES.md`

The current release packages are unsigned and not notarized. Release notes must
keep the Gatekeeper warning and local testing instructions.

## Generated Assets

A successful release directory contains:

```text
Dist/
  vX.Y.Z/
    Parrot-X.Y.Z-macos-<arch>-unsigned.dmg
    Parrot-X.Y.Z-macos-<arch>-unsigned.zip
    SHA256SUMS.txt
    RELEASE_NOTES.md
```

Verify checksums from inside the release directory:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

## Safety Rules

- Do not create formal packages from a dirty worktree.
- Do not move a pushed release tag. Publish a new PATCH version instead.
- Do not commit files under `Dist/`.
- Do not change the bundle identifier, signing team, deployment target, or app
  version unless the release task explicitly requires it.
- Keep API keys in Keychain only. Release artifacts must not include secrets.

## Future Signed Release

When a stable bundle identifier, Apple Developer Team, Developer ID
certificate, and notarization credentials are available, extend the release
script with a separate signed mode. Keep unsigned packaging available for local
testing.
