# LOINC -> OMOP Mapping -- Stats

Source: `DATA_v4/6_EvaluateMapping/codesWithOMOP.tsv`

## Overview

Each local code carries the OMOP concept `5_FixLOINC` chose for it
from a shortlist that a semantic search over the LOINC vocabulary returned for
the name `4_FindLOINC` guessed. One funnel, from a raw local code
to a concept that agrees with the separately curated reference mapping:

| step | n_codes | p_codes | n_events | p_events |
|---|---|---|---|---|
| total | 2,687 | 100.0% | 51,790,415 | 100.0% |
| has a guessed loinc | 2,577 | 95.9% | 51,567,886 | 99.6% |
| has a fixed loinc | 2,077 | 77.3% | 47,581,148 | 91.9% |
| exists in reference | 1,209 | 45.0% | 50,528,414 | 97.6% |
| agrees with reference |   742 | 27.6% | 40,275,283 | 77.8% |

"Reference" here and below means the reference's **`APPROVED`** rows
only — a code with only an `UNCHECKED`/`NOT-FOUND`/`IGNORED` reference row
counts as absent from it, not as a match or a miss (see Compare with
reference).

## Compare with reference

`DATA_v4/ReferenceMappings/lab_data_summary.csv` holds a separately curated
Finnish-code -> OMOP mapping, restricted here to its `APPROVED` rows and
matched to this table by `TEST_NAME` + `UNIT` (an empty `UNIT` counts as a unit
of its own, so a code with no unit recorded is a different row from the same
code in `mmol/l`, on both sides of the join).

**1209 / 2687 codes (45.0%) carry an APPROVED reference mapping** for their
`TEST_NAME`+`UNIT`. The rest of this section focuses only on those 1209 codes
-- the ones with something to compare against; a code with no APPROVED
reference row has nothing to agree or disagree with and is dropped from every
table and example below.

The reference is the best mapping available, not ground truth — it contains
errors of its own (it sends the rapid-test code `c-reaktiivinenproteiini,pika`
to a high-sensitivity CRP concept, though that row's values floor at 5 mg/l),
and it is internally inconsistent on some panel families. Read the figures
below as *agreement*, not as correctness.

### By evidence level

What the local row actually carried. The reference gives
more than one concept across a code's units for only ~6% of multi-unit codes,
so it is in practice a `TEST_NAME` -> concept mapping, while this pipeline maps
`(TEST_NAME, UNIT)`. A `name`-only row has nothing that fixes its quantity, so
`5_FixLOINC` takes a concept there only when the name alone settles it
and declines otherwise — which is why those rows both get AI-mapped less
often and agree less often. `p_codes` is this row's share of all
1209 codes in the reference; `p_ai_mapped` is of this row's
own codes, how many got AI-mapped; `p_agree` is of the ones this row
actually mapped, how many agreed:

| evidence_level | n_codes | n_ai_mapped | n_agree | p_codes | p_ai_mapped | p_agree |
|---|---|---|---|---|---|---|
| name+unit+values |  590 |  570 | 428 | 48.8% | 96.6% | 75.1% |
| name |  441 |  292 | 177 | 36.5% | 66.2% | 60.6% |
| name+values |  138 |  136 | 107 | 11.4% | 98.6% | 78.7% |
| name+unit |   40 |   39 |  30 | 3.3% | 97.5% | 76.9% |
| total | 1209 | 1037 | 742 | 100.0% | 85.8% | 71.6% |

The same breakdown weighted by records instead of codes:

| evidence_level | n_events | n_ai_mapped | n_agree | p_events | p_ai_mapped | p_agree |
|---|---|---|---|---|---|---|
| name+unit+values | 41,984,023 | 39,805,270 | 36,624,587 | 83.1% | 94.8% | 92.0% |
| name |  7,487,095 |  5,840,920 |  2,752,173 | 14.8% | 78.0% | 47.1% |
| name+values |  1,041,422 |  1,030,129 |    883,259 | 2.1% | 98.9% | 85.7% |
| name+unit |     15,874 |     15,662 |     15,264 | 0.0% | 98.7% | 97.5% |
| total | 50,528,414 | 46,691,981 | 40,275,283 | 100.0% | 92.4% | 86.3% |

### By record volume

The reference was curated for the codes that carry the data: it covers 97% of
the rows with 50,000+ records and under 30% of those below 500. Grouping by how
many records a code actually has -- restricted, like the rest of this section,
to the 1209 codes with an APPROVED reference mapping -- shows whether agreement
holds up for the high-volume codes the reference was written for, or only for
the tail it barely touches.

| records | n_codes | n_ai_mapped | n_agree | p_codes | p_ai_mapped | p_agree |
|---|---|---|---|---|---|---|
| < 100 |  184 |  139 | 107 | 15.2% | 75.5% | 77.0% |
| 100 - 499 |  341 |  299 | 216 | 28.2% | 87.7% | 72.2% |
| 500 - 4,999 |  376 |  331 | 242 | 31.1% | 88.0% | 73.1% |
| 5,000 - 49,999 |  210 |  180 | 114 | 17.4% | 85.7% | 63.3% |
| >= 50,000 |   98 |   88 |  63 | 8.1% | 89.8% | 71.6% |
| total | 1209 | 1037 | 742 | 100.0% | 85.8% | 71.6% |

The same breakdown weighted by records instead of codes:

| records | n_events | n_ai_mapped | n_agree | p_events | p_ai_mapped | p_agree |
|---|---|---|---|---|---|---|
| < 100 |      7,560 |      5,659 |      4,298 | 0.0% | 74.9% | 75.9% |
| 100 - 499 |     83,388 |     73,579 |     54,127 | 0.2% | 88.2% | 73.6% |
| 500 - 4,999 |    638,860 |    551,372 |    389,318 | 1.3% | 86.3% | 70.6% |
| 5,000 - 49,999 |  3,483,370 |  3,041,483 |  1,948,447 | 6.9% | 87.3% | 64.1% |
| >= 50,000 | 46,315,236 | 43,019,888 | 37,879,093 | 91.7% | 92.9% | 88.1% |
| total | 50,528,414 | 46,691,981 | 40,275,283 | 100.0% | 92.4% | 86.3% |

### Examples — not automapped

Five of the rows the reference maps but the pipeline left empty. An empty
`loinc_name_guess` means `4_FindLOINC` could not name the test at all;
a filled one means the search returned nothing the model would accept.


*156 distinct not automapped rows; 5 shown:*

| TEST_NAME | UNIT | evidence | certainty | loinc_name_guess | our_omop_concept_name | reference_OMOP_CONCEPT_NAME | reasoning |
|---|---|---|---|---|---|---|---|
| cu-alb-mi |  | name |  | Albumin in Collected urine |  | Albumin [Mass/time] in Urine collected for unspecified duration | The property (quantity type) cannot be determined as the row lacks a unit and value deciles. Candidates exist for [Mass/time], [Mass/volume] and [Presence]. |
| p-gt |  | name |  | Gamma glutamyltransferase [Enzymatic activity/volume] in Plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | The property cannot be determined from the name alone. Concepts for GGT exist with different properties (e.g., activity, mass), and without a unit or values, the choice is ambiguous. |
| b-ghba1c-oma |  | name |  | Hemoglobin A1c/Hemoglobin.total in Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood | Cannot map. Insufficient evidence to determine the property: [Mass Fraction] (for unit '%') vs. [Substance Ratio] (for unit 'mmol/mol'). |
| p-apttspr | s | name+unit+values |  | Activated partial thromboplastin time [Time] in Plasma |  | aPTT in Blood by Coagulation assay | The candidate list is missing a concept for a basic aPTT measurement with a `Time` property. `p-apttspr` is an aPTT variant (unit `s` and values confirm), but the `spr` suffix is unclear and no suitable candidate exists. |
| p-c-reaktiivinenproteiini |  | name |  | C reactive protein [Mass/volume] in Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | No unit or value deciles available, so the property (e.g., Mass/volume vs Moles/volume) cannot be determined. Both are possible for CRP. |


### Examples — disagreement

Five of the rows where the pipeline produced an id and the reference has a
different one, sampled from the *distinct* (our concept, reference concept)
pairs so one recurring disagreement cannot fill the table. `reasoning` is what
`5_FixLOINC` gave for that choice, clause by clause — so the mistake
can be read rather than guessed at.

*157 distinct disagreement rows; 5 shown:*

| TEST_NAME | UNIT | evidence | certainty | loinc_name_guess | our_omop_concept_name | reference_OMOP_CONCEPT_NAME | reasoning |
|---|---|---|---|---|---|---|---|
| vb-ca-ion | mmol/l | name+unit+values | high | Calcium.ionized [Moles/volume] in Venous blood | Calcium.ionized [Moles/volume] in Venous blood | Calcium.ionized [Moles/volume] in Serum or Plasma | Calcium.ionized bcs 'vb-ca-ion' ; [Moles/volume] bcs unit mmol/l and values ~1.0-1.2 ; in Venous blood bcs prefix 'vb-' |
| b-hladrld |  | name | high | HLA-DRB1 high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection | HLA-DRB1 SBT [Type] in Specimen by High resolution | HLA-DR beta [Type] | HLA-DRB1 bcs `hladrb` ; by High resolution bcs suffix `-ld` (`tarkennettu`) ; in Blood bcs prefix `b-` |
| s-afsuol3 | u/l | name+unit+values | high | Alkaline phosphatase.intestinal 3 [Enzymatic activity/volume] in Serum | Alkaline phosphatase.intestinal 3 [Enzymatic activity/volume] in Serum or Plasma | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum or Plasma | Alkaline phosphatase.intestinal 3 bcs TEST_NAME 's-afsuol3' where 'af'=alk phos, 'suol'=intestinal, '3'=fraction 3 ; [Enzymatic activity/volume] bcs UNIT is 'u/l' ; in Serum bcs TEST_NAME prefix 's-' |
| p-tt | % | name+unit+values | medium | Prothrombin time (PT) [Ratio] in Platelet poor plasma | Prothrombin index in Platelet poor plasma by Coagulation assay | Prothrombin time (PT) actual/Normal | Prothrombin time ratio bcs LongName 'Tromboplastiiniaika' and UNIT '%' ; [Ratio] bcs this concept has a ratio property ('normal/actual') which corresponds to reporting in percent ; in Platelet poor plasma bcs prefix 'p-' (Plasma) is equivalent. |
| u-gluk-0 |  | name+values | high | Glucose [Presence] in Urine | Glucose [Presence] in Urine | Glucose [Presence] in Urine by Test strip | Glucose bcs TEST_NAME has 'gluk' ; [Presence] bcs value_deciles are all 0, indicating a qualitative result ; in Urine bcs prefix is 'U-'. |

