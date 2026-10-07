# hct-match-report 0.2.0 (in development)

- DQA1 and DPA1 are shown in the typing table and counted on the Mismatches
  line, at the P group level. They are not part of either match grade.
  When neither person is typed at one of them, its cell shows NC without a
  comment.
- An X/8 match grade (A, B, C, DRB1) is reported beside the X/10 grade, with
  its own two-field cross-check in the comments.
- Match direction is selectable: bidirectional (default), GvH, or HvG. For
  bidirectional matching, the scope of the grade is selectable: locus
  (default) or genotype. Both are printed on the report and are arguments of
  `hct_match_report()`.
- All matching is done by the matching API. The two-field comparison in the
  comments, previously calculated with the local immunogenetr, is now the
  same API called on two-field names without P group reduction, so every
  count and grade comes from one service with one set of versions (up to 21
  API calls per report). Locally, immunogenetr only truncates and formats
  allele names.
- DPB1 shows NP only when it is non-permissive in the chosen direction: always
  for bidirectional, or when the TCE service names the chosen direction or no
  direction; otherwise P, with a comment.
- The app offers three synthetic example pairs (`R/examples.R`) that fill the
  GL String boxes, one of which shows how direction and scope change the
  grade.
- `tests/cases.R` now checks the X/8 grades, the DQA1 and DPA1 cells, and the
  examples under every direction and scope (25 cases).

# hct-match-report 0.1.0 (2026-10-04)

First version: a public, simplified form of a laboratory BMT donor match
report, with every database and laboratory-system dependency removed.

- Input is two typings (GL Strings or allele names by locus) from a Shiny form
  or from `hct_match_report()` in R. Optional labels are printed only.
- Mismatch counts at A, B, C, DRB1, and DQB1 and the X/10 match grade at the
  P group level from the immunogenetr matching API; DPB1 permissiveness from
  the IPD-IMGT/HLA DPB1 TCE service; comments where P group reduction changed
  a result.
- The genotypes as py-ard reduced them (the input to the matching) are printed
  as GL Strings under the grade; the comments list the loci where P group
  reduction changed a count; the DPB1 comment and the footer give the TCE
  service's and the matching API's URLs.
- A non-JSON reply from the API (including an HTML page sent with HTTP 200)
  stops the report with a clear message; a failed
  render reports the matching error or the end of Quarto's own output.
- No font files are bundled: the report uses whichever of Arial, Helvetica,
  Liberation Sans, or DejaVu Sans is installed, else Typst's own font.
- Every typing is checked by `read_typing()` before anything is sent or
  rendered (ambiguity, phasing, unnamed or mismatched loci, more than two
  alleles, empty typing), with a plain message.
- 13 synthetic test cases (`tests/cases.R`) plus offline typing checks, all
  passing against the live API on 2026-10-04 (API 1.1.0, immunogenetr 1.5.0,
  py-ard 2.3.1, IPD-IMGT/HLA 3.65.0).
- Licensed MIT.
