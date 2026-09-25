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
Here is group 110 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 8999 | b-b-cd19 | e6/l | 20% | name+unit+values | 913 | 0 | [10.41, 31.05, 55.36, 87.14, 120.42, 155.29, 201.58, 263.7, 407.08] |  | Blood |  |
| 9000 | b-b-cd19 | e9/l | 68% | name+unit+values | 3083 | 0 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.29, 0.48] |  | Blood |  |
| 9001 | b-b-cd19 |  | 12% | name+values | 569 | 89.28 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.31, 0.47] |  | Blood |  |
| 9002 | b-cd16/56 | e6/l | 0% | name+unit | 12 | 0 |  |  | Blood |  |
| 9003 | b-cd16/56 | e9/l | 96% | name+unit+values | 2606 | 0.65 | [0.06, 0.09, 0.12, 0.15, 0.18, 0.22, 0.26, 0.33, 0.44] |  | Blood |  |
| 9004 | b-cd16/56 |  | 4% | name | 108 | 84.26 |  |  | Blood |  |
| 9005 | b-cd16/cd56 | e9/l | 95% | name+unit+values | 263 | 0 | [0.09, 0.12, 0.15, 0.17, 0.21, 0.24, 0.3, 0.36, 0.44] |  | Blood |  |
| 9006 | b-cd16/cd56 |  | 5% | name | 15 | 100 |  |  | Blood |  |
| 9007 | b-cd19 | e6/l | 56% | name+unit+values | 3891 | 0 | [0, 1.97, 16.17, 41.05, 70.27, 108.04, 158.42, 221.57, 336.97] |  | Blood |  |
| 9008 | b-cd19 | e9/l | 41% | name+unit+values | 2870 | 0.59 | [0, 0, 0.01, 0.03, 0.06, 0.09, 0.14, 0.19, 0.29] |  | Blood |  |
| 9009 | b-cd19 |  | 3% | name | 175 | 66.29 |  |  | Blood |  |
| 9010 | b-cd3 | e6/l | 56% | name+unit | 3892 | 0 |  |  | Blood |  |
| 9011 | b-cd3 | e9/l | 41% | name+unit | 2868 | 0.59 |  |  | Blood |  |
| 9012 | b-cd3 |  | 3% | name | 204 | 71.57 |  |  | Blood |  |
| 9013 | b-cd34 | e6/l | 88% | name+unit+values | 193 | 0 | [5.27, 13.75, 20.31, 28.86, 37.69, 50.47, 63.07, 93.98, 156.93] |  | Blood |  |
| 9014 | b-cd34 |  | 12% | name | 27 | 29.63 |  |  | Blood |  |
| 9015 | b-cd4 | e6/l | 56% | name+unit+values | 3893 | 0 | [134.07, 213.38, 284.14, 381.8, 505.45, 647.7, 819.98, 1038.04, 1335.05] |  | Blood |  |
| 9016 | b-cd4 | e9/l | 41% | name+unit+values | 2870 | 0.59 | [0.14, 0.2, 0.25, 0.32, 0.4, 0.51, 0.63, 0.8, 1.07] |  | Blood |  |
| 9017 | b-cd4 |  | 2% | name | 172 | 66.28 |  |  | Blood |  |
| 9018 | b-cd8 | e6/l | 56% | name+unit+values | 3892 | 0 | [117.75, 200.41, 277.17, 351.98, 433.16, 541.85, 672.5, 850.74, 1214.03] |  | Blood |  |
| 9019 | b-cd8 | e9/l | 41% | name+unit+values | 2870 | 0.59 | [0.11, 0.16, 0.23, 0.29, 0.36, 0.46, 0.57, 0.73, 1] |  | Blood |  |
| 9020 | b-cd8 |  | 2% | name | 172 | 66.28 |  |  | Blood |  |
| 9021 | b-lcd34 | e6/l | 32% | name+unit+values | 251 | 0 | [3, 7.11, 11.11, 14.14, 17.55, 23.82, 31.86, 44, 64.2] | B -Leukosyytit, CD34 alaluokka | Blood |  |
| 9022 | b-lcd34 | e9/l | 60% | name+unit+values | 475 | 0 | [0, 0.01, 0.02, 0.03, 0.03, 0.04, 0.06, 0.09, 0.13] | B -Leukosyytit, CD34 alaluokka | Blood |  |
| 9023 | b-lcd34 |  | 8% | name | 66 | 100 |  | B -Leukosyytit, CD34 alaluokka | Blood |  |
| 9024 | b-lycd4 |  | 100% | name | 496 | 100 |  | B -Lymfosyytti CD4-alaluokka | Blood |  |
| 9025 | b-t-cd3 | e6/l | 28% | name+unit | 1174 | 0 |  |  | Blood |  |
| 9026 | b-t-cd3 | e9/l | 65% | name+unit | 2692 | 0 |  |  | Blood |  |
| 9027 | b-t-cd3 |  | 7% | name | 304 | 81.91 |  |  | Blood |  |
| 9028 | b-t-cd4 | e6/l | 20% | name+unit+values | 1609 | 0 | [168.06, 247.56, 335.09, 433.05, 551.26, 672.04, 816.88, 957.34, 1254.62] |  | Blood |  |
| 9029 | b-t-cd4 | e9/l | 75% | name+unit+values | 6105 | 0 | [0.16, 0.25, 0.34, 0.43, 0.52, 0.64, 0.79, 0.96, 1.28] |  | Blood |  |
| 9030 | b-t-cd4 |  | 6% | name+values | 475 | 69.89 | [0.2, 0.26, 0.34, 0.42, 0.55, 0.68, 0.8, 0.95, 1.29] |  | Blood |  |
| 9031 | b-t-cd8 | e6/l | 28% | name+unit+values | 1174 | 0 | [141.94, 210.82, 289.62, 366.11, 450.98, 530.13, 639.55, 796.16, 1179.47] |  | Blood |  |
| 9032 | b-t-cd8 | e9/l | 65% | name+unit+values | 2753 | 0 | [0.14, 0.21, 0.27, 0.35, 0.43, 0.52, 0.65, 0.83, 1.1] |  | Blood |  |
| 9033 | b-t-cd8 |  | 7% | name | 311 | 79.42 |  |  | Blood |  |
| 9034 | bl-cd4/cd8 | form | 32% | name+unit | 42 | 100 |  |  | Bronchoalveolar lavage |  |
| 9035 | bl-cd4/cd8 |  | 68% | name | 91 | 100 |  |  | Bronchoalveolar lavage |  |
| 9036 | cd4/cd8 |  | 100% | name+values | 3940 | 0.23 | [0.29, 0.47, 0.68, 0.91, 1.2, 1.57, 1.94, 2.45, 3.26] |  |  |  |
| 9037 | l-cd34 | % | 92% | name+unit+values | 481 | 0 | [0.05, 0.08, 0.1, 0.13, 0.16, 0.2, 0.25, 0.32, 0.61] |  | Leukocyte |  |
| 9038 | l-cd34 |  | 8% | name | 41 | 100 |  |  | Leukocyte |  |
| 9039 | la-cd34 | e6/kg | 28% | name+unit+values | 156 | 0 | [0.6, 0.9, 1.18, 1.41, 1.69, 2.1, 2.53, 3.4, 4.94] |  |  |  |
| 9040 | la-cd34 | e9/l | 72% | name+unit+values | 393 | 0 | [0.41, 0.56, 0.72, 0.84, 1.03, 1.27, 1.77, 2.36, 3.2] |  |  |  |
| 9041 | la-cd34-ks |  | 100% | name | 395 | 100 |  |  |  |  |
| 9042 | la-cd34-os | % | 100% | name+unit+values | 393 | 0 | [0.22, 0.3, 0.39, 0.49, 0.59, 0.69, 0.84, 1.12, 1.67] |  |  |  |
| 9043 | la-t-cd3 | e9/l | 96% | name+unit | 149 | 0 |  |  |  |  |
| 9044 | la-t-cd3 |  | 4% | name | 6 | 16.67 |  |  |  |  |
| 9045 | la-t-cd4 | e9/l | 96% | name+unit | 149 | 0 |  |  |  |  |
| 9046 | la-t-cd4 |  | 4% | name | 6 | 16.67 |  |  |  |  |
| 9047 | la-t-cd8 | e9/l | 96% | name+unit | 149 | 0 |  |  |  |  |
| 9048 | la-t-cd8 |  | 4% | name | 6 | 16.67 |  |  |  |  |
| 9049 | ly-b-cd19 | % | 61% | name+unit+values | 1504 | 0 | [0, 0, 0.45, 2.91, 5.54, 7.86, 10.24, 13.34, 18.94] |  | Lymphocyte |  |
| 9050 | ly-b-cd19 |  | 39% | name | 950 | 99.05 |  |  | Lymphocyte |  |
| 9051 | ly-cd16/56 | % | 97% | name+unit+values | 3462 | 0.49 | [5.28, 8.01, 10.25, 12.46, 15.08, 18.07, 21.55, 26.37, 33.4] |  | Lymphocyte |  |
| 9052 | ly-cd16/56 |  | 3% | name | 107 | 86.92 |  |  | Lymphocyte |  |
| 9053 | ly-cd16/cd56 | % | 95% | name+unit+values | 262 | 0 | [5.52, 8.16, 10.06, 12.71, 14.93, 17.65, 20.63, 27.5, 36.58] |  | Lymphocyte |  |
| 9054 | ly-cd16/cd56 |  | 5% | name | 15 | 100 |  |  | Lymphocyte |  |
| 9055 | ly-cd19 | % | 97% | name+unit+values | 3462 | 0.49 | [0, 0, 1.17, 3.24, 5.55, 8.08, 10.86, 14.11, 20.27] |  | Lymphocyte |  |
| 9056 | ly-cd19 |  | 3% | name | 107 | 85.98 |  |  | Lymphocyte |  |
| 9057 | ly-cd19-b | % | 99% | name+unit+values | 2507 | 0 | [0, 0, 1, 3.95, 7.56, 10.5, 13.61, 17.58, 25.6] |  | Lymphocyte |  |
| 9058 | ly-cd19-b |  | 1% | name | 19 | 100 |  |  | Lymphocyte |  |
| 9059 | ly-cd3 | % | 97% | name+unit+values | 3726 | 0.46 | [52.12, 61.25, 67.07, 71.15, 74.98, 78.39, 81.66, 85.36, 89.48] |  | Lymphocyte |  |
| 9060 | ly-cd3 |  | 3% | name | 122 | 87.7 |  |  | Lymphocyte |  |
| 9061 | ly-cd4 | % | 97% | name+unit+values | 3726 | 0.46 | [16.32, 22.56, 27.91, 32.59, 37.02, 41.75, 46.47, 51.76, 58.99] |  | Lymphocyte |  |
| 9062 | ly-cd4 |  | 3% | name | 122 | 87.7 |  |  | Lymphocyte |  |
| 9063 | ly-cd4+8+ | % | 35% | name+unit | 41 | 41.46 |  |  | Lymphocyte |  |
| 9064 | ly-cd4+8+ |  | 65% | name | 75 | 100 |  |  | Lymphocyte |  |
| 9065 | ly-cd4-8- | % | 73% | name+unit+values | 207 | 8.21 | [7, 8, 8, 8.88, 9.82, 10.9, 12, 14, 16] |  | Lymphocyte |  |
| 9066 | ly-cd4-8- |  | 27% | name | 77 | 100 |  |  | Lymphocyte |  |
| 9067 | ly-cd4-t | % | 96% | name+unit+values | 4576 | 0 | [15.23, 21.8, 27.31, 31.42, 35.47, 39.26, 43.26, 48.23, 54.7] |  | Lymphocyte |  |
| 9068 | ly-cd4-t |  | 4% | name+values | 170 | 22.94 | [17.53, 21.58, 24.78, 29.15, 33.2, 38.25, 41.67, 47.37, 52.57] |  | Lymphocyte |  |
| 9069 | ly-cd4/cd8 |  | 100% | name+values | 2752 | 4.18 | [0.37, 0.55, 0.75, 0.96, 1.18, 1.48, 1.83, 2.29, 3.23] | Ly-Auttaja- ja tappajasolujen suhde, immunofenotyypitys | Lymphocyte |  |
| 9070 | ly-cd4/cd8suhde |  | 100% | name+values | 278 | 5.4 | [0.5, 0.76, 1.02, 1.29, 1.66, 1.95, 2.26, 2.73, 3.97] |  | Lymphocyte |  |
| 9071 | ly-cd8 | % | 97% | name+unit+values | 3725 | 0.46 | [14.46, 19.13, 22.75, 26.46, 30.35, 34.98, 40.06, 46.74, 56.02] |  | Lymphocyte |  |
| 9072 | ly-cd8 |  | 3% | name | 122 | 87.7 |  |  | Lymphocyte |  |
| 9073 | ly-t-cd3 | % | 94% | name+unit+values | 3926 | 0 | [56.23, 64.92, 70.33, 74.35, 77.57, 80.54, 84.02, 87.72, 92.04] |  | Lymphocyte |  |
| 9074 | ly-t-cd3 |  | 6% | name | 264 | 98.48 |  |  | Lymphocyte |  |
| 9075 | ly-t-cd4 | % | 34% | name+unit+values | 2006 | 0 | [18.72, 24.57, 29.84, 34.47, 38.67, 43.22, 47.75, 52.18, 58.04] | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  |
| 9076 | ly-t-cd4 |  | 66% | name | 3875 | 99.92 |  | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  |
| 9077 | ly-t-cd4. | % | 98% | name+unit+values | 1462 | 0 | [18.57, 26.32, 32.42, 36.77, 41.27, 46.47, 51.47, 56.35, 63.05] |  | Lymphocyte |  |
| 9078 | ly-t-cd4. |  | 2% | name | 36 | 72.22 |  |  | Lymphocyte |  |
| 9079 | ly-t-cd4/8 | ratio | 89% | name+unit+values | 1816 | 0 | [0.6, 0.8, 0.99, 1.23, 1.56, 1.85, 2.06, 2.47, 3.19] |  | Lymphocyte |  |
| 9080 | ly-t-cd4/8 |  | 11% | name+values | 224 | 100 | [0.48, 0.79, 1.06, 1.31, 1.55, 1.83, 2.13, 2.62, 3.69] |  | Lymphocyte |  |
| 9081 | ly-t-cd8 | % | 92% | name+unit+values | 2895 | 0 | [14.95, 19.45, 23.24, 27.01, 30.29, 33.79, 38.05, 43.59, 52.29] | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  |
| 9082 | ly-t-cd8 |  | 8% | name | 245 | 99.59 |  | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  |
| 9083 | ly-tcd4/8. |  | 100% | name+values | 2179 | 0.83 | [0.48, 0.75, 1, 1.21, 1.42, 1.69, 2, 2.51, 3.27] |  | Lymphocyte |  |
| 9084 | ly-tt-cd8 | % | 100% | name+unit+values | 1219 | 0 | [13.33, 17.86, 21.01, 24.35, 28, 31.32, 36.22, 42.56, 52.88] |  | Lymphocyte |  |
| 9085 | ly-tt-cd8 |  | 0% | name | 5 | 40 |  |  | Lymphocyte |  |
| 9086 | s-gt-cdt | % | 0% | name+unit | 13 | 0 |  |  | Serum |  |
| 9087 | s-gt-cdt |  | 100% | name+values | 2807 | 3.35 | [2.6, 2.87, 3.04, 3.25, 3.47, 3.7, 3.96, 4.27, 4.86] |  | Serum |  |
| 9088 | so-t-cd3 | % | 96% | name+unit+values | 149 | 0 | [16.66, 19.73, 21.87, 23.49, 24.84, 27.82, 29.85, 33.41, 49.51] |  |  |  |
| 9089 | so-t-cd3 |  | 4% | name | 6 | 16.67 |  |  |  |  |
| 9090 | so-t-cd4 | % | 96% | name+unit+values | 149 | 0 | [9.42, 10.93, 12.3, 13.53, 14.67, 15.99, 17.4, 19.67, 23.42] |  |  |  |
| 9091 | so-t-cd4 |  | 4% | name | 6 | 16.67 |  |  |  |  |
| 9092 | so-t-cd8 | % | 96% | name+unit+values | 149 | 0 | [5.87, 7, 7.83, 8.57, 9.8, 10.57, 12.18, 14.02, 21.4] |  |  |  |
| 9093 | so-t-cd8 |  | 4% | name | 6 | 16.67 |  |  |  |  |

