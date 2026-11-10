# Testing OmarCraft

The manual test plan for a release candidate on a real Omarchy 4 machine. Work through it top to bottom;
each step says what to do and what you should see. Results go into the table in `v1-acceptance.md`.

`P=~/.config/omarchy/plugins/omarcraft.productivity`.

## 0. Before you start

- No other package install running: `pgrep -af 'pacman|makepkg'` prints nothing.
- Offline tests pass in the repository: `bash tests/run.sh`.
- Shell log open in a spare terminal: `journalctl --user -f _COMM=quickshell`.

## 1. Install the plugin the way users will

```bash
omarchy plugin remove omarcraft.productivity        # if present
omarchy plugin add https://github.com/dreamsgarage/OmarCraft.git --enable
```

Expect: the rocket icon in the **right** section of the bar, among tray, agents, bluetooth, network,
audio, monitor, power. Nothing installed, nothing written under `~/.config`. If the add printed
"omarchy-shell is not responding", `omarchy plugin enable omarcraft.productivity` places it.

## 2. Panel, read-only

| Do | Expect |
|---|---|
| Left-click the icon | Panel under the icon within a second: rocket logo, `OmarCraft`, `N OF 20 INSTALLED`; no line under the hero unless something is happening; three category headers (Creative, 3D Art, Office) and the Craft Anything line at the bottom |
| Make an app new: remove CADCraft first if it is installed, then `sed -i '/cadcraft/d' ~/.local/state/omarchy/omarcraft/seen` and right-click the icon | Bar icon in the urgent colour; open the panel: 3D Art has opened by itself, its header says *New*, CADCraft carries a *New* badge; close the panel: icon back to normal, `cadcraft` back in the seen file |
| `Enter` on a category header | It opens: installed tiles in each app's colour, the missing ones outlined and dimmed, and the header carries *Install N* with the category's key while apps are missing, open or closed; `Enter` again closes it. No version number anywhere |
| `t` | Inside each open category, rows instead of tiles (`Installed`, `Install · prebuilt, no compiling`, no versions); `t` again returns to tiles |
| `omarchy restart shell`, open the panel | The categories that were open are open again |
| `j` four times | First press activates the cursor on the first header, then it moves down one key per press (a header, a line of tiles, the Craft Anything line); the list scrolls to keep it in view |
| `Tab` | The neighbouring bar panel opens instead |
| `Esc` | Panel closes; a click outside closes it too |
| `$P/bin/omarcraft list` | Same apps and states as the panel |

## 3. Install one app

Pick an available app you don't use (FigCraft is small). `Enter` on its row.

Expect: a confirm line under the row, `figcraft-bin x.y.z · a terminal opens and asks your password`,
with *Install ⏎* and *Cancel esc*. `Esc` closes it and nothing runs. `Enter` again:

- a floating Omarchy terminal with the logo and `Installing FigCraft...`, then Omarchy's AUR add command
  downloading `figcraft-bin` (no `cargo`, no `makepkg` build), a password prompt, the done screen;
- meanwhile the panel row shows the spinner and `Installing…`, the hero `INSTALLING FIGCRAFT…`, every
  install action greyed out; launching an already installed app still works;
- when the terminal finishes: within a second the row is under INSTALLED with its version, the hero count
  went up by one, and FigCraft launched.

Then `Enter` on the new row: its window is focused, no second copy. `Super + Alt + Space`: FigCraft is in
the app launcher.

## 4. Group install

`o` (or *Install N* on the Office header; `c` and `3` for Creative and 3D Art). Expect the confirm
listing every missing office app by name, one terminal, one password prompt, one command with all
packages. Afterwards the header's key is gone and the apps read Installed. No launch.

## 5. Bar clicks

Right-click the icon: the refresh control in the hero spins and the status line says `Checking the AUR…`.
Middle-click: the layout flips.

## 6. Updates

Real updates arrive when an AUR `-bin` package is bumped (the first set, 2026-10-18, was WordCraft,
DeckCraft, GridCraft and SoundCraft 0.7.0 → 0.8.0). To see the flow without waiting, make the cached
catalog claim a newer build of an app you installed in step 3:

```bash
C=~/.cache/omarchy/omarcraft/catalog.tsv
cp $C /tmp/catalog.bak
awk -F'\t' -v OFS='\t' '$1 == "figcraft" { $5 = "99.0.0-1" } 1' /tmp/catalog.bak > $C
omarchy-shell omarcraft.productivity refresh
```

| Do | Expect |
|---|---|
| Look at the bar | Rocket and a `1` before it, both in the urgent colour |
| Open the panel | Hero `N OF 20 INSTALLED · 1 UPDATE`; an UPDATES · 1 strip naming FigCraft, with an *Update all · u* button; Creative's header has the update dot, and inside it FigCraft carries an *Update* badge |
| `Enter` on the tile | Confirm line `Update FigCraft · a terminal will open and ask for your password` with *Update ⏎*, *Launch instead*, *Cancel*; `Esc` cancels (don't run it: 99.0.0 does not exist) |
| `u` or *Update all* | The same confirm naming every app with a newer build |
| `$P/bin/omarcraft check --notify` twice | One notification "OmarCraft updates available" naming FigCraft (no version) the first time, none the second. The panel runs this check at shell start and every six hours; a manual refresh (`r`, right-click) only shows the badge |

Restore: `$P/bin/omarcraft refresh -f` then `omarchy-shell omarcraft.productivity refresh`. Expect the
icon back to normal and the badge gone.

## 7. Failure and interruption

Start an install (step 3 on another app) and close the terminal window while the password prompt waits.
Expect, within five seconds: hero `LAST JOB FAILED`, status line `Last job was interrupted · see the
terminal`, icon urgent, actions enabled again. Install something successfully: the failure clears.

## 8. Offline

`nmcli networking off`, then `r` in the panel. Expect the hero `OFFLINE · CACHED LIST`, the status line
`Could not reach the AUR · list from …`, rows unchanged, panel still instant, and nothing in red under the
hero: while offline the panel retries the AUR at most every ten minutes (before 0.1.0 a retry loop printed
`omarcraft state exited with status 15` repeatedly). `nmcli networking on`, `r`: back to normal.

## 9. Remove an app

Right-click an installed tile (or `x` with the cursor on it). Expect the confirm line `Remove <App> ·
a terminal will open and ask for your password · your files stay` with *Remove ⏎* in the urgent colour and
*Cancel*. `Enter`: one terminal titled `Removing <App>...` running Omarchy's `omarchy-pkg-drop <id>-bin`, one
password prompt; when it closes the tile is back under AVAILABLE and `pacman -Q <id>-bin` says it is not
installed. The app's documents and settings are untouched. `Esc` on the confirm cancels.

## 10. Optional menu section and keybinding

```bash
cp ~/.config/omarchy/extensions/omarchy-menu.jsonc /tmp/menu.bak
$P/bin/omarcraft setup-menu && omarchy menu summon ac       # ArtCraft section: All apps, Update all, group installs
$P/bin/omarcraft remove-menu
diff /tmp/menu.bak ~/.config/omarchy/extensions/omarchy-menu.jsonc && echo restored
```

With the README's keybinding line in `bindings.lua`: `Super + Alt + A` toggles the panel.

## 11. Plugin update and removal

- Push a commit, `omarchy plugin update omarcraft.productivity`: fast-forward, valid, panel working after
  `omarchy restart shell`. Note any `exited with status` line in the shell log.
- `omarchy plugin remove omarcraft.productivity`: icon gone; apps still installed.

## 12. Memospot, the first tool beyond ArtCraft

Open the panel. Expect a Memospot tile under AVAILABLE in amber with the note glyph, the chip `n Notes · 1`,
and, on a machine that had 0.1.0, the tile marked *New* in the rows layout and the bar icon in the urgent
colour until the panel is opened. `Enter` on the tile: `Install Memospot 1.0.5 · a terminal will open and
ask for your password`; one terminal, one password prompt (webkit2gtk is pulled in); afterwards the tile
moves to INSTALLED and `Enter` launches Memospot (its own window, `memospot.desktop`). `x` on it removes it.

## Reporting a problem

Include the step, what you saw, `git -C $P log --oneline -1`, `$P/bin/omarcraft state`, and the shell log
lines from `journalctl --user _COMM=quickshell` around that time.

## 0.5 on the author's machine (before any push)

While a marketplace submission is open, `main` stays at the validated commit. Test the `v0.5` branch by
pointing the installed plugin at it, and go back afterwards:

```bash
git -C $P fetch ~/Work/OmarCraft v0.5 && git -C $P checkout --detach FETCH_HEAD && omarchy restart shell
# back to the released version
git -C $P checkout main && omarchy restart shell
```

Rows 23–31 of `v1-acceptance.md` (Vikunja's rows are history: 0.5.1 dropped it).

## 0.5.1 on the author's machine (before any push)

The same way, with the `v0.5.1` branch:

```bash
git -C $P fetch ~/Work/OmarCraft v0.5.1 && git -C $P checkout --detach FETCH_HEAD && omarchy restart shell
```

Rows 32–34 of `v1-acceptance.md`. With 0.5.0's Vikunja installed, the first panel read after the switch
deletes `~/.local/share/applications/vikunja-desktop.desktop` and the `launch` script in
`~/.local/share/omarcraft/vikunja`, keeps everything else there, and posts one notification.

## 0.5.2 on the author's machine (before any push)

While a marketplace request is open, `main` stays at the commit under review. Test the `v0.5.2-dev` branch
the same way, and go back to the released version afterwards:

```bash
git -C $P fetch ~/Work/OmarCraft v0.5.2-dev && git -C $P checkout --detach FETCH_HEAD && omarchy restart shell
# back to the released version
git -C $P checkout main && omarchy restart shell
```

Rows 35–41 of `v1-acceptance.md`. Planify's data lives in `~/.local/share/io.github.alainm23.planify`;
check it after a remove. Measure its memory once installed: with Evolution's data services available it
may start a few background processes the unpacked benchmark could not.

## Upgrade from any earlier release

Before a release, on the commit to ship (network, nothing outside a temporary folder):

```bash
bash tests/upgrade-paths.sh "$PWD"     # or with no argument: what GitHub's main serves
```

Every earlier release (each tag, and 0.5.3) must print `ok`: cloned at that release, it leaves its own
cache and state, then the steps of `omarchy plugin update` (fetch, fast-forward, validate) bring it to
this commit, which reads the old data and comes back online. On a real machine that runs an older
version:

```bash
omarchy plugin update omarcraft.productivity --yes && omarchy restart shell
grep '"version"' ~/.config/omarchy/plugins/omarcraft.productivity/manifest.json   # the new version
git -C ~/.config/omarchy/plugins/omarcraft.productivity status --short --branch     # "## main...origin/main" (an "[ahead N]" after it is harmless), and no file listed below it
```

If the update refuses (*cannot fast-forward*, *local changes*, *not a git checkout*), the plugin folder
was edited or is not a clone: `omarchy plugin remove omarcraft.productivity --yes`, then `omarchy plugin
add https://github.com/dreamsgarage/OmarCraft.git --enable --yes` and `omarchy restart shell`. Apps stay
installed.

## 0.5.6: updates of apps from a package repo

Before the update, on a machine whose WordCraft or GridCraft is older than Omarchy's repo:
`CHECKUPDATES_DB=/tmp/omc-check checkupdates --nocolor` lists them (no password, the system untouched).
After `omarchy plugin update omarcraft.productivity` and `omarchy restart shell`, within a few seconds
the panel shows a badge with the new version on them; `$P/bin/omarcraft check` names the same versions.
Enter on one: the confirm reads like an AUR update; the terminal checks the repos, installs just that
package from `https://pkgs.omarchy.org/…` (pacman checks its signature) and nothing else; when it ends,
the badge is gone and `pacman -Q gridcraft-bin` shows the new version. Rows 51–56 of `v1-acceptance.md`.

## 0.5.5: bounded network input

After `omarchy plugin update omarcraft.productivity` and `omarchy restart shell`: the panel is online and
shows the same tools and versions as before; `$P/bin/omarcraft state | wc -c` prints well under 100000
(about 9000 in 2026-11). Row 50 of `v1-acceptance.md`.

## 0.5.4: apps a package repo ships

Omarchy's own repo ships `wordcraft-bin` and `gridcraft-bin`; check where each tool comes from before you
start, on each machine:

```bash
pacman -Si wordcraft-bin gridcraft-bin | grep -E '^(Repository|Name|Version)'   # Repository: omarchy
pacman -Qm | grep -E 'wordcraft|gridcraft'      # nothing: a name a repo ships is never foreign
```

Then update the plugin and restart the shell (`main` once 0.5.4 is released; before that, the branch the
same way as 0.5.2 above):

```bash
omarchy plugin update omarcraft.productivity && omarchy restart shell
jq -r .version $P/manifest.json                  # 0.5.4
$P/bin/omarcraft list | grep -E 'wordcraft|gridcraft|typesetter'
#   wordcraft ... installed 0.15.2-1 (omarchy repo)   — the version pacman -Si printed above
```

| Do | Expect |
|---|---|
| Open the panel | Within a few seconds the hero is no longer `OFFLINE` (the first read after the update checks the list once); no line in red |
| Hover WordCraft and GridCraft | Their installed version, the same as `pacman -Si` above; no `↑ system` badge |
| `r` | The list is checked again; the hero says when, no `OFFLINE` |
| `$P/bin/omarcraft check` | Lists only real updates: an AUR app as `Name installed → AUR version`, a repo app only if its repo has a newer build |

Rows 42–47 of `v1-acceptance.md`. Row 46 removes and reinstalls GridCraft from its tile: the install line
must say *from Omarchy's repo* and the terminal must run `omarchy-pkg-add gridcraft-bin`, not the AUR helper.

## 0.5.8: categories, the new apps, no versions

Rows 68–78 of `v1-acceptance.md`. After `omarchy plugin update` (or, before the release, the branch as in
the README's development steps) and `omarchy restart shell`:

| Do | Expect |
|---|---|
| Open the panel | `16 OF 20 INSTALLED` on a machine with the 16 earlier tools; 3D Art open by itself with *New* (SolidCraft, TextureCraft, MaterialCraft); Craft Anything on the last line with *New*; no version number anywhere |
| `$P/bin/omarcraft list \| wc -l` | 20 lines; `list 2>&1 >/dev/null` prints nothing (ArtCraft's list was read) |
| `3` | One confirm, `Install SolidCraft, TextureCraft and MaterialCraft · a terminal will open…`; run it, then launch each from its tile and remove one (`x`) |
| `Enter` on Craft Anything | Install confirm; then it launches from the same line |
| Close a category, `omarchy restart shell`, reopen | It stays closed |
| *Update all* with two updates pending | One job; afterwards `✓ Updated A and B` under the hero, gone on the next key |
| An opted-in menu from 0.5.7: its *Install Notes* entry | Installs what Office is missing; `$P/bin/omarcraft setup-menu` replaces it with *Install 3D Art* |

