# Omarchy Drawer

[![Omarchy](https://img.shields.io/badge/Omarchy-shell-1f2335?style=for-the-badge)](https://omarchy.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-plugin-54a3d8?style=for-the-badge)](https://quickshell.org/)
[![License](https://img.shields.io/badge/license-GPL--3.0-green?style=for-the-badge)](LICENSE)

Bar widget for the Omarchy shell that folds the right side of the bar into a drawer, tray icons included. You choose what stays pinned and what stays hidden.

## Install

Everything it needs (`python3`, `hyprctl`) comes with Omarchy.

```bash
git clone https://github.com/gabrielsitta4/omarchy-drawer ~/Documents/Projects/omarchy-drawer
mkdir -p ~/.config/omarchy/plugins
ln -s ~/Documents/Projects/omarchy-drawer ~/.config/omarchy/plugins/local.drawer
ln -s ~/Documents/Projects/omarchy-drawer/tray ~/.config/omarchy/plugins/local.tray
omarchy-shell shell rescanPlugins
sed -i 's/"omarchy.tray"/"local.tray"/' ~/.config/omarchy/shell.json
omarchy bar put local.drawer --section right --index 0
~/.config/omarchy/plugins/local.drawer/drawer apply
omarchy restart shell
```

`local.tray` replaces the stock tray so the tray icons follow the drawer and the bar shows a single arrow.

## Use

- Click the arrow to collapse or expand the drawer. Collapsed, only pinned widgets and tray icons stay visible.
- With the drawer open, hover the arrow to show the hidden items. They open to the left and go away when the mouse leaves the bar. A panel opened from one of them keeps them visible until it closes.
- Right click the arrow to pin or hide each widget and tray icon. Changes apply when the list closes.

The drawer hides its neighbours in the bar without rebuilding it, so it relies on how the Omarchy bar is laid out. Check it after `omarchy update`. If that layout changes, every widget simply stays visible.

## Update

```bash
git -C ~/Documents/Projects/omarchy-drawer pull
omarchy restart shell
```

## Remove

```bash
sed -i 's/"local.tray"/"omarchy.tray"/' ~/.config/omarchy/shell.json
```

Then delete the `local.drawer` entry from `~/.config/omarchy/shell.json`, remove both links in `~/.config/omarchy/plugins/` and run `omarchy restart shell`.

`tray/` is based on the Omarchy tray widget and keeps its MIT license (`tray/LICENSE`).
