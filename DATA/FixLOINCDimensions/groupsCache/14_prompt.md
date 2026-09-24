[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

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
- `n_codes` / `n_events` — how many curated Finnish lab codes already map to this concept, and how many records those codes cover. This is usage in Finland.

**The rows table** — one row per local lab test/unit combination:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty.
- `n` — number of records.
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available. The strongest single piece of evidence for what a test really measures and in which units: a "sodium" code whose deciles read 0.32-0.40 is not sodium in mmol/l.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess. A hypothesis to test against the row's own evidence, not an instruction.
- `is_panel` — whether the earlier pass judged the code to order a bundle of tests rather than report one result.

# How to decide

For each row:

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
2. **Pick the candidate that matches that reading**, and return its `omop_concept_id`. The unit and the deciles decide between candidates that differ only in property: `mmol/l` takes `[Moles/volume]`, `g/l` takes `[Mass/volume]`, `U/l` takes `[Enzymatic activity/volume]`. The prefix decides the specimen; remember that LOINC's `Serum or Plasma` is the right term for most routine chemistry, and that fasting is not part of the specimen (`fS` is still serum).
3. **When two or more candidates fit the evidence equally well**, break the tie in this order:
   1. **Prefer a candidate with a `top2000` rank.** That list is LOINC's own recommendation for what laboratories should map to, so a concept on it is the intended target and a near-duplicate off it usually is not.
   2. **Then prefer the higher `n_codes` / `n_events`.** Finland already maps real codes to that concept; matching established national usage keeps this data joinable with what exists.

   These break ties. They never override the row's own evidence: a top-2000 concept in the wrong specimen or the wrong units is still the wrong answer.
4. **Leave `omop_concept_id` empty when no candidate is right.** That is a correct, useful answer — it says "this code has no match in what the search returned", which is a fact the next iteration can act on. Common reasons: the code is too truncated or garbled to identify; it is a local administrative or non-laboratory code; or the search simply did not return the concept you know is right.
5. **Never return an id that is not in the candidate table.** Not one you remember, not one you derive from a LOINC code, not a plausible-looking number. Ids that are not in the table are discarded and the row is logged as unanswered, so inventing one only loses the row.

Specific things to watch:

- **A panel is not its components.** If the code orders a bundle (`B-PVK` = full blood count, `U-KemSeul` = urine dipstick screen), the answer is the panel concept (`CBC panel - Blood by Automated count`), not hemoglobin. Conversely, do not map a single reported result to a panel concept just because a panel candidate scored well.
- **Deprecated near-duplicates are already filtered out** of the candidate list — every candidate is a standard, current concept — so you never need to judge validity, only fit.
- **The same local code recurs in a group with different `UNIT`s**, and those rows are often genuinely different LOINC concepts. Answer each row from its own unit and deciles; do not give every row of a group the same id out of consistency.
- **Rows whose guess was empty still deserve an answer.** The earlier pass could not name them, but the group's pooled candidates may still contain the right concept.

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `omop_concept_id` — the chosen concept's id, copied from the candidate table. Empty if no candidate is right.
- `omop_concept_name` — that candidate's `omop_concept_name`, copied verbatim. Used only to cross-check that the id you copied is the concept you meant; leave it empty when the id is empty.
- `is_panel` — carried through from the input row unless the row is plainly contradictory.

Return an entry for EVERY row, including ones you leave unmapped.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which rows you could map and which you could not, where the candidate list was missing the concept you knew was right, where the earlier pass's guess sent the search astray, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 14.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 1.000 | 154 | 159 | 6,802,841 |
| 1091617 | C reactive protein [Mass/volume] in Serum, Plasma or Blood | 0.966 |  |   0 |         0 |
| 3010156 | C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method | 0.924 | 348 |  19 |    28,709 |
| 46234770 | C reactive protein [Moles/volume] in Serum or Plasma | 0.918 |  |   0 |         0 |
| 648940 | C reactive protein [Measurement] in Serum or Plasma | 0.900 |  |   0 |         0 |
| 3051387 | C reactive protein [Mass/volume] in Capillary blood | 0.889 |  |   9 |    30,338 |
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.888 |  |   0 |         0 |
| 3028766 | C reactive protein [Titer] in Serum or Plasma | 0.881 |  |   0 |         0 |
| 3035320 | C reactive protein [Mass/volume] in Body fluid | 0.879 |  |   6 |     9,479 |
| 42870365 | C reactive protein [Mass/volume] in Blood by High sensitivity method | 0.871 |  |   4 |    10,574 |
| 3000965 | C reactive protein [Presence] in Serum or Plasma | 0.870 | 1281 |   0 |         0 |
| 46234771 | C reactive protein [Moles/volume] in Serum or Plasma by High sensitivity method | 0.853 |  |   0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 23 | b-c-reaktiivinenproteiini | mg/l | 29 | 0 |  |  | Blood |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 24 | b-c-reaktiivinenproteiini |  | 262 | 44.27 | [6, 7.5, 10.67, 13.8, 18.67, 27.69, 37.44, 56, 84] |  | Blood |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 25 | b-c-reaktiivinenproteiinipika |  | 300 | 37 | [7, 10.22, 14.84, 20.3, 29.2, 37.52, 52.47, 75.48, 99.1] |  | Blood |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 26 | b-c-resktiivinenproteiini | mg/l | 1201 | 0 | [6, 8.11, 11.16, 14.7, 19.67, 26.61, 38.65, 58.3, 91.79] |  | Blood |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 27 | b-c-resktiivinenproteiini |  | 802 | 92.39 |  |  | Blood |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 28 | c-reaktiivinenproteiini | 1 | 925 | 0 | [6.19, 8.89, 11.99, 16.88, 23.76, 35.33, 49.12, 74.41, 108.21] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 29 | c-reaktiivinenproteiini | mg/l | 7963 | 0 | [4.01, 6.22, 9.5, 14.46, 23.15, 35.25, 51.85, 77.94, 126.36] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 30 | c-reaktiivinenproteiini |  | 7083 | 90.23 | [6.55, 8.84, 11.73, 17.15, 24.37, 37.67, 52.72, 72.92, 107.1] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 31 | c-reaktiivinenproteiini(4594p-crp) | mg/l | 143 | 0 | [1, 1.79, 2, 2, 3, 4, 5, 6, 12.8] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 32 | c-reaktiivinenproteiini(4594p-crp) |  | 74 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 33 | c-reaktiivinenproteiini(crp) | mg/l | 381 | 0 | [1.23, 1.51, 1.92, 2.62, 3.36, 4.75, 6.13, 9.98, 21.06] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 34 | c-reaktiivinenproteiini(crp) |  | 250 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 35 | c-reaktiivinenproteiini(p-crp) | mg/l | 500 | 0 | [1, 2, 2, 2.85, 3.14, 4.26, 5.94, 8.93, 19.54] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 36 | c-reaktiivinenproteiini(p-crp) |  | 261 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 37 | c-reaktiivinenproteiini,herkkä | mg/l | 254 | 0 | [0.22, 0.41, 0.57, 0.84, 1.15, 1.65, 2.42, 3.86, 6.33] |  |  |  | C reactive protein.high sensitivity [Mass/volume] in Serum or Plasma | FALSE |
| 38 | c-reaktiivinenproteiini,herkkä |  | 18 | 94.44 |  |  |  |  | C reactive protein.high sensitivity [Mass/volume] in Serum or Plasma | FALSE |
| 39 | c-reaktiivinenproteiini,herkkä,seerumista | mg/l | 7396 | 0 | [0.28, 0.41, 0.6, 0.78, 1.03, 1.34, 1.83, 2.72, 4.64] |  |  |  | C reactive protein.high sensitivity [Mass/volume] in Serum or Plasma | FALSE |
| 40 | c-reaktiivinenproteiini,herkkä,seerumista |  | 36 | 83.33 |  |  |  |  | C reactive protein.high sensitivity [Mass/volume] in Serum or Plasma | FALSE |
| 41 | c-reaktiivinenproteiini,pika | mg/l | 111 | 0 | [5, 5.05, 6.2, 8.27, 11.67, 14.3, 22.37, 36.1, 57] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 42 | c-reaktiivinenproteiini,pika |  | 49 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 43 | c-reaktiivinenproteiini,pika,tehdäänitse | mg/l | 997 | 0 | [5, 5, 6.35, 8.12, 10.93, 14.99, 21.14, 34.44, 53.73] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 44 | c-reaktiivinenproteiini,pika,tehdäänitse |  | 820 | 99.27 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 45 | c-reaktiivinenproteiini,pikatesti,veri | mg/l | 174 | 0 | [6, 7, 8.95, 10.5, 16.42, 22.45, 35.5, 53.5, 98.67] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 46 | c-reaktiivinenproteiini,pikatesti,veri |  | 1656 | 42.69 | [6.55, 9.61, 13.21, 19.27, 27.67, 39.17, 52.81, 73.29, 109.39] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 47 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) | mg/l | 803 | 0 | [4.99, 5.34, 7.17, 9.24, 13.4, 18.77, 28.88, 45.54, 76.31] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 48 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) |  | 240 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 49 | c-reaktiivinenproteiini,pikatutkimus | mg/l | 106 | 0 | [7, 12, 15.43, 21.6, 30.72, 39.4, 56.9, 87, 115.33] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 50 | c-reaktiivinenproteiini,pikatutkimus |  | 66 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 51 | c-reaktiivinenproteiini,plasmasta,vieritesti | mg/l | 699 | 0 | [5.17, 7.91, 10.75, 16.58, 23.68, 33.24, 48.01, 64.98, 99.29] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 52 | c-reaktiivinenproteiini,plasmasta,vieritesti |  | 274 | 94.89 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 53 | c-reaktiivinenproteiini,tk:ntekemä |  | 1605 | 13.4 | [2.23, 4.3, 7.78, 12.46, 19.91, 29.72, 46.58, 66.7, 98.89] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 54 | c-reaktiivinenproteiini,vieritesti | mg/l | 47 | 0 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 55 | c-reaktiivinenproteiini,vieritesti |  | 944 | 23.62 | [3.08, 5.45, 7.93, 11.11, 14.9, 20.87, 29.7, 49.04, 81.9] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 56 | c-reaktiivinenproteiini,vieritutkimus | mg/l | 525 | 0 | [5, 6.72, 8.66, 12.22, 15.93, 22.09, 35.26, 59.08, 89.7] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 57 | c-reaktiivinenproteiini,vieritutkimus |  | 631 | 58.8 | [6.41, 9.32, 15.53, 22.99, 35.64, 49.47, 62.97, 81.83, 113.06] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 58 | c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 1205 | 0 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 59 | c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 318 | 100 | [4.71, 7.37, 11.52, 16.21, 23.22, 31.65, 45.13, 65.98, 97.07] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 60 | c-reaktiivinenproteiini,vieritutkimusnordlab | mg/l | 92 | 0 | [5, 6, 8, 10.7, 12.75, 16.2, 21, 31.5, 47] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 61 | c-reaktiivinenproteiini,vieritutkimusnordlab |  | 99 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 62 | c-reaktiivinenproteiini-pika(4594crp-pika) | mg/l | 136 | 0 | [5, 5.32, 7, 9, 11.15, 14.57, 19, 33.2, 47.3] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 63 | c-reaktiivinenproteiini-pika(4594crp-pika) |  | 47 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 64 | c-reaktiivinenproteiini-pika(crp-pika) | mg/l | 1488 | 0 | [5, 6.88, 7, 7.34, 10.21, 14.71, 21.39, 32, 54.73] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 65 | c-reaktiivinenproteiini-pika(crp-pika) |  | 505 | 99.8 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 66 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä | mg/l | 1826 | 0 | [1.75, 3.02, 5.68, 9.52, 14.27, 22.77, 34.19, 57.29, 89.46] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 67 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä |  | 497 | 46.88 | [1.2, 1.53, 2.21, 2.84, 3.97, 4.8, 6.15, 7.51, 9.1] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 68 | fs-c-reaktiivinenproteiini | mg/l | 241 | 0 |  |  | Fasting serum |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 69 | fs-c-reaktiivinenproteiini |  | 184 | 100 |  |  | Fasting serum |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 70 | p-c-reaktiininenproteiini,vieritutkimus | mg/l | 258 | 0 | [5.85, 8.85, 11.14, 17.24, 24.49, 35.17, 49.34, 67.54, 96.38] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 71 | p-c-reaktiininenproteiini,vieritutkimus |  | 224 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 72 | p-c-reaktiivinenproteiini | mg/l | 41046 | 0 | [4.18, 7.12, 11.73, 18.09, 27.46, 40.11, 58.4, 87.78, 141.39] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 73 | p-c-reaktiivinenproteiini |  | 24714 | 99.73 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 74 | p-c-reaktiivinenproteiini(kval) | mg/l | 187 | 0 | [6.14, 9.01, 13.88, 18.86, 24.62, 33.54, 47.21, 67.37, 102.4] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 75 | p-c-reaktiivinenproteiini(kval) |  | 142 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 76 | p-c-reaktiivinenproteiini(kval)␤ | mg/l | 111 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 77 | p-c-reaktiivinenproteiini(kval)␤ |  | 130 | 100 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 78 | p-c-reaktiivinenproteiini(pikanäyte) | mg/l | 6 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 79 | p-c-reaktiivinenproteiini(pikanäyte) |  | 352 | 17.33 | [1.52, 2.59, 4.86, 7.54, 12.38, 20.91, 32.04, 56.93, 83.62] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 80 | p-c-reaktiivinenproteiini,crp | mg/l | 110 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 81 | p-c-reaktiivinenproteiini,crp |  | 8 | 62.5 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 82 | p-c-reaktiivinenproteiini,hoitoyksikkö | 1 | 40 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 83 | p-c-reaktiivinenproteiini,hoitoyksikkö | alle | 5 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 84 | p-c-reaktiivinenproteiini,hoitoyksikkö | mg/l | 81 | 0 | [8, 11, 13, 16.2, 22.25, 33.7, 48, 64, 131] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 85 | p-c-reaktiivinenproteiini,hoitoyksikkö |  | 156 | 63.46 | [6, 8, 12, 14, 26, 32, 40, 60, 120] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 86 | p-c-reaktiivinenproteiini,pikatesti | mg/l | 190 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 87 | p-c-reaktiivinenproteiini,pikatesti |  | 3095 | 41.23 | [6.43, 8.8, 12.04, 15.76, 21.17, 29.16, 41.93, 63.64, 96.9] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 88 | p-c-reaktiivinenproteiini,vieritutkimus | mg/l | 53 | 0 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 89 | p-c-reaktiivinenproteiini,vieritutkimus |  | 122 | 50.82 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 90 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 202 | 0 | [4.03, 6.98, 10.47, 16.6, 21.86, 29.42, 49.79, 68.66, 100] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 91 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 120 | 71.67 |  |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 92 | p-c-reaktiivinenproteiini.pika |  | 316 | 20.25 | [3.75, 6.98, 11.68, 15.55, 24.24, 38.44, 58.74, 89.38, 117.91] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 93 | p-c-reaktiivinenproteiinipikahoitoyksiköt | mg/l | 4601 | 0 | [5.2, 7.99, 12.13, 17.43, 25.81, 37.54, 54.45, 78.12, 113.86] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 94 | p-c-reaktiivinenproteiinipikahoitoyksiköt |  | 1925 | 80.52 | [1.18, 1.4, 1.83, 2.44, 3.17, 4.31, 5.83, 6.68, 8.76] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 95 | p-c-reaktiivinenproteiinipikamittari |  | 399 | 36.09 | [7, 9.06, 12.92, 21.23, 28.43, 42.17, 58.76, 81.22, 122.07] |  | Plasma |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 96 | pikatesti,c-reaktiivinenproteiini | mg/l | 315 | 0 | [6, 7.85, 10.56, 14.36, 20.22, 31.25, 44.62, 61.43, 91.59] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 97 | pikatesti,c-reaktiivinenproteiini |  | 386 | 100 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 98 | plasmanc-reaktiivinenproteiiniosoitus | 1 | 36 | 0 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 99 | plasmanc-reaktiivinenproteiiniosoitus | mg/l | 3255 | 0 | [6.24, 8.99, 12.45, 17.72, 25.65, 35.96, 50.8, 70.36, 106.56] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 100 | plasmanc-reaktiivinenproteiiniosoitus |  | 2589 | 98.42 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 101 | s-c-reaktiivinenproteiini | mg/l | 773 | 0 | [0.4, 0.73, 1.08, 1.43, 1.93, 2.88, 4.71, 7.16, 16.64] |  | Serum |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 102 | s-c-reaktiivinenproteiini |  | 121 | 100 |  |  | Serum |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 103 | s-c-reaktiivinenproteiini,herkkä | mg/l | 813 | 0 | [0.39, 0.59, 0.83, 1.22, 1.67, 2.46, 3.62, 5.63, 9.01] |  | Serum |  | C reactive protein.high sensitivity [Mass/volume] in Serum or Plasma | FALSE |
| 104 | s-c-reaktiivinenproteiini,herkkä |  | 34 | 100 |  |  | Serum |  | C reactive protein.high sensitivity [Mass/volume] in Serum or Plasma | FALSE |
| 105 | s-c-reaktiivinenproteiini,pika | mg/l | 77 | 0 | [8, 10, 12.4, 14.7, 17, 20.05, 27.4, 35, 48] |  | Serum |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 106 | s-c-reaktiivinenproteiini,pika |  | 199 | 75.88 |  |  | Serum |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 107 | s-c-reaktiivinenproteiini/ | mg/l | 191 | 0 | [0.31, 0.5, 0.7, 0.96, 1.46, 2.27, 3.04, 4.65, 10.16] |  | Serum |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |
| 108 | s-c-reaktiivinenproteiini/ |  | 5 | 100 |  |  | Serum |  | C reactive protein [Mass/volume] in Serum or Plasma | FALSE |

