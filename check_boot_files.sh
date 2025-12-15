#!/bin/bash
# check_boot_files.sh - Check for kernel and initramfs in mounted system

MOUNT=${1:-.}

echo "========================================="
echo "Boot Files Check"
echo "========================================="
echo "[*] Checking: $MOUNT"
echo ""

if [ ! -d "$MOUNT/boot" ]; then
    echo "[-] $MOUNT/boot not found!"
    exit 1
fi

echo "[*] Boot directory contents:"
ls -lh "$MOUNT/boot/"
echo ""

echo "[*] Looking for kernel files..."
KERNELS=$(find "$MOUNT/boot" -name "vmlinuz*" -o -name "kernel*" 2>/dev/null)
if [ -z "$KERNELS" ]; then
    echo "[-] NO KERNEL FILES FOUND!"
    echo ""
    echo "[*] Checking for kernel sources..."
    if [ -d "$MOUNT/usr/src/linux" ]; then
        echo "[✓] Kernel sources available at $MOUNT/usr/src/linux"
        echo "[!] Kernel needs to be compiled!"
    else
        echo "[-] No kernel sources found either"
        echo "[!] Kernel needs to be installed/compiled"
    fi
else
    echo "[✓] Found kernel files:"
    echo "$KERNELS" | sed 's/^/    /'
fi

echo ""
echo "[*] Looking for initramfs files..."
INITRAMFS=$(find "$MOUNT/boot" -name "initramfs*" -o -name "initrd*" 2>/dev/null | grep -v ".map")
if [ -z "$INITRAMFS" ]; then
    echo "[-] NO INITRAMFS FILES FOUND!"
    echo "[!] Initramfs needs to be generated"
else
    echo "[✓] Found initramfs files:"
    echo "$INITRAMFS" | sed 's/^/    /'
fi

echo ""
echo "[*] GRUB configuration:"
if [ -f "$MOUNT/boot/grub/grub.cfg" ]; then
    SIZE=$(stat -c%s "$MOUNT/boot/grub/grub.cfg")
    ENTRIES=$(grep -c "menuentry" "$MOUNT/boot/grub/grub.cfg" 2>/dev/null || echo "0")
    echo "[✓] grub.cfg exists ($SIZE bytes, $ENTRIES menu entries)"
else
    echo "[-] grub.cfg not found"
fi

echo ""
echo "[*] Summary:"
if [ -n "$KERNELS" ] && [ -n "$INITRAMFS" ] && [ -f "$MOUNT/boot/grub/grub.cfg" ]; then
    echo "[✓] System appears to be bootable"
else
    echo "[-] System has missing boot files:"
    [ -z "$KERNELS" ] && echo "    - Kernel files"
    [ -z "$INITRAMFS" ] && echo "    - Initramfs"
    [ ! -f "$MOUNT/boot/grub/grub.cfg" ] && echo "    - GRUB configuration"
fi

echo ""
echo "========================================="
