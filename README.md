# Omarchy Widgets

[![Omarchy](https://img.shields.io/badge/Omarchy-shell-1f2335?style=for-the-badge)](https://omarchy.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-plugin-54a3d8?style=for-the-badge)](https://quickshell.org/)
[![License](https://img.shields.io/badge/license-GPL--3.0-green?style=for-the-badge)](LICENSE)

Bar widgets for the Omarchy shell. Install only the ones you want.

| Folder | What it does |
|---|---|
| [`apps`](#apps) | Lists the open windows with a force kill button |
| [`drawer`](#drawer) | Folds the right side of the bar into a drawer, tray icons included |
| [`headset`](#headset) | Logitech G733 battery, sidetone and lights in the audio panel |
| [`hwstats`](#hwstats) | CPU, RAM and GPU usage and temperature |
| [`media`](#media) | Media controls for any MPRIS player |

## Install

Clone once, then follow the section of each widget you want:

```bash
git clone https://github.com/gabrielsitta4/omarchy-widgets ~/Documents/Projects/omarchy-widgets
mkdir -p ~/.config/omarchy/plugins ~/.config/omarchy/bar/scripts ~/.local/bin
```

## Update

```bash
git -C ~/Documents/Projects/omarchy-widgets pull
omarchy restart shell
```

## Apps

Lists the open windows with a button to force kill each one. Useful when a game freezes.

`force-kill` sends SIGKILL to the window's process and its children. For Steam and Proton games it also kills every process with the same `SteamGameId`, so Wine and the launcher go too. Without an argument it kills the focused window.

```bash
ln -s ~/Documents/Projects/omarchy-widgets/apps ~/.config/omarchy/plugins/local.apps
ln -s ~/Documents/Projects/omarchy-widgets/apps/force-kill ~/.local/bin/force-kill
omarchy-shell shell rescanPlugins
omarchy bar put local.apps --before omarchy.audio
```

For the shortcut, add this line to `~/.config/hypr/bindings.lua`, then run `hyprctl reload`:

```lua
o.bind("SUPER + SHIFT + W", "Force kill window", "force-kill")
```

- Click the bar icon to see the open windows. The X next to one kills it.
- Super+Shift+W kills the focused window, even a fullscreen game that hides the bar.
- The terminal running the shell or an agent shows up too; killing it closes that session.

## Drawer

Folds the right side of the bar into a drawer, tray icons included. You choose what stays pinned and what stays hidden.

```bash
ln -s ~/Documents/Projects/omarchy-widgets/drawer ~/.config/omarchy/plugins/local.drawer
ln -s ~/Documents/Projects/omarchy-widgets/drawer/tray ~/.config/omarchy/plugins/local.tray
omarchy-shell shell rescanPlugins
sed -i 's/"omarchy.tray"/"local.tray"/' ~/.config/omarchy/shell.json
omarchy bar put local.drawer --section right --index 0
~/.config/omarchy/plugins/local.drawer/drawer apply
omarchy restart shell
```

`local.tray` replaces the stock tray so the tray icons follow the drawer and the bar shows a single arrow.

- Click the arrow to collapse or expand the drawer. Collapsed, only pinned widgets and tray icons stay visible.
- With the drawer open, hover the arrow to show the hidden items. They open to the left and go away when the mouse leaves the bar. A panel opened from one of them keeps them visible until it closes.
- Right click the arrow to pin or hide each widget and tray icon. Changes apply when the list closes.

The drawer hides its neighbours in the bar without rebuilding it, so it relies on how the Omarchy bar is laid out. Check it after `omarchy update`. If that layout changes, every widget simply stays visible.

To remove it, run the line below, delete the `local.drawer` entry from `~/.config/omarchy/shell.json`, remove both links in `~/.config/omarchy/plugins/` and run `omarchy restart shell`.

```bash
sed -i 's/"local.tray"/"omarchy.tray"/' ~/.config/omarchy/shell.json
```

`drawer/tray` is based on the Omarchy tray widget and keeps its MIT license (`drawer/tray/LICENSE`).

## Headset

Logitech G733 battery, sidetone and lights inside the audio panel.

Install [headsetcontrol](https://github.com/Sapd/HeadsetControl). The package brings the udev rule that lets it talk to the headset without root, so unplug and plug the USB receiver back in afterwards.

```bash
omarchy pkg add headsetcontrol
ln -s ~/Documents/Projects/omarchy-widgets/headset ~/.config/omarchy/plugins/local.headset
ln -s ~/Documents/Projects/omarchy-widgets/headset/headset-battery ~/.config/omarchy/bar/scripts/headset-battery
ln -s ~/Documents/Projects/omarchy-widgets/headset/headset-set ~/.config/omarchy/bar/scripts/headset-set
omarchy-shell shell rescanPlugins
omarchy bar put local.headset --before omarchy.audio
```

Check that the headset is found with `headsetcontrol -b`.

- While the headset is on and set as the output, the audio icon shows the battery level and the audio panel shows its settings.
- Click the audio icon to change sidetone and turn the lights on or off, at the end of the audio panel. The microphone stays in the INPUT section of that panel.
- If the audio panel can't be reached, for example after an Omarchy update changes it, the widget shows its own icon and panel instead.
- The lights setting is saved in `~/.local/state/headset` and applied again when the headset turns on.

## Hwstats

Shows CPU usage and temperature, RAM in use, and GPU usage and temperature.

```
 2% 43°   8.1G  󰢮 0% 45°
```

Icons are CPU, RAM and GPU, drawn with a Nerd Font (JetBrainsMono Nerd Font comes with Omarchy). Hover it to see RAM and VRAM totals. Click it to open `btop`.

Needs an AMD CPU (`k10temp` sensor) and an AMD GPU (`amdgpu` sensor). Sensors are found by name, so it keeps working when the hwmon numbers change after a reboot.

```bash
ln -s ~/Documents/Projects/omarchy-widgets/hwstats/hwstats ~/.config/omarchy/bar/scripts/hwstats
```

Then add the module to a section under `bar.layout` in `~/.config/omarchy/shell.json`:

```json
{
  "id": "local.hwstats",
  "type": "command",
  "exec": "~/.config/omarchy/bar/scripts/hwstats",
  "interval": 3,
  "tooltip": "Hardware",
  "onClick": "omarchy launch or focus tui btop"
}
```

The shell reloads on save. Check the output with `~/.config/omarchy/bar/scripts/hwstats`.

The bar is the same on every monitor, so on a narrow screen the text can overlap the center widgets.

## Media

Controls any MPRIS player (YouTube Music, Spotify, browser tabs): previous, play/pause, next and the current track, with a popup that has the cover and a seek bar.

```bash
ln -s ~/Documents/Projects/omarchy-widgets/media ~/.config/omarchy/plugins/local.media
omarchy-shell shell rescanPlugins
omarchy bar put local.media --section right --index 0
```

- The buttons skip back, play/pause and skip forward. Any MPRIS player counts (music, videos, mpv). The widget stays while a player is playing or paused and hides when there is none.
- Click the track name, or right click any button, to open the popup. Drag the bar to jump inside the track.
- Pick what the bar shows under DISPLAY in the popup: the buttons and the name, only the name, or only the buttons. Same from the terminal: `omarchy bar set local.media display name` (`both`, `name`, `controls`).
- With more than one player open, the popup lists them so you can pick which one the buttons control.
- Track name length on the bar: `omarchy bar set local.media maxChars 40`.
