#!/usr/bin/env bash
# On-disk cache for the OpenScale model catalogue. QML cannot write files, so
# the write lives here; the tab reads it back through this script too, which
# keeps one place responsible for the envelope's shape.
#
#   models.sh --read      print the cached envelope, or {} when there is none
#   models.sh --refresh   fetch `osc models --json`, replace the cache, and
#                         print the fresh envelope (or {"error": "..."})
#
# Both modes print one JSON object on stdout and exit 0 on any outcome the tab
# can render:
#
#   {"fetchedAt": <epoch seconds>, "models": [ ... ]}   usable data
#   {"error": "..."}                                    the fetch failed
#   {}                                                  no cache yet
#
# The cache holds the public catalogue only — ids, limits and list prices. No
# credential or account data goes near it, so it is safe to keep on disk.
set -uo pipefail

readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/openscale"
readonly CACHE_FILE="$CACHE_DIR/models.json"

emit_empty() {
  printf '{}\n'
  exit 0
}

command -v jq >/dev/null 2>&1 || emit_empty

# One readable line from whatever the CLI printed. Its JSON errors carry the
# useful sentence in .error.message; anything else gets flattened and trimmed.
# The sign-in case is phrased once, the same way the QML side phrases it.
readable_error() {
  local raw=$1 code message
  code=$(printf '%s' "$raw" | jq -r '.error.code // empty | strings' 2>/dev/null | head -1)
  message=$(printf '%s' "$raw" | jq -r '(.error.message // .error // .message // empty) | strings' 2>/dev/null | head -1)
  if [[ $code == unauthorized ]] || printf '%s' "$message $raw" | grep -qi "not signed in"; then
    printf 'Not signed in — run `osc login`'
    return
  fi
  if [[ -z $message ]]; then
    message=$(printf '%s' "$raw" | tr '\n' ' ' \
      | sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' -e 's/^[^:]*: line [0-9]*: //' -e 's/^ *//' -e 's/ *$//')
  fi
  printf '%s' "$message"
}

read_cache() {
  [[ -r $CACHE_FILE ]] || emit_empty
  # Rebuild only the two fields the tab uses, so a partial, older or foreign
  # file is treated as no cache rather than half-parsed.
  jq -c 'if ((.models | type) == "array") and ((.fetchedAt | type) == "number")
         then {fetchedAt: .fetchedAt, models: .models}
         else {} end' "$CACHE_FILE" 2>/dev/null || emit_empty
}

refresh() {
  local out status
  out=$(osc models --json 2>&1)
  status=$?
  if [[ $status -ne 0 ]]; then
    jq -cn --arg message "$(readable_error "$out")" \
      '{error: (if $message == "" then "osc models failed" else $message end)}'
    exit 0
  fi
  if ! jq -e 'type == "array" and length > 0' >/dev/null 2>&1 <<<"$out"; then
    printf '{"error": "osc models returned no catalogue"}\n'
    exit 0
  fi

  local envelope
  # -n: the payload arrives through --argjson, so jq must not look for input on
  # stdin (under Process there is none, and empty input prints nothing).
  envelope=$(jq -cn --argjson at "$(date +%s)" --argjson models "$out" \
    '{fetchedAt: $at, models: $models}') || emit_empty

  # Best effort: a cache that cannot be written must not cost the caller the
  # data it is about to render.
  umask 077
  mkdir -p "$CACHE_DIR" 2>/dev/null
  local tmp
  tmp=$(mktemp "$CACHE_DIR/.models.XXXXXX" 2>/dev/null) || tmp=""
  if [[ -n $tmp ]]; then
    if printf '%s\n' "$envelope" > "$tmp" 2>/dev/null; then
      mv -f "$tmp" "$CACHE_FILE" 2>/dev/null || rm -f "$tmp"
    else
      rm -f "$tmp"
    fi
  fi

  printf '%s\n' "$envelope"
}

case "${1:-}" in
  --read) read_cache ;;
  --refresh) refresh ;;
  *)
    printf '{"error": "usage: models.sh --read | --refresh"}\n'
    exit 2
    ;;
esac
