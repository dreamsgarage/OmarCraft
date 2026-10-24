# Changelog

## 0.5.2 — unreleased

Tasks and kanban boards join *Notes*, without a server; sixteen tools. The evaluation is in
`docs/v0.5.2-plan.md`.

- **Planify** joins Memospot in *Notes* (chip `n`): tasks and projects, each shown as a list or a kanban
  board. From the Arch repos like Typesetter, so it installs with Omarchy's repo command and updates with
  the system; nothing is compiled and no AUR packager is involved. No server and no sign-in (Todoist,
  Nextcloud or CalDAV sync is optional); data in `~/.local/share/io.github.alainm23.planify`. 153 MiB idle
  in one native process. Tile colour from its icon.
- **Working with others is part of the rule.** A tool beyond ArtCraft must let its work be shared and
  exported, through an open format or a sync or sharing service the user chooses. The README's new
  *Working with others* section shows each tool's route: Typesetter's plain-text Typst files, Memospot with
  a shared Memos server, Planify with Nextcloud Deck, Todoist or CalDAV.
- **Nothing is compiled, now checked.** Before an AUR install or update, OmarCraft asks the AUR for the
  package's declared dependencies; if one is neither installed nor in the Arch repos, the AUR helper would
  build it from source, so the job stops before anything is installed, names the dependency in the terminal
  and in a notification, and is recorded as failed. Found when Kanri's AUR package, first evaluated for this slot, started
  compiling libsoup 2.
- A failed job stays flagged (bar icon, header, red tile) only until you close the panel that showed it;
  before, it stayed until another job succeeded. The next failure is flagged again.
- README: how to upgrade from an earlier version (update, restart the shell, check the version).
- The HTML README says rocket, not palette, and counts its tools beyond ArtCraft correctly.

## 0.5.1 — 2026-10-23

Vikunja leaves OmarCraft; fifteen tools. The decision and the evidence are in `docs/v0.5.1-plan.md`.

- **Vikunja is dropped.** Its desktop app signs in only through the browser: the approval page hands a
  one-time code back through a `vikunja-desktop://` link, which Chromium opens only after its *Open
  xdg-open?* prompt, and the app must stay open the whole time because closing it stops the local
  server the browser is talking to. After a clean install on the author's machine the app never signed
  in, and each lapsed session (three days by default) would mean the same hand-off again. *Notes* is
  Memospot again.
- Where 0.5.0 installed Vikunja, OmarCraft deletes once the desktop entry and launcher it wrote, and says
  so in one notification. The packages, the data in `~/.local/share/omarcraft/vikunja`, a running server
  and anything you wrote stay; remove the app with `omarchy pkg drop vikunja-desktop-bin vikunja-bin`.
  0.5.0's commands `vikunja-session`, `vikunja-stop` and `tray-sync` only run that clean-up now.
- With Vikunja go its local server, its tray handling (OmarCraft no longer writes the bar's tray Hide list
  in `~/.config/omarchy/shell.json`) and the tile's server dot.
- Fix: a job whose terminal was closed mid-job, or stopped with `Ctrl+C`, was recorded as a success with
  the status of the last step that had finished; it is now recorded as interrupted.
- README *Safety* matches the code again: Typesetter's Arch repo path, and no write under `~/.config`
  without the opt-in commands. `omarcraft --help` prints its last line.

## 0.5.0 — 2026-10-23

Two more tools beyond ArtCraft, chosen by benchmark (`docs/v0.5-plan.md`), sixteen in all.

- **Typesetter** (Typst documents with a live preview) in *Office*. It comes from the Arch repos:
  installed with `omarchy-pkg-add`, version read from the local sync database, and updated with the
  system: its badge reads `↑ system` and opens Omarchy's update. *Update all* keeps to AUR apps.
- **Launch matches the app's window class only.** It used `omarchy-launch-or-focus`, which also matches
  window titles, so a terminal titled "Vikunja testing" was focused instead of opening Vikunja (a
  browser tab titled "PhotoCraft docs" would do the same for PhotoCraft).
- **Vikunja** (tasks, kanban, Gantt) joins Memospot in *Notes* (chip `n`).
  It installs the desktop app and its server; OmarCraft runs the server under the user on
  `127.0.0.1:3456` only while the app runs, keeps its data in `~/.local/share/omarcraft/vikunja`, and
  writes a user desktop entry so the app launcher starts it the same way. A dot on the tile shows the
  server running. Closing Vikunja's window quits it and stops the server (the app alone would hide in the
  tray and keep both running). Its tray icon stays on the bar's tray Hide list: every launch puts it there,
  and so does the panel whenever the shell reloads a plugin, which makes the bar forget it (the bar
  re-applies the tray's settings from when it was built).
  Removing Vikunja quits the app first, if it is open, then stops the server.
- The qualification rule now reads: stable desktop release, prebuilt (Arch repos or AUR `-bin`),
  maintained open-source upstream, about 150 MiB idle in one native process unless the tool adds something
  ArtCraft lacks. Memospot and Vikunja are the documented exceptions.
- Fix: an install job whose package command failed could be recorded as successful when a later step ran.

## 0.2.0 — 2026-10-18

OmarCraft opens beyond ArtCraft: productivity tools for the Omarchy bar, by one rule (a prebuilt
`<id>-bin` AUR package with a desktop entry, maintained upstream, permissive licence).

- **Memospot**, the desktop build of Memos (notes and journal), as the first tool of a new *Notes* group:
  tile in the amber of its icon, chip *n Notes · N*, `install-group notes`, menu entry *Install Notes*.
  Same install, launch, update and remove path as the Craft apps; no new marketplace capability.
- An existing catalog cache learns tools a newer plugin version knows: they are added and their AUR
  version fetched on the next read, and they show as *New* until the panel is opened.
- Manifest, README, menu labels and the new-app notification say "tools", not only "Craft apps"; the
  hero counts fourteen.

## 0.1.0 — 2026-10-18

First release. Exercised on Omarchy 4.0.4 with all 13 Craft apps installed, updated and removed as
prebuilt packages through the panel (acceptance rows 1–19 and 21 in `docs/v1-acceptance.md`).

- Bar icon in the right section, a rocket at the size of the first-party icons: left = panel, right =
  check the AUR, middle = switch layout. Urgent colour with the pending count while updates are ready,
  urgent while a new Craft app waits to be seen, urgent after a failed job.
- Native panel (`KeyboardPanel`): hero with the one-line situation, INSTALLED / AVAILABLE
  sections, group chips *Creative* and *Office* with counts, a confirm naming the package
  before any install or update, spinner and greyed actions while a job runs, `h/l j/k`, `Enter`, `u`,
  `c/o`, `r`, `t`, `Tab`, `Esc`.
- Two layouts, switchable live (`omarchy bar set omarcraft.productivity layout tiles|rows`, `t`, IPC):
  **tiles**, three per line with the glyph in the app's own ArtCraft colour (from the official catalog)
  over its name at full contrast, installed with a tinted fill and available with an outline only;
  **rows**, one per line with a caption and a right-edge action.
- Remove an app from the panel (2026-10-18, canvas Round 4, option A): right-click an installed tile or
  `x` on the cursor, confirm *Remove ⏎* in the urgent colour, one terminal running Omarchy's
  `omarchy-pkg-drop <id>-bin`; the tile returns to AVAILABLE. Apps installed some other way are not
  offered. Also `omarcraft remove <id>…` and IPC `remove`.
- Offline: a failed AUR check is retried by the panel at most every ten minutes (a manual `r` or
  right-click always tries). Before, every state read retried and every failed retry poked the panel,
  a loop that printed `omarcraft state exited with status 15` in red while offline.
- A state read is never killed by a newer request; requests coalesce. One read takes 0.2 s with all
  13 apps installed (was 0.8 s): no forked helper per field any more.
- Apps with a newer build move to an UPDATES section at the top with an `↑ 0.8.0` badge and an
  *Update all · u* button; the hero reads `4 OF 13 INSTALLED · 2 UPDATES`. Rocket logo in the hero
  and on the bar. No standing status line, no key legend, no *Install all* chip (per the 2026-10-17
  reviews).
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
