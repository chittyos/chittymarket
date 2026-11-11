WHAT_BREAKS="an unmatched glob leaves the literal pattern in the loop variable, so the script reports a phantom orphan named '*' and the skipped count is a lie — exactly the 'silent cap reads as covered everything' failure the header warns about"
setup() {
  run_reap
}
assert() {
  expect_out_re 'skipped: 0' &&
  expect_no_out_re '^SKIP +\*' &&
  expect_rc 0
}
