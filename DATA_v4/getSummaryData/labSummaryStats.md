# Lab Summary -- Stats

Source: `DATA_v4/getSummaryData/labSummary.tsv`

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
| X | X | X | 8896 | 33.2% | 212539826 | 82.4% |
| X | X |  | 19 | 0.1% | 223 | 0.0% |
| X |  | X | 0 | 0.0% | 0 | 0.0% |
| X |  |  | 17883 | 66.7% | 45275747 | 17.6% |
| **total** | | | 26798 | 100.0% | 257815796 | 100.0% |

## Unit source composition

Each `unit_source` bucket: how many pairs have any record in it, and what
share of all records fall in it.

| bucket | n rows | % rows | n records | % records |
|---|---|---|---|---|
| Source | 1102 | 4.1% | 750487 | 0.3% |
| PrimaryInjection | 37 | 0.1% | 38271 | 0.0% |
| SecondaryCorrection | 17 | 0.1% | 28907 | 0.0% |
| no unit_source recorded (NA) | 26798 | 100.0% | 256998597 | 99.7% |

## Value source composition

Same as above, for `value_source`.

| bucket | n rows | % rows | n records | % records |
|---|---|---|---|---|
| Source | 8788 | 32.8% | 184068490 | 71.4% |
| Extracted | 907 | 3.4% | 28449624 | 11.0% |
| QCOut | 37 | 0.1% | 19528 | 0.0% |
| no value recorded (NA) | 18418 | 68.7% | 45277313 | 17.6% |
