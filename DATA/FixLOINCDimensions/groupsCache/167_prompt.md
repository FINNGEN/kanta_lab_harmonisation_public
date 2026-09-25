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
Here is group 167.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3001490 | Nucleated erythrocytes [#/volume] in Blood | 1.000 |  |
| 3001604 | Monocytes [#/volume] in Blood | 1.000 | 61 |
| 3005229 | Alpha 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 | 316 |
| 3006315 | Basophils [#/volume] in Blood | 1.000 | 121 |
| 3013115 | Eosinophils [#/volume] in Blood | 1.000 | 67 |
| 3013650 | Neutrophils [#/volume] in Blood by Automated count | 1.000 | 46 |
| 3015322 | Alpha 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 | 315 |
| 3015377 | Calcium [Moles/volume] in Serum or Plasma | 1.000 | 12 |
| 3017732 | Neutrophils [#/volume] in Blood | 1.000 | 57 |
| 3019198 | Lymphocytes [#/volume] in Blood | 1.000 | 70 |
| 3023465 | Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 | 323 |
| 3028286 | Albumin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 | 313 |
| 3028615 | Eosinophils [#/volume] in Blood by Automated count | 1.000 | 50 |
| 3043723 | Beta 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 |  |
| 3043747 | Beta 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 |  |
| 3002385 | Erythrocyte distribution width [Ratio] | 0.961 |  |
| 3046681 | Beta 2 globulin+Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.955 |  |
| 3009932 | Eosinophils [#/volume] in Blood by Manual count | 0.940 |  |
| 3016901 | Lambda lymphocytes [#/volume] in Blood | 0.936 |  |
| 3048248 | Gamma 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.933 |  |
| 1091526 | Gamma globulin [Mass/volume] in Serum or Plasma | 0.933 |  |
| 3010457 | Eosinophils/Leukocytes in Blood by Automated count | 0.925 | 43 |
| 3028129 | Nucleated erythrocytes [#/volume] in Body fluid | 0.923 |  |
| 1091762 | Alpha 1 globulin [Mass/volume] in Serum or Plasma | 0.922 |  |
| 3016520 | Beta globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.921 | 314 |
| 3013429 | Basophils [#/volume] in Blood by Automated count | 0.921 | 27 |
| 3017501 | Neutrophils [#/volume] in Blood by Manual count | 0.919 |  |
| 1092292 | Alpha 2 globulin [Mass/volume] in Serum or Plasma | 0.919 |  |
| 1616424 | Nucleated erythrocytes [#/volume] in Cord blood | 0.918 |  |
| 3030664 | Beta 1 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.916 |  |
| 3044821 | Beta 2 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.916 |  |
| 3033575 | Monocytes [#/volume] in Blood by Automated count | 0.915 | 52 |
| 3020192 | Gamma globulin [Mass/volume] in Body fluid by Electrophoresis | 0.914 |  |
| 3007238 | Nucleated erythrocytes [#/volume] in Blood by Automated count | 0.913 | 1247 |
| 3040757 | Calcium [Moles/volume] in Serum or Plasma --baseline | 0.912 |  |
| 1988791 | Gamma globulin [Mass/volume] in Serum or Plasma by Immunofixation | 0.912 |  |
| 43055372 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.911 |  |
| 3030947 | Beta 1 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.910 |  |
| 3028602 | Gamma globulin [Mass/volume] in Urine by Electrophoresis | 0.910 |  |
| 3027651 | Basophils [#/volume] in Blood by Manual count | 0.909 |  |
| 3006135 | Nucleated erythrocytes [#/volume] in Blood by Manual count | 0.908 | 501 |
| 40757485 | Beta 2 globulin [Mass/volume] in Urine by Electrophoresis | 0.908 |  |
| 40757484 | Beta 1 globulin [Mass/volume] in Urine by Electrophoresis | 0.907 |  |
| 3049383 | Erythrocyte distribution width [Ratio] in Cord blood | 0.907 |  |
| 3008512 | Albumin [Mass/volume] in Urine by Electrophoresis | 0.907 | 1035 |
| 3013869 | Basophils/Leukocytes in Blood by Automated count | 0.905 | 42 |
| 3006906 | Calcium [Mass/volume] in Serum or Plasma | 0.904 |  |
| 3000516 | Gamma globulin [Mass/volume] in Synovial fluid by Electrophoresis | 0.904 |  |
| 3021347 | Calcium.ionized [Moles/volume] in Serum or Plasma | 0.904 | 182 |
| 3012633 | Alpha 1 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.903 |  |
| 3030548 | Basophils [#/volume] in Body fluid | 0.903 |  |
| 3022361 | Alpha 1 globulin [Mass/volume] in Urine by Electrophoresis | 0.903 |  |
| 3004327 | Lymphocytes [#/volume] in Blood by Automated count | 0.903 | 35 |
| 43055373 | Basophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.903 |  |
| 3045286 | Beta globulin+Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.902 |  |
| 3034107 | Monocytes [#/volume] in Blood by Manual count | 0.901 | 472 |
| 3045561 | Albumin [Mass/volume] in Body fluid by Electrophoresis | 0.899 |  |
| 3034531 | Granulocytes [#/volume] in Blood by Automated count | 0.899 |  |
| 3008342 | Neutrophils/Leukocytes in Blood by Automated count | 0.897 | 25 |
| 3032360 | Lymphocytes+Monocytes [#/volume] in Blood | 0.897 |  |
| 3011948 | Monocytes/Leukocytes in Blood by Automated count | 0.895 | 44 |
| 3037039 | Alpha 2 globulin [Mass/volume] in Urine by Electrophoresis | 0.895 |  |
| 3030972 | Beta 2 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.895 |  |
| 43055370 | Monocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.894 |  |
| 43055428 | Alpha 1 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.894 |  |
| 3031042 | Nucleated cells [#/volume] in Blood | 0.893 |  |
| 3010043 | Alpha 2 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.893 |  |
| 3032084 | Eosinophils [#/volume] in Body fluid | 0.892 |  |
| 3003467 | Lymphocytes [#/volume] in Body fluid | 0.892 |  |
| 3037511 | Lymphocytes/Leukocytes in Blood by Automated count | 0.891 | 41 |
| 43055369 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.890 |  |
| 1988608 | Beta 2 globulin [Mass/volume] in 24 hour Urine by Electrophoresis | 0.890 |  |
| 3003215 | Lymphocytes [#/volume] in Blood by Manual count | 0.890 |  |
| 3046299 | Protein.monoclonal [Mass/volume] in Serum or Plasma by Electrophoresis | 0.889 | 482 |
| 1988171 | Alpha 1 antitrypsin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.889 |  |
| 3029713 | Protein.monoclonal band 1 [Mass/volume] in Serum or Plasma by Electrophoresis | 0.888 |  |
| 1989002 | Beta 1 globulin [Mass/volume] in 24 hour Urine by Electrophoresis | 0.888 |  |
| 40759043 | IgG [Mass/volume] in Serum by Electrophoresis | 0.888 |  |
| 3002590 | Prealbumin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.888 |  |
| 3032917 | Immature eosinophils [#/volume] in Blood | 0.887 |  |
| 3031141 | Monocytes [#/volume] in Body fluid | 0.887 |  |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.887 |  |
| 43055424 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.886 |  |
| 43055432 | Albumin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.886 |  |
| 3018997 | Alpha 1 globulin [Mass/volume] in Synovial fluid by Electrophoresis | 0.886 |  |
| 3000060 | B lymphocytes [#/volume] in Blood | 0.885 |  |
| 3024800 | Alpha 1 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.885 |  |
| 1091665 | Lymphocytes [#/volume] in Specimen | 0.885 |  |
| 3000905 | Leukocytes [#/volume] in Blood by Automated count | 0.885 | 15 |
| 3005162 | Calcium [Moles/volume] in Blood | 0.885 |  |
| 3031781 | Immature monocytes [#/volume] in Blood | 0.884 |  |
| 3015586 | Segmented neutrophils [#/volume] in Blood | 0.884 |  |
| 3006330 | Alpha 2 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.881 |  |
| 44787042 | Monocytes [#/volume] in Cord blood | 0.881 |  |
| 43055367 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.881 |  |
| 43055371 | Lymphocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.881 |  |
| 3032946 | Lymphoblasts [#/volume] in Blood | 0.881 |  |
| 3015956 | Eosinophils/Leukocytes in Blood by Manual count | 0.880 | 229 |
| 3031729 | Lymphocytes Immunoblastic [#/volume] in Blood | 0.880 |  |
| 44787049 | Basophils [#/volume] in Cord blood | 0.880 |  |
| 3035797 | Protein.monoclonal band 2 [Mass/volume] in Serum or Plasma by Electrophoresis | 0.879 |  |
| 3046321 | Neutrophils [#/volume] in Body fluid | 0.878 |  |
| 3046948 | Albumin/Globulin [Mass Ratio] in Serum or Plasma by Electrophoresis | 0.878 |  |
| 3035715 | Granulocytes [#/volume] in Blood | 0.876 | 2002 |
| 3000939 | Alpha 2 globulin [Mass/volume] in Synovial fluid by Electrophoresis | 0.876 |  |
| 3030511 | Albumin [Mass/volume] in 24 hour Urine by Electrophoresis | 0.874 |  |
| 1092234 | Monocytes [#/volume] in Blood by Flow cytometry (FC) | 0.874 |  |
| 40765176 | Nucleated erythrocytes [#/volume] in Body fluid by Automated count | 0.872 |  |
| 44787047 | Eosinophils [#/volume] in Cord blood | 0.871 |  |
| 3030905 | Polymorphonuclear cells [#/volume] in Blood | 0.871 |  |
| 3013806 | Calcium [Moles/volume] in Specimen | 0.870 |  |
| 3965752 | Albumin [Mass/volume] in Serum or Plasma by Nephelometry | 0.870 |  |
| 3024561 | Albumin [Mass/volume] in Serum or Plasma | 0.869 | 20 |
| 43055368 | Basophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.868 |  |
| 3009581 | Albumin [Mass/volume] in Synovial fluid by Electrophoresis | 0.868 |  |
| 3006504 | Eosinophils/Leukocytes in Blood | 0.868 | 49 |
| 3043948 | Calcium [Moles/volume] in Serum or Plasma --pre XXX challenge | 0.866 |  |
| 43055365 | Monocytes/Leukocytes [Pure number fraction] in Blood by Manual count | 0.866 |  |
| 40765009 | Nucleated erythrocytes [#/volume] in Blood from Fetus by Automated count | 0.865 |  |
| 3026260 | Monocytes Abnormal [#/volume] in Blood | 0.865 |  |
| 3026361 | Erythrocytes [#/volume] in Blood | 0.865 |  |
| 3039417 | Platelet distribution width [Ratio] in Blood | 0.864 |  |
| 3006032 | Nucleated erythrocytes [#/volume] in Body fluid by Manual count | 0.864 | 991 |
| 3001465 | Band form neutrophils [#/volume] in Blood by Automated count | 0.863 |  |
| 3010813 | Leukocytes [#/volume] in Blood | 0.861 | 33 |
| 3032890 | Immature basophils [#/volume] in Blood | 0.860 |  |
| 3043107 | Immature eosinophils [#/volume] in Blood by Manual count | 0.860 |  |
| 3009797 | Basophils/Leukocytes in Blood by Manual count | 0.859 | 235 |
| 3022407 | Monocytes/Leukocytes in Blood by Manual count | 0.859 | 225 |
| 3029338 | Protein.monoclonal band 3 [Mass/volume] in Serum or Plasma by Electrophoresis | 0.858 |  |
| 40768824 | Eosinophils [#/volume] in Blood from Fetus by Manual count | 0.858 |  |
| 3018010 | Neutrophils/Leukocytes in Blood | 0.858 | 76 |
| 3031805 | Promonocytes [#/volume] in Blood | 0.858 |  |
| 3032543 | Calcium [Moles/volume] in Venous blood | 0.857 |  |
| 3005176 | Neutrophils [#/volume] in Urine | 0.857 |  |
| 3004064 | Calcium [Moles/volume] corrected for total protein in Serum or Plasma | 0.857 |  |
| 3038720 | Eosinophils [#/volume] in Body fluid by Manual count | 0.855 |  |
| 3020059 | Calcium [Moles/volume] corrected for albumin in Serum or Plasma | 0.855 | 237 |
| 40765008 | Erythrocyte distribution width [Ratio] in Blood from Fetus by Automated count | 0.854 |  |
| 3019069 | Monocytes/Leukocytes in Blood | 0.854 | 40 |
| 43055364 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.853 |  |
| 3045398 | Protein.monoclonal [Units/volume] in Serum or Plasma by Electrophoresis | 0.852 |  |
| 3014528 | Neutrophils [#/volume] in Pleural fluid by Automated count | 0.851 |  |
| 3022096 | Basophils/Leukocytes in Blood | 0.849 | 54 |
| 3043139 | Polymorphonuclear cells/Monocytes [Ratio] in Blood | 0.848 |  |
| 46235808 | Reticulocyte distribution width [Ratio] in Blood by calculation | 0.848 |  |
| 40761514 | Nucleated erythrocytes/Leukocytes [Ratio] in Blood by Automated count | 0.848 | 326 |
| 3018199 | Band form neutrophils [#/volume] in Blood | 0.848 | 199 |
| 3041717 | Basophils [#/volume] in Body fluid by Manual count | 0.846 |  |
| 3030902 | Basophils [#/volume] in Pleural fluid | 0.846 |  |
| 40768825 | Basophils [#/volume] in Blood from Fetus by Manual count | 0.845 |  |
| 3027368 | Neutrophils/Leukocytes in Blood by Manual count | 0.840 | 1191 |
| 3002030 | Lymphocytes/Leukocytes in Blood | 0.839 | 45 |
| 3032072 | Eosinophils [#/volume] in Pleural fluid | 0.836 |  |
| 3039818 | Protein.monoclonal [Mass/volume] in Urine by Electrophoresis | 0.831 |  |
| 43055366 | Lymphocytes/Leukocytes [Pure number fraction] in Blood by Manual count | 0.830 |  |
| 1988129 | Protein.monoclonal band 1 [Mass/volume] in Serum or Plasma by Immunofixation | 0.830 |  |
| 1616489 | Protein.monoclonal band 1 [Mass/volume] in Urine by Electrophoresis | 0.828 |  |
| 1091125 | Protein.monoclonal [Mass/volume] in Serum or Plasma | 0.828 |  |
| 1988175 | Protein.monoclonal band 2 [Mass/volume] in Serum or Plasma by Immunofixation | 0.826 |  |
| 3028022 | Lymphocytes [#/volume] in Specimen by Automated count | 0.825 |  |
| 3029379 | Protein.monoclonal band 4 [Mass/volume] in Serum or Plasma by Electrophoresis | 0.825 |  |
| 3038058 | Lymphocytes/Leukocytes in Blood by Manual count | 0.824 | 186 |
| 40759885 | Protein.monoclonal band 1/Protein.total in Serum or Plasma by Electrophoresis | 0.824 |  |
| 43055339 | Eosinophils/Leukocytes [Pure number fraction] in Body fluid by Manual count | 0.820 |  |
| 43055289 | Eosinophils/Leukocytes [Pure number fraction] in Bronchial specimen by Manual count | 0.817 |  |
| 3011185 | Granulocytes/Leukocytes in Blood by Automated count | 0.816 |  |
| 43055340 | Basophils/Leukocytes [Pure number fraction] in Body fluid by Manual count | 0.816 |  |
| 3031047 | Protein.monoclonal band 2 [Mass/volume] in Urine by Electrophoresis | 0.813 |  |
| 43055341 | Monocytes/Leukocytes [Pure number fraction] in Body fluid by Manual count | 0.810 |  |
| 3013950 | Basophils+Eosinophils+Monocytes [#/volume] in Blood by Automated count | 0.806 |  |
| 3002888 | Erythrocyte distribution width [Entitic volume] | 0.803 |  |
| 3042675 | Protein.monoclonal band 2/Protein.total in Serum or Plasma by Electrophoresis | 0.803 |  |
| 3029582 | Protein.monoclonal band 3 [Mass/volume] in Urine by Electrophoresis | 0.793 |  |
| 3024516 | IgM.monoclonal [Mass/volume] in Serum | 0.793 |  |
| 3034226 | Lambda lymphocytes/Lymphocytes in Blood | 0.792 |  |
| 3030741 | Protein.monoclonal band 3/Protein.total in Serum or Plasma by Electrophoresis | 0.788 |  |
| 3015182 | Erythrocyte distribution width [Entitic volume] by Automated count | 0.785 |  |
| 3017057 | Lymphocytes+Monocytes/Leukocytes in Blood | 0.785 |  |
| 3021302 | Basophils/100 leukocytes in Body fluid | 0.785 | 1519 |
| 3039367 | Monocytes+Macrophages/Leukocytes in Blood | 0.784 |  |
| 3008943 | Abnormal lymphocytes [#/volume] in Blood | 0.783 |  |
| 3021453 | Eosinophils/Leukocytes in Body fluid | 0.783 | 418 |
| 3034708 | Nucleated erythrocytes/Leukocytes [Ratio] in Blood | 0.782 |  |
| 3038104 | Monocytes/Leukocytes in Body fluid | 0.781 | 369 |
| 3050032 | Hemoglobin distribution width [Mass/volume] in Blood | 0.759 |  |
| 3002736 | Platelet distribution width [Entitic volume] in Blood by Automated count | 0.726 | 1233 |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1950 | b-erybla,osatutkimus(19978b-erybla) | e9/l | 100% | name+unit+values | 1575 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  | Nucleated erythrocytes [#/volume] in Blood |
| 1951 | b-erybla,osatutkimus(b-erybla) | e9/l | 100% | name+unit+values | 3732 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  | Nucleated erythrocytes [#/volume] in Blood |
| 1952 | b-erybla,osatutkimus(b-erybla) |  | 0% | name | 8 | 75 |  |  | Blood |  | Nucleated erythrocytes [#/volume] in Blood |
| 1953 | b-neut,osatutkimus(689b-neut) | e9/l | 100% | name+unit+values | 114 | 0 | [2.36, 2.69, 3.03, 3.4, 3.69, 4.15, 4.59, 5.12, 5.88] |  | Blood |  | Neutrophils [#/volume] in Blood |
| 1954 | basofiilit,absol.arvot,osatutkimus(40b-baso) | e9/l | 100% | name+unit+values | 114 | 0 | [0.02, 0.03, 0.03, 0.04, 0.04, 0.05, 0.06, 0.06, 0.08] |  |  |  | Basophils [#/volume] in Blood |
| 1955 | basofiilit,konediffi(),osatutk.b-diffi | % | 100% | name+unit+values | 1040 | 0 | [0.2, 0.35, 0.48, 0.57, 0.68, 0.78, 0.9, 1.09, 1.35] |  |  |  | Basophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1956 | basofiilit,osatutkimus(692l-baso) | % | 100% | name+unit+values | 128 | 0 | [0, 0, 0.88, 1, 1, 1, 1, 1, 1] |  |  |  | Basophils/Leukocytes [# Ratio] in Blood |
| 1957 | e-rdw,osatutkimus(19976e-rdw) | % | 100% | name+unit+values | 1577 | 0 | [12, 12.98, 13, 13, 13, 13, 13.6, 14, 14.04] |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood |
| 1958 | e-rdw,osatutkimus(e-rdw) | % | 100% | name+unit+values | 3731 | 0 | [12, 12.05, 13, 13, 13, 13, 13, 14, 14.04] |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood |
| 1959 | e-rdw,osatutkimus(e-rdw) |  | 0% | name | 8 | 100 |  |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood |
| 1960 | eosinofiilit,absol.arvot,osatutkimus(39b-eos) | e9/l | 100% | name+unit+values | 114 | 0 | [0.06, 0.09, 0.12, 0.16, 0.18, 0.2, 0.23, 0.28, 0.33] |  |  |  | Eosinophils [#/volume] in Blood |
| 1961 | eosinofiilit,konediffi(),osatutk.b-diffi | % | 100% | name+unit+values | 1041 | 0 | [0.08, 1.13, 1.71, 2.33, 2.85, 3.43, 4.13, 5.02, 6.83] |  |  |  | Eosinophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1962 | eosinofiilit,osatutkimus(690l-eos) | % | 100% | name+unit+values | 114 | 0 | [1, 1.43, 2, 2, 3, 3, 3.11, 4, 5] |  |  |  | Eosinophils/Leukocytes [# Ratio] in Blood |
| 1963 | eosinofiilitabs,konediffi,osatutk.b-diffi | e9/l | 100% | name+unit+values | 1041 | 0 | [0.01, 0.07, 0.1, 0.14, 0.17, 0.22, 0.27, 0.33, 0.46] |  |  |  | Eosinophils [#/volume] in Blood by Automated count |
| 1964 | kalsium,osatutkimus(p-ca) | mmol/l | 100% | name+unit+values | 167 | 0 | [2.26, 2.3, 2.32, 2.34, 2.37, 2.38, 2.41, 2.43, 2.47] |  |  |  | Calcium [Moles/volume] in Serum or Plasma |
| 1965 | l-neut,osatutkimus(688l-neut) | % | 100% | name+unit+values | 114 | 0 | [46.1, 51, 53.29, 55, 56.87, 59, 62, 66.13, 71.3] |  | Leukocyte |  | Neutrophils/Leukocytes [# Ratio] in Blood |
| 1966 | lymfosyytit,absol.arvot,osatutkimus(43b-lymf) | e9/l | 100% | name+unit+values | 114 | 0 | [1.2, 1.42, 1.67, 1.84, 1.94, 2.02, 2.22, 2.46, 2.71] |  |  |  | Lymphocytes [#/volume] in Blood |
| 1967 | lymfosyytit,konediffi(),osatutk.b-diffi | % | 100% | name+unit+values | 1041 | 0 | [14.77, 18.39, 21, 24.27, 27.4, 30.54, 33.61, 37.23, 41.49] |  |  |  | Lymphocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1968 | lymfosyytit,osatutkimus(46l-lymf) | % | 100% | name+unit+values | 114 | 0 | [17.98, 23.4, 26.71, 28, 31, 32.84, 34.76, 36, 40.42] |  |  |  | Lymphocytes/Leukocytes [# Ratio] in Blood |
| 1969 | monosyytit,absol.arvot,osatutkimus(42b-monos) | e9/l | 100% | name+unit+values | 114 | 0 | [0.36, 0.42, 0.44, 0.49, 0.53, 0.58, 0.62, 0.67, 0.77] |  |  |  | Monocytes [#/volume] in Blood |
| 1970 | monosyytit,konediffi(),osatutk.b-diffi | % | 100% | name+unit+values | 1041 | 0 | [6.01, 6.87, 7.49, 8.19, 8.74, 9.45, 10.43, 11.69, 13.27] |  |  |  | Monocytes/Leukocytes [# Ratio] in Blood by Automated count |
| 1971 | monosyytit,osatutkimus(693l-monos) | % | 100% | name+unit+values | 114 | 0 | [6, 6.9, 7, 8, 8, 9, 9, 10, 11] |  |  |  | Monocytes/Leukocytes [# Ratio] in Blood |
| 1972 | neutrofiiliset,konediffi(),osatutk.b-diffi | % | 100% | name+unit+values | 1041 | 0 | [43.33, 48.08, 51.94, 55.59, 58.77, 61.59, 65.14, 69.9, 74.47] |  |  |  | Neutrophils/Leukocytes [# Ratio] in Blood by Automated count |
| 1973 | neutrofiilitabs,konediffi,osatutk.b-diffi | e9/l | 100% | name+unit+values | 1041 | 0 | [1.86, 2.39, 2.82, 3.25, 3.63, 4.11, 4.7, 5.54, 6.96] |  |  |  | Neutrophils [#/volume] in Blood by Automated count |
| 1974 | s-albumiini,osatutkimuss-prot-fr | g/l | 100% | name+unit+values | 109 | 0 | [31.62, 35.39, 37.28, 38.52, 39.57, 40.75, 41.75, 43.12, 44] |  | Serum | Fractions | Albumin [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1975 | s-alfa-1-globuliini,osatutkimuss-prot-fr | g/l | 100% | name+unit+values | 109 | 0 | [2.3, 2.4, 2.54, 2.7, 2.89, 3.08, 3.35, 3.6, 4.2] |  | Serum | Fractions | Alpha 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1976 | s-alfa-2-globuliini,osatutkimuss-prot-fr | g/l | 100% | name+unit+values | 109 | 0 | [5.63, 6, 6.24, 6.66, 7.47, 7.93, 8.35, 9.06, 9.9] |  | Serum | Fractions | Alpha 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1977 | s-beta-1-globuliini,osatutkimuss-prot-fr | g/l | 100% | name+unit+values | 109 | 0 | [3.5, 3.7, 3.85, 4.04, 4.14, 4.31, 4.42, 4.7, 4.9] |  | Serum | Fractions | Beta 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1978 | s-beta-2-globuliini,osatutkimuss-prot-fr | g/l | 100% | name+unit+values | 109 | 0 | [2.8, 3.09, 3.44, 3.86, 4.01, 4.31, 4.58, 4.8, 5.27] |  | Serum | Fractions | Beta 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1979 | s-gamma-globuliini,osatutkimuss-prot-fr | g/l | 100% | name+unit+values | 109 | 0 | [6.61, 7.97, 8.64, 9.16, 9.73, 10.36, 11, 11.66, 12.99] |  | Serum | Fractions | Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1980 | s-m-komponentti-1(valetietues-prot-fr) | g/l | 59% | name+unit+values | 135 | 0 | [0, 0, 0, 1.3, 2.13, 3.83, 5.42, 7.84, 12.97] |  | Serum |  | Monoclonal protein 1 [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1981 | s-m-komponentti-1(valetietues-prot-fr) |  | 41% | name | 93 | 100 |  |  | Serum |  | Monoclonal protein 1 [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1982 | s-m-komponentti-2(valetietues-prot-fr) | g/l | 38% | name+unit+values | 82 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 1] |  | Serum |  | Monoclonal protein 2 [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1983 | s-m-komponentti-2(valetietues-prot-fr) |  | 62% | name | 133 | 100 |  |  | Serum |  | Monoclonal protein 2 [Mass/volume] in Serum or Plasma by Electrophoresis |
| 1984 | s-m-komponentti-3(valetietues-prot-fr) |  | 100% | name | 131 | 100 |  |  | Serum |  | Monoclonal protein 3 [Mass/volume] in Serum or Plasma by Electrophoresis |

