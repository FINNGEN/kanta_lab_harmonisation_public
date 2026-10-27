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
Here is group 42.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000285 | Sodium [Moles/volume] in Blood | 1.000 | 129 |
| 3002079 | Sodium [Moles/time] in 24 hour Urine | 1.000 | 1217 |
| 3002190 | Sodium [Moles/volume] in Dialysis fluid | 1.000 |  |
| 3003181 | Sodium [Moles/volume] in Urine | 1.000 | 412 |
| 3008607 | Semen analysis panel | 1.000 |  |
| 3020410 | Lactate [Moles/volume] in Arterial plasma | 1.000 |  |
| 3036428 | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid | 1.000 |  |
| 3040491 | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | 1.000 |  |
| 3043706 | Sodium [Moles/volume] in Arterial blood | 1.000 |  |
| 3015399 | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | 0.981 |  |
| 3000788 | Lamellar bodies [#/volume] in Amniotic fluid | 0.977 |  |
| 3013721 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.968 | 19 |
| 3015066 | Potassium [Moles/volume] in Serum or Plasma --post dialysis | 0.967 |  |
| 3039651 | Potassium [Moles/volume] in Serum or Plasma --pre dialysis | 0.965 |  |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.965 | 16 |
| 46235106 | Alanine aminotransferase [Enzymatic activity/volume] in Blood | 0.964 |  |
| 3046279 | Procalcitonin [Mass/volume] in Serum or Plasma | 0.963 |  |
| 44816586 | Sodium [Moles/volume] in Serum or Plasma --post dialysis | 0.961 |  |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 0.960 | 5 |
| 46236949 | Alanine aminotransferase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.960 |  |
| 3021387 | Prolactin [Units/volume] in Serum or Plasma | 0.960 |  |
| 3013603 | Prostate specific Ag [Mass/volume] in Serum or Plasma | 0.959 | 124 |
| 3018405 | Lactate [Moles/volume] in Arterial blood | 0.954 | 1277 |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.947 |  |
| 3038702 | Sodium [Moles/volume] in Capillary blood | 0.943 |  |
| 3014485 | Sodium [Moles/volume] in 24 hour Urine | 0.942 | 1451 |
| 3026910 | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | 0.942 | 190 |
| 3023103 | Potassium [Moles/volume] in Serum or Plasma | 0.938 | 3 |
| 3011363 | Streptococcus pneumoniae Ag [Presence] in Urine | 0.936 |  |
| 3003458 | Phosphate [Moles/volume] in Serum or Plasma | 0.935 | 69 |
| 3046569 | Transferrin receptor.soluble [Moles/volume] in Serum or Plasma | 0.930 |  |
| 3040086 | Sodium [Moles/volume] in Peritoneal dialysis fluid | 0.930 |  |
| 3023636 | Sodium [Moles/time] in 12 hour Urine | 0.930 |  |
| 3022948 | Iron [Moles/volume] in Serum or Plasma | 0.929 | 140 |
| 3018913 | Phosphate [Moles/volume] in Blood | 0.928 |  |
| 3005456 | Potassium [Moles/volume] in Blood | 0.927 | 106 |
| 3041697 | Sodium [Moles/time] in 1 hour Urine | 0.923 |  |
| 3008007 | Sodium [Mass/time] in 24 hour Urine | 0.920 |  |
| 40758733 | Microscopic observation [Identifier] in Endometrium by Cyto stain | 0.918 |  |
| 3965350 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Plasma | 0.914 |  |
| 3032915 | Prostate specific Ag [Mass/volume] in Urine | 0.914 |  |
| 46235078 | Potassium [Moles/volume] in Serum, Plasma or Blood | 0.912 |  |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.911 |  |
| 3038011 | Prostate specific Ag [Mass/volume] in Semen | 0.908 |  |
| 3000784 | Alanine aminotransferase [Enzymatic activity/volume] in Body fluid | 0.908 |  |
| 3015574 | Sodium [Moles/time] in 6 hour Urine | 0.908 |  |
| 3029213 | Adenosine deaminase [Enzymatic activity/volume] in Pericardial fluid | 0.908 |  |
| 1617495 | Sodium [Moles/volume] in Dialysis fluid --1 hour specimen | 0.907 |  |
| 21491979 | Prolactin monomeric [Units/volume] in Serum or Plasma | 0.906 |  |
| 3003792 | Aspartate aminotransferase [Enzymatic activity/volume] in Body fluid | 0.904 |  |
| 42870299 | PDGFRA gene exon 18 targeted mutation analysis in Blood or Tissue by Sequencing | 0.904 |  |
| 40760495 | Sodium [Moles/volume] in 2 hour Urine | 0.904 |  |
| 3052038 | Prostate specific Ag [Mass/volume] in Body fluid | 0.902 |  |
| 3035963 | Corticotropin [Moles/volume] in Plasma | 0.901 | 816 |
| 40762087 | Sodium [Moles/time] in 18 hour Urine | 0.900 |  |
| 1617300 | Sodium [Moles/volume] in Dialysis fluid --2 hour specimen | 0.900 |  |
| 3033252 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal fluid | 0.899 |  |
| 3004722 | Prolactin [Mass/volume] in Serum or Plasma | 0.898 | 290 |
| 1259553 | PDGFRA gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.898 |  |
| 40757362 | Semen analysis fertility panel | 0.896 |  |
| 1616723 | Sodium [Moles/volume] in Dialysis fluid --4 hour specimen | 0.895 |  |
| 3052577 | Aspartate aminotransferase.macromolecular [Enzymatic activity/volume] in Serum or Plasma | 0.895 |  |
| 3035637 | Corticotropin [Mass/volume] in Plasma | 0.895 |  |
| 3039179 | Angiotensin converting enzyme [Enzymatic activity/volume] in Peritoneal fluid | 0.895 |  |
| 40760484 | Sodium [Moles/volume] in 12 hour Urine | 0.895 |  |
| 3022810 | Sodium [Moles/volume] in Body fluid | 0.893 |  |
| 44816583 | Sodium [Moles/volume] in 4 hour Urine | 0.893 |  |
| 3005622 | Sodium [Moles/time] in 24 hour Stool | 0.892 |  |
| 42529229 | Prostate specific Ag [Mass/volume] in Serum or Plasma by Immunoassay | 0.890 |  |
| 42529228 | Prolactin [Units/volume] in Serum or Plasma by Immunoassay | 0.890 |  |
| 3966146 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Serum or Plasma | 0.889 |  |
| 3005491 | Lactate [Moles/volume] in Plasma venous | 0.888 | 1070 |
| 3034249 | Sodium [Moles/volume] in Urine collected for unspecified duration | 0.888 | 689 |
| 1988947 | Procalcitonin [Moles/volume] in Serum or Plasma | 0.888 |  |
| 3041244 | Adenosine deaminase [Enzymatic activity/volume] in Synovial fluid | 0.888 |  |
| 3028515 | Gamma glutamyl transferase [Enzymatic activity/volume] in Urine | 0.887 |  |
| 44817130 | Procalcitonin [Mass/volume] in Serum or Plasma by Immunoassay | 0.887 |  |
| 648404 | Procalcitonin [Mass/volume] in Serum, Plasma or Blood by Immunoassay | 0.886 |  |
| 3028465 | Gamma glutamyl transferase [Enzymatic activity/volume] in Body fluid | 0.885 |  |
| 3002131 | Prostate specific Ag [Units/volume] in Serum or Plasma | 0.885 |  |
| 3052018 | Alanine aminotransferase.macromolecular [Enzymatic activity/volume] in Serum or Plasma | 0.884 |  |
| 3026681 | Sodium [Moles/volume] in Specimen | 0.883 |  |
| 3041354 | Potassium [Moles/volume] in Venous blood | 0.882 |  |
| 3037249 | Prostate specific Ag [Moles/volume] in Serum or Plasma | 0.882 |  |
| 3014111 | Lactate [Moles/volume] in Serum or Plasma | 0.881 | 346 |
| 40758222 | PDGFRA gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.880 |  |
| 1469583 | PDGFRA gene full mutation analysis [Presence] in Blood or Tissue by Sequencing | 0.879 |  |
| 21491864 | Prolactin.dimeric [Units/volume] in Serum or Plasma | 0.879 |  |
| 3043409 | Potassium [Moles/volume] in Arterial blood | 0.879 |  |
| 3050931 | Microscopic observation [Identifier] in Endometrium by Rhodamine-auramine fluorochrome stain | 0.879 |  |
| 3037437 | Adenosine deaminase [Enzymatic activity/volume] in Body fluid | 0.879 |  |
| 3012169 | Aspartate aminotransferase [Enzymatic activity/volume] in Urine | 0.878 |  |
| 3047181 | Lactate [Moles/volume] in Blood | 0.877 | 475 |
| 3037666 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay | 0.877 |  |
| 3005435 | Aspartate aminotransferase [Enzymatic activity/volume] in Red Blood Cells | 0.875 |  |
| 44816844 | Macroprolactin [Units/volume] in Serum or Plasma | 0.875 |  |
| 3004056 | Alanine aminotransferase [Enzymatic activity/volume] in Amniotic fluid | 0.872 |  |
| 3035561 | Lactate [Mass/volume] in Arterial blood | 0.872 |  |
| 46236341 | Streptococcus pneumoniae Ag [Presence] in Urine by Rapid immunoassay | 0.872 |  |
| 37021379 | Sodium [Molar amount] in 24 hour Dialysis fluid | 0.871 |  |
| 3005755 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma by With P-5'-P | 0.871 |  |
| 3042781 | Aspartate aminotransferase [Enzymatic activity/volume] (Maximum value during study) in Serum or Plasma | 0.869 |  |
| 3026160 | Phosphate [Moles/volume] in Body fluid | 0.868 |  |
| 3022976 | Prolactin [Units/volume] in Serum or Plasma by 3rd IS | 0.867 |  |
| 42869608 | Oxygen saturation [Pure mass fraction] in Blood | 0.867 |  |
| 3015912 | Alanine aminotransferase [Enzymatic activity/volume] in Red Blood Cells | 0.865 |  |
| 3027653 | Mycophenolate [Mass/volume] in Serum or Plasma | 0.865 |  |
| 3040893 | Potassium [Moles/volume] in Capillary blood | 0.864 |  |
| 3009299 | Lupus anticoagulant neutralization platelet [Time] in Platelet poor plasma by Coagulation assay | 0.864 | 811 |
| 3024746 | Aspartate aminotransferase [Enzymatic activity/volume] in Synovial fluid | 0.864 |  |
| 3002400 | Iron [Mass/volume] in Serum or Plasma | 0.863 |  |
| 3031579 | Sodium [Moles/volume] in Mixed venous blood | 0.863 |  |
| 3042793 | Prostate specific Ag.protein bound [Mass/volume] in Serum or Plasma | 0.863 |  |
| 3023488 | Aspartate aminotransferase [Enzymatic activity/volume] in Amniotic fluid | 0.863 |  |
| 46237012 | PDGFRA gene p.Asp842Val [Presence] in Blood or Tissue by Molecular genetics method | 0.863 |  |
| 3037081 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma by With P-5'-P | 0.861 |  |
| 3002568 | Complement factor B [Mass/volume] in Serum or Plasma | 0.861 |  |
| 3019056 | Alanine aminotransferase/Aspartate aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.860 |  |
| 3039189 | Lupus anticoagulant neutralization dilute phospholipid [Time] in Platelet poor plasma | 0.860 |  |
| 36659714 | Sodium [Moles/volume] in Urine from Fetus | 0.860 |  |
| 3036243 | Potassium [Moles/volume] in Body fluid | 0.859 |  |
| 3028271 | Lactate [Moles/volume] in Capillary blood | 0.859 |  |
| 3009960 | Adenosine deaminase [Enzymatic activity/volume] in Blood | 0.858 |  |
| 3009305 | Lamellar bodies [Presence] in Amniotic fluid | 0.856 |  |
| 40757490 | Bicarbonate [Moles/volume] in Plasma --post dialysis | 0.856 |  |
| 44816699 | Transferrin receptor.soluble/log Ferritin index [Mass Ratio] in Serum or Plasma | 0.855 |  |
| 3035717 | Potassium [Moles/volume] in Dialysis fluid | 0.855 |  |
| 649327 | Procalcitonin [Measurement] in Serum or Plasma | 0.854 |  |
| 3008037 | Lactate [Moles/volume] in Venous blood | 0.854 |  |
| 3001838 | Sodium [Moles/volume] in Red Blood Cells | 0.853 |  |
| 3034552 | Adenosine deaminase [Enzymatic activity/volume] in Cerebral spinal fluid | 0.852 |  |
| 3005013 | Prostate Specific Ag Free [Mass/volume] in Serum or Plasma | 0.851 | 554 |
| 3052649 | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma | 0.851 |  |
| 3034933 | Prolactin monomeric [Mass/volume] in Serum or Plasma | 0.851 |  |
| 3013294 | Phosphate [Moles/volume] in Specimen | 0.850 |  |
| 3007625 | Streptococcus pneumoniae Ag [Presence] in Specimen | 0.849 |  |
| 3049714 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma | 0.849 |  |
| 3011732 | Aspartate aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.848 |  |
| 40762116 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal dialysis fluid | 0.848 |  |
| 3041449 | Collagen crosslinked C-telopeptide [Mass/volume] in Serum or Plasma | 0.847 |  |
| 3045783 | Sodium and Potassium panel [Moles/volume] - Serum or Plasma | 0.847 |  |
| 3004484 | Streptococcus pneumoniae Ag [Presence] in Sputum | 0.847 |  |
| 3051050 | Macroprolactin/Prolactin [Moles] in Serum or Plasma | 0.847 |  |
| 3000477 | Aspartate aminotransferase [Enzymatic activity/volume] in Cerebral spinal fluid | 0.845 |  |
| 3000162 | Prolactin [Mass/volume] in Serum or Plasma --baseline | 0.845 |  |
| 3022893 | Aspartate aminotransferase/Alanine aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.843 |  |
| 40757500 | Chloride [Moles/volume] in Serum or Plasma --post dialysis | 0.843 |  |
| 3013098 | Potassium [Moles/volume] in Specimen | 0.842 |  |
| 40762321 | Prostate specific Ag [Mass/volume] in Cerebral spinal fluid | 0.841 |  |
| 3033891 | Prothrombin time (PT) in Platelet poor plasma from Control by Coagulation assay | 0.840 |  |
| 3015481 | Prolactin [Mass/volume] in Serum or Plasma by Immunoassay | 0.840 |  |
| 3032987 | Sodium [Moles/volume] corrected for glucose in Serum or Plasma | 0.839 |  |
| 3004789 | Transferrin [Mass/volume] in Serum or Plasma | 0.839 | 809 |
| 3041133 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay --baseline | 0.838 |  |
| 3010307 | Gamma glutamyl transferase/Aspartate aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.838 |  |
| 40759093 | Phosphate [Moles/volume] in Serum or Plasma --post dialysis | 0.838 |  |
| 3033042 | Sodium [Moles/volume] in Peritoneal fluid | 0.837 |  |
| 3022229 | Phosphate [Moles/volume] in Urine | 0.837 | 1197 |
| 1091858 | Prothrombin time (PT) factor substitution [Time Ratio] in Control Platelet poor plasma by Coagulation assay --2H post incubation with 1:1 normal plasma | 0.836 |  |
| 3025033 | Iron [Moles/volume] in Body fluid | 0.836 |  |
| 3030573 | Phosphate [Moles/volume] in Dialysis fluid | 0.833 |  |
| 3047091 | Lupus anticoagulant neutralization buffer [Time] in Platelet poor plasma by Coagulation assay | 0.833 |  |
| 3011904 | Phosphate [Mass/volume] in Serum or Plasma | 0.833 |  |
| 3013823 | Potassium [Moles/volume] in Red Blood Cells | 0.832 |  |
| 3016038 | Potassium [Moles/volume] in Urine | 0.832 | 493 |
| 1259708 | PDGFRA gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.832 |  |
| 3009991 | Angiotensin converting enzyme [Enzymatic activity/volume] in Cerebral spinal fluid | 0.831 |  |
| 3007023 | Streptococcus pneumoniae Ag [Presence] in Serum | 0.831 |  |
| 3005949 | Lactate [Moles/volume] in Mixed venous blood | 0.830 |  |
| 3036335 | Angiotensin converting enzyme [Enzymatic activity/volume] in Blood | 0.830 | 1299 |
| 3004825 | Lactate [Moles/volume] in Body fluid | 0.829 |  |
| 3047891 | FGFR2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.829 |  |
| 3027184 | Lupus anticoagulant [Interpretation] in Platelet poor plasma | 0.829 |  |
| 3042943 | Fatty acid essential (C12-C22) panel - Serum or Plasma | 0.829 |  |
| 3034780 | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | 0.829 | 730 |
| 3022392 | Complement factor Bb [Mass/volume] in Serum or Plasma | 0.826 |  |
| 3035960 | Phosphate [Moles/volume] in Red Blood Cells | 0.826 |  |
| 3009107 | Complement factor B [Mass/volume] in Body fluid | 0.826 |  |
| 36032012 | Gamma glutamyl transferase [Enzymatic activity/volume] in DBS | 0.825 |  |
| 3022979 | Gamma glutamyl cysteine synthetase [Enzymatic activity/volume] in Serum | 0.825 |  |
| 40758927 | Mycophenolate [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.825 |  |
| 3027627 | Lupus anticoagulant neutralization high phospholipid [Time] in Platelet poor plasma by Coagulation assay | 0.824 |  |
| 36304001 | Fatty acid omega-3 and omega-6 panel - Serum or Plasma | 0.824 |  |
| 21493666 | Mycophenolate acyl-glucuronide [Mass/volume] in Serum or Plasma | 0.824 |  |
| 3021398 | Gamma glutamyl transferase [Enzymatic activity/volume] in Amniotic fluid | 0.824 |  |
| 42869600 | Oxygen saturation [Pure mass fraction] in Venous blood | 0.823 |  |
| 40763074 | Corticotropin [Moles/volume] in Plasma --baseline | 0.822 |  |
| 3031076 | Corticotropin [Mass/volume] in Plasma --baseline | 0.822 |  |
| 3008152 | Bicarbonate [Moles/volume] in Arterial blood | 0.821 | 310 |
| 46235718 | Delta aPTT [Time] in Platelet poor plasma by Coagulation assay | 0.820 |  |
| 1259791 | Lupus anticoagulant aPTT screening panel - Platelet poor plasma by Coagulation assay | 0.819 |  |
| 40762241 | Calcium [Moles/volume] in Serum or Plasma --post dialysis | 0.819 |  |
| 3026365 | Gamma glutamyl transferase [Enzymatic activity/volume] in Semen | 0.818 |  |
| 3031643 | Corticotropin [Mass/volume] in Plasma --3 AM specimen | 0.818 |  |
| 3013502 | Oxygen saturation in Blood | 0.818 | 426 |
| 3049135 | FLT3 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.818 |  |
| 46236075 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma by Immunoassay | 0.817 |  |
| 40761633 | Corticotropin [Moles/volume] in Plasma --10 AM specimen | 0.817 |  |
| 43055501 | Mycophenolate [Mass/volume] in Serum or Plasma --trough | 0.816 |  |
| 3013870 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma | 0.815 |  |
| 40761662 | Corticotropin [Moles/volume] in Plasma --2 PM specimen | 0.815 |  |
| 40761632 | Corticotropin [Mass/volume] in Plasma --10 AM specimen | 0.815 |  |
| 40759058 | Magnesium [Moles/volume] in Serum or Plasma --post dialysis | 0.815 |  |
| 3049123 | Corticotropin [Mass/volume] in Plasma --12 AM specimen | 0.815 |  |
| 40757623 | Alanine aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.815 |  |
| 3027206 | Corticotropin [Mass/volume] in Plasma by Radioimmunoassay (RIA) | 0.814 |  |
| 40761642 | Corticotropin [Moles/volume] in Plasma --12 AM specimen | 0.814 |  |
| 3050146 | Prolactin [Mass/volume] in Serum or Plasma by 3rd IS | 0.813 |  |
| 3031315 | Corticotropin [Mass/volume] in Plasma --3 PM specimen | 0.812 |  |
| 3010989 | Calcitonin [Mass/volume] in Serum or Plasma | 0.812 | 1605 |
| 3032992 | Corticotropin [Mass/volume] in Plasma --6 PM specimen | 0.812 |  |
| 3052673 | Corticotropin [Mass/volume] in Plasma --4 AM specimen | 0.811 |  |
| 42869607 | Oxygen saturation [Pure mass fraction] in Arterial blood | 0.811 |  |
| 3024232 | Phosphate [Mass/volume] in Blood | 0.810 |  |
| 40762366 | Oxygen capacity [Volume Fraction] in Arterial blood | 0.810 |  |
| 40761643 | Corticotropin [Moles/volume] in Plasma --12 PM specimen | 0.810 |  |
| 40761635 | Corticotropin [Moles/volume] in Plasma --10 PM specimen | 0.810 |  |
| 3009873 | Streptococcus pneumoniae Ag [Presence] in Specimen by Latex agglutination | 0.809 |  |
| 43533705 | Mycophenolate [Mass/volume] in Serum or Plasma --peak | 0.809 |  |
| 40762388 | Lacosamide [Mass/volume] in Serum or Plasma | 0.809 |  |
| 40761703 | Corticotropin [Moles/volume] in Plasma --4 AM specimen | 0.808 |  |
| 3037998 | Microscopic observation [Identifier] in Specimen by Hematoxylin and eosin stain | 0.808 |  |
| 40761710 | Corticotropin [Moles/volume] in Plasma --6 PM specimen | 0.808 |  |
| 3031904 | Prolactin [Mass/volume] in Serum or Plasma --6th specimen | 0.807 |  |
| 40761862 | Gamma glutamyl transferase [Enzymatic activity/time] in 24 hour Urine | 0.807 |  |
| 42869606 | Oxygen saturation [Pure mass fraction] in Capillary blood | 0.807 |  |
| 3040526 | Collagen crosslinked C-telopeptide [Moles/volume] in Serum or Plasma | 0.807 |  |
| 3005082 | Progesterone [Moles/volume] in Serum or Plasma | 0.806 | 318 |
| 40760300 | Lupus anticoagulant neutralization dilute phospholipid/Lupus anticoagulant neutralization.high phospholipid [Ratio] in Platelet poor plasma by Coagulation assay | 0.806 |  |
| 3030428 | Prolactin [Mass/volume] in Serum or Plasma --7th specimen | 0.805 |  |
| 40757626 | Glucose [Moles/volume] in Serum or Plasma --post dialysis | 0.804 |  |
| 3031730 | PTPN11 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.804 |  |
| 3046505 | Aldolase [Enzymatic activity/volume] in Pleural fluid | 0.803 |  |
| 3011173 | Microscopic observation [Identifier] in Tissue by Hematoxylin and eosin stain | 0.803 |  |
| 42868685 | Mycophenolate [Moles/volume] in Serum or Plasma | 0.802 | 1787 |
| 3048498 | TGFBR2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.801 |  |
| 3044230 | Potassium [Moles/volume] in Peritoneal dialysis fluid | 0.801 |  |
| 646651 | Prolactin [Measurement] in Serum or Plasma | 0.800 |  |
| 3017427 | Lupus anticoagulant neutralization dilute phospholipid [Presence] in Platelet poor plasma | 0.800 | 1189 |
| 3004923 | Protein C [Mass/volume] in Plasma | 0.799 |  |
| 3029242 | Protein C/Coagulation factor X [Mass Ratio] in Platelet poor plasma | 0.799 |  |
| 3002903 | Transferrin [Moles/volume] in Serum or Plasma | 0.799 | 809 |
| 40763951 | Prothrombin time (PT) in Platelet poor plasma from Fetus by Coagulation assay | 0.799 |  |
| 3023542 | Coagulation normal/actual in Platelet poor plasma by Prothrombin time (PT) | 0.798 |  |
| 44786996 | Sodium and Potassium panel [Moles/volume] - Blood | 0.797 |  |
| 3039732 | Gamma glutamyl transferase [Enzymatic activity/volume] in Dialysis fluid | 0.797 |  |
| 1175721 | Fatty acid omega-3 and omega-6 panel - Blood | 0.796 |  |
| 3033688 | Peak flow meter device panel | 0.796 |  |
| 40762387 | Lacosamide [Mass/volume] in Blood | 0.796 |  |
| 3025481 | Topiramate [Mass/volume] in Serum or Plasma | 0.795 | 1804 |
| 3015401 | Amylase [Enzymatic activity/volume] in Pleural fluid | 0.794 |  |
| 3021530 | Procollagen type I [Mass/volume] in Serum | 0.794 |  |
| 3049183 | Collagen crosslinked C-telopeptide [Mass/volume] in Urine | 0.793 |  |
| 3039247 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay --2 hours pre XXX challenge | 0.792 |  |
| 3023261 | lamoTRIgine [Mass/volume] in Serum or Plasma | 0.791 |  |
| 3022667 | Microscopic observation [Identifier] in Cervix by Wet preparation | 0.791 |  |
| 3043920 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay --2 hours post XXX challenge | 0.791 |  |
| 3033295 | Lupus anticoagulant neutralization dilute phospholipid actual/normal in Platelet poor plasma by Coagulation assay | 0.791 |  |
| 3040058 | Iron [Moles/volume] in Water | 0.790 |  |
| 3010424 | Ferritin [Moles/volume] in Serum or Plasma | 0.789 |  |
| 36659885 | Transthyretin [Mass] in Blood | 0.788 |  |
| 42869547 | Procollagen type III.N-terminal propeptide [Mass/volume] in Serum | 0.788 |  |
| 3006550 | Complement factor Ba [Mass/volume] in Serum or Plasma | 0.788 |  |
| 40758907 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of platelet lysate | 0.786 |  |
| 3040416 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay --1 hour post XXX challenge | 0.786 |  |
| 3002142 | Oxygen [Partial pressure] in Gas | 0.786 |  |
| 40758928 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.784 |  |
| 645187 | Iron [Measurement] in Serum or Plasma | 0.784 |  |
| 3038697 | Lupus anticoagulant neutralization platelet [Presence] in Platelet poor plasma by Coagulation assay | 0.783 |  |
| 3006358 | Streptococcus pneumoniae Ab [Presence] in Serum | 0.783 |  |
| 3008561 | Activated protein C resistance [Time Ratio] in Platelet poor plasma by Coagulation assay | 0.782 | 797 |
| 3012734 | Streptococcus pneumoniae Ag [Presence] in Sputum by Immunofluorescence | 0.782 |  |
| 3015683 | Streptococcus pneumoniae Ag [Presence] in Specimen by Immunofluorescence | 0.782 |  |
| 3052662 | Ceruloplasmin [Moles/volume] in Serum or Plasma | 0.782 |  |
| 42869601 | Oxygen saturation [Pure mass fraction] in Mixed venous blood | 0.782 |  |
| 3049361 | Cytology report of Specimen Cyto stain | 0.781 |  |
| 3001977 | Microscopic observation [Identifier] in Tissue by Hematoxylin-eosin-Mayers progressive stain | 0.781 |  |
| 3014286 | Streptococcus pneumoniae Ag [Presence] in Cerebral spinal fluid | 0.780 |  |
| 40758906 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of saline | 0.779 |  |
| 3030682 | Semen analysis post vasectomy panel | 0.777 |  |
| 3044051 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of normal plasma | 0.777 |  |
| 3009814 | Iron saturation [Molar fraction] in Serum or Plasma | 0.777 | 192 |
| 40763251 | Topiramate [Mass/volume] in Blood | 0.776 |  |
| 3043701 | Iron [Moles/volume] in Urine | 0.775 |  |
| 3008440 | Collagen crosslinked N-telopeptide [Moles/volume] in Serum | 0.775 |  |
| 44786791 | Ezogabine [Mass/volume] in Plasma | 0.775 |  |
| 21493512 | Coagulation factor X activated inhibitor [Mass/volume] in Platelet poor plasma | 0.775 |  |
| 3021977 | Prothrombin Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.774 |  |
| 3049840 | Microscopic observation [Identifier] in Endocervical brush by Cyto stain | 0.774 | 750 |
| 3007886 | Transferrin [Mass/volume] in Urine | 0.774 |  |
| 3020287 | Protein C actual/normal in Platelet poor plasma by Coagulation assay | 0.773 | 886 |
| 3002681 | Prothrombin Ag actual/normal in Platelet poor plasma by Immunoassay | 0.772 |  |
| 3037430 | Protein C/Coagulation factor IX [Mass Ratio] in Platelet poor plasma | 0.772 |  |
| 3011482 | Spermatozoa motility and count panel | 0.772 |  |
| 3007603 | Complement factor P [Mass/volume] in Plasma | 0.772 |  |
| 40761054 | Collagen crosslinked C-telopeptide [Mass/volume] in 24 hour Urine | 0.771 |  |
| 42869602 | Oxygen saturation [Pure mass fraction] in Venous cord blood | 0.771 |  |
| 3022519 | Antithrombin [Interpretation] in Platelet poor plasma | 0.770 | 1117 |
| 1469604 | Lacosamide [Mass/volume] in Serum --trough | 0.770 |  |
| 3025378 | Microscopic observation [Identifier] in Cervix by Cyto stain | 0.769 | 484 |
| 42869590 | Oxygen/Gas total [Pure volume fraction] Inhaled gas | 0.769 |  |
| 3052628 | Collagen type 1 Ab [Units/volume] in Serum | 0.768 |  |
| 648623 | Mycophenolate [Measurement] in Serum or Plasma | 0.768 |  |
| 3015029 | Plasminogen activator urokinase type [Units/volume] in Urine | 0.768 |  |
| 646647 | Antithrombin Ag [Measurement] in Platelet poor plasma | 0.768 |  |
| 3023017 | Iron/Transferrin [Mass Ratio] in Serum or Plasma | 0.767 |  |
| 3009101 | Plasminogen activator urokinase type [Units/volume] in Platelet poor plasma | 0.767 |  |
| 3005757 | Coagulation factor V activity actual/normal in Platelet poor plasma by Coagulation assay | 0.767 | 1703 |
| 1091136 | Microscopic observation [Identifier] in Specimen | 0.766 |  |
| 648872 | Transferrin [Measurement] in Serum or Plasma | 0.766 |  |
| 1001657 | Lurasidone [Mass/volume] in Serum or Plasma | 0.765 |  |
| 3006924 | Coagulation factor V activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.764 |  |
| 3017155 | Microscopic observation [Identifier] in Specimen by Iron hematoxylin stain | 0.764 |  |
| 3016005 | Antithrombin Ag [Mass/volume] in Platelet poor plasma by Immunoassay | 0.763 |  |
| 44816835 | lamoTRIgine [Mass/volume] in Serum or Plasma --trough | 0.763 |  |
| 3005445 | Coagulation factor X activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.762 |  |
| 3965093 | Coagulation factor X inhibitor [Units/volume] in Platelet poor plasma by Chromogenic method | 0.762 |  |
| 3050351 | Pregabalin [Mass/volume] in Serum or Plasma | 0.762 |  |
| 3023945 | Coagulation factor V Ag actual/normal in Platelet poor plasma by Immunoassay | 0.761 |  |
| 1988420 | Gas and electrolytes panel - Arterial blood | 0.760 |  |
| 3032706 | Protein S Ag/Coagulation factor X Ag [Mass Ratio] in Platelet poor plasma by Coagulation assay | 0.760 |  |
| 42869604 | Oxygen saturation [Pure mass fraction] in Cord blood | 0.759 |  |
| 3026621 | Complement factor H [Mass/volume] in Serum or Plasma | 0.759 |  |
| 3005075 | Coagulation factor X+Acarboxy Ag actual/normal in Platelet poor plasma by Immunoassay | 0.759 |  |
| 3965143 | Calprotectin [Mass/volume] in Serum or Plasma | 0.758 |  |
| 3027396 | Coagulation factor V Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.758 |  |
| 42869599 | Oxygen saturation [Pure mass fraction] Calculated from oxygen partial pressure in Blood | 0.758 |  |
| 3003308 | Coagulation factor X activity [Units/volume] in Platelet poor plasma by Chromogenic method | 0.757 |  |
| 3009492 | Protein S/Coagulation factor IX [Mass Ratio] in Platelet poor plasma by Coagulation assay | 0.757 |  |
| 40761986 | Calcitonin [Mass/volume] in Serum or Plasma --baseline | 0.757 |  |
| 3018840 | Calcitonin [Moles/volume] in Serum or Plasma | 0.756 |  |
| 40768507 | Time to expiratory gas flow.max | 0.756 |  |
| 3019794 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --post therapy | 0.755 |  |
| 3049875 | Spermatozoa morphology panel | 0.755 |  |
| 3045669 | Fatty acid comprehensive (C8-C26) panel - Serum or Plasma | 0.754 |  |
| 3036669 | Protein S actual/normal in Platelet poor plasma by Coagulation assay | 0.753 | 1104 |
| 40758360 | Electrolytes panel - Blood | 0.753 |  |
| 3964861 | Semen and urine analysis fertility panel - Specimen | 0.752 |  |
| 3008009 | Antithrombin Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.752 | 1553 |
| 3021008 | Coagulation factor X+Acarboxy Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.752 |  |
| 21494686 | Coagulation factor V inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.751 |  |
| 1988962 | Transferrin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.750 |  |
| 3004057 | Coagulation factor V inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.750 |  |
| 3000515 | Antithrombin actual/normal in Platelet poor plasma by Chromogenic method | 0.750 | 760 |
| 3020783 | Coagulation factor X Ag actual/normal in Platelet poor plasma by Immunoassay | 0.749 |  |
| 3020427 | Coagulation factor X inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.748 |  |
| 3037384 | Protein C actual/normal in Platelet poor plasma by Chromogenic method | 0.748 | 1210 |
| 42869550 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --pre therapy | 0.748 |  |
| 3014353 | Coagulation factor X Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.748 |  |
| 3003296 | Protein C cofactor [Units/volume] in Platelet poor plasma | 0.748 |  |
| 1761456 | Vitamin A/Retinol binding protein [Ratio] in Serum or Plasma | 0.747 |  |
| 3051695 | PROS1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.747 |  |
| 3018676 | Antithrombin [Units/volume] in Platelet poor plasma by Chromogenic method | 0.746 | 1235 |
| 3016412 | Protein S Ag/Coagulation factor VII Ag [Mass Ratio] in Platelet poor plasma by Coagulation assay | 0.746 |  |
| 3008721 | Complement factor I [Mass/volume] in Serum or Plasma | 0.745 |  |
| 3007399 | Protein C Ag [Mass/volume] in Platelet poor plasma | 0.745 |  |
| 3003771 | Antithrombin Ag actual/normal in Platelet poor plasma by Immunoassay | 0.743 |  |
| 3036351 | Fibrinopeptide B [Mass/volume] in Serum | 0.742 |  |
| 3035670 | Protein C Ag/Coagulation factor VII Ag [Mass Ratio] in Platelet poor plasma by Immunoassay | 0.740 |  |
| 3031916 | CPT2 gene p.Arg631Cys [Presence] in Blood by Molecular genetics method | 0.740 |  |
| 46236485 | PCDH15 gene c.733C>T [Presence] in Blood or Tissue by Molecular genetics method | 0.740 |  |
| 46235736 | Interleukin 2 Receptor Soluble [Mass/volume] in Serum or Plasma | 0.740 |  |
| 3001036 | Coagulation factor VII+Coagulation factor X actual/normal in Platelet poor plasma by Coagulation assay | 0.740 |  |
| 3029418 | Calcitonin [Mass/volume] in Serum or Plasma --7th specimen | 0.738 |  |
| 3002346 | Protein S [Units/volume] in Platelet poor plasma by Coagulation assay | 0.738 | 722 |
| 46235717 | Delta dRVVT [Time] in Platelet poor plasma by Coagulation assay | 0.738 |  |
| 40759285 | CYP2C9 gene allele 2 [Identifier] in Blood by Molecular genetics method Nominal | 0.738 |  |
| 3032955 | CPT2 gene p.Arg503Cys [Presence] in Blood by Molecular genetics method | 0.737 |  |
| 36660448 | Transthyretin peak 2 [Mass] in Blood | 0.737 |  |
| 3020665 | Protein C [Units/volume] in Platelet poor plasma by Coagulation assay | 0.736 | 1278 |
| 3046082 | Antithrombin Ag [Presence] in Platelet poor plasma by Immunoassay | 0.736 |  |
| 3014914 | Antithrombin [Moles/volume] in Platelet poor plasma by Chromogenic method | 0.736 |  |
| 21492381 | Fatty acid comprehensive (C8-C26) panel - Red Blood Cells | 0.735 |  |
| 36659679 | Transthyretin width at half peak height [Mass] in Blood | 0.735 |  |
| 3037053 | TTR gene allele 1 [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.735 |  |
| 3015449 | Antithrombin Ag [Moles/volume] in Platelet poor plasma by Immunoassay | 0.735 |  |
| 3008336 | Mefenamate [Mass/volume] in Serum or Plasma | 0.734 |  |
| 36660174 | Transthyretin - transthyretin peak 2 [Mass difference] in Blood | 0.734 |  |
| 3040747 | CPT2 gene p.Pro50His+Ser113Leu [Presence] in Blood or Tissue by Molecular genetics method | 0.734 |  |
| 3001122 | Ferritin [Mass/volume] in Serum or Plasma | 0.733 | 153 |
| 40762081 | FGB gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.733 |  |
| 3000288 | Sodium/Potassium [Molar ratio] in Serum or Plasma | 0.732 |  |
| 43055134 | VKORC1 gene c.1173C>T [Presence] in Blood or Tissue by Molecular genetics method | 0.732 |  |
| 3026785 | Coagulation factor VII activity actual/normal [Molar ratio] in Platelet poor plasma by Coagulation assay | 0.732 |  |
| 40759286 | CYP2C9 gene allele 3 [Identifier] in Blood by Molecular genetics method Nominal | 0.731 |  |
| 3025431 | Microscopic exam [Interpretation] of Sputum by Cytology | 0.731 |  |
| 3004313 | Fibronectin [Mass/volume] in Plasma | 0.730 |  |
| 40761582 | Protein S Ag/Coagulation factor IX Ag [Mass Ratio] in Platelet poor plasma by Immunoassay | 0.730 |  |
| 3038521 | CBS gene c.833T>C [Presence] in Blood or Tissue by Molecular genetics method | 0.729 |  |
| 3019599 | Protein S actual/normal in Platelet poor plasma by Chromogenic method | 0.729 | 1356 |
| 3007731 | Thyroxine (T4).prealbumin bound/Prealbumin [Mass Ratio] in Serum or Plasma | 0.729 |  |
| 3038971 | TH gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.729 |  |
| 3017523 | Thyroxine (T4)/Thyroxine binding globulin [Mass Ratio] in Serum or Plasma | 0.729 |  |
| 3011836 | F2 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.729 | 1056 |
| 40758373 | HPFH-6 gene [Presence] in Blood by Molecular genetics method | 0.728 |  |
| 40758376 | HBA1 gene c.223G>C [Presence] in Blood by Molecular genetics method | 0.727 |  |
| 42869549 | Maximum expiratory gas flow Respiratory system airway --pre therapy | 0.726 |  |
| 40757584 | Semen analysis test method | 0.726 |  |
| 40758366 | HBA2 gene c.427T>C [Presence] in Blood by Molecular genetics method | 0.726 |  |
| 1092115 | Hereditary thrombosis disorders multigene analysis in Blood by Molecular genetics method | 0.726 |  |
| 3021002 | Oxygen [Partial pressure] in Inhaled gas | 0.724 |  |
| 21490780 | Oxygen gas delivered during case [Volume] from Gas delivery system | 0.723 |  |
| 3041078 | Clot formation [Time] in Blood by Thromboelastography | 0.723 |  |
| 3041761 | VWF gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.723 |  |
| 3002022 | Protein C Ag actual/normal in Platelet poor plasma by Immunoassay | 0.722 | 1488 |
| 3032354 | APOE gene allele 2 [Identifier] in Blood or Tissue by Molecular genetics method | 0.722 |  |
| 3005470 | Maximum expiratory gas flow Respiratory system airway --post therapy | 0.721 |  |
| 1175473 | ITPA gene g.9330C>A [Type] in Serum or Plasma by Molecular genetics method | 0.720 |  |
| 3965213 | Electrolytes panel - Venous blood | 0.720 |  |
| 3044378 | FEV1 --10 minutes post exercise | 0.720 |  |
| 1989594 | Thrombotic microangiopathy multigene analysis in Blood or Tissue by Molecular genetics method | 0.720 |  |
| 3051719 | ITGA2B gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.719 |  |
| 3021114 | Thyroxine (T4).albumin bound/Albumin [Mass Ratio] in Serum or Plasma | 0.718 |  |
| 3037321 | TTR gene allele 2 [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.718 |  |
| 3040149 | CFH gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.717 |  |
| 3045930 | Fatty acid mitochondrial (C8-C18) panel - Serum or Plasma | 0.716 |  |
| 3023055 | Clot Lysis [Time] in Platelet poor plasma by Coagulation assay | 0.715 |  |
| 3050160 | 3-Hydroxy fatty acid panel - Serum or Plasma | 0.715 |  |
| 3046526 | FEV1 --5 minutes post exercise | 0.715 |  |
| 3001444 | Plasminogen activator tissue type Ag [Mass/volume] in Platelet poor plasma by Immunoassay | 0.715 |  |
| 3037122 | Plasminogen activator tissue type-Plasminogen activator inhibitor 1 complex [Mass/volume] in Platelet poor plasma by Immunoassay | 0.715 |  |
| 1175193 | ITPA gene g.9381A>C [Type] in Serum or Plasma by Molecular genetics method | 0.714 |  |
| 40763571 | Iron/Transferrin [Ratio] in Serum or Plasma | 0.712 |  |
| 3007405 | General categories [Interpretation] of Cervical or vaginal smear or scraping by Cyto stain | 0.711 |  |
| 3046362 | FEV1 --15 minutes post exercise | 0.711 |  |
| 44816654 | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum | 0.710 |  |
| 3031415 | COL3A1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.710 |  |
| 3043725 | Clot Lysis [Time] in Control Platelet poor plasma by Coagulation assay | 0.709 |  |
| 42868465 | Maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.709 |  |
| 3021182 | F7 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.709 |  |
| 3043574 | FEV1 --Pre excercise | 0.708 |  |
| 3024976 | Plasminogen Ag [Mass/volume] in Platelet poor plasma | 0.708 |  |
| 1001906 | CYP4F2 gene c.1297G>A [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.708 |  |
| 42528941 | Spontaneous clot formation [Time] in Platelet poor plasma | 0.708 |  |
| 3046729 | Fatty acid very long chain (C22-C26) panel - Serum or Plasma | 0.708 |  |
| 3017678 | Lecithin [Units/volume] in Amniotic fluid | 0.707 |  |
| 36659643 | Aldosterone and sodium panel - 24 hour Urine | 0.706 |  |
| 36303453 | Omega-3 (EPA+DHA) index in Serum or Plasma | 0.706 |  |
| 40761008 | Triiodothyronine (T3)/Triiodothyronine (T3).reverse [Ratio] in Serum or Plasma | 0.706 |  |
| 3027995 | Electrolytes 1998 panel - Serum or Plasma | 0.705 |  |
| 21492232 | Plethysmogram Arterial blood Pulse oximetry | 0.705 |  |
| 3011893 | Reptilase time in Platelet poor plasma from Control by Coagulation assay | 0.703 |  |
| 3010417 | Phosphatidylglycerol [Mass/volume] in Amniotic fluid | 0.703 |  |
| 21493451 | Spirometry panel | 0.702 |  |
| 3045149 | Reason for lab test in Semen | 0.702 |  |
| 3025763 | Microscopic exam [Interpretation] of Tissue fine needle aspirate by Cytology | 0.701 |  |
| 21490894 | Expiratory airway gas flow | 0.700 |  |
| 21490868 | Fatty acid oxidation panel - Fibroblast | 0.700 |  |
| 3024882 | Oxygen/Total gas setting [Volume Fraction] Ventilator | 0.698 | 457 |
| 3013833 | Plasminogen activator inhibitor 2 Ag [Mass/volume] in Platelet poor plasma by Immunoassay | 0.697 |  |
| 42868467 | Maximum expiratory gas flow/Predicted maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.697 |  |
| 3016706 | Plasminogen activator tissue type [Mass/volume] in Platelet poor plasma by Chromogenic method | 0.696 |  |
| 3033157 | Peak flow meter Vendor name | 0.696 |  |
| 3013585 | Phosphatidylglycerol [Units/volume] in Amniotic fluid | 0.695 |  |
| 3020692 | Microscopic exam [Interpretation] of Urine by Cytology | 0.695 | 163 |
| 3049717 | Cytology report of Urine Cyto stain | 0.695 |  |
| 46235080 | Noninvasive arteriosclerosis studies panel | 0.694 |  |
| 3041952 | Clot initiation [Time] in Blood by Thromboelastography | 0.693 |  |
| 3013528 | Clot Retraction [Time] in Blood by Coagulation assay | 0.692 |  |
| 3011305 | Lecithin/Sphingomyelin [Mass Ratio] in Amniotic fluid | 0.692 |  |
| 21491705 | Aldosterone and renin concentration panel - Plasma | 0.691 |  |
| 3002417 | Prothrombin time (PT) in Blood by Coagulation assay | 0.691 |  |
| 40762347 | Cytologist who read Cyto stain of Specimen | 0.688 |  |
| 3035904 | Lecithin/Sphingomyelin [Ratio] in Amniotic fluid | 0.687 | 1853 |
| 3051661 | Cytology report of Sputum Cyto stain | 0.687 |  |
| 3041070 | Clot formation [Time] in Blood by Thromboelastography.rotational.extrinsic coagulation system activated.fibrinolysis suppressed | 0.687 |  |
| 40762868 | Phosphatidylglycerol [Moles/volume] in Amniotic fluid | 0.686 |  |
| 3023329 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter | 0.686 |  |
| 40758281 | Aldosterone and renin activity panel - Plasma | 0.683 |  |
| 3031203 | Blood pressure panel | 0.682 |  |
| 3034016 | Peak flow meter Vendor model code | 0.682 |  |
| 646557 | Potassium [Measurement] in Serum or Plasma | 0.680 |  |
| 21490781 | Oxygen gas delivered.total [Volume] in Reporting period from Gas delivery system | 0.680 |  |
| 3044016 | Orthostatic blood pressure panel | 0.679 |  |
| 3036380 | Tidal volume expired/Peak inspiratory pressure --on ventilator | 0.677 |  |
| 3003246 | Oxygen [Partial pressure] in Exhaled gas | 0.676 |  |
| 21490696 | Oxygen [VFr/PPres] Gas delivery system | 0.676 |  |
| 3049411 | Cytology report of Body fluid Cyto stain | 0.674 |  |
| 3019858 | Maximum voluntary ventilation [Flow] --post bronchodilator/Voluntary ventilation.maximum predicted | 0.672 |  |
| 3043109 | Cytology report of Tissue fine needle aspirate Cyto stain | 0.671 | 943 |
| 42868464 | Maximum expiratory gas flow Respiratory system airway --pre bronchodilation | 0.671 |  |
| 3029849 | Lecithin/Surfactant.total in Amniotic fluid | 0.670 |  |
| 1761891 | Other cells [#/volume] in Amniotic fluid by Manual count | 0.670 |  |
| 3034996 | Type of Peak flow meter | 0.669 |  |
| 42528945 | Clot formation lag time in Platelet poor plasma | 0.667 |  |
| 3005308 | Reptilase time | 0.665 | 3000 |
| 3047332 | Spermatozoa IgA and IgG and IgM panel - Serum | 0.664 |  |
| 3027315 | Oxygen [Partial pressure] in Blood | 0.664 | 87 |
| 3034930 | Peak flow meter Vendor software version | 0.660 |  |
| 36031308 | Delta Coagulation [Time] in Platelet poor plasma by aPTT W excess hexagonal phase phospholipid | 0.652 |  |
| 40769396 | Normalized silica clotting time of Platelet poor plasma | 0.651 |  |
| 40765359 | PhenX - respiratory - peak expiratory flow rate - PEFR protocol 090801 | 0.649 |  |
| 3035969 | Recalcification time in Platelet poor plasma by Coagulation assay | 0.649 |  |
| 42870500 | Reptilase time actual/Normal | 0.649 | 3000 |
| 1617311 | Time to thrombin peak in Platelet poor plasma by Chromogenic method | 0.649 |  |
| 37020879 | Carbon monoxide [Mass/volume] in Air | 0.648 |  |
| 3005629 | Inhaled oxygen flow rate | 0.648 | 174 |
| 36305632 | Microbiology CNAMTS panel - Semen | 0.646 |  |
| 3028846 | Blood pressure device panel | 0.645 |  |
| 40758546 | Short blood pressure panel | 0.642 |  |
| 36306151 | Blood pressure with exercise and post exercise panel | 0.637 |  |
| 1259761 | Pulse pressure by Noninvasive | 0.633 |  |
| 21493953 | Tissue perfusion assessment panel | 0.632 |  |
| 21492238 | Blood pressure by Noninvasive | 0.627 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 333 | ab-na | mmol/l | 100% | name+unit+values | 1125 | 0 | [131.07, 134.74, 136.65, 138.04, 139.27, 140.42, 141.11, 142.54, 144.85] |  | Arterial blood | Native preparation | Sodium [Moles/volume] in Arterial blood |
| 334 | am-lamel | e9/l | 97% | name+unit+values | 327 | 0 | [8.22, 12.77, 17.47, 21.27, 27.86, 33.66, 40.76, 49.86, 62.49] | Am-Lamellaarikappaleet | Amniotic fluid |  | Lamellar Body [#/volume] in Amniotic fluid |
| 335 | am-lamel |  | 3% | name | 10 | 100 |  | Am-Lamellaarikappaleet | Amniotic fluid |  | Lamellar Body [#/volume] in Amniotic fluid |
| 336 | ap-lakt | mmol/l | 99% | name+unit+values | 1456 | 0 | [0.69, 0.81, 0.96, 1.1, 1.28, 1.51, 1.82, 2.3, 3.23] |  |  |  | Lactate [Moles/volume] in Arterial plasma |
| 337 | ap-lakt |  | 1% | name | 18 | 100 |  |  |  |  | Lactate [Moles/volume] in Arterial plasma |
| 338 | ap-na | mmol/l | 100% | name+unit+values | 50270 | 0.07 | [130.69, 133.39, 134.98, 136, 136.99, 137.94, 138.91, 139.95, 141.72] |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma |
| 339 | ap-na |  | 0% | name | 233 | 100 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma |
| 340 | ap-nak |  | 100% | name | 155 | 100 |  |  |  |  | Sodium and Potassium panel - Arterial plasma |
| 341 | b-na | mmol/l | 86% | name+unit+values | 59360 | 0 | [132.83, 135.08, 136.5, 137.68, 138.42, 139.02, 140.21, 141.76, 144.07] |  | Blood | Native preparation | Sodium [Moles/volume] in Blood |
| 342 | b-na |  | 14% | name+values | 9740 | 100 | [132, 135.65, 137.06, 138.86, 139, 140, 140.25, 141, 142] |  | Blood | Native preparation | Sodium [Moles/volume] in Blood |
| 343 | cp-na | mmol/l | 94% | name+unit+values | 305 | 0 | [132, 134.13, 135.88, 137, 138, 139.24, 140, 141.93, 143] |  |  | Native preparation | Sodium [Moles/volume] in Capillary plasma |
| 344 | cp-na |  | 6% | name | 18 | 100 |  |  |  | Native preparation | Sodium [Moles/volume] in Capillary plasma |
| 345 | di-na | mmol/l | 100% | name+unit | 307 | 0 |  | Di-Natrium | Dialysis fluid | Native preparation | Sodium [Moles/volume] in Dialysis fluid |
| 346 | du-na | mmol/24h | 74% | name+unit+values | 2845 | 0 | [76.9, 98.34, 115.34, 133.54, 151.44, 169.81, 193.27, 222.7, 272.41] | dU-Natrium | 24-hour urine | Native preparation | Sodium [Moles/time] in 24 hour Urine |
| 347 | du-na |  | 26% | name+values | 1021 | 100 | [65.99, 83.48, 103.21, 117.93, 138.14, 155.68, 172.4, 209.91, 273.5] | dU-Natrium | 24-hour urine | Native preparation | Sodium [Moles/time] in 24 hour Urine |
| 348 | fp-alat | u/l | 100% | name+unit+values | 1830 | 0 | [14.7, 17.39, 20.07, 22.45, 25.26, 29.41, 34.57, 41.87, 57.54] |  | Fasting plasma |  | Alanine aminotransferase [Enzymatic activity/volume] in Plasma |
| 349 | fp-ctx | ng/l | 2% | name+unit | 34 | 0 |  |  | Fasting plasma |  | Collagen type I C-terminal telopeptide [Mass/volume] in Plasma |
| 350 | fp-ctx | ug/l | 71% | name+unit+values | 1281 | 0.23 | [0.09, 0.14, 0.2, 0.25, 0.3, 0.38, 0.48, 0.61, 0.81] |  | Fasting plasma |  | Collagen type I C-terminal telopeptide [Mass/volume] in Plasma |
| 351 | fp-ctx |  | 27% | name+values | 491 | 100 | [0.12, 0.19, 0.26, 0.33, 0.42, 0.53, 0.63, 0.85, 1.5] |  | Fasting plasma |  | Collagen type I C-terminal telopeptide [Mass/volume] in Plasma |
| 352 | fp-gt | u/l | 99% | name+unit+values | 772 | 0 | [15.59, 19.58, 23.9, 27.78, 33.1, 39.95, 49.61, 68.78, 105.4] |  | Fasting plasma |  | Gamma glutamyltransferase [Enzymatic activity/volume] in Plasma |
| 353 | fp-gt |  | 1% | name | 11 | 100 |  |  | Fasting plasma |  | Gamma glutamyltransferase [Enzymatic activity/volume] in Plasma |
| 354 | fp-na | mmol/l | 100% | name+unit+values | 6047 | 0 | [135.62, 137.92, 138.99, 139.97, 140.04, 141, 141.08, 142, 143] |  | Fasting plasma | Native preparation | Sodium [Moles/volume] in Plasma |
| 355 | fp-na |  | 0% | name | 18 | 100 |  |  | Fasting plasma | Native preparation | Sodium [Moles/volume] in Plasma |
| 356 | happi | % | 48% | name+unit+values | 838 | 0.24 | [25.89, 29.25, 34.66, 40, 44.71, 48.76, 54.72, 63.33, 83.17] |  |  |  | Oxygen saturation [Volume Fraction] in Blood |
| 357 | happi | l | 8% | name+unit+values | 132 | 0 | [1, 1.5, 2, 2, 2, 2.93, 3, 3.9, 6.43] |  |  |  | Oxygen [Volume] in Gas |
| 358 | happi | l/min | 0% | name+unit | 6 | 0 |  |  |  |  | Oxygen [Volume/time] in Gas |
| 359 | happi |  | 44% | name | 774 | 100 |  |  |  |  | Oxygen saturation [Volume Fraction] in Blood |
| 360 | j-papa |  | 100% | name | 183 | 100 |  |  |  |  | Cytology [Interpretation] of Specimen by Papanicolaou stain |
| 361 | p-acth | ng/l | 87% | name+unit+values | 10045 | 0 | [8.1, 11.17, 14.07, 17.18, 20.62, 24.78, 30.97, 40.56, 66.81] | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone [Mass/volume] in Plasma |
| 362 | p-acth | pmol/l | 0% | name+unit | 7 | 0 |  | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone [Moles/volume] in Plasma |
| 363 | p-acth |  | 13% | name+values | 1461 | 100 | [9.3, 12.05, 15.2, 18.33, 23.32, 27.18, 33.07, 40.35, 63.93] | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone [Mass/volume] in Plasma |
| 364 | p-alat | u/l | 97% | name+unit+values | 4827160 | 0 | [12.96, 15.82, 18.44, 20.97, 24.18, 27.92, 33.04, 41.55, 60.15] | P -Alaniiniaminotransferaasi | Plasma |  | Alanine aminotransferase [Enzymatic activity/volume] in Plasma |
| 365 | p-alat | umol/l | 0% | name+unit | 23 | 0 |  | P -Alaniiniaminotransferaasi | Plasma |  | Alanine aminotransferase [Enzymatic activity/volume] in Plasma |
| 366 | p-alat |  | 3% | name | 133418 | 100 |  | P -Alaniiniaminotransferaasi | Plasma |  | Alanine aminotransferase [Enzymatic activity/volume] in Plasma |
| 367 | p-alat. | u/l | 99% | name+unit+values | 896 | 0 | [12.41, 15.26, 17.78, 20.06, 22.46, 25.38, 29.04, 35.69, 47.17] |  | Plasma |  | Alanine aminotransferase [Enzymatic activity/volume] in Plasma |
| 368 | p-alat. |  | 1% | name | 10 | 100 |  |  | Plasma |  | Alanine aminotransferase [Enzymatic activity/volume] in Plasma |
| 369 | p-asat | u/l | 97% | name+unit+values | 466423 | 0 | [16.61, 19.52, 21.89, 24.36, 26.99, 30.42, 35.39, 44.79, 70.46] | P -Aspartaattiaminotransferaasi | Plasma |  | Aspartate aminotransferase [Enzymatic activity/volume] in Plasma |
| 370 | p-asat | umol/l | 0% | name+unit+values | 215 | 0 | [17.67, 20, 22.09, 24.95, 26.7, 28.89, 32.58, 37.69, 51.22] | P -Aspartaattiaminotransferaasi | Plasma |  | Aspartate aminotransferase [Enzymatic activity/volume] in Plasma |
| 371 | p-asat |  | 3% | name | 14767 | 100 |  | P -Aspartaattiaminotransferaasi | Plasma |  | Aspartate aminotransferase [Enzymatic activity/volume] in Plasma |
| 372 | p-at3 | % | 98% | name+unit+values | 33387 | 0 | [53.99, 67.43, 77.05, 84.9, 91.49, 97.39, 103.39, 110.16, 119.61] | P -Antitrombiini III | Plasma |  | Antithrombin III [Ratio] in Plasma |
| 373 | p-at3 | form | 0% | name+unit | 18 | 0 |  | P -Antitrombiini III | Plasma |  | Antithrombin III gene [Identifier] in Blood by Molecular genetics method |
| 374 | p-at3 |  | 2% | name+values | 750 | 100 | [77.31, 88.51, 92.97, 98.3, 102.33, 106.75, 110.2, 114.52, 120] | P -Antitrombiini III | Plasma |  | Antithrombin III [Ratio] in Plasma |
| 375 | p-at3. | % | 95% | name+unit+values | 4852 | 0 | [82.69, 90.71, 95.75, 100.16, 103.96, 107.71, 111.91, 117.1, 124.45] |  | Plasma |  | Antithrombin III [Ratio] in Plasma |
| 376 | p-at3. |  | 5% | name+values | 269 | 100 | [87.62, 92.42, 97.42, 100.6, 104.78, 109, 113.23, 117.65, 123.61] |  | Plasma |  | Antithrombin III [Ratio] in Plasma |
| 377 | p-efa |  | 100% | name | 125 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  | Essential fatty acids panel - Plasma |
| 378 | p-fakb | g/l | 77% | name+unit+values | 120 | 0 | [0.14, 0.16, 0.18, 0.2, 0.21, 0.21, 0.23, 0.26, 0.3] | P -Faktori B | Plasma |  | Coagulation factor B [Mass/volume] in Plasma |
| 379 | p-fakb |  | 23% | name | 35 | 100 |  | P -Faktori B | Plasma |  | Coagulation factor B [Mass/volume] in Plasma |
| 380 | p-fe | umol/l | 79% | name+unit+values | 2840 | 0 | [5.54, 7.67, 9.48, 11.27, 13.17, 14.88, 16.93, 19.43, 23.36] |  | Plasma |  | Iron [Moles/volume] in Plasma |
| 381 | p-fe |  | 21% | name+values | 740 | 100 | [5.17, 6.79, 8.59, 10.13, 12.1, 14.06, 16.49, 19.49, 23.47] |  | Plasma |  | Iron [Moles/volume] in Plasma |
| 382 | p-fs | s | 17% | name+unit+values | 319 | 0 | [28, 29.37, 30.81, 32, 33.25, 34.95, 36.52, 39.34, 45.23] |  | Plasma |  | Coagulation screen [Time] in Plasma |
| 383 | p-fs |  | 83% | name | 1586 | 100 |  |  | Plasma |  | Coagulation screen [Time] in Plasma |
| 384 | p-fv | % | 96% | name+unit+values | 6911 | 0.03 | [43.57, 58.38, 70.05, 80.34, 90.27, 99.83, 110.54, 122.66, 139.92] | P -Hyytymistekijä V | Plasma |  | Coagulation factor V [Ratio] in Plasma |
| 385 | p-fv |  | 4% | name+values | 261 | 100 | [69.88, 80.83, 88.32, 96.16, 100.54, 105.37, 112.35, 122.09, 134.3] | P -Hyytymistekijä V | Plasma |  | Coagulation factor V [Ratio] in Plasma |
| 386 | p-fx | % | 49% | name+unit+values | 916 | 0.22 | [45.39, 65.84, 76.4, 83.62, 90.78, 97.89, 105.11, 112.7, 123.23] | P -Hyytymistekijä X | Plasma |  | Coagulation factor X [Ratio] in Plasma |
| 387 | p-fx |  | 51% | name+values | 949 | 100 | [66, 78.85, 83.42, 90.36, 95.2, 99.28, 105.22, 113.1, 120.2] | P -Hyytymistekijä X | Plasma |  | Coagulation factor X [Ratio] in Plasma |
| 388 | p-gt | mg/ml | 0% | name+unit | 8 | 0 |  | P -Glutamyylitransferaasi | Plasma |  | Gamma glutamyltransferase [Mass/volume] in Plasma |
| 389 | p-gt | u/l | 98% | name+unit+values | 820178 | 0 | [14.61, 18.77, 23.38, 29.11, 36.97, 48.58, 67.09, 102.78, 197.74] | P -Glutamyylitransferaasi | Plasma |  | Gamma glutamyltransferase [Enzymatic activity/volume] in Plasma |
| 390 | p-gt |  | 2% | name | 15977 | 100 |  | P -Glutamyylitransferaasi | Plasma |  | Gamma glutamyltransferase [Enzymatic activity/volume] in Plasma |
| 391 | p-k+na |  | 100% | name | 69230 | 100 |  |  | Plasma |  | Potassium and Sodium panel - Plasma |
| 392 | p-k,na |  | 100% | name | 2518 | 100 |  |  | Plasma |  | Potassium and Sodium panel - Plasma |
| 393 | p-k-na | mmol/l | 76% | name+unit | 594 | 0 |  |  | Plasma | Native preparation | Potassium and Sodium panel - Plasma |
| 394 | p-k-na |  | 24% | name | 186 | 100 |  |  | Plasma | Native preparation | Potassium and Sodium panel - Plasma |
| 395 | p-k-pa | mmol/l | 100% | name+unit+values | 197 | 0 | [3.52, 3.78, 3.9, 3.99, 4.05, 4.12, 4.3, 4.38, 4.56] |  | Plasma | Long-term / prolonged | Potassium [Moles/volume] in Plasma |
| 396 | p-k/na |  | 100% | name | 321 | 100 |  |  | Plasma |  | Potassium and Sodium panel - Plasma |
| 397 | p-ked. | mmol/l | 100% | name+unit | 344 | 0 |  |  | Plasma |  | Potassium [Moles/volume] in Plasma --pre dialysis |
| 398 | p-kjd. | mmol/l | 100% | name+unit | 160 | 0 |  |  | Plasma |  | Potassium [Moles/volume] in Plasma --post dialysis |
| 399 | p-la1 | s | 95% | name+unit+values | 1064 | 0 | [30.03, 32, 33.13, 34.76, 36.01, 37.8, 39.95, 44.95, 54.82] |  | Plasma |  | Lupus anticoagulant screen [Time] in Platelet poor plasma |
| 400 | p-la1 |  | 5% | name | 52 | 100 |  |  | Plasma |  | Lupus anticoagulant screen [Time] in Platelet poor plasma |
| 401 | p-la2 | s | 26% | name+unit+values | 498 | 0 | [32, 33.5, 35.52, 37, 38.95, 40.99, 43.05, 47.4, 53.69] |  | Plasma |  | Lupus anticoagulant confirm [Time] in Platelet poor plasma |
| 402 | p-la2 |  | 74% | name | 1411 | 100 |  |  | Plasma |  | Lupus anticoagulant confirm [Time] in Platelet poor plasma |
| 403 | p-laite | ug/l | 100% | name+unit+values | 106 | 0 | [2.9, 3.2, 3.49, 3.68, 4.03, 4.44, 5.31, 6.24, 7.96] |  | Plasma |  | Lamotrigine [Mass/volume] in Plasma |
| 404 | p-lam/m |  | 100% | name+values | 1896 | 100 | [1.02, 1.07, 1.11, 1.14, 1.16, 1.19, 1.21, 1.24, 1.28] |  | Plasma |  | Lupus anticoagulant mix [Ratio] in Platelet poor plasma |
| 405 | p-mypa | mg/l | 87% | name+unit+values | 1692 | 0 | [0.63, 0.99, 1.33, 1.71, 2.12, 2.67, 3.43, 4.41, 6.29] | P -Mykofenolihappo | Plasma |  | Mycophenolic acid [Mass/volume] in Plasma |
| 406 | p-mypa |  | 13% | name | 245 | 100 |  | P -Mykofenolihappo | Plasma |  | Mycophenolic acid [Mass/volume] in Plasma |
| 407 | p-na | mmol/ | 0% | name+unit | 14 | 0 |  | P -Natrium | Plasma | Native preparation | Sodium [Moles/volume] in Plasma |
| 408 | p-na | mmol/l | 99% | name+unit+values | 7320578 | 0 | [134.08, 136.46, 137.96, 139, 139.93, 140.11, 141, 142, 143] | P -Natrium | Plasma | Native preparation | Sodium [Moles/volume] in Plasma |
| 409 | p-na |  | 1% | name | 81059 | 100 |  | P -Natrium | Plasma | Native preparation | Sodium [Moles/volume] in Plasma |
| 410 | p-na. | mmol/l | 100% | name+unit+values | 1467 | 0 | [134.62, 137, 138.31, 139.89, 140.56, 141, 142, 142.86, 144] |  | Plasma |  | Sodium [Moles/volume] in Plasma |
| 411 | p-na: | mmol/l | 100% | name+unit+values | 621 | 0 | [131.69, 133.81, 135, 136.19, 137.81, 138.69, 139.63, 140.92, 142] |  | Plasma |  | Sodium [Moles/volume] in Plasma |
| 412 | p-naed. | mmol/l | 100% | name+unit | 306 | 0 |  |  | Plasma |  | Sodium [Moles/volume] in Plasma --pre dialysis |
| 413 | p-najd. | mmol/l | 100% | name+unit | 154 | 0 |  |  | Plasma |  | Sodium [Moles/volume] in Plasma --post dialysis |
| 414 | p-nak |  | 100% | name | 259040 | 100 |  |  | Plasma |  | Sodium and Potassium panel - Plasma |
| 415 | p-nap | mmol/l | 100% | name+unit+values | 342 | 0.29 | [132.72, 135.18, 137.36, 139, 140, 140.67, 141.97, 143, 145] |  | Plasma |  | Sodium [Moles/volume] in Plasma |
| 416 | p-pc | % | 90% | name+unit+values | 7171 | 0 | [82.04, 95.56, 103.31, 110.09, 116.75, 123.11, 129.91, 139.06, 152.29] | P -Proteiini C | Plasma |  | Protein C functional [Ratio] in Plasma |
| 417 | p-pc | form | 0% | name+unit | 12 | 0 |  | P -Proteiini C | Plasma |  | Protein C gene [Identifier] in Blood by Molecular genetics method |
| 418 | p-pc |  | 10% | name+values | 763 | 100 | [85.52, 97.63, 105.02, 110.24, 116.71, 123.09, 130.39, 139.57, 155.46] | P -Proteiini C | Plasma |  | Protein C functional [Ratio] in Plasma |
| 419 | p-pct | ng/ml | 5% | name+unit+values | 1499 | 0 | [0.1, 0.1, 0.2, 0.28, 0.4, 0.64, 1.17, 2.72, 8.99] | P -Prokalsitoniini | Plasma |  | Procalcitonin [Mass/volume] in Plasma |
| 420 | p-pct | ug/l | 91% | name+unit+values | 25253 | 0 | [0.07, 0.1, 0.13, 0.18, 0.26, 0.4, 0.68, 1.41, 5.19] | P -Prokalsitoniini | Plasma |  | Procalcitonin [Mass/volume] in Plasma |
| 421 | p-pct |  | 4% | name | 1082 | 100 |  | P -Prokalsitoniini | Plasma |  | Procalcitonin [Mass/volume] in Plasma |
| 422 | p-pi | mmol/l | 99% | name+unit+values | 186393 | 0 | [0.74, 0.87, 0.96, 1.05, 1.13, 1.23, 1.34, 1.5, 1.79] | P -Fosfaatti, epäorgaaninen | Plasma |  | Phosphate [Moles/volume] in Plasma |
| 423 | p-pi |  | 1% | name | 2732 | 100 |  | P -Fosfaatti, epäorgaaninen | Plasma |  | Phosphate [Moles/volume] in Plasma |
| 424 | p-prl | mu/l | 98% | name+unit+values | 10459 | 0 | [139.86, 185.19, 223.46, 260.99, 305.79, 361.97, 438.81, 570.22, 911.44] | P -Prolaktiini | Plasma |  | Prolactin [Units/volume] in Plasma |
| 425 | p-prl | nmol/l | 0% | name+unit | 16 | 0 |  | P -Prolaktiini | Plasma |  | Prolactin [Moles/volume] in Plasma |
| 426 | p-prl |  | 2% | name | 162 | 100 |  | P -Prolaktiini | Plasma |  | Prolactin [Units/volume] in Plasma |
| 427 | p-ps | % | 79% | name+unit+values | 1651 | 0 | [65.21, 76.7, 83.61, 90.03, 95.98, 101.09, 108.67, 116.41, 129.83] | P -Proteiini S | Plasma | Basic screening | Protein S functional [Ratio] in Plasma |
| 428 | p-ps |  | 21% | name+values | 443 | 100 | [67.73, 78.79, 88.29, 94.24, 100.12, 106.66, 112.61, 120.5, 131.45] | P -Proteiini S | Plasma | Basic screening | Protein S functional [Ratio] in Plasma |
| 429 | p-psa | ug/l | 88% | name+unit+values | 440363 | 0 | [0.27, 0.54, 0.84, 1.21, 1.72, 2.49, 3.62, 5.6, 9.72] | P -Prostataspesifinen antigeeni | Plasma |  | Prostate specific Ag [Mass/volume] in Plasma |
| 430 | p-psa |  | 12% | name | 61308 | 100 |  | P -Prostataspesifinen antigeeni | Plasma |  | Prostate specific Ag [Mass/volume] in Plasma |
| 431 | p-pt | s | 100% | name+unit | 184 | 0 |  |  | Plasma |  | Prothrombin time (PT) [Time] in Platelet poor plasma |
| 432 | p-rvvt-l |  | 100% | name | 1894 | 100 |  |  | Plasma |  | Russell viper venom time [Time] in Platelet poor plasma |
| 433 | p-supar | ug/l | 96% | name+unit+values | 351 | 0 | [2.88, 3.25, 3.62, 3.93, 4.32, 4.72, 5.27, 6.34, 8.2] |  | Plasma |  | Urokinase plasminogen activator R.soluble [Mass/volume] in Plasma |
| 434 | p-supar |  | 4% | name | 16 | 100 |  |  | Plasma |  | Urokinase plasminogen activator R.soluble [Mass/volume] in Plasma |
| 435 | p-tfr | mg/l | 92% | name+unit+values | 188406 | 0 | [0.9, 1.59, 2.26, 2.65, 3.02, 3.46, 4.03, 4.87, 6.51] | P -Transferriinireseptori, liukoinen | Plasma |  | Transferrin receptor.soluble [Mass/volume] in Plasma |
| 436 | p-tfr |  | 8% | name | 15951 | 100 |  | P -Transferriinireseptori, liukoinen | Plasma |  | Transferrin receptor.soluble [Mass/volume] in Plasma |
| 437 | p-tt | % | 99% | name+unit+values | 472003 | 0 | [50.27, 64.91, 74.21, 81.59, 88.34, 94.66, 101.65, 109.8, 121.37] | P -Tromboplastiiniaika | Plasma |  | Prothrombin time (PT) [Ratio] in Platelet poor plasma |
| 438 | p-tt | form | 0% | name+unit | 20 | 0 |  | P -Tromboplastiiniaika | Plasma |  | Coagulation factor II gene [Identifier] in Blood by Molecular genetics method |
| 439 | p-tt |  | 1% | name | 4462 | 100 |  | P -Tromboplastiiniaika | Plasma |  | Prothrombin time (PT) [Ratio] in Platelet poor plasma |
| 440 | p-tt- | % | 98% | name+unit+values | 1432 | 0 | [60.41, 72.11, 78.26, 83.23, 88.7, 95.38, 102.26, 111.84, 122.4] |  | Plasma |  | Prothrombin time (PT) [Ratio] in Platelet poor plasma |
| 441 | p-tt- |  | 2% | name | 29 | 100 |  |  | Plasma |  | Prothrombin time (PT) [Ratio] in Platelet poor plasma |
| 442 | p-tt. | % | 94% | name+unit+values | 5628 | 0 | [63.23, 78.72, 87.03, 93.55, 99.79, 105.77, 112.44, 119.67, 130.79] |  | Plasma |  | Prothrombin time (PT) [Ratio] in Platelet poor plasma |
| 443 | p-tt. |  | 6% | name+values | 328 | 100 | [49.07, 79.43, 90.33, 98.82, 106.71, 114.28, 121.35, 130.68, 140.29] |  | Plasma |  | Prothrombin time (PT) [Ratio] in Platelet poor plasma |
| 444 | p-ttr | % | 93% | name+unit+values | 1114 | 0 | [50.96, 61.18, 67.8, 73.84, 78.53, 83.21, 89.2, 95.05, 100] |  | Plasma |  | Transthyretin [Ratio] in Plasma |
| 445 | p-ttr |  | 7% | name | 89 | 100 |  |  | Plasma |  | Transthyretin [Ratio] in Plasma |
| 446 | papa |  | 100% | name | 1138 | 100 |  |  |  |  | Cytology [Interpretation] of Specimen by Papanicolaou stain |
| 447 | pdgfr |  | 100% | name | 461 | 100 |  |  |  |  | PDGFRA gene mutation analysis in Blood or Tissue by Molecular genetics method |
| 448 | peak | l/min | 10% | name+unit | 12 | 0 |  |  |  |  | Expiratory flow.peak [Volume/time] |
| 449 | peak |  | 90% | name | 104 | 100 |  |  |  |  | Expiratory flow.peak [Volume/time] |
| 450 | pef-pa |  | 100% | name | 7844 | 100 |  | Uloshengityksen huippuvirtaus, sarjamittaus, pitkäaikaisseuranta |  | Long-term / prolonged | Peak expiratory flow rate home monitoring panel |
| 451 | pef-ras |  | 100% | name | 242 | 100 |  | Uloshengityksen huippuvirtaus, sarjamittaus, rasituskoe |  |  | Expiratory flow.peak [Volume/time] --pre exercise and post exercise |
| 452 | pf-ace | u/l | 66% | name+unit+values | 313 | 0.32 | [6.33, 10.32, 12.86, 15.39, 17.8, 19.84, 24.02, 28.69, 37.34] | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid |
| 453 | pf-ace |  | 34% | name | 161 | 100 |  | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid |
| 454 | pf-ada | u/l | 91% | name+unit+values | 3550 | 0 | [3.68, 5.17, 6.79, 8.03, 9.48, 11.18, 13.51, 17.41, 25.63] | Pf-Adenosiinideaminaasi | Pleural fluid |  | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid |
| 455 | pf-ada |  | 9% | name | 365 | 100 |  | Pf-Adenosiinideaminaasi | Pleural fluid |  | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid |
| 456 | pipelle |  | 100% | name | 428 | 100 |  |  |  |  | Microscopic observation [Identifier] in Endometrium by Histology |
| 457 | pneag |  | 100% | name | 244 | 100 |  |  |  |  | Streptococcus pneumoniae antigen [Presence] in Urine |
| 458 | pt-ivfal |  | 100% | name | 165 | 100 |  |  | Patient |  |  |
| 459 | pt-vp-ple |  | 100% | name | 102 | 100 |  |  | Patient |  | Arterial pressure and Blood flow study panel by Plethysmography |
| 460 | s-alat | iu/l | 0% | name+unit+values | 251 | 0 | [13.21, 15.82, 17.12, 19.56, 22, 24.18, 28.14, 35.6, 55.67] | S -Alaniiniaminotransferaasi | Serum |  | Alanine aminotransferase [Enzymatic activity/volume] in Serum |
| 461 | s-alat | u/l | 99% | name+unit+values | 323441 | 0 | [13.96, 17.08, 19.84, 22.78, 26.1, 30.03, 35.11, 42.65, 57.13] | S -Alaniiniaminotransferaasi | Serum |  | Alanine aminotransferase [Enzymatic activity/volume] in Serum |
| 462 | s-alat |  | 1% | name+values | 4631 | 100 | [14.16, 17.24, 20.69, 23.7, 27.55, 33.68, 39.69, 48.95, 68.13] | S -Alaniiniaminotransferaasi | Serum |  | Alanine aminotransferase [Enzymatic activity/volume] in Serum |
| 463 | s-asat | iu/l | 1% | name+unit+values | 247 | 0 | [18, 20.05, 21.99, 23.65, 25, 27.54, 29.68, 34.42, 41.57] | S -Aspartaattiaminotransferaasi | Serum |  | Aspartate aminotransferase [Enzymatic activity/volume] in Serum |
| 464 | s-asat | u/l | 98% | name+unit+values | 22999 | 0 | [17.95, 20.33, 22.41, 24.42, 26.51, 29.05, 32.45, 37.78, 49.76] | S -Aspartaattiaminotransferaasi | Serum |  | Aspartate aminotransferase [Enzymatic activity/volume] in Serum |
| 465 | s-asat |  | 1% | name+values | 171 | 100 | [18, 19, 22, 24, 24.5, 25.75, 29, 35, 49] | S -Aspartaattiaminotransferaasi | Serum |  | Aspartate aminotransferase [Enzymatic activity/volume] in Serum |
| 466 | s-na | mmol/l | 99% | name+unit+values | 124118 | 0 | [137.11, 138.74, 139.05, 140, 140.15, 141, 141.38, 142, 143] | S -Natrium | Serum | Native preparation | Sodium [Moles/volume] in Serum |
| 467 | s-na |  | 1% | name+values | 931 | 100 | [133.78, 137, 138.07, 139, 140, 140, 140.93, 141, 142.02] | S -Natrium | Serum | Native preparation | Sodium [Moles/volume] in Serum |
| 468 | s-prl | miu/l | 5% | name+unit+values | 1647 | 0 | [99, 122.35, 142.41, 160.53, 182.22, 206.49, 242.23, 297.21, 453.2] | S -Prolaktiini | Serum |  | Prolactin [Units/volume] in Serum |
| 469 | s-prl | mu/l | 93% | name+unit+values | 31229 | 0 | [116.54, 154.56, 187.96, 224.2, 266.24, 319.79, 396.49, 532.56, 848.45] | S -Prolaktiini | Serum |  | Prolactin [Units/volume] in Serum |
| 470 | s-prl | mul/l | 0% | name+unit | 6 | 0 |  | S -Prolaktiini | Serum |  | Prolactin [Units/volume] in Serum |
| 471 | s-prl | nmol/l | 0% | name+unit | 58 | 0 |  | S -Prolaktiini | Serum |  | Prolactin [Moles/volume] in Serum |
| 472 | s-prl |  | 2% | name | 718 | 100 |  | S -Prolaktiini | Serum |  | Prolactin [Units/volume] in Serum |
| 473 | s-psa | mg/l | 0% | name+unit | 7 | 0 |  | S -Prostataspesifinen antigeeni | Serum |  | Prostate specific Ag [Mass/volume] in Serum |
| 474 | s-psa | ug/l | 95% | name+unit+values | 91718 | 0 | [0.38, 0.57, 0.75, 0.96, 1.25, 1.64, 2.26, 3.32, 5.46] | S -Prostataspesifinen antigeeni | Serum |  | Prostate specific Ag [Mass/volume] in Serum |
| 475 | s-psa |  | 5% | name | 4826 | 100 |  | S -Prostataspesifinen antigeeni | Serum |  | Prostate specific Ag [Mass/volume] in Serum |
| 476 | s-tfr | mg | 0% | name+unit | 7 | 0 |  | S -Transferriinireseptori, liukoinen | Serum |  | Transferrin receptor.soluble [Mass/volume] in Serum |
| 477 | s-tfr | mg/l | 98% | name+unit+values | 77760 | 0 | [1.01, 1.24, 1.52, 1.93, 2.39, 2.84, 3.37, 4.15, 5.68] | S -Transferriinireseptori, liukoinen | Serum |  | Transferrin receptor.soluble [Mass/volume] in Serum |
| 478 | s-tfr |  | 2% | name | 1379 | 100 |  | S -Transferriinireseptori, liukoinen | Serum |  | Transferrin receptor.soluble [Mass/volume] in Serum |
| 479 | sp-pak |  | 100% | name | 196 | 100 |  |  | Sperm / semen |  | Semen analysis panel |
| 480 | sp-pakd |  | 100% | name | 138 | 100 |  |  | Sperm / semen |  | Semen analysis panel |
| 481 | u-na | mmol/l | 77% | name+unit+values | 8969 | 0 | [24.77, 32.46, 40.33, 48.4, 57.48, 68.26, 81.68, 99.24, 129.77] | U -Natrium | Urine | Native preparation | Sodium [Moles/volume] in Urine |
| 482 | u-na |  | 23% | name+values | 2662 | 100 | [27.31, 35.62, 42.78, 51.38, 60.48, 68.93, 78.14, 92.21, 110.65] | U -Natrium | Urine | Native preparation | Sodium [Moles/volume] in Urine |
| 483 | v-na |  | 100% | name+values | 265 | 100 | [130.07, 134.25, 136, 137.63, 138.47, 139, 140, 141, 142] |  |  | Native preparation | Sodium [Moles/volume] in Blood |
| 484 | vp-na | mmol/l | 98% | name+unit+values | 10896 | 0 | [132.88, 135.36, 136.91, 137.97, 139, 139.83, 140.33, 141.06, 142.5] |  |  | Native preparation | Sodium [Moles/volume] in Plasma |
| 485 | vp-na |  | 2% | name | 174 | 100 |  |  |  | Native preparation | Sodium [Moles/volume] in Plasma |
| 486 | vp-ple |  | 100% | name | 725 | 100 |  | Valtimopaine ja verenvirtaus, pletysmografi |  |  | Arterial pressure and Blood flow study panel by Plethysmography |

