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
Here is group 42 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 2487 | ab-na | mmol/l | 1125 | 0 | [130.94, 134.84, 136.62, 138.04, 139.34, 140.42, 141.09, 142.57, 144.87] |  | Arterial blood | Native preparation |
| 2488 | ap-lakt | mmol/l | 1456 | 0 | [0.68, 0.81, 0.96, 1.1, 1.28, 1.5, 1.81, 2.29, 3.25] |  |  |  |
| 2489 | ap-lakt |  | 18 | 50 |  |  |  |  |
| 2490 | ap-na | % | 24 | 0 |  |  |  | Native preparation |
| 2491 | ap-na | g/l | 6 | 0 |  |  |  | Native preparation |
| 2492 | ap-na | kpa | 12 | 0 |  |  |  | Native preparation |
| 2493 | ap-na | mmol/l | 50270 | 0 | [130.71, 133.37, 134.96, 136, 136.98, 137.95, 138.88, 139.98, 141.72] |  |  | Native preparation |
| 2494 | ap-na | °c | 6 | 0 |  |  |  | Native preparation |
| 2495 | ap-na |  | 233 | 92.27 |  |  |  | Native preparation |
| 2496 | ap-nak |  | 155 | 100 |  |  |  |  |
| 2497 | b-na | mmol/l | 59360 | 0 | [132.76, 134.99, 136.51, 137.61, 138.41, 139.21, 140.23, 141.69, 144.08] |  | Blood | Native preparation |
| 2498 | b-na |  | 9740 | 95.39 | [132.18, 135.78, 137.16, 138.83, 139, 140, 140.41, 141, 142] |  | Blood | Native preparation |
| 2499 | cp-na | mmol/l | 305 | 0 | [132, 134.22, 135.76, 137, 138, 139.28, 140, 141.93, 143] |  |  | Native preparation |
| 2500 | cp-na |  | 18 | 100 |  |  |  | Native preparation |
| 2501 | di-na | mmol/l | 307 | 0 |  | Di-Natrium | Dialysis fluid | Native preparation |
| 2502 | di-na |  | 5 | 100 |  | Di-Natrium | Dialysis fluid | Native preparation |
| 2503 | du-na | mmol | 2785 | 0.25 | [76.79, 98.05, 115.16, 132.8, 151.88, 170.12, 193.55, 223.43, 273.21] | dU-Natrium | 24-hour urine | Native preparation |
| 2504 | du-na | mmol/24h | 60 | 0 |  | dU-Natrium | 24-hour urine | Native preparation |
| 2505 | du-na |  | 1021 | 70.23 | [65.53, 84.3, 103.25, 116.92, 139.24, 156.61, 172.58, 210.59, 273.58] | dU-Natrium | 24-hour urine | Native preparation |
| 2506 | fp-ctx | ng/l | 34 | 0 |  |  | Fasting plasma |  |
| 2507 | fp-ctx | ug/l | 1281 | 0 | [0.09, 0.14, 0.2, 0.25, 0.3, 0.38, 0.48, 0.6, 0.81] |  | Fasting plasma |  |
| 2508 | fp-ctx |  | 491 | 16.7 | [0.12, 0.19, 0.24, 0.31, 0.39, 0.48, 0.58, 0.71, 1] |  | Fasting plasma |  |
| 2509 | fp-gt | u/l | 772 | 0 | [15.6, 19.58, 23.9, 27.61, 33.27, 39.92, 49.93, 68.82, 104.64] |  | Fasting plasma |  |
| 2510 | fp-gt |  | 11 | 0 |  |  | Fasting plasma |  |
| 2511 | fp-na | mmol/l | 6047 | 0 | [135.6, 137.84, 139, 139.97, 140.01, 141, 141.04, 142, 143] |  | Fasting plasma | Native preparation |
| 2512 | fp-na |  | 18 | 11.11 |  |  | Fasting plasma | Native preparation |
| 2513 | p-acth | ng/l | 10045 | 0.42 | [8.08, 11.12, 14.1, 17.14, 20.58, 24.79, 30.92, 40.41, 66.95] | P -Adrenokortikotropiini | Plasma |  |
| 2514 | p-acth | pmol/l | 7 | 0 |  | P -Adrenokortikotropiini | Plasma |  |
| 2515 | p-acth |  | 1461 | 80.01 | [9.26, 12.21, 15.18, 18.04, 23.17, 27.09, 32.96, 40.36, 61.68] | P -Adrenokortikotropiini | Plasma |  |
| 2516 | p-at3 | % | 33387 | 0.01 | [54.15, 67.47, 77.12, 84.9, 91.44, 97.34, 103.31, 110.17, 119.77] | P -Antitrombiini III | Plasma |  |
| 2517 | p-at3 | form | 18 | 0 |  | P -Antitrombiini III | Plasma |  |
| 2518 | p-at3 |  | 750 | 50.4 | [77.41, 88.27, 92.93, 97.96, 101.75, 106.37, 110.41, 114.53, 119.94] | P -Antitrombiini III | Plasma |  |
| 2519 | p-at3. | % | 4852 | 0 | [82.58, 90.63, 95.72, 100.18, 103.97, 107.65, 111.95, 117.06, 124.39] |  | Plasma |  |
| 2520 | p-at3. |  | 269 | 20.45 | [87.63, 92.63, 97.23, 100.8, 104.86, 109.03, 113.28, 117.74, 123.49] |  | Plasma |  |
| 2521 | p-efa | form | 5 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  |
| 2522 | p-efa |  | 125 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  |
| 2523 | p-fakb | g/l | 120 | 0 | [0.14, 0.17, 0.18, 0.2, 0.21, 0.21, 0.23, 0.26, 0.3] | P -Faktori B | Plasma |  |
| 2524 | p-fakb |  | 35 | 25.71 |  | P -Faktori B | Plasma |  |
| 2525 | p-fe | umol/l | 2840 | 0 | [5.52, 7.66, 9.48, 11.25, 13.18, 14.87, 16.94, 19.46, 23.35] |  | Plasma |  |
| 2526 | p-fe |  | 740 | 33.92 | [5.15, 6.78, 8.55, 10.06, 12.18, 14.07, 16.43, 19.54, 23.49] |  | Plasma |  |
| 2527 | p-fs | s | 319 | 0 | [28, 29.31, 30.81, 32, 33.17, 35, 36.48, 39.22, 45.08] |  | Plasma |  |
| 2528 | p-fs |  | 1586 | 99.87 |  |  | Plasma |  |
| 2529 | p-fv | % | 6911 | 0.01 | [43.78, 58.4, 69.62, 80.37, 90.29, 99.93, 110.48, 122.94, 139.52] | P -Hyytymistekijä V | Plasma |  |
| 2530 | p-fv |  | 261 | 40.23 | [68.7, 79.64, 87.53, 94.6, 99.14, 104.6, 110.72, 119.21, 132.72] | P -Hyytymistekijä V | Plasma |  |
| 2531 | p-fx | % | 916 | 0.11 | [46.06, 65.75, 76.36, 83.72, 90.83, 97.78, 104.84, 112.37, 122.61] | P -Hyytymistekijä X | Plasma |  |
| 2532 | p-fx |  | 949 | 87.46 | [66, 76.45, 83.38, 90.43, 96, 100.47, 108.88, 114, 128] | P -Hyytymistekijä X | Plasma |  |
| 2533 | p-gt | mg/ml | 8 | 0 |  | P -Glutamyylitransferaasi | Plasma |  |
| 2534 | p-gt | u/l | 820178 | 0.02 | [14.56, 18.66, 23.05, 28.6, 36.08, 47.26, 65.76, 101.29, 195.48] | P -Glutamyylitransferaasi | Plasma |  |
| 2535 | p-gt |  | 15977 | 100 | [15.82, 20.13, 24.14, 29.03, 35.14, 45.13, 63.31, 89.78, 161.64] | P -Glutamyylitransferaasi | Plasma |  |
| 2536 | p-hstni | ng/l | 3261 | 0 | [1, 2, 3, 4.12, 6.04, 9.1, 14.48, 27.09, 65.46] |  | Plasma |  |
| 2537 | p-k+na |  | 69230 | 100 |  |  | Plasma |  |
| 2538 | p-k,na |  | 2518 | 100 |  |  | Plasma |  |
| 2539 | p-k-na | mmol/l | 594 | 100 |  |  | Plasma | Native preparation |
| 2540 | p-k-na |  | 186 | 100 |  |  | Plasma | Native preparation |
| 2541 | p-k-pa | mmol/l | 197 | 0 | [3.53, 3.78, 3.9, 4, 4.04, 4.13, 4.3, 4.38, 4.56] |  | Plasma | Long-term / prolonged |
| 2542 | p-k/na |  | 321 | 100 |  |  | Plasma |  |
| 2543 | p-ked. | mmol/l | 344 | 0 |  |  | Plasma |  |
| 2544 | p-kjd. | mmol/l | 160 | 0 |  |  | Plasma |  |
| 2545 | p-la1 | s | 1064 | 0 | [30, 31.95, 33.1, 34.81, 35.99, 37.75, 39.96, 44.96, 54.77] |  | Plasma |  |
| 2546 | p-la1 |  | 52 | 50 |  |  | Plasma |  |
| 2547 | p-la2 | s | 498 | 0 | [32, 33.41, 35.41, 36.98, 38.82, 40.9, 43.06, 47.24, 53.65] |  | Plasma |  |
| 2548 | p-la2 |  | 1411 | 99.43 |  |  | Plasma |  |
| 2549 | p-mypa | mg/l | 1692 | 0.06 | [0.64, 0.99, 1.33, 1.7, 2.12, 2.67, 3.43, 4.39, 6.28] | P -Mykofenolihappo | Plasma |  |
| 2550 | p-mypa |  | 245 | 76.33 |  | P -Mykofenolihappo | Plasma |  |
| 2551 | p-na | mmol/ | 14 | 0 |  | P -Natrium | Plasma | Native preparation |
| 2552 | p-na | mmol/l | 7320578 | 0.03 | [133.91, 136.27, 137.98, 138.99, 139.95, 140, 141, 142, 143] | P -Natrium | Plasma | Native preparation |
| 2553 | p-na |  | 81059 | 100 | [134.02, 137.07, 138.67, 139, 140, 141, 142, 142.8, 143] | P -Natrium | Plasma | Native preparation |
| 2554 | p-na. | mmol/l | 1467 | 0 | [134.64, 136.99, 138.3, 139.9, 140.54, 141, 142, 142.75, 144] |  | Plasma |  |
| 2555 | p-na: | mmol/l | 621 | 0 | [131.65, 133.8, 135, 136.23, 137.85, 138.61, 139.67, 140.88, 142] |  | Plasma |  |
| 2556 | p-naed. | mmol/l | 306 | 0 |  |  | Plasma |  |
| 2557 | p-najd. | mmol/l | 154 | 0 |  |  | Plasma |  |
| 2558 | p-nak |  | 259040 | 100 |  |  | Plasma |  |
| 2559 | p-nap | mmol/l | 342 | 0 | [132.69, 135.3, 137.47, 139, 140, 140.64, 142, 143, 145] |  | Plasma |  |
| 2560 | p-supar | ug/l | 351 | 0 | [2.87, 3.25, 3.63, 3.92, 4.33, 4.73, 5.27, 6.37, 8.21] |  | Plasma |  |
| 2561 | p-supar |  | 16 | 100 |  |  | Plasma |  |
| 2562 | p-t3-v | pmol/l | 82081 | 0.04 | [3.46, 3.84, 4.11, 4.35, 4.57, 4.81, 5.08, 5.46, 6.26] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated |
| 2563 | p-t3-v |  | 921 | 100 | [3.47, 3.87, 4.08, 4.31, 4.53, 4.77, 5.02, 5.39, 6.24] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated |
| 2564 | p-t4-v | pmol/l | 1108128 | 0.01 | [11.98, 13.02, 13.95, 14.63, 15.23, 16.03, 16.92, 17.94, 19.56] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated |
| 2565 | p-t4-v |  | 19446 | 100 | [12, 13.8, 14.44, 15.06, 16, 16.21, 16.99, 17.6, 19] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated |
| 2566 | p-t4v | pmol/l | 110881 | 0 | [12.73, 13.79, 14.57, 15.27, 15.96, 16.68, 17.48, 18.48, 19.99] |  | Plasma |  |
| 2567 | p-t4v |  | 4743 | 100 | [12.19, 13.39, 14.21, 14.93, 15.61, 16.33, 17.17, 18.29, 20.03] |  | Plasma |  |
| 2568 | p-tfr | mg/l | 188406 | 0.02 | [0.81, 1.28, 2.05, 2.5, 2.87, 3.3, 3.83, 4.64, 6.21] | P -Transferriinireseptori, liukoinen | Plasma |  |
| 2569 | p-tfr |  | 15951 | 100 | [2.12, 2.53, 2.87, 3.21, 3.63, 4.15, 4.81, 5.75, 7.59] | P -Transferriinireseptori, liukoinen | Plasma |  |
| 2570 | p-tni | ng/l | 220095 | 0 | [4, 5.13, 7.13, 10.22, 15.11, 24.46, 46.82, 122.37, 829.48] | P -Troponiini I | Plasma |  |
| 2571 | p-tni | ug/l | 25579 | 0 | [0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.08, 0.16, 0.78] | P -Troponiini I | Plasma |  |
| 2572 | p-tni |  | 70910 | 100 | [0.05, 0.22, 2.89, 4.65, 7.45, 12.28, 24.91, 48.92, 145.81] | P -Troponiini I | Plasma |  |
| 2573 | p-tni. | ng/l | 6 | 0 |  |  | Plasma |  |
| 2574 | p-tni. | ug/l | 155 | 0 | [0, 0, 0, 0, 0, 0, 0.01, 0.02, 0.06] |  | Plasma |  |
| 2575 | p-tni. |  | 28 | 100 |  |  | Plasma |  |
| 2576 | p-tnih | ng/l | 1974 | 0 | [4, 5.78, 7.89, 10.8, 16.52, 27.69, 54.92, 168.16, 1593.63] |  | Plasma |  |
| 2577 | p-tnih |  | 440 | 100 |  |  | Plasma |  |
| 2578 | p-tnl | ng/l | 124 | 0 | [3, 4, 5.16, 7, 10, 12.72, 29.97, 89.8, 240.6] |  | Plasma |  |
| 2579 | p-tnl | ug/l | 179 | 0 | [0, 0, 0, 0, 0, 0.01, 0.01, 0.02, 0.05] |  | Plasma |  |
| 2580 | p-tnl |  | 36 | 100 |  |  | Plasma |  |
| 2581 | p-tnt | ng/l | 437584 | 0.96 | [6.97, 9.13, 11.78, 15.03, 19.12, 24.8, 33.92, 51.22, 106.22] | P -Troponiini T | Plasma |  |
| 2582 | p-tnt | ug/l | 76 | 0 |  | P -Troponiini T | Plasma |  |
| 2583 | p-tnt |  | 80220 | 100 | [6.97, 8.93, 11.46, 14.61, 18.09, 22.79, 29.94, 42.37, 74.82] | P -Troponiini T | Plasma |  |
| 2584 | p-tt | % | 472003 | 0.01 | [50.44, 65.04, 74.28, 81.62, 88.26, 94.73, 101.62, 109.77, 121.26] | P -Tromboplastiiniaika | Plasma |  |
| 2585 | p-tt | form | 20 | 0 |  | P -Tromboplastiiniaika | Plasma |  |
| 2586 | p-tt |  | 4462 | 100 | [41.42, 56.72, 66.85, 77.09, 85.82, 93.79, 102.07, 112.01, 126.16] | P -Tromboplastiiniaika | Plasma |  |
| 2587 | p-tt- | % | 1432 | 0 | [60.12, 72.07, 78.16, 83.25, 88.78, 95.39, 102.35, 111.94, 122.43] |  | Plasma |  |
| 2588 | p-tt- |  | 29 | 96.55 |  |  | Plasma |  |
| 2589 | p-tt. | % | 5628 | 0 | [63.13, 78.7, 87.12, 93.57, 99.77, 105.67, 112.42, 119.67, 130.89] |  | Plasma |  |
| 2590 | p-tt. |  | 328 | 31.4 | [48, 79.63, 90.12, 98.65, 107.18, 114.33, 121.82, 130.4, 140] |  | Plasma |  |
| 2591 | p-ttr | % | 1114 | 0 | [50.89, 61.27, 67.88, 73.89, 78.52, 83.07, 89.29, 95.08, 100] |  | Plasma |  |
| 2592 | p-ttr |  | 89 | 89.89 |  |  | Plasma |  |
| 2593 | pdgfr |  | 461 | 100 |  |  |  |  |
| 2594 | peak | l/min | 12 | 0 |  |  |  |  |
| 2595 | peak |  | 104 | 100 |  |  |  |  |
| 2596 | pef-pa |  | 7844 | 99.92 |  | Uloshengityksen huippuvirtaus, sarjamittaus, pitkäaikaisseuranta |  | Long-term / prolonged |
| 2597 | pef-ras |  | 242 | 100 |  | Uloshengityksen huippuvirtaus, sarjamittaus, rasituskoe |  |  |
| 2598 | pf-ace | u/l | 313 | 3.19 | [6.4, 10.22, 12.78, 15.45, 17.82, 19.96, 24.1, 28.83, 37.4] | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  |
| 2599 | pf-ace |  | 161 | 98.14 |  | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  |
| 2600 | pf-ada | u/l | 3550 | 0.14 | [3.68, 5.14, 6.78, 8.01, 9.46, 11.17, 13.55, 17.33, 25.48] | Pf-Adenosiinideaminaasi | Pleural fluid |  |
| 2601 | pf-ada |  | 365 | 90.96 |  | Pf-Adenosiinideaminaasi | Pleural fluid |  |
| 2602 | pneag |  | 244 | 100 |  |  |  |  |
| 2603 | s-na | mmol/l | 124118 | 0 | [137.36, 138.84, 139.01, 140, 140.14, 141, 141.38, 142, 143] | S -Natrium | Serum | Native preparation |
| 2604 | s-na | mol/l | 5 | 0 |  | S -Natrium | Serum | Native preparation |
| 2605 | s-na |  | 931 | 67.35 | [137.2, 138, 139, 139, 140, 140, 141, 141, 142.37] | S -Natrium | Serum | Native preparation |
| 2606 | s-t3-v | pmol/l | 18657 | 0 | [3.72, 4.06, 4.3, 4.5, 4.69, 4.9, 5.13, 5.43, 6.06] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated |
| 2607 | s-t3-v |  | 1623 | 51.2 | [3.55, 3.8, 4.02, 4.22, 4.41, 4.6, 4.85, 5.16, 5.82] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated |
| 2608 | s-t4-v | pmol/l | 252259 | 0 | [11.09, 12, 12.88, 13.14, 13.97, 14.48, 15.15, 16.1, 17.48] | S -Tyroksiini, vapaa | Serum | Free or unconjugated |
| 2609 | s-t4-v |  | 9900 | 100 | [12.03, 12.98, 13.72, 14.35, 14.94, 15.68, 16.39, 17.25, 18.59] | S -Tyroksiini, vapaa | Serum | Free or unconjugated |
| 2610 | s-t4v | pmol/l | 1086 | 0 | [12.85, 13, 14, 14.52, 15, 15.93, 16, 17, 18] |  | Serum |  |
| 2611 | s-tfr | mg | 7 | 0 |  | S -Transferriinireseptori, liukoinen | Serum |  |
| 2612 | s-tfr | mg/l | 77760 | 0 | [1, 1.22, 1.5, 1.89, 2.35, 2.8, 3.34, 4.1, 5.59] | S -Transferriinireseptori, liukoinen | Serum |  |
| 2613 | s-tfr |  | 1379 | 100 | [1.84, 2.22, 2.62, 3.08, 3.57, 4.23, 5.1, 6.26, 8.15] | S -Transferriinireseptori, liukoinen | Serum |  |
| 2614 | s-tnf | ng/l | 100 | 0 | [4.65, 5.4, 6.33, 7.11, 7.81, 8.85, 10.5, 13.2, 23.25] | S -Tuumorinekroositekijä, alfa | Serum |  |
| 2615 | s-tnf |  | 50 | 74 |  | S -Tuumorinekroositekijä, alfa | Serum |  |
| 2616 | s-tni | ng/l | 63 | 0 | [2.98, 3.29, 4.36, 4.96, 6.38, 8.72, 14.54, 33, 54.53] | S -Troponiini I | Serum |  |
| 2617 | s-tni | ug/l | 11 | 0 |  | S -Troponiini I | Serum |  |
| 2618 | s-tni |  | 171 | 100 |  | S -Troponiini I | Serum |  |
| 2619 | s-tnt | ng/l | 149 | 0 | [40, 42, 45.21, 51.23, 64.69, 87.1, 139.39, 201.81, 358.2] | S -Troponiini T | Serum |  |
| 2620 | s-tnt |  | 7446 | 99.38 |  | S -Troponiini T | Serum |  |
| 2621 | s-tob | mg/l | 805 | 0.99 | [0.29, 0.5, 0.61, 0.8, 1.01, 1.26, 1.54, 1.91, 3.02] | S -Tobramysiini | Serum |  |
| 2622 | s-tob |  | 560 | 81.96 |  | S -Tobramysiini | Serum |  |
| 2623 | sp-pak |  | 196 | 100 |  |  | Sperm / semen |  |
| 2624 | sp-pakd |  | 138 | 100 |  |  | Sperm / semen |  |
| 2625 | u-na | mmol/l | 8969 | 1.33 | [24.74, 32.42, 40.4, 48.4, 57.53, 68.16, 81.75, 99.14, 129.68] | U -Natrium | Urine | Native preparation |
| 2626 | u-na |  | 2662 | 76.37 | [27.27, 35.54, 43.11, 51.43, 60.05, 68.34, 78.15, 92.47, 111.65] | U -Natrium | Urine | Native preparation |
| 2627 | v-na |  | 265 | 0.75 | [130.22, 134.26, 135.98, 137.59, 138.5, 139.03, 140, 141, 142] |  |  | Native preparation |
| 2628 | vp-na | mmol/l | 10896 | 0 | [132.84, 135.34, 136.96, 137.97, 138.99, 139.84, 140.33, 141.08, 142.49] |  |  | Native preparation |
| 2629 | vp-na |  | 174 | 98.28 |  |  |  | Native preparation |

