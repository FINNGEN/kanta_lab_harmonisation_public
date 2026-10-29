# 4_BuildDashboard

Builds a self-contained HTML dashboard of the evaluated harmonised summary data: an
overview of the mapping status and of how the values compare with their LOINC Group, and
an interactive table with one row per pair.

## Inputs

- `DATA_SUMMARY/3_EvaluateHarmonisedData/evaluatedHarmonisedKantaSummaryData.tsv` — one row
  per `TEST_NAME` + `PREPROCESED_UNIT` + `UNIT` pair (see `3_EvaluateHarmonisedData`).

## Outputs

In `DATA_SUMMARY/4_BuildDashboard/`:

- `dashboard.html` — one file with no external libraries or fonts: the data is inside
  the page, so it opens offline in a browser. Two tabs:
  - **Summary**:
    - *Harmonised Events* — by `mapping_status` (APPROVED, ERROR, NOT-APPROVED, IGNORE,
      NOT-FOUND): the pairs with a warning message, the number of test+unit
      combinations (pairs), the number of records and the percentage of records, and a
      total row.
    - *Harmonised Values* — the number of codes (pairs) and records, and the percentage
      of records, of the pairs that have no values (100% of the records without a
      value), those that AGREE with their LOINC Group (KS under 0.5), those with a
      WARNING (KS from 0.5 to 0.8, both included), those that DISAGREE (KS over 0.8),
      and those that are not compared, each reason apart: not mapped (NOT-FOUND or
      IGNORE), no conversion to a harmonised unit, and no LOINC Group with enough
      approved pairs. The rows add up to the total.
  - **Table**: one row per pair, with `mapping_status`, the OMOP concept (id, name,
    quantity = `has_property`), `Unit change` (`PREPROCESED_UNIT->UNIT`, only when the
    unit was fixed), `TEST_NAME[PREPROCESED_UNIT]`, the number of records, bars with the
    share of records by value source and unit source, the deciles, `KS` with `KS_mlp`
    in brackets (green under 0.5, yellow up to 0.8, red above), the conversion to the
    harmonised unit, the harmonised deciles, `log10_D5`, the reference group (name and
    number of pairs) and the warning messages. Click a header to sort; every column
    has a filter: text matches anywhere (case insensitive), numeric columns take
    `>0.5`, `<=2`, `=0.3` or a range `0.2..0.5`, and the status is a list. The table
    shows 25 to 250 rows per page.
- `log.txt` — run log.

The number of subjects is not in the summary data, so it is not in the dashboard.

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
./STEPS/SUMMARY/4_BuildDashboard/run.sh <PATH_TO_DATA_SUMMARY> --env <ENV_NAME>
```
