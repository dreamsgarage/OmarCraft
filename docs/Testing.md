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

Expect: the palette icon in the **right** section of the bar, among tray, agents, bluetooth, network,
audio, monitor, power. Nothing installed, nothing written under `~/.config`. If the add printed
"omarchy-shell is not responding", `omarchy plugin enable omarcraft.productivity` places it.

## 2. Panel, read-only

| Do | Expect |
|---|---|
| Left-click the icon | Panel under the icon within a second: rocket logo, `OmarCraft`, `N OF 13 INSTALLED`; no line under the hero unless something is happening |
| Make an app new: `sed -i '/cadcraft/d' ~/.local/state/omarchy/omarcraft/seen`, then right-click the icon | Bar icon in the urgent colour (rows layout: `New · install …` on CADCraft); open and close the panel: icon back to normal, `cadcraft` back in the seen file |
| Read the sections (tiles) | INSTALLED tiles in each app's colour, AVAILABLE tiles dimmed, chips `c Creative · N` `o Office · N`; hover a tile for its version |
| `t` | Rows: INSTALLED (version, ▶), AVAILABLE (dimmed, `Install x.y.z · prebuilt, no compiling`, download glyph); `t` again returns to tiles |
| `j` four times | First press activates the cursor on the first row, then it moves down one row per press; the list scrolls to keep it in view |
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

`o` (or the *Office · N* chip). Expect the confirm line under the chips listing every missing office
package, one terminal, one password prompt, one command with all packages. Afterwards the chip is gone
and the apps read Installed. No launch.

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
| Open the panel | Hero `N OF 13 INSTALLED · 1 UPDATE`; an UPDATES · 1 section at the top with the FigCraft tile carrying `↑ 99.0.0` and an *Update all · u* button; FigCraft gone from INSTALLED |
| `Enter` on the tile | Confirm line `Update FigCraft 0.x.y → 99.0.0 · a terminal will open and ask for your password` with *Update ⏎*, *Launch instead*, *Cancel*; `Esc` cancels (don't run it: 99.0.0 does not exist) |
| `u` or *Update all* | The same confirm naming every app with a newer build |
| `$P/bin/omarcraft check --notify` twice | One notification "ArtCraft updates available" the first time, none the second. The panel runs this check at shell start and every six hours; a manual refresh (`r`, right-click) only shows the badge |

Restore: `$P/bin/omarcraft refresh -f` then `omarchy-shell omarcraft.productivity refresh`. Expect the
icon back to normal and the tile back in INSTALLED.

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

Right-click an installed tile (or `x` with the cursor on it). Expect the confirm line `Remove <App> x.y.z ·
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

## Reporting a problem

Include the step, what you saw, `git -C $P log --oneline -1`, `$P/bin/omarcraft state`, and the shell log
lines from `journalctl --user _COMM=quickshell` around that time.
