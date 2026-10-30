---
name: ui-logic-separation
description: "Keeps UI code apart from business code in any UI framework (React, Vue, Svelte, Flutter, SwiftUI, Compose and the like). The server owns rules and permissions, shared state lives in services or stores, a screen file holds only its layout while a logic file or hook beside it holds what it loads, what its controls do and what it decides to show, subtle rules live in pure tested code, and small per-screen components take plain values and callbacks. Use when creating or restructuring a screen, page, view, component, sheet or dialog, when UI code loads data, calls the network, checks a permission or computes a rule, or when a component forks on a mode flag. Not for a readability sweep of existing code (use find-readability-improvements), and not for a styling-only, copy-only or backend-only change."
---

# Separating UI from business code

Read the project's agent guide (`AGENTS.md`, `CLAUDE.md` or equivalent) and the **UI and business code** bullet in `.agents/project-facts.md` first. Together they name where UI lives, where shared state lives, where pure rules go, the shared components folder, and any screen to copy. Where the project disagrees with this skill, the project wins.

The words below are generic. Read "screen" as page, route or view, "component" as widget or view, "logic file" as a hook, view-model, controller, presenter or store slice, whatever the framework calls the thing that sits beside a screen and does its work.

## Where each piece of code goes (decide this first)

    a business rule or permission?            → the server. The UI may hide a control. It never decides.
    shared state (lists, the signed-in user)? → a service or store. The UI reads it and calls its methods.
    what this screen loads, what its controls
      do, what it shows when?                 → the screen's logic file
    a rule that can be subtly wrong (dates,
      money, what a role may see)?            → a pure function or model, with a unit test
    a formatter or helper only this screen
      uses?                                   → beside the screen, with no UI and no global state
    a drawn part only this screen uses?       → a component beside the screen, one per file
    a drawn part a second screen uses?        → the shared components folder
    anything else?                            → stop, name the code and ask where it goes

## The screen shape

1. The screen file holds the layout and nothing else. It reads top to bottom as what the user sees. Each event handler is one call into the logic: `onClick={() => logic.archive(list)}`.
2. The logic file holds the screen's state (loading, error, the rows on screen), its first load, every action, and the decisions the layout reads. After every `await` it checks the screen is still shown (mounted, not cancelled) before it touches UI state.
3. A logic file that outgrows the project's size budget becomes a folder, one job per file.
4. Small components take plain values and callbacks, never the logic object or the store.
5. A short piece of layout stays inline. Split a part out only when it has a name of its own: a card, a header, an empty state.

## Rules

- One component, one job. A component that renders very different things depending on a flag is several components. Put the shared layout in a parent, shared behaviour in a hook or mixin, and shared data in a value object.
- A mode is a named enum or union type, never a boolean passed down several levels or guessed from whether a callback is null.
- Parameters that always travel together become one named object.
- UI calls service or store methods. It never calls the network itself.
- A service only shows UI (a toast, a dialog) where no caller is waiting to handle the result.

## Worked example (illustrative names)

"Add an Archive button to the lists screen that hides archived lists."

    service    listsService.archive(id)            writes through the project's data layer, updates shared state
    rule       visibleLists(all, showArchived)     pure function, with a unit test
    logic      useListsScreen().archive(list)      awaits the service, then returns early if the screen is gone
    component  ArchiveButton({ onPress })          plain callback, no store access
    screen     <ArchiveButton onPress={() => logic.archive(list)} />

## Done means

- Each new rule has a unit test, and the logic has a test of its own. Quote the pass count.
- The project's lint or analyze command is clean. Quote the last line.
- Any structure check the project names in its facts passes. Quote its output.
- The screen file, read top to bottom, holds only layout.
