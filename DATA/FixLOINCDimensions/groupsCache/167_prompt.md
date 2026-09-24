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
Here is group 167.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3001604 | Monocytes [#/volume] in Blood | 1.000 | 61 | 29 |  1,513,142 |
| 3002030 | Lymphocytes/Leukocytes in Blood | 1.000 | 45 | 65 |  1,465,459 |
| 3005229 | Alpha 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 | 316 | 10 |     39,833 |
| 3006315 | Basophils [#/volume] in Blood | 1.000 | 121 | 26 |  1,519,691 |
| 3006504 | Eosinophils/Leukocytes in Blood | 1.000 | 49 | 42 |  1,429,973 |
| 3008342 | Neutrophils/Leukocytes in Blood by Automated count | 1.000 | 25 |  0 |          0 |
| 3010457 | Eosinophils/Leukocytes in Blood by Automated count | 1.000 | 43 |  0 |          0 |
| 3011948 | Monocytes/Leukocytes in Blood by Automated count | 1.000 | 44 |  0 |          0 |
| 3013115 | Eosinophils [#/volume] in Blood | 1.000 | 67 | 35 |  1,618,391 |
| 3013650 | Neutrophils [#/volume] in Blood by Automated count | 1.000 | 46 |  4 |  2,514,044 |
| 3013869 | Basophils/Leukocytes in Blood by Automated count | 1.000 | 42 |  0 |          0 |
| 3015322 | Alpha 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 | 315 |  9 |     38,126 |
| 3015377 | Calcium [Moles/volume] in Serum or Plasma | 1.000 | 12 | 20 |    520,967 |
| 3018010 | Neutrophils/Leukocytes in Blood | 1.000 | 76 | 55 |  1,410,042 |
| 3019069 | Monocytes/Leukocytes in Blood | 1.000 | 40 | 48 |  1,451,788 |
| 3019198 | Lymphocytes [#/volume] in Blood | 1.000 | 70 | 38 |  1,557,180 |
| 3021589 | Normoblasts [#/volume] in Blood | 1.000 |  | 22 |  2,299,398 |
| 3022096 | Basophils/Leukocytes in Blood | 1.000 | 54 | 48 |  1,446,628 |
| 3023465 | Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 | 323 |  4 |     34,144 |
| 3028286 | Albumin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 | 313 |  4 |      3,222 |
| 3028615 | Eosinophils [#/volume] in Blood by Automated count | 1.000 | 50 |  0 |          0 |
| 3037511 | Lymphocytes/Leukocytes in Blood by Automated count | 1.000 | 41 |  0 |          0 |
| 3043723 | Beta 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 |  | 11 |     39,801 |
| 3043747 | Beta 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 1.000 |  | 11 |     39,732 |
| 3002385 | Erythrocyte [DistWidth] in Blood | 0.961 |  | 20 |  7,004,505 |
| 3046681 | Beta 2 globulin+Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.955 |  |  0 |          0 |
| 3015956 | Eosinophils/Leukocytes in Blood by Manual count | 0.946 | 229 |  2 |      1,540 |
| 3009797 | Basophils/Leukocytes in Blood by Manual count | 0.941 | 235 |  0 |          0 |
| 3009932 | Eosinophils [#/volume] in Blood by Manual count | 0.940 |  |  0 |          0 |
| 3016901 | Lambda lymphocytes [#/volume] in Blood | 0.936 |  |  0 |          0 |
| 3022407 | Monocytes/Leukocytes in Blood by Manual count | 0.934 | 225 |  0 |          0 |
| 3048248 | Gamma 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.933 |  |  0 |          0 |
| 1091526 | Gamma globulin [Mass/volume] in Serum or Plasma | 0.933 |  |  0 |          0 |
| 3027368 | Neutrophils/Leukocytes in Blood by Manual count | 0.925 | 1191 |  0 |          0 |
| 1091762 | Alpha 1 globulin [Mass/volume] in Serum or Plasma | 0.922 |  |  0 |          0 |
| 3016520 | Beta globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.921 | 314 |  0 |          0 |
| 3013429 | Basophils [#/volume] in Blood by Automated count | 0.921 | 27 |  0 |          0 |
| 3017501 | Neutrophils [#/volume] in Blood by Manual count | 0.919 |  |  1 |         17 |
| 1092292 | Alpha 2 globulin [Mass/volume] in Serum or Plasma | 0.919 |  |  0 |          0 |
| 3030664 | Beta 1 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.916 |  |  0 |          0 |
| 3044821 | Beta 2 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.916 |  |  0 |          0 |
| 3033575 | Monocytes [#/volume] in Blood by Automated count | 0.915 | 52 |  0 |          0 |
| 3020192 | Gamma globulin [Mass/volume] in Body fluid by Electrophoresis | 0.914 |  |  0 |          0 |
| 3033622 | Lymphocytes/Leukocytes in Specimen by Automated count | 0.914 |  |  0 |          0 |
| 43055372 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.913 |  |  0 |          0 |
| 3040757 | Calcium [Moles/volume] in Serum or Plasma --baseline | 0.912 |  |  0 |          0 |
| 1988791 | Gamma globulin [Mass/volume] in Serum or Plasma by Immunofixation | 0.912 |  |  0 |          0 |
| 3038058 | Lymphocytes/Leukocytes in Blood by Manual count | 0.911 | 186 |  0 |          0 |
| 3011185 | Granulocytes/Leukocytes in Blood by Automated count | 0.910 |  |  0 |          0 |
| 3030947 | Beta 1 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.910 |  |  0 |          0 |
| 3028602 | Gamma globulin [Mass/volume] in Urine by Electrophoresis | 0.910 |  |  0 |          0 |
| 3027651 | Basophils [#/volume] in Blood by Manual count | 0.909 |  |  0 |          0 |
| 40757485 | Beta 2 globulin [Mass/volume] in Urine by Electrophoresis | 0.908 |  |  0 |          0 |
| 40757484 | Beta 1 globulin [Mass/volume] in Urine by Electrophoresis | 0.907 |  |  0 |          0 |
| 3008512 | Albumin [Mass/volume] in Urine by Electrophoresis | 0.907 | 1035 |  0 |          0 |
| 3017732 | Neutrophils [#/volume] in Blood | 0.906 | 57 | 42 |    179,947 |
| 43055373 | Basophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.906 |  |  0 |          0 |
| 3006906 | Calcium [Mass/volume] in Serum or Plasma | 0.904 |  |  1 |          8 |
| 3039367 | Monocytes+Macrophages/Leukocytes in Blood | 0.904 |  |  0 |          0 |
| 3000516 | Gamma globulin [Mass/volume] in Synovial fluid by Electrophoresis | 0.904 |  |  0 |          0 |
| 3021347 | Calcium.ionized [Moles/volume] in Serum or Plasma | 0.904 | 182 | 74 |  1,333,722 |
| 3012633 | Alpha 1 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.903 |  |  0 |          0 |
| 3030548 | Basophils [#/volume] in Body fluid | 0.903 |  |  0 |          0 |
| 3022361 | Alpha 1 globulin [Mass/volume] in Urine by Electrophoresis | 0.903 |  |  0 |          0 |
| 3004327 | Lymphocytes [#/volume] in Blood by Automated count | 0.903 | 35 |  0 |          0 |
| 3045286 | Beta globulin+Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.902 |  |  0 |          0 |
| 3034107 | Monocytes [#/volume] in Blood by Manual count | 0.901 | 472 |  0 |          0 |
| 3045561 | Albumin [Mass/volume] in Body fluid by Electrophoresis | 0.899 |  |  0 |          0 |
| 3034531 | Granulocytes [#/volume] in Blood by Automated count | 0.899 |  |  0 |          0 |
| 3032360 | Lymphocytes+Monocytes [#/volume] in Blood | 0.897 |  |  0 |          0 |
| 3037039 | Alpha 2 globulin [Mass/volume] in Urine by Electrophoresis | 0.895 |  |  0 |          0 |
| 3030972 | Beta 2 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.895 |  |  0 |          0 |
| 43055428 | Alpha 1 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.894 |  |  0 |          0 |
| 44787037 | Normoblasts [#/volume] in Cord blood | 0.894 |  |  0 |          0 |
| 43055370 | Monocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.894 |  |  0 |          0 |
| 43055369 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.893 |  |  0 |          0 |
| 3010043 | Alpha 2 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.893 |  |  0 |          0 |
| 3032084 | Eosinophils [#/volume] in Body fluid | 0.892 |  |  0 |          0 |
| 3003467 | Lymphocytes [#/volume] in Body fluid | 0.892 |  |  0 |          0 |
| 44787097 | Normoblasts [#/volume] in Blood from Fetus | 0.891 |  |  0 |          0 |
| 1988608 | Beta 2 globulin [Mass/volume] in 24 hour Urine by Electrophoresis | 0.890 |  |  0 |          0 |
| 3003215 | Lymphocytes [#/volume] in Blood by Manual count | 0.890 |  |  0 |          0 |
| 3021302 | Basophils/Leukocytes in Body fluid | 0.889 | 1519 |  0 |          0 |
| 1988171 | Alpha 1 antitrypsin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.889 |  |  0 |          0 |
| 43055371 | Lymphocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.889 |  |  0 |          0 |
| 1989002 | Beta 1 globulin [Mass/volume] in 24 hour Urine by Electrophoresis | 0.888 |  |  0 |          0 |
| 3038104 | Monocytes/Leukocytes in Body fluid | 0.888 | 369 |  0 |          0 |
| 40759043 | IgG [Mass/volume] in Serum by Electrophoresis | 0.888 |  |  0 |          0 |
| 3002590 | Prealbumin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.888 |  |  0 |          0 |
| 3032917 | Immature eosinophils [#/volume] in Blood | 0.887 |  |  0 |          0 |
| 3031141 | Monocytes [#/volume] in Body fluid | 0.887 |  |  0 |          0 |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.887 |  |  0 |          0 |
| 43055424 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.886 |  |  0 |          0 |
| 43055432 | Albumin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.886 |  |  0 |          0 |
| 3018997 | Alpha 1 globulin [Mass/volume] in Synovial fluid by Electrophoresis | 0.886 |  |  0 |          0 |
| 3000060 | B lymphocytes [#/volume] in Blood | 0.885 |  |  3 |      3,643 |
| 3024800 | Alpha 1 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.885 |  |  0 |          0 |
| 1091665 | Lymphocytes [#/volume] in Specimen | 0.885 |  |  0 |          0 |
| 3000905 | Leukocytes [#/volume] in Blood by Automated count | 0.885 | 15 |  0 |          0 |
| 3005162 | Calcium [Moles/volume] in Blood | 0.885 |  |  0 |          0 |
| 3021453 | Eosinophils/Leukocytes in Body fluid | 0.885 | 418 |  0 |          0 |
| 3031781 | Immature monocytes [#/volume] in Blood | 0.884 |  |  0 |          0 |
| 43055367 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.883 |  |  0 |          0 |
| 3031759 | Lymphoblasts/Leukocytes in Blood | 0.883 |  |  0 |          0 |
| 3006330 | Alpha 2 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.881 |  |  0 |          0 |
| 44787042 | Monocytes [#/volume] in Cord blood | 0.881 |  |  0 |          0 |
| 3024574 | Basophils/Leukocytes in Specimen by Manual count | 0.881 |  |  0 |          0 |
| 3032946 | Lymphoblasts [#/volume] in Blood | 0.881 |  |  0 |          0 |
| 3031729 | Lymphocytes Immunoblastic [#/volume] in Blood | 0.880 |  |  0 |          0 |
| 44787049 | Basophils [#/volume] in Cord blood | 0.880 |  |  0 |          0 |
| 3031368 | Variant lymphocytes/Leukocytes in Blood by Automated count | 0.879 |  |  0 |          0 |
| 3013084 | Monocytes Abnormal/Leukocytes in Blood | 0.879 |  |  0 |          0 |
| 3046948 | Albumin/Globulin [Mass Ratio] in Serum or Plasma by Electrophoresis | 0.878 |  |  0 |          0 |
| 3035933 | Granulocytes/Leukocytes in Blood | 0.878 |  |  5 |     34,440 |
| 3012608 | Segmented neutrophils/Leukocytes in Blood by Automated count | 0.876 |  |  0 |          0 |
| 3000939 | Alpha 2 globulin [Mass/volume] in Synovial fluid by Electrophoresis | 0.876 |  |  0 |          0 |
| 3030511 | Albumin [Mass/volume] in 24 hour Urine by Electrophoresis | 0.874 |  |  0 |          0 |
| 1092234 | Monocytes [#/volume] in Blood by Flow cytometry (FC) | 0.874 |  |  0 |          0 |
| 3013149 | Basophils+Eosinophils+Monocytes/Leukocytes in Blood by Automated count | 0.872 |  |  0 |          0 |
| 44787047 | Eosinophils [#/volume] in Cord blood | 0.871 |  |  0 |          0 |
| 3002272 | Eosinophils/Leukocytes in Specimen | 0.870 |  |  0 |          0 |
| 3013806 | Calcium [Moles/volume] in Specimen | 0.870 |  |  0 |          0 |
| 3965752 | Albumin [Mass/volume] in Serum or Plasma by Nephelometry | 0.870 |  |  0 |          0 |
| 3024561 | Albumin [Mass/volume] in Serum or Plasma | 0.869 | 20 | 21 |  1,016,464 |
| 3014502 | Neutrophils/Leukocytes in Body fluid | 0.869 | 954 |  0 |          0 |
| 43055368 | Basophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.869 |  |  0 |          0 |
| 3013942 | Lymphocytes/Leukocytes in Synovial fluid by Automated count | 0.869 |  |  0 |          0 |
| 3009581 | Albumin [Mass/volume] in Synovial fluid by Electrophoresis | 0.868 |  |  0 |          0 |
| 3022231 | Eosinophils/Leukocytes in Body fluid by Manual count | 0.866 | 1824 |  0 |          0 |
| 3043948 | Calcium [Moles/volume] in Serum or Plasma --pre XXX challenge | 0.866 |  |  0 |          0 |
| 3008839 | Basophils/Leukocytes in Body fluid by Manual count | 0.866 | 447 |  0 |          0 |
| 3026260 | Monocytes Abnormal [#/volume] in Blood | 0.865 |  |  0 |          0 |
| 3022055 | Basophils/Leukocytes in Specimen | 0.864 |  |  0 |          0 |
| 3049383 | Erythrocyte [DistWidth] in Cord blood | 0.864 |  |  0 |          0 |
| 3001465 | Band form neutrophils [#/volume] in Blood by Automated count | 0.863 |  |  0 |          0 |
| 43055365 | Monocytes/Leukocytes [Pure number fraction] in Blood by Manual count | 0.863 |  |  0 |          0 |
| 3004411 | Monocytes/Leukocytes in Body fluid by Manual count | 0.862 |  |  0 |          0 |
| 3021940 | Eosinophils/Leukocytes in Sputum | 0.861 |  |  0 |          0 |
| 3028895 | Lymphoblasts/Leukocytes in Blood by Manual count | 0.860 |  |  0 |          0 |
| 3032890 | Immature basophils [#/volume] in Blood | 0.860 |  |  0 |          0 |
| 3043107 | Immature eosinophils [#/volume] in Blood by Manual count | 0.860 |  |  0 |          0 |
| 3019402 | Monocytes Abnormal/Leukocytes in Blood by Manual count | 0.859 |  |  0 |          0 |
| 40768824 | Eosinophils [#/volume] in Blood from Fetus by Manual count | 0.858 |  |  0 |          0 |
| 40761510 | Other cells/Leukocytes in Blood by Automated count | 0.858 |  |  0 |          0 |
| 3031805 | Promonocytes [#/volume] in Blood | 0.858 |  |  0 |          0 |
| 3032543 | Calcium [Moles/volume] in Venous blood | 0.857 |  |  0 |          0 |
| 3004064 | Calcium [Moles/volume] corrected for total protein in Serum or Plasma | 0.857 |  |  0 |          0 |
| 43055364 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.857 |  |  0 |          0 |
| 3034226 | Lambda lymphocytes/Lymphocytes in Blood | 0.857 |  |  0 |          0 |
| 3038720 | Eosinophils [#/volume] in Body fluid by Manual count | 0.855 |  |  0 |          0 |
| 3020059 | Calcium [Moles/volume] corrected for albumin in Serum or Plasma | 0.855 | 237 | 17 |    250,713 |
| 3015233 | Abnormal lymphocytes/Leukocytes in Blood | 0.855 |  |  0 |          0 |
| 3037520 | Pronormoblasts [#/volume] in Blood | 0.854 |  |  0 |          0 |
| 3032929 | Immature eosinophils/Leukocytes in Blood | 0.853 |  |  0 |          0 |
| 3007357 | Lymphoma cells/Leukocytes in Blood | 0.852 |  |  0 |          0 |
| 3014528 | Neutrophils [#/volume] in Pleural fluid by Automated count | 0.851 |  |  0 |          0 |
| 3035768 | Promonocytes/Leukocytes in Blood | 0.850 |  |  0 |          0 |
| 3046299 | Protein.monoclonal [Mass/volume] in Serum or Plasma by Electrophoresis | 0.849 | 482 |  1 |      1,578 |
| 3028079 | Lymphocytes/Leukocytes in Body fluid | 0.849 | 370 |  0 |          0 |
| 3020688 | Eosinophils/Leukocytes in Sputum by Manual count | 0.849 |  |  0 |          0 |
| 3019897 | Erythrocyte [DistWidth] in Blood by Automated count | 0.847 | 24 | 11 |     16,931 |
| 3041717 | Basophils [#/volume] in Body fluid by Manual count | 0.846 |  |  0 |          0 |
| 3030902 | Basophils [#/volume] in Pleural fluid | 0.846 |  |  0 |          0 |
| 40768825 | Basophils [#/volume] in Blood from Fetus by Manual count | 0.845 |  |  0 |          0 |
| 3021056 | Basophils/Leukocytes in Sputum | 0.842 |  |  0 |          0 |
| 3017057 | Lymphocytes+Monocytes/Leukocytes in Blood | 0.840 |  |  0 |          0 |
| 3031793 | Immature monocytes/Leukocytes in Blood | 0.838 |  |  0 |          0 |
| 3032072 | Eosinophils [#/volume] in Pleural fluid | 0.836 |  |  0 |          0 |
| 3005377 | Eosinophils/Leukocytes in Stool | 0.836 |  |  0 |          0 |
| 3026844 | Monocytes+Macrophages/Leukocytes in Specimen by Manual count | 0.836 |  |  0 |          0 |
| 3026514 | Neutrophils/Leukocytes in Sputum | 0.832 |  |  0 |          0 |
| 3027359 | Monocytes/Leukocytes in Urine | 0.831 |  |  0 |          0 |
| 3017354 | Segmented neutrophils/Leukocytes in Blood | 0.828 |  |  6 |     15,889 |
| 3964927 | Monocytes/Leukocytes in Blood by Flow cytometry (FC) | 0.823 |  |  0 |          0 |
| 1091949 | Eosinophils/Leukocytes in Urine sediment | 0.823 |  |  0 |          0 |
| 3000121 | Eosinophils/Leukocytes in Bronchial specimen | 0.820 |  |  0 |          0 |
| 40759046 | IgM [Mass/volume] in Serum by Electrophoresis | 0.820 |  |  0 |          0 |
| 3031745 | Lymphocytes Plasmacytoid/Leukocytes in Blood | 0.820 |  |  0 |          0 |
| 3013498 | Variant lymphocytes/Leukocytes in Blood | 0.818 | 817 |  0 |          0 |
| 44787105 | Basophils/Leukocytes in Blood from Fetus | 0.815 |  |  0 |          0 |
| 3010557 | Basophils+Eosinophils+Monocytes/Leukocytes in Blood | 0.815 |  |  0 |          0 |
| 3001490 | Nucleated erythrocytes [#/volume] in Blood | 0.811 |  |  0 |          0 |
| 3006867 | Basophils/Leukocytes in Nose | 0.811 |  |  0 |          0 |
| 3013166 | Neutrophils/Leukocytes in Synovial fluid | 0.810 |  |  3 |      1,674 |
| 3042527 | Neutrophils.immature/Leukocytes in Blood | 0.804 |  |  0 |          0 |
| 3045398 | Protein.monoclonal [Units/volume] in Serum or Plasma by Electrophoresis | 0.803 |  |  0 |          0 |
| 3046588 | Normoblasts/100 blasts in Blood | 0.803 |  |  0 |          0 |
| 3040005 | Erythroid cells [#/volume] in Blood or Marrow | 0.802 |  |  0 |          0 |
| 3029160 | Normoblasts/100 leukocytes in Blood | 0.801 |  |  0 |          0 |
| 3024507 | Metamyelocytes [#/volume] in Blood | 0.798 |  |  0 |          0 |
| 3046859 | Protein.monoclonal/Protein.total in Serum or Plasma by Electrophoresis | 0.786 | 1980 |  0 |          0 |
| 3039818 | Protein.monoclonal [Mass/volume] in Urine by Electrophoresis | 0.771 |  |  0 |          0 |
| 3029379 | Protein.monoclonal band 4 [Mass/volume] in Serum or Plasma by Electrophoresis | 0.769 |  |  3 |     27,037 |
| 3035797 | Protein.monoclonal band 2 [Mass/volume] in Serum or Plasma by Electrophoresis | 0.767 |  |  3 |     29,394 |
| 40765008 | Erythrocyte [DistWidth] in Blood from Fetus by Automated count | 0.759 |  |  0 |          0 |
| 3001289 | Erythrocyte mean corpuscular diameter [Length] | 0.708 |  |  0 |          0 |
| 3012764 | Erythrocyte [Morphology] in Blood | 0.700 | 132 |  0 |          0 |
| 3022525 | Erythrocyte size [Morphology] in Blood | 0.666 |  |  0 |          0 |
| 3002888 | Erythrocyte distribution width [Entitic volume] | 0.658 |  |  0 |          0 |
| 3026361 | Erythrocytes [#/volume] in Blood | 0.651 |  | 14 | 11,175,264 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1950 | b-erybla,osatutkimus(19978b-erybla) | e9/l | 1575 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  | Normoblasts [#/volume] in Blood | FALSE |
| 1951 | b-erybla,osatutkimus(b-erybla) | e9/l | 3732 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  | Normoblasts [#/volume] in Blood | FALSE |
| 1952 | b-erybla,osatutkimus(b-erybla) |  | 8 | 75 |  |  | Blood |  | Normoblasts [#/volume] in Blood | FALSE |
| 1953 | b-neut,osatutkimus(689b-neut) | e9/l | 114 | 0 | [2.36, 2.69, 3.03, 3.4, 3.69, 4.15, 4.59, 5.12, 5.88] |  | Blood |  | Neutrophils [#/volume] in Blood by Automated count | FALSE |
| 1954 | basofiilit,absol.arvot,osatutkimus(40b-baso) | e9/l | 114 | 0 | [0.02, 0.03, 0.03, 0.04, 0.04, 0.05, 0.06, 0.06, 0.08] |  |  |  | Basophils [#/volume] in Blood | FALSE |
| 1955 | basofiilit,konediffi(),osatutk.b-diffi | % | 1040 | 0 | [0.2, 0.35, 0.48, 0.57, 0.68, 0.78, 0.9, 1.09, 1.35] |  |  |  | Basophils/Leukocytes in Blood by Automated count | FALSE |
| 1956 | basofiilit,osatutkimus(692l-baso) | % | 128 | 0 | [0, 0, 0.88, 1, 1, 1, 1, 1, 1] |  |  |  | Basophils/Leukocytes in Blood | FALSE |
| 1957 | e-rdw,osatutkimus(19976e-rdw) | % | 1577 | 0 | [12, 12.98, 13, 13, 13, 13, 13.6, 14, 14.04] |  | Erythrocyte |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1958 | e-rdw,osatutkimus(e-rdw) | % | 3731 | 0 | [12, 12.05, 13, 13, 13, 13, 13, 14, 14.04] |  | Erythrocyte |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1959 | e-rdw,osatutkimus(e-rdw) |  | 8 | 100 |  |  | Erythrocyte |  | Erythrocyte [DistWidth] in Red Blood Cells | FALSE |
| 1960 | eosinofiilit,absol.arvot,osatutkimus(39b-eos) | e9/l | 114 | 0 | [0.06, 0.09, 0.12, 0.16, 0.18, 0.2, 0.23, 0.28, 0.33] |  |  |  | Eosinophils [#/volume] in Blood | FALSE |
| 1961 | eosinofiilit,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [0.08, 1.13, 1.71, 2.33, 2.85, 3.43, 4.13, 5.02, 6.83] |  |  |  | Eosinophils/Leukocytes in Blood by Automated count | FALSE |
| 1962 | eosinofiilit,osatutkimus(690l-eos) | % | 114 | 0 | [1, 1.43, 2, 2, 3, 3, 3.11, 4, 5] |  |  |  | Eosinophils/Leukocytes in Blood | FALSE |
| 1963 | eosinofiilitabs,konediffi,osatutk.b-diffi | e9/l | 1041 | 0 | [0.01, 0.07, 0.1, 0.14, 0.17, 0.22, 0.27, 0.33, 0.46] |  |  |  | Eosinophils [#/volume] in Blood by Automated count | FALSE |
| 1964 | kalsium,osatutkimus(p-ca) | mmol/l | 167 | 0 | [2.26, 2.3, 2.32, 2.34, 2.37, 2.38, 2.41, 2.43, 2.47] |  |  |  | Calcium [Moles/volume] in Serum or Plasma | FALSE |
| 1965 | l-neut,osatutkimus(688l-neut) | % | 114 | 0 | [46.1, 51, 53.29, 55, 56.87, 59, 62, 66.13, 71.3] |  | Leukocyte |  | Neutrophils/Leukocytes in Blood | FALSE |
| 1966 | lymfosyytit,absol.arvot,osatutkimus(43b-lymf) | e9/l | 114 | 0 | [1.2, 1.42, 1.67, 1.84, 1.94, 2.02, 2.22, 2.46, 2.71] |  |  |  | Lymphocytes [#/volume] in Blood | FALSE |
| 1967 | lymfosyytit,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [14.77, 18.39, 21, 24.27, 27.4, 30.54, 33.61, 37.23, 41.49] |  |  |  | Lymphocytes/Leukocytes in Blood by Automated count | FALSE |
| 1968 | lymfosyytit,osatutkimus(46l-lymf) | % | 114 | 0 | [17.98, 23.4, 26.71, 28, 31, 32.84, 34.76, 36, 40.42] |  |  |  | Lymphocytes/Leukocytes in Blood | FALSE |
| 1969 | monosyytit,absol.arvot,osatutkimus(42b-monos) | e9/l | 114 | 0 | [0.36, 0.42, 0.44, 0.49, 0.53, 0.58, 0.62, 0.67, 0.77] |  |  |  | Monocytes [#/volume] in Blood | FALSE |
| 1970 | monosyytit,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [6.01, 6.87, 7.49, 8.19, 8.74, 9.45, 10.43, 11.69, 13.27] |  |  |  | Monocytes/Leukocytes in Blood by Automated count | FALSE |
| 1971 | monosyytit,osatutkimus(693l-monos) | % | 114 | 0 | [6, 6.9, 7, 8, 8, 9, 9, 10, 11] |  |  |  | Monocytes/Leukocytes in Blood | FALSE |
| 1972 | neutrofiiliset,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [43.33, 48.08, 51.94, 55.59, 58.77, 61.59, 65.14, 69.9, 74.47] |  |  |  | Neutrophils/Leukocytes in Blood by Automated count | FALSE |
| 1973 | neutrofiilitabs,konediffi,osatutk.b-diffi | e9/l | 1041 | 0 | [1.86, 2.39, 2.82, 3.25, 3.63, 4.11, 4.7, 5.54, 6.96] |  |  |  | Neutrophils [#/volume] in Blood by Automated count | FALSE |
| 1974 | s-albumiini,osatutkimuss-prot-fr | g/l | 109 | 0 | [31.62, 35.39, 37.28, 38.52, 39.57, 40.75, 41.75, 43.12, 44] |  | Serum | Fractions | Albumin [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1975 | s-alfa-1-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [2.3, 2.4, 2.54, 2.7, 2.89, 3.08, 3.35, 3.6, 4.2] |  | Serum | Fractions | Alpha 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1976 | s-alfa-2-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [5.63, 6, 6.24, 6.66, 7.47, 7.93, 8.35, 9.06, 9.9] |  | Serum | Fractions | Alpha 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1977 | s-beta-1-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [3.5, 3.7, 3.85, 4.04, 4.14, 4.31, 4.42, 4.7, 4.9] |  | Serum | Fractions | Beta 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1978 | s-beta-2-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [2.8, 3.09, 3.44, 3.86, 4.01, 4.31, 4.58, 4.8, 5.27] |  | Serum | Fractions | Beta 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1979 | s-gamma-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [6.61, 7.97, 8.64, 9.16, 9.73, 10.36, 11, 11.66, 12.99] |  | Serum | Fractions | Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1980 | s-m-komponentti-1(valetietues-prot-fr) | g/l | 135 | 0 | [0, 0, 0, 1.3, 2.13, 3.83, 5.42, 7.84, 12.97] |  | Serum |  | M-protein [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1981 | s-m-komponentti-1(valetietues-prot-fr) |  | 93 | 100 |  |  | Serum |  | M-protein [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1982 | s-m-komponentti-2(valetietues-prot-fr) | g/l | 82 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 1] |  | Serum |  | M-protein [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1983 | s-m-komponentti-2(valetietues-prot-fr) |  | 133 | 100 |  |  | Serum |  | M-protein [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |
| 1984 | s-m-komponentti-3(valetietues-prot-fr) |  | 131 | 100 |  |  | Serum |  | M-protein [Mass/volume] in Serum or Plasma by Electrophoresis | FALSE |

