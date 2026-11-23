# harmonisationTable

Summary of `harmonisationTable.tsv`, one row per `TEST_NAME` + `PREPROCESED_UNIT` pair.

## Mapping status

A row with an `ignore_mapping_reason` is ignored; otherwise it is approved (`APPROVED` or `ERROR:<reason>` in `mapping_status`) or not approved. `n with warning` and `n with error` count the rows with a warning that is not marked `ignore`: an error on an approved row, a warning on any other.

| status | n | % | n with warning | n with error |
| --- | ---: | ---: | ---: | ---: |
| approved | 7,136 | 92.0% | 0 | 239 |
| not approved | 387 | 5.0% | 264 | 0 |
| ignored | 237 | 3.1% | 2 | 0 |
| total | 7,760 | 100.0% | 266 | 239 |

## Approved

|  | n | % of approved rows |
| --- | ---: | ---: |
| rows (TEST_NAME + PREPROCESED_UNIT) | 7,136 |  |
| distinct concept_ids | 1,523 |  |
| rows with a group | 3,534 | 49.5% |
| distinct groups | 395 |  |
| rows with a conversion | 3,395 | 47.6% |
