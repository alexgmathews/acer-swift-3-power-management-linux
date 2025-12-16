#!/usr/bin/env bash
################################################################################
#<<< ACER SWIFT 3 POWER MANAGEMENT CONFIGURATION >>>#
################################################################################
#
# SUMMARY: Configure wake sources for Acer Swift SF315-51
#
# Last Updated: 2025-12-16
#
# INSTALLATION:
#   sudo cp acer-power-behavior.sh /usr/local/sbin/
#   sudo chmod 744 /usr/local/sbin/acer-power-behavior.sh
#
# PURPOSE:
#   - Enable keyboard wake from screen sleep and system suspend
#   - Disable touchpad wake to prevent spurious wakeups
#   - Disable USB controller wake
#   - Disable PCIe root port wake
#
################################################################################


#=== CONFIGURATION ===#

KEYBOARD_DEVICE="/sys/devices/platform/i8042/serio0/power/wakeup"
KEYBOARD_CONTROL="/sys/devices/platform/i8042/serio0/power/control"

TOUCHPAD_DEVICE="/sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-SYNA7DB5:00/power/wakeup"
TOUCHPAD_CONTROL="/sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-SYNA7DB5:00/power/control"

ACPI_WAKEUP="/proc/acpi/wakeup"

LOG_TAG="acer-power-wake"


#=== LOGGING ===#

log() {
    echo "$1"
    logger -t "$LOG_TAG" "$1"
}

log_error() {
    echo "ERROR: $1" >&2
    logger -t "$LOG_TAG" -p user.err "ERROR: $1"
}


#=== CHECK ROOT ===#

if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi


#=== MAIN CONFIGURATION ===#

log "Starting Acer Swift 3 power management configuration"


# **Enable Keyboard Wake** #

if [ -f "$KEYBOARD_DEVICE" ]; then
    echo "enabled" > "$KEYBOARD_DEVICE" 2>/dev/null
    if [ $? -eq 0 ]; then
        log "Keyboard wake enabled"
    else
        log_error "Failed to enable keyboard wake"
    fi

    if [ -f "$KEYBOARD_CONTROL" ]; then
        echo "on" > "$KEYBOARD_CONTROL" 2>/dev/null
        [ $? -eq 0 ] && log "Keyboard power control set to 'on'"
    fi
else
    log_error "Keyboard device not found at $KEYBOARD_DEVICE"
fi


# **Disable Touchpad Wake** #

if [ -f "$TOUCHPAD_DEVICE" ]; then
    echo "disabled" > "$TOUCHPAD_DEVICE" 2>/dev/null
    if [ $? -eq 0 ]; then
        log "Touchpad wake disabled"
    else
        log_error "Failed to disable touchpad wake"
    fi

    if [ -f "$TOUCHPAD_CONTROL" ]; then
        echo "auto" > "$TOUCHPAD_CONTROL" 2>/dev/null
        [ $? -eq 0 ] && log "Touchpad power control set to 'auto'"
    fi
else
    log_error "Touchpad device not found at $TOUCHPAD_DEVICE"

    # Fallback: search for any I2C touchpad with wake enabled
    for device in /sys/devices/pci0000:00/0000:00:15.*/*/i2c-*/i2c-*/power/wakeup; do
        if [ -f "$device" ]; then
            status=$(cat "$device" 2>/dev/null)
            if [ "$status" = "enabled" ]; then
                echo "disabled" > "$device" 2>/dev/null
                [ $? -eq 0 ] && log "Disabled wake for alternative touchpad at $device"
            fi
        fi
    done
fi


# **Disable USB Controller Wake (XHC)** #

if [ -f "$ACPI_WAKEUP" ]; then
    xhc_status=$(grep "^XHC" "$ACPI_WAKEUP" | awk '{print $3}')

    if [ "$xhc_status" = "*enabled" ]; then
        echo "XHC" > "$ACPI_WAKEUP" 2>/dev/null
        if [ $? -eq 0 ]; then
            log "USB controller (XHC) wake disabled"
        else
            log_error "Failed to disable XHC wake"
        fi
    else
        log "USB controller (XHC) wake already disabled"
    fi
else
    log_error "ACPI wakeup interface not available at $ACPI_WAKEUP"
fi


# **Disable PCIe Root Port Wake (RP05, RP09)** #

if [ -f "$ACPI_WAKEUP" ]; then
    for device in RP05 RP09; do
        status=$(grep "^$device" "$ACPI_WAKEUP" | awk '{print $3}')

        if [ "$status" = "*enabled" ]; then
            echo "$device" > "$ACPI_WAKEUP" 2>/dev/null
            if [ $? -eq 0 ]; then
                log "PCIe port $device wake disabled"
            else
                log_error "Failed to disable $device wake"
            fi
        else
            log "PCIe port $device wake already disabled"
        fi
    done
fi


#=== VERIFICATION ===#

log "Configuration complete. Current status:"

if [ -f "$KEYBOARD_DEVICE" ]; then
    kb_status=$(cat "$KEYBOARD_DEVICE" 2>/dev/null)
    log "  Keyboard: $kb_status"
fi

if [ -f "$TOUCHPAD_DEVICE" ]; then
    tp_status=$(cat "$TOUCHPAD_DEVICE" 2>/dev/null)
    log "  Touchpad: $tp_status"
fi

if [ -f "$ACPI_WAKEUP" ]; then
    xhc_final=$(grep "^XHC" "$ACPI_WAKEUP" | awk '{print $3}')
    rp05_final=$(grep "^RP05" "$ACPI_WAKEUP" | awk '{print $3}')
    rp09_final=$(grep "^RP09" "$ACPI_WAKEUP" | awk '{print $3}')
    log "  XHC: $xhc_final"
    log "  RP05: $rp05_final"
    log "  RP09: $rp09_final"
fi

log "Acer Swift 3 power management configuration finished"

exit 0
