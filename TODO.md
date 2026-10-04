# Open work

Status 2026-10-04: version 0.1.0 is built and passes all 13 synthetic cases
and the offline typing checks against the live API; the app's download was
tested end to end. Three independent review passes were applied before the
first commit. Licensed MIT (decided 2026-10-04).

## Next

- **Hosting the app.** Decide whether to host the app publicly (and where),
  or leave it as run-it-yourself.

## Later

- Bulk use: when the matching API's batch endpoint exists, a batch version of
  `hct_match()` for many pairs.
- Typing at DRB3/4/5, DQA1, and DPA1 is accepted and noted but not shown; show
  it in the typing table if wanted.
- Allele ambiguity (`/`) and phasing (`~`) are rejected; consider accepting
  ambiguity once the API handles it.
- **Watch: intermittent render failure.** Three times in about 70 renders on
  2026-10-04, `quarto::quarto_render(quiet = TRUE)` failed with Quarto's
  generic "error running quarto" on a random case, and the same render
  succeeded on retry; verbose renders never failed. `hct_match_report()` now
  runs the Quarto CLI directly with its output logged, and 24 renders since
  have been clean. If it recurs, the error now ends with Quarto's own output.
