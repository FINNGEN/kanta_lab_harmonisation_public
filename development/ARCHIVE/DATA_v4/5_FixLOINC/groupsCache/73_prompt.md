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
Here is group 73.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000606 | Spermatozoa [#/volume] in Semen | 1.000 | 1001 |
| 3006442 | Creatine [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3016436 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 156 |
| 3024390 | 25-hydroxyvitamin D3 [Moles/volume] in Serum or Plasma | 1.000 | 127 |
| 3030366 | Cystatin C [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3051659 | 25-hydroxyvitamin D2 [Moles/volume] in Serum or Plasma | 1.000 | 661 |
| 40758705 | QUEtiapine [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3000250 | Salmonella paratyphi B H Ab [Titer] in Serum | 0.981 |  |
| 3002522 | Salmonella paratyphi A H Ab [Titer] in Serum | 0.981 |  |
| 3037615 | Salmonella typhi H Ab [Titer] in Serum | 0.980 |  |
| 3003004 | Salmonella paratyphi B Ab [Titer] in Serum | 0.976 |  |
| 3000126 | Salmonella paratyphi A Ab [Titer] in Serum | 0.975 |  |
| 3005783 | Lactate dehydrogenase 1 [Enzymatic activity/volume] in Serum or Plasma | 0.964 |  |
| 3008700 | Salmonella typhi H D Ab [Titer] in Serum | 0.964 |  |
| 3044808 | Salmonella paratyphi A O Ab [Titer] in Serum | 0.962 |  |
| 3038085 | Salmonella paratyphi A H Ab [Titer] in Serum by Agglutination | 0.960 |  |
| 3033443 | Salmonella paratyphi B O Ab [Titer] in Serum | 0.959 |  |
| 3021820 | Salmonella paratyphi B H Ab [Titer] in Serum by Agglutination | 0.959 |  |
| 3017861 | Lactate dehydrogenase 2 [Enzymatic activity/volume] in Serum or Plasma | 0.959 |  |
| 3028857 | Salmonella paratyphi C O Ab [Titer] in Serum | 0.957 |  |
| 3022725 | Serotonin [Moles/volume] in Serum | 0.955 |  |
| 3037960 | Salmonella typhi O Ab [Titer] in Serum | 0.953 |  |
| 3035085 | Serotonin [Moles/volume] in Plasma | 0.953 |  |
| 3044613 | Salmonella typhi H Ab [Titer] in Serum by Agglutination | 0.950 |  |
| 3044332 | Salmonella typhimurium H Ab [Titer] in Serum | 0.949 |  |
| 3006769 | Lactate dehydrogenase 3 [Enzymatic activity/volume] in Serum or Plasma | 0.949 |  |
| 3029064 | Salmonella paratyphi C H Ab [Titer] in Serum | 0.946 |  |
| 3025124 | Lactate dehydrogenase 4 [Enzymatic activity/volume] in Serum or Plasma | 0.945 |  |
| 3022250 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma by Lactate to pyruvate reaction | 0.944 |  |
| 40771025 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma | 0.944 |  |
| 3027010 | Lactate dehydrogenase 5 [Enzymatic activity/volume] in Serum or Plasma | 0.942 |  |
| 3050121 | Salmonella paratyphi C Ab [Titer] in Serum | 0.942 |  |
| 3011418 | Salmonella paratyphi B O Ab [Titer] in Serum by Agglutination | 0.942 |  |
| 3030938 | Salmonella paratyphi A O Ab [Titer] in Serum by Agglutination | 0.941 |  |
| 3052884 | Salmonella typhi H D Ab [Titer] in Serum by Agglutination | 0.940 |  |
| 3004511 | QUEtiapine [Mass/volume] in Serum or Plasma | 0.939 |  |
| 3044607 | Salmonella paratyphi C O Ab [Titer] in Serum by Agglutination | 0.937 |  |
| 3045198 | Salmonella typhimurium H Ab [Titer] in Serum by Agglutination | 0.937 |  |
| 3015160 | Creatine [Mass/volume] in Serum or Plasma | 0.934 |  |
| 3037978 | Salmonella typhimurium Ab [Titer] in Serum | 0.933 |  |
| 3045480 | Salmonella paratyphi C H Ab [Titer] in Serum by Agglutination | 0.931 |  |
| 3005225 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma by Pyruvate to lactate reaction | 0.929 |  |
| 3044621 | Salmonella typhi O Ab [Titer] in Serum by Agglutination | 0.929 |  |
| 40765038 | 1,25-Dihydroxyvitamin D [Mass/volume] in Serum or Plasma | 0.929 |  |
| 3049536 | 25-hydroxyvitamin D2 [Mass/volume] in Serum or Plasma | 0.927 |  |
| 3043892 | Salmonella typhi O D Ab [Titer] in Serum | 0.925 |  |
| 3020149 | 25-hydroxyvitamin D3 [Mass/volume] in Serum or Plasma | 0.924 |  |
| 3007869 | Lactate dehydrogenase [Enzymatic activity/volume] in Specimen | 0.917 |  |
| 3004652 | Salmonella typhi O D Ab [Titer] in Serum by Agglutination | 0.914 |  |
| 3044323 | Salmonella enteritidis H Ab [Titer] in Serum | 0.912 |  |
| 3019444 | Salmonella typhimurium Ab [Titer] in Serum by Agglutination | 0.910 |  |
| 36303714 | Connective tissue autoimmune Ab panel - Serum | 0.910 |  |
| 40763387 | QUEtiapine [Moles/volume] in Specimen | 0.909 |  |
| 40765039 | 1,25-Dihydroxyvitamin D2 [Mass/volume] in Serum or Plasma | 0.905 |  |
| 3007858 | Lactate dehydrogenase 3/Lactate dehydrogenase.total in Serum or Plasma by Electrophoresis | 0.904 |  |
| 1002050 | NUDT15 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.904 |  |
| 3005551 | Serotonin [Moles/volume] in Blood | 0.902 |  |
| 3016213 | Lactate dehydrogenase 2 [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.902 |  |
| 40760678 | 25-hydroxyvitamin D3 [Moles/volume] in Serum or Plasma --pre dose calcium | 0.900 |  |
| 3045186 | Salmonella enteritidis H Ab [Titer] in Serum by Agglutination | 0.900 |  |
| 1469740 | 24,25-dihydroxyvitamin D3+24,25-dihydroxyvitamin D2 [Moles/volume] in Serum or Plasma | 0.899 |  |
| 3024830 | Lactate dehydrogenase 4/Lactate dehydrogenase.total in Serum or Plasma by Electrophoresis | 0.899 |  |
| 3029083 | Spermatozoa Motile [#/volume] in Semen | 0.898 |  |
| 42529188 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma by Immunoassay | 0.897 |  |
| 40763023 | QUEtiapine [Moles/volume] in Urine | 0.895 |  |
| 3046609 | Cholecalciferol (Vit D3) [Moles/volume] in Serum or Plasma | 0.893 |  |
| 3023919 | Lactate dehydrogenase 2/Lactate dehydrogenase.total in Serum or Plasma by Electrophoresis | 0.892 |  |
| 1091942 | Creatine/Creatinine [Molar ratio] in Serum or Plasma | 0.891 |  |
| 3006898 | Lactate dehydrogenase 1/Lactate dehydrogenase.total in Serum or Plasma by Electrophoresis | 0.891 |  |
| 3011391 | Calcitriol [Moles/volume] in Serum or Plasma | 0.890 | 503 |
| 649454 | 25-hydroxyvitamin D3 [Measurement] in Serum or Plasma | 0.890 |  |
| 647201 | Salmonella typhi O Ab [Measurement] in Serum | 0.887 |  |
| 3051595 | Calciferol (Vit D2) [Moles/volume] in Serum or Plasma | 0.886 | 391 |
| 3051083 | Cystatin C [Mass/volume] in Urine | 0.886 |  |
| 44816827 | QUEtiapine [Mass/volume] in Serum or Plasma --trough | 0.885 |  |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 0.884 | 1 |
| 3036071 | Salmonella sp Ab [Titer] in Serum | 0.883 |  |
| 40760679 | 25-hydroxyvitamin D3 [Moles/volume] in Serum or Plasma --2 hours post dose calcium | 0.881 |  |
| 3012481 | Lactate dehydrogenase 5/Lactate dehydrogenase.total in Serum or Plasma by Electrophoresis | 0.881 |  |
| 40765040 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Mass/volume] in Serum or Plasma | 0.881 | 632 |
| 645619 | QUEtiapine [Measurement] in Serum or Plasma | 0.880 |  |
| 3040432 | Spermatozoa [#/volume] in Semen --post concentration | 0.879 |  |
| 3022689 | Creatine [Moles/volume] in Urine | 0.876 |  |
| 3033625 | Serotonin [Mass/volume] in Serum | 0.875 |  |
| 3024025 | Serotonin [Mass/volume] in Plasma | 0.873 |  |
| 1469793 | Spermatozoa [#] in Semen | 0.873 |  |
| 1259622 | Giardia lamblia cysts [Presence] in Stool by Microscopy | 0.873 |  |
| 1091713 | Lactate dehydrogenase 1/Lactate dehydrogenase.total in Urine | 0.864 |  |
| 40760681 | 25-hydroxyvitamin D3 [Moles/volume] in Serum or Plasma --1 hour post dose calcium | 0.864 |  |
| 3002048 | Salmonella typhimurium Ab [Presence] in Serum | 0.857 |  |
| 1761401 | NUDT15 gene c.415C>T [Presence] in Blood by Molecular genetics method | 0.856 |  |
| 3008919 | Primary Spermatocytes [#/volume] in Semen | 0.856 |  |
| 3036684 | Cells other than spermatozoa [#/volume] in Semen | 0.855 |  |
| 3000307 | PM-SCL extractable nuclear Ab [Units/volume] in Serum | 0.855 |  |
| 3044625 | Serotonin [Moles/volume] in Urine | 0.855 |  |
| 3022981 | Spermatogonia [#/volume] in Semen | 0.854 |  |
| 3048015 | Spermatozoa [#/volume] in Semen --pre washing | 0.853 | 1266 |
| 3012965 | Cystine [Mass/volume] in Serum or Plasma | 0.853 |  |
| 1761572 | NUDT15 gene c.52G>A [Presence] in Blood by Molecular genetics method | 0.852 |  |
| 3028955 | 5-Hydroxytryptophan [Moles/volume] in Serum or Plasma | 0.850 |  |
| 3017761 | Creatine kinase isoenzymes [Interpretation] in Serum or Plasma | 0.850 |  |
| 3047671 | Spermatozoa [#/volume] in Semen --post washing | 0.847 |  |
| 40761995 | Spermatozoa Progressive [#/volume] in Semen | 0.847 |  |
| 647280 | Myositis specific Ab panel - Serum or Plasma | 0.847 |  |
| 46235076 | Creatinine [Moles/volume] in Serum, Plasma or Blood | 0.847 |  |
| 1616512 | Necrotizing myopathy autoimmune Ab panel - Serum | 0.846 |  |
| 3006762 | Serine [Moles/volume] in Serum or Plasma | 0.846 | 1886 |
| 40763881 | PM-SCL-100 IgG Ab [Units/volume] in Serum | 0.845 |  |
| 40763024 | QUEtiapine [Moles/volume] in Gastric fluid | 0.843 |  |
| 3016723 | Creatinine [Mass/volume] in Serum or Plasma | 0.843 |  |
| 1259775 | Creatine [Moles/volume] in DBS | 0.843 |  |
| 1761851 | NUDT15 gene c.416G>A [Presence] in Blood by Molecular genetics method | 0.841 |  |
| 3009347 | Lactate dehydrogenase isoenzymes [Interpretation] in Serum or Plasma | 0.841 |  |
| 1092446 | QUEtiapine [Mass/volume] in Urine | 0.839 |  |
| 40757511 | Cystatin C [Mass/volume] in 24 hour Urine | 0.837 |  |
| 3005662 | Lactate dehydrogenase 1/Lactate dehydrogenase 2 [Enzymatic activity ratio] in Serum or Plasma | 0.836 |  |
| 21490951 | L-serine [Moles/volume] in Serum or Plasma | 0.836 |  |
| 3010645 | SCL-70 extractable nuclear Ab [Units/volume] in Serum | 0.835 | 823 |
| 3045185 | Creatine [Moles/volume] in 24 hour Urine | 0.835 |  |
| 3041394 | Creatine [Moles/volume] in Amniotic fluid | 0.833 |  |
| 1092287 | PM-SCL-100 Ab [Units/volume] in Serum | 0.831 |  |
| 3026603 | Cystine+Cysteine [Mass/volume] in Serum or Plasma | 0.830 |  |
| 3015620 | Creatine kinase panel - Serum or Plasma | 0.828 |  |
| 43055123 | DNA double strand [Mass/volume] in Specimen | 0.828 |  |
| 1761601 | NUDT15 gene c.50_55del [Presence] in Blood by Molecular genetics method | 0.826 |  |
| 3013676 | Sertraline [Moles/volume] in Serum or Plasma | 0.823 |  |
| 1761681 | NUDT15 gene c.50_55dup and c.415C>T [Presence] in Blood by Molecular genetics method | 0.823 |  |
| 3034022 | Lactate dehydrogenase panel - Serum or Plasma | 0.820 |  |
| 3036604 | Creatine kinase isoenzymes [Interpretation] in Serum or Plasma by Electrophoresis | 0.815 |  |
| 3052944 | ARIPiprazole [Moles/volume] in Serum or Plasma | 0.815 |  |
| 1001587 | NUDT15 gene product metabolic activity interpretation in Blood or Tissue Qualitative by Molecular genetics method | 0.814 |  |
| 3016307 | Lactate dehydrogenase 3/Lactate dehydrogenase.total in Urine by Electrophoresis | 0.814 |  |
| 647812 | Lactate dehydrogenase [Measurement] in Serum or Plasma | 0.812 |  |
| 3005335 | Cystine [Moles/volume] in Serum or Plasma | 0.812 |  |
| 1259712 | Giardia lamblia trophozoites [Presence] in Stool by Microscopy | 0.811 |  |
| 3965405 | PM-SCL-100 extractable nuclear Ab [Units/volume] in Serum by Immunoassay | 0.811 |  |
| 3052524 | SCL-70 extractable nuclear IgG Ab [Units/volume] in Serum by Immunoassay | 0.809 |  |
| 3020900 | Cysteine [Moles/volume] in Serum or Plasma | 0.809 |  |
| 3025245 | SCL-70 extractable nuclear Ab [Units/volume] in Serum by Immunoassay | 0.809 |  |
| 3019378 | Topiramate [Moles/volume] in Serum or Plasma | 0.809 |  |
| 3008270 | Lactate dehydrogenase 4/Lactate dehydrogenase.total in Urine by Electrophoresis | 0.807 |  |
| 3015475 | Lactate dehydrogenase 2/Lactate dehydrogenase.total in Urine by Electrophoresis | 0.806 |  |
| 3014632 | Cystine [Units/volume] in Serum or Plasma | 0.804 |  |
| 3025950 | Lactate dehydrogenase 5 [Enzymatic activity/volume] in Serum or Plasma by Chemical separation | 0.803 |  |
| 3015237 | Lactate dehydrogenase 1/Lactate dehydrogenase.total in Urine by Electrophoresis | 0.801 |  |
| 21491223 | Cysteate [Moles/volume] in Serum or Plasma | 0.801 |  |
| 3049867 | Creatine kinase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.799 |  |
| 36659953 | Connective tissue autoimmune IgG panel - Serum or Plasma | 0.799 |  |
| 3025240 | Lactate dehydrogenase 4 [Enzymatic activity/volume] in Serum or Plasma by Chemical separation | 0.798 |  |
| 1761866 | NUDT15 gene c.50_55dup [Presence] in Blood by Molecular genetics method | 0.797 |  |
| 3049516 | Lactate dehydrogenase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.796 |  |
| 646665 | PM-SCL extractable nuclear Ab [Measurement] in Serum | 0.794 |  |
| 36304411 | PM-SCL-100 Ab [Units/volume] in Serum by Line blot | 0.794 |  |
| 1002341 | TPMT gene and NUDT15 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.791 |  |
| 3007691 | PM-1 Ab [Units/volume] in Serum | 0.791 |  |
| 3048917 | Creatine kinase isoenzymes [Interpretation] in Serum or Plasma by Electrophoresis Narrative | 0.787 |  |
| 43534055 | UGT2B15 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.786 |  |
| 40758526 | Short myasthenia gravis panel - Serum | 0.786 |  |
| 3023894 | Epithelial cells [Presence] in Stool by Light microscopy | 0.777 |  |
| 1176416 | Thymoma and myasthenia gravis antibody panel - Serum | 0.774 |  |
| 649150 | Giardia sp [Presence] in Stool by Light microscopy | 0.773 |  |
| 3007220 | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma | 0.773 | 90 |
| 3016311 | Creatine kinase.MB/Creatine kinase.total in Serum or Plasma | 0.769 | 297 |
| 1616798 | Myasthenia gravis and Lambert-Eaton syndrome autoimmune Ab panel - Serum | 0.767 |  |
| 36660106 | Myelopathy autoimmune Ab panel - Serum | 0.766 |  |
| 3048252 | Creatine kinase.MiMi/Creatine kinase.total in Serum or Plasma | 0.764 |  |
| 3007150 | Creatine kinase.MB/Creatine kinase.total in Serum or Plasma by Electrophoresis | 0.763 | 1391 |
| 3008558 | Creatine kinase.MM/Creatine kinase.total in Serum or Plasma | 0.763 |  |
| 3042694 | Eosinophils [Presence] in Stool by Light microscopy | 0.760 |  |
| 3019733 | Toxoplasma gondii [Presence] in Stool | 0.757 |  |
| 37019529 | Parasite [Presence] in Blood by Light microscopy | 0.748 |  |
| 1988361 | Dysautonomia autoimmune Ab panel - Serum | 0.742 |  |
| 3046513 | Cardiolipin IgA and IgG and IgM panel - Serum | 0.741 |  |
| 36306118 | Systemic sclerosis Ab panel - Serum by Immunoassay | 0.739 |  |
| 3032269 | Mucus [Presence] in Stool by Light microscopy | 0.734 |  |
| 3012487 | Cardiolipin IgG and IgM panel - Serum | 0.734 |  |
| 3025088 | Taenia sp eggs [Presence] in Stool by Probe | 0.729 |  |
| 1617093 | Nuclear antibody panel - Serum | 0.729 |  |
| 1175673 | Myeloperoxidase Ab.IgG and Proteinase 3 Ab.IgG Panel - Serum | 0.726 |  |
| 3028564 | Alkaline phosphatase isoenz panel - Serum or Plasma | 0.724 |  |
| 3010114 | Amylase isoenzyme 7 panel - Serum | 0.723 |  |
| 3031964 | Paraneoplastic Ab panel - Serum | 0.722 |  |
| 3003327 | Ova and parasites identified in Stool by Light microscopy | 0.722 | 659 |
| 40761827 | Mycoplasma pneumoniae IgG and IgM panel - Serum | 0.713 |  |
| 36304332 | Other Chemical [Mass/mass] in Specimen | 0.675 |  |
| 36303806 | Narasin [Mass/mass] in Specimen | 0.641 |  |
| 3041662 | Mycobacterium tuberculosis DNA [#/volume] in Specimen by NAA with probe detection | 0.633 |  |
| 36305468 | Magnesium [Mass/mass] in Specimen | 0.631 |  |
| 3027984 | Protein [Mass/volume] in Specimen | 0.627 |  |
| 1002345 | Substance use disorder score | 0.624 |  |
| 36303488 | Sodium [Mass/mass] in Specimen | 0.621 |  |
| 36305975 | PERC Total score | 0.620 |  |
| 36031622 | HTLV I DNA [#/volume] in Specimen by NAA with probe detection | 0.619 |  |
| 36305808 | Cyanide [Mass/mass] in Specimen | 0.614 |  |
| 36305453 | Cholecalciferol (Vit D3) [Mass/mass] in Specimen | 0.614 |  |
| 1175343 | PESI Total score | 0.612 |  |
| 3965290 | Total score (0 to 7) | 0.606 |  |
| 1988459 | Total score NRS_2002 | 0.605 |  |
| 1259540 | PAINAD.Total score Observed | 0.604 |  |
| 36031899 | Sedation total score NPASS | 0.596 |  |
| 1469983 | Patient follow-up goal attainment scaling score | 0.594 |  |
| 1988902 | Total score age adjusted | 0.581 |  |
| 36032261 | Pain agitation total score NPASS | 0.579 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 885 | -kskäynt |  | 100% | name | 14336 | 100 |  |  |  |  |  |
| 886 | -ku72/86 |  | 100% | name | 958 | 100 |  |  |  |  |  |
| 887 | -nudt15 |  | 100% | name+values | 2593 | 100 | [16, 16, 16, 16, 16, 16, 16, 16, 16] |  |  |  | NUDT15 gene [Identifier] in Blood or Tissue by Molecular genetics method |
| 888 | -s.yht. | e6 | 95% | name+unit+values | 1504 | 0 | [1.76, 9.88, 23.81, 46.09, 70.79, 95.11, 132.38, 178.2, 261.34] |  |  |  |  |
| 889 | -s.yht. |  | 5% | name | 83 | 100 |  |  |  |  |  |
| 890 | -selvtyö |  | 100% | name | 360 | 100 |  |  |  |  |  |
| 891 | -siitt. | e6/ml | 38% | name+unit+values | 1198 | 0 | [1.77, 7.42, 17.66, 25.89, 34.94, 43.13, 56.07, 73.53, 101.25] |  |  |  | Spermatozoa [#/volume] in Semen |
| 892 | -siitt. |  | 62% | name | 1937 | 100 |  |  |  |  | Spermatozoa [#/volume] in Semen |
| 893 | audit | form | 45% | name+unit+values | 399 | 0 | [0, 1, 2, 2.47, 3, 4, 4.99, 6.54, 8.56] |  |  |  | AUDIT total score [Score] in ^Patient |
| 894 | audit |  | 55% | name+values | 480 | 100 | [0, 0.98, 1, 2, 2.42, 3.62, 4, 5.74, 8.96] |  |  |  | AUDIT total score [Score] in ^Patient |
| 895 | audit-c |  | 100% | name+values | 187 | 100 | [1, 1, 2, 2, 3, 3, 3, 4, 5] |  |  |  | AUDIT-C total score [Score] in ^Patient |
| 896 | dnauut1 |  | 100% | name | 166 | 100 |  |  |  |  | DNA extracted [Mass] in Specimen |
| 897 | f-kystat |  | 100% | name | 7014 | 100 |  |  | Feces |  | Parasite cysts [Presence] in Stool by Microscopy |
| 898 | ku72/86 |  | 100% | name | 1497 | 100 |  |  |  |  |  |
| 899 | p-d-25 | nmol/l | 99% | name+unit+values | 93835 | 0 | [47.27, 57.52, 64.99, 71.99, 78.59, 85.79, 93.98, 104.82, 121.75] | P -D-vitamiini-25-OH | Plasma |  | 25-Hydroxyvitamin D [Moles/volume] in Serum or Plasma |
| 900 | p-d-25 |  | 1% | name | 1037 | 100 |  | P -D-vitamiini-25-OH | Plasma |  | 25-Hydroxyvitamin D [Moles/volume] in Serum or Plasma |
| 901 | p-kysc | mg/l | 100% | name+unit+values | 55470 | 0 | [0.84, 0.96, 1.08, 1.23, 1.41, 1.63, 1.91, 2.32, 3.12] | P -Kystatiini C | Plasma |  | Cystatin C [Mass/volume] in Serum or Plasma |
| 902 | p-kysc |  | 0% | name | 196 | 100 |  | P -Kystatiini C | Plasma |  | Cystatin C [Mass/volume] in Serum or Plasma |
| 903 | p-nkäs10 |  | 100% | name | 803 | 100 |  |  | Plasma |  |  |
| 904 | s-5-ht | nmol/l | 87% | name+unit+values | 224 | 0 | [100.62, 206.57, 388.63, 493.54, 647.03, 818.29, 936.71, 1116.9, 1624] | S -Hydroksitryptamiini (5-) | Serum |  | Serotonin [Moles/volume] in Serum or Plasma |
| 905 | s-5-ht |  | 13% | name | 33 | 100 |  | S -Hydroksitryptamiini (5-) | Serum |  | Serotonin [Moles/volume] in Serum or Plasma |
| 906 | s-ck-is |  | 100% | name | 326 | 100 |  | S -Kreatiinikinaasi, isoentsyymit | Serum | Isoenzymes | Creatine kinase isoenzymes panel - Serum |
| 907 | s-ctdscr |  | 100% | name+values | 123 | 100 | [0.1, 0.1, 0.1, 0.2, 0.2, 0.2, 0.3, 0.41, 1.2] |  | Serum |  | Connective tissue disease autoantibodies panel - Serum |
| 908 | s-d-1,25 | pmol/l | 87% | name+unit+values | 5369 | 0.02 | [55.49, 72.65, 85.92, 96.71, 107.01, 117.78, 130.2, 146.12, 170.51] | S -D-vitamiini-1,25-OH | Serum |  | 1,25-Dihydroxyvitamin D [Moles/volume] in Serum or Plasma |
| 909 | s-d-1,25 |  | 13% | name+values | 793 | 100 | [53.62, 70.32, 82.73, 93.66, 102.64, 113.83, 125.96, 141.84, 170.33] | S -D-vitamiini-1,25-OH | Serum |  | 1,25-Dihydroxyvitamin D [Moles/volume] in Serum or Plasma |
| 910 | s-d-25 | nmol/l | 99% | name+unit+values | 395823 | 0 | [46.37, 55.92, 63.01, 69.37, 75.68, 82.28, 90.01, 100.09, 116.33] | S -D-vitamiini-25-OH | Serum |  | 25-Hydroxyvitamin D [Moles/volume] in Serum or Plasma |
| 911 | s-d-25 |  | 1% | name | 3522 | 100 |  | S -D-vitamiini-25-OH | Serum |  | 25-Hydroxyvitamin D [Moles/volume] in Serum or Plasma |
| 912 | s-d-25-32 | nmol/l | 95% | name+unit+values | 1945 | 0 | [42.81, 52.88, 60.32, 66.43, 72.91, 78.86, 85.75, 94.48, 107.92] |  | Serum |  | 25-Hydroxyvitamin D [Moles/volume] in Serum or Plasma |
| 913 | s-d-25-32 |  | 5% | name+values | 109 | 100 | [39, 42, 47.62, 52.5, 62.5, 67, 77, 85, 101] |  | Serum |  | 25-Hydroxyvitamin D [Moles/volume] in Serum or Plasma |
| 914 | s-d2-25 | nmol/l | 24% | name+unit+values | 140 | 0 | [8.95, 11, 12.5, 14, 16, 18.32, 20.85, 26.09, 34.5] | S -D2-vitamiini-25-OH | Serum |  | 25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma |
| 915 | s-d2-25 |  | 76% | name | 436 | 100 |  | S -D2-vitamiini-25-OH | Serum |  | 25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma |
| 916 | s-d3-25 | nmol/l | 93% | name+unit+values | 2269 | 0 | [41.3, 52.08, 59.25, 66.03, 72.52, 78.44, 84.87, 93.25, 107.79] | S -D3-vitamiini-25-OH | Serum |  | 25-Hydroxyvitamin D3 [Moles/volume] in Serum or Plasma |
| 917 | s-d3-25 |  | 7% | name+values | 183 | 100 | [44, 51, 58.4, 64.35, 70, 77.2, 85, 91.25, 101] | S -D3-vitamiini-25-OH | Serum |  | 25-Hydroxyvitamin D3 [Moles/volume] in Serum or Plasma |
| 918 | s-ketiap | nmol/l | 73% | name+unit+values | 678 | 0 | [92.76, 170.13, 253.54, 334.41, 416.64, 519.04, 659.62, 894.01, 1335.87] | S -Ketiapiini | Serum |  | Quetiapine [Moles/volume] in Serum or Plasma |
| 919 | s-ketiap |  | 27% | name+values | 253 | 100 | [86.16, 138.77, 221.12, 302.45, 415.62, 487.41, 585.26, 794.71, 1304.5] | S -Ketiapiini | Serum |  | Quetiapine [Moles/volume] in Serum or Plasma |
| 920 | s-kid10 |  | 100% | name | 729 | 100 |  |  | Serum |  |  |
| 921 | s-kipa |  | 100% | name | 39484 | 100 |  |  | Serum |  |  |
| 922 | s-krtiin | umol/l | 100% | name+unit+values | 334 | 0 | [53.14, 57.95, 63.02, 66.17, 69.73, 74.27, 79.36, 85.56, 91.27] | S -Kreatiini | Serum |  | Creatine [Moles/volume] in Serum or Plasma |
| 923 | s-kubico |  | 100% | name | 571 | 100 |  |  | Serum |  |  |
| 924 | s-kysc | mg/l | 87% | name+unit+values | 5526 | 0 | [0.81, 0.89, 0.98, 1.06, 1.17, 1.31, 1.51, 1.81, 2.34] | S -Kystatiini C | Serum |  | Cystatin C [Mass/volume] in Serum or Plasma |
| 925 | s-kysc |  | 13% | name+values | 848 | 100 | [0.94, 1.14, 1.25, 1.38, 1.56, 1.78, 1.97, 2.33, 2.99] | S -Kystatiini C | Serum |  | Cystatin C [Mass/volume] in Serum or Plasma |
| 926 | s-käsmak |  | 100% | name | 312 | 100 |  |  | Serum |  |  |
| 927 | s-ld-1 | % | 92% | name+unit+values | 212 | 1.42 | [16.74, 19.25, 20.9, 22.13, 23.41, 24.74, 26.56, 27.97, 32] | S -Laktaattidehydrogenaasi, isoentsyymi 1 | Serum |  | Lactate dehydrogenase.1/Lactate dehydrogenase.total in Serum or Plasma |
| 928 | s-ld-1 |  | 8% | name | 18 | 100 |  | S -Laktaattidehydrogenaasi, isoentsyymi 1 | Serum |  | Lactate dehydrogenase.1/Lactate dehydrogenase.total in Serum or Plasma |
| 929 | s-ld-2 | % | 92% | name+unit+values | 200 | 0.5 | [31.26, 33.03, 34.03, 35.18, 36.53, 37.55, 38.57, 39.48, 41.3] |  | Serum |  | Lactate dehydrogenase.2/Lactate dehydrogenase.total in Serum or Plasma |
| 930 | s-ld-2 |  | 8% | name | 17 | 100 |  |  | Serum |  | Lactate dehydrogenase.2/Lactate dehydrogenase.total in Serum or Plasma |
| 931 | s-ld-3 | % | 91% | name+unit+values | 198 | 0.51 | [16.7, 18.6, 19.86, 20.8, 21.55, 22.38, 23.44, 24.42, 25.95] |  | Serum |  | Lactate dehydrogenase.3/Lactate dehydrogenase.total in Serum or Plasma |
| 932 | s-ld-3 |  | 9% | name | 19 | 100 |  |  | Serum |  | Lactate dehydrogenase.3/Lactate dehydrogenase.total in Serum or Plasma |
| 933 | s-ld-4 | % | 91% | name+unit+values | 195 | 0.51 | [5.62, 6.8, 7.36, 8.13, 8.54, 9.23, 10.04, 10.9, 12.07] |  | Serum |  | Lactate dehydrogenase.4/Lactate dehydrogenase.total in Serum or Plasma |
| 934 | s-ld-4 |  | 9% | name | 19 | 100 |  |  | Serum |  | Lactate dehydrogenase.4/Lactate dehydrogenase.total in Serum or Plasma |
| 935 | s-ld-5 | % | 91% | name+unit+values | 210 | 0.95 | [5.03, 6.14, 7.01, 7.64, 8.6, 9.45, 10.74, 12.13, 15.29] | S -Laktaattidehydrogenaasi, isoentsyymi 5 | Serum |  | Lactate dehydrogenase.5/Lactate dehydrogenase.total in Serum or Plasma |
| 936 | s-ld-5 |  | 9% | name | 21 | 100 |  | S -Laktaattidehydrogenaasi, isoentsyymi 5 | Serum |  | Lactate dehydrogenase.5/Lactate dehydrogenase.total in Serum or Plasma |
| 937 | s-ld-is |  | 100% | name | 243 | 100 |  | S -Laktaattidehydrogenaasi, isoentsyymit | Serum | Isoenzymes | Lactate dehydrogenase isoenzymes panel - Serum |
| 938 | s-ldpit | u/l | 82% | name+unit+values | 145 | 0 | [153.9, 174.43, 189.35, 197.65, 204.73, 215.72, 233.25, 253.4, 304.1] |  | Serum |  | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma |
| 939 | s-ldpit |  | 18% | name | 32 | 100 |  |  | Serum |  | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma |
| 940 | s-liv2x10 |  | 100% | name | 1270 | 100 |  |  | Serum |  |  |
| 941 | s-o4.5.12 | titre | 6% | name+unit | 66 | 0 |  |  | Serum |  | Salmonella typhimurium O Ag [4,5,12] Ab [Titer] in Serum |
| 942 | s-o4.5.12 |  | 94% | name | 1134 | 100 |  |  | Serum |  | Salmonella typhimurium O Ag [4,5,12] Ab [Titer] in Serum |
| 943 | s-pm-scl | u/ml | 57% | name+unit+values | 166 | 0 | [1, 1, 1, 1, 1, 1.21, 2, 2, 3] |  | Serum |  | PM/Scl Ab [Units/volume] in Serum |
| 944 | s-pm-scl |  | 43% | name | 125 | 100 |  |  | Serum |  | PM/Scl Ab [Units/volume] in Serum |
| 945 | s-pmdm-t |  | 100% | name | 313 | 100 |  |  | Serum |  | Myositis specific autoantibodies panel - Serum |
| 946 | s-prkäsit |  | 100% | name | 767 | 100 |  |  | Serum |  |  |
| 947 | s-w-h:a | titre | 1% | name+unit | 7 | 0 |  |  | Serum |  | Salmonella paratyphi A H Ag Ab [Titer] in Serum |
| 948 | s-w-h:a |  | 99% | name | 1090 | 100 |  |  | Serum |  | Salmonella paratyphi A H Ag Ab [Titer] in Serum |
| 949 | s-w-h:b | titre | 31% | name+unit+values | 338 | 0 | [160, 160, 320, 320, 320, 320, 640, 873.14, 2242.44] |  | Serum |  | Salmonella paratyphi B H Ag Ab [Titer] in Serum |
| 950 | s-w-h:b |  | 69% | name | 760 | 100 |  |  | Serum |  | Salmonella paratyphi B H Ag Ab [Titer] in Serum |
| 951 | s-w-h:d | titre | 15% | name+unit+values | 161 | 0 | [160, 160, 284.8, 320, 320, 640, 640, 1096, 2500] |  | Serum |  | Salmonella typhi H Ag Ab [Titer] in Serum |
| 952 | s-w-h:d |  | 85% | name | 937 | 100 |  |  | Serum |  | Salmonella typhi H Ag Ab [Titer] in Serum |
| 953 | s-w-h:g.m | titre | 11% | name+unit+values | 121 | 0 | [160, 160, 166.4, 320, 320, 320, 640, 640, 1280] |  | Serum |  | Salmonella enteritidis H Ag [g,m] Ab [Titer] in Serum |
| 954 | s-w-h:g.m |  | 89% | name | 977 | 100 |  |  | Serum |  | Salmonella enteritidis H Ag [g,m] Ab [Titer] in Serum |
| 955 | s-w-h:i | titre | 22% | name+unit+values | 243 | 0 | [160, 160, 160, 189.92, 320, 320, 320, 611.56, 640] |  | Serum |  | Salmonella typhimurium H Ag [i] Ab [Titer] in Serum |
| 956 | s-w-h:i |  | 78% | name | 855 | 100 |  |  | Serum |  | Salmonella typhimurium H Ag [i] Ab [Titer] in Serum |
| 957 | s-w-o6.7 | titre | 7% | name+unit+values | 78 | 0 | [80, 80, 80, 80, 133.33, 160, 160, 320, 320] |  | Serum |  | Salmonella paratyphi C O Ag [6,7] Ab [Titer] in Serum |
| 958 | s-w-o6.7 |  | 93% | name | 980 | 100 |  |  | Serum |  | Salmonella paratyphi C O Ag [6,7] Ab [Titer] in Serum |
| 959 | s-w-o9.12 | titre | 16% | name+unit+values | 172 | 0 | [80, 80, 80, 160, 160, 160, 160, 160, 320] |  | Serum |  | Salmonella typhi O Ag [9,12] Ab [Titer] in Serum |
| 960 | s-w-o9.12 |  | 84% | name | 885 | 100 |  |  | Serum |  | Salmonella typhi O Ag [9,12] Ab [Titer] in Serum |
| 961 | s-yskät |  | 100% | name | 102 | 100 |  |  | Serum |  |  |
| 962 | sjukhus |  | 100% | name | 696 | 100 |  |  |  |  |  |
| 963 | sukup.tau1 |  | 100% | name | 211 | 100 |  |  |  |  |  |
| 964 | sukup1 |  | 100% | name | 184 | 100 |  |  |  |  |  |
| 965 | sukup2 |  | 100% | name | 101 | 100 |  |  |  |  |  |
| 966 | u-käsma |  | 100% | name | 934 | 100 |  |  | Urine |  |  |

