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
Here is group 74.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000690 | Aldosterone [Moles/time] in 24 hour Urine | 1.000 |  |
| 3000998 | Ovalbumin IgE Ab [Units/volume] in Serum | 1.000 |  |
| 3014133 | Dog dander IgE Ab [Units/volume] in Serum | 1.000 | 1077 |
| 3015401 | Amylase [Enzymatic activity/volume] in Pleural fluid | 1.000 |  |
| 3016771 | Amylase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 152 |
| 3017315 | Amylase [Enzymatic activity/volume] in Urine | 1.000 |  |
| 3019396 | Amylase.pancreatic [Enzymatic activity/volume] in Urine | 1.000 |  |
| 3019677 | Aldosterone [Mass/time] in 24 hour Urine | 1.000 |  |
| 3019985 | Aldosterone [Moles/volume] in 24 hour Urine | 1.000 |  |
| 3035995 | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 23 |
| 3040370 | OLANZapine [Moles/volume] in Serum or Plasma | 1.000 |  |
| 36031415 | Gliadin IgE Ab [Units/volume] in Serum | 1.000 |  |
| 36304052 | Adalimumab Ab [Units/volume] in Serum or Plasma | 1.000 |  |
| 44786774 | Adalimumab [Mass/volume] in Serum or Plasma | 1.000 |  |
| 44816654 | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum | 0.984 |  |
| 3004280 | Aldosterone [Moles/volume] in Serum or Plasma --supine | 0.980 |  |
| 3017950 | Salicylates [Moles/volume] in Serum or Plasma | 0.979 | 464 |
| 42870305 | Alkaline phosphatase.intestinal 2 [Enzymatic activity/volume] in Serum or Plasma | 0.974 |  |
| 42870306 | Alkaline phosphatase.intestinal 3 [Enzymatic activity/volume] in Serum or Plasma | 0.973 |  |
| 3003171 | Aldosterone [Moles/volume] in Serum or Plasma --upright | 0.971 |  |
| 3016848 | Dog dander IgG Ab [Units/volume] in Serum | 0.971 |  |
| 1091762 | Alpha 1 globulin [Mass/volume] in Serum or Plasma | 0.970 |  |
| 1092292 | Alpha 2 globulin [Mass/volume] in Serum or Plasma | 0.967 |  |
| 3001788 | Aldosterone [Moles/volume] in Serum or Plasma | 0.967 | 774 |
| 3017830 | Gliadin IgG Ab [Presence] in Serum | 0.965 |  |
| 46236951 | Amylase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.965 |  |
| 3003966 | Gliadin IgG Ab [Units/volume] in Serum | 0.965 | 1637 |
| 3024457 | Aldosterone [Mass/volume] in 24 hour Urine | 0.964 |  |
| 3017317 | Gliadin IgA Ab [Presence] in Serum | 0.964 |  |
| 3037820 | Gliadin IgA Ab [Units/volume] in Serum | 0.964 | 878 |
| 44786773 | Adalimumab Ab [Mass/volume] in Serum or Plasma | 0.962 |  |
| 3027953 | Aldolase [Enzymatic activity/volume] in Serum or Plasma | 0.961 | 695 |
| 3016417 | Amylase.pancreatic [Enzymatic activity/volume] in Serum or Plasma | 0.961 |  |
| 3017726 | Gliadin Ab [Units/volume] in Serum | 0.960 | 1663 |
| 3005685 | Amylase.salivary [Enzymatic activity/volume] in Serum or Plasma | 0.960 |  |
| 46235077 | Alkaline phosphatase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.960 |  |
| 3020013 | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum or Plasma | 0.959 |  |
| 3024561 | Albumin [Mass/volume] in Serum or Plasma | 0.959 | 20 |
| 3007225 | Aldosterone free [Mass/time] in 24 hour Urine | 0.956 |  |
| 3041069 | Gliadin Ab [Presence] in Serum | 0.956 |  |
| 42868742 | Amylase.pancreatic [Enzymatic activity/volume] in Pleural fluid | 0.954 |  |
| 3001660 | Gliadin IgM Ab [Units/volume] in Serum | 0.953 |  |
| 36305075 | Vedolizumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.951 |  |
| 40759832 | Dog dander+Dog epithelium IgE Ab [Units/volume] in Serum | 0.948 |  |
| 36303365 | Adalimumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.944 |  |
| 3001110 | Alkaline phosphatase [Enzymatic activity/volume] in Blood | 0.944 |  |
| 1175645 | Adalimumab Ab [Units/volume] in Serum by Immunoassay | 0.939 |  |
| 40761803 | Gliadin peptide IgA Ab [Units/volume] in Serum | 0.938 |  |
| 40761804 | Gliadin peptide IgG Ab [Units/volume] in Serum | 0.937 |  |
| 3015174 | Gliadin IgA Ab [Units/volume] in Serum by Immunoassay | 0.935 | 694 |
| 3021494 | OLANZapine [Mass/volume] in Serum or Plasma | 0.935 |  |
| 3014729 | Amylase.P1 [Enzymatic activity/volume] in Serum or Plasma | 0.935 |  |
| 36305882 | Vedolizumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.934 |  |
| 3001467 | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum or Plasma | 0.933 | 1850 |
| 3016625 | Amylase S1 [Enzymatic activity/volume] in Serum or Plasma | 0.933 |  |
| 46235169 | Amylase [Enzymatic activity/volume] in Blood | 0.932 |  |
| 40765809 | Dog dander IgG Ab [Mass/volume] in Serum | 0.932 |  |
| 3015468 | Gliadin IgG Ab [Units/volume] in Serum by Immunoassay | 0.931 | 653 |
| 3018910 | Alkaline phosphatase.bone [Mass/volume] in Serum or Plasma | 0.931 |  |
| 3005294 | Aldosterone [Mass/volume] in Serum or Plasma --supine | 0.931 |  |
| 3035400 | Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma | 0.930 | 1919 |
| 3000831 | Aldosterone [Mass/volume] in Serum or Plasma --upright | 0.928 |  |
| 3004541 | Aldosterone [Moles/volume] in Urine | 0.928 |  |
| 36304805 | Adalimumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.924 |  |
| 3010114 | Amylase isoenzyme 7 panel - Serum | 0.924 |  |
| 3004155 | Amylase S2 [Enzymatic activity/volume] in Serum or Plasma | 0.924 |  |
| 3009876 | Amylase isoenzyme 3 panel - Serum or Plasma | 0.923 |  |
| 40759369 | Dog dander IgG4 Ab [Mass/volume] in Serum | 0.923 |  |
| 3028520 | Gluten IgE Ab [Units/volume] in Serum | 0.921 | 1932 |
| 3001415 | Amylase [Enzymatic activity/volume] in 24 hour Urine | 0.921 |  |
| 3023430 | Cat dander IgE Ab [Units/volume] in Serum | 0.917 | 715 |
| 3009039 | Amylase.P2 [Enzymatic activity/volume] in Serum or Plasma | 0.916 |  |
| 40771878 | Amylase [Enzymatic activity/volume] in Serum or Plasma --fasting | 0.915 |  |
| 40764094 | Dog dander IgE Ab/IgE total in Serum | 0.915 |  |
| 3000787 | Salicylates [Mass/volume] in Serum or Plasma | 0.915 |  |
| 40758706 | Salicylamide [Moles/volume] in Serum or Plasma | 0.913 |  |
| 3007970 | Alkaline phosphatase.bile [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |
| 3014599 | Egg white IgE Ab [Units/volume] in Serum | 0.913 | 799 |
| 3020233 | Acid phosphatase [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |
| 21492517 | Salicylurate [Moles/volume] in Serum or Plasma | 0.912 |  |
| 3003633 | Ovomucoid IgE Ab [Units/volume] in Serum | 0.911 |  |
| 1175553 | Vedolizumab and Vedolizumab Ab panel [Mass/volume] - Serum or Plasma | 0.911 |  |
| 649422 | Adalimumab Ab [Measurement] in Serum or Plasma | 0.910 |  |
| 3032449 | Aldolase [Enzymatic activity/volume] in Body fluid | 0.910 |  |
| 3037597 | Macroamylase [Enzymatic activity/volume] in Serum or Plasma | 0.910 |  |
| 3021162 | Amylase [Enzymatic activity/volume] in Specimen | 0.909 |  |
| 3018352 | Whole Egg IgE Ab [Units/volume] in Serum | 0.907 | 891 |
| 3050371 | Gliadin peptide IgG Ab [Presence] in Serum by Immunoassay | 0.907 |  |
| 3002000 | Albumin [Mass/volume] in Specimen | 0.905 |  |
| 3002214 | Alkaline phosphatase.renal [Enzymatic activity/volume] in Serum or Plasma | 0.905 |  |
| 3001151 | Sole IgE Ab [Units/volume] in Serum | 0.905 |  |
| 3045684 | Alkaline phosphatase.other fractions [Enzymatic activity/volume] in Serum or Plasma | 0.905 |  |
| 3040995 | Amylase [Enzymatic activity/volume] in 12 hour Urine | 0.904 |  |
| 3043544 | IgE [Presence] in Serum | 0.904 |  |
| 3036705 | Amylase [Enzymatic activity/volume] in 2 hour Urine | 0.904 |  |
| 3003860 | Alkaline phosphatase.regan [Enzymatic activity/volume] in Serum or Plasma | 0.903 |  |
| 1617227 | Adalimumab [Mass/volume] in Serum or Plasma --trough | 0.903 |  |
| 3015123 | Egg yolk IgE Ab [Units/volume] in Serum | 0.903 | 1080 |
| 3028564 | Alkaline phosphatase isoenz panel - Serum or Plasma | 0.902 |  |
| 3048601 | Amylase.pancreatic [Enzymatic activity/volume] in Body fluid | 0.902 |  |
| 3048403 | Gliadin peptide IgA Ab [Presence] in Serum by Immunoassay | 0.902 |  |
| 1175847 | Vedolizumab [Mass/volume] in Serum or Plasma by LC/MS/MS --trough | 0.902 |  |
| 3015322 | Alpha 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.902 | 315 |
| 3965168 | Ovalbumin IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.901 |  |
| 1617569 | Cholesterol.in LDL.small dense [Moles/volume] in Serum or Plasma | 0.901 |  |
| 3035654 | Conalbumin IgE Ab [Units/volume] in Serum | 0.900 |  |
| 3008691 | Amylase [Enzymatic activity/volume] in Peritoneal fluid | 0.899 |  |
| 1260115 | Albumin [Mass/volume] in Serum by Immunoassay | 0.898 |  |
| 40763380 | OLANZapine [Moles/volume] in Specimen | 0.897 |  |
| 43533877 | Aldosterone-18-glucuronide [Moles/time] in 24 hour Urine | 0.897 |  |
| 43533876 | Aldosterone-18-glucuronide [Moles/volume] in 24 hour Urine | 0.896 |  |
| 3005166 | Alpha 1 globulin [Mass/volume] in Urine | 0.896 |  |
| 3965996 | Dog dander IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.896 |  |
| 3039686 | IgE Ab [Presence] in Serum or Plasma | 0.896 |  |
| 3005229 | Alpha 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.895 | 316 |
| 3002670 | Multiple inhalant allergen IgE Ab [Units/volume] in Serum | 0.894 |  |
| 3002538 | Oyster IgE Ab [Units/volume] in Serum | 0.893 | 1690 |
| 21492784 | Miscellaneous allergen IgE Ab [Units/volume] in Serum | 0.893 |  |
| 3023949 | Allscale IgE Ab [Units/volume] in Serum | 0.893 |  |
| 3024218 | Fig IgE Ab [Units/volume] in Serum | 0.891 |  |
| 42868690 | Salicylates [Moles/volume] in Serum or Plasma by Screen method | 0.889 | 870 |
| 3010541 | Alpha 2 globulin [Mass/volume] in Urine | 0.888 |  |
| 3013765 | Hay IgE Ab [Units/volume] in Serum | 0.888 |  |
| 3019406 | Latex IgE Ab [Units/volume] in Serum | 0.887 | 1426 |
| 1175324 | Salicylcarnitine [Moles/volume] in Serum or Plasma | 0.887 |  |
| 3011337 | Aldosterone [Mass/volume] in Serum or Plasma | 0.887 |  |
| 3021476 | Amylase [Enzymatic activity/volume] in Duodenal fluid | 0.887 |  |
| 3025313 | Albumin [Mass/volume] in Body fluid | 0.887 | 1032 |
| 3018469 | Dog Fennel IgE Ab [Units/volume] in Serum | 0.886 | 1502 |
| 3014955 | Aldosterone [Mass/volume] in Urine | 0.886 |  |
| 3005090 | Alkaline phosphatase [Enzymatic activity/volume] in Body fluid | 0.886 |  |
| 649237 | Dog IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.886 |  |
| 3008136 | Dog epithelium IgE Ab [Units/volume] in Serum | 0.886 | 692 |
| 3030968 | Amylase [Enzymatic activity/volume] in Urine collected for unspecified duration | 0.884 |  |
| 1988210 | Ovalbumin IgG Ab [Mass/volume] in Serum | 0.884 |  |
| 40766189 | Gliadin peptide IgG Ab [Units/volume] in Serum by Immunoassay | 0.884 |  |
| 3001308 | Cholesterol in LDL [Moles/volume] in Serum or Plasma | 0.883 | 92 |
| 3042733 | HLA Ab [Presence] in Serum | 0.881 |  |
| 3043739 | Amylase [Enzymatic activity/volume] in Pericardial fluid | 0.881 |  |
| 3027320 | Salicylates [Moles/volume] in Specimen | 0.881 |  |
| 3018519 | Aldolase [Enzymatic activity/volume] in Red Blood Cells | 0.879 |  |
| 3013708 | Smelt IgE Ab [Units/volume] in Serum | 0.879 |  |
| 3001077 | Alkaline phosphatase [Enzymatic activity/volume] in Urine | 0.879 |  |
| 3026610 | Fish IgE Ab [Units/volume] in Serum | 0.878 |  |
| 3008832 | Norclozapine [Moles/volume] in Serum or Plasma | 0.877 |  |
| 3020874 | Milk IgE Ab [Units/volume] in Serum | 0.876 | 1442 |
| 3018001 | Oat IgE Ab [Units/volume] in Serum | 0.876 | 1486 |
| 3005322 | IgE [Units/volume] in Serum or Plasma | 0.876 | 466 |
| 44816883 | Amylase [Enzymatic activity/volume] in Saliva (oral fluid) | 0.876 |  |
| 3012133 | Amylase [Enzymatic activity/volume] in Body fluid | 0.875 | 771 |
| 40758600 | Aldosterone [Moles/volume] in Serum or Plasma --1 hour post dose corticotropin | 0.875 |  |
| 645478 | OLANZapine [Measurement] in Serum or Plasma | 0.874 |  |
| 3020990 | Alkaline phosphatase.intestinal/Alkaline phosphatase.total in Serum or Plasma | 0.874 | 1783 |
| 3029321 | OLANZapine [Moles/volume] in Urine | 0.873 |  |
| 3036185 | Alkaline phosphatase.liver 2 [Enzymatic activity/volume] in Serum or Plasma | 0.872 |  |
| 3965215 | Dog dander+Dog epithelium IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.872 |  |
| 3039654 | Egg white IgG Ab [Presence] in Serum | 0.872 |  |
| 3965091 | Gliadin peptide IgA+IgG Ab [Units/volume] in Serum by Immunoassay | 0.871 |  |
| 40766183 | Gliadin peptide IgA Ab [Units/volume] in Serum by Immunoassay | 0.870 |  |
| 3033031 | Aldosterone [Moles/volume] in Serum or Plasma --post XXX challenge | 0.869 |  |
| 3004142 | Amylase [Enzymatic activity/volume] in Synovial fluid | 0.869 |  |
| 3040652 | Amylase [Units/volume] in 24 hour Urine | 0.869 |  |
| 3017341 | Amylase [Enzymatic activity/volume] in Amniotic fluid | 0.869 |  |
| 3016585 | Aldosterone [Mass/volume] in Serum or Plasma --baseline | 0.868 |  |
| 3012516 | Albumin [Mass/volume] in Urine | 0.868 |  |
| 44786740 | Norolanzapine [Moles/volume] in Serum or Plasma | 0.866 |  |
| 3039488 | Alkaline phosphatase.intestinal 2/Alkaline phosphatase.total in Serum or Plasma | 0.866 |  |
| 3031598 | Aldosterone [Moles/volume] in Serum or Plasma --pre XXX challenge | 0.865 |  |
| 3035062 | Alkaline phosphatase.liver 1 [Enzymatic activity/volume] in Serum or Plasma | 0.865 |  |
| 648474 | Amylase [Measurement] in Urine | 0.865 |  |
| 3022487 | Cholesterol in VLDL [Moles/volume] in Serum or Plasma | 0.865 | 219 |
| 3013915 | Aldosterone [Mass/volume] in Blood | 0.865 |  |
| 3045829 | Aldosterone/Creatinine [Mass Ratio] in 24 hour Urine | 0.864 |  |
| 3028622 | Alkaline phosphatase.lung [Enzymatic activity/volume] in Serum or Plasma | 0.864 |  |
| 3015877 | Amylase.P3 [Enzymatic activity/volume] in Serum or Plasma | 0.863 |  |
| 3030162 | Aldosterone [Moles/volume] in Serum or Plasma --pre or post XXX challenge | 0.863 |  |
| 40766151 | Gliadin peptide+tissue transglutaminase IgA+IgG Ab [Presence] in Serum by Immunoassay | 0.862 |  |
| 3039730 | Alkaline phosphatase.intestinal 3/Alkaline phosphatase.total in Serum or Plasma | 0.862 |  |
| 647232 | Aldosterone [Measurement] in Urine | 0.861 |  |
| 40760707 | Aldosterone [Moles/volume] in Serum or Plasma --1 hour post XXX challenge | 0.861 |  |
| 649070 | Salicylates [Measurement] in Serum or Plasma | 0.860 |  |
| 43055511 | Salicylates [Mass/volume] in Serum or Plasma --trough | 0.860 |  |
| 3021643 | Salicylamide [Mass/volume] in Serum or Plasma | 0.859 |  |
| 3048752 | Lipase [Enzymatic activity/volume] in Pleural fluid | 0.859 |  |
| 3009059 | Enolase [Enzymatic activity/volume] in Serum | 0.858 |  |
| 647081 | HLA-A and B and C (class I) and HLA-DP and DQ and DR (class II) Ab.IgG donor specific [Presence] in Serum or Plasma | 0.858 |  |
| 3046505 | Aldolase [Enzymatic activity/volume] in Pleural fluid | 0.858 |  |
| 648378 | Gliadin IgG Ab [Measurement] in Serum | 0.858 |  |
| 3016801 | Amylase [Enzymatic activity/volume] in Gastric fluid | 0.857 |  |
| 1988545 | Gliadin IgG Ab [Mass/volume] in Serum | 0.856 |  |
| 3965752 | Albumin [Mass/volume] in Serum or Plasma by Nephelometry | 0.856 |  |
| 42868730 | Amylase.pancreatic [Enzymatic activity/volume] in Peritoneal fluid | 0.855 |  |
| 40757478 | Albumin [Moles/volume] in Serum or Plasma | 0.854 |  |
| 3012633 | Alpha 1 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.852 |  |
| 42868537 | Multiple inhalant allergen IgE Ab [Presence] in Serum by Immunoassay | 0.852 |  |
| 646403 | Gliadin IgA Ab [Measurement] in Serum | 0.850 |  |
| 3033598 | Amylase isoenzymes [Interpretation] in Serum or Plasma | 0.850 |  |
| 3002069 | Alkaline phosphatase.bone/Alkaline phosphatase.total in Serum or Plasma | 0.850 | 1666 |
| 3040682 | Aldosterone [Molar amount] in Urine collected for unspecified duration | 0.850 |  |
| 3964946 | Ovomucoid IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.847 |  |
| 42870307 | Alkaline phosphatase.placental 2 [Enzymatic activity/volume] in Serum or Plasma | 0.845 |  |
| 3010043 | Alpha 2 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.845 |  |
| 3965305 | Dog recombinant 5 IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.844 |  |
| 3009827 | Alpha-2-Macroglobulin [Mass/volume] in Serum or Plasma | 0.844 |  |
| 3022361 | Alpha 1 globulin [Mass/volume] in Urine by Electrophoresis | 0.843 |  |
| 36305571 | Albumin goal [Mass/volume] Serum or Plasma | 0.843 |  |
| 40762132 | Amylase [Enzymatic activity/volume] in Peritoneal dialysis fluid | 0.842 |  |
| 3000081 | cloZAPine [Moles/volume] in Serum or Plasma | 0.841 |  |
| 3028286 | Albumin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.841 | 313 |
| 44816655 | Soluble fms-like tyrosine kinase-1/placental growth factor [Ratio] in Serum | 0.840 |  |
| 1617584 | Ovalbumin IgG4 Ab [Mass/volume] in Serum | 0.840 |  |
| 40763164 | OLANZapine [Mass/volume] in Blood | 0.840 |  |
| 645900 | Alkaline phosphatase.bone [Measurement] in Serum or Plasma | 0.840 |  |
| 3021886 | Globulin [Mass/volume] in Serum | 0.839 | 83 |
| 646542 | Albumin [Measurement] in Serum or Plasma | 0.839 |  |
| 40757623 | Alanine aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.838 |  |
| 3966178 | Dog epithelium IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.838 |  |
| 3043889 | HLA Ab in Serum | 0.838 |  |
| 3036255 | Didesmethylcitalopram [Moles/volume] in Serum or Plasma | 0.836 |  |
| 3049125 | Alpha-1-Microglobulin [Mass/volume] in Serum or Plasma | 0.836 |  |
| 40763006 | OLANZapine [Moles/volume] in Gastric fluid | 0.836 |  |
| 3037039 | Alpha 2 globulin [Mass/volume] in Urine by Electrophoresis | 0.834 |  |
| 43055428 | Alpha 1 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.833 |  |
| 3023602 | Cholesterol in HDL [Moles/volume] in Serum or Plasma | 0.833 | 38 |
| 40758725 | Goose feather IgE Ab [Presence] in Serum | 0.833 |  |
| 3042299 | inFLIXimab [Mass/volume] in Serum or Plasma | 0.832 |  |
| 1175998 | Cholesterol in LDL 2 [Moles/volume] in Serum or Plasma | 0.831 |  |
| 3020579 | Amylase [Enzymatic activity/time] in 24 hour Urine | 0.830 |  |
| 3037908 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma | 0.830 |  |
| 3052599 | HLA Ab [Presence] in Serum by Immunoassay | 0.830 |  |
| 3035516 | HLA Ab [Presence] | 0.829 |  |
| 1175571 | Cholesterol in LDL 3 [Moles/volume] in Serum or Plasma | 0.827 |  |
| 1175617 | Cholesterol in LDL 5 [Moles/volume] in Serum or Plasma | 0.827 |  |
| 3964850 | Sole IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.826 |  |
| 36304617 | Golimumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.826 |  |
| 42868677 | Cholesterol in VLDL 3 [Moles/volume] in Serum or Plasma | 0.825 | 765 |
| 1175889 | Cholesterol in LDL 1 [Moles/volume] in Serum or Plasma | 0.825 |  |
| 3002960 | cloZAPine+Norclozapine [Moles/volume] in Serum or Plasma | 0.824 |  |
| 43055424 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.822 |  |
| 3966239 | Fig IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.822 |  |
| 3013407 | Alcohol dehydrogenase [Enzymatic activity/volume] in Serum | 0.822 |  |
| 3018657 | Pigeon serum IgE Ab [Presence] in Serum | 0.822 |  |
| 1176311 | Cholesterol.in LDL.small dense [Mass/volume] in Serum or Plasma | 0.822 |  |
| 1091897 | Risankizumab [Mass/volume] in Serum or Plasma | 0.821 |  |
| 3027159 | OXcarbazepine [Moles/volume] in Serum or Plasma | 0.818 | 1659 |
| 43055489 | Aldolase [Enzymatic activity/mass] in Red Blood Cells | 0.817 |  |
| 3048480 | O-desmethylvenlafaxine [Moles/volume] in Serum or Plasma | 0.817 |  |
| 3965207 | Elder IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.816 |  |
| 646132 | HLA-A and B and C (class I) and HLA-DP and DQ and DR (class II) Ab.IgG donor specific [Identifier] in Serum or Plasma | 0.815 |  |
| 40758658 | Clopenthixol [Moles/volume] in Serum or Plasma | 0.815 |  |
| 1616853 | HLA-A and B and C (class I) IgG donor specific [Identifier] in Serum or Plasma | 0.814 |  |
| 3966196 | Vanilla IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.814 |  |
| 3041421 | Tissue transglutaminase IgG Ab [Presence] in Serum | 0.813 |  |
| 3966278 | Miscellaneous allergen IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.813 |  |
| 3015383 | N-desalkylflurazepam [Moles/volume] in Serum or Plasma | 0.813 |  |
| 645268 | Gliadin peptide IgG Ab [Measurement] in Serum | 0.812 |  |
| 1989156 | Adalimumab and Adalimumab Ab panel - Serum or Plasma by Immunoassay | 0.811 |  |
| 3008764 | Glyceraldehyde 3 phosphate dehydrogenase [Enzymatic activity/volume] in Serum | 0.811 |  |
| 3012984 | Norclozapine [Mass/volume] in Serum or Plasma | 0.810 |  |
| 36304315 | Certolizumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.810 |  |
| 3042394 | European house dust mite IgG Ab [Presence] in Serum | 0.809 |  |
| 40762648 | HLA IgG Ab [Presence] in Serum by Immunofluorescence | 0.808 |  |
| 1175178 | Eculizumab [Mass/volume] in Serum | 0.808 |  |
| 3030555 | Tissue transglutaminase IgA Ab [Presence] in Serum | 0.808 |  |
| 3016436 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | 0.808 | 156 |
| 3964894 | Fish Feed IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.807 |  |
| 3039873 | Cholesterol in LDL [Moles/volume] in Body fluid | 0.806 |  |
| 36305036 | Ustekinumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.806 |  |
| 3048259 | Amylase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.806 |  |
| 3041414 | Tissue transglutaminase Ab [Presence] in Serum | 0.806 |  |
| 3015359 | Malate dehydrogenase [Enzymatic activity/volume] in Serum | 0.806 |  |
| 44816662 | Soluble fms-like tyrosine kinase-1 and placental growth factor panel - Serum or Plasma | 0.805 |  |
| 3002555 | Alkaline phosphatase [Mass/volume] in Urine | 0.804 |  |
| 36303722 | Certolizumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.803 |  |
| 3003650 | Alkaline phosphatase [Mass/volume] in Body fluid | 0.803 |  |
| 3029285 | HLA Ab [Type] in Serum | 0.802 |  |
| 3042479 | Alkaline phosphatase.bone [Presence] in Serum or Plasma | 0.800 |  |
| 44816887 | Alkaline phosphatase.bone [Z-score] in Serum or Plasma | 0.796 |  |
| 3019808 | Fish Feed IgE Ab [Units/volume] in Serum | 0.793 |  |
| 3965957 | Codfish IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.793 |  |
| 3015483 | Nefazodone [Moles/volume] in Serum or Plasma | 0.793 |  |
| 3013751 | cloZAPine [Mass/volume] in Serum or Plasma | 0.792 |  |
| 43055237 | Amylase and triacylglycerol lipase panel - Serum or Plasma | 0.792 |  |
| 3965244 | Flounder IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.791 |  |
| 3049181 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.790 |  |
| 3044539 | Alkaline phosphatase.intestinal [Presence] in Serum or Plasma | 0.789 |  |
| 648009 | HLA Ab [Measurement] in Serum | 0.789 |  |
| 3964628 | Whitefish IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.787 |  |
| 3042545 | Alkaline phosphatase.bile/Alkaline phosphatase.total in Serum or Plasma | 0.785 |  |
| 3964748 | Plaice IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.783 |  |
| 3966264 | Tilapia IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.783 |  |
| 3041395 | Nucleosome Ab [Presence] in Serum | 0.782 |  |
| 3012718 | DNA double strand Ab [Presence] in Serum | 0.781 |  |
| 3050937 | sp100 Ab [Presence] in Serum | 0.778 |  |
| 3026942 | Alkaline phosphatase.liver 2/Alkaline phosphatase.total in Serum or Plasma | 0.775 |  |
| 3028089 | Alkaline phosphatase isoenzyme [Units/volume] in Serum or Plasma | 0.774 |  |
| 3036955 | Alkaline phosphatase.liver/Alkaline phosphatase.total in Serum or Plasma | 0.773 | 1664 |
| 40761116 | Natalizumab Ab [Presence] in Serum | 0.773 |  |
| 3012528 | Ribosomal Ab [Presence] in Serum | 0.771 |  |
| 3000636 | Histone Ab [Presence] in Serum | 0.769 |  |
| 3004616 | Nuclear Ab [Presence] in Serum | 0.767 | 208 |
| 3966146 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Serum or Plasma | 0.764 |  |
| 648992 | SAE-1 Ab [Presence] in Serum or Plasma | 0.764 |  |
| 3021222 | Alkaline phosphatase.renal/Alkaline phosphatase.total in Serum or Plasma | 0.764 |  |
| 646529 | TIF1-gamma IgG Ab [Presence] in Serum by Immunoassay | 0.763 |  |
| 40766110 | DNA double strand IgG Ab [Presence] in Serum | 0.763 |  |
| 3039358 | Amylase isoenzymes [Interpretation] in Body fluid Narrative | 0.763 |  |
| 648729 | TIF1-gamma Ab [Presence] in Serum or Plasma | 0.761 |  |
| 3043435 | Alkaline phosphatase isoenzymes [Enzymatic activity/volume] in Serum or Plasma by Levamisole inhibition | 0.755 |  |
| 46235359 | Vascular endothelial growth factor A [Mass/volume] in Serum or Plasma | 0.752 |  |
| 3965350 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Plasma | 0.748 |  |
| 3037841 | Amylase.P2/Amylase.total in Serum or Plasma | 0.746 |  |
| 3031767 | Vascular endothelial growth factor [Mass/volume] in Serum or Plasma | 0.746 |  |
| 3023712 | Amylase.P1/Amylase.total in Serum or Plasma | 0.742 |  |
| 3038143 | Amylase.P3/Amylase.total in Serum or Plasma | 0.742 |  |
| 3965684 | Tumor necrosis factor ligand superfamily member 10 [Mass/volume] in Serum, Plasma or Blood | 0.734 |  |
| 3021952 | Alkaline phosphatase isoenzymes [Enzymatic activity/volume] in Serum or Plasma by Heat stability | 0.732 |  |
| 42529047 | Vascular endothelial growth factor D [Mass/volume] in Serum or Plasma | 0.732 |  |
| 1616827 | Angiopoietin receptor 2 [Mass/volume] in Serum or Plasma | 0.727 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 967 | -amyl | u/l | 92% | name+unit+values | 4274 | 0.02 | [40.67, 91.53, 164.11, 263.2, 435.72, 740.04, 1305.95, 2688.49, 7694.97] |  |  |  | Amylase [Enzymatic activity/volume] in Serum or Plasma |
| 968 | -amyl |  | 8% | name | 352 | 100 |  |  |  |  | Amylase [Enzymatic activity/volume] in Serum or Plasma |
| 969 | alfa-1 | g/l | 100% | name+unit+values | 903 | 0 | [1.22, 1.5, 1.79, 2.2, 2.48, 2.68, 2.9, 3.11, 3.52] |  |  |  | Alpha 1 globulin [Mass/volume] in Serum |
| 970 | alfa-2 | g/l | 100% | name+unit+values | 907 | 0 | [5.23, 5.83, 6.25, 6.52, 6.87, 7.21, 7.57, 8.08, 8.88] |  |  |  | Alpha 2 globulin [Mass/volume] in Serum |
| 971 | amylaasi | u/l | 98% | name+unit+values | 1380 | 0 | [29.99, 37.09, 43.34, 48.9, 54.86, 61.15, 69.82, 79.08, 95.2] |  |  |  | Amylase [Enzymatic activity/volume] in Serum or Plasma |
| 972 | amylaasi |  | 2% | name | 28 | 100 |  |  |  |  | Amylase [Enzymatic activity/volume] in Serum or Plasma |
| 973 | as-amyl | u/l | 85% | name+unit+values | 277 | 0 | [7.26, 10.43, 15.58, 18.44, 24.17, 32.74, 51.52, 248.83, 2427.98] | As-Amylaasi | Ascitic fluid |  | Amylase [Enzymatic activity/volume] in Ascitic fluid |
| 974 | as-amyl |  | 15% | name | 47 | 100 |  | As-Amylaasi | Ascitic fluid |  | Amylase [Enzymatic activity/volume] in Ascitic fluid |
| 975 | du-aldos | nmol | 81% | name+unit+values | 1126 | 0.09 | [10.24, 15.47, 20.03, 24.86, 30.48, 36.38, 42.95, 53.9, 73.35] | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/time] in 24 hour Urine |
| 976 | du-aldos | nmol/24h | 2% | name+unit | 31 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/time] in 24 hour Urine |
| 977 | du-aldos | nmol/l | 2% | name+unit | 25 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/volume] in 24 hour Urine |
| 978 | du-aldos | ug/24h | 1% | name+unit | 12 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Mass/time] in 24 hour Urine |
| 979 | du-aldos |  | 14% | name+values | 191 | 100 | [8, 16, 20, 24.43, 29.88, 35.35, 48.9, 70.25, 89] | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/time] in 24 hour Urine |
| 980 | fp-afos | u/l | 100% | name+unit+values | 595 | 0 | [48.33, 55.17, 59.65, 63.83, 67.67, 73.36, 82.33, 90.3, 106.24] |  | Fasting plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 981 | fp-aldos | pmol/l | 92% | name+unit+values | 759 | 0.13 | [99.64, 177.36, 232.25, 287.09, 343.45, 412.76, 483.45, 604.01, 841.72] | fP-Aldosteroni | Fasting plasma |  | Aldosterone [Moles/volume] in Plasma |
| 982 | fp-aldos |  | 8% | name | 70 | 100 |  | fP-Aldosteroni | Fasting plasma |  | Aldosterone [Moles/volume] in Plasma |
| 983 | fp-amyl | u/l | 100% | name+unit+values | 166 | 0 | [38.37, 46.9, 53.45, 59.94, 65.12, 70.97, 77.12, 86.5, 100.71] |  | Fasting plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 984 | p-afos | u/l | 99% | name+unit+values | 2633385 | 0 | [49.21, 57.22, 63.75, 69.97, 76.72, 84.54, 94.72, 111.14, 150.6] | P -Alkalinen fosfataasi | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 985 | p-afos |  | 1% | name | 28410 | 100 |  | P -Alkalinen fosfataasi | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 986 | p-aldos | pmol/l | 93% | name+unit+values | 978 | 0 | [87.5, 146.01, 191, 236.08, 287.89, 347.09, 420.44, 545.67, 784.36] | P -Aldosteroni | Plasma |  | Aldosterone [Moles/volume] in Plasma |
| 987 | p-aldos |  | 7% | name | 71 | 100 |  | P -Aldosteroni | Plasma |  | Aldosterone [Moles/volume] in Plasma |
| 988 | p-amyl | u/l | 98% | name+unit+values | 368852 | 0 | [26.4, 34.18, 40.53, 46.43, 52.51, 59.29, 67.59, 79.75, 104.71] | P -Amylaasi | Plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 989 | p-amyl |  | 2% | name | 5758 | 100 |  | P -Amylaasi | Plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 990 | p-amylaasi | u/l | 98% | name+unit+values | 1560 | 0.19 | [27.94, 35.69, 41.43, 47.16, 52.68, 59.04, 66.76, 77.97, 99.1] |  | Plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 991 | p-amylaasi |  | 2% | name | 28 | 100 |  |  | Plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 992 | p-amylp | u/l | 86% | name+unit+values | 96538 | 0 | [14.18, 19.81, 23.07, 26.25, 29.84, 34.09, 39.97, 50.62, 84.58] | P -Amylaasi, haimaperäinen | Plasma |  | Amylase.pancreatic [Enzymatic activity/volume] in Plasma |
| 993 | p-amylp |  | 14% | name | 16102 | 100 |  | P -Amylaasi, haimaperäinen | Plasma |  | Amylase.pancreatic [Enzymatic activity/volume] in Plasma |
| 994 | p-sldl | mmol/l | 91% | name+unit+values | 2968 | 0 | [1.54, 1.82, 2.07, 2.31, 2.6, 2.9, 3.18, 3.53, 4.07] |  | Plasma |  | Cholesterol in small dense LDL [Moles/volume] in Plasma |
| 995 | p-sldl |  | 9% | name | 282 | 100 |  |  | Plasma |  | Cholesterol in small dense LDL [Moles/volume] in Plasma |
| 996 | pa-amyl | u/l | 93% | name+unit+values | 181 | 0 | [5.84, 8.3, 13.6, 23.86, 38.44, 92.97, 509.66, 2103.72, 16163.44] | Pa-Amylaasi | Pancreatic juice |  | Amylase [Enzymatic activity/volume] in Pancreatic fluid |
| 997 | pa-amyl |  | 7% | name | 13 | 100 |  | Pa-Amylaasi | Pancreatic juice |  | Amylase [Enzymatic activity/volume] in Pancreatic fluid |
| 998 | pf-amyl | u/l | 70% | name+unit+values | 512 | 0 | [11.6, 15.61, 19.05, 23.06, 27.88, 32.2, 37.91, 46.55, 61.71] | Pf-Amylaasi | Pleural fluid |  | Amylase [Enzymatic activity/volume] in Pleural fluid |
| 999 | pf-amyl |  | 30% | name | 216 | 100 |  | Pf-Amylaasi | Pleural fluid |  | Amylase [Enzymatic activity/volume] in Pleural fluid |
| 1000 | s-aaldos | pmol/l | 100% | name+unit+values | 125 | 0 | [492.5, 660.37, 766.83, 836.71, 911.78, 1067.67, 1144.73, 1426.33, 2247] |  | Serum |  | Aldosterone [Moles/volume] in Serum |
| 1001 | s-adali | mg/l | 65% | name+unit+values | 1092 | 0 | [4.2, 6.26, 7.85, 9.09, 10.32, 11.8, 13.1, 14.95, 17.6] | S -Adalimumabi | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 1002 | s-adali |  | 35% | name+values | 600 | 100 | [3.2, 5.14, 6.89, 8.2, 9.31, 11.07, 13.16, 15.13, 17.9] | S -Adalimumabi | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 1003 | s-adaliab | au/ml | 11% | name+unit+values | 257 | 0 | [4.61, 14.4, 21.93, 36.11, 43.5, 59.86, 106.84, 181.08, 359.99] | S -Adalimumabi, vasta-aineet | Serum |  | Adalimumab Ab [Units/volume] in Serum or Plasma |
| 1004 | s-adaliab |  | 89% | name | 2149 | 100 |  | S -Adalimumabi, vasta-aineet | Serum |  | Adalimumab Ab [Presence] in Serum or Plasma |
| 1005 | s-adalimu | mg/l | 88% | name+unit+values | 2004 | 0 | [3.45, 5.33, 6.83, 8.05, 9.31, 10.64, 12.15, 13.86, 16.79] |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 1006 | s-adalimu |  | 12% | name+values | 271 | 100 | [2.15, 3.5, 4.82, 5.98, 6.9, 7.69, 8.4, 9, 10.5] |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 1007 | s-adalip |  | 100% | name | 274 | 100 |  |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 1008 | s-adalipa |  | 100% | name | 1304 | 100 |  |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 1009 | s-afluu | % | 51% | name+unit+values | 92 | 5.43 | [10.6, 14.1, 19.5, 22.81, 26.08, 32.8, 35.7, 41.67, 46.1] |  | Serum |  | Alkaline phosphatase.bone specific/Alkaline phosphatase.total [Ratio] in Serum |
| 1010 | s-afluu | u/l | 44% | name+unit+values | 80 | 0 | [17.5, 21.17, 25.5, 29.5, 33.5, 39, 50.25, 58.5, 97.5] |  | Serum |  | Alkaline phosphatase.bone specific [Enzymatic activity/volume] in Serum |
| 1011 | s-afluu |  | 5% | name | 9 | 100 |  |  | Serum |  | Alkaline phosphatase.bone specific [Enzymatic activity/volume] in Serum |
| 1012 | s-afluust | u/l | 86% | name+unit+values | 3036 | 0 | [23.5, 30.51, 36.98, 43, 49.76, 57.03, 66.34, 80.71, 107.37] |  | Serum |  | Alkaline phosphatase.bone specific [Enzymatic activity/volume] in Serum |
| 1013 | s-afluust |  | 14% | name+values | 488 | 100 | [22.65, 29.1, 35.8, 41.93, 49.62, 57.31, 65.33, 75.04, 91.71] |  | Serum |  | Alkaline phosphatase.bone specific [Enzymatic activity/volume] in Serum |
| 1014 | s-afmuut | u/l | 83% | name+unit+values | 1555 | 0 | [0, 0, 0, 0.45, 1.94, 4.15, 7.91, 14.33, 30.08] |  | Serum |  | Alkaline phosphatase.other [Enzymatic activity/volume] in Serum |
| 1015 | s-afmuut |  | 17% | name | 316 | 100 |  |  | Serum |  | Alkaline phosphatase.other [Enzymatic activity/volume] in Serum |
| 1016 | s-afos | iu/l | 0% | name+unit+values | 240 | 0 | [47.27, 53.35, 59.29, 64.98, 70.68, 75.89, 83.7, 97.87, 129.57] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 1017 | s-afos | u/l | 98% | name+unit+values | 62976 | 0 | [49.03, 56.57, 62.54, 68.42, 74.5, 81.36, 90.37, 104.34, 129.79] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 1018 | s-afos |  | 2% | name+values | 986 | 100 | [68.48, 103.96, 114.21, 123.83, 133.19, 141.93, 153.42, 179.39, 242.73] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 1019 | s-afos-is | u/l | 1% | name+unit | 70 | 0 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes | Alkaline phosphatase isoenzymes panel - Serum |
| 1020 | s-afos-is |  | 99% | name | 9083 | 100 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes | Alkaline phosphatase isoenzymes panel - Serum |
| 1021 | s-afosluu | u/l | 62% | name+unit+values | 106 | 0 | [26, 31, 35.88, 39.85, 42.27, 50.97, 59.94, 73, 99.5] | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone specific [Enzymatic activity/volume] in Serum |
| 1022 | s-afosluu | ug/l | 18% | name+unit | 30 | 0 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone specific [Mass/volume] in Serum |
| 1023 | s-afosluu |  | 20% | name | 35 | 100 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone specific [Enzymatic activity/volume] in Serum |
| 1024 | s-afospit | u/l | 96% | name+unit+values | 177 | 0 | [96.56, 105.54, 113.04, 119.58, 129, 140.12, 153.78, 189.21, 316.1] |  | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 1025 | s-afospit |  | 4% | name | 8 | 100 |  |  | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 1026 | s-afsuol1 | u/l | 87% | name+unit+values | 1064 | 0 | [0, 0, 0, 0, 0, 1, 2.35, 4.91, 11.59] |  | Serum |  | Alkaline phosphatase.intestinal 1 [Enzymatic activity/volume] in Serum |
| 1027 | s-afsuol1 |  | 13% | name+values | 158 | 100 | [0, 0, 0, 0, 0.25, 1.4, 3.03, 6.2, 16.7] |  | Serum |  | Alkaline phosphatase.intestinal 1 [Enzymatic activity/volume] in Serum |
| 1028 | s-afsuol2 | u/l | 87% | name+unit+values | 1070 | 0 | [0, 0, 0, 0, 0, 0.67, 2.05, 4.42, 8.95] |  | Serum |  | Alkaline phosphatase.intestinal 2 [Enzymatic activity/volume] in Serum |
| 1029 | s-afsuol2 |  | 13% | name+values | 156 | 100 | [0, 0, 0, 0, 0, 1.25, 2.97, 4.53, 7.88] |  | Serum |  | Alkaline phosphatase.intestinal 2 [Enzymatic activity/volume] in Serum |
| 1030 | s-afsuol3 | u/l | 87% | name+unit+values | 1075 | 0 | [0, 0, 0, 0, 0, 0, 0, 1, 1.95] |  | Serum |  | Alkaline phosphatase.intestinal 3 [Enzymatic activity/volume] in Serum |
| 1031 | s-afsuol3 |  | 13% | name+values | 157 | 100 | [0, 0, 0, 0, 0, 0, 0, 1, 1] |  | Serum |  | Alkaline phosphatase.intestinal 3 [Enzymatic activity/volume] in Serum |
| 1032 | s-afsuoli | % | 12% | name+unit | 53 | 7.55 |  |  | Serum |  | Alkaline phosphatase.intestinal/Alkaline phosphatase.total [Ratio] in Serum |
| 1033 | s-afsuoli | u/l | 45% | name+unit+values | 189 | 0 | [1, 2.3, 4.12, 5.88, 7.08, 9, 12.72, 22.94, 34.47] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 1034 | s-afsuoli |  | 43% | name | 182 | 100 |  |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 1035 | s-albind | g/l | 84% | name+unit+values | 815 | 0.12 | [34.39, 37.62, 39.39, 40.83, 42.06, 43.01, 44.02, 45.22, 47.08] |  | Serum |  | Albumin [Mass/volume] in Serum |
| 1036 | s-albind |  | 16% | name+values | 155 | 100 | [33.36, 36.48, 38.92, 39.95, 41.15, 41.97, 42.8, 43.45, 45.96] |  | Serum |  | Albumin [Mass/volume] in Serum |
| 1037 | s-albu | g/l | 98% | name+unit+values | 554 | 0 | [34.72, 36.69, 38.31, 39.81, 40.79, 41.92, 43.29, 44.85, 46.9] |  | Serum |  | Albumin [Mass/volume] in Serum |
| 1038 | s-albu |  | 2% | name | 12 | 100 |  |  | Serum |  | Albumin [Mass/volume] in Serum |
| 1039 | s-album | g/l | 100% | name+unit+values | 27997 | 0 | [31, 34.31, 36.28, 37.68, 38.86, 39.95, 41.05, 42.32, 43.98] |  | Serum |  | Albumin [Mass/volume] in Serum |
| 1040 | s-album |  | 0% | name | 49 | 100 |  |  | Serum |  | Albumin [Mass/volume] in Serum |
| 1041 | s-aldol | u/l | 85% | name+unit+values | 3331 | 0.06 | [3.04, 3.83, 4.01, 4.85, 5, 5.92, 6.2, 7.12, 9.73] | S -Aldolaasi | Serum |  | Aldolase [Enzymatic activity/volume] in Serum |
| 1042 | s-aldol |  | 15% | name+values | 603 | 100 | [2.94, 3.6, 4.14, 4.48, 5.31, 5.69, 6.13, 7.2, 9.7] | S -Aldolaasi | Serum |  | Aldolase [Enzymatic activity/volume] in Serum |
| 1043 | s-aldos | pmol/l | 81% | name+unit+values | 5247 | 0 | [80.64, 115.08, 152.41, 191.39, 237.65, 292.23, 360.82, 461.41, 670.27] | S -Aldosteroni | Serum |  | Aldosterone [Moles/volume] in Serum |
| 1044 | s-aldos |  | 19% | name+values | 1207 | 100 | [89, 124.87, 165.92, 211.54, 274.91, 347.78, 457.83, 589.41, 873.13] | S -Aldosteroni | Serum |  | Aldosterone [Moles/volume] in Serum |
| 1045 | s-aldos-m | pmol/l | 57% | name+unit+values | 88 | 0 | [47, 57.1, 79.8, 116.1, 136, 213.6, 259.95, 333.65, 926] | S -Aldosteroni, makuu | Serum | Supine (lying down) | Aldosterone [Moles/volume] in Serum --supine |
| 1046 | s-aldos-m |  | 43% | name | 66 | 100 |  | S -Aldosteroni, makuu | Serum | Supine (lying down) | Aldosterone [Moles/volume] in Serum --supine |
| 1047 | s-aldos-p | pmol/l | 71% | name+unit+values | 824 | 0 | [78.48, 114.19, 152.86, 191.94, 236.28, 290.41, 364.22, 470.52, 658.4] | S -Aldosteroni, pysty | Serum | Upright (standing) | Aldosterone [Moles/volume] in Serum --upright |
| 1048 | s-aldos-p |  | 29% | name+values | 329 | 100 | [80.67, 123.44, 171.37, 229.16, 280.86, 334.95, 403.64, 546.89, 817.21] | S -Aldosteroni, pysty | Serum | Upright (standing) | Aldosterone [Moles/volume] in Serum --upright |
| 1049 | s-alfa-1 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  | Alpha 1 globulin [Mass Fraction] in Serum |
| 1050 | s-alfa-1 | g/l | 100% | name+unit+values | 30281 | 0 | [2.07, 2.39, 2.56, 2.7, 2.85, 3.01, 3.21, 3.51, 4.07] |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum |
| 1051 | s-alfa-1 |  | 0% | name | 50 | 100 |  |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum |
| 1052 | s-alfa-2 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  | Alpha 2 globulin [Mass Fraction] in Serum |
| 1053 | s-alfa-2 | g/l | 100% | name+unit+values | 30219 | 0 | [5.47, 5.95, 6.33, 6.68, 7.02, 7.4, 7.85, 8.42, 9.36] |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum |
| 1054 | s-alfa-2 |  | 0% | name | 50 | 100 |  |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum |
| 1055 | s-alfa1 | g/l | 95% | name+unit+values | 1708 | 0 | [1.46, 1.6, 1.7, 1.81, 1.95, 2.12, 2.36, 2.65, 3.02] |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum |
| 1056 | s-alfa1 |  | 5% | name | 92 | 100 |  |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum |
| 1057 | s-alfa2 | g/l | 95% | name+unit+values | 1768 | 0 | [5.72, 6.29, 6.69, 6.98, 7.28, 7.6, 8.04, 8.58, 9.38] |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum |
| 1058 | s-alfa2 |  | 5% | name | 92 | 100 |  |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum |
| 1059 | s-allige | u/ml | 39% | name+unit+values | 1753 | 0 | [0.12, 0.18, 0.31, 0.51, 0.83, 1.37, 2.39, 4.58, 12.46] | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab [Units/volume] in Serum |
| 1060 | s-allige |  | 61% | name | 2748 | 100 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab [Presence] in Serum |
| 1061 | s-amyl | u/l | 99% | name+unit+values | 10387 | 0.03 | [33.29, 39.82, 44.99, 49.86, 54.7, 59.91, 66.42, 75.19, 91.06] | S -Amylaasi | Serum |  | Amylase [Enzymatic activity/volume] in Serum |
| 1062 | s-amyl |  | 1% | name+values | 129 | 100 | [34, 39.9, 46.23, 52.13, 61, 67.24, 81.8, 119, 157] | S -Amylaasi | Serum |  | Amylase [Enzymatic activity/volume] in Serum |
| 1063 | s-amyl-is | form | 3% | name+unit | 15 | 0 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes | Amylase isoenzymes panel - Serum |
| 1064 | s-amyl-is |  | 97% | name | 434 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes | Amylase isoenzymes panel - Serum |
| 1065 | s-amylp | u/l | 81% | name+unit+values | 280 | 0 | [14.9, 20.56, 25.73, 30.47, 37.07, 44.5, 55.7, 69, 134.71] | S -Amylaasi, haimaperäinen | Serum |  | Amylase.pancreatic [Enzymatic activity/volume] in Serum |
| 1066 | s-amylp |  | 19% | name | 66 | 100 |  | S -Amylaasi, haimaperäinen | Serum |  | Amylase.pancreatic [Enzymatic activity/volume] in Serum |
| 1067 | s-amyls | u/l | 81% | name+unit+values | 256 | 0 | [12.15, 18.54, 23.8, 28.41, 34.57, 44.58, 62.25, 81.5, 120.24] | S -Amylaasi, sylkiperäinen | Serum |  | Amylase.salivary [Enzymatic activity/volume] in Serum |
| 1068 | s-amyls |  | 19% | name | 61 | 100 |  | S -Amylaasi, sylkiperäinen | Serum |  | Amylase.salivary [Enzymatic activity/volume] in Serum |
| 1069 | s-dmklots | nmol/l | 60% | name+unit+values | 15078 | 0 | [352.19, 494.52, 609.92, 726.65, 850.41, 983.47, 1136.85, 1329.87, 1635.23] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma |
| 1070 | s-dmklots | umol/l | 36% | name+unit+values | 9051 | 0 | [0.3, 0.4, 0.5, 0.6, 0.71, 0.83, 0.98, 1.18, 1.47] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma |
| 1071 | s-dmklots | âumol/l | 0% | name+unit | 32 | 0 |  | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma |
| 1072 | s-dmklots |  | 4% | name | 1117 | 100 |  | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma |
| 1073 | s-gliade | u/ml | 21% | name+unit | 23 | 0 |  |  | Serum |  | Deamidated gliadin peptide Ab [Units/volume] in Serum |
| 1074 | s-gliade |  | 79% | name | 84 | 100 |  |  | Serum |  | Deamidated gliadin peptide Ab [Presence] in Serum |
| 1075 | s-gliadie | u/ml | 82% | name+unit+values | 531 | 0.38 | [0, 0, 0, 0, 0.01, 0.01, 0.03, 0.08, 0.28] |  | Serum |  | Gliadin IgE Ab [Units/volume] in Serum |
| 1076 | s-gliadie |  | 18% | name+values | 118 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Serum |  | Gliadin IgE Ab [Presence] in Serum |
| 1077 | s-hladsa |  | 100% | name | 847 | 100 |  |  | Serum |  | HLA donor specific Ab [Presence] in Serum |
| 1078 | s-kalatue |  | 100% | name | 132 | 100 |  |  | Serum |  | Fish IgE Ab [Presence] in Serum |
| 1079 | s-kolaige | u/ml | 7% | name+unit | 14 | 0 |  |  | Serum |  | Dog dander IgE Ab [Units/volume] in Serum |
| 1080 | s-kolaige |  | 93% | name | 181 | 100 |  |  | Serum |  | Dog dander IgE Ab [Presence] in Serum |
| 1081 | s-kudosab |  | 100% | name | 1042 | 100 |  |  | Serum |  |  |
| 1082 | s-ngmuut |  | 100% | name | 16771 | 100 |  |  | Serum |  |  |
| 1083 | s-oaldos | pmol/l | 100% | name+unit+values | 200 | 0 | [645.8, 1979.75, 7029, 15824.5, 33688.89, 59834.29, 83261.67, 123700, 205840] |  | Serum |  | Aldosterone [Moles/volume] in Serum |
| 1084 | s-olants | nmol/l | 87% | name+unit+values | 4003 | 0 | [52.76, 76.27, 97.67, 118.63, 141.6, 166.04, 195.64, 235.14, 292.5] | S -Olantsapiini | Serum |  | Olanzapine [Moles/volume] in Serum or Plasma |
| 1085 | s-olants |  | 13% | name+values | 595 | 100 | [58.72, 85.72, 111.16, 132.16, 158.37, 189.52, 220.42, 262.15, 324.43] | S -Olantsapiini | Serum |  | Olanzapine [Moles/volume] in Serum or Plasma |
| 1086 | s-ovalbue | u/ml | 84% | name+unit+values | 86 | 0 | [0, 0.02, 0.03, 0.1, 0.2, 0.56, 2, 8.02, 21.8] |  | Serum |  | Ovalbumin IgE Ab [Units/volume] in Serum |
| 1087 | s-ovalbue |  | 16% | name | 16 | 100 |  |  | Serum |  | Ovalbumin IgE Ab [Presence] in Serum |
| 1088 | s-salis | mmol/l | 21% | name+unit | 56 | 0 |  | S -Salisylaatit | Serum |  | Salicylate [Moles/volume] in Serum or Plasma |
| 1089 | s-salis | umol/l | 33% | name+unit | 87 | 0 |  | S -Salisylaatit | Serum |  | Salicylate [Moles/volume] in Serum or Plasma |
| 1090 | s-salis |  | 46% | name | 121 | 100 |  | S -Salisylaatit | Serum |  | Salicylate [Moles/volume] in Serum or Plasma |
| 1091 | s-scl-t |  | 100% | name | 833 | 100 |  |  | Serum |  | Topoisomerase I Ab [Presence] in Serum |
| 1092 | s-sfit1 | ng/l | 100% | name+unit+values | 135 | 0 | [1977.12, 2547.75, 3224.22, 3788.61, 4607, 5533.06, 7127.6, 9338, 11489.25] | S -Endoteelikasvutekijän liukoinen reseptori | Serum |  | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum or Plasma |
| 1093 | s-sflt-1 | ng/l | 100% | name+unit+values | 318 | 0 | [1299.5, 1665.62, 2341.78, 3012.06, 3768.02, 4783.78, 6034.45, 7173.43, 9227.09] |  | Serum |  | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum or Plasma |
| 1094 | s-sldl | mmol/l | 93% | name+unit+values | 2207 | 0 | [1.75, 2.1, 2.37, 2.68, 2.95, 3.22, 3.51, 3.8, 4.24] |  | Serum |  | Cholesterol in small dense LDL [Moles/volume] in Serum |
| 1095 | s-sldl |  | 7% | name | 177 | 100 |  |  | Serum |  | Cholesterol in small dense LDL [Moles/volume] in Serum |
| 1096 | s-suoli | u/l | 92% | name+unit+values | 115 | 0 | [0, 0, 0, 0.25, 2.82, 5.66, 7.43, 12.05, 20.71] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 1097 | s-suoli |  | 8% | name | 10 | 100 |  |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 1098 | s-suolist | u/l | 56% | name+unit+values | 81 | 0 | [2, 3.1, 5.23, 9, 10.88, 13, 15.18, 20.53, 28] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 1099 | s-suolist |  | 44% | name | 63 | 100 |  |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 1100 | s-valdos | pmol/l | 100% | name+unit+values | 157 | 0 | [3394.93, 10217.43, 18958.33, 28660, 43056.25, 61996.67, 85263.1, 111783.33, 189600] |  | Serum |  | Aldosterone [Moles/volume] in Serum |
| 1101 | s-vedol | mg/l | 88% | name+unit+values | 1566 | 0 | [10.83, 14.14, 17.65, 20.72, 24.04, 27.49, 31.91, 37.07, 43.64] | S -Vedolitsumabi | Serum |  | Vedolizumab [Mass/volume] in Serum or Plasma |
| 1102 | s-vedol |  | 12% | name+values | 221 | 100 | [5.8, 9.08, 13.26, 17.46, 21.54, 25.78, 28.85, 33.26, 39.06] | S -Vedolitsumabi | Serum |  | Vedolizumab [Mass/volume] in Serum or Plasma |
| 1103 | saline |  | 100% | name+values | 946 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |  |
| 1104 | se-amyl | u/l | 87% | name+unit+values | 1679 | 0 | [7.8, 14.55, 24.41, 42.23, 81.61, 199.2, 551.93, 1798.18, 9649.08] | Se-Amylaasi | Secretion |  | Amylase [Enzymatic activity/volume] in Secretion |
| 1105 | se-amyl |  | 13% | name | 248 | 100 |  | Se-Amylaasi | Secretion |  | Amylase [Enzymatic activity/volume] in Secretion |
| 1106 | sp-suld |  | 100% | name | 262 | 100 |  |  | Sperm / semen |  |  |
| 1107 | u-amyl | u/l | 94% | name+unit+values | 2762 | 0 | [39.74, 60.69, 84.27, 110.54, 142.25, 183.92, 243.16, 332.86, 543.79] | U -Amylaasi | Urine |  | Amylase [Enzymatic activity/volume] in Urine |
| 1108 | u-amyl |  | 6% | name+values | 192 | 100 | [46, 101.5, 137, 162, 204.5, 269.5, 360.4, 595.9, 1056] | U -Amylaasi | Urine |  | Amylase [Enzymatic activity/volume] in Urine |
| 1109 | u-amylp | u/l | 88% | name+unit+values | 106 | 0 | [30.2, 44.1, 67.11, 89.77, 112.17, 152.84, 214.66, 337.6, 540.5] | U -Amylaasi, haimaperäinen | Urine |  | Amylase.pancreatic [Enzymatic activity/volume] in Urine |
| 1110 | u-amylp |  | 12% | name | 15 | 100 |  | U -Amylaasi, haimaperäinen | Urine |  | Amylase.pancreatic [Enzymatic activity/volume] in Urine |

