# harmonizationTable

Summary of `harmonizationTable.tsv`, one row per `TEST_NAME` + `PREPROCESED_UNIT` pair.

## Mapping status

A row with an `ignore_mapping_reason` is ignored; otherwise it is approved (`APPROVED` or `ERROR` in `mapping_status`) or not approved. `n with warning` and `n with error` count the rows with a warning that is not marked `ignore`: an error on an approved row, a warning on any other.

| status | n | % | n with warning | n with error |
| --- | ---: | ---: | ---: | ---: |
| approved | 7,136 | 92.0% | 0 | 0 |
| not approved | 387 | 5.0% | 248 | 0 |
| ignored | 237 | 3.1% | 1 | 0 |
| total | 7,760 | 100.0% | 249 | 0 |

## Approved

|  | n | % of approved rows |
| --- | ---: | ---: |
| rows (TEST_NAME + PREPROCESED_UNIT) | 7,136 |  |
| distinct concept_ids | 1,523 |  |
| rows with a group | 3,605 | 50.5% |
| distinct groups | 533 |  |
| rows with a conversion | 3,506 | 49.1% |
