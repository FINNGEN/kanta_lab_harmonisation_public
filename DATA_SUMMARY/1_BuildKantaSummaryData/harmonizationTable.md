# harmonizationTable

Summary of `harmonizationTable.tsv`, one row per `TEST_NAME` + `PREPROCESED_UNIT` pair.

## Mapping status

A row with an `ignore_mapping_reason` is ignored; otherwise it is approved or not approved by `APPROVED`.

| status | n | % |
| --- | ---: | ---: |
| approved | 7,136 | 92.0% |
| not approved | 387 | 5.0% |
| ignored | 237 | 3.1% |
| total | 7,760 | 100.0% |

## Approved

|  | n | % of approved rows |
| --- | ---: | ---: |
| rows (TEST_NAME + PREPROCESED_UNIT) | 7,136 |  |
| distinct concept_ids | 1,523 |  |
| rows with a group | 3,605 | 50.5% |
| distinct groups | 533 |  |
| rows with a conversion | 3,506 | 49.1% |
