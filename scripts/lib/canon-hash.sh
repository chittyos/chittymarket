#!/usr/bin/env bash
# canon-hash.sh — the ONE implementation of the canon-versioning content hash (v2).
# Sourced by stamp-canon.sh and check-canon-sync.sh so they cannot drift apart.
# canon: chittycanon://core/contracts/canon-versioning
#
# Canonical byte string hashed (sha256), line endings normalised to LF:
#   canon-hash-v2\n
#   fm=<1|0>\n                 1 only when a complete frontmatter block exists
#   every frontmatter line EXCEPT lines belonging to a DENYLISTED top-level key (projection metadata),
#     grouped by top-level key, keys sorted bytewise (LC_ALL=C), file order kept within a key,
#     whitespace-only lines and '#' comment lines dropped
#   body\n
#   <everything below the frontmatter, trailing blank lines stripped>
# DENYLIST, not allowlist: an unknown key is hashed (fails safe). Only projection metadata that
# projections add or rewrite is outside the hash: see CANON_FM_DENY.
# FAIL CLOSED: the hash is refused (rc 1 -> UNVERIFIED) if any column-0 frontmatter line is not
# `key: value` / `key:` with key = [A-Za-z0-9_-]+ (quoted keys, `key : v`, `? k`, `<<:`, flow `{..}`
# mappings are all rejected), if an indented line has no owning key, or if a line starting with
# `---` other than `---[ \t]*` appears inside frontmatter.
# Delimiters follow the Claude Code runtime: opener/closer = a line matching ^---[ \t]*$ (CR tolerated).
# Signed-manifest bytes: `jq -cS 'del(.signature)'` output INCLUDING its trailing 0x0a. Non-jq signers
# MUST emit sorted-key compact JSON + "\n" (jq also escapes U+007F).
CANON_FM_DENY="canon_uri canonical_uri overlay canonical_capability_ref projection_owner projection_id projection_family runtimes plugin kind classification"

canon_has_fm() { # complete frontmatter? pure awk, reads whole file (no early-exit pipes)
  LC_ALL=C awk '{l=$0; sub(/\r$/,"",l)} NR==1{ if (l ~ /^---[ \t]*$/) o=1; else exit } NR>1 && o && l ~ /^---[ \t]*$/ {c=1} END{exit !(o && c)}' "$1"
}

canon_body_text() { # body only, CR stripped
  if canon_has_fm "$1"; then
    LC_ALL=C awk '{l=$0; sub(/\r$/,"",l)} NR==1{next} !done && l ~ /^---[ \t]*$/ {done=1; next} !done{next} {print l}' "$1"
  else LC_ALL=C awk '{l=$0; sub(/\r$/,"",l); print l}' "$1"; fi
}

canon_fm_lines() { # prints "key<TAB>seq<TAB>line" for hashed frontmatter lines; exit 3 on malformed frontmatter
  LC_ALL=C awk -v deny="$CANON_FM_DENY" '
    BEGIN { n=split(deny, d, " "); for(i=1;i<=n;i++) bad[d[i]]=1 }
    { l=$0; sub(/\r$/,"",l) }
    NR==1 { next }
    {
      if (l ~ /^---[ \t]*$/) exit 0
      if (l ~ /^---/) { print "malformed delimiter-like line in frontmatter: " l > "/dev/stderr"; exit 3 }
      if (l ~ /^[ \t]*$/ || l ~ /^#/) next
      if (l ~ /^[A-Za-z0-9_-]+:([ \t]|$)/) { k=l; sub(/:.*/,"",k); cur=k; have=1 }
      else if ((l ~ /^[ \t]/ || l ~ /^-([ \t]|$)/) && have) { }
      else { print "unparseable frontmatter line: " l > "/dev/stderr"; exit 3 }
      if (!(cur in bad)) { seq++; printf "%s\t%08d\t%s\n", cur, seq, l }
    }
  ' "$1"
}

canon_canonical_bytes() { # file -> canonical byte string on stdout; nonzero on malformed input
  local f="$1"
  printf 'canon-hash-v2\n'
  if canon_has_fm "$f"; then
    printf 'fm=1\n'
    ( set -o pipefail; canon_fm_lines "$f" | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2n | cut -f3- ) || return 1
    printf 'body\n'
  else
    printf 'fm=0\nbody\n'
  fi
  canon_body_text "$f"
}

# canon_hash FILE -> "sha256:<hex>"; nonzero (no output) on ANY failure in ANY stage.
canon_hash() {
  local hc tmp out rc
  if command -v sha256sum >/dev/null 2>&1; then hc="sha256sum"; else hc="shasum -a 256"; fi
  [ -f "$1" ] && [ -r "$1" ] || return 1
  tmp="$(mktemp "${TMPDIR:-/tmp}/canonhash.XXXXXX")" || return 1
  if ! canon_canonical_bytes "$1" > "$tmp"; then rm -f "$tmp"; return 1; fi
  # strip trailing blank lines (portable awk; no GNU-only sed), then hash; every stage checked via pipefail
  out="$( set -o pipefail; awk '/^[[:space:]]*$/ {b=b $0 "\n"; next} {printf "%s", b; b=""; print}' "$tmp" | $hc | cut -d' ' -f1 )"; rc=$?
  rm -f "$tmp"
  [ "$rc" -eq 0 ] || return 1
  case "$out" in e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855) return 1;; esac
  printf '%s' "$out" | grep -Eq '^[0-9a-f]{64}$' || return 1
  printf 'sha256:%s\n' "$out"
}

# canon_body_nonempty FILE: true iff the body has a non-blank line (empty artifacts are refused).
canon_body_nonempty() { local n; n="$(canon_body_text "$1" | grep -c '[^[:space:]]')"; [ "${n:-0}" -gt 0 ]; }
