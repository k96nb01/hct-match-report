# Open work

Status 2026-10-07: 0.2.0 in development (DQA1/DPA1, X/8 grade, direction and
scope options, app examples). All 25 synthetic cases and the offline typing
checks pass against the live API. Licensed MIT.

## Next

- **Host the app on a Posit Connect server, open to all** (decided
  2026-10-07). This repo stays the one public source and is deployed from
  directly; deployment records (`rsconnect/`) are not committed. Before the
  first deploy: add an renv lockfile. The Quarto CLI (with Typst) may not be
  installed on the server; the first test deploy will tell. Also confirm the
  server can reach `api.immunogenetr.org` and `www.ebi.ac.uk`. Then link the
  hosted app from this README.

## Later

- Recopy `R/matching_api_client.R` from the matching API's client once it
  says "GL String" (capital S) too; it is the one file here that still says
  "GL string", because it is kept as a verbatim copy.
- Bulk use: when the matching API's batch endpoint exists, a batch version of
  `hct_match()` for many pairs.
- Typing at DRB3/4/5 is accepted and noted but not shown; show it in the
  typing table if wanted.
- Allele ambiguity (`/`) and phasing (`~`) are rejected; consider accepting
  ambiguity once the API handles it.
- **Watch: intermittent render failure.** Three times in about 70 renders on
  2026-10-04, `quarto::quarto_render(quiet = TRUE)` failed with Quarto's
  generic "error running quarto" on a random case, and the same render
  succeeded on retry; verbose renders never failed. `hct_match_report()` now
  runs the Quarto CLI directly with its output logged, and 24 renders since
  have been clean. If it recurs, the error now ends with Quarto's own output.
