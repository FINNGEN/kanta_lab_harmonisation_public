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
Here is group 51 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 3431 | -adenag |  | 1964 | 100 |  | -Adenovirus, antigeeni |  |  |
| 3432 | -bokaag |  | 187 | 100 |  |  |  |  |
| 3433 | -coinrsv |  | 2490 | 100 |  |  |  |  |
| 3434 | -inabrsv |  | 19142 | 100 |  |  |  |  |
| 3435 | -infaag |  | 10730 | 100 |  | -Influenssa A -virus, antigeeni |  |  |
| 3436 | -infabag |  | 15107 | 100 |  | -Influenssa A ja B -virus, antigeeni |  |  |
| 3437 | -infabnh |  | 961 | 100 |  |  |  |  |
| 3438 | -infah03 |  | 227 | 100 |  |  |  |  |
| 3439 | -infah09 |  | 488 | 100 |  |  |  |  |
| 3440 | -infah1 |  | 480 | 100 |  |  |  |  |
| 3441 | -infah3 |  | 261 | 100 |  |  |  |  |
| 3442 | -infavt |  | 1271 | 100 |  |  |  |  |
| 3443 | -infbag |  | 10722 | 100 |  | -Influenssa B -virus, antigeeni |  |  |
| 3444 | -infbvt |  | 1271 | 100 |  |  |  |  |
| 3445 | -infl.a |  | 220 | 100 |  |  |  |  |
| 3446 | -infl.b |  | 220 | 100 |  |  |  |  |
| 3447 | -infrpak |  | 1338 | 100 |  |  |  |  |
| 3448 | -infrsv |  | 162 | 100 |  |  |  |  |
| 3449 | -ivf-et |  | 194 | 100 |  |  |  | Special technique |
| 3450 | -koroag |  | 625 | 100 |  |  |  |  |
| 3451 | -metpnag |  | 370 | 100 |  |  |  |  |
| 3452 | -pin1ag |  | 1146 | 100 |  | -Parainfluenssa 1 -virus, antigeeni |  |  |
| 3453 | -pin2ag |  | 1147 | 100 |  | -Parainfluenssa 2 -virus, antigeeni |  |  |
| 3454 | -pin3ag |  | 1147 | 100 |  | -Parainfluenssa 3 -virus, antigeeni |  |  |
| 3455 | -pinf1ag |  | 235 | 100 |  |  |  |  |
| 3456 | -pinf2ag |  | 235 | 100 |  |  |  |  |
| 3457 | -pinf3ag |  | 235 | 100 |  |  |  |  |
| 3458 | -pnjiag |  | 188 | 100 |  | -Pneumocystis jirovecii, antigeeni |  |  |
| 3459 | -rvirag |  | 3025 | 100 |  | -Respiratoristen virusten antigeeni |  |  |
| 3460 | -stpnag |  | 4094 | 100 |  | -Streptococcus pneumoniae, antigeeni |  |  |
| 3461 | bi-inflamm |  | 311 | 100 |  |  | Bile |  |
| 3462 | f-adenag |  | 863 | 100 |  | F -Adenovirus, antigeeni | Feces |  |
| 3463 | f-giarag |  | 218 | 100 |  | F -Giardia, antigeeni | Feces |  |
| 3464 | f-gicrag |  | 163 | 99.39 |  |  | Feces |  |
| 3465 | f-noroag |  | 1048 | 100 |  |  | Feces |  |
| 3466 | f-rotaag |  | 886 | 100 |  | F -Rotavirus, antigeeni | Feces |  |
| 3467 | f-virag |  | 489 | 100 |  |  | Feces |  |
| 3468 | li-adenabg |  | 215 | 100 |  | Li-Adenovirus, IgG-vasta-aineet | Cerebrospinal fluid |  |
| 3469 | li-infaabg | eiu | 40 | 0 |  | Li-Influenssa A -virus, IgG-vasta-aineet | Cerebrospinal fluid |  |
| 3470 | li-infaabg |  | 240 | 100 |  | Li-Influenssa A -virus, IgG-vasta-aineet | Cerebrospinal fluid |  |
| 3471 | li-infbabg | eiu | 18 | 0 |  | Li-Influenssa B -virus, IgG-vasta-aineet | Cerebrospinal fluid |  |
| 3472 | li-infbabg |  | 258 | 100 |  | Li-Influenssa B -virus, IgG-vasta-aineet | Cerebrospinal fluid |  |
| 3473 | li-mypnab |  | 614 | 100 |  | Li-Mycoplasma pneumoniae, vasta-aineet | Cerebrospinal fluid |  |
| 3474 | li-mypnabg | eiu | 32 | 0 |  | Li-Mycoplasma pneumoniae, IgG-vasta-aineet | Cerebrospinal fluid |  |
| 3475 | li-mypnabg |  | 1292 | 100 |  | Li-Mycoplasma pneumoniae, IgG-vasta-aineet | Cerebrospinal fluid |  |
| 3476 | li-mypnabm |  | 1314 | 100 |  | Li-Mycoplasma pneumoniae, IgM-vasta-aineet | Cerebrospinal fluid |  |
| 3477 | li-pin1abg | eiu | 7 | 0 |  | Li-Parainfluenssa 1 -virus, IgG-vasta-aineet | Cerebrospinal fluid |  |
| 3478 | li-pin1abg |  | 161 | 100 |  | Li-Parainfluenssa 1 -virus, IgG-vasta-aineet | Cerebrospinal fluid |  |
| 3479 | ns-infab/r |  | 181 | 100 |  |  | Nasal secretion |  |
| 3480 | ps-adenag |  | 1955 | 100 |  | Ps-Adenovirus, antigeeni (NPS-näyte) | Pharyngeal secretion |  |
| 3481 | ps-infaag |  | 11885 | 100 |  |  | Pharyngeal secretion |  |
| 3482 | ps-infbag |  | 11881 | 100 |  |  | Pharyngeal secretion |  |
| 3483 | rvirag-o |  | 340 | 100 |  |  |  | Qualitative test (also semi-quantitative) |
| 3484 | s-adenabg | eiu | 240 | 0 | [29.8, 39.96, 46.52, 56.21, 66.99, 76.86, 88.44, 100.94, 123.7] | S -Adenovirus, IgG-vasta-aineet | Serum |  |
| 3485 | s-adenabg |  | 30 | 96.67 |  | S -Adenovirus, IgG-vasta-aineet | Serum |  |
| 3486 | s-infaabg | eiu | 288 | 0 | [44.84, 67.49, 80.03, 92.84, 100.98, 109.5, 120.03, 134.44, 150.75] | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  |
| 3487 | s-infaabg | u/ml | 31 | 0 |  | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  |
| 3488 | s-infaabg |  | 46 | 71.74 |  | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  |
| 3489 | s-infbab | eiu | 84 | 0 | [37, 45.5, 59.88, 67.83, 76.88, 87.5, 108.12, 125, 142] | S -Influenssa B -virus, vasta-aineet | Serum |  |
| 3490 | s-infbab | u/ml | 20 | 0 |  | S -Influenssa B -virus, vasta-aineet | Serum |  |
| 3491 | s-infbab |  | 20 | 100 |  | S -Influenssa B -virus, vasta-aineet | Serum |  |
| 3492 | s-infbabg | eiu | 202 | 0 | [27.36, 39.2, 49.01, 55.71, 69.1, 81.14, 95.12, 117.99, 145.85] | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  |
| 3493 | s-infbabg | u/ml | 5 | 0 |  | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  |
| 3494 | s-infbabg |  | 19 | 73.68 |  | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  |
| 3495 | s-infli | mg/l | 4337 | 0.09 | [2.45, 4.22, 5.77, 7.21, 8.78, 10.55, 12.36, 14.93, 19.68] | S -Infliksimabi | Serum |  |
| 3496 | s-infli | ug/l | 62 | 0 |  | S -Infliksimabi | Serum |  |
| 3497 | s-infli | âug/ml | 5 | 0 |  | S -Infliksimabi | Serum |  |
| 3498 | s-infli |  | 1486 | 32.77 | [2.05, 3.56, 5.06, 6.2, 7.59, 8.94, 10.97, 13.84, 18.03] | S -Infliksimabi | Serum |  |
| 3499 | s-infliab | au/ml | 413 | 0.73 | [6.57, 14.16, 21.28, 34.4, 52.11, 73.2, 118.89, 190.88, 374.2] | S -Infliksimabi, vasta-aineet | Serum |  |
| 3500 | s-infliab |  | 4455 | 99.89 |  | S -Infliksimabi, vasta-aineet | Serum |  |
| 3501 | s-infliks | mg/l | 951 | 0 | [1.81, 3, 4.49, 5.55, 6.66, 8.19, 10.34, 13.5, 19.13] |  | Serum |  |
| 3502 | s-infliks |  | 310 | 30.97 | [1.21, 2.24, 3.08, 4.32, 5.17, 6.19, 7.17, 7.95, 9.17] |  | Serum |  |
| 3503 | s-inflipa |  | 4630 | 100 |  |  | Serum |  |
| 3504 | s-micfaeg | mg/l | 45 | 0 |  |  | Serum |  |
| 3505 | s-micfaeg |  | 90 | 76.67 |  |  | Serum |  |
| 3506 | s-mypnab |  | 19694 | 99.92 |  | S -Mycoplasma pneumoniae, vasta-aineet | Serum |  |
| 3507 | s-mypnabg | au/ml | 2298 | 0 | [0.52, 1.18, 1.86, 2.68, 3.78, 5.69, 8.99, 16.54, 33.76] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  |
| 3508 | s-mypnabg | eiu | 9577 | 0 | [51.21, 64.99, 79.08, 95.09, 113.13, 134.88, 160.85, 200.43, 260.64] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  |
| 3509 | s-mypnabg | form | 53 | 0 |  | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  |
| 3510 | s-mypnabg | ru/ml | 384 | 0 | [19.56, 23.19, 26.12, 30.65, 34.99, 40.45, 50.94, 60.03, 79.86] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  |
| 3511 | s-mypnabg |  | 4994 | 100 | [0.53, 1.1, 1.73, 2.48, 3.76, 5.77, 9.79, 21.47, 68.82] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  |
| 3512 | s-mypnabm | form | 16 | 0 |  | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  |
| 3513 | s-mypnabm | index | 3618 | 0 | [1.53, 2.22, 2.83, 3.43, 4.2, 5.16, 6.56, 8.38, 11.18] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  |
| 3514 | s-mypnabm | s/co | 1089 | 0 | [0.1, 0.1, 0.2, 0.2, 0.3, 0.33, 0.47, 0.63, 1.13] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  |
| 3515 | s-mypnabm |  | 12775 | 100 | [1.19, 1.67, 2.14, 2.58, 3.04, 3.6, 4.51, 5.78, 8.21] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  |
| 3516 | s-pin1abg | eiu | 209 | 0 | [51.38, 65.97, 78.97, 87.7, 96.4, 106.81, 114.5, 126.75, 144.62] | S -Parainfluenssa 1 -virus, IgG-vasta-aineet | Serum |  |
| 3517 | s-pin1abg |  | 9 | 88.89 |  | S -Parainfluenssa 1 -virus, IgG-vasta-aineet | Serum |  |
| 3518 | s-scc-ag | ug/l | 959 | 0 | [0.88, 1.03, 1.2, 1.38, 1.6, 2.01, 2.55, 3.56, 6.69] | S -Squamous cell carsinoma, antigeeni | Serum | Antigen |
| 3519 | s-scc-ag |  | 493 | 95.94 |  | S -Squamous cell carsinoma, antigeeni | Serum | Antigen |
| 3520 | u-lepnag |  | 3943 | 100 |  | U -Legionella pneumophila, antigeeni | Urine |  |
| 3521 | u-pneuag |  | 2058 | 100 |  |  | Urine |  |
| 3522 | u-stpnag |  | 2546 | 100 |  | U -Streptococcus pneumoniae, antigeeni | Urine |  |

