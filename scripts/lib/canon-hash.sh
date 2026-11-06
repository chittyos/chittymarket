#!/usr/bin/env bash
# canon-hash.sh — the ONE implementation of the canon-versioning content hash (v3).
# Sourced by stamp-canon.sh and check-canon-sync.sh so they cannot drift apart.
# canon: chittycanon://core/contracts/canon-versioning
#
# canon-hash-v3 = sha256 of:
#   canon-hash-v3\n
#   <the WHOLE file — frontmatter and body — with a trailing CR stripped from each line
#    and trailing blank lines removed>
# Nothing in the file is excluded. v1/v2 excluded parts of the frontmatter and had to agree with
# the runtime's frontmatter parser; every such exclusion was broken in review (quoted keys, a
# mid-line `---`, which the runtime treats as the frontmatter end, and denylisted keys that the
# dispatcher reads: plugin/kind/runtimes). Hashing everything makes the boundary irrelevant.
# Consequence: a projection whose frontmatter differs from its canonical source needs its own
# signed manifest; this gate checks the file it is given, byte for byte (modulo CRLF + trailing blanks).
# Signed-manifest bytes: `jq -cS 'del(.signature)'` output INCLUDING its trailing 0x0a. Non-jq signers
# MUST emit sorted-key compact JSON + "\n" (jq also escapes U+007F).

# canon_hash FILE -> "sha256:<hex>"; nonzero (no output) on ANY failure in ANY stage.
canon_hash() {
  local hc out rc
  if command -v sha256sum >/dev/null 2>&1; then hc="sha256sum"; else hc="shasum -a 256"; fi
  [ -f "$1" ] && [ -r "$1" ] || return 1
  # portable awk only (no GNU-only sed); pipefail covers every stage
  out="$( set -o pipefail
          { printf 'canon-hash-v3\n'
            LC_ALL=C awk '{ l=$0; sub(/\r$/,"",l); print l }' "$1"; } \
          | LC_ALL=C awk '/^[[:space:]]*$/ { b=b $0 "\n"; next } { printf "%s", b; b=""; print }' \
          | $hc | cut -d' ' -f1 )"; rc=$?
  [ "$rc" -eq 0 ] || return 1
  case "$out" in e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855) return 1;; esac
  printf '%s' "$out" | grep -Eq '^[0-9a-f]{64}$' || return 1
  printf 'sha256:%s\n' "$out"
}

# --- refusal policy only below: these can turn a verdict into UNVERIFIED, never into IN_SYNC ---
canon_has_fm() { # complete frontmatter? (runtime-style ^---[ \t]*$ delimiters; whole file read)
  LC_ALL=C awk '{l=$0; sub(/\r$/,"",l)} NR==1{ if (l ~ /^---[ \t]*$/) o=1; else exit } NR>1 && o && l ~ /^---[ \t]*$/ {c=1} END{exit !(o && c)}' "$1"
}
canon_body_text() { # body only, CR stripped
  if canon_has_fm "$1"; then
    LC_ALL=C awk '{l=$0; sub(/\r$/,"",l)} NR==1{next} !done && l ~ /^---[ \t]*$/ {done=1; next} !done{next} {print l}' "$1"
  else LC_ALL=C awk '{l=$0; sub(/\r$/,"",l); print l}' "$1"; fi
}
# canon_body_nonempty FILE: true iff the body has a non-blank line (empty / frontmatter-only artifacts are refused).
canon_body_nonempty() { local n; n="$(canon_body_text "$1" | grep -c '[^[:space:]]')"; [ "${n:-0}" -gt 0 ]; }
