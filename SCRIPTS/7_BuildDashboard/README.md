# 6_BuildDashboard

Builds a self-contained HTML dashboard of the evaluated harmonised summary data: an
overview of the mapping status and of how the values compare with their LOINC Group, and
an interactive table with one row per pair.

## Inputs

- `DATA/4_BuildHarmonisationTable/testname_unit_property_missmatch_warning.tsv`,
  `testname_property_shared_warning.tsv`, `test_unit_context_unit_missing_warning.tsv` and
  `test_unit_loinc_group_unit_mismatch_warning.tsv` — to tell the warnings that are marked `ignore`.
- `DATA/2_Harmonisation/unitFix.tsv` — only to count the fixes (its rows).
- `DATA/settings.yaml` — the no-value thresholds (section `1_Input`) and the KS thresholds (section
  `5_EvaluateHarmonisedData`), for the Harmonised Values table.
- `DATA/5_EvaluateHarmonisedData/ks_test_warning.tsv` — the KS warnings, for the `Warnings(total)` of the
  Harmonised Values table.
- `DATA/3_Target/4_BuildTargetTable/targetTable.tsv`, `DATA/3_Target/1_GetMeasurementOmopData/measurementOmopData.tsv`
  and `DATA/3_Target/2_GetHarmonisedUnitFromLab2Clean/loincSiConventionalConversion.tsv` — for the Target Data tab.

- `DATA/5_EvaluateHarmonisedData/evaluatedHarmonisedKantaAgregatedTable.tsv` — one row
  per `TEST_NAME` + `MEASUREMENT_UNIT` + `UNIT` pair (see `5_EvaluateHarmonisedData`).

## Outputs

In `DATA/6_BuildDashboard/`:

- `dashboard.html` — one file with no external libraries or fonts: the data is inside
  the page, so it opens offline in a browser. Four tabs, in this order (Mapping Summary is the one shown when the page opens):
  - **Input Data**: the tables of `kantaAgregatedTable.summary.md` (Name Unit Value combinations,
    Units, Values, Reference Ranges, Test Outcomes), computed from the same pairs of the evaluated table.
  - **Target Data**: the tables of `targetTable.summary.md` and `targetTable.validation.md` (Concepts, Groups, Validations and the Groups with
    more than one `harmonised_unit`), computed from `targetTable.tsv`.
  - **Mapping Summary**:
    - *Fixed Units* — one row: the number of test+unit fixes (rows of `unitFix.tsv`), the number of
      test+unit combinations (pairs) fixed, i.e. whose
      `MEASUREMENT_UNIT` was changed to a different `UNIT` (of the mapped pairs), the number of
      records and the percentage of records.
    - *Harmonised test+unit* — by `mapping_status` (APPROVED, NOT-APPROVED, IGNORE, MISSING,
      ERROR, which counts every `ERROR:<reason>`): the warnings not ignored and, in brackets, the total (from the four warning tables of
      `4_BuildHarmonisationTable`), the number of test+unit
      combinations (pairs), the number of records and the percentage of records, and a
      total row.
    - *Errors* — only when there are ERROR pairs: one row per reason (`ERROR:MissingConceptId`,
      `ERROR:PropertyUnitMismatch`, `ERROR:SharedProperty`, `ERROR:MissingConversion`,
      `ERROR:LoincGroupUnitsMissmatch`, those that occur), with the number of pairs and records, the percentage of
      all the records, and a total row.
    - *Harmonised Values* — the KS warnings not ignored and, in brackets, the total
      (`ks_test_warning.tsv`), and one row per `harmonisation_values_status` of
      `evaluatedHarmonisedKantaAgregatedTable.tsv` (set by `5_EvaluateHarmonisedData`): the number of codes (pairs) and records, and the percentage of records,
      in this order (each pair in the first that applies, the rows add up to the total; only
      `APPROVED` pairs are compared):
      AGREE with their LOINC Group (KS under 0.5); WARNING (KS from 0.5 to 0.8, both included);
      DISAGREE (KS over 0.8); error: values with missing units (no `UNIT`; "Error" in red);
      not compared: only one pair
      per group (fewer than 2 other approved pairs in its LOINC Group or concept; grey row); no value: value ignored, is qualitative or panel (the concept's `harmonised_unit_source` is
      `isQualitative` or `panel`; grey row); no value (fewer than `n_records_no_value_threshold` values or `n_subjects_no_value_threshold` subjects; grey row);
      not mapped (`NOT-APPROVED`, `IGNORE`, `MISSING` or `ERROR`; grey row). A pair with no values is
      counted there first, whatever its status. In the KS column of the Mapping Table an approved pair
      whose concept has no target unit shows `no unit` in grey.
  - **Mapping Table**: one row per pair, with `mapping_status` and, below it in the same cell, the
    harmonised values status of the pair (its row of the *Harmonised Values* table, with the same
    colour; a second filter under the Status header selects it), the OMOP concept (id, name with
    ` (panel)` added when the concept is a panel), *Harm. Unit* (the target unit of the concept, `target_unit` of
    the harmonisation table: `harmonisedUnitOverwrite.tsv` or `targetTable.tsv`; empty for a qualitative concept or a panel), the quantity (`has_property`), `Unit change` (`MEASUREMENT_UNIT->UNIT`, only when the
    two differ and the pair is mapped), `TestCode[Unit]` (`TEST_NAME[UNIT]`, the unit after the fix; `TEST_NAME[MEASUREMENT_UNIT]` for a `MISSING`
    pair, which has no `UNIT`), the number of
    records, bars with the share of records by value source and by unit source (hover a
    bar for a small table with `pRecords` and the approximate `nRecords`), the deciles,
    the value unit harmonisation (the conversion factor, and below it the harmonised unit
    only when `HARMONISED_UNIT` is not the `UNIT`), the harmonised deciles with the
    deciles of the reference below them (followed by the number of pairs they come from, e.g. `(36)`), `KS` with `KS_mlp` in brackets (green under
    0.5, yellow up to 0.8, red above), `log10_D5`, the reference (the name of the LOINC Group, or `Same concept`, and the number
    of other approved pairs in it), and `In reference` (yes when the pair is part of the
    reference of the other pairs of its Groups) and the warning messages. The columns have fixed, narrow widths. Click a
    header to sort (the concept id too); every column has a filter: text matches
    anywhere (case insensitive), numeric columns take `>0.5`, `<=2`, `=0.3` or a range
    `0.2..0.5`, and the status is a list. The table starts sorted by `N records`, largest first, and shows 25 to 250 rows per page.
- `log.txt` — run log.

The number of subjects is not in the aggregated data, so it is not in the dashboard.

## URL parameters

The URL sets the starting view of the dashboard, e.g.
`dashboard.html?tab=mappingtable&status=approved&testcodeunit=p-krea`:

- `tab` — `inputdata`, `targetdata`, `mappingsummary` or `mappingtable` (also `input`, `target`,
  `summary`, `table`). Without it the page opens on Mapping Summary.
- one parameter per column of the Mapping Table, to filter it. The name is the column label or key without
  spaces and symbols, in any case (`status`, `conceptid`, `conceptname`, `quantity`, `unitchange`,
  `testcodeunit`, `nrecords`, `ks`, ...), and the value is what would be typed in the filter box of the column
  (text matches anywhere; numeric columns take `>0.5`, `<=2`, `=0.3` or `0.2..0.5`; `status` is not case
  sensitive). Several parameters combine.

The URL is only read when the page opens; changing a tab or a filter in the page does not update it. The
query string works when the file is opened from disk or from a web server that keeps it.

## Action

`scripts/buildDashboard.R`:

1. Reads the evaluated table and `scripts/dashboardTemplate.html`.
2. Builds the two summary tables as HTML. The KS thresholds `ksAgree` (0.5) and
   `ksDisagree` (0.8) are set at the top of the script, and the same values colour the
   `KS` of the table.
3. Builds the data of the table: the columns of values as JSON (compact; the missing
   values are `null`).
4. Writes `dashboard.html`: the template with the tables and the JSON filled in. The
   page is plain HTML, CSS and JavaScript, with no libraries.

## Env vars

None required.

## How to run

```
./SCRIPTS/6_BuildDashboard/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
