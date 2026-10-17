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
| Left-click the icon | Panel under the icon within a second: hero `ArtCraft` + `N OF 13 INSTALLED`, status line `Prebuilt AUR packages · list from …` |
| Read the sections | INSTALLED (your apps, version, ▶), AVAILABLE (dimmed, `Install x.y.z · prebuilt, no compiling`, download glyph), chips `Install all · N` `Creative · N` `Office · N`, STUDIO |
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

## 5. Studio

Right-click the icon, or `s` in the panel. Expect ArtCraft Studio as a web-app window at
app.getartcraft.com; the first time, an ArtCraft entry appears in the app launcher; the second time the
existing window is focused.

## 6. Updates

Real updates arrive when an AUR `-bin` package is bumped. To see the flow now, make the cached catalog
claim a newer build of an app you installed in step 3:

```bash
C=~/.cache/omarchy/omarcraft/catalog.tsv
cp $C /tmp/catalog.bak
awk -F'\t' -v OFS='\t' '$1 == "figcraft" { $5 = "99.0.0-1" } 1' /tmp/catalog.bak > $C
omarchy-shell omarcraft.productivity refresh
```

| Do | Expect |
|---|---|
| Look at the bar | Icon in the urgent colour with `1 ` before it |
| Open the panel | Hero `1 UPDATE READY`; FigCraft row `Update ready x → 99.0.0-1`; *Update all* in the status line |
| `u` | Confirm line: `Runs Omarchy's AUR update, which upgrades every AUR package · a terminal opens…`; `Esc` cancels (don't run it: 99.0.0 does not exist) |
| Middle-click the icon twice | One notification "ArtCraft updates available" the first time, none the second |

Restore: `$P/bin/omarcraft refresh -f` then `omarchy-shell omarcraft.productivity refresh`. Expect the
icon back to normal and the row back to its version.

## 7. Failure and interruption

Start an install (step 3 on another app) and close the terminal window while the password prompt waits.
Expect, within five seconds: hero `LAST JOB FAILED`, status line `Last job was interrupted · see the
terminal`, icon urgent, actions enabled again. Install something successfully: the failure clears.

## 8. Offline

`nmcli networking off`, then `r` in the panel. Expect the hero `OFFLINE · CACHED LIST`, the status line
`Could not reach the AUR · list from …`, rows unchanged, panel still instant. `nmcli networking on`, `r`:
back to normal.

## 9. Optional menu section and keybinding

```bash
cp ~/.config/omarchy/extensions/omarchy-menu.jsonc /tmp/menu.bak
$P/bin/omarcraft setup-menu && omarchy menu summon ac       # ArtCraft section: All apps, Studio, Update all, group installs
$P/bin/omarcraft remove-menu
diff /tmp/menu.bak ~/.config/omarchy/extensions/omarchy-menu.jsonc && echo restored
```

With the README's keybinding line in `bindings.lua`: `Super + Alt + A` toggles the panel.

## 10. Plugin update and removal

- Push a commit, `omarchy plugin update omarcraft.productivity`: fast-forward, valid, panel working after
  `omarchy refresh shell`. Note any `exited with status` line in the shell log.
- `omarchy plugin remove omarcraft.productivity`: icon gone; apps still installed.

## Reporting a problem

Include the step, what you saw, `git -C $P log --oneline -1`, `$P/bin/omarcraft state`, and the shell log
lines from `journalctl --user _COMM=quickshell` around that time.
