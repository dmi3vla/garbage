#!/bin/bash

# Исправленный сценарий установки Gentoo (Systemd + EFI)
# Главное изменение: В Шаге 8 добавлена предварительная настройка флагов.
# Это решает проблему, когда emerge останавливался, просил подтвердить изменения,
# но не создавал файлы ядра (vmlinuz, initramfs).

set -e  # Прерывать выполнение при любой ошибке

echo "=== Начало установки Gentoo ==="

# 2. Разметка диска (GPT)
echo "=== Разметка диска ==="
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart swap linux-swap 512MiB 4.5GiB  # Swap лучше побольше для компиляции
parted /dev/sda -- mkpart root ext4 4.5GiB 100%

mkfs.vfat -F32 /dev/sda1
mkswap /dev/sda2 && swapon /dev/sda2
mkfs.ext4 /dev/sda3

# 3. Монтирование (Строго по порядку!)
echo "=== Монтирование разделов ==="
# 1. Сначала корень
mount /dev/sda3 /mnt/gentoo

# 2. Создаем папку для boot
mkdir -p /mnt/gentoo/boot

# 3. Монтируем boot раздел (ОБЯЗАТЕЛЬНО СЕЙЧАС)
mount /dev/sda1 /mnt/gentoo/boot

# 4. Проверка (должны быть видны sda3 и sda1)
lsblk

# 4. Скачивание Stage3 (Systemd)
echo "=== Скачивание и распаковка Stage3 ==="
cd /mnt/gentoo
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20251207T170056Z/stage3-amd64-systemd-20251207T170056Z.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

# 5. Вход в Chroot
echo "=== Настройка chroot окружения ==="
# Копируем DNS и монтируем системные разделы
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

# Входим в chroot
chroot /mnt/gentoo /bin/bash << 'EOF'
source /etc/profile
export PS1="(chroot) $PS1"

# 6. Обновление Portage и выбор профиля
echo "=== Обновление Portage и выбор профиля ==="
emerge-webrsync

# Смотрим список профилей
eselect profile list

# Выбираем стабильный systemd (цифры могут меняться, ищите 'default/linux/amd64/23.0/systemd')
# Например, если это номер 16:
eselect profile set 16

# 7. Базовая настройка
echo "=== Базовая настройка системы ==="
# Локаль
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

# Часовой пояс
echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data

# Создание пользователя (замените 'user' на свое имя)
useradd -m -G users,wheel,audio,video,usb,input user
echo "Создан пользователь 'user'. Установите пароль:"
passwd user
echo "Установите пароль для root:"
passwd root

# 8. Ядро (ИСПРАВЛЕННЫЙ БЛОК)
echo "=== Установка ядра ==="
# 1. Принудительно разрешаем флаг dracut для installkernel
mkdir -p /etc/portage/package.use
echo "sys-kernel/installkernel dracut" >> /etc/portage/package.use/installkernel

# 2. Устанавливаем бинарное ядро
emerge --ask sys-kernel/gentoo-kernel-bin

# 3. ! ВАЖНО ! Проверяем, что файлы создались
echo "=== Проверка файлов ядра ==="
ls -l /boot
echo "Вы должны увидеть: vmlinuz-*, initramfs-*, config-*"

# 9. Fstab
echo "=== Настройка fstab ==="
cat << FSTAB > /etc/fstab
/dev/sda1   /boot        vfat    defaults,noatime     0 2
/dev/sda2   none         swap    sw                   0 0
/dev/sda3   /            ext4    noatime              0 1
FSTAB

# 10. Загрузчик GRUB
echo "=== Установка GRUB ==="
emerge --ask sys-boot/grub sys-boot/efibootmgr

# Установка в EFI раздел
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Генерация конфига (найдет ядро linux image)
grub-mkconfig -o /boot/grub/grub.cfg

# 11. Сеть (NetworkManager)
echo "=== Настройка сети ==="
emerge --ask net-misc/networkmanager
systemctl enable NetworkManager

echo "=== Установка Gentoo завершена! ==="
EOF

# 12. Финал
echo "=== Завершение установки ==="
exit
cd
umount -R /mnt/gentoo
echo "Система готова к перезагрузке. Перезагрузите систему командой: reboot"
echo "После перезагрузки для установки KDE выполните:"
echo "echo \"kde-plasma/plasma-meta -sddm -zeroconf -bluetooth -networkmanager -geolocation\" >> /etc/portage/package.use/kde"
echo "emerge --ask kde-plasma/plasma-meta kde-apps/konsole kde-apps/dolphin"
echo "systemctl enable sddm"
