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
Here is group 14 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 965 | b-c-reaktiivinenproteiini | mg/l | 29 | 0 |  |  | Blood |  |
| 966 | b-c-reaktiivinenproteiini |  | 262 | 44.27 | [6, 7.5, 10.67, 13.8, 18.67, 27.69, 37.44, 56, 84] |  | Blood |  |
| 967 | b-c-reaktiivinenproteiinipika |  | 300 | 37 | [7, 10.22, 14.84, 20.3, 29.2, 37.52, 52.47, 75.48, 99.1] |  | Blood |  |
| 968 | b-c-resktiivinenproteiini | mg/l | 1201 | 0 | [6, 8.11, 11.16, 14.7, 19.67, 26.61, 38.65, 58.3, 91.79] |  | Blood |  |
| 969 | b-c-resktiivinenproteiini |  | 802 | 92.39 |  |  | Blood |  |
| 970 | c-reaktiivinenproteiini | 1 | 925 | 0 | [6.19, 8.89, 11.99, 16.88, 23.76, 35.33, 49.12, 74.41, 108.21] |  |  |  |
| 971 | c-reaktiivinenproteiini | mg/l | 7963 | 0 | [4.01, 6.22, 9.5, 14.46, 23.15, 35.25, 51.85, 77.94, 126.36] |  |  |  |
| 972 | c-reaktiivinenproteiini |  | 7083 | 90.23 | [6.55, 8.84, 11.73, 17.15, 24.37, 37.67, 52.72, 72.92, 107.1] |  |  |  |
| 973 | c-reaktiivinenproteiini(4594p-crp) | mg/l | 143 | 0 | [1, 1.79, 2, 2, 3, 4, 5, 6, 12.8] |  |  |  |
| 974 | c-reaktiivinenproteiini(4594p-crp) |  | 74 | 100 |  |  |  |  |
| 975 | c-reaktiivinenproteiini(crp) | mg/l | 381 | 0 | [1.23, 1.51, 1.92, 2.62, 3.36, 4.75, 6.13, 9.98, 21.06] |  |  |  |
| 976 | c-reaktiivinenproteiini(crp) |  | 250 | 100 |  |  |  |  |
| 977 | c-reaktiivinenproteiini(p-crp) | mg/l | 500 | 0 | [1, 2, 2, 2.85, 3.14, 4.26, 5.94, 8.93, 19.54] |  |  |  |
| 978 | c-reaktiivinenproteiini(p-crp) |  | 261 | 100 |  |  |  |  |
| 979 | c-reaktiivinenproteiini,herkkä | mg/l | 254 | 0 | [0.22, 0.41, 0.57, 0.84, 1.15, 1.65, 2.42, 3.86, 6.33] |  |  |  |
| 980 | c-reaktiivinenproteiini,herkkä |  | 18 | 94.44 |  |  |  |  |
| 981 | c-reaktiivinenproteiini,herkkä,seerumista | mg/l | 7396 | 0 | [0.28, 0.41, 0.6, 0.78, 1.03, 1.34, 1.83, 2.72, 4.64] |  |  |  |
| 982 | c-reaktiivinenproteiini,herkkä,seerumista |  | 36 | 83.33 |  |  |  |  |
| 983 | c-reaktiivinenproteiini,pika | mg/l | 111 | 0 | [5, 5.05, 6.2, 8.27, 11.67, 14.3, 22.37, 36.1, 57] |  |  |  |
| 984 | c-reaktiivinenproteiini,pika |  | 49 | 100 |  |  |  |  |
| 985 | c-reaktiivinenproteiini,pika,tehdäänitse | mg/l | 997 | 0 | [5, 5, 6.35, 8.12, 10.93, 14.99, 21.14, 34.44, 53.73] |  |  |  |
| 986 | c-reaktiivinenproteiini,pika,tehdäänitse |  | 820 | 99.27 |  |  |  |  |
| 987 | c-reaktiivinenproteiini,pikatesti,veri | mg/l | 174 | 0 | [6, 7, 8.95, 10.5, 16.42, 22.45, 35.5, 53.5, 98.67] |  |  |  |
| 988 | c-reaktiivinenproteiini,pikatesti,veri |  | 1656 | 42.69 | [6.55, 9.61, 13.21, 19.27, 27.67, 39.17, 52.81, 73.29, 109.39] |  |  |  |
| 989 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) | mg/l | 803 | 0 | [4.99, 5.34, 7.17, 9.24, 13.4, 18.77, 28.88, 45.54, 76.31] |  |  |  |
| 990 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) |  | 240 | 100 |  |  |  |  |
| 991 | c-reaktiivinenproteiini,pikatutkimus | mg/l | 106 | 0 | [7, 12, 15.43, 21.6, 30.72, 39.4, 56.9, 87, 115.33] |  |  |  |
| 992 | c-reaktiivinenproteiini,pikatutkimus |  | 66 | 100 |  |  |  |  |
| 993 | c-reaktiivinenproteiini,plasmasta,vieritesti | mg/l | 699 | 0 | [5.17, 7.91, 10.75, 16.58, 23.68, 33.24, 48.01, 64.98, 99.29] |  |  |  |
| 994 | c-reaktiivinenproteiini,plasmasta,vieritesti |  | 274 | 94.89 |  |  |  |  |
| 995 | c-reaktiivinenproteiini,tk:ntekemä |  | 1605 | 13.4 | [2.23, 4.3, 7.78, 12.46, 19.91, 29.72, 46.58, 66.7, 98.89] |  |  |  |
| 996 | c-reaktiivinenproteiini,vieritesti | mg/l | 47 | 0 |  |  |  |  |
| 997 | c-reaktiivinenproteiini,vieritesti |  | 944 | 23.62 | [3.08, 5.45, 7.93, 11.11, 14.9, 20.87, 29.7, 49.04, 81.9] |  |  |  |
| 998 | c-reaktiivinenproteiini,vieritutkimus | mg/l | 525 | 0 | [5, 6.72, 8.66, 12.22, 15.93, 22.09, 35.26, 59.08, 89.7] |  |  |  |
| 999 | c-reaktiivinenproteiini,vieritutkimus |  | 631 | 58.8 | [6.41, 9.32, 15.53, 22.99, 35.64, 49.47, 62.97, 81.83, 113.06] |  |  |  |
| 1000 | c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 1205 | 0 |  |  |  |  |
| 1001 | c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 318 | 100 | [4.71, 7.37, 11.52, 16.21, 23.22, 31.65, 45.13, 65.98, 97.07] |  |  |  |
| 1002 | c-reaktiivinenproteiini,vieritutkimusnordlab | mg/l | 92 | 0 | [5, 6, 8, 10.7, 12.75, 16.2, 21, 31.5, 47] |  |  |  |
| 1003 | c-reaktiivinenproteiini,vieritutkimusnordlab |  | 99 | 100 |  |  |  |  |
| 1004 | c-reaktiivinenproteiini-pika(4594crp-pika) | mg/l | 136 | 0 | [5, 5.32, 7, 9, 11.15, 14.57, 19, 33.2, 47.3] |  |  |  |
| 1005 | c-reaktiivinenproteiini-pika(4594crp-pika) |  | 47 | 100 |  |  |  |  |
| 1006 | c-reaktiivinenproteiini-pika(crp-pika) | mg/l | 1488 | 0 | [5, 6.88, 7, 7.34, 10.21, 14.71, 21.39, 32, 54.73] |  |  |  |
| 1007 | c-reaktiivinenproteiini-pika(crp-pika) |  | 505 | 99.8 |  |  |  |  |
| 1008 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä | mg/l | 1826 | 0 | [1.75, 3.02, 5.68, 9.52, 14.27, 22.77, 34.19, 57.29, 89.46] |  |  |  |
| 1009 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä |  | 497 | 46.88 | [1.2, 1.53, 2.21, 2.84, 3.97, 4.8, 6.15, 7.51, 9.1] |  |  |  |
| 1010 | fs-c-reaktiivinenproteiini | mg/l | 241 | 0 |  |  | Fasting serum |  |
| 1011 | fs-c-reaktiivinenproteiini |  | 184 | 100 |  |  | Fasting serum |  |
| 1012 | p-c-reaktiininenproteiini,vieritutkimus | mg/l | 258 | 0 | [5.85, 8.85, 11.14, 17.24, 24.49, 35.17, 49.34, 67.54, 96.38] |  | Plasma |  |
| 1013 | p-c-reaktiininenproteiini,vieritutkimus |  | 224 | 100 |  |  | Plasma |  |
| 1014 | p-c-reaktiivinenproteiini | mg/l | 41046 | 0 | [4.18, 7.12, 11.73, 18.09, 27.46, 40.11, 58.4, 87.78, 141.39] |  | Plasma |  |
| 1015 | p-c-reaktiivinenproteiini |  | 24714 | 99.73 |  |  | Plasma |  |
| 1016 | p-c-reaktiivinenproteiini(kval) | mg/l | 187 | 0 | [6.14, 9.01, 13.88, 18.86, 24.62, 33.54, 47.21, 67.37, 102.4] |  | Plasma |  |
| 1017 | p-c-reaktiivinenproteiini(kval) |  | 142 | 100 |  |  | Plasma |  |
| 1018 | p-c-reaktiivinenproteiini(kval)␤ | mg/l | 111 | 0 |  |  | Plasma |  |
| 1019 | p-c-reaktiivinenproteiini(kval)␤ |  | 130 | 100 |  |  | Plasma |  |
| 1020 | p-c-reaktiivinenproteiini(pikanäyte) | mg/l | 6 | 0 |  |  | Plasma |  |
| 1021 | p-c-reaktiivinenproteiini(pikanäyte) |  | 352 | 17.33 | [1.52, 2.59, 4.86, 7.54, 12.38, 20.91, 32.04, 56.93, 83.62] |  | Plasma |  |
| 1022 | p-c-reaktiivinenproteiini,crp | mg/l | 110 | 0 |  |  | Plasma |  |
| 1023 | p-c-reaktiivinenproteiini,crp |  | 8 | 62.5 |  |  | Plasma |  |
| 1024 | p-c-reaktiivinenproteiini,hoitoyksikkö | 1 | 40 | 0 |  |  | Plasma |  |
| 1025 | p-c-reaktiivinenproteiini,hoitoyksikkö | alle | 5 | 0 |  |  | Plasma |  |
| 1026 | p-c-reaktiivinenproteiini,hoitoyksikkö | mg/l | 81 | 0 | [8, 11, 13, 16.2, 22.25, 33.7, 48, 64, 131] |  | Plasma |  |
| 1027 | p-c-reaktiivinenproteiini,hoitoyksikkö |  | 156 | 63.46 | [6, 8, 12, 14, 26, 32, 40, 60, 120] |  | Plasma |  |
| 1028 | p-c-reaktiivinenproteiini,pikatesti | mg/l | 190 | 0 |  |  | Plasma |  |
| 1029 | p-c-reaktiivinenproteiini,pikatesti |  | 3095 | 41.23 | [6.43, 8.8, 12.04, 15.76, 21.17, 29.16, 41.93, 63.64, 96.9] |  | Plasma |  |
| 1030 | p-c-reaktiivinenproteiini,vieritutkimus | mg/l | 53 | 0 |  |  | Plasma |  |
| 1031 | p-c-reaktiivinenproteiini,vieritutkimus |  | 122 | 50.82 |  |  | Plasma |  |
| 1032 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 202 | 0 | [4.03, 6.98, 10.47, 16.6, 21.86, 29.42, 49.79, 68.66, 100] |  | Plasma |  |
| 1033 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 120 | 71.67 |  |  | Plasma |  |
| 1034 | p-c-reaktiivinenproteiini.pika |  | 316 | 20.25 | [3.75, 6.98, 11.68, 15.55, 24.24, 38.44, 58.74, 89.38, 117.91] |  | Plasma |  |
| 1035 | p-c-reaktiivinenproteiinipikahoitoyksiköt | mg/l | 4601 | 0 | [5.2, 7.99, 12.13, 17.43, 25.81, 37.54, 54.45, 78.12, 113.86] |  | Plasma |  |
| 1036 | p-c-reaktiivinenproteiinipikahoitoyksiköt |  | 1925 | 80.52 | [1.18, 1.4, 1.83, 2.44, 3.17, 4.31, 5.83, 6.68, 8.76] |  | Plasma |  |
| 1037 | p-c-reaktiivinenproteiinipikamittari |  | 399 | 36.09 | [7, 9.06, 12.92, 21.23, 28.43, 42.17, 58.76, 81.22, 122.07] |  | Plasma |  |
| 1038 | pikatesti,c-reaktiivinenproteiini | mg/l | 315 | 0 | [6, 7.85, 10.56, 14.36, 20.22, 31.25, 44.62, 61.43, 91.59] |  |  |  |
| 1039 | pikatesti,c-reaktiivinenproteiini |  | 386 | 100 |  |  |  |  |
| 1040 | plasmanc-reaktiivinenproteiiniosoitus | 1 | 36 | 0 |  |  |  |  |
| 1041 | plasmanc-reaktiivinenproteiiniosoitus | mg/l | 3255 | 0 | [6.24, 8.99, 12.45, 17.72, 25.65, 35.96, 50.8, 70.36, 106.56] |  |  |  |
| 1042 | plasmanc-reaktiivinenproteiiniosoitus |  | 2589 | 98.42 |  |  |  |  |
| 1043 | s-c-reaktiivinenproteiini | mg/l | 773 | 0 | [0.4, 0.73, 1.08, 1.43, 1.93, 2.88, 4.71, 7.16, 16.64] |  | Serum |  |
| 1044 | s-c-reaktiivinenproteiini |  | 121 | 100 |  |  | Serum |  |
| 1045 | s-c-reaktiivinenproteiini,herkkä | mg/l | 813 | 0 | [0.39, 0.59, 0.83, 1.22, 1.67, 2.46, 3.62, 5.63, 9.01] |  | Serum |  |
| 1046 | s-c-reaktiivinenproteiini,herkkä |  | 34 | 100 |  |  | Serum |  |
| 1047 | s-c-reaktiivinenproteiini,pika | mg/l | 77 | 0 | [8, 10, 12.4, 14.7, 17, 20.05, 27.4, 35, 48] |  | Serum |  |
| 1048 | s-c-reaktiivinenproteiini,pika |  | 199 | 75.88 |  |  | Serum |  |
| 1049 | s-c-reaktiivinenproteiini/ | mg/l | 191 | 0 | [0.31, 0.5, 0.7, 0.96, 1.46, 2.27, 3.04, 4.65, 10.16] |  | Serum |  |
| 1050 | s-c-reaktiivinenproteiini/ |  | 5 | 100 |  |  | Serum |  |

