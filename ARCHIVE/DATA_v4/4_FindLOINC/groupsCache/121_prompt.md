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
Here is group 121 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 9944 | cu-alb-mi | ug/min | 80% | name+unit+values | 7258 | 0.01 | [2.01, 3.06, 4.68, 7.09, 11.88, 22.58, 45.52, 98.32, 249.52] | cU-Albumiini, mikroalbuminuria | Collected urine | Micro |
| 9945 | cu-alb-mi |  | 20% | name | 1830 | 100 |  | cU-Albumiini, mikroalbuminuria | Collected urine | Micro |
| 9946 | e-coli. |  | 100% | name | 930 | 100 |  |  | Erythrocyte |  |
| 9947 | f-para-o |  | 100% | name | 16222 | 100 |  | F -Parasiitit (kval) | Feces | Qualitative test (also semi-quantitative) |
| 9948 | nu-alb-mi | mg/12h | 4% | name+unit | 12 | 0 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro |
| 9949 | nu-alb-mi | ug/min | 48% | name+unit+values | 155 | 0 | [4.6, 8.83, 19.33, 34.27, 68, 107.86, 175.14, 311.43, 536.5] | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro |
| 9950 | nu-alb-mi |  | 48% | name | 157 | 100 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro |
| 9951 | nu-albkre | mg/mmol | 17% | name+unit+values | 438 | 0 | [0.3, 0.49, 0.64, 0.9, 1.29, 2.02, 4.14, 8.64, 23.01] |  | Night (morning) urine |  |
| 9952 | nu-albkre |  | 83% | name+values | 2191 | 100 | [0.39, 0.5, 0.69, 0.88, 1.21, 1.8, 2.91, 6.37, 18.94] |  | Night (morning) urine |  |
| 9953 | nu-albkrea | mg/mmol | 44% | name+unit+values | 20929 | 0 | [0.3, 0.42, 0.59, 0.82, 1.19, 1.86, 3.33, 7.3, 23.5] |  | Night (morning) urine |  |
| 9954 | nu-albkrea |  | 56% | name | 26197 | 100 |  |  | Night (morning) urine |  |
| 9955 | p-seulkre |  | 100% | name | 277 | 100 |  |  | Plasma |  |
| 9956 | u-a1mikre |  | 100% | name+values | 113 | 100 | [1, 2.45, 3.7, 6.95, 9, 11.14, 14.58, 17.92, 35.1] |  | Urine |  |
| 9957 | u-alb-0 |  | 100% | name | 992 | 100 |  |  | Urine |  |
| 9958 | u-alb-lb | mg/l | 58% | name+unit | 70 | 0 |  |  | Urine |  |
| 9959 | u-alb-lb |  | 42% | name | 50 | 100 |  |  | Urine |  |
| 9960 | u-alb-mi | mg/l | 71% | name+unit+values | 7488 | 0 | [3, 3.95, 5.25, 7.22, 10.53, 17.06, 32.59, 75.32, 297.66] |  | Urine | Micro |
| 9961 | u-alb-mi |  | 29% | name | 3031 | 100 |  |  | Urine | Micro |
| 9962 | u-alb-o | estimate | 34% | name+unit+values | 161670 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 9963 | u-alb-o | form | 0% | name+unit+values | 287 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 9964 | u-alb-o |  | 66% | name | 312867 | 100 |  | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 9965 | u-alb/kre | g/mol | 3% | name+unit+values | 142 | 0 | [1.8, 3.05, 3.89, 5.37, 8.29, 16.27, 32.91, 51.96, 140.67] |  | Urine |  |
| 9966 | u-alb/kre | mg/mmol | 50% | name+unit+values | 2591 | 0 | [0.3, 0.42, 0.6, 0.84, 1.25, 2.06, 4.01, 8.97, 30.06] |  | Urine |  |
| 9967 | u-alb/kre |  | 48% | name | 2491 | 100 |  |  | Urine |  |
| 9968 | u-alb/krea | g/mol | 3% | name+unit | 49 | 0 |  |  | Urine |  |
| 9969 | u-alb/krea | mg/mmol | 51% | name+unit+values | 879 | 0 | [0.29, 0.4, 0.53, 0.74, 1.07, 1.82, 2.9, 5.82, 14.81] |  | Urine |  |
| 9970 | u-alb/krea |  | 47% | name | 812 | 100 |  |  | Urine |  |
| 9971 | u-albkre | mg/mmol | 60% | name+unit+values | 294883 | 0 | [0.3, 0.5, 0.68, 0.99, 1.55, 2.76, 5.6, 13.95, 52.37] | U -Albumiinin ja kreatiniinin suhde | Urine |  |
| 9972 | u-albkre |  | 40% | name | 200553 | 100 |  | U -Albumiinin ja kreatiniinin suhde | Urine |  |
| 9973 | u-albkrea | mg/mmol | 40% | name+unit+values | 10590 | 0 | [0.3, 0.44, 0.58, 0.73, 0.97, 1.32, 1.85, 3.04, 9.5] |  | Urine |  |
| 9974 | u-albkrea | mg/mmol/l | 0% | name+unit | 81 | 0 |  |  | Urine |  |
| 9975 | u-albkrea |  | 59% | name+values | 15486 | 100 | [0.4, 0.65, 1.07, 1.97, 3.4, 4.95, 7.8, 14.39, 37.94] |  | Urine |  |
| 9976 | u-alvhu4a |  | 100% | name | 760 | 100 |  |  | Urine |  |
| 9977 | u-alvhu5b |  | 100% | name | 912 | 100 |  |  | Urine |  |
| 9978 | u-alvhu6a |  | 100% | name | 1273 | 100 |  |  | Urine |  |
| 9979 | u-barb-o |  | 100% | name | 1791 | 100 |  | U -Barbituraatit (kval) | Urine | Qualitative test (also semi-quantitative) |
| 9980 | u-bupre-0 |  | 100% | name | 642 | 100 |  |  | Urine |  |
| 9981 | u-bupre-o | estimate | 0% | name+unit | 207 | 0 |  | U -Buprenorfiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 9982 | u-bupre-o |  | 100% | name | 44187 | 100 |  | U -Buprenorfiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 9983 | u-buprect |  | 100% | name | 1841 | 100 |  | U -Buprenorfiini, varmistus | Urine |  |
| 9984 | u-cakre |  | 100% | name | 106 | 100 |  |  | Urine |  |
| 9985 | u-color |  | 100% | name | 160 | 100 |  |  | Urine |  |
| 9986 | u-dxpro-o |  | 100% | name | 125 | 100 |  | U -Dekstropropoksifeeni, seulonta (kval) | Urine | Qualitative test (also semi-quantitative) |
| 9987 | u-eddp-o |  | 100% | name | 266 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) |
| 9988 | u-huum-10 |  | 100% | name | 109 | 100 |  |  | Urine |  |
| 9989 | u-huum-ct |  | 100% | name | 1643 | 100 |  |  | Urine | Confirmation, confirmatory test |
| 9990 | u-huum-o |  | 100% | name | 36546 | 100 |  | U -Huumeseulonta (kval) | Urine | Qualitative test (also semi-quantitative) |
| 9991 | u-huum-op |  | 100% | name | 163 | 100 |  |  | Urine |  |
| 9992 | u-huum-ps |  | 100% | name | 160 | 100 |  |  | Urine | Basic screening |
| 9993 | u-huum-su |  | 100% | name | 1133 | 100 |  |  | Urine |  |
| 9994 | u-huum4a |  | 100% | name | 118 | 100 |  |  | Urine |  |
| 9995 | u-huum5b |  | 100% | name | 128 | 100 |  |  | Urine |  |
| 9996 | u-huum6a |  | 100% | name | 241 | 100 |  |  | Urine |  |
| 9997 | u-huume-5b |  | 100% | name | 169 | 100 |  |  | Urine |  |
| 9998 | u-huume-6a |  | 100% | name | 115 | 100 |  |  | Urine |  |
| 9999 | u-huume-o |  | 100% | name | 425 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) |
| 10000 | u-huuml-o | form | 0% | name+unit | 6 | 0 |  | U -Huume- ja lääkeaineseulonta (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10001 | u-huuml-o |  | 100% | name | 1648 | 100 |  | U -Huume- ja lääkeaineseulonta (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10002 | u-huumlct | form | 0% | name+unit | 9 | 0 |  | U -Huume- ja lääkeainetutkimus, laaja, varmistus | Urine |  |
| 10003 | u-huumlct |  | 100% | name | 16104 | 100 |  | U -Huume- ja lääkeainetutkimus, laaja, varmistus | Urine |  |
| 10004 | u-huumoct |  | 100% | name | 1367 | 100 |  |  | Urine |  |
| 10005 | u-huumpika |  | 100% | name | 805 | 100 |  |  | Urine |  |
| 10006 | u-huumtof |  | 100% | name | 2536 | 100 |  |  | Urine |  |
| 10007 | u-huupika |  | 100% | name | 137 | 100 |  |  | Urine |  |
| 10008 | u-hyalie | e6/l | 97% | name+unit+values | 15276 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.18, 1] |  | Urine |  |
| 10009 | u-hyalie |  | 3% | name | 467 | 100 |  |  | Urine |  |
| 10010 | u-hyalier | e6/l | 93% | name+unit+values | 11469 | 0 | [0, 0, 0, 0, 0, 0.07, 0.1, 0.3, 0.59] |  | Urine |  |
| 10011 | u-hyalier | u/field | 1% | name+unit+values | 109 | 0 | [0, 1, 1, 1, 1, 1, 1, 1, 2] |  | Urine |  |
| 10012 | u-hyalier |  | 7% | name+values | 816 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0.39] |  | Urine |  |
| 10013 | u-hyallie | e6/l | 100% | name+unit+values | 146 | 0 | [0, 0, 0, 0, 0.1, 0.16, 0.39, 0.61, 1.03] |  | Urine |  |
| 10014 | u-inh-o |  | 100% | name | 124 | 100 |  | U -Isoniatsidi (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10015 | u-koka-o | estimate | 0% | name+unit | 206 | 0 |  | U -Kokaiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10016 | u-koka-o |  | 100% | name | 50285 | 100 |  | U -Kokaiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10017 | u-levyep | e6/l | 95% | name+unit+values | 217342 | 0 | [0, 0, 0, 0, 0.52, 1, 2.01, 4.09, 9.83] |  | Urine |  |
| 10018 | u-levyep | u/field | 0% | name+unit+values | 396 | 0 | [0, 0.82, 1, 1, 1, 1, 1, 1.89, 2.75] |  | Urine |  |
| 10019 | u-levyep |  | 5% | name | 10431 | 100 |  |  | Urine |  |
| 10020 | u-levyepi | e6/l | 1% | name+unit | 14 | 0 |  |  | Urine |  |
| 10021 | u-levyepi | u/field | 90% | name+unit+values | 1272 | 0 | [0, 0, 0, 0, 0, 0.89, 1, 1, 2] |  | Urine |  |
| 10022 | u-levyepi |  | 9% | name | 131 | 100 |  |  | Urine |  |
| 10023 | u-lier | e6/l | 99% | name+unit+values | 351179 | 0 | [0, 0, 0, 0, 0, 0, 0.11, 1, 2.09] |  | Urine |  |
| 10024 | u-lier |  | 1% | name | 4775 | 100 |  |  | Urine |  |
| 10025 | u-lierla | e6/l | 97% | name+unit+values | 2609 | 0.04 | [0, 0, 0, 0, 0, 0, 0, 0.76, 1] |  | Urine |  |
| 10026 | u-lierla |  | 3% | name | 67 | 100 |  |  | Urine |  |
| 10027 | u-mdma-o |  | 100% | name | 7294 | 100 |  | U -Metyleenidioksimetamfetamiini (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10028 | u-muulier | e6/l | 93% | name+unit+values | 11537 | 0 | [0, 0, 0, 0, 0, 0, 0.12, 0.16, 0.42] |  | Urine |  |
| 10029 | u-muulier |  | 7% | name+values | 846 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0.13] |  | Urine |  |
| 10030 | u-odling |  | 100% | name | 238 | 100 |  |  | Urine |  |
| 10031 | u-oksik-o |  | 100% | name | 3802 | 100 |  | U -Oksikodoni (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10032 | u-oxy-o |  | 100% | name | 284 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) |
| 10033 | u-paras-o |  | 100% | name | 629 | 100 |  | U -Parasetamoli (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10034 | u-pbg-o |  | 100% | name | 213 | 100 |  | U -Porfobilinogeeni (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10035 | u-ph-0 |  | 100% | name+values | 1803 | 100 | [5, 5.47, 5.5, 5.51, 6, 6, 6.45, 6.93, 7] |  | Urine |  |
| 10036 | u-ph-huu |  | 100% | name+values | 13233 | 100 | [5.15, 5.5, 5.88, 6, 6.48, 6.5, 6.96, 7, 7.5] |  | Urine |  |
| 10037 | u-ph-hy |  | 100% | name+values | 2442 | 100 | [5.42, 5.5, 5.5, 5.74, 6, 6.02, 6.5, 7, 7] |  | Urine |  |
| 10038 | u-ph-o | ph | 99% | name+unit+values | 52493 | 0 | [5.19, 5.5, 5.91, 6, 6.12, 6.5, 6.94, 7, 7.46] | U -Happamuusaste (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10039 | u-ph-o |  | 1% | name | 583 | 100 |  | U -Happamuusaste (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10040 | u-phhu |  | 100% | name | 170 | 100 |  |  | Urine |  |
| 10041 | u-pien.ep | e6/l | 95% | name+unit+values | 999 | 0 | [0.02, 0.1, 0.2, 0.4, 0.51, 0.8, 1.11, 1.7, 3.08] |  | Urine |  |
| 10042 | u-pien.ep |  | 5% | name | 55 | 100 |  |  | Urine |  |
| 10043 | u-pienep | e6/l | 96% | name+unit+values | 200789 | 0 | [0, 0, 0, 0, 0, 0.87, 1, 2, 3.84] |  | Urine |  |
| 10044 | u-pienep |  | 4% | name | 9215 | 100 |  |  | Urine |  |
| 10045 | u-prokre | g/mol | 28% | name+unit+values | 973 | 0 | [5.07, 7, 8.95, 11.09, 14.48, 19.43, 27.53, 52.62, 161.41] | U -Proteiinin ja kreatiniinin suhde | Urine |  |
| 10046 | u-prokre | mg/mmol | 53% | name+unit+values | 1813 | 0 | [9.65, 12.63, 16.22, 21.15, 31.06, 49.02, 103.19, 281.58, 1013.51] | U -Proteiinin ja kreatiniinin suhde | Urine |  |
| 10047 | u-prokre |  | 19% | name | 646 | 100 |  | U -Proteiinin ja kreatiniinin suhde | Urine |  |
| 10048 | u-protkre | mg/mmol | 100% | name+unit | 121 | 0 |  |  | Urine |  |
| 10049 | u-seul-os |  | 100% | name | 186 | 100 |  |  | Urine |  |
| 10050 | u-seul.hy |  | 100% | name | 447 | 100 |  |  | Urine |  |
| 10051 | u-seulakr |  | 100% | name | 270 | 100 |  |  | Urine |  |
| 10052 | u-suht-hy |  | 100% | name+values | 2336 | 100 | [1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02, 1.02] |  | Urine |  |
| 10053 | u-suhti | form | 0% | name+unit | 38 | 0 |  | U -Suhteellinen tiheys | Urine |  |
| 10054 | u-suhti | kg/l | 90% | name+unit+values | 307915 | 0 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.03] | U -Suhteellinen tiheys | Urine |  |
| 10055 | u-suhti | ratio | 0% | name+unit+values | 570 | 0 | [1, 1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02] | U -Suhteellinen tiheys | Urine |  |
| 10056 | u-suhti |  | 10% | name | 32697 | 100 |  | U -Suhteellinen tiheys | Urine |  |
| 10057 | u-suhti-o | ratio | 100% | name+unit+values | 47144 | 0 | [1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02, 1.03] |  | Urine | Qualitative test (also semi-quantitative) |
| 10058 | u-suhti. | ratio | 100% | name+unit+values | 24646 | 0 | [1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02] |  | Urine |  |
| 10059 | u-suhtih | kg/l | 83% | name+unit+values | 46601 | 0 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02] |  | Urine |  |
| 10060 | u-suhtih |  | 17% | name | 9841 | 100 |  |  | Urine |  |
| 10061 | u-suhtih-o |  | 100% | name+values | 141 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.03] |  | Urine | Qualitative test (also semi-quantitative) |
| 10062 | u-suhtihu |  | 100% | name | 161 | 100 |  |  | Urine |  |
| 10063 | u-suhtiv |  | 100% | name+values | 766 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02] |  | Urine |  |
| 10064 | u-trama-o |  | 100% | name | 4881 | 100 |  | U -Tramadoli (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10065 | u-trisy-o |  | 100% | name | 4379 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) |
| 10066 | u-tryp2-o |  | 100% | name | 148 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) |
| 10067 | u-tub.ep | /sunf | 6% | name+unit+values | 127 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  |
| 10068 | u-tub.ep |  | 94% | name | 2024 | 100 |  |  | Urine |  |
| 10069 | u-tubulep | u/field | 68% | name+unit+values | 123 | 0 | [0, 1, 1, 1, 1, 1, 1, 1, 2] |  | Urine |  |
| 10070 | u-tubulep |  | 32% | name | 58 | 100 |  |  | Urine |  |
| 10071 | u-ubg-o |  | 100% | name | 584 | 100 |  | U -Urobilinogeeni (kval) | Urine | Qualitative test (also semi-quantitative) |
| 10072 | u-väliepi | u/field | 93% | name+unit+values | 194 | 0 | [0, 0, 0, 0, 1, 1, 1, 1, 2] |  | Urine |  |
| 10073 | u-väliepi |  | 7% | name | 15 | 100 |  |  | Urine |  |
| 10074 | u-välimep | u/field | 71% | name+unit+values | 200 | 0 | [1, 1, 1, 1, 1, 1, 1, 1, 2] |  | Urine |  |
| 10075 | u-välimep |  | 29% | name | 81 | 100 |  |  | Urine |  |
| 10076 | u-överg.ep | /sunf | 6% | name+unit+values | 124 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  |
| 10077 | u-överg.ep |  | 94% | name | 2027 | 100 |  |  | Urine |  |

