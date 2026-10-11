<img src="assets/icon.svg" width="64" height="64" alt="">

# Seemless

A native macOS menu bar app for quicker app switching, custom shortcuts, and clipboard reuse.

Seemless 0.2.0 is available for Apple Silicon Macs running macOS 14 or later. Automated tests and native panel captures pass; permission-dependent keyboard and window workflows still need manual verification.

[Download the latest release](https://github.com/etphli/seemless/releases/latest).

## First version

- A command bar that searches installed apps and Seemless actions.
- Custom standard and Hyper shortcuts, with shortcut recording and conflict feedback.
- App switching that opens or focuses an app and can return to the previous app or window.
- Local clipboard history for text, links, and images, with search, pinning, deletion, and seven-day expiry for unpinned entries.
- A quiet update button in Settings and the menu bar, shown only when a compatible newer GitHub release is available.

Seemless scans system, shared, and user Applications folders, plus running apps. You can add an app stored elsewhere through Settings.

## Install

Download the release ZIP and `SHA256SUMS`, verify the archive checksum, and move `Seemless.app` to Applications. The initial release is ad-hoc code signed rather than Apple notarized. If macOS quarantines the verified download, use Privacy & Security to allow it, or run these commands for that app:

```sh
codesign --verify --deep --strict /Applications/Seemless.app
xattr -dr com.apple.quarantine /Applications/Seemless.app
open /Applications/Seemless.app
```

The local `./script/install.sh /path/to/Seemless-0.2.0-macOS-arm64.zip` verifies, backs up an existing Seemless installation, installs, clears its quarantine flag, and checks that the installed process is running.

Updates are checked at launch and daily. When a newer compatible release exists, select **Update to …** in Settings or the menu bar. Sparkle verifies both the release feed and update archive using the embedded public key before installation. It then replaces the app and restarts it; personal settings and clipboard history remain in Application Support.

## Build and run

Requires macOS 14 or later and Swift 6 through Xcode or Command Line Tools. The current development build was compiled and launched on macOS 26.7.

```sh
./script/build_and_run.sh
```

The script resolves Sparkle 2.10.0, creates and opens `dist/Seemless.app`, and bundles its framework and license. Seemless stays in the menu bar and opens Settings on first launch.

Default shortcuts are `⌥⌘Space` for the command bar and `⇧⌘V` for clipboard history. Change them in Settings, where you can also assign shortcuts to any discovered app.

Clipboard recording and Caps Lock Hyper start off. Enable each in Settings when wanted. Accessibility is needed for exact window focus, direct paste, and Hyper. Hyper may also require Input Monitoring. Without Accessibility, app activation and copying a history item remain available.

Caps Lock Hyper temporarily remaps Caps Lock while Seemless runs. Its prior mapping is restored on disable or normal quit. A recovery record restores it on the next launch after a crash. An unexpected quit can leave that temporary mapping active until Seemless is reopened.

## Verify

```sh
./script/test.sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --diagnostics
```

Tests use disposable folders and separate native pasteboards. They do not read or overwrite your clipboard or enable a system key remap. Set `SEEMLESS_SNAPSHOT_DIR` to generate native view snapshots during the rendering test.

Diagnostics launch the real app with separate temporary settings and sample history. They open each native panel, save six content captures in dark and light appearances, and record visibility, shortcut registration, app discovery, and permission state in `.build/diagnostics/<timestamp>/report.json`. `events.jsonl` records lifecycle and panel events. Captures contain synthetic clipboard examples. They do not require Computer Use or screen-recording access.

Use `./script/build_and_run.sh --logs` to save and follow local metadata logs at `.build/runtime.jsonl`. The app also emits Apple unified logs under `com.etphli.seemless`; `--telemetry` follows these when the system log store is accessible. Logs omit clipboard contents, app names, and window titles. Local logging is enabled only by the diagnostic or log flag.

The build scripts select an installed SDK matching the host macOS major version when available. Set `SEEMLESS_SDK` to choose another SDK. `--build-only` and `--debug` are also supported.

Release and updater integration checks are documented in [Releasing](docs/releasing.md).

## Design direction

A sleek, elegant interface with the restrained feel of T3 Code and the care of a well-made Apple app. Keep common actions immediate, make shortcuts easy to discover, and show compact panels when needed.

## Planning

- [Product brief](docs/product-brief.md) records confirmed requirements and open decisions.
- [Feature ideas](docs/feature-ideas.md) describes universal hotkeys and ten proposed features.
- [Implementation notes](docs/implementation.md) explains behaviour, permissions, and remaining verification.

The current release focuses on universal hotkeys, app and window switching, a command bar, and clipboard history. The remaining ideas stay on the roadmap.

Created in [T3 Code](https://t3.codes).
