# hct_match_report(): render the HCT donor match report to a PDF.
#
#   source("R/report.R")
#   hct_match_report(
#     recipient = "HLA-A*02:01+HLA-A*24:02^HLA-B*07:02+HLA-B*44:02^HLA-C*07:02+HLA-C*05:01^HLA-DRB1*15:01+HLA-DRB1*04:01^HLA-DQB1*06:02+HLA-DQB1*03:02^HLA-DPB1*04:01+HLA-DPB1*02:01",
#     donor     = list(A = c("02:09", "24:02"), B = c("07:02", "44:02"), C = c("07:50", "05:01"),
#                      DRB1 = c("15:01", "04:01"), DQB1 = c("06:02", "03:02"), DPB1 = c("04:01", "02:01")),
#     file      = "match_report.pdf"
#   )
#
# Each typing is a GL String or a named list by locus (see read_typing() in
# R/hct_match.R). `recipient_label` and `donor_label` are printed on the report
# only; they are never sent anywhere. `direction` is "bidirectional" (the
# default), "GvH", or "HvG"; `scope`, which only affects a bidirectional match
# grade, is "locus" (the default) or "genotype" (see R/hct_match.R).
# `quiet = FALSE` shows Quarto's output.
# Run from the project root. Needs the Quarto CLI and the R packages listed in
# the README.

suppressPackageStartupMessages({
  library(tidyverse)
  library(httr2)
  library(immunogenetr)
})

hct_match_report <- function(recipient, donor, file = "hct_match_report.pdf",
                             recipient_label = "Recipient", donor_label = "Donor",
                             direction = c("bidirectional", "GvH", "HvG"),
                             scope = c("locus", "genotype"),
                             api_host = "https://api.immunogenetr.org", quiet = TRUE) {
  direction <- match.arg(direction)
  scope     <- match.arg(scope)
  # The project root: where the R/ folder and report.qmd live.
  root <- normalizePath(".", winslash = "/")
  if (!file.exists(file.path(root, "report.qmd"))) {
    stop("Run hct_match_report() from the project root (the folder holding report.qmd).", call. = FALSE)
  }

  # Both typings go to the report as GL Strings. read_typing() checks each
  # one, so a typing that cannot be used stops here, with its message, rather
  # than inside the render.
  source(file.path(root, "R", "matching_api_client.R"), local = TRUE)
  source(file.path(root, "R", "hct_match.R"), local = TRUE)
  as_gl <- function(x) typing_gl(read_typing(x))

  params <- list(
    recipient       = as_gl(recipient),
    donor           = as_gl(donor),
    recipient_label = recipient_label,
    donor_label     = donor_label,
    direction       = direction,
    scope           = scope,
    api_host        = api_host
  )

  # Render in a fresh temporary folder, so the project folder is never written
  # to (a deployed app may not be allowed to) and two renders cannot collide.
  work <- tempfile("hct_report_")
  on.exit(unlink(work, recursive = TRUE), add = TRUE)
  dir.create(file.path(work, "R"), recursive = TRUE)
  file.copy(file.path(root, "report.qmd"), work)
  file.copy(list.files(file.path(root, "R"), full.names = TRUE), file.path(work, "R"))

  # Run the Quarto CLI directly, with its whole output kept in a log, so a
  # failed render can always say why. The parameters go in a YAML file, which
  # avoids quoting GL Strings on the command line.
  quarto_cli <- quarto::quarto_path()
  if (is.null(quarto_cli)) {
    stop("The Quarto CLI was not found. Install it from https://quarto.org (see the README).", call. = FALSE)
  }
  yaml::write_yaml(params, file.path(work, "params.yml"))
  log <- file.path(work, "render.log")
  status <- withr::with_dir(work, system2(
    quarto_cli,
    c("render", "report.qmd", "--to", "typst", "--execute-params", "params.yml"),
    stdout = log, stderr = log))
  if (!quiet && file.exists(log)) writeLines(readLines(log))

  if (status != 0 || !file.exists(file.path(work, "report.pdf"))) {
    # The report saves the reason the matching failed (see report.qmd);
    # otherwise give the end of Quarto's own output.
    saved  <- file.path(work, "render_error.txt")
    reason <- if (file.exists(saved)) {
      str_flatten(readLines(saved), " ")
    } else if (file.exists(log)) {
      str_flatten(tail(readLines(log), 15), "\n")
    } else {
      str_c("Quarto exited with status ", status, ".")
    }
    stop("The report could not be rendered: ", reason, call. = FALSE)
  }

  file.copy(file.path(work, "report.pdf"), file, overwrite = TRUE)
  invisible(file)
}
