# Omarchy Media

[![Omarchy](https://img.shields.io/badge/Omarchy-shell-1f2335?style=for-the-badge)](https://omarchy.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-plugin-54a3d8?style=for-the-badge)](https://quickshell.org/)
[![License](https://img.shields.io/badge/license-GPL--3.0-green?style=for-the-badge)](LICENSE)

Bar widget for the Omarchy shell to control any MPRIS player (YouTube Music, Spotify, browser tabs): previous, play/pause, next and the current track, with a popup that has the cover and a seek bar.

## Install

```bash
git clone https://github.com/gabrielsitta4/omarchy-media ~/Documents/Projects/omarchy-media
mkdir -p ~/.config/omarchy/plugins
ln -s ~/Documents/Projects/omarchy-media ~/.config/omarchy/plugins/local.media
omarchy-shell shell rescanPlugins
omarchy bar put local.media --section right --index 0
```

## Use

- The buttons skip back, play/pause and skip forward. Any MPRIS player counts (music, videos, mpv). The widget stays while a player is playing or paused and hides when there is none.
- Click the track name, or right click any button, to open the popup. Drag the bar to jump inside the track.
- Pick what the bar shows under DISPLAY in the popup: the buttons and the name, only the name, or only the buttons. Same from the terminal: `omarchy bar set local.media display name` (`both`, `name`, `controls`).
- With more than one player open, the popup lists them so you can pick which one the buttons control.
- Track name length on the bar: `omarchy bar set local.media maxChars 40`.

## Update

```bash
git -C ~/Documents/Projects/omarchy-media pull
omarchy restart shell
```
