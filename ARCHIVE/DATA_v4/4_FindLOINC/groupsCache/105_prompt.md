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
- `UNIT` — the measurement unit as recorded locally (e.g. `mmol/l`, `g/l`, `%`, `U/l`, `E9/l`). May be empty, and may be wrong — see below.
- `unit_share` — what percentage of this `TEST_NAME`'s records carry this row's `UNIT`. A unit holding a few percent of a code's records while another unit holds the rest is usually a data-entry error, not a second real test.
- `n` — how many result records exist for this test/unit combination.
- `value_missing_p` — percentage (0-100) of those records with no numeric value.
- `value_deciles` — the 9 deciles of the observed numeric values, when available.
- `LongName` — the official Finnish long name from the national code table, when the code could be matched. Often empty.
- `prefix_meaning` — the decoded system prefix (e.g. "Serum", "Fasting plasma", "Urine"), when recognised. Derived from the code text, so a strong but not infallible hint.
- `suffix_meaning` — the decoded suffix (e.g. "Qualitative test (also semi-quantitative)", "Antibodies", "Culture"), when recognised.

# Important caveats about this data

- These codes are collected from MANY different Finnish healthcare source systems over decades. They are **not** clean national codes: they may be locally invented, abbreviated differently, truncated, concatenated with several alternative spellings separated by commas, contain typos, or be a bare number that was never resolved to an abbreviation.
- Columns are frequently empty. An empty column means "unknown", never "not applicable".
- **Your name is a search query, not a verdict — so guess whenever the code gives you anything to work with.** It is fed to a semantic search over the real LOINC vocabulary, and a later step is shown the concepts that came back and makes the actual choice. A guess that is close but not exactly right still pulls the right neighbourhood of concepts, and that step can pick correctly from them. **Being wrong here is cheap; being empty is not.** An empty name retrieves nothing, so the code is dropped from consideration entirely and can never be mapped.
- **Leave the name empty only when the code text carries no usable hint at all** — a bare running number, an administrative label with no analyte in it, a string too garbled for any analyte to be read out of it. If you can read an analyte, or a specimen, or even the test family, write a name. Declining is the next step's job, not yours: it is the one that can compare your guess against real concepts and conclude that none of them fits.
- The rows have been **grouped by string similarity** of `TEST_NAME`, so that near-identical codes appear together. A sibling row can help you *read* a truncated or misspelled name — seeing `kudostransglutaminaasi,igavasta-aineet` next to `kudostransglutaminaasi,iga-vasta-aineet` tells you what the run-together one says. That is the only thing the group is for. It is a bag of codes that look alike, not a set of codes that are the same test, and it never supplies a row with a unit or a quantity it does not have itself.

# How to read the evidence

A row is one **`TEST_NAME` + `UNIT`** combination, and that pair is what you are naming. Two rows of the same code with different units are two different observations and may well belong to two different LOINC concepts. Decide each row on its own.

**The name is the source of truth.** `prefix_meaning` and `suffix_meaning` were derived from the `TEST_NAME` string by an earlier step, so when a name is misspelled, truncated or locally invented, the decoded prefix and suffix are wrong in exactly the same way. Treat them as extra information that can confirm what the name says — never as something that outranks it. The specimen in particular is often spelled out as a Finnish word rather than carried by a prefix: `veri` = blood, `seerumi` = serum, `plasma` = plasma, `virtsa` = urine, `likvori` = cerebrospinal fluid, `uloste` = feces, `sylki` = saliva. `c-reaktiivinenproteiini,pikatesti,veri` names blood and has no decoded prefix at all — and its leading `c-` is the start of "C-reactive", not a specimen code.

**Missing values are not evidence.** `value_missing_p` describes this extract, not the laboratory test: a row with no values is a row where the numbers were not recorded or not carried through. Never conclude "no numbers, therefore qualitative". A test is qualitative when the CODE says so — the `-O` suffix, a `LongName` naming a qualitative or screening test, a component only ever reported as detected/not-detected.

**Never borrow from another row.** The rows are grouped by string similarity of `TEST_NAME`, so a group is a bag of codes that merely look alike. A neighbouring row's unit is not evidence about this row, and the same code can also appear in another group carrying units you cannot see here — so the units visible around you are not the units this code uses. Do not take a unit, a quantity or an answer from a sibling row, not even from a row whose `TEST_NAME` is identical.

**What you may conclude depends on what the row actually has.** The `evidence_level` column states it. Every row has a name; the label says what is there *in addition*:

| `evidence_level` | what the row has | what you may do |
|---|---|---|
| `name+unit+values` | a unit and a value distribution | The strongest case. If the values contradict the unit, distrust the **unit** — units are typed by hand at hundreds of source systems and are often wrong, especially at a low `unit_share` — and decide as if the unit were absent. |
| `name+unit` | a unit, no values | Trust the unit. It is the only quantity evidence there is, and it is usually right. |
| `name+values` | values, no unit | Read the quantity off the magnitudes. Creatinine at 60-110 is µmol/l and takes `[Moles/volume]`; the same analyte at 0.6-1.2 is mg/dl and takes `[Mass/volume]`. |
| `name` | neither | **You cannot fix the quantity — but you can still aim the search.** Name the analyte and the specimen you can read, and take the plainest property the analyte is ordinarily reported in; where you have no basis at all for one, leave the brackets off rather than inventing a quantity. Do not copy a sibling's unit. The search is driven mostly by the component and system, so a name with an uncertain property still retrieves the right family of concepts and lets the next step choose the quantity from real candidates. |

**Some units are ratios, not concentrations.** `mmol/mol` is HbA1c IFCC, a substance ratio. `mg/mmol` is an albumin/creatinine ratio. `ml/min/173m2` is eGFR, a rate per body surface area. `%` is ambiguous by nature: it may be a fraction of a cell population, a fraction of a total mass, or activity as a percentage of normal.

**A repeated lowest decile is a detection limit, not a measurement.** When the first deciles are the same round number — `[5, 5, 6.2, 8.3, ...]` — the assay is censored at that floor and everything below was reported as "<5". Read the floor as the assay's sensitivity rather than the population's real low end: a CRP censored at 5 mg/l is an ordinary CRP, while a high-sensitivity assay reads down to about 0.1 mg/l, so that floor argues *against* a high-sensitivity concept.

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

   Choose the property from the **unit and the magnitude of the values** of this row, never from the analyte name: the same analyte is a different LOINC term in `mmol/l` and in `mg/l`. Apply the evidence rules above — and where this row has neither a unit nor values, take the analyte's ordinary form rather than a sibling row's unit.
3. **The system follows `in`**: `in Serum or Plasma`, `in Blood`, `in Urine`, `in Cerebral spinal fluid`, `in Stool`, `in Red Blood Cells`. LOINC uses the combined `Serum or Plasma` for most routine chemistry; take the narrow `Serum` or `Plasma` only when the test is genuinely specific to one. Fasting is NOT part of the system — `fS` is still serum.
4. **The timing is folded into the system slot** when it is not a plain spot sample: `in 24 hour Urine`, `in 2 hour Urine`. A normal point-in-time sample is LOINC's default and is written nowhere in the name — do not add "point in time".
5. **The method follows `by`, and only when it changes the clinical interpretation**: `by Automated count`, `by Test strip`, `by Culture`, `by Organism specific culture`, `by Immunoassay`, `by NAA with probe detection`, `by Electrophoresis`, `by calculation`. LOINC deliberately omits Method for most chemistry. **Leave it off unless the code states one.** Inventing a method makes the search miss the plain term that was the right answer.
6. **The scale is not written as a word.** It shows in the shape of the name: a quantitative test carries its property in brackets; an ordinal/qualitative one is `[Presence]`; a nominal identification drops the brackets entirely and reads `Bacteria identified in Urine by Culture`. A fraction of a cell population also drops the brackets: `Lymphocytes/Leukocytes in Blood`. Decide this from the code, never from how many values happen to be missing.
7. **Panels are named differently, and you must write a panel name when the code orders a bundle.** A panel is an order that bundles several separately reported tests, so it is not one measurable quantity and its name is not built from the ordinary template:

   - The word **`panel`** appears in the name — it does in 81% of LOINC's panel concepts.
   - There is normally **no `[Property]`**: only 6% of panel concepts carry one, because a bundle has no single kind of quantity. Do not invent one.
   - The **system follows a dash**, not `in`: `- Blood`, `- Serum or Plasma`, `- Urine`.
   - A method may still follow `by`, when the bundle is method-specific.

   So: `CBC panel - Blood by Automated count`, `Free T4 and TSH panel - Serum or Plasma`, `Urinalysis macro (dipstick) panel - Urine`, `Platelet aggregation panel - Platelet rich plasma`, `Eastern equine encephalitis virus IgG and IgM panel - Serum by Immunofluorescence`. Some panels name no system at all: `12 lead EKG panel`, `Polysomnography panel`.

   Finnish codes signal a bundle in several ways: a `LongName` that lists several analytes joined by `ja` ("and"); the endings `-seula` / `-seulonta` (screen) and `-paketti` (package); and the established blood-count abbreviations — `B-PVK` (perusverenkuva, the basic count) and `B-TVK` (taydellinen verenkuva, the complete count with a differential). Match the panel's breadth to the code: a basic count and a count with a differential are different concepts.

   If the evidence does not clearly say the code orders a bundle, write an ordinary single-test name. A panel name on a single reported result is as wrong as the reverse.
8. **Name the plainest test the code supports.** Do not add a qualifier the code does not state: no method, no `--trough` / `--post dose` challenge, no narrowing of `Serum or Plasma` to `Capillary blood` or `Platelet poor plasma` unless the code says so. LOINC has both a plain and a qualified concept for most tests, and a qualifier you invented aims the search at the wrong one.

There are exceptions to the template — some names put a body site first (`Left ventricular Ejection fraction by US.2D`), some append a challenge after a double dash (`Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose`) — but if you follow the template above you will be right for the overwhelming majority of laboratory tests, which is what this data is.

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `loinc_name_guess` — the Long Common Name you believe this code maps to, spelled as LOINC would, **including a panel name when the code orders a bundle**. Empty **only** when the code text carries no usable hint at all. A row with no unit and no values still gets a name: the missing quantity is the next step's problem, not a reason to stay silent.

Return an entry for EVERY row of the table, including rows you can say almost nothing about.

Additionally, return a short `reflection` (a few sentences to a short paragraph, markdown) covering: ideas to improve this process, gotchas and ambiguities you hit in THIS group, systematic problems in the data, and anything that would have helped you decide. Be concrete and specific to the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 105 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 8512 | p-adam13 | % | 95% | name+unit+values | 292 | 0 | [22.2, 37.98, 43.11, 48.45, 54.49, 61.91, 68.59, 80.67, 92.98] | P -ADAMTS13, aktiivisuus, plasmasta | Plasma |  |
| 8513 | p-adam13 |  | 5% | name | 16 | 100 |  | P -ADAMTS13, aktiivisuus, plasmasta | Plasma |  |
| 8514 | p-afxaapi | ug/l | 83% | name+unit+values | 885 | 0 | [28.54, 41.81, 56.02, 69.84, 87.39, 115.17, 139.04, 176.98, 252.81] | P -Apiksabaani, estovaikutus hyytymistekijä Xa:han | Plasma |  |
| 8515 | p-afxaapi |  | 17% | name | 175 | 100 |  | P -Apiksabaani, estovaikutus hyytymistekijä Xa:han | Plasma |  |
| 8516 | p-afxariv | ug/l | 60% | name+unit+values | 267 | 0 | [22.28, 30.54, 37.21, 46.02, 57.42, 75.62, 109.39, 173.07, 263.74] | P -Rivaroksabaani, estovaikutus hyytymistekijä Xa:han | Plasma |  |
| 8517 | p-afxariv |  | 40% | name | 177 | 100 |  | P -Rivaroksabaani, estovaikutus hyytymistekijä Xa:han | Plasma |  |
| 8518 | p-apcres | form | 5% | name+unit | 14 | 0 |  | P -APC-resistenssi | Plasma |  |
| 8519 | p-apcres |  | 95% | name+values | 261 | 100 | [1.8, 2, 2.5, 2.74, 2.87, 2.98, 3.02, 3.18, 3.5] | P -APC-resistenssi | Plasma |  |
| 8520 | p-apcres. | form | 99% | name+unit+values | 3154 | 0 | [2.46, 2.7, 2.8, 2.87, 2.9, 3, 3, 3.1, 3.2] |  | Plasma |  |
| 8521 | p-apcres. |  | 1% | name | 38 | 100 |  |  | Plasma |  |
| 8522 | p-apot |  | 100% | name | 113 | 100 |  |  | Plasma |  |
| 8523 | p-aptt | s | 98% | name+unit+values | 145452 | 0 | [24.74, 26.02, 27.07, 28.48, 29.86, 31.14, 33.13, 36.35, 45.81] | P -Tromboplastiiniaika, aktivoitu, partiaalinen | Plasma |  |
| 8524 | p-aptt |  | 2% | name | 3095 | 100 |  | P -Tromboplastiiniaika, aktivoitu, partiaalinen | Plasma |  |
| 8525 | p-aptt-l |  | 100% | name | 1896 | 100 |  |  | Plasma |  |
| 8526 | p-aptt. | s | 96% | name+unit+values | 829 | 0 | [24.98, 26.3, 27.53, 28.64, 29.69, 30.7, 32, 33.93, 38.41] |  | Plasma |  |
| 8527 | p-aptt. |  | 4% | name | 38 | 100 |  |  | Plasma |  |
| 8528 | p-apttm/m |  | 100% | name+values | 1897 | 100 | [0.9, 0.93, 0.95, 0.96, 0.98, 1, 1.04, 1.06, 1.11] |  | Plasma |  |
| 8529 | p-apttspr | s | 78% | name+unit+values | 146 | 0 | [31.44, 32.4, 33.4, 34.93, 35.75, 36.34, 37.27, 38.68, 43.4] |  | Plasma |  |
| 8530 | p-apttspr |  | 22% | name | 41 | 100 |  |  | Plasma |  |
| 8531 | p-ca++hoi | mmol/l | 7% | name+unit | 11 | 0 |  |  | Plasma |  |
| 8532 | p-ca++hoi |  | 93% | name+values | 157 | 100 | [1.1, 1.13, 1.15, 1.17, 1.19, 1.21, 1.22, 1.24, 1.26] |  | Plasma |  |
| 8533 | p-citratm |  | 100% | name | 1692 | 100 |  |  | Plasma |  |
| 8534 | p-clhoi | mmol/l | 100% | name+unit+values | 161 | 0 | [96.78, 99.15, 100.83, 102, 103, 104.79, 105.84, 106.7, 108.47] |  | Plasma |  |
| 8535 | p-f8paiv | % | 95% | name+unit+values | 216 | 0 | [39.62, 76.99, 102.21, 114.35, 129.3, 143.4, 157.7, 196.99, 246.74] |  | Plasma |  |
| 8536 | p-f8paiv |  | 5% | name | 11 | 100 |  |  | Plasma |  |
| 8537 | p-fii | % | 48% | name+unit+values | 879 | 0.23 | [61.57, 76.44, 83.11, 88.29, 93.18, 97.78, 102.21, 107.17, 113.51] | P -Protrombiini | Plasma |  |
| 8538 | p-fii |  | 52% | name+values | 964 | 100 | [77.3, 84.03, 87.1, 90.88, 93.17, 96.37, 100.57, 105.9, 112.5] | P -Protrombiini | Plasma |  |
| 8539 | p-fix | % | 95% | name+unit+values | 1416 | 0 | [47.55, 70.85, 82.85, 93.25, 101.17, 110, 119.02, 128.99, 143.26] | P -Hyytymistekijä IX | Plasma |  |
| 8540 | p-fix |  | 5% | name | 76 | 100 |  | P -Hyytymistekijä IX | Plasma |  |
| 8541 | p-fs-mix |  | 100% | name+values | 1895 | 100 | [28.6, 29.05, 29.55, 30, 30.68, 31, 31.77, 34.32, 37.6] |  | Plasma |  |
| 8542 | p-fsl-mix |  | 100% | name+values | 1894 | 100 | [27.66, 28.22, 29, 29.5, 30, 30.17, 31, 31.97, 33.87] |  | Plasma |  |
| 8543 | p-fsl/fs |  | 100% | name+values | 1889 | 100 | [0.93, 0.98, 1.01, 1.03, 1.06, 1.1, 1.14, 1.19, 1.29] |  | Plasma |  |
| 8544 | p-fvii | % | 90% | name+unit+values | 1818 | 0.11 | [48.8, 69.53, 86.15, 96.16, 104.36, 113.05, 122.83, 135.25, 151.88] | P -Hyytymistekijä VII | Plasma |  |
| 8545 | p-fvii |  | 10% | name+values | 196 | 100 | [67.45, 82.23, 90.82, 98.85, 107.17, 113, 125.69, 137.67, 161.9] | P -Hyytymistekijä VII | Plasma |  |
| 8546 | p-fviii | % | 87% | name+unit+values | 4777 | 0.04 | [77.4, 100.3, 119.2, 140.02, 160.19, 184.44, 211.4, 247.19, 311.94] | P -Hyytymistekijä VIII | Plasma |  |
| 8547 | p-fviii | form | 0% | name+unit | 7 | 0 |  | P -Hyytymistekijä VIII | Plasma |  |
| 8548 | p-fviii |  | 13% | name+values | 696 | 100 | [83.7, 100.38, 111.11, 124.39, 139.14, 161.05, 180.1, 202.21, 238.65] | P -Hyytymistekijä VIII | Plasma |  |
| 8549 | p-fviii. | % | 93% | name+unit+values | 28767 | 0 | [100.3, 128.09, 149.07, 170.88, 193.18, 217.07, 245.88, 283.52, 344.17] |  | Plasma |  |
| 8550 | p-fviii. |  | 7% | name+values | 2051 | 100 | [102.57, 121.76, 137.04, 153.56, 169.71, 188.24, 205.8, 229.29, 273.79] |  | Plasma |  |
| 8551 | p-fviiikr | % | 71% | name+unit | 124 | 0 |  |  | Plasma |  |
| 8552 | p-fviiikr |  | 29% | name | 51 | 100 |  |  | Plasma |  |
| 8553 | p-fviiire | % | 75% | name+unit | 251 | 0.4 |  | P-Hyytymistekijä VIII, rekombinantti | Plasma |  |
| 8554 | p-fviiire | form | 7% | name+unit | 23 | 0 |  | P-Hyytymistekijä VIII, rekombinantti | Plasma |  |
| 8555 | p-fviiire |  | 18% | name | 62 | 100 |  | P-Hyytymistekijä VIII, rekombinantti | Plasma |  |
| 8556 | p-fviiit | % | 90% | name+unit+values | 361 | 0 | [16.3, 37.97, 59.33, 87.28, 110.35, 131.87, 148.05, 185.43, 226.83] |  | Plasma |  |
| 8557 | p-fviiit |  | 10% | name | 38 | 100 |  |  | Plasma |  |
| 8558 | p-fxi | % | 31% | name+unit+values | 395 | 0 | [50.08, 64.57, 75.25, 81.99, 89.24, 97.03, 104.84, 115.34, 141.06] | P -Hyytymistekijä XI | Plasma |  |
| 8559 | p-fxi |  | 69% | name | 874 | 100 |  | P -Hyytymistekijä XI | Plasma |  |
| 8560 | p-fxii | % | 29% | name+unit+values | 366 | 0 | [39.18, 49.17, 59.19, 66.57, 75.37, 84.82, 94.93, 104.19, 121.16] | P -Hyytymistekijä XII | Plasma |  |
| 8561 | p-fxii |  | 71% | name | 879 | 100 |  | P -Hyytymistekijä XII | Plasma |  |
| 8562 | p-fxiii | % | 92% | name+unit+values | 2087 | 0.1 | [46.67, 56.85, 67.27, 77.3, 88.74, 99.76, 113.43, 126.96, 141.89] | P -Hyytymistekijä XIII | Plasma |  |
| 8563 | p-fxiii |  | 8% | name+values | 176 | 100 | [92, 99.83, 108.05, 114.95, 122.43, 128.18, 132.91, 138.11, 151.1] | P -Hyytymistekijä XIII | Plasma |  |
| 8564 | p-fxiii. | % | 97% | name+unit+values | 814 | 0 | [69.07, 80.91, 90.57, 100.38, 110.55, 120.66, 130.07, 138.79, 146.65] |  | Plasma |  |
| 8565 | p-fxiii. |  | 3% | name | 29 | 100 |  |  | Plasma |  |
| 8566 | p-k-ses | mmol/l | 97% | name+unit+values | 571 | 0 | [3.47, 3.71, 3.9, 4.01, 4.2, 4.3, 4.5, 4.74, 5.26] |  | Plasma |  |
| 8567 | p-k-ses |  | 3% | name | 16 | 100 |  |  | Plasma |  |
| 8568 | p-khoi | mmol/l | 16% | name+unit | 47 | 0 |  |  | Plasma |  |
| 8569 | p-khoi |  | 84% | name+values | 242 | 100 | [3.37, 3.59, 3.75, 3.89, 4, 4.13, 4.3, 4.49, 4.7] |  | Plasma |  |
| 8570 | p-la1-mix |  | 100% | name+values | 1894 | 100 | [37, 38, 39, 39.98, 40.95, 41.63, 42.91, 44.68, 47.2] |  | Plasma |  |
| 8571 | p-la1/la2 |  | 100% | name+values | 1893 | 100 | [1.11, 1.17, 1.22, 1.27, 1.31, 1.35, 1.42, 1.52, 1.74] |  | Plasma |  |
| 8572 | p-la2-mix |  | 100% | name+values | 1892 | 100 | [33.9, 34.6, 35.36, 36.63, 38, 39.7, 41.52, 43.7, 50] |  | Plasma |  |
| 8573 | p-lakthoi | mmol/l | 12% | name+unit | 31 | 0 |  |  | Plasma |  |
| 8574 | p-lakthoi |  | 88% | name+values | 228 | 100 | [0.76, 0.9, 1.02, 1.13, 1.23, 1.39, 1.6, 1.91, 2.55] |  | Plasma |  |
| 8575 | p-lh/fsh |  | 100% | name+values | 896 | 100 | [0.5, 0.7, 0.88, 1, 1.19, 1.4, 1.7, 2.14, 2.78] |  | Plasma |  |
| 8576 | p-mitotan | mg/l | 94% | name+unit | 266 | 0 |  | P -Mitotaani (Lysodren) | Plasma |  |
| 8577 | p-mitotan |  | 6% | name | 18 | 100 |  | P -Mitotaani (Lysodren) | Plasma |  |
| 8578 | p-na-ses | mmol/l | 97% | name+unit+values | 454 | 0 | [133.95, 135.35, 136.94, 138, 139, 140, 141.09, 142.76, 144.44] |  | Plasma |  |
| 8579 | p-na-ses |  | 3% | name | 16 | 100 |  |  | Plasma |  |
| 8580 | p-nahoi | mmol/l | 100% | name+unit+values | 289 | 0 | [131.88, 133.99, 135.4, 137.05, 138.9, 140, 140.99, 141.97, 143.59] |  | Plasma |  |
| 8581 | p-pg1/pg2 |  | 100% | name+values | 214 | 100 | [5.76, 7.27, 7.89, 8.45, 9.09, 9.69, 10.19, 11.33, 12.48] |  | Plasma |  |
| 8582 | p-sit3.1 |  | 100% | name | 774 | 100 |  |  | Plasma |  |
| 8583 | p-sitr3.8 |  | 100% | name | 1062 | 100 |  |  | Plasma |  |
| 8584 | p-tau-217 | ng/l | 41% | name+unit+values | 132 | 0 | [0.1, 0.12, 0.16, 0.2, 0.29, 0.37, 0.49, 0.64, 0.88] | P -Tau-proteiini, 217-fosforyloitu | Plasma |  |
| 8585 | p-tau-217 |  | 59% | name+values | 188 | 100 | [0.12, 0.16, 0.21, 0.28, 0.32, 0.38, 0.45, 0.59, 0.78] | P -Tau-proteiini, 217-fosforyloitu | Plasma |  |
| 8586 | p-vwf-ag | % | 95% | name+unit+values | 3318 | 0 | [47.7, 69.31, 90.97, 109.28, 131.06, 156.66, 193.1, 221.66, 254.07] | P -von Willebrand-tekijä, antigeeni | Plasma | Antigen |
| 8587 | p-vwf-ag |  | 5% | name+values | 164 | 100 | [42, 61.65, 79.42, 93.3, 113, 130.6, 161.7, 185.75, 231] | P -von Willebrand-tekijä, antigeeni | Plasma | Antigen |
| 8588 | p-vwf-akt | % | 93% | name+unit+values | 4343 | 0.02 | [38.92, 62.29, 79.13, 94.16, 109.29, 126.62, 152.89, 186.7, 245.26] | P -von Willebrand -tekijä, aktiivisuus (GPIb sitoutuminen) | Plasma |  |
| 8589 | p-vwf-akt |  | 7% | name+values | 340 | 100 | [55.5, 72.5, 81.5, 94.5, 101.75, 107.67, 129.5, 152.83, 223.5] | P -von Willebrand -tekijä, aktiivisuus (GPIb sitoutuminen) | Plasma |  |
| 8590 | p-vwf-aktt | % | 88% | name+unit+values | 211 | 0 | [36.56, 51.18, 66.86, 84.71, 112.56, 127.89, 144.38, 168.66, 217.53] |  | Plasma |  |
| 8591 | p-vwf-aktt |  | 12% | name | 28 | 100 |  |  | Plasma |  |
| 8592 | p-vwfcb | % | 92% | name+unit+values | 98 | 0 | [20, 35, 41, 47.3, 52.25, 60.85, 71.65, 83.6, 92] | P -von Willebrand -tekijä, kollageenin sitomiskyky | Plasma |  |
| 8593 | p-vwfcb |  | 8% | name | 8 | 100 |  | P -von Willebrand -tekijä, kollageenin sitomiskyky | Plasma |  |
| 8594 | p-vwfpaiv | % | 89% | name+unit | 169 | 0 |  |  | Plasma |  |
| 8595 | p-vwfpaiv |  | 11% | name | 20 | 100 |  |  | Plasma |  |
| 8596 | p-vwfrco | % | 30% | name+unit | 35 | 0 |  | P -von Willebrand-tekijä, ristosetiinikofaktori | Plasma |  |
| 8597 | p-vwfrco |  | 70% | name | 83 | 100 |  | P -von Willebrand-tekijä, ristosetiinikofaktori | Plasma |  |
| 8598 | s-fit/pgf |  | 100% | name+values | 135 | 100 | [6.12, 10.5, 17.8, 26.98, 40.52, 58.17, 73.2, 107.03, 135.33] | S -Endoteelikasvutekijän liukoisen reseptorin (S -sFlt-1) ja plasentaalisen kasvutekijän (S -PlGF) suhde | Serum |  |
| 8599 | s-flt/pgf |  | 100% | name+values | 326 | 100 | [2.33, 4.43, 7.66, 13.78, 25.02, 41.69, 56.09, 83.81, 137.49] |  | Serum |  |

