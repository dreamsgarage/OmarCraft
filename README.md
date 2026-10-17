# OmarCraft

The ArtCraft Craft apps, one click from the Omarchy bar.

![OmarCraft picker](preview.png)

[ArtCraft](https://getartcraft.com) ships thirteen creative and office apps (PhotoCraft, VectorCraft,
FilmCraft, LightCraft, PdfCraft, EffectCraft, DesignCraft, WordCraft, DeckCraft, GridCraft, CADCraft,
SoundCraft, FigCraft) plus ArtCraft Studio for AI image and video. OmarCraft puts them behind one bar icon:
launch what you have, install what you don't, one app or a whole group at a time, and get told when newer
builds are out. Installs use the prebuilt `-bin` packages from the AUR, so pacman owns every app and nothing
is ever compiled.

Plugin id `omarcraft.productivity`. MIT licensed. **Unofficial**: OmarCraft is not made by or affiliated with
Storyteller, the makers of ArtCraft. ArtCraft and the app names are theirs.

## Requirements

- Omarchy 4 (Quattro).
- `yay`, `curl` and `jq`, all part of a standard Omarchy install. Nothing else is downloaded at plugin
  install time.

## Install

```bash
omarchy plugin add https://github.com/dreamsgarage/OmarCraft.git --enable
```

The icon lands on the left of the bar. If the add prints "omarchy-shell is not responding", the shell was
still reloading; run `omarchy plugin enable omarcraft.productivity`. Updates:
`omarchy plugin update omarcraft.productivity`.

## Use

- **Left-click** the bar icon for the picker. It lists every Craft app with its state: installed (pick to
  launch or focus), available (pick to install, then it launches), update ready, or new. Above the apps:
  *Update apps* when there is something to update, and *ArtCraft Studio*. Below them: *Install Classic*
  (Photo, Vector, Film, Light, Pdf, Effect, DesignCraft), *Install New* (Word, Deck, Grid, CAD, Sound,
  FigCraft) and *Install all*; each disappears once its group is complete.
- **Right-click** opens ArtCraft Studio.
- **Middle-click** checks for updates now.
- Installs and updates run in one floating Omarchy terminal with one `yay` run, however many apps are
  selected. Your password is asked there, in the open; the plugin never calls sudo or pkexec itself.
- Installed apps also show up in the Omarchy app launcher (`Super + Alt + Space`), like any other app.

### ArtCraft Studio

ArtCraft Studio has no Linux build, only a source package that takes a long Rust and Node build. OmarCraft
opens it as an Omarchy web app (`https://app.getartcraft.com`) and adds it to the app launcher on first
use. It needs an ArtCraft account; generation runs in their cloud, so no local GPU is needed.

### Updates and new apps

Every six hours the widget compares your installed apps with the AUR. When newer builds are ready the
icon turns to the urgent colour, the tooltip lists them, and one notification appears per new set of
updates; clicking it (or *Update apps* in the picker) installs them. `omarchy update` updates them too,
since it upgrades AUR packages.

The app list itself comes from the official ArtCraft Launcher's catalog. When ArtCraft adds an app, it
appears in the picker marked new, with a notification, as soon as its `-bin` package is in the AUR.

## Optional extras

None of these are done for you; OmarCraft does not change your configuration on its own.

**A keybinding.** Add this line to `~/.config/hypr/bindings.lua` (`Super + Alt + A` is free on a default
Omarchy 4 install):

```lua
o.bind("SUPER + ALT + A", "OmarCraft", "omarchy-shell omarcraft.productivity open")
```

**An ArtCraft section in the Omarchy menu** (`Super + Alt + Space` root menu and *Install → ArtCraft*):

```bash
~/.config/omarchy/plugins/omarcraft.productivity/bin/omarcraft setup-menu    # add
~/.config/omarchy/plugins/omarcraft.productivity/bin/omarcraft remove-menu   # remove
```

It writes one marked block into `~/.config/omarchy/extensions/omarchy-menu.jsonc` and leaves the rest of
the file untouched. `omarchy menu summon ac` opens it.

## Command line

The picker is a front end for one script, which scripts and keybindings can call too:

```
bin/omarcraft menu                 # the picker
bin/omarcraft launch <id>          # e.g. photocraft
bin/omarcraft install <id>...      # one or more apps
bin/omarcraft install-group all|classic|new
bin/omarcraft check                # pending updates; exit 0 if any
bin/omarcraft update
bin/omarcraft studio
bin/omarcraft list                 # catalog with install state
```

IPC: `omarchy-shell omarcraft.productivity open` and `omarchy-shell omarcraft.productivity refresh`.

## Remove

```bash
omarchy plugin remove omarcraft.productivity
```

That deletes the plugin folder and its bar entry. Apps you installed stay installed; remove them like any
package, for example `omarchy pkg drop photocraft-bin`. Optional clean-up:

```bash
~/.config/omarchy/plugins/omarcraft.productivity/bin/omarcraft remove-menu   # before removing, if you ran setup-menu
rm -rf ~/.cache/omarchy/omarcraft ~/.local/state/omarchy/omarcraft            # catalog cache and state
rm -f ~/.local/share/applications/ArtCraft.desktop                           # the Studio web app
```

and delete the keybinding line if you added it.

## How it works

| Path | Role |
|---|---|
| `manifest.json` | Plugin manifest: `kinds: ["bar-widget"]`, entry point `BarWidget.qml` |
| `BarWidget.qml` | Bar icon, update check timer, IPC (`open`, `refresh`) |
| `bin/omarcraft` | Catalog, picker, install, update, Studio and the optional menu section |
| `tests/` | `bash tests/run.sh`; offline, never touches the network, pacman or your config |
| `docs/` | Publish guide and marketplace submission |

The catalog is read from `crates/core/src/catalog.rs` in
[storytold/craft-launcher](https://github.com/storytold/craft-launcher), with a built-in copy as fallback,
and versions from one AUR RPC request; both are cached for 24 hours in `~/.cache/omarchy/omarcraft/`. The
picker is Omarchy's own `omarchy-menu-select`, launches go through `omarchy-launch-or-focus`, and installs
through `omarchy-launch-floating-terminal-with-presentation`, so everything looks and behaves like the rest
of Omarchy. Only `<id>-bin` packages are installed: the `storytold-suite` and `storytold-office` bundles and
the official `artcraft-launcher` package depend on source builds, so OmarCraft deliberately avoids them.

## Development

```bash
bash tests/run.sh
rsync -a --delete --exclude .git ./ ~/.config/omarchy/plugins/omarcraft.productivity/
omarchy restart shell        # after changing BarWidget.qml
```

Shell log: `journalctl --user _COMM=quickshell`. Release and marketplace steps:
[docs/Publish-Guide.md](docs/Publish-Guide.md). Changes: [CHANGELOG.md](CHANGELOG.md).

## Credits and license

MIT, see [LICENSE](LICENSE). By Entangled Forge. The Craft apps, ArtCraft Studio and the app catalog are by
[Storyteller](https://github.com/storytold); the `-bin` packages are maintained by their AUR packagers.
