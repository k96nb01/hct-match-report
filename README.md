# HCT donor match report

A one-page PDF match report for a hematopoietic cell transplantation (HCT)
recipient and donor, built on the public
[immunogenetr matching API](https://api.immunogenetr.org/__docs__/).

Give it two high-resolution HLA typings. It returns:

- the recipient and donor typing at A, B, C, DRB1, DQB1, and DPB1;
- a **Mismatches** line: the bidirectional mismatch count (1 or 2) at A, B, C,
  DRB1, and DQB1 after both typings are reduced to **P groups**, and **P**
  (permissive) or **NP** (non-permissive) at a mismatched DPB1, by T-cell
  epitope (TCE) group. A matched locus is blank; `NC` (not compared) and `ERR`
  (could not be compared) mark the rest, so a blank always means "compared and
  matched";
- the **X/10 match grade** (A, B, C, DRB1, DQB1) at the P group level;
- the **genotypes matched**: both typings as py-ard reduced them to P groups,
  as GL strings, so the input to the matching is always visible;
- **comments**: the loci where P group reduction changed the mismatch count
  (and the grade) compared with two-field allele names, the DPB1 TCE result
  with the service's URL, and anything that could not be compared;
- a footer recording the matching API's URL and every software and database
  version that produced the result.

> **For research use only.** Any clinical use requires independent validation
> according to local regulations.

## What is sent where

Only typing leaves your machine. The matching API receives GL strings, the
locus names, and the matching options. The IPD-IMGT/HLA DPB1 TCE service at
EBI receives the four DPB1 allele names, and only when DPB1 is mismatched.
The optional recipient and donor labels are printed on the PDF and never sent
anywhere. Do not put identifiers in the typing.

## Requirements

- R (4.1 or later) with `tidyverse`, `httr2`, `immunogenetr`, `tinytable`
  (tested with 0.18.0; the Typst output depends on a recent version),
  `quarto`, `yaml`, `withr`, and, for the app, `shiny`:

  ```r
  install.packages(c("tidyverse", "httr2", "immunogenetr", "tinytable", "quarto", "yaml", "withr", "shiny"))
  ```

- The [Quarto CLI](https://quarto.org/docs/get-started/) (1.4 or later), which
  renders the PDF through Typst.
- Internet access to `api.immunogenetr.org` and `www.ebi.ac.uk`.

## Use

### The app

From the project folder:

```r
shiny::runApp()
```

Enter two alleles per locus for each person (leave the second blank for a
homozygote), or paste a GL string, then press **Generate report**.

### From R

From the project folder:

```r
source("R/report.R")

hct_match_report(
  recipient = "HLA-A*01:01^HLA-B*08:01+HLA-B*44:02^HLA-C*05:01+HLA-C*07:01^HLA-DRB1*03:01+HLA-DRB1*14:01^HLA-DQB1*02:01+HLA-DQB1*05:03^HLA-DPB1*04:01+HLA-DPB1*02:01",
  donor     = list(A = c("01:01", "01:01:01:02N"), B = c("08:01", "44:03"), C = c("05:01", "07:01"),
                   DRB1 = c("03:01", "14:54"), DQB1 = c("02:02", "05:03"), DPB1 = c("04:01", "17:01")),
  file      = "match_report.pdf"
)
```

This synthetic pair shows every part of the report: the recipient is
homozygous at A (one allele given) and the donor carries a null allele there,
which matches; B\*44:02 and B\*44:03 are a real mismatch; DRB1\*14:01/14:54
and DQB1\*02:01/02:02 are mismatched by allele name but in the same P groups;
and DPB1 is a non-permissive mismatch. The grade is 9/10 at the P group level
and 7/10 by two-field allele name.

Other arguments: `recipient_label` and `donor_label` (printed on the report
only), `api_host` (another deployment of the matching API), and `quiet = FALSE`
to see Quarto's output.

Each typing is either a GL string or a named list by locus. A GL string must
be unambiguous: no `/`, `|`, or `~`, and every allele written in full
(`HLA-A*02:01`). In a list, a value may carry its own prefix (`A*02:01`) only
under the matching locus. Typing at other loci is accepted and noted on the
report, but not compared. A typing that cannot be used stops with a plain
message before anything is sent.

To check the matching without rendering, `source("R/matching_api_client.R")`
and `source("R/hct_match.R")`, then call `hct_match(recipient, donor)` and
`hct_comments()` on the result.

## How the matching is calculated

Each report makes up to eight calls to the matching API: `/health` for the
versions, one `/mismatch/number` call per locus (the five match loci and
DPB1), and one `/match/hct` call for the grade. Every call reduces both GL
strings with py-ard to P groups (`redux_mode = "P"`) before counting. One
request per locus means a problem at one locus (an allele py-ard rejects, for
example) cannot stop the others.

The two-field comparison used in the comments is calculated locally with
immunogenetr on the typing truncated to two fields.

DPB1 permissiveness comes from the
[IPD-IMGT/HLA DPB1 T-cell epitope matching service](https://www.ebi.ac.uk/ipd/imgt/hla/matching/match_apis/),
algorithm version 2.1. It is called only after the matching API has accepted
the DPB1 typing and found a mismatch: the TCE service does not check allele
names (it places a name it does not know in group 3 and answers
"Permissive"), so the matching API goes first.

**Failures are explicit.** If the matching API cannot be reached, or answers
with anything other than JSON, no report is produced and the reason is shown.
If the API rejects the typing at one locus (for example a null allele given
with fewer than all of its fields, which is ambiguous at the P group level),
that locus prints `ERR` with a comment, and the grade is not calculated if it
is one of the five match loci. If the TCE service cannot be reached, the
report is still produced with DPB1 `ERR` and a comment.

## Testing

`tests/cases.R` holds 13 synthetic recipient/donor pairs that exercise each
branch of the report, with the expected grades. No real person's typing is
used. `tests/check_cases.R` also checks, offline, that bad typings are
rejected with the right message.

```sh
Rscript tests/check_cases.R         # check every case against the live API
Rscript tests/check_cases.R --pdf   # also render one PDF per case to tests/output/
Rscript tests/check_cases.R --pdf --verbose   # ... showing Quarto's output
```

## Files

| File | Purpose |
|---|---|
| `app.R` | Shiny app: typing form and report download |
| `report.qmd` | The report (Quarto, rendered to PDF with Typst) |
| `R/report.R` | `hct_match_report()`: render the report from R |
| `R/hct_match.R` | Matching logic and report comments |
| `R/matching_api_client.R` | R client for the matching API |
| `tests/` | Synthetic test cases and the script that checks them |

See [`NEWS.md`](NEWS.md) for the version history and [`TODO.md`](TODO.md) for
open work.

## License

MIT. See [`LICENSE`](LICENSE).
