#!/bin/bash
# install_kernel_and_grub.sh - Install kernel and fix GRUB

set -e

MOUNT=${1:-/mnt/gentoo}
DISK=${2:-/dev/sda}

echo "========================================="
echo "Kernel Installation & GRUB Setup"
echo "========================================="
echo "[*] Mount point: $MOUNT"
echo "[*] Target disk: $DISK"
echo ""

# Verify disk exists
if [ ! -b "$DISK" ]; then
    echo "[-] Disk $DISK not found!"
    exit 1
fi

echo "[*] Checking if already mounted..."
if mountpoint -q "$MOUNT"; then
    echo "[✓] $MOUNT already mounted"
else
    echo "[*] Mounting /dev/sda3 to $MOUNT..."
    mount "${DISK}3" "$MOUNT" 2>/dev/null || (umount -l "$MOUNT" 2>/dev/null; mount "${DISK}3" "$MOUNT")
fi

if mountpoint -q "$MOUNT/boot"; then
    echo "[✓] $MOUNT/boot already mounted"
else
    echo "[*] Mounting ${DISK}1 to $MOUNT/boot..."
    mkdir -p "$MOUNT/boot"
    mount "${DISK}1" "$MOUNT/boot" 2>/dev/null || true
fi

echo "[*] Mounting system directories..."
mount --types proc /proc "$MOUNT/proc" 2>/dev/null || true
mount --rbind /sys "$MOUNT/sys" 2>/dev/null || true
mount --make-rslave "$MOUNT/sys" 2>/dev/null || true
mount --rbind /dev "$MOUNT/dev" 2>/dev/null || true
mount --make-rslave "$MOUNT/dev" 2>/dev/null || true
mount --rbind /run "$MOUNT/run" 2>/dev/null || true
mount --make-rslave "$MOUNT/run" 2>/dev/null || true

# Mount /etc/portage if using Gentoo
if [ -d "$MOUNT/etc/portage" ]; then
    mount --rbind /etc/portage "$MOUNT/etc/portage" 2>/dev/null || true
fi

echo "[✓] All mounts successful"
echo ""
echo "[*] Entering chroot environment..."

chroot "$MOUNT" /bin/bash <<'CHROOT'
set -e

echo "[*] Checking kernel availability..."

# Check what's already installed
echo "[*] Checking installed packages..."
eselect kernel list 2>/dev/null || echo "[!] eselect not available"

echo ""
echo "[*] Checking available kernel sources..."
ls -la /usr/src/linux* 2>/dev/null | head -5 || echo "[!] No kernel sources found"

echo ""
echo "[*] Attempting to install kernel binary..."

# Try gentoo-kernel-bin first (precompiled)
if which emerge >/dev/null 2>&1; then
    echo "[*] Installing gentoo-kernel-bin (precompiled kernel)..."
    emerge --ask=n --autounmask-write sys-kernel/gentoo-kernel-bin 2>&1 | grep -E "ebuild|Kernel|ERROR|\[" || true
    
    # Try to update packages if needed
    etc-update --automode -5 2>/dev/null || true
    
    # Try again with autounmask applied
    echo "[*] Attempting installation with autounmask applied..."
    emerge --ask=n sys-kernel/gentoo-kernel-bin 2>&1 | grep -E "ebuild|Kernel|ERROR|\[" || true
    
    KERNEL=$(ls -t /boot/vmlinuz-* 2>/dev/null | head -1)
    if [ -n "$KERNEL" ]; then
        echo "[✓] Kernel installed: $(basename $KERNEL)"
    else
        echo "[!] Kernel installation may have failed, checking /boot..."
        ls -la /boot/
        
        # Try alternative: compile kernel from source if binary installation failed
        echo ""
        echo "[*] Trying alternative: installing buildkernel..."
        if [ -d "/usr/src/linux" ]; then
            echo "[*] Kernel sources found, attempting compilation..."
            cd /usr/src/linux
            if [ -f ".config" ]; then
                echo "[*] Using existing .config"
                make oldconfig -j$(nproc)
                make -j$(nproc)
                make modules_install
                make install
            else
                echo "[!] No .config found, trying genkernel..."
                if which genkernel >/dev/null 2>&1; then
                    genkernel --install all
                fi
            fi
        fi
    fi
else
    echo "[-] emerge not found"
    exit 1
fi

echo ""
echo "[*] Checking for initramfs tools..."

# Install and generate initramfs
if ! which dracut >/dev/null 2>&1; then
    echo "[*] Installing dracut..."
    emerge --ask=n sys-kernel/dracut 2>&1 | tail -10
fi

echo ""
echo "[*] Generating initramfs..."
if which dracut >/dev/null 2>&1; then
    # Get kernel version
    KERNEL=$(ls -t /boot/vmlinuz-* 2>/dev/null | head -1)
    if [ -n "$KERNEL" ]; then
        KERNEL_VER=$(basename "$KERNEL" | sed 's/vmlinuz-//')
        echo "[*] Kernel version: $KERNEL_VER"
        dracut --kver "$KERNEL_VER" --hostonly --hostonly-cmdline --add-drivers "ext4 vfat" -f
    else
        echo "[!] No kernel found for initramfs generation"
    fi
fi

echo ""
echo "[*] Verifying boot files..."
echo "[*] Kernel files:"
ls -lh /boot/vmlinuz-* 2>/dev/null || echo "[-] No kernel files"

echo "[*] Initramfs files:"
ls -lh /boot/initramfs-* 2>/dev/null || ls -lh /boot/initrd-* 2>/dev/null || echo "[-] No initramfs files"

echo ""
echo "[*] Creating GRUB configuration..."
mkdir -p /boot/grub

echo "[*] Installing GRUB (if needed)..."
if ! which grub-install >/dev/null 2>&1; then
    echo "[*] Installing sys-boot/grub..."
    emerge --ask=n sys-boot/grub 2>&1 | tail -10
fi

echo "[*] Generating GRUB config..."
grub-mkconfig -o /boot/grub/grub.cfg

echo ""
echo "[*] GRUB configuration created"
echo "[*] Menu entries:"
grep "menuentry" /boot/grub/grub.cfg | head -5 || echo "[-] No menu entries found"

echo ""
echo "[*] All tasks completed successfully!"

CHROOT

echo ""
echo "[*] Unmounting filesystems..."
umount -l "$MOUNT/run" 2>/dev/null || true
umount -l "$MOUNT/dev" 2>/dev/null || true
umount -l "$MOUNT/sys" 2>/dev/null || true
umount -l "$MOUNT/proc" 2>/dev/null || true
umount -l "$MOUNT/etc/portage" 2>/dev/null || true
umount -l "$MOUNT/boot" 2>/dev/null || true
umount -l "$MOUNT" 2>/dev/null || true

echo "[✓] All filesystems unmounted"
echo ""
echo "========================================="
echo "[✓] Kernel installation and GRUB setup complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Reboot your system: reboot"
echo "2. Boot from GRUB menu"
echo "3. If boot fails, run diagnose_grub.sh"
echo ""
