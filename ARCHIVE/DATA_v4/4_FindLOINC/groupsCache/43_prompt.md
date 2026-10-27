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
Here is group 43 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 2581 | -c3d |  | 100% | name | 313 | 100 |  |  |  |  |
| 2582 | -cdt | mg/l | 100% | name+unit+values | 465 | 0 | [30.93, 34.48, 37.2, 39.51, 41.65, 44.52, 47.1, 52.61, 66.32] |  |  |  |
| 2583 | -cea | ug/l | 62% | name+unit+values | 86 | 0 | [3.1, 10.24, 23.5, 45.82, 86.95, 226.27, 430.37, 1163.15, 2504] | -Karsinoembryonaalinen antigeeni |  |  |
| 2584 | -cea |  | 38% | name | 53 | 100 |  | -Karsinoembryonaalinen antigeeni |  |  |
| 2585 | ab-cl | mmol/l | 100% | name+unit+values | 1123 | 0 | [96.62, 99.74, 102.05, 103.97, 105.1, 106.54, 107.91, 109, 111.34] |  | Arterial blood | Clearance |
| 2586 | ap-cl | mmol/l | 76% | name+unit+values | 271 | 0 | [96.53, 101.68, 104.11, 105.92, 106.9, 108.61, 110, 111, 114.15] |  |  | Clearance |
| 2587 | ap-cl |  | 24% | name | 84 | 100 |  |  |  | Clearance |
| 2588 | b-cl | mmol/l | 86% | name+unit+values | 51262 | 0 | [99.4, 101.98, 103.81, 104.99, 106, 107.02, 108.25, 109.8, 112.07] |  | Blood | Clearance |
| 2589 | b-cl |  | 14% | name | 8059 | 100 |  |  | Blood | Clearance |
| 2590 | b-co | ug/l | 89% | name+unit+values | 4244 | 0 | [0.61, 0.84, 1.09, 1.4, 1.88, 2.76, 4.17, 6.44, 10.87] | B -Koboltti | Blood |  |
| 2591 | b-co |  | 11% | name+values | 508 | 100 | [0.9, 1, 1, 1.08, 1.7, 2.07, 3.1, 4.15, 6] | B -Koboltti | Blood |  |
| 2592 | b-cr | ug/l | 79% | name+unit+values | 3775 | 0 | [0.74, 1.01, 1.2, 1.43, 1.74, 2.14, 2.74, 3.65, 5.6] | B -Kromi | Blood |  |
| 2593 | b-cr |  | 21% | name+values | 980 | 100 | [1, 1, 1, 1.2, 1.6, 2, 2.16, 2.94, 3.6] | B -Kromi | Blood |  |
| 2594 | b-cya | ug/l | 95% | name+unit+values | 25550 | 0 | [60.87, 72.59, 81.84, 90.47, 100.07, 111.93, 131.29, 164.82, 225.76] | B -Syklosporiini A | Blood |  |
| 2595 | b-cya |  | 5% | name+values | 1477 | 100 | [61.13, 73.24, 78.64, 86.8, 95.21, 104.77, 117.98, 151.78, 199.49] | B -Syklosporiini A | Blood |  |
| 2596 | du-ca | *sai | 0% | name+unit | 6 | 0 |  | dU-Kalsium | 24-hour urine |  |
| 2597 | du-ca | mmol/24h | 89% | name+unit+values | 13838 | 0.02 | [1.76, 2.76, 3.64, 4.51, 5.38, 6.33, 7.4, 8.73, 10.72] | dU-Kalsium | 24-hour urine |  |
| 2598 | du-ca |  | 11% | name | 1693 | 100 |  | dU-Kalsium | 24-hour urine |  |
| 2599 | du-cl | mmol | 81% | name+unit+values | 411 | 0 | [81.75, 104.44, 123.91, 140.06, 160.24, 175.41, 203.5, 249.04, 310.48] | dU-Kloridi | 24-hour urine | Clearance |
| 2600 | du-cl |  | 19% | name | 94 | 100 |  | dU-Kloridi | 24-hour urine | Clearance |
| 2601 | du-cu | umol | 25% | name+unit+values | 94 | 1.06 | [0.16, 0.21, 0.28, 0.39, 0.78, 1.92, 4.29, 6.52, 10.65] | dU-Kupari | 24-hour urine |  |
| 2602 | du-cu | umol/24h | 34% | name+unit+values | 127 | 0 | [0.13, 0.17, 0.18, 0.22, 0.28, 0.36, 0.73, 3.44, 9.31] | dU-Kupari | 24-hour urine |  |
| 2603 | du-cu |  | 41% | name | 154 | 100 |  | dU-Kupari | 24-hour urine |  |
| 2604 | fp-ca | mmol/l | 99% | name+unit+values | 61661 | 0 | [2.2, 2.26, 2.3, 2.33, 2.36, 2.39, 2.42, 2.46, 2.51] | fP-Kalsium | Fasting plasma |  |
| 2605 | fp-ca |  | 1% | name | 407 | 100 |  | fP-Kalsium | Fasting plasma |  |
| 2606 | fp-cga | nmol/l | 95% | name+unit+values | 10003 | 0.03 | [0.72, 1.15, 1.84, 2.33, 2.83, 3.49, 4.63, 7.79, 19.95] | fP-Kromograniini A | Fasting plasma |  |
| 2607 | fp-cga |  | 5% | name+values | 571 | 100 | [1.96, 2.33, 2.55, 2.88, 3.13, 3.69, 4.46, 5.71, 8.06] | fP-Kromograniini A | Fasting plasma |  |
| 2608 | fs-ca | mmol/l | 99% | name+unit+values | 1580 | 0 | [2.25, 2.3, 2.33, 2.36, 2.39, 2.41, 2.44, 2.47, 2.52] |  | Fasting serum |  |
| 2609 | fs-ca |  | 1% | name | 9 | 100 |  |  | Fasting serum |  |
| 2610 | fs-cga | nmol/l | 95% | name+unit+values | 6208 | 0 | [0.71, 0.95, 1.19, 1.46, 1.91, 2.49, 3.38, 5.29, 12.84] | fS-Kromograniini A | Fasting serum |  |
| 2611 | fs-cga | ug/l | 0% | name+unit | 11 | 0 |  | fS-Kromograniini A | Fasting serum |  |
| 2612 | fs-cga |  | 5% | name+values | 331 | 100 | [1, 1, 1, 1.17, 1.99, 2.13, 3.28, 4.74, 10.29] | fS-Kromograniini A | Fasting serum |  |
| 2613 | mb-cl | mmol/l | 96% | name+unit | 2504 | 0 |  |  |  | Clearance |
| 2614 | mb-cl |  | 4% | name | 105 | 100 |  |  |  | Clearance |
| 2615 | p-c3 | g/l | 95% | name+unit+values | 14303 | 0 | [0.75, 0.87, 0.95, 1.02, 1.1, 1.18, 1.26, 1.35, 1.49] | P -Komplementti C3 | Plasma |  |
| 2616 | p-c3 |  | 5% | name+values | 748 | 100 | [0.79, 0.89, 0.96, 1.02, 1.1, 1.15, 1.23, 1.33, 1.48] | P -Komplementti C3 | Plasma |  |
| 2617 | p-c4 | g/l | 94% | name+unit+values | 13926 | 0 | [0.1, 0.13, 0.16, 0.18, 0.2, 0.22, 0.24, 0.27, 0.31] | P -Komplementti C4 | Plasma |  |
| 2618 | p-c4 |  | 6% | name+values | 953 | 100 | [0.1, 0.14, 0.17, 0.19, 0.2, 0.23, 0.25, 0.28, 0.32] | P -Komplementti C4 | Plasma |  |
| 2619 | p-ca | mmol/l | 99% | name+unit+values | 424377 | 0 | [2.21, 2.27, 2.31, 2.34, 2.37, 2.4, 2.43, 2.47, 2.53] | P -Kalsium | Plasma |  |
| 2620 | p-ca |  | 1% | name | 5509 | 100 |  | P -Kalsium | Plasma |  |
| 2621 | p-cea | ug/l | 84% | name+unit+values | 53825 | 0 | [1.59, 2.01, 2.37, 2.8, 3.39, 4.25, 5.72, 9.36, 30.62] | P -Karsinoembryonaalinen antigeeni | Plasma |  |
| 2622 | p-cea |  | 16% | name | 10275 | 100 |  | P -Karsinoembryonaalinen antigeeni | Plasma |  |
| 2623 | p-ck | u/l | 98% | name+unit+values | 278981 | 0 | [42.95, 58.04, 71.6, 86.71, 104.44, 129.55, 169.7, 253.54, 545.62] | P -Kreatiinikinaasi | Plasma |  |
| 2624 | p-ck |  | 2% | name | 4344 | 100 |  | P -Kreatiinikinaasi | Plasma |  |
| 2625 | p-cl | mmol/l | 100% | name+unit+values | 441381 | 0.01 | [97.91, 100.97, 102.85, 104, 105.19, 106.56, 107.81, 109.04, 111.15] | P -Kloridi | Plasma | Clearance |
| 2626 | p-cl |  | 0% | name+values | 2019 | 100 | [96.43, 100.31, 102, 103.61, 104.81, 106, 106.99, 108, 109.87] | P -Kloridi | Plasma | Clearance |
| 2627 | p-cu | umol/l | 82% | name+unit+values | 362 | 0 | [11.87, 13.34, 14.27, 15.36, 16.22, 16.79, 17.66, 19.1, 21.13] | P -Kupari | Plasma |  |
| 2628 | p-cu |  | 18% | name | 81 | 100 |  | P -Kupari | Plasma |  |
| 2629 | pf-c3 | g/l | 81% | name+unit+values | 143 | 0 | [0.16, 0.25, 0.28, 0.33, 0.37, 0.43, 0.52, 0.59, 0.67] | Pf-Komplementti C3 | Pleural fluid |  |
| 2630 | pf-c3 |  | 19% | name | 33 | 100 |  | Pf-Komplementti C3 | Pleural fluid |  |
| 2631 | pf-c4 | g/l | 70% | name+unit+values | 129 | 0 | [0.02, 0.03, 0.04, 0.05, 0.07, 0.08, 0.09, 0.1, 0.12] | Pf-Komplementti C4 | Pleural fluid |  |
| 2632 | pf-c4 |  | 30% | name | 55 | 100 |  | Pf-Komplementti C4 | Pleural fluid |  |
| 2633 | pf-cea | ug/l | 53% | name+unit+values | 765 | 0 | [0.7, 1.09, 1.25, 1.54, 2, 2.48, 4.54, 27.69, 279.67] | Pf-Karsinoembryonaalinen antigeeni | Pleural fluid |  |
| 2634 | pf-cea |  | 47% | name | 670 | 100 |  | Pf-Karsinoembryonaalinen antigeeni | Pleural fluid |  |
| 2635 | s-c3 | g/l | 96% | name+unit+values | 10697 | 0 | [0.77, 0.9, 0.98, 1.06, 1.13, 1.21, 1.3, 1.41, 1.56] | S -Komplementti C3 | Serum |  |
| 2636 | s-c3 |  | 4% | name+values | 394 | 100 | [0.84, 0.96, 1.01, 1.06, 1.15, 1.24, 1.31, 1.42, 1.59] | S -Komplementti C3 | Serum |  |
| 2637 | s-c4 | g/l | 95% | name+unit+values | 10528 | 0 | [0.11, 0.14, 0.17, 0.2, 0.22, 0.24, 0.27, 0.3, 0.34] | S -Komplementti C4 | Serum |  |
| 2638 | s-c4 |  | 5% | name+values | 506 | 100 | [0.11, 0.15, 0.18, 0.2, 0.22, 0.24, 0.26, 0.27, 0.31] | S -Komplementti C4 | Serum |  |
| 2639 | s-ca | g/l | 0% | name+unit | 8 | 0 |  | S -Kalsium | Serum |  |
| 2640 | s-ca | mmol/l | 99% | name+unit+values | 20957 | 0 | [2.23, 2.27, 2.3, 2.33, 2.35, 2.38, 2.4, 2.43, 2.48] | S -Kalsium | Serum |  |
| 2641 | s-ca |  | 1% | name+values | 114 | 100 | [2.11, 2.22, 2.24, 2.29, 2.33, 2.36, 2.4, 2.42, 2.5] | S -Kalsium | Serum |  |
| 2642 | s-cdt | % | 97% | name+unit+values | 102065 | 0 | [0.79, 1.14, 1.3, 1.41, 1.5, 1.6, 1.7, 1.9, 2.36] | S -Desialotransferriini | Serum |  |
| 2643 | s-cdt | u/l | 0% | name+unit | 35 | 0 |  | S -Desialotransferriini | Serum |  |
| 2644 | s-cdt |  | 3% | name | 2936 | 100 |  | S -Desialotransferriini | Serum |  |
| 2645 | s-cea | ug/l | 79% | name+unit+values | 90194 | 0 | [1.12, 1.4, 1.69, 2.03, 2.45, 3.05, 4.05, 6.32, 17.53] | S -Karsinoembryonaalinen antigeeni | Serum |  |
| 2646 | s-cea |  | 21% | name | 23960 | 100 |  | S -Karsinoembryonaalinen antigeeni | Serum |  |
| 2647 | s-cic | ugeq/ml | 95% | name+unit+values | 728 | 0 | [2, 2.11, 3, 4, 5.61, 6.93, 9.29, 12.82, 20.44] | S -Immunokompleksit, kiertävät | Serum |  |
| 2648 | s-cic |  | 5% | name | 36 | 100 |  | S -Immunokompleksit, kiertävät | Serum |  |
| 2649 | s-ck | u/l | 99% | name+unit+values | 11560 | 0 | [55.21, 68.52, 80.72, 93.9, 109.16, 127.95, 153.42, 197.38, 289.68] | S -Kreatiinikinaasi | Serum |  |
| 2650 | s-ck |  | 1% | name | 102 | 100 |  | S -Kreatiinikinaasi | Serum |  |
| 2651 | s-cl | mmol/l | 100% | name+unit+values | 194 | 0 | [97.57, 100, 101, 102, 103, 104, 104.97, 106, 107] | S -Kloridi | Serum | Clearance |
| 2652 | s-cu | umol/l | 93% | name+unit+values | 1531 | 0 | [11.56, 13.12, 14.07, 15.01, 15.92, 16.9, 18.04, 19.54, 22.14] | S -Kupari | Serum |  |
| 2653 | s-cu |  | 7% | name+values | 119 | 100 | [12, 13.59, 14.88, 16, 17.1, 18.8, 20.92, 22.95, 25.9] | S -Kupari | Serum |  |
| 2654 | s-ictp | ug/l | 90% | name+unit+values | 801 | 0 | [2.67, 3.25, 3.82, 4.4, 4.92, 5.81, 6.67, 8.24, 11.6] | S -Kollageeni I:n karboksiterminaalinen telopeptidi | Serum |  |
| 2655 | s-ictp | âug/l | 1% | name+unit | 11 | 0 |  | S -Kollageeni I:n karboksiterminaalinen telopeptidi | Serum |  |
| 2656 | s-ictp |  | 8% | name | 75 | 100 |  | S -Kollageeni I:n karboksiterminaalinen telopeptidi | Serum |  |
| 2657 | s-pct | ug/l | 76% | name+unit+values | 4418 | 0 | [0.06, 0.09, 0.12, 0.17, 0.23, 0.34, 0.54, 1, 3.09] | S -Prokalsitoniini | Serum |  |
| 2658 | s-pct |  | 24% | name+values | 1380 | 100 | [1.39, 2.13, 8.8, 12.06, 16.31, 22.57, 28.84, 42.06, 68.76] | S -Prokalsitoniini | Serum |  |
| 2659 | ts-cc |  | 100% | name | 582 | 100 |  |  | Tissue |  |
| 2660 | u-ca | mmol/l | 92% | name+unit+values | 2045 | 0 | [0.72, 1.18, 1.57, 2, 2.5, 3.06, 3.75, 4.62, 6.4] | U -Kalsium | Urine |  |
| 2661 | u-ca |  | 8% | name+values | 184 | 100 | [1.03, 1.34, 1.77, 1.9, 2.01, 2.25, 2.9, 4.1, 4.72] | U -Kalsium | Urine |  |
| 2662 | u-co | form | 5% | name+unit | 15 | 0 |  | U -Koboltti | Urine |  |
| 2663 | u-co | nmol/l | 69% | name+unit+values | 197 | 2.54 | [3.97, 5.82, 9.12, 16.26, 25.4, 41.63, 60.62, 94.57, 169.48] | U -Koboltti | Urine |  |
| 2664 | u-co | ug/l | 5% | name+unit | 13 | 7.69 |  | U -Koboltti | Urine |  |
| 2665 | u-co |  | 22% | name | 62 | 100 |  | U -Koboltti | Urine |  |
| 2666 | u-cot | ng/ml | 4% | name+unit | 23 | 0 |  | U -Kotiniini | Urine |  |
| 2667 | u-cot | ug/l | 18% | name+unit+values | 95 | 0 | [50, 228.5, 353.33, 580, 746.38, 949.5, 1247.5, 1604.25, 2426] | U -Kotiniini | Urine |  |
| 2668 | u-cot |  | 78% | name | 422 | 100 |  | U -Kotiniini | Urine |  |
| 2669 | u-cr | form | 2% | name+unit | 8 | 0 |  | U -Kromi | Urine |  |
| 2670 | u-cr | ug/l | 5% | name+unit | 25 | 0 |  | U -Kromi | Urine |  |
| 2671 | u-cr | umol/l | 42% | name+unit+values | 211 | 1.42 | [0.01, 0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.06, 0.09] | U -Kromi | Urine |  |
| 2672 | u-cr |  | 51% | name | 259 | 100 |  | U -Kromi | Urine |  |
| 2673 | v-hct |  | 100% | name+values | 258 | 100 | [0.33, 0.36, 0.38, 0.4, 0.41, 0.42, 0.45, 0.46, 0.49] |  |  |  |
| 2674 | v-ica |  | 100% | name+values | 294 | 100 | [1.08, 1.12, 1.15, 1.17, 1.19, 1.2, 1.22, 1.24, 1.27] |  |  |  |
| 2675 | vp-cl | mmol/l | 98% | name+unit+values | 10892 | 0 | [99.57, 102.23, 103.93, 105.1, 106.07, 107.13, 108.26, 109.58, 111.2] |  |  | Clearance |
| 2676 | vp-cl |  | 2% | name | 175 | 100 |  |  |  | Clearance |

