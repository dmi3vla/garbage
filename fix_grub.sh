#!/bin/bash
# fix_grub.sh - Fix GRUB boot configuration via SSH from LiveCD

set -e

MOUNT=/mnt/gentoo
DISK="/dev/sda"

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

echo "[*] Checking /boot/grub/grub.cfg..."
if [ ! -f /boot/grub/grub.cfg ]; then
    echo "[-] grub.cfg not found, creating..."
    mkdir -p /boot/grub
fi

echo "[*] Regenerating GRUB config..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "[*] Verifying GRUB installation..."
ls -la /boot/grub/grub.cfg
grep -q "menuentry" /boot/grub/grub.cfg && echo "[✓] GRUB config has menu entries" || echo "[-] No menu entries found"

echo "[*] Done. Exit from chroot."
CHROOT

echo "[*] Unmounting..."
umount -l "$MOUNT/dev" 2>/dev/null || true
umount -l "$MOUNT/sys" 2>/dev/null || true
umount -l "$MOUNT/proc" 2>/dev/null || true
umount -l "$MOUNT/boot" 2>/dev/null || true
umount -l "$MOUNT" 2>/dev/null || true

echo "[✓] GRUB fix complete. Ready to reboot."
