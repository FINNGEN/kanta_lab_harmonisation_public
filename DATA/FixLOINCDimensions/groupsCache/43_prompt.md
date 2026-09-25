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
Here is group 43.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3004248 | Sex hormone binding globulin [Moles/volume] in Serum or Plasma | 1.000 | 681 |
| 3005715 | Vancomycin [Mass/volume] in Serum or Plasma | 1.000 | 2009 |
| 3009306 | Alpha-1-Fetoprotein [Mass/volume] in Serum or Plasma | 1.000 | 386 |
| 3015916 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma | 1.000 |  |
| 3018171 | Choriogonadotropin [Units/volume] in Serum or Plasma | 1.000 | 252 |
| 3018308 | Bromide [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3018954 | Choriogonadotropin [Presence] in Urine | 1.000 | 184 |
| 3019539 | Treponema pallidum Ab [Titer] in Serum by Hemagglutination | 1.000 |  |
| 3023511 | Choriogonadotropin [Units/volume] in Urine | 1.000 |  |
| 3028050 | Streptolysin O Ab [Titer] in Serum | 1.000 | 1851 |
| 3029075 | Extractable nuclear Ab panel - Serum | 1.000 |  |
| 3031591 | Treponema pallidum Ab [Titer] in Cerebral spinal fluid by Hemagglutination | 1.000 |  |
| 3034780 | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 730 |
| 3035510 | Gentamicin [Mass/volume] in Serum or Plasma | 1.000 | 1092 |
| 3035947 | Staphylolysin Ab [Units/volume] in Serum | 1.000 |  |
| 3036152 | Amikacin [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3052649 | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma | 1.000 |  |
| 3024172 | Erythropoietin (EPO) [Units/volume] in Serum or Plasma | 0.980 | 838 |
| 3021236 | Streptolysin O Ab [Units/volume] in Serum or Plasma | 0.978 | 744 |
| 3018876 | Apolipoprotein A [Mass/volume] in Serum or Plasma | 0.974 |  |
| 3014339 | Estrone (E1) [Moles/volume] in Serum or Plasma | 0.971 | 1123 |
| 3001686 | Cold agglutinin [Titer] in Serum or Plasma | 0.968 |  |
| 3027880 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Serum or Plasma | 0.960 | 833 |
| 3009461 | 5-Hydroxyindoleacetate [Moles/time] in 24 hour Urine | 0.959 | 1449 |
| 3026725 | Estradiol (E2) [Moles/volume] in Serum or Plasma | 0.959 | 231 |
| 3016616 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in Serum or Plasma | 0.956 | 468 |
| 42529189 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma by Immunoassay | 0.953 |  |
| 3016103 | Fatty acids [Moles/volume] in Serum or Plasma | 0.950 |  |
| 3026383 | Bromide [Mass/volume] in Serum or Plasma | 0.950 |  |
| 3010801 | 5-Hydroxyindoleacetate [Moles/volume] in 24 hour Urine | 0.949 |  |
| 3030136 | 5-Hydroxyindoleacetate [Moles/volume] in Serum or Plasma | 0.949 |  |
| 42529203 | Choriogonadotropin [Units/volume] in Serum or Plasma by Immunoassay | 0.949 |  |
| 3029998 | Treponema pallidum Ab [Presence] in Cerebral spinal fluid by Hemagglutination | 0.947 |  |
| 42868681 | Estrogen [Moles/volume] in Serum or Plasma | 0.947 | 920 |
| 3029371 | Treponema pallidum Ab [Titer] in Cerebral spinal fluid | 0.944 |  |
| 3032397 | Treponema pallidum Ab [Units/volume] in Cerebral spinal fluid by Hemagglutination | 0.941 |  |
| 3038911 | Alpha-1-fetoprotein.tumor marker [Units/volume] in Serum or Plasma | 0.939 |  |
| 3028061 | Treponema pallidum Ab [Presence] in Serum by Hemagglutination | 0.938 |  |
| 42869548 | Treponema pallidum Ab [Titer] in Serum or Plasma by Agglutination | 0.938 |  |
| 3007061 | Streptolysin O Ab [Units/volume] in Serum by Latex agglutination | 0.938 |  |
| 3007932 | Treponema pallidum Ab [Titer] in Serum by Latex agglutination | 0.937 |  |
| 3031166 | Choriogonadotropin [Mass/volume] in Serum or Plasma | 0.937 |  |
| 3036988 | Choriogonadotropin.intact [Units/volume] in Serum or Plasma | 0.936 | 834 |
| 3010935 | Vancomycin [Moles/volume] in Serum or Plasma | 0.936 | 2009 |
| 42529190 | Alpha-1-Fetoprotein [Mass/volume] in Serum or Plasma by Immunoassay | 0.936 |  |
| 3026531 | Cold agglutinin [Titer] in Serum or Plasma by Agglutination | 0.936 |  |
| 3011229 | Endomysium Ab [Titer] in Serum | 0.934 | 1279 |
| 3027505 | Alpha-1-Fetoprotein [Units/volume] in Amniotic fluid | 0.932 | 1501 |
| 1989578 | Choriogonadotropin [Mass/volume] in Urine | 0.931 |  |
| 3015128 | Streptolysin O Ab [Units/volume] in Body fluid | 0.931 |  |
| 3003969 | Apolipoprotein C [Mass/volume] in Serum or Plasma | 0.930 |  |
| 3021607 | Alpha-1-Fetoprotein [Moles/volume] in Serum or Plasma | 0.929 |  |
| 3036065 | Streptolysin O Ab [Titer] in Serum by Latex agglutination | 0.929 |  |
| 3009960 | Adenosine deaminase [Enzymatic activity/volume] in Blood | 0.928 |  |
| 1175777 | Alpha-1-Fetoprotein Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.927 |  |
| 3009471 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma | 0.926 |  |
| 3039783 | Alpha-1-fetoprotein.tumor marker [Mass/volume] in Serum or Plasma | 0.925 | 746 |
| 3008364 | Apolipoprotein A-I [Mass/volume] in Serum or Plasma | 0.924 | 1261 |
| 3014791 | Apolipoprotein B [Mass/volume] in Serum or Plasma | 0.924 | 889 |
| 3046268 | Streptolysin O Ab [Mass/volume] in Serum | 0.924 |  |
| 3022237 | Choriogonadotropin [Moles/volume] in Urine | 0.923 |  |
| 3007675 | Apolipoprotein E [Mass/volume] in Serum or Plasma | 0.923 |  |
| 3037123 | Amikacin [Mass/volume] in Serum or Plasma --trough | 0.923 |  |
| 3018920 | Vancomycin [Mass/volume] in Serum or Plasma --trough | 0.923 | 382 |
| 3053140 | Gentamicin [Moles/volume] in Serum or Plasma | 0.923 | 1092 |
| 3010055 | Treponema pallidum Ab [Titer] in Serum | 0.923 |  |
| 3020961 | Endomysium IgA Ab [Titer] in Serum | 0.922 | 1349 |
| 3045958 | Alpha-1-Fetoprotein [Units/volume] in Body fluid | 0.921 |  |
| 3002091 | Choriogonadotropin [Moles/volume] in Serum or Plasma | 0.921 |  |
| 3048833 | Staphylolysin Ab [Units/volume] in Body fluid | 0.921 |  |
| 3016254 | Gentamicin [Mass/volume] in Serum or Plasma --trough | 0.920 | 871 |
| 3032773 | Endomysium IgG Ab [Titer] in Serum | 0.920 |  |
| 40759747 | Amikacin [Moles/volume] in Serum or Plasma | 0.920 |  |
| 3011099 | Sex hormone binding globulin [Mass/volume] in Serum or Plasma | 0.918 |  |
| 3005148 | 5-Hydroxyindoleacetate [Mass/time] in 24 hour Urine | 0.917 |  |
| 3034165 | Alpha-1-Fetoprotein [Mass/volume] in Body fluid | 0.917 |  |
| 3023640 | Estrone (E1) [Mass/volume] in Serum or Plasma | 0.917 |  |
| 648067 | Alpha-1-Fetoprotein [Measurement] in Serum or Plasma | 0.916 |  |
| 3036335 | Angiotensin converting enzyme [Enzymatic activity/volume] in Blood | 0.916 | 1299 |
| 3005886 | Vancomycin Free [Mass/volume] in Serum or Plasma | 0.913 |  |
| 3010296 | Alpha-1-Fetoprotein [Mass/volume] in Amniotic fluid | 0.912 |  |
| 1616967 | Treponema pallidum IgG Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.910 |  |
| 40759904 | Baker's yeast Ab [Units/volume] in Serum | 0.908 |  |
| 646451 | Extractable nuclear Ab [Measurement] in Serum | 0.907 |  |
| 21492990 | Choriogonadotropin [Presence] in Urine by Rapid immunoassay | 0.907 |  |
| 647790 | Streptolysin O Ab [Measurement] in Serum | 0.906 |  |
| 3045488 | Treponema pallidum Ab [Titer] in Serum by Immunofluorescence | 0.906 |  |
| 3021106 | 5-Hydroxyindoleacetate [Mass/volume] in Serum or Plasma | 0.904 |  |
| 3011461 | Vancomycin [Mass/volume] in Serum or Plasma --peak | 0.904 | 937 |
| 1617524 | Alpha-1-Fetoprotein [Units/volume] in Aspirate | 0.904 |  |
| 3011089 | Cold agglutinin [Titer] in Serum or Plasma by Cord RBC agglutination | 0.903 |  |
| 3036184 | Bromide [Moles/volume] in Blood | 0.903 |  |
| 3009917 | Gentamicin [Mass/volume] in Serum or Plasma --peak | 0.903 | 965 |
| 42529191 | Alpha-1-Fetoprotein [Units/volume] in Amniotic fluid by Immunoassay | 0.903 |  |
| 3015171 | Extractable nuclear Ab [Units/volume] in Serum | 0.901 |  |
| 3023028 | 5-Hydroxyindoleacetate [Mass/volume] in 24 hour Urine | 0.901 |  |
| 1616334 | Vancomycin [Mass/volume] in Serum or Plasma --2 hours post dose | 0.901 |  |
| 21494226 | Gentamicin free [Mass/volume] in Serum or Plasma | 0.901 |  |
| 3005831 | Streptolysin O Ab [Units/volume] in Synovial fluid | 0.900 |  |
| 648716 | Choriogonadotropin [Measurement] in Serum or Plasma | 0.900 |  |
| 3010554 | Cold agglutinin [Titer] in Serum or Plasma by Adult RBC Agglutination | 0.900 |  |
| 3002225 | Fatty acids [Mass/volume] in Serum or Plasma | 0.900 |  |
| 3008977 | Amikacin [Mass/volume] in Serum or Plasma --peak | 0.899 |  |
| 3009417 | Choriogonadotropin.beta subunit [Presence] in Urine | 0.898 | 1227 |
| 21494227 | Amikacin free [Mass/volume] in Serum or Plasma | 0.898 |  |
| 1617505 | Treponema pallidum IgM Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.898 |  |
| 3018337 | Streptolysin O Ab [Presence] in Serum | 0.897 |  |
| 3034387 | Apolipoprotein B-100 [Mass/volume] in Serum or Plasma | 0.897 | 772 |
| 3038136 | Choriogonadotropin.beta subunit [Units/volume] in Serum or Plasma | 0.897 | 364 |
| 3037522 | Nuclear Ab [Titer] in Serum | 0.896 | 890 |
| 3013293 | Extractable nuclear Ab [Presence] in Serum | 0.896 |  |
| 3019583 | Endomysium IgA Ab [Titer] in Serum by Immunofluorescence | 0.895 | 976 |
| 648034 | Choriogonadotropin [Measurement] in Urine | 0.895 |  |
| 21492226 | Cold agglutinin [Titer] in Serum by 4 deg C incubation --1 hour post incubation | 0.895 |  |
| 3036309 | 5-Hydroxyindoleacetate [Moles/volume] in Urine | 0.892 |  |
| 3004786 | Treponema pallidum Ab [Presence] in Serum by Agglutination | 0.891 | 1818 |
| 3033561 | Apolipoprotein A-II [Mass/volume] in Serum or Plasma | 0.891 |  |
| 40757479 | Alpha-1-Fetoprotein [Mass/volume] in Cord blood | 0.890 |  |
| 646220 | Cold agglutinin [Measurement] in Serum | 0.890 |  |
| 3038624 | Choriogonadotropin.tumor marker [Units/volume] in Serum or Plasma | 0.889 |  |
| 3018796 | Apolipoprotein A-III [Mass/volume] in Serum or Plasma | 0.889 |  |
| 3039041 | Endomysium IgG Ab [Titer] in Serum by Immunofluorescence | 0.888 |  |
| 3017915 | Endomysium Ab [Titer] in Serum by Immunofluorescence | 0.888 |  |
| 3051055 | Staphylolysin Ab [Titer] in Serum | 0.887 |  |
| 3027536 | Estrone sulfate [Mass/volume] in Serum or Plasma | 0.887 |  |
| 3046071 | Choriogonadotropin.intact+Beta subunit [Units/volume] in Serum or Plasma | 0.887 |  |
| 3017785 | Apolipoprotein LPA [Mass/volume] in Serum or Plasma | 0.887 |  |
| 42529214 | Estradiol (E2) [Moles/volume] in Serum or Plasma by Immunoassay | 0.887 |  |
| 21492225 | Cold agglutinin [Titer] in Serum by 22 degree C incubation --1 hour post incubation | 0.887 |  |
| 645783 | Treponema pallidum Ab [Measurement] in Cerebral spinal fluid | 0.886 |  |
| 3023122 | Fatty acids.very long chain [Moles/volume] in Serum or Plasma | 0.886 | 1826 |
| 3037641 | Choriogonadotropin [Units/volume] in Body fluid | 0.885 |  |
| 40766122 | Extractable nuclear Ab [Presence] in Serum by Immunoassay | 0.885 |  |
| 40759269 | Smith extractable nuclear Ab and Ribonucleoprotein extractable nuclear Ab panel - Serum | 0.885 |  |
| 3003099 | Streptolysin O Ab [Units/volume] in Serum --1st specimen | 0.884 |  |
| 3037437 | Adenosine deaminase [Enzymatic activity/volume] in Body fluid | 0.883 |  |
| 3016568 | Apolipoprotein C-I [Mass/volume] in Serum or Plasma | 0.883 |  |
| 1176189 | Extractable nuclear antigen Ab.IgG panel - Serum | 0.883 |  |
| 1617619 | Treponema pallidum Ab [Presence] in Cerebral spinal fluid by Immunoassay | 0.882 |  |
| 3010487 | Treponema pallidum Ab [Units/volume] in Serum by Latex agglutination | 0.882 |  |
| 3025285 | Estradiol (E2) [Mass/volume] in Serum or Plasma | 0.881 |  |
| 3022000 | Dehydroepiandrosterone (DHEA) [Mass/volume] in Serum or Plasma | 0.881 |  |
| 40758605 | Estradiol (E2) [Moles/volume] in Serum or Plasma --baseline | 0.880 |  |
| 21492227 | Cold agglutinin [Titer] in Serum by 4 deg C incubation --24 hour post incubation | 0.880 |  |
| 3015884 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma | 0.880 |  |
| 3002924 | Fatty acids.nonesterified [Mass/volume] in Serum or Plasma | 0.879 |  |
| 21492224 | Cold agglutinin [Titer] in Serum by 37 degree C incubation --1 hour post incubation | 0.879 |  |
| 3043496 | Extractable nuclear Ab [Interpretation] in Serum | 0.879 |  |
| 3005574 | Amikacin [Mass/volume] in Serum or Plasma --trough post extended interval dosing | 0.879 |  |
| 40758603 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Serum or Plasma --baseline | 0.879 |  |
| 3012631 | Estriol (E3) [Moles/volume] in Serum or Plasma | 0.878 | 1565 |
| 3008080 | Adenosine monophosphate deaminase [Enzymatic activity/volume] in Serum | 0.877 |  |
| 3019258 | Amikacin [Mass/volume] in Body fluid | 0.877 |  |
| 43534046 | Estradiol (E2) [Moles/volume] in Serum or Plasma by High sensitivity method | 0.876 |  |
| 3052820 | Kanamycin [Mass/volume] in Serum or Plasma | 0.874 |  |
| 3052507 | Netilmicin [Mass/volume] in Serum or Plasma | 0.874 |  |
| 3033818 | Extractable nuclear Ab [Units/volume] in Serum by Immunoassay | 0.873 |  |
| 3015881 | Streptolysin O Ab [Units/volume] in Serum --2nd specimen | 0.873 |  |
| 40762469 | Amikacin [Mass/volume] in Serum or Plasma --post dialysis | 0.873 |  |
| 3019603 | Treponema pallidum Ab [Presence] in Cerebral spinal fluid | 0.872 |  |
| 3039257 | Vancomycin [Moles/volume] in Serum or Plasma --trough | 0.871 | 382 |
| 3035509 | Tobramycin [Mass/volume] in Serum or Plasma | 0.870 | 1858 |
| 3005135 | Extractable nuclear Ab [Identifier] in Serum | 0.869 |  |
| 3026429 | Gentamicin [Mass/volume] in Serum or Plasma --trough post extended interval dosing | 0.869 |  |
| 3008692 | Estrone (E1) [Moles/volume] in Urine | 0.868 |  |
| 3032897 | Saturated fatty acids [Moles/volume] in Serum or Plasma | 0.868 |  |
| 40771477 | Baker's yeast Ab [Units/volume] in Serum by Immunoassay | 0.867 |  |
| 40762472 | Vancomycin [Mass/volume] in Serum or Plasma --post dialysis | 0.867 |  |
| 3002412 | Gentamicin [Moles/volume] in Serum or Plasma --trough | 0.866 | 871 |
| 3039445 | 5-Hydroxytryptophan [Moles/volume] in 24 hour Urine | 0.866 |  |
| 648828 | Cold agglutinin [Measurement] in Serum or Plasma | 0.866 |  |
| 3051403 | 5-Hydroxyindoleacetate [Moles/volume] in Cerebral spinal fluid | 0.865 |  |
| 3009623 | Estrone (E1).unconjugated [Mass/volume] in Serum or Plasma | 0.864 |  |
| 3015760 | Choriogonadotropin [Presence] in Body fluid | 0.864 |  |
| 3003191 | Choriogonadotropin [Presence] in Serum or Plasma | 0.863 | 615 |
| 647414 | Erythropoietin (EPO) [Measurement] in Serum or Plasma | 0.863 |  |
| 3029054 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --5th specimen fasting | 0.862 |  |
| 3019257 | Choriogonadotropin.beta subunit [Moles/volume] in Urine | 0.862 |  |
| 645324 | Treponema pallidum Ab [Measurement] in Serum | 0.862 |  |
| 3016906 | Vancomycin [Mass/volume] in Body fluid | 0.862 |  |
| 40760543 | Extractable nuclear Ab [Presence] in Serum by Immunoblot | 0.861 |  |
| 3041244 | Adenosine deaminase [Enzymatic activity/volume] in Synovial fluid | 0.861 |  |
| 3027646 | Estrogen [Mass/volume] in Serum or Plasma | 0.860 |  |
| 3032218 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --3rd specimen fasting | 0.859 |  |
| 40759782 | 5-Hydroxytryptophan [Moles/time] in 24 hour Urine | 0.858 |  |
| 3038531 | Vancomycin [Moles/volume] in Serum or Plasma --peak | 0.858 | 937 |
| 40768055 | Sex hormone binding globulin [Moles/volume] in Serum or Plasma --pre or post XXX challenge | 0.857 |  |
| 40761580 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --6th specimen fasting | 0.857 |  |
| 40765159 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --10th specimen fasting | 0.856 |  |
| 3036168 | 5-Hydroxyindoleacetate [Presence] in 24 hour Urine | 0.856 |  |
| 3045640 | Choriogonadotropin [Units/volume] in Amniotic fluid | 0.856 |  |
| 3002971 | Nuclear Ab [Titer] in Serum by Immunofluorescence | 0.856 | 345 |
| 3037371 | Bromide [Moles/volume] in Urine | 0.855 |  |
| 3040662 | Nuclear Ab [Titer] in Serum by Immunoassay | 0.853 |  |
| 3008092 | Baker's yeast IgG Ab [Units/volume] in Serum | 0.852 |  |
| 3003581 | Estrone (E1).bioavailable [Mass/volume] in Serum or Plasma | 0.852 |  |
| 3031814 | Bromide [Mass/volume] in Blood | 0.851 |  |
| 3036428 | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid | 0.851 |  |
| 3028955 | 5-Hydroxytryptophan [Moles/volume] in Serum or Plasma | 0.849 |  |
| 3021385 | 5-Hydroxyindoleacetate [Mass/volume] in Urine | 0.848 |  |
| 645582 | Endomysium IgM Ab [Units/volume] in Serum | 0.847 |  |
| 3038038 | Choriogonadotropin [Units/volume] in Semen | 0.846 |  |
| 3045218 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Urine | 0.844 |  |
| 3008834 | Endomysium IgA Ab [Units/volume] in Serum | 0.844 |  |
| 3044334 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in Urine | 0.843 |  |
| 3034552 | Adenosine deaminase [Enzymatic activity/volume] in Cerebral spinal fluid | 0.843 |  |
| 3017071 | Smith extractable nuclear Ab [Titer] in Serum | 0.843 |  |
| 649388 | Endomysium Ab [Measurement] in Serum | 0.842 |  |
| 44816667 | 5-Hydroxyindoleacetate [Moles/volume] in Platelet rich plasma | 0.841 |  |
| 646173 | Estrone (E1) [Measurement] in Serum or Plasma | 0.840 |  |
| 645401 | Endomysium IgG Ab [Measurement] in Serum | 0.839 |  |
| 647620 | Estrogen [Measurement] in Serum or Plasma | 0.838 |  |
| 3021133 | Inter alpha trypsin inhibitor [Mass/volume] in Serum | 0.838 |  |
| 646971 | Smith extractable nuclear Ab [Measurement] in Serum | 0.837 |  |
| 40758972 | Androstenediol [Moles/volume] in Serum or Plasma | 0.836 |  |
| 3014670 | 5-Hydroxyindoleacetate [Mass/volume] in Cerebral spinal fluid | 0.836 |  |
| 3023428 | Smith extractable nuclear Ab [Presence] in Serum | 0.836 |  |
| 44816943 | Adenosine deaminase [Enzymatic activity/volume] in DBS | 0.835 |  |
| 3047826 | Mullerian inhibiting substance [Mass/volume] in Serum or Plasma | 0.835 | 1599 |
| 3037275 | Staphylococcus aureus Ab [Units/volume] in Serum | 0.834 |  |
| 648952 | Baker's yeast Ab [Measurement] in Serum | 0.833 |  |
| 3051057 | 5-Hydroxyindoleacetate/Creatinine [Molar ratio] in 24 hour Urine | 0.833 |  |
| 3022795 | Bromazepam [Moles/volume] in Serum or Plasma | 0.833 |  |
| 3001740 | Acetylcholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.833 |  |
| 3029213 | Adenosine deaminase [Enzymatic activity/volume] in Pericardial fluid | 0.833 |  |
| 3033252 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal fluid | 0.832 |  |
| 40759753 | Nuclear IgG Ab [Titer] in Serum by Immunofluorescence | 0.832 |  |
| 3010312 | Streptococcus sp Ab [Titer] in Serum | 0.832 |  |
| 3052277 | 11-Hydroxyandrostenedione [Moles/volume] in Serum or Plasma | 0.829 |  |
| 3040491 | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | 0.829 |  |
| 3036566 | Thyroxine binding globulin [Moles/volume] in Serum or Plasma | 0.828 |  |
| 3009695 | 17-Hydroxypregnenolone [Moles/volume] in Serum or Plasma | 0.828 |  |
| 3010774 | Pregnenolone [Moles/volume] in Serum or Plasma | 0.828 | 1374 |
| 646438 | 5-Hydroxyindoleacetate [Measurement] in Urine | 0.827 |  |
| 3044096 | 5-Hydroxyindoleacetate panel - 24 hour Urine | 0.826 |  |
| 3049738 | Baker's yeast IgG Ab [Units/volume] in Serum by Immunoassay | 0.825 |  |
| 3018358 | Nuclear Ab [Titer] in Body fluid | 0.824 |  |
| 3004593 | Baker's yeast IgA Ab [Units/volume] in Serum | 0.823 | 1368 |
| 3009400 | Neuronal nuclear Ab [Titer] in Serum | 0.822 |  |
| 40759126 | Platelet aggregation in Blood by ADP induced 5 umol/L | 0.820 |  |
| 3024445 | Bromide [Mass/volume] in Specimen | 0.820 |  |
| 3003927 | Nuclear Ab [Titer] in Synovial fluid | 0.819 |  |
| 40758655 | Brompheniramine [Moles/volume] in Serum or Plasma | 0.818 |  |
| 3010866 | Cholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.817 |  |
| 40758310 | Human epididymis protein 4 [Moles/volume] in Serum or Plasma | 0.817 |  |
| 3039998 | Platelet aggregation [Units/volume] in Blood by arachidonate induced | 0.816 |  |
| 3042234 | Platelet aggregation [Units/volume] in Blood by ADP induced | 0.816 |  |
| 3049189 | Streptococcus sp exoenzyme Ab [Units/volume] in Serum | 0.815 |  |
| 40759128 | Platelet aggregation in Blood by arachidonate induced 500 ug/mL | 0.815 |  |
| 3030077 | Nuclear Ab [Titer] in Serum by Hep2 substrate | 0.815 |  |
| 3037035 | Baker's yeast IgG Ab [Mass/volume] in Serum | 0.814 | 1311 |
| 40759672 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma --baseline | 0.814 |  |
| 3011407 | Baker's yeast IgE Ab [Units/volume] in Serum | 0.812 | 1945 |
| 3025563 | Saccharopolyspora rectivirgula Ab [Units/volume] in Serum | 0.812 |  |
| 3021195 | Candida albicans Ab [Units/volume] in Serum | 0.811 |  |
| 648351 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.811 |  |
| 3044342 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in 24 hour Urine | 0.810 |  |
| 3009991 | Angiotensin converting enzyme [Enzymatic activity/volume] in Cerebral spinal fluid | 0.810 |  |
| 3051263 | Dihydroxycholestanoate [Moles/volume] in Serum or Plasma | 0.810 |  |
| 3039179 | Angiotensin converting enzyme [Enzymatic activity/volume] in Peritoneal fluid | 0.809 |  |
| 3012673 | Bromide [Mass/volume] in Urine | 0.808 |  |
| 3019041 | Neuronal nuclear type 1 Ab [Titer] in Serum | 0.807 |  |
| 3026712 | Neutrophil cytoplasmic Ab [Titer] in Serum | 0.807 | 1456 |
| 3018595 | Inhibin A [Mass/volume] in Serum or Plasma | 0.806 | 702 |
| 40759127 | Platelet aggregation in Blood by ADP induced 10 umol/L | 0.806 |  |
| 3039356 | Boron [Moles/volume] in Serum or Plasma | 0.805 |  |
| 42529221 | Mullerian inhibiting substance [Mass/volume] in Serum or Plasma by Immunoassay | 0.801 |  |
| 3008019 | Hyaluronidase Ab [Units/volume] in Serum | 0.799 |  |
| 3007808 | Renin [Enzymatic activity/volume] in Plasma | 0.798 | 822 |
| 40759134 | Platelet aggregation in Blood by arachidonate induced ATP secretion 500 umol/L | 0.798 |  |
| 3017446 | Testosterone [Moles/volume] in Serum or Plasma | 0.797 | 203 |
| 3035485 | Oxytocin [Units/volume] in Serum or Plasma | 0.797 |  |
| 3049799 | Mullerian inhibiting substance [Moles/volume] in Serum or Plasma | 0.796 |  |
| 3030073 | Trypsin [Mass/volume] in Serum or Plasma | 0.791 |  |
| 3013495 | Streptokinase Ab [Units/volume] in Serum | 0.788 |  |
| 3000481 | Estrogen+Progesterone receptor Ag [Presence] in Tissue by Immune stain | 0.787 |  |
| 3012620 | Inhibin [Mass/volume] in Serum or Plasma | 0.786 |  |
| 1092039 | Platelet aggregation in Plasma by arachidonate induced 1 umol/L | 0.784 |  |
| 3045781 | Inhibin B [Mass/volume] in Serum or Plasma | 0.782 |  |
| 3031441 | Tripeptide aminopeptidase [Enzymatic activity/volume] in Serum or Plasma | 0.781 |  |
| 21491244 | Platelet aggregation [Units/volume] in Blood by adenosine diphosphate+prostaglandin E1 induced | 0.781 |  |
| 3036969 | Erythropoietin (EPO) given [Units/volume] of Dose | 0.779 |  |
| 3010356 | Uroporphyrin [Moles/volume] in Serum or Plasma | 0.779 |  |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.778 | 16 |
| 3025283 | Somatotropin binding protein [Moles/volume] in Serum or Plasma | 0.778 |  |
| 645118 | Mullerian inhibiting substance [Measurement] in Serum or Plasma | 0.776 |  |
| 40759123 | Platelet aggregation in Blood by ADP induced ATP secretion 5 umol/L | 0.775 |  |
| 3021387 | Prolactin [Units/volume] in Serum or Plasma | 0.773 |  |
| 40759132 | Platelet aggregation in Blood by ADP induced ATP secretion 10 umol/L | 0.772 |  |
| 3020924 | Thyroxine binding globulin [Mass/volume] in Serum or Plasma | 0.771 |  |
| 42529222 | Mullerian inhibiting substance [Moles/volume] in Serum or Plasma by Immunoassay | 0.771 |  |
| 3035828 | Inhibin A [Multiple of the median] in Serum or Plasma | 0.770 |  |
| 1259621 | Platelet aggregation in Blood by ADP induced ATP secretion 2 umol/L | 0.770 |  |
| 3021925 | Trypsin+Trypsinogen [Mass/volume] in Serum or Plasma | 0.769 |  |
| 44786755 | Endothelin [Moles/volume] in Serum or Plasma | 0.769 |  |
| 36031680 | Human epididymis protein 4 [Mass/volume] in Serum or Plasma | 0.768 |  |
| 3003084 | Osteocalcin [Moles/volume] in Serum or Plasma | 0.767 |  |
| 3025484 | Inhibin [Units/volume] in Serum or Plasma | 0.766 |  |
| 3052662 | Ceruloplasmin [Moles/volume] in Serum or Plasma | 0.766 |  |
| 3016244 | Insulin [Units/volume] in Serum or Plasma | 0.765 |  |
| 3023763 | Trypsinogen [Mass/volume] in Serum or Plasma | 0.764 |  |
| 3009947 | Choriogonadotropin.beta subunit [Units/volume] in Amniotic fluid | 0.764 |  |
| 3022948 | Iron [Moles/volume] in Serum or Plasma | 0.764 | 140 |
| 3005346 | Estradiol (E2) [Mass/volume] in Amniotic fluid | 0.763 |  |
| 44786758 | Tissue inhibitor of metalloproteinases 1 [Mass/volume] in Serum or Plasma by Immunoassay | 0.760 |  |
| 36660109 | Platelet aggregation in Platelet rich plasma by ADP induced 1.2 umol/L | 0.758 |  |
| 40759133 | Platelet aggregation interpretation in Blood Qualitative by Arachidonate induced ATP secretion.500 umol/L | 0.756 |  |
| 3009201 | Thyrotropin [Units/volume] in Serum or Plasma | 0.755 | 105 |
| 21491008 | Platelet aggregation in Platelet rich plasma by arachidonate induced 1.6 mmol/L | 0.755 |  |
| 3010173 | Endothelin [Units/volume] in Serum or Plasma | 0.755 |  |
| 3038629 | Platelet aggregation in Platelet rich plasma by arachidonate induced 500 ug/mL | 0.752 |  |
| 3003289 | Progesterone receptor [Interpretation] in Tissue | 0.750 |  |
| 3044689 | Choriogonadotropin.intact [Units/volume] in Amniotic fluid | 0.750 |  |
| 3009150 | Pregnanediol [Mass/volume] in Amniotic fluid | 0.747 |  |
| 3018301 | Testosterone Free [Moles/volume] in Serum or Plasma | 0.747 | 325 |
| 3013770 | Testosterone [Mass/volume] adjusted for sex hormone binding globulin in Serum or Plasma | 0.745 |  |
| 3000275 | Trypsinogen I Free [Mass/volume] in Serum or Plasma | 0.742 |  |
| 3004390 | Estrogen receptor [Interpretation] in Tissue | 0.738 |  |
| 3024028 | Trypsin [Enzymatic activity/volume] in Serum or Plasma | 0.738 |  |
| 3043105 | HER2 Ag [Mass/volume] in Serum | 0.737 |  |
| 3042084 | Tryptase [Moles/volume] in Serum or Plasma | 0.736 |  |
| 3019420 | Tryptase [Mass/volume] in Serum or Plasma | 0.734 | 1562 |
| 3042818 | Melanoma inhibitory activity protein [Mass/volume] in Serum or Plasma | 0.733 |  |
| 3027056 | Estriol (E3) [Mass/volume] in Amniotic fluid | 0.731 |  |
| 3033670 | Parathyrin related protein [Moles/volume] in Serum or Plasma | 0.729 |  |
| 3041343 | Estrogen receptor Ag [Presence] in Tissue by Immune stain | 0.729 |  |
| 3023986 | Choriomammotropin [Mass/volume] in Amniotic fluid | 0.728 |  |
| 3045759 | Histamine [Moles/volume] in Serum or Plasma | 0.727 |  |
| 21491058 | 4-Hydroxyvalerate [Moles/volume] in Serum or Plasma | 0.726 |  |
| 3027652 | Tissue polypeptide Ag [Mass/volume] in Serum or Plasma | 0.718 |  |
| 3030860 | Tumor necrosis factor.alpha [Moles/volume] in Serum or Plasma | 0.714 |  |
| 42870325 | Hepcidin 25 amino acid peptide [Moles/volume] in Serum or Plasma | 0.712 |  |
| 46234766 | Alpha 1 antitrypsin [Moles/volume] in Serum or Plasma | 0.711 |  |
| 3016724 | Homocysteine [Moles/volume] in Serum or Plasma | 0.708 | 358 |
| 3002815 | Trypsinogen [Enzymatic activity/volume] in Serum or Plasma | 0.707 |  |
| 3041608 | Progesterone receptor Ag [Presence] in Tissue by Immune stain | 0.699 |  |
| 3016794 | Cells.estrogen receptor/100 cells in Tissue by Immune stain | 0.693 |  |
| 3022156 | Cells.progesterone receptor/100 cells in Tissue by Immune stain | 0.691 |  |
| 3966100 | ESR1 gene mutation panel - Tissue by Molecular genetics method | 0.691 |  |
| 43533700 | Adenosine triphosphate/Adenosine diphosphate [Entitic molar ratio] in Platelets | 0.621 |  |
| 3050758 | Platelet aggregation [Units/volume] in Platelet rich plasma by arachidonate induced | 0.593 |  |
| 3048603 | Platelet aggregation [Units/volume] in Platelet rich plasma by ADP induced | 0.591 |  |
| 3036193 | Monoamine oxidase [Enzymatic activity/volume] in Platelet rich plasma | 0.589 |  |
| 3043913 | Platelet aggregation [Units/volume] in Platelet rich plasma by EPINEPHrine induced 100 umol/L | 0.588 |  |
| 3040933 | Platelet aggregation [Units/volume] in Platelet rich plasma by EPINEPHrine induced 50 umol/L | 0.583 |  |
| 3032078 | Adenosine triphosphate/Adenosine diphosphate [Mass Ratio] in Blood | 0.579 |  |
| 3010564 | Serotonin [Mass/volume] in Platelets | 0.578 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 482 | -ana | titre | 11% | name+unit | 21 | 14.29 |  | -Tuma, vasta-aineet |  |  | Nuclear antibody [Titer] in Serum |
| 483 | -ana |  | 89% | name | 169 | 100 |  | -Tuma, vasta-aineet |  |  | Nuclear antibody [Titer] in Serum |
| 484 | am-epo | iu/l | 20% | name+unit | 76 | 0 |  | Am-Erytropoietiini | Amniotic fluid |  | Erythropoietin [Units/volume] in Amniotic fluid |
| 485 | am-epo | u/l | 71% | name+unit+values | 267 | 0.75 | [2.67, 3.48, 4.24, 4.97, 5.92, 7.13, 8.38, 10.84, 21.7] | Am-Erytropoietiini | Amniotic fluid |  | Erythropoietin [Units/volume] in Amniotic fluid |
| 486 | am-epo |  | 8% | name | 31 | 45.16 |  | Am-Erytropoietiini | Amniotic fluid |  | Erythropoietin [Units/volume] in Amniotic fluid |
| 487 | b-adp | auc | 8% | name+unit | 28 | 0 |  |  | Blood |  | Platelet aggregation ADP induced [Area under curve] in Blood |
| 488 | b-adp |  | 92% | name | 340 | 100 |  |  | Blood |  | Platelet aggregation ADP induced [Area under curve] in Blood |
| 489 | b-aspi | auc | 8% | name+unit | 28 | 0 |  |  | Blood |  | Platelet aggregation arachidonic acid induced [Area under curve] in Blood |
| 490 | b-aspi |  | 92% | name | 340 | 100 |  |  | Blood |  | Platelet aggregation arachidonic acid induced [Area under curve] in Blood |
| 491 | b-vasp | % | 71% | name+unit+values | 165 | 0 | [15.56, 23.85, 29.41, 35.04, 41.24, 50.14, 56.77, 61.91, 75.84] |  | Blood |  | Vasodilator stimulated phosphoprotein phosphorylation [Ratio] in Platelets |
| 492 | b-vasp |  | 29% | name | 67 | 61.19 |  |  | Blood |  | Vasodilator stimulated phosphoprotein phosphorylation [Ratio] in Platelets |
| 493 | du-5hiaa | umol | 49% | name+unit+values | 332 | 1.51 | [14.87, 17.89, 19.97, 21.96, 24, 26.85, 29.92, 35.9, 54.08] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid [Moles/time] in 24 hour Urine |
| 494 | du-5hiaa | umol/24h | 26% | name+unit+values | 175 | 0 | [13.31, 17.22, 20.27, 23.53, 25.81, 31.1, 37.11, 45.94, 66.13] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid [Moles/time] in 24 hour Urine |
| 495 | du-5hiaa | umol/l | 4% | name+unit | 25 | 0 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid [Moles/volume] in 24 hour Urine |
| 496 | du-5hiaa |  | 22% | name | 147 | 66.67 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid [Moles/time] in 24 hour Urine |
| 497 | fs-ace | u/l | 91% | name+unit+values | 33401 | 0.05 | [20.1, 26.68, 31.86, 36.8, 41.71, 47.15, 53.87, 62.77, 76.91] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma |
| 498 | fs-ace |  | 9% | name+values | 3291 | 89.58 | [11.62, 22.24, 28.9, 33.73, 39.48, 44.52, 50.34, 61.92, 75.37] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma |
| 499 | fs-apot |  | 100% | name | 258 | 100 |  |  | Fasting serum |  | Apolipoprotein [Mass/volume] in Serum or Plasma |
| 500 | fs-ffa | mmol/l | 90% | name+unit+values | 170 | 0.59 | [0.17, 0.25, 0.3, 0.38, 0.42, 0.5, 0.56, 0.69, 0.91] | fS-Rasvahapot, vapaat | Fasting serum |  | Fatty acids.free [Moles/volume] in Serum or Plasma |
| 501 | fs-ffa |  | 10% | name | 19 | 36.84 |  | fS-Rasvahapot, vapaat | Fasting serum |  | Fatty acids.free [Moles/volume] in Serum or Plasma |
| 502 | fs-tp-1 |  | 100% | name | 1698 | 100 |  |  | Fasting serum |  |  |
| 503 | fs-tp-3 |  | 100% | name | 867 | 100 |  |  | Fasting serum |  |  |
| 504 | fs-tp-4 |  | 100% | name | 926 | 100 |  |  | Fasting serum |  |  |
| 505 | fs-tp-7 |  | 100% | name | 400 | 100 |  |  | Fasting serum |  |  |
| 506 | li-tpha | titre | 2% | name+unit | 12 | 0 |  | Li-Treponema pallidum, hemagglutinaatio | Cerebrospinal fluid |  | Treponema pallidum Ab [Titer] in Cerebral spinal fluid by Hemagglutination |
| 507 | li-tpha |  | 98% | name | 526 | 100 |  | Li-Treponema pallidum, hemagglutinaatio | Cerebrospinal fluid |  | Treponema pallidum Ab [Titer] in Cerebral spinal fluid by Hemagglutination |
| 508 | p-hae |  | 100% | name | 461 | 100 |  |  | Plasma |  |  |
| 509 | p-hcg | iu/l | 3% | name+unit+values | 858 | 0 | [3.54, 10.48, 27.87, 72.06, 203.74, 526.1, 1525.11, 5507.31, 17831.23] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin [Units/volume] in Serum or Plasma |
| 510 | p-hcg | u/l | 45% | name+unit+values | 13156 | 11.71 | [0, 1.5, 5.06, 22.75, 97.57, 335.38, 1102.09, 3696.05, 18876.19] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin [Units/volume] in Serum or Plasma |
| 511 | p-hcg |  | 52% | name+values | 15471 | 94.78 | [2.42, 12.44, 35.69, 103.11, 288.41, 866.82, 2866.35, 7636.68, 32545.17] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin [Units/volume] in Serum or Plasma |
| 512 | p-he4 | pmol/l | 100% | name+unit+values | 2505 | 0.12 | [38.55, 42.76, 46.82, 51.17, 55.95, 62.75, 72.7, 92.45, 146.15] | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  | HE4 protein [Moles/volume] in Serum or Plasma |
| 513 | p-he4 |  | 0% | name | 6 | 100 |  | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  | HE4 protein [Moles/volume] in Serum or Plasma |
| 514 | p-hepg |  | 100% | name | 107 | 100 |  |  | Plasma |  |  |
| 515 | p-hok |  | 100% | name | 397 | 100 |  |  | Plasma |  |  |
| 516 | p-shbg | nmol/l | 51% | name+unit+values | 791 | 0 | [18.37, 23.23, 26.61, 30.13, 34.18, 38.05, 43.25, 50.43, 63.9] |  | Plasma |  | Sex hormone binding globulin [Moles/volume] in Serum or Plasma |
| 517 | p-shbg |  | 49% | name+values | 758 | 4.09 | [17.37, 21.68, 26.35, 30.87, 35.48, 41.39, 46.88, 56, 72.07] |  | Plasma |  | Sex hormone binding globulin [Moles/volume] in Serum or Plasma |
| 518 | s-5hiaa | nmol/l | 99% | name+unit+values | 10313 | 0.07 | [44.23, 52.73, 60.93, 69.76, 80.1, 94.8, 122.35, 200.37, 540.74] | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  | 5-Hydroxyindoleacetic acid [Moles/volume] in Serum or Plasma |
| 519 | s-5hiaa |  | 1% | name | 153 | 79.74 |  | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  | 5-Hydroxyindoleacetic acid [Moles/volume] in Serum or Plasma |
| 520 | s-ace | u/l | 74% | name+unit+values | 2203 | 0.18 | [19.48, 28.37, 33.74, 38.42, 43.02, 48.21, 54.09, 61.63, 75.23] |  | Serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma |
| 521 | s-ace |  | 26% | name+values | 769 | 20.68 | [21.02, 30.36, 34.97, 38.52, 42.83, 46.55, 51.62, 57.68, 65.53] |  | Serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma |
| 522 | s-ada | u/l | 94% | name+unit+values | 4147 | 1.33 | [7, 8.05, 9.23, 10.37, 11.69, 12.94, 14.77, 17.12, 21.32] | S -Adenosiinideaminaasi | Serum |  | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma |
| 523 | s-ada |  | 6% | name | 259 | 84.56 |  | S -Adenosiinideaminaasi | Serum |  | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma |
| 524 | s-afp | u/ml | 74% | name+unit+values | 18186 | 1.26 | [1.8, 2.08, 2.61, 3.01, 3.6, 4.33, 5.57, 7.77, 24.79] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-1-fetoprotein [Units/volume] in Serum or Plasma |
| 525 | s-afp | ug/l | 10% | name+unit+values | 2515 | 0 | [2, 2.23, 3, 3.96, 4.22, 5.38, 6.93, 9.7, 20.37] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-1-fetoprotein [Mass/volume] in Serum or Plasma |
| 526 | s-afp |  | 16% | name+values | 4026 | 80.55 | [2, 2.01, 3, 3, 3.99, 4, 5, 6.41, 9.69] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-1-fetoprotein [Units/volume] in Serum or Plasma |
| 527 | s-afp/d | u/ml | 83% | name+unit+values | 234 | 0 | [15.11, 17.44, 19.7, 22.07, 23.9, 26.33, 29.33, 33.17, 39.24] |  | Serum |  | Alpha-1-fetoprotein [Units/volume] in Serum or Plasma |
| 528 | s-afp/d |  | 17% | name | 49 | 12.24 |  |  | Serum |  | Alpha-1-fetoprotein [Units/volume] in Serum or Plasma |
| 529 | s-amh | ug/l | 88% | name+unit+values | 9545 | 0.43 | [0.42, 0.85, 1.31, 1.75, 2.24, 2.87, 3.63, 4.76, 7.13] | S -Anti-Muller hormoni | Serum |  | Anti-Mullerian hormone [Mass/volume] in Serum or Plasma |
| 530 | s-amh |  | 12% | name+values | 1328 | 93.45 | [0.62, 1.11, 1.66, 2.28, 2.8, 3.57, 4.21, 5.32, 7.88] | S -Anti-Muller hormoni | Serum |  | Anti-Mullerian hormone [Mass/volume] in Serum or Plasma |
| 531 | s-ami | mg/l | 49% | name+unit+values | 294 | 0 | [1.3, 1.49, 1.7, 2.28, 2.76, 3.41, 4.52, 6.36, 11.32] | S -Amikasiini | Serum |  | Amikacin [Mass/volume] in Serum or Plasma |
| 532 | s-ami |  | 51% | name | 308 | 95.13 |  | S -Amikasiini | Serum |  | Amikacin [Mass/volume] in Serum or Plasma |
| 533 | s-ana | titre | 26% | name+unit+values | 21493 | 1.69 | [80, 121.94, 160, 299.08, 320, 320, 399.84, 831.19, 1349.55] | S -Tuma, vasta-aineet | Serum |  | Nuclear antibody [Titer] in Serum |
| 534 | s-ana |  | 74% | name+values | 62781 | 100 | [80, 160, 320, 320, 320, 320, 640, 762.94, 1891.15] | S -Tuma, vasta-aineet | Serum |  | Nuclear antibody [Titer] in Serum |
| 535 | s-apot |  | 100% | name | 754 | 100 |  |  | Serum |  | Apolipoprotein [Mass/volume] in Serum or Plasma |
| 536 | s-asca | u/ml | 22% | name+unit | 89 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  | Saccharomyces cerevisiae Ab [Units/volume] in Serum |
| 537 | s-asca |  | 78% | name | 316 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  | Saccharomyces cerevisiae Ab [Units/volume] in Serum |
| 538 | s-ast | iu/ml | 44% | name+unit+values | 2404 | 0 | [49.92, 65.92, 77.55, 92.42, 111.12, 137.94, 173.28, 237.31, 396.71] | S -Antistreptolysiini | Serum |  | Streptolysin O Ab [Units/volume] in Serum |
| 539 | s-ast | titre | 0% | name+unit | 7 | 0 |  | S -Antistreptolysiini | Serum |  | Streptolysin O Ab [Titer] in Serum |
| 540 | s-ast | u/ml | 8% | name+unit+values | 408 | 4.17 | [30.71, 40.63, 53.38, 70.53, 94.49, 133.41, 202.61, 384.67, 783.66] | S -Antistreptolysiini | Serum |  | Streptolysin O Ab [Units/volume] in Serum |
| 541 | s-ast |  | 48% | name+values | 2603 | 94.05 | [60.92, 74.22, 90.53, 107.5, 145.19, 198.62, 261.7, 407.28, 740.72] | S -Antistreptolysiini | Serum |  | Streptolysin O Ab [Units/volume] in Serum |
| 542 | s-asta | iu/ml | 10% | name+unit+values | 256 | 16.41 | [2, 2, 2, 2, 3.02, 4, 4.64, 6, 8] | S -Antistafylolysiini | Serum |  | Staphylolysin Ab [Units/volume] in Serum |
| 543 | s-asta | u/ml | 0% | name+unit | 10 | 0 |  | S -Antistafylolysiini | Serum |  | Staphylolysin Ab [Units/volume] in Serum |
| 544 | s-asta |  | 89% | name | 2266 | 99.29 |  | S -Antistafylolysiini | Serum |  | Staphylolysin Ab [Units/volume] in Serum |
| 545 | s-br | mmol/l | 100% | name+unit | 130 | 0 |  | S -Bromidi | Serum |  | Bromide [Moles/volume] in Serum or Plasma |
| 546 | s-dhea | nmol/l | 84% | name+unit+values | 398 | 0 | [2.68, 4.23, 5.8, 8.33, 11.06, 14.2, 18.42, 22.5, 33.54] | S -Dehydroepiandrosteroni | Serum |  | Dehydroepiandrosterone [Moles/volume] in Serum or Plasma |
| 547 | s-dhea |  | 16% | name | 74 | 68.92 |  | S -Dehydroepiandrosteroni | Serum |  | Dehydroepiandrosterone [Moles/volume] in Serum or Plasma |
| 548 | s-dheas | umol/l | 92% | name+unit+values | 3797 | 0.03 | [1.05, 1.87, 2.83, 3.75, 4.58, 5.54, 6.67, 8.05, 10.29] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  | Dehydroepiandrosterone sulfate [Moles/volume] in Serum or Plasma |
| 549 | s-dheas |  | 8% | name+values | 331 | 53.47 | [1.45, 2.24, 2.88, 3.59, 4.26, 5.13, 5.94, 7.34, 8.82] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  | Dehydroepiandrosterone sulfate [Moles/volume] in Serum or Plasma |
| 550 | s-e1 | pmol/l | 80% | name+unit+values | 123 | 0 | [70, 112.9, 136.88, 181.46, 224.33, 282.87, 347.03, 435.1, 621.18] | S -Estroni | Serum |  | Estrone [Moles/volume] in Serum or Plasma |
| 551 | s-e1 |  | 20% | name | 30 | 76.67 |  | S -Estroni | Serum |  | Estrone [Moles/volume] in Serum or Plasma |
| 552 | s-e2 | nmol/l | 81% | name+unit+values | 10351 | 2.69 | [0.07, 0.1, 0.13, 0.16, 0.2, 0.27, 0.38, 0.55, 0.99] | S -Estradioli | Serum |  | Estradiol [Moles/volume] in Serum or Plasma |
| 553 | s-e2 |  | 19% | name+values | 2381 | 83.75 | [0.06, 0.08, 0.1, 0.12, 0.15, 0.19, 0.25, 0.35, 0.58] | S -Estradioli | Serum |  | Estradiol [Moles/volume] in Serum or Plasma |
| 554 | s-ema |  | 100% | name | 2245 | 99.96 |  | S -Endomysium, vasta-aineet | Serum |  | Endomysial Ab [Titer] in Serum |
| 555 | s-ena |  | 100% | name+values | 1469 | 62.22 | [0.1, 0.1, 0.1, 0.19, 0.2, 0.22, 0.3, 0.47, 1.12] |  | Serum |  | Extractable nuclear Ab [Ratio] in Serum |
| 556 | s-enal |  | 100% | name | 832 | 100 |  |  | Serum |  | Extractable nuclear Ab panel - Serum |
| 557 | s-epo | iu/l | 26% | name+unit+values | 2353 | 0.38 | [4.95, 7.08, 8.93, 10.78, 12.99, 15.54, 19.77, 28.75, 48.4] | S -Erytropoietiini | Serum |  | Erythropoietin [Units/volume] in Serum or Plasma |
| 558 | s-epo | pmol/l | 0% | name+unit | 44 | 0 |  | S -Erytropoietiini | Serum |  | Erythropoietin [Moles/volume] in Serum or Plasma |
| 559 | s-epo | u/l | 60% | name+unit+values | 5380 | 0 | [4.44, 6.44, 8.09, 9.88, 11.93, 14.55, 19.01, 29.55, 62.33] | S -Erytropoietiini | Serum |  | Erythropoietin [Units/volume] in Serum or Plasma |
| 560 | s-epo |  | 13% | name+values | 1209 | 20.35 | [4.6, 6.64, 8.47, 10.2, 11.81, 13.76, 17.07, 22.59, 40.53] | S -Erytropoietiini | Serum |  | Erythropoietin [Units/volume] in Serum or Plasma |
| 561 | s-ffa | mmol/l | 100% | name+unit+values | 518 | 0 | [0.03, 0.04, 0.07, 0.13, 0.19, 0.28, 0.44, 0.57, 0.75] |  | Serum |  | Fatty acids.free [Moles/volume] in Serum or Plasma |
| 562 | s-gen | mg/l | 52% | name+unit+values | 373 | 0.54 | [0.5, 0.65, 0.75, 0.89, 0.99, 1.17, 1.48, 2.04, 3.94] | S -Gentamysiini | Serum |  | Gentamicin [Mass/volume] in Serum or Plasma |
| 563 | s-gen |  | 48% | name | 339 | 85.55 |  | S -Gentamysiini | Serum |  | Gentamicin [Mass/volume] in Serum or Plasma |
| 564 | s-hae |  | 100% | name | 751 | 100 |  |  | Serum |  |  |
| 565 | s-hbe |  | 100% | name | 347 | 100 |  |  | Serum |  |  |
| 566 | s-hcg | iu/l | 9% | name+unit+values | 2181 | 0 | [2.11, 4.62, 15.8, 53.63, 166.71, 442, 1018.25, 2912.42, 12003.73] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin [Units/volume] in Serum or Plasma |
| 567 | s-hcg | u/l | 24% | name+unit+values | 5914 | 0 | [5.67, 20.66, 67.43, 172.44, 366.74, 677.25, 1513.49, 4378.78, 17452.46] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin [Units/volume] in Serum or Plasma |
| 568 | s-hcg |  | 67% | name+values | 16592 | 96.23 | [8.29, 17.67, 40.08, 108.43, 306.84, 912.85, 3181.52, 10206.39, 38671.9] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin [Units/volume] in Serum or Plasma |
| 569 | s-he4 | pmol/l | 96% | name+unit+values | 11193 | 0 | [31.87, 37.18, 41.94, 46.96, 53.02, 60.99, 73.42, 98.24, 181.66] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  | HE4 protein [Moles/volume] in Serum or Plasma |
| 570 | s-he4 |  | 4% | name+values | 420 | 43.57 | [28.77, 32.37, 35.15, 39.84, 42.92, 45.83, 51.37, 61.13, 81.8] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  | HE4 protein [Moles/volume] in Serum or Plasma |
| 571 | s-kem |  | 100% | name | 1473 | 100 |  |  | Serum |  |  |
| 572 | s-kyhemag | titre | 18% | name+unit+values | 180 | 1.67 | [8, 11.41, 16, 18.4, 42.5, 146.59, 256, 870.4, 2048] | S -Kylmähemagglutiniinit | Serum |  | Cold agglutinin [Titer] in Serum |
| 573 | s-kyhemag |  | 82% | name | 826 | 99.39 |  | S -Kylmähemagglutiniinit | Serum |  | Cold agglutinin [Titer] in Serum |
| 574 | s-shbg | nmol/l | 98% | name+unit+values | 29338 | 0 | [16.96, 21.37, 25.29, 29.19, 33.26, 37.98, 43.62, 51.6, 65.13] | S -Sukupuolihormoneja sitova globuliini | Serum |  | Sex hormone binding globulin [Moles/volume] in Serum or Plasma |
| 575 | s-shbg |  | 2% | name+values | 614 | 100 | [15.22, 19.74, 24.23, 28.3, 32.4, 37.12, 43.41, 51.5, 64.44] | S -Sukupuolihormoneja sitova globuliini | Serum |  | Sex hormone binding globulin [Moles/volume] in Serum or Plasma |
| 576 | s-tati | nmol/l | 51% | name+unit+values | 551 | 0 | [1.3, 1.49, 1.61, 1.81, 2.08, 2.38, 2.74, 3.44, 6.09] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor associated trypsin inhibitor [Moles/volume] in Serum or Plasma |
| 577 | s-tati | ug/l | 41% | name+unit+values | 446 | 0 | [6.71, 8.1, 9.03, 9.98, 11, 12.24, 13.98, 16.99, 30.9] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor associated trypsin inhibitor [Mass/volume] in Serum or Plasma |
| 578 | s-tati |  | 8% | name | 86 | 24.42 |  | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor associated trypsin inhibitor [Moles/volume] in Serum or Plasma |
| 579 | s-tpha | titre | 15% | name+unit+values | 1665 | 0 | [158.37, 304.61, 391.53, 640, 1034.44, 1338.85, 3168.84, 4985.37, 6432.72] | S -Treponema pallidum, hemagglutinaatio | Serum |  | Treponema pallidum Ab [Titer] in Serum by Hemagglutination |
| 580 | s-tpha |  | 85% | name | 9799 | 99.67 |  | S -Treponema pallidum, hemagglutinaatio | Serum |  | Treponema pallidum Ab [Titer] in Serum by Hemagglutination |
| 581 | s-van | mg/l | 96% | name+unit+values | 36935 | 0.09 | [6.84, 8.59, 9.97, 11.16, 12.39, 13.69, 15.03, 16.85, 19.72] | S -Vankomysiini | Serum |  | Vancomycin [Mass/volume] in Serum or Plasma |
| 582 | s-van |  | 4% | name+values | 1695 | 100 | [7.35, 9.11, 10.49, 11.71, 12.89, 14.15, 15.61, 17.74, 21.29] | S -Vankomysiini | Serum |  | Vancomycin [Mass/volume] in Serum or Plasma |
| 583 | ts-res |  | 100% | name | 1353 | 100 |  | Ts-Reseptoritutkimus | Tissue |  | Estrogen and Progesterone receptor panel - Tissue |
| 584 | u-hcg | iu/l | 28% | name+unit | 93 | 0 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin [Units/volume] in Urine |
| 585 | u-hcg | u/l | 4% | name+unit | 15 | 0 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin [Units/volume] in Urine |
| 586 | u-hcg |  | 68% | name | 227 | 97.8 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin [Presence] in Urine |

