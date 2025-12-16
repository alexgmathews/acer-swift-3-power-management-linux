#!/usr/bin/env bash
# Unified installer for Acer Swift 3 Power Management Configuration
# Installs both power wake configuration and FN+F6 screen off remapping
# Run with: sudo ./install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


#=== Check Root Privileges ===#

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Please run with: sudo ./install.sh"
    exit 1
fi


#=== Installation Banner ===#

echo "======================================================================="
echo "  Acer Swift 3 Power Management Configuration - Unified Installer"
echo "======================================================================="
echo ""
echo "This installer will configure:"
echo "  1. Power wake behavior (keyboard wake, disable touchpad/USB/PCIe wake)"
echo "  2. FN+F6 screen off remapping (DPMS off instead of backlight toggle)"
echo ""


#=== Install Power Wake Configuration ===#

echo "--- Installing Power Wake Configuration ---"
echo ""

# Install configuration script
echo "1. Installing acer-power-behavior.sh to /usr/local/sbin/"
cp "$SCRIPT_DIR/acer-power-behavior.sh" /usr/local/sbin/
chmod 744 /usr/local/sbin/acer-power-behavior.sh

# Install systemd service
echo "2. Installing acer-power-behavior.service to /etc/systemd/system/"
cp "$SCRIPT_DIR/acer-power-behavior.service" /etc/systemd/system/
chmod 644 /etc/systemd/system/acer-power-behavior.service

# Enable and start service
echo "3. Enabling and starting acer-power-behavior.service"
systemctl daemon-reload
systemctl enable acer-power-behavior.service
systemctl start acer-power-behavior.service

# Verify service status
if systemctl is-active --quiet acer-power-behavior.service; then
    echo "   ✓ Service active and running"
else
    echo "   ✗ WARNING: Service failed to start"
    echo "   Check status: systemctl status acer-power-behavior.service"
fi

echo ""


#=== Install FN+F6 Remapping ===#

echo "--- Installing FN+F6 Screen Off Remapping ---"
echo ""

# Install hwdb override
echo "4. Installing hwdb file to /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf"
cp "$SCRIPT_DIR/90-acer-remap-fn-f6.conf" /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf
chmod 644 /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf

# Update hwdb database
echo "5. Updating hwdb database"
systemd-hwdb update

# Trigger udev reload for input devices
echo "6. Triggering udev reload for input devices"
udevadm trigger --subsystem-match=input --action=change

echo ""


#=== Installation Complete ===#

echo "======================================================================="
echo "  Installation Complete!"
echo "======================================================================="
echo ""
echo "REBOOT REQUIRED for FN+F6 remapping to take effect"
echo "(udev trigger needed for internal keyboards)"
echo ""
echo "After reboot:"
echo "  ✓ Keyboard will wake screen from sleep"
echo "  ✓ Touchpad/USB/PCIe will NOT wake system from suspend"
echo "  ✓ FN+F6 will turn off display (DPMS off)"
echo ""
echo "Verify installation:"
echo "  systemctl status acer-power-behavior.service"
echo "  cat /sys/devices/platform/i8042/serio0/power/wakeup  # Should show 'enabled'"
echo ""
echo "Test after reboot:"
echo "  xset dpms force off   # Press keyboard - should wake"
echo "  Press FN+F6           # Display should turn off"
echo ""
