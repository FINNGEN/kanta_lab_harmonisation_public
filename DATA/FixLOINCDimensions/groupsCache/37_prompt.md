[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

**Those guesses exist only to fetch the candidate list. They have already done their job, and they carry no authority over your decision.** The earlier pass was told to write a name whenever the code gave it anything at all to work with, because a near-miss still retrieves the right neighbourhood of concepts while silence retrieves nothing. So a guess may be a careful reading or a shot in the dark, and nothing marks which. Use it as a pointer to where in the vocabulary to look, never as an answer to confirm. **Decide from the row's own `TEST_NAME`, `LongName`, `UNIT` and `deciles`.** When the row's evidence and the guess disagree, the row wins.

Your task: for each row, decide **which real OMOP concept the code actually maps to**, choosing from a list of genuine LOINC concepts retrieved for this group, and return that concept's `omop_concept_id`.

You are the step that turns a plausible-sounding name into a real, usable identifier. Nothing downstream can tell a confidently wrong concept id from a correct one, so an id you are not willing to defend is worse than no id at all.

# The Finnish laboratory coding system

Each national lab test has a 4-digit running number code and a short mnemonic abbreviation of at most 10 characters, built as:

    <system prefix> - <test abbreviation> [<suffix>]

- The **system prefix** is a 1-2 letter code for the specimen the sample came from, mostly from English words: `S` = serum, `P` = plasma, `B` = blood, `U` = urine, `Li` = cerebrospinal fluid, `F` = feces, `Ts` = tissue, `Pt` = patient (a whole-patient investigation), `fS`/`fP`/`fB` = fasting serum/plasma/blood, `dU` = 24-hour urine, `E` = erythrocyte, `L` = leukocyte.
- The **test abbreviation** is a mnemonic of the test's long Finnish name, occasionally an established international one (`CRP`, `TSH`).
- The optional **suffix** qualifies the result type or method: `-O` (qualitative/semi-quantitative), `-Ab` (antibodies), `-Ag` (antigen), `-Vi` (culture), `-Nh` (nucleic acid), `-Ion` (ionized), `-V` (free/unconjugated).

Finnish compounds run together: "transferriininrautakyllästeisyys" = transferrin iron saturation.

# What you are given

**The candidate table** — real OMOP LOINC concepts, found by running every guessed name in this group through a semantic search over the LOINC vocabulary and pooling the results. The candidates are pooled and deduplicated **across the whole group**, so a concept retrieved by one row's guess is offered to every row: sibling codes in a group are near-identical strings, and the right concept for one row is often the one another row's guess found. Columns:

- `omop_concept_id` — the id to return. Copy it digit for digit.
- `omop_concept_name` — the concept's real LOINC Long Common Name, as OMOP spells it today.
- `score` — how semantically close this concept was to the closest guess in the group, 0 to 1. **A high score only means the guess and the concept read alike.** The guess itself may have been wrong, so a 0.95 candidate for a misread code is a confident route to the wrong concept. Treat `score` as "the search found this", never as "this is correct".
- `top2000` — the concept's rank in the **LOINC Top 2000+ Lab Observations (SI edition)**: the ~2000 codes Regenstrief publishes as the recommended mapping targets, covering ~99.8% of the test volume of three large laboratory organisations. The SI edition is the relevant one here, since Finland reports in molar/SI units. Empty means the concept is not on the list.

**The rows table** — one row per local lab test/unit combination:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty, and may be wrong.
- `unit_share` — what percentage of this `TEST_NAME`'s records carry this row's `UNIT`.
- `n` — number of records.
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess, which is what the search was run on. A search query, not a hypothesis you owe any deference to: it was written under instructions to guess rather than stay silent, so its confidence is not calibrated and a fluent name may rest on very little. When it is a panel name, the earlier pass judged the code to order a bundle rather than report one result — check that against the code yourself.

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
| `name` | neither | **You cannot fix the quantity.** Do not guess one and do not copy a sibling. Choose a concept only when the name alone settles it — a panel, which carries no property at all, or an analyte that has exactly one LOINC form. Otherwise **leave `omop_concept_id` empty**. An honest gap is worth more than a concept resting on nothing. |

**Some units are ratios, not concentrations.** `mmol/mol` is HbA1c IFCC, a substance ratio. `mg/mmol` is an albumin/creatinine ratio. `ml/min/173m2` is eGFR, a rate per body surface area. `%` is ambiguous by nature: it may be a fraction of a cell population, a fraction of a total mass, or activity as a percentage of normal.

**A repeated lowest decile is a detection limit, not a measurement.** When the first deciles are the same round number — `[5, 5, 6.2, 8.3, ...]` — the assay is censored at that floor and everything below was reported as "<5". Read the floor as the assay's sensitivity rather than the population's real low end: a CRP censored at 5 mg/l is an ordinary CRP, while a high-sensitivity assay reads down to about 0.1 mg/l, so that floor argues *against* a high-sensitivity concept.

# How to decide

For each row:

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
2. **Pick the candidate that matches that reading**, and return its `omop_concept_id`. The unit and the values decide between candidates that differ only in property: `mmol/l` takes `[Moles/volume]`, `g/l` takes `[Mass/volume]`, `U/l` takes `[Enzymatic activity/volume]`. The specimen comes from the name — a decoded prefix where there is one, a Finnish specimen word otherwise; LOINC's `Serum or Plasma` is the right term for most routine chemistry, and fasting is not part of the specimen (`fS` is still serum).
3. **Precision must be earned by the name.** LOINC holds both a plain and a qualified concept for most tests. Take the **more precise** candidate whenever the row's name positively states the qualifier — `-Vi` really does say culture, `pikatesti` really does say a rapid test, `dU` really does say a 24-hour collection, `herkka` really does say high sensitivity. Take the plainer candidate when the name does not state it.

   The error to avoid is **inventing** a qualifier, not being specific. Measured against the curated Finnish mappings, this step added a method the reference leaves blank 59 times (usually `Automated count` on a bare blood-count code), took `--trough` variants for plain drug levels, and narrowed `Serum or Plasma` to `Capillary blood` on codes that said no such thing. Of every qualifier you are about to accept, ask: **which characters of this code say so?** If you cannot point at them, take the plainer concept.
4. **A guess that is itself a real concept is weak evidence, never an instruction.** If `loinc_name_guess` appears in the candidate table as an exact name at a score of 1.000, the earlier pass — reading this same row — happened to write the exact name of a concept that exists. That is mildly reassuring and nothing more: the earlier pass writes a name for almost every code it can read anything out of, so landing on a real name can be recognition or coincidence. Never adopt a candidate *because* it equals the guess. Take a different candidate, including a more precise one, whenever the row's own name, unit and values support it better — and take none at all if none fits, however well the guess matched.
5. **When two or more candidates still fit equally well**, prefer a candidate with a `top2000` rank. That list is LOINC's own recommendation for what laboratories should map to, so a concept on it is the intended target and a near-duplicate off it usually is not. It breaks ties and nothing more: a top-2000 concept in the wrong specimen or the wrong units is still the wrong answer.
6. **Leave `omop_concept_id` empty when no candidate is right.** That is a correct, useful answer — it says "this code has no match in what the search returned", which is a fact the next iteration can act on. Common reasons: the code is too truncated or garbled to identify; it is a local administrative or non-laboratory code; or the search simply did not return the concept you know is right.
7. **Never return an id that is not in the candidate table.** Not one you remember, not one you derive from a LOINC code, not a plausible-looking number. Ids that are not in the table are discarded and the row is logged as unanswered, so inventing one only loses the row.

Specific things to watch:

- **A panel is not its components.** If the code orders a bundle, the answer is a panel concept, not one of the bundled analytes: `B-PVK` (perusverenkuva, the basic blood count) and `B-TVK` (taydellinen verenkuva, the complete count with differential) are panels, not hemoglobin. Match the panel's breadth to the code: a basic count is not the same concept as a count with a differential. Conversely, do not map a single reported result to a panel concept just because a panel candidate scored well.
- **Deprecated near-duplicates are already filtered out** of the candidate list — every candidate is a standard, current concept — so you never need to judge validity, only fit.
- **The group is a bag of look-alike codes, not a set of equivalent ones.** It was built by string similarity, so it mixes genuinely different tests whose names happen to resemble each other. Answer every row from its own name, unit and values; never give rows one id because they sit together.
- **A row whose guess was empty can still be mapped** — the pooled list may hold the concept its own name points to. Map it on that row's own evidence, though, never because a neighbouring row was mapped there.

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `omop_concept_id` — the chosen concept's id, copied from the candidate table. Empty if no candidate is right.
- `omop_concept_name` — that candidate's `omop_concept_name`, copied verbatim. Used only to cross-check that the id you copied is the concept you meant; leave it empty when the id is empty.

Then justify and grade what you chose:

- `reasoning` — why each part of the name you chose is right, as **one clause per part, separated by ` ; `**. Each clause names the part and then the evidence it rests on, pointing at the specific characters of the row that carry it. Cover the component, the bracketed property, the specimen, and the method when the name has one. Keep it terse — this is a justification trail, not prose:

      <component> bcs <evidence> ; <[property]> bcs <evidence> ; in <system> bcs <evidence> ; by <method> bcs <evidence>

  Where a part rests on nothing in the row, say that instead of inventing a reason — "no specimen stated in the code" is a useful thing for a reader to find here.

  **When you choose no concept, `reasoning` still matters — it is the only thing you leave behind.** Say what blocked you, specifically: the code is too garbled to identify; it is not a laboratory test; the search returned nothing for this analyte; the candidates were all the wrong specimen; the evidence cannot settle the quantity. "Nothing fitted" is not an answer. A reader must be able to tell a code that is unidentifiable from one the search simply failed on, because those need opposite fixes.
- `certainty` — `high`, `medium` or `low`: how sure you are, on all the evidence together, that this concept is the right one for this row. Weigh the parts by what a wrong answer would cost: a doubtful analyte makes the mapping useless, while an unstated method is a smaller error. A row whose `evidence_level` is `name` should rarely be `high`, since nothing fixes its quantity. Use `low` freely — these are read downstream to decide which mappings can be trusted without review, so a `high` you cannot defend is worse than an honest `low`. Leave it empty when you chose no concept.

Return an entry for EVERY row, including ones you leave unmapped.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which rows you could map and which you could not, where the candidate list was missing the concept you knew was right, where the earlier pass's guess sent the search astray, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 37.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000285 | Sodium [Moles/volume] in Blood | 1.000 | 129 |
| 3000348 | Leukocyte esterase [Presence] in Urine by Test strip | 1.000 | 65 |
| 3002864 | Erythrocytes [#/volume] in Urine by Automated count | 1.000 | 246 |
| 3005456 | Potassium [Moles/volume] in Blood | 1.000 | 106 |
| 3006184 | Hemoglobin [Mass/volume] in Capillary blood | 1.000 |  |
| 3009261 | Glucose [Presence] in Urine by Test strip | 1.000 | 309 |
| 3009508 | Creatinine [Moles/volume] in Urine | 1.000 | 161 |
| 3011397 | Hemoglobin [Presence] in Urine by Test strip | 1.000 | 72 |
| 3014051 | Protein [Presence] in Urine by Test strip | 1.000 | 99 |
| 3020491 | Glucose [Moles/volume] in Blood | 1.000 | 13 |
| 3021447 | Carbon dioxide [Partial pressure] in Venous blood | 1.000 | 523 |
| 3021601 | Nitrite [Presence] in Urine by Test strip | 1.000 | 56 |
| 3028626 | Oxygen [Partial pressure] in Capillary blood | 1.000 |  |
| 3030467 | Casts [#/volume] in Urine by Automated count | 1.000 |  |
| 3031040 | Bacteria [#/volume] in Urine by Automated count | 1.000 |  |
| 3035350 | Ketones [Presence] in Urine by Test strip | 1.000 | 102 |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 1.000 |  |
| 40762887 | Creatinine [Moles/volume] in Blood | 1.000 | 283 |
| 40764133 | Human papilloma virus 16 DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 40764134 | Human papilloma virus 18 DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 1091714 | HIV 1+2 Ab+HIV1 p24 Ag [Presence] in Serum or Plasma | 0.985 |  |
| 37020511 | Human papilloma virus 18 DNA [Presence] in Genital specimen by NAA with probe detection | 0.974 |  |
| 36303442 | Epithelial cells [#/volume] in Urine by Automated | 0.974 |  |
| 37020661 | Human papilloma virus 16 DNA [Presence] in Genital specimen by NAA with probe detection | 0.973 |  |
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 0.973 | 154 |
| 40763086 | Leukocyte esterase [Presence] in Urine by Automated test strip | 0.970 |  |
| 42868547 | Human papilloma virus 16 and 18 DNA [Presence] in Specimen by NAA with probe detection | 0.966 |  |
| 3021125 | Hepatitis C virus RNA [Presence] in Serum or Plasma by NAA with probe detection | 0.966 | 740 |
| 3019902 | Methicillin resistant Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.965 | 146 |
| 3040151 | Glucose [Moles/volume] in Capillary blood | 0.961 |  |
| 3008075 | Hepatitis C virus RNA [Presence] in Blood by NAA with probe detection | 0.960 |  |
| 3030758 | Nitrite [Presence] in Urine by Automated test strip | 0.952 |  |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.952 |  |
| 40760007 | HIV 1+2 Ab+HIV1 p24 Ag [Presence] in Serum or Plasma by Immunoassay | 0.951 |  |
| 46236100 | Human papilloma virus 16 DNA [Presence] in Cervix by NAA with probe detection | 0.950 |  |
| 46236101 | Human papilloma virus 18 DNA [Presence] in Cervix by NAA with probe detection | 0.950 |  |
| 40760861 | Hemoglobin [Presence] in Urine by Automated test strip | 0.949 |  |
| 3029511 | Human papilloma virus DNA [Presence] in Specimen by NAA with probe detection | 0.947 |  |
| 1091414 | Leukocyte esterase [Presence] in Urine | 0.947 |  |
| 40764157 | Human papilloma virus 56 DNA [Presence] in Specimen by NAA with probe detection | 0.946 |  |
| 3043849 | Epstein Barr virus DNA [Units/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.945 |  |
| 40760844 | Ketones [Presence] in Urine by Automated test strip | 0.945 |  |
| 36204252 | Human papilloma virus 18 DNA [Presence] in Tissue by NAA with probe detection | 0.944 |  |
| 36661376 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.943 |  |
| 36661384 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.943 |  |
| 3004391 | Epithelial cells [#/volume] in Urine by Manual count | 0.943 |  |
| 3019077 | Protein [Presence] in 24 hour Urine by Test strip | 0.943 |  |
| 40764135 | Human papilloma virus 26 DNA [Presence] in Specimen by NAA with probe detection | 0.942 |  |
| 1761840 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Specimen by NAA with probe detection | 0.942 |  |
| 3030260 | Glucose [Presence] in Urine by Automated test strip | 0.942 |  |
| 36204250 | Human papilloma virus 16 DNA [Presence] in Tissue by NAA with probe detection | 0.941 |  |
| 1091617 | C reactive protein [Mass/volume] in Serum, Plasma or Blood | 0.939 |  |
| 3003327 | Ova and parasites identified in Stool by Light microscopy | 0.937 | 659 |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.936 |  |
| 40760845 | Protein [Presence] in Urine by Automated test strip | 0.935 |  |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.935 |  |
| 1001833 | Epstein Barr virus DNA [Units/volume] (viral load) in Blood by NAA with probe detection | 0.935 |  |
| 40764154 | Human papilloma virus 6 DNA [Presence] in Specimen by NAA with probe detection | 0.935 |  |
| 645339 | Human papilloma virus 16 E6+E7 mRNA [Presence] in Specimen by NAA with probe detection | 0.934 |  |
| 3001695 | Erythrocytes [#/volume] in Urine by Manual count | 0.933 |  |
| 3048529 | Troponin T.cardiac [Mass/volume] in Blood | 0.933 |  |
| 3033106 | HIV 1 p24 Ab [Presence] in Serum | 0.932 |  |
| 3042804 | Leukocyte esterase+Nitrite [Presence] in Urine by Test strip | 0.931 |  |
| 46235076 | Creatinine [Moles/volume] in Serum, Plasma or Blood | 0.930 |  |
| 40764145 | Human papilloma virus 58 DNA [Presence] in Specimen by NAA with probe detection | 0.930 |  |
| 649459 | Epstein Barr virus DNA [log units/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.928 |  |
| 40760140 | CBC W Auto Differential panel - Blood | 0.926 |  |
| 3029879 | Epithelial cells.squamous [#/volume] in Urine by Automated count | 0.926 |  |
| 3030306 | Epithelial cells.non-squamous [#/volume] in Urine by Automated count | 0.925 |  |
| 3015451 | Hepatitis C virus RNA [Presence] in Specimen by NAA with probe detection | 0.925 |  |
| 3966568 | Human papilloma virus 18 DNA [Presence] in Urine by NAA with probe detection | 0.925 |  |
| 46236251 | Leukocyte esterase [Presence] in Body fluid by Automated test strip | 0.925 |  |
| 3011325 | HIV 1+2 Ab [Presence] in Serum | 0.923 | 442 |
| 3028734 | HIV 1 p24 Ag [Presence] in Serum | 0.922 |  |
| 40760857 | Erythrocytes [#/volume] in Urine by Automated test strip | 0.922 |  |
| 3021513 | Carbon dioxide [Partial pressure] in Mixed venous blood | 0.921 |  |
| 3029187 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma | 0.921 | 516 |
| 1469672 | Bacteria identified in Pus by Anaerobe culture | 0.921 |  |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.920 |  |
| 46235078 | Potassium [Moles/volume] in Serum, Plasma or Blood | 0.919 |  |
| 1616989 | Carbon dioxide [Partial pressure] in Central venous blood | 0.918 |  |
| 37020002 | Multiple myeloma minimal residual disease panel - Bone marrow by Flow cytometry (FC) | 0.918 |  |
| 1001594 | Epstein Barr virus DNA [log units/volume] (viral load) in Blood by NAA with probe detection | 0.915 |  |
| 3000850 | Epithelial cells [#/volume] in Urine | 0.915 |  |
| 3040890 | HIV 1 p24 Ab [Presence] in Serum or Plasma by Immunoassay | 0.914 |  |
| 3050079 | Epstein Barr virus DNA [#/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.914 |  |
| 3043706 | Sodium [Moles/volume] in Arterial blood | 0.914 |  |
| 3047166 | Epithelial cells [#/area] in Urine sediment by Automated count | 0.913 |  |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.912 |  |
| 3020647 | HIV 1 p24 Ag [Presence] in Serum or Plasma by Immunoassay | 0.912 |  |
| 3014305 | Glucose [Presence] in Blood by Test strip | 0.912 |  |
| 42870589 | Drugs of abuse panel - Urine by Screen method | 0.911 |  |
| 3045874 | Casts [#/area] in Urine sediment by Automated count | 0.911 |  |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.911 |  |
| 648911 | Epstein Barr virus DNA [Units/volume] (viral load) in Specimen by NAA with probe detection | 0.911 |  |
| 3028893 | Ketones [Presence] in Urine | 0.910 | 217 |
| 3042812 | Nitrite [Presence] in Urine | 0.910 |  |
| 3002574 | Fasting glucose [Presence] in Urine by Test strip | 0.910 |  |
| 3964702 | Creatinine [Moles/volume] in Venous blood | 0.910 |  |
| 648393 | HIV 1+2 Ab+HIV1 p24 Ag [Measurement] in Serum or Plasma | 0.909 |  |
| 3043409 | Potassium [Moles/volume] in Arterial blood | 0.909 |  |
| 3013539 | Creatinine [Moles/volume] in 24 hour Urine | 0.908 | 1978 |
| 3020416 | Erythrocytes [#/volume] in Blood by Automated count | 0.907 | 9 |
| 1761893 | Epstein Barr virus DNA [Log #/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.907 |  |
| 3041354 | Potassium [Moles/volume] in Venous blood | 0.906 |  |
| 3039401 | Hepatitis C virus RNA [Presence] in Body fluid by NAA with probe detection | 0.905 |  |
| 3037329 | Epstein Barr virus DNA [#/volume] (viral load) in Blood by NAA with probe detection | 0.905 |  |
| 3009531 | Nitrite [Mass/volume] in Urine by Test strip | 0.904 |  |
| 3035962 | HIV 1+2 Ab [Presence] in Serum or Plasma by Immunoassay | 0.903 | 324 |
| 1616317 | Hemoglobin [Mass/volume] in Capillary blood by Oximetry | 0.903 |  |
| 3011960 | Natriuretic peptide B [Mass/volume] in Serum or Plasma | 0.903 | 204 |
| 3024629 | Glucose [Mass/volume] in Urine by Test strip | 0.901 |  |
| 3034979 | HIV 1+2 IgG Ab [Presence] in Serum | 0.900 |  |
| 3002582 | Erythrocytes [#/volume] in Urine | 0.900 |  |
| 648782 | Epstein Barr virus DNA [Presence] in Serum or Plasma by NAA with probe detection | 0.900 |  |
| 3021257 | Drugs of abuse 5 panel - Urine | 0.899 |  |
| 1761890 | Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.899 |  |
| 3003344 | Hemoglobin [Presence] in Urine | 0.899 |  |
| 1469525 | Bacteria identified in Pus by Culture | 0.898 |  |
| 3027315 | Oxygen [Partial pressure] in Blood | 0.898 | 87 |
| 37019579 | Human papilloma virus DNA [Presence] in Genital specimen by NAA with probe detection | 0.897 |  |
| 40764136 | Human papilloma virus 31 DNA [Presence] in Specimen by NAA with probe detection | 0.896 |  |
| 3038702 | Sodium [Moles/volume] in Capillary blood | 0.895 |  |
| 3050934 | HIV 1+Hepatitis C virus RNA [Presence] in Serum or Plasma by NAA with probe detection | 0.895 |  |
| 3028923 | Bacteria [#/area] in Urine sediment by Automated count | 0.895 |  |
| 3026782 | Osmolality of Urine | 0.895 | 556 |
| 1091200 | Bacteria [#/volume] in Urine | 0.895 |  |
| 3044242 | Glucose [Moles/volume] in Arterial blood | 0.894 |  |
| 3049185 | Hemoglobin [Mass/volume] in Urine by Test strip | 0.894 |  |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 0.894 | 1 |
| 46234770 | C reactive protein [Moles/volume] in Serum or Plasma | 0.894 |  |
| 3038515 | Glucose [Moles/volume] in Venous blood | 0.894 |  |
| 1761344 | Epstein Barr virus DNA [Log #/volume] (viral load) in Blood by NAA with probe detection | 0.894 |  |
| 3022810 | Sodium [Moles/volume] in Body fluid | 0.893 |  |
| 3037459 | Creatinine [Moles/volume] in Body fluid | 0.893 | 1234 |
| 3033745 | Troponin I.cardiac [Mass/volume] in Blood | 0.893 |  |
| 649280 | Hepatitis A virus RNA [Presence] in Blood by NAA with probe detection | 0.893 |  |
| 3026726 | Creatinine [Moles/volume] in Specimen | 0.893 |  |
| 3007696 | Carbon dioxide [Partial pressure] in Venous cord blood | 0.893 | 1204 |
| 1091581 | Methicillin resistant Staphylococcus aureus [Presence] in Skin by Organism specific culture | 0.892 |  |
| 3048402 | Erythrocytes [#/area] in Urine sediment by Automated count | 0.891 |  |
| 40764144 | Human papilloma virus 53 DNA [Presence] in Specimen by NAA with probe detection | 0.889 |  |
| 40764148 | Human papilloma virus 67 DNA [Presence] in Specimen by NAA with probe detection | 0.889 |  |
| 40764143 | Human papilloma virus 52 DNA [Presence] in Specimen by NAA with probe detection | 0.889 |  |
| 3007921 | HIV 1 Ag [Presence] in Serum | 0.889 | 785 |
| 3023024 | Carbon dioxide [Partial pressure] in Capillary blood | 0.889 |  |
| 3005897 | Protein [Mass/volume] in Urine by Test strip | 0.886 | 74 |
| 3013290 | Carbon dioxide [Partial pressure] in Blood | 0.885 | 86 |
| 3040006 | Creatinine [Moles/volume] in 12 hour Urine | 0.885 |  |
| 3003159 | Erythrocytes [#/volume] in Body fluid by Automated count | 0.885 | 1726 |
| 3023103 | Potassium [Moles/volume] in Serum or Plasma | 0.885 | 3 |
| 3017250 | Creatinine [Mass/volume] in Urine | 0.884 |  |
| 3039355 | Methicillin resistant Staphylococcus aureus [Presence] in Nose by Organism specific culture | 0.884 |  |
| 3051825 | Creatinine [Mass/volume] in Blood | 0.884 |  |
| 3013906 | HIV 1 Ab [Presence] in Serum | 0.884 | 1611 |
| 42870364 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Blood by Immunoassay | 0.884 |  |
| 3031569 | Natriuretic peptide B [Mass/volume] in Blood | 0.884 | 847 |
| 3010156 | C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method | 0.884 | 348 |
| 3023539 | Ketones [Mass/volume] in Urine by Test strip | 0.884 |  |
| 3019800 | Troponin T.cardiac [Mass/volume] in Serum or Plasma | 0.883 | 291 |
| 3037185 | Protein [Presence] in Urine | 0.883 |  |
| 3020650 | Glucose [Presence] in Urine | 0.882 | 116 |
| 3008116 | Ketones [Moles/volume] in Urine by Test strip | 0.882 | 80 |
| 3036243 | Potassium [Moles/volume] in Body fluid | 0.881 |  |
| 3002032 | Base excess in Venous blood by calculation | 0.881 | 966 |
| 3030141 | Hepatitis C virus RNA panel (viral load) in Serum or Plasma by NAA with probe detection | 0.881 |  |
| 3035729 | Glucose [Moles/volume] in Body fluid | 0.881 | 788 |
| 3050898 | Methicillin resistant Staphylococcus aureus [Presence] in Genital specimen by Organism specific culture | 0.880 |  |
| 3040510 | Creatinine [Moles/time] in 1 hour Urine | 0.879 |  |
| 44787055 | CBC W Differential panel - Cord blood | 0.879 |  |
| 3014918 | Hepatitis C virus RNA [Presence] in Tissue by NAA with probe detection | 0.878 |  |
| 3038830 | Creatinine [Moles/volume] in Urine --baseline | 0.878 |  |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 0.878 | 5 |
| 3966513 | Influenza virus A and Influenza virus B and SARS coronavirus 2 RNA panel - Nose by NAA with non-probe detection | 0.877 |  |
| 3040893 | Potassium [Moles/volume] in Capillary blood | 0.877 |  |
| 36661375 | Influenza virus A and B and SARS-CoV-2 (COVID-19) identified in Respiratory system specimen by NAA with probe detection | 0.877 |  |
| 3019572 | Troponin T.cardiac [Mass/volume] in Venous blood | 0.875 |  |
| 40768439 | Drugs of abuse 5 panel - Urine by Screen method | 0.875 |  |
| 36031949 | Influenza virus A and B and SARS-CoV+SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.875 |  |
| 36032352 | SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.875 |  |
| 42870592 | CBC W Differential panel, method unspecified - Blood | 0.875 |  |
| 648637 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Immunoassay | 0.874 |  |
| 3018447 | Hepatitis C virus RNA [Units/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.874 | 531 |
| 3006735 | Hepatitis A virus RNA [Presence] in Serum by NAA with probe detection | 0.874 |  |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 0.873 | 4 |
| 3003453 | Glucose [Presence] in Urine by Test strip --30 minutes post dose glucose | 0.873 |  |
| 3029435 | Natriuretic peptide.B prohormone N-Terminal [Moles/volume] in Serum or Plasma | 0.873 |  |
| 3002388 | Ova and parasites identified in Stool by Parasite sedimentation | 0.873 |  |
| 3008770 | Glucose [Moles/volume] in Urine by Test strip | 0.873 | 73 |
| 1761482 | Bacteria [#/volume] in Urine by Culture | 0.872 |  |
| 40760950 | Erythrocytes [#/volume] in Dialysis fluid by Automated count | 0.872 |  |
| 648940 | C reactive protein [Measurement] in Serum or Plasma | 0.872 |  |
| 3001501 | Glucose [Moles/volume] in Capillary blood by Glucometer | 0.872 |  |
| 46235760 | Methicillin resistant Staphylococcus aureus [Presence] in Pharynx by Organism specific culture | 0.871 |  |
| 3027946 | Carbon dioxide [Partial pressure] in Arterial blood | 0.871 | 205 |
| 3000483 | Glucose [Mass/volume] in Blood | 0.871 |  |
| 3019493 | Glucose [Presence] in Urine by Test strip --1 hour post dose glucose | 0.871 |  |
| 46235168 | Fasting glucose [Moles/volume] in Blood | 0.870 |  |
| 3046787 | Ova and parasites identified in Stool by Trichrome stain | 0.870 |  |
| 40762353 | Leukocyte esterase [Presence] in Cerebral spinal fluid by Test strip | 0.870 |  |
| 46234833 | Bacteria identified in Abscess by Anaerobe+Aerobe culture | 0.869 |  |
| 1092301 | Erythrocytes [#/volume] in Urine sediment | 0.868 |  |
| 3022621 | pH of Urine by Test strip | 0.868 | 59 |
| 3027215 | Base excess standard in Venous blood by calculation | 0.868 |  |
| 40766103 | Ketones [Presence] in Urine by Test strip --1 hour post dose glucose | 0.868 |  |
| 42529224 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma by Immunoassay | 0.867 |  |
| 1469712 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.867 |  |
| 3036839 | Oxygen [Partial pressure] in Capillary blood --pre treatment | 0.867 |  |
| 21491346 | Pathologic casts [#/volume] in Urine by Automated count | 0.867 |  |
| 36305828 | Drugs of abuse screen W Reflex confirm panel - Urine | 0.865 |  |
| 3005518 | Ova and parasites identified in Stool by Immune stain | 0.865 |  |
| 3005589 | Glucose [Presence] in Urine by Test strip --1.5 hours post dose glucose | 0.865 |  |
| 43055557 | Base excess.100% oxygenated [Moles/volume] standard in Venous blood by calculation | 0.864 |  |
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.864 |  |
| 3012744 | Ova and parasites identified in Specimen by Light microscopy | 0.863 | 527 |
| 3024354 | Oxygen [Partial pressure] in Venous blood | 0.862 | 665 |
| 3004077 | Glucose [Mass/volume] in Capillary blood | 0.862 |  |
| 3001298 | Ova and parasites identified in Stool by McMaster concentration | 0.862 |  |
| 3020389 | Ova and parasites identified in Stool by Concentration | 0.862 | 257 |
| 3050687 | CBC WO Differential panel - Cord blood | 0.861 |  |
| 3027801 | Oxygen [Partial pressure] in Arterial blood | 0.861 | 193 |
| 648594 | Leukocyte esterase [Measurement] in Urine | 0.861 |  |
| 21490733 | Potassium [Mass/volume] in Blood | 0.860 |  |
| 3005448 | Ova and parasites identified in Stool by Iron hematoxylin stain | 0.860 |  |
| 3000963 | Hemoglobin [Mass/volume] in Blood | 0.858 | 2 |
| 3051387 | C reactive protein [Mass/volume] in Capillary blood | 0.856 |  |
| 37020818 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with probe detection | 0.854 |  |
| 3039904 | Epithelial cells.renal [#/volume] in Urine by Computer assisted method | 0.854 |  |
| 3004361 | Ova and parasites identified in Stool by Kinyoun iron hematoxylin stain | 0.854 |  |
| 40766104 | Ketones [Presence] in Urine by Test strip --3 hours post dose glucose | 0.853 |  |
| 3001838 | Sodium [Moles/volume] in Red Blood Cells | 0.853 |  |
| 3004559 | Base deficit in Venous blood | 0.853 | 1187 |
| 3028766 | C reactive protein [Titer] in Serum or Plasma | 0.852 |  |
| 1469767 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Body fluid by Immunoassay | 0.852 |  |
| 3052295 | Natriuretic peptide B [Moles/volume] in Serum or Plasma | 0.852 |  |
| 3003181 | Sodium [Moles/volume] in Urine | 0.851 | 412 |
| 3029080 | Hemoglobin [Entitic mass] in Reticulocytes | 0.851 | 1413 |
| 3002173 | Hemoglobin [Mass/volume] in Arterial blood | 0.850 | 188 |
| 3035968 | Oxygen [Partial pressure] in Capillary blood --post treatment | 0.850 |  |
| 3029162 | Epithelial cells.squamous [#/area] in Urine sediment by Automated count | 0.850 |  |
| 40766105 | Ketones [Presence] in Urine by Test strip --4 hours post dose glucose | 0.849 |  |
| 3035320 | C reactive protein [Mass/volume] in Body fluid | 0.849 |  |
| 3004097 | Oxygen content in Capillary blood | 0.849 |  |
| 1616406 | Base excess standard in Central venous blood | 0.848 |  |
| 3029937 | Albumin [Presence] in Urine by Test strip | 0.848 |  |
| 3009105 | Erythrocytes [#/volume] in Urine by Test strip | 0.848 | 126 |
| 3043088 | Ketones [Presence] in 24 hour Urine | 0.847 |  |
| 1988560 | Cocci bacteria [#/volume] in Urine sediment by Automated count | 0.846 |  |
| 3013823 | Potassium [Moles/volume] in Red Blood Cells | 0.845 |  |
| 3017553 | Oxygen [Partial pressure] (8 hour minimum) in Capillary blood | 0.844 |  |
| 3016038 | Potassium [Moles/volume] in Urine | 0.844 | 493 |
| 1092449 | Base excess in Venous cord blood | 0.843 |  |
| 3026681 | Sodium [Moles/volume] in Specimen | 0.843 |  |
| 1989355 | Bacilliform bacteria [#/volume] in Urine sediment by Automated count | 0.843 |  |
| 3030267 | Hemoglobin [Mass/volume] in Urine by Automated test strip | 0.843 |  |
| 3000965 | C reactive protein [Presence] in Serum or Plasma | 0.843 | 1281 |
| 3021337 | Troponin I.cardiac [Mass/volume] in Serum or Plasma | 0.842 | 113 |
| 40757349 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Blood | 0.842 | 362 |
| 40760892 | CBC W Ordered Manual Differential panel - Blood | 0.842 |  |
| 3029427 | Karyotype [Identifier] in Blood or Tissue Narrative | 0.842 |  |
| 3006462 | Nitrate [Presence] in Urine | 0.842 |  |
| 1091253 | Methicillin resistant Staphylococcus aureus [Presence] in Axilla by Organism specific culture | 0.841 |  |
| 3019383 | Ova and parasites identified in Stool by Baermann concentration | 0.841 |  |
| 3006893 | Glucose [Moles/volume] in Specimen | 0.841 |  |
| 3041412 | Epithelial cells.non-squamous [#/area] in Urine sediment by Automated count | 0.841 |  |
| 3011797 | Bacteria identified in Abscess by Aerobe culture | 0.840 |  |
| 3030981 | Hyaline casts [#/volume] in Urine by Automated count | 0.840 |  |
| 3013171 | Leukocyte esterase [Units/volume] in Urine | 0.840 |  |
| 3010251 | Oxygen [Partial pressure] in Body fluid | 0.840 |  |
| 3029490 | Free Hemoglobin [Presence] in Urine | 0.839 |  |
| 21490848 | Carbon dioxide [Partial pressure] in Pulmonary artery | 0.839 |  |
| 3041290 | Carbon dioxide [Partial pressure] adjusted to patient's actual temperature in Venous blood | 0.839 |  |
| 43533384 | Drugs of abuse panel - Blood by Screen method | 0.838 |  |
| 1470002 | Bacteria identified in Abscess by Anaerobe culture | 0.838 |  |
| 3029350 | Yeast [#/volume] in Urine by Automated count | 0.836 |  |
| 3009343 | pH of Capillary blood | 0.834 | 865 |
| 1175703 | Drugs of abuse panel - Body fluid | 0.833 |  |
| 3004119 | Hemoglobin [Mass/volume] in Venous blood | 0.833 | 1986 |
| 1469858 | Troponin T.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.832 |  |
| 3051593 | INR in Capillary blood by Coagulation assay | 0.832 |  |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.832 |  |
| 40769783 | Troponin T.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.831 |  |
| 3025939 | Karyotype [Identifier] in Blood or Tissue Nominal | 0.831 | 790 |
| 3040799 | Casts [Presence] in Urine by Automated | 0.830 |  |
| 1259993 | Gas and Lactate panel - Venous blood | 0.829 |  |
| 3027969 | Bacteria identified in Wound by Anaerobe culture | 0.829 |  |
| 3041694 | Casts type not specified [#/volume] in Urine by Computer assisted method | 0.828 |  |
| 3029872 | Protein [Mass/volume] in Urine by Automated test strip | 0.828 |  |
| 40762014 | CD4+CD45RO+ cells/CD3+CD4+ (T4 helper) cells [# Ratio] in Blood | 0.827 |  |
| 3012544 | pH of Venous blood | 0.826 | 519 |
| 648479 | CLL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.826 |  |
| 645112 | Stenotrophomonas maltophilia.multidrug resistant [Presence] in Specimen by Organism specific culture | 0.826 |  |
| 40758548 | Home drug screening panel - Urine | 0.825 |  |
| 1616922 | Base excess in Central venous blood by calculation | 0.825 |  |
| 3032172 | Bacteria [Presence] in Urine by Automated | 0.825 |  |
| 3000991 | Gas panel - Venous blood | 0.824 |  |
| 21493470 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with non-probe detection | 0.824 |  |
| 3965306 | Troponin T.cardiac [Mass/volume] in 6 hour Serum or Plasma | 0.824 |  |
| 1616736 | Protein/Creatinine Qualitative in Urine by Test strip | 0.824 |  |
| 3043688 | Hemoglobin [Mass/volume] in Body fluid | 0.821 |  |
| 3038950 | Acinetobacter sp multidrug resistant identified in Specimen by Organism specific culture | 0.820 |  |
| 40760141 | CBC W Reflex Manual Differential panel - Blood | 0.819 |  |
| 46234834 | Bacteria identified in Bone by Anaerobe+Aerobe culture | 0.819 |  |
| 46236733 | Noninvasive prenatal fetal 18 and 21 aneuploidy panel - Plasma cell-free DNA by Sequencing | 0.819 | 3000 |
| 3043425 | Karyotype [Identifier] in Bone marrow Nominal | 0.818 | 1777 |
| 3965853 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Blood or Marrow by Flow cytometry (FC) | 0.818 |  |
| 36659824 | Bacteria.carbapenem resistant identified in Specimen by Organism specific culture | 0.818 |  |
| 43533989 | Noninvasive prenatal fetal aneuploidy panel - Plasma cell-free DNA | 0.817 | 3000 |
| 36660607 | Microalbumin [Presence] in Urine by Test strip | 0.817 |  |
| 1469831 | Hyaline casts [#/volume] in Urine sediment by Automated count | 0.817 |  |
| 3027005 | Bacteria identified in Tissue by Aerobe culture | 0.816 |  |
| 3024447 | Bacteria identified in Specimen by Anaerobe+Aerobe culture | 0.816 | 1062 |
| 1616954 | Amphetamines panel - Urine by Confirmatory method | 0.816 |  |
| 3016437 | Bacteria identified in Aspirate by Anaerobe culture | 0.816 |  |
| 1175629 | Drugs of abuse panel - Hair | 0.816 |  |
| 649098 | B-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.815 |  |
| 3002619 | Bacteria identified in Specimen by Culture | 0.815 | 39 |
| 1091300 | Yersinia enterocolitica DNA [Presence] in Specimen by NAA with probe detection | 0.815 |  |
| 46234968 | Reticulocyte cellular hemoglobin distribution width [Entitic mass] in Blood by calculation | 0.814 |  |
| 3023001 | Base excess in Mixed venous blood by calculation | 0.813 |  |
| 1091245 | Enteric bacteria panel - Stool by NAA with probe detection | 0.812 |  |
| 3041130 | Mixed cellular casts [#/volume] in Urine by Computer assisted method | 0.812 |  |
| 21491345 | Pathologic casts [#/area] in Urine by Automated count | 0.812 |  |
| 648732 | Reticulocyte - RBC Hemoglobin [Entitic mass difference] in Blood | 0.812 |  |
| 40758903 | Hemoglobin [Mass/volume] in Blood by Oximetry | 0.812 |  |
| 42869451 | Hemoglobin [Entitic mass] in Reticulocytes by Automated count | 0.811 |  |
| 1091454 | Yersinia pseudotuberculosis complex DNA [Presence] in Specimen by NAA with probe detection | 0.811 |  |
| 3040501 | WBC casts [#/volume] in Urine by Computer assisted method | 0.811 |  |
| 3007435 | Base excess in Venous cord blood by calculation | 0.810 |  |
| 1469828 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by High sensitivity method | 0.810 |  |
| 37020081 | Noninvasive prenatal fetal aneuploidy and microdeletion panel - Plasma cell-free DNA by Sequencing | 0.809 |  |
| 3966454 | Gas and electrolytes panel - Venous blood | 0.809 |  |
| 1091284 | Glucose [Moles/volume] in Interstitial fluid | 0.808 |  |
| 21493361 | Gastrointestinal pathogens DNA and RNA panel - Stool by NAA with non-probe detection | 0.808 |  |
| 645216 | T-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.808 |  |
| 3053010 | Karyotype [Identifier] in Cord blood Nominal | 0.808 |  |
| 3027901 | Hemoglobin [Mass/volume] in Arterial cord blood | 0.807 |  |
| 3965536 | Acute myeloid leukemia minimal residual disease in Bone marrow by Flow cytometry (FC) Narrative | 0.807 |  |
| 3010169 | Leukocyte esterase [Enzymatic activity/volume] in Leukocytes | 0.807 |  |
| 37019628 | Gastrointestinal bacterial pathogens panel - Stool by NAA with probe detection | 0.806 |  |
| 3049559 | Karyotype [Identifier] in Blood or Tissue by High resolution Nominal | 0.806 |  |
| 3051343 | DXA Bone [Mass/Area] Bone density | 0.806 |  |
| 3039059 | Drugs of abuse 7 and Alcohol and Tricyclics panel - Urine by Screen method | 0.804 |  |
| 46236732 | Noninvasive prenatal fetal 13 and 18 and 21 aneuploidy panel - Plasma cell-free DNA by Sequencing | 0.802 | 3000 |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.802 |  |
| 3021722 | DXA Femur [Mass/Area] Bone density | 0.802 |  |
| 3041041 | Hemoglobin [Mass/volume] in Cord blood | 0.802 |  |
| 1092282 | Methadone Confirmatory panel - Urine | 0.801 |  |
| 21492663 | Yersinia enterocolitica recN gene [Presence] in Stool by NAA with probe detection | 0.800 |  |
| 3027484 | Hemoglobin [Mass/volume] in Blood by calculation | 0.800 |  |
| 3029361 | Urinalysis dipstick panel - Urine by Automated test strip | 0.800 |  |
| 648549 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.800 |  |
| 3029305 | pH of Urine by Automated test strip | 0.799 |  |
| 21492659 | Gastrointestinal pathogens panel - Stool by NAA with probe detection | 0.799 |  |
| 3033173 | Hemoglobin [Presence] in Specimen | 0.798 |  |
| 3049714 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma | 0.798 |  |
| 3031015 | pH of 24 hour Urine by Test strip | 0.798 |  |
| 3052990 | Drugs of abuse panel - Meconium | 0.798 |  |
| 36306105 | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.796 |  |
| 1092191 | Enteric pathogen panel - Stool by NAA with probe detection | 0.795 |  |
| 3023601 | Vancomycin resistant enterococcus [Presence] in Specimen by Organism specific culture | 0.794 |  |
| 3023764 | Bacteria identified in Specimen by Respiratory culture | 0.793 |  |
| 40766210 | Pseudomonas aeruginosa.multidrug resistant isolate [Presence] in Specimen by Organism specific culture | 0.793 |  |
| 3036941 | Urinalysis complete panel - Urine | 0.792 |  |
| 1617363 | Noninvasive prenatal fetal aneuploidy panel - Plasma cell-free+WBC DNA by Dosage of chromosome-specific cfDNA | 0.792 |  |
| 21491103 | Multiple drug resistant gram negative organism [Identifier] in Specimen by Culture | 0.792 |  |
| 3033804 | DXA Lumbar spine [Mass/Area] Bone density | 0.791 |  |
| 3006147 | Osmolality of 24 hour Urine | 0.788 |  |
| 3052504 | DXA Calcaneus [Mass/Area] Bone density | 0.786 |  |
| 3023757 | Gas and Carbon monoxide panel - Venous blood | 0.786 |  |
| 3037242 | Nitrite [Mass/volume] in Urine | 0.786 |  |
| 647840 | CLL minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.786 |  |
| 42529473 | Bone density quantitative measurement by DXA panel | 0.785 |  |
| 3044552 | Amphetamine+Methamphetamine [Presence] in Urine | 0.785 |  |
| 46235811 | Reticulocyte corpuscular hemoglobin concentration mean [Mass/volume] in Blood | 0.784 |  |
| 40761558 | Sulfites [Presence] in Urine by Test strip | 0.784 |  |
| 3002101 | DXA Radius and Ulna [Mass/Area] Bone density | 0.783 |  |
| 3052486 | DXA Hip [Mass/Area] Bone density | 0.783 |  |
| 3037426 | Urobilinogen [Presence] in Urine by Test strip | 0.783 | 134 |
| 1616796 | Gas panel - Central venous blood | 0.783 |  |
| 648844 | B-ALL minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.781 |  |
| 3964699 | Gas and electrolytes point of care panel - Venous blood | 0.781 |  |
| 3027247 | Bacteria identified in Specimen | 0.781 |  |
| 3045414 | Leukocytes [Presence] in Urine | 0.781 |  |
| 3045058 | Bacteria # 3 identified in Specimen by Culture | 0.781 |  |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.780 |  |
| 1761484 | Gram negative bacteria.colistin resistant identified in Stool by Organism specific culture | 0.780 |  |
| 3046647 | Bacteria # 4 identified in Specimen by Culture | 0.779 |  |
| 3045560 | Bacteria # 2 identified in Specimen by Culture | 0.779 |  |
| 3041449 | Collagen crosslinked C-telopeptide [Mass/volume] in Serum or Plasma | 0.778 |  |
| 3030561 | Karyotype [Identifier] in Specimen Nominal | 0.778 |  |
| 648476 | Amphetamine+Methamphetamine [Measurement] in Urine | 0.778 |  |
| 46234777 | Amphetamine+Methamphetamine [Presence] in Urine by Screen method | 0.778 |  |
| 36660149 | OxyCODONE and metabolites panel - Urine by Confirmatory method | 0.778 |  |
| 36203242 | DXA Humerus [Mass/Area] Bone density | 0.777 |  |
| 1616438 | pH of Central venous blood | 0.777 |  |
| 21494209 | DXA Femur - left [Mass/Area] Bone density | 0.776 |  |
| 40758490 | Osmolality of Urine--baseline | 0.775 |  |
| 3044420 | Bacteria # 6 identified in Specimen by Culture | 0.775 |  |
| 3043867 | Bacteria # 8 identified in Specimen by Culture | 0.775 |  |
| 3021530 | Procollagen type I [Mass/volume] in Serum | 0.774 |  |
| 1617152 | Noninvasive prenatal fetal aneuploidy and 22q11.2 deletion panel - Plasma cell-free+WBC DNA by Dosage of chromosome-specific cfDNA | 0.773 |  |
| 40771543 | Amphetamines panel - Meconium by Confirmatory method | 0.773 |  |
| 3041326 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Tissue | 0.773 |  |
| 3045740 | CD56 cells/CD38 Cells [# Ratio] in Blood | 0.773 |  |
| 3041440 | Amphetamine+Methamphetamine [Presence] in Specimen | 0.773 |  |
| 3014859 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Body fluid | 0.773 |  |
| 36203243 | DXA Humerus - left [Mass/Area] Bone density | 0.772 |  |
| 646446 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.771 |  |
| 3029318 | Maternal screen for fetal abnormalities such as Open Neural Tube Defects, Trisomy 21 or Trisomy 18 panel - Serum or Plasma | 0.770 |  |
| 3039402 | Gas panel - Mixed venous blood | 0.770 |  |
| 3051698 | Osmolality of Urine by calculation | 0.769 |  |
| 40762358 | Karyotype [Identifier] in Blood or Tissue by FISH Narrative | 0.768 |  |
| 3017823 | Kappa lymphocytes/Lymphocytes.lambda [# Ratio] in Blood | 0.767 |  |
| 21494208 | DXA Femur - right [Mass/Area] Bone density | 0.766 |  |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.766 |  |
| 3019198 | Lymphocytes [#/volume] in Blood | 0.765 | 70 |
| 3001405 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood | 0.765 | 441 |
| 36660656 | CBC W Differential panel - Stem cell product | 0.765 |  |
| 42869547 | Procollagen type III.N-terminal propeptide [Mass/volume] in Serum | 0.763 |  |
| 3030830 | pH of Body fluid by Test strip | 0.761 |  |
| 46235160 | Noninvasive prenatal fetal aneuploidy and microdeletion panel based on Plasma cell-free+WBC DNA by Dosage of chromosome-specific circulating cell free (ccf) DNA | 0.761 | 3000 |
| 40761511 | CBC panel - Blood by Automated count | 0.760 |  |
| 46236075 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma by Immunoassay | 0.759 |  |
| 3040705 | Amphetamine+Methamphetamine [Presence] in Serum or Plasma | 0.759 |  |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.758 |  |
| 3020073 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Specimen | 0.757 |  |
| 43533918 | Hemoglobin [Entitic substance] in Reticulocytes by Automated count | 0.757 |  |
| 3012388 | pH of Mixed venous blood | 0.756 |  |
| 3030688 | Urinalysis panel - Urine by Auto | 0.755 |  |
| 1002224 | Polysomnography panel | 0.754 |  |
| 3008905 | Diffusion capacity.carbon monoxide | 0.753 |  |
| 3015209 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bone marrow | 0.753 |  |
| 3044933 | Cardiac 2D echo panel | 0.752 |  |
| 3965213 | Electrolytes panel - Venous blood | 0.752 |  |
| 648527 | Amphetamines [Measurement] in Urine | 0.751 |  |
| 3007449 | CD3+CD8+ (T8 suppressor) cells/cells in Blood | 0.750 | 397 |
| 3034458 | CD4+CD45RA+ cells/CD8 Cells [# Ratio] in Blood | 0.750 |  |
| 42870577 | Diffusion capacity.carbon monoxide/Alveolar volume adjusted for hemoglobin | 0.750 |  |
| 1091049 | Amphetamine [Presence] in Urine | 0.748 |  |
| 648501 | Amphetamine [Measurement] in Urine | 0.748 |  |
| 3053027 | Karyotype [Identifier] in Urine Nominal | 0.746 |  |
| 40765090 | Chromosome analysis panel - Blood from Fetus by G-banded | 0.744 |  |
| 3028167 | CD3+CD4+ (T4 helper) cells [#/volume] in Blood | 0.744 | 515 |
| 3040526 | Collagen crosslinked C-telopeptide [Moles/volume] in Serum or Plasma | 0.743 |  |
| 3029414 | Hydrogen ion [Moles/volume] in Venous blood | 0.742 |  |
| 40760486 | Osmolality of 12 hour Urine | 0.742 |  |
| 3003338 | MCHC [Entitic Mass/volume] in Red Blood Cells | 0.741 |  |
| 36031493 | Protein/Osmolality [Ratio] in Urine | 0.741 |  |
| 3034226 | Lambda lymphocytes/Lymphocytes in Blood | 0.740 |  |
| 3010421 | pH of Blood | 0.740 | 97 |
| 1988420 | Gas and electrolytes panel - Arterial blood | 0.740 |  |
| 3019060 | Gas panel - Arterial blood | 0.739 |  |
| 3015736 | pH of Urine | 0.739 | 612 |
| 3016901 | Lambda lymphocytes [#/volume] in Blood | 0.739 |  |
| 40759746 | Procollagen type III [Mass/volume] in Serum | 0.738 |  |
| 21493670 | CD27- cells/CD3+CD8+ (T8 suppressor cells) cells in Blood | 0.737 |  |
| 3022670 | pH of Venous cord blood | 0.736 | 1082 |
| 43055234 | pH of Vaginal fluid by Test strip | 0.736 |  |
| 3028160 | Osmolality of Specimen | 0.736 |  |
| 42870588 | Differential panel, method unspecified - Blood | 0.735 |  |
| 40760138 | Urinalysis dipstick W Reflex Culture panel - Urine | 0.734 |  |
| 3025271 | CD3-CD16+CD56+ (Natural killer) cells [#/volume] in Blood | 0.734 |  |
| 3025763 | Microscopic exam [Interpretation] of Tissue fine needle aspirate by Cytology | 0.732 |  |
| 3008943 | Abnormal lymphocytes [#/volume] in Blood | 0.732 |  |
| 46236282 | Fetal chromosome 13+18+21+Y aneuploidy [Presence] based on dosage of chromosome-specific cell-free DNA from Maternal plasma | 0.730 |  |
| 46235809 | Reticulocyte hemoglobin distribution width [Mass/volume] in Blood by calculation | 0.730 |  |
| 40760842 | Osmolality of Urine--3rd specimen | 0.729 |  |
| 3051038 | Chromosome [Identifier] in Blood or Tissue by Molecular genetics method | 0.728 |  |
| 3049183 | Collagen crosslinked C-telopeptide [Mass/volume] in Urine | 0.726 |  |
| 3051314 | MCHC [Entitic Mass/volume] in Red Blood Cells from Cord blood | 0.725 |  |
| 1176291 | B-cell phenotyping panel - Blood | 0.725 |  |
| 3050087 | Osmolality.urine/Osmolality.serum | 0.725 |  |
| 1469687 | pH of Urine by pH-meter | 0.724 |  |
| 3045467 | Natural killer cell function [Units/volume] in Blood | 0.724 |  |
| 3032080 | INR in Blood by Coagulation assay | 0.723 | 206 |
| 40760841 | Osmolality of Urine--2nd specimen | 0.723 |  |
| 3030662 | Karyotype [Identifier] in Amniotic fluid Nominal | 0.722 | 1161 |
| 40760142 | Auto Differential panel - Blood | 0.719 |  |
| 3023300 | Diffusion capacity/Alveolar volume by Single breath.carbon monoxide+Helium | 0.718 |  |
| 3008320 | Kappa lymphocytes [#/volume] in Blood | 0.718 |  |
| 40760866 | Procollagen type III.N-terminal propeptide [Units/volume] in Serum | 0.718 |  |
| 1617299 | Diffusion capacity.carbon monoxide/Predicted | 0.717 |  |
| 3045592 | Acute leukemia panel - Specimen by Flow cytometry (FC) | 0.717 |  |
| 3000330 | Specific gravity of Urine by Test strip | 0.716 | 71 |
| 3966204 | Leukemia and lymphoma immunophenotyping in Specimen Document by Flow cytometry (FC) | 0.716 |  |
| 3008440 | Collagen crosslinked N-telopeptide [Moles/volume] in Serum | 0.715 |  |
| 3006400 | Diffusion capacity.carbon monoxide adjusted for hemoglobin | 0.715 |  |
| 3050452 | Leukogram panel - Blood | 0.714 |  |
| 1616370 | Osteoporosis Index of Risk panel | 0.714 |  |
| 40761508 | Leukocyte morphology panel - Blood | 0.713 |  |
| 3051861 | Differential panel - Bone marrow | 0.713 |  |
| 3040135 | pH of Capillary blood adjusted to patient's actual temperature | 0.712 |  |
| 1259654 | Diagnostic multisection transesophageal and cardioversion panel Heart | 0.710 |  |
| 3043216 | Cardiovascular physiologic and EKG assessment panel | 0.708 |  |
| 3015145 | Diffusion capacity.carbon monoxide Predicted | 0.708 |  |
| 1175938 | Lymphocyte subset and B-cell phenotyping panel - Blood | 0.708 |  |
| 3009744 | MCHC [Entitic Mass/volume] in Red Blood Cells by Automated count | 0.708 | 10 |
| 3030327 | pH of Capillary blood from Fetus | 0.707 |  |
| 3029327 | Hydrogen ion [Moles/volume] in Capillary blood | 0.706 |  |
| 3018418 | pH of Serum or Plasma | 0.705 | 160 |
| 3047142 | Chronic leukemia panel - Specimen by Flow cytometry (FC) | 0.704 |  |
| 40771046 | pH of Peritoneal fluid by Test strip | 0.703 |  |
| 1617225 | Diffusion capacity.carbon monoxide --pre bronchodilation | 0.700 |  |
| 3041392 | Hydrogen ion [Moles/volume] in Mixed venous blood | 0.695 |  |
| 3038999 | pH of Venous blood adjusted to patient's actual temperature | 0.693 |  |
| 21494970 | Cardiovascular physiologic assessment panel | 0.688 |  |
| 1616566 | Diffusion capacity.carbon monoxide --post bronchodilation | 0.687 |  |
| 3053181 | Prothrombin time (PT) in Capillary blood by Coagulation assay | 0.686 |  |
| 40757359 | Lymphoma - CLL screen panel - Specimen by Flow cytometry (FC) | 0.686 |  |
| 3043821 | Protein and Glucose panel - Urine by Test strip | 0.684 |  |
| 3050489 | Study report Skeletal system DXA | 0.684 |  |
| 1988866 | Antipsychotics drug panel - Urine by Confirmatory method | 0.684 |  |
| 3038908 | pH of Blood product unit | 0.681 |  |
| 3027232 | Diffusion capacity/Alveolar volume | 0.681 |  |
| 37020879 | Carbon monoxide [Mass/volume] in Air | 0.675 |  |
| 3042605 | INR in Platelet poor plasma or blood by Coagulation assay | 0.671 |  |
| 44787089 | Stone analysis panel | 0.667 |  |
| 3015235 | Bicarbonate [Moles/volume] in Capillary blood | 0.662 | 1086 |
| 42868466 | Maximum expiratory gas flow/Predicted maximum expiratory gas flow Respiratory system airway --pre bronchodilation | 0.658 |  |
| 1761790 | Cardiac left ventricular segmental wall motion by echo panel | 0.653 |  |
| 42868467 | Maximum expiratory gas flow/Predicted maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.649 |  |
| 3022217 | INR in Platelet poor plasma by Coagulation assay | 0.646 | 53 |
| 3023329 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter | 0.645 |  |
| 3044889 | 12 lead EKG panel | 0.643 |  |
| 3964745 | Pathology report microscopic observation in Specimen | 0.643 |  |
| 3002256 | Pathology report gross observation | 0.642 |  |
| 42869550 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --pre therapy | 0.640 |  |
| 21491694 | Cardiac procedure complications panel | 0.639 |  |
| 3019794 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --post therapy | 0.634 |  |
| 40768804 | Tissue Pathology biopsy report | 0.633 |  |
| 1091959 | CT Hip [Mass/volume] Multisection for bone density | 0.631 |  |
| 42868465 | Maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.631 |  |
| 1988764 | Electromyography panel | 0.630 |  |
| 42868488 | Positive airway pressure panel | 0.630 |  |
| 44817246 | Macroscopic observation [Interpretation] in Specimen Narrative | 0.629 |  |
| 3039150 | Biopsy [Interpretation] in Specimen Narrative | 0.629 |  |
| 1091572 | CT Spine [Mass/volume] Multisection for bone density | 0.628 |  |
| 3032885 | Biopsy [Interpretation] in Muscle Narrative | 0.627 |  |
| 42868464 | Maximum expiratory gas flow Respiratory system airway --pre bronchodilation | 0.623 |  |
| 42528497 | Personal best peak expiratory gas flow Respiratory system airway | 0.623 |  |
| 3026358 | Preparation techniques [Type] in Cervical or vaginal smear or scraping by Cyto stain | 0.623 |  |
| 1092363 | CT Hip [T-score] Multisection for bone density | 0.621 |  |
| 3011173 | Microscopic observation [Identifier] in Tissue by Hematoxylin and eosin stain | 0.621 |  |
| 46235080 | Noninvasive arteriosclerosis studies panel | 0.619 |  |
| 40760874 | Microscopic exam [Interpretation] of Bone marrow by Cytology | 0.616 |  |
| 1091772 | CT Hip [Z-score] Multisection for bone density | 0.616 |  |
| 3024198 | Microscopic observation [Identifier] in Tissue by Giemsa stain | 0.615 |  |
| 3031723 | Peak flow measure duration Respiratory system airway by Peak flow meter | 0.614 |  |
| 3003891 | Specimen preparation [Type] | 0.613 |  |
| 42868463 | Maximum expiratory gas flow Respiratory system airway Predicted | 0.612 |  |
| 646570 | Warfarin [Measurement] in Serum or Plasma | 0.611 |  |
| 1092172 | CT Femur [Mass/volume] Multisection for bone density | 0.611 |  |
| 42528681 | Cardiac nuclear imaging SPECT panel | 0.610 |  |
| 43533840 | Percent heparin inhibition [Ratio] in Serum | 0.606 |  |
| 21494972 | Heart murmur assessment panel | 0.606 |  |
| 43055246 | Days in therapeutic INR range/Days INR result determined [Ratio] | 0.605 |  |
| 647347 | Glucose [Measurement] in Capillary blood | 0.605 |  |
| 3049361 | Cytology report of Specimen Cyto stain | 0.594 |  |
| 1988411 | Permanent pacemaker panel | 0.588 |  |
| 3025986 | Microscopic observation [Identifier] in Specimen by Cyto stain | 0.581 | 1498 |
| 3030078 | Cell type in Specimen | 0.576 |  |
| 3028846 | Blood pressure device panel | 0.575 |  |
| 42868479 | Apnea hypopnea index 24 hour | 0.574 |  |
| 3034937 | Oxygen saturation device panel | 0.574 |  |
| 21493451 | Spirometry panel | 0.573 |  |
| 3043405 | Microscopic observation [Identifier] in Specimen by Non-gynecological cytology method | 0.572 |  |
| 3014500 | Microscopic observation [Identifier] in Deep tissue fine needle aspirate by Cyto stain | 0.570 |  |
| 3036843 | Microscopic observation [Identifier] in Soft tissue fine needle aspirate by Cyto stain | 0.569 |  |
| 40758733 | Microscopic observation [Identifier] in Endometrium by Cyto stain | 0.569 |  |
| 36660247 | Specimen Processing comment | 0.568 |  |
| 21494996 | Respiratory assessment panel | 0.568 |  |
| 1988318 | Temporary pacemaker panel | 0.565 |  |
| 40758294 | Paroxysmal nocturnal panel - Blood | 0.563 |  |
| 40765372 | PhenX - respiratory - sleep apnea - adult protocol 091501 | 0.541 |  |
| 42868492 | Central apnea index 24 hour | 0.540 |  |
| 21493450 | Pulmonary function test panel | 0.539 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 222 | -histologinensolublokkisytologisestanäytteestä |  | 100% | name | 214 | 100 |  |  |  |  | Cell block preparation [Procedure] in Cytology specimen by Histology |
| 223 | -humanpapillomavirusgenotyyppi16 |  | 100% | name | 301 | 100 |  |  |  |  | Human papilloma virus 16 DNA [Presence] in Specimen by NAA with probe detection |
| 224 | -humanpapillomavirusgenotyyppi18 |  | 100% | name | 301 | 100 |  |  |  |  | Human papilloma virus 18 DNA [Presence] in Specimen by NAA with probe detection |
| 225 | -humanpapillomavirusgenotyyppimuupatogeeninenhpv |  | 100% | name | 252 | 100 |  |  |  |  | Human papilloma virus high risk types DNA [Presence] in Specimen by NAA with probe detection |
| 226 | -lisämaksukiireellisenäpyydetyllenäytteelle |  | 100% | name | 584 | 100 |  |  |  |  |  |
| 227 | -lisätutkimuspyyntöaiemmintutkitullenäytteelle |  | 100% | name | 191 | 100 |  |  |  |  |  |
| 228 | -lisävastaus2laskutuskuitatullenäytteelle |  | 100% | name | 438 | 100 |  |  |  |  |  |
| 229 | -lisävastauslaskutuskuitatullenäytteelle |  | 100% | name | 2865 | 100 |  |  |  |  |  |
| 230 | -moniresistentitgram-negatiivisetsauvat,viljely |  | 100% | name | 122 | 100 |  |  |  |  | Bacteria.Gram negative.multidrug resistant identified in Specimen by Culture |
| 231 | -moniresistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 163 | 100 |  |  |  |  | Bacteria.Gram negative.multidrug resistant identified in Specimen by Culture |
| 232 | -resistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 314 | 100 |  |  |  |  | Bacteria.Gram negative.resistant identified in Specimen by Culture |
| 233 | -staphylococcusaureus,metilliiniresist.viljely |  | 100% | name | 248 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Specimen by Organism specific culture |
| 234 | -staphylococcusaureus,metisilliiniresistentti,v |  | 100% | name | 540 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Specimen by Organism specific culture |
| 235 | b-glukoosi,hoitoyksikönvieritesti,kokoveri |  | 100% | name+values | 687 | 0.15 | [5.55, 5.93, 6.7, 7.42, 8.33, 9.1, 10.22, 12.18, 14.28] |  | Blood |  | Glucose [Moles/volume] in Blood |
| 236 | b-hematologisenpotilaanperuskaryotyypinmääritys |  | 100% | name | 125 | 100 |  |  | Blood |  | Karyotype [Identifier] in Blood for Hematology-Oncology |
| 237 | b-kreatiniini,hoitoyksikönvieritesti,veri |  | 100% | name+values | 167 | 0 | [58.29, 69.03, 76.8, 84.73, 95.67, 105.12, 116.21, 134.79, 170] |  | Blood |  | Creatinine [Moles/volume] in Blood |
| 238 | bakteerit,virtsasta,partikkelinlaskijalla,osatutk. |  | 100% | name | 212 | 100 |  |  |  |  | Bacteria [#/volume] in Urine by Automated count |
| 239 | bm-pahanlaatuisenveritaudinimmunofenotyypitys |  | 100% | name | 191 | 100 |  |  | Bone marrow |  | Leukemia-Lymphoma immunophenotyping panel - Bone marrow |
| 240 | bm-pahanlaatuisenveritaudinimmunofenotyyppinenjäännöstautianalyysi |  | 100% | name | 162 | 100 |  |  | Bone marrow |  | Minimal residual disease panel - Bone marrow by Flow cytometry (FC) |
| 241 | cb-hemoglobiini,vieritestihoitoyksikössä | g/l | 100% | name+unit+values | 101 | 0 | [84.5, 92.5, 100.5, 112.5, 121.56, 127.06, 131.83, 135.83, 146] |  | Capillary blood |  | Hemoglobin [Mass/volume] in Capillary blood |
| 242 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä | mmol/l | 100% | name+unit+values | 5203 | 0 | [5.2, 6.16, 6.92, 7.87, 8.89, 10.17, 11.74, 13.96, 16.77] |  |  |  | Glucose [Moles/volume] in Capillary plasma |
| 243 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä |  | 0% | name+values | 19 | 100 | [5.33, 6.26, 7.1, 7.98, 9.1, 10.33, 11.92, 13.89, 16.96] |  |  |  | Glucose [Moles/volume] in Capillary plasma |
| 244 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella | mg/l | 80% | name+unit+values | 771 | 0 | [2.6, 5.17, 9.64, 14.69, 22, 32.29, 47.95, 69.4, 106.84] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 245 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella |  | 20% | name | 192 | 85.42 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 246 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 97% | name+unit+values | 438 | 0 | [26.9, 30, 31.94, 33, 34, 34.57, 35, 36, 37.53] |  | Erythrocyte |  | Reticulocyte hemoglobin content [Entitic mass] in Blood |
| 247 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 3% | name | 15 | 6.67 |  |  | Erythrocyte |  | Reticulocyte hemoglobin content [Entitic mass] in Blood |
| 248 | emäsylimäärä,laskimoverestä,pikatesti␤ | mmol/l | 52% | name+unit | 373 | 0 |  |  |  |  | Base excess [Moles/volume] in Venous blood |
| 249 | emäsylimäärä,laskimoverestä,pikatesti␤ |  | 48% | name | 339 | 19.47 |  |  |  |  | Base excess [Moles/volume] in Venous blood |
| 250 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 96% | name+unit+values | 203 | 0 | [0.2, 0.4, 0.66, 1, 1.3, 1.71, 2.47, 3.65, 8.32] |  |  |  | Epithelial cells [#/volume] in Urine by Automated count |
| 251 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. |  | 4% | name | 9 | 100 |  |  |  |  | Epithelial cells [#/volume] in Urine by Automated count |
| 252 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta | iu/ml | 9% | name+unit | 24 | 0 |  |  |  |  | Epstein-Barr virus DNA [Units/volume] in Plasma by NAA with probe detection |
| 253 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta |  | 91% | name | 241 | 100 |  |  |  |  | Epstein-Barr virus DNA [Units/volume] in Plasma by NAA with probe detection |
| 254 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 95% | name+unit+values | 202 | 0 | [3.19, 4.28, 5.76, 7.13, 9.35, 12.16, 16.65, 32.02, 93.76] |  |  |  | Erythrocytes [#/volume] in Urine by Automated count |
| 255 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. |  | 5% | name | 10 | 100 |  |  |  |  | Erythrocytes [#/volume] in Urine by Automated count |
| 256 | fp-kollageenii:nbeta-karboksiterminaalinentelopeptidi | ug/l | 100% | name+unit+values | 299 | 0 | [0.08, 0.14, 0.17, 0.21, 0.26, 0.3, 0.36, 0.45, 0.63] |  | Fasting plasma |  | Telopeptide.beta C-terminal.collagen type I [Mass/volume] in Plasma |
| 257 | happamusaste,kapillaariverestä,pikatesti␤ |  | 100% | name | 1262 | 0.24 |  |  |  |  | pH [Logarithmic Content] in Capillary blood |
| 258 | happamuusaste,laskimoverestä,pikatesti␤ |  | 100% | name | 712 | 0.7 |  |  |  |  | pH [Logarithmic Content] in Venous blood |
| 259 | happiosapaine,kapillaariverestä,pikatesti␤ | kpa | 100% | name+unit | 1260 | 0 |  |  |  |  | Oxygen [Partial pressure] in Capillary blood |
| 260 | happoemästasejahappi,laskimoverestä,pikatesti␤ |  | 100% | name | 643 | 100 |  |  |  |  | Blood gas panel - Venous blood |
| 261 | hepatiittic-virus,nh,jatkotutkimus,plasmasta |  | 100% | name | 512 | 100 |  |  |  |  | Hepatitis C virus RNA [Presence] in Plasma by NAA with probe detection |
| 262 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ | kpa | 99% | name+unit | 707 | 0 |  |  |  |  | Carbon dioxide [Partial pressure] in Venous blood |
| 263 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ |  | 1% | name | 5 | 100 |  |  |  |  | Carbon dioxide [Partial pressure] in Venous blood |
| 264 | hpv-gt16aptimapanther,apututkimustulostensiirtoon |  | 100% | name | 149 | 100 |  |  |  |  |  |
| 265 | hpv-gt18-45aptimapanther,apututkimustulostensiirtoon |  | 100% | name | 149 | 100 |  |  |  |  |  |
| 266 | hpvaptimapanther,apututkimustulostensiirtoon |  | 100% | name | 413 | 100 |  |  |  |  |  |
| 267 | humanimmunodeficiencyvirus,antigeenijavasta- |  | 100% | name | 192 | 100 |  |  |  |  | HIV 1+2 Ab and p24 Ag [Presence] in Serum or Plasma |
| 268 | humanimmunodeficiencyvirus,antigeenijavasta-aineet,yhd |  | 100% | name | 260 | 100 |  |  |  |  | HIV 1+2 Ab and p24 Ag [Presence] in Serum or Plasma |
| 269 | huume-jalääkeainetutkimus,laaja,varmistus |  | 100% | name | 448 | 100 |  |  |  |  | Drugs of abuse confirmation panel - Urine |
| 270 | huumeseulonta,kvalitatiivinen,virtsasta␤ |  | 100% | name | 140 | 100 |  |  |  |  | Drugs of abuse screen panel - Urine |
| 271 | kalium,hoitoyksikönvieritesti,veri | mmol/l | 36% | name+unit+values | 166 | 0 | [3.34, 3.65, 3.8, 3.9, 4, 4.19, 4.3, 4.42, 4.6] |  |  |  | Potassium [Moles/volume] in Blood |
| 272 | kalium,hoitoyksikönvieritesti,veri |  | 64% | name+values | 290 | 0 | [3.4, 3.69, 3.8, 3.9, 4.06, 4.2, 4.4, 4.56, 5] |  |  |  | Potassium [Moles/volume] in Blood |
| 273 | kreatiniini,hoitoyksikönvieritesti,veri | mmol/l | 100% | name+unit+values | 163 | 0 | [61.44, 68.7, 74.81, 78.74, 84.67, 94.44, 102.62, 112.17, 146.53] |  |  |  | Creatinine [Moles/volume] in Blood |
| 274 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 99% | name+unit+values | 874 | 0 | [2.21, 3.1, 4.22, 5.54, 6.81, 8.47, 10.55, 13.18, 17.82] |  |  |  | Creatinine [Moles/volume] in Urine |
| 275 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) |  | 1% | name | 6 | 66.67 |  |  |  |  | Creatinine [Moles/volume] in Urine |
| 276 | laajahuumeseulonta,varmistustasoinen,virtsasta |  | 100% | name | 944 | 100 |  |  |  |  | Drugs of abuse confirmation panel - Urine |
| 277 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 96% | name+unit+values | 203 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.1, 0.4] |  |  |  | Casts [#/volume] in Urine by Automated count |
| 278 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. |  | 4% | name | 9 | 100 |  |  |  |  | Casts [#/volume] in Urine by Automated count |
| 279 | lisävastauslaskutuskuitatullenäytteelle |  | 100% | name | 214 | 100 |  |  |  |  |  |
| 280 | luuntiheysmittaus,2kohdetta(nk6sa),lausuttuna |  | 100% | name | 145 | 100 |  |  |  |  | Bone density study panel |
| 281 | marevan-hoidonseur.tatesti,hoitoyksikkötekeesormenpäänäyte |  | 100% | name | 168 | 0 |  |  |  |  | INR [Ratio] in Capillary blood |
| 282 | moniresistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 206 | 100 |  |  |  |  | Bacteria.Gram negative.multidrug resistant identified in Specimen by Culture |
| 283 | natrium,hoitoyksikönvieritesti,veri | mmol/l | 36% | name+unit+values | 163 | 0 | [133.07, 135, 136.54, 138, 139, 139.55, 140, 141, 142] |  |  |  | Sodium [Moles/volume] in Blood |
| 284 | natrium,hoitoyksikönvieritesti,veri |  | 64% | name+values | 292 | 0 | [131.17, 133.92, 135.97, 137.29, 138.69, 139.5, 140, 141, 142] |  |  |  | Sodium [Moles/volume] in Blood |
| 285 | natriureettinenpeptidi,b-tyypinn-terminaalinenpropeptidi,plasmasta | ng/l | 100% | name+unit+values | 159 | 0 | [27.45, 51.56, 106.33, 265.57, 634.4, 1351.3, 2903.04, 5577.84, 11032.2] |  |  |  | Natriuretic peptide B.N-terminal pro [Mass/volume] in Plasma |
| 286 | nk-solujenosuus(määritettynäcd3-/cd16+/cd56+-soluina) | % | 100% | name+unit+values | 665 | 0 | [4, 7.07, 9.79, 12.53, 14.84, 17.1, 21.25, 26.92, 36.91] |  |  |  | NK cells/Lymphocytes [# Ratio] in Blood |
| 287 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. | mosm/kgh2o | 96% | name+unit+values | 203 | 0 | [331.17, 377.3, 431.74, 500.49, 539.14, 595.38, 634.62, 686.05, 750.53] |  |  |  | Osmolality [Osmolality] in Urine |
| 288 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. |  | 4% | name | 9 | 100 |  |  |  |  | Osmolality [Osmolality] in Urine |
| 289 | p-natriureett.peptidin-termin.propept.vieritl | ng/l | 86% | name+unit+values | 118 | 0 | [140.45, 226.81, 316.84, 708.93, 1117.67, 1691.6, 2121.04, 3414.6, 4866.2] |  | Plasma |  | Natriuretic peptide B.N-terminal pro [Mass/volume] in Plasma |
| 290 | p-natriureett.peptidin-termin.propept.vieritl |  | 14% | name | 20 | 100 |  |  | Plasma |  | Natriuretic peptide B.N-terminal pro [Mass/volume] in Plasma |
| 291 | p-natriureettinenpeptidi,b-tyypinn-terminaalin | ng/l | 97% | name+unit+values | 4682 | 0 | [86.24, 151.65, 238.65, 387.07, 653.89, 1066.35, 1771.72, 3084.52, 6142.85] |  | Plasma |  | Natriuretic peptide B.N-terminal pro [Mass/volume] in Plasma |
| 292 | p-natriureettinenpeptidi,b-tyypinn-terminaalin |  | 3% | name | 149 | 100 |  |  | Plasma |  | Natriuretic peptide B.N-terminal pro [Mass/volume] in Plasma |
| 293 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi | ng/l | 93% | name+unit+values | 1366 | 0 | [106.15, 192.31, 311.64, 535.82, 915.89, 1456.12, 2310.73, 3820.95, 6983] |  | Plasma |  | Natriuretic peptide B.N-terminal pro [Mass/volume] in Plasma |
| 294 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi |  | 7% | name | 107 | 100 |  |  | Plasma |  | Natriuretic peptide B.N-terminal pro [Mass/volume] in Plasma |
| 295 | parasiitit,ulosteesta(alkueläintenkystat,madot,madonmunat,toukat) |  | 100% | name | 120 | 100 |  |  |  |  | Ova and Parasites identified in Stool by Microscopy |
| 296 | pienikudoskoepala,enintään1-3samankokonaisuudennäytettä |  | 100% | name | 234 | 100 |  |  |  |  | Tissue examination.gross and microscopic [Interpretation] in Tissue |
| 297 | pika:m10inabnhp,rsvnhp,cv19nhp,yhdistelmävierit. |  | 100% | name | 267 | 100 |  |  |  |  | Influenza virus A+B and Respiratory syncytial virus and SARS-CoV-2 RNA panel - Respiratory specimen by NAA with probe detection |
| 298 | pt-diffuusiokapasiteetti,single-breath-menetelmä,tavallinenperusmittaus |  | 100% | name | 3577 | 100 |  |  | Patient |  | Carbon monoxide diffusing capacity [Volume/time/Pressure] in Exhaled gas |
| 299 | pt-lausuntoneurofysiologisestatutkimuksesta,hälytysindikaatiot |  | 100% | name | 113 | 100 |  |  | Patient |  |  |
| 300 | pt-luuntiheysmittaus,2kohdetta,ilmanlausuntoa |  | 100% | name | 120 | 100 |  |  | Patient |  | Bone density 2 sites [Mass/area] by DXA |
| 301 | pt-sydämenkattavarakenteellinenjatoiminnallinenuä(fm1ee) |  | 100% | name | 177 | 100 |  |  | Patient |  | Echocardiogram.comprehensive panel |
| 302 | pt-uloshengityksenhuippuvirtaus,vuorokausivaihtelunseuranta |  | 100% | name | 474 | 100 |  |  | Patient |  | Peak expiratory flow rate diurnal variation |
| 303 | pt-yöpolygrafia,ambulatorinen,hyvinsuppeaunirekisteröintikotona |  | 100% | name | 542 | 100 |  |  | Patient |  | Sleep study.home limited panel |
| 304 | pt-yöpolygrafia,ambulatorinen,jalkaliikerekisteröinnein |  | 100% | name | 102 | 100 |  |  | Patient |  | Sleep study.home panel |
| 305 | pu-aerobinenjaanaerobinenbakteerityypitysjaan |  | 100% | name | 147 | 100 |  |  | Pus |  | Bacteria identified in Pus by Aerobic and Anaerobic culture |
| 306 | resistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 320 | 100 |  |  |  |  | Bacteria.Gram negative.resistant identified in Specimen by Culture |
| 307 | retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 99% | name+unit+values | 525 | 0 | [26.59, 29.88, 31.77, 32.87, 33.87, 34, 35, 35.95, 37] |  |  |  | Reticulocyte hemoglobin content [Entitic mass] in Blood |
| 308 | retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 1% | name | 5 | 100 |  |  |  |  | Reticulocyte hemoglobin content [Entitic mass] in Blood |
| 309 | s-humanimmunodeficiencyvirus,antigeenijavast |  | 100% | name | 1221 | 100 |  |  | Serum |  | HIV 1+2 Ab and p24 Ag [Presence] in Serum |
| 310 | sikiöperäisendna:ntutkimusäidinverinäytteestä |  | 100% | name | 104 | 100 |  |  |  |  | Fetal aneuploidy screen panel - Maternal blood by DNA analysis |
| 311 | staphylococcusaureus,metisilliiniresistenssiviljely␤ |  | 100% | name | 134 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Specimen by Organism specific culture |
| 312 | staphylococcusaureus,metisilliiniresistentti(mrsa),viljely |  | 100% | name | 627 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Specimen by Organism specific culture |
| 313 | t-auttajasolujenosuus(määritettynäcd3+cd4+soluina) | % | 100% | name+unit+values | 665 | 0 | [12.24, 17.15, 20.76, 25.01, 30.99, 37.63, 47.04, 52.34, 60.07] |  | Thrombocyte |  | T-helper cells/Lymphocytes [# Ratio] in Blood |
| 314 | t-estäjäsolujenosuus(määritettynäcd3+cd8+soluina) | % | 100% | name+unit+values | 665 | 0 | [14.45, 20.35, 24.03, 27.06, 32.04, 37.14, 44.33, 52.92, 66.66] |  | Thrombocyte |  | T-suppressor cells/Lymphocytes [# Ratio] in Blood |
| 315 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella | ng/l | 7% | name+unit | 7 | 0 |  |  |  |  | Troponin T [Mass/volume] in Blood |
| 316 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella |  | 93% | name | 97 | 93.81 |  |  |  |  | Troponin T [Mass/volume] in Blood |
| 317 | ts-histologinentutkimus,1-3kudosnäytettä |  | 100% | name | 160 | 100 |  |  | Tissue |  |  |
| 318 | ts-histologinentutkimus,1-3näytettä |  | 100% | name | 945 | 100 |  |  | Tissue |  | Tissue examination.gross and microscopic [Interpretation] in Tissue |
| 319 | työpaikanhuumeseulontajavarmistus,4yhdistettä |  | 100% | name | 469 | 100 |  |  |  |  | Workplace drugs of abuse screen and confirmation 4 panel - Urine |
| 320 | työpaikanhuumeseulontajavarmistus,7yhdistettä |  | 100% | name | 312 | 100 |  |  |  |  | Workplace drugs of abuse screen and confirmation 7 panel - Urine |
| 321 | täydellinennimi:pt-näytteenotto0maksu,kierronulkopuolisetnäytteet |  | 100% | name | 1481 | 100 |  |  |  |  |  |
| 322 | täydellinenverenkuva,sis.perusverenkuvanjaleukosyyttienerittelylaskennan␤ |  | 100% | name | 9742 | 100 |  |  |  |  | CBC with Differential panel - Blood |
| 323 | u-amfetamiinijametamfetamiini,enantiomeerienerittely |  | 100% | name | 120 | 100 |  |  | Urine |  | Amphetamine and Methamphetamine enantiomers panel - Urine |
| 324 | u-asetoniaineet,kval,vieritestihoitoyksikössä |  | 100% | name | 421 | 100 |  |  | Urine |  | Ketones [Presence] in Urine by Test strip |
| 325 | u-erytrosyytit,kval,vieritestihoitoyksikössä |  | 100% | name | 413 | 100 |  |  | Urine |  | Hemoglobin [Presence] in Urine by Test strip |
| 326 | u-glukoosi,kvalvieritestihoitoyksikössä |  | 100% | name | 423 | 100 |  |  | Urine |  | Glucose [Presence] in Urine by Test strip |
| 327 | u-happamuusaste,vieritestihoitoyksikössä |  | 100% | name+values | 400 | 0.25 | [5.5, 5.5, 5.5, 5.9, 6, 6, 6.5, 7, 7] |  | Urine |  | pH [Logarithmic Content] in Urine by Test strip |
| 328 | u-huume-jalääkeainetutkimus,laaja,varmistus |  | 100% | name | 175 | 100 |  |  | Urine |  | Drugs of abuse confirmation panel - Urine |
| 329 | u-huume-jalääkeainetutkimus,semikvantitatiivinen,virtsa␤sta |  | 100% | name | 121 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 330 | u-huumeseulonta,laaja(kvalitatiivinenlc-tof-ms) |  | 100% | name | 144 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 331 | u-kemiallinenseulonta,vieritestihoitoyksikössä |  | 100% | name | 104 | 100 |  |  | Urine |  | Urinalysis macro (dipstick) panel - Urine |
| 332 | u-kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 100% | name+unit+values | 398 | 0 | [2.13, 2.88, 3.69, 4.73, 6, 7.61, 9.67, 12.44, 16.61] |  | Urine |  | Creatinine [Moles/volume] in Urine |
| 333 | u-laajahuume-jalääkeainetutkimus,semikvantitatiivinen |  | 100% | name | 421 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 334 | u-leukosyytit,kval,vieritestihoitoyksikössä |  | 100% | name | 429 | 100 |  |  | Urine |  | Leukocyte esterase [Presence] in Urine by Test strip |
| 335 | u-nitriitti,kval,vieritestihoitoyksikössä |  | 100% | name | 421 | 100 |  |  | Urine |  | Nitrite [Presence] in Urine by Test strip |
| 336 | u-proteiini,kval,vieritestihoitoyksikössä |  | 100% | name | 425 | 100 |  |  | Urine |  | Protein [Presence] in Urine by Test strip |
| 337 | vieritestilaite(epoc)verikaasuanalyysilaskimonäytteestä |  | 100% | name | 162 | 100 |  |  |  |  | Blood gas panel - Venous blood |
| 338 | yersinia(lajitenterocolitica,pseudotuberculosis,pestis)nho,ulosteesta␤ |  | 100% | name | 484 | 100 |  |  |  |  | Yersinia enterocolitica+pseudotuberculosis+pestis DNA panel - Stool by NAA with probe detection |

