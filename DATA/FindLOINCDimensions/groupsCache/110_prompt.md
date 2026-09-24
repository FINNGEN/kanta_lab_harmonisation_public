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
Here is group 110 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 8999 | b-b-cd19 | e6/l | 913 | 0 | [10.41, 31.05, 55.36, 87.14, 120.42, 155.29, 201.58, 263.7, 407.08] |  | Blood |  |
| 9000 | b-b-cd19 | e9/l | 3083 | 0 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.29, 0.48] |  | Blood |  |
| 9001 | b-b-cd19 |  | 569 | 89.28 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.31, 0.47] |  | Blood |  |
| 9002 | b-cd16/56 | e6/l | 12 | 0 |  |  | Blood |  |
| 9003 | b-cd16/56 | e9/l | 2606 | 0.65 | [0.06, 0.09, 0.12, 0.15, 0.18, 0.22, 0.26, 0.33, 0.44] |  | Blood |  |
| 9004 | b-cd16/56 |  | 108 | 84.26 |  |  | Blood |  |
| 9005 | b-cd16/cd56 | e9/l | 263 | 0 | [0.09, 0.12, 0.15, 0.17, 0.21, 0.24, 0.3, 0.36, 0.44] |  | Blood |  |
| 9006 | b-cd16/cd56 |  | 15 | 100 |  |  | Blood |  |
| 9007 | b-cd19 | e6/l | 3891 | 0 | [0, 1.97, 16.17, 41.05, 70.27, 108.04, 158.42, 221.57, 336.97] |  | Blood |  |
| 9008 | b-cd19 | e9/l | 2870 | 0.59 | [0, 0, 0.01, 0.03, 0.06, 0.09, 0.14, 0.19, 0.29] |  | Blood |  |
| 9009 | b-cd19 |  | 175 | 66.29 |  |  | Blood |  |
| 9010 | b-cd3 | e6/l | 3892 | 0 |  |  | Blood |  |
| 9011 | b-cd3 | e9/l | 2868 | 0.59 |  |  | Blood |  |
| 9012 | b-cd3 |  | 204 | 71.57 |  |  | Blood |  |
| 9013 | b-cd34 | e6/l | 193 | 0 | [5.27, 13.75, 20.31, 28.86, 37.69, 50.47, 63.07, 93.98, 156.93] |  | Blood |  |
| 9014 | b-cd34 |  | 27 | 29.63 |  |  | Blood |  |
| 9015 | b-cd4 | e6/l | 3893 | 0 | [134.07, 213.38, 284.14, 381.8, 505.45, 647.7, 819.98, 1038.04, 1335.05] |  | Blood |  |
| 9016 | b-cd4 | e9/l | 2870 | 0.59 | [0.14, 0.2, 0.25, 0.32, 0.4, 0.51, 0.63, 0.8, 1.07] |  | Blood |  |
| 9017 | b-cd4 |  | 172 | 66.28 |  |  | Blood |  |
| 9018 | b-cd8 | e6/l | 3892 | 0 | [117.75, 200.41, 277.17, 351.98, 433.16, 541.85, 672.5, 850.74, 1214.03] |  | Blood |  |
| 9019 | b-cd8 | e9/l | 2870 | 0.59 | [0.11, 0.16, 0.23, 0.29, 0.36, 0.46, 0.57, 0.73, 1] |  | Blood |  |
| 9020 | b-cd8 |  | 172 | 66.28 |  |  | Blood |  |
| 9021 | b-lcd34 | e6/l | 251 | 0 | [3, 7.11, 11.11, 14.14, 17.55, 23.82, 31.86, 44, 64.2] | B -Leukosyytit, CD34 alaluokka | Blood |  |
| 9022 | b-lcd34 | e9/l | 475 | 0 | [0, 0.01, 0.02, 0.03, 0.03, 0.04, 0.06, 0.09, 0.13] | B -Leukosyytit, CD34 alaluokka | Blood |  |
| 9023 | b-lcd34 |  | 66 | 100 |  | B -Leukosyytit, CD34 alaluokka | Blood |  |
| 9024 | b-lycd4 |  | 496 | 100 |  | B -Lymfosyytti CD4-alaluokka | Blood |  |
| 9025 | b-t-cd3 | e6/l | 1174 | 0 |  |  | Blood |  |
| 9026 | b-t-cd3 | e9/l | 2692 | 0 |  |  | Blood |  |
| 9027 | b-t-cd3 |  | 304 | 81.91 |  |  | Blood |  |
| 9028 | b-t-cd4 | e6/l | 1609 | 0 | [168.06, 247.56, 335.09, 433.05, 551.26, 672.04, 816.88, 957.34, 1254.62] |  | Blood |  |
| 9029 | b-t-cd4 | e9/l | 6105 | 0 | [0.16, 0.25, 0.34, 0.43, 0.52, 0.64, 0.79, 0.96, 1.28] |  | Blood |  |
| 9030 | b-t-cd4 |  | 475 | 69.89 | [0.2, 0.26, 0.34, 0.42, 0.55, 0.68, 0.8, 0.95, 1.29] |  | Blood |  |
| 9031 | b-t-cd8 | e6/l | 1174 | 0 | [141.94, 210.82, 289.62, 366.11, 450.98, 530.13, 639.55, 796.16, 1179.47] |  | Blood |  |
| 9032 | b-t-cd8 | e9/l | 2753 | 0 | [0.14, 0.21, 0.27, 0.35, 0.43, 0.52, 0.65, 0.83, 1.1] |  | Blood |  |
| 9033 | b-t-cd8 |  | 311 | 79.42 |  |  | Blood |  |
| 9034 | bl-cd4/cd8 | form | 42 | 100 |  |  | Bronchoalveolar lavage |  |
| 9035 | bl-cd4/cd8 |  | 91 | 100 |  |  | Bronchoalveolar lavage |  |
| 9036 | cd4/cd8 |  | 3940 | 0.23 | [0.29, 0.47, 0.68, 0.91, 1.2, 1.57, 1.94, 2.45, 3.26] |  |  |  |
| 9037 | l-cd34 | % | 481 | 0 | [0.05, 0.08, 0.1, 0.13, 0.16, 0.2, 0.25, 0.32, 0.61] |  | Leukocyte |  |
| 9038 | l-cd34 |  | 41 | 100 |  |  | Leukocyte |  |
| 9039 | la-cd34 | e6/kg | 156 | 0 | [0.6, 0.9, 1.18, 1.41, 1.69, 2.1, 2.53, 3.4, 4.94] |  |  |  |
| 9040 | la-cd34 | e9/l | 393 | 0 | [0.41, 0.56, 0.72, 0.84, 1.03, 1.27, 1.77, 2.36, 3.2] |  |  |  |
| 9041 | la-cd34-ks |  | 395 | 100 |  |  |  |  |
| 9042 | la-cd34-os | % | 393 | 0 | [0.22, 0.3, 0.39, 0.49, 0.59, 0.69, 0.84, 1.12, 1.67] |  |  |  |
| 9043 | la-t-cd3 | e9/l | 149 | 0 |  |  |  |  |
| 9044 | la-t-cd3 |  | 6 | 16.67 |  |  |  |  |
| 9045 | la-t-cd4 | e9/l | 149 | 0 |  |  |  |  |
| 9046 | la-t-cd4 |  | 6 | 16.67 |  |  |  |  |
| 9047 | la-t-cd8 | e9/l | 149 | 0 |  |  |  |  |
| 9048 | la-t-cd8 |  | 6 | 16.67 |  |  |  |  |
| 9049 | ly-b-cd19 | % | 1504 | 0 | [0, 0, 0.45, 2.91, 5.54, 7.86, 10.24, 13.34, 18.94] |  | Lymphocyte |  |
| 9050 | ly-b-cd19 |  | 950 | 99.05 |  |  | Lymphocyte |  |
| 9051 | ly-cd16/56 | % | 3462 | 0.49 | [5.28, 8.01, 10.25, 12.46, 15.08, 18.07, 21.55, 26.37, 33.4] |  | Lymphocyte |  |
| 9052 | ly-cd16/56 |  | 107 | 86.92 |  |  | Lymphocyte |  |
| 9053 | ly-cd16/cd56 | % | 262 | 0 | [5.52, 8.16, 10.06, 12.71, 14.93, 17.65, 20.63, 27.5, 36.58] |  | Lymphocyte |  |
| 9054 | ly-cd16/cd56 |  | 15 | 100 |  |  | Lymphocyte |  |
| 9055 | ly-cd19 | % | 3462 | 0.49 | [0, 0, 1.17, 3.24, 5.55, 8.08, 10.86, 14.11, 20.27] |  | Lymphocyte |  |
| 9056 | ly-cd19 |  | 107 | 85.98 |  |  | Lymphocyte |  |
| 9057 | ly-cd19-b | % | 2507 | 0 | [0, 0, 1, 3.95, 7.56, 10.5, 13.61, 17.58, 25.6] |  | Lymphocyte |  |
| 9058 | ly-cd19-b |  | 19 | 100 |  |  | Lymphocyte |  |
| 9059 | ly-cd3 | % | 3726 | 0.46 | [52.12, 61.25, 67.07, 71.15, 74.98, 78.39, 81.66, 85.36, 89.48] |  | Lymphocyte |  |
| 9060 | ly-cd3 |  | 122 | 87.7 |  |  | Lymphocyte |  |
| 9061 | ly-cd4 | % | 3726 | 0.46 | [16.32, 22.56, 27.91, 32.59, 37.02, 41.75, 46.47, 51.76, 58.99] |  | Lymphocyte |  |
| 9062 | ly-cd4 |  | 122 | 87.7 |  |  | Lymphocyte |  |
| 9063 | ly-cd4+8+ | % | 41 | 41.46 |  |  | Lymphocyte |  |
| 9064 | ly-cd4+8+ |  | 75 | 100 |  |  | Lymphocyte |  |
| 9065 | ly-cd4-8- | % | 207 | 8.21 | [7, 8, 8, 8.88, 9.82, 10.9, 12, 14, 16] |  | Lymphocyte |  |
| 9066 | ly-cd4-8- |  | 77 | 100 |  |  | Lymphocyte |  |
| 9067 | ly-cd4-t | % | 4576 | 0 | [15.23, 21.8, 27.31, 31.42, 35.47, 39.26, 43.26, 48.23, 54.7] |  | Lymphocyte |  |
| 9068 | ly-cd4-t |  | 170 | 22.94 | [17.53, 21.58, 24.78, 29.15, 33.2, 38.25, 41.67, 47.37, 52.57] |  | Lymphocyte |  |
| 9069 | ly-cd4/cd8 |  | 2752 | 4.18 | [0.37, 0.55, 0.75, 0.96, 1.18, 1.48, 1.83, 2.29, 3.23] | Ly-Auttaja- ja tappajasolujen suhde, immunofenotyypitys | Lymphocyte |  |
| 9070 | ly-cd4/cd8suhde |  | 278 | 5.4 | [0.5, 0.76, 1.02, 1.29, 1.66, 1.95, 2.26, 2.73, 3.97] |  | Lymphocyte |  |
| 9071 | ly-cd8 | % | 3725 | 0.46 | [14.46, 19.13, 22.75, 26.46, 30.35, 34.98, 40.06, 46.74, 56.02] |  | Lymphocyte |  |
| 9072 | ly-cd8 |  | 122 | 87.7 |  |  | Lymphocyte |  |
| 9073 | ly-t-cd3 | % | 3926 | 0 | [56.23, 64.92, 70.33, 74.35, 77.57, 80.54, 84.02, 87.72, 92.04] |  | Lymphocyte |  |
| 9074 | ly-t-cd3 |  | 264 | 98.48 |  |  | Lymphocyte |  |
| 9075 | ly-t-cd4 | % | 2006 | 0 | [18.72, 24.57, 29.84, 34.47, 38.67, 43.22, 47.75, 52.18, 58.04] | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  |
| 9076 | ly-t-cd4 |  | 3875 | 99.92 |  | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  |
| 9077 | ly-t-cd4. | % | 1462 | 0 | [18.57, 26.32, 32.42, 36.77, 41.27, 46.47, 51.47, 56.35, 63.05] |  | Lymphocyte |  |
| 9078 | ly-t-cd4. |  | 36 | 72.22 |  |  | Lymphocyte |  |
| 9079 | ly-t-cd4/8 | ratio | 1816 | 0 | [0.6, 0.8, 0.99, 1.23, 1.56, 1.85, 2.06, 2.47, 3.19] |  | Lymphocyte |  |
| 9080 | ly-t-cd4/8 |  | 224 | 100 | [0.48, 0.79, 1.06, 1.31, 1.55, 1.83, 2.13, 2.62, 3.69] |  | Lymphocyte |  |
| 9081 | ly-t-cd8 | % | 2895 | 0 | [14.95, 19.45, 23.24, 27.01, 30.29, 33.79, 38.05, 43.59, 52.29] | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  |
| 9082 | ly-t-cd8 |  | 245 | 99.59 |  | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  |
| 9083 | ly-tcd4/8. |  | 2179 | 0.83 | [0.48, 0.75, 1, 1.21, 1.42, 1.69, 2, 2.51, 3.27] |  | Lymphocyte |  |
| 9084 | ly-tt-cd8 | % | 1219 | 0 | [13.33, 17.86, 21.01, 24.35, 28, 31.32, 36.22, 42.56, 52.88] |  | Lymphocyte |  |
| 9085 | ly-tt-cd8 |  | 5 | 40 |  |  | Lymphocyte |  |
| 9086 | s-gt-cdt | % | 13 | 0 |  |  | Serum |  |
| 9087 | s-gt-cdt |  | 2807 | 3.35 | [2.6, 2.87, 3.04, 3.25, 3.47, 3.7, 3.96, 4.27, 4.86] |  | Serum |  |
| 9088 | so-t-cd3 | % | 149 | 0 | [16.66, 19.73, 21.87, 23.49, 24.84, 27.82, 29.85, 33.41, 49.51] |  |  |  |
| 9089 | so-t-cd3 |  | 6 | 16.67 |  |  |  |  |
| 9090 | so-t-cd4 | % | 149 | 0 | [9.42, 10.93, 12.3, 13.53, 14.67, 15.99, 17.4, 19.67, 23.42] |  |  |  |
| 9091 | so-t-cd4 |  | 6 | 16.67 |  |  |  |  |
| 9092 | so-t-cd8 | % | 149 | 0 | [5.87, 7, 7.83, 8.57, 9.8, 10.57, 12.18, 14.02, 21.4] |  |  |  |
| 9093 | so-t-cd8 |  | 6 | 16.67 |  |  |  |  |

