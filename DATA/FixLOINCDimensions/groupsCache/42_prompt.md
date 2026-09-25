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
Here is group 42.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000285 | Sodium [Moles/volume] in Blood | 1.000 | 129 |
| 3002079 | Sodium [Moles/time] in 24 hour Urine | 1.000 | 1217 |
| 3002190 | Sodium [Moles/volume] in Dialysis fluid | 1.000 |  |
| 3003181 | Sodium [Moles/volume] in Urine | 1.000 | 412 |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 1.000 | 5 |
| 3020410 | Lactate [Moles/volume] in Arterial plasma | 1.000 |  |
| 3022948 | Iron [Moles/volume] in Serum or Plasma | 1.000 | 140 |
| 3023103 | Potassium [Moles/volume] in Serum or Plasma | 1.000 | 3 |
| 3026910 | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 190 |
| 3036428 | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid | 1.000 |  |
| 3040491 | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | 1.000 |  |
| 3043706 | Sodium [Moles/volume] in Arterial blood | 1.000 |  |
| 3965350 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Plasma | 1.000 |  |
| 36306105 | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.983 |  |
| 3021337 | Troponin I.cardiac [Mass/volume] in Serum or Plasma | 0.983 | 113 |
| 3019800 | Troponin T.cardiac [Mass/volume] in Serum or Plasma | 0.980 | 291 |
| 1469828 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by High sensitivity method | 0.972 |  |
| 3008486 | Thyroxine (T4) free [Moles/volume] in Serum or Plasma | 0.970 | 133 |
| 3035509 | Tobramycin [Mass/volume] in Serum or Plasma | 0.967 | 1858 |
| 46235078 | Potassium [Moles/volume] in Serum, Plasma or Blood | 0.966 |  |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.965 |  |
| 3966146 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Serum or Plasma | 0.962 |  |
| 3033745 | Troponin I.cardiac [Mass/volume] in Blood | 0.962 |  |
| 3048529 | Troponin T.cardiac [Mass/volume] in Blood | 0.962 |  |
| 3026989 | Triiodothyronine (T3) Free [Moles/volume] in Serum or Plasma | 0.960 | 274 |
| 3002568 | Complement factor B [Mass/volume] in Serum or Plasma | 0.954 |  |
| 3018405 | Lactate [Moles/volume] in Arterial blood | 0.954 | 1277 |
| 40769783 | Troponin T.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.952 |  |
| 3014620 | Thyroxine (T4) [Moles/volume] in Serum or Plasma | 0.948 | 145 |
| 3009107 | Complement factor B [Mass/volume] in Body fluid | 0.943 |  |
| 3038702 | Sodium [Moles/volume] in Capillary blood | 0.943 |  |
| 3014485 | Sodium [Moles/volume] in 24 hour Urine | 0.942 | 1451 |
| 3015399 | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | 0.941 |  |
| 3004282 | Tumor necrosis factor.alpha [Mass/volume] in Serum or Plasma | 0.940 |  |
| 3008304 | Triiodothyronine (T3) [Moles/volume] in Serum or Plasma | 0.935 | 223 |
| 3002400 | Iron [Mass/volume] in Serum or Plasma | 0.934 |  |
| 3008607 | Semen analysis panel | 0.933 |  |
| 3019572 | Troponin T.cardiac [Mass/volume] in Venous blood | 0.930 |  |
| 3040086 | Sodium [Moles/volume] in Peritoneal dialysis fluid | 0.930 |  |
| 3023636 | Sodium [Moles/time] in 12 hour Urine | 0.930 |  |
| 3041697 | Sodium [Moles/time] in 1 hour Urine | 0.923 |  |
| 3008598 | Thyroxine (T4) free [Mass/volume] in Serum or Plasma | 0.921 |  |
| 3008007 | Sodium [Mass/time] in 24 hour Urine | 0.920 |  |
| 3000288 | Sodium/Potassium [Molar ratio] in Serum or Plasma | 0.920 |  |
| 3026925 | Triiodothyronine (T3) Free [Mass/volume] in Serum or Plasma | 0.915 |  |
| 3006638 | Tobramycin [Mass/volume] in Serum or Plasma --trough | 0.914 | 1537 |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.911 |  |
| 1469858 | Troponin T.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.909 |  |
| 3015574 | Sodium [Moles/time] in 6 hour Urine | 0.908 |  |
| 3029213 | Adenosine deaminase [Enzymatic activity/volume] in Pericardial fluid | 0.908 |  |
| 1617495 | Sodium [Moles/volume] in Dialysis fluid --1 hour specimen | 0.907 |  |
| 1469723 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.907 |  |
| 3965306 | Troponin T.cardiac [Mass/volume] in 6 hour Serum or Plasma | 0.907 |  |
| 40760495 | Sodium [Moles/volume] in 2 hour Urine | 0.904 |  |
| 42529232 | Thyroxine (T4) free [Moles/volume] in Serum or Plasma by Immunoassay | 0.904 |  |
| 3022392 | Complement factor Bb [Mass/volume] in Serum or Plasma | 0.904 |  |
| 3046569 | Transferrin receptor.soluble [Moles/volume] in Serum or Plasma | 0.901 |  |
| 3035963 | Corticotropin [Moles/volume] in Plasma | 0.901 | 816 |
| 40762087 | Sodium [Moles/time] in 18 hour Urine | 0.900 |  |
| 1617300 | Sodium [Moles/volume] in Dialysis fluid --2 hour specimen | 0.900 |  |
| 3033252 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal fluid | 0.899 |  |
| 42529255 | Triiodothyronine (T3) Free [Moles/volume] in Serum or Plasma by Immunoassay | 0.897 |  |
| 3027828 | Triiodothyronine (T3).reverse [Moles/volume] in Serum or Plasma | 0.897 | 1057 |
| 1616723 | Sodium [Moles/volume] in Dialysis fluid --4 hour specimen | 0.895 |  |
| 3035637 | Corticotropin [Mass/volume] in Plasma | 0.895 |  |
| 3039179 | Angiotensin converting enzyme [Enzymatic activity/volume] in Peritoneal fluid | 0.895 |  |
| 40760484 | Sodium [Moles/volume] in 12 hour Urine | 0.895 |  |
| 3029979 | Tobramycin [Moles/volume] in Serum or Plasma | 0.894 | 1858 |
| 3022810 | Sodium [Moles/volume] in Body fluid | 0.893 |  |
| 3004090 | Tobramycin [Mass/volume] in Serum or Plasma --peak | 0.893 | 1574 |
| 44816583 | Sodium [Moles/volume] in 4 hour Urine | 0.893 |  |
| 3005622 | Sodium [Moles/time] in 24 hour Stool | 0.892 |  |
| 3016991 | Thyroxine (T4) [Mass/volume] in Serum or Plasma | 0.889 |  |
| 3005491 | Lactate [Moles/volume] in Plasma venous | 0.888 | 1070 |
| 3034249 | Sodium [Moles/volume] in Urine collected for unspecified duration | 0.888 | 689 |
| 3041244 | Adenosine deaminase [Enzymatic activity/volume] in Synovial fluid | 0.888 |  |
| 3028465 | Gamma glutamyl transferase [Enzymatic activity/volume] in Body fluid | 0.888 |  |
| 3005456 | Potassium [Moles/volume] in Blood | 0.885 | 106 |
| 3041449 | Collagen crosslinked C-telopeptide [Mass/volume] in Serum or Plasma | 0.885 |  |
| 3010340 | Triiodothyronine (T3) [Mass/volume] in Serum or Plasma | 0.884 |  |
| 645187 | Iron [Measurement] in Serum or Plasma | 0.884 |  |
| 3014111 | Lactate [Moles/volume] in Serum or Plasma | 0.881 | 346 |
| 21494221 | Tobramycin free [Mass/volume] in Serum or Plasma | 0.880 |  |
| 3004526 | Tobramycin [Mass/volume] in Urine | 0.879 |  |
| 3037437 | Adenosine deaminase [Enzymatic activity/volume] in Body fluid | 0.879 |  |
| 3028515 | Gamma glutamyl transferase [Enzymatic activity/volume] in Urine | 0.879 |  |
| 3008985 | Tobramycin [Mass/volume] in Body fluid | 0.878 |  |
| 3047181 | Lactate [Moles/volume] in Blood | 0.877 | 475 |
| 3024920 | Potassium [Moles/volume] in Serum or Plasma --3rd specimen | 0.877 |  |
| 3032987 | Sodium [Moles/volume] corrected for glucose in Serum or Plasma | 0.875 |  |
| 42529254 | Triiodothyronine (T3) [Moles/volume] in Serum or Plasma by Immunoassay | 0.875 |  |
| 42529231 | Thyroxine (T4) [Moles/volume] in Serum or Plasma by Immunoassay | 0.874 |  |
| 3035561 | Lactate [Mass/volume] in Arterial blood | 0.872 |  |
| 37021379 | Sodium [Molar amount] in 24 hour Dialysis fluid | 0.871 |  |
| 36305238 | Potassium goal [Moles/volume] Serum or Plasma | 0.870 |  |
| 40762471 | Tobramycin [Mass/volume] in Serum or Plasma --post dialysis | 0.869 |  |
| 3013098 | Potassium [Moles/volume] in Specimen | 0.869 |  |
| 40761932 | Thyroxine (T4) free [Mass/volume] in Serum or Plasma --baseline | 0.868 |  |
| 3007603 | Complement factor P [Mass/volume] in Plasma | 0.867 |  |
| 3041354 | Potassium [Moles/volume] in Venous blood | 0.867 |  |
| 3026681 | Sodium [Moles/volume] in Specimen | 0.867 |  |
| 3010661 | Tobramycin [Mass/volume] in Serum or Plasma --trough post extended interval dosing | 0.867 |  |
| 3037883 | Thyroxine (T4).albumin bound [Mass/volume] in Serum or Plasma | 0.866 |  |
| 42868691 | Thyroxine (T4) free [Moles/volume] in Serum or Plasma by Dialysis | 0.866 | 1494 |
| 3027653 | Mycophenolate [Mass/volume] in Serum or Plasma | 0.865 |  |
| 3009299 | Lupus anticoagulant neutralization platelet [Time] in Platelet poor plasma by Coagulation assay | 0.864 | 811 |
| 3030860 | Tumor necrosis factor.alpha [Moles/volume] in Serum or Plasma | 0.864 |  |
| 3010307 | Gamma glutamyl transferase/Aspartate aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.864 |  |
| 3049714 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma | 0.863 |  |
| 3031579 | Sodium [Moles/volume] in Mixed venous blood | 0.863 |  |
| 3039651 | Potassium [Moles/volume] in Serum or Plasma --pre dialysis | 0.863 |  |
| 3046728 | Iron [Presence] in Serum or Plasma | 0.861 |  |
| 3024380 | Potassium [Moles/volume] in Serum or Plasma --2nd specimen | 0.860 |  |
| 3039189 | Lupus anticoagulant neutralization dilute phospholipid [Time] in Platelet poor plasma | 0.860 |  |
| 36659714 | Sodium [Moles/volume] in Urine from Fetus | 0.860 |  |
| 3010424 | Ferritin [Moles/volume] in Serum or Plasma | 0.859 |  |
| 3028271 | Lactate [Moles/volume] in Capillary blood | 0.859 |  |
| 40761934 | Triiodothyronine (T3) Free [Mass/volume] in Serum or Plasma --baseline | 0.858 |  |
| 3009960 | Adenosine deaminase [Enzymatic activity/volume] in Blood | 0.858 |  |
| 3028582 | Triiodothyronine (T3).true [Mass/volume] in Serum or Plasma | 0.858 |  |
| 1988875 | Tumor necrosis factor.alpha [Units/volume] in Serum or Plasma | 0.856 |  |
| 3035717 | Potassium [Moles/volume] in Dialysis fluid | 0.855 |  |
| 3043409 | Potassium [Moles/volume] in Arterial blood | 0.854 |  |
| 3008037 | Lactate [Moles/volume] in Venous blood | 0.854 |  |
| 3001838 | Sodium [Moles/volume] in Red Blood Cells | 0.853 |  |
| 3004789 | Transferrin [Mass/volume] in Serum or Plasma | 0.853 | 809 |
| 3006550 | Complement factor Ba [Mass/volume] in Serum or Plasma | 0.853 |  |
| 3034552 | Adenosine deaminase [Enzymatic activity/volume] in Cerebral spinal fluid | 0.852 |  |
| 44816586 | Sodium [Moles/volume] in Serum or Plasma --post dialysis | 0.852 |  |
| 3003701 | Tobramycin [Moles/volume] in Serum or Plasma --trough | 0.852 | 1537 |
| 3032971 | Troponin I.cardiac [Mass/volume] in Serum or Plasma by Detection limit <= 0.01 ng/mL | 0.852 | 449 |
| 3052649 | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma | 0.851 |  |
| 46235360 | Tumor necrosis factor receptor superfamily member 1A [Mass/volume] in Serum or Plasma | 0.848 |  |
| 3044738 | Sodium [Moles/volume] (Maximum value during study) in Serum or Plasma | 0.848 |  |
| 3011732 | Aspartate aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.848 |  |
| 40762116 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal dialysis fluid | 0.848 |  |
| 40757362 | Semen analysis fertility panel | 0.847 |  |
| 3040526 | Collagen crosslinked C-telopeptide [Moles/volume] in Serum or Plasma | 0.847 |  |
| 3021862 | Iron [Interpretation] in Serum or Plasma | 0.845 |  |
| 46236075 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma by Immunoassay | 0.843 |  |
| 3032491 | Iron [Mass/volume] in Serum or Plasma --1st specimen | 0.842 |  |
| 44816699 | Transferrin receptor.soluble/log Ferritin index [Mass Ratio] in Serum or Plasma | 0.841 |  |
| 3002903 | Transferrin [Moles/volume] in Serum or Plasma | 0.840 | 809 |
| 3052662 | Ceruloplasmin [Moles/volume] in Serum or Plasma | 0.839 |  |
| 3026621 | Complement factor H [Mass/volume] in Serum or Plasma | 0.838 |  |
| 3033042 | Sodium [Moles/volume] in Peritoneal fluid | 0.837 |  |
| 3031053 | Iron [Mass/volume] in Serum or Plasma --5th specimen | 0.833 |  |
| 3030573 | Phosphate [Moles/volume] in Dialysis fluid | 0.833 |  |
| 3022979 | Gamma glutamyl cysteine synthetase [Enzymatic activity/volume] in Serum | 0.833 |  |
| 3047091 | Lupus anticoagulant neutralization buffer [Time] in Platelet poor plasma by Coagulation assay | 0.833 |  |
| 3009991 | Angiotensin converting enzyme [Enzymatic activity/volume] in Cerebral spinal fluid | 0.831 |  |
| 3005949 | Lactate [Moles/volume] in Mixed venous blood | 0.830 |  |
| 3036335 | Angiotensin converting enzyme [Enzymatic activity/volume] in Blood | 0.830 | 1299 |
| 3004825 | Lactate [Moles/volume] in Body fluid | 0.829 |  |
| 3013721 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.829 | 19 |
| 3027184 | Lupus anticoagulant [Interpretation] in Platelet poor plasma | 0.829 |  |
| 3042943 | Fatty acid essential (C12-C22) panel - Serum or Plasma | 0.829 |  |
| 3034780 | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | 0.829 | 730 |
| 3045783 | Sodium and Potassium panel [Moles/volume] - Serum or Plasma | 0.826 |  |
| 1988486 | Tumor necrosis factor.alpha [Mass/volume] in Cerebral spinal fluid | 0.826 |  |
| 40758927 | Mycophenolate [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.825 |  |
| 647897 | Tumor necrosis factor.alpha [Measurement] in Serum or Plasma | 0.825 |  |
| 3965684 | Tumor necrosis factor ligand superfamily member 10 [Mass/volume] in Serum, Plasma or Blood | 0.825 |  |
| 3027627 | Lupus anticoagulant neutralization high phospholipid [Time] in Platelet poor plasma by Coagulation assay | 0.824 |  |
| 42870299 | PDGFRA gene exon 18 targeted mutation analysis in Blood or Tissue by Sequencing | 0.824 |  |
| 36304001 | Fatty acid omega-3 and omega-6 panel - Serum or Plasma | 0.824 |  |
| 21493666 | Mycophenolate acyl-glucuronide [Mass/volume] in Serum or Plasma | 0.824 |  |
| 40763074 | Corticotropin [Moles/volume] in Plasma --baseline | 0.822 |  |
| 3031076 | Corticotropin [Mass/volume] in Plasma --baseline | 0.822 |  |
| 3008152 | Bicarbonate [Moles/volume] in Arterial blood | 0.821 | 310 |
| 3026365 | Gamma glutamyl transferase [Enzymatic activity/volume] in Semen | 0.821 |  |
| 36032012 | Gamma glutamyl transferase [Enzymatic activity/volume] in DBS | 0.821 |  |
| 1259791 | Lupus anticoagulant aPTT screening panel - Platelet poor plasma by Coagulation assay | 0.819 |  |
| 3021398 | Gamma glutamyl transferase [Enzymatic activity/volume] in Amniotic fluid | 0.819 |  |
| 3031643 | Corticotropin [Mass/volume] in Plasma --3 AM specimen | 0.818 |  |
| 40761633 | Corticotropin [Moles/volume] in Plasma --10 AM specimen | 0.817 |  |
| 3021423 | Complement factor D [Mass/volume] in Serum or Plasma | 0.816 |  |
| 43055501 | Mycophenolate [Mass/volume] in Serum or Plasma --trough | 0.816 |  |
| 3013870 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma | 0.815 |  |
| 40761662 | Corticotropin [Moles/volume] in Plasma --2 PM specimen | 0.815 |  |
| 40761632 | Corticotropin [Mass/volume] in Plasma --10 AM specimen | 0.815 |  |
| 3022126 | Complement C3b [Mass/volume] in Serum or Plasma | 0.815 |  |
| 3049123 | Corticotropin [Mass/volume] in Plasma --12 AM specimen | 0.815 |  |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.815 | 16 |
| 40757623 | Alanine aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.815 |  |
| 3008721 | Complement factor I [Mass/volume] in Serum or Plasma | 0.814 |  |
| 3027206 | Corticotropin [Mass/volume] in Plasma by Radioimmunoassay (RIA) | 0.814 |  |
| 40761642 | Corticotropin [Moles/volume] in Plasma --12 AM specimen | 0.814 |  |
| 3037478 | Sodium/Potassium [Molar ratio] in Urine | 0.813 |  |
| 3031315 | Corticotropin [Mass/volume] in Plasma --3 PM specimen | 0.812 |  |
| 3007042 | Complement iC3 [Mass/volume] in Plasma | 0.812 |  |
| 3032992 | Corticotropin [Mass/volume] in Plasma --6 PM specimen | 0.812 |  |
| 3052673 | Corticotropin [Mass/volume] in Plasma --4 AM specimen | 0.811 |  |
| 3008440 | Collagen crosslinked N-telopeptide [Moles/volume] in Serum | 0.811 |  |
| 40761643 | Corticotropin [Moles/volume] in Plasma --12 PM specimen | 0.810 |  |
| 40761635 | Corticotropin [Moles/volume] in Plasma --10 PM specimen | 0.810 |  |
| 43533705 | Mycophenolate [Mass/volume] in Serum or Plasma --peak | 0.809 |  |
| 40761703 | Corticotropin [Moles/volume] in Plasma --4 AM specimen | 0.808 |  |
| 40761710 | Corticotropin [Moles/volume] in Plasma --6 PM specimen | 0.808 |  |
| 40757296 | Tumor necrosis factor binding protein [Units/volume] in Serum | 0.807 |  |
| 648872 | Transferrin [Measurement] in Serum or Plasma | 0.807 |  |
| 3049183 | Collagen crosslinked C-telopeptide [Mass/volume] in Urine | 0.806 |  |
| 3046505 | Aldolase [Enzymatic activity/volume] in Pleural fluid | 0.803 |  |
| 3036489 | Thrombin time | 0.802 | 705 |
| 42868685 | Mycophenolate [Moles/volume] in Serum or Plasma | 0.802 | 1787 |
| 3005757 | Coagulation factor V activity actual/normal in Platelet poor plasma by Coagulation assay | 0.801 | 1703 |
| 3005445 | Coagulation factor X activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.799 |  |
| 3052628 | Collagen type 1 Ab [Units/volume] in Serum | 0.798 |  |
| 44816885 | Collagen crosslinked C-telopeptide [Z-score] in Serum or Plasma | 0.797 |  |
| 42869547 | Procollagen type III.N-terminal propeptide [Mass/volume] in Serum | 0.797 |  |
| 1175721 | Fatty acid omega-3 and omega-6 panel - Blood | 0.796 |  |
| 3043430 | Interleukin 1 alpha [Mass/volume] in Serum or Plasma | 0.795 |  |
| 3006924 | Coagulation factor V activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.795 |  |
| 3015401 | Amylase [Enzymatic activity/volume] in Pleural fluid | 0.794 |  |
| 3021530 | Procollagen type I [Mass/volume] in Serum | 0.791 |  |
| 3004409 | Coagulation factor X activity actual/normal in Platelet poor plasma by Coagulation assay | 0.789 | 1896 |
| 3023017 | Iron/Transferrin [Mass Ratio] in Serum or Plasma | 0.788 |  |
| 40758907 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of platelet lysate | 0.786 |  |
| 3014391 | Thrombin time [Interpretation] in Blood by Coagulation assay | 0.785 | 1113 |
| 1091858 | Prothrombin time (PT) factor substitution [Time Ratio] in Control Platelet poor plasma by Coagulation assay --2H post incubation with 1:1 normal plasma | 0.785 |  |
| 3003308 | Coagulation factor X activity [Units/volume] in Platelet poor plasma by Chromogenic method | 0.785 |  |
| 40758928 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.784 |  |
| 3036953 | Sodium/Potassium [Molar ratio] in Sweat | 0.784 |  |
| 3038697 | Lupus anticoagulant neutralization platelet [Presence] in Platelet poor plasma by Coagulation assay | 0.783 |  |
| 3964861 | Semen and urine analysis fertility panel - Specimen | 0.781 |  |
| 44786996 | Sodium and Potassium panel [Moles/volume] - Blood | 0.780 |  |
| 40758906 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of saline | 0.779 |  |
| 3044051 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of normal plasma | 0.777 |  |
| 40763571 | Iron/Transferrin [Ratio] in Serum or Plasma | 0.777 |  |
| 3047891 | FGFR2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.777 |  |
| 3030959 | Coagulation factor X activity actual/normal in Platelet poor plasma by Chromogenic method | 0.776 | 1526 |
| 3001122 | Ferritin [Mass/volume] in Serum or Plasma | 0.775 | 153 |
| 1469583 | PDGFRA gene full mutation analysis [Presence] in Blood or Tissue by Sequencing | 0.775 |  |
| 3005080 | Thrombin time in Platelet poor plasma from Control by Coagulation assay | 0.773 |  |
| 3046935 | Sodium/Potassium [Molar ratio] in 24 hour Urine | 0.771 |  |
| 3026785 | Coagulation factor VII activity actual/normal [Molar ratio] in Platelet poor plasma by Coagulation assay | 0.770 |  |
| 648623 | Mycophenolate [Measurement] in Serum or Plasma | 0.768 |  |
| 3005075 | Coagulation factor X+Acarboxy Ag actual/normal in Platelet poor plasma by Immunoassay | 0.768 |  |
| 3021749 | Alpha thymosin [Mass/volume] in Serum | 0.766 |  |
| 3019794 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --post therapy | 0.762 |  |
| 1988420 | Gas and electrolytes panel - Arterial blood | 0.760 |  |
| 3023945 | Coagulation factor V Ag actual/normal in Platelet poor plasma by Immunoassay | 0.760 |  |
| 46235736 | Interleukin 2 Receptor Soluble [Mass/volume] in Serum or Plasma | 0.760 |  |
| 3044378 | FEV1 --10 minutes post exercise | 0.758 |  |
| 3046526 | FEV1 --5 minutes post exercise | 0.758 |  |
| 3029242 | Protein C/Coagulation factor X [Mass Ratio] in Platelet poor plasma | 0.757 |  |
| 3016005 | Antithrombin Ag [Mass/volume] in Platelet poor plasma by Immunoassay | 0.755 |  |
| 3002907 | Coagulation factor XII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.755 |  |
| 3045669 | Fatty acid comprehensive (C8-C26) panel - Serum or Plasma | 0.754 |  |
| 3011482 | Spermatozoa motility and count panel | 0.754 |  |
| 3027396 | Coagulation factor V Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.753 |  |
| 40758360 | Electrolytes panel - Blood | 0.753 |  |
| 21493512 | Coagulation factor X activated inhibitor [Mass/volume] in Platelet poor plasma | 0.753 |  |
| 3020783 | Coagulation factor X Ag actual/normal in Platelet poor plasma by Immunoassay | 0.752 |  |
| 42870499 | Thrombin time actual/Normal | 0.752 | 3000 |
| 3046362 | FEV1 --15 minutes post exercise | 0.752 |  |
| 3021008 | Coagulation factor X+Acarboxy Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.751 |  |
| 646647 | Antithrombin Ag [Measurement] in Platelet poor plasma | 0.750 |  |
| 3025317 | Coagulation factor VII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.749 |  |
| 3000515 | Antithrombin actual/normal in Platelet poor plasma by Chromogenic method | 0.749 | 760 |
| 1259553 | PDGFRA gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.748 |  |
| 3008009 | Antithrombin Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.747 | 1553 |
| 3024402 | Coagulation factor VII+Acarboxy Ag activity actual/normal in Platelet poor plasma by Immunoassay | 0.746 |  |
| 3030682 | Semen analysis post vasectomy panel | 0.746 |  |
| 3003771 | Antithrombin Ag actual/normal in Platelet poor plasma by Immunoassay | 0.745 |  |
| 3011547 | Coagulation factor VII activity actual/normal in Platelet poor plasma by Coagulation assay | 0.744 | 1752 |
| 3026798 | Calcium/Sodium [Mass Ratio] in Serum or Plasma | 0.742 |  |
| 44816654 | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum | 0.742 |  |
| 3040469 | Prothrombin Ab [Units/volume] in Serum or Plasma | 0.742 |  |
| 3001036 | Coagulation factor VII+Coagulation factor X actual/normal in Platelet poor plasma by Coagulation assay | 0.741 |  |
| 3022519 | Antithrombin [Interpretation] in Platelet poor plasma | 0.741 | 1117 |
| 3005470 | Maximum expiratory gas flow Respiratory system airway --post therapy | 0.741 |  |
| 3004057 | Coagulation factor V inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.741 |  |
| 3018676 | Antithrombin [Units/volume] in Platelet poor plasma by Chromogenic method | 0.741 | 1235 |
| 3038563 | Respiratory rate --post exercise | 0.737 |  |
| 42868409 | Thrombin time.high dose in Platelet poor plasma by Coagulation assay | 0.737 |  |
| 21492381 | Fatty acid comprehensive (C8-C26) panel - Red Blood Cells | 0.735 |  |
| 3050511 | FGFR3 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.735 |  |
| 3008336 | Mefenamate [Mass/volume] in Serum or Plasma | 0.734 |  |
| 3015449 | Antithrombin Ag [Moles/volume] in Platelet poor plasma by Immunoassay | 0.731 |  |
| 3008561 | Activated protein C resistance [Time Ratio] in Platelet poor plasma by Coagulation assay | 0.731 | 797 |
| 3049875 | Spermatozoa morphology panel | 0.730 |  |
| 3044232 | FGD1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.729 |  |
| 3046082 | Antithrombin Ag [Presence] in Platelet poor plasma by Immunoassay | 0.727 |  |
| 3009101 | Plasminogen activator urokinase type [Units/volume] in Platelet poor plasma | 0.726 |  |
| 40758222 | PDGFRA gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.725 |  |
| 3014914 | Antithrombin [Moles/volume] in Platelet poor plasma by Chromogenic method | 0.725 |  |
| 3041133 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay --baseline | 0.725 |  |
| 3048498 | TGFBR2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.724 |  |
| 3037666 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay | 0.724 |  |
| 42868465 | Maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.724 |  |
| 3033891 | Prothrombin time (PT) in Platelet poor plasma from Control by Coagulation assay | 0.723 |  |
| 46237012 | PDGFRA gene p.Asp842Val [Presence] in Blood or Tissue by Molecular genetics method | 0.721 |  |
| 3015029 | Plasminogen activator urokinase type [Units/volume] in Urine | 0.721 |  |
| 3031730 | PTPN11 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.720 |  |
| 3040175 | Thrombin time.factor substitution immediately after addition of XXX in Platelet poor plasma by Coagulation assay | 0.719 |  |
| 3049710 | Thrombin time.factor substitution immediately after addition of bovine thrombin in Platelet poor plasma by Coagulation assay | 0.717 |  |
| 3965213 | Electrolytes panel - Venous blood | 0.716 |  |
| 42869550 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --pre therapy | 0.716 |  |
| 40757350 | Thrombin time.factor substitution immediately after 1:4 addition of normal plasma in Platelet poor plasma by Coagulation assay | 0.716 |  |
| 3045930 | Fatty acid mitochondrial (C8-C18) panel - Serum or Plasma | 0.716 |  |
| 42868467 | Maximum expiratory gas flow/Predicted maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.715 |  |
| 3043980 | Thrombin time.factor substitution immediately after addition of normal plasma in Platelet poor plasma by Coagulation assay | 0.715 |  |
| 3050160 | 3-Hydroxy fatty acid panel - Serum or Plasma | 0.715 |  |
| 3046589 | Prothrombin time (PT) factor substitution 2H post incubation with 1:4 normal plasma in Platelet poor plasma by Coagulation assay | 0.713 |  |
| 3046008 | Thrombin time.factor substitution immediately after addition of protamine sulfate in Platelet poor plasma by Coagulation assay | 0.713 | 1069 |
| 3043450 | Prothrombin time (PT) factor substitution 1H post incubation with 1:4 normal plasma in Platelet poor plasma by Coagulation assay | 0.713 |  |
| 3033658 | Prothrombin time (PT) actual/Normal | 0.711 | 3000 |
| 3023329 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter | 0.711 |  |
| 36032060 | Prothrombin time (PT) factor substitution 1H post incubation with 1:1 normal plasma in Platelet poor plasma by Coagulation assay | 0.710 |  |
| 3046729 | Fatty acid very long chain (C22-C26) panel - Serum or Plasma | 0.708 |  |
| 36303453 | Omega-3 (EPA+DHA) index in Serum or Plasma | 0.706 |  |
| 21493444 | Maximum expiratory pressure Respiratory system --post bronchodilation | 0.705 |  |
| 1616827 | Angiopoietin receptor 2 [Mass/volume] in Serum or Plasma | 0.704 |  |
| 21490868 | Fatty acid oxidation panel - Fibroblast | 0.700 |  |
| 3047332 | Spermatozoa IgA and IgG and IgM panel - Serum | 0.699 |  |
| 36659643 | Aldosterone and sodium panel - 24 hour Urine | 0.697 |  |
| 40757584 | Semen analysis test method | 0.693 |  |
| 3027995 | Electrolytes 1998 panel - Serum or Plasma | 0.691 |  |
| 3024976 | Plasminogen Ag [Mass/volume] in Platelet poor plasma | 0.690 |  |
| 21491705 | Aldosterone and renin concentration panel - Plasma | 0.689 |  |
| 21492677 | Synovial fluid analysis panel - Synovial fluid | 0.688 |  |
| 3045149 | Reason for lab test in Semen | 0.687 |  |
| 3037122 | Plasminogen activator tissue type-Plasminogen activator inhibitor 1 complex [Mass/volume] in Platelet poor plasma by Immunoassay | 0.685 |  |
| 40758281 | Aldosterone and renin activity panel - Plasma | 0.682 |  |
| 3009608 | Thromboglobulin [Mass/volume] in Plasma | 0.682 |  |
| 40759048 | Interleukin 1 receptor alpha chain soluble [Mass/volume] in Serum or Plasma | 0.681 |  |
| 646557 | Potassium [Measurement] in Serum or Plasma | 0.680 |  |
| 42528497 | Personal best peak expiratory gas flow Respiratory system airway | 0.671 |  |
| 3031723 | Peak flow measure duration Respiratory system airway by Peak flow meter | 0.671 |  |
| 42868463 | Maximum expiratory gas flow Respiratory system airway Predicted | 0.669 |  |
| 40765359 | PhenX - respiratory - peak expiratory flow rate - PEFR protocol 090801 | 0.662 |  |
| 42868466 | Maximum expiratory gas flow/Predicted maximum expiratory gas flow Respiratory system airway --pre bronchodilation | 0.659 |  |
| 42868464 | Maximum expiratory gas flow Respiratory system airway --pre bronchodilation | 0.644 |  |
| 21490559 | Maximum expiratory gas flow Respiratory system airway --on ventilator | 0.637 |  |
| 3043729 | Maximum expiratory gas flow Respiratory system airway | 0.636 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 339 | ab-na | mmol/l | 100% | name+unit+values | 1125 | 0 | [130.94, 134.84, 136.62, 138.04, 139.34, 140.42, 141.09, 142.57, 144.87] |  | Arterial blood | Native preparation | Sodium [Moles/volume] in Arterial blood |
| 340 | ap-lakt | mmol/l | 99% | name+unit+values | 1456 | 0 | [0.68, 0.81, 0.96, 1.1, 1.28, 1.5, 1.81, 2.29, 3.25] |  |  |  | Lactate [Moles/volume] in Arterial plasma |
| 341 | ap-lakt |  | 1% | name | 18 | 50 |  |  |  |  | Lactate [Moles/volume] in Arterial plasma |
| 342 | ap-na | % | 0% | name+unit | 24 | 0 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma |
| 343 | ap-na | g/l | 0% | name+unit | 6 | 0 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma |
| 344 | ap-na | kpa | 0% | name+unit | 12 | 0 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma |
| 345 | ap-na | mmol/l | 99% | name+unit+values | 50270 | 0 | [130.71, 133.37, 134.96, 136, 136.98, 137.95, 138.88, 139.98, 141.72] |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma |
| 346 | ap-na | °c | 0% | name+unit | 6 | 0 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma |
| 347 | ap-na |  | 0% | name | 233 | 92.27 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma |
| 348 | ap-nak |  | 100% | name | 155 | 100 |  |  |  |  | Sodium and Potassium panel - Arterial plasma |
| 349 | b-na | mmol/l | 86% | name+unit+values | 59360 | 0 | [132.76, 134.99, 136.51, 137.61, 138.41, 139.21, 140.23, 141.69, 144.08] |  | Blood | Native preparation | Sodium [Moles/volume] in Blood |
| 350 | b-na |  | 14% | name+values | 9740 | 95.39 | [132.18, 135.78, 137.16, 138.83, 139, 140, 140.41, 141, 142] |  | Blood | Native preparation | Sodium [Moles/volume] in Blood |
| 351 | cp-na | mmol/l | 94% | name+unit+values | 305 | 0 | [132, 134.22, 135.76, 137, 138, 139.28, 140, 141.93, 143] |  |  | Native preparation | Sodium [Moles/volume] in Capillary plasma |
| 352 | cp-na |  | 6% | name | 18 | 100 |  |  |  | Native preparation | Sodium [Moles/volume] in Capillary plasma |
| 353 | di-na | mmol/l | 98% | name+unit | 307 | 0 |  | Di-Natrium | Dialysis fluid | Native preparation | Sodium [Moles/volume] in Dialysis fluid |
| 354 | di-na |  | 2% | name | 5 | 100 |  | Di-Natrium | Dialysis fluid | Native preparation | Sodium [Moles/volume] in Dialysis fluid |
| 355 | du-na | mmol | 72% | name+unit+values | 2785 | 0.25 | [76.79, 98.05, 115.16, 132.8, 151.88, 170.12, 193.55, 223.43, 273.21] | dU-Natrium | 24-hour urine | Native preparation | Sodium [Moles/time] in 24 hour Urine |
| 356 | du-na | mmol/24h | 2% | name+unit | 60 | 0 |  | dU-Natrium | 24-hour urine | Native preparation | Sodium [Moles/time] in 24 hour Urine |
| 357 | du-na |  | 26% | name+values | 1021 | 70.23 | [65.53, 84.3, 103.25, 116.92, 139.24, 156.61, 172.58, 210.59, 273.58] | dU-Natrium | 24-hour urine | Native preparation | Sodium [Moles/time] in 24 hour Urine |
| 358 | fp-ctx | ng/l | 2% | name+unit | 34 | 0 |  |  | Fasting plasma |  | Collagen type I C-terminal telopeptide [Mass/volume] in Serum or Plasma |
| 359 | fp-ctx | ug/l | 71% | name+unit+values | 1281 | 0 | [0.09, 0.14, 0.2, 0.25, 0.3, 0.38, 0.48, 0.6, 0.81] |  | Fasting plasma |  | Collagen type I C-terminal telopeptide [Mass/volume] in Serum or Plasma |
| 360 | fp-ctx |  | 27% | name+values | 491 | 16.7 | [0.12, 0.19, 0.24, 0.31, 0.39, 0.48, 0.58, 0.71, 1] |  | Fasting plasma |  | Collagen type I C-terminal telopeptide [Mass/volume] in Serum or Plasma |
| 361 | fp-gt | u/l | 99% | name+unit+values | 772 | 0 | [15.6, 19.58, 23.9, 27.61, 33.27, 39.92, 49.93, 68.82, 104.64] |  | Fasting plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma |
| 362 | fp-gt |  | 1% | name | 11 | 0 |  |  | Fasting plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma |
| 363 | fp-na | mmol/l | 100% | name+unit+values | 6047 | 0 | [135.6, 137.84, 139, 139.97, 140.01, 141, 141.04, 142, 143] |  | Fasting plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma |
| 364 | fp-na |  | 0% | name | 18 | 11.11 |  |  | Fasting plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma |
| 365 | p-acth | ng/l | 87% | name+unit+values | 10045 | 0.42 | [8.08, 11.12, 14.1, 17.14, 20.58, 24.79, 30.92, 40.41, 66.95] | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone [Mass/volume] in Plasma |
| 366 | p-acth | pmol/l | 0% | name+unit | 7 | 0 |  | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone [Moles/volume] in Plasma |
| 367 | p-acth |  | 13% | name+values | 1461 | 80.01 | [9.26, 12.21, 15.18, 18.04, 23.17, 27.09, 32.96, 40.36, 61.68] | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone [Mass/volume] in Plasma |
| 368 | p-at3 | % | 98% | name+unit+values | 33387 | 0.01 | [54.15, 67.47, 77.12, 84.9, 91.44, 97.34, 103.31, 110.17, 119.77] | P -Antitrombiini III | Plasma |  | Antithrombin III activity [Ratio] in Plasma |
| 369 | p-at3 | form | 0% | name+unit | 18 | 0 |  | P -Antitrombiini III | Plasma |  | Antithrombin III activity [Ratio] in Plasma |
| 370 | p-at3 |  | 2% | name+values | 750 | 50.4 | [77.41, 88.27, 92.93, 97.96, 101.75, 106.37, 110.41, 114.53, 119.94] | P -Antitrombiini III | Plasma |  | Antithrombin III activity [Ratio] in Plasma |
| 371 | p-at3. | % | 95% | name+unit+values | 4852 | 0 | [82.58, 90.63, 95.72, 100.18, 103.97, 107.65, 111.95, 117.06, 124.39] |  | Plasma |  | Antithrombin III activity [Ratio] in Plasma |
| 372 | p-at3. |  | 5% | name+values | 269 | 20.45 | [87.63, 92.63, 97.23, 100.8, 104.86, 109.03, 113.28, 117.74, 123.49] |  | Plasma |  | Antithrombin III activity [Ratio] in Plasma |
| 373 | p-efa | form | 4% | name+unit | 5 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  | Essential fatty acids panel - Plasma |
| 374 | p-efa |  | 96% | name | 125 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  | Essential fatty acids panel - Plasma |
| 375 | p-fakb | g/l | 77% | name+unit+values | 120 | 0 | [0.14, 0.17, 0.18, 0.2, 0.21, 0.21, 0.23, 0.26, 0.3] | P -Faktori B | Plasma |  | Complement factor B [Mass/volume] in Plasma |
| 376 | p-fakb |  | 23% | name | 35 | 25.71 |  | P -Faktori B | Plasma |  | Complement factor B [Mass/volume] in Plasma |
| 377 | p-fe | umol/l | 79% | name+unit+values | 2840 | 0 | [5.52, 7.66, 9.48, 11.25, 13.18, 14.87, 16.94, 19.46, 23.35] |  | Plasma |  | Iron [Moles/volume] in Serum or Plasma |
| 378 | p-fe |  | 21% | name+values | 740 | 33.92 | [5.15, 6.78, 8.55, 10.06, 12.18, 14.07, 16.43, 19.54, 23.49] |  | Plasma |  | Iron [Moles/volume] in Serum or Plasma |
| 379 | p-fs | s | 17% | name+unit+values | 319 | 0 | [28, 29.31, 30.81, 32, 33.17, 35, 36.48, 39.22, 45.08] |  | Plasma |  | Thrombin time [Time] in Plasma |
| 380 | p-fs |  | 83% | name | 1586 | 99.87 |  |  | Plasma |  | Thrombin time [Time] in Plasma |
| 381 | p-fv | % | 96% | name+unit+values | 6911 | 0.01 | [43.78, 58.4, 69.62, 80.37, 90.29, 99.93, 110.48, 122.94, 139.52] | P -Hyytymistekijä V | Plasma |  | Coagulation factor V activity [Ratio] in Plasma |
| 382 | p-fv |  | 4% | name+values | 261 | 40.23 | [68.7, 79.64, 87.53, 94.6, 99.14, 104.6, 110.72, 119.21, 132.72] | P -Hyytymistekijä V | Plasma |  | Coagulation factor V activity [Ratio] in Plasma |
| 383 | p-fx | % | 49% | name+unit+values | 916 | 0.11 | [46.06, 65.75, 76.36, 83.72, 90.83, 97.78, 104.84, 112.37, 122.61] | P -Hyytymistekijä X | Plasma |  | Coagulation factor X activity [Ratio] in Plasma |
| 384 | p-fx |  | 51% | name+values | 949 | 87.46 | [66, 76.45, 83.38, 90.43, 96, 100.47, 108.88, 114, 128] | P -Hyytymistekijä X | Plasma |  | Coagulation factor X activity [Ratio] in Plasma |
| 385 | p-gt | mg/ml | 0% | name+unit | 8 | 0 |  | P -Glutamyylitransferaasi | Plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma |
| 386 | p-gt | u/l | 98% | name+unit+values | 820178 | 0.02 | [14.56, 18.66, 23.05, 28.6, 36.08, 47.26, 65.76, 101.29, 195.48] | P -Glutamyylitransferaasi | Plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma |
| 387 | p-gt |  | 2% | name+values | 15977 | 100 | [15.82, 20.13, 24.14, 29.03, 35.14, 45.13, 63.31, 89.78, 161.64] | P -Glutamyylitransferaasi | Plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma |
| 388 | p-hstni | ng/l | 100% | name+unit+values | 3261 | 0 | [1, 2, 3, 4.12, 6.04, 9.1, 14.48, 27.09, 65.46] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma by High sensitivity method |
| 389 | p-k+na |  | 100% | name | 69230 | 100 |  |  | Plasma |  | Potassium and Sodium panel - Plasma |
| 390 | p-k,na |  | 100% | name | 2518 | 100 |  |  | Plasma |  | Potassium and Sodium panel - Plasma |
| 391 | p-k-na | mmol/l | 76% | name+unit | 594 | 100 |  |  | Plasma | Native preparation | Potassium and Sodium panel - Plasma |
| 392 | p-k-na |  | 24% | name | 186 | 100 |  |  | Plasma | Native preparation | Potassium and Sodium panel - Plasma |
| 393 | p-k-pa | mmol/l | 100% | name+unit+values | 197 | 0 | [3.53, 3.78, 3.9, 4, 4.04, 4.13, 4.3, 4.38, 4.56] |  | Plasma | Long-term / prolonged | Potassium [Moles/volume] in Serum or Plasma |
| 394 | p-k/na |  | 100% | name | 321 | 100 |  |  | Plasma |  | Potassium/Sodium [Molar ratio] in Plasma |
| 395 | p-ked. | mmol/l | 100% | name+unit | 344 | 0 |  |  | Plasma |  |  |
| 396 | p-kjd. | mmol/l | 100% | name+unit | 160 | 0 |  |  | Plasma |  |  |
| 397 | p-la1 | s | 95% | name+unit+values | 1064 | 0 | [30, 31.95, 33.1, 34.81, 35.99, 37.75, 39.96, 44.96, 54.77] |  | Plasma |  | Lupus anticoagulant screen [Time] in Platelet poor plasma |
| 398 | p-la1 |  | 5% | name | 52 | 50 |  |  | Plasma |  | Lupus anticoagulant screen [Time] in Platelet poor plasma |
| 399 | p-la2 | s | 26% | name+unit+values | 498 | 0 | [32, 33.41, 35.41, 36.98, 38.82, 40.9, 43.06, 47.24, 53.65] |  | Plasma |  | Lupus anticoagulant confirm [Time] in Platelet poor plasma |
| 400 | p-la2 |  | 74% | name | 1411 | 99.43 |  |  | Plasma |  | Lupus anticoagulant confirm [Time] in Platelet poor plasma |
| 401 | p-mypa | mg/l | 87% | name+unit+values | 1692 | 0.06 | [0.64, 0.99, 1.33, 1.7, 2.12, 2.67, 3.43, 4.39, 6.28] | P -Mykofenolihappo | Plasma |  | Mycophenolic acid [Mass/volume] in Plasma |
| 402 | p-mypa |  | 13% | name | 245 | 76.33 |  | P -Mykofenolihappo | Plasma |  | Mycophenolic acid [Mass/volume] in Plasma |
| 403 | p-na | mmol/ | 0% | name+unit | 14 | 0 |  | P -Natrium | Plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma |
| 404 | p-na | mmol/l | 99% | name+unit+values | 7320578 | 0.03 | [133.91, 136.27, 137.98, 138.99, 139.95, 140, 141, 142, 143] | P -Natrium | Plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma |
| 405 | p-na |  | 1% | name+values | 81059 | 100 | [134.02, 137.07, 138.67, 139, 140, 141, 142, 142.8, 143] | P -Natrium | Plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma |
| 406 | p-na. | mmol/l | 100% | name+unit+values | 1467 | 0 | [134.64, 136.99, 138.3, 139.9, 140.54, 141, 142, 142.75, 144] |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma |
| 407 | p-na: | mmol/l | 100% | name+unit+values | 621 | 0 | [131.65, 133.8, 135, 136.23, 137.85, 138.61, 139.67, 140.88, 142] |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma |
| 408 | p-naed. | mmol/l | 100% | name+unit | 306 | 0 |  |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma |
| 409 | p-najd. | mmol/l | 100% | name+unit | 154 | 0 |  |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma |
| 410 | p-nak |  | 100% | name | 259040 | 100 |  |  | Plasma |  | Potassium and Sodium panel - Plasma |
| 411 | p-nap | mmol/l | 100% | name+unit+values | 342 | 0 | [132.69, 135.3, 137.47, 139, 140, 140.64, 142, 143, 145] |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma |
| 412 | p-supar | ug/l | 96% | name+unit+values | 351 | 0 | [2.87, 3.25, 3.63, 3.92, 4.33, 4.73, 5.27, 6.37, 8.21] |  | Plasma |  | Soluble urokinase plasminogen activator receptor [Mass/volume] in Plasma |
| 413 | p-supar |  | 4% | name | 16 | 100 |  |  | Plasma |  | Soluble urokinase plasminogen activator receptor [Mass/volume] in Plasma |
| 414 | p-t3-v | pmol/l | 99% | name+unit+values | 82081 | 0.04 | [3.46, 3.84, 4.11, 4.35, 4.57, 4.81, 5.08, 5.46, 6.26] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated | Triiodothyronine (T3).free [Moles/volume] in Serum or Plasma |
| 415 | p-t3-v |  | 1% | name+values | 921 | 100 | [3.47, 3.87, 4.08, 4.31, 4.53, 4.77, 5.02, 5.39, 6.24] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated | Triiodothyronine (T3).free [Moles/volume] in Serum or Plasma |
| 416 | p-t4-v | pmol/l | 98% | name+unit+values | 1108128 | 0.01 | [11.98, 13.02, 13.95, 14.63, 15.23, 16.03, 16.92, 17.94, 19.56] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated | Thyroxine (T4).free [Moles/volume] in Serum or Plasma |
| 417 | p-t4-v |  | 2% | name+values | 19446 | 100 | [12, 13.8, 14.44, 15.06, 16, 16.21, 16.99, 17.6, 19] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated | Thyroxine (T4).free [Moles/volume] in Serum or Plasma |
| 418 | p-t4v | pmol/l | 96% | name+unit+values | 110881 | 0 | [12.73, 13.79, 14.57, 15.27, 15.96, 16.68, 17.48, 18.48, 19.99] |  | Plasma |  | Thyroxine (T4).free [Moles/volume] in Serum or Plasma |
| 419 | p-t4v |  | 4% | name+values | 4743 | 100 | [12.19, 13.39, 14.21, 14.93, 15.61, 16.33, 17.17, 18.29, 20.03] |  | Plasma |  | Thyroxine (T4).free [Moles/volume] in Serum or Plasma |
| 420 | p-tfr | mg/l | 92% | name+unit+values | 188406 | 0.02 | [0.81, 1.28, 2.05, 2.5, 2.87, 3.3, 3.83, 4.64, 6.21] | P -Transferriinireseptori, liukoinen | Plasma |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 421 | p-tfr |  | 8% | name+values | 15951 | 100 | [2.12, 2.53, 2.87, 3.21, 3.63, 4.15, 4.81, 5.75, 7.59] | P -Transferriinireseptori, liukoinen | Plasma |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 422 | p-tni | ng/l | 70% | name+unit+values | 220095 | 0 | [4, 5.13, 7.13, 10.22, 15.11, 24.46, 46.82, 122.37, 829.48] | P -Troponiini I | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma |
| 423 | p-tni | ug/l | 8% | name+unit+values | 25579 | 0 | [0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.08, 0.16, 0.78] | P -Troponiini I | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma |
| 424 | p-tni |  | 22% | name+values | 70910 | 100 | [0.05, 0.22, 2.89, 4.65, 7.45, 12.28, 24.91, 48.92, 145.81] | P -Troponiini I | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma |
| 425 | p-tni. | ng/l | 3% | name+unit | 6 | 0 |  |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma |
| 426 | p-tni. | ug/l | 82% | name+unit+values | 155 | 0 | [0, 0, 0, 0, 0, 0, 0.01, 0.02, 0.06] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma |
| 427 | p-tni. |  | 15% | name | 28 | 100 |  |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma |
| 428 | p-tnih | ng/l | 82% | name+unit+values | 1974 | 0 | [4, 5.78, 7.89, 10.8, 16.52, 27.69, 54.92, 168.16, 1593.63] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma by High sensitivity method |
| 429 | p-tnih |  | 18% | name | 440 | 100 |  |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma by High sensitivity method |
| 430 | p-tnl | ng/l | 37% | name+unit+values | 124 | 0 | [3, 4, 5.16, 7, 10, 12.72, 29.97, 89.8, 240.6] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma |
| 431 | p-tnl | ug/l | 53% | name+unit+values | 179 | 0 | [0, 0, 0, 0, 0, 0.01, 0.01, 0.02, 0.05] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma |
| 432 | p-tnl |  | 11% | name | 36 | 100 |  |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Plasma |
| 433 | p-tnt | ng/l | 84% | name+unit+values | 437584 | 0.96 | [6.97, 9.13, 11.78, 15.03, 19.12, 24.8, 33.92, 51.22, 106.22] | P -Troponiini T | Plasma |  | Troponin T.cardiac [Mass/volume] in Plasma |
| 434 | p-tnt | ug/l | 0% | name+unit | 76 | 0 |  | P -Troponiini T | Plasma |  | Troponin T.cardiac [Mass/volume] in Plasma |
| 435 | p-tnt |  | 15% | name+values | 80220 | 100 | [6.97, 8.93, 11.46, 14.61, 18.09, 22.79, 29.94, 42.37, 74.82] | P -Troponiini T | Plasma |  | Troponin T.cardiac [Mass/volume] in Plasma |
| 436 | p-tt | % | 99% | name+unit+values | 472003 | 0.01 | [50.44, 65.04, 74.28, 81.62, 88.26, 94.73, 101.62, 109.77, 121.26] | P -Tromboplastiiniaika | Plasma |  | Prothrombin time [Ratio] in Plasma |
| 437 | p-tt | form | 0% | name+unit | 20 | 0 |  | P -Tromboplastiiniaika | Plasma |  | Prothrombin time [Ratio] in Plasma |
| 438 | p-tt |  | 1% | name+values | 4462 | 100 | [41.42, 56.72, 66.85, 77.09, 85.82, 93.79, 102.07, 112.01, 126.16] | P -Tromboplastiiniaika | Plasma |  | Prothrombin time [Ratio] in Plasma |
| 439 | p-tt- | % | 98% | name+unit+values | 1432 | 0 | [60.12, 72.07, 78.16, 83.25, 88.78, 95.39, 102.35, 111.94, 122.43] |  | Plasma |  | Prothrombin time [Ratio] in Plasma |
| 440 | p-tt- |  | 2% | name | 29 | 96.55 |  |  | Plasma |  | Prothrombin time [Ratio] in Plasma |
| 441 | p-tt. | % | 94% | name+unit+values | 5628 | 0 | [63.13, 78.7, 87.12, 93.57, 99.77, 105.67, 112.42, 119.67, 130.89] |  | Plasma |  | Prothrombin time [Ratio] in Plasma |
| 442 | p-tt. |  | 6% | name+values | 328 | 31.4 | [48, 79.63, 90.12, 98.65, 107.18, 114.33, 121.82, 130.4, 140] |  | Plasma |  | Prothrombin time [Ratio] in Plasma |
| 443 | p-ttr | % | 93% | name+unit+values | 1114 | 0 | [50.89, 61.27, 67.88, 73.89, 78.52, 83.07, 89.29, 95.08, 100] |  | Plasma |  | Prothrombin time [Ratio] in Plasma |
| 444 | p-ttr |  | 7% | name | 89 | 89.89 |  |  | Plasma |  | Prothrombin time [Ratio] in Plasma |
| 445 | pdgfr |  | 100% | name | 461 | 100 |  |  |  |  | PDGFR gene targeted mutation analysis |
| 446 | peak | l/min | 10% | name+unit | 12 | 0 |  |  |  |  | Peak expiratory flow rate [Volume Rate] |
| 447 | peak |  | 90% | name | 104 | 100 |  |  |  |  | Peak expiratory flow rate [Volume Rate] |
| 448 | pef-pa |  | 100% | name | 7844 | 99.92 |  | Uloshengityksen huippuvirtaus, sarjamittaus, pitkäaikaisseuranta |  | Long-term / prolonged | Peak expiratory flow rate during monitoring period |
| 449 | pef-ras |  | 100% | name | 242 | 100 |  | Uloshengityksen huippuvirtaus, sarjamittaus, rasituskoe |  |  | Peak expiratory flow rate [Volume Rate] --post exercise |
| 450 | pf-ace | u/l | 66% | name+unit+values | 313 | 3.19 | [6.4, 10.22, 12.78, 15.45, 17.82, 19.96, 24.1, 28.83, 37.4] | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid |
| 451 | pf-ace |  | 34% | name | 161 | 98.14 |  | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid |
| 452 | pf-ada | u/l | 91% | name+unit+values | 3550 | 0.14 | [3.68, 5.14, 6.78, 8.01, 9.46, 11.17, 13.55, 17.33, 25.48] | Pf-Adenosiinideaminaasi | Pleural fluid |  | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid |
| 453 | pf-ada |  | 9% | name | 365 | 90.96 |  | Pf-Adenosiinideaminaasi | Pleural fluid |  | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid |
| 454 | pneag |  | 100% | name | 244 | 100 |  |  |  |  |  |
| 455 | s-na | mmol/l | 99% | name+unit+values | 124118 | 0 | [137.36, 138.84, 139.01, 140, 140.14, 141, 141.38, 142, 143] | S -Natrium | Serum | Native preparation | Sodium [Moles/volume] in Serum or Plasma |
| 456 | s-na | mol/l | 0% | name+unit | 5 | 0 |  | S -Natrium | Serum | Native preparation | Sodium [Moles/volume] in Serum or Plasma |
| 457 | s-na |  | 1% | name+values | 931 | 67.35 | [137.2, 138, 139, 139, 140, 140, 141, 141, 142.37] | S -Natrium | Serum | Native preparation | Sodium [Moles/volume] in Serum or Plasma |
| 458 | s-t3-v | pmol/l | 92% | name+unit+values | 18657 | 0 | [3.72, 4.06, 4.3, 4.5, 4.69, 4.9, 5.13, 5.43, 6.06] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated | Triiodothyronine (T3).free [Moles/volume] in Serum or Plasma |
| 459 | s-t3-v |  | 8% | name+values | 1623 | 51.2 | [3.55, 3.8, 4.02, 4.22, 4.41, 4.6, 4.85, 5.16, 5.82] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated | Triiodothyronine (T3).free [Moles/volume] in Serum or Plasma |
| 460 | s-t4-v | pmol/l | 96% | name+unit+values | 252259 | 0 | [11.09, 12, 12.88, 13.14, 13.97, 14.48, 15.15, 16.1, 17.48] | S -Tyroksiini, vapaa | Serum | Free or unconjugated | Thyroxine (T4).free [Moles/volume] in Serum or Plasma |
| 461 | s-t4-v |  | 4% | name+values | 9900 | 100 | [12.03, 12.98, 13.72, 14.35, 14.94, 15.68, 16.39, 17.25, 18.59] | S -Tyroksiini, vapaa | Serum | Free or unconjugated | Thyroxine (T4).free [Moles/volume] in Serum or Plasma |
| 462 | s-t4v | pmol/l | 100% | name+unit+values | 1086 | 0 | [12.85, 13, 14, 14.52, 15, 15.93, 16, 17, 18] |  | Serum |  | Thyroxine (T4).free [Moles/volume] in Serum or Plasma |
| 463 | s-tfr | mg | 0% | name+unit | 7 | 0 |  | S -Transferriinireseptori, liukoinen | Serum |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 464 | s-tfr | mg/l | 98% | name+unit+values | 77760 | 0 | [1, 1.22, 1.5, 1.89, 2.35, 2.8, 3.34, 4.1, 5.59] | S -Transferriinireseptori, liukoinen | Serum |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 465 | s-tfr |  | 2% | name+values | 1379 | 100 | [1.84, 2.22, 2.62, 3.08, 3.57, 4.23, 5.1, 6.26, 8.15] | S -Transferriinireseptori, liukoinen | Serum |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 466 | s-tnf | ng/l | 67% | name+unit+values | 100 | 0 | [4.65, 5.4, 6.33, 7.11, 7.81, 8.85, 10.5, 13.2, 23.25] | S -Tuumorinekroositekijä, alfa | Serum |  | Tumor necrosis factor alpha [Mass/volume] in Serum |
| 467 | s-tnf |  | 33% | name | 50 | 74 |  | S -Tuumorinekroositekijä, alfa | Serum |  | Tumor necrosis factor alpha [Mass/volume] in Serum |
| 468 | s-tni | ng/l | 26% | name+unit+values | 63 | 0 | [2.98, 3.29, 4.36, 4.96, 6.38, 8.72, 14.54, 33, 54.53] | S -Troponiini I | Serum |  | Troponin I.cardiac [Mass/volume] in Serum |
| 469 | s-tni | ug/l | 4% | name+unit | 11 | 0 |  | S -Troponiini I | Serum |  | Troponin I.cardiac [Mass/volume] in Serum |
| 470 | s-tni |  | 70% | name | 171 | 100 |  | S -Troponiini I | Serum |  | Troponin I.cardiac [Mass/volume] in Serum |
| 471 | s-tnt | ng/l | 2% | name+unit+values | 149 | 0 | [40, 42, 45.21, 51.23, 64.69, 87.1, 139.39, 201.81, 358.2] | S -Troponiini T | Serum |  | Troponin T.cardiac [Mass/volume] in Serum |
| 472 | s-tnt |  | 98% | name | 7446 | 99.38 |  | S -Troponiini T | Serum |  | Troponin T.cardiac [Mass/volume] in Serum |
| 473 | s-tob | mg/l | 59% | name+unit+values | 805 | 0.99 | [0.29, 0.5, 0.61, 0.8, 1.01, 1.26, 1.54, 1.91, 3.02] | S -Tobramysiini | Serum |  | Tobramycin [Mass/volume] in Serum |
| 474 | s-tob |  | 41% | name | 560 | 81.96 |  | S -Tobramysiini | Serum |  | Tobramycin [Mass/volume] in Serum |
| 475 | sp-pak |  | 100% | name | 196 | 100 |  |  | Sperm / semen |  | Semen analysis panel - Semen |
| 476 | sp-pakd |  | 100% | name | 138 | 100 |  |  | Sperm / semen |  | Semen analysis panel - Semen |
| 477 | u-na | mmol/l | 77% | name+unit+values | 8969 | 1.33 | [24.74, 32.42, 40.4, 48.4, 57.53, 68.16, 81.75, 99.14, 129.68] | U -Natrium | Urine | Native preparation | Sodium [Moles/volume] in Urine |
| 478 | u-na |  | 23% | name+values | 2662 | 76.37 | [27.27, 35.54, 43.11, 51.43, 60.05, 68.34, 78.15, 92.47, 111.65] | U -Natrium | Urine | Native preparation | Sodium [Moles/volume] in Urine |
| 479 | v-na |  | 100% | name+values | 265 | 0.75 | [130.22, 134.26, 135.98, 137.59, 138.5, 139.03, 140, 141, 142] |  |  | Native preparation | Sodium [Moles/volume] in Blood |
| 480 | vp-na | mmol/l | 98% | name+unit+values | 10896 | 0 | [132.84, 135.34, 136.96, 137.97, 138.99, 139.84, 140.33, 141.08, 142.49] |  |  | Native preparation | Sodium [Moles/volume] in Serum or Plasma |
| 481 | vp-na |  | 2% | name | 174 | 98.28 |  |  |  | Native preparation | Sodium [Moles/volume] in Serum or Plasma |

