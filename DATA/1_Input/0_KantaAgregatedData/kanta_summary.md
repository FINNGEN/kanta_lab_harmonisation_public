**Table: summaryTest**

Summary for the kanta `TEST_NAME` + `PREPROCESED_UNIT` pairs

* `TEST_NAME`: Character,  lab test name
* `PREPROCESED_UNIT`: Character, lab test unit
* `n_records`: Integer, number of records for each `TEST_NAME` + `PREPROCESED_UNIT` pair
* `n_subjects`: Integer, number of patients for each `TEST_NAME` + `PREPROCESED_UNIT` pair (removed if <=5)


**Table: summaryValuesSource**

Source distrubution for the value for the `TEST_NAME` + `PREPROCESED_UNIT` pairs

* `TEST_NAME`: Character, lab test name
* `PREPROCESED_UNIT`: Character, lab test unit
* `unit_source`: label for the type of unit source
* `n_subjects`: Integer, number of subjects (removed if <=5)
* `n_records`: Integer, number of records


**Table: summaryUnitSource**

Source distributions for the units `TEST_NAME` + `PREPROCESED_UNIT` pairs

* `TEST_NAME`: Character, lab test name
* `PREPROCESED_UNIT`: Character, lab test unit
* `unit_source`: label for the type of unit source
* `n_subjects`: Integer, number of subjects (removed if <=5)
* `n_records`: Integer, number of records


**Table: summaryValues**

Value distributions for the `TEST_NAME` + `PREPROCESED_UNIT` pairs

* `TEST_NAME`: Character, lab test name
* `PREPROCESED_UNIT`: Character, lab test unit
* `n_subjects`: Integer, number of subjects (removed if <=5)
* `n_records`: Integer, number of records
* `decile`: Numeric, decile value
* `decile_MEASUREMENT_VALUE`: Numeric, decile of measurement value


**Table: summaryOutcomes**

Outcome distributions for the `TEST_NAME` + `PREPROCESED_UNIT` pairs

* `TEST_NAME`: Character, lab test name
* `PREPROCESED_UNIT`: Character, lab test unit
* `TEST_OUTCOME`: Character, test outcome
* `n_TEST_OUTCOME`: Integer, number of test outcomes
* `n_subjects`: Integer, number of subjects (removed if <=5)


**Note on `PREPROCESED_UNIT`**

The tables were collected on `TEST_NAME` + `UNIT` (the unit after the fix). In this repo the `PREPROCESED_UNIT` of every pair in `unit_fix.tsv` (`TEST_NAME` + `UNIT`) was put back, so the tables are keyed by `TEST_NAME` + `PREPROCESED_UNIT` as if collected on the preprocessed unit. A `UNIT` fixed from several `PREPROCESED_UNIT`s (du-alb, li-igg-ind, u-kemseul, u-ph-o) cannot be split and took the first one in `unit_fix.tsv`. The values are in the unit after the fix.
