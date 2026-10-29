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
Here is group 162 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 13132 | b-eosinofiilit,b-diffiosatutkimus | e9/l | 95% | name+unit+values | 776 | 0 | [0.05, 0.09, 0.12, 0.15, 0.18, 0.21, 0.25, 0.31, 0.41] |  | Blood |  |
| 13133 | b-eosinofiilit,b-diffiosatutkimus |  | 5% | name | 38 | 100 |  |  | Blood |  |
| 13134 | b-erybla(19978b-erybla),osatutkimus | e9/l | 100% | name+unit+values | 162 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  |
| 13135 | b-hyytymistekijävgeeni,dna-tutkimus |  | 100% | name | 145 | 100 |  |  | Blood |  |
| 13136 | b-jak2-geeninmutaatio,dna-tutkimus |  | 100% | name | 141 | 100 |  |  | Blood |  |
| 13137 | b-laktaatti,päivystystutkimus | mmol/l | 100% | name+unit+values | 11297 | 0 | [0.6, 0.73, 0.85, 0.99, 1.13, 1.3, 1.56, 1.95, 2.72] |  | Blood |  |
| 13138 | b-laktaatti,päivystystutkimus |  | 0% | name | 53 | 100 |  |  | Blood |  |
| 13139 | b-laktoosi-intoleranssi,dna-tutkimus |  | 100% | name | 396 | 100 |  |  | Blood |  |
| 13140 | b-laktoosimalabsorptioonliityvägeenimuutos,dna |  | 100% | name | 146 | 100 |  |  | Blood |  |
| 13141 | b-neutrofiili,erillistutkimuksena | e9/l | 100% | name+unit+values | 26946 | 0 | [1.15, 1.77, 2.31, 2.83, 3.4, 4.06, 4.87, 6.13, 8.46] |  | Blood |  |
| 13142 | b-neutrofiili,erillistutkimuksena |  | 0% | name | 90 | 100 |  |  | Blood |  |
| 13143 | b-neutrofiilit,b-diffiosatutkimus | e9/l | 100% | name+unit+values | 813 | 0 | [1.98, 2.53, 3.01, 3.43, 3.8, 4.31, 4.86, 5.59, 6.82] |  | Blood |  |
| 13144 | b-neutrofiilit,erillistutkimuksena | e9/l | 95% | name+unit+values | 1653 | 0 | [2.1, 2.62, 3.09, 3.44, 3.76, 4.24, 4.87, 5.59, 7.23] |  | Blood |  |
| 13145 | b-neutrofiilit,erillistutkimuksena |  | 5% | name | 80 | 100 |  |  | Blood |  |
| 13146 | b-neutrofiiliterillistutkimuksena | e9/l | 100% | name+unit+values | 555 | 0 | [1.8, 2.41, 2.88, 3.29, 3.66, 4.13, 4.71, 5.54, 7.13] |  | Blood |  |
| 13147 | b-protrombiinigeeni,dna-tutkimus |  | 100% | name | 135 | 100 |  |  | Blood |  |
| 13148 | bf-bronkuseritteenirtosolututkimus |  | 100% | name | 121 | 100 |  |  | Bronchial fluid |  |
| 13149 | bronkuseritteenirtosolututkimus |  | 100% | name | 145 | 100 |  |  |  |  |
| 13150 | cyp2d6-geeninvariaatiot,dna-tutkimus |  | 100% | name | 560 | 100 |  |  |  |  |
| 13151 | dpyd-geeninvarianttientutkimusverestä |  | 100% | name | 381 | 100 |  |  |  |  |
| 13152 | e-rdw(19976e-rdw),osatutkimus | % | 100% | name+unit+values | 161 | 0 | [12, 12.3, 13, 13, 13, 13, 13, 14, 15] |  | Erythrocyte |  |
| 13153 | farmakogeneettinenpaneeli,dna-tutkimusverestä |  | 100% | name | 307 | 100 |  |  |  |  |
| 13154 | farmakogeneettinenpaneelitutkimus |  | 100% | name | 238 | 100 |  |  |  |  |
| 13155 | gynegologinenirtosolututkimus |  | 100% | name | 143 | 100 |  |  |  |  |
| 13156 | gynekologinenirtosolunäyte,hpvnho+tarvnestepapa |  | 100% | name | 156 | 100 |  |  |  |  |
| 13157 | gynekologinenirtosolututkimus |  | 100% | name | 1964 | 100 |  |  |  |  |
| 13158 | gynekologinenirtosolututkimus,seulonta |  | 100% | name | 2320 | 100 |  |  |  |  |
| 13159 | hyytymistekijävgeeni,dna-tutkimus |  | 100% | name | 105 | 100 |  |  |  |  |
| 13160 | immunohistokemiallinentutkimus |  | 100% | name | 124 | 100 |  |  |  |  |
| 13161 | k-vitamiinitk1jak2,pakettitutkimus |  | 100% | name | 211 | 100 |  |  |  |  |
| 13162 | k1-vitamiini(fyllokinoni)osatutkimus | ug/l | 95% | name+unit+values | 195 | 0 | [0.15, 0.22, 0.28, 0.36, 0.43, 0.52, 0.7, 0.9, 1.6] |  |  |  |
| 13163 | k1-vitamiini(fyllokinoni)osatutkimus |  | 5% | name | 11 | 100 |  |  |  |  |
| 13164 | k2-vitamiini,menakinoni-4(mk4)osatutkimus | ug/l | 94% | name+unit+values | 203 | 0 | [0.14, 0.16, 0.2, 0.23, 0.26, 0.3, 0.34, 0.44, 0.58] |  |  |  |
| 13165 | k2-vitamiini,menakinoni-4(mk4)osatutkimus |  | 6% | name | 14 | 100 |  |  |  |  |
| 13166 | k2-vitamiini,menakinoni-7(mk7)osatutkimus | ug/l | 85% | name+unit+values | 185 | 0 | [0.13, 0.16, 0.2, 0.24, 0.32, 0.43, 0.71, 1.38, 2.6] |  |  |  |
| 13167 | k2-vitamiini,menakinoni-7(mk7)osatutkimus |  | 15% | name | 32 | 100 |  |  |  |  |
| 13168 | laktaatti,päivystystutkimus,verestä | mmol/l | 100% | name+unit+values | 353 | 0 | [0.77, 0.9, 1.04, 1.2, 1.46, 1.74, 2.08, 2.47, 3.11] |  |  |  |
| 13169 | laktoosi-intoleranssi,dna-tutkimus |  | 100% | name | 168 | 100 |  |  |  |  |
| 13170 | laktoosi-intoleranssi,dna-tutkimus,verestä␤ |  | 100% | name | 151 | 100 |  |  |  |  |
| 13171 | lausunto,hemostaasi-jatrombosyyttitutkimukset |  | 100% | name | 337 | 100 |  |  |  |  |
| 13172 | mikrobiologianerikoistutkimuk |  | 100% | name | 105 | 100 |  |  |  |  |
| 13173 | neuvola1,äitiysneuvolatutkimukset |  | 100% | name | 337 | 100 |  |  |  |  |
| 13174 | p-ca-albk(laskennallinentutkimus) | mmol/l | 100% | name+unit+values | 161 | 0 | [2.31, 2.35, 2.39, 2.41, 2.43, 2.45, 2.47, 2.5, 2.53] |  | Plasma |  |
| 13175 | pf-laktaatti,päivystystutkimus | mmol/l | 100% | name+unit+values | 117 | 0 | [1.1, 1.2, 1.33, 1.5, 1.9, 2.39, 3.19, 4.1, 7.87] |  | Pleural fluid |  |
| 13176 | pleuranesteenirtosolututkimus |  | 100% | name | 157 | 100 |  |  |  |  |
| 13177 | pt-gynegologinenirtosolututkimus␤ |  | 100% | name | 463 | 100 |  |  | Patient |  |
| 13178 | pt-gynekologinenirtosolututkimus |  | 100% | name | 1912 | 100 |  |  | Patient |  |
| 13179 | pt-gynekologinenirtosolututkimus,seulonta |  | 100% | name | 483 | 100 |  |  | Patient |  |
| 13180 | s-borrelia,vasta-aineetiggvarmistustutkimus | au/ml | 38% | name+unit+values | 202 | 0 | [8.73, 12.59, 17.76, 25.48, 39, 57.84, 89.45, 117.05, 176.45] |  | Serum |  |
| 13181 | s-borrelia,vasta-aineetiggvarmistustutkimus |  | 62% | name | 325 | 100 |  |  | Serum |  |
| 13182 | s-borrelia,vasta-aineetigmvarmistustutkimus | au/ml | 78% | name+unit+values | 411 | 0 | [3.99, 6, 7.64, 9.37, 11.83, 15.83, 21.24, 27.61, 48.27] |  | Serum |  |
| 13183 | s-borrelia,vasta-aineetigmvarmistustutkimus |  | 22% | name | 117 | 100 |  |  | Serum |  |
| 13184 | s-hi-virus,vasta-aineet,päivystystutkimus |  | 100% | name | 151 | 100 |  |  | Serum |  |
| 13185 | s-immunofiksaatiotutkimus |  | 100% | name | 406 | 100 |  |  | Serum |  |
| 13186 | sytologinenirtosolututkimus,virtsasta |  | 100% | name | 534 | 100 |  |  |  |  |
| 13187 | ts-rintasyövänennustekijätutkimus |  | 100% | name | 164 | 100 |  |  | Tissue |  |
| 13188 | tyreotropiinirefleksointitutkimus |  | 100% | name | 1372 | 100 |  |  |  |  |
| 13189 | u-asetoniaineet(kval),osatutkimus |  | 100% | name | 151 | 100 |  |  | Urine |  |
| 13190 | u-epiteelisolut,osatutkimus | e6/l | 91% | name+unit+values | 116 | 0 | [0.19, 0.3, 0.51, 1, 1.4, 2.09, 3.19, 5.3, 10.87] |  | Urine |  |
| 13191 | u-epiteelisolut,osatutkimus |  | 9% | name | 11 | 100 |  |  | Urine |  |
| 13192 | u-laajahuume-jalääkeainetutkimus |  | 100% | name | 374 | 100 |  |  | Urine |  |
| 13193 | u-proteiini(kval),osatutkimus |  | 100% | name | 151 | 100 |  |  | Urine |  |
| 13194 | u-suhteellinentiheys,osatutkimus |  | 100% | name+values | 154 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.03] |  | Urine |  |
| 13195 | u-virtsanirtosolututkimus |  | 100% | name | 802 | 100 |  |  | Urine |  |
| 13196 | virtsanirtosolututkimus |  | 100% | name | 1078 | 100 |  |  |  |  |

