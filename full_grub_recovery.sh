#!/bin/bash
# full_grub_recovery.sh - Complete GRUB recovery from LiveCD

set -e

MOUNT=${1:-/mnt/gentoo}
DISK=${2:-/dev/sda}

echo "========================================="
echo "GRUB Recovery Tool"
echo "========================================="
echo "[*] Mount point: $MOUNT"
echo "[*] Target disk: $DISK"
echo ""

# Verify disk exists
if [ ! -b "$DISK" ]; then
    echo "[-] Disk $DISK not found!"
    exit 1
fi

echo "[*] Attempting to mount partitions from $DISK..."

# Try to find and mount partitions
for part in "${DISK}1" "${DISK}2" "${DISK}3"; do
    if [ -b "$part" ]; then
        echo "[*] Found partition: $part"
    fi
done

echo "[*] Mounting ${DISK}3 to $MOUNT..."
mount "${DISK}3" "$MOUNT" 2>/dev/null || (umount -l "$MOUNT" 2>/dev/null; mount "${DISK}3" "$MOUNT")

echo "[*] Mounting ${DISK}1 to $MOUNT/boot..."
mkdir -p "$MOUNT/boot"
mount "${DISK}1" "$MOUNT/boot" 2>/dev/null || true

echo "[*] Mounting system directories..."
mount --types proc /proc "$MOUNT/proc" 2>/dev/null || true
mount --rbind /sys "$MOUNT/sys" 2>/dev/null || true
mount --make-rslave "$MOUNT/sys" 2>/dev/null || true
mount --rbind /dev "$MOUNT/dev" 2>/dev/null || true
mount --make-rslave "$MOUNT/dev" 2>/dev/null || true
mount --rbind /run "$MOUNT/run" 2>/dev/null || true
mount --make-rslave "$MOUNT/run" 2>/dev/null || true

echo "[✓] All mounts successful"
echo ""
echo "[*] Entering chroot environment..."

chroot "$MOUNT" /bin/bash <<'CHROOT'
set -e

echo "[*] Checking environment..."
pwd
whoami

echo "[*] Verifying boot files..."
if [ ! -f /boot/grub/grub.cfg ]; then
    echo "[!] grub.cfg missing, will regenerate"
fi

echo "[*] Finding kernel and initramfs..."
KERNEL=$(ls -t /boot/vmlinuz-* 2>/dev/null | head -1)
INITRAMFS=$(ls -t /boot/initramfs-* 2>/dev/null | head -1)

if [ -z "$KERNEL" ]; then
    echo "[-] ERROR: No kernel found!"
    echo "    Available files in /boot:"
    ls -la /boot/
    exit 1
else
    echo "[✓] Kernel: $(basename $KERNEL)"
fi

if [ -z "$INITRAMFS" ]; then
    echo "[!] WARNING: No initramfs found"
else
    echo "[✓] Initramfs: $(basename $INITRAMFS)"
fi

echo ""
echo "[*] Checking GRUB installation..."
if ! which grub-install >/dev/null 2>&1; then
    echo "[-] grub-install not found, attempting to install grub..."
    if which emerge >/dev/null 2>&1; then
        emerge --oneshot sys-boot/grub || echo "[!] Could not install GRUB via emerge"
    fi
fi

echo ""
echo "[*] Creating GRUB config..."
mkdir -p /boot/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo "[*] Verifying GRUB config..."
if [ -f /boot/grub/grub.cfg ]; then
    ENTRIES=$(grep -c "menuentry" /boot/grub/grub.cfg 2>/dev/null || echo 0)
    echo "[✓] GRUB config created with $ENTRIES menu entries"
    
    if [ "$ENTRIES" -eq 0 ]; then
        echo ""
        echo "[-] WARNING: No menu entries found!"
        echo "[*] Manual entry may be needed. Checking /boot/grub/grub.cfg:"
        head -20 /boot/grub/grub.cfg
    fi
else
    echo "[-] ERROR: grub.cfg was not created"
    exit 1
fi

echo ""
echo "[*] Checking for GRUB installation on disk..."
if [ -d /boot/grub ]; then
    echo "[✓] GRUB directory exists"
    if [ -f /boot/grub/i386-pc/core.img ] || [ -f /boot/grub/x86_64-efi/grubx64.efi ]; then
        echo "[✓] GRUB modules found"
    else
        echo "[!] GRUB modules may need reinstallation"
    fi
fi

echo ""
echo "[*] Attempting GRUB boot sector installation..."
# Try both BIOS and EFI installations
BOOT_DISK=$(mount | grep "on /boot" | awk '{print $1}' | sed 's/[0-9]$//')

if [ -n "$BOOT_DISK" ]; then
    echo "[*] Boot disk detected: $BOOT_DISK"
    
    # Check if EFI
    if [ -d /sys/firmware/efi ]; then
        echo "[*] EFI system detected, installing GRUB to EFI..."
        if [ -d /boot/efi ] || [ -d /sys/firmware/efi/efivars ]; then
            grub-install --target=x86_64-efi --efi-directory=/boot || grub-install --target=x86_64-efi --efi-directory=/boot/efi || echo "[!] EFI installation failed"
        fi
    else
        echo "[*] BIOS system detected, installing GRUB to MBR..."
        grub-install "$BOOT_DISK" || echo "[!] BIOS installation failed"
    fi
else
    echo "[!] Could not determine boot disk"
fi

echo ""
echo "[✓] GRUB configuration complete"
echo ""

CHROOT

echo ""
echo "[*] Unmounting filesystems..."
umount -l "$MOUNT/run" 2>/dev/null || true
umount -l "$MOUNT/dev" 2>/dev/null || true
umount -l "$MOUNT/sys" 2>/dev/null || true
umount -l "$MOUNT/proc" 2>/dev/null || true
umount -l "$MOUNT/boot" 2>/dev/null || true
umount -l "$MOUNT" 2>/dev/null || true

echo "[✓] All filesystems unmounted"
echo ""
echo "========================================="
echo "[✓] GRUB recovery complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Reboot your system: reboot"
echo "2. Boot from the GRUB menu"
echo "3. If issues persist, run diagnose_grub.sh again"
echo ""
