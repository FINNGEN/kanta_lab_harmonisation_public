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
Here is group 74 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 5588 | -amyl | u/l | 92% | name+unit+values | 4274 | 0.02 | [40.67, 91.53, 164.11, 263.2, 435.72, 740.04, 1305.95, 2688.49, 7694.97] |  |  |  |
| 5589 | -amyl |  | 8% | name | 352 | 100 |  |  |  |  |
| 5590 | alfa-1 | g/l | 100% | name+unit+values | 903 | 0 | [1.22, 1.5, 1.79, 2.2, 2.48, 2.68, 2.9, 3.11, 3.52] |  |  |  |
| 5591 | alfa-2 | g/l | 100% | name+unit+values | 907 | 0 | [5.23, 5.83, 6.25, 6.52, 6.87, 7.21, 7.57, 8.08, 8.88] |  |  |  |
| 5592 | amylaasi | u/l | 98% | name+unit+values | 1380 | 0 | [29.99, 37.09, 43.34, 48.9, 54.86, 61.15, 69.82, 79.08, 95.2] |  |  |  |
| 5593 | amylaasi |  | 2% | name | 28 | 100 |  |  |  |  |
| 5594 | as-amyl | u/l | 85% | name+unit+values | 277 | 0 | [7.26, 10.43, 15.58, 18.44, 24.17, 32.74, 51.52, 248.83, 2427.98] | As-Amylaasi | Ascitic fluid |  |
| 5595 | as-amyl |  | 15% | name | 47 | 100 |  | As-Amylaasi | Ascitic fluid |  |
| 5596 | du-aldos | nmol | 81% | name+unit+values | 1126 | 0.09 | [10.24, 15.47, 20.03, 24.86, 30.48, 36.38, 42.95, 53.9, 73.35] | dU-Aldosteroni | 24-hour urine |  |
| 5597 | du-aldos | nmol/24h | 2% | name+unit | 31 | 0 |  | dU-Aldosteroni | 24-hour urine |  |
| 5598 | du-aldos | nmol/l | 2% | name+unit | 25 | 0 |  | dU-Aldosteroni | 24-hour urine |  |
| 5599 | du-aldos | ug/24h | 1% | name+unit | 12 | 0 |  | dU-Aldosteroni | 24-hour urine |  |
| 5600 | du-aldos |  | 14% | name+values | 191 | 100 | [8, 16, 20, 24.43, 29.88, 35.35, 48.9, 70.25, 89] | dU-Aldosteroni | 24-hour urine |  |
| 5601 | fp-afos | u/l | 100% | name+unit+values | 595 | 0 | [48.33, 55.17, 59.65, 63.83, 67.67, 73.36, 82.33, 90.3, 106.24] |  | Fasting plasma |  |
| 5602 | fp-aldos | pmol/l | 92% | name+unit+values | 759 | 0.13 | [99.64, 177.36, 232.25, 287.09, 343.45, 412.76, 483.45, 604.01, 841.72] | fP-Aldosteroni | Fasting plasma |  |
| 5603 | fp-aldos |  | 8% | name | 70 | 100 |  | fP-Aldosteroni | Fasting plasma |  |
| 5604 | fp-amyl | u/l | 100% | name+unit+values | 166 | 0 | [38.37, 46.9, 53.45, 59.94, 65.12, 70.97, 77.12, 86.5, 100.71] |  | Fasting plasma |  |
| 5605 | p-afos | u/l | 99% | name+unit+values | 2633385 | 0 | [49.21, 57.22, 63.75, 69.97, 76.72, 84.54, 94.72, 111.14, 150.6] | P -Alkalinen fosfataasi | Plasma |  |
| 5606 | p-afos |  | 1% | name | 28410 | 100 |  | P -Alkalinen fosfataasi | Plasma |  |
| 5607 | p-aldos | pmol/l | 93% | name+unit+values | 978 | 0 | [87.5, 146.01, 191, 236.08, 287.89, 347.09, 420.44, 545.67, 784.36] | P -Aldosteroni | Plasma |  |
| 5608 | p-aldos |  | 7% | name | 71 | 100 |  | P -Aldosteroni | Plasma |  |
| 5609 | p-amyl | u/l | 98% | name+unit+values | 368852 | 0 | [26.4, 34.18, 40.53, 46.43, 52.51, 59.29, 67.59, 79.75, 104.71] | P -Amylaasi | Plasma |  |
| 5610 | p-amyl |  | 2% | name | 5758 | 100 |  | P -Amylaasi | Plasma |  |
| 5611 | p-amylaasi | u/l | 98% | name+unit+values | 1560 | 0.19 | [27.94, 35.69, 41.43, 47.16, 52.68, 59.04, 66.76, 77.97, 99.1] |  | Plasma |  |
| 5612 | p-amylaasi |  | 2% | name | 28 | 100 |  |  | Plasma |  |
| 5613 | p-amylp | u/l | 86% | name+unit+values | 96538 | 0 | [14.18, 19.81, 23.07, 26.25, 29.84, 34.09, 39.97, 50.62, 84.58] | P -Amylaasi, haimaperäinen | Plasma |  |
| 5614 | p-amylp |  | 14% | name | 16102 | 100 |  | P -Amylaasi, haimaperäinen | Plasma |  |
| 5615 | p-sldl | mmol/l | 91% | name+unit+values | 2968 | 0 | [1.54, 1.82, 2.07, 2.31, 2.6, 2.9, 3.18, 3.53, 4.07] |  | Plasma |  |
| 5616 | p-sldl |  | 9% | name | 282 | 100 |  |  | Plasma |  |
| 5617 | pa-amyl | u/l | 93% | name+unit+values | 181 | 0 | [5.84, 8.3, 13.6, 23.86, 38.44, 92.97, 509.66, 2103.72, 16163.44] | Pa-Amylaasi | Pancreatic juice |  |
| 5618 | pa-amyl |  | 7% | name | 13 | 100 |  | Pa-Amylaasi | Pancreatic juice |  |
| 5619 | pf-amyl | u/l | 70% | name+unit+values | 512 | 0 | [11.6, 15.61, 19.05, 23.06, 27.88, 32.2, 37.91, 46.55, 61.71] | Pf-Amylaasi | Pleural fluid |  |
| 5620 | pf-amyl |  | 30% | name | 216 | 100 |  | Pf-Amylaasi | Pleural fluid |  |
| 5621 | s-aaldos | pmol/l | 100% | name+unit+values | 125 | 0 | [492.5, 660.37, 766.83, 836.71, 911.78, 1067.67, 1144.73, 1426.33, 2247] |  | Serum |  |
| 5622 | s-adali | mg/l | 65% | name+unit+values | 1092 | 0 | [4.2, 6.26, 7.85, 9.09, 10.32, 11.8, 13.1, 14.95, 17.6] | S -Adalimumabi | Serum |  |
| 5623 | s-adali |  | 35% | name+values | 600 | 100 | [3.2, 5.14, 6.89, 8.2, 9.31, 11.07, 13.16, 15.13, 17.9] | S -Adalimumabi | Serum |  |
| 5624 | s-adaliab | au/ml | 11% | name+unit+values | 257 | 0 | [4.61, 14.4, 21.93, 36.11, 43.5, 59.86, 106.84, 181.08, 359.99] | S -Adalimumabi, vasta-aineet | Serum |  |
| 5625 | s-adaliab |  | 89% | name | 2149 | 100 |  | S -Adalimumabi, vasta-aineet | Serum |  |
| 5626 | s-adalimu | mg/l | 88% | name+unit+values | 2004 | 0 | [3.45, 5.33, 6.83, 8.05, 9.31, 10.64, 12.15, 13.86, 16.79] |  | Serum |  |
| 5627 | s-adalimu |  | 12% | name+values | 271 | 100 | [2.15, 3.5, 4.82, 5.98, 6.9, 7.69, 8.4, 9, 10.5] |  | Serum |  |
| 5628 | s-adalip |  | 100% | name | 274 | 100 |  |  | Serum |  |
| 5629 | s-adalipa |  | 100% | name | 1304 | 100 |  |  | Serum |  |
| 5630 | s-afluu | % | 51% | name+unit+values | 92 | 5.43 | [10.6, 14.1, 19.5, 22.81, 26.08, 32.8, 35.7, 41.67, 46.1] |  | Serum |  |
| 5631 | s-afluu | u/l | 44% | name+unit+values | 80 | 0 | [17.5, 21.17, 25.5, 29.5, 33.5, 39, 50.25, 58.5, 97.5] |  | Serum |  |
| 5632 | s-afluu |  | 5% | name | 9 | 100 |  |  | Serum |  |
| 5633 | s-afluust | u/l | 86% | name+unit+values | 3036 | 0 | [23.5, 30.51, 36.98, 43, 49.76, 57.03, 66.34, 80.71, 107.37] |  | Serum |  |
| 5634 | s-afluust |  | 14% | name+values | 488 | 100 | [22.65, 29.1, 35.8, 41.93, 49.62, 57.31, 65.33, 75.04, 91.71] |  | Serum |  |
| 5635 | s-afmuut | u/l | 83% | name+unit+values | 1555 | 0 | [0, 0, 0, 0.45, 1.94, 4.15, 7.91, 14.33, 30.08] |  | Serum |  |
| 5636 | s-afmuut |  | 17% | name | 316 | 100 |  |  | Serum |  |
| 5637 | s-afos | iu/l | 0% | name+unit+values | 240 | 0 | [47.27, 53.35, 59.29, 64.98, 70.68, 75.89, 83.7, 97.87, 129.57] | S -Alkalinen fosfataasi | Serum |  |
| 5638 | s-afos | u/l | 98% | name+unit+values | 62976 | 0 | [49.03, 56.57, 62.54, 68.42, 74.5, 81.36, 90.37, 104.34, 129.79] | S -Alkalinen fosfataasi | Serum |  |
| 5639 | s-afos |  | 2% | name+values | 986 | 100 | [68.48, 103.96, 114.21, 123.83, 133.19, 141.93, 153.42, 179.39, 242.73] | S -Alkalinen fosfataasi | Serum |  |
| 5640 | s-afos-is | u/l | 1% | name+unit | 70 | 0 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes |
| 5641 | s-afos-is |  | 99% | name | 9083 | 100 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes |
| 5642 | s-afosluu | u/l | 62% | name+unit+values | 106 | 0 | [26, 31, 35.88, 39.85, 42.27, 50.97, 59.94, 73, 99.5] | S -Alkalinen fosfataasi, luuspesifinen | Serum |  |
| 5643 | s-afosluu | ug/l | 18% | name+unit | 30 | 0 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  |
| 5644 | s-afosluu |  | 20% | name | 35 | 100 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  |
| 5645 | s-afospit | u/l | 96% | name+unit+values | 177 | 0 | [96.56, 105.54, 113.04, 119.58, 129, 140.12, 153.78, 189.21, 316.1] |  | Serum |  |
| 5646 | s-afospit |  | 4% | name | 8 | 100 |  |  | Serum |  |
| 5647 | s-afsuol1 | u/l | 87% | name+unit+values | 1064 | 0 | [0, 0, 0, 0, 0, 1, 2.35, 4.91, 11.59] |  | Serum |  |
| 5648 | s-afsuol1 |  | 13% | name+values | 158 | 100 | [0, 0, 0, 0, 0.25, 1.4, 3.03, 6.2, 16.7] |  | Serum |  |
| 5649 | s-afsuol2 | u/l | 87% | name+unit+values | 1070 | 0 | [0, 0, 0, 0, 0, 0.67, 2.05, 4.42, 8.95] |  | Serum |  |
| 5650 | s-afsuol2 |  | 13% | name+values | 156 | 100 | [0, 0, 0, 0, 0, 1.25, 2.97, 4.53, 7.88] |  | Serum |  |
| 5651 | s-afsuol3 | u/l | 87% | name+unit+values | 1075 | 0 | [0, 0, 0, 0, 0, 0, 0, 1, 1.95] |  | Serum |  |
| 5652 | s-afsuol3 |  | 13% | name+values | 157 | 100 | [0, 0, 0, 0, 0, 0, 0, 1, 1] |  | Serum |  |
| 5653 | s-afsuoli | % | 12% | name+unit | 53 | 7.55 |  |  | Serum |  |
| 5654 | s-afsuoli | u/l | 45% | name+unit+values | 189 | 0 | [1, 2.3, 4.12, 5.88, 7.08, 9, 12.72, 22.94, 34.47] |  | Serum |  |
| 5655 | s-afsuoli |  | 43% | name | 182 | 100 |  |  | Serum |  |
| 5656 | s-albind | g/l | 84% | name+unit+values | 815 | 0.12 | [34.39, 37.62, 39.39, 40.83, 42.06, 43.01, 44.02, 45.22, 47.08] |  | Serum |  |
| 5657 | s-albind |  | 16% | name+values | 155 | 100 | [33.36, 36.48, 38.92, 39.95, 41.15, 41.97, 42.8, 43.45, 45.96] |  | Serum |  |
| 5658 | s-albu | g/l | 98% | name+unit+values | 554 | 0 | [34.72, 36.69, 38.31, 39.81, 40.79, 41.92, 43.29, 44.85, 46.9] |  | Serum |  |
| 5659 | s-albu |  | 2% | name | 12 | 100 |  |  | Serum |  |
| 5660 | s-album | g/l | 100% | name+unit+values | 27997 | 0 | [31, 34.31, 36.28, 37.68, 38.86, 39.95, 41.05, 42.32, 43.98] |  | Serum |  |
| 5661 | s-album |  | 0% | name | 49 | 100 |  |  | Serum |  |
| 5662 | s-aldol | u/l | 85% | name+unit+values | 3331 | 0.06 | [3.04, 3.83, 4.01, 4.85, 5, 5.92, 6.2, 7.12, 9.73] | S -Aldolaasi | Serum |  |
| 5663 | s-aldol |  | 15% | name+values | 603 | 100 | [2.94, 3.6, 4.14, 4.48, 5.31, 5.69, 6.13, 7.2, 9.7] | S -Aldolaasi | Serum |  |
| 5664 | s-aldos | pmol/l | 81% | name+unit+values | 5247 | 0 | [80.64, 115.08, 152.41, 191.39, 237.65, 292.23, 360.82, 461.41, 670.27] | S -Aldosteroni | Serum |  |
| 5665 | s-aldos |  | 19% | name+values | 1207 | 100 | [89, 124.87, 165.92, 211.54, 274.91, 347.78, 457.83, 589.41, 873.13] | S -Aldosteroni | Serum |  |
| 5666 | s-aldos-m | pmol/l | 57% | name+unit+values | 88 | 0 | [47, 57.1, 79.8, 116.1, 136, 213.6, 259.95, 333.65, 926] | S -Aldosteroni, makuu | Serum | Supine (lying down) |
| 5667 | s-aldos-m |  | 43% | name | 66 | 100 |  | S -Aldosteroni, makuu | Serum | Supine (lying down) |
| 5668 | s-aldos-p | pmol/l | 71% | name+unit+values | 824 | 0 | [78.48, 114.19, 152.86, 191.94, 236.28, 290.41, 364.22, 470.52, 658.4] | S -Aldosteroni, pysty | Serum | Upright (standing) |
| 5669 | s-aldos-p |  | 29% | name+values | 329 | 100 | [80.67, 123.44, 171.37, 229.16, 280.86, 334.95, 403.64, 546.89, 817.21] | S -Aldosteroni, pysty | Serum | Upright (standing) |
| 5670 | s-alfa-1 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  |
| 5671 | s-alfa-1 | g/l | 100% | name+unit+values | 30281 | 0 | [2.07, 2.39, 2.56, 2.7, 2.85, 3.01, 3.21, 3.51, 4.07] |  | Serum |  |
| 5672 | s-alfa-1 |  | 0% | name | 50 | 100 |  |  | Serum |  |
| 5673 | s-alfa-2 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  |
| 5674 | s-alfa-2 | g/l | 100% | name+unit+values | 30219 | 0 | [5.47, 5.95, 6.33, 6.68, 7.02, 7.4, 7.85, 8.42, 9.36] |  | Serum |  |
| 5675 | s-alfa-2 |  | 0% | name | 50 | 100 |  |  | Serum |  |
| 5676 | s-alfa1 | g/l | 95% | name+unit+values | 1708 | 0 | [1.46, 1.6, 1.7, 1.81, 1.95, 2.12, 2.36, 2.65, 3.02] |  | Serum |  |
| 5677 | s-alfa1 |  | 5% | name | 92 | 100 |  |  | Serum |  |
| 5678 | s-alfa2 | g/l | 95% | name+unit+values | 1768 | 0 | [5.72, 6.29, 6.69, 6.98, 7.28, 7.6, 8.04, 8.58, 9.38] |  | Serum |  |
| 5679 | s-alfa2 |  | 5% | name | 92 | 100 |  |  | Serum |  |
| 5680 | s-allige | u/ml | 39% | name+unit+values | 1753 | 0 | [0.12, 0.18, 0.31, 0.51, 0.83, 1.37, 2.39, 4.58, 12.46] | S -Allergeeni, IgE-vasta-aineet | Serum |  |
| 5681 | s-allige |  | 61% | name | 2748 | 100 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  |
| 5682 | s-amyl | u/l | 99% | name+unit+values | 10387 | 0.03 | [33.29, 39.82, 44.99, 49.86, 54.7, 59.91, 66.42, 75.19, 91.06] | S -Amylaasi | Serum |  |
| 5683 | s-amyl |  | 1% | name+values | 129 | 100 | [34, 39.9, 46.23, 52.13, 61, 67.24, 81.8, 119, 157] | S -Amylaasi | Serum |  |
| 5684 | s-amyl-is | form | 3% | name+unit | 15 | 0 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes |
| 5685 | s-amyl-is |  | 97% | name | 434 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes |
| 5686 | s-amylp | u/l | 81% | name+unit+values | 280 | 0 | [14.9, 20.56, 25.73, 30.47, 37.07, 44.5, 55.7, 69, 134.71] | S -Amylaasi, haimaperäinen | Serum |  |
| 5687 | s-amylp |  | 19% | name | 66 | 100 |  | S -Amylaasi, haimaperäinen | Serum |  |
| 5688 | s-amyls | u/l | 81% | name+unit+values | 256 | 0 | [12.15, 18.54, 23.8, 28.41, 34.57, 44.58, 62.25, 81.5, 120.24] | S -Amylaasi, sylkiperäinen | Serum |  |
| 5689 | s-amyls |  | 19% | name | 61 | 100 |  | S -Amylaasi, sylkiperäinen | Serum |  |
| 5690 | s-dmklots | nmol/l | 60% | name+unit+values | 15078 | 0 | [352.19, 494.52, 609.92, 726.65, 850.41, 983.47, 1136.85, 1329.87, 1635.23] | S -Desmetyyliklotsapiini | Serum |  |
| 5691 | s-dmklots | umol/l | 36% | name+unit+values | 9051 | 0 | [0.3, 0.4, 0.5, 0.6, 0.71, 0.83, 0.98, 1.18, 1.47] | S -Desmetyyliklotsapiini | Serum |  |
| 5692 | s-dmklots | âumol/l | 0% | name+unit | 32 | 0 |  | S -Desmetyyliklotsapiini | Serum |  |
| 5693 | s-dmklots |  | 4% | name | 1117 | 100 |  | S -Desmetyyliklotsapiini | Serum |  |
| 5694 | s-gliade | u/ml | 21% | name+unit | 23 | 0 |  |  | Serum |  |
| 5695 | s-gliade |  | 79% | name | 84 | 100 |  |  | Serum |  |
| 5696 | s-gliadie | u/ml | 82% | name+unit+values | 531 | 0.38 | [0, 0, 0, 0, 0.01, 0.01, 0.03, 0.08, 0.28] |  | Serum |  |
| 5697 | s-gliadie |  | 18% | name+values | 118 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Serum |  |
| 5698 | s-hladsa |  | 100% | name | 847 | 100 |  |  | Serum |  |
| 5699 | s-kalatue |  | 100% | name | 132 | 100 |  |  | Serum |  |
| 5700 | s-kolaige | u/ml | 7% | name+unit | 14 | 0 |  |  | Serum |  |
| 5701 | s-kolaige |  | 93% | name | 181 | 100 |  |  | Serum |  |
| 5702 | s-kudosab |  | 100% | name | 1042 | 100 |  |  | Serum |  |
| 5703 | s-ngmuut |  | 100% | name | 16771 | 100 |  |  | Serum |  |
| 5704 | s-oaldos | pmol/l | 100% | name+unit+values | 200 | 0 | [645.8, 1979.75, 7029, 15824.5, 33688.89, 59834.29, 83261.67, 123700, 205840] |  | Serum |  |
| 5705 | s-olants | nmol/l | 87% | name+unit+values | 4003 | 0 | [52.76, 76.27, 97.67, 118.63, 141.6, 166.04, 195.64, 235.14, 292.5] | S -Olantsapiini | Serum |  |
| 5706 | s-olants |  | 13% | name+values | 595 | 100 | [58.72, 85.72, 111.16, 132.16, 158.37, 189.52, 220.42, 262.15, 324.43] | S -Olantsapiini | Serum |  |
| 5707 | s-ovalbue | u/ml | 84% | name+unit+values | 86 | 0 | [0, 0.02, 0.03, 0.1, 0.2, 0.56, 2, 8.02, 21.8] |  | Serum |  |
| 5708 | s-ovalbue |  | 16% | name | 16 | 100 |  |  | Serum |  |
| 5709 | s-salis | mmol/l | 21% | name+unit | 56 | 0 |  | S -Salisylaatit | Serum |  |
| 5710 | s-salis | umol/l | 33% | name+unit | 87 | 0 |  | S -Salisylaatit | Serum |  |
| 5711 | s-salis |  | 46% | name | 121 | 100 |  | S -Salisylaatit | Serum |  |
| 5712 | s-scl-t |  | 100% | name | 833 | 100 |  |  | Serum |  |
| 5713 | s-sfit1 | ng/l | 100% | name+unit+values | 135 | 0 | [1977.12, 2547.75, 3224.22, 3788.61, 4607, 5533.06, 7127.6, 9338, 11489.25] | S -Endoteelikasvutekijän liukoinen reseptori | Serum |  |
| 5714 | s-sflt-1 | ng/l | 100% | name+unit+values | 318 | 0 | [1299.5, 1665.62, 2341.78, 3012.06, 3768.02, 4783.78, 6034.45, 7173.43, 9227.09] |  | Serum |  |
| 5715 | s-sldl | mmol/l | 93% | name+unit+values | 2207 | 0 | [1.75, 2.1, 2.37, 2.68, 2.95, 3.22, 3.51, 3.8, 4.24] |  | Serum |  |
| 5716 | s-sldl |  | 7% | name | 177 | 100 |  |  | Serum |  |
| 5717 | s-suoli | u/l | 92% | name+unit+values | 115 | 0 | [0, 0, 0, 0.25, 2.82, 5.66, 7.43, 12.05, 20.71] |  | Serum |  |
| 5718 | s-suoli |  | 8% | name | 10 | 100 |  |  | Serum |  |
| 5719 | s-suolist | u/l | 56% | name+unit+values | 81 | 0 | [2, 3.1, 5.23, 9, 10.88, 13, 15.18, 20.53, 28] |  | Serum |  |
| 5720 | s-suolist |  | 44% | name | 63 | 100 |  |  | Serum |  |
| 5721 | s-valdos | pmol/l | 100% | name+unit+values | 157 | 0 | [3394.93, 10217.43, 18958.33, 28660, 43056.25, 61996.67, 85263.1, 111783.33, 189600] |  | Serum |  |
| 5722 | s-vedol | mg/l | 88% | name+unit+values | 1566 | 0 | [10.83, 14.14, 17.65, 20.72, 24.04, 27.49, 31.91, 37.07, 43.64] | S -Vedolitsumabi | Serum |  |
| 5723 | s-vedol |  | 12% | name+values | 221 | 100 | [5.8, 9.08, 13.26, 17.46, 21.54, 25.78, 28.85, 33.26, 39.06] | S -Vedolitsumabi | Serum |  |
| 5724 | saline |  | 100% | name+values | 946 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |
| 5725 | se-amyl | u/l | 87% | name+unit+values | 1679 | 0 | [7.8, 14.55, 24.41, 42.23, 81.61, 199.2, 551.93, 1798.18, 9649.08] | Se-Amylaasi | Secretion |  |
| 5726 | se-amyl |  | 13% | name | 248 | 100 |  | Se-Amylaasi | Secretion |  |
| 5727 | sp-suld |  | 100% | name | 262 | 100 |  |  | Sperm / semen |  |
| 5728 | u-amyl | u/l | 94% | name+unit+values | 2762 | 0 | [39.74, 60.69, 84.27, 110.54, 142.25, 183.92, 243.16, 332.86, 543.79] | U -Amylaasi | Urine |  |
| 5729 | u-amyl |  | 6% | name+values | 192 | 100 | [46, 101.5, 137, 162, 204.5, 269.5, 360.4, 595.9, 1056] | U -Amylaasi | Urine |  |
| 5730 | u-amylp | u/l | 88% | name+unit+values | 106 | 0 | [30.2, 44.1, 67.11, 89.77, 112.17, 152.84, 214.66, 337.6, 540.5] | U -Amylaasi, haimaperäinen | Urine |  |
| 5731 | u-amylp |  | 12% | name | 15 | 100 |  | U -Amylaasi, haimaperäinen | Urine |  |

