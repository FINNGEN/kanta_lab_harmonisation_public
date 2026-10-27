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
Here is group 106.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3009466 | Valproate [Moles/volume] in Serum or Plasma | 1.000 | 408 |
| 3012336 | Haptoglobin [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3023383 | Lactate [Moles/volume] in Pleural fluid | 1.000 |  |
| 3023530 | 17-Hydroxyprogesterone [Moles/volume] in Serum or Plasma | 1.000 | 850 |
| 3026470 | Cobalt [Mass/volume] in Blood | 1.000 |  |
| 3026493 | Urate [Moles/volume] in Serum or Plasma | 1.000 | 142 |
| 3031219 | Potassium [Moles/volume] in Mixed venous blood | 1.000 |  |
| 3031579 | Sodium [Moles/volume] in Mixed venous blood | 1.000 |  |
| 3035999 | Lactate [Moles/volume] in Cerebral spinal fluid | 1.000 |  |
| 3047181 | Lactate [Moles/volume] in Blood | 1.000 | 475 |
| 3016616 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in Serum or Plasma | 0.956 | 468 |
| 3016650 | Hepatitis A virus Ab [Presence] in Serum | 0.955 |  |
| 3014111 | Lactate [Moles/volume] in Serum or Plasma | 0.938 | 346 |
| 3016201 | Valproate [Mass/volume] in Serum or Plasma | 0.938 |  |
| 3023103 | Potassium [Moles/volume] in Serum or Plasma | 0.938 | 3 |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 0.934 | 5 |
| 3020491 | Glucose [Moles/volume] in Blood | 0.933 | 13 |
| 3005491 | Lactate [Moles/volume] in Plasma venous | 0.932 | 1070 |
| 3025848 | Cobalt [Moles/volume] in Blood | 0.932 |  |
| 3005456 | Potassium [Moles/volume] in Blood | 0.927 | 106 |
| 3017588 | European tick borne encephalitis virus Ab [Titer] in Serum | 0.926 |  |
| 3020410 | Lactate [Moles/volume] in Arterial plasma | 0.925 |  |
| 3022915 | Valproate Free [Moles/volume] in Serum or Plasma | 0.923 |  |
| 3028718 | 17-Hydroxyprogesterone [Mass/volume] in Serum or Plasma | 0.922 |  |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 0.921 | 4 |
| 3037556 | Urate [Mass/volume] in Serum or Plasma | 0.921 |  |
| 3043000 | Haptoglobin [Mass/volume] in Serum or Plasma by Nephelometry | 0.921 |  |
| 3035456 | Hepatitis A virus Ab [Presence] in Serum by Immunoassay | 0.917 | 558 |
| 3025022 | Lactate [Mass/volume] in Cerebral spinal fluid | 0.917 |  |
| 3027880 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Serum or Plasma | 0.916 | 833 |
| 42529218 | HIV 1+2 Ab and HIV1 p24 Ag panel - Serum or Plasma by Immunoassay | 0.914 |  |
| 1092084 | Beta hydroxybutyrate [Moles/volume] in Blood | 0.914 |  |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.914 |  |
| 3000285 | Sodium [Moles/volume] in Blood | 0.913 | 129 |
| 3016703 | Haptoglobin [Mass/volume] in Body fluid | 0.912 |  |
| 46235078 | Potassium [Moles/volume] in Serum, Plasma or Blood | 0.912 |  |
| 36031335 | HIV 1 and 2 Ab panel - Serum or Plasma by Immunoassay | 0.911 |  |
| 40763125 | Cobalt [Mass/volume] in Red Blood Cells | 0.910 |  |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.909 |  |
| 3020337 | 17-Hydroxyprogesterone [Moles/volume] in Serum or Plasma --baseline | 0.909 |  |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.909 |  |
| 3009695 | 17-Hydroxypregnenolone [Moles/volume] in Serum or Plasma | 0.909 |  |
| 44816931 | D-Lactate [Moles/volume] in Cerebral spinal fluid | 0.909 |  |
| 3019800 | Troponin T.cardiac [Mass/volume] in Serum or Plasma | 0.908 | 291 |
| 3028271 | Lactate [Moles/volume] in Capillary blood | 0.907 |  |
| 42868683 | Haptoglobin [Moles/volume] in Serum or Plasma | 0.906 | 596 |
| 3011525 | 17-Hydroxyprogesterone [Moles/volume] in Urine | 0.905 |  |
| 3041354 | Potassium [Moles/volume] in Venous blood | 0.905 |  |
| 42527815 | HIV 1 and 2 Ab and HIV 1 p24 Ag panel - Serum or Plasma by Immunoassay | 0.905 |  |
| 3006631 | Hepatitis A virus IgG Ab [Presence] in Serum | 0.903 |  |
| 3008037 | Lactate [Moles/volume] in Venous blood | 0.903 |  |
| 3018405 | Lactate [Moles/volume] in Arterial blood | 0.902 | 1277 |
| 3009759 | Haptoglobin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.899 |  |
| 3036736 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Specimen by NAA with probe detection | 0.897 |  |
| 3031021 | Cobalt [Mass/volume] in Body fluid | 0.897 |  |
| 3028447 | Cobalt [Mass/volume] in Serum or Plasma | 0.896 |  |
| 3004825 | Lactate [Moles/volume] in Body fluid | 0.894 |  |
| 3003985 | Beta hydroxybutyrate [Moles/volume] in Serum or Plasma | 0.894 | 1670 |
| 40762125 | Lactate [Mass/volume] in Blood | 0.893 |  |
| 3013327 | Hepatitis A virus IgM Ab [Presence] in Serum | 0.892 | 724 |
| 3048529 | Troponin T.cardiac [Mass/volume] in Blood | 0.891 |  |
| 646803 | Haptoglobin [Measurement] in Serum or Plasma | 0.888 |  |
| 3028566 | Urate [Moles/volume] in Specimen | 0.886 |  |
| 646215 | Hepatitis A virus Ab [Measurement] in Serum | 0.886 |  |
| 3045281 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Urine by NAA with probe detection | 0.886 |  |
| 3039319 | Hepatitis A virus IgG+IgM Ab [Presence] in Serum | 0.885 |  |
| 3045789 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Genital specimen by NAA with probe detection | 0.884 |  |
| 3022620 | Valproate [Mass/volume] in Serum or Plasma --trough | 0.883 |  |
| 1259791 | Lupus anticoagulant aPTT screening panel - Platelet poor plasma by Coagulation assay | 0.881 |  |
| 46237023 | Hepatitis B virus core and surface Ab and surface Ag panel - Serum | 0.881 |  |
| 3040363 | Hepatitis A virus IgG Ab [Presence] in Serum by Immunoassay | 0.881 |  |
| 1259648 | European tick borne encephalitis virus IgM Ab [Titer] in Serum by Immunoassay | 0.880 |  |
| 3029143 | Chylomicrons [Presence] in Pleural fluid | 0.880 |  |
| 3015884 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma | 0.880 |  |
| 3043409 | Potassium [Moles/volume] in Arterial blood | 0.879 |  |
| 3040257 | Hepatitis A virus Ab [Presence] in Body fluid | 0.878 |  |
| 3027874 | Urate [Moles/volume] in Urine | 0.876 | 1405 |
| 3024085 | Cobalt [Mass/volume] in Urine | 0.876 |  |
| 3040151 | Glucose [Moles/volume] in Capillary blood | 0.875 |  |
| 40759053 | Lactate [Moles/volume] in Cord blood | 0.874 |  |
| 3021337 | Troponin I.cardiac [Mass/volume] in Serum or Plasma | 0.874 | 113 |
| 36306193 | HIV 1 and 2 Ab panel - Serum, Plasma or Blood by Rapid immunoassay | 0.873 |  |
| 36031337 | Human papilloma virus high-risk genotypes panel - Cervix by NAA with probe detection | 0.873 |  |
| 3009179 | Lactate [Moles/volume] in Peritoneal fluid | 0.872 |  |
| 3021600 | Valproate Free [Mass/volume] in Serum or Plasma | 0.870 |  |
| 1617572 | HIV 1 Ab panel - Serum or Plasma by Immunoblot | 0.870 |  |
| 647936 | Urate [Measurement] in Serum or Plasma | 0.870 |  |
| 1616351 | HIV 2 Ab panel - Serum or Plasma by Immunoblot | 0.869 |  |
| 3017889 | European tick borne encephalitis virus IgG Ab [Units/volume] in Serum | 0.869 |  |
| 44786993 | 17-Hydroxyprogesterone [Moles/volume] in Serum or Plasma --20M post dose corticotropin | 0.868 |  |
| 40760658 | 17-Hydroxyprogesterone [Moles/volume] in Serum or Plasma --pre dose dexamethasone | 0.868 |  |
| 40758599 | 17-Hydroxyprogesterone [Moles/volume] in Serum or Plasma --1 hour post dose corticotropin | 0.868 |  |
| 3007330 | European tick borne encephalitis virus Ab [Titer] in Serum by Complement fixation | 0.867 |  |
| 3043706 | Sodium [Moles/volume] in Arterial blood | 0.866 |  |
| 3022810 | Sodium [Moles/volume] in Body fluid | 0.866 |  |
| 3035729 | Glucose [Moles/volume] in Body fluid | 0.866 | 788 |
| 1469824 | Tick borne encephalitis virus Ab [Interpretation] in Serum or Plasma | 0.865 |  |
| 646177 | 17-Hydroxyprogesterone [Measurement] in Serum or Plasma | 0.865 |  |
| 649588 | European tick borne encephalitis virus Ab [Measurement] in Serum | 0.865 |  |
| 46235425 | Hepatitis B virus little e Ag and Ab panel - Serum | 0.865 |  |
| 3040893 | Potassium [Moles/volume] in Capillary blood | 0.864 |  |
| 3006944 | 17-Hydroxyprogesterone [Mass/volume] in Serum or Plasma --baseline | 0.864 |  |
| 3038515 | Glucose [Moles/volume] in Venous blood | 0.864 |  |
| 3039218 | Hepatitis A virus Ab [Interpretation] in Serum | 0.864 |  |
| 3044242 | Glucose [Moles/volume] in Arterial blood | 0.863 |  |
| 36660717 | Hepatitis B virus surface Ab panel - Serum or Plasma | 0.863 |  |
| 3028479 | European tick borne encephalitis virus Ab [Units/volume] in Serum | 0.863 |  |
| 3006922 | Hepatitis E virus Ab [Presence] in Serum | 0.862 |  |
| 1989655 | Tick-borne encephalitis virus neutralizing antibody [Titer] in Specimen by Neutralization test | 0.861 |  |
| 3038702 | Sodium [Moles/volume] in Capillary blood | 0.861 |  |
| 3033745 | Troponin I.cardiac [Mass/volume] in Blood | 0.861 |  |
| 3004721 | European tick borne encephalitis virus IgM Ab [Units/volume] in Serum | 0.860 |  |
| 3036243 | Potassium [Moles/volume] in Body fluid | 0.859 |  |
| 3008520 | Urate [Moles/volume] in Body fluid | 0.859 |  |
| 3042324 | Beta hydroxybutyrate + Gamma aminobutyrate [Moles/volume] in Serum or Plasma | 0.859 |  |
| 3019572 | Troponin T.cardiac [Mass/volume] in Venous blood | 0.858 |  |
| 42528602 | Human papilloma virus 16 and 18+45 E6+E7 mRNA panel - Cervix by NAA with probe detection | 0.857 |  |
| 3044125 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Specimen by Probe with signal amplification | 0.857 |  |
| 3019205 | Cobalt [Mass/volume] in Specimen | 0.856 |  |
| 36660125 | Hepatitis B virus surface Ag and Hepatitis B virus e Ab and Ag panel - Serum or Plasma | 0.856 |  |
| 40769783 | Troponin T.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.855 |  |
| 3024316 | Viscosity of Plasma | 0.854 |  |
| 1259614 | European tick borne encephalitis virus IgM Ab [Titer] in Cerebral spinal fluid by Immunoassay | 0.854 |  |
| 3038697 | Lupus anticoagulant neutralization platelet [Presence] in Platelet poor plasma by Coagulation assay | 0.853 |  |
| 3006093 | Chlamydia trachomatis DNA [Presence] in Specimen by NAA with probe detection | 0.853 | 180 |
| 3965306 | Troponin T.cardiac [Mass/volume] in 6 hour Serum or Plasma | 0.853 |  |
| 43533702 | Valproate [Mass/volume] in Serum or Plasma --peak | 0.853 |  |
| 36660732 | Hepatitis B virus DNA panel - Serum or Plasma | 0.851 |  |
| 3045367 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Cervix by NAA with probe detection | 0.851 | 2001 |
| 36660589 | Hepatitis B virus core Ab panel - Serum or Plasma | 0.851 |  |
| 3017427 | Lupus anticoagulant neutralization dilute phospholipid [Presence] in Platelet poor plasma | 0.851 | 1189 |
| 36660011 | Hepatitis B virus surface Ag panel - Serum or Plasma | 0.849 |  |
| 645110 | European tick borne encephalitis virus IgG Ab [Measurement] in Serum | 0.848 |  |
| 3024421 | Chlamydia trachomatis DNA [Presence] in Genital specimen by NAA with probe detection | 0.848 |  |
| 36031171 | Tick-borne encephalitis virus IgG Ab [Presence] in Specimen by Immunoassay | 0.847 |  |
| 3035800 | Chlamydia trachomatis and Neisseria gonorrhoeae DNA [Identifier] in Specimen by NAA with probe detection | 0.847 | 327 |
| 3051893 | Chlamydia trachomatis L2 DNA [Presence] in Specimen by NAA with probe detection | 0.846 |  |
| 3044014 | Lactate [Moles/volume] in Urine | 0.846 |  |
| 21491077 | Lactyl lactate [Moles/volume] in Serum or Plasma | 0.846 |  |
| 1092100 | Chlamydia trachomatis DNA [Presence] in Specimen by Molecular genetics method | 0.845 |  |
| 3040752 | Haptoglobin [Presence] in Serum or Plasma | 0.845 |  |
| 3020779 | Urea [Moles/volume] in Serum or Plasma | 0.845 |  |
| 3027184 | Lupus anticoagulant [Interpretation] in Platelet poor plasma | 0.845 |  |
| 3024950 | Chlamydia trachomatis DNA [Presence] in Urine by NAA with probe detection | 0.845 | 726 |
| 3029886 | Cobalt [Moles/volume] in Red Blood Cells | 0.844 |  |
| 3021311 | Cobalt [Moles/volume] in Serum or Plasma | 0.844 |  |
| 3044334 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in Urine | 0.843 |  |
| 1092096 | Chlamydia trachomatis L1 DNA [Presence] in Specimen by NAA with probe detection | 0.843 |  |
| 3022000 | Dehydroepiandrosterone (DHEA) [Mass/volume] in Serum or Plasma | 0.842 |  |
| 3013098 | Potassium [Moles/volume] in Specimen | 0.842 |  |
| 3010421 | pH of Blood | 0.842 | 97 |
| 43055437 | Beta hydroxybutyrate + Acetoacetate [Moles/volume] in Blood | 0.842 |  |
| 1469858 | Troponin T.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.841 |  |
| 42868417 | European tick borne encephalitis virus IgG Ab [Presence] in Serum by Immunoassay | 0.839 |  |
| 37020905 | Hepatitis B virus core Ab and surface and little e Ab and Ag panel - Serum or Plasma | 0.839 |  |
| 21491446 | Chlamydia trachomatis+Neisseria gonorrhoeae rRNA [Presence] in Urine by NAA with probe detection | 0.838 | 3000 |
| 40761050 | Cobalt [Mass/volume] in Cerebral spinal fluid | 0.838 |  |
| 40758603 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Serum or Plasma --baseline | 0.838 |  |
| 3009015 | Lactate [Moles/volume] in Synovial fluid | 0.837 |  |
| 3006669 | Glucose [Moles/volume] in Serum or Plasma --pre 12 hour fast | 0.836 |  |
| 3006893 | Glucose [Moles/volume] in Specimen | 0.835 |  |
| 40757618 | Glucose [Moles/volume] in Water | 0.834 |  |
| 3012713 | Urate [Moles/volume] in 24 hour Urine | 0.833 |  |
| 3026681 | Sodium [Moles/volume] in Specimen | 0.833 |  |
| 3013823 | Potassium [Moles/volume] in Red Blood Cells | 0.832 |  |
| 3016038 | Potassium [Moles/volume] in Urine | 0.832 | 493 |
| 3050932 | Hepatitis A virus Ab panel - Serum | 0.831 |  |
| 3028166 | Beta hydroxybutyrate [Moles/volume] in Urine | 0.830 |  |
| 3020979 | Major crossmatch.re-crossmatch [Interpretation] | 0.829 |  |
| 3018747 | Beta hydroxybutyrate [Mass/volume] in Serum or Plasma | 0.829 |  |
| 3042301 | Urate [Moles/volume] in Synovial fluid | 0.828 |  |
| 3004592 | Major crossmatch [Interpretation] | 0.828 | 247 |
| 21491327 | Allopurinol [Moles/volume] in Serum or Plasma | 0.828 |  |
| 3033735 | Hepatitis A and B and C 7a panel - Serum | 0.828 |  |
| 36306105 | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.825 |  |
| 3003181 | Sodium [Moles/volume] in Urine | 0.825 | 412 |
| 1989097 | Urate [Mass/volume] in Blood | 0.824 |  |
| 1469828 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by High sensitivity method | 0.823 |  |
| 42868340 | Alpha hydroxybutyrate [Moles/volume] in Serum or Plasma | 0.823 |  |
| 1259531 | Human papilloma virus 31+33+52+58 DNA [Presence] in Cervix by NAA with probe detection | 0.822 |  |
| 3025817 | Bicarbonate [Moles/volume] in Mixed venous blood | 0.822 |  |
| 3001838 | Sodium [Moles/volume] in Red Blood Cells | 0.821 |  |
| 40761785 | Beta hydroxybutyrate [Moles/volume] in Vitreous fluid | 0.821 |  |
| 40757440 | Lactate/Pyruvate [Molar ratio] in Cerebral spinal fluid | 0.818 |  |
| 3018279 | Valproate.protein bound [Mass/volume] in Serum or Plasma | 0.817 |  |
| 42868350 | 3-Hydroxyisobutyrate [Moles/volume] in Serum or Plasma | 0.816 |  |
| 3041493 | Beta aminobutyrate [Moles/volume] in Serum or Plasma | 0.816 |  |
| 3019923 | Valproate [Mass/volume] in Urine | 0.816 |  |
| 3020115 | Chlamydia trachomatis DNA [Presence] in Urethra by NAA with probe detection | 0.815 |  |
| 3026788 | Beta hydroxybutyrate [Moles/volume] in Cerebral spinal fluid | 0.815 |  |
| 40759672 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma --baseline | 0.814 |  |
| 40769111 | Beta hydroxybutyrate [Moles/volume] in Blood by Test strip | 0.814 |  |
| 3041392 | Hydrogen ion [Moles/volume] in Mixed venous blood | 0.813 |  |
| 36031212 | Human papilloma virus 31 DNA [Presence] in Cervix by NAA with probe detection | 0.812 |  |
| 36031448 | Human papilloma virus 33+58 DNA [Presence] in Cervix by NAA with probe detection | 0.812 |  |
| 43055048 | Beta hydroxybutyrate [Moles/volume] in Blood --pre-meal | 0.812 |  |
| 36032027 | Human papilloma virus 56+59+66 DNA [Presence] in Cervix by NAA with probe detection | 0.811 |  |
| 648351 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.811 |  |
| 3011531 | Valproate [Mass/volume] in Body fluid | 0.811 |  |
| 3044342 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in 24 hour Urine | 0.810 |  |
| 3051263 | Dihydroxycholestanoate [Moles/volume] in Serum or Plasma | 0.810 |  |
| 3033110 | Human papilloma virus high and Low risk DNA panel - Cervix | 0.810 |  |
| 36032242 | HIV 1 and 2 RNA panel - Serum or Plasma by NAA with probe detection | 0.810 |  |
| 3033526 | Urate [Mass/volume] in Urine | 0.809 |  |
| 21492985 | HIV 2 RNA panel - Serum or Plasma by NAA with probe detection | 0.809 |  |
| 3023456 | Valproate Free/Valproate.total in Serum or Plasma | 0.809 |  |
| 42870370 | Human papilloma virus 31+33+35+39+45+51+52+56+58+59+66+68 DNA [Presence] in Cervix by NAA with probe detection | 0.808 |  |
| 43055060 | 4-Hydroxyphenyllactate [Moles/volume] in Cerebral spinal fluid | 0.808 |  |
| 648393 | HIV 1+2 Ab+HIV1 p24 Ag [Measurement] in Serum or Plasma | 0.808 |  |
| 3036932 | Minor crossmatch [Interpretation] | 0.806 |  |
| 3022493 | Free Hemoglobin [Mass/volume] in Plasma | 0.806 | 1917 |
| 1761323 | Chloride [Moles/volume] in Mixed venous blood | 0.806 |  |
| 36032213 | Human papilloma virus 51 DNA [Presence] in Cervix by NAA with probe detection | 0.806 |  |
| 3030560 | Chlamydia sp DNA [Presence] in Urine by NAA with probe detection | 0.804 |  |
| 36032296 | Human papilloma virus 52 DNA [Presence] in Cervix by NAA with probe detection | 0.804 |  |
| 1091714 | HIV 1+2 Ab+HIV1 p24 Ag [Presence] in Serum or Plasma | 0.803 |  |
| 1092194 | Hemoglobin [Moles/volume] in Mixed venous blood | 0.802 |  |
| 3012113 | Leucine [Moles/volume] in Cerebral spinal fluid | 0.802 |  |
| 1761753 | Glucose [Moles/volume] in Mixed venous blood | 0.800 |  |
| 43055047 | Beta hydroxybutyrate [Moles/volume] in Blood --post meal | 0.799 |  |
| 3003510 | Neisseria gonorrhoeae DNA [Presence] in Urine by NAA with probe detection | 0.797 | 1560 |
| 3043859 | Chlamydia trachomatis+Neisseria gonorrhoeae rRNA [Presence] in Urethra by Probe | 0.791 |  |
| 3019174 | dRVVT in Platelet poor plasma by Coagulation assay | 0.791 | 759 |
| 3039189 | Lupus anticoagulant neutralization dilute phospholipid [Time] in Platelet poor plasma | 0.790 |  |
| 46235128 | Lupus anticoagulant aPTT and dRVVT screening panel W Reflex | 0.789 |  |
| 43055496 | Extrinsic coagulation factor activity 4 panel - Platelet poor plasma | 0.788 |  |
| 3009299 | Lupus anticoagulant neutralization platelet [Time] in Platelet poor plasma by Coagulation assay | 0.786 | 811 |
| 1175335 | Human papilloma virus genotype [Identifier] in Tissue by NAA with probe detection | 0.784 |  |
| 3000588 | Chylomicrons [Mass/volume] in Pleural fluid | 0.784 |  |
| 37019482 | Human papilloma virus genotype [Identifier] in Genital specimen by NAA with probe detection | 0.784 |  |
| 3027112 | dRVVT actual/normal [Presence] in Platelet poor plasma by Coagulation assay | 0.783 |  |
| 3049514 | Human papilloma virus genotype [Identifier] in Specimen by NAA with probe detection | 0.783 | 1407 |
| 46235689 | Lupus anticoagulant aPTT, dRVVT and PT screening panel W Reflex | 0.779 |  |
| 43055495 | Intrinsic coagulation factor activity 4 panel - Platelet poor plasma by Coagulation assay | 0.777 |  |
| 3003160 | Major crossmatch [Interpretation] --post immediate spin | 0.777 |  |
| 3003488 | Major crossmatch [Interpretation] by Immediate spin | 0.776 |  |
| 3028671 | Hemopexin [Mass/volume] in Serum | 0.776 |  |
| 3049997 | Major crossmatch [Interpretation] --after transfusion reaction | 0.775 |  |
| 40760300 | Lupus anticoagulant neutralization dilute phospholipid/Lupus anticoagulant neutralization.high phospholipid [Ratio] in Platelet poor plasma by Coagulation assay | 0.773 |  |
| 1616395 | dRVVT/dRVVT.excess phospholipid [Ratio] normalized in Platelet poor plasma by Coagulation assay | 0.772 |  |
| 42529439 | Human papilloma virus 16 and 18+45 E6+E7 mRNA [Identifier] in Cervix by NAA with probe detection | 0.772 |  |
| 1176129 | Coagulation factor VII activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.768 |  |
| 3001257 | Free Hemoglobin [Mass/volume] in Serum | 0.767 | 1947 |
| 3033295 | Lupus anticoagulant neutralization dilute phospholipid actual/normal in Platelet poor plasma by Coagulation assay | 0.767 |  |
| 3044947 | aPTT.lupus sensitive in Platelet poor plasma from Control by Coagulation assay | 0.767 |  |
| 3045887 | Human papilloma virus DNA [Presence] in Cervix by Probe | 0.767 |  |
| 3039363 | dRVVT in Platelet poor plasma from Control by Coagulation assay | 0.764 |  |
| 36032236 | Coagulation factor II activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.762 |  |
| 36031832 | Coagulation factor V activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.762 |  |
| 36660198 | dRVVT/dRVVT.excess phospholipid [Ratio] in Platelet poor plasma by Coagulation assay --post DOAC neutralization | 0.761 |  |
| 3005895 | Myoglobin [Mass/volume] in Serum or Plasma | 0.761 | 496 |
| 3015115 | Human papilloma virus identified in Cervix | 0.760 |  |
| 36032232 | Coagulation factor X activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.760 |  |
| 1091602 | Human papilloma virus DNA [Presence] in Specimen | 0.760 |  |
| 3046082 | Antithrombin Ag [Presence] in Platelet poor plasma by Immunoassay | 0.759 |  |
| 36031948 | Coagulation factor VIII activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.757 |  |
| 3038606 | aPTT.lupus insensitive in Platelet poor plasma by Coagulation assay | 0.757 |  |
| 3048268 | PT and aPTT and Fibrinogen panel - Platelet poor plasma by Coagulation assay | 0.756 |  |
| 3027627 | Lupus anticoagulant neutralization high phospholipid [Time] in Platelet poor plasma by Coagulation assay | 0.756 |  |
| 1469515 | Human papilloma virus genotype [Identifier] in Semen by NAA with probe detection | 0.756 |  |
| 36032226 | Coagulation factor XI activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.754 |  |
| 3001997 | Major crossmatch [Interpretation] by Prewarmed | 0.753 |  |
| 46235717 | Delta dRVVT [Time] in Platelet poor plasma by Coagulation assay | 0.752 |  |
| 3032493 | dRVVT/dRVVT W excess phospholipid (screen to confirm ratio) | 0.751 | 3000 |
| 3033779 | Human papilloma virus 16+18+31+33+35+45+51+52+56 DNA [Presence] in Cervix by Probe | 0.746 | 709 |
| 36031637 | Coagulation factor IX activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.745 |  |
| 3047126 | Platelet crossmatch [Interpretation] | 0.741 |  |
| 3030308 | Hydrogen ion [Moles/volume] in Blood | 0.739 |  |
| 3038350 | Major crossmatch [Interpretation] by Electronic | 0.739 |  |
| 3038908 | pH of Blood product unit | 0.738 |  |
| 3029782 | Chylomicrons [Presence] in Body fluid | 0.737 |  |
| 40758907 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of platelet lysate | 0.736 |  |
| 3015823 | Fibrin D-dimer [Presence] in Platelet poor plasma | 0.732 |  |
| 3051807 | B cell crossmatch [Interpretation] | 0.732 |  |
| 3047091 | Lupus anticoagulant neutralization buffer [Time] in Platelet poor plasma by Coagulation assay | 0.731 |  |
| 3030251 | pH of Pleural fluid by Test strip | 0.718 |  |
| 3035880 | pH of Pleural fluid | 0.717 |  |
| 46235338 | Cell-free DNA.fetal/Cell-free DNA.total in Plasma cell-free DNA by Dosage of chromosome-specific cfDNA | 0.715 |  |
| 3048571 | Activated protein C resistance panel - Platelet poor plasma | 0.714 |  |
| 46235339 | Cell-free DNA.fetal/Cell-free DNA.total in Plasma cell-free DNA by Dosage of chromosome-specific cfDNA Narrative | 0.712 |  |
| 3018672 | pH of Body fluid | 0.712 | 953 |
| 3049242 | von Willebrand panel - Platelet poor plasma | 0.712 |  |
| 3045962 | Hyaluronate [Presence] in Pleural fluid | 0.708 |  |
| 3018418 | pH of Serum or Plasma | 0.707 | 160 |
| 46237006 | Karyotype [Identifier] in Products of Conception Nominal | 0.705 |  |
| 3003403 | Glucose [Mass/volume] in Pleural fluid | 0.701 |  |
| 3009343 | pH of Capillary blood | 0.701 | 865 |
| 3035173 | Hydrogen ion [Moles/volume] in Arterial blood | 0.696 |  |
| 3030091 | pH of Blood adjusted to patient's actual temperature | 0.695 | 1223 |
| 1616748 | Vascular endothelial growth factor C [Mass/volume] in Serum or Plasma | 0.695 |  |
| 3031767 | Vascular endothelial growth factor [Mass/volume] in Serum or Plasma | 0.694 |  |
| 1259993 | Gas and Lactate panel - Venous blood | 0.693 |  |
| 3004313 | Fibronectin [Mass/volume] in Plasma | 0.691 |  |
| 40770392 | Thromboelastography panel - Blood | 0.690 |  |
| 1001555 | Platelet surface glycoprotein disorders panel - Blood by Flow cytometry (FC) | 0.690 |  |
| 3033364 | Cholesterol [Mass/volume] in Pleural fluid | 0.689 |  |
| 3006576 | Bicarbonate [Moles/volume] in Blood | 0.689 | 120 |
| 42529047 | Vascular endothelial growth factor D [Mass/volume] in Serum or Plasma | 0.689 |  |
| 3035265 | Fatty acids [Presence] in Pleural fluid | 0.688 |  |
| 3029414 | Hydrogen ion [Moles/volume] in Venous blood | 0.688 |  |
| 1617671 | Fibroblast growth factor 2 [Mass/volume] in Serum or Plasma | 0.687 |  |
| 646689 | Lactate dehydrogenase [Measurement] in Pleural fluid | 0.686 |  |
| 3045509 | PT and aPTT panel - Platelet poor plasma by Coagulation assay | 0.685 |  |
| 46235359 | Vascular endothelial growth factor A [Mass/volume] in Serum or Plasma | 0.685 |  |
| 36304944 | Microscopic observation [Identifier] in Placenta by Gram stain | 0.685 |  |
| 3036782 | Glucose [Moles/volume] in Pleural fluid | 0.685 |  |
| 44816653 | Placental growth factor [Mass/volume] in Serum | 0.684 |  |
| 3044762 | Menorrhagia coagulation panel - Platelet poor plasma | 0.683 |  |
| 46234693 | Fetal blood [Volume] in Blood by Flow cytometry (FC) | 0.682 |  |
| 3045788 | Cell count panel - Pleural fluid | 0.682 |  |
| 3031305 | aPTT panel - Platelet poor plasma | 0.681 |  |
| 1617375 | aPTT mixing study panel - Platelet poor plasma | 0.681 |  |
| 3005532 | Lymphocytes/Leukocytes in Pleural fluid | 0.681 |  |
| 3044282 | Cell count and Differential panel - Pleural fluid | 0.681 |  |
| 3012441 | Differential panel - Pleural fluid | 0.677 |  |
| 3020132 | Chylomicrons [Presence] in Serum or Plasma | 0.677 |  |
| 3002256 | Pathology report gross observation | 0.677 |  |
| 36031376 | Chylomicrons [Presence] in Urine | 0.677 |  |
| 40758333 | Macroamylase [Presence] in Pleural fluid | 0.672 |  |
| 36304570 | Microscopic observation [Identifier] in Amniotic fluid by Giemsa stain | 0.658 |  |
| 1091136 | Microscopic observation [Identifier] in Specimen | 0.647 |  |
| 3010190 | Viscosity of Body fluid | 0.646 |  |
| 3043405 | Microscopic observation [Identifier] in Specimen by Non-gynecological cytology method | 0.645 |  |
| 36304247 | Microscopic observation [Identifier] in Amniotic fluid by Gram stain | 0.642 |  |
| 3006595 | Microscopic observation [Identifier] in Genital specimen by Wet preparation | 0.641 |  |
| 3022667 | Microscopic observation [Identifier] in Cervix by Wet preparation | 0.641 |  |
| 3028652 | Viscosity of Blood | 0.639 |  |
| 37019823 | Microscopic observation [Identifier] in Genital specimen by Giemsa stain | 0.634 |  |
| 3042641 | Viscosity of Water | 0.626 |  |
| 3010493 | Viscosity of Serum | 0.621 |  |
| 3041907 | Viscosity of Serum Qualitative | 0.602 |  |
| 3040771 | Viscosity of Synovial fluid | 0.585 |  |
| 3026433 | Viscosity of Synovial fluid Qualitative | 0.583 |  |
| 3040480 | Viscosity of Cerebral spinal fluid Qualitative | 0.572 |  |
| 3040556 | Viscosity of Pleural fluid Qualitative | 0.567 |  |
| 3022436 | Volume of Plasma | 0.567 |  |
| 3043696 | Viscosity of Semen Qualitative | 0.567 | 1856 |
| 646951 | Ideal plasma [Volume] by calculation | 0.557 |  |
| 3038278 | Viscosity of Peritoneal fluid Qualitative | 0.546 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1635 | -omactgc |  | 100% | name | 591 | 100 |  |  |  |  | Chlamydia trachomatis & Neisseria gonorrhoeae DNA [Presence] in Specimen |
| 1636 | -viskos. |  | 100% | name | 1644 | 100 |  |  |  |  | Viscosity [Dynamic viscosity] in Fluid specimen |
| 1637 | b-koboltti | ug/l | 100% | name+unit+values | 157 | 0 | [0.5, 0.7, 0.95, 1.17, 1.75, 2.2, 4.11, 6.21, 10.68] |  | Blood |  | Cobalt [Mass/volume] in Blood |
| 1638 | b-lakteh | mmol/l | 100% | name+unit+values | 345 | 0 | [0.88, 1, 1.19, 1.38, 1.53, 1.66, 1.88, 2.15, 2.77] |  | Blood |  | Lactate [Moles/volume] in Blood |
| 1639 | b-laktevt | mmol/l | 42% | name+unit+values | 408 | 0 | [0.74, 0.85, 1, 1.15, 1.35, 1.54, 1.77, 2.2, 2.94] |  | Blood |  | Lactate [Moles/volume] in Blood |
| 1640 | b-laktevt |  | 58% | name+values | 572 | 100 | [0.73, 0.87, 1.01, 1.15, 1.33, 1.55, 1.74, 2.11, 2.84] |  | Blood |  | Lactate [Moles/volume] in Blood |
| 1641 | b-laktteh | mmol/l | 86% | name+unit+values | 59507 | 0 | [0.7, 0.8, 0.91, 1.03, 1.18, 1.35, 1.59, 1.9, 2.56] |  | Blood |  | Lactate [Moles/volume] in Blood |
| 1642 | b-laktteh |  | 14% | name | 9379 | 100 |  |  | Blood |  | Lactate [Moles/volume] in Blood |
| 1643 | b-ohbutm | mmol/l | 81% | name+unit+values | 422 | 0 | [0.1, 0.16, 0.2, 0.3, 0.51, 0.84, 1.63, 2.94, 4.56] |  | Blood |  | Hydroxybutyrate.beta [Moles/volume] in Blood |
| 1644 | b-ohbutm |  | 19% | name | 99 | 100 |  |  | Blood |  | Hydroxybutyrate.beta [Moles/volume] in Blood |
| 1645 | b-ohbutvt | mmol/l | 87% | name+unit+values | 97 | 0 | [0.1, 0.1, 0.2, 0.2, 0.28, 0.31, 0.7, 1.16, 2.4] |  | Blood |  | Hydroxybutyrate.beta [Moles/volume] in Blood |
| 1646 | b-ohbutvt |  | 13% | name | 14 | 100 |  |  | Blood |  | Hydroxybutyrate.beta [Moles/volume] in Blood |
| 1647 | b-ohbutyr | mmol/l | 74% | name+unit+values | 147 | 0 | [0.1, 0.2, 0.2, 0.3, 0.41, 0.95, 1.64, 2.49, 4.08] | B -Beeta-hydroksibutyraatti | Blood |  | Hydroxybutyrate.beta [Moles/volume] in Blood |
| 1648 | b-ohbutyr |  | 26% | name | 51 | 100 |  | B -Beeta-hydroksibutyraatti | Blood |  | Hydroxybutyrate.beta [Moles/volume] in Blood |
| 1649 | b-sop.koe |  | 100% | name | 174 | 100 |  |  | Blood |  | Crossmatch final [Interpretation] in Blood |
| 1650 | b-sopkoe |  | 100% | name | 662 | 100 |  |  | Blood |  | Crossmatch final [Interpretation] in Blood |
| 1651 | cp-ohbutlb | mmol/l | 100% | name+unit+values | 245 | 0 | [0.1, 0.1, 0.2, 0.2, 0.33, 0.57, 1.04, 1.88, 3.21] |  |  |  | Hydroxybutyrate.beta [Moles/volume] in Plasma |
| 1652 | f-projekti |  | 100% | name | 469 | 100 |  |  | Feces |  |  |
| 1653 | hpvpapctgc |  | 100% | name | 116 | 100 |  |  |  |  | Human papillomavirus DNA and RNA panel - Cervix by NAA |
| 1654 | hpvrefctgc |  | 100% | name | 135 | 100 |  |  |  |  | Human papillomavirus DNA [Identifier] in Cervix |
| 1655 | li-laktteh | mmol/l | 82% | name+unit+values | 299 | 0 | [1.4, 1.5, 1.68, 1.93, 2.14, 2.47, 2.77, 3.15, 4.3] |  | Cerebrospinal fluid |  | Lactate [Moles/volume] in Cerebral spinal fluid |
| 1656 | li-laktteh |  | 18% | name | 65 | 100 |  |  | Cerebrospinal fluid |  | Lactate [Moles/volume] in Cerebral spinal fluid |
| 1657 | mb-k-veka | mmol/l | 96% | name+unit | 2501 | 0 |  |  |  |  | Potassium [Moles/volume] in Mixed venous blood |
| 1658 | mb-k-veka |  | 4% | name | 109 | 100 |  |  |  |  | Potassium [Moles/volume] in Mixed venous blood |
| 1659 | mb-na-veka | mmol/l | 96% | name+unit | 2500 | 0 |  |  |  |  | Sodium [Moles/volume] in Mixed venous blood |
| 1660 | mb-na-veka |  | 4% | name | 108 | 100 |  |  |  |  | Sodium [Moles/volume] in Mixed venous blood |
| 1661 | p-gluveka | mmol/l | 98% | name+unit+values | 1581 | 0 | [4.71, 5.12, 5.39, 5.75, 6.24, 6.95, 7.79, 9.18, 12.1] |  | Plasma |  | Glucose [Moles/volume] in Plasma |
| 1662 | p-gluveka |  | 2% | name | 35 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Plasma |
| 1663 | p-haglund |  | 100% | name | 212 | 100 |  |  | Plasma |  |  |
| 1664 | p-haptog | g/l | 87% | name+unit+values | 20134 | 0 | [0.43, 0.71, 0.93, 1.13, 1.34, 1.56, 1.81, 2.15, 2.66] |  | Plasma |  | Haptoglobin [Mass/volume] in Plasma |
| 1665 | p-haptog |  | 13% | name | 2978 | 100 |  |  | Plasma |  | Haptoglobin [Mass/volume] in Plasma |
| 1666 | p-hbcfdn |  | 100% | name | 3269 | 100 |  |  | Plasma |  | Cell free DNA [Mass/volume] in Plasma |
| 1667 | p-hbcfdna |  | 100% | name | 340 | 100 |  |  | Plasma |  | Cell free DNA [Mass/volume] in Plasma |
| 1668 | p-hyyerik | form | 8% | name+unit | 14 | 0 |  |  | Plasma |  | Coagulation factors panel - Plasma |
| 1669 | p-hyyerik |  | 92% | name | 156 | 100 |  |  | Plasma |  | Coagulation factors panel - Plasma |
| 1670 | p-hyyttek |  | 100% | name | 12967 | 100 |  |  | Plasma |  | Coagulation factors panel - Plasma |
| 1671 | p-k-veka | mmol/l | 96% | name+unit+values | 22023 | 0 | [3.49, 3.69, 3.83, 3.97, 4.08, 4.2, 4.32, 4.51, 4.81] |  | Plasma |  | Potassium [Moles/volume] in Plasma |
| 1672 | p-k-veka |  | 4% | name+values | 965 | 100 | [3.5, 3.8, 3.8, 3.9, 4, 4.15, 4.25, 4.52, 4.72] |  | Plasma |  | Potassium [Moles/volume] in Plasma |
| 1673 | p-laaptct | form | 1% | name+unit | 34 | 0 |  | P -Lupusantikoagulantti, aPTT, varmistus | Plasma |  | Lupus anticoagulant PTT based confirmation [Presence] in Platelet poor plasma |
| 1674 | p-laaptct |  | 99% | name | 6713 | 100 |  | P -Lupusantikoagulantti, aPTT, varmistus | Plasma |  | Lupus anticoagulant PTT based confirmation [Presence] in Platelet poor plasma |
| 1675 | p-laaptva |  | 100% | name | 508 | 100 |  |  | Plasma |  | Lupus anticoagulant PTT based screen [Ratio] in Platelet poor plasma |
| 1676 | p-lakveka | mmol/l | 98% | name+unit+values | 1581 | 0 | [0.89, 1.01, 1.18, 1.3, 1.48, 1.62, 1.82, 2.14, 2.81] |  | Plasma |  | Lactate [Moles/volume] in Plasma |
| 1677 | p-lakveka |  | 2% | name | 36 | 100 |  |  | Plasma |  | Lactate [Moles/volume] in Plasma |
| 1678 | p-larvvct | form | 0% | name+unit | 22 | 0 |  | P -Lupusantikoagulantti, dRVVT, varmistus | Plasma |  | Lupus anticoagulant dRVVT based confirmation [Presence] in Platelet poor plasma |
| 1679 | p-larvvct |  | 100% | name | 6654 | 100 |  | P -Lupusantikoagulantti, dRVVT, varmistus | Plasma |  | Lupus anticoagulant dRVVT based confirmation [Presence] in Platelet poor plasma |
| 1680 | p-larvvva |  | 100% | name | 486 | 100 |  |  | Plasma |  | Lupus anticoagulant dRVVT based screen [Ratio] in Platelet poor plasma |
| 1681 | p-luakptt | form | 0% | name+unit | 7 | 0 |  | P -Lupusantikoagulantti, PTT | Plasma |  | Lupus anticoagulant PTT based screen [Presence] in Platelet poor plasma |
| 1682 | p-luakptt | ratio | 95% | name+unit+values | 3216 | 0 | [0.97, 1, 1.02, 1.03, 1.05, 1.06, 1.09, 1.12, 1.18] | P -Lupusantikoagulantti, PTT | Plasma |  | Lupus anticoagulant PTT based screen [Ratio] in Platelet poor plasma |
| 1683 | p-luakptt |  | 5% | name | 166 | 100 |  | P -Lupusantikoagulantti, PTT | Plasma |  | Lupus anticoagulant PTT based screen in Platelet poor plasma |
| 1684 | p-luakrvv | form | 0% | name+unit | 7 | 0 |  | P -Lupusantikoagulantti, dRVVT | Plasma |  | Lupus anticoagulant dRVVT based screen [Presence] in Platelet poor plasma |
| 1685 | p-luakrvv | ratio | 95% | name+unit+values | 3188 | 0 | [0.89, 0.92, 0.95, 0.97, 0.98, 1.01, 1.03, 1.07, 1.16] | P -Lupusantikoagulantti, dRVVT | Plasma |  | Lupus anticoagulant dRVVT based screen [Ratio] in Platelet poor plasma |
| 1686 | p-luakrvv |  | 5% | name | 166 | 100 |  | P -Lupusantikoagulantti, dRVVT | Plasma |  | Lupus anticoagulant dRVVT based screen in Platelet poor plasma |
| 1687 | p-na-veka | mmol/l | 96% | name+unit+values | 22025 | 0 | [132.75, 135.51, 137, 138.23, 139.24, 140.1, 141.08, 142, 143.75] |  | Plasma |  | Sodium [Moles/volume] in Plasma |
| 1688 | p-na-veka |  | 4% | name+values | 961 | 100 | [132.3, 136, 137.49, 138.3, 140, 141, 141.62, 142, 143.8] |  | Plasma |  | Sodium [Moles/volume] in Plasma |
| 1689 | p-ohbut | mmol/l | 50% | name+unit | 56 | 0 |  | P -Hydroksivoihappo | Plasma |  | Hydroxybutyrate.beta [Moles/volume] in Plasma |
| 1690 | p-ohbut |  | 50% | name | 56 | 100 |  | P -Hydroksivoihappo | Plasma |  | Hydroxybutyrate.beta [Moles/volume] in Plasma |
| 1691 | p-ohbutyr | mmol/l | 75% | name+unit+values | 1065 | 0 | [0.13, 0.2, 0.34, 0.52, 0.77, 1.15, 1.8, 2.55, 3.82] | P -Beeta-hydroksibutyraatti | Plasma |  | Hydroxybutyrate.beta [Moles/volume] in Plasma |
| 1692 | p-ohbutyr |  | 25% | name | 352 | 100 |  | P -Beeta-hydroksibutyraatti | Plasma |  | Hydroxybutyrate.beta [Moles/volume] in Plasma |
| 1693 | p-troptkon | ng/l | 5% | name+unit | 14 | 0 |  |  | Plasma |  | Troponin T [Mass/volume] in Plasma |
| 1694 | p-troptkon |  | 95% | name | 282 | 100 |  |  | Plasma |  | Troponin T [Mass/volume] in Plasma |
| 1695 | p-uraatti | umol/l | 100% | name+unit+values | 6902 | 0.04 | [233.93, 271.59, 300.95, 327.89, 355.46, 383.67, 416.29, 458.67, 519.33] |  | Plasma |  | Urate [Moles/volume] in Plasma |
| 1696 | p-uraatti |  | 0% | name | 32 | 100 |  |  | Plasma |  | Urate [Moles/volume] in Plasma |
| 1697 | p-viskos | mpas | 92% | name+unit+values | 370 | 0 | [1.28, 1.39, 1.46, 1.54, 1.7, 1.84, 2.12, 2.46, 3.05] | P -Viskositeetti | Plasma |  | Viscosity [Dynamic viscosity] in Plasma |
| 1698 | p-viskos |  | 8% | name | 32 | 100 |  | P -Viskositeetti | Plasma |  | Viscosity [Dynamic viscosity] in Plasma |
| 1699 | p-vuotope |  | 100% | name | 147 | 100 |  |  | Plasma |  | Bleeding disorder screening panel - Plasma |
| 1700 | p-vuotot |  | 100% | name | 2075 | 100 |  | P -Vuototaipumuksen selvittely | Plasma |  | Bleeding disorder screening panel - Plasma |
| 1701 | pf-chylus |  | 100% | name | 157 | 100 |  |  | Pleural fluid |  | Chyle [Presence] in Pleural fluid |
| 1702 | pf-laktteh | mmol/l | 84% | name+unit+values | 350 | 0 | [1.1, 1.31, 1.51, 1.78, 2.06, 2.43, 2.98, 3.98, 5.91] |  | Pleural fluid |  | Lactate [Moles/volume] in Pleural fluid |
| 1703 | pf-laktteh |  | 16% | name | 69 | 100 |  |  | Pleural fluid |  | Lactate [Moles/volume] in Pleural fluid |
| 1704 | pf-phglula |  | 100% | name | 168 | 100 |  |  | Pleural fluid |  | pH and Glucose and Lactate panel - Pleural fluid |
| 1705 | ph(akt) | ph | 98% | name+unit+values | 9848 | 0 | [7.34, 7.36, 7.37, 7.38, 7.39, 7.4, 7.41, 7.42, 7.44] |  |  |  | pH [pH] in Blood |
| 1706 | ph(akt) |  | 2% | name | 238 | 100 |  |  |  |  | pH [pH] in Blood |
| 1707 | phakt. | ph | 100% | name+unit+values | 140 | 0 | [7.35, 7.37, 7.38, 7.39, 7.4, 7.4, 7.42, 7.43, 7.44] |  |  |  | pH [pH] in Blood |
| 1708 | projekti1 |  | 100% | name | 160 | 100 |  |  |  |  |  |
| 1709 | pt-dehglur |  | 100% | name | 168 | 100 |  |  | Patient |  | Dehydroepiandrosterone sulfate [Moles/volume] in Serum or Plasma |
| 1710 | pt-hyytek |  | 100% | name | 106 | 100 |  |  | Patient |  | Coagulation factors panel - Plasma |
| 1711 | s-17hprog | nmol/l | 91% | name+unit+values | 645 | 0 | [0.62, 0.98, 1.4, 1.88, 2.53, 3.71, 5.41, 12.39, 77.92] | S -Hydroksiprogesteroni (17-) | Serum |  | 17-Hydroxyprogesterone [Moles/volume] in Serum or Plasma |
| 1712 | s-17hprog |  | 9% | name | 61 | 100 |  | S -Hydroksiprogesteroni (17-) | Serum |  | 17-Hydroxyprogesterone [Moles/volume] in Serum or Plasma |
| 1713 | s-haglund |  | 100% | name | 216 | 100 |  |  | Serum |  |  |
| 1714 | s-haptog | g/l | 88% | name+unit+values | 11553 | 0 | [0.48, 0.72, 0.93, 1.13, 1.33, 1.55, 1.82, 2.16, 2.71] | S -Haptoglobiini | Serum |  | Haptoglobin [Mass/volume] in Serum or Plasma |
| 1715 | s-haptog |  | 12% | name | 1634 | 100 |  | S -Haptoglobiini | Serum |  | Haptoglobin [Mass/volume] in Serum or Plasma |
| 1716 | s-havtot |  | 100% | name | 3549 | 100 |  |  | Serum |  | Hepatitis A virus Ab.total [Presence] in Serum |
| 1717 | s-hbvtut |  | 100% | name | 509 | 100 |  |  | Serum |  | Hepatitis B virus serology panel - Serum |
| 1718 | s-hivab+tod |  | 100% | name | 172 | 100 |  |  | Serum |  | HIV 1 & 2 Ag+Ab panel - Serum or Plasma |
| 1719 | s-ph(akt) | ph | 99% | name+unit+values | 114319 | 0 | [7.34, 7.36, 7.38, 7.39, 7.4, 7.41, 7.42, 7.43, 7.45] |  | Serum |  | pH [pH] in Blood |
| 1720 | s-ph(akt) |  | 1% | name | 1327 | 100 |  |  | Serum |  | pH [pH] in Blood |
| 1721 | s-tbetot | titre | 13% | name+unit+values | 90 | 2.22 | [20, 20, 40, 40, 80, 80, 160, 320, 960] |  | Serum |  | Tick-borne encephalitis virus Ab.total [Titer] in Serum |
| 1722 | s-tbetot |  | 87% | name | 604 | 100 |  |  | Serum |  | Tick-borne encephalitis virus Ab.total in Serum |
| 1723 | s-uraatti | umol/l | 94% | name+unit+values | 621 | 0 | [232.57, 257.68, 279.43, 297.99, 317.54, 343.17, 366.8, 401.68, 449.76] |  | Serum |  | Urate [Moles/volume] in Serum or Plasma |
| 1724 | s-uraatti |  | 6% | name | 38 | 100 |  |  | Serum |  | Urate [Moles/volume] in Serum or Plasma |
| 1725 | s-valproaatti | umol/l | 96% | name+unit+values | 431 | 0 | [242.9, 309.2, 356.11, 396.55, 425.09, 467.35, 503.25, 551.17, 625.19] |  | Serum |  | Valproate [Moles/volume] in Serum or Plasma |
| 1726 | s-valproaatti |  | 4% | name | 16 | 100 |  |  | Serum |  | Valproate [Moles/volume] in Serum or Plasma |
| 1727 | ts-abortti |  | 100% | name | 315 | 100 |  | Ts-Aborttikudoksen dissektiotutkimus | Tissue |  | Gross observation [Identifier] in Products of conception |
| 1728 | u-omactgc |  | 100% | name | 480 | 100 |  |  | Urine |  | Chlamydia trachomatis & Neisseria gonorrhoeae DNA [Presence] in Urine |
| 1729 | uraatti | umol/l | 99% | name+unit+values | 3560 | 0 | [230.36, 267.65, 298.52, 325.92, 354.53, 382.52, 413.88, 454.99, 511.79] |  |  |  | Urate [Moles/volume] in Serum or Plasma |
| 1730 | uraatti |  | 1% | name | 19 | 100 |  |  |  |  | Urate [Moles/volume] in Serum or Plasma |

