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
Here is group 73 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 5506 | -kskäynt |  | 100% | name | 14336 | 100 |  |  |  |  |
| 5507 | -ku72/86 |  | 100% | name | 958 | 100 |  |  |  |  |
| 5508 | -nudt15 |  | 100% | name+values | 2593 | 100 | [16, 16, 16, 16, 16, 16, 16, 16, 16] |  |  |  |
| 5509 | -s.yht. | e6 | 95% | name+unit+values | 1504 | 0 | [1.76, 9.88, 23.81, 46.09, 70.79, 95.11, 132.38, 178.2, 261.34] |  |  |  |
| 5510 | -s.yht. |  | 5% | name | 83 | 100 |  |  |  |  |
| 5511 | -selvtyö |  | 100% | name | 360 | 100 |  |  |  |  |
| 5512 | -siitt. | e6/ml | 38% | name+unit+values | 1198 | 0 | [1.77, 7.42, 17.66, 25.89, 34.94, 43.13, 56.07, 73.53, 101.25] |  |  |  |
| 5513 | -siitt. |  | 62% | name | 1937 | 100 |  |  |  |  |
| 5514 | audit | form | 45% | name+unit+values | 399 | 0 | [0, 1, 2, 2.47, 3, 4, 4.99, 6.54, 8.56] |  |  |  |
| 5515 | audit |  | 55% | name+values | 480 | 100 | [0, 0.98, 1, 2, 2.42, 3.62, 4, 5.74, 8.96] |  |  |  |
| 5516 | audit-c |  | 100% | name+values | 187 | 100 | [1, 1, 2, 2, 3, 3, 3, 4, 5] |  |  |  |
| 5517 | dnauut1 |  | 100% | name | 166 | 100 |  |  |  |  |
| 5518 | f-kystat |  | 100% | name | 7014 | 100 |  |  | Feces |  |
| 5519 | ku72/86 |  | 100% | name | 1497 | 100 |  |  |  |  |
| 5520 | p-d-25 | nmol/l | 99% | name+unit+values | 93835 | 0 | [47.27, 57.52, 64.99, 71.99, 78.59, 85.79, 93.98, 104.82, 121.75] | P -D-vitamiini-25-OH | Plasma |  |
| 5521 | p-d-25 |  | 1% | name | 1037 | 100 |  | P -D-vitamiini-25-OH | Plasma |  |
| 5522 | p-kysc | mg/l | 100% | name+unit+values | 55470 | 0 | [0.84, 0.96, 1.08, 1.23, 1.41, 1.63, 1.91, 2.32, 3.12] | P -Kystatiini C | Plasma |  |
| 5523 | p-kysc |  | 0% | name | 196 | 100 |  | P -Kystatiini C | Plasma |  |
| 5524 | p-nkäs10 |  | 100% | name | 803 | 100 |  |  | Plasma |  |
| 5525 | s-5-ht | nmol/l | 87% | name+unit+values | 224 | 0 | [100.62, 206.57, 388.63, 493.54, 647.03, 818.29, 936.71, 1116.9, 1624] | S -Hydroksitryptamiini (5-) | Serum |  |
| 5526 | s-5-ht |  | 13% | name | 33 | 100 |  | S -Hydroksitryptamiini (5-) | Serum |  |
| 5527 | s-ck-is |  | 100% | name | 326 | 100 |  | S -Kreatiinikinaasi, isoentsyymit | Serum | Isoenzymes |
| 5528 | s-ctdscr |  | 100% | name+values | 123 | 100 | [0.1, 0.1, 0.1, 0.2, 0.2, 0.2, 0.3, 0.41, 1.2] |  | Serum |  |
| 5529 | s-d-1,25 | pmol/l | 87% | name+unit+values | 5369 | 0.02 | [55.49, 72.65, 85.92, 96.71, 107.01, 117.78, 130.2, 146.12, 170.51] | S -D-vitamiini-1,25-OH | Serum |  |
| 5530 | s-d-1,25 |  | 13% | name+values | 793 | 100 | [53.62, 70.32, 82.73, 93.66, 102.64, 113.83, 125.96, 141.84, 170.33] | S -D-vitamiini-1,25-OH | Serum |  |
| 5531 | s-d-25 | nmol/l | 99% | name+unit+values | 395823 | 0 | [46.37, 55.92, 63.01, 69.37, 75.68, 82.28, 90.01, 100.09, 116.33] | S -D-vitamiini-25-OH | Serum |  |
| 5532 | s-d-25 |  | 1% | name | 3522 | 100 |  | S -D-vitamiini-25-OH | Serum |  |
| 5533 | s-d-25-32 | nmol/l | 95% | name+unit+values | 1945 | 0 | [42.81, 52.88, 60.32, 66.43, 72.91, 78.86, 85.75, 94.48, 107.92] |  | Serum |  |
| 5534 | s-d-25-32 |  | 5% | name+values | 109 | 100 | [39, 42, 47.62, 52.5, 62.5, 67, 77, 85, 101] |  | Serum |  |
| 5535 | s-d2-25 | nmol/l | 24% | name+unit+values | 140 | 0 | [8.95, 11, 12.5, 14, 16, 18.32, 20.85, 26.09, 34.5] | S -D2-vitamiini-25-OH | Serum |  |
| 5536 | s-d2-25 |  | 76% | name | 436 | 100 |  | S -D2-vitamiini-25-OH | Serum |  |
| 5537 | s-d3-25 | nmol/l | 93% | name+unit+values | 2269 | 0 | [41.3, 52.08, 59.25, 66.03, 72.52, 78.44, 84.87, 93.25, 107.79] | S -D3-vitamiini-25-OH | Serum |  |
| 5538 | s-d3-25 |  | 7% | name+values | 183 | 100 | [44, 51, 58.4, 64.35, 70, 77.2, 85, 91.25, 101] | S -D3-vitamiini-25-OH | Serum |  |
| 5539 | s-ketiap | nmol/l | 73% | name+unit+values | 678 | 0 | [92.76, 170.13, 253.54, 334.41, 416.64, 519.04, 659.62, 894.01, 1335.87] | S -Ketiapiini | Serum |  |
| 5540 | s-ketiap |  | 27% | name+values | 253 | 100 | [86.16, 138.77, 221.12, 302.45, 415.62, 487.41, 585.26, 794.71, 1304.5] | S -Ketiapiini | Serum |  |
| 5541 | s-kid10 |  | 100% | name | 729 | 100 |  |  | Serum |  |
| 5542 | s-kipa |  | 100% | name | 39484 | 100 |  |  | Serum |  |
| 5543 | s-krtiin | umol/l | 100% | name+unit+values | 334 | 0 | [53.14, 57.95, 63.02, 66.17, 69.73, 74.27, 79.36, 85.56, 91.27] | S -Kreatiini | Serum |  |
| 5544 | s-kubico |  | 100% | name | 571 | 100 |  |  | Serum |  |
| 5545 | s-kysc | mg/l | 87% | name+unit+values | 5526 | 0 | [0.81, 0.89, 0.98, 1.06, 1.17, 1.31, 1.51, 1.81, 2.34] | S -Kystatiini C | Serum |  |
| 5546 | s-kysc |  | 13% | name+values | 848 | 100 | [0.94, 1.14, 1.25, 1.38, 1.56, 1.78, 1.97, 2.33, 2.99] | S -Kystatiini C | Serum |  |
| 5547 | s-käsmak |  | 100% | name | 312 | 100 |  |  | Serum |  |
| 5548 | s-ld-1 | % | 92% | name+unit+values | 212 | 1.42 | [16.74, 19.25, 20.9, 22.13, 23.41, 24.74, 26.56, 27.97, 32] | S -Laktaattidehydrogenaasi, isoentsyymi 1 | Serum |  |
| 5549 | s-ld-1 |  | 8% | name | 18 | 100 |  | S -Laktaattidehydrogenaasi, isoentsyymi 1 | Serum |  |
| 5550 | s-ld-2 | % | 92% | name+unit+values | 200 | 0.5 | [31.26, 33.03, 34.03, 35.18, 36.53, 37.55, 38.57, 39.48, 41.3] |  | Serum |  |
| 5551 | s-ld-2 |  | 8% | name | 17 | 100 |  |  | Serum |  |
| 5552 | s-ld-3 | % | 91% | name+unit+values | 198 | 0.51 | [16.7, 18.6, 19.86, 20.8, 21.55, 22.38, 23.44, 24.42, 25.95] |  | Serum |  |
| 5553 | s-ld-3 |  | 9% | name | 19 | 100 |  |  | Serum |  |
| 5554 | s-ld-4 | % | 91% | name+unit+values | 195 | 0.51 | [5.62, 6.8, 7.36, 8.13, 8.54, 9.23, 10.04, 10.9, 12.07] |  | Serum |  |
| 5555 | s-ld-4 |  | 9% | name | 19 | 100 |  |  | Serum |  |
| 5556 | s-ld-5 | % | 91% | name+unit+values | 210 | 0.95 | [5.03, 6.14, 7.01, 7.64, 8.6, 9.45, 10.74, 12.13, 15.29] | S -Laktaattidehydrogenaasi, isoentsyymi 5 | Serum |  |
| 5557 | s-ld-5 |  | 9% | name | 21 | 100 |  | S -Laktaattidehydrogenaasi, isoentsyymi 5 | Serum |  |
| 5558 | s-ld-is |  | 100% | name | 243 | 100 |  | S -Laktaattidehydrogenaasi, isoentsyymit | Serum | Isoenzymes |
| 5559 | s-ldpit | u/l | 82% | name+unit+values | 145 | 0 | [153.9, 174.43, 189.35, 197.65, 204.73, 215.72, 233.25, 253.4, 304.1] |  | Serum |  |
| 5560 | s-ldpit |  | 18% | name | 32 | 100 |  |  | Serum |  |
| 5561 | s-liv2x10 |  | 100% | name | 1270 | 100 |  |  | Serum |  |
| 5562 | s-o4.5.12 | titre | 6% | name+unit | 66 | 0 |  |  | Serum |  |
| 5563 | s-o4.5.12 |  | 94% | name | 1134 | 100 |  |  | Serum |  |
| 5564 | s-pm-scl | u/ml | 57% | name+unit+values | 166 | 0 | [1, 1, 1, 1, 1, 1.21, 2, 2, 3] |  | Serum |  |
| 5565 | s-pm-scl |  | 43% | name | 125 | 100 |  |  | Serum |  |
| 5566 | s-pmdm-t |  | 100% | name | 313 | 100 |  |  | Serum |  |
| 5567 | s-prkäsit |  | 100% | name | 767 | 100 |  |  | Serum |  |
| 5568 | s-w-h:a | titre | 1% | name+unit | 7 | 0 |  |  | Serum |  |
| 5569 | s-w-h:a |  | 99% | name | 1090 | 100 |  |  | Serum |  |
| 5570 | s-w-h:b | titre | 31% | name+unit+values | 338 | 0 | [160, 160, 320, 320, 320, 320, 640, 873.14, 2242.44] |  | Serum |  |
| 5571 | s-w-h:b |  | 69% | name | 760 | 100 |  |  | Serum |  |
| 5572 | s-w-h:d | titre | 15% | name+unit+values | 161 | 0 | [160, 160, 284.8, 320, 320, 640, 640, 1096, 2500] |  | Serum |  |
| 5573 | s-w-h:d |  | 85% | name | 937 | 100 |  |  | Serum |  |
| 5574 | s-w-h:g.m | titre | 11% | name+unit+values | 121 | 0 | [160, 160, 166.4, 320, 320, 320, 640, 640, 1280] |  | Serum |  |
| 5575 | s-w-h:g.m |  | 89% | name | 977 | 100 |  |  | Serum |  |
| 5576 | s-w-h:i | titre | 22% | name+unit+values | 243 | 0 | [160, 160, 160, 189.92, 320, 320, 320, 611.56, 640] |  | Serum |  |
| 5577 | s-w-h:i |  | 78% | name | 855 | 100 |  |  | Serum |  |
| 5578 | s-w-o6.7 | titre | 7% | name+unit+values | 78 | 0 | [80, 80, 80, 80, 133.33, 160, 160, 320, 320] |  | Serum |  |
| 5579 | s-w-o6.7 |  | 93% | name | 980 | 100 |  |  | Serum |  |
| 5580 | s-w-o9.12 | titre | 16% | name+unit+values | 172 | 0 | [80, 80, 80, 160, 160, 160, 160, 160, 320] |  | Serum |  |
| 5581 | s-w-o9.12 |  | 84% | name | 885 | 100 |  |  | Serum |  |
| 5582 | s-yskät |  | 100% | name | 102 | 100 |  |  | Serum |  |
| 5583 | sjukhus |  | 100% | name | 696 | 100 |  |  |  |  |
| 5584 | sukup.tau1 |  | 100% | name | 211 | 100 |  |  |  |  |
| 5585 | sukup1 |  | 100% | name | 184 | 100 |  |  |  |  |
| 5586 | sukup2 |  | 100% | name | 101 | 100 |  |  |  |  |
| 5587 | u-käsma |  | 100% | name | 934 | 100 |  |  | Urine |  |

