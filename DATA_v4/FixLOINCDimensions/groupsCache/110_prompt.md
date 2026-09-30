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
Here is group 110.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3003714 | Bacteria identified in Wound by Culture | 1.000 | 270 |
| 3009986 | Bacteria identified in Catheter tip by Culture | 1.000 | 946 |
| 3001684 | Respiratory syncytial virus Ag [Presence] in Specimen | 0.987 |  |
| 3013978 | Campylobacter sp identified in Stool by Organism specific culture | 0.984 | 588 |
| 36305818 | Shigella sp identified in Stool by Organism specific culture | 0.978 |  |
| 3004716 | Salmonella sp identified in Stool by Organism specific culture | 0.972 |  |
| 1469856 | Bacteria identified in Mother's milk by Culture | 0.951 |  |
| 3026167 | Bacteria identified in Specimen by Environmental culture | 0.947 |  |
| 3025892 | Trichomonas vaginalis Ag [Presence] in Genital specimen | 0.936 |  |
| 1092302 | Bacteria identified in Surgical wound by Culture | 0.935 |  |
| 3028433 | Virus identified in Specimen by Culture | 0.934 | 655 |
| 3028371 | Actinomyces sp identified in Specimen by Organism specific culture | 0.933 |  |
| 3043814 | Bacteria identified in Wound deep by Culture | 0.932 |  |
| 3020426 | Respiratory syncytial virus Ag [Presence] in Specimen by Immunoassay | 0.932 | 881 |
| 3053028 | Streptococcus sp identified in Specimen by Organism specific culture | 0.932 |  |
| 3026389 | Candida sp identified in Specimen by Organism specific culture | 0.931 |  |
| 3046983 | Nocardia sp identified in Specimen by Organism specific culture | 0.931 |  |
| 3042645 | Salmonella and Shigella sp identified in Stool by Organism specific culture | 0.929 | 587 |
| 3005444 | Respiratory syncytial virus Ag [Presence] in Specimen by Immunofluorescence | 0.926 | 1674 |
| 1176221 | Bacteria identified in Catheter tip by Aerobe culture | 0.926 |  |
| 1761492 | Campylobacter sp [Presence] in Stool by Organism specific culture | 0.923 |  |
| 1175370 | Bacteria identified in Catheter tip by Anaerobe culture | 0.922 |  |
| 3014940 | Shigella sp identified in Specimen by Organism specific culture | 0.922 |  |
| 3002619 | Bacteria identified in Specimen by Culture | 0.917 | 39 |
| 36304759 | Respiratory syncytial virus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.917 |  |
| 46235760 | Methicillin resistant Staphylococcus aureus [Presence] in Pharynx by Organism specific culture | 0.915 |  |
| 3025722 | Staphylococcus sp identified in Specimen by Organism specific culture | 0.911 |  |
| 3033319 | Streptococcus pyogenes Ag [Presence] in Throat | 0.910 | 337 |
| 3013146 | Bacteria identified in Wound by Aerobe culture | 0.908 |  |
| 3012568 | Campylobacter sp identified in Specimen by Organism specific culture | 0.907 |  |
| 1091581 | Methicillin resistant Staphylococcus aureus [Presence] in Skin by Organism specific culture | 0.906 |  |
| 3010254 | Herpes simplex virus identified in Specimen by Organism specific culture | 0.904 | 678 |
| 1259757 | Campylobacter and Salmonella and Shigella sp identified in Stool by Organism specific culture | 0.903 |  |
| 3021508 | Respiratory syncytial virus Ag [Presence] in Throat | 0.901 |  |
| 3024328 | Herpes virus identified in Specimen by Organism specific culture | 0.899 |  |
| 3032246 | Trichomonas vaginalis Ag [Presence] in Vaginal fluid | 0.898 |  |
| 3046856 | Respiratory syncytial virus Ag [Presence] in Nose | 0.896 |  |
| 3027150 | Campylobacter sp identified in Isolate by Organism specific culture | 0.895 |  |
| 1175680 | Candida auris [Presence] in Specimen by Organism specific culture | 0.895 |  |
| 3027969 | Bacteria identified in Wound by Anaerobe culture | 0.894 |  |
| 3024522 | Salmonella sp identified in Specimen by Organism specific culture | 0.894 |  |
| 40771500 | Respiratory syncytial virus Ag [Presence] in Nasopharynx by Immunoassay | 0.893 |  |
| 1091847 | Trichomonas vaginalis [Presence] in Specimen | 0.892 |  |
| 3027190 | Salmonella enteritidis [Presence] in Stool by Organism specific culture | 0.888 |  |
| 43534059 | Respiratory syncytial virus Ag [Presence] in Nasopharynx by Rapid immunoassay | 0.888 |  |
| 3023609 | Respiratory syncytial virus Ag [Presence] in Throat by Immunoassay | 0.887 |  |
| 46236091 | Respiratory syncytial virus Ag [Presence] in Nasopharynx by Immunofluorescence | 0.886 |  |
| 40758230 | Respiratory syncytial virus [Presence] in Specimen by Organism specific culture | 0.886 |  |
| 1091323 | Fungus identified in Catheter tip by Culture | 0.884 |  |
| 3004998 | Trichomonas vaginalis Ag [Presence] in Genital specimen by Immunoassay | 0.884 |  |
| 3015479 | Mycobacterium sp identified in Blood by Organism specific culture | 0.884 | 1870 |
| 37020439 | Respiratory syncytial virus [Presence] in Upper respiratory specimen by Organism specific culture | 0.884 |  |
| 3005702 | Mycobacterium sp identified in Specimen by Organism specific culture | 0.883 | 425 |
| 1091465 | Bacteria # 2 identified in Catheter tip by Aerobe culture | 0.880 |  |
| 3020227 | Campylobacter sp identified in Blood by Organism specific culture | 0.880 |  |
| 36305181 | Actinomyces sp identified in Tissue by Organism specific culture | 0.879 |  |
| 3006418 | Campylobacter sp identified in Tissue by Organism specific culture | 0.879 |  |
| 1259619 | Campylobacter and Salmonella and Shigella and Yersinia sp identified in Stool by Organism specific culture | 0.878 |  |
| 3013430 | Campylobacter sp identified in Body fluid by Organism specific culture | 0.877 |  |
| 37019563 | Respiratory syncytial virus [Presence] in Lower respiratory specimen by Organism specific culture | 0.876 |  |
| 3042631 | Mycobacterium sp identified in Specimen | 0.876 |  |
| 1091909 | Bacteria # 2 identified in Catheter tip by Anaerobe culture | 0.875 |  |
| 1176155 | Actinomyces sp identified in Aspirate by Organism specific culture | 0.875 |  |
| 3035133 | Fungus identified in Wound by Culture | 0.874 |  |
| 3020635 | Virus # 2 identified in Specimen by Culture | 0.873 |  |
| 1259916 | Salmonella and Shigella and Campylobacter and E. coli sp identified in Stool by Organism specific culture | 0.872 |  |
| 3015409 | Nocardia sp identified in Isolate by Organism specific culture | 0.872 |  |
| 1761558 | Vancomycin resistant enterococcus [Identifier] in Specimen by Organism specific culture | 0.870 |  |
| 3023899 | Escherichia coli shiga-like toxin identified in Stool by Organism specific culture | 0.870 |  |
| 3017227 | Bacteria identified in Wound deep by Anaerobe culture | 0.869 |  |
| 3032530 | Salmonella and Shigella sp identified in Specimen by Organism specific culture | 0.869 |  |
| 3018368 | Bacteria identified in Wound deep by Aerobe culture | 0.869 |  |
| 3021732 | Shigella sp identified in Feed by Organism specific culture | 0.868 |  |
| 3025633 | Candida sp identified in Saliva (oral fluid) by Organism specific culture | 0.868 |  |
| 3012167 | Candida sp identified in Stool by Organism specific culture | 0.868 |  |
| 3004178 | Mycobacterium sp identified in Urine by Organism specific culture | 0.867 |  |
| 1091623 | Bacteria # 3 identified in Catheter tip by Anaerobe culture | 0.866 |  |
| 1092431 | Bacteria # 3 identified in Catheter tip by Aerobe culture | 0.866 |  |
| 42529408 | Campylobacter sp [Presence] in Stool by Culture | 0.866 |  |
| 3044254 | Respiratory syncytial virus RNA [Presence] in Specimen by NAA with probe detection | 0.865 |  |
| 3045560 | Bacteria # 2 identified in Specimen by Culture | 0.865 |  |
| 3014536 | Streptococcus agalactiae Ag [Presence] in Throat | 0.864 |  |
| 1092081 | Respiratory syncytial virus RNA [Presence] in Specimen by Molecular genetics method | 0.864 |  |
| 3007473 | Trichomonas vaginalis Ag [Presence] in Genital specimen by Immunofluorescence | 0.863 |  |
| 37020053 | Nocardia sp identified in Aspirate by Organism specific culture | 0.862 |  |
| 3039355 | Methicillin resistant Staphylococcus aureus [Presence] in Nose by Organism specific culture | 0.862 |  |
| 40765191 | Herpes simplex virus and Varicella zoster virus identified in Specimen by Organism specific culture | 0.862 |  |
| 3043867 | Bacteria # 8 identified in Specimen by Culture | 0.862 |  |
| 3044670 | Neisseria sp identified in Specimen by Organism specific culture | 0.862 |  |
| 3036675 | Virus # 3 identified in Specimen by Culture | 0.862 |  |
| 3005156 | Respiratory syncytial virus A RNA [Presence] in Specimen by NAA with probe detection | 0.861 |  |
| 3045058 | Bacteria # 3 identified in Specimen by Culture | 0.860 |  |
| 3046647 | Bacteria # 4 identified in Specimen by Culture | 0.860 |  |
| 3015969 | Actinobacillus sp identified in Specimen by Organism specific culture | 0.859 |  |
| 1176383 | Actinomyces sp identified in Lower respiratory specimen by Organism specific culture | 0.859 |  |
| 3019902 | Methicillin resistant Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.858 | 146 |
| 3028334 | Neisseria gonorrhoeae [Presence] in Specimen by Organism specific culture | 0.857 | 1609 |
| 3044537 | Virus identified in Genital specimen by Culture | 0.857 |  |
| 1176258 | Nocardia sp identified in Lower respiratory specimen by Organism specific culture | 0.857 |  |
| 3045634 | Herpes simplex virus identified in Specimen by Shell vial culture | 0.857 |  |
| 3028116 | Herpes simplex virus identified in Genital specimen by Organism specific culture | 0.856 |  |
| 3046136 | Bacteria # 7 identified in Specimen by Culture | 0.856 |  |
| 3005296 | Entamoeba histolytica [Presence] in Stool by Trichrome stain | 0.855 |  |
| 3053312 | Staphylococcus aureus Panton-Valentine leukocidin gene [Presence] in Isolate or Specimen by Molecular genetics method | 0.855 |  |
| 3044420 | Bacteria # 6 identified in Specimen by Culture | 0.855 |  |
| 3051608 | Shigella sp [Presence] in Specimen by Organism specific culture | 0.855 |  |
| 3024461 | Microorganism identified in Specimen by Culture | 0.854 |  |
| 3004761 | Bacteria identified in Water by Culture | 0.853 |  |
| 3042263 | Yeast identified in Genital specimen by Organism specific culture | 0.853 |  |
| 3014137 | Bacteria identified in Wound shallow by Aerobe culture | 0.853 |  |
| 3038154 | Virus identified in Tissue by Culture | 0.851 |  |
| 42529406 | Shigella sp [Presence] in Stool by Culture | 0.851 |  |
| 1469525 | Bacteria identified in Pus by Culture | 0.851 |  |
| 3027247 | Bacteria identified in Specimen | 0.851 |  |
| 3017339 | Salmonella sp identified in Tissue by Organism specific culture | 0.849 |  |
| 3043578 | Bacteria # 5 identified in Specimen by Culture | 0.848 |  |
| 3044790 | Chlamydia sp identified in Vaginal fluid by Organism specific culture | 0.848 |  |
| 3001098 | Virus identified in Isolate by Culture | 0.848 |  |
| 3043183 | Mycobacterium sp # 2 identified in Specimen by Organism specific culture | 0.848 |  |
| 3005074 | Virus identified in Blood by Culture | 0.848 |  |
| 3027244 | Fungus identified in Specimen by Environmental culture | 0.846 |  |
| 3045340 | Mycobacterium sp # 4 identified in Specimen by Organism specific culture | 0.846 |  |
| 3042975 | Streptococcus sp identified in Isolate by Organism specific culture | 0.846 |  |
| 3006928 | Escherichia coli enterotoxic identified in Stool by Organism specific culture | 0.846 |  |
| 3008871 | Neisseria gonorrhoeae [Presence] in Genital specimen by Organism specific culture | 0.846 |  |
| 46236184 | Clostridium perfringens [Presence] in Specimen by Organism specific culture | 0.843 |  |
| 1989444 | Band form neutrophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.843 |  |
| 3028793 | Virus identified in Specimen | 0.841 |  |
| 3047316 | Mycobacterium sp # 3 identified in Specimen by Organism specific culture | 0.841 |  |
| 3023601 | Vancomycin resistant enterococcus [Presence] in Specimen by Organism specific culture | 0.840 |  |
| 3044978 | Mycobacterium sp # 5 identified in Specimen by Organism specific culture | 0.840 |  |
| 3001465 | Band form neutrophils [#/volume] in Blood by Automated count | 0.839 |  |
| 3043973 | Virus identified in Body fluid by Culture | 0.839 |  |
| 1092208 | Mycobacterium sp identified in Stool by Organism specific culture | 0.838 |  |
| 3027544 | Mycobacterium sp identified in Sputum by Organism specific culture | 0.838 |  |
| 3013867 | Bacteria identified in Specimen by Aerobe culture | 0.838 | 276 |
| 3044413 | Neisseria sp identified in Urethra by Organism specific culture | 0.838 | 3000 |
| 3036393 | Herpes simplex virus identified in Tissue by Organism specific culture | 0.838 |  |
| 1175708 | Actinomyces sp identified in Implanted device by Organism specific culture | 0.836 |  |
| 1761890 | Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.836 |  |
| 37019895 | Staphylococcus sp identified in Isolate by Organism specific culture | 0.834 |  |
| 46236183 | Bacillus cereus [Presence] in Specimen by Organism specific culture | 0.834 |  |
| 3025941 | Bacteria identified in Stool by Culture | 0.834 | 469 |
| 37020336 | Herpes simplex virus identified in Aspirate by Organism specific culture | 0.834 |  |
| 3035839 | Band form neutrophils/Leukocytes in Blood by Automated count | 0.834 |  |
| 3043836 | Herpes virus identified in Specimen by Shell vial culture | 0.833 |  |
| 3028072 | Vibrio sp identified in Stool by Organism specific culture | 0.833 |  |
| 3035834 | Herpes simplex virus identified in Urine by Organism specific culture | 0.833 |  |
| 21492393 | Bacteria identified in Implanted device by Culture | 0.833 |  |
| 36659777 | Mycobacterial stain and culture panel - Specimen | 0.832 |  |
| 36304786 | Virus identified in Lower respiratory specimen by Culture | 0.831 |  |
| 1469798 | Fungus identified in Vaginal fluid by Culture | 0.831 |  |
| 3024901 | Mycobacterium sp identified in Bronchial specimen by Organism specific culture | 0.830 |  |
| 3009171 | Fungus identified in Blood by Culture | 0.829 | 1476 |
| 646199 | Trichomonas vaginalis Ag [Measurement] in Genital specimen | 0.827 |  |
| 3023368 | Bacteria identified in Blood by Culture | 0.826 | 131 |
| 21491660 | Streptococcus pyogenes Ag [Presence] in Throat by Rapid immunoassay | 0.826 | 1051 |
| 1175764 | Mycobacterium sp identified in Specimen by Sequencing | 0.824 |  |
| 40767123 | Mycobacterium sp [Presence] in Blood by Organism specific culture | 0.823 |  |
| 3027809 | Neisseria gonorrhoeae [Presence] in Urethra by Organism specific culture | 0.822 | 3000 |
| 36303984 | Clostridium botulinum [Presence] in Stool by Organism specific culture | 0.820 |  |
| 3000494 | Fungus identified in Specimen by Culture | 0.820 | 328 |
| 40762244 | Vancomycin resistant enterococcus [Presence] in Urine by Organism specific culture | 0.820 |  |
| 1617249 | Fungus and Mycobacterium sp identified in Blood by Organism specific culture | 0.819 |  |
| 3050209 | Cryptococcus sp identified in Specimen by Organism specific culture | 0.817 |  |
| 3045744 | Candida sp identified in Vaginal fluid by Cyto stain | 0.817 |  |
| 3013566 | Clostridioides difficile [Presence] in Stool by Organism specific culture | 0.816 |  |
| 3014506 | Trichomonas vaginalis [Presence] in Genital specimen by Wet preparation | 0.816 | 824 |
| 46235279 | Trichomonas vaginalis [Presence] in Specimen by Gram stain | 0.816 |  |
| 1175365 | Mycobacterium sp identified in Lower respiratory specimen by Organism specific culture | 0.816 |  |
| 3047204 | Trichomonas vaginalis [Presence] in Specimen by Wet preparation | 0.815 | 1421 |
| 3024483 | Escherichia coli verotoxic identified in Stool by Organism specific culture | 0.814 |  |
| 3006210 | Bacteria identified in Milk by Aerobe culture | 0.813 |  |
| 3024536 | Nuclear Ab pattern [Interpretation] in Serum by Immunofluorescence | 0.812 | 925 |
| 1092070 | Trichomonas vaginalis [Presence] in Urine sediment | 0.812 |  |
| 1176346 | Nocardia sp identified in Implanted device by Organism specific culture | 0.812 |  |
| 43055369 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.811 |  |
| 3038614 | Chromosomal nuclear Ab pattern [Presence] in Serum by Immunofluorescence | 0.811 |  |
| 37020517 | Yeast identified in Upper respiratory specimen by Organism specific culture | 0.809 |  |
| 43055363 | Band form neutrophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.809 |  |
| 3008342 | Neutrophils/Leukocytes in Blood by Automated count | 0.809 | 25 |
| 3008258 | Mycobacterium sp identified in Body fluid by Organism specific culture | 0.809 |  |
| 3050898 | Methicillin resistant Staphylococcus aureus [Presence] in Genital specimen by Organism specific culture | 0.807 |  |
| 40762243 | Vancomycin resistant enterococcus [Presence] in Anal by Organism specific culture | 0.807 |  |
| 1091745 | Staphylococcus sp identified in Specimen | 0.806 |  |
| 3042752 | Neisseria sp identified in Cervix by Organism specific culture | 0.806 |  |
| 3023419 | Bacteria identified in Sputum by Culture | 0.804 | 1768 |
| 3026008 | Bacteria identified in Urine by Culture | 0.804 | 93 |
| 3043185 | Neisseria sp identified in Anal by Organism specific culture | 0.804 |  |
| 1091253 | Methicillin resistant Staphylococcus aureus [Presence] in Axilla by Organism specific culture | 0.803 |  |
| 3034583 | Herpes simplex virus identified in Vaginal fluid by Organism specific culture | 0.802 |  |
| 3009000 | Neisseria gonorrhoeae [Presence] in Conjunctival specimen by Organism specific culture | 0.801 | 3000 |
| 37020456 | Neisseria gonorrhoeae [Presence] in Aspirate by Organism specific culture | 0.801 |  |
| 3016981 | Virus identified in Sputum by Culture | 0.801 |  |
| 3008939 | Band form neutrophils [#/volume] in Blood by Manual count | 0.801 | 347 |
| 3012431 | Thermophilic Actinomycetes identified in Specimen by Organism specific culture | 0.801 |  |
| 3045469 | Band form neutrophils [Presence] in Blood by Automated count | 0.800 | 1297 |
| 3010088 | Chlamydia sp identified in Genital specimen by Organism specific culture | 0.799 |  |
| 1761571 | Yeast and Candida sp identification panel - Specimen by Organism specific culture | 0.799 |  |
| 3015241 | Mycobacterium sp identified in Aspirate by Organism specific culture | 0.799 |  |
| 3011116 | Haemophilus sp identified in Specimen by Organism specific culture | 0.798 |  |
| 40761514 | Nucleated erythrocytes/Leukocytes [Ratio] in Blood by Automated count | 0.798 | 326 |
| 3017611 | Mycoplasma sp identified in Specimen by Organism specific culture | 0.797 |  |
| 3014765 | Yersinia sp identified in Stool by Organism specific culture | 0.797 |  |
| 3007161 | Mycobacterium sp identified in Bone marrow by Organism specific culture | 0.796 |  |
| 3038950 | Acinetobacter sp multidrug resistant identified in Specimen by Organism specific culture | 0.796 |  |
| 36659876 | Respiratory viral pathogens DNA and RNA panel - Lower respiratory specimen by NAA with probe detection | 0.796 |  |
| 3042547 | Nuclear matrix Ab pattern [Presence] in Serum by Immunofluorescence | 0.795 |  |
| 37020541 | Yeast identified in Isolate by Organism specific culture | 0.794 |  |
| 647010 | Streptococcus pyogenes Ag [Measurement] in Throat | 0.794 |  |
| 1469540 | Mycobacterium sp identified in Skin by Organism specific culture | 0.793 |  |
| 3034171 | Yeast [Presence] in Specimen by Organism specific culture | 0.793 | 1855 |
| 3011588 | Microscopic observation [Identifier] in Sputum by Acid fast stain | 0.792 |  |
| 3017364 | Streptococcus pyogenes Ag [Presence] in Throat by Immunofluorescence | 0.792 |  |
| 3041732 | Fungus identified in Genital specimen by Culture | 0.791 |  |
| 3035538 | Herpes simplex virus identified in Bronchial specimen by Organism specific culture | 0.791 |  |
| 42527956 | Other nuclear IgG pattern [Titer] in Serum by Immunofluorescence | 0.789 |  |
| 3008051 | Streptococcus pyogenes Ag [Presence] in Specimen | 0.789 |  |
| 706162 | Respiratory viral pathogens DNA and RNA panel - Respiratory system specimen Qualitative by NAA with probe detection | 0.789 |  |
| 3050605 | Nucleolar nuclear Ab pattern [Presence] in Serum by Immunofluorescence | 0.788 |  |
| 36305460 | Bordetella sp identified in Nasopharynx by Organism specific culture | 0.788 |  |
| 36660725 | Microscopic observation [Presence] in Sputum by Acid fast stain --3rd specimen | 0.788 |  |
| 1176136 | Gardnerella vaginalis [Presence] in Vaginal fluid by Organism specific culture | 0.788 |  |
| 3034456 | Yeast [Presence] in Genital specimen by Organism specific culture | 0.787 |  |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.786 |  |
| 3005988 | Vibrio sp identified in Specimen by Organism specific culture | 0.786 |  |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.785 |  |
| 3037470 | Ureaplasma sp identified in Specimen by Organism specific culture | 0.785 |  |
| 37020245 | Staphylococcus species methicillin resistant identified in Isolate or Specimen by Molecular genetics method | 0.784 |  |
| 3050143 | Nuclear Ab pattern [Interpretation] in Serum by Immunofluorescence Narrative | 0.784 |  |
| 37020688 | Human metapneumovirus and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.783 |  |
| 3050917 | Atypic speckled nuclear Ab pattern [Presence] in Serum by Immunofluorescence | 0.783 |  |
| 3038101 | Streptococcus agalactiae Ag [Presence] in Throat by Immunofluorescence | 0.783 |  |
| 43054991 | Microscopic observation [Presence] in Specimen by Acid fast stain | 0.782 |  |
| 3015055 | Bacteria identified in Amniotic fluid by Culture | 0.782 |  |
| 3041935 | Fine speckled nuclear Ab pattern [Titer] in Serum by Immunofluorescence | 0.782 |  |
| 37020812 | Human metapneumovirus and Respiratory syncytial virus RNA panel - Lower respiratory specimen by NAA with probe detection | 0.781 |  |
| 37021212 | Respiratory pathogens DNA and RNA panel - Respiratory system specimen by NAA with probe detection | 0.780 |  |
| 36303760 | Microscopic observation [Presence] in Pleural fluid by Acid fast stain | 0.780 |  |
| 3042671 | Burkholderia sp identified in Specimen by Organism specific culture | 0.780 |  |
| 40758231 | Respiratory pathogens panel - Specimen by Organism specific culture | 0.779 |  |
| 21491103 | Multiple drug resistant gram negative organism [Identifier] in Specimen by Culture | 0.779 |  |
| 3043237 | Aspergillus sp identified in Specimen by Organism specific culture | 0.778 |  |
| 1175485 | Acinetobacter sp identified in Specimen by Organism specific culture | 0.778 |  |
| 3019415 | Bacteria identified in Food by Culture | 0.778 |  |
| 3039212 | Fine speckled nuclear Ab pattern [Presence] in Serum by Immunofluorescence | 0.777 |  |
| 3050594 | Chromosomal nuclear Ab pattern [Titer] in Serum by Immunofluorescence | 0.777 |  |
| 3005910 | Mycobacterium avium ss paratuberculosis [Presence] in Stool by Acid fast stain.Ziehl-Neelsen | 0.776 |  |
| 46234883 | Staphylococcus aureus sau3AI gene [Presence] in Swab specimen by NAA with probe detection | 0.776 |  |
| 36659990 | Microscopic observation [Presence] in Sputum by Acid fast stain --2nd specimen | 0.776 |  |
| 647875 | Respiratory pathogens DNA and RNA panel - Specimen by NAA with non-probe detection | 0.775 |  |
| 43533858 | Bacteria.extended spectrum beta lactamase resistance [Identifier] in Anal by Organism specific culture | 0.774 |  |
| 36304271 | Microscopic observation [Presence] in Lower respiratory specimen by Acid fast stain.Kinyoun | 0.771 |  |
| 1092180 | Entamoeba histolytica DNA [Presence] in Stool | 0.771 |  |
| 36659824 | Bacteria.carbapenem resistant identified in Specimen by Organism specific culture | 0.771 |  |
| 1091341 | Vancomycin resistant enterococcus [Presence] in Specimen | 0.770 |  |
| 3045617 | Chlamydia sp identified in Nasopharynx by Organism specific culture | 0.769 |  |
| 36304167 | Respiratory pathogens panel - Nasopharynx by Immunofluorescence | 0.769 |  |
| 3003551 | Influenza virus A Ag [Presence] in Throat | 0.768 |  |
| 3047233 | Neisseria sp identified in Throat by Organism specific culture | 0.768 |  |
| 1175890 | Mycobacterium preliminary growth [Presence] in Sputum by Organism specific culture | 0.767 |  |
| 3038590 | Bacteria identified in Semen by Culture | 0.767 |  |
| 1761466 | Staph aureus and MRSA screening panel - Specimen by Organism specific culture | 0.767 |  |
| 3039197 | Mycobacterium sp identified in Pleural fluid by Organism specific culture | 0.766 |  |
| 36304858 | Microscopic observation [Presence] in Isolate by Acid fast stain | 0.765 |  |
| 3010629 | Chlamydia sp identified in Throat by Organism specific culture | 0.765 |  |
| 3034361 | Cryptosporidium sp [Presence] in Specimen by Acid fast stain | 0.765 |  |
| 43533982 | Bacteria identified in Mouth by Culture | 0.765 |  |
| 3005012 | Respiratory Mycoplasma identified in Throat by Organism specific culture | 0.765 |  |
| 3000450 | Mycobacterium avium ss paratuberculosis [Presence] in Tissue by Acid fast stain.Ziehl-Neelsen | 0.764 |  |
| 3049146 | Mycoplasma sp identified in Urine by Organism specific culture | 0.763 |  |
| 1092318 | Mycobacterium sp identified in Pus by Organism specific culture | 0.762 |  |
| 645112 | Stenotrophomonas maltophilia.multidrug resistant [Presence] in Specimen by Organism specific culture | 0.761 |  |
| 3016727 | Bacteria identified in Body fluid by Culture | 0.760 | 1786 |
| 37020690 | Gram negative bacilli identified in Isolate by Organism specific culture | 0.760 |  |
| 1469829 | Mycobacterium sp identified in Semen by Organism specific culture | 0.759 |  |
| 3000924 | Streptococcus pyogenes [Presence] in Throat by Organism specific culture | 0.758 |  |
| 21492788 | Serial sputum smears for diagnosing pulmonary tuberculosis panel - by Acid fast stain | 0.757 |  |
| 3030526 | Mycobacterium sp [Presence] in Specimen by Organism specific culture | 0.756 |  |
| 3016439 | Virus identified in Urine by Culture | 0.755 |  |
| 40764165 | Staphylococcus aureus DNA [Presence] in Specimen by NAA with probe detection | 0.754 |  |
| 3022193 | Influenza virus A+B Ag [Presence] in Throat | 0.754 |  |
| 40766210 | Pseudomonas aeruginosa.multidrug resistant isolate [Presence] in Specimen by Organism specific culture | 0.753 |  |
| 1761484 | Gram negative bacteria.colistin resistant identified in Stool by Organism specific culture | 0.752 |  |
| 1761775 | Enterobacteriaceae.extended spectrum beta lactamase resistance phenotype [Identifier] in Specimen by Organism specific culture | 0.751 |  |
| 36659989 | Staphylococcus aureus DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.751 |  |
| 1091951 | Staphylococcus sp DNA [Presence] in Specimen by NAA with probe detection | 0.749 |  |
| 3028018 | Entamoeba histolytica Ag [Presence] in Stool by Immunoassay | 0.748 |  |
| 3964720 | Bacteria.extended spectrum beta lactamase (ESBL) [Presence] in Stool based on lab data | 0.741 |  |
| 3966166 | Staphylococcus aureus DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.741 |  |
| 1091649 | Staphylococcus aureus DNA [Presence] in Specimen by Molecular genetics method | 0.739 |  |
| 42869541 | Staphylococcus aureus exfoliative toxin A eta gene [Presence] in Specimen by NAA with probe detection | 0.739 |  |
| 46234878 | Streptococcus pneumoniae nanA gene [Presence] in Swab specimen by NAA with probe detection | 0.738 |  |
| 3047049 | Staphylococcus aureus toxic shock syndrome toxin gene [Presence] in Specimen by NAA with probe detection | 0.735 |  |
| 1176246 | Microscopic observation [Identifier] in Lower respiratory specimen by Acid fast stain | 0.735 |  |
| 43533857 | Bacteria.carbapenem resistant identified in Anal by Organism specific culture | 0.734 |  |
| 1175839 | Microscopic observation [Identifier] in Upper respiratory specimen by Acid fast stain | 0.731 |  |
| 3019883 | Entamoeba histolytica Ab [Presence] in Serum | 0.727 |  |
| 3036500 | Entamoeba histolytica DNA [Presence] in Specimen by NAA with probe detection | 0.726 |  |
| 37020799 | Gram positive bacilli identified in Isolate by Organism specific culture | 0.724 |  |
| 3032808 | Multiple drug resistant organism identified in Urine | 0.720 |  |
| 3009070 | Entamoeba sp Ab [Presence] in Serum | 0.709 |  |
| 42868764 | Entamoeba histolytica+Entamoeba dispar+Entamoeba ecuadoriensis+Entamoeba nuttalli DNA [Presence] in Specimen by NAA with probe detection | 0.709 |  |
| 3013799 | Entamoeba histolytica Ag [Units/volume] in Specimen | 0.708 |  |
| 36659890 | Mycobacterial identification panel - Specimen by Molecular genetics method | 0.707 |  |
| 40760040 | Entamoeba histolytica Ab [Presence] in Serum by Immunofluorescence | 0.705 |  |
| 646804 | Entamoeba histolytica Ag [Measurement] in Stool | 0.705 |  |
| 3037952 | Mycoplasma sp and Ureaplasma sp panel - Specimen by Organism specific culture | 0.686 |  |
| 36306120 | Microbiology CNAMTS panel - Sputum | 0.680 |  |
| 44786924 | Mycobacterium tuberculosis stimulated gamma interferon and spot count panel - Blood | 0.672 |  |
| 3018821 | Respiratory Mycoplasma identified in Sputum by Organism specific culture | 0.672 |  |
| 3019711 | Mycobacterium sp DNA [Presence] in Sputum by NAA with probe detection | 0.671 |  |
| 36305032 | Tobacco use panel | 0.610 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1731 | -activi |  | 100% | name | 523 | 100 |  | -Actinomyces, viljely |  |  | Actinomyces identified in Unspecified specimen by Organism specific culture |
| 1732 | -amebvr |  | 100% | name | 732 | 100 |  | -Ameeba, värjäys (trofozoiitit) |  |  | Entamoeba histolytica trophozoite [Presence] in Unspecified specimen by Stain |
| 1733 | -caauvi |  | 100% | name | 468 | 100 |  | -Candida auris, viljely |  |  | Candida auris identified in Unspecified specimen by Organism specific culture |
| 1734 | -cand-vi |  | 100% | name | 285 | 100 |  |  |  | Culture | Candida identified in Unspecified specimen by Organism specific culture |
| 1735 | -candvi |  | 100% | name | 9492 | 100 |  | -Hiiva, viljely |  |  | Yeast identified in Unspecified specimen by Culture |
| 1736 | -em-bl |  | 100% | name | 104 | 100 |  |  |  |  |  |
| 1737 | -ervr |  | 100% | name | 185 | 100 |  |  |  |  |  |
| 1738 | -esblvi |  | 100% | name | 2644 | 100 |  | -Bakteeri, laajakirjoista beta-laktamaasia tuottava, viljely |  |  | Bacteria.ESBL producing identified in Unspecified specimen by Culture |
| 1739 | -gcvi |  | 100% | name | 2115 | 100 |  | -Neisseria gonorrhoeae, viljely |  |  | Neisseria gonorrhoeae identified in Unspecified specimen by Organism specific culture |
| 1740 | -hsvpvi |  | 100% | name | 1154 | 100 |  | -Herpes simplex -virus, pikaviljely |  |  | Herpes simplex virus identified in Unspecified specimen by Rapid culture |
| 1741 | -hsvvi |  | 100% | name | 1451 | 100 |  | -Herpes simplex -virus, viljely |  |  | Herpes simplex virus identified in Unspecified specimen by Culture |
| 1742 | -hygvi |  | 100% | name | 276 | 100 |  | -Hygienianäyte, viljely |  |  | Bacteria identified in Environmental specimen by Culture |
| 1743 | -ifkuvio |  | 100% | name | 330 | 100 |  |  |  |  | Nuclear antibody staining pattern [Type] in Serum by Immunofluorescence |
| 1744 | -kat-vi |  | 100% | name | 205 | 100 |  |  |  | Culture | Bacteria identified in Catheter tip by Culture |
| 1745 | -mdrsjvi |  | 100% | name | 152 | 100 |  | -Moniresistentit gramnegatiiviset sauvat, jatkoviljely |  |  | Gram negative bacilli.multidrug resistant identified in Unspecified specimen by Culture |
| 1746 | -mdrsvi |  | 100% | name | 4893 | 100 |  | -Moniresistentit gramnegatiiviset sauvat, viljely |  |  | Gram negative bacilli.multidrug resistant identified in Unspecified specimen by Culture |
| 1747 | -mrsajvi |  | 100% | name | 143 | 100 |  | -Staphylococcus aureus, metisilliiniresistentti, jatkoviljely |  |  | Staphylococcus aureus.methicillin resistant identified in Unspecified specimen by Organism specific culture |
| 1748 | -mrsavi |  | 100% | name | 147348 | 100 |  | -Staphylococcus aureus, metisilliiniresistenssi viljely |  |  | Staphylococcus aureus.methicillin resistant identified in Unspecified specimen by Organism specific culture |
| 1749 | -mrsavine |  | 100% | name | 825 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Unspecified specimen by Organism specific culture |
| 1750 | -mrsavini |  | 100% | name | 835 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Unspecified specimen by Organism specific culture |
| 1751 | -mrsrivi |  | 100% | name | 260 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Unspecified specimen by Organism specific culture |
| 1752 | -nocavi |  | 100% | name | 2268 | 100 |  | -Nokardia, viljely |  |  | Nocardia identified in Unspecified specimen by Organism specific culture |
| 1753 | -palovvi |  | 100% | name | 704 | 100 |  |  |  |  | Bacteria identified in Wound by Culture |
| 1754 | -psvs |  | 100% | name | 161 | 100 |  |  |  |  |  |
| 1755 | -respvt |  | 100% | name | 1271 | 100 |  |  |  |  | Respiratory virus panel - Respiratory specimen |
| 1756 | -rsv |  | 100% | name | 220 | 100 |  |  |  |  | Respiratory syncytial virus Ag [Presence] in Respiratory specimen |
| 1757 | -rsvvt |  | 100% | name | 1271 | 100 |  |  |  |  | Respiratory syncytial virus [Presence] in Respiratory specimen |
| 1758 | -staupvl |  | 100% | name | 146 | 100 |  |  |  |  | Staphylococcus aureus.Panton-Valentine leukocidin gene [Presence] in Unspecified specimen by NAA |
| 1759 | -stauvi |  | 100% | name | 681 | 100 |  |  |  |  | Staphylococcus aureus identified in Unspecified specimen by Organism specific culture |
| 1760 | -strag |  | 100% | name | 276 | 100 |  | -Streptococcus, antigeeni |  |  | Streptococcus group A Ag [Presence] in Throat |
| 1761 | -strjvi |  | 100% | name | 4196 | 100 |  | -Streptococcus, jatkoviljely (seulottu näyte) |  |  | Streptococcus identified in Unspecified specimen by Organism specific culture |
| 1762 | -strvi |  | 100% | name | 1015 | 100 |  |  |  |  | Streptococcus identified in Unspecified specimen by Organism specific culture |
| 1763 | -tbevi |  | 100% | name | 4326 | 100 |  | -Mycobacterium, erikoisviljely |  |  | Mycobacterium identified in Unspecified specimen by Culture |
| 1764 | -tbpvr |  | 100% | name | 395 | 100 |  |  |  |  | Mycobacterium tuberculosis [Presence] in Unspecified specimen by Acid fast stain |
| 1765 | -tbvi |  | 100% | name | 25319 | 100 |  | -Mycobacterium tuberculosis, viljely |  |  | Mycobacterium tuberculosis identified in Unspecified specimen by Culture |
| 1766 | -tbvivr |  | 100% | name | 131 | 100 |  |  |  |  | Mycobacterium tuberculosis smear and culture panel - Unspecified specimen |
| 1767 | -tbvr |  | 100% | name | 14513 | 100 |  | -Mycobacterium tuberculosis, värjäys |  |  | Mycobacterium tuberculosis [Presence] in Unspecified specimen by Acid fast stain |
| 1768 | -tbvrvi |  | 100% | name | 9619 | 100 |  |  |  |  | Mycobacterium tuberculosis smear and culture panel - Unspecified specimen |
| 1769 | -trvaag |  | 100% | name | 740 | 100 |  | -Trichomonas vaginalis, antigeeni |  |  | Trichomonas vaginalis Ag [Presence] in Unspecified specimen |
| 1770 | -vi |  | 100% | name | 110 | 100 |  |  |  | Culture | Bacteria identified in Unspecified specimen by Culture |
| 1771 | -virvi |  | 100% | name | 1652 | 100 |  | -Virus, viljely |  |  | Virus identified in Unspecified specimen by Culture |
| 1772 | -vrevi |  | 100% | name | 10787 | 100 |  | -Enterokokki, vankomysiiniresistentti, viljely |  |  | Enterococcus.vancomycin resistant identified in Unspecified specimen by Organism specific culture |
| 1773 | -väri |  | 100% | name | 1665 | 100 |  |  |  |  |  |
| 1774 | 1.savuk | u | 77% | name+unit+values | 83 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 10] |  |  |  | Cigarettes smoked [#] by Report |
| 1775 | 1.savuk |  | 23% | name | 25 | 100 |  |  |  |  | Cigarettes smoked [#] by Report |
| 1776 | b-tbevi |  | 100% | name | 1076 | 100 |  | B -Mycobacterium, erikoisviljely | Blood |  | Mycobacterium identified in Blood by Culture |
| 1777 | candvi |  | 100% | name | 508 | 100 |  |  |  |  | Candida identified in Unspecified specimen by Organism specific culture |
| 1778 | ex-tbvi |  | 100% | name | 7823 | 100 |  | Ex-Mycobacterium tuberculosis, viljely | Expectorate (sputum) |  | Mycobacterium tuberculosis identified in Sputum by Culture |
| 1779 | ex-tbvivr |  | 100% | name | 807 | 100 |  |  | Expectorate (sputum) |  | Mycobacterium tuberculosis smear and culture panel - Sputum |
| 1780 | ex-tbvr |  | 100% | name | 853 | 100 |  |  | Expectorate (sputum) |  | Mycobacterium tuberculosis [Presence] in Sputum by Acid fast stain |
| 1781 | ex-tbvrvi |  | 100% | name | 15922 | 100 |  |  | Expectorate (sputum) |  | Mycobacterium tuberculosis smear and culture panel - Sputum |
| 1782 | f-aurvi |  | 100% | name | 116 | 100 |  |  | Feces |  | Staphylococcus aureus identified in Stool by Organism specific culture |
| 1783 | f-bacevi |  | 100% | name | 114 | 100 |  |  | Feces |  | Bacillus cereus identified in Stool by Organism specific culture |
| 1784 | f-camp-vi |  | 100% | name | 167 | 100 |  |  | Feces | Culture | Campylobacter identified in Stool by Organism specific culture |
| 1785 | f-campvi |  | 100% | name | 14627 | 100 |  | F -Campylobacter, viljely | Feces |  | Campylobacter identified in Stool by Organism specific culture |
| 1786 | f-cereuvi |  | 100% | name | 198 | 100 |  |  | Feces |  | Bacillus cereus identified in Stool by Organism specific culture |
| 1787 | f-clpevi |  | 100% | name | 114 | 100 |  |  | Feces |  | Clostridium perfringens identified in Stool by Organism specific culture |
| 1788 | f-salm-vi |  | 100% | name | 607 | 100 |  |  | Feces | Culture | Salmonella identified in Stool by Organism specific culture |
| 1789 | f-salmvi | form | 0% | name+unit | 18 | 0 |  | F -Salmonella, viljely | Feces |  | Salmonella identified in Stool by Organism specific culture |
| 1790 | f-salmvi |  | 100% | name | 33355 | 100 |  | F -Salmonella, viljely | Feces |  | Salmonella identified in Stool by Organism specific culture |
| 1791 | f-shigvi |  | 100% | name | 14849 | 100 |  | F -Shigella, viljely | Feces |  | Shigella identified in Stool by Organism specific culture |
| 1792 | f-stafvi |  | 100% | name | 107 | 100 |  |  | Feces |  | Staphylococcus identified in Stool by Organism specific culture |
| 1793 | fl-candvi |  | 100% | name | 786 | 100 |  |  | Vaginal discharge |  | Candida identified in Vaginal fluid by Organism specific culture |
| 1794 | hsvpvi |  | 100% | name | 246 | 100 |  |  |  |  | Herpes simplex virus identified in Unspecified specimen by Rapid culture |
| 1795 | l-sauv | % | 99% | name+unit+values | 3700 | 0 | [0, 0, 0, 0, 0.48, 1, 1.78, 2.98, 5.83] |  | Leukocyte |  | Neutrophils.band form/Leukocytes [# Ratio] in Blood by Automated count |
| 1796 | l-sauv |  | 1% | name | 36 | 100 |  |  | Leukocyte |  | Neutrophils.band form/Leukocytes [# Ratio] in Blood by Automated count |
| 1797 | l-sauva | % | 95% | name+unit+values | 4826 | 0 | [0, 0, 0, 0.02, 0.78, 1.03, 2.02, 3.39, 6.06] |  | Leukocyte |  | Neutrophils.band form/Leukocytes [# Ratio] in Blood by Automated count |
| 1798 | l-sauva |  | 5% | name+values | 244 | 100 | [0, 0, 0, 0.06, 1, 1, 2, 2.4, 4] |  | Leukocyte |  | Neutrophils.band form/Leukocytes [# Ratio] in Blood by Automated count |
| 1799 | l-sauvat | % | 93% | name+unit+values | 3136 | 0 | [0, 0, 0, 0.1, 1, 1, 1.97, 2.83, 4.14] |  | Leukocyte |  | Neutrophils.band form/Leukocytes [# Ratio] in Blood by Automated count |
| 1800 | l-sauvat |  | 7% | name | 224 | 100 |  |  | Leukocyte |  | Neutrophils.band form/Leukocytes [# Ratio] in Blood by Automated count |
| 1801 | mm-hygvi |  | 100% | name | 702 | 100 |  | Mm-Hygienianäyte, viljely (äidinmaito) | Maternal milk |  | Bacteria identified in Breast milk by Culture |
| 1802 | mrsavi |  | 100% | name | 879 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Unspecified specimen by Organism specific culture |
| 1803 | ns-mrsavi |  | 100% | name | 697 | 100 |  |  | Nasal secretion |  | Staphylococcus aureus.methicillin resistant identified in Nasal specimen by Organism specific culture |
| 1804 | ns-staurvi |  | 100% | name | 1639 | 100 |  |  | Nasal secretion |  | Staphylococcus aureus identified in Nasal specimen by Organism specific culture |
| 1805 | ps-mrsavi |  | 100% | name | 694 | 100 |  |  | Pharyngeal secretion |  | Staphylococcus aureus.methicillin resistant identified in Pharynx by Organism specific culture |
| 1806 | rasvat |  | 100% | name | 811 | 100 |  |  |  |  |  |
| 1807 | resgnsvi |  | 100% | name | 2065 | 100 |  |  |  |  | Gram negative bacilli.multidrug resistant identified in Unspecified specimen by Culture |
| 1808 | rsv |  | 100% | name | 1507 | 100 |  |  |  |  | Respiratory syncytial virus Ag [Presence] in Respiratory specimen |
| 1809 | sc-hygvi |  | 100% | name | 251 | 100 |  |  |  |  | Bacteria identified in Environmental specimen by Culture |
| 1810 | sk-mrsavi |  | 100% | name | 165 | 100 |  |  | Skin |  | Staphylococcus aureus.methicillin resistant identified in Skin by Organism specific culture |
| 1811 | straag |  | 100% | name | 525 | 100 |  |  |  |  | Streptococcus group A Ag [Presence] in Throat |
| 1812 | strvi |  | 100% | name | 175 | 100 |  |  |  |  | Streptococcus identified in Unspecified specimen by Organism specific culture |
| 1813 | tbvi |  | 100% | name | 1001 | 100 |  |  |  |  | Mycobacterium tuberculosis identified in Unspecified specimen by Culture |
| 1814 | tbvr |  | 100% | name | 863 | 100 |  |  |  |  | Mycobacterium tuberculosis [Presence] in Unspecified specimen by Acid fast stain |
| 1815 | tbvrvi |  | 100% | name | 174 | 100 |  |  |  |  | Mycobacterium tuberculosis smear and culture panel - Unspecified specimen |
| 1816 | u-mrsavi |  | 100% | name | 3760 | 100 |  |  | Urine |  | Staphylococcus aureus.methicillin resistant identified in Urine by Organism specific culture |
| 1817 | u-tbvi |  | 100% | name | 564 | 100 |  |  | Urine |  | Mycobacterium tuberculosis identified in Urine by Culture |
| 1818 | veri |  | 100% | name | 122 | 100 |  |  |  |  |  |
| 1819 | vi | form | 30% | name+unit | 101 | 0 |  |  |  |  | Bacteria identified in Unspecified specimen by Culture |
| 1820 | vi |  | 70% | name | 233 | 100 |  |  |  |  | Bacteria identified in Unspecified specimen by Culture |
| 1821 | vre-vi |  | 100% | name | 1349 | 100 |  |  |  | Culture | Enterococcus.vancomycin resistant identified in Unspecified specimen by Organism specific culture |
| 1822 | vrevi |  | 100% | name | 5662 | 100 |  |  |  |  | Enterococcus.vancomycin resistant identified in Unspecified specimen by Organism specific culture |

