#!/bin/sh
set -e

# ========== CONFIG ==========
STAGE_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-systemd/stage3-amd64-systemd-20251207T170056Z.tar.xz"
MOUNT=/mnt/gentoo
DISK="/dev/sda"
BOOT_SIZE="512M"
SWAP_SIZE="2G"
ROOT_FS="ext4"
HOSTNAME="gentoo-box"
# ============================

echo "[*] Проверка сети..."
ping -c1 gentoo.org >/dev/null 2>&1 || {
    echo "[-] Нет сети. Настрой eth0 или vboxnet."
    exit 1
}

echo "[*] Подготовка диска..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB "$BOOT_SIZE"
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart swap linux-swap "$BOOT_SIZE" "$SWAP_SIZE"
parted -s "$DISK" mkpart root "$ROOT_FS" "$SWAP_SIZE" 100%

mkfs.vfat -F32 "${DISK}1"
mkswap "${DISK}2"
mkfs.ext4 "${DISK}3"

mount "${DISK}3" "$MOUNT"
mkdir -p "$MOUNT/boot"
mount "${DISK}1" "$MOUNT/boot"
swapon "${DISK}2"

echo "[*] Скачиваем stage3..."
wget -O /tmp/stage3.tar.xz "$STAGE_URL"

echo "[*] Распаковка stage3..."
tar xpvf /tmp/stage3.tar.xz -C "$MOUNT" --xattrs-include='*.*' --numeric-owner

echo "[*] Монтирование системных каталогов..."
mount --types proc /proc "$MOUNT/proc"
mount --rbind /sys "$MOUNT/sys"
mount --make-rslave "$MOUNT/sys"
mount --rbind /dev "$MOUNT/dev"
mount --make-rslave "$MOUNT/dev"

echo "[*] Копирование DNS..."
cp -L /etc/resolv.conf "$MOUNT/etc/"

echo "[*] Конфиг fstab..."
cat <<EOF > "$MOUNT/etc/fstab"
/dev/sda1   /boot   vfat    defaults,noatime 0 2
/dev/sda2   none    swap    sw              0 0
/dev/sda3   /       ext4    noatime         0 1
EOF

echo "[*] Входим в chroot..."
cat <<'EOF' | chroot "$MOUNT" /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"

echo "[*] Синхронизация Portage..."
emerge --sync

echo "[*] Установка базовых пакетов..."
emerge --verbose --update --deep --newuse @world

echo "[*] Настройка часового пояса..."
echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data

echo "[*] Локали..."
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

echo "[*] Ядро..."
emerge sys-kernel/gentoo-kernel-bin

echo "[*] Hostname..."
echo "gentoo-box" > /etc/hostname

echo "[*] Сетевой сервис..."
systemctl enable NetworkManager

echo "[*] KDE Plasma minimal..."
emerge kde-plasma/plasma-meta --autounmask-write
etc-update --automode -5
emerge kde-plasma/plasma-meta

systemctl enable sddm

echo "[*] Готово. exit из chroot."
EOF

echo "[*] Установка завершена. Можешь перезагружаться."
