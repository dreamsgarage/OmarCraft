# Testing OmarCraft

A manual test plan for a release candidate, run on a real Omarchy 4 machine. Work through it top to bottom;
each step says what to do and what you should see. Record results in the readiness table of
[Publish-Guide.md](Publish-Guide.md).

Paths below use `P=~/.config/omarchy/plugins/omarcraft.productivity`.

## 0. Before you start

- **No other package install running.** `pgrep -af 'yay|pacman|makepkg'` should print nothing. pacman
  allows one transaction at a time; a running `yay` (for example a source build of `storytold-office`)
  makes OmarCraft's install stop with a database lock error. A build that is only compiling does not hold
  the lock yet, but it will when it installs, so finish or stop it first.
- **Offline tests pass** in the repository: `bash tests/run.sh` (32 passed).
- **Shell log open** in a spare terminal: `journalctl --user -f _COMM=quickshell`.

## 1. Install the plugin the way users will

```bash
omarchy plugin list | grep -i omarcraft          # if listed, remove first:
omarchy plugin remove omarcraft.productivity
omarchy plugin add https://github.com/dreamsgarage/OmarCraft.git --enable
```

Expect: the palette icon on the left of the bar, after the workspaces. If the add printed "omarchy-shell is
not responding", run `omarchy plugin enable omarcraft.productivity` and expect the icon then.

Check: `git -C $P log --oneline -1` shows the commit you are testing.

## 2. Picker

| Do | Expect |
|---|---|
| Left-click the icon | Picker titled ArtCraft opens within about a second |
| Look at the rows | *ArtCraft Studio* first, then 13 apps with "Install x.y.z" or "Installed x.y.z", then the group rows for incomplete groups |
| Type `word`, Esc | List filters; Esc closes, nothing happens |
| `Super + Alt + A` (if you added the keybinding) | Same picker |
| `$P/bin/omarcraft list` | Same 13 apps with group, AUR version and state |

## 3. Install one app

Pick a small one you don't use yet, for example **FigCraft**.

Expect: a floating terminal with the Omarchy logo, `Installing FigCraft...`, yay downloading
`figcraft-bin` (no `cargo`, no compiling), a password prompt, Omarchy's done screen, then FigCraft opens.

Then:

- Left-click again: FigCraft now reads "Installed x.y.z". Pick it: the open window is focused, no second
  copy starts.
- `Super + Alt + Space`: FigCraft is in the app launcher.
- `pacman -Q figcraft-bin` shows the version.

## 4. Group install

Pick *Install New* (or *Install Classic*).

Expect: one terminal, one password prompt, every missing app of the group listed in one `yay -S` line,
`-bin` packages only. After it finishes, the group row is gone from the picker and the apps read
"Installed".

## 5. Studio

Right-click the icon.

Expect: ArtCraft Studio opens as a web app window at app.getartcraft.com; on first use an ArtCraft entry
appears in the app launcher. Right-click again: the existing window is focused.

## 6. Updates

Real updates arrive when an AUR `-bin` package is bumped. To test the flow without waiting, make the cached
catalog claim a newer build of an app you installed in step 3:

```bash
C=~/.cache/omarchy/omarcraft/catalog.tsv
cp $C /tmp/catalog.bak
# bump FigCraft's AUR version (column 5) in the cache
awk -F'\t' -v OFS='\t' '$1 == "figcraft" { $5 = "99.0.0-1" } 1' /tmp/catalog.bak > $C
```

| Do | Expect |
|---|---|
| Middle-click the icon | Icon turns urgent; one notification "ArtCraft updates available", FigCraft x → 99.0.0-1 |
| Hover the icon | Tooltip lists the same line |
| Middle-click again | No second notification for the same set |
| Left-click | Picker leads with *Update apps*; FigCraft shows "Update ready" |
| `$P/bin/omarcraft check; echo $?` | The FigCraft line, then `0` |

Do **not** pick *Update apps* here (99.0.0 doesn't exist). Restore and confirm the icon calms down:

```bash
$P/bin/omarcraft refresh -f       # re-reads the real versions
omarchy-shell omarcraft.productivity refresh
```

Expect: icon back to normal, `bin/omarcraft check` exits `1`.

## 7. Optional menu section

```bash
cp ~/.config/omarchy/extensions/omarchy-menu.jsonc /tmp/menu.bak
$P/bin/omarcraft setup-menu
omarchy menu summon ac            # ArtCraft section: All apps, Studio, group installs
$P/bin/omarcraft remove-menu
diff /tmp/menu.bak ~/.config/omarchy/extensions/omarchy-menu.jsonc && echo restored
```

## 8. Plugin update and removal

- Push a trivial commit (or test the next real one), then `omarchy plugin update omarcraft.productivity`.
  Expect a fast-forward, a valid result, the icon still working. Note whether the shell restarted:
  `journalctl --user --since -5min | grep 'exited with status'` (seen once during development, not
  reproduced).
- `omarchy plugin remove omarcraft.productivity`: icon gone; installed apps still installed.

## 9. Apps installed some other way

If you have source builds (for example from `storytold-office`), check the documented behaviour: they show
as installed in the picker, launch, are skipped by group installs, and do not appear in `bin/omarcraft
check`. Moving one to the prebuilt package: `yay -S wordcraft-bin`, answer `y` to remove the conflicting
`wordcraft`; afterwards it shows in update checks.

## Reporting a problem

Include: the step, what you saw, `git -C $P log --oneline -1`, `$P/bin/omarcraft list`, and the shell log
lines from `journalctl --user _COMM=quickshell` around that time.
