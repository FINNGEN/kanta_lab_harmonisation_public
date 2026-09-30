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
Here is group 44.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 1616780 | Bilirubin.total [Moles/volume] in Capillary blood | 1.000 |  |
| 3000764 | Benzodiazepines [Presence] in Urine | 1.000 | 196 |
| 3002395 | Porphobilinogen [Moles/volume] in Urine | 1.000 |  |
| 3004176 | fentaNYL [Presence] in Urine | 1.000 | 1509 |
| 3006140 | Bilirubin.total [Moles/volume] in Serum or Plasma | 1.000 | 21 |
| 3007463 | Buprenorphine [Presence] in Urine | 1.000 | 812 |
| 3007733 | Chloride [Moles/volume] in Urine | 1.000 | 697 |
| 3010600 | Phosphate [Moles/time] in 24 hour Urine | 1.000 | 1478 |
| 3013494 | Arsenic.inorganic [Mass/volume] in Urine | 1.000 |  |
| 3015736 | pH of Urine | 1.000 | 612 |
| 3017400 | Magnesium [Moles/volume] in Urine | 1.000 |  |
| 3017937 | Magnesium [Moles/time] in 24 hour Urine | 1.000 |  |
| 3022229 | Phosphate [Moles/volume] in Urine | 1.000 | 1197 |
| 3025942 | Nickel [Mass/volume] in Urine | 1.000 |  |
| 3026008 | Bacteria identified in Urine by Culture | 1.000 | 93 |
| 3027944 | Amphetamines [Presence] in Urine | 1.000 | 214 |
| 3028300 | Cannabinoids [Presence] in Urine | 1.000 |  |
| 3030458 | Arsenic.inorganic [Moles/volume] in Urine | 1.000 |  |
| 3030704 | Iodide [Mass/volume] in Urine | 1.000 |  |
| 3033543 | Specific gravity of Urine | 1.000 | 122 |
| 3035060 | Mercury [Moles/volume] in Blood | 1.000 | 1314 |
| 3036180 | Methadone [Presence] in Urine | 1.000 | 417 |
| 3037426 | Urobilinogen [Presence] in Urine by Test strip | 1.000 | 134 |
| 3040794 | Aluminum [Moles/volume] in Urine | 1.000 |  |
| 3044316 | Mercury [Moles/volume] in Urine | 1.000 |  |
| 3044597 | Porphobilinogen/Creatinine [Molar ratio] in Urine | 1.000 |  |
| 3044943 | Nickel [Moles/volume] in Urine | 1.000 |  |
| 3045284 | traMADol [Presence] in Urine | 1.000 |  |
| 3045424 | Erythrocytes [Presence] in Urine | 1.000 | 287 |
| 44787084 | Porphobilinogen/Creatinine [Molar ratio] in 24 hour Urine | 0.973 |  |
| 46235782 | Bilirubin.total [Moles/volume] in Serum, Plasma or Blood | 0.970 |  |
| 3009201 | Thyrotropin [Units/volume] in Serum or Plasma | 0.967 | 105 |
| 42870560 | Thyrotropin [Units/volume] in Cord blood | 0.964 |  |
| 1091049 | Amphetamine [Presence] in Urine | 0.963 |  |
| 3022454 | Porphobilinogen/Creatinine [Mass Ratio] in Urine | 0.958 |  |
| 3031400 | Arsenic.inorganic [Mass/volume] in 24 hour Urine | 0.957 |  |
| 1091059 | Erythrocytes [Presence] in Urine sediment | 0.956 |  |
| 3051252 | Vasoactive intestinal peptide [Moles/volume] in Serum or Plasma | 0.956 |  |
| 3021916 | Phosphate [Moles/volume] in 24 hour Urine | 0.955 |  |
| 3041918 | Cholesterol [Moles/volume] in Pleural fluid | 0.952 |  |
| 3012095 | Magnesium [Moles/volume] in Serum or Plasma | 0.952 | 78 |
| 3025734 | Magnesium [Moles/volume] in 24 hour Urine | 0.951 |  |
| 3023399 | Thyrotropin [Units/volume] in Blood | 0.951 |  |
| 3003738 | Nickel [Mass/volume] in 24 hour Urine | 0.950 |  |
| 40757494 | Bilirubin.total [Moles/volume] in Blood | 0.949 |  |
| 3027464 | Nickel [Moles/volume] in 24 hour Urine | 0.948 |  |
| 3010015 | Selenium [Moles/volume] in Serum or Plasma | 0.945 | 1614 |
| 3018834 | Bilirubin.total [Presence] in Urine by Test strip | 0.944 | 64 |
| 3044592 | Porphobilinogen [Moles/volume] in 24 hour Urine | 0.943 |  |
| 3005219 | Iodine [Mass/volume] in Urine | 0.941 |  |
| 3001736 | Aluminum [Moles/volume] in 24 hour Urine | 0.941 |  |
| 3041509 | Phosphate [Moles/time] in 12 hour Urine | 0.940 |  |
| 40763806 | fentaNYL [Presence] in Specimen | 0.938 |  |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.937 |  |
| 3044311 | Mercury [Moles/volume] in 24 hour Urine | 0.937 |  |
| 40765224 | Urobilinogen [Presence] in Urine by Automated test strip | 0.937 |  |
| 3052141 | Buprenorphine+Norbuprenorphine [Presence] in Urine | 0.937 |  |
| 3010973 | Magnesium [Moles/time] in 4 hour Urine | 0.936 |  |
| 3013561 | Magnesium [Moles/time] in 2 hour Urine | 0.935 |  |
| 3000566 | Arsenic [Mass/volume] in Urine | 0.934 |  |
| 3032333 | Phosphate [Mass or Moles] in 24 hour Urine | 0.931 |  |
| 3007771 | Amphetamines [Presence] in Specimen | 0.930 |  |
| 3013542 | traMADol [Presence] in Urine by Screen method | 0.930 | 1539 |
| 3008724 | Arsenic [Moles/volume] in Urine | 0.929 |  |
| 36032133 | Arsenic.inorganic+methylated [Mass/volume] in Urine | 0.929 |  |
| 648579 | Nickel [Measurement] in Urine | 0.927 |  |
| 3013666 | Nickel [Mass/volume] in Urine collected for unspecified duration | 0.927 |  |
| 3012636 | Phosphate [Mass/time] in 24 hour Urine | 0.926 |  |
| 647628 | Cannabinoids synthetic [Presence] in Urine | 0.926 |  |
| 3009272 | traMADol [Presence] in Urine by Confirmatory method | 0.925 |  |
| 3030540 | Arsenic organic [Moles/volume] in Urine | 0.925 |  |
| 3008769 | Porphobilinogen [Moles/volume] in Serum or Plasma | 0.925 |  |
| 3036768 | Bilirubin.total [Moles/volume] in Specimen | 0.925 |  |
| 3018601 | Magnesium [Mass/time] in 24 hour Urine | 0.924 |  |
| 3038918 | Arsenic organic [Mass/volume] in Urine | 0.922 |  |
| 3025776 | Phosphate [Mass/volume] in 24 hour Urine | 0.922 |  |
| 3016735 | Thyrotropin Ab [Units/volume] in Serum | 0.922 |  |
| 40762735 | fentaNYL [Presence] in Urine by Screen method | 0.922 |  |
| 3015116 | Methadone [Presence] in Specimen | 0.922 |  |
| 3023920 | Nickel [Presence] in Urine | 0.921 |  |
| 1260020 | traMADol [Presence] in Serum or Plasma | 0.920 |  |
| 3002752 | Chloride [Moles/volume] in 24 hour Urine | 0.920 |  |
| 3045942 | Benzodiazepines [Presence] in Specimen | 0.918 |  |
| 649466 | Bilirubin.total [Measurement] in Serum or Plasma | 0.918 |  |
| 645171 | Arsenic.inorganic [Measurement] in Urine | 0.917 |  |
| 21491252 | Selenium [Moles/volume] in Blood | 0.917 |  |
| 3024128 | Bilirubin.total [Mass/volume] in Serum or Plasma | 0.916 |  |
| 3009451 | Bacteria identified in 24 hour Urine by Culture | 0.916 |  |
| 3008477 | fentaNYL [Presence] in Serum or Plasma | 0.916 |  |
| 3042522 | Arsenic.inorganic [Mass/time] in 24 hour Urine | 0.915 |  |
| 3017750 | Porphobilinogen [Mass/volume] in Urine | 0.914 |  |
| 3028531 | Enolase.neuron specific [Mass/volume] in Serum or Plasma | 0.914 |  |
| 3033836 | Magnesium [Moles/volume] in Blood | 0.913 |  |
| 3019738 | Magnesium [Mass/volume] in Urine | 0.912 |  |
| 3042448 | fentaNYL [Presence] in Urine by Confirmatory method | 0.912 |  |
| 3023022 | Amphetaminil [Presence] in Urine | 0.911 |  |
| 44816594 | Magnesium [Moles/volume] in 12 hour Urine | 0.911 |  |
| 1001926 | Buprenorphine [Presence] in Urine by Screen method | 0.911 |  |
| 3011960 | Natriuretic peptide B [Mass/volume] in Serum or Plasma | 0.911 | 204 |
| 3009708 | Mercury [Presence] in Urine | 0.910 |  |
| 3030477 | Bilirubin.total [Presence] in Urine by Automated test strip | 0.909 |  |
| 3031569 | Natriuretic peptide B [Mass/volume] in Blood | 0.909 | 847 |
| 3006828 | Magnesium [Mass/volume] in 24 hour Urine | 0.908 |  |
| 3007110 | Nickel [Moles/time] in 24 hour Urine | 0.908 |  |
| 3024145 | Nickel [Mass/time] in 24 hour Urine | 0.908 |  |
| 647106 | Designer benzodiazepines [Presence] in Urine | 0.908 |  |
| 36031403 | Arsenic.inorganic+methylated [Mass/volume] in 24 hour Urine | 0.907 |  |
| 3009454 | Biotin [Presence] in Blood | 0.906 |  |
| 3004454 | Aluminum [Mass/volume] in Urine | 0.906 |  |
| 3030977 | Arsenic.inorganic [Moles/time] in 24 hour Urine | 0.906 |  |
| 3006932 | Cannabinoids [Presence] in Urine by Screen method | 0.905 | 224 |
| 40760458 | Chloride [Moles/volume] in 12 hour Urine | 0.904 |  |
| 3028054 | Vasoactive intestinal peptide [Mass/volume] in Serum or Plasma | 0.904 |  |
| 3014603 | Buprenorphine [Presence] in Urine by Confirmatory method | 0.903 |  |
| 3045267 | Arsenic organic [Mass/volume] in 24 hour Urine | 0.903 |  |
| 3026729 | Phosphate [Mass/volume] in Urine | 0.903 |  |
| 3006843 | Mercury [Mass/volume] in Urine | 0.902 |  |
| 3044963 | Bilirubin.total [Presence] in 24 hour Urine by Test strip | 0.902 |  |
| 3020207 | Porphobilinogen [Moles/time] in 24 hour Urine | 0.902 |  |
| 3013120 | Amphetamines [Presence] in Serum or Plasma | 0.901 |  |
| 1175191 | Bilirubin.total [Moles/volume] in Venous blood | 0.901 |  |
| 3007682 | Benzodiazepines [Presence] in Urine by Screen method | 0.898 | 1307 |
| 3045767 | Arsenic [Moles/volume] in 24 hour Urine | 0.897 |  |
| 3035732 | Benzodiazepines [Presence] in Urine by Confirmatory method | 0.897 | 1915 |
| 3019479 | Bacteria # 2 identified in Urine by Culture | 0.896 |  |
| 40762260 | Phosphate [Moles/time] in 24 hour Stool | 0.896 |  |
| 645697 | fentaNYL [Measurement] in Urine | 0.896 |  |
| 3044552 | Amphetamine+Methamphetamine [Presence] in Urine | 0.895 |  |
| 1175183 | Bilirubin.total [Moles/volume] in Arterial blood | 0.894 |  |
| 40760459 | Chloride [Moles/volume] in 2 hour Urine | 0.894 |  |
| 3034719 | Porphobilinogen [Presence] in Urine | 0.894 |  |
| 3037072 | Urobilinogen [Mass/volume] in Urine by Test strip | 0.894 |  |
| 3006363 | Amphetamines [Presence] in Urine by Confirmatory method | 0.894 |  |
| 3023596 | Amphetamines [Presence] in Urine by Screen method | 0.894 | 1508 |
| 3014310 | Cannabinoids [Presence] in Urine by Confirmatory method | 0.894 |  |
| 3014320 | Bacteria identified in Urethra by Culture | 0.893 |  |
| 3013830 | Methadone [Presence] in Urine by Confirmatory method | 0.892 |  |
| 3016450 | Mercury [Mass/volume] in Blood | 0.892 |  |
| 3041096 | Erythrocytes [Presence] in Urine by Automated | 0.892 |  |
| 3007755 | Magnesium [Moles/time] in 24 hour Stool | 0.891 |  |
| 3046030 | Erythrocytes [Presence] in Urine sediment by Light microscopy | 0.890 |  |
| 645740 | traMADol [Measurement] in Urine | 0.890 |  |
| 3031951 | Benzodiazepines [Presence] in Blood | 0.889 |  |
| 3035048 | Amphetamines [Presence] in Urine by SAMHSA screen method | 0.889 |  |
| 40766096 | Thyrotropin receptor Ab [Units/volume] in Cord blood | 0.888 |  |
| 3006567 | Chloride [Moles/time] in 24 hour Urine | 0.888 |  |
| 3035067 | Mercury [Moles/time] in 24 hour Urine | 0.888 |  |
| 3033364 | Cholesterol [Mass/volume] in Pleural fluid | 0.888 |  |
| 3028707 | Methadone [Presence] in Urine by Screen method | 0.887 | 629 |
| 3006459 | Amphetamines [Presence] in Stool | 0.887 |  |
| 647935 | Buprenorphine [Measurement] in Urine | 0.887 |  |
| 3010879 | Iodine [Mass/volume] in 24 hour Urine | 0.887 |  |
| 646979 | Cannabinoids [Measurement] in Urine | 0.886 |  |
| 647156 | Mercury [Measurement] in Urine | 0.886 |  |
| 3012728 | Benzodiazepines [Presence] in Serum or Plasma | 0.886 | 536 |
| 3003392 | Bacteria # 4 identified in Urine by Culture | 0.885 |  |
| 3032051 | Urobilinogen [Moles/volume] in Urine by Test strip | 0.884 | 117 |
| 645769 | Porphobilinogen/Creatinine [Measurement] in Urine | 0.884 |  |
| 3010391 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in Urine | 0.883 | 1140 |
| 648856 | Aluminum [Measurement] in Urine | 0.882 |  |
| 3012310 | Bilirubin.total [Moles/volume] in Body fluid | 0.882 | 1909 |
| 3028064 | Tetrahydrocannabinol [Presence] in Urine | 0.882 | 368 |
| 3006473 | Urobilinogen [Units/volume] in Urine by Test strip | 0.882 | 170 |
| 21493398 | Phosphate [Moles/volume] in Urine collected for unspecified duration | 0.882 |  |
| 3007785 | fentaNYL [Mass/volume] in Urine | 0.881 |  |
| 3025766 | Phosphate [Presence] in Urine | 0.880 |  |
| 3036649 | Aluminum [Moles/time] in 24 hour Urine | 0.879 |  |
| 3039416 | Vasoactive intestinal peptide [Presence] in Serum or Plasma | 0.879 |  |
| 3046484 | Bacteria # 8 identified in Urine by Culture | 0.879 |  |
| 3045335 | Bacteria # 7 identified in Urine by Culture | 0.879 |  |
| 3017044 | Thyrotropin receptor Ab [Units/volume] in Serum | 0.879 |  |
| 21492215 | traMADol [Presence] in Blood by Confirmatory method | 0.879 |  |
| 3005772 | Bilirubin.conjugated [Moles/volume] in Serum or Plasma | 0.879 |  |
| 3027114 | Cholesterol [Mass/volume] in Serum or Plasma | 0.878 |  |
| 3027700 | Thyrotropin [Units/volume] in Serum or Plasma --baseline | 0.878 |  |
| 40760482 | Magnesium [Mass/time] in 12 hour Urine | 0.878 |  |
| 3003113 | Bacteria # 5 identified in Urine by Culture | 0.878 |  |
| 3005024 | Bacteria # 3 identified in Urine by Culture | 0.877 |  |
| 3002013 | Bacteria # 6 identified in Urine by Culture | 0.876 |  |
| 3027641 | Methadone [Presence] in Stool | 0.876 |  |
| 3034832 | Methadone [Presence] in Serum or Plasma | 0.876 |  |
| 3016360 | Urobilinogen [Presence] in Urine | 0.875 |  |
| 647235 | Benzodiazepines [Measurement] in Urine | 0.875 |  |
| 3037955 | Cannabinoids [Presence] in Blood | 0.875 |  |
| 3020768 | Bilirubin.delta [Moles/volume] in Serum or Plasma | 0.873 |  |
| 3052927 | Bilirubin.total [Moles/volume] in Cord blood | 0.873 |  |
| 3015021 | Porphobilinogen [Mass/volume] in 24 hour Urine | 0.873 |  |
| 3045817 | Iodide [Mass/volume] in Specimen | 0.872 |  |
| 40761460 | Buprenorphine+Norbuprenorphine [Presence] in Urine by Screen method | 0.872 |  |
| 3017388 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in 24 hour Urine | 0.872 |  |
| 645629 | Porphobilinogen [Measurement] in Urine | 0.872 |  |
| 646976 | Magnesium [Measurement] in Urine | 0.871 |  |
| 3029052 | Nickel [Mass/volume] in Body fluid | 0.871 |  |
| 3019900 | Cholesterol [Moles/volume] in Serum or Plasma | 0.871 | 32 |
| 3025665 | Magnesium [Moles/volume] in Specimen | 0.870 |  |
| 40760485 | Enolase.neuron specific [Mass/volume] in Serum or Plasma by Immunoassay | 0.870 |  |
| 3006513 | Bilirubin.total [Mass/volume] in Urine by Test strip | 0.870 |  |
| 1092378 | Norbuprenorphine [Presence] in Urine | 0.869 |  |
| 3027772 | Cannabinoids [Presence] in Serum or Plasma | 0.869 |  |
| 42529510 | Buprenorphine [Presence] in Specimen by Screen method | 0.869 |  |
| 3004201 | Nickel [Mass/volume] in Blood | 0.869 |  |
| 3007953 | Mercury [Mass/volume] in 24 hour Urine | 0.869 |  |
| 21492216 | traMADol [Presence] in Blood by Screen method | 0.868 |  |
| 3028638 | Bilirubin.direct [Moles/volume] in Serum or Plasma | 0.868 | 82 |
| 3007437 | Mercury [Moles/volume] in Serum or Plasma | 0.868 |  |
| 3009672 | Porphobilinogen [Presence] in 24 hour Urine | 0.868 |  |
| 43533388 | Cannabinoids [Presence] in Urine by Screen method >50 ng/mL | 0.867 |  |
| 40762088 | Magnesium [Mass/time] in 18 hour Urine | 0.867 |  |
| 648045 | Methadone [Measurement] in Urine | 0.867 |  |
| 42868673 | Bilirubin.total [Moles/volume] in Urine | 0.867 | 171 |
| 3019652 | Selenium [Mass/volume] in Serum or Plasma | 0.866 |  |
| 40761480 | fentaNYL+Norfentanyl [Presence] in Urine by Screen method | 0.866 |  |
| 3037311 | Chloride [Moles/volume] in Urine collected for unspecified duration | 0.866 | 997 |
| 3008429 | Aluminum [Mass/volume] in 24 hour Urine | 0.865 |  |
| 3021197 | Magnesium Ionized [Moles/volume] in Serum or Plasma | 0.865 |  |
| 3017733 | Nickel [Moles/volume] in Blood | 0.865 |  |
| 42868626 | Cannabinoids [Presence] in Urine by Screen method >20 ng/mL | 0.865 |  |
| 3046816 | Methadone [Presence] in Meconium | 0.865 |  |
| 21494503 | Aluminum [Moles/volume] in Body fluid | 0.865 |  |
| 3044908 | Iodine [Moles/volume] in Urine | 0.864 |  |
| 43533958 | fentaNYL [Presence] in Blood by Screen method | 0.864 |  |
| 3023323 | Follitropin [Units/volume] in Serum or Plasma | 0.863 | 230 |
| 3001420 | Magnesium [Mass/volume] in Serum or Plasma | 0.863 |  |
| 1469855 | Buprenorphine [Presence] in Hair | 0.863 |  |
| 3023533 | Arsenic [Presence] in Urine | 0.863 |  |
| 1001641 | Benzodiazepines panel [Presence] - Urine by Screen method | 0.863 |  |
| 40760492 | Porphyrins/Creatinine [Molar ratio] in Urine | 0.862 |  |
| 3035521 | Bilirubin.direct/Bilirubin.total in Serum or Plasma | 0.862 |  |
| 3019025 | Thyrotropin.long acting [Units/volume] in Serum or Plasma | 0.862 |  |
| 3004338 | Enolase.neuron specific [Units/volume] in Serum or Plasma | 0.861 |  |
| 3009024 | Chloride [Moles/volume] in Specimen | 0.860 |  |
| 40758052 | Phosphate [Mass/time] in 12 hour Urine | 0.860 |  |
| 40760460 | Chloride [Moles/time] in 12 hour Urine | 0.860 |  |
| 3034662 | Methadone+Metabolite [Presence] in Urine by Screen method | 0.860 |  |
| 3044599 | Bilirubin.conjugated/Bilirubin.total in Serum or Plasma | 0.859 |  |
| 40768812 | fentaNYL+Norfentanyl [Presence] in Urine by Confirmatory method | 0.859 |  |
| 3041012 | Bilirubin.total [Moles/volume] in Urine by Test strip | 0.859 | 907 |
| 42528608 | Aluminum [Moles/volume] in Blood | 0.859 |  |
| 36660507 | Chloride [Moles/volume] in Urine from Fetus | 0.857 |  |
| 3030803 | Mercury [Moles/volume] in Red Blood Cells | 0.857 |  |
| 3045170 | Collagen crosslinked N-telopeptide/Creatinine [Ratio] in Urine | 0.857 |  |
| 3044171 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in Urine by Immunoassay | 0.857 |  |
| 3015271 | Benzodiazepines [Presence] in Stool | 0.857 |  |
| 3039169 | Iodine [Mass/volume] in Urine collected for unspecified duration | 0.856 |  |
| 3030188 | Thyrotropin [Units/volume] in Serum or Plasma --7th specimen | 0.856 |  |
| 3030198 | Thyrotropin [Units/volume] in Serum or Plasma --5th specimen | 0.855 |  |
| 646012 | Chloride [Measurement] in Urine | 0.855 |  |
| 3029985 | Thyrotropin [Units/volume] in Serum or Plasma --1st specimen | 0.855 |  |
| 3039627 | Selenium [Moles/volume] in Red Blood Cells | 0.855 |  |
| 40760465 | Phosphate [Mass/volume] in 12 hour Urine | 0.854 |  |
| 3047203 | Thyrotropin [Units/volume] in Serum or Plasma --1 hour post dose TRH | 0.854 |  |
| 40762086 | Phosphate [Mass/time] in 18 hour Urine | 0.854 |  |
| 1001608 | traMADol [Presence] in Meconium by Screen method | 0.853 |  |
| 40760481 | Magnesium [Mass/volume] in 12 hour Urine | 0.853 |  |
| 647560 | Vasoactive intestinal peptide [Measurement] in Serum or Plasma | 0.853 |  |
| 1175818 | Buprenorphine-3-glucuronide [Presence] in Urine by Screen method | 0.851 |  |
| 3032482 | Selenium [Moles/volume] in Urine | 0.851 |  |
| 3015711 | Magnesium [Moles/volume] in Body fluid | 0.851 |  |
| 3049111 | Enolase.neuron specific [Mass/volume] in Body fluid | 0.851 |  |
| 3013294 | Phosphate [Moles/volume] in Specimen | 0.850 |  |
| 648311 | Phosphate [Measurement] in Urine | 0.849 |  |
| 3009803 | traMADol [Mass/volume] in Urine | 0.849 |  |
| 40757502 | Cholesterol [Moles/volume] in Peritoneal fluid | 0.849 |  |
| 44786767 | traMADol [Presence] in Saliva (oral fluid) by Screen method | 0.849 |  |
| 3052295 | Natriuretic peptide B [Moles/volume] in Serum or Plasma | 0.848 |  |
| 3014814 | Methamphetamine [Presence] in Urine | 0.848 | 634 |
| 3042993 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in 24 hour Urine by Immunoassay | 0.848 |  |
| 3053321 | Collagen crosslinked C-telopeptide/Creatinine [Ratio] in Urine | 0.847 |  |
| 3001260 | Chloride [Moles/volume] in Stool | 0.847 |  |
| 21491001 | Cholesterol [Moles/volume] in Pericardial fluid | 0.847 |  |
| 3029187 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma | 0.847 | 516 |
| 40760466 | Phosphate [Mass/volume] in 2 hour Urine | 0.846 |  |
| 3044637 | Erythrocytes [Presence] in Body fluid | 0.846 |  |
| 3011258 | Bilirubin.total [Presence] in Urine | 0.846 | 621 |
| 3011787 | Mercury [Presence] in 24 hour Urine | 0.846 |  |
| 3015834 | Enolase.neuron specific [Enzymatic activity/volume] in Serum or Plasma | 0.846 |  |
| 40761551 | Bilirubin [Presence] in Urine by Confirmatory method | 0.846 |  |
| 646713 | Arsenic organic [Measurement] in Urine | 0.845 |  |
| 3024273 | Biotin [Mass/volume] in Serum or Plasma | 0.845 |  |
| 40762759 | Iodide [Mass/volume] in Serum or Plasma | 0.845 |  |
| 3028846 | Blood pressure device panel | 0.845 |  |
| 3019364 | Iodine Free [Mass/volume] in Urine | 0.845 |  |
| 1469998 | Natriuretic peptide B [Mass/volume] adjusted for eGFR in Serum or Plasma | 0.844 |  |
| 3044458 | Uroporphyrin/Creatinine [Molar ratio] in Urine | 0.844 |  |
| 3005758 | Thyrotropin [Units/volume] in Serum or Plasma --1 hour post dose TRH IV | 0.844 |  |
| 3046029 | Thyrotropin [Units/volume] in Serum or Plasma --pre dose TRH | 0.844 |  |
| 3034408 | Atrial natriuretic factor [Mass/volume] in Plasma | 0.844 |  |
| 3008034 | Magnesium [Moles/volume] in Stool | 0.843 |  |
| 3043714 | Erythrocytes [Presence] in Stool | 0.841 |  |
| 3018913 | Phosphate [Moles/volume] in Blood | 0.841 |  |
| 3018479 | Urobilinogen [Presence] in Stool | 0.841 |  |
| 3030379 | Thyrotropin [Units/volume] in Serum or Plasma --1.5 hours post dose TRH | 0.840 |  |
| 40762254 | Phosphate [Moles/volume] in Stool | 0.840 |  |
| 3044929 | Cholesterol.in chylomicrons [Mass/volume] in Serum or Plasma | 0.839 |  |
| 3024183 | Urobilinogen [Presence] in 24 hour Urine | 0.839 |  |
| 3049473 | Enolase.neuron specific [Mass/volume] in Serum or Plasma by Radioimmunoassay (RIA) | 0.838 |  |
| 3042779 | Enolase.neuron specific [Mass/volume] in Cerebral spinal fluid | 0.838 |  |
| 645251 | Iodine [Measurement] in Urine | 0.837 |  |
| 3034536 | Mercury [Moles/volume] in Saliva (oral fluid) | 0.835 |  |
| 3029870 | Urobilinogen [Mass/volume] in Urine by Automated test strip | 0.835 |  |
| 1988692 | Mercury [Moles/volume] in Cerebral spinal fluid | 0.835 |  |
| 3032467 | Bilirubin+Urobilinogen [Presence] in Urine | 0.834 |  |
| 42868740 | Cholesterol in pleural fluid/Cholesterol in serum | 0.834 |  |
| 40768058 | Magnesium [Moles/volume] corrected for albumin in Serum or Plasma | 0.833 |  |
| 3008254 | Cholesterol esters [Mass/volume] in Serum or Plasma | 0.833 |  |
| 3022621 | pH of Urine by Test strip | 0.833 | 59 |
| 3000578 | Aluminum [Moles/volume] in Serum or Plasma | 0.833 |  |
| 3011163 | Cholesterol.total/Cholesterol in HDL [Mass Ratio] in Serum or Plasma | 0.833 |  |
| 3015548 | Cholesterol [Moles/volume] in Specimen | 0.832 |  |
| 3028437 | Cholesterol in LDL [Mass/volume] in Serum or Plasma | 0.832 |  |
| 3015597 | Iodine [Mass/time] in 24 hour Urine | 0.832 |  |
| 3044590 | Delta aminolevulinate [Moles/volume] in Urine | 0.831 |  |
| 3011306 | Selenium [Mass/volume] in Blood | 0.830 |  |
| 3040519 | Bilirubin.total [Mass/volume] in Urine by Automated test strip | 0.830 |  |
| 1988603 | Mercury [Moles/volume] in Milk | 0.830 |  |
| 3003501 | Porphobilinogen [Mass/time] in 24 hour Urine | 0.830 |  |
| 1616626 | Enolase.neuron specific [Mass/volume] in Aspirate | 0.829 |  |
| 3028833 | Bilirubin.total [Mass/volume] in Blood | 0.829 |  |
| 42529215 | Follitropin [Units/volume] in Serum or Plasma by Immunoassay | 0.829 |  |
| 21491387 | Aluminum [Moles/volume] in Water | 0.829 |  |
| 1617351 | Hexacarboxylporphyrin/Creatinine [Molar ratio] in Urine | 0.827 |  |
| 3048400 | Enolase.neuron specific [Mass/volume] in Cerebral spinal fluid by Immunoassay | 0.827 |  |
| 3001308 | Cholesterol in LDL [Moles/volume] in Serum or Plasma | 0.827 | 92 |
| 3044491 | Cholesterol non HDL [Mass/volume] in Serum or Plasma | 0.827 |  |
| 3028195 | Cholesterol.non-esterified [Mass/volume] in Serum or Plasma | 0.826 |  |
| 3001280 | Aluminum [Mass/time] in 24 hour Urine | 0.825 |  |
| 3013104 | Cholesterol.total/Cholesterol in LDL [Mass Ratio] in Serum or Plasma | 0.825 |  |
| 3007352 | Cholesterol in VLDL [Mass/volume] in Serum or Plasma | 0.824 |  |
| 3041519 | Chloride [Mass/time] in 24 hour Urine | 0.824 |  |
| 3037598 | Cholesterol esters/Cholesterol.total in Serum or Plasma | 0.824 |  |
| 3034076 | Specific gravity of 24 hour Urine | 0.823 |  |
| 3001417 | Mercury [Mass/time] in 24 hour Urine | 0.823 |  |
| 3007070 | Cholesterol in HDL [Mass/volume] in Serum or Plasma | 0.822 |  |
| 3008455 | Magnesium [Moles/volume] in Red Blood Cells | 0.821 | 1697 |
| 3035821 | Porphyrins/Creatinine [Mass Ratio] in Urine | 0.820 |  |
| 3031203 | Blood pressure panel | 0.819 |  |
| 40757504 | Cholesterol.non-esterified [Moles/volume] in Serum or Plasma | 0.819 |  |
| 3002582 | Erythrocytes [#/volume] in Urine | 0.819 |  |
| 3019150 | Specific gravity of Urine by Refractometry | 0.819 |  |
| 648631 | Collagen crosslinked N-telopeptide/Creatinine [Measurement] in Urine | 0.819 |  |
| 40761535 | Cells panel - Urine sediment | 0.818 |  |
| 40758961 | Cholesterol esters [Moles/volume] in Serum or Plasma | 0.818 |  |
| 3044002 | Follitropin and Lutropin panel [Units/volume] - Serum or Plasma | 0.818 |  |
| 3022487 | Cholesterol in VLDL [Moles/volume] in Serum or Plasma | 0.818 | 219 |
| 3009930 | Uroporphyrin/Creatinine [Molar ratio] in 24 hour Urine | 0.817 |  |
| 3045969 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in Specimen by Immunoassay | 0.817 |  |
| 1469687 | pH of Urine by pH-meter | 0.817 |  |
| 40766095 | Thyrotropin receptor Ab [Units/volume] in Blood from Fetus | 0.816 |  |
| 40758334 | Vasoactive intestinal peptide [Mass/volume] in Cerebral spinal fluid | 0.815 |  |
| 3051266 | Erythrocytes.non-dysmorphic [Presence] in Urine sediment by Light microscopy | 0.815 |  |
| 40761533 | Casts panel - Urine sediment | 0.815 |  |
| 3006916 | Magnesium [Mass/volume] in Blood | 0.815 |  |
| 3016087 | Cholesterol.total/Cholesterol in HDL [Molar ratio] in Serum or Plasma | 0.815 | 91 |
| 3044028 | Biotin [Moles/volume] in Serum or Plasma | 0.813 |  |
| 646953 | Natriuretic peptide B [Measurement] in Serum or Plasma | 0.813 |  |
| 1092452 | Blood [Presence] in Urine | 0.812 |  |
| 3038345 | Erythrocytes.ghost cells [Presence] in Urine sediment by Light microscopy | 0.812 |  |
| 3021973 | Delta aminolevulinate [Moles/volume] in 24 hour Urine | 0.811 |  |
| 3041537 | Cholesterol [Moles/volume] in Synovial fluid | 0.811 |  |
| 42868678 | Cholesterol non HDL [Moles/volume] in Serum or Plasma | 0.811 | 289 |
| 40761534 | Crystals panel - Urine sediment | 0.810 |  |
| 42870364 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Blood by Immunoassay | 0.810 |  |
| 1761795 | Follitropin [Units/volume] in Body fluid | 0.810 |  |
| 3023602 | Cholesterol in HDL [Moles/volume] in Serum or Plasma | 0.809 | 38 |
| 3014038 | Collagen crosslinked N-telopeptide [Moles/volume] in Urine | 0.808 | 1419 |
| 3021832 | Aluminum [Mass/volume] in Urine collected for unspecified duration | 0.808 |  |
| 40771480 | Enolase.neuron specific [Mass/volume] in Pleural fluid | 0.806 |  |
| 3018329 | Vasoactive intestinal peptide [Mass/time] in 24 hour Urine | 0.806 |  |
| 3042010 | Triglyceride [Moles/volume] in Pleural fluid | 0.805 |  |
| 3037024 | Collagen crosslinked N-telopeptide [Moles/volume] in 24 hour Urine | 0.805 |  |
| 3004173 | Bilirubin.delta [Mass/volume] in Serum or Plasma | 0.804 |  |
| 3040042 | pH of 4 hour Urine | 0.804 |  |
| 1469767 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Body fluid by Immunoassay | 0.801 |  |
| 3004198 | Follitropin [Units/volume] in Serum or Plasma --baseline | 0.800 |  |
| 3006361 | Follitropin [Units/volume] in Serum or Plasma by 2nd IRP | 0.799 |  |
| 3029435 | Natriuretic peptide.B prohormone N-Terminal [Moles/volume] in Serum or Plasma | 0.799 |  |
| 3019975 | Mercury [Mass/volume] in Red Blood Cells | 0.799 |  |
| 3027597 | Bilirubin.direct [Mass/volume] in Serum or Plasma | 0.798 |  |
| 3031028 | Follitropin [Units/volume] in Serum or Plasma --1st specimen | 0.798 |  |
| 3011570 | Cholesterol [Moles/volume] in Body fluid | 0.797 |  |
| 43533580 | Thyroxine (T4) free [Mass/volume] in Cord blood | 0.797 |  |
| 3029305 | pH of Urine by Automated test strip | 0.796 |  |
| 3004208 | Mercury [Presence] in Urine by Visual.Reinsch | 0.795 |  |
| 40760217 | Follitropin [Units/volume] in Serum or Plasma --1.5 hours post dose gonadotropin releasing hormone | 0.793 |  |
| 40760218 | Follitropin [Units/volume] in Serum or Plasma --1 hour post dose gonadotropin releasing hormone | 0.793 |  |
| 3049183 | Collagen crosslinked C-telopeptide [Mass/volume] in Urine | 0.792 |  |
| 3052657 | Follitropin [Units/volume] in Serum or Plasma --pre 100 ug luteinizing releasing hormone IV | 0.792 |  |
| 42868677 | Cholesterol in VLDL 3 [Moles/volume] in Serum or Plasma | 0.792 | 765 |
| 42868726 | Follitropin IgG Ab [Units/volume] in Serum by Immunoassay | 0.792 |  |
| 3044942 | Collagen crosslinked N-telopeptide [Mass/volume] in Urine | 0.791 |  |
| 3002651 | Cholesterol [Mass/volume] in Peritoneal fluid | 0.791 |  |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.790 |  |
| 3013590 | Selenium [Mass/volume] in Body fluid | 0.790 |  |
| 646354 | Mercury [Measurement] in Red Blood Cells | 0.790 |  |
| 3046915 | Lipoprotein.beta/total Lipoprotein in Pleural fluid | 0.790 |  |
| 40758991 | Choriogonadotropin [Units/volume] in Cord blood | 0.789 |  |
| 3039866 | Selenium [Moles/mass] in Tissue | 0.788 |  |
| 3029656 | Follitropin [Units/volume] in Serum or Plasma --7th specimen | 0.788 |  |
| 3049505 | Follitropin [Units/volume] in Serum or Plasma --on cycle day 3 | 0.788 |  |
| 3029896 | Follitropin [Units/volume] in Serum or Plasma --5th specimen | 0.788 |  |
| 646465 | Collagen crosslinked C-telopeptide [Measurement] in Urine | 0.787 |  |
| 3043812 | Specific gravity of 24 hour Urine by Refractometry | 0.786 |  |
| 40761536 | Microorganisms panel - Urine sediment | 0.786 |  |
| 3015501 | pH of 24 hour Urine | 0.786 |  |
| 3033742 | Chloride panel - 24 hour Urine | 0.784 |  |
| 40762259 | Bilirubin.total [Moles/time] in 24 hour Stool | 0.783 |  |
| 3036187 | Delta aminolevulinate [Mass/volume] in Urine | 0.783 |  |
| 3036691 | Phosphate [Mass/volume] in Urine collected for unspecified duration | 0.781 |  |
| 3037142 | Thyrotropin [Units/volume] in DBS | 0.781 | 3000 |
| 3009032 | Chloride [Molar amount] in Urine collected for unspecified duration | 0.781 |  |
| 3004149 | Delta aminolevulinate [Moles/time] in 24 hour Urine | 0.780 |  |
| 40761501 | Specimen pH acceptable of Urine | 0.780 |  |
| 649476 | Nickel/Creatinine [Measurement] in Urine | 0.779 |  |
| 3045256 | Bilirubin.total [Presence] in Body fluid | 0.779 |  |
| 3050148 | Bilirubin.total [Mass/volume] in Cord blood | 0.778 |  |
| 3000330 | Specific gravity of Urine by Test strip | 0.777 | 71 |
| 40760031 | Cholesterol [Mass/volume] in Pericardial fluid | 0.777 |  |
| 40761130 | Selenium [Mass/volume] in Nonbiological fluid | 0.776 |  |
| 3040007 | pH of 2 hour Urine | 0.775 |  |
| 3041668 | Urinalysis microscopic panel [#/area] - Urine sediment by Automated count | 0.775 |  |
| 3010860 | Aluminum/Creatinine [Mass Ratio] in Urine | 0.772 |  |
| 3046619 | Specific gravity of Specimen | 0.771 |  |
| 3006772 | Delta aminolevulinate [Mass/volume] in 24 hour Urine | 0.771 |  |
| 3028101 | Alanine [Moles/volume] in Urine | 0.770 |  |
| 3031015 | pH of 24 hour Urine by Test strip | 0.769 |  |
| 3017228 | Iodine [Moles/volume] in 24 hour Urine | 0.767 |  |
| 40762888 | Bilirubin.total [Mass/volume] in Arterial blood | 0.767 |  |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 0.766 |  |
| 40762889 | Bilirubin.total [Mass/volume] in Venous blood | 0.766 |  |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.766 |  |
| 3041663 | Selenium [Moles/time] in 24 hour Urine | 0.766 |  |
| 3046027 | Biotinidase [Presence] in Serum or Plasma | 0.765 |  |
| 645821 | Cholesterol [Measurement] in Serum or Plasma | 0.765 |  |
| 3020379 | Vasopressin [Moles/volume] in Plasma | 0.764 |  |
| 648562 | Aluminum/Creatinine [Measurement] in Urine | 0.764 |  |
| 3036941 | Urinalysis complete panel - Urine | 0.763 |  |
| 3037850 | Specific gravity of Body fluid | 0.763 |  |
| 3028193 | Bilirubin.total [Mass/volume] in Body fluid | 0.762 |  |
| 649352 | Bilirubin.total [Measurement] in Body fluid | 0.761 |  |
| 3009538 | Alpha aminoadipate [Moles/volume] in Urine | 0.761 |  |
| 649393 | Delta aminolevulinate [Measurement] in Urine | 0.760 |  |
| 3035944 | Iodine Free [Mass/time] in 24 hour Urine | 0.759 |  |
| 3046897 | Bilirubin.total [Presence] in Specimen | 0.759 |  |
| 1616488 | Thyroxine (T4) free [Moles/volume] in Cord blood | 0.758 |  |
| 3047162 | Lipoprotein.pre-beta/total Lipoprotein in Pleural fluid | 0.757 |  |
| 3039919 | Specific gravity of Urine by Automated test strip | 0.757 |  |
| 3005271 | Mercury [Mass/mass] in Red Blood Cells | 0.755 |  |
| 3048789 | Delta aminolevulinate [Moles/volume] in Serum | 0.754 |  |
| 44787078 | Cholesterol.non-esterified/Cholesterol.total in Serum or Plasma by Gas chromatography | 0.753 |  |
| 3032696 | Somatostatin [Moles/volume] in Plasma | 0.752 |  |
| 3034207 | Triglyceride [Mass/volume] in Pleural fluid | 0.752 |  |
| 3029991 | Specific gravity of Urine by Refractometry automated | 0.751 |  |
| 3026316 | Pyrroles [Mass/volume] in Urine | 0.751 |  |
| 3024509 | Biotinidase [Presence] in Blood | 0.750 |  |
| 646312 | Bilirubin.total [Measurement] in Urine | 0.750 |  |
| 3034788 | Alanine [Moles/volume] in 24 hour Urine | 0.750 |  |
| 3044016 | Orthostatic blood pressure panel | 0.750 |  |
| 40758546 | Short blood pressure panel | 0.749 |  |
| 646497 | Biotinidase [Measurement] in Serum or Plasma | 0.749 |  |
| 3032448 | Specific gravity of Urine by Adjustment to pH 7.4 | 0.748 |  |
| 3022851 | Hydroquinone [Mass/volume] in Urine | 0.747 |  |
| 3010873 | Bilirubin.total [Mass/volume] in Urine | 0.746 |  |
| 3028253 | Gastric inhibitory polypeptide [Mass/volume] in Plasma | 0.743 |  |
| 44787076 | Cholestanol/Cholesterol in Serum or Plasma | 0.743 |  |
| 3024733 | Bilirubin.total [Presence] in Stool | 0.741 |  |
| 40758442 | Yeast [Presence] in Vaginal fluid by KOH preparation | 0.736 |  |
| 3007706 | Norepinephrine [Moles/volume] in Plasma | 0.734 |  |
| 21493544 | 4-Hydroxy 3-Nitrophenylacetate (HNPAA) [Mass/volume] in Urine | 0.730 |  |
| 3016312 | Uroporphyrin [Mass/volume] in Urine | 0.729 |  |
| 3025631 | Biotinidase [Enzymatic activity/volume] in Serum or Plasma | 0.729 |  |
| 40758436 | Fungus [Presence] in Vaginal fluid by KOH preparation | 0.728 |  |
| 3048422 | Vasoactive intestinal peptide Ag [Presence] in Tissue by Immune stain | 0.728 |  |
| 3002117 | Para nitrophenol [Mass/volume] in Urine | 0.727 |  |
| 3017223 | Mercury [Mass/volume] in Body fluid | 0.720 |  |
| 3017204 | Mercury [Mass/volume] in Serum or Plasma | 0.720 |  |
| 3034580 | 1-Naphthol [Mass/volume] in Urine | 0.717 |  |
| 3018672 | pH of Body fluid | 0.716 | 953 |
| 3007384 | Hexacarboxylporphyrin [Mass/volume] in Urine | 0.713 |  |
| 21492858 | Biotinidase [Enzymatic activity/mass] in Serum or Plasma | 0.711 |  |
| 40759645 | 5-Hydroxytryptophan [Mass/volume] in Urine | 0.711 |  |
| 3001496 | Yeast [Presence] in Vaginal fluid by Wet preparation | 0.711 |  |
| 3023055 | Clot Lysis [Time] in Platelet poor plasma by Coagulation assay | 0.710 |  |
| 3012954 | 3-Methoxy-4-Hydroxyphenylglycol [Mass/volume] in Urine | 0.710 |  |
| 3047074 | Bacteria [Presence] in Vaginal fluid by Wet preparation | 0.710 |  |
| 3033331 | Uroporphyrin [Mass/volume] in 24 hour Urine | 0.710 |  |
| 40757588 | Biotinidase [Enzymatic activity/volume] in Serum or Plasma from Normal control | 0.709 |  |
| 3041078 | Clot formation [Time] in Blood by Thromboelastography | 0.708 |  |
| 3011241 | Epithelial cells [Presence] in Vaginal fluid by Wet preparation | 0.707 |  |
| 3002766 | Leukocytes [Presence] in Vaginal fluid by Wet preparation | 0.707 |  |
| 42528941 | Spontaneous clot formation [Time] in Platelet poor plasma | 0.704 |  |
| 40758283 | Biotinidase panel - Serum or Plasma | 0.702 |  |
| 3043725 | Clot Lysis [Time] in Control Platelet poor plasma by Coagulation assay | 0.700 |  |
| 3042808 | Tetrahydrobiopterin/Biopterin in Urine | 0.697 |  |
| 3003007 | Microscopic observation [Identifier] in Vaginal fluid by KOH preparation | 0.697 |  |
| 3013528 | Clot Retraction [Time] in Blood by Coagulation assay | 0.694 |  |
| 40758441 | Yeast.pseudohyphae [Presence] in Vaginal fluid by KOH preparation | 0.693 |  |
| 3005711 | Thyrotropin.beta subunit [Mass/volume] in Serum or Plasma | 0.690 |  |
| 3041070 | Clot formation [Time] in Blood by Thromboelastography.rotational.extrinsic coagulation system activated.fibrinolysis suppressed | 0.689 |  |
| 3041952 | Clot initiation [Time] in Blood by Thromboelastography | 0.686 |  |
| 647250 | Thyrotropin [Measurement] in Serum or Plasma | 0.683 |  |
| 1616743 | Clot initiation [Time] in Blood | 0.682 |  |
| 36031308 | Delta Coagulation [Time] in Platelet poor plasma by aPTT W excess hexagonal phase phospholipid | 0.681 |  |
| 3011450 | Thyrotropin [Presence] in Blood | 0.681 |  |
| 36031928 | Blood pressure panel mean systolic and mean diastolic | 0.681 |  |
| 1616739 | Blood pressure panel 24 hour mean | 0.678 |  |
| 3035363 | Trichomonas vaginalis [Presence] in Vaginal fluid by Wet preparation | 0.676 |  |
| 3050675 | Wet mount panel - Vaginal fluid | 0.676 |  |
| 21492238 | Blood pressure by Noninvasive | 0.674 |  |
| 3040555 | Clot formation [Time] in Blood by Thromboelastography.rotational.extrinsic coagulation system activated | 0.674 |  |
| 36203185 | Blood pressure panel with all children optional | 0.672 |  |
| 3053264 | Biopterin [Moles/volume] in Cerebral spinal fluid | 0.671 |  |
| 36306151 | Blood pressure with exercise and post exercise panel | 0.663 |  |
| 3040023 | Carnosine [Presence] in Cerebral spinal fluid | 0.662 |  |
| 21492240 | Diastolic blood pressure by Noninvasive | 0.659 |  |
| 3002176 | 4-Hydroxyphenylpyruvate [Presence] in Urine | 0.657 |  |
| 3009606 | Beta hydroxybutyrate [Presence] in Urine | 0.656 |  |
| 3016423 | Beta aminoisobutyrate [Moles/volume] in Cerebral spinal fluid | 0.655 |  |
| 3015850 | Thiamine [Presence] in Blood | 0.654 |  |
| 21490949 | S-beta aminoisobutyrate [Moles/volume] in Cerebral spinal fluid | 0.654 |  |
| 3046050 | Beta-2-Microglobulin [Presence] in Cerebral spinal fluid | 0.652 |  |
| 3046860 | 5-Methyltetrahydrofolate [Presence] in Cerebral spinal fluid | 0.652 |  |
| 649008 | Beta-2-Microglobulin [Measurement] in Cerebral spinal fluid | 0.652 |  |
| 3012115 | Taurine [Presence] in Cerebral spinal fluid | 0.651 |  |
| 3044720 | 4-Hydroxybenzoate [Presence] in 24 hour Urine | 0.651 |  |
| 3007952 | Homocystine [Mass/volume] in Cerebral spinal fluid | 0.647 |  |
| 3012028 | 4-Hydroxyphenylacetate [Presence] in Urine | 0.645 |  |
| 3003347 | Nitrophenol [Presence] in Urine | 0.644 |  |
| 3007199 | Beta aminoisobutyrate [Presence] in Urine | 0.642 |  |
| 3023690 | Calcium phosphate/Total in Stone | 0.641 |  |
| 44816801 | Calcium oxalate dihydrate/Total in Stone | 0.640 |  |
| 3048268 | PT and aPTT and Fibrinogen panel - Platelet poor plasma by Coagulation assay | 0.639 |  |
| 3011937 | Urate/Total in Stone | 0.638 |  |
| 3048114 | Biotinidase [Presence] in DBS | 0.638 | 3000 |
| 647507 | Phenols [Measurement] in Urine | 0.637 |  |
| 3043754 | Beta hydroxybutyrate [Presence] in 24 hour Urine | 0.637 |  |
| 3006029 | 4-Hydroxyphenylpyruvate/Creatinine [Molar ratio] in Urine | 0.635 |  |
| 3009773 | Bismuth [Presence] in Urine | 0.634 |  |
| 645199 | Cryofibrinogen [Measurement] in Plasma | 0.633 |  |
| 3016407 | Fibrinogen [Mass/volume] in Platelet poor plasma by Coagulation assay | 0.632 | 267 |
| 3004468 | Somatostatin [Presence] in Plasma | 0.630 |  |
| 3012491 | Riboflavin [Presence] in Blood | 0.629 |  |
| 3043557 | Triamterene/Total in Stone | 0.628 |  |
| 3016113 | Fibrin.soluble [Units/volume] in Serum by Coagulation assay | 0.627 |  |
| 36031623 | Coagulation viscoelastic tracing in Blood Document | 0.627 |  |
| 43055495 | Intrinsic coagulation factor activity 4 panel - Platelet poor plasma by Coagulation assay | 0.627 |  |
| 3009515 | Fibrin+Fibrinogen fragments [Units/volume] in Platelet poor plasma by Latex agglutination | 0.625 |  |
| 3052964 | Fibrinogen [Mass/volume] in Platelet poor plasma by Coagulation.derived | 0.625 |  |
| 3024933 | Calcium [Presence] in Stone | 0.624 |  |
| 3037731 | Prothrombin Fragment 1.2 Ag [Moles/volume] in Serum or Plasma by Immunoassay | 0.623 |  |
| 3034896 | Calcium oxalate monohydrate/Total in Stone | 0.623 |  |
| 40757567 | Urate dihydrate/Total in Stone | 0.623 |  |
| 36032215 | Coagulation factor II inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.623 |  |
| 40761140 | Xanthine/Total in Stone | 0.621 |  |
| 3002762 | Somatostatin [Mass/volume] in Plasma | 0.618 |  |
| 40766276 | Calcium magnesium phosphate/Total in Stone | 0.616 |  |
| 3006087 | Urate [Presence] in Stone | 0.615 |  |
| 645117 | Mini nutritional assessment - short form 3 months Reported.MNA-SF | 0.576 |  |
| 649445 | Total score Reported.MNA-SF | 0.570 |  |
| 46236410 | Motor examination panel [UPDRS] | 0.530 |  |
| 21491091 | Applied cognitive score [AM-PAC] | 0.523 |  |
| 40765501 | PhenX - global mental status - adult protocol 130701 | 0.523 |  |
| 42528546 | Picture Sequence Memory Test - computed score [NIH Toolbox] | 0.519 |  |
| 42528548 | Picture Sequence Memory Test - raw score [NIH Toolbox] | 0.517 |  |
| 46236408 | Mentation, behavior and mood panel [UPDRS] | 0.513 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 587 | -bil | umol/l | 84% | name+unit+values | 433 | 0 | [8.08, 11.42, 17.8, 24.81, 35.56, 52.32, 88.15, 166.34, 422.22] | -Bilirubiini |  |  | Bilirubin.total [Moles/volume] in Serum or Plasma |
| 588 | -bil |  | 16% | name | 85 | 95.29 |  | -Bilirubiini |  |  | Bilirubin.total in Serum or Plasma |
| 589 | b-bio |  | 100% | name | 4183 | 100 |  |  | Blood |  | Biotin in Blood |
| 590 | b-hg | nmol/l | 56% | name+unit | 64 | 0 |  | B -Elohopea | Blood |  | Mercury [Moles/volume] in Blood |
| 591 | b-hg |  | 44% | name | 51 | 94.12 |  | B -Elohopea | Blood |  | Mercury in Blood |
| 592 | cb-bil | umol/l | 7% | name+unit+values | 331 | 0 | [11.1, 19.39, 22.31, 26.36, 32.8, 45.69, 98.54, 156.29, 216.28] | cB-Bilirubiini | Capillary blood |  | Bilirubin.total [Moles/volume] in Capillary blood |
| 593 | cb-bil |  | 93% | name | 4244 | 99.98 |  | cB-Bilirubiini | Capillary blood |  | Bilirubin.total in Capillary blood |
| 594 | du-mg | mmol | 79% | name+unit+values | 580 | 0.17 | [2.07, 2.62, 3.11, 3.51, 3.97, 4.42, 4.91, 5.69, 6.98] | dU-Magnesium | 24-hour urine |  | Magnesium [Moles/time] in 24 hour Urine |
| 595 | du-mg |  | 21% | name | 154 | 70.78 |  | dU-Magnesium | 24-hour urine |  | Magnesium in 24 hour Urine |
| 596 | du-pi | mmol | 83% | name+unit+values | 591 | 0.17 | [14.15, 19.7, 22.95, 26.88, 29.9, 33.43, 38, 43.23, 51.47] | dU-Fosfaatti, epäorgaaninen | 24-hour urine |  | Phosphate [Moles/time] in 24 hour Urine |
| 597 | du-pi |  | 17% | name | 118 | 75.42 |  | dU-Fosfaatti, epäorgaaninen | 24-hour urine |  | Phosphate in 24 hour Urine |
| 598 | fl-koh |  | 100% | name | 285 | 100 |  |  | Vaginal discharge |  | Potassium hydroxide [Presence] in Vaginal fluid by Wet mount |
| 599 | fp-bil | umol/l | 100% | name+unit+values | 111 | 0 | [4.98, 6.34, 7.02, 8.69, 9.41, 10.29, 12.14, 15.18, 27.61] |  | Fasting plasma |  | Bilirubin.total [Moles/volume] in Plasma |
| 600 | fp-kol | mmol | 0% | name+unit | 7 | 0 |  | fP-Kolesteroli | Fasting plasma |  | Cholesterol.total [Moles/volume] in Plasma |
| 601 | fp-kol | mmol/ | 0% | name+unit | 7 | 0 |  | fP-Kolesteroli | Fasting plasma |  | Cholesterol.total [Moles/volume] in Plasma |
| 602 | fp-kol | mmol/l | 99% | name+unit+values | 1407523 | 0 | [3.2, 3.63, 3.97, 4.28, 4.58, 4.87, 5.21, 5.6, 6.16] | fP-Kolesteroli | Fasting plasma |  | Cholesterol.total [Moles/volume] in Plasma |
| 603 | fp-kol |  | 1% | name+values | 17406 | 100 | [4.01, 4.31, 4.6, 4.91, 5.19, 5.43, 5.75, 6.21, 6.8] | fP-Kolesteroli | Fasting plasma |  | Cholesterol.total [Moles/volume] in Plasma |
| 604 | fp-vip | pmol/l | 87% | name+unit+values | 391 | 1.53 | [6.42, 8.54, 9.99, 11.21, 13, 14.7, 16.8, 19.84, 27.89] | fP-Vasoaktiivinen intestinaalinen peptidi | Fasting plasma |  | Vasoactive intestinal peptide [Moles/volume] in Plasma |
| 605 | fp-vip |  | 13% | name | 61 | 81.97 |  | fP-Vasoaktiivinen intestinaalinen peptidi | Fasting plasma |  | Vasoactive intestinal peptide in Plasma |
| 606 | fs-kol | mmol/ | 0% | name+unit | 7 | 0 |  | fS-Kolesteroli | Fasting serum |  | Cholesterol.total [Moles/volume] in Serum |
| 607 | fs-kol | mmol/l | 100% | name+unit+values | 259011 | 0 | [3.71, 4.15, 4.46, 4.76, 5.03, 5.31, 5.59, 5.95, 6.44] | fS-Kolesteroli | Fasting serum |  | Cholesterol.total [Moles/volume] in Serum |
| 608 | fs-kol |  | 0% | name+values | 481 | 100 | [3.95, 4.3, 4.66, 4.92, 5.17, 5.39, 5.64, 6.03, 6.57] | fS-Kolesteroli | Fasting serum |  | Cholesterol.total [Moles/volume] in Serum |
| 609 | li-bio |  | 100% | name | 161 | 100 |  |  | Cerebrospinal fluid |  | Biotin in Cerebral spinal fluid |
| 610 | mmse |  | 100% | name | 524 | 94.66 |  |  |  |  | Mini-mental state examination |
| 611 | p-bil | umol/l | 97% | name+unit+values | 1420468 | 0.09 | [5, 6, 7, 8.01, 9.15, 10.92, 12.96, 16.55, 24.99] | P -Bilirubiini | Plasma |  | Bilirubin.total [Moles/volume] in Plasma |
| 612 | p-bil |  | 3% | name+values | 51285 | 100 | [4.75, 5.95, 6.93, 7.97, 9.15, 10.81, 13.1, 17.26, 26.41] | P -Bilirubiini | Plasma |  | Bilirubin.total [Moles/volume] in Plasma |
| 613 | p-bnp | ng/l | 94% | name+unit+values | 92283 | 0 | [19.9, 36.26, 58.02, 88.41, 132.21, 195.75, 292.04, 465.57, 902.19] | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  | Natriuretic peptide.B [Mass/volume] in Plasma |
| 614 | p-bnp | ng/ml | 0% | name+unit | 14 | 0 |  | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  | Natriuretic peptide.B [Mass/volume] in Plasma |
| 615 | p-bnp |  | 6% | name+values | 5638 | 100 | [41.88, 71.98, 108.12, 145.12, 193.35, 257.89, 351.05, 510.91, 912.06] | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  | Natriuretic peptide.B [Mass/volume] in Plasma |
| 616 | p-fsh | u/l | 99% | name+unit+values | 10309 | 0 | [3.43, 4.83, 5.94, 7.2, 9.39, 15.3, 30.23, 51.8, 73.17] | P -Follikkelia stimuloiva hormoni | Plasma |  | Follicle stimulating hormone [Units/volume] in Plasma |
| 617 | p-fsh |  | 1% | name+values | 155 | 100 | [3.32, 4.57, 5.74, 6.86, 8.5, 12.89, 23.84, 44.5, 70.18] | P -Follikkelia stimuloiva hormoni | Plasma |  | Follicle stimulating hormone [Units/volume] in Plasma |
| 618 | p-fsl | s | 95% | name+unit+values | 1808 | 0 | [23.6, 25, 25.97, 26.26, 27.2, 28.08, 29.24, 31.3, 34.37] |  | Plasma |  | Coagulation FSL [Time] in Plasma |
| 619 | p-fsl |  | 5% | name | 86 | 69.77 |  |  | Plasma |  | Coagulation FSL in Plasma |
| 620 | p-kol | mmol/l | 99% | name+unit+values | 298985 | 0 | [3.03, 3.42, 3.74, 4.03, 4.33, 4.64, 4.97, 5.37, 5.92] | P -Kolesteroli | Plasma |  | Cholesterol.total [Moles/volume] in Plasma |
| 621 | p-kol |  | 1% | name+values | 2034 | 100 | [3, 3.37, 3.67, 3.97, 4.25, 4.57, 4.92, 5.32, 5.88] | P -Kolesteroli | Plasma |  | Cholesterol.total [Moles/volume] in Plasma |
| 622 | p-mg | mmol/l | 99% | name+unit+values | 259826 | 0.04 | [0.64, 0.7, 0.74, 0.77, 0.8, 0.83, 0.86, 0.89, 0.95] | P -Magnesium | Plasma |  | Magnesium [Moles/volume] in Plasma |
| 623 | p-mg |  | 1% | name+values | 2225 | 100 | [0.64, 0.7, 0.74, 0.78, 0.81, 0.84, 0.86, 0.9, 0.95] | P -Magnesium | Plasma |  | Magnesium [Moles/volume] in Plasma |
| 624 | p-se | umol/l | 95% | name+unit+values | 1087 | 0.09 | [0.86, 1.03, 1.1, 1.19, 1.27, 1.34, 1.41, 1.5, 1.62] | P -Seleeni | Plasma |  | Selenium [Moles/volume] in Plasma |
| 625 | p-se |  | 5% | name+values | 55 | 43.64 | [1.17, 1.27, 1.34, 1.4, 1.46, 1.54, 1.63, 1.73, 1.94] | P -Seleeni | Plasma |  | Selenium [Moles/volume] in Plasma |
| 626 | p-tsh | miu/l | 2% | name+unit+values | 32584 | 0 | [0.71, 1.13, 1.46, 1.75, 2.07, 2.43, 2.87, 3.48, 4.57] | P -Tyreotropiini | Plasma |  | Thyrotropin [Units/volume] in Plasma |
| 627 | p-tsh | mlu/l | 0% | name+unit+values | 4705 | 0 | [0.58, 1.02, 1.38, 1.7, 2.07, 2.5, 3.01, 3.68, 4.95] | P -Tyreotropiini | Plasma |  | Thyrotropin [Units/volume] in Plasma |
| 628 | p-tsh | mu/l | 95% | name+unit+values | 1660849 | 0.06 | [0.53, 0.92, 1.22, 1.5, 1.78, 2.11, 2.53, 3.11, 4.2] | P -Tyreotropiini | Plasma |  | Thyrotropin [Units/volume] in Plasma |
| 629 | p-tsh |  | 3% | name+values | 53377 | 100 | [0.3, 0.81, 1.02, 1.41, 1.64, 1.91, 2.3, 2.66, 3.57] | P -Tyreotropiini | Plasma |  | Thyrotropin [Units/volume] in Plasma |
| 630 | pf-kol | mmol/l | 63% | name+unit+values | 614 | 0 | [0.64, 0.93, 1.1, 1.3, 1.51, 1.75, 2.03, 2.36, 2.85] | Pf-Kolesteroli | Pleural fluid |  | Cholesterol.total [Moles/volume] in Pleural fluid |
| 631 | pf-kol |  | 37% | name | 361 | 98.06 |  | Pf-Kolesteroli | Pleural fluid |  | Cholesterol.total in Pleural fluid |
| 632 | s-bil | umol/l | 99% | name+unit+values | 15554 | 0 | [5.56, 6.89, 7.91, 8.95, 10.06, 11.55, 13.42, 16.35, 22.65] | S -Bilirubiini | Serum |  | Bilirubin.total [Moles/volume] in Serum |
| 633 | s-bil |  | 1% | name+values | 183 | 82.51 | [5.99, 7.33, 8.34, 9.33, 10.81, 12.14, 14.24, 16.54, 22.13] | S -Bilirubiini | Serum |  | Bilirubin.total [Moles/volume] in Serum |
| 634 | s-bio |  | 100% | name | 11283 | 100 |  |  | Serum |  | Biotin in Serum |
| 635 | s-biol |  | 100% | name | 508 | 100 |  |  | Serum |  | Biotin in Serum |
| 636 | s-fsh | iu/l | 58% | name+unit+values | 21045 | 0 | [3.26, 4.67, 5.97, 7.58, 10.27, 17.4, 33.37, 51.85, 72.5] | S -Follikkelia stimuloiva hormoni | Serum |  | Follicle stimulating hormone [Units/volume] in Serum |
| 637 | s-fsh | u/l | 39% | name+unit+values | 14312 | 0.62 | [3.48, 4.97, 6.16, 7.42, 9.34, 13.61, 26.1, 47.59, 73.43] | S -Follikkelia stimuloiva hormoni | Serum |  | Follicle stimulating hormone [Units/volume] in Serum |
| 638 | s-fsh |  | 3% | name+values | 1106 | 100 | [3.11, 4.58, 5.88, 7.13, 8.92, 13.11, 23.72, 44.2, 70.34] | S -Follikkelia stimuloiva hormoni | Serum |  | Follicle stimulating hormone [Units/volume] in Serum |
| 639 | s-kol | mg/ml | 0% | name+unit | 9 | 0 |  | S -Kolesteroli | Serum |  | Cholesterol.total [Mass/volume] in Serum |
| 640 | s-kol | mmol/l | 99% | name+unit+values | 35285 | 0 | [3.59, 4.01, 4.33, 4.59, 4.85, 5.11, 5.39, 5.71, 6.19] | S -Kolesteroli | Serum |  | Cholesterol.total [Moles/volume] in Serum |
| 641 | s-kol |  | 1% | name | 396 | 89.9 |  | S -Kolesteroli | Serum |  | Cholesterol.total in Serum |
| 642 | s-mg | mmol/l | 100% | name+unit+values | 5982 | 0 | [0.77, 0.81, 0.83, 0.85, 0.87, 0.88, 0.9, 0.92, 0.95] | S -Magnesium | Serum |  | Magnesium [Moles/volume] in Serum |
| 643 | s-mg |  | 0% | name+values | 23 | 69.57 | [0.75, 0.78, 0.8, 0.82, 0.83, 0.85, 0.87, 0.89, 0.91] | S -Magnesium | Serum |  | Magnesium [Moles/volume] in Serum |
| 644 | s-nse | ug/l | 98% | name+unit+values | 10085 | 0.04 | [9.38, 10.96, 12, 13.1, 14.43, 16.18, 18.88, 24.33, 45.7] | S -Neuronispesifinen enolaasi | Serum |  | Neuron specific enolase [Mass/volume] in Serum |
| 645 | s-nse |  | 2% | name+values | 210 | 45.24 | [8.56, 10, 10.8, 12.01, 14.24, 17, 20.25, 24.5, 29.28] | S -Neuronispesifinen enolaasi | Serum |  | Neuron specific enolase [Mass/volume] in Serum |
| 646 | s-tsh | miu/l | 31% | name+unit+values | 117078 | 0 | [0.56, 0.91, 1.16, 1.39, 1.62, 1.89, 2.23, 2.72, 3.61] | S -Tyreotropiini | Serum |  | Thyrotropin [Units/volume] in Serum |
| 647 | s-tsh | mlu/l | 0% | name+unit+values | 113 | 0 | [0.33, 0.69, 1.02, 1.22, 1.42, 1.62, 2, 2.33, 2.93] | S -Tyreotropiini | Serum |  | Thyrotropin [Units/volume] in Serum |
| 648 | s-tsh | mu/l | 68% | name+unit+values | 253056 | 0 | [0.62, 0.91, 1.15, 1.36, 1.59, 1.85, 2.18, 2.64, 3.49] | S -Tyreotropiini | Serum |  | Thyrotropin [Units/volume] in Serum |
| 649 | s-tsh | u/l | 0% | name+unit+values | 142 | 0 | [0.52, 0.94, 1.22, 1.48, 1.73, 1.98, 2.18, 2.57, 4.01] | S -Tyreotropiini | Serum |  | Thyrotropin [Units/volume] in Serum |
| 650 | s-tsh |  | 1% | name+values | 4491 | 100 | [0.62, 0.91, 1.18, 1.45, 1.66, 1.95, 2.23, 2.72, 3.49] | S -Tyreotropiini | Serum |  | Thyrotropin [Units/volume] in Serum |
| 651 | se-bil | umol/l | 84% | name+unit+values | 526 | 1.33 | [9.24, 12.96, 16.08, 20.31, 26.93, 38.21, 60.68, 119.92, 333.14] |  | Secretion |  | Bilirubin.total [Moles/volume] in Secretion |
| 652 | se-bil |  | 16% | name | 102 | 99.02 |  |  | Secretion |  | Bilirubin.total in Secretion |
| 653 | u-al | umol/l | 48% | name+unit+values | 81 | 0 | [0.1, 0.1, 0.2, 0.2, 0.22, 0.3, 0.4, 0.7, 1.7] | U -Alumiini | Urine |  | Aluminum [Moles/volume] in Urine |
| 654 | u-al |  | 52% | name | 87 | 97.7 |  | U -Alumiini | Urine |  | Aluminum in Urine |
| 655 | u-amp |  | 100% | name | 158 | 100 |  |  | Urine |  | Amphetamines [Presence] in Urine |
| 656 | u-as-i | nmol/l | 11% | name+unit | 16 | 0 |  | U -Arseeni, epäorgaaninen | Urine |  | Arsenic.inorganic [Moles/volume] in Urine |
| 657 | u-as-i | ug/l | 14% | name+unit | 20 | 0 |  | U -Arseeni, epäorgaaninen | Urine |  | Arsenic.inorganic [Mass/volume] in Urine |
| 658 | u-as-i |  | 75% | name | 107 | 100 |  | U -Arseeni, epäorgaaninen | Urine |  | Arsenic.inorganic in Urine |
| 659 | u-bil |  | 100% | name | 441 | 100 |  |  | Urine |  | Bilirubin [Presence] in Urine by Test strip |
| 660 | u-bio |  | 100% | name | 2387 | 100 |  |  | Urine |  | Biotin in Urine |
| 661 | u-bup |  | 100% | name | 145 | 100 |  |  | Urine |  | Buprenorphine [Presence] in Urine |
| 662 | u-bzd |  | 100% | name | 143 | 100 |  |  | Urine |  | Benzodiazepines [Presence] in Urine |
| 663 | u-cl | mmol/l | 86% | name+unit+values | 200 | 1.5 | [30.37, 49.43, 62.98, 72.55, 86.28, 96.56, 114.04, 135.66, 174.02] | U -Kloridi | Urine | Clearance | Chloride [Moles/volume] in Urine |
| 664 | u-cl |  | 14% | name | 33 | 72.73 |  | U -Kloridi | Urine | Clearance | Chloride in Urine |
| 665 | u-dala | umol/l | 100% | name+unit+values | 111 | 0.9 | [5, 8, 10.96, 13.72, 17, 20.55, 23.93, 29.9, 40.27] | U -Delta-aminolevulinaatti | Urine |  | Aminolevulinic acid [Moles/volume] in Urine |
| 666 | u-ds4a |  | 100% | name | 461 | 100 |  |  | Urine |  |  |
| 667 | u-ds5 |  | 100% | name | 133 | 100 |  |  | Urine |  |  |
| 668 | u-ds5b |  | 100% | name | 1156 | 100 |  |  | Urine |  |  |
| 669 | u-ds6 |  | 100% | name | 386 | 100 |  |  | Urine |  |  |
| 670 | u-ds6a |  | 100% | name | 1325 | 100 |  |  | Urine |  |  |
| 671 | u-ery |  | 100% | name | 3788 | 99.71 |  |  | Urine |  | Erythrocytes [Presence] in Urine |
| 672 | u-fyl |  | 100% | name | 145 | 100 |  |  | Urine |  | Fentanyl [Presence] in Urine |
| 673 | u-hg | nmol/l | 81% | name+unit | 108 | 0 |  | U -Elohopea | Urine |  | Mercury [Moles/volume] in Urine |
| 674 | u-hg |  | 19% | name | 25 | 100 |  | U -Elohopea | Urine |  | Mercury in Urine |
| 675 | u-i | ug/l | 94% | name+unit+values | 309 | 0 | [44.03, 61.73, 78.06, 96.82, 115.33, 136.79, 163.87, 204.07, 318.14] | U -Jodidi | Urine |  | Iodide [Mass/volume] in Urine |
| 676 | u-i |  | 6% | name | 18 | 88.89 |  | U -Jodidi | Urine |  | Iodide in Urine |
| 677 | u-inf |  | 100% | name | 51657 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 678 | u-intp | nmol/mmol | 66% | name+unit+values | 2098 | 0 | [16.36, 22.55, 28.43, 35.25, 42.57, 53.83, 68.67, 92.78, 154.47] | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I telopeptide.N-terminal/Creatinine [Molar ratio] in Urine |
| 679 | u-intp | nmol/mmolkr | 0% | name+unit | 14 | 0 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I telopeptide.N-terminal/Creatinine [Molar ratio] in Urine |
| 680 | u-intp | ratio | 1% | name+unit | 47 | 0 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I telopeptide.N-terminal/Creatinine [Molar ratio] in Urine |
| 681 | u-intp |  | 32% | name | 1030 | 94.47 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I telopeptide.N-terminal/Creatinine in Urine |
| 682 | u-kivi | form | 3% | name+unit | 60 | 100 |  | U -Kivianalyysi | Urine |  | Calculus composition identified in Urinary stone |
| 683 | u-kivi |  | 97% | name | 1820 | 100 |  | U -Kivianalyysi | Urine |  | Calculus composition identified in Urinary stone |
| 684 | u-mg | mmol/l | 83% | name+unit+values | 123 | 0.81 | [0.84, 1.34, 1.62, 1.98, 2.27, 2.78, 3.64, 4.45, 6.45] | U -Magnesium | Urine |  | Magnesium [Moles/volume] in Urine |
| 685 | u-mg |  | 17% | name | 26 | 38.46 |  | U -Magnesium | Urine |  | Magnesium in Urine |
| 686 | u-mtd |  | 100% | name | 144 | 100 |  |  | Urine |  | Methadone [Presence] in Urine |
| 687 | u-ni | form | 5% | name+unit | 57 | 0 |  | U -Nikkeli | Urine |  | Nickel in Urine |
| 688 | u-ni | ug/l | 5% | name+unit | 65 | 0 |  | U -Nikkeli | Urine |  | Nickel [Mass/volume] in Urine |
| 689 | u-ni | umol/l | 63% | name+unit+values | 754 | 0 | [0.01, 0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.06] | U -Nikkeli | Urine |  | Nickel [Moles/volume] in Urine |
| 690 | u-ni |  | 27% | name | 323 | 90.71 |  | U -Nikkeli | Urine |  | Nickel in Urine |
| 691 | u-pbg | umol/l | 86% | name+unit+values | 248 | 1.61 | [1, 2, 2, 3, 3.9, 4.42, 5, 6.04, 8.79] | U -Porfobilinogeeni | Urine |  | Porphobilinogen [Moles/volume] in Urine |
| 692 | u-pbg | umol/mmol | 2% | name+unit | 6 | 0 |  | U -Porfobilinogeeni | Urine |  | Porphobilinogen/Creatinine [Molar ratio] in Urine |
| 693 | u-pbg |  | 11% | name | 33 | 51.52 |  | U -Porfobilinogeeni | Urine |  | Porphobilinogen in Urine |
| 694 | u-pgb |  | 100% | name | 144 | 100 |  |  | Urine |  | Porphobilinogen in Urine |
| 695 | u-ph. |  | 100% | name+values | 24516 | 1.33 | [5, 5.5, 5.5, 5.87, 6, 6.26, 6.5, 6.96, 7.02] |  | Urine |  | pH of Urine |
| 696 | u-phv |  | 100% | name+values | 737 | 0.27 | [5, 5.5, 5.5, 5.66, 6, 6, 6.5, 7, 7] |  | Urine |  | pH of Urine |
| 697 | u-pi | mmol/l | 90% | name+unit+values | 772 | 0.13 | [4.87, 7.61, 10.55, 13.2, 16.31, 20.1, 24.74, 31.17, 40.13] | U -Fosfaatti, epäorgaaninen | Urine |  | Phosphate [Moles/volume] in Urine |
| 698 | u-pi |  | 10% | name | 84 | 54.76 |  | U -Fosfaatti, epäorgaaninen | Urine |  | Phosphate in Urine |
| 699 | u-pyr | form | 7% | name+unit | 7 | 0 |  | U -Pyrenoli (1) | Urine |  | 1-Hydroxypyrene in Urine |
| 700 | u-pyr | ug/l | 6% | name+unit | 6 | 0 |  | U -Pyrenoli (1) | Urine |  | 1-Hydroxypyrene [Mass/volume] in Urine |
| 701 | u-pyr |  | 87% | name | 88 | 100 |  | U -Pyrenoli (1) | Urine |  | 1-Hydroxypyrene in Urine |
| 702 | u-sed |  | 100% | name | 2162 | 99.95 |  |  | Urine |  | Urinalysis sediment microscopy panel - Urine |
| 703 | u-sg | kg/l | 98% | name+unit+values | 3827 | 0 | [1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity of Urine |
| 704 | u-sg |  | 2% | name+values | 75 | 100 | [1, 1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.03] |  | Urine |  | Specific gravity of Urine |
| 705 | u-thc |  | 100% | name | 157 | 100 |  |  | Urine |  | Cannabinoids [Presence] in Urine |
| 706 | u-tml |  | 100% | name | 145 | 100 |  |  | Urine |  | Tramadol [Presence] in Urine |
| 707 | u-ubg |  | 100% | name | 441 | 100 |  |  | Urine |  | Urobilinogen [Presence] in Urine by Test strip |
| 708 | us-tsh | mu/l | 85% | name+unit+values | 415 | 0.72 | [3.59, 4.74, 5.45, 6.2, 7.04, 7.92, 9.44, 11.82, 16.59] | uS-Tyreotropiini | Umbilical (blood) serum |  | Thyrotropin [Units/volume] in Umbilical cord blood serum |
| 709 | us-tsh |  | 15% | name | 75 | 33.33 |  | uS-Tyreotropiini | Umbilical (blood) serum |  | Thyrotropin in Umbilical cord blood serum |
| 710 | vp-dop |  | 100% | name | 154 | 100 |  | Valtimopaine, dopplermittaus |  |  | Blood pressure Doppler panel |

