# Matching logic for the HCT donor match report.
#
# Sourced by report.qmd, and by tests/check_cases.R so the logic can be checked
# without rendering a PDF. Needs tidyverse, httr2, immunogenetr, and
# R/matching_api_client.R (sourced before this file).
#
# What leaves this machine: GL Strings for one recipient/donor pair, the locus
# names, and the matching options go to the matching API; four DPB1 allele
# names go to the DPB1 T-cell epitope (TCE) service when DPB1 is mismatched.
# The optional recipient and donor labels never leave the machine.

# The loci of each match grade, in the order the report prints the grades.
# (The names are the matching API's match_grade values.)
grade_loci <- list(
  Xof10 = c("HLA-A", "HLA-B", "HLA-C", "HLA-DRB1", "HLA-DQB1"),
  Xof8  = c("HLA-A", "HLA-B", "HLA-C", "HLA-DRB1")
)
grade_out_of <- c(Xof10 = 10L, Xof8 = 8L)

# The loci with a mismatch count, in report order. DQA1 and DPA1 are counted
# but are not part of either match grade.
count_loci <- c("HLA-A", "HLA-B", "HLA-C", "HLA-DRB1", "HLA-DQA1", "HLA-DQB1", "HLA-DPA1")

# DPB1 is compared too, but it is reported as TCE permissiveness, not as a
# count, and it is not part of either match grade.
dpb1_locus <- "HLA-DPB1"

report_loci <- c(count_loci, dpb1_locus)

# The reduction py-ard applies before matching.
redux_mode <- "P"

# The match directions and bidirectional scopes the report offers; the first of
# each is the default. Bidirectional counts the larger of the graft-versus-host
# and host-versus-graft counts at each locus. Scope only affects a bidirectional
# match grade: "locus" adds up the worse direction at each locus, "genotype"
# totals each direction across the loci and takes the worse total.
match_directions <- c("bidirectional", "GvH", "HvG")
match_scopes     <- c("locus", "genotype")

# The public matching API.
default_api_host <- "https://api.immunogenetr.org"

# ---- reading the typing ------------------------------------------------------

# Read one person's typing. Returns a list:
#   alleles - one element per report locus, each a character vector of 0, 1,
#             or 2 allele names without the locus prefix (e.g. "02:01")
#   all     - the same for every locus given, including loci the report does
#             not compare (used to pass the typing on as a GL String)
#   ignored - the loci given that the report does not compare
# Every check on the input is made here, so a typing that cannot be used stops
# with a plain message before anything is sent or rendered.
#
# `x` is either
#   - a GL String, e.g. "HLA-A*02:01+HLA-A*24:02^HLA-B*07:02+HLA-B*44:02^...",
#     with no ambiguity ("/" or "|") and no phasing ("~"); or
#   - a named list or character vector by locus, e.g.
#     list(A = c("02:01", "24:02"), B = c("07:02", "44:02"), ...). Names may be
#     "A" or "HLA-A". A value may carry its own prefix ("A*02:01"), which must
#     match the name. Blank values are dropped.
# A homozygote may be given as one allele; immunogenetr counts a single allele
# at a locus as homozygous.
read_typing <- function(x) {
  ambiguous <- function() {
    stop("The typing contains an ambiguity (\"/\" or \"|\") or phasing (\"~\"). ",
         "Give one allele name per allele.", call. = FALSE)
  }

  # Allele names and loci are upper case; accept lower-case input.
  if (is.null(x) || (is.atomic(x) && all(is.na(x)))) {
    by_locus <- list()
  } else if (is.character(x) && length(x) == 1 && is.null(names(x))) {
    gl <- str_to_upper(str_squish(x))
    if (str_detect(gl, "[/|~]")) ambiguous()
    alleles <- if (gl == "") character() else str_split_1(gl, "[\\^+]") |> str_trim()
    alleles <- alleles[alleles != ""]
    if (!all(str_detect(alleles, "^HLA-[A-Z0-9]+\\*[^*\\s]+$"))) {
      stop("Every allele in the GL String must be written in full, e.g. HLA-A*02:01.", call. = FALSE)
    }
    loci <- str_extract(alleles, "^HLA-[A-Z0-9]+")
    # Keep the loci in the order given (split() would sort them).
    by_locus <- split(str_remove(alleles, "^HLA-[A-Z0-9]+\\*"), factor(loci, levels = unique(loci)))
  } else {
    by_locus <- as.list(x)
    given <- str_to_upper(str_trim(names(by_locus) %||% rep("", length(by_locus))))
    if (any(!str_detect(given, "^(HLA-)?[A-Z0-9]+$"))) {
      stop("Every locus in the typing must be named, e.g. A or HLA-A.", call. = FALSE)
    }
    names(by_locus) <- if_else(str_starts(given, "HLA-"), given, str_c("HLA-", given))
    repeated <- unique(names(by_locus)[duplicated(names(by_locus))])
    if (length(repeated) > 0) {
      stop(str_flatten_comma(repeated), " is given more than once.", call. = FALSE)
    }
    # A plain loop, not map(): an error raised inside map() comes back wrapped
    # in purrr's own text, and these messages are shown to the user as is.
    for (locus in names(by_locus)) {
      v <- str_to_upper(str_trim(as.character(by_locus[[locus]])))
      v <- v[!is.na(v) & v != ""]
      # Accept "A*02:01" or "HLA-A*02:01" as well as "02:01", but only for the
      # locus it is listed under.
      prefix <- str_match(v, "^(?:HLA-)?([A-Z0-9]+)\\*")[, 2]
      wrong  <- !is.na(prefix) & str_c("HLA-", prefix) != locus
      if (any(wrong)) {
        stop("The allele ", v[wrong][1], " is listed under ", locus, ".", call. = FALSE)
      }
      v <- str_remove(v, "^(?:HLA-)?[A-Z0-9]+\\*")
      if (any(str_detect(v, "[/|~]"))) ambiguous()
      if (any(str_detect(v, "[\\^+*\\s]"))) {
        stop("Give one allele name per field (", locus, ": ", str_flatten_comma(v), ").", call. = FALSE)
      }
      by_locus[[locus]] <- v
    }
  }

  by_locus <- keep(by_locus, \(v) length(v) > 0)
  if (length(by_locus) == 0) {
    stop("No typing was given.", call. = FALSE)
  }
  if (!any(names(by_locus) %in% report_loci)) {
    stop("No typing was given at A, B, C, DRB1, DQA1, DQB1, DPA1, or DPB1.", call. = FALSE)
  }
  too_many <- names(keep(by_locus, \(v) length(v) > 2))
  if (length(too_many) > 0) {
    stop("More than two alleles were given at ", str_flatten_comma(too_many), ".", call. = FALSE)
  }

  list(
    alleles = map(set_names(report_loci), \(l) by_locus[[l]] %||% character()),
    all     = by_locus,
    ignored = setdiff(names(by_locus), report_loci)
  )
}

# The typing as a GL String, every locus given included.
typing_gl <- function(typing) {
  typing$all |>
    imap_chr(\(v, l) str_c(l, "*", v, collapse = "+")) |>
    str_flatten("^")
}

# The GL String for one locus of one person, and whether it can be compared.
# Returns list(gl, status), where status is "typed", "not typed", or
# "not high resolution".
locus_typing <- function(typing, locus) {
  values <- typing$alleles[[locus]]

  if (length(values) == 0) {
    return(list(gl = NA_character_, status = "not typed"))
  }
  # High-resolution typing is digits in at least two colon-separated fields,
  # with an optional one-letter suffix (N, G, P, ...). Anything else is not sent
  # for matching: low resolution ("02"), an NMDP code, or text. (Allele
  # ambiguity is rejected earlier, by read_typing().)
  if (!all(str_detect(values, "^[:digit:]+(:[:digit:]+)+[A-Z]?$"))) {
    return(list(gl = NA_character_, status = "not high resolution"))
  }

  list(gl = str_c(locus, "*", values, collapse = "+"), status = "typed")
}

# ---- DPB1 TCE service --------------------------------------------------------

# The IPD-IMGT/HLA DPB1 T-cell epitope matching service at EBI, algorithm
# version 2.1: the endpoint called, and the page describing it (printed on the
# report).
dpb1_tce_url      <- "https://www.ebi.ac.uk/cgi-bin/ipd/matching/dpb1_tce_v21"
dpb1_tce_docs_url <- "https://www.ebi.ac.uk/ipd/imgt/hla/matching/match_apis/"
dpb1_tce_version  <- "2.1"

# Ask the TCE service to grade one DPB1 mismatch. `recip_gl` and `donor_gl` are
# DPB1 GL Strings. The service wants two alleles per person, with a homozygote
# given twice, so a single allele is repeated. `direction` is the chosen match
# direction. Returns a list:
#   label      - "P" (permissive) or "NP" (non-permissive) in that direction,
#                or NA
#   prediction - the service's own wording, e.g. "Non permissive HvG"
#   np_direction - the direction the service named as non-permissive, or NA
#   groups     - each allele with its TCE group, for the comments
#   notes      - anything the service remarked on (it comments on null alleles)
#   error      - why there is no label, otherwise NA
#
# Only call this for typing the matching API has already accepted: the TCE
# service does not validate allele names. It puts a name it has never heard of
# in group 3 and calls the pair permissive. For the same reason the alleles are
# sent as plain two-field names (HLA_truncate also drops a G or P group suffix,
# and keeps an expression suffix such as N): that is the form the service
# documents, and a longer or group name it did not recognize would be graded
# as group 3 without any warning.
#
# The patient and donor identifiers the service asks for are fixed words.
dpb1_tce <- function(recip_gl, donor_gl, direction = "bidirectional") {
  alleles <- function(gl) {
    x <- str_remove(str_split_1(HLA_truncate(gl), fixed("+")), fixed("HLA-DPB1*"))
    if (length(x) == 1) rep(x, 2) else x
  }
  failed  <- function(why) list(label = NA_character_, prediction = NA_character_, np_direction = NA_character_,
                                groups = NA_character_, notes = character(), error = why)

  # Any failure here (no connection, an error status, a body that is not the
  # expected JSON) means no label. It never stops the report.
  report <- tryCatch({
    response <- request(dpb1_tce_url) |>
      req_url_query(pid = "patient", patdpb1 = alleles(recip_gl)[1], patdpb2 = alleles(recip_gl)[2],
                    did = "donor",   dondpb1 = alleles(donor_gl)[1], dondpb2 = alleles(donor_gl)[2]) |>
      req_timeout(60) |>
      req_retry(max_tries = 3, retry_on_failure = TRUE) |>
      req_perform() |>
      resp_body_json(check_type = FALSE)
    response[[str_c("HLA-DPB1_TCE_report_V", dpb1_tce_version)]]
  }, error = \(e) NULL)

  donor <- if (is.list(report) && length(report$donors) >= 1) report$donors[[1]] else NULL
  prediction <- if (is.list(donor) && is.list(donor$result)) donor$result$tce_prediction else NULL

  if (!is.character(prediction) || length(prediction) != 1) {
    return(failed("The DPB1 TCE service could not be reached or returned no prediction."))
  }

  # The TCE groups and the service's remarks, for the comments. If this part of
  # the response is not shaped as expected, there is no label either: a
  # prediction that cannot be shown with its groups is not reported.
  details <- tryCatch({
    text   <- function(x) if (length(x) == 0) "not given" else str_flatten(as.character(unlist(x)), " ")
    listed <- c(report$patient$gene[["HLA-DPB1"]], donor$gene[["HLA-DPB1"]])
    who    <- rep(c("recipient", "donor"), c(length(report$patient$gene[["HLA-DPB1"]]),
                                             length(donor$gene[["HLA-DPB1"]])))
    list(
      groups = str_flatten(str_c(who, " ", map_chr(listed, \(a) text(a$allele)), " = group ",
                                 map_chr(listed, \(a) text(a$tce_group))), "; "),
      notes  = listed |>
        keep(\(a) length(a$comments) > 0) |>
        map_chr(\(a) str_c(text(a$allele), ": ", text(a$comments))))
  }, error = \(e) NULL)

  if (is.null(details)) {
    return(failed("The DPB1 TCE service returned a response that could not be read."))
  }

  # The label is decided from the service's wording. A non-permissive mismatch
  # names the one direction it is non-permissive in ("Non permissive HvG"). It
  # is NP on the report when that is the chosen direction, or the choice is
  # bidirectional; non-permissive only in the other direction, it is P in the
  # chosen one. A non-permissive answer naming no direction is NP in any
  # direction. Anything that is not one of the expected answers gets no label.
  # That includes "ARD Matched", which would contradict the mismatch that led to
  # this call.
  non_permissive <- str_match(str_squish(prediction), regex("^non[ -]?permissive(?:\\s+(GvH|HvG))?$", ignore_case = TRUE))
  np_direction   <- non_permissive[, 2]
  if (!is.na(np_direction)) np_direction <- if (str_to_lower(np_direction) == "gvh") "GvH" else "HvG"
  label <- case_when(
    !is.na(non_permissive[, 1]) &
      (direction == "bidirectional" | is.na(np_direction) | np_direction == direction) ~ "NP",
    !is.na(non_permissive[, 1])                                                         ~ "P",
    str_detect(str_squish(prediction), regex("^permissive$", ignore_case = TRUE))                 ~ "P",
    .default = NA_character_)

  list(label = label, prediction = prediction, np_direction = np_direction,
       groups = details$groups, notes = details$notes,
       error = if (is.na(label)) str_c("The DPB1 TCE service answered \"", prediction,
                                       "\", which is not a permissiveness grade.") else NA_character_)
}

# ---- matching API ----------------------------------------------------------

# Build a request without performing it, so the per-locus requests can run in
# parallel. 4xx/5xx responses are returned, not thrown, so the API's own error
# message can be reported.
api_request <- function(path, body, host) {
  mapi_request(path, host) |>
    req_body_json(body) |>
    req_error(is_error = \(resp) FALSE) |>
    req_timeout(30) |>
    req_retry(max_tries = 3, retry_on_failure = TRUE)
}

# Perform a request, returning a connection failure as a condition for
# api_result() to report, rather than throwing httr2's own message.
api_perform <- function(req) tryCatch(req_perform(req), error = \(e) e)

# Read one API result. Returns list(ok, body, error).
#   - A 400 or 422 means the API rejected this input (for example an allele
#     name py-ard does not know). That is a result: it is reported for the
#     locus concerned.
#   - Anything else that is not a JSON success means the API could not be used
#     at all, and the report stops: a match report must not go out with the
#     matching silently missing. That includes an HTML page returned with
#     HTTP 200, which is what a web firewall's bot challenge looks like.
api_result <- function(resp) {
  if (!inherits(resp, "httr2_response")) {
    stop("The matching API could not be reached: ", conditionMessage(resp), call. = FALSE)
  }
  status <- resp_status(resp)
  body   <- tryCatch(resp_body_json(resp), error = \(e) NULL)

  if (status %in% c(400, 422)) {
    message <- if (is.list(body) && !is.null(body$error)) body$error else resp_status_desc(resp)
    return(list(ok = FALSE, body = NULL, error = str_squish(message)))
  }
  if (status >= 400 || !is.list(body)) {
    stop("The matching API returned an unexpected response (HTTP ", status, "). ",
         "If this persists, try again in a few minutes.", call. = FALSE)
  }
  list(ok = TRUE, body = body, error = NA_character_)
}

# The same for a two-field request. Those results only feed the comments, so
# any failure, even one that would stop the report in api_result(), becomes a
# missing two-field count, and the comments say it could not be assessed.
two_field_result <- function(resp) {
  tryCatch(api_result(resp), error = \(e) list(ok = FALSE, body = NULL, error = conditionMessage(e)))
}

# ---- the whole comparison for one pair -------------------------------------

# `recipient` and `donor` are typings as accepted by read_typing(). `direction`
# and `scope` are one of match_directions and match_scopes. Returns a list:
#   loci     - one row per report locus: the counted loci and DPB1
#   tce      - the DPB1 TCE result (see dpb1_tce), or NULL when DPB1 is matched,
#              was not compared, or could not be compared
#   grades   - one element per match grade (Xof10, Xof8), each a list of
#                grade     - the X of "X/10" or "X/8" at the P group level, or NA
#                note      - why the grade is NA, otherwise NA
#                two_field - the same grade from allele names truncated to two
#                            fields, without P group reduction
#   direction, scope - the options used
#   ignored  - loci given in the typing that this report does not compare
#   versions - what calculated the results
hct_match <- function(recipient, donor, host = default_api_host,
                      direction = match_directions, scope = match_scopes) {
  direction <- match.arg(direction)
  scope     <- match.arg(scope)
  recipient <- if (is.list(recipient) && !is.null(recipient$alleles)) recipient else read_typing(recipient)
  donor     <- if (is.list(donor) && !is.null(donor$alleles)) donor else read_typing(donor)

  # The versions come from /health. If it does not answer with JSON, nothing
  # else will either, so stop here with a clear message.
  health <- mapi_request("/health", host) |>
    req_error(is_error = \(resp) FALSE) |>
    req_timeout(30) |>
    req_retry(max_tries = 3, retry_on_failure = TRUE) |>
    api_perform() |>
    api_result() |>
    pluck("body")

  loci <- tibble(locus = report_loci) |>
    mutate(recip = map(locus, \(l) locus_typing(recipient, l)),
           donor = map(locus, \(l) locus_typing(donor, l))) |>
    mutate(recip_gl = map_chr(recip, "gl"), donor_gl = map_chr(donor, "gl"),
           recip_status = map_chr(recip, "status"), donor_status = map_chr(donor, "status")) |>
    select(-recip, -donor) |>
    mutate(comparable = recip_status == "typed" & donor_status == "typed")

  # All of the matching is done by the matching API, in two forms: at the P
  # group level (py-ard reduces both typings first), and on the allele names
  # truncated to two fields, not reduced (used only for the comments, to show
  # what P group reduction changed). The same service and versions do both.
  # `preprocess` chooses the form; the body of a two-field request is the same
  # apart from the truncated GL Strings.
  matching_body <- function(recip_gl, donor_gl, preprocess, ...) {
    if (!preprocess) {
      recip_gl <- HLA_truncate(recip_gl)
      donor_gl <- HLA_truncate(donor_gl)
    }
    c(list(gl_string_recip = recip_gl, gl_string_donor = donor_gl, ...,
           direction = direction, preprocess = preprocess),
      if (preprocess) list(redux_mode = redux_mode))
  }
  # The number of one locus from a /mismatch/number result, or NA.
  locus_count <- function(r, l) {
    value <- if (r$ok) r$body$by_locus[[l]] else NULL
    if (is.null(value)) NA_integer_ else suppressWarnings(as.integer(value))
  }

  # One request per comparable locus and form, sending only that locus. A
  # problem at one locus (an allele py-ard rejects, say) then cannot take the
  # other loci down with it. DPB1 goes through the same call: it says whether
  # DPB1 is mismatched at the P group level, and it checks the allele names,
  # which the TCE service does not. With two forms of each match grade and the
  # /health call for the versions, that is at most 21 calls to the API per
  # report, run a few at a time.
  requests <- loci |>
    filter(comparable) |>
    select(locus, recip_gl, donor_gl)

  locus_requests <- function(preprocess) {
    pmap(requests, \(locus, recip_gl, donor_gl) api_request("/mismatch/number", matching_body(
      recip_gl, donor_gl, preprocess, loci = list(locus), homozygous_count = 2L), host))
  }
  all_responses <- c(locus_requests(TRUE), locus_requests(FALSE)) |>
    req_perform_parallel(on_error = "continue", max_active = 5, progress = FALSE)
  responses           <- map(all_responses[seq_len(nrow(requests))], api_result)
  responses_two_field <- map(all_responses[nrow(requests) + seq_len(nrow(requests))], two_field_result)

  results <- requests |>
    mutate(
      MM      = map2_int(responses, locus, locus_count),
      # A two-field count the API could not give is NA; the comments say so.
      MM_two_field = map2_int(responses_two_field, locus, locus_count),
      error   = map_chr(responses, "error"),
      # The GL Strings as py-ard reduced them, which is what was matched.
      recip_P = map_chr(responses, \(r) if (r$ok) r$body$gl_string_recip %||% NA_character_ else NA_character_),
      donor_P = map_chr(responses, \(r) if (r$ok) r$body$gl_string_donor %||% NA_character_ else NA_character_)
    ) |>
    # A success with no number for the locus is also an error for that locus,
    # and a locus with an error has no reduced genotype to show.
    mutate(error   = if_else(is.na(MM) & is.na(error), "The matching API returned no result for this locus.", error),
           recip_P = if_else(is.na(error), recip_P, NA_character_),
           donor_P = if_else(is.na(error), donor_P, NA_character_))

  loci <- loci |>
    left_join(results |> select(locus, MM, MM_two_field, error, recip_P, donor_P), join_by(locus))

  # ---- DPB1 TCE permissiveness ----
  # Only when DPB1 was compared and is mismatched at the P group level in the
  # chosen direction.
  dpb1 <- loci |> filter(locus == dpb1_locus)
  tce  <- NULL
  if (dpb1$comparable && is.na(dpb1$error) && dpb1$MM > 0) {
    tce <- dpb1_tce(dpb1$recip_gl, dpb1$donor_gl, direction)
  }

  # ---- X/10 and X/8 match grades ----
  # Each from its own loci only; DQA1, DPA1, and DPB1 are in neither.
  grade_for <- function(match_grade) {
    out <- list(grade = NA_integer_, note = NA_character_, two_field = NA_integer_)
    graded <- loci |> filter(locus %in% grade_loci[[match_grade]])

    if (!all(graded$comparable)) {
      out$note <- "High-resolution typing is not given for both recipient and donor at every graded locus."
      return(out)
    }
    if (any(!is.na(graded$error))) {
      out$note <- "One or more graded loci could not be compared."
      return(out)
    }

    recip_all <- str_c(graded$recip_gl, collapse = "^")
    donor_all <- str_c(graded$donor_gl, collapse = "^")

    # The grade at the P group level and, for the comments, on two-field names.
    grade_request <- function(preprocess) api_request("/match/hct", matching_body(
      recip_all, donor_all, preprocess, match_grade = match_grade, scope = scope), host)
    hct <- list(grade_request(TRUE), grade_request(FALSE)) |>
      req_perform_parallel(on_error = "continue", progress = FALSE)
    hct <- list(api_result(hct[[1]]), two_field_result(hct[[2]]))
    summary_of <- function(r) {
      if (r$ok && !is.null(r$body$match_summary)) suppressWarnings(as.integer(r$body$match_summary)) else NA_integer_
    }

    out$grade     <- summary_of(hct[[1]])
    out$two_field <- summary_of(hct[[2]])
    # No grade always comes with a reason.
    if (is.na(out$grade)) {
      out$note <- if (is.na(hct[[1]]$error)) "The matching API returned no match grade." else hct[[1]]$error
    }
    out
  }
  grades <- map(set_names(names(grade_loci)), grade_for)

  list(
    loci = loci,
    tce = tce,
    grades = grades,
    direction = direction,
    scope = scope,
    ignored = union(recipient$ignored, donor$ignored),
    versions = list(
      host               = host,
      api                = health$api_version %||% "unknown",
      api_immunogenetr   = health$immunogenetr_version %||% "unknown",
      ipd_imgt_hla       = health$ipd_imgt_hla_version %||% "unknown",
      py_ard             = health$py_ard_version %||% "unknown"
    )
  )
}

# ---- the genotypes that were matched ----------------------------------------

# The recipient's and donor's genotypes as py-ard reduced them to P groups, as
# GL Strings without the "HLA-" prefix (e.g. "A*01:01P+A*01:11N^B*..."),
# in report locus order. Only loci the API compared are included; returns NA
# for a person when none were.
hct_reduced_gl <- function(match) {
  compared <- match$loci |> filter(!is.na(recip_P), !is.na(donor_P))
  as_gl <- function(x) if (length(x) == 0) NA_character_ else str_remove_all(str_flatten(x, "^"), "HLA-")
  list(recipient = as_gl(compared$recip_P), donor = as_gl(compared$donor_P))
}

# ---- comments printed under the match grades -------------------------------

# Returns a character vector, one comment per element. Every comment is decided
# here from the results.
hct_comments <- function(match) {
  loci <- match$loci
  short <- function(gl) HLA_prefix_remove(gl, keep_locus = TRUE) |> str_replace_all(fixed("+"), ", ")
  comments <- character()

  # Loci that were not compared, and why. DQA1 and DPA1 are often not typed at
  # all; when neither person is typed there, the NC cell says enough.
  not_compared <- loci |>
    filter(!comparable) |>
    filter_out(locus %in% c("HLA-DQA1", "HLA-DPA1"), recip_status == "not typed", donor_status == "not typed")
  for (i in seq_len(nrow(not_compared))) {
    row <- not_compared[i, ]
    who <- c(if (row$recip_status != "typed") str_c("recipient ", row$recip_status),
             if (row$donor_status != "typed") str_c("donor ", row$donor_status))
    comments <- c(comments, str_c(row$locus, " was not compared: ", str_flatten_comma(who), "."))
  }

  # Loci the API could not compare.
  failed <- loci |> filter(comparable, !is.na(error))
  for (i in seq_len(nrow(failed))) {
    row <- failed[i, ]
    comments <- c(comments, str_c(row$locus, " could not be compared (recipient ", short(row$recip_gl),
                                  "; donor ", short(row$donor_gl), "). The matching service reported: ",
                                  row$error,
                                  # The usual cause, in plain words.
                                  if (str_detect(row$error, "unambiguous")) str_c(
                                    " This usually means an allele name does not identify a single allele ",
                                    "at the P group level, for example a null allele given with fewer ",
                                    "than all of its fields.") else ""))
  }

  # Why a match grade is missing, one comment per reason (the X/10 and X/8
  # grades usually fail for the same one). This is printed in the comments
  # table, which escapes it for Typst; it can carry an API message.
  missing <- match$grades |>
    keep(\(g) is.na(g$grade) && !is.na(g$note)) |>
    imap_chr(\(g, mg) g$note)
  for (note in unique(missing)) {
    which <- str_c("X/", grade_out_of[names(missing)[missing == note]])
    comments <- c(comments, str_c(
      "The ", str_flatten(which, " and "), " match grade", if (length(which) > 1) "s were" else " was",
      " not calculated. ", note))
  }

  # Where P group reduction changed a mismatch count, in one line. The reduced
  # genotypes themselves are printed above the comments.
  changed <- loci |>
    filter(comparable, is.na(error), !is.na(MM_two_field)) |>
    filter(MM != MM_two_field) |>
    pull(locus) |>
    str_remove("^HLA-")
  grade_changes <- match$grades |>
    imap(\(g, mg) if (!is.na(g$grade) && !is.na(g$two_field) && g$grade != g$two_field) {
      str_c(g$two_field, "/", grade_out_of[[mg]], " to ", g$grade, "/", grade_out_of[[mg]])
    }) |>
    compact() |>
    unlist()
  if (length(changed) > 0) {
    comments <- c(comments, str_c(
      "P group reduction changed the mismatch count at ", str_flatten_comma(changed, ", and "),
      if (length(grade_changes) > 0) str_c(", and the match grade from ", str_flatten(grade_changes, " and from "),
                                           " (two-field allele names to P groups)") else "",
      ". Alleles in the same P group encode the same protein sequence in the antigen recognition domain."))
  }

  # DPB1 TCE permissiveness.
  if (!is.null(match$tce)) {
    tce <- match$tce
    if (is.na(tce$error)) {
      comments <- c(comments, str_c(
        "DPB1 is mismatched. T-cell epitope (TCE) prediction, algorithm version ", dpb1_tce_version,
        ": ", tce$prediction,
        # Say why a non-permissive prediction is shown as P.
        if (tce$label == "P" && !is.na(tce$np_direction)) str_c(
          " (non-permissive in the ", tce$np_direction, " direction only, so permissive in the chosen ",
          match$direction, " direction)") else "",
        ". TCE groups: ", tce$groups, ". Service: ", dpb1_tce_docs_url))
    } else {
      comments <- c(comments, str_c("DPB1 is mismatched, but TCE permissiveness is not available. ", tce$error))
    }
    for (note in tce$notes) {
      comments <- c(comments, str_c("The DPB1 TCE service noted: ", note, "."))
    }
  }

  # The two-field comparison is only a cross-check, but say so if it was unavailable.
  unchecked <- loci |> filter(comparable, is.na(error), is.na(MM_two_field))
  if (nrow(unchecked) > 0) {
    comments <- c(comments, str_c("The effect of P group reduction could not be assessed at ",
                                  str_flatten_comma(unchecked$locus), "."))
  }
  unchecked_grades <- keep(match$grades, \(g) !is.na(g$grade) && is.na(g$two_field))
  if (length(unchecked_grades) > 0) {
    comments <- c(comments, str_c("The two-field comparison could not be made for the ",
                                  str_flatten(str_c("X/", grade_out_of[names(unchecked_grades)]), " and "),
                                  " match grade", if (length(unchecked_grades) > 1) "s" else "", "."))
  }

  # Loci in the typing that this report does not compare.
  if (length(match$ignored) > 0) {
    comments <- c(comments, str_c("Typing at ", str_flatten_comma(match$ignored),
                                  " was given but is not part of this report."))
  }

  comments
}
