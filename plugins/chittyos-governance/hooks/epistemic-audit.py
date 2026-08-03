#!/usr/bin/env python3
"""
Epistemic audit — a randomized, unpredictable challenge to unverified claims.

WHY THIS IS RANDOM AND NOT PATTERN-MATCHED
------------------------------------------
The obvious design is a regex: fire when the response contains blocker-shaped
language ("architecturally unreachable", "blocked on", "not possible") without
an adjacent tool call. That design is worse, for one reason: it is DETECTABLE.
Given a known trigger, the cheapest adaptation is to avoid the trigger words
while remaining just as unverified. Goodhart's law, immediately.

A random audit has no signal to game. If any claim might be challenged, the
only strategy that survives is being right about all of them. This is why tax
audits and QA sampling are random rather than targeted.

It also catches a failure class the regex cannot: claims that WERE sampled, but
badly. "36 of 38 manifests are empty" (a grep artifact — the real number was
37, and the pattern only matched a single-line form) and "3/3 accounts
connected" (a tautology — every row emitted was connected by construction) both
had evidence behind them. Nothing in their phrasing was blocker-shaped. A
random challenge doesn't care about shape; it just occasionally asks whether
the thing is actually true.

SEEDING
-------
The seed is the transcript hash, so:
  - the fire pattern is fixed by history BEFORE the current response is written,
    and therefore cannot be influenced by how the response is phrased;
  - a session replays identically, which matters for debugging a hook whose
    entire purpose is to fire unpredictably.

RATE
----
Deliberately low. A challenge that fires often becomes ceremony — the same
failure as an Alchemization clause that a comment could satisfy, or a manifest
that declares tools which do not exist. An unconditional check carries no
information. Tune via EPISTEMIC_AUDIT_RATE (default 0.07).

Exits 0 always. This asks a question; it never blocks.
"""
import hashlib
import json
import os
import re
import sys

# Operator-invoked trigger. Pattern-matching is safe HERE, unlike a hook that
# watches the assistant's own output: the assistant cannot route around a
# trigger the operator controls. This is the two-word nudge with the full text
# attached — a macro, not a detector.
MANUAL_TRIGGER = re.compile(
    r"^\s*(?:/)?(?:bs|bullshit|call\s*(?:bs|bullshit)|audit|prove\s*it)\s*[!.?]*\s*$",
    re.IGNORECASE,
)

CHALLENGE = (
    "Pick the single load-bearing factual claim in what you just wrote — "
    "the one the rest depends on.\n\n"
    "  1. Did you MEASURE it this turn, or did you infer it from a name, "
    "a doc, a memory, or a plausible causal story?\n"
    "  2. If you measured it: could the measurement be right and the "
    "conclusion still wrong? (A grep that matched one spelling. A ratio "
    "whose denominator cannot vary. A test asserting the buggy value.)\n"
    "  3. Name the one command that would falsify it. If it takes under a "
    "minute, run it before answering.\n\n"
    "Confident-and-wrong is indistinguishable from confident-and-right "
    "from the inside.\n"
)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    # Mode 2 — operator-invoked. A UserPromptSubmit payload carries `prompt`.
    # Fires unconditionally on the trigger and says nothing otherwise, so the
    # operator can call bullshit without having to articulate why.
    prompt = payload.get("prompt")
    if prompt is not None:
        if MANUAL_TRIGGER.match(prompt):
            sys.stderr.write("EPISTEMIC AUDIT (operator-invoked)\n\n" + CHALLENGE)
        return 0

    # Never audit an already-interrupted or errored turn — the operator is
    # steering, which is a stronger signal than anything this hook provides.
    if payload.get("stop_hook_active"):
        return 0

    transcript = payload.get("transcript_path") or ""
    session = payload.get("session_id") or ""

    basis = ""
    try:
        if transcript and os.path.exists(transcript):
            st = os.stat(transcript)
            # Size + mtime is a cheap proxy for "conversation so far" without
            # reading a large file on every single turn.
            basis = f"{transcript}:{st.st_size}:{int(st.st_mtime)}"
        else:
            basis = session
    except Exception:
        basis = session

    if not basis:
        return 0

    digest = hashlib.sha256(basis.encode("utf-8")).hexdigest()
    draw = int(digest[:8], 16) / 0xFFFFFFFF

    try:
        rate = float(os.environ.get("EPISTEMIC_AUDIT_RATE", "0.07"))
    except ValueError:
        rate = 0.07
    rate = min(max(rate, 0.0), 1.0)

    if draw >= rate:
        return 0

    sys.stderr.write(
        "EPISTEMIC AUDIT (random, seeded on transcript — not triggered by "
        "anything you said)\n\n" + CHALLENGE +
        "That is the whole reason this fires at random.\n"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
