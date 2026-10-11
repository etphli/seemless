# Seemless feature ideas

Build one app that reduces the steps between deciding what to do and doing it. Universal hotkeys are the foundation.

This document keeps the five features you liked and adds five new proposals. It is an idea draft, not a final specification.

The [product brief](product-brief.md) records decisions made since this draft, including support for both shortcut styles and seven-day history for text, links, and images.

Seemless is a native macOS app. Supported macOS versions and the implementation approach are still open.

## What the app should feel like

Press a shortcut, do something useful, and return to your work. Keep the interface small and show it only when needed.

Make every action discoverable and customisable. The app should feel faster because it reduces clicks, window hunting, and repeated setup. Actual performance needs measurement.

## Foundation: universal hotkeys

Assign shortcuts to app actions, windows, workspaces, and utilities. Manage them in one place.

Support shortcuts that work across apps, with optional rules for a specific app. Show conflicts during setup and let you pause shortcuts when needed.

Example: use one shortcut to open the clipboard panel regardless of which app is active.

Questions to flesh out:

- Do you prefer conventional shortcuts, a dedicated modifier key, or both?
- Should shortcuts behave differently in different apps?
- How should you discover available actions without memorising every shortcut?

## Features you already liked

### 1. Instant window switching

Assign a shortcut to an app or a specific window. Press it to bring that window forward. Press it again to return to the previous window.

Example: jump from your editor to a browser preview, then back to the exact editor window.

First version: app shortcuts and return-to-previous-window behaviour.

Questions to flesh out:

- How should the app choose between several windows belonging to the same app?
- What should happen when the target app is closed or its window is minimised?
- Should shortcuts move windows between displays or switch to their existing location?

### 2. Saved workspaces

Save the apps, folders, websites, and window arrangement for a task. Restore that setup with one shortcut.

Example: a Coding workspace opens your editor, terminal, project folder, and browser preview in their usual positions.

First version: named setups with app launches, folder and URL opens, and window positions.

Questions to flesh out:

- Should restoring a workspace leave unrelated windows visible?
- Should you save workspaces manually or capture the current arrangement?
- How should layouts adapt when an external display is disconnected?

### 3. Clipboard history with quick paste

Search recent copied text, links, and images. Pin reusable entries, paste as plain text, or paste several entries in order.

Example: copy three pieces of information from a website, then paste each into a form without switching back.

First version: searchable text history, pinned entries, and plain-text paste. Image support can follow.

Questions to flesh out:

- How long should history remain available?
- Which apps or types of content should be excluded?
- Should history remain on this computer or sync between your computers?

### 4. Temporary drag-and-drop shelf

Collect files, screenshots, links, and text in a floating shelf. Switch apps and drop the collected items where needed.

Example: collect screenshots from several folders, open an email draft, and attach them together.

First version: a shelf opened by shortcut, with individual items and multi-item dragging.

Questions to flesh out:

- Should the shelf appear near the pointer or at a fixed screen edge?
- Should items disappear after a successful drop?
- Should the shelf survive closing the app or restarting the computer?

### 5. Actions on selected text

Select text in an app and open a small action menu. Calculate an expression, convert units, change capitalisation, clean formatting, or search the selection.

Example: select `1920 / 3`, run Calculate, and copy the result without opening another app.

First version: a short set of predictable local transformations, with a preview before replacing text.

Questions to flesh out:

- Should results appear beside the selection or in one consistent panel?
- Which actions deserve their own direct shortcuts?
- When selection access is unavailable, should you copy text manually into the panel?

## Five new proposals

### 6. Universal command bar

Open one searchable bar to find and run the app's actions. Search by what you want to do, even when you do not know its shortcut.

Show shortcuts beside results so using the bar helps you learn them. Include recent actions and favourites.

Example: type `paste plain` or `open coding workspace`, then press Return.

Why it helps: the app stays usable as its features grow, without requiring you to remember dozens of shortcuts.

First version: search this app's actions, workspaces, and configured app targets. Use predictable search matching before considering natural-language interpretation.

Questions to flesh out:

- Should the bar also search files and apps, or stay focused on this app's actions?
- Should it open in the centre of the screen or near the current window?
- Which actions should appear before you type?

### 7. Reusable text snippets

Save text you repeatedly type and insert it through a shortcut or short abbreviation. Optional fields let you fill in details before insertion.

Example: insert a bug-report template with fields for the problem, reproduction steps, and expected behaviour.

Other uses include email replies, code templates, addresses, and the current date.

Why it helps: you avoid repeatedly typing or hunting for the same text. Snippets are deliberately saved templates, separate from recent clipboard entries.

First version: named snippets, search, insertion, and a small form for placeholders. Automatic abbreviation expansion can follow.

Questions to flesh out:

- Do you prefer a snippet picker, typed abbreviations, or both?
- Should snippets support rich text and attachments?
- Should snippets belong to an app, a workspace, or a shared library?

### 8. Pinned previews

Keep a compact reference visible while you work in another app. Pin an image, a PDF page, or a captured screen region.

Example: keep an assignment rubric beside your document, or a design reference beside your editor.

Let you resize the preview, adjust its opacity, and hide or restore all previews with a shortcut.

Why it helps: you can consult a reference without repeatedly switching windows or rearranging your main workspace.

First version: static image previews and captured screen regions. Live previews are a separate later possibility.

Questions to flesh out:

- Should a preview accept clicks or allow clicks to pass through to the window beneath it?
- Should previews remain visible across workspaces?
- Do you need live content, or are static captures enough?

### 9. Keyboard navigation hints

Press a shortcut to show short letter labels over available controls in the active window. Type a label to activate that control.

Example: activate a sidebar item, toolbar button, or tab without reaching for the mouse.

Why it helps: you can operate interfaces that lack useful keyboard shortcuts.

First version: controls that expose enough information for reliable detection and activation. Compatibility needs testing in the apps you actually use.

Questions to flesh out:

- Which apps should we test first?
- Should hints cover only the active window or everything on screen?
- How should the app handle interfaces whose controls cannot be detected reliably?

### 10. Temporary system modes

Apply a set of temporary computer settings and restore the previous settings when the mode ends.

Example: a Presentation mode keeps the display awake and activates your chosen notification settings. A Reading mode applies your preferred brightness and audio settings.

These modes change computer settings. Saved workspaces handle apps and window layouts. You could optionally activate both together.

Why it helps: repeated setup becomes one action, and you do not have to remember which settings to restore.

First version: one mode with a small set of supported settings, a visible active indicator, and manual exit. Verify each setting's control and restoration behaviour before including it.

Questions to flesh out:

- Which settings do you repeatedly change today?
- Should a mode end manually, after a timer, or when an app closes?
- If you change a setting yourself during a mode, should exiting preserve that change?

## Confirmed first release

Start with universal hotkeys, app and window switching, the command bar, and clipboard history. Seemless will live mainly in the menu bar, with a command bar and floating panels.

The temporary shelf, saved workspaces, and other feature ideas remain on the roadmap. The [product brief](product-brief.md) tracks confirmed decisions and proposed interaction defaults.

## Decisions for our next discussion

The next step is to choose the everyday workflows this app should improve:

- The apps and windows you switch between most often.
- The shortcuts you already use and want to preserve.
- The repeated actions that currently take too many clicks.
- Whether the first release is for your own use or eventual distribution.
- The detailed behaviour of the four features chosen for the first release.

Then we can define each chosen feature's behaviour, interface, edge cases, and a concrete way to check that it works.
