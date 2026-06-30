#!/usr/bin/env bash
# Resolve crew conventions: stackable coding-convention presets that firstmate
# injects into crewmate briefs so crews follow the captain's house style.
#
# Two LOCAL, gitignored files under config/, parallel to crew-dispatch.json:
#   config/crew-conventions.json   rules + always list; firstmate-maintained, human-editable
#   config/conventions/<name>.md   the body of each named preset (markdown)
#
# Selection is firstmate's JUDGMENT at intake, exactly like crew dispatch profiles:
# this script never matches the natural-language `when` text. It lists the rules
# and presets so firstmate can judge, prints the always-on presets, and renders a
# chosen stack so fm-brief.sh can inject it. Unlike dispatch (single best-fit),
# conventions STACK: firstmate applies every rule whose `when` fits the task, plus
# every `always` preset.
#
# Schema (config/crew-conventions.json):
#   {
#     "always": ["base"],
#     "rules": [
#       { "when": "<natural-language condition>", "use": ["preset", ...], "why": "<optional>" }
#     ]
#   }
# Every name in `always` and in each rule's `use` must have a config/conventions/<name>.md.
#
# Usage:
#   fm-conventions.sh list              print the always presets, each rule (when -> use), and available presets
#   fm-conventions.sh always            print always-on preset names, one per line (deduped, order preserved)
#   fm-conventions.sh render <name>...  emit the concatenated preset bodies (the stack), deduped, in the
#                                       order given; an unknown name is a hard error so a typo never ships empty
#   fm-conventions.sh validate          validate the JSON and that referenced presets exist; prints an error
#                                       reason on one line, or nothing when valid/absent
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"
JSON="$CONFIG/crew-conventions.json"
PRESET_DIR="$CONFIG/conventions"

need_jq() {
  command -v jq >/dev/null 2>&1 || { echo "error: jq is required for crew-conventions" >&2; return 1; }
}

referenced_names() {  # all names in always + every rule's use, deduped
  jq -r '[ (.always // [])[]?, (.rules // [])[]?.use[]? ] | map(tostring) | unique | .[]' "$JSON" 2>/dev/null
}

list_conventions() {
  if [ ! -f "$JSON" ]; then
    echo "no crew-conventions ($JSON absent)"
    return 0
  fi
  need_jq || return 1
  jq -r '
    "always: " + (((.always // []) | map(tostring)) | join(", ")),
    ((.rules // [])[]? | "rule: " + (.when | tostring) + " -> " + (((.use // []) | map(tostring)) | join(", ")))
  ' "$JSON" 2>/dev/null || { echo "error: malformed $JSON" >&2; return 1; }
  if [ -d "$PRESET_DIR" ]; then
    local names="" f
    for f in "$PRESET_DIR"/*.md; do
      [ -e "$f" ] || continue
      names="$names${names:+, }$(basename "$f" .md)"
    done
    [ -n "$names" ] && echo "presets: $names"
  fi
  return 0
}

always_conventions() {
  [ -f "$JSON" ] || return 0
  need_jq || return 1
  jq -r '(.always // [])[]? | tostring' "$JSON" 2>/dev/null | awk 'NF && !seen[$0]++'
}

render_conventions() {
  [ "$#" -gt 0 ] || return 0
  local name file seen=" " first=1
  for name in "$@"; do
    case "$seen" in *" $name "*) continue ;; esac
    seen="$seen$name "
    file="$PRESET_DIR/$name.md"
    [ -f "$file" ] || { echo "error: unknown convention preset '$name' (no $file)" >&2; return 1; }
    [ "$first" = 1 ] || printf '\n'
    first=0
    cat "$file"
  done
}

validate_conventions() {
  [ -f "$JSON" ] || return 0
  need_jq || return 1
  if ! jq -e . "$JSON" >/dev/null 2>&1; then
    echo "malformed JSON"
    return 0
  fi
  local err
  err=$(jq -r '
    if type != "object" then "top-level value must be an object"
    elif has("always") and (.always | type) != "array" then "always must be an array"
    elif [(.always // [])[]? | select(type != "string" or length == 0)] | length > 0 then "each always entry must be a non-empty string"
    elif has("rules") and (.rules | type) != "array" then "rules must be an array"
    elif [(.rules // [])[]? | select(type != "object")] | length > 0 then "each rule must be an object"
    elif [(.rules // [])[]? | select((.when? | type) != "string" or (.when | length) == 0)] | length > 0 then "each rule needs a non-empty when"
    elif [(.rules // [])[]? | select((.use? | type) != "array" or (.use | length) == 0)] | length > 0 then "each rule needs a non-empty use array"
    elif [(.rules // [])[]?.use[]? | select(type != "string" or length == 0)] | length > 0 then "each use entry must be a non-empty string"
    else empty
    end
  ' "$JSON" 2>/dev/null || true)
  if [ -n "$err" ]; then
    echo "$err"
    return 0
  fi
  local missing="" name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ -f "$PRESET_DIR/$name.md" ] || missing="$missing${missing:+, }$name"
  done <<EOF
$(referenced_names)
EOF
  [ -n "$missing" ] && echo "missing preset file(s): $missing"
  return 0
}

cmd=${1:-}
[ "$#" -gt 0 ] && shift || true
case "$cmd" in
  list) list_conventions ;;
  always) always_conventions ;;
  render) render_conventions "$@" ;;
  validate) validate_conventions ;;
  ''|-h|--help)
    sed -n '2,/^set -eu/ p' "$0" | sed -e 's/^# \{0,1\}//' -e '/^set -eu$/d'
    ;;
  *) echo "error: unknown command '$cmd' (expected list|always|render|validate)" >&2; exit 2 ;;
esac
