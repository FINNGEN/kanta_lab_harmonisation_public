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
Here is group 110.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3019724 | CD34 cells [#/volume] in Blood | 0.983 |  |  0 |         0 |
| 3000060 | B lymphocytes [#/volume] in Blood | 0.969 |  |  3 |     3,643 |
| 3019198 | Lymphocytes [#/volume] in Blood | 0.915 | 70 | 38 | 1,557,180 |
| 3023256 | CD34 cells/cells in Blood | 0.910 |  |  0 |         0 |
| 44816730 | CD34 cells [#/volume] in Specimen | 0.907 |  |  0 |         0 |
| 3045389 | CD34 cells [#/volume] in Blood from Blood product unit | 0.906 |  |  0 |         0 |
| 40757349 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Blood | 0.899 | 362 |  3 |     4,016 |
| 40762032 | CD34 cells [#/volume] in Body fluid | 0.894 |  |  0 |         0 |
| 1469655 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bronchoalveolar lavage by Flow cytometry (FC) | 0.893 |  |  0 |         0 |
| 3037816 | CD4+CD8+ cells/cells in Blood | 0.891 |  |  0 |         0 |
| 3016901 | Lambda lymphocytes [#/volume] in Blood | 0.891 |  |  0 |         0 |
| 3005533 | CD34+HLA-DR+ cells/Cells in Blood | 0.882 |  |  0 |         0 |
| 3001405 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood | 0.867 | 441 |  7 |     8,289 |
| 3024672 | CD33 cells [#/volume] in Blood | 0.863 |  |  0 |         0 |
| 3052708 | Transferrin.carbohydrate deficient/Transferrin.total in Serum or Plasma | 0.860 |  |  0 |         0 |
| 3034238 | Transferrin.carbohydrate deficient.disialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.860 |  |  0 |         0 |
| 1175635 | Transferrin.carbohydrate deficient.trisialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.857 |  |  0 |         0 |
| 3045450 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bronchial specimen | 0.856 |  |  0 |         0 |
| 3034226 | Lambda lymphocytes/Lymphocytes in Blood | 0.855 |  |  0 |         0 |
| 3025271 | CD3-CD16+CD56+ (Natural killer) cells [#/volume] in Blood | 0.853 |  |  4 |     8,969 |
| 3002030 | Lymphocytes/Leukocytes in Blood | 0.852 | 45 | 65 | 1,465,459 |
| 3047764 | CD33+CD34+ cells/cells in Blood | 0.851 |  |  0 |         0 |
| 3031240 | B lymphocytes [#/volume] in Bone marrow | 0.849 |  |  0 |         0 |
| 3031729 | Lymphocytes Immunoblastic [#/volume] in Blood | 0.848 |  |  0 |         0 |
| 3028167 | CD3+CD4+ (T4 helper) cells [#/volume] in Blood | 0.848 | 515 |  4 |     8,143 |
| 3036413 | Transferrin.carbohydrate deficient.asialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.845 |  |  0 |         0 |
| 3011412 | CD3 cells [#/volume] in Blood | 0.845 | 427 |  8 |    11,121 |
| 3025059 | Transferrin.carbohydrate deficient [Mass/volume] in Serum or Plasma | 0.844 |  |  2 |       461 |
| 3043266 | Transferrin.carbohydrate deficient.asialo/Transferrin.carbohydrate deficient.disialo [Mass Ratio] in Serum or Plasma | 0.841 |  |  0 |         0 |
| 3046399 | Transferrin.carbohydrate deficient.monosialo/Transferrin.carbohydrate deficient.disialo [Mass Ratio] in Serum or Plasma | 0.841 |  |  0 |         0 |
| 40760533 | CD34 cells/cells in Body fluid | 0.841 |  |  0 |         0 |
| 3001362 | Plasma cells [#/volume] in Blood | 0.840 |  |  0 |         0 |
| 3030044 | CD34 cells/cells in Blood from Blood product unit | 0.840 |  |  0 |         0 |
| 3011211 | CD41 cells [#/volume] in Blood | 0.840 |  |  0 |         0 |
| 36032071 | CD34 cells [#] in Blood product unit | 0.839 |  |  0 |         0 |
| 3023834 | CD24 cells [#/volume] in Blood | 0.839 |  |  0 |         0 |
| 3032946 | Lymphoblasts [#/volume] in Blood | 0.839 |  |  0 |         0 |
| 3036304 | CD45 (Lymphs) cells [#/volume] in Blood | 0.837 | 2006 |  0 |         0 |
| 3003031 | Transferrin.carbohydrate deficient.disialo/Transferrin.total in Serum or Plasma | 0.837 |  |  9 |   108,678 |
| 40760512 | CD34 cells/cells in Bone marrow | 0.837 |  |  1 |        52 |
| 3019342 | CD16-CD34+ cells/cells in Blood | 0.836 |  |  0 |         0 |
| 3003137 | Variant lymphocytes [#/volume] in Blood | 0.835 |  |  0 |         0 |
| 3032360 | Lymphocytes+Monocytes [#/volume] in Blood | 0.835 |  |  0 |         0 |
| 3003467 | Lymphocytes [#/volume] in Body fluid | 0.830 |  |  0 |         0 |
| 40762014 | CD4+CD45RO+ cells/CD3+CD4+ (T4 helper) cells [# Ratio] in Blood | 0.830 |  |  0 |         0 |
| 3034154 | Transferrin.carbohydrate deficient.trisialo/Transferrin.total in Serum or Plasma | 0.829 |  |  0 |         0 |
| 3041326 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Tissue | 0.829 |  |  0 |         0 |
| 37020917 | Transferrin.carbohydrate deficient.disialo/Transferrin.total standardized per IFCC-RMP for CDT in Serum or Plasma | 0.828 |  |  0 |         0 |
| 3001552 | Prolymphocytes [#/volume] in Blood | 0.827 |  |  0 |         0 |
| 3033172 | Lymphocytes Plasmacytoid [#/volume] in Blood | 0.825 |  |  0 |         0 |
| 3014859 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Body fluid | 0.825 |  |  0 |         0 |
| 3026757 | CD56 cells [#/volume] in Blood | 0.818 |  |  0 |         0 |
| 21492329 | Cells.CD3+CD4+CD8+ (Double positive)/cells in Blood | 0.817 |  |  0 |         0 |
| 3020358 | CD16+CD56+ cells [#/volume] in Blood | 0.816 | 1410 |  0 |         0 |
| 3025183 | CD4+CD25+ cells [#/volume] in Blood | 0.815 |  |  0 |         0 |
| 40760513 | CD4+CD8+ cells/cells in Body fluid | 0.814 |  |  0 |         0 |
| 21493668 | CD4-CD8-/Cells.CD3+TCR alpha beta+ in Blood | 0.813 |  |  0 |         0 |
| 3042388 | CD3+CD4-CD8-CD45+ cells/cells in Blood | 0.809 |  |  0 |         0 |
| 3045467 | Natural killer cell function [Units/volume] in Blood | 0.809 |  |  0 |         0 |
| 3039219 | CD3-CD56+ cells [#/volume] in Blood | 0.809 |  |  0 |         0 |
| 3041141 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Tissue | 0.808 |  |  0 |         0 |
| 3019082 | CD3+CD56+ cells [#/volume] in Blood | 0.806 |  |  0 |         0 |
| 3026340 | CD5+CD8+ cells/cells in Blood | 0.805 |  |  0 |         0 |
| 36660486 | Leukocytes [#/volume] in Stem cell product | 0.804 |  |  0 |         0 |
| 3012302 | CD16C+CD56+ cells [#/volume] in Blood | 0.803 |  |  0 |         0 |
| 3020073 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Specimen | 0.803 |  |  2 |     2,748 |
| 21492330 | Cells.CD3+CD4+CD8+ (Double positive) [#/volume] in Blood | 0.802 |  |  0 |         0 |
| 3015209 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bone marrow | 0.802 |  |  0 |         0 |
| 3032842 | CD3+CD16+CD56+ cells [#/volume] in Blood | 0.800 |  |  0 |         0 |
| 3026696 | CD34 cells/cells in Specimen | 0.797 |  |  0 |         0 |
| 3030679 | TCR alpha beta cells [#/volume] in Blood | 0.795 |  |  0 |         0 |
| 3007449 | CD3+CD8+ (T8 suppressor) cells/cells in Blood | 0.794 | 397 |  3 |     4,359 |
| 3044810 | HLA-DR+ cells [#/volume] in Blood | 0.793 |  |  0 |         0 |
| 40763402 | Viable CD34 cells [#/volume] in Body fluid | 0.793 |  |  0 |         0 |
| 3026022 | CD4+HLA-DR+ cells [#/volume] in Blood | 0.793 |  |  0 |         0 |
| 1469794 | CD3+CD8+ (T8 suppressor) cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.793 |  |  0 |         0 |
| 3038211 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Specimen | 0.791 |  |  0 |         0 |
| 3013529 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Bone marrow | 0.791 |  |  0 |         0 |
| 1091820 | CD3+HLA-DR+ cells/Lymphocytes in Bronchoalveolar lavage | 0.791 |  |  0 |         0 |
| 3036099 | CD158 cells [#/volume] in Blood | 0.790 |  |  0 |         0 |
| 3013936 | CD3+HLA-DR+ cells [#/volume] in Blood | 0.788 |  |  0 |         0 |
| 1470025 | CD3+CD4+ (T4 helper) cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.788 |  |  0 |         0 |
| 1175426 | CD3 cells/Lymphocytes in Blood | 0.788 |  |  5 |     8,032 |
| 3010083 | CD3-CD16+CD56+ (Natural killer) cells [#/volume] in Specimen | 0.783 |  |  0 |         0 |
| 1092254 | CD3+CD25+ cells/Lymphocytes in Bronchoalveolar lavage | 0.783 |  |  0 |         0 |
| 3019424 | CD4+CD45+ cells [#/volume] in Blood | 0.782 |  |  0 |         0 |
| 46236971 | CD34 dose in hematopoietic progenitor cell transfusion [#/mass] per recipient body mass | 0.782 |  |  0 |         0 |
| 1092400 | Other cells [#/volume] in Blood | 0.777 |  |  0 |         0 |
| 3032382 | CD3+TCR alpha beta+ cells [#/volume] in Blood | 0.776 |  |  0 |         0 |
| 3006178 | CD8+CD25+ cells [#/volume] in Blood | 0.775 |  |  0 |         0 |
| 3014037 | CD3+CD4+ (T4 helper) cells/cells in Blood | 0.773 | 377 |  3 |     7,337 |
| 36304658 | CD4+CD25-CD127+ cells [#/volume] in Blood | 0.772 |  |  0 |         0 |
| 40766181 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Cerebral spinal fluid | 0.771 |  |  0 |         0 |
| 1469967 | Lymphocytes [#/volume] in Hematopoietic progenitor cells from Blood product unit | 0.769 |  |  0 |         0 |
| 36304873 | CD45RO cells/CD3+CD8+ (T8 suppressor cells) cells in Blood | 0.769 |  |  0 |         0 |
| 21493667 | Viable CD34 cells/CD34 cells in Hematopoietic progenitor cells from Blood product unit | 0.769 |  |  0 |         0 |
| 1616698 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Lower respiratory specimen by Flow cytometry (FC) | 0.767 |  |  0 |         0 |
| 1469804 | Lymphocytes/Cells in Bronchoalveolar lavage | 0.766 |  |  0 |         0 |
| 1260044 | Lambda lymphocytes/Lymphocytes in Bone marrow | 0.763 |  |  0 |         0 |
| 3001669 | CV lymphocytes/Lymphocytes in Blood | 0.761 |  |  0 |         0 |
| 3031759 | Lymphoblasts/Leukocytes in Blood | 0.761 |  |  0 |         0 |
| 1761703 | CD3+CD8+ (T8 suppressor) cells/cells in Blood mononuclear cells | 0.760 |  |  0 |         0 |
| 3034458 | CD4+CD45RA+ cells/CD8 Cells [# Ratio] in Blood | 0.759 |  |  0 |         0 |
| 36660684 | Lymphocytes/Leukocytes in Stem cell product by Manual count | 0.758 |  |  0 |         0 |
| 3017057 | Lymphocytes+Monocytes/Leukocytes in Blood | 0.755 |  |  0 |         0 |
| 3028866 | Leukocytes [#/volume] in Blood Product unit.platelet pheresis by Automated count | 0.753 |  |  0 |         0 |
| 36303448 | CD27+CD62L+ cells/CD3+CD8+ (T8 suppressor cells) cells in Blood | 0.753 |  |  0 |         0 |
| 3001162 | HLE lymphocytes/Lymphocytes in Blood | 0.753 |  |  0 |         0 |
| 3047146 | Leukocytes [#/volume] in Blood from Blood product unit | 0.753 |  |  0 |         0 |
| 3020308 | Activated T cells lymphocytes/Lymphocytes.small in Blood | 0.753 |  |  0 |         0 |
| 1469914 | CD3 cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.752 |  |  0 |         0 |
| 40759893 | Lymphocytes/Leukocytes in Tissue | 0.752 |  |  0 |         0 |
| 1470003 | CD3 cells [#/volume] in Hematopoietic progenitor cells from Blood product unit | 0.751 |  |  0 |         0 |
| 3027831 | CD3-CD16+CD56+ (Natural killer) cells/cells in Blood | 0.751 | 944 |  4 |     7,605 |
| 3007672 | Kappa lymphocytes/Lymphocytes in Blood | 0.750 |  |  0 |         0 |
| 36304769 | CD28+HLA DR+ cells/CD3+CD8+ (T8 suppressor cells) cells in Blood | 0.749 |  |  0 |         0 |
| 3040131 | CD3+CD8+ (T8 suppressor) cells/100 cells in Bronchial specimen | 0.745 |  |  0 |         0 |
| 21493674 | CD27+CD45RA+ cells/CD3+CD8+ (T8 suppressor cells) cells in Blood | 0.744 |  |  0 |         0 |
| 21493670 | CD27- cells/CD3+CD8+ (T8 suppressor cells) cells in Blood | 0.743 |  |  0 |         0 |
| 3020318 | Prolymphocytes/Leukocytes in Blood | 0.743 |  |  0 |         0 |
| 3005460 | CD56 cells/cells in Blood | 0.742 |  |  0 |         0 |
| 21493672 | CD27+CD45RA- cells/CD3+CD8+ (T8 suppressor cells) cells in Blood | 0.741 |  |  0 |         0 |
| 3031732 | Lymphocytes Immunoblastic/Leukocytes in Blood | 0.741 |  |  0 |         0 |
| 3030157 | CD56+CD57+ cells/cells in Blood | 0.741 |  |  0 |         0 |
| 3015455 | CD16+CD56+ cells/cells in Blood | 0.739 | 1406 |  0 |         0 |
| 36305855 | CD28+HLA DR+ cells/CD3+CD4+ (T4 helper) cells in Blood | 0.739 |  |  0 |         0 |
| 36304463 | CD27-CD45RO+CD62L-CCR7- cells/CD3+CD8+ (T8 suppressor cells) cells in Blood | 0.736 |  |  0 |         0 |
| 3000611 | Lambda lymphocytes/Lymphocytes in Specimen | 0.736 |  |  0 |         0 |
| 1761320 | CD3+CD4+ (T4 helper) cells/cells in Blood mononuclear cells | 0.733 |  |  0 |         0 |
| 3003466 | CD3+CD56+ cells/cells in Blood | 0.732 |  |  0 |         0 |
| 3007357 | Lymphoma cells/Leukocytes in Blood | 0.731 |  |  0 |         0 |
| 40758220 | CD3-CD56+ cells/cells in Blood | 0.730 |  |  0 |         0 |
| 1091665 | Lymphocytes [#/volume] in Specimen | 0.730 |  |  0 |         0 |
| 44787044 | Lymphocytes [#/volume] in Cord blood | 0.725 |  |  0 |         0 |
| 3022533 | CD3 cells/cells in Blood | 0.719 | 383 |  0 |         0 |
| 36032412 | CD3 cells [#] in Blood product unit | 0.716 |  |  0 |         0 |
| 3036479 | CD3+CD4+ (T4 helper) cells [#/volume] in Bone marrow | 0.706 |  |  0 |         0 |
| 3001694 | CD3+CD4+ (T4 helper) cells [#/volume] in Specimen | 0.706 | 602 |  0 |         0 |
| 3035438 | CD3+CD25+ cells [#/volume] in Bone marrow | 0.688 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1469 | b-b-cd19 | e6/l | 913 | 0 | [10.41, 31.05, 55.36, 87.14, 120.42, 155.29, 201.58, 263.7, 407.08] |  | Blood |  | B-lymphocytes [#/volume] in Blood | FALSE |
| 1470 | b-b-cd19 | e9/l | 3083 | 0 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.29, 0.48] |  | Blood |  | B-lymphocytes [#/volume] in Blood | FALSE |
| 1471 | b-b-cd19 |  | 569 | 89.28 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.31, 0.47] |  | Blood |  | B-lymphocytes [#/volume] in Blood | FALSE |
| 1472 | b-cd16/56 | e6/l | 12 | 0 |  |  | Blood |  | NK cells [#/volume] in Blood | FALSE |
| 1473 | b-cd16/56 | e9/l | 2606 | 0.65 | [0.06, 0.09, 0.12, 0.15, 0.18, 0.22, 0.26, 0.33, 0.44] |  | Blood |  | NK cells [#/volume] in Blood | FALSE |
| 1474 | b-cd16/56 |  | 108 | 84.26 |  |  | Blood |  | NK cells [#/volume] in Blood | FALSE |
| 1475 | b-cd16/cd56 | e9/l | 263 | 0 | [0.09, 0.12, 0.15, 0.17, 0.21, 0.24, 0.3, 0.36, 0.44] |  | Blood |  | NK cells [#/volume] in Blood | FALSE |
| 1476 | b-cd16/cd56 |  | 15 | 100 |  |  | Blood |  | NK cells [#/volume] in Blood | FALSE |
| 1477 | b-cd19 | e6/l | 3891 | 0 | [0, 1.97, 16.17, 41.05, 70.27, 108.04, 158.42, 221.57, 336.97] |  | Blood |  | B-lymphocytes [#/volume] in Blood | FALSE |
| 1478 | b-cd19 | e9/l | 2870 | 0.59 | [0, 0, 0.01, 0.03, 0.06, 0.09, 0.14, 0.19, 0.29] |  | Blood |  | B-lymphocytes [#/volume] in Blood | FALSE |
| 1479 | b-cd19 |  | 175 | 66.29 |  |  | Blood |  | B-lymphocytes [#/volume] in Blood | FALSE |
| 1480 | b-cd3 | e6/l | 3892 | 0 |  |  | Blood |  | T-lymphocytes [#/volume] in Blood | FALSE |
| 1481 | b-cd3 | e9/l | 2868 | 0.59 |  |  | Blood |  | T-lymphocytes [#/volume] in Blood | FALSE |
| 1482 | b-cd3 |  | 204 | 71.57 |  |  | Blood |  | T-lymphocytes [#/volume] in Blood | FALSE |
| 1483 | b-cd34 | e6/l | 193 | 0 | [5.27, 13.75, 20.31, 28.86, 37.69, 50.47, 63.07, 93.98, 156.93] |  | Blood |  | CD34+ cells [#/volume] in Blood | FALSE |
| 1484 | b-cd34 |  | 27 | 29.63 |  |  | Blood |  | CD34+ cells [#/volume] in Blood | FALSE |
| 1485 | b-cd4 | e6/l | 3893 | 0 | [134.07, 213.38, 284.14, 381.8, 505.45, 647.7, 819.98, 1038.04, 1335.05] |  | Blood |  | T-helper cells [#/volume] in Blood | FALSE |
| 1486 | b-cd4 | e9/l | 2870 | 0.59 | [0.14, 0.2, 0.25, 0.32, 0.4, 0.51, 0.63, 0.8, 1.07] |  | Blood |  | T-helper cells [#/volume] in Blood | FALSE |
| 1487 | b-cd4 |  | 172 | 66.28 |  |  | Blood |  | T-helper cells [#/volume] in Blood | FALSE |
| 1488 | b-cd8 | e6/l | 3892 | 0 | [117.75, 200.41, 277.17, 351.98, 433.16, 541.85, 672.5, 850.74, 1214.03] |  | Blood |  | T-suppressor cells [#/volume] in Blood | FALSE |
| 1489 | b-cd8 | e9/l | 2870 | 0.59 | [0.11, 0.16, 0.23, 0.29, 0.36, 0.46, 0.57, 0.73, 1] |  | Blood |  | T-suppressor cells [#/volume] in Blood | FALSE |
| 1490 | b-cd8 |  | 172 | 66.28 |  |  | Blood |  | T-suppressor cells [#/volume] in Blood | FALSE |
| 1491 | b-lcd34 | e6/l | 251 | 0 | [3, 7.11, 11.11, 14.14, 17.55, 23.82, 31.86, 44, 64.2] | B -Leukosyytit, CD34 alaluokka | Blood |  | CD34+ cells [#/volume] in Blood | FALSE |
| 1492 | b-lcd34 | e9/l | 475 | 0 | [0, 0.01, 0.02, 0.03, 0.03, 0.04, 0.06, 0.09, 0.13] | B -Leukosyytit, CD34 alaluokka | Blood |  | CD34+ cells [#/volume] in Blood | FALSE |
| 1493 | b-lcd34 |  | 66 | 100 |  | B -Leukosyytit, CD34 alaluokka | Blood |  | CD34+ cells [#/volume] in Blood | FALSE |
| 1494 | b-lycd4 |  | 496 | 100 |  | B -Lymfosyytti CD4-alaluokka | Blood |  | T-helper cells [#/volume] in Blood | FALSE |
| 1495 | b-t-cd3 | e6/l | 1174 | 0 |  |  | Blood |  | T-lymphocytes [#/volume] in Blood | FALSE |
| 1496 | b-t-cd3 | e9/l | 2692 | 0 |  |  | Blood |  | T-lymphocytes [#/volume] in Blood | FALSE |
| 1497 | b-t-cd3 |  | 304 | 81.91 |  |  | Blood |  | T-lymphocytes [#/volume] in Blood | FALSE |
| 1498 | b-t-cd4 | e6/l | 1609 | 0 | [168.06, 247.56, 335.09, 433.05, 551.26, 672.04, 816.88, 957.34, 1254.62] |  | Blood |  | T-helper cells [#/volume] in Blood | FALSE |
| 1499 | b-t-cd4 | e9/l | 6105 | 0 | [0.16, 0.25, 0.34, 0.43, 0.52, 0.64, 0.79, 0.96, 1.28] |  | Blood |  | T-helper cells [#/volume] in Blood | FALSE |
| 1500 | b-t-cd4 |  | 475 | 69.89 | [0.2, 0.26, 0.34, 0.42, 0.55, 0.68, 0.8, 0.95, 1.29] |  | Blood |  | T-helper cells [#/volume] in Blood | FALSE |
| 1501 | b-t-cd8 | e6/l | 1174 | 0 | [141.94, 210.82, 289.62, 366.11, 450.98, 530.13, 639.55, 796.16, 1179.47] |  | Blood |  | T-suppressor cells [#/volume] in Blood | FALSE |
| 1502 | b-t-cd8 | e9/l | 2753 | 0 | [0.14, 0.21, 0.27, 0.35, 0.43, 0.52, 0.65, 0.83, 1.1] |  | Blood |  | T-suppressor cells [#/volume] in Blood | FALSE |
| 1503 | b-t-cd8 |  | 311 | 79.42 |  |  | Blood |  | T-suppressor cells [#/volume] in Blood | FALSE |
| 1504 | bl-cd4/cd8 | form | 42 | 100 |  |  | Bronchoalveolar lavage |  | T-helper cells/T-suppressor cells [# Ratio] in Bronchoalveolar lavage | FALSE |
| 1505 | bl-cd4/cd8 |  | 91 | 100 |  |  | Bronchoalveolar lavage |  | T-helper cells/T-suppressor cells [# Ratio] in Bronchoalveolar lavage | FALSE |
| 1506 | cd4/cd8 |  | 3940 | 0.23 | [0.29, 0.47, 0.68, 0.91, 1.2, 1.57, 1.94, 2.45, 3.26] |  |  |  | T-helper cells/T-suppressor cells [# Ratio] in Blood | FALSE |
| 1507 | l-cd34 | % | 481 | 0 | [0.05, 0.08, 0.1, 0.13, 0.16, 0.2, 0.25, 0.32, 0.61] |  | Leukocyte |  | CD34+ cells/Leukocytes in Blood | FALSE |
| 1508 | l-cd34 |  | 41 | 100 |  |  | Leukocyte |  | CD34+ cells/Leukocytes in Blood | FALSE |
| 1509 | la-cd34 | e6/kg | 156 | 0 | [0.6, 0.9, 1.18, 1.41, 1.69, 2.1, 2.53, 3.4, 4.94] |  |  |  | CD34+ cells [#/mass] in Leukapheresis product | FALSE |
| 1510 | la-cd34 | e9/l | 393 | 0 | [0.41, 0.56, 0.72, 0.84, 1.03, 1.27, 1.77, 2.36, 3.2] |  |  |  | CD34+ cells [#/volume] in Leukapheresis product | FALSE |
| 1511 | la-cd34-ks |  | 395 | 100 |  |  |  |  |  | FALSE |
| 1512 | la-cd34-os | % | 393 | 0 | [0.22, 0.3, 0.39, 0.49, 0.59, 0.69, 0.84, 1.12, 1.67] |  |  |  | CD34+ cells/Total nucleated cells in Leukapheresis product | FALSE |
| 1513 | la-t-cd3 | e9/l | 149 | 0 |  |  |  |  | T-lymphocytes [#/volume] in Leukapheresis product | FALSE |
| 1514 | la-t-cd3 |  | 6 | 16.67 |  |  |  |  | T-lymphocytes [#/volume] in Leukapheresis product | FALSE |
| 1515 | la-t-cd4 | e9/l | 149 | 0 |  |  |  |  | T-helper cells [#/volume] in Leukapheresis product | FALSE |
| 1516 | la-t-cd4 |  | 6 | 16.67 |  |  |  |  | T-helper cells [#/volume] in Leukapheresis product | FALSE |
| 1517 | la-t-cd8 | e9/l | 149 | 0 |  |  |  |  | T-suppressor cells [#/volume] in Leukapheresis product | FALSE |
| 1518 | la-t-cd8 |  | 6 | 16.67 |  |  |  |  | T-suppressor cells [#/volume] in Leukapheresis product | FALSE |
| 1519 | ly-b-cd19 | % | 1504 | 0 | [0, 0, 0.45, 2.91, 5.54, 7.86, 10.24, 13.34, 18.94] |  | Lymphocyte |  | B-lymphocytes/Lymphocytes in Blood | FALSE |
| 1520 | ly-b-cd19 |  | 950 | 99.05 |  |  | Lymphocyte |  | B-lymphocytes/Lymphocytes in Blood | FALSE |
| 1521 | ly-cd16/56 | % | 3462 | 0.49 | [5.28, 8.01, 10.25, 12.46, 15.08, 18.07, 21.55, 26.37, 33.4] |  | Lymphocyte |  | NK cells/Lymphocytes in Blood | FALSE |
| 1522 | ly-cd16/56 |  | 107 | 86.92 |  |  | Lymphocyte |  | NK cells/Lymphocytes in Blood | FALSE |
| 1523 | ly-cd16/cd56 | % | 262 | 0 | [5.52, 8.16, 10.06, 12.71, 14.93, 17.65, 20.63, 27.5, 36.58] |  | Lymphocyte |  | NK cells/Lymphocytes in Blood | FALSE |
| 1524 | ly-cd16/cd56 |  | 15 | 100 |  |  | Lymphocyte |  | NK cells/Lymphocytes in Blood | FALSE |
| 1525 | ly-cd19 | % | 3462 | 0.49 | [0, 0, 1.17, 3.24, 5.55, 8.08, 10.86, 14.11, 20.27] |  | Lymphocyte |  | B-lymphocytes/Lymphocytes in Blood | FALSE |
| 1526 | ly-cd19 |  | 107 | 85.98 |  |  | Lymphocyte |  | B-lymphocytes/Lymphocytes in Blood | FALSE |
| 1527 | ly-cd19-b | % | 2507 | 0 | [0, 0, 1, 3.95, 7.56, 10.5, 13.61, 17.58, 25.6] |  | Lymphocyte |  | B-lymphocytes/Lymphocytes in Blood | FALSE |
| 1528 | ly-cd19-b |  | 19 | 100 |  |  | Lymphocyte |  | B-lymphocytes/Lymphocytes in Blood | FALSE |
| 1529 | ly-cd3 | % | 3726 | 0.46 | [52.12, 61.25, 67.07, 71.15, 74.98, 78.39, 81.66, 85.36, 89.48] |  | Lymphocyte |  | T-lymphocytes/Lymphocytes in Blood | FALSE |
| 1530 | ly-cd3 |  | 122 | 87.7 |  |  | Lymphocyte |  | T-lymphocytes/Lymphocytes in Blood | FALSE |
| 1531 | ly-cd4 | % | 3726 | 0.46 | [16.32, 22.56, 27.91, 32.59, 37.02, 41.75, 46.47, 51.76, 58.99] |  | Lymphocyte |  | T-helper cells/Lymphocytes in Blood | FALSE |
| 1532 | ly-cd4 |  | 122 | 87.7 |  |  | Lymphocyte |  | T-helper cells/Lymphocytes in Blood | FALSE |
| 1533 | ly-cd4+8+ | % | 41 | 41.46 |  |  | Lymphocyte |  | CD4+CD8+ T-lymphocytes/Lymphocytes in Blood | FALSE |
| 1534 | ly-cd4+8+ |  | 75 | 100 |  |  | Lymphocyte |  | CD4+CD8+ T-lymphocytes/Lymphocytes in Blood | FALSE |
| 1535 | ly-cd4-8- | % | 207 | 8.21 | [7, 8, 8, 8.88, 9.82, 10.9, 12, 14, 16] |  | Lymphocyte |  | CD4-CD8- T-lymphocytes/Lymphocytes in Blood | FALSE |
| 1536 | ly-cd4-8- |  | 77 | 100 |  |  | Lymphocyte |  | CD4-CD8- T-lymphocytes/Lymphocytes in Blood | FALSE |
| 1537 | ly-cd4-t | % | 4576 | 0 | [15.23, 21.8, 27.31, 31.42, 35.47, 39.26, 43.26, 48.23, 54.7] |  | Lymphocyte |  | T-helper cells/Lymphocytes in Blood | FALSE |
| 1538 | ly-cd4-t |  | 170 | 22.94 | [17.53, 21.58, 24.78, 29.15, 33.2, 38.25, 41.67, 47.37, 52.57] |  | Lymphocyte |  | T-helper cells/Lymphocytes in Blood | FALSE |
| 1539 | ly-cd4/cd8 |  | 2752 | 4.18 | [0.37, 0.55, 0.75, 0.96, 1.18, 1.48, 1.83, 2.29, 3.23] | Ly-Auttaja- ja tappajasolujen suhde, immunofenotyypitys | Lymphocyte |  | T-helper cells/T-suppressor cells [# Ratio] in Blood | FALSE |
| 1540 | ly-cd4/cd8suhde |  | 278 | 5.4 | [0.5, 0.76, 1.02, 1.29, 1.66, 1.95, 2.26, 2.73, 3.97] |  | Lymphocyte |  | T-helper cells/T-suppressor cells [# Ratio] in Blood | FALSE |
| 1541 | ly-cd8 | % | 3725 | 0.46 | [14.46, 19.13, 22.75, 26.46, 30.35, 34.98, 40.06, 46.74, 56.02] |  | Lymphocyte |  | T-suppressor cells/Lymphocytes in Blood | FALSE |
| 1542 | ly-cd8 |  | 122 | 87.7 |  |  | Lymphocyte |  | T-suppressor cells/Lymphocytes in Blood | FALSE |
| 1543 | ly-t-cd3 | % | 3926 | 0 | [56.23, 64.92, 70.33, 74.35, 77.57, 80.54, 84.02, 87.72, 92.04] |  | Lymphocyte |  | T-lymphocytes/Lymphocytes in Blood | FALSE |
| 1544 | ly-t-cd3 |  | 264 | 98.48 |  |  | Lymphocyte |  | T-lymphocytes/Lymphocytes in Blood | FALSE |
| 1545 | ly-t-cd4 | % | 2006 | 0 | [18.72, 24.57, 29.84, 34.47, 38.67, 43.22, 47.75, 52.18, 58.04] | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  | T-helper cells/Lymphocytes in Blood | FALSE |
| 1546 | ly-t-cd4 |  | 3875 | 99.92 |  | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  | T-helper cells/Lymphocytes in Blood | FALSE |
| 1547 | ly-t-cd4. | % | 1462 | 0 | [18.57, 26.32, 32.42, 36.77, 41.27, 46.47, 51.47, 56.35, 63.05] |  | Lymphocyte |  | T-helper cells/Lymphocytes in Blood | FALSE |
| 1548 | ly-t-cd4. |  | 36 | 72.22 |  |  | Lymphocyte |  | T-helper cells/Lymphocytes in Blood | FALSE |
| 1549 | ly-t-cd4/8 | ratio | 1816 | 0 | [0.6, 0.8, 0.99, 1.23, 1.56, 1.85, 2.06, 2.47, 3.19] |  | Lymphocyte |  | T-helper cells/T-suppressor cells [# Ratio] in Blood | FALSE |
| 1550 | ly-t-cd4/8 |  | 224 | 100 | [0.48, 0.79, 1.06, 1.31, 1.55, 1.83, 2.13, 2.62, 3.69] |  | Lymphocyte |  | T-helper cells/T-suppressor cells [# Ratio] in Blood | FALSE |
| 1551 | ly-t-cd8 | % | 2895 | 0 | [14.95, 19.45, 23.24, 27.01, 30.29, 33.79, 38.05, 43.59, 52.29] | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  | T-suppressor cells/Lymphocytes in Blood | FALSE |
| 1552 | ly-t-cd8 |  | 245 | 99.59 |  | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  | T-suppressor cells/Lymphocytes in Blood | FALSE |
| 1553 | ly-tcd4/8. |  | 2179 | 0.83 | [0.48, 0.75, 1, 1.21, 1.42, 1.69, 2, 2.51, 3.27] |  | Lymphocyte |  | T-helper cells/T-suppressor cells [# Ratio] in Blood | FALSE |
| 1554 | ly-tt-cd8 | % | 1219 | 0 | [13.33, 17.86, 21.01, 24.35, 28, 31.32, 36.22, 42.56, 52.88] |  | Lymphocyte |  | T-suppressor cells/Lymphocytes in Blood | FALSE |
| 1555 | ly-tt-cd8 |  | 5 | 40 |  |  | Lymphocyte |  | T-suppressor cells/Lymphocytes in Blood | FALSE |
| 1556 | s-gt-cdt | % | 13 | 0 |  |  | Serum |  | Carbohydrate deficient transferrin/Transferrin.total [Mass Ratio] in Serum or Plasma | FALSE |
| 1557 | s-gt-cdt |  | 2807 | 3.35 | [2.6, 2.87, 3.04, 3.25, 3.47, 3.7, 3.96, 4.27, 4.86] |  | Serum |  | Carbohydrate deficient transferrin/Transferrin.total [Mass Ratio] in Serum or Plasma | FALSE |
| 1558 | so-t-cd3 | % | 149 | 0 | [16.66, 19.73, 21.87, 23.49, 24.84, 27.82, 29.85, 33.41, 49.51] |  |  |  |  | FALSE |
| 1559 | so-t-cd3 |  | 6 | 16.67 |  |  |  |  |  | FALSE |
| 1560 | so-t-cd4 | % | 149 | 0 | [9.42, 10.93, 12.3, 13.53, 14.67, 15.99, 17.4, 19.67, 23.42] |  |  |  |  | FALSE |
| 1561 | so-t-cd4 |  | 6 | 16.67 |  |  |  |  |  | FALSE |
| 1562 | so-t-cd8 | % | 149 | 0 | [5.87, 7, 7.83, 8.57, 9.8, 10.57, 12.18, 14.02, 21.4] |  |  |  |  | FALSE |
| 1563 | so-t-cd8 |  | 6 | 16.67 |  |  |  |  |  | FALSE |

