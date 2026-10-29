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
Here is group 20.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3044889 | 12 lead EKG panel | 1.000 |  |
| 3033564 | Herpes simplex virus 2 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.965 |  |
| 3016894 | Varicella zoster virus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.964 |  |
| 1988744 | Listeria monocytogenes DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.962 |  |
| 42868767 | Plesiomonas shigelloides DNA [Presence] in Stool by NAA with probe detection | 0.961 |  |
| 37020818 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with probe detection | 0.960 |  |
| 3023671 | Herpes simplex virus 1 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.959 |  |
| 1469649 | Campylobacter sp DNA [Presence] in Stool by NAA with probe detection | 0.958 |  |
| 1617228 | Escherichia coli enterotoxigenic DNA [Presence] in Stool by NAA with probe detection | 0.958 |  |
| 1988730 | Neisseria meningitidis DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.956 |  |
| 1616933 | Salmonella sp DNA [Presence] in Stool by NAA with probe detection | 0.956 |  |
| 21493350 | Listeria monocytogenes DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.956 |  |
| 3011927 | Cytomegalovirus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.955 |  |
| 1988894 | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.955 |  |
| 1988899 | Streptococcus pneumoniae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.955 |  |
| 21493354 | Varicella zoster virus DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.954 |  |
| 21493357 | Herpes simplex virus 2 DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.954 |  |
| 21493356 | Herpes simplex virus 1 DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.953 |  |
| 1616308 | Escherichia coli enteropathogenic DNA [Presence] in Stool by NAA with probe detection | 0.951 |  |
| 21493352 | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.949 |  |
| 21493466 | Plesiomonas shigelloides DNA [Presence] in Stool by NAA with non-probe detection | 0.947 |  |
| 21493355 | Cytomegalovirus DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.947 |  |
| 21493351 | Neisseria meningitidis DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.945 |  |
| 21493470 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with non-probe detection | 0.945 |  |
| 1988643 | Escherichia coli K1 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.945 |  |
| 3008733 | Herpes simplex virus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.945 |  |
| 21493353 | Streptococcus pneumoniae DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.944 |  |
| 1616645 | Escherichia coli enteroaggregative DNA [Presence] in Stool by NAA with probe detection | 0.942 |  |
| 3002781 | Herpes simplex virus 1+2 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.938 |  |
| 21493348 | Escherichia coli K1 DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.935 |  |
| 42870368 | Campylobacter sp DNA.diarrheagenic [Presence] in Stool by NAA with probe detection | 0.927 |  |
| 3966289 | Campylobacter jejuni DNA [Presence] in Stool by NAA with probe detection | 0.925 |  |
| 1469726 | Herpes virus 7 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.920 |  |
| 3965358 | Campylobacter coli DNA [Presence] in Stool by NAA with probe detection | 0.920 |  |
| 3966224 | Campylobacter upsaliensis DNA [Presence] in Stool by NAA with probe detection | 0.914 |  |
| 40765218 | Herpes virus 6A DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.909 |  |
| 21492842 | Escherichia coli enteropathogenic eae gene [Presence] in Stool by NAA with non-probe detection | 0.909 |  |
| 3966743 | Escherichia coli enteroinvasive DNA [Presence] in Stool by NAA with probe detection | 0.908 |  |
| 1988916 | Cryptococcus gattii+neoformans DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.908 |  |
| 3046896 | Herpes virus 6 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.905 |  |
| 1092255 | Campylobacter sp DNA [Identifier] in Stool by NAA with probe detection | 0.903 |  |
| 36304546 | Varicella zoster virus DNA [Presence] in Body fluid by NAA with probe detection | 0.902 |  |
| 21493467 | Salmonella enterica+bongori DNA [Presence] in Stool by NAA with non-probe detection | 0.902 |  |
| 1091300 | Yersinia enterocolitica DNA [Presence] in Specimen by NAA with probe detection | 0.899 |  |
| 40765219 | Herpes virus 6B DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.899 |  |
| 21493558 | Escherichia coli enterotoxigenic eltA+estB genes [Presence] in Stool by NAA with probe detection | 0.894 |  |
| 1092359 | Campylobacter sp DNA [Presence] in Specimen by NAA with probe detection | 0.894 |  |
| 1616367 | Campylobacter coli+jejuni+upsaliensis DNA [Presence] in Stool by NAA with probe detection | 0.894 |  |
| 3030436 | Herpes simplex virus 2 DNA [#/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.893 |  |
| 1469633 | Shigella species+EIEC DNA [Presence] in Stool by NAA with probe detection | 0.893 |  |
| 21492663 | Yersinia enterocolitica recN gene [Presence] in Stool by NAA with probe detection | 0.891 |  |
| 3052840 | Varicella zoster virus DNA [#/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.891 |  |
| 1175408 | Cryptococcus sp rRNA gene [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.890 |  |
| 21493362 | Campylobacter coli+jejuni+upsaliensis DNA [Presence] in Stool by NAA with non-probe detection | 0.889 |  |
| 21492661 | Salmonella sp rpoD gene [Presence] in Stool by NAA with probe detection | 0.888 |  |
| 1617150 | Escherichia coli O157 DNA [Presence] in Stool by NAA with probe detection | 0.888 |  |
| 1761458 | Varicella zoster virus DNA [Log #/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.888 |  |
| 1469822 | Escherichia coli shiga-like toxin DNA [Presence] in Stool by NAA with probe detection | 0.886 |  |
| 3966163 | Shigella sp DNA [Presence] in Stool by NAA with probe detection | 0.886 |  |
| 3000384 | Varicella zoster virus DNA [Presence] in Serum by NAA with probe detection | 0.884 |  |
| 36204312 | Varicella zoster virus DNA [Presence] in Amniotic fluid by NAA with probe detection | 0.884 |  |
| 3032674 | Salmonella sp DNA [Presence] in Specimen by NAA with probe detection | 0.884 |  |
| 21493347 | Cryptococcus gattii+neoformans DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.883 |  |
| 3042515 | Neisseria meningitidis DNA [Presence] in Blood by NAA with probe detection | 0.883 |  |
| 1989596 | Streptococcus pyogenes DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.882 |  |
| 3965777 | Cryptococcus neoformans DNA [Presence] in Specimen by NAA with probe detection | 0.880 |  |
| 3005197 | Varicella zoster virus DNA [Presence] in Blood by NAA with probe detection | 0.880 |  |
| 649062 | Plesiomonas shigelloides and aeromonas sp DNA [Identifier] in Stool by NAA with probe detection | 0.879 |  |
| 36305298 | Varicella zoster virus DNA [Presence] in Aspirate by NAA with probe detection | 0.879 |  |
| 21493472 | Escherichia coli O157 DNA [Presence] in Stool by NAA with non-probe detection | 0.878 |  |
| 3043907 | Cytomegalovirus DNA [#/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.878 |  |
| 36303825 | Escherichia coli eaeA gene [Presence] in Stool by NAA with probe detection | 0.877 |  |
| 1617553 | Streptococcus pneumoniae DNA [Presence] in Synovial fluid by NAA with non-probe detection | 0.876 |  |
| 647508 | Cytomegalovirus DNA [log units/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.875 |  |
| 1617136 | Vibrio parahaemolyticus DNA [Presence] in Stool by NAA with probe detection | 0.875 |  |
| 21493559 | Salmonella sp invA+fliC genes [Presence] in Stool by NAA with probe detection | 0.874 |  |
| 3965246 | Cytomegalovirus DNA [Units/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.873 |  |
| 647444 | Varicella zoster virus DNA [Measurement] in Cerebral spinal fluid | 0.873 |  |
| 1259931 | Blastomyces sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.872 |  |
| 21493883 | Salmonella sp spaO gene [Presence] in Stool by NAA with probe detection | 0.872 |  |
| 3038874 | Streptococcus pneumoniae DNA [Presence] in Blood by NAA with probe detection | 0.871 |  |
| 1470026 | Neisseria meningitidis DNA [Presence] in Body fluid by NAA with non-probe detection | 0.870 |  |
| 21492845 | Escherichia coli enterotoxigenic ltA+st1a+st1b genes [Presence] in Stool by NAA with non-probe detection | 0.870 |  |
| 648359 | Cytomegalovirus DNA [Log #/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.870 |  |
| 21492843 | Escherichia coli enteroaggregative pAA plasmid aggR+aatA genes [Presence] in Stool by NAA with non-probe detection | 0.869 |  |
| 3030388 | Neisseria meningitidis DNA [Presence] in Specimen by NAA with probe detection | 0.867 |  |
| 1469938 | Streptococcus pneumoniae DNA [Presence] in Body fluid by NAA with non-probe detection | 0.866 |  |
| 1091086 | Streptococcus pneumoniae DNA [Presence] in Nasopharynx by NAA with probe detection | 0.864 |  |
| 1259851 | Entamoeba coli DNA [Presence] in Stool by NAA with probe detection | 0.864 |  |
| 1259979 | Histoplasma sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.864 |  |
| 1469493 | Salmonella sp DNA [Presence] in Body fluid by NAA with non-probe detection | 0.861 |  |
| 37020459 | Cryptococcus neoformans DNA [Presence] by NAA with probe detection in Positive blood culture | 0.860 |  |
| 1259632 | Coccidioides sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.860 |  |
| 3966671 | Aeromonas sp DNA [Presence] in Stool by NAA with probe detection | 0.860 |  |
| 1616546 | Streptococcus agalactiae DNA [Presence] in Synovial fluid by NAA with non-probe detection | 0.860 |  |
| 1091817 | Yersinia enterocolitica DNA [Presence] in Specimen | 0.857 |  |
| 647294 | Cytomegalovirus DNA [Measurement] in Cerebral spinal fluid | 0.857 |  |
| 40764131 | Salmonella enterica DNA [Presence] in Specimen by NAA with probe detection | 0.857 |  |
| 21492665 | Escherichia coli Stx2 toxin stx2 gene [Presence] in Stool by NAA with probe detection | 0.857 |  |
| 3018642 | Streptococcus agalactiae Ag [Presence] in Cerebral spinal fluid | 0.856 |  |
| 3031469 | Cytomegalovirus DNA [Presence] in Amniotic fluid by NAA with probe detection | 0.855 |  |
| 1469780 | Streptococcus agalactiae DNA [Presence] in Body fluid by NAA with non-probe detection | 0.854 |  |
| 3966738 | Aeromonas hydrophila DNA [Presence] in Stool by NAA with probe detection | 0.854 |  |
| 1091127 | Escherichia coli enterotoxigenic ltA+st1a+st1b genes [Presence] in Stool | 0.853 |  |
| 36305353 | Listeria monocytogenes DNA [Presence] in Blood by NAA with probe detection | 0.851 |  |
| 1002168 | Neisseria meningitidis DNA [Presence] by NAA with probe detection in Positive blood culture | 0.850 |  |
| 1091454 | Yersinia pseudotuberculosis complex DNA [Presence] in Specimen by NAA with probe detection | 0.850 |  |
| 3004245 | Escherichia coli K1 Ag [Presence] in Cerebral spinal fluid | 0.848 |  |
| 1091690 | Plesiomonas shigelloides DNA [Presence] in Specimen | 0.848 |  |
| 3048882 | Streptococcus agalactiae DNA [Presence] in Specimen by NAA with probe detection | 0.847 | 1156 |
| 42868716 | Shigella species+EIEC invasion plasmid antigen H ipaH gene [Presence] in Stool by NAA with probe detection | 0.846 |  |
| 36303723 | Cytomegalovirus Ag [Presence] in Cerebral spinal fluid by Immunofluorescence | 0.846 |  |
| 1469662 | Listeria monocytogenes DNA [Presence] in Body fluid by NAA with non-probe detection | 0.845 |  |
| 3026422 | Neisseria meningitidis Ag [Presence] in Cerebral spinal fluid | 0.843 |  |
| 36203226 | Neisseria meningitidis DNA [Presence] by NAA with non-probe detection in Positive blood culture | 0.843 |  |
| 40764130 | Listeria monocytogenes DNA [Presence] in Specimen by NAA with probe detection | 0.843 |  |
| 3001363 | Cryptococcus sp Ag [Presence] in Cerebral spinal fluid | 0.843 | 1707 |
| 37020949 | Neisseria meningitidis DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.843 |  |
| 3046567 | Escherichia coli O157:H7 Ag [Presence] in Stool | 0.842 |  |
| 3965696 | Yersinia enterocolitica DNA [Presence] in Wound by NAA with probe detection | 0.840 |  |
| 40766195 | Brucella sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.837 |  |
| 3004834 | Cryptococcus sp Ag [Presence] in Cerebral spinal fluid by Immunoassay | 0.836 |  |
| 21492844 | Shigella species+EIEC invasion plasmid antigen H ipaH gene [Presence] in Stool by NAA with non-probe detection | 0.833 |  |
| 3048762 | Shigella sp DNA [Presence] in Specimen by NAA with probe detection | 0.833 |  |
| 3006574 | Escherichia coli verotoxin 1 [Presence] in Stool | 0.829 |  |
| 3025564 | Escherichia coli verotoxin 2 [Presence] in Stool | 0.827 |  |
| 3005925 | Escherichia coli K1 Ag [Presence] in Cerebral spinal fluid by Latex agglutination | 0.818 |  |
| 1091794 | Escherichia coli Stx1 and Stx2 toxin stx1+stx2 genes [Presence] in Stool | 0.801 |  |
| 3040222 | Escherichia coli shiga-like toxin 2 [Presence] in Stool by Immunoassay | 0.800 |  |
| 3041798 | Escherichia coli shiga-like toxin 1 [Presence] in Stool by Immunoassay | 0.800 |  |
| 3020489 | Escherichia coli shiga-like toxin [Presence] in Stool by Immunoassay | 0.796 | 589 |
| 3038330 | Escherichia coli enteroinvasive [Presence] in Isolate | 0.793 |  |
| 42529409 | Escherichia coli O157 [Presence] in Stool by Culture | 0.785 |  |
| 42529406 | Shigella sp [Presence] in Stool by Culture | 0.781 |  |
| 3023207 | Escherichia coli O157:H7 [Presence] in Stool by Organism specific culture | 0.775 |  |
| 42529405 | Escherichia coli shiga-like toxin 1+2 [Presence] in Stool by Immunoassay | 0.762 |  |
| 1091029 | Shigella species+EIEC invasion plasmid antigen H ipaH gene [Presence] in Specimen | 0.740 |  |
| 3020434 | Escherichia coli enteroinvasive identified in Stool by Organism specific culture | 0.733 |  |
| 3043216 | Cardiovascular physiologic and EKG assessment panel | 0.695 |  |
| 3023075 | Type of EKG leads | 0.684 |  |
| 3042945 | Cardiac monitor interpretation Narrative | 0.662 |  |
| 3020019 | EKG impression | 0.655 |  |
| 1988764 | Electromyography panel | 0.654 |  |
| 1259654 | Diagnostic multisection transesophageal and cardioversion panel Heart | 0.652 |  |
| 1988411 | Permanent pacemaker panel | 0.642 |  |
| 3044933 | Cardiac 2D echo panel | 0.641 |  |
| 3013512 | EKG study | 0.638 |  |
| 21491595 | Coronary angiography panel | 0.631 |  |
| 1988463 | Pacemaker Atrial electrical activity captured | 0.629 |  |
| 21490871 | Type of arrhythmia on EKG | 0.628 |  |
| 1988318 | Temporary pacemaker panel | 0.628 |  |
| 3044671 | QRS duration {Electrocardiograph lead} | 0.625 |  |
| 21490872 | Heart rate.beat-to-beat by EKG | 0.622 |  |
| 40771965 | Cardiology monitoring | 0.620 |  |
| 3014761 | Prosthetic cardiac pacemaker [Interpretation] by EKG | 0.617 |  |
| 3016652 | QRS complex [Interpretation] by EKG | 0.617 |  |
| 3004451 | EKG impression Narrative | 0.616 |  |
| 3002185 | P wave Atrium by EKG | 0.605 |  |
| 1988306 | Pacemaker Atrial electrical activity sensed | 0.605 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 106 | ehec(enterohemorraaginene.coli) |  | 100% | name | 1317 | 100 |  |  |  |  | Escherichia coli.enterohemorrhagic [Presence] in Stool |
| 107 | ekg,12kytkentäälevossa |  | 100% | name | 6937 | 100 |  |  |  |  | 12 lead EKG panel |
| 108 | ekg,12kytkentäälevossa(asi |  | 100% | name | 8872 | 100 |  |  |  |  | 12 lead EKG panel |
| 109 | ekg,12kytkentäälevossa(asiakkaanottama) |  | 100% | name | 2232 | 100 |  |  |  |  | 12 lead EKG panel |
| 110 | ekg,12kytkentäälevossa(asiakkanottama) |  | 100% | name | 1287 | 100 |  |  |  |  | 12 lead EKG panel |
| 111 | ekg-12kytkentäälevossa |  | 100% | name | 2227 | 100 |  |  |  |  | 12 lead EKG panel |
| 112 | enteroaggregatiivinene.colinho |  | 100% | name | 229 | 100 |  |  |  |  | Escherichia coli.enteroaggregative DNA [Presence] in Stool by NAA |
| 113 | enterohemorraginene.colinho |  | 100% | name | 383 | 100 |  |  |  |  | Escherichia coli.enterohemorrhagic DNA [Presence] in Stool by NAA |
| 114 | enteropatogeeninene.colinho |  | 100% | name | 229 | 100 |  |  |  |  | Escherichia coli.enteropathogenic DNA [Presence] in Stool by NAA |
| 115 | enterotoksigeeninene.colinho |  | 100% | name | 383 | 100 |  |  |  |  | Escherichia coli.enterotoxigenic DNA [Presence] in Stool by NAA |
| 116 | etec(enterotoksigeeninene.coli) |  | 100% | name | 1317 | 100 |  |  |  |  | Escherichia coli.enterotoxigenic [Presence] in Stool |
| 117 | f-campylobacterspp.(jejuni&coli)nukl.haponos |  | 100% | name | 607 | 100 |  |  | Feces |  | Campylobacter sp DNA [Presence] in Stool by NAA |
| 118 | f-ehec(enterohemorraaginene.coli)nukl.haponos |  | 100% | name | 607 | 100 |  |  | Feces |  | Escherichia coli.enterohemorrhagic DNA [Presence] in Stool by NAA |
| 119 | f-etec(enterotoksigeeninene.coli)nukl.haponos |  | 100% | name | 607 | 100 |  |  | Feces |  | Escherichia coli.enterotoxigenic DNA [Presence] in Stool by NAA |
| 120 | f-plesiomonasshigelloidesnukl.haponos. |  | 100% | name | 607 | 100 |  |  | Feces |  | Plesiomonas shigelloides DNA [Presence] in Stool by NAA |
| 121 | f-salmonellaspp.nukl.haponos |  | 100% | name | 607 | 100 |  |  | Feces |  | Salmonella sp DNA [Presence] in Stool by NAA |
| 122 | f-shigellaspp./eiec(enteroinvasiivinene.coli)nukl.haponos |  | 100% | name | 616 | 100 |  |  | Feces |  | Shigella sp+Escherichia coli.enteroinvasive DNA [Presence] in Stool by NAA |
| 123 | f-yersiniaenterocoliticanukl.haponos. |  | 100% | name | 607 | 100 |  |  | Feces |  | Yersinia enterocolitica DNA [Presence] in Stool by NAA |
| 124 | li-cryptococcusneoformans,nukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Cryptococcus neoformans DNA [Presence] in Cerebral spinal fluid by NAA |
| 125 | li-cytomegalovirusnukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Cytomegalovirus DNA [Presence] in Cerebral spinal fluid by NAA |
| 126 | li-escherichiacolik1nukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Escherichia coli K1 antigen DNA [Presence] in Cerebral spinal fluid by NAA |
| 127 | li-herpessimplex1,nukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Herpes simplex virus 1 DNA [Presence] in Cerebral spinal fluid by NAA |
| 128 | li-herpessimplex2,nukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Herpes simplex virus 2 DNA [Presence] in Cerebral spinal fluid by NAA |
| 129 | li-l.monocytogenesnukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Listeria monocytogenes DNA [Presence] in Cerebral spinal fluid by NAA |
| 130 | li-neisseriameningitidisnukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Neisseria meningitidis DNA [Presence] in Cerebral spinal fluid by NAA |
| 131 | li-streptococcusagalactiaenukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA |
| 132 | li-streptococcuspneumoniaenukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Streptococcus pneumoniae DNA [Presence] in Cerebral spinal fluid by NAA |
| 133 | li-varicella-zosternukl.haponos. |  | 100% | name | 129 | 100 |  |  | Cerebrospinal fluid |  | Varicella zoster virus DNA [Presence] in Cerebral spinal fluid by NAA |
| 134 | pt-ekg,12kytkentälevossa |  | 100% | name | 243 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 135 | pt-ekg,12kytkentää6tk |  | 100% | name | 368 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 136 | pt-ekg,12kytkentääep-terveyskeskus |  | 100% | name | 206 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 137 | pt-ekg,12kytkentäälevossa | 1 | 0% | name+unit | 55 | 0 |  |  | Patient |  | 12 lead EKG panel |
| 138 | pt-ekg,12kytkentäälevossa |  | 100% | name | 54957 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 139 | pt-ekg,12kytkentäälevossa(k-pks:n)(ko) |  | 100% | name | 272 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 140 | pt-ekg,12kytkentäälevossa(ot.tk:ssa) |  | 100% | name | 210 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 141 | pt-ekg,12kytkentäälevossa,omarekisteröintimuseen |  | 100% | name | 2847 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 142 | pt-ekg,12kytkentäälevossaosastolla |  | 100% | name | 193 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 143 | pt-ekg,12kytkentäälevossa␤ |  | 100% | name | 2419 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 144 | pt-ekg,eteisvärinänseulonta,valvontamonitori-ekg |  | 100% | name | 477 | 100 |  |  | Patient |  | Atrial fibrillation [Presence] by EKG.monitor |
| 145 | pt-ekg,eteisvärinänseulonta,valvontamonitori-ekg,lisätallenne |  | 100% | name | 625 | 100 |  |  | Patient |  | Atrial fibrillation [Presence] by EKG.monitor |
| 146 | pt-ekg,sisältäentietokoneanalyysin |  | 100% | name | 8257 | 100 |  |  | Patient |  | 12 lead EKG with interpretation panel |
| 147 | pt-ekg,sisältäentietokoneanalyysin(malmin)(pi) |  | 100% | name | 226 | 100 |  |  | Patient |  | 12 lead EKG with interpretation panel |
| 148 | pt-ekg,sisältäätietokoneanalyysin |  | 100% | name | 4178 | 100 |  |  | Patient |  | 12 lead EKG with interpretation panel |
| 149 | pt-ekgsis[lt[entietokoneanalyysin |  | 100% | name | 305 | 100 |  |  | Patient |  | 12 lead EKG with interpretation panel |
| 150 | pt-ekgsisältäentietokoneanalyysin |  | 100% | name | 347 | 100 |  |  | Patient |  | 12 lead EKG with interpretation panel |
| 151 | shigella/eiec(enteroinvasiivinene.coli) |  | 100% | name | 1318 | 100 |  |  |  |  | Shigella sp+Escherichia coli.enteroinvasive [Presence] in Stool |

