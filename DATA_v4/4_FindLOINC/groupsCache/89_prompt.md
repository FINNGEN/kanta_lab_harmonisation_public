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
Here is group 89 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 6679 | ab-ca++7.4 | mmol/l | 100% | name+unit+values | 1106 | 0 | [1.08, 1.12, 1.14, 1.16, 1.18, 1.2, 1.21, 1.23, 1.26] |  | Arterial blood |  |
| 6680 | ab-ca-i7.4 | mmol/l | 87% | name+unit+values | 52168 | 0 | [1, 1.05, 1.08, 1.1, 1.13, 1.15, 1.17, 1.2, 1.24] |  | Arterial blood |  |
| 6681 | ab-ca-i7.4 |  | 13% | name | 8114 | 100 |  |  | Arterial blood |  |
| 6682 | ab-ca-ion | mmol/l | 87% | name+unit+values | 52238 | 0 | [1, 1.04, 1.07, 1.1, 1.12, 1.14, 1.16, 1.18, 1.22] |  | Arterial blood | Ionized |
| 6683 | ab-ca-ion |  | 13% | name | 8098 | 100 |  |  | Arterial blood | Ionized |
| 6684 | ab-caionvt | mmol/l | 40% | name+unit+values | 84 | 1.19 | [1.12, 1.15, 1.18, 1.18, 1.2, 1.21, 1.22, 1.24, 1.28] |  | Arterial blood |  |
| 6685 | ab-caionvt |  | 60% | name+values | 124 | 100 | [1.1, 1.14, 1.15, 1.17, 1.19, 1.2, 1.23, 1.25, 1.28] |  | Arterial blood |  |
| 6686 | ap-ca-ion | mmol/l | 94% | name+unit+values | 1484 | 0 | [1.08, 1.11, 1.13, 1.14, 1.16, 1.17, 1.19, 1.2, 1.23] |  |  | Ionized |
| 6687 | ap-ca-ion |  | 6% | name | 102 | 100 |  |  |  | Ionized |
| 6688 | b-caionpf | mmol/l | 85% | name+unit | 652 | 0 |  |  | Blood |  |
| 6689 | b-caionpf |  | 15% | name | 111 | 100 |  |  | Blood |  |
| 6690 | ca++/7.40 | mmol/l | 100% | name+unit+values | 126152 | 0 | [1.14, 1.19, 1.2, 1.22, 1.23, 1.25, 1.26, 1.28, 1.31] |  |  |  |
| 6691 | ca++/7.40 |  | 0% | name | 569 | 100 |  |  |  |  |
| 6692 | ca++/ph7.4 | mmol/l | 97% | name+unit+values | 18482 | 0 | [1.1, 1.15, 1.18, 1.2, 1.22, 1.23, 1.25, 1.27, 1.31] |  |  |  |
| 6693 | ca++/ph7.4 |  | 3% | name+values | 588 | 100 | [1.08, 1.12, 1.13, 1.14, 1.15, 1.16, 1.21, 1.26, 1.34] |  |  |  |
| 6694 | ca++ph7.4 | mmol/l | 99% | name+unit+values | 16678 | 0 | [1.13, 1.16, 1.18, 1.2, 1.22, 1.23, 1.24, 1.26, 1.29] |  |  |  |
| 6695 | ca++ph7.4 |  | 1% | name | 184 | 100 |  |  |  |  |
| 6696 | ca-ion | mmol/l | 100% | name+unit+values | 126458 | 0 | [1.15, 1.19, 1.21, 1.23, 1.24, 1.26, 1.27, 1.29, 1.33] |  |  | Ionized |
| 6697 | ca-ion |  | 0% | name | 549 | 100 |  |  |  | Ionized |
| 6698 | cb-ca-i7.4 | mmol/l | 89% | name+unit+values | 1450 | 0 | [1.11, 1.15, 1.17, 1.19, 1.21, 1.22, 1.23, 1.25, 1.29] |  | Capillary blood |  |
| 6699 | cb-ca-i7.4 |  | 11% | name | 185 | 100 |  |  | Capillary blood |  |
| 6700 | cb-ca-ion | mmol/l | 88% | name+unit+values | 1880 | 0 | [1.11, 1.15, 1.17, 1.19, 1.2, 1.22, 1.24, 1.26, 1.3] |  | Capillary blood | Ionized |
| 6701 | cb-ca-ion |  | 12% | name | 250 | 100 |  |  | Capillary blood | Ionized |
| 6702 | cp-ca-ion | mmol/l | 92% | name+unit+values | 307 | 0 | [1.04, 1.1, 1.13, 1.15, 1.16, 1.18, 1.2, 1.22, 1.25] |  |  | Ionized |
| 6703 | cp-ca-ion |  | 8% | name | 28 | 100 |  |  |  | Ionized |
| 6704 | di-ca-ion | mmol/l | 98% | name+unit | 450 | 0 |  |  | Dialysis fluid | Ionized |
| 6705 | di-ca-ion |  | 2% | name | 8 | 100 |  |  | Dialysis fluid | Ionized |
| 6706 | di-ca-iona | mmol/l | 100% | name+unit | 456 | 0 |  |  | Dialysis fluid |  |
| 6707 | fb-nh4-ion | umol/l | 81% | name+unit+values | 298 | 0 | [11, 13.44, 17.68, 24.49, 31.79, 42.13, 54.77, 72.94, 100.99] | fB-Ammonium-ioni | Fasting blood; Foreign body / implant | Ionized |
| 6708 | fb-nh4-ion |  | 19% | name | 69 | 100 |  | fB-Ammonium-ioni | Fasting blood; Foreign body / implant | Ionized |
| 6709 | fp-ca-ion | mmol/l | 99% | name+unit+values | 1040 | 0 | [1.12, 1.15, 1.17, 1.19, 1.2, 1.21, 1.23, 1.25, 1.28] |  | Fasting plasma | Ionized |
| 6710 | fp-ca-ion |  | 1% | name | 8 | 100 |  |  | Fasting plasma | Ionized |
| 6711 | fp-ca-ion. | mmol/l | 99% | name+unit+values | 22635 | 0.13 | [1.05, 1.09, 1.11, 1.13, 1.15, 1.16, 1.18, 1.2, 1.23] |  | Fasting plasma |  |
| 6712 | fp-ca-ion. |  | 1% | name | 196 | 100 |  |  | Fasting plasma |  |
| 6713 | fp-ca-iona | mmol/l | 97% | name+unit+values | 383 | 0 | [1.16, 1.19, 1.2, 1.21, 1.22, 1.23, 1.25, 1.26, 1.29] |  | Fasting plasma |  |
| 6714 | fp-ca-iona |  | 3% | name | 13 | 100 |  |  | Fasting plasma |  |
| 6715 | fp-nh4-ion | umol/l | 90% | name+unit+values | 22919 | 0 | [17.32, 22.53, 27.24, 32.28, 37.91, 44.96, 54.51, 68.52, 92.89] | fP-Ammonium-ioni | Fasting plasma | Ionized |
| 6716 | fp-nh4-ion |  | 10% | name+values | 2418 | 100 | [18.27, 23.76, 29.8, 37.05, 45.85, 55.82, 65.3, 79.23, 103.94] | fP-Ammonium-ioni | Fasting plasma | Ionized |
| 6717 | fs-ca++/7.40 |  | 100% | name+values | 10897 | 100 | [1.18, 1.21, 1.22, 1.23, 1.24, 1.25, 1.27, 1.28, 1.32] |  | Fasting serum |  |
| 6718 | fs-ca++7.4 | mmol/l | 99% | name+unit+values | 8087 | 0 | [1.15, 1.19, 1.21, 1.22, 1.23, 1.25, 1.26, 1.28, 1.33] |  | Fasting serum |  |
| 6719 | fs-ca++7.4 |  | 1% | name | 47 | 100 |  |  | Fasting serum |  |
| 6720 | fs-ca-7.40 | mmol/l | 100% | name+unit+values | 987 | 0 | [1.19, 1.23, 1.25, 1.26, 1.28, 1.29, 1.31, 1.34, 1.38] |  | Fasting serum |  |
| 6721 | fs-ca-ion | mmol/l | 39% | name+unit+values | 21952 | 0 | [1.18, 1.2, 1.22, 1.24, 1.25, 1.26, 1.28, 1.3, 1.34] |  | Fasting serum | Ionized |
| 6722 | fs-ca-ion |  | 61% | name | 33916 | 100 |  |  | Fasting serum | Ionized |
| 6723 | fs-ca-ion/ph7.40 | mmol/l | 99% | name+unit+values | 27031 | 0 | [1.13, 1.17, 1.19, 1.21, 1.23, 1.24, 1.25, 1.27, 1.31] |  | Fasting serum |  |
| 6724 | fs-ca-ion/ph7.40 |  | 1% | name+values | 232 | 100 | [1.14, 1.31, 1.32, 1.33, 1.33, 1.34, 1.36, 1.38, 1.42] |  | Fasting serum |  |
| 6725 | fs-ca-iona | mmol/l | 87% | name+unit+values | 1052 | 0 | [1.14, 1.17, 1.19, 1.2, 1.22, 1.23, 1.25, 1.28, 1.35] |  | Fasting serum |  |
| 6726 | fs-ca-iona |  | 13% | name+values | 162 | 100 | [1.15, 1.16, 1.18, 1.19, 1.2, 1.21, 1.22, 1.24, 1.29] |  | Fasting serum |  |
| 6727 | fs-ph(ca-ion) |  | 100% | name+values | 1713 | 100 | [7.33, 7.35, 7.37, 7.38, 7.39, 7.4, 7.41, 7.42, 7.44] |  | Fasting serum |  |
| 6728 | mb-ca(7.4) | mmol/l | 96% | name+unit | 2502 | 0 |  |  |  |  |
| 6729 | mb-ca(7.4) |  | 4% | name | 108 | 100 |  |  |  |  |
| 6730 | mb-ca-ion | mmol/l | 96% | name+unit | 2504 | 0 |  |  |  | Ionized |
| 6731 | mb-ca-ion |  | 4% | name | 105 | 100 |  |  |  | Ionized |
| 6732 | p-ca(7.4) | mmol/l | 95% | name+unit+values | 23257 | 0 | [1.1, 1.14, 1.16, 1.17, 1.18, 1.2, 1.21, 1.23, 1.26] |  | Plasma |  |
| 6733 | p-ca(7.4) |  | 5% | name | 1266 | 100 |  |  | Plasma |  |
| 6734 | p-ca-ion | mmol/l | 28% | name+unit+values | 37155 | 0 | [1.09, 1.13, 1.15, 1.17, 1.18, 1.2, 1.21, 1.23, 1.27] | P -Kalsium, ionisoitunut | Plasma | Ionized |
| 6735 | p-ca-ion |  | 72% | name+values | 93247 | 100 | [1.1, 1.13, 1.16, 1.18, 1.2, 1.21, 1.25, 1.29, 1.33] | P -Kalsium, ionisoitunut | Plasma | Ionized |
| 6736 | p-ca-ion. | mmol/l | 100% | name+unit+values | 360997 | 0 | [1.03, 1.08, 1.11, 1.13, 1.16, 1.18, 1.2, 1.22, 1.26] |  | Plasma |  |
| 6737 | p-ca-ion. |  | 0% | name | 756 | 100 |  |  | Plasma |  |
| 6738 | p-ca-ion: | mmol/l | 100% | name+unit+values | 626 | 0 | [1.1, 1.14, 1.15, 1.17, 1.18, 1.19, 1.2, 1.22, 1.24] |  | Plasma |  |
| 6739 | p-ca-iona | mmol/l | 100% | name+unit+values | 409206 | 0.01 | [1.04, 1.08, 1.11, 1.13, 1.15, 1.17, 1.19, 1.21, 1.25] |  | Plasma |  |
| 6740 | p-ca-iona |  | 0% | name | 882 | 100 |  |  | Plasma |  |
| 6741 | p-caio7.4: | mmol/l | 100% | name+unit+values | 608 | 0 | [1.1, 1.13, 1.15, 1.17, 1.19, 1.2, 1.21, 1.23, 1.25] |  | Plasma |  |
| 6742 | p-caion7.4 | mmol/l | 54% | name+unit | 58 | 0 |  |  | Plasma |  |
| 6743 | p-caion7.4 |  | 46% | name | 49 | 100 |  |  | Plasma |  |
| 6744 | p-nh4-ion | umol/l | 86% | name+unit+values | 1298 | 0 | [24, 30.04, 34.97, 40.74, 46.76, 54.98, 66.47, 82.91, 111.7] |  | Plasma | Ionized |
| 6745 | p-nh4-ion |  | 14% | name+values | 208 | 100 | [23, 29.64, 34, 40.9, 50.07, 57.7, 72.1, 92.36, 125.65] |  | Plasma | Ionized |
| 6746 | s-ca(7.4) | mmol/l | 99% | name+unit+values | 132501 | 0 | [1.13, 1.17, 1.19, 1.21, 1.23, 1.24, 1.25, 1.27, 1.31] |  | Serum |  |
| 6747 | s-ca(7.4) | nmol/l | 0% | name+unit+values | 93 | 0 | [1.18, 1.21, 1.23, 1.24, 1.25, 1.26, 1.28, 1.3, 1.37] |  | Serum |  |
| 6748 | s-ca(7.4) |  | 1% | name | 1609 | 100 |  |  | Serum |  |
| 6749 | s-ca++/7.40 |  | 100% | name+values | 5887 | 100 | [1.18, 1.2, 1.21, 1.23, 1.24, 1.25, 1.26, 1.28, 1.32] |  | Serum |  |
| 6750 | s-ca-17.4 | mmol/l | 100% | name+unit+values | 835 | 0 | [1.18, 1.21, 1.22, 1.24, 1.25, 1.27, 1.28, 1.3, 1.33] |  | Serum |  |
| 6751 | s-ca-i7.4 | mmol/l | 92% | name+unit+values | 46811 | 0 | [1.17, 1.2, 1.22, 1.24, 1.25, 1.27, 1.28, 1.3, 1.34] |  | Serum |  |
| 6752 | s-ca-i7.4 |  | 8% | name | 4102 | 100 |  |  | Serum |  |
| 6753 | s-ca-ion | mmol/l | 72% | name+unit+values | 507827 | 0 | [1.14, 1.18, 1.2, 1.21, 1.23, 1.24, 1.26, 1.28, 1.32] | S -Kalsium, ionisoitunut | Serum | Ionized |
| 6754 | s-ca-ion |  | 28% | name | 192950 | 100 |  | S -Kalsium, ionisoitunut | Serum | Ionized |
| 6755 | s-ca-iona | mmol/l | 99% | name+unit+values | 394912 | 0 | [1.14, 1.18, 1.2, 1.22, 1.23, 1.25, 1.26, 1.29, 1.32] |  | Serum |  |
| 6756 | s-ca-iona |  | 1% | name | 2820 | 100 |  |  | Serum |  |
| 6757 | s-caio7.4 | mmol/l | 100% | name+unit+values | 860 | 0 | [1.17, 1.2, 1.22, 1.23, 1.25, 1.26, 1.28, 1.3, 1.35] |  | Serum |  |
| 6758 | s-caion7.4 | mmol/l | 99% | name+unit+values | 5310 | 0 | [1.16, 1.19, 1.21, 1.22, 1.23, 1.24, 1.25, 1.27, 1.29] |  | Serum |  |
| 6759 | s-caion7.4 |  | 1% | name | 57 | 100 |  |  | Serum |  |
| 6760 | s-caionac | mmol/l | 98% | name+unit+values | 863 | 0 | [1.16, 1.2, 1.22, 1.23, 1.25, 1.26, 1.28, 1.3, 1.34] |  | Serum |  |
| 6761 | s-caionac |  | 2% | name | 15 | 100 |  |  | Serum |  |
| 6762 | s-caph7.4 | mmol/l | 99% | name+unit+values | 5238 | 0 | [1.16, 1.19, 1.21, 1.22, 1.23, 1.25, 1.26, 1.28, 1.31] |  | Serum |  |
| 6763 | s-caph7.4 |  | 1% | name | 67 | 100 |  |  | Serum |  |
| 6764 | s-mg-ion | mmol/l | 95% | name+unit+values | 4664 | 0 | [0.5, 0.54, 0.56, 0.58, 0.6, 0.62, 0.64, 0.67, 0.71] |  | Serum | Ionized |
| 6765 | s-mg-ion |  | 5% | name+values | 253 | 100 | [0.55, 0.58, 0.6, 0.62, 0.63, 0.65, 0.67, 0.69, 0.74] |  | Serum | Ionized |
| 6766 | vb-ca-i7.4 | mmol/l | 81% | name+unit+values | 2427 | 0 | [0.99, 1.06, 1.1, 1.13, 1.15, 1.17, 1.19, 1.22, 1.26] |  | Venous blood |  |
| 6767 | vb-ca-i7.4 |  | 19% | name | 580 | 100 |  |  | Venous blood |  |
| 6768 | vb-ca-ion | mmol/l | 81% | name+unit+values | 2428 | 0 | [1.02, 1.08, 1.11, 1.14, 1.16, 1.18, 1.2, 1.22, 1.26] |  | Venous blood | Ionized |
| 6769 | vb-ca-ion |  | 19% | name | 567 | 100 |  |  | Venous blood | Ionized |
| 6770 | vb-caionvt | 1 | 5% | name+unit | 40 | 0 |  |  | Venous blood |  |
| 6771 | vb-caionvt | mmol/l | 40% | name+unit+values | 308 | 0 | [1.1, 1.13, 1.15, 1.18, 1.19, 1.21, 1.22, 1.24, 1.27] |  | Venous blood |  |
| 6772 | vb-caionvt |  | 55% | name+values | 422 | 100 | [1.12, 1.15, 1.17, 1.18, 1.2, 1.22, 1.23, 1.25, 1.27] |  | Venous blood |  |
| 6773 | vp-ca-ion | mmol/l | 98% | name+unit+values | 10809 | 0 | [1.13, 1.16, 1.17, 1.19, 1.2, 1.21, 1.23, 1.24, 1.27] |  |  | Ionized |
| 6774 | vp-ca-ion |  | 2% | name | 173 | 100 |  |  |  | Ionized |

