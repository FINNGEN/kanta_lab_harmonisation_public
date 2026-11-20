# 6_BuildDashboard

Builds a self-contained HTML dashboard of the evaluated harmonised summary data: an
overview of the mapping status and of how the values compare with their LOINC Group, and
an interactive table with one row per pair.

## Inputs

- `DATA/2_Harmonisation/unitFix.tsv` — only to count the fixes (its rows).
- `DATA/3_Target/4_BuildTargetTable/targetTable.tsv`, `DATA/3_Target/1_GetMeasurementOmopData/measurementOmopData.tsv`
  and `DATA/3_Target/2a_GetHarmonisedUnitFromLab2Clean/loincSiConventionalConversion.tsv` — for the Target Data tab.

- `DATA/5_EvaluateHarmonisedData/evaluatedHarmonisedKantaAgregatedTable.tsv` — one row
  per `TEST_NAME` + `PREPROCESED_UNIT` + `UNIT` pair (see `5_EvaluateHarmonisedData`).

## Outputs

In `DATA/6_BuildDashboard/`:

- `dashboard.html` — one file with no external libraries or fonts: the data is inside
  the page, so it opens offline in a browser. Four tabs, in this order (Mapping Summary is the one shown when the page opens):
  - **Input Data**: the tables of `kantaAgregatedTable.md` (Name Unit Value combinations,
    Units, Reference Ranges, Values), computed from the same pairs of the evaluated table.
  - **Target Data**: the tables of `targetTable.md` (Concepts, Groups, Validations and the Groups with
    more than one `harmonised_unit`), computed from `targetTable.tsv`.
  - **Mapping Summary**:
    - *Fixed Units* — one row: the number of test+unit fixes (rows of `unitFix.tsv`), the number of
      test+unit combinations (pairs) fixed, i.e. whose
      `PREPROCESED_UNIT` was changed to a different `UNIT` (of the mapped pairs), the number of
      records and the percentage of records.
    - *Harmonised test+unit* — by `mapping_status` (APPROVED, ERROR, NOT-APPROVED, IGNORE,
      NOT-FOUND): the pairs with a warning message, the number of test+unit
      combinations (pairs), the number of records and the percentage of records, and a
      total row.
    - *Harmonised Values* — the number of codes (pairs) and records, and the percentage
      of records, of the pairs that have no values (100% of the records without a
      value), those that AGREE with their LOINC Group (KS under 0.5), those with a
      WARNING (KS from 0.5 to 0.8, both included), those that DISAGREE (KS over 0.8),
      and those that are not compared, each reason apart: not mapped (NOT-FOUND or
      IGNORE), no conversion to a harmonised unit, and no LOINC Group or concept with enough
      approved pairs. The rows add up to the total.
  - **Mapping Table**: one row per pair, with `mapping_status`, the OMOP concept (id, name with
    ` (panel)` added when the concept is a panel, quantity = `has_property`), `Unit change` (`PREPROCESED_UNIT->UNIT`, only when the
    two differ and the pair is mapped), `TEST_NAME[PREPROCESED_UNIT]`, the number of
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
