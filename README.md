<img src="assets/icon.svg" width="64" height="64" alt="">

# Seemless

A native macOS menu bar app for quicker app switching, custom shortcuts, and clipboard reuse.

The first development build is implemented and running. Automated tests and native panel captures pass; permission-dependent keyboard and window workflows still need manual verification.

## First version

- A command bar that searches installed apps and Seemless actions.
- Custom standard and Hyper shortcuts, with shortcut recording and conflict feedback.
- App switching that opens or focuses an app and can return to the previous app or window.
- Local clipboard history for text, links, and images, with search, pinning, deletion, and seven-day expiry for unpinned entries.

Seemless scans system, shared, and user Applications folders, plus running apps. You can add an app stored elsewhere through Settings.

## Run

Requires macOS 14 or later and Swift 6 through Xcode or Command Line Tools. The current development build was compiled and launched on macOS 26.7.

```sh
./script/build_and_run.sh
```

The script creates and opens `dist/Seemless.app`. Seemless stays in the menu bar and opens Settings on first launch.

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

## Design direction

A sleek, elegant interface with the restrained feel of T3 Code and the care of a well-made Apple app. Keep common actions immediate, make shortcuts easy to discover, and show compact panels when needed.

## Planning

- [Product brief](docs/product-brief.md) records confirmed requirements and open decisions.
- [Feature ideas](docs/feature-ideas.md) describes universal hotkeys and ten proposed features.
- [Implementation notes](docs/implementation.md) explains behaviour, permissions, and remaining verification.

The first release will focus on universal hotkeys, app and window switching, a command bar, and clipboard history. Seemless will live mainly in the menu bar, with compact floating panels.

Created in [T3 Code](https://t3.codes).
