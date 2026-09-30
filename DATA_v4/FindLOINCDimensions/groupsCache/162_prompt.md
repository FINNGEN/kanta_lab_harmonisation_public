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
Here is group 162 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 13068 | -cd4-solujensuhdecd8-soluihin |  | 100% | name+values | 667 | 0.3 | [0.26, 0.37, 0.55, 0.73, 1, 1.35, 1.81, 2.32, 3.03] |  |  |  |
| 13069 | -kt/v,daugirdaksenkaava |  | 100% | name+values | 176 | 0 | [1.13, 1.23, 1.29, 1.33, 1.39, 1.43, 1.46, 1.5, 1.57] |  |  |  |
| 13070 | -sieni,natiivivalmiste |  | 100% | name | 244 | 100 |  |  |  |  |
| 13071 | ab-aktuaalibikarbonaatti | mmol/l | 100% | name+unit+values | 14354 | 0 | [18.76, 21.02, 22.57, 23.76, 24.73, 25.7, 26.99, 28.55, 31.59] |  | Arterial blood |  |
| 13072 | ab-aktuaalibikarbonaatti |  | 0% | name | 47 | 100 |  |  | Arterial blood |  |
| 13073 | ab-lämpötila(he-tase) | aste | 100% | name+unit+values | 418 | 0 | [36.38, 36.95, 37, 37, 37, 37, 37.01, 37.48, 38.01] |  | Arterial blood |  |
| 13074 | ab-standardibikarbonaatti | mmol/l | 100% | name+unit+values | 4434 | 0 | [19.73, 21.71, 22.89, 23.76, 24.46, 25.22, 26.01, 27.04, 28.87] |  | Arterial blood |  |
| 13075 | ab-standardibikarbonaatti |  | 0% | name | 20 | 100 |  |  | Arterial blood |  |
| 13076 | alkalinenfosfataasi | u/l | 91% | name+unit+values | 4090 | 0 | [51.93, 59.73, 66.52, 72.54, 78.85, 86.09, 95.45, 111.37, 142.22] |  |  |  |
| 13077 | alkalinenfosfataasi |  | 9% | name | 409 | 100 |  |  |  |  |
| 13078 | angiotensiini-1-konvertaasi | u/l | 93% | name+unit+values | 286 | 0 | [21.5, 28.51, 36.37, 41.21, 48.76, 54.44, 63.62, 70.94, 80.3] |  |  |  |
| 13079 | angiotensiini-1-konvertaasi |  | 7% | name | 20 | 100 |  |  |  |  |
| 13080 | b-diffi,erittelylaskenta,klooni |  | 100% | name | 142 | 100 |  |  | Blood |  |
| 13081 | cb-standardibikarbonaatti | mmol/l | 99% | name+unit+values | 10798 | 0 | [20.28, 22.23, 23.36, 24.16, 24.9, 25.66, 26.58, 27.89, 30.19] |  | Capillary blood |  |
| 13082 | cb-standardibikarbonaatti |  | 1% | name | 90 | 50 |  |  | Capillary blood |  |
| 13083 | d-vitamiini-25-oh,d3-jad2-muodot | nmol/l | 100% | name+unit+values | 219 | 0 | [48.54, 55.58, 61.96, 68.73, 74.1, 79.27, 84.22, 89.91, 106.45] |  |  |  |
| 13084 | d-vitamiini-25-oh,plasmasta | nmol/l | 100% | name+unit+values | 694 | 0 | [44.59, 53.15, 59, 64.66, 69.89, 76.01, 82.54, 92.02, 105.7] |  |  |  |
| 13085 | e-punasolujenkokojakaum | % | 100% | name+unit+values | 55570 | 0 | [12.19, 12.59, 12.95, 13.26, 13.67, 14.09, 14.51, 14.98, 15.71] |  | Erythrocyte |  |
| 13086 | e-punasolujenkokojakaum |  | 0% | name | 7 | 71.43 |  |  | Erythrocyte |  |
| 13087 | e-punasolujenkokojakauma | % | 99% | name+unit+values | 196935 | 0 | [12, 13, 13, 13, 13.69, 14, 14.05, 15, 16.37] |  | Erythrocyte |  |
| 13088 | e-punasolujenkokojakauma |  | 1% | name+values | 1688 | 46.92 | [15, 15, 15.98, 16, 16, 16.41, 17, 18, 19.59] |  | Erythrocyte |  |
| 13089 | e-rdw,punasolujenkokojakauma | % | 100% | name+unit+values | 25929 | 0 | [12.08, 13, 13, 13.03, 14, 14, 15, 15.7, 17.03] |  | Erythrocyte |  |
| 13090 | e-rdw,punasolujenkokojakauma |  | 0% | name | 76 | 100 |  |  | Erythrocyte |  |
| 13091 | ekg,hoitoyksikönottama |  | 100% | name | 213 | 100 |  |  |  |  |
| 13092 | ekgasiakkaanottama |  | 100% | name | 257 | 100 |  |  |  |  |
| 13093 | erikoislääkärinkonsultaatio |  | 100% | name | 118 | 100 |  |  |  |  |
| 13094 | folaatti(fe-folaat) | nmol/l | 96% | name+unit+values | 320 | 0 | [1456.69, 1642.98, 1740.68, 1864.47, 2021, 2152.9, 2311.39, 2519.36, 2775.52] |  |  |  |
| 13095 | folaatti(fe-folaat) |  | 4% | name | 12 | 100 |  |  |  |  |
| 13096 | fosfaatti,epäorgaaninen | mmol/l | 95% | name+unit+values | 275 | 0 | [0.83, 0.93, 0.99, 1.05, 1.1, 1.15, 1.23, 1.36, 1.64] |  |  |  |
| 13097 | fosfaatti,epäorgaaninen |  | 5% | name | 13 | 100 |  |  |  |  |
| 13098 | fp-fosfaatti,epäorgaaninen | mmol/l | 100% | name+unit+values | 1537 | 0 | [0.81, 0.94, 1.04, 1.12, 1.21, 1.31, 1.45, 1.64, 2] |  | Fasting plasma |  |
| 13099 | fp-fosfaatti,epäorgaaninen |  | 0% | name | 7 | 100 |  |  | Fasting plasma |  |
| 13100 | fp-parathormoni(intakti) | ng/l | 100% | name+unit+values | 167 | 0 | [34.58, 43.28, 53.6, 64.34, 75.77, 88.59, 106.04, 128.88, 166.07] |  | Fasting plasma |  |
| 13101 | fp-parathormoni,intakti | ng/l | 67% | name+unit+values | 443 | 0 | [42.85, 55.73, 66.85, 78.78, 88.68, 102.07, 115.78, 136.81, 193.49] |  | Fasting plasma |  |
| 13102 | fp-parathormoni,intakti | pmol/l | 32% | name+unit+values | 213 | 0 | [5.11, 7.29, 9.06, 12.26, 16.48, 21.96, 29.55, 41.46, 57.9] |  | Fasting plasma |  |
| 13103 | fp-parathormoni,intakti |  | 1% | name | 5 | 60 |  |  | Fasting plasma |  |
| 13104 | fp-reniini,konsentraatio | mu/l | 97% | name+unit+values | 275 | 0 | [1.9, 3.7, 5.72, 9.15, 13.8, 21.38, 36.23, 69.29, 149] |  | Fasting plasma |  |
| 13105 | fp-reniini,konsentraatio |  | 3% | name | 9 | 100 |  |  | Fasting plasma |  |
| 13106 | fras,oksidatiivinenstressi |  | 100% | name | 508 | 100 |  |  |  |  |
| 13107 | fs-alkalinenfosfataasi | u/l | 100% | name+unit | 114 | 0 |  |  | Fasting serum |  |
| 13108 | fs-angiotensiini-1-konvertaasi | u/l | 91% | name+unit+values | 168 | 0 | [21.95, 28.78, 36.13, 43.17, 50.38, 57.02, 63.03, 69.31, 88.3] |  | Fasting serum |  |
| 13109 | fs-angiotensiini-1-konvertaasi |  | 9% | name | 17 | 100 |  |  | Fasting serum |  |
| 13110 | fs-monikanava4-7tthperuspaketti |  | 100% | name | 125 | 100 |  |  | Fasting serum |  |
| 13111 | fs-työterveyshuollonperuspaketti |  | 100% | name | 141 | 100 |  |  | Fasting serum |  |
| 13112 | ilmajohtotarv.luujohto |  | 100% | name | 785 | 100 |  |  |  |  |
| 13113 | korona-rs-influenssa,pcrpikatesti |  | 100% | name | 6428 | 100 |  |  |  |  |
| 13114 | kreatiinikinaasi | u/l | 100% | name+unit+values | 821 | 0 | [51.45, 67.28, 78.98, 91.33, 108.19, 125.74, 161.13, 224.43, 350.78] |  |  |  |
| 13115 | l-basofiilit,automaatio | % | 100% | name+unit+values | 10670 | 0 | [0, 0, 0.5, 1, 1, 1, 1, 1, 1] |  | Leukocyte |  |
| 13116 | l-eosinofiilit,automaatio | % | 100% | name+unit+values | 10670 | 0 | [0.35, 1, 1.93, 2, 2.74, 3, 3.97, 4.81, 6.33] |  | Leukocyte |  |
| 13117 | l-lymfosyytit,automaatio | % | 100% | name+unit+values | 19279 | 0 | [15.56, 20.42, 24.04, 26.95, 29.66, 32.37, 35.21, 38.75, 43.79] |  | Leukocyte |  |
| 13118 | l-lymfosyytit,automaatio |  | 0% | name | 23 | 100 |  |  | Leukocyte |  |
| 13119 | l-monosyytit,automaatio | % | 100% | name+unit+values | 19276 | 0 | [5.94, 6.98, 7.19, 8, 8.78, 9.04, 10, 11, 12.64] |  | Leukocyte |  |
| 13120 | l-monosyytit,automaatio |  | 0% | name | 23 | 100 |  |  | Leukocyte |  |
| 13121 | l-neutrofiilit,automaatio | % | 100% | name+unit+values | 19277 | 0 | [41.43, 47.16, 50.99, 54.23, 57.08, 59.98, 63.15, 67.08, 72.76] |  | Leukocyte |  |
| 13122 | l-neutrofiilit,automaatio |  | 0% | name | 23 | 100 |  |  | Leukocyte |  |
| 13123 | laktaattidehydrogenaasi | u/l | 100% | name+unit+values | 112 | 0 | [166.9, 176.25, 189.57, 200, 217.89, 228.73, 246.21, 285.8, 336.3] |  |  |  |
| 13124 | p-aktuaalinenbikarbonaatti | mmol/l | 100% | name+unit+values | 1258 | 0 | [20.16, 23.03, 24.56, 25.84, 26.91, 27.87, 28.97, 30.03, 32.38] |  | Plasma |  |
| 13125 | p-alkaalinenfosfataasi | u/l | 97% | name+unit+values | 218 | 0 | [54.87, 64.51, 69.29, 74.44, 80.78, 89.02, 97.67, 107.93, 128.13] |  | Plasma |  |
| 13126 | p-alkaalinenfosfataasi |  | 3% | name | 6 | 16.67 |  |  | Plasma |  |
| 13127 | p-alkalinenfosfataasi | u/l | 100% | name+unit+values | 26335 | 0 | [51.5, 59.65, 66.46, 73.03, 79.94, 87.78, 97.91, 113.11, 149.16] |  | Plasma |  |
| 13128 | p-alkalinenfosfataasi |  | 0% | name | 74 | 91.89 |  |  | Plasma |  |
| 13129 | p-bilirubiinikonjugaatit | umol/l | 92% | name+unit+values | 1839 | 0 | [2.92, 3, 3.32, 4, 4.89, 5.93, 7.57, 10.11, 21.15] |  | Plasma |  |
| 13130 | p-bilirubiinikonjugaatit |  | 8% | name | 168 | 100 |  |  | Plasma |  |
| 13131 | p-fosfaatti,epäorgaaninen | mmol/l | 100% | name+unit+values | 436 | 0 | [0.89, 0.99, 1.06, 1.13, 1.2, 1.27, 1.36, 1.47, 1.66] |  | Plasma |  |
| 13132 | p-kreatiinikinaasi | u/l | 99% | name+unit+values | 2765 | 0 | [43.61, 57.48, 70.52, 85.33, 100.93, 124.44, 165.61, 239.04, 491.32] |  | Plasma |  |
| 13133 | p-kreatiinikinaasi |  | 1% | name | 21 | 95.24 |  |  | Plasma |  |
| 13134 | p-laktaattidehydrogenaasi | u/l | 99% | name+unit+values | 3272 | 0 | [163.71, 178.57, 190.98, 203.43, 216.38, 231.67, 254.03, 288.21, 372.84] |  | Plasma |  |
| 13135 | p-laktaattidehydrogenaasi |  | 1% | name | 29 | 96.55 |  |  | Plasma |  |
| 13136 | p-lupusantikoagulantti |  | 100% | name | 220 | 100 |  |  | Plasma |  |
| 13137 | p-psavapaanosuustotaalista | % | 100% | name+unit+values | 719 | 0 | [10.55, 13.9, 16.1, 18.77, 21.1, 23.88, 26.7, 30.17, 36.09] |  | Plasma |  |
| 13138 | p-urea,resirkulaatio | mmol/l | 100% | name+unit+values | 200 | 0 | [4.65, 12.03, 14.2, 15.66, 16.84, 18.43, 19.52, 21.22, 23.14] |  | Plasma |  |
| 13139 | psa-vapaa/totaali-suhde,plasmasta | % | 26% | name+unit+values | 1183 | 0 | [8.11, 11.04, 13.43, 15.83, 18.18, 20.89, 24.81, 29.88, 39.78] |  |  |  |
| 13140 | psa-vapaa/totaali-suhde,plasmasta |  | 74% | name | 3428 | 100 |  |  |  |  |
| 13141 | psavapaanjatotaalinsuhde | % | 26% | name+unit | 62 | 0 |  |  |  |  |
| 13142 | psavapaanjatotaalinsuhde |  | 74% | name | 180 | 97.78 |  |  |  |  |
| 13143 | pt-vaativainhalaatiohoito |  | 100% | name | 114 | 100 |  |  | Patient |  |
| 13144 | punasolojenkokojakauma | % | 99% | name+unit+values | 1068 | 0 | [12, 12.05, 13, 13, 13, 13, 13.97, 14, 14.47] |  |  |  |
| 13145 | punasolojenkokojakauma |  | 1% | name | 7 | 100 |  |  |  |  |
| 13146 | punasolujenerittelylaskenta | % | 9% | name+unit | 41 | 0 |  |  |  |  |
| 13147 | punasolujenerittelylaskenta |  | 91% | name+values | 433 | 6 | [12, 12, 12.18, 13, 13, 13, 13, 13.97, 14] |  |  |  |
| 13148 | punasolujenesiasteet(erytroblastit) | e9/l | 98% | name+unit+values | 1040 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |
| 13149 | punasolujenesiasteet(erytroblastit) |  | 2% | name | 24 | 100 |  |  |  |  |
| 13150 | punasolujenkokojakauma | % | 98% | name+unit+values | 155883 | 0 | [12.28, 13, 13, 13.02, 14, 14, 15, 15.9, 17] |  |  |  |
| 13151 | punasolujenkokojakauma |  | 2% | name | 2478 | 99.48 |  |  |  |  |
| 13152 | punasolujenkokojakautuma | % | 100% | name+unit+values | 683 | 0 | [13, 13, 13, 13, 13, 14, 14, 14, 14.95] |  |  |  |
| 13153 | punasolujenkoonvaihtelu | % | 100% | name+unit+values | 2031 | 0 | [12.51, 12.91, 13.17, 13.34, 13.62, 13.91, 14.31, 14.86, 15.92] |  |  |  |
| 13154 | punasolut,kokojakauma | % | 100% | name+unit+values | 121 | 0 | [13, 13, 13, 13, 14, 14, 14, 14, 15] |  |  |  |
| 13155 | s-alkalinenfosfataasi | u/l | 100% | name+unit+values | 368 | 0 | [52.79, 63.98, 76.35, 87.37, 103.68, 118.86, 131.06, 146.22, 181.47] |  | Serum |  |
| 13156 | s-alkalinenfosfataasi,isoentsyymit |  | 100% | name | 318 | 100 |  |  | Serum |  |
| 13157 | s-glykoproteiininasetylaatio | mmol/l | 100% | name+unit+values | 265 | 0 | [0.75, 0.79, 0.81, 0.83, 0.85, 0.88, 0.9, 0.94, 1] |  | Serum |  |
| 13158 | s-neuronispesifinenenolaasi | ug/l | 100% | name+unit | 105 | 0 |  |  | Serum |  |
| 13159 | s-nightingale-mittaus |  | 100% | name | 265 | 100 |  |  | Serum |  |
| 13160 | s-psavapaanjatotaalinsuhde | % | 29% | name+unit+values | 106 | 0 | [11, 13, 14.4, 16.35, 19, 21, 23.87, 27, 31.9] |  | Serum |  |
| 13161 | s-psavapaanjatotaalinsuhde |  | 71% | name | 264 | 100 |  |  | Serum |  |
| 13162 | s-tymidiinikinaasi | u/l | 100% | name+unit+values | 237 | 0 | [3.92, 4.79, 5.63, 6.48, 7.24, 8.95, 10.78, 13.93, 39.38] |  | Serum |  |
| 13163 | s-vapaanjakokonais-psa:nsuhde | % | 29% | name+unit+values | 643 | 0 | [11.89, 14.35, 17.11, 19.53, 21.76, 24, 27.79, 31.6, 36.6] |  | Serum |  |
| 13164 | s-vapaanjakokonais-psa:nsuhde |  | 71% | name | 1561 | 100 |  |  | Serum |  |
| 13165 | sars-cov-2,influenssaa,bja |  | 100% | name | 161 | 100 |  |  |  |  |
| 13166 | sars-cov-2-antigeenitesti,pikatesti |  | 100% | name | 101 | 100 |  |  |  |  |
| 13167 | tth-pakettia(ilmanpaastoa) |  | 100% | name | 1079 | 100 |  |  |  |  |
| 13168 | tth:ssavirtsanprotjagluk |  | 100% | name | 294 | 100 |  |  |  |  |
| 13169 | u-solut,peruslaskenta |  | 100% | name | 1772 | 100 |  |  | Urine |  |
| 13170 | vb-aktuaalibikarbonaatti | mmol/l | 90% | name+unit+values | 1612 | 0 | [16.94, 19.74, 21.93, 23.14, 24.18, 25.06, 26.96, 28.44, 30.92] |  | Venous blood |  |
| 13171 | vb-aktuaalibikarbonaatti |  | 10% | name+values | 185 | 17.3 | [20.1, 23.3, 24.38, 25.39, 26.05, 26.8, 27.78, 28.4, 29.7] |  | Venous blood |  |
| 13172 | vb-standardibikarbonaatti | mmol/l | 100% | name+unit+values | 13754 | 0 | [20.04, 21.93, 23.08, 23.95, 24.68, 25.36, 26.13, 27.07, 28.82] |  | Venous blood |  |
| 13173 | vb-standardibikarbonaatti |  | 0% | name | 44 | 100 |  |  | Venous blood |  |
| 13174 | virtsansolujenhl7-siirtoon | e6/l | 94% | name+unit+values | 5551 | 0 | [0.1, 0.37, 0.65, 1.07, 1.65, 2.44, 3.88, 6.78, 14.04] |  |  |  |
| 13175 | virtsansolujenhl7-siirtoon |  | 6% | name+values | 353 | 11.05 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |
| 13176 | zb-aktuaalibikarbonaatti | mmol/l | 100% | name+unit+values | 394 | 0 | [22, 23, 23.94, 24, 25, 26, 27, 27.8, 29.78] |  | Central blood |  |

