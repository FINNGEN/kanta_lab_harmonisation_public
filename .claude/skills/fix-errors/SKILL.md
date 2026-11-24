---
name: fix-errors
description: Use when the user asks to map Kanta tests or fix the errors the pipeline reports (e.g. "fix the MissingConversion errors", "why does s-tsh disagree", "map p-xyz", "work on the dashboard errors"). Gathers the evidence of a pair, proposes a change to the 2_Harmonisation tables, applies it after confirmation, reruns and reports.
---

# Fix errors

This skill is the **procedure** to fix an error of the mapping (mode 2 of `AGENTS.md`). What each error
means, where it comes from and its possible solutions are defined only in `README.md`, "Errors along the
process": look the error up there by its label (e.g. `ERROR:MissingConversion`, **Values mismatch**) and do
not copy the catalogue here.

Status: draft. It is refined from real cases: after each case worked with the user, add what was actually
checked and decided to "Lessons from cases" at the end.

## Guardrails

- Edit only the tables of `DATA/2_Harmonisation/` and the `ignore` column of the warning tables. Never edit
  the outputs of a step or `3_Target` by hand.
- **Propose first.** Show the evidence and the rows you would add or change, and wait for the user's
  answer before editing.
- **Never set `APPROVED` or `ignore` to `TRUE` without the user's explicit confirmation**: both declare the
  mapping right. A new mapping row goes in with `APPROVED` = `FALSE` unless the user approves it.
- One decision at a time: fix the unit before judging the values, and the mapping before the unit.
- Never commit (see `AGENTS.md`).

## 1. Choose what to work on

When the user does not name a pair, list the open errors and propose an order:

- By `mapping_status` in `DATA/4_BuildHarmonisationTable/harmonisationTable.tsv`, then
  `harmonisation_values_status` in `DATA/5_EvaluateHarmonisedData/evaluatedHarmonisedKantaAgregatedTable.tsv`.
- Largest first: sort by the records of the pair (`n`) or of the `TEST_NAME` across its units.
- Errors upstream first: `MissingConceptId` and the mapping errors, then `PropertyUnitMismatch`,
  `MissingConversion`, then `LoincGroupUnitsMissmatch`, then the values (`DISAGREE`, `WARNING`). A unit or
  mapping fix often changes the values status, and a wrong pair in a Group can make the others disagree.
- Pairs of the same `TEST_NAME` (several units) or of the same concept are worked together.

## 2. Gather the evidence

For a pair `TEST_NAME[MEASUREMENT_UNIT]`, collect and show in one short table:

| Evidence | Where |
|---|---|
| records, subjects, unit and value sources | `kantaAgregatedTable.tsv`: `n`, `n_subjects`, `unit_source_…`, `value_source_…` |
| the deciles, and the reference deciles | evaluated table: `decile_value`, `decile_value_harmonised`, `reference_decile_value_harmonised` |
| the shift and the distance | evaluated table: `log10_D5` (a whole number, e.g. -2 or 3, is a factor of 100 or 1000: a unit problem), `KS` |
| the reference ranges and test outcomes | `reference_range` (e.g. `AF[3.5,5]`), `test_outcome` (e.g. `N[94];A[37]`): a range of the wrong size points to the unit; only N/A/POS/NEG points to a qualitative test |
| the other units of the same `TEST_NAME` | all the rows of the `TEST_NAME` in the evaluated table, and in `unitFix.tsv` |
| the concept and its LOINC axes | `targetTable.tsv`: `concept_name`, `has_component`, `has_property`, `has_system`, `has_scale_type`, `harmonised_unit`, `harmonised_unit_source`, the Groups |
| the other pairs of the concept or Group | the evaluated table, same `concept_id` or `group_concept_id`: their units and deciles |
| the warning that holds the error | the `message` of its row in the `_warning.tsv` of step 4 or in `ks_test_warning.tsv` |

The `TEST_NAME` prefix gives the specimen; check it against `has_system` of the concept. As the approved
mappings use them: `b-` and `l-` Blood, `p-`, `s-`, `fp-`, `fs-` Serum or Plasma, `u-`, `du-`, `cu-` Urine,
`pt-` Serum, Plasma or Blood (often calculated, e.g. eGFR), `li-` Cerebral spinal fluid, `ab-` Blood
arterial, `cb-` Blood capillary, `vb-` Blood venous, `e-` Red Blood Cells, `pf-` Pleural fluid, `sy-`
Synovial fluid, `f-` Stool.

### Show the pairs in the dashboard

When showing the evidence, and again in the report after the rerun, offer the user a link to the dashboard
filtered on the pairs of the case, so they can check them by eye. The URL parameters are described in
`SCRIPTS/6_BuildDashboard/README.md`, "URL parameters":

```
file://<repo>/DATA/6_BuildDashboard/dashboard.html?tab=mappingtable&<column>=<filter>&...
```

- `tab=mappingtable`, then one parameter per column filter, written as in the filter box: `testcodeunit`,
  `conceptid`, `conceptname`, `quantity`, `unitchange`, `nrecords`, `ks`, ... (text matches anywhere;
  numbers take `>0.5`, `<=2`, `0.2..0.5`).
- `status` takes one whole `mapping_status`, e.g. `ERROR:PropertyUnitMismatch`.
- URL-encode the values (`%20` for a space, `%2F` for `/`, `%3A` for `:`).
- Give one link for the pairs in error and, when it helps, one for all the pairs of the concept or the
  property (to compare with the approved ones). Open it with `open "<url>"` only if the user asks.

## 3. Find a candidate concept

When a mapping is missing or wrong:

- Search `targetTable.tsv` (one row per concept and Group) by the component in English in `concept_name` and
  `has_component`, then narrow by `has_system` (from the prefix), `has_property` (from the unit: `g/l` mass
  concentration, `mmol/l` substance concentration, `%` fraction, `/l` number concentration) and
  `has_scale_type` (`Qn` with values, `Ord`/`Nom` qualitative).
- Look at how the same test is already mapped: other units of the `TEST_NAME`, and `TEST_NAME`s with the
  same stem in `mapping.tsv` (e.g. `p-krea`, `s-krea`, `u-krea`).
- Prefer a concept of a LOINC Group already used by approved pairs of the same test, and a LOINC concept
  over a SNOMED one.
- Give 1 to 3 candidates with their `concept_id`, `concept_name`, axes and `harmonised_unit`, and say which
  you recommend and why.

## 4. Propose the change

Write the exact rows, in the format of each table (tab separated, `""` for missing, never `NA`):

| Table | Columns | A correct new row |
|---|---|---|
| `mapping.tsv` | `TEST_NAME`, `UNIT`, `concept_id`, `ignore_mapping_reason`, `APPROVED` | `TEST_NAME` + `UNIT` unique; `APPROVED` `TRUE`/`FALSE`; a pair left out on purpose has `concept_id` 0 and an `ignore_mapping_reason` (reuse an existing reason, e.g. `Diagnostic procedure, not lab test`) |
| `unitFix.tsv` | `TEST_NAME`, `MEASUREMENT_UNIT`, `UNIT`, `unit_fix_reasoning`, `INJECTION_NOTES` | `UNIT` differs from `MEASUREMENT_UNIT`; the `TEST_NAME` + `MEASUREMENT_UNIT` is not in `mapping.tsv`; the `TEST_NAME` + `UNIT` is (otherwise the fix is unused); say why in `unit_fix_reasoning` |
| `unitHarmonisation.tsv` | `context`, `UNIT`, `HARMONISED_UNIT`, `CONVERSION`, `VALIDATION_MESSAGES` | `context` is a `has_property` (all its concepts) or a `concept_id` (only that one, wins); `HARMONISED_UNIT` written exactly as in `targetTable.tsv` (e.g. `g/L`); `CONVERSION` a number or a formula in `X` (e.g. `0.001`, `703*X+0`) |
| `harmonisedUnitOverwrite.tsv` | `concept_id`, `harmonised_unit`, `note` | one row per concept; `note` says why; add the conversions to the new unit |

Show the effect you expect: the new `mapping_status`, the `HARMONISED_UNIT`, and for a unit fix the
deciles after the conversion against the reference.

## 5. Apply, rerun and check

After the user agrees:

1. Edit the table(s).
2. Rerun from step 4: `./SCRIPTS/4_BuildHarmonisationTable/run.sh DATA --env build`, then steps 5 and 6
   (see "Rerunning after an edit" in `README.md`).
3. Check `harmonisationTable.validation.md` has no ERROR and no new WARNING about the edited rows.
4. Check the pair's new `mapping_status` and `harmonisation_values_status`, and that no other pair of the
   same concept or Group changed status unexpectedly (its reference changed).

## 6. Report

- The rows added or changed, table by table.
- The pair before and after: `mapping_status`, `harmonisation_values_status`, `KS`, `log10_D5`.
- The change of the dashboard counts (Events and Harmonised Values tables), and any other pair that
  changed status.
- What is left open, and anything the user should decide.

## Lessons from cases

(Empty: add here, per case, what was checked and decided, and turn repeated lessons into rules above.)
