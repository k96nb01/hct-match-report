# Synthetic recipient/donor pairs that exercise each branch of the report.
# No real person's typing. Each case gives the expected match grade at the P
# group level (NA when it cannot be calculated), the expected two-field grade,
# and what the Mismatches line should show at DPB1.
#
# Used by tests/check_cases.R.

recipient_1 <- list(A = c("02:01", "24:02"), B = c("07:02", "44:02"), C = c("07:02", "05:01"),
                    DRB1 = c("15:01", "04:01"), DQB1 = c("06:02", "03:02"), DPB1 = c("04:01", "02:01"))

# A recipient with a null allele given at its full name.
recipient_2 <- list(A = c("01:01", "01:04:01:01N"), B = c("08:01", "08:01"), C = c("07:01", "07:01"),
                    DRB1 = c("03:01", "14:01"), DQB1 = c("02:01", "05:03"), DPB1 = c("04:01", "01:01"))

cases <- list(
  list(name = "sibling, 3 and 4 field typing", recipient = recipient_1,
       donor = list(A = c("02:01:01:01", "24:02:01:01"), B = c("07:02:01", "44:02:01:01"),
                    C = c("07:02:01:03", "05:01:01"), DRB1 = c("15:01:01:01", "04:01:01"),
                    DQB1 = c("06:02:01", "03:02:01"), DPB1 = c("04:01:01", "02:01:02")),
       grade = 10, grade_two_field = 10, dpb1 = ""),

  # A*02:09 and C*07:50 are in the same P groups as A*02:01 and C*07:02.
  list(name = "same P groups, different allele names", recipient = recipient_1,
       donor = list(A = c("02:09", "24:02"), B = c("07:02", "44:02"), C = c("07:50", "05:01"),
                    DRB1 = c("15:01", "04:01"), DQB1 = c("06:02", "03:02"), DPB1 = c("04:01", "02:01")),
       grade = 10, grade_two_field = 8, dpb1 = ""),

  list(name = "one B mismatch, DPB1 mismatch", recipient = recipient_1,
       donor = list(A = c("02:01", "24:02"), B = c("07:02", "44:03"), C = c("07:02", "05:01"),
                    DRB1 = c("15:01", "04:01"), DQB1 = c("06:02", "03:02"), DPB1 = c("04:01", "17:01")),
       grade = 9, grade_two_field = 9, dpb1 = "NP"),

  list(name = "haploidentical", recipient = recipient_1,
       donor = list(A = c("02:01", "01:01"), B = c("07:02", "08:01"), C = c("07:02", "07:01"),
                    DRB1 = c("15:01", "03:01"), DQB1 = c("06:02", "02:01"), DPB1 = c("04:01", "01:01")),
       grade = 5, grade_two_field = 5, dpb1 = "P"),

  # One allele per locus: a homozygous donor.
  list(name = "homozygous donor, one allele given per locus", recipient = recipient_1,
       donor = list(A = "02:01", B = "07:02", C = "07:02", DRB1 = "15:01", DQB1 = "06:02", DPB1 = "04:01"),
       grade = 5, grade_two_field = 5, dpb1 = "P"),

  list(name = "same null allele on both sides", recipient = recipient_2, donor = recipient_2,
       grade = 10, grade_two_field = 10, dpb1 = ""),

  # DRB1*14:54 and DQB1*02:02 are in the same P groups as DRB1*14:01 and
  # DQB1*02:01; the expressed A*01:01 homozygote matches the null-carrying
  # recipient.
  list(name = "expressed homozygote against a null; DRB1*14:54, DQB1*02:02", recipient = recipient_2,
       donor = list(A = c("01:01", "01:01"), B = c("08:01", "08:01"), C = c("07:01", "07:01"),
                    DRB1 = c("03:01", "14:54"), DQB1 = c("02:02", "05:03"), DPB1 = c("04:01", "01:01")),
       grade = 10, grade_two_field = 8, dpb1 = ""),

  # A null given at two fields is ambiguous at the P group level: A cannot be
  # compared, so there is no grade.
  list(name = "null allele given at two fields", recipient = recipient_2,
       donor = list(A = c("01:01", "01:04N"), B = c("08:01", "08:01"), C = c("07:01", "07:01"),
                    DRB1 = c("03:01", "14:01"), DQB1 = c("02:01", "05:03"), DPB1 = c("04:01", "01:01")),
       grade = NA, grade_two_field = NA, dpb1 = ""),

  list(name = "no DPB1 typing", recipient = recipient_2,
       donor = list(A = c("01:01", "01:04:01:01N"), B = c("08:01", "08:01"), C = c("07:01", "07:01"),
                    DRB1 = c("03:01", "14:01"), DQB1 = c("02:01", "05:03")),
       grade = 10, grade_two_field = 10, dpb1 = "NC"),

  list(name = "low-resolution typing only", recipient = recipient_2,
       donor = list(A = c("01", "01"), B = c("08", "08"), C = c("07", "07"),
                    DRB1 = c("03", "14"), DQB1 = c("02", "05")),
       grade = NA, grade_two_field = NA, dpb1 = "NC"),

  # Loci the report does not compare are accepted and noted in the comments.
  list(name = "extra loci (DRB4, DQA1) given",
       recipient = c(recipient_1, list(DRB4 = "01:03", DQA1 = c("01:02", "03:01"))),
       donor = recipient_1, grade = 10, grade_two_field = 10, dpb1 = ""),

  # The README example, which shows every part of the report at once: a null
  # allele that matches (A), a real allele mismatch that P groups do not merge
  # (B*44:02 vs B*44:03), two mismatches by allele name that P groups do merge
  # (DRB1*14:01/14:54 and DQB1*02:01/02:02), and a non-permissive DPB1.
  list(name = "README example",
       recipient = "HLA-A*01:01^HLA-B*08:01+HLA-B*44:02^HLA-C*05:01+HLA-C*07:01^HLA-DRB1*03:01+HLA-DRB1*14:01^HLA-DQB1*02:01+HLA-DQB1*05:03^HLA-DPB1*04:01+HLA-DPB1*02:01",
       donor     = "HLA-A*01:01+HLA-A*01:01:01:02N^HLA-B*08:01+HLA-B*44:03^HLA-C*05:01+HLA-C*07:01^HLA-DRB1*03:01+HLA-DRB1*14:54^HLA-DQB1*02:02+HLA-DQB1*05:03^HLA-DPB1*04:01+HLA-DPB1*17:01",
       grade = 9, grade_two_field = 7, dpb1 = "NP"),

  # The same recipient as a GL string, to exercise that input form.
  list(name = "recipient given as a GL string",
       recipient = "HLA-A*02:01+HLA-A*24:02^HLA-B*07:02+HLA-B*44:02^HLA-C*07:02+HLA-C*05:01^HLA-DRB1*15:01+HLA-DRB1*04:01^HLA-DQB1*06:02+HLA-DQB1*03:02^HLA-DPB1*04:01+HLA-DPB1*02:01",
       donor = recipient_1,
       grade = 10, grade_two_field = 10, dpb1 = "")
)
