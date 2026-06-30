#!/usr/bin/env bash
# fm-conventions.test.sh - crew convention resolution, brief injection, and
# inheritance of the convention preset directory to secondmate homes.
set -eu

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v jq >/dev/null 2>&1 || { pass "fm-conventions (skipped: jq absent)"; exit 0; }

TMP=$(fm_test_tmproot fm-conventions)
CFG="$TMP/config"
DATA="$TMP/data"
mkdir -p "$CFG/conventions" "$DATA"
printf -- '- alpha [no-mistakes] - test project (added 2026-01-01)\n' > "$DATA/projects.md"

preset() {  # <name> <body-marker>
  printf '# %s\n%s\n' "$1" "$2" > "$CFG/conventions/$1.md"
}
conv_json() { printf '%s\n' "$1" > "$CFG/crew-conventions.json"; }

export FM_CONFIG_OVERRIDE="$CFG" FM_DATA_OVERRIDE="$DATA"
CONV="$ROOT/bin/fm-conventions.sh"
BRIEF="$ROOT/bin/fm-brief.sh"

preset base "BASE_BODY"
preset dotnet-fsharp "FSHARP_BODY"
preset house-style "HOUSE_BODY"
conv_json '{
  "always": ["base"],
  "rules": [
    { "when": "F#/.NET work", "use": ["dotnet-fsharp"] },
    { "when": "tradingteam project", "use": ["house-style"] }
  ]
}'

# --- validate: clean config reports nothing -------------------------------
out=$("$CONV" validate)
[ -z "$out" ] || fail "valid config must produce no validate output, got: $out"

# --- validate: missing preset file is reported ----------------------------
conv_json '{ "always": ["base"], "rules": [ { "when": "x", "use": ["ghost"] } ] }'
out=$("$CONV" validate)
assert_contains "$out" "missing preset file" "validate flags a referenced preset with no file"
assert_contains "$out" "ghost" "validate names the missing preset"

# --- validate: malformed JSON --------------------------------------------
conv_json '{ not json'
out=$("$CONV" validate)
assert_contains "$out" "malformed JSON" "validate flags malformed JSON"

# restore a good config
conv_json '{
  "always": ["base"],
  "rules": [
    { "when": "F#/.NET work", "use": ["dotnet-fsharp"] },
    { "when": "tradingteam project", "use": ["house-style"] }
  ]
}'

# --- always: lists only the always entries --------------------------------
out=$("$CONV" always)
assert_contains "$out" "base" "always lists the always preset"
assert_not_contains "$out" "dotnet-fsharp" "always excludes rule-only presets"

# --- list: shows always, rules, and available presets ---------------------
out=$("$CONV" list)
assert_contains "$out" "always: base" "list shows always"
assert_contains "$out" "F#/.NET work -> dotnet-fsharp" "list shows a rule's when -> use"
assert_contains "$out" "presets: " "list shows available presets"

# --- render: unknown name is a hard error ---------------------------------
set +e
out=$("$CONV" render nope 2>&1); code=$?
set -e
expect_code 1 "$code" "render unknown preset must fail"
assert_contains "$out" "unknown convention preset 'nope'" "render names the missing preset"

# --- render: stacking + dedupe, order preserved ---------------------------
out=$("$CONV" render base dotnet-fsharp base)
assert_contains "$out" "BASE_BODY" "render emits base body"
assert_contains "$out" "FSHARP_BODY" "render emits stacked body"
[ "$(printf '%s\n' "$out" | grep -c BASE_BODY)" -eq 1 ] || fail "render must dedupe repeated names"
pos_base=$(printf '%s\n' "$out" | grep -n BASE_BODY | head -1 | cut -d: -f1)
pos_fs=$(printf '%s\n' "$out" | grep -n FSHARP_BODY | head -1 | cut -d: -f1)
[ "$pos_base" -lt "$pos_fs" ] || fail "render must preserve given order (base before dotnet-fsharp)"

# --- brief: --convention injects a Conventions section + always rides -----
"$BRIEF" ship-x7 alpha --convention dotnet-fsharp >/dev/null
bf="$DATA/ship-x7/brief.md"
assert_grep "# Conventions" "$bf" "ship brief gets a Conventions section"
assert_grep "FSHARP_BODY" "$bf" "named preset body lands in the ship brief"
assert_grep "BASE_BODY" "$bf" "always preset rides the ship brief automatically"

# --- brief: always rides even with no --convention ------------------------
"$BRIEF" ship-auto alpha >/dev/null
assert_grep "BASE_BODY" "$DATA/ship-auto/brief.md" "always preset rides a brief with no --convention"

# --- brief: dedupe when an always preset is also named --------------------
"$BRIEF" ship-dd alpha --convention base >/dev/null
[ "$(grep -c BASE_BODY "$DATA/ship-dd/brief.md")" -eq 1 ] || fail "named+always preset must appear once"

# --- brief: comma list, and scout briefs carry conventions ----------------
"$BRIEF" scout-c2 alpha --scout --convention dotnet-fsharp,house-style >/dev/null
assert_grep "FSHARP_BODY" "$DATA/scout-c2/brief.md" "comma list: first preset lands in scout brief"
assert_grep "HOUSE_BODY" "$DATA/scout-c2/brief.md" "comma list: second preset lands in scout brief"

# --- brief: no conventions at all => no Conventions section ---------------
rm -f "$CFG/crew-conventions.json"
rm -rf "$CFG/conventions"
"$BRIEF" ship-bare alpha >/dev/null
assert_no_grep "# Conventions" "$DATA/ship-bare/brief.md" "no conventions => no Conventions section"

# --- inheritance: the conventions dir + json propagate to a secondmate ----
# shellcheck source=bin/fm-config-inherit-lib.sh
. "$ROOT/bin/fm-config-inherit-lib.sh"
SRC="$TMP/primary/config"
DST="$TMP/sub/config"
mkdir -p "$SRC/conventions" "$DST"
printf '{ "always": ["base"] }\n' > "$SRC/crew-conventions.json"
printf '# base\nINHERIT_BASE\n' > "$SRC/conventions/base.md"
printf '# fs\nINHERIT_FS\n' > "$SRC/conventions/dotnet-fsharp.md"
propagate_inheritable_config "$SRC" "$DST" || fail "propagate must succeed"
assert_present "$DST/crew-conventions.json" "json file inherits"
assert_grep "INHERIT_BASE" "$DST/conventions/base.md" "preset body inherits"
assert_grep "INHERIT_FS" "$DST/conventions/dotnet-fsharp.md" "second preset body inherits"

# deletion mirroring: drop a preset from the primary, it leaves the secondmate
rm -f "$SRC/conventions/dotnet-fsharp.md"
propagate_inheritable_config "$SRC" "$DST" || fail "re-propagate must succeed"
assert_present "$DST/conventions/base.md" "surviving preset stays"
assert_absent "$DST/conventions/dotnet-fsharp.md" "dropped preset is mirrored as deletion"

# absence mirroring: drop the json from the primary, it leaves the secondmate
rm -f "$SRC/crew-conventions.json"
propagate_inheritable_config "$SRC" "$DST" || fail "third propagate must succeed"
assert_absent "$DST/crew-conventions.json" "dropped json is mirrored as deletion"

pass "fm-conventions resolution, brief injection, and inheritance"
