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
Here is group 162 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 13068 | -cd4-solujensuhdecd8-soluihin |  | 667 | 0.3 | [0.26, 0.37, 0.55, 0.73, 1, 1.35, 1.81, 2.32, 3.03] |  |  |  |
| 13069 | -kt/v,daugirdaksenkaava |  | 176 | 0 | [1.13, 1.23, 1.29, 1.33, 1.39, 1.43, 1.46, 1.5, 1.57] |  |  |  |
| 13070 | -sieni,natiivivalmiste |  | 244 | 100 |  |  |  |  |
| 13071 | ab-aktuaalibikarbonaatti | mmol/l | 14354 | 0 | [18.76, 21.02, 22.57, 23.76, 24.73, 25.7, 26.99, 28.55, 31.59] |  | Arterial blood |  |
| 13072 | ab-aktuaalibikarbonaatti |  | 47 | 100 |  |  | Arterial blood |  |
| 13073 | ab-lämpötila(he-tase) | aste | 418 | 0 | [36.38, 36.95, 37, 37, 37, 37, 37.01, 37.48, 38.01] |  | Arterial blood |  |
| 13074 | ab-standardibikarbonaatti | mmol/l | 4434 | 0 | [19.73, 21.71, 22.89, 23.76, 24.46, 25.22, 26.01, 27.04, 28.87] |  | Arterial blood |  |
| 13075 | ab-standardibikarbonaatti |  | 20 | 100 |  |  | Arterial blood |  |
| 13076 | alkalinenfosfataasi | u/l | 4090 | 0 | [51.93, 59.73, 66.52, 72.54, 78.85, 86.09, 95.45, 111.37, 142.22] |  |  |  |
| 13077 | alkalinenfosfataasi |  | 409 | 100 |  |  |  |  |
| 13078 | angiotensiini-1-konvertaasi | u/l | 286 | 0 | [21.5, 28.51, 36.37, 41.21, 48.76, 54.44, 63.62, 70.94, 80.3] |  |  |  |
| 13079 | angiotensiini-1-konvertaasi |  | 20 | 100 |  |  |  |  |
| 13080 | b-diffi,erittelylaskenta,klooni |  | 142 | 100 |  |  | Blood |  |
| 13081 | cb-standardibikarbonaatti | mmol/l | 10798 | 0 | [20.28, 22.23, 23.36, 24.16, 24.9, 25.66, 26.58, 27.89, 30.19] |  | Capillary blood |  |
| 13082 | cb-standardibikarbonaatti |  | 90 | 50 |  |  | Capillary blood |  |
| 13083 | d-vitamiini-25-oh,d3-jad2-muodot | nmol/l | 219 | 0 | [48.54, 55.58, 61.96, 68.73, 74.1, 79.27, 84.22, 89.91, 106.45] |  |  |  |
| 13084 | d-vitamiini-25-oh,plasmasta | nmol/l | 694 | 0 | [44.59, 53.15, 59, 64.66, 69.89, 76.01, 82.54, 92.02, 105.7] |  |  |  |
| 13085 | e-punasolujenkokojakaum | % | 55570 | 0 | [12.19, 12.59, 12.95, 13.26, 13.67, 14.09, 14.51, 14.98, 15.71] |  | Erythrocyte |  |
| 13086 | e-punasolujenkokojakaum |  | 7 | 71.43 |  |  | Erythrocyte |  |
| 13087 | e-punasolujenkokojakauma | % | 196935 | 0 | [12, 13, 13, 13, 13.69, 14, 14.05, 15, 16.37] |  | Erythrocyte |  |
| 13088 | e-punasolujenkokojakauma |  | 1688 | 46.92 | [15, 15, 15.98, 16, 16, 16.41, 17, 18, 19.59] |  | Erythrocyte |  |
| 13089 | e-rdw,punasolujenkokojakauma | % | 25929 | 0 | [12.08, 13, 13, 13.03, 14, 14, 15, 15.7, 17.03] |  | Erythrocyte |  |
| 13090 | e-rdw,punasolujenkokojakauma |  | 76 | 100 |  |  | Erythrocyte |  |
| 13091 | ekg,hoitoyksikönottama |  | 213 | 100 |  |  |  |  |
| 13092 | ekgasiakkaanottama |  | 257 | 100 |  |  |  |  |
| 13093 | erikoislääkärinkonsultaatio |  | 118 | 100 |  |  |  |  |
| 13094 | folaatti(fe-folaat) | nmol/l | 320 | 0 | [1456.69, 1642.98, 1740.68, 1864.47, 2021, 2152.9, 2311.39, 2519.36, 2775.52] |  |  |  |
| 13095 | folaatti(fe-folaat) |  | 12 | 100 |  |  |  |  |
| 13096 | fosfaatti,epäorgaaninen | mmol/l | 275 | 0 | [0.83, 0.93, 0.99, 1.05, 1.1, 1.15, 1.23, 1.36, 1.64] |  |  |  |
| 13097 | fosfaatti,epäorgaaninen |  | 13 | 100 |  |  |  |  |
| 13098 | fp-fosfaatti,epäorgaaninen | mmol/l | 1537 | 0 | [0.81, 0.94, 1.04, 1.12, 1.21, 1.31, 1.45, 1.64, 2] |  | Fasting plasma |  |
| 13099 | fp-fosfaatti,epäorgaaninen |  | 7 | 100 |  |  | Fasting plasma |  |
| 13100 | fp-parathormoni(intakti) | ng/l | 167 | 0 | [34.58, 43.28, 53.6, 64.34, 75.77, 88.59, 106.04, 128.88, 166.07] |  | Fasting plasma |  |
| 13101 | fp-parathormoni,intakti | ng/l | 443 | 0 | [42.85, 55.73, 66.85, 78.78, 88.68, 102.07, 115.78, 136.81, 193.49] |  | Fasting plasma |  |
| 13102 | fp-parathormoni,intakti | pmol/l | 213 | 0 | [5.11, 7.29, 9.06, 12.26, 16.48, 21.96, 29.55, 41.46, 57.9] |  | Fasting plasma |  |
| 13103 | fp-parathormoni,intakti |  | 5 | 60 |  |  | Fasting plasma |  |
| 13104 | fp-reniini,konsentraatio | mu/l | 275 | 0 | [1.9, 3.7, 5.72, 9.15, 13.8, 21.38, 36.23, 69.29, 149] |  | Fasting plasma |  |
| 13105 | fp-reniini,konsentraatio |  | 9 | 100 |  |  | Fasting plasma |  |
| 13106 | fras,oksidatiivinenstressi |  | 508 | 100 |  |  |  |  |
| 13107 | fs-alkalinenfosfataasi | u/l | 114 | 0 |  |  | Fasting serum |  |
| 13108 | fs-angiotensiini-1-konvertaasi | u/l | 168 | 0 | [21.95, 28.78, 36.13, 43.17, 50.38, 57.02, 63.03, 69.31, 88.3] |  | Fasting serum |  |
| 13109 | fs-angiotensiini-1-konvertaasi |  | 17 | 100 |  |  | Fasting serum |  |
| 13110 | fs-monikanava4-7tthperuspaketti |  | 125 | 100 |  |  | Fasting serum |  |
| 13111 | fs-työterveyshuollonperuspaketti |  | 141 | 100 |  |  | Fasting serum |  |
| 13112 | ilmajohtotarv.luujohto |  | 785 | 100 |  |  |  |  |
| 13113 | korona-rs-influenssa,pcrpikatesti |  | 6428 | 100 |  |  |  |  |
| 13114 | kreatiinikinaasi | u/l | 821 | 0 | [51.45, 67.28, 78.98, 91.33, 108.19, 125.74, 161.13, 224.43, 350.78] |  |  |  |
| 13115 | l-basofiilit,automaatio | % | 10670 | 0 | [0, 0, 0.5, 1, 1, 1, 1, 1, 1] |  | Leukocyte |  |
| 13116 | l-eosinofiilit,automaatio | % | 10670 | 0 | [0.35, 1, 1.93, 2, 2.74, 3, 3.97, 4.81, 6.33] |  | Leukocyte |  |
| 13117 | l-lymfosyytit,automaatio | % | 19279 | 0 | [15.56, 20.42, 24.04, 26.95, 29.66, 32.37, 35.21, 38.75, 43.79] |  | Leukocyte |  |
| 13118 | l-lymfosyytit,automaatio |  | 23 | 100 |  |  | Leukocyte |  |
| 13119 | l-monosyytit,automaatio | % | 19276 | 0 | [5.94, 6.98, 7.19, 8, 8.78, 9.04, 10, 11, 12.64] |  | Leukocyte |  |
| 13120 | l-monosyytit,automaatio |  | 23 | 100 |  |  | Leukocyte |  |
| 13121 | l-neutrofiilit,automaatio | % | 19277 | 0 | [41.43, 47.16, 50.99, 54.23, 57.08, 59.98, 63.15, 67.08, 72.76] |  | Leukocyte |  |
| 13122 | l-neutrofiilit,automaatio |  | 23 | 100 |  |  | Leukocyte |  |
| 13123 | laktaattidehydrogenaasi | u/l | 112 | 0 | [166.9, 176.25, 189.57, 200, 217.89, 228.73, 246.21, 285.8, 336.3] |  |  |  |
| 13124 | p-aktuaalinenbikarbonaatti | mmol/l | 1258 | 0 | [20.16, 23.03, 24.56, 25.84, 26.91, 27.87, 28.97, 30.03, 32.38] |  | Plasma |  |
| 13125 | p-alkaalinenfosfataasi | u/l | 218 | 0 | [54.87, 64.51, 69.29, 74.44, 80.78, 89.02, 97.67, 107.93, 128.13] |  | Plasma |  |
| 13126 | p-alkaalinenfosfataasi |  | 6 | 16.67 |  |  | Plasma |  |
| 13127 | p-alkalinenfosfataasi | u/l | 26335 | 0 | [51.5, 59.65, 66.46, 73.03, 79.94, 87.78, 97.91, 113.11, 149.16] |  | Plasma |  |
| 13128 | p-alkalinenfosfataasi |  | 74 | 91.89 |  |  | Plasma |  |
| 13129 | p-bilirubiinikonjugaatit | umol/l | 1839 | 0 | [2.92, 3, 3.32, 4, 4.89, 5.93, 7.57, 10.11, 21.15] |  | Plasma |  |
| 13130 | p-bilirubiinikonjugaatit |  | 168 | 100 |  |  | Plasma |  |
| 13131 | p-fosfaatti,epäorgaaninen | mmol/l | 436 | 0 | [0.89, 0.99, 1.06, 1.13, 1.2, 1.27, 1.36, 1.47, 1.66] |  | Plasma |  |
| 13132 | p-kreatiinikinaasi | u/l | 2765 | 0 | [43.61, 57.48, 70.52, 85.33, 100.93, 124.44, 165.61, 239.04, 491.32] |  | Plasma |  |
| 13133 | p-kreatiinikinaasi |  | 21 | 95.24 |  |  | Plasma |  |
| 13134 | p-laktaattidehydrogenaasi | u/l | 3272 | 0 | [163.71, 178.57, 190.98, 203.43, 216.38, 231.67, 254.03, 288.21, 372.84] |  | Plasma |  |
| 13135 | p-laktaattidehydrogenaasi |  | 29 | 96.55 |  |  | Plasma |  |
| 13136 | p-lupusantikoagulantti |  | 220 | 100 |  |  | Plasma |  |
| 13137 | p-psavapaanosuustotaalista | % | 719 | 0 | [10.55, 13.9, 16.1, 18.77, 21.1, 23.88, 26.7, 30.17, 36.09] |  | Plasma |  |
| 13138 | p-urea,resirkulaatio | mmol/l | 200 | 0 | [4.65, 12.03, 14.2, 15.66, 16.84, 18.43, 19.52, 21.22, 23.14] |  | Plasma |  |
| 13139 | psa-vapaa/totaali-suhde,plasmasta | % | 1183 | 0 | [8.11, 11.04, 13.43, 15.83, 18.18, 20.89, 24.81, 29.88, 39.78] |  |  |  |
| 13140 | psa-vapaa/totaali-suhde,plasmasta |  | 3428 | 100 |  |  |  |  |
| 13141 | psavapaanjatotaalinsuhde | % | 62 | 0 |  |  |  |  |
| 13142 | psavapaanjatotaalinsuhde |  | 180 | 97.78 |  |  |  |  |
| 13143 | pt-vaativainhalaatiohoito |  | 114 | 100 |  |  | Patient |  |
| 13144 | punasolojenkokojakauma | % | 1068 | 0 | [12, 12.05, 13, 13, 13, 13, 13.97, 14, 14.47] |  |  |  |
| 13145 | punasolojenkokojakauma |  | 7 | 100 |  |  |  |  |
| 13146 | punasolujenerittelylaskenta | % | 41 | 0 |  |  |  |  |
| 13147 | punasolujenerittelylaskenta |  | 433 | 6 | [12, 12, 12.18, 13, 13, 13, 13, 13.97, 14] |  |  |  |
| 13148 | punasolujenesiasteet(erytroblastit) | e9/l | 1040 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |
| 13149 | punasolujenesiasteet(erytroblastit) |  | 24 | 100 |  |  |  |  |
| 13150 | punasolujenkokojakauma | % | 155883 | 0 | [12.28, 13, 13, 13.02, 14, 14, 15, 15.9, 17] |  |  |  |
| 13151 | punasolujenkokojakauma |  | 2478 | 99.48 |  |  |  |  |
| 13152 | punasolujenkokojakautuma | % | 683 | 0 | [13, 13, 13, 13, 13, 14, 14, 14, 14.95] |  |  |  |
| 13153 | punasolujenkoonvaihtelu | % | 2031 | 0 | [12.51, 12.91, 13.17, 13.34, 13.62, 13.91, 14.31, 14.86, 15.92] |  |  |  |
| 13154 | punasolut,kokojakauma | % | 121 | 0 | [13, 13, 13, 13, 14, 14, 14, 14, 15] |  |  |  |
| 13155 | s-alkalinenfosfataasi | u/l | 368 | 0 | [52.79, 63.98, 76.35, 87.37, 103.68, 118.86, 131.06, 146.22, 181.47] |  | Serum |  |
| 13156 | s-alkalinenfosfataasi,isoentsyymit |  | 318 | 100 |  |  | Serum |  |
| 13157 | s-glykoproteiininasetylaatio | mmol/l | 265 | 0 | [0.75, 0.79, 0.81, 0.83, 0.85, 0.88, 0.9, 0.94, 1] |  | Serum |  |
| 13158 | s-neuronispesifinenenolaasi | ug/l | 105 | 0 |  |  | Serum |  |
| 13159 | s-nightingale-mittaus |  | 265 | 100 |  |  | Serum |  |
| 13160 | s-psavapaanjatotaalinsuhde | % | 106 | 0 | [11, 13, 14.4, 16.35, 19, 21, 23.87, 27, 31.9] |  | Serum |  |
| 13161 | s-psavapaanjatotaalinsuhde |  | 264 | 100 |  |  | Serum |  |
| 13162 | s-tymidiinikinaasi | u/l | 237 | 0 | [3.92, 4.79, 5.63, 6.48, 7.24, 8.95, 10.78, 13.93, 39.38] |  | Serum |  |
| 13163 | s-vapaanjakokonais-psa:nsuhde | % | 643 | 0 | [11.89, 14.35, 17.11, 19.53, 21.76, 24, 27.79, 31.6, 36.6] |  | Serum |  |
| 13164 | s-vapaanjakokonais-psa:nsuhde |  | 1561 | 100 |  |  | Serum |  |
| 13165 | sars-cov-2,influenssaa,bja |  | 161 | 100 |  |  |  |  |
| 13166 | sars-cov-2-antigeenitesti,pikatesti |  | 101 | 100 |  |  |  |  |
| 13167 | tth-pakettia(ilmanpaastoa) |  | 1079 | 100 |  |  |  |  |
| 13168 | tth:ssavirtsanprotjagluk |  | 294 | 100 |  |  |  |  |
| 13169 | u-solut,peruslaskenta |  | 1772 | 100 |  |  | Urine |  |
| 13170 | vb-aktuaalibikarbonaatti | mmol/l | 1612 | 0 | [16.94, 19.74, 21.93, 23.14, 24.18, 25.06, 26.96, 28.44, 30.92] |  | Venous blood |  |
| 13171 | vb-aktuaalibikarbonaatti |  | 185 | 17.3 | [20.1, 23.3, 24.38, 25.39, 26.05, 26.8, 27.78, 28.4, 29.7] |  | Venous blood |  |
| 13172 | vb-standardibikarbonaatti | mmol/l | 13754 | 0 | [20.04, 21.93, 23.08, 23.95, 24.68, 25.36, 26.13, 27.07, 28.82] |  | Venous blood |  |
| 13173 | vb-standardibikarbonaatti |  | 44 | 100 |  |  | Venous blood |  |
| 13174 | virtsansolujenhl7-siirtoon | e6/l | 5551 | 0 | [0.1, 0.37, 0.65, 1.07, 1.65, 2.44, 3.88, 6.78, 14.04] |  |  |  |
| 13175 | virtsansolujenhl7-siirtoon |  | 353 | 11.05 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |
| 13176 | zb-aktuaalibikarbonaatti | mmol/l | 394 | 0 | [22, 23, 23.94, 24, 25, 26, 27, 27.8, 29.78] |  | Central blood |  |

