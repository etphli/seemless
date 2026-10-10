# Seemless product brief

Status: planning. First release scope and the main interface are confirmed. Detailed interactions are still open.

## Confirmed direction

Seemless is a native macOS app for making the computer more intuitive, quicker, and easier to use. Universal hotkeys are its foundation.

The interface should have the quality and care of Notion, T3 Code, and Apple products. T3 Code is the strongest reference for its sleek, restrained appearance. The visual details still need to be chosen.

Seemless will live mainly in the menu bar, with a command bar and floating panels opened when needed. A settings window can handle configuration.

The main frustration is a lack of useful shortcuts and interactions that take too many steps. Specific app workflows have not yet been named.

All ten feature ideas remain candidates for the roadmap. Liking an idea does not yet define its final behaviour or commit it to the first release.

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

## Proposed interaction defaults

The following defaults are proposals awaiting feedback:

- Open compact panels on the active display and return focus to the previous app when dismissed.
- Show each action's shortcut in the command bar so actions are discoverable before their shortcuts are memorised.
- An app shortcut opens or focuses the app. Pressing it again returns to the previous window. The behaviour for several windows in the same app still needs definition.
- Keep clipboard history on this Mac. Begin with searchable text and links, plain-text paste, pinned entries, and a way to clear history. Expire unpinned entries after seven days.
- Use a restrained charcoal appearance, subtle borders, readable spacing, and limited translucency. Support the system's light appearance as well.

## Decisions to settle before implementation

- Which apps should get quick-switch shortcuts first, and which workflows should be used to verify them?
- Which shortcut patterns should be supported, and which existing shortcuts must be preserved?
- Should a dedicated modifier such as Caps Lock be supported for shortcuts?
- How should switching choose among several windows of the same app?
- Which appearance details should follow T3 Code, including colours, density, and window materials?
- Is the initial app for personal use, with wider distribution later, or intended for other users from the start?
- Which macOS versions should be supported?
- Should the first clipboard release include images, and which content should be excluded or expired?

## Proposed engineering direction

Use Swift and SwiftUI for the native app, with focused AppKit integration where system-wide shortcuts, window control, or floating panels need it. This is a proposal to validate during implementation.

Before promising support across apps, verify window switching, selected-text access, and keyboard navigation hints in the apps used most often. Define permission requests around the features that need them.

## What a working first release must demonstrate

The chosen daily workflows must work outside Seemless while another app is active. Verify shortcuts, focus changes, cancellation, multiple displays where relevant, and recovery when a target app is unavailable.

Review the actual native interface for keyboard use, readable text, light and dark appearances, and responsiveness. Build and run the app before calling any feature complete.
