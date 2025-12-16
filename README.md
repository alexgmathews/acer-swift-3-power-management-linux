# Acer Swift 3 Power Management Configuration for Linux Mint

**System:** Acer Swift SF315-51

**OS:** Linux Mint 22.2 (Zara)

**Kernel:** 6.8.0-59-generic

**Date:** 2025-12-16

**Version:** 1.0

---

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Test](#quick-test)
- [Problem Statements](#problem-statements)
  - [Power Wake Behavior](#power-wake-behavior)
  - [FN+F6 Screen Off Mapping](#fnf6-screen-off-mapping)
- [Verification and Testing](#verification-and-testing)
  - [Verify Power Wake Configuration](#verify-power-wake-configuration)
  - [Verify FN+F6 Remapping](#verify-fnf6-remapping)
  - [Functional Testing](#functional-testing)
  - [Using Included Test Scripts](#using-included-test-scripts)
- [Troubleshooting](#troubleshooting)
  - [Power Wake Issues](#power-wake-issues)
  - [FN+F6 Remapping Issues](#fnf6-remapping-issues)
  - [Device Path Changes](#device-path-changes)
- [Uninstallation](#uninstallation)
  - [Automatic Uninstall](#automatic-uninstall)
  - [Temporarily Disable Power Wake Configuration](#temporarily-disable-power-wake-configuration)
  - [Manually Uninstall Power Wake Configuration](#manually-uninstall-power-wake-configuration)
  - [Manually Uninstall FN+F6 Remapping](#manually-uninstall-fnf6-remapping)
- [Appendices](#appendices)
  - [Package Contents](#package-contents)
  - [What the Configuration Does](#what-the-configuration-does)
  - [Hardware-Specific Details](#hardware-specific-details)
  - [Portability and Porting](#portability-and-porting)
  - [Technical Details](#technical-details)
  - [Known Limitations](#known-limitations)
- [License and Warranty](#license-and-warranty)

---

## Overview

This package provides power management configurations for the Acer Swift SF315-51 laptop running Linux Mint, addressing two distinct issues:

### 1. Power Wake Behavior
- Original Behavior: System would become unresponsive after DPMS sleep (screen off) and would not respond to events (functional hang)
- Now system resumes from DPMS sleep on keyboard events
- Touchpad and USB/PCIe devices also proactively disabled to prevent waking system unintentionally
- Implemented via systemd service (maintains persistence)

### 2. FN+F6 Screen Off Mapping
- Original Behavior: keyboard screen-off toggle only disabled LCD backlight (LCD stayed on)
- Now FN+F6 turns off display backlight and LCD
- Implemented via kernel hwdb remapping (ACPI events were problematic, also deprecated)

---

## Installation

### Automatic Install

Run [`install.sh`](install.sh)

```bash
# Navigate to package directory
cd "Acer Swift 3 Power Management"

# Run unified installer (installs both power wake and FN+F6 remapping)
sudo ./install.sh

# Reboot (required for FN+F6 remapping to take effect)
sudo reboot
```

After Reboot:

- Keyboard wakes screen from sleep
- FN+F6 turns off display (DPMS off)
- Touchpad/USB/PCIe do not wake from suspend

### Manual Install - Power Wake Behavior

```bash
# 1. Install configuration script
sudo cp acer-power-behavior.sh /usr/local/sbin/
sudo chmod 744 /usr/local/sbin/acer-power-behavior.sh

# 2. Install systemd service
sudo cp acer-power-behavior.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/acer-power-behavior.service

# 3. Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable --now acer-power-behavior.service

# 4. Verify installation
sudo systemctl status acer-power-behavior.service
```

### Manual Install - FN+F6 Screen Off Mapping

```bash
# 1. Install hwdb override
sudo cp 90-acer-remap-fn-f6.conf /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf

# 2. Update hwdb database
sudo systemd-hwdb update

# 3. Trigger udev reload
sudo udevadm trigger --subsystem-match=input --action=change

# 4. Reboot (required for internal keyboards)
sudo reboot
```

---

## Quick Test

### Test Power Wake Behavior

```bash
# Test screen wake
xset dpms force off          # Press keyboard key - screen should wake

# Test suspend wake
sudo systemctl suspend       # Touch touchpad - should NOT wake
                             # Press keyboard key - should wake
```

### Test FN+F6 Screen Off

```bash
# Press FN+F6
# Expected: Display turns off (DPMS off)

# Press any key
# Expected: Display wakes
```

---

## Problem Statements

### Power Wake Behavior

#### Issues

- Screen would turn off after timeout (normal behavior)
- Keyboard did not wake screen from DPMS sleep
- System would not respond to events (functional hang)

#### Root Causes

- Keyboard wake disabled by default in `/sys/devices/platform/i8042/serio0/power/wakeup`

#### Proactive Changes

After identifying the keyboard wake issue, additional sources were identified that might cause unintended wakeups:

- Touchpad wake was enabled for wake
- USB controller (XHC) was enabled for wake
- PCIe root ports (RP05, RP09) were enabled for wake

#### Resolution

Solution: systemd service that configures wake sources on boot

Implementation:

- systemd service `/etc/systemd/system/`[`acer-power-behavior.service`](acer-power-behavior.service) runs at boot
- Script `/usr/local/sbin/`[`acer-power-behavior.sh`](acer-power-behavior.sh) configures system wakes

Wake Sources Enabled:

- ✓ Keyboard (i8042/serio0) - Primary wake source

Wake Sources Disabled:

- ✗ Touchpad (SYNA7DB5) - Prevents accidental wakes
- ✗ USB controller (XHC) - Prevents USB device wakes
- ✗ PCIe ports (RP05, RP09) - Prevents PCIe device wakes

Verified Behaviors:

- [x] Keyboard wakes screen from DPMS sleep
- [x] Lid close suspends system
- [x] Keyboard wakes system from suspend
- [x] Touchpad does not wake system from suspend
- [x] USB devices do not wake system
- [x] PCIe devices do not wake system

---

### FN+F6 Screen Off Mapping

#### Issues

- Original Behavior: FN+F6 only disabled LCD backlight. LCD panel remained on (displaying image with no backlight). Only FN+F6 re-enabled LCD backlight
- User Wanted: Complete display off (DPMS off) like tested behavior on FN+F6, with display on after any following keypress

#### Root Causes

- Kernel hwdb Mapping: `KEYBOARD_KEY_f6=KEY_POWER` (FN+F6) generated ACPI `video/switchmode VMOD 00000080` event
- Firmware-Level Backlight Control: Default behavior controlled at EC/BIOS level

#### Resolution

Solution: Kernel hwdb remapping to bypass ACPI events entirely

Implementation:

- Remap FN+F6 keycode from `KEY_POWER` → `KEY_SCREENLOCK` at kernel hwdb level
- File: `/etc/udev/hwdb.d/` [`90-acer-remap-fn-f6.conf`](90-acer-remap-fn-f6.conf)
- Generates `XF86ScreenSaver` key event instead of ACPI event
- Cinnamon desktop environment automatically binds to screen-off

Why This Works:

- No ACPI interception required (avoids deadlock)
- Same mechanism used successfully for FN+F4 suspend key
- Standard keyboard event path (safe for desktop environment handling)
- Desktop environment handles key event without blocking

Original Hardware Mapping:
```
KEYBOARD_KEY_f6=KEY_POWER  →  ACPI video/switchmode event  →  Backlight toggle
```

New Hardware Mapping:
```
KEYBOARD_KEY_f6=KEY_SCREENLOCK  →  XF86ScreenSaver event  →  DPMS off
```

Verified Behavior:

- [x] FN+F6 turns off display (DPMS off)
- [x] Both backlight and LCD turn off
- [x] Any keypress wakes display
- [x] No system freezes or deadlocks
- [x] Works without additional dconf configuration

---

## Verification and Testing

### Verify Power Wake Configuration

#### Check Keyboard Wake Status

```bash
cat /sys/devices/platform/i8042/serio0/power/wakeup
```

Expected: `enabled`

#### Check Touchpad Wake Status

```bash
cat /sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-SYNA7DB5:00/power/wakeup
```

Expected: `disabled`

#### Check ACPI Wake Sources

```bash
grep -E '^(XHC|RP05|RP09)' /proc/acpi/wakeup
```

Expected Output:
```
XHC   S3  *disabled  pci:0000:00:14.0
RP05  S4  *disabled  pci:0000:00:1c.4
RP09  S4  *disabled  pci:0000:00:1d.0
```

### Verify FN+F6 Remapping

#### Check hwdb Remapping Applied

```bash
# Check if hwdb file exists
ls -l /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf

# Verify hwdb database updated
systemd-hwdb query evdev:atkbd:dmi:*:svnAcer:pnSwift*SF314-54*:* | grep KEYBOARD_KEY_f6
```

Expected: `KEYBOARD_KEY_f6=screenlock`

### Functional Testing

#### Test 1: Screen Wake

```bash
# Force screen off
xset dpms force off

# Press any keyboard key
# Expected: Screen wakes immediately
```

#### Test 2: FN+F6 Screen Off

```bash
# Press FN+F6
# Expected: Display turns off (both backlight and LCD)

# Press any keyboard key
# Expected: Display wakes

# Press FN+F6 again while screen is off
# Expected: Display wakes
```

#### Test 3: Suspend Wake

```bash
# Suspend system
sudo systemctl suspend

# While suspended, test these in order:
# 1. Touch touchpad - should NOT wake
# 2. Move mouse - should NOT wake
# 3. Press keyboard key - SHOULD wake

# Expected: Only keyboard wakes the system
```

### Using Included Test Scripts

This package includes comprehensive testing tools:

```bash
# Run system audit (generates timestamped report)
./audit-system-power-behavior.sh

# Identify power button mappings interactively
./identify-power-buttons.sh --monitor
```

---

## Troubleshooting

### Power Wake Issues

#### Service Fails to Start

Check service status and logs:
```bash
sudo systemctl status acer-power-behavior.service
sudo journalctl -u acer-power-behavior.service -n 50
```

Common causes:

- Device paths changed (different kernel version)
- Missing permissions (script must run as root)
- Devices not present at boot time

Run script manually to see detailed error:
```bash
sudo /usr/local/sbin/acer-power-behavior.sh
```

#### Keyboard Wake Not Working

Verify keyboard wake is enabled:
```bash
cat /sys/devices/platform/i8042/serio0/power/wakeup
```

If shows `disabled`:

1. Check if service is running: `sudo systemctl status acer-power-behavior.service`
2. Restart service: `sudo systemctl restart acer-power-behavior.service`
3. Run script manually: `sudo /usr/local/sbin/acer-power-behavior.sh`

#### Touchpad Still Wakes System

Verify touchpad wake disabled:
```bash
grep "^SYNA" /sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-SYNA7DB5:00/power/wakeup
```

If shows `enabled`: restart service or run script manually.

---

### FN+F6 Remapping Issues

#### FN+F6 Still Toggles Backlight Only

Verify hwdb remapping installed:
```bash
ls -l /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf
```

If file missing: Reinstall, see [Manual Install - FN+F6 Screen Off Mapping](#manual-install---fnf6-screen-off-mapping)

Verify hwdb Database Updated:
```bash
systemd-hwdb query evdev:atkbd | grep f6
```

Should show `KEYBOARD_KEY_f6=screenlock` (not `KEY_POWER`).

#### FN+F6 Does Nothing

After installing hwdb remapping and rebooting:

1. Check if key event is generated:
   ```bash
   xev | grep -i screen
   # Press FN+F6 in the xev window
   ```

2. Manually trigger DPMS off:
   ```bash
   xset dpms force off
   ```
    If this works, the issue is with key binding, not DPMS.

3. Check Cinnamon desktop environment key bindings:
   ```bash
   gsettings get org.cinnamon.desktop.keybindings.media-keys screensaver
   ```

---

### Device Path Changes

If device paths change after kernel update:

1. Run diagnostic script:
   ```bash
   ./audit-system-power-behavior.sh
   ```

2. Compare device paths in `new-audit.txt` vs original

3. Update script variables in `/usr/local/sbin/`[`acer-power-behavior.sh`](acer-power-behavior.sh)

4. Restart service:
   ```bash
   sudo systemctl restart acer-power-behavior.service
   ```

---

## Uninstallation

### Automatic Uninstall

Run [`uninstall.sh`](uninstall.sh) (*handles partial installations)*

```bash
# Navigate to package directory
cd "Acer Swift 3 Power Management"

# Run unified uninstaller (removes both power wake and FN+F6 remapping)
sudo ./uninstall.sh

# Reboot (required for all changes to take effect)
sudo reboot
```

After reboot:

- Power wake settings revert to system defaults
- FN+F6 reverts to original behavior (backlight toggle)

### Temporarily Disable Power Wake Configuration

To temporarily disable power wake configuration without uninstalling:
```bash
sudo systemctl stop acer-power-behavior.service
sudo reboot
```

Re-enable with:
```bash
sudo systemctl start acer-power-behavior.service
```

### Manually Uninstall Power Wake Configuration

```bash
# Stop and disable service
sudo systemctl stop acer-power-behavior.service
sudo systemctl disable acer-power-behavior.service

# Remove files
sudo rm /etc/systemd/system/acer-power-behavior.service
sudo rm /usr/local/sbin/acer-power-behavior.sh
sudo systemctl daemon-reload

# Reboot to revert to defaults
sudo reboot
```

### Manually Uninstall FN+F6 Remapping

```bash
# Remove hwdb override
sudo rm /etc/udev/hwdb.d/90-acer-remap-fn-f6.conf

# Update hwdb database
sudo systemd-hwdb update

# Trigger udev reload
sudo udevadm trigger --subsystem-match=input --action=change

# Reboot for changes to take effect
sudo reboot
```

After reboot, FN+F6 will return to default backlight toggle behavior.

---

## Appendices

### Package Contents

#### Installation Files

Install & Uninstall Scripts:

- [install.sh](install.sh) - Unified installer for both power wake and FN+F6 remapping
- [uninstall.sh](uninstall.sh) - Unified uninstaller (handles partial installations)

Power Wake Configuration:

- [acer-power-behavior.service](acer-power-behavior.service) - systemd service unit
- [acer-power-behavior.sh](acer-power-behavior.sh) - Configuration script

FN+F6 Remapping:

- [90-acer-remap-fn-f6.conf](90-acer-remap-fn-f6.conf) - hwdb override for kernel

#### Diagnostic Tools

- [identify-power-buttons.sh](identify-power-buttons.sh) - Power button identification tool (use `--monitor` flag for interactive mode)
- [audit-system-power-behavior.sh](audit-system-power-behavior.sh) - System power configuration audit tool

Diagnostic scripts automatically generate:

- `audit-system-power-behavior-YYYYMMDD-HHMMSS.txt`
- `identify-power-buttons-YYYYMMDD-HHMMSS.txt`

#### Documentation

- [README.md](#) (this file) - Complete package documentation
- [LICENSE.md](LICENSE.md) - MIT License

---

### What the Configuration Does

#### Power Wake Script Operations

The [`acer-power-behavior.sh`](acer-power-behavior.sh) script performs these operations on each boot:

1. Enables Keyboard Wake:
   ```bash
   echo "enabled" > /sys/devices/platform/i8042/serio0/power/wakeup
   echo "on" > /sys/devices/platform/i8042/serio0/power/control
   ```
   - Sets keyboard device to generate wake events
   - Prevents keyboard from runtime suspend
   - Allows wake from both screen sleep and system suspend

2. Disables Touchpad Wake:
   ```bash
   echo "disabled" > /sys/devices/pci0000:00/0000:00:15.1/.../i2c-SYNA7DB5:00/power/wakeup
   echo "auto" > /sys/devices/pci0000:00/0000:00:15.1/.../i2c-SYNA7DB5:00/power/control
   ```
   - Prevents touchpad from generating wake events
   - Does not disable touchpad during normal use
   - Only affects wake behavior from suspend

3. Disables USB Controller Wake:
   ```bash
   echo "XHC" > /proc/acpi/wakeup
   ```
   - Toggles USB controller (XHC) wake state to disabled
   - Prevents USB devices from waking system

4. Disables PCIe Root Port Wake:
   ```bash
   echo "RP05" > /proc/acpi/wakeup
   echo "RP09" > /proc/acpi/wakeup
   ```
   - Disables wake for PCIe root ports
   - Prevents network cards, storage devices from waking system

#### FN+F6 Remapping Details

hwdb Override File: `/etc/udev/hwdb.d/`[`90-acer-remap-fn-f6.conf`](90-acer-remap-fn-f6.conf)

```
evdev:atkbd:dmi:*:svnAcer:pnSwift*SF314-54*:*
 KEYBOARD_KEY_f6=screenlock
```

What This Does:

- Matches Acer Swift keyboard via DMI strings
- Remaps scancode `f6` to `screenlock` keycode
- Generates `XF86ScreenSaver` X11 key event
- Cinnamon desktop environment binds this to DPMS off by default

#### Modern Event Monitoring

The acpid daemon and its `/proc/acpi/event` interface have been deprecated since Linux kernel 2.6.24. systemd-logind replaces the functionality, which handles power button, lid switch, and suspend/hibernate events natively via `/etc/systemd/logind.conf`. The included diagnostic scripts use `journalctl -f -u systemd-logind` for real-time event monitoring instead of the deprecated `acpi_listen` tool.

This package directly configures kernel interfaces (`/proc/acpi/wakeup`, sysfs, `/dev/input/event*`). Hardware remapping bypasses ACPI events, using the standard keyboard event path. During testing, attempts to use deprecated `acpi_listen` to intercept ACPI events and call X11 commands (like `xset`) resulted in system deadlocks. Even async/detached execution failed due to restricted kernel context restrictions.

#### Files Modified

Runtime Configuration (reset on reboot without service):

- `/sys/devices/platform/i8042/serio0/power/wakeup`
- `/sys/devices/platform/i8042/serio0/power/control`
- `/sys/devices/pci0000:00/0000:00:15.1/.../i2c-SYNA7DB5:00/power/wakeup`
- `/sys/devices/pci0000:00/0000:00:15.1/.../i2c-SYNA7DB5:00/power/control`
- `/proc/acpi/wakeup` (XHC, RP05, RP09 entries)

Persistent Files Added:

- `/etc/systemd/system/`[`acer-power-behavior.service`](acer-power-behavior.service)
- `/usr/local/sbin/`[`acer-power-behavior.sh`](acer-power-behavior.sh)
- `/etc/udev/hwdb.d/`[`90-acer-remap-fn-f6.conf`](90-acer-remap-fn-f6.conf)

No Modifications To:

- Kernel parameters or modules
- GRUB/bootloader configuration
- BIOS/UEFI firmware settings
- Desktop environment configurations (automatic binding)
- User-specific settings or files

---

### Hardware-Specific Details

#### Acer Swift SF315-51 Components

Keyboard Controller:

- Type: i8042 (PS/2 interface)
- Device: AT Translated Set 2 keyboard
- Path: `/sys/devices/platform/i8042/serio0`

Touchpad:

- Model: Synaptics SYNA7DB5:00 (06CB:7DB7)
- Interface: I2C HID
- Path: `/sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-SYNA7DB5:00`

USB Controller:

- Model: Intel xHCI Host Controller
- ACPI Name: XHC
- PCIe Address: 0000:00:14.0

PCIe Root Ports:

- RP05: PCIe port at 0000:00:1c.4
- RP09: PCIe port at 0000:00:1d.0

Power Button:

- Type: Firmware-controlled (Embedded Controller)
- ACPI Device: PNP0C0C:00
- Cannot be remapped (firmware-level control only)

#### Special Keyboard Mappings

From udev Keyboard Scancodes:
```
Scancode f3: prog2        (FN+F3)
Scancode f4: prog1        (FN+F4 - Suspend/Hibernate)
Scancode f5: presentation (FN+F5)
Scancode f6: screenlock   (FN+F6 - Screen lock) [remapped from KEY_POWER]
Scancode f8: fn           (FN lock)
```

Note: FN+F4 provides OS-level suspend control as alternative to physical power button.

---

### Portability and Porting

#### Compatibility

Tested On:

- Acer Swift SF315-51
  - i8042 serial keyboard controller
- Linux Mint 22
  - Cinnamon desktop environment
  - systemd-based distribution
  - sysfs/procfs kernel interfaces (`/sys`, `/proc/acpi`)
  - Linux kernel 5.0+

#### Porting to Different Hardware

The following instructions apply to different hardware running Linux Mint with Cinnamon desktop environment. For other desktop environments, see [Known Limitations #6 - Desktop Environment Specific](#6-desktop-environment-specific).

Step 1: Run Diagnostic Script
```bash
./audit-system-power-behavior.sh
```

Step 2: Identify Device Paths

Look for:

- Keyboard: Search for i8042 device or USB keyboard
- Touchpad: Search for I2C HID or USB touchpad device
- ACPI Devices: Check `/proc/acpi/wakeup`

Step 3: Update Script

Edit [`acer-power-behavior.sh`](acer-power-behavior.sh) and modify device paths:
```bash
KEYBOARD_DEVICE="/sys/devices/.../new-keyboard-path/power/wakeup"
TOUCHPAD_DEVICE="/sys/devices/.../new-touchpad-path/power/wakeup"
```

Step 4: Test Before Making Persistent
```bash
sudo ./acer-power-behavior.sh
sudo systemctl suspend  # Test wake behavior
```

Step 5: Update FN+F6 Remapping DMI Match

Edit [`90-acer-remap-fn-f6.conf`](90-acer-remap-fn-f6.conf):
```
evdev:atkbd:dmi:*:svnYourVendor:pnYourModel*:*
 KEYBOARD_KEY_f6=screenlock
```

Find DMI strings:
```bash
cat /sys/class/dmi/id/sys_vendor
cat /sys/class/dmi/id/product_name
```

---

### Technical Details

#### Linux Power Management Architecture

sysfs/procfs Interface:

- `/sys/devices/.../power/wakeup` - Device wake capability (enabled/disabled)
- `/sys/devices/.../power/control` - Runtime PM (on/auto/off)
- `/proc/acpi/wakeup` - ACPI wake source configuration

Wake Event Path:

1. Hardware device generates interrupt
2. Kernel checks device wakeup capability
3. If enabled, wake event propagates to PM core
4. System exits suspend/screen wake state

This configuration controls step 2 - which devices can generate wake events.

#### Device Paths Explained

i8042 Keyboard:
```
/sys/devices/platform/i8042/serio0
           └─ Platform device (motherboard-attached)
                   └─ Serial I/O port 0 (PS/2)
```

I2C Touchpad:
```
/sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-SYNA7DB5:00
           └─ PCI bus 0, device 15, function 1
                   └─ I2C controller 1
                       └─ I2C device SYNA7DB5
```

#### FN+F6 Remapping Technical Details

Original Keycode Flow:
```
FN+F6 pressed
  → Scancode 0xf6 sent by firmware
  → Kernel hwdb: KEYBOARD_KEY_f6=KEY_POWER
  → Generates KEY_POWER event
  → ACPI catches as video/switchmode VMOD 00000080
  → Firmware/driver toggles backlight
```

Remapped Keycode Flow:
```
FN+F6 pressed
  → Scancode 0xf6 sent by firmware
  → Kernel hwdb: KEYBOARD_KEY_f6=KEY_SCREENLOCK
  → Generates KEY_SCREENLOCK event
  → X11: XF86ScreenSaver keysym
  → Cinnamon: Bound to "xset dpms force off"
  → Display turns off (DPMS)
```

How This Avoids Deadlock:

- No ACPI event generated
- Standard input event path through kernel → X11 → DE
- Desktop environment handles in user context (not kernel/ACPI context)
- No blocking calls to X server from restricted contexts

---

### Known Limitations

#### 1. Physical Power Button Cannot Be Remapped

- Limitation: Physical power button is controlled at firmware level (EC/BIOS) and bypasses the operating system entirely
- Workaround: Use FN+F4 and lid close for OS-controlled suspend instead of physical power button

#### 2. Configuration Not Persistent Without Service

- Limitation: sysfs and procfs settings reset to defaults on every reboot
- Impact: Use systemd service or equivalent for persistence

#### 3. Device Paths Are Hardware-Specific

- Limitation: Device paths in script are specific to Acer Swift SF315-51 Laptop Hardware
- Impact: Porting to different hardware requires updating paths
- Mitigation: Script includes fallback detection logic. Diagnostic tools help identify paths on new systems

#### 4. FN+F6 Remapping Requires Reboot

- Limitation: hwdb changes require reboot (or keyboard replug) to take effect
- Why: Kernel reads hwdb at device initialization time only

#### 5. Requires i8042 or Compatible Keyboard Controller

- Limitation: Script assumes PS/2-style keyboard controller (i8042)
- Impact: USB keyboards require different device paths
- Portability: Most laptops use i8042 even for internal keyboards

#### 6. Desktop Environment Specific

- This configuration package is designed for Linux Mint with Cinnamon desktop environment
- Diagnostic scripts use Cinnamon-specific `gsettings` queries and desktop environment configuration
- Scripts will not function correctly on other desktop environments (GNOME, KDE, XFCE, etc.) without significant modification
- Power wake configuration can be adapted to other systemd-based distributions, but porting requires updating both hardware-specific device paths and desktop environment configuration

---

## License and Warranty

This project is licensed under the [MIT License](LICENSE.md).

**Summary:** You are free to use, modify, and distribute this software for any purpose, including commercial use, with proper attribution.

**Warranty Disclaimer:** This configuration is provided as-is without any warranty. Test thoroughly before deployment. While these settings are non-destructive and revert on reboot without the service, always verify behavior on your specific hardware. Use at your own risk.
