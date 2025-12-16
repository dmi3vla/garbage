Вот исправленная и оптимизированная инструкция.

**Главное изменение:** В **Шаге 8** добавлена предварительная настройка флагов. Это решает проблему, когда `emerge` останавливался, просил подтвердить изменения, но не создавал файлы ядра (`vmlinuz`, `initramfs`). Теперь установка пройдет с первого раза.

---

##🚀 Исправленный сценарий установки Gentoo (Systemd + EFI)###1. Подготовка VM (VirtualBox)* **Тип ОС:** Linux / Gentoo 64-bit.
* **EFI:** Включить галочку **Enable EFI** (System → Motherboard).
* **Диск:** Минимум 25 ГБ (для KDE лучше 30+).
* **Сеть:** Bridged Adapter (Сетевой мост) — чтобы был интернет.

###2. Разметка диска (GPT)
#bash
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart swap linux-swap 512MiB 4.5GiB  # Swap лучше побольше для компиляции
parted /dev/sda -- mkpart root ext4 4.5GiB 100%

mkfs.vfat -F32 /dev/sda1
mkswap /dev/sda2 && swapon /dev/sda2
mkfs.ext4 /dev/sda3

```

###3. Монтирование (Строго по порядку!)```bash
# 1. Сначала корень
mount /dev/sda3 /mnt/gentoo

# 2. Создаем папку для boot
mkdir -p /mnt/gentoo/boot

# 3. Монтируем boot раздел (ОБЯЗАТЕЛЬНО СЕЙЧАС)
mount /dev/sda1 /mnt/gentoo/boot

# 4. Проверка (должны быть видны sda3 и sda1)
lsblk

```

###4. Скачивание Stage3 (Systemd)Используем ссылку на `current`, чтобы всегда была свежая версия.

```bash
# cd /mnt/gentoo
# wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-systemd/stage3-amd64-systemd-*.tar.xz

# Распаковка (занимает время)
# tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

cd /mnt/gentoo
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20251207T170056Z/stage3-amd64-systemd-20251207T170056Z.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

```

###5. Вход в Chroot```bash
# Копируем DNS # Монтируем системные разделы
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

# Входим
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"

```

###6. Обновление Portage и выбор профиля```bash
emerge-webrsync

# Смотрим список профилей
eselect profile list

# Выбираем стабильный systemd (цифры могут меняться, ищите 'default/linux/amd64/23.0/systemd')
# Например, если это номер 16:
eselect profile set 16

```

###7. Базовая настройка```bash
# Локаль
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

# Часовой пояс
echo "UTC" > /etc/timezone
emerge --config sys-libs/timezone-data

# Создание пользователя (замените 'user' на свое имя)
useradd -m -G users,wheel,audio,video,usb,input user
passwd user
passwd root

```

###8. Ядро (ИСПРАВЛЕННЫЙ БЛОК)Мы заранее прописываем нужные флаги, чтобы `emerge` не вылетал в цикл подтверждений.

```bash
# 1. Принудительно разрешаем флаг dracut для installkernel
mkdir -p /etc/portage/package.use
echo "sys-kernel/installkernel dracut" >> /etc/portage/package.use/installkernel

# 2. Устанавливаем бинарное ядро
emerge --ask sys-kernel/gentoo-kernel-bin

# 3. ! ВАЖНО ! Проверяем, что файлы создались
ls -l /boot
# Вы должны увидеть: vmlinuz-*, initramfs-*, config-*

```

###9. FstabАвтоматическое создание файла конфигурации дисков.

```bash
cat <<EOF > /etc/fstab
/dev/sda1   /boot        vfat    defaults,noatime     0 2
/dev/sda2   none         swap    sw                   0 0
/dev/sda3   /            ext4    noatime              0 1
EOF

```

###10. Загрузчик GRUB```bash
emerge --ask sys-boot/grub sys-boot/efibootmgr

# Установка в EFI раздел
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Генерация конфига (найдет ядро linux image)
grub-mkconfig -o /boot/grub/grub.cfg

```

###11. Сеть (NetworkManager)Для KDE Plasma лучше всего использовать NetworkManager.

```bash
emerge --ask net-misc/networkmanager
systemctl enable NetworkManager

```

###12. Финал```bash
exit
cd
umount -R /mnt/gentoo
reboot

```

---

###Что делать после перезагрузки (для KDE):Когда вы войдете в новую систему (логин root или ваш user), выполните команду для минимальной KDE:

```bash
# Минимальные флаги
echo "kde-plasma/plasma-meta -sddm -zeroconf -bluetooth -networkmanager -geolocation" >> /etc/portage/package.use/kde

# Установка
emerge --ask kde-plasma/plasma-meta kde-apps/konsole kde-apps/dolphin

# Включение графического входа
systemctl enable sddm

```