# Deploying to Posit Connect

The app is deployed from Posit Workbench to two Posit Connect servers: first
to staging, then, once staging works, to production. The bundle is built
from the working tree of the clone you deploy from, not from GitHub, so
deploy only from an up-to-date, clean `main`.

This repository is public, so the server and account names are not written
here. `rsconnect::accounts()` lists the ones registered on your Workbench
account; use them below.

## 1. Prepare on Workbench

In a terminal, from the project folder:

```sh
git switch main
git pull
git status                          # should be clean
Rscript tests/check_cases.R --pdf   # expect "All checks passed."
```

There is no renv lockfile yet, so the server installs the package versions
of your Workbench library. Update packages, if at all, before running the
tests; never between the tests and the deploy.

## 2. Deploy

Restart R first (Ctrl+Shift+F10), so no stale package versions are loaded,
and run from the project folder. Set `server` to the staging or production
server's name from `rsconnect::accounts()`:

```r
server <- "<staging or production server>"

rsconnect::deployApp(
  appDir   = ".",
  appFiles = c("app.R", "report.qmd", "R/examples.R", "R/hct_match.R",
               "R/matching_api_client.R", "R/report.R",
               list.files("fonts", full.names = TRUE)),
  appName  = "hct-match-report",
  appTitle = "HCT donor match report",
  server   = server,
  account  = "<your account on that server>"
)
```

`appFiles` lists the app's files explicitly, so `tests/` and the
documentation stay out of the bundle. Add any new file the app needs here.
The deploy records in `rsconnect/` (not committed) tie this clone to the
content on each server. From a clone without them, rsconnect looks for
content named `hct-match-report` owned by `account` and may ask whether to
update it or create new content: choose update, and always deploy under the
same account, or a second copy is created. The first deploy to a server
creates the content.

## 3. Check

- The content log shows a new bundle ID.
- In the app, **Generate report** works for each example, under each
  direction. This also checks that the server can reach
  `api.immunogenetr.org` and `www.ebi.ac.uk`.
- If the report says "The Quarto CLI was not found", Quarto is not on the
  app's PATH or in `/opt/quarto/<version>/bin` (see `find_quarto_cli()` in
  `R/report.R`).

On the first deploy to production, also set the content's access to
"Anyone - no login required" in the Connect dashboard. If that option is
missing, anonymous access is turned off on the server; ask its
administrators.
