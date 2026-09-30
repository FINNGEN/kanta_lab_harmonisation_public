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
Here is group 110 of the table. Write the LOINC Long Common Name for every row.

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|---|---|---|---|---|---|
| 8963 | -activi |  | 100% | name | 523 | 100 |  | -Actinomyces, viljely |  |  |
| 8964 | -amebvr |  | 100% | name | 732 | 100 |  | -Ameeba, värjäys (trofozoiitit) |  |  |
| 8965 | -caauvi |  | 100% | name | 468 | 100 |  | -Candida auris, viljely |  |  |
| 8966 | -cand-vi |  | 100% | name | 285 | 100 |  |  |  | Culture |
| 8967 | -candvi |  | 100% | name | 9492 | 100 |  | -Hiiva, viljely |  |  |
| 8968 | -em-bl |  | 100% | name | 104 | 100 |  |  |  |  |
| 8969 | -ervr |  | 100% | name | 185 | 100 |  |  |  |  |
| 8970 | -esblvi |  | 100% | name | 2644 | 100 |  | -Bakteeri, laajakirjoista beta-laktamaasia tuottava, viljely |  |  |
| 8971 | -gcvi |  | 100% | name | 2115 | 100 |  | -Neisseria gonorrhoeae, viljely |  |  |
| 8972 | -hsvpvi |  | 100% | name | 1154 | 100 |  | -Herpes simplex -virus, pikaviljely |  |  |
| 8973 | -hsvvi |  | 100% | name | 1451 | 100 |  | -Herpes simplex -virus, viljely |  |  |
| 8974 | -hygvi |  | 100% | name | 276 | 100 |  | -Hygienianäyte, viljely |  |  |
| 8975 | -ifkuvio |  | 100% | name | 330 | 100 |  |  |  |  |
| 8976 | -kat-vi |  | 100% | name | 205 | 100 |  |  |  | Culture |
| 8977 | -mdrsjvi |  | 100% | name | 152 | 100 |  | -Moniresistentit gramnegatiiviset sauvat, jatkoviljely |  |  |
| 8978 | -mdrsvi |  | 100% | name | 4893 | 100 |  | -Moniresistentit gramnegatiiviset sauvat, viljely |  |  |
| 8979 | -mrsajvi |  | 100% | name | 143 | 100 |  | -Staphylococcus aureus, metisilliiniresistentti, jatkoviljely |  |  |
| 8980 | -mrsavi |  | 100% | name | 147348 | 100 |  | -Staphylococcus aureus, metisilliiniresistenssi viljely |  |  |
| 8981 | -mrsavine |  | 100% | name | 825 | 100 |  |  |  |  |
| 8982 | -mrsavini |  | 100% | name | 835 | 100 |  |  |  |  |
| 8983 | -mrsrivi |  | 100% | name | 260 | 100 |  |  |  |  |
| 8984 | -nocavi |  | 100% | name | 2268 | 100 |  | -Nokardia, viljely |  |  |
| 8985 | -palovvi |  | 100% | name | 704 | 100 |  |  |  |  |
| 8986 | -psvs |  | 100% | name | 161 | 100 |  |  |  |  |
| 8987 | -respvt |  | 100% | name | 1271 | 100 |  |  |  |  |
| 8988 | -rsv |  | 100% | name | 220 | 100 |  |  |  |  |
| 8989 | -rsvvt |  | 100% | name | 1271 | 100 |  |  |  |  |
| 8990 | -staupvl |  | 100% | name | 146 | 100 |  |  |  |  |
| 8991 | -stauvi |  | 100% | name | 681 | 100 |  |  |  |  |
| 8992 | -strag |  | 100% | name | 276 | 100 |  | -Streptococcus, antigeeni |  |  |
| 8993 | -strjvi |  | 100% | name | 4196 | 100 |  | -Streptococcus, jatkoviljely (seulottu näyte) |  |  |
| 8994 | -strvi |  | 100% | name | 1015 | 100 |  |  |  |  |
| 8995 | -tbevi |  | 100% | name | 4326 | 100 |  | -Mycobacterium, erikoisviljely |  |  |
| 8996 | -tbpvr |  | 100% | name | 395 | 100 |  |  |  |  |
| 8997 | -tbvi |  | 100% | name | 25319 | 100 |  | -Mycobacterium tuberculosis, viljely |  |  |
| 8998 | -tbvivr |  | 100% | name | 131 | 100 |  |  |  |  |
| 8999 | -tbvr |  | 100% | name | 14513 | 100 |  | -Mycobacterium tuberculosis, värjäys |  |  |
| 9000 | -tbvrvi |  | 100% | name | 9619 | 100 |  |  |  |  |
| 9001 | -trvaag |  | 100% | name | 740 | 100 |  | -Trichomonas vaginalis, antigeeni |  |  |
| 9002 | -vi |  | 100% | name | 110 | 100 |  |  |  | Culture |
| 9003 | -virvi |  | 100% | name | 1652 | 100 |  | -Virus, viljely |  |  |
| 9004 | -vrevi |  | 100% | name | 10787 | 100 |  | -Enterokokki, vankomysiiniresistentti, viljely |  |  |
| 9005 | -väri |  | 100% | name | 1665 | 100 |  |  |  |  |
| 9006 | 1.savuk | u | 77% | name+unit+values | 83 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 10] |  |  |  |
| 9007 | 1.savuk |  | 23% | name | 25 | 100 |  |  |  |  |
| 9008 | b-tbevi |  | 100% | name | 1076 | 100 |  | B -Mycobacterium, erikoisviljely | Blood |  |
| 9009 | candvi |  | 100% | name | 508 | 100 |  |  |  |  |
| 9010 | ex-tbvi |  | 100% | name | 7823 | 100 |  | Ex-Mycobacterium tuberculosis, viljely | Expectorate (sputum) |  |
| 9011 | ex-tbvivr |  | 100% | name | 807 | 100 |  |  | Expectorate (sputum) |  |
| 9012 | ex-tbvr |  | 100% | name | 853 | 100 |  |  | Expectorate (sputum) |  |
| 9013 | ex-tbvrvi |  | 100% | name | 15922 | 100 |  |  | Expectorate (sputum) |  |
| 9014 | f-aurvi |  | 100% | name | 116 | 100 |  |  | Feces |  |
| 9015 | f-bacevi |  | 100% | name | 114 | 100 |  |  | Feces |  |
| 9016 | f-camp-vi |  | 100% | name | 167 | 100 |  |  | Feces | Culture |
| 9017 | f-campvi |  | 100% | name | 14627 | 100 |  | F -Campylobacter, viljely | Feces |  |
| 9018 | f-cereuvi |  | 100% | name | 198 | 100 |  |  | Feces |  |
| 9019 | f-clpevi |  | 100% | name | 114 | 100 |  |  | Feces |  |
| 9020 | f-salm-vi |  | 100% | name | 607 | 100 |  |  | Feces | Culture |
| 9021 | f-salmvi | form | 0% | name+unit | 18 | 0 |  | F -Salmonella, viljely | Feces |  |
| 9022 | f-salmvi |  | 100% | name | 33355 | 100 |  | F -Salmonella, viljely | Feces |  |
| 9023 | f-shigvi |  | 100% | name | 14849 | 100 |  | F -Shigella, viljely | Feces |  |
| 9024 | f-stafvi |  | 100% | name | 107 | 100 |  |  | Feces |  |
| 9025 | fl-candvi |  | 100% | name | 786 | 100 |  |  | Vaginal discharge |  |
| 9026 | hsvpvi |  | 100% | name | 246 | 100 |  |  |  |  |
| 9027 | l-sauv | % | 99% | name+unit+values | 3700 | 0 | [0, 0, 0, 0, 0.48, 1, 1.78, 2.98, 5.83] |  | Leukocyte |  |
| 9028 | l-sauv |  | 1% | name | 36 | 100 |  |  | Leukocyte |  |
| 9029 | l-sauva | % | 95% | name+unit+values | 4826 | 0 | [0, 0, 0, 0.02, 0.78, 1.03, 2.02, 3.39, 6.06] |  | Leukocyte |  |
| 9030 | l-sauva |  | 5% | name+values | 244 | 100 | [0, 0, 0, 0.06, 1, 1, 2, 2.4, 4] |  | Leukocyte |  |
| 9031 | l-sauvat | % | 93% | name+unit+values | 3136 | 0 | [0, 0, 0, 0.1, 1, 1, 1.97, 2.83, 4.14] |  | Leukocyte |  |
| 9032 | l-sauvat |  | 7% | name | 224 | 100 |  |  | Leukocyte |  |
| 9033 | mm-hygvi |  | 100% | name | 702 | 100 |  | Mm-Hygienianäyte, viljely (äidinmaito) | Maternal milk |  |
| 9034 | mrsavi |  | 100% | name | 879 | 100 |  |  |  |  |
| 9035 | ns-mrsavi |  | 100% | name | 697 | 100 |  |  | Nasal secretion |  |
| 9036 | ns-staurvi |  | 100% | name | 1639 | 100 |  |  | Nasal secretion |  |
| 9037 | ps-mrsavi |  | 100% | name | 694 | 100 |  |  | Pharyngeal secretion |  |
| 9038 | rasvat |  | 100% | name | 811 | 100 |  |  |  |  |
| 9039 | resgnsvi |  | 100% | name | 2065 | 100 |  |  |  |  |
| 9040 | rsv |  | 100% | name | 1507 | 100 |  |  |  |  |
| 9041 | sc-hygvi |  | 100% | name | 251 | 100 |  |  |  |  |
| 9042 | sk-mrsavi |  | 100% | name | 165 | 100 |  |  | Skin |  |
| 9043 | straag |  | 100% | name | 525 | 100 |  |  |  |  |
| 9044 | strvi |  | 100% | name | 175 | 100 |  |  |  |  |
| 9045 | tbvi |  | 100% | name | 1001 | 100 |  |  |  |  |
| 9046 | tbvr |  | 100% | name | 863 | 100 |  |  |  |  |
| 9047 | tbvrvi |  | 100% | name | 174 | 100 |  |  |  |  |
| 9048 | u-mrsavi |  | 100% | name | 3760 | 100 |  |  | Urine |  |
| 9049 | u-tbvi |  | 100% | name | 564 | 100 |  |  | Urine |  |
| 9050 | veri |  | 100% | name | 122 | 100 |  |  |  |  |
| 9051 | vi | form | 30% | name+unit | 101 | 0 |  |  |  |  |
| 9052 | vi |  | 70% | name | 233 | 100 |  |  |  |  |
| 9053 | vre-vi |  | 100% | name | 1349 | 100 |  |  |  | Culture |
| 9054 | vrevi |  | 100% | name | 5662 | 100 |  |  |  |  |

