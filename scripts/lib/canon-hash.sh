#!/usr/bin/env bash
# canon-hash.sh — the ONE implementation of the canon-versioning content hash (v1).
# Sourced by stamp-canon.sh and check-canon-sync.sh so they cannot drift apart.
# canon: chittycanon://core/contracts/canon-versioning
#
# Canonical byte string hashed (sha256), all line endings normalised to LF:
#   canon-hash-v1\n
#   fm=<1|0>\n                      1 only when a COMPLETE frontmatter block exists (line 1 '---' + a later '---')
#   for each ALLOWLISTED top-level frontmatter key, sorted bytewise (LC_ALL=C), stable:
#     <the key's lines: 'key: value' + its indented continuation lines, whitespace-only lines dropped>\n
#   body\n
#   <everything below the frontmatter, trailing blank lines stripped>
# Allowlist = keys that change runtime BEHAVIOUR. Projection metadata (canon_uri, overlay, projection_*,
# runtimes, kind, ...) is deliberately outside the hash because projections add/rewrite it.
# Signed-manifest bytes: `jq -cS 'del(.signature)'` output INCLUDING its trailing 0x0a. Non-jq signers
# MUST emit sorted-key compact JSON + "\n" (jq also escapes U+007F).
CANON_FM_ALLOW="name description tools allowed-tools disallowedTools model permissionMode hooks mcpServers skills effort"

canon_has_fm() { # complete frontmatter? (no early-exit pipes: pipefail/SIGPIPE-safe)
  [ "$(sed -n '1p' "$1" | sed 's/\r$//')" = "---" ] || return 1
  sed -n '2,$p' "$1" | sed 's/\r$//' | grep -xF -- '---' >/dev/null
}

canon_canonical_bytes() { # file -> canonical byte string on stdout
  local f="$1"
  printf 'canon-hash-v1\n'
  if canon_has_fm "$f"; then
    printf 'fm=1\n'
    LC_ALL=C awk -v allow="$CANON_FM_ALLOW" '
      BEGIN { n=split(allow, a, " "); for(i=1;i<=n;i++) ok[a[i]]=1 }
      { l=$0; sub(/\r$/,"",l) }
      NR==1 && l=="---" { fm=1; next }
      fm && l=="---" { fm=0; done=1; next }
      done { next }
      fm {
        if (l ~ /^[A-Za-z0-9_-]+:/) { k=l; sub(/:.*/,"",k); cur=(k in ok)?k:"" }
        if (cur!="" && l !~ /^[ \t]*$/) { seq++; printf "%s\t%08d\t%s\n", cur, seq, l }
      }' "$f" | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2n | cut -f3-
    printf 'body\n'
  else
    printf 'fm=0\nbody\n'
  fi
  canon_body_text "$f"
}

canon_body_text() { # body only (below a complete frontmatter block, or the whole file), CR stripped
  if canon_has_fm "$1"; then
    LC_ALL=C awk '{l=$0; sub(/\r$/,"",l)} NR==1&&l=="---"{fm=1;next} fm&&l=="---"{fm=0;done=1;next} fm{next} {print l}' "$1"
  else sed -e 's/\r$//' "$1"; fi
}

# canon_hash FILE -> "sha256:<hex>" ; returns nonzero (no output) on any pipeline failure.
canon_hash() {
  local hc out rc
  if command -v sha256sum >/dev/null 2>&1; then hc="sha256sum"; else hc="shasum -a 256"; fi
  [ -f "$1" ] && [ -r "$1" ] || return 1
  # strip trailing blank lines from the whole canonical string, then hash
  out="$({ canon_canonical_bytes "$1" || exit 1; } | sed -e :a -e '/^\n*$/{$d;N;ba}' | $hc | cut -d' ' -f1; exit "${PIPESTATUS[0]}")"; rc=$?
  [ "$rc" -eq 0 ] && [ -n "$out" ] || return 1
  printf 'sha256:%s\n' "$out"
}

# canon_body_nonempty FILE: true iff the body has a non-blank line (empty artifacts are refused).
canon_body_nonempty() { local n; n="$(canon_body_text "$1" | grep -c '[^[:space:]]')"; [ "${n:-0}" -gt 0 ]; }
