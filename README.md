# Dark Terminal Protocol

A dark Omarchy theme inspired by the RobCo terminals and Pip-Boy of the Fallout series: phosphor green on near-black, CRT scanlines, Vault Boy, and the Omarchy mark flying Vault-Tec wings.

![Mode](https://img.shields.io/badge/mode-dark-06170d?style=flat-square) ![Accent](https://img.shields.io/badge/accent-phosphor%20green-2cae2e?style=flat-square) ![Universe](https://img.shields.io/badge/universe-Fallout-ffcc33?style=flat-square) ![Era](https://img.shields.io/badge/era-Atomic%20Age-a68117?style=flat-square)

![Omarchy Quattro Ready](https://img.shields.io/badge/Omarchy-Quattro%20Ready-brightgreen?style=flat-square)

![Dark Terminal Protocol](preview.png)

The theme on its own, with Omarchy's bar. The Vault-Tec bar, the Pip-Boy menu and the status panels come with the [Terminal Protocol Controller](https://github.com/Anerti/terminal-protocol-controller).

## Wallpaper Gallery

This theme includes four wallpapers.

| Preview | Artwork |
| ------- | ------- |
| ![Omarchy logo](backgrounds/1-omarchy-logo.jpg) | Omarchy, the winged mark on black: "The malleable OS for the age of agents" |
| ![Welcome Home](backgrounds/2-welcome-home.jpg) | Welcome Home: Vault Boy giving a thumbs-up |
| ![Omarchy wordmark](backgrounds/3-omarchy-wordmark.jpg) | The Omarchy wordmark as the Fallout 4 title card, with an Omarchy theme wallpaper showing through each letter |
| ![Omarchy pin-up](backgrounds/4-omarchy-pin-up.jpg) | The Nuka-Cola space pin-up, rebranded: "Omarchy: Beautiful, fun & agentic Linux" |

## Color Palette

![](https://placehold.co/120x24/06170d/2cae2e?text=%2306170D)
![](https://placehold.co/120x24/0c2a18/6bc66d?text=%230C2A18)
![](https://placehold.co/120x24/11361d/d6ffe3?text=%2311361D)
![](https://placehold.co/120x24/2cae2e/000000?text=%232CAE2E)
![](https://placehold.co/120x24/6bc66d/000000?text=%236BC66D)
![](https://placehold.co/120x24/d6ffe3/000000?text=%23D6FFE3)
![](https://placehold.co/120x24/ffcc33/000000?text=%23FFCC33)
![](https://placehold.co/120x24/ff5a3c/000000?text=%23FF5A3C)

## Components

- Alacritty
- btop
- Chromium
- Foot
- Ghostty
- Hyprland (4px radius, green glow)
- Kitty
- Neovim
- Omarchy Shell (bar, lock screen, notifications, launcher, on-screen display, polkit, wallpaper picker)
- VS Code
- Shell plugins, from the [Terminal Protocol Controller](https://github.com/Anerti/terminal-protocol-controller): Pip-Boy menu, Omarchy terminal lock screen (with the PLEASE STAND BY hand-off), Vault-Tec workspaces wedge, and Vault Boy status panels (network, Bluetooth, audio, display, power, clock, weather, agents)
- From the controller too: VaultTec mouse cursors, the CRT effect (scanlines and vignette as a Hyprland screen shader), and the Omarchy terminal boot screen (passphrase prompt, then Vault Boy and INITIALIZING SYSTEM)

## Installation

Clone the repository, link it into your Omarchy themes directory and set it:

```bash
git clone <repo-url> ~/Work/dark-terminal-protocol
ln -s ~/Work/dark-terminal-protocol ~/.config/omarchy/themes/dark-terminal-protocol
omarchy theme set dark-terminal-protocol
```

### Vault-Tec extras

The shell plugins, cursors, CRT effect and boot screen ship with the [Terminal Protocol Controller](https://github.com/Anerti/terminal-protocol-controller) plugin:

```bash
omarchy plugin add https://github.com/Anerti/terminal-protocol-controller.git --enable
```

It adds a radiation icon to the bar with one switch per part, and its README lists the commands behind each switch.
