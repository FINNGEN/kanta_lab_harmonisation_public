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
Here is group 70.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000285 | Sodium [Moles/volume] in Blood | 1.000 | 129 |
| 3000963 | Hemoglobin [Mass/volume] in Blood | 1.000 | 2 |
| 3005456 | Potassium [Moles/volume] in Blood | 1.000 | 106 |
| 3013676 | Sertraline [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3016759 | Leptospira sp Ab [Presence] in Serum | 1.000 |  |
| 3017461 | Flecainide [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3018572 | Chloride [Moles/volume] in Blood | 1.000 | 295 |
| 3019406 | Latex IgE Ab [Units/volume] in Serum | 1.000 | 1426 |
| 3020491 | Glucose [Moles/volume] in Blood | 1.000 | 13 |
| 3021367 | Citalopram [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3027165 | Pistachio IgE Ab [Units/volume] in Serum | 1.000 | 1583 |
| 3038026 | Centromere Ab [Units/volume] in Serum | 1.000 |  |
| 3041230 | Basic metabolic panel - Blood | 1.000 |  |
| 3042341 | Yersinia pseudotuberculosis Ab [Presence] in Serum | 1.000 |  |
| 40762887 | Creatinine [Moles/volume] in Blood | 1.000 | 283 |
| 43534077 | Urea [Moles/volume] in Blood | 1.000 |  |
| 3011436 | Histone Ab [Units/volume] in Serum | 0.983 |  |
| 3009542 | Hematocrit [Volume Fraction] of Blood | 0.979 | 28 |
| 3010370 | Gastrin [Moles/volume] in Serum or Plasma | 0.968 |  |
| 3004419 | Cephalexin [Mass/volume] in Serum or Plasma | 0.967 |  |
| 1761381 | Pistachio IgG Ab [Units/volume] in Serum | 0.956 |  |
| 36032269 | Testosterone Free [Moles/volume] in Serum or Plasma by calculation | 0.956 |  |
| 36305790 | Ustekinumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.954 |  |
| 3017446 | Testosterone [Moles/volume] in Serum or Plasma | 0.952 | 203 |
| 648992 | SAE-1 Ab [Presence] in Serum or Plasma | 0.951 |  |
| 3009841 | Latex IgE Ab [Units/volume] in Blood | 0.951 |  |
| 3017304 | Leptospira sp Ab [Presence] in Serum by Agglutination | 0.947 |  |
| 3008616 | Leptospira sp Ab [Presence] in Serum by Immunoassay | 0.947 |  |
| 649373 | Pistachio IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.946 |  |
| 3017816 | Listeria sp Ab [Presence] in Serum | 0.945 |  |
| 3001190 | Centromere Ab [Units/volume] in Body fluid | 0.941 |  |
| 40762632 | Urea nitrogen [Moles/volume] in Blood | 0.941 |  |
| 3040944 | Yersinia pseudotuberculosis 3 Ab [Titer] in Serum | 0.940 |  |
| 3024614 | Yersinia enterocolitica O:3 Ab [Titer] in Serum | 0.940 |  |
| 40762028 | Yersinia pseudotuberculosis Ab [Presence] in Serum by Agglutination | 0.940 |  |
| 3011736 | Yersinia pseudotuberculosis Ab [Titer] in Serum | 0.939 |  |
| 3046175 | Histone Ab [Units/volume] in Serum by Immunoassay | 0.938 |  |
| 3018301 | Testosterone Free [Moles/volume] in Serum or Plasma | 0.937 | 325 |
| 46235781 | Urea [Moles/volume] in Serum, Plasma or Blood | 0.936 |  |
| 3030552 | Citalopram [Mass/volume] in Serum or Plasma | 0.935 |  |
| 3000244 | Sertraline [Mass/volume] in Serum or Plasma | 0.934 |  |
| 3009519 | Leptospira interrogans Ab [Presence] in Serum | 0.933 |  |
| 3028146 | Bartonella henselae Ab [Titer] in Serum | 0.932 |  |
| 46235783 | Chloride [Moles/volume] in Serum, Plasma or Blood | 0.931 |  |
| 46235076 | Creatinine [Moles/volume] in Serum, Plasma or Blood | 0.930 |  |
| 36303722 | Certolizumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.929 |  |
| 43534101 | Urea [Moles/volume] in Arterial blood | 0.928 |  |
| 3006689 | Flecainide [Mass/volume] in Serum or Plasma | 0.927 |  |
| 646468 | Centromere Ab [Measurement] in Serum | 0.927 |  |
| 3040917 | Yersinia enterocolitica Ab [Presence] in Serum | 0.924 |  |
| 3026725 | Estradiol (E2) [Moles/volume] in Serum or Plasma | 0.922 | 231 |
| 3039162 | Centromere protein B Ab [Units/volume] in Serum | 0.921 | 985 |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.920 |  |
| 43534100 | Urea [Moles/volume] in Venous blood | 0.920 |  |
| 3039295 | Pistachio IgE Ab/IgE total in Serum | 0.920 |  |
| 3042033 | Yersinia sp Ab [Presence] in Serum | 0.920 |  |
| 3014720 | Leptospira sp IgG Ab [Presence] in Serum | 0.919 |  |
| 46235078 | Potassium [Moles/volume] in Serum, Plasma or Blood | 0.919 |  |
| 3017779 | Centromere IgG Ab [Units/volume] in Serum | 0.919 |  |
| 36305389 | Ustekinumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.917 |  |
| 3034208 | Histone IgG Ab [Units/volume] in Serum | 0.916 |  |
| 648568 | Histone Ab [Measurement] in Serum | 0.916 |  |
| 3043723 | Beta 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.915 |  |
| 3043706 | Sodium [Moles/volume] in Arterial blood | 0.914 |  |
| 3043747 | Beta 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.913 |  |
| 3040926 | Yersinia pseudotuberculosis 1 Ab [Titer] in Serum | 0.912 |  |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.912 |  |
| 3009810 | Urea [Mass/volume] in Blood | 0.912 |  |
| 648296 | Pistachio IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.912 |  |
| 3012052 | Histone H2a+H2b Ab [Units/volume] in Serum | 0.912 |  |
| 3015575 | Latex IgG Ab [Units/volume] in Serum | 0.911 |  |
| 40765842 | Pistachio IgG Ab [Mass/volume] in Serum | 0.911 |  |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.911 |  |
| 3038981 | Yersinia enterocolitica O:3 Ab [Titer] in Serum by Agglutination | 0.911 |  |
| 3964702 | Creatinine [Moles/volume] in Venous blood | 0.910 |  |
| 3033099 | Centromere Ab [Titer] in Serum | 0.910 |  |
| 3045806 | Bartonella sp Ab [Presence] in Serum | 0.910 |  |
| 3043409 | Potassium [Moles/volume] in Arterial blood | 0.909 |  |
| 3009508 | Creatinine [Moles/volume] in Urine | 0.907 | 161 |
| 3041354 | Potassium [Moles/volume] in Venous blood | 0.906 |  |
| 3021330 | Testes IgG Ab [Titer] in Serum | 0.905 |  |
| 3031248 | Chloride [Moles/volume] in Arterial blood | 0.905 |  |
| 3001151 | Sole IgE Ab [Units/volume] in Serum | 0.905 |  |
| 3040617 | Yersinia pseudotuberculosis 2 Ab [Titer] in Serum | 0.904 |  |
| 40759481 | Pistachio IgG4 Ab [Mass/volume] in Serum | 0.904 |  |
| 3023626 | Latex Bencard IgE Ab [Units/volume] in Serum | 0.903 |  |
| 3035285 | Chloride [Moles/volume] in Venous blood | 0.903 |  |
| 3012898 | Urea [Moles/volume] in Urine | 0.903 |  |
| 3015869 | Leptospira sp IgM Ab [Presence] in Serum | 0.903 |  |
| 40763350 | Citalopram [Moles/volume] in Specimen | 0.902 |  |
| 3040151 | Glucose [Moles/volume] in Capillary blood | 0.901 |  |
| 3965349 | Certolizumab Ab [Mass/volume] in Serum or Plasma by SPR | 0.900 |  |
| 3004238 | Bartonella henselae IgG Ab [Titer] in Serum | 0.900 | 1643 |
| 646146 | Yersinia pseudotuberculosis Ab [Measurement] in Serum | 0.900 |  |
| 42868681 | Estrogen [Moles/volume] in Serum or Plasma | 0.899 | 920 |
| 3035630 | Yersinia enterocolitica O:3 Ab [Titer] in Specimen | 0.899 |  |
| 3028504 | Yersinia enterocolitica O:9 Ab [Titer] in Serum | 0.898 |  |
| 3004664 | Listeria sp Ab [Presence] in Serum by Agglutination | 0.897 |  |
| 3020779 | Urea [Moles/volume] in Serum or Plasma | 0.897 |  |
| 3038714 | Yersinia pseudotuberculosis Ab [Titer] in Serum by Agglutination | 0.897 |  |
| 3008108 | Hematocrit [Volume Fraction] of Body fluid | 0.896 | 733 |
| 3965878 | Ustekinumab [Mass/volume] in Serum or Plasma by Immunoassay --trough | 0.896 |  |
| 3038702 | Sodium [Moles/volume] in Capillary blood | 0.895 |  |
| 646367 | Leptospira sp Ab [Measurement] in Serum | 0.895 |  |
| 3019266 | Cefonicid [Mass/volume] in Serum or Plasma | 0.895 |  |
| 3044242 | Glucose [Moles/volume] in Arterial blood | 0.894 |  |
| 3002670 | Multiple inhalant allergen IgE Ab [Units/volume] in Serum | 0.894 |  |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 0.894 | 1 |
| 3038515 | Glucose [Moles/volume] in Venous blood | 0.894 |  |
| 3022810 | Sodium [Moles/volume] in Body fluid | 0.893 |  |
| 3037459 | Creatinine [Moles/volume] in Body fluid | 0.893 | 1234 |
| 3041603 | Yersinia enterocolitica IgG Ab [Presence] in Serum | 0.893 |  |
| 21492784 | Miscellaneous allergen IgE Ab [Units/volume] in Serum | 0.893 |  |
| 3023849 | Yersinia enterocolitica Ab [Titer] in Serum | 0.893 |  |
| 3023949 | Allscale IgE Ab [Units/volume] in Serum | 0.893 |  |
| 3014594 | Urea [Moles/volume] in Body fluid | 0.892 |  |
| 3006862 | Bartonella henselae IgM Ab [Titer] in Serum | 0.891 | 1749 |
| 3039964 | Chloride [Moles/volume] in Capillary blood | 0.891 |  |
| 3024218 | Fig IgE Ab [Units/volume] in Serum | 0.891 |  |
| 3039817 | Yersinia enterocolitica IgA Ab [Presence] in Serum | 0.891 |  |
| 3038842 | Yersinia enterocolitica O:9 Ab [Presence] in Serum | 0.891 |  |
| 3023822 | Latex glove extract IgE Ab [Units/volume] in Serum | 0.890 |  |
| 3039012 | Yersinia enterocolitica O:5 Ab [Presence] in Serum | 0.890 |  |
| 3007165 | Listeria monocytogenes Ab [Titer] in Serum | 0.890 |  |
| 3013194 | Chloride [Moles/volume] in Body fluid | 0.889 |  |
| 3043688 | Hemoglobin [Mass/volume] in Body fluid | 0.888 |  |
| 3013765 | Hay IgE Ab [Units/volume] in Serum | 0.888 |  |
| 1091804 | Beta globulin [Mass/volume] in Serum or Plasma | 0.888 |  |
| 3004679 | Leptospira sp IgG Ab [Presence] in Serum by Immunoassay | 0.888 |  |
| 3014576 | Chloride [Moles/volume] in Serum or Plasma | 0.888 | 8 |
| 3017421 | Leptospira sp Ab [Titer] in Serum | 0.887 |  |
| 21493395 | Cefuroxime [Mass/volume] in Serum or Plasma | 0.887 |  |
| 3027484 | Hemoglobin [Mass/volume] in Blood by calculation | 0.887 |  |
| 3014735 | Leptospira interrogans Ab [Presence] in Serum by Agglutination | 0.886 |  |
| 3011742 | Histone IgG Ab [Units/volume] in Serum by Immunoassay | 0.886 |  |
| 3023103 | Potassium [Moles/volume] in Serum or Plasma | 0.885 | 3 |
| 648413 | Listeria monocytogenes Ab [Measurement] in Serum | 0.885 |  |
| 3051825 | Creatinine [Mass/volume] in Blood | 0.884 |  |
| 3009927 | Gastrin [Mass/volume] in Serum or Plasma | 0.882 | 1411 |
| 3036243 | Potassium [Moles/volume] in Body fluid | 0.881 |  |
| 3035729 | Glucose [Moles/volume] in Body fluid | 0.881 | 788 |
| 3000279 | Paper IgE Ab [Units/volume] in Serum | 0.881 |  |
| 3966536 | Testosterone Free [Mass/volume] in Serum or Plasma by Calculation | 0.880 |  |
| 3002173 | Hemoglobin [Mass/volume] in Arterial blood | 0.880 | 188 |
| 3051059 | Bartonella elizabethae IgG Ab [Titer] in Serum | 0.879 |  |
| 3013708 | Smelt IgE Ab [Units/volume] in Serum | 0.879 |  |
| 3050447 | Bartonella vinsonii berkhoffii IgG Ab [Titer] in Serum | 0.878 |  |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 0.878 | 5 |
| 3050765 | Latex IgE Ab/IgE total in Serum | 0.878 |  |
| 40758648 | Testosterone [Moles/volume] in Serum or Plasma --baseline | 0.877 |  |
| 3040893 | Potassium [Moles/volume] in Capillary blood | 0.877 |  |
| 3030664 | Beta 1 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.877 |  |
| 3014825 | Centromere Ab [Presence] in Serum | 0.876 |  |
| 3026726 | Creatinine [Moles/volume] in Specimen | 0.876 |  |
| 3005322 | IgE [Units/volume] in Serum or Plasma | 0.876 | 466 |
| 3035161 | Testosterone [Moles/volume] in Urine | 0.876 |  |
| 44816802 | Sertraline [Mass/volume] in Serum or Plasma --trough | 0.876 |  |
| 40762331 | Testosterone [Moles/volume] in Body fluid | 0.876 |  |
| 3003705 | Cefaclor [Mass/volume] in Serum or Plasma | 0.876 |  |
| 3030847 | Flecainide [Mass/volume] in Serum or Plasma --trough | 0.876 |  |
| 3048246 | Bartonella vinsonii berkhoffii IgM Ab [Titer] in Serum | 0.876 |  |
| 3002774 | Cephalothin [Mass/volume] in Serum or Plasma | 0.875 |  |
| 648525 | Sertraline [Measurement] in Serum or Plasma | 0.875 |  |
| 36304315 | Certolizumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.875 |  |
| 1091897 | Risankizumab [Mass/volume] in Serum or Plasma | 0.875 |  |
| 3036255 | Didesmethylcitalopram [Moles/volume] in Serum or Plasma | 0.875 |  |
| 3014599 | Egg white IgE Ab [Units/volume] in Serum | 0.875 | 799 |
| 3043528 | Bartonella sp IgG Ab [Units/volume] in Serum | 0.875 |  |
| 3028471 | Vanilla IgE Ab [Units/volume] in Serum | 0.874 |  |
| 3023230 | Hematocrit [Volume Fraction] of Arterial blood | 0.874 |  |
| 36305036 | Ustekinumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.874 |  |
| 40761859 | Histone Ab [Presence] in Serum by Immunoassay | 0.873 |  |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 0.873 | 4 |
| 3030947 | Beta 1 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.873 |  |
| 3044821 | Beta 2 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.872 |  |
| 3053318 | Bartonella elizabethae IgM Ab [Titer] in Serum | 0.872 |  |
| 3004622 | Cefotaxime [Mass/volume] in Serum or Plasma | 0.871 |  |
| 3014277 | Listeria monocytogenes Ab [Units/volume] in Serum | 0.871 |  |
| 3000483 | Glucose [Mass/volume] in Blood | 0.871 |  |
| 40762946 | Citalopram [Moles/volume] in Urine | 0.871 |  |
| 3017497 | Pine Nut IgE Ab [Units/volume] in Serum | 0.870 |  |
| 3046837 | Bartonella sp IgM Ab [Units/volume] in Serum | 0.870 |  |
| 46235168 | Fasting glucose [Moles/volume] in Blood | 0.870 |  |
| 3035294 | Centromere Ab [Titer] in Body fluid | 0.870 |  |
| 42529528 | Centromere protein B Ab [Units/volume] in Serum by Line blot | 0.870 |  |
| 3014339 | Estrone (E1) [Moles/volume] in Serum or Plasma | 0.869 | 1123 |
| 3019495 | Cefoperazone [Mass/volume] in Serum or Plasma | 0.869 |  |
| 645204 | Flecainide [Measurement] in Serum or Plasma | 0.868 |  |
| 3021886 | Globulin [Mass/volume] in Serum | 0.868 | 83 |
| 3004295 | Urea nitrogen [Mass/volume] in Blood | 0.867 | 288 |
| 3051467 | Cefepime [Mass/volume] in Serum or Plasma | 0.867 |  |
| 3030972 | Beta 2 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.866 |  |
| 645787 | Guselkumab [Mass/volume] in Serum or Plasma | 0.866 |  |
| 3018086 | Chloride [Moles/volume] in Red Blood Cells | 0.865 |  |
| 648928 | Centromere Ab [Measurement] in Body fluid | 0.865 |  |
| 3004290 | Testosterone [Moles/volume] in Semen | 0.864 |  |
| 3000149 | Gastrin [Moles/volume] in Serum or Plasma --post meal | 0.864 |  |
| 3014565 | Sertraline [Presence] in Serum or Plasma | 0.863 |  |
| 42529563 | Testosterone [Moles/volume] in Serum or Plasma by Immunoassay | 0.863 |  |
| 1092223 | Testosterone [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.863 |  |
| 3027439 | Cephapirin [Mass/volume] in Serum or Plasma | 0.861 |  |
| 3044052 | Escitalopram [Mass/volume] in Serum or Plasma | 0.861 |  |
| 40758903 | Hemoglobin [Mass/volume] in Blood by Oximetry | 0.861 |  |
| 3019909 | Hematocrit [Volume Fraction] of Blood by Centrifugation | 0.861 | 545 |
| 3038571 | Testosterone.free+weakly bound [Moles/volume] in Serum or Plasma | 0.860 |  |
| 42529527 | Centromere protein A Ab [Units/volume] in Serum by Line blot | 0.860 |  |
| 21490733 | Potassium [Mass/volume] in Blood | 0.860 |  |
| 3002613 | Cefadroxil [Mass/volume] in Serum or Plasma | 0.860 |  |
| 21492571 | Gastrin [Moles/volume] in Serum or Plasma --pre XXX challenge | 0.860 |  |
| 3044606 | Estradiol (E2) [Moles/volume] in Urine | 0.859 |  |
| 3022493 | Free Hemoglobin [Mass/volume] in Plasma | 0.859 | 1917 |
| 3022857 | Norsertraline [Mass/volume] in Serum or Plasma | 0.859 |  |
| 3006184 | Hemoglobin [Mass/volume] in Capillary blood | 0.858 |  |
| 645566 | Listeria sp Ab [Measurement] in Serum | 0.858 |  |
| 3038248 | Deoxyhemoglobin [Mass/volume] in Blood | 0.858 |  |
| 42529214 | Estradiol (E2) [Moles/volume] in Serum or Plasma by Immunoassay | 0.858 |  |
| 3046681 | Beta 2 globulin+Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.857 |  |
| 3028813 | Hematocrit [Volume Fraction] of Capillary blood | 0.857 |  |
| 3028373 | Gastrin.17 residue fragment [Mass/volume] in Serum or Plasma | 0.857 |  |
| 3000636 | Histone Ab [Presence] in Serum | 0.856 |  |
| 40758605 | Estradiol (E2) [Moles/volume] in Serum or Plasma --baseline | 0.855 |  |
| 3012494 | Peanut IgE Ab [Units/volume] in Serum | 0.855 | 611 |
| 3040418 | Listeria monocytogenes H Ab [Titer] in Serum | 0.853 |  |
| 3001838 | Sodium [Moles/volume] in Red Blood Cells | 0.853 |  |
| 42869583 | Hematocrit [Pure volume fraction] of Body fluid | 0.853 |  |
| 3029612 | Listeria sp Ab [Titer] in Serum | 0.852 |  |
| 3037869 | Flecainide [Presence] in Serum or Plasma | 0.852 |  |
| 3004119 | Hemoglobin [Mass/volume] in Venous blood | 0.852 | 1986 |
| 3034976 | Hematocrit [Volume Fraction] of Venous blood | 0.852 |  |
| 3003181 | Sodium [Moles/volume] in Urine | 0.851 | 412 |
| 40758979 | Estradiol (E2) [Moles/volume] in Body fluid | 0.850 |  |
| 3012631 | Estriol (E3) [Moles/volume] in Serum or Plasma | 0.849 | 1565 |
| 43534046 | Estradiol (E2) [Moles/volume] in Serum or Plasma by High sensitivity method | 0.849 |  |
| 40757484 | Beta 1 globulin [Mass/volume] in Urine by Electrophoresis | 0.849 |  |
| 3027401 | Testosterone Free/Testosterone.total in Serum or Plasma | 0.849 | 707 |
| 3012584 | Beta 2 glycoprotein 1 [Mass/volume] in Serum or Plasma | 0.848 |  |
| 3016049 | Testosterone Free [Mass/volume] in Serum or Plasma | 0.848 |  |
| 3004945 | Histone H2a+H2b Ab [Units/volume] in Serum by Immunofluorescence | 0.848 |  |
| 649281 | Histone IgG Ab [Measurement] in Serum | 0.848 |  |
| 3016031 | Almond IgE Ab [Units/volume] in Serum | 0.847 | 1024 |
| 1091762 | Alpha 1 globulin [Mass/volume] in Serum or Plasma | 0.847 |  |
| 40757485 | Beta 2 globulin [Mass/volume] in Urine by Electrophoresis | 0.846 |  |
| 3009482 | Gastrin [Mass/volume] in Serum or Plasma --fasting | 0.846 |  |
| 40760154 | Cow milk Ab [Presence] in Serum by Immune diffusion (ID) | 0.846 |  |
| 3050746 | Hematocrit [Volume Fraction] of Blood by Estimated | 0.846 |  |
| 40762351 | Hemoglobin [Moles/volume] in Blood | 0.846 |  |
| 3020043 | Norcitalopram [Moles/volume] in Serum or Plasma | 0.846 |  |
| 3009024 | Chloride [Moles/volume] in Specimen | 0.845 |  |
| 3013823 | Potassium [Moles/volume] in Red Blood Cells | 0.845 |  |
| 3007733 | Chloride [Moles/volume] in Urine | 0.844 | 697 |
| 44786774 | Adalimumab [Mass/volume] in Serum or Plasma | 0.844 |  |
| 3016038 | Potassium [Moles/volume] in Urine | 0.844 | 493 |
| 3026681 | Sodium [Moles/volume] in Specimen | 0.843 |  |
| 3038680 | Listeria monocytogenes O1 Ab [Titer] in Serum | 0.843 |  |
| 3036664 | Testosterone Free [Moles/volume] in Serum or Plasma by Radioimmunoassay (RIA) | 0.843 | 1710 |
| 43055420 | Beta globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.843 |  |
| 40762947 | Citalopram [Moles/volume] in Gastric fluid | 0.842 |  |
| 648944 | Centromere protein B Ab [Measurement] in Serum | 0.842 |  |
| 3039255 | Listeria monocytogenes H1 Ab [Titer] in Serum | 0.842 |  |
| 3013201 | Beta-2-Microglobulin [Mass/volume] in Serum or Plasma | 0.841 | 783 |
| 3006893 | Glucose [Moles/volume] in Specimen | 0.841 |  |
| 3002602 | Gastrin [Moles/volume] in Serum or Plasma --pre 0.2 U/kg secretin | 0.840 |  |
| 44816560 | Sertraline [Mass/volume] in Urine | 0.840 |  |
| 3008893 | Testosterone [Mass/volume] in Serum or Plasma | 0.840 |  |
| 3025285 | Estradiol (E2) [Mass/volume] in Serum or Plasma | 0.840 |  |
| 40771562 | Chronic urticaria index panel - Serum or Plasma | 0.840 |  |
| 645874 | Centromere IgG Ab [Measurement] in Serum | 0.839 |  |
| 40759035 | Beta 1 globulin [Mass/volume] in Cerebral spinal fluid by Electrophoresis | 0.839 |  |
| 40762892 | Gastrin [Mass/volume] in Serum or Plasma --baseline | 0.839 |  |
| 3965476 | Ustekinumab and Ustekinumab Ab panel - Serum or Plasma | 0.838 |  |
| 3029203 | Beta 1 globulin/Protein.total in Body fluid by Electrophoresis | 0.838 |  |
| 42869584 | Hematocrit [Pure volume fraction] of Venous blood | 0.836 |  |
| 3026864 | Gastrin [Moles/volume] in Serum or Plasma --1st specimen post XXX challenge | 0.835 |  |
| 42868714 | Testosterone Free [Moles/volume] in Serum or Plasma by Detection limit <= 3.47 pmol/L | 0.835 | 1753 |
| 3013539 | Creatinine [Moles/volume] in 24 hour Urine | 0.834 | 1978 |
| 3030596 | Flecainide [Mass/volume] in Serum or Plasma --peak | 0.833 |  |
| 44786752 | Didesmethylcitalopram [Mass/volume] in Serum or Plasma | 0.832 |  |
| 3029451 | Beta 2 globulin/Protein.total in Body fluid by Electrophoresis | 0.832 |  |
| 3003351 | S Ab [Presence] in Serum or Plasma | 0.832 |  |
| 3044070 | Beta 2 globulin+Gamma globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.832 |  |
| 3966740 | Gastrin 34 [Moles/volume] in Serum or Plasma by LC/MS/MS | 0.831 |  |
| 3027994 | Gastrin [Moles/volume] in Serum or Plasma --3rd specimen post XXX challenge | 0.829 |  |
| 3010969 | Propafenone [Moles/volume] in Serum or Plasma | 0.824 |  |
| 36304617 | Golimumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.822 |  |
| 36031836 | Tocilizumab [Mass/volume] in Serum | 0.822 |  |
| 40768031 | Sc1 Ab [Presence] in Serum or Plasma | 0.821 |  |
| 3042299 | inFLIXimab [Mass/volume] in Serum or Plasma | 0.821 |  |
| 3016598 | A1 Ab [Presence] in Serum or Plasma | 0.820 |  |
| 3052928 | Testosterone [Moles/volume] in Saliva (oral fluid) | 0.820 |  |
| 3041847 | Casein IgG Ab [Presence] in Serum | 0.818 |  |
| 3018327 | Chicken serum Ab [Presence] in Serum | 0.817 |  |
| 40762310 | Testosterone [Moles/volume] in Pleural fluid | 0.815 |  |
| 3040006 | Creatinine [Moles/volume] in 12 hour Urine | 0.813 |  |
| 3039985 | Beta lactoglobulin IgG Ab [Presence] in Serum | 0.813 |  |
| 36305075 | Vedolizumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.812 |  |
| 3044866 | Ovary Ab [Titer] in Serum | 0.812 |  |
| 3030943 | Beta 1 globulin/Protein.total in Urine by Electrophoresis | 0.812 |  |
| 3036317 | Flecainide [Mass/volume] in Urine | 0.811 |  |
| 3037118 | Maprotiline [Moles/volume] in Serum or Plasma | 0.811 |  |
| 40758683 | Mirtazapine [Moles/volume] in Serum or Plasma | 0.810 |  |
| 3025883 | Mexiletine [Moles/volume] in Serum or Plasma | 0.810 |  |
| 3042570 | Tocainide [Moles/volume] in Serum or Plasma | 0.808 |  |
| 42529564 | Testosterone [Mass/volume] in Serum or Plasma by Immunoassay | 0.808 |  |
| 3026480 | Teichoate Ab [Titer] in Serum | 0.808 |  |
| 1175178 | Eculizumab [Mass/volume] in Serum | 0.808 |  |
| 3050937 | sp100 Ab [Presence] in Serum | 0.808 |  |
| 3039396 | Lactalbumin alpha IgG Ab [Presence] in Serum | 0.807 |  |
| 42868713 | Testosterone [Moles/volume] in Serum or Plasma by Detection limit <= 3.47 pmol/L | 0.806 | 1740 |
| 3005256 | PM-1 Ab [Presence] in Serum | 0.804 |  |
| 3030638 | Beta 2 globulin/Protein.total in Urine by Electrophoresis | 0.803 |  |
| 3039759 | Lactoferrin Ab [Presence] in Serum | 0.802 |  |
| 3013055 | A Ab [Presence] in Serum or Plasma | 0.801 |  |
| 43055419 | Beta globulin/Protein.total [Pure mass fraction] in Urine by Electrophoresis | 0.801 |  |
| 40758467 | Sd sup(a) Ab [Presence] in Serum or Plasma | 0.801 |  |
| 43055424 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.801 |  |
| 3023837 | Testosterone.free+weakly bound/Testosterone.total in Serum or Plasma | 0.799 | 1224 |
| 3017800 | H Ab [Presence] in Serum | 0.797 |  |
| 3050153 | Food allergen panel - Serum | 0.795 |  |
| 3964676 | Basic metabolic and hematocrit panel - Blood | 0.790 |  |
| 3023661 | A Ab [Titer] in Serum or Plasma | 0.790 |  |
| 3006806 | B Ab [Titer] in Serum or Plasma | 0.790 |  |
| 3966040 | Es^a Ab [Presence] in Serum or Plasma | 0.789 |  |
| 3027511 | Gastrin [Moles/volume] in Serum or Plasma --7th specimen post XXX challenge | 0.789 |  |
| 3024330 | Gastrin.14 residue fragment [Mass/volume] in Serum or Plasma | 0.788 |  |
| 3028565 | Gastrin [Moles/volume] in Serum or Plasma --9th specimen post XXX challenge | 0.788 |  |
| 36031523 | Indoor respiratory allergen IgE panel - Serum | 0.787 |  |
| 3020811 | Streptococcus sp Ab [Presence] in Serum | 0.783 |  |
| 3029448 | S Ab [Titer] in Serum or Plasma | 0.783 |  |
| 3010312 | Streptococcus sp Ab [Titer] in Serum | 0.780 |  |
| 3030313 | Adrenal Ab [Titer] in Serum | 0.779 |  |
| 3044338 | C Ab [Titer] in Serum or Plasma | 0.778 |  |
| 3031458 | I Ab [Titer] in Serum or Plasma | 0.777 |  |
| 40766101 | Chronic urticaria index in Serum | 0.776 |  |
| 1092321 | Egg White IgE Panel - Serum | 0.775 |  |
| 40766216 | Nut allergen panel - Serum | 0.774 |  |
| 3009684 | Actinomyces sp Ab [Titer] in Serum | 0.772 |  |
| 3022539 | Spermatozoa Ab [Presence] in Serum | 0.772 |  |
| 3005011 | Chlamydia sp Ab [Titer] in Serum | 0.772 |  |
| 40761116 | Natalizumab Ab [Presence] in Serum | 0.766 |  |
| 40762045 | Testosterone free and total panel [Mass/volume] - Serum or Plasma | 0.758 |  |
| 1092411 | Risankizumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.758 |  |
| 3013598 | Hornet venom IgE Ab [Units/volume] in Serum | 0.758 |  |
| 3029395 | Gastrin [Mass/volume] in Serum or Plasma --1st specimen | 0.757 |  |
| 3041250 | Core respiratory allergens panel - Serum | 0.756 |  |
| 649422 | Adalimumab Ab [Measurement] in Serum or Plasma | 0.754 |  |
| 648106 | Testosterone Free [Measurement] in Serum or Plasma | 0.753 |  |
| 3015222 | Testosterone.free+weakly bound [Mass/volume] in Serum or Plasma | 0.753 |  |
| 3030713 | Gastrin [Mass/volume] in Serum or Plasma --2nd specimen | 0.751 |  |
| 40764086 | European Hornet IgE Ab/IgE total in Serum | 0.749 |  |
| 1469657 | Peanut components allergen IgE panel - Serum by Immunoassay | 0.748 |  |
| 649103 | Teichoate Ab [Measurement] in Serum | 0.747 |  |
| 3008752 | Teichoate Ab [Units/volume] in Serum | 0.747 |  |
| 3051055 | Staphylolysin Ab [Titer] in Serum | 0.747 |  |
| 3032518 | Natalizumab Ab [Presence] in Serum by Immunoassay | 0.746 |  |
| 3005687 | Testosterone.bound [Mass/volume] in Serum or Plasma | 0.746 |  |
| 36304850 | Basic metabolic and albumin panel - Serum or Plasma | 0.745 |  |
| 3029866 | Gastrin [Mass/volume] in Serum or Plasma --8th specimen | 0.745 |  |
| 3004861 | Intercellular substance Ab [Titer] in Serum | 0.745 |  |
| 3004274 | Wasp venom IgE Ab [Units/volume] in Serum | 0.744 |  |
| 1091832 | Egg Comprehensive IgE Ab panel - Serum or Plasma | 0.744 |  |
| 3027814 | Streptococcus pyogenes enzyme Ab [Titer] in Serum | 0.742 |  |
| 3036055 | Teichoate Ab [Presence] in Serum | 0.742 |  |
| 3030781 | Gastrin [Mass/volume] in Serum or Plasma --4th specimen | 0.740 |  |
| 36306063 | Golimumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.740 |  |
| 3029647 | Gastrin [Mass/volume] in Serum or Plasma --5th specimen | 0.737 |  |
| 3029624 | Gastrin [Mass/volume] in Serum or Plasma --7th specimen | 0.731 |  |
| 3035163 | Hypersensitivity pneumonitis panel - Serum | 0.731 |  |
| 3022035 | Basic metabolic 2000 panel - Serum or Plasma | 0.731 |  |
| 3006343 | Basic metabolic 1998 panel - Serum or Plasma | 0.730 |  |
| 40762893 | Gastrin [Mass/volume] in Serum or Plasma --1st specimen post XXX challenge | 0.729 |  |
| 1260092 | Basic metabolic with hemoglobin and hematocrit panel - Blood | 0.724 |  |
| 44787052 | MICA IgG panel - Serum | 0.712 |  |
| 40761137 | Nettle IgE Ab/IgE total in Serum | 0.708 |  |
| 40758360 | Electrolytes panel - Blood | 0.690 |  |
| 40757364 | Metabolic panel.small animal - Serum or Plasma | 0.668 |  |
| 42868693 | Basic metabolic 2008 panel with ionized calcium - Serum or Plasma | 0.665 |  |
| 40758558 | Short blood count panel - Blood | 0.664 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 766 | b-talt.kn |  | 100% | name | 1141 | 100 |  |  | Blood |  |  |
| 767 | b-talt.kt |  | 100% | name | 1084 | 100 |  |  | Blood |  |  |
| 768 | cefalexin |  | 100% | name | 930 | 100 |  |  |  |  | Cefalexin [Mass/volume] in Serum or Plasma |
| 769 | fp-gastpan |  | 100% | name | 282 | 100 |  |  | Fasting plasma |  | Gastrin panel - Plasma |
| 770 | fs-gastr | pmol/l | 84% | name+unit+values | 1126 | 0 | [7.07, 9.04, 10.82, 13.13, 17.52, 26.34, 40.18, 72.29, 150.81] | fS-Gastriini | Fasting serum |  | Gastrin [Moles/volume] in Serum |
| 771 | fs-gastr |  | 16% | name | 217 | 100 |  | fS-Gastriini | Fasting serum |  | Gastrin [Moles/volume] in Serum |
| 772 | fs-gastr17 | pmol/l | 49% | name+unit+values | 67 | 0 | [1, 1.3, 1.5, 1.8, 2.24, 2.92, 3.9, 7.7, 12] | fS-Gastriini, 17-fragmentti | Fasting serum |  | Gastrin.17 [Moles/volume] in Serum |
| 773 | fs-gastr17 |  | 51% | name | 69 | 100 |  | fS-Gastriini, 17-fragmentti | Fasting serum |  | Gastrin.17 [Moles/volume] in Serum |
| 774 | i-stat-8 |  | 100% | name | 171 | 100 |  |  |  |  | Basic metabolic panel - Blood |
| 775 | i-statcl | mmol/l | 7% | name+unit | 46 | 0 |  |  |  |  | Chloride [Moles/volume] in Blood |
| 776 | i-statcl |  | 93% | name+values | 574 | 100 | [96.03, 98.51, 100, 101.16, 102.29, 103.31, 104, 105, 106.97] |  |  |  | Chloride [Moles/volume] in Blood |
| 777 | i-statcrea | umol/l | 100% | name+unit+values | 1603 | 0 | [54.96, 63.69, 70.71, 78.35, 86.7, 96.38, 108.79, 126.64, 163.46] |  |  |  | Creatinine [Moles/volume] in Blood |
| 778 | i-statglu | mmol/l | 7% | name+unit | 45 | 0 |  |  |  |  | Glucose [Moles/volume] in Blood |
| 779 | i-statglu |  | 93% | name+values | 575 | 100 | [5.28, 5.64, 5.96, 6.25, 6.6, 6.94, 7.55, 8.43, 10.01] |  |  |  | Glucose [Moles/volume] in Blood |
| 780 | i-stathb | g/l | 19% | name+unit+values | 105 | 0 | [120, 126, 129.8, 135.2, 139, 143, 150, 156, 160] |  |  |  | Hemoglobin [Mass/volume] in Blood |
| 781 | i-stathb |  | 81% | name+values | 439 | 100 | [111.08, 121.7, 128.79, 134.9, 139.09, 143.65, 149.99, 155.37, 161.31] |  |  |  | Hemoglobin [Mass/volume] in Blood |
| 782 | i-stathct | % | 7% | name+unit+values | 92 | 0 | [35, 37.7, 39.15, 41, 42, 43, 44, 46, 49] |  |  |  | Hematocrit [Volume Fraction] in Blood |
| 783 | i-stathct | %pcv | 5% | name+unit | 67 | 0 |  |  |  |  | Hematocrit [Volume Fraction] in Blood |
| 784 | i-stathct |  | 89% | name+values | 1243 | 100 | [0.34, 0.37, 0.39, 0.41, 0.43, 0.45, 0.47, 0.53, 40.11] |  |  |  | Hematocrit [Volume Fraction] in Blood |
| 785 | i-statk | mmol/l | 100% | name+unit+values | 1404 | 0 | [3.34, 3.59, 3.7, 3.82, 3.94, 4.04, 4.19, 4.31, 4.55] |  |  |  | Potassium [Moles/volume] in Blood |
| 786 | i-statna | mmol/l | 100% | name+unit+values | 1408 | 0 | [132.58, 135.29, 136.99, 138.07, 139.03, 140, 140.98, 141.61, 142.9] |  |  |  | Sodium [Moles/volume] in Blood |
| 787 | i-staturea | mmol/l | 7% | name+unit | 39 | 0 |  |  |  |  | Urea [Moles/volume] in Blood |
| 788 | i-staturea |  | 93% | name+values | 525 | 100 | [3.63, 4.49, 5.24, 6.1, 6.92, 7.85, 8.89, 10.54, 13.46] |  |  |  | Urea [Moles/volume] in Blood |
| 789 | lateksi | u/ml | 6% | name+unit | 11 | 0 |  |  |  |  | Latex IgE Ab [Units/volume] in Serum |
| 790 | lateksi |  | 94% | name | 159 | 100 |  |  |  |  | Latex IgE Ab [Units/volume] in Serum |
| 791 | li-talt.kn |  | 100% | name | 415 | 100 |  |  | Cerebrospinal fluid |  |  |
| 792 | li-talteen |  | 100% | name | 255 | 100 |  |  | Cerebrospinal fluid |  |  |
| 793 | p-talt.kn |  | 100% | name | 2008 | 100 |  |  | Plasma |  |  |
| 794 | p-talt.kt |  | 100% | name | 1025 | 100 |  |  | Plasma |  |  |
| 795 | s-bartab | titre | 5% | name+unit | 20 | 5 |  | S -Bartonella, vasta-aineet | Serum |  | Bartonella sp Ab [Titer] in Serum |
| 796 | s-bartab |  | 95% | name | 411 | 100 |  | S -Bartonella, vasta-aineet | Serum |  | Bartonella sp Ab [Titer] in Serum |
| 797 | s-beeta-1 | g/l | 97% | name+unit+values | 269 | 0 | [3.63, 3.81, 3.97, 4.19, 4.3, 4.4, 4.58, 4.73, 5.21] |  | Serum |  | Beta 1 globulin [Mass/volume] in Serum |
| 798 | s-beeta-1 |  | 3% | name | 7 | 100 |  |  | Serum |  | Beta 1 globulin [Mass/volume] in Serum |
| 799 | s-beeta-2 | g/l | 97% | name+unit+values | 269 | 0 | [2.5, 2.77, 2.97, 3.2, 3.48, 3.66, 3.93, 4.1, 4.73] |  | Serum |  | Beta 2 globulin [Mass/volume] in Serum |
| 800 | s-beeta-2 |  | 3% | name | 7 | 100 |  |  | Serum |  | Beta 2 globulin [Mass/volume] in Serum |
| 801 | s-beta-1 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  | Beta 1 globulin/Protein.total [Mass Fraction] in Serum |
| 802 | s-beta-1 | g/l | 100% | name+unit+values | 29947 | 0 | [3.3, 3.55, 3.73, 3.89, 4.03, 4.2, 4.38, 4.61, 5] |  | Serum |  | Beta 1 globulin [Mass/volume] in Serum |
| 803 | s-beta-1 |  | 0% | name | 50 | 100 |  |  | Serum |  | Beta 1 globulin [Mass/volume] in Serum |
| 804 | s-beta-2 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  | Beta 2 globulin/Protein.total [Mass Fraction] in Serum |
| 805 | s-beta-2 | g/l | 100% | name+unit+values | 29895 | 0 | [2.24, 2.56, 2.82, 3.08, 3.33, 3.62, 3.97, 4.45, 5.42] |  | Serum |  | Beta 2 globulin [Mass/volume] in Serum |
| 806 | s-beta-2 |  | 0% | name | 50 | 100 |  |  | Serum |  | Beta 2 globulin [Mass/volume] in Serum |
| 807 | s-beta1 | g/l | 95% | name+unit+values | 1765 | 0 | [3.56, 3.83, 4.09, 4.27, 4.49, 4.66, 4.9, 5.16, 5.55] |  | Serum |  | Beta 1 globulin [Mass/volume] in Serum |
| 808 | s-beta1 |  | 5% | name | 92 | 100 |  |  | Serum |  | Beta 1 globulin [Mass/volume] in Serum |
| 809 | s-beta2 | g/l | 95% | name+unit+values | 1772 | 0 | [1.95, 2.22, 2.5, 2.76, 3.03, 3.39, 3.78, 4.35, 5.3] |  | Serum |  | Beta 2 globulin [Mass/volume] in Serum |
| 810 | s-beta2 |  | 5% | name | 101 | 100 |  |  | Serum |  | Beta 2 globulin [Mass/volume] in Serum |
| 811 | s-estdio | nmol/l | 70% | name+unit+values | 341 | 0 | [0.08, 0.09, 0.12, 0.15, 0.18, 0.22, 0.3, 0.44, 0.66] |  | Serum |  | Estradiol [Moles/volume] in Serum |
| 812 | s-estdio |  | 30% | name+values | 146 | 100 | [0.1, 0.11, 0.13, 0.15, 0.17, 0.19, 0.24, 0.32, 0.5] |  | Serum |  | Estradiol [Moles/volume] in Serum |
| 813 | s-estdiol | nmol/l | 71% | name+unit+values | 655 | 0.15 | [0.01, 0.02, 0.04, 0.07, 0.09, 0.11, 0.15, 0.2, 0.34] |  | Serum |  | Estradiol [Moles/volume] in Serum |
| 814 | s-estdiol |  | 29% | name | 266 | 100 |  |  | Serum |  | Estradiol [Moles/volume] in Serum |
| 815 | s-flekain | umol/l | 76% | name+unit+values | 326 | 0.31 | [0.25, 0.31, 0.4, 0.5, 0.57, 0.7, 0.85, 1, 1.27] | S -Flekainidi | Serum |  | Flecainide [Moles/volume] in Serum or Plasma |
| 816 | s-flekain |  | 24% | name | 101 | 100 |  | S -Flekainidi | Serum |  | Flecainide [Moles/volume] in Serum or Plasma |
| 817 | s-gastr17 | pmol/l | 55% | name+unit+values | 95 | 0 | [1.1, 1.3, 1.7, 1.9, 2.3, 2.9, 3.25, 4.75, 7.9] | S -Gastriini, 17-fragmentti | Serum |  | Gastrin.17 [Moles/volume] in Serum |
| 818 | s-gastr17 |  | 45% | name | 79 | 100 |  | S -Gastriini, 17-fragmentti | Serum |  | Gastrin.17 [Moles/volume] in Serum |
| 819 | s-histab | u/ml | 3% | name+unit | 35 | 0 |  | S -Histoni, vasta-aineet | Serum |  | Histones Ab [Units/volume] in Serum |
| 820 | s-histab |  | 97% | name | 1006 | 100 |  | S -Histoni, vasta-aineet | Serum |  | Histones Ab [Units/volume] in Serum |
| 821 | s-hstesto | nmol/l | 96% | name+unit+values | 613 | 0 | [0.39, 1.55, 6.18, 8.15, 10.35, 12.15, 14.54, 16.96, 22.76] |  | Serum |  | Testosterone [Moles/volume] in Serum by High sensitivity |
| 822 | s-hstesto |  | 4% | name | 25 | 100 |  |  | Serum |  | Testosterone [Moles/volume] in Serum by High sensitivity |
| 823 | s-latekse | mmol/l | 1% | name+unit | 6 | 0 |  | S -Lateksi (luonnonkumi, k82), IgE-vasta-aineet | Serum |  | Latex IgE Ab [Units/volume] in Serum |
| 824 | s-latekse | u/ml | 56% | name+unit+values | 233 | 0.43 | [0, 0, 0, 0.01, 0.01, 0.02, 0.02, 0.04, 0.17] | S -Lateksi (luonnonkumi, k82), IgE-vasta-aineet | Serum |  | Latex IgE Ab [Units/volume] in Serum |
| 825 | s-latekse |  | 42% | name | 175 | 100 |  | S -Lateksi (luonnonkumi, k82), IgE-vasta-aineet | Serum |  | Latex IgE Ab [Units/volume] in Serum |
| 826 | s-leptab |  | 100% | name | 108 | 100 |  | S -Leptospira, vasta-aineet | Serum |  | Leptospira sp Ab [Presence] in Serum |
| 827 | s-listab |  | 100% | name | 128 | 100 |  | S -Listeria, vasta-aineet | Serum |  | Listeria monocytogenes Ab [Presence] in Serum |
| 828 | s-maitab |  | 100% | name | 241 | 100 |  | S -Lehmänmaito, vasta-aineet | Serum |  | Cow's milk Ab [Presence] in Serum |
| 829 | s-pistaae | u/ml | 37% | name+unit | 47 | 0 |  |  | Serum |  | Pistachio IgE Ab [Units/volume] in Serum |
| 830 | s-pistaae |  | 63% | name | 80 | 100 |  |  | Serum |  | Pistachio IgE Ab [Units/volume] in Serum |
| 831 | s-pisto1 |  | 100% | name | 532 | 100 |  |  | Serum |  | Insect venom IgE Ab panel - Serum |
| 832 | s-pisto2 |  | 100% | name | 911 | 100 |  |  | Serum |  | Insect venom IgE Ab panel - Serum |
| 833 | s-sae1-o |  | 100% | name | 716 | 100 |  |  | Serum | Qualitative test (also semi-quantitative) | SAE1 Ab [Presence] in Serum |
| 834 | s-sentab | u/ml | 16% | name+unit+values | 441 | 0 | [0.5, 0.64, 0.89, 1.43, 16.8, 42.09, 90.3, 130.01, 181.65] | S -Sentromeeri, vasta-aineet | Serum |  | Centromere Ab [Units/volume] in Serum |
| 835 | s-sentab |  | 84% | name+values | 2373 | 100 | [0.4, 0.5, 0.6, 0.74, 0.99, 1.2, 1.6, 3.73, 37.58] | S -Sentromeeri, vasta-aineet | Serum |  | Centromere Ab [Units/volume] in Serum |
| 836 | s-sentabb |  | 100% | name | 4462 | 100 |  |  | Serum |  | Centromere B Ab [Units/volume] in Serum |
| 837 | s-sentbab | u/ml | 2% | name+unit+values | 100 | 0 | [9.5, 16.67, 23, 33.5, 49.5, 66.5, 97, 120, 157] | S -Sentromeeri (CENP-B), vasta-aineet | Serum |  | Centromere B Ab [Units/volume] in Serum |
| 838 | s-sentbab |  | 98% | name | 5128 | 100 |  | S -Sentromeeri (CENP-B), vasta-aineet | Serum |  | Centromere B Ab [Units/volume] in Serum |
| 839 | s-serto | mg/l | 91% | name+unit+values | 108 | 0 | [9.6, 18.4, 22.3, 25.27, 27.75, 30, 32.95, 38, 47.27] | S -Sertolitsumabipegoli | Serum |  | Certolizumab pegol [Mass/volume] in Serum or Plasma |
| 840 | s-serto |  | 9% | name | 11 | 100 |  | S -Sertolitsumabipegoli | Serum |  | Certolizumab pegol [Mass/volume] in Serum or Plasma |
| 841 | s-sertral | nmol/l | 74% | name+unit+values | 85 | 0 | [29, 58.3, 80.33, 99, 113, 148, 204.27, 237.85, 312] | S -Sertraliini | Serum |  | Sertraline [Moles/volume] in Serum or Plasma |
| 842 | s-sertral |  | 26% | name | 30 | 100 |  | S -Sertraliini | Serum |  | Sertraline [Moles/volume] in Serum or Plasma |
| 843 | s-sital | nmol/l | 67% | name+unit+values | 110 | 0 | [35.5, 55, 68.23, 79.89, 102.56, 129.7, 171.22, 226.5, 323.33] | S -Sitalopraami | Serum |  | Citalopram [Moles/volume] in Serum or Plasma |
| 844 | s-sital |  | 33% | name | 53 | 100 |  | S -Sitalopraami | Serum |  | Citalopram [Moles/volume] in Serum or Plasma |
| 845 | s-statrae | u/ml | 45% | name+unit+values | 83 | 0 | [0, 0, 0, 0, 0, 0.01, 0.01, 0.01, 0.03] |  | Serum |  | Allergen specific IgE Ab [Units/volume] in Serum |
| 846 | s-statrae |  | 55% | name+values | 101 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Serum |  | Allergen specific IgE Ab [Units/volume] in Serum |
| 847 | s-talt.kn |  | 100% | name | 1751 | 100 |  |  | Serum |  |  |
| 848 | s-talt.kt |  | 100% | name | 1152 | 100 |  |  | Serum |  |  |
| 849 | s-talteen |  | 100% | name | 622 | 100 |  |  | Serum |  |  |
| 850 | s-teikab | titre | 3% | name+unit | 14 | 0 |  | S -Teikkohappo, vasta-aineet | Serum |  | Teichoic acid Ab [Titer] in Serum |
| 851 | s-teikab |  | 97% | name | 407 | 100 |  | S -Teikkohappo, vasta-aineet | Serum |  | Teichoic acid Ab [Titer] in Serum |
| 852 | s-tes-vlik | pmol/l | 98% | name+unit+values | 3055 | 0 | [131.96, 163.73, 183.37, 200.39, 216.85, 234.59, 255.45, 280.74, 327.47] |  | Serum |  | Testosterone.free [Moles/volume] in Serum by calculation |
| 853 | s-tes-vlik |  | 2% | name | 70 | 100 |  |  | Serum |  | Testosterone.free [Moles/volume] in Serum by calculation |
| 854 | s-tesmsvl | pmol/l | 100% | name+unit+values | 119 | 0.84 | [7.22, 9, 11.83, 14.36, 16.33, 22.3, 27.53, 49.39, 149.4] |  | Serum |  | Testosterone.free [Moles/volume] in Serum by calculation |
| 855 | s-testab | titre | 7% | name+unit | 17 | 0 |  | S -Kives, vasta-aineet | Serum |  | Testis Ab [Titer] in Serum |
| 856 | s-testab |  | 93% | name | 240 | 100 |  | S -Kives, vasta-aineet | Serum |  | Testis Ab [Titer] in Serum |
| 857 | s-testo | form | 0% | name+unit | 21 | 0 |  | S -Testosteroni | Serum |  | Testosterone [Moles/volume] in Serum |
| 858 | s-testo | nmol | 0% | name+unit | 11 | 0 |  | S -Testosteroni | Serum |  | Testosterone [Moles/volume] in Serum |
| 859 | s-testo | nmol/l | 93% | name+unit+values | 84595 | 0 | [1.69, 6.54, 8.92, 10.82, 12.63, 14.54, 16.81, 19.66, 24.4] | S -Testosteroni | Serum |  | Testosterone [Moles/volume] in Serum |
| 860 | s-testo | pmol/l | 0% | name+unit | 25 | 0 |  | S -Testosteroni | Serum |  | Testosterone [Moles/volume] in Serum |
| 861 | s-testo |  | 7% | name | 6136 | 100 |  | S -Testosteroni | Serum |  | Testosterone [Moles/volume] in Serum |
| 862 | s-testo-v | % | 1% | name+unit | 15 | 0 |  | S -Testosteroni, vapaa | Serum | Free or unconjugated | Testosterone.free/Testosterone.total [Molar fraction] in Serum |
| 863 | s-testo-v | pmol/l | 75% | name+unit+values | 1395 | 0 | [11.98, 20, 25.24, 29.51, 34.24, 42.09, 56.58, 119.64, 213.9] | S -Testosteroni, vapaa | Serum | Free or unconjugated | Testosterone.free [Moles/volume] in Serum |
| 864 | s-testo-v |  | 24% | name+values | 446 | 100 | [15.53, 20.79, 27.6, 41.13, 82.38, 102.22, 145.07, 178.13, 242.28] | S -Testosteroni, vapaa | Serum | Free or unconjugated | Testosterone.free [Moles/volume] in Serum |
| 865 | s-testo-vl | pmol/l | 81% | name+unit+values | 1584 | 0 | [89.6, 123.43, 144.91, 163.8, 182.42, 203.43, 230.73, 265.71, 334.87] |  | Serum |  | Testosterone.free [Moles/volume] in Serum by calculation |
| 866 | s-testo-vl |  | 19% | name+values | 381 | 100 | [70, 109.05, 118.48, 129.51, 141.4, 148.57, 156.84, 174.32, 249.8] |  | Serum |  | Testosterone.free [Moles/volume] in Serum by calculation |
| 867 | s-testoms | nmol/l | 90% | name+unit+values | 721 | 0 | [0.32, 0.59, 0.81, 1.15, 1.67, 3.12, 7.32, 10.86, 15.21] |  | Serum |  | Testosterone [Moles/volume] in Serum by Mass spectrometry |
| 868 | s-testoms |  | 10% | name | 81 | 100 |  |  | Serum |  | Testosterone [Moles/volume] in Serum by Mass spectrometry |
| 869 | s-testov | % | 69% | name+unit+values | 149 | 0 | [1, 1.2, 1.3, 1.4, 1.46, 1.51, 1.61, 1.7, 1.83] |  | Serum |  | Testosterone.free/Testosterone.total [Molar fraction] in Serum |
| 870 | s-testov |  | 31% | name | 67 | 100 |  |  | Serum |  | Testosterone.free/Testosterone.total [Molar fraction] in Serum |
| 871 | s-testovi | pmol/l | 71% | name+unit+values | 85 | 0 | [101, 125, 141.12, 158, 172.75, 200.75, 240.62, 278, 351] |  | Serum |  | Testosterone.free [Moles/volume] in Serum |
| 872 | s-testovi |  | 29% | name | 34 | 100 |  |  | Serum |  | Testosterone.free [Moles/volume] in Serum |
| 873 | s-testovl | pmol/l | 88% | name+unit+values | 14468 | 0.01 | [78.71, 126.93, 151.85, 172.92, 194.5, 216.9, 243.36, 280.96, 361.32] | S -Testosteroni, vapaa, laskettu | Serum |  | Testosterone.free [Moles/volume] in Serum by calculation |
| 874 | s-testovl |  | 12% | name+values | 2065 | 100 | [74.75, 124.44, 150.35, 173.46, 192.81, 214.54, 237.23, 275.33, 343.04] | S -Testosteroni, vapaa, laskettu | Serum |  | Testosterone.free [Moles/volume] in Serum by calculation |
| 875 | s-urtikar |  | 100% | name | 165 | 100 |  |  | Serum |  | Urticaria panel - Serum |
| 876 | s-ustek | mg/l | 100% | name+unit+values | 158 | 0 | [0.83, 1.36, 1.66, 2.2, 2.73, 3.38, 4.09, 4.87, 6.01] | S -Ustekinumabi | Serum |  | Ustekinumab [Mass/volume] in Serum or Plasma |
| 877 | s-ustekab |  | 100% | name | 281 | 100 |  | S -Ustekinumabi, vasta-aineet | Serum |  | Ustekinumab Ab [Presence] in Serum or Plasma |
| 878 | s-usteki | mg/l | 89% | name+unit+values | 758 | 0 | [0.94, 1.58, 2.09, 2.63, 3.28, 4.09, 4.69, 5.88, 8.45] |  | Serum |  | Ustekinumab [Mass/volume] in Serum or Plasma |
| 879 | s-usteki |  | 11% | name | 94 | 100 |  |  | Serum |  | Ustekinumab [Mass/volume] in Serum or Plasma |
| 880 | s-ypstu1a |  | 100% | name | 116 | 100 |  |  | Serum |  | Yersinia pseudotuberculosis Ab [Presence] in Serum |
| 881 | s-ypstu3 | titre | 6% | name+unit | 6 | 0 |  |  | Serum |  | Yersinia pseudotuberculosis serotype O:3 Ab [Titer] in Serum |
| 882 | s-ypstu3 |  | 94% | name | 95 | 100 |  |  | Serum |  | Yersinia pseudotuberculosis serotype O:3 Ab [Titer] in Serum |
| 883 | satks,haj |  | 100% | name | 1146 | 100 |  |  |  |  |  |
| 884 | u-talt.kt |  | 100% | name | 120 | 100 |  |  | Urine |  |  |

