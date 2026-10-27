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
Here is group 79 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 6065 | b-gluk-o | mmol/l | 5% | name+unit | 7 | 100 |  |  | Blood | Qualitative test (also semi-quantitative) |
| 6066 | b-gluk-o |  | 95% | name+values | 129 | 100 | [5.43, 5.81, 6.2, 6.6, 7.12, 7.54, 8.33, 9.91, 15.45] |  | Blood | Qualitative test (also semi-quantitative) |
| 6067 | b-gluk-pi | mmol/l | 42% | name+unit | 60 | 0 |  |  | Blood |  |
| 6068 | b-gluk-pi |  | 58% | name+values | 83 | 100 | [5.2, 5.45, 5.81, 6.35, 7.22, 7.7, 10.2, 13.07, 15.5] |  | Blood |  |
| 6069 | b-gluk-pt | mmol/l | 36% | name+unit | 53 | 0 |  |  | Blood |  |
| 6070 | b-gluk-pt |  | 64% | name+values | 93 | 100 | [5.4, 5.85, 6.43, 7, 7.38, 8, 8.92, 10.13, 11.9] |  | Blood |  |
| 6071 | b-gluk-vt | mmol/l | 31% | name+unit | 72 | 0 |  |  | Blood |  |
| 6072 | b-gluk-vt |  | 69% | name+values | 157 | 100 | [5.1, 5.51, 5.93, 6.37, 6.75, 7.3, 8.41, 9.51, 12.29] |  | Blood |  |
| 6073 | b-gluk/pi | mmol/l | 99% | name+unit+values | 1414 | 0 | [5.2, 5.7, 6.14, 6.59, 7.19, 7.89, 8.94, 10.29, 12.88] |  | Blood |  |
| 6074 | b-gluk/pi |  | 1% | name | 10 | 100 |  |  | Blood |  |
| 6075 | b-gluk/pik | mmol/l | 100% | name+unit+values | 945 | 0 | [5.26, 5.68, 6.01, 6.38, 6.84, 7.35, 8.11, 9.42, 11.75] |  | Blood |  |
| 6076 | b-gluk/tt |  | 100% | name | 114 | 100 |  |  | Blood |  |
| 6077 | b-glukhoi | mmol/l | 35% | name+unit | 52 | 0 |  |  | Blood |  |
| 6078 | b-glukhoi |  | 65% | name+values | 95 | 100 | [4.9, 5.3, 5.54, 5.78, 6.1, 6.4, 6.97, 8.77, 12.2] |  | Blood |  |
| 6079 | cb-gluk-0 | mmol/l | 19% | name+unit | 21 | 0 |  |  | Capillary blood |  |
| 6080 | cb-gluk-0 |  | 81% | name | 89 | 100 |  |  | Capillary blood |  |
| 6081 | cb-gluk-v |  | 100% | name+values | 182 | 100 | [5.2, 5.7, 6.07, 6.36, 6.75, 7.46, 8.34, 9.87, 12.02] |  | Capillary blood | Free or unconjugated |
| 6082 | cb-gluk-vt | mmol/l | 37% | name+unit+values | 147 | 0 | [5.62, 6.11, 6.75, 7.37, 8.19, 9.86, 12.56, 16.24, 20.1] |  | Capillary blood |  |
| 6083 | cb-gluk-vt |  | 63% | name | 249 | 100 |  |  | Capillary blood |  |
| 6084 | cfp-glucos | mmol/l | 98% | name+unit+values | 1307 | 0 | [5.81, 6.24, 6.62, 6.91, 7.24, 7.63, 8.02, 8.7, 9.78] |  |  |  |
| 6085 | cfp-glucos |  | 2% | name | 30 | 100 |  |  |  |  |
| 6086 | cp-glucos | mmol/l | 82% | name+unit+values | 3564 | 0 | [5.94, 6.53, 7.17, 7.83, 8.52, 9.32, 10.35, 11.61, 13.51] |  |  |  |
| 6087 | cp-glucos |  | 18% | name | 794 | 100 |  |  |  |  |
| 6088 | cp-gluk-hy | mmol/l | 100% | name+unit+values | 16015 | 0.04 | [5.33, 6.49, 7.52, 8.51, 9.53, 10.54, 11.78, 13.35, 15.67] |  |  |  |
| 6089 | cp-gluk-hy |  | 0% | name | 40 | 100 |  |  |  |  |
| 6090 | cp-gluk-lb | mmol/l | 97% | name+unit+values | 10492 | 0 | [4.98, 5.61, 6.18, 6.77, 7.46, 8.42, 9.63, 11.26, 13.98] |  |  |  |
| 6091 | cp-gluk-lb |  | 3% | name | 283 | 100 |  |  |  |  |
| 6092 | cp-gluk-o |  | 100% | name | 165 | 100 |  |  |  | Qualitative test (also semi-quantitative) |
| 6093 | cp-gluk-po | mmol/l | 100% | name+unit+values | 2528 | 0 | [4.65, 5.93, 7.07, 8.16, 9.34, 10.66, 12.22, 14.51, 17.97] |  |  |  |
| 6094 | cp-gluk-po |  | 0% | name | 7 | 100 |  |  |  |  |
| 6095 | cp-glukpaa | mmol/l | 55% | name+unit | 116 | 0 |  |  |  |  |
| 6096 | cp-glukpaa |  | 45% | name | 94 | 100 |  |  |  |  |
| 6097 | cp-glukpot |  | 100% | name+values | 106 | 100 | [4.93, 5.55, 6.42, 7.07, 7.43, 8.57, 9.89, 11.44, 13.83] |  |  |  |
| 6098 | fp-gluk,t |  | 100% | name+values | 773 | 100 | [5.56, 6.02, 6.34, 6.71, 7.09, 7.5, 7.92, 8.81, 10.39] |  | Fasting plasma |  |
| 6099 | fp-gluk,tk |  | 100% | name+values | 1207 | 100 | [4.77, 5.03, 5.29, 5.49, 5.88, 6.46, 7.07, 7.93, 9.36] |  | Fasting plasma |  |
| 6100 | fp-gluk-0h | mmol/l | 41% | name+unit+values | 156 | 0 | [5.62, 5.88, 6.03, 6.17, 6.3, 6.44, 6.68, 6.89, 7.2] |  | Fasting plasma |  |
| 6101 | fp-gluk-0h |  | 59% | name+values | 229 | 100 | [4.5, 4.7, 4.81, 5, 5.1, 5.3, 5.51, 5.91, 6.41] |  | Fasting plasma |  |
| 6102 | fp-gluk-1 | mmol/l | 100% | name+unit+values | 108 | 0 | [5.5, 6.24, 6.81, 7.36, 7.89, 8.4, 8.79, 9.47, 10.2] |  | Fasting plasma |  |
| 6103 | fp-gluk-2 | mmol/l | 95% | name+unit+values | 168 | 0 | [4.74, 5.29, 5.7, 6.17, 6.78, 7.15, 7.64, 8.78, 10.15] |  | Fasting plasma |  |
| 6104 | fp-gluk-2 |  | 5% | name | 9 | 100 |  |  | Fasting plasma |  |
| 6105 | fp-gluk-2h | mmol/l | 71% | name+unit+values | 109 | 0 | [4.43, 5.4, 5.75, 6.21, 6.7, 7.52, 8.1, 8.93, 10.71] |  | Fasting plasma |  |
| 6106 | fp-gluk-2h | mmol/mol | 29% | name+unit | 45 | 0 |  |  | Fasting plasma |  |
| 6107 | fp-gluk-o | mmol/l | 95% | name+unit+values | 104 | 0 | [4.6, 4.9, 5.18, 5.4, 5.71, 6, 6.3, 6.7, 6.95] |  | Fasting plasma | Qualitative test (also semi-quantitative) |
| 6108 | fp-gluk-o |  | 5% | name | 6 | 100 |  |  | Fasting plasma | Qualitative test (also semi-quantitative) |
| 6109 | fp-gluk-p | mmol/l | 88% | name+unit+values | 391 | 0 | [4.76, 5.2, 5.64, 5.93, 6.1, 6.3, 6.49, 6.74, 7.18] |  | Fasting plasma | Upright (standing) |
| 6110 | fp-gluk-p |  | 12% | name | 51 | 100 |  |  | Fasting plasma | Upright (standing) |
| 6111 | fp-gluk-sn | mmol/l | 98% | name+unit+values | 1398 | 0 | [5.04, 5.72, 6.23, 6.71, 7.2, 7.71, 8.25, 9.13, 10.8] |  | Fasting plasma |  |
| 6112 | fp-gluk-sn |  | 2% | name | 28 | 100 |  |  | Fasting plasma |  |
| 6113 | fp-gluk/0 | mmol/l | 87% | name+unit+values | 296 | 0 | [4.49, 4.7, 4.93, 5.24, 5.55, 5.9, 6.19, 6.52, 6.89] |  | Fasting plasma |  |
| 6114 | fp-gluk/0 |  | 13% | name | 46 | 100 |  |  | Fasting plasma |  |
| 6115 | fp-gluk/pi |  | 100% | name+values | 110 | 100 | [5.2, 5.44, 5.64, 5.94, 6.22, 6.57, 7.06, 7.97, 9.9] |  | Fasting plasma |  |
| 6116 | fp-gluk0 | mmol/l | 90% | name+unit+values | 1616 | 0 | [4.6, 4.73, 4.9, 5.02, 5.22, 5.42, 5.67, 5.95, 6.5] |  | Fasting plasma |  |
| 6117 | fp-gluk0 |  | 10% | name+values | 175 | 100 | [4.96, 5.57, 6.04, 6.16, 6.3, 6.49, 6.7, 6.84, 7.15] |  | Fasting plasma |  |
| 6118 | fp-glukos | mmol/l | 100% | name+unit+values | 977 | 0 | [4.79, 5.14, 5.39, 5.61, 5.86, 6.13, 6.45, 7.01, 8.07] |  | Fasting plasma |  |
| 6119 | fp-glukr0 | mmol/l | 89% | name+unit+values | 173 | 0 | [4.63, 4.88, 5.24, 5.55, 5.9, 6.12, 6.4, 6.6, 7.09] |  | Fasting plasma |  |
| 6120 | fp-glukr0 |  | 11% | name | 21 | 100 |  |  | Fasting plasma |  |
| 6121 | fp-glukr0h | mmol/l | 97% | name+unit+values | 951 | 0.32 | [5.42, 5.7, 5.88, 6.01, 6.19, 6.34, 6.51, 6.77, 7.2] |  | Fasting plasma |  |
| 6122 | fp-glukr0h |  | 3% | name | 28 | 100 |  |  | Fasting plasma |  |
| 6123 | p-glkg | ng/l | 83% | name+unit+values | 365 | 0 | [139.5, 155.41, 170.26, 182.78, 193.92, 208.93, 237.14, 279.6, 336.26] | P -Glukagoni | Plasma |  |
| 6124 | p-glkg |  | 17% | name | 77 | 100 |  | P -Glukagoni | Plasma |  |
| 6125 | p-glu/0 | mmol/l | 99% | name+unit+values | 1831 | 0 | [4.4, 4.63, 4.86, 5.08, 5.3, 5.57, 5.89, 6.23, 6.67] |  | Plasma |  |
| 6126 | p-glu/0 |  | 1% | name | 24 | 100 |  |  | Plasma |  |
| 6127 | p-glu/1h | mmol/l | 98% | name+unit+values | 683 | 0 | [5.17, 5.85, 6.4, 6.95, 7.34, 7.81, 8.3, 8.85, 9.71] |  | Plasma |  |
| 6128 | p-glu/1h |  | 2% | name | 11 | 100 |  |  | Plasma |  |
| 6129 | p-glu/2h | mmol/l | 98% | name+unit+values | 1816 | 0 | [4.49, 5.06, 5.5, 5.9, 6.36, 6.92, 7.74, 8.85, 11.03] |  | Plasma |  |
| 6130 | p-glu/2h |  | 2% | name | 35 | 100 |  |  | Plasma |  |
| 6131 | p-glu/30m | mmol/l | 100% | name+unit+values | 228 | 0 | [6.47, 7.15, 7.55, 7.97, 8.37, 8.76, 9.2, 9.83, 10.94] |  | Plasma |  |
| 6132 | p-gluk,tk | mmol/l | 100% | name+unit+values | 7423 | 0 | [5.62, 6.19, 6.72, 7.31, 8.07, 8.98, 10.16, 11.79, 14.45] |  | Plasma |  |
| 6133 | p-gluk-0 | mmol/l | 91% | name+unit+values | 264 | 0 | [4.63, 4.8, 4.96, 5.1, 5.27, 5.57, 5.92, 6.32, 7.02] |  | Plasma |  |
| 6134 | p-gluk-0 |  | 9% | name | 26 | 100 |  |  | Plasma |  |
| 6135 | p-gluk-0h | mmol/l | 99% | name+unit+values | 750 | 0 | [4.5, 4.74, 4.99, 5.18, 5.41, 5.76, 6.07, 6.32, 6.7] |  | Plasma |  |
| 6136 | p-gluk-0h |  | 1% | name | 8 | 100 |  |  | Plasma |  |
| 6137 | p-gluk-1h | mmol/l | 71% | name+unit+values | 402 | 0 | [5.57, 6.22, 6.83, 7.23, 7.57, 8.06, 8.49, 9.01, 9.94] |  | Plasma |  |
| 6138 | p-gluk-1h |  | 29% | name+values | 163 | 100 | [5.81, 6.57, 7.01, 7.47, 7.82, 8.15, 8.47, 9.03, 10.1] |  | Plasma |  |
| 6139 | p-gluk-1t | mmol/l | 91% | name+unit+values | 167 | 0 | [5.29, 5.9, 6.35, 6.66, 7.27, 7.64, 8.35, 8.9, 10.16] |  | Plasma |  |
| 6140 | p-gluk-1t |  | 9% | name | 17 | 100 |  |  | Plasma |  |
| 6141 | p-gluk-2h | mmol/l | 77% | name+unit+values | 897 | 0 | [4.78, 5.31, 5.74, 6.17, 6.56, 7.1, 7.66, 8.51, 9.94] |  | Plasma |  |
| 6142 | p-gluk-2h |  | 23% | name+values | 263 | 100 | [4.77, 5.45, 5.76, 6.17, 6.52, 6.84, 7.15, 7.77, 9.15] |  | Plasma |  |
| 6143 | p-gluk-2t | mmol/l | 89% | name+unit+values | 462 | 0 | [4.62, 5.32, 5.8, 6.21, 6.64, 7.17, 7.9, 8.99, 11.01] |  | Plasma |  |
| 6144 | p-gluk-2t |  | 11% | name | 59 | 100 |  |  | Plasma |  |
| 6145 | p-gluk-a2 | mmol/l | 85% | name+unit+values | 1483 | 0.07 | [5.94, 7.28, 8.69, 10, 11.25, 12.56, 14.23, 16.59, 19.44] |  | Plasma |  |
| 6146 | p-gluk-a2 |  | 15% | name+values | 259 | 100 | [6.42, 7.76, 9.11, 10.3, 11.29, 12.59, 13.78, 15.77, 18.35] |  | Plasma |  |
| 6147 | p-gluk-o | mmol/l | 88% | name+unit+values | 1305 | 0.08 | [3.8, 4.26, 4.54, 4.72, 4.91, 5.15, 5.44, 5.9, 6.59] |  | Plasma | Qualitative test (also semi-quantitative) |
| 6148 | p-gluk-o |  | 12% | name | 175 | 100 |  |  | Plasma | Qualitative test (also semi-quantitative) |
| 6149 | p-gluk-po | mmol/l | 77% | name+unit+values | 820 | 0 | [5.73, 6.47, 7.19, 7.81, 8.6, 9.37, 10.27, 11.53, 13.61] |  | Plasma |  |
| 6150 | p-gluk-po |  | 23% | name+values | 242 | 100 | [5.3, 6.08, 6.6, 7.05, 7.78, 8.4, 9.46, 11.37, 12.6] |  | Plasma |  |
| 6151 | p-gluk-sn | mmol/l | 32% | name+unit+values | 1252 | 0 | [5.62, 6.24, 6.87, 7.62, 8.75, 10.05, 11.53, 13.51, 16.47] |  | Plasma |  |
| 6152 | p-gluk-sn |  | 68% | name | 2688 | 100 |  |  | Plasma |  |
| 6153 | p-gluk-vt | 1 | 1% | name+unit | 40 | 0 |  |  | Plasma |  |
| 6154 | p-gluk-vt | mmol/l | 99% | name+unit+values | 7875 | 0 | [4.66, 4.98, 5.43, 6.02, 6.79, 7.88, 9.29, 11.32, 14.47] |  | Plasma |  |
| 6155 | p-gluk. | mmol/l | 40% | name+unit+values | 752 | 0 | [4.6, 4.9, 5.19, 5.56, 5.95, 6.36, 6.79, 7.42, 8.57] |  | Plasma |  |
| 6156 | p-gluk. |  | 60% | name | 1111 | 100 |  |  | Plasma |  |
| 6157 | p-gluk/120 | mmol/l | 76% | name+unit+values | 95 | 0 | [4.8, 5.3, 5.71, 6.15, 6.7, 7.35, 7.8, 8.75, 10] |  | Plasma |  |
| 6158 | p-gluk/120 |  | 24% | name | 30 | 100 |  |  | Plasma |  |
| 6159 | p-gluk/2h | mmol/l | 92% | name+unit+values | 204 | 0 | [4.6, 5.17, 5.53, 6.07, 6.51, 7.16, 8.06, 9.69, 11.7] |  | Plasma |  |
| 6160 | p-gluk/2h |  | 8% | name | 17 | 100 |  |  | Plasma |  |
| 6161 | p-gluk0 | mmol/l | 60% | name+unit+values | 205 | 0 | [4.71, 4.97, 5.2, 5.33, 5.51, 5.7, 5.82, 6, 6.41] |  | Plasma |  |
| 6162 | p-gluk0 |  | 40% | name+values | 134 | 100 | [4.9, 5.29, 5.97, 6.1, 6.21, 6.44, 6.67, 6.9, 7.26] |  | Plasma |  |
| 6163 | p-gluk120 | mmol/l | 96% | name+unit+values | 1674 | 0 | [4.77, 5.31, 5.74, 6.14, 6.54, 7.03, 7.61, 8.44, 10] |  | Plasma |  |
| 6164 | p-gluk120 |  | 4% | name | 77 | 100 |  |  | Plasma |  |
| 6165 | p-gluk1h | mmol/l | 83% | name+unit+values | 181 | 0 | [5.46, 5.92, 6.58, 7.24, 7.73, 8.41, 9.44, 10.75, 12.63] |  | Plasma |  |
| 6166 | p-gluk1h |  | 17% | name | 38 | 100 |  |  | Plasma |  |
| 6167 | p-gluk2h | mmol/l | 24% | name+unit+values | 92 | 0 | [4.6, 5.11, 5.97, 6.3, 6.8, 7.26, 7.98, 9, 10.5] |  | Plasma |  |
| 6168 | p-gluk2h | mmoll/l | 43% | name+unit+values | 169 | 0 | [4.54, 4.97, 5.56, 5.91, 6.35, 6.78, 7.43, 8.12, 9.76] |  | Plasma |  |
| 6169 | p-gluk2h |  | 33% | name+values | 129 | 100 | [5.36, 6.02, 6.76, 7.08, 7.8, 8.46, 9.11, 10.06, 11.53] |  | Plasma |  |
| 6170 | p-gluk60 | mmol/l | 96% | name+unit+values | 936 | 0.21 | [5.58, 6.24, 6.73, 7.23, 7.62, 8.17, 8.7, 9.36, 10.2] |  | Plasma |  |
| 6171 | p-gluk60 |  | 4% | name | 43 | 100 |  |  | Plasma |  |
| 6172 | p-gluk: | mmol/l | 100% | name+unit+values | 627 | 0 | [5.38, 5.94, 6.31, 6.7, 7.16, 7.74, 8.48, 9.63, 11.83] |  | Plasma |  |
| 6173 | p-glukhoi | mmol/l | 42% | name+unit+values | 279 | 0 | [5.05, 5.62, 6.12, 6.89, 7.83, 9, 10.74, 12.64, 15.73] |  | Plasma |  |
| 6174 | p-glukhoi |  | 58% | name+values | 384 | 100 | [5.07, 5.6, 5.97, 6.28, 6.77, 7.43, 8.38, 10.3, 13.45] |  | Plasma |  |
| 6175 | p-glukp | mmol/l | 100% | name+unit+values | 175 | 0.57 | [4.6, 4.91, 5.23, 5.5, 5.89, 6.43, 6.92, 7.84, 12.46] |  | Plasma |  |
| 6176 | p-glukpik | mmol/l | 90% | name+unit+values | 200 | 0 | [5, 5.2, 5.4, 5.63, 5.8, 6.05, 6.2, 6.5, 7.53] |  | Plasma |  |
| 6177 | p-glukpik |  | 10% | name | 21 | 100 |  |  | Plasma |  |
| 6178 | p-glukpoc | mmol/l | 100% | name+unit+values | 2519 | 0 | [5.93, 6.58, 7.13, 7.75, 8.31, 9.1, 9.95, 11.15, 13.04] |  | Plasma |  |
| 6179 | p-glukr0h | mmol/l | 100% | name+unit+values | 535 | 0 | [4.5, 4.7, 4.86, 5, 5.1, 5.28, 5.45, 5.71, 6.24] |  | Plasma |  |
| 6180 | p-glukr1h | mmol/l | 98% | name+unit+values | 466 | 0 | [5.51, 6.13, 6.67, 7.07, 7.5, 7.91, 8.49, 9.1, 9.84] |  | Plasma |  |
| 6181 | p-glukr1h |  | 2% | name | 8 | 100 |  |  | Plasma |  |
| 6182 | p-glukr2h | mmol/l | 97% | name+unit+values | 1604 | 0.19 | [4.57, 5.2, 5.69, 6.15, 6.62, 7.19, 7.87, 8.98, 10.55] |  | Plasma |  |
| 6183 | p-glukr2h |  | 3% | name | 58 | 100 |  |  | Plasma |  |
| 6184 | pt-gluk,0 |  | 100% | name | 130 | 100 |  |  | Patient |  |
| 6185 | pt-gluk-0 | mmol/l | 64% | name+unit+values | 272 | 0 | [4.3, 4.59, 4.8, 4.98, 5.22, 5.5, 5.77, 6.17, 6.53] |  | Patient |  |
| 6186 | pt-gluk-0 |  | 36% | name+values | 151 | 100 | [4.5, 4.7, 4.8, 4.88, 5, 5.11, 5.33, 5.5, 5.76] |  | Patient |  |
| 6187 | pt-gluk-0h | mmol/l | 87% | name+unit+values | 951 | 0 | [4.4, 4.6, 4.76, 4.9, 5.02, 5.23, 5.49, 5.86, 6.46] |  | Patient |  |
| 6188 | pt-gluk-0h |  | 13% | name+values | 138 | 100 | [5, 5.1, 5.21, 5.5, 5.63, 5.81, 5.99, 6.24, 6.64] |  | Patient |  |
| 6189 | pt-gluk-1h | mmol/l | 99% | name+unit+values | 771 | 0 | [5.25, 5.86, 6.42, 6.94, 7.45, 8.02, 8.57, 9.25, 10.42] |  | Patient |  |
| 6190 | pt-gluk-1h |  | 1% | name | 6 | 100 |  |  | Patient |  |
| 6191 | pt-gluk-2h | mmol/l | 91% | name+unit+values | 1501 | 0 | [4.46, 4.99, 5.43, 5.84, 6.26, 6.73, 7.36, 8.21, 9.78] |  | Patient |  |
| 6192 | pt-gluk-2h |  | 9% | name+values | 154 | 100 | [4, 4.66, 5.12, 5.48, 5.93, 6.4, 6.95, 7.57, 9.38] |  | Patient |  |
| 6193 | pt-gluk-30 |  | 100% | name+values | 131 | 100 | [7.04, 7.5, 7.77, 8.19, 8.53, 9.21, 9.76, 10.71, 12.23] |  | Patient |  |
| 6194 | pt-gluk-r |  | 100% | name | 14723 | 100 |  |  | Patient | Exercise / functional test |
| 6195 | pt-gluk-r1 | form | 0% | name+unit | 75 | 0 |  | Pt-Glukoosi-koe, oraalinen, lyhyt | Patient |  |
| 6196 | pt-gluk-r1 | mmol/l | 1% | name+unit+values | 369 | 0 | [5, 5.36, 5.74, 6.03, 6.42, 6.84, 7.39, 8.3, 9.71] | Pt-Glukoosi-koe, oraalinen, lyhyt | Patient |  |
| 6197 | pt-gluk-r1 |  | 99% | name | 71876 | 100 |  | Pt-Glukoosi-koe, oraalinen, lyhyt | Patient |  |
| 6198 | pt-gluk-r2 | mmol/l | 7% | name+unit | 21 | 0 |  | Pt-Glukoosi-koe, oraalinen, pitkä | Patient |  |
| 6199 | pt-gluk-r2 |  | 93% | name | 287 | 100 |  | Pt-Glukoosi-koe, oraalinen, pitkä | Patient |  |
| 6200 | pt-gluk-r2,tk |  | 100% | name | 289 | 100 |  |  | Patient |  |
| 6201 | pt-gluk-r4 |  | 100% | name | 143 | 100 |  | Pt-Glukoosi-koe, hypoglykemia | Patient |  |
| 6202 | pt-gluk-r5 |  | 100% | name | 108 | 100 |  | Pt-Glukoosi-koe, kasvuhormoni | Patient |  |
| 6203 | pt-gluk-r6 | mmol/l | 2% | name+unit+values | 370 | 0 | [4.7, 4.94, 5.17, 5.39, 5.84, 6.39, 6.99, 7.91, 8.84] | Pt-Glukoosi-koe, oraalinen, raskaudenaikainen | Patient |  |
| 6204 | pt-gluk-r6 |  | 98% | name | 23123 | 100 |  | Pt-Glukoosi-koe, oraalinen, raskaudenaikainen | Patient |  |
| 6205 | pt-gluk-r8 |  | 100% | name | 231 | 100 |  |  | Patient |  |
| 6206 | pt-gluk-rg |  | 100% | name | 118 | 100 |  |  | Patient |  |
| 6207 | pt-gluk-sd |  | 100% | name | 824 | 100 |  |  | Patient |  |
| 6208 | pt-glukoos |  | 100% | name | 257 | 100 |  |  | Patient |  |
| 6209 | pt-glukr-0 | mmol/l | 100% | name+unit+values | 300 | 0 | [5.37, 5.6, 5.8, 5.96, 6.13, 6.3, 6.48, 6.67, 7.12] |  | Patient |  |
| 6210 | pt-glukr1p |  | 100% | name | 902 | 100 |  |  | Patient |  |
| 6211 | pt-glukr1v |  | 100% | name | 1247 | 100 |  |  | Patient |  |
| 6212 | pt-glukr2h |  | 100% | name | 5360 | 100 |  |  | Patient |  |
| 6213 | pt-glur3-g |  | 100% | name | 118 | 100 |  |  | Patient |  |
| 6214 | pt-glur3-i |  | 100% | name | 118 | 100 |  |  | Patient |  |
| 6215 | u-gluk-0 |  | 100% | name+values | 9320 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  |
| 6216 | u-gluk-de |  | 100% | name+values | 152 | 100 | [1044.9, 1079.17, 1109.42, 1125, 1152.75, 1186.12, 1207.92, 1246.3, 1486.7] |  | Urine |  |
| 6217 | u-gluk-hy |  | 100% | name | 2667 | 100 |  |  | Urine |  |
| 6218 | u-gluk-o | estimate | 21% | name+unit+values | 176312 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Glukoosi (kval) | Urine | Qualitative test (also semi-quantitative) |
| 6219 | u-gluk-o | form | 0% | name+unit+values | 842 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Glukoosi (kval) | Urine | Qualitative test (also semi-quantitative) |
| 6220 | u-gluk-o |  | 79% | name | 658060 | 100 |  | U -Glukoosi (kval) | Urine | Qualitative test (also semi-quantitative) |
| 6221 | u-gluk-o. |  | 100% | name | 24482 | 100 |  |  | Urine |  |
| 6222 | u-gluk-ov |  | 100% | name | 816 | 100 |  |  | Urine |  |
| 6223 | u-gluk-pi |  | 100% | name | 422 | 100 |  |  | Urine |  |
| 6224 | vp-gluk-0h | mmol/l | 62% | name+unit+values | 715 | 0 | [4.69, 4.93, 5.24, 5.58, 5.92, 6.16, 6.43, 6.77, 7.19] |  |  |  |
| 6225 | vp-gluk-0h |  | 38% | name+values | 439 | 100 | [4.64, 4.89, 5.14, 5.56, 5.95, 6.27, 6.57, 6.88, 7.22] |  |  |  |
| 6226 | vp-gluk-1h | mmol/l | 63% | name+unit+values | 247 | 0 | [5.11, 5.77, 6.25, 6.61, 7.03, 7.67, 8.06, 8.63, 9.93] |  |  |  |
| 6227 | vp-gluk-1h |  | 37% | name+values | 144 | 100 | [5.81, 6.29, 6.71, 7.08, 7.37, 7.82, 8.17, 8.78, 9.49] |  |  |  |
| 6228 | vp-gluk-2h | mmol/l | 62% | name+unit+values | 712 | 0 | [4.98, 5.56, 6.04, 6.64, 7.18, 7.97, 8.74, 10.17, 12.52] |  |  |  |
| 6229 | vp-gluk-2h |  | 38% | name+values | 431 | 100 | [5.19, 5.72, 6.34, 6.98, 7.61, 8.2, 9.41, 11.25, 12.85] |  |  |  |

