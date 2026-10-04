# A copy of client/matching_api_client.R from the matching_api repo, used here
# unchanged. The report calls it through R/hct_match.R.
#
# matching_api — R client
#
# A thin httr2 wrapper around the matching_api endpoints. Source this file
# from any R session that needs to talk to a deployed instance.
#
# Quick start:
#
#   source("matching_api_client.R")
#
#   # Point at your deployed instance (env var or per-call argument)
#   Sys.setenv(MATCHING_API_HOST = "https://matching-api.yourdomain.com")
#
#   mapi_health()
#   mapi_preprocess("HLA-A*01:01+HLA-A*02:01")
#   mapi_match_hct(
#     recip       = "HLA-A*01:01+HLA-A*02:01^HLA-B*07:02+HLA-B*08:01^HLA-C*07:01+HLA-C*07:02^HLA-DRB1*03:01+HLA-DRB1*15:01",
#     donor       = "HLA-A*01:01+HLA-A*02:01^HLA-B*07:02+HLA-B*08:01^HLA-C*07:01+HLA-C*07:02^HLA-DRB1*03:01+HLA-DRB1*15:01",
#     match_grade = "Xof8",
#     preprocess  = TRUE
#   )

if (!requireNamespace("httr2", quietly = TRUE)) {
  stop("Install 'httr2' first: install.packages('httr2')")
}

mapi_host <- function(host = NULL) {
  host <- host %||% Sys.getenv("MATCHING_API_HOST", unset = NA_character_)
  if (is.na(host) || !nzchar(host)) {
    stop("No host. Set MATCHING_API_HOST env var or pass host = ...",
         call. = FALSE)
  }
  sub("/+$", "", host)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Build a request against the configured host. The API itself is unauthenticated
# (deployed open on Posit Connect), so no auth headers are added here.
mapi_request <- function(path, host = NULL) {
  httr2::request(paste0(mapi_host(host), path))
}

# Performs the request and returns parsed JSON. On HTTP error, raises with
# the server's error message when one is provided in the response body.
mapi_perform <- function(req) {
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- httr2::req_perform(req)
  body <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
  if (httr2::resp_status(resp) >= 400) {
    msg <- if (is.list(body) && !is.null(body$error)) body$error
           else httr2::resp_status_desc(resp)
    stop(sprintf("matching_api %d: %s", httr2::resp_status(resp), msg),
         call. = FALSE)
  }
  body
}

#' GET /health
mapi_health <- function(host = NULL) {
  mapi_perform(mapi_request("/health", host))
}

#' POST /preprocess — reduce a GL string through py-ard.
#' redux_mode is optional; the server default is used when NULL. The IPD-IMGT/HLA
#' version is pinned server-side (build-time) and cannot be selected per
#' request — see GET /health for the active version.
mapi_preprocess <- function(gl_string,
                            redux_mode = NULL,
                            host       = NULL) {
  body <- list(gl_string = gl_string)
  if (!is.null(redux_mode)) body$redux_mode <- redux_mode
  req <- httr2::req_body_json(mapi_request("/preprocess", host), body)
  mapi_perform(req)
}

#' POST /match/hct — HCT match summary for a recipient/donor pair.
#' Set preprocess = TRUE to reduce inputs through py-ard before matching;
#' the response then echoes the reduced GL strings. The IPD-IMGT/HLA version used
#' for reduction is pinned server-side and not configurable here.
mapi_match_hct <- function(recip,
                           donor,
                           match_grade,
                           direction  = NULL,
                           scope      = NULL,
                           preprocess = FALSE,
                           redux_mode = NULL,
                           host       = NULL) {
  body <- list(
    gl_string_recip = recip,
    gl_string_donor = donor,
    match_grade     = match_grade,
    preprocess      = isTRUE(preprocess)
  )
  if (!is.null(direction))  body$direction  <- direction
  if (!is.null(scope))      body$scope      <- scope
  if (!is.null(redux_mode)) body$redux_mode <- redux_mode
  req <- httr2::req_body_json(mapi_request("/match/hct", host), body)
  mapi_perform(req)
}

# Internal helper for the four per-locus endpoints. They share the same
# input shape (recip, donor, loci, direction, optional preprocess fields)
# and only the URL path and the optional homozygous_count differ.
mapi_perlocus_post <- function(path, recip, donor, loci, direction,
                               homozygous_count = NULL,
                               preprocess = FALSE,
                               redux_mode = NULL,
                               host       = NULL) {
  body <- list(
    gl_string_recip = recip,
    gl_string_donor = donor,
    loci            = as.list(loci),  # ensure JSON array even for length-1
    direction       = direction,
    preprocess      = isTRUE(preprocess)
  )
  if (!is.null(homozygous_count)) body$homozygous_count <- as.integer(homozygous_count)
  if (!is.null(redux_mode))       body$redux_mode       <- redux_mode
  req <- httr2::req_body_json(mapi_request(path, host), body)
  mapi_perform(req)
}

#' POST /match/number — per-locus match counts.
#' direction defaults to "bidirectional" server-side.
mapi_match_number <- function(recip, donor, loci,
                              direction  = NULL,
                              preprocess = FALSE,
                              redux_mode = NULL,
                              host       = NULL) {
  mapi_perlocus_post(
    path       = "/match/number",
    recip      = recip,
    donor      = donor,
    loci       = loci,
    direction  = direction %||% "bidirectional",
    preprocess = preprocess,
    redux_mode = redux_mode,
    host       = host
  )
}

#' POST /mismatch/logical — TRUE if any mismatch across the specified loci.
#' direction is required (one of "HvG", "GvH", "bidirectional", "SOT").
mapi_mismatch_logical <- function(recip, donor, loci, direction,
                                  preprocess = FALSE,
                                  redux_mode = NULL,
                                  host       = NULL) {
  mapi_perlocus_post(
    path       = "/mismatch/logical",
    recip      = recip,
    donor      = donor,
    loci       = loci,
    direction  = direction,
    preprocess = preprocess,
    redux_mode = redux_mode,
    host       = host
  )
}

#' POST /mismatch/number — per-locus mismatch counts.
#' direction is required (one of "HvG", "GvH", "bidirectional", "SOT").
#' homozygous_count is 1 or 2 (default 2 server-side).
mapi_mismatch_number <- function(recip, donor, loci, direction,
                                 homozygous_count = NULL,
                                 preprocess = FALSE,
                                 redux_mode = NULL,
                                 host       = NULL) {
  mapi_perlocus_post(
    path             = "/mismatch/number",
    recip            = recip,
    donor            = donor,
    loci             = loci,
    direction        = direction,
    homozygous_count = homozygous_count,
    preprocess       = preprocess,
    redux_mode       = redux_mode,
    host             = host
  )
}

#' POST /mismatch/alleles — per-locus mismatched-allele GL fragments.
#' direction is required (one of "HvG", "GvH", "bidirectional", "SOT").
#' homozygous_count is 1 or 2 (default 2 server-side).
mapi_mismatch_alleles <- function(recip, donor, loci, direction,
                                  homozygous_count = NULL,
                                  preprocess = FALSE,
                                  redux_mode = NULL,
                                  host       = NULL) {
  mapi_perlocus_post(
    path             = "/mismatch/alleles",
    recip            = recip,
    donor            = donor,
    loci             = loci,
    direction        = direction,
    homozygous_count = homozygous_count,
    preprocess       = preprocess,
    redux_mode       = redux_mode,
    host             = host
  )
}
