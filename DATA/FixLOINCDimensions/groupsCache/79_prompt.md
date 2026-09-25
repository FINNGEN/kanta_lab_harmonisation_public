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
Here is group 79.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 1092182 | Bacteria [Presence] in Urine sediment by Microscopy | 1.000 |  |
| 3009508 | Creatinine [Moles/volume] in Urine | 1.000 | 161 |
| 3012516 | Albumin [Mass/volume] in Urine | 1.000 |  |
| 3015736 | pH of Urine | 1.000 | 612 |
| 3025987 | Albumin [Presence] in Urine | 1.000 |  |
| 3034485 | Albumin/Creatinine [Mass Ratio] in Urine | 1.000 |  |
| 3051409 | Alpha-1-Microglobulin/Creatinine [Mass Ratio] in Urine | 1.000 |  |
| 3004562 | Bacteria [Presence] in Urine sediment by Light microscopy | 0.969 | 514 |
| 1091601 | Epithelial cells [#/area] in Urine sediment | 0.968 |  |
| 1988702 | Alpha-1-Microglobulin/Creatinine [Mass Ratio] in 24 hour Urine | 0.965 |  |
| 1092445 | Erythrocytes [#/area] in Urine sediment | 0.961 |  |
| 3002481 | Calcium/Creatinine [Mass Ratio] in Urine | 0.959 |  |
| 1092217 | Leukocytes [#/area] in Urine sediment | 0.959 |  |
| 3000819 | Albumin/Creatinine [Mass Ratio] in 24 hour Urine | 0.958 |  |
| 3020682 | Albumin/Creatinine [Ratio] in Urine | 0.957 |  |
| 3038224 | Microscopic observation [Identifier] in Urine sediment by Light microscopy | 0.955 | 339 |
| 3027035 | Albumin [Mass/time] in 24 hour Urine | 0.953 |  |
| 3002812 | Albumin/Creatinine [Molar ratio] in Urine | 0.948 |  |
| 3017754 | Calcium/Creatinine [Molar ratio] in Urine | 0.941 |  |
| 43055190 | Macrophages [#/area] in Urine sediment by Microscopy high power field | 0.932 |  |
| 3050449 | Albumin [Mass/time] in Urine collected for unspecified duration | 0.932 |  |
| 3047166 | Epithelial cells [#/area] in Urine sediment by Automated count | 0.931 |  |
| 1092008 | Casts [#/area] in Urine sediment | 0.930 |  |
| 3051014 | Leukocytes [#/area] in Urine sediment by Automated count | 0.926 |  |
| 3008960 | Albumin [Mass/volume] in 24 hour Urine | 0.923 |  |
| 649500 | Albumin/Creatinine [Measurement] in Urine | 0.923 |  |
| 3010189 | Epithelial cells [#/area] in Urine sediment by Microscopy high power field | 0.921 | 166 |
| 3001582 | Protein/Creatinine [Mass Ratio] in Urine | 0.920 | 509 |
| 46235897 | Albumin/Creatinine [Ratio] in 24 hour Urine | 0.919 |  |
| 3035583 | Leukocytes [#/area] in Urine sediment by Microscopy high power field | 0.919 | 79 |
| 3048402 | Erythrocytes [#/area] in Urine sediment by Automated count | 0.919 |  |
| 3035124 | Erythrocytes [#/area] in Urine sediment by Microscopy high power field | 0.914 | 100 |
| 3043507 | Leukocytes [#/area] in Urine sediment by Microscopy low power field | 0.913 |  |
| 3035982 | Calcium/Creatinine [Mass Ratio] in 24 hour Urine | 0.911 |  |
| 3043366 | Epithelial cells [#/area] in Urine sediment by Microscopy low power field | 0.911 |  |
| 3013539 | Creatinine [Moles/volume] in 24 hour Urine | 0.908 | 1978 |
| 40762887 | Creatinine [Moles/volume] in Blood | 0.907 | 283 |
| 649233 | Calcium/Creatinine [Measurement] in Urine | 0.905 |  |
| 3001802 | Microalbumin/Creatinine [Mass Ratio] in Urine | 0.903 | 212 |
| 3030451 | Calcium/Creatinine [Molar ratio] in 24 hour Urine | 0.900 |  |
| 645998 | Albumin [Measurement] in Urine | 0.898 |  |
| 3029937 | Albumin [Presence] in Urine by Test strip | 0.896 |  |
| 1092204 | Epithelial cells.squamous [#/area] in Urine sediment | 0.895 |  |
| 3026726 | Creatinine [Moles/volume] in Specimen | 0.893 |  |
| 3023147 | Calcium/Creatinine [Mass Ratio] in 2 hour Urine | 0.893 |  |
| 1091831 | Leukocytes [#/area] in Urine by Computer assisted method | 0.891 |  |
| 3033268 | Albumin [Mass/time] in Urine collected for unspecified duration --supine | 0.891 |  |
| 3000837 | Albumin/Creatinine [Mass Ratio] in Urine by Test strip | 0.891 |  |
| 3045571 | Creatinine/Calcium [Mass Ratio] in Urine | 0.890 |  |
| 3029162 | Epithelial cells.squamous [#/area] in Urine sediment by Automated count | 0.886 |  |
| 3052318 | Alpha-1-Microglobulin [Mass/volume] in Urine | 0.886 |  |
| 1092420 | Epithelial cells.non-squamous [#/area] in Urine sediment | 0.886 |  |
| 3040006 | Creatinine [Moles/volume] in 12 hour Urine | 0.885 |  |
| 3001008 | Epithelial cells.squamous [#/area] in Urine sediment by Microscopy high power field | 0.885 | 148 |
| 3037459 | Creatinine [Moles/volume] in Body fluid | 0.885 | 1234 |
| 3017250 | Creatinine [Mass/volume] in Urine | 0.884 |  |
| 3037791 | Protein/Creatinine [Mass Ratio] in 24 hour Urine | 0.884 |  |
| 3046055 | Albumin [Presence] in Body fluid | 0.884 |  |
| 3030015 | Alpha-2-Macroglobulin/Creatinine [Mass Ratio] in Urine | 0.882 |  |
| 1091888 | Epithelial cells.renal [#/area] in Urine sediment | 0.882 |  |
| 3015023 | Epithelial cells.renal [#/area] in Urine sediment by Microscopy high power field | 0.881 | 605 |
| 36304419 | Bacteria [Presence] in Urine | 0.881 |  |
| 3008392 | Creatinine/Protein [Mass Ratio] in Urine | 0.880 |  |
| 3040510 | Creatinine [Moles/time] in 1 hour Urine | 0.879 |  |
| 3038830 | Creatinine [Moles/volume] in Urine --baseline | 0.878 |  |
| 40761537 | Casts [Type] in Urine sediment by Light microscopy | 0.878 |  |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 0.876 | 1 |
| 40763957 | Albumin [Mass/volume] in Urine from Fetus | 0.876 |  |
| 1092248 | Bacteria [#/area] in Urine sediment by Microscopy | 0.870 |  |
| 3043798 | Albumin [Presence] in Serum or Plasma | 0.869 |  |
| 36032273 | Leukocytes [#/area] in Prostatic fluid by Light microscopy | 0.867 |  |
| 1092301 | Erythrocytes [#/volume] in Urine sediment | 0.867 |  |
| 36031484 | Leukocytes [#/area] in Body fluid by Light microscopy | 0.865 |  |
| 3040554 | Leukocytes [#/area] in Urethra by Wet preparation | 0.864 |  |
| 3043771 | Microalbumin [Mass/time] in 12 hour Urine | 0.864 |  |
| 3045874 | Casts [#/area] in Urine sediment by Automated count | 0.864 |  |
| 3008512 | Albumin [Mass/volume] in Urine by Electrophoresis | 0.864 | 1035 |
| 3045462 | Protein/Creatinine [Ratio] in Urine | 0.864 |  |
| 3002000 | Albumin [Mass/volume] in Specimen | 0.863 |  |
| 3022826 | Microalbumin/Creatinine [Ratio] in Urine | 0.863 |  |
| 3009292 | Casts [#/area] in Urine sediment by Microscopy high power field | 0.862 | 864 |
| 1091058 | Erythrocyte [#/area] in Urine by Computer assisted method | 0.861 |  |
| 3002827 | Microalbumin/Creatinine [Mass Ratio] in 24 hour Urine | 0.861 | 1979 |
| 3035004 | Microscopic observation [Identifier] in Urine by Cyto stain | 0.860 | 1251 |
| 3005658 | Casts [#/area] in Urine sediment by Microscopy low power field | 0.860 | 294 |
| 3018097 | Albumin [Mass/time] in 24 hour Urine by Electrophoresis | 0.858 |  |
| 1988513 | Alpha-1-Microglobulin [Mass/volume] in 24 hour Urine | 0.857 |  |
| 40771492 | Microscopic observation [Identifier] in Urine by KOH preparation | 0.857 |  |
| 3018095 | Leukocytes [#/volume] in Urine | 0.855 | 201 |
| 1989137 | Erythrocytes.non-dysmorphic [#/area] in Urine sediment by Computer assisted method | 0.855 |  |
| 46235212 | Alpha-1-acid glycoprotein/Creatinine [Mass Ratio] in Urine | 0.855 |  |
| 3000955 | Protein/Creatinine [Mass Ratio] in Serum or Plasma | 0.854 |  |
| 3040034 | Microscopic observation [Identifier] in Urine by Wright stain | 0.854 |  |
| 1989084 | Calcium/Creatinine [Mass Ratio] in Urine from Fetus | 0.853 |  |
| 3052615 | Alpha-1-Microglobulin [Mass/time] in 24 hour Urine | 0.852 |  |
| 3005489 | Leukocytes [#/volume] in Urine by Manual count | 0.851 |  |
| 40763732 | Protein/Creatinine [Mass Ratio] in 12 hour Urine | 0.850 |  |
| 3001494 | Erythrocytes [#/volume] in Urine sediment by Microscopy high power field | 0.850 | 155 |
| 3039522 | Prealbumin [Mass/volume] in Urine | 0.848 |  |
| 3043209 | Microalbumin/Creatinine [Mass Ratio] in 12 hour Urine | 0.847 |  |
| 40757477 | Albumin [Mass/volume] in Stool | 0.846 |  |
| 3004068 | Alpha aminoadipate/Creatinine [Mass Ratio] in Urine | 0.844 |  |
| 646324 | Alpha-1-Microglobulin [Measurement] in Urine | 0.843 |  |
| 3003291 | Casts [Presence] in Urine sediment by Light microscopy | 0.841 |  |
| 46237005 | Alpha-1-Microglobulin [Moles/volume] in Urine | 0.841 |  |
| 3038404 | Protein/Creatinine [Ratio] in 24 hour Urine | 0.840 |  |
| 3038276 | Urea/Creatinine [Ratio] in Urine | 0.840 |  |
| 36031377 | Macrophages [#/area] in Prostatic fluid by Light microscopy | 0.839 |  |
| 36032130 | Erythrocytes [#/area] in Body fluid by Light microscopy | 0.839 |  |
| 36031764 | Microscopic observation [Identifier] in Body fluid by Light microscopy | 0.838 |  |
| 3029482 | Bacterial casts [Presence] in Urine sediment by Light microscopy | 0.837 |  |
| 40760483 | Microalbumin [Mass/volume] in 12 hour Urine | 0.837 |  |
| 46236875 | Albumin [Mass/volume] by Electrophoresis in Urine collected for unspecified duration | 0.837 |  |
| 3043518 | Potassium/Creatinine [Ratio] in Urine | 0.836 |  |
| 3024850 | Microscopic observation [Identifier] in Urine by Acid fast stain | 0.835 |  |
| 3003745 | Microscopic observation [Identifier] in Urine by Gram stain | 0.834 |  |
| 3036634 | Albumin [Presence] in 24 hour Urine by Electrophoresis | 0.833 |  |
| 3004261 | Microscopic observation [Identifier] in Urine by Dark field examination | 0.833 |  |
| 3022621 | pH of Urine by Test strip | 0.833 | 59 |
| 648891 | Bacteria [Measurement] in Urine sediment | 0.832 |  |
| 3002582 | Erythrocytes [#/volume] in Urine | 0.832 |  |
| 3046030 | Erythrocytes [Presence] in Urine sediment by Light microscopy | 0.831 |  |
| 3033812 | Protein [Mass/time] in 12 hour Urine | 0.829 |  |
| 3003326 | Creatine/Creatinine [Mass Ratio] in Urine | 0.828 |  |
| 646827 | Protein/Creatinine [Measurement] in Urine | 0.827 |  |
| 3040509 | Prealbumin [Mass/time] in 24 hour Urine | 0.826 |  |
| 1091309 | Bacteria [#/area] in Urine sediment | 0.824 |  |
| 1091136 | Microscopic observation [Identifier] in Specimen | 0.820 |  |
| 3025472 | Microscopic observation [Identifier] in Body fluid by Wet preparation | 0.817 |  |
| 1617497 | Urea/Creatinine [Mass Ratio] in Urine | 0.817 |  |
| 1469687 | pH of Urine by pH-meter | 0.817 |  |
| 3021344 | Bacteria [Presence] in Semen by Light microscopy | 0.816 |  |
| 36303515 | Broad casts [#/area] in Urine sediment | 0.813 |  |
| 3032172 | Bacteria [Presence] in Urine by Automated | 0.805 |  |
| 3040042 | pH of 4 hour Urine | 0.804 |  |
| 43054974 | Bacteria [Presence] in Prostatic fluid by Light microscopy | 0.802 |  |
| 3005577 | Microalbumin [Mass/time] in 24 hour Urine | 0.800 | 1294 |
| 3043179 | Microalbumin [Mass/time] in 4 hour Urine | 0.799 |  |
| 3000600 | Renal tubular casts [#/area] in Urine by Light microscopy | 0.798 |  |
| 3024291 | Alpha 1 globulin [Presence] in Urine | 0.796 |  |
| 3029305 | pH of Urine by Automated test strip | 0.796 |  |
| 3039874 | Casts type not specified [#/area] in Urine by Computer assisted method | 0.796 |  |
| 3043749 | Fine Granular Casts [#/area] in Urine sediment by Microscopy high power field | 0.791 |  |
| 3030511 | Albumin [Mass/volume] in 24 hour Urine by Electrophoresis | 0.789 |  |
| 3000745 | Histiocytes [#/area] in Urine sediment by Microscopy high power field | 0.788 |  |
| 40761539 | Cells [Type] in Urine sediment by Light microscopy | 0.786 |  |
| 3015501 | pH of 24 hour Urine | 0.786 |  |
| 40761501 | Specimen pH acceptable of Urine | 0.780 |  |
| 1092035 | Epithelial cells.squamous [#/area] in Urine by Computer assisted method | 0.776 |  |
| 3040007 | pH of 2 hour Urine | 0.775 |  |
| 3020322 | Bladder cells [#/area] in Urine sediment by Microscopy high power field | 0.769 |  |
| 3031015 | pH of 24 hour Urine by Test strip | 0.769 |  |
| 1091733 | Crystals [#/area] in Urine sediment | 0.769 |  |
| 1091765 | Leukocyte clumps [#/area] in Urine sediment | 0.750 |  |
| 3050658 | Leukocyte clumps [#/area] in Urine sediment by Microscopy high power field | 0.750 | 1021 |
| 3018672 | pH of Body fluid | 0.716 | 953 |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1161 | cu-alb-mi | ug/min | 80% | name+unit+values | 7258 | 0 | [2, 3.03, 4.27, 6.2, 9.73, 17, 34.68, 78.84, 221.36] | cU-Albumiini, mikroalbuminuria | Collected urine | Micro | Albumin [Mass/time] in Collected Urine |
| 1162 | cu-alb-mi |  | 20% | name+values | 1830 | 100 | [2, 3.76, 5.36, 7.63, 12.69, 25, 48.21, 105.09, 287.3] | cU-Albumiini, mikroalbuminuria | Collected urine | Micro | Albumin [Mass/time] in Collected Urine |
| 1163 | nu-alb-mi | mg/12h | 4% | name+unit | 12 | 0 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin [Mass/time] in 12 hour Urine |
| 1164 | nu-alb-mi | ug/min | 48% | name+unit+values | 155 | 0 | [5, 8.88, 19.76, 34.34, 70.38, 107.14, 173.45, 320, 537.6] | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin [Mass/time] in Timed Urine |
| 1165 | nu-alb-mi |  | 48% | name | 157 | 68.15 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin [Mass/time] in Timed Urine |
| 1166 | nu-albkre | mg/mmol | 17% | name+unit+values | 438 | 0 | [0.3, 0.49, 0.65, 0.9, 1.28, 2, 4.09, 8.45, 23.14] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Timed Urine |
| 1167 | nu-albkre |  | 83% | name+values | 2191 | 62.12 | [0.39, 0.5, 0.69, 0.87, 1.2, 1.82, 2.88, 6.31, 19.04] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Timed Urine |
| 1168 | nu-albkrea | mg/mmol | 44% | name+unit+values | 20929 | 0 | [0.33, 0.49, 0.66, 0.9, 1.32, 2.09, 3.79, 8.38, 27.64] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Timed Urine |
| 1169 | nu-albkrea |  | 56% | name+values | 26197 | 100 | [0.21, 0.36, 0.51, 0.7, 1.05, 1.62, 2.84, 6.09, 18.42] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Timed Urine |
| 1170 | u-a1mikre |  | 100% | name+values | 113 | 12.39 | [1, 2.43, 3.5, 6.91, 9.03, 11.18, 14.78, 18.06, 35.1] |  | Urine |  | Alpha-1-Microglobulin/Creatinine [Mass Ratio] in Urine |
| 1171 | u-alb-0 |  | 100% | name | 992 | 100 |  |  | Urine |  | Albumin [Presence] in Urine |
| 1172 | u-alb-lb | mg/l | 58% | name+unit | 70 | 0 |  |  | Urine |  | Albumin [Mass/volume] in Urine |
| 1173 | u-alb-lb |  | 42% | name | 50 | 98 |  |  | Urine |  | Albumin [Mass/volume] in Urine |
| 1174 | u-alb-mi | mg/l | 71% | name+unit+values | 7488 | 0 | [3.01, 4.02, 5.51, 7.59, 11.17, 18.74, 35.95, 87.24, 325.25] |  | Urine | Micro | Albumin [Mass/volume] in Urine |
| 1175 | u-alb-mi |  | 29% | name+values | 3031 | 100 | [1.94, 3, 4.21, 6.03, 8.61, 11.71, 20.86, 50.08, 291.2] |  | Urine | Micro | Albumin [Mass/volume] in Urine |
| 1176 | u-alb-o | estimate | 34% | name+unit+values | 161670 | 2.95 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin [Presence] in Urine |
| 1177 | u-alb-o | form | 0% | name+unit+values | 287 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin [Presence] in Urine |
| 1178 | u-alb-o |  | 66% | name+values | 312867 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin [Presence] in Urine |
| 1179 | u-alb/kre | g/mol | 3% | name+unit+values | 142 | 0 | [1.78, 3.02, 3.92, 5.37, 8.28, 16.58, 32.75, 51.54, 140.31] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1180 | u-alb/kre | mg/mmol | 50% | name+unit+values | 2591 | 0 | [0.3, 0.42, 0.6, 0.84, 1.25, 2.07, 3.99, 8.87, 30.32] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1181 | u-alb/kre |  | 48% | name | 2491 | 96.87 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1182 | u-alb/kre,u-alb |  | 100% | name+values | 247 | 39.27 | [6.13, 7.52, 9.27, 12.32, 15.29, 19.26, 37.25, 66.2, 187.73] |  | Urine |  | Albumin [Mass/volume] in Urine |
| 1183 | u-alb/kre,u-alb/krea | mg/mmol | 60% | name+unit+values | 148 | 0 | [0.59, 0.74, 0.99, 1.41, 1.89, 3.03, 5.25, 10.21, 22.45] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1184 | u-alb/kre,u-alb/krea |  | 40% | name | 99 | 96.97 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1185 | u-alb/kre,u-krea |  | 100% | name+values | 247 | 0.81 | [3.67, 4.76, 5.83, 6.76, 7.67, 8.61, 9.82, 10.75, 12.92] |  | Urine |  | Creatinine [Moles/volume] in Urine |
| 1186 | u-alb/krea | g/mol | 3% | name+unit | 49 | 0 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1187 | u-alb/krea | mg/mmol | 51% | name+unit+values | 879 | 0 | [0.29, 0.4, 0.52, 0.73, 1.06, 1.82, 2.87, 5.79, 14.42] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1188 | u-alb/krea |  | 47% | name | 812 | 100 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1189 | u-albkre | g/mol | 0% | name+unit | 10 | 0 |  | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1190 | u-albkre | mg/mmol | 60% | name+unit+values | 294883 | 0.26 | [0.31, 0.5, 0.7, 1.03, 1.68, 3, 6.29, 16.55, 61.66] | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1191 | u-albkre |  | 40% | name+values | 200553 | 100 | [0.3, 0.4, 0.59, 0.81, 1.18, 1.92, 3.44, 7.04, 20.74] | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1192 | u-albkrea | mg/mmol | 40% | name+unit+values | 10590 | 0 | [0.3, 0.44, 0.59, 0.73, 0.97, 1.31, 1.85, 3.03, 9.45] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1193 | u-albkrea | mg/mmol/l | 0% | name+unit | 81 | 0 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1194 | u-albkrea |  | 59% | name+values | 15486 | 73.32 | [0.4, 0.65, 1.06, 1.98, 3.39, 4.96, 7.85, 14.4, 37.26] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1195 | u-alvhu4a |  | 100% | name | 760 | 100 |  |  | Urine |  |  |
| 1196 | u-alvhu5b |  | 100% | name | 912 | 100 |  |  | Urine |  |  |
| 1197 | u-alvhu6a |  | 100% | name | 1273 | 100 |  |  | Urine |  |  |
| 1198 | u-cakre |  | 100% | name | 106 | 48.11 |  |  | Urine |  | Calcium/Creatinine [Ratio] in Urine |
| 1199 | u-happamuus |  | 100% | name+values | 204 | 0.49 | [6.5, 6.5, 7, 7, 7, 7, 7.5, 7.5, 8] |  | Urine |  | pH of Urine |
| 1200 | u-prokre | g/mol | 28% | name+unit+values | 973 | 0.41 | [5.03, 6.97, 8.99, 11.1, 14.55, 19.47, 27.35, 52.28, 161.87] | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein.total/Creatinine [Mass Ratio] in Urine |
| 1201 | u-prokre | mg/mmol | 53% | name+unit+values | 1813 | 0 | [9.66, 12.56, 16.16, 21.33, 30.42, 49.33, 102.26, 292.89, 1027.72] | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein.total/Creatinine [Mass Ratio] in Urine |
| 1202 | u-prokre |  | 19% | name | 646 | 99.85 |  | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein.total/Creatinine [Mass Ratio] in Urine |
| 1203 | u-protkre | mg/mmol | 93% | name+unit | 121 | 0 |  |  | Urine |  | Protein.total/Creatinine [Mass Ratio] in Urine |
| 1204 | u-protkre |  | 7% | name | 9 | 100 |  |  | Urine |  | Protein.total/Creatinine [Mass Ratio] in Urine |
| 1205 | u-sakka,bakt |  | 100% | name | 330 | 99.39 |  |  | Urine |  | Bacteria [Presence] in Urine sediment by Microscopy |
| 1206 | u-sakka,epit |  | 100% | name+values | 1251 | 71.3 | [0, 0, 0, 0, 0, 0, 0.33, 1, 2] |  | Urine |  | Epithelial cells [#/area] in Urine sediment by Microscopy |
| 1207 | u-sakka,eryt | u/field | 91% | name+unit+values | 1247 | 0 | [0, 1, 1, 1, 1, 2, 2.67, 4, 7] |  | Urine |  | Erythrocytes [#/area] in Urine sediment by Microscopy |
| 1208 | u-sakka,eryt |  | 9% | name+values | 121 | 100 | [0, 0, 0, 0, 0.62, 1, 2, 3.04, 7.71] |  | Urine |  | Erythrocytes [#/area] in Urine sediment by Microscopy |
| 1209 | u-sakka,leuk | u/field | 81% | name+unit+values | 1087 | 0 | [0, 0, 0, 0, 0, 1, 1, 2.25, 5] |  | Urine |  | Leukocytes [#/area] in Urine sediment by Microscopy |
| 1210 | u-sakka,leuk |  | 19% | name+values | 261 | 100 | [0, 0, 0, 0, 0, 0.98, 2, 4.88, 11.66] |  | Urine |  | Leukocytes [#/area] in Urine sediment by Microscopy |
| 1211 | u-sakka,lier |  | 100% | name+values | 367 | 5.72 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Casts [#/area] in Urine sediment by Microscopy |
| 1212 | u-sakka,makrof |  | 100% | name+values | 367 | 4.63 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Macrophages [#/area] in Urine sediment by Microscopy |
| 1213 | u-sakka,muuta |  | 100% | name+values | 456 | 25.88 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Microscopic observation [Identifier] in Urine sediment |
| 1214 | u-solut,muut |  | 100% | name | 136 | 88.24 |  |  | Urine |  | Cells.other [#/area] in Urine sediment by Microscopy |

