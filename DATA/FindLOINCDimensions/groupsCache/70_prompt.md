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
Here is group 70 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 5451 | -calpro | mg/l | 86% | name+unit+values | 368 | 0 | [0.1, 0.31, 0.88, 2.86, 7.72, 16.73, 36.68, 74.3, 206.67] |  |  |  |
| 5452 | -calpro | ug/g | 9% | name+unit | 37 | 0 |  |  |  |  |
| 5453 | -calpro |  | 5% | name | 23 | 21.74 |  |  |  |  |
| 5454 | 4184sk-padihot |  | 100% | name | 107 | 100 |  |  |  |  |
| 5455 | b-karyot |  | 100% | name | 686 | 100 |  |  | Blood |  |
| 5456 | b-malarv |  | 100% | name | 127 | 100 |  |  | Blood |  |
| 5457 | b-nakkrea |  | 100% | name | 424 | 100 |  |  | Blood |  |
| 5458 | b-pakk-e |  | 100% | name | 249 | 100 |  |  | Blood |  |
| 5459 | b-vara |  | 100% | name | 254 | 100 |  |  | Blood |  |
| 5460 | b-varaspr |  | 100% | name | 331 | 99.7 |  |  | Blood |  |
| 5461 | b.parapert |  | 100% | name | 619 | 100 |  |  |  |  |
| 5462 | du-parprot |  | 100% | name | 369 | 100 |  |  | 24-hour urine |  |
| 5463 | f-calpro | ug/g | 89% | name+unit+values | 144892 | 0.48 | [13.78, 23.28, 35.55, 53.95, 82, 128.24, 215.34, 397.8, 911.98] | F -Kalprotektiini; F -Calprotectin | Feces |  |
| 5464 | f-calpro |  | 11% | name+values | 17874 | 100 | [23.61, 33.46, 47.58, 74.67, 119.83, 157.1, 290.01, 478.43, 993.36] | F -Kalprotektiini; F -Calprotectin | Feces |  |
| 5465 | f-calpro2 | ug/g | 80% | name+unit+values | 395 | 0 | [28.88, 40.5, 54.65, 82.87, 126.54, 220.92, 330.47, 583.74, 1304.77] |  | Feces |  |
| 5466 | f-calpro2 |  | 20% | name | 97 | 100 |  |  | Feces |  |
| 5467 | fs-bkarot | nmol/l | 5% | name+unit | 18 | 0 |  | fS-Beetakaroteeni | Fasting serum |  |
| 5468 | fs-bkarot | umol/l | 95% | name+unit+values | 318 | 0 | [0.25, 0.45, 0.6, 0.75, 0.87, 1.06, 1.29, 1.57, 2.19] | fS-Beetakaroteeni | Fasting serum |  |
| 5469 | fs-sappih | umol/l | 89% | name+unit+values | 5416 | 0.04 | [1.58, 2, 2.4, 3, 3.74, 4.45, 5.67, 7.59, 13.61] |  | Fasting serum |  |
| 5470 | fs-sappih |  | 11% | name+values | 686 | 100 | [2, 2.48, 3.02, 3.91, 4.81, 5.88, 6.86, 8.3, 12.54] |  | Fasting serum |  |
| 5471 | fs-sappihapot | umol/l | 87% | name+unit+values | 198 | 0 | [1.41, 1.79, 2.06, 2.5, 3.2, 3.97, 4.98, 6.66, 11.59] |  | Fasting serum |  |
| 5472 | fs-sappihapot |  | 13% | name | 30 | 100 |  |  | Fasting serum |  |
| 5473 | li-kardab | titre | 3% | name+unit | 7 | 14.29 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  |
| 5474 | li-kardab |  | 97% | name | 204 | 100 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  |
| 5475 | li-varlikv |  | 100% | name | 111 | 100 |  |  | Cerebrospinal fluid |  |
| 5476 | p-kardabg | gpl | 10% | name+unit+values | 1101 | 6.99 | [1, 1, 1.61, 2, 2, 3, 5.05, 7.62, 12.35] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  |
| 5477 | p-kardabg | u/ml | 42% | name+unit+values | 4443 | 0 | [1, 1, 1.08, 2, 2, 2.64, 3.48, 5.89, 13.12] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  |
| 5478 | p-kardabg |  | 47% | name+values | 4985 | 95.25 | [1, 1.14, 2, 2, 3.36, 5, 5.97, 9.03, 19.8] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  |
| 5479 | p-kardabm | mpl | 60% | name+unit+values | 1111 | 5.04 | [1, 2, 2, 2.88, 3, 4.6, 7.59, 12.86, 20.09] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  |
| 5480 | p-kardabm | u/ml | 1% | name+unit | 11 | 0 |  | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  |
| 5481 | p-kardabm |  | 39% | name+values | 724 | 89.09 | [1, 1, 1.45, 2, 2, 3, 4, 6, 15] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  |
| 5482 | p-pakk-si |  | 100% | name | 260 | 100 |  |  | Plasma |  |
| 5483 | p-varainr |  | 100% | name | 8332 | 99.99 |  |  | Plasma |  |
| 5484 | p-varmtr | s | 93% | name+unit+values | 1488 | 0 | [17.02, 18, 18.87, 19, 19.98, 20, 21, 21.93, 23] |  | Plasma |  |
| 5485 | p-varmtr |  | 7% | name | 111 | 100 |  |  | Plasma |  |
| 5486 | p-varmtt | % | 93% | name+unit+values | 1494 | 0 | [41.91, 74.69, 84.09, 92.24, 98.54, 104.26, 111.28, 119.13, 131.18] |  | Plasma |  |
| 5487 | p-varmtt |  | 7% | name | 105 | 100 |  |  | Plasma |  |
| 5488 | s-afmakro | u/l | 84% | name+unit+values | 2842 | 0 | [3.98, 5.01, 6.23, 7.94, 10.06, 14.01, 21.13, 33.22, 62.9] |  | Serum |  |
| 5489 | s-afmakro |  | 16% | name+values | 523 | 59.85 | [4, 5, 6, 7.5, 10, 15.29, 22.33, 30.86, 49.44] |  | Serum |  |
| 5490 | s-afmaks1 | u/l | 94% | name+unit+values | 199 | 0 | [25.36, 33.2, 41.05, 48.96, 56.78, 64.23, 71.62, 84.6, 112.64] |  | Serum |  |
| 5491 | s-afmaks1 |  | 6% | name | 13 | 0 |  |  | Serum |  |
| 5492 | s-afmaks2 | u/l | 97% | name+unit+values | 205 | 0 | [3.2, 4.72, 5.48, 6.4, 7, 8.07, 11.08, 16.5, 34.56] |  | Serum |  |
| 5493 | s-afmaks2 |  | 3% | name | 7 | 14.29 |  |  | Serum |  |
| 5494 | s-afmaksa | % | 3% | name+unit+values | 94 | 0 | [39.9, 51.85, 57.9, 64.48, 69.3, 73.65, 78.41, 84.08, 89.4] |  | Serum |  |
| 5495 | s-afmaksa | u/l | 84% | name+unit+values | 2958 | 0 | [25.04, 37.52, 47.03, 56.68, 67.64, 79.81, 95.37, 125.6, 201.78] |  | Serum |  |
| 5496 | s-afmaksa |  | 14% | name+values | 489 | 65.03 | [32.9, 45.51, 57.63, 71.86, 79.96, 85.36, 96.57, 123.73, 246.45] |  | Serum |  |
| 5497 | s-caspähe | u/ml | 89% | name+unit+values | 895 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.04, 0.13, 1.71] |  | Serum |  |
| 5498 | s-caspähe |  | 11% | name | 106 | 80.19 |  |  | Serum |  |
| 5499 | s-haspähe | u/ml | 81% | name+unit | 683 | 0.15 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  |
| 5500 | s-haspähe |  | 19% | name | 162 | 73.46 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  |
| 5501 | s-hasspäe | u/ml | 87% | name+unit+values | 476 | 1.05 | [0, 0.01, 0.03, 0.29, 1.1, 3.4, 6.79, 13.75, 30.06] |  | Serum |  |
| 5502 | s-hasspäe |  | 13% | name | 72 | 54.17 |  |  | Serum |  |
| 5503 | s-karba | umol/l | 76% | name+unit+values | 3476 | 0.06 | [18.5, 22.32, 25.2, 27.69, 29.91, 32.56, 35.34, 38.81, 44.25] | S -Karbamatsepiini | Serum |  |
| 5504 | s-karba |  | 24% | name+values | 1101 | 59.49 | [18.42, 22.33, 25.59, 27.84, 29.91, 31.7, 34.15, 37.84, 41.83] | S -Karbamatsepiini | Serum |  |
| 5505 | s-karbae | umol/l | 81% | name+unit | 88 | 0 |  | S -Karbamatsepiiniepoksidi | Serum |  |
| 5506 | s-karbae |  | 19% | name | 21 | 100 |  | S -Karbamatsepiiniepoksidi | Serum |  |
| 5507 | s-kardab | titre | 10% | name+unit+values | 1640 | 0 | [0, 1, 1.58, 2, 2.38, 4, 8.71, 19.26, 62.28] | S -Kardiolipiini, vasta-aineet | Serum |  |
| 5508 | s-kardab |  | 90% | name | 14614 | 99.49 |  | S -Kardiolipiini, vasta-aineet | Serum |  |
| 5509 | s-kardabg | gpl | 12% | name+unit+values | 222 | 29.28 | [6, 7, 8, 9, 11, 14.4, 18.14, 24.7, 40.7] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  |
| 5510 | s-kardabg | u/ml | 4% | name+unit+values | 83 | 0 | [1, 1, 2, 2, 2.25, 3, 4, 7.3, 23] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  |
| 5511 | s-kardabg |  | 84% | name+values | 1591 | 94.97 | [1, 2, 2, 4.55, 7, 8, 9, 11, 27] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  |
| 5512 | s-kardabm | mpl | 18% | name+unit+values | 359 | 18.11 | [10, 11.36, 12, 13.78, 15, 17.69, 23.08, 30.86, 52.98] | S -Kardiolipiini, IgM-vasta-aineet | Serum |  |
| 5513 | s-kardabm |  | 82% | name | 1672 | 96.29 |  | S -Kardiolipiini, IgM-vasta-aineet | Serum |  |
| 5514 | s-karni | umol/l | 95% | name+unit+values | 328 | 0 | [17.78, 24.87, 29.09, 33.28, 36.28, 39.87, 43.86, 49.4, 55.76] | S -Karnitiini | Serum |  |
| 5515 | s-karni |  | 5% | name | 16 | 100 |  | S -Karnitiini | Serum |  |
| 5516 | s-karni-v | umol/l | 98% | name+unit+values | 342 | 0 | [11.86, 16.35, 19.2, 22.24, 25.07, 27.94, 30.82, 35, 41.74] | S -Karnitiini, vapaa | Serum | Free or unconjugated |
| 5517 | s-karni-v |  | 2% | name | 7 | 85.71 |  | S -Karnitiini, vapaa | Serum | Free or unconjugated |
| 5518 | s-koopähe | u/ml | 56% | name+unit+values | 83 | 0 | [0.02, 0.02, 0.03, 0.04, 0.06, 0.11, 0.2, 0.31, 0.85] | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  |
| 5519 | s-koopähe |  | 44% | name | 65 | 78.46 |  | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  |
| 5520 | s-leppäe | u/ml | 54% | name+unit+values | 196 | 0.51 | [0, 0.01, 0.01, 0.02, 0.06, 0.22, 0.9, 2.7, 6.69] | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  |
| 5521 | s-leppäe |  | 46% | name | 167 | 86.23 |  | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  |
| 5522 | s-maapähe | u/ml | 44% | name+unit+values | 1974 | 0.81 | [0.01, 0.02, 0.05, 0.1, 0.19, 0.37, 0.71, 1.55, 5.76] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  |
| 5523 | s-maapähe |  | 56% | name+values | 2541 | 94.14 | [0.04, 0.11, 0.15, 0.24, 0.38, 0.57, 1.12, 1.88, 3.68] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  |
| 5524 | s-maksa |  | 100% | name | 108 | 100 |  |  | Serum |  |
| 5525 | s-maksa-1 | u/l | 95% | name+unit+values | 115 | 0 | [31.15, 42.45, 51.29, 60.72, 65.7, 69.64, 79.3, 87.8, 100.66] |  | Serum |  |
| 5526 | s-maksa-1 |  | 5% | name | 6 | 16.67 |  |  | Serum |  |
| 5527 | s-maksa-2 | u/l | 90% | name+unit+values | 110 | 0 | [3.95, 4.95, 5.9, 6.88, 7.37, 8.14, 9.54, 13.38, 18.4] |  | Serum |  |
| 5528 | s-maksa-2 |  | 10% | name | 12 | 8.33 |  |  | Serum |  |
| 5529 | s-maksa1 | u/l | 94% | name+unit+values | 134 | 0 | [36.7, 43.4, 53.05, 58.95, 67.89, 79.32, 89.06, 98.11, 147.2] |  | Serum |  |
| 5530 | s-maksa1 |  | 6% | name | 9 | 66.67 |  |  | Serum |  |
| 5531 | s-maksa2 | u/l | 92% | name+unit+values | 132 | 0 | [4, 5, 6, 7.35, 9, 10.85, 14.35, 21.6, 43.05] |  | Serum |  |
| 5532 | s-maksa2 |  | 8% | name | 11 | 81.82 |  |  | Serum |  |
| 5533 | s-maksaab |  | 100% | name | 1108 | 100 |  |  | Serum |  |
| 5534 | s-maksap |  | 100% | name | 147 | 100 |  |  | Serum |  |
| 5535 | s-makspak |  | 100% | name | 778 | 100 |  |  | Serum |  |
| 5536 | s-ohkarba | umol/l | 84% | name+unit+values | 4080 | 0.02 | [27.1, 35.97, 41.95, 47.99, 54.61, 61.42, 68.9, 80.34, 98.86] | S -Hydroksikarbatsepiini (10-) | Serum |  |
| 5537 | s-ohkarba |  | 16% | name+values | 797 | 53.58 | [25.02, 33.78, 40.6, 47.36, 53.64, 59.31, 68.63, 83.49, 103.17] | S -Hydroksikarbatsepiini (10-) | Serum |  |
| 5538 | s-okarba | umol/l | 49% | name+unit+values | 163 | 10.43 | [0.4, 0.4, 0.8, 0.8, 0.8, 1, 1.2, 2, 2.28] | S -Okskarbatsepiini | Serum |  |
| 5539 | s-okarba |  | 51% | name | 168 | 92.26 |  | S -Okskarbatsepiini | Serum |  |
| 5540 | s-ovarab | titre | 8% | name+unit | 22 | 9.09 |  | S -Munasarja, vasta-aineet | Serum |  |
| 5541 | s-ovarab |  | 92% | name | 250 | 99.2 |  | S -Munasarja, vasta-aineet | Serum |  |
| 5542 | s-pakast5 |  | 100% | name | 880 | 100 |  |  | Serum |  |
| 5543 | s-pakast7 |  | 100% | name | 106 | 100 |  |  | Serum |  |
| 5544 | s-pakaste |  | 100% | name | 345 | 100 |  |  | Serum |  |
| 5545 | s-pakkas |  | 100% | name | 1423 | 100 |  |  | Serum |  |
| 5546 | s-pakkase |  | 100% | name | 262 | 100 |  |  | Serum |  |
| 5547 | s-pakkask |  | 100% | name | 1061 | 100 |  |  | Serum |  |
| 5548 | s-pakkasl |  | 100% | name | 919 | 100 |  |  | Serum |  |
| 5549 | s-pakkasn |  | 100% | name | 563 | 100 |  |  | Serum |  |
| 5550 | s-pakkasv |  | 100% | name | 357 | 100 |  |  | Serum |  |
| 5551 | s-papp-a | mu/l | 61% | name+unit+values | 533 | 0 | [227.4, 357.69, 452.41, 562.07, 709.24, 895.85, 1154.59, 1409.1, 2163.11] |  | Serum |  |
| 5552 | s-papp-a |  | 39% | name+values | 338 | 2.37 | [167.71, 318.34, 452.63, 572.23, 702.5, 894.09, 1122.57, 1356.65, 1789.1] |  | Serum |  |
| 5553 | s-pappa | form | 0% | name+unit+values | 136 | 0 | [318.92, 443.67, 549.54, 657.05, 734.74, 894.71, 1259.38, 1647.76, 2113.41] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  |
| 5554 | s-pappa | mu/l | 99% | name+unit+values | 41976 | 0 | [274.01, 424.82, 564.51, 708.65, 861.85, 1046.47, 1281.47, 1624.11, 2236.83] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  |
| 5555 | s-pappa |  | 1% | name+values | 357 | 100 | [254.51, 396.2, 527.37, 666.3, 821.3, 1003.01, 1225.19, 1551.35, 2139.86] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  |
| 5556 | s-pappmom | mom | 100% | name+unit+values | 461 | 0 | [0.48, 0.64, 0.76, 0.89, 1.03, 1.22, 1.42, 1.67, 2.13] |  | Serum |  |
| 5557 | s-parapäe | u/ml | 96% | name+unit+values | 829 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.02, 0.06, 0.35] |  | Serum |  |
| 5558 | s-parapäe |  | 4% | name | 34 | 61.76 |  |  | Serum |  |
| 5559 | s-paras | umol/l | 52% | name+unit+values | 2680 | 3.1 | [16.09, 27.95, 44.46, 65.68, 102.63, 158.13, 258.09, 473.45, 862.14] | S -Parasetamoli | Serum |  |
| 5560 | s-paras |  | 48% | name | 2490 | 99.24 |  | S -Parasetamoli | Serum |  |
| 5561 | s-paroab |  | 100% | name | 212 | 100 |  | S -Sikotautivirus, vasta-aineet | Serum |  |
| 5562 | s-paroabg | au/ml | 25% | name+unit+values | 72 | 0 | [14.1, 32.2, 47.68, 60.86, 78.93, 100.49, 117, 176, 216] | S -Sikotautivirus, IgG-vasta-aineet | Serum |  |
| 5563 | s-paroabg | titre | 16% | name+unit | 45 | 0 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  |
| 5564 | s-paroabg |  | 60% | name | 172 | 91.86 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  |
| 5565 | s-paroabm |  | 100% | name | 197 | 98.98 |  | S -Sikotautivirus, IgM-vasta-aineet | Serum |  |
| 5566 | s-parprot |  | 100% | name | 1578 | 100 |  |  | Serum |  |
| 5567 | s-parpäh | u/ml | 27% | name+unit | 67 | 0 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  |
| 5568 | s-parpäh |  | 73% | name | 184 | 96.2 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  |
| 5569 | s-parvab |  | 100% | name | 3096 | 100 |  | S -Parvovirus, vasta-aineet | Serum |  |
| 5570 | s-parvabg | eiu | 2% | name+unit+values | 67 | 0 | [10, 35, 50, 61, 71.88, 80.25, 90, 90, 100] | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5571 | s-parvabg | ie/ml | 0% | name+unit | 5 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5572 | s-parvabg | index | 8% | name+unit+values | 250 | 0 | [10.1, 15.96, 22.67, 26.36, 30.21, 33.04, 36.98, 39.69, 42.76] | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5573 | s-parvabg | iu/ml | 2% | name+unit | 57 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5574 | s-parvabg | titre | 19% | name+unit+values | 558 | 0 | [200, 400, 800, 800, 800, 1555.56, 1600, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5575 | s-parvabg |  | 69% | name+values | 2056 | 91.73 | [4.91, 11.45, 38.67, 122.23, 400, 800, 800, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  |
| 5576 | s-parvabm |  | 100% | name | 2965 | 99.46 |  | S -Parvovirus, IgM-vasta-aineet | Serum |  |
| 5577 | s-parvavi | % | 2% | name+unit | 13 | 0 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  |
| 5578 | s-parvavi |  | 98% | name | 600 | 95.33 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  |
| 5579 | s-pekpähe | u/ml | 29% | name+unit | 31 | 0 |  |  | Serum |  |
| 5580 | s-pekpähe |  | 71% | name | 77 | 96.1 |  |  | Serum |  |
| 5581 | s-sakspäe | u/ml | 90% | name+unit+values | 883 | 0 | [0, 0, 0, 0.01, 0.01, 0.03, 0.07, 0.21, 1.55] |  | Serum |  |
| 5582 | s-sakspäe |  | 10% | name | 95 | 74.74 |  |  | Serum |  |
| 5583 | s-sappih | umol/l | 82% | name+unit+values | 9172 | 0.36 | [2, 2.87, 3.49, 4.45, 5.83, 7.59, 10.65, 16.77, 32.84] | S -Sappihapot | Serum |  |
| 5584 | s-sappih |  | 18% | name+values | 1955 | 50.33 | [2, 3, 3, 4, 4.4, 5.33, 7.05, 9.69, 18.19] | S -Sappihapot | Serum |  |
| 5585 | s-valpr | % | 0% | name+unit | 33 | 0 |  | S -Valproaatti | Serum |  |
| 5586 | s-valpr | umol/l | 96% | name+unit+values | 35853 | 0.05 | [220.39, 285.23, 332.16, 372.59, 408.92, 446.56, 486.81, 533.22, 600.78] | S -Valproaatti | Serum |  |
| 5587 | s-valpr |  | 4% | name+values | 1583 | 100 | [195.88, 257.11, 300.41, 340.81, 382.77, 422.91, 465.76, 516.34, 588.53] | S -Valproaatti | Serum |  |
| 5588 | s-valpr-v | umol/l | 79% | name+unit+values | 818 | 0 | [25.49, 29.94, 35.24, 39.88, 44.93, 50.41, 57.45, 67.85, 86.45] | S -Valproaatti, vapaa | Serum | Free or unconjugated |
| 5589 | s-valpr-v |  | 21% | name | 221 | 80.54 |  | S -Valproaatti, vapaa | Serum | Free or unconjugated |
| 5590 | s-valpro | umol/l | 97% | name+unit | 171 | 0 |  |  | Serum |  |
| 5591 | s-valpro |  | 3% | name | 5 | 100 |  |  | Serum |  |
| 5592 | s-vara |  | 100% | name | 340 | 100 |  |  | Serum |  |
| 5593 | s-varah |  | 100% | name | 253 | 100 |  |  | Serum |  |
| 5594 | sappihapot | umol/l | 92% | name+unit | 161 | 0 |  |  |  |  |
| 5595 | sappihapot |  | 8% | name | 14 | 100 |  |  |  |  |
| 5596 | sk-padihot |  | 100% | name | 24730 | 100 |  | Sk-Ihottumanäytteen histologinen tutkimus | Skin |  |
| 5597 | tupakka | u/24h | 85% | name+unit+values | 599 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 8.55] |  |  |  |
| 5598 | tupakka |  | 15% | name | 104 | 100 |  |  |  |  |
| 5599 | u-gluprot |  | 100% | name | 2097 | 100 |  |  | Urine |  |
| 5600 | u-partik |  | 100% | name | 14759 | 100 |  |  | Urine |  |
| 5601 | u-partikk |  | 100% | name | 5466 | 100 |  |  | Urine |  |
| 5602 | u-rakkoai | h | 99% | name+unit+values | 373 | 0 | [2.84, 4, 4, 4.03, 5, 6, 6.66, 7.87, 8.33] |  | Urine |  |
| 5603 | u-rakkoai |  | 1% | name | 5 | 100 |  |  | Urine |  |
| 5604 | u-sakka |  | 100% | name | 2736 | 100 |  |  | Urine |  |
| 5605 | u-valvott |  | 100% | name | 1125 | 100 |  |  | Urine |  |
| 5606 | u-varabak |  | 100% | name | 206 | 100 |  |  | Urine |  |

