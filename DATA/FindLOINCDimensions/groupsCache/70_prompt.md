[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of how LOINC names its terms.

Your task: for each row of the table given below, work out what the test actually measures and then **write the LOINC Long Common Name that this test would have**, as LOINC itself would spell it.

You are not asked to return the LOINC axes. You are asked to return the one name they compose into. Work the axes out in your head — component, property, time, system, scale, method — and then assemble them into the name.

Your answer is used as a **search query against the real LOINC vocabulary**. So write it the way LOINC writes names, not the way a person would describe a test. The closer your phrasing is to real LOINC phrasing, the better the search finds the concept you mean. A later step shows you the real concepts the search returned and asks you to choose among them; your job here is only to aim the search well.

# The Finnish laboratory coding system

Each national lab test has a 4-digit running number code and a short mnemonic abbreviation of at most 10 characters, built as:

    <system prefix> - <test abbreviation> [<suffix>]

- The **system prefix** is a 1-2 letter code for the specimen / system the sample was taken from, mostly derived from English words: `S` = serum, `P` = plasma, `B` = blood, `U` = urine, `Li` = cerebrospinal fluid, `F` = feces, `Ts` = tissue, `Pt` = patient (a whole-patient investigation, not a specimen), `fS`/`fP`/`fB` = fasting serum/plasma/blood, `dU` = 24-hour urine, `cU` = collected urine, `E` = erythrocyte, `L` = leukocyte, `Sy` = synovial fluid, and so on.
- The **test abbreviation** is a mnemonic of the test's long Finnish name (occasionally an established international abbreviation instead, e.g. `CEA`, `TSH`, `CRP`).
- The optional **suffix** (takaliite) qualifies the result type or method, attached directly or after a hyphen. The most important is `-O`, used for ALL qualitative and semi-quantitative tests. Others include `-Ab` (antibodies), `-Ag` (antigen), `-Vi` (culture, viljely), `-Vr` (staining), `-Nh` (nucleic acid), `-D` (DNA test), `-Ion` (ionized), `-V` (free/unconjugated), `-Fr` (fractions), `-Ind` (index), `-R` (exercise / functional test), `-Ps`/`-Ss` (screening), `-Ty` (typing), `-Tc` (transcutaneous), `-M` (lying down), `-P` (upright).

Finnish long names are largely descriptive; note that Finnish compound words run together, e.g. "transferriininrautakyllästeisyys" = transferrin iron saturation.

# The table columns

The group is given as a markdown table. Each row is one observed local lab test/unit combination:

- `row_id` — a unique integer identifying the row. **Echo it back exactly**; it is the only key used to join your answer to the table.
- `TEST_NAME` — the local test code, lowercased with spaces removed. Normally the Finnish abbreviation described above, but see the caveats below.
- `UNIT` — the measurement unit as recorded locally (e.g. `mmol/l`, `g/l`, `%`, `U/l`, `E9/l`). May be empty.
- `n` — how many result records exist for this test/unit combination.
- `p_missing` — percentage (0-100) of those records with no numeric value. A high `p_missing` together with an empty `UNIT` suggests a non-quantitative (qualitative / narrative) test.
- `deciles` — the 9 deciles of the observed numeric values, when available. The strongest single piece of evidence about what a test really measures and in what property: a "sodium" code whose deciles read 0.32-0.40 is not measuring sodium in mmol/l.
- `LongName` — the official Finnish long name from the national code table, when the code could be matched. Often empty.
- `prefix_meaning` — the decoded system prefix (e.g. "Serum", "Fasting plasma", "Urine"), when recognised. Derived from the code text, so a strong but not infallible hint.
- `suffix_meaning` — the decoded suffix (e.g. "Qualitative test (also semi-quantitative)", "Antibodies", "Culture"), when recognised.

# Important caveats about this data

- These codes are collected from MANY different Finnish healthcare source systems over decades. They are **not** clean national codes: they may be locally invented, abbreviated differently, truncated, concatenated with several alternative spellings separated by commas, contain typos, or be a bare number that was never resolved to an abbreviation.
- Columns are frequently empty. An empty column means "unknown", never "not applicable".
- **When you cannot tell what the test measures, return an empty name.** An empty name is a correct and useful answer. A plausible-sounding invention is worse than nothing: it sends the search after a concept the code never meant, and downstream code cannot tell a guess from a fact.
- The rows have been **grouped by string similarity** of `TEST_NAME`, so that near-identical codes appear together. Use the group as context: sibling rows often disambiguate a truncated or misspelled code, and reveal whether two similar codes are genuinely the same test or deliberately different (e.g. differing specimen, fasting state, or unit). Do not assume all rows in a group are the same test.

# How LOINC builds a Long Common Name

Almost every LOINC lab term's Long Common Name follows one template:

    <Component> [<Property>] in <System> by <Method>

Read as: *what was measured*, *in what kind of quantity*, *in what specimen*, *by what method*. For example:

| Long Common Name | Component | Property | System | Method |
|---|---|---|---|---|
| `Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture` | Streptococcus.beta-hemolytic | Presence or Threshold | Throat | Organism specific culture |
| `Creatinine [Moles/volume] in Serum or Plasma` | Creatinine | Substance Concentration | Serum or Plasma | *(none)* |
| `Hemoglobin [Mass/volume] in Blood` | Hemoglobin | Mass Concentration | Blood | *(none)* |
| `Glucose [Presence] in Urine by Test strip` | Glucose | Presence or Threshold | Urine | Test strip |
| `Bacteria identified in Urine by Culture` | Bacteria | Presence or Identity | Urine | Culture |
| `Calcium [Moles/time] in 24 hour Urine` | Calcium | Substance Rate | 24 hour Urine | *(none)* |

The rules that make a name come out right:

1. **The component comes first**, in LOINC's own English spelling. LOINC uses `.` to attach a qualifier to a component (`Streptococcus.beta-hemolytic`, `Hemoglobin A1c/Hemoglobin.total`, `Protein.total`) and `/` to express a ratio or a fraction of a whole (`Lymphocytes/Leukocytes`).
2. **The property goes in square brackets**, written in LOINC's *display* form — which is NOT the OMOP attribute name. Use this table:

   | write this | means |
   |---|---|
   | `[Moles/volume]` | substance concentration — `mol/l`, `mmol/l`, `umol/l`, `nmol/l`, `pmol/l` |
   | `[Mass/volume]` | mass concentration — `g/l`, `mg/l`, `ug/l` |
   | `[Units/volume]` | arbitrary/international units per volume — `U/ml`, `IU/ml`, `kU/l` |
   | `[#/volume]` | a count per volume — `E9/l`, `E12/l`, `E6/l` |
   | `[Presence]` | qualitative detected / not detected |
   | `[Enzymatic activity/volume]` | enzyme activity — `U/l` |
   | `[Titer]` | a titer |
   | `[Identifier]` | which organism / variant was identified |
   | `[Mass/time]`, `[Moles/time]` | an amount excreted per time, e.g. in a 24-hour urine collection |
   | `[Volume Fraction]`, `[Mass Ratio]`, `[Ratio]`, `[Molar ratio]`, `[# Ratio]` | fractions and ratios |
   | `[Entitic mass]`, `[Entitic mean volume]`, `[Entitic Mass/volume]` | per-cell red-cell indices — MCH, MCV, MCHC |
   | `[Volume Rate/Area]` | a body-surface-normalised rate, e.g. eGFR |
   | `[Partial pressure]` | blood gases — `kPa`, `mmHg` |
   | `[Susceptibility]` | antimicrobial susceptibility |
   | `[Interpretation]` | an interpretive impression of a study |

   Choose the property from the **`UNIT` and the magnitude of the `deciles`**, never from the analyte name: the same analyte is a different LOINC term in `mmol/l` and in `mg/l`.
3. **The system follows `in`**: `in Serum or Plasma`, `in Blood`, `in Urine`, `in Cerebral spinal fluid`, `in Stool`, `in Red Blood Cells`. LOINC uses the combined `Serum or Plasma` for most routine chemistry; take the narrow `Serum` or `Plasma` only when the test is genuinely specific to one. Fasting is NOT part of the system — `fS` is still serum.
4. **The timing is folded into the system slot** when it is not a plain spot sample: `in 24 hour Urine`, `in 2 hour Urine`. A normal point-in-time sample is LOINC's default and is written nowhere in the name — do not add "point in time".
5. **The method follows `by`, and only when it changes the clinical interpretation**: `by Automated count`, `by Test strip`, `by Culture`, `by Organism specific culture`, `by Immunoassay`, `by NAA with probe detection`, `by Electrophoresis`, `by calculation`. LOINC deliberately omits Method for most chemistry. **Leave it off unless the code states one.** Inventing a method makes the search miss the plain term that was the right answer.
6. **The scale is not written as a word.** It shows in the shape of the name: a quantitative test carries its property in brackets; an ordinal/qualitative one is `[Presence]`; a nominal identification drops the brackets entirely and reads `Bacteria identified in Urine by Culture`. A fraction of a cell population also drops the brackets: `Lymphocytes/Leukocytes in Blood`.
7. **Panels** are named as panels, with the system after a dash: `CBC panel - Blood by Automated count`, `Urinalysis macro (dipstick) panel - Urine`, `Short blood count panel - Blood`. If the code orders a bundle rather than reporting one result, write a panel name.

There are exceptions to the template — some names put a body site first (`Left ventricular Ejection fraction by US.2D`), some append a challenge after a double dash (`Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose`) — but if you follow the template above you will be right for the overwhelming majority of laboratory tests, which is what this data is.

# The names Finland actually uses

These are the LOINC concepts the curated Finnish mappings already use, ordered by how many records they cover. They are real, current LOINC names — use them as your model for spelling and shape, and when a row plainly IS one of these tests, reuse that exact name.

| LOINC Long Common Name | n_codes | n_events |
|---|---|---|
| Hematocrit [Volume Fraction] of Blood by calculation |  29 | 11,407,235 |
| Hemoglobin [Mass/volume] in Blood |  57 | 11,265,093 |
| Leukocytes [#/volume] in Blood |  53 | 11,205,325 |
| Platelets [#/volume] in Blood |  19 | 11,196,211 |
| Erythrocytes [#/volume] in Blood |  14 | 11,175,264 |
| MCV [Entitic mean volume] in Red Blood Cells |  18 | 11,148,804 |
| MCH [Entitic mass] |  15 | 11,139,123 |
| Creatinine [Moles/volume] in Serum or Plasma |  51 |  9,024,989 |
| Potassium [Moles/volume] in Serum or Plasma |  45 |  7,908,182 |
| Sodium [Moles/volume] in Serum or Plasma |  52 |  7,821,326 |
| MCHC [Entitic Mass/volume] in Red Blood Cells |  16 |  7,331,654 |
| Erythrocyte [DistWidth] in Red Blood Cells |  20 |  7,004,505 |
| C reactive protein [Mass/volume] in Serum or Plasma | 159 |  6,802,841 |
| CBC panel - Blood by Automated count |   5 |  6,172,064 |
| Glomerular filtration rate [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (CKD-EPI)/1.73 sq M |  62 |  6,143,658 |
| Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma |  21 |  5,367,314 |
| INR in Blood by Coagulation assay |  88 |  2,812,069 |
| Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |  13 |  2,756,532 |
| Neutrophils [#/volume] in Blood by Automated count |   4 |  2,514,044 |
| Hemoglobin A1c/Hemoglobin.total in Blood |  88 |  2,419,123 |
| Cholesterol in LDL [Moles/volume] in Serum or Plasma |  47 |  2,347,979 |
| Normoblasts [#/volume] in Blood |  22 |  2,299,398 |
| Thyrotropin [Units/volume] in Serum or Plasma |  44 |  2,173,821 |
| Cholesterol [Moles/volume] in Serum or Plasma |  31 |  2,073,556 |
| Cholesterol in HDL [Moles/volume] in Serum or Plasma |  41 |  2,024,003 |
| Fasting glucose [Moles/volume] in Serum or Plasma |  42 |  1,996,657 |
| Triglyceride [Moles/volume] in Serum or Plasma --fasting |  17 |  1,655,520 |
| Eosinophils [#/volume] in Blood |  35 |  1,618,391 |
| Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Serum or Plasma |  66 |  1,612,576 |
| Lymphocytes [#/volume] in Blood |  38 |  1,557,180 |
| Thyroxine (T4) free [Moles/volume] in Serum or Plasma |  24 |  1,537,005 |
| Basophils [#/volume] in Blood |  26 |  1,519,691 |
| Monocytes [#/volume] in Blood |  29 |  1,513,142 |
| Bilirubin.total [Moles/volume] in Serum or Plasma |  12 |  1,506,859 |
| Lymphocytes/Leukocytes in Blood |  65 |  1,465,459 |
| Monocytes/Leukocytes in Blood |  48 |  1,451,788 |
| Basophils/Leukocytes in Blood |  48 |  1,446,628 |
| Eosinophils/Leukocytes in Blood |  42 |  1,429,973 |
| Erythrocyte sedimentation rate [Velocity] in Red Blood Cells by Westergren method |   6 |  1,423,371 |
| Neutrophils/Leukocytes in Blood |  55 |  1,410,042 |
| Urinalysis macro (dipstick) panel - Urine |   6 |  1,393,084 |
| Bacteria [#/volume] in Urine by Automated count |  12 |  1,358,321 |
| Glucose [Moles/volume] in Serum or Plasma |  53 |  1,339,897 |
| Calcium.ionized [Moles/volume] in Serum or Plasma |  74 |  1,333,722 |
| 12 lead EKG panel |   2 |  1,163,408 |
| Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma |  17 |  1,024,731 |
| Differential panel, method unspecified - Blood |   2 |  1,020,069 |
| Albumin [Mass/volume] in Serum or Plasma |  21 |  1,016,464 |
| SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with probe detection |   2 |    961,920 |
| Glucose [Presence] in Urine by Test strip |  10 |    946,600 |
| Ketones [Presence] in Urine by Test strip |  11 |    933,706 |
| Nitrite [Presence] in Urine by Test strip |  10 |    919,087 |
| Short blood count panel - Blood |   8 |    872,285 |
| Ferritin [Mass/volume] in Serum or Plasma |  13 |    725,861 |
| Leukocyte esterase [Presence] in Urine by Automated test strip |   3 |    687,408 |
| Leukocytes [#/volume] in Urine |  20 |    676,308 |
| Prostate specific Ag [Mass/volume] in Serum or Plasma |  39 |    674,775 |
| pH of Urine |  11 |    668,794 |
| Troponin T.cardiac [Mass/volume] in Serum or Plasma |  60 |    599,869 |
| Blood group antibody screen [Presence] in Serum or Plasma |   2 |    590,172 |
| Albumin/Creatinine [Ratio] in Urine |  31 |    588,386 |
| pH of Serum or Plasma |  19 |    570,372 |
| Urinalysis microscopic panel [#/volume] - Urine by Automated count |   3 |    557,289 |
| Albumin [Presence] in Urine by Test strip |  10 |    532,964 |
| Creatinine [Moles/volume] in Urine |  22 |    532,449 |
| Lipid panel - Serum or Plasma |   4 |    529,561 |
| Bacteria identified in Blood by Culture |   3 |    528,769 |
| Calcium [Moles/volume] in Serum or Plasma |  20 |    520,967 |
| Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma |  14 |    513,305 |
| 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma |  26 |    509,150 |
| EKG study |  10 |    506,024 |
| Erythrocytes [#/volume] in Urine |  12 |    500,225 |
| CBC W Ordered Manual Differential panel - Blood |   3 |    490,892 |
| Albumin [Mass/volume] in Urine |  15 |    484,794 |
| Prothrombin time (PT) actual/Normal |  17 |    484,673 |
| Chloride [Moles/volume] in Serum or Plasma |  10 |    457,594 |
| Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma |  47 |    441,698 |
| Erythrocytes [Presence] in Urine by Automated |   3 |    431,124 |
| Specific gravity of Urine by Refractometry |  16 |    426,435 |
| Bacteria identified in Urine by Culture |   3 |    420,379 |
| Casts [#/volume] in Urine by Automated count |  20 |    419,520 |
| Hemoglobin [Presence] in Urine by Test strip |   5 |    413,345 |
| pH of Arterial blood |   8 |    406,844 |
| Carbon dioxide [Partial pressure] in Arterial blood |   3 |    405,582 |
| Oxygen [Partial pressure] in Arterial blood |   3 |    404,986 |
| Holo-transcobalamin II [Moles/volume] in Serum |   7 |    404,765 |
| Base excess in Arterial blood by calculation |   5 |    400,371 |
| Amylase [Enzymatic activity/volume] in Serum or Plasma |  14 |    391,242 |
| Bacteria [Presence] in Urine |   2 |    390,903 |
| Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma |  57 |    390,599 |
| Protein [Presence] in Urine by Test strip |   3 |    382,676 |
| Phosphate [Moles/volume] in Serum or Plasma |   9 |    377,182 |
| Oxygen saturation in Arterial blood |  10 |    377,099 |
| Tissue Pathology biopsy report |   9 |    373,531 |
| Gas panel - Venous blood |   5 |    371,862 |
| Hemoglobin [Mass/volume] in Arterial blood |   9 |    371,451 |
| Blood type and Crossmatch panel - Blood |   1 |    354,396 |
| Triglyceride [Moles/volume] in Serum or Plasma |  26 |    343,761 |
| Sodium and Potassium panel [Moles/volume] - Serum or Plasma |   2 |    328,037 |
| Lactate [Moles/volume] in Serum or Plasma |  10 |    326,511 |

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `loinc_name_guess` — the Long Common Name you believe this code maps to, spelled as LOINC would. Empty if you cannot tell what the test measures.
- `is_panel` — `true` if the code orders a **panel**: a bundle of several separately reported component tests (e.g. `B-PVK` = full blood count, `U-KemSeul` = urine dipstick screen). `false` for a single reportable result.

Return an entry for EVERY row of the table, including rows you can say almost nothing about.

Additionally, return a short `reflection` (a few sentences to a short paragraph, markdown) covering: ideas to improve this process, gotchas and ambiguities you hit in THIS group, systematic problems in the data, and anything that would have helped you decide. Be concrete and specific to the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 70 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 5451 | -calpro | mg/l | 368 | 0 | [0.1, 0.31, 0.88, 2.86, 7.72, 16.73, 36.68, 74.3, 206.67] |  |  |  |
| 5452 | -calpro | ug/g | 37 | 0 |  |  |  |  |
| 5453 | -calpro |  | 23 | 21.74 |  |  |  |  |
| 5454 | 4184sk-padihot |  | 107 | 100 |  |  |  |  |
| 5455 | b-karyot |  | 686 | 100 |  |  | Blood |  |
| 5456 | b-malarv |  | 127 | 100 |  |  | Blood |  |
| 5457 | b-nakkrea |  | 424 | 100 |  |  | Blood |  |
| 5458 | b-pakk-e |  | 249 | 100 |  |  | Blood |  |
| 5459 | b-vara |  | 254 | 100 |  |  | Blood |  |
| 5460 | b-varaspr |  | 331 | 99.7 |  |  | Blood |  |
| 5461 | b.parapert |  | 619 | 100 |  |  |  |  |
| 5462 | du-parprot |  | 369 | 100 |  |  | 24-hour urine |  |
| 5463 | f-calpro | ug/g | 144892 | 0.48 | [13.78, 23.28, 35.55, 53.95, 82, 128.24, 215.34, 397.8, 911.98] | F -Kalprotektiini; F -Calprotectin | Feces |  |
| 5464 | f-calpro |  | 17874 | 100 | [23.61, 33.46, 47.58, 74.67, 119.83, 157.1, 290.01, 478.43, 993.36] | F -Kalprotektiini; F -Calprotectin | Feces |  |
| 5465 | f-calpro2 | ug/g | 395 | 0 | [28.88, 40.5, 54.65, 82.87, 126.54, 220.92, 330.47, 583.74, 1304.77] |  | Feces |  |
| 5466 | f-calpro2 |  | 97 | 100 |  |  | Feces |  |
| 5467 | fs-bkarot | nmol/l | 18 | 0 |  | fS-Beetakaroteeni | Fasting serum |  |
| 5468 | fs-bkarot | umol/l | 318 | 0 | [0.25, 0.45, 0.6, 0.75, 0.87, 1.06, 1.29, 1.57, 2.19] | fS-Beetakaroteeni | Fasting serum |  |
| 5469 | fs-sappih | umol/l | 5416 | 0.04 | [1.58, 2, 2.4, 3, 3.74, 4.45, 5.67, 7.59, 13.61] |  | Fasting serum |  |
| 5470 | fs-sappih |  | 686 | 100 | [2, 2.48, 3.02, 3.91, 4.81, 5.88, 6.86, 8.3, 12.54] |  | Fasting serum |  |
| 5471 | fs-sappihapot | umol/l | 198 | 0 | [1.41, 1.79, 2.06, 2.5, 3.2, 3.97, 4.98, 6.66, 11.59] |  | Fasting serum |  |
| 5472 | fs-sappihapot |  | 30 | 100 |  |  | Fasting serum |  |
| 5473 | li-kardab | titre | 7 | 14.29 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  |
| 5474 | li-kardab |  | 204 | 100 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  |
| 5475 | li-varlikv |  | 111 | 100 |  |  | Cerebrospinal fluid |  |
| 5476 | p-kardabg | gpl | 1101 | 6.99 | [1, 1, 1.61, 2, 2, 3, 5.05, 7.62, 12.35] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  |
| 5477 | p-kardabg | u/ml | 4443 | 0 | [1, 1, 1.08, 2, 2, 2.64, 3.48, 5.89, 13.12] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  |
| 5478 | p-kardabg |  | 4985 | 95.25 | [1, 1.14, 2, 2, 3.36, 5, 5.97, 9.03, 19.8] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  |
| 5479 | p-kardabm | mpl | 1111 | 5.04 | [1, 2, 2, 2.88, 3, 4.6, 7.59, 12.86, 20.09] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  |
| 5480 | p-kardabm | u/ml | 11 | 0 |  | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  |
| 5481 | p-kardabm |  | 724 | 89.09 | [1, 1, 1.45, 2, 2, 3, 4, 6, 15] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  |
| 5482 | p-pakk-si |  | 260 | 100 |  |  | Plasma |  |
| 5483 | p-varainr |  | 8332 | 99.99 |  |  | Plasma |  |
| 5484 | p-varmtr | s | 1488 | 0 | [17.02, 18, 18.87, 19, 19.98, 20, 21, 21.93, 23] |  | Plasma |  |
| 5485 | p-varmtr |  | 111 | 100 |  |  | Plasma |  |
| 5486 | p-varmtt | % | 1494 | 0 | [41.91, 74.69, 84.09, 92.24, 98.54, 104.26, 111.28, 119.13, 131.18] |  | Plasma |  |
| 5487 | p-varmtt |  | 105 | 100 |  |  | Plasma |  |
| 5488 | s-afmakro | u/l | 2842 | 0 | [3.98, 5.01, 6.23, 7.94, 10.06, 14.01, 21.13, 33.22, 62.9] |  | Serum |  |
| 5489 | s-afmakro |  | 523 | 59.85 | [4, 5, 6, 7.5, 10, 15.29, 22.33, 30.86, 49.44] |  | Serum |  |
| 5490 | s-afmaks1 | u/l | 199 | 0 | [25.36, 33.2, 41.05, 48.96, 56.78, 64.23, 71.62, 84.6, 112.64] |  | Serum |  |
| 5491 | s-afmaks1 |  | 13 | 0 |  |  | Serum |  |
| 5492 | s-afmaks2 | u/l | 205 | 0 | [3.2, 4.72, 5.48, 6.4, 7, 8.07, 11.08, 16.5, 34.56] |  | Serum |  |
| 5493 | s-afmaks2 |  | 7 | 14.29 |  |  | Serum |  |
| 5494 | s-afmaksa | % | 94 | 0 | [39.9, 51.85, 57.9, 64.48, 69.3, 73.65, 78.41, 84.08, 89.4] |  | Serum |  |
| 5495 | s-afmaksa | u/l | 2958 | 0 | [25.04, 37.52, 47.03, 56.68, 67.64, 79.81, 95.37, 125.6, 201.78] |  | Serum |  |
| 5496 | s-afmaksa |  | 489 | 65.03 | [32.9, 45.51, 57.63, 71.86, 79.96, 85.36, 96.57, 123.73, 246.45] |  | Serum |  |
| 5497 | s-caspähe | u/ml | 895 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.04, 0.13, 1.71] |  | Serum |  |
| 5498 | s-caspähe |  | 106 | 80.19 |  |  | Serum |  |
| 5499 | s-haspähe | u/ml | 683 | 0.15 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  |
| 5500 | s-haspähe |  | 162 | 73.46 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  |
| 5501 | s-hasspäe | u/ml | 476 | 1.05 | [0, 0.01, 0.03, 0.29, 1.1, 3.4, 6.79, 13.75, 30.06] |  | Serum |  |
| 5502 | s-hasspäe |  | 72 | 54.17 |  |  | Serum |  |
| 5503 | s-karba | umol/l | 3476 | 0.06 | [18.5, 22.32, 25.2, 27.69, 29.91, 32.56, 35.34, 38.81, 44.25] | S -Karbamatsepiini | Serum |  |
| 5504 | s-karba |  | 1101 | 59.49 | [18.42, 22.33, 25.59, 27.84, 29.91, 31.7, 34.15, 37.84, 41.83] | S -Karbamatsepiini | Serum |  |
| 5505 | s-karbae | umol/l | 88 | 0 |  | S -Karbamatsepiiniepoksidi | Serum |  |
| 5506 | s-karbae |  | 21 | 100 |  | S -Karbamatsepiiniepoksidi | Serum |  |
| 5507 | s-kardab | titre | 1640 | 0 | [0, 1, 1.58, 2, 2.38, 4, 8.71, 19.26, 62.28] | S -Kardiolipiini, vasta-aineet | Serum |  |
| 5508 | s-kardab |  | 14614 | 99.49 |  | S -Kardiolipiini, vasta-aineet | Serum |  |
| 5509 | s-kardabg | gpl | 222 | 29.28 | [6, 7, 8, 9, 11, 14.4, 18.14, 24.7, 40.7] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  |
| 5510 | s-kardabg | u/ml | 83 | 0 | [1, 1, 2, 2, 2.25, 3, 4, 7.3, 23] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  |
| 5511 | s-kardabg |  | 1591 | 94.97 | [1, 2, 2, 4.55, 7, 8, 9, 11, 27] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  |
| 5512 | s-kardabm | mpl | 359 | 18.11 | [10, 11.36, 12, 13.78, 15, 17.69, 23.08, 30.86, 52.98] | S -Kardiolipiini, IgM-vasta-aineet | Serum |  |
| 5513 | s-kardabm |  | 1672 | 96.29 |  | S -Kardiolipiini, IgM-vasta-aineet | Serum |  |
| 5514 | s-karni | umol/l | 328 | 0 | [17.78, 24.87, 29.09, 33.28, 36.28, 39.87, 43.86, 49.4, 55.76] | S -Karnitiini | Serum |  |
| 5515 | s-karni |  | 16 | 100 |  | S -Karnitiini | Serum |  |
| 5516 | s-karni-v | umol/l | 342 | 0 | [11.86, 16.35, 19.2, 22.24, 25.07, 27.94, 30.82, 35, 41.74] | S -Karnitiini, vapaa | Serum | Free or unconjugated |
| 5517 | s-karni-v |  | 7 | 85.71 |  | S -Karnitiini, vapaa | Serum | Free or unconjugated |
| 5518 | s-koopähe | u/ml | 83 | 0 | [0.02, 0.02, 0.03, 0.04, 0.06, 0.11, 0.2, 0.31, 0.85] | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  |
| 5519 | s-koopähe |  | 65 | 78.46 |  | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  |
| 5520 | s-leppäe | u/ml | 196 | 0.51 | [0, 0.01, 0.01, 0.02, 0.06, 0.22, 0.9, 2.7, 6.69] | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  |
| 5521 | s-leppäe |  | 167 | 86.23 |  | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  |
| 5522 | s-maapähe | u/ml | 1974 | 0.81 | [0.01, 0.02, 0.05, 0.1, 0.19, 0.37, 0.71, 1.55, 5.76] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  |
| 5523 | s-maapähe |  | 2541 | 94.14 | [0.04, 0.11, 0.15, 0.24, 0.38, 0.57, 1.12, 1.88, 3.68] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  |
| 5524 | s-maksa |  | 108 | 100 |  |  | Serum |  |
| 5525 | s-maksa-1 | u/l | 115 | 0 | [31.15, 42.45, 51.29, 60.72, 65.7, 69.64, 79.3, 87.8, 100.66] |  | Serum |  |
| 5526 | s-maksa-1 |  | 6 | 16.67 |  |  | Serum |  |
| 5527 | s-maksa-2 | u/l | 110 | 0 | [3.95, 4.95, 5.9, 6.88, 7.37, 8.14, 9.54, 13.38, 18.4] |  | Serum |  |
| 5528 | s-maksa-2 |  | 12 | 8.33 |  |  | Serum |  |
| 5529 | s-maksa1 | u/l | 134 | 0 | [36.7, 43.4, 53.05, 58.95, 67.89, 79.32, 89.06, 98.11, 147.2] |  | Serum |  |
| 5530 | s-maksa1 |  | 9 | 66.67 |  |  | Serum |  |
| 5531 | s-maksa2 | u/l | 132 | 0 | [4, 5, 6, 7.35, 9, 10.85, 14.35, 21.6, 43.05] |  | Serum |  |
| 5532 | s-maksa2 |  | 11 | 81.82 |  |  | Serum |  |
| 5533 | s-maksaab |  | 1108 | 100 |  |  | Serum |  |
| 5534 | s-maksap |  | 147 | 100 |  |  | Serum |  |
| 5535 | s-makspak |  | 778 | 100 |  |  | Serum |  |
| 5536 | s-ohkarba | umol/l | 4080 | 0.02 | [27.1, 35.97, 41.95, 47.99, 54.61, 61.42, 68.9, 80.34, 98.86] | S -Hydroksikarbatsepiini (10-) | Serum |  |
| 5537 | s-ohkarba |  | 797 | 53.58 | [25.02, 33.78, 40.6, 47.36, 53.64, 59.31, 68.63, 83.49, 103.17] | S -Hydroksikarbatsepiini (10-) | Serum |  |
| 5538 | s-okarba | umol/l | 163 | 10.43 | [0.4, 0.4, 0.8, 0.8, 0.8, 1, 1.2, 2, 2.28] | S -Okskarbatsepiini | Serum |  |
| 5539 | s-okarba |  | 168 | 92.26 |  | S -Okskarbatsepiini | Serum |  |
| 5540 | s-ovarab | titre | 22 | 9.09 |  | S -Munasarja, vasta-aineet | Serum |  |
| 5541 | s-ovarab |  | 250 | 99.2 |  | S -Munasarja, vasta-aineet | Serum |  |
| 5542 | s-pakast5 |  | 880 | 100 |  |  | Serum |  |
| 5543 | s-pakast7 |  | 106 | 100 |  |  | Serum |  |
| 5544 | s-pakaste |  | 345 | 100 |  |  | Serum |  |
| 5545 | s-pakkas |  | 1423 | 100 |  |  | Serum |  |
| 5546 | s-pakkase |  | 262 | 100 |  |  | Serum |  |
| 5547 | s-pakkask |  | 1061 | 100 |  |  | Serum |  |
| 5548 | s-pakkasl |  | 919 | 100 |  |  | Serum |  |
| 5549 | s-pakkasn |  | 563 | 100 |  |  | Serum |  |
| 5550 | s-pakkasv |  | 357 | 100 |  |  | Serum |  |
| 5551 | s-papp-a | mu/l | 533 | 0 | [227.4, 357.69, 452.41, 562.07, 709.24, 895.85, 1154.59, 1409.1, 2163.11] |  | Serum |  |
| 5552 | s-papp-a |  | 338 | 2.37 | [167.71, 318.34, 452.63, 572.23, 702.5, 894.09, 1122.57, 1356.65, 1789.1] |  | Serum |  |
| 5553 | s-pappa | form | 136 | 0 | [318.92, 443.67, 549.54, 657.05, 734.74, 894.71, 1259.38, 1647.76, 2113.41] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  |
| 5554 | s-pappa | mu/l | 41976 | 0 | [274.01, 424.82, 564.51, 708.65, 861.85, 1046.47, 1281.47, 1624.11, 2236.83] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  |
| 5555 | s-pappa |  | 357 | 100 | [254.51, 396.2, 527.37, 666.3, 821.3, 1003.01, 1225.19, 1551.35, 2139.86] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  |
| 5556 | s-pappmom | mom | 461 | 0 | [0.48, 0.64, 0.76, 0.89, 1.03, 1.22, 1.42, 1.67, 2.13] |  | Serum |  |
| 5557 | s-parapäe | u/ml | 829 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.02, 0.06, 0.35] |  | Serum |  |
| 5558 | s-parapäe |  | 34 | 61.76 |  |  | Serum |  |
| 5559 | s-paras | umol/l | 2680 | 3.1 | [16.09, 27.95, 44.46, 65.68, 102.63, 158.13, 258.09, 473.45, 862.14] | S -Parasetamoli | Serum |  |
| 5560 | s-paras |  | 2490 | 99.24 |  | S -Parasetamoli | Serum |  |
| 5561 | s-paroab |  | 212 | 100 |  | S -Sikotautivirus, vasta-aineet | Serum |  |
| 5562 | s-paroabg | au/ml | 72 | 0 | [14.1, 32.2, 47.68, 60.86, 78.93, 100.49, 117, 176, 216] | S -Sikotautivirus, IgG-vasta-aineet | Serum |  |
| 5563 | s-paroabg | titre | 45 | 0 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  |
| 5564 | s-paroabg |  | 172 | 91.86 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  |
| 5565 | s-paroabm |  | 197 | 98.98 |  | S -Sikotautivirus, IgM-vasta-aineet | Serum |  |
| 5566 | s-parprot |  | 1578 | 100 |  |  | Serum |  |
| 5567 | s-parpäh | u/ml | 67 | 0 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  |
| 5568 | s-parpäh |  | 184 | 96.2 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  |
| 5569 | s-parvab |  | 3096 | 100 |  | S -Parvovirus, vasta-aineet | Serum |  |
| 5570 | s-parvabg | eiu | 67 | 0 | [10, 35, 50, 61, 71.88, 80.25, 90, 90, 100] | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5571 | s-parvabg | ie/ml | 5 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5572 | s-parvabg | index | 250 | 0 | [10.1, 15.96, 22.67, 26.36, 30.21, 33.04, 36.98, 39.69, 42.76] | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5573 | s-parvabg | iu/ml | 57 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5574 | s-parvabg | titre | 558 | 0 | [200, 400, 800, 800, 800, 1555.56, 1600, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5575 | s-parvabg |  | 2056 | 91.73 | [4.91, 11.45, 38.67, 122.23, 400, 800, 800, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5576 | s-parvabm |  | 2965 | 99.46 |  | S -Parvovirus, IgM-vasta-aineet | Serum |  |
| 5577 | s-parvavi | % | 13 | 0 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  |
| 5578 | s-parvavi |  | 600 | 95.33 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  |
| 5579 | s-pekpähe | u/ml | 31 | 0 |  |  | Serum |  |
| 5580 | s-pekpähe |  | 77 | 96.1 |  |  | Serum |  |
| 5581 | s-sakspäe | u/ml | 883 | 0 | [0, 0, 0, 0.01, 0.01, 0.03, 0.07, 0.21, 1.55] |  | Serum |  |
| 5582 | s-sakspäe |  | 95 | 74.74 |  |  | Serum |  |
| 5583 | s-sappih | umol/l | 9172 | 0.36 | [2, 2.87, 3.49, 4.45, 5.83, 7.59, 10.65, 16.77, 32.84] | S -Sappihapot | Serum |  |
| 5584 | s-sappih |  | 1955 | 50.33 | [2, 3, 3, 4, 4.4, 5.33, 7.05, 9.69, 18.19] | S -Sappihapot | Serum |  |
| 5585 | s-valpr | % | 33 | 0 |  | S -Valproaatti | Serum |  |
| 5586 | s-valpr | umol/l | 35853 | 0.05 | [220.39, 285.23, 332.16, 372.59, 408.92, 446.56, 486.81, 533.22, 600.78] | S -Valproaatti | Serum |  |
| 5587 | s-valpr |  | 1583 | 100 | [195.88, 257.11, 300.41, 340.81, 382.77, 422.91, 465.76, 516.34, 588.53] | S -Valproaatti | Serum |  |
| 5588 | s-valpr-v | umol/l | 818 | 0 | [25.49, 29.94, 35.24, 39.88, 44.93, 50.41, 57.45, 67.85, 86.45] | S -Valproaatti, vapaa | Serum | Free or unconjugated |
| 5589 | s-valpr-v |  | 221 | 80.54 |  | S -Valproaatti, vapaa | Serum | Free or unconjugated |
| 5590 | s-valpro | umol/l | 171 | 0 |  |  | Serum |  |
| 5591 | s-valpro |  | 5 | 100 |  |  | Serum |  |
| 5592 | s-vara |  | 340 | 100 |  |  | Serum |  |
| 5593 | s-varah |  | 253 | 100 |  |  | Serum |  |
| 5594 | sappihapot | umol/l | 161 | 0 |  |  |  |  |
| 5595 | sappihapot |  | 14 | 100 |  |  |  |  |
| 5596 | sk-padihot |  | 24730 | 100 |  | Sk-Ihottumanäytteen histologinen tutkimus | Skin |  |
| 5597 | tupakka | u/24h | 599 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 8.55] |  |  |  |
| 5598 | tupakka |  | 104 | 100 |  |  |  |  |
| 5599 | u-gluprot |  | 2097 | 100 |  |  | Urine |  |
| 5600 | u-partik |  | 14759 | 100 |  |  | Urine |  |
| 5601 | u-partikk |  | 5466 | 100 |  |  | Urine |  |
| 5602 | u-rakkoai | h | 373 | 0 | [2.84, 4, 4, 4.03, 5, 6, 6.66, 7.87, 8.33] |  | Urine |  |
| 5603 | u-rakkoai |  | 5 | 100 |  |  | Urine |  |
| 5604 | u-sakka |  | 2736 | 100 |  |  | Urine |  |
| 5605 | u-valvott |  | 1125 | 100 |  |  | Urine |  |
| 5606 | u-varabak |  | 206 | 100 |  |  | Urine |  |

