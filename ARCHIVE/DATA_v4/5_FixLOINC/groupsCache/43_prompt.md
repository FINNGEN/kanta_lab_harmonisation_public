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
Here is group 43.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000620 | Complement C3 [Mass/volume] in Serum or Plasma | 1.000 | 436 |
| 3001186 | Copper [Moles/volume] in Serum or Plasma | 1.000 | 1184 |
| 3006407 | Chromogranin A [Mass/volume] in Serum or Plasma | 1.000 | 1578 |
| 3006567 | Chloride [Moles/time] in 24 hour Urine | 1.000 |  |
| 3006906 | Calcium [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3007171 | Chromium [Mass/volume] in Urine | 1.000 |  |
| 3007220 | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 90 |
| 3010375 | cycloSPORINE [Mass/volume] in Blood | 1.000 | 474 |
| 3010838 | Calcium [Moles/time] in 24 hour Urine | 1.000 | 902 |
| 3014576 | Chloride [Moles/volume] in Serum or Plasma | 1.000 | 8 |
| 3014702 | Chromogranin A [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3015377 | Calcium [Moles/volume] in Serum or Plasma | 1.000 | 12 |
| 3015883 | Cotinine [Presence] in Urine | 1.000 |  |
| 3017766 | Complement C4 [Mass/volume] in Serum or Plasma | 1.000 | 437 |
| 3018133 | Calcium [Moles/volume] in Urine | 1.000 | 859 |
| 3018572 | Chloride [Moles/volume] in Blood | 1.000 | 295 |
| 3021119 | Calcium.ionized [Moles/volume] in Blood | 1.000 | 130 |
| 3024085 | Cobalt [Mass/volume] in Urine | 1.000 |  |
| 3025577 | Chromium [Mass/volume] in Blood | 1.000 |  |
| 3025911 | Cotinine [Mass/volume] in Urine | 1.000 | 674 |
| 3026470 | Cobalt [Mass/volume] in Blood | 1.000 |  |
| 3031248 | Chloride [Moles/volume] in Arterial blood | 1.000 |  |
| 3033942 | Copper [Moles/time] in 24 hour Urine | 1.000 |  |
| 3035256 | Chromium [Moles/volume] in Urine | 1.000 |  |
| 3040160 | Chromium [Presence] in Urine | 1.000 |  |
| 3043323 | Complement C3 [Mass/volume] in Pleural fluid | 1.000 |  |
| 3044336 | Cobalt [Moles/volume] in Urine | 1.000 |  |
| 3044416 | Complement C4 [Mass/volume] in Pleural fluid | 1.000 |  |
| 3046279 | Procalcitonin [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3009542 | Hematocrit [Volume Fraction] of Blood | 0.979 | 28 |
| 3031619 | Immune complex [Mass/volume] in Serum or Plasma | 0.969 |  |
| 3022126 | Complement C3b [Mass/volume] in Serum or Plasma | 0.966 |  |
| 3002752 | Chloride [Moles/volume] in 24 hour Urine | 0.966 |  |
| 40761055 | Complement C4c [Mass/volume] in Serum or Plasma | 0.965 |  |
| 3000581 | Complement C3c [Mass/volume] in Serum or Plasma | 0.964 |  |
| 3026738 | Copper [Moles/volume] in 24 hour Urine | 0.963 |  |
| 3035285 | Chloride [Moles/volume] in Venous blood | 0.960 |  |
| 3009630 | Calcium [Moles/volume] in 24 hour Urine | 0.958 | 1090 |
| 3009804 | Carcinoembryonic Ag [Mass/volume] in Pleural fluid | 0.957 |  |
| 46235783 | Chloride [Moles/volume] in Serum, Plasma or Blood | 0.955 |  |
| 3018950 | cycloSPORINE [Mass/volume] in Plasma | 0.954 |  |
| 3003785 | Carcinoembryonic Ag [Mass/volume] in Serum or Plasma | 0.952 | 312 |
| 3015367 | Cobalt [Mass/volume] in 24 hour Urine | 0.949 |  |
| 3021348 | Complement C4 [Units/volume] in Serum or Plasma | 0.948 |  |
| 3002050 | Chromium [Mass/volume] in 24 hour Urine | 0.947 |  |
| 40760460 | Chloride [Moles/time] in 12 hour Urine | 0.946 |  |
| 3042505 | cycloSPORINE [Mass/volume] in Blood --trough | 0.946 |  |
| 3010612 | cycloSPORINE [Mass/volume] in Serum | 0.944 |  |
| 3044343 | Cobalt [Moles/volume] in 24 hour Urine | 0.943 |  |
| 3048733 | Chromium [Moles/volume] in 24 hour Urine | 0.943 |  |
| 3020219 | cycloSPORINE+Metabolites [Mass/volume] in Blood | 0.942 |  |
| 46234781 | Complement C4 [Moles/volume] in Serum or Plasma | 0.940 |  |
| 3041568 | Calcium [Moles/time] in 12 hour Urine | 0.937 |  |
| 3044331 | Calcium.ionized [Moles/volume] in Arterial blood | 0.937 |  |
| 3048816 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Blood | 0.937 |  |
| 3045762 | Complement C3d [Mass/volume] in Serum or Plasma | 0.933 |  |
| 3041519 | Chloride [Mass/time] in 24 hour Urine | 0.932 |  |
| 3025848 | Cobalt [Moles/volume] in Blood | 0.932 |  |
| 3027126 | Copper [Mass/volume] in Serum or Plasma | 0.932 |  |
| 3040003 | cycloSPORINE [Mass/volume] in Blood --post dose | 0.932 |  |
| 3019462 | cycloSPORINE [Mass/volume] in Body fluid | 0.932 |  |
| 3029790 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma | 0.931 | 374 |
| 44817130 | Procalcitonin [Mass/volume] in Serum or Plasma by Immunoassay | 0.929 |  |
| 3036426 | Calcium.ionized [Mass/volume] in Blood | 0.927 |  |
| 1988947 | Procalcitonin [Moles/volume] in Serum or Plasma | 0.927 |  |
| 3023851 | Copper [Mass/time] in 24 hour Urine | 0.924 |  |
| 3013480 | cycloSPORINE [Mass/volume] in Blood by Immunoassay | 0.924 |  |
| 40758926 | cycloSPORINE [Mass/volume] in Blood by LC/MS/MS | 0.923 |  |
| 3034141 | Complement C3a [Mass/volume] in Serum or Plasma | 0.923 |  |
| 3035279 | Calcium.ionized [Moles/volume] in Capillary blood | 0.922 |  |
| 648404 | Procalcitonin [Mass/volume] in Serum, Plasma or Blood by Immunoassay | 0.922 |  |
| 3028297 | Cotinine [Mass/volume] in Specimen | 0.922 |  |
| 40762092 | Chloride [Moles/time] in 18 hour Urine | 0.922 |  |
| 3033705 | Calcium.ionized [Moles/volume] in Venous blood | 0.921 |  |
| 3046135 | Complement C4 [Mass/volume] in Pericardial fluid | 0.921 |  |
| 3015531 | Creatine kinase.macromolecular [Enzymatic activity/volume] in Serum or Plasma | 0.919 |  |
| 46237011 | cycloSPORINE [Mass/volume] in Blood --1 hour post dose | 0.917 |  |
| 3007687 | Calcium [Mass/time] in 24 hour Urine | 0.917 |  |
| 3039576 | Calcium [Mass/volume] in Serum or Plasma --baseline | 0.916 |  |
| 3017730 | Calcium [Mass/volume] in 24 hour Urine | 0.916 |  |
| 3001793 | Complement C2 [Mass/volume] in Serum or Plasma | 0.916 |  |
| 3045920 | Complement C3 [Mass/volume] in Pericardial fluid | 0.916 |  |
| 645942 | Chromium [Measurement] in Urine | 0.915 |  |
| 3039921 | Calcium [Moles/time] in 1 hour Urine | 0.914 |  |
| 3005962 | Chromium [Moles/volume] in Blood | 0.914 |  |
| 3040757 | Calcium [Moles/volume] in Serum or Plasma --baseline | 0.912 |  |
| 3045730 | Cotinine [Moles/volume] in Urine | 0.912 |  |
| 40760458 | Chloride [Moles/volume] in 12 hour Urine | 0.912 |  |
| 3021347 | Calcium.ionized [Moles/volume] in Serum or Plasma | 0.911 | 182 |
| 3029431 | Calcium.ionized [Moles/volume] in Body fluid | 0.911 |  |
| 40763125 | Cobalt [Mass/volume] in Red Blood Cells | 0.910 |  |
| 42529202 | Carcinoembryonic Ag [Mass/volume] in Serum or Plasma by Immunoassay | 0.909 |  |
| 645657 | Cobalt [Measurement] in Urine | 0.909 |  |
| 649040 | Complement C4 [Measurement] in Serum or Plasma | 0.909 |  |
| 3041386 | Immune complex [Mass/volume] in Serum or Plasma by Immunoassay | 0.908 |  |
| 3015620 | Creatine kinase panel - Serum or Plasma | 0.908 |  |
| 3037601 | Chromium [Mass/volume] in Urine collected for unspecified duration | 0.908 |  |
| 3002818 | Complement C1s [Mass/volume] in Serum or Plasma | 0.907 |  |
| 3006028 | Cotinine [Mass/volume] in Serum or Plasma | 0.907 |  |
| 3041066 | Chromogranin A [Mass/volume] in Body fluid | 0.907 |  |
| 3027356 | Cobalt [Mass/time] in 24 hour Urine | 0.906 |  |
| 3004849 | Copper [Mass/volume] in 24 hour Urine | 0.906 |  |
| 649327 | Procalcitonin [Measurement] in Serum or Plasma | 0.905 |  |
| 3026941 | Chloride [Moles/time] in 24 hour Stool | 0.905 |  |
| 3017692 | Complement C5 [Mass/volume] in Serum or Plasma | 0.904 |  |
| 3044690 | Nicotine+Cotinine [Presence] in Urine | 0.903 |  |
| 40762708 | Cotinine [Presence] in Urine by Screen method | 0.901 |  |
| 3045531 | Complement C3 and C4 panel [Mass/volume] - Serum or Plasma | 0.900 |  |
| 40760459 | Chloride [Moles/volume] in 2 hour Urine | 0.899 |  |
| 3009274 | Carcinoembryonic Ag [Units/volume] in Pleural fluid | 0.899 |  |
| 3046437 | Complement C4 [Mass/volume] in Peritoneal fluid | 0.898 |  |
| 3045431 | Immune complex.IgG [Mass/volume] in Serum or Plasma | 0.897 |  |
| 3034898 | Cotinine [Presence] in Urine by Confirmatory method | 0.897 |  |
| 645212 | Chromogranin A [Measurement] in Serum or Plasma | 0.897 |  |
| 3026025 | Cotinine cutoff [Mass/volume] in Urine | 0.897 |  |
| 3031021 | Cobalt [Mass/volume] in Body fluid | 0.897 |  |
| 3028447 | Cobalt [Mass/volume] in Serum or Plasma | 0.896 |  |
| 3008108 | Hematocrit [Volume Fraction] of Body fluid | 0.896 | 733 |
| 647455 | Calcium [Measurement] in Serum or Plasma | 0.896 |  |
| 40763889 | Cotinine [Presence] in Serum or Plasma | 0.896 |  |
| 3036347 | Cobalt [Moles/time] in 24 hour Urine | 0.896 |  |
| 3002695 | Complement C4 [Mass/volume] in Body fluid | 0.896 |  |
| 3040481 | Chromium [Moles/time] in 24 hour Urine | 0.895 |  |
| 36031874 | Copper free [Moles/volume] in Serum or Plasma | 0.894 |  |
| 3038258 | Carcinoembryonic Ag [Mass/volume] in Pericardial fluid | 0.893 |  |
| 3006661 | Calcium [Mass/volume] in Urine | 0.893 |  |
| 3008269 | Chromium [Mass/volume] in Serum or Plasma | 0.893 |  |
| 3033517 | Chromium [Mass/volume] in Body fluid | 0.892 |  |
| 3041671 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Venous blood | 0.892 |  |
| 3005268 | Transferrin.carbohydrate deficient [Units/volume] in Serum or Plasma | 0.892 |  |
| 3026979 | Carcinoembryonic Ag [Moles/volume] in Pleural fluid | 0.892 |  |
| 3019696 | Complement C4 [Mass/volume] in Synovial fluid | 0.892 |  |
| 3046784 | Complement C3 [Mass/volume] in Peritoneal fluid | 0.891 |  |
| 40757498 | Calcium.ionized [Moles/volume] in Cord blood | 0.891 |  |
| 3039964 | Chloride [Moles/volume] in Capillary blood | 0.891 |  |
| 3017905 | Immune complex [Units/volume] in Serum or Plasma | 0.891 |  |
| 3004689 | Complement C3 [Mass/volume] in Body fluid | 0.890 |  |
| 3027694 | Calcium.ionized [Mass/volume] in Serum or Plasma | 0.889 |  |
| 649561 | Cotinine [Measurement] in Urine | 0.889 |  |
| 3013194 | Chloride [Moles/volume] in Body fluid | 0.889 |  |
| 3007733 | Chloride [Moles/volume] in Urine | 0.888 | 697 |
| 3006071 | Chromium [Mass/time] in 24 hour Urine | 0.887 |  |
| 3051339 | Copper [Moles/volume] in Blood | 0.887 |  |
| 43055646 | Cotinine [Mass/volume] in Urine by Screen method | 0.887 |  |
| 3023980 | Creatine kinase [Enzymatic activity/volume] in Body fluid | 0.886 |  |
| 3001452 | Complement C3 [Mass/volume] in Synovial fluid | 0.885 |  |
| 3045820 | Cotinine/Creatinine [Mass Ratio] in Urine | 0.885 |  |
| 3005162 | Calcium [Moles/volume] in Blood | 0.885 |  |
| 3042038 | Carcinoembryonic Ag [Mass/volume] in Peritoneal fluid | 0.884 |  |
| 3009237 | Chromogranin A [Units/volume] in Serum or Plasma by Immunoassay | 0.883 |  |
| 645157 | Carcinoembryonic Ag [Measurement] in Pleural fluid | 0.883 |  |
| 3013444 | Carcinoembryonic Ag [Units/volume] in Serum or Plasma | 0.883 |  |
| 3033742 | Chloride panel - 24 hour Urine | 0.883 |  |
| 42869545 | Calcium [Moles/volume] in Urine collected for unspecified duration | 0.882 | 1359 |
| 3013735 | Carcinoembryonic Ag [Mass/volume] in Body fluid | 0.882 |  |
| 46236482 | Norcotinine [Mass/volume] in Urine | 0.882 |  |
| 3045177 | Copper [Moles/volume] in Urine | 0.882 |  |
| 3025059 | Transferrin.carbohydrate deficient [Mass/volume] in Serum or Plasma | 0.881 |  |
| 3004741 | Calcium [Moles/time] in 2 hour Urine --12 hours fasting | 0.879 |  |
| 3045714 | Immune complex.IgM [Mass/volume] in Serum or Plasma | 0.879 |  |
| 37020287 | Cotinine [Mass/volume] in Urine by Confirmatory method | 0.879 |  |
| 3016306 | Chromium [Mass/volume] in Red Blood Cells | 0.878 |  |
| 3023230 | Hematocrit [Volume Fraction] of Arterial blood | 0.874 |  |
| 40758958 | Chloride [Moles/volume] in 24 hour Stool | 0.874 |  |
| 3019273 | Chromium [Mass/volume] in Specimen | 0.874 |  |
| 3009024 | Chloride [Moles/volume] in Specimen | 0.873 |  |
| 3050025 | Chromium [Moles/volume] in Body fluid | 0.872 |  |
| 3027665 | Carcinoembryonic Ag [Moles/volume] in Serum or Plasma | 0.872 |  |
| 3032503 | Calcium [Mass/volume] in Blood | 0.872 |  |
| 3052010 | Complement C3c [Mass/volume] in Body fluid | 0.871 |  |
| 3040485 | Calcium [Mass/volume] in Serum or Plasma --pre XXX challenge | 0.871 |  |
| 1761323 | Chloride [Moles/volume] in Mixed venous blood | 0.871 |  |
| 3013806 | Calcium [Moles/volume] in Specimen | 0.870 |  |
| 3045741 | Immune complex IgA [Mass/volume] in Serum or Plasma | 0.870 |  |
| 3008994 | Creatine kinase.BB [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.869 |  |
| 647668 | Carcinoembryonic Ag [Measurement] in Serum or Plasma | 0.869 |  |
| 3016070 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.867 |  |
| 3016913 | Creatine kinase.MM [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.866 |  |
| 3043948 | Calcium [Moles/volume] in Serum or Plasma --pre XXX challenge | 0.866 |  |
| 3045536 | Immune complex [Presence] in Serum or Plasma | 0.865 |  |
| 3018086 | Chloride [Moles/volume] in Red Blood Cells | 0.865 |  |
| 3041289 | Cotinine [Presence] in Meconium | 0.865 |  |
| 3005785 | Creatine kinase.MB [Mass/volume] in Serum or Plasma | 0.863 | 111 |
| 3005674 | Calcium/Protein [Mass Ratio] in Serum or Plasma | 0.863 |  |
| 647128 | Immune complex [Measurement] in Serum or Plasma | 0.863 |  |
| 36303542 | Calcium goal [Mass/volume] Serum or Plasma | 0.861 |  |
| 3019909 | Hematocrit [Volume Fraction] of Blood by Centrifugation | 0.861 | 545 |
| 3017170 | Calcium [Mass/time] in 12 hour Urine | 0.860 |  |
| 1091592 | Copper panel - Serum or Plasma | 0.859 |  |
| 3007614 | Calcium [Mass/time] in 2 hour Urine | 0.858 |  |
| 3028813 | Hematocrit [Volume Fraction] of Capillary blood | 0.857 |  |
| 3032543 | Calcium [Moles/volume] in Venous blood | 0.857 |  |
| 3004064 | Calcium [Moles/volume] corrected for total protein in Serum or Plasma | 0.857 |  |
| 3008178 | Immune complex [Units/volume] in Body fluid | 0.857 |  |
| 3019205 | Cobalt [Mass/volume] in Specimen | 0.856 |  |
| 3037781 | Chromium [Mass/volume] in Water | 0.856 |  |
| 40760453 | Calcium [Mass/volume] in 12 hour Urine | 0.856 |  |
| 3026798 | Calcium/Sodium [Mass Ratio] in Serum or Plasma | 0.856 |  |
| 3020059 | Calcium [Moles/volume] corrected for albumin in Serum or Plasma | 0.855 | 237 |
| 3048718 | Copper [Moles/volume] in Body fluid | 0.854 |  |
| 42869583 | Hematocrit [Pure volume fraction] of Body fluid | 0.853 |  |
| 3034976 | Hematocrit [Volume Fraction] of Venous blood | 0.852 |  |
| 40762332 | Chromogranin A [Units/volume] in Body fluid | 0.852 |  |
| 3015040 | Creatine kinase.BB/Creatine kinase.total in Serum or Plasma | 0.850 |  |
| 3021311 | Cobalt [Moles/volume] in Serum or Plasma | 0.850 |  |
| 3049668 | Complement C3 [Presence] in Serum or Plasma | 0.849 |  |
| 3000321 | Chromium [Moles/volume] in Serum or Plasma | 0.848 |  |
| 40762093 | Calcium [Mass/time] in 18 hour Urine | 0.848 |  |
| 3052708 | Transferrin.carbohydrate deficient/Transferrin.total in Serum or Plasma | 0.847 |  |
| 3039094 | Chromium [Mass/volume] in Air | 0.847 |  |
| 3050998 | Immune Complex C3d [Mass/volume] in Serum or Plasma | 0.846 |  |
| 3050746 | Hematocrit [Volume Fraction] of Blood by Estimated | 0.846 |  |
| 3017858 | Calcium [Mass/time] in 4 hour Urine | 0.846 |  |
| 3030170 | Creatine kinase [Mass/volume] in Blood | 0.846 |  |
| 3016311 | Creatine kinase.MB/Creatine kinase.total in Serum or Plasma | 0.845 | 297 |
| 3024431 | Calcium [Mass/volume] in 4 hour Urine | 0.845 |  |
| 3023729 | Carcinoembryonic Ag [Mass/volume] in Cerebral spinal fluid | 0.845 |  |
| 3006044 | Creatine kinase.total/Creatine kinase.MB [Enzymatic activity ratio] in Serum or Plasma | 0.844 |  |
| 3029886 | Cobalt [Moles/volume] in Red Blood Cells | 0.844 |  |
| 3005389 | Copper [Moles/volume] in Specimen | 0.844 |  |
| 3021530 | Procollagen type I [Mass/volume] in Serum | 0.843 |  |
| 3019027 | Nicotine [Presence] in Urine | 0.843 |  |
| 3008558 | Creatine kinase.MM/Creatine kinase.total in Serum or Plasma | 0.842 |  |
| 3040291 | Chromium panel - Urine | 0.841 |  |
| 3017058 | Calcium [Moles/volume] in Stool | 0.841 |  |
| 3006619 | Chromium [Mass/volume] in Saliva (oral fluid) | 0.839 |  |
| 3048252 | Creatine kinase.MiMi/Creatine kinase.total in Serum or Plasma | 0.839 |  |
| 36031387 | Copper free [Mass/volume] in Serum or Plasma | 0.839 |  |
| 40761050 | Cobalt [Mass/volume] in Cerebral spinal fluid | 0.838 |  |
| 648684 | Copper [Measurement] in Urine | 0.838 |  |
| 42869584 | Hematocrit [Pure volume fraction] of Venous blood | 0.836 |  |
| 1616377 | Carcinoembryonic Ag [Mass/volume] in Aspirate | 0.835 |  |
| 3048150 | Creatine kinase.MB [Presence] in Serum or Plasma | 0.833 |  |
| 3017761 | Creatine kinase isoenzymes [Interpretation] in Serum or Plasma | 0.831 |  |
| 3009090 | Calcium [Moles/volume] in Urine --2nd specimen post XXX challenge | 0.831 |  |
| 3034238 | Transferrin.carbohydrate deficient.disialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.831 |  |
| 3052662 | Ceruloplasmin [Moles/volume] in Serum or Plasma | 0.830 |  |
| 3010989 | Calcitonin [Mass/volume] in Serum or Plasma | 0.830 | 1605 |
| 3003031 | Transferrin.carbohydrate deficient.disialo/Transferrin.total in Serum or Plasma | 0.829 |  |
| 3049714 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma | 0.829 |  |
| 3008152 | Bicarbonate [Moles/volume] in Arterial blood | 0.829 | 310 |
| 649302 | Immune complex [Measurement] in Body fluid | 0.829 |  |
| 3005396 | Chloride [Moles/volume] in Vitreous fluid | 0.828 |  |
| 3040026 | Transferrin.carbohydrate deficient panel - Serum or Plasma | 0.827 |  |
| 1175635 | Transferrin.carbohydrate deficient.trisialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.827 |  |
| 3000531 | Carcinoembryonic Ag [Mass/volume] in Semen | 0.826 |  |
| 3034154 | Transferrin.carbohydrate deficient.trisialo/Transferrin.total in Serum or Plasma | 0.822 |  |
| 40757500 | Chloride [Moles/volume] in Serum or Plasma --post dialysis | 0.821 |  |
| 3039936 | Copper/Creatinine [Molar ratio] in 24 hour Urine | 0.820 |  |
| 3036413 | Transferrin.carbohydrate deficient.asialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.819 |  |
| 647174 | Calcium.ionized [Measurement] in Serum or Plasma | 0.819 |  |
| 40762318 | Chromogranin A [Units/volume] in Cerebral spinal fluid | 0.818 |  |
| 3040335 | Chloride/Creatinine [Ratio] in 24 hour Urine | 0.817 |  |
| 3030993 | Tin [Moles/time] in 24 hour Urine | 0.816 |  |
| 37020917 | Transferrin.carbohydrate deficient.disialo/Transferrin.total standardized per IFCC-RMP for CDT in Serum or Plasma | 0.816 |  |
| 3044443 | Immune Complex C3d [Units/volume] in Serum or Plasma | 0.815 |  |
| 3038215 | Transferrin.carbohydrate deficient.tetrasialo/Transferrin.total in Serum or Plasma | 0.813 |  |
| 3043266 | Transferrin.carbohydrate deficient.asialo/Transferrin.carbohydrate deficient.disialo [Mass Ratio] in Serum or Plasma | 0.813 |  |
| 3052628 | Collagen type 1 Ab [Units/volume] in Serum | 0.812 |  |
| 1988213 | Chloride/Creatinine [Molar ratio] in 24 hour Urine | 0.812 |  |
| 3002754 | Copper [Mass/volume] in Urine collected for unspecified duration | 0.808 |  |
| 40762311 | Chromogranin A [Units/volume] in Pleural fluid | 0.808 |  |
| 42869547 | Procollagen type III.N-terminal propeptide [Mass/volume] in Serum | 0.806 |  |
| 3028506 | Copper [Mass/volume] in Urine | 0.805 |  |
| 3041449 | Collagen crosslinked C-telopeptide [Mass/volume] in Serum or Plasma | 0.802 |  |
| 46236075 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma by Immunoassay | 0.800 |  |
| 21494382 | Copper intake 24 hour Measured | 0.798 |  |
| 3965143 | Calprotectin [Mass/volume] in Serum or Plasma | 0.795 |  |
| 648592 | Complement C3+C4+ C1q Ab.IgG panel - Serum or Plasma | 0.792 |  |
| 3038588 | Complement C2 [Presence] in Serum or Plasma | 0.790 |  |
| 3046399 | Transferrin.carbohydrate deficient.monosialo/Transferrin.carbohydrate deficient.disialo [Mass Ratio] in Serum or Plasma | 0.789 |  |
| 3052973 | Complement C4 [Presence] in Serum or Plasma | 0.786 |  |
| 3003415 | Copper/Creatinine [Mass Ratio] in 24 hour Urine | 0.786 |  |
| 3000301 | Heavy metals [Presence] in 24 hour Urine | 0.786 |  |
| 3046458 | Immune complex [Presence] in Serum or Plasma by C1q binding assay | 0.786 |  |
| 40759746 | Procollagen type III [Mass/volume] in Serum | 0.783 |  |
| 648687 | Cobalt/Creatinine [Measurement] in Urine | 0.782 |  |
| 3037209 | Collagen Ab [Units/volume] in Serum | 0.782 |  |
| 3009927 | Gastrin [Mass/volume] in Serum or Plasma | 0.781 | 1411 |
| 3023920 | Nickel [Presence] in Urine | 0.779 |  |
| 3052033 | Collagen.bovine type 1 Ab [Units/volume] in Serum | 0.779 |  |
| 40762317 | Chromogranin A [Units/volume] in Peritoneal fluid | 0.779 |  |
| 3000163 | Transferrin.carbohydrate deficient.asialo/Transferrin.total in Serum or Plasma | 0.777 |  |
| 646391 | Immune complex.IgG [Measurement] in Serum or Plasma | 0.776 |  |
| 3018840 | Calcitonin [Moles/volume] in Serum or Plasma | 0.774 |  |
| 3001919 | Transferrin.carbohydrate deficient.monosialo/Transferrin.total in Serum or Plasma | 0.772 |  |
| 3008440 | Collagen crosslinked N-telopeptide [Moles/volume] in Serum | 0.772 |  |
| 40761986 | Calcitonin [Mass/volume] in Serum or Plasma --baseline | 0.772 |  |
| 3043240 | Immune complex [Presence] in Serum or Plasma by Raji cell assay | 0.769 |  |
| 3022947 | Cobalt/Creatinine [Mass Ratio] in Urine | 0.765 |  |
| 3004722 | Prolactin [Mass/volume] in Serum or Plasma | 0.763 | 290 |
| 3010370 | Gastrin [Moles/volume] in Serum or Plasma | 0.763 |  |
| 3046728 | Iron [Presence] in Serum or Plasma | 0.762 |  |
| 3002091 | Choriogonadotropin [Moles/volume] in Serum or Plasma | 0.761 |  |
| 36031941 | Copper free/Total copper in Serum or Plasma by calculation | 0.757 |  |
| 3023433 | Cobalt/Creatinine [Mass Ratio] in 24 hour Urine | 0.749 |  |
| 3022756 | Ceruloplasmin [Mass/volume] in Serum or Plasma | 0.740 | 777 |
| 3040880 | Ceruloplasmin actual/normal in Serum or Plasma | 0.740 |  |
| 3040526 | Collagen crosslinked C-telopeptide [Moles/volume] in Serum or Plasma | 0.737 |  |
| 645187 | Iron [Measurement] in Serum or Plasma | 0.735 |  |
| 40757501 | Chloride [Mass/volume] in Body fluid | 0.732 |  |
| 40760866 | Procollagen type III.N-terminal propeptide [Units/volume] in Serum | 0.732 |  |
| 1002263 | Chloride [Moles/volume] in Serum or Plasma --1 hour post dose vasopressin | 0.728 |  |
| 3003143 | Carcinoembryonic Ag [Units/volume] in Semen | 0.728 |  |
| 44816885 | Collagen crosslinked C-telopeptide [Z-score] in Serum or Plasma | 0.726 |  |
| 1001843 | Chloride [Moles/volume] in Serum or Plasma --2 hours post dose vasopressin | 0.726 |  |
| 646316 | Squamous cell carcinoma Ag [Measurement] in Pleural fluid | 0.723 |  |
| 36303415 | Chloride [Mass/volume] in Specimen | 0.714 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 487 | -c3d |  | 100% | name | 313 | 100 |  |  |  |  | Complement C3d in Serum or Plasma |
| 488 | -cdt | mg/l | 100% | name+unit+values | 465 | 0 | [30.93, 34.48, 37.2, 39.51, 41.65, 44.52, 47.1, 52.61, 66.32] |  |  |  | Carbohydrate deficient transferrin [Mass/volume] in Serum |
| 489 | -cea | ug/l | 62% | name+unit+values | 86 | 0 | [3.1, 10.24, 23.5, 45.82, 86.95, 226.27, 430.37, 1163.15, 2504] | -Karsinoembryonaalinen antigeeni |  |  | Carcinoembryonic antigen [Mass/volume] in Serum or Plasma |
| 490 | -cea |  | 38% | name | 53 | 100 |  | -Karsinoembryonaalinen antigeeni |  |  | Carcinoembryonic antigen in Serum or Plasma |
| 491 | ab-cl | mmol/l | 100% | name+unit+values | 1123 | 0 | [96.62, 99.74, 102.05, 103.97, 105.1, 106.54, 107.91, 109, 111.34] |  | Arterial blood | Clearance | Chloride [Moles/volume] in Arterial blood |
| 492 | ap-cl | mmol/l | 76% | name+unit+values | 271 | 0 | [96.53, 101.68, 104.11, 105.92, 106.9, 108.61, 110, 111, 114.15] |  |  | Clearance | Chloride [Moles/volume] in Arterial plasma |
| 493 | ap-cl |  | 24% | name | 84 | 100 |  |  |  | Clearance | Chloride in Arterial plasma |
| 494 | b-cl | mmol/l | 86% | name+unit+values | 51262 | 0 | [99.4, 101.98, 103.81, 104.99, 106, 107.02, 108.25, 109.8, 112.07] |  | Blood | Clearance | Chloride [Moles/volume] in Blood |
| 495 | b-cl |  | 14% | name | 8059 | 100 |  |  | Blood | Clearance | Chloride in Blood |
| 496 | b-co | ug/l | 89% | name+unit+values | 4244 | 0 | [0.61, 0.84, 1.09, 1.4, 1.88, 2.76, 4.17, 6.44, 10.87] | B -Koboltti | Blood |  | Cobalt [Mass/volume] in Blood |
| 497 | b-co |  | 11% | name+values | 508 | 100 | [0.9, 1, 1, 1.08, 1.7, 2.07, 3.1, 4.15, 6] | B -Koboltti | Blood |  | Cobalt [Mass/volume] in Blood |
| 498 | b-cr | ug/l | 79% | name+unit+values | 3775 | 0 | [0.74, 1.01, 1.2, 1.43, 1.74, 2.14, 2.74, 3.65, 5.6] | B -Kromi | Blood |  | Chromium [Mass/volume] in Blood |
| 499 | b-cr |  | 21% | name+values | 980 | 100 | [1, 1, 1, 1.2, 1.6, 2, 2.16, 2.94, 3.6] | B -Kromi | Blood |  | Chromium [Mass/volume] in Blood |
| 500 | b-cya | ug/l | 95% | name+unit+values | 25550 | 0 | [60.87, 72.59, 81.84, 90.47, 100.07, 111.93, 131.29, 164.82, 225.76] | B -Syklosporiini A | Blood |  | Cyclosporine [Mass/volume] in Blood |
| 501 | b-cya |  | 5% | name+values | 1477 | 100 | [61.13, 73.24, 78.64, 86.8, 95.21, 104.77, 117.98, 151.78, 199.49] | B -Syklosporiini A | Blood |  | Cyclosporine [Mass/volume] in Blood |
| 502 | du-ca | *sai | 0% | name+unit | 6 | 0 |  | dU-Kalsium | 24-hour urine |  | Calcium in 24 hour Urine |
| 503 | du-ca | mmol/24h | 89% | name+unit+values | 13838 | 0.02 | [1.76, 2.76, 3.64, 4.51, 5.38, 6.33, 7.4, 8.73, 10.72] | dU-Kalsium | 24-hour urine |  | Calcium [Moles/time] in 24 hour Urine |
| 504 | du-ca |  | 11% | name | 1693 | 100 |  | dU-Kalsium | 24-hour urine |  | Calcium in 24 hour Urine |
| 505 | du-cl | mmol | 81% | name+unit+values | 411 | 0 | [81.75, 104.44, 123.91, 140.06, 160.24, 175.41, 203.5, 249.04, 310.48] | dU-Kloridi | 24-hour urine | Clearance | Chloride [Moles/time] in 24 hour Urine |
| 506 | du-cl |  | 19% | name | 94 | 100 |  | dU-Kloridi | 24-hour urine | Clearance | Chloride in 24 hour Urine |
| 507 | du-cu | umol | 25% | name+unit+values | 94 | 1.06 | [0.16, 0.21, 0.28, 0.39, 0.78, 1.92, 4.29, 6.52, 10.65] | dU-Kupari | 24-hour urine |  | Copper [Moles/time] in 24 hour Urine |
| 508 | du-cu | umol/24h | 34% | name+unit+values | 127 | 0 | [0.13, 0.17, 0.18, 0.22, 0.28, 0.36, 0.73, 3.44, 9.31] | dU-Kupari | 24-hour urine |  | Copper [Moles/time] in 24 hour Urine |
| 509 | du-cu |  | 41% | name | 154 | 100 |  | dU-Kupari | 24-hour urine |  | Copper in 24 hour Urine |
| 510 | fp-ca | mmol/l | 99% | name+unit+values | 61661 | 0 | [2.2, 2.26, 2.3, 2.33, 2.36, 2.39, 2.42, 2.46, 2.51] | fP-Kalsium | Fasting plasma |  | Calcium [Moles/volume] in Serum or Plasma |
| 511 | fp-ca |  | 1% | name | 407 | 100 |  | fP-Kalsium | Fasting plasma |  | Calcium in Serum or Plasma |
| 512 | fp-cga | nmol/l | 95% | name+unit+values | 10003 | 0.03 | [0.72, 1.15, 1.84, 2.33, 2.83, 3.49, 4.63, 7.79, 19.95] | fP-Kromograniini A | Fasting plasma |  | Chromogranin A [Moles/volume] in Serum or Plasma |
| 513 | fp-cga |  | 5% | name+values | 571 | 100 | [1.96, 2.33, 2.55, 2.88, 3.13, 3.69, 4.46, 5.71, 8.06] | fP-Kromograniini A | Fasting plasma |  | Chromogranin A [Moles/volume] in Serum or Plasma |
| 514 | fs-ca | mmol/l | 99% | name+unit+values | 1580 | 0 | [2.25, 2.3, 2.33, 2.36, 2.39, 2.41, 2.44, 2.47, 2.52] |  | Fasting serum |  | Calcium [Moles/volume] in Serum or Plasma |
| 515 | fs-ca |  | 1% | name | 9 | 100 |  |  | Fasting serum |  | Calcium in Serum or Plasma |
| 516 | fs-cga | nmol/l | 95% | name+unit+values | 6208 | 0 | [0.71, 0.95, 1.19, 1.46, 1.91, 2.49, 3.38, 5.29, 12.84] | fS-Kromograniini A | Fasting serum |  | Chromogranin A [Moles/volume] in Serum or Plasma |
| 517 | fs-cga | ug/l | 0% | name+unit | 11 | 0 |  | fS-Kromograniini A | Fasting serum |  | Chromogranin A [Mass/volume] in Serum or Plasma |
| 518 | fs-cga |  | 5% | name+values | 331 | 100 | [1, 1, 1, 1.17, 1.99, 2.13, 3.28, 4.74, 10.29] | fS-Kromograniini A | Fasting serum |  | Chromogranin A [Moles/volume] in Serum or Plasma |
| 519 | mb-cl | mmol/l | 96% | name+unit | 2504 | 0 |  |  |  | Clearance | Chloride [Moles/volume] in Blood |
| 520 | mb-cl |  | 4% | name | 105 | 100 |  |  |  | Clearance | Chloride in Blood |
| 521 | p-c3 | g/l | 95% | name+unit+values | 14303 | 0 | [0.75, 0.87, 0.95, 1.02, 1.1, 1.18, 1.26, 1.35, 1.49] | P -Komplementti C3 | Plasma |  | Complement C3 [Mass/volume] in Serum or Plasma |
| 522 | p-c3 |  | 5% | name+values | 748 | 100 | [0.79, 0.89, 0.96, 1.02, 1.1, 1.15, 1.23, 1.33, 1.48] | P -Komplementti C3 | Plasma |  | Complement C3 [Mass/volume] in Serum or Plasma |
| 523 | p-c4 | g/l | 94% | name+unit+values | 13926 | 0 | [0.1, 0.13, 0.16, 0.18, 0.2, 0.22, 0.24, 0.27, 0.31] | P -Komplementti C4 | Plasma |  | Complement C4 [Mass/volume] in Serum or Plasma |
| 524 | p-c4 |  | 6% | name+values | 953 | 100 | [0.1, 0.14, 0.17, 0.19, 0.2, 0.23, 0.25, 0.28, 0.32] | P -Komplementti C4 | Plasma |  | Complement C4 [Mass/volume] in Serum or Plasma |
| 525 | p-ca | mmol/l | 99% | name+unit+values | 424377 | 0 | [2.21, 2.27, 2.31, 2.34, 2.37, 2.4, 2.43, 2.47, 2.53] | P -Kalsium | Plasma |  | Calcium [Moles/volume] in Serum or Plasma |
| 526 | p-ca |  | 1% | name | 5509 | 100 |  | P -Kalsium | Plasma |  | Calcium in Serum or Plasma |
| 527 | p-cea | ug/l | 84% | name+unit+values | 53825 | 0 | [1.59, 2.01, 2.37, 2.8, 3.39, 4.25, 5.72, 9.36, 30.62] | P -Karsinoembryonaalinen antigeeni | Plasma |  | Carcinoembryonic antigen [Mass/volume] in Serum or Plasma |
| 528 | p-cea |  | 16% | name | 10275 | 100 |  | P -Karsinoembryonaalinen antigeeni | Plasma |  | Carcinoembryonic antigen in Serum or Plasma |
| 529 | p-ck | u/l | 98% | name+unit+values | 278981 | 0 | [42.95, 58.04, 71.6, 86.71, 104.44, 129.55, 169.7, 253.54, 545.62] | P -Kreatiinikinaasi | Plasma |  | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma |
| 530 | p-ck |  | 2% | name | 4344 | 100 |  | P -Kreatiinikinaasi | Plasma |  | Creatine kinase in Serum or Plasma |
| 531 | p-cl | mmol/l | 100% | name+unit+values | 441381 | 0.01 | [97.91, 100.97, 102.85, 104, 105.19, 106.56, 107.81, 109.04, 111.15] | P -Kloridi | Plasma | Clearance | Chloride [Moles/volume] in Serum or Plasma |
| 532 | p-cl |  | 0% | name+values | 2019 | 100 | [96.43, 100.31, 102, 103.61, 104.81, 106, 106.99, 108, 109.87] | P -Kloridi | Plasma | Clearance | Chloride [Moles/volume] in Serum or Plasma |
| 533 | p-cu | umol/l | 82% | name+unit+values | 362 | 0 | [11.87, 13.34, 14.27, 15.36, 16.22, 16.79, 17.66, 19.1, 21.13] | P -Kupari | Plasma |  | Copper [Moles/volume] in Serum or Plasma |
| 534 | p-cu |  | 18% | name | 81 | 100 |  | P -Kupari | Plasma |  | Copper in Serum or Plasma |
| 535 | pf-c3 | g/l | 81% | name+unit+values | 143 | 0 | [0.16, 0.25, 0.28, 0.33, 0.37, 0.43, 0.52, 0.59, 0.67] | Pf-Komplementti C3 | Pleural fluid |  | Complement C3 [Mass/volume] in Pleural fluid |
| 536 | pf-c3 |  | 19% | name | 33 | 100 |  | Pf-Komplementti C3 | Pleural fluid |  | Complement C3 in Pleural fluid |
| 537 | pf-c4 | g/l | 70% | name+unit+values | 129 | 0 | [0.02, 0.03, 0.04, 0.05, 0.07, 0.08, 0.09, 0.1, 0.12] | Pf-Komplementti C4 | Pleural fluid |  | Complement C4 [Mass/volume] in Pleural fluid |
| 538 | pf-c4 |  | 30% | name | 55 | 100 |  | Pf-Komplementti C4 | Pleural fluid |  | Complement C4 in Pleural fluid |
| 539 | pf-cea | ug/l | 53% | name+unit+values | 765 | 0 | [0.7, 1.09, 1.25, 1.54, 2, 2.48, 4.54, 27.69, 279.67] | Pf-Karsinoembryonaalinen antigeeni | Pleural fluid |  | Carcinoembryonic antigen [Mass/volume] in Pleural fluid |
| 540 | pf-cea |  | 47% | name | 670 | 100 |  | Pf-Karsinoembryonaalinen antigeeni | Pleural fluid |  | Carcinoembryonic antigen in Pleural fluid |
| 541 | s-c3 | g/l | 96% | name+unit+values | 10697 | 0 | [0.77, 0.9, 0.98, 1.06, 1.13, 1.21, 1.3, 1.41, 1.56] | S -Komplementti C3 | Serum |  | Complement C3 [Mass/volume] in Serum or Plasma |
| 542 | s-c3 |  | 4% | name+values | 394 | 100 | [0.84, 0.96, 1.01, 1.06, 1.15, 1.24, 1.31, 1.42, 1.59] | S -Komplementti C3 | Serum |  | Complement C3 [Mass/volume] in Serum or Plasma |
| 543 | s-c4 | g/l | 95% | name+unit+values | 10528 | 0 | [0.11, 0.14, 0.17, 0.2, 0.22, 0.24, 0.27, 0.3, 0.34] | S -Komplementti C4 | Serum |  | Complement C4 [Mass/volume] in Serum or Plasma |
| 544 | s-c4 |  | 5% | name+values | 506 | 100 | [0.11, 0.15, 0.18, 0.2, 0.22, 0.24, 0.26, 0.27, 0.31] | S -Komplementti C4 | Serum |  | Complement C4 [Mass/volume] in Serum or Plasma |
| 545 | s-ca | g/l | 0% | name+unit | 8 | 0 |  | S -Kalsium | Serum |  | Calcium [Mass/volume] in Serum or Plasma |
| 546 | s-ca | mmol/l | 99% | name+unit+values | 20957 | 0 | [2.23, 2.27, 2.3, 2.33, 2.35, 2.38, 2.4, 2.43, 2.48] | S -Kalsium | Serum |  | Calcium [Moles/volume] in Serum or Plasma |
| 547 | s-ca |  | 1% | name+values | 114 | 100 | [2.11, 2.22, 2.24, 2.29, 2.33, 2.36, 2.4, 2.42, 2.5] | S -Kalsium | Serum |  | Calcium [Moles/volume] in Serum or Plasma |
| 548 | s-cdt | % | 97% | name+unit+values | 102065 | 0 | [0.79, 1.14, 1.3, 1.41, 1.5, 1.6, 1.7, 1.9, 2.36] | S -Desialotransferriini | Serum |  | Carbohydrate deficient transferrin/Transferrin.total [Molar ratio] in Serum |
| 549 | s-cdt | u/l | 0% | name+unit | 35 | 0 |  | S -Desialotransferriini | Serum |  | Carbohydrate deficient transferrin [Units/volume] in Serum |
| 550 | s-cdt |  | 3% | name | 2936 | 100 |  | S -Desialotransferriini | Serum |  | Carbohydrate deficient transferrin in Serum |
| 551 | s-cea | ug/l | 79% | name+unit+values | 90194 | 0 | [1.12, 1.4, 1.69, 2.03, 2.45, 3.05, 4.05, 6.32, 17.53] | S -Karsinoembryonaalinen antigeeni | Serum |  | Carcinoembryonic antigen [Mass/volume] in Serum or Plasma |
| 552 | s-cea |  | 21% | name | 23960 | 100 |  | S -Karsinoembryonaalinen antigeeni | Serum |  | Carcinoembryonic antigen in Serum or Plasma |
| 553 | s-cic | ugeq/ml | 95% | name+unit+values | 728 | 0 | [2, 2.11, 3, 4, 5.61, 6.93, 9.29, 12.82, 20.44] | S -Immunokompleksit, kiertävät | Serum |  | Immune complex [Mass/volume] in Serum |
| 554 | s-cic |  | 5% | name | 36 | 100 |  | S -Immunokompleksit, kiertävät | Serum |  | Immune complex in Serum |
| 555 | s-ck | u/l | 99% | name+unit+values | 11560 | 0 | [55.21, 68.52, 80.72, 93.9, 109.16, 127.95, 153.42, 197.38, 289.68] | S -Kreatiinikinaasi | Serum |  | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma |
| 556 | s-ck |  | 1% | name | 102 | 100 |  | S -Kreatiinikinaasi | Serum |  | Creatine kinase in Serum or Plasma |
| 557 | s-cl | mmol/l | 100% | name+unit+values | 194 | 0 | [97.57, 100, 101, 102, 103, 104, 104.97, 106, 107] | S -Kloridi | Serum | Clearance | Chloride [Moles/volume] in Serum or Plasma |
| 558 | s-cu | umol/l | 93% | name+unit+values | 1531 | 0 | [11.56, 13.12, 14.07, 15.01, 15.92, 16.9, 18.04, 19.54, 22.14] | S -Kupari | Serum |  | Copper [Moles/volume] in Serum or Plasma |
| 559 | s-cu |  | 7% | name+values | 119 | 100 | [12, 13.59, 14.88, 16, 17.1, 18.8, 20.92, 22.95, 25.9] | S -Kupari | Serum |  | Copper [Moles/volume] in Serum or Plasma |
| 560 | s-ictp | ug/l | 90% | name+unit+values | 801 | 0 | [2.67, 3.25, 3.82, 4.4, 4.92, 5.81, 6.67, 8.24, 11.6] | S -Kollageeni I:n karboksiterminaalinen telopeptidi | Serum |  | Collagen type I telopeptide.carboxyterminal [Mass/volume] in Serum |
| 561 | s-ictp | âug/l | 1% | name+unit | 11 | 0 |  | S -Kollageeni I:n karboksiterminaalinen telopeptidi | Serum |  | Collagen type I telopeptide.carboxyterminal [Mass/volume] in Serum |
| 562 | s-ictp |  | 8% | name | 75 | 100 |  | S -Kollageeni I:n karboksiterminaalinen telopeptidi | Serum |  | Collagen type I telopeptide.carboxyterminal in Serum |
| 563 | s-pct | ug/l | 76% | name+unit+values | 4418 | 0 | [0.06, 0.09, 0.12, 0.17, 0.23, 0.34, 0.54, 1, 3.09] | S -Prokalsitoniini | Serum |  | Procalcitonin [Mass/volume] in Serum or Plasma |
| 564 | s-pct |  | 24% | name+values | 1380 | 100 | [1.39, 2.13, 8.8, 12.06, 16.31, 22.57, 28.84, 42.06, 68.76] | S -Prokalsitoniini | Serum |  | Procalcitonin [Mass/volume] in Serum or Plasma |
| 565 | ts-cc |  | 100% | name | 582 | 100 |  |  | Tissue |  |  |
| 566 | u-ca | mmol/l | 92% | name+unit+values | 2045 | 0 | [0.72, 1.18, 1.57, 2, 2.5, 3.06, 3.75, 4.62, 6.4] | U -Kalsium | Urine |  | Calcium [Moles/volume] in Urine |
| 567 | u-ca |  | 8% | name+values | 184 | 100 | [1.03, 1.34, 1.77, 1.9, 2.01, 2.25, 2.9, 4.1, 4.72] | U -Kalsium | Urine |  | Calcium [Moles/volume] in Urine |
| 568 | u-co | form | 5% | name+unit | 15 | 0 |  | U -Koboltti | Urine |  | Cobalt [Presence] in Urine |
| 569 | u-co | nmol/l | 69% | name+unit+values | 197 | 2.54 | [3.97, 5.82, 9.12, 16.26, 25.4, 41.63, 60.62, 94.57, 169.48] | U -Koboltti | Urine |  | Cobalt [Moles/volume] in Urine |
| 570 | u-co | ug/l | 5% | name+unit | 13 | 7.69 |  | U -Koboltti | Urine |  | Cobalt [Mass/volume] in Urine |
| 571 | u-co |  | 22% | name | 62 | 100 |  | U -Koboltti | Urine |  | Cobalt in Urine |
| 572 | u-cot | ng/ml | 4% | name+unit | 23 | 0 |  | U -Kotiniini | Urine |  | Cotinine [Mass/volume] in Urine |
| 573 | u-cot | ug/l | 18% | name+unit+values | 95 | 0 | [50, 228.5, 353.33, 580, 746.38, 949.5, 1247.5, 1604.25, 2426] | U -Kotiniini | Urine |  | Cotinine [Mass/volume] in Urine |
| 574 | u-cot |  | 78% | name | 422 | 100 |  | U -Kotiniini | Urine |  | Cotinine [Presence] in Urine |
| 575 | u-cr | form | 2% | name+unit | 8 | 0 |  | U -Kromi | Urine |  | Chromium [Presence] in Urine |
| 576 | u-cr | ug/l | 5% | name+unit | 25 | 0 |  | U -Kromi | Urine |  | Chromium [Mass/volume] in Urine |
| 577 | u-cr | umol/l | 42% | name+unit+values | 211 | 1.42 | [0.01, 0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.06, 0.09] | U -Kromi | Urine |  | Chromium [Moles/volume] in Urine |
| 578 | u-cr |  | 51% | name | 259 | 100 |  | U -Kromi | Urine |  | Chromium in Urine |
| 579 | v-hct |  | 100% | name+values | 258 | 100 | [0.33, 0.36, 0.38, 0.4, 0.41, 0.42, 0.45, 0.46, 0.49] |  |  |  | Hematocrit [Volume Fraction] in Blood |
| 580 | v-ica |  | 100% | name+values | 294 | 100 | [1.08, 1.12, 1.15, 1.17, 1.19, 1.2, 1.22, 1.24, 1.27] |  |  |  | Calcium.ionized [Moles/volume] in Blood |
| 581 | vp-cl | mmol/l | 98% | name+unit+values | 10892 | 0 | [99.57, 102.23, 103.93, 105.1, 106.07, 107.13, 108.26, 109.58, 111.2] |  |  | Clearance | Chloride [Moles/volume] in Venous plasma |
| 582 | vp-cl |  | 2% | name | 175 | 100 |  |  |  | Clearance | Chloride in Venous plasma |

