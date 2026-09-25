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
Here is group 42 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 2487 | ab-na | mmol/l | 100% | name+unit+values | 1125 | 0 | [130.94, 134.84, 136.62, 138.04, 139.34, 140.42, 141.09, 142.57, 144.87] |  | Arterial blood | Native preparation |
| 2488 | ap-lakt | mmol/l | 99% | name+unit+values | 1456 | 0 | [0.68, 0.81, 0.96, 1.1, 1.28, 1.5, 1.81, 2.29, 3.25] |  |  |  |
| 2489 | ap-lakt |  | 1% | name | 18 | 50 |  |  |  |  |
| 2490 | ap-na | % | 0% | name+unit | 24 | 0 |  |  |  | Native preparation |
| 2491 | ap-na | g/l | 0% | name+unit | 6 | 0 |  |  |  | Native preparation |
| 2492 | ap-na | kpa | 0% | name+unit | 12 | 0 |  |  |  | Native preparation |
| 2493 | ap-na | mmol/l | 99% | name+unit+values | 50270 | 0 | [130.71, 133.37, 134.96, 136, 136.98, 137.95, 138.88, 139.98, 141.72] |  |  | Native preparation |
| 2494 | ap-na | °c | 0% | name+unit | 6 | 0 |  |  |  | Native preparation |
| 2495 | ap-na |  | 0% | name | 233 | 92.27 |  |  |  | Native preparation |
| 2496 | ap-nak |  | 100% | name | 155 | 100 |  |  |  |  |
| 2497 | b-na | mmol/l | 86% | name+unit+values | 59360 | 0 | [132.76, 134.99, 136.51, 137.61, 138.41, 139.21, 140.23, 141.69, 144.08] |  | Blood | Native preparation |
| 2498 | b-na |  | 14% | name+values | 9740 | 95.39 | [132.18, 135.78, 137.16, 138.83, 139, 140, 140.41, 141, 142] |  | Blood | Native preparation |
| 2499 | cp-na | mmol/l | 94% | name+unit+values | 305 | 0 | [132, 134.22, 135.76, 137, 138, 139.28, 140, 141.93, 143] |  |  | Native preparation |
| 2500 | cp-na |  | 6% | name | 18 | 100 |  |  |  | Native preparation |
| 2501 | di-na | mmol/l | 98% | name+unit | 307 | 0 |  | Di-Natrium | Dialysis fluid | Native preparation |
| 2502 | di-na |  | 2% | name | 5 | 100 |  | Di-Natrium | Dialysis fluid | Native preparation |
| 2503 | du-na | mmol | 72% | name+unit+values | 2785 | 0.25 | [76.79, 98.05, 115.16, 132.8, 151.88, 170.12, 193.55, 223.43, 273.21] | dU-Natrium | 24-hour urine | Native preparation |
| 2504 | du-na | mmol/24h | 2% | name+unit | 60 | 0 |  | dU-Natrium | 24-hour urine | Native preparation |
| 2505 | du-na |  | 26% | name+values | 1021 | 70.23 | [65.53, 84.3, 103.25, 116.92, 139.24, 156.61, 172.58, 210.59, 273.58] | dU-Natrium | 24-hour urine | Native preparation |
| 2506 | fp-ctx | ng/l | 2% | name+unit | 34 | 0 |  |  | Fasting plasma |  |
| 2507 | fp-ctx | ug/l | 71% | name+unit+values | 1281 | 0 | [0.09, 0.14, 0.2, 0.25, 0.3, 0.38, 0.48, 0.6, 0.81] |  | Fasting plasma |  |
| 2508 | fp-ctx |  | 27% | name+values | 491 | 16.7 | [0.12, 0.19, 0.24, 0.31, 0.39, 0.48, 0.58, 0.71, 1] |  | Fasting plasma |  |
| 2509 | fp-gt | u/l | 99% | name+unit+values | 772 | 0 | [15.6, 19.58, 23.9, 27.61, 33.27, 39.92, 49.93, 68.82, 104.64] |  | Fasting plasma |  |
| 2510 | fp-gt |  | 1% | name | 11 | 0 |  |  | Fasting plasma |  |
| 2511 | fp-na | mmol/l | 100% | name+unit+values | 6047 | 0 | [135.6, 137.84, 139, 139.97, 140.01, 141, 141.04, 142, 143] |  | Fasting plasma | Native preparation |
| 2512 | fp-na |  | 0% | name | 18 | 11.11 |  |  | Fasting plasma | Native preparation |
| 2513 | p-acth | ng/l | 87% | name+unit+values | 10045 | 0.42 | [8.08, 11.12, 14.1, 17.14, 20.58, 24.79, 30.92, 40.41, 66.95] | P -Adrenokortikotropiini | Plasma |  |
| 2514 | p-acth | pmol/l | 0% | name+unit | 7 | 0 |  | P -Adrenokortikotropiini | Plasma |  |
| 2515 | p-acth |  | 13% | name+values | 1461 | 80.01 | [9.26, 12.21, 15.18, 18.04, 23.17, 27.09, 32.96, 40.36, 61.68] | P -Adrenokortikotropiini | Plasma |  |
| 2516 | p-at3 | % | 98% | name+unit+values | 33387 | 0.01 | [54.15, 67.47, 77.12, 84.9, 91.44, 97.34, 103.31, 110.17, 119.77] | P -Antitrombiini III | Plasma |  |
| 2517 | p-at3 | form | 0% | name+unit | 18 | 0 |  | P -Antitrombiini III | Plasma |  |
| 2518 | p-at3 |  | 2% | name+values | 750 | 50.4 | [77.41, 88.27, 92.93, 97.96, 101.75, 106.37, 110.41, 114.53, 119.94] | P -Antitrombiini III | Plasma |  |
| 2519 | p-at3. | % | 95% | name+unit+values | 4852 | 0 | [82.58, 90.63, 95.72, 100.18, 103.97, 107.65, 111.95, 117.06, 124.39] |  | Plasma |  |
| 2520 | p-at3. |  | 5% | name+values | 269 | 20.45 | [87.63, 92.63, 97.23, 100.8, 104.86, 109.03, 113.28, 117.74, 123.49] |  | Plasma |  |
| 2521 | p-efa | form | 4% | name+unit | 5 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  |
| 2522 | p-efa |  | 96% | name | 125 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  |
| 2523 | p-fakb | g/l | 77% | name+unit+values | 120 | 0 | [0.14, 0.17, 0.18, 0.2, 0.21, 0.21, 0.23, 0.26, 0.3] | P -Faktori B | Plasma |  |
| 2524 | p-fakb |  | 23% | name | 35 | 25.71 |  | P -Faktori B | Plasma |  |
| 2525 | p-fe | umol/l | 79% | name+unit+values | 2840 | 0 | [5.52, 7.66, 9.48, 11.25, 13.18, 14.87, 16.94, 19.46, 23.35] |  | Plasma |  |
| 2526 | p-fe |  | 21% | name+values | 740 | 33.92 | [5.15, 6.78, 8.55, 10.06, 12.18, 14.07, 16.43, 19.54, 23.49] |  | Plasma |  |
| 2527 | p-fs | s | 17% | name+unit+values | 319 | 0 | [28, 29.31, 30.81, 32, 33.17, 35, 36.48, 39.22, 45.08] |  | Plasma |  |
| 2528 | p-fs |  | 83% | name | 1586 | 99.87 |  |  | Plasma |  |
| 2529 | p-fv | % | 96% | name+unit+values | 6911 | 0.01 | [43.78, 58.4, 69.62, 80.37, 90.29, 99.93, 110.48, 122.94, 139.52] | P -Hyytymistekijä V | Plasma |  |
| 2530 | p-fv |  | 4% | name+values | 261 | 40.23 | [68.7, 79.64, 87.53, 94.6, 99.14, 104.6, 110.72, 119.21, 132.72] | P -Hyytymistekijä V | Plasma |  |
| 2531 | p-fx | % | 49% | name+unit+values | 916 | 0.11 | [46.06, 65.75, 76.36, 83.72, 90.83, 97.78, 104.84, 112.37, 122.61] | P -Hyytymistekijä X | Plasma |  |
| 2532 | p-fx |  | 51% | name+values | 949 | 87.46 | [66, 76.45, 83.38, 90.43, 96, 100.47, 108.88, 114, 128] | P -Hyytymistekijä X | Plasma |  |
| 2533 | p-gt | mg/ml | 0% | name+unit | 8 | 0 |  | P -Glutamyylitransferaasi | Plasma |  |
| 2534 | p-gt | u/l | 98% | name+unit+values | 820178 | 0.02 | [14.56, 18.66, 23.05, 28.6, 36.08, 47.26, 65.76, 101.29, 195.48] | P -Glutamyylitransferaasi | Plasma |  |
| 2535 | p-gt |  | 2% | name+values | 15977 | 100 | [15.82, 20.13, 24.14, 29.03, 35.14, 45.13, 63.31, 89.78, 161.64] | P -Glutamyylitransferaasi | Plasma |  |
| 2536 | p-hstni | ng/l | 100% | name+unit+values | 3261 | 0 | [1, 2, 3, 4.12, 6.04, 9.1, 14.48, 27.09, 65.46] |  | Plasma |  |
| 2537 | p-k+na |  | 100% | name | 69230 | 100 |  |  | Plasma |  |
| 2538 | p-k,na |  | 100% | name | 2518 | 100 |  |  | Plasma |  |
| 2539 | p-k-na | mmol/l | 76% | name+unit | 594 | 100 |  |  | Plasma | Native preparation |
| 2540 | p-k-na |  | 24% | name | 186 | 100 |  |  | Plasma | Native preparation |
| 2541 | p-k-pa | mmol/l | 100% | name+unit+values | 197 | 0 | [3.53, 3.78, 3.9, 4, 4.04, 4.13, 4.3, 4.38, 4.56] |  | Plasma | Long-term / prolonged |
| 2542 | p-k/na |  | 100% | name | 321 | 100 |  |  | Plasma |  |
| 2543 | p-ked. | mmol/l | 100% | name+unit | 344 | 0 |  |  | Plasma |  |
| 2544 | p-kjd. | mmol/l | 100% | name+unit | 160 | 0 |  |  | Plasma |  |
| 2545 | p-la1 | s | 95% | name+unit+values | 1064 | 0 | [30, 31.95, 33.1, 34.81, 35.99, 37.75, 39.96, 44.96, 54.77] |  | Plasma |  |
| 2546 | p-la1 |  | 5% | name | 52 | 50 |  |  | Plasma |  |
| 2547 | p-la2 | s | 26% | name+unit+values | 498 | 0 | [32, 33.41, 35.41, 36.98, 38.82, 40.9, 43.06, 47.24, 53.65] |  | Plasma |  |
| 2548 | p-la2 |  | 74% | name | 1411 | 99.43 |  |  | Plasma |  |
| 2549 | p-mypa | mg/l | 87% | name+unit+values | 1692 | 0.06 | [0.64, 0.99, 1.33, 1.7, 2.12, 2.67, 3.43, 4.39, 6.28] | P -Mykofenolihappo | Plasma |  |
| 2550 | p-mypa |  | 13% | name | 245 | 76.33 |  | P -Mykofenolihappo | Plasma |  |
| 2551 | p-na | mmol/ | 0% | name+unit | 14 | 0 |  | P -Natrium | Plasma | Native preparation |
| 2552 | p-na | mmol/l | 99% | name+unit+values | 7320578 | 0.03 | [133.91, 136.27, 137.98, 138.99, 139.95, 140, 141, 142, 143] | P -Natrium | Plasma | Native preparation |
| 2553 | p-na |  | 1% | name+values | 81059 | 100 | [134.02, 137.07, 138.67, 139, 140, 141, 142, 142.8, 143] | P -Natrium | Plasma | Native preparation |
| 2554 | p-na. | mmol/l | 100% | name+unit+values | 1467 | 0 | [134.64, 136.99, 138.3, 139.9, 140.54, 141, 142, 142.75, 144] |  | Plasma |  |
| 2555 | p-na: | mmol/l | 100% | name+unit+values | 621 | 0 | [131.65, 133.8, 135, 136.23, 137.85, 138.61, 139.67, 140.88, 142] |  | Plasma |  |
| 2556 | p-naed. | mmol/l | 100% | name+unit | 306 | 0 |  |  | Plasma |  |
| 2557 | p-najd. | mmol/l | 100% | name+unit | 154 | 0 |  |  | Plasma |  |
| 2558 | p-nak |  | 100% | name | 259040 | 100 |  |  | Plasma |  |
| 2559 | p-nap | mmol/l | 100% | name+unit+values | 342 | 0 | [132.69, 135.3, 137.47, 139, 140, 140.64, 142, 143, 145] |  | Plasma |  |
| 2560 | p-supar | ug/l | 96% | name+unit+values | 351 | 0 | [2.87, 3.25, 3.63, 3.92, 4.33, 4.73, 5.27, 6.37, 8.21] |  | Plasma |  |
| 2561 | p-supar |  | 4% | name | 16 | 100 |  |  | Plasma |  |
| 2562 | p-t3-v | pmol/l | 99% | name+unit+values | 82081 | 0.04 | [3.46, 3.84, 4.11, 4.35, 4.57, 4.81, 5.08, 5.46, 6.26] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated |
| 2563 | p-t3-v |  | 1% | name+values | 921 | 100 | [3.47, 3.87, 4.08, 4.31, 4.53, 4.77, 5.02, 5.39, 6.24] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated |
| 2564 | p-t4-v | pmol/l | 98% | name+unit+values | 1108128 | 0.01 | [11.98, 13.02, 13.95, 14.63, 15.23, 16.03, 16.92, 17.94, 19.56] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated |
| 2565 | p-t4-v |  | 2% | name+values | 19446 | 100 | [12, 13.8, 14.44, 15.06, 16, 16.21, 16.99, 17.6, 19] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated |
| 2566 | p-t4v | pmol/l | 96% | name+unit+values | 110881 | 0 | [12.73, 13.79, 14.57, 15.27, 15.96, 16.68, 17.48, 18.48, 19.99] |  | Plasma |  |
| 2567 | p-t4v |  | 4% | name+values | 4743 | 100 | [12.19, 13.39, 14.21, 14.93, 15.61, 16.33, 17.17, 18.29, 20.03] |  | Plasma |  |
| 2568 | p-tfr | mg/l | 92% | name+unit+values | 188406 | 0.02 | [0.81, 1.28, 2.05, 2.5, 2.87, 3.3, 3.83, 4.64, 6.21] | P -Transferriinireseptori, liukoinen | Plasma |  |
| 2569 | p-tfr |  | 8% | name+values | 15951 | 100 | [2.12, 2.53, 2.87, 3.21, 3.63, 4.15, 4.81, 5.75, 7.59] | P -Transferriinireseptori, liukoinen | Plasma |  |
| 2570 | p-tni | ng/l | 70% | name+unit+values | 220095 | 0 | [4, 5.13, 7.13, 10.22, 15.11, 24.46, 46.82, 122.37, 829.48] | P -Troponiini I | Plasma |  |
| 2571 | p-tni | ug/l | 8% | name+unit+values | 25579 | 0 | [0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.08, 0.16, 0.78] | P -Troponiini I | Plasma |  |
| 2572 | p-tni |  | 22% | name+values | 70910 | 100 | [0.05, 0.22, 2.89, 4.65, 7.45, 12.28, 24.91, 48.92, 145.81] | P -Troponiini I | Plasma |  |
| 2573 | p-tni. | ng/l | 3% | name+unit | 6 | 0 |  |  | Plasma |  |
| 2574 | p-tni. | ug/l | 82% | name+unit+values | 155 | 0 | [0, 0, 0, 0, 0, 0, 0.01, 0.02, 0.06] |  | Plasma |  |
| 2575 | p-tni. |  | 15% | name | 28 | 100 |  |  | Plasma |  |
| 2576 | p-tnih | ng/l | 82% | name+unit+values | 1974 | 0 | [4, 5.78, 7.89, 10.8, 16.52, 27.69, 54.92, 168.16, 1593.63] |  | Plasma |  |
| 2577 | p-tnih |  | 18% | name | 440 | 100 |  |  | Plasma |  |
| 2578 | p-tnl | ng/l | 37% | name+unit+values | 124 | 0 | [3, 4, 5.16, 7, 10, 12.72, 29.97, 89.8, 240.6] |  | Plasma |  |
| 2579 | p-tnl | ug/l | 53% | name+unit+values | 179 | 0 | [0, 0, 0, 0, 0, 0.01, 0.01, 0.02, 0.05] |  | Plasma |  |
| 2580 | p-tnl |  | 11% | name | 36 | 100 |  |  | Plasma |  |
| 2581 | p-tnt | ng/l | 84% | name+unit+values | 437584 | 0.96 | [6.97, 9.13, 11.78, 15.03, 19.12, 24.8, 33.92, 51.22, 106.22] | P -Troponiini T | Plasma |  |
| 2582 | p-tnt | ug/l | 0% | name+unit | 76 | 0 |  | P -Troponiini T | Plasma |  |
| 2583 | p-tnt |  | 15% | name+values | 80220 | 100 | [6.97, 8.93, 11.46, 14.61, 18.09, 22.79, 29.94, 42.37, 74.82] | P -Troponiini T | Plasma |  |
| 2584 | p-tt | % | 99% | name+unit+values | 472003 | 0.01 | [50.44, 65.04, 74.28, 81.62, 88.26, 94.73, 101.62, 109.77, 121.26] | P -Tromboplastiiniaika | Plasma |  |
| 2585 | p-tt | form | 0% | name+unit | 20 | 0 |  | P -Tromboplastiiniaika | Plasma |  |
| 2586 | p-tt |  | 1% | name+values | 4462 | 100 | [41.42, 56.72, 66.85, 77.09, 85.82, 93.79, 102.07, 112.01, 126.16] | P -Tromboplastiiniaika | Plasma |  |
| 2587 | p-tt- | % | 98% | name+unit+values | 1432 | 0 | [60.12, 72.07, 78.16, 83.25, 88.78, 95.39, 102.35, 111.94, 122.43] |  | Plasma |  |
| 2588 | p-tt- |  | 2% | name | 29 | 96.55 |  |  | Plasma |  |
| 2589 | p-tt. | % | 94% | name+unit+values | 5628 | 0 | [63.13, 78.7, 87.12, 93.57, 99.77, 105.67, 112.42, 119.67, 130.89] |  | Plasma |  |
| 2590 | p-tt. |  | 6% | name+values | 328 | 31.4 | [48, 79.63, 90.12, 98.65, 107.18, 114.33, 121.82, 130.4, 140] |  | Plasma |  |
| 2591 | p-ttr | % | 93% | name+unit+values | 1114 | 0 | [50.89, 61.27, 67.88, 73.89, 78.52, 83.07, 89.29, 95.08, 100] |  | Plasma |  |
| 2592 | p-ttr |  | 7% | name | 89 | 89.89 |  |  | Plasma |  |
| 2593 | pdgfr |  | 100% | name | 461 | 100 |  |  |  |  |
| 2594 | peak | l/min | 10% | name+unit | 12 | 0 |  |  |  |  |
| 2595 | peak |  | 90% | name | 104 | 100 |  |  |  |  |
| 2596 | pef-pa |  | 100% | name | 7844 | 99.92 |  | Uloshengityksen huippuvirtaus, sarjamittaus, pitkäaikaisseuranta |  | Long-term / prolonged |
| 2597 | pef-ras |  | 100% | name | 242 | 100 |  | Uloshengityksen huippuvirtaus, sarjamittaus, rasituskoe |  |  |
| 2598 | pf-ace | u/l | 66% | name+unit+values | 313 | 3.19 | [6.4, 10.22, 12.78, 15.45, 17.82, 19.96, 24.1, 28.83, 37.4] | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  |
| 2599 | pf-ace |  | 34% | name | 161 | 98.14 |  | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  |
| 2600 | pf-ada | u/l | 91% | name+unit+values | 3550 | 0.14 | [3.68, 5.14, 6.78, 8.01, 9.46, 11.17, 13.55, 17.33, 25.48] | Pf-Adenosiinideaminaasi | Pleural fluid |  |
| 2601 | pf-ada |  | 9% | name | 365 | 90.96 |  | Pf-Adenosiinideaminaasi | Pleural fluid |  |
| 2602 | pneag |  | 100% | name | 244 | 100 |  |  |  |  |
| 2603 | s-na | mmol/l | 99% | name+unit+values | 124118 | 0 | [137.36, 138.84, 139.01, 140, 140.14, 141, 141.38, 142, 143] | S -Natrium | Serum | Native preparation |
| 2604 | s-na | mol/l | 0% | name+unit | 5 | 0 |  | S -Natrium | Serum | Native preparation |
| 2605 | s-na |  | 1% | name+values | 931 | 67.35 | [137.2, 138, 139, 139, 140, 140, 141, 141, 142.37] | S -Natrium | Serum | Native preparation |
| 2606 | s-t3-v | pmol/l | 92% | name+unit+values | 18657 | 0 | [3.72, 4.06, 4.3, 4.5, 4.69, 4.9, 5.13, 5.43, 6.06] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated |
| 2607 | s-t3-v |  | 8% | name+values | 1623 | 51.2 | [3.55, 3.8, 4.02, 4.22, 4.41, 4.6, 4.85, 5.16, 5.82] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated |
| 2608 | s-t4-v | pmol/l | 96% | name+unit+values | 252259 | 0 | [11.09, 12, 12.88, 13.14, 13.97, 14.48, 15.15, 16.1, 17.48] | S -Tyroksiini, vapaa | Serum | Free or unconjugated |
| 2609 | s-t4-v |  | 4% | name+values | 9900 | 100 | [12.03, 12.98, 13.72, 14.35, 14.94, 15.68, 16.39, 17.25, 18.59] | S -Tyroksiini, vapaa | Serum | Free or unconjugated |
| 2610 | s-t4v | pmol/l | 100% | name+unit+values | 1086 | 0 | [12.85, 13, 14, 14.52, 15, 15.93, 16, 17, 18] |  | Serum |  |
| 2611 | s-tfr | mg | 0% | name+unit | 7 | 0 |  | S -Transferriinireseptori, liukoinen | Serum |  |
| 2612 | s-tfr | mg/l | 98% | name+unit+values | 77760 | 0 | [1, 1.22, 1.5, 1.89, 2.35, 2.8, 3.34, 4.1, 5.59] | S -Transferriinireseptori, liukoinen | Serum |  |
| 2613 | s-tfr |  | 2% | name+values | 1379 | 100 | [1.84, 2.22, 2.62, 3.08, 3.57, 4.23, 5.1, 6.26, 8.15] | S -Transferriinireseptori, liukoinen | Serum |  |
| 2614 | s-tnf | ng/l | 67% | name+unit+values | 100 | 0 | [4.65, 5.4, 6.33, 7.11, 7.81, 8.85, 10.5, 13.2, 23.25] | S -Tuumorinekroositekijä, alfa | Serum |  |
| 2615 | s-tnf |  | 33% | name | 50 | 74 |  | S -Tuumorinekroositekijä, alfa | Serum |  |
| 2616 | s-tni | ng/l | 26% | name+unit+values | 63 | 0 | [2.98, 3.29, 4.36, 4.96, 6.38, 8.72, 14.54, 33, 54.53] | S -Troponiini I | Serum |  |
| 2617 | s-tni | ug/l | 4% | name+unit | 11 | 0 |  | S -Troponiini I | Serum |  |
| 2618 | s-tni |  | 70% | name | 171 | 100 |  | S -Troponiini I | Serum |  |
| 2619 | s-tnt | ng/l | 2% | name+unit+values | 149 | 0 | [40, 42, 45.21, 51.23, 64.69, 87.1, 139.39, 201.81, 358.2] | S -Troponiini T | Serum |  |
| 2620 | s-tnt |  | 98% | name | 7446 | 99.38 |  | S -Troponiini T | Serum |  |
| 2621 | s-tob | mg/l | 59% | name+unit+values | 805 | 0.99 | [0.29, 0.5, 0.61, 0.8, 1.01, 1.26, 1.54, 1.91, 3.02] | S -Tobramysiini | Serum |  |
| 2622 | s-tob |  | 41% | name | 560 | 81.96 |  | S -Tobramysiini | Serum |  |
| 2623 | sp-pak |  | 100% | name | 196 | 100 |  |  | Sperm / semen |  |
| 2624 | sp-pakd |  | 100% | name | 138 | 100 |  |  | Sperm / semen |  |
| 2625 | u-na | mmol/l | 77% | name+unit+values | 8969 | 1.33 | [24.74, 32.42, 40.4, 48.4, 57.53, 68.16, 81.75, 99.14, 129.68] | U -Natrium | Urine | Native preparation |
| 2626 | u-na |  | 23% | name+values | 2662 | 76.37 | [27.27, 35.54, 43.11, 51.43, 60.05, 68.34, 78.15, 92.47, 111.65] | U -Natrium | Urine | Native preparation |
| 2627 | v-na |  | 100% | name+values | 265 | 0.75 | [130.22, 134.26, 135.98, 137.59, 138.5, 139.03, 140, 141, 142] |  |  | Native preparation |
| 2628 | vp-na | mmol/l | 98% | name+unit+values | 10896 | 0 | [132.84, 135.34, 136.96, 137.97, 138.99, 139.84, 140.33, 141.08, 142.49] |  |  | Native preparation |
| 2629 | vp-na |  | 2% | name | 174 | 98.28 |  |  |  | Native preparation |

