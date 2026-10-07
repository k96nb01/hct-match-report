# Example recipient/donor pairs offered on the app's landing page, as GL
# Strings, so a visitor can try the report without typing anything. All are
# synthetic: no real person's typing. tests/cases.R checks each one's grades.
# Base R only: Shiny sources everything in R/ before app.R loads any package.

example_pairs <- list(
  list(
    name = "One mismatch, a null allele, and a non-permissive DPB1",
    description = paste0(
      "The recipient is homozygous at A; the donor carries a null allele there, which matches. ",
      "B*44:02 and B*44:03 are a real mismatch. DRB1 and DQB1 differ by allele name but are in ",
      "the same P groups. DPA1 is mismatched, and DPB1 is a non-permissive mismatch."),
    recipient = "HLA-A*01:01^HLA-B*08:01+HLA-B*44:02^HLA-C*05:01+HLA-C*07:01^HLA-DRB1*03:01+HLA-DRB1*14:01^HLA-DQA1*05:01+HLA-DQA1*01:04^HLA-DQB1*02:01+HLA-DQB1*05:03^HLA-DPA1*01:03+HLA-DPA1*01:03^HLA-DPB1*04:01+HLA-DPB1*02:01",
    donor     = "HLA-A*01:01+HLA-A*01:11N^HLA-B*08:01+HLA-B*44:03^HLA-C*05:01+HLA-C*07:01^HLA-DRB1*03:01+HLA-DRB1*14:54^HLA-DQA1*05:01+HLA-DQA1*01:04^HLA-DQB1*02:02+HLA-DQB1*05:03^HLA-DPA1*01:03+HLA-DPA1*02:01^HLA-DPB1*04:01+HLA-DPB1*17:01"
  ),
  list(
    name = "Matched at the P group level, not by allele name",
    description = paste0(
      "A*02:09 and C*07:50 are in the same P groups as A*02:01 and C*07:02, so the pair is ",
      "10/10 at the P group level but 8/10 by two-field allele name."),
    recipient = "HLA-A*02:01+HLA-A*24:02^HLA-B*07:02+HLA-B*44:02^HLA-C*07:02+HLA-C*05:01^HLA-DRB1*15:01+HLA-DRB1*04:01^HLA-DQA1*01:02+HLA-DQA1*03:01^HLA-DQB1*06:02+HLA-DQB1*03:02^HLA-DPA1*01:03+HLA-DPA1*01:03^HLA-DPB1*04:01+HLA-DPB1*02:01",
    donor     = "HLA-A*02:09+HLA-A*24:02^HLA-B*07:02+HLA-B*44:02^HLA-C*07:50+HLA-C*05:01^HLA-DRB1*15:01+HLA-DRB1*04:01^HLA-DQA1*01:02+HLA-DQA1*03:01^HLA-DQB1*06:02+HLA-DQB1*03:02^HLA-DPA1*01:03+HLA-DPA1*01:03^HLA-DPB1*04:01+HLA-DPB1*02:01"
  ),
  list(
    name = "Mismatches in opposite directions (try the direction and scope options)",
    description = paste0(
      "The recipient is homozygous at A and the donor at B. A is mismatched only host versus ",
      "graft, and B only graft versus host. Bidirectional with locus scope gives 8/10; genotype ",
      "scope, GvH, or HvG gives 9/10."),
    recipient = "HLA-A*01:01^HLA-B*08:01+HLA-B*44:02^HLA-C*05:01+HLA-C*07:01^HLA-DRB1*03:01+HLA-DRB1*04:01^HLA-DQA1*05:01+HLA-DQA1*03:01^HLA-DQB1*02:01+HLA-DQB1*03:02^HLA-DPA1*01:03^HLA-DPB1*04:01+HLA-DPB1*02:01",
    donor     = "HLA-A*01:01+HLA-A*02:01^HLA-B*08:01^HLA-C*05:01+HLA-C*07:01^HLA-DRB1*03:01+HLA-DRB1*04:01^HLA-DQA1*05:01+HLA-DQA1*03:01^HLA-DQB1*02:01+HLA-DQB1*03:02^HLA-DPA1*01:03^HLA-DPB1*04:01+HLA-DPB1*02:01"
  )
)
