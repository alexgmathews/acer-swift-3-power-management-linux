#!/usr/bin/env bash
################################################################################
#<<< POWER BUTTON IDENTIFICATION SCRIPT >>>#
################################################################################
#
# SUMMARY: Identify and monitor all power-related button mappings
#
# Last Updated: 2025-12-16
#
# USAGE:
#   ./identify-power-buttons.sh [--monitor]
#
# OPTIONS:
#   (none)      Show all power button configurations and devices
#   --monitor   Interactive mode - press buttons to see which devices respond
#               REQUIRES root or sudo privilege to monitor and evtest
#
# PURPOSE:
#   Identify power, sleep, and suspend button mappings on systems with
#   non-standard configurations (like Acer laptops)
#
################################################################################


MONITOR_MODE=false
if [ "$1" = "--monitor" ]; then
    MONITOR_MODE=true
fi

OUTPUT_FILE="identify-power-buttons-$(date +%Y%m%d-%H%M%S).txt"


#=== HELPER FUNCTIONS ===#

log_message() {
    echo "$1" | tee -a "$OUTPUT_FILE"
}

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_dependencies() {
    if [ "$MONITOR_MODE" = true ]; then
        local errors=false

        # Check for evtest command
        if ! check_command evtest; then
            echo ""
            echo "ERROR: Missing dependency 'evtest'. Install with:"
            echo ""
            echo "$ sudo apt-get update"
            echo "$ sudo apt-get install evtest -y"
            echo ""
            errors=true
        fi

        # Check for sudo privilege
        if [ "$EUID" -ne 0 ]; then
            echo ""
            echo "ERROR: Monitor mode requires root privileges"
            echo ""
            echo "$ sudo ./identify-power-buttons.sh --monitor"
            echo ""
            errors=true
        fi

        # Exit if any errors found
        if [ "$errors" = "true" ]; then
            exit 1
        fi
    fi
}


#=== SYSTEM INFORMATION ===#

# Run dependency checks
check_dependencies

clear

# Skip diagnostic output if in monitor mode
if [ "$MONITOR_MODE" = false ]; then

{

echo "================================================================================"
echo "IDENTIFY POWER BUTTONS"
echo "Generated: $(date +"%Y-%m-%d %H:%M:%S %Z")"
echo "================================================================================"
echo ""

echo "### SYSTEM INFORMATION ###"
echo ""
echo "System: $(uname -r)"
echo "Hardware: $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "unknown")"
echo "Vendor: $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "unknown")"
echo ""


#=== ACPI BUTTON DEVICES ===#

echo "================================================================================"
echo "### ACPI BUTTON DEVICES ###"
echo "================================================================================"
echo ""

if [ -d /proc/acpi/button ]; then
    echo "Found ACPI button directory structure:"
    tree -L 3 /proc/acpi/button 2>/dev/null || find /proc/acpi/button -type f | while read f; do
        echo "  $f"
        if [ -f "$f/info" ]; then
            cat "$f/info" 2>/dev/null | sed 's/^/    /'
        fi
    done
else
    echo "No /proc/acpi/button directory found"
fi
echo ""

echo "ACPI button events:"
if [ -d /proc/acpi/button ]; then
    for button_type in power sleep lid; do
        if [ -d "/proc/acpi/button/$button_type" ]; then
            for device in /proc/acpi/button/$button_type/*; do
                if [ -d "$device" ]; then
                    device_name=$(basename "$device")
                    echo "  Type: $button_type"
                    echo "  Device: $device_name"
                    if [ -f "$device/info" ]; then
                        echo "  Info:"
                        cat "$device/info" 2>/dev/null | sed 's/^/    /'
                    fi
                fi
            done
        fi
    done
else
    echo "  (ACPI button structure not available)"
fi
echo ""


#=== INPUT DEVICES WITH POWER CAPABILITIES ===#

echo "================================================================================"
echo "### INPUT DEVICES WITH POWER CAPABILITIES ###"
echo "================================================================================"
echo ""

for event in /dev/input/event*; do
    if [ -c "$event" ]; then
        event_num=$(basename "$event")

        # Get device capabilities
        capabilities=$(udevadm info "$event" 2>/dev/null | grep -E '(ID_INPUT|TAGS|NAME)' | grep -iE '(power|key|button)')

        if [ -n "$capabilities" ]; then
            echo "--- $event ---"

            # Device name
            device_name=$(udevadm info --query=property "$event" 2>/dev/null | grep '^ID_MODEL=' | cut -d= -f2)
            if [ -z "$device_name" ]; then
                device_name=$(cat /sys/class/input/$event_num/device/name 2>/dev/null)
            fi
            echo "Name: $device_name"

            # Show relevant properties
            udevadm info "$event" 2>/dev/null | grep -E 'ID_INPUT_KEY|ID_INPUT_KEYBOARD|TAGS|ID_PATH'

            # Check for power switch tag
            if udevadm info "$event" 2>/dev/null | grep -q 'TAGS=.*power-switch'; then
                echo "*** POWER SWITCH DEVICE ***"
            fi

            echo ""
        fi
    fi
done


#=== XINPUT DEVICES ===#

echo "================================================================================"
echo "### XINPUT DEVICE LIST ###"
echo "================================================================================"
echo ""

if check_command xinput; then
    export DISPLAY=:0
    echo "All input devices:"
    xinput list 2>/dev/null
    echo ""

    echo "Keyboard devices (potential power button sources):"
    xinput list 2>/dev/null | grep -iE '(keyboard|power|button)' | while read line; do
        device_id=$(echo "$line" | grep -oP 'id=\K\d+')
        if [ -n "$device_id" ]; then
            echo "  Device: $line"
            echo "  Properties:"
            xinput list-props "$device_id" 2>/dev/null | grep -iE '(power|button|enabled)' | sed 's/^/    /'
        fi
    done
else
    echo "xinput not available (X11 not running or not installed)"
fi
echo ""


#=== DCONF/GSETTINGS POWER BUTTON CONFIGURATION ===#

echo "================================================================================"
echo "### CINNAMON POWER BUTTON SETTINGS ###"
echo "================================================================================"
echo ""

if check_command gsettings; then
    echo "Power button action:"
    gsettings get org.cinnamon.settings-daemon.plugins.power button-power 2>/dev/null || \
    echo "  Not configured or not available"

    echo ""
    echo "Sleep button action:"
    gsettings get org.cinnamon.settings-daemon.plugins.power button-sleep 2>/dev/null || \
    echo "  Not configured or not available"

    echo ""
    echo "Suspend button action:"
    gsettings get org.cinnamon.settings-daemon.plugins.power button-suspend 2>/dev/null || \
    echo "  Not configured or not available"

    echo ""
    echo "Lid close action (when on AC):"
    gsettings get org.cinnamon.settings-daemon.plugins.power lid-close-ac-action 2>/dev/null || \
    echo "  Not configured or not available"

    echo ""
    echo "All power-related settings:"
    gsettings list-recursively org.cinnamon.settings-daemon.plugins.power 2>/dev/null | grep -iE '(button|suspend|sleep|lid)' || \
    echo "  Not available"
else
    echo "gsettings not available"
fi
echo ""


#=== SYSTEMD-LOGIND CONFIGURATION ===#

echo "================================================================================"
echo "### SYSTEMD-LOGIND BUTTON HANDLING ###"
echo "================================================================================"
echo ""

echo "Logind configuration (/etc/systemd/logind.conf):"
if [ -f /etc/systemd/logind.conf ]; then
    grep -E '^(HandlePowerKey|HandleSuspendKey|HandleHibernateKey|HandleLidSwitch)' /etc/systemd/logind.conf 2>/dev/null | sed 's/^/  /'
    if [ $? -ne 0 ]; then
        echo "  (all using defaults - check man logind.conf for values)"
    fi
else
    echo "  Not found"
fi
echo ""

echo "Current logind settings:"
loginctl show-session 2>/dev/null | grep -iE '(HandlePower|HandleSuspend|HandleLid)' | sed 's/^/  /' || echo "  Unable to query"
echo ""


#=== KEYBOARD KEY MAPPINGS ===#

echo "================================================================================"
echo "### KEYBOARD SPECIAL KEY MAPPINGS ###"
echo "================================================================================"
echo ""

echo "Your keyboard special key mappings (from udev):"
for event in /dev/input/event*; do
    if udevadm info "$event" 2>/dev/null | grep -q 'ID_INPUT_KEYBOARD=1'; then
        event_name=$(udevadm info "$event" 2>/dev/null | grep 'ID_MODEL=' | cut -d= -f2)
        echo "Keyboard: $event_name ($event)"
        udevadm info "$event" 2>/dev/null | grep '^E: KEYBOARD_KEY' | sed 's/^E: KEYBOARD_KEY_/  Scancode /' | sed 's/=/: /'
        echo ""
    fi
done


#=== EXPECTED KEY CODES ===#

echo "================================================================================"
echo "### EXPECTED KEY CODES FOR POWER BUTTONS ###"
echo "================================================================================"
echo ""

echo "Key codes to watch for:"
echo "  KEY_POWER (116)       - Physical power button"
echo "  KEY_SLEEP (142)       - Sleep button"
echo "  KEY_SUSPEND (205)     - Suspend button"
echo "  KEY_WAKEUP (143)      - Wake button"
echo "  KEY_PROG1 (148)       - Programmable key 1 (sometimes used for power)"
echo "  KEY_PROG2 (149)       - Programmable key 2"
echo "  BTN_0 (256)           - Generic button 0 (sometimes power)"
echo ""

} | tee "$OUTPUT_FILE"

echo ""
echo "Report saved to: $OUTPUT_FILE"
echo ""

fi  # End of diagnostic output section


#=== MONITOR MODE ===#

if [ "$MONITOR_MODE" = true ]; then
    echo "================================================================================"
    echo "### INTERACTIVE BUTTON MONITORING MODE ###"
    echo "================================================================================"
    echo ""

    echo "This mode will monitor ALL input devices for button presses."
    echo ""
    echo "Instructions:"
    echo "  1. Press Ctrl+C to stop monitoring"
    echo "  2. Press your power button, sleep button, or other special keys"
    echo "  3. Watch for events with KEY_POWER, KEY_SLEEP, KEY_SUSPEND, etc."
    echo ""
    echo "Available devices:"
    ls -1 /dev/input/event* | nl
    echo ""
    echo "Press Enter to begin monitoring..."
    read -r dummy < /dev/tty
    echo ""

    # Monitor all event devices simultaneously
    for event in /dev/input/event*; do
        if [ -c "$event" ]; then
            device_name=$(cat /sys/class/input/$(basename "$event")/device/name 2>/dev/null)
            (
                evtest "$event" 2>/dev/null | while read line; do
                    # Only show key events and filter for power-related keys
                    if echo "$line" | grep -qE '(KEY_POWER|KEY_SLEEP|KEY_SUSPEND|KEY_WAKEUP|KEY_PROG|BTN_|type 1)'; then
                        echo "[$event - $device_name] $line"
                    fi
                done
            ) &
        fi
    done

    # Wait for user interrupt
    wait
else
    echo "================================================================================"
    echo "### NEXT STEPS ###"
    echo "================================================================================"
    echo ""
    echo "To interactively identify which device handles your power button:"
    echo "  sudo ./identify-power-buttons.sh --monitor"
    echo ""
fi
