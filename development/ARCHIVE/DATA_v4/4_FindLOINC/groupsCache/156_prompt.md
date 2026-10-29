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
Here is group 156 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 12722 | -dialyysinjälkeen,p-urea | mmol/l | 100% | name+unit+values | 180 | 0 | [3, 3.68, 4.18, 4.49, 4.93, 5.5, 6.21, 6.87, 8.12] |  |  |  |
| 12723 | -ennendialyysiä,p-urea | mmol/l | 100% | name+unit+values | 210 | 0 | [12.2, 14.25, 15.96, 17.24, 18.13, 19.3, 20.55, 22.38, 25.16] |  |  |  |
| 12724 | alfa-1-fetoproteiini,seerumista | u/ml | 74% | name+unit | 105 | 0 |  |  |  |  |
| 12725 | alfa-1-fetoproteiini,seerumista |  | 26% | name | 37 | 100 |  |  |  |  |
| 12726 | dialyysiaedeltäväp-urea | mmol/l | 97% | name+unit | 745 | 0 |  |  |  |  |
| 12727 | dialyysiaedeltäväp-urea |  | 3% | name | 22 | 100 |  |  |  |  |
| 12728 | dialyysinjälkeinenp-urea | mmol/l | 95% | name+unit | 708 | 0 |  |  |  |  |
| 12729 | dialyysinjälkeinenp-urea |  | 5% | name | 38 | 100 |  |  |  |  |
| 12730 | dialyysinriittävyydensuhdeluku␤ |  | 100% | name | 117 | 100 |  |  |  |  |
| 12731 | ex-sieni,viljely,yskös |  | 100% | name | 387 | 100 |  |  | Expectorate (sputum) |  |
| 12732 | gamma-fraktio,seerumista␤ | g/l | 100% | name+unit+values | 715 | 0 | [3.62, 4.97, 6.21, 7.31, 8.18, 9.2, 10.45, 13.45, 22.31] |  |  |  |
| 12733 | hiiva,viljely,limakalvo␤ |  | 100% | name | 132 | 100 |  |  |  |  |
| 12734 | immunofiksaatio,seerumista |  | 100% | name | 144 | 100 |  |  |  |  |
| 12735 | klotsapiini,seerumi | nmol/l | 96% | name+unit+values | 1152 | 0 | [634.32, 1045.65, 1268.58, 1440.03, 1585.57, 1750.83, 1951.06, 2171.02, 2657.43] |  |  |  |
| 12736 | klotsapiini,seerumi |  | 4% | name | 54 | 100 |  |  |  |  |
| 12737 | klotsapiini,seerumista␤ |  | 100% | name | 365 | 100 |  |  |  |  |
| 12738 | kreatiinikinaasi,mb-alayksikkö | ug/l | 100% | name+unit+values | 382 | 0 | [1.39, 1.78, 2.02, 2.34, 2.67, 2.98, 3.56, 4.2, 6.94] |  |  |  |
| 12739 | kreatiniini(4600p-krea) | umol/l | 100% | name+unit+values | 2046 | 0 | [58.69, 64.03, 68.26, 71.62, 75.78, 79.76, 84.39, 89.68, 98.13] |  |  |  |
| 12740 | kreatiniini(krea) | umol/l | 95% | name+unit+values | 1301 | 0 | [59.48, 64.22, 68.11, 71.83, 75.82, 80.59, 84.79, 89.73, 96.23] |  |  |  |
| 12741 | kreatiniini(krea) |  | 5% | name | 72 | 100 |  |  |  |  |
| 12742 | kreatiniini(p-krea) | umol/l | 99% | name+unit+values | 1817 | 0 | [59.11, 64.24, 67.62, 71.97, 76.07, 80.59, 85.51, 90.87, 98.23] |  |  |  |
| 12743 | kreatiniini(p-krea) |  | 1% | name | 16 | 100 |  |  |  |  |
| 12744 | kreatiniini(u-maniposat.) | mmol/l | 97% | name+unit+values | 394 | 0 | [1.61, 2.67, 3.95, 5.52, 7.57, 9.7, 11.69, 14.28, 17.19] |  |  |  |
| 12745 | kreatiniini(u-maniposat.) |  | 3% | name | 13 | 100 |  |  |  |  |
| 12746 | kreatiniini,pika | umol/l | 100% | name+unit+values | 119 | 0 | [30.6, 43.6, 49.8, 57.13, 63.6, 68.54, 76.97, 87.02, 109.95] |  |  |  |
| 12747 | kreatiniini,pikatesti | umol/l | 100% | name+unit+values | 649 | 0 | [60.09, 66.57, 72.93, 78.8, 85, 91.65, 100.3, 111.92, 128.95] |  |  |  |
| 12748 | kreatiniini,plasma |  | 100% | name | 366 | 100 |  |  |  |  |
| 12749 | kreatiniini,plasmasta | ml/min/173m2 | 41% | name+unit+values | 84 | 0 | [72, 79, 87.13, 91, 93.5, 99.7, 102.9, 108.05, 114] |  |  |  |
| 12750 | kreatiniini,plasmasta | umol/l | 49% | name+unit+values | 101 | 0 | [54, 59, 63.15, 67.2, 69.93, 75.22, 80.8, 90.95, 204] |  |  |  |
| 12751 | kreatiniini,plasmasta |  | 10% | name | 20 | 100 |  |  |  |  |
| 12752 | m-komponentti-1,seerumista | g/l | 100% | name+unit+values | 666 | 0 | [0, 0, 0, 0, 0, 1.62, 4.88, 8.98, 19.92] |  | Muscle |  |
| 12753 | mm-hygienianäyte,viljely(äidinmaito) |  | 100% | name | 161 | 100 |  |  | Maternal milk |  |
| 12754 | p-kreatiinikinaasi,mb-alayksikkö,massa | ug/l | 84% | name+unit+values | 92 | 0 | [1, 2, 2, 3, 4, 5, 6.7, 10, 19] |  | Plasma |  |
| 12755 | p-kreatiinikinaasi,mb-alayksikkö,massa |  | 16% | name | 17 | 100 |  |  | Plasma |  |
| 12756 | p-kreatiniinitykslab | umol/l | 100% | name+unit+values | 933 | 0 | [55.37, 59.87, 63.05, 65.9, 68.57, 71.68, 75.55, 79.76, 85.87] |  | Plasma |  |
| 12757 | p-kreatiniinitykslab(osat.) | umol/l | 100% | name+unit+values | 111 | 0 | [54.4, 59.3, 62.6, 65.76, 68.67, 70.63, 74.07, 79.3, 82.97] |  | Plasma |  |
| 12758 | p-kreatiniinitykslab(sis.gfreepi) | umol/l | 100% | name+unit+values | 476 | 0 | [56.56, 60.35, 62.96, 66.42, 69.21, 72.17, 75.17, 79.22, 85.93] |  | Plasma |  |
| 12759 | p-reumafaktori,määritys | iu/ml | 33% | name+unit+values | 608 | 0 | [7.09, 10.95, 12, 12.13, 13, 14, 15.89, 21.26, 46.72] |  | Plasma |  |
| 12760 | p-reumafaktori,määritys |  | 67% | name | 1217 | 100 |  |  | Plasma |  |
| 12761 | p-reumafaktori,plasmasta | iu/ml | 37% | name+unit+values | 149 | 0 | [5, 5, 6, 7, 8.31, 9.43, 11.6, 20.13, 53.77] |  | Plasma |  |
| 12762 | p-reumafaktori,plasmasta |  | 63% | name | 253 | 100 |  |  | Plasma |  |
| 12763 | p-trijodityroniini,vapaa | pmol/l | 100% | name+unit+values | 637 | 0 | [3.6, 3.91, 4.18, 4.36, 4.56, 4.7, 4.89, 5.19, 5.6] |  | Plasma |  |
| 12764 | p-trijodityroniini,vapaa,plasmasta | pmol/l | 100% | name+unit+values | 505 | 0 | [3.85, 4.19, 4.43, 4.63, 4.84, 5.05, 5.3, 5.56, 6.37] |  | Plasma |  |
| 12765 | p-tyroksiini,vapaa | pmol/l | 100% | name+unit+values | 27699 | 0.01 | [12.79, 13.84, 14.5, 15.08, 15.94, 16.5, 17.23, 18.21, 19.81] |  | Plasma |  |
| 12766 | p-tyroksiini,vapaa |  | 0% | name | 45 | 100 |  |  | Plasma |  |
| 12767 | p-tyroksiini,vapaa(ko) | pmol/l | 100% | name+unit+values | 214 | 0 | [13, 13, 14, 14.25, 15, 15.69, 16, 17, 18.16] |  | Plasma |  |
| 12768 | p-tyroksiini,vapaa(pi) | pmol/l | 100% | name+unit+values | 114 | 0 | [8.88, 9.2, 9.77, 10.13, 10.63, 11.11, 11.49, 12.12, 13.33] |  | Plasma |  |
| 12769 | p-urea,10mindialyysinjälkeen | mmol/l | 100% | name+unit | 136 | 0 |  |  | Plasma |  |
| 12770 | p-urea,ennendialyysiä | mmol/l | 100% | name+unit | 139 | 0 |  |  | Plasma |  |
| 12771 | prealbumiini,plasma | g/l | 100% | name+unit+values | 103 | 0 | [0.08, 0.1, 0.13, 0.16, 0.19, 0.21, 0.23, 0.24, 0.27] |  |  |  |
| 12772 | prealbumiini,seerumista␤ | g/l | 100% | name+unit+values | 147 | 0 | [0.1, 0.13, 0.16, 0.17, 0.19, 0.21, 0.23, 0.25, 0.29] |  |  |  |
| 12773 | proteiini,fraktiot,seerumi |  | 100% | name | 262 | 100 |  |  |  |  |
| 12774 | proteiini,fraktiot,seerumista |  | 100% | name | 151 | 100 |  |  |  |  |
| 12775 | proteiini,fraktiot,seerumista␤ |  | 100% | name | 716 | 100 |  |  |  |  |
| 12776 | proteiini,ty,seerumista | g/l | 100% | name+unit+values | 663 | 0 | [56.91, 60.48, 62.84, 64.87, 66.98, 68.69, 70.61, 72.85, 80.94] |  |  |  |
| 12777 | reumafaktori,määritys,seerumista | kiu/l | 53% | name+unit+values | 99 | 0 | [4, 5, 5, 6, 7, 8.42, 10.72, 18.75, 43] |  |  |  |
| 12778 | reumafaktori,määritys,seerumista |  | 47% | name | 89 | 100 |  |  |  |  |
| 12779 | reumafaktori,plasmasta | iu/ml | 13% | name+unit | 26 | 0 |  |  |  |  |
| 12780 | reumafaktori,plasmasta |  | 87% | name | 171 | 100 |  |  |  |  |
| 12781 | s-proteiini,fraktiot,seerumi |  | 100% | name | 243 | 100 |  |  | Serum |  |
| 12782 | s-reumafaktori,määritys | iu/ml | 7% | name+unit | 32 | 0 |  |  | Serum |  |
| 12783 | s-reumafaktori,määritys | kiu/l | 38% | name+unit+values | 173 | 0 | [4, 5, 5, 6, 6.34, 7.1, 8.76, 12.32, 25.08] |  | Serum |  |
| 12784 | s-reumafaktori,määritys |  | 55% | name | 253 | 100 |  |  | Serum |  |
| 12785 | s-testo,vap,laskmassasp | pmol/l | 100% | name+unit+values | 192 | 0 | [10.85, 19, 49.35, 138.06, 177.45, 207.93, 238.8, 263.47, 335.81] |  | Serum |  |
| 12786 | s-testosteroni,herkkä | nmol/l | 100% | name+unit+values | 123 | 0 | [0.5, 0.6, 0.74, 0.87, 1, 1.12, 1.3, 1.61, 10.16] |  | Serum |  |
| 12787 | s-testosteroni,seerumista | nmol/l | 79% | name+unit+values | 395 | 0 | [2.6, 5.96, 8.17, 9.83, 11.94, 13.99, 16.59, 19.77, 24.44] |  | Serum |  |
| 12788 | s-testosteroni,seerumista |  | 21% | name | 102 | 100 |  |  | Serum |  |
| 12789 | s-testosteroni,vapaa,laskettu | pmol/l | 97% | name+unit+values | 3226 | 0 | [128.94, 163.03, 185.24, 206.94, 226.3, 246.5, 270.86, 300.89, 362.97] |  | Serum |  |
| 12790 | s-testosteroni,vapaa,laskettu |  | 3% | name | 109 | 100 |  |  | Serum |  |
| 12791 | s-testosteronivapaalaskettu | pmol/l | 100% | name+unit+values | 102 | 0 | [45, 133.8, 156.3, 186.43, 208.5, 230.49, 255, 283.9, 340] |  | Serum |  |
| 12792 | s-testosterooni,vapaa,lask. | pmol/l | 100% | name+unit+values | 112 | 0 | [131, 157.45, 176.5, 192.03, 211.37, 227.05, 249.87, 280.3, 365.2] |  | Serum |  |
| 12793 | s-testostervapaalaske | pmol/l | 100% | name+unit+values | 122 | 0 | [121.65, 153.9, 181.28, 195.2, 232.67, 260.6, 296.27, 367.7, 460.95] |  | Serum |  |
| 12794 | s-tyroksiini,vapaa | pmol/l | 99% | name+unit+values | 655 | 0 | [11.99, 12.87, 13.47, 14.03, 14.59, 15.27, 15.86, 16.79, 18.23] |  | Serum |  |
| 12795 | s-tyroksiini,vapaa |  | 1% | name | 9 | 100 |  |  | Serum |  |
| 12796 | sieni,viljely(syvänäyte) |  | 100% | name | 123 | 100 |  |  |  |  |
| 12797 | sieni,viljelyjanatiivi |  | 100% | name | 169 | 100 |  |  |  |  |
| 12798 | sk-sieni,viljely(pintanäyte) |  | 100% | name | 333 | 100 |  |  | Skin |  |
| 12799 | sk-sieni,viljely(pintasieni) |  | 100% | name | 106 | 100 |  |  | Skin |  |
| 12800 | testosteroni,vapaalask | pmol/l | 99% | name+unit+values | 913 | 0 | [119.73, 156.24, 180.26, 202.32, 224.76, 247.29, 273.77, 325.72, 420.18] |  |  |  |
| 12801 | testosteroni,vapaalask |  | 1% | name | 11 | 100 |  |  |  |  |
| 12802 | testosteroni,vapaalaskettu | pmol/l | 84% | name+unit+values | 549 | 0 | [113.52, 156.92, 183.94, 206.6, 232.26, 261.25, 292.92, 350.15, 450.68] |  |  |  |
| 12803 | testosteroni,vapaalaskettu |  | 16% | name | 103 | 100 |  |  |  |  |
| 12804 | trijodityroniini,vapaa | pmol/l | 88% | name+unit+values | 275 | 0 | [3.41, 3.83, 4.1, 4.29, 4.49, 4.7, 4.98, 5.34, 5.71] |  |  |  |
| 12805 | trijodityroniini,vapaa |  | 12% | name | 38 | 100 |  |  |  |  |
| 12806 | trijodityroniini,vapaa(t3v) | pmol/l | 98% | name+unit+values | 459 | 0 | [3.8, 4.03, 4.24, 4.4, 4.6, 4.79, 5, 5.33, 5.86] |  |  |  |
| 12807 | trijodityroniini,vapaa(t3v) |  | 2% | name | 7 | 100 |  |  |  |  |
| 12808 | tyreoglobuliini,seerumista | ug/l | 46% | name+unit | 65 | 0 |  |  |  |  |
| 12809 | tyreoglobuliini,seerumista |  | 54% | name | 75 | 100 |  |  |  |  |
| 12810 | tyreotropiiniseerumista | mu/l | 100% | name+unit+values | 146 | 0 | [0.58, 0.92, 1.29, 1.57, 2.06, 2.32, 2.77, 3.3, 4.39] |  |  |  |
| 12811 | tyroksiini,vapaa | pmol/l | 56% | name+unit+values | 808 | 0 | [12.62, 13.73, 14.33, 15, 15.68, 16.27, 17.12, 17.96, 19.14] |  |  |  |
| 12812 | tyroksiini,vapaa |  | 44% | name | 628 | 100 |  |  |  |  |
| 12813 | tyroksiini,vapaa(t4v) | pmol/l | 94% | name+unit+values | 782 | 0 | [12.85, 13.56, 14.3, 14.95, 15.6, 16.21, 16.98, 18.07, 19.69] |  |  |  |
| 12814 | tyroksiini,vapaa(t4v) |  | 6% | name | 49 | 100 |  |  |  |  |
| 12815 | tyroksiini,vapaa,plasmasta | pmol/l | 100% | name+unit+values | 153 | 0 | [12.28, 13.47, 13.92, 14.37, 15.17, 15.67, 16.39, 17.5, 18.88] |  |  |  |
| 12816 | tyroksiini,vapaaseerumista | pmol/l | 100% | name+unit+values | 102 | 0 | [12.7, 14.2, 14.98, 15.63, 16.27, 16.79, 17.48, 18.4, 20.2] |  |  |  |
| 12817 | u-kreatiniinimmol/l(u-albkre) | mmol/l | 99% | name+unit+values | 1616 | 0 | [3.09, 4.12, 5.01, 5.82, 6.75, 7.8, 9.11, 10.7, 13.33] |  | Urine |  |
| 12818 | u-kreatiniinimmol/l(u-albkre) |  | 1% | name | 18 | 100 |  |  | Urine |  |
| 12819 | urea,dialyysinjälkee | mmol/l | 100% | name+unit | 133 | 0 |  |  |  |  |
| 12820 | urea,dialyysinjälkeen,plasmasta␤ | mmol/l | 100% | name+unit | 128 | 0 |  |  |  |  |
| 12821 | urea,ennendialyysia,plasmasta␤ | mmol/l | 100% | name+unit | 162 | 0 |  |  |  |  |
| 12822 | urea,ennendialyysiä | mmol/l | 100% | name+unit | 141 | 0 |  |  |  |  |

