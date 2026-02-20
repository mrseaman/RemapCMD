# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**RemapCMD** is a World of Warcraft addon for macOS that remaps modifier keys (Alt, Ctrl, Shift, Meta/⌘) to each other for keybinding compatibility. Its primary use case is remapping the Command key (⌘) to behave like Alt, so macOS players can use keybinds configured with Alt modifiers on Windows without reconfiguring them.

Rules are fully user-configurable and persisted via `SavedVariables`. The addon includes a graphical options panel registered in the WoW system Interface Options.

## File Structure

| File | Purpose |
|---|---|
| `RemapCMD/RemapCMD.toc` | Addon metadata, interface versions, SavedVariables declaration |
| `RemapCMD/RemapCMD.lua` | Core logic: binding scan, override binding application, slash commands |
| `RemapCMD/RemapCMD_Options.lua` | GUI options panel using the Settings canvas layout API |

## WoW Addon Conventions

- Written in Lua; no build step — the game client loads files directly.
- The `.toc` file declares metadata and lists Lua files to load in order. Supports comma-delimited `## Interface` values for multi-version targeting (since patch 10.2.7).
- Addon logic runs in WoW's sandboxed Lua environment.
- No package manager; no external dependencies.
- `local addonName, ns = ...` — `ns` is a shared namespace table passed between files of the same addon.

## Supported Client Versions

| Version | Interface # | Client |
|---|---|---|
| 12.0.1 | 120001 | Retail (Midnight) |
| 5.5.3 | 50503 | Mists of Pandaria Classic |
| 3.x | 38000 | Titan Reforged Classic (Blizzard/NetEase) |
| 2.5.5 | 20505 | Burning Crusade Classic Anniversary |
| 1.15.8 | 11508 | Classic Era |

The core keybinding logic works across all versions. The GUI options panel (`RemapCMD_Options.lua`) uses `Settings.RegisterCanvasLayoutCategory`, which only exists in retail Dragonflight (10.0) and later — it will error on Classic clients.

## Core Logic (RemapCMD.lua)

**How remapping works:**

Rule `{ from = "META", to = "ALT" }` means "pressing META should trigger ALT bindings."

Implementation: scan all bindings with `GetBinding(i)` (returns `action, category, key1, key2`), find keys containing the `to` modifier, create `from`-modifier override bindings via `SetOverrideBinding(frame, true, newKey, action)`.

`RemapKey(key, fromMod, toMod)` handles multi-modifier keys (e.g. `ALT-CTRL-X`) by parsing all modifier prefixes, substituting, and reassembling in canonical order (`ALT-CTRL-SHIFT-META`).

**Key implementation decisions:**
- `isPriority = true` in `SetOverrideBinding` — ensures our binding wins over any existing META binding (macOS WoW has some built-in META bindings that would otherwise silently block the override).
- No `GetBindingAction` guard — we always set the override; the user explicitly configured the rule.
- Listens to `ADDON_LOADED`, `PLAYER_LOGIN` (character bindings guaranteed loaded), and `UPDATE_BINDINGS`.

**Namespace exports** (used by `RemapCMD_Options.lua`):
- `ns.ApplyRules(verbose)` — reapply all rules
- `ns.ClearBindings()` — clear all override bindings
- `ns.openSettings()` — open the options panel (set by Options file)

## Relevant WoW API

- `GetNumBindings()` / `GetBinding(i)` — iterate all binding slots; `GetBinding` returns `(action, category, key1, key2)`
- `SetOverrideBinding(owner, isPriority, key, action)` — set a temporary override binding scoped to a frame
- `ClearOverrideBindings(owner)` — remove all overrides for a frame
- `Settings.RegisterCanvasLayoutCategory(frame, name)` — register a custom options panel (retail 10.0+ only); returns `(category, layout)`
- `Settings.RegisterAddOnCategory(category)` / `Settings.OpenToCategory(id)` — addon options panel registration and navigation
- `UIDropDownMenu_*` — dropdown widget API used in the options panel (deprecated in retail but still present)
- Key modifier strings: `ALT-`, `CTRL-`, `SHIFT-`, `META-` (META = ⌘ on macOS)

## SavedVariables

`RemapCMD_Config` — table with structure:
```lua
{
    rules = {
        { from = "META", to = "ALT" },  -- default
        -- up to 4 rules (one per source modifier)
    }
}
```

## Slash Commands

| Command | Effect |
|---|---|
| `/remapcmd` | Show help |
| `/remapcmd options` | Open GUI options panel |
| `/remapcmd list` | Show active rules |
| `/remapcmd add <FROM> <TO>` | Add or replace a rule |
| `/remapcmd remove <FROM>` | Remove a rule |
| `/remapcmd clear` | Remove all rules |
| `/remapcmd reset` | Restore default (META → ALT) |
| `/remapcmd refresh` | Reapply all rules |

## Known Limitations

- **Macro conditions** (`[mod:alt]` etc.) — evaluated by WoW's C-level secure macro system, which cannot be intercepted by addons. The only workaround is manually editing macro text to use `[mod:alt][mod:meta]` syntax.
- **Alt self-cast** — checks `IsAltKeyDown()` in secure context; cannot be remapped by an addon. Workaround: change Self Cast Key in Interface → Controls to a different modifier.
- **Classic GUI** — the options panel errors on Classic clients (pre-Dragonflight); the core keybinding logic still works.

## Testing

No automated test framework. Test in-game via `/reload` and observing behavior. Use `/console scriptErrors 1` or BugGrabber/BugSack to surface Lua errors. Use `/remapcmd refresh` to reapply rules without reloading.
