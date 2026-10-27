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
Here is group 111 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 9055 | -crp-o |  | 100% | name+values | 285 | 100 | [1.78, 4.57, 8.47, 13.7, 22.69, 32.46, 46.6, 73.58, 109.4] |  |  | Qualitative test (also semi-quantitative) |
| 9056 | -cyp2b6 |  | 100% | name | 2593 | 100 |  |  |  |  |
| 9057 | -cyp2c19 |  | 100% | name | 2601 | 100 |  |  |  |  |
| 9058 | -cyp2c9 |  | 100% | name | 2594 | 100 |  |  |  |  |
| 9059 | -cyp2d6 |  | 100% | name | 2585 | 100 |  |  |  |  |
| 9060 | -cyp3a5 |  | 100% | name | 2594 | 100 |  |  |  |  |
| 9061 | -cyp4f2 |  | 100% | name+values | 2594 | 100 | [11, 11, 11, 11, 11, 11.01, 13, 13, 13] |  |  |  |
| 9062 | -hcgbsuh | % | 14% | name+unit+values | 349 | 0 | [2.04, 3.59, 5.05, 7.34, 10.09, 13.58, 18.22, 33.58, 53.88] |  |  |  |
| 9063 | -hcgbsuh |  | 86% | name | 2216 | 100 |  |  |  |  |
| 9064 | b-ckmbmv |  | 100% | name+values | 268 | 100 | [1.1, 1.2, 1.3, 1.49, 1.68, 1.87, 2.18, 3.02, 5.19] |  | Blood |  |
| 9065 | b-crp-0 | mg/l | 64% | name+unit+values | 280 | 0 | [6.12, 8.21, 10.3, 13.62, 18.95, 26.74, 38.92, 56.79, 94.86] |  | Blood |  |
| 9066 | b-crp-0 |  | 36% | name | 159 | 100 |  |  | Blood |  |
| 9067 | b-crp-o | mg/l | 63% | name+unit+values | 4645 | 0 | [6.89, 9.54, 13.07, 17.91, 24.02, 32.68, 45.29, 63.98, 96.23] |  | Blood | Qualitative test (also semi-quantitative) |
| 9068 | b-crp-o |  | 37% | name | 2697 | 100 |  |  | Blood | Qualitative test (also semi-quantitative) |
| 9069 | b-crp-os |  | 100% | name+values | 722 | 100 | [8.23, 12.34, 17.13, 22.2, 29.21, 39.16, 57.77, 71.42, 103.76] |  | Blood |  |
| 9070 | b-crp-poc | mg/l | 66% | name+unit+values | 3324 | 0.15 | [6.18, 8.49, 11.75, 15.65, 21.27, 28.91, 40.33, 56.63, 84.68] |  | Blood |  |
| 9071 | b-crp-poc |  | 34% | name | 1709 | 100 |  |  | Blood |  |
| 9072 | b-crp-pt | mg/l | 35% | name+unit+values | 478 | 0 | [6.89, 9.09, 12.92, 17.68, 25.52, 36.09, 50.45, 69.71, 107.87] |  | Blood |  |
| 9073 | b-crp-pt |  | 65% | name+values | 891 | 100 | [7, 9.67, 13.33, 18.07, 24.95, 38.04, 53.76, 86.77, 121.33] |  | Blood |  |
| 9074 | b-crp-tth | mg/l | 54% | name+unit | 61 | 0 |  |  | Blood |  |
| 9075 | b-crp-tth |  | 46% | name | 52 | 100 |  |  | Blood |  |
| 9076 | b-crp-v | mg/l | 66% | name+unit+values | 1837 | 0 | [4.76, 9.44, 12.48, 16.97, 23.43, 35.1, 48.82, 67.87, 108.81] |  | Blood | Free or unconjugated |
| 9077 | b-crp-v |  | 34% | name+values | 961 | 100 | [1.3, 1.6, 2.15, 2.74, 3.34, 4.12, 5.16, 6.16, 8] |  | Blood | Free or unconjugated |
| 9078 | b-crp-vt | mg/l | 57% | name+unit+values | 20172 | 0 | [5.97, 7.8, 10.39, 14.13, 19.28, 26.74, 38.07, 54.9, 88.62] | B -C-reaktiivinen proteiini, vieritutkimus | Blood |  |
| 9079 | b-crp-vt |  | 43% | name | 14973 | 100 |  | B -C-reaktiivinen proteiini, vieritutkimus | Blood |  |
| 9080 | b-cyp2c19 |  | 100% | name | 617 | 100 |  | B -Sytokromi P450 2C19, CYP2C19-geenin alleelit *2 ja *17, DNA-tutkimus verestä | Blood |  |
| 9081 | b-cyp2d6 |  | 100% | name | 723 | 100 |  | B -Sytokromi P450 2D6, CYP2D6-geenin variaatiot, DNA-tutkimus verestä | Blood |  |
| 9082 | cb-crp(qr) | mg/l | 64% | name+unit+values | 3604 | 0.08 | [6, 8, 10.5, 14.3, 18.62, 24.99, 34.66, 50.48, 80.71] |  | Capillary blood |  |
| 9083 | cb-crp(qr) |  | 36% | name | 2040 | 100 |  |  | Capillary blood |  |
| 9084 | cp-crp-hy | mg/l | 76% | name+unit+values | 12184 | 0 | [3.48, 6.15, 8.73, 12.66, 17.92, 26.04, 38.58, 57.55, 91.94] |  |  |  |
| 9085 | cp-crp-hy |  | 24% | name | 3870 | 100 |  |  |  |  |
| 9086 | cp-crp-lb | mg/l | 66% | name+unit+values | 247 | 0 | [6, 8.5, 12.42, 17.71, 24.78, 34.13, 46.86, 67.12, 92.62] |  |  |  |
| 9087 | cp-crp-lb |  | 34% | name | 128 | 100 |  |  |  |  |
| 9088 | fp-c-pept | nmol/l | 82% | name+unit+values | 3086 | 0.13 | [0.3, 0.46, 0.58, 0.7, 0.83, 0.98, 1.14, 1.37, 1.79] | fP-C-peptidi, proinsuliinin | Fasting plasma |  |
| 9089 | fp-c-pept |  | 18% | name+values | 690 | 100 | [0.24, 0.39, 0.51, 0.67, 0.82, 1.01, 1.26, 1.53, 1.95] | fP-C-peptidi, proinsuliinin | Fasting plasma |  |
| 9090 | fs-c-pept | nmol/l | 95% | name+unit+values | 15089 | 0 | [0.23, 0.4, 0.54, 0.66, 0.79, 0.93, 1.12, 1.4, 1.93] | fS-C-peptidi, proinsuliinin | Fasting serum |  |
| 9091 | fs-c-pept |  | 5% | name | 864 | 100 |  | fS-C-peptidi, proinsuliinin | Fasting serum |  |
| 9092 | fs-jc-pept | nmol/l | 100% | name+unit+values | 167 | 0 | [0.38, 0.53, 0.65, 0.74, 0.85, 0.98, 1.14, 1.36, 1.79] |  | Fasting serum |  |
| 9093 | p-c-pept | nmol/l | 74% | name+unit+values | 1623 | 0 | [0.39, 0.63, 0.84, 1.09, 1.39, 1.75, 2.25, 2.85, 3.73] |  | Plasma |  |
| 9094 | p-c-pept |  | 26% | name+values | 582 | 100 | [0.39, 0.59, 0.76, 0.95, 1.19, 1.45, 1.77, 2.16, 3] |  | Plasma |  |
| 9095 | p-c-pepta | nmol/l | 92% | name+unit+values | 1962 | 0 | [0.57, 0.8, 1.02, 1.23, 1.44, 1.69, 1.97, 2.37, 3.06] | P -C-peptidi, proinsuliinin, aterianjälkeinen | Plasma |  |
| 9096 | p-c-pepta |  | 8% | name+values | 166 | 100 | [0.38, 0.66, 0.99, 1.6, 1.72, 1.93, 2.24, 2.7, 3.74] | P -C-peptidi, proinsuliinin, aterianjälkeinen | Plasma |  |
| 9097 | p-c-peptidi | nmol/l | 89% | name+unit+values | 171 | 0 | [0.45, 0.63, 0.81, 1, 1.24, 1.51, 1.8, 2.3, 3.2] |  | Plasma |  |
| 9098 | p-c-peptidi |  | 11% | name | 21 | 100 |  |  | Plasma |  |
| 9099 | p-c1inh | g/l | 84% | name+unit+values | 186 | 0 | [0.21, 0.23, 0.25, 0.26, 0.28, 0.3, 0.33, 0.34, 0.38] | P -C1-Esteraasin inhibiittori | Plasma |  |
| 9100 | p-c1inh |  | 16% | name | 35 | 100 |  | P -C1-Esteraasin inhibiittori | Plasma |  |
| 9101 | p-c1inhbk | % | 87% | name+unit+values | 1420 | 0.07 | [77.16, 90.39, 98.04, 104.77, 110.86, 117.47, 124.68, 131.53, 144.39] | P -C1-Esteraasin inhibiittori, aktiivisuus | Plasma |  |
| 9102 | p-c1inhbk | form | 1% | name+unit | 11 | 0 |  | P -C1-Esteraasin inhibiittori, aktiivisuus | Plasma |  |
| 9103 | p-c1inhbk |  | 13% | name+values | 207 | 100 | [73, 86.25, 94.53, 101.6, 110, 115, 118.7, 127.77, 139] | P -C1-Esteraasin inhibiittori, aktiivisuus | Plasma |  |
| 9104 | p-ca12-5 | u/ml | 98% | name+unit+values | 29714 | 0 | [8.17, 10.61, 13.28, 16.55, 21.71, 31.29, 52.45, 110.42, 328.04] | P -CA 12-5 antigeeni | Plasma |  |
| 9105 | p-ca12-5 |  | 2% | name+values | 589 | 100 | [7, 8.96, 10, 11.85, 13.35, 16.35, 20.64, 29.91, 53.21] | P -CA 12-5 antigeeni | Plasma |  |
| 9106 | p-ca15-3 | u/ml | 99% | name+unit+values | 16517 | 0 | [9.61, 13.22, 16.67, 20.07, 24.27, 29.6, 39.05, 63.09, 168.72] | P -CA 15-3 antigeeni | Plasma |  |
| 9107 | p-ca15-3 |  | 1% | name | 135 | 100 |  | P -CA 15-3 antigeeni | Plasma |  |
| 9108 | p-ca19-9 | u/ml | 93% | name+unit+values | 27681 | 0 | [5.13, 7.04, 9.22, 12.37, 17.66, 26.92, 46.53, 113.02, 513.07] | P -CA 19-9 antigeeni | Plasma |  |
| 9109 | p-ca19-9 |  | 7% | name+values | 2212 | 100 | [4.07, 6.72, 8.36, 10.75, 14.96, 20.27, 26.89, 40.06, 106.38] | P -CA 19-9 antigeeni | Plasma |  |
| 9110 | p-ck-mb | u/l | 42% | name+unit+values | 109 | 0 | [8, 10, 10.92, 12, 13, 14.37, 16.08, 18.15, 28] | P -Kreatiinikinaasi, MB-alayksikkö | Plasma |  |
| 9111 | p-ck-mb | ug/l | 10% | name+unit | 27 | 0 |  | P -Kreatiinikinaasi, MB-alayksikkö | Plasma |  |
| 9112 | p-ck-mb |  | 48% | name+values | 126 | 100 | [10, 11, 11, 12.32, 13.27, 15, 16.01, 18.1, 20.3] | P -Kreatiinikinaasi, MB-alayksikkö | Plasma |  |
| 9113 | p-ck-mbm | ug/l | 97% | name+unit+values | 76990 | 0 | [1.09, 1.52, 1.93, 2.24, 2.77, 3.38, 4.47, 6.93, 16.86] | P -Kreatiinikinaasi, MB-alayksikkö, massa | Plasma |  |
| 9114 | p-ck-mbm |  | 3% | name | 2370 | 100 |  | P -Kreatiinikinaasi, MB-alayksikkö, massa | Plasma |  |
| 9115 | p-ckmbm | ug/l | 98% | name+unit+values | 372 | 0 | [1, 2, 2, 2.93, 3, 4, 4.92, 6, 8.88] |  | Plasma |  |
| 9116 | p-ckmbm |  | 2% | name | 9 | 100 |  |  | Plasma |  |
| 9117 | p-crp-hoi | mg/l | 75% | name+unit+values | 1173 | 0 | [5, 6.85, 9.48, 13.71, 20.27, 30.55, 44.2, 65.88, 104.84] |  | Plasma |  |
| 9118 | p-crp-hoi |  | 25% | name | 391 | 100 |  |  | Plasma |  |
| 9119 | p-crp-hy | mg/l | 57% | name+unit+values | 9239 | 0 | [6.51, 8.55, 11.56, 15.65, 21.5, 29.73, 42.27, 60.54, 94.03] |  | Plasma |  |
| 9120 | p-crp-hy |  | 43% | name | 6863 | 100 |  |  | Plasma |  |
| 9121 | p-crp-o | mg/l | 54% | name+unit+values | 38640 | 0 | [6.01, 8.14, 11.06, 15.11, 20.94, 29.28, 41.28, 59.55, 92.83] |  | Plasma | Qualitative test (also semi-quantitative) |
| 9122 | p-crp-o |  | 46% | name | 32815 | 100 |  |  | Plasma | Qualitative test (also semi-quantitative) |
| 9123 | p-crp-oma | mg/l | 55% | name+unit+values | 1613 | 0 | [6, 8.17, 11.43, 15.37, 19.86, 26.59, 35.72, 52.43, 83.46] |  | Plasma |  |
| 9124 | p-crp-oma |  | 45% | name | 1306 | 100 |  |  | Plasma |  |
| 9125 | p-crp-p | mg/l | 16% | name+unit+values | 198 | 0 | [1.18, 2.54, 4.73, 8.89, 15.1, 20.7, 30.37, 44.73, 68.28] |  | Plasma | Upright (standing) |
| 9126 | p-crp-p |  | 84% | name+values | 1065 | 100 | [4.46, 6.38, 8.76, 12.77, 17.8, 25.4, 36.67, 54.24, 91.62] |  | Plasma | Upright (standing) |
| 9127 | p-crp-poc | mg/l | 52% | name+unit+values | 281 | 0 | [4.24, 7.55, 12.19, 16.73, 24.29, 35.37, 50.95, 69.91, 100.65] |  | Plasma |  |
| 9128 | p-crp-poc |  | 48% | name+values | 257 | 100 | [1.3, 2.38, 3.75, 5.95, 9.46, 14.85, 27.16, 41.26, 72.5] |  | Plasma |  |
| 9129 | p-crp-päi | mg/l | 95% | name+unit+values | 122 | 0 | [0, 0, 0.85, 1.24, 2.83, 6.05, 11.93, 23.6, 44.85] |  | Plasma |  |
| 9130 | p-crp-päi |  | 5% | name | 7 | 100 |  |  | Plasma |  |
| 9131 | p-crp-vt | mg/l | 67% | name+unit+values | 10010 | 0.01 | [5.1, 7.09, 9.85, 14.07, 19.99, 27.88, 40.22, 59.89, 93.51] |  | Plasma |  |
| 9132 | p-crp-vt |  | 33% | name | 5015 | 100 |  |  | Plasma |  |
| 9133 | p-crphoi | mg/l | 57% | name+unit+values | 6246 | 0 | [6.03, 8.33, 11.66, 16.09, 22.29, 31.43, 44.78, 63.9, 96.64] |  | Plasma |  |
| 9134 | p-crphoi |  | 43% | name+values | 4708 | 100 | [9, 11.95, 15.82, 20.23, 27.43, 32.4, 41, 60.3, 90.28] |  | Plasma |  |
| 9135 | p-crpos | mg/l | 60% | name+unit+values | 386 | 1.55 | [6.7, 9.04, 12.01, 15.42, 20.33, 28.84, 36.52, 56.1, 82.12] |  | Plasma |  |
| 9136 | p-crpos |  | 40% | name | 260 | 100 |  |  | Plasma |  |
| 9137 | p-hcg-tot | iu/l | 43% | name+unit+values | 9307 | 0 | [4.09, 10.68, 31.42, 84.47, 209.82, 494.82, 1192.71, 3554.16, 15110.09] | P -Koriongonadotropiini, totaali | Plasma |  |
| 9138 | p-hcg-tot |  | 57% | name | 12193 | 100 |  | P -Koriongonadotropiini, totaali | Plasma |  |
| 9139 | s-c-pep-a | nmol/l | 85% | name+unit+values | 2840 | 0.04 | [0.29, 0.5, 0.68, 0.86, 1.06, 1.29, 1.58, 1.97, 2.54] |  | Serum |  |
| 9140 | s-c-pep-a |  | 15% | name+values | 508 | 100 | [0.3, 0.52, 0.71, 0.89, 1.07, 1.31, 1.52, 1.9, 2.36] |  | Serum |  |
| 9141 | s-c-pept | nmol/l | 84% | name+unit+values | 1452 | 0 | [0.24, 0.44, 0.62, 0.79, 0.92, 1.12, 1.37, 1.72, 2.31] | S -C-peptidi | Serum |  |
| 9142 | s-c-pept |  | 16% | name+values | 271 | 100 | [0.28, 0.47, 0.63, 0.84, 0.97, 1.16, 1.44, 1.76, 2.45] | S -C-peptidi | Serum |  |
| 9143 | s-c1inh | g/l | 78% | name+unit+values | 1560 | 0.06 | [0.23, 0.25, 0.27, 0.28, 0.3, 0.31, 0.33, 0.35, 0.4] | S -C1-Esteraasin inhibiittori | Serum |  |
| 9144 | s-c1inh |  | 22% | name+values | 429 | 100 | [0.22, 0.25, 0.26, 0.28, 0.29, 0.31, 0.33, 0.35, 0.38] | S -C1-Esteraasin inhibiittori | Serum |  |
| 9145 | s-c1inhbk | % | 96% | name+unit+values | 425 | 0 | [87.27, 95.84, 100.07, 104.14, 106.54, 108.71, 112.59, 116.31, 122] | S -C1-Esteraasin inhibiittori, aktiivisuus | Serum |  |
| 9146 | s-c1inhbk | g/l | 2% | name+unit | 8 | 0 |  | S -C1-Esteraasin inhibiittori, aktiivisuus | Serum |  |
| 9147 | s-c1inhbk |  | 3% | name | 12 | 100 |  | S -C1-Esteraasin inhibiittori, aktiivisuus | Serum |  |
| 9148 | s-ca12-5 | u/ml | 95% | name+unit+values | 43238 | 0 | [7.23, 9.53, 11.79, 14.75, 18.98, 26.26, 41.05, 82.19, 239.23] | S -CA 12-5 antigeeni | Serum |  |
| 9149 | s-ca12-5 |  | 5% | name+values | 2169 | 100 | [8, 9.95, 11.74, 14.05, 16.6, 21.13, 30.4, 60.38, 103.15] | S -CA 12-5 antigeeni | Serum |  |
| 9150 | s-ca15-3 | u/ml | 97% | name+unit+values | 23073 | 0 | [8.05, 10.72, 13.36, 16, 19.22, 23.39, 30.69, 50.91, 133.08] | S -CA 15-3 antigeeni | Serum |  |
| 9151 | s-ca15-3 |  | 3% | name | 825 | 100 |  | S -CA 15-3 antigeeni | Serum |  |
| 9152 | s-ca19-9 | u/ml | 85% | name+unit+values | 44400 | 0 | [3.81, 5.5, 7.65, 10.34, 14.08, 19.73, 30.38, 62.29, 367.62] | S -CA 19-9 antigeeni | Serum |  |
| 9153 | s-ca19-9 |  | 15% | name+values | 7854 | 100 | [3, 4, 5, 6.85, 9.04, 12.81, 17.63, 26.61, 52.11] | S -CA 19-9 antigeeni | Serum |  |
| 9154 | s-ch100 |  | 100% | name | 343 | 100 |  | S -Komplementti, kokonaisaktiivisuus | Serum |  |
| 9155 | s-ch100al | % | 98% | name+unit+values | 1509 | 0 | [46.27, 69.22, 81.13, 88.95, 96.44, 102.87, 108.89, 116.07, 128.48] | S -Komplementti, kokonaishemolyyttinen, vaihtoehtonen tie | Serum |  |
| 9156 | s-ch100al |  | 2% | name | 35 | 100 |  | S -Komplementti, kokonaishemolyyttinen, vaihtoehtonen tie | Serum |  |
| 9157 | s-ch100cl | % | 98% | name+unit+values | 1524 | 0 | [78.34, 91.46, 99.05, 104, 108.74, 112.93, 117.94, 123.75, 133.35] | S -Komplementti, kokonaishemolyyttinen, klassinen tie | Serum |  |
| 9158 | s-ch100cl |  | 2% | name | 36 | 100 |  | S -Komplementti, kokonaishemolyyttinen, klassinen tie | Serum |  |
| 9159 | s-ch100l | % | 97% | name+unit+values | 1353 | 0 | [0.08, 5.28, 24.18, 50.65, 76.01, 94.59, 107.63, 119.25, 133.34] | S -Komplementti, aktiivisuus, lektiinitie | Serum |  |
| 9160 | s-ch100l |  | 3% | name | 37 | 100 |  | S -Komplementti, aktiivisuus, lektiinitie | Serum |  |
| 9161 | s-ch100mbl | % | 95% | name+unit+values | 143 | 0 | [1, 4.79, 27.31, 49.98, 83.33, 103.2, 117.04, 126.14, 145.7] |  | Serum |  |
| 9162 | s-ch100mbl |  | 5% | name | 8 | 100 |  |  | Serum |  |
| 9163 | s-ck-bb | % | 3% | name+unit | 11 | 0 |  |  | Serum |  |
| 9164 | s-ck-bb | u/l | 18% | name+unit+values | 62 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Serum |  |
| 9165 | s-ck-bb |  | 78% | name | 263 | 100 |  |  | Serum |  |
| 9166 | s-ck-mb | % | 26% | name+unit+values | 100 | 0 | [1, 1, 1, 2, 2, 2.13, 3, 4, 6] | S -Kreatiinikinaasi, MB-alayksikkö | Serum |  |
| 9167 | s-ck-mb | u/l | 57% | name+unit+values | 223 | 0 | [0, 0, 2, 3, 3.84, 4.25, 5.65, 7.45, 11.43] | S -Kreatiinikinaasi, MB-alayksikkö | Serum |  |
| 9168 | s-ck-mb |  | 17% | name | 68 | 100 |  | S -Kreatiinikinaasi, MB-alayksikkö | Serum |  |
| 9169 | s-ck-mm | % | 34% | name+unit+values | 113 | 0 | [91, 94.7, 96.25, 97, 98, 98, 99, 99, 99.85] |  | Serum |  |
| 9170 | s-ck-mm | u/l | 51% | name+unit+values | 171 | 0 | [55.93, 76.67, 106.93, 142.02, 206.11, 274.4, 361.3, 449.47, 653.55] |  | Serum |  |
| 9171 | s-ck-mm |  | 15% | name | 50 | 100 |  |  | Serum |  |
| 9172 | s-crp-o | form | 4% | name+unit+values | 303 | 0 | [5, 7.58, 11.67, 16.13, 20.49, 28.31, 39.19, 56.35, 80.5] | S -C-reaktiivinen proteiini (kval) | Serum | Qualitative test (also semi-quantitative) |
| 9173 | s-crp-o | mg/l | 54% | name+unit+values | 4270 | 0 | [5, 5.03, 7.05, 9.78, 13.63, 19.21, 29.09, 45.02, 77.03] | S -C-reaktiivinen proteiini (kval) | Serum | Qualitative test (also semi-quantitative) |
| 9174 | s-crp-o | u/ml | 0% | name+unit | 10 | 0 |  | S -C-reaktiivinen proteiini (kval) | Serum | Qualitative test (also semi-quantitative) |
| 9175 | s-crp-o |  | 42% | name | 3270 | 100 |  | S -C-reaktiivinen proteiini (kval) | Serum | Qualitative test (also semi-quantitative) |
| 9176 | s-hcg-b | u/l | 30% | name+unit | 58 | 0 |  | S -Koriongonadotropiini-B-alayksikkö | Serum |  |
| 9177 | s-hcg-b |  | 70% | name | 134 | 100 |  | S -Koriongonadotropiini-B-alayksikkö | Serum |  |
| 9178 | s-hcg-b-v | pmol/l | 5% | name+unit+values | 1133 | 0.26 | [1.11, 1.38, 2.02, 3.24, 6.39, 20.3, 53.95, 143.27, 1665.94] | S -Koriongonadotropiini-B-alayksikkö, vapaa | Serum | Free or unconjugated |
| 9179 | s-hcg-b-v | ug/l | 84% | name+unit+values | 18166 | 0 | [22.37, 30.52, 37.9, 45.37, 53.7, 63.59, 75.86, 93.4, 123.74] | S -Koriongonadotropiini-B-alayksikkö, vapaa | Serum | Free or unconjugated |
| 9180 | s-hcg-b-v |  | 10% | name | 2245 | 100 |  | S -Koriongonadotropiini-B-alayksikkö, vapaa | Serum | Free or unconjugated |
| 9181 | s-hcg-b/d | ug/l | 81% | name+unit+values | 203 | 0 | [6.98, 9.79, 12.24, 14.11, 16.55, 20.08, 23.61, 27.98, 38.24] |  | Serum |  |
| 9182 | s-hcg-b/d |  | 19% | name | 47 | 100 |  |  | Serum |  |
| 9183 | s-hcg-o |  | 100% | name | 11062 | 100 |  | S -Koriongonadotropiini (kval) | Serum | Qualitative test (also semi-quantitative) |
| 9184 | s-hcg-tot | iu/l | 12% | name+unit | 49 | 0 |  | S -Koriongonadotropiini, totaali | Serum |  |
| 9185 | s-hcg-tot | u/l | 33% | name+unit+values | 131 | 0 | [2.3, 3.14, 4.69, 14.27, 48.54, 313.48, 844.4, 3876, 8300] | S -Koriongonadotropiini, totaali | Serum |  |
| 9186 | s-hcg-tot |  | 55% | name | 220 | 100 |  | S -Koriongonadotropiini, totaali | Serum |  |
| 9187 | s-hcgbsuh | % | 9% | name+unit | 9 | 0 |  |  | Serum |  |
| 9188 | s-hcgbsuh |  | 91% | name | 93 | 100 |  |  | Serum |  |
| 9189 | s-hcgbv | ug/l | 82% | name+unit+values | 3403 | 0.06 | [23.28, 33.06, 41.4, 49.13, 57.97, 68.15, 80.14, 98.96, 129.15] |  | Serum |  |
| 9190 | s-hcgbv |  | 18% | name+values | 762 | 100 | [26.54, 34.48, 42.52, 49.78, 58, 66.21, 79.65, 95.49, 123.63] |  | Serum |  |
| 9191 | s-hcgbv/d | ug/l | 99% | name+unit+values | 19561 | 0 | [22.41, 30.99, 38.46, 45.94, 54.48, 64.42, 77.11, 93.56, 124.02] |  | Serum |  |
| 9192 | s-hcgbv/d |  | 1% | name | 116 | 100 |  |  | Serum |  |
| 9193 | s-hcgbvtr | ug/l | 100% | name+unit+values | 1332 | 0 | [21.35, 30.24, 38.52, 46.74, 57.22, 69.04, 82.94, 101.43, 133.78] |  | Serum |  |
| 9194 | s-hcgbvtr |  | 0% | name | 6 | 100 |  |  | Serum |  |
| 9195 | s-hcgxmom | mom | 100% | name+unit+values | 478 | 0 | [0.45, 0.59, 0.71, 0.83, 1, 1.2, 1.38, 1.72, 2.16] |  | Serum |  |
| 9196 | u-hcg-o |  | 100% | name | 15029 | 100 |  | U -Koriongonadotropiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 9197 | u-hcgo-lb |  | 100% | name | 123 | 100 |  |  | Urine |  |

