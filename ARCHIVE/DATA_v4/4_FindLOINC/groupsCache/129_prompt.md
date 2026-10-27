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
Here is group 129 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 10733 | -bakt-he |  | 100% | name | 111 | 100 |  |  |  | Antibiotic sensitivity |
| 10734 | -bakt-lm |  | 100% | name | 545 | 100 |  |  |  | Species identification |
| 10735 | -baktvi |  | 100% | name | 1515 | 100 |  | -Bakteeri, viljely |  |  |
| 10736 | -baktvr |  | 100% | name | 22025 | 100 |  | -Bakteeri, värjäys |  |  |
| 10737 | ab-laktaat | mmol/l | 94% | name+unit+values | 5666 | 0 | [0.6, 0.73, 0.87, 0.99, 1.13, 1.31, 1.55, 1.91, 2.7] |  | Arterial blood |  |
| 10738 | ab-laktaat |  | 6% | name | 385 | 100 |  |  | Arterial blood |  |
| 10739 | ab-laktaatti | mmol/l | 99% | name+unit+values | 415 | 0 | [0.6, 0.7, 0.85, 0.99, 1.14, 1.36, 1.62, 2.08, 3.17] |  | Arterial blood |  |
| 10740 | ab-laktaatti |  | 1% | name | 6 | 100 |  |  | Arterial blood |  |
| 10741 | af-baktvi |  | 100% | name | 262 | 100 |  |  | Aspiration fluid |  |
| 10742 | ap-laktaat | mmol/l | 99% | name+unit+values | 49217 | 0.02 | [0.7, 0.8, 0.9, 1.04, 1.19, 1.34, 1.58, 1.93, 2.65] |  |  |  |
| 10743 | ap-laktaat |  | 1% | name | 248 | 100 |  |  |  |  |
| 10744 | ap-laktaatti | mmol/l | 99% | name+unit+values | 3940 | 0 | [0.6, 0.7, 0.82, 0.97, 1.1, 1.28, 1.53, 1.93, 2.87] |  |  |  |
| 10745 | ap-laktaatti |  | 1% | name | 22 | 100 |  |  |  |  |
| 10746 | as-baktvr |  | 100% | name | 252 | 100 |  |  | Ascitic fluid |  |
| 10747 | b-bakt-vi |  | 100% | name | 1757 | 100 |  |  | Blood | Culture |
| 10748 | b-baktjvi |  | 100% | name | 28084 | 100 |  | B -Bakteeri, jatkoviljely | Blood |  |
| 10749 | b-baktsvi |  | 100% | name | 6514 | 100 |  |  | Blood |  |
| 10750 | b-baktvi |  | 100% | name | 506538 | 100 |  | B -Bakteeri, viljely | Blood |  |
| 10751 | b-baktvi. |  | 100% | name | 2240 | 100 |  |  | Blood |  |
| 10752 | b-baktvij |  | 100% | name | 1818 | 100 |  |  | Blood |  |
| 10753 | b-laktaat | mmol/l | 50% | name+unit+values | 337 | 0 | [0.62, 0.71, 0.82, 0.93, 1.08, 1.21, 1.46, 1.92, 2.86] | B -Laktaatti | Blood |  |
| 10754 | b-laktaat |  | 50% | name | 335 | 100 |  | B -Laktaatti | Blood |  |
| 10755 | bakteerit |  | 100% | name | 6114 | 100 |  |  |  |  |
| 10756 | baktlm |  | 100% | name | 897 | 100 |  |  |  |  |
| 10757 | baktvr |  | 100% | name | 339 | 100 |  |  |  |  |
| 10758 | bl-baktvi |  | 100% | name | 303 | 100 |  |  | Bronchoalveolar lavage |  |
| 10759 | bo-baktvi |  | 100% | name | 312 | 100 |  |  | Bone |  |
| 10760 | ca-baktvi |  | 100% | name | 1564 | 100 |  | Ca-Bakteeri, viljely suonikanyylista |  |  |
| 10761 | cb-laktaat | mmol/l | 98% | name+unit+values | 12059 | 0 | [0.9, 1.1, 1.23, 1.38, 1.53, 1.73, 1.97, 2.31, 2.95] |  | Capillary blood |  |
| 10762 | cb-laktaat |  | 2% | name | 288 | 100 |  |  | Capillary blood |  |
| 10763 | cp-laktaat | mmol/l | 96% | name+unit+values | 301 | 0 | [0.9, 1.02, 1.2, 1.3, 1.49, 1.65, 1.93, 2.29, 3.07] |  |  |  |
| 10764 | cp-laktaat |  | 4% | name | 14 | 100 |  |  |  |  |
| 10765 | d-baktvi |  | 100% | name | 120 | 100 |  |  |  |  |
| 10766 | ex-baktvi |  | 100% | name | 14096 | 100 |  | Ex-Bakteeri, viljely | Expectorate (sputum) |  |
| 10767 | ex-baktvr |  | 100% | name | 3217 | 100 |  |  | Expectorate (sputum) |  |
| 10768 | f-baktjvi |  | 100% | name | 281 | 100 |  |  | Feces |  |
| 10769 | f-baktvi1 |  | 100% | name | 32771 | 100 |  | F -Bakteeri, viljely 1 (Salmonella, Shigella, Yersinia, Campylobacter) | Feces |  |
| 10770 | f-baktvi2 |  | 100% | name | 739 | 100 |  | F -Bakteeri, viljely 2 (Clostridium difficile, Staphylococcus aureus, candida) | Feces |  |
| 10771 | f-baktvi3 |  | 100% | name | 1380 | 100 |  | F -Bakteeri, viljely 3 (viljely 1 + Bacillus cereus, Clostridium perfringens, Staphylococcus aureus) | Feces |  |
| 10772 | f-baktvip |  | 100% | name | 17284 | 100 |  |  | Feces |  |
| 10773 | f-elastaasi-1 | ug/g | 63% | name+unit+values | 80 | 0 | [36.25, 72.33, 130, 174, 239.5, 308, 367.33, 444, 542.5] |  | Feces |  |
| 10774 | f-elastaasi-1 |  | 37% | name | 47 | 100 |  |  | Feces |  |
| 10775 | f-elastaasi1 | ug/g | 72% | name+unit+values | 205 | 1.95 | [58.67, 101.72, 132.4, 171.78, 206.3, 240.97, 285.31, 336.75, 412.33] |  | Feces |  |
| 10776 | f-elastaasi1 |  | 28% | name | 79 | 100 |  |  | Feces |  |
| 10777 | fl-baktna |  | 100% | name | 154 | 100 |  |  | Vaginal discharge |  |
| 10778 | fl-baktvr |  | 100% | name | 11637 | 100 |  | Fl-Bakteeri, värjäys | Vaginal discharge |  |
| 10779 | fp-laktaat | mmol/l | 99% | name+unit+values | 301358 | 0 | [0.53, 0.7, 0.8, 0.9, 1.01, 1.19, 1.39, 1.71, 2.34] | fP-Laktaatti | Fasting plasma |  |
| 10780 | fp-laktaat |  | 1% | name | 1633 | 100 |  | fP-Laktaatti | Fasting plasma |  |
| 10781 | fp-laktaatti | mmol/l | 100% | name+unit+values | 1982 | 0 | [0.79, 0.93, 1.09, 1.21, 1.38, 1.55, 1.78, 2.09, 2.72] |  | Fasting plasma |  |
| 10782 | fp-laktaatti |  | 0% | name | 7 | 100 |  |  | Fasting plasma |  |
| 10783 | fp-parathormoni | ng/l | 87% | name+unit+values | 3057 | 0 | [39.26, 52.29, 64.09, 76.18, 92.14, 109.87, 136.61, 188.47, 312.59] |  | Fasting plasma |  |
| 10784 | fp-parathormoni | pmol/l | 12% | name+unit+values | 423 | 0 | [4.16, 5.6, 7.49, 9.39, 11.31, 14.21, 18.57, 24.25, 46.66] |  | Fasting plasma |  |
| 10785 | fp-parathormoni |  | 1% | name | 31 | 100 |  |  | Fasting plasma |  |
| 10786 | fp-rauta(osat.) | umol/l | 100% | name+unit+values | 288 | 0 | [9.46, 11.8, 13.57, 15, 16.25, 17.88, 19.32, 21.84, 25.79] |  | Fasting plasma |  |
| 10787 | li-baktvi |  | 100% | name | 7020 | 100 |  | Li-Bakteeri, viljely | Cerebrospinal fluid |  |
| 10788 | li-baktvr |  | 100% | name | 3747 | 100 |  | Li-Bakteeri, värjäys | Cerebrospinal fluid |  |
| 10789 | li-laktaat | mmol/l | 92% | name+unit+values | 4034 | 0.02 | [1.4, 1.5, 1.6, 1.7, 1.8, 1.93, 2.17, 2.53, 3.28] | Li-Laktaatti | Cerebrospinal fluid |  |
| 10790 | li-laktaat |  | 8% | name+values | 359 | 100 | [1.46, 1.56, 1.68, 1.88, 2, 2, 2, 2.23, 3] | Li-Laktaatti | Cerebrospinal fluid |  |
| 10791 | mb-laktaat | mmol/l | 94% | name+unit | 2452 | 0 |  |  |  |  |
| 10792 | mb-laktaat |  | 6% | name | 157 | 100 |  |  |  |  |
| 10793 | p-laboratorio |  | 100% | name | 221 | 100 |  |  | Plasma |  |
| 10794 | p-laktaat | mmol/l | 99% | name+unit+values | 21546 | 0 | [0.71, 0.89, 1, 1.14, 1.3, 1.49, 1.72, 2.06, 2.71] |  | Plasma |  |
| 10795 | p-laktaat |  | 1% | name | 113 | 100 |  |  | Plasma |  |
| 10796 | p-laktaatti | mmol/l | 100% | name+unit+values | 11624 | 0 | [0.7, 0.87, 1, 1.12, 1.29, 1.49, 1.72, 2.07, 2.76] |  | Plasma |  |
| 10797 | p-laktaatti |  | 0% | name | 43 | 100 |  |  | Plasma |  |
| 10798 | pd-baktvi |  | 100% | name | 917 | 100 |  | Pd-Bakteeri, viljely peritoneaalidialyysinesteestä | Peritoneal dialysis fluid |  |
| 10799 | pf-baktvr |  | 100% | name | 258 | 100 |  |  | Pleural fluid |  |
| 10800 | pf-laktaat | mmol/l | 92% | name+unit+values | 994 | 0 | [1.24, 1.54, 1.83, 2.21, 2.69, 3.33, 4.17, 5.46, 8.14] |  | Pleural fluid |  |
| 10801 | pf-laktaat |  | 8% | name | 85 | 100 |  |  | Pleural fluid |  |
| 10802 | pf-laktaatti | mmol/l | 100% | name+unit+values | 125 | 0 | [1.2, 1.49, 1.64, 2.05, 2.51, 3.11, 3.96, 5.16, 9.17] |  | Pleural fluid |  |
| 10803 | pp-baktnh |  | 100% | name | 445 | 100 |  | Pp-Bakteeri, nukleiinihappo (kvant), ientasku | Periodontal pocket |  |
| 10804 | ps-baktvi |  | 100% | name | 3894 | 100 |  | Ps-Bakteeri, viljely | Pharyngeal secretion |  |
| 10805 | pu-baktvi1 |  | 100% | name | 132179 | 100 |  | Pu-Bakteeri, viljely 1 (anaerobi + aerobiviljely, syvämärkä) | Pus |  |
| 10806 | pu-baktvi2 |  | 100% | name | 97752 | 100 |  | Pu-Bakteeri, viljely 2 (aerobiviljely, pintamärkä) | Pus |  |
| 10807 | s-laktaatti | mmol/l | 100% | name+unit+values | 262 | 0 | [1.25, 1.39, 1.5, 1.57, 1.69, 1.79, 1.9, 2.1, 2.43] |  | Serum |  |
| 10808 | sy-baktvr |  | 100% | name | 1225 | 100 |  |  | Synovial fluid |  |
| 10809 | sy-laktaat | mmol/l | 46% | name+unit+values | 247 | 0 | [2.75, 3.23, 3.84, 4.2, 4.64, 5.4, 6.36, 8.2, 11.68] | Sy-Laktaatti | Synovial fluid |  |
| 10810 | sy-laktaat |  | 54% | name | 287 | 100 |  | Sy-Laktaatti | Synovial fluid |  |
| 10811 | u-bact |  | 100% | name+values | 4570 | 100 | [0.99, 2.83, 5.12, 9.53, 18.07, 36.49, 88.52, 332.29, 2094.64] |  | Urine |  |
| 10812 | u-bakt | e6/l | 3% | name+unit+values | 12886 | 0 | [0.99, 2, 3.8, 6.5, 13.25, 30.37, 97.24, 567.39, 5475.37] |  | Urine |  |
| 10813 | u-bakt | estimate | 3% | name+unit | 14084 | 0.01 |  |  | Urine |  |
| 10814 | u-bakt | u/field | 0% | name+unit | 11 | 0 |  |  | Urine |  |
| 10815 | u-bakt |  | 93% | name+values | 377251 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  |
| 10816 | u-bakt-vi |  | 100% | name | 14923 | 100 |  |  | Urine | Culture |
| 10817 | u-bakt. | /sunf | 24% | name+unit+values | 514 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  |
| 10818 | u-bakt. | /sunfält | 2% | name+unit | 40 | 0 |  |  | Urine |  |
| 10819 | u-bakt. |  | 74% | name | 1617 | 100 |  |  | Urine |  |
| 10820 | u-baktalv |  | 100% | name | 2258 | 100 |  | U -Bakteeri, aluslasiviljely | Urine |  |
| 10821 | u-baktb |  | 100% | name+values | 210 | 100 | [1.66, 5.71, 11.75, 19.06, 29.8, 65.32, 201.28, 2182.67, 10970.57] |  | Urine |  |
| 10822 | u-baktbv | e6/l | 98% | name+unit+values | 3962 | 0 | [0.8, 1.82, 3.94, 7.14, 16.08, 44.82, 182.18, 1319.22, 13314.4] |  | Urine |  |
| 10823 | u-baktbv |  | 2% | name | 93 | 100 |  |  | Urine |  |
| 10824 | u-bakteeri |  | 100% | name | 1711 | 100 |  |  | Urine |  |
| 10825 | u-bakteerit | e6/l | 9% | name+unit+values | 1692 | 0 | [1, 3.32, 6.82, 15.06, 44.78, 157.3, 835.48, 6020.54, 24759.04] |  | Urine |  |
| 10826 | u-bakteerit |  | 91% | name | 16840 | 100 |  |  | Urine |  |
| 10827 | u-baktevi |  | 100% | name | 18799 | 100 |  | U -Bakteeri, erikoisviljely | Urine |  |
| 10828 | u-baktjvi |  | 100% | name | 390824 | 100 |  | U -Bakteeri, jatkoviljely | Urine |  |
| 10829 | u-baktjvi. |  | 100% | name | 11570 | 100 |  |  | Urine |  |
| 10830 | u-baktla |  | 100% | name | 4577 | 100 |  |  | Urine |  |
| 10831 | u-baktlm |  | 100% | name | 1437 | 100 |  |  | Urine |  |
| 10832 | u-baktnim |  | 100% | name | 111 | 100 |  |  | Urine |  |
| 10833 | u-bakts |  | 100% | name | 1045 | 100 |  |  | Urine |  |
| 10834 | u-baktseu |  | 100% | name | 39886 | 100 |  |  | Urine |  |
| 10835 | u-baktsjvi |  | 100% | name | 539 | 100 |  |  | Urine |  |
| 10836 | u-bakttun |  | 100% | name | 653 | 100 |  |  | Urine |  |
| 10837 | u-baktv |  | 100% | name | 1154 | 100 |  |  | Urine |  |
| 10838 | u-baktvi | e6 | 0% | name+unit | 45 | 0 |  | U -Bakteeri, viljely | Urine |  |
| 10839 | u-baktvi | e6/l | 0% | name+unit | 60 | 0 |  | U -Bakteeri, viljely | Urine |  |
| 10840 | u-baktvi | form | 0% | name+unit | 10 | 0 |  | U -Bakteeri, viljely | Urine |  |
| 10841 | u-baktvi |  | 100% | name | 1324678 | 100 |  | U -Bakteeri, viljely | Urine |  |
| 10842 | u-baktvi/ |  | 100% | name | 562 | 100 |  |  | Urine |  |
| 10843 | u-baktvi/oma |  | 100% | name | 629 | 100 |  |  | Urine |  |
| 10844 | u-baktvi2 |  | 100% | name | 283 | 100 |  |  | Urine |  |
| 10845 | u-baktvtk |  | 100% | name | 1637 | 100 |  |  | Urine |  |
| 10846 | u-happamuus |  | 100% | name+values | 204 | 100 | [6.5, 6.5, 7, 7, 7, 7.1, 7.5, 7.5, 8] |  | Urine |  |
| 10847 | u-sakka,bakt |  | 100% | name | 330 | 100 |  |  | Urine |  |
| 10848 | u-sakka,epit |  | 100% | name+values | 1251 | 100 | [0, 0, 0, 0, 0, 0, 0.35, 1, 2] |  | Urine |  |
| 10849 | u-sakka,eryt | u/field | 91% | name+unit+values | 1247 | 0 | [0, 0, 0, 0, 0.96, 1, 2, 3.08, 7.59] |  | Urine |  |
| 10850 | u-sakka,eryt |  | 9% | name | 121 | 100 |  |  | Urine |  |
| 10851 | u-sakka,leuk | u/field | 81% | name+unit+values | 1087 | 0 | [0, 0, 0, 0, 0, 0.95, 1.95, 4.61, 11] |  | Urine |  |
| 10852 | u-sakka,leuk |  | 19% | name | 261 | 100 |  |  | Urine |  |
| 10853 | u-sakka,lier |  | 100% | name+values | 367 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  |
| 10854 | u-sakka,makrof |  | 100% | name+values | 367 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  |
| 10855 | u-sakka,muuta |  | 100% | name+values | 456 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  |
| 10856 | u-solut,muut |  | 100% | name | 136 | 100 |  |  | Urine |  |
| 10857 | vb-laktaat | mmol/l | 96% | name+unit+values | 17603 | 0 | [0.8, 0.99, 1.11, 1.25, 1.39, 1.57, 1.79, 2.13, 2.75] |  | Venous blood |  |
| 10858 | vb-laktaat |  | 4% | name+values | 701 | 100 | [0.88, 1, 1.1, 1.24, 1.41, 1.56, 1.78, 1.95, 2.36] |  | Venous blood |  |
| 10859 | vp-laktaat | mmol/l | 98% | name+unit+values | 10894 | 0 | [0.9, 1.05, 1.2, 1.33, 1.49, 1.69, 1.92, 2.26, 2.87] |  |  |  |
| 10860 | vp-laktaat |  | 2% | name | 179 | 100 |  |  |  |  |

