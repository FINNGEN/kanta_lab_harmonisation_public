[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

**Those guesses exist only to fetch the candidate list. They have already done their job, and they carry no authority over your decision.** The earlier pass was told to write a name whenever the code gave it anything at all to work with, because a near-miss still retrieves the right neighbourhood of concepts while silence retrieves nothing. So a guess may be a careful reading or a shot in the dark, and nothing marks which. Use it as a pointer to where in the vocabulary to look, never as an answer to confirm. **Decide from the row's own `TEST_NAME`, `LongName`, `UNIT` and `value_deciles`.** When the row's evidence and the guess disagree, the row wins.

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
- `value_missing_p` — percentage (0-100) of records with no numeric value.
- `value_deciles` — the 9 deciles of observed values, when available.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess, which is what the search was run on. A search query, not a hypothesis you owe any deference to: it was written under instructions to guess rather than stay silent, so its confidence is not calibrated and a fluent name may rest on very little. When it is a panel name, the earlier pass judged the code to order a bundle rather than report one result — check that against the code yourself.

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
| `name` | neither | **You cannot fix the quantity.** Do not guess one and do not copy a sibling. Choose a concept only when the name alone settles it — a panel, which carries no property at all, or an analyte that has exactly one LOINC form. Otherwise **leave `omop_concept_id` empty**. An honest gap is worth more than a concept resting on nothing. |

**Some units are ratios, not concentrations.** `mmol/mol` is HbA1c IFCC, a substance ratio. `mg/mmol` is an albumin/creatinine ratio. `ml/min/173m2` is eGFR, a rate per body surface area. `%` is ambiguous by nature: it may be a fraction of a cell population, a fraction of a total mass, or activity as a percentage of normal.

**A repeated lowest decile is a detection limit, not a measurement.** When the first deciles are the same round number — `[5, 5, 6.2, 8.3, ...]` — the assay is censored at that floor and everything below was reported as "<5". Read the floor as the assay's sensitivity rather than the population's real low end: a CRP censored at 5 mg/l is an ordinary CRP, while a high-sensitivity assay reads down to about 0.1 mg/l, so that floor argues *against* a high-sensitivity concept.

# How to decide

For each row:

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `value_deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
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
Here is group 129.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 1092182 | Bacteria [Presence] in Urine sediment by Microscopy | 1.000 |  |
| 1092248 | Bacteria [#/area] in Urine sediment by Microscopy | 1.000 |  |
| 3002619 | Bacteria identified in Specimen by Culture | 1.000 | 39 |
| 3008037 | Lactate [Moles/volume] in Venous blood | 1.000 |  |
| 3009015 | Lactate [Moles/volume] in Synovial fluid | 1.000 |  |
| 3009986 | Bacteria identified in Catheter tip by Culture | 1.000 | 946 |
| 3015736 | pH of Urine | 1.000 | 612 |
| 3016914 | Bacteria identified in Cerebral spinal fluid by Culture | 1.000 | 561 |
| 3018405 | Lactate [Moles/volume] in Arterial blood | 1.000 | 1277 |
| 3020410 | Lactate [Moles/volume] in Arterial plasma | 1.000 |  |
| 3023368 | Bacteria identified in Blood by Culture | 1.000 | 131 |
| 3023383 | Lactate [Moles/volume] in Pleural fluid | 1.000 |  |
| 3023419 | Bacteria identified in Sputum by Culture | 1.000 | 1768 |
| 3025941 | Bacteria identified in Stool by Culture | 1.000 | 469 |
| 3026008 | Bacteria identified in Urine by Culture | 1.000 | 93 |
| 3028271 | Lactate [Moles/volume] in Capillary blood | 1.000 |  |
| 3031040 | Bacteria [#/volume] in Urine by Automated count | 1.000 |  |
| 3035999 | Lactate [Moles/volume] in Cerebral spinal fluid | 1.000 |  |
| 3042736 | Bacteria [Presence] in Specimen | 1.000 |  |
| 3043614 | Bacteria identified in Aspirate by Culture | 1.000 |  |
| 3047181 | Lactate [Moles/volume] in Blood | 1.000 | 475 |
| 36304419 | Bacteria [Presence] in Urine | 1.000 |  |
| 40763091 | Bacteria identified in Peritoneal dialysis fluid by Culture | 1.000 |  |
| 1092251 | Bacteria identified in Bronchoalveolar lavage by Culture | 0.992 |  |
| 3005491 | Lactate [Moles/volume] in Plasma venous | 0.970 | 1070 |
| 3004562 | Bacteria [Presence] in Urine sediment by Light microscopy | 0.969 | 514 |
| 3000570 | Elastase.pancreatic [Mass/mass] in Stool | 0.968 |  |
| 1091601 | Epithelial cells [#/area] in Urine sediment | 0.968 |  |
| 3014111 | Lactate [Moles/volume] in Serum or Plasma | 0.965 | 346 |
| 1092445 | Erythrocytes [#/area] in Urine sediment | 0.961 |  |
| 1092217 | Leukocytes [#/area] in Urine sediment | 0.959 |  |
| 1091309 | Bacteria [#/area] in Urine sediment | 0.952 |  |
| 3025099 | Bacteria identified in Sputum by Respiratory culture | 0.945 | 275 |
| 1175982 | Bacteria identified in Peritoneal dialysis fluid by Aerobe culture | 0.934 |  |
| 43055190 | Macrophages [#/area] in Urine sediment by Microscopy high power field | 0.932 |  |
| 3045873 | Bacteria identified in Nasopharynx by Culture | 0.932 |  |
| 3047166 | Epithelial cells [#/area] in Urine sediment by Automated count | 0.931 |  |
| 1092008 | Casts [#/area] in Urine sediment | 0.930 |  |
| 3022948 | Iron [Moles/volume] in Serum or Plasma | 0.929 | 140 |
| 1469672 | Bacteria identified in Pus by Anaerobe culture | 0.929 |  |
| 3008582 | Bacteria identified in Aspirate by Aerobe culture | 0.928 |  |
| 3045360 | Bacteria identified in Bronchoalveolar lavage by Aerobe culture | 0.928 | 1695 |
| 3051014 | Leukocytes [#/area] in Urine sediment by Automated count | 0.926 |  |
| 1176221 | Bacteria identified in Catheter tip by Aerobe culture | 0.926 |  |
| 1175346 | Bacteria identified in Peritoneal dialysis fluid by Anaerobe culture | 0.925 |  |
| 3024461 | Microorganism identified in Specimen by Culture | 0.924 |  |
| 3025037 | Bacteria identified in Peritoneal fluid by Culture | 0.923 |  |
| 1175370 | Bacteria identified in Catheter tip by Anaerobe culture | 0.922 |  |
| 1469525 | Bacteria identified in Pus by Culture | 0.922 |  |
| 3025233 | Bacteria identified in Sputum by Aerobe culture | 0.921 |  |
| 3010189 | Epithelial cells [#/area] in Urine sediment by Microscopy high power field | 0.921 | 166 |
| 42529411 | Gastrointestinal pathogens panel - Stool by Culture | 0.920 |  |
| 3012475 | Bacteria identified in Throat by Culture | 0.919 | 638 |
| 3035583 | Leukocytes [#/area] in Urine sediment by Microscopy high power field | 0.919 | 79 |
| 3048402 | Erythrocytes [#/area] in Urine sediment by Automated count | 0.919 |  |
| 3002106 | Lactate [Mass/volume] in Venous blood | 0.918 |  |
| 3025022 | Lactate [Mass/volume] in Cerebral spinal fluid | 0.917 |  |
| 3009451 | Bacteria identified in 24 hour Urine by Culture | 0.916 |  |
| 3035124 | Erythrocytes [#/area] in Urine sediment by Microscopy high power field | 0.914 | 100 |
| 3023470 | Bacteria # 2 identified in Stool by Culture | 0.913 |  |
| 3043507 | Leukocytes [#/area] in Urine sediment by Microscopy low power field | 0.913 |  |
| 3005949 | Lactate [Moles/volume] in Mixed venous blood | 0.913 |  |
| 3040968 | Lactate [Mass/volume] in Capillary blood | 0.912 |  |
| 40763313 | Bacteria identified in Bone marrow by Culture | 0.912 |  |
| 3028923 | Bacteria [#/area] in Urine sediment by Automated count | 0.911 |  |
| 3035561 | Lactate [Mass/volume] in Arterial blood | 0.911 |  |
| 3043366 | Epithelial cells [#/area] in Urine sediment by Microscopy low power field | 0.911 |  |
| 3034965 | Elastase.pancreatic [Presence] in Stool | 0.910 |  |
| 3033670 | Parathyrin related protein [Moles/volume] in Serum or Plasma | 0.909 |  |
| 44816931 | D-Lactate [Moles/volume] in Cerebral spinal fluid | 0.909 |  |
| 3014398 | Bacteria identified in Bone by Aerobe culture | 0.909 |  |
| 36305419 | Bacteria identified in Cerebral spinal fluid by Aerobe culture | 0.908 |  |
| 3045560 | Bacteria # 2 identified in Specimen by Culture | 0.907 |  |
| 3037534 | Parathyrin related protein [Mass/volume] in Serum or Plasma | 0.902 |  |
| 3034504 | Parathyrin.C-terminal [Moles/volume] in Serum or Plasma | 0.901 |  |
| 3027247 | Bacteria identified in Specimen | 0.899 |  |
| 3003776 | Bacteria # 4 identified in Stool by Culture | 0.899 |  |
| 3024182 | Parathyrin.mid molecule [Moles/volume] in Serum or Plasma | 0.899 |  |
| 3002863 | Parathyrin.mid molecule [Mass/volume] in Serum or Plasma | 0.898 |  |
| 1761482 | Bacteria [#/volume] in Urine by Culture | 0.898 |  |
| 3019479 | Bacteria # 2 identified in Urine by Culture | 0.896 |  |
| 3000521 | Bacteria # 3 identified in Stool by Culture | 0.896 |  |
| 1092204 | Epithelial cells.squamous [#/area] in Urine sediment | 0.895 |  |
| 1091200 | Bacteria [#/volume] in Urine | 0.895 |  |
| 3013867 | Bacteria identified in Specimen by Aerobe culture | 0.895 | 276 |
| 3046647 | Bacteria # 4 identified in Specimen by Culture | 0.895 |  |
| 3004825 | Lactate [Moles/volume] in Body fluid | 0.894 |  |
| 3000067 | Parathyrin.intact [Mass/volume] in Serum or Plasma | 0.894 | 240 |
| 3000455 | Bacteria identified in Stool by Anaerobe culture | 0.894 |  |
| 40762125 | Lactate [Mass/volume] in Blood | 0.893 |  |
| 3014320 | Bacteria identified in Urethra by Culture | 0.893 |  |
| 3002687 | Bacteria # 5 identified in Stool by Culture | 0.893 |  |
| 3025255 | Bacteria [#/area] in Urine sediment by Microscopy high power field | 0.893 | 89 |
| 3023764 | Bacteria identified in Specimen by Respiratory culture | 0.892 |  |
| 3016437 | Bacteria identified in Aspirate by Anaerobe culture | 0.892 |  |
| 3001028 | Bacteria # 6 identified in Stool by Culture | 0.891 |  |
| 1091831 | Leukocytes [#/area] in Urine by Computer assisted method | 0.891 |  |
| 3053320 | Bacteria # 2 identified in Blood by Culture | 0.891 |  |
| 3022036 | Colony count [#/volume] in Urine | 0.891 |  |
| 3043867 | Bacteria # 8 identified in Specimen by Culture | 0.891 |  |
| 3045058 | Bacteria # 3 identified in Specimen by Culture | 0.891 |  |
| 3001693 | Parathyrin.N-terminal [Mass/volume] in Serum or Plasma | 0.890 |  |
| 3024362 | Bacteria identified in Dialysis fluid by Culture | 0.890 | 982 |
| 3010566 | Parathyrin.intact [Moles/volume] in Serum or Plasma | 0.889 | 240 |
| 3008334 | Bacteria identified in Drain by Aerobe culture | 0.888 |  |
| 3044420 | Bacteria # 6 identified in Specimen by Culture | 0.888 |  |
| 3005063 | Parathyrin.C-terminal [Mass/volume] in Serum or Plasma | 0.888 |  |
| 3029162 | Epithelial cells.squamous [#/area] in Urine sediment by Automated count | 0.886 |  |
| 1092420 | Epithelial cells.non-squamous [#/area] in Urine sediment | 0.886 |  |
| 1092049 | Bacteria identified in Bronchial specimen by Culture | 0.885 |  |
| 3003392 | Bacteria # 4 identified in Urine by Culture | 0.885 |  |
| 3001008 | Epithelial cells.squamous [#/area] in Urine sediment by Microscopy high power field | 0.885 | 148 |
| 1091323 | Fungus identified in Catheter tip by Culture | 0.884 |  |
| 46234834 | Bacteria identified in Bone by Anaerobe+Aerobe culture | 0.884 |  |
| 1091888 | Epithelial cells.renal [#/area] in Urine sediment | 0.882 |  |
| 3015023 | Epithelial cells.renal [#/area] in Urine sediment by Microscopy high power field | 0.881 | 605 |
| 1091465 | Bacteria # 2 identified in Catheter tip by Aerobe culture | 0.880 |  |
| 3046484 | Bacteria # 8 identified in Urine by Culture | 0.879 |  |
| 36303545 | Bacteria identified in Cerebral spinal fluid by Anaerobe culture | 0.879 |  |
| 3045335 | Bacteria # 7 identified in Urine by Culture | 0.879 |  |
| 40761537 | Casts [Type] in Urine sediment by Light microscopy | 0.878 |  |
| 21491077 | Lactyl lactate [Moles/volume] in Serum or Plasma | 0.878 |  |
| 3003113 | Bacteria # 5 identified in Urine by Culture | 0.878 |  |
| 3024194 | Bacteria identified in Pleural fluid by Culture | 0.877 |  |
| 3005024 | Bacteria # 3 identified in Urine by Culture | 0.877 |  |
| 3005745 | Bacteria identified in Blood by Aerobe culture | 0.876 |  |
| 3002013 | Bacteria # 6 identified in Urine by Culture | 0.876 |  |
| 1091909 | Bacteria # 2 identified in Catheter tip by Anaerobe culture | 0.875 |  |
| 3040138 | Bacteria identified in Sputum tracheal aspirate by Culture | 0.875 |  |
| 40762097 | Lactate [Moles/volume] in Serum or Plasma --baseline | 0.874 |  |
| 40759053 | Lactate [Moles/volume] in Cord blood | 0.874 |  |
| 3049876 | Bacteria # 3 identified in Blood by Culture | 0.872 |  |
| 3009179 | Lactate [Moles/volume] in Peritoneal fluid | 0.872 |  |
| 3020138 | Lactate [Mass/volume] in Serum or Plasma | 0.870 |  |
| 3000943 | Bacteria # 2 identified in Peritoneal fluid by Culture | 0.870 |  |
| 40762896 | Parathyrin.intact [Mass/volume] in Body fluid | 0.869 |  |
| 46234833 | Bacteria identified in Abscess by Anaerobe+Aerobe culture | 0.868 |  |
| 36032273 | Leukocytes [#/area] in Prostatic fluid by Light microscopy | 0.867 |  |
| 3016528 | Bacteria # 4 identified in Peritoneal fluid by Culture | 0.867 |  |
| 3011797 | Bacteria identified in Abscess by Aerobe culture | 0.867 |  |
| 3012809 | Bacteria # 2 identified in Bone by Aerobe culture | 0.867 |  |
| 1092301 | Erythrocytes [#/volume] in Urine sediment | 0.867 |  |
| 1091623 | Bacteria # 3 identified in Catheter tip by Anaerobe culture | 0.866 |  |
| 1092431 | Bacteria # 3 identified in Catheter tip by Aerobe culture | 0.866 |  |
| 36304569 | Bacteria identified in Bronchoalveolar lavage by Anaerobe culture | 0.866 |  |
| 36031484 | Leukocytes [#/area] in Body fluid by Light microscopy | 0.865 |  |
| 3024040 | Parathyrin [Interpretation] in Serum or Plasma | 0.865 |  |
| 3040554 | Leukocytes [#/area] in Urethra by Wet preparation | 0.864 |  |
| 3045874 | Casts [#/area] in Urine sediment by Automated count | 0.864 |  |
| 3020156 | D-Lactate [Moles/volume] in Serum or Plasma | 0.864 |  |
| 3002400 | Iron [Mass/volume] in Serum or Plasma | 0.863 |  |
| 3044014 | Lactate [Moles/volume] in Urine | 0.863 |  |
| 36303914 | Fungus identified in Bronchoalveolar lavage by Culture | 0.863 |  |
| 3009292 | Casts [#/area] in Urine sediment by Microscopy high power field | 0.862 | 864 |
| 3032172 | Bacteria [Presence] in Urine by Automated | 0.862 |  |
| 3027005 | Bacteria identified in Tissue by Aerobe culture | 0.862 |  |
| 3013301 | Bacteria # 4 identified in Bone by Aerobe culture | 0.862 |  |
| 1091058 | Erythrocyte [#/area] in Urine by Computer assisted method | 0.861 |  |
| 3021618 | Bacteria # 5 identified in Peritoneal fluid by Culture | 0.860 |  |
| 36305689 | Fungus identified in Peritoneal dialysis fluid by Culture | 0.860 |  |
| 3005658 | Casts [#/area] in Urine sediment by Microscopy low power field | 0.860 | 294 |
| 3010799 | Bacteria # 3 identified in Peritoneal fluid by Culture | 0.860 |  |
| 3002996 | Fungus identified in Cerebral spinal fluid by Culture | 0.859 |  |
| 42870564 | Atopobium vaginae DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.859 |  |
| 3000448 | Bacteria # 2 identified in Sputum by Aerobe culture | 0.858 |  |
| 3013146 | Bacteria identified in Wound by Aerobe culture | 0.857 |  |
| 3027326 | Bacteria # 3 identified in Bone by Aerobe culture | 0.857 |  |
| 3018095 | Leukocytes [#/volume] in Urine | 0.855 | 201 |
| 1989137 | Erythrocytes.non-dysmorphic [#/area] in Urine sediment by Computer assisted method | 0.855 |  |
| 3014365 | Bacteria # 6 identified in Bone by Aerobe culture | 0.855 |  |
| 3046695 | Bacteria identified in Nasopharynx by Aerobe culture | 0.854 |  |
| 3010729 | Bacteria # 5 identified in Bone by Aerobe culture | 0.853 |  |
| 3019415 | Bacteria identified in Food by Culture | 0.853 |  |
| 3002611 | Bacteria # 4 identified in Sputum by Aerobe culture | 0.851 |  |
| 3016727 | Bacteria identified in Body fluid by Culture | 0.851 | 1786 |
| 3005489 | Leukocytes [#/volume] in Urine by Manual count | 0.851 |  |
| 3033973 | Parathyrin.intact [Mass/volume] in Serum or Plasma --baseline | 0.851 |  |
| 40770955 | Bacteria identified in Blood product unit by Culture | 0.850 |  |
| 3020072 | Bacteria # 6 identified in Sputum by Aerobe culture | 0.850 |  |
| 3035949 | Bacteria identified in Bone marrow by Aerobe culture | 0.850 | 1425 |
| 3001494 | Erythrocytes [#/volume] in Urine sediment by Microscopy high power field | 0.850 | 155 |
| 3035740 | Bacteria identified in Throat by Aerobe culture | 0.849 | 526 |
| 3001521 | Bacteria # 5 identified in Sputum by Aerobe culture | 0.849 |  |
| 1616938 | Parathyrin.intact [Moles/volume] in Body fluid | 0.847 |  |
| 3000088 | Virus identified in Cerebral spinal fluid by Culture | 0.847 |  |
| 1988560 | Cocci bacteria [#/volume] in Urine sediment by Automated count | 0.846 |  |
| 3006761 | Bacteria identified in Synovial fluid by Culture | 0.846 |  |
| 3044495 | Bacteria identified in Tissue by Culture | 0.846 |  |
| 3052240 | Parathyrin.intact [Moles/volume] in Serum or Plasma --baseline | 0.845 |  |
| 3000796 | Bacteria identified in Pleural fluid by Aerobe culture | 0.845 |  |
| 1989355 | Bacilliform bacteria [#/volume] in Urine sediment by Automated count | 0.843 |  |
| 3006673 | Bacteria identified in Blood by Anaerobe culture | 0.842 |  |
| 3003291 | Casts [Presence] in Urine sediment by Light microscopy | 0.841 |  |
| 42870565 | Bacterial vaginosis associated bacterium 2 DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.841 |  |
| 3046905 | Bacteria [Presence] in Specimen by Wet preparation | 0.840 |  |
| 3040827 | Bacteria identified in Anal by Culture | 0.839 |  |
| 36031377 | Macrophages [#/area] in Prostatic fluid by Light microscopy | 0.839 |  |
| 1175669 | Bacteria identified in Synovial fluid by Aerobe culture | 0.839 |  |
| 36032130 | Erythrocytes [#/area] in Body fluid by Light microscopy | 0.839 |  |
| 1469941 | Gardnerella vaginalis DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.839 |  |
| 1470002 | Bacteria identified in Abscess by Anaerobe culture | 0.839 |  |
| 3029482 | Bacterial casts [Presence] in Urine sediment by Light microscopy | 0.837 |  |
| 3029350 | Yeast [#/volume] in Urine by Automated count | 0.836 |  |
| 3036692 | Chlamydia sp DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.836 |  |
| 3025033 | Iron [Moles/volume] in Body fluid | 0.836 |  |
| 3015532 | Bacteria identified in Bronchial specimen by Aerobe culture | 0.836 |  |
| 46235131 | Bacteria identified in Cerebral spinal fluid by Latex agglutination | 0.835 |  |
| 36031886 | Parathyrin.intact [Moles/volume] in Serum or Plasma by Immunoassay | 0.835 |  |
| 1092021 | Bacteria [#/volume] in Bronchoalveolar lavage by Culture | 0.835 |  |
| 3029151 | Bacteria identified in Bronchial specimen | 0.834 |  |
| 3022621 | pH of Urine by Test strip | 0.833 | 59 |
| 21492393 | Bacteria identified in Implanted device by Culture | 0.833 |  |
| 1259619 | Campylobacter and Salmonella and Shigella and Yersinia sp identified in Stool by Organism specific culture | 0.833 |  |
| 3027969 | Bacteria identified in Wound by Anaerobe culture | 0.832 |  |
| 648891 | Bacteria [Measurement] in Urine sediment | 0.832 |  |
| 3002582 | Erythrocytes [#/volume] in Urine | 0.832 |  |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.832 |  |
| 3046030 | Erythrocytes [Presence] in Urine sediment by Light microscopy | 0.831 |  |
| 1989010 | Bacilliform bacteria [#/area] in Urine sediment by Automated count | 0.829 |  |
| 3000374 | Elastase.pancreatic [Mass/volume] in Serum | 0.828 |  |
| 1175573 | Streptococcus agalactiae DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.827 |  |
| 3031246 | Bacteria identified in Isolate | 0.826 | 1461 |
| 42870561 | Candida albicans DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.825 |  |
| 3024447 | Bacteria identified in Specimen by Anaerobe+Aerobe culture | 0.825 | 1062 |
| 3046574 | Neisseria gonorrhoeae DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.825 | 3000 |
| 43533982 | Bacteria identified in Mouth by Culture | 0.824 |  |
| 3000186 | Fungus identified in Aspirate by Culture | 0.823 |  |
| 645215 | Parathyrin Ab [Measurement] in Serum | 0.823 |  |
| 1091856 | Ureaplasma urealyticum DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.821 |  |
| 43055004 | Virus identified in Nasopharynx by Culture | 0.820 |  |
| 1988077 | Cocci bacteria [#/area] in Urine sediment by Automated count | 0.819 |  |
| 645314 | Parathyrin.intact [Measurement] in Serum or Plasma | 0.818 |  |
| 1092116 | Bacteria DNA [Presence] in Specimen by NAA with probe detection | 0.818 |  |
| 3039448 | Bacteria identified in Bile fluid by Culture | 0.818 |  |
| 40757440 | Lactate/Pyruvate [Molar ratio] in Cerebral spinal fluid | 0.818 |  |
| 1469687 | pH of Urine by pH-meter | 0.817 |  |
| 3021344 | Bacteria [Presence] in Semen by Light microscopy | 0.816 |  |
| 3042936 | Bacteria identified in Isolate by Culture | 0.816 |  |
| 645382 | Bacteria [Measurement] in Urine | 0.816 |  |
| 40765197 | Candida sp DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.815 |  |
| 1092178 | Bacteria [Presence] in Urine by Computer assisted method | 0.815 |  |
| 3006581 | Other Antibiotic [Susceptibility] | 0.814 | 123 |
| 36303515 | Broad casts [#/area] in Urine sediment | 0.813 |  |
| 1092191 | Enteric pathogen panel - Stool by NAA with probe detection | 0.813 |  |
| 3015055 | Bacteria identified in Amniotic fluid by Culture | 0.811 |  |
| 1469731 | Bacteria identified in Penis by Culture | 0.811 |  |
| 3016298 | Mycobacterium sp identified in Cerebral spinal fluid by Organism specific culture | 0.809 |  |
| 3000686 | Virus identified in Throat by Culture | 0.809 |  |
| 43055060 | 4-Hydroxyphenyllactate [Moles/volume] in Cerebral spinal fluid | 0.808 |  |
| 3015093 | Bacteria [Presence] in Genital specimen by Wet preparation | 0.807 |  |
| 3040042 | pH of 4 hour Urine | 0.804 |  |
| 3023143 | Ciprofloxacin [Susceptibility] | 0.804 | 317 |
| 43054974 | Bacteria [Presence] in Prostatic fluid by Light microscopy | 0.802 |  |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.802 |  |
| 645850 | Bacteria identified in Fistula by Culture | 0.802 |  |
| 3012113 | Leucine [Moles/volume] in Cerebral spinal fluid | 0.802 |  |
| 3036266 | Bacteria # 2 identified in Throat by Aerobe culture | 0.801 |  |
| 3019101 | Bacteria # 6 identified in Throat by Aerobe culture | 0.801 |  |
| 1259757 | Campylobacter and Salmonella and Shigella sp identified in Stool by Organism specific culture | 0.800 |  |
| 3032566 | Bacteria [Presence] in Pleural fluid by Light microscopy | 0.800 |  |
| 3043578 | Bacteria # 5 identified in Specimen by Culture | 0.799 |  |
| 3008193 | Fungus identified in Specimen by Fungus stain | 0.798 | 825 |
| 1091634 | Fungus [Presence] in Specimen | 0.798 |  |
| 3000600 | Renal tubular casts [#/area] in Urine by Light microscopy | 0.798 |  |
| 3025185 | Colony count [#] in Urine by Visual count | 0.797 |  |
| 3033386 | Bacteria [Presence] in Cerebral spinal fluid by Light microscopy | 0.797 |  |
| 3029305 | pH of Urine by Automated test strip | 0.796 |  |
| 3039874 | Casts type not specified [#/area] in Urine by Computer assisted method | 0.796 |  |
| 40759052 | Lactate [Moles/volume] in Dialysis fluid | 0.795 |  |
| 645244 | Lactate [Measurement] in Serum or Plasma | 0.795 |  |
| 3046136 | Bacteria # 7 identified in Specimen by Culture | 0.794 |  |
| 3025242 | Penicillin [Susceptibility] | 0.794 | 453 |
| 1469892 | Mycobacterium sp identified in Drain by Organism specific culture | 0.793 |  |
| 3043749 | Fine Granular Casts [#/area] in Urine sediment by Microscopy high power field | 0.791 |  |
| 1259916 | Salmonella and Shigella and Campylobacter and E. coli sp identified in Stool by Organism specific culture | 0.791 |  |
| 3008159 | Colony count [#/volume] in Catheter tip by Culture | 0.790 |  |
| 3040058 | Iron [Moles/volume] in Water | 0.790 |  |
| 1091245 | Enteric bacteria panel - Stool by NAA with probe detection | 0.790 |  |
| 3034838 | Amoxicillin [Susceptibility] | 0.789 |  |
| 3010424 | Ferritin [Moles/volume] in Serum or Plasma | 0.789 |  |
| 3000745 | Histiocytes [#/area] in Urine sediment by Microscopy high power field | 0.788 |  |
| 3009403 | Ampicillin [Susceptibility] | 0.786 | 331 |
| 3015501 | pH of 24 hour Urine | 0.786 |  |
| 3019055 | Sulfamethoxazole [Susceptibility] | 0.786 |  |
| 646689 | Lactate dehydrogenase [Measurement] in Pleural fluid | 0.785 |  |
| 3028269 | Bacteria identified in Vaginal fluid by Aerobe culture | 0.784 | 1225 |
| 645187 | Iron [Measurement] in Serum or Plasma | 0.784 |  |
| 36304920 | Bacteria identified in Synovial fluid by Anaerobe culture | 0.783 |  |
| 36303793 | Bacteria identified in Pleural fluid by Anaerobe culture | 0.783 |  |
| 3005829 | Sulfonamide [Susceptibility] | 0.782 |  |
| 3052662 | Ceruloplasmin [Moles/volume] in Serum or Plasma | 0.782 |  |
| 3002903 | Transferrin [Moles/volume] in Serum or Plasma | 0.781 | 809 |
| 1092057 | Bacteria [#/volume] in Semen by Culture | 0.781 |  |
| 3013641 | Bacteroides fragilis Ag [Presence] in Specimen | 0.780 |  |
| 40761501 | Specimen pH acceptable of Urine | 0.780 |  |
| 3003101 | Alpha 1 antitrypsin [Mass/mass] in Stool | 0.779 |  |
| 3023753 | Tetracycline [Susceptibility] | 0.778 | 393 |
| 3018112 | Azithromycin [Susceptibility] | 0.778 |  |
| 3026402 | Cephalexin [Susceptibility] | 0.777 |  |
| 3009814 | Iron saturation [Molar fraction] in Serum or Plasma | 0.777 | 192 |
| 1092202 | Streptococcus pyogenes [Presence] in Specimen | 0.776 |  |
| 3043701 | Iron [Moles/volume] in Urine | 0.775 |  |
| 3013566 | Clostridioides difficile [Presence] in Stool by Organism specific culture | 0.775 |  |
| 3028855 | Bacteria [Presence] in Body fluid by Light microscopy | 0.775 |  |
| 3040007 | pH of 2 hour Urine | 0.775 |  |
| 1988166 | Bacteria [Presence] in Body fluid by Automated | 0.774 |  |
| 3024572 | Bacteria identified in Sputum by Cystic fibrosis respiratory culture | 0.773 |  |
| 3003703 | Bacteria # 3 identified in Sputum by Aerobe culture | 0.771 |  |
| 3045744 | Candida sp identified in Vaginal fluid by Cyto stain | 0.771 |  |
| 3031015 | pH of 24 hour Urine by Test strip | 0.769 |  |
| 3009693 | Lactate [Mass/volume] in Blood --fasting | 0.768 |  |
| 3042645 | Salmonella and Shigella sp identified in Stool by Organism specific culture | 0.767 | 587 |
| 3020535 | Elastase.pancreatic [Enzymatic activity/volume] in Serum | 0.766 |  |
| 3001886 | Microscopic observation [Identifier] in Cerebral spinal fluid by Gram stain | 0.766 |  |
| 1761772 | Urinary tract pathogens panel - Urine by Culture | 0.766 |  |
| 3027001 | Fungus colony count [#/volume] in Specimen by Culture | 0.765 |  |
| 3023155 | Clostridioides difficile [Presence] in Stool by Aerobe culture | 0.764 |  |
| 3027095 | Bacteria # 2 identified in Blood by Aerobe culture | 0.763 |  |
| 3031354 | Microscopic observation [Identifier] in Cerebral spinal fluid by Cyto stain | 0.763 |  |
| 36659872 | Clostridioides difficile toxin and BI-NAP1-027 strain DNA panel - Stool by NAA with probe detection | 0.763 |  |
| 21492659 | Gastrointestinal pathogens panel - Stool by NAA with probe detection | 0.761 |  |
| 1091706 | Campylobacter and Salmonella and Shigella sp # 3 identified in Stool by Organism specific culture | 0.761 |  |
| 3027759 | Bacteria # 2 identified in Blood by Anaerobe culture | 0.760 |  |
| 3037395 | Elastase.pancreatic Free [Enzymatic activity/volume] in Serum | 0.760 |  |
| 3014990 | Bacteria identified in Specimen by Sterile body fluid culture | 0.759 |  |
| 3014717 | Alpha 1 antitrypsin [Mass/volume] in Stool | 0.758 |  |
| 3032488 | Lactate dehydrogenase in pleural fluid/Lactate dehydrogenase in serum | 0.758 |  |
| 42529407 | Salmonella sp [Presence] in Stool by Culture | 0.758 |  |
| 647644 | Lactate dehydrogenase [Measurement] in Synovial fluid | 0.757 |  |
| 3001667 | Chymotrypsin [Mass/mass] in Stool | 0.756 |  |
| 3022889 | Bacteria # 6 identified in Peritoneal fluid by Culture | 0.756 |  |
| 40767123 | Mycobacterium sp [Presence] in Blood by Organism specific culture | 0.756 |  |
| 1091673 | Campylobacter and Salmonella and Shigella sp # 2 identified in Stool by Organism specific culture | 0.755 |  |
| 3021150 | Lactate [Mass/volume] in Body fluid | 0.754 |  |
| 37019628 | Gastrointestinal bacterial pathogens panel - Stool by NAA with probe detection | 0.754 |  |
| 3005384 | Microscopic observation [Identifier] in Pleural fluid by Gram stain | 0.754 |  |
| 46234951 | Bacterial 16S rRNA [#/volume] in XXX.body fluid by NAA with probe detection | 0.754 |  |
| 3009228 | Elastase.pancreatic 2 [Enzymatic activity/volume] in Serum | 0.754 |  |
| 3031505 | Bacteria [Presence] in Synovial fluid by Light microscopy | 0.754 |  |
| 3047074 | Bacteria [Presence] in Vaginal fluid by Wet preparation | 0.753 |  |
| 40771457 | Lactate [Mass/volume] in Serum or Plasma --post exercise | 0.753 |  |
| 1091765 | Leukocyte clumps [#/area] in Urine sediment | 0.750 |  |
| 3050658 | Leukocyte clumps [#/area] in Urine sediment by Microscopy high power field | 0.750 | 1021 |
| 1091892 | Aggregatibacter aphrophilus DNA [Presence] in Specimen by NAA with probe detection | 0.750 |  |
| 1091056 | Aggregatibacter actinomycetemcomitans DNA [Presence] in Specimen by NAA with probe detection | 0.750 |  |
| 46236183 | Bacillus cereus [Presence] in Specimen by Organism specific culture | 0.750 |  |
| 3012625 | Microscopic observation [Identifier] in Cerebral spinal fluid by Acid fast stain | 0.749 |  |
| 40758731 | Microscopic observation [Identifier] in Pleural fluid by Cyto stain | 0.746 |  |
| 40759834 | Bacteria identified in Pericardial fluid by Culture | 0.746 |  |
| 1175816 | Bacteria identified in Peritoneal fluid by Aerobe culture | 0.745 |  |
| 3012339 | Bacteria identified in Semen | 0.744 |  |
| 42529408 | Campylobacter sp [Presence] in Stool by Culture | 0.744 |  |
| 1092003 | Prevotella buccae DNA [Presence] in Specimen by NAA with probe detection | 0.744 |  |
| 3048545 | Microorganism identified in Cervical or vaginal smear or scraping by Cyto stain | 0.743 |  |
| 3016675 | Lactate dehydrogenase [Enzymatic activity/volume] in Synovial fluid | 0.741 |  |
| 3051287 | Alpha 1 antitrypsin [Mass/mass] in 24 hour Stool | 0.741 |  |
| 42529409 | Escherichia coli O157 [Presence] in Stool by Culture | 0.740 |  |
| 3015054 | Lactate dehydrogenase [Enzymatic activity/volume] in Pleural fluid | 0.739 |  |
| 3050147 | Salmonella sp+Shigella sp+Escherichia coli enterotoxic [Identifier] in Stool by Organism specific culture | 0.734 |  |
| 42529406 | Shigella sp [Presence] in Stool by Culture | 0.734 |  |
| 1988257 | Bacilliform bacteria [Presence] in Urine sediment by Automated | 0.733 |  |
| 44816565 | Atopobium vaginae DNA [Log #/volume] in Vaginal fluid by NAA with probe detection | 0.729 |  |
| 3045330 | Bacteria identified in Cervix by Culture | 0.729 |  |
| 37021149 | Gastrointestinal parasitic pathogens panel - Stool by NAA with probe detection | 0.728 |  |
| 3012167 | Candida sp identified in Stool by Organism specific culture | 0.726 |  |
| 1092133 | Prevotella intermedia DNA [Presence] in Specimen by NAA with probe detection | 0.726 |  |
| 1761466 | Staph aureus and MRSA screening panel - Specimen by Organism specific culture | 0.726 |  |
| 3005461 | Lactate [Mass/volume] in Blood --4 hours post XXX challenge | 0.726 |  |
| 3002389 | Microscopic observation [Identifier] in Synovial fluid by Gram stain | 0.726 |  |
| 3010991 | Clostridioides difficile [Presence] in Specimen by Organism specific culture | 0.726 |  |
| 46234842 | Lactate [Moles/volume] in Capillary blood from Fetus by Test strip | 0.725 |  |
| 1469798 | Fungus identified in Vaginal fluid by Culture | 0.725 |  |
| 3039092 | Lactate dehydrogenase 1/Lactate dehydrogenase.total in Pleural fluid by Electrophoresis | 0.723 |  |
| 3000855 | Microscopic observation [Identifier] in Vaginal fluid by Gram stain | 0.722 |  |
| 46234891 | Bacterial 16S rRNA [#/mass] in XXX.tissue by NAA with probe detection | 0.721 |  |
| 3005532 | Lymphocytes/Leukocytes in Pleural fluid | 0.721 |  |
| 40758732 | Microscopic observation [Identifier] in Synovial fluid by Cyto stain | 0.720 |  |
| 3042126 | Lactate dehydrogenase 2/Lactate dehydrogenase.total in Pleural fluid by Electrophoresis | 0.719 |  |
| 3042406 | Lactate dehydrogenase 3/Lactate dehydrogenase.total in Pleural fluid by Electrophoresis | 0.719 |  |
| 3020915 | Virus identified in Vaginal fluid by Culture | 0.719 |  |
| 3018672 | pH of Body fluid | 0.716 | 953 |
| 647662 | Neisseria gonorrhoeae DNA [Presence] in Mouth by NAA with probe detection | 0.716 |  |
| 44816566 | Gardnerella vaginalis DNA [Log #/volume] in Vaginal fluid by NAA with probe detection | 0.716 |  |
| 3039118 | Lactate dehydrogenase 4/Lactate dehydrogenase.total in Pleural fluid by Electrophoresis | 0.716 |  |
| 3013754 | Clostridioides difficile [Presence] in Stool by Agglutination | 0.715 | 492 |
| 3039751 | Elastase Ab [Presence] in Serum | 0.714 |  |
| 1761571 | Yeast and Candida sp identification panel - Specimen by Organism specific culture | 0.712 |  |
| 3044790 | Chlamydia sp identified in Vaginal fluid by Organism specific culture | 0.709 |  |
| 3966351 | Clostridioides difficile DNA [Presence] in Stool by NAA with probe detection | 0.708 |  |
| 3002444 | Fungus identified in Synovial fluid by Culture | 0.708 |  |
| 647124 | Alpha 1 antitrypsin [Measurement] in Stool | 0.691 |  |
| 40771039 | Lactate dehydrogenase [Enzymatic activity/volume] in Synovial fluid by Pyruvate to lactate reaction | 0.690 |  |
| 3003329 | Lymphocytes/Leukocytes in Synovial fluid | 0.690 |  |
| 3036813 | Lactate [Presence] in Gastric fluid | 0.681 |  |
| 40771040 | Lactate dehydrogenase [Enzymatic activity/volume] in Synovial fluid by Lactate to pyruvate reaction | 0.667 |  |
| 40766118 | Elastase Ab [Presence] in Body fluid by Immunoassay | 0.667 |  |
| 3016304 | Abnormal lymphocytes/Leukocytes in Synovial fluid | 0.663 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2275 | -bakt-he |  | 100% | name | 111 | 100 |  |  |  | Antibiotic sensitivity | Bacteria [Susceptibility] |
| 2276 | -bakt-lm |  | 100% | name | 545 | 100 |  |  |  | Species identification | Bacteria identified |
| 2277 | -baktvi |  | 100% | name | 1515 | 100 |  | -Bakteeri, viljely |  |  | Bacteria identified in Specimen by Culture |
| 2278 | -baktvr |  | 100% | name | 22025 | 100 |  | -Bakteeri, värjäys |  |  | Bacteria identified in Specimen by Stain |
| 2279 | ab-laktaat | mmol/l | 94% | name+unit+values | 5666 | 0 | [0.6, 0.73, 0.87, 0.99, 1.13, 1.31, 1.55, 1.91, 2.7] |  | Arterial blood |  | Lactate [Moles/volume] in Arterial blood |
| 2280 | ab-laktaat |  | 6% | name | 385 | 100 |  |  | Arterial blood |  | Lactate in Arterial blood |
| 2281 | ab-laktaatti | mmol/l | 99% | name+unit+values | 415 | 0 | [0.6, 0.7, 0.85, 0.99, 1.14, 1.36, 1.62, 2.08, 3.17] |  | Arterial blood |  | Lactate [Moles/volume] in Arterial blood |
| 2282 | ab-laktaatti |  | 1% | name | 6 | 100 |  |  | Arterial blood |  | Lactate in Arterial blood |
| 2283 | af-baktvi |  | 100% | name | 262 | 100 |  |  | Aspiration fluid |  | Bacteria identified in Aspirate by Culture |
| 2284 | ap-laktaat | mmol/l | 99% | name+unit+values | 49217 | 0.02 | [0.7, 0.8, 0.9, 1.04, 1.19, 1.34, 1.58, 1.93, 2.65] |  |  |  | Lactate [Moles/volume] in Arterial plasma |
| 2285 | ap-laktaat |  | 1% | name | 248 | 100 |  |  |  |  | Lactate in Arterial plasma |
| 2286 | ap-laktaatti | mmol/l | 99% | name+unit+values | 3940 | 0 | [0.6, 0.7, 0.82, 0.97, 1.1, 1.28, 1.53, 1.93, 2.87] |  |  |  | Lactate [Moles/volume] in Arterial plasma |
| 2287 | ap-laktaatti |  | 1% | name | 22 | 100 |  |  |  |  | Lactate in Arterial plasma |
| 2288 | as-baktvr |  | 100% | name | 252 | 100 |  |  | Ascitic fluid |  | Bacteria identified in Ascitic fluid by Stain |
| 2289 | b-bakt-vi |  | 100% | name | 1757 | 100 |  |  | Blood | Culture | Bacteria identified in Blood by Culture |
| 2290 | b-baktjvi |  | 100% | name | 28084 | 100 |  | B -Bakteeri, jatkoviljely | Blood |  | Bacteria identified in Blood by Subculture |
| 2291 | b-baktsvi |  | 100% | name | 6514 | 100 |  |  | Blood |  | Bacteria [Presence] in Blood by Culture |
| 2292 | b-baktvi |  | 100% | name | 506538 | 100 |  | B -Bakteeri, viljely | Blood |  | Bacteria identified in Blood by Culture |
| 2293 | b-baktvi. |  | 100% | name | 2240 | 100 |  |  | Blood |  | Bacteria identified in Blood by Culture |
| 2294 | b-baktvij |  | 100% | name | 1818 | 100 |  |  | Blood |  | Bacteria identified in Blood by Subculture |
| 2295 | b-laktaat | mmol/l | 50% | name+unit+values | 337 | 0 | [0.62, 0.71, 0.82, 0.93, 1.08, 1.21, 1.46, 1.92, 2.86] | B -Laktaatti | Blood |  | Lactate [Moles/volume] in Blood |
| 2296 | b-laktaat |  | 50% | name | 335 | 100 |  | B -Laktaatti | Blood |  | Lactate in Blood |
| 2297 | bakteerit |  | 100% | name | 6114 | 100 |  |  |  |  | Bacteria [Presence] in Specimen |
| 2298 | baktlm |  | 100% | name | 897 | 100 |  |  |  |  | Bacteria identified |
| 2299 | baktvr |  | 100% | name | 339 | 100 |  |  |  |  | Bacteria identified in Specimen by Stain |
| 2300 | bl-baktvi |  | 100% | name | 303 | 100 |  |  | Bronchoalveolar lavage |  | Bacteria identified in Bronchoalveolar lavage fluid by Culture |
| 2301 | bo-baktvi |  | 100% | name | 312 | 100 |  |  | Bone |  | Bacteria identified in Bone by Culture |
| 2302 | ca-baktvi |  | 100% | name | 1564 | 100 |  | Ca-Bakteeri, viljely suonikanyylista |  |  | Bacteria identified in Catheter tip by Culture |
| 2303 | cb-laktaat | mmol/l | 98% | name+unit+values | 12059 | 0 | [0.9, 1.1, 1.23, 1.38, 1.53, 1.73, 1.97, 2.31, 2.95] |  | Capillary blood |  | Lactate [Moles/volume] in Capillary blood |
| 2304 | cb-laktaat |  | 2% | name | 288 | 100 |  |  | Capillary blood |  | Lactate in Capillary blood |
| 2305 | cp-laktaat | mmol/l | 96% | name+unit+values | 301 | 0 | [0.9, 1.02, 1.2, 1.3, 1.49, 1.65, 1.93, 2.29, 3.07] |  |  |  | Lactate [Moles/volume] in Capillary plasma |
| 2306 | cp-laktaat |  | 4% | name | 14 | 100 |  |  |  |  | Lactate in Capillary plasma |
| 2307 | d-baktvi |  | 100% | name | 120 | 100 |  |  |  |  | Bacteria identified in Drain fluid by Culture |
| 2308 | ex-baktvi |  | 100% | name | 14096 | 100 |  | Ex-Bakteeri, viljely | Expectorate (sputum) |  | Bacteria identified in Sputum by Culture |
| 2309 | ex-baktvr |  | 100% | name | 3217 | 100 |  |  | Expectorate (sputum) |  | Bacteria identified in Sputum by Stain |
| 2310 | f-baktjvi |  | 100% | name | 281 | 100 |  |  | Feces |  | Bacteria identified in Stool by Subculture |
| 2311 | f-baktvi1 |  | 100% | name | 32771 | 100 |  | F -Bakteeri, viljely 1 (Salmonella, Shigella, Yersinia, Campylobacter) | Feces |  | Salmonella and Shigella and Yersinia and Campylobacter species panel - Stool by Culture |
| 2312 | f-baktvi2 |  | 100% | name | 739 | 100 |  | F -Bakteeri, viljely 2 (Clostridium difficile, Staphylococcus aureus, candida) | Feces |  | Clostridioides difficile and Staphylococcus aureus and Candida panel - Stool by Culture |
| 2313 | f-baktvi3 |  | 100% | name | 1380 | 100 |  | F -Bakteeri, viljely 3 (viljely 1 + Bacillus cereus, Clostridium perfringens, Staphylococcus aureus) | Feces |  | Enteric pathogens panel - Stool by Culture |
| 2314 | f-baktvip |  | 100% | name | 17284 | 100 |  |  | Feces |  | Bacteria identified in Stool by Culture |
| 2315 | f-elastaasi-1 | ug/g | 63% | name+unit+values | 80 | 0 | [36.25, 72.33, 130, 174, 239.5, 308, 367.33, 444, 542.5] |  | Feces |  | Elastase.pancreatic 1 [Mass/mass] in Stool |
| 2316 | f-elastaasi-1 |  | 37% | name | 47 | 100 |  |  | Feces |  | Elastase.pancreatic 1 in Stool |
| 2317 | f-elastaasi1 | ug/g | 72% | name+unit+values | 205 | 1.95 | [58.67, 101.72, 132.4, 171.78, 206.3, 240.97, 285.31, 336.75, 412.33] |  | Feces |  | Elastase.pancreatic 1 [Mass/mass] in Stool |
| 2318 | f-elastaasi1 |  | 28% | name | 79 | 100 |  |  | Feces |  | Elastase.pancreatic 1 in Stool |
| 2319 | fl-baktna |  | 100% | name | 154 | 100 |  |  | Vaginal discharge |  | Bacteria DNA [Presence] in Vaginal fluid by NAA |
| 2320 | fl-baktvr |  | 100% | name | 11637 | 100 |  | Fl-Bakteeri, värjäys | Vaginal discharge |  | Bacteria identified in Vaginal fluid by Stain |
| 2321 | fp-laktaat | mmol/l | 99% | name+unit+values | 301358 | 0 | [0.53, 0.7, 0.8, 0.9, 1.01, 1.19, 1.39, 1.71, 2.34] | fP-Laktaatti | Fasting plasma |  | Lactate [Moles/volume] in Plasma |
| 2322 | fp-laktaat |  | 1% | name | 1633 | 100 |  | fP-Laktaatti | Fasting plasma |  | Lactate in Plasma |
| 2323 | fp-laktaatti | mmol/l | 100% | name+unit+values | 1982 | 0 | [0.79, 0.93, 1.09, 1.21, 1.38, 1.55, 1.78, 2.09, 2.72] |  | Fasting plasma |  | Lactate [Moles/volume] in Plasma |
| 2324 | fp-laktaatti |  | 0% | name | 7 | 100 |  |  | Fasting plasma |  | Lactate in Plasma |
| 2325 | fp-parathormoni | ng/l | 87% | name+unit+values | 3057 | 0 | [39.26, 52.29, 64.09, 76.18, 92.14, 109.87, 136.61, 188.47, 312.59] |  | Fasting plasma |  | Parathyrin [Mass/volume] in Plasma |
| 2326 | fp-parathormoni | pmol/l | 12% | name+unit+values | 423 | 0 | [4.16, 5.6, 7.49, 9.39, 11.31, 14.21, 18.57, 24.25, 46.66] |  | Fasting plasma |  | Parathyrin [Moles/volume] in Plasma |
| 2327 | fp-parathormoni |  | 1% | name | 31 | 100 |  |  | Fasting plasma |  | Parathyrin in Plasma |
| 2328 | fp-rauta(osat.) | umol/l | 100% | name+unit+values | 288 | 0 | [9.46, 11.8, 13.57, 15, 16.25, 17.88, 19.32, 21.84, 25.79] |  | Fasting plasma |  | Iron [Moles/volume] in Plasma |
| 2329 | li-baktvi |  | 100% | name | 7020 | 100 |  | Li-Bakteeri, viljely | Cerebrospinal fluid |  | Bacteria identified in Cerebral spinal fluid by Culture |
| 2330 | li-baktvr |  | 100% | name | 3747 | 100 |  | Li-Bakteeri, värjäys | Cerebrospinal fluid |  | Bacteria identified in Cerebral spinal fluid by Stain |
| 2331 | li-laktaat | mmol/l | 92% | name+unit+values | 4034 | 0.02 | [1.4, 1.5, 1.6, 1.7, 1.8, 1.93, 2.17, 2.53, 3.28] | Li-Laktaatti | Cerebrospinal fluid |  | Lactate [Moles/volume] in Cerebral spinal fluid |
| 2332 | li-laktaat |  | 8% | name+values | 359 | 100 | [1.46, 1.56, 1.68, 1.88, 2, 2, 2, 2.23, 3] | Li-Laktaatti | Cerebrospinal fluid |  | Lactate [Moles/volume] in Cerebral spinal fluid |
| 2333 | mb-laktaat | mmol/l | 94% | name+unit | 2452 | 0 |  |  |  |  | Lactate [Moles/volume] in Blood |
| 2334 | mb-laktaat |  | 6% | name | 157 | 100 |  |  |  |  | Lactate in Blood |
| 2335 | p-laboratorio |  | 100% | name | 221 | 100 |  |  | Plasma |  |  |
| 2336 | p-laktaat | mmol/l | 99% | name+unit+values | 21546 | 0 | [0.71, 0.89, 1, 1.14, 1.3, 1.49, 1.72, 2.06, 2.71] |  | Plasma |  | Lactate [Moles/volume] in Plasma |
| 2337 | p-laktaat |  | 1% | name | 113 | 100 |  |  | Plasma |  | Lactate in Plasma |
| 2338 | p-laktaatti | mmol/l | 100% | name+unit+values | 11624 | 0 | [0.7, 0.87, 1, 1.12, 1.29, 1.49, 1.72, 2.07, 2.76] |  | Plasma |  | Lactate [Moles/volume] in Plasma |
| 2339 | p-laktaatti |  | 0% | name | 43 | 100 |  |  | Plasma |  | Lactate in Plasma |
| 2340 | pd-baktvi |  | 100% | name | 917 | 100 |  | Pd-Bakteeri, viljely peritoneaalidialyysinesteestä | Peritoneal dialysis fluid |  | Bacteria identified in Peritoneal dialysis fluid by Culture |
| 2341 | pf-baktvr |  | 100% | name | 258 | 100 |  |  | Pleural fluid |  | Bacteria identified in Pleural fluid by Stain |
| 2342 | pf-laktaat | mmol/l | 92% | name+unit+values | 994 | 0 | [1.24, 1.54, 1.83, 2.21, 2.69, 3.33, 4.17, 5.46, 8.14] |  | Pleural fluid |  | Lactate [Moles/volume] in Pleural fluid |
| 2343 | pf-laktaat |  | 8% | name | 85 | 100 |  |  | Pleural fluid |  | Lactate in Pleural fluid |
| 2344 | pf-laktaatti | mmol/l | 100% | name+unit+values | 125 | 0 | [1.2, 1.49, 1.64, 2.05, 2.51, 3.11, 3.96, 5.16, 9.17] |  | Pleural fluid |  | Lactate [Moles/volume] in Pleural fluid |
| 2345 | pp-baktnh |  | 100% | name | 445 | 100 |  | Pp-Bakteeri, nukleiinihappo (kvant), ientasku | Periodontal pocket |  | Bacteria DNA [#/volume] in Periodontal pocket by NAA with probe detection |
| 2346 | ps-baktvi |  | 100% | name | 3894 | 100 |  | Ps-Bakteeri, viljely | Pharyngeal secretion |  | Bacteria identified in Pharynx by Culture |
| 2347 | pu-baktvi1 |  | 100% | name | 132179 | 100 |  | Pu-Bakteeri, viljely 1 (anaerobi + aerobiviljely, syvämärkä) | Pus |  | Bacteria identified in Pus by Anaerobic and Aerobic culture |
| 2348 | pu-baktvi2 |  | 100% | name | 97752 | 100 |  | Pu-Bakteeri, viljely 2 (aerobiviljely, pintamärkä) | Pus |  | Bacteria identified in Pus by Aerobic culture |
| 2349 | s-laktaatti | mmol/l | 100% | name+unit+values | 262 | 0 | [1.25, 1.39, 1.5, 1.57, 1.69, 1.79, 1.9, 2.1, 2.43] |  | Serum |  | Lactate [Moles/volume] in Serum |
| 2350 | sy-baktvr |  | 100% | name | 1225 | 100 |  |  | Synovial fluid |  | Bacteria identified in Synovial fluid by Stain |
| 2351 | sy-laktaat | mmol/l | 46% | name+unit+values | 247 | 0 | [2.75, 3.23, 3.84, 4.2, 4.64, 5.4, 6.36, 8.2, 11.68] | Sy-Laktaatti | Synovial fluid |  | Lactate [Moles/volume] in Synovial fluid |
| 2352 | sy-laktaat |  | 54% | name | 287 | 100 |  | Sy-Laktaatti | Synovial fluid |  | Lactate in Synovial fluid |
| 2353 | u-bact |  | 100% | name+values | 4570 | 100 | [0.99, 2.83, 5.12, 9.53, 18.07, 36.49, 88.52, 332.29, 2094.64] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 2354 | u-bakt | e6/l | 3% | name+unit+values | 12886 | 0 | [0.99, 2, 3.8, 6.5, 13.25, 30.37, 97.24, 567.39, 5475.37] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 2355 | u-bakt | estimate | 3% | name+unit | 14084 | 0.01 |  |  | Urine |  | Bacteria [Presence] in Urine |
| 2356 | u-bakt | u/field | 0% | name+unit | 11 | 0 |  |  | Urine |  | Bacteria [#/area] in Urine sediment by Microscopy |
| 2357 | u-bakt |  | 93% | name+values | 377251 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Bacteria [Presence] in Urine |
| 2358 | u-bakt-vi |  | 100% | name | 14923 | 100 |  |  | Urine | Culture | Bacteria identified in Urine by Culture |
| 2359 | u-bakt. | /sunf | 24% | name+unit+values | 514 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Bacteria [#/area] in Urine sediment by Microscopy |
| 2360 | u-bakt. | /sunfält | 2% | name+unit | 40 | 0 |  |  | Urine |  | Bacteria [#/area] in Urine sediment by Microscopy |
| 2361 | u-bakt. |  | 74% | name | 1617 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine |
| 2362 | u-baktalv |  | 100% | name | 2258 | 100 |  | U -Bakteeri, aluslasiviljely | Urine |  | Bacteria colony count [#/volume] in Urine by Slide culture |
| 2363 | u-baktb |  | 100% | name+values | 210 | 100 | [1.66, 5.71, 11.75, 19.06, 29.8, 65.32, 201.28, 2182.67, 10970.57] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 2364 | u-baktbv | e6/l | 98% | name+unit+values | 3962 | 0 | [0.8, 1.82, 3.94, 7.14, 16.08, 44.82, 182.18, 1319.22, 13314.4] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 2365 | u-baktbv |  | 2% | name | 93 | 100 |  |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 2366 | u-bakteeri |  | 100% | name | 1711 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine |
| 2367 | u-bakteerit | e6/l | 9% | name+unit+values | 1692 | 0 | [1, 3.32, 6.82, 15.06, 44.78, 157.3, 835.48, 6020.54, 24759.04] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 2368 | u-bakteerit |  | 91% | name | 16840 | 100 |  |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 2369 | u-baktevi |  | 100% | name | 18799 | 100 |  | U -Bakteeri, erikoisviljely | Urine |  | Bacteria identified in Urine by Culture |
| 2370 | u-baktjvi |  | 100% | name | 390824 | 100 |  | U -Bakteeri, jatkoviljely | Urine |  | Bacteria identified in Urine by Subculture |
| 2371 | u-baktjvi. |  | 100% | name | 11570 | 100 |  |  | Urine |  | Bacteria identified in Urine by Subculture |
| 2372 | u-baktla |  | 100% | name | 4577 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine |
| 2373 | u-baktlm |  | 100% | name | 1437 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 2374 | u-baktnim |  | 100% | name | 111 | 100 |  |  | Urine |  | Bacteria identified in Urine |
| 2375 | u-bakts |  | 100% | name | 1045 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine by Screen |
| 2376 | u-baktseu |  | 100% | name | 39886 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine by Screen |
| 2377 | u-baktsjvi |  | 100% | name | 539 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 2378 | u-bakttun |  | 100% | name | 653 | 100 |  |  | Urine |  | Bacteria identified in Urine |
| 2379 | u-baktv |  | 100% | name | 1154 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 2380 | u-baktvi | e6 | 0% | name+unit | 45 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria colony count [#/volume] in Urine by Culture |
| 2381 | u-baktvi | e6/l | 0% | name+unit | 60 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria colony count [#/volume] in Urine by Culture |
| 2382 | u-baktvi | form | 0% | name+unit | 10 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria identified in Urine by Culture |
| 2383 | u-baktvi |  | 100% | name | 1324678 | 100 |  | U -Bakteeri, viljely | Urine |  | Bacteria identified in Urine by Culture |
| 2384 | u-baktvi/ |  | 100% | name | 562 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 2385 | u-baktvi/oma |  | 100% | name | 629 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 2386 | u-baktvi2 |  | 100% | name | 283 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 2387 | u-baktvtk |  | 100% | name | 1637 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 2388 | u-happamuus |  | 100% | name+values | 204 | 100 | [6.5, 6.5, 7, 7, 7, 7.1, 7.5, 7.5, 8] |  | Urine |  | pH of Urine |
| 2389 | u-sakka,bakt |  | 100% | name | 330 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine sediment by Microscopy |
| 2390 | u-sakka,epit |  | 100% | name+values | 1251 | 100 | [0, 0, 0, 0, 0, 0, 0.35, 1, 2] |  | Urine |  | Epithelial cells [#/area] in Urine sediment by Microscopy |
| 2391 | u-sakka,eryt | u/field | 91% | name+unit+values | 1247 | 0 | [0, 0, 0, 0, 0.96, 1, 2, 3.08, 7.59] |  | Urine |  | Erythrocytes [#/area] in Urine sediment by Microscopy |
| 2392 | u-sakka,eryt |  | 9% | name | 121 | 100 |  |  | Urine |  | Erythrocytes [#/area] in Urine sediment by Microscopy |
| 2393 | u-sakka,leuk | u/field | 81% | name+unit+values | 1087 | 0 | [0, 0, 0, 0, 0, 0.95, 1.95, 4.61, 11] |  | Urine |  | Leukocytes [#/area] in Urine sediment by Microscopy |
| 2394 | u-sakka,leuk |  | 19% | name | 261 | 100 |  |  | Urine |  | Leukocytes [#/area] in Urine sediment by Microscopy |
| 2395 | u-sakka,lier |  | 100% | name+values | 367 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Casts [#/area] in Urine sediment by Microscopy |
| 2396 | u-sakka,makrof |  | 100% | name+values | 367 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Macrophages [#/area] in Urine sediment by Microscopy |
| 2397 | u-sakka,muuta |  | 100% | name+values | 456 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  |  |
| 2398 | u-solut,muut |  | 100% | name | 136 | 100 |  |  | Urine |  |  |
| 2399 | vb-laktaat | mmol/l | 96% | name+unit+values | 17603 | 0 | [0.8, 0.99, 1.11, 1.25, 1.39, 1.57, 1.79, 2.13, 2.75] |  | Venous blood |  | Lactate [Moles/volume] in Venous blood |
| 2400 | vb-laktaat |  | 4% | name+values | 701 | 100 | [0.88, 1, 1.1, 1.24, 1.41, 1.56, 1.78, 1.95, 2.36] |  | Venous blood |  | Lactate [Moles/volume] in Venous blood |
| 2401 | vp-laktaat | mmol/l | 98% | name+unit+values | 10894 | 0 | [0.9, 1.05, 1.2, 1.33, 1.49, 1.69, 1.92, 2.26, 2.87] |  |  |  | Lactate [Moles/volume] in Venous plasma |
| 2402 | vp-laktaat |  | 2% | name | 179 | 100 |  |  |  |  | Lactate in Venous plasma |

