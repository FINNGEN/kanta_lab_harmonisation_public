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
Here is group 121 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 10066 | -ctr-d |  | 100% | name | 115 | 100 |  |  |  | DNA test |
| 10067 | -fishhyb | form | 22% | name+unit | 48 | 100 |  |  |  |  |
| 10068 | -fishhyb |  | 78% | name | 174 | 100 |  |  |  |  |
| 10069 | b-apoe-d |  | 100% | name | 146 | 100 |  | B -Apolipoproteiini E, DNA-tutkimus | Blood | DNA test |
| 10070 | b-aso2-qd |  | 100% | name | 102 | 100 |  |  | Blood |  |
| 10071 | b-atrytyd | form | 2% | name+unit | 7 | 100 |  | B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus | Blood |  |
| 10072 | b-atrytyd |  | 98% | name | 283 | 100 |  | B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus | Blood |  |
| 10073 | b-auria10 |  | 100% | name | 1807 | 100 |  |  | Blood |  |
| 10074 | b-bcr-qr | form | 9% | name+unit | 159 | 100 |  | B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Blood |  |
| 10075 | b-bcr-qr |  | 91% | name | 1562 | 100 |  | B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Blood |  |
| 10076 | b-blapcr |  | 100% | name | 138 | 100 |  |  | Blood |  |
| 10077 | b-bo3-d |  | 100% | name | 963 | 100 |  |  | Blood | DNA test |
| 10078 | b-brcay-d |  | 100% | name | 519 | 100 |  |  | Blood | DNA test |
| 10079 | b-brovcore |  | 100% | name | 356 | 100 |  |  | Blood |  |
| 10080 | b-calr-d |  | 100% | name | 421 | 100 |  |  | Blood | DNA test |
| 10081 | b-cmlpcr |  | 100% | name | 553 | 100 |  |  | Blood |  |
| 10082 | b-crco |  | 100% | name | 3627 | 100 |  |  | Blood |  |
| 10083 | b-crcoti |  | 100% | name | 1359 | 100 |  |  | Blood |  |
| 10084 | b-dm2alld | form | 11% | name+unit | 19 | 100 |  | B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus | Blood |  |
| 10085 | b-dm2alld |  | 89% | name | 149 | 100 |  | B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus | Blood |  |
| 10086 | b-dpyd-d | form | 6% | name+unit | 211 | 100 |  |  | Blood | DNA test |
| 10087 | b-dpyd-d |  | 94% | name | 3111 | 100 |  |  | Blood | DNA test |
| 10088 | b-dpydl-d |  | 100% | name | 101 | 100 |  |  | Blood | DNA test |
| 10089 | b-exkon-d |  | 100% | name | 147 | 100 |  |  | Blood | DNA test |
| 10090 | b-extri-d |  | 100% | name | 136 | 100 |  |  | Blood | DNA test |
| 10091 | b-farma-d |  | 100% | name | 594 | 100 |  |  | Blood | DNA test |
| 10092 | b-farml-d |  | 100% | name | 190 | 100 |  |  | Blood | DNA test |
| 10093 | b-fii-d | form | 2% | name+unit | 138 | 100 |  | B -Protrombiinigeeni, DNA-tutkimus | Blood | DNA test |
| 10094 | b-fii-d |  | 98% | name | 7712 | 100 |  | B -Protrombiinigeeni, DNA-tutkimus | Blood | DNA test |
| 10095 | b-finngen |  | 100% | name | 736 | 100 |  |  | Blood |  |
| 10096 | b-fishhem |  | 100% | name | 130 | 100 |  | B -Hematologinen fluoresenssi in situ hybridisaatio, veri | Blood |  |
| 10097 | b-frax-d | form | 1% | name+unit | 5 | 100 |  | B -Fragiili-X,-FMR1-geenin DNA-tutkimus | Blood | DNA test |
| 10098 | b-frax-d |  | 99% | name | 347 | 100 |  | B -Fragiili-X,-FMR1-geenin DNA-tutkimus | Blood | DNA test |
| 10099 | b-fuus-mr | form | 13% | name+unit | 26 | 100 |  |  | Blood |  |
| 10100 | b-fuus-mr |  | 87% | name | 177 | 100 |  |  | Blood |  |
| 10101 | b-fv-d | form | 2% | name+unit | 139 | 100 |  | B -Hyytymistekijä V geeni, DNA-tutkimus | Blood | DNA test |
| 10102 | b-fv-d |  | 98% | name | 8156 | 100 |  | B -Hyytymistekijä V geeni, DNA-tutkimus | Blood | DNA test |
| 10103 | b-fvfii-d | form | 6% | name+unit | 52 | 100 |  |  | Blood | DNA test |
| 10104 | b-fvfii-d |  | 94% | name | 765 | 100 |  |  | Blood | DNA test |
| 10105 | b-hfe-d |  | 100% | name | 730 | 100 |  | B -Periytyvään hemokromatoosiin liittyvien HFE-geenin valtamutaatioiden tutkimus | Blood | DNA test |
| 10106 | b-hnpcy-d |  | 100% | name | 175 | 100 |  | B -Periytyvä ei-polypoottinen paksusuolisyöpä (HNPCC), MLH1-, MSH2- tai MSH6-geenin yksittäisen mutaation DNA-tutkimus | Blood | DNA test |
| 10107 | b-jak2-d | form | 2% | name+unit | 139 | 100 |  | B -JAK2-geenin mutaatio, DNA-tutkimus | Blood | DNA test |
| 10108 | b-jak2-d |  | 98% | name | 5494 | 100 |  | B -JAK2-geenin mutaatio, DNA-tutkimus | Blood | DNA test |
| 10109 | b-kim-d |  | 100% | name | 197 | 100 |  |  | Blood | DNA test |
| 10110 | b-kim-fd |  | 100% | name | 1367 | 100 |  |  | Blood |  |
| 10111 | b-kml-qr |  | 100% | name | 1809 | 100 |  |  | Blood |  |
| 10112 | b-lakt-d | form | 0% | name+unit | 18 | 77.78 |  | B -Laktoosi-intoleranssi, DNA-tutkimus | Blood | DNA test |
| 10113 | b-lakt-d |  | 100% | name | 27791 | 100 |  | B -Laktoosi-intoleranssi, DNA-tutkimus | Blood | DNA test |
| 10114 | b-ldlre-4 | form | 28% | name+unit | 53 | 100 |  |  | Blood |  |
| 10115 | b-ldlre-4 |  | 72% | name | 135 | 100 |  |  | Blood |  |
| 10116 | b-ldlre-d |  | 100% | name | 1121 | 100 |  | B -LDL-reseptorigeenin mutaatio, DNA-tutkimus | Blood | DNA test |
| 10117 | b-ngs-d |  | 100% | name | 277 | 100 |  |  | Blood | DNA test |
| 10118 | b-nphs1-d |  | 100% | name | 272 | 100 |  | B -Kongenitaali nefroosi (CNF), kahden NPHS1-geenin valtamutaation DNA-tutkimus | Blood | DNA test |
| 10119 | b-pgx-d |  | 100% | name | 2778 | 100 |  |  | Blood | DNA test |
| 10120 | b-sekvy-d | form | 4% | name+unit | 59 | 100 |  |  | Blood | DNA test |
| 10121 | b-sekvy-d |  | 96% | name | 1268 | 100 |  |  | Blood | DNA test |
| 10122 | b-tp53-d |  | 100% | name | 211 | 100 |  |  | Blood | DNA test |
| 10123 | b-tpmt-d | form | 5% | name+unit | 30 | 100 |  |  | Blood | DNA test |
| 10124 | b-tpmt-d |  | 95% | name | 615 | 100 |  |  | Blood | DNA test |
| 10125 | b-varfa-d |  | 100% | name | 643 | 100 |  | B -Varfariinin yksilölliseen annostukseen liittyvät VKORC1- ja CYP2C9-geenivariaatiot, DNA-tutkimus verestä | Blood | DNA test |
| 10126 | b-ykrom-d | form | 5% | name+unit | 7 | 100 |  | B -Y-kromosomin poikkeavuuksia | Blood | DNA test |
| 10127 | b-ykrom-d |  | 95% | name | 142 | 100 |  | B -Y-kromosomin poikkeavuuksia | Blood | DNA test |
| 10128 | bl-bal |  | 100% | name | 919 | 100 |  | Bl-Bronkoalveolaarinen lavaationäyte sairaalakohtainen ryhmätutkimus, jonka sisältö vaihtelee | Bronchoalveolar lavage |  |
| 10129 | bl-bal-1 |  | 100% | name | 3636 | 100 |  | Bl-Bronkoalveolaarinen huuhtelunäyte, solututkimus | Bronchoalveolar lavage |  |
| 10130 | bl-balfc |  | 100% | name | 397 | 100 |  |  | Bronchoalveolar lavage |  |
| 10131 | bm-aso-qd |  | 100% | name | 224 | 100 |  |  | Bone marrow |  |
| 10132 | bm-aso2-qd | form | 1% | name+unit | 6 | 100 |  |  | Bone marrow |  |
| 10133 | bm-aso2-qd |  | 99% | name | 511 | 100 |  |  | Bone marrow |  |
| 10134 | bm-aspir |  | 100% | name | 1994 | 98.65 |  |  | Bone marrow |  |
| 10135 | bm-bcr-qr |  | 100% | name | 152 | 100 |  | Bm-BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Bone marrow |  |
| 10136 | bm-blapcr |  | 100% | name | 753 | 100 |  |  | Bone marrow |  |
| 10137 | bm-bpvalm |  | 100% | name | 145 | 100 |  |  | Bone marrow |  |
| 10138 | bm-fish | form | 5% | name+unit | 48 | 100 |  |  | Bone marrow |  |
| 10139 | bm-fish |  | 95% | name | 943 | 100 |  |  | Bone marrow |  |
| 10140 | bm-fish-mm |  | 100% | name | 127 | 100 |  |  | Bone marrow |  |
| 10141 | bm-fish2 | form | 26% | name+unit | 29 | 100 |  |  | Bone marrow |  |
| 10142 | bm-fish2 |  | 74% | name | 81 | 100 |  |  | Bone marrow |  |
| 10143 | bm-fishhem | form | 2% | name+unit | 7 | 100 |  | Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin | Bone marrow |  |
| 10144 | bm-fishhem |  | 98% | name | 414 | 100 |  | Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin | Bone marrow |  |
| 10145 | bm-fishmm | form | 16% | name+unit | 28 | 100 |  |  | Bone marrow |  |
| 10146 | bm-fishmm |  | 84% | name | 147 | 100 |  |  | Bone marrow |  |
| 10147 | bm-fishvar |  | 100% | name | 141 | 100 |  |  | Bone marrow |  |
| 10148 | bm-flt3-d | form | 6% | name+unit | 9 | 100 |  |  | Bone marrow | DNA test |
| 10149 | bm-flt3-d |  | 94% | name | 138 | 100 |  |  | Bone marrow | DNA test |
| 10150 | bm-fuus-mr | form | 5% | name+unit | 14 | 100 |  |  | Bone marrow |  |
| 10151 | bm-fuus-mr |  | 95% | name | 268 | 100 |  |  | Bone marrow |  |
| 10152 | bm-fuus-qr | form | 21% | name+unit | 21 | 100 |  |  | Bone marrow |  |
| 10153 | bm-fuus-qr |  | 79% | name | 81 | 100 |  |  | Bone marrow |  |
| 10154 | bm-mgg |  | 100% | name | 314 | 100 |  |  | Bone marrow |  |
| 10155 | bm-mggfe | form | 5% | name+unit | 660 | 100 |  | Bm-Luuydintutkimus, MGG- ja rautavärjäys | Bone marrow |  |
| 10156 | bm-mggfe |  | 95% | name | 11527 | 100 |  | Bm-Luuydintutkimus, MGG- ja rautavärjäys | Bone marrow |  |
| 10157 | bm-mm-ift |  | 100% | name | 651 | 100 |  |  | Bone marrow |  |
| 10158 | bm-mmpcr |  | 100% | name | 128 | 100 |  |  | Bone marrow |  |
| 10159 | bm-morflkl |  | 100% | name | 278 | 100 |  |  | Bone marrow |  |
| 10160 | bm-mrd-all |  | 100% | name | 416 | 100 |  |  | Bone marrow |  |
| 10161 | bm-mrd-vs |  | 100% | name | 666 | 100 |  |  | Bone marrow |  |
| 10162 | bm-mrdmut |  | 100% | name | 198 | 100 |  |  | Bone marrow |  |
| 10163 | bm-npm1-qd | form | 11% | name+unit | 23 | 100 |  |  | Bone marrow |  |
| 10164 | bm-npm1-qd |  | 89% | name | 182 | 100 |  |  | Bone marrow |  |

