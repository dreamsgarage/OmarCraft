#!/bin/bash

# Offline tests for bin/omarcraft. Nothing here touches the network, the package database or the real
# Omarchy config: HOME and the XDG dirs point at a temporary folder, and every external command the
# script calls is a stub on PATH that records what it was asked to do.
#
#   bash tests/run.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_CACHE_HOME="$TMP/cache" XDG_STATE_HOME="$TMP/state" XDG_DATA_HOME="$TMP/data"
export XDG_CONFIG_HOME="$TMP/config"
mkdir -p "$HOME" "$TMP/bin" "$TMP/log"

# --- stubs --------------------------------------------------------------------------------------

stub() {
  # stub <name> <exit code> [stdout]: records its argv to $TMP/log/<name>
  printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"%s/log/%s"\n%s\nexit %s\n' "$TMP" "$1" "${3:+printf '%s\\n' \"$3\"}" "$2" >"$TMP/bin/$1"
  chmod +x "$TMP/bin/$1"
}
stub curl 7                                   # any network call fails loudly
# omarchy-shell: records its calls; `shell listShellConfig` answers with the config file, as the shell
# does once it applied a change. $TMP/shell-lag N makes it answer the previous content N times first.
cat >"$TMP/bin/omarchy-shell" <<STUB
#!/bin/bash
printf '%s\\n' "\$*" >>"$TMP/log/omarchy-shell"
if [[ \$1 == shell && \$2 == listShellConfig ]]; then
  lag=\$(cat "$TMP/shell-lag" 2>/dev/null || echo 0)
  if (( lag > 0 )); then echo \$(( lag - 1 )) >"$TMP/shell-lag"; cat "$TMP/shell-previous" 2>/dev/null; exit 0; fi
  cat "$TMP/config/omarchy/shell.json" 2>/dev/null
fi
exit 0
STUB
chmod +x "$TMP/bin/omarchy-shell"
stub omarchy-menu 0
stub omarchy-notification-send 0
stub omarchy-pkg-aur-add 0
stub omarchy-pkg-drop 0
stub yay 0
stub omarchy-launch-floating-terminal-with-presentation 0
stub setsid 0                                 # detached refreshes are recorded, never run
# pacman, answering the way the real one does (a fake that answers differently once hid a bug: 0.5.3), from
# two files the tests edit: $TMP/installed, what -Q prints ("name version"), and $TMP/sync-db, the
# configured repos' packages in repo order ("repo name version"). -Si takes any number of names and
# prints an entry for each repo that ships one, Repository first; for a name no repo ships it prints
# "error: package 'x' was not found" on stderr and exits 1. Field names are translated unless LC_ALL=C,
# as pacman's are. -Qm prints the installed packages no repo ships, with their versions. Anything else
# lists the installed packages. Typesetter and Planify come from the Arch repos, wordcraft-bin from
# Omarchy's repo; the other Craft apps are AUR packages.
cat >"$TMP/bin/pacman" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$TMP/log/pacman"
case "\$1" in
  -Si)
    shift; [[ \${1:-} == -- ]] && shift
    if [[ \${LC_ALL:-} == C ]]; then r=Repository n=Name v=Version; else r=Repositorio n=Nombre v=Versión; fi
    rc=0
    for pkg in "\$@"; do
      found=0
      while read -r repo name version; do
        [[ \$name == "\$pkg" ]] || continue
        found=1
        printf '%-15s : %s\n%-15s : %s\n%-15s : %s\n%-15s : %s\n\n' "\$r" "\$repo" "\$n" "\$name" "\$v" "\$version" \
          Description "An app: with a colon"
      done <"$TMP/sync-db"
      (( found )) || { echo "error: package '\$pkg' was not found" >&2; rc=1; }
    done
    exit \$rc ;;
  -Qm)
    while read -r name version; do
      awk -v p="\$name" '\$2 == p { f = 1 } END { exit !f }' "$TMP/sync-db" || echo "\$name \$version"
    done <"$TMP/installed"
    exit 0 ;;
esac
cat "$TMP/installed"
STUB
chmod +x "$TMP/bin/pacman"
printf 'photocraft-bin 0.8.0-1\nwordcraft-bin 1.0.0-1\nfilmcraft 1.0.0-1\ntypesetter 0.15.2-1\nother 1.0-1\n' >"$TMP/installed"
printf 'omarchy wordcraft-bin 1.0.0-1\nextra typesetter 0.16-1\nextra planify 1.0.0-1\n' >"$TMP/sync-db"
# The sync databases and pacman.conf the script stats to know whether the repos changed.
mkdir -p "$TMP/sync"; : >"$TMP/sync/omarchy.db"; : >"$TMP/sync/extra.db"; : >"$TMP/pacman.conf"
stub omarchy-pkg-add 0
stub omarchy-update 0
export PATH="$TMP/bin:$PATH"

calls() { cat "$TMP/log/$1" 2>/dev/null; }
reset_log() { rm -f "$TMP/log/$1"; }
# A new run's view of the repos (what a fresh process would load).
resync_memo() { SYNC_LOADED=0; SYNC_REPO=(); SYNC_VERSION=(); }
# The repos now ship exactly these ("repo name version"), as after a sync: the databases change on disk.
sync_db() { printf '%s\n' "$@" >"$TMP/sync-db"; printf x >>"$TMP/sync/omarchy.db"; resync_memo; }
# These packages are installed now ("name version").
installed_now() { printf '%s\n' "$@" >"$TMP/installed"; INSTALLED_LOADED=0; INSTALLED=(); }

# shellcheck source=../bin/omarcraft
source "$ROOT/bin/omarcraft"
PACMAN_SYNC_DIR="$TMP/sync"
PACMAN_CONF="$TMP/pacman.conf"

# Nothing the script touches may be real: every path it writes or deletes must point into the test
# folder, or the suite stops before any test.
for var in CACHE_DIR STATE_DIR DATA_HOME MENU_FILE LEGACY_VIKUNJA_DIR LEGACY_VIKUNJA_ENTRY LEGACY_VIKUNJA_PID \
  SYNC_CACHE CATALOG_FORMAT_FILE PACMAN_SYNC_DIR PACMAN_CONF; do
  [[ ${!var} == "$TMP"/* ]] || { echo "refusing to run: $var=${!var} is outside $TMP" >&2; exit 2; }
done
set +e

passed=0
failed=0
ok() { passed=$((passed + 1)); echo "ok   $1"; }
fail() { failed=$((failed + 1)); echo "FAIL $1${2:+: $2}"; }
expect_eq() { if [[ $2 == "$3" ]]; then ok "$1"; else fail "$1" "expected [$3], got [$2]"; fi; }
expect_true() { if eval "$2"; then ok "$1"; else fail "$1" "$2"; fi; }

parse_menu_jsonc() {
  sed -E '/^[[:space:]]*\/\//d' "$1" | perl -0pe 's/,(\s*[}\]])/$1/g' | jq -e . >/dev/null
}

# --- catalog parser ----------------------------------------------------------------------------

parsed=$(parse_upstream_catalog <"$ROOT/tests/fixtures/catalog.rs")
expect_eq "parser finds 13 apps" "$(wc -l <<<"$parsed")" "13"
expect_eq "parser reads the first app with its colours" "$(head -1 <<<"$parsed")" \
  $'photocraft\tPhotoCraft\tImage editing\tclassic\t#2f7bf5\t#1a5bc4\t#7fb0ff'
expect_eq "parser handles the struct-update form (pdfcraft)" \
  "$(grep '^pdfcraft' <<<"$parsed")" $'pdfcraft\tPdfCraft\tReading, organizing and protecting PDFs\tclassic\t#12a58a\t#0a7563\t#3fd6b8'
expect_eq "parser matches the built-in catalog" "$parsed" "$BUILTIN_CATALOG"

# --- first run: no cache, no network ------------------------------------------------------------

ensure_cache
expect_true "first run writes the built-in catalog without versions" "[[ \$(cut -f5 '$CATALOG' | sort -u) == '' ]]"
expect_eq "cache has the full column set" "$(awk -F'\t' '{print NF}' "$CATALOG" | sort -u)" "8"
expect_eq "first run marks every app as seen" "$(wc -l <"$SEEN")" "16"
expect_true "built-in catalog carries the extras" "grep -q '^memospot' \"$CATALOG\""
expect_eq "first run made no network call" "$(calls curl | wc -l)" "0"
catalog_fresh && fail "first-run cache is stale so versions are fetched at once" || ok "first-run cache is stale so versions are fetched at once"
expect_eq "first-run state keeps empty AUR versions empty (no column shift)" "$(state | jq -r '[.apps[] | select(.kind == "aur") | .aurVersion] | unique | join(",")')" ""
expect_eq "while a repo tool shows its repo's version at once" "$(state | jq -r '.apps[] | select(.id=="typesetter") | .aurVersion')" "0.16-1"
expect_eq "first-run state carries the colours" "$(state | jq -r '.apps[] | select(.id=="photocraft") | .color')" "#2f7bf5"

# --- groups and ids ----------------------------------------------------------------------------

expect_eq "office group" "$(for i in wordcraft deckcraft gridcraft pdfcraft photocraft; do group_for $i; echo; done | tr '\n' ' ')" "office office office office creative "
expect_eq "notes group" "$(group_for memospot)" "notes"
( valid_id "photocraft" ) 2>/dev/null && ok "valid id accepted" || fail "valid id accepted"
( valid_id 'x;rm -rf' ) 2>/dev/null && fail "unsafe id rejected" || ok "unsafe id rejected"
( known_id 'photocraft-git' ) 2>/dev/null && fail "id outside the catalog rejected" || ok "id outside the catalog rejected"
( group_ids bogus ) 2>/dev/null && fail "unknown group rejected" || ok "unknown group rejected"

# An older cache layout (five columns) is migrated and keeps its versions.
printf 'photocraft\tPhotoCraft\tImage editing\tclassic\t0.5.0-1\n' >"$CATALOG"
ensure_cache
expect_eq "old cache layout is migrated" "$(awk -F'\t' '{print NF}' "$CATALOG" | sort -u)" "8"
expect_eq "migration keeps known versions" "$(awk -F'\t' '$1=="photocraft"{print $5}' "$CATALOG")" "0.5.0-1"

# A cache from an older version lacks a tool this version knows: it is added and the cache made stale.
grep -v "^memospot" "$CATALOG" >"$CATALOG.tmp" && mv "$CATALOG.tmp" "$CATALOG" && touch "$CATALOG"
ensure_cache
expect_true "a missing built-in tool is added to an existing cache" "grep -q '^memospot' \"$CATALOG\""
catalog_fresh && fail "the cache is made stale so the version is fetched soon" || ok "the cache is made stale so the version is fetched soon"

# A cache that still lists a tool this version dropped (e.g. KolourPaint): it is pruned, keeping other
# versions, and a prune alone does not make a fresh cache stale.
printf 'kolourpaint	KolourPaint	Quick paint	extra	26.08.2-1	#ac4b37	#8a3626	#e9806a
' >>"$CATALOG"
touch "$CATALOG"
before_photo=$(awk -F'	' '$1=="photocraft"{print $5}' "$CATALOG")
ensure_cache
expect_true "a tool this version no longer knows is pruned from the cache" "! grep -q '^kolourpaint' \"$CATALOG\""
expect_eq "pruning keeps the other tools' versions" "$(awk -F'\t' '$1=="photocraft"{print $5}' "$CATALOG")" "$before_photo"
expect_true "a prune alone leaves a fresh cache fresh" "catalog_fresh"
# An unknown Craft app (upstream group classic/new) must be kept: upstream may list more than the
# built-in fallback, and only tools beyond ArtCraft (group extra) are ever dropped here.
printf 'brushcraft	BrushCraft	Future Craft app	new	1.2.3-1	#111111	#222222	#333333
' >>"$CATALOG"
touch "$CATALOG"
ensure_cache
expect_true "an unknown upstream Craft app is kept, not pruned" "grep -q '^brushcraft' \"$CATALOG\""
grep -v '^brushcraft' "$CATALOG" >"$CATALOG.t" && mv "$CATALOG.t" "$CATALOG"; touch "$CATALOG"

# Give the cache versions, as a successful refresh would.
while IFS=$'\t' read -r id name tagline group color inkl inkd; do
  printf '%s\t%s\t%s\t%s\t1.0.0-1\t%s\t%s\t%s\n' "$id" "$name" "$tagline" "$group" "$color" "$inkl" "$inkd"
done < <(builtin_rows) >"$CATALOG"
printf 'unpackaged\tUnpackaged\tNo AUR build yet\tnew\t\t\t\t\n' >>"$CATALOG"
touch "$CATALOG"

expect_eq "group all skips apps without an AUR build" "$(group_ids all | wc -l)" "16"
expect_eq "group notes" "$(group_ids notes | tr '\n' ' ')" "memospot planify "
expect_eq "group office" "$(group_ids office | tr '\n' ' ')" "pdfcraft wordcraft deckcraft gridcraft typesetter "
expect_eq "group creative" "$(group_ids creative | wc -l)" "9"

# --- installed state (pacman stubbed) -----------------------------------------------------------

reset_log pacman   # the first-run checks above ran state in subshells
is_installed photocraft && ok "-bin package counts as installed" || fail "-bin package counts as installed"
is_installed filmcraft && ok "source build counts as installed" || fail "source build counts as installed"
is_installed gridcraft && fail "missing app is not installed" || ok "missing app is not installed"
expect_eq "install source bin / source / none" "$(install_source photocraft)/$(install_source filmcraft)/$(install_source gridcraft)" "bin/source/"
expect_eq "installed version through a subshell" "$(installed_version photocraft)" "0.8.0-1"
expect_eq "outdated: only older -bin builds" "$(outdated_ids)" "photocraft"
expect_eq "missing office excludes installed apps" "$(missing_ids office | wc -l)" "3"
expect_eq "missing notes" "$(missing_ids notes | tr '\n' ' ')" "memospot planify "
( resync_memo; load_sync )
reset_log pacman
( INSTALLED_LOADED=0; load_installed; load_installed; resync_memo; load_sync; load_sync )
expect_eq "a run reads the installed packages once, and the repos not at all while they are unchanged" "$(calls pacman | tr '\n' ' ')" "-Q "
printf x >>"$TMP/sync/omarchy.db"
reset_log pacman
( resync_memo; load_sync; load_sync )
expect_eq "after a sync the repos are asked again, once" "$(calls pacman | cut -d' ' -f1-2 | tr '\n' ' ')" "-Si -- "
expect_true "in one query naming every tool's package" "calls pacman | grep -q -- '-Si -- photocraft-bin .* memospot-bin typesetter planify'"

# --- package kinds ------------------------------------------------------------------------------

expect_eq "kinds: Craft app, repo tool" "$(kind_for photocraft)/$(kind_for typesetter)" "aur/repo"
expect_eq "a package no repo ships is an AUR app, installed or not" "$(kind_for photocraft)/$(kind_for deckcraft)" "aur/aur"
expect_eq "a package Omarchy's repo ships is a repo app" "$(kind_for wordcraft)/$(install_source wordcraft)" "repo/repo"
expect_eq "packages of a tool" "$(pkgs_for typesetter)|$(pkg_for typesetter)|$(pkg_for memospot)|$(pkg_for photocraft)" \
  "typesetter|typesetter|memospot-bin|photocraft-bin"
expect_eq "a repo tool is installed from the repo" "$(install_source typesetter)" "repo"
expect_eq "Update all takes only AUR apps" "$(outdated_ids | tr '\n' ' ')" "photocraft "
expect_eq "repo apps behind the sync database are listed apart" "$(outdated_ids repo | tr '\n' ' ')" "typesetter "
expect_eq "a repo tool's version is its repo's, whatever the catalog column says" "$(version_var typesetter 9.9-1; echo "$VERSION")" "0.16-1"
expect_eq "an AUR tool's version is the catalog's, the AUR's" "$(version_var photocraft 1.1.0-1; echo "$VERSION")" "1.1.0-1"
expect_eq "the repos are read with pacman's field names untranslated, whatever the locale" \
  "$(LC_ALL=C.UTF-8 sync_table typesetter wordcraft-bin nope-bin 2>/dev/null | tr '\t\n' ',;')" "typesetter,extra,0.16-1;wordcraft-bin,omarchy,1.0.0-1;"
sync_table typesetter nope-bin >/dev/null
expect_eq "a package no repo ships is not an error" "$?" "0"
cat >"$TMP/bin/curl" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$TMP/log/curl"
echo '{"results":[{"Name":"photocraft-bin","Version":"1.1.0-1"},{"Name":"memospot-bin","Version":"1.0.5-1"},{"Name":"unrelated-bin","Version":"9"}]}'
STUB
expect_eq "AUR names map back to ids; pinned repo tools are not asked" "$(aur_versions photocraft memospot typesetter wordcraft | tr '\t\n' '= ')" \
  "photocraft=1.1.0-1 memospot=1.0.5-1 "
expect_true "the AUR is asked for -bin packages, one a repo ships too, never a pinned repo tool" \
  "calls curl | grep -q 'arg\[\]=memospot-bin' && calls curl | grep -q 'arg\[\]=wordcraft-bin' && ! calls curl | grep -q typesetter"
# curl answering with fixed JSON (stub cannot carry double quotes).
fake_aur() { printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"%s/log/curl"\ncat <<"JSON"\n%s\nJSON\n' "$TMP" "$1" >"$TMP/bin/curl"; chmod +x "$TMP/bin/curl"; }
fake_aur '{"version":5,"type":"multiinfo","resultcount":0,"results":[]}'
expect_eq "an AUR answer without the packages is an answer: no versions, no failure" "$(aur_versions photocraft; echo "rc=$?")" "rc=0"
fake_aur '{"version":5,"type":"error","resultcount":0,"results":[],"error":"Too many package names."}'
aur_versions photocraft >/dev/null
expect_eq "an AUR error is a failure, even with an empty results list" "$?" "1"
fake_aur '{"version":5,"type":"error","error":"Incorrect request type specified."}'
aur_versions photocraft >/dev/null
expect_eq "an AUR error is a failure" "$?" "1"
stub curl 7
aur_versions photocraft >/dev/null
expect_eq "so is an AUR that cannot be reached" "$?" "1"
reset_log curl

# --- state JSON --------------------------------------------------------------------------------

reset_log curl
st=$(state)
jq -e . <<<"$st" >/dev/null && ok "state is valid JSON" || fail "state is valid JSON"
expect_eq "state counts" "$(jq -c .counts <<<"$st")" '{"installed":4,"available":12,"updates":2,"unpackaged":1}'
expect_eq "state: a repo tool" "$(jq -c '.apps[] | select(.id=="typesetter") | [.group,.kind,.source,.installedVersion,.updateReady,.desktopId]' <<<"$st")" \
  '["office","repo","repo","0.15.2-1",true,"net.trowell.typesetter"]'
jq -e '.apps[] | select(.id=="vikunja")' <<<"$st" >/dev/null && fail "no app is Vikunja any more" || ok "no app is Vikunja any more"
expect_eq "state: Planify is a Notes tool from the Arch repos, with its own desktop id and colours" "$(jq -c '.apps[] | select(.id=="planify") | [.group,.upstreamGroup,.kind,.installed,.desktopId,.color,.inkLight,.inkDark]' <<<"$st")" \
  '["notes","extra","repo",false,"io.github.alainm23.planify","#3571e4","#2968e0","#7aa8ff"]'
expect_eq "Planify installs as the repo package planify" "$(pkgs_for planify)" "planify"
expect_eq "state app shape" "$(jq -c '.apps[] | select(.id=="photocraft") | [.group,.upstreamGroup,.installed,.source,.installedVersion,.aurVersion,.updateReady,.new,.desktopId]' <<<"$st")" \
  '["creative","classic",true,"bin","0.8.0-1","1.0.0-1",true,false,"ai.storyteller.photocraft"]'
expect_eq "state carries the extra tool with its own group, glyph and desktop id" "$(jq -c '.apps[] | select(.id=="memospot") | [.group,.upstreamGroup,.installed,.aurVersion,.desktopId,.color]' <<<"$st")" '["notes","extra",false,"1.0.0-1","memospot","#f6b028"]'
expect_eq "state: source build is installed, never update-ready" "$(jq -c '.apps[] | select(.id=="filmcraft") | [.installed,.source,.updateReady]' <<<"$st")" '[true,"source",false]'
expect_eq "state: unpackaged app has null source and no version" "$(jq -c '.apps[] | select(.id=="unpackaged") | [.installed,.source,.aurVersion]' <<<"$st")" '[false,null,""]'
expect_eq "state office group list" "$(jq -c .groups.office <<<"$st")" '["pdfcraft","wordcraft","deckcraft","gridcraft","typesetter"]'
expect_eq "state: no job, no last job" "$(jq -c '[.job,.lastJob,.offline,.refreshing]' <<<"$st")" '[null,null,false,false]'
expect_eq "state carries the brand colours" "$(jq -c '.apps[] | select(.id=="wordcraft") | [.color,.inkLight,.inkDark]' <<<"$st")" '["#3f5fe0","#2a44b8","#8ea2ff"]'
expect_eq "state: wordcraft-bin comes from Omarchy's repo and updates with the system" "$(jq -c '.apps[] | select(.id=="wordcraft") | [.group,.kind,.repo,.source,.installedVersion,.updateReady]' <<<"$st")" \
  '["office","repo","omarchy","repo","1.0.0-1",false]'
expect_eq "state names the repo of a repo tool, none for an AUR app" "$(jq -c '[.apps[] | select(.id=="typesetter" or .id=="photocraft") | .repo]' <<<"$st")" '["","extra"]'
expect_eq "state glyph is the verified codepoint" "$(printf '%s' "$(jq -r '.apps[] | select(.id=="wordcraft") | .glyph' <<<"$st")" | od -An -tx1 | tr -d ' \n')" "f3b08899"
expect_eq "state made no network call itself" "$(calls curl | wc -l)" "0"
expect_true "state is fast" "[[ \$( { TIMEFORMAT=%R; time state >/dev/null; } 2>&1 ) < 1.0 ]]"

# --- new-app detection -------------------------------------------------------------------------

grep -v figcraft "$SEEN" >"$SEEN.tmp" && mv "$SEEN.tmp" "$SEEN"
is_new figcraft && ok "unseen app is new" || fail "unseen app is new"
is_new photocraft && fail "seen app is not new" || ok "seen app is not new"
mark_seen figcraft
is_new figcraft && fail "mark_seen clears new" || ok "mark_seen clears new"
grep -v -e figcraft -e cadcraft "$SEEN" >"$SEEN.tmp" && mv "$SEEN.tmp" "$SEEN"
expect_eq "state reports the unseen packaged apps as new" "$(state | jq -r '[.apps[] | select(.new and .aurVersion != "")] | length')" "2"
mark_all_seen
expect_eq "seen clears every new mark" "$(state | jq -r '[.apps[] | select(.new)] | length')" "0"
expect_eq "seen does not duplicate ids" "$(sort "$SEEN" | uniq -d | wc -l)" "0"

# --- refresh: failure keeps the old data -------------------------------------------------------

cp "$CATALOG" "$TMP/catalog.before"
refresh -f >/dev/null 2>&1
expect_eq "refresh returns failure when the AUR is unreachable" "$?" "1"
cmp -s "$CATALOG" "$TMP/catalog.before" && ok "failed refresh leaves the catalog untouched" || fail "failed refresh leaves the catalog untouched"
expect_true "failed refresh leaves a marker" "[[ -f '$REFRESH_FAILED' ]]"
expect_eq "state reports offline after a failed refresh" "$(state | jq -c .offline)" "true"
reset_log setsid
state >/dev/null
state >/dev/null
expect_eq "state does not retry a check that failed moments ago" "$(calls setsid | grep -c '^bash -c')" "0"
touch -d '-11 minutes' "$REFRESH_FAILED"
state >/dev/null
expect_eq "state retries once the failure is older than the backoff" "$(calls setsid | grep -c '^bash -c')" "1"
touch "$REFRESH_FAILED"
refresh_due && fail "refresh_due is false right after a failure" || ok "refresh_due is false right after a failure"
rm -f "$REFRESH_FAILED"
refresh_due && ok "refresh_due is true with no failure recorded" || fail "refresh_due is true with no failure recorded"

# --- jobs --------------------------------------------------------------------------------------

reset_log omarchy-pkg-add; reset_log omarchy-pkg-aur-add; reset_log omarchy-shell
( job install wordcraft deckcraft ) >/dev/null 2>&1
expect_eq "job install exits with the package command's status" "$?" "0"
expect_eq "a package a repo ships installs through omarchy-pkg-add" "$(calls omarchy-pkg-add)" "wordcraft-bin"
expect_eq "and an AUR package through omarchy-pkg-aur-add" "$(calls omarchy-pkg-aur-add)" "deckcraft-bin"
expect_true "job file is gone after the job" "[[ ! -f '$JOB_FILE' ]]"
expect_eq "last job records verb, ids and exit" "$(jq -c '[.verb,.ids,.exit]' "$LAST_JOB_FILE")" '["install",["wordcraft","deckcraft"],0]'
expect_eq "job pokes the panel when it ends" "$(calls omarchy-shell | grep -c 'omarcraft.productivity refresh')" "1"

stub omarchy-pkg-aur-add 1
( job install gridcraft ) >/dev/null 2>&1
expect_eq "failed job exits non-zero" "$?" "1"
expect_eq "failed job is recorded" "$(jq -c '[.verb,.exit]' "$LAST_JOB_FILE")" '["install",1]'
expect_true "failed job leaves no job file" "[[ ! -f '$JOB_FILE' ]]"
stub omarchy-pkg-aur-add 0

( job install photocraft-git ) >/dev/null 2>&1 && fail "job refuses an id outside the catalog" || ok "job refuses an id outside the catalog"
( job install 'x;rm' ) >/dev/null 2>&1 && fail "job refuses an unsafe id" || ok "job refuses an unsafe id"
expect_eq "refused jobs never reach the package command" "$(calls omarchy-pkg-aur-add | wc -l)" "2"

reset_log yay
( job update ) >/dev/null 2>&1
expect_eq "job update with no ids takes every outdated app, through the helper" "$(calls yay)" "-S --noconfirm photocraft-bin"
expect_eq "job update records the outdated ids" "$(jq -c '[.verb,.ids]' "$LAST_JOB_FILE")" '["update",["photocraft"]]'
reset_log yay
( job update wordcraft ) >/dev/null 2>&1 && fail "a repo package is never updated by the AUR helper" || ok "a repo package is never updated by the AUR helper"
( job update photocraft ) >/dev/null 2>&1
expect_eq "job update <id> is package-exact" "$(calls yay)" "-S --noconfirm photocraft-bin"
( job update 'x;rm' ) >/dev/null 2>&1 && fail "job update refuses an unsafe id" || ok "job update refuses an unsafe id"
expect_eq "the single-app update was the only helper call since the reset" "$(calls yay | wc -l)" "1"

reset_log omarchy-pkg-drop
( job remove photocraft wordcraft ) >/dev/null 2>&1
expect_eq "job remove exits with the command's status" "$?" "0"
expect_eq "job remove delegates to omarchy-pkg-drop with -bin names" "$(calls omarchy-pkg-drop)" "photocraft-bin wordcraft-bin"
expect_eq "last job records the remove verb" "$(jq -c '[.verb,.ids,.exit]' "$LAST_JOB_FILE")" '["remove",["photocraft","wordcraft"],0]'
( job remove 'x;rm' ) >/dev/null 2>&1 && fail "job remove refuses an unsafe id" || ok "job remove refuses an unsafe id"
expect_eq "a refused removal never reaches the command" "$(calls omarchy-pkg-drop | wc -l)" "1"

# Repo tools install through omarchy-pkg-add, AUR tools through omarchy-pkg-aur-add, in one job.
reset_log omarchy-pkg-add; reset_log omarchy-pkg-aur-add
( job install typesetter memospot ) >/dev/null 2>&1
expect_eq "mixed install exits 0" "$?" "0"
expect_eq "repo packages go to omarchy-pkg-add" "$(calls omarchy-pkg-add)" "typesetter"
expect_eq "AUR packages go to omarchy-pkg-aur-add" "$(calls omarchy-pkg-aur-add)" "memospot-bin"
stub omarchy-pkg-add 1
reset_log omarchy-pkg-aur-add
( job install typesetter memospot ) >/dev/null 2>&1
expect_eq "a failed repo install fails the job" "$(jq -c '[.verb,.exit]' "$LAST_JOB_FILE")" '["install",1]'
expect_eq "and stops before the AUR part" "$(calls omarchy-pkg-aur-add | wc -l)" "0"
stub omarchy-pkg-add 0

reset_log omarchy-pkg-drop
( job remove memospot typesetter ) >/dev/null 2>&1
expect_eq "remove drops the packages, repo tools too" "$(calls omarchy-pkg-drop)" "memospot-bin typesetter"

reset_log yay
( job update typesetter ) >/dev/null 2>&1 && fail "a repo tool is never updated alone" || ok "a repo tool is never updated alone"
expect_eq "so the helper is not called for it" "$(calls yay | wc -l)" "0"
reset_log omarchy-update
( job system-update typesetter ) >/dev/null 2>&1
expect_eq "system-update runs Omarchy's update" "$(calls omarchy-update | wc -l)" "1"
expect_eq "and is recorded like any job" "$(jq -c '[.verb,.ids,.exit]' "$LAST_JOB_FILE")" '["system-update",["typesetter"],0]'

# An AUR package whose declared dependency is neither installed nor in the Arch repos would make the AUR
# helper compile it: the job refuses before anything is installed. Here the package declares libsoup 2,
# as kanri-bin did in 2026-10.
cat >"$TMP/bin/curl" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$TMP/log/curl"
echo '{"results":[{"Name":"memospot-bin","Version":"1.0.6-1","Depends":["gtk3","libsoup","webkit2gtk-4.1>=2.40"]}]}'
STUB
chmod +x "$TMP/bin/curl"
cp "$TMP/bin/pacman" "$TMP/pacman.real"
cat >"$TMP/bin/pacman" <<STUB
#!/bin/bash
case "\$1" in
  -T) [[ \$3 == libsoup ]] && { echo libsoup; exit 127; }; exit 0 ;;
  -Si) [[ \$3 == libsoup ]] && exit 1; exec "$TMP/pacman.real" "\$@" ;;
esac
exec "$TMP/pacman.real" "\$@"
STUB
chmod +x "$TMP/bin/pacman"
reset_log omarchy-pkg-aur-add; reset_log omarchy-notification-send
out=$( ( job install memospot ) 2>&1 )
expect_eq "a package that would compile a dependency is refused" "$(jq -c '[.verb,.ids,.exit]' "$LAST_JOB_FILE")" '["install",["memospot"],3]'
expect_eq "before the AUR helper runs" "$(calls omarchy-pkg-aur-add | wc -l)" "0"
expect_true "the terminal names the dependency" "grep -q 'needs libsoup' <<<'$out'"
expect_true "and so does a notification" "calls omarchy-notification-send | grep -q libsoup"
( job update photocraft ) >/dev/null 2>&1
expect_eq "an update is checked the same way" "$(jq -c '[.verb,.exit]' "$LAST_JOB_FILE")" '["update",3]'
cat >"$TMP/bin/curl" <<STUB
#!/bin/bash
echo '{"results":[{"Name":"memospot-bin","Version":"1.0.6-1","Depends":["gtk3","libsoup3","webkit2gtk-4.1"]}]}'
STUB
( job install memospot ) >/dev/null 2>&1
expect_eq "with every dependency installed or in the repos, it installs" "$(calls omarchy-pkg-aur-add)" "memospot-bin"
stub curl 7
reset_log omarchy-pkg-aur-add
( job install memospot ) >/dev/null 2>&1
expect_eq "when the AUR cannot be asked, the install goes ahead as before" "$(calls omarchy-pkg-aur-add)" "memospot-bin"
mv "$TMP/pacman.real" "$TMP/bin/pacman"

# Closing a job's terminal mid-job (a hangup) records it as interrupted, not with the status of the last
# step that had finished: here the package command is cut off by the hangup.
cat >"$TMP/bin/omarchy-pkg-drop" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$TMP/log/omarchy-pkg-drop"
kill -HUP "\$PPID"
exit 1
STUB
chmod +x "$TMP/bin/omarchy-pkg-drop"
( job remove memospot ) >/dev/null 2>&1
expect_eq "a job whose terminal closes is recorded as interrupted" "$(jq -c '[.verb,.exit,.interrupted]' "$LAST_JOB_FILE")" '["remove",130,true]'
expect_true "and leaves no job file" "[[ ! -f '$JOB_FILE' ]]"
stub omarchy-pkg-drop 0

# Closing the panel acknowledges a failed job it showed; a new failure is flagged again.
stub omarchy-pkg-aur-add 1
( job install gridcraft ) >/dev/null 2>&1
expect_eq "a failed job is not yet acknowledged" "$(state | jq -c '[.lastJob.exit, (.lastJob.seen // false)]')" '[1,false]'
mark_all_seen
expect_eq "closing the panel acknowledges it" "$(state | jq -c '[.lastJob.exit, .lastJob.seen]')" '[1,true]'
( job install gridcraft ) >/dev/null 2>&1
expect_eq "the next failure is flagged again" "$(state | jq -c '(.lastJob.seen // false)')" 'false'
stub omarchy-pkg-aur-add 0
( job install gridcraft ) >/dev/null 2>&1
mark_all_seen
expect_eq "a successful job is never marked" "$(jq -c 'has("seen")' "$LAST_JOB_FILE")" 'false'

# A job whose process died without end_job (terminal killed) is reported as interrupted, not running.
jq -nc '{verb:"install", ids:["soundcraft"], startedAt:"x", pid: 2147483000}' >"$JOB_FILE"
st=$(state)
expect_eq "stale job is not reported as running" "$(jq -c .job <<<"$st")" "null"
expect_eq "stale job is recorded as interrupted" "$(jq -c '[.lastJob.verb,.lastJob.exit,.lastJob.interrupted]' <<<"$st")" '["install",130,true]'

# A live job (our own pid) is reported as running.
jq -nc --argjson pid "$$" '{verb:"install", ids:["soundcraft"], startedAt:"x", pid:$pid}' >"$JOB_FILE"
expect_eq "live job is reported" "$(state | jq -c '[.job.verb,.job.ids]')" '["install",["soundcraft"]]'
( run_job install "" soundcraft ) >/dev/null 2>&1 && fail "second job refused while one runs" || ok "second job refused while one runs"
rm -f "$JOB_FILE"

# --- install / update front doors -------------------------------------------------------------

reset_log omarchy-launch-floating-terminal-with-presentation
( install_apps soundcraft ) >/dev/null 2>&1
term=$(calls omarchy-launch-floating-terminal-with-presentation)
expect_true "install opens one floating terminal running job install" "[[ \$(wc -l <<<'$term') == 1 && '$term' == *'job install soundcraft'* ]]"
expect_true "single install launches the app afterwards" "[[ '$term' == *'launch soundcraft'* ]]"
expect_true "the terminal command carries no helper string" "[[ '$term' != *yay* && '$term' != *sudo* ]]"
reset_log omarchy-launch-floating-terminal-with-presentation
( install_group office ) >/dev/null 2>&1
term=$(calls omarchy-launch-floating-terminal-with-presentation)
expect_true "group install lists only the missing apps" "[[ '$term' == *'job install pdfcraft deckcraft gridcraft'* && '$term' != *'launch '* ]]"
reset_log omarchy-launch-floating-terminal-with-presentation
( install_group notes ) >/dev/null 2>&1
term=$(calls omarchy-launch-floating-terminal-with-presentation)
expect_true "notes group installs memospot and planify through the same job" "[[ '$term' == *'job install memospot planify'* ]]"
reset_log setsid
( install_apps photocraft ) >/dev/null 2>&1
expect_true "installing an installed app launches it instead" "calls setsid | grep -q 'gtk-launch ai.storyteller.photocraft'"

# Launch focuses the app's own window by class; a window that only has the name in its title is not it.
fake_clients() {
  printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"%s/log/hyprctl"\n[[ $1 == clients ]] && echo %q\nexit 0\n' "$TMP" "$1" >"$TMP/bin/hyprctl"
  chmod +x "$TMP/bin/hyprctl"
}
fake_clients '[{"class":"org.omarchy.agent","title":"SoundCraft testing session","address":"0xa"},{"class":"firefox","title":"PhotoCraft docs","address":"0xb"}]'
reset_log setsid; reset_log hyprctl
( launch_or_focus soundcraft "uwsm-app -- gtk-launch ai.storyteller.soundcraft" ) >/dev/null 2>&1
expect_true "a terminal titled SoundCraft does not stop SoundCraft from launching" "calls setsid | grep -q 'gtk-launch ai.storyteller.soundcraft'"
( launch photocraft ) >/dev/null 2>&1
expect_true "nor does a browser tab titled PhotoCraft" "calls setsid | grep -q 'gtk-launch ai.storyteller.photocraft'"
expect_true "and neither window is focused" "! calls hyprctl | grep -q address"
fake_clients '[{"class":"ai.storyteller.photocraft","title":"untitled","address":"0xc"}]'
reset_log setsid; reset_log hyprctl
( launch photocraft ) >/dev/null 2>&1
expect_true "an open window of the app is focused" "calls hyprctl | grep -q 'address:0xc'"
expect_eq "and not launched again" "$(calls setsid | grep -c gtk-launch)" "0"
rm -f "$TMP/bin/hyprctl"
reset_log omarchy-launch-floating-terminal-with-presentation
( remove_apps photocraft ) >/dev/null 2>&1
term=$(calls omarchy-launch-floating-terminal-with-presentation)
expect_true "remove opens one floating terminal running job remove, no launch" "[[ \$(wc -l <<<'$term') == 1 && '$term' == *'job remove photocraft'* && '$term' != *'launch '* ]]"
reset_log omarchy-launch-floating-terminal-with-presentation
( remove_apps typesetter ) >/dev/null 2>&1
expect_true "a repo tool can be removed" "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job remove typesetter'"
reset_log omarchy-launch-floating-terminal-with-presentation
( update typesetter ) >/dev/null 2>&1
expect_true "updating a repo tool opens the system update" "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job system-update typesetter'"
reset_log omarchy-launch-floating-terminal-with-presentation
( update wordcraft ) >/dev/null 2>&1
expect_true "an Omarchy repo app opens the system update too" "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job system-update wordcraft'"
reset_log omarchy-launch-floating-terminal-with-presentation
( update ) >/dev/null 2>&1
expect_true "Update all leaves repo tools to the system" "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job update photocraft$'"
( remove_apps figcraft ) >/dev/null 2>&1 && fail "remove refuses an app that is not installed" || ok "remove refuses an app that is not installed"
( remove_apps filmcraft ) >/dev/null 2>&1 && fail "remove refuses a source build" || ok "remove refuses a source build"
expect_eq "refused removals open no terminal" "$(calls omarchy-launch-floating-terminal-with-presentation | wc -l)" "1"

# --- what 0.5.0 left for Vikunja ---------------------------------------------------------------
# 0.5.1 removes the desktop entry and launcher OmarCraft wrote, once, and leaves the data, the packages, a
# running server and the user's own files alone.
mkdir -p "$LEGACY_VIKUNJA_DIR" "$(dirname "$LEGACY_VIKUNJA_ENTRY")" "$STATE_DIR"
printf '[Desktop Entry]\nX-OmarCraft=true\nName=Vikunja Desktop\nExec="%s/launch" %%U\n' "$LEGACY_VIKUNJA_DIR" >"$LEGACY_VIKUNJA_ENTRY"
printf '#!/bin/bash\n' >"$LEGACY_VIKUNJA_DIR/launch"; echo data >"$LEGACY_VIKUNJA_DIR/vikunja.db"
echo 2147483000 >"$LEGACY_VIKUNJA_PID"
reset_log omarchy-notification-send
state >/dev/null
expect_true "0.5.0's Vikunja entry and launcher are removed" "[[ ! -e '$LEGACY_VIKUNJA_ENTRY' && ! -e '$LEGACY_VIKUNJA_DIR/launch' ]]"
expect_true "its data is kept" "[[ -f '$LEGACY_VIKUNJA_DIR/vikunja.db' ]]"
expect_true "a stale server pid file is cleared" "[[ ! -e '$LEGACY_VIKUNJA_PID' ]]"
expect_eq "the user is told where the data is" "$(calls omarchy-notification-send | grep -c 'omarcraft/vikunja')" "1"
state >/dev/null
expect_eq "once" "$(calls omarchy-notification-send | grep -c 'omarcraft/vikunja')" "1"
echo "$$" >"$LEGACY_VIKUNJA_PID"; state >/dev/null
expect_true "the pid file of a live process is left alone" "[[ -f '$LEGACY_VIKUNJA_PID' ]] && kill -0 $$"
rm -f "$LEGACY_VIKUNJA_PID"
printf '[Desktop Entry]\nName=My Vikunja\n' >"$LEGACY_VIKUNJA_ENTRY"; state >/dev/null
expect_true "an entry the user wrote is left alone" "grep -q 'My Vikunja' '$LEGACY_VIKUNJA_ENTRY'"
rm -f "$LEGACY_VIKUNJA_ENTRY"
# 0.5.0's launcher entry and panel may call its old commands once more after the update.
for old in vikunja-session vikunja-stop tray-sync; do
  "$ROOT/bin/omarcraft" "$old" >/dev/null 2>&1; expect_eq "the old command $old exits cleanly" "$?" "0"
done

# --- an app's source, whichever installed it -----------------------------------------------------
# Omarchy's own repo ships some Craft apps under their AUR names (wordcraft-bin and gridcraft-bin since
# 2026-11). The package manager and the AUR helper both take a name from a repo when one ships it, so for
# those the panel follows the repo, installed or not, and only offers what its action then delivers.

cp "$TMP/installed" "$TMP/installed.baseline"; cp "$TMP/sync-db" "$TMP/sync-db.baseline"; cp "$CATALOG" "$TMP/catalog.baseline"
aur_has() { awk -F'\t' -v OFS='\t' -v id="$1" -v v="$2" '$1 == id { $5 = v } { print }' "$CATALOG" >"$CATALOG.t" && mv "$CATALOG.t" "$CATALOG"; }
app() { state | jq -c --arg id "$1" ".apps[] | select(.id == \$id) | $2"; }

# The machine of the 0.5.3 report: Omarchy's builds installed, the AUR a release ahead.
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.15.2-1" "gridcraft-bin 0.16.1-1" "typesetter 0.16-1"
sync_db "omarchy wordcraft-bin 0.15.2-1" "omarchy gridcraft-bin 0.16.1-1" "extra typesetter 0.16-1" "extra planify 4.20.0-2"
aur_has photocraft 0.21.0-1; aur_has wordcraft 0.16.0-1; aur_has gridcraft 0.17.0-1
expect_eq "Omarchy's build is measured against Omarchy's repo, never the newer AUR build (0.5.3's stuck badge)" \
  "$(app gridcraft '[.kind,.repo,.source,.installedVersion,.aurVersion,.updateReady]')" '["repo","omarchy","repo","0.16.1-1","0.16.1-1",false]'
expect_eq "so no badge waits for an update the system cannot bring" "$(state | jq -c '[.apps[] | select(.updateReady) | .id]')" '[]'
expect_eq "and Update all has nothing to hand the AUR helper" "$(outdated_ids | wc -l)" "0"

sync_db "omarchy wordcraft-bin 0.16.0-1" "omarchy gridcraft-bin 0.16.1-1" "extra typesetter 0.16-1" "extra planify 4.20.0-2"
expect_eq "a newer build in Omarchy's repo shows the system badge" "$(app wordcraft '[.source,.aurVersion,.updateReady]')" '["repo","0.16.0-1",true]'
reset_log omarchy-launch-floating-terminal-with-presentation
( update wordcraft ) >/dev/null 2>&1
expect_true "which opens Omarchy's update" "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job system-update wordcraft'"
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.16.0-1" "gridcraft-bin 0.16.1-1" "typesetter 0.16-1"
expect_eq "and once the system is updated the badge is gone" "$(app wordcraft '.updateReady')" "false"

# Installed from the AUR while a repo ships the same name: the repo's build is the one that updates.
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.17.0-1" "gridcraft-bin 0.16.1-1"
expect_eq "an AUR build newer than the repo's: a repo app, no badge" "$(app wordcraft '[.kind,.source,.installedVersion,.updateReady]')" '["repo","repo","0.17.0-1",false]'
reset_log yay
( job update wordcraft ) >/dev/null 2>&1 && fail "the AUR helper is never asked for a name a repo ships" || ok "the AUR helper is never asked for a name a repo ships"
expect_eq "so nothing is reinstalled or downgraded (0.5.2 downgraded WordCraft that way)" "$(calls yay | wc -l)" "0"
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.15.1-1" "gridcraft-bin 0.16.1-1"
expect_eq "an AUR build older than the repo's: the system update brings the repo's" "$(app wordcraft '[.source,.aurVersion,.updateReady]')" '["repo","0.16.0-1",true]'

# Not installed, a repo ships it.
installed_now "photocraft-bin 0.21.0-1"
expect_eq "not installed: offered at the repo's version, from the repo" "$(app gridcraft '[.installed,.kind,.repo,.aurVersion]')" '[false,"repo","omarchy","0.16.1-1"]'
reset_log omarchy-pkg-add; reset_log omarchy-pkg-aur-add
( job install gridcraft ) >/dev/null 2>&1
expect_eq "installed with Omarchy's repo command" "$(calls omarchy-pkg-add)|$(calls omarchy-pkg-aur-add | wc -l)" "gridcraft-bin|0"
installed_now "photocraft-bin 0.21.0-1" "gridcraft-bin 0.16.1-1"
expect_eq "and no badge right after the install" "$(app gridcraft '[.source,.updateReady]')" '["repo",false]'

# A repo stops shipping an app, or starts: the app follows at the next sync, without waiting for a check.
sync_db "omarchy gridcraft-bin 0.16.1-1" "extra typesetter 0.16-1" "extra planify 4.20.0-2"
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.15.2-1" "gridcraft-bin 0.16.1-1"
expect_eq "a repo that stops shipping an app hands it back to the AUR, with the AUR's version" \
  "$(app wordcraft '[.kind,.repo,.source,.aurVersion,.updateReady]')" '["aur","","bin","0.16.0-1",true]'
reset_log yay
( job update wordcraft ) >/dev/null 2>&1
expect_eq "which updates it package-exact through the AUR helper" "$(calls yay)" "-S --noconfirm wordcraft-bin"
sync_db "omarchy gridcraft-bin 0.16.1-1" "omarchy deckcraft-bin 0.15.0-1" "extra typesetter 0.16-1" "extra planify 4.20.0-2"
expect_eq "a repo that starts shipping an app takes it over" "$(app deckcraft '[.kind,.repo,.aurVersion]')" '["repo","omarchy","0.15.0-1"]'

# A source build stays one when a repo ships the -bin package.
sync_db "omarchy filmcraft-bin 1.0.0-1" "extra typesetter 0.16-1" "extra planify 4.20.0-2"
installed_now "filmcraft 0.9.0-1"
expect_eq "a source build stays a source build, never update-ready, whatever ships the -bin" \
  "$(install_source filmcraft)|$(app filmcraft '[.source,.updateReady]')" 'source|["source",false]'
( remove_apps filmcraft ) >/dev/null 2>&1 && fail "and is not removed as a package" || ok "and is not removed as a package"

# A failed read of the repos is not cached: the next run asks again.
cp "$SYNC_CACHE" "$TMP/sync.before"
printf x >>"$TMP/sync/omarchy.db"
mv "$TMP/bin/pacman" "$TMP/pacman.fake"
cat >"$TMP/bin/pacman" <<STUB
#!/bin/bash
[[ \$1 == -Si ]] && { printf '%s\n' "\$*" >>"$TMP/log/pacman"; echo "error: could not read db 'omarchy' (Unrecognized archive format)" >&2; exit 1; }
exec "$TMP/pacman.fake" "\$@"
STUB
chmod +x "$TMP/bin/pacman"
( resync_memo; load_sync )
cmp -s "$SYNC_CACHE" "$TMP/sync.before" && ok "a database pacman cannot read is not cached" || fail "a database pacman cannot read is not cached"
mv "$TMP/pacman.fake" "$TMP/bin/pacman"
reset_log pacman
( resync_memo; load_sync )
expect_eq "the next run asks again" "$(calls pacman | cut -d' ' -f1 | tr '\n' ' ')" "-Si "
mkdir -p "$TMP/no-sync"; cp "$SYNC_CACHE" "$TMP/sync.before"
reset_log pacman
( PACMAN_SYNC_DIR="$TMP/no-sync"; resync_memo; load_sync; resync_memo; load_sync )
expect_eq "with no sync database where expected, every run asks and the answer still counts" "$(calls pacman | cut -d' ' -f1 | tr '\n' ' ')|$(PACMAN_SYNC_DIR="$TMP/no-sync"; resync_memo; kind_for filmcraft)" "-Si -Si |repo"
cmp -s "$SYNC_CACHE" "$TMP/sync.before" && ok "and nothing is kept" || fail "and nothing is kept"

# --- checks: the AUR's version for every tool; a failure only when the AUR does not answer ---------
cat >"$TMP/bin/curl" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$TMP/log/curl"
[[ "\$*" == *aur.archlinux.org* ]] || exit 22
printf '{"version":5,"type":"multiinfo","results":['
sep=""
for a in "\$@"; do
  [[ \$a == 'arg[]='* ]] || continue
  printf '%s{"Name":"%s","Version":"2.0.0-1"}' "\$sep" "\${a#'arg[]='}"; sep=,
done
printf ']}\n'
STUB
chmod +x "$TMP/bin/curl"
for id in photocraft vectorcraft filmcraft lightcraft pdfcraft effectcraft designcraft wordcraft deckcraft gridcraft \
  cadcraft soundcraft figcraft memospot; do echo "$id-bin 1.0.0-1"; done >"$TMP/installed"
printf 'typesetter 0.16-1\nplanify 4.20.0-2\n' >>"$TMP/installed"; INSTALLED_LOADED=0; INSTALLED=()
sync_db "omarchy wordcraft-bin 1.0.0-1" "omarchy gridcraft-bin 1.0.0-1" "extra typesetter 0.16-1" "extra planify 4.20.0-2"
rm -f "$REFRESH_FAILED"
refresh -f >/dev/null 2>&1
expect_eq "with every tool installed a check still asks the AUR, and succeeds (0.5.3 said OFFLINE)" "$?" "0"
expect_eq "so the panel is online" "$(state | jq -c .offline)" "false"
expect_eq "the version column holds the AUR's version of every tool not pinned to a repo" \
  "$(awk -F'\t' '$1 == "photocraft" || $1 == "gridcraft" || $1 == "typesetter" { print $1 "=" $5 }' "$CATALOG" | tr '\n' ' ')" \
  "photocraft=2.0.0-1 gridcraft=2.0.0-1 typesetter= "
expect_eq "an installed AUR app gets its badge from it, Omarchy's build does not" \
  "$(state | jq -c '[.apps[] | select(.id == "photocraft" or .id == "gridcraft") | [.id,.aurVersion,.updateReady]]')" \
  '[["photocraft","2.0.0-1",true],["gridcraft","1.0.0-1",false]]'
sync_db "omarchy wordcraft-bin 1.0.0-1" "omarchy gridcraft-bin 1.0.0-1" "extra typesetter 0.17-1" "extra planify 4.20.0-2"
out=$(check 2>/dev/null)
expect_true "check names an AUR update with the AUR's version" "grep -qx 'PhotoCraft 1.0.0-1 → 2.0.0-1' <<<'$out'"
expect_true "and a repo update with the repo's" "grep -qx 'Typesetter 0.16-1 → 0.17-1' <<<'$out'"
expect_true "never an AUR version for an app a repo ships" "! grep -q GridCraft <<<'$out'"
for cmd in state list check; do
  reset_log pacman
  ( INSTALLED_LOADED=0; INSTALLED=(); resync_memo; "$cmd" >/dev/null 2>&1 )
  expect_eq "$cmd reads the installed packages once and the unchanged repos not at all" "$(calls pacman | tr '\n' ' ')" "-Q "
done

# --- upgrade from an older version -----------------------------------------------------------------
rm -f "$CATALOG_FORMAT_FILE"; touch "$CATALOG"; now_iso >"$REFRESH_FAILED"
ensure_cache
catalog_fresh && fail "a cache an older version wrote is refreshed at once" || ok "a cache an older version wrote is refreshed at once"
expect_true "the old failure's retry wait goes with it" "[[ ! -f '$REFRESH_FAILED' ]]"
expect_eq "this version's format is recorded" "$(cat "$CATALOG_FORMAT_FILE")" "2"
touch "$CATALOG"; ensure_cache
expect_true "once: the next read leaves a fresh cache fresh" "catalog_fresh"

cp "$TMP/installed.baseline" "$TMP/installed"; INSTALLED_LOADED=0; INSTALLED=()
cp "$TMP/sync-db.baseline" "$TMP/sync-db"; printf x >>"$TMP/sync/omarchy.db"; resync_memo
cp "$TMP/catalog.baseline" "$CATALOG"
stub curl 7

# --- hygiene -----------------------------------------------------------------------------------

expect_eq "no privilege strings in the script" \
  "$(grep -cE '(^|[^a-z-])(sudo|pkexec)([^a-z-]|$)|pacman -R|pacman -S([^i]|$)' "$ROOT/bin/omarcraft")" "0"
expect_eq "the helper is called in exactly one place (the update job)" \
  "$(grep -cE '(^|[^a-z-])yay ' "$ROOT/bin/omarcraft")" "1"
expect_eq "manifest id" "$(jq -r .id "$ROOT/manifest.json")" "omarcraft.productivity"
expect_eq "IPC target matches the manifest id" "$IPC_TARGET" "$(jq -r .id "$ROOT/manifest.json")"
[[ -x $ROOT/bin/omarcraft ]] && ok "bin/omarcraft is executable" || fail "bin/omarcraft is executable"

# --- optional Omarchy menu section -------------------------------------------------------------

mkdir -p "$(dirname "$MENU_FILE")"
printf '{\n  // user comment\n  "personal": {"icon":"x","label":"Personal"},\n}\n' >"$MENU_FILE"
cp "$MENU_FILE" "$TMP/original.jsonc"
setup_menu >/dev/null
parse_menu_jsonc "$MENU_FILE" && ok "menu section parses as Omarchy JSONC" || fail "menu section parses as Omarchy JSONC"
grep -q '"personal"' "$MENU_FILE" && ok "user entries kept" || fail "user entries kept"
expect_eq "menu section has 8 entries" "$(grep -c '^  "\(install\.\)\{0,1\}omarcraft' "$MENU_FILE")" "8"
cp "$MENU_FILE" "$TMP/once.jsonc"
setup_menu >/dev/null
cmp -s "$MENU_FILE" "$TMP/once.jsonc" && ok "setup-menu is idempotent" || fail "setup-menu is idempotent"
remove_menu
cmp -s "$MENU_FILE" "$TMP/original.jsonc" && ok "remove-menu restores the file" || fail "remove-menu restores the file"

echo
echo "$passed passed, $failed failed"
(( failed == 0 ))
