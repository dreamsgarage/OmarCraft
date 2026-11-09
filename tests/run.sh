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
    shift; db="$TMP/sync-db"
    if [[ \${1:-} == --dbpath ]]; then db="\$2/fake-sync-db"; shift 2; fi
    [[ \${1:-} == -- ]] && shift
    if [[ \${LC_ALL:-} == C ]]; then r=Repository n=Name v=Version; else r=Repositorio n=Nombre v=Versión; fi
    rc=0
    for pkg in "\$@"; do
      found=0
      while read -r repo name version; do
        [[ \$name == "\$pkg" ]] || continue
        found=1
        printf '%-15s : %s\n%-15s : %s\n%-15s : %s\n%-15s : %s\n\n' "\$r" "\$repo" "\$n" "\$name" "\$v" "\$version" \
          Description "An app: with a colon"
      done < <(cat "\$db" 2>/dev/null)
      (( found )) || { echo "error: package '\$pkg' was not found" >&2; rc=1; }
    done
    exit \$rc ;;
  -Sp)
    # What installing the named packages would download, as pacman prints it with --print-format '%n %l':
    # from the private copy with --dbpath, skipping current ones with --needed, plus what $TMP/fresh-deps
    # ("pkg dep") says the install would also need. Addresses: https://pkgs.example/<repo>, or \$FAKE_PKG_URL.
    shift; db="$TMP/sync-db"; needed=0
    while (( \$# > 0 )); do
      case "\$1" in
        --dbpath) db="\$2/fake-sync-db"; shift 2 ;;
        --cachedir|--print-format) shift 2 ;;
        --needed) needed=1; shift ;;
        --) shift; break ;;
        *) break ;;
      esac
    done
    for pkg in "\$@"; do
      line=\$(awk -v p="\$pkg" '\$2 == p { print; exit }' "\$db" 2>/dev/null)
      [[ -n \$line ]] || { echo "error: target not found: \$pkg" >&2; exit 1; }
      read -r repo name version <<<"\$line"
      inst=\$(awk -v p="\$pkg" '\$1 == p { print \$2 }' "$TMP/installed")
      if (( needed )) && [[ -n \$inst ]] && (( \$(vercmp "\$inst" "\$version") >= 0 )); then continue; fi
      echo "\$name \${FAKE_PKG_URL:-https://pkgs.example/\$repo}/\$name-\$version-x86_64.pkg.tar.zst"
      awk -v p="\$pkg" '\$1 == p { print \$2 " https://pkgs.example/extra/" \$2 "-1-1-x86_64.pkg.tar.zst" }' "$TMP/fresh-deps" 2>/dev/null
    done
    exit 0 ;;
  -Q)
    # -Q with names: "name version" for each installed one; "error: package 'x' was not found" on stderr
    # and exit 1 for any other. Without names it lists every installed package, like the default below.
    shift; [[ \${1:-} == -- ]] && shift
    (( \$# == 0 )) && { cat "$TMP/installed"; exit 0; }
    rc=0
    for pkg in "\$@"; do
      line=\$(awk -v p="\$pkg" '\$1 == p { print; exit }' "$TMP/installed")
      if [[ -n \$line ]]; then echo "\$line"; else echo "error: package '\$pkg' was not found" >&2; rc=1; fi
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
cp "$TMP/sync-db" "$TMP/fresh-db"
# checkupdates, as pacman-contrib's: it refreshes a private copy of the package lists in $CHECKUPDATES_DB
# (here: copies $TMP/fresh-db, the repos as they are now, into it), prints "name old -> new" for each
# installed package with a newer build, exits 0 when it listed any and 2 when none, and 1 when it failed
# ($TMP/checkupdates-fail). The real one is never reached: this stub comes first on PATH.
cat >"$TMP/bin/checkupdates" <<STUB
#!/bin/bash
printf '%s|%s\n' "\$*" "\${CHECKUPDATES_DB:-}" >>"$TMP/log/checkupdates"
# A failed refresh can leave the copy broken: here it is emptied, so whatever reads it after a failure
# reads nothing.
[[ -f "$TMP/checkupdates-fail" ]] && { [[ -d \${CHECKUPDATES_DB:-/nonexistent} ]] && : >"\$CHECKUPDATES_DB/fake-sync-db"; exit 1; }
mkdir -p "\$CHECKUPDATES_DB" && cp "$TMP/fresh-db" "\$CHECKUPDATES_DB/fake-sync-db" || exit 1
n=0
while read -r name version; do
  new=\$(awk -v p="\$name" '\$2 == p { print \$3; exit }' "$TMP/fresh-db")
  if [[ -n \$new && \$new != "\$version" ]] && (( \$(vercmp "\$version" "\$new") < 0 )); then echo "\$name \$version -> \$new"; n=\$((n + 1)); fi
done <"$TMP/installed"
(( n > 0 )) && exit 0 || exit 2
STUB
chmod +x "$TMP/bin/checkupdates"
# pacman-conf, with the signature levels of a stock Omarchy pacman.conf (SigLevel Required; RemoteFileSigLevel
# unset, so it defaults to SigLevel); $TMP/remote-siglevel sets RemoteFileSigLevel.
cat >"$TMP/bin/pacman-conf" <<STUB
#!/bin/bash
case "\$1" in
  SigLevel) printf 'PackageRequired\nPackageTrustedOnly\nDatabaseOptional\nDatabaseTrustedOnly\n' ;;
  RemoteFileSigLevel) cat "$TMP/remote-siglevel" 2>/dev/null ;;
esac
exit 0
STUB
chmod +x "$TMP/bin/pacman-conf"
: >"$TMP/fresh-deps"
# The sync databases and pacman.conf the script stats to know whether the repos changed.
mkdir -p "$TMP/sync"; : >"$TMP/sync/omarchy.db"; : >"$TMP/sync/extra.db"; : >"$TMP/pacman.conf"
stub omarchy-pkg-add 0
stub omarchy-update 0
export PATH="$TMP/bin:$PATH"

calls() { cat "$TMP/log/$1" 2>/dev/null; }
reset_log() { rm -f "$TMP/log/$1"; }
# A new run's view of the repos (what a fresh process would load).
resync_memo() { SYNC_LOADED=0; SYNC_REPO=(); SYNC_VERSION=(); LATEST_LOADED=0; LATEST_VERSION=(); }
# The repos now ship exactly these ("repo name version"), as after a sync: the system's lists change on
# disk, and a check of the repos as they are now (checkupdates) would see the same. Tests that need the
# repos ahead of the system's lists write $TMP/fresh-db after this.
sync_db() { printf '%s\n' "$@" >"$TMP/sync-db"; cp "$TMP/sync-db" "$TMP/fresh-db"; printf x >>"$TMP/sync/omarchy.db"; resync_memo; }
# These packages are installed now ("name version").
installed_now() { printf '%s\n' "$@" >"$TMP/installed"; INSTALLED_LOADED=0; INSTALLED=(); }

# shellcheck source=../bin/omarcraft
source "$ROOT/bin/omarcraft"
PACMAN_SYNC_DIR="$TMP/sync"
PACMAN_CONF="$TMP/pacman.conf"
# The tests up to the 0.5.7 section describe 0.5.4 to 0.5.6, where an app a repo ships follows the repo:
# they run with that code switched on, to show it is kept unchanged. The 0.5.7 section switches it off,
# as the release ships.
FOLLOW_APP_REPOS=1

# Nothing the script touches may be real: every path it writes or deletes must point into the test
# folder, or the suite stops before any test.
for var in CACHE_DIR STATE_DIR DATA_HOME MENU_FILE LEGACY_VIKUNJA_DIR LEGACY_VIKUNJA_ENTRY LEGACY_VIKUNJA_PID \
  SYNC_CACHE CATALOG_FORMAT_FILE PACMAN_SYNC_DIR PACMAN_CONF REPO_DB REPO_LATEST; do
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
expect_eq "a package Omarchy's repo ships is a repo app that updates alone, like an AUR one" "$(kind_for wordcraft)/$(install_source wordcraft)" "repo/bin"
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
expect_eq "state: wordcraft-bin comes from Omarchy's repo and updates alone" "$(jq -c '.apps[] | select(.id=="wordcraft") | [.group,.kind,.repo,.source,.installedVersion,.updateReady]' <<<"$st")" \
  '["office","repo","omarchy","bin","1.0.0-1",false]'
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
( job update wordcraft ) >/dev/null 2>&1
expect_eq "an Omarchy repo package already at its repo's build: nothing to do, and the AUR helper is never asked" \
  "$?|$(calls yay | wc -l)" "0|0"
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
expect_true "an Omarchy repo app updates alone, like an AUR one" "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job update wordcraft$'"
reset_log omarchy-launch-floating-terminal-with-presentation
( update ) >/dev/null 2>&1
expect_true "Update all updates the apps that update alone and leaves an Arch repo tool to the system" \
  "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job update photocraft$'"
reset_log omarchy-launch-floating-terminal-with-presentation
( update wordcraft photocraft ) >/dev/null 2>&1
expect_true "an Omarchy repo app and an AUR app update together, each alone" \
  "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job update wordcraft photocraft$'"
reset_log omarchy-launch-floating-terminal-with-presentation
( update typesetter photocraft ) >/dev/null 2>&1
expect_true "asked with an AUR app, an Arch repo tool is left to the system, as before 0.5.6" \
  "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job update photocraft$'"
reset_log omarchy-launch-floating-terminal-with-presentation
( update photocraft ) >/dev/null 2>&1
expect_true "while AUR apps alone still update one package each through the helper" \
  "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job update photocraft$'"
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
# These cases predate the check of the repos as they are now: start without one (jobs above ran it).
rm -f "$REPO_LATEST"; resync_memo
aur_has() { awk -F'\t' -v OFS='\t' -v id="$1" -v v="$2" '$1 == id { $5 = v } { print }' "$CATALOG" >"$CATALOG.t" && mv "$CATALOG.t" "$CATALOG"; }
app() { state | jq -c --arg id "$1" ".apps[] | select(.id == \$id) | $2"; }

# The machine of the 0.5.3 report: Omarchy's builds installed, the AUR a release ahead.
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.15.2-1" "gridcraft-bin 0.16.1-1" "typesetter 0.16-1"
sync_db "omarchy wordcraft-bin 0.15.2-1" "omarchy gridcraft-bin 0.16.1-1" "extra typesetter 0.16-1" "extra planify 4.20.0-2"
aur_has photocraft 0.21.0-1; aur_has wordcraft 0.16.0-1; aur_has gridcraft 0.17.0-1
expect_eq "Omarchy's build is measured against Omarchy's repo, never the newer AUR build (0.5.3's stuck badge)" \
  "$(app gridcraft '[.kind,.repo,.source,.installedVersion,.aurVersion,.updateReady]')" '["repo","omarchy","bin","0.16.1-1","0.16.1-1",false]'
expect_eq "so no badge waits for an update the system cannot bring" "$(state | jq -c '[.apps[] | select(.updateReady) | .id]')" '[]'
expect_eq "and Update all has nothing to hand the AUR helper" "$(outdated_ids | wc -l)" "0"

sync_db "omarchy wordcraft-bin 0.16.0-1" "omarchy gridcraft-bin 0.16.1-1" "extra typesetter 0.16-1" "extra planify 4.20.0-2"
expect_eq "a newer build in Omarchy's repo shows a badge" "$(app wordcraft '[.source,.aurVersion,.updateReady]')" '["bin","0.16.0-1",true]'
reset_log omarchy-launch-floating-terminal-with-presentation
( update wordcraft ) >/dev/null 2>&1
expect_true "which updates it alone" "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job update wordcraft$'"
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.16.0-1" "gridcraft-bin 0.16.1-1" "typesetter 0.16-1"
expect_eq "and once the system is updated the badge is gone" "$(app wordcraft '.updateReady')" "false"

# Installed from the AUR while a repo ships the same name: the repo's build is the one that updates.
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.17.0-1" "gridcraft-bin 0.16.1-1"
expect_eq "an AUR build newer than the repo's: a repo app, no badge" "$(app wordcraft '[.kind,.source,.installedVersion,.updateReady]')" '["repo","bin","0.17.0-1",false]'
reset_log yay
( job update wordcraft ) >/dev/null 2>&1
expect_eq "updating it finds nothing newer in its repo, and the AUR helper is not asked for it" "$?|$(calls yay | grep -c -- '-S ')" "0|0"
expect_eq "so nothing is reinstalled or downgraded (0.5.2 downgraded WordCraft that way)" "$(calls yay | wc -l)" "0"
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.15.1-1" "gridcraft-bin 0.16.1-1"
expect_eq "an AUR build older than the repo's: the repo's build is offered" "$(app wordcraft '[.source,.aurVersion,.updateReady]')" '["bin","0.16.0-1",true]'

# Not installed, a repo ships it.
installed_now "photocraft-bin 0.21.0-1"
expect_eq "not installed: offered at the repo's version, from the repo" "$(app gridcraft '[.installed,.kind,.repo,.aurVersion]')" '[false,"repo","omarchy","0.16.1-1"]'
reset_log omarchy-pkg-add; reset_log omarchy-pkg-aur-add
( job install gridcraft ) >/dev/null 2>&1
expect_eq "installed with Omarchy's repo command" "$(calls omarchy-pkg-add)|$(calls omarchy-pkg-aur-add | wc -l)" "gridcraft-bin|0"
installed_now "photocraft-bin 0.21.0-1" "gridcraft-bin 0.16.1-1"
expect_eq "and no badge right after the install" "$(app gridcraft '[.source,.updateReady]')" '["bin",false]'

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
expect_eq "this version's format is recorded" "$(cat "$CATALOG_FORMAT_FILE")" "5"
touch "$CATALOG"; ensure_cache
expect_true "once: the next read leaves a fresh cache fresh" "catalog_fresh"

cp "$TMP/installed.baseline" "$TMP/installed"; INSTALLED_LOADED=0; INSTALLED=()
cp "$TMP/sync-db.baseline" "$TMP/sync-db"; printf x >>"$TMP/sync/omarchy.db"; resync_memo
cp "$TMP/catalog.baseline" "$CATALOG"
stub curl 7

# --- what comes from the network is bounded (marketplace review of 0.5.4, #14311) -----------------
# A hostile or broken answer can neither fill memory nor reach the panel: downloads stop at a size, every
# field kept from them is checked, and state bounds again whatever the cache holds.
fx="$ROOT/tests/fixtures/catalog.rs"
long=$(printf '%5000s' '' | tr ' ' x)
expect_eq "an app whose name is too long is dropped, the others kept" \
  "$(sed "s/\"PhotoCraft\",/\"$long\",/" "$fx" | parse_upstream_catalog | cut -f1 | tr '\n' ' ')" \
  "$(parse_upstream_catalog <"$fx" | cut -f1 | grep -v photocraft | tr '\n' ' ')"
expect_eq "so is one whose tagline holds a control character" \
  "$(sed 's/"Image editing",/"Image\x01editing",/' "$fx" | parse_upstream_catalog | grep -c '^photocraft')" "0"
expect_eq "and one whose id is not a plain id" "$(sed 's/"photocraft",/"photo craft;x",/' "$fx" | parse_upstream_catalog | grep -c photo)" "0"
expect_eq "at most MAX_APPS apps are kept" "$(MAX_APPS=5 parse_upstream_catalog <"$fx" | wc -l)" "5"

cat >"$TMP/bin/curl" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$TMP/log/curl"
case "\$*" in
  *small*) printf 'hello\n' ;;
  *exact*) head -c 1000 /dev/zero | tr '\0' a ;;
  *over*) head -c 1001 /dev/zero | tr '\0' a ;;
  *endless*) exec yes ;;
esac
STUB
chmod +x "$TMP/bin/curl"; reset_log curl
expect_eq "a download within its limit comes through whole" "$(fetch_bounded 1000 https://x/small)" "hello"
fetch_bounded 1000 https://x/exact >/dev/null
expect_eq "one exactly at its limit too" "$?" "0"
fetch_bounded 1000 https://x/over >/dev/null
expect_eq "one byte over is refused" "$?" "1"
expect_eq "and nothing of it is printed" "$(fetch_bounded 1000 https://x/over | wc -c)" "0"
fetch_bounded 1000 https://x/endless >/dev/null
expect_eq "an endless answer is cut off and refused" "$?" "1"
expect_true "curl is told the limit as well" "calls curl | grep -q -- '--max-filesize 1000'"

# A hostile catalog during a real check: an endless download, then AUR versions that are not versions.
cat >"$TMP/bin/curl" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$TMP/log/curl"
[[ "\$*" == *raw.githubusercontent.com* ]] && { yes "    app(" | head -c 30000000; exit 0; }
printf '{"version":5,"type":"multiinfo","results":[{"Name":"photocraft-bin","Version":"9.0.0-1"},'
printf '{"Name":"vectorcraft-bin","Version":"9.0.0-1; rm -rf x"},{"Name":"filmcraft-bin","Version":"$long"}]}\n'
STUB
chmod +x "$TMP/bin/curl"; rm -f "$REFRESH_FAILED"
refresh -f >/dev/null 2>&1
expect_eq "a 30 MB catalog download falls back to the built-in list, and the check succeeds" "$?|$(wc -l <"$CATALOG")" "0|16"
expect_eq "a well-formed AUR version is kept, a malformed or overlong one is not" \
  "$(awk -F'\t' '$1 == "photocraft" || $1 == "vectorcraft" || $1 == "filmcraft" { print $1 "=" $5 }' "$CATALOG" | tr '\n' ' ')" \
  "photocraft=9.0.0-1 vectorcraft= filmcraft= "
# A well-formed catalog padded past its limit is refused whole, not read up to the limit: the built-in
# list stays (the padded copy says "Image editing, padded").
{ printf '// %s\n' "$long" "$long" "$long" "$long" "$long" "$long" "$long" "$long"
  for i in $(seq 1 40); do printf '// %s\n' "$long"; done
  sed 's/"Image editing",/"Image editing, padded",/' "$fx"; } >"$TMP/padded.rs"
cat >"$TMP/bin/curl" <<STUB
#!/bin/bash
[[ "\$*" == *raw.githubusercontent.com* ]] && exec cat "$TMP/padded.rs"
printf '{"version":5,"type":"multiinfo","results":[{"Name":"photocraft-bin","Version":"9.0.0-1"}]}\n'
STUB
chmod +x "$TMP/bin/curl"
CATALOG_MAX_BYTES=200000 refresh -f >/dev/null 2>&1
expect_eq "a catalog over its limit is refused whole: the built-in list stays" \
  "$(wc -c <"$TMP/padded.rs" | awk '{ print ($1 > 200000) }')|$(awk -F'\t' '$1 == "photocraft" { print $3 }' "$CATALOG")" "1|Image editing"
cat >"$TMP/bin/curl" <<STUB
#!/bin/bash
[[ "\$*" == *raw.githubusercontent.com* ]] && exit 22
printf '{"version":5,"type":"multiinfo","results":['; head -c 1100000 /dev/zero | tr '\0' ' '; printf ']}\n'
STUB
cp "$CATALOG" "$TMP/catalog.before"
refresh -f >/dev/null 2>&1
expect_eq "an AUR answer over its limit fails the check and keeps the list" "$?|$(cmp -s "$CATALOG" "$TMP/catalog.before" && echo kept)" "1|kept"
fake_aur '{"results":[{"Name":"memospot-bin","Version":"1.0.5-1","Depends":["gtk3","a;b","$(x)","ok-dep>=1"]}]}'
reset_log pacman
aur_source_deps memospot-bin >/dev/null
expect_true "a declared dependency that is not a package name never reaches pacman" \
  "calls pacman | grep -q -- '-T -- ok-dep' && ! calls pacman | grep -q -e 'a;b' -e 'x)'"

# A cache written before 0.5.5 may hold anything: state bounds it on the way out.
awk -F'\t' -v OFS='\t' -v long="$long" '$1 == "photocraft" { $2 = long; $3 = long; $5 = "1.0;x"; $6 = "red" } { print }' \
  "$TMP/catalog.baseline" >"$CATALOG"
for i in $(seq 1 200); do printf 'zz%s\tZz\tZz\tnew\t1.0-1\t#111111\t#222222\t#333333\n' "$i"; done >>"$CATALOG"
touch "$CATALOG"
st=$(state)
expect_eq "state bounds a name and a tagline, and drops a colour or a version that is not one" \
  "$(jq -c '.apps[] | select(.id=="photocraft") | [(.name | length), (.tagline | length), .color, .aurVersion]' <<<"$st")" '[48,96,"",""]'
expect_eq "and lists at most MAX_APPS + 8 tools" "$(jq '.apps | length' <<<"$st")" "$((MAX_APPS + 8))"
size=$(wc -c <<<"$st")
expect_true "so its whole answer stays small ($size bytes)" "(( $size < 100000 ))"
cp "$TMP/catalog.baseline" "$CATALOG"
stub curl 7

# --- the repos as they are now (0.5.6) -------------------------------------------------------------
# The system's lists are as old as its last update: on 2026-11-08 they said GridCraft 0.16.1 while
# Omarchy's repo shipped 0.17.0, so 0.5.5 showed no update. A check now reads the repos as they are
# through checkupdates, into a private copy in the cache.
cp "$TMP/installed" "$TMP/installed.b6"; cp "$TMP/sync-db" "$TMP/sync-db.b6"; cp "$TMP/fresh-db" "$TMP/fresh-db.b6"
cp "$CATALOG" "$TMP/catalog.b6"
fake_aur '{"version":5,"type":"multiinfo","resultcount":0,"results":[]}'
installed_now "gridcraft-bin 0.16.1-1" "wordcraft-bin 0.15.2-1" "photocraft-bin 1.0.0-1"
sync_db "omarchy gridcraft-bin 0.16.1-1" "omarchy wordcraft-bin 0.15.2-1" "extra typesetter 0.16-1" "extra planify 1.0.0-1"
printf 'omarchy gridcraft-bin 0.17.0-1\nomarchy wordcraft-bin 0.16.0-1\nextra typesetter 0.16-1\nextra planify 1.0.0-1\n' >"$TMP/fresh-db"
reset_log checkupdates; rm -f "$REFRESH_FAILED" "$REPO_LATEST"
refresh -f >/dev/null 2>&1
expect_eq "a check reads the repos as they are now, into a private copy in the cache" "$?|$(calls checkupdates)" "0|--nocolor|$REPO_DB"
expect_eq "an installed app whose repo has a newer build than the stale lists shows a badge" \
  "$(app gridcraft '[.kind,.repo,.source,.installedVersion,.aurVersion,.updateReady]')" '["repo","omarchy","bin","0.16.1-1","0.17.0-1",true]'
expect_eq "so does the other one" "$(app wordcraft '[.aurVersion,.updateReady]')" '["0.16.0-1",true]'
reset_log omarchy-launch-floating-terminal-with-presentation
( update gridcraft ) >/dev/null 2>&1
expect_true "Enter on it updates it alone" "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job update gridcraft$'"
out=$(check 2>/dev/null)
expect_true "the six-hourly check names the repo's build" "grep -qx 'GridCraft 0.16.1-1 → 0.17.0-1' <<<'$out'"
expect_eq "and Update all takes them" "$(outdated_ids | tr '\n' ' ')" "wordcraft gridcraft "
installed_now "gridcraft-bin 0.17.0-1" "wordcraft-bin 0.16.0-1" "photocraft-bin 1.0.0-1"
sync_db "omarchy gridcraft-bin 0.17.0-1" "omarchy wordcraft-bin 0.16.0-1" "extra typesetter 0.16-1" "extra planify 1.0.0-1"
expect_eq "after Omarchy's update both badges are gone" "$(state | jq -c '[.apps[] | select(.updateReady) | .id]')" '[]'

# Not installed: an install brings the system lists' build, so the tile offers that one; once it is
# installed, the repo's newer build shows as a system update.
installed_now "photocraft-bin 1.0.0-1"
sync_db "omarchy gridcraft-bin 0.16.1-1" "omarchy wordcraft-bin 0.15.2-1" "extra typesetter 0.16-1" "extra planify 1.0.0-1"
expect_eq "not installed: offered at what an install brings now" "$(app gridcraft '[.installed,.aurVersion,.updateReady]')" '[false,"0.16.1-1",false]'
installed_now "photocraft-bin 1.0.0-1" "gridcraft-bin 0.16.1-1"
expect_eq "installed: the repo's newer build as a system update" "$(app gridcraft '[.aurVersion,.updateReady]')" '["0.17.0-1",true]'

cp "$REPO_LATEST" "$TMP/latest.before"; touch "$TMP/checkupdates-fail"
refresh -f >/dev/null 2>&1
expect_eq "a failed repo check keeps the previous answer, and the check itself succeeds" \
  "$?|$(cmp -s "$REPO_LATEST" "$TMP/latest.before" && echo kept)" "0|kept"
rm -f "$TMP/checkupdates-fail"
printf 'gridcraft-bin\tomarchy\t9.9.9;rm\n' >"$REPO_LATEST"; resync_memo
expect_eq "a malformed version in the copy is ignored" "$(app gridcraft '.aurVersion')" '"0.16.1-1"'
expect_eq "a check every six hours, like the panel's timer" "$CATALOG_MAX_AGE_MINUTES" "360"
touch -d '-7 hours' "$CATALOG"
catalog_fresh && fail "a list older than six hours is checked again" || ok "a list older than six hours is checked again"

cp "$TMP/installed.b6" "$TMP/installed"; INSTALLED_LOADED=0; INSTALLED=()
cp "$TMP/sync-db.b6" "$TMP/sync-db"; cp "$TMP/fresh-db.b6" "$TMP/fresh-db"; printf x >>"$TMP/sync/omarchy.db"; resync_memo
cp "$TMP/catalog.b6" "$CATALOG"; rm -f "$REPO_LATEST"
stub curl 7

# --- an app from Omarchy's repo updates alone (0.5.6) ------------------------------------------------
# Like an AUR app, without Omarchy's whole update (the author's decision): the private copy of the repos is
# refreshed, pacman resolves the update against it, and the app is installed alone from its repo's https
# address, pacman checking its signature. When the update needs anything else, nothing is installed.
cp "$TMP/installed" "$TMP/installed.b7"; cp "$TMP/sync-db" "$TMP/sync-db.b7"; cp "$TMP/fresh-db" "$TMP/fresh-db.b7"
installed_now "gridcraft-bin 0.16.1-1" "wordcraft-bin 0.15.2-1" "photocraft-bin 1.0.0-1" "typesetter 0.15.2-1"
sync_db "omarchy gridcraft-bin 0.16.1-1" "omarchy wordcraft-bin 0.15.2-1" "extra typesetter 0.15.2-1" "extra planify 1.0.0-1"
printf 'omarchy gridcraft-bin 0.17.0-1\nomarchy wordcraft-bin 0.16.0-1\nextra typesetter 0.16-1\nextra planify 1.0.0-1\n' >"$TMP/fresh-db"
want_sp="-Sp --needed --dbpath $REPO_DB --cachedir $REPO_DB/no-cache --print-format %n %l -- gridcraft-bin"
reset_log yay; reset_log checkupdates; reset_log omarchy-update; reset_log pacman
( job update gridcraft ) >/dev/null 2>&1
expect_eq "an app from Omarchy's repo updates alone: the job succeeds" "$?" "0"
expect_eq "after refreshing the private copy of the repos" "$(calls checkupdates | wc -l)" "1"
expect_true "pacman resolves it against that copy and prints the repo's address" "calls pacman | grep -qxF -- \"\$want_sp\""
expect_eq "the helper installs that one package from its https address" "$(calls yay)" \
  "-U --noconfirm https://pkgs.example/omarchy/gridcraft-bin-0.17.0-1-x86_64.pkg.tar.zst"
expect_eq "Omarchy's whole update is not run" "$(calls omarchy-update | wc -l)" "0"
expect_eq "and the job is recorded as an update" "$(jq -c '[.verb,.ids,.exit]' "$LAST_JOB_FILE")" '["update",["gridcraft"],0]'

echo "gridcraft-bin libfoo" >"$TMP/fresh-deps"
reset_log yay; reset_log omarchy-notification-send
out=$( ( job update gridcraft ) 2>&1 )
expect_eq "when the update needs another package too, nothing is installed" \
  "$(jq -c '[.verb,.exit]' "$LAST_JOB_FILE")|$(calls yay | wc -l)" '["update",4]|0'
expect_true "the terminal names it, and Omarchy's update as the way" "grep -q 'also needs libfoo' <<<\"\$out\" && grep -q 'omarchy update' <<<\"\$out\""
expect_true "and so does a notification" "calls omarchy-notification-send | grep -q libfoo"
: >"$TMP/fresh-deps"

reset_log yay
( FAKE_PKG_URL=http://pkgs.example/omarchy; export FAKE_PKG_URL; job update gridcraft ) >/dev/null 2>&1
expect_eq "an address that is not https is refused" "$(jq -c '.exit' "$LAST_JOB_FILE")|$(calls yay | wc -l)" "1|0"
printf 'PackageOptional\nPackageTrustedOnly\n' >"$TMP/remote-siglevel"; reset_log yay
( job update gridcraft ) >/dev/null 2>&1
expect_eq "nothing is installed from an address where pacman would not require its signature" \
  "$(jq -c '.exit' "$LAST_JOB_FILE")|$(calls yay | wc -l)" "1|0"
rm -f "$TMP/remote-siglevel"
touch "$TMP/checkupdates-fail"; reset_log yay
( job update gridcraft ) >/dev/null 2>&1
expect_eq "nor when the repos cannot be read just then" "$(jq -c '.exit' "$LAST_JOB_FILE")|$(calls yay | wc -l)" "1|0"
rm -f "$TMP/checkupdates-fail"

reset_log yay
( job update gridcraft photocraft ) >/dev/null 2>&1
expect_eq "an Omarchy repo app and an AUR app in one job: each alone" "$(calls yay | tr '\n' '|')" \
  "-U --noconfirm https://pkgs.example/omarchy/gridcraft-bin-0.17.0-1-x86_64.pkg.tar.zst|-S --noconfirm photocraft-bin|"
installed_now "gridcraft-bin 0.17.0-1" "wordcraft-bin 0.15.2-1" "photocraft-bin 1.0.0-1" "typesetter 0.15.2-1"
reset_log yay
( job update gridcraft ) >/dev/null 2>&1
expect_eq "an app already at its repo's newest build is left alone" "$(jq -c '.exit' "$LAST_JOB_FILE")|$(calls yay | wc -l)" "0|0"
( job update typesetter ) >/dev/null 2>&1 && fail "a tool from the Arch repos never updates alone" || ok "a tool from the Arch repos never updates alone"

installed_now "gridcraft-bin 0.16.1-1" "wordcraft-bin 0.15.2-1" "photocraft-bin 1.0.0-1" "typesetter 0.15.2-1"
reset_log omarchy-launch-floating-terminal-with-presentation
( update ) >/dev/null 2>&1
expect_true "Update all updates the Omarchy repo apps alone and leaves the Arch repo tool to the system" \
  "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job update wordcraft gridcraft$'"
installed_now "gridcraft-bin 0.17.0-1" "wordcraft-bin 0.16.0-1" "photocraft-bin 1.0.0-1" "typesetter 0.15.2-1"
reset_log omarchy-launch-floating-terminal-with-presentation
( update ) >/dev/null 2>&1
expect_true "with only an Arch repo tool pending, Update all runs Omarchy's update rather than nothing" \
  "calls omarchy-launch-floating-terminal-with-presentation | grep -q 'job system-update typesetter$'"

cp "$TMP/installed.b7" "$TMP/installed"; INSTALLED_LOADED=0; INSTALLED=()
cp "$TMP/sync-db.b7" "$TMP/sync-db"; cp "$TMP/fresh-db.b7" "$TMP/fresh-db"; printf x >>"$TMP/sync/omarchy.db"; resync_memo
rm -f "$REPO_LATEST"

# --- 0.5.7: a Craft app a repo also ships comes from the AUR (FOLLOW_APP_REPOS=0) -----------------
# The author's machine on 2026-11-09: Omarchy's builds of WordCraft and GridCraft installed, ArtCraft's
# newer releases in the AUR; WordCraft's own prompt offered 0.17.0 while OmarCraft showed nothing.

FOLLOW_APP_REPOS=0
for f in installed sync-db fresh-db; do cp "$TMP/$f" "$TMP/$f.before057"; done
cp "$CATALOG" "$TMP/catalog.before057"
aur_now() { aur_has "$@"; AUR_LOADED=0; AUR_OF=(); }
rm -f "$REPO_LATEST"
installed_now "photocraft-bin 0.21.0-1" "wordcraft-bin 0.16.0-1" "gridcraft-bin 0.17.0-1" "typesetter 0.16-1"
sync_db "omarchy wordcraft-bin 0.16.0-1" "omarchy gridcraft-bin 0.17.0-1" "extra typesetter 0.16-1" "extra planify 4.20.0-2"
aur_now photocraft 0.21.0-1; aur_now wordcraft 0.17.0-1; aur_now gridcraft 0.18.0-1

expect_eq "0.5.7: Omarchy's WordCraft installed, the AUR newer: an AUR app with a badge (the author's report)" \
  "$(app wordcraft '[.kind,.repo,.source,.installedVersion,.aurVersion,.updateReady]')" '["aur","","bin","0.16.0-1","0.17.0-1",true]'
expect_eq "0.5.7: GridCraft the same, at the AUR's 0.18.0" "$(app gridcraft '[.kind,.aurVersion,.updateReady]')" '["aur","0.18.0-1",true]'
expect_eq "0.5.7: Typesetter, pinned to the Arch repos, is not affected" "$(app typesetter '[.kind,.repo]')" '["repo","extra"]'
expect_eq "0.5.7: both are what Update all updates, none goes to the system update" \
  "$(outdated_ids | tr '\n' ' ')|$(outdated_ids repo | tr '\n' ' ')" "wordcraft gridcraft |"
expect_true "0.5.7: list shows the AUR's build ready, not Omarchy's repo" \
  "list | grep '^wordcraft' | grep -q 'update ready 0.17.0-1' && ! list | grep '^wordcraft' | grep -q 'omarchy repo'"

reset_log yay; reset_log checkupdates; reset_log omarchy-update
( job update wordcraft ) >/dev/null 2>&1
expect_eq "0.5.7: its update names the AUR, or yay would take Omarchy's build" "$?|$(calls yay)" "0|-S --noconfirm aur/wordcraft-bin"
expect_eq "0.5.7: and runs neither the repo update nor Omarchy's update" "$(calls checkupdates | wc -l)|$(calls omarchy-update | wc -l)" "0|0"

aur_now photocraft 0.22.0-1
reset_log yay
( job update ) >/dev/null 2>&1
expect_eq "0.5.7: Update all: one helper call, the AUR prefix only where a repo ships the name" \
  "$(calls yay)" "-S --noconfirm photocraft-bin aur/wordcraft-bin aur/gridcraft-bin"
aur_now photocraft 0.21.0-1

# Install from the tile. The fake yay installs nothing, so the package is put in place first where the
# install is meant to succeed.
reset_log yay; reset_log omarchy-pkg-aur-add; reset_log omarchy-pkg-add
installed_now "photocraft-bin 0.21.0-1"
expect_eq "0.5.7: not installed: offered at the AUR's version, not as from Omarchy's repo" \
  "$(app gridcraft '[.installed,.kind,.repo,.aurVersion]')" '[false,"aur","","0.18.0-1"]'
installed_now "photocraft-bin 0.21.0-1" "gridcraft-bin 0.18.0-1"
( job install gridcraft ) >/dev/null 2>&1
expect_eq "0.5.7: installed from the AUR by its aur/ name, --needed" "$?|$(calls yay)" "0|-S --noconfirm --needed -- aur/gridcraft-bin"
expect_eq "0.5.7: not through omarchy-pkg-aur-add (its own check cannot take aur/) nor Omarchy's repo" \
  "$(calls omarchy-pkg-aur-add | wc -l)|$(calls omarchy-pkg-add | wc -l)" "0|0"
installed_now "photocraft-bin 0.21.0-1"
out=$( ( job install gridcraft ) 2>&1 )
expect_eq "0.5.7: an install that leaves no package fails, checked on the plain name" \
  "$(jq -c '[.verb,.exit]' "$LAST_JOB_FILE")|$(grep -c 'gridcraft-bin did not install' <<<"$out")" '["install",1]|1'
reset_log yay; reset_log omarchy-pkg-aur-add
installed_now "photocraft-bin 0.21.0-1" "gridcraft-bin 0.18.0-1" "deckcraft-bin 1.0.0-1"
( job install deckcraft gridcraft ) >/dev/null 2>&1
expect_eq "0.5.7: an AUR app no repo ships still installs through omarchy-pkg-aur-add, in the same job" \
  "$?|$(calls omarchy-pkg-aur-add)|$(calls yay)" "0|deckcraft-bin|-S --noconfirm --needed -- aur/gridcraft-bin"

# Omarchy's update brought Omarchy's build, newer than the AUR's (or a higher pkgrel of the same version).
installed_now "wordcraft-bin 0.18.0-1"
expect_eq "0.5.7: installed newer than the AUR: no badge, no error" "$(app wordcraft '[.kind,.source,.updateReady]')" '["aur","bin",false]'
installed_now "wordcraft-bin 0.17.0-2"
expect_eq "0.5.7: a higher pkgrel of the AUR's version: no badge" "$(app wordcraft '.updateReady')" 'false'
aur_now wordcraft 0.19.0-1
expect_eq "0.5.7: the AUR's next release is offered again" "$(app wordcraft '[.aurVersion,.updateReady]')" '["0.19.0-1",true]'

# The AUR has no build of it (removed there, or no check yet): it follows its repo, as in 0.5.6.
installed_now "wordcraft-bin 0.16.0-1"
aur_now wordcraft ""
expect_eq "0.5.7: no AUR build: the app follows Omarchy's repo, as in 0.5.6" \
  "$(app wordcraft '[.kind,.repo,.source,.aurVersion]')" '["repo","omarchy","bin","0.16.0-1"]'
aur_now wordcraft 0.17.0-1

# The switch: on, the same machine behaves exactly as under 0.5.6.
FOLLOW_APP_REPOS=1; resync_memo
expect_eq "0.5.7: with FOLLOW_APP_REPOS on, Omarchy's build follows Omarchy's repo again, no badge" \
  "$(app wordcraft '[.kind,.repo,.aurVersion,.updateReady]')" '["repo","omarchy","0.16.0-1",false]'
FOLLOW_APP_REPOS=0; resync_memo

# The AUR versions are read again after the catalog is rewritten.
AUR_LOADED=1; AUR_OF=()
grep -v "^memospot" "$CATALOG" >"$CATALOG.tmp" && mv "$CATALOG.tmp" "$CATALOG"
reconcile_cache
expect_eq "0.5.7: a rewritten catalog is read again for the AUR's versions" "$AUR_LOADED" "0"
expect_eq "0.5.7: and the AUR's version decides again" "$(app wordcraft '.kind')" '"aur"'

FOLLOW_APP_REPOS=1
for f in installed sync-db fresh-db; do cp "$TMP/$f.before057" "$TMP/$f"; done
cp "$TMP/catalog.before057" "$CATALOG"; INSTALLED_LOADED=0; INSTALLED=(); resync_memo; AUR_LOADED=0; AUR_OF=()
rm -f "$REPO_LATEST"

# --- hygiene -----------------------------------------------------------------------------------

expect_eq "no privilege strings in the script" \
  "$(grep -cE '(^|[^a-z-])(sudo|pkexec)([^a-z-]|$)|pacman -R|pacman -S([^ip]|$)' "$ROOT/bin/omarcraft")" "0"
expect_eq "the helper is called in three places: installing an AUR package a repo also ships, and for the update job AUR packages and one repo package" \
  "$(grep -E '(^|[^a-z-])yay ' "$ROOT/bin/omarcraft" | grep -oE 'yay -[SU] --noconfirm' | tr '\n' '|')" "yay -S --noconfirm|yay -U --noconfirm|yay -S --noconfirm|"
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
