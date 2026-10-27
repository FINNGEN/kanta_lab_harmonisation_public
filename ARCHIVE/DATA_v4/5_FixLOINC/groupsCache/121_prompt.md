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
Here is group 121.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 1469831 | Hyaline casts [#/volume] in Urine sediment by Automated count | 1.000 |  |
| 3000068 | oxyCODONE [Presence] in Urine | 1.000 | 814 |
| 3001526 | Acetaminophen [Presence] in Urine | 1.000 | 742 |
| 3001582 | Protein/Creatinine [Mass Ratio] in Urine | 1.000 | 509 |
| 3002020 | Barbiturates [Presence] in Urine | 1.000 | 207 |
| 3007463 | Buprenorphine [Presence] in Urine | 1.000 | 812 |
| 3012516 | Albumin [Mass/volume] in Urine | 1.000 |  |
| 3015736 | pH of Urine | 1.000 | 612 |
| 3016360 | Urobilinogen [Presence] in Urine | 1.000 |  |
| 3016879 | Cocaine [Presence] in Urine | 1.000 | 301 |
| 3017013 | Tricyclic antidepressants [Presence] in Urine | 1.000 | 568 |
| 3017754 | Calcium/Creatinine [Molar ratio] in Urine | 1.000 |  |
| 3025987 | Albumin [Presence] in Urine | 1.000 |  |
| 3026008 | Bacteria identified in Urine by Culture | 1.000 | 93 |
| 3027008 | Opiates [Presence] in Urine | 1.000 | 195 |
| 3027162 | Color of Urine | 1.000 | 58 |
| 3029937 | Albumin [Presence] in Urine by Test strip | 1.000 |  |
| 3033543 | Specific gravity of Urine | 1.000 | 122 |
| 3034485 | Albumin/Creatinine [Mass Ratio] in Urine | 1.000 |  |
| 3034719 | Porphobilinogen [Presence] in Urine | 1.000 |  |
| 3041184 | Isoniazid [Presence] in Urine | 1.000 |  |
| 3045284 | traMADol [Presence] in Urine | 1.000 |  |
| 3030981 | Hyaline casts [#/volume] in Urine by Automated count | 0.988 |  |
| 21491346 | Pathologic casts [#/volume] in Urine by Automated count | 0.984 |  |
| 1092199 | Hyaline casts [#/volume] in Urine | 0.981 |  |
| 3030467 | Casts [#/volume] in Urine by Automated count | 0.965 |  |
| 3014603 | Buprenorphine [Presence] in Urine by Confirmatory method | 0.961 |  |
| 3000819 | Albumin/Creatinine [Mass Ratio] in 24 hour Urine | 0.958 |  |
| 36306016 | Hyaline casts [#/area] in Urine sediment | 0.958 |  |
| 3020682 | Albumin/Creatinine [Ratio] in Urine | 0.957 |  |
| 3045874 | Casts [#/area] in Urine sediment by Automated count | 0.956 |  |
| 3027035 | Albumin [Mass/time] in 24 hour Urine | 0.953 |  |
| 3018479 | Urobilinogen [Presence] in Stool | 0.952 |  |
| 3030451 | Calcium/Creatinine [Molar ratio] in 24 hour Urine | 0.952 |  |
| 3002812 | Albumin/Creatinine [Molar ratio] in Urine | 0.948 |  |
| 3009220 | Epithelial cells.squamous [#/volume] in Urine sediment | 0.947 |  |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 0.945 | 1 |
| 3002481 | Calcium/Creatinine [Mass Ratio] in Urine | 0.943 |  |
| 3045462 | Protein/Creatinine [Ratio] in Urine | 0.943 |  |
| 3043722 | Hyaline casts [#/area] in Urine sediment by Automated count | 0.942 |  |
| 3037791 | Protein/Creatinine [Mass Ratio] in 24 hour Urine | 0.940 |  |
| 21491345 | Pathologic casts [#/area] in Urine by Automated count | 0.938 |  |
| 3029879 | Epithelial cells.squamous [#/volume] in Urine by Automated count | 0.938 |  |
| 3003327 | Ova and parasites identified in Stool by Light microscopy | 0.937 | 659 |
| 3052141 | Buprenorphine+Norbuprenorphine [Presence] in Urine | 0.937 |  |
| 3025812 | Tricyclic antidepressants [Presence] in Urine by Immunoassay | 0.933 |  |
| 1091356 | Transitional cells [#/area] in Urine sediment | 0.931 |  |
| 3050449 | Albumin [Mass/time] in Urine collected for unspecified duration | 0.931 |  |
| 3024183 | Urobilinogen [Presence] in 24 hour Urine | 0.930 |  |
| 3008236 | Barbiturates [Presence] in Specimen | 0.930 |  |
| 3013542 | traMADol [Presence] in Urine by Screen method | 0.930 | 1539 |
| 3009672 | Porphobilinogen [Presence] in 24 hour Urine | 0.929 |  |
| 3007534 | oxyCODONE [Presence] in Specimen | 0.927 |  |
| 3009272 | traMADol [Presence] in Urine by Confirmatory method | 0.925 |  |
| 40762887 | Creatinine [Moles/volume] in Blood | 0.924 | 283 |
| 3008392 | Creatinine/Protein [Mass Ratio] in Urine | 0.924 |  |
| 3008960 | Albumin [Mass/volume] in 24 hour Urine | 0.923 |  |
| 3022551 | Methylenedioxymethamphetamine [Presence] in Urine | 0.923 |  |
| 3017396 | Urobilin [Presence] in Urine | 0.923 |  |
| 649500 | Albumin/Creatinine [Measurement] in Urine | 0.923 |  |
| 46235076 | Creatinine [Moles/volume] in Serum, Plasma or Blood | 0.921 |  |
| 1092204 | Epithelial cells.squamous [#/area] in Urine sediment | 0.920 |  |
| 1260020 | traMADol [Presence] in Serum or Plasma | 0.920 |  |
| 3006006 | Tricyclic antidepressants [Presence] in Urine by Screen method | 0.920 | 443 |
| 46235897 | Albumin/Creatinine [Ratio] in 24 hour Urine | 0.919 |  |
| 1092008 | Casts [#/area] in Urine sediment | 0.919 |  |
| 3021016 | oxyCODONE [Presence] in Urine by Screen method | 0.918 |  |
| 3009451 | Bacteria identified in 24 hour Urine by Culture | 0.916 |  |
| 3044286 | Opiates [Presence] in Specimen | 0.916 |  |
| 40763732 | Protein/Creatinine [Mass Ratio] in 12 hour Urine | 0.915 |  |
| 3044003 | Tricyclic antidepressants [Presence] in Specimen | 0.914 |  |
| 3000955 | Protein/Creatinine [Mass Ratio] in Serum or Plasma | 0.912 |  |
| 3023093 | Urobilinogen [Presence] in Body fluid | 0.912 |  |
| 42870589 | Drugs of abuse panel - Urine by Screen method | 0.911 |  |
| 1001926 | Buprenorphine [Presence] in Urine by Screen method | 0.911 |  |
| 3021257 | Drugs of abuse 5 panel - Urine | 0.910 |  |
| 3029162 | Epithelial cells.squamous [#/area] in Urine sediment by Automated count | 0.910 |  |
| 3046561 | Hyaline casts [#/area] in Urine sediment by Microscopy high power field | 0.907 |  |
| 3035982 | Calcium/Creatinine [Mass Ratio] in 24 hour Urine | 0.907 |  |
| 3024418 | Acetaminophen [Presence] in Specimen | 0.906 |  |
| 1091601 | Epithelial cells [#/area] in Urine sediment | 0.906 |  |
| 3022509 | Hyaline casts [#/area] in Urine sediment by Microscopy low power field | 0.905 | 238 |
| 3028103 | Tricyclic antidepressants [Presence] in Urine by Confirmatory method | 0.904 |  |
| 3001802 | Microalbumin/Creatinine [Mass Ratio] in Urine | 0.903 | 212 |
| 3005058 | Barbiturates [Presence] in Urine by Screen method | 0.903 | 706 |
| 3030306 | Epithelial cells.non-squamous [#/volume] in Urine by Automated count | 0.901 |  |
| 21491928 | Buprenorphine [Presence] in Blood by Confirmatory method | 0.900 |  |
| 40762475 | Acetaminophen [Presence] in Urine by Screen method | 0.898 |  |
| 3011802 | Propoxyphene [Presence] in Urine | 0.898 | 932 |
| 645998 | Albumin [Measurement] in Urine | 0.898 |  |
| 3016856 | Barbiturates [Presence] in Urine by Confirmatory method | 0.897 |  |
| 3008076 | Acetaminophen [Presence] in Body fluid | 0.896 |  |
| 3019479 | Bacteria # 2 identified in Urine by Culture | 0.896 |  |
| 3005639 | oxyCODONE [Presence] in Urine by Confirmatory method | 0.896 | 1628 |
| 3033268 | Albumin [Mass/time] in Urine collected for unspecified duration --supine | 0.896 |  |
| 3003132 | Barbiturates [Presence] in Serum, Plasma or Blood | 0.895 | 520 |
| 3046266 | Transitional cells [#/area] in Urine sediment by Microscopy low power field | 0.895 |  |
| 646827 | Protein/Creatinine [Measurement] in Urine | 0.895 |  |
| 3036941 | Urinalysis complete panel - Urine | 0.894 |  |
| 3009508 | Creatinine [Moles/volume] in Urine | 0.894 | 161 |
| 3014320 | Bacteria identified in Urethra by Culture | 0.893 |  |
| 3040639 | Cocaine [Presence] in Specimen | 0.892 |  |
| 1988296 | Hyaline-granular casts [#/volume] in Urine sediment by Computer assisted method | 0.892 |  |
| 3015208 | Opiates [Presence] in Urine by Screen method | 0.892 | 987 |
| 3035851 | Transitional cells [#/area] in Urine sediment by Microscopy high power field | 0.892 | 491 |
| 3038404 | Protein/Creatinine [Ratio] in 24 hour Urine | 0.892 |  |
| 3012868 | oxyCODONE [Presence] in Serum or Plasma | 0.891 |  |
| 3000837 | Albumin/Creatinine [Mass Ratio] in Urine by Test strip | 0.891 |  |
| 645740 | traMADol [Measurement] in Urine | 0.890 |  |
| 3046731 | Epithelial cells.squamous [#/area] in Urine sediment by Microscopy low power field | 0.889 |  |
| 1091227 | Hyaline casts [#/area] in Urine by Computer assisted method | 0.889 |  |
| 3018060 | Cocaine [Presence] in Urine by Screen method | 0.889 |  |
| 648131 | Tricyclic antidepressants [Measurement] in Urine | 0.888 |  |
| 3964702 | Creatinine [Moles/volume] in Venous blood | 0.888 |  |
| 36660607 | Microalbumin [Presence] in Urine by Test strip | 0.888 |  |
| 647935 | Buprenorphine [Measurement] in Urine | 0.887 |  |
| 1092420 | Epithelial cells.non-squamous [#/area] in Urine sediment | 0.887 |  |
| 3011341 | Barbiturates [Presence] in Stool | 0.886 |  |
| 3003392 | Bacteria # 4 identified in Urine by Culture | 0.885 |  |
| 3019121 | Opiates [Presence] in Urine by SAMHSA screen method | 0.885 |  |
| 3045571 | Creatinine/Calcium [Mass Ratio] in Urine | 0.885 |  |
| 3000850 | Epithelial cells [#/volume] in Urine | 0.885 |  |
| 3023147 | Calcium/Creatinine [Mass Ratio] in 2 hour Urine | 0.885 |  |
| 3025478 | Tricyclic antidepressants [Presence] in Serum or Plasma | 0.884 | 421 |
| 3035722 | Cocaine [Presence] in Urine by Confirmatory method | 0.884 |  |
| 3046055 | Albumin [Presence] in Body fluid | 0.884 |  |
| 3026726 | Creatinine [Moles/volume] in Specimen | 0.884 |  |
| 3047166 | Epithelial cells [#/area] in Urine sediment by Automated count | 0.883 |  |
| 3023562 | Opiates [Presence] in Urine by Confirmatory method | 0.883 | 553 |
| 3009878 | Urobilin [Presence] in Stool | 0.883 |  |
| 649233 | Calcium/Creatinine [Measurement] in Urine | 0.882 |  |
| 645629 | Porphobilinogen [Measurement] in Urine | 0.882 |  |
| 36303442 | Epithelial cells [#/volume] in Urine by Automated | 0.882 |  |
| 3032467 | Bilirubin+Urobilinogen [Presence] in Urine | 0.882 |  |
| 3012479 | Opiates [Presence] in Serum or Plasma | 0.881 |  |
| 3037459 | Creatinine [Moles/volume] in Body fluid | 0.881 | 1234 |
| 3026895 | Opiates [Presence] in Stool | 0.879 |  |
| 3046484 | Bacteria # 8 identified in Urine by Culture | 0.879 |  |
| 648390 | Acetaminophen [Measurement] in Urine | 0.879 |  |
| 3045335 | Bacteria # 7 identified in Urine by Culture | 0.879 |  |
| 21492215 | traMADol [Presence] in Blood by Confirmatory method | 0.879 |  |
| 40761460 | Buprenorphine+Norbuprenorphine [Presence] in Urine by Screen method | 0.878 |  |
| 3003113 | Bacteria # 5 identified in Urine by Culture | 0.878 |  |
| 3005024 | Bacteria # 3 identified in Urine by Culture | 0.877 |  |
| 40768439 | Drugs of abuse 5 panel - Urine by Screen method | 0.876 |  |
| 3002013 | Bacteria # 6 identified in Urine by Culture | 0.876 |  |
| 40763957 | Albumin [Mass/volume] in Urine from Fetus | 0.876 |  |
| 46235087 | Buprenorphine [Presence] in Saliva (oral fluid) by Confirmatory method | 0.875 |  |
| 3033308 | Hyaline casts [Presence] in Urine sediment by Light microscopy | 0.875 | 191 |
| 3037426 | Urobilinogen [Presence] in Urine by Test strip | 0.875 | 134 |
| 3001008 | Epithelial cells.squamous [#/area] in Urine sediment by Microscopy high power field | 0.874 | 148 |
| 3041412 | Epithelial cells.non-squamous [#/area] in Urine sediment by Automated count | 0.874 |  |
| 21491589 | Tricyclic antidepressants [Presence] in Urine by Screen method >300 ng/mL | 0.873 |  |
| 3002388 | Ova and parasites identified in Stool by Parasite sedimentation | 0.873 |  |
| 3004709 | Norpropoxyphene [Presence] in Urine | 0.872 |  |
| 1092035 | Epithelial cells.squamous [#/area] in Urine by Computer assisted method | 0.871 |  |
| 3046787 | Ova and parasites identified in Stool by Trichrome stain | 0.870 |  |
| 1092378 | Norbuprenorphine [Presence] in Urine | 0.869 |  |
| 3043798 | Albumin [Presence] in Serum or Plasma | 0.869 |  |
| 647067 | Opiates [Measurement] in Urine | 0.869 |  |
| 3030688 | Urinalysis panel - Urine by Automated | 0.869 |  |
| 42529510 | Buprenorphine [Presence] in Specimen by Screen method | 0.869 |  |
| 3034223 | HYDROcodone [Presence] in Urine | 0.868 | 1622 |
| 21492216 | traMADol [Presence] in Blood by Screen method | 0.868 |  |
| 40761463 | Norbuprenorphine [Presence] in Urine by Confirmatory method | 0.868 |  |
| 3003709 | Acetaminophen [Presence] in Serum or Plasma | 0.868 | 829 |
| 647898 | Barbiturates [Measurement] in Urine | 0.866 |  |
| 36305828 | Drugs of abuse screen W Reflex confirm panel - Urine | 0.865 |  |
| 3005518 | Ova and parasites identified in Stool by Immune stain | 0.865 |  |
| 43055193 | Pathologic casts [Presence] in Urine by Automated | 0.865 |  |
| 3010366 | Acetaminophen [Mass/volume] in Urine | 0.865 |  |
| 3044250 | Barbiturates [Presence] in Meconium | 0.865 |  |
| 648307 | Cocaine [Measurement] in Urine | 0.865 |  |
| 3043771 | Microalbumin [Mass/time] in 12 hour Urine | 0.864 |  |
| 3008512 | Albumin [Mass/volume] in Urine by Electrophoresis | 0.864 | 1035 |
| 3026879 | Butabarbital [Presence] in Urine | 0.864 |  |
| 3004391 | Epithelial cells [#/volume] in Urine by Manual count | 0.864 |  |
| 648044 | oxyCODONE [Measurement] in Urine | 0.864 |  |
| 3000600 | Renal tubular casts [#/area] in Urine by Light microscopy | 0.864 |  |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 0.864 |  |
| 3041499 | Barbiturates [Presence] in Hair | 0.864 |  |
| 3012744 | Ova and parasites identified in Specimen by Light microscopy | 0.863 | 527 |
| 1469855 | Buprenorphine [Presence] in Hair | 0.863 |  |
| 3002000 | Albumin [Mass/volume] in Specimen | 0.863 |  |
| 3022826 | Microalbumin/Creatinine [Ratio] in Urine | 0.863 |  |
| 3041957 | Epithelial cells.non-squamous [#/area] in Urine sediment by Microscopy low power field | 0.862 |  |
| 3001298 | Ova and parasites identified in Stool by McMaster concentration | 0.862 |  |
| 1469591 | Tubular cells [#/volume] in Urine sediment | 0.862 |  |
| 1988325 | Hyaline-granular casts [#/area] in Urine sediment by Computer assisted method | 0.862 |  |
| 40761531 | oxyCODONE+oxyMORphone [Presence] in Urine by Screen method | 0.862 |  |
| 21491434 | Tricyclic antidepressants [Presence] in Urine by Screen method >1000 ng/mL | 0.862 |  |
| 3020389 | Ova and parasites identified in Stool by Concentration | 0.862 | 257 |
| 21494637 | Tricyclic antidepressants [Presence] in Blood by Screen method | 0.861 |  |
| 3002827 | Microalbumin/Creatinine [Mass Ratio] in 24 hour Urine | 0.861 | 1979 |
| 3005448 | Ova and parasites identified in Stool by Iron hematoxylin stain | 0.860 |  |
| 3032729 | Buprenorphine [Mass/volume] in Urine by Confirmatory method | 0.859 |  |
| 3001858 | Opiates [Presence] in Meconium | 0.859 | 1417 |
| 3018097 | Albumin [Mass/time] in 24 hour Urine by Electrophoresis | 0.858 |  |
| 3041060 | Methylenedioxymethamphetamine [Presence] in Specimen | 0.857 |  |
| 3020297 | Epithelial cells.renal [#/volume] in Urine sediment | 0.856 |  |
| 3043366 | Epithelial cells [#/area] in Urine sediment by Microscopy low power field | 0.856 |  |
| 1988285 | Superficial transitional cells [#/area] in Urine sediment by Computer assisted method | 0.855 |  |
| 3021819 | Acetaminophen [Units/volume] in Urine | 0.854 |  |
| 3004361 | Ova and parasites identified in Stool by Kinyoun iron hematoxylin stain | 0.854 |  |
| 3013632 | Cocaine [Presence] in Serum or Plasma | 0.854 |  |
| 1001608 | traMADol [Presence] in Meconium by Screen method | 0.853 |  |
| 3028475 | Transitional cells [Presence] in Urine sediment by Light microscopy | 0.853 | 1317 |
| 1092319 | Casts [Presence] in Urine sediment | 0.852 |  |
| 40763958 | oxyCODONE+oxyMORphone [Presence] in Urine by Confirmatory method | 0.852 |  |
| 3001272 | Opiates [Presence] in Urine by SAMHSA confirm method | 0.852 |  |
| 1617497 | Urea/Creatinine [Mass Ratio] in Urine | 0.852 |  |
| 3022890 | Cocaine [Presence] in Blood | 0.852 |  |
| 1175818 | Buprenorphine-3-glucuronide [Presence] in Urine by Screen method | 0.851 |  |
| 3044318 | Oxalate/Creatinine [Molar ratio] in Urine | 0.851 |  |
| 1091481 | Hyaline casts [Presence] in Urine sediment | 0.851 |  |
| 3011931 | Proline/Creatinine [Mass Ratio] in Urine | 0.849 |  |
| 40763812 | Methylenedioxyethylamphetamine [Presence] in Urine | 0.849 |  |
| 3009803 | traMADol [Mass/volume] in Urine | 0.849 |  |
| 3025644 | oxyMORphone [Presence] in Urine | 0.849 |  |
| 44786767 | traMADol [Presence] in Saliva (oral fluid) by Screen method | 0.849 |  |
| 3014051 | Protein [Presence] in Urine by Test strip | 0.848 | 99 |
| 3039522 | Prealbumin [Mass/volume] in Urine | 0.848 |  |
| 3029115 | Methylenedioxyamphetamine [Presence] in Urine | 0.848 |  |
| 3017750 | Porphobilinogen [Mass/volume] in Urine | 0.848 |  |
| 3032008 | 2-Ethylidene-1,5-Dimethyl-3,3-Diphenylpyrrolidine (EDDP) [Presence] in Urine | 0.847 |  |
| 40765224 | Urobilinogen [Presence] in Urine by Automated test strip | 0.847 |  |
| 3039902 | Granular casts [#/volume] in Urine by Computer assisted method | 0.846 |  |
| 40757477 | Albumin [Mass/volume] in Stool | 0.846 |  |
| 3042856 | Acetaminophen+Phenacetin [Presence] in Urine by Screen method | 0.846 |  |
| 1260102 | Creatinine [Moles/volume] in Serum or Plasma by LC/MS/MS | 0.844 |  |
| 1091888 | Epithelial cells.renal [#/area] in Urine sediment | 0.843 |  |
| 1469718 | Granular casts [#/volume] in Urine sediment by Computer assisted method | 0.843 |  |
| 3038807 | Methylenedioxymethamphetamine [Presence] in Serum or Plasma | 0.842 |  |
| 3028469 | Citrate/Creatinine [Molar ratio] in Urine | 0.842 |  |
| 3009956 | Propoxyphene [Presence] in Urine by Screen method | 0.841 | 1464 |
| 3019383 | Ova and parasites identified in Stool by Baermann concentration | 0.841 |  |
| 3013539 | Creatinine [Moles/volume] in 24 hour Urine | 0.840 | 1978 |
| 1989084 | Calcium/Creatinine [Mass Ratio] in Urine from Fetus | 0.840 |  |
| 647683 | Hyaline casts [Measurement] in Urine sediment | 0.840 |  |
| 3005253 | Phenacetin [Presence] in Urine | 0.840 |  |
| 46236875 | Albumin [Mass/volume] by Electrophoresis in Urine collected for unspecified duration | 0.839 |  |
| 43533384 | Drugs of abuse panel - Blood by Screen method | 0.838 |  |
| 40760483 | Microalbumin [Mass/volume] in 12 hour Urine | 0.837 |  |
| 3045043 | Propoxyphene [Presence] in Specimen | 0.837 |  |
| 3043681 | Transitional cells [#/area] in Urine by Computer assisted method | 0.837 |  |
| 3041735 | Creatinine [Moles/volume] in Serum or Plasma --baseline | 0.837 |  |
| 3002148 | Methylenedioxymethamphetamine [Presence] in Urine by Screen method | 0.836 |  |
| 3030405 | Hyaline casts [Presence] in Urine by Automated | 0.836 |  |
| 3002395 | Porphobilinogen [Moles/volume] in Urine | 0.835 |  |
| 3036634 | Albumin [Presence] in 24 hour Urine by Electrophoresis | 0.833 |  |
| 3020993 | Methylenedioxymethamphetamine [Presence] in Urine by Confirmatory method | 0.833 |  |
| 1175703 | Drugs of abuse panel - Body fluid | 0.833 |  |
| 3022621 | pH of Urine by Test strip | 0.833 | 59 |
| 3965477 | Pathologic casts [Presence] in Urine sediment by Light microscopy | 0.831 |  |
| 3009549 | Trypsin [Presence] in Stool | 0.830 |  |
| 3018019 | Cocaine [Mass/volume] in Urine | 0.830 |  |
| 649125 | Urobilinogen [Measurement] in Urine | 0.830 |  |
| 3033812 | Protein [Mass/time] in 12 hour Urine | 0.829 |  |
| 3015021 | Porphobilinogen [Mass/volume] in 24 hour Urine | 0.829 |  |
| 3039801 | Cocaine [Presence] in Meconium | 0.827 | 1448 |
| 3046825 | Epithelial cells.renal [#/area] in Urine sediment by Microscopy low power field | 0.827 |  |
| 3036541 | Propoxyphene + Norpropoxyphene [Presence] in Urine by Screen method | 0.827 |  |
| 3041694 | Casts type not specified [#/volume] in Urine by Computer assisted method | 0.827 |  |
| 3039904 | Epithelial cells.renal [#/volume] in Urine by Computer assisted method | 0.827 |  |
| 3040509 | Prealbumin [Mass/time] in 24 hour Urine | 0.826 |  |
| 3007876 | Appearance of Urine | 0.826 | 66 |
| 1091537 | Epithelial cells.squamous [Presence] in Urine sediment | 0.826 |  |
| 40761537 | Casts [Type] in Urine sediment by Light microscopy | 0.825 |  |
| 3029925 | Color of Urine by Auto | 0.825 |  |
| 40758548 | Home drug screening panel - Urine | 0.825 |  |
| 3042209 | Waxy casts [#/volume] in Urine sediment | 0.825 |  |
| 3034076 | Specific gravity of 24 hour Urine | 0.823 |  |
| 3019377 | Propoxyphene [Presence] in Urine by Confirmatory method | 0.822 |  |
| 1469809 | WBC casts [#/volume] in Urine sediment by Computer assisted method | 0.821 |  |
| 3044221 | Cocaine [Presence] in Hair | 0.820 |  |
| 3009252 | Propoxyphene [Presence] in Stool | 0.819 |  |
| 3020207 | Porphobilinogen [Moles/time] in 24 hour Urine | 0.819 |  |
| 3019150 | Specific gravity of Urine by Refractometry | 0.819 |  |
| 3037377 | Propoxyphene + Norpropoxyphene [Presence] in Urine by Confirmatory method | 0.818 |  |
| 3015023 | Epithelial cells.renal [#/area] in Urine sediment by Microscopy high power field | 0.818 | 605 |
| 3030946 | Fine Granular Casts [#/area] in Urine sediment by Automated count | 0.818 |  |
| 3035106 | Propoxyphene [Presence] in Serum or Plasma | 0.818 |  |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.817 |  |
| 1469687 | pH of Urine by pH-meter | 0.817 |  |
| 1002422 | 2-Ethylidene-1,5-Dimethyl-3,3-Diphenylpyrrolidine (EDDP) [Presence] in Urine by Screen method | 0.816 |  |
| 1175629 | Drugs of abuse panel - Hair | 0.816 |  |
| 645265 | Methylenedioxymethamphetamine [Measurement] in Urine | 0.816 |  |
| 3030335 | Coarse Granular Casts [#/area] in Urine sediment by Automated count | 0.815 |  |
| 3013997 | Dextromethorphan [Presence] in Urine | 0.812 |  |
| 3044592 | Porphobilinogen [Moles/volume] in 24 hour Urine | 0.811 |  |
| 3029361 | Urinalysis dipstick panel - Urine by Automated test strip | 0.811 |  |
| 3019077 | Protein [Presence] in 24 hour Urine by Test strip | 0.811 |  |
| 3012844 | Porphyrins [Presence] in Urine | 0.809 |  |
| 3011397 | Hemoglobin [Presence] in Urine by Test strip | 0.808 | 72 |
| 3032569 | 2-Ethylidene-1,5-Dimethyl-3,3-Diphenylpyrrolidine (EDDP) [Presence] in Specimen | 0.806 |  |
| 36305963 | Granular casts [#/area] in Urine sediment | 0.806 |  |
| 3043138 | Epithelial cells.renal [#/area] in Urine by Computer assisted method | 0.805 |  |
| 40760845 | Protein [Presence] in Urine by Automated test strip | 0.804 |  |
| 3039059 | Drugs of abuse 7 and Alcohol and Tricyclics panel - Urine by Screen method | 0.804 |  |
| 3040042 | pH of 4 hour Urine | 0.804 |  |
| 40763845 | Methylenedioxymethamphetamine [Presence] in Gastric fluid | 0.803 |  |
| 3014814 | Methamphetamine [Presence] in Urine | 0.802 | 634 |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.802 |  |
| 1092282 | Methadone Confirmatory panel - Urine | 0.801 |  |
| 36303515 | Broad casts [#/area] in Urine sediment | 0.800 |  |
| 3005577 | Microalbumin [Mass/time] in 24 hour Urine | 0.800 | 1294 |
| 3043179 | Microalbumin [Mass/time] in 4 hour Urine | 0.799 |  |
| 3052990 | Drugs of abuse panel - Meconium | 0.798 |  |
| 3003291 | Casts [Presence] in Urine sediment by Light microscopy | 0.797 |  |
| 3024291 | Alpha 1 globulin [Presence] in Urine | 0.796 |  |
| 3029305 | pH of Urine by Automated test strip | 0.796 |  |
| 3030511 | Albumin [Mass/volume] in 24 hour Urine by Electrophoresis | 0.796 |  |
| 1092063 | 2-Ethylidene-1,5-Dimethyl-3,3-Diphenylpyrrolidine (EDDP) [Presence] in Urine by Gas chromatography-mass spectrometry | 0.795 |  |
| 40761529 | 2-Ethylidene-1,5-Dimethyl-3,3-Diphenylpyrrolidine (EDDP) [Presence] in Urine by Confirmatory method | 0.795 |  |
| 36304468 | Casts [Presence] in Urine | 0.790 |  |
| 3031215 | 2-Ethylidene-1,5-Dimethyl-3,3-Diphenylpyrrolidine (EDDP) [Presence] in Serum or Plasma | 0.790 |  |
| 3011760 | Epithelial cells.extrarenal [#/area] in Urine sediment by Microscopy high power field | 0.788 |  |
| 1176420 | Epithelial cells.renal [Presence] in Urine sediment | 0.788 |  |
| 3043812 | Specific gravity of 24 hour Urine by Refractometry | 0.786 |  |
| 3015501 | pH of 24 hour Urine | 0.786 |  |
| 3023245 | Trypsinogen [Presence] in Serum or Plasma | 0.785 |  |
| 648954 | 2-Ethylidene-1,5-Dimethyl-3,3-Diphenylpyrrolidine (EDDP) [Measurement] in Urine | 0.780 |  |
| 40761501 | Specimen pH acceptable of Urine | 0.780 |  |
| 648207 | Isoniazid [Measurement] in Serum or Plasma | 0.779 |  |
| 36660149 | OxyCODONE and metabolites panel - Urine by Confirmatory method | 0.778 |  |
| 3000330 | Specific gravity of Urine by Test strip | 0.777 | 71 |
| 1988922 | Superficial transitional cells [Presence] in Urine sediment by Computer assisted method | 0.775 |  |
| 3040007 | pH of 2 hour Urine | 0.775 |  |
| 1092033 | Epithelial cells [Presence] in Urine sediment | 0.775 |  |
| 1988185 | Stimulants drug panel - Urine by Screen method | 0.774 |  |
| 40763838 | 2-Ethylidene-1,5-Dimethyl-3,3-Diphenylpyrrolidine (EDDP) [Presence] in Gastric fluid | 0.771 |  |
| 3046619 | Specific gravity of Specimen | 0.771 |  |
| 3031015 | pH of 24 hour Urine by Test strip | 0.769 |  |
| 1175815 | Drugs of abuse panel - Tissue | 0.769 |  |
| 3002650 | Tubular cells [Presence] in Urine sediment by Light microscopy | 0.769 | 956 |
| 40761809 | Adulterants panel - Urine | 0.766 |  |
| 3008026 | Epithelial cells.renal [Presence] in Urine sediment by Light microscopy | 0.765 | 721 |
| 36032057 | Opioids panel - Urine by Screen method | 0.765 |  |
| 3031029 | 2-Ethylidene-1,5-Dimethyl-3,3-Diphenylpyrrolidine (EDDP) [Mass/volume] in Urine | 0.763 |  |
| 3037850 | Specific gravity of Body fluid | 0.763 |  |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.762 |  |
| 3041098 | Transitional cells [Presence] in Urine by Computer assisted method | 0.757 |  |
| 3039919 | Specific gravity of Urine by Automated test strip | 0.757 |  |
| 1091041 | Epithelial cells.non-squamous [Presence] in Urine sediment | 0.755 |  |
| 3032641 | Amino acids panel - Urine | 0.753 |  |
| 645145 | Trypsin [Measurement] in Stool | 0.753 |  |
| 3043714 | Erythrocytes [Presence] in Stool | 0.752 |  |
| 3029991 | Specific gravity of Urine by Refractometry automated | 0.751 |  |
| 3011422 | Epithelial cells [Presence] in Urine sediment by Light microscopy | 0.749 | 151 |
| 3032448 | Specific gravity of Urine by Adjustment to pH 7.4 | 0.748 |  |
| 3042009 | Drugs identified in Urine by Confirmatory method | 0.748 | 1711 |
| 3045424 | Erythrocytes [Presence] in Urine | 0.747 | 287 |
| 1091059 | Erythrocytes [Presence] in Urine sediment | 0.742 |  |
| 3043738 | Trypsin [Titer] in Stool | 0.741 |  |
| 3046030 | Erythrocytes [Presence] in Urine sediment by Light microscopy | 0.741 |  |
| 3039382 | Trypsinogen I Free [Presence] in DBS | 0.741 |  |
| 3015579 | Color of Body fluid | 0.738 | 352 |
| 3037490 | Color of Stool | 0.738 |  |
| 1761421 | traMADol and Metabolites Panel - Urine by Confirmatory method | 0.737 |  |
| 3011941 | Isoniazid [Mass/volume] in Serum or Plasma | 0.731 |  |
| 3035662 | Isoniazid [Susceptibility] | 0.727 |  |
| 3020406 | Isoniazid [Moles/volume] in Serum or Plasma | 0.725 |  |
| 3040843 | Epithelial cells.renal [Presence] in Urine by Computer assisted method | 0.722 |  |
| 3005312 | Cytosol aminopeptidase [Presence] in Urine | 0.722 |  |
| 3018933 | Trypsin [Enzymatic activity/volume] in Stool | 0.721 |  |
| 3029863 | Chymotrypsin [Presence] in Stool | 0.720 |  |
| 3037596 | N Ag [Presence] on Red Blood Cells | 0.718 |  |
| 3003573 | C Ag [Presence] on Red Blood Cells | 0.718 |  |
| 3018672 | pH of Body fluid | 0.716 | 953 |
| 3050592 | Epithelial cells [Presence] in Blood by Light microscopy | 0.713 |  |
| 43054905 | Erythrocytes [Presence] in Specimen by Gram stain | 0.712 |  |
| 3023738 | Nicotinamide [Presence] in Urine | 0.709 |  |
| 3011093 | Trypsin [Enzymatic activity/time] in 24 hour Stool | 0.709 |  |
| 3023951 | Trypsin Ag [Presence] in Tissue by Immune stain | 0.709 |  |
| 3008684 | Color of Semen | 0.708 |  |
| 36303790 | Epithelial cells [Presence] in Urine | 0.708 |  |
| 3044637 | Erythrocytes [Presence] in Body fluid | 0.707 |  |
| 3029396 | Erythrocyte agglutination [Presence] in Blood | 0.706 |  |
| 3008204 | Clarity of Urine | 0.703 | 1066 |
| 3028632 | Character of Urine | 0.702 | 272 |
| 3004530 | Isocitrate [Presence] in Urine | 0.699 |  |
| 3016131 | Nitrosonaphthol [Presence] in Urine | 0.699 |  |
| 3046596 | Color of Specimen | 0.694 |  |
| 3003586 | Phenytoin [Presence] in Urine | 0.689 |  |
| 3011042 | Disulfiram [Presence] in Urine | 0.683 |  |
| 36203862 | Color of Sputum | 0.669 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1966 | cu-alb-mi | ug/min | 80% | name+unit+values | 7258 | 0.01 | [2.01, 3.06, 4.68, 7.09, 11.88, 22.58, 45.52, 98.32, 249.52] | cU-Albumiini, mikroalbuminuria | Collected urine | Micro | Albumin [Mass/time] in Collected urine |
| 1967 | cu-alb-mi |  | 20% | name | 1830 | 100 |  | cU-Albumiini, mikroalbuminuria | Collected urine | Micro | Albumin in Collected urine |
| 1968 | e-coli. |  | 100% | name | 930 | 100 |  |  | Erythrocyte |  | Escherichia coli [Presence] in Red Blood Cells |
| 1969 | f-para-o |  | 100% | name | 16222 | 100 |  | F -Parasiitit (kval) | Feces | Qualitative test (also semi-quantitative) | Ova and Parasites identified in Stool by Microscopy |
| 1970 | nu-alb-mi | mg/12h | 4% | name+unit | 12 | 0 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin [Mass/time] in 12 hour Urine |
| 1971 | nu-alb-mi | ug/min | 48% | name+unit+values | 155 | 0 | [4.6, 8.83, 19.33, 34.27, 68, 107.86, 175.14, 311.43, 536.5] | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin [Mass/time] in Timed Urine |
| 1972 | nu-alb-mi |  | 48% | name | 157 | 100 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin in Timed Urine |
| 1973 | nu-albkre | mg/mmol | 17% | name+unit+values | 438 | 0 | [0.3, 0.49, 0.64, 0.9, 1.29, 2.02, 4.14, 8.64, 23.01] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1974 | nu-albkre |  | 83% | name+values | 2191 | 100 | [0.39, 0.5, 0.69, 0.88, 1.21, 1.8, 2.91, 6.37, 18.94] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1975 | nu-albkrea | mg/mmol | 44% | name+unit+values | 20929 | 0 | [0.3, 0.42, 0.59, 0.82, 1.19, 1.86, 3.33, 7.3, 23.5] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1976 | nu-albkrea |  | 56% | name | 26197 | 100 |  |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1977 | p-seulkre |  | 100% | name | 277 | 100 |  |  | Plasma |  | Creatinine [Moles/volume] in Plasma |
| 1978 | u-a1mikre |  | 100% | name+values | 113 | 100 | [1, 2.45, 3.7, 6.95, 9, 11.14, 14.58, 17.92, 35.1] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1979 | u-alb-0 |  | 100% | name | 992 | 100 |  |  | Urine |  | Albumin [Presence] in Urine |
| 1980 | u-alb-lb | mg/l | 58% | name+unit | 70 | 0 |  |  | Urine |  | Albumin [Mass/volume] in Urine |
| 1981 | u-alb-lb |  | 42% | name | 50 | 100 |  |  | Urine |  | Albumin [Mass/volume] in Urine |
| 1982 | u-alb-mi | mg/l | 71% | name+unit+values | 7488 | 0 | [3, 3.95, 5.25, 7.22, 10.53, 17.06, 32.59, 75.32, 297.66] |  | Urine | Micro | Albumin [Mass/volume] in Urine |
| 1983 | u-alb-mi |  | 29% | name | 3031 | 100 |  |  | Urine | Micro | Albumin [Mass/volume] in Urine |
| 1984 | u-alb-o | estimate | 34% | name+unit+values | 161670 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin [Presence] in Urine by Test strip |
| 1985 | u-alb-o | form | 0% | name+unit+values | 287 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin [Presence] in Urine by Test strip |
| 1986 | u-alb-o |  | 66% | name | 312867 | 100 |  | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin [Presence] in Urine |
| 1987 | u-alb/kre | g/mol | 3% | name+unit+values | 142 | 0 | [1.8, 3.05, 3.89, 5.37, 8.29, 16.27, 32.91, 51.96, 140.67] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1988 | u-alb/kre | mg/mmol | 50% | name+unit+values | 2591 | 0 | [0.3, 0.42, 0.6, 0.84, 1.25, 2.06, 4.01, 8.97, 30.06] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1989 | u-alb/kre |  | 48% | name | 2491 | 100 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1990 | u-alb/krea | g/mol | 3% | name+unit | 49 | 0 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1991 | u-alb/krea | mg/mmol | 51% | name+unit+values | 879 | 0 | [0.29, 0.4, 0.53, 0.74, 1.07, 1.82, 2.9, 5.82, 14.81] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1992 | u-alb/krea |  | 47% | name | 812 | 100 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1993 | u-albkre | mg/mmol | 60% | name+unit+values | 294883 | 0 | [0.3, 0.5, 0.68, 0.99, 1.55, 2.76, 5.6, 13.95, 52.37] | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1994 | u-albkre |  | 40% | name | 200553 | 100 |  | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1995 | u-albkrea | mg/mmol | 40% | name+unit+values | 10590 | 0 | [0.3, 0.44, 0.58, 0.73, 0.97, 1.32, 1.85, 3.04, 9.5] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1996 | u-albkrea | mg/mmol/l | 0% | name+unit | 81 | 0 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1997 | u-albkrea |  | 59% | name+values | 15486 | 100 | [0.4, 0.65, 1.07, 1.97, 3.4, 4.95, 7.8, 14.39, 37.94] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 1998 | u-alvhu4a |  | 100% | name | 760 | 100 |  |  | Urine |  |  |
| 1999 | u-alvhu5b |  | 100% | name | 912 | 100 |  |  | Urine |  |  |
| 2000 | u-alvhu6a |  | 100% | name | 1273 | 100 |  |  | Urine |  |  |
| 2001 | u-barb-o |  | 100% | name | 1791 | 100 |  | U -Barbituraatit (kval) | Urine | Qualitative test (also semi-quantitative) | Barbiturates [Presence] in Urine |
| 2002 | u-bupre-0 |  | 100% | name | 642 | 100 |  |  | Urine |  | Buprenorphine [Presence] in Urine |
| 2003 | u-bupre-o | estimate | 0% | name+unit | 207 | 0 |  | U -Buprenorfiini (kval) | Urine | Qualitative test (also semi-quantitative) | Buprenorphine [Presence] in Urine |
| 2004 | u-bupre-o |  | 100% | name | 44187 | 100 |  | U -Buprenorfiini (kval) | Urine | Qualitative test (also semi-quantitative) | Buprenorphine [Presence] in Urine |
| 2005 | u-buprect |  | 100% | name | 1841 | 100 |  | U -Buprenorfiini, varmistus | Urine |  | Buprenorphine [Presence] in Urine by Confirmation |
| 2006 | u-cakre |  | 100% | name | 106 | 100 |  |  | Urine |  | Calcium/Creatinine [Molar ratio] in Urine |
| 2007 | u-color |  | 100% | name | 160 | 100 |  |  | Urine |  | Color of Urine |
| 2008 | u-dxpro-o |  | 100% | name | 125 | 100 |  | U -Dekstropropoksifeeni, seulonta (kval) | Urine | Qualitative test (also semi-quantitative) | Dextropropoxyphene [Presence] in Urine |
| 2009 | u-eddp-o |  | 100% | name | 266 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) | EDDP [Presence] in Urine |
| 2010 | u-huum-10 |  | 100% | name | 109 | 100 |  |  | Urine |  | Drugs of abuse 10 panel - Urine |
| 2011 | u-huum-ct |  | 100% | name | 1643 | 100 |  |  | Urine | Confirmation, confirmatory test | Drugs of abuse confirmation panel - Urine |
| 2012 | u-huum-o |  | 100% | name | 36546 | 100 |  | U -Huumeseulonta (kval) | Urine | Qualitative test (also semi-quantitative) | Drugs of abuse screen panel - Urine |
| 2013 | u-huum-op |  | 100% | name | 163 | 100 |  |  | Urine |  | Opiates [Presence] in Urine |
| 2014 | u-huum-ps |  | 100% | name | 160 | 100 |  |  | Urine | Basic screening | Drugs of abuse screen panel - Urine |
| 2015 | u-huum-su |  | 100% | name | 1133 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 2016 | u-huum4a |  | 100% | name | 118 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 2017 | u-huum5b |  | 100% | name | 128 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 2018 | u-huum6a |  | 100% | name | 241 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 2019 | u-huume-5b |  | 100% | name | 169 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 2020 | u-huume-6a |  | 100% | name | 115 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 2021 | u-huume-o |  | 100% | name | 425 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) | Drugs of abuse screen panel - Urine |
| 2022 | u-huuml-o | form | 0% | name+unit | 6 | 0 |  | U -Huume- ja lääkeaineseulonta (kval) | Urine | Qualitative test (also semi-quantitative) | Drugs of abuse and Medications screen panel - Urine |
| 2023 | u-huuml-o |  | 100% | name | 1648 | 100 |  | U -Huume- ja lääkeaineseulonta (kval) | Urine | Qualitative test (also semi-quantitative) | Drugs of abuse and Medications screen panel - Urine |
| 2024 | u-huumlct | form | 0% | name+unit | 9 | 0 |  | U -Huume- ja lääkeainetutkimus, laaja, varmistus | Urine |  | Drugs of abuse and Medications confirmation panel - Urine |
| 2025 | u-huumlct |  | 100% | name | 16104 | 100 |  | U -Huume- ja lääkeainetutkimus, laaja, varmistus | Urine |  | Drugs of abuse and Medications confirmation panel - Urine |
| 2026 | u-huumoct |  | 100% | name | 1367 | 100 |  |  | Urine |  | Drugs of abuse confirmation panel - Urine |
| 2027 | u-huumpika |  | 100% | name | 805 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine by Rapid test |
| 2028 | u-huumtof |  | 100% | name | 2536 | 100 |  |  | Urine |  | Drugs of abuse confirmation panel - Urine by Mass spec (TOF) |
| 2029 | u-huupika |  | 100% | name | 137 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine by Rapid test |
| 2030 | u-hyalie | e6/l | 97% | name+unit+values | 15276 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.18, 1] |  | Urine |  | Hyaline casts [#/volume] in Urine sediment by Automated count |
| 2031 | u-hyalie |  | 3% | name | 467 | 100 |  |  | Urine |  | Hyaline casts [#/volume] in Urine sediment |
| 2032 | u-hyalier | e6/l | 93% | name+unit+values | 11469 | 0 | [0, 0, 0, 0, 0, 0.07, 0.1, 0.3, 0.59] |  | Urine |  | Hyaline casts [#/volume] in Urine sediment by Automated count |
| 2033 | u-hyalier | u/field | 1% | name+unit+values | 109 | 0 | [0, 1, 1, 1, 1, 1, 1, 1, 2] |  | Urine |  | Hyaline casts [#/area] in Urine sediment by Light microscopy |
| 2034 | u-hyalier |  | 7% | name+values | 816 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0.39] |  | Urine |  | Hyaline casts [#/volume] in Urine sediment by Automated count |
| 2035 | u-hyallie | e6/l | 100% | name+unit+values | 146 | 0 | [0, 0, 0, 0, 0.1, 0.16, 0.39, 0.61, 1.03] |  | Urine |  | Hyaline casts [#/volume] in Urine sediment by Automated count |
| 2036 | u-inh-o |  | 100% | name | 124 | 100 |  | U -Isoniatsidi (kval) | Urine | Qualitative test (also semi-quantitative) | Isoniazid [Presence] in Urine |
| 2037 | u-koka-o | estimate | 0% | name+unit | 206 | 0 |  | U -Kokaiini (kval) | Urine | Qualitative test (also semi-quantitative) | Cocaine [Presence] in Urine |
| 2038 | u-koka-o |  | 100% | name | 50285 | 100 |  | U -Kokaiini (kval) | Urine | Qualitative test (also semi-quantitative) | Cocaine [Presence] in Urine |
| 2039 | u-levyep | e6/l | 95% | name+unit+values | 217342 | 0 | [0, 0, 0, 0, 0.52, 1, 2.01, 4.09, 9.83] |  | Urine |  | Squamous epithelial cells [#/volume] in Urine sediment by Automated count |
| 2040 | u-levyep | u/field | 0% | name+unit+values | 396 | 0 | [0, 0.82, 1, 1, 1, 1, 1, 1.89, 2.75] |  | Urine |  | Squamous epithelial cells [#/area] in Urine sediment by Light microscopy |
| 2041 | u-levyep |  | 5% | name | 10431 | 100 |  |  | Urine |  | Squamous epithelial cells [#/volume] in Urine sediment |
| 2042 | u-levyepi | e6/l | 1% | name+unit | 14 | 0 |  |  | Urine |  | Squamous epithelial cells [#/volume] in Urine sediment by Automated count |
| 2043 | u-levyepi | u/field | 90% | name+unit+values | 1272 | 0 | [0, 0, 0, 0, 0, 0.89, 1, 1, 2] |  | Urine |  | Squamous epithelial cells [#/area] in Urine sediment by Light microscopy |
| 2044 | u-levyepi |  | 9% | name | 131 | 100 |  |  | Urine |  | Squamous epithelial cells [#/volume] in Urine sediment |
| 2045 | u-lier | e6/l | 99% | name+unit+values | 351179 | 0 | [0, 0, 0, 0, 0, 0, 0.11, 1, 2.09] |  | Urine |  | Casts [#/volume] in Urine sediment by Automated count |
| 2046 | u-lier |  | 1% | name | 4775 | 100 |  |  | Urine |  | Casts [#/volume] in Urine sediment |
| 2047 | u-lierla | e6/l | 97% | name+unit+values | 2609 | 0.04 | [0, 0, 0, 0, 0, 0, 0, 0.76, 1] |  | Urine |  | Casts [#/volume] in Urine sediment by Automated count |
| 2048 | u-lierla |  | 3% | name | 67 | 100 |  |  | Urine |  | Casts [#/volume] in Urine sediment |
| 2049 | u-mdma-o |  | 100% | name | 7294 | 100 |  | U -Metyleenidioksimetamfetamiini (kval) | Urine | Qualitative test (also semi-quantitative) | MDMA [Presence] in Urine |
| 2050 | u-muulier | e6/l | 93% | name+unit+values | 11537 | 0 | [0, 0, 0, 0, 0, 0, 0.12, 0.16, 0.42] |  | Urine |  | Pathologic casts [#/volume] in Urine sediment by Automated count |
| 2051 | u-muulier |  | 7% | name+values | 846 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0.13] |  | Urine |  | Pathologic casts [#/volume] in Urine sediment |
| 2052 | u-odling |  | 100% | name | 238 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture |
| 2053 | u-oksik-o |  | 100% | name | 3802 | 100 |  | U -Oksikodoni (kval) | Urine | Qualitative test (also semi-quantitative) | Oxycodone [Presence] in Urine |
| 2054 | u-oxy-o |  | 100% | name | 284 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) | Oxycodone [Presence] in Urine |
| 2055 | u-paras-o |  | 100% | name | 629 | 100 |  | U -Parasetamoli (kval) | Urine | Qualitative test (also semi-quantitative) | Acetaminophen [Presence] in Urine |
| 2056 | u-pbg-o |  | 100% | name | 213 | 100 |  | U -Porfobilinogeeni (kval) | Urine | Qualitative test (also semi-quantitative) | Porphobilinogen [Presence] in Urine |
| 2057 | u-ph-0 |  | 100% | name+values | 1803 | 100 | [5, 5.47, 5.5, 5.51, 6, 6, 6.45, 6.93, 7] |  | Urine |  | pH of Urine |
| 2058 | u-ph-huu |  | 100% | name+values | 13233 | 100 | [5.15, 5.5, 5.88, 6, 6.48, 6.5, 6.96, 7, 7.5] |  | Urine |  | pH of Urine |
| 2059 | u-ph-hy |  | 100% | name+values | 2442 | 100 | [5.42, 5.5, 5.5, 5.74, 6, 6.02, 6.5, 7, 7] |  | Urine |  | pH of Urine |
| 2060 | u-ph-o | ph | 99% | name+unit+values | 52493 | 0 | [5.19, 5.5, 5.91, 6, 6.12, 6.5, 6.94, 7, 7.46] | U -Happamuusaste (kval) | Urine | Qualitative test (also semi-quantitative) | pH of Urine |
| 2061 | u-ph-o |  | 1% | name | 583 | 100 |  | U -Happamuusaste (kval) | Urine | Qualitative test (also semi-quantitative) | pH of Urine |
| 2062 | u-phhu |  | 100% | name | 170 | 100 |  |  | Urine |  | pH of Urine |
| 2063 | u-pien.ep | e6/l | 95% | name+unit+values | 999 | 0 | [0.02, 0.1, 0.2, 0.4, 0.51, 0.8, 1.11, 1.7, 3.08] |  | Urine |  | Renal tubular epithelial cells [#/volume] in Urine sediment by Automated count |
| 2064 | u-pien.ep |  | 5% | name | 55 | 100 |  |  | Urine |  | Renal tubular epithelial cells [#/volume] in Urine sediment |
| 2065 | u-pienep | e6/l | 96% | name+unit+values | 200789 | 0 | [0, 0, 0, 0, 0, 0.87, 1, 2, 3.84] |  | Urine |  | Renal tubular epithelial cells [#/volume] in Urine sediment by Automated count |
| 2066 | u-pienep |  | 4% | name | 9215 | 100 |  |  | Urine |  | Renal tubular epithelial cells [#/volume] in Urine sediment |
| 2067 | u-prokre | g/mol | 28% | name+unit+values | 973 | 0 | [5.07, 7, 8.95, 11.09, 14.48, 19.43, 27.53, 52.62, 161.41] | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein/Creatinine [Mass Ratio] in Urine |
| 2068 | u-prokre | mg/mmol | 53% | name+unit+values | 1813 | 0 | [9.65, 12.63, 16.22, 21.15, 31.06, 49.02, 103.19, 281.58, 1013.51] | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein/Creatinine [Mass Ratio] in Urine |
| 2069 | u-prokre |  | 19% | name | 646 | 100 |  | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein/Creatinine [Mass Ratio] in Urine |
| 2070 | u-protkre | mg/mmol | 100% | name+unit | 121 | 0 |  |  | Urine |  | Protein/Creatinine [Mass Ratio] in Urine |
| 2071 | u-seul-os |  | 100% | name | 186 | 100 |  |  | Urine |  | Urinalysis panel - Urine |
| 2072 | u-seul.hy |  | 100% | name | 447 | 100 |  |  | Urine |  | Urinalysis panel - Urine |
| 2073 | u-seulakr |  | 100% | name | 270 | 100 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine |
| 2074 | u-suht-hy |  | 100% | name+values | 2336 | 100 | [1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity of Urine |
| 2075 | u-suhti | form | 0% | name+unit | 38 | 0 |  | U -Suhteellinen tiheys | Urine |  | Specific gravity of Urine |
| 2076 | u-suhti | kg/l | 90% | name+unit+values | 307915 | 0 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.03] | U -Suhteellinen tiheys | Urine |  | Specific gravity of Urine |
| 2077 | u-suhti | ratio | 0% | name+unit+values | 570 | 0 | [1, 1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02] | U -Suhteellinen tiheys | Urine |  | Specific gravity of Urine |
| 2078 | u-suhti |  | 10% | name | 32697 | 100 |  | U -Suhteellinen tiheys | Urine |  | Specific gravity of Urine |
| 2079 | u-suhti-o | ratio | 100% | name+unit+values | 47144 | 0 | [1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02, 1.03] |  | Urine | Qualitative test (also semi-quantitative) | Specific gravity of Urine |
| 2080 | u-suhti. | ratio | 100% | name+unit+values | 24646 | 0 | [1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity of Urine |
| 2081 | u-suhtih | kg/l | 83% | name+unit+values | 46601 | 0 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity of Urine |
| 2082 | u-suhtih |  | 17% | name | 9841 | 100 |  |  | Urine |  | Specific gravity of Urine |
| 2083 | u-suhtih-o |  | 100% | name+values | 141 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.03] |  | Urine | Qualitative test (also semi-quantitative) | Specific gravity of Urine |
| 2084 | u-suhtihu |  | 100% | name | 161 | 100 |  |  | Urine |  | Specific gravity of Urine |
| 2085 | u-suhtiv |  | 100% | name+values | 766 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity of Urine |
| 2086 | u-trama-o |  | 100% | name | 4881 | 100 |  | U -Tramadoli (kval) | Urine | Qualitative test (also semi-quantitative) | Tramadol [Presence] in Urine |
| 2087 | u-trisy-o |  | 100% | name | 4379 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) | Tricyclic antidepressants [Presence] in Urine |
| 2088 | u-tryp2-o |  | 100% | name | 148 | 100 |  |  | Urine | Qualitative test (also semi-quantitative) | Trypsin-2 [Presence] in Urine |
| 2089 | u-tub.ep | /sunf | 6% | name+unit+values | 127 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Renal tubular epithelial cells [#/area] in Urine sediment by Light microscopy |
| 2090 | u-tub.ep |  | 94% | name | 2024 | 100 |  |  | Urine |  | Renal tubular epithelial cells in Urine sediment |
| 2091 | u-tubulep | u/field | 68% | name+unit+values | 123 | 0 | [0, 1, 1, 1, 1, 1, 1, 1, 2] |  | Urine |  | Renal tubular epithelial cells [#/area] in Urine sediment by Light microscopy |
| 2092 | u-tubulep |  | 32% | name | 58 | 100 |  |  | Urine |  | Renal tubular epithelial cells in Urine sediment |
| 2093 | u-ubg-o |  | 100% | name | 584 | 100 |  | U -Urobilinogeeni (kval) | Urine | Qualitative test (also semi-quantitative) | Urobilinogen [Presence] in Urine |
| 2094 | u-väliepi | u/field | 93% | name+unit+values | 194 | 0 | [0, 0, 0, 0, 1, 1, 1, 1, 2] |  | Urine |  | Transitional epithelial cells [#/area] in Urine sediment by Light microscopy |
| 2095 | u-väliepi |  | 7% | name | 15 | 100 |  |  | Urine |  | Transitional epithelial cells in Urine sediment |
| 2096 | u-välimep | u/field | 71% | name+unit+values | 200 | 0 | [1, 1, 1, 1, 1, 1, 1, 1, 2] |  | Urine |  | Transitional epithelial cells [#/area] in Urine sediment by Light microscopy |
| 2097 | u-välimep |  | 29% | name | 81 | 100 |  |  | Urine |  | Transitional epithelial cells in Urine sediment |
| 2098 | u-överg.ep | /sunf | 6% | name+unit+values | 124 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Transitional epithelial cells [#/area] in Urine sediment by Light microscopy |
| 2099 | u-överg.ep |  | 94% | name | 2027 | 100 |  |  | Urine |  | Transitional epithelial cells in Urine sediment |

