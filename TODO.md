# Open work

Status 2026-10-09: 0.2.0 (DQA1/DPA1, X/8 grade, direction and scope options,
app examples) is on `main`; NEWS still marks it "in development". All 25
synthetic cases and the offline typing checks pass against the live API.
Licensed MIT. Hosting is blocked: the Connect server has no Quarto (below).

## Next

- **Host the app on a Posit Connect server, open to all** (decided
  2026-10-07). This repo stays the one public source and is deployed from
  directly; deployment records (`rsconnect/`) are not committed.
  - **First test deploy, 2026-10-09:** the app deployed to a staging Connect
    server and starts, but **Generate report** fails with "The Quarto CLI was
    not found." The server's Quarto settings
    (`GET /__api__/v1/server_settings/quarto`) list no installations, so
    Quarto (which includes Typst) is not installed there at all. A request to
    the server administrators to install it went in on 2026-10-09, asking for
    Posit's standard location, `/opt/quarto/<version>/bin/quarto`. Nothing
    more can be tested until then.
  - That deploy listed the app's files explicitly (`app.R`, `report.qmd`,
    and the four files in `R/`) so `tests/` stays out of the bundle, and used
    no renv lockfile; package versions came from the deploying library.
  - **Once Quarto is installed:** make `report.R` find it without server-side
    settings. When `quarto::quarto_path()` finds nothing, fall back to the
    newest `/opt/quarto/*/bin/quarto`, and point Quarto at the running R
    (`QUARTO_R` from `R.home("bin")`) so the render's R process is the same
    R. A `QUARTO_PATH` set on the server would still win, as an override.
    Then redeploy and render every example.
  - Still to do: add an renv lockfile; confirm the server can reach
    `api.immunogenetr.org` and `www.ebi.ac.uk` (not yet tested, because the
    report stops before any request is made); then link the hosted app from
    this README.

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
