#!/usr/bin/env bash
# Unified uninstaller for Acer Swift 3 Power Management Configuration
# Removes both power wake configuration and FN+F6 screen off remapping
# Handles partial installations
# Run with: sudo ./uninstall.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


#=== Check Root Privileges ===#

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Please run with: sudo ./uninstall.sh"
    exit 1
fi


#=== Uninstallation Banner ===#

echo "======================================================================="
echo "  Acer Swift 3 Power Management Configuration - Unified Uninstaller"
echo "======================================================================="
echo ""
echo "This uninstaller will remove:"
echo "  1. Power wake behavior configuration"
echo "  2. FN+F6 screen off remapping"
echo ""


#=== Uninstall Power Wake Configuration ===#

echo "--- Uninstalling Power Wake Configuration ---"
echo ""

# Stop and disable service
if systemctl list-unit-files | grep -q "acer-power-behavior.service"; then
    echo "1. Stopping and disabling acer-power-behavior.service"
    systemctl stop acer-power-behavior.service 2>/dev/null || echo "   ⚠ Service already stopped or not running"
    systemctl disable acer-power-behavior.service 2>/dev/null || echo "   ⚠ Service already disabled"
else
    echo "1. Service not found (skipping)"
fi

# Remove service file
if [ -f /etc/systemd/system/acer-power-behavior.service ]; then
    echo "2. Removing /etc/systemd/system/acer-power-behavior.service"
    rm /etc/systemd/system/acer-power-behavior.service
else
    echo "2. Service file not found (skipping)"
fi

# Remove configuration script
if [ -f /usr/local/sbin/acer-power-behavior.sh ]; then
    echo "3. Removing /usr/local/sbin/acer-power-behavior.sh"
    rm /usr/local/sbin/acer-power-behavior.sh
else
    echo "3. Configuration script not found (skipping)"
fi

# Reload systemd
echo "4. Reloading systemd daemon"
systemctl daemon-reload

echo ""


#=== Uninstall FN+F6 Remapping ===#

echo "--- Uninstalling FN+F6 Screen Off Remapping ---"
echo ""

# Remove hwdb override
if [ -f /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf ]; then
    echo "5. Removing /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf"
    rm /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf
else
    echo "5. hwdb override file not found (skipping)"
fi

# Update hwdb database
echo "6. Updating hwdb database"
systemd-hwdb update

# Trigger udev reload for input devices
echo "7. Triggering udev reload for input devices"
udevadm trigger --subsystem-match=input --action=change

echo ""


#=== Uninstallation Complete ===#

echo "======================================================================="
echo "  Uninstallation Complete!"
echo "======================================================================="
echo ""
echo "REBOOT REQUIRED for all changes to take effect"
echo ""
echo "After reboot:"
echo "  ✓ Power wake settings will revert to system defaults"
echo "  ✓ FN+F6 will revert to original behavior (backlight toggle)"
echo ""
echo "System defaults after reboot:"
echo "  - Keyboard wake: likely disabled (default behavior)"
echo "  - FN+F6: toggles backlight only (original behavior)"
echo ""
