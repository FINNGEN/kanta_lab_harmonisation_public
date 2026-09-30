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
Here is group 44 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 2735 | -bil | umol/l | 84% | name+unit+values | 433 | 0 | [8.08, 11.42, 17.8, 24.81, 35.56, 52.32, 88.15, 166.34, 422.22] | -Bilirubiini |  |  |
| 2736 | -bil |  | 16% | name | 85 | 95.29 |  | -Bilirubiini |  |  |
| 2737 | b-bio |  | 100% | name | 4183 | 100 |  |  | Blood |  |
| 2738 | b-hg | nmol/l | 56% | name+unit | 64 | 0 |  | B -Elohopea | Blood |  |
| 2739 | b-hg |  | 44% | name | 51 | 94.12 |  | B -Elohopea | Blood |  |
| 2740 | cb-bil | umol/l | 7% | name+unit+values | 331 | 0 | [11.1, 19.39, 22.31, 26.36, 32.8, 45.69, 98.54, 156.29, 216.28] | cB-Bilirubiini | Capillary blood |  |
| 2741 | cb-bil |  | 93% | name | 4244 | 99.98 |  | cB-Bilirubiini | Capillary blood |  |
| 2742 | du-mg | mmol | 79% | name+unit+values | 580 | 0.17 | [2.07, 2.62, 3.11, 3.51, 3.97, 4.42, 4.91, 5.69, 6.98] | dU-Magnesium | 24-hour urine |  |
| 2743 | du-mg |  | 21% | name | 154 | 70.78 |  | dU-Magnesium | 24-hour urine |  |
| 2744 | du-pi | mmol | 83% | name+unit+values | 591 | 0.17 | [14.15, 19.7, 22.95, 26.88, 29.9, 33.43, 38, 43.23, 51.47] | dU-Fosfaatti, epäorgaaninen | 24-hour urine |  |
| 2745 | du-pi |  | 17% | name | 118 | 75.42 |  | dU-Fosfaatti, epäorgaaninen | 24-hour urine |  |
| 2746 | fl-koh |  | 100% | name | 285 | 100 |  |  | Vaginal discharge |  |
| 2747 | fp-bil | umol/l | 100% | name+unit+values | 111 | 0 | [4.98, 6.34, 7.02, 8.69, 9.41, 10.29, 12.14, 15.18, 27.61] |  | Fasting plasma |  |
| 2748 | fp-kol | mmol | 0% | name+unit | 7 | 0 |  | fP-Kolesteroli | Fasting plasma |  |
| 2749 | fp-kol | mmol/ | 0% | name+unit | 7 | 0 |  | fP-Kolesteroli | Fasting plasma |  |
| 2750 | fp-kol | mmol/l | 99% | name+unit+values | 1407523 | 0 | [3.2, 3.63, 3.97, 4.28, 4.58, 4.87, 5.21, 5.6, 6.16] | fP-Kolesteroli | Fasting plasma |  |
| 2751 | fp-kol |  | 1% | name+values | 17406 | 100 | [4.01, 4.31, 4.6, 4.91, 5.19, 5.43, 5.75, 6.21, 6.8] | fP-Kolesteroli | Fasting plasma |  |
| 2752 | fp-vip | pmol/l | 87% | name+unit+values | 391 | 1.53 | [6.42, 8.54, 9.99, 11.21, 13, 14.7, 16.8, 19.84, 27.89] | fP-Vasoaktiivinen intestinaalinen peptidi | Fasting plasma |  |
| 2753 | fp-vip |  | 13% | name | 61 | 81.97 |  | fP-Vasoaktiivinen intestinaalinen peptidi | Fasting plasma |  |
| 2754 | fs-kol | mmol/ | 0% | name+unit | 7 | 0 |  | fS-Kolesteroli | Fasting serum |  |
| 2755 | fs-kol | mmol/l | 100% | name+unit+values | 259011 | 0 | [3.71, 4.15, 4.46, 4.76, 5.03, 5.31, 5.59, 5.95, 6.44] | fS-Kolesteroli | Fasting serum |  |
| 2756 | fs-kol |  | 0% | name+values | 481 | 100 | [3.95, 4.3, 4.66, 4.92, 5.17, 5.39, 5.64, 6.03, 6.57] | fS-Kolesteroli | Fasting serum |  |
| 2757 | li-bio |  | 100% | name | 161 | 100 |  |  | Cerebrospinal fluid |  |
| 2758 | mmse |  | 100% | name | 524 | 94.66 |  |  |  |  |
| 2759 | p-bil | umol/l | 97% | name+unit+values | 1420468 | 0.09 | [5, 6, 7, 8.01, 9.15, 10.92, 12.96, 16.55, 24.99] | P -Bilirubiini | Plasma |  |
| 2760 | p-bil |  | 3% | name+values | 51285 | 100 | [4.75, 5.95, 6.93, 7.97, 9.15, 10.81, 13.1, 17.26, 26.41] | P -Bilirubiini | Plasma |  |
| 2761 | p-bnp | ng/l | 94% | name+unit+values | 92283 | 0 | [19.9, 36.26, 58.02, 88.41, 132.21, 195.75, 292.04, 465.57, 902.19] | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  |
| 2762 | p-bnp | ng/ml | 0% | name+unit | 14 | 0 |  | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  |
| 2763 | p-bnp |  | 6% | name+values | 5638 | 100 | [41.88, 71.98, 108.12, 145.12, 193.35, 257.89, 351.05, 510.91, 912.06] | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  |
| 2764 | p-fsh | u/l | 99% | name+unit+values | 10309 | 0 | [3.43, 4.83, 5.94, 7.2, 9.39, 15.3, 30.23, 51.8, 73.17] | P -Follikkelia stimuloiva hormoni | Plasma |  |
| 2765 | p-fsh |  | 1% | name+values | 155 | 100 | [3.32, 4.57, 5.74, 6.86, 8.5, 12.89, 23.84, 44.5, 70.18] | P -Follikkelia stimuloiva hormoni | Plasma |  |
| 2766 | p-fsl | s | 95% | name+unit+values | 1808 | 0 | [23.6, 25, 25.97, 26.26, 27.2, 28.08, 29.24, 31.3, 34.37] |  | Plasma |  |
| 2767 | p-fsl |  | 5% | name | 86 | 69.77 |  |  | Plasma |  |
| 2768 | p-kol | mmol/l | 99% | name+unit+values | 298985 | 0 | [3.03, 3.42, 3.74, 4.03, 4.33, 4.64, 4.97, 5.37, 5.92] | P -Kolesteroli | Plasma |  |
| 2769 | p-kol |  | 1% | name+values | 2034 | 100 | [3, 3.37, 3.67, 3.97, 4.25, 4.57, 4.92, 5.32, 5.88] | P -Kolesteroli | Plasma |  |
| 2770 | p-mg | mmol/l | 99% | name+unit+values | 259826 | 0.04 | [0.64, 0.7, 0.74, 0.77, 0.8, 0.83, 0.86, 0.89, 0.95] | P -Magnesium | Plasma |  |
| 2771 | p-mg |  | 1% | name+values | 2225 | 100 | [0.64, 0.7, 0.74, 0.78, 0.81, 0.84, 0.86, 0.9, 0.95] | P -Magnesium | Plasma |  |
| 2772 | p-se | umol/l | 95% | name+unit+values | 1087 | 0.09 | [0.86, 1.03, 1.1, 1.19, 1.27, 1.34, 1.41, 1.5, 1.62] | P -Seleeni | Plasma |  |
| 2773 | p-se |  | 5% | name+values | 55 | 43.64 | [1.17, 1.27, 1.34, 1.4, 1.46, 1.54, 1.63, 1.73, 1.94] | P -Seleeni | Plasma |  |
| 2774 | p-tsh | miu/l | 2% | name+unit+values | 32584 | 0 | [0.71, 1.13, 1.46, 1.75, 2.07, 2.43, 2.87, 3.48, 4.57] | P -Tyreotropiini | Plasma |  |
| 2775 | p-tsh | mlu/l | 0% | name+unit+values | 4705 | 0 | [0.58, 1.02, 1.38, 1.7, 2.07, 2.5, 3.01, 3.68, 4.95] | P -Tyreotropiini | Plasma |  |
| 2776 | p-tsh | mu/l | 95% | name+unit+values | 1660849 | 0.06 | [0.53, 0.92, 1.22, 1.5, 1.78, 2.11, 2.53, 3.11, 4.2] | P -Tyreotropiini | Plasma |  |
| 2777 | p-tsh |  | 3% | name+values | 53377 | 100 | [0.3, 0.81, 1.02, 1.41, 1.64, 1.91, 2.3, 2.66, 3.57] | P -Tyreotropiini | Plasma |  |
| 2778 | pf-kol | mmol/l | 63% | name+unit+values | 614 | 0 | [0.64, 0.93, 1.1, 1.3, 1.51, 1.75, 2.03, 2.36, 2.85] | Pf-Kolesteroli | Pleural fluid |  |
| 2779 | pf-kol |  | 37% | name | 361 | 98.06 |  | Pf-Kolesteroli | Pleural fluid |  |
| 2780 | s-bil | umol/l | 99% | name+unit+values | 15554 | 0 | [5.56, 6.89, 7.91, 8.95, 10.06, 11.55, 13.42, 16.35, 22.65] | S -Bilirubiini | Serum |  |
| 2781 | s-bil |  | 1% | name+values | 183 | 82.51 | [5.99, 7.33, 8.34, 9.33, 10.81, 12.14, 14.24, 16.54, 22.13] | S -Bilirubiini | Serum |  |
| 2782 | s-bio |  | 100% | name | 11283 | 100 |  |  | Serum |  |
| 2783 | s-biol |  | 100% | name | 508 | 100 |  |  | Serum |  |
| 2784 | s-fsh | iu/l | 58% | name+unit+values | 21045 | 0 | [3.26, 4.67, 5.97, 7.58, 10.27, 17.4, 33.37, 51.85, 72.5] | S -Follikkelia stimuloiva hormoni | Serum |  |
| 2785 | s-fsh | u/l | 39% | name+unit+values | 14312 | 0.62 | [3.48, 4.97, 6.16, 7.42, 9.34, 13.61, 26.1, 47.59, 73.43] | S -Follikkelia stimuloiva hormoni | Serum |  |
| 2786 | s-fsh |  | 3% | name+values | 1106 | 100 | [3.11, 4.58, 5.88, 7.13, 8.92, 13.11, 23.72, 44.2, 70.34] | S -Follikkelia stimuloiva hormoni | Serum |  |
| 2787 | s-kol | mg/ml | 0% | name+unit | 9 | 0 |  | S -Kolesteroli | Serum |  |
| 2788 | s-kol | mmol/l | 99% | name+unit+values | 35285 | 0 | [3.59, 4.01, 4.33, 4.59, 4.85, 5.11, 5.39, 5.71, 6.19] | S -Kolesteroli | Serum |  |
| 2789 | s-kol |  | 1% | name | 396 | 89.9 |  | S -Kolesteroli | Serum |  |
| 2790 | s-mg | mmol/l | 100% | name+unit+values | 5982 | 0 | [0.77, 0.81, 0.83, 0.85, 0.87, 0.88, 0.9, 0.92, 0.95] | S -Magnesium | Serum |  |
| 2791 | s-mg |  | 0% | name+values | 23 | 69.57 | [0.75, 0.78, 0.8, 0.82, 0.83, 0.85, 0.87, 0.89, 0.91] | S -Magnesium | Serum |  |
| 2792 | s-nse | ug/l | 98% | name+unit+values | 10085 | 0.04 | [9.38, 10.96, 12, 13.1, 14.43, 16.18, 18.88, 24.33, 45.7] | S -Neuronispesifinen enolaasi | Serum |  |
| 2793 | s-nse |  | 2% | name+values | 210 | 45.24 | [8.56, 10, 10.8, 12.01, 14.24, 17, 20.25, 24.5, 29.28] | S -Neuronispesifinen enolaasi | Serum |  |
| 2794 | s-tsh | miu/l | 31% | name+unit+values | 117078 | 0 | [0.56, 0.91, 1.16, 1.39, 1.62, 1.89, 2.23, 2.72, 3.61] | S -Tyreotropiini | Serum |  |
| 2795 | s-tsh | mlu/l | 0% | name+unit+values | 113 | 0 | [0.33, 0.69, 1.02, 1.22, 1.42, 1.62, 2, 2.33, 2.93] | S -Tyreotropiini | Serum |  |
| 2796 | s-tsh | mu/l | 68% | name+unit+values | 253056 | 0 | [0.62, 0.91, 1.15, 1.36, 1.59, 1.85, 2.18, 2.64, 3.49] | S -Tyreotropiini | Serum |  |
| 2797 | s-tsh | u/l | 0% | name+unit+values | 142 | 0 | [0.52, 0.94, 1.22, 1.48, 1.73, 1.98, 2.18, 2.57, 4.01] | S -Tyreotropiini | Serum |  |
| 2798 | s-tsh |  | 1% | name+values | 4491 | 100 | [0.62, 0.91, 1.18, 1.45, 1.66, 1.95, 2.23, 2.72, 3.49] | S -Tyreotropiini | Serum |  |
| 2799 | se-bil | umol/l | 84% | name+unit+values | 526 | 1.33 | [9.24, 12.96, 16.08, 20.31, 26.93, 38.21, 60.68, 119.92, 333.14] |  | Secretion |  |
| 2800 | se-bil |  | 16% | name | 102 | 99.02 |  |  | Secretion |  |
| 2801 | u-al | umol/l | 48% | name+unit+values | 81 | 0 | [0.1, 0.1, 0.2, 0.2, 0.22, 0.3, 0.4, 0.7, 1.7] | U -Alumiini | Urine |  |
| 2802 | u-al |  | 52% | name | 87 | 97.7 |  | U -Alumiini | Urine |  |
| 2803 | u-amp |  | 100% | name | 158 | 100 |  |  | Urine |  |
| 2804 | u-as-i | nmol/l | 11% | name+unit | 16 | 0 |  | U -Arseeni, epäorgaaninen | Urine |  |
| 2805 | u-as-i | ug/l | 14% | name+unit | 20 | 0 |  | U -Arseeni, epäorgaaninen | Urine |  |
| 2806 | u-as-i |  | 75% | name | 107 | 100 |  | U -Arseeni, epäorgaaninen | Urine |  |
| 2807 | u-bil |  | 100% | name | 441 | 100 |  |  | Urine |  |
| 2808 | u-bio |  | 100% | name | 2387 | 100 |  |  | Urine |  |
| 2809 | u-bup |  | 100% | name | 145 | 100 |  |  | Urine |  |
| 2810 | u-bzd |  | 100% | name | 143 | 100 |  |  | Urine |  |
| 2811 | u-cl | mmol/l | 86% | name+unit+values | 200 | 1.5 | [30.37, 49.43, 62.98, 72.55, 86.28, 96.56, 114.04, 135.66, 174.02] | U -Kloridi | Urine | Clearance |
| 2812 | u-cl |  | 14% | name | 33 | 72.73 |  | U -Kloridi | Urine | Clearance |
| 2813 | u-dala | umol/l | 100% | name+unit+values | 111 | 0.9 | [5, 8, 10.96, 13.72, 17, 20.55, 23.93, 29.9, 40.27] | U -Delta-aminolevulinaatti | Urine |  |
| 2814 | u-ds4a |  | 100% | name | 461 | 100 |  |  | Urine |  |
| 2815 | u-ds5 |  | 100% | name | 133 | 100 |  |  | Urine |  |
| 2816 | u-ds5b |  | 100% | name | 1156 | 100 |  |  | Urine |  |
| 2817 | u-ds6 |  | 100% | name | 386 | 100 |  |  | Urine |  |
| 2818 | u-ds6a |  | 100% | name | 1325 | 100 |  |  | Urine |  |
| 2819 | u-ery |  | 100% | name | 3788 | 99.71 |  |  | Urine |  |
| 2820 | u-fyl |  | 100% | name | 145 | 100 |  |  | Urine |  |
| 2821 | u-hg | nmol/l | 81% | name+unit | 108 | 0 |  | U -Elohopea | Urine |  |
| 2822 | u-hg |  | 19% | name | 25 | 100 |  | U -Elohopea | Urine |  |
| 2823 | u-i | ug/l | 94% | name+unit+values | 309 | 0 | [44.03, 61.73, 78.06, 96.82, 115.33, 136.79, 163.87, 204.07, 318.14] | U -Jodidi | Urine |  |
| 2824 | u-i |  | 6% | name | 18 | 88.89 |  | U -Jodidi | Urine |  |
| 2825 | u-inf |  | 100% | name | 51657 | 100 |  |  | Urine |  |
| 2826 | u-intp | nmol/mmol | 66% | name+unit+values | 2098 | 0 | [16.36, 22.55, 28.43, 35.25, 42.57, 53.83, 68.67, 92.78, 154.47] | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  |
| 2827 | u-intp | nmol/mmolkr | 0% | name+unit | 14 | 0 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  |
| 2828 | u-intp | ratio | 1% | name+unit | 47 | 0 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  |
| 2829 | u-intp |  | 32% | name | 1030 | 94.47 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  |
| 2830 | u-kivi | form | 3% | name+unit | 60 | 100 |  | U -Kivianalyysi | Urine |  |
| 2831 | u-kivi |  | 97% | name | 1820 | 100 |  | U -Kivianalyysi | Urine |  |
| 2832 | u-mg | mmol/l | 83% | name+unit+values | 123 | 0.81 | [0.84, 1.34, 1.62, 1.98, 2.27, 2.78, 3.64, 4.45, 6.45] | U -Magnesium | Urine |  |
| 2833 | u-mg |  | 17% | name | 26 | 38.46 |  | U -Magnesium | Urine |  |
| 2834 | u-mtd |  | 100% | name | 144 | 100 |  |  | Urine |  |
| 2835 | u-ni | form | 5% | name+unit | 57 | 0 |  | U -Nikkeli | Urine |  |
| 2836 | u-ni | ug/l | 5% | name+unit | 65 | 0 |  | U -Nikkeli | Urine |  |
| 2837 | u-ni | umol/l | 63% | name+unit+values | 754 | 0 | [0.01, 0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.06] | U -Nikkeli | Urine |  |
| 2838 | u-ni |  | 27% | name | 323 | 90.71 |  | U -Nikkeli | Urine |  |
| 2839 | u-pbg | umol/l | 86% | name+unit+values | 248 | 1.61 | [1, 2, 2, 3, 3.9, 4.42, 5, 6.04, 8.79] | U -Porfobilinogeeni | Urine |  |
| 2840 | u-pbg | umol/mmol | 2% | name+unit | 6 | 0 |  | U -Porfobilinogeeni | Urine |  |
| 2841 | u-pbg |  | 11% | name | 33 | 51.52 |  | U -Porfobilinogeeni | Urine |  |
| 2842 | u-pgb |  | 100% | name | 144 | 100 |  |  | Urine |  |
| 2843 | u-ph. |  | 100% | name+values | 24516 | 1.33 | [5, 5.5, 5.5, 5.87, 6, 6.26, 6.5, 6.96, 7.02] |  | Urine |  |
| 2844 | u-phv |  | 100% | name+values | 737 | 0.27 | [5, 5.5, 5.5, 5.66, 6, 6, 6.5, 7, 7] |  | Urine |  |
| 2845 | u-pi | mmol/l | 90% | name+unit+values | 772 | 0.13 | [4.87, 7.61, 10.55, 13.2, 16.31, 20.1, 24.74, 31.17, 40.13] | U -Fosfaatti, epäorgaaninen | Urine |  |
| 2846 | u-pi |  | 10% | name | 84 | 54.76 |  | U -Fosfaatti, epäorgaaninen | Urine |  |
| 2847 | u-pyr | form | 7% | name+unit | 7 | 0 |  | U -Pyrenoli (1) | Urine |  |
| 2848 | u-pyr | ug/l | 6% | name+unit | 6 | 0 |  | U -Pyrenoli (1) | Urine |  |
| 2849 | u-pyr |  | 87% | name | 88 | 100 |  | U -Pyrenoli (1) | Urine |  |
| 2850 | u-sed |  | 100% | name | 2162 | 99.95 |  |  | Urine |  |
| 2851 | u-sg | kg/l | 98% | name+unit+values | 3827 | 0 | [1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02] |  | Urine |  |
| 2852 | u-sg |  | 2% | name+values | 75 | 100 | [1, 1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.03] |  | Urine |  |
| 2853 | u-thc |  | 100% | name | 157 | 100 |  |  | Urine |  |
| 2854 | u-tml |  | 100% | name | 145 | 100 |  |  | Urine |  |
| 2855 | u-ubg |  | 100% | name | 441 | 100 |  |  | Urine |  |
| 2856 | us-tsh | mu/l | 85% | name+unit+values | 415 | 0.72 | [3.59, 4.74, 5.45, 6.2, 7.04, 7.92, 9.44, 11.82, 16.59] | uS-Tyreotropiini | Umbilical (blood) serum |  |
| 2857 | us-tsh |  | 15% | name | 75 | 33.33 |  | uS-Tyreotropiini | Umbilical (blood) serum |  |
| 2858 | vp-dop |  | 100% | name | 154 | 100 |  | Valtimopaine, dopplermittaus |  |  |

