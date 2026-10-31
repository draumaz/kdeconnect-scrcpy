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

if [ "$1" = "--uninstall" ]; then
    systemctl --user disable --now kdeconnect-scrcpy.service 2>/dev/null || true
    rm -f ~/.local/bin/kdeconnect-scrcpy ~/.config/systemd/user/kdeconnect-scrcpy.service
    systemctl --user daemon-reload
    restore_popups
    echo "Uninstalled. Restart KDE Connect (or log out and back in) to get its popups back."
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
    echo "Turned off KDE Connect's duplicate popups (System Settings → Notifications → KDE Connect → Generic Notification)."
fi

systemctl --user daemon-reload
systemctl --user enable --now kdeconnect-scrcpy.service
systemctl --user restart kdeconnect-scrcpy.service
echo "Installed. Logs: journalctl --user -u kdeconnect-scrcpy -f"
echo "If you still see duplicate popups, restart KDE Connect: kquitapp6 kdeconnectd; kdeconnectd &"
