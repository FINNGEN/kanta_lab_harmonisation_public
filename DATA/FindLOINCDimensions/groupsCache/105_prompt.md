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
Here is group 105 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 8557 | b-pvk | % | 1036 | 0 | [12.98, 13, 13, 13, 13.02, 14, 14, 14, 14.9] | B -Perusverenkuva | Blood |  |
| 8558 | b-pvk | e12/l | 180 | 0 |  | B -Perusverenkuva | Blood |  |
| 8559 | b-pvk | e9/l | 180 | 0 |  | B -Perusverenkuva | Blood |  |
| 8560 | b-pvk | fl | 191 | 0 |  | B -Perusverenkuva | Blood |  |
| 8561 | b-pvk | form | 6 | 0 |  | B -Perusverenkuva | Blood |  |
| 8562 | b-pvk | g/l | 371 | 0 | [130.49, 135.97, 140.17, 143.56, 146.5, 149.94, 154.99, 161.16, 169.87] | B -Perusverenkuva | Blood |  |
| 8563 | b-pvk | paketti | 261 | 0 | [31329.79, 60496.46, 87166.96, 116360.34, 146168.26, 177141.71, 213025.07, 240401.38, 278743.21] | B -Perusverenkuva | Blood |  |
| 8564 | b-pvk | pg | 191 | 0 |  | B -Perusverenkuva | Blood |  |
| 8565 | b-pvk |  | 1084645 | 100 |  | B -Perusverenkuva | Blood |  |
| 8566 | b-pvk(pi) |  | 994 | 100 |  |  | Blood |  |
| 8567 | b-pvk+eo |  | 1355 | 100 |  |  | Blood |  |
| 8568 | b-pvk+kd |  | 335 | 100 |  |  | Blood |  |
| 8569 | b-pvk+ne |  | 301325 | 100 |  |  | Blood |  |
| 8570 | b-pvk+ner |  | 551 | 100 |  |  | Blood |  |
| 8571 | b-pvk+t | % | 16337 | 0 | [8.54, 11.43, 12.73, 13.01, 14.63, 21.66, 27.29, 34.08, 48.89] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8572 | b-pvk+t | %g | 229 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8573 | b-pvk+t | %l | 229 | 0 | [15.3, 18.86, 20.93, 24.39, 26.09, 27.9, 29.48, 31.36, 37.88] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8574 | b-pvk+t | %m | 229 | 0 | [9, 10, 10.3, 10.73, 11, 11.47, 11.97, 12.55, 13.3] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8575 | b-pvk+t | e12/l | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8576 | b-pvk+t | e9/l | 4647 | 0 | [0, 0, 0, 0, 0, 0, 2.04, 5.2, 8.91] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8577 | b-pvk+t | fl | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8578 | b-pvk+t | form | 361 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.89, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8579 | b-pvk+t | g/l | 2746 | 0 | [312.86, 315.11, 317.96, 319.16, 327.56, 334.19, 340.53, 346.44, 355.56] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8580 | b-pvk+t | l/l | 6 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8581 | b-pvk+t | paketti | 269 | 0 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8582 | b-pvk+t | pg | 2769 | 0 | [29, 29.58, 30, 30.35, 31, 31.07, 32, 32.99, 34.11] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8583 | b-pvk+t |  | 4547373 | 100 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8584 | b-pvk+t+e |  | 1491 | 100 |  |  | Blood |  |
| 8585 | b-pvk+t+n |  | 20012 | 100 |  |  | Blood |  |
| 8586 | b-pvk+t+ne |  | 1150 | 100 |  |  | Blood |  |
| 8587 | b-pvk+t+r |  | 713 | 100 |  |  | Blood |  |
| 8588 | b-pvk+tk |  | 466 | 100 |  |  | Blood |  |
| 8589 | b-pvk+tkd | % | 567 | 0 | [10.52, 11.98, 22.28, 26.53, 30.21, 32.92, 36.29, 39.43, 43.1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |
| 8590 | b-pvk+tkd | e9/l | 5 | 0 |  | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |
| 8591 | b-pvk+tkd |  | 347141 | 99.77 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |
| 8592 | b-pvk+tkd,baso | % | 4387 | 0 | [0.13, 0.2, 0.3, 0.34, 0.4, 0.5, 0.59, 0.7, 0.91] |  | Blood |  |
| 8593 | b-pvk+tkd,baso | e9/l | 4345 | 0 | [0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.05, 0.06] |  | Blood |  |
| 8594 | b-pvk+tkd,baso |  | 28 | 96.43 |  |  | Blood |  |
| 8595 | b-pvk+tkd,eo | % | 4389 | 0 | [0.28, 0.95, 1.44, 1.88, 2.38, 2.9, 3.5, 4.34, 5.77] |  | Blood |  |
| 8596 | b-pvk+tkd,eo | e9/l | 4355 | 0 | [0.02, 0.07, 0.1, 0.13, 0.16, 0.2, 0.24, 0.3, 0.39] |  | Blood |  |
| 8597 | b-pvk+tkd,eo |  | 35 | 77.14 |  |  | Blood |  |
| 8598 | b-pvk+tkd,eryt | e12/l | 4432 | 0 | [3.69, 4.01, 4.19, 4.32, 4.47, 4.6, 4.71, 4.86, 5.08] |  | Blood |  |
| 8599 | b-pvk+tkd,eryt |  | 28 | 82.14 |  |  | Blood |  |
| 8600 | b-pvk+tkd,hb | g/l | 4431 | 0 | [109.63, 119.87, 125.6, 130.31, 134.35, 137.72, 141.31, 145.38, 151.58] |  | Blood |  |
| 8601 | b-pvk+tkd,hb |  | 28 | 82.14 |  |  | Blood |  |
| 8602 | b-pvk+tkd,hkr | osuus | 4430 | 0 | [0.34, 0.36, 0.38, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45] |  | Blood |  |
| 8603 | b-pvk+tkd,hkr |  | 28 | 82.14 |  |  | Blood |  |
| 8604 | b-pvk+tkd,ig | % | 4380 | 0 | [0, 0.1, 0.18, 0.2, 0.2, 0.24, 0.3, 0.4, 0.66] |  | Blood |  |
| 8605 | b-pvk+tkd,ig | e9/l | 4329 | 0 | [0, 0.01, 0.01, 0.01, 0.01, 0.02, 0.02, 0.03, 0.06] |  | Blood |  |
| 8606 | b-pvk+tkd,ig |  | 27 | 100 |  |  | Blood |  |
| 8607 | b-pvk+tkd,leuk | e9/l | 4441 | 0 | [4.64, 5.29, 5.87, 6.47, 7.06, 7.73, 8.41, 9.34, 10.91] |  | Blood |  |
| 8608 | b-pvk+tkd,leuk |  | 23 | 100 | [4.39, 5.06, 5.62, 6.11, 6.7, 7.36, 7.96, 8.73, 10.19] |  | Blood |  |
| 8609 | b-pvk+tkd,lymph | % | 4402 | 0 | [14.51, 18.87, 22.17, 24.95, 27.85, 30.77, 33.85, 37.68, 42.79] |  | Blood |  |
| 8610 | b-pvk+tkd,lymph | e9/l | 4366 | 0 | [1.07, 1.3, 1.5, 1.68, 1.87, 2.05, 2.28, 2.59, 3.03] |  | Blood |  |
| 8611 | b-pvk+tkd,lymph |  | 39 | 71.79 |  |  | Blood |  |
| 8612 | b-pvk+tkd,mch | pg | 4427 | 0 | [27.35, 28.81, 29.01, 30, 30, 30.98, 31, 31.99, 32.41] |  | Blood |  |
| 8613 | b-pvk+tkd,mch |  | 26 | 88.46 |  |  | Blood |  |
| 8614 | b-pvk+tkd,mchc | g/l | 4422 | 0 | [316.84, 322.97, 327.09, 330.49, 333.34, 336.5, 339.82, 343.59, 348.74] |  | Blood |  |
| 8615 | b-pvk+tkd,mchc |  | 27 | 85.19 |  |  | Blood |  |
| 8616 | b-pvk+tkd,mcv | fl | 4432 | 0 | [83.81, 86.19, 87.9, 89.02, 90.1, 91.52, 92.95, 94.05, 96.04] |  | Blood |  |
| 8617 | b-pvk+tkd,mcv |  | 25 | 92 |  |  | Blood |  |
| 8618 | b-pvk+tkd,mono | % | 4397 | 0 | [6.39, 7.45, 8.16, 8.78, 9.38, 10.01, 10.67, 11.64, 13.06] |  | Blood |  |
| 8619 | b-pvk+tkd,mono | e9/l | 4364 | 0 | [0.41, 0.48, 0.54, 0.59, 0.65, 0.7, 0.78, 0.88, 1.03] |  | Blood |  |
| 8620 | b-pvk+tkd,mono |  | 32 | 84.38 |  |  | Blood |  |
| 8621 | b-pvk+tkd,neut | % | 4407 | 0 | [43.3, 48.04, 51.9, 55.37, 58.56, 61.78, 65.36, 69.3, 74.25] |  | Blood |  |
| 8622 | b-pvk+tkd,neut | e9/l | 4373 | 0 | [2.18, 2.67, 3.11, 3.55, 4, 4.52, 5.12, 5.94, 7.37] |  | Blood |  |
| 8623 | b-pvk+tkd,neut |  | 34 | 82.35 |  |  | Blood |  |
| 8624 | b-pvk+tkd,rdw | % | 4298 | 0 | [12.5, 12.85, 13.17, 13.49, 13.79, 14.12, 14.57, 15.17, 16.52] |  | Blood |  |
| 8625 | b-pvk+tkd,rdw |  | 30 | 76.67 |  |  | Blood |  |
| 8626 | b-pvk+tkd,trom | eg/l | 4413 | 0 | [163.91, 190.28, 209.92, 228.62, 246.86, 267.53, 293.03, 326.64, 371.27] |  | Blood |  |
| 8627 | b-pvk+tkd,trom |  | 31 | 74.19 |  |  | Blood |  |
| 8628 | b-pvk+tmd | % | 108 | 0 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  |
| 8629 | b-pvk+tmd |  | 31394 | 99.96 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  |
| 8630 | b-pvk-päi |  | 120 | 100 |  |  | Blood |  |
| 8631 | b-pvk-t |  | 1651 | 100 |  |  | Blood |  |
| 8632 | b-pvk-tkd |  | 5227 | 100 |  |  | Blood |  |
| 8633 | b-pvkt |  | 540592 | 100 |  |  | Blood |  |
| 8634 | b-pvkt+re |  | 3032 | 100 |  |  | Blood |  |
| 8635 | b-pvktkdr |  | 6444 | 100 |  |  | Blood |  |
| 8636 | b-pvktmdl |  | 275 | 100 |  |  | Blood |  |
| 8637 | b-pvktmdp |  | 1012 | 100 |  |  | Blood |  |
| 8638 | b-pvktnee |  | 9809 | 100 |  |  | Blood |  |
| 8639 | b-pvktp |  | 5212 | 100 |  |  | Blood |  |
| 8640 | b-tvk | % | 505 | 0 | [0, 0, 0, 0, 1, 2.55, 12.33, 37.94, 62.13] | B -Täydellinen verenkuva | Blood |  |
| 8641 | b-tvk | e9/l | 368 | 0 | [0.03, 0.03, 0.04, 0.04, 0.05, 0.05, 0.06, 0.07, 0.09] | B -Täydellinen verenkuva | Blood |  |
| 8642 | b-tvk | fl | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8643 | b-tvk | form | 11 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8644 | b-tvk | g/l | 19 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8645 | b-tvk | paketti | 22 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8646 | b-tvk | pg | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8647 | b-tvk |  | 466809 | 100 |  | B -Täydellinen verenkuva | Blood |  |
| 8648 | b-tvk+r |  | 465 | 100 |  |  | Blood |  |

