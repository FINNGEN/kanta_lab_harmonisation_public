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
Here is group 14 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 957 | b-c-reaktiivinenproteiini | mg/l | 10% | name+unit | 29 | 0 |  |  | Blood |  |
| 958 | b-c-reaktiivinenproteiini |  | 90% | name+values | 262 | 100 | [6, 7.54, 10.61, 13.7, 19, 27.87, 38.55, 55.7, 83.8] |  | Blood |  |
| 959 | b-c-reaktiivinenproteiinipika |  | 100% | name+values | 300 | 100 | [7, 9.98, 14.87, 19.86, 29.44, 37.29, 52.65, 75.47, 99.97] |  | Blood |  |
| 960 | b-c-resktiivinenproteiini | mg/l | 60% | name+unit+values | 1201 | 0 | [6.01, 8.05, 11.19, 14.61, 19.57, 26.51, 38.87, 58.3, 92.06] |  | Blood |  |
| 961 | b-c-resktiivinenproteiini |  | 40% | name | 802 | 100 |  |  | Blood |  |
| 962 | c-reaktiivinenproteiini | 1 | 6% | name+unit+values | 925 | 0 | [6.19, 8.92, 12.22, 16.99, 23.6, 35.02, 49.28, 74.96, 108.63] |  |  |  |
| 963 | c-reaktiivinenproteiini | mg/l | 50% | name+unit+values | 7963 | 0 | [4.01, 6.23, 9.46, 14.44, 23.17, 35.24, 51.91, 78.65, 126.37] |  |  |  |
| 964 | c-reaktiivinenproteiini |  | 44% | name+values | 7083 | 100 | [6.33, 8.51, 11.39, 16.56, 23.29, 36.71, 52.04, 72.28, 105.61] |  |  |  |
| 965 | c-reaktiivinenproteiini(4594p-crp) | mg/l | 66% | name+unit+values | 143 | 0 | [1, 1.79, 2, 2, 3, 4, 5, 6.63, 12.8] |  |  |  |
| 966 | c-reaktiivinenproteiini(4594p-crp) |  | 34% | name | 74 | 100 |  |  |  |  |
| 967 | c-reaktiivinenproteiini(crp) | mg/l | 60% | name+unit+values | 381 | 0 | [1.23, 1.51, 1.92, 2.62, 3.39, 4.73, 6.27, 9.96, 21.14] |  |  |  |
| 968 | c-reaktiivinenproteiini(crp) |  | 40% | name | 250 | 100 |  |  |  |  |
| 969 | c-reaktiivinenproteiini(p-crp) | mg/l | 66% | name+unit+values | 500 | 0 | [1, 1.99, 2, 2.87, 3.17, 4.22, 5.93, 9.01, 19.57] |  |  |  |
| 970 | c-reaktiivinenproteiini(p-crp) |  | 34% | name | 261 | 100 |  |  |  |  |
| 971 | c-reaktiivinenproteiini,herkkä | mg/l | 93% | name+unit+values | 254 | 0 | [0.22, 0.41, 0.59, 0.85, 1.15, 1.65, 2.41, 3.84, 6.24] |  |  |  |
| 972 | c-reaktiivinenproteiini,herkkä |  | 7% | name | 18 | 100 |  |  |  |  |
| 973 | c-reaktiivinenproteiini,herkkä,seerumista | mg/l | 100% | name+unit+values | 7396 | 0 | [0.29, 0.41, 0.59, 0.78, 1.03, 1.33, 1.82, 2.72, 4.64] |  |  |  |
| 974 | c-reaktiivinenproteiini,herkkä,seerumista |  | 0% | name | 36 | 100 |  |  |  |  |
| 975 | c-reaktiivinenproteiini,pika | mg/l | 69% | name+unit+values | 111 | 0 | [5, 5, 5.98, 7, 10.56, 13.36, 20.87, 34.17, 56] |  |  |  |
| 976 | c-reaktiivinenproteiini,pika |  | 31% | name | 49 | 100 |  |  |  |  |
| 977 | c-reaktiivinenproteiini,pika,tehdäänitse | mg/l | 55% | name+unit+values | 997 | 0 | [5, 5, 6.03, 8.02, 10.68, 14.69, 20.77, 34.42, 52.97] |  |  |  |
| 978 | c-reaktiivinenproteiini,pika,tehdäänitse |  | 45% | name | 820 | 100 |  |  |  |  |
| 979 | c-reaktiivinenproteiini,pikatesti,veri | mg/l | 10% | name+unit+values | 174 | 0.57 | [6, 7, 8.95, 10.84, 16.77, 22.29, 34.85, 53.05, 98.17] |  |  |  |
| 980 | c-reaktiivinenproteiini,pikatesti,veri |  | 90% | name+values | 1656 | 100 | [6.44, 9.56, 13.03, 19.18, 27.25, 38.9, 52.68, 73.38, 109.24] |  |  |  |
| 981 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) | mg/l | 77% | name+unit+values | 803 | 0.12 | [5, 5.19, 7.23, 9.16, 13.46, 18.82, 28.89, 45.49, 75.91] |  |  |  |
| 982 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) |  | 23% | name | 240 | 100 |  |  |  |  |
| 983 | c-reaktiivinenproteiini,pikatutkimus | mg/l | 62% | name+unit+values | 106 | 0 | [6.73, 11.2, 15.4, 21.77, 30.17, 39.25, 56.9, 88.7, 114] |  |  |  |
| 984 | c-reaktiivinenproteiini,pikatutkimus |  | 38% | name | 66 | 100 |  |  |  |  |
| 985 | c-reaktiivinenproteiini,plasmasta,vieritesti | mg/l | 72% | name+unit+values | 699 | 0.14 | [5.15, 7.88, 10.79, 16.55, 23.64, 33.15, 47.97, 64.96, 99.24] |  |  |  |
| 986 | c-reaktiivinenproteiini,plasmasta,vieritesti |  | 28% | name | 274 | 100 |  |  |  |  |
| 987 | c-reaktiivinenproteiini,tk:ntekemä |  | 100% | name+values | 1605 | 100 | [1.8, 3.13, 5.04, 8.21, 13.7, 22.58, 37.06, 58.66, 92.43] |  |  |  |
| 988 | c-reaktiivinenproteiini,vieritesti | mg/l | 5% | name+unit | 47 | 0 |  |  |  |  |
| 989 | c-reaktiivinenproteiini,vieritesti |  | 95% | name+values | 944 | 100 | [2.05, 4.95, 6.52, 8.89, 12.48, 17.85, 26.38, 44.03, 78.27] |  |  |  |
| 990 | c-reaktiivinenproteiini,vieritutkimus | mg/l | 45% | name+unit+values | 525 | 0 | [5, 5.95, 7.87, 11.68, 14.87, 20.65, 33.27, 55.7, 86.43] |  |  |  |
| 991 | c-reaktiivinenproteiini,vieritutkimus |  | 55% | name+values | 631 | 100 | [6, 8.93, 14.57, 21.5, 32.56, 47.6, 62.23, 77.19, 111.75] |  |  |  |
| 992 | c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 79% | name+unit+values | 1205 | 0 | [3.19, 6, 9.37, 13.37, 19.15, 28.37, 40.64, 61.88, 94.42] |  |  |  |
| 993 | c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 21% | name | 318 | 100 |  |  |  |  |
| 994 | c-reaktiivinenproteiini,vieritutkimusnordlab | mg/l | 48% | name+unit+values | 92 | 1.09 | [5, 6, 7.65, 9.6, 12.5, 16.2, 20.27, 33, 47] |  |  |  |
| 995 | c-reaktiivinenproteiini,vieritutkimusnordlab |  | 52% | name | 99 | 100 |  |  |  |  |
| 996 | c-reaktiivinenproteiini-pika(4594crp-pika) | mg/l | 74% | name+unit+values | 136 | 0 | [5, 5.3, 7, 8.84, 11.17, 14.59, 18.57, 33.71, 47.7] |  |  |  |
| 997 | c-reaktiivinenproteiini-pika(4594crp-pika) |  | 26% | name | 47 | 100 |  |  |  |  |
| 998 | c-reaktiivinenproteiini-pika(crp-pika) | mg/l | 75% | name+unit+values | 1488 | 0 | [5, 6.95, 7, 7.23, 10.11, 14.48, 21.2, 31.68, 54.63] |  |  |  |
| 999 | c-reaktiivinenproteiini-pika(crp-pika) |  | 25% | name | 505 | 100 |  |  |  |  |
| 1000 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä | mg/l | 79% | name+unit+values | 1826 | 0 | [1.75, 3.04, 5.71, 9.59, 14.3, 22.86, 34.7, 57.86, 90.35] |  |  |  |
| 1001 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä |  | 21% | name+values | 497 | 100 | [1.2, 1.55, 2.24, 2.89, 3.98, 4.84, 6.22, 7.61, 9.1] |  |  |  |
| 1002 | fs-c-reaktiivinenproteiini | mg/l | 57% | name+unit | 241 | 0 |  |  | Fasting serum |  |
| 1003 | fs-c-reaktiivinenproteiini |  | 43% | name | 184 | 100 |  |  | Fasting serum |  |
| 1004 | p-c-reaktiininenproteiini,vieritutkimus | mg/l | 54% | name+unit+values | 258 | 0 | [5.88, 8.84, 11.18, 17.01, 24.5, 35.24, 49.69, 68.51, 95.63] |  | Plasma |  |
| 1005 | p-c-reaktiininenproteiini,vieritutkimus |  | 46% | name | 224 | 100 |  |  | Plasma |  |
| 1006 | p-c-reaktiivinenproteiini | mg/l | 62% | name+unit+values | 41046 | 0 | [4.28, 7.21, 11.69, 18.14, 27.46, 40.14, 58.51, 87.59, 141.7] |  | Plasma |  |
| 1007 | p-c-reaktiivinenproteiini |  | 38% | name | 24714 | 100 |  |  | Plasma |  |
| 1008 | p-c-reaktiivinenproteiini(kval) | mg/l | 57% | name+unit+values | 187 | 0 | [6, 8.84, 13.56, 19.94, 26.88, 35.76, 52.92, 75.64, 104.4] |  | Plasma |  |
| 1009 | p-c-reaktiivinenproteiini(kval) |  | 43% | name | 142 | 100 |  |  | Plasma |  |
| 1010 | p-c-reaktiivinenproteiini(kval)␤ | mg/l | 46% | name+unit+values | 111 | 0 | [7, 10.23, 13.96, 17.18, 22.2, 27.49, 39.84, 58.9, 98.58] |  | Plasma |  |
| 1011 | p-c-reaktiivinenproteiini(kval)␤ |  | 54% | name | 130 | 100 |  |  | Plasma |  |
| 1012 | p-c-reaktiivinenproteiini(pikanäyte) | mg/l | 2% | name+unit | 6 | 0 |  |  | Plasma |  |
| 1013 | p-c-reaktiivinenproteiini(pikanäyte) |  | 98% | name+values | 352 | 100 | [1.49, 2.47, 4.27, 6.66, 10.25, 18.19, 28.15, 53.49, 81.26] |  | Plasma |  |
| 1014 | p-c-reaktiivinenproteiini,crp | mg/l | 93% | name+unit | 110 | 0 |  |  | Plasma |  |
| 1015 | p-c-reaktiivinenproteiini,crp |  | 7% | name | 8 | 100 |  |  | Plasma |  |
| 1016 | p-c-reaktiivinenproteiini,hoitoyksikkö | 1 | 14% | name+unit | 40 | 0 |  |  | Plasma |  |
| 1017 | p-c-reaktiivinenproteiini,hoitoyksikkö | mg/l | 29% | name+unit+values | 81 | 0 | [8, 10.55, 12, 15, 19.38, 26, 38.8, 61.6, 84] |  | Plasma |  |
| 1018 | p-c-reaktiivinenproteiini,hoitoyksikkö |  | 56% | name | 156 | 100 |  |  | Plasma |  |
| 1019 | p-c-reaktiivinenproteiini,pikatesti | mg/l | 6% | name+unit+values | 190 | 0 | [6, 7.07, 9, 13.46, 17.54, 24.16, 32.08, 50.25, 89.17] |  | Plasma |  |
| 1020 | p-c-reaktiivinenproteiini,pikatesti |  | 94% | name+values | 3095 | 100 | [6.4, 8.81, 12.02, 15.75, 21.21, 29.04, 42.26, 63.42, 97.39] |  | Plasma |  |
| 1021 | p-c-reaktiivinenproteiini,vieritutkimus | mg/l | 30% | name+unit | 53 | 0 |  |  | Plasma |  |
| 1022 | p-c-reaktiivinenproteiini,vieritutkimus |  | 70% | name | 122 | 100 |  |  | Plasma |  |
| 1023 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 63% | name+unit+values | 202 | 0 | [4.07, 6.94, 10.45, 16.41, 21.83, 29.61, 49.9, 68.72, 99.83] |  | Plasma |  |
| 1024 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 37% | name | 120 | 100 |  |  | Plasma |  |
| 1025 | p-c-reaktiivinenproteiini.pika |  | 100% | name+values | 316 | 100 | [2, 5.1, 8.74, 12.93, 19.35, 31.57, 53.66, 84.04, 111.82] |  | Plasma |  |
| 1026 | p-c-reaktiivinenproteiinipikahoitoyksiköt | mg/l | 71% | name+unit+values | 4601 | 0 | [5.18, 8.04, 12.05, 17.39, 25.78, 37.53, 54.69, 78.04, 114.03] |  | Plasma |  |
| 1027 | p-c-reaktiivinenproteiinipikahoitoyksiköt |  | 29% | name+values | 1925 | 100 | [1.19, 1.37, 1.77, 2.35, 2.97, 4.11, 5.47, 6.48, 8.22] |  | Plasma |  |
| 1028 | p-c-reaktiivinenproteiinipikamittari |  | 100% | name+values | 399 | 100 | [7, 9, 13, 21.24, 29.31, 41.92, 59.31, 82.22, 121.8] |  | Plasma |  |
| 1029 | pikatesti,c-reaktiivinenproteiini | mg/l | 45% | name+unit+values | 315 | 0 | [6, 7.89, 10.58, 14.45, 20.43, 30.94, 44.31, 61.05, 91] |  |  |  |
| 1030 | pikatesti,c-reaktiivinenproteiini |  | 55% | name | 386 | 100 |  |  |  |  |
| 1031 | plasmanc-reaktiivinenproteiiniosoitus | 1 | 1% | name+unit | 36 | 0 |  |  |  |  |
| 1032 | plasmanc-reaktiivinenproteiiniosoitus | mg/l | 55% | name+unit+values | 3255 | 0 | [6.38, 8.92, 12.54, 17.7, 25.56, 35.77, 50.77, 70.37, 106.61] |  |  |  |
| 1033 | plasmanc-reaktiivinenproteiiniosoitus |  | 44% | name | 2589 | 100 |  |  |  |  |
| 1034 | s-c-reaktiivinenproteiini | mg/l | 86% | name+unit+values | 773 | 0 | [0.4, 0.73, 1.09, 1.42, 1.93, 2.88, 4.68, 7.14, 16.59] |  | Serum |  |
| 1035 | s-c-reaktiivinenproteiini |  | 14% | name | 121 | 100 |  |  | Serum |  |
| 1036 | s-c-reaktiivinenproteiini,herkkä | mg/l | 96% | name+unit+values | 813 | 0 | [0.39, 0.59, 0.81, 1.22, 1.68, 2.46, 3.64, 5.7, 8.99] |  | Serum |  |
| 1037 | s-c-reaktiivinenproteiini,herkkä |  | 4% | name | 34 | 100 |  |  | Serum |  |
| 1038 | s-c-reaktiivinenproteiini,pika | mg/l | 28% | name+unit+values | 77 | 0 | [8, 10, 12.53, 14.7, 17, 20, 27.67, 35, 48] |  | Serum |  |
| 1039 | s-c-reaktiivinenproteiini,pika |  | 72% | name | 199 | 100 |  |  | Serum |  |
| 1040 | s-c-reaktiivinenproteiini/ | mg/l | 100% | name+unit+values | 191 | 0 | [0.31, 0.5, 0.71, 0.96, 1.48, 2.27, 3.05, 4.68, 10.07] |  | Serum |  |

