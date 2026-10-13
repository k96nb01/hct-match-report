# Open work

Status 2026-10-12: 0.2.0 is released and hosted at
<https://hct-report.immunogenetr.org/> (the production Connect content,
through a Cloudflare Worker that lives with the matching API's proxy, not in
this public repo). All 25 synthetic cases and the offline typing checks
pass against the live API, on the desktop and on Workbench.

## Next

- Finish the smoke test of the hosted app: leave it idle for more than 5
  minutes and generate another report, and use it once from a phone on a
  cellular network.

## Later

- **Quarto fallback in `R/report.R`:** since 2026-10-13 production Connect
  puts Quarto on the PATH it passes to content (a symlink, confirmed by the
  diagnostic app), so `find_quarto_cli()` now finds it through
  `quarto::quarto_path()` and the `/opt/quarto` search is unused there. The
  administrators have not yet chosen between the symlink and a program
  supervisor that sets `QUARTO_PATH`; either works with the app unchanged.
  Keep the fallback until they settle it, then decide whether to remove it.

- Recopy `R/matching_api_client.R` from the matching API's client once it
  says "GL String" (capital S) too; it is the one file here that still says
  "GL string", because it is kept as a verbatim copy.
- Bulk use: a batch version of `hct_match()` for many pairs, using the
  matching API's batch endpoints (API 1.2.0).
- Typing at DRB3/4/5 is accepted and noted but not shown; show it in the
  typing table if wanted.
- Allele ambiguity (`/`) and phasing (`~`) are rejected; consider accepting
  ambiguity once the API handles it.
- **Watch: intermittent render failure.** Three times in about 70 renders on
  2026-10-04, `quarto::quarto_render(quiet = TRUE)` failed with Quarto's
  generic "error running quarto" on a random case, and the same render
  succeeded on retry; verbose renders never failed. If it recurs, the error
  ends with Quarto's own output (`hct_match_report()` logs it).
