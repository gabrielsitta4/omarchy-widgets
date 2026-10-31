# Omarchy Apps

[![Omarchy](https://img.shields.io/badge/Omarchy-shell-1f2335?style=for-the-badge)](https://omarchy.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-plugin-54a3d8?style=for-the-badge)](https://quickshell.org/)
[![License](https://img.shields.io/badge/license-GPL--3.0-green?style=for-the-badge)](LICENSE)

Bar widget for the Omarchy shell that lists the open windows with a button to force kill each one. Useful when a game freezes.

`force-kill` sends SIGKILL to the window's process and its children. For Steam and Proton games it also kills every process with the same `SteamGameId`, so Wine and the launcher go too. Without an argument it kills the focused window.

## Install

Everything it needs (`hyprctl`, `jq`, `pgrep`, `notify-send`) comes with Omarchy.

```bash
git clone https://github.com/gabrielsitta4/omarchy-apps ~/Documents/Projects/omarchy-apps
mkdir -p ~/.config/omarchy/plugins ~/.local/bin
ln -s ~/Documents/Projects/omarchy-apps ~/.config/omarchy/plugins/local.apps
ln -s ~/Documents/Projects/omarchy-apps/force-kill ~/.local/bin/force-kill
omarchy-shell shell rescanPlugins
omarchy bar put local.apps --before omarchy.audio
```

## Shortcut

Add this line to `~/.config/hypr/bindings.lua`, then run `hyprctl reload`:

```lua
o.bind("SUPER + SHIFT + W", "Force kill window", "force-kill")
```

## Use

- Click the bar icon to see the open windows. The X next to one kills it.
- Super+Shift+W kills the focused window, even a fullscreen game that hides the bar.
- The terminal running the shell or an agent shows up too; killing it closes that session.

## Update

```bash
git -C ~/Documents/Projects/omarchy-apps pull
omarchy restart shell
```
