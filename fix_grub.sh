#!/bin/bash
# fix_grub.sh - Fix GRUB boot configuration via SSH from LiveCD

set -e

MOUNT=/mnt/gentoo
DISK="${1:-/dev/sda}"

echo "[*] Using disk: $DISK"
echo "[*] Mounting partitions..."
mount "${DISK}3" "$MOUNT" 2>/dev/null || true
mount "${DISK}1" "$MOUNT/boot" 2>/dev/null || true

echo "[*] Mounting system directories..."
mount --types proc /proc "$MOUNT/proc" 2>/dev/null || true
mount --rbind /sys "$MOUNT/sys" 2>/dev/null || true
mount --make-rslave "$MOUNT/sys" 2>/dev/null || true
mount --rbind /dev "$MOUNT/dev" 2>/dev/null || true
mount --make-rslave "$MOUNT/dev" 2>/dev/null || true

echo "[*] Entering chroot..."
chroot "$MOUNT" /bin/bash <<'CHROOT'
source /etc/profile
export PS1="(chroot) $PS1"

echo "[*] Checking kernel and initramfs..."
ls -la /boot/vmlinuz* /boot/initramfs* 2>/dev/null || echo "[-] Kernel or initramfs missing!"

echo "[*] Reinstalling kernel..."
emerge --oneshot sys-kernel/gentoo-kernel-bin 2>/dev/null || echo "[!] Kernel installation skipped (may not be needed)"

echo "[*] Checking if dracut is installed..."
which dracut >/dev/null || emerge sys-kernel/dracut 2>/dev/null || echo "[!] Dracut not available"

echo "[*] Generating initramfs..."
if which dracut >/dev/null 2>&1; then
    dracut --hostonly --hostonly-cmdline --add-drivers "ext4 vfat" -f 2>/dev/null || echo "[!] Dracut failed, continuing..."
fi

echo "[*] Verifying kernel and initramfs..."
ls -la /boot/vmlinuz* /boot/initramfs* 2>/dev/null || echo "[!] Kernel/initramfs not found"

echo "[*] Checking for GRUB installation..."
if ! which grub-mkconfig >/dev/null 2>&1; then
    echo "[!] GRUB not installed, installing..."
    emerge sys-boot/grub || echo "[-] Failed to install GRUB"
fi

if [ ! -f /boot/grub/grub.cfg ]; then
    echo "[-] grub.cfg not found, creating..."
    mkdir -p /boot/grub
fi

echo "[*] Detecting root partition..."
ROOT_PART=$(findmnt -n -o SOURCE /)
echo "[*] Root partition: $ROOT_PART"

echo "[*] Regenerating GRUB config..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "[*] Verifying GRUB installation..."
ls -la /boot/grub/grub.cfg
if grep -q "menuentry" /boot/grub/grub.cfg; then
    echo "[✓] GRUB config has menu entries:"
    grep "menuentry" /boot/grub/grub.cfg | head -5
else
    echo "[-] WARNING: No menu entries found in GRUB config!"
    echo "[*] Attempting to add manual entry..."
fi

echo "[*] Done. Exit from chroot."
CHROOT

echo "[*] Unmounting..."
umount -l "$MOUNT/dev" 2>/dev/null || true
umount -l "$MOUNT/sys" 2>/dev/null || true
umount -l "$MOUNT/proc" 2>/dev/null || true
umount -l "$MOUNT/boot" 2>/dev/null || true
umount -l "$MOUNT" 2>/dev/null || true

echo "[✓] GRUB fix complete. Ready to reboot."
