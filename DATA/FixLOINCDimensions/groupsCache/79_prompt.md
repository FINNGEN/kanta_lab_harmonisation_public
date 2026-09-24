[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

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
- `n_codes` / `n_events` — how many curated Finnish lab codes already map to this concept, and how many records those codes cover. This is usage in Finland.

**The rows table** — one row per local lab test/unit combination:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty.
- `n` — number of records.
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available. The strongest single piece of evidence for what a test really measures and in which units: a "sodium" code whose deciles read 0.32-0.40 is not sodium in mmol/l.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess. A hypothesis to test against the row's own evidence, not an instruction.
- `is_panel` — whether the earlier pass judged the code to order a bundle of tests rather than report one result.

# How to decide

For each row:

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
2. **Pick the candidate that matches that reading**, and return its `omop_concept_id`. The unit and the deciles decide between candidates that differ only in property: `mmol/l` takes `[Moles/volume]`, `g/l` takes `[Mass/volume]`, `U/l` takes `[Enzymatic activity/volume]`. The prefix decides the specimen; remember that LOINC's `Serum or Plasma` is the right term for most routine chemistry, and that fasting is not part of the specimen (`fS` is still serum).
3. **When two or more candidates fit the evidence equally well**, break the tie in this order:
   1. **Prefer a candidate with a `top2000` rank.** That list is LOINC's own recommendation for what laboratories should map to, so a concept on it is the intended target and a near-duplicate off it usually is not.
   2. **Then prefer the higher `n_codes` / `n_events`.** Finland already maps real codes to that concept; matching established national usage keeps this data joinable with what exists.

   These break ties. They never override the row's own evidence: a top-2000 concept in the wrong specimen or the wrong units is still the wrong answer.
4. **Leave `omop_concept_id` empty when no candidate is right.** That is a correct, useful answer — it says "this code has no match in what the search returned", which is a fact the next iteration can act on. Common reasons: the code is too truncated or garbled to identify; it is a local administrative or non-laboratory code; or the search simply did not return the concept you know is right.
5. **Never return an id that is not in the candidate table.** Not one you remember, not one you derive from a LOINC code, not a plausible-looking number. Ids that are not in the table are discarded and the row is logged as unanswered, so inventing one only loses the row.

Specific things to watch:

- **A panel is not its components.** If the code orders a bundle (`B-PVK` = full blood count, `U-KemSeul` = urine dipstick screen), the answer is the panel concept (`CBC panel - Blood by Automated count`), not hemoglobin. Conversely, do not map a single reported result to a panel concept just because a panel candidate scored well.
- **Deprecated near-duplicates are already filtered out** of the candidate list — every candidate is a standard, current concept — so you never need to judge validity, only fit.
- **The same local code recurs in a group with different `UNIT`s**, and those rows are often genuinely different LOINC concepts. Answer each row from its own unit and deciles; do not give every row of a group the same id out of consistency.
- **Rows whose guess was empty still deserve an answer.** The earlier pass could not name them, but the group's pooled candidates may still contain the right concept.

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `omop_concept_id` — the chosen concept's id, copied from the candidate table. Empty if no candidate is right.
- `omop_concept_name` — that candidate's `omop_concept_name`, copied verbatim. Used only to cross-check that the id you copied is the concept you meant; leave it empty when the id is empty.
- `is_panel` — carried through from the input row unless the row is plainly contradictory.

Return an entry for EVERY row, including ones you leave unmapped.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which rows you could map and which you could not, where the candidate list was missing the concept you knew was right, where the earlier pass's guess sent the search astray, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 79.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3001582 | Protein/Creatinine [Mass Ratio] in Urine | 1.000 | 509 |  0 |         0 |
| 3004562 | Bacteria [Presence] in Urine sediment by Light microscopy | 1.000 | 514 |  0 |         0 |
| 3009508 | Creatinine [Moles/volume] in Urine | 1.000 | 161 | 22 |   532,449 |
| 3012516 | Albumin [Mass/volume] in Urine | 1.000 |  | 15 |   484,794 |
| 3015736 | pH of Urine | 1.000 | 612 | 11 |   668,794 |
| 3017754 | Calcium/Creatinine [Molar ratio] in Urine | 1.000 |  |  0 |         0 |
| 3029937 | Albumin [Presence] in Urine by Test strip | 1.000 |  | 10 |   532,964 |
| 3034485 | Albumin/Creatinine [Mass Ratio] in Urine | 1.000 |  |  0 |         0 |
| 3051409 | Alpha-1-Microglobulin/Creatinine [Mass Ratio] in Urine | 0.977 |  |  0 |         0 |
| 1092182 | Bacteria [Presence] in Urine sediment by Microscopy | 0.969 |  |  0 |         0 |
| 1091601 | Epithelial cells [#/area] in Urine sediment | 0.961 |  |  0 |         0 |
| 3000819 | Albumin/Creatinine [Mass Ratio] in 24 hour Urine | 0.958 |  |  0 |         0 |
| 3020682 | Albumin/Creatinine [Ratio] in Urine | 0.957 |  | 31 |   588,386 |
| 3038224 | Microscopic observation [Identifier] in Urine sediment by Light microscopy | 0.955 | 339 |  0 |         0 |
| 3027035 | Albumin [Mass/time] in 24 hour Urine | 0.953 |  |  3 |       539 |
| 1092217 | Leukocytes [#/area] in Urine sediment | 0.952 |  |  0 |         0 |
| 3030451 | Calcium/Creatinine [Molar ratio] in 24 hour Urine | 0.952 |  |  0 |         0 |
| 1988702 | Alpha-1-Microglobulin/Creatinine [Mass Ratio] in 24 hour Urine | 0.950 |  |  0 |         0 |
| 3002812 | Albumin/Creatinine [Molar ratio] in Urine | 0.948 |  |  0 |         0 |
| 3002481 | Calcium/Creatinine [Mass Ratio] in Urine | 0.943 |  |  1 |        76 |
| 3045462 | Protein/Creatinine [Ratio] in Urine | 0.943 |  |  3 |     3,428 |
| 1092445 | Erythrocytes [#/area] in Urine sediment | 0.941 |  |  0 |         0 |
| 3037791 | Protein/Creatinine [Mass Ratio] in 24 hour Urine | 0.940 |  |  0 |         0 |
| 3050449 | Albumin [Mass/time] in Urine collected for unspecified duration | 0.932 |  |  6 |    22,756 |
| 3008392 | Creatinine/Protein [Mass Ratio] in Urine | 0.924 |  |  0 |         0 |
| 3008960 | Albumin [Mass/volume] in 24 hour Urine | 0.923 |  |  0 |         0 |
| 649500 | Albumin/Creatinine [Measurement] in Urine | 0.923 |  |  0 |         0 |
| 43055190 | Macrophages [#/area] in Urine sediment by Microscopy high power field | 0.921 |  |  3 |       226 |
| 40761537 | Casts [Type] in Urine sediment by Light microscopy | 0.921 |  |  0 |         0 |
| 46235897 | Albumin/Creatinine [Ratio] in 24 hour Urine | 0.919 |  |  0 |         0 |
| 3047166 | Epithelial cells [#/area] in Urine sediment by Automated count | 0.918 |  |  1 |     1,272 |
| 3051014 | Leukocytes [#/area] in Urine sediment by Automated count | 0.917 |  | 15 |     6,638 |
| 1092008 | Casts [#/area] in Urine sediment | 0.915 |  |  0 |         0 |
| 40763732 | Protein/Creatinine [Mass Ratio] in 12 hour Urine | 0.915 |  |  0 |         0 |
| 3043507 | Leukocytes [#/area] in Urine sediment by Microscopy low power field | 0.914 |  |  0 |         0 |
| 3043366 | Epithelial cells [#/area] in Urine sediment by Microscopy low power field | 0.913 |  |  0 |         0 |
| 3000955 | Protein/Creatinine [Mass Ratio] in Serum or Plasma | 0.912 |  |  0 |         0 |
| 3035583 | Leukocytes [#/area] in Urine sediment by Microscopy high power field | 0.908 | 79 |  0 |         0 |
| 3010189 | Epithelial cells [#/area] in Urine sediment by Microscopy high power field | 0.908 | 166 |  0 |         0 |
| 3013539 | Creatinine [Moles/volume] in 24 hour Urine | 0.908 | 1978 |  0 |         0 |
| 40762887 | Creatinine [Moles/volume] in Blood | 0.907 | 283 |  1 |       449 |
| 3035982 | Calcium/Creatinine [Mass Ratio] in 24 hour Urine | 0.907 |  |  0 |         0 |
| 3001802 | Microalbumin/Creatinine [Mass Ratio] in Urine | 0.903 | 212 |  0 |         0 |
| 645998 | Albumin [Measurement] in Urine | 0.898 |  |  0 |         0 |
| 3048402 | Erythrocytes [#/area] in Urine sediment by Automated count | 0.897 |  |  6 |     4,000 |
| 3025987 | Albumin [Presence] in Urine | 0.896 |  |  0 |         0 |
| 3035124 | Erythrocytes [#/area] in Urine sediment by Microscopy high power field | 0.895 | 100 |  0 |         0 |
| 646827 | Protein/Creatinine [Measurement] in Urine | 0.895 |  |  0 |         0 |
| 3026726 | Creatinine [Moles/volume] in Specimen | 0.893 |  |  2 |       834 |
| 3038404 | Protein/Creatinine [Ratio] in 24 hour Urine | 0.892 |  |  0 |         0 |
| 3033268 | Albumin [Mass/time] in Urine collected for unspecified duration --supine | 0.891 |  |  0 |         0 |
| 3000837 | Albumin/Creatinine [Mass Ratio] in Urine by Test strip | 0.891 |  |  0 |         0 |
| 36660607 | Microalbumin [Presence] in Urine by Test strip | 0.888 |  |  0 |         0 |
| 36031484 | Leukocytes [#/area] in Body fluid by Light microscopy | 0.886 |  |  0 |         0 |
| 3040006 | Creatinine [Moles/volume] in 12 hour Urine | 0.885 |  |  0 |         0 |
| 1092204 | Epithelial cells.squamous [#/area] in Urine sediment | 0.885 |  |  0 |         0 |
| 3045571 | Creatinine/Calcium [Mass Ratio] in Urine | 0.885 |  |  0 |         0 |
| 3023147 | Calcium/Creatinine [Mass Ratio] in 2 hour Urine | 0.885 |  |  0 |         0 |
| 3037459 | Creatinine [Moles/volume] in Body fluid | 0.885 | 1234 |  0 |         0 |
| 3017250 | Creatinine [Mass/volume] in Urine | 0.884 |  |  0 |         0 |
| 3003291 | Casts [Presence] in Urine sediment by Light microscopy | 0.884 |  |  0 |         0 |
| 3052318 | Alpha-1-Microglobulin [Mass/volume] in Urine | 0.884 |  |  3 |     2,195 |
| 36032273 | Leukocytes [#/area] in Prostatic fluid by Light microscopy | 0.884 |  |  0 |         0 |
| 1091831 | Leukocytes [#/area] in Urine by Computer assisted method | 0.883 |  |  0 |         0 |
| 649233 | Calcium/Creatinine [Measurement] in Urine | 0.882 |  |  0 |         0 |
| 3040510 | Creatinine [Moles/time] in 1 hour Urine | 0.879 |  |  0 |         0 |
| 3038830 | Creatinine [Moles/volume] in Urine --baseline | 0.878 |  |  0 |         0 |
| 3030015 | Alpha-2-Macroglobulin/Creatinine [Mass Ratio] in Urine | 0.878 |  |  0 |         0 |
| 1092420 | Epithelial cells.non-squamous [#/area] in Urine sediment | 0.878 |  |  0 |         0 |
| 1091888 | Epithelial cells.renal [#/area] in Urine sediment | 0.876 |  |  0 |         0 |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 0.876 | 1 | 51 | 9,024,989 |
| 3046825 | Epithelial cells.renal [#/area] in Urine sediment by Microscopy low power field | 0.876 |  |  0 |         0 |
| 40763957 | Albumin [Mass/volume] in Urine from Fetus | 0.876 |  |  0 |         0 |
| 3029482 | Bacterial casts [Presence] in Urine sediment by Light microscopy | 0.873 |  |  0 |         0 |
| 3029162 | Epithelial cells.squamous [#/area] in Urine sediment by Automated count | 0.873 |  |  0 |         0 |
| 3022547 | Leukocytes [Presence] in Urine sediment by Light microscopy | 0.872 | 2000 |  0 |         0 |
| 3015023 | Epithelial cells.renal [#/area] in Urine sediment by Microscopy high power field | 0.871 | 605 |  0 |         0 |
| 46235212 | Alpha-1-acid glycoprotein/Creatinine [Mass Ratio] in Urine | 0.869 |  |  0 |         0 |
| 3046030 | Erythrocytes [Presence] in Urine sediment by Light microscopy | 0.867 |  |  0 |         0 |
| 36032130 | Erythrocytes [#/area] in Body fluid by Light microscopy | 0.867 |  |  0 |         0 |
| 3043771 | Microalbumin [Mass/time] in 12 hour Urine | 0.864 |  |  0 |         0 |
| 3008512 | Albumin [Mass/volume] in Urine by Electrophoresis | 0.864 | 1035 |  0 |         0 |
| 3040554 | Leukocytes [#/area] in Urethra by Wet preparation | 0.863 |  |  0 |         0 |
| 3002000 | Albumin [Mass/volume] in Specimen | 0.863 |  |  0 |         0 |
| 3022826 | Microalbumin/Creatinine [Ratio] in Urine | 0.863 |  |  0 |         0 |
| 3002827 | Microalbumin/Creatinine [Mass Ratio] in 24 hour Urine | 0.861 | 1979 |  0 |         0 |
| 3035004 | Microscopic observation [Identifier] in Urine by Cyto stain | 0.860 | 1251 |  0 |         0 |
| 3005658 | Casts [#/area] in Urine sediment by Microscopy low power field | 0.859 | 294 |  0 |         0 |
| 3018097 | Albumin [Mass/time] in 24 hour Urine by Electrophoresis | 0.858 |  |  0 |         0 |
| 40771492 | Microscopic observation [Identifier] in Urine by KOH preparation | 0.857 |  |  0 |         0 |
| 1988513 | Alpha-1-Microglobulin [Mass/volume] in 24 hour Urine | 0.856 |  |  0 |         0 |
| 3040034 | Microscopic observation [Identifier] in Urine by Wright stain | 0.854 |  |  0 |         0 |
| 36304419 | Bacteria [Presence] in Urine | 0.852 |  |  2 |   390,903 |
| 1617497 | Urea/Creatinine [Mass Ratio] in Urine | 0.852 |  |  0 |         0 |
| 3052615 | Alpha-1-Microglobulin [Mass/time] in 24 hour Urine | 0.852 |  |  0 |         0 |
| 36031377 | Macrophages [#/area] in Prostatic fluid by Light microscopy | 0.851 |  |  0 |         0 |
| 3044318 | Oxalate/Creatinine [Molar ratio] in Urine | 0.851 |  |  0 |         0 |
| 36032101 | Erythrocytes [#/area] in Prostatic fluid by Light microscopy | 0.851 |  |  0 |         0 |
| 3011931 | Proline/Creatinine [Mass Ratio] in Urine | 0.849 |  |  0 |         0 |
| 1989137 | Erythrocytes.non-dysmorphic [#/area] in Urine sediment by Computer assisted method | 0.849 |  |  0 |         0 |
| 3021344 | Bacteria [Presence] in Semen by Light microscopy | 0.849 |  |  0 |         0 |
| 3014051 | Protein [Presence] in Urine by Test strip | 0.848 | 99 |  3 |   382,676 |
| 3039522 | Prealbumin [Mass/volume] in Urine | 0.848 |  |  0 |         0 |
| 40771458 | Erythrocytes in 24 hour Urine sediment by Light microscopy | 0.847 |  |  0 |         0 |
| 3004068 | Alpha aminoadipate/Creatinine [Mass Ratio] in Urine | 0.847 |  |  0 |         0 |
| 40757477 | Albumin [Mass/volume] in Stool | 0.846 |  |  0 |         0 |
| 3041120 | Leukocytes [#/area] in Specimen by Wet preparation | 0.846 |  |  0 |         0 |
| 3029409 | Erythrocytes [#/area] in Synovial fluid by Light microscopy | 0.845 |  |  0 |         0 |
| 3045874 | Casts [#/area] in Urine sediment by Automated count | 0.843 |  |  0 |         0 |
| 1092301 | Erythrocytes [#/volume] in Urine sediment | 0.843 |  |  0 |         0 |
| 3028469 | Citrate/Creatinine [Molar ratio] in Urine | 0.842 |  |  0 |         0 |
| 1989084 | Calcium/Creatinine [Mass Ratio] in Urine from Fetus | 0.840 |  |  0 |         0 |
| 3028855 | Bacteria [Presence] in Body fluid by Light microscopy | 0.840 |  |  0 |         0 |
| 1092248 | Bacteria [#/area] in Urine sediment by Microscopy | 0.840 |  |  0 |         0 |
| 46237005 | Alpha-1-Microglobulin [Moles/volume] in Urine | 0.840 |  |  0 |         0 |
| 3009292 | Casts [#/area] in Urine sediment by Microscopy high power field | 0.840 | 864 |  0 |         0 |
| 36031764 | Microscopic observation [Identifier] in Body fluid by Light microscopy | 0.838 |  |  0 |         0 |
| 40760483 | Microalbumin [Mass/volume] in 12 hour Urine | 0.837 |  |  0 |         0 |
| 46236875 | Albumin [Mass/volume] by Electrophoresis in Urine collected for unspecified duration | 0.837 |  |  0 |         0 |
| 43054974 | Bacteria [Presence] in Prostatic fluid by Light microscopy | 0.836 |  |  0 |         0 |
| 3024850 | Microscopic observation [Identifier] in Urine by Acid fast stain | 0.835 |  |  0 |         0 |
| 3003745 | Microscopic observation [Identifier] in Urine by Gram stain | 0.834 |  |  0 |         0 |
| 3004261 | Microscopic observation [Identifier] in Urine by Dark field examination | 0.833 |  |  0 |         0 |
| 3022621 | pH of Urine by Test strip | 0.833 | 59 | 17 |    92,206 |
| 646324 | Alpha-1-Microglobulin [Measurement] in Urine | 0.833 |  |  0 |         0 |
| 3033812 | Protein [Mass/time] in 12 hour Urine | 0.829 |  |  0 |         0 |
| 3041765 | Neutrophils [Presence] in Urine by Light microscopy | 0.829 | 1515 |  0 |         0 |
| 40761538 | Microorganisms seen [Type] in Urine sediment by Light microscopy | 0.828 |  |  0 |         0 |
| 3040509 | Prealbumin [Mass/time] in 24 hour Urine | 0.826 |  |  0 |         0 |
| 3005577 | Microalbumin [Mass/time] in 24 hour Urine | 0.821 | 1294 |  0 |         0 |
| 1091136 | Microscopic observation [Identifier] in Specimen | 0.820 |  |  0 |         0 |
| 3000600 | Renal tubular casts [#/area] in Urine by Light microscopy | 0.818 |  |  0 |         0 |
| 40761543 | Other elements [Identifier] in Urine sediment by Light microscopy | 0.817 |  |  0 |         0 |
| 3025472 | Microscopic observation [Identifier] in Body fluid by Wet preparation | 0.817 |  |  0 |         0 |
| 1469687 | pH of Urine by pH-meter | 0.817 |  |  0 |         0 |
| 3019077 | Protein [Presence] in 24 hour Urine by Test strip | 0.811 |  |  0 |         0 |
| 3036634 | Albumin [Presence] in 24 hour Urine by Electrophoresis | 0.809 |  |  0 |         0 |
| 3011397 | Hemoglobin [Presence] in Urine by Test strip | 0.808 | 72 |  5 |   413,345 |
| 40760845 | Protein [Presence] in Urine by Automated test strip | 0.804 |  |  0 |         0 |
| 3040042 | pH of 4 hour Urine | 0.804 |  |  0 |         0 |
| 36303515 | Broad casts [#/area] in Urine sediment | 0.803 |  |  0 |         0 |
| 1617335 | Artifact [#/area] in Urine sediment by Light microscopy | 0.802 |  |  0 |         0 |
| 40761539 | Cells [Type] in Urine sediment by Light microscopy | 0.801 |  |  1 |     1,262 |
| 3046055 | Albumin [Presence] in Body fluid | 0.796 |  |  0 |         0 |
| 3029305 | pH of Urine by Automated test strip | 0.796 |  |  0 |         0 |
| 3030511 | Albumin [Mass/volume] in 24 hour Urine by Electrophoresis | 0.789 |  |  0 |         0 |
| 3965477 | Pathologic casts [Presence] in Urine sediment by Light microscopy | 0.789 |  |  0 |         0 |
| 3015501 | pH of 24 hour Urine | 0.786 |  |  0 |         0 |
| 3000745 | Histiocytes [#/area] in Urine sediment by Microscopy high power field | 0.780 |  |  0 |         0 |
| 40761501 | Specimen pH acceptable of Urine | 0.780 |  |  0 |         0 |
| 3040007 | pH of 2 hour Urine | 0.775 |  |  0 |         0 |
| 3031015 | pH of 24 hour Urine by Test strip | 0.769 |  |  0 |         0 |
| 1091765 | Leukocyte clumps [#/area] in Urine sediment | 0.758 |  |  0 |         0 |
| 3050658 | Leukocyte clumps [#/area] in Urine sediment by Microscopy high power field | 0.754 | 1021 |  0 |         0 |
| 3011422 | Epithelial cells [Presence] in Urine sediment by Light microscopy | 0.745 | 151 |  0 |         0 |
| 3017064 | Microcytes [Presence] in Urine by Light microscopy | 0.745 |  |  0 |         0 |
| 40761557 | Bladder cells [Presence] in Urine sediment by Light microscopy | 0.736 |  |  0 |         0 |
| 3039774 | Microcytes [Presence] in Urine sediment by Light microscopy | 0.733 |  |  0 |         0 |
| 3040311 | Epithelial cells.non-squamous [Presence] in Urine sediment by Light microscopy | 0.725 |  |  0 |         0 |
| 3002650 | Tubular cells [Presence] in Urine sediment by Light microscopy | 0.723 | 956 |  0 |         0 |
| 3018672 | pH of Body fluid | 0.716 | 953 |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1161 | cu-alb-mi | ug/min | 7258 | 0 | [2, 3.03, 4.27, 6.2, 9.73, 17, 34.68, 78.84, 221.36] | cU-Albumiini, mikroalbuminuria | Collected urine | Micro | Albumin [Mass/time] in Collected Urine | FALSE |
| 1162 | cu-alb-mi |  | 1830 | 100 | [2, 3.76, 5.36, 7.63, 12.69, 25, 48.21, 105.09, 287.3] | cU-Albumiini, mikroalbuminuria | Collected urine | Micro | Albumin [Mass/time] in Collected Urine | FALSE |
| 1163 | nu-alb-mi | mg/12h | 12 | 0 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin [Mass/time] in 12 hour Urine | FALSE |
| 1164 | nu-alb-mi | ug/min | 155 | 0 | [5, 8.88, 19.76, 34.34, 70.38, 107.14, 173.45, 320, 537.6] | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin [Mass/time] in Urine | FALSE |
| 1165 | nu-alb-mi |  | 157 | 68.15 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin [Mass/time] in Urine | FALSE |
| 1166 | nu-albkre | mg/mmol | 438 | 0 | [0.3, 0.49, 0.65, 0.9, 1.28, 2, 4.09, 8.45, 23.14] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1167 | nu-albkre |  | 2191 | 62.12 | [0.39, 0.5, 0.69, 0.87, 1.2, 1.82, 2.88, 6.31, 19.04] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1168 | nu-albkrea | mg/mmol | 20929 | 0 | [0.33, 0.49, 0.66, 0.9, 1.32, 2.09, 3.79, 8.38, 27.64] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1169 | nu-albkrea |  | 26197 | 100 | [0.21, 0.36, 0.51, 0.7, 1.05, 1.62, 2.84, 6.09, 18.42] |  | Night (morning) urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1170 | u-a1mikre |  | 113 | 12.39 | [1, 2.43, 3.5, 6.91, 9.03, 11.18, 14.78, 18.06, 35.1] |  | Urine |  | Alpha 1 microglobulin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1171 | u-alb-0 |  | 992 | 100 |  |  | Urine |  | Albumin [Presence] in Urine by Test strip | FALSE |
| 1172 | u-alb-lb | mg/l | 70 | 0 |  |  | Urine |  | Albumin [Mass/volume] in Urine | FALSE |
| 1173 | u-alb-lb |  | 50 | 98 |  |  | Urine |  | Albumin [Mass/volume] in Urine | FALSE |
| 1174 | u-alb-mi | mg/l | 7488 | 0 | [3.01, 4.02, 5.51, 7.59, 11.17, 18.74, 35.95, 87.24, 325.25] |  | Urine | Micro | Albumin [Mass/volume] in Urine | FALSE |
| 1175 | u-alb-mi |  | 3031 | 100 | [1.94, 3, 4.21, 6.03, 8.61, 11.71, 20.86, 50.08, 291.2] |  | Urine | Micro | Albumin [Mass/volume] in Urine | FALSE |
| 1176 | u-alb-o | estimate | 161670 | 2.95 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin [Presence] in Urine by Test strip | FALSE |
| 1177 | u-alb-o | form | 287 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin [Presence] in Urine by Test strip | FALSE |
| 1178 | u-alb-o |  | 312867 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin [Presence] in Urine by Test strip | FALSE |
| 1179 | u-alb/kre | g/mol | 142 | 0 | [1.78, 3.02, 3.92, 5.37, 8.28, 16.58, 32.75, 51.54, 140.31] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1180 | u-alb/kre | mg/mmol | 2591 | 0 | [0.3, 0.42, 0.6, 0.84, 1.25, 2.07, 3.99, 8.87, 30.32] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1181 | u-alb/kre |  | 2491 | 96.87 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1182 | u-alb/kre,u-alb |  | 247 | 39.27 | [6.13, 7.52, 9.27, 12.32, 15.29, 19.26, 37.25, 66.2, 187.73] |  | Urine |  | Albumin [Mass/volume] in Urine | FALSE |
| 1183 | u-alb/kre,u-alb/krea | mg/mmol | 148 | 0 | [0.59, 0.74, 0.99, 1.41, 1.89, 3.03, 5.25, 10.21, 22.45] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1184 | u-alb/kre,u-alb/krea |  | 99 | 96.97 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1185 | u-alb/kre,u-krea |  | 247 | 0.81 | [3.67, 4.76, 5.83, 6.76, 7.67, 8.61, 9.82, 10.75, 12.92] |  | Urine |  | Creatinine [Moles/volume] in Urine | FALSE |
| 1186 | u-alb/krea | g/mol | 49 | 0 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1187 | u-alb/krea | mg/mmol | 879 | 0 | [0.29, 0.4, 0.52, 0.73, 1.06, 1.82, 2.87, 5.79, 14.42] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1188 | u-alb/krea |  | 812 | 100 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1189 | u-albkre | g/mol | 10 | 0 |  | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1190 | u-albkre | mg/mmol | 294883 | 0.26 | [0.31, 0.5, 0.7, 1.03, 1.68, 3, 6.29, 16.55, 61.66] | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1191 | u-albkre |  | 200553 | 100 | [0.3, 0.4, 0.59, 0.81, 1.18, 1.92, 3.44, 7.04, 20.74] | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1192 | u-albkrea | mg/mmol | 10590 | 0 | [0.3, 0.44, 0.59, 0.73, 0.97, 1.31, 1.85, 3.03, 9.45] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1193 | u-albkrea | mg/mmol/l | 81 | 0 |  |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1194 | u-albkrea |  | 15486 | 73.32 | [0.4, 0.65, 1.06, 1.98, 3.39, 4.96, 7.85, 14.4, 37.26] |  | Urine |  | Albumin/Creatinine [Mass Ratio] in Urine | FALSE |
| 1195 | u-alvhu4a |  | 760 | 100 |  |  | Urine |  |  | FALSE |
| 1196 | u-alvhu5b |  | 912 | 100 |  |  | Urine |  |  | FALSE |
| 1197 | u-alvhu6a |  | 1273 | 100 |  |  | Urine |  |  | FALSE |
| 1198 | u-cakre |  | 106 | 48.11 |  |  | Urine |  | Calcium/Creatinine [Molar ratio] in Urine | FALSE |
| 1199 | u-happamuus |  | 204 | 0.49 | [6.5, 6.5, 7, 7, 7, 7, 7.5, 7.5, 8] |  | Urine |  | pH of Urine | FALSE |
| 1200 | u-prokre | g/mol | 973 | 0.41 | [5.03, 6.97, 8.99, 11.1, 14.55, 19.47, 27.35, 52.28, 161.87] | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein/Creatinine [Mass Ratio] in Urine | FALSE |
| 1201 | u-prokre | mg/mmol | 1813 | 0 | [9.66, 12.56, 16.16, 21.33, 30.42, 49.33, 102.26, 292.89, 1027.72] | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein/Creatinine [Mass Ratio] in Urine | FALSE |
| 1202 | u-prokre |  | 646 | 99.85 |  | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein/Creatinine [Mass Ratio] in Urine | FALSE |
| 1203 | u-protkre | mg/mmol | 121 | 0 |  |  | Urine |  | Protein/Creatinine [Mass Ratio] in Urine | FALSE |
| 1204 | u-protkre |  | 9 | 100 |  |  | Urine |  | Protein/Creatinine [Mass Ratio] in Urine | FALSE |
| 1205 | u-sakka,bakt |  | 330 | 99.39 |  |  | Urine |  | Bacteria [Presence] in Urine sediment by Light microscopy | FALSE |
| 1206 | u-sakka,epit |  | 1251 | 71.3 | [0, 0, 0, 0, 0, 0, 0.33, 1, 2] |  | Urine |  | Epithelial cells [#/area] in Urine sediment by Light microscopy | FALSE |
| 1207 | u-sakka,eryt | u/field | 1247 | 0 | [0, 1, 1, 1, 1, 2, 2.67, 4, 7] |  | Urine |  | Erythrocytes [#/area] in Urine sediment by Light microscopy | FALSE |
| 1208 | u-sakka,eryt |  | 121 | 100 | [0, 0, 0, 0, 0.62, 1, 2, 3.04, 7.71] |  | Urine |  | Erythrocytes [#/area] in Urine sediment by Light microscopy | FALSE |
| 1209 | u-sakka,leuk | u/field | 1087 | 0 | [0, 0, 0, 0, 0, 1, 1, 2.25, 5] |  | Urine |  | Leukocytes [#/area] in Urine sediment by Light microscopy | FALSE |
| 1210 | u-sakka,leuk |  | 261 | 100 | [0, 0, 0, 0, 0, 0.98, 2, 4.88, 11.66] |  | Urine |  | Leukocytes [#/area] in Urine sediment by Light microscopy | FALSE |
| 1211 | u-sakka,lier |  | 367 | 5.72 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Casts [#/area] in Urine sediment by Light microscopy | FALSE |
| 1212 | u-sakka,makrof |  | 367 | 4.63 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Macrophages [#/area] in Urine sediment by Light microscopy | FALSE |
| 1213 | u-sakka,muuta |  | 456 | 25.88 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Microscopic observation [Identifier] in Urine sediment | FALSE |
| 1214 | u-solut,muut |  | 136 | 88.24 |  |  | Urine |  | Cells.other [Identifier] in Urine by Light microscopy | FALSE |

