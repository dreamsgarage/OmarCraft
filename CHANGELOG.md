# Changelog

## 0.1.0 — unreleased

First release. Exercised on Omarchy 4.0.4 with WordCraft, DeckCraft and GridCraft installed as prebuilt
packages.

- Bar icon in the right section: left = panel, right = check the AUR, middle = switch layout. Urgent
  colour with the pending count while updates are ready, urgent after a failed job.
- Native panel (`KeyboardPanel`): hero with the one-line situation, INSTALLED / AVAILABLE
  sections, group chips *Install all*, *Creative*, *Office* with counts, a confirm naming the package
  before any install or update, spinner and greyed actions while a job runs, `h/l j/k`, `Enter`, `u`,
  `a/c/o`, `s`, `r`, `t`, `Tab`, `Esc`.
- Two layouts, switchable live (`omarchy bar set omarcraft.productivity layout tiles|rows`, `t`, IPC):
  **tiles**, three per line with the glyph in the app's own ArtCraft colour (from the official catalog)
  over its name at full contrast, installed with a tinted fill and available with an outline only;
  **rows**, one per line with a caption and a right-edge action.
- Apps with a newer build move to an UPDATES section at the top with an `↑ 0.8.0` badge and an
  *Update all · u* button; the hero reads `4 OF 13 INSTALLED · 2 UPDATES`. Trend-line logo in the hero
  and on the bar. No standing status line and no key legend (per the 2026-10-17 review).
- Clicking an installed app with a newer build asks: *Update* (that package), *Launch instead*, *Cancel*.
- Jobs run in Omarchy's floating presentation terminal: installs through `omarchy-pkg-aur-add`, updates
  package-exact through the AUR helper Omarchy ships; `job.json` while running, `last-job.json` after;
  the panel re-reads the package database when a job ends and reports an interrupted job as such.
- Data: catalog from the official ArtCraft Launcher with a built-in fallback, versions from one AUR RPC
  request, cached 24 h; `state` reads local files only; a failed refresh keeps the old data and reports
  offline. Six-hourly update check with one notification per new set; new apps flagged once.
- IPC: `open`, `close`, `toggle`, `refresh`, `status`, `layout`, `launch`, `install`, `update`.
- Opt-in only: an ArtCraft section in the Omarchy menu and a documented keybinding line.
- 79 offline tests with every external command stubbed.

Not in this release: removing apps, AppImage or Flatpak installs, the official launcher. ArtCraft Studio
(the AI image/video app) is deliberately out of scope: it is a different category of software from the
Craft apps and has no Linux build (removed 2026-10-17 at the user's request).

### Superseded during development (never released)

- v2, 2026-10-17: a text picker on `omarchy-menu-select` with the icon in the left section. Replaced by the
  panel.
- v1, 2026-10-17: Omarchy-menu entries whose "Office Suite" item installed the source-build bundle and
  compiled for hours. Removed; prebuilt packages only since.
