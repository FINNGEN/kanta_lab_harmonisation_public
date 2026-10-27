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
Here is group 126 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 10411 | ab-hb-co | % | 100% | name+unit+values | 287747 | 0 | [0.4, 0.69, 0.86, 1, 1.15, 1.3, 1.48, 1.72, 2.12] |  | Arterial blood |  |
| 10412 | ab-hb-co |  | 0% | name | 601 | 100 |  |  | Arterial blood |  |
| 10413 | ab-hb-met | % | 100% | name+unit+values | 290833 | 0 | [0.16, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.96, 1.18] |  | Arterial blood |  |
| 10414 | ab-hb-met |  | 0% | name+values | 523 | 100 | [-1, -0.6, -0.27, -0.06, 0.1, 0.2, 0.3, 0.4, 0.9] |  | Arterial blood |  |
| 10415 | ab-hb-vt | g/l | 100% | name+unit+values | 225 | 0 | [111.19, 121, 130.27, 136.29, 140, 145.22, 150.6, 157.19, 167.12] |  | Arterial blood |  |
| 10416 | ab-hkr | osuus | 77% | name+unit+values | 864 | 0 | [0.3, 0.32, 0.35, 0.37, 0.39, 0.41, 0.42, 0.45, 0.47] |  | Arterial blood |  |
| 10417 | ab-hkr |  | 23% | name+values | 263 | 100 | [0.31, 0.34, 0.36, 0.38, 0.4, 0.41, 0.42, 0.45, 0.47] |  | Arterial blood |  |
| 10418 | b-ghb-a1c | % | 87% | name+unit+values | 87878 | 0 | [5.2, 5.42, 5.59, 5.73, 5.91, 6.13, 6.47, 7.08, 8.13] |  | Blood |  |
| 10419 | b-ghb-a1c | mmol | 0% | name+unit | 50 | 0 |  |  | Blood |  |
| 10420 | b-ghb-a1c | mmol/mol | 2% | name+unit+values | 2333 | 0 | [37.33, 39.77, 41.82, 43.61, 45.59, 48.88, 52.44, 59, 68.33] |  | Blood |  |
| 10421 | b-ghb-a1c |  | 11% | name | 11089 | 100 |  |  | Blood |  |
| 10422 | b-ghb-a1c,tk | % | 100% | name+unit+values | 5304 | 0 | [5.43, 5.76, 6.16, 6.59, 7.03, 7.45, 7.9, 8.45, 9.34] |  | Blood |  |
| 10423 | b-ghb-a1cv | mmol/mol | 98% | name+unit+values | 346 | 0 | [41.33, 44.54, 47.42, 50.55, 53.09, 56.35, 59.4, 64.46, 73.63] |  | Blood |  |
| 10424 | b-ghb-a1cv |  | 2% | name | 6 | 100 |  |  | Blood |  |
| 10425 | b-ghba1c | % | 99% | name+unit+values | 3607 | 0 | [5.39, 5.56, 5.73, 5.9, 6.1, 6.4, 6.8, 7.38, 8.29] |  | Blood |  |
| 10426 | b-ghba1c |  | 1% | name | 36 | 100 |  |  | Blood |  |
| 10427 | b-ghba1c- | % | 100% | name+unit | 123 | 0 |  |  | Blood |  |
| 10428 | b-ghba1c-oma | % | 97% | name+unit+values | 360 | 0 | [5.7, 5.9, 6, 6.2, 6.4, 6.67, 6.91, 7.42, 8.16] |  | Blood |  |
| 10429 | b-ghba1c-oma |  | 3% | name | 13 | 100 |  |  | Blood |  |
| 10430 | b-ghba1c/ | % | 98% | name+unit+values | 566 | 0.35 | [5.6, 5.83, 6, 6.19, 6.39, 6.63, 6.84, 7.16, 7.71] |  | Blood |  |
| 10431 | b-ghba1c/ |  | 2% | name | 11 | 100 |  |  | Blood |  |
| 10432 | b-ghba1c/p | % | 71% | name+unit+values | 506 | 0 | [5.93, 6.26, 6.57, 6.86, 7.1, 7.44, 7.84, 8.32, 9.4] |  | Blood |  |
| 10433 | b-ghba1c/p |  | 29% | name+values | 206 | 100 | [5.97, 6.26, 6.51, 6.72, 7.01, 7.3, 7.7, 8.34, 8.93] |  | Blood |  |
| 10434 | b-ghba1cp | % | 100% | name+unit+values | 4868 | 0 | [5.97, 6.3, 6.58, 6.88, 7.16, 7.46, 7.8, 8.23, 8.9] |  | Blood |  |
| 10435 | b-ghba1cp |  | 0% | name | 13 | 100 |  |  | Blood |  |
| 10436 | b-ghba1cv |  | 100% | name | 423 | 100 |  |  | Blood |  |
| 10437 | b-ghba1cvt |  | 100% | name | 135 | 100 |  |  | Blood |  |
| 10438 | b-hb-a1c | % | 88% | name+unit+values | 62531 | 0 | [5.29, 5.44, 5.6, 5.77, 5.95, 6.17, 6.48, 6.96, 7.84] | B -Hemoglobiini-A1C, glykoitunut | Blood |  |
| 10439 | b-hb-a1c | %/mmol | 0% | name+unit | 29 | 0 |  | B -Hemoglobiini-A1C, glykoitunut | Blood |  |
| 10440 | b-hb-a1c | mmol/l | 0% | name+unit | 13 | 7.69 |  | B -Hemoglobiini-A1C, glykoitunut | Blood |  |
| 10441 | b-hb-a1c | mmol/mol | 11% | name+unit+values | 7621 | 0 | [34.01, 36.12, 37.89, 39.5, 41.2, 43.55, 46.81, 52.53, 62.2] | B -Hemoglobiini-A1C, glykoitunut | Blood |  |
| 10442 | b-hb-a1c |  | 2% | name | 1216 | 100 |  | B -Hemoglobiini-A1C, glykoitunut | Blood |  |
| 10443 | b-hb-co | % | 90% | name+unit+values | 82164 | 0 | [0.89, 1.18, 1.38, 1.56, 1.71, 1.88, 2.05, 2.26, 2.63] | B -Hemoglobiini, hiilimonoksidi | Blood |  |
| 10444 | b-hb-co |  | 10% | name+values | 9154 | 100 | [-0.38, -0.21, -0.17, -0.1, 0.02, 1, 1, 1, 1.99] | B -Hemoglobiini, hiilimonoksidi | Blood |  |
| 10445 | b-hb-co. | % | 99% | name+unit+values | 1009 | 0 | [1.01, 1.42, 1.61, 1.79, 1.94, 2.14, 2.31, 2.51, 2.86] |  | Blood |  |
| 10446 | b-hb-co. |  | 1% | name | 9 | 100 |  |  | Blood |  |
| 10447 | b-hb-ef |  | 100% | name | 124 | 100 |  | B -Hemoglobiini, elektroforeesi, verestä | Blood |  |
| 10448 | b-hb-f | % | 52% | name+unit+values | 609 | 0.49 | [0, 0.92, 2.09, 5.89, 14.57, 22.26, 24.76, 27.04, 30.81] | B -Hemoglobiini, fetaali | Blood |  |
| 10449 | b-hb-f |  | 48% | name | 572 | 100 |  | B -Hemoglobiini, fetaali | Blood |  |
| 10450 | b-hb-f-vr | % | 22% | name+unit | 24 | 0 |  | B -Hemoglobiini, fetaali, värjäys | Blood | Staining |
| 10451 | b-hb-f-vr |  | 78% | name | 84 | 100 |  | B -Hemoglobiini, fetaali, värjäys | Blood | Staining |
| 10452 | b-hb-fr |  | 100% | name | 398 | 100 |  | B -Hemoglobiini, fraktiot | Blood | Fractions |
| 10453 | b-hb-hoi |  | 100% | name+values | 230 | 100 | [103.94, 111.88, 117.74, 122.95, 126.96, 132.1, 135.84, 143.2, 148.99] |  | Blood |  |
| 10454 | b-hb-ief | form | 3% | name+unit | 10 | 0 |  | B -Hemoglobiini, isoelektrinen fokusointi | Blood | Isoelectric focusing |
| 10455 | b-hb-ief |  | 97% | name | 298 | 100 |  | B -Hemoglobiini, isoelektrinen fokusointi | Blood | Isoelectric focusing |
| 10456 | b-hb-met | % | 90% | name+unit+values | 81133 | 0 | [0.45, 0.62, 0.79, 0.9, 1, 1.1, 1.2, 1.3, 1.47] | B -Methemoglobiini | Blood |  |
| 10457 | b-hb-met |  | 10% | name+values | 8996 | 100 | [-0.9, -0.36, -0.3, -0.2, -0.1, -0.1, -0.1, 0.48, 0.8] | B -Methemoglobiini | Blood |  |
| 10458 | b-hb-met. | % | 99% | name+unit+values | 1016 | 0 | [0.63, 0.83, 0.94, 1.06, 1.11, 1.2, 1.3, 1.4, 1.6] |  | Blood |  |
| 10459 | b-hb-met. |  | 1% | name | 10 | 100 |  |  | Blood |  |
| 10460 | b-hb-o | g/l | 14% | name+unit | 36 | 13.89 |  |  | Blood | Qualitative test (also semi-quantitative) |
| 10461 | b-hb-o |  | 86% | name+values | 229 | 100 | [95.33, 106.5, 114.78, 121.31, 126.79, 131.45, 137.03, 142.44, 148.67] |  | Blood | Qualitative test (also semi-quantitative) |
| 10462 | b-hb-poc | g/l | 20% | name+unit | 26 | 3.85 |  |  | Blood |  |
| 10463 | b-hb-poc |  | 80% | name+values | 106 | 100 | [109, 115.5, 120.67, 126.17, 128.33, 131.5, 135, 137.75, 145] |  | Blood |  |
| 10464 | b-hb-pt | g/l | 80% | name+unit+values | 649 | 0 | [100.43, 115.06, 121.84, 129.26, 133.9, 138.93, 143.78, 148.8, 154.91] |  | Blood |  |
| 10465 | b-hb-pt |  | 20% | name+values | 166 | 100 | [101.8, 109.84, 119.26, 127.38, 133.79, 137.87, 143.9, 152.16, 160.2] |  | Blood |  |
| 10466 | b-hb-vt | g/l | 100% | name+unit+values | 4224 | 0 | [103.86, 114.44, 120.79, 126.22, 130.62, 135.07, 140.03, 145.79, 153.81] | B -Hemoglobiini, vieritutkimus | Blood |  |
| 10467 | b-hb-vt |  | 0% | name | 6 | 100 |  | B -Hemoglobiini, vieritutkimus | Blood |  |
| 10468 | b-hba1c | % | 0% | name+unit+values | 847 | 0 | [5.33, 5.59, 5.76, 5.92, 6.09, 6.4, 6.81, 7.45, 8.49] | B -Hemoglobiini-A1c | Blood |  |
| 10469 | b-hba1c | form | 0% | name+unit | 16 | 0 |  | B -Hemoglobiini-A1c | Blood |  |
| 10470 | b-hba1c | mmol | 0% | name+unit+values | 1356 | 0 | [34.05, 36, 37.63, 39.08, 40.8, 42.57, 45.91, 51.48, 61.02] | B -Hemoglobiini-A1c | Blood |  |
| 10471 | b-hba1c | mmol/l | 0% | name+unit+values | 135 | 0.74 | [31.02, 33, 34, 35, 36, 37, 38, 39, 42] | B -Hemoglobiini-A1c | Blood |  |
| 10472 | b-hba1c | mmol/m | 0% | name+unit+values | 2831 | 0 | [32.52, 34.15, 35.7, 37.07, 38.51, 40.34, 43, 48.76, 59.85] | B -Hemoglobiini-A1c | Blood |  |
| 10473 | b-hba1c | mmol/ml | 0% | name+unit+values | 138 | 0 | [32, 33.68, 34.75, 35.94, 37.85, 38, 39.68, 41.38, 43] | B -Hemoglobiini-A1c | Blood |  |
| 10474 | b-hba1c | mmol/mol | 93% | name+unit+values | 1976825 | 0 | [33.05, 35.18, 36.97, 38.1, 39.99, 42.16, 45.07, 50.32, 60.31] | B -Hemoglobiini-A1c | Blood |  |
| 10475 | b-hba1c |  | 6% | name | 133002 | 100 |  | B -Hemoglobiini-A1c | Blood |  |
| 10476 | b-hba1c,t |  | 100% | name+values | 10329 | 100 | [28.69, 39.63, 43.09, 47.24, 51.82, 56.59, 61.9, 68.13, 77.56] |  | Blood |  |
| 10477 | b-hba1c,tk | mmol/mol | 100% | name+unit+values | 7907 | 0.01 | [35.82, 39.36, 43.46, 47.75, 52.16, 56.55, 61.35, 67.21, 76.08] |  | Blood |  |
| 10478 | b-hba1c-o |  | 100% | name+values | 337 | 100 | [6.05, 6.44, 6.78, 7.33, 7.97, 10.13, 38.6, 48.91, 61.53] |  | Blood | Qualitative test (also semi-quantitative) |
| 10479 | b-hba1c-om |  | 100% | name | 127 | 100 |  |  | Blood |  |
| 10480 | b-hba1c-oma |  | 100% | name+values | 440 | 100 | [39, 41, 42, 43.9, 46, 49.06, 51.84, 56.91, 65.06] |  | Blood |  |
| 10481 | b-hba1c-p | % | 14% | name+unit+values | 153 | 3.27 | [6.4, 6.72, 7.1, 7.6, 7.94, 8.2, 8.55, 9, 9.88] |  | Blood | Upright (standing) |
| 10482 | b-hba1c-p | mmol/mol | 81% | name+unit+values | 867 | 0.35 | [44.02, 49.67, 54.3, 58.25, 62.24, 65.89, 70.4, 74.81, 84.61] |  | Blood | Upright (standing) |
| 10483 | b-hba1c-p |  | 5% | name | 55 | 100 |  |  | Blood | Upright (standing) |
| 10484 | b-hba1c/p | mmol/mol | 35% | name+unit+values | 568 | 0 | [37.94, 40, 42, 43.91, 45.94, 49.31, 51.37, 54.5, 60.85] |  | Blood |  |
| 10485 | b-hba1c/p |  | 65% | name | 1078 | 100 |  |  | Blood |  |
| 10486 | b-hba1c/pi |  | 100% | name+values | 1172 | 100 | [40.12, 43.68, 47.04, 50.61, 53.4, 56.88, 61.12, 66.65, 76.14] |  | Blood |  |
| 10487 | b-hba1chy | mmol/mol | 100% | name+unit+values | 261 | 0 | [41.44, 47.08, 50.41, 54.19, 57.44, 60.77, 65.08, 71.6, 82.33] |  | Blood |  |
| 10488 | b-hba1cp | % | 10% | name+unit+values | 1574 | 0.19 | [5.77, 6.01, 6.21, 6.46, 6.69, 6.98, 7.32, 7.75, 8.45] |  | Blood |  |
| 10489 | b-hba1cp | mmol/mol | 89% | name+unit+values | 13769 | 0.02 | [40.97, 44.13, 47.25, 50.28, 53.07, 56.14, 59.73, 64.36, 71.61] |  | Blood |  |
| 10490 | b-hba1cp |  | 0% | name | 60 | 100 |  |  | Blood |  |
| 10491 | b-hba1cpi | mmol/mol | 100% | name+unit+values | 1299 | 0 | [37.79, 40.52, 42.7, 45.2, 48.39, 51.41, 55.01, 61.08, 69.91] |  | Blood |  |
| 10492 | b-hba1cvt | % | 35% | name+unit+values | 7630 | 0 | [5.82, 6.13, 6.39, 6.65, 6.92, 7.24, 7.57, 8.02, 8.75] | B -Hemoglobiini-A1c, vieritutkimus | Blood |  |
| 10493 | b-hba1cvt | mmol | 0% | name+unit | 7 | 0 |  | B -Hemoglobiini-A1c, vieritutkimus | Blood |  |
| 10494 | b-hba1cvt | mmol/mol | 63% | name+unit+values | 13876 | 0.01 | [41.8, 45.73, 49.05, 52.33, 55.71, 59.15, 63.13, 68.18, 76.86] | B -Hemoglobiini-A1c, vieritutkimus | Blood |  |
| 10495 | b-hba1cvt |  | 3% | name | 591 | 100 |  | B -Hemoglobiini-A1c, vieritutkimus | Blood |  |
| 10496 | b-hbf-fc | % | 6% | name+unit | 16 | 0 |  | B -Immunofenotyypitys, fetaalihemoglobiini | Blood | Flow cytometry |
| 10497 | b-hbf-fc | form | 9% | name+unit | 24 | 0 |  | B -Immunofenotyypitys, fetaalihemoglobiini | Blood | Flow cytometry |
| 10498 | b-hbf-fc |  | 84% | name | 215 | 100 |  | B -Immunofenotyypitys, fetaalihemoglobiini | Blood | Flow cytometry |
| 10499 | b-hbfvol | ml | 9% | name+unit | 14 | 0 |  |  | Blood |  |
| 10500 | b-hbfvol |  | 91% | name | 139 | 100 |  |  | Blood |  |
| 10501 | b-hbhoi | g/l | 88% | name+unit+values | 496 | 0 | [97.88, 110.36, 119.68, 125.02, 129.72, 135.92, 143.92, 151.3, 159.16] |  | Blood |  |
| 10502 | b-hbhoi |  | 12% | name | 66 | 100 |  |  | Blood |  |
| 10503 | b-hbhplc |  | 100% | name | 308 | 100 |  |  | Blood |  |
| 10504 | b-hbpoc | g/l | 100% | name+unit+values | 639 | 0 | [97.85, 107.26, 112.9, 117.7, 122.88, 126.88, 132.06, 138.55, 147.12] |  | Blood |  |
| 10505 | b-hkr | % | 46% | name+unit+values | 5020904 | 0 | [29.67, 33.32, 36, 37.79, 39.16, 40.79, 42, 43.3, 45.13] | B -Erytrosyytit, tilavuusosuus | Blood |  |
| 10506 | b-hkr | fl | 0% | name+unit+values | 7243 | 0 | [84.54, 86.11, 87.23, 88.3, 89.15, 90.24, 91.28, 92.73, 94.69] | B -Erytrosyytit, tilavuusosuus | Blood |  |
| 10507 | b-hkr | form | 0% | name+unit | 33 | 0 |  | B -Erytrosyytit, tilavuusosuus | Blood |  |
| 10508 | b-hkr | l/l | 0% | name+unit+values | 3192 | 0 | [0.36, 0.38, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45, 0.46] | B -Erytrosyytit, tilavuusosuus | Blood |  |
| 10509 | b-hkr | ratio | 53% | name+unit+values | 5806054 | 0 | [0.31, 0.34, 0.36, 0.38, 0.4, 0.41, 0.42, 0.44, 0.46] | B -Erytrosyytit, tilavuusosuus | Blood |  |
| 10510 | b-hkr |  | 1% | name | 119384 | 100 |  | B -Erytrosyytit, tilavuusosuus | Blood |  |
| 10511 | b-hkr.fol | % | 15% | name+unit | 28 | 0 |  |  | Blood |  |
| 10512 | b-hkr.fol |  | 85% | name+values | 153 | 100 | [0.36, 0.37, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45, 0.46] |  | Blood |  |
| 10513 | b-hkrhoi | osuus | 10% | name+unit | 18 | 0 |  |  | Blood |  |
| 10514 | b-hkrhoi |  | 90% | name+values | 155 | 100 | [0.3, 0.32, 0.36, 0.38, 0.4, 0.42, 0.44, 0.46, 0.49] |  | Blood |  |
| 10515 | b-hkrp | % | 100% | name+unit+values | 1281 | 0 | [35.35, 37.88, 39.35, 40.46, 41.52, 42.63, 43.67, 45, 46.74] |  | Blood |  |
| 10516 | b-hkrp |  | 0% | name | 6 | 100 |  |  | Blood |  |
| 10517 | b-hla-bw | form | 7% | name+unit | 44 | 0 |  |  | Blood |  |
| 10518 | b-hla-bw |  | 93% | name | 611 | 100 |  |  | Blood |  |
| 10519 | b-hla1mun |  | 100% | name | 828 | 100 |  |  | Blood |  |
| 10520 | b-hla1pk |  | 100% | name | 316 | 100 |  |  | Blood |  |
| 10521 | b-hla2frk |  | 100% | name | 124 | 100 |  |  | Blood |  |
| 10522 | b-hla2prk |  | 100% | name | 155 | 100 |  |  | Blood |  |
| 10523 | b-hlaabac |  | 100% | name | 120 | 100 |  | B -Abacavir-yliherkkyys, HLA-assosiaatio, DNA-tutkimus | Blood |  |
| 10524 | b-hlaad | form | 4% | name+unit | 65 | 0 |  | B -HLA-A, DNA-tutkimus | Blood |  |
| 10525 | b-hlaad |  | 96% | name | 1525 | 100 |  | B -HLA-A, DNA-tutkimus | Blood |  |
| 10526 | b-hlaadt | form | 6% | name+unit | 11 | 0 |  | B -HLA-A, DNA-tutkimus, tarkennettu | Blood |  |
| 10527 | b-hlaadt |  | 94% | name | 186 | 100 |  | B -HLA-A, DNA-tutkimus, tarkennettu | Blood |  |
| 10528 | b-hlaag |  | 100% | name | 126 | 100 |  |  | Blood |  |
| 10529 | b-hlabd | form | 4% | name+unit | 66 | 0 |  | B -HLA-B, DNA-tutkimus | Blood |  |
| 10530 | b-hlabd |  | 96% | name | 1637 | 100 |  | B -HLA-B, DNA-tutkimus | Blood |  |
| 10531 | b-hlabdt | form | 5% | name+unit | 10 | 0 |  | B -HLA-B, DNA-tutkimus, tarkennettu | Blood |  |
| 10532 | b-hlabdt |  | 95% | name | 185 | 100 |  | B -HLA-B, DNA-tutkimus, tarkennettu | Blood |  |
| 10533 | b-hlabg |  | 100% | name | 126 | 100 |  |  | Blood |  |
| 10534 | b-hlacdt | form | 5% | name+unit | 10 | 0 |  | B -HLA-C, DNA-tutkimus, tarkennettu | Blood |  |
| 10535 | b-hlacdt |  | 95% | name | 187 | 100 |  | B -HLA-C, DNA-tutkimus, tarkennettu | Blood |  |
| 10536 | b-hlacg |  | 100% | name | 117 | 100 |  |  | Blood |  |
| 10537 | b-hladpb1g |  | 100% | name | 117 | 100 |  |  | Blood |  |
| 10538 | b-hladpbd | form | 5% | name+unit | 10 | 0 |  | B -HLA-DPB, DNA-tutkimus, tarkennettu | Blood |  |
| 10539 | b-hladpbd |  | 95% | name | 186 | 100 |  | B -HLA-DPB, DNA-tutkimus, tarkennettu | Blood |  |
| 10540 | b-hladqb1g |  | 100% | name | 117 | 100 |  |  | Blood |  |
| 10541 | b-hladqbd | form | 5% | name+unit | 10 | 0 |  | B -HLA-DQB, DNA-tutkimus, tarkennettu | Blood |  |
| 10542 | b-hladqbd |  | 95% | name | 184 | 100 |  | B -HLA-DQB, DNA-tutkimus, tarkennettu | Blood |  |
| 10543 | b-hladrb1g |  | 100% | name | 125 | 100 |  |  | Blood |  |
| 10544 | b-hladrbd | form | 4% | name+unit | 62 | 0 |  | B -HLA-DRB, DNA-tutkimus | Blood |  |
| 10545 | b-hladrbd |  | 96% | name | 1486 | 100 |  | B -HLA-DRB, DNA-tutkimus | Blood |  |
| 10546 | b-hladrld | form | 6% | name+unit | 10 | 0 |  | B -HLA-DRB, DNA-tutkimus, tarkennettu | Blood |  |
| 10547 | b-hladrld |  | 94% | name | 158 | 100 |  | B -HLA-DRB, DNA-tutkimus, tarkennettu | Blood |  |
| 10548 | b-hlamaks |  | 100% | name | 277 | 100 |  |  | Blood |  |
| 10549 | b-hlasyke |  | 100% | name | 348 | 100 |  |  | Blood |  |
| 10550 | b-hlatrb |  | 100% | name | 133 | 100 |  |  | Blood |  |
| 10551 | b-vthba1c | mmol/mol | 99% | name+unit+values | 1184 | 0.08 | [45.54, 50.5, 53.58, 56.3, 58.39, 61.04, 63.92, 68.87, 77.06] |  | Blood |  |
| 10552 | b-vthba1c |  | 1% | name | 8 | 100 |  |  | Blood |  |
| 10553 | cb-hb-hy | g/l | 100% | name+unit+values | 1578 | 0.19 | [98.91, 111.68, 118.7, 123.76, 129.35, 133.47, 138.3, 144.32, 152.78] |  | Capillary blood |  |
| 10554 | cb-hb-v |  | 100% | name+values | 312 | 100 | [95.63, 107.52, 115.55, 122.44, 129.89, 134.53, 139.44, 145.94, 153.46] |  | Capillary blood | Free or unconjugated |
| 10555 | cb-hba1cnla | mmol/mol | 68% | name+unit | 212 | 0 |  |  | Capillary blood |  |
| 10556 | cb-hba1cnla |  | 32% | name | 102 | 100 |  |  | Capillary blood |  |
| 10557 | f-hb-hum |  | 100% | name | 457 | 100 |  |  | Feces |  |
| 10558 | f-hb-o |  | 100% | name | 2079 | 100 |  | F -Hemoglobiini (kval) | Feces | Qualitative test (also semi-quantitative) |
| 10559 | f-hb-o2 |  | 100% | name | 146 | 100 |  |  | Feces |  |
| 10560 | f-hb-o3 |  | 100% | name | 125 | 100 |  |  | Feces |  |
| 10561 | f-hhb-1 |  | 100% | name | 400 | 100 |  |  | Feces |  |
| 10562 | f-hhb-2 |  | 100% | name | 400 | 100 |  |  | Feces |  |
| 10563 | f-hhb-o | estimate | 0% | name+unit | 106 | 0 |  | F -Hemoglobiini, ihmisen (kval) | Feces | Qualitative test (also semi-quantitative) |
| 10564 | f-hhb-o | form | 0% | name+unit | 18 | 0 |  | F -Hemoglobiini, ihmisen (kval) | Feces | Qualitative test (also semi-quantitative) |
| 10565 | f-hhb-o |  | 100% | name | 52037 | 100 |  | F -Hemoglobiini, ihmisen (kval) | Feces | Qualitative test (also semi-quantitative) |
| 10566 | f-hhb-ox3 |  | 100% | name | 141 | 100 |  |  | Feces |  |
| 10567 | hba1c |  | 100% | name | 2374 | 100 |  |  |  |  |
| 10568 | hoighb-a1c |  | 100% | name+values | 387 | 100 | [40.25, 44.21, 48.92, 53.87, 58.77, 64.48, 69.2, 76.02, 85.37] |  |  |  |
| 10569 | hoihba1c |  | 100% | name+values | 652 | 100 | [45.35, 49.99, 53.1, 56.13, 59.42, 63, 67.63, 72.67, 79.74] |  |  |  |
| 10570 | mb-hb-co | % | 100% | name+unit+values | 574 | 0 | [0.79, 0.91, 1.08, 1.11, 1.2, 1.3, 1.43, 1.59, 1.82] |  |  |  |
| 10571 | mb-hb-met | % | 100% | name+unit+values | 574 | 0 | [0.5, 0.6, 0.7, 0.71, 0.8, 0.9, 0.98, 1.08, 1.33] |  |  |  |
| 10572 | u-hb-dec |  | 100% | name+values | 152 | 100 | [1034.47, 1050, 1065.3, 1082.98, 1121.64, 1184.46, 1367.25, 1689.47, 1915.55] |  | Urine |  |
| 10573 | u-hb-o | A | 0% | name+unit | 19 | 0 |  | U -Hemoglobiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10574 | u-hb-o | estimate | 0% | name+unit | 65 | 0 |  | U -Hemoglobiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10575 | u-hb-o |  | 100% | name+values | 350964 | 100 | [0, 0, 0, 0.02, 1, 1, 1.23, 2.66, 3.01] | U -Hemoglobiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10576 | u-hb-o. |  | 100% | name | 23128 | 100 |  |  | Urine |  |
| 10577 | vb-hb-co | % | 99% | name+unit+values | 63056 | 0 | [0.3, 0.59, 0.79, 0.94, 1.09, 1.26, 1.44, 1.7, 2.22] |  | Venous blood |  |
| 10578 | vb-hb-co |  | 1% | name+values | 421 | 100 | [-0.6, -0.35, -0.2, -0.1, 0.25, 0.91, 1.19, 1.53, 2.3] |  | Venous blood |  |
| 10579 | vb-hb-met | % | 99% | name+unit+values | 62766 | 0 | [0.2, 0.3, 0.4, 0.5, 0.6, 0.68, 0.78, 0.9, 1.09] |  | Venous blood |  |
| 10580 | vb-hb-met |  | 1% | name | 329 | 100 |  |  | Venous blood |  |
| 10581 | vb-hb-vt | 1 | 4% | name+unit | 40 | 0 |  |  | Venous blood |  |
| 10582 | vb-hb-vt | g/l | 72% | name+unit+values | 790 | 0 | [111.74, 124.93, 132.25, 138.24, 143.08, 147.41, 152.55, 158.57, 167] |  | Venous blood |  |
| 10583 | vb-hb-vt |  | 25% | name+values | 273 | 100 | [103.37, 120.62, 125.98, 130.71, 135.91, 139.96, 144.6, 150.76, 156.45] |  | Venous blood |  |
| 10584 | vb-hkr-vt | 1 | 27% | name+unit | 40 | 0 |  |  | Venous blood |  |
| 10585 | vb-hkr-vt |  | 73% | name | 110 | 100 |  |  | Venous blood |  |

