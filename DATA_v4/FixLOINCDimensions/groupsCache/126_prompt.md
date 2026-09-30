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
Here is group 126.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3008799 | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose glucose | 1.000 |  |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 1.000 | 4 |
| 3015024 | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 1.000 | 928 |
| 3016701 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 1.000 | 884 |
| 3019047 | Glucose [Moles/volume] in Serum or Plasma --2.5 hours post dose glucose | 0.971 |  |
| 3034101 | Glucose [Moles/volume] in Serum or Plasma --2.6 hours post dose glucose | 0.970 |  |
| 3036895 | Glucose [Moles/volume] in Serum or Plasma --1.5 hours post dose glucose | 0.969 |  |
| 3006520 | Glucose [Moles/volume] in Serum or Plasma --2.3 hours post dose glucose | 0.965 |  |
| 3007619 | Glucose [Moles/volume] in Serum or Plasma --1.6 hours post dose glucose | 0.963 |  |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.963 |  |
| 3003912 | Glucose [Moles/volume] in Serum or Plasma --1.3 hours post dose glucose | 0.962 |  |
| 3014194 | Glucose [Moles/volume] in Serum or Plasma --40 minutes post dose glucose | 0.958 |  |
| 3012413 | Glucose [Moles/volume] in Serum or Plasma --2 hours post meal | 0.955 | 1141 |
| 3018582 | Glucose [Moles/volume] in Serum or Plasma --20 minutes post dose glucose | 0.954 |  |
| 3023228 | Glucose [Moles/volume] in Serum or Plasma --45 minutes post dose glucose | 0.952 |  |
| 3028247 | Glucose [Mass/volume] in Serum or Plasma --30 minutes post dose glucose | 0.951 |  |
| 3040659 | Glucose [Moles/volume] in Serum or Plasma --1 hour post meal | 0.951 | 1362 |
| 3009877 | Glucose [Moles/volume] in Serum or Plasma --15 minutes post dose glucose | 0.950 |  |
| 3037432 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 100 g glucose PO | 0.950 | 872 |
| 40757389 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose insulin IV | 0.948 |  |
| 40757394 | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose insulin IV | 0.948 |  |
| 3039422 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 75 g glucose PO | 0.947 | 876 |
| 3009154 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 100 g glucose PO | 0.947 | 896 |
| 3026300 | Glucose [Mass/volume] in Serum or Plasma --2 hours post dose glucose | 0.947 |  |
| 3010300 | Glucose [Mass/volume] in Serum or Plasma --1 hour post dose glucose | 0.947 |  |
| 3017538 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 75 g glucose PO | 0.946 | 835 |
| 3020869 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 50 g glucose PO | 0.946 | 338 |
| 3001022 | Glucose [Moles/volume] in Serum or Plasma --10 minutes post dose glucose | 0.946 |  |
| 3049428 | Glucose [Moles/volume] in Serum or Plasma --5 minutes post dose glucose | 0.943 |  |
| 43055143 | Glucose [Moles/volume] in Blood by Automated test strip | 0.937 |  |
| 3004501 | Glucose [Mass/volume] in Serum or Plasma | 0.905 |  |
| 3007821 | Glucose [Moles/volume] in Serum or Plasma --baseline | 0.903 |  |
| 3008770 | Glucose [Moles/volume] in Urine by Test strip | 0.903 | 73 |
| 3006669 | Glucose [Moles/volume] in Serum or Plasma --pre 12 hour fast | 0.899 |  |
| 3014053 | Glucose [Mass/volume] in Blood by Test strip manual | 0.881 |  |
| 3043536 | Glucose [Moles/volume] in Serum or Plasma --12 AM specimen | 0.880 |  |
| 40762876 | Glucose [Moles/volume] in Serum or Plasma --3 PM specimen | 0.877 |  |
| 3045291 | Glucose [Moles/volume] in Serum or Plasma --12 PM specimen | 0.874 |  |
| 3018251 | Fasting glucose [Moles/volume] in Serum or Plasma | 0.874 | 332 |
| 3020491 | Glucose [Moles/volume] in Blood | 0.873 | 13 |
| 40762249 | Glucose [Moles/volume] in Urine by Automated test strip | 0.871 |  |
| 3011424 | Glucose [Mass/volume] in Blood by Automated test strip | 0.864 |  |
| 3014305 | Glucose [Presence] in Blood by Test strip | 0.859 |  |
| 3001501 | Glucose [Moles/volume] in Capillary blood by Glucometer | 0.842 |  |
| 3024629 | Glucose [Mass/volume] in Urine by Test strip | 0.841 |  |
| 40769111 | Beta hydroxybutyrate [Moles/volume] in Blood by Test strip | 0.825 |  |
| 1469878 | Time below range, low in Reporting Period Interstitial fluid by calculation | 0.732 |  |
| 648169 | Glucose [Measurement] in Interstitial fluid | 0.719 |  |
| 1469666 | Time below range, very low in Reporting Period Interstitial fluid by calculation | 0.711 |  |
| 1617169 | Average glucose [Mass/volume] in Interstitial fluid during Reporting Period | 0.698 |  |
| 1989265 | Glucose [Mass/volume] in Interstitial fluid | 0.691 |  |
| 1469495 | Continuous glucose monitoring time in ranges panel | 0.679 |  |
| 1091681 | Glucose [Moles/volume] in Reporting Period mean Interstitial fluid by calculation | 0.665 |  |
| 1470024 | Time above range, high in Reporting Period Interstitial fluid by calculation | 0.665 |  |
| 1091284 | Glucose [Moles/volume] in Interstitial fluid | 0.651 |  |
| 1091739 | Glucose standard deviation/Glucose mean in Reporting Period Interstitial fluid by calculation | 0.649 |  |
| 1469729 | Time above range, very high in Reporting Period Interstitial fluid by calculation | 0.639 |  |
| 645793 | Glucose [Measurement] in Body fluid | 0.618 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1710 | -gluk-tbr | % | 100% | name+unit+values | 118 | 0 | [0, 0, 1, 1, 1, 2, 2.43, 4.38, 6.6] |  |  |  | Glucose.time below range (TBR) [Time Fraction] in Interstitial fluid |
| 1711 | -gluk-tir | % | 100% | name+unit+values | 120 | 0 | [25.5, 36.83, 44.57, 51.33, 60.25, 66, 72.25, 76.73, 81.25] |  |  |  | Glucose.time in range (TIR) [Time Fraction] in Interstitial fluid |
| 1712 | gluk-vieri |  | 100% | name+values | 309 | 0 | [5.09, 5.42, 5.78, 6.17, 6.7, 7.14, 8, 9.04, 11.23] |  |  |  | Glucose [Moles/volume] in Blood by Test strip |
| 1713 | gluk0 | mmol/l | 93% | name+unit+values | 143 | 0 | [4.61, 4.8, 4.96, 5.03, 5.21, 5.48, 5.8, 6.24, 6.7] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1714 | gluk0 |  | 7% | name | 10 | 20 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1715 | gluk0min |  | 100% | name+values | 368 | 0 | [4.92, 5.32, 5.58, 5.75, 5.88, 6, 6.19, 6.58, 7.05] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1716 | gluk120min |  | 100% | name+values | 349 | 0 | [4.3, 5.17, 5.91, 6.49, 7.07, 7.6, 8.72, 10.59, 13.35] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1717 | gluk1h | mmol/l | 100% | name+unit+values | 282 | 0 | [5.36, 6.29, 6.9, 7.39, 7.93, 8.69, 9.15, 9.75, 11.47] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1718 | gluk2h | mmol/l | 98% | name+unit+values | 280 | 0 | [4.55, 5.28, 5.68, 6.16, 6.59, 6.99, 7.54, 8.2, 9.44] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1719 | gluk2h |  | 2% | name | 6 | 100 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1720 | gluk30min |  | 100% | name+values | 362 | 0 | [7.03, 7.79, 8.42, 8.84, 9.36, 9.74, 10.39, 11.2, 12.52] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose glucose |
| 1721 | gluk60min |  | 100% | name+values | 359 | 0 | [5.8, 6.9, 7.62, 8.52, 9.3, 10.21, 11.28, 12.5, 14.53] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1722 | glukbel-vp | mmol/l | 76% | name+unit+values | 664 | 0 | [4.52, 4.88, 5.29, 5.73, 5.99, 6.35, 6.81, 10.3, 12.64] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1723 | glukbel-vp |  | 24% | name | 209 | 100 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1724 | glukoosi120min | mmol/l | 100% | name+unit+values | 119 | 0 | [4.6, 5.12, 5.49, 5.84, 6.6, 7.25, 8.25, 9.68, 12.44] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1725 | glukr-0 | mmol/l | 100% | name+unit+values | 144 | 0 | [4.8, 5.18, 5.45, 5.64, 5.93, 6.16, 6.41, 6.64, 7.16] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1726 | glukr-1h | mmol/l | 100% | name+unit+values | 125 | 0 | [6.69, 7.13, 7.9, 8.73, 9.2, 10.36, 11.37, 12.79, 14.55] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1727 | glukr-2h | mmol/l | 100% | name+unit+values | 144 | 0 | [5.34, 5.79, 6.28, 6.91, 7.51, 8.15, 8.91, 10.16, 11.81] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1728 | glukr0 | mmol/l | 100% | name+unit+values | 204 | 0 | [4.5, 4.79, 4.89, 5.08, 5.2, 5.47, 5.8, 6.29, 6.89] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1729 | glukr0-n | mmol/l | 100% | name+unit+values | 618 | 0 | [4.67, 4.86, 5.09, 5.3, 5.57, 5.83, 6.03, 6.29, 6.69] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1730 | glukr1h | mmol/l | 100% | name+unit+values | 381 | 0 | [5.67, 6.21, 6.84, 7.42, 7.86, 8.3, 8.82, 9.42, 10.36] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1731 | glukr1valm |  | 100% | name | 333 | 100 |  |  |  |  |  |
| 1732 | glukr2h | mmol/l | 100% | name+unit+values | 780 | 0 | [4.8, 5.34, 5.8, 6.21, 6.59, 7.03, 7.53, 8.19, 9.83] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1733 | glukras-0 | mmol/l | 76% | name+unit+values | 97 | 0 | [4.6, 4.78, 5, 5.1, 5.2, 5.43, 5.65, 5.9, 6.3] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1734 | glukras-0 |  | 24% | name | 30 | 3.33 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1735 | glukras120 | mmol/l | 100% | name+unit+values | 153 | 0 | [5.1, 5.47, 5.77, 6.11, 6.54, 6.97, 7.58, 8.12, 9.26] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1736 | glukrvalm |  | 100% | name | 2563 | 100 |  |  |  |  |  |
| 1737 | glukvieri | mmol/l | 77% | name+unit+values | 823 | 0 | [5.3, 5.72, 6.09, 6.42, 6.92, 7.6, 8.66, 10.17, 12.3] |  |  |  | Glucose [Moles/volume] in Blood by Test strip |
| 1738 | glukvieri |  | 23% | name+values | 251 | 1.59 | [5.24, 5.55, 5.81, 6.07, 6.3, 6.79, 7.52, 8.56, 10.76] |  |  |  | Glucose [Moles/volume] in Blood by Test strip |

