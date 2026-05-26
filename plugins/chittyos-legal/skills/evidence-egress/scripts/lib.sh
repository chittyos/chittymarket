#!/usr/bin/env bash
# Shared helpers for evidence-egress scripts.
# Source from other scripts via: . "$(dirname "$0")/lib.sh"

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${SKILL_DIR}/assets/config.json"
STATE_FILE="${SKILL_DIR}/assets/state.json"

# --- config ---------------------------------------------------------------

ee_config() {
  # ee_config <jq-path>  -> prints value
  jq -r "$1" "$CONFIG_FILE"
}

ee_report_dir() {
  ee_config '.report_dir // "/tmp"'
}

ee_doc_exts() {
  # Print extensions as a regex group: pdf|eml|docx|...
  jq -r '.document_extensions | join("|")' "$CONFIG_FILE"
}

ee_doc_find_args() {
  # Populate global array EE_DOC_ARGS with find predicate args: ( -iname *.pdf -o -iname *.eml ... )
  EE_DOC_ARGS=( '(' )
  local first=1
  while IFS= read -r ext; do
    if [ "$first" = 1 ]; then
      EE_DOC_ARGS+=( -iname "*.${ext}" )
      first=0
    else
      EE_DOC_ARGS+=( -o -iname "*.${ext}" )
    fi
  done < <(jq -r '.document_extensions[]' "$CONFIG_FILE")
  EE_DOC_ARGS+=( ')' )
}

ee_prune_find_args() {
  # Populate global array EE_PRUNE_ARGS with find predicate args: ( -name node_modules -o -name .git ... )
  EE_PRUNE_ARGS=( '(' )
  local first=1
  while IFS= read -r d; do
    if [ "$first" = 1 ]; then
      EE_PRUNE_ARGS+=( -name "$d" )
      first=0
    else
      EE_PRUNE_ARGS+=( -o -name "$d" )
    fi
  done < <(jq -r '.code_marker_dirs[]' "$CONFIG_FILE")
  EE_PRUNE_ARGS+=( ')' )
}

ee_count_docs() {
  # ee_count_docs <dir>  -> echoes file count, respecting prune + doc filter
  local dir="$1"
  ee_prune_find_args
  ee_doc_find_args
  find "$dir" "${EE_PRUNE_ARGS[@]}" -prune -o -type f "${EE_DOC_ARGS[@]}" -print 2>/dev/null | wc -l | tr -d ' '
}

ee_list_docs() {
  # ee_list_docs <dir>  -> echoes one file path per line, respecting prune + doc filter
  local dir="$1"
  ee_prune_find_args
  ee_doc_find_args
  find "$dir" "${EE_PRUNE_ARGS[@]}" -prune -o -type f "${EE_DOC_ARGS[@]}" -print 2>/dev/null
}

ee_code_marker_dirs() {
  # Newline-separated
  jq -r '.code_marker_dirs[]' "$CONFIG_FILE"
}

ee_code_marker_files() {
  jq -r '.code_marker_files[]' "$CONFIG_FILE"
}

ee_drive_remote_for() {
  # ee_drive_remote_for <case_id>  -> sd_<case_id>: (or whatever pattern says)
  local case_id="$1"
  local pattern
  pattern="$(ee_config '.drive_remote_pattern')"
  printf '%s:\n' "${pattern//\{case_id\}/$case_id}"
}

# --- run ids --------------------------------------------------------------

ee_new_run_id() {
  printf 'egress-%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$$"
}

# --- sha256 ---------------------------------------------------------------

ee_sha256() {
  # ee_sha256 <file>  -> prints lowercase hex hash
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# --- subtree filter -------------------------------------------------------

ee_should_skip_subtree() {
  # ee_should_skip_subtree <dir>  -> exit 0 if subtree should be skipped (it's code)
  local d="$1"
  while IFS= read -r marker; do
    [ -e "${d}/${marker}" ] && return 0
  done < <(ee_code_marker_files)
  return 1
}

ee_is_code_path() {
  # ee_is_code_path <path>  -> exit 0 if any path segment matches a code dir marker
  local p="$1"
  while IFS= read -r d; do
    case "/$p/" in
      */"$d"/*) return 0 ;;
    esac
  done < <(ee_code_marker_dirs)
  return 1
}

# --- discovery ------------------------------------------------------------

ee_discover_cases() {
  # ee_discover_cases <root>  -> prints one case_id per line
  local root="$1"
  [ -d "${root}/cases" ] || { echo "no cases/ under $root" >&2; return 1; }
  find "${root}/cases" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

# --- neon -----------------------------------------------------------------

ee_neon_ready() {
  # exit 0 if NEON_DATABASE_URL set and psql works
  [ -n "${NEON_DATABASE_URL:-}" ] || return 1
  psql "$NEON_DATABASE_URL" -c 'select 1' >/dev/null 2>&1
}

ee_neon_table() {
  # Discover first matching table from config list. Echoes table name or empty.
  ee_neon_ready || { echo ""; return 0; }
  local tbl
  while IFS= read -r tbl; do
    if psql "$NEON_DATABASE_URL" -tAc \
         "select to_regclass('${tbl}') is not null" 2>/dev/null | grep -q '^t$'; then
      echo "$tbl"
      return 0
    fi
  done < <(jq -r '.neon_tables_to_try[]' "$CONFIG_FILE")
  echo ""
}

# --- progress -------------------------------------------------------------

ee_progress() {
  # ee_progress <current> <total> <label>
  local cur="$1" tot="$2" label="${3:-}"
  printf '\r[%5d/%5d] %s' "$cur" "$tot" "$label" >&2
  [ "$cur" = "$tot" ] && echo "" >&2
}

ee_log() {
  printf '[ee] %s\n' "$*" >&2
}
