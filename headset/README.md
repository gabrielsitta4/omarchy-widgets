# Omarchy Headset

[![Omarchy](https://img.shields.io/badge/Omarchy-shell-1f2335?style=for-the-badge)](https://omarchy.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-plugin-54a3d8?style=for-the-badge)](https://quickshell.org/)
[![License](https://img.shields.io/badge/license-GPL--3.0-green?style=for-the-badge)](LICENSE)

Logitech G733 battery, sidetone and lights inside the audio panel of the Omarchy shell.

## Install

Install [headsetcontrol](https://github.com/Sapd/HeadsetControl). The package brings the udev rule that lets it talk to the headset without root, so unplug and plug the USB receiver back in afterwards.

```bash
omarchy pkg add headsetcontrol
```

Then the widget:

```bash
git clone https://github.com/gabrielsitta4/omarchy-headset ~/Documents/Projects/omarchy-headset
mkdir -p ~/.config/omarchy/plugins ~/.config/omarchy/bar/scripts
ln -s ~/Documents/Projects/omarchy-headset ~/.config/omarchy/plugins/local.headset
ln -s ~/Documents/Projects/omarchy-headset/headset-battery ~/.config/omarchy/bar/scripts/headset-battery
ln -s ~/Documents/Projects/omarchy-headset/headset-set ~/.config/omarchy/bar/scripts/headset-set
omarchy-shell shell rescanPlugins
omarchy bar put local.headset --before omarchy.audio
```

Check that the headset is found with `headsetcontrol -b`.

## Use

- While the headset is on and set as the output, the audio icon shows the battery level and the audio panel shows its settings.
- Click the audio icon to change sidetone and turn the lights on or off, at the end of the audio panel. The microphone stays in the INPUT section of that panel.
- If the audio panel can't be reached, for example after an Omarchy update changes it, the widget shows its own icon and panel instead.
- The lights setting is saved in `~/.local/state/headset` and applied again when the headset turns on.

## Update

```bash
git -C ~/Documents/Projects/omarchy-headset pull
omarchy restart shell
```
