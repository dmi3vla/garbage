Вы хотите установить окружение рабочего стола KDE Plasma, но с минимальным набором пакетов, чтобы система не была перегружена. Это правильный подход в Gentoo!

В Gentoo минимальная установка KDE Plasma достигается путем выбора определенных пакетов и, что самое главное, правильной настройкой **USE-флагов**.

**ВНИМАНИЕ:** Установка KDE — это очень объемный процесс. Вам все еще нужно быть в **chroot** с настроенным интернетом.

---

###1. Настройка USE-флагов (Ключевой шаг)Перед началом установки KDE Plasma, вам нужно определить, какие компоненты вы хотите отключить. Это делается в файле `/etc/portage/make.conf` (глобально) или в `/etc/portage/package.use/kde` (лучше для конкретных пакетов).

####A. Глобальные USE-флагиВ `/etc/portage/make.conf` или `/etc/portage/package.use/plasma` добавьте или уберите флаги:

* **Обязательно включить:** `elogind` или `systemd` (в зависимости от того, что вы выбрали как init system), `qt5`, `kde`, `plasma`.
* **Исключить/Отключить (для минимализма):** Добавьте дефис (`-`) перед ненужными флагами.

```bash
# В /etc/portage/make.conf

# ВАЖНО: Определите, что вы используете. Обычно systemd или elogind.
# Если вы используете Stage3 с systemd:
USE="... systemd ..." 

# Если вы используете Stage3 с OpenRC/Elogind:
USE="... elogind ..." 

# Добавьте/уберите эти флаги (пример для минимизации):
USE="... -akonadi -baloo -bluetooth -doc -nepomuk -pim -telepathy -wayland -zeroconf"

```

####B. Флаги для конкретных пакетов (Наиболее эффективно)Создайте файл `/etc/portage/package.use/kde` и добавьте туда флаги для базовых пакетов:

```bash
# В /etc/portage/package.use/kde

# Отключаем ненужное в KWin (композитный менеджер)
kde-plasma/kwin -kwayland

# Отключаем ненужное в Plasma-meta (базовый пакет)
kde-plasma/plasma-meta -sddm -zeroconf -bluetooth -networkmanager -geolocation

# Отключаем медиасервер
media-sound/pulseaudio -daemon

# Если используете NetworkManager, можно отключить его интеграцию
net-misc/networkmanager -ppp -modemmanager -kde

```

###2. Установка минимального набора пакетовДля минимального KDE Plasma вам понадобятся только основные мета-пакеты.

####A. Базовый наборУстановите минимальный набор для запуска рабочего стола:

```bash
emerge --ask \
    kde-plasma/plasma-meta \
    x11-drivers/xf86-input-evdev \
    x11-drivers/xf86-video-intel # <--- Замените на ваш драйвер (nvidia, amdgpu, virtualbox, и т.д.)

```

####B. Минимальный набор приложенийВ Gentoo KDE Plasma не тянет много приложений по умолчанию, но для работы вам могут понадобиться:

* **Терминал:** `konsole`
* **Файловый менеджер:** `kde-apps/dolphin`
* **Редактор:** `kde-apps/kate` или `app-editors/nano`

Установите их отдельно:

```bash
emerge --ask kde-apps/konsole kde-apps/dolphin

```

###3. Настройка и запускПосле установки вам нужно будет настроить дисплейный менеджер (SDDM) и сам Plasma.

####A. Настройка SDDMУбедитесь, что SDDM установлен и включен для запуска при загрузке.

1. **Проверка установки SDDM:** Если вы не отключили флаг `-sddm` в `plasma-meta`, он уже установлен.
2. **Настройка запуска (для OpenRC):**
```bash
rc-update add display-manager default
# Выберите SDDM
eselect display-manager set sddm

```


3. **Настройка запуска (для systemd):**
```bash
systemctl enable sddm.service

```



---

###Резюме действий1. **В chroot:** Определите и установите минимальные USE-флаги в `/etc/portage/make.conf` и `/etc/portage/package.use/kde`.
2. **В chroot:** Выполните `emerge --ask kde-plasma/plasma-meta` (и не забудьте про драйвер видеокарты!).
3. **В chroot:** Включите SDDM через `rc-update` или `systemctl enable`.
4. Выйдите из chroot и перезагрузитесь.

**Какой драйвер для видеокарты вам нужен (например, `xf86-video-amdgpu`, `nvidia-drivers` или `virtualbox-guest-additions`)?**