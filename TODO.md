# Open work

Status 2026-10-12: 0.2.0 is on `main`; NEWS still marks it "in development".
All 25 synthetic cases and the offline typing checks pass against the live
API, on the desktop and on Workbench. The app runs on the staging Connect
server and renders a correct report there.

## Next

- **Host the app on a Posit Connect server, open to all** (decided
  2026-10-07). This repo stays the one public source and is deployed from
  directly; deployment records (`rsconnect/`) are not committed.
  - On staging, render the other examples and each direction and scope.
  - Deploy to production (`DEPLOY.md`), open to anyone. **Blocked:** the
    production server has no Quarto (`GET /__api__/v1/server_settings/quarto`
    listed no installations on 2026-10-12); ask its administrators to
    install it, as on staging.
  - Link the hosted app from this README.
- **Quarto on the servers' PATH:** the server administrators were asked
  (2026-10-12) to link Quarto into `/usr/local/bin`, as Posit's install
  instructions do, so apps that run Quarto themselves find it. The app does
  not need this (`find_quarto_cli()` and `QUARTO_PATH` in `R/report.R`); once
  it is done, nothing here changes.

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
