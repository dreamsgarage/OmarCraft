# OmarCraft v1 plan

**Status: approved 2026-10-17** (proposed the same day). Build follows the phases below; the repo stays
private until acceptance passes.

## Goal

An Omarchy bar widget with a native popup panel that shows, at a glance, which ArtCraft Craft apps are
installed, which are not and which have updates, and lets the user launch, install (one or a group) and
update them from that panel, without ever compiling anything. Same look, keys and manners as Omarchy's own
Power, Network and Bluetooth panels and as OmasteelRGB.

## What is wrong with what exists today

| Piece | Why it is not the product |
|---|---|
| **OmarCraft v2** (current `main`): bar icon on the **left after the workspace numbers**, left click opens a plain `omarchy-menu-select` text list | Wrong section: left is navigation (menu, workspaces); popup panels live on the **right** (power, network, audio, bluetooth, tailscale, dropbox). A text list cannot show state at a glance: the author could not find the icon and could not tell installed from available. No keyboard model, no actions in place, no progress state. |
| **Official ArtCraft Launcher** (`artcraft-launcher`, egui window + tray) | Its own window, its own look; installs AppImage/Flatpak outside pacman on Arch; its AUR package is a source build. |
| **AUR bundles** `storytold-suite` / `storytold-office` | Depend on the **source** packages: a 1.5 h Rust build per app, then an unattended `sudo` timeout. This is the trap v1 fell into. |
| **Omarchy app launcher** (`Super + Alt + Space`) | Launches what is installed; says nothing about what is not, and cannot install. |

## Product

**Reference config:** Omarchy 4.0.4, JetBrainsMono Nerd Font (the `monospace` alias), the Tokyo Night
theme as shipped; validated on the author's machine with WordCraft, DeckCraft and GridCraft installed as
`-bin` packages.

**v1 capabilities**

1. A bar icon in the **right** section (`defaultSection: "right"`), category Productivity. Left click opens
   the panel, right click checks the AUR now, middle click switches the layout (amended 2026-10-17).
2. The panel lists every Craft app in two sections, **Installed** and **Available**, each entry
   with the app glyph, name, a one-line status and an action at the right edge (launch, update, install,
   open).
3. Hero meta line that states the whole situation in one short uppercase phrase: `3 OF 13 INSTALLED`,
   `2 UPDATES READY`, `INSTALLING WORDCRAFT…`, `NOTHING INSTALLED YET`, `OFFLINE · CACHED LIST`.
4. Install one app, every missing app, or a named group, each in **one** floating Omarchy terminal and one
   `omarchy-pkg-aur-add` run. Only `<app>-bin` packages. The panel shows the job while it runs and re-reads
   the truth from the package database when it ends.
5. Update: rows with a newer AUR build show `old → new`; `u` or *Update all* runs Omarchy's AUR update in a
   terminal; the bar icon shows the pending count in the urgent colour; one notification per new set.
6. Keyboard-driven like the first-party panels: `j/k` move, `Enter` act on the row, `u` update all,
   ~~`a` install all,~~ `r` refresh, `t` layout, `Tab` neighbouring panel, `Esc` close.
   (Amended 2026-10-17: *Install all* and `a` removed as redundant with the group chips.)
7. Truth over optimism: every state in the panel comes from `pacman -Q` and the AUR, re-read after every
   job. The panel never shows an app as installed because a click happened.
8. Honest copy before anything happens: an available row says `Install 0.9.0 · prebuilt, no compiling`;
   confirming an install says a terminal will open and ask for the password.
9. No side effects on enable or open: enabling the plugin installs nothing, opening the panel installs
   nothing, and no configuration file is written. The optional Omarchy-menu section and keybinding stay
   opt-in commands.
10. IPC for scripts and keybindings: `open`, `close`, `toggle`, `refresh`, `install <ids>`, `update`,
    `launch <id>`, `layout`, `status` (JSON).

**Explicit non-goals for v1**

- Removing apps from the panel (pacman's job; documented command in the README).
- AppImage or Flatpak installs, the official launcher, the source packages.
- ArtCraft Studio in any form (amended 2026-10-17: removed from scope).
- A settings schema in the manifest (no user-tunable options in v1).
- Per-app changelogs, screenshots, ratings, or a search field (13 rows do not need one).

## Architecture

```
Panel.qml            bar-widget entry point: BarIconButton + KeyboardPanel (the slot item itself,
    │                like power/network/agents; no BarWidget↔Panel forwarding)
    ├── Service.qml  one per panel: runs bin/omarcraft state, watches the job file, exposes
    │                plain properties (apps, counts, job, offline, lastError, actionStatus)
    ├── Model.js     pure helpers: grouping, sorting, labels, meta line, key handling tables
    └── bin/omarcraft  bash; the only thing that touches the network, pacman or yay
                       state  → JSON for the panel (catalog + installed + job)
                       install/update → floating Omarchy terminal running one yay -S …
                       launch/check/refresh/list
~/.cache/omarchy/omarcraft/catalog.tsv     catalog + AUR versions, 24 h
~/.local/state/omarchy/omarcraft/job.json  written by the terminal run at start and end
```

- **Why a one-shot `state` command, not a long-lived bridge:** OmasteelRGB needs a resident process because
  HID has state; OmarCraft's state is on disk (pacman db, cache files). One `Process` with a
  `StdioCollector`, re-run on open, on timer and when `job.json` changes, is the Power-panel pattern and
  survives plugin hot-reloads, which rebuild widget objects and would lose a resident process.
- **Why installs run in a terminal, not in a `Process`:** the AUR helper needs a password prompt;
  SystemUpdate does the same with `omarchy-launch-floating-terminal-with-presentation`. The terminal run
  writes `job.json` (`{verb, ids, startedAt, pid}`) first and clears it last; `Service.qml` watches it with
  `FileView { watchChanges: true }`, so the panel shows *Installing WordCraft…* while the terminal is up
  and refreshes the moment it finishes, even if the shell reloaded meanwhile.
- **Why Omarchy's package commands, not the helper directly:** the marketplace survey (`v1-research.md`)
  shows that plugins delegating to `omarchy-pkg-add` / `omarchy-pkg-aur-add` / `omarchy plugin …` pass the
  automated baseline with no capabilities, while a literal `yay -S` or `sudo pacman` string, even as text
  to copy, yields `review-required` with `privilege` + `package-manager` (OmasteelRGB's outcome, approved
  after a maintainer review). Installs use `omarchy-pkg-aur-add <pkgs>` (the same command
  `omarchy-install-and-launch` uses); updates use `omarchy-update-aur-pkgs`, the AUR step of
  `omarchy update`. The cost: no per-app update, and *Update all* upgrades every AUR package, which the
  panel says plainly. Installed state is still read with a local package query, which may or may not
  trip the scanner; either outcome is acceptable.
- **Permissions:** none. The plugin never calls sudo or pkexec; the password prompt belongs to Omarchy's
  command, in a visible terminal.
- **Theme integration:** colours only from `bar.foreground`, `bar.urgent`, `Color.accent`,
  `Color.popups.background`; sizes only from `Style.space()` and `Style.font.*`; follows theme changes live.

## UX

See `v1-design.md` for the mockups. In one line each:

- **Bar:** palette glyph, `slotSize: Style.bar.statusSlot`, no label; `active` (urgent colour) while
  updates are pending; tooltip empty because the panel is the detail view. Right = check, middle = layout.
- **Panel:** `PanelHero` (glyph, "ArtCraft", meta line, refresh control) → caption line → INSTALLED rows →
  AVAILABLE rows + group chips → key legend. Width `Style.space(380)`, height fitted and
  capped at `Style.space(640)` with a scrolling Flickable, like Agents.
- **Rows:** `CursorSurface` with glyph, name, caption subtext and a `PanelActionButton` at the right edge
  (the Network/Bluetooth recipe). One cursor for mouse and keys.
- **Confirm:** `Enter` on an available row expands an inline line naming the package and the terminal, with
  Install and Cancel; the same for group chips, listing what will be installed. Nothing modal.
- **Busy:** the row glyph spins (`Button.iconSpinning` / `RotationAnimator` on `󰦖`), actions are disabled
  at 0.45 opacity, the hero says what is running.

## Safety

- Only `<id>-bin` packages, ever. The script refuses any other package name.
- The confirm line is the only place a job starts from the panel; IPC `install` is explicit by nature.
- Nothing under `/usr/share/omarchy/` is read for writing, nothing in `~/.config` is written without the
  opt-in commands.
- Catalog and AUR data are read over HTTPS from `raw.githubusercontent.com` and `aur.archlinux.org` only,
  cached 24 h, with a built-in fallback list.

## Repo and install shape

Unchanged from today: `manifest.json` and QML at the root, `bin/omarcraft`, `tests/`, `docs/`,
`preview.png`. `omarchy plugin add https://github.com/dreamsgarage/OmarCraft.git --enable` places the
icon on the right. `manifest.json` changes: `entryPoints.barWidget: "Panel.qml"`, `defaultSection: "right"`,
`category: "Productivity"`, `displayName: "ArtCraft apps"`.

## Implementation phases

Each phase is independently testable; the next does not start before the previous passes.

0. **Docs approved.** This plan, the spec, the design, the acceptance criteria.
1. **`bin/omarcraft state`** prints the JSON in the spec; `job.json` written around every terminal run;
   offline tests cover both. The v2 picker keeps working meanwhile.
2. **Panel skeleton:** manifest moves to `Panel.qml`, right section; hero + sections + rows rendered from
   `state`; open/close/toggle, Tab, Esc; no actions yet. Validate with `omarchy plugin validate`, screenshot.
3. **Actions:** launch, install with inline confirm, update, group chips; job state from `job.json`;
   spinner, disabled actions, re-read on finish.
4. **Bar and notifications:** urgent icon, six-hourly check, one notification per set, middle-click check (amended 2026-10-17: right-click checks, middle-click switches the layout).
5. **Polish and acceptance:** key legend, empty/offline states, `preview.png`, README rewrite,
   `v1-acceptance.md` filled with results. Remove `bin/omarcraft menu` (the text picker) if the decision
   below stands.

## Validation on this machine

Three `-bin` apps are installed; ten are available; there is no real update pending, so the update state is
validated by the cache trick in `docs/Testing.md` § 6 and, when it happens, by a real AUR bump.

## Risks

| Risk | Mitigation |
|---|---|
| Hot reload while a job runs loses panel state | State lives in `job.json` and pacman; the panel re-reads on reload |
| A `-bin` package lags an ArtCraft release | The panel shows the AUR version, which is what installs; README says so |
| The AUR RPC is down | Cached catalog (24 h) and built-in list; hero says `OFFLINE · CACHED LIST`; installs still work through yay's own fetch |
| Group names do not match how users think | Groups are data in `Model.js`; the research plan decides the names before release |
| Shell IPC timeout ("not responding") right after `plugin add` | Documented; `omarchy plugin enable` finishes placement |
| Marketplace scanner flags the read-only package query | Accept `review-required` (OmasteelRGB precedent); the submission notes say no privileged call exists |
| `omarchy-update-aur-pkgs` upgrades more than the Craft apps | Said in the confirm line and the README; it is the same step `omarchy update` runs |

## Decisions (approved 2026-10-17)

1. **Panel replaces the text picker.** `bin/omarcraft menu` is removed; the keybinding and IPC open the
   panel (`omarchy-shell omarcraft.productivity toggle`).
2. **Bar icon in the right section.** Icon only while nothing is pending; a count badge in the urgent
   colour (`2 󰏘`) while updates are pending, like FossFetch and System Updater and Power's percentage.
   No permanent `3/13` label: the hero carries the count.
3. **Inline confirm before every install and before Update all** (one extra `Enter`), naming the
   packages and the terminal. Launch needs no confirm.
4. **Groups shown as chips under Available: ~~*Install all*,~~ *Creative*, *Office*.** Proposed mapping:
   Office = WordCraft, DeckCraft, GridCraft, PdfCraft; Creative = the other nine. Upstream's *Classic/New*
   stays in the data but is not shown. The research plan's survey confirms or changes the mapping before
   release.
5. ~~**Studio stays a web app**, one row in its own section, right click on the bar icon as the shortcut.~~

   > **Amended 2026-10-17 (user decision):** ArtCraft Studio is removed from the plugin altogether; it is
   > another category of software from the Craft apps. The bar's right click checks the AUR, middle click
   > switches the layout.
6. ~~**Package work through Omarchy's commands** (`omarchy-pkg-aur-add`, `omarchy-update-aur-pkgs`),
   aiming for a *passed* baseline. Consequence: *Update all* is Omarchy's AUR update (every AUR package),
   no per-app update.~~

   > **Amended 2026-10-17 (user decision, after using the panel):** updates are **package-exact**.
   > `omarcraft update [id…]` calls the AUR helper Omarchy ships (`yay -S --noconfirm <id>-bin…`) for
   > exactly those packages; clicking an installed app with a newer build asks to update that app.
   > Installs keep going through `omarchy-pkg-aur-add`. The marketplace outcome is therefore
   > `review-required` (`package-manager`), the path OmasteelRGB took and was approved on.
7. **Two layouts under evaluation, switchable** (added 2026-10-17): *tiles* (three per line, glyph in the
   app's own ArtCraft colour, name only; default) and *rows* (one per line with a caption).
   `omarchy bar set omarcraft.productivity layout tiles|rows`, the `t` key, or IPC `layout`. The loser is
   removed before release; `v1-research.md` § F says how the choice is made.

8. **Remove from the panel** (added 2026-10-18, user decision from canvas Round 4, option A): right-click
   or `x` on an installed tile opens the same confirm strip; the job runs Omarchy's `omarchy-pkg-drop
   <id>-bin`. Apps installed some other way are not offered. No new marketplace capability: package
   management is already in the report.

## Out of scope until asked

Remove-from-panel, AppImage path, settings schema, a search field, per-app pages, theme-coloured glyphs,
a compact one-line row variant, Flatpak detection.
