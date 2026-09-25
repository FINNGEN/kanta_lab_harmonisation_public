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
Here is group 105.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000905 | Leukocytes [#/volume] in Blood by Automated count | 1.000 | 15 |
| 3000963 | Hemoglobin [Mass/volume] in Blood | 1.000 | 2 |
| 3004327 | Lymphocytes [#/volume] in Blood by Automated count | 1.000 | 35 |
| 3013429 | Basophils [#/volume] in Blood by Automated count | 1.000 | 27 |
| 3013650 | Neutrophils [#/volume] in Blood by Automated count | 1.000 | 46 |
| 3020416 | Erythrocytes [#/volume] in Blood by Automated count | 1.000 | 9 |
| 3024929 | Platelets [#/volume] in Blood by Automated count | 1.000 | 18 |
| 3028615 | Eosinophils [#/volume] in Blood by Automated count | 1.000 | 50 |
| 3033575 | Monocytes [#/volume] in Blood by Automated count | 1.000 | 52 |
| 3041084 | Immature granulocytes [#/volume] in Blood by Automated count | 1.000 |  |
| 3023314 | Hematocrit [Volume Fraction] of Blood by Automated count | 0.987 | 14 |
| 42869588 | Hematocrit [Pure volume fraction] of Blood by Automated count | 0.953 |  |
| 3016682 | Platelets [#/volume] in Plasma by Automated count | 0.945 |  |
| 3009932 | Eosinophils [#/volume] in Blood by Manual count | 0.940 |  |
| 40760140 | CBC W Auto Differential panel - Blood | 0.939 |  |
| 3040168 | Immature granulocytes [#/volume] in Blood | 0.938 |  |
| 3027651 | Basophils [#/volume] in Blood by Manual count | 0.938 |  |
| 1616298 | Platelets [#/volume] in Blood by Automated count.optical | 0.937 |  |
| 3034107 | Monocytes [#/volume] in Blood by Manual count | 0.933 | 472 |
| 3003159 | Erythrocytes [#/volume] in Body fluid by Automated count | 0.929 | 1726 |
| 3010457 | Eosinophils/Leukocytes in Blood by Automated count | 0.925 | 43 |
| 3003215 | Lymphocytes [#/volume] in Blood by Manual count | 0.925 |  |
| 3006696 | Leukocytes [#/volume] in Specimen by Automated count | 0.924 |  |
| 3028022 | Lymphocytes [#/volume] in Specimen by Automated count | 0.923 |  |
| 3002385 | Erythrocyte distribution width [Ratio] | 0.922 |  |
| 3006315 | Basophils [#/volume] in Blood | 0.921 | 121 |
| 3017501 | Neutrophils [#/volume] in Blood by Manual count | 0.919 |  |
| 3013115 | Eosinophils [#/volume] in Blood | 0.917 | 67 |
| 3030232 | Leukocytes other [#/volume] in Blood by Automated count | 0.916 |  |
| 3001604 | Monocytes [#/volume] in Blood | 0.915 | 61 |
| 3010834 | Platelets [#/volume] in Blood by Manual count | 0.912 |  |
| 43055372 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.911 |  |
| 3002864 | Erythrocytes [#/volume] in Urine by Automated count | 0.907 | 246 |
| 3003282 | Leukocytes [#/volume] in Blood by Manual count | 0.907 |  |
| 40760954 | Leukocytes [#/volume] in Body fluid by Automated count | 0.906 | 438 |
| 3017732 | Neutrophils [#/volume] in Blood | 0.906 | 57 |
| 42528762 | Erythrocytes [#/volume] in Bone marrow by Automated count | 0.905 |  |
| 3013869 | Basophils/Leukocytes in Blood by Automated count | 0.905 | 42 |
| 3027017 | Erythrocytes [#/volume] in Blood by Manual count | 0.905 |  |
| 3019198 | Lymphocytes [#/volume] in Blood | 0.903 | 70 |
| 43055373 | Basophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.903 |  |
| 40765008 | Erythrocyte distribution width [Ratio] in Blood from Fetus by Automated count | 0.902 |  |
| 3039827 | Platelets [#/volume] in Body fluid by Automated count | 0.900 |  |
| 3034531 | Granulocytes [#/volume] in Blood by Automated count | 0.899 |  |
| 3008342 | Neutrophils/Leukocytes in Blood by Automated count | 0.897 | 25 |
| 3007238 | Nucleated erythrocytes [#/volume] in Blood by Automated count | 0.896 | 1247 |
| 3011948 | Monocytes/Leukocytes in Blood by Automated count | 0.895 | 44 |
| 3046553 | Variant lymphocytes [#/volume] in Blood by Automated count | 0.895 |  |
| 43055370 | Monocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.894 |  |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.892 |  |
| 3037511 | Lymphocytes/Leukocytes in Blood by Automated count | 0.891 | 41 |
| 3046900 | Leukocytes [#/volume] corrected for nucleated erythrocytes in Blood by Automated count | 0.891 | 2010 |
| 43055369 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.890 |  |
| 42869452 | Immature granulocytes/Leukocytes in Blood by Automated count | 0.889 |  |
| 3011185 | Granulocytes/Leukocytes in Blood by Automated count | 0.889 |  |
| 3043688 | Hemoglobin [Mass/volume] in Body fluid | 0.888 |  |
| 3010813 | Leukocytes [#/volume] in Blood | 0.887 | 33 |
| 3027484 | Hemoglobin [Mass/volume] in Blood by calculation | 0.887 |  |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.887 |  |
| 40765001 | Erythrocytes [#/volume] in Blood from Fetus by Automated count | 0.886 |  |
| 3007461 | Platelets [#/volume] in Blood | 0.886 | 31 |
| 42528761 | Leukocytes [#/volume] in Bone marrow by Automated count | 0.884 |  |
| 3044916 | Immature granulocytes [Presence] in Blood by Automated count | 0.884 | 1866 |
| 1469714 | Platelets [#/volume] in Blood by Automated count --in presence of EDTA to detect possible clumping | 0.881 |  |
| 43055367 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.881 |  |
| 43055371 | Lymphocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.881 |  |
| 3015956 | Eosinophils/Leukocytes in Blood by Manual count | 0.880 | 229 |
| 3002173 | Hemoglobin [Mass/volume] in Arterial blood | 0.880 | 188 |
| 3026361 | Erythrocytes [#/volume] in Blood | 0.879 |  |
| 40760892 | CBC W Ordered Manual Differential panel - Blood | 0.877 |  |
| 40768826 | Monocytes [#/volume] in Blood from Fetus by Manual count | 0.876 |  |
| 40760950 | Erythrocytes [#/volume] in Dialysis fluid by Automated count | 0.876 |  |
| 3049383 | Erythrocyte distribution width [Ratio] in Cord blood | 0.875 |  |
| 40768825 | Basophils [#/volume] in Blood from Fetus by Manual count | 0.874 |  |
| 3020775 | Erythrocytes [#/volume] in Pleural fluid by Automated count | 0.872 |  |
| 40765005 | Platelets [#/volume] in Blood from Fetus by Automated count | 0.871 |  |
| 3010748 | Hematocrit/Hemoglobin [Ratio] of Blood by Automated count | 0.871 |  |
| 3021904 | Hematocrit [Volume Fraction] of Cord blood by Automated count | 0.870 |  |
| 43055368 | Basophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.868 |  |
| 40765002 | Hematocrit [Volume Fraction] of Blood from Fetus by Automated count | 0.868 |  |
| 3030332 | Immature monocytes [#/volume] in Blood by Manual count | 0.868 |  |
| 44816673 | Platelets [#/volume] in Platelet rich plasma by Automated count | 0.868 |  |
| 42870592 | CBC W Differential panel, method unspecified - Blood | 0.867 |  |
| 3026710 | Lymphocytes [#/volume] in Blood by Flow cytometry (FC) | 0.866 |  |
| 43055365 | Monocytes/Leukocytes [Pure number fraction] in Blood by Manual count | 0.866 |  |
| 1092234 | Monocytes [#/volume] in Blood by Flow cytometry (FC) | 0.865 |  |
| 40761511 | CBC panel - Blood by Automated count | 0.864 |  |
| 3001465 | Band form neutrophils [#/volume] in Blood by Automated count | 0.863 |  |
| 42869449 | Platelets reticulated [#/volume] in Blood by Automated count | 0.862 |  |
| 40760141 | CBC W Reflex Manual Differential panel - Blood | 0.862 |  |
| 40758903 | Hemoglobin [Mass/volume] in Blood by Oximetry | 0.861 |  |
| 3015182 | Erythrocyte distribution width [Entitic volume] by Automated count | 0.861 |  |
| 3028920 | Lymphocytes Immunoblastic [#/volume] in Blood by Manual count | 0.861 |  |
| 3013950 | Basophils+Eosinophils+Monocytes [#/volume] in Blood by Automated count | 0.860 |  |
| 3043107 | Immature eosinophils [#/volume] in Blood by Manual count | 0.860 |  |
| 3009797 | Basophils/Leukocytes in Blood by Manual count | 0.859 | 235 |
| 3022407 | Monocytes/Leukocytes in Blood by Manual count | 0.859 | 225 |
| 3022493 | Free Hemoglobin [Mass/volume] in Plasma | 0.859 | 1917 |
| 3006184 | Hemoglobin [Mass/volume] in Capillary blood | 0.858 |  |
| 40768824 | Eosinophils [#/volume] in Blood from Fetus by Manual count | 0.858 |  |
| 3038248 | Deoxyhemoglobin [Mass/volume] in Blood | 0.858 |  |
| 3041717 | Basophils [#/volume] in Body fluid by Manual count | 0.858 |  |
| 3038720 | Eosinophils [#/volume] in Body fluid by Manual count | 0.855 |  |
| 44787055 | CBC W Differential panel - Cord blood | 0.853 |  |
| 43055364 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.853 |  |
| 3004119 | Hemoglobin [Mass/volume] in Venous blood | 0.852 | 1986 |
| 3014528 | Neutrophils [#/volume] in Pleural fluid by Automated count | 0.851 |  |
| 1988081 | Hematocrit [Pure volume fraction] of Cord blood by Automated count | 0.851 |  |
| 40761514 | Nucleated erythrocytes/Leukocytes [Ratio] in Blood by Automated count | 0.848 | 326 |
| 3029798 | Monocytes [#/volume] in Body fluid by Manual count | 0.847 |  |
| 40762351 | Hemoglobin [Moles/volume] in Blood | 0.846 |  |
| 3023468 | Monocytes Abnormal [#/volume] in Blood by Manual count | 0.845 |  |
| 46235808 | Reticulocyte distribution width [Ratio] in Blood by calculation | 0.842 |  |
| 3043111 | Platelet mean volume [Entitic volume] in Blood by Automated count | 0.841 | 149 |
| 3050583 | Platelets panel - Blood by Automated count | 0.840 |  |
| 3027368 | Neutrophils/Leukocytes in Blood by Manual count | 0.840 | 1191 |
| 3050687 | CBC WO Differential panel - Cord blood | 0.839 |  |
| 3038784 | Granulocytes [#/volume] in Blood by Manual count | 0.837 |  |
| 3023599 | MCV [Entitic mean volume] in Red Blood Cells by Automated count | 0.836 | 17 |
| 3024557 | Granulocytes/Leukocytes in Blood by Manual count | 0.832 | 423 |
| 43055366 | Lymphocytes/Leukocytes [Pure number fraction] in Blood by Manual count | 0.830 |  |
| 3046885 | Immature basophils [#/volume] in Blood by Manual count | 0.829 |  |
| 3038058 | Lymphocytes/Leukocytes in Blood by Manual count | 0.824 | 186 |
| 43055339 | Eosinophils/Leukocytes [Pure number fraction] in Body fluid by Manual count | 0.820 |  |
| 43055289 | Eosinophils/Leukocytes [Pure number fraction] in Bronchial specimen by Manual count | 0.817 |  |
| 3009542 | Hematocrit [Volume Fraction] of Blood | 0.817 | 28 |
| 43055340 | Basophils/Leukocytes [Pure number fraction] in Body fluid by Manual count | 0.816 |  |
| 42869453 | Granulocytes/Leukocytes in Body fluid by Automated count | 0.811 |  |
| 3039417 | Platelet distribution width [Ratio] in Blood | 0.811 |  |
| 43055341 | Monocytes/Leukocytes [Pure number fraction] in Body fluid by Manual count | 0.810 |  |
| 3043139 | Polymorphonuclear cells/Monocytes [Ratio] in Blood | 0.809 |  |
| 3050746 | Hematocrit [Volume Fraction] of Blood by Estimated | 0.806 |  |
| 3019909 | Hematocrit [Volume Fraction] of Blood by Centrifugation | 0.805 | 545 |
| 3049858 | Reticulocyte mean volume [Entitic volume] in Reticulocytes | 0.803 |  |
| 3050479 | Immature granulocytes/100 leukocytes in Blood | 0.798 |  |
| 3024386 | Platelet [Entitic mean volume] in Blood by Rees-Ecker | 0.785 |  |
| 3024731 | MCV [Entitic mean volume] in Red Blood Cells | 0.784 | 34 |
| 3001123 | Platelet [Entitic mean volume] in Blood | 0.782 |  |
| 3002736 | Platelet distribution width [Entitic volume] in Blood by Automated count | 0.780 | 1233 |
| 3002888 | Erythrocyte distribution width [Entitic volume] | 0.778 |  |
| 1617382 | Neutrophils.immature/Neutrophils.segmented [Ratio] in Bone marrow by Manual count | 0.778 |  |
| 3019897 | Erythrocyte [DistWidth] in Blood by Automated count | 0.773 | 24 |
| 42869451 | Hemoglobin [Entitic mass] in Reticulocytes by Automated count | 0.771 |  |
| 36660656 | CBC W Differential panel - Stem cell product | 0.764 |  |
| 3009744 | MCHC [Entitic Mass/volume] in Red Blood Cells by Automated count | 0.757 | 10 |
| 43533918 | Hemoglobin [Entitic substance] in Reticulocytes by Automated count | 0.755 |  |
| 42869450 | Platelets reticulated/Platelets in Blood by Automated count | 0.752 |  |
| 40760142 | Auto Differential panel - Blood | 0.749 |  |
| 3031639 | Reticulocytes panel - Blood | 0.744 |  |
| 44787095 | Platelet distribution width [Entitic volume] in Cord blood by Automated count | 0.738 |  |
| 42870588 | Differential panel, method unspecified - Blood | 0.733 |  |
| 3007124 | Reticulocytes/Erythrocytes in Blood by Automated count | 0.728 | 1124 |
| 3026112 | Erythrocyte mean corpuscular diameter [Length] by Automated count | 0.724 |  |
| 3029080 | Hemoglobin [Entitic mass] in Reticulocytes | 0.714 | 1413 |
| 648732 | Reticulocyte - RBC Hemoglobin [Entitic mass difference] in Blood | 0.704 |  |
| 3044045 | Cell count and Differential panel - Body fluid | 0.701 |  |
| 3050452 | Leukogram panel - Blood | 0.700 |  |
| 3012030 | MCH [Entitic mass] by Automated count | 0.694 | 11 |
| 3038256 | Platelet clump [Presence] in Blood by Automated count | 0.685 |  |
| 3021223 | Hemogram without Platelets and with Manual Differential panel - Blood | 0.685 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1305 | b-pvk | % | 0% | name+unit+values | 1036 | 0 | [12.98, 13, 13, 13, 13.02, 14, 14, 14, 14.9] | B -Perusverenkuva | Blood |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1306 | b-pvk | e12/l | 0% | name+unit | 180 | 0 |  | B -Perusverenkuva | Blood |  | Erythrocytes [#/volume] in Blood by Automated count |
| 1307 | b-pvk | e9/l | 0% | name+unit | 180 | 0 |  | B -Perusverenkuva | Blood |  | Leukocytes [#/volume] in Blood by Automated count |
| 1308 | b-pvk | fl | 0% | name+unit | 191 | 0 |  | B -Perusverenkuva | Blood |  | Erythrocyte mean volume [Entitic volume] in Blood by Automated count |
| 1309 | b-pvk | form | 0% | name+unit | 6 | 0 |  | B -Perusverenkuva | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1310 | b-pvk | g/l | 0% | name+unit+values | 371 | 0 | [130.49, 135.97, 140.17, 143.56, 146.5, 149.94, 154.99, 161.16, 169.87] | B -Perusverenkuva | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 1311 | b-pvk | paketti | 0% | name+unit+values | 261 | 0 | [31329.79, 60496.46, 87166.96, 116360.34, 146168.26, 177141.71, 213025.07, 240401.38, 278743.21] | B -Perusverenkuva | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1312 | b-pvk | pg | 0% | name+unit | 191 | 0 |  | B -Perusverenkuva | Blood |  | Erythrocyte mean hemoglobin [Entitic mass] in Blood by Automated count |
| 1313 | b-pvk |  | 100% | name | 1084645 | 100 |  | B -Perusverenkuva | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1314 | b-pvk(pi) |  | 100% | name | 994 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1315 | b-pvk+eo |  | 100% | name | 1355 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1316 | b-pvk+kd |  | 100% | name | 335 | 100 |  |  | Blood |  | CBC with automated differential panel - Blood |
| 1317 | b-pvk+ne |  | 100% | name | 301325 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1318 | b-pvk+ner |  | 100% | name | 551 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1319 | b-pvk+t | % | 0% | name+unit+values | 16337 | 0 | [8.54, 11.43, 12.73, 13.01, 14.63, 21.66, 27.29, 34.08, 48.89] | B -Perusverenkuva ja trombosyytit | Blood |  | Neutrophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1320 | b-pvk+t | %g | 0% | name+unit | 229 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Granulocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1321 | b-pvk+t | %l | 0% | name+unit+values | 229 | 0 | [15.3, 18.86, 20.93, 24.39, 26.09, 27.9, 29.48, 31.36, 37.88] | B -Perusverenkuva ja trombosyytit | Blood |  | Lymphocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1322 | b-pvk+t | %m | 0% | name+unit+values | 229 | 0 | [9, 10, 10.3, 10.73, 11, 11.47, 11.97, 12.55, 13.3] | B -Perusverenkuva ja trombosyytit | Blood |  | Monocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1323 | b-pvk+t | e12/l | 0% | name+unit | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Erythrocytes [#/volume] in Blood by Automated count |
| 1324 | b-pvk+t | e9/l | 0% | name+unit+values | 4647 | 0 | [0, 0, 0, 0, 0, 0, 2.04, 5.2, 8.91] | B -Perusverenkuva ja trombosyytit | Blood |  | Leukocytes [#/volume] in Blood by Automated count |
| 1325 | b-pvk+t | fl | 0% | name+unit | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Erythrocyte mean volume [Entitic volume] in Blood by Automated count |
| 1326 | b-pvk+t | form | 0% | name+unit+values | 361 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.89, 1] | B -Perusverenkuva ja trombosyytit | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1327 | b-pvk+t | g/l | 0% | name+unit+values | 2746 | 0 | [312.86, 315.11, 317.96, 319.16, 327.56, 334.19, 340.53, 346.44, 355.56] | B -Perusverenkuva ja trombosyytit | Blood |  | Erythrocyte mean hemoglobin concentration [Mass/volume] in Blood by Automated count |
| 1328 | b-pvk+t | l/l | 0% | name+unit | 6 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Hematocrit [Volume Fraction] in Blood by Automated count |
| 1329 | b-pvk+t | paketti | 0% | name+unit+values | 269 | 0 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1330 | b-pvk+t | pg | 0% | name+unit+values | 2769 | 0 | [29, 29.58, 30, 30.35, 31, 31.07, 32, 32.99, 34.11] | B -Perusverenkuva ja trombosyytit | Blood |  | Erythrocyte mean hemoglobin [Entitic mass] in Blood by Automated count |
| 1331 | b-pvk+t |  | 99% | name+values | 4547373 | 100 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1332 | b-pvk+t+e |  | 100% | name | 1491 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1333 | b-pvk+t+n |  | 100% | name | 20012 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1334 | b-pvk+t+ne |  | 100% | name | 1150 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1335 | b-pvk+t+r |  | 100% | name | 713 | 100 |  |  | Blood |  | CBC with platelet and reticulocyte panel - Blood by Automated count |
| 1336 | b-pvk+tk |  | 100% | name | 466 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1337 | b-pvk+tkd | % | 0% | name+unit+values | 567 | 0 | [10.52, 11.98, 22.28, 26.53, 30.21, 32.92, 36.29, 39.43, 43.1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  | CBC with automated differential panel - Blood |
| 1338 | b-pvk+tkd | e9/l | 0% | name+unit | 5 | 0 |  | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  | CBC with automated differential panel - Blood |
| 1339 | b-pvk+tkd |  | 100% | name+values | 347141 | 99.77 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  | CBC with automated differential panel - Blood |
| 1340 | b-pvk+tkd,baso | % | 50% | name+unit+values | 4387 | 0 | [0.13, 0.2, 0.3, 0.34, 0.4, 0.5, 0.59, 0.7, 0.91] |  | Blood |  | Basophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1341 | b-pvk+tkd,baso | e9/l | 50% | name+unit+values | 4345 | 0 | [0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.05, 0.06] |  | Blood |  | Basophils [#/volume] in Blood by Automated count |
| 1342 | b-pvk+tkd,baso |  | 0% | name | 28 | 96.43 |  |  | Blood |  | Basophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1343 | b-pvk+tkd,eo | % | 50% | name+unit+values | 4389 | 0 | [0.28, 0.95, 1.44, 1.88, 2.38, 2.9, 3.5, 4.34, 5.77] |  | Blood |  | Eosinophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1344 | b-pvk+tkd,eo | e9/l | 50% | name+unit+values | 4355 | 0 | [0.02, 0.07, 0.1, 0.13, 0.16, 0.2, 0.24, 0.3, 0.39] |  | Blood |  | Eosinophils [#/volume] in Blood by Automated count |
| 1345 | b-pvk+tkd,eo |  | 0% | name | 35 | 77.14 |  |  | Blood |  | Eosinophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1346 | b-pvk+tkd,eryt | e12/l | 99% | name+unit+values | 4432 | 0 | [3.69, 4.01, 4.19, 4.32, 4.47, 4.6, 4.71, 4.86, 5.08] |  | Blood |  | Erythrocytes [#/volume] in Blood by Automated count |
| 1347 | b-pvk+tkd,eryt |  | 1% | name | 28 | 82.14 |  |  | Blood |  | Erythrocytes [#/volume] in Blood by Automated count |
| 1348 | b-pvk+tkd,hb | g/l | 99% | name+unit+values | 4431 | 0 | [109.63, 119.87, 125.6, 130.31, 134.35, 137.72, 141.31, 145.38, 151.58] |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 1349 | b-pvk+tkd,hb |  | 1% | name | 28 | 82.14 |  |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 1350 | b-pvk+tkd,hkr | osuus | 99% | name+unit+values | 4430 | 0 | [0.34, 0.36, 0.38, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45] |  | Blood |  | Hematocrit [Volume Fraction] in Blood by Automated count |
| 1351 | b-pvk+tkd,hkr |  | 1% | name | 28 | 82.14 |  |  | Blood |  | Hematocrit [Volume Fraction] in Blood by Automated count |
| 1352 | b-pvk+tkd,ig | % | 50% | name+unit+values | 4380 | 0 | [0, 0.1, 0.18, 0.2, 0.2, 0.24, 0.3, 0.4, 0.66] |  | Blood |  | Immature granulocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1353 | b-pvk+tkd,ig | e9/l | 50% | name+unit+values | 4329 | 0 | [0, 0.01, 0.01, 0.01, 0.01, 0.02, 0.02, 0.03, 0.06] |  | Blood |  | Immature granulocytes [#/volume] in Blood by Automated count |
| 1354 | b-pvk+tkd,ig |  | 0% | name | 27 | 100 |  |  | Blood |  | Immature granulocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1355 | b-pvk+tkd,leuk | e9/l | 99% | name+unit+values | 4441 | 0 | [4.64, 5.29, 5.87, 6.47, 7.06, 7.73, 8.41, 9.34, 10.91] |  | Blood |  | Leukocytes [#/volume] in Blood by Automated count |
| 1356 | b-pvk+tkd,leuk |  | 1% | name+values | 23 | 100 | [4.39, 5.06, 5.62, 6.11, 6.7, 7.36, 7.96, 8.73, 10.19] |  | Blood |  | Leukocytes [#/volume] in Blood by Automated count |
| 1357 | b-pvk+tkd,lymph | % | 50% | name+unit+values | 4402 | 0 | [14.51, 18.87, 22.17, 24.95, 27.85, 30.77, 33.85, 37.68, 42.79] |  | Blood |  | Lymphocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1358 | b-pvk+tkd,lymph | e9/l | 50% | name+unit+values | 4366 | 0 | [1.07, 1.3, 1.5, 1.68, 1.87, 2.05, 2.28, 2.59, 3.03] |  | Blood |  | Lymphocytes [#/volume] in Blood by Automated count |
| 1359 | b-pvk+tkd,lymph |  | 0% | name | 39 | 71.79 |  |  | Blood |  | Lymphocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1360 | b-pvk+tkd,mch | pg | 99% | name+unit+values | 4427 | 0 | [27.35, 28.81, 29.01, 30, 30, 30.98, 31, 31.99, 32.41] |  | Blood |  | Erythrocyte mean hemoglobin [Entitic mass] in Blood by Automated count |
| 1361 | b-pvk+tkd,mch |  | 1% | name | 26 | 88.46 |  |  | Blood |  | Erythrocyte mean hemoglobin [Entitic mass] in Blood by Automated count |
| 1362 | b-pvk+tkd,mchc | g/l | 99% | name+unit+values | 4422 | 0 | [316.84, 322.97, 327.09, 330.49, 333.34, 336.5, 339.82, 343.59, 348.74] |  | Blood |  | Erythrocyte mean hemoglobin concentration [Mass/volume] in Blood by Automated count |
| 1363 | b-pvk+tkd,mchc |  | 1% | name | 27 | 85.19 |  |  | Blood |  | Erythrocyte mean hemoglobin concentration [Mass/volume] in Blood by Automated count |
| 1364 | b-pvk+tkd,mcv | fl | 99% | name+unit+values | 4432 | 0 | [83.81, 86.19, 87.9, 89.02, 90.1, 91.52, 92.95, 94.05, 96.04] |  | Blood |  | Erythrocyte mean volume [Entitic volume] in Blood by Automated count |
| 1365 | b-pvk+tkd,mcv |  | 1% | name | 25 | 92 |  |  | Blood |  | Erythrocyte mean volume [Entitic volume] in Blood by Automated count |
| 1366 | b-pvk+tkd,mono | % | 50% | name+unit+values | 4397 | 0 | [6.39, 7.45, 8.16, 8.78, 9.38, 10.01, 10.67, 11.64, 13.06] |  | Blood |  | Monocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1367 | b-pvk+tkd,mono | e9/l | 50% | name+unit+values | 4364 | 0 | [0.41, 0.48, 0.54, 0.59, 0.65, 0.7, 0.78, 0.88, 1.03] |  | Blood |  | Monocytes [#/volume] in Blood by Automated count |
| 1368 | b-pvk+tkd,mono |  | 0% | name | 32 | 84.38 |  |  | Blood |  | Monocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1369 | b-pvk+tkd,neut | % | 50% | name+unit+values | 4407 | 0 | [43.3, 48.04, 51.9, 55.37, 58.56, 61.78, 65.36, 69.3, 74.25] |  | Blood |  | Neutrophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1370 | b-pvk+tkd,neut | e9/l | 50% | name+unit+values | 4373 | 0 | [2.18, 2.67, 3.11, 3.55, 4, 4.52, 5.12, 5.94, 7.37] |  | Blood |  | Neutrophils [#/volume] in Blood by Automated count |
| 1371 | b-pvk+tkd,neut |  | 0% | name | 34 | 82.35 |  |  | Blood |  | Neutrophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1372 | b-pvk+tkd,rdw | % | 99% | name+unit+values | 4298 | 0 | [12.5, 12.85, 13.17, 13.49, 13.79, 14.12, 14.57, 15.17, 16.52] |  | Blood |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1373 | b-pvk+tkd,rdw |  | 1% | name | 30 | 76.67 |  |  | Blood |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1374 | b-pvk+tkd,trom | eg/l | 99% | name+unit+values | 4413 | 0 | [163.91, 190.28, 209.92, 228.62, 246.86, 267.53, 293.03, 326.64, 371.27] |  | Blood |  | Platelets [#/volume] in Blood by Automated count |
| 1375 | b-pvk+tkd,trom |  | 1% | name | 31 | 74.19 |  |  | Blood |  | Platelets [#/volume] in Blood by Automated count |
| 1376 | b-pvk+tmd | % | 0% | name+unit | 108 | 0 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  | CBC with 3 part differential panel - Blood |
| 1377 | b-pvk+tmd |  | 100% | name | 31394 | 99.96 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  | CBC with 3 part differential panel - Blood |
| 1378 | b-pvk-päi |  | 100% | name | 120 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1379 | b-pvk-t |  | 100% | name | 1651 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1380 | b-pvk-tkd |  | 100% | name | 5227 | 100 |  |  | Blood |  | CBC with automated differential panel - Blood |
| 1381 | b-pvkt |  | 100% | name | 540592 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1382 | b-pvkt+re |  | 100% | name | 3032 | 100 |  |  | Blood |  | CBC with platelet and reticulocyte panel - Blood by Automated count |
| 1383 | b-pvktkdr |  | 100% | name | 6444 | 100 |  |  | Blood |  | CBC with automated differential and reticulocyte panel - Blood |
| 1384 | b-pvktmdl |  | 100% | name | 275 | 100 |  |  | Blood |  | CBC with 3 part differential panel - Blood |
| 1385 | b-pvktmdp |  | 100% | name | 1012 | 100 |  |  | Blood |  | CBC with 3 part differential panel - Blood |
| 1386 | b-pvktnee |  | 100% | name | 9809 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1387 | b-pvktp |  | 100% | name | 5212 | 100 |  |  | Blood |  | CBC with platelet panel - Blood by Automated count |
| 1388 | b-tvk | % | 0% | name+unit+values | 505 | 0 | [0, 0, 0, 0, 1, 2.55, 12.33, 37.94, 62.13] | B -Täydellinen verenkuva | Blood |  | CBC with automated differential panel - Blood |
| 1389 | b-tvk | e9/l | 0% | name+unit+values | 368 | 0 | [0.03, 0.03, 0.04, 0.04, 0.05, 0.05, 0.06, 0.07, 0.09] | B -Täydellinen verenkuva | Blood |  | Basophils [#/volume] in Blood by Automated count |
| 1390 | b-tvk | fl | 0% | name+unit | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  | Erythrocyte mean volume [Entitic volume] in Blood by Automated count |
| 1391 | b-tvk | form | 0% | name+unit | 11 | 0 |  | B -Täydellinen verenkuva | Blood |  | CBC with automated differential panel - Blood |
| 1392 | b-tvk | g/l | 0% | name+unit | 19 | 0 |  | B -Täydellinen verenkuva | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 1393 | b-tvk | paketti | 0% | name+unit | 22 | 0 |  | B -Täydellinen verenkuva | Blood |  | CBC with automated differential panel - Blood |
| 1394 | b-tvk | pg | 0% | name+unit | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  | Erythrocyte mean hemoglobin [Entitic mass] in Blood by Automated count |
| 1395 | b-tvk |  | 100% | name | 466809 | 100 |  | B -Täydellinen verenkuva | Blood |  | CBC with automated differential panel - Blood |
| 1396 | b-tvk+r |  | 100% | name | 465 | 100 |  |  | Blood |  | CBC with automated differential and reticulocyte panel - Blood |

