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
Here is group 89.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3021119 | Calcium.ionized [Moles/volume] in Blood | 1.000 | 130 |
| 3021347 | Calcium.ionized [Moles/volume] in Serum or Plasma | 1.000 | 182 |
| 3033705 | Calcium.ionized [Moles/volume] in Venous blood | 1.000 |  |
| 3035279 | Calcium.ionized [Moles/volume] in Capillary blood | 1.000 |  |
| 3044331 | Calcium.ionized [Moles/volume] in Arterial blood | 1.000 |  |
| 3046516 | Calcium.ionized [Moles/volume] in Dialysis fluid | 1.000 |  |
| 3041671 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Venous blood | 0.978 |  |
| 3039602 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Capillary blood | 0.977 |  |
| 3048816 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Blood | 0.976 |  |
| 3041706 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Arterial blood | 0.975 |  |
| 3016431 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Serum or Plasma | 0.973 |  |
| 3023183 | Ammonium ion [Moles/volume] in Plasma | 0.951 |  |
| 40762533 | Calcium.ionized [Mass/volume] in Venous blood | 0.944 |  |
| 3021197 | Magnesium Ionized [Moles/volume] in Serum or Plasma | 0.943 |  |
| 3027694 | Calcium.ionized [Mass/volume] in Serum or Plasma | 0.940 |  |
| 3015774 | Calcium.ionized [Moles/volume] in Serum or Plasma by calculation | 0.934 |  |
| 40762532 | Calcium.ionized [Mass/volume] in Arterial blood | 0.932 |  |
| 3013784 | Calcium.ionized [Moles/volume] in Serum or Plasma by Ion-selective membrane electrode (ISE) | 0.930 | 1045 |
| 3002991 | Calcium [Moles/volume] in Dialysis fluid | 0.928 |  |
| 3036426 | Calcium.ionized [Mass/volume] in Blood | 0.927 |  |
| 3032271 | Calcium.ionized [Moles/volume] in Mixed venous blood | 0.922 |  |
| 3032543 | Calcium [Moles/volume] in Venous blood | 0.915 |  |
| 647174 | Calcium.ionized [Measurement] in Serum or Plasma | 0.913 |  |
| 3039352 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Nonbiological fluid | 0.912 |  |
| 3029431 | Calcium.ionized [Moles/volume] in Body fluid | 0.911 |  |
| 3031020 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Body fluid | 0.911 |  |
| 1092214 | Calcium [Moles/volume] in Arterial blood | 0.909 |  |
| 3022592 | Ammonium ion [Moles/volume] in Arterial blood | 0.905 |  |
| 3034988 | Calcium [Moles/volume] in Capillary blood | 0.905 |  |
| 3015377 | Calcium [Moles/volume] in Serum or Plasma | 0.904 | 12 |
| 40757497 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Cord blood | 0.901 |  |
| 40757498 | Calcium.ionized [Moles/volume] in Cord blood | 0.891 |  |
| 3015205 | Calcium.ionized [Moles/volume] in Serum or Plasma --5th specimen post XXX challenge | 0.884 |  |
| 3042811 | Magnesium Ionized [Mass/volume] in Serum or Plasma | 0.882 |  |
| 3011958 | Ammonia [Moles/volume] in Plasma | 0.874 | 367 |
| 3012095 | Magnesium [Moles/volume] in Serum or Plasma | 0.869 | 78 |
| 3036773 | Calcium [Mass/volume] in Dialysis fluid | 0.863 |  |
| 3005347 | Ammonia [Moles/volume] in Blood | 0.861 |  |
| 42529185 | Calcium.ionized [Moles/volume] in Blood drawn from CRRT circuit | 0.847 |  |
| 3049241 | Calcium [Moles/volume] in Peritoneal dialysis fluid | 0.842 |  |
| 43533595 | Magnesium Ionized [Moles/volume] in Blood by Ion-selective membrane electrode (ISE) | 0.837 |  |
| 3018418 | pH of Serum or Plasma | 0.831 | 160 |
| 3033836 | Magnesium [Moles/volume] in Blood | 0.821 |  |
| 1002144 | Ammonia [Moles/volume] in Arterial blood | 0.819 |  |
| 3000092 | Ammonia [Moles/volume] in Body fluid | 0.818 |  |
| 43533596 | Magnesium Ionized [Moles/volume] adjusted to pH 7.4 in Blood by Ion-selective membrane electrode (ISE) | 0.815 |  |
| 3030942 | Ammonia [Mass/volume] in Blood | 0.808 |  |
| 3036887 | Ammonia [Mass/volume] in Plasma | 0.806 | 366 |
| 3001420 | Magnesium [Mass/volume] in Serum or Plasma | 0.797 |  |
| 3015711 | Magnesium [Moles/volume] in Body fluid | 0.784 |  |
| 3025665 | Magnesium [Moles/volume] in Specimen | 0.778 |  |
| 3030308 | Hydrogen ion [Moles/volume] in Blood | 0.773 |  |
| 3016238 | Ammonia [Moles/volume] in Urine | 0.770 |  |
| 649292 | Ammonia [Measurement] in Plasma | 0.767 |  |
| 3030171 | Hydrogen ion [Moles/volume] in Serum or Plasma | 0.749 |  |
| 3039586 | Ammonia [Moles/volume] in Dialysis fluid | 0.740 |  |
| 3038908 | pH of Blood product unit | 0.728 |  |
| 3019715 | Histidine [Units/volume] in Serum or Plasma | 0.702 |  |
| 3002342 | Phenylalanine [Units/volume] in Serum or Plasma | 0.689 |  |
| 3016293 | Bicarbonate [Moles/volume] in Serum or Plasma | 0.673 |  |
| 3023623 | Histidine [Mass/volume] in Serum or Plasma | 0.668 |  |
| 3019225 | pH of Specimen | 0.667 |  |
| 3013441 | Alpha subunit [Units/volume] in Serum or Plasma | 0.666 |  |
| 3019508 | Histamine [Mass/volume] in Serum or Plasma | 0.666 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1451 | ab-ca++7.4 | mmol/l | 100% | name+unit+values | 1106 | 0 | [1.08, 1.12, 1.14, 1.16, 1.18, 1.2, 1.21, 1.23, 1.26] |  | Arterial blood |  | Calcium.ionized [Moles/volume] in Arterial blood adjusted to pH 7.4 |
| 1452 | ab-ca-i7.4 | mmol/l | 87% | name+unit+values | 52168 | 0 | [1, 1.05, 1.08, 1.1, 1.13, 1.15, 1.17, 1.2, 1.24] |  | Arterial blood |  | Calcium.ionized [Moles/volume] in Arterial blood adjusted to pH 7.4 |
| 1453 | ab-ca-i7.4 |  | 13% | name | 8114 | 100 |  |  | Arterial blood |  | Calcium.ionized [Moles/volume] in Arterial blood adjusted to pH 7.4 |
| 1454 | ab-ca-ion | mmol/l | 87% | name+unit+values | 52238 | 0 | [1, 1.04, 1.07, 1.1, 1.12, 1.14, 1.16, 1.18, 1.22] |  | Arterial blood | Ionized | Calcium.ionized [Moles/volume] in Arterial blood |
| 1455 | ab-ca-ion |  | 13% | name | 8098 | 100 |  |  | Arterial blood | Ionized | Calcium.ionized [Moles/volume] in Arterial blood |
| 1456 | ab-caionvt | mmol/l | 40% | name+unit+values | 84 | 1.19 | [1.12, 1.15, 1.18, 1.18, 1.2, 1.21, 1.22, 1.24, 1.28] |  | Arterial blood |  | Calcium.ionized [Moles/volume] in Arterial blood |
| 1457 | ab-caionvt |  | 60% | name+values | 124 | 100 | [1.1, 1.14, 1.15, 1.17, 1.19, 1.2, 1.23, 1.25, 1.28] |  | Arterial blood |  | Calcium.ionized [Moles/volume] in Arterial blood |
| 1458 | ap-ca-ion | mmol/l | 94% | name+unit+values | 1484 | 0 | [1.08, 1.11, 1.13, 1.14, 1.16, 1.17, 1.19, 1.2, 1.23] |  |  | Ionized | Calcium.ionized [Moles/volume] in Arterial plasma |
| 1459 | ap-ca-ion |  | 6% | name | 102 | 100 |  |  |  | Ionized | Calcium.ionized [Moles/volume] in Arterial plasma |
| 1460 | b-caionpf | mmol/l | 85% | name+unit | 652 | 0 |  |  | Blood |  | Calcium.ionized [Moles/volume] in Blood |
| 1461 | b-caionpf |  | 15% | name | 111 | 100 |  |  | Blood |  | Calcium.ionized [Moles/volume] in Blood |
| 1462 | ca++/7.40 | mmol/l | 100% | name+unit+values | 126152 | 0 | [1.14, 1.19, 1.2, 1.22, 1.23, 1.25, 1.26, 1.28, 1.31] |  |  |  | Calcium.ionized [Moles/volume] in Serum or Plasma adjusted to pH 7.4 |
| 1463 | ca++/7.40 |  | 0% | name | 569 | 100 |  |  |  |  | Calcium.ionized [Moles/volume] in Serum or Plasma adjusted to pH 7.4 |
| 1464 | ca++/ph7.4 | mmol/l | 97% | name+unit+values | 18482 | 0 | [1.1, 1.15, 1.18, 1.2, 1.22, 1.23, 1.25, 1.27, 1.31] |  |  |  | Calcium.ionized [Moles/volume] in Serum or Plasma adjusted to pH 7.4 |
| 1465 | ca++/ph7.4 |  | 3% | name+values | 588 | 100 | [1.08, 1.12, 1.13, 1.14, 1.15, 1.16, 1.21, 1.26, 1.34] |  |  |  | Calcium.ionized [Moles/volume] in Serum or Plasma adjusted to pH 7.4 |
| 1466 | ca++ph7.4 | mmol/l | 99% | name+unit+values | 16678 | 0 | [1.13, 1.16, 1.18, 1.2, 1.22, 1.23, 1.24, 1.26, 1.29] |  |  |  | Calcium.ionized [Moles/volume] in Serum or Plasma adjusted to pH 7.4 |
| 1467 | ca++ph7.4 |  | 1% | name | 184 | 100 |  |  |  |  | Calcium.ionized [Moles/volume] in Serum or Plasma adjusted to pH 7.4 |
| 1468 | ca-ion | mmol/l | 100% | name+unit+values | 126458 | 0 | [1.15, 1.19, 1.21, 1.23, 1.24, 1.26, 1.27, 1.29, 1.33] |  |  | Ionized | Calcium.ionized [Moles/volume] in Serum or Plasma |
| 1469 | ca-ion |  | 0% | name | 549 | 100 |  |  |  | Ionized | Calcium.ionized [Moles/volume] in Serum or Plasma |
| 1470 | cb-ca-i7.4 | mmol/l | 89% | name+unit+values | 1450 | 0 | [1.11, 1.15, 1.17, 1.19, 1.21, 1.22, 1.23, 1.25, 1.29] |  | Capillary blood |  | Calcium.ionized [Moles/volume] in Capillary blood adjusted to pH 7.4 |
| 1471 | cb-ca-i7.4 |  | 11% | name | 185 | 100 |  |  | Capillary blood |  | Calcium.ionized [Moles/volume] in Capillary blood adjusted to pH 7.4 |
| 1472 | cb-ca-ion | mmol/l | 88% | name+unit+values | 1880 | 0 | [1.11, 1.15, 1.17, 1.19, 1.2, 1.22, 1.24, 1.26, 1.3] |  | Capillary blood | Ionized | Calcium.ionized [Moles/volume] in Capillary blood |
| 1473 | cb-ca-ion |  | 12% | name | 250 | 100 |  |  | Capillary blood | Ionized | Calcium.ionized [Moles/volume] in Capillary blood |
| 1474 | cp-ca-ion | mmol/l | 92% | name+unit+values | 307 | 0 | [1.04, 1.1, 1.13, 1.15, 1.16, 1.18, 1.2, 1.22, 1.25] |  |  | Ionized | Calcium.ionized [Moles/volume] in Capillary plasma |
| 1475 | cp-ca-ion |  | 8% | name | 28 | 100 |  |  |  | Ionized | Calcium.ionized [Moles/volume] in Capillary plasma |
| 1476 | di-ca-ion | mmol/l | 98% | name+unit | 450 | 0 |  |  | Dialysis fluid | Ionized | Calcium.ionized [Moles/volume] in Dialysis fluid |
| 1477 | di-ca-ion |  | 2% | name | 8 | 100 |  |  | Dialysis fluid | Ionized | Calcium.ionized [Moles/volume] in Dialysis fluid |
| 1478 | di-ca-iona | mmol/l | 100% | name+unit | 456 | 0 |  |  | Dialysis fluid |  | Calcium.ionized [Moles/volume] in Dialysis fluid |
| 1479 | fb-nh4-ion | umol/l | 81% | name+unit+values | 298 | 0 | [11, 13.44, 17.68, 24.49, 31.79, 42.13, 54.77, 72.94, 100.99] | fB-Ammonium-ioni | Fasting blood; Foreign body / implant | Ionized | Ammonium.ionized [Moles/volume] in Blood |
| 1480 | fb-nh4-ion |  | 19% | name | 69 | 100 |  | fB-Ammonium-ioni | Fasting blood; Foreign body / implant | Ionized | Ammonium.ionized [Moles/volume] in Blood |
| 1481 | fp-ca-ion | mmol/l | 99% | name+unit+values | 1040 | 0 | [1.12, 1.15, 1.17, 1.19, 1.2, 1.21, 1.23, 1.25, 1.28] |  | Fasting plasma | Ionized | Calcium.ionized [Moles/volume] in Plasma |
| 1482 | fp-ca-ion |  | 1% | name | 8 | 100 |  |  | Fasting plasma | Ionized | Calcium.ionized [Moles/volume] in Plasma |
| 1483 | fp-ca-ion. | mmol/l | 99% | name+unit+values | 22635 | 0.13 | [1.05, 1.09, 1.11, 1.13, 1.15, 1.16, 1.18, 1.2, 1.23] |  | Fasting plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1484 | fp-ca-ion. |  | 1% | name | 196 | 100 |  |  | Fasting plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1485 | fp-ca-iona | mmol/l | 97% | name+unit+values | 383 | 0 | [1.16, 1.19, 1.2, 1.21, 1.22, 1.23, 1.25, 1.26, 1.29] |  | Fasting plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1486 | fp-ca-iona |  | 3% | name | 13 | 100 |  |  | Fasting plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1487 | fp-nh4-ion | umol/l | 90% | name+unit+values | 22919 | 0 | [17.32, 22.53, 27.24, 32.28, 37.91, 44.96, 54.51, 68.52, 92.89] | fP-Ammonium-ioni | Fasting plasma | Ionized | Ammonium.ionized [Moles/volume] in Plasma |
| 1488 | fp-nh4-ion |  | 10% | name+values | 2418 | 100 | [18.27, 23.76, 29.8, 37.05, 45.85, 55.82, 65.3, 79.23, 103.94] | fP-Ammonium-ioni | Fasting plasma | Ionized | Ammonium.ionized [Moles/volume] in Plasma |
| 1489 | fs-ca++/7.40 |  | 100% | name+values | 10897 | 100 | [1.18, 1.21, 1.22, 1.23, 1.24, 1.25, 1.27, 1.28, 1.32] |  | Fasting serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1490 | fs-ca++7.4 | mmol/l | 99% | name+unit+values | 8087 | 0 | [1.15, 1.19, 1.21, 1.22, 1.23, 1.25, 1.26, 1.28, 1.33] |  | Fasting serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1491 | fs-ca++7.4 |  | 1% | name | 47 | 100 |  |  | Fasting serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1492 | fs-ca-7.40 | mmol/l | 100% | name+unit+values | 987 | 0 | [1.19, 1.23, 1.25, 1.26, 1.28, 1.29, 1.31, 1.34, 1.38] |  | Fasting serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1493 | fs-ca-ion | mmol/l | 39% | name+unit+values | 21952 | 0 | [1.18, 1.2, 1.22, 1.24, 1.25, 1.26, 1.28, 1.3, 1.34] |  | Fasting serum | Ionized | Calcium.ionized [Moles/volume] in Serum |
| 1494 | fs-ca-ion |  | 61% | name | 33916 | 100 |  |  | Fasting serum | Ionized | Calcium.ionized [Moles/volume] in Serum |
| 1495 | fs-ca-ion/ph7.40 | mmol/l | 99% | name+unit+values | 27031 | 0 | [1.13, 1.17, 1.19, 1.21, 1.23, 1.24, 1.25, 1.27, 1.31] |  | Fasting serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1496 | fs-ca-ion/ph7.40 |  | 1% | name+values | 232 | 100 | [1.14, 1.31, 1.32, 1.33, 1.33, 1.34, 1.36, 1.38, 1.42] |  | Fasting serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1497 | fs-ca-iona | mmol/l | 87% | name+unit+values | 1052 | 0 | [1.14, 1.17, 1.19, 1.2, 1.22, 1.23, 1.25, 1.28, 1.35] |  | Fasting serum |  | Calcium.ionized [Moles/volume] in Serum |
| 1498 | fs-ca-iona |  | 13% | name+values | 162 | 100 | [1.15, 1.16, 1.18, 1.19, 1.2, 1.21, 1.22, 1.24, 1.29] |  | Fasting serum |  | Calcium.ionized [Moles/volume] in Serum |
| 1499 | fs-ph(ca-ion) |  | 100% | name+values | 1713 | 100 | [7.33, 7.35, 7.37, 7.38, 7.39, 7.4, 7.41, 7.42, 7.44] |  | Fasting serum |  | pH [Units] in Serum |
| 1500 | mb-ca(7.4) | mmol/l | 96% | name+unit | 2502 | 0 |  |  |  |  | Calcium.ionized [Moles/volume] in Blood adjusted to pH 7.4 |
| 1501 | mb-ca(7.4) |  | 4% | name | 108 | 100 |  |  |  |  | Calcium.ionized [Moles/volume] in Blood adjusted to pH 7.4 |
| 1502 | mb-ca-ion | mmol/l | 96% | name+unit | 2504 | 0 |  |  |  | Ionized | Calcium.ionized [Moles/volume] in Blood |
| 1503 | mb-ca-ion |  | 4% | name | 105 | 100 |  |  |  | Ionized | Calcium.ionized [Moles/volume] in Blood |
| 1504 | p-ca(7.4) | mmol/l | 95% | name+unit+values | 23257 | 0 | [1.1, 1.14, 1.16, 1.17, 1.18, 1.2, 1.21, 1.23, 1.26] |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma adjusted to pH 7.4 |
| 1505 | p-ca(7.4) |  | 5% | name | 1266 | 100 |  |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma adjusted to pH 7.4 |
| 1506 | p-ca-ion | mmol/l | 28% | name+unit+values | 37155 | 0 | [1.09, 1.13, 1.15, 1.17, 1.18, 1.2, 1.21, 1.23, 1.27] | P -Kalsium, ionisoitunut | Plasma | Ionized | Calcium.ionized [Moles/volume] in Plasma |
| 1507 | p-ca-ion |  | 72% | name+values | 93247 | 100 | [1.1, 1.13, 1.16, 1.18, 1.2, 1.21, 1.25, 1.29, 1.33] | P -Kalsium, ionisoitunut | Plasma | Ionized | Calcium.ionized [Moles/volume] in Plasma |
| 1508 | p-ca-ion. | mmol/l | 100% | name+unit+values | 360997 | 0 | [1.03, 1.08, 1.11, 1.13, 1.16, 1.18, 1.2, 1.22, 1.26] |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1509 | p-ca-ion. |  | 0% | name | 756 | 100 |  |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1510 | p-ca-ion: | mmol/l | 100% | name+unit+values | 626 | 0 | [1.1, 1.14, 1.15, 1.17, 1.18, 1.19, 1.2, 1.22, 1.24] |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1511 | p-ca-iona | mmol/l | 100% | name+unit+values | 409206 | 0.01 | [1.04, 1.08, 1.11, 1.13, 1.15, 1.17, 1.19, 1.21, 1.25] |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1512 | p-ca-iona |  | 0% | name | 882 | 100 |  |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1513 | p-caio7.4: | mmol/l | 100% | name+unit+values | 608 | 0 | [1.1, 1.13, 1.15, 1.17, 1.19, 1.2, 1.21, 1.23, 1.25] |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma adjusted to pH 7.4 |
| 1514 | p-caion7.4 | mmol/l | 54% | name+unit | 58 | 0 |  |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma adjusted to pH 7.4 |
| 1515 | p-caion7.4 |  | 46% | name | 49 | 100 |  |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma adjusted to pH 7.4 |
| 1516 | p-nh4-ion | umol/l | 86% | name+unit+values | 1298 | 0 | [24, 30.04, 34.97, 40.74, 46.76, 54.98, 66.47, 82.91, 111.7] |  | Plasma | Ionized | Ammonium.ionized [Moles/volume] in Plasma |
| 1517 | p-nh4-ion |  | 14% | name+values | 208 | 100 | [23, 29.64, 34, 40.9, 50.07, 57.7, 72.1, 92.36, 125.65] |  | Plasma | Ionized | Ammonium.ionized [Moles/volume] in Plasma |
| 1518 | s-ca(7.4) | mmol/l | 99% | name+unit+values | 132501 | 0 | [1.13, 1.17, 1.19, 1.21, 1.23, 1.24, 1.25, 1.27, 1.31] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1519 | s-ca(7.4) | nmol/l | 0% | name+unit+values | 93 | 0 | [1.18, 1.21, 1.23, 1.24, 1.25, 1.26, 1.28, 1.3, 1.37] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1520 | s-ca(7.4) |  | 1% | name | 1609 | 100 |  |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1521 | s-ca++/7.40 |  | 100% | name+values | 5887 | 100 | [1.18, 1.2, 1.21, 1.23, 1.24, 1.25, 1.26, 1.28, 1.32] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1522 | s-ca-17.4 | mmol/l | 100% | name+unit+values | 835 | 0 | [1.18, 1.21, 1.22, 1.24, 1.25, 1.27, 1.28, 1.3, 1.33] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1523 | s-ca-i7.4 | mmol/l | 92% | name+unit+values | 46811 | 0 | [1.17, 1.2, 1.22, 1.24, 1.25, 1.27, 1.28, 1.3, 1.34] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1524 | s-ca-i7.4 |  | 8% | name | 4102 | 100 |  |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1525 | s-ca-ion | mmol/l | 72% | name+unit+values | 507827 | 0 | [1.14, 1.18, 1.2, 1.21, 1.23, 1.24, 1.26, 1.28, 1.32] | S -Kalsium, ionisoitunut | Serum | Ionized | Calcium.ionized [Moles/volume] in Serum |
| 1526 | s-ca-ion |  | 28% | name | 192950 | 100 |  | S -Kalsium, ionisoitunut | Serum | Ionized | Calcium.ionized [Moles/volume] in Serum |
| 1527 | s-ca-iona | mmol/l | 99% | name+unit+values | 394912 | 0 | [1.14, 1.18, 1.2, 1.22, 1.23, 1.25, 1.26, 1.29, 1.32] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum |
| 1528 | s-ca-iona |  | 1% | name | 2820 | 100 |  |  | Serum |  | Calcium.ionized [Moles/volume] in Serum |
| 1529 | s-caio7.4 | mmol/l | 100% | name+unit+values | 860 | 0 | [1.17, 1.2, 1.22, 1.23, 1.25, 1.26, 1.28, 1.3, 1.35] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1530 | s-caion7.4 | mmol/l | 99% | name+unit+values | 5310 | 0 | [1.16, 1.19, 1.21, 1.22, 1.23, 1.24, 1.25, 1.27, 1.29] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1531 | s-caion7.4 |  | 1% | name | 57 | 100 |  |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1532 | s-caionac | mmol/l | 98% | name+unit+values | 863 | 0 | [1.16, 1.2, 1.22, 1.23, 1.25, 1.26, 1.28, 1.3, 1.34] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum |
| 1533 | s-caionac |  | 2% | name | 15 | 100 |  |  | Serum |  | Calcium.ionized [Moles/volume] in Serum |
| 1534 | s-caph7.4 | mmol/l | 99% | name+unit+values | 5238 | 0 | [1.16, 1.19, 1.21, 1.22, 1.23, 1.25, 1.26, 1.28, 1.31] |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1535 | s-caph7.4 |  | 1% | name | 67 | 100 |  |  | Serum |  | Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 |
| 1536 | s-mg-ion | mmol/l | 95% | name+unit+values | 4664 | 0 | [0.5, 0.54, 0.56, 0.58, 0.6, 0.62, 0.64, 0.67, 0.71] |  | Serum | Ionized | Magnesium.ionized [Moles/volume] in Serum |
| 1537 | s-mg-ion |  | 5% | name+values | 253 | 100 | [0.55, 0.58, 0.6, 0.62, 0.63, 0.65, 0.67, 0.69, 0.74] |  | Serum | Ionized | Magnesium.ionized [Moles/volume] in Serum |
| 1538 | vb-ca-i7.4 | mmol/l | 81% | name+unit+values | 2427 | 0 | [0.99, 1.06, 1.1, 1.13, 1.15, 1.17, 1.19, 1.22, 1.26] |  | Venous blood |  | Calcium.ionized [Moles/volume] in Venous blood adjusted to pH 7.4 |
| 1539 | vb-ca-i7.4 |  | 19% | name | 580 | 100 |  |  | Venous blood |  | Calcium.ionized [Moles/volume] in Venous blood adjusted to pH 7.4 |
| 1540 | vb-ca-ion | mmol/l | 81% | name+unit+values | 2428 | 0 | [1.02, 1.08, 1.11, 1.14, 1.16, 1.18, 1.2, 1.22, 1.26] |  | Venous blood | Ionized | Calcium.ionized [Moles/volume] in Venous blood |
| 1541 | vb-ca-ion |  | 19% | name | 567 | 100 |  |  | Venous blood | Ionized | Calcium.ionized [Moles/volume] in Venous blood |
| 1542 | vb-caionvt | 1 | 5% | name+unit | 40 | 0 |  |  | Venous blood |  | Calcium.ionized [Moles/volume] in Venous blood |
| 1543 | vb-caionvt | mmol/l | 40% | name+unit+values | 308 | 0 | [1.1, 1.13, 1.15, 1.18, 1.19, 1.21, 1.22, 1.24, 1.27] |  | Venous blood |  | Calcium.ionized [Moles/volume] in Venous blood |
| 1544 | vb-caionvt |  | 55% | name+values | 422 | 100 | [1.12, 1.15, 1.17, 1.18, 1.2, 1.22, 1.23, 1.25, 1.27] |  | Venous blood |  | Calcium.ionized [Moles/volume] in Venous blood |
| 1545 | vp-ca-ion | mmol/l | 98% | name+unit+values | 10809 | 0 | [1.13, 1.16, 1.17, 1.19, 1.2, 1.21, 1.23, 1.24, 1.27] |  |  | Ionized | Calcium.ionized [Moles/volume] in Venous plasma |
| 1546 | vp-ca-ion |  | 2% | name | 173 | 100 |  |  |  | Ionized | Calcium.ionized [Moles/volume] in Venous plasma |

