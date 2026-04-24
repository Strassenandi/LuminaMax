# LuminaMax

LuminaMax is a lightweight macOS menu bar app that helps you make better use of peak brightness on XDR/EDR-capable displays.

## Overview

The app runs as a background utility (without a Dock icon) and creates a minimal 1x1 Metal overlay per display to trigger EDR/HDR headroom.
Intensity can be adjusted live from the menu bar menu.

## Features

- Menu bar control with on/off toggle
- Global shortcut: Option + Command + B
- Intensity slider (0-100%) plus presets (50/75/100)
- Smooth fade-in/fade-out transitions
- Persists state (active/inactive + intensity)
- Restores gamma values when disabled

## Requirements

- macOS 13 or newer
- XDR/EDR-capable display (for example MacBook Pro 14/16 with XDR)
- Swift 5.9 toolchain (Xcode or Command Line Tools)

## Quick Start (Development)

```bash
swift build -c debug
swift run
```

Note: The app is designed as a menu bar utility and runs without a standard main window.

## Build as a .app Bundle

```bash
chmod +x build.sh && ./build.sh
open LuminaMax.app
```

The script builds a release binary and creates a runnable `LuminaMax.app` in the project root.

## Code Quality

Install tools:

```bash
brew install swiftformat swiftlint
```

Run checks locally:

```bash
swiftformat --lint Sources --config .swiftformat
swiftlint lint --strict --config .swiftlint.yml
```

Auto-format source files:

```bash
swiftformat Sources --config .swiftformat
```

## CI

This repository includes a GitHub Actions workflow at `.github/workflows/ci.yml`.

On push and pull request, CI runs:

- SwiftFormat in lint mode
- SwiftLint with strict mode
- `swift build -c debug`
- `swift test -c debug` (if a `Tests` target exists)
- app bundle build via `build.sh`

The generated app bundle is uploaded as a CI artifact.

## Auto Release

This repository includes an automated release workflow at `.github/workflows/release.yml`.

When you push a version tag (for example `v1.0.1`), GitHub Actions will:

- build `LuminaMax.app`
- package it as `LuminaMax.app.zip`
- generate a SHA-256 checksum file
- create/update the GitHub Release and upload both files

Create and push a tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

## Release Process

For production-ready releases, follow the checklist in `docs/RELEASE_CHECKLIST.md`.

## First Launch (Unsigned App)

Since the app is currently not signed/notarized, macOS may block launch.

Possible workaround:

1. Right-click `LuminaMax.app` -> `Open`
2. Or allow launch in `System Settings -> Privacy & Security`

## Usage

- Click the menu bar icon to view status
- `Brightness Boost` enables/disables the effect
- Adjust `Intensity` via slider or presets
- Use `Option + Command + B` to toggle quickly

## Troubleshooting

### "XDR display not detected"

The app shows a warning if no suitable EDR/XDR display is detected.
In that case, the effect is not available on your hardware.

### Shortcut does not trigger globally

First test the shortcut while the app is running.
Depending on your macOS configuration, global keyboard events may be limited.

### Exit and restore state

When quitting, LuminaMax disables the boost and restores saved gamma tables.

## Project Structure

```text
.github/workflows/
	ci.yml
	release.yml
Sources/LuminaMax/
	AppDelegate.swift
	OverlayManager.swift
	MetalRenderer.swift
	StatusBarController.swift
Resources/
	Info.plist
docs/
	RELEASE_CHECKLIST.md
.swiftformat
.swiftlint.yml
build.sh
Package.swift
```
