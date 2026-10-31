#!/bin/sh
# Installs kdeconnect-scrcpy as a systemd user service.
#   ./install.sh                 install and replace KDE Connect's own popups
#   ./install.sh --keep-popups   install, but leave KDE Connect's popups alone
#   ./install.sh --uninstall     remove everything and restore KDE Connect's popups
set -e
cd "$(dirname "$0")"

restore_popups() {
    kwriteconfig6 --file kdeconnect.notifyrc --group Event/notification --key Action --delete
}

# kdeconnectd only reads its notification settings at startup, and ignores
# kquitapp6. Stop it and let D-Bus activation start it again.
restart_kdeconnect() {
    pgrep -x kdeconnectd >/dev/null || return 0
    pkill -x kdeconnectd
    sleep 1
    busctl --user call org.kde.kdeconnect /modules/kdeconnect \
        org.freedesktop.DBus.Peer Ping >/dev/null 2>&1 || (kdeconnectd >/dev/null 2>&1 &)
}

if [ "$1" = "--uninstall" ]; then
    systemctl --user disable --now kdeconnect-scrcpy.service 2>/dev/null || true
    rm -f ~/.local/bin/kdeconnect-scrcpy ~/.config/systemd/user/kdeconnect-scrcpy.service
    systemctl --user daemon-reload
    restore_popups
    restart_kdeconnect
    echo "Uninstalled. KDE Connect's own popups are back."
    exit 0
fi

for dep in adb scrcpy kdeconnect-cli; do
    command -v "$dep" >/dev/null || echo "warning: $dep not found, install it first"
done
python3 -c 'import dbus, gi' 2>/dev/null || echo "warning: needs python-dbus and python-gobject"

install -Dm755 kdeconnect-scrcpy ~/.local/bin/kdeconnect-scrcpy
install -Dm644 kdeconnect-scrcpy.service ~/.config/systemd/user/kdeconnect-scrcpy.service
[ -e ~/.config/kdeconnect-scrcpy/config.toml ] || \
    install -Dm644 config.example.toml ~/.config/kdeconnect-scrcpy/config.toml

if [ "$1" != "--keep-popups" ]; then
    # Turn off KDE Connect's own popup for phone notifications so you don't get two.
    kwriteconfig6 --file kdeconnect.notifyrc --group Event/notification --key Action ""
    restart_kdeconnect
    echo "Turned off KDE Connect's duplicate popups (System Settings → Notifications → KDE Connect → Generic Notification)."
fi

systemctl --user daemon-reload
systemctl --user enable --now kdeconnect-scrcpy.service
systemctl --user restart kdeconnect-scrcpy.service
echo "Installed. Logs: journalctl --user -u kdeconnect-scrcpy -f"
