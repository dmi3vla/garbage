#!/bin/bash
# quick_kernel_install.sh - Quick kernel installation with proper configuration

MOUNT=${1:-/mnt/gentoo}
DISK=${2:-/dev/sda}

echo "========================================="
echo "Quick Kernel Installation"
echo "========================================="

if [ ! -d "$MOUNT/boot" ]; then
    echo "[*] Mounting $MOUNT..."
    sudo mount "${DISK}3" "$MOUNT" 2>/dev/null || sudo mount -L rootfs "$MOUNT"
    sudo mkdir -p "$MOUNT/boot"
    sudo mount "${DISK}1" "$MOUNT/boot" 2>/dev/null || sudo mount -L boot "$MOUNT/boot"
fi

echo "[*] Mounting system directories..."
sudo mount --types proc /proc "$MOUNT/proc" 2>/dev/null || true
sudo mount --rbind /sys "$MOUNT/sys" 2>/dev/null || true
sudo mount --make-rslave "$MOUNT/sys" 2>/dev/null || true
sudo mount --rbind /dev "$MOUNT/dev" 2>/dev/null || true
sudo mount --make-rslave "$MOUNT/dev" 2>/dev/null || true
sudo mount --rbind /run "$MOUNT/run" 2>/dev/null || true
sudo mount --make-rslave "$MOUNT/run" 2>/dev/null || true

echo "[✓] System mounted"
echo ""
echo "[*] Entering chroot..."

sudo chroot "$MOUNT" /bin/bash <<'CHROOT'
set -e

echo "[*] Setting up kernel build environment..."

# Update package database
echo "[*] Updating Portage..."
emerge --sync --quiet 2>/dev/null || true

# Set USE flags for installkernel
echo "[*] Configuring USE flags..."
mkdir -p /etc/portage
cat >> /etc/portage/package.use/kernel << 'EOF'
sys-kernel/installkernel dracut
EOF

echo "[*] Installing kernel package..."
# Install with automatic unmasking
emerge -q --ask=n --autounmask --autounmask-continue sys-kernel/gentoo-kernel-bin 2>&1 | tail -30

echo ""
echo "[*] Checking installation result..."
KERNEL=$(ls -t /boot/vmlinuz-* 2>/dev/null | head -1)

if [ -n "$KERNEL" ]; then
    echo "[✓] Kernel installed successfully: $(basename $KERNEL)"
    
    # Get kernel version
    KERNEL_VER=$(basename "$KERNEL" | sed 's/vmlinuz-//')
    echo "[*] Kernel version: $KERNEL_VER"
    
    # Check for initramfs
    if [ -f "/boot/initramfs-${KERNEL_VER}.img" ]; then
        echo "[✓] Initramfs found: initramfs-${KERNEL_VER}.img"
    else
        echo "[!] Initramfs not found, generating..."
        
        # Install dracut if needed
        which dracut >/dev/null || emerge -q sys-kernel/dracut
        
        # Generate initramfs
        dracut --kver "$KERNEL_VER" --hostonly --hostonly-cmdline -f
        
        if [ -f "/boot/initramfs-${KERNEL_VER}.img" ]; then
            echo "[✓] Initramfs generated"
        fi
    fi
else
    echo "[-] Kernel installation failed"
    echo "[*] /boot contents:"
    ls -la /boot/
    exit 1
fi

echo ""
echo "[*] Regenerating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo "[*] Verifying GRUB config..."
ENTRIES=$(grep -c "menuentry.*Linux" /boot/grub/grub.cfg 2>/dev/null || echo "0")
echo "[✓] GRUB configuration has $ENTRIES Linux boot entries"

if [ "$ENTRIES" -eq 0 ]; then
    echo "[!] WARNING: No Linux boot entries found"
    echo "[*] Available menu entries:"
    grep "menuentry" /boot/grub/grub.cfg | head -5
fi

echo ""
echo "[✓] Kernel installation complete!"

CHROOT

echo ""
echo "[*] Unmounting..."
sudo umount -l "$MOUNT/run" 2>/dev/null || true
sudo umount -l "$MOUNT/dev" 2>/dev/null || true
sudo umount -l "$MOUNT/sys" 2>/dev/null || true
sudo umount -l "$MOUNT/proc" 2>/dev/null || true
sudo umount -l "$MOUNT/boot" 2>/dev/null || true
sudo umount -l "$MOUNT" 2>/dev/null || true

echo "[✓] Done. System ready to boot."
echo ""
echo "To reboot: sudo reboot"
echo ""
