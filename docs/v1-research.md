# OmarCraft v1 research

**Status:** approved 2026-10-17. Replaces the earlier `User-Research.md`, whose five-person usability
study was the wrong first move: the gaps were already visible from two shipped references and one real
session. Research here is sized to a two-person company shipping its second plugin: cheap, fast, and each
method answers a question the design cannot settle on its own.

## What we are not going to repeat

| Delivered | Why it failed | Lesson |
|---|---|---|
| **v1** (2026-10-17 morning): Omarchy-menu entries + "Office Suite" item | The item pulled the AUR **source** bundle: 1.5 h of Rust, then an unattended `sudo` timeout, zero apps installed | Know what a package does before offering it; prebuilt only |
| **v2** (same day): bar icon on the left, `omarchy-menu-select` text picker | Icon placed next to the workspace numbers against the section convention; a text list cannot show state; the author could not find the icon nor read installed vs. available | Follow the precedents first (OmasteelRGB, first-party panels); a panel, not a list |
| Research plan v1 | Proposed five moderated sessions before fixing what the references already showed | Expert and precedent review before user studies |

Both v1 and v2 were built before any spec or design existed. The OmasteelRGB sequence (plan → spec +
design → acceptance → build → validate) is the process now; `approved-plan.md`, `v1-spec.md`, `v1-design.md`,
`v1-acceptance.md` are that paper, and no more paper is planned.

## Research questions

1. **Placement and findability.** With the icon on the right, do Omarchy users find it unprompted?
   (Design answer: right section, like every popup-panel widget. Verify, don't study.)
2. **Status at a glance.** Can a user state installed / available / update-ready from the panel alone,
   within seconds, without reading subtext twice?
3. **Install confidence.** Does the inline confirm line make people more willing to click Install, or is it
   friction? What do they expect to happen (download vs. compile, password, duration)?
4. **Grouping.** Do people want *Office / Creative*, upstream's *Classic / New*, or no groups? Which apps
   belong where (PdfCraft is the ambiguous one)?
5. **Updates.** Is a notification per new set of updates welcome? Does the urgent icon get noticed and
   acted on within a day?
6. ~~Studio as a web app.~~ Dropped 2026-10-17: Studio is out of scope.

## Methods, in the order they run

### A. Precedent review (done before design; this document's last section)

Compare against OmasteelRGB, the first-party Network / Power / Agents panels, and the marketplace plugins
that install or update packages. Output: the patterns-to-copy list that `v1-design.md` already follows,
plus anything the marketplace shows that first-party panels do not. Cost: hours. Answers Q1 partly and sets
the baseline for everything else.

### B. Heuristic walk-through of the built panel (phase 2 and 3 of the plan)

Two reviewers (the author and one Entangled Forge colleague who has not seen the design), each alone,
against a 12-point checklist drawn from the references:

1. Icon in the right section, urgent only when attention is needed.
2. Hero meta states the whole situation in ≤ 28 characters.
3. Every row answers "what is it, what state, what can I do" in one glance.
4. Primary action on `Enter`, secondary on a visible button, nothing hidden in right-click only.
5. `j/k`, `Tab`, `Esc` behave like Network and Power.
6. Nothing happens on open; nothing happens without a visible confirm or an explicit key.
7. The confirm line names the package, the version and the terminal.
8. Busy state is visible in the row, the hero and the bar; actions are disabled, not hidden.
9. Failure is stated in words (`yay exited with status N`), not implied.
10. All colours come from the theme; square themes stay square.
11. No string elides at the default size.
12. The panel reads the same when 0, 3 and 13 apps are installed.

Each reviewer marks pass / fail / note per item and per state (normal, installing, confirm, empty,
offline). Output: the fix list for phase 5. Cost: one hour each. Answers Q1, Q2, partly Q3.

### C. Survey on grouping and expectations (Q3, Q4, Q5, Q6)

Ten questions, anonymous, posted in the Omarchy Discord `#plugins` channel and the ArtCraft Discord, open
one week, target n ≥ 40. Card-sort style for grouping, Likert for expectations:

1. Which of these apps have you heard of? (13 checkboxes)
2. Group these 13 apps the way you would want to install them together: drag into *Office*, *Creative*,
   *Other*, or leave ungrouped. (The closed card sort; PdfCraft, CADCraft, SoundCraft, FigCraft are the
   ones we expect to split.)
3. Would you rather have: install-all only / two or three groups / pick each app? (single choice)
4. When you click Install, what do you expect? (download a prebuilt package / compile from source /
   don't know)
5. How long should an install take before you'd assume something is wrong? (30 s / 2 min / 10 min / an hour)
6. A terminal opens and asks your password: fine / acceptable / would stop me. (Likert 5)
7. For updates: a desktop notification each time new builds appear / only an icon change / nothing,
   `omarchy update` is enough.
8. ~~ArtCraft Studio as a web app~~ (dropped; question removed from the survey).
9. Where do you expect a widget like this on the bar? (left / centre / right / don't care)
10. Free text: anything else.

Decision rules, written before the data comes in:

- Groups ship as *Office / Creative* only if ≥ 60 % of respondents place each app where the design puts
  it; otherwise the ambiguous apps move to where the majority put them. Below 60 % agreement overall, groups
  are dropped and *Install all* stays.
- The confirm line stays unless ≥ 70 % answer "fine" to Q6 **and** ≥ 70 % answer "prebuilt" to Q4; both
  together mean the line explains nothing people don't already expect.
- Notifications stay per-set (the current design) unless "nothing" wins Q7 outright.

Cost: one evening to build, one week to run, one hour to read. Output: the group table in `Model.js` and
two yes/no decisions.

### D. Private dogfooding diary (define → build → use → iterate)

The plugin is installed on the author's machine from phase 2 onward and on one or two colleagues'
machines from phase 3. Each person keeps a three-line note per day in a shared file, for ten working days:

- what I did with it today (launch / install / update / nothing);
- what surprised or annoyed me;
- one thing I'd change.

The repo stays private throughout; fixes land between days. Exit criterion: three consecutive days with
no new "annoyed" entry from anyone. Answers Q2, Q3, Q5 in real use, which a session cannot. Cost: two
minutes a day per person.

### E. Five-person usability test, only after D passes

Same session guide as the previous plan (seven tasks: find it, read state, install one, install a group,
notice an update, remove), with Omarchy users who have never seen OmarCraft, over a shared screen,
45 minutes each. It runs on the finished candidate, not on a draft, so its findings are release blockers or
nothing. Pass bar: 4 of 5 complete tasks 1–4 without a hint; nobody misreads installed vs. available; median
ease ≥ 5 of 7. Cost: one week including recruiting in the Omarchy Discord.

### F. Tiles against rows (added 2026-10-17)

The user asked for a tiles layout (three per line, the app's own colour) as a new version and for an
evaluation of whether it improves usability. Both layouts ship in one build, switched live with
`omarchy bar set omarcraft.productivity layout tiles|rows` or the `t` key, so the comparison is on the
same data, machine and day.

- **Who:** the author and one colleague (D's diary group), then the five E participants, each session
  running both layouts in alternating order (half start with tiles).
- **Tasks, timed, both layouts:** T2 "which apps do you have?" (state at a glance), T3 "install
  <app>" (find and act), T6 "anything to update?" (notice the mark), plus "open <installed app>".
- **Measures:** time to answer T2 correctly; errors (naming an available app as installed or the
  reverse); clicks or keys to complete T3; whether the update mark is noticed unprompted; stated
  preference and one reason.
- **Decision rule, written now:** tiles ship as the only layout if T2 is faster and at least as accurate
  for 4 of 5 participants and preference is ≥ 3 of 5; rows ship alone if the reverse; otherwise both
  stay with tiles as default and the question goes to the survey (C) with the two screenshots.
- **What the design predicts:** tiles win T2 (colour and density) and T6 (the mark); rows win T3 for
  first-time users (the caption says "Install 0.9.0 · prebuilt"); the tooltip is meant to close that gap.
- **Outcome for 0.1.0 (2026-10-18):** the timed comparison did not run before release. By the decision
  rule's third branch both layouts ship, tiles as default, and the question goes to the survey (C).

## Timeline

| When | What | Gate |
|---|---|---|
| Day 0 | Docs approved | the four docs |
| Days 1–3 | Phases 1–2 (state JSON, panel skeleton on the right) | B, round 1 |
| Day 3 | Survey C posted | runs through day 10 |
| Days 4–7 | Phases 3–4 (actions, jobs, notifications) | B, round 2; D starts |
| Days 8–17 | Phase 5 polish; D runs; survey read on day 10, groups decided | D exit criterion |
| Days 18–24 | E with five users | pass bar |
| Day 25 | Acceptance table filled, `preview.png`, go public, marketplace submission | `v1-acceptance.md` Must rows all PASS |

## Synthesis and deliverables

- One page: per research question, the answer, the evidence (survey counts, diary quotes, session
  observations), and the change made or deliberately not made.
- The checklist results from B, the survey table from C, the diary file from D, the task table from E,
  all in `docs/research/` with dates.
- Quotes anonymised unless the person asks for credit; recordings deleted after synthesis.

## Precedent review (done 2026-10-17)

**Scope.** The official marketplace registry (`omacom/omarchy-plugin-marketplace`, 5,603 listed sources:
2,913 *passed*, 2,599 *review-required*, 51 *needs-fixes*). Every plugin's manifest name and description
was fetched and searched by meaning, then the eight closest were read end to end (manifest, README,
panel QML, preview). Raw material: `desc*.tsv` and the previews, kept outside the repo.

**Competition.** No listed plugin installs ArtCraft, any Craft app, or any creative suite (searched: art,
creative, Krita, Blender, GIMP, Inkscape, suite, bundle). Partial overlap only: FossFetch (generic
find-and-install), Agent Helm (same install/launch list UX, for AI agents), Network Spell Book (curated
catalog with installed state, no installs).

**Plugins read, and what each taught**

| Plugin · id · outcome | Does | Copy | Avoid |
|---|---|---|---|
| Agent Helm · `jinchaofs.agent-helm` · passed | INSTALLED / NOT INSTALLED rows, dimmed missing rows, whole-row click launches or installs, cursor on the likely row, key-hint footer, JSON status script bounded by `timeout`, installs delegated to `omarchy-default-agent` | sections, dimming, JSON status script, delegation to Omarchy commands | detection by `command -v` alone (stub binaries read as installed) |
| Network Spell Book · `wizard.spellbook` · review-required | hero `35 OF 46 INSTALLED`, per-category tallies `4/6`, filled/hollow dot for present/absent, regex whitelist on package names; copies commands, never runs them | X-of-Y hero, tallies on chips, whitelist | literal `sudo pacman` strings even as copy-text: still flagged |
| FossFetch · `davedes.fossfetch` · review-required | pacman + AUR + Flathub search and install, `✓ Installed` / amber `old → new` chips, update count badge on the bar, arm-then-confirm for install, terminal exit → toast → rescan | badge when pending, confirm step, rescan after the terminal | a 233 KB `Panel.qml`; hard-coded terminal fallback |
| System Updater · `gennaro.updater` · review-required | hero "Updates / 1 PENDING" + refresh, sections per source with counts, `u` updates via `omarchy-launch-floating-terminal-with-presentation omarchy-update` | hero with pending count; floating presentation terminal for anything privileged | `cp` into the plugins dir as install docs |
| Dizziee System Updates · review-required | per-source cards with "Checked 38 s ago", completion tracked from Hyprland `openwindow`/`closewindow` | freshness line | `OMARCHY_ALLOW_DIRECT_PACMAN=1`, bypassing the pacman guard |
| Omaplug · `mateus.omaplug` · review-required | "a failed check is never reported as up to date", stale rows stay marked, confirm defaults to No | stale-not-fresh rule | four apps in one popup |
| Okomart · `b.okomart` · passed | plugin storefront; detached worker so work survives the panel closing; results view; destructive actions in the urgent colour | detached job, results after action | — |
| WordPress Studio · needs-fixes | four-state hero line; Launch/Remove disabled until installed | disabled-not-hidden actions | curl-pipe installers, unpinned git builds |

**Rule inferred from outcomes** (inference, not confirmed with the maintainers): the automated baseline
matches strings. Plugins whose files contain `sudo`, `pacman -S`, `yay -S` or `paru -S`, even in text
meant for copying, get `privilege` and `package-manager` and land in `review-required`; plugins that hand
the work to `omarchy-pkg-add`, `omarchy-pkg-aur-add`, `omarchy plugin …` or `omarchy-default-agent` pass
with no capabilities. OmasteelRGB is `review-required` (udev commands in its README and `Model.js`) and was
approved by a maintainer on 2026-09-22, so neither outcome blocks listing; *passed* just skips the wait.

**What changed in the design because of this review**

1. Jobs call `omarchy-pkg-aur-add` and `omarchy-update-aur-pkgs`, not the AUR helper (plan decision 6).
2. The bar shows a count badge only while updates are pending (plan decision 2).
3. Available rows are dimmed; installed rows are not.
4. `state` is local-only and bounded; refresh is detached; a failed refresh marks data stale.
5. Panel code is split into small files from the start.

**Answered without a study:** Q1 (right section: every comparable plugin and every first-party popup
panel is there) and the first half of Q2 (sections + dimming + X-of-Y hero is the established way to show
installed state). The survey and the diary now carry Q3–Q6.
