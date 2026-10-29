# Lab Summary -- Stats

Source: `DATA_v4/1_GetSummaryData/labSummary.tsv`

## Overview

Total records across all pairs: 257,815,796

| bucket | n | % |
|---|---|---|
| total TEST_NAME/UNIT pairs | 26798 | 100.0% |
| with value_deciles computed | 5333 | 19.9% |

### Name / unit / value coverage

Every `TEST_NAME`/`UNIT` pair against the three things it may or may not
carry: a real `TEST_NAME` (not the upstream's stringified missing value,
`"NA"`), a recorded `UNIT`, and at least one record with a value
(`value_missing_p` under 100).

| name | unit | value | n rows | % rows | n records | % records |
|---|---|---|---|---|---|---|
| X | X | X | 8745 | 32.6% | 212508947 | 82.4% |
| X | X |  | 170 | 0.6% | 31102 | 0.0% |
| X |  | X | 2928 | 10.9% | 10479927 | 4.1% |
| X |  |  | 14955 | 55.8% | 34795820 | 13.5% |
| **total** | | | 26798 | 100.0% | 257815796 | 100.0% |

### Name / unit / deciles coverage

Same as above, with `value_deciles` computed in place of `value`. These
are different facts, not two views of the same thing: `value_deciles` is
empty for any pair below the upstream decile-computation's volume floor,
whether or not it actually has recorded values (see Action) -- so this
table's `X`s are a strict subset of the value-coverage table's.

| name | unit | deciles | n rows | % rows | n records | % records |
|---|---|---|---|---|---|---|
| X | X | X | 4212 | 15.7% | 212319624 | 82.4% |
| X | X |  | 4703 | 17.5% | 220425 | 0.1% |
| X |  | X | 1121 | 4.2% | 6685374 | 2.6% |
| X |  |  | 16762 | 62.5% | 38590373 | 15.0% |
| **total** | | | 26798 | 100.0% | 257815796 | 100.0% |

## Unit source composition

Each `unit_source` bucket: how many pairs have any record in it, and what
share of all records fall in it.

| bucket | n rows | % rows | n records | % records |
|---|---|---|---|---|
| Source | 8788 | 32.8% | 195844802 | 76.0% |
| PrimaryInjection | 684 | 2.6% | 8986400 | 3.5% |
| SecondaryCorrection | 27 | 0.1% | 7707753 | 3.0% |
| no unit_source recorded (NA) | 18377 | 68.6% | 45277059 | 17.6% |

## Value source composition

Same as above, for `value_source`.

| bucket | n rows | % rows | n records | % records |
|---|---|---|---|---|
| Source | 9872 | 36.8% | 184288129 | 71.5% |
| Extracted | 3088 | 11.5% | 28921728 | 11.2% |
| QCOut | 38 | 0.1% | 19544 | 0.0% |
| no value recorded (NA) | 18606 | 69.4% | 44587916 | 17.3% |
