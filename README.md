# GPD Screen Orientation Fix

Fix the screen orientation on the GPD G1628-04 handheld, which ships with a natively portrait (1600x2560) eDP-1 panel that needs to be rotated for landscape use.

## What it does

The script rotates the built-in display left (270°) and persists the fix across:

- **Current session** — applied immediately via the Mutter DBus API
- **Future GNOME sessions** — writes `~/.config/monitors.xml`
- **GDM login screen** — writes `/var/lib/gdm3/.config/monitors.xml`
- **Boot console** — adds `panel_orientation` and `fbcon=rotate` kernel parameters to GRUB

## Usage

```bash
# Apply rotation everywhere (session + monitors.xml + GRUB + GDM)
bash fix-screen-orientation.sh

# Apply to current session only (no GRUB/GDM changes)
bash fix-screen-orientation.sh --now

# Only update GRUB and GDM (requires sudo)
bash fix-screen-orientation.sh --grub
```

## Panel details

| Property   | Value              |
|------------|--------------------|
| Connector  | eDP-1              |
| Vendor     | HSX                |
| Product    | YHB03P24           |
| Native res | 1600x2560 (portrait) |
| Refresh    | 144 Hz             |
| Scale      | 1.25x              |

## Requirements

- GNOME (Mutter) on Wayland or X11
- GDM display manager
- GRUB bootloader
