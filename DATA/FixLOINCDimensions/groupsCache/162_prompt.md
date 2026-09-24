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
Here is group 162.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1616794 | Bicarbonate [Moles/volume] in Central venous blood | 1.000 |  |  0 |          0 |
| 3000067 | Parathyrin.intact [Mass/volume] in Serum or Plasma | 1.000 | 240 |  3 |    136,886 |
| 3001784 | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | 1.000 | 532 | 47 |    441,698 |
| 3003458 | Phosphate [Moles/volume] in Serum or Plasma | 1.000 | 69 |  9 |    377,182 |
| 3005772 | Bilirubin.conjugated [Moles/volume] in Serum or Plasma | 1.000 |  | 11 |    150,241 |
| 3007220 | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 90 | 12 |    297,958 |
| 3007808 | Renin [Enzymatic activity/volume] in Plasma | 1.000 | 822 |  0 |          0 |
| 3008152 | Bicarbonate [Moles/volume] in Arterial blood | 1.000 | 310 | 12 |    183,958 |
| 3008342 | Neutrophils/Leukocytes in Blood by Automated count | 1.000 | 25 |  0 |          0 |
| 3010457 | Eosinophils/Leukocytes in Blood by Automated count | 1.000 | 43 |  0 |          0 |
| 3010566 | Parathyrin.intact [Moles/volume] in Serum or Plasma | 1.000 | 240 |  1 |     30,491 |
| 3011948 | Monocytes/Leukocytes in Blood by Automated count | 1.000 | 44 |  0 |          0 |
| 3013869 | Basophils/Leukocytes in Blood by Automated count | 1.000 | 42 |  0 |          0 |
| 3016436 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 156 |  2 |      5,209 |
| 3018095 | Leukocytes [#/volume] in Urine | 1.000 | 201 | 20 |    676,308 |
| 3019309 | Folate [Moles/volume] in Red Blood Cells | 1.000 | 743 |  8 |    125,721 |
| 3020891 | Body temperature | 1.000 | 138 |  9 |     93,063 |
| 3021589 | Normoblasts [#/volume] in Blood | 1.000 |  | 22 |  2,299,398 |
| 3027273 | Bicarbonate [Moles/volume] in Venous blood | 1.000 | 781 | 20 |     70,272 |
| 3029287 | Urinalysis microscopic panel [#/volume] - Urine by Automated count | 1.000 |  |  3 |    557,289 |
| 3034780 | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 730 |  6 |     39,648 |
| 3035995 | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 23 | 13 |  2,756,532 |
| 3037511 | Lymphocytes/Leukocytes in Blood by Automated count | 1.000 | 41 |  0 |          0 |
| 3044889 | 12 lead EKG panel | 1.000 |  |  2 |  1,163,408 |
| 3045066 | Thymidine kinase [Enzymatic activity/volume] in Serum | 1.000 |  |  3 |      2,079 |
| 40771025 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma | 1.000 |  | 26 |    509,150 |
| 42870588 | Differential panel, method unspecified - Blood | 1.000 |  |  2 |  1,020,069 |
| 3007628 | Bicarbonate [Moles/volume] standard in Venous blood | 0.973 |  |  9 |    123,954 |
| 723477 | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.969 |  |  0 |          0 |
| 3014218 | Bicarbonate [Moles/volume] standard in Arterial blood | 0.968 |  |  9 |    265,515 |
| 3004490 | Bicarbonate [Moles/volume] standard in Capillary blood | 0.966 |  |  3 |     72,349 |
| 3005783 | Lactate dehydrogenase 1 [Enzymatic activity/volume] in Serum or Plasma | 0.964 |  |  0 |          0 |
| 3002385 | Erythrocyte [DistWidth] in Blood | 0.961 |  | 20 |  7,004,505 |
| 46235077 | Alkaline phosphatase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.960 |  |  0 |          0 |
| 3017861 | Lactate dehydrogenase 2 [Enzymatic activity/volume] in Serum or Plasma | 0.959 |  |  0 |          0 |
| 1175563 | Parathyrin.intact [Mass/volume] in Serum or Plasma by Immunoassay | 0.955 |  |  0 |          0 |
| 36031886 | Parathyrin.intact [Moles/volume] in Serum or Plasma by Immunoassay | 0.953 |  |  0 |          0 |
| 3006769 | Lactate dehydrogenase 3 [Enzymatic activity/volume] in Serum or Plasma | 0.949 |  |  0 |          0 |
| 40765040 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Mass/volume] in Serum or Plasma | 0.949 | 632 |  0 |          0 |
| 3015956 | Eosinophils/Leukocytes in Blood by Manual count | 0.946 | 229 |  2 |      1,540 |
| 3052240 | Parathyrin.intact [Moles/volume] in Serum or Plasma --baseline | 0.946 |  |  0 |          0 |
| 3025124 | Lactate dehydrogenase 4 [Enzymatic activity/volume] in Serum or Plasma | 0.945 |  |  0 |          0 |
| 3022250 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma by Lactate to pyruvate reaction | 0.944 |  |  7 |    227,952 |
| 3051659 | 25-hydroxyvitamin D2 [Moles/volume] in Serum or Plasma | 0.944 | 661 |  2 |        575 |
| 3033973 | Parathyrin.intact [Mass/volume] in Serum or Plasma --baseline | 0.944 |  |  0 |          0 |
| 3024390 | 25-hydroxyvitamin D3 [Moles/volume] in Serum or Plasma | 0.943 | 127 |  0 |          0 |
| 3027010 | Lactate dehydrogenase 5 [Enzymatic activity/volume] in Serum or Plasma | 0.942 |  |  0 |          0 |
| 757685 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.942 |  |  0 |          0 |
| 1617100 | Bicarbonate [Moles/volume] standard in Central venous blood | 0.942 |  |  0 |          0 |
| 3009797 | Basophils/Leukocytes in Blood by Manual count | 0.941 | 235 |  0 |          0 |
| 42529188 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma by Immunoassay | 0.937 |  |  2 |        681 |
| 36032419 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Immunoassay | 0.935 |  |  3 |     32,724 |
| 3022407 | Monocytes/Leukocytes in Blood by Manual count | 0.934 | 225 |  0 |          0 |
| 3043821 | Protein and Glucose panel - Urine by Test strip | 0.934 |  |  0 |          0 |
| 645314 | Parathyrin.intact [Measurement] in Serum or Plasma | 0.932 |  |  0 |          0 |
| 1469740 | 24,25-dihydroxyvitamin D3+24,25-dihydroxyvitamin D2 [Moles/volume] in Serum or Plasma | 0.931 |  |  0 |          0 |
| 3029790 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma | 0.931 | 374 |  3 |        349 |
| 40762896 | Parathyrin.intact [Mass/volume] in Body fluid | 0.931 |  |  0 |          0 |
| 3035400 | Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma | 0.930 | 1919 |  3 |      3,451 |
| 3028531 | Enolase.neuron specific [Mass/volume] in Serum or Plasma | 0.930 |  |  3 |     10,290 |
| 3005225 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma by Pyruvate to lactate reaction | 0.929 |  |  0 |          0 |
| 3035569 | Folate [Mass/volume] in Red Blood Cells | 0.928 |  |  0 |          0 |
| 3015235 | Bicarbonate [Moles/volume] in Capillary blood | 0.928 | 1086 | 20 |     47,536 |
| 3027368 | Neutrophils/Leukocytes in Blood by Manual count | 0.925 | 1191 |  0 |          0 |
| 3001620 | Renin [Enzymatic activity/volume] in Plasma --supine | 0.924 |  |  0 |          0 |
| 3024848 | Renin [Enzymatic activity/volume] in Plasma --upright | 0.923 |  |  0 |          0 |
| 1616938 | Parathyrin.intact [Moles/volume] in Body fluid | 0.921 |  |  0 |          0 |
| 3015531 | Creatine kinase.macromolecular [Enzymatic activity/volume] in Serum or Plasma | 0.919 |  |  1 |         18 |
| 3002733 | Renin [Enzymatic activity/volume] in Plasma --baseline | 0.918 |  |  0 |          0 |
| 3020013 | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum or Plasma | 0.918 |  |  9 |      4,096 |
| 3001110 | Alkaline phosphatase [Enzymatic activity/volume] in Blood | 0.918 |  |  0 |          0 |
| 3050084 | Parathyrin.intact [Mass/volume] in Serum or Plasma --pre dose calcium | 0.918 |  |  0 |          0 |
| 3037310 | Renin [Mass/volume] in Plasma | 0.918 |  |  0 |          0 |
| 3007869 | Lactate dehydrogenase [Enzymatic activity/volume] in Specimen | 0.917 |  |  0 |          0 |
| 36303407 | Parathyrin.intact goal [Mass/volume] Serum or Plasma | 0.917 |  |  0 |          0 |
| 3028961 | Parathyrin.intact [Mass/volume] in Serum or Plasma --5th specimen | 0.917 |  |  0 |          0 |
| 43055410 | Prostate Specific Ag Free/Prostate specific Ag.total [Pure mass fraction] in Serum or Plasma | 0.916 |  |  0 |          0 |
| 3036335 | Angiotensin converting enzyme [Enzymatic activity/volume] in Blood | 0.916 | 1299 |  0 |          0 |
| 646074 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Measurement] in Serum or Plasma | 0.915 |  |  0 |          0 |
| 3030413 | Parathyrin.intact [Mass/volume] in Serum or Plasma --4th specimen | 0.915 |  |  0 |          0 |
| 3011985 | Renin [Units/volume] in Plasma | 0.915 |  | 21 |     10,814 |
| 3033622 | Lymphocytes/Leukocytes in Specimen by Automated count | 0.914 |  |  0 |          0 |
| 3007970 | Alkaline phosphatase.bile [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |  0 |          0 |
| 43055372 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.913 |  |  0 |          0 |
| 3020233 | Acid phosphatase [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |  0 |          0 |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.911 |  |  0 |          0 |
| 3001467 | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum or Plasma | 0.911 | 1850 | 12 |      5,701 |
| 3038058 | Lymphocytes/Leukocytes in Blood by Manual count | 0.911 | 186 |  0 |          0 |
| 3011185 | Granulocytes/Leukocytes in Blood by Automated count | 0.910 |  |  0 |          0 |
| 36033641 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.909 |  |  1 |     15,478 |
| 3019676 | Bilirubin.conjugated [Mass/volume] in Serum or Plasma | 0.909 |  |  0 |          0 |
| 3011904 | Phosphate [Mass/volume] in Serum or Plasma | 0.909 |  |  0 |          0 |
| 3043995 | Bilirubin.conjugated+indirect [Moles/volume] in Serum or Plasma | 0.909 |  |  0 |          0 |
| 3005489 | Leukocytes [#/volume] in Urine by Manual count | 0.908 |  |  0 |          0 |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.907 |  |  2 |     45,357 |
| 43055373 | Basophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.906 |  |  0 |          0 |
| 3002214 | Alkaline phosphatase.renal [Enzymatic activity/volume] in Serum or Plasma | 0.905 |  |  0 |          0 |
| 3041668 | Urinalysis microscopic panel [#/area] - Urine sediment by Automated count | 0.905 |  |  0 |          0 |
| 3006576 | Bicarbonate [Moles/volume] in Blood | 0.904 | 120 |  5 |      8,626 |
| 3003860 | Alkaline phosphatase.regan [Enzymatic activity/volume] in Serum or Plasma | 0.903 |  |  0 |          0 |
| 3016213 | Lactate dehydrogenase 2 [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.902 |  |  0 |          0 |
| 1761840 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Specimen by NAA with probe detection | 0.900 |  |  0 |          0 |
| 1091634 | Fungus [Presence] in Specimen | 0.898 |  |  0 |          0 |
| 3006538 | Bicarbonate [Moles/volume] standard in Mixed venous blood | 0.898 |  |  0 |          0 |
| 40762329 | Prostate Specific Ag Free/Prostate specific Ag.total in Body fluid | 0.897 |  |  0 |          0 |
| 3028564 | Alkaline phosphatase isoenz panel - Serum or Plasma | 0.895 |  |  0 |          0 |
| 3018650 | Bicarbonate [Moles/volume] in Venous cord blood | 0.895 | 1213 |  0 |          0 |
| 36661376 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.894 |  |  0 |          0 |
| 36661384 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.894 |  |  0 |          0 |
| 44787037 | Normoblasts [#/volume] in Cord blood | 0.894 |  |  0 |          0 |
| 43055370 | Monocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.894 |  |  0 |          0 |
| 43055369 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.893 |  |  0 |          0 |
| 3025817 | Bicarbonate [Moles/volume] in Mixed venous blood | 0.892 |  |  0 |          0 |
| 3017809 | Bicarbonate [Moles/volume] in Arterial cord blood | 0.892 | 1229 |  0 |          0 |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.892 |  |  0 |          0 |
| 44787097 | Normoblasts [#/volume] in Blood from Fetus | 0.891 |  |  0 |          0 |
| 3049536 | 25-hydroxyvitamin D2 [Mass/volume] in Serum or Plasma | 0.890 |  |  0 |          0 |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.890 |  |  0 |          0 |
| 3006270 | Folate [Moles/volume] in Blood | 0.890 | 1465 |  7 |      3,879 |
| 3034504 | Parathyrin.C-terminal [Moles/volume] in Serum or Plasma | 0.889 |  |  0 |          0 |
| 3014749 | Leukocytes [#/volume] in Urine by Test strip | 0.889 | 162 |  0 |          0 |
| 40760485 | Enolase.neuron specific [Mass/volume] in Serum or Plasma by Immunoassay | 0.889 |  |  0 |          0 |
| 3052201 | Parathyrin.intact [Moles/volume] in Serum or Plasma --5 minutes post excision | 0.889 |  |  0 |          0 |
| 43055371 | Lymphocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.889 |  |  0 |          0 |
| 1092217 | Leukocytes [#/area] in Urine sediment | 0.888 |  |  0 |          0 |
| 3018913 | Phosphate [Moles/volume] in Blood | 0.887 |  |  0 |          0 |
| 3023980 | Creatine kinase [Enzymatic activity/volume] in Body fluid | 0.886 |  |  0 |          0 |
| 3004327 | Lymphocytes [#/volume] in Blood by Automated count | 0.886 | 35 |  0 |          0 |
| 36659751 | 24,25-dihydroxyvitamin D3+24,25-dihydroxyvitamin D2 [Mass/volume] in Serum or Plasma | 0.885 |  |  0 |          0 |
| 43055367 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.883 |  |  0 |          0 |
| 3040637 | Bicarbonate [Moles/volume] standard in Venous cord blood | 0.883 |  |  0 |          0 |
| 3020149 | 25-hydroxyvitamin D3 [Mass/volume] in Serum or Plasma | 0.883 |  |  0 |          0 |
| 3004338 | Enolase.neuron specific [Units/volume] in Serum or Plasma | 0.882 |  |  0 |          0 |
| 3041008 | Bicarbonate [Moles/volume] standard in Arterial cord blood | 0.881 |  |  6 |        712 |
| 3024574 | Basophils/Leukocytes in Specimen by Manual count | 0.881 |  |  0 |          0 |
| 40761899 | Leukocytes [#/volume] in Urine by Automated test strip | 0.880 |  |  0 |          0 |
| 3028615 | Eosinophils [#/volume] in Blood by Automated count | 0.880 | 50 |  0 |          0 |
| 3031368 | Variant lymphocytes/Leukocytes in Blood by Automated count | 0.879 |  |  0 |          0 |
| 3006140 | Bilirubin.total [Moles/volume] in Serum or Plasma | 0.879 | 21 | 12 |  1,506,859 |
| 3038245 | Bilirubin.conjugated [Moles/volume] in Body fluid | 0.878 |  |  0 |          0 |
| 3012608 | Segmented neutrophils/Leukocytes in Blood by Automated count | 0.876 |  |  0 |          0 |
| 40758434 | Fungus [Presence] in Specimen by KOH preparation | 0.874 |  |  0 |          0 |
| 3013429 | Basophils [#/volume] in Blood by Automated count | 0.873 | 27 |  0 |          0 |
| 40757349 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Blood | 0.872 | 362 |  3 |      4,016 |
| 3015834 | Enolase.neuron specific [Enzymatic activity/volume] in Serum or Plasma | 0.872 |  |  0 |          0 |
| 3013149 | Basophils+Eosinophils+Monocytes/Leukocytes in Blood by Automated count | 0.872 |  |  0 |          0 |
| 3013294 | Phosphate [Moles/volume] in Specimen | 0.871 |  |  0 |          0 |
| 706163 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.870 |  |  2 |    961,920 |
| 1259611 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen | 0.869 |  |  0 |          0 |
| 3008994 | Creatine kinase.BB [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.869 |  |  3 |        313 |
| 43055368 | Basophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.869 |  |  0 |          0 |
| 3013942 | Lymphocytes/Leukocytes in Synovial fluid by Automated count | 0.869 |  |  0 |          0 |
| 3010813 | Leukocytes [#/volume] in Blood | 0.868 | 33 | 53 | 11,205,325 |
| 3039350 | Urinalysis other formed elements panel [#/volume] - Urine by Computer assisted method | 0.867 |  |  0 |          0 |
| 42868453 | Bicarbonate [Moles/volume] standard in Plasma | 0.867 |  |  0 |          0 |
| 3016070 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.867 |  |  0 |          0 |
| 3016913 | Creatine kinase.MM [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.866 |  |  3 |        217 |
| 3022231 | Eosinophils/Leukocytes in Body fluid by Manual count | 0.866 | 1824 |  0 |          0 |
| 3008839 | Basophils/Leukocytes in Body fluid by Manual count | 0.866 | 447 |  0 |          0 |
| 3049383 | Erythrocyte [DistWidth] in Cord blood | 0.864 |  |  0 |          0 |
| 3049149 | Renin [Mass/volume] in Plasma --upright | 0.864 |  |  0 |          0 |
| 3005785 | Creatine kinase.MB [Mass/volume] in Serum or Plasma | 0.863 | 111 | 13 |     79,959 |
| 36031238 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with non-probe detection | 0.863 |  |  0 |          0 |
| 43055365 | Monocytes/Leukocytes [Pure number fraction] in Blood by Manual count | 0.863 |  |  0 |          0 |
| 3004411 | Monocytes/Leukocytes in Body fluid by Manual count | 0.862 |  |  0 |          0 |
| 3028895 | Lymphoblasts/Leukocytes in Blood by Manual count | 0.860 |  |  0 |          0 |
| 40762328 | Prostate Specific Ag Free/Prostate specific Ag.total in Pleural fluid | 0.860 |  |  0 |          0 |
| 646531 | Influenza virus A and Influenza virus B and SARS coronavirus 2 and Respiratory syncytial virus Ag panel - Nose by Rapid immunoassay | 0.860 |  |  0 |          0 |
| 3019402 | Monocytes Abnormal/Leukocytes in Blood by Manual count | 0.859 |  |  0 |          0 |
| 648850 | Renin [Measurement] in Plasma | 0.858 |  |  0 |          0 |
| 40761510 | Other cells/Leukocytes in Blood by Automated count | 0.858 |  |  0 |          0 |
| 43055364 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.857 |  |  0 |          0 |
| 36033643 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.857 |  |  0 |          0 |
| 1091922 | Leukocytes [#/volume] in Urethra by Wet preparation | 0.857 |  |  0 |          0 |
| 37021550 | Renin [Units/volume] in Plasma --upright | 0.856 |  |  3 |      1,125 |
| 36031949 | Influenza virus A and B and SARS-CoV+SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.856 |  |  0 |          0 |
| 40759093 | Phosphate [Moles/volume] in Serum or Plasma --post dialysis | 0.856 |  |  0 |          0 |
| 649431 | Phosphate [Measurement] in Serum or Plasma | 0.855 |  |  0 |          0 |
| 3025262 | Renin [Mass/volume] in Plasma --supine | 0.855 |  |  0 |          0 |
| 3037520 | Pronormoblasts [#/volume] in Blood | 0.854 |  |  0 |          0 |
| 3022174 | Leukocytes [#/volume] in Body fluid | 0.852 | 708 |  0 |          0 |
| 21490586 | Blood temperature | 0.851 |  |  0 |          0 |
| 3006504 | Eosinophils/Leukocytes in Blood | 0.851 | 49 | 42 |  1,429,973 |
| 3028638 | Bilirubin.direct [Moles/volume] in Serum or Plasma | 0.851 | 82 |  0 |          0 |
| 3966513 | Influenza virus A and Influenza virus B and SARS coronavirus 2 RNA panel - Nose by NAA with non-probe detection | 0.850 |  |  0 |          0 |
| 3013650 | Neutrophils [#/volume] in Blood by Automated count | 0.850 | 46 |  4 |  2,514,044 |
| 3049473 | Enolase.neuron specific [Mass/volume] in Serum or Plasma by Radioimmunoassay (RIA) | 0.849 |  |  0 |          0 |
| 3005176 | Neutrophils [#/volume] in Urine | 0.849 |  |  0 |          0 |
| 3034458 | CD4+CD45RA+ cells/CD8 Cells [# Ratio] in Blood | 0.849 |  |  0 |          0 |
| 3020688 | Eosinophils/Leukocytes in Sputum by Manual count | 0.849 |  |  0 |          0 |
| 1091110 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Specimen | 0.848 |  |  0 |          0 |
| 36661377 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by Sequencing | 0.848 |  |  0 |          0 |
| 3019897 | Erythrocyte [DistWidth] in Blood by Automated count | 0.847 | 24 | 11 |     16,931 |
| 723465 | SARS-CoV-2 (COVID-19) S gene [Presence] in Respiratory system specimen by NAA with probe detection | 0.846 |  |  0 |          0 |
| 3030170 | Creatine kinase [Mass/volume] in Blood | 0.846 |  |  0 |          0 |
| 3033575 | Monocytes [#/volume] in Blood by Automated count | 0.845 | 52 |  0 |          0 |
| 3020768 | Bilirubin.delta [Moles/volume] in Serum or Plasma | 0.844 |  |  0 |          0 |
| 3006044 | Creatine kinase.total/Creatine kinase.MB [Enzymatic activity ratio] in Serum or Plasma | 0.844 |  |  1 |        100 |
| 3007242 | Bilirubin.indirect [Moles/volume] in Serum or Plasma | 0.844 | 125 |  0 |          0 |
| 3017427 | Lupus anticoagulant neutralization dilute phospholipid [Presence] in Platelet poor plasma | 0.843 | 1189 |  0 |          0 |
| 46235782 | Bilirubin.total [Moles/volume] in Serum, Plasma or Blood | 0.843 |  |  0 |          0 |
| 649172 | Prostate Specific Ag Free [Measurement] in Serum or Plasma | 0.841 |  |  0 |          0 |
| 3019069 | Monocytes/Leukocytes in Blood | 0.839 | 40 | 48 |  1,451,788 |
| 3026844 | Monocytes+Macrophages/Leukocytes in Specimen by Manual count | 0.836 |  |  0 |          0 |
| 3005013 | Prostate Specific Ag Free [Mass/volume] in Serum or Plasma | 0.836 | 554 | 17 |    236,561 |
| 647727 | Enolase.neuron specific [Measurement] in Serum or Plasma | 0.835 |  |  0 |          0 |
| 3001740 | Acetylcholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.833 |  |  0 |          0 |
| 3035173 | Hydrogen ion [Moles/volume] in Arterial blood | 0.833 |  |  0 |          0 |
| 40762014 | CD4+CD45RO+ cells/CD3+CD4+ (T4 helper) cells [# Ratio] in Blood | 0.832 |  |  0 |          0 |
| 40762327 | Prostate Specific Ag Free/Prostate specific Ag.total in Peritoneal fluid | 0.832 |  |  0 |          0 |
| 3026160 | Phosphate [Moles/volume] in Body fluid | 0.832 |  |  0 |          0 |
| 3049111 | Enolase.neuron specific [Mass/volume] in Body fluid | 0.831 |  |  0 |          0 |
| 42870592 | CBC W Differential panel, method unspecified - Blood | 0.831 |  |  0 |          0 |
| 3031248 | Chloride [Moles/volume] in Arterial blood | 0.829 |  |  0 |          0 |
| 3040491 | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | 0.829 |  |  2 |        471 |
| 3004706 | Phosphoserine [Moles/volume] in Serum or Plasma | 0.828 |  |  0 |          0 |
| 3001138 | Prostate Specific Ag Free [Units/volume] in Serum or Plasma | 0.827 | 1854 |  0 |          0 |
| 3038697 | Lupus anticoagulant neutralization platelet [Presence] in Platelet poor plasma by Coagulation assay | 0.827 |  |  0 |          0 |
| 3022229 | Phosphate [Moles/volume] in Urine | 0.825 | 1197 |  3 |        856 |
| 3021960 | Folate [Moles/volume] in Serum or Plasma | 0.825 | 181 |  7 |    209,197 |
| 3002112 | Folate [Mass/volume] in Blood | 0.825 |  |  0 |          0 |
| 40762326 | Prostate Specific Ag Free/Prostate specific Ag.total in Cerebral spinal fluid | 0.824 |  |  0 |          0 |
| 3043744 | Bilirubin.conjugated+indirect [Mass/volume] in Serum or Plasma | 0.824 |  |  0 |          0 |
| 3046121 | Yeast.hyphae [Presence] in Specimen by Wet preparation | 0.820 |  |  0 |          0 |
| 3027184 | Lupus anticoagulant [Interpretation] in Platelet poor plasma | 0.819 |  |  0 |          0 |
| 3041369 | Urinalysis other formed elements panel [#/area] - Urine by Computer assisted method | 0.818 |  |  0 |          0 |
| 3010866 | Cholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.817 |  |  0 |          0 |
| 3041980 | Urinalysis type of cast panel [#/volume] - Urine by Computer assisted method | 0.816 |  |  0 |          0 |
| 1091400 | Fungus [Presence] in Tissue by KOH preparation | 0.815 |  |  0 |          0 |
| 3042779 | Enolase.neuron specific [Mass/volume] in Cerebral spinal fluid | 0.814 |  |  0 |          0 |
| 3015377 | Calcium [Moles/volume] in Serum or Plasma | 0.814 | 12 | 20 |    520,967 |
| 3048400 | Enolase.neuron specific [Mass/volume] in Cerebral spinal fluid by Immunoassay | 0.813 |  |  0 |          0 |
| 3037908 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma | 0.813 |  |  0 |          0 |
| 3041953 | Urinalysis type of crystal panel [#/volume] - Urine by Computer assisted method | 0.811 |  |  0 |          0 |
| 3001490 | Nucleated erythrocytes [#/volume] in Blood | 0.811 |  |  0 |          0 |
| 3009991 | Angiotensin converting enzyme [Enzymatic activity/volume] in Cerebral spinal fluid | 0.810 |  |  3 |      2,955 |
| 1616626 | Enolase.neuron specific [Mass/volume] in Aspirate | 0.809 |  |  0 |          0 |
| 3039179 | Angiotensin converting enzyme [Enzymatic activity/volume] in Peritoneal fluid | 0.809 |  |  0 |          0 |
| 3047178 | Yeast [Presence] in Specimen by Wet preparation | 0.808 | 874 |  0 |          0 |
| 3038738 | Fungus [Presence] in Specimen by Organism specific culture | 0.807 |  |  0 |          0 |
| 3006729 | Transketolase [Enzymatic activity/volume] in Serum | 0.805 |  |  0 |          0 |
| 3008966 | Adenylate kinase [Enzymatic activity/volume] in Serum | 0.804 |  |  0 |          0 |
| 3037816 | CD4+CD8+ cells/100 cells in Blood | 0.804 |  |  0 |          0 |
| 3046588 | Normoblasts/100 blasts in Blood | 0.803 |  |  0 |          0 |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.803 |  |  0 |          0 |
| 42529562 | Prostate Specific Ag Free [Mass/volume] in Serum or Plasma by Immunoassay | 0.803 |  |  0 |          0 |
| 3040005 | Erythroid cells [#/volume] in Blood or Marrow | 0.802 |  |  0 |          0 |
| 3029160 | Normoblasts/100 leukocytes in Blood | 0.801 |  |  0 |          0 |
| 40760142 | Auto Differential panel - Blood | 0.800 |  |  0 |          0 |
| 3041326 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Tissue | 0.798 |  |  0 |          0 |
| 3024507 | Metamyelocytes [#/volume] in Blood | 0.798 |  |  0 |          0 |
| 3041673 | Urinalysis type of non-squamous epithelial cells panel [#/volume] - Urine by Computer assisted method | 0.797 |  |  0 |          0 |
| 3014859 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Body fluid | 0.795 |  |  0 |          0 |
| 40758447 | Fungus [Presence] in Bronchial specimen by KOH preparation | 0.794 |  |  0 |          0 |
| 3025926 | Body temperature - Core | 0.792 |  |  0 |          0 |
| 3002864 | Erythrocytes [#/volume] in Urine by Automated count | 0.791 | 246 |  0 |          0 |
| 40758436 | Fungus [Presence] in Vaginal fluid by KOH preparation | 0.791 |  |  0 |          0 |
| 40758433 | Fungus [Presence] in Sputum by KOH preparation | 0.789 |  |  0 |          0 |
| 40758432 | Fungus [Presence] in Skin by KOH preparation | 0.788 |  |  0 |          0 |
| 3029361 | Urinalysis dipstick panel - Urine by Automated test strip | 0.786 |  |  0 |          0 |
| 3031441 | Tripeptide aminopeptidase [Enzymatic activity/volume] in Serum or Plasma | 0.781 |  |  0 |          0 |
| 3020073 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Specimen | 0.780 |  |  2 |      2,748 |
| 3015209 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bone marrow | 0.780 |  |  0 |          0 |
| 37019573 | Body temperature - Brain | 0.779 |  |  0 |          0 |
| 3014942 | Protein kinase [Enzymatic activity/volume] in Serum | 0.778 |  |  0 |          0 |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.778 | 16 | 21 |  5,367,314 |
| 3036987 | Folate [Mass/volume] in Serum or Plasma | 0.775 |  |  0 |          0 |
| 42528887 | GlycA [Moles/volume] in Serum or Plasma | 0.773 |  |  0 |          0 |
| 3021543 | Triosephosphate isomerase [Enzymatic activity/volume] in Serum | 0.773 |  |  0 |          0 |
| 3030296 | Molybdenum [Moles/volume] in Red Blood Cells | 0.771 |  |  0 |          0 |
| 3049181 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.771 |  |  0 |          0 |
| 21493858 | Methotrexate monoglutamate [Moles/volume] in Red Blood Cells | 0.769 |  |  0 |          0 |
| 3028089 | Alkaline phosphatase isoenzyme [Units/volume] in Serum or Plasma | 0.767 |  |  0 |          0 |
| 44816949 | Thymidine phosphorylase [Enzymatic activity/volume] in DBS | 0.766 |  |  0 |          0 |
| 1001548 | Glycocholate [Moles/volume] in Serum or Plasma | 0.764 |  |  0 |          0 |
| 3037799 | Differential panel - Body fluid | 0.763 |  |  0 |          0 |
| 3008455 | Magnesium [Moles/volume] in Red Blood Cells | 0.763 | 1697 |  0 |          0 |
| 3013088 | Calcium [Moles/volume] in Red Blood Cells | 0.759 |  |  0 |          0 |
| 40765008 | Erythrocyte [DistWidth] in Blood from Fetus by Automated count | 0.759 |  |  0 |          0 |
| 3020990 | Alkaline phosphatase.intestinal/Alkaline phosphatase.total in Serum or Plasma | 0.759 | 1783 |  0 |          0 |
| 3045740 | CD56 cells/CD38 Cells [# Ratio] in Blood | 0.757 |  |  0 |          0 |
| 44787056 | Differential panel - Cord blood | 0.753 |  |  0 |          0 |
| 21492585 | N-alpha acetyllysine [Moles/volume] in Serum or Plasma | 0.751 |  |  0 |          0 |
| 3039189 | Lupus anticoagulant neutralization dilute phospholipid [Time] in Platelet poor plasma | 0.751 |  |  0 |          0 |
| 3008575 | Glycine [Moles/volume] in Serum or Plasma | 0.751 | 1885 |  0 |          0 |
| 3002069 | Alkaline phosphatase.bone/Alkaline phosphatase.total in Serum or Plasma | 0.750 | 1666 |  0 |          0 |
| 3009299 | Lupus anticoagulant neutralization platelet [Time] in Platelet poor plasma by Coagulation assay | 0.749 | 811 |  0 |          0 |
| 3014780 | Pyrimidine-5'-Nucleotidase [Enzymatic activity/volume] in Blood | 0.748 |  |  0 |          0 |
| 21490688 | Body surface temperature | 0.747 |  |  0 |          0 |
| 21491070 | N-acetyltyrosine [Moles/volume] in Serum or Plasma | 0.746 |  |  0 |          0 |
| 40760845 | Protein [Presence] in Urine by Automated test strip | 0.745 |  |  0 |          0 |
| 3027627 | Lupus anticoagulant neutralization high phospholipid [Time] in Platelet poor plasma by Coagulation assay | 0.744 |  |  0 |          0 |
| 3013721 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.744 | 19 | 14 |    513,305 |
| 3039488 | Alkaline phosphatase.intestinal 2/Alkaline phosphatase.total in Serum or Plasma | 0.744 |  |  0 |          0 |
| 3039730 | Alkaline phosphatase.intestinal 3/Alkaline phosphatase.total in Serum or Plasma | 0.743 |  |  0 |          0 |
| 3003511 | Phosphoglycerate kinase [Enzymatic activity/volume] in Serum | 0.743 |  |  0 |          0 |
| 3043435 | Alkaline phosphatase isoenzymes [Enzymatic activity/volume] in Serum or Plasma by Levamisole inhibition | 0.742 |  |  0 |          0 |
| 3036955 | Alkaline phosphatase.liver/Alkaline phosphatase.total in Serum or Plasma | 0.740 | 1664 |  2 |        176 |
| 3051861 | Differential panel - Bone marrow | 0.739 |  |  0 |          0 |
| 3009261 | Glucose [Presence] in Urine by Test strip | 0.739 | 309 | 10 |    946,600 |
| 3014051 | Protein [Presence] in Urine by Test strip | 0.738 | 99 |  3 |    382,676 |
| 1002116 | Glycohyodeoxycholate [Moles/volume] in Serum or Plasma | 0.735 |  |  0 |          0 |
| 3004750 | Body temperature 10 hour | 0.735 |  |  0 |          0 |
| 21490950 | Glycylproline [Moles/volume] in Serum or Plasma | 0.735 |  |  0 |          0 |
| 3046082 | Antithrombin Ag [Presence] in Platelet poor plasma by Immunoassay | 0.733 |  |  0 |          0 |
| 3030260 | Glucose [Presence] in Urine by Automated test strip | 0.733 |  |  0 |          0 |
| 3021583 | Cardiolipin Ab [Presence] in Serum | 0.733 |  |  0 |          0 |
| 3028333 | Cardiolipin IgG Ab [Presence] in Serum | 0.732 |  |  0 |          0 |
| 1988377 | Body temperature - Hand surface | 0.731 |  |  0 |          0 |
| 3025662 | Manual Differential panel - Blood | 0.730 |  |  0 |          0 |
| 3030688 | Urinalysis panel - Urine by Automated | 0.730 |  |  0 |          0 |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 0.729 |  |  6 |  1,393,084 |
| 3046251 | Low molecular weight heparin induced platelet Ab [Presence] in Serum | 0.728 |  |  0 |          0 |
| 40760140 | CBC W Auto Differential panel - Blood | 0.726 |  |  0 |          0 |
| 44816954 | Glycerate [Moles/volume] in Serum or Plasma | 0.726 |  |  0 |          0 |
| 21491067 | Suberylglycine [Moles/volume] in Serum or Plasma | 0.726 |  |  0 |          0 |
| 21491068 | Vanilloylglycine [Moles/volume] in Serum or Plasma | 0.725 |  |  0 |          0 |
| 3017614 | Body temperature 1 hour | 0.717 |  |  0 |          0 |
| 3039856 | Temperature of Skin | 0.716 |  |  0 |          0 |
| 3024629 | Glucose [Mass/volume] in Urine by Test strip | 0.715 |  |  0 |          0 |
| 3006749 | Body temperature 24 hour | 0.715 |  |  0 |          0 |
| 3001289 | Erythrocyte mean corpuscular diameter [Length] | 0.708 |  |  0 |          0 |
| 3012764 | Erythrocyte [Morphology] in Blood | 0.700 | 132 |  0 |          0 |
| 3043216 | Cardiovascular physiologic and EKG assessment panel | 0.695 |  |  0 |          0 |
| 3012441 | Differential panel - Pleural fluid | 0.695 |  |  1 |      6,311 |
| 3050687 | CBC WO Differential panel - Cord blood | 0.690 |  |  0 |          0 |
| 3023075 | Type of EKG leads | 0.684 |  |  0 |          0 |
| 3022525 | Erythrocyte size [Morphology] in Blood | 0.666 |  |  0 |          0 |
| 3002888 | Erythrocyte distribution width [Entitic volume] | 0.658 |  |  0 |          0 |
| 1988764 | Electromyography panel | 0.654 |  |  0 |          0 |
| 1259654 | Diagnostic multisection transesophageal and cardioversion panel Heart | 0.652 |  |  0 |          0 |
| 3026361 | Erythrocytes [#/volume] in Blood | 0.651 |  | 14 | 11,175,264 |
| 1988411 | Permanent pacemaker panel | 0.642 |  |  0 |          0 |
| 3044933 | Cardiac 2D echo panel | 0.641 |  |  0 |          0 |
| 3013512 | EKG study | 0.638 |  | 10 |    506,024 |
| 1988318 | Temporary pacemaker panel | 0.628 |  |  0 |          0 |
| 3044671 | QRS duration {Electrocardiograph lead} | 0.625 |  |  0 |          0 |
| 3052678 | Hematocrit [Volume Fraction] of Dialysis fluid by calculation | 0.619 |  |  0 |          0 |
| 3023665 | Volume of Dialysis fluid | 0.601 |  |  0 |          0 |
| 3022673 | Creatinine [Mass/volume] in Dialysis fluid | 0.595 |  |  0 |          0 |
| 3033858 | Volume of 4 hour Dialysis fluid | 0.581 |  |  0 |          0 |
| 3007196 | Creatinine [Moles/volume] in Dialysis fluid | 0.577 |  |  0 |          0 |
| 3042571 | Creatinine [Moles/time] in 24 hour Dialysis fluid | 0.576 |  |  0 |          0 |
| 3035717 | Potassium [Moles/volume] in Dialysis fluid | 0.574 |  |  0 |          0 |
| 3041197 | Creatinine [Moles/volume] in 24 hour Dialysis fluid | 0.573 |  |  0 |          0 |
| 1989626 | Hemodialysis fluid removed [Volume] 1 hour | 0.573 |  |  0 |          0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1841 | -cd4-solujensuhdecd8-soluihin |  | 667 | 0.3 | [0.26, 0.37, 0.55, 0.73, 1, 1.35, 1.81, 2.32, 3.03] |  |  |  | CD4/CD8 [# Ratio] in Blood | FALSE |
| 1842 | -kt/v,daugirdaksenkaava |  | 176 | 0 | [1.13, 1.23, 1.29, 1.33, 1.39, 1.43, 1.46, 1.5, 1.57] |  |  |  | Kt/V [Ratio] for Dialysis patient by Daugirdas formula | FALSE |
| 1843 | -sieni,natiivivalmiste |  | 244 | 100 |  |  |  |  | Fungus [Presence] in Specimen by Wet mount | FALSE |
| 1844 | ab-aktuaalibikarbonaatti | mmol/l | 14354 | 0 | [18.76, 21.02, 22.57, 23.76, 24.73, 25.7, 26.99, 28.55, 31.59] |  | Arterial blood |  | Bicarbonate [Moles/volume] in Arterial blood | FALSE |
| 1845 | ab-aktuaalibikarbonaatti |  | 47 | 100 |  |  | Arterial blood |  | Bicarbonate [Moles/volume] in Arterial blood | FALSE |
| 1846 | ab-lämpötila(he-tase) | aste | 418 | 0 | [36.38, 36.95, 37, 37, 37, 37, 37.01, 37.48, 38.01] |  | Arterial blood |  | Body temperature | FALSE |
| 1847 | ab-standardibikarbonaatti | mmol/l | 4434 | 0 | [19.73, 21.71, 22.89, 23.76, 24.46, 25.22, 26.01, 27.04, 28.87] |  | Arterial blood |  | Bicarbonate.standard [Moles/volume] in Arterial blood | FALSE |
| 1848 | ab-standardibikarbonaatti |  | 20 | 100 |  |  | Arterial blood |  | Bicarbonate.standard [Moles/volume] in Arterial blood | FALSE |
| 1849 | alkalinenfosfataasi | u/l | 4090 | 0 | [51.93, 59.73, 66.52, 72.54, 78.85, 86.09, 95.45, 111.37, 142.22] |  |  |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1850 | alkalinenfosfataasi |  | 409 | 100 |  |  |  |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1851 | angiotensiini-1-konvertaasi | u/l | 286 | 0 | [21.5, 28.51, 36.37, 41.21, 48.76, 54.44, 63.62, 70.94, 80.3] |  |  |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1852 | angiotensiini-1-konvertaasi |  | 20 | 100 |  |  |  |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1853 | b-diffi,erittelylaskenta,klooni |  | 142 | 100 |  |  | Blood |  | Differential panel, method unspecified - Blood | TRUE |
| 1854 | cb-standardibikarbonaatti | mmol/l | 10798 | 0 | [20.28, 22.23, 23.36, 24.16, 24.9, 25.66, 26.58, 27.89, 30.19] |  | Capillary blood |  | Bicarbonate.standard [Moles/volume] in Capillary blood | FALSE |
| 1855 | cb-standardibikarbonaatti |  | 90 | 50 |  |  | Capillary blood |  | Bicarbonate.standard [Moles/volume] in Capillary blood | FALSE |
| 1856 | d-vitamiini-25-oh,d3-jad2-muodot | nmol/l | 219 | 0 | [48.54, 55.58, 61.96, 68.73, 74.1, 79.27, 84.22, 89.91, 106.45] |  |  |  | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma | FALSE |
| 1857 | d-vitamiini-25-oh,plasmasta | nmol/l | 694 | 0 | [44.59, 53.15, 59, 64.66, 69.89, 76.01, 82.54, 92.02, 105.7] |  |  |  | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma | FALSE |
| 1858 | e-punasolujenkokojakaum | % | 55570 | 0 | [12.19, 12.59, 12.95, 13.26, 13.67, 14.09, 14.51, 14.98, 15.71] |  | Erythrocyte |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1859 | e-punasolujenkokojakaum |  | 7 | 71.43 |  |  | Erythrocyte |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1860 | e-punasolujenkokojakauma | % | 196935 | 0 | [12, 13, 13, 13, 13.69, 14, 14.05, 15, 16.37] |  | Erythrocyte |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1861 | e-punasolujenkokojakauma |  | 1688 | 46.92 | [15, 15, 15.98, 16, 16, 16.41, 17, 18, 19.59] |  | Erythrocyte |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1862 | e-rdw,punasolujenkokojakauma | % | 25929 | 0 | [12.08, 13, 13, 13.03, 14, 14, 15, 15.7, 17.03] |  | Erythrocyte |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1863 | e-rdw,punasolujenkokojakauma |  | 76 | 100 |  |  | Erythrocyte |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1864 | ekg,hoitoyksikönottama |  | 213 | 100 |  |  |  |  | 12 lead EKG panel | TRUE |
| 1865 | ekgasiakkaanottama |  | 257 | 100 |  |  |  |  | 12 lead EKG panel | TRUE |
| 1866 | erikoislääkärinkonsultaatio |  | 118 | 100 |  |  |  |  |  | FALSE |
| 1867 | folaatti(fe-folaat) | nmol/l | 320 | 0 | [1456.69, 1642.98, 1740.68, 1864.47, 2021, 2152.9, 2311.39, 2519.36, 2775.52] |  |  |  | Folate [Moles/volume] in Red Blood Cells | FALSE |
| 1868 | folaatti(fe-folaat) |  | 12 | 100 |  |  |  |  | Folate [Moles/volume] in Red Blood Cells | FALSE |
| 1869 | fosfaatti,epäorgaaninen | mmol/l | 275 | 0 | [0.83, 0.93, 0.99, 1.05, 1.1, 1.15, 1.23, 1.36, 1.64] |  |  |  | Phosphate [Moles/volume] in Serum or Plasma | FALSE |
| 1870 | fosfaatti,epäorgaaninen |  | 13 | 100 |  |  |  |  | Phosphate [Moles/volume] in Serum or Plasma | FALSE |
| 1871 | fp-fosfaatti,epäorgaaninen | mmol/l | 1537 | 0 | [0.81, 0.94, 1.04, 1.12, 1.21, 1.31, 1.45, 1.64, 2] |  | Fasting plasma |  | Phosphate [Moles/volume] in Serum or Plasma | FALSE |
| 1872 | fp-fosfaatti,epäorgaaninen |  | 7 | 100 |  |  | Fasting plasma |  | Phosphate [Moles/volume] in Serum or Plasma | FALSE |
| 1873 | fp-parathormoni(intakti) | ng/l | 167 | 0 | [34.58, 43.28, 53.6, 64.34, 75.77, 88.59, 106.04, 128.88, 166.07] |  | Fasting plasma |  | Parathyrin.intact [Mass/volume] in Serum or Plasma | FALSE |
| 1874 | fp-parathormoni,intakti | ng/l | 443 | 0 | [42.85, 55.73, 66.85, 78.78, 88.68, 102.07, 115.78, 136.81, 193.49] |  | Fasting plasma |  | Parathyrin.intact [Mass/volume] in Serum or Plasma | FALSE |
| 1875 | fp-parathormoni,intakti | pmol/l | 213 | 0 | [5.11, 7.29, 9.06, 12.26, 16.48, 21.96, 29.55, 41.46, 57.9] |  | Fasting plasma |  | Parathyrin.intact [Moles/volume] in Serum or Plasma | FALSE |
| 1876 | fp-parathormoni,intakti |  | 5 | 60 |  |  | Fasting plasma |  |  | FALSE |
| 1877 | fp-reniini,konsentraatio | mu/l | 275 | 0 | [1.9, 3.7, 5.72, 9.15, 13.8, 21.38, 36.23, 69.29, 149] |  | Fasting plasma |  | Renin [Enzymatic activity/volume] in Plasma | FALSE |
| 1878 | fp-reniini,konsentraatio |  | 9 | 100 |  |  | Fasting plasma |  | Renin [Enzymatic activity/volume] in Plasma | FALSE |
| 1879 | fras,oksidatiivinenstressi |  | 508 | 100 |  |  |  |  |  | FALSE |
| 1880 | fs-alkalinenfosfataasi | u/l | 114 | 0 |  |  | Fasting serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1881 | fs-angiotensiini-1-konvertaasi | u/l | 168 | 0 | [21.95, 28.78, 36.13, 43.17, 50.38, 57.02, 63.03, 69.31, 88.3] |  | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1882 | fs-angiotensiini-1-konvertaasi |  | 17 | 100 |  |  | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1883 | fs-monikanava4-7tthperuspaketti |  | 125 | 100 |  |  | Fasting serum |  |  | TRUE |
| 1884 | fs-työterveyshuollonperuspaketti |  | 141 | 100 |  |  | Fasting serum |  |  | TRUE |
| 1885 | ilmajohtotarv.luujohto |  | 785 | 100 |  |  |  |  |  | FALSE |
| 1886 | korona-rs-influenssa,pcrpikatesti |  | 6428 | 100 |  |  |  |  | SARS-CoV-2 & Influenza virus A & Influenza virus B & Respiratory syncytial virus RNA panel - Respiratory specimen by NAA | TRUE |
| 1887 | kreatiinikinaasi | u/l | 821 | 0 | [51.45, 67.28, 78.98, 91.33, 108.19, 125.74, 161.13, 224.43, 350.78] |  |  |  | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1888 | l-basofiilit,automaatio | % | 10670 | 0 | [0, 0, 0.5, 1, 1, 1, 1, 1, 1] |  | Leukocyte |  | Basophils/Leukocytes in Blood by Automated count | FALSE |
| 1889 | l-eosinofiilit,automaatio | % | 10670 | 0 | [0.35, 1, 1.93, 2, 2.74, 3, 3.97, 4.81, 6.33] |  | Leukocyte |  | Eosinophils/Leukocytes in Blood by Automated count | FALSE |
| 1890 | l-lymfosyytit,automaatio | % | 19279 | 0 | [15.56, 20.42, 24.04, 26.95, 29.66, 32.37, 35.21, 38.75, 43.79] |  | Leukocyte |  | Lymphocytes/Leukocytes in Blood by Automated count | FALSE |
| 1891 | l-lymfosyytit,automaatio |  | 23 | 100 |  |  | Leukocyte |  | Lymphocytes/Leukocytes in Blood by Automated count | FALSE |
| 1892 | l-monosyytit,automaatio | % | 19276 | 0 | [5.94, 6.98, 7.19, 8, 8.78, 9.04, 10, 11, 12.64] |  | Leukocyte |  | Monocytes/Leukocytes in Blood by Automated count | FALSE |
| 1893 | l-monosyytit,automaatio |  | 23 | 100 |  |  | Leukocyte |  | Monocytes/Leukocytes in Blood by Automated count | FALSE |
| 1894 | l-neutrofiilit,automaatio | % | 19277 | 0 | [41.43, 47.16, 50.99, 54.23, 57.08, 59.98, 63.15, 67.08, 72.76] |  | Leukocyte |  | Neutrophils/Leukocytes in Blood by Automated count | FALSE |
| 1895 | l-neutrofiilit,automaatio |  | 23 | 100 |  |  | Leukocyte |  | Neutrophils/Leukocytes in Blood by Automated count | FALSE |
| 1896 | laktaattidehydrogenaasi | u/l | 112 | 0 | [166.9, 176.25, 189.57, 200, 217.89, 228.73, 246.21, 285.8, 336.3] |  |  |  | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1897 | p-aktuaalinenbikarbonaatti | mmol/l | 1258 | 0 | [20.16, 23.03, 24.56, 25.84, 26.91, 27.87, 28.97, 30.03, 32.38] |  | Plasma |  | Bicarbonate [Moles/volume] in Venous blood | FALSE |
| 1898 | p-alkaalinenfosfataasi | u/l | 218 | 0 | [54.87, 64.51, 69.29, 74.44, 80.78, 89.02, 97.67, 107.93, 128.13] |  | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1899 | p-alkaalinenfosfataasi |  | 6 | 16.67 |  |  | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1900 | p-alkalinenfosfataasi | u/l | 26335 | 0 | [51.5, 59.65, 66.46, 73.03, 79.94, 87.78, 97.91, 113.11, 149.16] |  | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1901 | p-alkalinenfosfataasi |  | 74 | 91.89 |  |  | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1902 | p-bilirubiinikonjugaatit | umol/l | 1839 | 0 | [2.92, 3, 3.32, 4, 4.89, 5.93, 7.57, 10.11, 21.15] |  | Plasma |  | Bilirubin.conjugated [Moles/volume] in Serum or Plasma | FALSE |
| 1903 | p-bilirubiinikonjugaatit |  | 168 | 100 |  |  | Plasma |  | Bilirubin.conjugated [Moles/volume] in Serum or Plasma | FALSE |
| 1904 | p-fosfaatti,epäorgaaninen | mmol/l | 436 | 0 | [0.89, 0.99, 1.06, 1.13, 1.2, 1.27, 1.36, 1.47, 1.66] |  | Plasma |  | Phosphate [Moles/volume] in Serum or Plasma | FALSE |
| 1905 | p-kreatiinikinaasi | u/l | 2765 | 0 | [43.61, 57.48, 70.52, 85.33, 100.93, 124.44, 165.61, 239.04, 491.32] |  | Plasma |  | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1906 | p-kreatiinikinaasi |  | 21 | 95.24 |  |  | Plasma |  | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1907 | p-laktaattidehydrogenaasi | u/l | 3272 | 0 | [163.71, 178.57, 190.98, 203.43, 216.38, 231.67, 254.03, 288.21, 372.84] |  | Plasma |  | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1908 | p-laktaattidehydrogenaasi |  | 29 | 96.55 |  |  | Plasma |  | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1909 | p-lupusantikoagulantti |  | 220 | 100 |  |  | Plasma |  | Lupus anticoagulant [Presence] in Plasma | FALSE |
| 1910 | p-psavapaanosuustotaalista | % | 719 | 0 | [10.55, 13.9, 16.1, 18.77, 21.1, 23.88, 26.7, 30.17, 36.09] |  | Plasma |  | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | FALSE |
| 1911 | p-urea,resirkulaatio | mmol/l | 200 | 0 | [4.65, 12.03, 14.2, 15.66, 16.84, 18.43, 19.52, 21.22, 23.14] |  | Plasma |  |  | FALSE |
| 1912 | psa-vapaa/totaali-suhde,plasmasta | % | 1183 | 0 | [8.11, 11.04, 13.43, 15.83, 18.18, 20.89, 24.81, 29.88, 39.78] |  |  |  | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | FALSE |
| 1913 | psa-vapaa/totaali-suhde,plasmasta |  | 3428 | 100 |  |  |  |  | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | FALSE |
| 1914 | psavapaanjatotaalinsuhde | % | 62 | 0 |  |  |  |  | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | FALSE |
| 1915 | psavapaanjatotaalinsuhde |  | 180 | 97.78 |  |  |  |  | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | FALSE |
| 1916 | pt-vaativainhalaatiohoito |  | 114 | 100 |  |  | Patient |  |  | FALSE |
| 1917 | punasolojenkokojakauma | % | 1068 | 0 | [12, 12.05, 13, 13, 13, 13, 13.97, 14, 14.47] |  |  |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1918 | punasolojenkokojakauma |  | 7 | 100 |  |  |  |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1919 | punasolujenerittelylaskenta | % | 41 | 0 |  |  |  |  |  | FALSE |
| 1920 | punasolujenerittelylaskenta |  | 433 | 6 | [12, 12, 12.18, 13, 13, 13, 13, 13.97, 14] |  |  |  |  | FALSE |
| 1921 | punasolujenesiasteet(erytroblastit) | e9/l | 1040 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  | Normoblasts [#/volume] in Blood | FALSE |
| 1922 | punasolujenesiasteet(erytroblastit) |  | 24 | 100 |  |  |  |  | Normoblasts [#/volume] in Blood | FALSE |
| 1923 | punasolujenkokojakauma | % | 155883 | 0 | [12.28, 13, 13, 13.02, 14, 14, 15, 15.9, 17] |  |  |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1924 | punasolujenkokojakauma |  | 2478 | 99.48 |  |  |  |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1925 | punasolujenkokojakautuma | % | 683 | 0 | [13, 13, 13, 13, 13, 14, 14, 14, 14.95] |  |  |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1926 | punasolujenkoonvaihtelu | % | 2031 | 0 | [12.51, 12.91, 13.17, 13.34, 13.62, 13.91, 14.31, 14.86, 15.92] |  |  |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1927 | punasolut,kokojakauma | % | 121 | 0 | [13, 13, 13, 13, 14, 14, 14, 14, 15] |  |  |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1928 | s-alkalinenfosfataasi | u/l | 368 | 0 | [52.79, 63.98, 76.35, 87.37, 103.68, 118.86, 131.06, 146.22, 181.47] |  | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1929 | s-alkalinenfosfataasi,isoentsyymit |  | 318 | 100 |  |  | Serum |  | Alkaline phosphatase.isoenzymes panel - Serum | TRUE |
| 1930 | s-glykoproteiininasetylaatio | mmol/l | 265 | 0 | [0.75, 0.79, 0.81, 0.83, 0.85, 0.88, 0.9, 0.94, 1] |  | Serum |  | Glycoprotein acetyls [Moles/volume] in Serum or Plasma by NMR | FALSE |
| 1931 | s-neuronispesifinenenolaasi | ug/l | 105 | 0 |  |  | Serum |  | Neuron specific enolase [Mass/volume] in Serum or Plasma | FALSE |
| 1932 | s-nightingale-mittaus |  | 265 | 100 |  |  | Serum |  |  | TRUE |
| 1933 | s-psavapaanjatotaalinsuhde | % | 106 | 0 | [11, 13, 14.4, 16.35, 19, 21, 23.87, 27, 31.9] |  | Serum |  | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | FALSE |
| 1934 | s-psavapaanjatotaalinsuhde |  | 264 | 100 |  |  | Serum |  | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | FALSE |
| 1935 | s-tymidiinikinaasi | u/l | 237 | 0 | [3.92, 4.79, 5.63, 6.48, 7.24, 8.95, 10.78, 13.93, 39.38] |  | Serum |  | Thymidine kinase [Enzymatic activity/volume] in Serum | FALSE |
| 1936 | s-vapaanjakokonais-psa:nsuhde | % | 643 | 0 | [11.89, 14.35, 17.11, 19.53, 21.76, 24, 27.79, 31.6, 36.6] |  | Serum |  | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | FALSE |
| 1937 | s-vapaanjakokonais-psa:nsuhde |  | 1561 | 100 |  |  | Serum |  | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | FALSE |
| 1938 | sars-cov-2,influenssaa,bja |  | 161 | 100 |  |  |  |  | SARS-CoV-2 & Influenza virus A & Influenza virus B RNA panel - Respiratory specimen by NAA | TRUE |
| 1939 | sars-cov-2-antigeenitesti,pikatesti |  | 101 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Immunoassay | FALSE |
| 1940 | tth-pakettia(ilmanpaastoa) |  | 1079 | 100 |  |  |  |  |  | TRUE |
| 1941 | tth:ssavirtsanprotjagluk |  | 294 | 100 |  |  |  |  | Urinalysis protein and glucose panel - Urine by Test strip | TRUE |
| 1942 | u-solut,peruslaskenta |  | 1772 | 100 |  |  | Urine |  | Urinalysis microscopic panel [#/volume] - Urine by Automated count | TRUE |
| 1943 | vb-aktuaalibikarbonaatti | mmol/l | 1612 | 0 | [16.94, 19.74, 21.93, 23.14, 24.18, 25.06, 26.96, 28.44, 30.92] |  | Venous blood |  | Bicarbonate [Moles/volume] in Venous blood | FALSE |
| 1944 | vb-aktuaalibikarbonaatti |  | 185 | 17.3 | [20.1, 23.3, 24.38, 25.39, 26.05, 26.8, 27.78, 28.4, 29.7] |  | Venous blood |  | Bicarbonate [Moles/volume] in Venous blood | FALSE |
| 1945 | vb-standardibikarbonaatti | mmol/l | 13754 | 0 | [20.04, 21.93, 23.08, 23.95, 24.68, 25.36, 26.13, 27.07, 28.82] |  | Venous blood |  | Bicarbonate.standard [Moles/volume] in Venous blood | FALSE |
| 1946 | vb-standardibikarbonaatti |  | 44 | 100 |  |  | Venous blood |  | Bicarbonate.standard [Moles/volume] in Venous blood | FALSE |
| 1947 | virtsansolujenhl7-siirtoon | e6/l | 5551 | 0 | [0.1, 0.37, 0.65, 1.07, 1.65, 2.44, 3.88, 6.78, 14.04] |  |  |  | Leukocytes [#/volume] in Urine | FALSE |
| 1948 | virtsansolujenhl7-siirtoon |  | 353 | 11.05 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  | Leukocytes [#/volume] in Urine | FALSE |
| 1949 | zb-aktuaalibikarbonaatti | mmol/l | 394 | 0 | [22, 23, 23.94, 24, 25, 26, 27, 27.8, 29.78] |  | Central blood |  | Bicarbonate [Moles/volume] in Central venous blood | FALSE |

