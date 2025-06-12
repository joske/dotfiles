#!/bin/bash

set -euo pipefail

### CONFIGURATION ###
KERNEL_IMG="/boot/vmlinuz-linux-zen"
INITRD_IMG="/boot/initramfs-linux-zen.img"
CMDLINE=$(cat /proc/cmdline)
DISPLAY_MANAGER="gdm"
LOGFILE="/var/log/kexec.log"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script only works on Linux systems."
  exit 1
fi

if fgconsole >/dev/null 2>&1; then
  echo "Running on a virtual terminal (VT$(fgconsole))"
else
  echo "Not running on a virtual terminal!"
  exit 1
fi

[[ -f "$KERNEL_IMG" ]] || {
  echo "Kernel image not found!"
  exit 1
}
[[ -f "$INITRD_IMG" ]] || {
  echo "Initrd image not found!"
  exit 1
}

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

echo "=== [safe-kexec] ===" | tee "$LOGFILE"
date | tee -a "$LOGFILE"

echo "Stopping display manager: $DISPLAY_MANAGER" | tee -a "$LOGFILE"
systemctl stop "$DISPLAY_MANAGER" 2>&1 | tee -a "$LOGFILE"

echo "Syncing disks..." | tee -a "$LOGFILE"
sync

echo "Loading kernel via kexec..." | tee -a "$LOGFILE"
kexec -l "$KERNEL_IMG" --initrd="$INITRD_IMG" --command-line="$CMDLINE" 2>&1 | tee -a "$LOGFILE"

echo "Kernel loaded. Executing kexec now." | tee -a "$LOGFILE"
sleep 2

kexec -e 2>&1 | tee -a "$LOGFILE"
