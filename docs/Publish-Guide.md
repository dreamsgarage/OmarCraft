# Publish guide

How OmarCraft goes from this private repository to a marketplace listing, and the procedure for each
release. Based on the OmasteelRGB publish guide (Entangled Forge's first plugin) and Omarchy 4.0.4.

## Current state

- Repository `dreamsgarage/OmarCraft` is **public** since 2026-10-18 (`v0.1.0`). Before that, `omarchy plugin
  add` worked only on machines whose git could authenticate to the account.
- The marketplace requires a public repository, so going public was step one of submission.

## What publishing means for an Omarchy plugin

Two independent layers:

1. **Installable from git.** `omarchy plugin add <url> --enable` clones the repository into
   `~/.config/omarchy/plugins/<id>/`, runs `omarchy plugin validate`, refuses an id already used by any
   folder there, and places the widget (`barWidget.defaultSection`, here `right`). No install script runs:
   everything the plugin needs must live in the repository and work from the plugin folder. That is why
   `bin/omarcraft` is called by path from `Panel.qml` and nothing is copied to `~/.local/bin`.
2. **Listed on the marketplace** at <https://plugins.omarchy.org>
   (<https://github.com/omacom/omarchy-plugin-marketplace>). Listing is by GitHub issue, reviewed by
   maintainers.

`omarchy plugin update <id>` fetches `origin HEAD`, fast-forwards and validates. So:

- **Never force-push `main`.** Every installed copy tracks it.
- `main` must be valid at every commit, not only at tags.

## Marketplace requirements, and where OmarCraft stands

| Requirement | OmarCraft |
|---|---|
| Public GitHub repository, one plugin, `manifest.json` at the root | Yes, public since 2026-10-18 |
| Root README with install and removal instructions | Install, Remove, optional clean-up |
| Root licence, external dependencies documented | MIT; only Omarchy's bundled tools, said in Requirements |
| Globally unique id outside `omarchy.*`, permanent | `omarcraft.productivity`; not in the registry's 5,603 sources or retired ids as of 2026-10-17 |
| Optional root `preview.png` | Screenshot of the panel, tiles layout |
| Manifest fields `schemaVersion`, `id`, `name`, `version`, `author`, `description`, `kinds`, `entryPoints` | All present; author `Entangled-Forge` as in OmasteelRGB |
| No configuration changes without consent | Menu section and keybinding are opt-in, documented, reversible |

Category: **Productivity**. Tags (one to three from the allowed list): `launcher, bar, quickshell`.

The automated security baseline is a deterministic static scan (its rules are public in the
marketplace's `SECURITY.md`, and its code runs locally, see below). OmarCraft's expected result is
`review-required` with one capability, `package-manager`: the `yay -S` line of the update job and the
`omarchy pkg drop` lines of the README. A `privilege` capability appears whenever a document mentions
`sudo` or `pkexec` in a form the scanner does not recognise as a negation; it accepts "does not use sudo or
pkexec" and "No sudo or pkexec is required", not "never calls" or "never uses" (checked against the
scanner's regular expression on 2026-10-18). `review-required` is publishable once a
maintainer accepts the exact capability set, the path OmasteelRGB took and was approved on.

Run the scanner yourself before every submission or update, on the commit you will submit:

```bash
git clone --depth 1 https://github.com/omacom/omarchy-plugin-marketplace /tmp/marketplace
node tests/marketplace-baseline.mjs /tmp/marketplace        # Node 24 or newer, no npm install needed
```

It serves the scanner the repository at `HEAD` the way GitHub would and prints the bot's report
followed by a machine summary (`outcome`, `findings`, `capabilities` with evidence lines).

Trademark note: ArtCraft and the Craft app names belong to Storyteller, whose packages carry a separate
brand licence. The README calls OmarCraft unofficial and unaffiliated, and the plugin uses no ArtCraft
logo (the bar icon is a Nerd Font rocket glyph; the per-app colours are data from their public catalog).
Keep it that way.

## Release procedure

1. Tests green: `bash tests/run.sh`.
2. Bump `version` in `manifest.json` (semver) and add the CHANGELOG entry.
3. Validate a clean export, not the working folder:

   ```bash
   rm -rf /tmp/omarcraft-export && mkdir /tmp/omarcraft-export
   git archive HEAD | tar -x -C /tmp/omarcraft-export
   omarchy plugin validate /tmp/omarcraft-export
   ```

4. Commit, push `main`, tag: `git tag -a v0.1.0 -m "OmarCraft 0.1.0" && git push origin main --tags`.
5. Confirm the update path on a git-managed install: `omarchy plugin update omarcraft.productivity`, then
   `omarchy restart shell` if a QML file changed.
6. Optionally `gh release create v0.1.0 --generate-notes`.
7. If listed, open a Plugin verification issue for the new commit SHA
   (<https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=verify-plugin.yml>).

## Submission, when ready

1. Run the release checks above on the commit you will submit.
2. Test the real install path on a clean plugins folder (the add command refuses an existing id):

   ```bash
   omarchy plugin remove omarcraft.productivity
   omarchy plugin add https://github.com/dreamsgarage/OmarCraft.git --enable
   ```

   Then: panel opens, an app installs and launches, a group install runs in one terminal,
   `bin/omarcraft check` reports correctly.
3. Make the repository public: `gh repo edit dreamsgarage/OmarCraft --visibility public --accept-visibility-change-consequences`.
4. Submit from a pushed commit you will not move until the bot has validated it:

   ```bash
   gh issue create --repo omacom/omarchy-plugin-marketplace --title "[Plugin]: OmarCraft" --body-file docs/marketplace-submission.md
   ```

5. Do not push to `main` while the submission is open, or resubmit the new SHA.

## Readiness checks for 0.1.0

| Check | How | Result |
|---|---|---|
| Unit tests | `bash tests/run.sh` | 95 passed |
| Manifest and layout | `omarchy plugin validate` on the folder | valid (export check at tag time) |
| Real install path | `omarchy plugin add <url> --enable --yes` from the private repo (v2 manifest) | cloned and validated; enable timed out once (see Troubleshooting), `omarchy plugin enable` placed it; re-run with the panel manifest pending |
| Update path | `omarchy plugin update omarcraft.productivity --yes`, three times | fast-forwarded and validated each time |
| Panel | bar icon right, hero, sections, cursor, confirm line, IPC | see `v1-acceptance.md` rows 1–12 |
| App install / group install / update / interruption / offline / theme on real packages | through the panel | PASS, `v1-acceptance.md` rows 13–19 (2026-10-18); rows 20 (fresh add, after going public) and 21 (remove) pending |
| Marketplace repository rules | table above | all |

## Troubleshooting for issue reports

- `omarchy plugin add … --enable` can print "omarchy-shell is not responding" right after cloning: the
  shell is still rescanning plugins and `omarchy-shell` gives up after 2 s (`OMARCHY_SHELL_IPC_TIMEOUT`).
  The plugin is installed; place it with `omarchy plugin enable omarcraft.productivity`.

- Shell log: `journalctl --user _COMM=quickshell`.
- Script by hand from the install folder: `bin/omarcraft list`, `bin/omarcraft check`.
- Stale catalog: `bin/omarcraft refresh -f`.
- An app missing from the panel has no `-bin` package in the AUR yet (`bin/omarcraft list` says
  "not packaged yet").
