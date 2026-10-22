# AGENTS.md

Dark Terminal Protocol: an Omarchy (Quattro) theme in the style of Fallout's RobCo terminals
and Pip-Boy. Phosphor green on near-black, Vault-Tec yellow accent. Beyond the
colour files, it ships an XCursor theme, a Plymouth boot screen, a CRT screen shader and
the scripts that install them. Its Omarchy shell plugins (QML) live in the Terminal
Protocol Controller plugin (`~/Work/terminal-protocol-controller`,
github.com/Anerti/terminal-protocol-controller), which `colored-terminal-protocol`, the
coloured variant of this theme, shares.

There is no test suite, linter config or CI; see Verifying.

## Layout

| Path | What it is |
| ---- | ---------- |
| `colors.toml` | The palette every other file follows. Omarchy derives most app themes from it. |
| `shell.toml` | Omarchy shell surfaces (bar, popups, launcher, menu, lock, notifications...). Its header lists the mockup tokens the values come from. |
| `hyprland.lua` | Borders, groupbar, rounding, shadows; turns on `crt.frag` as the screen shader when the `vault-tec-crt` toggle file exists. |
| `alacritty.toml`, `foot.ini`, `ghostty.conf`, `kitty.conf`, `btop.theme`, `icons.theme`, `keyboard.rgb` | Per-app theme files Omarchy picks up. |
| `backgrounds/` | Wallpapers. |
| `logo/` | `vaulttec-omarchy.svg`: Vault-Tec wings around the Omarchy mark (generated), plus its fonts. |
| `cursors/VaultTec` | Built XCursor theme. |
| `hooks/vault-tec-cursor` | Omarchy `theme-set` / `post-boot` hook: VaultTec cursors while this theme is active. |
| `plymouth/src/` | Boot screen sources: `boot.html` + `fallout.css` (mockup copies), `vault-tec.script` template, `render-footer`, the Vault Boy GIF. |
| `plymouth/vault-tec/` | Built Plymouth theme (generated, ~4 MB of PNG sprites). |
| `bin/` | Installers/toggles for one part each: `vault-tec-cursor`, `vault-tec-crt`, `vault-tec-plymouth`. |
| `tools/` | Build scripts for generated assets. |
| `full-theme.sh` | Interactive setup (gum TUI), which needs the controller installed for the plugins: theme + cursors, then yes/no for menu, bar, login and the CRT effect; `--status`, `--unset` (everything back to built-in and the CRT effect off, then a ✓/✗ check of each plugin, built-in, the bar layout, the boot screen and the CRT effect). Signs off with the logo drawn as half-block art (cached in `~/.cache/vault-tec`). |

### Plugins

The plugins (`anerti.menu`, `anerti.lock`, `anerti.workspaces` and the status panels) are in
the controller's `plugins/`, with their installer, tools and notes (its `AGENTS.md`).
`full-theme.sh` takes them from `$TERMINAL_PROTOCOL_CONTROLLER_DIR`, else from the installed
controller (`~/.config/omarchy/plugins/anerti.terminal-protocol-controller`), and stops
with the install command when there is neither. The controller sets that variable to its
own checkout when it runs the steps.

`full-theme.sh` groups them as menu = `anerti.menu`, login = `anerti.lock` + the Plymouth
theme, and bar = every other plugin (computed, so a new plugin joins the bar group).

Enabling or disabling a clone only swaps its id where it sits in `shell.json`, and
re-enabling `omarchy.menu` (menu *and* logo button) drops it in the centre. So
`place_bar` sets the layout itself (the right side is never touched):
- Vault-Tec: the wedge alone in the centre, anchored there; every other widget on the left.
- Built-in: `omarchy.menu` then `omarchy.workspaces` alone on the left; every other
  widget in the centre, anchored on the clock.
Widgets move between the two with their settings, so switching back and forth is lossless.

## Generated files: edit the source, then rebuild

| Output | Source | Rebuild |
| ------ | ------ | ------- |
| `plymouth/vault-tec/*`, `plymouth/preview-*.png` | `plymouth/src/*` (font in `plymouth/src/fonts/`), `logo/vaulttec-omarchy.svg` | `tools/build-plymouth` (headless `chromium`, `magick`) |
| `cursors/VaultTec` | SVGs inside `tools/build-cursors` | `tools/build-cursors` (`rsvg-convert`, `magick`) |
| `logo/vaulttec-omarchy.svg`, `unlock.png`, and the copies in the controller's `anerti.lock`, `anerti.menu` and `anerti.workspaces` (ink) | `tools/build-logo` | `tools/build-logo [stroke] [gap]`; with `TERMINAL_PROTOCOL_CONTROLLER_DIR=<controller checkout>` it writes the copies too; `[out] [fill]` writes one file only |
| `backgrounds/1-omarchy-logo.jpg` | `tools/build-wallpaper`, `logo/` | `tools/build-wallpaper` (`rsvg-convert`, `magick`) |
| `backgrounds/3-omarchy-wordmark.jpg` | `tools/build-wallpaper-wordmark`, `logo/omarchy-wordmark.svg` (omarchy.org/brand), the built-in themes' wallpapers | `tools/build-wallpaper-wordmark` (`rsvg-convert`, `magick`) |

`tools/build-plymouth` measures every piece from the rendered mockup and writes the
1080p layout into `vault-tec.script` at `#@LAYOUT@`. Change layout in `boot.html`, not in
the generated script. The lock stage copies `anerti.lock`'s terminal (in the controller; keep
the two in step), and its banner lines (versions, copyright, hostname) and the init stage's footer
are drawn at install time by `render-footer`, not baked in.

## How things get installed (and why edits do not show up)

- **Theme:** Omarchy reads it from `~/.config/omarchy/themes/<slug>`, which should be a
  symlink to this checkout (slug here: `dark-terminal-protocol`, which Omarchy shows as
  "Dark Terminal Protocol"; the cursor hook matches it). If it is a copy
  instead, edits never reach it. Even through the symlink, Omarchy applies theme file
  edits only when `omarchy theme set <slug>` runs again.
- **Plugins** come from the controller (see Plugins above), which copies them into
  `~/.config/omarchy/plugins/<id>`. An installed controller older than the move has no
  `plugins/`: update it before running `full-theme.sh`.
- **Cursors** go to `~/.local/share/icons/VaultTec`. The hook is copied into
  `~/.config/omarchy/hooks/{theme-set,post-boot}.d/`. A stale hook copy counts as not
  installed.
- **Boot screen:** `bin/vault-tec-plymouth install` uses **sudo**, copies to
  `/usr/share/plymouth/themes/vault-tec`, adds an initcpio hook (`render-footer` per
  initramfs) and a pacman hook (rebuild on Omarchy upgrades and kernel installs), then
  rebuilds the initramfs (`limine-mkinitcpio`). It only writes what changed, so
  re-running it on a current install does no work and rebuilds nothing. The first
  install records the default theme; `uninstall` restores that one (Omarchy's `omarchy`
  when there is no record). `test` previews it from a text console with the
  passphrase `omarchy`. Omarchy's "set boot screen from theme" menu item
  (`omarchy-plymouth-set-by-theme`) switches the default back to `omarchy`; `omarchy
  theme set` does not.
- **CRT shader:** the flag file `~/.local/state/omarchy/toggles/vault-tec-crt`, read by
  `hyprland.lua`.

Built-in Omarchy sources to compare against: `/usr/share/omarchy/` (`bin/`, `default/`,
`shell/plugins/...`). `omarchy-plugin-catalog` gives each built-in's `sourceDir`.

## Conventions

**Shell scripts** (bash):
- A header comment says what the script does, how and why, and ends with a `Usage:` line.
- Paths come from `ROOT="$(cd "$(dirname "$0")/.." && pwd)"`.
- Subcommands are verbs (`install|uninstall|test`, `on|off|toggle|status`) dispatched by
  a final `case` that prints usage to stderr and exits 1.
- Comments explain why, in full sentences. Keep the same density.
- Installers are idempotent and only do work when the target differs: compare with
  `cmp`/`diff`, check state before enabling.

**Python tools:** `#!/usr/bin/env python3`, stdlib only, `ROOT` from `__file__`, shell
out to `magick` / `chromium` / `rsvg-convert` via `subprocess.run(check=True)`.

**Visual language:** use only `colors.toml` values: fg `#2cae2e`, bright `#d6ffe3`,
muted `#7c9480`, accent `#ffcc33`, urgent `#ff5a3c`, background `#06170d`. Text uses
the Share Tech Mono font with letter spacing, a soft green glow and CRT scanlines. The
mockup (`fallout.css` tokens) is the reference, and comments cite it ("as in the mockup").

## Verifying

- Shell: `bash -n <file>`. `shellcheck` is not installed; keep the existing
  `# shellcheck disable=` notes accurate anyway.
- `full-theme.sh --status` is read-only and safe. `--help` prints the header.
- Plugins: see the controller's `AGENTS.md`. To run `full-theme.sh` against a controller
  checkout, set `TERMINAL_PROTOCOL_CONTROLLER_DIR`.
- Boot screen: rebuild, look at `plymouth/preview-{lock,init}.png`, and preview it with
  `bin/vault-tec-plymouth test` (needs a text console).
- `source omarchy-shell-config` + `commit` writes the live `~/.config/omarchy/shell.json`
  and reloads the shell. To test a layout change, override `CONFIG_FILE` and
  `refresh_shell_config` *after* the helper is sourced, and work on a copy.
- To check a TUI without applying anything, run it under `script -qfc` and send Ctrl+C
  or the Cancel key.

## Safety

- Ask before running anything that uses sudo or changes the live desktop:
  `vault-tec-plymouth install|uninstall`, `full-theme.sh` (no args or `--unset`),
  `omarchy theme set`, plugin enable/disable, `omarchy restart shell`.
- The boot screen is where the LUKS passphrase is entered. Never install it without
  `tools/build-plymouth` having produced a complete `plymouth/vault-tec/`.

## Licensing

Fallout, Vault-Tec, Vault Boy, Pip-Boy and RobCo belong to Bethesda. The art is for
personal, non-commercial use; keep the README acknowledgement. Bundled fonts are OFL
(licences sit next to them).
