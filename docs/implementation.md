# Implementation

The downloadable 0.2.0 release is ad-hoc code signed and uses signed update packages. It is not Apple notarised.

## App structure

`SeemlessCore` contains shortcut identities, preferences, clipboard entry models, search ranking, key mapping restoration rules, and an actor-owned history repository.

`Seemless` contains SwiftUI views and the macOS services. A single app model owns settings, app discovery, clipboard monitoring, shortcut registration, switching, and panel presentation. AppKit owns the menu bar, window lifecycle, focus, and native pasteboard operations. SwiftUI renders the command bar, clipboard panel, settings, and shortcut recorder.

## Shortcuts and app switching

Standard shortcuts use Carbon hotkey registration. Seemless rejects duplicate assignments internally and shows a registration failure when a combination is unavailable. Shortcut recording suspends Seemless hotkeys until the recorder closes.

Apps are found in `/Applications`, `/System/Applications`, `/System/Library/CoreServices/Applications`, and the user's `Applications` directory. Running apps and manually selected app bundles are also included. Embedded app helpers and bundles marked background-only are excluded; menu bar apps can be selected.

With Accessibility, the switcher captures the focused window before leaving an app, raises it on return, and attempts to restore minimised windows. Otherwise it activates the app. Exact window restoration depends on the target app exposing usable Accessibility information. Named windows from the current app appear in the command bar when that information is available.

## Hyper

Hyper combinations are Command, Option, Control, and Shift together. Opting in to Caps Lock Hyper uses Apple's `hidutil` key mapping mechanism to map Caps Lock to F18 temporarily. A Quartz event tap interprets F18 press and release events and adds the four modifiers while it is held.

The prior Caps Lock mapping is written to a recovery record before applying the remap. Disable and normal quit restore it. Startup recovers any outstanding record before re-enabling Hyper if the saved preference requests it. Restoration preserves unrelated mappings and avoids replacing a newer Caps Lock mapping made by another tool.

F18 is reserved while Hyper is enabled. The app refuses activation if another existing key mapping already targets F18. Forced termination may leave the temporary remap in place until the next launch. Unplugging or adding keyboards while Hyper is active still needs testing.

The mapping method follows [Apple's key remapping technical note](https://developer.apple.com/library/archive/technotes/tn2450/). Event handling uses [Quartz event taps](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)).

## Clipboard

Recording is opt-in. Seemless polls the native pasteboard change count every 0.6 seconds and reads only changes made after recording starts. Very rapid successive copies can be missed between polls.

Text and links are saved in an atomic JSON index. Images are normalised to PNG and stored separately, with a 20 MB limit per image. Repeated copies update an existing entry's timestamp while preserving its identity and pin. Unpinned entries expire seven days after their latest captured copy. Expiry runs at startup, on repository mutations, and once per minute while running.

The repository serialises changes, writes the index before removing referenced images, and cleans up orphaned PNG files on load. Pausing recording does not pause expiry. Clearing history keeps pinned entries. Clipboard data stays local and has no cloud sync.

Data lives under the user's `Library/Application Support/Seemless` directory, outside the source checkout. The clipboard folder is restricted to the owning user. History is stored in readable local files rather than encrypted as a secrets vault.

Default exclusions cover 1Password and Bitwarden bundle identifiers. Excluded apps and pasteboards marked concealed, transient, or automatically generated are skipped. Sensitive content is not universally detectable. A copied password from an unmarked, non-excluded app may still be recorded.

Paste requires Accessibility. Seemless restores the captured app/window, waits briefly for focus, and sends Command-V only if the target app is still frontmost. Copy remains available without Accessibility. History text is copied as plain text; original rich formatting and multi-item pasteboards are not preserved.

The monitor follows [NSPasteboard change count](https://developer.apple.com/documentation/appkit/nspasteboard/changecount). It reports denied access when [pasteboard access behaviour](https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-86972) exposes that state. Permission prompting uses [Apple's Accessibility trust API](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions).

## Interface and performance

Panels use adaptive graphite and light surfaces, thin borders, violet selection, compact shortcut badges, and consistent spacing. The command bar groups applications, windows, and actions; the clipboard panel separates history from its preview and metadata.

Command candidates and app ranking are prepared when their underlying state changes. Search filters run when the query changes; moving selection or hovering does not repeat app sorting. Clipboard filtering similarly runs when entries, query, or filter change. Image thumbnails decode off the main actor and use a bounded memory cache. Clipboard titles inspect only a bounded portion of the first nonempty line.

## Updates

Sparkle 2.10.0 checks the public GitHub release feed at launch and daily. Its information-only initial check updates the app's observable availability state. Settings and the menu bar display the update control only when a compatible newer release is found. Scheduled reminders stay quiet. Selecting Update opens the native download/install flow, which verifies the signed feed and archive and can relaunch the app after replacement.

The Ed25519 private release key is stored in the maintainer's Keychain; the public key is embedded in the app. No private key is checked into Git. Archive authentication and Apple's Developer ID/notarisation are separate; the latter is not available on the current build machine. The updater does not send clipboard contents or enable system profiling. Checks contact GitHub for release metadata and packages.

See [Releasing](releasing.md) for the repeatable build, signing, verification, and publication workflow.

## Verification

The local run passed 17 tests, compiled the app bundle, launched its process, and verified the ad-hoc signature. Diagnostics discovered installed apps and registered both default shortcuts without failures. Test and diagnostic results do not replace the outstanding manual checks below.

The test suite exercises seven-day expiry, pinned item survival, duplicate copies, concurrent persistence, image cleanup, safe image paths, bounded clipboard titles, shortcut conflicts, search ranking, preference migration, and key mapping restoration rules.

Platform tests use separate native pasteboards to capture and copy text, links, and PNG images. They check concealed-content and app exclusions, discovery of nested apps, helper exclusions, real hotkey registration conflicts, and Hyper event translation without changing system key mappings.

Updater integration checks use Sparkle's real downloader and installer on disposable app copies inside `.build`. A signed update upgrades the staged bundle and passes deep code-signature verification. Changing a byte in the archive makes Sparkle reject it with a validation error, leaving the old bundle intact. An older diagnostic app also reads the signed feed and renders the conditional update button in its native Settings window.

A rendering test uses native SwiftUI hosting views in invisible test windows to render the command bar, clipboard panel, and settings in dark and light appearances. It can save PNG artifacts via `SEEMLESS_SNAPSHOT_DIR`. It does not operate the user's desktop.

The `--diagnostics` launch mode uses the real menu bar app with a separate data directory and synthetic clipboard examples. It opens the settings window, command bar, and clipboard panel in both appearances and saves content captures from their native AppKit views. A JSON report records visibility, key-window state, pixel dimensions, discovery count, registration failures, and permission state. These are app content captures rather than desktop screenshots. The user requested logs and screenshots without Computer Use.

Lifecycle, shortcut registration, panel presentation, and clipboard load/recording state emit Apple unified logs. Diagnostics also save structured metadata events locally, because this environment denies access to the system log store. `--logs` enables the same local stream for normal runs. Clipboard contents, app names, and external window titles are omitted. Generated captures, reports, and logs stay outside Git.

Accessibility was not granted during verification. Live shortcut activation, window return, keyboard navigation, direct paste, physical Caps Lock Hyper, multiple displays, and full-screen Spaces still need manual checks. Diagnostics do not enable Hyper, recording, or macOS permissions.

The build script stages a local `.app` bundle, embeds Sparkle, generates its icon, and applies an ad-hoc signature. The current downloadable archive targets Apple Silicon. A Developer ID identity and notarisation are still needed for trusted initial installation on other Macs without a local exception. Rebuilding an ad-hoc app may require macOS permissions to be granted again.
