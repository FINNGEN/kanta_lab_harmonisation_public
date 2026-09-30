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
Here is group 73.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 37021252 | Influenza virus B RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.983 |  |
| 37020335 | Parainfluenza virus 4 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.980 |  |
| 3038297 | Parainfluenza virus 4 RNA [Presence] in Specimen by NAA with probe detection | 0.980 |  |
| 3012158 | Parainfluenza virus 2 RNA [Presence] in Specimen by NAA with probe detection | 0.978 |  |
| 40764126 | Parainfluenza virus RNA [Presence] in Specimen by NAA with probe detection | 0.977 |  |
| 37019747 | Rhinovirus RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.977 |  |
| 3025023 | Rhinovirus RNA [Presence] in Specimen by NAA with probe detection | 0.977 |  |
| 37020003 | Rhinovirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.977 |  |
| 37021465 | Parainfluenza virus 3 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.977 |  |
| 3038288 | Influenza virus B RNA [Presence] in Specimen by NAA with probe detection | 0.976 |  |
| 3025634 | Parainfluenza virus 1 RNA [Presence] in Specimen by NAA with probe detection | 0.976 |  |
| 40765199 | Influenza virus A+B RNA [Presence] in Specimen by NAA with probe detection | 0.976 |  |
| 3006262 | Parainfluenza virus 3 RNA [Presence] in Specimen by NAA with probe detection | 0.976 |  |
| 37019589 | Parainfluenza virus 1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.975 |  |
| 3965803 | Influenza virus A+B RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.975 |  |
| 37020635 | Influenza virus A RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.975 |  |
| 37019613 | Parainfluenza virus 2 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.975 |  |
| 37019984 | Parainfluenza virus 4 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.973 |  |
| 37020338 | Haemophilus influenzae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.973 |  |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.972 |  |
| 40764127 | Haemophilus influenzae DNA [Presence] in Specimen by NAA with probe detection | 0.972 |  |
| 36203322 | Influenza virus B RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.971 |  |
| 3044938 | Influenza virus A RNA [Presence] in Specimen by NAA with probe detection | 0.970 |  |
| 37019976 | Parainfluenza virus 3 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.969 |  |
| 37021346 | Parainfluenza virus 2 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.969 |  |
| 36203321 | Influenza virus A RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.968 |  |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.968 |  |
| 1091113 | Influenza virus B RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.967 |  |
| 40770419 | Parainfluenza virus 4a RNA [Presence] in Specimen by NAA with probe detection | 0.966 |  |
| 36304298 | Parainfluenza virus 4 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.965 |  |
| 37020881 | Parainfluenza virus 1 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.965 |  |
| 36304319 | Parainfluenza virus 2 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.965 |  |
| 40770420 | Parainfluenza virus 4b RNA [Presence] in Specimen by NAA with probe detection | 0.965 |  |
| 1091251 | Parainfluenza virus 4 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.964 |  |
| 37019554 | Parainfluenza virus RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.964 |  |
| 36305681 | Parainfluenza virus 1 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.963 |  |
| 36303784 | Parainfluenza virus 3 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.963 |  |
| 36304620 | Parainfluenza virus RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.962 |  |
| 36304919 | Influenza virus B RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.962 |  |
| 36660466 | Haemophilus influenzae DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.962 |  |
| 1091605 | Influenza virus A+B RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.960 |  |
| 1092023 | Parainfluenza virus 3 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.960 |  |
| 1469884 | Haemophilus influenzae DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.957 |  |
| 1091557 | Rhinovirus RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.957 |  |
| 36305662 | Influenza virus A RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.957 |  |
| 3024270 | Haemophilus influenzae A DNA [Presence] in Specimen by NAA with probe detection | 0.957 |  |
| 1091967 | Parainfluenza virus 2 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.956 |  |
| 645902 | Parainfluenza virus 4 RNA [Presence] in Specimen by NAA with non-probe detection | 0.955 |  |
| 1091332 | Parainfluenza virus 1 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.955 |  |
| 1091443 | Influenza virus A RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.954 |  |
| 36660474 | Parainfluenza virus 4 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.954 |  |
| 3966116 | Influenza virus A H1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.954 |  |
| 1988089 | Influenza virus A N1 RNA [Presence] in Specimen by NAA with probe detection | 0.953 |  |
| 1175203 | Rhinovirus RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.953 |  |
| 1092106 | Parainfluenza virus RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.951 |  |
| 646127 | Influenza virus B RNA [Presence] in Specimen by NAA with non-probe detection | 0.950 |  |
| 36659829 | Parainfluenza virus 3 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.949 |  |
| 648164 | Haemophilus influenzae E DNA [Presence] in Specimen by NAA with probe detection | 0.949 |  |
| 647882 | Parainfluenza virus 3 RNA [Presence] in Specimen by NAA with non-probe detection | 0.948 |  |
| 36660164 | Parainfluenza virus 1 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.948 |  |
| 645732 | Haemophilus influenzae D DNA [Presence] in Specimen by NAA with probe detection | 0.947 |  |
| 649183 | Haemophilus influenzae F DNA [Presence] in Specimen by NAA with probe detection | 0.947 |  |
| 649299 | Parainfluenza virus 1 RNA [Presence] in Specimen by NAA with non-probe detection | 0.947 |  |
| 37021109 | Influenza virus B RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.946 |  |
| 645627 | Parainfluenza virus 2 RNA [Presence] in Specimen by NAA with non-probe detection | 0.945 |  |
| 647158 | Influenza virus A RNA [Presence] in Specimen by NAA with non-probe detection | 0.944 |  |
| 36660052 | Parainfluenza virus 2 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.942 |  |
| 40763309 | Parainfluenza virus 1+2+3 RNA [Presence] in Specimen by NAA with probe detection | 0.939 |  |
| 1092357 | Rhinovirus RNA [Presence] in Sputum by NAA with probe detection | 0.938 |  |
| 3965820 | Human Rhinovirus 1 and 2 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.938 |  |
| 37020005 | Parainfluenza virus RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.938 |  |
| 46236735 | Rhinovirus RNA [Presence] in Nasopharynx by NAA with probe detection | 0.938 |  |
| 1091244 | Influenza virus A+B RNA [Presence] in Sputum by NAA with probe detection | 0.937 |  |
| 46235765 | Parainfluenza virus 3 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.937 |  |
| 3965123 | Human Rhinovirus 2 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.936 |  |
| 1091221 | Influenza virus B RNA [Presence] in Sputum by NAA with probe detection | 0.935 |  |
| 46235764 | Parainfluenza virus 2 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.935 |  |
| 3024794 | Haemophilus influenzae B DNA [Presence] in Specimen by NAA with probe detection | 0.935 |  |
| 1469891 | Influenza virus A+B RNA [Presence] in Nasopharynx by NAA with probe detection | 0.933 |  |
| 1091209 | Haemophilus influenzae DNA [Presence] in Nasopharynx by NAA with probe detection | 0.933 |  |
| 46235759 | Influenza virus B RNA [Presence] in Nasopharynx by NAA with probe detection | 0.932 |  |
| 37020197 | Influenza virus A H1 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.930 |  |
| 37019683 | Rhinovirus+Enterovirus RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.930 |  |
| 37020237 | Influenza virus A subtype [Identifier] in Upper respiratory specimen by NAA with probe detection | 0.929 |  |
| 3020346 | Influenza virus A subtype [Identifier] in Specimen by NAA with probe detection | 0.916 |  |
| 1175638 | Influenza virus A subtype [Identifier] in Lower respiratory specimen by NAA with probe detection | 0.913 |  |
| 37020181 | Influenza virus types A and B panel - Upper respiratory specimen by NAA with probe detection | 0.904 |  |
| 21494892 | Influenza virus types A and B and subtypes RNA panel - Respiratory system specimen by NAA with probe detection | 0.890 |  |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.890 |  |
| 36304096 | Influenza virus types A and B panel - Lower respiratory specimen by NAA with probe detection | 0.889 |  |
| 1617384 | Influenza virus types A and B and subtypes RNA panel - Specimen by NAA with probe detection | 0.875 |  |
| 40762514 | Influenza virus A hemagglutinin type RNA [Identifier] in Specimen by NAA with probe detection | 0.873 |  |
| 36661376 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.871 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1104 | -hinfnho |  | 100% | name | 311 | 100 |  |  |  |  | Haemophilus influenzae DNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1105 | -hinnho |  | 100% | name | 3618 | 100 |  |  |  |  |  |
| 1106 | -inabnho |  | 100% | name | 4313 | 100 |  | -Influenssa A ja B-virus, nukleiinihappo (kval) |  |  | Influenza virus A+B RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1107 | -inabnhoho |  | 100% | name | 387 | 100 |  |  |  |  | Influenza virus A+B RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1108 | -inabrsnho |  | 100% | name | 432 | 100 |  |  |  |  | Influenza virus A+B and Respiratory syncytial virus RNA panel - Respiratory specimen by NAA with probe detection |
| 1109 | -inanho |  | 100% | name | 356 | 100 |  |  |  |  | Influenza virus A RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1110 | -inanhoho |  | 100% | name | 409 | 100 |  |  |  |  | Influenza virus A RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1111 | -inbnho |  | 100% | name | 356 | 100 |  |  |  |  | Influenza virus B RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1112 | -inbnhoho |  | 100% | name | 411 | 100 |  |  |  |  | Influenza virus B RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1113 | -infanho |  | 100% | name | 122873 | 100 |  | -Influenssa A -virus, nukleiinihappo (kval) |  |  | Influenza virus A RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1114 | -infbnho |  | 100% | name | 95902 | 100 |  | -Influenssa B-virus, nukleiinihappo (kval) |  |  | Influenza virus B RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1115 | -infvnho |  | 100% | name | 1260 | 100 |  | -Influenssa A-virus, variantti, nukleiinihappo (kval) |  |  | Influenza virus A subtype identified in Respiratory specimen by NAA with probe detection |
| 1116 | -pin1nho |  | 100% | name | 9246 | 100 |  | -Parainfluenssa 1-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 1 RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1117 | -pin2nho |  | 100% | name | 9244 | 100 |  | -Parainfluenssa 2-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 2 RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1118 | -pin3nho |  | 100% | name | 9240 | 100 |  | -Parainfluenssa 3-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 3 RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1119 | -pin4nho |  | 100% | name | 9240 | 100 |  | -Parainfluenssa 4-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 4 RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1120 | -pinfnho |  | 100% | name | 5018 | 100 |  |  |  |  | Parainfluenza virus RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1121 | -rinonho |  | 100% | name | 7403 | 100 |  | -Rinovirus, nukleiinihappo (kval) |  |  | Rhinovirus RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1122 | -tintnho |  | 100% | name | 595 | 100 |  |  |  |  |  |
| 1123 | hinflnho |  | 100% | name | 745 | 100 |  |  |  |  | Haemophilus influenzae DNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1124 | inanho |  | 100% | name | 7494 | 100 |  |  |  |  | Influenza virus A RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1125 | inbnho |  | 100% | name | 7494 | 100 |  |  |  |  | Influenza virus B RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1126 | infanho |  | 100% | name | 12417 | 100 |  |  |  |  | Influenza virus A RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1127 | infbnho |  | 100% | name | 34660 | 100 |  |  |  |  | Influenza virus B RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1128 | infnho |  | 100% | name | 766 | 100 |  |  |  |  | Influenza virus RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1129 | pin1nho |  | 100% | name | 4037 | 100 |  |  |  |  | Parainfluenza virus 1 RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1130 | pin2nho |  | 100% | name | 4036 | 100 |  |  |  |  | Parainfluenza virus 2 RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1131 | pin3nho |  | 100% | name | 4036 | 100 |  |  |  |  | Parainfluenza virus 3 RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1132 | pin4nho |  | 100% | name | 4034 | 100 |  |  |  |  | Parainfluenza virus 4 RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1133 | rinonho |  | 100% | name | 245 | 100 |  |  |  |  | Rhinovirus RNA [Presence] in Respiratory specimen by NAA with probe detection |

