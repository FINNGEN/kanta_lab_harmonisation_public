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
Here is group 44 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 2677 | -ana | titre | 11% | name+unit | 21 | 0 |  | -Tuma, vasta-aineet |  |  |
| 2678 | -ana |  | 89% | name | 169 | 100 |  | -Tuma, vasta-aineet |  |  |
| 2679 | b-adp | auc | 8% | name+unit | 28 | 0 |  |  | Blood |  |
| 2680 | b-adp |  | 92% | name | 340 | 100 |  |  | Blood |  |
| 2681 | b-aspi | auc | 8% | name+unit | 28 | 0 |  |  | Blood |  |
| 2682 | b-aspi |  | 92% | name | 340 | 100 |  |  | Blood |  |
| 2683 | b-vasp | % | 71% | name+unit+values | 165 | 0.61 | [15.75, 23.9, 29.38, 35.29, 42.07, 50.51, 57, 61.68, 75.5] |  | Blood |  |
| 2684 | b-vasp |  | 29% | name | 67 | 100 |  |  | Blood |  |
| 2685 | du-5hiaa | umol | 49% | name+unit+values | 332 | 0 | [14.84, 17.93, 19.97, 21.95, 24.09, 26.9, 29.86, 35.62, 54.61] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  |
| 2686 | du-5hiaa | umol/24h | 26% | name+unit+values | 175 | 0 | [12.52, 16.28, 19.6, 22.92, 25.58, 30.54, 36.9, 47, 66.84] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  |
| 2687 | du-5hiaa | umol/l | 4% | name+unit | 25 | 0 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  |
| 2688 | du-5hiaa |  | 22% | name | 147 | 100 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  |
| 2689 | fs-ace | u/l | 91% | name+unit+values | 33401 | 0 | [20.01, 26.72, 31.85, 36.77, 41.74, 47.12, 53.86, 62.72, 77.07] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  |
| 2690 | fs-ace |  | 9% | name+values | 3291 | 100 | [11.74, 22.42, 28.98, 33.88, 39.56, 44.46, 50.35, 61.63, 75.64] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  |
| 2691 | fs-ffa | mmol/l | 90% | name+unit+values | 170 | 0.59 | [0.18, 0.25, 0.3, 0.38, 0.42, 0.5, 0.56, 0.69, 0.9] | fS-Rasvahapot, vapaat | Fasting serum |  |
| 2692 | fs-ffa |  | 10% | name | 19 | 100 |  | fS-Rasvahapot, vapaat | Fasting serum |  |
| 2693 | p-hae |  | 100% | name | 461 | 100 |  |  | Plasma |  |
| 2694 | p-hcg | iu/l | 3% | name+unit+values | 858 | 0 | [3.48, 10.49, 27.21, 71.9, 194.98, 530.06, 1481.95, 5270.49, 17544.85] | P -Koriongonadotropiini | Plasma |  |
| 2695 | p-hcg | u/l | 45% | name+unit+values | 13156 | 0 | [0, 1.47, 5, 22.74, 99.28, 332.77, 1072.06, 3554.69, 18400.55] | P -Koriongonadotropiini | Plasma |  |
| 2696 | p-hcg |  | 52% | name+values | 15471 | 100 | [2.3, 12.1, 34.61, 97.94, 275.98, 842.13, 2833.73, 7394.19, 31975.3] | P -Koriongonadotropiini | Plasma |  |
| 2697 | p-he4 | pmol/l | 100% | name+unit+values | 2505 | 0 | [38.56, 42.77, 46.8, 51.21, 56.04, 62.65, 72.66, 92.27, 148.13] | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  |
| 2698 | p-he4 |  | 0% | name | 6 | 100 |  | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  |
| 2699 | p-hepg |  | 100% | name | 107 | 100 |  |  | Plasma |  |
| 2700 | p-hok |  | 100% | name | 397 | 100 |  |  | Plasma |  |
| 2701 | p-shbg | nmol/l | 51% | name+unit+values | 791 | 0 | [18.05, 23.19, 26.53, 30.08, 34.17, 38.11, 43.33, 50.43, 63.58] |  | Plasma |  |
| 2702 | p-shbg |  | 49% | name+values | 758 | 100 | [17.44, 21.87, 26.42, 30.98, 35.64, 41.79, 47.18, 56.49, 73.47] |  | Plasma |  |
| 2703 | s-5hiaa | nmol/l | 99% | name+unit+values | 10313 | 0 | [44.24, 52.84, 60.81, 69.7, 80.24, 95.18, 123.37, 200.27, 541.18] | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  |
| 2704 | s-5hiaa |  | 1% | name | 153 | 100 |  | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  |
| 2705 | s-ace | u/l | 74% | name+unit+values | 2203 | 0 | [19.71, 28.37, 33.66, 38.43, 43.04, 48.17, 53.91, 61.65, 75.1] |  | Serum |  |
| 2706 | s-ace |  | 26% | name+values | 769 | 100 | [21.46, 30.53, 35.19, 38.74, 43.02, 46.74, 52.18, 58.12, 66.5] |  | Serum |  |
| 2707 | s-ada | u/l | 94% | name+unit+values | 4147 | 0 | [7, 8.11, 9.17, 10.37, 11.58, 13.01, 14.79, 17.22, 21.44] | S -Adenosiinideaminaasi | Serum |  |
| 2708 | s-ada |  | 6% | name | 259 | 100 |  | S -Adenosiinideaminaasi | Serum |  |
| 2709 | s-afp | u/ml | 74% | name+unit+values | 18186 | 0.02 | [1.8, 2.09, 2.61, 3.01, 3.61, 4.34, 5.57, 7.78, 25.89] | S -Alfa-1-fetoproteiini | Serum |  |
| 2710 | s-afp | ug/l | 10% | name+unit+values | 2515 | 0.2 | [2, 2.19, 3, 3.92, 4.18, 5.4, 6.88, 9.63, 20.48] | S -Alfa-1-fetoproteiini | Serum |  |
| 2711 | s-afp |  | 16% | name+values | 4026 | 100 | [2, 2.04, 3, 3.01, 3.97, 4, 5, 6.37, 9.78] | S -Alfa-1-fetoproteiini | Serum |  |
| 2712 | s-afp/d | u/ml | 83% | name+unit+values | 234 | 0 | [15.07, 17.36, 19.66, 21.92, 23.81, 26.18, 29.19, 33.19, 39.28] |  | Serum |  |
| 2713 | s-afp/d |  | 17% | name | 49 | 100 |  |  | Serum |  |
| 2714 | s-amh | ug/l | 88% | name+unit+values | 9545 | 0 | [0.41, 0.85, 1.31, 1.76, 2.25, 2.87, 3.65, 4.79, 7.19] | S -Anti-Muller hormoni | Serum |  |
| 2715 | s-amh |  | 12% | name+values | 1328 | 100 | [0.75, 1.12, 1.6, 2, 2.6, 3.25, 3.89, 5.15, 6.81] | S -Anti-Muller hormoni | Serum |  |
| 2716 | s-ami | mg/l | 49% | name+unit+values | 294 | 0 | [1.26, 1.45, 1.68, 2.02, 2.66, 3.31, 4.38, 6.23, 11.11] | S -Amikasiini | Serum |  |
| 2717 | s-ami |  | 51% | name | 308 | 100 |  | S -Amikasiini | Serum |  |
| 2718 | s-ana | titre | 26% | name+unit+values | 21493 | 0 | [80, 159.91, 214.87, 320, 320, 320, 522.82, 1051.43, 1384.04] | S -Tuma, vasta-aineet | Serum |  |
| 2719 | s-ana |  | 74% | name | 62781 | 100 |  | S -Tuma, vasta-aineet | Serum |  |
| 2720 | s-asca | u/ml | 22% | name+unit | 89 | 0 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  |
| 2721 | s-asca |  | 78% | name | 316 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  |
| 2722 | s-ast | iu/ml | 44% | name+unit+values | 2404 | 0 | [53.94, 68.05, 79.53, 94.83, 113.69, 141.82, 180.88, 246.57, 415.18] | S -Antistreptolysiini | Serum |  |
| 2723 | s-ast | titre | 0% | name+unit | 7 | 0 |  | S -Antistreptolysiini | Serum |  |
| 2724 | s-ast | u/ml | 8% | name+unit+values | 408 | 0 | [30.69, 40.68, 53.25, 70.32, 94.82, 134.06, 198.84, 380.5, 767.49] | S -Antistreptolysiini | Serum |  |
| 2725 | s-ast |  | 48% | name+values | 2603 | 100 | [61.25, 72.75, 89.71, 105.94, 136, 193.17, 248, 404.5, 714.67] | S -Antistreptolysiini | Serum |  |
| 2726 | s-asta | iu/ml | 10% | name+unit+values | 256 | 0 | [2, 2, 2, 2, 3, 4, 4.2, 6, 8] | S -Antistafylolysiini | Serum |  |
| 2727 | s-asta | u/ml | 0% | name+unit | 10 | 0 |  | S -Antistafylolysiini | Serum |  |
| 2728 | s-asta |  | 89% | name | 2266 | 100 |  | S -Antistafylolysiini | Serum |  |
| 2729 | s-br | mmol/l | 100% | name+unit | 130 | 2.31 |  | S -Bromidi | Serum |  |
| 2730 | s-dhea | nmol/l | 84% | name+unit+values | 398 | 0 | [2.51, 3.94, 5.32, 7.57, 10.22, 13.71, 18.17, 23.83, 35.37] | S -Dehydroepiandrosteroni | Serum |  |
| 2731 | s-dhea |  | 16% | name | 74 | 100 |  | S -Dehydroepiandrosteroni | Serum |  |
| 2732 | s-dheas | umol/l | 92% | name+unit+values | 3797 | 0 | [1.08, 1.91, 2.83, 3.72, 4.53, 5.45, 6.59, 8, 10.09] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  |
| 2733 | s-dheas |  | 8% | name+values | 331 | 100 | [1.32, 2.02, 2.87, 3.83, 4.89, 5.72, 6.85, 7.86, 9.48] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  |
| 2734 | s-e1 | pmol/l | 80% | name+unit+values | 123 | 0 | [71.12, 113.75, 135.4, 184.19, 225.67, 280.98, 347.05, 435.31, 614] | S -Estroni | Serum |  |
| 2735 | s-e1 |  | 20% | name | 30 | 100 |  | S -Estroni | Serum |  |
| 2736 | s-e2 | nmol/l | 81% | name+unit+values | 10351 | 0 | [0.07, 0.1, 0.13, 0.16, 0.2, 0.27, 0.37, 0.54, 0.98] | S -Estradioli | Serum |  |
| 2737 | s-e2 |  | 19% | name+values | 2381 | 100 | [0.07, 0.1, 0.11, 0.14, 0.17, 0.2, 0.26, 0.37, 0.59] | S -Estradioli | Serum |  |
| 2738 | s-ema |  | 100% | name | 2245 | 100 |  | S -Endomysium, vasta-aineet | Serum |  |
| 2739 | s-ena |  | 100% | name+values | 1469 | 100 | [0.1, 0.1, 0.1, 0.2, 0.2, 0.22, 0.3, 0.5, 1.15] |  | Serum |  |
| 2740 | s-enal |  | 100% | name | 832 | 100 |  |  | Serum |  |
| 2741 | s-ffa | mmol/l | 100% | name+unit+values | 518 | 0 | [0.03, 0.04, 0.08, 0.13, 0.18, 0.28, 0.44, 0.57, 0.75] |  | Serum |  |
| 2742 | s-gen | mg/l | 52% | name+unit+values | 373 | 0.27 | [0.5, 0.66, 0.76, 0.89, 0.99, 1.17, 1.47, 2.03, 3.89] | S -Gentamysiini | Serum |  |
| 2743 | s-gen |  | 48% | name | 339 | 100 |  | S -Gentamysiini | Serum |  |
| 2744 | s-hae |  | 100% | name | 751 | 100 |  |  | Serum |  |
| 2745 | s-hbe |  | 100% | name | 347 | 100 |  |  | Serum |  |
| 2746 | s-hcg | iu/l | 9% | name+unit+values | 2181 | 0 | [2.03, 3.95, 10.46, 38.54, 127.28, 369.25, 940.92, 2982.24, 13488.73] | S -Koriongonadotropiini | Serum |  |
| 2747 | s-hcg | u/l | 24% | name+unit+values | 5914 | 0.08 | [5.54, 20.85, 66.85, 168.4, 361.64, 670.15, 1496.54, 4307.97, 16838.39] | S -Koriongonadotropiini | Serum |  |
| 2748 | s-hcg |  | 67% | name+values | 16592 | 100 | [8.52, 18.24, 40.62, 113.39, 319.93, 924.91, 3362.22, 10372.34, 38864.49] | S -Koriongonadotropiini | Serum |  |
| 2749 | s-he4 | pmol/l | 96% | name+unit+values | 11193 | 0 | [31.8, 37.2, 41.86, 46.93, 53.05, 60.93, 73.32, 98.06, 184.4] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  |
| 2750 | s-he4 |  | 4% | name+values | 420 | 100 | [28.89, 32.42, 35.14, 39.73, 42.86, 45.92, 51.27, 61.15, 81.37] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  |
| 2751 | s-kem |  | 100% | name | 1473 | 100 |  |  | Serum |  |
| 2752 | s-kyhemag | titre | 18% | name+unit+values | 180 | 0 | [8, 16, 16, 28.54, 32, 64, 163.55, 483.7, 1556.48] | S -Kylmähemagglutiniinit | Serum |  |
| 2753 | s-kyhemag |  | 82% | name | 826 | 100 |  | S -Kylmähemagglutiniinit | Serum |  |
| 2754 | s-shbg | nmol/l | 98% | name+unit+values | 29338 | 0 | [16.87, 21.37, 25.24, 29.25, 33.23, 37.98, 43.66, 51.48, 65.24] | S -Sukupuolihormoneja sitova globuliini | Serum |  |
| 2755 | s-shbg |  | 2% | name | 614 | 100 |  | S -Sukupuolihormoneja sitova globuliini | Serum |  |
| 2756 | s-tati | nmol/l | 51% | name+unit+values | 551 | 0 | [1.3, 1.48, 1.65, 1.82, 2.09, 2.38, 2.76, 3.46, 6.22] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  |
| 2757 | s-tati | ug/l | 41% | name+unit+values | 446 | 0 | [6.73, 8.09, 9.02, 9.95, 11.09, 12.18, 13.95, 17.1, 31.19] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  |
| 2758 | s-tati |  | 8% | name | 86 | 100 |  | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  |
| 2759 | s-van | mg/l | 96% | name+unit+values | 36935 | 0 | [6.88, 8.63, 10, 11.22, 12.44, 13.72, 15.08, 16.91, 19.82] | S -Vankomysiini | Serum |  |
| 2760 | s-van |  | 4% | name | 1695 | 100 |  | S -Vankomysiini | Serum |  |
| 2761 | ts-res |  | 100% | name | 1353 | 100 |  | Ts-Reseptoritutkimus | Tissue |  |
| 2762 | u-hcg | iu/l | 28% | name+unit+values | 93 | 0 | [1.4, 1.54, 1.7, 1.9, 2.16, 2.3, 2.81, 31.3, 4256] | U -Koriongonadotropiini | Urine |  |
| 2763 | u-hcg | u/l | 4% | name+unit | 15 | 0 |  | U -Koriongonadotropiini | Urine |  |
| 2764 | u-hcg |  | 68% | name | 227 | 100 |  | U -Koriongonadotropiini | Urine |  |

