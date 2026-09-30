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
Here is group 14.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 1.000 | 154 |
| 1091617 | C reactive protein [Mass/volume] in Serum, Plasma or Blood | 0.966 |  |
| 3010156 | C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method | 0.924 | 348 |
| 46234770 | C reactive protein [Moles/volume] in Serum or Plasma | 0.918 |  |
| 3051387 | C reactive protein [Mass/volume] in Capillary blood | 0.904 |  |
| 648940 | C reactive protein [Measurement] in Serum or Plasma | 0.900 |  |
| 3035320 | C reactive protein [Mass/volume] in Body fluid | 0.898 |  |
| 42870365 | C reactive protein [Mass/volume] in Blood by High sensitivity method | 0.890 |  |
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.888 |  |
| 3028766 | C reactive protein [Titer] in Serum or Plasma | 0.881 |  |
| 3000965 | C reactive protein [Presence] in Serum or Plasma | 0.870 | 1281 |
| 46234771 | C reactive protein [Moles/volume] in Serum or Plasma by High sensitivity method | 0.853 |  |
| 3044417 | C reactive protein [Mass/volume] in Cerebral spinal fluid | 0.825 |  |
| 1988606 | C reactive protein [Units/volume] in Body fluid | 0.820 |  |
| 40762274 | C reactive protein [Mass/volume] in Cerebral spinal fluid by High sensitivity method | 0.815 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 22 | b-c-reaktiivinenproteiini | mg/l | 10% | name+unit | 29 | 0 |  |  | Blood |  | C reactive protein [Mass/volume] in Blood |
| 23 | b-c-reaktiivinenproteiini |  | 90% | name+values | 262 | 100 | [6, 7.54, 10.61, 13.7, 19, 27.87, 38.55, 55.7, 83.8] |  | Blood |  | C reactive protein [Mass/volume] in Blood |
| 24 | b-c-reaktiivinenproteiinipika |  | 100% | name+values | 300 | 100 | [7, 9.98, 14.87, 19.86, 29.44, 37.29, 52.65, 75.47, 99.97] |  | Blood |  | C reactive protein [Mass/volume] in Blood |
| 25 | b-c-resktiivinenproteiini | mg/l | 60% | name+unit+values | 1201 | 0 | [6.01, 8.05, 11.19, 14.61, 19.57, 26.51, 38.87, 58.3, 92.06] |  | Blood |  | C reactive protein [Mass/volume] in Blood |
| 26 | b-c-resktiivinenproteiini |  | 40% | name | 802 | 100 |  |  | Blood |  | C reactive protein [Mass/volume] in Blood |
| 27 | c-reaktiivinenproteiini | 1 | 6% | name+unit+values | 925 | 0 | [6.19, 8.92, 12.22, 16.99, 23.6, 35.02, 49.28, 74.96, 108.63] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 28 | c-reaktiivinenproteiini | mg/l | 50% | name+unit+values | 7963 | 0 | [4.01, 6.23, 9.46, 14.44, 23.17, 35.24, 51.91, 78.65, 126.37] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 29 | c-reaktiivinenproteiini |  | 44% | name+values | 7083 | 100 | [6.33, 8.51, 11.39, 16.56, 23.29, 36.71, 52.04, 72.28, 105.61] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 30 | c-reaktiivinenproteiini(4594p-crp) | mg/l | 66% | name+unit+values | 143 | 0 | [1, 1.79, 2, 2, 3, 4, 5, 6.63, 12.8] |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 31 | c-reaktiivinenproteiini(4594p-crp) |  | 34% | name | 74 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 32 | c-reaktiivinenproteiini(crp) | mg/l | 60% | name+unit+values | 381 | 0 | [1.23, 1.51, 1.92, 2.62, 3.39, 4.73, 6.27, 9.96, 21.14] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 33 | c-reaktiivinenproteiini(crp) |  | 40% | name | 250 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 34 | c-reaktiivinenproteiini(p-crp) | mg/l | 66% | name+unit+values | 500 | 0 | [1, 1.99, 2, 2.87, 3.17, 4.22, 5.93, 9.01, 19.57] |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 35 | c-reaktiivinenproteiini(p-crp) |  | 34% | name | 261 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 36 | c-reaktiivinenproteiini,herkkä | mg/l | 93% | name+unit+values | 254 | 0 | [0.22, 0.41, 0.59, 0.85, 1.15, 1.65, 2.41, 3.84, 6.24] |  |  |  | C reactive protein.high sensitivity [Mass/volume] in Serum or Plasma |
| 37 | c-reaktiivinenproteiini,herkkä |  | 7% | name | 18 | 100 |  |  |  |  | C reactive protein.high sensitivity [Mass/volume] in Serum or Plasma |
| 38 | c-reaktiivinenproteiini,herkkä,seerumista | mg/l | 100% | name+unit+values | 7396 | 0 | [0.29, 0.41, 0.59, 0.78, 1.03, 1.33, 1.82, 2.72, 4.64] |  |  |  | C reactive protein.high sensitivity [Mass/volume] in Serum |
| 39 | c-reaktiivinenproteiini,herkkä,seerumista |  | 0% | name | 36 | 100 |  |  |  |  | C reactive protein.high sensitivity [Mass/volume] in Serum |
| 40 | c-reaktiivinenproteiini,pika | mg/l | 69% | name+unit+values | 111 | 0 | [5, 5, 5.98, 7, 10.56, 13.36, 20.87, 34.17, 56] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 41 | c-reaktiivinenproteiini,pika |  | 31% | name | 49 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 42 | c-reaktiivinenproteiini,pika,tehdäänitse | mg/l | 55% | name+unit+values | 997 | 0 | [5, 5, 6.03, 8.02, 10.68, 14.69, 20.77, 34.42, 52.97] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 43 | c-reaktiivinenproteiini,pika,tehdäänitse |  | 45% | name | 820 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 44 | c-reaktiivinenproteiini,pikatesti,veri | mg/l | 10% | name+unit+values | 174 | 0.57 | [6, 7, 8.95, 10.84, 16.77, 22.29, 34.85, 53.05, 98.17] |  |  |  | C reactive protein [Mass/volume] in Blood |
| 45 | c-reaktiivinenproteiini,pikatesti,veri |  | 90% | name+values | 1656 | 100 | [6.44, 9.56, 13.03, 19.18, 27.25, 38.9, 52.68, 73.38, 109.24] |  |  |  | C reactive protein [Mass/volume] in Blood |
| 46 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) | mg/l | 77% | name+unit+values | 803 | 0.12 | [5, 5.19, 7.23, 9.16, 13.46, 18.82, 28.89, 45.49, 75.91] |  |  |  | C reactive protein [Mass/volume] in Blood |
| 47 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) |  | 23% | name | 240 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Blood |
| 48 | c-reaktiivinenproteiini,pikatutkimus | mg/l | 62% | name+unit+values | 106 | 0 | [6.73, 11.2, 15.4, 21.77, 30.17, 39.25, 56.9, 88.7, 114] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 49 | c-reaktiivinenproteiini,pikatutkimus |  | 38% | name | 66 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 50 | c-reaktiivinenproteiini,plasmasta,vieritesti | mg/l | 72% | name+unit+values | 699 | 0.14 | [5.15, 7.88, 10.79, 16.55, 23.64, 33.15, 47.97, 64.96, 99.24] |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 51 | c-reaktiivinenproteiini,plasmasta,vieritesti |  | 28% | name | 274 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 52 | c-reaktiivinenproteiini,tk:ntekemä |  | 100% | name+values | 1605 | 100 | [1.8, 3.13, 5.04, 8.21, 13.7, 22.58, 37.06, 58.66, 92.43] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 53 | c-reaktiivinenproteiini,vieritesti | mg/l | 5% | name+unit | 47 | 0 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 54 | c-reaktiivinenproteiini,vieritesti |  | 95% | name+values | 944 | 100 | [2.05, 4.95, 6.52, 8.89, 12.48, 17.85, 26.38, 44.03, 78.27] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 55 | c-reaktiivinenproteiini,vieritutkimus | mg/l | 45% | name+unit+values | 525 | 0 | [5, 5.95, 7.87, 11.68, 14.87, 20.65, 33.27, 55.7, 86.43] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 56 | c-reaktiivinenproteiini,vieritutkimus |  | 55% | name+values | 631 | 100 | [6, 8.93, 14.57, 21.5, 32.56, 47.6, 62.23, 77.19, 111.75] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 57 | c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 79% | name+unit+values | 1205 | 0 | [3.19, 6, 9.37, 13.37, 19.15, 28.37, 40.64, 61.88, 94.42] |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 58 | c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 21% | name | 318 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 59 | c-reaktiivinenproteiini,vieritutkimusnordlab | mg/l | 48% | name+unit+values | 92 | 1.09 | [5, 6, 7.65, 9.6, 12.5, 16.2, 20.27, 33, 47] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 60 | c-reaktiivinenproteiini,vieritutkimusnordlab |  | 52% | name | 99 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 61 | c-reaktiivinenproteiini-pika(4594crp-pika) | mg/l | 74% | name+unit+values | 136 | 0 | [5, 5.3, 7, 8.84, 11.17, 14.59, 18.57, 33.71, 47.7] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 62 | c-reaktiivinenproteiini-pika(4594crp-pika) |  | 26% | name | 47 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 63 | c-reaktiivinenproteiini-pika(crp-pika) | mg/l | 75% | name+unit+values | 1488 | 0 | [5, 6.95, 7, 7.23, 10.11, 14.48, 21.2, 31.68, 54.63] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 64 | c-reaktiivinenproteiini-pika(crp-pika) |  | 25% | name | 505 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 65 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä | mg/l | 79% | name+unit+values | 1826 | 0 | [1.75, 3.04, 5.71, 9.59, 14.3, 22.86, 34.7, 57.86, 90.35] |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 66 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä |  | 21% | name+values | 497 | 100 | [1.2, 1.55, 2.24, 2.89, 3.98, 4.84, 6.22, 7.61, 9.1] |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 67 | fs-c-reaktiivinenproteiini | mg/l | 57% | name+unit | 241 | 0 |  |  | Fasting serum |  | C reactive protein [Mass/volume] in Serum |
| 68 | fs-c-reaktiivinenproteiini |  | 43% | name | 184 | 100 |  |  | Fasting serum |  | C reactive protein [Mass/volume] in Serum |
| 69 | p-c-reaktiininenproteiini,vieritutkimus | mg/l | 54% | name+unit+values | 258 | 0 | [5.88, 8.84, 11.18, 17.01, 24.5, 35.24, 49.69, 68.51, 95.63] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 70 | p-c-reaktiininenproteiini,vieritutkimus |  | 46% | name | 224 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 71 | p-c-reaktiivinenproteiini | mg/l | 62% | name+unit+values | 41046 | 0 | [4.28, 7.21, 11.69, 18.14, 27.46, 40.14, 58.51, 87.59, 141.7] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 72 | p-c-reaktiivinenproteiini |  | 38% | name | 24714 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 73 | p-c-reaktiivinenproteiini(kval) | mg/l | 57% | name+unit+values | 187 | 0 | [6, 8.84, 13.56, 19.94, 26.88, 35.76, 52.92, 75.64, 104.4] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 74 | p-c-reaktiivinenproteiini(kval) |  | 43% | name | 142 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 75 | p-c-reaktiivinenproteiini(kval)␤ | mg/l | 46% | name+unit+values | 111 | 0 | [7, 10.23, 13.96, 17.18, 22.2, 27.49, 39.84, 58.9, 98.58] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 76 | p-c-reaktiivinenproteiini(kval)␤ |  | 54% | name | 130 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 77 | p-c-reaktiivinenproteiini(pikanäyte) | mg/l | 2% | name+unit | 6 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 78 | p-c-reaktiivinenproteiini(pikanäyte) |  | 98% | name+values | 352 | 100 | [1.49, 2.47, 4.27, 6.66, 10.25, 18.19, 28.15, 53.49, 81.26] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 79 | p-c-reaktiivinenproteiini,crp | mg/l | 93% | name+unit | 110 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 80 | p-c-reaktiivinenproteiini,crp |  | 7% | name | 8 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 81 | p-c-reaktiivinenproteiini,hoitoyksikkö | 1 | 14% | name+unit | 40 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 82 | p-c-reaktiivinenproteiini,hoitoyksikkö | mg/l | 29% | name+unit+values | 81 | 0 | [8, 10.55, 12, 15, 19.38, 26, 38.8, 61.6, 84] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 83 | p-c-reaktiivinenproteiini,hoitoyksikkö |  | 56% | name | 156 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 84 | p-c-reaktiivinenproteiini,pikatesti | mg/l | 6% | name+unit+values | 190 | 0 | [6, 7.07, 9, 13.46, 17.54, 24.16, 32.08, 50.25, 89.17] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 85 | p-c-reaktiivinenproteiini,pikatesti |  | 94% | name+values | 3095 | 100 | [6.4, 8.81, 12.02, 15.75, 21.21, 29.04, 42.26, 63.42, 97.39] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 86 | p-c-reaktiivinenproteiini,vieritutkimus | mg/l | 30% | name+unit | 53 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 87 | p-c-reaktiivinenproteiini,vieritutkimus |  | 70% | name | 122 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 88 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 63% | name+unit+values | 202 | 0 | [4.07, 6.94, 10.45, 16.41, 21.83, 29.61, 49.9, 68.72, 99.83] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 89 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 37% | name | 120 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 90 | p-c-reaktiivinenproteiini.pika |  | 100% | name+values | 316 | 100 | [2, 5.1, 8.74, 12.93, 19.35, 31.57, 53.66, 84.04, 111.82] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 91 | p-c-reaktiivinenproteiinipikahoitoyksiköt | mg/l | 71% | name+unit+values | 4601 | 0 | [5.18, 8.04, 12.05, 17.39, 25.78, 37.53, 54.69, 78.04, 114.03] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 92 | p-c-reaktiivinenproteiinipikahoitoyksiköt |  | 29% | name+values | 1925 | 100 | [1.19, 1.37, 1.77, 2.35, 2.97, 4.11, 5.47, 6.48, 8.22] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 93 | p-c-reaktiivinenproteiinipikamittari |  | 100% | name+values | 399 | 100 | [7, 9, 13, 21.24, 29.31, 41.92, 59.31, 82.22, 121.8] |  | Plasma |  | C reactive protein [Mass/volume] in Plasma |
| 94 | pikatesti,c-reaktiivinenproteiini | mg/l | 45% | name+unit+values | 315 | 0 | [6, 7.89, 10.58, 14.45, 20.43, 30.94, 44.31, 61.05, 91] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 95 | pikatesti,c-reaktiivinenproteiini |  | 55% | name | 386 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma |
| 96 | plasmanc-reaktiivinenproteiiniosoitus | 1 | 1% | name+unit | 36 | 0 |  |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 97 | plasmanc-reaktiivinenproteiiniosoitus | mg/l | 55% | name+unit+values | 3255 | 0 | [6.38, 8.92, 12.54, 17.7, 25.56, 35.77, 50.77, 70.37, 106.61] |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 98 | plasmanc-reaktiivinenproteiiniosoitus |  | 44% | name | 2589 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Plasma |
| 99 | s-c-reaktiivinenproteiini | mg/l | 86% | name+unit+values | 773 | 0 | [0.4, 0.73, 1.09, 1.42, 1.93, 2.88, 4.68, 7.14, 16.59] |  | Serum |  | C reactive protein.high sensitivity [Mass/volume] in Serum |
| 100 | s-c-reaktiivinenproteiini |  | 14% | name | 121 | 100 |  |  | Serum |  | C reactive protein.high sensitivity [Mass/volume] in Serum |
| 101 | s-c-reaktiivinenproteiini,herkkä | mg/l | 96% | name+unit+values | 813 | 0 | [0.39, 0.59, 0.81, 1.22, 1.68, 2.46, 3.64, 5.7, 8.99] |  | Serum |  | C reactive protein.high sensitivity [Mass/volume] in Serum |
| 102 | s-c-reaktiivinenproteiini,herkkä |  | 4% | name | 34 | 100 |  |  | Serum |  | C reactive protein.high sensitivity [Mass/volume] in Serum |
| 103 | s-c-reaktiivinenproteiini,pika | mg/l | 28% | name+unit+values | 77 | 0 | [8, 10, 12.53, 14.7, 17, 20, 27.67, 35, 48] |  | Serum |  | C reactive protein [Mass/volume] in Serum |
| 104 | s-c-reaktiivinenproteiini,pika |  | 72% | name | 199 | 100 |  |  | Serum |  | C reactive protein [Mass/volume] in Serum |
| 105 | s-c-reaktiivinenproteiini/ | mg/l | 100% | name+unit+values | 191 | 0 | [0.31, 0.5, 0.71, 0.96, 1.48, 2.27, 3.05, 4.68, 10.07] |  | Serum |  | C reactive protein.high sensitivity [Mass/volume] in Serum |

