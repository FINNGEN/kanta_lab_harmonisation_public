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

One row per source (`TEST_NAME`, `UNIT`) pair and the OMOP
measurement concept it maps to.

| Column             | Type    | Description                                        |
|--------------------|---------|----------------------------------------------------|
| `TEST_NAME`        | string  | Source lab test name. Required.                    |
| `UNIT` | string  | Source unit; `""` = qualitative test (no unit).    |
| `concept_id`       | integer | Target OMOP measurement `concept_id`. Required.    |

**Validations**

- `TEST_NAME` and `concept_id` cannot be empty.
- `TEST_NAME` + `UNIT` is unique.

### `UNITSfi.tsv` — source-unit dictionary

One row per distinct source measurement unit and its OMOP unit concept.

| Column             | Type    | Description                                           |
|--------------------|---------|-------------------------------------------------------|
| `UNIT`             | string  | Source unit code (e.g. `mmol/l`). Primary key.        |
| `concept_id`       | integer | OMOP unit `concept_id`. `0` marks an unmapped unit.   |
| `UNIQUE_FOR_LAB`   | boolean | `TRUE`/`FALSE` — whether the unit is unique per lab.  |

**Validations**

- No empty fields in any column.
- `UNIT` is unique.
- `UNIQUE_FOR_LAB` is strictly `TRUE` or `FALSE`.

### `conceptid_target_unit.tsv` — target unit per concept

The unit the values of an OMOP concept are converted to.

| Column        | Type    | Description                                         |
|---------------|---------|-----------------------------------------------------|
| `concept_id`  | integer | OMOP measurement `concept_id`. Primary key.         |
| `HARMONISED_UNIT` | string  | Unit the values of the concept are converted to.    |

### `unit_fix.tsv` — known unit corrections

Per test, a preprocessed unit known to be wrong and the unit it must be read as.

| Column               | Type   | Description                                        |
|----------------------|--------|----------------------------------------------------|
| `TEST_NAME`          | string | Source lab test name.                              |
| `PREPROCESED_UNIT`   | string | Unit as it arrives after preprocessing.            |
| `UNIT`               | string | Unit it is corrected to.                           |
| `unit_fix_reasoning` | string | Why the unit is fixed. Optional.                   |
| `INJECTION_NOTES`    | string | Review state of the unit injection (e.g. `VALID`). |

### `quantity_source_unit_conversion.tsv` — unit-conversion table

Per OMOP quantity, the allowed source units and how to convert between them.
`value_in_HARMONISED_UNIT = value_in_UNIT * CONVERSION`.

| Column                              | Type          | Description                                                        |
|-------------------------------------|---------------|--------------------------------------------------------------------|
| `has_property` | string        | OMOP quantity/property. Required.                                  |
| `UNIT`                  | string        | Source unit; `""` = no-unit (qualitative), a valid value.          |
| `HARMONISED_UNIT`               | string        | Target unit; `""` allowed as above.                                |
| `CONVERSION`                        | float\|formula| Multiplier (e.g. `1000`, `0.001`) **or** a formula in `X` (e.g. `0.703*X+0`). Required. |
| `ONLY_TO_OMOP_CONCEPTS`             | string        | Optional. Restricts the rule to specific OMOP concept id(s).       |
| `VALIDATION_MESSAGES`               | string        | Optional free-text notes.                                          |

**Validations**

- `has_property` and `CONVERSION` cannot be empty. Empty values are allowed only
  in `UNIT`, `HARMONISED_UNIT`, `ONLY_TO_OMOP_CONCEPTS`,
  `VALIDATION_MESSAGES`.
- `has_property` + `UNIT` + `HARMONISED_UNIT` is unique among
  **numeric** conversions. Formula rows are concept-specific overrides and may
  coexist with the plain identity row for the same triple, so they are excluded.
- **Reciprocity**: every numeric conversion `MU → TO_MU = c` (within the same
  `has_property`) must have the reverse row `HARMONISED_UNIT → UNIT` with the reciprocal
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
