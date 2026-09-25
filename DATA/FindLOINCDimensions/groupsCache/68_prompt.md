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
- `p_missing` — percentage (0-100) of those records with no numeric value.
- `deciles` — the 9 deciles of the observed numeric values, when available.
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

**Missing values are not evidence.** `p_missing` describes this extract, not the laboratory test: a row with no values is a row where the numbers were not recorded or not carried through. Never conclude "no numbers, therefore qualitative". A test is qualitative when the CODE says so — the `-O` suffix, a `LongName` naming a qualitative or screening test, a component only ever reported as detected/not-detected.

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
Here is group 68 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 5245 | -amyl | u/l | 92% | name+unit+values | 4274 | 0 | [40.79, 91.13, 163.85, 262.6, 433.78, 741.28, 1310.78, 2709.64, 7550.04] |  |  |  |
| 5246 | -amyl |  | 8% | name | 352 | 99.15 |  |  |  |  |
| 5247 | alfa-1 | g/l | 100% | name+unit+values | 903 | 0 | [1.23, 1.5, 1.79, 2.22, 2.48, 2.68, 2.88, 3.11, 3.51] |  |  |  |
| 5248 | alfa-2 | g/l | 100% | name+unit+values | 907 | 0 | [5.21, 5.83, 6.26, 6.53, 6.88, 7.18, 7.58, 8.1, 8.87] |  |  |  |
| 5249 | amylaasi | u/l | 98% | name+unit+values | 1380 | 0 | [29.91, 37.05, 43.3, 48.81, 54.92, 61.3, 69.75, 79.02, 95.18] |  |  |  |
| 5250 | amylaasi |  | 2% | name | 28 | 100 |  |  |  |  |
| 5251 | as-amyl | u/l | 85% | name+unit+values | 277 | 0 | [7.29, 10.51, 15.56, 18.22, 24.01, 33.76, 50.6, 245.04, 2494.39] | As-Amylaasi | Ascitic fluid |  |
| 5252 | as-amyl |  | 15% | name | 47 | 87.23 |  | As-Amylaasi | Ascitic fluid |  |
| 5253 | du-aldos | nmol | 81% | name+unit+values | 1126 | 1.15 | [10.3, 15.49, 20, 24.81, 30.39, 36.32, 42.97, 53.97, 73.23] | dU-Aldosteroni | 24-hour urine |  |
| 5254 | du-aldos | nmol/24h | 2% | name+unit | 31 | 0 |  | dU-Aldosteroni | 24-hour urine |  |
| 5255 | du-aldos | nmol/l | 2% | name+unit | 25 | 0 |  | dU-Aldosteroni | 24-hour urine |  |
| 5256 | du-aldos | ug/24h | 1% | name+unit | 12 | 0 |  | dU-Aldosteroni | 24-hour urine |  |
| 5257 | du-aldos |  | 14% | name+values | 191 | 49.21 | [8, 15.27, 20, 24.32, 29.5, 36, 48.62, 70.25, 89] | dU-Aldosteroni | 24-hour urine |  |
| 5258 | fp-afos | u/l | 100% | name+unit+values | 595 | 0 | [48.33, 55.25, 59.57, 63.86, 67.6, 73.77, 82.28, 90.12, 106.03] |  | Fasting plasma |  |
| 5259 | fp-aldos | pmol/l | 92% | name+unit+values | 759 | 0 | [99.71, 178.79, 234.24, 287.4, 344.18, 414.36, 481.84, 606.93, 836.03] | fP-Aldosteroni | Fasting plasma |  |
| 5260 | fp-aldos |  | 8% | name | 70 | 70 |  | fP-Aldosteroni | Fasting plasma |  |
| 5261 | fp-amyl | u/l | 100% | name+unit+values | 166 | 0 | [38.7, 46.83, 53.52, 59.77, 65.17, 71.18, 77.02, 86.88, 100.9] |  | Fasting plasma |  |
| 5262 | p-afos | u/l | 99% | name+unit+values | 2633385 | 0.01 | [49.38, 57.42, 63.93, 70.22, 76.89, 84.76, 95, 111.35, 151.36] | P -Alkalinen fosfataasi | Plasma |  |
| 5263 | p-afos |  | 1% | name+values | 28410 | 100 | [47.41, 55.11, 61.31, 67.35, 73.68, 80.95, 90.67, 106.27, 134.65] | P -Alkalinen fosfataasi | Plasma |  |
| 5264 | p-aldos | pmol/l | 93% | name+unit+values | 978 | 0 | [88.37, 146.16, 190.71, 235.98, 287.48, 347.26, 419.69, 540.86, 783.53] | P -Aldosteroni | Plasma |  |
| 5265 | p-aldos |  | 7% | name | 71 | 88.73 |  | P -Aldosteroni | Plasma |  |
| 5266 | p-amyl | u/l | 98% | name+unit+values | 368852 | 0.02 | [26.2, 33.98, 40.36, 46.26, 52.37, 59.2, 67.68, 79.78, 104.76] | P -Amylaasi | Plasma |  |
| 5267 | p-amyl |  | 2% | name+values | 5758 | 100 | [29, 36.73, 43, 48.41, 54.21, 60.53, 68.18, 78.9, 100.7] | P -Amylaasi | Plasma |  |
| 5268 | p-amylaasi | u/l | 98% | name+unit+values | 1560 | 0 | [28.07, 35.77, 41.54, 47.32, 52.57, 59.03, 66.78, 77.77, 99.14] |  | Plasma |  |
| 5269 | p-amylaasi |  | 2% | name | 28 | 89.29 |  |  | Plasma |  |
| 5270 | p-amylp | u/l | 86% | name+unit+values | 96538 | 0 | [14.27, 20, 23.24, 26.43, 29.95, 34.28, 40.26, 51.17, 86.4] | P -Amylaasi, haimaperäinen | Plasma |  |
| 5271 | p-amylp |  | 14% | name+values | 16102 | 100 | [12.88, 17.77, 21.4, 24.41, 27.47, 31.02, 35.38, 42.83, 60.62] | P -Amylaasi, haimaperäinen | Plasma |  |
| 5272 | p-sldl | mmol/l | 91% | name+unit+values | 2968 | 0 | [1.54, 1.82, 2.07, 2.32, 2.6, 2.9, 3.19, 3.53, 4.07] |  | Plasma |  |
| 5273 | p-sldl |  | 9% | name | 282 | 86.52 |  |  | Plasma |  |
| 5274 | pa-amyl | u/l | 93% | name+unit+values | 181 | 0 | [6, 8.3, 13.62, 23.54, 38.11, 86.55, 532.84, 2066.13, 14410] | Pa-Amylaasi | Pancreatic juice |  |
| 5275 | pa-amyl |  | 7% | name | 13 | 100 |  | Pa-Amylaasi | Pancreatic juice |  |
| 5276 | pf-amyl | u/l | 70% | name+unit+values | 512 | 0 | [11.47, 15.64, 19.01, 23.1, 27.84, 32.18, 37.92, 46.58, 62.15] | Pf-Amylaasi | Pleural fluid |  |
| 5277 | pf-amyl |  | 30% | name | 216 | 100 |  | Pf-Amylaasi | Pleural fluid |  |
| 5278 | s-aaldos | pmol/l | 100% | name+unit+values | 125 | 0.8 | [506.75, 663.13, 772.54, 837.76, 918.5, 1062, 1146, 1442.2, 2247] |  | Serum |  |
| 5279 | s-adali | mg/l | 65% | name+unit+values | 1092 | 0.37 | [4.24, 6.27, 7.87, 9.1, 10.33, 11.83, 13.14, 14.95, 17.6] | S -Adalimumabi | Serum |  |
| 5280 | s-adali |  | 35% | name+values | 600 | 16.67 | [3.21, 5.15, 6.89, 8.21, 9.3, 11.07, 13.15, 15.09, 18] | S -Adalimumabi | Serum |  |
| 5281 | s-adaliab | au/ml | 11% | name+unit+values | 257 | 1.17 | [4.47, 14.51, 21.55, 36.22, 43.39, 60.38, 104.64, 181.31, 370.6] | S -Adalimumabi, vasta-aineet | Serum |  |
| 5282 | s-adaliab |  | 89% | name | 2149 | 99.3 |  | S -Adalimumabi, vasta-aineet | Serum |  |
| 5283 | s-adalimu | mg/l | 88% | name+unit+values | 2004 | 0 | [3.43, 5.38, 6.89, 8.1, 9.37, 10.76, 12.24, 13.87, 16.85] |  | Serum |  |
| 5284 | s-adalimu |  | 12% | name+values | 271 | 52.03 | [2.22, 3.86, 5.11, 6.02, 6.96, 7.78, 8.44, 9.23, 10.15] |  | Serum |  |
| 5285 | s-adalip |  | 100% | name | 274 | 100 |  |  | Serum |  |
| 5286 | s-adalipa |  | 100% | name | 1304 | 100 |  |  | Serum |  |
| 5287 | s-afluu | % | 51% | name+unit+values | 92 | 0 | [10.3, 14.1, 19.33, 22.23, 25.37, 32.17, 35.52, 40.85, 45.6] |  | Serum |  |
| 5288 | s-afluu | u/l | 44% | name+unit+values | 80 | 0 | [17.5, 21, 25.5, 29.5, 33.5, 38.75, 50, 58.5, 97.5] |  | Serum |  |
| 5289 | s-afluu |  | 5% | name | 9 | 77.78 |  |  | Serum |  |
| 5290 | s-afluust | u/l | 86% | name+unit+values | 3036 | 0 | [23.45, 30.5, 36.88, 43.03, 49.77, 57.33, 66.23, 80.75, 107.75] |  | Serum |  |
| 5291 | s-afluust |  | 14% | name+values | 488 | 63.73 | [22.65, 29.23, 35.8, 41.92, 49.43, 57.83, 64.94, 75.26, 91.6] |  | Serum |  |
| 5292 | s-afmuut | u/l | 83% | name+unit+values | 1555 | 0 | [0, 0, 0, 0.56, 2.03, 4.33, 8.12, 14.99, 30.62] |  | Serum |  |
| 5293 | s-afmuut |  | 17% | name | 316 | 96.2 |  |  | Serum |  |
| 5294 | s-afos | iu/l | 0% | name+unit+values | 240 | 0 | [47.27, 53.32, 59.23, 65.05, 70.65, 75.95, 84.63, 98.48, 130] | S -Alkalinen fosfataasi | Serum |  |
| 5295 | s-afos | u/l | 98% | name+unit+values | 62976 | 0 | [49.01, 56.54, 62.55, 68.34, 74.46, 81.49, 90.44, 104.36, 129.97] | S -Alkalinen fosfataasi | Serum |  |
| 5296 | s-afos |  | 2% | name+values | 986 | 36 | [88.65, 108.98, 118.14, 127.37, 135.4, 144.04, 157.28, 186.3, 252.69] | S -Alkalinen fosfataasi | Serum |  |
| 5297 | s-afos-is | u/l | 1% | name+unit | 70 | 0 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes |
| 5298 | s-afos-is |  | 99% | name | 9083 | 99.98 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes |
| 5299 | s-afosluu | u/l | 62% | name+unit+values | 106 | 0 | [25.67, 31, 35.33, 39.5, 42, 50.37, 59.67, 72.5, 100] | S -Alkalinen fosfataasi, luuspesifinen | Serum |  |
| 5300 | s-afosluu | ug/l | 18% | name+unit | 30 | 0 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  |
| 5301 | s-afosluu |  | 20% | name | 35 | 11.43 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  |
| 5302 | s-afospit | u/l | 96% | name+unit+values | 177 | 0 | [96.72, 105.51, 113.04, 119.21, 129.13, 139.98, 153.3, 187.04, 317.98] |  | Serum |  |
| 5303 | s-afospit |  | 4% | name | 8 | 37.5 |  |  | Serum |  |
| 5304 | s-afsuol1 | u/l | 87% | name+unit+values | 1064 | 0 | [0, 0, 0, 0, 0, 0.97, 2.27, 4.95, 11.83] |  | Serum |  |
| 5305 | s-afsuol1 |  | 13% | name+values | 158 | 1.27 | [0, 0, 0, 0, 0.17, 1.4, 3, 6.28, 16.75] |  | Serum |  |
| 5306 | s-afsuol2 | u/l | 87% | name+unit+values | 1070 | 0 | [0, 0, 0, 0, 0, 0.76, 2.02, 4.43, 8.94] |  | Serum |  |
| 5307 | s-afsuol2 |  | 13% | name+values | 156 | 0.64 | [0, 0, 0, 0, 0, 1.25, 3, 4.75, 8] |  | Serum |  |
| 5308 | s-afsuol3 | u/l | 87% | name+unit+values | 1075 | 0 | [0, 0, 0, 0, 0, 0, 0, 1, 1.91] |  | Serum |  |
| 5309 | s-afsuol3 |  | 13% | name+values | 157 | 0.64 | [0, 0, 0, 0, 0, 0, 0, 1, 1] |  | Serum |  |
| 5310 | s-afsuoli | % | 12% | name+unit | 53 | 0 |  |  | Serum |  |
| 5311 | s-afsuoli | u/l | 45% | name+unit+values | 189 | 0 | [1, 2.2, 4.12, 5.94, 7, 9.07, 12.69, 23.37, 34.67] |  | Serum |  |
| 5312 | s-afsuoli |  | 43% | name | 182 | 96.15 |  |  | Serum |  |
| 5313 | s-albind | g/l | 84% | name+unit+values | 815 | 0 | [34.39, 37.6, 39.38, 40.81, 42.07, 43.01, 44.01, 45.22, 47.08] |  | Serum |  |
| 5314 | s-albind |  | 16% | name+values | 155 | 25.81 | [33.15, 36.46, 38.93, 39.99, 41.28, 41.98, 42.86, 43.61, 45.95] |  | Serum |  |
| 5315 | s-albu | g/l | 98% | name+unit+values | 554 | 0 | [34.76, 36.69, 38.29, 39.83, 40.76, 41.89, 43.25, 44.88, 46.93] |  | Serum |  |
| 5316 | s-albu |  | 2% | name | 12 | 33.33 |  |  | Serum |  |
| 5317 | s-album | g/l | 100% | name+unit+values | 27997 | 0 | [31.02, 34.31, 36.21, 37.6, 38.74, 39.81, 40.91, 42.12, 43.69] |  | Serum |  |
| 5318 | s-album |  | 0% | name+values | 49 | 100 | [31.46, 35.04, 37.29, 38.99, 40.3, 41.52, 42.95, 44.52, 46.29] |  | Serum |  |
| 5319 | s-aldol | u/l | 85% | name+unit+values | 3331 | 0.03 | [3.03, 3.84, 4, 4.87, 5, 5.94, 6.21, 7.11, 9.71] | S -Aldolaasi | Serum |  |
| 5320 | s-aldol |  | 15% | name+values | 603 | 75.79 | [2.92, 3.62, 4.18, 4.48, 5.37, 5.7, 6.13, 7.21, 9.7] | S -Aldolaasi | Serum |  |
| 5321 | s-aldos | pmol/l | 81% | name+unit+values | 5247 | 0.88 | [80.92, 114.8, 152.73, 192.44, 237.39, 292.55, 361.76, 461.2, 667.49] | S -Aldosteroni | Serum |  |
| 5322 | s-aldos |  | 19% | name+values | 1207 | 72.49 | [89.4, 124.94, 166.83, 212.25, 274.25, 349.09, 455.92, 585.04, 869.75] | S -Aldosteroni | Serum |  |
| 5323 | s-aldos-m | pmol/l | 57% | name+unit+values | 88 | 0 | [47, 57.1, 78.9, 115.83, 136, 213.63, 263.1, 334.4, 926] | S -Aldosteroni, makuu | Serum | Supine (lying down) |
| 5324 | s-aldos-m |  | 43% | name | 66 | 68.18 |  | S -Aldosteroni, makuu | Serum | Supine (lying down) |
| 5325 | s-aldos-p | pmol/l | 71% | name+unit+values | 824 | 0 | [77.23, 114.1, 153.16, 191.49, 236.83, 292.92, 363.97, 474.9, 659.05] | S -Aldosteroni, pysty | Serum | Upright (standing) |
| 5326 | s-aldos-p |  | 29% | name+values | 329 | 21.88 | [79.42, 123.32, 172.77, 232.62, 283.29, 334.05, 403.83, 552.65, 812.7] | S -Aldosteroni, pysty | Serum | Upright (standing) |
| 5327 | s-alfa-1 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  |
| 5328 | s-alfa-1 | g/l | 100% | name+unit+values | 30281 | 0 | [2.19, 2.42, 2.6, 2.72, 2.88, 3.03, 3.24, 3.54, 4.08] |  | Serum |  |
| 5329 | s-alfa-1 |  | 0% | name+values | 50 | 100 | [1.5, 1.7, 1.88, 2.13, 2.38, 2.62, 2.88, 3.19, 3.81] |  | Serum |  |
| 5330 | s-alfa-2 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  |
| 5331 | s-alfa-2 | g/l | 100% | name+unit+values | 30219 | 0 | [5.45, 5.93, 6.31, 6.66, 7.01, 7.39, 7.84, 8.42, 9.36] |  | Serum |  |
| 5332 | s-alfa-2 |  | 0% | name+values | 50 | 100 | [5.71, 6.15, 6.53, 6.83, 7.14, 7.51, 7.91, 8.44, 9.39] |  | Serum |  |
| 5333 | s-alfa1 | g/l | 95% | name+unit+values | 1708 | 0 | [1.45, 1.6, 1.7, 1.8, 1.95, 2.11, 2.38, 2.65, 3.03] |  | Serum |  |
| 5334 | s-alfa1 |  | 5% | name | 92 | 25 |  |  | Serum |  |
| 5335 | s-alfa2 | g/l | 95% | name+unit+values | 1768 | 0 | [5.73, 6.28, 6.69, 6.98, 7.28, 7.59, 8.04, 8.57, 9.36] |  | Serum |  |
| 5336 | s-alfa2 |  | 5% | name | 92 | 25 |  |  | Serum |  |
| 5337 | s-allige | mg/l | 0% | name+unit | 14 | 0 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  |
| 5338 | s-allige | u/ml | 39% | name+unit+values | 1753 | 0 | [0.12, 0.19, 0.31, 0.51, 0.83, 1.39, 2.4, 4.64, 12.35] | S -Allergeeni, IgE-vasta-aineet | Serum |  |
| 5339 | s-allige |  | 61% | name | 2748 | 99.71 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  |
| 5340 | s-amyl | u/l | 99% | name+unit+values | 10387 | 0 | [33.31, 39.8, 44.99, 49.81, 54.67, 59.75, 66.53, 75.22, 91.12] | S -Amylaasi | Serum |  |
| 5341 | s-amyl |  | 1% | name+values | 129 | 20.16 | [35, 42.3, 49.52, 56.4, 62.75, 71, 94.2, 128.3, 161] | S -Amylaasi | Serum |  |
| 5342 | s-amyl-is | form | 3% | name+unit | 15 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes |
| 5343 | s-amyl-is |  | 97% | name | 434 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes |
| 5344 | s-amylp | u/l | 81% | name+unit+values | 280 | 0 | [14.92, 20.3, 25.89, 30.35, 36.7, 44.3, 55.25, 69.52, 135.91] | S -Amylaasi, haimaperäinen | Serum |  |
| 5345 | s-amylp |  | 19% | name | 66 | 16.67 |  | S -Amylaasi, haimaperäinen | Serum |  |
| 5346 | s-amyls | u/l | 81% | name+unit+values | 256 | 0 | [12.25, 18.54, 23.94, 28.43, 34.44, 44.93, 63.37, 81.22, 120.05] | S -Amylaasi, sylkiperäinen | Serum |  |
| 5347 | s-amyls |  | 19% | name | 61 | 18.03 |  | S -Amylaasi, sylkiperäinen | Serum |  |
| 5348 | s-dmklots | nmol/l | 60% | name+unit+values | 15078 | 0.19 | [349.72, 488.38, 603.51, 717.55, 840.77, 973.75, 1127.96, 1320.3, 1616.71] | S -Desmetyyliklotsapiini | Serum |  |
| 5349 | s-dmklots | umol/l | 36% | name+unit+values | 9051 | 0 | [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.95, 1.16, 1.45] | S -Desmetyyliklotsapiini | Serum |  |
| 5350 | s-dmklots | âumol/l | 0% | name+unit | 32 | 0 |  | S -Desmetyyliklotsapiini | Serum |  |
| 5351 | s-dmklots |  | 4% | name+values | 1117 | 100 | [0.79, 1.17, 292.49, 521.2, 721.89, 874.92, 1051.9, 1273.86, 1599.85] | S -Desmetyyliklotsapiini | Serum |  |
| 5352 | s-gliade | u/ml | 21% | name+unit | 23 | 60.87 |  |  | Serum |  |
| 5353 | s-gliade |  | 79% | name | 84 | 98.81 |  |  | Serum |  |
| 5354 | s-gliadie | u/ml | 82% | name+unit+values | 531 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.02, 0.07, 0.24] |  | Serum |  |
| 5355 | s-gliadie |  | 18% | name+values | 118 | 5.93 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Serum |  |
| 5356 | s-hladsa |  | 100% | name | 847 | 100 |  |  | Serum |  |
| 5357 | s-kalatue |  | 100% | name | 132 | 100 |  |  | Serum |  |
| 5358 | s-kolaige | u/ml | 7% | name+unit | 14 | 100 |  |  | Serum |  |
| 5359 | s-kolaige |  | 93% | name | 181 | 100 |  |  | Serum |  |
| 5360 | s-kudosab |  | 100% | name | 1042 | 100 |  |  | Serum |  |
| 5361 | s-ngmuut |  | 100% | name | 16771 | 100 |  |  | Serum |  |
| 5362 | s-oaldos | pmol/l | 100% | name+unit+values | 200 | 1.5 | [636.2, 2117.22, 7632.17, 17219.7, 36953.33, 62851.67, 87233.33, 130744.44, 214222.22] |  | Serum |  |
| 5363 | s-olants | nmol/l | 87% | name+unit+values | 4003 | 0.07 | [53.03, 76.26, 97.99, 119.12, 141.44, 165.86, 195.39, 234.91, 291.91] | S -Olantsapiini | Serum |  |
| 5364 | s-olants |  | 13% | name+values | 595 | 31.43 | [58.73, 86.04, 110.31, 132.4, 158.88, 189.03, 219.38, 262.18, 324.46] | S -Olantsapiini | Serum |  |
| 5365 | s-ovalbue | u/ml | 84% | name+unit+values | 86 | 1.16 | [0, 0.02, 0.03, 0.1, 0.23, 0.56, 2, 8.02, 21.8] |  | Serum |  |
| 5366 | s-ovalbue |  | 16% | name | 16 | 81.25 |  |  | Serum |  |
| 5367 | s-salis | mmol/l | 21% | name+unit | 56 | 0 |  | S -Salisylaatit | Serum |  |
| 5368 | s-salis | umol/l | 33% | name+unit | 87 | 5.75 |  | S -Salisylaatit | Serum |  |
| 5369 | s-salis |  | 46% | name | 121 | 97.52 |  | S -Salisylaatit | Serum |  |
| 5370 | s-scl-t |  | 100% | name | 833 | 100 |  |  | Serum |  |
| 5371 | s-sfit1 | ng/l | 100% | name+unit+values | 135 | 0 | [1994, 2524.58, 3215, 3792.29, 4608.29, 5445.5, 7105.78, 9372.28, 11496.33] | S -Endoteelikasvutekijän liukoinen reseptori | Serum |  |
| 5372 | s-sflt-1 | ng/l | 100% | name+unit+values | 318 | 0 | [1291.87, 1667.24, 2344.04, 3006.81, 3762.57, 4805.39, 6029.95, 7158.88, 9214.96] |  | Serum |  |
| 5373 | s-sldl | mmol/l | 93% | name+unit+values | 2207 | 0 | [1.75, 2.1, 2.37, 2.68, 2.95, 3.22, 3.51, 3.8, 4.25] |  | Serum |  |
| 5374 | s-sldl |  | 7% | name | 177 | 98.87 |  |  | Serum |  |
| 5375 | s-suoli | u/l | 92% | name+unit+values | 115 | 0 | [0, 0, 0, 0.27, 2.83, 5.44, 7.47, 12.05, 21.01] |  | Serum |  |
| 5376 | s-suoli |  | 8% | name | 10 | 30 |  |  | Serum |  |
| 5377 | s-suolist | u/l | 56% | name+unit+values | 81 | 0 | [2, 3.1, 5.23, 9, 10.88, 13, 15, 20.35, 28] |  | Serum |  |
| 5378 | s-suolist |  | 44% | name | 63 | 96.83 |  |  | Serum |  |
| 5379 | s-valdos | pmol/l | 100% | name+unit+values | 157 | 0.64 | [3435.33, 10631.9, 19753.33, 29394.05, 44768.33, 65139.29, 87875, 118200, 193300] |  | Serum |  |
| 5380 | s-vedol | mg/l | 88% | name+unit+values | 1566 | 0 | [10.87, 14.08, 17.75, 20.76, 23.95, 27.59, 31.95, 37.11, 43.61] | S -Vedolitsumabi | Serum |  |
| 5381 | s-vedol |  | 12% | name+values | 221 | 12.22 | [5.88, 9.27, 13.22, 17.42, 21.48, 25.78, 28.81, 33.33, 39.06] | S -Vedolitsumabi | Serum |  |
| 5382 | saline |  | 100% | name+values | 946 | 3.38 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |
| 5383 | se-amyl | u/l | 87% | name+unit+values | 1679 | 0.83 | [7.84, 14.57, 24.16, 42.2, 81.52, 202.31, 555.29, 1833.05, 9919.76] | Se-Amylaasi | Secretion |  |
| 5384 | se-amyl |  | 13% | name | 248 | 97.98 |  | Se-Amylaasi | Secretion |  |
| 5385 | sp-suld |  | 100% | name | 262 | 100 |  |  | Sperm / semen |  |
| 5386 | u-amyl | u/l | 94% | name+unit+values | 2762 | 0.04 | [40.07, 60.75, 84.23, 110.48, 142.21, 184.16, 244.01, 332.59, 547.07] | U -Amylaasi | Urine |  |
| 5387 | u-amyl |  | 6% | name+values | 192 | 49.48 | [46, 98.65, 135.92, 161.9, 205.44, 269.5, 358.67, 597.35, 1056] | U -Amylaasi | Urine |  |
| 5388 | u-amylp | u/l | 88% | name+unit+values | 106 | 0 | [29, 44.7, 68.1, 90.36, 112.17, 155.8, 214.47, 337.6, 546] | U -Amylaasi, haimaperäinen | Urine |  |
| 5389 | u-amylp |  | 12% | name | 15 | 20 |  | U -Amylaasi, haimaperäinen | Urine |  |

