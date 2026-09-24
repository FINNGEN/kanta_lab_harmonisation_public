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
Here is group 37 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|
| 1894 | -histologinensolublokkisytologisestanäytteestä |  | 214 | 100 |  |  |  |  |
| 1895 | -humanpapillomavirusgenotyyppi16 |  | 301 | 100 |  |  |  |  |
| 1896 | -humanpapillomavirusgenotyyppi18 |  | 301 | 100 |  |  |  |  |
| 1897 | -humanpapillomavirusgenotyyppimuupatogeeninenhpv |  | 252 | 100 |  |  |  |  |
| 1898 | -lisämaksukiireellisenäpyydetyllenäytteelle |  | 584 | 100 |  |  |  |  |
| 1899 | -lisätutkimuspyyntöaiemmintutkitullenäytteelle |  | 191 | 100 |  |  |  |  |
| 1900 | -lisävastaus2laskutuskuitatullenäytteelle |  | 438 | 100 |  |  |  |  |
| 1901 | -lisävastauslaskutuskuitatullenäytteelle |  | 2865 | 100 |  |  |  |  |
| 1902 | -moniresistentitgram-negatiivisetsauvat,viljely |  | 122 | 100 |  |  |  |  |
| 1903 | -moniresistentitgramnegatiivisetsauvat,viljely |  | 163 | 100 |  |  |  |  |
| 1904 | -resistentitgramnegatiivisetsauvat,viljely |  | 314 | 100 |  |  |  |  |
| 1905 | -staphylococcusaureus,metilliiniresist.viljely |  | 248 | 100 |  |  |  |  |
| 1906 | -staphylococcusaureus,metisilliiniresistentti,v |  | 540 | 100 |  |  |  |  |
| 1907 | b-glukoosi,hoitoyksikönvieritesti,kokoveri |  | 687 | 0.15 | [5.55, 5.93, 6.7, 7.42, 8.33, 9.1, 10.22, 12.18, 14.28] |  | Blood |  |
| 1908 | b-hematologisenpotilaanperuskaryotyypinmääritys |  | 125 | 100 |  |  | Blood |  |
| 1909 | b-kreatiniini,hoitoyksikönvieritesti,veri |  | 167 | 0 | [58.29, 69.03, 76.8, 84.73, 95.67, 105.12, 116.21, 134.79, 170] |  | Blood |  |
| 1910 | bakteerit,virtsasta,partikkelinlaskijalla,osatutk. |  | 212 | 100 |  |  |  |  |
| 1911 | bm-pahanlaatuisenveritaudinimmunofenotyypitys |  | 191 | 100 |  |  | Bone marrow |  |
| 1912 | bm-pahanlaatuisenveritaudinimmunofenotyyppinenjäännöstautianalyysi |  | 162 | 100 |  |  | Bone marrow |  |
| 1913 | cb-hemoglobiini,vieritestihoitoyksikössä | g/l | 101 | 0 | [84.5, 92.5, 100.5, 112.5, 121.56, 127.06, 131.83, 135.83, 146] |  | Capillary blood |  |
| 1914 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä | mmol/l | 5203 | 0 | [5.2, 6.16, 6.92, 7.87, 8.89, 10.17, 11.74, 13.96, 16.77] |  |  |  |
| 1915 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä |  | 19 | 100 | [5.33, 6.26, 7.1, 7.98, 9.1, 10.33, 11.92, 13.89, 16.96] |  |  |  |
| 1916 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella | mg/l | 771 | 0 | [2.6, 5.17, 9.64, 14.69, 22, 32.29, 47.95, 69.4, 106.84] |  |  |  |
| 1917 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella |  | 192 | 85.42 |  |  |  |  |
| 1918 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 438 | 0 | [26.9, 30, 31.94, 33, 34, 34.57, 35, 36, 37.53] |  | Erythrocyte |  |
| 1919 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 15 | 6.67 |  |  | Erythrocyte |  |
| 1920 | emäsylimäärä,laskimoverestä,pikatesti␤ | mmol/l | 373 | 0 |  |  |  |  |
| 1921 | emäsylimäärä,laskimoverestä,pikatesti␤ |  | 339 | 19.47 |  |  |  |  |
| 1922 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 203 | 0 | [0.2, 0.4, 0.66, 1, 1.3, 1.71, 2.47, 3.65, 8.32] |  |  |  |
| 1923 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. |  | 9 | 100 |  |  |  |  |
| 1924 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta | iu/ml | 24 | 0 |  |  |  |  |
| 1925 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta |  | 241 | 100 |  |  |  |  |
| 1926 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 202 | 0 | [3.19, 4.28, 5.76, 7.13, 9.35, 12.16, 16.65, 32.02, 93.76] |  |  |  |
| 1927 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. |  | 10 | 100 |  |  |  |  |
| 1928 | fp-kollageenii:nbeta-karboksiterminaalinentelopeptidi | ug/l | 299 | 0 | [0.08, 0.14, 0.17, 0.21, 0.26, 0.3, 0.36, 0.45, 0.63] |  | Fasting plasma |  |
| 1929 | happamusaste,kapillaariverestä,pikatesti␤ |  | 1262 | 0.24 |  |  |  |  |
| 1930 | happamuusaste,laskimoverestä,pikatesti␤ |  | 712 | 0.7 |  |  |  |  |
| 1931 | happiosapaine,kapillaariverestä,pikatesti␤ | kpa | 1260 | 0 |  |  |  |  |
| 1932 | happoemästasejahappi,laskimoverestä,pikatesti␤ |  | 643 | 100 |  |  |  |  |
| 1933 | hepatiittic-virus,nh,jatkotutkimus,plasmasta |  | 512 | 100 |  |  |  |  |
| 1934 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ | kpa | 707 | 0 |  |  |  |  |
| 1935 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ |  | 5 | 100 |  |  |  |  |
| 1936 | hpv-gt16aptimapanther,apututkimustulostensiirtoon |  | 149 | 100 |  |  |  |  |
| 1937 | hpv-gt18-45aptimapanther,apututkimustulostensiirtoon |  | 149 | 100 |  |  |  |  |
| 1938 | hpvaptimapanther,apututkimustulostensiirtoon |  | 413 | 100 |  |  |  |  |
| 1939 | humanimmunodeficiencyvirus,antigeenijavasta- |  | 192 | 100 |  |  |  |  |
| 1940 | humanimmunodeficiencyvirus,antigeenijavasta-aineet,yhd |  | 260 | 100 |  |  |  |  |
| 1941 | huume-jalääkeainetutkimus,laaja,varmistus |  | 448 | 100 |  |  |  |  |
| 1942 | huumeseulonta,kvalitatiivinen,virtsasta␤ |  | 140 | 100 |  |  |  |  |
| 1943 | kalium,hoitoyksikönvieritesti,veri | mmol/l | 166 | 0 | [3.34, 3.65, 3.8, 3.9, 4, 4.19, 4.3, 4.42, 4.6] |  |  |  |
| 1944 | kalium,hoitoyksikönvieritesti,veri |  | 290 | 0 | [3.4, 3.69, 3.8, 3.9, 4.06, 4.2, 4.4, 4.56, 5] |  |  |  |
| 1945 | kreatiniini,hoitoyksikönvieritesti,veri | mmol/l | 163 | 0 | [61.44, 68.7, 74.81, 78.74, 84.67, 94.44, 102.62, 112.17, 146.53] |  |  |  |
| 1946 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 874 | 0 | [2.21, 3.1, 4.22, 5.54, 6.81, 8.47, 10.55, 13.18, 17.82] |  |  |  |
| 1947 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) |  | 6 | 66.67 |  |  |  |  |
| 1948 | laajahuumeseulonta,varmistustasoinen,virtsasta |  | 944 | 100 |  |  |  |  |
| 1949 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 203 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.1, 0.4] |  |  |  |
| 1950 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. |  | 9 | 100 |  |  |  |  |
| 1951 | lisävastauslaskutuskuitatullenäytteelle |  | 214 | 100 |  |  |  |  |
| 1952 | luuntiheysmittaus,2kohdetta(nk6sa),lausuttuna |  | 145 | 100 |  |  |  |  |
| 1953 | marevan-hoidonseur.tatesti,hoitoyksikkötekeesormenpäänäyte |  | 168 | 0 |  |  |  |  |
| 1954 | moniresistentitgramnegatiivisetsauvat,viljely |  | 206 | 100 |  |  |  |  |
| 1955 | natrium,hoitoyksikönvieritesti,veri | mmol/l | 163 | 0 | [133.07, 135, 136.54, 138, 139, 139.55, 140, 141, 142] |  |  |  |
| 1956 | natrium,hoitoyksikönvieritesti,veri |  | 292 | 0 | [131.17, 133.92, 135.97, 137.29, 138.69, 139.5, 140, 141, 142] |  |  |  |
| 1957 | natriureettinenpeptidi,b-tyypinn-terminaalinenpropeptidi,plasmasta | ng/l | 159 | 0 | [27.45, 51.56, 106.33, 265.57, 634.4, 1351.3, 2903.04, 5577.84, 11032.2] |  |  |  |
| 1958 | nk-solujenosuus(määritettynäcd3-/cd16+/cd56+-soluina) | % | 665 | 0 | [4, 7.07, 9.79, 12.53, 14.84, 17.1, 21.25, 26.92, 36.91] |  |  |  |
| 1959 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. | mosm/kgh2o | 203 | 0 | [331.17, 377.3, 431.74, 500.49, 539.14, 595.38, 634.62, 686.05, 750.53] |  |  |  |
| 1960 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. |  | 9 | 100 |  |  |  |  |
| 1961 | p-natriureett.peptidin-termin.propept.vieritl | ng/l | 118 | 0 | [140.45, 226.81, 316.84, 708.93, 1117.67, 1691.6, 2121.04, 3414.6, 4866.2] |  | Plasma |  |
| 1962 | p-natriureett.peptidin-termin.propept.vieritl |  | 20 | 100 |  |  | Plasma |  |
| 1963 | p-natriureettinenpeptidi,b-tyypinn-terminaalin | ng/l | 4682 | 0 | [86.24, 151.65, 238.65, 387.07, 653.89, 1066.35, 1771.72, 3084.52, 6142.85] |  | Plasma |  |
| 1964 | p-natriureettinenpeptidi,b-tyypinn-terminaalin |  | 149 | 100 |  |  | Plasma |  |
| 1965 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi | ng/l | 1366 | 0 | [106.15, 192.31, 311.64, 535.82, 915.89, 1456.12, 2310.73, 3820.95, 6983] |  | Plasma |  |
| 1966 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi |  | 107 | 100 |  |  | Plasma |  |
| 1967 | parasiitit,ulosteesta(alkueläintenkystat,madot,madonmunat,toukat) |  | 120 | 100 |  |  |  |  |
| 1968 | pienikudoskoepala,enintään1-3samankokonaisuudennäytettä |  | 234 | 100 |  |  |  |  |
| 1969 | pika:m10inabnhp,rsvnhp,cv19nhp,yhdistelmävierit. |  | 267 | 100 |  |  |  |  |
| 1970 | pt-diffuusiokapasiteetti,single-breath-menetelmä,tavallinenperusmittaus |  | 3577 | 100 |  |  | Patient |  |
| 1971 | pt-lausuntoneurofysiologisestatutkimuksesta,hälytysindikaatiot |  | 113 | 100 |  |  | Patient |  |
| 1972 | pt-luuntiheysmittaus,2kohdetta,ilmanlausuntoa |  | 120 | 100 |  |  | Patient |  |
| 1973 | pt-sydämenkattavarakenteellinenjatoiminnallinenuä(fm1ee) |  | 177 | 100 |  |  | Patient |  |
| 1974 | pt-uloshengityksenhuippuvirtaus,vuorokausivaihtelunseuranta |  | 474 | 100 |  |  | Patient |  |
| 1975 | pt-yöpolygrafia,ambulatorinen,hyvinsuppeaunirekisteröintikotona |  | 542 | 100 |  |  | Patient |  |
| 1976 | pt-yöpolygrafia,ambulatorinen,jalkaliikerekisteröinnein |  | 102 | 100 |  |  | Patient |  |
| 1977 | pu-aerobinenjaanaerobinenbakteerityypitysjaan |  | 147 | 100 |  |  | Pus |  |
| 1978 | resistentitgramnegatiivisetsauvat,viljely |  | 320 | 100 |  |  |  |  |
| 1979 | retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 525 | 0 | [26.59, 29.88, 31.77, 32.87, 33.87, 34, 35, 35.95, 37] |  |  |  |
| 1980 | retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 5 | 100 |  |  |  |  |
| 1981 | s-humanimmunodeficiencyvirus,antigeenijavast |  | 1221 | 100 |  |  | Serum |  |
| 1982 | sikiöperäisendna:ntutkimusäidinverinäytteestä |  | 104 | 100 |  |  |  |  |
| 1983 | staphylococcusaureus,metisilliiniresistenssiviljely␤ |  | 134 | 100 |  |  |  |  |
| 1984 | staphylococcusaureus,metisilliiniresistentti(mrsa),viljely |  | 627 | 100 |  |  |  |  |
| 1985 | t-auttajasolujenosuus(määritettynäcd3+cd4+soluina) | % | 665 | 0 | [12.24, 17.15, 20.76, 25.01, 30.99, 37.63, 47.04, 52.34, 60.07] |  | Thrombocyte |  |
| 1986 | t-estäjäsolujenosuus(määritettynäcd3+cd8+soluina) | % | 665 | 0 | [14.45, 20.35, 24.03, 27.06, 32.04, 37.14, 44.33, 52.92, 66.66] |  | Thrombocyte |  |
| 1987 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella | ng/l | 7 | 0 |  |  |  |  |
| 1988 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella |  | 97 | 93.81 |  |  |  |  |
| 1989 | ts-histologinentutkimus,1-3kudosnäytettä |  | 160 | 100 |  |  | Tissue |  |
| 1990 | ts-histologinentutkimus,1-3näytettä |  | 945 | 100 |  |  | Tissue |  |
| 1991 | työpaikanhuumeseulontajavarmistus,4yhdistettä |  | 469 | 100 |  |  |  |  |
| 1992 | työpaikanhuumeseulontajavarmistus,7yhdistettä |  | 312 | 100 |  |  |  |  |
| 1993 | täydellinennimi:pt-näytteenotto0maksu,kierronulkopuolisetnäytteet |  | 1481 | 100 |  |  |  |  |
| 1994 | täydellinenverenkuva,sis.perusverenkuvanjaleukosyyttienerittelylaskennan␤ |  | 9742 | 100 |  |  |  |  |
| 1995 | u-amfetamiinijametamfetamiini,enantiomeerienerittely |  | 120 | 100 |  |  | Urine |  |
| 1996 | u-asetoniaineet,kval,vieritestihoitoyksikössä |  | 421 | 100 |  |  | Urine |  |
| 1997 | u-erytrosyytit,kval,vieritestihoitoyksikössä |  | 413 | 100 |  |  | Urine |  |
| 1998 | u-glukoosi,kvalvieritestihoitoyksikössä |  | 423 | 100 |  |  | Urine |  |
| 1999 | u-happamuusaste,vieritestihoitoyksikössä |  | 400 | 0.25 | [5.5, 5.5, 5.5, 5.9, 6, 6, 6.5, 7, 7] |  | Urine |  |
| 2000 | u-huume-jalääkeainetutkimus,laaja,varmistus |  | 175 | 100 |  |  | Urine |  |
| 2001 | u-huume-jalääkeainetutkimus,semikvantitatiivinen,virtsa␤sta |  | 121 | 100 |  |  | Urine |  |
| 2002 | u-huumeseulonta,laaja(kvalitatiivinenlc-tof-ms) |  | 144 | 100 |  |  | Urine |  |
| 2003 | u-kemiallinenseulonta,vieritestihoitoyksikössä |  | 104 | 100 |  |  | Urine |  |
| 2004 | u-kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 398 | 0 | [2.13, 2.88, 3.69, 4.73, 6, 7.61, 9.67, 12.44, 16.61] |  | Urine |  |
| 2005 | u-laajahuume-jalääkeainetutkimus,semikvantitatiivinen |  | 421 | 100 |  |  | Urine |  |
| 2006 | u-leukosyytit,kval,vieritestihoitoyksikössä |  | 429 | 100 |  |  | Urine |  |
| 2007 | u-nitriitti,kval,vieritestihoitoyksikössä |  | 421 | 100 |  |  | Urine |  |
| 2008 | u-proteiini,kval,vieritestihoitoyksikössä |  | 425 | 100 |  |  | Urine |  |
| 2009 | vieritestilaite(epoc)verikaasuanalyysilaskimonäytteestä |  | 162 | 100 |  |  |  |  |
| 2010 | yersinia(lajitenterocolitica,pseudotuberculosis,pestis)nho,ulosteesta␤ |  | 484 | 100 |  |  |  |  |

