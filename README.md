# RemapCMD

A simple WoW add-on to remap modifier keys without changing the settings in keybindings. Designed for players who would play on both Windows and Mac clients.

## The Problem

WoW keybindings use `Alt`, `Ctrl`, and `Shift` as modifiers. On macOS, the Command key (Cmd) is not recognised as any of these, so keybinds set up on Windows (e.g. `Alt-1`) do not work when pressed with Cmd on Mac — even though Cmd sits in the same physical position as the Windows Alt key.

## How It Works

RemapCMD scans your existing keybindings and creates override bindings so that pressing one modifier triggers the actions bound to another. The default rule maps `Meta (Cmd)` -> `Alt`, meaning pressing `Cmd-1` on Mac fires the same action as `Alt-1` on Windows — no keybinding changes required.

Rules are fully configurable and persisted per character via SavedVariables.

## Usage

Configure rules via the graphical options panel (**Interface -> AddOns -> RemapCMD**) or slash commands:

| Command | Effect |
|---|---|
| `/remapcmd list` | Show active rules |
| `/remapcmd add <FROM> <TO>` | Add a remap rule (e.g. `add META ALT`) |
| `/remapcmd remove <FROM>` | Remove the rule for a source modifier |
| `/remapcmd reset` | Restore default rule (Meta -> Alt) |
| `/remapcmd clear` | Remove all rules |
| `/remapcmd refresh` | Reapply all rules |

Valid modifiers: `ALT`, `CTRL`, `SHIFT`, `META`

## Supported Versions

| Client | Interface # |
|---|---|
| Retail (Midnight) | 120001 |
| Mists of Pandaria Classic | 50503 |
| Wrath of the Lich King Classic | 38000 |
| Burning Crusade Classic | 20505 |
| Classic Era | 11508 |

## Known Limitations

- **Macro conditions** (`[mod:alt]` etc.) are evaluated by WoW's secure C engine and cannot be intercepted by addons. Edit macro text manually to add `[mod:meta]` alongside `[mod:alt]` if needed.
- **Alt self-cast** cannot be remapped by an addon. Change the Self Cast Key in Interface -> Controls as a workaround.
