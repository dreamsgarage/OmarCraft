# Changelog

## 0.1.0 — unreleased

First release. Exercised on Omarchy 4.0.4 with WordCraft, DeckCraft and GridCraft installed as prebuilt
packages.

- Bar icon in the right section: left = panel, right = ArtCraft Studio, middle = check the AUR. Urgent
  colour with the pending count while updates are ready, urgent after a failed job.
- Native panel (`KeyboardPanel`): hero with the one-line situation, INSTALLED / AVAILABLE / STUDIO sections,
  one row per app with glyph, name, status and a right-edge action; available rows dimmed; group chips
  *Install all*, *Creative*, *Office* with counts; inline confirm naming the package before any install
  and before *Update all*; spinner and greyed actions while a job runs; `j/k`, `Enter`, `u`, `a/c/o`,
  `s`, `r`, `Tab`, `Esc`.
- Jobs run in Omarchy's floating presentation terminal through Omarchy's own commands
  (`omarchy-pkg-aur-add`, `omarchy-update-aur-pkgs`); `job.json` while running, `last-job.json` after;
  the panel re-reads the package database when a job ends and reports an interrupted job as such.
- Data: catalog from the official ArtCraft Launcher with a built-in fallback, versions from one AUR RPC
  request, cached 24 h; `state` reads local files only; a failed refresh keeps the old data and reports
  offline. Six-hourly update check with one notification per new set; new apps flagged once.
- ArtCraft Studio as an Omarchy web app.
- IPC: `open`, `close`, `toggle`, `refresh`, `status`, `launch`, `install`, `update`, `studio`.
- Opt-in only: an ArtCraft section in the Omarchy menu and a documented keybinding line.
- 71 offline tests with every external command stubbed.

Not in this release: per-app update (Omarchy's AUR update is all-or-nothing), removing apps, AppImage or
Flatpak installs, the official launcher, building Studio.

### Superseded during development (never released)

- v2, 2026-10-17: a text picker on `omarchy-menu-select` with the icon in the left section. Replaced by the
  panel.
- v1, 2026-10-17: Omarchy-menu entries whose "Office Suite" item installed the source-build bundle and
  compiled for hours. Removed; prebuilt packages only since.
