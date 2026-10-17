# OmarCraft

The ArtCraft Craft apps, from the Omarchy bar.

![OmarCraft panel](preview.png)

[ArtCraft](https://getartcraft.com) ships thirteen creative and office apps (PhotoCraft, VectorCraft,
FilmCraft, LightCraft, PdfCraft, EffectCraft, DesignCraft, WordCraft, DeckCraft, GridCraft, CADCraft,
SoundCraft, FigCraft) plus ArtCraft Studio for AI image and video. OmarCraft puts them behind one bar icon
with a native Omarchy panel: what is installed, what is not, what has a newer build, and one action per
row to launch, install or update. Installs use the prebuilt `-bin` packages from the AUR through Omarchy's
own package commands, so pacman owns every app and nothing is ever compiled.

Plugin id `omarcraft.productivity`. MIT licensed. **Unofficial**: OmarCraft is not made by or affiliated with
Storyteller, the makers of ArtCraft. ArtCraft and the app names are theirs.

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

Left-click the icon (or `Tab` from a neighbouring panel).

- **Hero.** The one-line situation: `3 OF 13 INSTALLED`, `2 UPDATES READY`, `INSTALLING WORDCRAFT…`,
  `NOTHING INSTALLED YET`, `OFFLINE · CACHED LIST`, `LAST JOB FAILED`. The circular arrow at the right
  checks the AUR now.
- **INSTALLED.** Your apps with their version. `Enter` or the ▶ action launches one; if its window is
  already open it is focused instead. A row with a newer build reads `Update ready 0.7.0-1 → 0.8.0-1`
  and *Update all* appears in the status line.
- **AVAILABLE.** The rest, dimmed, with `Install 0.9.0-1 · prebuilt, no compiling`. `Enter` or the
  download action opens a one-line confirm under the row naming the exact package and that a terminal
  will open and ask for your password; `Enter` again runs it, `Esc` cancels. A newly added Craft app shows
  `New`.
- **Group chips** under the available rows: *Install all · N*, *Creative · N*, *Office · N* (Office =
  WordCraft, DeckCraft, GridCraft, PdfCraft), each counting the apps you don't have. Same confirm, listing
  every package; one terminal, one run.
- **STUDIO.** ArtCraft Studio as an Omarchy web app (it has no Linux build; only a long source build). It
  needs an ArtCraft account; generation runs in their cloud. First use adds it to the app launcher.

While a job runs the row shows a spinner and `Installing…`, the hero says what runs, every install action
is greyed out, and the terminal is the place to type your password. When the terminal finishes the panel
re-reads the package database: what you see is what is installed, never what a click intended.

**Keys:** `j`/`k` move · `Enter` launch or install · `u` Update all · `a` / `c` / `o` install all /
Creative / Office · `s` Studio · `r` check the AUR · `Tab` neighbouring panel · `Esc` cancel or close.

**Bar icon:** left = panel · right = ArtCraft Studio · middle = check now. While updates are pending the
icon turns to the urgent colour and shows the count (`2 󰏘`); it also turns urgent after a job that failed.

## Updates

Every six hours, and whenever you press `r` or middle-click, OmarCraft compares your installed `-bin`
packages with the AUR. Newer builds show in the rows, on the icon, and once per new set as a desktop
notification that opens the panel. *Update all* runs Omarchy's own AUR update
(`omarchy-update-aur-pkgs`, the step `omarchy update` runs), which upgrades every AUR package on the
system, not only the Craft apps; the confirm line says so. There is no per-app update. "Newer" means a
newer AUR build exists, which can trail an ArtCraft release by a day or so.

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
$P install-group all|creative|office
$P update                     # Omarchy's AUR update, in a floating terminal
$P check [--notify]           # pending updates; exit 0 if any
$P refresh [-f]               # fetch catalog and AUR versions now
$P studio
```

```
omarchy-shell omarcraft.productivity open | close | toggle | refresh | studio
omarchy-shell omarcraft.productivity launch <id>
omarchy-shell omarcraft.productivity install "<id> <id>"      # no confirm: a script is explicit
omarchy-shell omarcraft.productivity update
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

Apps stay installed; remove them like any package, e.g. `omarchy pkg drop photocraft-bin`. Optional
clean-up:

```bash
rm -rf ~/.cache/omarchy/omarcraft ~/.local/state/omarchy/omarcraft   # catalog cache, job records, seen list
rm -f ~/.local/share/applications/ArtCraft.desktop                  # the Studio web app
```

plus `$P remove-menu` before removing if you ran `setup-menu`, and the keybinding line if you added it.

## Safety

- Only `<id>-bin` package names, checked against the catalog and a strict pattern, ever reach a package
  command. The plugin never calls sudo or pkexec, and never calls the package manager or the AUR helper
  directly: installs go through `omarchy-pkg-aur-add`, updates through `omarchy-update-aur-pkgs`, both in
  a visible Omarchy terminal that asks for your password itself.
- Network use: the app catalog from `raw.githubusercontent.com` (storytold/craft-launcher) and versions
  from the AUR RPC, every 24 hours, with bounded timeouts; a failed check keeps the old list and says
  `OFFLINE`, never "up to date". The panel itself never waits on the network.
- Files: `~/.cache/omarchy/omarcraft/` (catalog) and `~/.local/state/omarchy/omarcraft/` (job records,
  seen apps, notification state). Nothing under `~/.config` without the opt-in commands.

## How it works

| Path | Role |
|---|---|
| `manifest.json` | `kinds: ["bar-widget"]`, entry point `Panel.qml`, default section right |
| `Panel.qml` | Bar icon, `KeyboardPanel`, sections, cursor, confirm line, keys, IPC |
| `AppRow.qml` | One row: glyph · name · subtext · right-edge action, Network-panel style |
| `Service.qml` | Runs `bin/omarcraft state`, watches `job.json`, six-hourly check |
| `Model.js` | Pure helpers: sections, meta line, subtexts, confirm text |
| `bin/omarcraft` | Catalog, installed state, jobs, launch, Studio, the opt-in menu section |
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
omarchy refresh shell        # after changing a .qml
```

Manual test plan: [docs/Testing.md](docs/Testing.md). Shell log: `journalctl --user _COMM=quickshell`.
Release and marketplace steps: [docs/Publish-Guide.md](docs/Publish-Guide.md). Changes:
[CHANGELOG.md](CHANGELOG.md).

## Credits and license

MIT, see [LICENSE](LICENSE). By Entangled Forge. The Craft apps, ArtCraft Studio and the app catalog are by
[Storyteller](https://github.com/storytold); the `-bin` packages are maintained by their AUR packagers. The
panel follows Omarchy's first-party Network and Power panels and Entangled Forge's OmasteelRGB.
