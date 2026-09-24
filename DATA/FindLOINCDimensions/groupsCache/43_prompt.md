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
Here is group 43 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 2630 | -ana | titre | 21 | 14.29 |  | -Tuma, vasta-aineet |  |  |
| 2631 | -ana |  | 169 | 100 |  | -Tuma, vasta-aineet |  |  |
| 2632 | am-epo | iu/l | 76 | 0 |  | Am-Erytropoietiini | Amniotic fluid |  |
| 2633 | am-epo | u/l | 267 | 0.75 | [2.67, 3.48, 4.24, 4.97, 5.92, 7.13, 8.38, 10.84, 21.7] | Am-Erytropoietiini | Amniotic fluid |  |
| 2634 | am-epo |  | 31 | 45.16 |  | Am-Erytropoietiini | Amniotic fluid |  |
| 2635 | b-adp | auc | 28 | 0 |  |  | Blood |  |
| 2636 | b-adp |  | 340 | 100 |  |  | Blood |  |
| 2637 | b-aspi | auc | 28 | 0 |  |  | Blood |  |
| 2638 | b-aspi |  | 340 | 100 |  |  | Blood |  |
| 2639 | b-vasp | % | 165 | 0 | [15.56, 23.85, 29.41, 35.04, 41.24, 50.14, 56.77, 61.91, 75.84] |  | Blood |  |
| 2640 | b-vasp |  | 67 | 61.19 |  |  | Blood |  |
| 2641 | du-5hiaa | umol | 332 | 1.51 | [14.87, 17.89, 19.97, 21.96, 24, 26.85, 29.92, 35.9, 54.08] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  |
| 2642 | du-5hiaa | umol/24h | 175 | 0 | [13.31, 17.22, 20.27, 23.53, 25.81, 31.1, 37.11, 45.94, 66.13] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  |
| 2643 | du-5hiaa | umol/l | 25 | 0 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  |
| 2644 | du-5hiaa |  | 147 | 66.67 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  |
| 2645 | fs-ace | u/l | 33401 | 0.05 | [20.1, 26.68, 31.86, 36.8, 41.71, 47.15, 53.87, 62.77, 76.91] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  |
| 2646 | fs-ace |  | 3291 | 89.58 | [11.62, 22.24, 28.9, 33.73, 39.48, 44.52, 50.34, 61.92, 75.37] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  |
| 2647 | fs-apot |  | 258 | 100 |  |  | Fasting serum |  |
| 2648 | fs-ffa | mmol/l | 170 | 0.59 | [0.17, 0.25, 0.3, 0.38, 0.42, 0.5, 0.56, 0.69, 0.91] | fS-Rasvahapot, vapaat | Fasting serum |  |
| 2649 | fs-ffa |  | 19 | 36.84 |  | fS-Rasvahapot, vapaat | Fasting serum |  |
| 2650 | fs-tp-1 |  | 1698 | 100 |  |  | Fasting serum |  |
| 2651 | fs-tp-3 |  | 867 | 100 |  |  | Fasting serum |  |
| 2652 | fs-tp-4 |  | 926 | 100 |  |  | Fasting serum |  |
| 2653 | fs-tp-7 |  | 400 | 100 |  |  | Fasting serum |  |
| 2654 | li-tpha | titre | 12 | 0 |  | Li-Treponema pallidum, hemagglutinaatio | Cerebrospinal fluid |  |
| 2655 | li-tpha |  | 526 | 100 |  | Li-Treponema pallidum, hemagglutinaatio | Cerebrospinal fluid |  |
| 2656 | p-hae |  | 461 | 100 |  |  | Plasma |  |
| 2657 | p-hcg | iu/l | 858 | 0 | [3.54, 10.48, 27.87, 72.06, 203.74, 526.1, 1525.11, 5507.31, 17831.23] | P -Koriongonadotropiini | Plasma |  |
| 2658 | p-hcg | u/l | 13156 | 11.71 | [0, 1.5, 5.06, 22.75, 97.57, 335.38, 1102.09, 3696.05, 18876.19] | P -Koriongonadotropiini | Plasma |  |
| 2659 | p-hcg |  | 15471 | 94.78 | [2.42, 12.44, 35.69, 103.11, 288.41, 866.82, 2866.35, 7636.68, 32545.17] | P -Koriongonadotropiini | Plasma |  |
| 2660 | p-he4 | pmol/l | 2505 | 0.12 | [38.55, 42.76, 46.82, 51.17, 55.95, 62.75, 72.7, 92.45, 146.15] | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  |
| 2661 | p-he4 |  | 6 | 100 |  | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  |
| 2662 | p-hepg |  | 107 | 100 |  |  | Plasma |  |
| 2663 | p-hok |  | 397 | 100 |  |  | Plasma |  |
| 2664 | p-shbg | nmol/l | 791 | 0 | [18.37, 23.23, 26.61, 30.13, 34.18, 38.05, 43.25, 50.43, 63.9] |  | Plasma |  |
| 2665 | p-shbg |  | 758 | 4.09 | [17.37, 21.68, 26.35, 30.87, 35.48, 41.39, 46.88, 56, 72.07] |  | Plasma |  |
| 2666 | s-5hiaa | nmol/l | 10313 | 0.07 | [44.23, 52.73, 60.93, 69.76, 80.1, 94.8, 122.35, 200.37, 540.74] | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  |
| 2667 | s-5hiaa |  | 153 | 79.74 |  | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  |
| 2668 | s-ace | u/l | 2203 | 0.18 | [19.48, 28.37, 33.74, 38.42, 43.02, 48.21, 54.09, 61.63, 75.23] |  | Serum |  |
| 2669 | s-ace |  | 769 | 20.68 | [21.02, 30.36, 34.97, 38.52, 42.83, 46.55, 51.62, 57.68, 65.53] |  | Serum |  |
| 2670 | s-ada | u/l | 4147 | 1.33 | [7, 8.05, 9.23, 10.37, 11.69, 12.94, 14.77, 17.12, 21.32] | S -Adenosiinideaminaasi | Serum |  |
| 2671 | s-ada |  | 259 | 84.56 |  | S -Adenosiinideaminaasi | Serum |  |
| 2672 | s-afp | u/ml | 18186 | 1.26 | [1.8, 2.08, 2.61, 3.01, 3.6, 4.33, 5.57, 7.77, 24.79] | S -Alfa-1-fetoproteiini | Serum |  |
| 2673 | s-afp | ug/l | 2515 | 0 | [2, 2.23, 3, 3.96, 4.22, 5.38, 6.93, 9.7, 20.37] | S -Alfa-1-fetoproteiini | Serum |  |
| 2674 | s-afp |  | 4026 | 80.55 | [2, 2.01, 3, 3, 3.99, 4, 5, 6.41, 9.69] | S -Alfa-1-fetoproteiini | Serum |  |
| 2675 | s-afp/d | u/ml | 234 | 0 | [15.11, 17.44, 19.7, 22.07, 23.9, 26.33, 29.33, 33.17, 39.24] |  | Serum |  |
| 2676 | s-afp/d |  | 49 | 12.24 |  |  | Serum |  |
| 2677 | s-amh | ug/l | 9545 | 0.43 | [0.42, 0.85, 1.31, 1.75, 2.24, 2.87, 3.63, 4.76, 7.13] | S -Anti-Muller hormoni | Serum |  |
| 2678 | s-amh |  | 1328 | 93.45 | [0.62, 1.11, 1.66, 2.28, 2.8, 3.57, 4.21, 5.32, 7.88] | S -Anti-Muller hormoni | Serum |  |
| 2679 | s-ami | mg/l | 294 | 0 | [1.3, 1.49, 1.7, 2.28, 2.76, 3.41, 4.52, 6.36, 11.32] | S -Amikasiini | Serum |  |
| 2680 | s-ami |  | 308 | 95.13 |  | S -Amikasiini | Serum |  |
| 2681 | s-ana | titre | 21493 | 1.69 | [80, 121.94, 160, 299.08, 320, 320, 399.84, 831.19, 1349.55] | S -Tuma, vasta-aineet | Serum |  |
| 2682 | s-ana |  | 62781 | 100 | [80, 160, 320, 320, 320, 320, 640, 762.94, 1891.15] | S -Tuma, vasta-aineet | Serum |  |
| 2683 | s-apot |  | 754 | 100 |  |  | Serum |  |
| 2684 | s-asca | u/ml | 89 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  |
| 2685 | s-asca |  | 316 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  |
| 2686 | s-ast | iu/ml | 2404 | 0 | [49.92, 65.92, 77.55, 92.42, 111.12, 137.94, 173.28, 237.31, 396.71] | S -Antistreptolysiini | Serum |  |
| 2687 | s-ast | titre | 7 | 0 |  | S -Antistreptolysiini | Serum |  |
| 2688 | s-ast | u/ml | 408 | 4.17 | [30.71, 40.63, 53.38, 70.53, 94.49, 133.41, 202.61, 384.67, 783.66] | S -Antistreptolysiini | Serum |  |
| 2689 | s-ast |  | 2603 | 94.05 | [60.92, 74.22, 90.53, 107.5, 145.19, 198.62, 261.7, 407.28, 740.72] | S -Antistreptolysiini | Serum |  |
| 2690 | s-asta | iu/ml | 256 | 16.41 | [2, 2, 2, 2, 3.02, 4, 4.64, 6, 8] | S -Antistafylolysiini | Serum |  |
| 2691 | s-asta | u/ml | 10 | 0 |  | S -Antistafylolysiini | Serum |  |
| 2692 | s-asta |  | 2266 | 99.29 |  | S -Antistafylolysiini | Serum |  |
| 2693 | s-br | mmol/l | 130 | 0 |  | S -Bromidi | Serum |  |
| 2694 | s-dhea | nmol/l | 398 | 0 | [2.68, 4.23, 5.8, 8.33, 11.06, 14.2, 18.42, 22.5, 33.54] | S -Dehydroepiandrosteroni | Serum |  |
| 2695 | s-dhea |  | 74 | 68.92 |  | S -Dehydroepiandrosteroni | Serum |  |
| 2696 | s-dheas | umol/l | 3797 | 0.03 | [1.05, 1.87, 2.83, 3.75, 4.58, 5.54, 6.67, 8.05, 10.29] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  |
| 2697 | s-dheas |  | 331 | 53.47 | [1.45, 2.24, 2.88, 3.59, 4.26, 5.13, 5.94, 7.34, 8.82] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  |
| 2698 | s-e1 | pmol/l | 123 | 0 | [70, 112.9, 136.88, 181.46, 224.33, 282.87, 347.03, 435.1, 621.18] | S -Estroni | Serum |  |
| 2699 | s-e1 |  | 30 | 76.67 |  | S -Estroni | Serum |  |
| 2700 | s-e2 | nmol/l | 10351 | 2.69 | [0.07, 0.1, 0.13, 0.16, 0.2, 0.27, 0.38, 0.55, 0.99] | S -Estradioli | Serum |  |
| 2701 | s-e2 |  | 2381 | 83.75 | [0.06, 0.08, 0.1, 0.12, 0.15, 0.19, 0.25, 0.35, 0.58] | S -Estradioli | Serum |  |
| 2702 | s-ema |  | 2245 | 99.96 |  | S -Endomysium, vasta-aineet | Serum |  |
| 2703 | s-ena |  | 1469 | 62.22 | [0.1, 0.1, 0.1, 0.19, 0.2, 0.22, 0.3, 0.47, 1.12] |  | Serum |  |
| 2704 | s-enal |  | 832 | 100 |  |  | Serum |  |
| 2705 | s-epo | iu/l | 2353 | 0.38 | [4.95, 7.08, 8.93, 10.78, 12.99, 15.54, 19.77, 28.75, 48.4] | S -Erytropoietiini | Serum |  |
| 2706 | s-epo | pmol/l | 44 | 0 |  | S -Erytropoietiini | Serum |  |
| 2707 | s-epo | u/l | 5380 | 0 | [4.44, 6.44, 8.09, 9.88, 11.93, 14.55, 19.01, 29.55, 62.33] | S -Erytropoietiini | Serum |  |
| 2708 | s-epo |  | 1209 | 20.35 | [4.6, 6.64, 8.47, 10.2, 11.81, 13.76, 17.07, 22.59, 40.53] | S -Erytropoietiini | Serum |  |
| 2709 | s-ffa | mmol/l | 518 | 0 | [0.03, 0.04, 0.07, 0.13, 0.19, 0.28, 0.44, 0.57, 0.75] |  | Serum |  |
| 2710 | s-gen | mg/l | 373 | 0.54 | [0.5, 0.65, 0.75, 0.89, 0.99, 1.17, 1.48, 2.04, 3.94] | S -Gentamysiini | Serum |  |
| 2711 | s-gen |  | 339 | 85.55 |  | S -Gentamysiini | Serum |  |
| 2712 | s-hae |  | 751 | 100 |  |  | Serum |  |
| 2713 | s-hbe |  | 347 | 100 |  |  | Serum |  |
| 2714 | s-hcg | iu/l | 2181 | 0 | [2.11, 4.62, 15.8, 53.63, 166.71, 442, 1018.25, 2912.42, 12003.73] | S -Koriongonadotropiini | Serum |  |
| 2715 | s-hcg | u/l | 5914 | 0 | [5.67, 20.66, 67.43, 172.44, 366.74, 677.25, 1513.49, 4378.78, 17452.46] | S -Koriongonadotropiini | Serum |  |
| 2716 | s-hcg |  | 16592 | 96.23 | [8.29, 17.67, 40.08, 108.43, 306.84, 912.85, 3181.52, 10206.39, 38671.9] | S -Koriongonadotropiini | Serum |  |
| 2717 | s-he4 | pmol/l | 11193 | 0 | [31.87, 37.18, 41.94, 46.96, 53.02, 60.99, 73.42, 98.24, 181.66] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  |
| 2718 | s-he4 |  | 420 | 43.57 | [28.77, 32.37, 35.15, 39.84, 42.92, 45.83, 51.37, 61.13, 81.8] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  |
| 2719 | s-kem |  | 1473 | 100 |  |  | Serum |  |
| 2720 | s-kyhemag | titre | 180 | 1.67 | [8, 11.41, 16, 18.4, 42.5, 146.59, 256, 870.4, 2048] | S -Kylmähemagglutiniinit | Serum |  |
| 2721 | s-kyhemag |  | 826 | 99.39 |  | S -Kylmähemagglutiniinit | Serum |  |
| 2722 | s-shbg | nmol/l | 29338 | 0 | [16.96, 21.37, 25.29, 29.19, 33.26, 37.98, 43.62, 51.6, 65.13] | S -Sukupuolihormoneja sitova globuliini | Serum |  |
| 2723 | s-shbg |  | 614 | 100 | [15.22, 19.74, 24.23, 28.3, 32.4, 37.12, 43.41, 51.5, 64.44] | S -Sukupuolihormoneja sitova globuliini | Serum |  |
| 2724 | s-tati | nmol/l | 551 | 0 | [1.3, 1.49, 1.61, 1.81, 2.08, 2.38, 2.74, 3.44, 6.09] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  |
| 2725 | s-tati | ug/l | 446 | 0 | [6.71, 8.1, 9.03, 9.98, 11, 12.24, 13.98, 16.99, 30.9] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  |
| 2726 | s-tati |  | 86 | 24.42 |  | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  |
| 2727 | s-tpha | titre | 1665 | 0 | [158.37, 304.61, 391.53, 640, 1034.44, 1338.85, 3168.84, 4985.37, 6432.72] | S -Treponema pallidum, hemagglutinaatio | Serum |  |
| 2728 | s-tpha |  | 9799 | 99.67 |  | S -Treponema pallidum, hemagglutinaatio | Serum |  |
| 2729 | s-van | mg/l | 36935 | 0.09 | [6.84, 8.59, 9.97, 11.16, 12.39, 13.69, 15.03, 16.85, 19.72] | S -Vankomysiini | Serum |  |
| 2730 | s-van |  | 1695 | 100 | [7.35, 9.11, 10.49, 11.71, 12.89, 14.15, 15.61, 17.74, 21.29] | S -Vankomysiini | Serum |  |
| 2731 | ts-res |  | 1353 | 100 |  | Ts-Reseptoritutkimus | Tissue |  |
| 2732 | u-hcg | iu/l | 93 | 0 |  | U -Koriongonadotropiini | Urine |  |
| 2733 | u-hcg | u/l | 15 | 0 |  | U -Koriongonadotropiini | Urine |  |
| 2734 | u-hcg |  | 227 | 97.8 |  | U -Koriongonadotropiini | Urine |  |

