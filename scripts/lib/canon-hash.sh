#!/usr/bin/env bash
# canon-hash.sh — the ONE implementation of the canon-versioning content hash (v3).
# Sourced by stamp-canon.sh and check-canon-sync.sh so they cannot drift apart.
# canon: chittycanon://core/contracts/canon-versioning
#
# canon-hash-v3 = sha256 of:
#   canon-hash-v3\n
#   <the WHOLE file — frontmatter and body — line by line, each line terminated by \n>
# The ONLY normalisations (all invisible to the runtime):
#   1. one trailing CR is stripped from each line (CRLF == LF);
#   2. a missing final newline is supplied (`Body` == `Body\n`);
#   3. trailing lines consisting only of whitespace ([[:space:]]: space, tab, \v, \f) are removed.
# Every other byte change changes the hash. Files containing a NUL byte are REFUSED (no hash):
# awk implementations disagree on NUL (busybox awk turns it into a newline), which would let a
# NUL in a signed file collide with a newline — i.e. an injected frontmatter key.
# Nothing in the file is excluded. v1/v2 excluded parts of the frontmatter and had to agree with
# the runtime's frontmatter parser; every such exclusion was broken in review (quoted keys, a
# mid-line `---`, which the runtime treats as the frontmatter end, and denylisted keys that the
# dispatcher reads: plugin/kind/runtimes). Hashing everything makes the boundary irrelevant.
# Consequence: a projection whose frontmatter differs from its canonical source needs its own
# signed manifest; this gate checks the file it is given.
# Signed-manifest bytes: `jq -cS 'del(.signature)'` output INCLUDING its trailing 0x0a. Non-jq signers
# MUST emit sorted-key compact JSON + "\n" (jq also escapes U+007F).
# All awk calls read the file on stdin (`< "$1"`): a path shaped like `k=v` would otherwise be
# taken by awk as a variable assignment and awk would hash stdin instead.

# Manifest/min-version format, shared by stamp and check. Match with bash [[ =~ ]] (whole string,
# so an embedded newline cannot smuggle a second line past it), never with line-based grep.
CANON_VER_RE='^[0-9]+(\.[0-9A-Za-z.+-]+)*$'

canon_has_nul() { # true iff FILE contains a 0x00 byte
  local a b
  a="$(wc -c < "$1")" || return 0
  b="$(tr -d '\000' < "$1" | wc -c)" || return 0
  [ "$a" -ne "$b" ]
}

# canon_hash FILE -> "sha256:<hex>"; nonzero (no output) on ANY failure in ANY stage.
canon_hash() {
  local hc out rc
  if command -v sha256sum >/dev/null 2>&1; then hc="sha256sum"; else hc="shasum -a 256"; fi
  [ -f "$1" ] && [ -r "$1" ] || return 1
  canon_has_nul "$1" && return 1
  # portable awk only (no GNU-only sed); pipefail covers every stage
  out="$( set -o pipefail
          { printf 'canon-hash-v3\n'
            LC_ALL=C awk '{ l=$0; sub(/\r$/,"",l); print l }' < "$1"; } \
          | LC_ALL=C awk '/^[[:space:]]*$/ { b=b $0 "\n"; next } { printf "%s", b; b=""; print }' \
          | $hc | cut -d' ' -f1 )"; rc=$?
  [ "$rc" -eq 0 ] || return 1
  printf '%s' "$out" | grep -Eq '^[0-9a-f]{64}$' || return 1
  printf 'sha256:%s\n' "$out"
}

# --- refusal policy only below: these can turn a verdict into UNVERIFIED, never into IN_SYNC ---
# canon_body_text FILE: the body as the RUNTIME sees it. The runtime parses frontmatter with
# /^---\s*\n([\s\S]*?)---\s*\n?/ : an opening `---` + whitespace containing a newline, then the
# FIRST `---` anywhere (mid-line included) closes it, then leading whitespace is consumed.
# No closing `---` -> no frontmatter -> the whole file is the body. CRs are stripped first.
canon_body_text() {
  LC_ALL=C awk '{ l=$0; sub(/\r$/,"",l); s = s l "\n" }
    END {
      if (substr(s,1,3) == "---") {
        r = substr(s,4)
        if (match(r, /^[ \t\v\f]*\n/)) {
          i = index(r, "---")
          if (i > 0) { s = substr(r, i+3); sub(/^[ \t\n\v\f]+/, "", s) }
        }
      }
      printf "%s", s
    }' < "$1"
}
# canon_body_nonempty FILE: true iff the runtime-visible body has a non-blank line.
canon_body_nonempty() { local n; n="$(canon_body_text "$1" | grep -c '[^[:space:]]')"; [ "${n:-0}" -gt 0 ]; }
