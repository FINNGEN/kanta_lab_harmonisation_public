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
Here is group 167 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 13496 | b-erybla,osatutkimus(19978b-erybla) | e9/l | 1575 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  |
| 13497 | b-erybla,osatutkimus(b-erybla) | e9/l | 3732 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  |
| 13498 | b-erybla,osatutkimus(b-erybla) |  | 8 | 75 |  |  | Blood |  |
| 13499 | b-neut,osatutkimus(689b-neut) | e9/l | 114 | 0 | [2.36, 2.69, 3.03, 3.4, 3.69, 4.15, 4.59, 5.12, 5.88] |  | Blood |  |
| 13500 | basofiilit,absol.arvot,osatutkimus(40b-baso) | e9/l | 114 | 0 | [0.02, 0.03, 0.03, 0.04, 0.04, 0.05, 0.06, 0.06, 0.08] |  |  |  |
| 13501 | basofiilit,konediffi(),osatutk.b-diffi | % | 1040 | 0 | [0.2, 0.35, 0.48, 0.57, 0.68, 0.78, 0.9, 1.09, 1.35] |  |  |  |
| 13502 | basofiilit,osatutkimus(692l-baso) | % | 128 | 0 | [0, 0, 0.88, 1, 1, 1, 1, 1, 1] |  |  |  |
| 13503 | e-rdw,osatutkimus(19976e-rdw) | % | 1577 | 0 | [12, 12.98, 13, 13, 13, 13, 13.6, 14, 14.04] |  | Erythrocyte |  |
| 13504 | e-rdw,osatutkimus(e-rdw) | % | 3731 | 0 | [12, 12.05, 13, 13, 13, 13, 13, 14, 14.04] |  | Erythrocyte |  |
| 13505 | e-rdw,osatutkimus(e-rdw) |  | 8 | 100 |  |  | Erythrocyte |  |
| 13506 | eosinofiilit,absol.arvot,osatutkimus(39b-eos) | e9/l | 114 | 0 | [0.06, 0.09, 0.12, 0.16, 0.18, 0.2, 0.23, 0.28, 0.33] |  |  |  |
| 13507 | eosinofiilit,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [0.08, 1.13, 1.71, 2.33, 2.85, 3.43, 4.13, 5.02, 6.83] |  |  |  |
| 13508 | eosinofiilit,osatutkimus(690l-eos) | % | 114 | 0 | [1, 1.43, 2, 2, 3, 3, 3.11, 4, 5] |  |  |  |
| 13509 | eosinofiilitabs,konediffi,osatutk.b-diffi | e9/l | 1041 | 0 | [0.01, 0.07, 0.1, 0.14, 0.17, 0.22, 0.27, 0.33, 0.46] |  |  |  |
| 13510 | kalsium,osatutkimus(p-ca) | mmol/l | 167 | 0 | [2.26, 2.3, 2.32, 2.34, 2.37, 2.38, 2.41, 2.43, 2.47] |  |  |  |
| 13511 | l-neut,osatutkimus(688l-neut) | % | 114 | 0 | [46.1, 51, 53.29, 55, 56.87, 59, 62, 66.13, 71.3] |  | Leukocyte |  |
| 13512 | lymfosyytit,absol.arvot,osatutkimus(43b-lymf) | e9/l | 114 | 0 | [1.2, 1.42, 1.67, 1.84, 1.94, 2.02, 2.22, 2.46, 2.71] |  |  |  |
| 13513 | lymfosyytit,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [14.77, 18.39, 21, 24.27, 27.4, 30.54, 33.61, 37.23, 41.49] |  |  |  |
| 13514 | lymfosyytit,osatutkimus(46l-lymf) | % | 114 | 0 | [17.98, 23.4, 26.71, 28, 31, 32.84, 34.76, 36, 40.42] |  |  |  |
| 13515 | monosyytit,absol.arvot,osatutkimus(42b-monos) | e9/l | 114 | 0 | [0.36, 0.42, 0.44, 0.49, 0.53, 0.58, 0.62, 0.67, 0.77] |  |  |  |
| 13516 | monosyytit,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [6.01, 6.87, 7.49, 8.19, 8.74, 9.45, 10.43, 11.69, 13.27] |  |  |  |
| 13517 | monosyytit,osatutkimus(693l-monos) | % | 114 | 0 | [6, 6.9, 7, 8, 8, 9, 9, 10, 11] |  |  |  |
| 13518 | neutrofiiliset,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [43.33, 48.08, 51.94, 55.59, 58.77, 61.59, 65.14, 69.9, 74.47] |  |  |  |
| 13519 | neutrofiilitabs,konediffi,osatutk.b-diffi | e9/l | 1041 | 0 | [1.86, 2.39, 2.82, 3.25, 3.63, 4.11, 4.7, 5.54, 6.96] |  |  |  |
| 13520 | s-albumiini,osatutkimuss-prot-fr | g/l | 109 | 0 | [31.62, 35.39, 37.28, 38.52, 39.57, 40.75, 41.75, 43.12, 44] |  | Serum | Fractions |
| 13521 | s-alfa-1-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [2.3, 2.4, 2.54, 2.7, 2.89, 3.08, 3.35, 3.6, 4.2] |  | Serum | Fractions |
| 13522 | s-alfa-2-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [5.63, 6, 6.24, 6.66, 7.47, 7.93, 8.35, 9.06, 9.9] |  | Serum | Fractions |
| 13523 | s-beta-1-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [3.5, 3.7, 3.85, 4.04, 4.14, 4.31, 4.42, 4.7, 4.9] |  | Serum | Fractions |
| 13524 | s-beta-2-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [2.8, 3.09, 3.44, 3.86, 4.01, 4.31, 4.58, 4.8, 5.27] |  | Serum | Fractions |
| 13525 | s-gamma-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [6.61, 7.97, 8.64, 9.16, 9.73, 10.36, 11, 11.66, 12.99] |  | Serum | Fractions |
| 13526 | s-m-komponentti-1(valetietues-prot-fr) | g/l | 135 | 0 | [0, 0, 0, 1.3, 2.13, 3.83, 5.42, 7.84, 12.97] |  | Serum |  |
| 13527 | s-m-komponentti-1(valetietues-prot-fr) |  | 93 | 100 |  |  | Serum |  |
| 13528 | s-m-komponentti-2(valetietues-prot-fr) | g/l | 82 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 1] |  | Serum |  |
| 13529 | s-m-komponentti-2(valetietues-prot-fr) |  | 133 | 100 |  |  | Serum |  |
| 13530 | s-m-komponentti-3(valetietues-prot-fr) |  | 131 | 100 |  |  | Serum |  |

