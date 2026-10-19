# OmarCraft v1 acceptance

**Status:** approved 2026-10-17. Each criterion is a claim that is either true or false on the reference
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
  compiling`; chips read `Install all · 10`, `Creative · 9`, `Office · 1`.
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
- `grep -rE 'sudo|pkexec|pacman -S' --exclude-dir=.git .` in the plugin folder matches only negated
  sentences in docs; the AUR helper is called in exactly one place in code, the update job.
- While the job runs: the row shows the spinner and `Installing…`, the hero reads `INSTALLING <NAME>…`,
  every install/update action is disabled, launch of other installed apps still works.
- When the job ends successfully: within 1 s the row is under INSTALLED with its version, the meta count
  is `4 OF 13 INSTALLED`, and the app launches (single-app job only).
- `a` (or the *Install all* chip) confirms with the full package list and runs one `omarchy-pkg-aur-add`
  with every missing `-bin` package on one line; group chips do the same for their group; no launch
  afterwards.
- With the FigCraft update fixture: meta reads `N OF 13 INSTALLED · 1 UPDATE`, the bar shows `1 󰔵` in
  the urgent colour, FigCraft sits in an UPDATES · 1 section with an `↑ 99.0.0` badge next to
  *Update all · u* (row layout: `Update ready 0.6.0-1 → 99.0.0-1`); `Enter` on FigCraft opens a confirm
  `Update FigCraft 0.6.0 → 99.0.0 · a terminal will open…` with *Update ⏎*, *Launch instead*, *Cancel*;
  *Launch instead* launches; everything returns to normal after `bin/omarcraft refresh -f`.
- `omarchy bar set omarcraft.productivity layout rows` and `… tiles`, and the `t` key, switch the layout
  live with the panel open; the cursor, confirm and job state survive the switch.
- Opening the panel with the network down (`nmcli networking off`) shows the cached list, the meta
  `OFFLINE · CACHED LIST`, and never a blank or "Detecting…" panel; `state` still returns in < 0.3 s.
- A job whose terminal is killed mid-way leaves no `job.json` older than 30 min reported as running;
  the hero reads `LAST JOB FAILED` and the next successful job clears it.

**Safety**

- `bin/omarcraft install 'x;rm'`, `install ../x` and `install photocraft-git` are refused with a message;
  the only package names in any `yay` invocation match `^[a-z0-9-]+-bin$`.
- Right click on the icon checks the AUR (the refresh control spins); middle click switches the layout.
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
| 1 | `omarchy plugin validate` on the folder | e7d2615 | PASS | working folder; export check pending at tag time |
| 2 | Icon in the right section | e7d2615 | PASS | `omarchy bar move … --section right` after update; fresh `plugin add` with the new manifest default pending |
| 3 | Hero meta `3 OF 13 INSTALLED`, sections and chips as specified | e7d2615 | PASS | screenshot 2026-10-17 17:18; v2 hero `4 OF 13 INSTALLED · 2 UPDATES` and the UPDATES section screenshotted with the cache fixture at fd7439f |
| 4 | Available rows dimmed, installed full | e7d2615 | PASS | screenshot |
| 5 | No elided string at the default size | e7d2615 | PASS | all 13 rows, chips and meta visible in the screenshot |
| 6 | `j` activates then moves the cursor; `Enter` on an available row shows the confirm naming `<id>-bin <version>` and the terminal | e7d2615 | PASS | driven with `wtype`; screenshot of the confirm line |
| 7 | `Esc` closes the confirm, then the panel | e7d2615 | PASS | driven with `wtype` |
| 8 | Launching an installed app whose window is open focuses it (window count stays 1) | e7d2615 | PASS | via IPC `launch deckcraft` |
| 9 | IPC refuses unknown and unsafe ids, reports no updates | e7d2615 | PASS | `launch nope`, `install 'x;rm'`, `update` |
| 10 | No `sudo`, `pkexec`, helper or `pacman -S` string in code | e7d2615 | PASS | test `no package-manager or privilege strings in the script`; docs use negations only |
| 11 | Offline tests | e7d2615 | PASS | 71 passed |
| 12 | Shell loads the plugin with no QML error | e7d2615 | PASS | log clean after `omarchy restart shell`; one transient "File name case mismatch" from the old shell during the git fast-forward, gone after restart |
| 13 | Real install: one terminal, one Omarchy command, no compiling, row moves to INSTALLED, app launches | 17ce259 | PASS (user) | SoundCraft installed by the user through the panel at 17:34: `last-job.json` `install soundcraft` exit 0, `soundcraft-bin 0.7.0-1` present, tile shown under INSTALLED on the next open |
| 14 | Group install, one command with every package | 5b48856 | PASS (user) | 2026-10-18, the *Creative* chip: eight packages in one terminal, one password prompt, chip gone afterwards |
| 15 | ~~Studio opens as a web app~~ | | dropped | Studio removed from scope 2026-10-17 |
| 16 | Update state: badge, row, *Update all*, one notification | 5b48856 | PASS (user) | 2026-10-18, real AUR bumps 0.7.0 → 0.8.0: WordCraft alone at 08:03, then DeckCraft, GridCraft and SoundCraft with *Update all* at 08:35 in one pacman transaction, job exit 0. The notification was not exercised: the updates were found by a manual refresh, which shows the badge and does not notify; the six-hourly check notified correctly in the fixture test of 2026-10-17 |
| 17 | Interrupted job reported as failed within 5 s, cleared by the next success | 5b48856 | PASS (user) | 2026-10-18, PdfCraft install interrupted at the password prompt: `LAST JOB FAILED` and the interrupted line, cleared by the next job |
| 18 | Offline: cached list, `OFFLINE` meta, panel instant | 5b48856 | PASS with a defect | 2026-10-18: offline state correct, but `omarcraft state exited with status 15` repeated in red. Cause: every state read retried the failed check and every failed check poked the panel, so reads killed one another. Fixed in the next commit (retry at most every ten minutes, reads never killed, state read 0.2 s instead of 0.8 s); re-tested by the user after the fix: PASS, no red line |
| 19 | Theme switch recolours the panel live | 5b48856 | PASS (user) | 2026-10-18 |
| 20 | Fresh `plugin add` places the icon right and installs nothing | 5a9311a | PASS | 2026-10-18, from the public URL after `plugin remove`: cloned, validated, enabled, placed in the right section after the tray by itself; package count unchanged (972); status answered with no error |
| 21 | Remove from the panel: confirm, one terminal with Omarchy's drop command, tile back under AVAILABLE | 51d29ba | PASS (user) | 2026-10-18 |
| 22 | Memospot: tile, Notes chip, install, launch, remove through the same paths | 18ef9d3 | PASS (user) | 2026-10-18 |
| 23 | 0.5 · Install Typesetter from its tile: `omarchy-pkg-add typesetter` in the floating terminal, tile turns installed, it launches | f4a2e0a | PASS | 2026-10-19, installed from the tile, launches |
| 24 | 0.5 · Install KolourPaint the same way; open a screenshot in it | f4a2e0a | PASS | 2026-10-19, installed from the tile, launches |
| 25 | 0.5 · Repo update badge: a stale system shows `↑ system`; Enter opens the confirm, which runs Omarchy's update | | pending | needs a repo app behind the sync database |
| 26 | 0.5 · Install Vikunja: one AUR job with `vikunja-desktop-bin` and `vikunja-bin`; user desktop entry appears | f4a2e0a | PASS | 2026-10-19, one job, user desktop entry present |
| 27 | 0.5 · First Vikunja launch: server on 127.0.0.1:3456, app opens, notification shows the URL; register, create a task | f4a2e0a | PASS | 2026-10-19, registered a local account, created a task |
| 28 | 0.5 · Vikunja lifecycle: close window → app quits, server stops within 5 s, port free, dot off; *Quit* from tray → same | c948963 | PASS | 2026-10-19: closing the window stopped the server, dot off; tray *Quit* passed earlier |
| 29 | 0.5 · Vikunja from the app launcher starts the server too | f4a2e0a | PASS | 2026-10-19, from the app launcher: server started, tile dot on |
| 30 | 0.5 · Remove Vikunja: both packages dropped, desktop entry gone, data kept | | pending | |
| 31 | 0.5 · First Vikunja launch hides its tray icon (bar's Hide list); after *Show*, later launches leave it shown | | pending | |
