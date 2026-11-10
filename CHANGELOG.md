# Changelog

## 0.5.8 — unreleased

ArtCraft's new apps, and a panel that stays simple with twenty tools. Plan and decisions in
`docs/v0.5.8-plan.md`; design Round 7 on the design canvas.

- **Fixed: ArtCraft's app list was no longer read.** ArtCraft changed its layout on 2026-11-06/07 and
  OmarCraft quietly fell back to its built-in thirteen apps. Both layouts are read now, within the same
  bounds as before, and a list that downloads but holds no readable app is reported by `omarcraft check`
  and `list` instead of going unnoticed.
- **New apps:** SolidCraft (Tangency Labs, a community app in ArtCraft's list), TextureCraft and
  MaterialCraft in the new **3D Art** category with CADCraft, and Craft Anything, ArtCraft's AI coding agent
  (early alpha), on its own line at the bottom of the panel. Twenty tools in all.
- **Categories instead of status sections:** Office, Creative and 3D Art (Notes merged into Office), each
  one header line that opens and closes with Enter and is remembered; a category opens by itself when it
  gets a new app. Keys `c`, `3` and `o` install what a category is missing (`n` is gone; `install-group
  notes` still works, as Office).
- **No version numbers in the panel:** badges read *Update* or *New*, confirms name the apps only, and the
  update notification lists names. After an update, one line names what was updated. The command line
  (`list`, `check`) still shows versions.
- The UPDATES strip names the apps; the apps stay in their category with their badge.
- Cache format 6: the first read after the update fetches the list at once.
- Trackpad scrolling follows the fingers, the way Omarchy's own menu scrolls; it was sluggish.
- MailCraft, which ArtCraft added on 2026-11-10, is placed in Office; it shows once it has a package.

## 0.5.7 — unreleased

WordCraft and GridCraft come from the AUR again, so OmarCraft offers ArtCraft's releases within hours. The
decision and its cases are in `docs/v0.5.7-plan.md`.

- **Changed: Craft apps that Omarchy's repo also ships follow the AUR.** On 2026-11-09 WordCraft 0.16.0
  offered its own update to 0.17.0 while OmarCraft and Omarchy showed none: ArtCraft and the AUR had
  0.17.0, Omarchy's repo still 0.16.0. These apps now compare with the AUR's build, and installs and
  updates name the AUR explicitly (`yay -S aur/<pkg>`), since pacman and the AUR helper otherwise take the
  repo's build. The AUR build replaces Omarchy's in place under the same name, so there is only one copy;
  Omarchy's update never downgrades it, and brings Omarchy's build only when that one is newer. If the AUR
  has no build of such an app, it follows Omarchy's repo as before. Typesetter and Planify are unchanged.
- The code that followed Omarchy's repo (0.5.4 to 0.5.6) is kept, switched off (`FOLLOW_APP_REPOS`), until
  Omarchy answers omacom/omarchy-pkgs#2390; its tests still run with it on.
- The first read after the update checks at once (cache format 5), so the new badges show without waiting
  for the six-hourly check.

## 0.5.6 — 2026-11-09

Apps from a package repo show their updates, and apps from Omarchy's repo update alone. The review and the
decisions are in `docs/v0.5.6-plan.md`.

- **Fixed: WordCraft and GridCraft never showed an update.** OmarCraft read what the repos ship from the
  system's package lists, which are only as new as its last update: on 2026-11-08 they still said
  GridCraft 0.16.1 while Omarchy's repo shipped 0.17.0, so the panel showed nothing while the app itself
  offered 0.17.0, and a reinstall from the tile installed 0.16.1 again. Each check now reads the repos as
  they are now, the way Omarchy's own update check does: `checkupdates` refreshes a private copy of the
  package lists (about 9 MB in `~/.cache/omarchy/omarcraft/checkup-db`), without a password and without
  touching the system's. The six-hourly notification names these updates too.
- **Apps from Omarchy's repo update alone, like the AUR ones**, without Omarchy's whole update: their
  badge shows the new version, and Enter or *Update all* installs just that app, in one terminal with one
  password prompt. OmarCraft first asks pacman, against the private copy, what the update needs, and goes
  ahead only when nothing but that app would change; the package comes from Omarchy's https address, pacman
  checking its signature (OmarCraft refuses where pacman would not require one), through the AUR helper
  Omarchy ships. When the update needs other packages, nothing is installed and the terminal names them;
  Omarchy's update brings them together. The system's own lists and every other package stay as they are,
  and Omarchy's update still updates these apps with everything else when it runs. One risk remains: a new
  build that needs a newer library without declaring it would affect that app alone, until the next full
  update. Tools from the Arch repos (Typesetter, Planify) still update with the system.
- **Fixed: Update all did nothing when only system updates were pending.** It said "The rest update with
  the system · Enter on their tile"; it now runs Omarchy's update when only tools from the Arch repos are
  pending, and otherwise updates every app that updates alone, as before.
- **Fixed: the six-hourly check checked once a day.** The panel checked every six hours, but the list was
  only fetched again after 24 hours; it is now fetched at every six-hourly check.
- README: an app's own "Update and restart" cannot update a package that pacman installed; update it from
  OmarCraft or with Omarchy's update.
- Tests: 267 offline tests (33 new), each new piece checked by breaking it on purpose.

## 0.5.5 — 2026-11-08

What comes from the network is bounded: a fix from the marketplace review of 0.5.4. The decision is in
`docs/v0.5.5-plan.md`.

- **Fixed: an oversized answer could fill the shell's memory.** OmarCraft took app names and taglines from
  the upstream catalog without a length limit, and its download had a time limit but no size limit; the
  panel reads all of OmarCraft's output inside the shell that draws the bar. Whoever controlled that
  catalog or its connection could have sent a huge record and run the shell out of memory during the
  automatic check. Now each download stops at a size (256 KB for the catalog, which is 19 KB; 1 MB for an
  AUR answer, which is 10 KB) and a longer one is refused whole. Only well-formed records are kept: a plain
  id, a name of at most 48 characters and a tagline of at most 96 without control characters, `#rrggbb`
  colours, at most 64 apps. AUR versions must look like versions, and a declared dependency must look
  like a package name before it reaches pacman. The panel's data is bounded again on the way out (at most
  72 tools), so a cache an older version wrote cannot carry an oversized field either; such a cache is
  checked again once, at once.
- README: tested on Omarchy 4.5.
- Tests: 234 offline tests (18 new), each new bound checked by breaking it on purpose.

## 0.5.4 — 2026-11-07

Apps that Omarchy's own repo ships, done right, and 0.5.3's regression fixed. The decision is in
`docs/v0.5.4-plan.md`.

- **Fixed: 0.5.3 took every installed app for a repo app.** It read pacman's list of AUR packages
  (`name version` lines) as names, so no package ever counted as an AUR one. With every tool installed the
  panel said `OFFLINE · Could not reach the AUR` while online and found no more updates; otherwise a check
  erased the AUR version of every installed app. Every badge read `↑ system` and opened Omarchy's update,
  which cannot bring an AUR build, so a badge could stay forever.
- **A tool a package repo ships follows that repo, whatever installed it.** Omarchy's own repo now ships
  WordCraft and GridCraft under their AUR names (`wordcraft-bin`, `gridcraft-bin`), and pacman and the AUR
  helper both take a package from a repo when one ships it: 0.5.2's Update reinstalled Omarchy's build
  (once downgrading WordCraft) and the badge stayed. OmarCraft now reads from the local sync databases
  which tools a repo ships, installed or not. Those show the repo's version, install with
  `omarchy-pkg-add` and update with the system; `↑ system` appears only when the repo has a newer build
  than the one installed, so the update always clears it. Every other tool keeps the AUR's version and
  package-exact AUR updates. When a repo starts or stops shipping a tool, the tool follows after the next
  system update. The tile of a tool not yet installed names the repo it comes from.
- **A check fails only when the AUR does not answer**, never because nothing is newer or every tool comes
  from a repo. An error reply from the AUR now counts as a failure, not as an empty answer.
- **Fast again.** What the repos ship is kept until a sync database, `pacman.conf` or the catalog changes:
  a panel read is back to one package query (0.1 s; 0.4 s once after a sync), `check` and `list` to under
  half a second (8 s in 0.5.3).
- Repo versions are read with pacman's field names untranslated, so a system set to another language reads
  them too. A source build of a Craft app stays a source build when a repo ships its `-bin` package.
- The first read after the update checks the list once, at once.
- Tests: the fake `pacman` answers in pacman's real formats (0.5.3's printed `-Qm` without versions, which
  hid the bug), and cover each way an app can be installed; 216 offline tests.

## 0.5.3 — 2026-11-07

- **Fixed: Craft apps installed from Omarchy's repo could not update.** `gridcraft-bin`, `wordcraft-bin`
  and the other Craft `-bin` packages, when installed from the `[omarchy]` repo, were assumed to be AUR
  packages: Update ran `yay -S` against the stale local sync database, silently reinstalled the same build
  and recorded success. The package kind now comes from the package database: an installed package that is
  not foreign (`pacman -Qm`) is a repo package, so its tile reads `↑ system` and opens Omarchy's update;
  foreign packages keep updating through the AUR helper. Tests cover both cases.

## 0.5.2 — 2026-10-24

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
