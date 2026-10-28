# Kanta Lab Harmonisation Structure

The aim is to build one harmonization table and apply it to both the Preprocess Kanta Data and the Kanta summary data, so the harmonization logic lives in a single place. The harmonization script is deliberately simple: it only joins the harmonization table to either the Preprocess Kanta Data or the Kanta summary data (it runs once on each, hence the two boxes below). The harmonization table is built by combining 5 different tables into one, so everything is already resolved in it and the script has nothing left to decide. The Preprocess Kanta Data is the Kanta data after the preprocessing steps, ending with the Primary Injection step. The Kanta summary data is a count of the distinct rows: `summarizePreprocessKantaData` produces 5 summary tables, which are later combined, outside the sandbox, into one Kanta summary data. The harmonized Kanta data goes to the sandbox, and the harmonized summary data goes to the Github-Page and to Risteys.

```mermaid
flowchart LR
    %% Data = rectangles, Scripts = hexagons, Databases = cylinders, Destinations = stadium
    RAW["PreprocessKantaData"]:::data
    SUM{{"summarizePreprocessKantaData"}}:::script

    SRC["<b>Kanta Summary Tables</b><br/>• summaryTest.tsv<br/>• summaryValues.tsv<br/>• summaryValuesSource.tsv<br/>• summaryUnitSource.tsv<br/>• summaryOutcomes.tsv"]:::data

    GSD{{"buildKantaSummaryData"}}:::script
    SUMDATA["KantaSummaryData"]:::data

    subgraph MAP["Build Harmonization Table"]
        M1["quantity_source_unit_conversion.tsv"]:::data
        M2["testname_unit_to_conceptid.tsv"]:::data
        M4["conceptid_target_unit.tsv"]:::data
        M5["unit_fix.tsv"]:::data
        OMOPDB[("OMOP CDM database")]:::db
        GETOMOP{{"GetMeasurementOmopData"}}:::script
        M6["measurement_concept_attributes.tsv"]:::data
        M7["loinc_group_membership.tsv"]:::data
        COMB{{"buildHarmonizationTable"}}:::script
        HTAB["harmonizationTable.tsv"]:::data
    end

    HARMRAW{{"harmonize"}}:::script
    HARMSUM{{"harmonize"}}:::script
    HKANTA["HarmonizedKantaData"]:::data
    HSUM["HarmonisedSummaryData"]:::data
    SANDBOX(["Sandbox"]):::dest
    GHP(["Github-Page"]):::dest
    RIS(["Risteys"]):::dest

    RAW --> HARMRAW
    RAW --> SUM --> SRC
    SRC --> GSD --> SUMDATA
    M1 --> COMB
    M2 --> COMB
    M4 --> COMB
    M5 --> COMB
    OMOPDB --> GETOMOP
    GETOMOP --> M6
    GETOMOP --> M7
    M6 --> COMB
    M7 --> COMB
    COMB --> HTAB
    HTAB --> HARMRAW
    SUMDATA --> HARMSUM
    HTAB --> HARMSUM
    HARMSUM --> HSUM
    HSUM --> GHP
    HSUM --> RIS
    HARMRAW --> HKANTA --> SANDBOX
    

    classDef data fill:#e8f1fb,stroke:#2b6cb0,stroke-width:1.5px,color:#111;
    classDef script fill:#fff3d6,stroke:#b7791f,stroke-width:1.5px,color:#111;
    classDef db fill:#f3e8fb,stroke:#6b46c1,stroke-width:1.5px,color:#111;
    classDef dest fill:#e6f4ea,stroke:#2f855a,stroke-width:1.5px,color:#111;
```

---

## Preprocess Kanta Data

`PreprocessKantaData`: the lab measurement records after preprocessing, one row per record. It comes after the Primary Injection step (clean and rename columns, free-text extraction, regex cleanup, unit validation, then Primary Injection, a statistical guess of missing units), so it is the output of that step. Only the columns the pipeline needs are described here.

| Column | Type | Description |
|---|---|---|
| FINNGENID | Character | Subject identifier |
| SEX | Character | Subject sex |
| DATE | Date | Date of the measurement |
| **TEST_NAME** | Character | Lab test name |
| **PREPROCESED_UNIT** | Character | Lab test unit |
| **VALUE** | Numeric | Measurement value |
| ... | | Other columns |

---

## Kanta summary tables

`summarizePreprocessKantaData` turns the Preprocess Kanta Data into 5 summary tables, written to `DATA_SUMMARY/0_KantaSummaryTables/`. Each is keyed by the **TEST_NAME** + **PREPROCESED_UNIT** pair. Subject counts of 5 or fewer are removed.

**summaryTest** — one row per pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **PREPROCESED_UNIT** | Character | Lab test unit |
| n_records | Integer | Number of records for the pair |
| n_subjects | Integer | Number of patients for the pair (removed if <=5) |

**summaryValuesSource** — source distribution of the value for each pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **PREPROCESED_UNIT** | Character | Lab test unit |
| value_source | Character | Label for the type of value source (`Source`, `Extracted`, `QCOut`) |
| n_subjects | Integer | Number of subjects (removed if <=5) |
| n_records | Integer | Number of records |

**summaryUnitSource** — source distribution of the unit for each pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **PREPROCESED_UNIT** | Character | Lab test unit |
| unit_source | Character | Label for the type of unit source |
| n_subjects | Integer | Number of subjects (removed if <=5) |
| n_records | Integer | Number of records |

**summaryValues** — value distribution for each pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **PREPROCESED_UNIT** | Character | Lab test unit |
| n_subjects | Integer | Number of subjects (removed if <=5) |
| n_records | Integer | Number of records |
| decile | Numeric | Decile (0.1 to 0.9) |
| **decile_MEASUREMENT_VALUE** | Numeric | **Value** at that decile |

**summaryOutcomes** — outcome distribution for each pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **PREPROCESED_UNIT** | Character | Lab test unit |
| TEST_OUTCOME | Character | Test outcome |
| n_TEST_OUTCOME | Integer | Number of test outcomes |
| n_subjects | Integer | Number of subjects (removed if <=5) |

---

## Kanta summary data

`KantaSummaryData`: the 5 summary tables combined by `buildKantaSummaryData` into one table, one row per **TEST_NAME** + **UNIT** pair and decile. It is the long form of `DATA_SUMMARY/1_BuildKantaSummaryData/kantaSummaryData.tsv`: instead of packing all the deciles into one `value_deciles` string, each decile gets its own row.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **UNIT** | Character | Lab test unit (empty when no unit is recorded) |
| n | Integer | Number of records for the pair (repeated on every decile row) |
| unit_source_injection_correction_na_p | Character | `[source%,injection%,correction%,na%]`, the percent of the pair's records whose unit comes from the `Source`, `PrimaryInjection`, `SecondaryCorrection`, or is missing |
| value_missing_p | Numeric | Percent of the pair's records with no value |
| value_source_extracted_qcout_na_p | Character | `[source%,extracted%,qcout%,na%]`, the percent of the pair's records whose value is `Source`, `Extracted`, `QCOut`, or missing |
| decile | Numeric | Which decile the row holds (0.1 to 0.9) |
| **decile_value** | Numeric | The measurement **value** at that decile. Empty for pairs with no deciles (low volume or no values) |

---

## Mapping tables

The tables in `DATA_MAPPINGS/0_MappingTables/`, edited by hand. Every table is a TSV (tab-separated, UTF-8, one header row), and a missing value is the empty string.

Each table, the OMOP tables and the output are checked by the step `1_BuildHarmonizationTable`, which writes `DATA_MAPPINGS/1_BuildHarmonizationTable/harmonizationTableValidation.md`: a summary of SUCCESS, WARNING and ERROR per table, then one row per test. Every table also gets the test that its columns match the declared types. A failed test does not stop the step. A *valid unit* is a unit in `UNITSfi.tsv`, or an empty one (a qualitative test) where the rules below say so.

**testname_unit_to_conceptid.tsv** — one row per source lab test and unit, mapped to its OMOP concept.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Source lab test name |
| **UNIT** | Character | Source unit (empty for qualitative tests) |
| concept_id | Integer | Target OMOP measurement `concept_id`. `0` (no concept) only with an `ignoreReason` |
| ignoreReason | Character | Why the test is not mapped, e.g. `Diagnostic procedure, not lab test` |

**Validations**

- `TEST_NAME` and `concept_id` have a value.
- `concept_id` is not `0`, unless the row has an `ignoreReason`.
- `UNIT` is a valid unit (or empty).
- `TEST_NAME` + `UNIT` are unique.
- `concept_id` is in `measurement_concept_attributes.tsv`, unless the row has an `ignoreReason`.

**conceptid_target_unit.tsv** — the unit each OMOP concept is converted to.

| Column | Type | Description |
|---|---|---|
| concept_id | Integer | Target OMOP measurement `concept_id` |
| HARMONISED_UNIT | Character | Unit the values of the concept are converted to. Never empty |

**Validations**

- `concept_id` and `HARMONISED_UNIT` have a value (no empty units).
- `HARMONISED_UNIT` is a valid unit in `UNITSfi.tsv`, never empty.
- `concept_id` is unique.
- `concept_id` is in `measurement_concept_attributes.tsv`.

**unit_fix.tsv** — known unit errors and what they must be read as.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Source lab test name |
| PREPROCESED_UNIT | Character | Unit as it arrives after preprocessing |
| **UNIT** | Character | Unit it is corrected to |
| unit_fix_reasoning | Character | Why the unit is fixed |
| INJECTION_NOTES | Character | Review state of the unit injection (e.g. `VALID`) |

**Validations**

- `TEST_NAME` has a value.
- `UNIT` is a valid unit (or empty).
- `TEST_NAME` + `PREPROCESED_UNIT` are unique.
- WARNING: `TEST_NAME` + `UNIT` is in `testname_unit_to_conceptid.tsv`. A fix for a pair that is not there is not an error, it is only never used downstream.

**quantity_source_unit_conversion.tsv** — per OMOP quantity, how to convert one unit to another.

| Column | Type | Description |
|---|---|---|
| has_property | Character | OMOP quantity, e.g. `Mass Concentration` |
| **UNIT** | Character | Source unit |
| HARMONISED_UNIT | Character | Unit the value is converted to |
| CONVERSION | Numeric or formula | Factor, or a formula in `X`, so that `value_in_HARMONISED_UNIT = value_in_UNIT * CONVERSION` |
| ONLY_TO_OMOP_CONCEPTS | Character | Optional, restricts the rule to specific OMOP concept ids |
| VALIDATION_MESSAGES | Character | Optional free-text notes |

**Validations**

- `has_property`, `UNIT`, `HARMONISED_UNIT` and `CONVERSION` have a value. Only `ONLY_TO_OMOP_CONCEPTS` and `VALIDATION_MESSAGES` can be empty.
- `UNIT` and `HARMONISED_UNIT` are valid units in `UNITSfi.tsv`, never empty.
- `has_property` + `UNIT` + `HARMONISED_UNIT` + `ONLY_TO_OMOP_CONCEPTS` are unique.
- `CONVERSION` is a number or a formula in `X`.
- `has_property` is a `has_property` of `measurement_concept_attributes.tsv`.
- `ONLY_TO_OMOP_CONCEPTS` are concept ids in `measurement_concept_attributes.tsv`.

**UNITSfi.tsv** — dictionary of source units, kept as is.

| Column | Type | Description |
|---|---|---|
| **UNIT** | Character | Source unit code |
| concept_id | Integer | OMOP unit `concept_id` (`0` for an unmapped unit) |
| UNIQUE_FOR_LAB | Logical | Whether the unit is unique per lab |

**Validations**

- `UNIT`, `concept_id` and `UNIQUE_FOR_LAB` have a value.
- `UNIT` is unique.

---

## OMOP tables

Written by `GetMeasurementOmopData` to `DATA_MAPPINGS/0_GetMeasurementOmopData/`, pulled from the OMOP CDM.

**measurement_concept_attributes.tsv** — one row per standard `Measurement` concept.

| Column | Type | Description |
|---|---|---|
| concept_id | Integer | OMOP concept id |
| concept_code | Character | Concept code in its vocabulary |
| concept_name | Character | Concept name |
| vocabulary_id | Character | Vocabulary of the concept |
| is_panel | Logical | `TRUE` if the concept bundles several component tests |
| has_component | Character | Analyte measured |
| has_property | Character | Kind of quantity reported, e.g. Mass Concentration |
| has_method | Character | Analytical method |
| has_scale_type | Character | Result scale (`Qn`, `Ord`, `Nom`, `Nar`, `Doc`) |
| has_system | Character | Specimen or body system |
| has_time_aspect | Character | Timing of the collection |

**Validations**

- `concept_id`, `concept_code`, `concept_name`, `vocabulary_id` and `is_panel` have a value.
- `concept_id` is unique.

**loinc_group_membership.tsv** — one row per concept and LOINC Group it belongs to (many-to-many).

| Column | Type | Description |
|---|---|---|
| concept_id | Integer | OMOP concept id, joins to `measurement_concept_attributes.tsv` |
| group_concept_id | Integer | OMOP concept id of the LOINC Group |
| group_concept_code | Character | The `LG...` code of the Group |
| group_concept_name | Character | Name of the Group |
| n_descendants | Integer | How many standard `Measurement` concepts the Group holds |
| is_parent_group | Logical | `TRUE` if the Group subsumes other Groups |

**Validations**

- `concept_id`, `group_concept_id`, `group_concept_code` and `group_concept_name` have a value.
- `concept_id` + `group_concept_id` are unique. A concept belongs to several Groups, so `concept_id` alone repeats.
- `concept_id` is in `measurement_concept_attributes.tsv`.

---

## Harmonization table

`harmonizationTable.tsv`: built by the step `1_BuildHarmonizationTable` (`buildHarmonizationTable` in the diagram) from the 5 tables in the box above, into `DATA_MAPPINGS/1_BuildHarmonizationTable/`. One row per source **TEST_NAME** + **PREPROCESED_UNIT** + **UNIT** (several rows when the concept has several LOINC Groups), resolved all the way to its OMOP concept, target unit and conversion, so the harmonize scripts only have to join it.

| Column | Type | Description | Comes from |
|---|---|---|---|
| **TEST_NAME** | Character | Source lab test name (join key) | `testname_unit_to_conceptid.tsv` |
| PREPROCESED_UNIT | Character | Unit as it arrives after preprocessing. The `UNIT` when the pair is not in `unit_fix.tsv` | `unit_fix.tsv` |
| **UNIT** | Character | Unit after the fix (join key). Empty for qualitative tests | `testname_unit_to_conceptid.tsv` |
| unit_fix_reasoning | Character | Why the unit was fixed | `unit_fix.tsv` |
| concept_id | Integer | Target OMOP measurement `concept_id` | `testname_unit_to_conceptid.tsv` |
| ignoreReason | Character | Why the test is not mapped | `testname_unit_to_conceptid.tsv` |
| concept_code, concept_name, vocabulary_id, is_panel |  | The concept itself | `measurement_concept_attributes.tsv` |
| has_component, has_property, has_method, has_scale_type, has_system, has_time_aspect | Character | The 6 LOINC axes | `measurement_concept_attributes.tsv` |
| group_concept_id, group_concept_code, group_concept_name |  | LOINC Group the concept belongs to | `loinc_group_membership.tsv` |
| HARMONISED_UNIT | Character | Unit the value is converted to | `conceptid_target_unit.tsv` |
| CONVERSION | Character | Factor, or a formula in `X`, so that `value_in_HARMONISED_UNIT = value_in_UNIT * CONVERSION` | `quantity_source_unit_conversion.tsv` |

**Validations**

- `TEST_NAME` + `PREPROCESED_UNIT` are unique.
- Every `TEST_NAME` + `UNIT` of `testname_unit_to_conceptid.tsv` is kept.
- `concept_id` has its attributes in `measurement_concept_attributes.tsv`, unless the row has an `ignoreReason`.
- A row with a `HARMONISED_UNIT` has a `CONVERSION`.

How the 5 tables combine:

1. `testname_unit_to_conceptid.tsv` is the base, with `unit_fix.tsv` put in front of it, joined on `TEST_NAME` + `UNIT`. A pair that is not in `unit_fix.tsv` copies its `UNIT` into `PREPROCESED_UNIT`.
2. `measurement_concept_attributes.tsv` is joined on `concept_id`.
3. `loinc_group_membership.tsv` is joined on `concept_id`, keeping only `group_concept_id`, `group_concept_code` and `group_concept_name`.
4. `conceptid_target_unit.tsv` is joined on `concept_id` to add `HARMONISED_UNIT`.
5. `quantity_source_unit_conversion.tsv` is joined on `has_property` + `UNIT` + `HARMONISED_UNIT` to add only `CONVERSION`. A rule with an empty `ONLY_TO_OMOP_CONCEPTS` applies to any concept; a rule with concept ids applies only to those.

---

## Harmonized Kanta data

`HarmonizedKantaData`, produced by `harmonize` and sent to the sandbox. It is `PreprocessKantaData` left-joined to `harmonizationTable.tsv` on **TEST_NAME** + **PREPROCESED_UNIT**.

| Column | Type | Description |
|---|---|---|
| All columns of `PreprocessKantaData` |  | Including **TEST_NAME**, **PREPROCESED_UNIT** and **VALUE** |
| All columns of the harmonization table |  | `PREPROCESED_UNIT`, `unit_fix_reasoning`, `concept_id`, the concept attributes, the LOINC Group, `HARMONISED_UNIT`, `CONVERSION` |
| **VALUE_HARMONIZED** | Numeric | The raw **value** times `CONVERSION`, in `HARMONISED_UNIT` |

---

## Harmonized summary data

`HarmonisedSummaryData`, produced by `harmonize` and sent to the Github-Page and to Risteys. It is `KantaSummaryData` left-joined to `harmonizationTable.tsv` on **TEST_NAME** + the unit (**UNIT** in the summary data, **PREPROCESED_UNIT** in the harmonization table).

| Column | Type | Description |
|---|---|---|
| All columns of `KantaSummaryData` |  | Including **TEST_NAME**, **UNIT** and **decile_value** |
| All columns of the harmonization table |  | `PREPROCESED_UNIT`, `unit_fix_reasoning`, `concept_id`, the concept attributes, the LOINC Group, `HARMONISED_UNIT`, `CONVERSION` |
| **decile_value_harmonized** | Numeric | `decile_value` times `CONVERSION`, in `HARMONISED_UNIT` |
