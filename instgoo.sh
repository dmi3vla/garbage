#!/bin/bash
# filepath: /root/gi.sh
# Скрипт установки Gentoo Linux в VirtualBox

set -e

# Переменные
DISK="/dev/sda"
MOUNT_POINT="/mnt/gentoo"
STAGE3_URL="https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/latest-stage3-amd64-systemd.tar.xz"

echo "=== Установка Gentoo Linux ==="

# 1. Разбиение диска
echo "=== Разбиение диска $DISK ==="
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary fat32 1MiB 512MiB
parted -s $DISK mkpart primary ext4 512MiB 25GiB
parted -s $DISK set 1 boot on

# Форматирование
echo "=== Форматирование разделов ==="
mkfs.fat -F 32 ${DISK}1
mkfs.ext4 -F ${DISK}2

# 2. Монтирование
echo "=== Монтирование разделов ==="
mkdir -p $MOUNT_POINT
mount ${DISK}2 $MOUNT_POINT
mkdir -p $MOUNT_POINT/boot
mount ${DISK}1 $MOUNT_POINT/boot

# 3. Скачивание и распаковка stage3
echo "=== Скачивание stage3 ==="
cd $MOUNT_POINT
wget $STAGE3_URL -O stage3.tar.xz

echo "=== Распаковка stage3 ==="
tar xpf stage3.tar.xz --xattrs-include='.*' --numeric-owner
rm stage3.tar.xz

# 4. Копирование resolv.conf
echo "=== Настройка сети ==="
cp /etc/resolv.conf $MOUNT_POINT/etc/

# 5. Монтирование необходимых систем
echo "=== Монтирование систем ==="
mount -t proc /proc $MOUNT_POINT/proc
mount --rbind /sys $MOUNT_POINT/sys
mount --rbind /dev $MOUNT_POINT/dev
mount --bind /run $MOUNT_POINT/run

# 6. Chroot и установка
echo "=== Входим в chroot ==="
chroot $MOUNT_POINT /bin/bash << 'EOF'

# Обновление репозитория
emerge-webrsync

# Выбор профиля (systemd)
eselect profile set default/linux/amd64/17.1/systemd

# Обновление системы
emerge --update --deep --newuse @world

# Установка необходимых пакетов
emerge sys-kernel/linux-firmware
emerge sys-kernel/gentoo-kernel-bin

# Установка GRUB
emerge --ask=n sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/boot

# Генерация GRUB конфигурации
grub-mkconfig -o /boot/grub/grub.cfg

# Установка hostname
echo "gentoo" > /etc/hostname

# Базовая конфигурация сети
cat > /etc/conf.d/net << 'NETCONF'
config_eth0="dhcp"
NETCONF

# Создание sudoers для root (опционально)
echo "root ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/root

echo "=== Установка завершена ==="
EOF

echo "=== Размонтирование ==="
umount -l $MOUNT_POINT/run
umount -l $MOUNT_POINT/dev
umount -l $MOUNT_POINT/sys
umount -l $MOUNT_POINT/proc
umount -l $MOUNT_POINT/boot
umount -l $MOUNT_POINT

echo "=== Установка Gentoo завершена! ==="
echo "Перезагрузите систему и удалите LiveCD"