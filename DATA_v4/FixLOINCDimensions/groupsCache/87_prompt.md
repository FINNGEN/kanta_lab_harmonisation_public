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
Here is group 87.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3017281 | Microscopic observation [Identifier] in Tissue by Electron microscopy thin sectiion | 0.967 |  |
| 3037320 | Microscopic observation [Identifier] in Specimen by Immunofluorescence | 0.948 |  |
| 3044928 | Microscopic observation [Identifier] in Specimen by Electron microscopy | 0.921 |  |
| 40758733 | Microscopic observation [Identifier] in Endometrium by Cyto stain | 0.905 |  |
| 3025378 | Microscopic observation [Identifier] in Cervix by Cyto stain | 0.900 | 484 |
| 3036910 | Microscopic observation [Identifier] in Tissue by Trichrome stain | 0.899 | 894 |
| 3011173 | Microscopic observation [Identifier] in Tissue by Hematoxylin and eosin stain | 0.898 |  |
| 3006864 | Microscopic observation [Identifier] in Tissue by Tetrachrome stain | 0.897 |  |
| 3021339 | Microscopic observation [Identifier] in Tissue by Wright Giemsa stain | 0.891 |  |
| 3021269 | Microscopic observation [Identifier] in Tissue by Other stain | 0.891 |  |
| 3024198 | Microscopic observation [Identifier] in Tissue by Giemsa stain | 0.890 |  |
| 3014979 | Microscopic observation [Identifier] in Tissue by Wet preparation | 0.887 |  |
| 3022667 | Microscopic observation [Identifier] in Cervix by Wet preparation | 0.887 |  |
| 3050931 | Microscopic observation [Identifier] in Endometrium by Rhodamine-auramine fluorochrome stain | 0.883 |  |
| 3002208 | Microscopic observation [Identifier] in Prostate fine needle aspirate by Cyto stain | 0.879 |  |
| 3014155 | Microscopic observation [Identifier] in Tissue by Quinacrine fluorescent stain | 0.878 |  |
| 3004240 | Microscopic observation [Identifier] in Tissue by Supravital stain | 0.878 |  |
| 3002202 | Microscopic observation [Identifier] in Tissue by Dark field examination | 0.876 |  |
| 3018006 | Microscopic observation [Identifier] in Cervix by Cyto stain.thin prep | 0.876 | 1048 |
| 3035330 | Microscopic observation [Identifier] in Cervix by Other stain | 0.872 |  |
| 3001529 | Microscopic observation [Identifier] in Cervix by Gram stain | 0.869 |  |
| 3025156 | Microscopic observation [Identifier] in Cervical or vaginal smear or scraping by Cyto stain | 0.869 |  |
| 3007738 | Microscopic observation [Identifier] in Breast fine needle aspirate by Cyto stain | 0.866 |  |
| 36305844 | Microscopic observation [Identifier] in Cervix by Acid fast stain | 0.862 |  |
| 3025991 | Microscopic observation [Identifier] in Cervical or vaginal smear or scraping by Cyto stain Narrative | 0.860 |  |
| 3005656 | Microscopic observation [Identifier] in Tissue by Rhodamine-auramine fluorochrome stain | 0.858 |  |
| 3000130 | Microscopic observation [Identifier] in Cervix by KOH preparation | 0.857 |  |
| 3049840 | Microscopic observation [Identifier] in Endocervical brush by Cyto stain | 0.849 | 750 |
| 3026439 | Microscopic observation [Identifier] in Tissue by Cyto stain | 0.847 |  |
| 3025027 | Microscopic observation [Identifier] in Tissue by Gimenez stain | 0.846 |  |
| 3006595 | Microscopic observation [Identifier] in Genital specimen by Wet preparation | 0.845 |  |
| 37019823 | Microscopic observation [Identifier] in Genital specimen by Giemsa stain | 0.844 |  |
| 3005428 | Microscopic observation [Identifier] in Tissue by Bielschowsky stain | 0.840 |  |
| 1091136 | Microscopic observation [Identifier] in Specimen | 0.838 |  |
| 3007222 | Microscopic observation [Identifier] in Tissue by Silver stain | 0.837 |  |
| 3021466 | Microscopic observation [Identifier] in Vaginal fluid by Wet preparation | 0.836 |  |
| 3024587 | Microscopic observation [Identifier] in Tissue by Acridine orange stain | 0.834 |  |
| 3000855 | Microscopic observation [Identifier] in Vaginal fluid by Gram stain | 0.830 |  |
| 3019614 | Amyloid.prealbumin Ag [Presence] in Tissue by Immune stain | 0.830 |  |
| 3018559 | Microscopic observation [Identifier] in Buccal smear by Cyto stain | 0.827 |  |
| 3001057 | Microscopic observation [Identifier] in Genital mucus by Gram stain | 0.827 |  |
| 3048285 | Microscopic observation [Identifier] in Genital specimen by Gram stain | 0.825 |  |
| 36304856 | Microscopic observation [Identifier] in Cerebral spinal fluid by Giemsa stain | 0.825 |  |
| 3036272 | Microscopic observation [Identifier] in Genital fluid by Gram stain | 0.825 |  |
| 3025428 | Microscopic observation [Identifier] in Cerebral spinal fluid | 0.820 |  |
| 3036801 | Microscopic observation [Identifier] in Tissue by Periodic acid-Schiff stain with diastase digestion | 0.819 |  |
| 3037998 | Microscopic observation [Identifier] in Specimen by Hematoxylin and eosin stain | 0.817 |  |
| 1469614 | Amyloid Beta Ag [Presence] in Tissue by Immune stain | 0.814 |  |
| 3965650 | Amyloid protein in Tissue Document | 0.813 |  |
| 3011798 | Microscopic observation [Identifier] in Tissue by Mucicarmine stain | 0.812 |  |
| 3000050 | Microscopic observation [Identifier] in Tissue by Toluidine blue O stain | 0.811 |  |
| 3020314 | Microscopic observation [Identifier] in Tissue by Fite-Faraco stain | 0.809 |  |
| 3001977 | Microscopic observation [Identifier] in Tissue by Hematoxylin-eosin-Mayers progressive stain | 0.807 |  |
| 3020521 | Microscopic observation [Identifier] in Tissue by Periodic acid-Schiff stain | 0.807 |  |
| 3036843 | Microscopic observation [Identifier] in Soft tissue fine needle aspirate by Cyto stain | 0.807 |  |
| 3006413 | Microscopic observation [Identifier] in Nipple discharge by Cyto stain | 0.803 |  |
| 3017672 | Microscopic observation [Identifier] in Gastric fluid by Cyto stain | 0.803 |  |
| 3019634 | Microscopic observation [Identifier] in Tissue by Wright stain | 0.802 |  |
| 3031354 | Microscopic observation [Identifier] in Cerebral spinal fluid by Cyto stain | 0.802 |  |
| 3003539 | Microscopic observation [Identifier] in Tissue by Bodian stain | 0.802 |  |
| 3014500 | Microscopic observation [Identifier] in Deep tissue fine needle aspirate by Cyto stain | 0.799 |  |
| 3020068 | Microscopic observation [Identifier] in Duodenal fluid by Trichrome stain | 0.799 |  |
| 3004993 | Microscopic observation [Identifier] in Superficial tissue fine needle aspirate by Cyto stain | 0.799 |  |
| 3035975 | Microscopic observation [Identifier] in Neck mass fine needle aspirate by Cyto stain | 0.798 |  |
| 3005280 | Beta-2-Microglobulin amyloid Ag [Presence] in Tissue by Immune stain | 0.797 |  |
| 3036321 | Microscopic observation [Identifier] in Submandibular fine needle aspirate by Cyto stain | 0.796 |  |
| 3011035 | Amyloid A component Ag [Presence] in Tissue by Immune stain | 0.784 |  |
| 3021450 | Screening techniques [Identifier] in Cervical or vaginal smear or scraping by Cyto stain | 0.774 |  |
| 3020271 | Microscopic observation [Identifier] in Pelvis fine needle aspirate by Cyto stain | 0.772 |  |
| 3014667 | Amyloid P component Ag [Presence] in Tissue by Immune stain | 0.771 |  |
| 3038224 | Microscopic observation [Identifier] in Urine sediment by Light microscopy | 0.768 | 339 |
| 3028494 | Microscopic observation [Identifier] in Tissue by Dry mount | 0.746 |  |
| 21494148 | Amyloid A [Mass/mass] in Tissue | 0.744 |  |
| 3006313 | Specimen source [Identifier] in Cervical or vaginal smear or scraping by Cyto stain | 0.741 | 110 |
| 1091494 | Microscopic observation [Identifier] in Cervix by Cyto stain.thin prep.computer assisted | 0.731 |  |
| 3030411 | Alzheimer precursor protein Ag [Presence] in Tissue by Immune stain | 0.728 |  |
| 3020283 | Immunoglobulin light chains.lambda amyloid Ag [Presence] in Tissue by Immune stain | 0.726 |  |
| 3007354 | Amyloid.microscopic observation [Identifier] in Tissue by Highman stain | 0.725 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1385 | 4043ts-padgast |  | 100% | name | 822 | 100 |  |  |  |  | Microscopic observation [Identifier] in Stomach tissue by Light microscopy |
| 1386 | 4044pt-papa-1 |  | 100% | name | 956 | 100 |  |  |  |  | Papanicolaou smear [Identifier] in Cervical or vaginal specimen by Light microscopy |
| 1387 | 4054ts-pad-1 |  | 100% | name | 2636 | 100 |  |  |  |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1388 | 4056ts-pad-3 |  | 100% | name | 1048 | 100 |  |  |  |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1389 | 4191ts-pad-ih |  | 100% | name | 722 | 100 |  |  |  | Immunohistochemical | Microscopic observation [Identifier] in Tissue by Immunohistochemistry |
| 1390 | 4194ts-pad-4 |  | 100% | name | 211 | 100 |  |  |  |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1391 | 4764ts-padcolo |  | 100% | name | 911 | 100 |  |  |  |  | Microscopic observation [Identifier] in Colon tissue by Light microscopy |
| 1392 | 6388ts-padkolp |  | 100% | name | 110 | 100 |  |  |  |  | Microscopic observation [Identifier] in Cervix tissue by Light microscopy |
| 1393 | 6389ts-padendo |  | 100% | name | 184 | 100 |  |  |  |  | Microscopic observation [Identifier] in Endometrium tissue by Light microscopy |
| 1394 | ts-aa-o |  | 100% | name | 243 | 100 |  | Ts-Amyloidi (kval) | Tissue | Qualitative test (also semi-quantitative) | Amyloid [Presence] in Tissue |
| 1395 | ts-pad |  | 100% | name | 7322 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1396 | ts-pad-0 |  | 100% | name | 1166 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1397 | ts-pad-0-u |  | 100% | name | 192 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1398 | ts-pad-1 | form | 0% | name+unit | 14 | 0 |  | Ts-Kudosnäytteen histologinen tutkimus, 1-3 eriteltyä pientä näytettä, samaan kokonaisuuteen kuuluvia | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1399 | ts-pad-1 |  | 100% | name | 260747 | 100 |  | Ts-Kudosnäytteen histologinen tutkimus, 1-3 eriteltyä pientä näytettä, samaan kokonaisuuteen kuuluvia | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1400 | ts-pad-1co |  | 100% | name | 3927 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Colon tissue by Light microscopy |
| 1401 | ts-pad-1tk |  | 100% | name | 525 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1402 | ts-pad-1tu |  | 100% | name | 1837 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1403 | ts-pad-1x2 |  | 100% | name | 118 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1404 | ts-pad-1x3 |  | 100% | name | 271 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1405 | ts-pad-2 |  | 100% | name | 10491 | 100 |  | Ts-Kudosnäytteen histologinen tutkimus, 4 tai useampia eriteltyjä pieniä näytteitä | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1406 | ts-pad-2tu |  | 100% | name | 299 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1407 | ts-pad-3 |  | 100% | name | 77691 | 100 |  | Ts-Kudosnäytteen histologinen tutkimus, suppea leikkauspreparaatti | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1408 | ts-pad-3co |  | 100% | name | 176 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Colon tissue by Light microscopy |
| 1409 | ts-pad-3tu |  | 100% | name | 1602 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1410 | ts-pad-4 |  | 100% | name | 33705 | 100 |  | Ts-Kudosnäytteen histologinen tutkimus, laaja leikkauspreparaatti | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1411 | ts-pad-4tu |  | 100% | name | 4673 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1412 | ts-pad-5 |  | 100% | name | 5039 | 100 |  | Ts-Erittäin laaja histologinen tutkimus tai monielinkudospreparaatti | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1413 | ts-pad-5tu |  | 100% | name | 11310 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1414 | ts-pad-bio |  | 100% | name | 6876 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1415 | ts-pad-em |  | 100% | name | 106 | 100 |  | Ts-Kudosnäyte, elektronimikroskooppinen tutkimus | Tissue | Electron microscopic | Microscopic observation [Identifier] in Tissue by Electron microscopy |
| 1416 | ts-pad-ev |  | 100% | name | 9091 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1417 | ts-pad-if |  | 100% | name | 296 | 100 |  | Ts-Kudosnäyte, immunofluoresenssitutkimus | Tissue | Immunofluorescence | Microscopic observation [Identifier] in Tissue by Immunofluorescence |
| 1418 | ts-pad-ih |  | 100% | name | 53523 | 100 |  | Ts-Kudosnäyte, immunohistokemiallinen tutkimus | Tissue | Immunohistochemical | Microscopic observation [Identifier] in Tissue by Immunohistochemistry |
| 1419 | ts-pad-ih2 |  | 100% | name | 308 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Immunohistochemistry |
| 1420 | ts-pad-ihu |  | 100% | name | 137 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Immunohistochemistry |
| 1421 | ts-pad-ish |  | 100% | name | 3661 | 100 |  | Ts-Kudosnäyte, in situ-hybridisaatiotutkimus | Tissue | In situ hybridization | Microscopic observation [Identifier] in Tissue by In situ hybridization |
| 1422 | ts-pad-lau |  | 100% | name | 536 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1423 | ts-pad-pnb |  | 100% | name | 6823 | 100 |  | Ts-Paksuneulabiopsian histologinen tutkimus | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1424 | ts-pad-pol |  | 100% | name | 275 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1425 | ts-pad-tk |  | 100% | name | 20896 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1426 | ts-pad-y |  | 100% | name | 15295 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1427 | ts-pad1 |  | 100% | name | 831 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1428 | ts-pad2 |  | 100% | name | 137 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1429 | ts-pad4-hn |  | 100% | name | 839 | 100 |  | Ts-Pään ja kaulan alueen histologinen tutkimus, laaja leikkauspreparaatti | Tissue |  | Microscopic observation [Identifier] in Head and neck tissue by Light microscopy |
| 1430 | ts-padbrea |  | 100% | name | 12091 | 100 |  | Ts-Rinnan paksuneulabiopsian histologinen tutkimus | Tissue |  | Microscopic observation [Identifier] in Breast tissue by Light microscopy |
| 1431 | ts-padcns |  | 100% | name | 1168 | 100 |  | Ts-Keskushermoston histologinen tutkimus, kirurginen näyte | Tissue |  | Microscopic observation [Identifier] in Central nervous system tissue by Light microscopy |
| 1432 | ts-padcolo |  | 100% | name | 72092 | 100 |  | Ts-Kolonoskopianäytteiden histologinen tutkimus | Tissue |  | Microscopic observation [Identifier] in Colon tissue by Light microscopy |
| 1433 | ts-padfish |  | 100% | name | 294 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by FISH |
| 1434 | ts-padgas |  | 100% | name | 139 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Stomach tissue by Light microscopy |
| 1435 | ts-padgas2 |  | 100% | name | 1497 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Stomach tissue by Light microscopy |
| 1436 | ts-padgast |  | 100% | name | 76383 | 100 |  | Ts-Gastroskopianäytteiden histologinen tutkimus | Tissue |  | Microscopic observation [Identifier] in Stomach tissue by Light microscopy |
| 1437 | ts-padgyn |  | 100% | name | 290 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Female genital tract tissue by Light microscopy |
| 1438 | ts-padkolp | form | 9% | name+unit | 769 | 0 |  | Ts-Kolposkopianäytteiden histologinen tutkimus | Tissue |  | Microscopic observation [Identifier] in Cervix tissue by Light microscopy |
| 1439 | ts-padkolp |  | 91% | name | 8220 | 100 |  | Ts-Kolposkopianäytteiden histologinen tutkimus | Tissue |  | Microscopic observation [Identifier] in Cervix tissue by Light microscopy |
| 1440 | ts-padlis1 |  | 100% | name | 594 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1441 | ts-padmakr |  | 100% | name | 2840 | 100 |  |  | Tissue |  | Gross observation [Identifier] in Tissue |
| 1442 | ts-padpak2 |  | 100% | name | 1434 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1443 | ts-padpak3 |  | 100% | name | 473 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1444 | ts-padpika |  | 100% | name | 8000 | 100 |  | Ts-Kudoksen pikaleiketutkimus | Tissue |  | Frozen section [Identifier] in Tissue by Light microscopy |
| 1445 | ts-padpros |  | 100% | name | 9361 | 100 |  | Ts-Prostatabiopsian histologinen tutkimus | Tissue |  | Microscopic observation [Identifier] in Prostate tissue by Light microscopy |
| 1446 | ts-padsuu |  | 100% | name | 345 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Oral cavity tissue by Light microscopy |
| 1447 | ts-padtuor |  | 100% | name | 101 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1448 | ts-patlask |  | 100% | name | 281 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by Light microscopy |
| 1449 | ts.pad-ih |  | 100% | name | 224 | 100 |  |  |  | Immunohistochemical | Microscopic observation [Identifier] in Tissue by Immunohistochemistry |
| 1450 | tspadbrea |  | 100% | name | 129 | 100 |  |  |  |  | Microscopic observation [Identifier] in Breast tissue by Light microscopy |

