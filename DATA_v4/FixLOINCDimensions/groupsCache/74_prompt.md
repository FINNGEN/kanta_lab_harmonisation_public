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
Here is group 74.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 1616933 | Salmonella sp DNA [Presence] in Stool by NAA with probe detection | 1.000 |  |
| 3012477 | Bordetella pertussis DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 3015822 | Parvovirus B19 DNA [Presence] in Serum by NAA with probe detection | 1.000 |  |
| 3032674 | Salmonella sp DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 3033060 | Aspergillus sp DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 3037875 | Bordetella parapertussis DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 3038546 | Human coronavirus OC43 RNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 3040359 | Human coronavirus NL63 RNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 3041642 | Human coronavirus 229E RNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 40765160 | Human coronavirus HKU1 RNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 40765161 | Human bocavirus DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 648686 | Borrelia sp DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  |
| 646724 | Human coronavirus 229E RNA [Presence] in Specimen by NAA with non-probe detection | 0.983 |  |
| 645449 | Human coronavirus OC43 RNA [Presence] in Specimen by NAA with non-probe detection | 0.980 |  |
| 646769 | Human coronavirus NL63 RNA [Presence] in Specimen by NAA with non-probe detection | 0.977 |  |
| 1469897 | Bordetella parapertussis DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.977 |  |
| 1469600 | Bordetella pertussis DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.974 |  |
| 3028372 | Borrelia burgdorferi DNA [Presence] in Specimen by NAA with probe detection | 0.972 | 1877 |
| 1091135 | Borreliella sp DNA [Presence] in Specimen by NAA with probe detection | 0.972 |  |
| 645895 | Human coronavirus HKU1 RNA [Presence] in Specimen by NAA with non-probe detection | 0.972 |  |
| 3032435 | Parvovirus B19 DNA [Presence] in Blood by NAA with probe detection | 0.969 |  |
| 40765215 | Aspergillus fumigatus DNA [Presence] in Specimen by NAA with probe detection | 0.966 |  |
| 36305676 | Human coronavirus HKU1 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.963 |  |
| 40764131 | Salmonella enterica DNA [Presence] in Specimen by NAA with probe detection | 0.962 |  |
| 36304464 | Human coronavirus OC43 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.962 |  |
| 1091709 | Human coronavirus NL63 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.962 |  |
| 1092421 | Human coronavirus OC43 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.961 |  |
| 36304601 | Human coronavirus 229E RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.958 |  |
| 1091614 | Aspergillus clavatus DNA [Presence] in Specimen by NAA with probe detection | 0.958 |  |
| 37019602 | Bordetella parapertussis DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.958 |  |
| 36304548 | Human coronavirus NL63 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.957 |  |
| 3965970 | Human coronavirus 229E RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.956 |  |
| 37021179 | Bordetella parapertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.954 |  |
| 42869862 | Sapovirus RNA [Presence] in Specimen by NAA with probe detection | 0.953 |  |
| 3964787 | Human coronavirus HKU1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.953 |  |
| 37020862 | Bordetella pertussis DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.952 |  |
| 40766162 | Bordetella sp DNA [Presence] in Specimen by NAA with probe detection | 0.952 |  |
| 3966673 | Human coronavirus OC43 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.952 |  |
| 3009121 | Parvovirus B19 DNA [Presence] in Specimen by NAA with probe detection | 0.952 |  |
| 3034972 | Bordetella parapertussis DNA [Presence] in Nasopharynx by NAA with probe detection | 0.951 |  |
| 37020160 | Bordetella pertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.951 |  |
| 36305655 | Human bocavirus DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.950 |  |
| 3965131 | Sapovirus genogroup V RNA [Presence] in Stool by NAA with probe detection | 0.949 |  |
| 3965395 | Human coronavirus NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.948 |  |
| 1091933 | Human coronavirus OC43 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.947 |  |
| 3023950 | Parvovirus B19 RNA [Presence] in Blood by NAA with probe detection | 0.947 |  |
| 36305656 | Human coronavirus NL63 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.946 |  |
| 1091866 | Human coronavirus NL63 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.946 |  |
| 1091764 | Bordetella parapertussis DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.945 |  |
| 36304330 | Human coronavirus 229E RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.944 |  |
| 36659767 | Bordetella pertussis DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.944 |  |
| 36305349 | Human coronavirus HKU1 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.943 |  |
| 37021002 | Bordetella parapertussis DNA [Presence] in Throat by NAA with probe detection | 0.943 |  |
| 3047117 | Bordetella pertussis DNA [Presence] in Nasopharynx by NAA with probe detection | 0.942 |  |
| 36204249 | Human bocavirus DNA [Presence] in Tissue by NAA with probe detection | 0.941 |  |
| 36304961 | Human coronavirus OC43 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.941 |  |
| 36660329 | Human coronavirus NL63 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.941 |  |
| 36031318 | Borrelia sp DNA [Presence] in Blood by NAA with probe detection | 0.941 |  |
| 1091342 | Human coronavirus HKU1 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.941 |  |
| 36660364 | Human coronavirus OC43 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.940 |  |
| 1761619 | Aspergillus sp DNA [Presence] in Blood by NAA with probe detection | 0.940 |  |
| 36660491 | Human coronavirus 229E RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.939 |  |
| 1176020 | Aspergillus sp DNA [Presence] in Tissue by NAA with probe detection | 0.939 |  |
| 37020168 | Bordetella pertussis DNA [Presence] in Throat by NAA with probe detection | 0.938 |  |
| 1091413 | Aspergillus flavus DNA [Presence] in Specimen by NAA with probe detection | 0.937 |  |
| 1091444 | Human coronavirus 229E RNA [Presence] in Specimen | 0.937 |  |
| 1176455 | Aspergillus sp DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.937 |  |
| 1469496 | Human bocavirus DNA [Presence] in Sputum by NAA with probe detection | 0.937 |  |
| 1259587 | Human bocavirus DNA [Presence] in Upper respiratory specimen by NAA with non-probe detection | 0.936 |  |
| 1092055 | Human bocavirus DNA [Presence] in Nasopharynx by NAA with probe detection | 0.936 |  |
| 21493148 | Human coronavirus OC43 RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.934 |  |
| 36303776 | Human bocavirus DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.934 |  |
| 36305615 | Human coronavirus NL63 RNA [Presence] in Aspirate by NAA with probe detection | 0.934 |  |
| 36659667 | Human coronavirus HKU1 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.934 |  |
| 36303607 | Human coronavirus 229E RNA [Presence] in Aspirate by NAA with probe detection | 0.933 |  |
| 3029274 | Parvovirus B19 DNA [Presence] in Body fluid by NAA with probe detection | 0.933 |  |
| 3042596 | Human coronavirus RNA [Presence] in Specimen by NAA with probe detection | 0.931 |  |
| 40765216 | Aspergillus terreus DNA [Presence] in Specimen by NAA with probe detection | 0.931 |  |
| 3964934 | Sapovirus genogroups I+II+IV RNA [Presence] in Stool by NAA with probe detection | 0.930 |  |
| 646396 | Aspergillus sp DNA [#/volume] in Specimen by NAA with probe detection | 0.930 |  |
| 37020776 | Human coronavirus 229E+NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.930 |  |
| 3030429 | Borrelia sp DNA [Identifier] in Specimen by NAA with probe detection | 0.930 |  |
| 36305386 | Human coronavirus HKU1 RNA [Presence] in Aspirate by NAA with probe detection | 0.928 |  |
| 36304729 | Human coronavirus OC43 RNA [Presence] in Aspirate by NAA with probe detection | 0.928 |  |
| 21493147 | Human coronavirus 229E RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.928 |  |
| 21493331 | Human coronavirus NL63 RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.928 |  |
| 21493467 | Salmonella enterica+bongori DNA [Presence] in Stool by NAA with non-probe detection | 0.924 |  |
| 37020957 | Sapovirus genogroups I+II+IV+V RNA [Presence] in Stool by NAA with probe detection | 0.924 |  |
| 3025310 | Parvovirus B19 RNA [Presence] in Specimen by NAA with probe detection | 0.922 |  |
| 3032785 | Parvovirus B19 DNA [Presence] in Bone marrow by NAA with probe detection | 0.922 |  |
| 21492661 | Salmonella sp rpoD gene [Presence] in Stool by NAA with probe detection | 0.921 |  |
| 3028977 | Parvovirus B19 DNA [Presence] in Urine by NAA with probe detection | 0.920 |  |
| 21493330 | Human coronavirus HKU1 RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.920 |  |
| 1091349 | Aspergillus niger DNA [Presence] in Specimen by NAA with probe detection | 0.919 |  |
| 3024482 | Parvovirus B19 RNA [Presence] in Tissue by NAA with probe detection | 0.917 |  |
| 3044820 | Borrelia burgdorferi DNA [Presence] in Blood by NAA with probe detection | 0.914 |  |
| 21493559 | Salmonella sp invA+fliC genes [Presence] in Stool by NAA with probe detection | 0.911 |  |
| 1091185 | Human bocavirus 1+2+3+4 DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.911 |  |
| 21493481 | Sapovirus genogroups I+II+IV+V RNA [Presence] in Stool by NAA with non-probe detection | 0.911 |  |
| 3007217 | Salmonella pullorum DNA [Presence] in Specimen by NAA with probe detection | 0.911 |  |
| 37021321 | Human bocavirus 1+2+3 DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.910 |  |
| 1001596 | Salmonella sp DNA [Presence] by NAA with probe detection in Positive blood culture | 0.908 |  |
| 21493883 | Salmonella sp spaO gene [Presence] in Stool by NAA with probe detection | 0.908 |  |
| 3015220 | Salmonella gallinarum DNA [Presence] in Specimen by NAA with probe detection | 0.904 |  |
| 3008909 | Norovirus RNA [Presence] in Stool by NAA with probe detection | 0.902 |  |
| 1176317 | Borrelia sp DNA [Presence] in Tick by NAA with probe detection | 0.901 |  |
| 46235156 | Parvovirus B19 DNA [Presence] in Plasma from Donor by NAA with probe detection | 0.900 |  |
| 21492668 | Gastrointestinal pathogens identified in Stool by NAA with probe detection | 0.900 |  |
| 3966163 | Shigella sp DNA [Presence] in Stool by NAA with probe detection | 0.897 |  |
| 1259546 | Borrelia recurrentis DNA [Presence] in Specimen by NAA with probe detection | 0.896 |  |
| 3966671 | Aeromonas sp DNA [Presence] in Stool by NAA with probe detection | 0.895 |  |
| 36032369 | Salmonella sp DNA [Presence] by NAA with non-probe detection in Positive blood culture | 0.892 |  |
| 1469493 | Salmonella sp DNA [Presence] in Body fluid by NAA with non-probe detection | 0.892 |  |
| 1259661 | Salmonella paratyphi DNA [Presence] in Isolate by NAA with probe detection | 0.891 |  |
| 36304443 | Parechovirus RNA [Presence] in Stool by NAA with probe detection | 0.890 |  |
| 42868767 | Plesiomonas shigelloides DNA [Presence] in Stool by NAA with probe detection | 0.888 |  |
| 1260098 | Salmonella typhi DNA [Presence] in Isolate by NAA with probe detection | 0.888 |  |
| 3035492 | Borrelia burgdorferi DNA [Presence] in Tissue by NAA with probe detection | 0.888 |  |
| 3037610 | Borrelia burgdorferi DNA [Presence] in Body fluid by NAA with probe detection | 0.885 |  |
| 37020058 | Rotavirus A RNA [Presence] in Stool by NAA with probe detection | 0.882 |  |
| 647461 | Rotavirus RNA [Presence] in Stool by NAA with probe detection | 0.880 |  |
| 37020445 | Astrovirus RNA [Presence] in Stool by NAA with probe detection | 0.878 |  |
| 1092075 | Human bocavirus 1+2+3+4 DNA [Presence] in Bronchoalveolar lavage by NAA with probe detection | 0.875 |  |
| 1092116 | Bacteria DNA [Presence] in Specimen by NAA with probe detection | 0.868 |  |
| 1092353 | Enteric parasite panel - Stool by NAA with probe detection | 0.867 |  |
| 21493881 | Respiratory pathogens DNA and RNA identified in Respiratory system specimen by NAA with probe detection | 0.864 |  |
| 36303358 | Gastrointestinal pathogens identified in Specimen by NAA with probe detection | 0.863 |  |
| 1988643 | Escherichia coli K1 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.847 |  |
| 1988894 | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.844 |  |
| 46234881 | Bacterial 16S rRNA [Presence] in Specimen by NAA with probe detection | 0.835 |  |
| 3001391 | Mycobacterium sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.832 |  |
| 1988744 | Listeria monocytogenes DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.831 |  |
| 1175944 | Helminth identified in Specimen by NAA with probe detection | 0.830 |  |
| 3027247 | Bacteria identified in Specimen | 0.830 |  |
| 37021149 | Gastrointestinal parasitic pathogens panel - Stool by NAA with probe detection | 0.829 |  |
| 1469649 | Campylobacter sp DNA [Presence] in Stool by NAA with probe detection | 0.826 |  |
| 1091951 | Staphylococcus sp DNA [Presence] in Specimen by NAA with probe detection | 0.824 |  |
| 1988899 | Streptococcus pneumoniae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.823 |  |
| 1989596 | Streptococcus pyogenes DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.823 |  |
| 21493389 | Respiratory pathogens identified [Type] in Nasopharynx by NAA with probe detection | 0.822 |  |
| 649062 | Plesiomonas shigelloides and aeromonas sp DNA [Identifier] in Stool by NAA with probe detection | 0.822 |  |
| 1092255 | Campylobacter sp DNA [Identifier] in Stool by NAA with probe detection | 0.820 |  |
| 1988730 | Neisseria meningitidis DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.820 |  |
| 3966224 | Campylobacter upsaliensis DNA [Presence] in Stool by NAA with probe detection | 0.819 |  |
| 21493195 | Respiratory pathogens DNA and RNA tested for in Respiratory system specimen by NAA with probe detection | 0.818 |  |
| 1616308 | Escherichia coli enteropathogenic DNA [Presence] in Stool by NAA with probe detection | 0.818 |  |
| 645848 | Vibrio sp DNA [Identifier] in Stool by NAA with probe detection | 0.816 |  |
| 3966166 | Staphylococcus aureus DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.816 |  |
| 36305477 | Microsporidia DNA [Presence] in Stool by NAA with probe detection | 0.815 |  |
| 21493348 | Escherichia coli K1 DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.814 |  |
| 3049510 | Pseudomonas sp DNA [Identifier] in Specimen by NAA with probe detection | 0.812 |  |
| 21493352 | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.809 |  |
| 40764159 | Escherichia coli DNA [Presence] in Specimen by NAA with probe detection | 0.808 |  |
| 36305992 | Strongyloides stercoralis DNA [Presence] in Stool by NAA with probe detection | 0.808 |  |
| 1092209 | Streptococcus sp DNA [Presence] in Specimen by NAA with probe detection | 0.808 |  |
| 3016914 | Bacteria identified in Cerebral spinal fluid by Culture | 0.808 | 561 |
| 36659989 | Staphylococcus aureus DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.807 |  |
| 37020998 | Streptococcus pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.807 |  |
| 37020598 | Moraxella catarrhalis DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.807 |  |
| 1091462 | Aerococcus viridans DNA [Presence] in Specimen by NAA with probe detection | 0.805 |  |
| 3049944 | XXX microorganism DNA [Identifier] in Specimen by NAA with probe detection | 0.804 |  |
| 3025929 | Taenia sp eggs [Presence] in Stool by NAA with probe detection | 0.800 |  |
| 37020937 | Giardia lamblia DNA [Presence] in Stool by NAA with probe detection | 0.795 |  |
| 42868763 | Blastocystis hominis DNA [Presence] in Stool by NAA with probe detection | 0.788 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1134 | -aspenho |  | 100% | name | 680 | 100 |  | -Aspergillus, nukleiinihappo (kval) |  |  | Aspergillus sp DNA [Presence] in Specimen by NAA with probe detection |
| 1135 | -baktnho |  | 100% | name | 14771 | 100 |  | -Bakteeri, nukleiinihappo (kval) |  |  | Bacteria identified in Specimen by NAA with probe detection |
| 1136 | -bocanho |  | 100% | name | 1008 | 100 |  |  |  |  | Human bocavirus DNA [Presence] in Specimen by NAA with probe detection |
| 1137 | -bokanho |  | 100% | name | 13005 | 100 |  | -Bokavirus, nukleiinihappo (kval) |  |  | Human bocavirus DNA [Presence] in Specimen by NAA with probe detection |
| 1138 | -bopanho |  | 100% | name | 1739 | 100 |  |  |  |  | Bordetella pertussis DNA [Presence] in Specimen by NAA with probe detection |
| 1139 | -bopenho |  | 100% | name | 12052 | 100 |  | -Bordetella pertussis, nukleiinihappo (kval) |  |  | Bordetella pertussis DNA [Presence] in Specimen by NAA with probe detection |
| 1140 | -bopenho. |  | 100% | name | 1314 | 100 |  |  |  |  | Bordetella pertussis DNA [Presence] in Specimen by NAA with probe detection |
| 1141 | -boppnho |  | 100% | name | 3753 | 100 |  |  |  |  | Bordetella pertussis+Bordetella parapertussis DNA [Presence] in Specimen by NAA with probe detection |
| 1142 | -borrnho |  | 100% | name | 1762 | 100 |  | -Borrelia, nukleiinihappo (kval) |  |  | Borrelia sp DNA [Presence] in Specimen by NAA with probe detection |
| 1143 | -bparnho |  | 100% | name | 314 | 100 |  |  |  |  | Bordetella parapertussis DNA [Presence] in Specimen by NAA with probe detection |
| 1144 | -rbaktnho |  | 100% | name | 4646 | 100 |  |  |  |  | Bacteria identified in Respiratory specimen by NAA with probe detection |
| 1145 | baktnho |  | 100% | name | 328 | 100 |  |  |  |  | Bacteria identified in Specimen by NAA with probe detection |
| 1146 | bokanho |  | 100% | name | 222 | 100 |  |  |  |  | Human bocavirus DNA [Presence] in Specimen by NAA with probe detection |
| 1147 | bopenho |  | 100% | name | 608 | 100 |  |  |  |  | Bordetella pertussis DNA [Presence] in Specimen by NAA with probe detection |
| 1148 | bparanho |  | 100% | name | 1650 | 100 |  |  |  |  | Bordetella parapertussis DNA [Presence] in Specimen by NAA with probe detection |
| 1149 | f-baktnho |  | 100% | name | 17469 | 100 |  |  | Feces |  | Bacteria identified in Stool by NAA with probe detection |
| 1150 | f-paranho |  | 100% | name | 14240 | 99.99 |  | F -Parasiitit, nukleiinihappo (kval) | Feces |  | Parasites identified in Stool by NAA with probe detection |
| 1151 | f-salmnho |  | 100% | name | 2354 | 100 |  | F -Salmonella, nukleiinihappo (kval) | Feces |  | Salmonella sp DNA [Presence] in Stool by NAA with probe detection |
| 1152 | f-saponho |  | 100% | name | 4057 | 100 |  | F -Sapovirus, nukleiinihappo (kval) | Feces |  | Sapovirus RNA [Presence] in Stool by NAA with probe detection |
| 1153 | kv229enho |  | 100% | name | 5976 | 100 |  |  |  |  | Human coronavirus 229E RNA [Presence] in Specimen by NAA with probe detection |
| 1154 | kvhku1nho |  | 100% | name | 537 | 100 |  |  |  |  | Human coronavirus HKU1 RNA [Presence] in Specimen by NAA with probe detection |
| 1155 | kvnl63nho |  | 100% | name | 5975 | 100 |  |  |  |  | Human coronavirus NL63 RNA [Presence] in Specimen by NAA with probe detection |
| 1156 | kvoc43nho |  | 100% | name | 5977 | 100 |  |  |  |  | Human coronavirus OC43 RNA [Presence] in Specimen by NAA with probe detection |
| 1157 | li-baktnho |  | 100% | name | 268 | 100 |  | Li-Bakteeri, nukleiinihappo (kval) | Cerebrospinal fluid |  | Bacteria identified in Cerebral spinal fluid by NAA with probe detection |
| 1158 | resbaktnho |  | 100% | name | 770 | 100 |  |  |  |  | Bacteria identified in Respiratory specimen by NAA with probe detection |
| 1159 | s-parvnho |  | 100% | name | 208 | 99.04 |  | S -Parvovirus, nukleiinihappo (kval) | Serum |  | Parvovirus B19 DNA [Presence] in Serum by NAA with probe detection |
| 1160 | salmnho |  | 100% | name | 8183 | 100 |  |  |  |  | Salmonella sp DNA [Presence] in Specimen by NAA with probe detection |

