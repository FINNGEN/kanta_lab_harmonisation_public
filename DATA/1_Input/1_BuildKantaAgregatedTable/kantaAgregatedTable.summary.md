# Name Unit Value combinations

Name / unit / value coverage of `kantaAgregatedTable.tsv`, one row per `TEST_NAME` + `MEASUREMENT_UNIT` pair. An `X` under unit means the pair has a recorded unit; under value, that at least one of its records has a value.

| name | unit | value | n rows | % rows | n records | % rec |
| --- | --- | --- | --- | --- | --- | --- |
| X | X | X | 9,351 | 32.5% | 230,874,814 | 82.2% |
| X | X |  | 170 | 0.6% | 27,929 | 0.0% |
| X |  | X | 3,167 | 11.0% | 9,273,101 | 3.3% |
| X |  |  | 16,084 | 55.9% | 40,783,918 | 14.5% |
| total |  |  | 28,772 | 100% | 280,959,762 | 100% |

# Units

Where the unit of the records came from (`unit_source_injection_correction_na_p`). A pair counts in a source when some of its records come from it, so `% rows` does not add up to 100%. `n records` is approximate (shares are rounded).

| source | n rows | % rows | n records | % rec |
| --- | --- | --- | --- | --- |
| Source | 9,366 | 32.6% | 190,405,264 | 67.8% |
| PrimaryInjection | 917 | 3.2% | 32,460,092 | 11.6% |
| SecondaryCorrection | 76 | 0.3% | 8,640,193 | 3.1% |
|  | 19,703 | 68.5% | 49,454,213 | 17.6% |
| total | 28,772 | 100% | 280,959,762 | 100% |

# Reference Ranges

Combinations of demographic bins with a reference range (`reference_range`): `AF` adult female, `AM` adult male, `MF` minor female, `MM` minor male. An `X` means the pair has a range for that bin; the row with no `X` has no reference range.

| AF | AM | MF | MM | n rows | % rows | n records | % rec |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  | 24,021 | 83.5% | 35,148,286 | 12.5% |
| X | X |  |  | 2,815 | 9.8% | 21,456,730 | 7.6% |
| X |  |  |  | 753 | 2.6% | 335,279 | 0.1% |
| X | X | X | X | 689 | 2.4% | 215,226,747 | 76.6% |
|  | X |  |  | 210 | 0.7% | 2,033,619 | 0.7% |
| X | X | X |  | 199 | 0.7% | 3,107,571 | 1.1% |
| X | X |  | X | 76 | 0.3% | 3,598,732 | 1.3% |
|  | X |  | X | 6 | 0.0% | 13,016 | 0.0% |
| X |  | X |  | 3 | 0.0% | 39,782 | 0.0% |
| total |  |  |  | 28,772 | 100% | 280,959,762 | 100% |

# Values

Where the value of the records came from (`value_source_extracted_qcout_na_p`); `na` is records with no value. Same counting as Units.

| source | n rows | % rows | n records | % rec |
| --- | --- | --- | --- | --- |
| Source | 10,539 | 36.6% | 200,315,814 | 71.3% |
| Extracted | 3,313 | 11.5% | 31,999,765 | 11.4% |
| QCOut | 38 | 0.1% | 21,443 | 0.0% |
|  | 19,945 | 69.3% | 48,618,069 | 17.3% |
| total | 28,772 | 100% | 280,959,762 | 100% |
