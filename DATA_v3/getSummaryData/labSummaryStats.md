# Lab Summary -- Stats

Source: `DATA_v3/getSummaryData/labSummary.tsv`

## Overview

Total records across all pairs: 257,363,005

| bucket | n | % |
|---|---|---|
| total TEST_NAME/UNIT pairs | 26613 | 100.0% |
| with value_deciles computed | 5632 | 21.2% |

### Name / unit / value coverage

Every `TEST_NAME`/`UNIT` pair against the three things it may or may not
carry: a real `TEST_NAME` (not the upstream's stringified missing value,
`"NA"`), a recorded `UNIT`, and at least one record with a value
(`value_missing_p` under 100).

| name | unit | value | n rows | % rows | n records | % records |
|---|---|---|---|---|---|---|
| X | X | X | 8606 | 32.3% | 179527254 | 69.8% |
| X | X |  | 150 | 0.6% | 17034 | 0.0% |
| X |  | X | 3541 | 13.3% | 61271567 | 23.8% |
| X |  |  | 14316 | 53.8% | 16547150 | 6.4% |
| **total** | | | 26613 | 100.0% | 257363005 | 100.0% |

### Name / unit / deciles coverage

Same as above, with `value_deciles` computed in place of `value`. These
are different facts, not two views of the same thing: `value_deciles` is
empty for any pair below the upstream decile-computation's volume floor,
whether or not it actually has recorded values (see Action) -- so this
table's `X`s are a strict subset of the value-coverage table's.

| name | unit | deciles | n rows | % rows | n records | % records |
|---|---|---|---|---|---|---|
| X | X | X | 4115 | 15.5% | 179305671 | 69.7% |
| X | X |  | 4641 | 17.4% | 238617 | 0.1% |
| X |  | X | 1517 | 5.7% | 55409073 | 21.5% |
| X |  |  | 16340 | 61.4% | 22409644 | 8.7% |
| **total** | | | 26613 | 100.0% | 257363005 | 100.0% |

## Unit source composition

Each `unit_source` bucket: how many pairs have any record in it, and what
share of all records fall in it.

| bucket | n rows | % rows | n records | % records |
|---|---|---|---|---|
| Source | 0 | 0.0% | 0 | 0.0% |
| PrimaryInjection | 0 | 0.0% | 0 | 0.0% |
| SecondaryCorrection | 0 | 0.0% | 0 | 0.0% |
| no unit_source recorded (NA) | 26613 | 100.0% | 257363005 | 100.0% |

## Value source composition

Same as above, for `value_source`.

| bucket | n rows | % rows | n records | % records |
|---|---|---|---|---|
| Source | 10122 | 38.0% | 184150248 | 71.6% |
| Extracted | 2598 | 9.8% | 26904949 | 10.5% |
| QCOut | 300 | 1.1% | 683014 | 0.3% |
| no value recorded (NA) | 17810 | 66.9% | 45624280 | 17.7% |
