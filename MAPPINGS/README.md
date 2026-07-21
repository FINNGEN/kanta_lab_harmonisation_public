# MAPPINGS

Minimal, reviewable reference tables that drive the Kanta lab harmonisation to
OMOP. Each table is a plain, hand-editable file; correctness is guarded by the
validation script in [`tests/tables_validation.py`](tests/tables_validation.py).

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

Run the validations:

```bash
python3 MAPPINGS/tests/tables_validation.py
```

Exit code `0` = all hard checks pass (warnings allowed), `1` = at least one hard
check failed. `[WARN]` findings are reported but never fail the run.

---

## Tables

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

### `LABfi.tsv` — lab test → OMOP mapping

One row per (test abbreviation, unit) mapping to an OMOP measurement concept.

| Column                              | Type    | Description                                              |
|-------------------------------------|---------|----------------------------------------------------------|
| `TEST_NAME_ABBREVIATION`            | string  | Source lab test abbreviation. Required.                  |
| `MEASUREMENT_UNIT`                  | string  | Source unit; `""` = qualitative test (no unit).          |
| `harmonization_omop::OMOP_ID`       | integer | Target OMOP measurement `concept_id`.                    |
| `harmonization_omop::OMOP_QUANTITY` | string  | OMOP quantity/property (e.g. `Mass Concentration`).      |
| `harmonization_omop::MAPPING_STATUS`| enum    | Review state: `APPROVED` or `UNCHECKED`.                 |

**Validations**

- `TEST_NAME_ABBREVIATION` cannot be empty.
- `MAPPING_STATUS` cannot be empty; only the values present in the file are
  allowed (`APPROVED`, `UNCHECKED`).
- `TEST_NAME_ABBREVIATION` + `MEASUREMENT_UNIT` is unique.
- A given `OMOP_ID` maps to exactly one `OMOP_QUANTITY` (no id with two
  different quantities).
- If `MAPPING_STATUS = APPROVED`, `OMOP_ID` cannot be empty or `0`.
- If `MAPPING_STATUS = APPROVED` and a unit is present, that unit must exist in
  `UNITSfi.tsv` (cross-table, below).

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

### `harmonization_counts.tsv` — observed-usage provenance

Per harmonised (concept, quantity, unit), the source of the unit decision and
before/after unit distributions.

| Column                              | Type    | Description                                                      |
|-------------------------------------|---------|------------------------------------------------------------------|
| `harmonization_omop::OMOP_ID`       | integer | OMOP measurement `concept_id`. Required.                         |
| `harmonization_omop::OMOP_QUANTITY` | string  | OMOP quantity. Required.                                         |
| `harmonization_omop::MEASUREMENT_UNIT` | string | Harmonised unit; `""` = no unit.                              |
| `UNIT_SOURCE`                       | enum    | How the unit was decided: `SOURCE`, `INJECTED`, `MANUAL`.        |
| `NOTES`                             | string  | Free-text.                                                       |
| `PREV_SOURCE`                       | dict    | `{unit: fraction}` distribution before injection.                |
| `PREV_INJECTED`                     | dict    | `{unit: fraction}` distribution after injection.                 |

**Validations**

- `OMOP_ID` and `OMOP_QUANTITY` cannot be empty.
- `OMOP_ID` + `OMOP_QUANTITY` is unique.
- `UNIT_SOURCE` only takes values present in the file (`SOURCE`, `INJECTED`,
  `MANUAL`).
- `PREV_SOURCE` and `PREV_INJECTED` parse as `{string: number}` dictionaries.

---

## Table relationships & cross-table validations

```
                 UNITSfi.tsv
              (unit dictionary)
                     ▲
                     │ APPROVED unit must be defined here
                     │
                 LABfi.tsv ──────────────► quantity_source_unit_conversion.tsv
           (test → OMOP mapping)   APPROVED (quantity,unit)   (per-quantity units
                     ▲              must be defined here        & conversions)
                     │
                     │ (soft) counts concept should map back
                     │
            harmonization_counts.tsv
                (usage provenance)
```

- **LABfi → UNITSfi** — every `APPROVED` `LABfi` row **with a unit** must use a
  `MEASUREMENT_UNIT` present in `UNITSfi.tsv`. Empty units (qualitative) are
  exempt; `UNCHECKED` rows are not checked.
- **LABfi → quantity table** — every `APPROVED` `LABfi`
  (`OMOP_QUANTITY`, `MEASUREMENT_UNIT`) pair with a unit must be defined in
  `quantity_source_unit_conversion.tsv`. The direction is one-way: `LABfi` must
  be covered by the conversion table, not the reverse (the conversion table may
  list units no approved test currently uses).
- **counts → LABfi** *(warning only)* — every counts
  (`OMOP_ID`, `OMOP_QUANTITY`, `MEASUREMENT_UNIT`) triple ideally exists in
  `LABfi.tsv`. This is a **`[WARN]`**, not a failure: `harmonization_counts.tsv`
  legitimately contains OMOP concepts that are not (yet) lab-mapped, e.g. rows
  whose `OMOP_QUANTITY` is `NA`.
