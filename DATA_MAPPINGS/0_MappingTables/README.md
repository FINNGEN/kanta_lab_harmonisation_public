# MAPPINGS

Minimal, reviewable reference tables that drive the Kanta lab harmonisation to
OMOP. Each table is a plain, hand-editable file.

## File conventions

- **Format** — every table is **TSV** (tab-separated, UTF-8). Tabs separate
  fields; there is exactly one header row.
- **NA / missing** — encoded as the **empty string `""`** (an empty field).
- **Column-name format** — two styles are used:
  - `harmonization_omop::<Name>` — fields that carry the OMOP harmonisation
    result (the concept id, its quantity, the mapping status). The
    `harmonization_omop::` namespace marks columns consumed/produced by the
    harmonisation step.
  - `UPPER_SNAKE_CASE` — all other columns (source units, abbreviations, flags,
    provenance).
- **Booleans** — literal `TRUE` / `FALSE`.

---

## Tables

### `testname_unit_to_conceptid.tsv` — lab test → OMOP concept

One row per source (`TEST_NAME`, `MEASUREMENT_UNIT`) pair and the OMOP
measurement concept it maps to.

| Column             | Type    | Description                                        |
|--------------------|---------|----------------------------------------------------|
| `TEST_NAME`        | string  | Source lab test name. Required.                    |
| `MEASUREMENT_UNIT` | string  | Source unit; `""` = qualitative test (no unit).    |
| `OMOP_ID`          | integer | Target OMOP measurement `concept_id`. Required.    |

**Validations**

- `TEST_NAME` and `OMOP_ID` cannot be empty.
- `TEST_NAME` + `MEASUREMENT_UNIT` is unique.

### `UNITSfi.tsv` — source-unit dictionary

One row per distinct source measurement unit and its OMOP unit concept.

| Column             | Type    | Description                                           |
|--------------------|---------|-------------------------------------------------------|
| `MEASUREMENT_UNIT` | string  | Source unit code (e.g. `mmol/l`). Primary key.        |
| `OMOP_ID`          | integer | OMOP unit `concept_id`. `0` marks an unmapped unit.   |
| `UNIQUE_FOR_LAB`   | boolean | `TRUE`/`FALSE` — whether the unit is unique per lab.  |

**Validations**

- No empty fields in any column.
- `MEASUREMENT_UNIT` is unique.
- `UNIQUE_FOR_LAB` is strictly `TRUE` or `FALSE`.

### `conceptid_target_unit.tsv` — target unit per concept

The unit the values of an OMOP concept are converted to.

| Column        | Type    | Description                                         |
|---------------|---------|-----------------------------------------------------|
| `OMOP_ID`     | integer | OMOP measurement `concept_id`. Primary key.         |
| `TARGET_UNIT` | string  | Unit the values of the concept are converted to.    |

### `unit_fix.tsv` — known unit corrections

Per test, a source unit known to be wrong and the unit it must be read as.

| Column                   | Type   | Description                                       |
|--------------------------|--------|---------------------------------------------------|
| `TEST_NAME_ABBREVIATION` | string | Source lab test abbreviation.                     |
| `source_unit_clean`      | string | Unit as it arrives after cleaning.                |
| `source_unit_clean_fix`  | string | Unit it is corrected to.                          |
| `notes`                  | string | Optional free-text.                               |
| `INJECTION_NOTES`        | string | Review state of the unit injection (e.g. `VALID`).|

### `quantity_source_unit_conversion.tsv` — unit-conversion table

Per OMOP quantity, the allowed source units and how to convert between them.
`value_in_TO_UNIT = value_in_MEASUREMENT_UNIT * CONVERSION`.

| Column                              | Type          | Description                                                        |
|-------------------------------------|---------------|--------------------------------------------------------------------|
| `harmonization_omop::OMOP_QUANTITY` | string        | OMOP quantity/property. Required.                                  |
| `MEASUREMENT_UNIT`                  | string        | Source unit; `""` = no-unit (qualitative), a valid value.          |
| `TO_MEASUREMENT_UNIT`               | string        | Target unit; `""` allowed as above.                                |
| `CONVERSION`                        | float\|formula| Multiplier (e.g. `1000`, `0.001`) **or** a formula in `X` (e.g. `0.703*X+0`). Required. |
| `ONLY_TO_OMOP_CONCEPTS`             | string        | Optional. Restricts the rule to specific OMOP concept id(s).       |
| `VALIDATION_MESSAGES`               | string        | Optional free-text notes.                                          |

**Validations**

- `OMOP_QUANTITY` and `CONVERSION` cannot be empty. Empty values are allowed only
  in `MEASUREMENT_UNIT`, `TO_MEASUREMENT_UNIT`, `ONLY_TO_OMOP_CONCEPTS`,
  `VALIDATION_MESSAGES`.
- `OMOP_QUANTITY` + `MEASUREMENT_UNIT` + `TO_MEASUREMENT_UNIT` is unique among
  **numeric** conversions. Formula rows are concept-specific overrides and may
  coexist with the plain identity row for the same triple, so they are excluded.
- **Reciprocity**: every numeric conversion `MU → TO_MU = c` (within the same
  `OMOP_QUANTITY`) must have the reverse row `TO_MU → MU` with the reciprocal
  value (`c * reverse ≈ 1`). Formula conversions are exempt.

---

## Table relationships

- **testname_unit_to_conceptid → UNITSfi** — a mapped unit should be defined in
  `UNITSfi.tsv`. Empty units (qualitative) are exempt.
- **unit_fix** — applied to the source unit before it is looked up in
  `quantity_source_unit_conversion.tsv`.
- **testname_unit_to_conceptid → quantity table** — the OMOP quantity of a
  mapped concept and its (fixed) unit should be defined in
  `quantity_source_unit_conversion.tsv`.
