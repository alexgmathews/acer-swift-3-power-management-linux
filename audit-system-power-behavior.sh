#!/usr/bin/env bash
################################################################################
#<<< SYSTEM POWER BEHAVIOR AUDIT >>>#
################################################################################
#
# SUMMARY: Comprehensive power management configuration audit and diagnostics
#
# Last Updated: 2025-12-16
#
# USAGE:
#   ./audit-system-power-behavior.sh
#
# PURPOSE:
#   Gathers complete power management configuration snapshot including:
#   - System information and kernel version
#   - Power management capabilities and sleep states
#   - Device wakeup configuration (keyboard, touchpad, USB, PCIe)
#   - Display power management settings
#   - systemd-logind configuration
#   - Loaded power management modules
#
################################################################################


OUTPUT_FILE="audit-system-power-behavior-$(date +%Y%m%d-%H%M%S).txt"


#=== HELPER FUNCTIONS ===#

log_message() {
    echo "$1" | tee -a "$OUTPUT_FILE"
}

log_separator() {
    log_message "================================================================================"
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}


#=== MAIN AUDIT ===#

clear

{

    log_separator
    echo "AUDIT SYSTEM POWER BEHAVIOR"
    echo "Generated: $(date +"%Y-%m-%d %H:%M:%S %Z")"
    log_separator
    echo ""


    # **SYSTEM INFORMATION** #

    echo "### SYSTEM INFORMATION ###"
    echo ""
    uname -a
    echo ""
    cat /etc/*-release 2>/dev/null | grep -E '^(NAME|VERSION)=' | head -4
    echo ""
    echo "Uptime: $(uptime)"
    echo ""


    # **POWER MANAGEMENT CAPABILITIES** #

    log_separator
    echo "### POWER MANAGEMENT CAPABILITIES ###"
    log_separator
    echo ""

    echo "--- Available Sleep States ---"
    cat /sys/power/state 2>/dev/null || echo "Unable to read"
    echo ""

    echo "--- Memory Sleep Mode ---"
    cat /sys/power/mem_sleep 2>/dev/null || echo "Unable to read"
    echo ""

    echo "--- Disk Sleep Mode ---"
    cat /sys/power/disk 2>/dev/null || echo "Unable to read"
    echo ""


    # **INPUT DEVICES** #

    log_separator
    echo "### INPUT DEVICES ###"
    log_separator
    echo ""

    for event in /dev/input/event*; do
        [ -c "$event" ] || continue
        event_num=$(basename "$event")

        device_type=$(udevadm info "$event" 2>/dev/null | grep -oE 'ID_INPUT_(KEYBOARD|MOUSE|TOUCHPAD)=1' | head -1 | cut -d= -f1 | cut -d_ -f3)

        if [ -n "$device_type" ]; then
            echo "--- Device: $event ---"
            echo "Type: $device_type"
            echo "Path: $(udevadm info "$event" 2>/dev/null | grep 'DEVPATH=' | cut -d= -f2)"
            echo "Name: $(cat /sys/class/input/$event_num/device/name 2>/dev/null)"
            echo ""
        fi
    done


    # **DEVICE WAKEUP CONFIGURATION** #

    log_separator
    echo "### DEVICE WAKEUP CONFIGURATION ###"
    log_separator
    echo ""

    echo "--- ACPI Wakeup Devices (/proc/acpi/wakeup) ---"
    if [ -f /proc/acpi/wakeup ]; then
        cat /proc/acpi/wakeup
    else
        echo "Not available"
    fi
    echo ""

    echo "--- Sysfs Wakeup Devices ---"
    for device in /sys/devices/*/*/power/wakeup /sys/devices/*/*/*/power/wakeup; do
        [ -f "$device" ] || continue
        wakeup_status=$(cat "$device" 2>/dev/null)
        if [ "$wakeup_status" = "enabled" ] || [ "$wakeup_status" = "disabled" ]; then
            device_path=$(dirname $(dirname "$device"))
            device_name=$(basename "$device_path")
            echo "Device: $device_name"
            echo "  Path: $device_path"
            echo "  Wakeup: $wakeup_status"
            [ -f "$device_path/name" ] && echo "  Name: $(cat "$device_path/name" 2>/dev/null)"
            echo ""
        fi
    done


    # **KEYBOARD CONFIGURATION** #

    log_separator
    echo "### KEYBOARD CONFIGURATION ###"
    log_separator
    echo ""

    if [ -f /sys/devices/platform/i8042/serio0/power/wakeup ]; then
        echo "Keyboard device: /sys/devices/platform/i8042/serio0"
        echo "  Wakeup: $(cat /sys/devices/platform/i8042/serio0/power/wakeup 2>/dev/null)"
        echo "  Control: $(cat /sys/devices/platform/i8042/serio0/power/control 2>/dev/null)"
    else
        echo "i8042 keyboard device not found"
    fi
    echo ""

    echo "Keyboard device info (/dev/input/event3):"
    if [ -e /dev/input/event3 ]; then
        udevadm info /dev/input/event3 2>/dev/null | grep -E '(DEVPATH|KEYBOARD_KEY)'
    else
        echo "  Not found"
    fi
    echo ""


    # **TOUCHPAD CONFIGURATION** #

    log_separator
    echo "### TOUCHPAD CONFIGURATION ###"
    log_separator
    echo ""

    echo "Searching for touchpad devices..."
    found_touchpad=false
    for device in /sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-*/power/wakeup; do
        [ -f "$device" ] || continue
        device_path=$(dirname $(dirname "$device"))
        device_name=$(basename "$device_path")
        if echo "$device_name" | grep -qiE '(touchpad|synaptics|elan|syna)'; then
            echo "Touchpad device: $device_path"
            echo "  Name: $device_name"
            echo "  Wakeup: $(cat "$device" 2>/dev/null)"
            [ -f "$(dirname "$device")/control" ] && echo "  Control: $(cat "$(dirname "$device")/control" 2>/dev/null)"
            found_touchpad=true
        fi
    done
    [ "$found_touchpad" = false ] && echo "No touchpad devices found"
    echo ""


    # **DISPLAY POWER MANAGEMENT** #

    log_separator
    echo "### DISPLAY POWER MANAGEMENT ###"
    log_separator
    echo ""

    if check_command xset; then
        export DISPLAY=:0
        echo "--- DPMS Status ---"
        xset q 2>/dev/null | grep -A 10 "DPMS" || echo "Unable to query DPMS"
        echo ""
        echo "--- Screen Saver ---"
        xset q 2>/dev/null | grep -A 5 "Screen Saver" || echo "Unable to query screen saver"
    else
        echo "xset not available"
    fi
    echo ""


    # **SYSTEMD-LOGIND CONFIGURATION** #

    log_separator
    echo "### SYSTEMD-LOGIND CONFIGURATION ###"
    log_separator
    echo ""

    echo "--- /etc/systemd/logind.conf ---"
    if [ -f /etc/systemd/logind.conf ]; then
        grep -vE '^(#|$)' /etc/systemd/logind.conf || echo "(all defaults)"
    else
        echo "Not found"
    fi
    echo ""

    echo "--- Current logind settings ---"
    loginctl show-session 2>/dev/null | grep -iE '(HandlePower|HandleSuspend|HandleLid)' || echo "Unable to query"
    echo ""


    # **USB AUTOSUSPEND** #

    log_separator
    echo "### USB AUTOSUSPEND CONFIGURATION ###"
    log_separator
    echo ""

    for usb in /sys/bus/usb/devices/*/power/control; do
        [ -f "$usb" ] || continue
        device=$(dirname $(dirname "$usb"))
        control=$(cat "$usb" 2>/dev/null)
        product=$(cat "$device/product" 2>/dev/null)
        echo "Device: $(basename "$device")"
        echo "  Control: $control"
        [ -n "$product" ] && echo "  Product: $product"
        echo ""
    done


    # **KERNEL PARAMETERS** #

    log_separator
    echo "### KERNEL PARAMETERS ###"
    log_separator
    echo ""

    echo "--- Boot parameters ---"
    cat /proc/cmdline
    echo ""


    # **POWER MANAGEMENT MODULES** #

    log_separator
    echo "### LOADED POWER MANAGEMENT MODULES ###"
    log_separator
    echo ""

    lsmod | grep -iE '(acpi|pm|power|suspend|wake|i8042)'
    echo ""


    log_separator
    echo "AUDIT COMPLETE"
    log_separator

} | tee "$OUTPUT_FILE"

echo ""
echo "Audit saved to: $OUTPUT_FILE"
