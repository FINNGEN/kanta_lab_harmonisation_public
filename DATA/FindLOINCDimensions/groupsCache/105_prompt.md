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
Here is group 105 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 8557 | b-pvk | % | 0% | name+unit+values | 1036 | 0 | [12.98, 13, 13, 13, 13.02, 14, 14, 14, 14.9] | B -Perusverenkuva | Blood |  |
| 8558 | b-pvk | e12/l | 0% | name+unit | 180 | 0 |  | B -Perusverenkuva | Blood |  |
| 8559 | b-pvk | e9/l | 0% | name+unit | 180 | 0 |  | B -Perusverenkuva | Blood |  |
| 8560 | b-pvk | fl | 0% | name+unit | 191 | 0 |  | B -Perusverenkuva | Blood |  |
| 8561 | b-pvk | form | 0% | name+unit | 6 | 0 |  | B -Perusverenkuva | Blood |  |
| 8562 | b-pvk | g/l | 0% | name+unit+values | 371 | 0 | [130.49, 135.97, 140.17, 143.56, 146.5, 149.94, 154.99, 161.16, 169.87] | B -Perusverenkuva | Blood |  |
| 8563 | b-pvk | paketti | 0% | name+unit+values | 261 | 0 | [31329.79, 60496.46, 87166.96, 116360.34, 146168.26, 177141.71, 213025.07, 240401.38, 278743.21] | B -Perusverenkuva | Blood |  |
| 8564 | b-pvk | pg | 0% | name+unit | 191 | 0 |  | B -Perusverenkuva | Blood |  |
| 8565 | b-pvk |  | 100% | name | 1084645 | 100 |  | B -Perusverenkuva | Blood |  |
| 8566 | b-pvk(pi) |  | 100% | name | 994 | 100 |  |  | Blood |  |
| 8567 | b-pvk+eo |  | 100% | name | 1355 | 100 |  |  | Blood |  |
| 8568 | b-pvk+kd |  | 100% | name | 335 | 100 |  |  | Blood |  |
| 8569 | b-pvk+ne |  | 100% | name | 301325 | 100 |  |  | Blood |  |
| 8570 | b-pvk+ner |  | 100% | name | 551 | 100 |  |  | Blood |  |
| 8571 | b-pvk+t | % | 0% | name+unit+values | 16337 | 0 | [8.54, 11.43, 12.73, 13.01, 14.63, 21.66, 27.29, 34.08, 48.89] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8572 | b-pvk+t | %g | 0% | name+unit | 229 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8573 | b-pvk+t | %l | 0% | name+unit+values | 229 | 0 | [15.3, 18.86, 20.93, 24.39, 26.09, 27.9, 29.48, 31.36, 37.88] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8574 | b-pvk+t | %m | 0% | name+unit+values | 229 | 0 | [9, 10, 10.3, 10.73, 11, 11.47, 11.97, 12.55, 13.3] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8575 | b-pvk+t | e12/l | 0% | name+unit | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8576 | b-pvk+t | e9/l | 0% | name+unit+values | 4647 | 0 | [0, 0, 0, 0, 0, 0, 2.04, 5.2, 8.91] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8577 | b-pvk+t | fl | 0% | name+unit | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8578 | b-pvk+t | form | 0% | name+unit+values | 361 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.89, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8579 | b-pvk+t | g/l | 0% | name+unit+values | 2746 | 0 | [312.86, 315.11, 317.96, 319.16, 327.56, 334.19, 340.53, 346.44, 355.56] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8580 | b-pvk+t | l/l | 0% | name+unit | 6 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8581 | b-pvk+t | paketti | 0% | name+unit+values | 269 | 0 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8582 | b-pvk+t | pg | 0% | name+unit+values | 2769 | 0 | [29, 29.58, 30, 30.35, 31, 31.07, 32, 32.99, 34.11] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8583 | b-pvk+t |  | 99% | name+values | 4547373 | 100 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |
| 8584 | b-pvk+t+e |  | 100% | name | 1491 | 100 |  |  | Blood |  |
| 8585 | b-pvk+t+n |  | 100% | name | 20012 | 100 |  |  | Blood |  |
| 8586 | b-pvk+t+ne |  | 100% | name | 1150 | 100 |  |  | Blood |  |
| 8587 | b-pvk+t+r |  | 100% | name | 713 | 100 |  |  | Blood |  |
| 8588 | b-pvk+tk |  | 100% | name | 466 | 100 |  |  | Blood |  |
| 8589 | b-pvk+tkd | % | 0% | name+unit+values | 567 | 0 | [10.52, 11.98, 22.28, 26.53, 30.21, 32.92, 36.29, 39.43, 43.1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |
| 8590 | b-pvk+tkd | e9/l | 0% | name+unit | 5 | 0 |  | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |
| 8591 | b-pvk+tkd |  | 100% | name+values | 347141 | 99.77 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |
| 8592 | b-pvk+tkd,baso | % | 50% | name+unit+values | 4387 | 0 | [0.13, 0.2, 0.3, 0.34, 0.4, 0.5, 0.59, 0.7, 0.91] |  | Blood |  |
| 8593 | b-pvk+tkd,baso | e9/l | 50% | name+unit+values | 4345 | 0 | [0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.05, 0.06] |  | Blood |  |
| 8594 | b-pvk+tkd,baso |  | 0% | name | 28 | 96.43 |  |  | Blood |  |
| 8595 | b-pvk+tkd,eo | % | 50% | name+unit+values | 4389 | 0 | [0.28, 0.95, 1.44, 1.88, 2.38, 2.9, 3.5, 4.34, 5.77] |  | Blood |  |
| 8596 | b-pvk+tkd,eo | e9/l | 50% | name+unit+values | 4355 | 0 | [0.02, 0.07, 0.1, 0.13, 0.16, 0.2, 0.24, 0.3, 0.39] |  | Blood |  |
| 8597 | b-pvk+tkd,eo |  | 0% | name | 35 | 77.14 |  |  | Blood |  |
| 8598 | b-pvk+tkd,eryt | e12/l | 99% | name+unit+values | 4432 | 0 | [3.69, 4.01, 4.19, 4.32, 4.47, 4.6, 4.71, 4.86, 5.08] |  | Blood |  |
| 8599 | b-pvk+tkd,eryt |  | 1% | name | 28 | 82.14 |  |  | Blood |  |
| 8600 | b-pvk+tkd,hb | g/l | 99% | name+unit+values | 4431 | 0 | [109.63, 119.87, 125.6, 130.31, 134.35, 137.72, 141.31, 145.38, 151.58] |  | Blood |  |
| 8601 | b-pvk+tkd,hb |  | 1% | name | 28 | 82.14 |  |  | Blood |  |
| 8602 | b-pvk+tkd,hkr | osuus | 99% | name+unit+values | 4430 | 0 | [0.34, 0.36, 0.38, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45] |  | Blood |  |
| 8603 | b-pvk+tkd,hkr |  | 1% | name | 28 | 82.14 |  |  | Blood |  |
| 8604 | b-pvk+tkd,ig | % | 50% | name+unit+values | 4380 | 0 | [0, 0.1, 0.18, 0.2, 0.2, 0.24, 0.3, 0.4, 0.66] |  | Blood |  |
| 8605 | b-pvk+tkd,ig | e9/l | 50% | name+unit+values | 4329 | 0 | [0, 0.01, 0.01, 0.01, 0.01, 0.02, 0.02, 0.03, 0.06] |  | Blood |  |
| 8606 | b-pvk+tkd,ig |  | 0% | name | 27 | 100 |  |  | Blood |  |
| 8607 | b-pvk+tkd,leuk | e9/l | 99% | name+unit+values | 4441 | 0 | [4.64, 5.29, 5.87, 6.47, 7.06, 7.73, 8.41, 9.34, 10.91] |  | Blood |  |
| 8608 | b-pvk+tkd,leuk |  | 1% | name+values | 23 | 100 | [4.39, 5.06, 5.62, 6.11, 6.7, 7.36, 7.96, 8.73, 10.19] |  | Blood |  |
| 8609 | b-pvk+tkd,lymph | % | 50% | name+unit+values | 4402 | 0 | [14.51, 18.87, 22.17, 24.95, 27.85, 30.77, 33.85, 37.68, 42.79] |  | Blood |  |
| 8610 | b-pvk+tkd,lymph | e9/l | 50% | name+unit+values | 4366 | 0 | [1.07, 1.3, 1.5, 1.68, 1.87, 2.05, 2.28, 2.59, 3.03] |  | Blood |  |
| 8611 | b-pvk+tkd,lymph |  | 0% | name | 39 | 71.79 |  |  | Blood |  |
| 8612 | b-pvk+tkd,mch | pg | 99% | name+unit+values | 4427 | 0 | [27.35, 28.81, 29.01, 30, 30, 30.98, 31, 31.99, 32.41] |  | Blood |  |
| 8613 | b-pvk+tkd,mch |  | 1% | name | 26 | 88.46 |  |  | Blood |  |
| 8614 | b-pvk+tkd,mchc | g/l | 99% | name+unit+values | 4422 | 0 | [316.84, 322.97, 327.09, 330.49, 333.34, 336.5, 339.82, 343.59, 348.74] |  | Blood |  |
| 8615 | b-pvk+tkd,mchc |  | 1% | name | 27 | 85.19 |  |  | Blood |  |
| 8616 | b-pvk+tkd,mcv | fl | 99% | name+unit+values | 4432 | 0 | [83.81, 86.19, 87.9, 89.02, 90.1, 91.52, 92.95, 94.05, 96.04] |  | Blood |  |
| 8617 | b-pvk+tkd,mcv |  | 1% | name | 25 | 92 |  |  | Blood |  |
| 8618 | b-pvk+tkd,mono | % | 50% | name+unit+values | 4397 | 0 | [6.39, 7.45, 8.16, 8.78, 9.38, 10.01, 10.67, 11.64, 13.06] |  | Blood |  |
| 8619 | b-pvk+tkd,mono | e9/l | 50% | name+unit+values | 4364 | 0 | [0.41, 0.48, 0.54, 0.59, 0.65, 0.7, 0.78, 0.88, 1.03] |  | Blood |  |
| 8620 | b-pvk+tkd,mono |  | 0% | name | 32 | 84.38 |  |  | Blood |  |
| 8621 | b-pvk+tkd,neut | % | 50% | name+unit+values | 4407 | 0 | [43.3, 48.04, 51.9, 55.37, 58.56, 61.78, 65.36, 69.3, 74.25] |  | Blood |  |
| 8622 | b-pvk+tkd,neut | e9/l | 50% | name+unit+values | 4373 | 0 | [2.18, 2.67, 3.11, 3.55, 4, 4.52, 5.12, 5.94, 7.37] |  | Blood |  |
| 8623 | b-pvk+tkd,neut |  | 0% | name | 34 | 82.35 |  |  | Blood |  |
| 8624 | b-pvk+tkd,rdw | % | 99% | name+unit+values | 4298 | 0 | [12.5, 12.85, 13.17, 13.49, 13.79, 14.12, 14.57, 15.17, 16.52] |  | Blood |  |
| 8625 | b-pvk+tkd,rdw |  | 1% | name | 30 | 76.67 |  |  | Blood |  |
| 8626 | b-pvk+tkd,trom | eg/l | 99% | name+unit+values | 4413 | 0 | [163.91, 190.28, 209.92, 228.62, 246.86, 267.53, 293.03, 326.64, 371.27] |  | Blood |  |
| 8627 | b-pvk+tkd,trom |  | 1% | name | 31 | 74.19 |  |  | Blood |  |
| 8628 | b-pvk+tmd | % | 0% | name+unit | 108 | 0 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  |
| 8629 | b-pvk+tmd |  | 100% | name | 31394 | 99.96 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  |
| 8630 | b-pvk-päi |  | 100% | name | 120 | 100 |  |  | Blood |  |
| 8631 | b-pvk-t |  | 100% | name | 1651 | 100 |  |  | Blood |  |
| 8632 | b-pvk-tkd |  | 100% | name | 5227 | 100 |  |  | Blood |  |
| 8633 | b-pvkt |  | 100% | name | 540592 | 100 |  |  | Blood |  |
| 8634 | b-pvkt+re |  | 100% | name | 3032 | 100 |  |  | Blood |  |
| 8635 | b-pvktkdr |  | 100% | name | 6444 | 100 |  |  | Blood |  |
| 8636 | b-pvktmdl |  | 100% | name | 275 | 100 |  |  | Blood |  |
| 8637 | b-pvktmdp |  | 100% | name | 1012 | 100 |  |  | Blood |  |
| 8638 | b-pvktnee |  | 100% | name | 9809 | 100 |  |  | Blood |  |
| 8639 | b-pvktp |  | 100% | name | 5212 | 100 |  |  | Blood |  |
| 8640 | b-tvk | % | 0% | name+unit+values | 505 | 0 | [0, 0, 0, 0, 1, 2.55, 12.33, 37.94, 62.13] | B -Täydellinen verenkuva | Blood |  |
| 8641 | b-tvk | e9/l | 0% | name+unit+values | 368 | 0 | [0.03, 0.03, 0.04, 0.04, 0.05, 0.05, 0.06, 0.07, 0.09] | B -Täydellinen verenkuva | Blood |  |
| 8642 | b-tvk | fl | 0% | name+unit | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8643 | b-tvk | form | 0% | name+unit | 11 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8644 | b-tvk | g/l | 0% | name+unit | 19 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8645 | b-tvk | paketti | 0% | name+unit | 22 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8646 | b-tvk | pg | 0% | name+unit | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  |
| 8647 | b-tvk |  | 100% | name | 466809 | 100 |  | B -Täydellinen verenkuva | Blood |  |
| 8648 | b-tvk+r |  | 100% | name | 465 | 100 |  |  | Blood |  |

