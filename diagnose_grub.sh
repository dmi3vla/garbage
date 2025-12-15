#!/bin/bash
# diagnose_grub.sh - Diagnose GRUB boot issues

echo "========================================="
echo "GRUB Boot Diagnosis"
echo "========================================="

echo ""
echo "[*] Checking GRUB files..."
if [ -f /boot/grub/grub.cfg ]; then
    echo "[✓] /boot/grub/grub.cfg exists"
    echo "    Size: $(stat -c%s /boot/grub/grub.cfg) bytes"
else
    echo "[-] /boot/grub/grub.cfg NOT FOUND"
fi

echo ""
echo "[*] Checking GRUB installation..."
if which grub-install >/dev/null 2>&1; then
    echo "[✓] grub-install found"
else
    echo "[-] grub-install NOT FOUND"
fi

echo ""
echo "[*] Checking kernel files..."
if ls /boot/vmlinuz* >/dev/null 2>&1; then
    echo "[✓] Kernel files found:"
    ls -lh /boot/vmlinuz* | awk '{print "    " $9 " (" $5 ")"}'
else
    echo "[-] No kernel files found in /boot"
fi

echo ""
echo "[*] Checking initramfs files..."
if ls /boot/initramfs* >/dev/null 2>&1; then
    echo "[✓] Initramfs files found:"
    ls -lh /boot/initramfs* | awk '{print "    " $9 " (" $5 ")"}'
else
    echo "[-] No initramfs files found in /boot"
fi

echo ""
echo "[*] Checking filesystem..."
mount | grep -E "/boot|root" | awk '{print "[✓] Mounted: " $1 " on " $3}'

echo ""
echo "[*] Disk configuration:"
if [ -n "$1" ]; then
    DISK="$1"
else
    DISK=$(grep -o '/dev/[a-z]*' /etc/fstab | head -1 | sed 's/[0-9]$//')
fi
echo "    Target disk: $DISK"

if [ -b "$DISK" ]; then
    echo "    Partitions:"
    fdisk -l "$DISK" 2>/dev/null | grep "^$DISK" | head -10 | awk '{print "      " $0}'
else
    echo "[-] Disk $DISK not found"
fi

echo ""
echo "[*] GRUB menu entries:"
if [ -f /boot/grub/grub.cfg ]; then
    COUNT=$(grep -c "menuentry" /boot/grub/grub.cfg 2>/dev/null || echo "0")
    echo "    Total entries: $COUNT"
    if [ "$COUNT" -gt 0 ]; then
        grep "menuentry" /boot/grub/grub.cfg | head -5 | sed 's/^/      /'
    else
        echo "    [-] WARNING: No menu entries found!"
    fi
fi

echo ""
echo "[*] GRUB configuration sources:"
if [ -d /etc/grub.d ]; then
    echo "    Files in /etc/grub.d:"
    ls -1 /etc/grub.d/ | grep -v "^$" | awk '{print "      " $0}'
fi

echo ""
echo "========================================="
echo "End of diagnosis"
echo "========================================="
