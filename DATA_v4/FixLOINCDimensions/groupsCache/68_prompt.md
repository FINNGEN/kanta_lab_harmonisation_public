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
Here is group 68.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000690 | Aldosterone [Moles/time] in 24 hour Urine | 1.000 |  |
| 3000998 | Ovalbumin IgE Ab [Units/volume] in Serum | 1.000 |  |
| 3015401 | Amylase [Enzymatic activity/volume] in Pleural fluid | 1.000 |  |
| 3016771 | Amylase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 152 |
| 3017315 | Amylase [Enzymatic activity/volume] in Urine | 1.000 |  |
| 3019396 | Amylase.pancreatic [Enzymatic activity/volume] in Urine | 1.000 |  |
| 3019677 | Aldosterone [Mass/time] in 24 hour Urine | 1.000 |  |
| 3019985 | Aldosterone [Moles/volume] in 24 hour Urine | 1.000 |  |
| 3027953 | Aldolase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 695 |
| 3035995 | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 23 |
| 3040370 | OLANZapine [Moles/volume] in Serum or Plasma | 1.000 |  |
| 36304052 | Adalimumab Ab [Units/volume] in Serum or Plasma | 1.000 |  |
| 44786774 | Adalimumab [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3004280 | Aldosterone [Moles/volume] in Serum or Plasma --supine | 0.980 |  |
| 3017950 | Salicylates [Moles/volume] in Serum or Plasma | 0.979 | 464 |
| 44816654 | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum | 0.974 |  |
| 3003171 | Aldosterone [Moles/volume] in Serum or Plasma --upright | 0.971 |  |
| 1091762 | Alpha 1 globulin [Mass/volume] in Serum or Plasma | 0.970 |  |
| 1092292 | Alpha 2 globulin [Mass/volume] in Serum or Plasma | 0.967 |  |
| 3001788 | Aldosterone [Moles/volume] in Serum or Plasma | 0.967 | 774 |
| 46236951 | Amylase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.965 |  |
| 3018910 | Alkaline phosphatase.bone [Mass/volume] in Serum or Plasma | 0.964 |  |
| 3024457 | Aldosterone [Mass/volume] in 24 hour Urine | 0.964 |  |
| 36031415 | Gliadin IgE Ab [Units/volume] in Serum | 0.963 |  |
| 44786773 | Adalimumab Ab [Mass/volume] in Serum or Plasma | 0.962 |  |
| 3016417 | Amylase.pancreatic [Enzymatic activity/volume] in Serum or Plasma | 0.961 |  |
| 3005685 | Amylase.salivary [Enzymatic activity/volume] in Serum or Plasma | 0.960 |  |
| 46235077 | Alkaline phosphatase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.960 |  |
| 3001467 | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum or Plasma | 0.959 | 1850 |
| 3020013 | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum or Plasma | 0.959 |  |
| 3024561 | Albumin [Mass/volume] in Serum or Plasma | 0.959 | 20 |
| 3007225 | Aldosterone free [Mass/time] in 24 hour Urine | 0.956 |  |
| 42868742 | Amylase.pancreatic [Enzymatic activity/volume] in Pleural fluid | 0.954 |  |
| 3014133 | Dog dander IgE Ab [Units/volume] in Serum | 0.954 | 1077 |
| 36305075 | Vedolizumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.951 |  |
| 36303365 | Adalimumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.944 |  |
| 3001110 | Alkaline phosphatase [Enzymatic activity/volume] in Blood | 0.944 |  |
| 1175645 | Adalimumab Ab [Units/volume] in Serum by Immunoassay | 0.939 |  |
| 1617569 | Cholesterol.in LDL.small dense [Moles/volume] in Serum or Plasma | 0.936 |  |
| 3021494 | OLANZapine [Mass/volume] in Serum or Plasma | 0.935 |  |
| 3014729 | Amylase.P1 [Enzymatic activity/volume] in Serum or Plasma | 0.935 |  |
| 36305882 | Vedolizumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.934 |  |
| 3017726 | Gliadin Ab [Units/volume] in Serum | 0.933 | 1663 |
| 3016625 | Amylase S1 [Enzymatic activity/volume] in Serum or Plasma | 0.933 |  |
| 3003966 | Gliadin IgG Ab [Units/volume] in Serum | 0.933 | 1637 |
| 46235169 | Amylase [Enzymatic activity/volume] in Blood | 0.932 |  |
| 3016848 | Dog dander IgG Ab [Units/volume] in Serum | 0.932 |  |
| 3005294 | Aldosterone [Mass/volume] in Serum or Plasma --supine | 0.931 |  |
| 3035400 | Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma | 0.930 | 1919 |
| 42870306 | Alkaline phosphatase.intestinal 3 [Enzymatic activity/volume] in Serum or Plasma | 0.929 |  |
| 3000831 | Aldosterone [Mass/volume] in Serum or Plasma --upright | 0.928 |  |
| 3004541 | Aldosterone [Moles/volume] in Urine | 0.928 |  |
| 40759832 | Dog dander+Dog epithelium IgE Ab [Units/volume] in Serum | 0.928 |  |
| 42870305 | Alkaline phosphatase.intestinal 2 [Enzymatic activity/volume] in Serum or Plasma | 0.928 |  |
| 3037820 | Gliadin IgA Ab [Units/volume] in Serum | 0.926 | 878 |
| 40761804 | Gliadin peptide IgG Ab [Units/volume] in Serum | 0.925 |  |
| 40761803 | Gliadin peptide IgA Ab [Units/volume] in Serum | 0.925 |  |
| 36304805 | Adalimumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.924 |  |
| 3010114 | Amylase isoenzyme 7 panel - Serum | 0.924 |  |
| 3020990 | Alkaline phosphatase.intestinal/Alkaline phosphatase.total in Serum or Plasma | 0.924 | 1783 |
| 3004155 | Amylase S2 [Enzymatic activity/volume] in Serum or Plasma | 0.924 |  |
| 3009876 | Amylase isoenzyme 3 panel - Serum or Plasma | 0.923 |  |
| 3001415 | Amylase [Enzymatic activity/volume] in 24 hour Urine | 0.921 |  |
| 3017651 | SCL-70 extractable nuclear IgG Ab [Presence] in Serum | 0.919 |  |
| 3009039 | Amylase.P2 [Enzymatic activity/volume] in Serum or Plasma | 0.916 |  |
| 3001660 | Gliadin IgM Ab [Units/volume] in Serum | 0.916 |  |
| 3015468 | Gliadin IgG Ab [Units/volume] in Serum by Immunoassay | 0.916 | 653 |
| 40771878 | Amylase [Enzymatic activity/volume] in Serum or Plasma --fasting | 0.915 |  |
| 3000787 | Salicylates [Mass/volume] in Serum or Plasma | 0.915 |  |
| 40766189 | Gliadin peptide IgG Ab [Units/volume] in Serum by Immunoassay | 0.914 |  |
| 3015174 | Gliadin IgA Ab [Units/volume] in Serum by Immunoassay | 0.914 | 694 |
| 3014568 | SCL-70 extractable nuclear Ab [Presence] in Serum | 0.914 |  |
| 40758706 | Salicylamide [Moles/volume] in Serum or Plasma | 0.913 |  |
| 3007970 | Alkaline phosphatase.bile [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |
| 3014599 | Egg white IgE Ab [Units/volume] in Serum | 0.913 | 799 |
| 3020233 | Acid phosphatase [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |
| 21492517 | Salicylurate [Moles/volume] in Serum or Plasma | 0.912 |  |
| 3003633 | Ovomucoid IgE Ab [Units/volume] in Serum | 0.911 |  |
| 1175553 | Vedolizumab and Vedolizumab Ab panel [Mass/volume] - Serum or Plasma | 0.911 |  |
| 3037597 | Macroamylase [Enzymatic activity/volume] in Serum or Plasma | 0.910 |  |
| 3021162 | Amylase [Enzymatic activity/volume] in Specimen | 0.909 |  |
| 3002069 | Alkaline phosphatase.bone/Alkaline phosphatase.total in Serum or Plasma | 0.909 | 1666 |
| 3018352 | Whole Egg IgE Ab [Units/volume] in Serum | 0.907 | 891 |
| 43055428 | Alpha 1 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.906 |  |
| 3002000 | Albumin [Mass/volume] in Specimen | 0.905 |  |
| 3002214 | Alkaline phosphatase.renal [Enzymatic activity/volume] in Serum or Plasma | 0.905 |  |
| 3001151 | Sole IgE Ab [Units/volume] in Serum | 0.905 |  |
| 3045684 | Alkaline phosphatase.other fractions [Enzymatic activity/volume] in Serum or Plasma | 0.905 |  |
| 3040995 | Amylase [Enzymatic activity/volume] in 12 hour Urine | 0.904 |  |
| 3036705 | Amylase [Enzymatic activity/volume] in 2 hour Urine | 0.904 |  |
| 3003860 | Alkaline phosphatase.regan [Enzymatic activity/volume] in Serum or Plasma | 0.903 |  |
| 649422 | Adalimumab Ab [Measurement] in Serum or Plasma | 0.903 |  |
| 1617227 | Adalimumab [Mass/volume] in Serum or Plasma --trough | 0.903 |  |
| 3015123 | Egg yolk IgE Ab [Units/volume] in Serum | 0.903 | 1080 |
| 3028564 | Alkaline phosphatase isoenz panel - Serum or Plasma | 0.902 |  |
| 3048601 | Amylase.pancreatic [Enzymatic activity/volume] in Body fluid | 0.902 |  |
| 1175847 | Vedolizumab [Mass/volume] in Serum or Plasma by LC/MS/MS --trough | 0.902 |  |
| 3015322 | Alpha 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.902 | 315 |
| 3039730 | Alkaline phosphatase.intestinal 3/Alkaline phosphatase.total in Serum or Plasma | 0.901 |  |
| 43055424 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.900 |  |
| 3035654 | Conalbumin IgE Ab [Units/volume] in Serum | 0.900 |  |
| 3008691 | Amylase [Enzymatic activity/volume] in Peritoneal fluid | 0.899 |  |
| 40765809 | Dog dander IgG Ab [Mass/volume] in Serum | 0.898 |  |
| 1260115 | Albumin [Mass/volume] in Serum by Immunoassay | 0.898 |  |
| 40763380 | OLANZapine [Moles/volume] in Specimen | 0.897 |  |
| 43533877 | Aldosterone-18-glucuronide [Moles/time] in 24 hour Urine | 0.897 |  |
| 43533876 | Aldosterone-18-glucuronide [Moles/volume] in 24 hour Urine | 0.896 |  |
| 3005166 | Alpha 1 globulin [Mass/volume] in Urine | 0.896 |  |
| 3005229 | Alpha 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.895 | 316 |
| 3039488 | Alkaline phosphatase.intestinal 2/Alkaline phosphatase.total in Serum or Plasma | 0.895 |  |
| 3002670 | Multiple inhalant allergen IgE Ab [Units/volume] in Serum | 0.894 |  |
| 3002538 | Oyster IgE Ab [Units/volume] in Serum | 0.893 | 1690 |
| 21492784 | Miscellaneous allergen IgE Ab [Units/volume] in Serum | 0.893 |  |
| 3023949 | Allscale IgE Ab [Units/volume] in Serum | 0.893 |  |
| 3032449 | Aldolase [Enzymatic activity/volume] in Body fluid | 0.891 |  |
| 3024218 | Fig IgE Ab [Units/volume] in Serum | 0.891 |  |
| 40759369 | Dog dander IgG4 Ab [Mass/volume] in Serum | 0.890 |  |
| 42868690 | Salicylates [Moles/volume] in Serum or Plasma by Screen method | 0.889 | 870 |
| 3010541 | Alpha 2 globulin [Mass/volume] in Urine | 0.888 |  |
| 3013765 | Hay IgE Ab [Units/volume] in Serum | 0.888 |  |
| 3019406 | Latex IgE Ab [Units/volume] in Serum | 0.887 | 1426 |
| 1175324 | Salicylcarnitine [Moles/volume] in Serum or Plasma | 0.887 |  |
| 3011337 | Aldosterone [Mass/volume] in Serum or Plasma | 0.887 |  |
| 3021476 | Amylase [Enzymatic activity/volume] in Duodenal fluid | 0.887 |  |
| 3025726 | SCL-70 extractable nuclear IgG Ab [Presence] in Serum by Immunoassay | 0.887 |  |
| 3025313 | Albumin [Mass/volume] in Body fluid | 0.887 | 1032 |
| 3014955 | Aldosterone [Mass/volume] in Urine | 0.886 |  |
| 3005090 | Alkaline phosphatase [Enzymatic activity/volume] in Body fluid | 0.886 |  |
| 44816899 | Dog native (nCan f) 1 IgE Ab [Units/volume] in Serum | 0.885 |  |
| 3030968 | Amylase [Enzymatic activity/volume] in Urine collected for unspecified duration | 0.884 |  |
| 1988210 | Ovalbumin IgG Ab [Mass/volume] in Serum | 0.884 |  |
| 40764094 | Dog dander IgE Ab/IgE total in Serum | 0.883 |  |
| 3016604 | IgE [Mass/volume] in Serum | 0.882 |  |
| 3042733 | HLA Ab [Presence] in Serum | 0.881 |  |
| 3043739 | Amylase [Enzymatic activity/volume] in Pericardial fluid | 0.881 |  |
| 3027320 | Salicylates [Moles/volume] in Specimen | 0.881 |  |
| 3013708 | Smelt IgE Ab [Units/volume] in Serum | 0.879 |  |
| 3001077 | Alkaline phosphatase [Enzymatic activity/volume] in Urine | 0.879 |  |
| 3008832 | Norclozapine [Moles/volume] in Serum or Plasma | 0.877 |  |
| 3000049 | SCL-70 extractable nuclear Ab [Presence] in Serum by Immunoassay | 0.877 | 1171 |
| 3020874 | Milk IgE Ab [Units/volume] in Serum | 0.876 | 1442 |
| 1176311 | Cholesterol.in LDL.small dense [Mass/volume] in Serum or Plasma | 0.876 |  |
| 3018001 | Oat IgE Ab [Units/volume] in Serum | 0.876 | 1486 |
| 40767673 | Dog recombinant 5 IgE Ab [Units/volume] in Serum | 0.876 |  |
| 3005322 | IgE [Units/volume] in Serum or Plasma | 0.876 | 466 |
| 44816883 | Amylase [Enzymatic activity/volume] in Saliva (oral fluid) | 0.876 |  |
| 3012133 | Amylase [Enzymatic activity/volume] in Body fluid | 0.875 | 771 |
| 40758600 | Aldosterone [Moles/volume] in Serum or Plasma --1 hour post dose corticotropin | 0.875 |  |
| 645478 | OLANZapine [Measurement] in Serum or Plasma | 0.874 |  |
| 3029321 | OLANZapine [Moles/volume] in Urine | 0.873 |  |
| 3033031 | Aldosterone [Moles/volume] in Serum or Plasma --post XXX challenge | 0.869 |  |
| 3004142 | Amylase [Enzymatic activity/volume] in Synovial fluid | 0.869 |  |
| 3040652 | Amylase [Units/volume] in 24 hour Urine | 0.869 |  |
| 3017341 | Amylase [Enzymatic activity/volume] in Amniotic fluid | 0.869 |  |
| 3016585 | Aldosterone [Mass/volume] in Serum or Plasma --baseline | 0.868 |  |
| 3023430 | Cat dander IgE Ab [Units/volume] in Serum | 0.868 | 715 |
| 3012516 | Albumin [Mass/volume] in Urine | 0.868 |  |
| 44786740 | Norolanzapine [Moles/volume] in Serum or Plasma | 0.866 |  |
| 3031598 | Aldosterone [Moles/volume] in Serum or Plasma --pre XXX challenge | 0.865 |  |
| 36660596 | Dog recombinant 6 IgE Ab [Units/volume] in Serum | 0.865 |  |
| 648474 | Amylase [Measurement] in Urine | 0.865 |  |
| 3013915 | Aldosterone [Mass/volume] in Blood | 0.865 |  |
| 3045829 | Aldosterone/Creatinine [Mass Ratio] in 24 hour Urine | 0.864 |  |
| 3028622 | Alkaline phosphatase.lung [Enzymatic activity/volume] in Serum or Plasma | 0.864 |  |
| 3015877 | Amylase.P3 [Enzymatic activity/volume] in Serum or Plasma | 0.863 |  |
| 3030162 | Aldosterone [Moles/volume] in Serum or Plasma --pre or post XXX challenge | 0.863 |  |
| 3018519 | Aldolase [Enzymatic activity/volume] in Red Blood Cells | 0.862 |  |
| 647232 | Aldosterone [Measurement] in Urine | 0.861 |  |
| 3010350 | SCL-70 extractable nuclear Ab [Presence] in Serum by Immunofluorescence | 0.861 |  |
| 40760707 | Aldosterone [Moles/volume] in Serum or Plasma --1 hour post XXX challenge | 0.861 |  |
| 649070 | Salicylates [Measurement] in Serum or Plasma | 0.860 |  |
| 43055511 | Salicylates [Mass/volume] in Serum or Plasma --trough | 0.860 |  |
| 3021643 | Salicylamide [Mass/volume] in Serum or Plasma | 0.859 |  |
| 3048752 | Lipase [Enzymatic activity/volume] in Pleural fluid | 0.859 |  |
| 647081 | HLA-A and B and C (class I) and HLA-DP and DQ and DR (class II) Ab.IgG donor specific [Presence] in Serum or Plasma | 0.858 |  |
| 3046505 | Aldolase [Enzymatic activity/volume] in Pleural fluid | 0.858 |  |
| 3016801 | Amylase [Enzymatic activity/volume] in Gastric fluid | 0.857 |  |
| 3965752 | Albumin [Mass/volume] in Serum or Plasma by Nephelometry | 0.856 |  |
| 42868730 | Amylase.pancreatic [Enzymatic activity/volume] in Peritoneal fluid | 0.855 |  |
| 3016436 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | 0.854 | 156 |
| 40757478 | Albumin [Moles/volume] in Serum or Plasma | 0.854 |  |
| 3012633 | Alpha 1 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.852 |  |
| 3024800 | Alpha 1 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.851 |  |
| 40759812 | SCL-70 extractable nuclear Ab [Presence] in Serum by Immunoblot | 0.851 |  |
| 43055427 | Alpha 1 globulin/Protein.total [Pure mass fraction] in Urine by Electrophoresis | 0.851 |  |
| 3033598 | Amylase isoenzymes [Interpretation] in Serum or Plasma | 0.850 |  |
| 3040682 | Aldosterone [Molar amount] in Urine collected for unspecified duration | 0.850 |  |
| 3006330 | Alpha 2 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.849 |  |
| 645900 | Alkaline phosphatase.bone [Measurement] in Serum or Plasma | 0.846 |  |
| 3010043 | Alpha 2 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.845 |  |
| 40766268 | SCL-70 extractable nuclear Ab [Presence] in Body fluid | 0.844 |  |
| 3009827 | Alpha-2-Macroglobulin [Mass/volume] in Serum or Plasma | 0.844 |  |
| 3022361 | Alpha 1 globulin [Mass/volume] in Urine by Electrophoresis | 0.843 |  |
| 43055426 | Alpha 1 globulin/Protein.total [Pure mass fraction] in 24 hour Urine by Electrophoresis | 0.843 |  |
| 43055423 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Urine by Electrophoresis | 0.843 |  |
| 36305571 | Albumin goal [Mass/volume] Serum or Plasma | 0.843 |  |
| 40762132 | Amylase [Enzymatic activity/volume] in Peritoneal dialysis fluid | 0.842 |  |
| 3002842 | SCL-70 extractable nuclear Ab [Presence] in Serum by Immune diffusion (ID) | 0.842 |  |
| 3046951 | IgE [Mass/volume] in Specimen | 0.841 |  |
| 3000081 | cloZAPine [Moles/volume] in Serum or Plasma | 0.841 |  |
| 3028286 | Albumin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.841 | 313 |
| 40763164 | OLANZapine [Mass/volume] in Blood | 0.840 |  |
| 3021886 | Globulin [Mass/volume] in Serum | 0.839 | 83 |
| 646542 | Albumin [Measurement] in Serum or Plasma | 0.839 |  |
| 40757623 | Alanine aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.838 |  |
| 3011887 | Alkaline phosphatase.other fractions/Alkaline phosphatase.total in Serum or Plasma | 0.838 |  |
| 3043889 | HLA Ab in Serum | 0.838 |  |
| 3036255 | Didesmethylcitalopram [Moles/volume] in Serum or Plasma | 0.836 |  |
| 3049125 | Alpha-1-Microglobulin [Mass/volume] in Serum or Plasma | 0.836 |  |
| 40763006 | OLANZapine [Moles/volume] in Gastric fluid | 0.836 |  |
| 3004185 | IgE.monoclonal [Mass/volume] in Serum | 0.835 |  |
| 3005783 | Lactate dehydrogenase 1 [Enzymatic activity/volume] in Serum or Plasma | 0.835 |  |
| 3037039 | Alpha 2 globulin [Mass/volume] in Urine by Electrophoresis | 0.834 |  |
| 43055422 | Alpha 2 globulin/Protein.total [Pure mass fraction] in 24 hour Urine by Electrophoresis | 0.834 |  |
| 646600 | SCL-70 extractable nuclear IgG Ab [Measurement] in Serum | 0.834 |  |
| 3017861 | Lactate dehydrogenase 2 [Enzymatic activity/volume] in Serum or Plasma | 0.832 |  |
| 3042299 | inFLIXimab [Mass/volume] in Serum or Plasma | 0.832 |  |
| 3042545 | Alkaline phosphatase.bile/Alkaline phosphatase.total in Serum or Plasma | 0.832 |  |
| 3020579 | Amylase [Enzymatic activity/time] in 24 hour Urine | 0.830 |  |
| 3037908 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma | 0.830 |  |
| 3052599 | HLA Ab [Presence] in Serum by Immunoassay | 0.830 |  |
| 43055429 | Alpha 1 globulin/Protein.total [Pure mass fraction] in Cerebral spinal fluid by Electrophoresis | 0.830 |  |
| 3009059 | Enolase [Enzymatic activity/volume] in Serum | 0.829 |  |
| 3035516 | HLA Ab [Presence] | 0.829 |  |
| 46234773 | IgE [Mass/volume] in Serum or Plasma by Immunoassay | 0.829 |  |
| 36304617 | Golimumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.826 |  |
| 3036955 | Alkaline phosphatase.liver/Alkaline phosphatase.total in Serum or Plasma | 0.826 | 1664 |
| 43055425 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Cerebral spinal fluid by Electrophoresis | 0.826 |  |
| 3042479 | Alkaline phosphatase.bone [Presence] in Serum or Plasma | 0.825 |  |
| 3002960 | cloZAPine+Norclozapine [Moles/volume] in Serum or Plasma | 0.824 |  |
| 44816655 | Soluble fms-like tyrosine kinase-1/placental growth factor [Ratio] in Serum | 0.824 |  |
| 3006769 | Lactate dehydrogenase 3 [Enzymatic activity/volume] in Serum or Plasma | 0.823 |  |
| 1091897 | Risankizumab [Mass/volume] in Serum or Plasma | 0.821 |  |
| 3030437 | Cholesterol in LDL.narrow density [Mass/volume] in Serum or Plasma | 0.820 |  |
| 3026076 | Alpha hydroxybutyrate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | 0.819 |  |
| 645131 | SCL-70 extractable nuclear Ab [Measurement] in Serum | 0.818 |  |
| 3027159 | OXcarbazepine [Moles/volume] in Serum or Plasma | 0.818 | 1659 |
| 3048480 | O-desmethylvenlafaxine [Moles/volume] in Serum or Plasma | 0.817 |  |
| 3021222 | Alkaline phosphatase.renal/Alkaline phosphatase.total in Serum or Plasma | 0.817 |  |
| 3019891 | Alpha 1 globulin/Protein.total in Body fluid by Electrophoresis | 0.816 |  |
| 3041414 | Tissue transglutaminase Ab [Presence] in Serum | 0.816 |  |
| 646132 | HLA-A and B and C (class I) and HLA-DP and DQ and DR (class II) Ab.IgG donor specific [Identifier] in Serum or Plasma | 0.815 |  |
| 40758658 | Clopenthixol [Moles/volume] in Serum or Plasma | 0.815 |  |
| 1616853 | HLA-A and B and C (class I) IgG donor specific [Identifier] in Serum or Plasma | 0.814 |  |
| 3015383 | N-desalkylflurazepam [Moles/volume] in Serum or Plasma | 0.813 |  |
| 3003650 | Alkaline phosphatase [Mass/volume] in Body fluid | 0.812 |  |
| 3012984 | Norclozapine [Mass/volume] in Serum or Plasma | 0.810 |  |
| 36304315 | Certolizumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.810 |  |
| 40762648 | HLA IgG Ab [Presence] in Serum by Immunofluorescence | 0.808 |  |
| 1175178 | Eculizumab [Mass/volume] in Serum | 0.808 |  |
| 36305036 | Ustekinumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.806 |  |
| 3048259 | Amylase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.806 |  |
| 44816887 | Alkaline phosphatase.bone [Z-score] in Serum or Plasma | 0.806 |  |
| 3005504 | Alpha 2 globulin/Protein.total in Body fluid by Electrophoresis | 0.806 |  |
| 3001308 | Cholesterol in LDL [Moles/volume] in Serum or Plasma | 0.805 | 92 |
| 3005932 | Smooth muscle Ab [Presence] in Serum | 0.805 | 1219 |
| 36303722 | Certolizumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.803 |  |
| 3029285 | HLA Ab [Type] in Serum | 0.802 |  |
| 3037225 | Intercellular substance Ab [Presence] in Serum | 0.802 |  |
| 3002555 | Alkaline phosphatase [Mass/volume] in Urine | 0.798 |  |
| 3015483 | Nefazodone [Moles/volume] in Serum or Plasma | 0.793 |  |
| 3013751 | cloZAPine [Mass/volume] in Serum or Plasma | 0.792 |  |
| 43055237 | Amylase and triacylglycerol lipase panel - Serum or Plasma | 0.792 |  |
| 3046961 | Epidermis Ab [Presence] in Serum | 0.792 |  |
| 3013055 | A Ab [Presence] in Serum or Plasma | 0.792 |  |
| 3017800 | H Ab [Presence] in Serum | 0.791 |  |
| 3030555 | Tissue transglutaminase IgA Ab [Presence] in Serum | 0.791 |  |
| 3049181 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.790 |  |
| 648009 | HLA Ab [Measurement] in Serum | 0.789 |  |
| 3041421 | Tissue transglutaminase IgG Ab [Presence] in Serum | 0.788 |  |
| 3050937 | sp100 Ab [Presence] in Serum | 0.787 |  |
| 3022487 | Cholesterol in VLDL [Moles/volume] in Serum or Plasma | 0.786 | 219 |
| 44816662 | Soluble fms-like tyrosine kinase-1 and placental growth factor panel - Serum or Plasma | 0.782 |  |
| 3028089 | Alkaline phosphatase isoenzyme [Units/volume] in Serum or Plasma | 0.774 |  |
| 37020823 | Lipoprotein.broad beta.subparticle.small [Moles/volume] in Serum | 0.773 |  |
| 1175998 | Cholesterol in LDL 2 [Moles/volume] in Serum or Plasma | 0.771 |  |
| 1175617 | Cholesterol in LDL 5 [Moles/volume] in Serum or Plasma | 0.770 |  |
| 1175571 | Cholesterol in LDL 3 [Moles/volume] in Serum or Plasma | 0.767 |  |
| 3039358 | Amylase isoenzymes [Interpretation] in Body fluid Narrative | 0.763 |  |
| 3047120 | Alkaline phosphatase.liver+bone [Presence] in Serum or Plasma | 0.762 |  |
| 37020736 | Lipoprotein.pre-beta.subparticle.small [Moles/volume] in Serum | 0.760 |  |
| 46235359 | Vascular endothelial growth factor A [Mass/volume] in Serum or Plasma | 0.759 |  |
| 3043435 | Alkaline phosphatase isoenzymes [Enzymatic activity/volume] in Serum or Plasma by Levamisole inhibition | 0.755 |  |
| 3966146 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Serum or Plasma | 0.753 |  |
| 3031767 | Vascular endothelial growth factor [Mass/volume] in Serum or Plasma | 0.750 |  |
| 3037841 | Amylase.P2/Amylase.total in Serum or Plasma | 0.746 |  |
| 3023712 | Amylase.P1/Amylase.total in Serum or Plasma | 0.742 |  |
| 3038143 | Amylase.P3/Amylase.total in Serum or Plasma | 0.742 |  |
| 3965350 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Plasma | 0.741 |  |
| 3039873 | Cholesterol in LDL [Moles/volume] in Body fluid | 0.741 |  |
| 3965684 | Tumor necrosis factor ligand superfamily member 10 [Mass/volume] in Serum, Plasma or Blood | 0.738 |  |
| 42529047 | Vascular endothelial growth factor D [Mass/volume] in Serum or Plasma | 0.736 |  |
| 44816653 | Placental growth factor [Mass/volume] in Serum | 0.733 |  |
| 3021952 | Alkaline phosphatase isoenzymes [Enzymatic activity/volume] in Serum or Plasma by Heat stability | 0.732 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 803 | -amyl | u/l | 92% | name+unit+values | 4274 | 0 | [40.79, 91.13, 163.85, 262.6, 433.78, 741.28, 1310.78, 2709.64, 7550.04] |  |  |  | Amylase [Enzymatic activity/volume] in Serum or Plasma |
| 804 | -amyl |  | 8% | name | 352 | 99.15 |  |  |  |  | Amylase [Enzymatic activity/volume] in Serum or Plasma |
| 805 | alfa-1 | g/l | 100% | name+unit+values | 903 | 0 | [1.23, 1.5, 1.79, 2.22, 2.48, 2.68, 2.88, 3.11, 3.51] |  |  |  | Alpha 1 globulin [Mass/volume] in Serum |
| 806 | alfa-2 | g/l | 100% | name+unit+values | 907 | 0 | [5.21, 5.83, 6.26, 6.53, 6.88, 7.18, 7.58, 8.1, 8.87] |  |  |  | Alpha 2 globulin [Mass/volume] in Serum |
| 807 | amylaasi | u/l | 98% | name+unit+values | 1380 | 0 | [29.91, 37.05, 43.3, 48.81, 54.92, 61.3, 69.75, 79.02, 95.18] |  |  |  | Amylase [Enzymatic activity/volume] in Serum or Plasma |
| 808 | amylaasi |  | 2% | name | 28 | 100 |  |  |  |  | Amylase [Enzymatic activity/volume] in Serum or Plasma |
| 809 | as-amyl | u/l | 85% | name+unit+values | 277 | 0 | [7.29, 10.51, 15.56, 18.22, 24.01, 33.76, 50.6, 245.04, 2494.39] | As-Amylaasi | Ascitic fluid |  | Amylase [Enzymatic activity/volume] in Ascitic fluid |
| 810 | as-amyl |  | 15% | name | 47 | 87.23 |  | As-Amylaasi | Ascitic fluid |  | Amylase [Enzymatic activity/volume] in Ascitic fluid |
| 811 | du-aldos | nmol | 81% | name+unit+values | 1126 | 1.15 | [10.3, 15.49, 20, 24.81, 30.39, 36.32, 42.97, 53.97, 73.23] | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/time] in 24 hour Urine |
| 812 | du-aldos | nmol/24h | 2% | name+unit | 31 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/time] in 24 hour Urine |
| 813 | du-aldos | nmol/l | 2% | name+unit | 25 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/volume] in 24 hour Urine |
| 814 | du-aldos | ug/24h | 1% | name+unit | 12 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Mass/time] in 24 hour Urine |
| 815 | du-aldos |  | 14% | name+values | 191 | 49.21 | [8, 15.27, 20, 24.32, 29.5, 36, 48.62, 70.25, 89] | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/time] in 24 hour Urine |
| 816 | fp-afos | u/l | 100% | name+unit+values | 595 | 0 | [48.33, 55.25, 59.57, 63.86, 67.6, 73.77, 82.28, 90.12, 106.03] |  | Fasting plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 817 | fp-aldos | pmol/l | 92% | name+unit+values | 759 | 0 | [99.71, 178.79, 234.24, 287.4, 344.18, 414.36, 481.84, 606.93, 836.03] | fP-Aldosteroni | Fasting plasma |  | Aldosterone [Moles/volume] in Plasma |
| 818 | fp-aldos |  | 8% | name | 70 | 70 |  | fP-Aldosteroni | Fasting plasma |  | Aldosterone [Moles/volume] in Plasma |
| 819 | fp-amyl | u/l | 100% | name+unit+values | 166 | 0 | [38.7, 46.83, 53.52, 59.77, 65.17, 71.18, 77.02, 86.88, 100.9] |  | Fasting plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 820 | p-afos | u/l | 99% | name+unit+values | 2633385 | 0.01 | [49.38, 57.42, 63.93, 70.22, 76.89, 84.76, 95, 111.35, 151.36] | P -Alkalinen fosfataasi | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 821 | p-afos |  | 1% | name+values | 28410 | 100 | [47.41, 55.11, 61.31, 67.35, 73.68, 80.95, 90.67, 106.27, 134.65] | P -Alkalinen fosfataasi | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 822 | p-aldos | pmol/l | 93% | name+unit+values | 978 | 0 | [88.37, 146.16, 190.71, 235.98, 287.48, 347.26, 419.69, 540.86, 783.53] | P -Aldosteroni | Plasma |  | Aldosterone [Moles/volume] in Plasma |
| 823 | p-aldos |  | 7% | name | 71 | 88.73 |  | P -Aldosteroni | Plasma |  | Aldosterone [Moles/volume] in Plasma |
| 824 | p-amyl | u/l | 98% | name+unit+values | 368852 | 0.02 | [26.2, 33.98, 40.36, 46.26, 52.37, 59.2, 67.68, 79.78, 104.76] | P -Amylaasi | Plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 825 | p-amyl |  | 2% | name+values | 5758 | 100 | [29, 36.73, 43, 48.41, 54.21, 60.53, 68.18, 78.9, 100.7] | P -Amylaasi | Plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 826 | p-amylaasi | u/l | 98% | name+unit+values | 1560 | 0 | [28.07, 35.77, 41.54, 47.32, 52.57, 59.03, 66.78, 77.77, 99.14] |  | Plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 827 | p-amylaasi |  | 2% | name | 28 | 89.29 |  |  | Plasma |  | Amylase [Enzymatic activity/volume] in Plasma |
| 828 | p-amylp | u/l | 86% | name+unit+values | 96538 | 0 | [14.27, 20, 23.24, 26.43, 29.95, 34.28, 40.26, 51.17, 86.4] | P -Amylaasi, haimaperäinen | Plasma |  | Amylase.pancreatic [Enzymatic activity/volume] in Plasma |
| 829 | p-amylp |  | 14% | name+values | 16102 | 100 | [12.88, 17.77, 21.4, 24.41, 27.47, 31.02, 35.38, 42.83, 60.62] | P -Amylaasi, haimaperäinen | Plasma |  | Amylase.pancreatic [Enzymatic activity/volume] in Plasma |
| 830 | p-sldl | mmol/l | 91% | name+unit+values | 2968 | 0 | [1.54, 1.82, 2.07, 2.32, 2.6, 2.9, 3.19, 3.53, 4.07] |  | Plasma |  | LDL cholesterol.small dense [Moles/volume] in Plasma |
| 831 | p-sldl |  | 9% | name | 282 | 86.52 |  |  | Plasma |  | LDL cholesterol.small dense [Moles/volume] in Plasma |
| 832 | pa-amyl | u/l | 93% | name+unit+values | 181 | 0 | [6, 8.3, 13.62, 23.54, 38.11, 86.55, 532.84, 2066.13, 14410] | Pa-Amylaasi | Pancreatic juice |  | Amylase [Enzymatic activity/volume] in Pancreatic fluid |
| 833 | pa-amyl |  | 7% | name | 13 | 100 |  | Pa-Amylaasi | Pancreatic juice |  | Amylase [Enzymatic activity/volume] in Pancreatic fluid |
| 834 | pf-amyl | u/l | 70% | name+unit+values | 512 | 0 | [11.47, 15.64, 19.01, 23.1, 27.84, 32.18, 37.92, 46.58, 62.15] | Pf-Amylaasi | Pleural fluid |  | Amylase [Enzymatic activity/volume] in Pleural fluid |
| 835 | pf-amyl |  | 30% | name | 216 | 100 |  | Pf-Amylaasi | Pleural fluid |  | Amylase [Enzymatic activity/volume] in Pleural fluid |
| 836 | s-aaldos | pmol/l | 100% | name+unit+values | 125 | 0.8 | [506.75, 663.13, 772.54, 837.76, 918.5, 1062, 1146, 1442.2, 2247] |  | Serum |  | Aldosterone [Moles/volume] in Serum |
| 837 | s-adali | mg/l | 65% | name+unit+values | 1092 | 0.37 | [4.24, 6.27, 7.87, 9.1, 10.33, 11.83, 13.14, 14.95, 17.6] | S -Adalimumabi | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 838 | s-adali |  | 35% | name+values | 600 | 16.67 | [3.21, 5.15, 6.89, 8.21, 9.3, 11.07, 13.15, 15.09, 18] | S -Adalimumabi | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 839 | s-adaliab | au/ml | 11% | name+unit+values | 257 | 1.17 | [4.47, 14.51, 21.55, 36.22, 43.39, 60.38, 104.64, 181.31, 370.6] | S -Adalimumabi, vasta-aineet | Serum |  | Adalimumab Ab [Units/volume] in Serum or Plasma |
| 840 | s-adaliab |  | 89% | name | 2149 | 99.3 |  | S -Adalimumabi, vasta-aineet | Serum |  | Adalimumab Ab [Units/volume] in Serum or Plasma |
| 841 | s-adalimu | mg/l | 88% | name+unit+values | 2004 | 0 | [3.43, 5.38, 6.89, 8.1, 9.37, 10.76, 12.24, 13.87, 16.85] |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 842 | s-adalimu |  | 12% | name+values | 271 | 52.03 | [2.22, 3.86, 5.11, 6.02, 6.96, 7.78, 8.44, 9.23, 10.15] |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 843 | s-adalip |  | 100% | name | 274 | 100 |  |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 844 | s-adalipa |  | 100% | name | 1304 | 100 |  |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma |
| 845 | s-afluu | % | 51% | name+unit+values | 92 | 0 | [10.3, 14.1, 19.33, 22.23, 25.37, 32.17, 35.52, 40.85, 45.6] |  | Serum |  | Alkaline phosphatase.bone/Alkaline phosphatase.total [Enzyme fraction] in Serum |
| 846 | s-afluu | u/l | 44% | name+unit+values | 80 | 0 | [17.5, 21, 25.5, 29.5, 33.5, 38.75, 50, 58.5, 97.5] |  | Serum |  | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum |
| 847 | s-afluu |  | 5% | name | 9 | 77.78 |  |  | Serum |  | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum |
| 848 | s-afluust | u/l | 86% | name+unit+values | 3036 | 0 | [23.45, 30.5, 36.88, 43.03, 49.77, 57.33, 66.23, 80.75, 107.75] |  | Serum |  | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum |
| 849 | s-afluust |  | 14% | name+values | 488 | 63.73 | [22.65, 29.23, 35.8, 41.92, 49.43, 57.83, 64.94, 75.26, 91.6] |  | Serum |  | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum |
| 850 | s-afmuut | u/l | 83% | name+unit+values | 1555 | 0 | [0, 0, 0, 0.56, 2.03, 4.33, 8.12, 14.99, 30.62] |  | Serum |  | Alkaline phosphatase.other [Enzymatic activity/volume] in Serum |
| 851 | s-afmuut |  | 17% | name | 316 | 96.2 |  |  | Serum |  | Alkaline phosphatase.other [Enzymatic activity/volume] in Serum |
| 852 | s-afos | iu/l | 0% | name+unit+values | 240 | 0 | [47.27, 53.32, 59.23, 65.05, 70.65, 75.95, 84.63, 98.48, 130] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 853 | s-afos | u/l | 98% | name+unit+values | 62976 | 0 | [49.01, 56.54, 62.55, 68.34, 74.46, 81.49, 90.44, 104.36, 129.97] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 854 | s-afos |  | 2% | name+values | 986 | 36 | [88.65, 108.98, 118.14, 127.37, 135.4, 144.04, 157.28, 186.3, 252.69] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 855 | s-afos-is | u/l | 1% | name+unit | 70 | 0 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes | Alkaline phosphatase isoenzymes panel - Serum |
| 856 | s-afos-is |  | 99% | name | 9083 | 99.98 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes | Alkaline phosphatase isoenzymes panel - Serum |
| 857 | s-afosluu | u/l | 62% | name+unit+values | 106 | 0 | [25.67, 31, 35.33, 39.5, 42, 50.37, 59.67, 72.5, 100] | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum |
| 858 | s-afosluu | ug/l | 18% | name+unit | 30 | 0 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone [Mass/volume] in Serum |
| 859 | s-afosluu |  | 20% | name | 35 | 11.43 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum |
| 860 | s-afospit | u/l | 96% | name+unit+values | 177 | 0 | [96.72, 105.51, 113.04, 119.21, 129.13, 139.98, 153.3, 187.04, 317.98] |  | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 861 | s-afospit |  | 4% | name | 8 | 37.5 |  |  | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 862 | s-afsuol1 | u/l | 87% | name+unit+values | 1064 | 0 | [0, 0, 0, 0, 0, 0.97, 2.27, 4.95, 11.83] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 863 | s-afsuol1 |  | 13% | name+values | 158 | 1.27 | [0, 0, 0, 0, 0.17, 1.4, 3, 6.28, 16.75] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 864 | s-afsuol2 | u/l | 87% | name+unit+values | 1070 | 0 | [0, 0, 0, 0, 0, 0.76, 2.02, 4.43, 8.94] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 865 | s-afsuol2 |  | 13% | name+values | 156 | 0.64 | [0, 0, 0, 0, 0, 1.25, 3, 4.75, 8] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 866 | s-afsuol3 | u/l | 87% | name+unit+values | 1075 | 0 | [0, 0, 0, 0, 0, 0, 0, 1, 1.91] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 867 | s-afsuol3 |  | 13% | name+values | 157 | 0.64 | [0, 0, 0, 0, 0, 0, 0, 1, 1] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 868 | s-afsuoli | % | 12% | name+unit | 53 | 0 |  |  | Serum |  | Alkaline phosphatase.intestinal/Alkaline phosphatase.total [Enzyme fraction] in Serum |
| 869 | s-afsuoli | u/l | 45% | name+unit+values | 189 | 0 | [1, 2.2, 4.12, 5.94, 7, 9.07, 12.69, 23.37, 34.67] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 870 | s-afsuoli |  | 43% | name | 182 | 96.15 |  |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 871 | s-albind | g/l | 84% | name+unit+values | 815 | 0 | [34.39, 37.6, 39.38, 40.81, 42.07, 43.01, 44.01, 45.22, 47.08] |  | Serum |  | Albumin [Mass/volume] in Serum |
| 872 | s-albind |  | 16% | name+values | 155 | 25.81 | [33.15, 36.46, 38.93, 39.99, 41.28, 41.98, 42.86, 43.61, 45.95] |  | Serum |  | Albumin [Mass/volume] in Serum |
| 873 | s-albu | g/l | 98% | name+unit+values | 554 | 0 | [34.76, 36.69, 38.29, 39.83, 40.76, 41.89, 43.25, 44.88, 46.93] |  | Serum |  | Albumin [Mass/volume] in Serum |
| 874 | s-albu |  | 2% | name | 12 | 33.33 |  |  | Serum |  | Albumin [Mass/volume] in Serum |
| 875 | s-album | g/l | 100% | name+unit+values | 27997 | 0 | [31.02, 34.31, 36.21, 37.6, 38.74, 39.81, 40.91, 42.12, 43.69] |  | Serum |  | Albumin [Mass/volume] in Serum |
| 876 | s-album |  | 0% | name+values | 49 | 100 | [31.46, 35.04, 37.29, 38.99, 40.3, 41.52, 42.95, 44.52, 46.29] |  | Serum |  | Albumin [Mass/volume] in Serum |
| 877 | s-aldol | u/l | 85% | name+unit+values | 3331 | 0.03 | [3.03, 3.84, 4, 4.87, 5, 5.94, 6.21, 7.11, 9.71] | S -Aldolaasi | Serum |  | Aldolase [Enzymatic activity/volume] in Serum or Plasma |
| 878 | s-aldol |  | 15% | name+values | 603 | 75.79 | [2.92, 3.62, 4.18, 4.48, 5.37, 5.7, 6.13, 7.21, 9.7] | S -Aldolaasi | Serum |  | Aldolase [Enzymatic activity/volume] in Serum or Plasma |
| 879 | s-aldos | pmol/l | 81% | name+unit+values | 5247 | 0.88 | [80.92, 114.8, 152.73, 192.44, 237.39, 292.55, 361.76, 461.2, 667.49] | S -Aldosteroni | Serum |  | Aldosterone [Moles/volume] in Serum |
| 880 | s-aldos |  | 19% | name+values | 1207 | 72.49 | [89.4, 124.94, 166.83, 212.25, 274.25, 349.09, 455.92, 585.04, 869.75] | S -Aldosteroni | Serum |  | Aldosterone [Moles/volume] in Serum |
| 881 | s-aldos-m | pmol/l | 57% | name+unit+values | 88 | 0 | [47, 57.1, 78.9, 115.83, 136, 213.63, 263.1, 334.4, 926] | S -Aldosteroni, makuu | Serum | Supine (lying down) | Aldosterone [Moles/volume] in Serum --supine |
| 882 | s-aldos-m |  | 43% | name | 66 | 68.18 |  | S -Aldosteroni, makuu | Serum | Supine (lying down) | Aldosterone [Moles/volume] in Serum --supine |
| 883 | s-aldos-p | pmol/l | 71% | name+unit+values | 824 | 0 | [77.23, 114.1, 153.16, 191.49, 236.83, 292.92, 363.97, 474.9, 659.05] | S -Aldosteroni, pysty | Serum | Upright (standing) | Aldosterone [Moles/volume] in Serum --upright |
| 884 | s-aldos-p |  | 29% | name+values | 329 | 21.88 | [79.42, 123.32, 172.77, 232.62, 283.29, 334.05, 403.83, 552.65, 812.7] | S -Aldosteroni, pysty | Serum | Upright (standing) | Aldosterone [Moles/volume] in Serum --upright |
| 885 | s-alfa-1 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  | Alpha 1 globulin/Protein.total [Mass Fraction] in Serum |
| 886 | s-alfa-1 | g/l | 100% | name+unit+values | 30281 | 0 | [2.19, 2.42, 2.6, 2.72, 2.88, 3.03, 3.24, 3.54, 4.08] |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum |
| 887 | s-alfa-1 |  | 0% | name+values | 50 | 100 | [1.5, 1.7, 1.88, 2.13, 2.38, 2.62, 2.88, 3.19, 3.81] |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum |
| 888 | s-alfa-2 | % | 0% | name+unit | 11 | 0 |  |  | Serum |  | Alpha 2 globulin/Protein.total [Mass Fraction] in Serum |
| 889 | s-alfa-2 | g/l | 100% | name+unit+values | 30219 | 0 | [5.45, 5.93, 6.31, 6.66, 7.01, 7.39, 7.84, 8.42, 9.36] |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum |
| 890 | s-alfa-2 |  | 0% | name+values | 50 | 100 | [5.71, 6.15, 6.53, 6.83, 7.14, 7.51, 7.91, 8.44, 9.39] |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum |
| 891 | s-alfa1 | g/l | 95% | name+unit+values | 1708 | 0 | [1.45, 1.6, 1.7, 1.8, 1.95, 2.11, 2.38, 2.65, 3.03] |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum |
| 892 | s-alfa1 |  | 5% | name | 92 | 25 |  |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum |
| 893 | s-alfa2 | g/l | 95% | name+unit+values | 1768 | 0 | [5.73, 6.28, 6.69, 6.98, 7.28, 7.59, 8.04, 8.57, 9.36] |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum |
| 894 | s-alfa2 |  | 5% | name | 92 | 25 |  |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum |
| 895 | s-allige | mg/l | 0% | name+unit | 14 | 0 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab [Mass/volume] in Serum |
| 896 | s-allige | u/ml | 39% | name+unit+values | 1753 | 0 | [0.12, 0.19, 0.31, 0.51, 0.83, 1.39, 2.4, 4.64, 12.35] | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab [Units/volume] in Serum |
| 897 | s-allige |  | 61% | name | 2748 | 99.71 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab [Units/volume] in Serum |
| 898 | s-amyl | u/l | 99% | name+unit+values | 10387 | 0 | [33.31, 39.8, 44.99, 49.81, 54.67, 59.75, 66.53, 75.22, 91.12] | S -Amylaasi | Serum |  | Amylase [Enzymatic activity/volume] in Serum |
| 899 | s-amyl |  | 1% | name+values | 129 | 20.16 | [35, 42.3, 49.52, 56.4, 62.75, 71, 94.2, 128.3, 161] | S -Amylaasi | Serum |  | Amylase [Enzymatic activity/volume] in Serum |
| 900 | s-amyl-is | form | 3% | name+unit | 15 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes | Amylase isoenzymes panel - Serum |
| 901 | s-amyl-is |  | 97% | name | 434 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes | Amylase isoenzymes panel - Serum |
| 902 | s-amylp | u/l | 81% | name+unit+values | 280 | 0 | [14.92, 20.3, 25.89, 30.35, 36.7, 44.3, 55.25, 69.52, 135.91] | S -Amylaasi, haimaperäinen | Serum |  | Amylase.pancreatic [Enzymatic activity/volume] in Serum |
| 903 | s-amylp |  | 19% | name | 66 | 16.67 |  | S -Amylaasi, haimaperäinen | Serum |  | Amylase.pancreatic [Enzymatic activity/volume] in Serum |
| 904 | s-amyls | u/l | 81% | name+unit+values | 256 | 0 | [12.25, 18.54, 23.94, 28.43, 34.44, 44.93, 63.37, 81.22, 120.05] | S -Amylaasi, sylkiperäinen | Serum |  | Amylase.salivary [Enzymatic activity/volume] in Serum |
| 905 | s-amyls |  | 19% | name | 61 | 18.03 |  | S -Amylaasi, sylkiperäinen | Serum |  | Amylase.salivary [Enzymatic activity/volume] in Serum |
| 906 | s-dmklots | nmol/l | 60% | name+unit+values | 15078 | 0.19 | [349.72, 488.38, 603.51, 717.55, 840.77, 973.75, 1127.96, 1320.3, 1616.71] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma |
| 907 | s-dmklots | umol/l | 36% | name+unit+values | 9051 | 0 | [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.95, 1.16, 1.45] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma |
| 908 | s-dmklots | âumol/l | 0% | name+unit | 32 | 0 |  | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma |
| 909 | s-dmklots |  | 4% | name+values | 1117 | 100 | [0.79, 1.17, 292.49, 521.2, 721.89, 874.92, 1051.9, 1273.86, 1599.85] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma |
| 910 | s-gliade | u/ml | 21% | name+unit | 23 | 60.87 |  |  | Serum |  | Gliadin deamidated Ab [Units/volume] in Serum |
| 911 | s-gliade |  | 79% | name | 84 | 98.81 |  |  | Serum |  | Gliadin deamidated Ab [Units/volume] in Serum |
| 912 | s-gliadie | u/ml | 82% | name+unit+values | 531 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.02, 0.07, 0.24] |  | Serum |  | Gliadin deamidated IgE Ab [Units/volume] in Serum |
| 913 | s-gliadie |  | 18% | name+values | 118 | 5.93 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Serum |  | Gliadin deamidated IgE Ab [Units/volume] in Serum |
| 914 | s-hladsa |  | 100% | name | 847 | 100 |  |  | Serum |  | HLA donor specific Ab [Presence] in Serum |
| 915 | s-kalatue |  | 100% | name | 132 | 100 |  |  | Serum |  |  |
| 916 | s-kolaige | u/ml | 7% | name+unit | 14 | 100 |  |  | Serum |  | Dog (Canis familiaris) dander IgE Ab [Units/volume] in Serum |
| 917 | s-kolaige |  | 93% | name | 181 | 100 |  |  | Serum |  | Dog (Canis familiaris) dander IgE Ab [Units/volume] in Serum |
| 918 | s-kudosab |  | 100% | name | 1042 | 100 |  |  | Serum |  | Tissue Ab [Presence] in Serum |
| 919 | s-ngmuut |  | 100% | name | 16771 | 100 |  |  | Serum |  |  |
| 920 | s-oaldos | pmol/l | 100% | name+unit+values | 200 | 1.5 | [636.2, 2117.22, 7632.17, 17219.7, 36953.33, 62851.67, 87233.33, 130744.44, 214222.22] |  | Serum |  | Aldosterone [Moles/volume] in Serum |
| 921 | s-olants | nmol/l | 87% | name+unit+values | 4003 | 0.07 | [53.03, 76.26, 97.99, 119.12, 141.44, 165.86, 195.39, 234.91, 291.91] | S -Olantsapiini | Serum |  | Olanzapine [Moles/volume] in Serum or Plasma |
| 922 | s-olants |  | 13% | name+values | 595 | 31.43 | [58.73, 86.04, 110.31, 132.4, 158.88, 189.03, 219.38, 262.18, 324.46] | S -Olantsapiini | Serum |  | Olanzapine [Moles/volume] in Serum or Plasma |
| 923 | s-ovalbue | u/ml | 84% | name+unit+values | 86 | 1.16 | [0, 0.02, 0.03, 0.1, 0.23, 0.56, 2, 8.02, 21.8] |  | Serum |  | Ovalbumin IgE Ab [Units/volume] in Serum |
| 924 | s-ovalbue |  | 16% | name | 16 | 81.25 |  |  | Serum |  | Ovalbumin IgE Ab [Units/volume] in Serum |
| 925 | s-salis | mmol/l | 21% | name+unit | 56 | 0 |  | S -Salisylaatit | Serum |  | Salicylate [Moles/volume] in Serum or Plasma |
| 926 | s-salis | umol/l | 33% | name+unit | 87 | 5.75 |  | S -Salisylaatit | Serum |  | Salicylate [Moles/volume] in Serum or Plasma |
| 927 | s-salis |  | 46% | name | 121 | 97.52 |  | S -Salisylaatit | Serum |  | Salicylate [Moles/volume] in Serum or Plasma |
| 928 | s-scl-t |  | 100% | name | 833 | 100 |  |  | Serum |  | Scl 70 Ab [Presence] in Serum |
| 929 | s-sfit1 | ng/l | 100% | name+unit+values | 135 | 0 | [1994, 2524.58, 3215, 3792.29, 4608.29, 5445.5, 7105.78, 9372.28, 11496.33] | S -Endoteelikasvutekijän liukoinen reseptori | Serum |  | Soluble fms-like tyrosine kinase 1 [Mass/volume] in Serum or Plasma |
| 930 | s-sflt-1 | ng/l | 100% | name+unit+values | 318 | 0 | [1291.87, 1667.24, 2344.04, 3006.81, 3762.57, 4805.39, 6029.95, 7158.88, 9214.96] |  | Serum |  | Soluble fms-like tyrosine kinase 1 [Mass/volume] in Serum or Plasma |
| 931 | s-sldl | mmol/l | 93% | name+unit+values | 2207 | 0 | [1.75, 2.1, 2.37, 2.68, 2.95, 3.22, 3.51, 3.8, 4.25] |  | Serum |  | LDL cholesterol.small dense [Moles/volume] in Serum |
| 932 | s-sldl |  | 7% | name | 177 | 98.87 |  |  | Serum |  | LDL cholesterol.small dense [Moles/volume] in Serum |
| 933 | s-suoli | u/l | 92% | name+unit+values | 115 | 0 | [0, 0, 0, 0.27, 2.83, 5.44, 7.47, 12.05, 21.01] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 934 | s-suoli |  | 8% | name | 10 | 30 |  |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 935 | s-suolist | u/l | 56% | name+unit+values | 81 | 0 | [2, 3.1, 5.23, 9, 10.88, 13, 15, 20.35, 28] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 936 | s-suolist |  | 44% | name | 63 | 96.83 |  |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum |
| 937 | s-valdos | pmol/l | 100% | name+unit+values | 157 | 0.64 | [3435.33, 10631.9, 19753.33, 29394.05, 44768.33, 65139.29, 87875, 118200, 193300] |  | Serum |  | Aldosterone [Moles/volume] in Serum |
| 938 | s-vedol | mg/l | 88% | name+unit+values | 1566 | 0 | [10.87, 14.08, 17.75, 20.76, 23.95, 27.59, 31.95, 37.11, 43.61] | S -Vedolitsumabi | Serum |  | Vedolizumab [Mass/volume] in Serum or Plasma |
| 939 | s-vedol |  | 12% | name+values | 221 | 12.22 | [5.88, 9.27, 13.22, 17.42, 21.48, 25.78, 28.81, 33.33, 39.06] | S -Vedolitsumabi | Serum |  | Vedolizumab [Mass/volume] in Serum or Plasma |
| 940 | saline |  | 100% | name+values | 946 | 3.38 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |  |
| 941 | se-amyl | u/l | 87% | name+unit+values | 1679 | 0.83 | [7.84, 14.57, 24.16, 42.2, 81.52, 202.31, 555.29, 1833.05, 9919.76] | Se-Amylaasi | Secretion |  | Amylase [Enzymatic activity/volume] in Secretion |
| 942 | se-amyl |  | 13% | name | 248 | 97.98 |  | Se-Amylaasi | Secretion |  | Amylase [Enzymatic activity/volume] in Secretion |
| 943 | sp-suld |  | 100% | name | 262 | 100 |  |  | Sperm / semen |  |  |
| 944 | u-amyl | u/l | 94% | name+unit+values | 2762 | 0.04 | [40.07, 60.75, 84.23, 110.48, 142.21, 184.16, 244.01, 332.59, 547.07] | U -Amylaasi | Urine |  | Amylase [Enzymatic activity/volume] in Urine |
| 945 | u-amyl |  | 6% | name+values | 192 | 49.48 | [46, 98.65, 135.92, 161.9, 205.44, 269.5, 358.67, 597.35, 1056] | U -Amylaasi | Urine |  | Amylase [Enzymatic activity/volume] in Urine |
| 946 | u-amylp | u/l | 88% | name+unit+values | 106 | 0 | [29, 44.7, 68.1, 90.36, 112.17, 155.8, 214.47, 337.6, 546] | U -Amylaasi, haimaperäinen | Urine |  | Amylase.pancreatic [Enzymatic activity/volume] in Urine |
| 947 | u-amylp |  | 12% | name | 15 | 20 |  | U -Amylaasi, haimaperäinen | Urine |  | Amylase.pancreatic [Enzymatic activity/volume] in Urine |

