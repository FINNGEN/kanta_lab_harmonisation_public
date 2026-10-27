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
Here is group 42 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 2427 | ab-na | mmol/l | 100% | name+unit+values | 1125 | 0 | [131.07, 134.74, 136.65, 138.04, 139.27, 140.42, 141.11, 142.54, 144.85] |  | Arterial blood | Native preparation |
| 2428 | am-lamel | e9/l | 97% | name+unit+values | 327 | 0 | [8.22, 12.77, 17.47, 21.27, 27.86, 33.66, 40.76, 49.86, 62.49] | Am-Lamellaarikappaleet | Amniotic fluid |  |
| 2429 | am-lamel |  | 3% | name | 10 | 100 |  | Am-Lamellaarikappaleet | Amniotic fluid |  |
| 2430 | ap-lakt | mmol/l | 99% | name+unit+values | 1456 | 0 | [0.69, 0.81, 0.96, 1.1, 1.28, 1.51, 1.82, 2.3, 3.23] |  |  |  |
| 2431 | ap-lakt |  | 1% | name | 18 | 100 |  |  |  |  |
| 2432 | ap-na | mmol/l | 100% | name+unit+values | 50270 | 0.07 | [130.69, 133.39, 134.98, 136, 136.99, 137.94, 138.91, 139.95, 141.72] |  |  | Native preparation |
| 2433 | ap-na |  | 0% | name | 233 | 100 |  |  |  | Native preparation |
| 2434 | ap-nak |  | 100% | name | 155 | 100 |  |  |  |  |
| 2435 | b-na | mmol/l | 86% | name+unit+values | 59360 | 0 | [132.83, 135.08, 136.5, 137.68, 138.42, 139.02, 140.21, 141.76, 144.07] |  | Blood | Native preparation |
| 2436 | b-na |  | 14% | name+values | 9740 | 100 | [132, 135.65, 137.06, 138.86, 139, 140, 140.25, 141, 142] |  | Blood | Native preparation |
| 2437 | cp-na | mmol/l | 94% | name+unit+values | 305 | 0 | [132, 134.13, 135.88, 137, 138, 139.24, 140, 141.93, 143] |  |  | Native preparation |
| 2438 | cp-na |  | 6% | name | 18 | 100 |  |  |  | Native preparation |
| 2439 | di-na | mmol/l | 100% | name+unit | 307 | 0 |  | Di-Natrium | Dialysis fluid | Native preparation |
| 2440 | du-na | mmol/24h | 74% | name+unit+values | 2845 | 0 | [76.9, 98.34, 115.34, 133.54, 151.44, 169.81, 193.27, 222.7, 272.41] | dU-Natrium | 24-hour urine | Native preparation |
| 2441 | du-na |  | 26% | name+values | 1021 | 100 | [65.99, 83.48, 103.21, 117.93, 138.14, 155.68, 172.4, 209.91, 273.5] | dU-Natrium | 24-hour urine | Native preparation |
| 2442 | fp-alat | u/l | 100% | name+unit+values | 1830 | 0 | [14.7, 17.39, 20.07, 22.45, 25.26, 29.41, 34.57, 41.87, 57.54] |  | Fasting plasma |  |
| 2443 | fp-ctx | ng/l | 2% | name+unit | 34 | 0 |  |  | Fasting plasma |  |
| 2444 | fp-ctx | ug/l | 71% | name+unit+values | 1281 | 0.23 | [0.09, 0.14, 0.2, 0.25, 0.3, 0.38, 0.48, 0.61, 0.81] |  | Fasting plasma |  |
| 2445 | fp-ctx |  | 27% | name+values | 491 | 100 | [0.12, 0.19, 0.26, 0.33, 0.42, 0.53, 0.63, 0.85, 1.5] |  | Fasting plasma |  |
| 2446 | fp-gt | u/l | 99% | name+unit+values | 772 | 0 | [15.59, 19.58, 23.9, 27.78, 33.1, 39.95, 49.61, 68.78, 105.4] |  | Fasting plasma |  |
| 2447 | fp-gt |  | 1% | name | 11 | 100 |  |  | Fasting plasma |  |
| 2448 | fp-na | mmol/l | 100% | name+unit+values | 6047 | 0 | [135.62, 137.92, 138.99, 139.97, 140.04, 141, 141.08, 142, 143] |  | Fasting plasma | Native preparation |
| 2449 | fp-na |  | 0% | name | 18 | 100 |  |  | Fasting plasma | Native preparation |
| 2450 | happi | % | 48% | name+unit+values | 838 | 0.24 | [25.89, 29.25, 34.66, 40, 44.71, 48.76, 54.72, 63.33, 83.17] |  |  |  |
| 2451 | happi | l | 8% | name+unit+values | 132 | 0 | [1, 1.5, 2, 2, 2, 2.93, 3, 3.9, 6.43] |  |  |  |
| 2452 | happi | l/min | 0% | name+unit | 6 | 0 |  |  |  |  |
| 2453 | happi |  | 44% | name | 774 | 100 |  |  |  |  |
| 2454 | j-papa |  | 100% | name | 183 | 100 |  |  |  |  |
| 2455 | p-acth | ng/l | 87% | name+unit+values | 10045 | 0 | [8.1, 11.17, 14.07, 17.18, 20.62, 24.78, 30.97, 40.56, 66.81] | P -Adrenokortikotropiini | Plasma |  |
| 2456 | p-acth | pmol/l | 0% | name+unit | 7 | 0 |  | P -Adrenokortikotropiini | Plasma |  |
| 2457 | p-acth |  | 13% | name+values | 1461 | 100 | [9.3, 12.05, 15.2, 18.33, 23.32, 27.18, 33.07, 40.35, 63.93] | P -Adrenokortikotropiini | Plasma |  |
| 2458 | p-alat | u/l | 97% | name+unit+values | 4827160 | 0 | [12.96, 15.82, 18.44, 20.97, 24.18, 27.92, 33.04, 41.55, 60.15] | P -Alaniiniaminotransferaasi | Plasma |  |
| 2459 | p-alat | umol/l | 0% | name+unit | 23 | 0 |  | P -Alaniiniaminotransferaasi | Plasma |  |
| 2460 | p-alat |  | 3% | name | 133418 | 100 |  | P -Alaniiniaminotransferaasi | Plasma |  |
| 2461 | p-alat. | u/l | 99% | name+unit+values | 896 | 0 | [12.41, 15.26, 17.78, 20.06, 22.46, 25.38, 29.04, 35.69, 47.17] |  | Plasma |  |
| 2462 | p-alat. |  | 1% | name | 10 | 100 |  |  | Plasma |  |
| 2463 | p-asat | u/l | 97% | name+unit+values | 466423 | 0 | [16.61, 19.52, 21.89, 24.36, 26.99, 30.42, 35.39, 44.79, 70.46] | P -Aspartaattiaminotransferaasi | Plasma |  |
| 2464 | p-asat | umol/l | 0% | name+unit+values | 215 | 0 | [17.67, 20, 22.09, 24.95, 26.7, 28.89, 32.58, 37.69, 51.22] | P -Aspartaattiaminotransferaasi | Plasma |  |
| 2465 | p-asat |  | 3% | name | 14767 | 100 |  | P -Aspartaattiaminotransferaasi | Plasma |  |
| 2466 | p-at3 | % | 98% | name+unit+values | 33387 | 0 | [53.99, 67.43, 77.05, 84.9, 91.49, 97.39, 103.39, 110.16, 119.61] | P -Antitrombiini III | Plasma |  |
| 2467 | p-at3 | form | 0% | name+unit | 18 | 0 |  | P -Antitrombiini III | Plasma |  |
| 2468 | p-at3 |  | 2% | name+values | 750 | 100 | [77.31, 88.51, 92.97, 98.3, 102.33, 106.75, 110.2, 114.52, 120] | P -Antitrombiini III | Plasma |  |
| 2469 | p-at3. | % | 95% | name+unit+values | 4852 | 0 | [82.69, 90.71, 95.75, 100.16, 103.96, 107.71, 111.91, 117.1, 124.45] |  | Plasma |  |
| 2470 | p-at3. |  | 5% | name+values | 269 | 100 | [87.62, 92.42, 97.42, 100.6, 104.78, 109, 113.23, 117.65, 123.61] |  | Plasma |  |
| 2471 | p-efa |  | 100% | name | 125 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  |
| 2472 | p-fakb | g/l | 77% | name+unit+values | 120 | 0 | [0.14, 0.16, 0.18, 0.2, 0.21, 0.21, 0.23, 0.26, 0.3] | P -Faktori B | Plasma |  |
| 2473 | p-fakb |  | 23% | name | 35 | 100 |  | P -Faktori B | Plasma |  |
| 2474 | p-fe | umol/l | 79% | name+unit+values | 2840 | 0 | [5.54, 7.67, 9.48, 11.27, 13.17, 14.88, 16.93, 19.43, 23.36] |  | Plasma |  |
| 2475 | p-fe |  | 21% | name+values | 740 | 100 | [5.17, 6.79, 8.59, 10.13, 12.1, 14.06, 16.49, 19.49, 23.47] |  | Plasma |  |
| 2476 | p-fs | s | 17% | name+unit+values | 319 | 0 | [28, 29.37, 30.81, 32, 33.25, 34.95, 36.52, 39.34, 45.23] |  | Plasma |  |
| 2477 | p-fs |  | 83% | name | 1586 | 100 |  |  | Plasma |  |
| 2478 | p-fv | % | 96% | name+unit+values | 6911 | 0.03 | [43.57, 58.38, 70.05, 80.34, 90.27, 99.83, 110.54, 122.66, 139.92] | P -Hyytymistekijä V | Plasma |  |
| 2479 | p-fv |  | 4% | name+values | 261 | 100 | [69.88, 80.83, 88.32, 96.16, 100.54, 105.37, 112.35, 122.09, 134.3] | P -Hyytymistekijä V | Plasma |  |
| 2480 | p-fx | % | 49% | name+unit+values | 916 | 0.22 | [45.39, 65.84, 76.4, 83.62, 90.78, 97.89, 105.11, 112.7, 123.23] | P -Hyytymistekijä X | Plasma |  |
| 2481 | p-fx |  | 51% | name+values | 949 | 100 | [66, 78.85, 83.42, 90.36, 95.2, 99.28, 105.22, 113.1, 120.2] | P -Hyytymistekijä X | Plasma |  |
| 2482 | p-gt | mg/ml | 0% | name+unit | 8 | 0 |  | P -Glutamyylitransferaasi | Plasma |  |
| 2483 | p-gt | u/l | 98% | name+unit+values | 820178 | 0 | [14.61, 18.77, 23.38, 29.11, 36.97, 48.58, 67.09, 102.78, 197.74] | P -Glutamyylitransferaasi | Plasma |  |
| 2484 | p-gt |  | 2% | name | 15977 | 100 |  | P -Glutamyylitransferaasi | Plasma |  |
| 2485 | p-k+na |  | 100% | name | 69230 | 100 |  |  | Plasma |  |
| 2486 | p-k,na |  | 100% | name | 2518 | 100 |  |  | Plasma |  |
| 2487 | p-k-na | mmol/l | 76% | name+unit | 594 | 0 |  |  | Plasma | Native preparation |
| 2488 | p-k-na |  | 24% | name | 186 | 100 |  |  | Plasma | Native preparation |
| 2489 | p-k-pa | mmol/l | 100% | name+unit+values | 197 | 0 | [3.52, 3.78, 3.9, 3.99, 4.05, 4.12, 4.3, 4.38, 4.56] |  | Plasma | Long-term / prolonged |
| 2490 | p-k/na |  | 100% | name | 321 | 100 |  |  | Plasma |  |
| 2491 | p-ked. | mmol/l | 100% | name+unit | 344 | 0 |  |  | Plasma |  |
| 2492 | p-kjd. | mmol/l | 100% | name+unit | 160 | 0 |  |  | Plasma |  |
| 2493 | p-la1 | s | 95% | name+unit+values | 1064 | 0 | [30.03, 32, 33.13, 34.76, 36.01, 37.8, 39.95, 44.95, 54.82] |  | Plasma |  |
| 2494 | p-la1 |  | 5% | name | 52 | 100 |  |  | Plasma |  |
| 2495 | p-la2 | s | 26% | name+unit+values | 498 | 0 | [32, 33.5, 35.52, 37, 38.95, 40.99, 43.05, 47.4, 53.69] |  | Plasma |  |
| 2496 | p-la2 |  | 74% | name | 1411 | 100 |  |  | Plasma |  |
| 2497 | p-laite | ug/l | 100% | name+unit+values | 106 | 0 | [2.9, 3.2, 3.49, 3.68, 4.03, 4.44, 5.31, 6.24, 7.96] |  | Plasma |  |
| 2498 | p-lam/m |  | 100% | name+values | 1896 | 100 | [1.02, 1.07, 1.11, 1.14, 1.16, 1.19, 1.21, 1.24, 1.28] |  | Plasma |  |
| 2499 | p-mypa | mg/l | 87% | name+unit+values | 1692 | 0 | [0.63, 0.99, 1.33, 1.71, 2.12, 2.67, 3.43, 4.41, 6.29] | P -Mykofenolihappo | Plasma |  |
| 2500 | p-mypa |  | 13% | name | 245 | 100 |  | P -Mykofenolihappo | Plasma |  |
| 2501 | p-na | mmol/ | 0% | name+unit | 14 | 0 |  | P -Natrium | Plasma | Native preparation |
| 2502 | p-na | mmol/l | 99% | name+unit+values | 7320578 | 0 | [134.08, 136.46, 137.96, 139, 139.93, 140.11, 141, 142, 143] | P -Natrium | Plasma | Native preparation |
| 2503 | p-na |  | 1% | name | 81059 | 100 |  | P -Natrium | Plasma | Native preparation |
| 2504 | p-na. | mmol/l | 100% | name+unit+values | 1467 | 0 | [134.62, 137, 138.31, 139.89, 140.56, 141, 142, 142.86, 144] |  | Plasma |  |
| 2505 | p-na: | mmol/l | 100% | name+unit+values | 621 | 0 | [131.69, 133.81, 135, 136.19, 137.81, 138.69, 139.63, 140.92, 142] |  | Plasma |  |
| 2506 | p-naed. | mmol/l | 100% | name+unit | 306 | 0 |  |  | Plasma |  |
| 2507 | p-najd. | mmol/l | 100% | name+unit | 154 | 0 |  |  | Plasma |  |
| 2508 | p-nak |  | 100% | name | 259040 | 100 |  |  | Plasma |  |
| 2509 | p-nap | mmol/l | 100% | name+unit+values | 342 | 0.29 | [132.72, 135.18, 137.36, 139, 140, 140.67, 141.97, 143, 145] |  | Plasma |  |
| 2510 | p-pc | % | 90% | name+unit+values | 7171 | 0 | [82.04, 95.56, 103.31, 110.09, 116.75, 123.11, 129.91, 139.06, 152.29] | P -Proteiini C | Plasma |  |
| 2511 | p-pc | form | 0% | name+unit | 12 | 0 |  | P -Proteiini C | Plasma |  |
| 2512 | p-pc |  | 10% | name+values | 763 | 100 | [85.52, 97.63, 105.02, 110.24, 116.71, 123.09, 130.39, 139.57, 155.46] | P -Proteiini C | Plasma |  |
| 2513 | p-pct | ng/ml | 5% | name+unit+values | 1499 | 0 | [0.1, 0.1, 0.2, 0.28, 0.4, 0.64, 1.17, 2.72, 8.99] | P -Prokalsitoniini | Plasma |  |
| 2514 | p-pct | ug/l | 91% | name+unit+values | 25253 | 0 | [0.07, 0.1, 0.13, 0.18, 0.26, 0.4, 0.68, 1.41, 5.19] | P -Prokalsitoniini | Plasma |  |
| 2515 | p-pct |  | 4% | name | 1082 | 100 |  | P -Prokalsitoniini | Plasma |  |
| 2516 | p-pi | mmol/l | 99% | name+unit+values | 186393 | 0 | [0.74, 0.87, 0.96, 1.05, 1.13, 1.23, 1.34, 1.5, 1.79] | P -Fosfaatti, epäorgaaninen | Plasma |  |
| 2517 | p-pi |  | 1% | name | 2732 | 100 |  | P -Fosfaatti, epäorgaaninen | Plasma |  |
| 2518 | p-prl | mu/l | 98% | name+unit+values | 10459 | 0 | [139.86, 185.19, 223.46, 260.99, 305.79, 361.97, 438.81, 570.22, 911.44] | P -Prolaktiini | Plasma |  |
| 2519 | p-prl | nmol/l | 0% | name+unit | 16 | 0 |  | P -Prolaktiini | Plasma |  |
| 2520 | p-prl |  | 2% | name | 162 | 100 |  | P -Prolaktiini | Plasma |  |
| 2521 | p-ps | % | 79% | name+unit+values | 1651 | 0 | [65.21, 76.7, 83.61, 90.03, 95.98, 101.09, 108.67, 116.41, 129.83] | P -Proteiini S | Plasma | Basic screening |
| 2522 | p-ps |  | 21% | name+values | 443 | 100 | [67.73, 78.79, 88.29, 94.24, 100.12, 106.66, 112.61, 120.5, 131.45] | P -Proteiini S | Plasma | Basic screening |
| 2523 | p-psa | ug/l | 88% | name+unit+values | 440363 | 0 | [0.27, 0.54, 0.84, 1.21, 1.72, 2.49, 3.62, 5.6, 9.72] | P -Prostataspesifinen antigeeni | Plasma |  |
| 2524 | p-psa |  | 12% | name | 61308 | 100 |  | P -Prostataspesifinen antigeeni | Plasma |  |
| 2525 | p-pt | s | 100% | name+unit | 184 | 0 |  |  | Plasma |  |
| 2526 | p-rvvt-l |  | 100% | name | 1894 | 100 |  |  | Plasma |  |
| 2527 | p-supar | ug/l | 96% | name+unit+values | 351 | 0 | [2.88, 3.25, 3.62, 3.93, 4.32, 4.72, 5.27, 6.34, 8.2] |  | Plasma |  |
| 2528 | p-supar |  | 4% | name | 16 | 100 |  |  | Plasma |  |
| 2529 | p-tfr | mg/l | 92% | name+unit+values | 188406 | 0 | [0.9, 1.59, 2.26, 2.65, 3.02, 3.46, 4.03, 4.87, 6.51] | P -Transferriinireseptori, liukoinen | Plasma |  |
| 2530 | p-tfr |  | 8% | name | 15951 | 100 |  | P -Transferriinireseptori, liukoinen | Plasma |  |
| 2531 | p-tt | % | 99% | name+unit+values | 472003 | 0 | [50.27, 64.91, 74.21, 81.59, 88.34, 94.66, 101.65, 109.8, 121.37] | P -Tromboplastiiniaika | Plasma |  |
| 2532 | p-tt | form | 0% | name+unit | 20 | 0 |  | P -Tromboplastiiniaika | Plasma |  |
| 2533 | p-tt |  | 1% | name | 4462 | 100 |  | P -Tromboplastiiniaika | Plasma |  |
| 2534 | p-tt- | % | 98% | name+unit+values | 1432 | 0 | [60.41, 72.11, 78.26, 83.23, 88.7, 95.38, 102.26, 111.84, 122.4] |  | Plasma |  |
| 2535 | p-tt- |  | 2% | name | 29 | 100 |  |  | Plasma |  |
| 2536 | p-tt. | % | 94% | name+unit+values | 5628 | 0 | [63.23, 78.72, 87.03, 93.55, 99.79, 105.77, 112.44, 119.67, 130.79] |  | Plasma |  |
| 2537 | p-tt. |  | 6% | name+values | 328 | 100 | [49.07, 79.43, 90.33, 98.82, 106.71, 114.28, 121.35, 130.68, 140.29] |  | Plasma |  |
| 2538 | p-ttr | % | 93% | name+unit+values | 1114 | 0 | [50.96, 61.18, 67.8, 73.84, 78.53, 83.21, 89.2, 95.05, 100] |  | Plasma |  |
| 2539 | p-ttr |  | 7% | name | 89 | 100 |  |  | Plasma |  |
| 2540 | papa |  | 100% | name | 1138 | 100 |  |  |  |  |
| 2541 | pdgfr |  | 100% | name | 461 | 100 |  |  |  |  |
| 2542 | peak | l/min | 10% | name+unit | 12 | 0 |  |  |  |  |
| 2543 | peak |  | 90% | name | 104 | 100 |  |  |  |  |
| 2544 | pef-pa |  | 100% | name | 7844 | 100 |  | Uloshengityksen huippuvirtaus, sarjamittaus, pitkäaikaisseuranta |  | Long-term / prolonged |
| 2545 | pef-ras |  | 100% | name | 242 | 100 |  | Uloshengityksen huippuvirtaus, sarjamittaus, rasituskoe |  |  |
| 2546 | pf-ace | u/l | 66% | name+unit+values | 313 | 0.32 | [6.33, 10.32, 12.86, 15.39, 17.8, 19.84, 24.02, 28.69, 37.34] | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  |
| 2547 | pf-ace |  | 34% | name | 161 | 100 |  | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  |
| 2548 | pf-ada | u/l | 91% | name+unit+values | 3550 | 0 | [3.68, 5.17, 6.79, 8.03, 9.48, 11.18, 13.51, 17.41, 25.63] | Pf-Adenosiinideaminaasi | Pleural fluid |  |
| 2549 | pf-ada |  | 9% | name | 365 | 100 |  | Pf-Adenosiinideaminaasi | Pleural fluid |  |
| 2550 | pipelle |  | 100% | name | 428 | 100 |  |  |  |  |
| 2551 | pneag |  | 100% | name | 244 | 100 |  |  |  |  |
| 2552 | pt-ivfal |  | 100% | name | 165 | 100 |  |  | Patient |  |
| 2553 | pt-vp-ple |  | 100% | name | 102 | 100 |  |  | Patient |  |
| 2554 | s-alat | iu/l | 0% | name+unit+values | 251 | 0 | [13.21, 15.82, 17.12, 19.56, 22, 24.18, 28.14, 35.6, 55.67] | S -Alaniiniaminotransferaasi | Serum |  |
| 2555 | s-alat | u/l | 99% | name+unit+values | 323441 | 0 | [13.96, 17.08, 19.84, 22.78, 26.1, 30.03, 35.11, 42.65, 57.13] | S -Alaniiniaminotransferaasi | Serum |  |
| 2556 | s-alat |  | 1% | name+values | 4631 | 100 | [14.16, 17.24, 20.69, 23.7, 27.55, 33.68, 39.69, 48.95, 68.13] | S -Alaniiniaminotransferaasi | Serum |  |
| 2557 | s-asat | iu/l | 1% | name+unit+values | 247 | 0 | [18, 20.05, 21.99, 23.65, 25, 27.54, 29.68, 34.42, 41.57] | S -Aspartaattiaminotransferaasi | Serum |  |
| 2558 | s-asat | u/l | 98% | name+unit+values | 22999 | 0 | [17.95, 20.33, 22.41, 24.42, 26.51, 29.05, 32.45, 37.78, 49.76] | S -Aspartaattiaminotransferaasi | Serum |  |
| 2559 | s-asat |  | 1% | name+values | 171 | 100 | [18, 19, 22, 24, 24.5, 25.75, 29, 35, 49] | S -Aspartaattiaminotransferaasi | Serum |  |
| 2560 | s-na | mmol/l | 99% | name+unit+values | 124118 | 0 | [137.11, 138.74, 139.05, 140, 140.15, 141, 141.38, 142, 143] | S -Natrium | Serum | Native preparation |
| 2561 | s-na |  | 1% | name+values | 931 | 100 | [133.78, 137, 138.07, 139, 140, 140, 140.93, 141, 142.02] | S -Natrium | Serum | Native preparation |
| 2562 | s-prl | miu/l | 5% | name+unit+values | 1647 | 0 | [99, 122.35, 142.41, 160.53, 182.22, 206.49, 242.23, 297.21, 453.2] | S -Prolaktiini | Serum |  |
| 2563 | s-prl | mu/l | 93% | name+unit+values | 31229 | 0 | [116.54, 154.56, 187.96, 224.2, 266.24, 319.79, 396.49, 532.56, 848.45] | S -Prolaktiini | Serum |  |
| 2564 | s-prl | mul/l | 0% | name+unit | 6 | 0 |  | S -Prolaktiini | Serum |  |
| 2565 | s-prl | nmol/l | 0% | name+unit | 58 | 0 |  | S -Prolaktiini | Serum |  |
| 2566 | s-prl |  | 2% | name | 718 | 100 |  | S -Prolaktiini | Serum |  |
| 2567 | s-psa | mg/l | 0% | name+unit | 7 | 0 |  | S -Prostataspesifinen antigeeni | Serum |  |
| 2568 | s-psa | ug/l | 95% | name+unit+values | 91718 | 0 | [0.38, 0.57, 0.75, 0.96, 1.25, 1.64, 2.26, 3.32, 5.46] | S -Prostataspesifinen antigeeni | Serum |  |
| 2569 | s-psa |  | 5% | name | 4826 | 100 |  | S -Prostataspesifinen antigeeni | Serum |  |
| 2570 | s-tfr | mg | 0% | name+unit | 7 | 0 |  | S -Transferriinireseptori, liukoinen | Serum |  |
| 2571 | s-tfr | mg/l | 98% | name+unit+values | 77760 | 0 | [1.01, 1.24, 1.52, 1.93, 2.39, 2.84, 3.37, 4.15, 5.68] | S -Transferriinireseptori, liukoinen | Serum |  |
| 2572 | s-tfr |  | 2% | name | 1379 | 100 |  | S -Transferriinireseptori, liukoinen | Serum |  |
| 2573 | sp-pak |  | 100% | name | 196 | 100 |  |  | Sperm / semen |  |
| 2574 | sp-pakd |  | 100% | name | 138 | 100 |  |  | Sperm / semen |  |
| 2575 | u-na | mmol/l | 77% | name+unit+values | 8969 | 0 | [24.77, 32.46, 40.33, 48.4, 57.48, 68.26, 81.68, 99.24, 129.77] | U -Natrium | Urine | Native preparation |
| 2576 | u-na |  | 23% | name+values | 2662 | 100 | [27.31, 35.62, 42.78, 51.38, 60.48, 68.93, 78.14, 92.21, 110.65] | U -Natrium | Urine | Native preparation |
| 2577 | v-na |  | 100% | name+values | 265 | 100 | [130.07, 134.25, 136, 137.63, 138.47, 139, 140, 141, 142] |  |  | Native preparation |
| 2578 | vp-na | mmol/l | 98% | name+unit+values | 10896 | 0 | [132.88, 135.36, 136.91, 137.97, 139, 139.83, 140.33, 141.06, 142.5] |  |  | Native preparation |
| 2579 | vp-na |  | 2% | name | 174 | 100 |  |  |  | Native preparation |
| 2580 | vp-ple |  | 100% | name | 725 | 100 |  | Valtimopaine ja verenvirtaus, pletysmografi |  |  |

