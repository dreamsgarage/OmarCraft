# OmarCraft v1 spec

- **Status:** approved 2026-10-17 (see `approved-plan.md`)
- **Plugin id:** `omarcraft.productivity`
- **Name:** OmarCraft
- **Kinds:** `bar-widget` (entry point `Panel.qml`)
- **Default bar section:** right
- **Target:** Omarchy 4 / Quattro (validated against 4.0.4)
- **Precedent:** OmasteelRGB (`steelseries.keyboard`, Entangled Forge, approved) for structure, docs and
  manners; first-party Power, Network and Bluetooth panels for the panel UI.

## Goal

From one bar icon, see the state of all thirteen ArtCraft Craft apps and act on it: launch, install, update.
Prebuilt packages only. Native Omarchy panel, keyboard-driven, theme-coloured, honest about what it is about
to do.

## Definitions

These words are used exactly like this everywhere (UI, docs, code):

| Word | Meaning | Source of truth |
|---|---|---|
| **Installed** | `pacman -Q <id>-bin` or `pacman -Q <id>` succeeds | pacman |
| **Available** | not installed, and an AUR package `<id>-bin` exists | AUR RPC (cached) |
| **Update ready** | installed as `<id>-bin` and the AUR version is newer (`vercmp`) | pacman + AUR |
| **Source build** | installed as `<id>` (compiled from the AUR source package, e.g. through `storytold-office`) | pacman |
| **Not packaged yet** | in the catalog but no `<id>-bin` in the AUR | AUR RPC |
| **New** | an id that was not in the catalog the last time the user looked | state file `seen` |
| **Job** | one terminal run of `yay -S …` started by OmarCraft | `job.json` |
| **Catalog** | the 13 apps: id, name, tagline, group | storytold/craft-launcher `catalog.rs`, cached 24 h, built-in fallback |
| **Group** | Office = WordCraft, DeckCraft, GridCraft, PdfCraft; Creative = the other nine. Upstream's Classic/New kept as data, not shown | `Model.js` (to be confirmed by research) |

A source build counts as installed and launches; it is never updated by OmarCraft (that would compile) and
its row says `Source build · updates via omarchy update`.

## v1 capabilities

1. **Bar icon**, right section, `slotSize: Style.bar.statusSlot`, palette glyph `󰏘`. Icon only while
   nothing is pending; with updates pending it shows the count before the glyph (`2 󰏘`) in the urgent
   colour, Power's label pattern; urgent also after a failed job. Left = panel, right = Studio, middle =
   check now.
2. **Panel** anchored to the icon, width `Style.space(380)`, height fitted to content and capped at
   `Style.space(640)` with scrolling. Sections in this order: hero, status caption, INSTALLED, AVAILABLE
   (rows, then group chips), STUDIO, key legend. Empty sections are hidden.
3. **Hero meta line**, uppercase, one of: `N OF 13 INSTALLED` · `N UPDATES READY` · `INSTALLING X…` /
   `UPDATING N APPS…` · `NOTHING INSTALLED YET` · `OFFLINE · CACHED LIST` · `LAST JOB FAILED`. Priority
   in that order from the right (failure beats offline beats job beats updates beats count).
4. **Rows**: glyph, name, caption subtext, right-edge action. Subtext per state: `0.7.0` ·
   `Update ready 0.7.0 → 0.8.0` · `Install 0.9.0 · prebuilt, no compiling` · `New · install 0.6.0` ·
   `Installing…` · `Source build · updates via omarchy update`. Actions: launch `󰐊`, update `󰑐`, install
   `󰇚`, open `󰖟`.
5. **Launch**: Enter or the action on an installed row runs `omarchy-launch-or-focus <id> …`; an already
   open window is focused, not duplicated.
6. **Install**: Enter or the action on an available row expands an inline confirm line
   (`wordcraft-bin 0.7.0 · a terminal opens and asks your password`) with *Install* and *Cancel*. Confirm
   starts one job: `omarchy-pkg-aur-add <id>-bin` (Omarchy's own AUR add command) inside
   `omarchy-launch-floating-terminal-with-presentation`, then launches the app when the job succeeds
   (single app only).
7. **Group install**: chips *Install all (N)*, *Creative (N)*, *Office (N)* under the available rows, each
   showing how many are missing; hidden when nothing is missing. Same inline confirm, listing the names.
   One job, every package on one `omarchy-pkg-aur-add` line, no launch afterwards.
8. **Update** (amended 2026-10-17): package-exact. `Enter` or a click on an installed app with a newer
   build asks to update that app (*Update ⏎* / *Launch instead* / *Cancel*); `u` or *Update all* asks
   for every app with a newer build. The job runs `yay -S --noconfirm <id>-bin…`, the helper Omarchy
   ships and uses itself, inside Omarchy's floating terminal. Installs still go through
   `omarchy-pkg-aur-add`. The plugin contains no `sudo` or `pkexec`.
9. **Job tracking**: the terminal run writes `job.json` on start and removes it on exit (success or
   failure, with the exit status kept in `last-job.json`). While it exists, the involved rows show a
   spinning glyph and `Installing…`, every action is disabled, the hero says what runs. When it goes, the
   panel re-reads state within one second. A job older than 30 minutes with no terminal alive is shown
   as failed, not as running.
10. **Checks and notifications**: on open, every six hours, and on middle click, the panel re-runs
    `state`, which reads only local files and finishes in under 0.3 s. A catalog older than 24 h (or a
    middle click / `r`) starts a detached `refresh` that fetches the catalog and AUR versions with
    bounded timeouts and pokes the panel when done; a failed refresh keeps the old data and marks it
    stale (`OFFLINE · CACHED LIST`), never "up to date". When the set of update-ready apps changes and is
    non-empty, one `omarchy-notification-send` with the names; clicking it opens the panel. New apps get
    the same, once.
11. **Studio**: one row, `ArtCraft Studio · web app · needs an ArtCraft account`, action opens it
    (`omarchy-launch-or-focus-webapp`); first use creates the web app with `omarchy-webapp-install`.
12. **Keyboard** (PanelKeyCatcher): `j/k` `↑/↓` move the cursor over rows; `Enter` primary action of the
    row; `u` update all; `a` install all; `c` / `o` install Creative / Office; `s` Studio; `r` refresh;
    `Tab`/`Shift+Tab` neighbouring panel; `Esc` cancels an open confirm line, otherwise closes.
13. **IPC** (`omarchy-shell omarcraft.productivity <verb>`): `open`, `close`, `toggle`, `refresh`,
    `install <id…>`, `update`, `launch <id>`, `studio`, `status` (returns the state JSON). Bad input
    returns a message string, never throws. IPC installs skip the inline confirm; a script is explicit.
14. **Opt-in extras, unchanged**: `bin/omarcraft setup-menu` / `remove-menu` for an Omarchy-menu section;
    a documented keybinding line (`omarchy-shell omarcraft.productivity toggle`).
15. **CLI**: `bin/omarcraft state|list|check|refresh|install|update|launch|studio|setup-menu|remove-menu`.
    The v2 `menu` picker is removed.

## Non-goals for v1

Removing apps; AppImage/Flatpak; the official launcher; building Studio; settings schema; search field;
per-app detail pages; remembering window positions; anything that writes outside the plugin's cache and
state directories without an opt-in command.

## Behaviour that must hold

- Enabling the plugin installs nothing and writes no configuration. Opening the panel installs nothing.
- Only `<id>-bin` package names ever reach a package command; the script validates ids against the catalog
  and the regex `^[a-z0-9-]+$` and refuses anything else.
- No sudo, no pkexec in the plugin. Installs go through `omarchy-pkg-aur-add`; updates call the AUR
  helper Omarchy ships, for the named `-bin` packages only; both prompt for the password in a visible
  terminal. Installed state is read, never written, by the plugin.
- State shown is state read: after every job the panel shows pacman's answer, never the click's intent.
- Every string in the panel is short enough not to elide at `Style.space(380)` with the hero's uppercase
  meta style (keep meta ≤ 28 characters).

## State JSON (`bin/omarcraft state`)

```json
{
  "generatedAt": "2026-10-17T18:40:12-03:00",
  "catalogAgeSeconds": 7200,
  "offline": false,
  "counts": { "installed": 3, "available": 10, "updates": 1, "unpackaged": 0 },
  "job": null,
  "lastJob": { "verb": "install", "ids": ["wordcraft"], "exit": 0, "endedAt": "…" },
  "studio": { "installed": true },
  "groups": { "office": ["wordcraft", "deckcraft", "gridcraft", "pdfcraft"] },
  "apps": [
    {
      "id": "wordcraft", "name": "WordCraft", "tagline": "Writing and document design",
      "group": "office", "upstreamGroup": "new", "glyph": "󰈙",
      "aurVersion": "0.8.0-1", "installed": true, "installedVersion": "0.7.0-1",
      "source": "bin", "updateReady": true, "new": false,
      "desktopId": "ai.storyteller.wordcraft"
    }
  ]
}
```

`job`, when present: `{ "verb": "install" | "update", "ids": [...], "startedAt": "…", "pid": 12345 }`.
Apps are listed in catalog order; the panel sorts them into sections.

## Decision summary

1. Native `KeyboardPanel` replaces the `omarchy-menu-select` picker; the picker is removed.
2. Right bar section; icon only, with a count badge in the urgent colour only while updates are pending.
3. Inline confirm before every panel-started install and before *Update all*; none for launch.
4. Groups Office / Creative shown as chips with counts; names confirmed by the research plan before
   release; upstream Classic/New not shown.
5. One-shot `state` command (local only) and a watched `job.json`, not a resident bridge; jobs in
   Omarchy's floating presentation terminal.
6. Installs through `omarchy-pkg-aur-add`; updates package-exact through the AUR helper Omarchy ships
   (amended 2026-10-17; marketplace path `review-required`).
7. Studio remains a web app.
8. Two layouts, tiles (default) and rows, switchable; the app's own ArtCraft colour on tiles (amended
   2026-10-17).
