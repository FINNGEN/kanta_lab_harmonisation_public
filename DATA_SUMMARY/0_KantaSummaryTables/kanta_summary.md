**Table: summaryTest**

Summary for the kanta `TEST_NAME` + `MEASUREMENT_UNIT` pairs

* `TEST_NAME`: Character,  lab test name
* `MEASUREMENT_UNIT`: Character, lab test unit
* `n_records`: Integer, number of records for each `TEST_NAME` + `MEASUREMENT_UNIT` pair
* `n_subjects`: Integer, number of patients for each `TEST_NAME` + `MEASUREMENT_UNIT` pair (removed if <=5)


**Table: summaryValuesSource**

Source distrubution for the value for the `TEST_NAME` + `MEASUREMENT_UNIT` pairs

* `TEST_NAME`: Character, lab test name
* `MEASUREMENT_UNIT`: Character, lab test unit
* `unit_source`: label for the type of unit source
* `n_subjects`: Integer, number of subjects (removed if <=5)
* `n_records`: Integer, number of records


**Table: summaryUnitSource**

Source distributions for the units `TEST_NAME` + `MEASUREMENT_UNIT` pairs

* `TEST_NAME`: Character, lab test name
* `MEASUREMENT_UNIT`: Character, lab test unit
* `unit_source`: label for the type of unit source
* `n_subjects`: Integer, number of subjects (removed if <=5)
* `n_records`: Integer, number of records


**Table: summaryValues**

Value distributions for the `TEST_NAME` + `MEASUREMENT_UNIT` pairs

* `TEST_NAME`: Character, lab test name
* `MEASUREMENT_UNIT`: Character, lab test unit
* `n_subjects`: Integer, number of subjects (removed if <=5)
* `n_records`: Integer, number of records
* `decile`: Numeric, decile value
* `decile_MEASUREMENT_VALUE`: Numeric, decile of measurement value


**Table: summaryOutcomes**

Outcome distributions for the `TEST_NAME` + `MEASUREMENT_UNIT` pairs

* `TEST_NAME`: Character, lab test name
* `MEASUREMENT_UNIT`: Character, lab test unit
* `TEST_OUTCOME`: Character, test outcome
* `n_TEST_OUTCOME`: Integer, number of test outcomes
* `n_subjects`: Integer, number of subjects (removed if <=5)
