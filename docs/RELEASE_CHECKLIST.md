# Release Checklist

Use this checklist before creating a release.

## 1. Versioning and Notes

- Update version values in `Resources/Info.plist`:
  - `CFBundleShortVersionString`
  - `CFBundleVersion`
- Prepare release notes with key changes and known limitations.

## 2. Local Quality Checks

Run these commands from the project root:

```bash
swift build -c debug
swiftformat --lint Sources --config .swiftformat
swiftlint lint --strict --config .swiftlint.yml
```

If tests exist:

```bash
swift test -c debug
```

## 3. Build Release App Bundle

```bash
chmod +x build.sh && ./build.sh
```

Verify that `LuminaMax.app` is generated and starts correctly.

## 4. Manual Validation

- Launch app from Finder.
- Confirm menu bar icon appears.
- Verify toggle and slider behavior.
- Verify hotkey (`Option + Command + B`).
- Verify behavior on supported XDR/EDR hardware.
- Confirm gamma state is restored after app quit.

## 5. Signing and Notarization (Recommended)

- Sign app with Developer ID certificate.
- Notarize app with Apple notary service.
- Staple notarization ticket to the app.

Keep signing identities and notarization credentials in CI secrets.

## 6. Release and Tag

- Create release commit.
- Create and push a version tag (example: `v1.0.1`).
- Auto-release workflow (`.github/workflows/release.yml`) should create/update the GitHub Release and upload artifacts:
  - `LuminaMax.app.zip`
  - `LuminaMax.app.zip.sha256`

Tag commands:

```bash
git tag v1.0.1
git push origin v1.0.1
```

## 7. Post-Release

- Smoke test the downloaded artifact on a clean machine.
- Track regressions and user feedback.
- Open follow-up issues for known gaps.
