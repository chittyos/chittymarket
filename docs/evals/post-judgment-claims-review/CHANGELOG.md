## 2026-10-15 — eval-3 assertion 3 corrected (before grading iteration-2; after the runs)

The original assertion claimed the Unit B reconciliation "closes to the cent: 6,905.00 − 5,480.00 = 1,425.00 = 310.00 + 425.00 + 40.00 + 300.00". That sum is 1,075.00, not 1,425.00: the prompt's facts (ledger at judgment 5,790.00; postings 765.00; payment 6,905.00) leave 350.00 that no posting explains, so no run could satisfy the assertion as written. The facts are kept — the gap is a useful trap (the skill says a demand waits until the decomposition closes) — and the assertion now tests that the gap is found and named. A second assertion tests that no demand treats the 350.00 as overpayment. Both iteration-2 eval-3 runs had finished before this change; both are graded against the corrected text. eval-1 assertions were tightened earlier the same day (addressee; records request to the statutory addressee; letter drafted + nothing sent) before the iteration-2 runs started.

## 2026-10-15 — reviewer round after iteration 3 (no further runs)

- eval-3 assertion 6 reworded: the prompt gives no Unit A payment history, so the installment count may be marked Unknown.
- eval-3 assertion 7 added: the counsel note's ask about the unexplained 350.00 must be for the posting detail, not whether to demand it. The iteration-3 with_skill run would FAIL this assertion (its note asked whether the 350.00 could be demanded); the Stage 2 clause that targets it was added to the skill after that run and is untested.
- eval-3 prompt line 6 made consistent with its record list (the firm letter says "judgment awarded"; the invoice says "trial").
- eval-1 prompt: the quoted declaration wording and the delivery-receipt detail were varied so the synthetic pattern tracks no real instrument. Cosmetic; no assertion depends on the varied text. The iteration-2 runs used the earlier wording.
- Not yet asserted anywhere: the unregistered-case notice at the top, the proportional manifest, and the index of unwritten files.
