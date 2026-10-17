# Publish guide

How OmarCraft goes from this private repository to a marketplace listing, and the procedure for each
release. Based on the OmasteelRGB publish guide (Entangled Forge's first plugin) and Omarchy 4.0.4.

## Current state

- Repository `dreamsgarage/OmarCraft` is **private**. `omarchy plugin add` works from it only on machines
  whose git can authenticate to the account (here, through `gh auth git-credential`).
- The marketplace requires a public repository, so going public is step one of submission.

## What publishing means for an Omarchy plugin

Two independent layers:

1. **Installable from git.** `omarchy plugin add <url> --enable` clones the repository into
   `~/.config/omarchy/plugins/<id>/`, runs `omarchy plugin validate`, refuses an id already used by any
   folder there, and places the widget (`barWidget.defaultSection`, here `left`). No install script runs:
   everything the plugin needs must live in the repository and work from the plugin folder. That is why
   `bin/omarcraft` is called by path from `BarWidget.qml` and nothing is copied to `~/.local/bin`.
2. **Listed on the marketplace** at <https://plugins.omarchy.org>
   (<https://github.com/omacom/omarchy-plugin-marketplace>). Listing is by GitHub issue, reviewed by
   maintainers.

`omarchy plugin update <id>` fetches `origin HEAD`, fast-forwards and validates. So:

- **Never force-push `main`.** Every installed copy tracks it.
- `main` must be valid at every commit, not only at tags.

## Marketplace requirements, and where OmarCraft stands

| Requirement | OmarCraft |
|---|---|
| Public GitHub repository, one plugin, `manifest.json` at the root | Root manifest yes; **public: not yet** |
| Root README with install and removal instructions | Install, Remove, optional clean-up |
| Root licence, external dependencies documented | MIT; `yay`, `curl`, `jq` named in Requirements |
| Globally unique id outside `omarchy.*`, permanent | `omarcraft.productivity`; check the registry is free before submitting |
| Optional root `preview.png` | Screenshot of the picker |
| Manifest fields `schemaVersion`, `id`, `name`, `version`, `author`, `description`, `kinds`, `entryPoints` | All present; author `Entangled-Forge` as in OmasteelRGB |
| No configuration changes without consent | Menu section and keybinding are opt-in, documented, reversible |

Category: **Productivity**. Tags (one to three from the allowed list): `launcher, bar, quickshell`.

The automated security baseline is a static scan. Non-negated mentions of `sudo` or `pkexec` count as the
`privilege` capability and add `security-review-required`. OmarCraft calls neither; the README and the
submission say so as a negation. `yay` asks for the password itself, in a visible terminal. Expect the
scan to report the `package-manager` capability anyway (the plugin runs `yay -S`), which means
`review-required` and a maintainer review; listed plugins such as `readitloud.tts` went through the same.

Trademark note: ArtCraft and the Craft app names belong to Storyteller, whose packages carry a separate
brand licence. The README calls OmarCraft unofficial and unaffiliated, and the plugin uses no ArtCraft
logo (the bar icon is a Nerd Font palette glyph; the Studio web app icon is fetched from Storyteller's own
GitHub avatar at runtime, not shipped). Keep it that way.

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
   `omarchy restart shell` if `BarWidget.qml` changed.
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

   Then: picker opens, an app installs and launches, a group install runs in one terminal, Studio opens,
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
| Unit tests | `bash tests/run.sh` | 32 passed |
| Manifest and layout | `omarchy plugin validate` on a `git archive` export | valid |
| Real install path | `omarchy plugin add <url> --enable --yes` from the private repo | cloned and validated; enable timed out once (see Troubleshooting), `omarchy plugin enable` placed it |
| Update path | `omarchy plugin update omarcraft.productivity --yes` | see below |
| Picker | bar IPC `open`, real catalog | opens with 13 apps, Studio and the three group rows |
| App install / group install / update on real packages | through the picker | not yet run |
| Studio web app | right click | not yet run |
| Marketplace repository rules | table above | all but public |

## Troubleshooting for issue reports

- `omarchy plugin add … --enable` can print "omarchy-shell is not responding" right after cloning: the
  shell is still rescanning plugins and `omarchy-shell` gives up after 2 s (`OMARCHY_SHELL_IPC_TIMEOUT`).
  The plugin is installed; place it with `omarchy plugin enable omarcraft.productivity`.

- Shell log: `journalctl --user _COMM=quickshell`.
- Script by hand from the install folder: `bin/omarcraft list`, `bin/omarcraft check`.
- Stale catalog: `bin/omarcraft refresh -f`.
- An app missing from the picker has no `-bin` package in the AUR yet (`bin/omarcraft list` says
  "not packaged yet").
