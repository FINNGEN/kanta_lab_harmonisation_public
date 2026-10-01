# LOINC -> OMOP Mapping -- Stats

Source: `DATA_v4/6_EvaluateMapping/codesWithOMOP.tsv`

## Overview

Each local code carries the OMOP concept `5_FixLOINC` chose for it
from a shortlist that a semantic search over the LOINC vocabulary returned for
the name `4_FindLOINC` guessed. This step only resolves that id
against the vocabulary — there is no tuple join to succeed or fail, so
"unmapped" here means the model declined every candidate, not that a join
missed.

| bucket | n | pct |
|---|---|---|
| total | 2687 | 100.0% |
| named by 4_FindLOINC | 2577 | 95.9% |
| left unnamed |  110 | 4.1% |

Of the rows a mapping was attempted for:

| bucket | n | pct |
|---|---|---|
| attempted (a name was guessed) | 2577 | 100.0% |
| mapped to an OMOP concept | 2077 | 80.6% |
| unmapped (no candidate was right) |  500 | 19.4% |
| distinct concepts used |  705 |  |

## By domain (the chosen concept's `has_system`)

Which specimens the mapped codes ended up in, most common first. Unmapped
rows are grouped together: this approach never infers a system of its own, so
an unmapped row has no specimen to be counted under.

| omop_has_system | n_rows | pct_of_rows |
|---|---|---|
| Serum or Plasma | 834 | 31.0% |
| (unmapped) | 609 | 22.7% |
| Urine | 233 | 8.7% |
| Blood | 162 | 6.0% |
| Serum | 143 | 5.3% |
| XXX | 104 | 3.9% |
| Platelet poor plasma |  81 | 3.0% |
| Tissue and Smears |  62 | 2.3% |
| Serum, Plasma or Blood |  59 | 2.2% |
| Stool |  40 | 1.5% |
| Blood or Tissue |  34 | 1.3% |
| Throat |  32 | 1.2% |
| Urine sediment |  27 | 1.0% |
| Blood venous |  25 | 0.9% |
| Blood capillary |  24 | 0.9% |
| Blood arterial |  21 | 0.8% |
| Heart |  20 | 0.7% |
| ^Patient |  19 | 0.7% |
| Cerebral spinal fluid |  15 | 0.6% |
| Red Blood Cells |  15 | 0.6% |
| Pleural fluid |  14 | 0.5% |
| Plasma |   9 | 0.3% |
| Cervix or Vagina |   8 | 0.3% |
| Blood mixed venous |   6 | 0.2% |
| Cervix |   6 | 0.2% |
| Body fluid |   5 | 0.2% |
| Dialysis fluid |   4 | 0.1% |
| Nose |   4 | 0.1% |
| Pharynx |   4 | 0.1% |
| Plasma venous |   4 | 0.1% |
| Semen |   4 | 0.1% |
| Skeletal system |   4 | 0.1% |
| Sputum |   4 | 0.1% |
| Plasma arterial |   3 | 0.1% |
| Respiratory system specimen |   3 | 0.1% |
| Reticulocytes |   3 | 0.1% |
| Skin |   3 | 0.1% |
| Vaginal |   3 | 0.1% |
| Abscess |   2 | 0.1% |
| Catheter tip |   2 | 0.1% |
| Dialysis fluid peritoneal |   2 | 0.1% |
| Duodenal fluid |   2 | 0.1% |
| Genital |   2 | 0.1% |
| Mother's milk |   2 | 0.1% |
| Peritoneal fluid |   2 | 0.1% |
| Respiratory system airway |   2 | 0.1% |
| Synovial fluid |   2 | 0.1% |
| Wound |   2 | 0.1% |
| Amniotic fluid |   1 | 0.0% |
| Aspirate |   1 | 0.0% |
| Breast cancer specimen |   1 | 0.0% |
| Bronchoalveolar lavage |   1 | 0.0% |
| Drain |   1 | 0.0% |
| Ear |   1 | 0.0% |
| Gas delivery system |   1 | 0.0% |
| Inhaled gas |   1 | 0.0% |
| Isolate or Specimen |   1 | 0.0% |
| Lung tissue |   1 | 0.0% |
| Nervous system |   1 | 0.0% |
| Plasma cell-free DNA |   1 | 0.0% |
| Referral lab test |   1 | 0.0% |
| Respiratory system |   1 | 0.0% |
| Serum and Blood |   1 | 0.0% |
| Specimen |   1 | 0.0% |
| Upper respiratory specimen |   1 | 0.0% |

## Cross-check against the reference mapping

`DATA_v4/ReferenceMappings/lab_data_summary.csv` holds a separately curated Finnish-code -> OMOP mapping. Restricted to its `APPROVED` rows and matched to this table by `TEST_NAME`+`UNIT`, it is the only independent read on whether the concepts chosen here are the *right* ones.

The join key is `TEST_NAME` + `UNIT`. An **empty `UNIT` counts as a unit**:
a code with no unit recorded is a different row from the same code in
`mmol/l`, on both sides of the join, and they must not collapse together.

Every row of this pipeline's table then falls into exactly one of four
outcomes:

- **not in reference** — the reference has no **`APPROVED`** mapping for this
  `TEST_NAME`+`UNIT`, so there is nothing to compare against. Not a result
  either way, and mostly not a gap in the reference either — see the split
  below.
- **not automapped** — the reference has this code, but the pipeline produced
  no OMOP id: `5_FixLOINC` judged no candidate defensible and left it
  empty on purpose. For a code with no unit and no values that is the intended
  answer, not a failure.
- **disagreement** — the pipeline produced an id and the reference has a
  different one.
- **agreement** — the pipeline produced the same id as the reference.


| outcome | n | pct_of_all | pct_of_in_reference |
|---|---|---|---|
| not in reference | 1478 | 55.0% |  |
| not automapped |  172 | 6.4% | 14.2% |
| disagreement |  295 | 11.0% | 24.4% |
| agreement |  742 | 27.6% | 61.4% |

Agreement over the whole overlap: **742 / 1209 = 61.4%**. Restricted to rows that carry real evidence (a unit, values, or both): **565 / 768 = 73.6%**.

The reference is the best mapping available, not ground truth — it contains
errors of its own (it sends the rapid-test code `c-reaktiivinenproteiini,pika`
to a high-sensitivity CRP concept, though that row's values floor at 5 mg/l),
and it is internally inconsistent on some panel families. Read the figures
below as *agreement*, not as correctness.

### What "not in reference" actually means

The cross-check uses the reference's `APPROVED` rows only, so that bucket is
*not* "the reference has never heard of this code". It mostly is not: the
reference carries a row for these codes under another status. What it says
about them, and what this pipeline did anyway:

| reference_status | rows | automapped | records |
|---|---|---|---|
| UNCHECKED | 1097 | 748 (68.2%) | 779,224 |
| NOT-FOUND |  282 | 225 (79.8%) | 238,706 |
| (no row at all) |   57 | 45 (78.9%) | 87,321 |
| IGNORED |   42 | 27 (64.3%) | 156,750 |

- **`UNCHECKED`** — nobody has curated the code yet. There is no answer to
  compare against, and these are where a working pipeline adds mappings that
  do not exist today.
- **`NOT-FOUND`** — a curator looked and concluded no concept fits; none of
  these rows carries a concept id in the reference. Rows here that the
  pipeline *did* map are its strongest claim to beat the reference — and,
  equally, where a hallucinated concept would hide. They are the highest-value
  set to put in front of a human.
- **`IGNORED`** — deliberately excluded from the curation.
- **`(no row at all)`** — genuinely absent from the reference file.

### By record volume

The reference was curated for the codes that carry the data. It covers 97% of the rows with 50,000+ records and under 30% of those below 500, so a single agreement figure over the whole overlap mixes the codes it was written for with ones it barely touches.

| records | rows | in_reference | automapped | agreement |
|---|---|---|---|---|
| < 100 |  491 | 184 (37.5%) | 75.5% | 107 (58.2%) |
| 100 - 499 | 1063 | 341 (32.1%) | 87.7% | 216 (63.3%) |
| 500 - 4,999 |  780 | 376 (48.2%) | 88.0% | 242 (64.4%) |
| 5,000 - 49,999 |  255 | 210 (82.4%) | 85.7% | 114 (54.3%) |
| >= 50,000 |   98 | 98 (100.0%) | 89.8% | 63 (64.3%) |

**Restricted to codes with >= 500 records — the range the reference actually covers: 419 / 684 = 61.3%** (69.9% of the 599 it automapped).

### By evidence level

What the local row actually carried. The reference gives
more than one concept across a code's units for only ~6% of multi-unit codes,
so it is in practice a `TEST_NAME` -> concept mapping, while this pipeline maps
`(TEST_NAME, UNIT)`. A `name`-only row has nothing that fixes its quantity, so
`5_FixLOINC` takes a concept there only when the name alone settles it
and declines otherwise — which is why those rows both answer less often and
agree less often, and why they are reported apart from the evidenced ones:

| evidence_level | n_rows | n_automapped | n_agreement | pct_automapped | pct_agree_of_rows | pct_agree_of_automapped |
|---|---|---|---|---|---|---|
| name+unit+values | 590 | 570 | 428 | 96.6% | 72.5% | 75.1% |
| name | 441 | 292 | 177 | 66.2% | 40.1% | 60.6% |
| name+values | 138 | 136 | 107 | 98.6% | 77.5% | 78.7% |
| name+unit |  40 |  39 |  30 | 97.5% | 75.0% | 76.9% |

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

