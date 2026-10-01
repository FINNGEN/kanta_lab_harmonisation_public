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
Here is group 37 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 1864 | -histologinensolublokkisytologisestanäytteestä |  | 100% | name | 214 | 100 |  |  |  |  |
| 1865 | -humanpapillomavirusgenotyyppi16 |  | 100% | name | 301 | 100 |  |  |  |  |
| 1866 | -humanpapillomavirusgenotyyppi18 |  | 100% | name | 301 | 100 |  |  |  |  |
| 1867 | -humanpapillomavirusgenotyyppimuupatogeeninenhpv |  | 100% | name | 252 | 100 |  |  |  |  |
| 1868 | -lisämaksukiireellisenäpyydetyllenäytteelle |  | 100% | name | 584 | 100 |  |  |  |  |
| 1869 | -lisätutkimuspyyntöaiemmintutkitullenäytteelle |  | 100% | name | 191 | 100 |  |  |  |  |
| 1870 | -lisävastaus2laskutuskuitatullenäytteelle |  | 100% | name | 438 | 100 |  |  |  |  |
| 1871 | -lisävastauslaskutuskuitatullenäytteelle |  | 100% | name | 2865 | 100 |  |  |  |  |
| 1872 | -moniresistentitgram-negatiivisetsauvat,viljely |  | 100% | name | 122 | 100 |  |  |  |  |
| 1873 | -moniresistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 163 | 100 |  |  |  |  |
| 1874 | -resistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 314 | 100 |  |  |  |  |
| 1875 | -staphylococcusaureus,metilliiniresist.viljely |  | 100% | name | 248 | 100 |  |  |  |  |
| 1876 | -staphylococcusaureus,metisilliiniresistentti,v |  | 100% | name | 540 | 100 |  |  |  |  |
| 1877 | b-glukoosi,hoitoyksikönvieritesti,kokoveri |  | 100% | name+values | 687 | 100 | [5.67, 6.19, 6.85, 7.42, 8.13, 9, 9.86, 11.05, 13.55] |  | Blood |  |
| 1878 | b-hematologisenpotilaanperuskaryotyypinmääritys |  | 100% | name | 125 | 100 |  |  | Blood |  |
| 1879 | b-kreatiniini,hoitoyksikönvieritesti,veri |  | 100% | name+values | 167 | 100 | [57.92, 69.09, 76.79, 84.4, 95.96, 104.83, 115.95, 134.6, 169.03] |  | Blood |  |
| 1880 | bakteerit,virtsasta,partikkelinlaskijalla,osatutk. |  | 100% | name | 212 | 100 |  |  |  |  |
| 1881 | bm-pahanlaatuisenveritaudinimmunofenotyypitys |  | 100% | name | 191 | 100 |  |  | Bone marrow |  |
| 1882 | bm-pahanlaatuisenveritaudinimmunofenotyyppinenjäännöstautianalyysi |  | 100% | name | 162 | 100 |  |  | Bone marrow |  |
| 1883 | cb-hemoglobiini,vieritestihoitoyksikössä | g/l | 100% | name+unit+values | 101 | 0 | [85, 92.1, 99, 112.31, 121.33, 126.93, 131.68, 135.77, 146] |  | Capillary blood |  |
| 1884 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä | mmol/l | 100% | name+unit+values | 5203 | 0 | [5.29, 6.24, 7.08, 7.99, 9.06, 10.25, 11.87, 13.98, 17.04] |  |  |  |
| 1885 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä |  | 0% | name | 19 | 100 |  |  |  |  |
| 1886 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella | mg/l | 80% | name+unit+values | 771 | 0 | [2.64, 5.11, 9.64, 14.77, 21.85, 32.33, 47.97, 68.93, 107.02] |  |  |  |
| 1887 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella |  | 20% | name | 192 | 100 |  |  |  |  |
| 1888 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 97% | name+unit+values | 438 | 0 | [26.94, 29.96, 31.93, 33, 34, 34.57, 35, 36, 37.55] |  | Erythrocyte |  |
| 1889 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 3% | name | 15 | 100 |  |  | Erythrocyte |  |
| 1890 | emäsylimäärä,laskimoverestä,pikatesti␤ | mmol/l | 52% | name+unit+values | 373 | 0 | [0, 0.83, 1, 1.91, 2, 3, 4, 5.5, 7.33] |  |  |  |
| 1891 | emäsylimäärä,laskimoverestä,pikatesti␤ |  | 48% | name+values | 339 | 100 | [-10.27, -7.62, -6, -5, -4, -3.15, -3, -2.01, -2] |  |  |  |
| 1892 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 96% | name+unit+values | 203 | 0 | [0.2, 0.4, 0.66, 1, 1.3, 1.74, 2.5, 3.68, 8.22] |  |  |  |
| 1893 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. |  | 4% | name | 9 | 100 |  |  |  |  |
| 1894 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta | iu/ml | 9% | name+unit | 24 | 0 |  |  |  |  |
| 1895 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta |  | 91% | name | 241 | 100 |  |  |  |  |
| 1896 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 95% | name+unit+values | 202 | 0 | [3.17, 4.33, 5.71, 7.18, 9.35, 12.21, 16.76, 32.31, 99.28] |  |  |  |
| 1897 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. |  | 5% | name | 10 | 100 |  |  |  |  |
| 1898 | fp-kollageenii:nbeta-karboksiterminaalinentelopeptidi | ug/l | 100% | name+unit+values | 299 | 0 | [0.08, 0.14, 0.17, 0.21, 0.26, 0.3, 0.36, 0.45, 0.62] |  | Fasting plasma |  |
| 1899 | happamusaste,kapillaariverestä,pikatesti␤ |  | 100% | name+values | 1262 | 100 | [7.35, 7.38, 7.39, 7.4, 7.41, 7.42, 7.44, 7.45, 7.47] |  |  |  |
| 1900 | happamuusaste,laskimoverestä,pikatesti␤ |  | 100% | name+values | 712 | 100 | [7.29, 7.33, 7.36, 7.37, 7.39, 7.4, 7.41, 7.43, 7.45] |  |  |  |
| 1901 | happiosapaine,kapillaariverestä,pikatesti␤ | kpa | 100% | name+unit+values | 1260 | 0 | [5.69, 6, 6.94, 7, 7.32, 8, 8.07, 9, 10] |  |  |  |
| 1902 | happoemästasejahappi,laskimoverestä,pikatesti␤ |  | 100% | name | 643 | 100 |  |  |  |  |
| 1903 | hepatiittic-virus,nh,jatkotutkimus,plasmasta |  | 100% | name | 512 | 100 |  |  |  |  |
| 1904 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ | kpa | 100% | name+unit+values | 707 | 0 | [4.3, 4.68, 4.95, 5.18, 5.49, 5.73, 6.01, 6.38, 7.01] |  |  |  |
| 1905 | hpv-gt16aptimapanther,apututkimustulostensiirtoon |  | 100% | name | 149 | 100 |  |  |  |  |
| 1906 | hpv-gt18-45aptimapanther,apututkimustulostensiirtoon |  | 100% | name | 149 | 100 |  |  |  |  |
| 1907 | hpvaptimapanther,apututkimustulostensiirtoon |  | 100% | name | 413 | 100 |  |  |  |  |
| 1908 | humanimmunodeficiencyvirus,antigeenijavasta- |  | 100% | name | 192 | 100 |  |  |  |  |
| 1909 | humanimmunodeficiencyvirus,antigeenijavasta-aineet,yhd |  | 100% | name | 260 | 100 |  |  |  |  |
| 1910 | huume-jalääkeainetutkimus,laaja,varmistus |  | 100% | name | 448 | 100 |  |  |  |  |
| 1911 | huumeseulonta,kvalitatiivinen,virtsasta␤ |  | 100% | name | 140 | 100 |  |  |  |  |
| 1912 | kalium,hoitoyksikönvieritesti,veri | mmol/l | 36% | name+unit+values | 166 | 0 | [3.34, 3.66, 3.8, 3.9, 4.01, 4.19, 4.3, 4.4, 4.6] |  |  |  |
| 1913 | kalium,hoitoyksikönvieritesti,veri |  | 64% | name+values | 290 | 100 | [3.37, 3.6, 3.72, 3.89, 4, 4.19, 4.3, 4.49, 4.83] |  |  |  |
| 1914 | kreatiniini,hoitoyksikönvieritesti,veri | mmol/l | 100% | name+unit+values | 163 | 0 | [61.15, 69.04, 74.66, 78.71, 84.6, 94.36, 102.3, 112.64, 146.9] |  |  |  |
| 1915 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 99% | name+unit+values | 874 | 0 | [2.19, 3.1, 4.19, 5.55, 6.81, 8.5, 10.54, 13.16, 17.83] |  |  |  |
| 1916 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) |  | 1% | name | 6 | 100 |  |  |  |  |
| 1917 | laajahuumeseulonta,varmistustasoinen,virtsasta |  | 100% | name | 944 | 100 |  |  |  |  |
| 1918 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 96% | name+unit+values | 203 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.1, 0.4] |  |  |  |
| 1919 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. |  | 4% | name | 9 | 100 |  |  |  |  |
| 1920 | lisävastauslaskutuskuitatullenäytteelle |  | 100% | name | 214 | 100 |  |  |  |  |
| 1921 | luuntiheysmittaus,2kohdetta(nk6sa),lausuttuna |  | 100% | name | 145 | 100 |  |  |  |  |
| 1922 | marevan-hoidonseur.tatesti,hoitoyksikkötekeesormenpäänäyte |  | 100% | name | 168 | 100 |  |  |  |  |
| 1923 | moniresistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 206 | 100 |  |  |  |  |
| 1924 | natrium,hoitoyksikönvieritesti,veri | mmol/l | 36% | name+unit+values | 163 | 0 | [132.82, 135, 136.55, 138, 138.97, 139.52, 140, 141, 142.23] |  |  |  |
| 1925 | natrium,hoitoyksikönvieritesti,veri |  | 64% | name+values | 292 | 100 | [131.15, 133.89, 135.97, 137.34, 138.73, 139.47, 140, 141, 142] |  |  |  |
| 1926 | natriureettinenpeptidi,b-tyypinn-terminaalinenpropeptidi,plasmasta | ng/l | 100% | name+unit+values | 159 | 0 | [27.23, 51.68, 104.13, 291.48, 592.33, 1344.4, 2902.92, 5512.78, 11171.35] |  |  |  |
| 1927 | nk-solujenosuus(määritettynäcd3-/cd16+/cd56+-soluina) | % | 100% | name+unit+values | 665 | 0 | [4, 6.9, 9.82, 12.42, 14.78, 17.15, 21.39, 27.07, 37.23] |  |  |  |
| 1928 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. | mosm/kgh2o | 96% | name+unit+values | 203 | 0 | [331.07, 376.3, 432.78, 501.52, 539.44, 595.89, 633.34, 686.56, 750.67] |  |  |  |
| 1929 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. |  | 4% | name | 9 | 100 |  |  |  |  |
| 1930 | p-natriureett.peptidin-termin.propept.vieritl | ng/l | 86% | name+unit+values | 118 | 0 | [137, 226.57, 313.72, 706.7, 1152, 1687.1, 2121.1, 3414.67, 4894.4] |  | Plasma |  |
| 1931 | p-natriureett.peptidin-termin.propept.vieritl |  | 14% | name | 20 | 100 |  |  | Plasma |  |
| 1932 | p-natriureettinenpeptidi,b-tyypinn-terminaalin | ng/l | 97% | name+unit+values | 4682 | 0 | [86.78, 151.71, 238.42, 386.57, 654.19, 1074.93, 1786.88, 3080.95, 6168.61] |  | Plasma |  |
| 1933 | p-natriureettinenpeptidi,b-tyypinn-terminaalin |  | 3% | name | 149 | 100 |  |  | Plasma |  |
| 1934 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi | ng/l | 93% | name+unit+values | 1366 | 0 | [104.73, 192.2, 313.28, 532.11, 917.12, 1448.3, 2324.68, 3800.52, 7047.17] |  | Plasma |  |
| 1935 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi |  | 7% | name | 107 | 100 |  |  | Plasma |  |
| 1936 | parasiitit,ulosteesta(alkueläintenkystat,madot,madonmunat,toukat) |  | 100% | name | 120 | 100 |  |  |  |  |
| 1937 | pienikudoskoepala,enintään1-3samankokonaisuudennäytettä |  | 100% | name | 234 | 100 |  |  |  |  |
| 1938 | pika:m10inabnhp,rsvnhp,cv19nhp,yhdistelmävierit. |  | 100% | name | 267 | 100 |  |  |  |  |
| 1939 | pt-diffuusiokapasiteetti,single-breath-menetelmä,tavallinenperusmittaus |  | 100% | name | 3577 | 100 |  |  | Patient |  |
| 1940 | pt-lausuntoneurofysiologisestatutkimuksesta,hälytysindikaatiot |  | 100% | name | 113 | 100 |  |  | Patient |  |
| 1941 | pt-luuntiheysmittaus,2kohdetta,ilmanlausuntoa |  | 100% | name | 120 | 100 |  |  | Patient |  |
| 1942 | pt-sydämenkattavarakenteellinenjatoiminnallinenuä(fm1ee) |  | 100% | name | 177 | 100 |  |  | Patient |  |
| 1943 | pt-uloshengityksenhuippuvirtaus,vuorokausivaihtelunseuranta |  | 100% | name | 474 | 100 |  |  | Patient |  |
| 1944 | pt-yöpolygrafia,ambulatorinen,hyvinsuppeaunirekisteröintikotona |  | 100% | name | 542 | 100 |  |  | Patient |  |
| 1945 | pt-yöpolygrafia,ambulatorinen,jalkaliikerekisteröinnein |  | 100% | name | 102 | 100 |  |  | Patient |  |
| 1946 | pu-aerobinenjaanaerobinenbakteerityypitysjaan |  | 100% | name | 147 | 100 |  |  | Pus |  |
| 1947 | resistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 320 | 100 |  |  |  |  |
| 1948 | retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 100% | name+unit+values | 525 | 0 | [26.55, 29.82, 31.74, 32.87, 33.78, 34, 35, 35.94, 37] |  |  |  |
| 1949 | s-humanimmunodeficiencyvirus,antigeenijavast |  | 100% | name | 1221 | 100 |  |  | Serum |  |
| 1950 | sikiöperäisendna:ntutkimusäidinverinäytteestä |  | 100% | name | 104 | 100 |  |  |  |  |
| 1951 | staphylococcusaureus,metisilliiniresistenssiviljely␤ |  | 100% | name | 134 | 100 |  |  |  |  |
| 1952 | staphylococcusaureus,metisilliiniresistentti(mrsa),viljely |  | 100% | name | 627 | 100 |  |  |  |  |
| 1953 | t-auttajasolujenosuus(määritettynäcd3+cd4+soluina) | % | 100% | name+unit+values | 665 | 0 | [12.27, 17.13, 20.74, 25.08, 31.09, 37.49, 46.86, 52.29, 60.29] |  | Thrombocyte |  |
| 1954 | t-estäjäsolujenosuus(määritettynäcd3+cd8+soluina) | % | 100% | name+unit+values | 665 | 0 | [14.47, 20.34, 23.97, 27.07, 31.95, 36.95, 44.67, 52.96, 66.49] |  | Thrombocyte |  |
| 1955 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella | ng/l | 7% | name+unit | 7 | 0 |  |  |  |  |
| 1956 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella |  | 93% | name | 97 | 100 |  |  |  |  |
| 1957 | ts-histologinentutkimus,1-3kudosnäytettä |  | 100% | name | 160 | 100 |  |  | Tissue |  |
| 1958 | ts-histologinentutkimus,1-3näytettä |  | 100% | name | 945 | 100 |  |  | Tissue |  |
| 1959 | työpaikanhuumeseulontajavarmistus,4yhdistettä |  | 100% | name | 469 | 100 |  |  |  |  |
| 1960 | työpaikanhuumeseulontajavarmistus,7yhdistettä |  | 100% | name | 312 | 100 |  |  |  |  |
| 1961 | täydellinennimi:pt-näytteenotto0maksu,kierronulkopuolisetnäytteet |  | 100% | name | 1481 | 100 |  |  |  |  |
| 1962 | täydellinenverenkuva,sis.perusverenkuvanjaleukosyyttienerittelylaskennan␤ |  | 100% | name | 9742 | 100 |  |  |  |  |
| 1963 | u-amfetamiinijametamfetamiini,enantiomeerienerittely |  | 100% | name | 120 | 100 |  |  | Urine |  |
| 1964 | u-asetoniaineet,kval,vieritestihoitoyksikössä |  | 100% | name | 421 | 100 |  |  | Urine |  |
| 1965 | u-erytrosyytit,kval,vieritestihoitoyksikössä |  | 100% | name | 413 | 100 |  |  | Urine |  |
| 1966 | u-glukoosi,kvalvieritestihoitoyksikössä |  | 100% | name | 423 | 100 |  |  | Urine |  |
| 1967 | u-happamuusaste,vieritestihoitoyksikössä |  | 100% | name+values | 400 | 100 | [5.5, 5.5, 5.5, 5.9, 6, 6, 6.5, 6.95, 7] |  | Urine |  |
| 1968 | u-huume-jalääkeainetutkimus,laaja,varmistus |  | 100% | name | 175 | 100 |  |  | Urine |  |
| 1969 | u-huume-jalääkeainetutkimus,semikvantitatiivinen,virtsa␤sta |  | 100% | name | 121 | 100 |  |  | Urine |  |
| 1970 | u-huumeseulonta,laaja(kvalitatiivinenlc-tof-ms) |  | 100% | name | 144 | 100 |  |  | Urine |  |
| 1971 | u-kemiallinenseulonta,vieritestihoitoyksikössä |  | 100% | name | 104 | 100 |  |  | Urine |  |
| 1972 | u-kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 100% | name+unit+values | 398 | 0 | [2.12, 2.87, 3.64, 4.69, 6, 7.64, 9.64, 12.49, 16.58] |  | Urine |  |
| 1973 | u-laajahuume-jalääkeainetutkimus,semikvantitatiivinen |  | 100% | name | 421 | 100 |  |  | Urine |  |
| 1974 | u-leukosyytit,kval,vieritestihoitoyksikössä |  | 100% | name | 429 | 100 |  |  | Urine |  |
| 1975 | u-nitriitti,kval,vieritestihoitoyksikössä |  | 100% | name | 421 | 100 |  |  | Urine |  |
| 1976 | u-proteiini,kval,vieritestihoitoyksikössä |  | 100% | name | 425 | 100 |  |  | Urine |  |
| 1977 | vieritestilaite(epoc)verikaasuanalyysilaskimonäytteestä |  | 100% | name | 162 | 100 |  |  |  |  |
| 1978 | yersinia(lajitenterocolitica,pseudotuberculosis,pestis)nho,ulosteesta␤ |  | 100% | name | 484 | 100 |  |  |  |  |

