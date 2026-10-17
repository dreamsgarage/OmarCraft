#!/bin/bash

# Offline tests for bin/omarcraft. Nothing here touches the network, pacman state or the real
# Omarchy config: HOME and the XDG dirs point at a temporary folder.
#
#   bash tests/run.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_CACHE_HOME="$TMP/cache" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME"

# shellcheck source=../bin/omarcraft
source "$ROOT/bin/omarcraft"
set +e

passed=0
failed=0

ok() {
  passed=$((passed + 1))
  echo "ok   $1"
}

fail() {
  failed=$((failed + 1))
  echo "FAIL $1${2:+: $2}"
}

expect_eq() {
  if [[ $2 == "$3" ]]; then ok "$1"; else fail "$1" "expected [$3], got [$2]"; fi
}

# Parse JSONC the way Omarchy's MenuModel.js does: drop full-line comments, then trailing commas.
parse_menu_jsonc() {
  sed -E '/^[[:space:]]*\/\//d' "$1" | perl -0pe 's/,(\s*[}\]])/$1/g' | jq -e . >/dev/null
}

# --- catalog parser --------------------------------------------------------------------------

parsed=$(parse_upstream_catalog <"$ROOT/tests/fixtures/catalog.rs")
expect_eq "parser finds 13 apps" "$(wc -l <<<"$parsed")" "13"
expect_eq "parser reads the first app" "$(head -1 <<<"$parsed")" $'photocraft\tPhotoCraft\tImage editing\tclassic'
expect_eq "parser handles the struct-update form (pdfcraft)" \
  "$(grep '^pdfcraft' <<<"$parsed")" $'pdfcraft\tPdfCraft\tReading, organizing and protecting PDFs\tclassic'
expect_eq "parser reads groups (7 classic)" "$(cut -f4 <<<"$parsed" | grep -c '^classic$')" "7"
expect_eq "parser reads groups (6 new)" "$(cut -f4 <<<"$parsed" | grep -c '^new$')" "6"
expect_eq "parser matches the built-in catalog" "$parsed" "$BUILTIN_CATALOG"

# --- ids and groups --------------------------------------------------------------------------

( valid_id "photocraft" ) 2>/dev/null && ok "valid id accepted" || fail "valid id accepted"
( valid_id 'x;rm -rf' ) 2>/dev/null && fail "unsafe id rejected" || ok "unsafe id rejected"
( install_group bogus ) 2>/dev/null && fail "unknown group rejected" || ok "unknown group rejected"

mkdir -p "$CACHE_DIR"
while IFS=$'\t' read -r id name tagline group; do
  printf '%s\t%s\t%s\t%s\t1.0.0-1\n' "$id" "$name" "$tagline" "$group"
done <<<"$BUILTIN_CATALOG" >"$CATALOG"
printf 'unpackaged\tUnpackaged\tNo AUR build yet\tnew\t\n' >>"$CATALOG"
touch "$CATALOG"

expect_eq "group all skips apps without an AUR build" "$(group_ids all | wc -l)" "13"
expect_eq "group classic" "$(group_ids classic | tr '\n' ' ')" \
  "photocraft vectorcraft filmcraft lightcraft pdfcraft effectcraft designcraft "
expect_eq "group new" "$(group_ids new | wc -l)" "6"
expect_eq "app name lookup" "$(app_name figcraft)" "FigCraft"
expect_eq "app name falls back to the id" "$(app_name nope)" "nope"

# --- new-app detection -----------------------------------------------------------------------

mkdir -p "$STATE_DIR"
group_ids all | grep -v figcraft >"$SEEN"
is_new figcraft && ok "unseen app is new" || fail "unseen app is new"
is_new photocraft && fail "seen app is not new" || ok "seen app is not new"
mark_seen figcraft
is_new figcraft && fail "mark_seen clears new" || ok "mark_seen clears new"

# --- optional Omarchy menu section -----------------------------------------------------------

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

# --- manifest --------------------------------------------------------------------------------

expect_eq "manifest id" "$(jq -r .id "$ROOT/manifest.json")" "omarcraft.productivity"
expect_eq "IPC target matches the manifest id" "$IPC_TARGET" "$(jq -r .id "$ROOT/manifest.json")"
grep -q "target: \"$IPC_TARGET\"" "$ROOT/BarWidget.qml" && ok "widget IPC target matches" || fail "widget IPC target matches"
[[ -x $ROOT/bin/omarcraft ]] && ok "bin/omarcraft is executable" || fail "bin/omarcraft is executable"

echo
echo "$passed passed, $failed failed"
(( failed == 0 ))
