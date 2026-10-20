# Omarchy Hardware Stats

[![Omarchy](https://img.shields.io/badge/Omarchy-shell-1f2335?style=for-the-badge)](https://omarchy.org/)
[![Bash](https://img.shields.io/badge/Bash-script-4eaa25?style=for-the-badge)](hwstats)
[![License](https://img.shields.io/badge/license-GPL--3.0-green?style=for-the-badge)](LICENSE)

Bar module for the Omarchy shell that shows CPU usage and temperature, RAM in use, and GPU usage and temperature.

```
CPU 2% 43°  RAM 8.1G  GPU 0% 45°
```

Hover it to see RAM and VRAM totals. Click it to open `btop`.

Needs an AMD CPU (`k10temp` sensor) and an AMD GPU (`amdgpu` sensor). Sensors are found by name, so it keeps working when the hwmon numbers change after a reboot.

## Install

```bash
git clone https://github.com/gabrielsitta4/omarchy-hwstats ~/Documents/Projects/omarchy-hwstats
mkdir -p ~/.config/omarchy/bar/scripts
ln -s ~/Documents/Projects/omarchy-hwstats/hwstats ~/.config/omarchy/bar/scripts/hwstats
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

## Update

```bash
git -C ~/Documents/Projects/omarchy-hwstats pull
```
