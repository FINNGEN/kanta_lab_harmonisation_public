# kantaAgregatedTable validation

Validation of the input tables of `1_BuildKantaAgregatedTable` (`DATA/1_Input/0_KantaAgregatedData/`). 
The step stops when a test is an ERROR.

## Validation summary

| table | SUCCESS | WARNING | ERROR |
| --- | --- | --- | --- |
| summaryTest.tsv | 7 | 0 | 0 |
| summaryUnitSource.tsv | 10 | 0 | 0 |
| summaryValuesSource.tsv | 10 | 0 | 0 |
| summaryValues.tsv | 12 | 0 | 0 |
| summaryReference.tsv | 11 | 1 | 0 |
| summaryOutcomes.tsv | 8 | 0 | 0 |
| ALL | 58 | 1 | 0 |

## Tests

| table | result | test | n rows | message |
| --- | --- | --- | ---: | --- |
| summaryTest.tsv | SUCCESS | columns are TEST_NAME, MEASUREMENT_UNIT, n_records, n_subjects |  |  |
| summaryTest.tsv | SUCCESS | TEST_NAME has a value |  |  |
| summaryTest.tsv | SUCCESS | TEST_NAME + MEASUREMENT_UNIT are unique |  |  |
| summaryTest.tsv | SUCCESS | n_records is a whole number above 0 |  |  |
| summaryTest.tsv | SUCCESS | n_subjects is a whole number above 0 |  |  |
| summaryTest.tsv | SUCCESS | n_subjects is above 5 (small counts are removed) |  |  |
| summaryTest.tsv | SUCCESS | n_records is at least n_subjects |  |  |
| summaryUnitSource.tsv | SUCCESS | columns are TEST_NAME, MEASUREMENT_UNIT, unit_source, n_records, n_subjects |  |  |
| summaryUnitSource.tsv | SUCCESS | TEST_NAME has a value |  |  |
| summaryUnitSource.tsv | SUCCESS | TEST_NAME + MEASUREMENT_UNIT + unit_source are unique |  |  |
| summaryUnitSource.tsv | SUCCESS | n_records is a whole number above 0 |  |  |
| summaryUnitSource.tsv | SUCCESS | n_subjects is a whole number above 0 |  |  |
| summaryUnitSource.tsv | SUCCESS | n_subjects is above 5 (small counts are removed) |  |  |
| summaryUnitSource.tsv | SUCCESS | n_records is at least n_subjects |  |  |
| summaryUnitSource.tsv | SUCCESS | every TEST_NAME + MEASUREMENT_UNIT is in summaryTest.tsv |  |  |
| summaryUnitSource.tsv | SUCCESS | unit_source is one of Source, PrimaryInjection |  |  |
| summaryUnitSource.tsv | SUCCESS | the n_records of a pair add up to no more than its n_records in summaryTest.tsv |  |  |
| summaryValuesSource.tsv | SUCCESS | columns are TEST_NAME, MEASUREMENT_UNIT, value_source, n_records, n_subjects |  |  |
| summaryValuesSource.tsv | SUCCESS | TEST_NAME has a value |  |  |
| summaryValuesSource.tsv | SUCCESS | TEST_NAME + MEASUREMENT_UNIT + value_source are unique |  |  |
| summaryValuesSource.tsv | SUCCESS | n_records is a whole number above 0 |  |  |
| summaryValuesSource.tsv | SUCCESS | n_subjects is a whole number above 0 |  |  |
| summaryValuesSource.tsv | SUCCESS | n_subjects is above 5 (small counts are removed) |  |  |
| summaryValuesSource.tsv | SUCCESS | n_records is at least n_subjects |  |  |
| summaryValuesSource.tsv | SUCCESS | every TEST_NAME + MEASUREMENT_UNIT is in summaryTest.tsv |  |  |
| summaryValuesSource.tsv | SUCCESS | value_source is one of Source, Extracted, QCOut |  |  |
| summaryValuesSource.tsv | SUCCESS | the n_records of a pair add up to no more than its n_records in summaryTest.tsv |  |  |
| summaryValues.tsv | SUCCESS | columns are TEST_NAME, MEASUREMENT_UNIT, n_subjects, n_records, decile, decile_MEASUREMENT_VALUE |  |  |
| summaryValues.tsv | SUCCESS | TEST_NAME has a value |  |  |
| summaryValues.tsv | SUCCESS | TEST_NAME + MEASUREMENT_UNIT + decile are unique |  |  |
| summaryValues.tsv | SUCCESS | n_records is a whole number above 0 |  |  |
| summaryValues.tsv | SUCCESS | n_subjects is a whole number above 0 |  |  |
| summaryValues.tsv | SUCCESS | decile_MEASUREMENT_VALUE is a number |  |  |
| summaryValues.tsv | SUCCESS | n_subjects is above 5 (small counts are removed) |  |  |
| summaryValues.tsv | SUCCESS | n_records is at least n_subjects |  |  |
| summaryValues.tsv | SUCCESS | every TEST_NAME + MEASUREMENT_UNIT is in summaryTest.tsv |  |  |
| summaryValues.tsv | SUCCESS | decile is one of 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 |  |  |
| summaryValues.tsv | SUCCESS | every pair has the 9 deciles |  |  |
| summaryValues.tsv | SUCCESS | the deciles of a pair do not decrease |  |  |
| summaryReference.tsv | SUCCESS | columns are TEST_NAME, MEASUREMENT_UNIT, DEMOGRAPHICS_BIN, REFERENCE_RANGE_LOW_MEAN, REFERENCE_RANGE_HIGH_MEAN, n_records, n_subjects |  |  |
| summaryReference.tsv | SUCCESS | TEST_NAME has a value |  |  |
| summaryReference.tsv | SUCCESS | TEST_NAME + MEASUREMENT_UNIT + DEMOGRAPHICS_BIN are unique |  |  |
| summaryReference.tsv | SUCCESS | n_records is a whole number above 0 |  |  |
| summaryReference.tsv | SUCCESS | n_subjects is a whole number above 0 |  |  |
| summaryReference.tsv | SUCCESS | REFERENCE_RANGE_LOW_MEAN is a number |  |  |
| summaryReference.tsv | SUCCESS | REFERENCE_RANGE_HIGH_MEAN is a number |  |  |
| summaryReference.tsv | SUCCESS | n_subjects is above 5 (small counts are removed) |  |  |
| summaryReference.tsv | SUCCESS | n_records is at least n_subjects |  |  |
| summaryReference.tsv | SUCCESS | every TEST_NAME + MEASUREMENT_UNIT is in summaryTest.tsv |  |  |
| summaryReference.tsv | SUCCESS | DEMOGRAPHICS_BIN is one of Adult-Female, Adult-Male, Minor-Female, Minor-Male |  |  |
| summaryReference.tsv | WARNING | REFERENCE_RANGE_LOW_MEAN is not above REFERENCE_RANGE_HIGH_MEAN | 7 | e.g. TEST_NAME=p-d-25 MEASUREMENT_UNIT= DEMOGRAPHICS_BIN=Adult-Female REFERENCE_RANGE_LOW_MEAN=49.444444 REFERENCE_RANGE_HIGH_MEAN=21.333333; TEST_NAME=p-d-25 MEASUREMENT_UNIT= DEMOGRAPHICS_BIN=Adult-Male REFERENCE_RANGE_LOW_MEAN=48.985507 REFERENCE_RANGE_HIGH_MEAN=36.888889; TEST_NAME=p-kolesteroli,highdensitylipoproteiinit MEASUREMENT_UNIT=mmol/l DEMOGRAPHICS_BIN=Adult-Female REFERENCE_RANGE_LOW_MEAN=1.196983 REFERENCE_RANGE_HIGH_MEAN=0.0 |
| summaryOutcomes.tsv | SUCCESS | columns are TEST_NAME, MEASUREMENT_UNIT, TEST_OUTCOME, n_TEST_OUTCOME, n_subjects |  |  |
| summaryOutcomes.tsv | SUCCESS | TEST_NAME has a value |  |  |
| summaryOutcomes.tsv | SUCCESS | TEST_NAME + MEASUREMENT_UNIT + TEST_OUTCOME are unique |  |  |
| summaryOutcomes.tsv | SUCCESS | n_TEST_OUTCOME is a whole number above 0 |  |  |
| summaryOutcomes.tsv | SUCCESS | n_subjects is a whole number above 0 |  |  |
| summaryOutcomes.tsv | SUCCESS | n_subjects is above 5 (small counts are removed) |  |  |
| summaryOutcomes.tsv | SUCCESS | n_TEST_OUTCOME is at least n_subjects |  |  |
| summaryOutcomes.tsv | SUCCESS | every TEST_NAME + MEASUREMENT_UNIT is in summaryTest.tsv |  |  |
