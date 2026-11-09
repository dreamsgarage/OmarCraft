#!/bin/bash

# Upgrade paths: every earlier release must upgrade to the current one the way users upgrade, with
# `omarchy plugin update`. For each release, a throwaway install cloned at that release leaves its own
# cache and state (its check and its panel read run with HOME and every XDG dir in a temporary folder,
# and the panel, notification and detach commands stubbed); then the steps of omarchy-plugin-update bring
# it forward (fetch origin HEAD, merge --ff-only, omarchy-plugin-validate), and the new version reads and
# checks that old data. Needs the network and Omarchy's tools; reads the package database; writes only in
# the temporary folder.
#
#   bash tests/upgrade-paths.sh [repository]    default: https://github.com/dreamsgarage/OmarCraft.git
#
# The repository's HEAD is the version upgraded to. Run it before a release, on the commit to ship.

set -uo pipefail

REPO=${1:-https://github.com/dreamsgarage/OmarCraft.git}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/stubs"
for c in omarchy-shell omarchy-menu omarchy-notification-send setsid hyprctl; do
  printf '#!/bin/bash\nexit 0\n' >"$TMP/stubs/$c"
  chmod +x "$TMP/stubs/$c"
done

# Every release tag, and 0.5.3, the one release on main without a tag.
mapfile -t refs < <(git ls-remote --tags "$REPO" 'v*' | sed -n 's|.*refs/tags/\(v[^^]*\)$|\1|p' | sort -uV)
refs+=(57969bd)
target=$(git ls-remote "$REPO" HEAD | cut -f1)
[[ -n $target ]] || { echo "cannot read $REPO" >&2; exit 2; }

fail=0
for ref in "${refs[@]}"; do
  d="$TMP/$ref"
  mkdir -p "$d"/{home,cache,state,data,config}
  export HOME="$d/home" XDG_CACHE_HOME="$d/cache" XDG_STATE_HOME="$d/state" XDG_DATA_HOME="$d/data" \
    XDG_CONFIG_HOME="$d/config"
  plugin="$d/plugin"
  git clone -q "$REPO" "$plugin" && git -C "$plugin" reset -q --hard "$ref" || { echo "FAIL $ref: cannot clone"; fail=1; continue; }
  old=$(jq -r .version "$plugin/manifest.json")
  PATH="$TMP/stubs:$PATH" timeout 120 "$plugin/bin/omarcraft" refresh -f >/dev/null 2>&1
  PATH="$TMP/stubs:$PATH" timeout 60 "$plugin/bin/omarcraft" state >/dev/null 2>&1
  # omarchy-plugin-update, step by step.
  if ! git -C "$plugin" fetch --quiet origin HEAD || ! git -C "$plugin" merge --ff-only FETCH_HEAD >/dev/null 2>&1; then
    echo "FAIL $ref ($old): no fast-forward to $target"; fail=1; continue
  fi
  if ! omarchy-plugin-validate "$plugin" >/dev/null 2>&1; then
    echo "FAIL $ref ($old): the upgraded plugin does not validate"; fail=1; continue
  fi
  new=$(jq -r .version "$plugin/manifest.json")
  if ! PATH="$TMP/stubs:$PATH" timeout 60 "$plugin/bin/omarcraft" state | jq -e '.apps | length > 0' >/dev/null 2>&1; then
    echo "FAIL $ref ($old): the first read after the upgrade is not valid"; fail=1; continue
  fi
  PATH="$TMP/stubs:$PATH" timeout 120 "$plugin/bin/omarcraft" refresh -f >/dev/null 2>&1
  summary=$(PATH="$TMP/stubs:$PATH" timeout 60 "$plugin/bin/omarcraft" state 2>/dev/null |
    jq -r '"offline \(.offline), \(.counts.installed) installed, \(.counts.updates) updates, \(.apps | length) tools"' 2>/dev/null)
  if [[ $summary != "offline false,"* ]]; then
    echo "FAIL $ref ($old): after the upgrade the check does not come back online: ${summary:-no state}"; fail=1; continue
  fi
  echo "ok   $ref ($old) -> $new: $summary"
done
(( fail == 0 ))
