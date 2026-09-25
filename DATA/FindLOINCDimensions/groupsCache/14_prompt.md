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
Here is group 14 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 965 | b-c-reaktiivinenproteiini | mg/l | 10% | name+unit | 29 | 0 |  |  | Blood |  |
| 966 | b-c-reaktiivinenproteiini |  | 90% | name+values | 262 | 44.27 | [6, 7.5, 10.67, 13.8, 18.67, 27.69, 37.44, 56, 84] |  | Blood |  |
| 967 | b-c-reaktiivinenproteiinipika |  | 100% | name+values | 300 | 37 | [7, 10.22, 14.84, 20.3, 29.2, 37.52, 52.47, 75.48, 99.1] |  | Blood |  |
| 968 | b-c-resktiivinenproteiini | mg/l | 60% | name+unit+values | 1201 | 0 | [6, 8.11, 11.16, 14.7, 19.67, 26.61, 38.65, 58.3, 91.79] |  | Blood |  |
| 969 | b-c-resktiivinenproteiini |  | 40% | name | 802 | 92.39 |  |  | Blood |  |
| 970 | c-reaktiivinenproteiini | 1 | 6% | name+unit+values | 925 | 0 | [6.19, 8.89, 11.99, 16.88, 23.76, 35.33, 49.12, 74.41, 108.21] |  |  |  |
| 971 | c-reaktiivinenproteiini | mg/l | 50% | name+unit+values | 7963 | 0 | [4.01, 6.22, 9.5, 14.46, 23.15, 35.25, 51.85, 77.94, 126.36] |  |  |  |
| 972 | c-reaktiivinenproteiini |  | 44% | name+values | 7083 | 90.23 | [6.55, 8.84, 11.73, 17.15, 24.37, 37.67, 52.72, 72.92, 107.1] |  |  |  |
| 973 | c-reaktiivinenproteiini(4594p-crp) | mg/l | 66% | name+unit+values | 143 | 0 | [1, 1.79, 2, 2, 3, 4, 5, 6, 12.8] |  |  |  |
| 974 | c-reaktiivinenproteiini(4594p-crp) |  | 34% | name | 74 | 100 |  |  |  |  |
| 975 | c-reaktiivinenproteiini(crp) | mg/l | 60% | name+unit+values | 381 | 0 | [1.23, 1.51, 1.92, 2.62, 3.36, 4.75, 6.13, 9.98, 21.06] |  |  |  |
| 976 | c-reaktiivinenproteiini(crp) |  | 40% | name | 250 | 100 |  |  |  |  |
| 977 | c-reaktiivinenproteiini(p-crp) | mg/l | 66% | name+unit+values | 500 | 0 | [1, 2, 2, 2.85, 3.14, 4.26, 5.94, 8.93, 19.54] |  |  |  |
| 978 | c-reaktiivinenproteiini(p-crp) |  | 34% | name | 261 | 100 |  |  |  |  |
| 979 | c-reaktiivinenproteiini,herkkä | mg/l | 93% | name+unit+values | 254 | 0 | [0.22, 0.41, 0.57, 0.84, 1.15, 1.65, 2.42, 3.86, 6.33] |  |  |  |
| 980 | c-reaktiivinenproteiini,herkkä |  | 7% | name | 18 | 94.44 |  |  |  |  |
| 981 | c-reaktiivinenproteiini,herkkä,seerumista | mg/l | 100% | name+unit+values | 7396 | 0 | [0.28, 0.41, 0.6, 0.78, 1.03, 1.34, 1.83, 2.72, 4.64] |  |  |  |
| 982 | c-reaktiivinenproteiini,herkkä,seerumista |  | 0% | name | 36 | 83.33 |  |  |  |  |
| 983 | c-reaktiivinenproteiini,pika | mg/l | 69% | name+unit+values | 111 | 0 | [5, 5.05, 6.2, 8.27, 11.67, 14.3, 22.37, 36.1, 57] |  |  |  |
| 984 | c-reaktiivinenproteiini,pika |  | 31% | name | 49 | 100 |  |  |  |  |
| 985 | c-reaktiivinenproteiini,pika,tehdäänitse | mg/l | 55% | name+unit+values | 997 | 0 | [5, 5, 6.35, 8.12, 10.93, 14.99, 21.14, 34.44, 53.73] |  |  |  |
| 986 | c-reaktiivinenproteiini,pika,tehdäänitse |  | 45% | name | 820 | 99.27 |  |  |  |  |
| 987 | c-reaktiivinenproteiini,pikatesti,veri | mg/l | 10% | name+unit+values | 174 | 0 | [6, 7, 8.95, 10.5, 16.42, 22.45, 35.5, 53.5, 98.67] |  |  |  |
| 988 | c-reaktiivinenproteiini,pikatesti,veri |  | 90% | name+values | 1656 | 42.69 | [6.55, 9.61, 13.21, 19.27, 27.67, 39.17, 52.81, 73.29, 109.39] |  |  |  |
| 989 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) | mg/l | 77% | name+unit+values | 803 | 0 | [4.99, 5.34, 7.17, 9.24, 13.4, 18.77, 28.88, 45.54, 76.31] |  |  |  |
| 990 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) |  | 23% | name | 240 | 100 |  |  |  |  |
| 991 | c-reaktiivinenproteiini,pikatutkimus | mg/l | 62% | name+unit+values | 106 | 0 | [7, 12, 15.43, 21.6, 30.72, 39.4, 56.9, 87, 115.33] |  |  |  |
| 992 | c-reaktiivinenproteiini,pikatutkimus |  | 38% | name | 66 | 100 |  |  |  |  |
| 993 | c-reaktiivinenproteiini,plasmasta,vieritesti | mg/l | 72% | name+unit+values | 699 | 0 | [5.17, 7.91, 10.75, 16.58, 23.68, 33.24, 48.01, 64.98, 99.29] |  |  |  |
| 994 | c-reaktiivinenproteiini,plasmasta,vieritesti |  | 28% | name | 274 | 94.89 |  |  |  |  |
| 995 | c-reaktiivinenproteiini,tk:ntekemä |  | 100% | name+values | 1605 | 13.4 | [2.23, 4.3, 7.78, 12.46, 19.91, 29.72, 46.58, 66.7, 98.89] |  |  |  |
| 996 | c-reaktiivinenproteiini,vieritesti | mg/l | 5% | name+unit | 47 | 0 |  |  |  |  |
| 997 | c-reaktiivinenproteiini,vieritesti |  | 95% | name+values | 944 | 23.62 | [3.08, 5.45, 7.93, 11.11, 14.9, 20.87, 29.7, 49.04, 81.9] |  |  |  |
| 998 | c-reaktiivinenproteiini,vieritutkimus | mg/l | 45% | name+unit+values | 525 | 0 | [5, 6.72, 8.66, 12.22, 15.93, 22.09, 35.26, 59.08, 89.7] |  |  |  |
| 999 | c-reaktiivinenproteiini,vieritutkimus |  | 55% | name+values | 631 | 58.8 | [6.41, 9.32, 15.53, 22.99, 35.64, 49.47, 62.97, 81.83, 113.06] |  |  |  |
| 1000 | c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 79% | name+unit | 1205 | 0 |  |  |  |  |
| 1001 | c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 21% | name+values | 318 | 100 | [4.71, 7.37, 11.52, 16.21, 23.22, 31.65, 45.13, 65.98, 97.07] |  |  |  |
| 1002 | c-reaktiivinenproteiini,vieritutkimusnordlab | mg/l | 48% | name+unit+values | 92 | 0 | [5, 6, 8, 10.7, 12.75, 16.2, 21, 31.5, 47] |  |  |  |
| 1003 | c-reaktiivinenproteiini,vieritutkimusnordlab |  | 52% | name | 99 | 100 |  |  |  |  |
| 1004 | c-reaktiivinenproteiini-pika(4594crp-pika) | mg/l | 74% | name+unit+values | 136 | 0 | [5, 5.32, 7, 9, 11.15, 14.57, 19, 33.2, 47.3] |  |  |  |
| 1005 | c-reaktiivinenproteiini-pika(4594crp-pika) |  | 26% | name | 47 | 100 |  |  |  |  |
| 1006 | c-reaktiivinenproteiini-pika(crp-pika) | mg/l | 75% | name+unit+values | 1488 | 0 | [5, 6.88, 7, 7.34, 10.21, 14.71, 21.39, 32, 54.73] |  |  |  |
| 1007 | c-reaktiivinenproteiini-pika(crp-pika) |  | 25% | name | 505 | 99.8 |  |  |  |  |
| 1008 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä | mg/l | 79% | name+unit+values | 1826 | 0 | [1.75, 3.02, 5.68, 9.52, 14.27, 22.77, 34.19, 57.29, 89.46] |  |  |  |
| 1009 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä |  | 21% | name+values | 497 | 46.88 | [1.2, 1.53, 2.21, 2.84, 3.97, 4.8, 6.15, 7.51, 9.1] |  |  |  |
| 1010 | fs-c-reaktiivinenproteiini | mg/l | 57% | name+unit | 241 | 0 |  |  | Fasting serum |  |
| 1011 | fs-c-reaktiivinenproteiini |  | 43% | name | 184 | 100 |  |  | Fasting serum |  |
| 1012 | p-c-reaktiininenproteiini,vieritutkimus | mg/l | 54% | name+unit+values | 258 | 0 | [5.85, 8.85, 11.14, 17.24, 24.49, 35.17, 49.34, 67.54, 96.38] |  | Plasma |  |
| 1013 | p-c-reaktiininenproteiini,vieritutkimus |  | 46% | name | 224 | 100 |  |  | Plasma |  |
| 1014 | p-c-reaktiivinenproteiini | mg/l | 62% | name+unit+values | 41046 | 0 | [4.18, 7.12, 11.73, 18.09, 27.46, 40.11, 58.4, 87.78, 141.39] |  | Plasma |  |
| 1015 | p-c-reaktiivinenproteiini |  | 38% | name | 24714 | 99.73 |  |  | Plasma |  |
| 1016 | p-c-reaktiivinenproteiini(kval) | mg/l | 57% | name+unit+values | 187 | 0 | [6.14, 9.01, 13.88, 18.86, 24.62, 33.54, 47.21, 67.37, 102.4] |  | Plasma |  |
| 1017 | p-c-reaktiivinenproteiini(kval) |  | 43% | name | 142 | 100 |  |  | Plasma |  |
| 1018 | p-c-reaktiivinenproteiini(kval)␤ | mg/l | 46% | name+unit | 111 | 0 |  |  | Plasma |  |
| 1019 | p-c-reaktiivinenproteiini(kval)␤ |  | 54% | name | 130 | 100 |  |  | Plasma |  |
| 1020 | p-c-reaktiivinenproteiini(pikanäyte) | mg/l | 2% | name+unit | 6 | 0 |  |  | Plasma |  |
| 1021 | p-c-reaktiivinenproteiini(pikanäyte) |  | 98% | name+values | 352 | 17.33 | [1.52, 2.59, 4.86, 7.54, 12.38, 20.91, 32.04, 56.93, 83.62] |  | Plasma |  |
| 1022 | p-c-reaktiivinenproteiini,crp | mg/l | 93% | name+unit | 110 | 0 |  |  | Plasma |  |
| 1023 | p-c-reaktiivinenproteiini,crp |  | 7% | name | 8 | 62.5 |  |  | Plasma |  |
| 1024 | p-c-reaktiivinenproteiini,hoitoyksikkö | 1 | 14% | name+unit | 40 | 0 |  |  | Plasma |  |
| 1025 | p-c-reaktiivinenproteiini,hoitoyksikkö | alle | 2% | name+unit | 5 | 0 |  |  | Plasma |  |
| 1026 | p-c-reaktiivinenproteiini,hoitoyksikkö | mg/l | 29% | name+unit+values | 81 | 0 | [8, 11, 13, 16.2, 22.25, 33.7, 48, 64, 131] |  | Plasma |  |
| 1027 | p-c-reaktiivinenproteiini,hoitoyksikkö |  | 55% | name+values | 156 | 63.46 | [6, 8, 12, 14, 26, 32, 40, 60, 120] |  | Plasma |  |
| 1028 | p-c-reaktiivinenproteiini,pikatesti | mg/l | 6% | name+unit | 190 | 0 |  |  | Plasma |  |
| 1029 | p-c-reaktiivinenproteiini,pikatesti |  | 94% | name+values | 3095 | 41.23 | [6.43, 8.8, 12.04, 15.76, 21.17, 29.16, 41.93, 63.64, 96.9] |  | Plasma |  |
| 1030 | p-c-reaktiivinenproteiini,vieritutkimus | mg/l | 30% | name+unit | 53 | 0 |  |  | Plasma |  |
| 1031 | p-c-reaktiivinenproteiini,vieritutkimus |  | 70% | name | 122 | 50.82 |  |  | Plasma |  |
| 1032 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 63% | name+unit+values | 202 | 0 | [4.03, 6.98, 10.47, 16.6, 21.86, 29.42, 49.79, 68.66, 100] |  | Plasma |  |
| 1033 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 37% | name | 120 | 71.67 |  |  | Plasma |  |
| 1034 | p-c-reaktiivinenproteiini.pika |  | 100% | name+values | 316 | 20.25 | [3.75, 6.98, 11.68, 15.55, 24.24, 38.44, 58.74, 89.38, 117.91] |  | Plasma |  |
| 1035 | p-c-reaktiivinenproteiinipikahoitoyksiköt | mg/l | 71% | name+unit+values | 4601 | 0 | [5.2, 7.99, 12.13, 17.43, 25.81, 37.54, 54.45, 78.12, 113.86] |  | Plasma |  |
| 1036 | p-c-reaktiivinenproteiinipikahoitoyksiköt |  | 29% | name+values | 1925 | 80.52 | [1.18, 1.4, 1.83, 2.44, 3.17, 4.31, 5.83, 6.68, 8.76] |  | Plasma |  |
| 1037 | p-c-reaktiivinenproteiinipikamittari |  | 100% | name+values | 399 | 36.09 | [7, 9.06, 12.92, 21.23, 28.43, 42.17, 58.76, 81.22, 122.07] |  | Plasma |  |
| 1038 | pikatesti,c-reaktiivinenproteiini | mg/l | 45% | name+unit+values | 315 | 0 | [6, 7.85, 10.56, 14.36, 20.22, 31.25, 44.62, 61.43, 91.59] |  |  |  |
| 1039 | pikatesti,c-reaktiivinenproteiini |  | 55% | name | 386 | 100 |  |  |  |  |
| 1040 | plasmanc-reaktiivinenproteiiniosoitus | 1 | 1% | name+unit | 36 | 0 |  |  |  |  |
| 1041 | plasmanc-reaktiivinenproteiiniosoitus | mg/l | 55% | name+unit+values | 3255 | 0 | [6.24, 8.99, 12.45, 17.72, 25.65, 35.96, 50.8, 70.36, 106.56] |  |  |  |
| 1042 | plasmanc-reaktiivinenproteiiniosoitus |  | 44% | name | 2589 | 98.42 |  |  |  |  |
| 1043 | s-c-reaktiivinenproteiini | mg/l | 86% | name+unit+values | 773 | 0 | [0.4, 0.73, 1.08, 1.43, 1.93, 2.88, 4.71, 7.16, 16.64] |  | Serum |  |
| 1044 | s-c-reaktiivinenproteiini |  | 14% | name | 121 | 100 |  |  | Serum |  |
| 1045 | s-c-reaktiivinenproteiini,herkkä | mg/l | 96% | name+unit+values | 813 | 0 | [0.39, 0.59, 0.83, 1.22, 1.67, 2.46, 3.62, 5.63, 9.01] |  | Serum |  |
| 1046 | s-c-reaktiivinenproteiini,herkkä |  | 4% | name | 34 | 100 |  |  | Serum |  |
| 1047 | s-c-reaktiivinenproteiini,pika | mg/l | 28% | name+unit+values | 77 | 0 | [8, 10, 12.4, 14.7, 17, 20.05, 27.4, 35, 48] |  | Serum |  |
| 1048 | s-c-reaktiivinenproteiini,pika |  | 72% | name | 199 | 75.88 |  |  | Serum |  |
| 1049 | s-c-reaktiivinenproteiini/ | mg/l | 97% | name+unit+values | 191 | 0 | [0.31, 0.5, 0.7, 0.96, 1.46, 2.27, 3.04, 4.65, 10.16] |  | Serum |  |
| 1050 | s-c-reaktiivinenproteiini/ |  | 3% | name | 5 | 100 |  |  | Serum |  |

