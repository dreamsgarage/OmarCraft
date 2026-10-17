# OmarCraft v1 acceptance

**Status:** proposed, 2026-10-17. Each criterion is a claim that is either true or false on the reference
machine (Omarchy 4.0.4, the author's laptop). Results go in the table at the end, PASS/FAIL, with the
commit hash. Nothing ships with a FAIL in the *Must* rows.

## Fixture

- Installed before the run: `wordcraft-bin`, `deckcraft-bin`, `gridcraft-bin` (0.7.0-1).
- Not installed: the other ten. No source builds, no `storytold-*` bundles.
- `~/.cache/omarchy/omarcraft/` and `~/.local/state/omarchy/omarcraft/` deleted before the first-run
  checks, present for the rest.
- The update state is produced with the cache edit in `Testing.md` § 6 (FigCraft bumped to 99.0.0-1
  after installing it), then cleared with `bin/omarcraft refresh -f`.

## Must

**Placement and plugin hygiene**

- `omarchy plugin validate` passes on a `git archive` export of the commit.
- `omarchy plugin add <url> --enable` places the icon in the **right** section, after power or wherever
  `--enable` puts right-section widgets, never left or centre.
- Enabling the plugin runs no `yay`, no `pacman`, writes nothing under `~/.config` and creates no
  `.desktop` file. (`find ~/.config -newer <marker>` is empty; `pacman -Q` unchanged.)
- The plugin folder contains no symlink, no file outside the documented layout, and no reference to
  `sudo` or `pkexec` except as a negation in docs.

**Panel**

- Left click opens the panel under the icon within 1 s on a warm cache; a second click closes it; a click
  outside closes it; `Esc` closes it; `Tab` moves to the neighbouring bar panel.
- With the fixture, the hero meta reads exactly `3 OF 13 INSTALLED`; INSTALLED lists WordCraft, DeckCraft,
  GridCraft with `0.7.0-1`; AVAILABLE lists the other ten with `Install <version> · prebuilt, no
  compiling`; chips read `Install all · 10`, `Creative · 9`, `Office · 1`; STUDIO shows one row.
- Nothing installed (fixture apps removed): INSTALLED is hidden, meta reads `NOTHING INSTALLED YET`,
  cursor starts on the first available row.
- Every string is fully visible at the default font size: no elided name, subtext, chip or meta.
- The panel uses only theme colours: switching the theme (`omarchy theme set <other>`) recolours it with
  no restart and no hard-coded colour remains visible.

**Actions**

- `Enter` on an installed row launches the app; `Enter` again while it runs focuses the existing window
  (window count stays 1).
- `Enter` on an available row shows the confirm line naming `<id>-bin <version>` and the terminal; `Esc`
  closes the line and nothing runs; `Enter` again opens exactly one floating Omarchy terminal running
  exactly one `omarchy-pkg-aur-add <id>-bin`, which prompts for the password and installs with **no**
  `cargo`, `rustc` or `makepkg build` in the process tree at any time.
- `grep -rE 'sudo|pkexec|yay |pacman -S' --exclude-dir=.git .` in the plugin folder matches only negated
  sentences in docs; no command string in code.
- While the job runs: the row shows the spinner and `Installing…`, the hero reads `INSTALLING <NAME>…`,
  every install/update action is disabled, launch of other installed apps still works.
- When the job ends successfully: within 1 s the row is under INSTALLED with its version, the meta count
  is `4 OF 13 INSTALLED`, and the app launches (single-app job only).
- `a` (or the *Install all* chip) confirms with the full package list and runs one `omarchy-pkg-aur-add`
  with every missing `-bin` package on one line; group chips do the same for their group; no launch
  afterwards.
- With the FigCraft update fixture: meta reads `1 UPDATE READY`, the bar shows `1 󰏘` in the urgent
  colour, the row shows `Update ready 0.6.0-1 → 99.0.0-1`, *Update all* is visible and `u` opens a confirm
  line that names Omarchy's AUR update; the badge and the row return to normal after
  `bin/omarcraft refresh -f`.
- Opening the panel with the network down (`nmcli networking off`) shows the cached list, the meta
  `OFFLINE · CACHED LIST`, and never a blank or "Detecting…" panel; `state` still returns in < 0.3 s.
- A job whose terminal is killed mid-way leaves no `job.json` older than 30 min reported as running;
  the hero reads `LAST JOB FAILED` and the next successful job clears it.

**Safety**

- `bin/omarcraft install 'x;rm'`, `install ../x` and `install photocraft-git` are refused with a message;
  the only package names in any `yay` invocation match `^[a-z0-9-]+-bin$`.
- Right click opens Studio as a web app; the first right click creates `ArtCraft.desktop`; later ones
  focus the existing window.
- Removing the plugin (`omarchy plugin remove`) leaves every installed app installed.

**Offline tests**

- `bash tests/run.sh` passes, including new cases for `state` JSON shape, sectioning, group counts,
  meta-line priority, job lifecycle (`job.json` present / stale / absent) and id validation.

## Should

- Middle click refreshes and, with the update fixture, sends exactly one notification; a second middle
  click sends none.
- `omarchy-shell omarcraft.productivity status` returns the state JSON; `install wordcraft` from IPC
  starts the job without the confirm line; `launch nope` returns a message, not an exception.
- `state` completes in under 0.3 s on a warm cache (`time bin/omarcraft state`).
- `omarchy plugin update` from one phase commit to the next fast-forwards, validates and leaves the panel
  working without a shell restart when only `bin/` or docs changed.

## Validation results

| # | Claim | Commit | Result | Note |
|---|---|---|---|---|
| | *(filled during phase 5)* | | | |
