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
Here is group 111.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3006093 | Chlamydia trachomatis DNA [Presence] in Specimen by NAA with probe detection | 1.000 | 180 |
| 723477 | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.972 |  |
| 1092096 | Chlamydia trachomatis L1 DNA [Presence] in Specimen by NAA with probe detection | 0.971 |  |
| 706163 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.968 |  |
| 3024421 | Chlamydia trachomatis DNA [Presence] in Genital specimen by NAA with probe detection | 0.967 |  |
| 706177 | SARS-CoV-2 (COVID-19) IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.964 |  |
| 706178 | SARS-CoV-2 (COVID-19) IgM Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.963 |  |
| 1092298 | SARS-CoV-2 (COVID-19) IgG Ab [Units/volume] in Specimen | 0.963 |  |
| 1091948 | Chlamydia trachomatis L3 DNA [Presence] in Specimen by NAA with probe detection | 0.958 |  |
| 706170 | SARS-CoV-2 (COVID-19) RNA [Presence] in Specimen by NAA with probe detection | 0.957 |  |
| 3051893 | Chlamydia trachomatis L2 DNA [Presence] in Specimen by NAA with probe detection | 0.956 |  |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.956 |  |
| 36033641 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.956 |  |
| 723459 | SARS-CoV-2 (COVID-19) IgA Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.955 |  |
| 586515 | SARS-CoV-2 (COVID-19) Ab [Presence] in Serum or Plasma by Immunoassay | 0.955 |  |
| 3034878 | Chlamydia sp DNA [Presence] in Specimen by NAA with probe detection | 0.946 |  |
| 757685 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.944 |  |
| 3004275 | Chlamydia trachomatis DNA [Presence] in Conjunctival specimen by NAA with probe detection | 0.944 |  |
| 36031238 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with non-probe detection | 0.939 |  |
| 586522 | SARS-CoV-2 (COVID-19) Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.939 |  |
| 36661384 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.938 |  |
| 36661376 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.935 |  |
| 3042951 | Complement C1q Ab [Units/volume] in Serum | 0.931 |  |
| 1761840 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Specimen by NAA with probe detection | 0.931 |  |
| 3020200 | Chlamydia trachomatis DNA [Presence] in Cervix by NAA with probe detection | 0.931 | 751 |
| 36032419 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Immunoassay | 0.928 |  |
| 3049703 | Chlamydia trachomatis DNA [Identifier] in Specimen by NAA with probe detection | 0.928 |  |
| 3036736 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Specimen by NAA with probe detection | 0.925 |  |
| 648157 | SARS-CoV-2 (COVID-19) IgG Ab [Measurement] in Serum or Plasma | 0.922 |  |
| 1091110 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Specimen | 0.920 |  |
| 649402 | SARS-CoV-2 (COVID-19) RNA [Presence] in Specimen by NAA with non-probe detection | 0.919 |  |
| 645263 | SARS-CoV-2 (COVID-19) IgM Ab [Measurement] in Serum or Plasma | 0.918 |  |
| 1259611 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen | 0.917 |  |
| 648299 | SARS-CoV-2 (COVID-19) IgA Ab [Measurement] in Serum or Plasma | 0.916 |  |
| 586526 | SARS-CoV-2 (COVID-19) RNA [Presence] in Nasopharynx by NAA with probe detection | 0.910 |  |
| 723474 | SARS-CoV-2 (COVID-19) IgG Ab [Presence] in Serum or Plasma by Immunoassay | 0.909 |  |
| 3012827 | Coronavirus Ab [Units/volume] in Serum | 0.908 |  |
| 36661369 | SARS-CoV-2 (COVID-19) Ab [Presence] in Serum, Plasma or Blood by Rapid immunoassay | 0.906 |  |
| 706160 | SARS-CoV-2 (COVID-19) RdRp gene [Presence] in Respiratory system specimen by NAA with probe detection | 0.903 |  |
| 706161 | SARS-CoV-2 (COVID-19) N gene [Presence] in Respiratory system specimen by NAA with probe detection | 0.903 |  |
| 36033666 | SARS-CoV-2 (COVID-19) IgG Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.902 |  |
| 3031852 | SARS coronavirus RNA [Presence] in Specimen by NAA with probe detection | 0.900 |  |
| 723479 | SARS-CoV-2 (COVID-19) IgG+IgM Ab [Presence] in Serum or Plasma by Immunoassay | 0.900 |  |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.899 |  |
| 1988202 | SARS-CoV-2 (COVID-19) S protein IgG Ab [Presence] in Serum or Plasma by Immunoassay | 0.898 |  |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.897 |  |
| 757677 | SARS-CoV-2 (COVID-19) RNA [Presence] in Nose by NAA with probe detection | 0.896 |  |
| 1092311 | SARS-CoV-2 (COVID-19) RNA [Presence] in Specimen | 0.896 |  |
| 706158 | SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.895 |  |
| 723475 | SARS-CoV-2 (COVID-19) IgM Ab [Presence] in Serum or Plasma by Immunoassay | 0.889 |  |
| 3020378 | Complement C1q Ag [Units/volume] in Serum | 0.888 |  |
| 723473 | SARS-CoV-2 (COVID-19) IgA Ab [Presence] in Serum or Plasma by Immunoassay | 0.885 |  |
| 36033643 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.882 |  |
| 723480 | SARS-CoV-2 (COVID-19) Ab [Interpretation] in Serum or Plasma | 0.881 |  |
| 36031949 | Influenza virus A and B and SARS-CoV+SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.881 |  |
| 1091424 | SARS-CoV-2 (COVID-19) IgG Ab [Presence] in Specimen | 0.881 |  |
| 586517 | SARS-CoV-2 (COVID-19) whole genome [Nucleotide sequence] in Isolate or Specimen by Sequencing | 0.872 |  |
| 36661375 | Influenza virus A and B and SARS-CoV-2 (COVID-19) identified in Respiratory system specimen by NAA with probe detection | 0.870 |  |
| 1988397 | SARS-CoV-2 (COVID-19) N protein IgG Ab [Presence] in Serum or Plasma by Immunoassay | 0.867 |  |
| 646531 | Influenza virus A and Influenza virus B and SARS coronavirus 2 and Respiratory syncytial virus Ag panel - Nose by Rapid immunoassay | 0.866 |  |
| 36661377 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by Sequencing | 0.864 |  |
| 3965594 | SARS-CoV-2 (COVID-19) Ag [Presence] in Nasopharynx by Immunofluorescence | 0.854 |  |
| 3033385 | SARS coronavirus [Presence] in Specimen | 0.853 |  |
| 36031213 | SARS-CoV-2 (COVID-19) S gene [Presence] in Respiratory system specimen by Sequencing | 0.850 |  |
| 36661372 | SARS-CoV-2 (COVID-19) IgA Ab [Titer] in Serum or Plasma by Immunofluorescence | 0.847 |  |
| 723465 | SARS-CoV-2 (COVID-19) S gene [Presence] in Respiratory system specimen by NAA with probe detection | 0.839 |  |
| 3026128 | IgM IgM Ab [Units/volume] in Serum or Plasma | 0.836 |  |
| 586521 | SARS-CoV-2 (COVID-19) IgA Ab [Presence] in Serum, Plasma or Blood by Rapid immunoassay | 0.834 |  |
| 3002140 | Complement C1q [Mass/volume] in Serum or Plasma | 0.832 |  |
| 36304336 | Complement C1q.functional [Units/volume] in Serum or Plasma | 0.830 |  |
| 36033652 | SARS-CoV-2 (COVID-19) lineage [Identifier] in Specimen by Molecular genetics method | 0.830 |  |
| 647699 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag [Identifier] in Nose by Rapid immunoassay | 0.821 |  |
| 3020999 | Complement C1q Ag [Moles/volume] in Serum or Plasma | 0.821 |  |
| 3041700 | Complement C1q Ab [Presence] in Serum | 0.817 |  |
| 3022870 | Complement C1q Ag [Units/volume] in Serum or Plasma by Raji cell assay | 0.815 |  |
| 1619029 | SARS-CoV-2 (COVID-19) S protein RBD neutralizing antibody [Units/volume] in Serum or Plasma by Immunoassay | 0.809 |  |
| 3032256 | Immune complex.IgG [Units/volume] in Serum or Plasma by C1q binding assay | 0.809 |  |
| 723476 | SARS-CoV-2 (COVID-19) RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.808 |  |
| 3025552 | Complement C1 esterase inhibitor free IgG Ab [Mass/volume] in Serum or Plasma | 0.808 |  |
| 3006448 | Complement C1 esterase inhibitor bound IgG Ab [Mass/volume] in Serum or Plasma | 0.802 |  |
| 1988376 | SARS-CoV-2 (COVID-19) RdRp gene mutation detected [Identifier] in Specimen by Molecular genetics method | 0.792 |  |
| 36033664 | SARS-CoV-2 (COVID-19) S gene mutation detected [Identifier] in Specimen by Molecular genetics method | 0.791 |  |
| 1989163 | SARS-CoV-2 (COVID-19) lineage [Type] in Specimen by Sequencing | 0.775 |  |
| 36033651 | SARS-CoV-2 (COVID-19) sequencing and identification panel - Specimen by Molecular genetics method | 0.770 |  |
| 36033667 | SARS-CoV-2 (COVID-19) variant [Type] in Specimen by Sequencing | 0.768 |  |
| 645739 | Influenza virus A whole genome segment sequence [Identifier] in Specimen by Sequencing | 0.757 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1564 | -c19agvt |  | 100% | name | 139 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1565 | -covidjt |  | 100% | name | 396 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) [Presence] in Respiratory specimen |
| 1566 | -cv19ag | % | 0% | name+unit | 13 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1567 | -cv19ag | e12/l | 0% | name+unit | 7 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1568 | -cv19ag | e9/l | 0% | name+unit | 19 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1569 | -cv19ag | fl | 0% | name+unit | 8 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1570 | -cv19ag | g/l | 0% | name+unit | 15 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1571 | -cv19ag | mmol/l | 0% | name+unit | 25 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1572 | -cv19ag | pg | 0% | name+unit | 8 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1573 | -cv19ag | u/l | 0% | name+unit | 5 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1574 | -cv19ag | ug/l | 0% | name+unit | 6 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1575 | -cv19ag | umol/l | 0% | name+unit | 6 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1576 | -cv19ag |  | 99% | name | 11991 | 99.09 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1577 | -cv19ag0 |  | 100% | name | 3845 | 100 |  | Panbio COVID-19 Ag Rapid Test, Abbott Rapid Diagnostics |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1578 | -cv19ag1 |  | 100% | name | 504 | 100 |  | Flowflex SARS-CoV-2 Antigen rapid test, ACON Laboratories, Inc |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1579 | -cv19ag2 |  | 100% | name | 204 | 100 |  | mariPOC SARS-CoV-2, ArcDia International Ltd |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1580 | -cv19ag3 |  | 100% | name | 270 | 100 |  | mariPOC Quick Flu+ , ArcDia International Ltd |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1581 | -cv19ag4 |  | 100% | name | 20852 | 100 |  | STANDARD Q COVID-19 Ag, SD BIONSENSOR Inc |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1582 | -cv19ag5 |  | 100% | name | 15481 | 100 |  | SARS-CoV-2 Antigen Rapid Test, Roche (SD BIOSENSOR) |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1583 | -cv19agj |  | 100% | name | 1370 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1584 | -cv19agl |  | 100% | name | 391 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1585 | -cv19nho |  | 100% | name | 891531 | 100 |  | -COVID-19-koronavirustauti, nukleiinihappo (kval) |  |  | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1586 | -cv19pika |  | 100% | name | 8349 | 99.95 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1587 | -cv19vt |  | 100% | name | 1271 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) [Presence] in Respiratory specimen |
| 1588 | b-cv19ab-o |  | 100% | name | 325 | 100 |  |  | Blood | Qualitative test (also semi-quantitative) | SARS-CoV-2 (COVID-19) Ab [Presence] in Serum or Plasma |
| 1589 | b-cv19abg |  | 100% | name | 232 | 100 |  | B -COVID-19 -koronavirustauti, IgG-vasta-aineet | Blood |  | SARS-CoV-2 (COVID-19) IgG Ab [Units/volume] in Serum or Plasma |
| 1590 | b-cv19abm |  | 100% | name | 233 | 100 |  | B -COVID-19 -koronavirustauti, IgM-vasta-aineet | Blood |  | SARS-CoV-2 (COVID-19) IgM Ab [Units/volume] in Serum or Plasma |
| 1591 | cldinho |  | 100% | name | 111 | 100 |  |  |  |  | Chlamydia trachomatis DNA [Presence] in Specimen by NAA with probe detection |
| 1592 | covid-19aghoi |  | 100% | name | 476 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1593 | cv19ag |  | 100% | name | 985 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen |
| 1594 | cv19infrs |  | 100% | name | 7932 | 100 |  |  |  |  | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory specimen by NAA |
| 1595 | cv19nho |  | 100% | name | 71412 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1596 | cv19nhopth |  | 100% | name | 159 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory specimen by NAA with probe detection |
| 1597 | cv19sekv |  | 100% | name | 120 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) whole genome [Identifier] in Respiratory specimen by Sequencing |
| 1598 | oma-covid-o |  | 100% | name | 1391 | 100 |  |  |  | Qualitative test (also semi-quantitative) | SARS-CoV-2 (COVID-19) Ag [Presence] in Nasal specimen by Rapid immunoassay |
| 1599 | p-c1qabg | u/ml | 31% | name+unit | 88 | 0 |  | P-Komplementti C1q, IgG-vasta-aineet | Plasma |  | Complement C1q IgG Ab [Units/volume] in Plasma |
| 1600 | p-c1qabg |  | 69% | name | 195 | 95.38 |  | P-Komplementti C1q, IgG-vasta-aineet | Plasma |  | Complement C1q IgG Ab [Units/volume] in Plasma |
| 1601 | pika-covid-19ag |  | 100% | name | 290 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1602 | s-cv19ab | au/ml | 1% | name+unit | 36 | 100 |  | S -COVID-19 -koronavirustauti, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) Ab [Units/volume] in Serum |
| 1603 | s-cv19ab |  | 99% | name | 3692 | 100 |  | S -COVID-19 -koronavirustauti, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) Ab [Units/volume] in Serum |
| 1604 | s-cv19aba |  | 100% | name | 270 | 100 |  | S -COVID-19 -koronavirustauti, IgA-vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) IgA Ab [Units/volume] in Serum |
| 1605 | s-cv19abg |  | 100% | name | 1259 | 100 |  | S -COVID-19 -koronavirustauti, IgG-vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) IgG Ab [Units/volume] in Serum |
| 1606 | s-cv19abm |  | 100% | name | 101 | 100 |  | S -COVID-19 -koronavirustauti, IgM- vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) IgM Ab [Units/volume] in Serum |
| 1607 | s-cv19abp |  | 100% | name | 153 | 100 |  |  | Serum |  | SARS-CoV-2 (COVID-19) Ab [Units/volume] in Serum |
| 1608 | s-cv19sab | au/ml | 55% | name+unit+values | 149 | 0 | [1.48, 3.94, 139.34, 691.66, 1561.95, 3317.2, 5543.63, 12999.61, 20746] | S -COVID-19-koronavirustauti, piikkiproteiini, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) Spike protein Ab [Units/volume] in Serum |
| 1609 | s-cv19sab | u/ml | 6% | name+unit | 15 | 0 |  | S -COVID-19-koronavirustauti, piikkiproteiini, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) Spike protein Ab [Units/volume] in Serum |
| 1610 | s-cv19sab |  | 39% | name | 106 | 100 |  | S -COVID-19-koronavirustauti, piikkiproteiini, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) Spike protein Ab [Units/volume] in Serum |

