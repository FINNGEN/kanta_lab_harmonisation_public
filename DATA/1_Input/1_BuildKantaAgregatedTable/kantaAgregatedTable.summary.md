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
| Source | 9,398 | 32.7% | 195,572,464 | 69.6% |
| PrimaryInjection | 931 | 3.2% | 35,328,941 | 12.6% |
| SecondaryCorrection | 0 | 0.0% | 0 | 0.0% |
|  | 19,746 | 68.6% | 50,058,357 | 17.8% |
| total | 28,772 | 100% | 280,959,762 | 100% |

# Values

Where the value of the records came from (`value_source_extracted_qcout_na_p`); `na` is records with no value. Same counting as Units.

| source | n rows | % rows | n records | % rec |
| --- | --- | --- | --- | --- |
| Source | 10,539 | 36.6% | 200,315,814 | 71.3% |
| Extracted | 3,313 | 11.5% | 31,999,765 | 11.4% |
| QCOut | 38 | 0.1% | 21,443 | 0.0% |
|  | 19,945 | 69.3% | 48,618,069 | 17.3% |
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

# Test Outcomes

Combinations of test outcomes (`test_outcome`, from `summaryOutcomes.tsv`), e.g. `N` normal, `A` abnormal, `L` / `H` low / high, `AA` / `LL` / `HH` very abnormal / low / high, `POS` / `NEG` positive / negative. An `X` means some records of the pair have that outcome; the row with no `X` has no test outcome.

| N | A | AA | L | LL | H | HH | POS | NEG | IND | I | n rows | % rows | n records | % rec |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |  |  |  |  | 15,177 | 52.7% | 4,821,905 | 1.7% |
| X |  |  |  |  |  |  |  |  |  |  | 5,983 | 20.8% | 12,293,182 | 4.4% |
|  | X |  |  |  |  |  |  |  |  |  | 2,647 | 9.2% | 3,790,137 | 1.3% |
| X | X |  |  |  |  |  |  |  |  |  | 2,010 | 7.0% | 20,816,713 | 7.4% |
| X | X |  |  |  | X |  |  |  |  |  | 832 | 2.9% | 23,073,603 | 8.2% |
| X | X |  | X |  | X |  |  |  |  |  | 497 | 1.7% | 68,766,344 | 24.5% |
| X |  |  |  |  | X |  |  |  |  |  | 353 | 1.2% | 481,512 | 0.2% |
|  |  |  |  |  | X |  |  |  |  |  | 192 | 0.7% | 82,866 | 0.0% |
| X | X |  | X |  |  |  |  |  |  |  | 191 | 0.7% | 7,966,829 | 2.8% |
| X |  |  | X |  | X |  |  |  |  |  | 156 | 0.5% | 529,967 | 0.2% |
|  | X |  |  |  | X |  |  |  |  |  | 140 | 0.5% | 149,197 | 0.1% |
| X |  |  | X |  |  |  |  |  |  |  | 136 | 0.5% | 143,778 | 0.1% |
|  | X |  | X |  |  |  |  |  |  |  | 58 | 0.2% | 29,200 | 0.0% |
| X | X | X |  |  |  |  |  |  |  |  | 55 | 0.2% | 1,218,478 | 0.4% |
|  |  |  | X |  |  |  |  |  |  |  | 52 | 0.2% | 8,187 | 0.0% |
|  |  |  | X |  | X |  |  |  |  |  | 52 | 0.2% | 123,367 | 0.0% |
|  | X |  | X |  | X |  |  |  |  |  | 37 | 0.1% | 385,857 | 0.1% |
| X | X |  | X |  | X | X |  |  |  |  | 33 | 0.1% | 17,330,522 | 6.2% |
| X | X |  |  |  | X | X |  |  |  |  | 24 | 0.1% | 3,516,965 | 1.3% |
| X |  | X |  |  |  |  |  |  |  |  | 21 | 0.1% | 41,899 | 0.0% |
| X | X |  | X | X | X |  |  |  |  |  | 21 | 0.1% | 5,544,947 | 2.0% |
| X | X |  | X | X | X | X |  |  |  |  | 20 | 0.1% | 15,631,282 | 5.6% |
| X | X | X | X |  | X |  |  |  |  |  | 11 | 0.0% | 9,920,453 | 3.5% |
| X | X | X | X |  | X | X |  |  |  |  | 10 | 0.0% | 18,192,550 | 6.5% |
| X | X | X | X | X | X | X |  |  |  |  | 6 | 0.0% | 41,223,940 | 14.7% |
|  | X |  |  |  | X | X |  |  |  |  | 5 | 0.0% | 21,334 | 0.0% |
|  |  | X |  |  |  |  |  |  |  |  | 4 | 0.0% | 233 | 0.0% |
|  | X | X |  |  |  |  |  |  |  |  | 4 | 0.0% | 1,055 | 0.0% |
| X | X |  |  |  | X |  |  |  |  | X | 4 | 0.0% | 983,658 | 0.4% |
| X | X |  | X | X |  |  |  |  |  |  | 4 | 0.0% | 21,587 | 0.0% |
| X | X | X |  |  | X |  |  |  |  |  | 4 | 0.0% | 1,899,044 | 0.7% |
| X | X | X |  |  | X | X |  |  |  |  | 4 | 0.0% | 6,284,164 | 2.2% |
| X |  |  | X | X | X |  |  |  |  |  | 3 | 0.0% | 8,998 | 0.0% |
|  |  |  |  |  | X | X |  |  |  |  | 2 | 0.0% | 154 | 0.0% |
|  | X |  | X |  | X | X |  |  |  |  | 2 | 0.0% | 71,282 | 0.0% |
| X |  |  |  |  |  |  | X | X |  |  | 2 | 0.0% | 4,010 | 0.0% |
| X | X |  |  |  |  |  |  |  | X |  | 2 | 0.0% | 774,191 | 0.3% |
| X | X |  |  |  |  |  | X | X |  |  | 2 | 0.0% | 113,190 | 0.0% |
| X | X |  |  |  |  | X |  |  |  |  | 2 | 0.0% | 28,559 | 0.0% |
| X | X |  | X |  | X |  |  |  |  | X | 2 | 0.0% | 397,592 | 0.1% |
| X | X | X | X |  |  |  |  |  |  |  | 2 | 0.0% | 6,356 | 0.0% |
| X | X | X | X | X | X |  |  |  |  |  | 2 | 0.0% | 11,885,673 | 4.2% |
|  |  |  | X |  | X | X |  |  |  |  | 1 | 0.0% | 12,438 | 0.0% |
|  |  |  | X | X | X |  |  |  |  |  | 1 | 0.0% | 24,113 | 0.0% |
|  | X |  | X |  |  | X |  |  |  |  | 1 | 0.0% | 826 | 0.0% |
| X |  |  |  |  |  |  |  |  | X |  | 1 | 0.0% | 8,539 | 0.0% |
| X |  |  |  |  |  | X |  |  |  |  | 1 | 0.0% | 12,120 | 0.0% |
| X |  |  |  |  | X |  |  |  |  | X | 1 | 0.0% | 4,539 | 0.0% |
| X | X |  | X |  |  |  |  |  | X |  | 1 | 0.0% | 1,411,430 | 0.5% |
| X | X | X |  |  |  |  | X | X |  |  | 1 | 0.0% | 900,997 | 0.3% |
| total |  |  |  |  |  |  |  |  |  |  | 28,772 | 100% | 280,959,762 | 100% |
