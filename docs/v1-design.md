# OmarCraft v1 design

**Status:** approved 2026-10-17. Pairs with `v1-spec.md`; the plan is `approved-plan.md`. Mockups are
`Style.space(380)` wide at the default 12 px monospace, about 46 columns; glyphs are Nerd Font (MDI
range) and render in JetBrainsMono Nerd Font, which is what Omarchy's `monospace` alias resolves to.

## Precedents

Closest UX to copy, in order:

- **Network panel** (`/usr/share/omarchy/shell/plugins/panels/network/Panel.qml`): dynamic list of rows,
  each a `CursorSurface` with a status glyph, name, caption subtext and a right-edge action; one cursor
  shared by mouse and keys; busy model with `actionKind` and a timeout; inline expansion for a password.
  OmarCraft's rows, cursor, busy state and inline confirm are this recipe.
- **Power panel** (`panels/power/Panel.qml`): one-shot `Process` + `StdioCollector` data, refresh on
  open and on a timer that runs only while open, parsers in `Model.js`, `onOpenedChanged` resets the
  cursor. OmarCraft's data path is this.
- **Agents panel** (`plugins/agents/Panel.qml`): `PanelHero` with meta line, `PanelSeparator` +
  `PanelSectionHeader` sections, height capped at `Style.space(640)` with a Flickable that `j/k` scroll,
  bar icon `active` when something needs attention. OmarCraft's layout and cap are this.
- **SystemUpdate widget** (`plugins/bar/widgets/SystemUpdate.qml`): the only first-party widget that
  starts a package-manager run, and it does it in `omarchy-launch-floating-terminal-with-presentation`.
  OmarCraft's jobs are this.
- **OmasteelRGB** (`dreamsgarage/OmasteelRGB`, `Panel.qml`): `Panel` root with `manageIpc: false` and
  its own `IpcHandler` whose verbs return strings; `PanelKeyCatcher` with `blocked` while a field has
  focus; an inline guard before the first destructive write (`requestWrite`), with an urgent-coloured
  *Replace it* and a *Cancel*; a transient `actionStatus` flash and a persistent `lastError` sharing one
  status line; colours from `bar.*` with `Color.*` fallback; `dim = Qt.darker(fg, 1.55)`. OmarCraft's IPC,
  confirm, status line and colour handling are this.

From the marketplace (5,603 listed sources surveyed on 2026-10-17; details in `v1-research.md`
§ Precedent review). No listed plugin installs ArtCraft or any creative suite; the structural neighbours:

- **Agent Helm** (`jinchaofs.agent-helm`, *passed*, no capabilities): INSTALLED / NOT INSTALLED sections,
  missing rows dimmed, whole-row click launches or installs, cursor opens on the most likely row, footer
  key hint, a status script that emits JSON and is bounded with `timeout`. Installs are delegated to an
  Omarchy command (`omarchy-default-agent`), which is why it passed. OmarCraft copies the sections, the
  dimming, the JSON status script and the delegation.
- **Network Spell Book** (`wizard.spellbook`): hero `35 OF 46 INSTALLED`, per-section tallies, state
  encoded by shape (filled dot present, hollow ring absent) as well as colour, package names whitelisted by
  regex before they reach any command. OmarCraft copies the hero, the tallies on the group chips and the
  whitelist.
- **FossFetch** (`davedes.fossfetch`): `✓ Installed` and amber `old → new` chips on every row, a count
  badge on the bar button, an arm-then-confirm step for install, completion from the terminal's exit then
  a re-scan. OmarCraft copies the badge-when-pending and the confirm step. Avoid: its 233 KB `Panel.qml`.
- **System Updater** (`gennaro.updater`) and **Omaplug**: hero with a pending count and a refresh
  control; "a failed check is never reported as up to date", stale rows stay marked stale. OmarCraft
  copies both rules.
- **Okomart** (`b.okomart`, *passed*): work runs in a detached helper so it survives the panel closing;
  a results view after each action. OmarCraft's `job.json` does the first; the status line does the second.

Mistakes seen there and avoided here: literal `sudo pacman` / `yay` strings (even as copy-text) → the
`privilege` and `package-manager` capabilities; curl-pipe installers → `needs-fixes`; unbounded
detection freezing a panel at "Detecting…"; success claimed from an exit code instead of re-reading
state; bypassing Omarchy's pacman guard.

## Architecture

```
Panel.qml                  the item in the bar slot (Panel root, like power/network/agents)
  ├─ BarIconButton         󰏘  left = toggle, right = check, middle = layout
  ├─ KeyboardPanel         anchorItem: button · owner: root · focusTarget: keyCatcher
  │    └─ PanelKeyCatcher → Flickable → Column
  │         ├─ PanelHero                  "ArtCraft" · meta · trailing refresh Button
  │         ├─ status caption             actionStatus | lastError | "Prebuilt AUR packages…"
  │         ├─ PanelSectionHeader INSTALLED  + Repeater AppRow
  │         ├─ PanelSectionHeader AVAILABLE  + Repeater AppRow + group chips + confirm line
  │         └─ key legend (caption, dim)
  ├─ Service { id: craft }  Process bin/omarcraft state → JSON → properties
  │                          FileView job.json (watchChanges) → job property → re-run state on change
  │                          Timer 6 h (always) · Timer 5 s (while opened and job running)
  └─ IpcHandler              open close toggle refresh install update launch layout status
Model.js                   pure: sectioning, group counts, meta line, subtext, glyph table, legend
bin/omarcraft              bash: state (JSON), install/update (terminal job + job.json), launch,
                           check (notifications), refresh, list, setup-menu, remove-menu
```

**Plugin contract.** `Panel { moduleName: "omarcraft.productivity"; ipcTarget: "omarcraft.productivity";
manageIpc: false }`. The Panel root is the slot item, so `open()`, `close()`, `opened` are there for
`Bar.findPanelWidget`, Tab switching and `omarchy-shell shell toggle omarcraft.productivity` without any
BarWidget↔Panel forwarding (the weather plugin's Loader pattern is not needed). `implicitWidth/Height`
come from the button. `KeyboardPanel { contentWidth: panel.fittedContentWidth(Style.space(380));
contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640)) }`.

**Service.** Plain `Item` inside `Panel.qml` (OmasteelRGB and the first-party dropbox panel do the same;
third-party `service` kinds have no supported lookup path). Properties the panel binds to: `apps`,
`counts`, `job`, `lastJob`, `offline`, `catalogAgeSeconds`, `busy`, `lastError`,
`actionStatus`. `refresh()` runs `[pluginDir + "/bin/omarcraft", "state"]` through a `Process` with
`StdioCollector { waitForEnd: true }`; empty or invalid output keeps the last good data and sets
`lastError`. `flash(text)` sets `actionStatus` for 2600 ms. Jobs are started with
`Util.execDetached` through `bar.run(...)` so they outlive the shell; the script, not QML, writes
`job.json`.

**Script.** `bin/omarcraft` keeps the v2 catalog, AUR and installed-state logic (one installed-package
read per run, one AUR RPC call per refresh, 24 h cache, built-in fallback) and gains `state` and `job`.
`state` never touches the network: it reads the cache and reports `catalogAgeSeconds`; a stale cache is
refreshed by a separate detached `refresh` run that pokes the panel when done. Package work is delegated to
Omarchy's own commands, the way Agent Helm and Okomart do, so no `yay`, `pacman -S` or `sudo` string exists
in the plugin:

```bash
# bin/omarcraft job install wordcraft deckcraft   (runs inside the floating presentation terminal)
write_job install wordcraft deckcraft    # job.json {verb, ids, startedAt, pid}
omarchy-pkg-aur-add wordcraft-bin deckcraft-bin; rc=$?   # Omarchy's AUR add: the helper with --needed, password prompt
end_job $rc                              # rm job.json; last-job.json {verb, ids, exit, endedAt}
omarchy-shell -q omarcraft.productivity refresh

# bin/omarcraft job update wordcraft      (or no ids: every app with a newer build)
write_job update wordcraft
yay -S --noconfirm wordcraft-bin; rc=$?   # package-exact, the helper Omarchy ships
end_job $rc; omarchy-shell -q omarcraft.productivity refresh
```

> **Amended 2026-10-17:** updates are package-exact. `job update <ids>` runs
> `yay -S --noconfirm <id>-bin…` (the helper Omarchy ships) for exactly those packages; `omarchy-update-aur-pkgs`
> is no longer used. See `approved-plan.md` decision 6.

## Bar

| Input | Action |
|---|---|
| Left click | toggle the panel |
| Right click | `refresh()` with a forced catalog refresh (`check now`) |
| Middle click | switch layout (tiles ↔ rows), like Power's right click toggling a display setting |
| Hover | no tooltip (`tooltipText: ""`): the panel is the detail view, as Power and Weather do |

- `BarIconButton { text: pending > 0 ? pending + " 󰏘" : "󰏘"; slotSize: pending > 0 ?
  Style.bar.statusSlot * 2 : Style.bar.statusSlot; fontSize: Style.font.caption }`, with
  `openPanelIndicatorWidth: button.glyphPaintedWidth` so the open-panel dot spans the text: Power's
  percentage pattern, used by FossFetch and System Updater as an update badge.
- `active: pending > 0 || (craft.lastJob && craft.lastJob.exit !== 0)` paints it in `bar.urgent`, the
  convention Agents and SystemUpdate use for "needs attention".
- With nothing pending: icon only, no label, like every right-section widget.
- Placement: `defaultSection: "right"`, category Productivity; lands with tray, agents, bluetooth,
  network, audio, monitor, power. Never left (navigation) or centre (status and clock).

## Panel v2 (approved artboard, 2026-10-17 evening)

After using the tiles build the user asked for five changes, mocked up on the canvas
<https://claude.ai/artifact/JCcaokq9mHv7Ju6FVoK74D> and approved from the artboard:

1. **Readable text.** Tile names `Style.font.subtitle` (13 px) demi-bold at full foreground in both
   sections; section labels and hero meta `Style.font.bodySmall` (11 px) bold caps. Available tiles keep
   the name bright and dim only the glyph (60 %) and outline (28 %); installed tiles get the app colour
   as a 12 % fill and a 55 % outline. State is told by the fill, not by greying words.
2. **Logo.** The Nerd Font trend line `󰔵` (U+F0535) in `Color.accent`, hero at `Style.font.display`,
   bar at 13 px with the pending count before it (`2 󰔵`).
3. **No standing status line.** Freshness lives in the refresh button's tooltip
   (`Check the AUR now · list from 2 h ago`); the line under the hero shows only a flash, an error, a
   running or failed job, or offline.
4. **Brighter focus.** The cursor tile: accent outline 2 px, accent fill at 22 %, name in white and bold,
   glyph at full colour.
5. **No key legend.** Removed. Chips carry their key letter as the icon slot (`a Install all · 9`).
6. **Pending updates.** Apps with a newer build leave INSTALLED for an **UPDATES · N** section at the top,
   label in the urgent colour, each tile with an `↑ 0.8.0` badge (pkgrel stripped), and an
   *Update all · u* button in the section header. The hero reads `4 OF 13 INSTALLED · 2 UPDATES`, the
   updates part in the urgent colour. `Enter` on such a tile asks *Update ⏎ / Launch instead / Cancel*.

The sections below describe the layouts as first built; where they differ from the list above, the list
wins.

## Layouts (amended 2026-10-17)

Two layouts share the data, cursor, confirm and job model; `setting("layout", "tiles")` picks one
(`omarchy bar set omarcraft.productivity layout tiles|rows`, the `t` key, or IPC `layout`, stored inline
in `shell.json` the way Power stores `showPercentage`). **Tiles** is the default under evaluation; **rows**
is the first build. The research plan (§ F) decides which ships.

### Tiles: three per line, the app's own colour

```
 󰏘  OmarCraft                                  󰑐
     4 OF 13 INSTALLED

 Prebuilt · nothing compiled · list from 3 h ago
 ────────────────────────────────────────────────
 INSTALLED
 ┌──────────┐ ┌──────────┐ ┌──────────┐
 │    󰈙     │ │    󰐩     │ │    󰓫     │
 │ WordCraft│ │ DeckCraft│ │ GridCraft│
 └──────────┘ └──────────┘ └──────────┘
 ┌──────────┐
 │    󰝚   󰑐│   ← update mark, urgent colour
 │SoundCraft│
 └──────────┘
 ────────────────────────────────────────────────
 AVAILABLE
 ┌──────────┐ ┌──────────┐ ┌──────────┐
 │    󰋩     │ │    󰕠     │ │    󰕧     │   dimmed: glyph at 45 %, name at 70 %
 │PhotoCraft│ │VectorCraf│ │ FilmCraft│
 └──────────┘ └──────────┘ └──────────┘
 … three lines of three …
 [ Install all · 9 ]  [ Creative · 8 ]  [ Office · 1 ]
 h/l j/k move · ⏎ launch, update or install · u update all · a/c/o · r · t rows · esc
```

- `AppTile.qml`: a `CursorSurface` with `bordered: true`; the glyph at `Style.font.display` in the
  app's **own ArtCraft colour** (the official catalog's ink colour for dark or light panels, chosen by
  `Color.popups.background` lightness; the surface colour is the fallback), a 1 px outline in the same
  colour at 45 % (installed) or 18 % (available), the name at `Style.font.bodySmall` in the theme
  foreground. Nothing else on the tile; the version and state are the tooltip (`Model.tileTip`). The
  update mark `󰑐` sits in the tile's top-right corner in the urgent colour.
- Colours come from the catalog, through the cache and the state JSON (`color`, `inkLight`, `inkDark`),
  never from QML constants. Everything structural stays theme-coloured, the
  OmasteelRGB balance (its hero glyph is tinted, its chrome is the theme).
- Grid: `Grid { columns: 3 }`, tile width `(width − 2·6 px) / 3`; cursor movement `Model.gridMove`:
  `h`/`l` step one tile, `j`/`k` jump a line and stop at the section edge, then land on the next
  section's first tile.
- Confirms are one **strip under the status line** (tiles have no room beneath them). Clicking an
  installed tile with a newer build opens `wordcraft-bin 0.7.0-1 → 0.8.0-1 · via the AUR helper · a
  terminal opens and asks your password` with *Update ⏎*, *Launch instead*, *Cancel esc*.

### Rows: one per line with a caption (the first build)

The sections below describe the rows layout; everything about data, bar, keys and jobs applies to both.

### Normal: three installed, one update ready

```
 󰏘  ArtCraft                                  󰑐
     3 OF 13 INSTALLED · 1 UPDATE READY

 Prebuilt AUR packages · list from 2 h ago · Update all
 ────────────────────────────────────────────────
 INSTALLED
 ▸ 󰈙  WordCraft                                󰐊
       Update ready 0.7.0 → 0.8.0
   󰐩  DeckCraft                                󰐊
       0.7.0
   󰓫  GridCraft                                󰐊
       0.7.0
 ────────────────────────────────────────────────
 AVAILABLE
   󰋩  PhotoCraft                               󰇚
       Install 0.9.0 · prebuilt, no compiling
   󰕠  VectorCraft                              󰇚
       Install 0.12.0 · prebuilt, no compiling
   … eight more rows, the Flickable scrolls …

   [ Install all · 10 ]  [ Creative · 9 ]  [ Office · 1 ]
 j/k move · ⏎ launch/install · u update · a all · esc
```

- The hero is `PanelHero { title: "ArtCraft"; meta: Model.metaLine(craft) ; iconComponent: 󰏘 ;
  trailingControl: refresh Button (iconText "󰑐", iconSpinning: craft.busy) }`. `meta` is rendered
  uppercase, caption size, letter-spaced and dimmed by PanelHero itself, so the string stays short.
- The caption line under the hero is the status line: `actionStatus` (flash) or `lastError` (urgent) or
  the standing text. *Update all* is a caption-size `Button` at its right end, visible only when
  `counts.updates > 0`.
- `▸` marks the cursor row (`CursorSurface.hasCursor`); the connected-style `current` fill is not used
  (no row is "current" in the Network sense).
- Available rows are drawn dimmed (glyph and subtext at `Qt.darker(fg, 1.5)`, name at 0.75 opacity), the
  Agent Helm convention, so installed and not-installed read apart by weight before any text is read.
- The row on the update-ready app keeps its launch action; the update is reachable from *Update all* or
  the `u` key only (one Omarchy AUR update run; there is no per-app update).

### Installing

```
 󰏘  ArtCraft                                  󰦖
     INSTALLING WORDCRAFT…

 A terminal is open and may ask for your password.
 ────────────────────────────────────────────────
 AVAILABLE
 ▸ 󰦖  WordCraft                                 ·
       Installing…
   󰐩  DeckCraft                                 󰇚
       Install 0.7.0 · prebuilt, no compiling
```

- The row glyph is `󰦖` with a `RotationAnimator` (800 ms, infinite), the Weather pattern; the hero's
  refresh control spins too.
- Every action is `enabled: !craft.job` at `opacity: enabled ? 1.0 : 0.45` (OmasteelRGB), chips
  included. Launch of already-installed apps stays enabled: it does not touch pacman.
- When `job.json` disappears the Service re-runs `state`; the row moves to INSTALLED with its version,
  the hero returns to the count, the single-app job launches the app.
- `job.json` older than 30 minutes whose `pid` is gone is treated as failed: hero `LAST JOB FAILED`, status
  line `yay exited with status N · see the terminal`, bar icon urgent, until the next successful job or
  a manual refresh after the user fixes it.

### Confirm line (after Enter on an available row or a group chip)

```
   󰋩  PhotoCraft                               󰇚
       photocraft-bin 0.9.0 · a terminal opens and asks your password
       [ Install ⏎ ]  [ Cancel esc ]
```

For a group chip the second line lists the names: `wordcraft-bin, deckcraft-bin, gridcraft-bin · 3
packages · a terminal opens and asks your password`. Only one confirm line is open at a time; moving the
cursor or pressing Esc closes it. The *Install* button is a normal `Button` (not urgent: installing is not
destructive). This is OmasteelRGB's `requestWrite` guard applied to the one action that opens a terminal.

### Nothing installed yet (first run)

```
 󰏘  ArtCraft                                  󰑐
     NOTHING INSTALLED YET

 Prebuilt AUR packages · nothing is compiled
 ────────────────────────────────────────────────
 AVAILABLE
 ▸ 󰋩  PhotoCraft                               󰇚
       Install 0.9.0 · prebuilt, no compiling
   …
   [ Install all · 13 ]  [ Creative · 9 ]  [ Office · 4 ]
```

INSTALLED is hidden; the cursor starts on the first available row.

### Offline

Hero meta `OFFLINE · CACHED LIST`, status line `Could not reach the AUR · showing the list from 3 days
ago`. Rows and actions stay as they are (a job may still succeed; yay fetches on its own and fails
visibly if not).

### Source build present

```
   󰈙  WordCraft                                󰐊
       Source build · updates via omarchy update
```

No update action, never counted in `counts.updates`; `Install all` / groups skip it.

## Row anatomy

`component AppRow: CursorSurface` (Network's `NetworkRow` shape):

```
 ┌ glyph ─┬── name (Style.font.body, elide) ───────────────┬─ action 22px ─┐
 │ 󰈙      │ WordCraft                                      │ 󰐊            │
 │        │ subtext (Style.font.caption, statusColor)     │              │
 └────────┴────────────────────────────────────────────────┴──────────────┘
   margins Style.space(10) · height max(glyph, column, action) + Style.spacing.rowPaddingX
```

- `hasCursor: root.cursorActive && isCursorRow`; mouse hover moves the cursor (`onHovered`), click runs
  the primary action; both go through the one cursor model.
- Glyph: per-app Nerd Font glyph from `Model.GLYPHS`, `Style.font.title`, coloured `statusColor`:
  `bar.urgent` for a failed job on that row, full foreground when installed or busy, `Qt.darker(fg, 1.5)`
  when available.
- Action: `PanelActionButton { iconText; tooltipText; enabled: !craft.job }`. One per row, primary per
  state: launch `󰐊`, install `󰇚`, open `󰖟`. An update-ready row keeps launch; its subtext carries the
  `old → new` and the hero's *Update all* carries the action.
- Subtext collapses to height 0 when empty, as in Network.

## Keyboard

Declared on `PanelKeyCatcher { blocked: false }` (no text fields in v1, so never blocked):

| Key | Action |
|---|---|
| `j` `k` `↓` `↑` | move the cursor over rows (installed → available); first press only activates the cursor, like Power |
| `Enter` | primary action of the cursor row: launch, ask to update, or open the install confirm; with a confirm open: run it |
| `u` | *Update all*: confirm line `Runs Omarchy's AUR update (every AUR package) in a terminal`, then the job |
| `a` | confirm line for *Install all* |
| `c` / `o` | confirm line for *Creative* / *Office* |
| `r` | refresh (forced catalog refresh) |
| `Tab` / `Shift+Tab` | `root.switchPanel(±1)`, the neighbouring bar panel |
| `Esc` | close the confirm line if one is open, else close the panel |

`h`/`l` are consumed by the catcher as horizontal moves and do nothing here; `x` (delete) does nothing in
v1. The legend at the bottom lists only the keys that exist, caption size, dim.

## Components and tokens

| Need | Component / token |
|---|---|
| Popup | `KeyboardPanel` (`qs.Ui`), `fittedContentWidth(Style.space(380))`, cap `Style.space(640)` |
| Header | `PanelHero` with `iconComponent`, `title`, `meta`, `trailingControl` |
| Sections | `PanelSeparator` + `PanelSectionHeader` (uppercase literals) |
| Rows | `CursorSurface`, `Text`, `PanelActionButton`, `PanelToolTip` |
| Chips, confirm buttons, Update all | `Button` (`bordered: true` for chips, `fontSize: Style.font.bodySmall`) |
| Spinner | `Button.iconSpinning` on the hero control; `RotationAnimator` on `󰦖` in rows |
| Colours | `bar.foreground`, `bar.urgent`, `bar.fontFamily`; `Color.accent`, `Color.popups.background`; `dim = Qt.darker(fg, 1.55)`; disabled `opacity 0.45` |
| Type | `Style.font.{caption, bodySmall, body, title, display}` only |
| Spacing | `Style.space(n)`, `Style.spacing.{panelGap, rowPaddingX, popupPadding}` |
| Radius | `Style.cornerRadius`; chips use `Style.cornerRadius > 0 ? Style.space(6) : 0` (square themes stay square) |

No hard-coded colours, no custom fonts, no images; `textFormat: Text.PlainText` on every `Text`.

Glyph table (`Model.GLYPHS`), all MDI codepoints rendered and checked in JetBrainsMono Nerd Font on
2026-10-17 (`fc-match monospace`):

| App | Glyph | Codepoint | App | Glyph | Codepoint |
|---|---|---|---|---|---|
| PhotoCraft | 󰋩 | U+F02E9 | WordCraft | 󰈙 | U+F0219 |
| VectorCraft | 󰕠 | U+F0560 | DeckCraft | 󰐩 | U+F0429 |
| FilmCraft | 󰕧 | U+F0567 | GridCraft | 󰓫 | U+F04EB |
| LightCraft | 󰄀 | U+F0100 | CADCraft | 󰻬 | U+F0EEC |
| PdfCraft | 󰈦 | U+F0226 | SoundCraft | 󰝚 | U+F075A |
| EffectCraft | 󰁨 | U+F0068 | FigCraft | 󰀁 | U+F0001 |
| DesignCraft | 󰏘 | U+F03D8 | | | |

Actions: launch 󰐊 U+F040A · update/refresh 󰑐 U+F0450 · install 󰇚 U+F01DA · open web 󰖟 U+F059F ·
spinner 󰦖 U+F0996. Bar icon: 󰏘 U+F03D8. Any id without an entry falls back to 󰏘.

## Notifications

`bin/omarcraft check --notify` (unchanged logic): one `omarchy-notification-send --app-name OmarCraft`
per distinct set of update-ready apps, `--exec omarchy-shell omarcraft.productivity open`; one per batch of
new apps. The panel's six-hour timer calls it; so does middle click. Nothing else notifies.

## Hot reload and resilience

- Any write under the plugin folder reloads the plugin (150 ms debounce), including `bin/` and `docs/`.
  Widget objects are rebuilt; therefore no state lives only in QML: jobs are in `job.json`, catalog in
  cache, cursor resets on reload (acceptable).
- A job runs in a detached terminal started by `bar.run`; it survives reloads and shell restarts.
- `state` must finish in well under a second (v2 measured 0.73 s with a hundred package queries; one
  read of the installed list brings it under 0.3 s) and never touches the network. The panel never blocks
  on it: it opens with the last data and swaps when the Process ends. The Process is restarted on every
  open (Agent Helm's rule) so a stalled run cannot wedge the panel, and every external call in the script
  carries `--max-time` or `timeout`.
- Files stay small and split: `Panel.qml` (layout and keys), `AppRow.qml` (row component), `Service.qml`
  (data), `Model.js` (pure helpers), `bin/omarcraft`. FossFetch's 233 KB panel is the counter-example.

## Implementation phases

As in `approved-plan.md`: (1) `state` + job files + tests → (2) panel skeleton on the right, read-only → (3) actions
and job state → (4) bar urgency and notifications → (5) polish, acceptance, README, preview. Each phase
is installed on the author's machine and used for a day before the next starts (define → build → use →
iterate, privately).

## Risks specific to the design

| Risk | Mitigation |
|---|---|
| 13 two-line rows exceed the cap | Installed first, cap 640 with scroll, `j/k` keep the cursor in view (`positionViewAtIndex` equivalent on the Flickable) |
| `PanelHero` elides a long meta | Meta strings ≤ 28 chars; checked in phase 2 at the default font size and at `Style.scale` 1.25 |
| Glyph missing in a user's font | All glyphs from the MDI block shipped in every Nerd Font; fallback `󰏘` if `Model.GLYPHS` has no entry |
| Confirm line adds a step | One `Enter`; IPC and group chips for power users; measured in research (install confidence vs. friction) |
