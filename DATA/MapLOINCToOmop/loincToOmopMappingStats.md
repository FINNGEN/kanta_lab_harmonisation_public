# LOINC -> OMOP Mapping -- Stats

Source: `DATA/MapLOINCToOmop/codesWithOMOP.tsv`

## Overview

Each local code carries the OMOP concept `FixLOINCDimensions` chose for it
from a shortlist that a semantic search over the LOINC vocabulary returned for
the name `FindLOINCDimensions` guessed. This step only resolves that id
against the vocabulary — there is no tuple join to succeed or fail, so
"unmapped" here means the model declined every candidate, not that a join
missed.

| bucket | n | pct |
|---|---|---|
| total | 1984 | 100.0% |
| named by FindLOINCDimensions | 1890 | 95.3% |
| left unnamed |   94 | 4.7% |

Of the rows a mapping was attempted for:

| bucket | n | pct |
|---|---|---|
| attempted (a name was guessed) | 1890 | 100.0% |
| mapped to an OMOP concept | 1559 | 82.5% |
| unmapped (no candidate was right) |  331 | 17.5% |
| distinct concepts used |  601 |  |

## By domain (the chosen concept's `has_system`)

Which specimens the mapped codes ended up in, most common first. Unmapped
rows are grouped together: this approach never infers a system of its own, so
an unmapped row has no specimen to be counted under.

| omop_has_system | n_rows | pct_of_rows |
|---|---|---|
| Serum or Plasma | 547 | 27.6% |
| (unmapped) | 423 | 21.3% |
| Blood | 181 | 9.1% |
| Urine | 160 | 8.1% |
| XXX | 104 | 5.2% |
| Serum | 100 | 5.0% |
| Serum, Plasma or Blood |  51 | 2.6% |
| Respiratory system specimen |  39 | 2.0% |
| Blood or Tissue |  38 | 1.9% |
| Red Blood Cells |  33 | 1.7% |
| Stool |  31 | 1.6% |
| Heart |  27 | 1.4% |
| Upper respiratory specimen |  24 | 1.2% |
| Platelet poor plasma |  21 | 1.1% |
| Blood capillary |  19 | 1.0% |
| Urine sediment |  19 | 1.0% |
| Cerebral spinal fluid |  18 | 0.9% |
| Respiratory system |  18 | 0.9% |
| Throat |  14 | 0.7% |
| Blood venous |  11 | 0.6% |
| Semen |   9 | 0.5% |
| Plasma |   7 | 0.4% |
| Pleural fluid |   7 | 0.4% |
| Bone marrow |   6 | 0.3% |
| Isolate |   6 | 0.3% |
| Blood arterial |   5 | 0.3% |
| Nose |   4 | 0.2% |
| Reticulocytes |   4 | 0.2% |
| Specimen |   4 | 0.2% |
| Vaginal |   4 | 0.2% |
| ^Patient |   4 | 0.2% |
| Body fluid |   3 | 0.2% |
| Bronchoalveolar lavage |   3 | 0.2% |
| Interstitial fluid |   3 | 0.2% |
| Pharynx |   3 | 0.2% |
| Respiratory system airway |   3 | 0.2% |
| Tissue and Smears |   3 | 0.2% |
| Blood^BPU |   2 | 0.1% |
| Dialysis fluid |   2 | 0.1% |
| Hematopoietic progenitor cells^BPU |   2 | 0.1% |
| Plasma arterial |   2 | 0.1% |
| Plasma cell-free DNA |   2 | 0.1% |
| Skeletal system |   2 | 0.1% |
| Abscess |   1 | 0.1% |
| Aspirate |   1 | 0.1% |
| Blood central venous |   1 | 0.1% |
| Blood cord |   1 | 0.1% |
| Bone |   1 | 0.1% |
| Cardiac echo study |   1 | 0.1% |
| Cardiac stress study |   1 | 0.1% |
| Catheter tip |   1 | 0.1% |
| Dialysis fluid peritoneal |   1 | 0.1% |
| Eye |   1 | 0.1% |
| Nasopharynx |   1 | 0.1% |
| Peritoneal fluid |   1 | 0.1% |
| Pus |   1 | 0.1% |
| Sputum |   1 | 0.1% |
| Synovial fluid |   1 | 0.1% |
| ^BPU |   1 | 0.1% |

## Cross-check against the reference mapping

`DATA/ReferenceMappings/lab_data_summary.csv` holds a separately curated Finnish-code -> OMOP mapping. Restricted to its `APPROVED` rows and matched to this table by `TEST_NAME`+`UNIT`, it is the only independent read on whether the concepts chosen here are the *right* ones.

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
  no OMOP id: `FixLOINCDimensions` judged no candidate defensible and left it
  empty on purpose. For a code with no unit and no values that is the intended
  answer, not a failure.
- **disagreement** — the pipeline produced an id and the reference has a
  different one.
- **agreement** — the pipeline produced the same id as the reference.


| outcome | n | pct_of_all | pct_of_in_reference |
|---|---|---|---|
| not in reference | 1220 | 61.5% |  |
| not automapped |   71 | 3.6% | 9.3% |
| disagreement |  239 | 12.0% | 31.3% |
| agreement |  454 | 22.9% | 59.4% |

Agreement over the whole overlap: **454 / 764 = 59.4%**. Restricted to rows that carry real evidence (a unit, values, or both): **353 / 500 = 70.6%**.

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
| UNCHECKED | 849 | 574 (67.6%) | 786,229 |
| NOT-FOUND | 243 | 202 (83.1%) | 116,974 |
| (no row at all) |  93 | 77 (82.8%) | 42,625 |
| IGNORED |  35 | 20 (57.1%) | 144,424 |

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
| < 100 | 388 | 114 (29.4%) | 80.7% | 56 (49.1%) |
| 100 - 499 | 772 | 183 (23.7%) | 89.6% | 120 (65.6%) |
| 500 - 4,999 | 589 | 269 (45.7%) | 92.9% | 154 (57.2%) |
| 5,000 - 49,999 | 171 | 136 (79.5%) | 92.6% | 81 (59.6%) |
| >= 50,000 |  64 | 62 (96.9%) | 98.4% | 43 (69.4%) |

**Restricted to codes with >= 500 records — the range the reference actually covers: 278 / 467 = 59.5%** (63.6% of the 437 it automapped).

### By evidence level

What the local row actually carried. The reference gives
more than one concept across a code's units for only ~6% of multi-unit codes,
so it is in practice a `TEST_NAME` -> concept mapping, while this pipeline maps
`(TEST_NAME, UNIT)`. A `name`-only row has nothing that fixes its quantity, so
`FixLOINCDimensions` takes a concept there only when the name alone settles it
and declines otherwise — which is why those rows both answer less often and
agree less often, and why they are reported apart from the evidenced ones:

| evidence_level | n_rows | n_automapped | n_agreement | pct_automapped | pct_agree_of_rows | pct_agree_of_automapped |
|---|---|---|---|---|---|---|
| name+unit+values | 348 | 342 | 240 | 98.3% | 69.0% | 70.2% |
| name | 264 | 203 | 101 | 76.9% | 38.3% | 49.8% |
| name+values | 115 | 113 |  85 | 98.3% | 73.9% | 75.2% |
| name+unit |  37 |  35 |  28 | 94.6% | 75.7% | 80.0% |

### Examples — disagreement

Five of the rows where the pipeline produced an id and the reference has a
different one, sampled from the *distinct* (our concept, reference concept)
pairs so one recurring disagreement cannot fill the table. `reasoning` is what
`FixLOINCDimensions` gave for that choice, clause by clause — so the mistake
can be read rather than guessed at.

*128 distinct disagreement rows; 5 shown:*

| TEST_NAME | UNIT | evidence | certainty | loinc_name_guess | our_omop_concept_name | reference_OMOP_CONCEPT_NAME | reasoning |
|---|---|---|---|---|---|---|---|
| pt-sper-2 |  | name | medium | Semen analysis panel - Semen | Semen analysis panel | Semen analysis, post vasectomy | component: Semen analysis bcs LongName is 'Pt-Siemennestetutkimus, laaja' (Semen analysis, extensive) and TEST_NAME has `sper` ; property: panel bcs `Pt-` indicates a patient-level investigation, typically an orderable panel; the general panel is chosen as no 'extensive' variant is available |
| u-alb-o | estimate | name+unit+values | high | Albumin [Presence] in Urine | Albumin [Presence] in Urine | Albumin [Presence] in Urine by Test strip | Albumin bcs 'Albumiini' in LongName ; [Presence] bcs '-O' suffix and '(kval)' in LongName indicate a qualitative test ; in Urine bcs 'U-' prefix means Urine ; method not specified |
| s-maksa-1 | u/l | name+unit+values | medium | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | Alkaline phosphatase.liver 1 [Enzymatic activity/volume] in Serum or Plasma | Alanine aminotransferase bcs `s-maksa-1` is a local code for a primary liver enzyme, conventionally ALT ; [Enzymatic activity/volume] bcs unit `u/l` ; in Serum or Plasma bcs prefix `S-` |
| kudostransglutaminaasi,iga-vasta-aineet |  | name | medium | Transglutaminase IgA Ab [Units/volume] in Serum or Plasma | Tissue transglutaminase IgA Ab [Units/volume] in Serum by Immunoassay | Tissue transglutaminase IgA Ab [Units/volume] in Serum | Tissue transglutaminase IgA Ab bcs name `kudostransglutaminaasi,iga-vasta-aineet` ; [Units/volume] bcs this is the standard property for this test, as seen in sibling rows with units ; in Serum bcs this is the default specimen ; by Immunoassay bcs this is the standard method and the concept is a top-2000 preferred target. |
| se-amyl | u/l | name+unit+values | medium | Amylase [Enzymatic activity/volume] in Secretion | Amylase [Enzymatic activity/volume] in Body fluid | Amylase [Enzymatic activity/volume] in Specimen | Amylase from 'amyl' ; [Enzymatic activity/volume] bcs unit 'u/l' and deciles ; in Body fluid bcs this is a reasonable general mapping for prefix 'Se-' (Secretion). |


### Examples — not automapped

Five of the rows the reference maps but the pipeline left empty. An empty
`loinc_name_guess` means `FindLOINCDimensions` could not name the test at all;
a filled one means the search returned nothing the model would accept.


*65 distinct not automapped rows; 5 shown:*

| TEST_NAME | UNIT | evidence | certainty | loinc_name_guess | our_omop_concept_name | reference_OMOP_CONCEPT_NAME | reasoning |
|---|---|---|---|---|---|---|---|
| u-alb-lb |  | name |  | Albumin [Mass/volume] in Urine |  | Albumin [Mass/volume] in Urine | The code 'u-alb-lb' indicates albumin in urine, but with no unit or values, the property (e.g., mass concentration, presence) cannot be determined. |
| u-pi |  | name |  | Phosphate in Urine |  | Phosphate [Moles/volume] in Urine | The test is Phosphate in Urine, but there is no UNIT or deciles to determine the property (e.g., Moles/volume vs Mass/volume), so no concept can be chosen. |
| li-mypnabm |  | name |  | Mycoplasma pneumoniae IgM Ab [Presence] in Cerebral spinal fluid |  | Mycoplasma pneumoniae IgM Ab [Titer] in Cerebral spinal fluid | The code `li-mypnabm` is for Mycoplasma pneumoniae IgM antibodies in cerebrospinal fluid, reported qualitatively. The candidate list does not contain a `[Presence]` concept for these specific antibodies in CSF. |
| bm-bcr-qr |  | name |  | BCR gene/ABL1 gene fusion transcript [# Ratio] in Bone marrow by NAA |  | t(9;22)(q34.1;q11)(ABL1,BCR) e1a2 fusion transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | The code `bm-bcr-qr` specifies a quantitative ratio of the BCR-ABL1 fusion transcript in bone marrow. No suitable candidate for a general (non-log, non-transcript-specific) ratio in bone marrow was found in the list. |
| b-pvktkdr |  | name |  | CBC with automated differential and reticulocyte panel - Blood |  | Short blood count panel - Blood | No mapping chosen because the test `b-pvktkdr` (CBC with auto differential and reticulocytes) corresponds to a LOINC panel concept (e.g., 57782-5) that is not present in the candidate list. |

