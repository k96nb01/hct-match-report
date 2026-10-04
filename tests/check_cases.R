# Runs the report's matching logic on every synthetic case in tests/cases.R
# and checks the match grades and the DPB1 cell against the expected values,
# without rendering a PDF. Calls the live matching API, and the DPB1 TCE
# service for DPB1 mismatches.
#
# Run from the project root:   Rscript tests/check_cases.R
# Add --pdf to also render one PDF per case into tests/output/, and --verbose
# to show Quarto's output while rendering.

suppressPackageStartupMessages({
  library(tidyverse); library(httr2); library(immunogenetr)
})
source("R/matching_api_client.R")
source("R/hct_match.R")
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

# A typing by locus and the GL string typing_gl() makes from it must read the
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
  case  <- cases[[i]]
  match <- hct_match(case$recipient, case$donor)

  # The DPB1 cell as the Mismatches line prints it.
  dpb1  <- match$loci |> filter(locus == "HLA-DPB1")
  dpb1_cell <- case_when(!dpb1$comparable ~ "NC", !is.na(dpb1$error) ~ "ERR",
                         dpb1$MM == 0 ~ "", .default = coalesce(match$tce$label, "ERR"))

  ok <- same(match$grade, case$grade) && same(match$grade_two_field, case$grade_two_field) &&
    dpb1_cell == case$dpb1
  failures <- failures + !ok

  cat("\n=== ", i, ". ", case$name, ": ", if (ok) "PASS" else "FAIL", "\n", sep = "")
  cat("Grade ", match$grade, "/10 (expected ", case$grade, "); two-field ", match$grade_two_field,
      "/10 (expected ", case$grade_two_field, "); DPB1 \"", dpb1_cell, "\" (expected \"", case$dpb1, "\")\n",
      sep = "")
  cat(str_c(" - ", str_wrap(hct_comments(match), 150, exdent = 3)), sep = "\n")

  if (render) {
    hct_match_report(case$recipient, case$donor, file = sprintf("tests/output/case_%02d.pdf", i),
                     recipient_label = "Synthetic recipient", donor_label = str_c("Synthetic donor: ", case$name),
                     quiet = !verbose)
  }
}

cat("\n", if (failures == 0) "All checks passed." else str_c(failures, " check(s) failed."), "\n", sep = "")
if (failures > 0) quit(status = 1)
