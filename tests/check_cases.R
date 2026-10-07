# Runs the report's matching logic on every synthetic case in tests/cases.R
# and checks the X/10 and X/8 match grades and the Mismatches cells against the
# expected values, without rendering a PDF. Calls the live matching API, and the
# DPB1 TCE service for DPB1 mismatches.
#
# Run from the project root:   Rscript tests/check_cases.R
# Add --pdf to also render one PDF per case into tests/output/, and --verbose
# to show Quarto's output while rendering.

suppressPackageStartupMessages({
  library(tidyverse); library(httr2); library(immunogenetr)
})
source("R/matching_api_client.R")
source("R/hct_match.R")
source("R/examples.R")
source("tests/cases.R")
options(width = 200)

render  <- "--pdf" %in% commandArgs(trailingOnly = TRUE)
verbose <- "--verbose" %in% commandArgs(trailingOnly = TRUE)
if (render) {
  source("R/report.R")
  dir.create("tests/output", showWarnings = FALSE)
}

same <- function(a, b) identical(is.na(a), is.na(b)) && (is.na(a) || a == b)
failures <- 0

# ---- reading the typing (offline: no API calls) ----
# Each input must stop with a message containing the text given.
bad_inputs <- list(
  list(input = "HLA-A*02:01/HLA-A*02:09",             error = "ambiguity"),
  list(input = list(A = "02:01/02:09"),                error = "ambiguity"),
  list(input = list(A = "02:01+02:09"),                error = "one allele name per field"),
  list(input = list(A = "HLA-B*07:02"),                error = "listed under HLA-A"),
  list(input = list(A = c("01:01", "02:01", "03:01")), error = "More than two"),
  list(input = list(c("02:01", "24:02")),              error = "must be named"),
  list(input = "A*02:01+A*24:02",                      error = "written in full"),
  list(input = list(A = "02:01", `HLA-A` = "24:02"),   error = "given more than once"),
  list(input = list(DRB3 = "01:01"),                   error = "No typing was given at A"),
  list(input = list(A = c("", NA)),                    error = "No typing"),
  list(input = "",                                     error = "No typing")
)
for (b in bad_inputs) {
  message <- tryCatch({ read_typing(b$input); "no error" }, error = conditionMessage)
  ok <- str_detect(message, fixed(b$error))
  failures <- failures + !ok
  if (!ok) cat("FAIL read_typing: expected \"", b$error, "\", got \"", message, "\"\n", sep = "")
}

# A typing by locus and the GL String typing_gl() makes from it must read the
# same; loci the report does not compare are kept and listed as ignored.
by_locus <- read_typing(list(a = c("A*02:01", " 24:02 "), `HLA-B` = "07:02", DRB3 = "01:01", DPB1 = c("", NA)))
as_gl    <- typing_gl(by_locus)
again    <- read_typing(as_gl)
round_trip <- identical(by_locus$alleles, again$alleles) && identical(by_locus$ignored, again$ignored) &&
  as_gl == "HLA-A*02:01+HLA-A*24:02^HLA-B*07:02^HLA-DRB3*01:01" &&
  identical(by_locus$ignored, "HLA-DRB3")
if (!round_trip) cat("FAIL typing_gl round trip: ", as_gl, "\n", sep = "")
failures <- failures + !round_trip
cat("Typing checks done (", length(bad_inputs) + 1, " checks).\n", sep = "")

for (i in seq_along(cases)) {
  case      <- cases[[i]]
  direction <- case$direction %||% "bidirectional"
  scope     <- case$scope %||% "locus"
  match     <- hct_match(case$recipient, case$donor, direction = direction, scope = scope)

  # Every cell of the Mismatches line as the report prints it, named by locus
  # without the prefix (e.g. "DPB1").
  cells <- match$loci |>
    mutate(cell = case_when(!comparable ~ "NC", !is.na(error) ~ "ERR", MM == 0 ~ "",
                            locus == "HLA-DPB1" ~ coalesce(match$tce$label, "ERR"),
                            .default = as.character(MM)),
           locus = str_remove(locus, "^HLA-")) |>
    select(locus, cell) |>
    deframe()
  expected_cells <- c(DPB1 = case$dpb1, case$mm)

  g10 <- match$grades$Xof10
  g8  <- match$grades$Xof8
  ok <- same(g10$grade, case$grade) && same(g10$two_field, case$grade_two_field) &&
    same(g8$grade, case$grade8) && same(g8$two_field, case$grade8_two_field) &&
    identical(unname(cells[names(expected_cells)]), unname(expected_cells))
  failures <- failures + !ok

  cat("\n=== ", i, ". ", case$name, " (", direction, ", ", scope, "): ", if (ok) "PASS" else "FAIL", "\n", sep = "")
  cat("X/10 ", g10$grade, " (expected ", case$grade, "), two-field ", g10$two_field,
      " (expected ", case$grade_two_field, "); X/8 ", g8$grade, " (expected ", case$grade8,
      "), two-field ", g8$two_field, " (expected ", case$grade8_two_field, ")\n", sep = "")
  cat("Mismatches: ", str_flatten(str_c(names(cells), "=\"", cells, "\""), " "), "\n", sep = "")
  if (!ok) cat("Expected:   ", str_flatten(str_c(names(expected_cells), "=\"", expected_cells, "\""), " "), "\n", sep = "")
  cat(str_c(" - ", str_wrap(hct_comments(match), 150, exdent = 3)), sep = "\n")

  if (render) {
    hct_match_report(case$recipient, case$donor, file = sprintf("tests/output/case_%02d.pdf", i),
                     direction = direction, scope = scope,
                     recipient_label = "Synthetic recipient", donor_label = str_c("Synthetic donor: ", case$name),
                     quiet = !verbose)
  }
}

cat("\n", if (failures == 0) "All checks passed." else str_c(failures, " check(s) failed."), "\n", sep = "")
if (failures > 0) quit(status = 1)
