#!/bin/bash
# setup_gentoo_ssh.sh
# Скрипт для установки OpenSSH и создания пользователя в Gentoo LiveCD

# Обновляем дерево пакетов
emerge --sync

# Устанавливаем OpenSSH и sudo
emerge --ask net-misc/openssh app-admin/sudo

# Создаём пользователя "admin" с домашним каталогом и оболочкой bash
useradd -m -G users,wheel -s /bin/bash admin

# Устанавливаем пароль для пользователя
echo "Задайте пароль для пользователя admin:"
passwd admin

# Добавляем пользователя в группу wheel (для sudo)
gpasswd -a admin wheel

# Включаем sshd в автозагрузку и запускаем его (OpenRC)
rc-update add sshd default
/etc/init.d/sshd start

# Выводим статус sshd
rc-status

echo "[✓] OpenSSH установлен и настроен. Пользователь 'admin' создан."