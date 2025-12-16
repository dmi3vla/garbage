#!/bin/bash

# Минимальная установка KDE Plasma с SSH/SFTP сервером
# ВНИМАНИЕ: Установка KDE - это очень объемный процесс.
# Вам все еще нужно быть в chroot с настроенным интернетом.

set -e  # Прерывать выполнение при любой ошибке

echo "=== Начало минимальной установки KDE Plasma с SSH/SFTP ==="

# 1. Настройка USE-флагов (Ключевой шаг)
echo "=== Настройка USE-флагов ==="

# A. Глобальные USE-флаги в make.conf
echo "Настройка глобальных USE-флагов..."
if ! grep -q "systemd" /etc/portage/make.conf; then
    echo "Добавляем systemd в USE флаги..."
    sed -i 's/USE="\(.*\)"/USE="\1 systemd"/' /etc/portage/make.conf
fi

# Добавляем флаги для минимизации
echo "Добавляем флаги для минимализации..."
cat << 'EOF' >> /etc/portage/make.conf

# Минимизация KDE Plasma
USE="${USE} -akonadi -baloo -bluetooth -doc -nepomuk -pim -telepathy -wayland -zeroconf"
EOF

# B. Флаги для конкретных пакетов
echo "Создание файла package.use/kde..."
mkdir -p /etc/portage/package.use
cat << 'EOF' > /etc/portage/package.use/kde

# Отключаем ненужное в KWin (композитный менеджер)
kde-plasma/kwin -kwayland

# Отключаем ненужное в Plasma-meta (базовый пакет)
kde-plasma/plasma-meta -sddm -zeroconf -bluetooth -networkmanager -geolocation

# Отключаем медиасервер
media-sound/pulseaudio -daemon

# Если используете NetworkManager, можно отключить его интеграцию
net-misc/networkmanager -ppp -modemmanager -kde

# SSH сервер с поддержкой SFTP
net-misc/openssh pam tcpd

# SFTP поддержка
net-fs/sftp-server
EOF

# 2. Установка минимального набора пакетов
echo "=== Установка базового набора KDE Plasma ==="

# Определение драйвера видеокарты
echo "Определение драйвера видеокарты..."
VIDEO_DRIVER=""
if lspci | grep -i "nvidia" > /dev/null; then
    VIDEO_DRIVER="x11-drivers/nvidia-drivers"
elif lspci | grep -i "amd\|radeon" > /dev/null; then
    VIDEO_DRIVER="x11-drivers/xf86-video-amdgpu"
elif lspci | grep -i "intel" > /dev/null; then
    VIDEO_DRIVER="x11-drivers/xf86-video-intel"
elif lspci | grep -i "virtualbox" > /dev/null; then
    VIDEO_DRIVER="app-emulation/virtualbox-guest-additions"
else
    VIDEO_DRIVER="x11-drivers/xf86-video-vesa"  # Универсальный драйвер
    echo "Не удалось определить драйвер, используем vesa"
fi

echo "Используем драйвер: $VIDEO_DRIVER"

# Установка базового набора
emerge --ask \
    kde-plasma/plasma-meta \
    x11-drivers/xf86-input-evdev \
    "$VIDEO_DRIVER"

# B. Минимальный набор приложений
echo "=== Установка минимального набора приложений ==="
emerge --ask kde-apps/konsole kde-apps/dolphin kde-apps/kate

# 3. Установка SSH/SFTP сервера
echo "=== Установка SSH/SFTP сервера ==="
emerge --ask net-misc/openssh

# Настройка SSH сервера
echo "Настройка SSH сервера..."
cat << 'EOF' > /etc/ssh/sshd_config

# Базовая конфигурация SSH сервера
Port 22
Protocol 2

# Аутентификация
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes

# Безопасность
PermitEmptyPasswords no
X11Forwarding yes

# SFTP (встроенный в OpenSSH)
Subsystem sftp /usr/lib64/misc/sftp-server

# Логирование
SyslogFacility AUTH
LogLevel INFO

EOF

# Включение SSH сервиса
echo "Включение SSH сервиса..."
systemctl enable sshd
systemctl start sshd

# 4. Настройка и запуск KDE
echo "=== Настройка и запуск KDE Plasma ==="

# A. Настройка SDDM
echo "Настройка SDDM..."

# Установка SDDM отдельно (если был отключен в plasma-meta)
emerge --ask x11-misc/sddm

# Настройка запуска (для systemd)
echo "Включение SDDM для systemd..."
systemctl enable sddm.service

# Создание базовой конфигурации SDDM
mkdir -p /etc/sddm.conf.d
cat << 'EOF' > /etc/sddm.conf.d/kde_settings.conf

[Autologin]
# Раскомментируйте для автологина
# User=user
# Session=plasma

[General]
# HaltCommand=/usr/bin/systemctl poweroff
# RebootCommand=/usr/bin/systemctl reboot

[Theme]
# Current=breeze
EOF

# 5. Настройка фаервола для SSH
echo "=== Настройка фаервола для SSH ==="
if command -v ufw > /dev/null; then
    echo "Настройка UFW для SSH..."
    ufw allow 22/tcp
    ufw --force enable
elif command -v iptables > /dev/null; then
    echo "Настройка iptables для SSH..."
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    # Сохранение правил (зависит от дистрибутива)
    if command -v iptables-save > /dev/null; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
        iptables-save > /etc/iptables.rules 2>/dev/null || \
        echo "Правила iptables не сохранены автоматически"
    fi
fi

# 6. Создание пользователя с правами для SSH
echo "=== Создание пользователя для SSH ==="
if ! id "user" &>/dev/null; then
    echo "Пользователь 'user' уже существует"
else
    echo "Создание пользователя 'user' с правами для SSH..."
    useradd -m -G users,wheel,audio,video,usb,input,ssh user
    echo "Установите пароль для пользователя 'user':"
    passwd user
fi

# 7. Проверка установки
echo "=== Проверка установки ==="
echo "Проверка файлов ядра в /boot:"
ls -la /boot/ | grep -E "(vmlinuz|initramfs|config)"

echo "Проверка установки KDE:"
if command -v startplasma-x11 > /dev/null; then
    echo "KDE Plasma установлен успешно"
else
    echo "ВНИМАНИЕ: KDE Plasma может быть установлен некорректно"
fi

echo "Проверка SSH сервера:"
systemctl status sshd --no-pager || echo "SSH сервис не запущен"

echo "Проверка SDDM:"
systemctl status sddm --no-pager || echo "SDDM сервис не запущен"

# 8. Финальная информация
echo "=== Установка завершена! ==="
echo ""
echo "=== ИНФОРМАЦИЯ О СИСТЕМЕ ==="
echo "1. KDE Plasma установлен с минимальным набором пакетов"
echo "2. SSH сервер запущен и доступен на порту 22"
echo "3. SFTP встроен в SSH сервер"
echo "4. SDDM настроен для автозапуска"
echo ""
echo "=== ПОЛЕЗНЫЕ КОМАНДЫ ==="
echo "Подключиться по SSH: ssh user@IP_АДРЕС"
echo "Подключиться по SFTP: sftp user@IP_АДРЕС"
echo "Проверить статус SSH: systemctl status sshd"
echo "Перезапустить SSH: systemctl restart sshd"
echo "Проверить статус SDDM: systemctl status sddm"
echo ""
echo "=== СЛЕДУЮЩИЕ ШАГИ ==="
echo "1. Перезагрузите систему: reboot"
echo "2. После перезагрузки войдите в графический режим"
echo "3. Настройте SSH ключи для безопасности"
echo "4. Настройте фаервол по необходимости"
echo ""
echo "=== ДИАГНОСТИКА ==="
echo "Если графический режим не запускается:"
echo "- Проверьте драйвер видеокарты: lspci | grep -i vga"
echo "- Проверьте логи X11: cat /var/log/Xorg.0.log"
echo "- Проверьте статус SDDM: systemctl status sddm"
echo ""
echo "Если SSH не работает:"
echo "- Проверьте статус: systemctl status sshd"
echo "- Проверьте порт: netstat -tlnp | grep :22"
echo "- Проверьте конфиг: sshd -t"
