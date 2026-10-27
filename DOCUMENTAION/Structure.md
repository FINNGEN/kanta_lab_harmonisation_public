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
| **MEASUREMENT_UNIT** | Character | Lab test unit |
| **VALUE** | Numeric | Measurement value |
| ... | | Other columns |

---

## Kanta summary tables

`summarizePreprocessKantaData` turns the Preprocess Kanta Data into 5 summary tables, written to `DATA_SUMMARY/0_KantaSummaryTables/`. Each is keyed by the **TEST_NAME** + **MEASUREMENT_UNIT** pair. Subject counts of 5 or fewer are removed.

**summaryTest** — one row per pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **MEASUREMENT_UNIT** | Character | Lab test unit |
| n_records | Integer | Number of records for the pair |
| n_subjects | Integer | Number of patients for the pair (removed if <=5) |

**summaryValuesSource** — source distribution of the value for each pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **MEASUREMENT_UNIT** | Character | Lab test unit |
| value_source | Character | Label for the type of value source (`Source`, `Extracted`, `QCOut`) |
| n_subjects | Integer | Number of subjects (removed if <=5) |
| n_records | Integer | Number of records |

**summaryUnitSource** — source distribution of the unit for each pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **MEASUREMENT_UNIT** | Character | Lab test unit |
| unit_source | Character | Label for the type of unit source |
| n_subjects | Integer | Number of subjects (removed if <=5) |
| n_records | Integer | Number of records |

**summaryValues** — value distribution for each pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **MEASUREMENT_UNIT** | Character | Lab test unit |
| n_subjects | Integer | Number of subjects (removed if <=5) |
| n_records | Integer | Number of records |
| decile | Numeric | Decile (0.1 to 0.9) |
| **decile_MEASUREMENT_VALUE** | Numeric | **Value** at that decile |

**summaryOutcomes** — outcome distribution for each pair.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Lab test name |
| **MEASUREMENT_UNIT** | Character | Lab test unit |
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

The tables in `DATA_MAPPINGS/0_MappingTables/`, edited by hand. Their columns are described in full in that folder's `README.md`.

**testname_unit_to_conceptid.tsv** — one row per source lab test and unit, mapped to its OMOP concept.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME** | Character | Source lab test name |
| **MEASUREMENT_UNIT** | Character | Source unit (empty for qualitative tests) |
| OMOP_ID | Integer | Target OMOP measurement `concept_id` |

**unit_fix.tsv** — known unit errors and what they must be read as.

| Column | Type | Description |
|---|---|---|
| **TEST_NAME_ABBREVIATION** | Character | Source lab test name |
| source_unit_clean | Character | Unit as it arrives after cleaning |
| source_unit_clean_fix | Character | Unit it is corrected to |
| notes | Character | Free-text notes |
| INJECTION_NOTES | Character | Review state of the unit injection (e.g. `VALID`) |

**quantity_source_unit_conversion.tsv** — per OMOP quantity, how to convert one unit to another.

| Column | Type | Description |
|---|---|---|
| harmonization_omop::OMOP_QUANTITY | Character | OMOP quantity, e.g. `Mass Concentration` |
| **MEASUREMENT_UNIT** | Character | Source unit |
| TO_MEASUREMENT_UNIT | Character | Unit the value is converted to |
| CONVERSION | Numeric or formula | Factor, or a formula in `X`, so that `value_in_TO_MEASUREMENT_UNIT = value_in_MEASUREMENT_UNIT * CONVERSION` |
| ONLY_TO_OMOP_CONCEPTS | Character | Optional, restricts the rule to specific OMOP concept ids |
| VALIDATION_MESSAGES | Character | Optional free-text notes |

**UNITSfi.tsv** — dictionary of source units, kept as is.

| Column | Type | Description |
|---|---|---|
| **MEASUREMENT_UNIT** | Character | Source unit code |
| OMOP_ID | Integer | OMOP unit `concept_id` (`0` for an unmapped unit) |
| UNIQUE_FOR_LAB | Logical | Whether the unit is unique per lab |

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

**loinc_group_membership.tsv** — one row per concept and LOINC Group it belongs to (many-to-many).

| Column | Type | Description |
|---|---|---|
| concept_id | Integer | OMOP concept id, joins to `measurement_concept_attributes.tsv` |
| group_concept_id | Integer | OMOP concept id of the LOINC Group |
| group_concept_code | Character | The `LG...` code of the Group |
| group_concept_name | Character | Name of the Group |
| n_descendants | Integer | How many standard `Measurement` concepts the Group holds |
| is_parent_group | Logical | `TRUE` if the Group subsumes other Groups |

---

## Harmonization table

`harmonizationTable.tsv`: built by `buildHarmonizationTable` from the 5 tables in the box above. One row per source **TEST_NAME** + **UNIT** pair, resolved all the way to its OMOP concept, target unit and conversion, so the harmonize scripts only have to join it. The columns below are the proposed design.

| Column | Type | Description | Comes from |
|---|---|---|---|
| **TEST_NAME** | Character | Source lab test name (join key) | `testname_unit_to_conceptid.tsv` |
| **UNIT** | Character | Source unit (join key). Empty for qualitative tests | `testname_unit_to_conceptid.tsv` |
| UNIT_FIXED | Character | Source unit after correcting known unit errors | `unit_fix.tsv` |
| OMOP_ID | Integer | Target OMOP measurement `concept_id` | `testname_unit_to_conceptid.tsv` |
| OMOP_NAME | Character | OMOP `concept_name` for `OMOP_ID` | `measurement_concept_attributes.tsv` |
| OMOP_QUANTITY | Character | OMOP quantity (`has_property`), e.g. `Mass Concentration` | `measurement_concept_attributes.tsv` |
| LOINC_GROUP | Character | LOINC group the concept belongs to | `loinc_group_membership.tsv` |
| TO_UNIT | Character | Unit the value is converted to | `quantity_source_unit_conversion.tsv` |
| CONVERSION | Numeric | Factor so that `value_in_TO_UNIT = value_in_UNIT * CONVERSION` | `quantity_source_unit_conversion.tsv` |

How the 5 tables combine:

1. `testname_unit_to_conceptid.tsv` is the base: it gives each `TEST_NAME` + `UNIT` pair its `OMOP_ID`.
2. `unit_fix.tsv` is joined on `TEST_NAME` + `UNIT` to add `UNIT_FIXED`, so a misspelled or mislabeled unit resolves to the right one.
3. `measurement_concept_attributes.tsv` is joined on `OMOP_ID` to add the OMOP name and quantity.
4. `loinc_group_membership.tsv` is joined on `OMOP_ID` to add the LOINC group.
5. `quantity_source_unit_conversion.tsv` is joined on `OMOP_QUANTITY` + `UNIT_FIXED` to add the target unit and the conversion factor.

---

## Harmonized Kanta data

`HarmonizedKantaData`, produced by `harmonize` and sent to the sandbox. It is `PreprocessKantaData` left-joined to `harmonizationTable.tsv` on **TEST_NAME** + **UNIT**.

| Column | Type | Description |
|---|---|---|
| All columns of `PreprocessKantaData` |  | Including **TEST_NAME**, **MEASUREMENT_UNIT** and **VALUE** |
| All columns of the harmonization table |  | `UNIT_FIXED`, `OMOP_ID`, `OMOP_NAME`, `OMOP_QUANTITY`, `LOINC_GROUP`, `TO_UNIT`, `CONVERSION` |
| **VALUE_HARMONIZED** | Numeric | The raw **value** times `CONVERSION`, in `TO_UNIT` |

---

## Harmonized summary data

`HarmonisedSummaryData`, produced by `harmonize` and sent to the Github-Page and to Risteys. It is `KantaSummaryData` left-joined to `harmonizationTable.tsv` on **TEST_NAME** + **UNIT**.

| Column | Type | Description |
|---|---|---|
| All columns of `KantaSummaryData` |  | Including **TEST_NAME**, **UNIT** and **decile_value** |
| All columns of the harmonization table |  | `UNIT_FIXED`, `OMOP_ID`, `OMOP_NAME`, `OMOP_QUANTITY`, `LOINC_GROUP`, `TO_UNIT`, `CONVERSION` |
| **decile_value_harmonized** | Numeric | `decile_value` times `CONVERSION`, in `TO_UNIT` |
