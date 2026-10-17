# Changelog

## 0.1.0 — unreleased

First release. Exercised on Omarchy 4.0.4.

- Bar widget: left click opens the picker, right click opens ArtCraft Studio, middle click checks for
  updates. The icon turns urgent and the tooltip lists pending updates.
- Picker over Omarchy's own `omarchy-menu-select`: all thirteen Craft apps with their state (installed,
  available, update ready, new), launch or focus, install then launch, group installs (Classic, New, all)
  and *Update apps*.
- Installs and updates in one floating Omarchy terminal and one `yay` run. Only prebuilt `<id>-bin`
  packages, so nothing is compiled; source-build bundles are deliberately avoided.
- App catalog parsed from the official ArtCraft Launcher, with a built-in fallback; versions from one AUR
  RPC request; both cached for 24 hours. New apps are flagged and notified once.
- Update check every six hours, one notification per new set of updates.
- ArtCraft Studio as an Omarchy web app, added to the app launcher on first use.
- IPC: `open`, `refresh`.
- Opt-in only: an ArtCraft section in the Omarchy menu (`bin/omarcraft setup-menu`) and a documented
  keybinding line. The plugin changes no configuration on its own.
- Offline test suite: `bash tests/run.sh`.

Not in this release: removing apps from the picker, AppImage installs, a custom panel UI.
