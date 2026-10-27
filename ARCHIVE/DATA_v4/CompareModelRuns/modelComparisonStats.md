# Model comparison -- Stats

Runs compared (the first is the baseline): `gemini-2.5-pro` (`DATA`), `claude-sonnet-5` (`DATA_sonnet`), `claude-opus-5` (`DATA_opus`).

Every run processed the same similarity groups of the same input table
through the same system prompts; only the model differs. Two things are
measured, and they answer different questions:

1. **Against the reference** — how often each run produces the same OMOP
   concept as the curated Finnish mapping, over the rows both cover. This is
   MapLOINCToOmop's own cross-check, repeated per run on the same join key
   (`TEST_NAME` + `UNIT`, an empty `UNIT` counting as a unit) and the same
   four outcomes. It is **agreement, not correctness**: the reference is the
   best mapping available, not ground truth, and carries errors of its own.
2. **Against each other** — how often two runs choose the same concept, on
   the rows they share. This needs no reference, so it also covers the rows
   the reference has no `APPROVED` answer for, which is most of them.

## Coverage and cost

`named` is how many rows `FindLOINCDimensions` could write a LOINC name for;
`mapped` how many of them `FixLOINCDimensions` then resolved to a real OMOP
concept. Coverage is easy to inflate by never declining, so it is reported
next to agreement, never instead of it. `cost_usd` is what the two LLM steps
logged for that run.

| run | rows | named | mapped_of_named | distinct_concepts | cost_usd |
|---|---|---|---|---|---|
| gemini-2.5-pro | 1984 | 1890 (95.3%) | 1561 (82.6%) | 601 | 6.36 |
| claude-sonnet-5 | 1984 | 1920 (96.8%) | 600 (31.2%) | 221 | 5.48 |
| claude-opus-5 | 1984 | 1925 (97.0%) | 1746 (90.7%) | 646 | 26.86 |

## Agreement with the reference

`overlap` is the rows with an `APPROVED` reference mapping. `agreement` is
over that whole overlap; `agreement_of_answered` drops the rows the run
declined, so the two together show whether a run buys agreement by
abstaining. `agreement_evidenced` restricts to rows carrying a unit, values,
or both; `agreement_highvolume` to codes with >= 500 records — the
range the reference was actually curated for.

| run | overlap | answered | agreement | agreement_of_answered | agreement_evidenced | agreement_highvolume |
|---|---|---|---|---|---|---|
| gemini-2.5-pro | 764 | 693 (90.7%) | 454 (59.4%) | 65.5% | 353 / 500 (70.6%) | 278 / 467 (59.5%) |
| claude-sonnet-5 | 764 | 246 (32.2%) | 198 (25.9%) | 80.5% | 164 / 500 (32.8%) | 121 / 467 (25.9%) |
| claude-opus-5 | 764 | 744 (97.4%) | 506 (66.2%) | 68.0% | 358 / 500 (71.6%) | 297 / 467 (63.6%) |

## Outcomes

- **not in reference** — no `APPROVED` reference mapping for this row, so
  there is nothing to compare against. Identical across runs by construction:
  it depends on the reference and the input table, not on the model.
- **not automapped** — the reference has the code, the run declined every
  candidate. For a code with no unit and no values that is the intended
  answer, not a failure.
- **disagreement** — the run produced an id, the reference has another.
- **agreement** — same id as the reference.

| outcome | gemini-2.5-pro | claude-sonnet-5 | claude-opus-5 |
|---|---|---|---|
| not in reference | 1220 (61.5%) | 1220 (61.5%) | 1220 (61.5%) |
| not automapped | 71 (3.6%) | 518 (26.1%) | 20 (1.0%) |
| disagreement | 239 (12.0%) | 48 (2.4%) | 238 (12.0%) |
| agreement | 454 (22.9%) | 198 (10.0%) | 506 (25.5%) |

## Agreement by evidence level

What the local row actually carried. A `name`-only row has nothing that
fixes its quantity, so `FixLOINCDimensions` is meant to decline there unless
the name alone settles the concept — which makes this the split where the
models are most free to differ, and where a higher number is not
automatically better.

| evidence_level | gemini-2.5-pro | claude-sonnet-5 | claude-opus-5 |
|---|---|---|---|
| name+unit+values | 240 / 348 (69.0%) | 109 / 348 (31.3%) | 243 / 348 (69.8%) |
| name | 101 / 264 (38.3%) | 34 / 264 (12.9%) | 148 / 264 (56.1%) |
| name+values | 85 / 115 (73.9%) | 40 / 115 (34.8%) | 84 / 115 (73.0%) |
| name+unit | 28 / 37 (75.7%) | 15 / 37 (40.5%) | 31 / 37 (83.8%) |

## Run against run

On the rows every run covers. `same_concept` is out of the rows **both**
runs mapped, so declines do not count as agreement. Rows where two models
independently land on the same concept are weak evidence it is right; rows
where they split are the ones worth a human's time.

| pair | rows | both_mapped | same_concept | only_first | only_second | neither |
|---|---|---|---|---|---|---|
| gemini-2.5-pro vs claude-sonnet-5 | 1984 | 561 (28.3%) | 487 (86.8%) | 1005 | 40 | 378 |
| gemini-2.5-pro vs claude-opus-5 | 1984 | 1505 (75.9%) | 1120 (74.4%) | 61 | 251 | 167 |
| claude-sonnet-5 vs claude-opus-5 | 1984 | 585 (29.5%) | 492 (84.1%) | 16 | 1171 | 212 |

## Where the runs split on the reference

Rows the reference has an `APPROVED` answer for and where at least one run agrees with it and at least one does not — 368 in total, 15 shown, sampled by row so one recurring code cannot fill the table.
`OK` marks the run that matched the reference; `--` one that did not, followed
by what it chose instead (or `(declined)` where it chose nothing).

| TEST_NAME | UNIT | evidence_level | reference | gemini-2.5-pro | claude-sonnet-5 | claude-opus-5 |
|---|---|---|---|---|---|---|
| -ana |  | name | Nuclear Ab [Titer] in Serum | OK Nuclear Ab [Titer] in Serum | OK Nuclear Ab [Titer] in Serum | -- Nuclear Ab [Presence] in Serum |
| as-amyl |  | name | Amylase [Enzymatic activity/volume] in Peritoneal fluid | -- (declined) | -- (declined) | OK Amylase [Enzymatic activity/volume] in Peritoneal fluid |
| p-afos |  | name+values | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | OK Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | -- (declined) | OK Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| s-aldos-p |  | name+values | Aldosterone [Moles/volume] in Serum or Plasma --upright | OK Aldosterone [Moles/volume] in Serum or Plasma --upright | -- (declined) | OK Aldosterone [Moles/volume] in Serum or Plasma --upright |
| s-afmaksa | u/l | name+unit+values | Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma | OK Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma | -- (declined) | OK Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma |
| s-maksa2 | u/l | name+unit+values | Alkaline phosphatase.liver 2 [Enzymatic activity/volume] in Serum or Plasma | -- Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | -- (declined) | OK Alkaline phosphatase.liver 2 [Enzymatic activity/volume] in Serum or Plasma |
| -bokanho |  | name | Human bocavirus DNA [Presence] in Specimen by NAA with probe detection | OK Human bocavirus DNA [Presence] in Specimen by NAA with probe detection | -- (declined) | OK Human bocavirus DNA [Presence] in Specimen by NAA with probe detection |
| b-cd19 |  | name | CD19 cells [#/volume] in Blood | OK CD19 cells [#/volume] in Blood | -- (declined) | OK CD19 cells [#/volume] in Blood |
| b-cd8 |  | name | CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood | OK CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood | -- (declined) | OK CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood |
| b-t-cd8 |  | name | CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood | OK CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood | -- (declined) | OK CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood |
| s-cv19aba |  | name | SARS-CoV-2 (COVID-19) IgA Ab [Presence] in Serum or Plasma by Immunoassay | -- SARS-CoV-2 (COVID-19) IgA Ab [Units/volume] in Serum or Plasma by Immunoassay | -- (declined) | OK SARS-CoV-2 (COVID-19) IgA Ab [Presence] in Serum or Plasma by Immunoassay |
| gluk2h | mmol/l | name+unit+values | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | OK Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | -- (declined) | OK Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| p-aspartaattiaminotransferaasi |  | name | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | OK Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | -- (declined) | OK Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| s-aspartaattiaminotransferaasi | u/l | name+unit+values | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | OK Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | -- (declined) | OK Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| s-aspartaattiaminotransferaasi |  | name | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | OK Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | -- (declined) | OK Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma |

