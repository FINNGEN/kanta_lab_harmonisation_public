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
Here is group 106.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 1092251 | Bacteria identified in Bronchoalveolar lavage by Culture | 1.000 |  |
| 1469525 | Bacteria identified in Pus by Culture | 1.000 |  |
| 1761482 | Bacteria [#/volume] in Urine by Culture | 1.000 |  |
| 3002619 | Bacteria identified in Specimen by Culture | 1.000 | 39 |
| 3009986 | Bacteria identified in Catheter tip by Culture | 1.000 | 946 |
| 3012475 | Bacteria identified in Throat by Culture | 1.000 | 638 |
| 3016914 | Bacteria identified in Cerebral spinal fluid by Culture | 1.000 | 561 |
| 3023368 | Bacteria identified in Blood by Culture | 1.000 | 131 |
| 3023419 | Bacteria identified in Sputum by Culture | 1.000 | 1768 |
| 3025941 | Bacteria identified in Stool by Culture | 1.000 | 469 |
| 3026008 | Bacteria identified in Urine by Culture | 1.000 | 93 |
| 3027247 | Bacteria identified in Specimen | 1.000 |  |
| 3031040 | Bacteria [#/volume] in Urine by Automated count | 1.000 |  |
| 3031246 | Bacteria identified in Isolate | 1.000 | 1461 |
| 3043614 | Bacteria identified in Aspirate by Culture | 1.000 |  |
| 36304419 | Bacteria [Presence] in Urine | 1.000 |  |
| 40763091 | Bacteria identified in Peritoneal dialysis fluid by Culture | 1.000 |  |
| 3004562 | Bacteria [Presence] in Urine sediment by Light microscopy | 0.968 | 514 |
| 1092182 | Bacteria [Presence] in Urine sediment by Microscopy | 0.948 |  |
| 3025099 | Bacteria identified in Sputum by Respiratory culture | 0.945 | 275 |
| 1092248 | Bacteria [#/area] in Urine sediment by Microscopy | 0.943 |  |
| 3045360 | Bacteria identified in Bronchoalveolar lavage by Aerobe culture | 0.938 | 1695 |
| 1175982 | Bacteria identified in Peritoneal dialysis fluid by Aerobe culture | 0.934 |  |
| 3008582 | Bacteria identified in Aspirate by Aerobe culture | 0.928 |  |
| 1176221 | Bacteria identified in Catheter tip by Aerobe culture | 0.926 |  |
| 1175346 | Bacteria identified in Peritoneal dialysis fluid by Anaerobe culture | 0.925 |  |
| 3024461 | Microorganism identified in Specimen by Culture | 0.924 |  |
| 3042936 | Bacteria identified in Isolate by Culture | 0.924 |  |
| 3025037 | Bacteria identified in Peritoneal fluid by Culture | 0.923 |  |
| 1175370 | Bacteria identified in Catheter tip by Anaerobe culture | 0.922 |  |
| 36203273 | Bacterial identification and susceptibility panel - Isolate | 0.922 |  |
| 3025233 | Bacteria identified in Sputum by Aerobe culture | 0.921 |  |
| 3009451 | Bacteria identified in 24 hour Urine by Culture | 0.916 |  |
| 1091200 | Bacteria [#/volume] in Urine | 0.913 |  |
| 3023470 | Bacteria # 2 identified in Stool by Culture | 0.913 |  |
| 40763313 | Bacteria identified in Bone marrow by Culture | 0.912 |  |
| 3014398 | Bacteria identified in Bone by Aerobe culture | 0.909 |  |
| 36305419 | Bacteria identified in Cerebral spinal fluid by Aerobe culture | 0.908 |  |
| 3045560 | Bacteria # 2 identified in Specimen by Culture | 0.907 |  |
| 1091309 | Bacteria [#/area] in Urine sediment | 0.907 |  |
| 3035740 | Bacteria identified in Throat by Aerobe culture | 0.905 | 526 |
| 1469672 | Bacteria identified in Pus by Anaerobe culture | 0.903 |  |
| 3003776 | Bacteria # 4 identified in Stool by Culture | 0.899 |  |
| 3019479 | Bacteria # 2 identified in Urine by Culture | 0.896 |  |
| 3000521 | Bacteria # 3 identified in Stool by Culture | 0.896 |  |
| 3028923 | Bacteria [#/area] in Urine sediment by Automated count | 0.895 |  |
| 3013867 | Bacteria identified in Specimen by Aerobe culture | 0.895 | 276 |
| 3046647 | Bacteria # 4 identified in Specimen by Culture | 0.895 |  |
| 42529411 | Gastrointestinal pathogens panel - Stool by Culture | 0.895 |  |
| 3000455 | Bacteria identified in Stool by Anaerobe culture | 0.894 |  |
| 3014320 | Bacteria identified in Urethra by Culture | 0.893 |  |
| 3002687 | Bacteria # 5 identified in Stool by Culture | 0.893 |  |
| 3023764 | Bacteria identified in Specimen by Respiratory culture | 0.892 |  |
| 3016437 | Bacteria identified in Aspirate by Anaerobe culture | 0.892 |  |
| 3001028 | Bacteria # 6 identified in Stool by Culture | 0.891 |  |
| 3053320 | Bacteria # 2 identified in Blood by Culture | 0.891 |  |
| 3043867 | Bacteria # 8 identified in Specimen by Culture | 0.891 |  |
| 3045058 | Bacteria # 3 identified in Specimen by Culture | 0.891 |  |
| 3024362 | Bacteria identified in Dialysis fluid by Culture | 0.890 | 982 |
| 1092049 | Bacteria identified in Bronchial specimen by Culture | 0.889 |  |
| 3044420 | Bacteria # 6 identified in Specimen by Culture | 0.888 |  |
| 3003392 | Bacteria # 4 identified in Urine by Culture | 0.885 |  |
| 1091323 | Fungus identified in Catheter tip by Culture | 0.884 |  |
| 46234834 | Bacteria identified in Bone by Anaerobe+Aerobe culture | 0.884 |  |
| 1091465 | Bacteria # 2 identified in Catheter tip by Aerobe culture | 0.880 |  |
| 3046484 | Bacteria # 8 identified in Urine by Culture | 0.879 |  |
| 36303545 | Bacteria identified in Cerebral spinal fluid by Anaerobe culture | 0.879 |  |
| 3045335 | Bacteria # 7 identified in Urine by Culture | 0.879 |  |
| 3003113 | Bacteria # 5 identified in Urine by Culture | 0.878 |  |
| 3024194 | Bacteria identified in Pleural fluid by Culture | 0.877 |  |
| 3005024 | Bacteria # 3 identified in Urine by Culture | 0.877 |  |
| 3005745 | Bacteria identified in Blood by Aerobe culture | 0.876 |  |
| 3002013 | Bacteria # 6 identified in Urine by Culture | 0.876 |  |
| 1091909 | Bacteria # 2 identified in Catheter tip by Anaerobe culture | 0.875 |  |
| 3045873 | Bacteria identified in Nasopharynx by Culture | 0.875 |  |
| 3040138 | Bacteria identified in Sputum tracheal aspirate by Culture | 0.875 |  |
| 36304569 | Bacteria identified in Bronchoalveolar lavage by Anaerobe culture | 0.875 |  |
| 3049876 | Bacteria # 3 identified in Blood by Culture | 0.872 |  |
| 3000943 | Bacteria # 2 identified in Peritoneal fluid by Culture | 0.870 |  |
| 1469485 | Fungus identified in Pus by Culture | 0.870 |  |
| 36303914 | Fungus identified in Bronchoalveolar lavage by Culture | 0.868 |  |
| 3008334 | Bacteria identified in Drain by Aerobe culture | 0.868 |  |
| 3016528 | Bacteria # 4 identified in Peritoneal fluid by Culture | 0.867 |  |
| 3011797 | Bacteria identified in Abscess by Aerobe culture | 0.867 |  |
| 3012809 | Bacteria # 2 identified in Bone by Aerobe culture | 0.867 |  |
| 1091623 | Bacteria # 3 identified in Catheter tip by Anaerobe culture | 0.866 |  |
| 1092431 | Bacteria # 3 identified in Catheter tip by Aerobe culture | 0.866 |  |
| 46235543 | Bacteria identified in Isolate by MS.MALDI-TOF | 0.864 |  |
| 3000686 | Virus identified in Throat by Culture | 0.864 |  |
| 3032172 | Bacteria [Presence] in Urine by Automated | 0.862 |  |
| 3027005 | Bacteria identified in Tissue by Aerobe culture | 0.862 |  |
| 3013301 | Bacteria # 4 identified in Bone by Aerobe culture | 0.862 |  |
| 1092057 | Bacteria [#/volume] in Semen by Culture | 0.862 |  |
| 3007312 | Bacteria identified in Isolate by Anaerobe culture | 0.861 |  |
| 3036944 | Bacteria identified in Isolate by Aerobe culture | 0.861 |  |
| 3021618 | Bacteria # 5 identified in Peritoneal fluid by Culture | 0.860 |  |
| 36305689 | Fungus identified in Peritoneal dialysis fluid by Culture | 0.860 |  |
| 3010799 | Bacteria # 3 identified in Peritoneal fluid by Culture | 0.860 |  |
| 3002996 | Fungus identified in Cerebral spinal fluid by Culture | 0.859 |  |
| 42870564 | Atopobium vaginae DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.859 |  |
| 3000448 | Bacteria # 2 identified in Sputum by Aerobe culture | 0.858 |  |
| 3013146 | Bacteria identified in Wound by Aerobe culture | 0.857 |  |
| 3027326 | Bacteria # 3 identified in Bone by Aerobe culture | 0.857 |  |
| 37021450 | Urinary pathogens identified in Isolate by Organism specific culture | 0.856 |  |
| 3014365 | Bacteria # 6 identified in Bone by Aerobe culture | 0.855 |  |
| 3036266 | Bacteria # 2 identified in Throat by Aerobe culture | 0.854 |  |
| 3010729 | Bacteria # 5 identified in Bone by Aerobe culture | 0.853 |  |
| 3019415 | Bacteria identified in Food by Culture | 0.853 |  |
| 3044495 | Bacteria identified in Tissue by Culture | 0.852 |  |
| 648891 | Bacteria [Measurement] in Urine sediment | 0.852 |  |
| 3002611 | Bacteria # 4 identified in Sputum by Aerobe culture | 0.851 |  |
| 3016727 | Bacteria identified in Body fluid by Culture | 0.851 | 1786 |
| 3046136 | Bacteria # 7 identified in Specimen by Culture | 0.851 |  |
| 3003714 | Bacteria identified in Wound by Culture | 0.851 | 270 |
| 40770955 | Bacteria identified in Blood product unit by Culture | 0.850 |  |
| 3020072 | Bacteria # 6 identified in Sputum by Aerobe culture | 0.850 |  |
| 3035949 | Bacteria identified in Bone marrow by Aerobe culture | 0.850 | 1425 |
| 3019101 | Bacteria # 6 identified in Throat by Aerobe culture | 0.849 |  |
| 3001248 | Bacteria # 5 identified in Throat by Aerobe culture | 0.849 |  |
| 3001521 | Bacteria # 5 identified in Sputum by Aerobe culture | 0.849 |  |
| 3002416 | Bacteria # 4 identified in Throat by Aerobe culture | 0.847 |  |
| 3000088 | Virus identified in Cerebral spinal fluid by Culture | 0.847 |  |
| 1988560 | Cocci bacteria [#/volume] in Urine sediment by Automated count | 0.846 |  |
| 3006761 | Bacteria identified in Synovial fluid by Culture | 0.846 |  |
| 3000796 | Bacteria identified in Pleural fluid by Aerobe culture | 0.845 |  |
| 3043578 | Bacteria # 5 identified in Specimen by Culture | 0.844 |  |
| 3025255 | Bacteria [#/area] in Urine sediment by Microscopy high power field | 0.843 | 89 |
| 3029482 | Bacterial casts [Presence] in Urine sediment by Light microscopy | 0.843 |  |
| 1989355 | Bacilliform bacteria [#/volume] in Urine sediment by Automated count | 0.843 |  |
| 43533982 | Bacteria identified in Mouth by Culture | 0.842 |  |
| 3006673 | Bacteria identified in Blood by Anaerobe culture | 0.842 |  |
| 3004127 | Bacteria identified in Isolate by Animal inoculation | 0.842 |  |
| 42870565 | Bacterial vaginosis associated bacterium 2 DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.841 |  |
| 3015532 | Bacteria identified in Bronchial specimen by Aerobe culture | 0.841 |  |
| 1092021 | Bacteria [#/volume] in Bronchoalveolar lavage by Culture | 0.840 |  |
| 3029151 | Bacteria identified in Bronchial specimen | 0.840 |  |
| 3003509 | Bacteria # 3 identified in Throat by Aerobe culture | 0.839 |  |
| 3040827 | Bacteria identified in Anal by Culture | 0.839 |  |
| 1175669 | Bacteria identified in Synovial fluid by Aerobe culture | 0.839 |  |
| 1469941 | Gardnerella vaginalis DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.839 |  |
| 46235131 | Bacteria identified in Cerebral spinal fluid by Latex agglutination | 0.838 |  |
| 3029350 | Yeast [#/volume] in Urine by Automated count | 0.836 |  |
| 3036692 | Chlamydia sp DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.836 |  |
| 21492393 | Bacteria identified in Implanted device by Culture | 0.833 |  |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.832 |  |
| 3020896 | Bacterial susceptibility panel | 0.831 |  |
| 3044506 | Streptococcus sp identified in Isolate | 0.831 |  |
| 3042736 | Bacteria [Presence] in Specimen | 0.829 |  |
| 1175573 | Streptococcus agalactiae DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.827 |  |
| 3033396 | Fungus identified in Isolate | 0.827 |  |
| 1091231 | Bacteria Identification [Presence] in Isolate | 0.826 |  |
| 42870561 | Candida albicans DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.825 |  |
| 3046574 | Neisseria gonorrhoeae DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.825 | 3000 |
| 3000186 | Fungus identified in Aspirate by Culture | 0.823 |  |
| 3049146 | Mycoplasma sp identified in Urine by Organism specific culture | 0.823 |  |
| 3021344 | Bacteria [Presence] in Semen by Light microscopy | 0.823 |  |
| 3039448 | Bacteria identified in Bile fluid by Culture | 0.822 |  |
| 1091856 | Ureaplasma urealyticum DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.821 |  |
| 3033419 | Parasite identified in Isolate | 0.819 |  |
| 1092116 | Bacteria DNA [Presence] in Specimen by NAA with probe detection | 0.818 |  |
| 645382 | Bacteria [Measurement] in Urine | 0.816 |  |
| 40765197 | Candida sp DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.815 |  |
| 1092178 | Bacteria [Presence] in Urine by Computer assisted method | 0.815 |  |
| 3028855 | Bacteria [Presence] in Body fluid by Light microscopy | 0.813 |  |
| 3028269 | Bacteria identified in Vaginal fluid by Aerobe culture | 0.811 | 1225 |
| 3015055 | Bacteria identified in Amniotic fluid by Culture | 0.811 |  |
| 1988257 | Bacilliform bacteria [Presence] in Urine sediment by Automated | 0.810 |  |
| 3016298 | Mycobacterium sp identified in Cerebral spinal fluid by Organism specific culture | 0.809 |  |
| 645850 | Bacteria identified in Fistula by Culture | 0.807 |  |
| 43054974 | Bacteria [Presence] in Prostatic fluid by Light microscopy | 0.806 |  |
| 3021601 | Nitrite [Presence] in Urine by Test strip | 0.805 | 56 |
| 40761538 | Microorganisms seen [Type] in Urine sediment by Light microscopy | 0.804 |  |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.802 |  |
| 3032566 | Bacteria [Presence] in Pleural fluid by Light microscopy | 0.800 |  |
| 3008193 | Fungus identified in Specimen by Fungus stain | 0.798 | 825 |
| 1988670 | Cocci bacteria [Presence] in Urine sediment by Automated | 0.796 |  |
| 1989010 | Bacilliform bacteria [#/area] in Urine sediment by Automated count | 0.794 |  |
| 3014051 | Protein [Presence] in Urine by Test strip | 0.794 | 99 |
| 3001886 | Microscopic observation [Identifier] in Cerebral spinal fluid by Gram stain | 0.790 |  |
| 1091245 | Enteric bacteria panel - Stool by NAA with probe detection | 0.787 |  |
| 36304920 | Bacteria identified in Synovial fluid by Anaerobe culture | 0.783 |  |
| 36303793 | Bacteria identified in Pleural fluid by Anaerobe culture | 0.783 |  |
| 3033386 | Bacteria [Presence] in Cerebral spinal fluid by Light microscopy | 0.781 |  |
| 36303629 | Bacterial susceptibility panel - Isolate by Minimum lethal concentration (MLC) | 0.777 |  |
| 42529408 | Campylobacter sp [Presence] in Stool by Culture | 0.774 |  |
| 3042804 | Leukocyte esterase+Nitrite [Presence] in Urine by Test strip | 0.773 |  |
| 3024572 | Bacteria identified in Sputum by Cystic fibrosis respiratory culture | 0.773 |  |
| 3003703 | Bacteria # 3 identified in Sputum by Aerobe culture | 0.771 |  |
| 36303261 | Leukocytes [Presence] in Cerebral spinal fluid by Gram stain | 0.771 |  |
| 42529407 | Salmonella sp [Presence] in Stool by Culture | 0.768 |  |
| 3030758 | Nitrite [Presence] in Urine by Automated test strip | 0.768 |  |
| 1988077 | Cocci bacteria [#/area] in Urine sediment by Automated count | 0.767 |  |
| 3037426 | Urobilinogen [Presence] in Urine by Test strip | 0.766 | 134 |
| 42529406 | Shigella sp [Presence] in Stool by Culture | 0.765 |  |
| 3022036 | Colony count [#/volume] in Urine | 0.764 |  |
| 1092191 | Enteric pathogen panel - Stool by NAA with probe detection | 0.764 |  |
| 3027095 | Bacteria # 2 identified in Blood by Aerobe culture | 0.763 |  |
| 3027759 | Bacteria # 2 identified in Blood by Anaerobe culture | 0.760 |  |
| 3014990 | Bacteria identified in Specimen by Sterile body fluid culture | 0.759 |  |
| 3000855 | Microscopic observation [Identifier] in Vaginal fluid by Gram stain | 0.755 |  |
| 3005384 | Microscopic observation [Identifier] in Pleural fluid by Gram stain | 0.754 |  |
| 3031505 | Bacteria [Presence] in Synovial fluid by Light microscopy | 0.754 |  |
| 1761772 | Urinary tract pathogens panel - Urine by Culture | 0.750 |  |
| 46234951 | Bacterial 16S rRNA [#/volume] in XXX.body fluid by NAA with probe detection | 0.750 |  |
| 647359 | Yeast [Presence] in Vaginal fluid by Gram stain | 0.748 |  |
| 40758731 | Microscopic observation [Identifier] in Pleural fluid by Cyto stain | 0.746 |  |
| 40759834 | Bacteria identified in Pericardial fluid by Culture | 0.746 |  |
| 1091158 | Fungal susceptibility panel - Isolate by Minimum inhibitory concentration (MIC) | 0.746 |  |
| 42529410 | Plesiomonas shigelloides [Presence] in Stool by Culture | 0.739 |  |
| 3001849 | Virus identified in Stool by Culture | 0.738 |  |
| 1761492 | Campylobacter sp [Presence] in Stool by Organism specific culture | 0.738 |  |
| 3006928 | Escherichia coli enterotoxic identified in Stool by Organism specific culture | 0.738 |  |
| 3022889 | Bacteria # 6 identified in Peritoneal fluid by Culture | 0.737 |  |
| 1259757 | Campylobacter and Salmonella and Shigella sp identified in Stool by Organism specific culture | 0.734 |  |
| 3026005 | Bacteria identified in Cervix by Anaerobe culture | 0.732 |  |
| 42529409 | Escherichia coli O157 [Presence] in Stool by Culture | 0.731 |  |
| 3023207 | Escherichia coli O157:H7 [Presence] in Stool by Organism specific culture | 0.731 |  |
| 36304965 | Erythrocytes [Presence] in Cerebral spinal fluid by Gram stain | 0.731 |  |
| 3045330 | Bacteria identified in Cervix by Culture | 0.730 |  |
| 44816566 | Gardnerella vaginalis DNA [Log #/volume] in Vaginal fluid by NAA with probe detection | 0.728 |  |
| 3002389 | Microscopic observation [Identifier] in Synovial fluid by Gram stain | 0.726 |  |
| 645261 | Granulocytes [Presence] in Vaginal fluid by Gram stain | 0.725 |  |
| 3027190 | Salmonella enteritidis [Presence] in Stool by Organism specific culture | 0.725 |  |
| 1761887 | Enterobacteriaceae.carbapenem resistance panel - Anal by Organism specific culture | 0.724 |  |
| 3024483 | Escherichia coli verotoxic identified in Stool by Organism specific culture | 0.723 |  |
| 3031939 | Bacterial susceptibility panel by Gradient strip | 0.723 |  |
| 3022087 | Bacteria identified in Cervix by Aerobe culture | 0.721 |  |
| 3045744 | Candida sp identified in Vaginal fluid by Cyto stain | 0.720 |  |
| 40758732 | Microscopic observation [Identifier] in Synovial fluid by Cyto stain | 0.720 |  |
| 646646 | Yeast susceptibility limited panel - Isolate by Minimum inhibitory concentration (MIC) | 0.720 |  |
| 1175816 | Bacteria identified in Peritoneal fluid by Aerobe culture | 0.718 |  |
| 3030687 | Bacterial susceptibility panel by Minimum inhibitory concentration (MIC) | 0.718 |  |
| 3047074 | Bacteria [Presence] in Vaginal fluid by Wet preparation | 0.717 |  |
| 36305372 | Bacteria identified in Peritoneal fluid by Anaerobe culture | 0.717 |  |
| 1092060 | Bacterial resistance panel | 0.717 |  |
| 46234952 | Serratia marcescens gyrB gene [#/volume] in XXX.body fluid by NAA with probe detection | 0.713 |  |
| 1469798 | Fungus identified in Vaginal fluid by Culture | 0.710 |  |
| 3002444 | Fungus identified in Synovial fluid by Culture | 0.708 |  |
| 44816565 | Atopobium vaginae DNA [Log #/volume] in Vaginal fluid by NAA with probe detection | 0.703 |  |
| 44816660 | Megasphaera sp DNA [Log #/volume] in Vaginal fluid by NAA with probe detection | 0.703 |  |
| 44816567 | Lactobacillus sp DNA [Log #/volume] in Vaginal fluid by NAA with probe detection | 0.702 |  |
| 46234891 | Bacterial 16S rRNA [#/mass] in XXX.tissue by NAA with probe detection | 0.695 |  |
| 1616650 | Cytomegalovirus DNA [#/volume] (viral load) in Saliva (oral fluid) by NAA with probe detection | 0.684 |  |
| 46234949 | Moraxella catarrhalis g1b gene [#/volume] in XXX.body fluid by NAA with probe detection | 0.683 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1397 | -bakt-he |  | 100% | name | 111 | 100 |  |  |  | Antibiotic sensitivity | Bacteria susceptibility panel - Isolate |
| 1398 | -bakt-lm |  | 100% | name | 545 | 100 |  |  |  | Species identification | Bacteria identified in Isolate |
| 1399 | -baktvi |  | 100% | name | 1515 | 100 |  | -Bakteeri, viljely |  |  | Bacteria identified in Specimen by Culture |
| 1400 | -baktvr |  | 100% | name | 22025 | 100 |  | -Bakteeri, värjäys |  |  | Bacteria identified in Specimen by Stain |
| 1401 | af-baktvi |  | 100% | name | 262 | 100 |  |  | Aspiration fluid |  | Bacteria identified in Aspirate by Culture |
| 1402 | as-baktvr |  | 100% | name | 252 | 100 |  |  | Ascitic fluid |  | Bacteria identified in Ascites by Stain |
| 1403 | b-bakt-vi |  | 100% | name | 1757 | 100 |  |  | Blood | Culture | Bacteria identified in Blood by Culture |
| 1404 | b-baktjvi |  | 100% | name | 28084 | 100 |  | B -Bakteeri, jatkoviljely | Blood |  | Bacteria identified in Blood by Subculture |
| 1405 | b-baktsvi |  | 100% | name | 6514 | 100 |  |  | Blood |  | Bacteria identified in Blood by Culture |
| 1406 | b-baktvi |  | 100% | name | 506538 | 100 |  | B -Bakteeri, viljely | Blood |  | Bacteria identified in Blood by Culture |
| 1407 | b-baktvi. |  | 100% | name | 2240 | 100 |  |  | Blood |  | Bacteria identified in Blood by Culture |
| 1408 | b-baktvij |  | 100% | name | 1818 | 100 |  |  | Blood |  | Bacteria identified in Blood by Subculture |
| 1409 | bakteerit |  | 100% | name | 6114 | 100 |  |  |  |  | Bacteria identified in Specimen |
| 1410 | baktlm |  | 100% | name | 897 | 100 |  |  |  |  | Bacteria identified in Isolate |
| 1411 | baktvr |  | 100% | name | 339 | 100 |  |  |  |  | Bacteria identified in Specimen by Stain |
| 1412 | bl-baktvi |  | 100% | name | 303 | 100 |  |  | Bronchoalveolar lavage |  | Bacteria identified in Bronchoalveolar lavage by Culture |
| 1413 | bo-baktvi |  | 100% | name | 312 | 100 |  |  | Bone |  | Bacteria identified in Bone by Culture |
| 1414 | ca-baktvi |  | 100% | name | 1564 | 100 |  | Ca-Bakteeri, viljely suonikanyylista |  |  | Bacteria identified in Catheter tip by Culture |
| 1415 | d-baktvi |  | 100% | name | 120 | 100 |  |  |  |  | Bacteria identified in Drainage fluid by Culture |
| 1416 | ex-baktvi |  | 100% | name | 14096 | 100 |  | Ex-Bakteeri, viljely | Expectorate (sputum) |  | Bacteria identified in Sputum by Culture |
| 1417 | ex-baktvr |  | 100% | name | 3217 | 100 |  |  | Expectorate (sputum) |  | Bacteria identified in Sputum by Stain |
| 1418 | f-baktjvi |  | 100% | name | 281 | 100 |  |  | Feces |  | Bacteria identified in Stool by Subculture |
| 1419 | f-baktvi1 |  | 100% | name | 32771 | 100 |  | F -Bakteeri, viljely 1 (Salmonella, Shigella, Yersinia, Campylobacter) | Feces |  | Enteric organisms panel - Stool by Culture |
| 1420 | f-baktvi2 |  | 100% | name | 739 | 100 |  | F -Bakteeri, viljely 2 (Clostridium difficile, Staphylococcus aureus, candida) | Feces |  | Stool pathogens panel - Stool by Culture |
| 1421 | f-baktvi3 |  | 100% | name | 1380 | 100 |  | F -Bakteeri, viljely 3 (viljely 1 + Bacillus cereus, Clostridium perfringens, Staphylococcus aureus) | Feces |  | Enteric organisms panel - Stool by Culture |
| 1422 | f-baktvip |  | 100% | name | 17284 | 100 |  |  | Feces |  | Bacteria identified in Stool by Culture |
| 1423 | fl-baktna |  | 100% | name | 154 | 100 |  |  | Vaginal discharge |  | Bacteria DNA [Presence] in Vaginal fluid by NAA |
| 1424 | fl-baktvr |  | 100% | name | 11637 | 100 |  | Fl-Bakteeri, värjäys | Vaginal discharge |  | Bacteria identified in Vaginal fluid by Gram stain |
| 1425 | li-baktvi |  | 100% | name | 7020 | 100 |  | Li-Bakteeri, viljely | Cerebrospinal fluid |  | Bacteria identified in Cerebral spinal fluid by Culture |
| 1426 | li-baktvr |  | 100% | name | 3747 | 100 |  | Li-Bakteeri, värjäys | Cerebrospinal fluid |  | Bacteria identified in Cerebral spinal fluid by Gram stain |
| 1427 | pd-baktvi |  | 100% | name | 917 | 100 |  | Pd-Bakteeri, viljely peritoneaalidialyysinesteestä | Peritoneal dialysis fluid |  | Bacteria identified in Peritoneal dialysis fluid by Culture |
| 1428 | pf-baktvr |  | 100% | name | 258 | 100 |  |  | Pleural fluid |  | Bacteria identified in Pleural fluid by Stain |
| 1429 | pp-baktnh |  | 100% | name | 445 | 100 |  | Pp-Bakteeri, nukleiinihappo (kvant), ientasku | Periodontal pocket |  | Bacteria DNA [#/volume] in Gingival crevicular fluid by NAA |
| 1430 | ps-baktvi |  | 100% | name | 3894 | 99.97 |  | Ps-Bakteeri, viljely | Pharyngeal secretion |  | Bacteria identified in Throat by Culture |
| 1431 | pu-baktvi1 |  | 100% | name | 132179 | 100 |  | Pu-Bakteeri, viljely 1 (anaerobi + aerobiviljely, syvämärkä) | Pus |  | Bacteria identified in Pus by Culture |
| 1432 | pu-baktvi2 |  | 100% | name | 97752 | 100 |  | Pu-Bakteeri, viljely 2 (aerobiviljely, pintamärkä) | Pus |  | Bacteria identified in Pus by Aerobic culture |
| 1433 | sy-baktvr |  | 100% | name | 1225 | 100 |  |  | Synovial fluid |  | Bacteria identified in Synovial fluid by Stain |
| 1434 | u-bact |  | 100% | name+values | 4570 | 19.15 | [1.88, 4.41, 7.11, 12.12, 22.01, 65.08, 182.99, 478.65, 3425.04] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 1435 | u-bakt | e6/l | 3% | name+unit+values | 12886 | 0 | [0.99, 1.98, 3.85, 6.56, 13.19, 31.1, 95.22, 562.86, 5560.98] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 1436 | u-bakt | estimate | 3% | name+unit | 14084 | 99.66 |  |  | Urine |  | Bacteria [Presence] in Urine sediment by Microscopy light |
| 1437 | u-bakt | u/field | 0% | name+unit | 11 | 0 |  |  | Urine |  | Bacteria [#/area] in Urine sediment by Microscopy light |
| 1438 | u-bakt |  | 93% | name+values | 377251 | 99.78 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Bacteria [Presence] in Urine sediment by Microscopy light |
| 1439 | u-bakt-vi |  | 100% | name+values | 14923 | 100 | [10000, 10000, 10000, 10000, 1e+05, 1e+05, 1e+05, 1e+06, 1e+06] |  | Urine | Culture | Bacteria [#/volume] in Urine by Culture |
| 1440 | u-bakt. | /sunf | 24% | name+unit+values | 514 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Bacteria [#/area] in Urine sediment by Microscopy light |
| 1441 | u-bakt. | /sunfält | 2% | name+unit | 40 | 0 |  |  | Urine |  | Bacteria [#/area] in Urine sediment by Microscopy light |
| 1442 | u-bakt. |  | 74% | name | 1617 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine sediment |
| 1443 | u-baktalv |  | 100% | name | 2258 | 99.42 |  | U -Bakteeri, aluslasiviljely | Urine |  | Bacteria identified in Urine by Slide culture |
| 1444 | u-baktb |  | 100% | name+values | 210 | 4.29 | [1.72, 5.76, 11.77, 19.42, 30.15, 66.2, 213.28, 2129.49, 11056.23] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 1445 | u-baktbv | e6/l | 98% | name+unit+values | 3962 | 0 | [0.82, 1.8, 3.97, 7.16, 16.23, 44.68, 171.24, 1315.3, 12976.36] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 1446 | u-baktbv |  | 2% | name | 93 | 100 |  |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 1447 | u-bakteeri |  | 100% | name | 1711 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine |
| 1448 | u-bakteerit | e6/l | 9% | name+unit+values | 1692 | 0 | [1, 3.34, 6.78, 15.13, 44.47, 159.79, 845.2, 5975.08, 24980.83] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 1449 | u-bakteerit |  | 91% | name | 16840 | 99.96 |  |  | Urine |  | Bacteria [#/volume] in Urine by Automated count |
| 1450 | u-baktevi |  | 100% | name | 18799 | 99.99 |  | U -Bakteeri, erikoisviljely | Urine |  | Bacteria identified in Urine by Organism specific culture |
| 1451 | u-baktjvi |  | 100% | name | 390824 | 100 |  | U -Bakteeri, jatkoviljely | Urine |  | Bacteria identified in Urine by Subculture |
| 1452 | u-baktjvi. |  | 100% | name | 11570 | 100 |  |  | Urine |  | Bacteria identified in Urine by Subculture |
| 1453 | u-baktla |  | 100% | name | 4577 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine |
| 1454 | u-baktlm |  | 100% | name | 1437 | 100 |  |  | Urine |  | Bacteria identified in Urine by Organism specific culture |
| 1455 | u-baktnim |  | 100% | name | 111 | 100 |  |  | Urine |  | Bacteria identified in Urine by Organism specific culture |
| 1456 | u-bakts |  | 100% | name | 1045 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine by Test strip |
| 1457 | u-baktseu |  | 100% | name | 39886 | 99.99 |  |  | Urine |  | Bacteria [Presence] in Urine by Test strip |
| 1458 | u-baktsjvi |  | 100% | name | 539 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 1459 | u-bakttun |  | 100% | name | 653 | 100 |  |  | Urine |  | Bacteria identified in Urine by Organism specific culture |
| 1460 | u-baktv |  | 100% | name | 1154 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 1461 | u-baktvi | e6 | 0% | name+unit | 45 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria [#/volume] in Urine by Culture |
| 1462 | u-baktvi | e6/l | 0% | name+unit | 60 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria [#/volume] in Urine by Culture |
| 1463 | u-baktvi | form | 0% | name+unit | 10 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria identified in Urine by Culture |
| 1464 | u-baktvi |  | 100% | name+values | 1324678 | 99.99 | [106.83, 10000, 1e+05, 754545.45, 1e+06, 1e+07, 1e+08, 1e+08, 1e+08] | U -Bakteeri, viljely | Urine |  | Bacteria [#/volume] in Urine by Culture |
| 1465 | u-baktvi/ |  | 100% | name | 562 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 1466 | u-baktvi/oma |  | 100% | name | 629 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 1467 | u-baktvi2 |  | 100% | name | 283 | 100 |  |  | Urine |  | Bacteria identified in Urine by Organism specific culture |
| 1468 | u-baktvtk |  | 100% | name | 1637 | 100 |  |  | Urine |  | Bacteria identified in Urine |

