# Seemless product brief

Status: first native development build. Release scope and the main interface are confirmed. Automated tests, launch, and native captures pass; permission-dependent workflows need manual verification.

## Confirmed direction

Seemless is a native macOS app for making the computer more intuitive, quicker, and easier to use. Universal hotkeys are its foundation.

The interface should have the quality and care of Notion, T3 Code, and Apple products. T3 Code is the strongest reference for its sleek, restrained appearance. The visual details still need to be chosen.

Seemless will live mainly in the menu bar, with a command bar and floating panels opened when needed. A settings window can handle configuration.

The main frustration is a lack of useful shortcuts and interactions that take too many steps. Specific app workflows have not yet been named.

All ten feature ideas remain on the roadmap. The command bar, app and window switching, and clipboard history are in the initial build alongside universal hotkeys.

The project has a public GitHub repository. Public visibility alone does not decide licensing or distribution.

## Feature candidates

- Instant app and window switching, including returning to the previous window.
- Saved workspaces with apps, folders, websites, and window arrangements.
- Searchable clipboard history and quick paste.
- A temporary drag-and-drop shelf for files, screenshots, links, and text.
- Actions on selected text, such as calculations and formatting changes.
- A command bar that searches and runs Seemless actions.
- Reusable text snippets.
- Pinned reference previews.
- Keyboard navigation hints for controls in other apps.
- Temporary system modes that restore prior settings when they end.

See [the feature draft](feature-ideas.md) for examples and unresolved questions.

## Confirmed first release

Build and polish universal hotkeys, app and window switching, a command bar, and clipboard history first. The drag shelf and other feature ideas remain on the roadmap.

## Confirmed behaviour

- Support both standard shortcuts and a Hyper key.
- Discover installed apps so the user chooses their own quick-switch targets. Include an app picker for apps outside standard installation folders.
- Store text, links, and images locally for seven days. Pinned entries remain until removed.
- Keep Seemless mainly in the menu bar, with a command bar and floating panels.

## Initial interaction defaults

- Open compact panels on the active display and return focus to the previous app when dismissed.
- Show each action's shortcut in the command bar so actions are discoverable before their shortcuts are memorised.
- An app shortcut opens or focuses the app. Pressing it again while that app is active returns to the previously captured app or window. With Accessibility, remember each app's last captured window and offer the current app's named windows in the command bar.
- Clipboard history supports text, links, and images, search, plain-text copying, pinned entries, app exclusions, and clearing unpinned history. Expire unpinned entries after seven days. Image entries are limited to 20 MB each.
- Use a restrained charcoal appearance, subtle borders, readable spacing, and limited translucency. Support the system's light appearance as well.

## Decisions still open

- Which real daily workflows should be used for the final desktop usability checks?
- Should window targeting extend to all running apps, with saved per-window assignments?
- Which appearance details should follow T3 Code, including colours, density, and window materials?
- Is the initial app for personal use, with wider distribution later, or intended for other users from the start?
- Should macOS 14 remain the minimum supported version? It is the current deployment target; older Macs still need testing.
- What additional clipboard exclusions or storage limits should be available?

## Engineering direction

The app uses Swift and SwiftUI, with focused AppKit integration for the menu bar, floating panels, settings window, pasteboard, and app activation. Models and the clipboard repository live in a separate core module.

Before promising support across apps, verify window switching, selected-text access, and keyboard navigation hints in the apps used most often. Define permission requests around the features that need them.

## What a working first release must demonstrate

The chosen daily workflows must work outside Seemless while another app is active. Verify shortcuts, focus changes, cancellation, multiple displays where relevant, and recovery when a target app is unavailable.

Review the actual native interface for keyboard use, readable text, light and dark appearances, and responsiveness. Build and run the app before calling any feature complete.
