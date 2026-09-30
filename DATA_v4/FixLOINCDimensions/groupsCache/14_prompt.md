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
Here is group 14.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 0.973 | 154 |
| 3051387 | C reactive protein [Mass/volume] in Capillary blood | 0.972 |  |
| 1091617 | C reactive protein [Mass/volume] in Serum, Plasma or Blood | 0.939 |  |
| 3010156 | C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method | 0.910 | 348 |
| 46234770 | C reactive protein [Moles/volume] in Serum or Plasma | 0.894 |  |
| 42870365 | C reactive protein [Mass/volume] in Blood by High sensitivity method | 0.874 |  |
| 648940 | C reactive protein [Measurement] in Serum or Plasma | 0.872 |  |
| 3035320 | C reactive protein [Mass/volume] in Body fluid | 0.866 |  |
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.864 |  |
| 3028766 | C reactive protein [Titer] in Serum or Plasma | 0.852 |  |
| 46234771 | C reactive protein [Moles/volume] in Serum or Plasma by High sensitivity method | 0.847 |  |
| 3000965 | C reactive protein [Presence] in Serum or Plasma | 0.843 | 1281 |
| 40762274 | C reactive protein [Mass/volume] in Cerebral spinal fluid by High sensitivity method | 0.802 |  |
| 1988606 | C reactive protein [Units/volume] in Body fluid | 0.800 |  |
| 3044417 | C reactive protein [Mass/volume] in Cerebral spinal fluid | 0.790 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 23 | b-c-reaktiivinenproteiini | mg/l | 10% | name+unit | 29 | 0 |  |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 24 | b-c-reaktiivinenproteiini |  | 90% | name+values | 262 | 44.27 | [6, 7.5, 10.67, 13.8, 18.67, 27.69, 37.44, 56, 84] |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 25 | b-c-reaktiivinenproteiinipika |  | 100% | name+values | 300 | 37 | [7, 10.22, 14.84, 20.3, 29.2, 37.52, 52.47, 75.48, 99.1] |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 26 | b-c-resktiivinenproteiini | mg/l | 60% | name+unit+values | 1201 | 0 | [6, 8.11, 11.16, 14.7, 19.67, 26.61, 38.65, 58.3, 91.79] |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 27 | b-c-resktiivinenproteiini |  | 40% | name | 802 | 92.39 |  |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 28 | c-reaktiivinenproteiini | 1 | 6% | name+unit+values | 925 | 0 | [6.19, 8.89, 11.99, 16.88, 23.76, 35.33, 49.12, 74.41, 108.21] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 29 | c-reaktiivinenproteiini | mg/l | 50% | name+unit+values | 7963 | 0 | [4.01, 6.22, 9.5, 14.46, 23.15, 35.25, 51.85, 77.94, 126.36] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 30 | c-reaktiivinenproteiini |  | 44% | name+values | 7083 | 90.23 | [6.55, 8.84, 11.73, 17.15, 24.37, 37.67, 52.72, 72.92, 107.1] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 31 | c-reaktiivinenproteiini(4594p-crp) | mg/l | 66% | name+unit+values | 143 | 0 | [1, 1.79, 2, 2, 3, 4, 5, 6, 12.8] |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 32 | c-reaktiivinenproteiini(4594p-crp) |  | 34% | name | 74 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 33 | c-reaktiivinenproteiini(crp) | mg/l | 60% | name+unit+values | 381 | 0 | [1.23, 1.51, 1.92, 2.62, 3.36, 4.75, 6.13, 9.98, 21.06] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 34 | c-reaktiivinenproteiini(crp) |  | 40% | name | 250 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 35 | c-reaktiivinenproteiini(p-crp) | mg/l | 66% | name+unit+values | 500 | 0 | [1, 2, 2, 2.85, 3.14, 4.26, 5.94, 8.93, 19.54] |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 36 | c-reaktiivinenproteiini(p-crp) |  | 34% | name | 261 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 37 | c-reaktiivinenproteiini,herkkä | mg/l | 93% | name+unit+values | 254 | 0 | [0.22, 0.41, 0.57, 0.84, 1.15, 1.65, 2.42, 3.86, 6.33] |  |  |  | C-reactive protein.high sensitivity [Mass/volume] in Serum or Plasma |
| 38 | c-reaktiivinenproteiini,herkkä |  | 7% | name | 18 | 94.44 |  |  |  |  | C-reactive protein.high sensitivity [Mass/volume] in Serum or Plasma |
| 39 | c-reaktiivinenproteiini,herkkä,seerumista | mg/l | 100% | name+unit+values | 7396 | 0 | [0.28, 0.41, 0.6, 0.78, 1.03, 1.34, 1.83, 2.72, 4.64] |  |  |  | C-reactive protein.high sensitivity [Mass/volume] in Serum |
| 40 | c-reaktiivinenproteiini,herkkä,seerumista |  | 0% | name | 36 | 83.33 |  |  |  |  | C-reactive protein.high sensitivity [Mass/volume] in Serum |
| 41 | c-reaktiivinenproteiini,pika | mg/l | 69% | name+unit+values | 111 | 0 | [5, 5.05, 6.2, 8.27, 11.67, 14.3, 22.37, 36.1, 57] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 42 | c-reaktiivinenproteiini,pika |  | 31% | name | 49 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 43 | c-reaktiivinenproteiini,pika,tehdäänitse | mg/l | 55% | name+unit+values | 997 | 0 | [5, 5, 6.35, 8.12, 10.93, 14.99, 21.14, 34.44, 53.73] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 44 | c-reaktiivinenproteiini,pika,tehdäänitse |  | 45% | name | 820 | 99.27 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 45 | c-reaktiivinenproteiini,pikatesti,veri | mg/l | 10% | name+unit+values | 174 | 0 | [6, 7, 8.95, 10.5, 16.42, 22.45, 35.5, 53.5, 98.67] |  |  |  | C-reactive protein [Mass/volume] in Blood |
| 46 | c-reaktiivinenproteiini,pikatesti,veri |  | 90% | name+values | 1656 | 42.69 | [6.55, 9.61, 13.21, 19.27, 27.67, 39.17, 52.81, 73.29, 109.39] |  |  |  | C-reactive protein [Mass/volume] in Blood |
| 47 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) | mg/l | 77% | name+unit+values | 803 | 0 | [4.99, 5.34, 7.17, 9.24, 13.4, 18.77, 28.88, 45.54, 76.31] |  |  |  | C-reactive protein [Mass/volume] in Blood |
| 48 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) |  | 23% | name | 240 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Blood |
| 49 | c-reaktiivinenproteiini,pikatutkimus | mg/l | 62% | name+unit+values | 106 | 0 | [7, 12, 15.43, 21.6, 30.72, 39.4, 56.9, 87, 115.33] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 50 | c-reaktiivinenproteiini,pikatutkimus |  | 38% | name | 66 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 51 | c-reaktiivinenproteiini,plasmasta,vieritesti | mg/l | 72% | name+unit+values | 699 | 0 | [5.17, 7.91, 10.75, 16.58, 23.68, 33.24, 48.01, 64.98, 99.29] |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 52 | c-reaktiivinenproteiini,plasmasta,vieritesti |  | 28% | name | 274 | 94.89 |  |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 53 | c-reaktiivinenproteiini,tk:ntekemä |  | 100% | name+values | 1605 | 13.4 | [2.23, 4.3, 7.78, 12.46, 19.91, 29.72, 46.58, 66.7, 98.89] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 54 | c-reaktiivinenproteiini,vieritesti | mg/l | 5% | name+unit | 47 | 0 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 55 | c-reaktiivinenproteiini,vieritesti |  | 95% | name+values | 944 | 23.62 | [3.08, 5.45, 7.93, 11.11, 14.9, 20.87, 29.7, 49.04, 81.9] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 56 | c-reaktiivinenproteiini,vieritutkimus | mg/l | 45% | name+unit+values | 525 | 0 | [5, 6.72, 8.66, 12.22, 15.93, 22.09, 35.26, 59.08, 89.7] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 57 | c-reaktiivinenproteiini,vieritutkimus |  | 55% | name+values | 631 | 58.8 | [6.41, 9.32, 15.53, 22.99, 35.64, 49.47, 62.97, 81.83, 113.06] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 58 | c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 79% | name+unit | 1205 | 0 |  |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 59 | c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 21% | name+values | 318 | 100 | [4.71, 7.37, 11.52, 16.21, 23.22, 31.65, 45.13, 65.98, 97.07] |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 60 | c-reaktiivinenproteiini,vieritutkimusnordlab | mg/l | 48% | name+unit+values | 92 | 0 | [5, 6, 8, 10.7, 12.75, 16.2, 21, 31.5, 47] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 61 | c-reaktiivinenproteiini,vieritutkimusnordlab |  | 52% | name | 99 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 62 | c-reaktiivinenproteiini-pika(4594crp-pika) | mg/l | 74% | name+unit+values | 136 | 0 | [5, 5.32, 7, 9, 11.15, 14.57, 19, 33.2, 47.3] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 63 | c-reaktiivinenproteiini-pika(4594crp-pika) |  | 26% | name | 47 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 64 | c-reaktiivinenproteiini-pika(crp-pika) | mg/l | 75% | name+unit+values | 1488 | 0 | [5, 6.88, 7, 7.34, 10.21, 14.71, 21.39, 32, 54.73] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 65 | c-reaktiivinenproteiini-pika(crp-pika) |  | 25% | name | 505 | 99.8 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 66 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä | mg/l | 79% | name+unit+values | 1826 | 0 | [1.75, 3.02, 5.68, 9.52, 14.27, 22.77, 34.19, 57.29, 89.46] |  |  |  | C-reactive protein [Mass/volume] in Capillary blood |
| 67 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä |  | 21% | name+values | 497 | 46.88 | [1.2, 1.53, 2.21, 2.84, 3.97, 4.8, 6.15, 7.51, 9.1] |  |  |  | C-reactive protein [Mass/volume] in Capillary blood |
| 68 | fs-c-reaktiivinenproteiini | mg/l | 57% | name+unit | 241 | 0 |  |  | Fasting serum |  | C-reactive protein [Mass/volume] in Serum |
| 69 | fs-c-reaktiivinenproteiini |  | 43% | name | 184 | 100 |  |  | Fasting serum |  | C-reactive protein [Mass/volume] in Serum |
| 70 | p-c-reaktiininenproteiini,vieritutkimus | mg/l | 54% | name+unit+values | 258 | 0 | [5.85, 8.85, 11.14, 17.24, 24.49, 35.17, 49.34, 67.54, 96.38] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 71 | p-c-reaktiininenproteiini,vieritutkimus |  | 46% | name | 224 | 100 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 72 | p-c-reaktiivinenproteiini | mg/l | 62% | name+unit+values | 41046 | 0 | [4.18, 7.12, 11.73, 18.09, 27.46, 40.11, 58.4, 87.78, 141.39] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 73 | p-c-reaktiivinenproteiini |  | 38% | name | 24714 | 99.73 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 74 | p-c-reaktiivinenproteiini(kval) | mg/l | 57% | name+unit+values | 187 | 0 | [6.14, 9.01, 13.88, 18.86, 24.62, 33.54, 47.21, 67.37, 102.4] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 75 | p-c-reaktiivinenproteiini(kval) |  | 43% | name | 142 | 100 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 76 | p-c-reaktiivinenproteiini(kval)␤ | mg/l | 46% | name+unit | 111 | 0 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 77 | p-c-reaktiivinenproteiini(kval)␤ |  | 54% | name | 130 | 100 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 78 | p-c-reaktiivinenproteiini(pikanäyte) | mg/l | 2% | name+unit | 6 | 0 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 79 | p-c-reaktiivinenproteiini(pikanäyte) |  | 98% | name+values | 352 | 17.33 | [1.52, 2.59, 4.86, 7.54, 12.38, 20.91, 32.04, 56.93, 83.62] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 80 | p-c-reaktiivinenproteiini,crp | mg/l | 93% | name+unit | 110 | 0 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 81 | p-c-reaktiivinenproteiini,crp |  | 7% | name | 8 | 62.5 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 82 | p-c-reaktiivinenproteiini,hoitoyksikkö | 1 | 14% | name+unit | 40 | 0 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 83 | p-c-reaktiivinenproteiini,hoitoyksikkö | alle | 2% | name+unit | 5 | 0 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 84 | p-c-reaktiivinenproteiini,hoitoyksikkö | mg/l | 29% | name+unit+values | 81 | 0 | [8, 11, 13, 16.2, 22.25, 33.7, 48, 64, 131] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 85 | p-c-reaktiivinenproteiini,hoitoyksikkö |  | 55% | name+values | 156 | 63.46 | [6, 8, 12, 14, 26, 32, 40, 60, 120] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 86 | p-c-reaktiivinenproteiini,pikatesti | mg/l | 6% | name+unit | 190 | 0 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 87 | p-c-reaktiivinenproteiini,pikatesti |  | 94% | name+values | 3095 | 41.23 | [6.43, 8.8, 12.04, 15.76, 21.17, 29.16, 41.93, 63.64, 96.9] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 88 | p-c-reaktiivinenproteiini,vieritutkimus | mg/l | 30% | name+unit | 53 | 0 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 89 | p-c-reaktiivinenproteiini,vieritutkimus |  | 70% | name | 122 | 50.82 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 90 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 63% | name+unit+values | 202 | 0 | [4.03, 6.98, 10.47, 16.6, 21.86, 29.42, 49.79, 68.66, 100] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 91 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 37% | name | 120 | 71.67 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 92 | p-c-reaktiivinenproteiini.pika |  | 100% | name+values | 316 | 20.25 | [3.75, 6.98, 11.68, 15.55, 24.24, 38.44, 58.74, 89.38, 117.91] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 93 | p-c-reaktiivinenproteiinipikahoitoyksiköt | mg/l | 71% | name+unit+values | 4601 | 0 | [5.2, 7.99, 12.13, 17.43, 25.81, 37.54, 54.45, 78.12, 113.86] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 94 | p-c-reaktiivinenproteiinipikahoitoyksiköt |  | 29% | name+values | 1925 | 80.52 | [1.18, 1.4, 1.83, 2.44, 3.17, 4.31, 5.83, 6.68, 8.76] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 95 | p-c-reaktiivinenproteiinipikamittari |  | 100% | name+values | 399 | 36.09 | [7, 9.06, 12.92, 21.23, 28.43, 42.17, 58.76, 81.22, 122.07] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 96 | pikatesti,c-reaktiivinenproteiini | mg/l | 45% | name+unit+values | 315 | 0 | [6, 7.85, 10.56, 14.36, 20.22, 31.25, 44.62, 61.43, 91.59] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 97 | pikatesti,c-reaktiivinenproteiini |  | 55% | name | 386 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 98 | plasmanc-reaktiivinenproteiiniosoitus | 1 | 1% | name+unit | 36 | 0 |  |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 99 | plasmanc-reaktiivinenproteiiniosoitus | mg/l | 55% | name+unit+values | 3255 | 0 | [6.24, 8.99, 12.45, 17.72, 25.65, 35.96, 50.8, 70.36, 106.56] |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 100 | plasmanc-reaktiivinenproteiiniosoitus |  | 44% | name | 2589 | 98.42 |  |  |  |  | C-reactive protein [Mass/volume] in Plasma |
| 101 | s-c-reaktiivinenproteiini | mg/l | 86% | name+unit+values | 773 | 0 | [0.4, 0.73, 1.08, 1.43, 1.93, 2.88, 4.71, 7.16, 16.64] |  | Serum |  | C-reactive protein [Mass/volume] in Serum |
| 102 | s-c-reaktiivinenproteiini |  | 14% | name | 121 | 100 |  |  | Serum |  | C-reactive protein [Mass/volume] in Serum |
| 103 | s-c-reaktiivinenproteiini,herkkä | mg/l | 96% | name+unit+values | 813 | 0 | [0.39, 0.59, 0.83, 1.22, 1.67, 2.46, 3.62, 5.63, 9.01] |  | Serum |  | C-reactive protein.high sensitivity [Mass/volume] in Serum |
| 104 | s-c-reaktiivinenproteiini,herkkä |  | 4% | name | 34 | 100 |  |  | Serum |  | C-reactive protein.high sensitivity [Mass/volume] in Serum |
| 105 | s-c-reaktiivinenproteiini,pika | mg/l | 28% | name+unit+values | 77 | 0 | [8, 10, 12.4, 14.7, 17, 20.05, 27.4, 35, 48] |  | Serum |  | C-reactive protein [Mass/volume] in Serum |
| 106 | s-c-reaktiivinenproteiini,pika |  | 72% | name | 199 | 75.88 |  |  | Serum |  | C-reactive protein [Mass/volume] in Serum |
| 107 | s-c-reaktiivinenproteiini/ | mg/l | 97% | name+unit+values | 191 | 0 | [0.31, 0.5, 0.7, 0.96, 1.46, 2.27, 3.04, 4.65, 10.16] |  | Serum |  | C-reactive protein [Mass/volume] in Serum |
| 108 | s-c-reaktiivinenproteiini/ |  | 3% | name | 5 | 100 |  |  | Serum |  | C-reactive protein [Mass/volume] in Serum |

