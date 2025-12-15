#!/bin/sh
set -e

# ========== CONFIG ==========
STAGE_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/20251207T170056Z/stage3-amd64-systemd-20251207T170056Z.tar.xz"
MOUNT=/mnt/gentoo
DISK="/dev/sda"
BOOT_SIZE="512M"
SWAP_SIZE="2G"
ROOT_FS="ext4"
HOSTNAME="gentoo-box"
# ============================

echo "[*] Checking network..."
ping -c1 gentoo.org >/dev/null 2>&1 || {
    echo "[-] No network. Configure eth0 or vboxnet."
    exit 1
}

echo "[*] Checking stage3 availability..."
wget --spider "$STAGE_URL" >/dev/null 2>&1 || {
    echo "[-] Stage3 file not accessible: $STAGE_URL"
    exit 1
}

echo "[*] Partitioning disk..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB "$BOOT_SIZE"
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart swap linux-swap "$BOOT_SIZE" "$SWAP_SIZE"
parted -s "$DISK" mkpart root "$ROOT_FS" "$SWAP_SIZE" 100%

echo "[*] Formatting partitions..."
mkfs.vfat -F32 "${DISK}1"
mkswap "${DISK}2"
mkfs.ext4 "${DISK}3"

echo "[*] Creating directory for distribution..."
mkdir -p "$MOUNT"

echo "[*] Mounting partitions..."
mount "${DISK}3" "$MOUNT"
mkdir -p "$MOUNT/boot"
mount "${DISK}1" "$MOUNT/boot"
swapon "${DISK}2"

echo "[*] Downloading stage3..."
wget -O /tmp/stage3.tar.xz "$STAGE_URL"

echo "[*] Extracting stage3..."
tar xpvf /tmp/stage3.tar.xz -C "$MOUNT" --xattrs-include='*.*' --numeric-owner

echo "[*] Mounting system directories..."
mount --types proc /proc "$MOUNT/proc"
mount --rbind /sys "$MOUNT/sys"
mount --make-rslave "$MOUNT/sys"
mount --rbind /dev "$MOUNT/dev"
mount --make-rslave "$MOUNT/dev"

echo "[*] Copying DNS configuration..."
cp -L /etc/resolv.conf "$MOUNT/etc/"

echo "[*] Configuring fstab..."
cat <<EOF > "$MOUNT/etc/fstab"
/dev/sda1   /boot   vfat    defaults,noatime 0 2
/dev/sda2   none    swap    sw              0 0
/dev/sda3   /       ext4    noatime         0 1
EOF

echo "[*] Entering chroot..."
cat <<'EOF' | chroot "$MOUNT" /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"

echo "[*] Syncing Portage..."
emerge --sync

echo "[*] Installing base packages..."
emerge --verbose --update --deep --newuse @world

echo "[*] Configuring timezone..."
echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data

echo "[*] Setting up locales..."
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

echo "[*] Installing kernel..."
emerge sys-kernel/gentoo-kernel-bin

echo "[*] Setting hostname..."
echo "gentoo-box" > /etc/hostname

echo "[*] Enabling network service..."
systemctl enable NetworkManager

echo "[*] Installing KDE Plasma..."
emerge kde-plasma/plasma-meta --autounmask-write
etc-update --automode -5
emerge kde-plasma/plasma-meta

systemctl enable sddm

echo "[*] Installing GRUB bootloader for EFI..."
emerge --verbose sys-boot/grub:2 sys-boot/efibootmgr

echo "[*] Installing GRUB to EFI partition..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

echo "[*] Generating GRUB config..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "[*] Done. Exit from chroot."
EOF

echo "[*] Installation complete. Ready to reboot."
