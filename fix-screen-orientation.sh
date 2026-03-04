#!/bin/bash
#
# fix-screen-orientation.sh — Fix GPD G1628-04 portrait panel orientation
#
# The built-in eDP-1 panel is natively portrait (1600x2560) but needs
# to be rotated left (270) for correct landscape use.
#
# Persists across reboots via:
#   1. Mutter DBus API (immediate, current session)
#   2. monitors.xml (GNOME session persistence)
#   3. GDM monitors.xml (login screen)
#   4. GRUB kernel parameter (boot console orientation)
#
# Usage:
#   bash fix-screen-orientation.sh          # Apply rotation now + persist
#   bash fix-screen-orientation.sh --now    # Apply rotation now only (no GRUB)
#   bash fix-screen-orientation.sh --grub   # Only update GRUB (needs sudo)
#

CONNECTOR="eDP-1"
MODE="1600x2560@143.999"
NATIVE_W=1600
NATIVE_H=2560
SCALE=1.25
TRANSFORM=3  # 0=normal, 1=90right, 2=180, 3=270left

info()  { printf '\033[0;32m[+]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
error() { printf '\033[0;31m[-]\033[0m %s\n' "$*"; }

MONITORS_XML='<monitors version="2">
  <configuration>
    <layoutmode>logical</layoutmode>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1.25</scale>
      <primary>yes</primary>
      <transform>
        <rotation>left</rotation>
        <flipped>no</flipped>
      </transform>
      <monitor>
        <monitorspec>
          <connector>eDP-1</connector>
          <vendor>HSX</vendor>
          <product>YHB03P24</product>
          <serial>0x00888888</serial>
        </monitorspec>
        <mode>
          <width>1600</width>
          <height>2560</height>
          <rate>143.999</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>'

apply_mutter_rotation() {
    info "Applying left rotation (270) via Mutter DBus API..."
    if gdbus call --session \
        --dest org.gnome.Mutter.DisplayConfig \
        --object-path /org/gnome/Mutter/DisplayConfig \
        --method org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig \
        1 \
        1 \
        "[(0, 0, $SCALE, uint32 $TRANSFORM, true, [('$CONNECTOR', '$MODE', @a{sv} {})])]" \
        "{'layout-mode': <uint32 1>}" \
        > /dev/null 2>&1; then
        info "Rotation applied successfully to current session."
    else
        error "Failed to apply rotation via DBus."
        warn "Writing monitors.xml instead -- log out and back in to apply."
    fi
}

update_monitors_xml() {
    local monitors_file="$HOME/.config/monitors.xml"
    info "Updating $monitors_file for session persistence..."

    if [ -f "$monitors_file" ]; then
        cp "$monitors_file" "${monitors_file}.bak"
        info "Backup saved to ${monitors_file}.bak"
    fi

    printf '%s\n' "$MONITORS_XML" > "$monitors_file"
    info "monitors.xml updated with left rotation."
}

update_grub() {
    info "Updating GRUB for boot console orientation..."

    local grub_file="/etc/default/grub"
    local grub_param="video=eDP-1:panel_orientation=right_side_up"
    local fbcon_param="fbcon=rotate:3"

    if [ ! -f "$grub_file" ]; then
        error "GRUB config not found at $grub_file"
        return 1
    fi

    local current
    current=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file" || true)

    if echo "$current" | grep -q "$grub_param"; then
        info "GRUB already has panel_orientation parameter."
    else
        info "Adding kernel parameters to GRUB..."
        sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $grub_param $fbcon_param\"|" "$grub_file"
        sudo sed -i 's|  | |g' "$grub_file"

        info "Running update-grub..."
        sudo update-grub

        info "GRUB updated. Boot console will be correctly oriented on next reboot."
    fi
}

update_gdm() {
    info "Configuring GDM login screen orientation..."
    local gdm_monitors="/var/lib/gdm3/.config/monitors.xml"

    sudo mkdir -p "$(dirname "$gdm_monitors")"
    printf '%s\n' "$MONITORS_XML" | sudo tee "$gdm_monitors" > /dev/null
    sudo chown gdm:gdm "$gdm_monitors" 2>/dev/null || true
    info "GDM login screen orientation configured."
}

main() {
    echo "========================================="
    echo " GPD G1628-04 Screen Orientation Fix"
    printf ' Panel: %sx%s -> Landscape (left 270)\n' "$NATIVE_W" "$NATIVE_H"
    echo "========================================="
    echo

    local mode="${1:-all}"

    case "$mode" in
        --now)
            apply_mutter_rotation
            update_monitors_xml
            ;;
        --grub)
            update_grub
            update_gdm
            ;;
        *)
            apply_mutter_rotation
            update_monitors_xml
            update_grub
            update_gdm
            echo
            info "All done! Orientation fixed and persisted across:"
            info "  - Current session (applied now)"
            info "  - Future GNOME sessions (monitors.xml)"
            info "  - GDM login screen"
            info "  - Boot console (GRUB kernel params)"
            ;;
    esac
}

main "$@"
