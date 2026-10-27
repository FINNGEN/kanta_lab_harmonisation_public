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
Here is group 84 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 6367 | gt-cdt-ind |  | 100% | name+values | 8671 | 100 | [2.7, 3.02, 3.27, 3.52, 3.77, 4.04, 4.34, 4.72, 5.26] |  |  | Index |
| 6368 | p-at3-spr | % | 73% | name+unit+values | 330 | 0 | [86.92, 91.6, 95.11, 97.89, 99.97, 102.97, 106.49, 109.7, 115.54] |  | Plasma |  |
| 6369 | p-at3-spr |  | 27% | name+values | 124 | 100 | [91.42, 95.11, 98.49, 101, 103.88, 105.86, 108, 111.89, 116] |  | Plasma |  |
| 6370 | p-traispr | s | 20% | name+unit | 110 | 0 |  |  | Plasma |  |
| 6371 | p-traispr |  | 80% | name | 448 | 100 |  |  | Plasma |  |
| 6372 | p-tt-spa | % | 79% | name+unit+values | 450 | 0 | [61.6, 74.33, 80.55, 86.92, 91.78, 97.31, 102.37, 109.68, 121.76] |  | Plasma |  |
| 6373 | p-tt-spa |  | 21% | name+values | 123 | 100 | [76.4, 84, 88.55, 95.06, 100.62, 106.53, 112.4, 120.3, 128.2] |  | Plasma |  |
| 6374 | p-tt-spr | % | 84% | name+unit+values | 511 | 0 | [71.66, 80.46, 86.05, 90.09, 94.9, 100.49, 106.6, 112.1, 123.79] |  | Plasma |  |
| 6375 | p-tt-spr |  | 16% | name+values | 99 | 100 | [65, 81.47, 86.4, 93.7, 99, 103.7, 111.13, 117.4, 123] |  | Plasma |  |
| 6376 | pd-bavikäs |  | 100% | name | 196 | 100 |  |  | Peritoneal dialysis fluid |  |
| 6377 | pf-ada/s-ada |  | 100% | name+values | 123 | 100 | [0.3, 0.4, 0.5, 0.64, 0.77, 0.81, 1, 1.32, 1.74] |  | Pleural fluid |  |
| 6378 | pt-abiras |  | 100% | name | 244 | 100 |  |  | Patient |  |
| 6379 | pt-acth-r1 |  | 100% | name | 726 | 100 |  | Pt-Adrenokortikotropiini-koe, lyhyt | Patient |  |
| 6380 | pt-acth-ro |  | 100% | name | 107 | 100 |  |  | Patient |  |
| 6381 | pt-acthrma |  | 100% | name | 217 | 100 |  |  | Patient |  |
| 6382 | pt-acthrmk |  | 100% | name | 332 | 100 |  |  | Patient |  |
| 6383 | pt-ada-ind |  | 100% | name+values | 626 | 100 | [0.3, 0.48, 0.6, 0.76, 0.9, 1, 1.2, 1.5, 2.31] |  | Patient | Index |
| 6384 | pt-aiv-pet |  | 100% | name | 106 | 100 |  |  | Patient |  |
| 6385 | pt-aktig |  | 100% | name | 176 | 100 |  | Pt-Liikeativiteettirekisteröinti, aktigrafia | Patient |  |
| 6386 | pt-aktig-2 |  | 100% | name | 154 | 100 |  | Pt-Liikeaktiviteettirekisteröinti, aktigrafia, vaativa | Patient |  |
| 6387 | pt-angirtg |  | 100% | name | 364 | 100 |  |  | Patient |  |
| 6388 | pt-cert |  | 100% | name | 315 | 100 |  |  | Patient |  |
| 6389 | pt-diabet |  | 100% | name | 135 | 100 |  |  | Patient |  |
| 6390 | pt-diascr |  | 100% | name | 527 | 100 |  |  | Patient |  |
| 6391 | pt-dxm-r1 | nmol/l | 1% | name+unit+values | 76 | 0 | [14, 17, 19, 21.2, 25, 27.2, 32.47, 39, 68] | Pt-Deksametasoni-koe, lyhyt | Patient |  |
| 6392 | pt-dxm-r1 |  | 99% | name | 6248 | 100 |  | Pt-Deksametasoni-koe, lyhyt | Patient |  |
| 6393 | pt-erist |  | 100% | name | 848 | 100 |  |  | Patient |  |
| 6394 | pt-fdg-pet |  | 100% | name | 2426 | 100 |  |  | Patient |  |
| 6395 | pt-fdgvpet |  | 100% | name | 736 | 100 |  |  | Patient |  |
| 6396 | pt-fib-4 |  | 100% | name+values | 10764 | 100 | [0.55, 0.74, 0.9, 1.05, 1.2, 1.38, 1.59, 1.9, 2.38] |  | Patient |  |
| 6397 | pt-gal-r3 | min | 19% | name+unit | 36 | 0 |  | Pt-Galaktoosi-koe, puoliintumisaika | Patient |  |
| 6398 | pt-gal-r3 |  | 81% | name | 150 | 100 |  | Pt-Galaktoosi-koe, puoliintumisaika | Patient |  |
| 6399 | pt-galt1/2 | min | 100% | name+unit+values | 184 | 0 | [9, 10.34, 11.82, 13, 14.89, 17.65, 23.89, 32.76, 46.25] |  | Patient |  |
| 6400 | pt-glomfr |  | 100% | name | 357 | 100 |  |  | Patient |  |
| 6401 | pt-hertta |  | 100% | name | 152 | 100 |  |  | Patient |  |
| 6402 | pt-iho-r1 | mm | 40% | name+unit | 115 | 0 |  | Pt-Ihokoe 1, suppea, 1-5 antigeenia | Patient |  |
| 6403 | pt-iho-r1 |  | 60% | name | 173 | 100 |  | Pt-Ihokoe 1, suppea, 1-5 antigeenia | Patient |  |
| 6404 | pt-iho-r3 |  | 100% | name | 1244 | 100 |  | Pt-Ihokoe 3, laaja, 6-20 antigeenia | Patient |  |
| 6405 | pt-kauvduä |  | 100% | name | 312 | 100 |  |  | Patient |  |
| 6406 | pt-kt/v |  | 100% | name+values | 2372 | 100 | [1.18, 1.28, 1.32, 1.36, 1.39, 1.41, 1.45, 1.49, 1.53] |  | Patient |  |
| 6407 | pt-kt/v1 |  | 100% | name+values | 5747 | 100 | [1.09, 1.27, 1.39, 1.48, 1.56, 1.65, 1.74, 1.85, 2.02] |  | Patient |  |
| 6408 | pt-laihdu |  | 100% | name | 149 | 100 |  |  | Patient |  |
| 6409 | pt-lakt-r1 | mmol/l | 6% | name+unit | 14 | 0 |  | Pt-Laktoosi-koe | Patient |  |
| 6410 | pt-lakt-r1 |  | 94% | name | 214 | 100 |  | Pt-Laktoosi-koe | Patient |  |
| 6411 | pt-meet2 |  | 100% | name | 110 | 100 |  |  | Patient |  |
| 6412 | pt-meetin |  | 100% | name | 189 | 100 |  |  | Patient |  |
| 6413 | pt-meeting |  | 100% | name | 12544 | 100 |  | Pt-Potilastapauksen kliinispatologinen käsittely | Patient |  |
| 6414 | pt-miesl |  | 100% | name | 889 | 100 |  |  | Patient |  |
| 6415 | pt-miesp |  | 100% | name | 260 | 100 |  |  | Patient |  |
| 6416 | pt-miestp |  | 100% | name | 152 | 100 |  |  | Patient |  |
| 6417 | pt-munfung |  | 100% | name | 310 | 100 |  |  | Patient |  |
| 6418 | pt-nainenl |  | 100% | name | 716 | 100 |  |  | Patient |  |
| 6419 | pt-nainenp |  | 100% | name | 310 | 100 |  |  | Patient |  |
| 6420 | pt-naistp |  | 100% | name | 117 | 100 |  |  | Patient |  |
| 6421 | pt-paino | kg | 95% | name+unit+values | 2695 | 0.15 | [60.61, 67.01, 71.85, 75.49, 79.69, 83.26, 87.24, 92.77, 102.78] |  | Patient |  |
| 6422 | pt-paino |  | 5% | name+values | 153 | 100 | [59.8, 65.06, 69.62, 73.7, 78, 81.97, 85.17, 91.96, 99.6] |  | Patient |  |
| 6423 | pt-pentaca |  | 100% | name | 425 | 100 |  |  | Patient |  |
| 6424 | pt-psmapet |  | 100% | name | 509 | 100 |  |  | Patient |  |
| 6425 | pt-punktio |  | 100% | name | 213 | 100 |  |  | Patient |  |
| 6426 | pt-selvit |  | 100% | name | 506 | 100 |  |  | Patient |  |
| 6427 | pt-som-pet |  | 100% | name | 448 | 100 |  |  | Patient |  |
| 6428 | pt-spr/thl |  | 100% | name | 164 | 100 |  |  | Patient |  |
| 6429 | pt-syd-pet |  | 100% | name | 270 | 100 |  |  | Patient |  |
| 6430 | pt-tahdist |  | 100% | name | 203 | 100 |  |  | Patient |  |
| 6431 | pt-taksim1 |  | 100% | name | 255 | 100 |  |  | Patient |  |
| 6432 | pt-taksim3 |  | 100% | name | 109 | 100 |  |  | Patient |  |
| 6433 | pt-terta |  | 100% | name | 456 | 100 |  |  | Patient |  |
| 6434 | pt-tthscr1 |  | 100% | name | 145 | 100 |  |  | Patient |  |
| 6435 | pt-ttlaite |  | 100% | name | 526 | 100 |  |  | Patient |  |
| 6436 | pt-ttr+inr | % | 76% | name+unit+values | 1974 | 0 | [36.34, 51.51, 59.83, 67.58, 73.4, 78.22, 83.44, 90.53, 99.05] |  | Patient |  |
| 6437 | pt-ttr+inr |  | 24% | name | 609 | 100 |  |  | Patient |  |
| 6438 | pt-vai-tk |  | 100% | name | 397 | 100 |  |  | Patient |  |
| 6439 | pt-valtim |  | 100% | name | 106 | 100 |  |  | Patient |  |
| 6440 | pt-valvot |  | 100% | name | 349 | 100 |  |  | Patient |  |
| 6441 | pt-vartig |  | 100% | name | 2815 | 100 |  |  | Patient |  |
| 6442 | pt-vartspq |  | 100% | name | 144 | 100 |  |  | Patient |  |
| 6443 | pt-vitascr |  | 100% | name | 521 | 100 |  |  | Patient |  |
| 6444 | pt-vitrif |  | 100% | name | 276 | 100 |  |  | Patient |  |

