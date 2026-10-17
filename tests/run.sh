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
export HOME="$TMP/home" XDG_CACHE_HOME="$TMP/cache" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME" "$TMP/bin" "$TMP/log"

# --- stubs --------------------------------------------------------------------------------------

stub() {
  # stub <name> <exit code> [stdout]: records its argv to $TMP/log/<name>
  printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"%s/log/%s"\n%s\nexit %s\n' "$TMP" "$1" "${3:+printf '%s\\n' \"$3\"}" "$2" >"$TMP/bin/$1"
  chmod +x "$TMP/bin/$1"
}
stub curl 7                                   # any network call fails loudly
stub omarchy-shell 0
stub omarchy-menu 0
stub omarchy-notification-send 0
stub omarchy-pkg-aur-add 0
stub omarchy-update-aur-pkgs 0
stub omarchy-launch-floating-terminal-with-presentation 0
stub omarchy-launch-or-focus 0
stub pacman 0 $'photocraft-bin 0.8.0-1\nwordcraft-bin 1.0.0-1\nfilmcraft 1.0.0-1\nother 1.0-1'
export PATH="$TMP/bin:$PATH"

calls() { cat "$TMP/log/$1" 2>/dev/null; }
reset_log() { rm -f "$TMP/log/$1"; }

# shellcheck source=../bin/omarcraft
source "$ROOT/bin/omarcraft"
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
expect_eq "parser reads the first app" "$(head -1 <<<"$parsed")" $'photocraft\tPhotoCraft\tImage editing\tclassic'
expect_eq "parser handles the struct-update form (pdfcraft)" \
  "$(grep '^pdfcraft' <<<"$parsed")" $'pdfcraft\tPdfCraft\tReading, organizing and protecting PDFs\tclassic'
expect_eq "parser matches the built-in catalog" "$parsed" "$BUILTIN_CATALOG"

# --- first run: no cache, no network ------------------------------------------------------------

ensure_cache
expect_true "first run writes the built-in catalog without versions" "[[ \$(cut -f5 '$CATALOG' | sort -u) == '' ]]"
expect_eq "first run marks every app as seen" "$(wc -l <"$SEEN")" "13"
expect_eq "first run made no network call" "$(calls curl | wc -l)" "0"

# --- groups and ids ----------------------------------------------------------------------------

expect_eq "office group" "$(for i in wordcraft deckcraft gridcraft pdfcraft photocraft; do group_for $i; echo; done | tr '\n' ' ')" "office office office office creative "
( valid_id "photocraft" ) 2>/dev/null && ok "valid id accepted" || fail "valid id accepted"
( valid_id 'x;rm -rf' ) 2>/dev/null && fail "unsafe id rejected" || ok "unsafe id rejected"
( known_id 'photocraft-git' ) 2>/dev/null && fail "id outside the catalog rejected" || ok "id outside the catalog rejected"
( group_ids bogus ) 2>/dev/null && fail "unknown group rejected" || ok "unknown group rejected"

# Give the cache versions, as a successful refresh would.
while IFS=$'\t' read -r id name tagline group; do
  printf '%s\t%s\t%s\t%s\t1.0.0-1\n' "$id" "$name" "$tagline" "$group"
done <<<"$BUILTIN_CATALOG" >"$CATALOG"
printf 'unpackaged\tUnpackaged\tNo AUR build yet\tnew\t\n' >>"$CATALOG"
touch "$CATALOG"

expect_eq "group all skips apps without an AUR build" "$(group_ids all | wc -l)" "13"
expect_eq "group office" "$(group_ids office | tr '\n' ' ')" "pdfcraft wordcraft deckcraft gridcraft "
expect_eq "group creative" "$(group_ids creative | wc -l)" "9"

# --- installed state (pacman stubbed) -----------------------------------------------------------

is_installed photocraft && ok "-bin package counts as installed" || fail "-bin package counts as installed"
is_installed filmcraft && ok "source build counts as installed" || fail "source build counts as installed"
is_installed gridcraft && fail "missing app is not installed" || ok "missing app is not installed"
expect_eq "install source bin / source / none" "$(install_source photocraft)/$(install_source filmcraft)/$(install_source gridcraft)" "bin/source/"
expect_eq "installed version through a subshell" "$(installed_version photocraft)" "0.8.0-1"
expect_eq "outdated: only older -bin builds" "$(outdated_ids)" "photocraft"
expect_eq "missing office excludes installed apps" "$(missing_ids office | wc -l)" "3"
expect_eq "one package-database read per run" "$(calls pacman | wc -l)" "1"

# --- state JSON --------------------------------------------------------------------------------

reset_log curl
st=$(state)
jq -e . <<<"$st" >/dev/null && ok "state is valid JSON" || fail "state is valid JSON"
expect_eq "state counts" "$(jq -c .counts <<<"$st")" '{"installed":3,"available":10,"updates":1,"unpackaged":1}'
expect_eq "state app shape" "$(jq -c '.apps[] | select(.id=="photocraft") | [.group,.upstreamGroup,.installed,.source,.installedVersion,.aurVersion,.updateReady,.new,.desktopId]' <<<"$st")" \
  '["creative","classic",true,"bin","0.8.0-1","1.0.0-1",true,false,"ai.storyteller.photocraft"]'
expect_eq "state: source build is installed, never update-ready" "$(jq -c '.apps[] | select(.id=="filmcraft") | [.installed,.source,.updateReady]' <<<"$st")" '[true,"source",false]'
expect_eq "state: unpackaged app has null source and no version" "$(jq -c '.apps[] | select(.id=="unpackaged") | [.installed,.source,.aurVersion]' <<<"$st")" '[false,null,""]'
expect_eq "state office group list" "$(jq -c .groups.office <<<"$st")" '["pdfcraft","wordcraft","deckcraft","gridcraft"]'
expect_eq "state: no job, no last job" "$(jq -c '[.job,.lastJob,.offline,.refreshing]' <<<"$st")" '[null,null,false,false]'
expect_eq "state glyph is the verified codepoint" "$(printf '%s' "$(jq -r '.apps[] | select(.id=="wordcraft") | .glyph' <<<"$st")" | od -An -tx1 | tr -d ' \n')" "f3b08899"
expect_eq "state made no network call itself" "$(calls curl | wc -l)" "0"
expect_true "state is fast" "[[ \$( { TIMEFORMAT=%R; time state >/dev/null; } 2>&1 ) < 1.0 ]]"

# --- new-app detection -------------------------------------------------------------------------

grep -v figcraft "$SEEN" >"$SEEN.tmp" && mv "$SEEN.tmp" "$SEEN"
is_new figcraft && ok "unseen app is new" || fail "unseen app is new"
is_new photocraft && fail "seen app is not new" || ok "seen app is not new"
mark_seen figcraft
is_new figcraft && fail "mark_seen clears new" || ok "mark_seen clears new"

# --- refresh: failure keeps the old data -------------------------------------------------------

cp "$CATALOG" "$TMP/catalog.before"
refresh -f >/dev/null 2>&1
expect_eq "refresh returns failure when the AUR is unreachable" "$?" "1"
cmp -s "$CATALOG" "$TMP/catalog.before" && ok "failed refresh leaves the catalog untouched" || fail "failed refresh leaves the catalog untouched"
expect_true "failed refresh leaves a marker" "[[ -f '$REFRESH_FAILED' ]]"
expect_eq "state reports offline after a failed refresh" "$(state | jq -c .offline)" "true"
rm -f "$REFRESH_FAILED"

# --- jobs --------------------------------------------------------------------------------------

reset_log omarchy-pkg-aur-add; reset_log omarchy-shell
( job install wordcraft deckcraft ) >/dev/null 2>&1
expect_eq "job install exits with the package command's status" "$?" "0"
expect_eq "job install delegates to omarchy-pkg-aur-add with -bin names" "$(calls omarchy-pkg-aur-add)" "wordcraft-bin deckcraft-bin"
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

reset_log omarchy-update-aur-pkgs
( job update ) >/dev/null 2>&1
expect_eq "job update delegates to omarchy-update-aur-pkgs" "$(calls omarchy-update-aur-pkgs | wc -l)" "1"
expect_eq "job update records the outdated ids" "$(jq -c '[.verb,.ids]' "$LAST_JOB_FILE")" '["update",["photocraft"]]'

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
( install_apps photocraft ) >/dev/null 2>&1
expect_eq "installing an installed app launches it instead" "$(calls omarchy-launch-or-focus | wc -l)" "1"

# --- hygiene -----------------------------------------------------------------------------------

expect_eq "no package-manager or privilege strings in the script" \
  "$(grep -cE '(^|[^a-z-])(yay|paru|sudo|pkexec)([^a-z-]|$)|pacman -S' "$ROOT/bin/omarcraft")" "0"
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
