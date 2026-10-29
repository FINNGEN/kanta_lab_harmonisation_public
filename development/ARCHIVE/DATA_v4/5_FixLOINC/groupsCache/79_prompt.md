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
Here is group 79.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3005478 | Glucose [Mass/time] in 24 hour Urine | 1.000 |  |
| 3008799 | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose glucose | 1.000 |  |
| 3009261 | Glucose [Presence] in Urine by Test strip | 1.000 | 309 |
| 3012413 | Glucose [Moles/volume] in Serum or Plasma --2 hours post meal | 1.000 | 1141 |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 1.000 | 4 |
| 3015024 | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 1.000 | 928 |
| 3016701 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 1.000 | 884 |
| 3020491 | Glucose [Moles/volume] in Blood | 1.000 | 13 |
| 3020650 | Glucose [Presence] in Urine | 1.000 | 116 |
| 3023436 | Glucagon [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3040151 | Glucose [Moles/volume] in Capillary blood | 1.000 |  |
| 46236367 | Glucose [Moles/volume] in Serum, Plasma or Blood --2 hours post meal | 0.987 |  |
| 3019047 | Glucose [Moles/volume] in Serum or Plasma --2.5 hours post dose glucose | 0.971 |  |
| 3034101 | Glucose [Moles/volume] in Serum or Plasma --2.6 hours post dose glucose | 0.970 |  |
| 3036895 | Glucose [Moles/volume] in Serum or Plasma --1.5 hours post dose glucose | 0.969 |  |
| 3006520 | Glucose [Moles/volume] in Serum or Plasma --2.3 hours post dose glucose | 0.965 |  |
| 3007619 | Glucose [Moles/volume] in Serum or Plasma --1.6 hours post dose glucose | 0.963 |  |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.963 |  |
| 3003912 | Glucose [Moles/volume] in Serum or Plasma --1.3 hours post dose glucose | 0.962 |  |
| 3040659 | Glucose [Moles/volume] in Serum or Plasma --1 hour post meal | 0.960 | 1362 |
| 3014194 | Glucose [Moles/volume] in Serum or Plasma --40 minutes post dose glucose | 0.958 |  |
| 3009154 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 100 g glucose PO | 0.955 | 896 |
| 3018582 | Glucose [Moles/volume] in Serum or Plasma --20 minutes post dose glucose | 0.954 |  |
| 3042995 | Glucose [Moles/volume] in Serum or Plasma --1.5 hours post meal | 0.953 |  |
| 3023228 | Glucose [Moles/volume] in Serum or Plasma --45 minutes post dose glucose | 0.952 |  |
| 3028247 | Glucose [Mass/volume] in Serum or Plasma --30 minutes post dose glucose | 0.951 |  |
| 3009877 | Glucose [Moles/volume] in Serum or Plasma --15 minutes post dose glucose | 0.950 |  |
| 3037432 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 100 g glucose PO | 0.950 | 872 |
| 3007034 | Glucose [Mass/volume] in 24 hour Urine | 0.949 |  |
| 40757389 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose insulin IV | 0.948 |  |
| 3017538 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 75 g glucose PO | 0.948 | 835 |
| 40757394 | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose insulin IV | 0.948 |  |
| 3021737 | Glucose [Mass/volume] in Serum or Plasma --2 hours post meal | 0.948 |  |
| 3039422 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 75 g glucose PO | 0.947 | 876 |
| 3026300 | Glucose [Mass/volume] in Serum or Plasma --2 hours post dose glucose | 0.947 |  |
| 3010300 | Glucose [Mass/volume] in Serum or Plasma --1 hour post dose glucose | 0.947 |  |
| 3041930 | Glucose [Moles/volume] in Serum or Plasma --post meal | 0.947 |  |
| 3020869 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 50 g glucose PO | 0.946 | 338 |
| 3001022 | Glucose [Moles/volume] in Serum or Plasma --10 minutes post dose glucose | 0.946 |  |
| 3049428 | Glucose [Moles/volume] in Serum or Plasma --5 minutes post dose glucose | 0.943 |  |
| 3030260 | Glucose [Presence] in Urine by Automated test strip | 0.942 |  |
| 40758510 | Glucose [Moles/volume] in Serum or Plasma --2.5 hours post 75 g glucose PO | 0.933 |  |
| 43054914 | Glucose tolerance 2 hours panel - Serum or Plasma | 0.931 |  |
| 36659673 | Glucagon [Mass/volume] in Serum or Plasma --fasting | 0.931 |  |
| 21492888 | Glucose tolerance 2 hours gestational panel - Serum or Plasma | 0.921 |  |
| 3000361 | Glucose [Moles/time] in 24 hour Urine | 0.920 |  |
| 3030753 | Glucose tolerance 3 hours gestational panel - Serum or Plasma | 0.918 |  |
| 3010607 | Glucagon [Moles/volume] in Serum or Plasma | 0.916 |  |
| 40762090 | Glucose [Mass/time] in 18 hour Urine | 0.915 |  |
| 3023544 | Glucose [Mass/time] in 6 hour Urine | 0.913 |  |
| 3014305 | Glucose [Presence] in Blood by Test strip | 0.912 |  |
| 3005943 | Glucose [Mass/time] in 8 hour Urine | 0.911 |  |
| 3001501 | Glucose [Moles/volume] in Capillary blood by Glucometer | 0.910 |  |
| 3002574 | Fasting glucose [Presence] in Urine by Test strip | 0.910 |  |
| 3025893 | Glucose [Mass/time] in 10 hour Urine | 0.909 |  |
| 3004501 | Glucose [Mass/volume] in Serum or Plasma | 0.905 |  |
| 3004077 | Glucose [Mass/volume] in Capillary blood | 0.904 |  |
| 3007821 | Glucose [Moles/volume] in Serum or Plasma --baseline | 0.903 |  |
| 3030783 | Glucose tolerance gestational panel - Urine and Serum or Plasma | 0.903 |  |
| 1002388 | Glucose tolerance and insulin sensitivity 2 hour panel - Serum or Plasma | 0.901 |  |
| 3024629 | Glucose [Mass/volume] in Urine by Test strip | 0.901 |  |
| 3030737 | Glucose tolerance 5 hours panel - Serum or Plasma | 0.899 |  |
| 3006669 | Glucose [Moles/volume] in Serum or Plasma --pre 12 hour fast | 0.899 |  |
| 3029335 | Glucose tolerance 4 hours panel - Serum or Plasma | 0.898 |  |
| 3007308 | Glucose [Presence] in 24 hour Urine | 0.895 |  |
| 3044242 | Glucose [Moles/volume] in Arterial blood | 0.894 |  |
| 3038515 | Glucose [Moles/volume] in Venous blood | 0.894 |  |
| 3030997 | Glucose tolerance 3 hours panel - Serum or Plasma | 0.893 |  |
| 40770913 | Hypoglycemics panel - Serum or Plasma | 0.893 |  |
| 40768040 | Glucagon [Mass/volume] in Serum or Plasma --pre XXX challenge | 0.889 |  |
| 3035381 | Glucose [Moles/volume] in 24 hour Urine | 0.888 |  |
| 647086 | Glucagon [Measurement] in Serum or Plasma | 0.885 |  |
| 3029596 | Glucose tolerance 6 hours panel - Serum or Plasma | 0.884 |  |
| 40762150 | Glucagon [Mass/volume] in Serum or Plasma --1st specimen fasting | 0.884 |  |
| 40762146 | Glucagon [Mass/volume] in Serum or Plasma --5th specimen fasting | 0.882 |  |
| 40762640 | Glucagon [Mass/volume] in Serum or Plasma --6th specimen fasting | 0.882 |  |
| 3035729 | Glucose [Moles/volume] in Body fluid | 0.881 | 788 |
| 40762639 | Glucagon [Mass/volume] in Serum or Plasma --7th specimen fasting | 0.881 |  |
| 3043536 | Glucose [Moles/volume] in Serum or Plasma --12 AM specimen | 0.880 |  |
| 647796 | Glucose [Measurement] in Serum or Plasma | 0.877 |  |
| 40762876 | Glucose [Moles/volume] in Serum or Plasma --3 PM specimen | 0.877 |  |
| 3025791 | Fasting glucose [Presence] in Urine | 0.876 |  |
| 40762147 | Glucagon [Mass/volume] in Serum or Plasma --4th specimen fasting | 0.876 |  |
| 3045291 | Glucose [Moles/volume] in Serum or Plasma --12 PM specimen | 0.874 |  |
| 3018251 | Fasting glucose [Moles/volume] in Serum or Plasma | 0.874 | 332 |
| 3003453 | Glucose [Presence] in Urine by Test strip --30 minutes post dose glucose | 0.873 |  |
| 3008770 | Glucose [Moles/volume] in Urine by Test strip | 0.873 | 73 |
| 3003169 | Glucose tolerance 2 hours gestational panel - Urine and Serum or Plasma | 0.872 |  |
| 3000483 | Glucose [Mass/volume] in Blood | 0.871 |  |
| 3019493 | Glucose [Presence] in Urine by Test strip --1 hour post dose glucose | 0.871 |  |
| 46235168 | Fasting glucose [Moles/volume] in Blood | 0.870 |  |
| 40758981 | Glucose [Mass/time] in 24 hour Stool | 0.867 |  |
| 3005589 | Glucose [Presence] in Urine by Test strip --1.5 hours post dose glucose | 0.865 |  |
| 3966759 | Glucose and somatotropin post glucagon stimulation panel - Serum or Plasma | 0.860 |  |
| 3029645 | Glucose screen gestational panel - Urine and Serum or Plasma | 0.854 |  |
| 1616773 | Somatotropin post glucose stimulation panel - Serum or Plasma | 0.850 |  |
| 37020480 | Glucose post glucagon stimulation panel - Serum or Plasma | 0.848 |  |
| 3965035 | Somatotropin and glucose post glucose stimulation panel - Serum or Plasma | 0.848 |  |
| 645854 | Glucose [Measurement] in Urine | 0.846 |  |
| 3028016 | Galactose [Presence] in Urine | 0.841 |  |
| 3006893 | Glucose [Moles/volume] in Specimen | 0.841 |  |
| 37020778 | Growth hormone and glucose post cloNIDine stimulation panel - Serum or Plasma | 0.841 |  |
| 647347 | Glucose [Measurement] in Capillary blood | 0.835 |  |
| 3039379 | Sucrose [Presence] in Urine | 0.834 |  |
| 3004684 | Galactose [Presence] in Blood | 0.831 |  |
| 3020399 | Glucose [Mass/volume] in Urine | 0.830 |  |
| 3046092 | Insulin [Presence] in Serum or Plasma | 0.826 |  |
| 3040980 | Glucose [Presence] in Stool | 0.816 |  |
| 646334 | Glucose [Measurement] in Blood | 0.812 |  |
| 44816672 | Glucose [Mass/volume] in Serum, Plasma or Blood | 0.808 |  |
| 3002666 | Glucose [Mass/volume] in Serum or Plasma --baseline | 0.802 |  |
| 3019474 | Glucose [Mass/volume] in Serum or Plasma --pre 12 hour fast | 0.794 |  |
| 3033819 | Glucose-6-Phosphate dehydrogenase [Presence] in Serum | 0.790 |  |
| 3007090 | Glucose tolerance [Interpretation] in Serum or Plasma | 0.788 |  |
| 3005872 | Hemoglobin [Presence] in Blood | 0.776 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1111 | b-gluk-o | mmol/l | 5% | name+unit | 7 | 100 |  |  | Blood | Qualitative test (also semi-quantitative) | Glucose [Presence] in Blood |
| 1112 | b-gluk-o |  | 95% | name+values | 129 | 100 | [5.43, 5.81, 6.2, 6.6, 7.12, 7.54, 8.33, 9.91, 15.45] |  | Blood | Qualitative test (also semi-quantitative) | Glucose [Presence] in Blood |
| 1113 | b-gluk-pi | mmol/l | 42% | name+unit | 60 | 0 |  |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1114 | b-gluk-pi |  | 58% | name+values | 83 | 100 | [5.2, 5.45, 5.81, 6.35, 7.22, 7.7, 10.2, 13.07, 15.5] |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1115 | b-gluk-pt | mmol/l | 36% | name+unit | 53 | 0 |  |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1116 | b-gluk-pt |  | 64% | name+values | 93 | 100 | [5.4, 5.85, 6.43, 7, 7.38, 8, 8.92, 10.13, 11.9] |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1117 | b-gluk-vt | mmol/l | 31% | name+unit | 72 | 0 |  |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1118 | b-gluk-vt |  | 69% | name+values | 157 | 100 | [5.1, 5.51, 5.93, 6.37, 6.75, 7.3, 8.41, 9.51, 12.29] |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1119 | b-gluk/pi | mmol/l | 99% | name+unit+values | 1414 | 0 | [5.2, 5.7, 6.14, 6.59, 7.19, 7.89, 8.94, 10.29, 12.88] |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1120 | b-gluk/pi |  | 1% | name | 10 | 100 |  |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1121 | b-gluk/pik | mmol/l | 100% | name+unit+values | 945 | 0 | [5.26, 5.68, 6.01, 6.38, 6.84, 7.35, 8.11, 9.42, 11.75] |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1122 | b-gluk/tt |  | 100% | name | 114 | 100 |  |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1123 | b-glukhoi | mmol/l | 35% | name+unit | 52 | 0 |  |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1124 | b-glukhoi |  | 65% | name+values | 95 | 100 | [4.9, 5.3, 5.54, 5.78, 6.1, 6.4, 6.97, 8.77, 12.2] |  | Blood |  | Glucose [Moles/volume] in Blood |
| 1125 | cb-gluk-0 | mmol/l | 19% | name+unit | 21 | 0 |  |  | Capillary blood |  | Glucose [Moles/volume] in Capillary blood |
| 1126 | cb-gluk-0 |  | 81% | name | 89 | 100 |  |  | Capillary blood |  | Glucose [Moles/volume] in Capillary blood |
| 1127 | cb-gluk-v |  | 100% | name+values | 182 | 100 | [5.2, 5.7, 6.07, 6.36, 6.75, 7.46, 8.34, 9.87, 12.02] |  | Capillary blood | Free or unconjugated | Glucose [Moles/volume] in Capillary blood |
| 1128 | cb-gluk-vt | mmol/l | 37% | name+unit+values | 147 | 0 | [5.62, 6.11, 6.75, 7.37, 8.19, 9.86, 12.56, 16.24, 20.1] |  | Capillary blood |  | Glucose [Moles/volume] in Capillary blood |
| 1129 | cb-gluk-vt |  | 63% | name | 249 | 100 |  |  | Capillary blood |  | Glucose [Moles/volume] in Capillary blood |
| 1130 | cfp-glucos | mmol/l | 98% | name+unit+values | 1307 | 0 | [5.81, 6.24, 6.62, 6.91, 7.24, 7.63, 8.02, 8.7, 9.78] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1131 | cfp-glucos |  | 2% | name | 30 | 100 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1132 | cp-glucos | mmol/l | 82% | name+unit+values | 3564 | 0 | [5.94, 6.53, 7.17, 7.83, 8.52, 9.32, 10.35, 11.61, 13.51] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1133 | cp-glucos |  | 18% | name | 794 | 100 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1134 | cp-gluk-hy | mmol/l | 100% | name+unit+values | 16015 | 0.04 | [5.33, 6.49, 7.52, 8.51, 9.53, 10.54, 11.78, 13.35, 15.67] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1135 | cp-gluk-hy |  | 0% | name | 40 | 100 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1136 | cp-gluk-lb | mmol/l | 97% | name+unit+values | 10492 | 0 | [4.98, 5.61, 6.18, 6.77, 7.46, 8.42, 9.63, 11.26, 13.98] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1137 | cp-gluk-lb |  | 3% | name | 283 | 100 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1138 | cp-gluk-o |  | 100% | name | 165 | 100 |  |  |  | Qualitative test (also semi-quantitative) | Glucose [Presence] in Serum or Plasma |
| 1139 | cp-gluk-po | mmol/l | 100% | name+unit+values | 2528 | 0 | [4.65, 5.93, 7.07, 8.16, 9.34, 10.66, 12.22, 14.51, 17.97] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1140 | cp-gluk-po |  | 0% | name | 7 | 100 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1141 | cp-glukpaa | mmol/l | 55% | name+unit | 116 | 0 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1142 | cp-glukpaa |  | 45% | name | 94 | 100 |  |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1143 | cp-glukpot |  | 100% | name+values | 106 | 100 | [4.93, 5.55, 6.42, 7.07, 7.43, 8.57, 9.89, 11.44, 13.83] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1144 | fp-gluk,t |  | 100% | name+values | 773 | 100 | [5.56, 6.02, 6.34, 6.71, 7.09, 7.5, 7.92, 8.81, 10.39] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1145 | fp-gluk,tk |  | 100% | name+values | 1207 | 100 | [4.77, 5.03, 5.29, 5.49, 5.88, 6.46, 7.07, 7.93, 9.36] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1146 | fp-gluk-0h | mmol/l | 41% | name+unit+values | 156 | 0 | [5.62, 5.88, 6.03, 6.17, 6.3, 6.44, 6.68, 6.89, 7.2] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1147 | fp-gluk-0h |  | 59% | name+values | 229 | 100 | [4.5, 4.7, 4.81, 5, 5.1, 5.3, 5.51, 5.91, 6.41] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1148 | fp-gluk-1 | mmol/l | 100% | name+unit+values | 108 | 0 | [5.5, 6.24, 6.81, 7.36, 7.89, 8.4, 8.79, 9.47, 10.2] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1149 | fp-gluk-2 | mmol/l | 95% | name+unit+values | 168 | 0 | [4.74, 5.29, 5.7, 6.17, 6.78, 7.15, 7.64, 8.78, 10.15] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1150 | fp-gluk-2 |  | 5% | name | 9 | 100 |  |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1151 | fp-gluk-2h | mmol/l | 71% | name+unit+values | 109 | 0 | [4.43, 5.4, 5.75, 6.21, 6.7, 7.52, 8.1, 8.93, 10.71] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1152 | fp-gluk-2h | mmol/mol | 29% | name+unit | 45 | 0 |  |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1153 | fp-gluk-o | mmol/l | 95% | name+unit+values | 104 | 0 | [4.6, 4.9, 5.18, 5.4, 5.71, 6, 6.3, 6.7, 6.95] |  | Fasting plasma | Qualitative test (also semi-quantitative) | Glucose [Presence] in Serum or Plasma |
| 1154 | fp-gluk-o |  | 5% | name | 6 | 100 |  |  | Fasting plasma | Qualitative test (also semi-quantitative) | Glucose [Presence] in Serum or Plasma |
| 1155 | fp-gluk-p | mmol/l | 88% | name+unit+values | 391 | 0 | [4.76, 5.2, 5.64, 5.93, 6.1, 6.3, 6.49, 6.74, 7.18] |  | Fasting plasma | Upright (standing) | Glucose [Moles/volume] in Serum or Plasma |
| 1156 | fp-gluk-p |  | 12% | name | 51 | 100 |  |  | Fasting plasma | Upright (standing) | Glucose [Moles/volume] in Serum or Plasma |
| 1157 | fp-gluk-sn | mmol/l | 98% | name+unit+values | 1398 | 0 | [5.04, 5.72, 6.23, 6.71, 7.2, 7.71, 8.25, 9.13, 10.8] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1158 | fp-gluk-sn |  | 2% | name | 28 | 100 |  |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1159 | fp-gluk/0 | mmol/l | 87% | name+unit+values | 296 | 0 | [4.49, 4.7, 4.93, 5.24, 5.55, 5.9, 6.19, 6.52, 6.89] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1160 | fp-gluk/0 |  | 13% | name | 46 | 100 |  |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1161 | fp-gluk/pi |  | 100% | name+values | 110 | 100 | [5.2, 5.44, 5.64, 5.94, 6.22, 6.57, 7.06, 7.97, 9.9] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1162 | fp-gluk0 | mmol/l | 90% | name+unit+values | 1616 | 0 | [4.6, 4.73, 4.9, 5.02, 5.22, 5.42, 5.67, 5.95, 6.5] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1163 | fp-gluk0 |  | 10% | name+values | 175 | 100 | [4.96, 5.57, 6.04, 6.16, 6.3, 6.49, 6.7, 6.84, 7.15] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1164 | fp-glukos | mmol/l | 100% | name+unit+values | 977 | 0 | [4.79, 5.14, 5.39, 5.61, 5.86, 6.13, 6.45, 7.01, 8.07] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1165 | fp-glukr0 | mmol/l | 89% | name+unit+values | 173 | 0 | [4.63, 4.88, 5.24, 5.55, 5.9, 6.12, 6.4, 6.6, 7.09] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1166 | fp-glukr0 |  | 11% | name | 21 | 100 |  |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1167 | fp-glukr0h | mmol/l | 97% | name+unit+values | 951 | 0.32 | [5.42, 5.7, 5.88, 6.01, 6.19, 6.34, 6.51, 6.77, 7.2] |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1168 | fp-glukr0h |  | 3% | name | 28 | 100 |  |  | Fasting plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1169 | p-glkg | ng/l | 83% | name+unit+values | 365 | 0 | [139.5, 155.41, 170.26, 182.78, 193.92, 208.93, 237.14, 279.6, 336.26] | P -Glukagoni | Plasma |  | Glucagon [Mass/volume] in Serum or Plasma |
| 1170 | p-glkg |  | 17% | name | 77 | 100 |  | P -Glukagoni | Plasma |  | Glucagon [Mass/volume] in Serum or Plasma |
| 1171 | p-glu/0 | mmol/l | 99% | name+unit+values | 1831 | 0 | [4.4, 4.63, 4.86, 5.08, 5.3, 5.57, 5.89, 6.23, 6.67] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1172 | p-glu/0 |  | 1% | name | 24 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1173 | p-glu/1h | mmol/l | 98% | name+unit+values | 683 | 0 | [5.17, 5.85, 6.4, 6.95, 7.34, 7.81, 8.3, 8.85, 9.71] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1174 | p-glu/1h |  | 2% | name | 11 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1175 | p-glu/2h | mmol/l | 98% | name+unit+values | 1816 | 0 | [4.49, 5.06, 5.5, 5.9, 6.36, 6.92, 7.74, 8.85, 11.03] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1176 | p-glu/2h |  | 2% | name | 35 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1177 | p-glu/30m | mmol/l | 100% | name+unit+values | 228 | 0 | [6.47, 7.15, 7.55, 7.97, 8.37, 8.76, 9.2, 9.83, 10.94] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose glucose |
| 1178 | p-gluk,tk | mmol/l | 100% | name+unit+values | 7423 | 0 | [5.62, 6.19, 6.72, 7.31, 8.07, 8.98, 10.16, 11.79, 14.45] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1179 | p-gluk-0 | mmol/l | 91% | name+unit+values | 264 | 0 | [4.63, 4.8, 4.96, 5.1, 5.27, 5.57, 5.92, 6.32, 7.02] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1180 | p-gluk-0 |  | 9% | name | 26 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1181 | p-gluk-0h | mmol/l | 99% | name+unit+values | 750 | 0 | [4.5, 4.74, 4.99, 5.18, 5.41, 5.76, 6.07, 6.32, 6.7] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1182 | p-gluk-0h |  | 1% | name | 8 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1183 | p-gluk-1h | mmol/l | 71% | name+unit+values | 402 | 0 | [5.57, 6.22, 6.83, 7.23, 7.57, 8.06, 8.49, 9.01, 9.94] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1184 | p-gluk-1h |  | 29% | name+values | 163 | 100 | [5.81, 6.57, 7.01, 7.47, 7.82, 8.15, 8.47, 9.03, 10.1] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1185 | p-gluk-1t | mmol/l | 91% | name+unit+values | 167 | 0 | [5.29, 5.9, 6.35, 6.66, 7.27, 7.64, 8.35, 8.9, 10.16] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1186 | p-gluk-1t |  | 9% | name | 17 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1187 | p-gluk-2h | mmol/l | 77% | name+unit+values | 897 | 0 | [4.78, 5.31, 5.74, 6.17, 6.56, 7.1, 7.66, 8.51, 9.94] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1188 | p-gluk-2h |  | 23% | name+values | 263 | 100 | [4.77, 5.45, 5.76, 6.17, 6.52, 6.84, 7.15, 7.77, 9.15] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1189 | p-gluk-2t | mmol/l | 89% | name+unit+values | 462 | 0 | [4.62, 5.32, 5.8, 6.21, 6.64, 7.17, 7.9, 8.99, 11.01] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1190 | p-gluk-2t |  | 11% | name | 59 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1191 | p-gluk-a2 | mmol/l | 85% | name+unit+values | 1483 | 0.07 | [5.94, 7.28, 8.69, 10, 11.25, 12.56, 14.23, 16.59, 19.44] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post meal |
| 1192 | p-gluk-a2 |  | 15% | name+values | 259 | 100 | [6.42, 7.76, 9.11, 10.3, 11.29, 12.59, 13.78, 15.77, 18.35] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post meal |
| 1193 | p-gluk-o | mmol/l | 88% | name+unit+values | 1305 | 0.08 | [3.8, 4.26, 4.54, 4.72, 4.91, 5.15, 5.44, 5.9, 6.59] |  | Plasma | Qualitative test (also semi-quantitative) | Glucose [Presence] in Serum or Plasma |
| 1194 | p-gluk-o |  | 12% | name | 175 | 100 |  |  | Plasma | Qualitative test (also semi-quantitative) | Glucose [Presence] in Serum or Plasma |
| 1195 | p-gluk-po | mmol/l | 77% | name+unit+values | 820 | 0 | [5.73, 6.47, 7.19, 7.81, 8.6, 9.37, 10.27, 11.53, 13.61] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1196 | p-gluk-po |  | 23% | name+values | 242 | 100 | [5.3, 6.08, 6.6, 7.05, 7.78, 8.4, 9.46, 11.37, 12.6] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1197 | p-gluk-sn | mmol/l | 32% | name+unit+values | 1252 | 0 | [5.62, 6.24, 6.87, 7.62, 8.75, 10.05, 11.53, 13.51, 16.47] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1198 | p-gluk-sn |  | 68% | name | 2688 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1199 | p-gluk-vt | 1 | 1% | name+unit | 40 | 0 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1200 | p-gluk-vt | mmol/l | 99% | name+unit+values | 7875 | 0 | [4.66, 4.98, 5.43, 6.02, 6.79, 7.88, 9.29, 11.32, 14.47] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1201 | p-gluk. | mmol/l | 40% | name+unit+values | 752 | 0 | [4.6, 4.9, 5.19, 5.56, 5.95, 6.36, 6.79, 7.42, 8.57] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1202 | p-gluk. |  | 60% | name | 1111 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1203 | p-gluk/120 | mmol/l | 76% | name+unit+values | 95 | 0 | [4.8, 5.3, 5.71, 6.15, 6.7, 7.35, 7.8, 8.75, 10] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1204 | p-gluk/120 |  | 24% | name | 30 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1205 | p-gluk/2h | mmol/l | 92% | name+unit+values | 204 | 0 | [4.6, 5.17, 5.53, 6.07, 6.51, 7.16, 8.06, 9.69, 11.7] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1206 | p-gluk/2h |  | 8% | name | 17 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1207 | p-gluk0 | mmol/l | 60% | name+unit+values | 205 | 0 | [4.71, 4.97, 5.2, 5.33, 5.51, 5.7, 5.82, 6, 6.41] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1208 | p-gluk0 |  | 40% | name+values | 134 | 100 | [4.9, 5.29, 5.97, 6.1, 6.21, 6.44, 6.67, 6.9, 7.26] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1209 | p-gluk120 | mmol/l | 96% | name+unit+values | 1674 | 0 | [4.77, 5.31, 5.74, 6.14, 6.54, 7.03, 7.61, 8.44, 10] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1210 | p-gluk120 |  | 4% | name | 77 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1211 | p-gluk1h | mmol/l | 83% | name+unit+values | 181 | 0 | [5.46, 5.92, 6.58, 7.24, 7.73, 8.41, 9.44, 10.75, 12.63] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1212 | p-gluk1h |  | 17% | name | 38 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1213 | p-gluk2h | mmol/l | 24% | name+unit+values | 92 | 0 | [4.6, 5.11, 5.97, 6.3, 6.8, 7.26, 7.98, 9, 10.5] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1214 | p-gluk2h | mmoll/l | 43% | name+unit+values | 169 | 0 | [4.54, 4.97, 5.56, 5.91, 6.35, 6.78, 7.43, 8.12, 9.76] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1215 | p-gluk2h |  | 33% | name+values | 129 | 100 | [5.36, 6.02, 6.76, 7.08, 7.8, 8.46, 9.11, 10.06, 11.53] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1216 | p-gluk60 | mmol/l | 96% | name+unit+values | 936 | 0.21 | [5.58, 6.24, 6.73, 7.23, 7.62, 8.17, 8.7, 9.36, 10.2] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1217 | p-gluk60 |  | 4% | name | 43 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1218 | p-gluk: | mmol/l | 100% | name+unit+values | 627 | 0 | [5.38, 5.94, 6.31, 6.7, 7.16, 7.74, 8.48, 9.63, 11.83] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1219 | p-glukhoi | mmol/l | 42% | name+unit+values | 279 | 0 | [5.05, 5.62, 6.12, 6.89, 7.83, 9, 10.74, 12.64, 15.73] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1220 | p-glukhoi |  | 58% | name+values | 384 | 100 | [5.07, 5.6, 5.97, 6.28, 6.77, 7.43, 8.38, 10.3, 13.45] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1221 | p-glukp | mmol/l | 100% | name+unit+values | 175 | 0.57 | [4.6, 4.91, 5.23, 5.5, 5.89, 6.43, 6.92, 7.84, 12.46] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1222 | p-glukpik | mmol/l | 90% | name+unit+values | 200 | 0 | [5, 5.2, 5.4, 5.63, 5.8, 6.05, 6.2, 6.5, 7.53] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1223 | p-glukpik |  | 10% | name | 21 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1224 | p-glukpoc | mmol/l | 100% | name+unit+values | 2519 | 0 | [5.93, 6.58, 7.13, 7.75, 8.31, 9.1, 9.95, 11.15, 13.04] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1225 | p-glukr0h | mmol/l | 100% | name+unit+values | 535 | 0 | [4.5, 4.7, 4.86, 5, 5.1, 5.28, 5.45, 5.71, 6.24] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma |
| 1226 | p-glukr1h | mmol/l | 98% | name+unit+values | 466 | 0 | [5.51, 6.13, 6.67, 7.07, 7.5, 7.91, 8.49, 9.1, 9.84] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1227 | p-glukr1h |  | 2% | name | 8 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1228 | p-glukr2h | mmol/l | 97% | name+unit+values | 1604 | 0.19 | [4.57, 5.2, 5.69, 6.15, 6.62, 7.19, 7.87, 8.98, 10.55] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1229 | p-glukr2h |  | 3% | name | 58 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1230 | pt-gluk,0 |  | 100% | name | 130 | 100 |  |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma |
| 1231 | pt-gluk-0 | mmol/l | 64% | name+unit+values | 272 | 0 | [4.3, 4.59, 4.8, 4.98, 5.22, 5.5, 5.77, 6.17, 6.53] |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma |
| 1232 | pt-gluk-0 |  | 36% | name+values | 151 | 100 | [4.5, 4.7, 4.8, 4.88, 5, 5.11, 5.33, 5.5, 5.76] |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma |
| 1233 | pt-gluk-0h | mmol/l | 87% | name+unit+values | 951 | 0 | [4.4, 4.6, 4.76, 4.9, 5.02, 5.23, 5.49, 5.86, 6.46] |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma |
| 1234 | pt-gluk-0h |  | 13% | name+values | 138 | 100 | [5, 5.1, 5.21, 5.5, 5.63, 5.81, 5.99, 6.24, 6.64] |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma |
| 1235 | pt-gluk-1h | mmol/l | 99% | name+unit+values | 771 | 0 | [5.25, 5.86, 6.42, 6.94, 7.45, 8.02, 8.57, 9.25, 10.42] |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1236 | pt-gluk-1h |  | 1% | name | 6 | 100 |  |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1237 | pt-gluk-2h | mmol/l | 91% | name+unit+values | 1501 | 0 | [4.46, 4.99, 5.43, 5.84, 6.26, 6.73, 7.36, 8.21, 9.78] |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1238 | pt-gluk-2h |  | 9% | name+values | 154 | 100 | [4, 4.66, 5.12, 5.48, 5.93, 6.4, 6.95, 7.57, 9.38] |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1239 | pt-gluk-30 |  | 100% | name+values | 131 | 100 | [7.04, 7.5, 7.77, 8.19, 8.53, 9.21, 9.76, 10.71, 12.23] |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose glucose |
| 1240 | pt-gluk-r |  | 100% | name | 14723 | 100 |  |  | Patient | Exercise / functional test | Glucose oral tolerance test panel - Serum or Plasma |
| 1241 | pt-gluk-r1 | form | 0% | name+unit | 75 | 0 |  | Pt-Glukoosi-koe, oraalinen, lyhyt | Patient |  | Glucose 2 hour oral tolerance test panel - Serum or Plasma |
| 1242 | pt-gluk-r1 | mmol/l | 1% | name+unit+values | 369 | 0 | [5, 5.36, 5.74, 6.03, 6.42, 6.84, 7.39, 8.3, 9.71] | Pt-Glukoosi-koe, oraalinen, lyhyt | Patient |  | Glucose 2 hour oral tolerance test panel - Serum or Plasma |
| 1243 | pt-gluk-r1 |  | 99% | name | 71876 | 100 |  | Pt-Glukoosi-koe, oraalinen, lyhyt | Patient |  | Glucose 2 hour oral tolerance test panel - Serum or Plasma |
| 1244 | pt-gluk-r2 | mmol/l | 7% | name+unit | 21 | 0 |  | Pt-Glukoosi-koe, oraalinen, pitkä | Patient |  | Glucose oral tolerance test panel - Serum or Plasma |
| 1245 | pt-gluk-r2 |  | 93% | name | 287 | 100 |  | Pt-Glukoosi-koe, oraalinen, pitkä | Patient |  | Glucose oral tolerance test panel - Serum or Plasma |
| 1246 | pt-gluk-r2,tk |  | 100% | name | 289 | 100 |  |  | Patient |  | Glucose oral tolerance test panel - Serum or Plasma |
| 1247 | pt-gluk-r4 |  | 100% | name | 143 | 100 |  | Pt-Glukoosi-koe, hypoglykemia | Patient |  | Glucose tolerance test for hypoglycemia panel - Serum or Plasma |
| 1248 | pt-gluk-r5 |  | 100% | name | 108 | 100 |  | Pt-Glukoosi-koe, kasvuhormoni | Patient |  | Glucose tolerance test for growth hormone panel - Serum or Plasma |
| 1249 | pt-gluk-r6 | mmol/l | 2% | name+unit+values | 370 | 0 | [4.7, 4.94, 5.17, 5.39, 5.84, 6.39, 6.99, 7.91, 8.84] | Pt-Glukoosi-koe, oraalinen, raskaudenaikainen | Patient |  | Glucose tolerance test during pregnancy panel - Serum or Plasma |
| 1250 | pt-gluk-r6 |  | 98% | name | 23123 | 100 |  | Pt-Glukoosi-koe, oraalinen, raskaudenaikainen | Patient |  | Glucose tolerance test during pregnancy panel - Serum or Plasma |
| 1251 | pt-gluk-r8 |  | 100% | name | 231 | 100 |  |  | Patient |  | Glucose oral tolerance test panel - Serum or Plasma |
| 1252 | pt-gluk-rg |  | 100% | name | 118 | 100 |  |  | Patient |  | Glucose tolerance test during pregnancy panel - Serum or Plasma |
| 1253 | pt-gluk-sd |  | 100% | name | 824 | 100 |  |  | Patient |  | Glucose oral tolerance test panel - Serum or Plasma |
| 1254 | pt-glukoos |  | 100% | name | 257 | 100 |  |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma |
| 1255 | pt-glukr-0 | mmol/l | 100% | name+unit+values | 300 | 0 | [5.37, 5.6, 5.8, 5.96, 6.13, 6.3, 6.48, 6.67, 7.12] |  | Patient |  | Glucose [Moles/volume] in Serum or Plasma |
| 1256 | pt-glukr1p |  | 100% | name | 902 | 100 |  |  | Patient |  | Glucose 2 hour oral tolerance test panel - Serum or Plasma |
| 1257 | pt-glukr1v |  | 100% | name | 1247 | 100 |  |  | Patient |  | Glucose 2 hour oral tolerance test panel - Serum or Plasma |
| 1258 | pt-glukr2h |  | 100% | name | 5360 | 100 |  |  | Patient |  | Glucose 2 hour oral tolerance test panel - Serum or Plasma |
| 1259 | pt-glur3-g |  | 100% | name | 118 | 100 |  |  | Patient |  | Glucose oral tolerance test panel - Serum or Plasma |
| 1260 | pt-glur3-i |  | 100% | name | 118 | 100 |  |  | Patient |  | Glucose oral tolerance test panel - Serum or Plasma |
| 1261 | u-gluk-0 |  | 100% | name+values | 9320 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Glucose [Presence] in Urine |
| 1262 | u-gluk-de |  | 100% | name+values | 152 | 100 | [1044.9, 1079.17, 1109.42, 1125, 1152.75, 1186.12, 1207.92, 1246.3, 1486.7] |  | Urine |  | Glucose [Mass/time] in 24 hour Urine |
| 1263 | u-gluk-hy |  | 100% | name | 2667 | 100 |  |  | Urine |  | Glucose [Presence] in Urine |
| 1264 | u-gluk-o | estimate | 21% | name+unit+values | 176312 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Glukoosi (kval) | Urine | Qualitative test (also semi-quantitative) | Glucose [Presence] in Urine by Test strip |
| 1265 | u-gluk-o | form | 0% | name+unit+values | 842 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Glukoosi (kval) | Urine | Qualitative test (also semi-quantitative) | Glucose [Presence] in Urine by Test strip |
| 1266 | u-gluk-o |  | 79% | name | 658060 | 100 |  | U -Glukoosi (kval) | Urine | Qualitative test (also semi-quantitative) | Glucose [Presence] in Urine by Test strip |
| 1267 | u-gluk-o. |  | 100% | name | 24482 | 100 |  |  | Urine |  | Glucose [Presence] in Urine by Test strip |
| 1268 | u-gluk-ov |  | 100% | name | 816 | 100 |  |  | Urine |  | Glucose [Presence] in Urine by Test strip |
| 1269 | u-gluk-pi |  | 100% | name | 422 | 100 |  |  | Urine |  | Glucose [Presence] in Urine by Test strip |
| 1270 | vp-gluk-0h | mmol/l | 62% | name+unit+values | 715 | 0 | [4.69, 4.93, 5.24, 5.58, 5.92, 6.16, 6.43, 6.77, 7.19] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1271 | vp-gluk-0h |  | 38% | name+values | 439 | 100 | [4.64, 4.89, 5.14, 5.56, 5.95, 6.27, 6.57, 6.88, 7.22] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 1272 | vp-gluk-1h | mmol/l | 63% | name+unit+values | 247 | 0 | [5.11, 5.77, 6.25, 6.61, 7.03, 7.67, 8.06, 8.63, 9.93] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1273 | vp-gluk-1h |  | 37% | name+values | 144 | 100 | [5.81, 6.29, 6.71, 7.08, 7.37, 7.82, 8.17, 8.78, 9.49] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose |
| 1274 | vp-gluk-2h | mmol/l | 62% | name+unit+values | 712 | 0 | [4.98, 5.56, 6.04, 6.64, 7.18, 7.97, 8.74, 10.17, 12.52] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |
| 1275 | vp-gluk-2h |  | 38% | name+values | 431 | 100 | [5.19, 5.72, 6.34, 6.98, 7.61, 8.2, 9.41, 11.25, 12.85] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose |

