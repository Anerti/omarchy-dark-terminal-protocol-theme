# AGENTS.md

Dark Terminal Protocol: an Omarchy (Quattro) theme in the style of Fallout's RobCo terminals
and Pip-Boy. Phosphor green on near-black, Vault-Tec yellow accent. It holds the colour
files, wallpapers and the lock emblem (`unlock.png`). Everything else it used to ship (the
Omarchy shell plugins, VaultTec cursors, CRT screen shader and Plymouth boot screen) lives
in the Terminal Protocol
Controller plugin (`~/Work/terminal-protocol-controller`,
github.com/Anerti/terminal-protocol-controller), which `colored-terminal-protocol`, the
coloured variant of this theme, shares.

There is no test suite, linter config or CI; see Verifying.

## Layout

| Path | What it is |
| ---- | ---------- |
| `colors.toml` | The palette every other file follows. Omarchy derives most app themes from it. |
| `shell.toml` | Omarchy shell surfaces (bar, popups, launcher, menu, lock, notifications...). Its header lists the mockup tokens the values come from. |
| `hyprland.lua` | Borders, groupbar, rounding, shadows. Omarchy drops it from a theme installed from git, so nothing else may depend on it. |
| `alacritty.toml`, `foot.ini`, `ghostty.conf`, `kitty.conf`, `btop.theme`, `icons.theme`, `keyboard.rgb` | Per-app theme files Omarchy picks up. |
| `backgrounds/` | Wallpapers. |
| `logo/` | `vaulttec-omarchy.svg`: Vault-Tec wings around the Omarchy mark (generated), the Omarchy wordmark and the wallpaper fonts. Local only (`.gitignore`), like `tools/`, which is the only thing that reads it. |
| `unlock.png` | Omarchy's built-in lock screen emblem (generated). |
| `tools/` | Build scripts for generated assets. Local only (`.gitignore`): a fresh clone has the outputs but not the scripts; the last tracked versions are in git history. |

## Generated files: edit the source, then rebuild

`tools/` and `logo/` are local only, so these rebuilds work only where they still exist.

| Output | Source | Rebuild |
| ------ | ------ | ------- |
| `logo/vaulttec-omarchy.svg`, `unlock.png`, and the controller's copies (`anerti.lock`, `anerti.menu`, `anerti.workspaces` (ink), `plymouth/src/`) | `tools/build-logo` | `tools/build-logo [stroke] [gap]`; with `TERMINAL_PROTOCOL_CONTROLLER_DIR=<controller checkout>` it writes the copies too; `[out] [fill]` writes one file only |
| `backgrounds/1-omarchy-logo.jpg` | `tools/build-wallpaper`, `logo/` | `tools/build-wallpaper` (`rsvg-convert`, `magick`) |
| `backgrounds/3-omarchy-wordmark.jpg` | `tools/build-wallpaper-wordmark`, `logo/omarchy-wordmark.svg` (omarchy.org/brand), the built-in themes' wallpapers | `tools/build-wallpaper-wordmark` (`rsvg-convert`, `magick`) |

## How it gets installed (and why edits do not show up)

Omarchy reads the theme from `~/.config/omarchy/themes/<slug>` (slug here:
`dark-terminal-protocol`, which Omarchy shows as "Dark Terminal Protocol"; the controller's
cursor hook matches it). That should be a symlink to this checkout: Omarchy treats a folder
there that contains `.git` as a theme installed from git and drops its `hyprland.lua` and
terminal configs (`/usr/bin/omarchy-theme-set`, `theme_came_from_a_repo`). A copy instead
of a symlink never sees edits. Even through the symlink, Omarchy applies theme file edits
only when `omarchy theme set <slug>` runs again.

Built-in Omarchy sources to compare against: `/usr/share/omarchy/` (`bin/`, `default/`,
`themes/`).

## Conventions

**Python tools:** `#!/usr/bin/env python3`, stdlib only, `ROOT` from `__file__`, shell
out to `magick` / `chromium` / `rsvg-convert` via `subprocess.run(check=True)`.

Comments explain why, in full sentences. Keep the same density.

**Visual language:** use only `colors.toml` values: fg `#2cae2e`, bright `#d6ffe3`,
muted `#7c9480`, accent `#ffcc33`, urgent `#ff5a3c`, background `#06170d`. Text uses
the Share Tech Mono font with letter spacing, a soft green glow and CRT scanlines. The
mockup (`fallout.css` tokens, in the controller's `plymouth/src/`) is the reference, and
comments cite it ("as in the mockup").

## Verifying

- Python tools: `python3 -c "import ast; ast.parse(open('tools/<name>').read())"`, then run
  them with an `[out]` path in a scratch folder when they take one.
- Theme files: `omarchy theme set dark-terminal-protocol`, then look at the desktop.
- Plugins, cursors, CRT effect and boot screen: see the controller's `AGENTS.md`.

## Safety

- Ask before running `omarchy theme set`: it changes the live desktop.

## Licensing

Fallout, Vault-Tec, Vault Boy, Pip-Boy and RobCo belong to Bethesda. The art is for
personal, non-commercial use; keep the README acknowledgement. The theme bundles no fonts
any more; the controller's are OFL (licences sit next to them).
