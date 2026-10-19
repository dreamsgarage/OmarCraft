# OmarCraft

Productivity tools from the Omarchy bar: the ArtCraft Craft apps and more.

![OmarCraft panel](preview.png)

OmarCraft is for people who come to Omarchy for office, design and creative work, not only for code: simple,
powerful desktop tools behind one bar icon, with a native Omarchy panel that shows what is installed, what
is not, what has a newer build, and one action per tool to launch, install, update or remove. Every tool is
a prebuilt package, a `-bin` from the AUR or a package from the Arch repos, installed through Omarchy's own
package commands, so pacman owns it and nothing is ever compiled.

It carries the thirteen [ArtCraft](https://getartcraft.com) Craft apps (PhotoCraft, VectorCraft, FilmCraft,
LightCraft, PdfCraft, EffectCraft, DesignCraft, WordCraft, DeckCraft, GridCraft, CADCraft, SoundCraft,
FigCraft) in the groups Creative and Office, plus four tools that do what ArtCraft does not (see *Beyond
ArtCraft*), seventeen in all.

Plugin id `omarcraft.productivity`. MIT licensed. **Unofficial**: OmarCraft is not made by or affiliated with
Storyteller, the makers of ArtCraft, nor with the projects behind the other tools. The names are theirs.

## Beyond ArtCraft

A tool gets a tile when it:

1. has a stable desktop release (tagged, not a release candidate or a source-only build),
2. ships prebuilt, in the Arch repos or as an AUR `<id>-bin`, with a desktop entry,
3. comes from a maintained upstream under an open-source licence,
4. stays near **150 MiB idle in one native process**, like the Craft apps (70–90 MiB measured),
5. does something an office, design or creative user wants on the desktop.

A tool that adds a capability ArtCraft lacks may exceed item 4; its row says so. Today:

| Tool | Group | Package | What it is | Idle memory (measured) |
|---|---|---|---|---|
| [Typesetter](https://codeberg.org/haydn/typesetter) | Office | `typesetter` (Arch repos) | A focused [Typst](https://typst.app) editor with a live preview | 57 MiB, 1 process |
| [KolourPaint](https://apps.kde.org/kolourpaint/) | Creative | `kolourpaint` (Arch repos) | Quick paint: screenshot edits, diagrams, pixel art | 66 MiB, 1 process |
| [Memospot](https://memospot.github.io) | Notes & tasks | `memospot-bin` | [Memos](https://usememos.com), the notes and journal service, as a desktop app | 371 MiB, 4 processes · **exception**: web-based |
| [Vikunja](https://vikunja.io) | Notes & tasks | `vikunja-desktop-bin`, `vikunja-bin` | Tasks, kanban, Gantt and lists, with its own local server | ~400 MiB while open, 0 when closed · **exception**: Electron app plus server |

Tools from the Arch repos update with the system: their badge reads `↑ system` and opens Omarchy's
update, because updating one repo package on its own is a partial upgrade.

**Vikunja's server.** The Vikunja app is a client. OmarCraft installs the server too and runs it under your
user, listening on `127.0.0.1:3456` only, while the app runs: it starts when you open Vikunja (from the
panel or the app launcher) and stops when you close Vikunja's window (or choose *Quit* in its tray menu):
OmarCraft quits the app instead of letting it hide in the tray. On the first launch OmarCraft also hides
Vikunja's tray icon, adding it once to the bar's tray Hide list (`~/.config/omarchy/shell.json`); to see
it again, right-click the tray's `<` arrow and choose *Show*. The data and the server's config are in `~/.local/share/omarcraft/vikunja` and stay
when Vikunja is removed. The first time, enter `http://127.0.0.1:3456` when the app asks for a server and
register a local account. The package's own system service is not used.

To propose one, open an issue with the package name and the upstream. Tools that only exist as a server or
a command-line program (Typst's compiler, the Memos server itself) are not tiles: nothing to launch.

## Requirements

- Omarchy 4 (Quattro). Nothing else: the plugin uses Omarchy's bundled tools (`curl`, `jq`, the AUR
  helper behind `omarchy-pkg-aur-add`) and no Python or extra packages.

## Install

```bash
omarchy plugin add https://github.com/dreamsgarage/OmarCraft.git --enable
```

The palette icon lands in the right section of the bar, with the other panels. Enabling installs no app
and writes no configuration; nothing happens until you pick something in the panel. If the add prints
"omarchy-shell is not responding", the shell was still reloading; `omarchy plugin enable
omarcraft.productivity` finishes the placement. Updates: `omarchy plugin update omarcraft.productivity`.

## The panel

Left-click the icon (or `Tab` from a neighbouring panel). Two layouts, switched live with `t` or
`omarchy bar set omarcraft.productivity layout tiles|rows`:

- **Tiles** (default): three apps per line, each tile the app's glyph in its own ArtCraft colour over its
  name. Installed tiles have a tinted fill, available ones only an outline; the name stays readable in
  both. Hover for the version and state. The tile under the cursor takes the accent outline and fill.
- **Rows**: one app per line with a caption (`0.7.0-1`, `Update ready 0.7.0-1 → 0.8.0-1`, `Install
  0.9.0-1 · prebuilt, no compiling`) and one action at the right edge.

In both:

- **Hero.** The rocket logo, then the one-line situation: `4 OF 13 INSTALLED · 2 UPDATES` (the
  updates part in the urgent colour), `INSTALLING WORDCRAFT…`, `NOTHING INSTALLED YET`, `OFFLINE · CACHED
  LIST`, `LAST JOB FAILED`. The circular arrow at the right checks the AUR now; its tooltip says how old
  the list is. A line under the hero appears only while something needs saying (a job, an error, offline).
- **UPDATES · N.** Shown only when newer builds exist: those apps move here from INSTALLED, each with an
  `↑ 0.8.0` badge, next to an *Update all · u* button. `Enter` on one asks: *Update ⏎* (that package),
  *Launch instead*, *Cancel*.
- **INSTALLED · N.** Your apps that are up to date. `Enter` or a click launches one; if its window is
  already open it is focused instead.
- **AVAILABLE · N.** The rest. `Enter` or a click opens a one-line confirm under the hero (`Install
  PhotoCraft 0.9.0 · a terminal will open and ask for your password`); `Enter` again runs it, `Esc`
  cancels. In the rows layout the confirm sits under the row and a newly added Craft app shows `New`.
- **Group chips** under the available apps, each with its key: *c Creative · N*, *o Office · N*
  (Office = WordCraft, DeckCraft, GridCraft, PdfCraft), *n Notes · N* (Memospot), counting the apps you
  don't have. Same confirm, naming every app; one terminal, one run. A chip disappears when its group is
  complete.
- **Remove.** Right-click an installed tile, or press `x` with the cursor on it: `Remove PhotoCraft 0.9.0 ·
  a terminal will open and ask for your password · your files stay`, then *Remove ⏎* or *Cancel*. The job
  is Omarchy's `omarchy pkg drop photocraft-bin`; when the terminal closes the tile is back under
  AVAILABLE. Apps installed some other way are not offered.
While a job runs the row shows a spinner and `Installing…`, the hero says what runs, every install action
is greyed out, and the terminal is the place to type your password. When the terminal finishes the panel
re-reads the package database: what you see is what is installed, never what a click intended.

**Keys:** `h`/`l` `j`/`k` move (tiles: one tile, one line) · `Enter` launch, update or install · `u` Update
all · `x` remove the app under the cursor · `c` / `o` / `n` install the missing Creative / Office / Notes
tools · `r` check the AUR · `t` switch layout ·
`Tab` neighbouring panel · `Esc` cancel or close.

**Bar icon:** a rocket (󰓄), left = panel · right = check the AUR now · middle = switch layout. It turns to
the urgent colour while updates are pending, with the count in front (`2 󰓄`), when a Craft app appeared in
the catalog since you last opened the panel, and after a job that failed.

## Updates

Every six hours, and whenever you press `r` or right-click the icon, OmarCraft compares your installed
`-bin` packages with the AUR. Newer builds show on the tiles or rows and on the icon; the six-hourly check
also sends one desktop notification per new set, which opens the panel. If the AUR cannot be reached the
hero says `OFFLINE · CACHED LIST` and the panel retries on its own every ten minutes. Updates are package-exact: `Enter` on the app updates that
one, *Update all* (`u`) every app with a newer build, each through the AUR helper Omarchy ships, in a
floating terminal that asks for your password. `omarchy update` updates them too. "Newer" means a newer
AUR build exists, which can trail an ArtCraft release by a day or so.

## Apps installed some other way

OmarCraft recognises apps it did not install and never removes or replaces anything on its own.

| How the app got there | In the panel |
|---|---|
| `<app>-bin` from the AUR by any means | Installed; launches; counted for updates |
| Source build (`<app>`, e.g. via `storytold-office` or `storytold-suite`) | Installed; launches; reads `Source build · updates via omarchy update`; never in OmarCraft's update checks (updating it would compile again) |
| AppImage or Flatpak from the official ArtCraft Launcher | Not detected; the panel offers the `-bin` package. Remove the other copy first if you want one |

To move a source build to the prebuilt package, remove it and install the `-bin` one with Omarchy's
command; the bundle packages stay satisfied because each `-bin` package provides the app name:

```bash
omarchy pkg drop wordcraft && omarchy-pkg-aur-add wordcraft-bin
```

## Command line and IPC

Everything the panel does is a subcommand of one script, usable from scripts and keybindings:

```
P=~/.config/omarchy/plugins/omarcraft.productivity/bin/omarcraft
$P state                      # the JSON the panel reads (local files only)
$P list                       # catalog with install state
$P launch <id>                # e.g. photocraft
$P install <id>...            # floating terminal, one run
$P install-group all|creative|office|notes
$P remove <id>...             # floating terminal, Omarchy's pkg drop; your files stay
$P update [id...]             # the named apps, or every app with a newer build; floating terminal
$P check [--notify]           # pending updates; exit 0 if any
$P refresh [-f]               # fetch catalog and AUR versions now
```

```
omarchy-shell omarcraft.productivity open | close | toggle | refresh
omarchy-shell omarcraft.productivity launch <id>
omarchy-shell omarcraft.productivity install "<id> <id>"      # no confirm: a script is explicit
omarchy-shell omarcraft.productivity update "<id> <id>"      # or "" for every app with a newer build
omarchy-shell omarcraft.productivity remove "<id> <id>"      # apps installed as -bin packages
omarchy-shell omarcraft.productivity layout tiles|rows
omarchy-shell omarcraft.productivity status                   # JSON
```

A keybinding, if you want one (`Super + Alt + A` is free on a default Omarchy 4 install), in
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + A", "OmarCraft", "omarchy-shell omarcraft.productivity toggle")
```

An ArtCraft section in the Omarchy menu (`Super + Alt + Space` root and *Install → ArtCraft*), opt-in and
reversible: `$P setup-menu` / `$P remove-menu`. It writes one marked block into
`~/.config/omarchy/extensions/omarchy-menu.jsonc` and nothing else.

## Remove

```bash
omarchy plugin remove omarcraft.productivity
```

Apps stay installed; remove them from the panel first if you want (right-click a tile), or like any
package, e.g. `omarchy pkg drop photocraft-bin`. Optional clean-up:

```bash
rm -rf ~/.cache/omarchy/omarcraft ~/.local/state/omarchy/omarcraft   # catalog cache, job records, seen list
```

plus `$P remove-menu` before removing if you ran `setup-menu`, and the keybinding line if you added it.

## Safety

- Only `<id>-bin` package names, checked against the catalog and a strict pattern, ever reach a package
  command. The plugin does not use sudo or pkexec. Installs go through Omarchy's `omarchy-pkg-aur-add`;
  updates call the AUR helper Omarchy ships for exactly the named packages; removals go through Omarchy's
  `omarchy-pkg-drop`, which takes the package and the dependencies nothing else needs, never your
  documents or settings. All three run in a visible Omarchy terminal that asks for your password itself.
- Network use: the app catalog from `raw.githubusercontent.com` (storytold/craft-launcher) and versions
  from the AUR RPC, every 24 hours, with bounded timeouts; a failed check keeps the old list and says
  `OFFLINE`, never "up to date". The panel itself never waits on the network.
- Files: `~/.cache/omarchy/omarcraft/` (catalog) and `~/.local/state/omarchy/omarcraft/` (job records,
  seen apps, notification state). Nothing under `~/.config` without the opt-in commands.

## How it works

| Path | Role |
|---|---|
| `manifest.json` | `kinds: ["bar-widget"]`, entry point `Panel.qml`, default section right |
| `Panel.qml` | Bar icon, `KeyboardPanel`, both layouts, cursor, confirm, keys, IPC |
| `AppTile.qml` | One tile: glyph in the app's ArtCraft colour over its name |
| `AppRow.qml` | One row: glyph · name · subtext · right-edge action, Network-panel style |
| `Service.qml` | Runs `bin/omarcraft state`, watches `job.json`, six-hourly check |
| `Model.js` | Pure helpers: sections, meta line, subtexts, confirm text |
| `bin/omarcraft` | Catalog, installed state, jobs, launch, the opt-in menu section |
| `tests/` | `bash tests/run.sh`: offline, every external command stubbed |
| `docs/` | Approved plan, spec, design, acceptance, research, testing and publish guides |

A job is one floating Omarchy terminal running `bin/omarcraft job install …` or `job update`: it writes
`job.json`, calls the Omarchy command, records `last-job.json` and pokes the panel. The panel never claims
success from an exit code; it re-reads the package database.

## Development

```bash
bash tests/run.sh
omarchy plugin validate .
rsync -a --delete --exclude .git ./ ~/.config/omarchy/plugins/omarcraft.productivity/   # or push + omarchy plugin update
omarchy restart shell        # after changing a .qml (never "refresh shell": that resets shell.json)
```

Manual test plan: [docs/Testing.md](docs/Testing.md). Shell log: `journalctl --user _COMM=quickshell`.
Release and marketplace steps: [docs/Publish-Guide.md](docs/Publish-Guide.md). Changes:
[CHANGELOG.md](CHANGELOG.md).

## Credits and license

MIT, see [LICENSE](LICENSE). By Entangled Forge. The Craft apps and the app catalog are by
[Storyteller](https://github.com/storytold), as are the per-app colours, taken from their launcher's catalog;
Memos is by [usememos](https://github.com/usememos/memos) and Memospot by
[memospot](https://github.com/memospot/memospot) (colours from its icon); the `-bin` packages are maintained
by their AUR packagers. The panel follows Omarchy's first-party Network
and Power panels and Entangled Forge's OmasteelRGB.
