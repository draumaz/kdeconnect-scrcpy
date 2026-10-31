# kdeconnect-scrcpy

iPhone Mirroring–style phone notifications for KDE Plasma. A notification from your
Android phone arrives through KDE Connect, you click **Open**, and a scrcpy window
opens with your phone's screen, already in the app that sent it. You can control
the phone from that window with your mouse and keyboard.

## How it works

```
phone app ──► KDE Connect (Android) ──► kdeconnectd ──D-Bus──► kdeconnect-scrcpy
                                                                 │  posts a Plasma notification
                                                                 │  with Open / Reply buttons
                                       you click "Open" ◄────────┘
                                             │
                     adb (USB or Wireless debugging) ──► scrcpy --start-app=<package>
```

- KDE Connect publishes every phone notification on the session bus
  (`org.kde.kdeconnect.device.notifications`). Each one has an `internalId` that holds
  the Android package name, e.g. `0|com.whatsapp|…`.
- The daemon posts its own notification with an **Open** action. It also has inline
  **Reply** when the phone app supports it, and it disappears when you clear the
  notification on the phone.
- When you click Open, it finds the phone over ADB. It tries USB first, then
  Wireless debugging (found through mDNS and matched to the IP KDE Connect reports).
  Then it runs `scrcpy --start-app=<package>`. If a mirror is already open, it just
  switches the phone to that app.
- The installer turns off KDE Connect's own popup for phone notifications so you
  don't get two of each.

## Requirements

- KDE Plasma 6 and KDE Connect, paired with the phone
- `scrcpy` (v2.2+ for `--start-app`), `android-tools` (adb), `python-dbus`, `python-gobject`
- On the phone: **Developer options → USB debugging**, and for cordless use
  **Wireless debugging**. Pair once from the computer:
  `adb pair <ip>:<pairing-port>` (shown under *Pair device with pairing code*).
  After that, the phone reconnects automatically whenever Wireless debugging is on
  and you're on the same network.

## Install

```sh
./install.sh                # installs to ~/.local/bin and enables a systemd user service
./install.sh --keep-popups  # same, but leave KDE Connect's own popups on
./install.sh --uninstall
```

Settings live in `~/.config/kdeconnect-scrcpy/config.toml` (see `config.example.toml`).
Logs: `journalctl --user -u kdeconnect-scrcpy -f`.

To try it without waiting for a real notification, post a fake one for any app
(ADB can't post notifications on behalf of other apps, so this is done on the desktop side):

```sh
kdeconnect-scrcpy --test com.twitter.android
```

## Limitations

- Clicking Open opens the *app*, not the exact chat or post. Android doesn't let ADB
  fire another app's notification intent.
- Apps without a launcher activity (e.g. some system services) open the mirror but
  stay on the current screen.
- Wireless debugging turns itself off on networks the phone doesn't trust and after
  some reboots. If Open shows "Couldn't reach … over ADB", turn it back on.
