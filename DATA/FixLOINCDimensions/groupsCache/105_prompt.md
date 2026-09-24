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
Here is group 105.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3000905 | Leukocytes [#/volume] in Blood by Automated count | 1.000 | 15 |  0 |          0 |
| 3000963 | Hemoglobin [Mass/volume] in Blood | 1.000 | 2 | 57 | 11,265,093 |
| 3002030 | Lymphocytes/Leukocytes in Blood | 1.000 | 45 | 65 |  1,465,459 |
| 3003338 | MCHC [Entitic Mass/volume] in Red Blood Cells | 1.000 |  | 16 |  7,331,654 |
| 3004327 | Lymphocytes [#/volume] in Blood by Automated count | 1.000 | 35 |  0 |          0 |
| 3006504 | Eosinophils/Leukocytes in Blood | 1.000 | 49 | 42 |  1,429,973 |
| 3009542 | Hematocrit [Volume Fraction] of Blood by calculation | 1.000 | 28 | 29 | 11,407,235 |
| 3010813 | Leukocytes [#/volume] in Blood | 1.000 | 33 | 53 | 11,205,325 |
| 3013429 | Basophils [#/volume] in Blood by Automated count | 1.000 | 27 |  0 |          0 |
| 3013650 | Neutrophils [#/volume] in Blood by Automated count | 1.000 | 46 |  4 |  2,514,044 |
| 3018010 | Neutrophils/Leukocytes in Blood | 1.000 | 76 | 55 |  1,410,042 |
| 3019069 | Monocytes/Leukocytes in Blood | 1.000 | 40 | 48 |  1,451,788 |
| 3022096 | Basophils/Leukocytes in Blood | 1.000 | 54 | 48 |  1,446,628 |
| 3024731 | MCV [Entitic mean volume] in Red Blood Cells | 1.000 | 34 | 18 | 11,148,804 |
| 3024929 | Platelets [#/volume] in Blood by Automated count | 1.000 | 18 |  0 |          0 |
| 3026361 | Erythrocytes [#/volume] in Blood | 1.000 |  | 14 | 11,175,264 |
| 3028615 | Eosinophils [#/volume] in Blood by Automated count | 1.000 | 50 |  0 |          0 |
| 3033575 | Monocytes [#/volume] in Blood by Automated count | 1.000 | 52 |  0 |          0 |
| 3035933 | Granulocytes/Leukocytes in Blood | 1.000 |  |  5 |     34,440 |
| 3035941 | MCH [Entitic mass] | 1.000 |  | 15 | 11,139,123 |
| 3041084 | Immature granulocytes [#/volume] in Blood by Automated count | 1.000 |  |  0 |          0 |
| 40758558 | Short blood count panel - Blood | 1.000 |  |  8 |    872,285 |
| 40761511 | CBC panel - Blood by Automated count | 1.000 |  |  5 |  6,172,064 |
| 42869452 | Immature granulocytes/Leukocytes in Blood by Automated count | 1.000 |  |  0 |          0 |
| 3002385 | Erythrocyte [DistWidth] in Blood | 0.961 |  | 20 |  7,004,505 |
| 1092441 | Hematocrit [Pure volume fraction] of Blood by calculation | 0.946 |  |  0 |          0 |
| 3016682 | Platelets [#/volume] in Plasma by Automated count | 0.945 |  |  0 |          0 |
| 3009932 | Eosinophils [#/volume] in Blood by Manual count | 0.940 |  |  0 |          0 |
| 3040168 | Immature granulocytes [#/volume] in Blood | 0.938 |  |  0 |          0 |
| 3027651 | Basophils [#/volume] in Blood by Manual count | 0.938 |  |  0 |          0 |
| 1616298 | Platelets [#/volume] in Blood by Automated count.optical | 0.937 |  |  0 |          0 |
| 3008108 | Hematocrit [Volume Fraction] of Body fluid by calculation | 0.935 | 733 |  0 |          0 |
| 3034107 | Monocytes [#/volume] in Blood by Manual count | 0.933 | 472 |  0 |          0 |
| 40762530 | MCHC [Entitic Moles/volume] in Red Blood Cells | 0.932 |  |  0 |          0 |
| 3003215 | Lymphocytes [#/volume] in Blood by Manual count | 0.925 |  |  0 |          0 |
| 3006696 | Leukocytes [#/volume] in Specimen by Automated count | 0.924 |  |  0 |          0 |
| 3028022 | Lymphocytes [#/volume] in Specimen by Automated count | 0.923 |  |  0 |          0 |
| 3006315 | Basophils [#/volume] in Blood | 0.921 | 121 | 26 |  1,519,691 |
| 3017501 | Neutrophils [#/volume] in Blood by Manual count | 0.919 |  |  1 |         17 |
| 3013115 | Eosinophils [#/volume] in Blood | 0.917 | 67 | 35 |  1,618,391 |
| 3030232 | Leukocytes other [#/volume] in Blood by Automated count | 0.916 |  |  0 |          0 |
| 3001604 | Monocytes [#/volume] in Blood | 0.915 | 61 | 29 |  1,513,142 |
| 3023230 | Hematocrit [Volume Fraction] of Arterial blood by calculation | 0.913 |  |  0 |          0 |
| 3010834 | Platelets [#/volume] in Blood by Manual count | 0.912 |  |  0 |          0 |
| 40760140 | CBC W Auto Differential panel - Blood | 0.910 |  |  0 |          0 |
| 3010910 | Erythrocytes [#/volume] in Body fluid | 0.910 | 435 |  0 |          0 |
| 3003282 | Leukocytes [#/volume] in Blood by Manual count | 0.907 |  |  0 |          0 |
| 40760954 | Leukocytes [#/volume] in Body fluid by Automated count | 0.906 | 438 |  0 |          0 |
| 3017732 | Neutrophils [#/volume] in Blood | 0.906 | 57 | 42 |    179,947 |
| 3034976 | Hematocrit [Volume Fraction] of Venous blood by calculation | 0.906 |  |  0 |          0 |
| 3008511 | Leukocytes other [#/volume] in Blood | 0.905 |  |  0 |          0 |
| 3039367 | Monocytes+Macrophages/Leukocytes in Blood | 0.904 |  |  0 |          0 |
| 3019198 | Lymphocytes [#/volume] in Blood | 0.903 | 70 | 38 |  1,557,180 |
| 3028813 | Hematocrit [Volume Fraction] of Capillary blood by calculation | 0.900 |  |  0 |          0 |
| 3039827 | Platelets [#/volume] in Body fluid by Automated count | 0.900 |  |  0 |          0 |
| 3034531 | Granulocytes [#/volume] in Blood by Automated count | 0.899 |  |  0 |          0 |
| 3044916 | Immature granulocytes [Presence] in Blood by Automated count | 0.897 | 1866 |  0 |          0 |
| 42869583 | Hematocrit [Pure volume fraction] of Body fluid by calculation | 0.896 |  |  0 |          0 |
| 3046553 | Variant lymphocytes [#/volume] in Blood by Automated count | 0.895 |  |  0 |          0 |
| 40762531 | MCH [Entitic substance] | 0.895 |  |  0 |          0 |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.892 |  |  0 |          0 |
| 3046900 | Leukocytes [#/volume] corrected for nucleated erythrocytes in Blood by Automated count | 0.891 | 2010 |  0 |          0 |
| 3022174 | Leukocytes [#/volume] in Body fluid | 0.890 | 708 |  0 |          0 |
| 3009744 | MCHC [Entitic Mass/volume] in Red Blood Cells by Automated count | 0.890 | 10 |  0 |          0 |
| 3021302 | Basophils/Leukocytes in Body fluid | 0.889 | 1519 |  0 |          0 |
| 3023599 | MCV [Entitic mean volume] in Red Blood Cells by Automated count | 0.889 | 17 |  0 |          0 |
| 3043688 | Hemoglobin [Mass/volume] in Body fluid | 0.888 |  |  0 |          0 |
| 3038104 | Monocytes/Leukocytes in Body fluid | 0.888 | 369 |  0 |          0 |
| 3050479 | Immature granulocytes/Leukocytes in Blood | 0.887 |  |  0 |          0 |
| 3027484 | Hemoglobin [Mass/volume] in Blood by calculation | 0.887 |  |  0 |          0 |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.887 |  |  0 |          0 |
| 3007461 | Platelets [#/volume] in Blood | 0.886 | 31 | 19 | 11,196,211 |
| 3052191 | Erythrocytes [#/volume] in Cord blood | 0.886 |  |  0 |          0 |
| 3037511 | Lymphocytes/Leukocytes in Blood by Automated count | 0.886 | 41 |  0 |          0 |
| 3021453 | Eosinophils/Leukocytes in Body fluid | 0.885 | 418 |  0 |          0 |
| 42528761 | Leukocytes [#/volume] in Bone marrow by Automated count | 0.884 |  |  0 |          0 |
| 3031759 | Lymphoblasts/Leukocytes in Blood | 0.883 |  |  0 |          0 |
| 1469714 | Platelets [#/volume] in Blood by Automated count --in presence of EDTA to detect possible clumping | 0.881 |  |  0 |          0 |
| 3002173 | Hemoglobin [Mass/volume] in Arterial blood | 0.880 | 188 |  9 |    371,451 |
| 3010457 | Eosinophils/Leukocytes in Blood by Automated count | 0.880 | 43 |  0 |          0 |
| 3020416 | Erythrocytes [#/volume] in Blood by Automated count | 0.879 | 9 |  0 |          0 |
| 3013084 | Monocytes Abnormal/Leukocytes in Blood | 0.879 |  |  0 |          0 |
| 3051314 | MCHC [Entitic Mass/volume] in Red Blood Cells from Cord blood | 0.877 |  |  0 |          0 |
| 40758902 | Hematocrit [Volume Fraction] of Bone marrow by calculation | 0.877 |  |  0 |          0 |
| 1091805 | Hematocrit [Volume Fraction] of Blood by calculation --baseline | 0.877 |  |  0 |          0 |
| 40768826 | Monocytes [#/volume] in Blood from Fetus by Manual count | 0.876 |  |  0 |          0 |
| 3027017 | Erythrocytes [#/volume] in Blood by Manual count | 0.875 |  |  0 |          0 |
| 43055373 | Basophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.875 |  |  0 |          0 |
| 40768825 | Basophils [#/volume] in Blood from Fetus by Manual count | 0.874 |  |  0 |          0 |
| 3002582 | Erythrocytes [#/volume] in Urine | 0.873 |  | 12 |    500,225 |
| 3013869 | Basophils/Leukocytes in Blood by Automated count | 0.873 | 42 |  0 |          0 |
| 3001657 | Leukocytes [#/volume] corrected for nucleated erythrocytes in Blood | 0.873 | 1504 |  0 |          0 |
| 42869584 | Hematocrit [Pure volume fraction] of Venous blood by calculation | 0.872 |  |  0 |          0 |
| 40765005 | Platelets [#/volume] in Blood from Fetus by Automated count | 0.871 |  |  0 |          0 |
| 3002272 | Eosinophils/Leukocytes in Specimen | 0.870 |  |  0 |          0 |
| 43055371 | Lymphocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.870 |  |  0 |          0 |
| 44786800 | Granulocytes/Leukocytes in Body fluid | 0.869 |  |  2 |        585 |
| 3014502 | Neutrophils/Leukocytes in Body fluid | 0.869 | 954 |  0 |          0 |
| 3030332 | Immature monocytes [#/volume] in Blood by Manual count | 0.868 |  |  0 |          0 |
| 44816673 | Platelets [#/volume] in Platelet rich plasma by Automated count | 0.868 |  |  0 |          0 |
| 3018095 | Leukocytes [#/volume] in Urine | 0.868 | 201 | 20 |    676,308 |
| 3026710 | Lymphocytes [#/volume] in Blood by Flow cytometry (FC) | 0.866 |  |  0 |          0 |
| 1092234 | Monocytes [#/volume] in Blood by Flow cytometry (FC) | 0.865 |  |  0 |          0 |
| 3022055 | Basophils/Leukocytes in Specimen | 0.864 |  |  0 |          0 |
| 3049383 | Erythrocyte [DistWidth] in Cord blood | 0.864 |  |  0 |          0 |
| 43055372 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.864 |  |  0 |          0 |
| 3001490 | Nucleated erythrocytes [#/volume] in Blood | 0.864 |  |  0 |          0 |
| 3001465 | Band form neutrophils [#/volume] in Blood by Automated count | 0.863 |  |  0 |          0 |
| 3032393 | Leukocytes [#/volume] in Blood by Estimate | 0.862 |  |  0 |          0 |
| 42869449 | Platelets reticulated [#/volume] in Blood by Automated count | 0.862 |  |  0 |          0 |
| 40758903 | Hemoglobin [Mass/volume] in Blood by Oximetry | 0.861 |  |  0 |          0 |
| 3021940 | Eosinophils/Leukocytes in Sputum | 0.861 |  |  0 |          0 |
| 3028920 | Lymphocytes Immunoblastic [#/volume] in Blood by Manual count | 0.861 |  |  0 |          0 |
| 3013950 | Basophils+Eosinophils+Monocytes [#/volume] in Blood by Automated count | 0.860 |  |  0 |          0 |
| 3043107 | Immature eosinophils [#/volume] in Blood by Manual count | 0.860 |  |  0 |          0 |
| 3022493 | Free Hemoglobin [Mass/volume] in Plasma | 0.859 | 1917 |  4 |      9,350 |
| 3006184 | Hemoglobin [Mass/volume] in Capillary blood | 0.858 |  | 10 |     25,042 |
| 40768824 | Eosinophils [#/volume] in Blood from Fetus by Manual count | 0.858 |  |  0 |          0 |
| 3038248 | Deoxyhemoglobin [Mass/volume] in Blood | 0.858 |  |  0 |          0 |
| 3041717 | Basophils [#/volume] in Body fluid by Manual count | 0.858 |  |  0 |          0 |
| 3047146 | Leukocytes [#/volume] in Blood from Blood product unit | 0.857 |  |  0 |          0 |
| 3034226 | Lambda lymphocytes/Lymphocytes in Blood | 0.857 |  |  0 |          0 |
| 3031639 | Reticulocytes panel - Blood | 0.856 |  |  0 |          0 |
| 3038720 | Eosinophils [#/volume] in Body fluid by Manual count | 0.855 |  |  0 |          0 |
| 3015233 | Abnormal lymphocytes/Leukocytes in Blood | 0.855 |  |  0 |          0 |
| 43055369 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.854 |  |  0 |          0 |
| 3032929 | Immature eosinophils/Leukocytes in Blood | 0.853 |  |  0 |          0 |
| 3007357 | Lymphoma cells/Leukocytes in Blood | 0.852 |  |  0 |          0 |
| 3004119 | Hemoglobin [Mass/volume] in Venous blood | 0.852 | 1986 | 10 |     97,228 |
| 3015956 | Eosinophils/Leukocytes in Blood by Manual count | 0.852 | 229 |  2 |      1,540 |
| 3014528 | Neutrophils [#/volume] in Pleural fluid by Automated count | 0.851 |  |  0 |          0 |
| 3035768 | Promonocytes/Leukocytes in Blood | 0.850 |  |  0 |          0 |
| 3028079 | Lymphocytes/Leukocytes in Body fluid | 0.849 | 370 |  0 |          0 |
| 1092301 | Erythrocytes [#/volume] in Urine sediment | 0.848 |  |  0 |          0 |
| 3019897 | Erythrocyte [DistWidth] in Blood by Automated count | 0.847 | 24 | 11 |     16,931 |
| 40760892 | CBC W Ordered Manual Differential panel - Blood | 0.847 |  |  3 |    490,892 |
| 3008342 | Neutrophils/Leukocytes in Blood by Automated count | 0.847 | 25 |  0 |          0 |
| 3029798 | Monocytes [#/volume] in Body fluid by Manual count | 0.847 |  |  0 |          0 |
| 3040005 | Erythroid cells [#/volume] in Blood or Marrow | 0.847 |  |  0 |          0 |
| 43055370 | Monocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.846 |  |  0 |          0 |
| 40762351 | Hemoglobin [Moles/volume] in Blood | 0.846 |  |  0 |          0 |
| 3011948 | Monocytes/Leukocytes in Blood by Automated count | 0.845 | 44 |  0 |          0 |
| 3023468 | Monocytes Abnormal [#/volume] in Blood by Manual count | 0.845 |  |  0 |          0 |
| 3021056 | Basophils/Leukocytes in Sputum | 0.842 |  |  0 |          0 |
| 3017057 | Lymphocytes+Monocytes/Leukocytes in Blood | 0.840 |  |  0 |          0 |
| 3027475 | Erythrocytes [#/volume] in Cerebral spinal fluid | 0.840 | 641 | 10 |     16,111 |
| 44787055 | CBC W Differential panel - Cord blood | 0.839 |  |  0 |          0 |
| 3009797 | Basophils/Leukocytes in Blood by Manual count | 0.838 | 235 |  0 |          0 |
| 3027368 | Neutrophils/Leukocytes in Blood by Manual count | 0.838 | 1191 |  0 |          0 |
| 3022407 | Monocytes/Leukocytes in Blood by Manual count | 0.838 | 225 |  0 |          0 |
| 3031793 | Immature monocytes/Leukocytes in Blood | 0.838 |  |  0 |          0 |
| 3011185 | Granulocytes/Leukocytes in Blood by Automated count | 0.837 |  |  0 |          0 |
| 42870592 | CBC W Differential panel, method unspecified - Blood | 0.837 |  |  0 |          0 |
| 3005377 | Eosinophils/Leukocytes in Stool | 0.836 |  |  0 |          0 |
| 3026514 | Neutrophils/Leukocytes in Sputum | 0.832 |  |  0 |          0 |
| 3027359 | Monocytes/Leukocytes in Urine | 0.831 |  |  0 |          0 |
| 3046909 | Immature basophils/Leukocytes in Blood by Manual count | 0.831 |  |  0 |          0 |
| 3046885 | Immature basophils [#/volume] in Blood by Manual count | 0.829 |  |  0 |          0 |
| 3017354 | Segmented neutrophils/Leukocytes in Blood | 0.828 |  |  6 |     15,889 |
| 40760141 | CBC W Reflex Manual Differential panel - Blood | 0.824 |  |  0 |          0 |
| 3024557 | Granulocytes/Leukocytes in Blood by Manual count | 0.824 | 423 |  0 |          0 |
| 3964927 | Monocytes/Leukocytes in Blood by Flow cytometry (FC) | 0.823 |  |  0 |          0 |
| 3038784 | Granulocytes [#/volume] in Blood by Manual count | 0.823 |  |  0 |          0 |
| 1091949 | Eosinophils/Leukocytes in Urine sediment | 0.823 |  |  0 |          0 |
| 40771529 | Immature granulocytes/Leukocytes in Body fluid | 0.821 |  |  0 |          0 |
| 3000121 | Eosinophils/Leukocytes in Bronchial specimen | 0.820 |  |  0 |          0 |
| 3031745 | Lymphocytes Plasmacytoid/Leukocytes in Blood | 0.820 |  |  0 |          0 |
| 3013498 | Variant lymphocytes/Leukocytes in Blood | 0.818 | 817 |  0 |          0 |
| 3012030 | MCH [Entitic mass] by Automated count | 0.817 | 11 |  0 |          0 |
| 3003683 | Granulocytes/Leukocytes in Urine | 0.817 |  |  0 |          0 |
| 3050687 | CBC WO Differential panel - Cord blood | 0.817 |  |  0 |          0 |
| 44787105 | Basophils/Leukocytes in Blood from Fetus | 0.815 |  |  0 |          0 |
| 3010557 | Basophils+Eosinophils+Monocytes/Leukocytes in Blood | 0.815 |  |  0 |          0 |
| 3006867 | Basophils/Leukocytes in Nose | 0.811 |  |  0 |          0 |
| 3013166 | Neutrophils/Leukocytes in Synovial fluid | 0.810 |  |  3 |      1,674 |
| 40765007 | MCHC [Entitic Mass/volume] in Red Blood Cells from Fetus by Automated count | 0.808 |  |  0 |          0 |
| 3035715 | Granulocytes [#/volume] in Blood | 0.808 | 2002 |  2 |     28,336 |
| 3051341 | MCH [Entitic mass] in Cord blood | 0.807 |  |  0 |          0 |
| 3042527 | Neutrophils.immature/Leukocytes in Blood | 0.804 |  |  0 |          0 |
| 3006571 | Granulocytes/Leukocytes in Synovial fluid | 0.799 |  | 17 |      8,256 |
| 3051950 | MCV [Entitic mean volume] in Cord blood | 0.790 |  |  1 |         24 |
| 3049858 | Reticulocyte mean volume [Entitic volume] in Reticulocytes | 0.788 |  |  0 |          0 |
| 3039385 | Mean sphered cell volume [Entitic volume] in Red Blood Cells | 0.788 |  |  0 |          0 |
| 40765003 | MCV [Entitic mean volume] in Red Blood Cells from Fetus by Automated count | 0.766 |  |  0 |          0 |
| 40765008 | Erythrocyte [DistWidth] in Blood from Fetus by Automated count | 0.759 |  |  0 |          0 |
| 36660656 | CBC W Differential panel - Stem cell product | 0.750 |  |  0 |          0 |
| 3001123 | Platelet mean volume [Entitic volume] in Blood | 0.746 |  |  0 |          0 |
| 3037713 | Hemogram without Platelets panel - Blood | 0.736 |  |  0 |          0 |
| 3050583 | Platelets panel - Blood by Automated count | 0.732 |  |  0 |          0 |
| 3964676 | Basic metabolic and hematocrit panel - Blood | 0.732 |  |  0 |          0 |
| 40765004 | MCH [Entitic mass] in Blood from Fetus by Automated count | 0.724 |  |  0 |          0 |
| 1260092 | Basic metabolic with hemoglobin and hematocrit panel - Blood | 0.716 |  |  0 |          0 |
| 40760142 | Auto Differential panel - Blood | 0.716 |  |  0 |          0 |
| 40761510 | Other cells/Leukocytes in Blood by Automated count | 0.709 |  |  0 |          0 |
| 3021223 | Hemogram without Platelets and with Manual Differential panel - Blood | 0.708 |  |  0 |          0 |
| 3001289 | Erythrocyte mean corpuscular diameter [Length] | 0.708 |  |  0 |          0 |
| 3050452 | Leukogram panel - Blood | 0.708 |  |  0 |          0 |
| 40758546 | Short blood pressure panel | 0.703 |  |  0 |          0 |
| 3044045 | Cell count and Differential panel - Body fluid | 0.701 |  |  0 |          0 |
| 3012764 | Erythrocyte [Morphology] in Blood | 0.700 | 132 |  0 |          0 |
| 3048885 | Erythrogram panel - Blood | 0.697 |  |  0 |          0 |
| 40761509 | Erythrocyte morphology panel - Blood | 0.689 |  |  0 |          0 |
| 3022525 | Erythrocyte size [Morphology] in Blood | 0.666 |  |  0 |          0 |
| 3002888 | Erythrocyte distribution width [Entitic volume] | 0.658 |  |  0 |          0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1305 | b-pvk | % | 1036 | 0 | [12.98, 13, 13, 13, 13.02, 14, 14, 14, 14.9] | B -Perusverenkuva | Blood |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1306 | b-pvk | e12/l | 180 | 0 |  | B -Perusverenkuva | Blood |  | Erythrocytes [#/volume] in Blood | FALSE |
| 1307 | b-pvk | e9/l | 180 | 0 |  | B -Perusverenkuva | Blood |  | Leukocytes [#/volume] in Blood | FALSE |
| 1308 | b-pvk | fl | 191 | 0 |  | B -Perusverenkuva | Blood |  | MCV [Entitic mean volume] in Red Blood Cells | FALSE |
| 1309 | b-pvk | form | 6 | 0 |  | B -Perusverenkuva | Blood |  |  | FALSE |
| 1310 | b-pvk | g/l | 371 | 0 | [130.49, 135.97, 140.17, 143.56, 146.5, 149.94, 154.99, 161.16, 169.87] | B -Perusverenkuva | Blood |  | Hemoglobin [Mass/volume] in Blood | FALSE |
| 1311 | b-pvk | paketti | 261 | 0 | [31329.79, 60496.46, 87166.96, 116360.34, 146168.26, 177141.71, 213025.07, 240401.38, 278743.21] | B -Perusverenkuva | Blood |  | Short blood count panel - Blood | TRUE |
| 1312 | b-pvk | pg | 191 | 0 |  | B -Perusverenkuva | Blood |  | MCH [Entitic mass] | FALSE |
| 1313 | b-pvk |  | 1084645 | 100 |  | B -Perusverenkuva | Blood |  | Short blood count panel - Blood | TRUE |
| 1314 | b-pvk(pi) |  | 994 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1315 | b-pvk+eo |  | 1355 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1316 | b-pvk+kd |  | 335 | 100 |  |  | Blood |  | CBC panel - Blood by Automated count | TRUE |
| 1317 | b-pvk+ne |  | 301325 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1318 | b-pvk+ner |  | 551 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1319 | b-pvk+t | % | 16337 | 0 | [8.54, 11.43, 12.73, 13.01, 14.63, 21.66, 27.29, 34.08, 48.89] | B -Perusverenkuva ja trombosyytit | Blood |  |  | FALSE |
| 1320 | b-pvk+t | %g | 229 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Granulocytes/Leukocytes in Blood | FALSE |
| 1321 | b-pvk+t | %l | 229 | 0 | [15.3, 18.86, 20.93, 24.39, 26.09, 27.9, 29.48, 31.36, 37.88] | B -Perusverenkuva ja trombosyytit | Blood |  | Lymphocytes/Leukocytes in Blood | FALSE |
| 1322 | b-pvk+t | %m | 229 | 0 | [9, 10, 10.3, 10.73, 11, 11.47, 11.97, 12.55, 13.3] | B -Perusverenkuva ja trombosyytit | Blood |  | Monocytes/Leukocytes in Blood | FALSE |
| 1323 | b-pvk+t | e12/l | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Erythrocytes [#/volume] in Blood | FALSE |
| 1324 | b-pvk+t | e9/l | 4647 | 0 | [0, 0, 0, 0, 0, 0, 2.04, 5.2, 8.91] | B -Perusverenkuva ja trombosyytit | Blood |  | Leukocytes [#/volume] in Blood | FALSE |
| 1325 | b-pvk+t | fl | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | MCV [Entitic mean volume] in Red Blood Cells | FALSE |
| 1326 | b-pvk+t | form | 361 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.89, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |  | FALSE |
| 1327 | b-pvk+t | g/l | 2746 | 0 | [312.86, 315.11, 317.96, 319.16, 327.56, 334.19, 340.53, 346.44, 355.56] | B -Perusverenkuva ja trombosyytit | Blood |  | MCHC [Entitic Mass/volume] in Red Blood Cells | FALSE |
| 1328 | b-pvk+t | l/l | 6 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Hematocrit [Volume Fraction] of Blood by calculation | FALSE |
| 1329 | b-pvk+t | paketti | 269 | 0 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  | Short blood count panel - Blood | TRUE |
| 1330 | b-pvk+t | pg | 2769 | 0 | [29, 29.58, 30, 30.35, 31, 31.07, 32, 32.99, 34.11] | B -Perusverenkuva ja trombosyytit | Blood |  | MCH [Entitic mass] | FALSE |
| 1331 | b-pvk+t |  | 4547373 | 100 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  | Short blood count panel - Blood | TRUE |
| 1332 | b-pvk+t+e |  | 1491 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1333 | b-pvk+t+n |  | 20012 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1334 | b-pvk+t+ne |  | 1150 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1335 | b-pvk+t+r |  | 713 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1336 | b-pvk+tk |  | 466 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1337 | b-pvk+tkd | % | 567 | 0 | [10.52, 11.98, 22.28, 26.53, 30.21, 32.92, 36.29, 39.43, 43.1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  | Lymphocytes/Leukocytes in Blood | FALSE |
| 1338 | b-pvk+tkd | e9/l | 5 | 0 |  | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |  | FALSE |
| 1339 | b-pvk+tkd |  | 347141 | 99.77 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  | CBC panel - Blood by Automated count | TRUE |
| 1340 | b-pvk+tkd,baso | % | 4387 | 0 | [0.13, 0.2, 0.3, 0.34, 0.4, 0.5, 0.59, 0.7, 0.91] |  | Blood |  | Basophils/Leukocytes in Blood | FALSE |
| 1341 | b-pvk+tkd,baso | e9/l | 4345 | 0 | [0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.05, 0.06] |  | Blood |  | Basophils [#/volume] in Blood by Automated count | FALSE |
| 1342 | b-pvk+tkd,baso |  | 28 | 96.43 |  |  | Blood |  | Basophils/Leukocytes in Blood | FALSE |
| 1343 | b-pvk+tkd,eo | % | 4389 | 0 | [0.28, 0.95, 1.44, 1.88, 2.38, 2.9, 3.5, 4.34, 5.77] |  | Blood |  | Eosinophils/Leukocytes in Blood | FALSE |
| 1344 | b-pvk+tkd,eo | e9/l | 4355 | 0 | [0.02, 0.07, 0.1, 0.13, 0.16, 0.2, 0.24, 0.3, 0.39] |  | Blood |  | Eosinophils [#/volume] in Blood by Automated count | FALSE |
| 1345 | b-pvk+tkd,eo |  | 35 | 77.14 |  |  | Blood |  | Eosinophils/Leukocytes in Blood | FALSE |
| 1346 | b-pvk+tkd,eryt | e12/l | 4432 | 0 | [3.69, 4.01, 4.19, 4.32, 4.47, 4.6, 4.71, 4.86, 5.08] |  | Blood |  | Erythrocytes [#/volume] in Blood | FALSE |
| 1347 | b-pvk+tkd,eryt |  | 28 | 82.14 |  |  | Blood |  | Erythrocytes [#/volume] in Blood | FALSE |
| 1348 | b-pvk+tkd,hb | g/l | 4431 | 0 | [109.63, 119.87, 125.6, 130.31, 134.35, 137.72, 141.31, 145.38, 151.58] |  | Blood |  | Hemoglobin [Mass/volume] in Blood | FALSE |
| 1349 | b-pvk+tkd,hb |  | 28 | 82.14 |  |  | Blood |  | Hemoglobin [Mass/volume] in Blood | FALSE |
| 1350 | b-pvk+tkd,hkr | osuus | 4430 | 0 | [0.34, 0.36, 0.38, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45] |  | Blood |  | Hematocrit [Volume Fraction] of Blood by calculation | FALSE |
| 1351 | b-pvk+tkd,hkr |  | 28 | 82.14 |  |  | Blood |  | Hematocrit [Volume Fraction] of Blood by calculation | FALSE |
| 1352 | b-pvk+tkd,ig | % | 4380 | 0 | [0, 0.1, 0.18, 0.2, 0.2, 0.24, 0.3, 0.4, 0.66] |  | Blood |  | Immature granulocytes/Leukocytes in Blood by Automated count | FALSE |
| 1353 | b-pvk+tkd,ig | e9/l | 4329 | 0 | [0, 0.01, 0.01, 0.01, 0.01, 0.02, 0.02, 0.03, 0.06] |  | Blood |  | Immature granulocytes [#/volume] in Blood by Automated count | FALSE |
| 1354 | b-pvk+tkd,ig |  | 27 | 100 |  |  | Blood |  | Immature granulocytes/Leukocytes in Blood by Automated count | FALSE |
| 1355 | b-pvk+tkd,leuk | e9/l | 4441 | 0 | [4.64, 5.29, 5.87, 6.47, 7.06, 7.73, 8.41, 9.34, 10.91] |  | Blood |  | Leukocytes [#/volume] in Blood by Automated count | FALSE |
| 1356 | b-pvk+tkd,leuk |  | 23 | 100 | [4.39, 5.06, 5.62, 6.11, 6.7, 7.36, 7.96, 8.73, 10.19] |  | Blood |  | Leukocytes [#/volume] in Blood by Automated count | FALSE |
| 1357 | b-pvk+tkd,lymph | % | 4402 | 0 | [14.51, 18.87, 22.17, 24.95, 27.85, 30.77, 33.85, 37.68, 42.79] |  | Blood |  | Lymphocytes/Leukocytes in Blood | FALSE |
| 1358 | b-pvk+tkd,lymph | e9/l | 4366 | 0 | [1.07, 1.3, 1.5, 1.68, 1.87, 2.05, 2.28, 2.59, 3.03] |  | Blood |  | Lymphocytes [#/volume] in Blood by Automated count | FALSE |
| 1359 | b-pvk+tkd,lymph |  | 39 | 71.79 |  |  | Blood |  | Lymphocytes/Leukocytes in Blood | FALSE |
| 1360 | b-pvk+tkd,mch | pg | 4427 | 0 | [27.35, 28.81, 29.01, 30, 30, 30.98, 31, 31.99, 32.41] |  | Blood |  | MCH [Entitic mass] | FALSE |
| 1361 | b-pvk+tkd,mch |  | 26 | 88.46 |  |  | Blood |  | MCH [Entitic mass] | FALSE |
| 1362 | b-pvk+tkd,mchc | g/l | 4422 | 0 | [316.84, 322.97, 327.09, 330.49, 333.34, 336.5, 339.82, 343.59, 348.74] |  | Blood |  | MCHC [Entitic Mass/volume] in Red Blood Cells | FALSE |
| 1363 | b-pvk+tkd,mchc |  | 27 | 85.19 |  |  | Blood |  | MCHC [Entitic Mass/volume] in Red Blood Cells | FALSE |
| 1364 | b-pvk+tkd,mcv | fl | 4432 | 0 | [83.81, 86.19, 87.9, 89.02, 90.1, 91.52, 92.95, 94.05, 96.04] |  | Blood |  | MCV [Entitic mean volume] in Red Blood Cells | FALSE |
| 1365 | b-pvk+tkd,mcv |  | 25 | 92 |  |  | Blood |  | MCV [Entitic mean volume] in Red Blood Cells | FALSE |
| 1366 | b-pvk+tkd,mono | % | 4397 | 0 | [6.39, 7.45, 8.16, 8.78, 9.38, 10.01, 10.67, 11.64, 13.06] |  | Blood |  | Monocytes/Leukocytes in Blood | FALSE |
| 1367 | b-pvk+tkd,mono | e9/l | 4364 | 0 | [0.41, 0.48, 0.54, 0.59, 0.65, 0.7, 0.78, 0.88, 1.03] |  | Blood |  | Monocytes [#/volume] in Blood by Automated count | FALSE |
| 1368 | b-pvk+tkd,mono |  | 32 | 84.38 |  |  | Blood |  | Monocytes/Leukocytes in Blood | FALSE |
| 1369 | b-pvk+tkd,neut | % | 4407 | 0 | [43.3, 48.04, 51.9, 55.37, 58.56, 61.78, 65.36, 69.3, 74.25] |  | Blood |  | Neutrophils/Leukocytes in Blood | FALSE |
| 1370 | b-pvk+tkd,neut | e9/l | 4373 | 0 | [2.18, 2.67, 3.11, 3.55, 4, 4.52, 5.12, 5.94, 7.37] |  | Blood |  | Neutrophils [#/volume] in Blood by Automated count | FALSE |
| 1371 | b-pvk+tkd,neut |  | 34 | 82.35 |  |  | Blood |  | Neutrophils/Leukocytes in Blood | FALSE |
| 1372 | b-pvk+tkd,rdw | % | 4298 | 0 | [12.5, 12.85, 13.17, 13.49, 13.79, 14.12, 14.57, 15.17, 16.52] |  | Blood |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1373 | b-pvk+tkd,rdw |  | 30 | 76.67 |  |  | Blood |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1374 | b-pvk+tkd,trom | eg/l | 4413 | 0 | [163.91, 190.28, 209.92, 228.62, 246.86, 267.53, 293.03, 326.64, 371.27] |  | Blood |  | Platelets [#/volume] in Blood by Automated count | FALSE |
| 1375 | b-pvk+tkd,trom |  | 31 | 74.19 |  |  | Blood |  | Platelets [#/volume] in Blood by Automated count | FALSE |
| 1376 | b-pvk+tmd | % | 108 | 0 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  |  | FALSE |
| 1377 | b-pvk+tmd |  | 31394 | 99.96 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  | CBC with 3 part differential panel - Blood | TRUE |
| 1378 | b-pvk-päi |  | 120 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1379 | b-pvk-t |  | 1651 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1380 | b-pvk-tkd |  | 5227 | 100 |  |  | Blood |  | CBC panel - Blood by Automated count | TRUE |
| 1381 | b-pvkt |  | 540592 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1382 | b-pvkt+re |  | 3032 | 100 |  |  | Blood |  | CBC with reticulocyte panel - Blood | TRUE |
| 1383 | b-pvktkdr |  | 6444 | 100 |  |  | Blood |  | CBC W Auto Differential and Reticulocyte panel - Blood | TRUE |
| 1384 | b-pvktmdl |  | 275 | 100 |  |  | Blood |  | CBC with 3 part differential panel - Blood | TRUE |
| 1385 | b-pvktmdp |  | 1012 | 100 |  |  | Blood |  | CBC with 3 part differential panel - Blood | TRUE |
| 1386 | b-pvktnee |  | 9809 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1387 | b-pvktp |  | 5212 | 100 |  |  | Blood |  | Short blood count panel - Blood | TRUE |
| 1388 | b-tvk | % | 505 | 0 | [0, 0, 0, 0, 1, 2.55, 12.33, 37.94, 62.13] | B -Täydellinen verenkuva | Blood |  | Neutrophils/Leukocytes in Blood | FALSE |
| 1389 | b-tvk | e9/l | 368 | 0 | [0.03, 0.03, 0.04, 0.04, 0.05, 0.05, 0.06, 0.07, 0.09] | B -Täydellinen verenkuva | Blood |  | Basophils [#/volume] in Blood by Automated count | FALSE |
| 1390 | b-tvk | fl | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  | MCV [Entitic mean volume] in Red Blood Cells | FALSE |
| 1391 | b-tvk | form | 11 | 0 |  | B -Täydellinen verenkuva | Blood |  |  | FALSE |
| 1392 | b-tvk | g/l | 19 | 0 |  | B -Täydellinen verenkuva | Blood |  |  | FALSE |
| 1393 | b-tvk | paketti | 22 | 0 |  | B -Täydellinen verenkuva | Blood |  | CBC panel - Blood by Automated count | TRUE |
| 1394 | b-tvk | pg | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  | MCH [Entitic mass] | FALSE |
| 1395 | b-tvk |  | 466809 | 100 |  | B -Täydellinen verenkuva | Blood |  | CBC panel - Blood by Automated count | TRUE |
| 1396 | b-tvk+r |  | 465 | 100 |  |  | Blood |  | CBC W Auto Differential and Reticulocyte panel - Blood | TRUE |

