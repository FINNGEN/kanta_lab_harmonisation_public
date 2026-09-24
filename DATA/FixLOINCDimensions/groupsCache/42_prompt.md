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
Here is group 42.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3000285 | Sodium [Moles/volume] in Blood | 1.000 | 129 |  4 |       967 |
| 3002079 | Sodium [Moles/time] in 24 hour Urine | 1.000 | 1217 |  2 |     2,837 |
| 3002190 | Sodium [Moles/volume] in Dialysis fluid | 1.000 |  |  0 |         0 |
| 3002568 | Complement factor B [Mass/volume] in Serum or Plasma | 1.000 |  |  3 |       154 |
| 3003181 | Sodium [Moles/volume] in Urine | 1.000 | 412 |  3 |    11,625 |
| 3008607 | Semen analysis panel | 1.000 |  |  0 |         0 |
| 3015399 | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | 1.000 |  | 15 |   285,465 |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 1.000 | 5 | 52 | 7,821,326 |
| 3019800 | Troponin T.cardiac [Mass/volume] in Serum or Plasma | 1.000 | 291 | 60 |   599,869 |
| 3020410 | Lactate [Moles/volume] in Arterial plasma | 1.000 |  |  0 |         0 |
| 3021337 | Troponin I.cardiac [Mass/volume] in Serum or Plasma | 1.000 | 113 | 25 |   323,924 |
| 3022948 | Iron [Moles/volume] in Serum or Plasma | 1.000 | 140 | 15 |   207,654 |
| 3023103 | Potassium [Moles/volume] in Serum or Plasma | 1.000 | 3 | 45 | 7,908,182 |
| 3026910 | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 190 | 17 | 1,024,731 |
| 3033658 | Prothrombin time (PT) actual/Normal | 1.000 | 3000 | 17 |   484,673 |
| 3035509 | Tobramycin [Mass/volume] in Serum or Plasma | 1.000 | 1858 |  3 |     1,365 |
| 3036428 | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid | 1.000 |  |  3 |     3,914 |
| 3040491 | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | 1.000 |  |  2 |       471 |
| 3043706 | Sodium [Moles/volume] in Arterial blood | 1.000 |  |  0 |         0 |
| 36306105 | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 1.000 |  |  0 |         0 |
| 1469828 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by High sensitivity method | 0.988 |  |  0 |         0 |
| 40769783 | Troponin T.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.971 |  |  0 |         0 |
| 3004282 | Tumor necrosis factor.alpha [Mass/volume] in Serum or Plasma | 0.970 |  |  3 |       150 |
| 46235078 | Potassium [Moles/volume] in Serum, Plasma or Blood | 0.966 |  |  0 |         0 |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.965 |  |  0 |         0 |
| 3022392 | Complement factor Bb [Mass/volume] in Serum or Plasma | 0.960 |  |  0 |         0 |
| 1259708 | PDGFRA gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.956 |  |  0 |         0 |
| 3018405 | Lactate [Moles/volume] in Arterial blood | 0.954 | 1277 |  8 |    56,958 |
| 3033745 | Troponin I.cardiac [Mass/volume] in Blood | 0.952 |  |  0 |         0 |
| 3966146 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Serum or Plasma | 0.952 |  |  0 |         0 |
| 3048529 | Troponin T.cardiac [Mass/volume] in Blood | 0.948 |  |  0 |         0 |
| 3046569 | Transferrin receptor.soluble [Moles/volume] in Serum or Plasma | 0.945 |  |  0 |         0 |
| 3008486 | Thyroxine (T4) free [Moles/volume] in Serum or Plasma | 0.944 | 133 | 24 | 1,537,005 |
| 3014485 | Sodium [Moles/volume] in 24 hour Urine | 0.942 | 1451 |  0 |         0 |
| 3002400 | Iron [Mass/volume] in Serum or Plasma | 0.934 |  |  0 |         0 |
| 3006638 | Tobramycin [Mass/volume] in Serum or Plasma --trough | 0.933 | 1537 |  0 |         0 |
| 3026989 | Triiodothyronine (T3) Free [Moles/volume] in Serum or Plasma | 0.932 | 274 | 15 |   105,869 |
| 3029979 | Tobramycin [Moles/volume] in Serum or Plasma | 0.932 | 1858 |  0 |         0 |
| 3040086 | Sodium [Moles/volume] in Peritoneal dialysis fluid | 0.930 |  |  0 |         0 |
| 3023636 | Sodium [Moles/time] in 12 hour Urine | 0.930 |  |  0 |         0 |
| 3041449 | Collagen crosslinked C-telopeptide [Mass/volume] in Serum or Plasma | 0.926 |  |  3 |     1,772 |
| 1469723 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.925 |  |  0 |         0 |
| 1469858 | Troponin T.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.924 |  |  0 |         0 |
| 3041697 | Sodium [Moles/time] in 1 hour Urine | 0.923 |  |  0 |         0 |
| 3965350 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Plasma | 0.921 |  |  0 |         0 |
| 3965306 | Troponin T.cardiac [Mass/volume] in 6 hour Serum or Plasma | 0.921 |  |  0 |         0 |
| 3008007 | Sodium [Mass/time] in 24 hour Urine | 0.920 |  |  0 |         0 |
| 3019572 | Troponin T.cardiac [Mass/volume] in Venous blood | 0.918 |  |  0 |         0 |
| 3014620 | Thyroxine (T4) [Moles/volume] in Serum or Plasma | 0.917 | 145 |  1 |         8 |
| 3009107 | Complement factor B [Mass/volume] in Body fluid | 0.915 |  |  0 |         0 |
| 21494221 | Tobramycin free [Mass/volume] in Serum or Plasma | 0.914 |  |  0 |         0 |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.911 |  |  0 |         0 |
| 3004090 | Tobramycin [Mass/volume] in Serum or Plasma --peak | 0.910 | 1574 |  0 |         0 |
| 3006550 | Complement factor Ba [Mass/volume] in Serum or Plasma | 0.909 |  |  0 |         0 |
| 3027653 | Mycophenolate [Mass/volume] in Serum or Plasma | 0.909 |  |  3 |     1,935 |
| 3015574 | Sodium [Moles/time] in 6 hour Urine | 0.908 |  |  0 |         0 |
| 3029213 | Adenosine deaminase [Enzymatic activity/volume] in Pericardial fluid | 0.908 |  |  0 |         0 |
| 1617495 | Sodium [Moles/volume] in Dialysis fluid --1 hour specimen | 0.907 |  |  0 |         0 |
| 40760495 | Sodium [Moles/volume] in 2 hour Urine | 0.904 |  |  0 |         0 |
| 3035963 | Corticotropin [Moles/volume] in Plasma | 0.901 | 816 |  1 |         7 |
| 3006924 | Coagulation factor V activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.900 |  |  0 |         0 |
| 40762087 | Sodium [Moles/time] in 18 hour Urine | 0.900 |  |  0 |         0 |
| 1617300 | Sodium [Moles/volume] in Dialysis fluid --2 hour specimen | 0.900 |  |  0 |         0 |
| 3005445 | Coagulation factor X activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.899 |  |  0 |         0 |
| 3033252 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal fluid | 0.899 |  |  0 |         0 |
| 3008304 | Triiodothyronine (T3) [Moles/volume] in Serum or Plasma | 0.897 | 223 |  0 |         0 |
| 40757362 | Semen analysis fertility panel | 0.896 |  |  0 |         0 |
| 3008598 | Thyroxine (T4) free [Mass/volume] in Serum or Plasma | 0.895 |  |  0 |         0 |
| 1616723 | Sodium [Moles/volume] in Dialysis fluid --4 hour specimen | 0.895 |  |  0 |         0 |
| 3038702 | Sodium [Moles/volume] in Capillary blood | 0.895 |  |  2 |        74 |
| 3035637 | Corticotropin [Mass/volume] in Plasma | 0.895 |  |  1 |    10,000 |
| 3966498 | Troponin T. cardiac [Mass/volume] in 2 hour 5th generation Serum or Plasma | 0.895 |  |  0 |         0 |
| 3039179 | Angiotensin converting enzyme [Enzymatic activity/volume] in Peritoneal fluid | 0.895 |  |  0 |         0 |
| 40760484 | Sodium [Moles/volume] in 12 hour Urine | 0.895 |  |  0 |         0 |
| 3030860 | Tumor necrosis factor.alpha [Moles/volume] in Serum or Plasma | 0.894 |  |  0 |         0 |
| 3022810 | Sodium [Moles/volume] in Body fluid | 0.893 |  |  0 |         0 |
| 44816583 | Sodium [Moles/volume] in 4 hour Urine | 0.893 |  |  0 |         0 |
| 3005622 | Sodium [Moles/time] in 24 hour Stool | 0.892 |  |  0 |         0 |
| 1988875 | Tumor necrosis factor.alpha [Units/volume] in Serum or Plasma | 0.891 |  |  0 |         0 |
| 3005491 | Lactate [Moles/volume] in Plasma venous | 0.888 | 1070 |  0 |         0 |
| 3034249 | Sodium [Moles/volume] in Urine collected for unspecified duration | 0.888 | 689 |  0 |         0 |
| 3041244 | Adenosine deaminase [Enzymatic activity/volume] in Synovial fluid | 0.888 |  |  0 |         0 |
| 3028465 | Gamma glutamyl transferase [Enzymatic activity/volume] in Body fluid | 0.888 |  |  0 |         0 |
| 3026621 | Complement factor H [Mass/volume] in Serum or Plasma | 0.887 |  |  0 |         0 |
| 40762471 | Tobramycin [Mass/volume] in Serum or Plasma --post dialysis | 0.886 |  |  0 |         0 |
| 3005456 | Potassium [Moles/volume] in Blood | 0.885 | 106 |  0 |         0 |
| 3005757 | Coagulation factor V activity actual/normal in Platelet poor plasma by Coagulation assay | 0.885 | 1703 |  3 |     7,162 |
| 645187 | Iron [Measurement] in Serum or Plasma | 0.884 |  |  0 |         0 |
| 3026925 | Triiodothyronine (T3) Free [Mass/volume] in Serum or Plasma | 0.884 |  |  0 |         0 |
| 3010661 | Tobramycin [Mass/volume] in Serum or Plasma --trough post extended interval dosing | 0.883 |  |  0 |         0 |
| 3040526 | Collagen crosslinked C-telopeptide [Moles/volume] in Serum or Plasma | 0.882 |  |  0 |         0 |
| 3014111 | Lactate [Moles/volume] in Serum or Plasma | 0.881 | 346 | 10 |   326,511 |
| 3003308 | Coagulation factor X activity [Units/volume] in Platelet poor plasma by Chromogenic method | 0.881 |  |  0 |         0 |
| 42529232 | Thyroxine (T4) free [Moles/volume] in Serum or Plasma by Immunoassay | 0.880 |  |  0 |         0 |
| 40758222 | PDGFRA gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.880 |  |  0 |         0 |
| 3037437 | Adenosine deaminase [Enzymatic activity/volume] in Body fluid | 0.879 |  |  0 |         0 |
| 3028515 | Gamma glutamyl transferase [Enzymatic activity/volume] in Urine | 0.879 |  |  0 |         0 |
| 40758927 | Mycophenolate [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.877 |  |  0 |         0 |
| 3047181 | Lactate [Moles/volume] in Blood | 0.877 | 475 | 13 |    73,160 |
| 3024920 | Potassium [Moles/volume] in Serum or Plasma --3rd specimen | 0.877 |  |  0 |         0 |
| 42529255 | Triiodothyronine (T3) Free [Moles/volume] in Serum or Plasma by Immunoassay | 0.876 |  |  0 |         0 |
| 3032987 | Sodium [Moles/volume] corrected for glucose in Serum or Plasma | 0.875 |  |  0 |         0 |
| 3003701 | Tobramycin [Moles/volume] in Serum or Plasma --trough | 0.875 | 1537 |  0 |         0 |
| 3035561 | Lactate [Mass/volume] in Arterial blood | 0.872 |  |  0 |         0 |
| 3013870 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma | 0.872 |  |  0 |         0 |
| 37021379 | Sodium [Molar amount] in 24 hour Dialysis fluid | 0.871 |  |  0 |         0 |
| 3032971 | Troponin I.cardiac [Mass/volume] in Serum or Plasma by Detection limit <= 0.01 ng/mL | 0.871 | 449 |  0 |         0 |
| 3004409 | Coagulation factor X activity actual/normal in Platelet poor plasma by Coagulation assay | 0.870 | 1896 |  3 |     1,860 |
| 3004789 | Transferrin [Mass/volume] in Serum or Plasma | 0.870 | 809 | 17 |   191,693 |
| 36305238 | Potassium goal [Moles/volume] Serum or Plasma | 0.870 |  |  0 |         0 |
| 3035510 | Gentamicin [Mass/volume] in Serum or Plasma | 0.869 | 1092 |  3 |       712 |
| 21493666 | Mycophenolate acyl-glucuronide [Mass/volume] in Serum or Plasma | 0.869 |  |  0 |         0 |
| 3013098 | Potassium [Moles/volume] in Specimen | 0.869 |  |  0 |         0 |
| 3022126 | Complement C3b [Mass/volume] in Serum or Plasma | 0.868 |  |  0 |         0 |
| 3008721 | Complement factor I [Mass/volume] in Serum or Plasma | 0.867 |  |  0 |         0 |
| 3041354 | Potassium [Moles/volume] in Venous blood | 0.867 |  |  2 |    11,069 |
| 3026681 | Sodium [Moles/volume] in Specimen | 0.867 |  |  0 |         0 |
| 42870499 | Thrombin time actual/Normal | 0.867 | 3000 |  0 |         0 |
| 1259553 | PDGFRA gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.867 |  |  0 |         0 |
| 3008985 | Tobramycin [Mass/volume] in Body fluid | 0.866 |  |  0 |         0 |
| 647897 | Tumor necrosis factor.alpha [Measurement] in Serum or Plasma | 0.865 |  |  0 |         0 |
| 46235360 | Tumor necrosis factor receptor superfamily member 1A [Mass/volume] in Serum or Plasma | 0.865 |  |  0 |         0 |
| 3966641 | Thyroxine.free.gestational [Moles/volume] in Serum or Plasma by Immunoassay | 0.865 |  |  0 |         0 |
| 3021423 | Complement factor D [Mass/volume] in Serum or Plasma | 0.865 |  |  0 |         0 |
| 44816699 | Transferrin receptor.soluble/log Ferritin index [Mass Ratio] in Serum or Plasma | 0.864 |  |  0 |         0 |
| 3010307 | Gamma glutamyl transferase/Aspartate aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.864 |  |  0 |         0 |
| 3031579 | Sodium [Moles/volume] in Mixed venous blood | 0.863 |  |  0 |         0 |
| 3039651 | Potassium [Moles/volume] in Serum or Plasma --pre dialysis | 0.863 |  |  0 |         0 |
| 3036566 | Thyroxine binding globulin [Moles/volume] in Serum or Plasma | 0.862 |  |  1 |        12 |
| 3027828 | Triiodothyronine (T3).reverse [Moles/volume] in Serum or Plasma | 0.862 | 1057 |  0 |         0 |
| 46237012 | PDGFRA gene p.Asp842Val [Presence] in Blood or Tissue by Molecular genetics method | 0.861 |  |  0 |         0 |
| 3046728 | Iron [Presence] in Serum or Plasma | 0.861 |  |  0 |         0 |
| 3024380 | Potassium [Moles/volume] in Serum or Plasma --2nd specimen | 0.860 |  |  0 |         0 |
| 36659714 | Sodium [Moles/volume] in Urine from Fetus | 0.860 |  |  0 |         0 |
| 21493512 | Coagulation factor X activated inhibitor [Mass/volume] in Platelet poor plasma | 0.860 |  |  0 |         0 |
| 3010424 | Ferritin [Moles/volume] in Serum or Plasma | 0.859 |  |  0 |         0 |
| 3028271 | Lactate [Moles/volume] in Capillary blood | 0.859 |  |  6 |    13,034 |
| 3016991 | Thyroxine (T4) [Mass/volume] in Serum or Plasma | 0.859 |  |  0 |         0 |
| 645355 | Coagulation factor X inhibitor [Measurement] in Platelet poor plasma | 0.859 |  |  0 |         0 |
| 3009960 | Adenosine deaminase [Enzymatic activity/volume] in Blood | 0.858 |  |  0 |         0 |
| 3027396 | Coagulation factor V Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.858 |  |  0 |         0 |
| 3014353 | Coagulation factor X Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.858 |  |  0 |         0 |
| 3030959 | Coagulation factor X activity actual/normal in Platelet poor plasma by Chromogenic method | 0.856 | 1526 |  0 |         0 |
| 36304114 | Troponin I.cardiac [Interpretation] in Serum or Plasma Qualitative by High sensitivity method | 0.855 |  |  0 |         0 |
| 42868685 | Mycophenolate [Moles/volume] in Serum or Plasma | 0.855 | 1787 |  0 |         0 |
| 3035717 | Potassium [Moles/volume] in Dialysis fluid | 0.855 |  |  0 |         0 |
| 3049714 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma | 0.854 |  |  2 |     3,659 |
| 3025317 | Coagulation factor VII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.854 |  |  0 |         0 |
| 3043409 | Potassium [Moles/volume] in Arterial blood | 0.854 |  |  4 |    51,548 |
| 3008037 | Lactate [Moles/volume] in Venous blood | 0.854 |  |  7 |    32,806 |
| 3001838 | Sodium [Moles/volume] in Red Blood Cells | 0.853 |  |  0 |         0 |
| 3034552 | Adenosine deaminase [Enzymatic activity/volume] in Cerebral spinal fluid | 0.852 |  |  2 |       279 |
| 3049183 | Collagen crosslinked C-telopeptide [Mass/volume] in Urine | 0.852 |  |  0 |         0 |
| 44816586 | Sodium [Moles/volume] in Serum or Plasma --post dialysis | 0.852 |  |  0 |         0 |
| 3041052 | Coagulation factor X inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.851 |  |  0 |         0 |
| 3001793 | Complement C2 [Mass/volume] in Serum or Plasma | 0.851 |  |  0 |         0 |
| 3052649 | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma | 0.851 |  |  3 |     4,406 |
| 40761932 | Thyroxine (T4) free [Mass/volume] in Serum or Plasma --baseline | 0.850 |  |  0 |         0 |
| 42529254 | Triiodothyronine (T3) [Moles/volume] in Serum or Plasma by Immunoassay | 0.849 |  |  0 |         0 |
| 3044738 | Sodium [Moles/volume] (Maximum value during study) in Serum or Plasma | 0.848 |  |  0 |         0 |
| 3011732 | Aspartate aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.848 |  |  0 |         0 |
| 646647 | Antithrombin Ag [Measurement] in Platelet poor plasma | 0.848 |  |  0 |         0 |
| 40762116 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal dialysis fluid | 0.848 |  |  0 |         0 |
| 3022519 | Antithrombin [Interpretation] in Platelet poor plasma | 0.848 | 1117 |  0 |         0 |
| 3002907 | Coagulation factor XII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.846 |  |  0 |         0 |
| 3017692 | Complement C5 [Mass/volume] in Serum or Plasma | 0.846 |  |  0 |         0 |
| 3021862 | Iron [Interpretation] in Serum or Plasma | 0.845 |  |  0 |         0 |
| 21494686 | Coagulation factor V inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.845 |  |  0 |         0 |
| 3965093 | Coagulation factor X inhibitor [Units/volume] in Platelet poor plasma by Chromogenic method | 0.845 |  |  0 |         0 |
| 3010340 | Triiodothyronine (T3) [Mass/volume] in Serum or Plasma | 0.844 |  |  0 |         0 |
| 40758928 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.844 |  |  0 |         0 |
| 42529231 | Thyroxine (T4) [Moles/volume] in Serum or Plasma by Immunoassay | 0.843 |  |  0 |         0 |
| 3032491 | Iron [Mass/volume] in Serum or Plasma --1st specimen | 0.842 |  |  0 |         0 |
| 43055501 | Mycophenolate [Mass/volume] in Serum or Plasma --trough | 0.842 |  |  0 |         0 |
| 3002903 | Transferrin [Moles/volume] in Serum or Plasma | 0.840 | 809 |  0 |         0 |
| 3008440 | Collagen crosslinked N-telopeptide [Moles/volume] in Serum | 0.839 |  |  0 |         0 |
| 3052662 | Ceruloplasmin [Moles/volume] in Serum or Plasma | 0.839 |  |  0 |         0 |
| 1469583 | PDGFRA gene full mutation analysis [Presence] in Blood or Tissue by Sequencing | 0.838 |  |  0 |         0 |
| 46236075 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma by Immunoassay | 0.838 |  |  0 |         0 |
| 3022520 | Coagulation factor VIII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.838 |  |  0 |         0 |
| 3023945 | Coagulation factor V Ag actual/normal in Platelet poor plasma by Immunoassay | 0.838 |  |  0 |         0 |
| 3045783 | Sodium and Potassium panel [Moles/volume] - Serum or Plasma | 0.838 |  |  2 |   328,037 |
| 3033042 | Sodium [Moles/volume] in Peritoneal fluid | 0.837 |  |  0 |         0 |
| 3016005 | Antithrombin Ag [Mass/volume] in Platelet poor plasma by Immunoassay | 0.837 |  |  0 |         0 |
| 3965684 | Tumor necrosis factor ligand superfamily member 10 [Mass/volume] in Serum, Plasma or Blood | 0.836 |  |  0 |         0 |
| 3004057 | Coagulation factor V inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.835 |  |  0 |         0 |
| 3031053 | Iron [Mass/volume] in Serum or Plasma --5th specimen | 0.833 |  |  0 |         0 |
| 3030573 | Phosphate [Moles/volume] in Dialysis fluid | 0.833 |  |  0 |         0 |
| 3022979 | Gamma glutamyl cysteine synthetase [Enzymatic activity/volume] in Serum | 0.833 |  |  0 |         0 |
| 647604 | Coagulation factor VIII Ag [Measurement] in Platelet poor plasma | 0.833 |  |  0 |         0 |
| 3016469 | FGFR2 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.832 |  |  0 |         0 |
| 647113 | Triiodothyronine (T3) Free [Measurement] in Serum or Plasma | 0.832 |  |  0 |         0 |
| 36031832 | Coagulation factor V activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.832 |  |  0 |         0 |
| 3009991 | Angiotensin converting enzyme [Enzymatic activity/volume] in Cerebral spinal fluid | 0.831 |  |  3 |     2,955 |
| 44816885 | Collagen crosslinked C-telopeptide [Z-score] in Serum or Plasma | 0.831 |  |  0 |         0 |
| 3018676 | Antithrombin [Units/volume] in Platelet poor plasma by Chromogenic method | 0.831 | 1235 |  0 |         0 |
| 3039189 | Lupus anticoagulant neutralization dilute phospholipid [Time] in Platelet poor plasma | 0.831 |  |  0 |         0 |
| 3005949 | Lactate [Moles/volume] in Mixed venous blood | 0.830 |  |  0 |         0 |
| 3036335 | Angiotensin converting enzyme [Enzymatic activity/volume] in Blood | 0.830 | 1299 |  0 |         0 |
| 43533705 | Mycophenolate [Mass/volume] in Serum or Plasma --peak | 0.830 |  |  0 |         0 |
| 3004825 | Lactate [Moles/volume] in Body fluid | 0.829 |  |  0 |         0 |
| 3013721 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.829 | 19 | 14 |   513,305 |
| 40761934 | Triiodothyronine (T3) Free [Mass/volume] in Serum or Plasma --baseline | 0.829 |  |  0 |         0 |
| 3042943 | Fatty acid essential (C12-C22) panel - Serum or Plasma | 0.829 |  |  0 |         0 |
| 3034780 | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | 0.829 | 730 |  6 |    39,648 |
| 3014914 | Antithrombin [Moles/volume] in Platelet poor plasma by Chromogenic method | 0.828 |  |  0 |         0 |
| 3008009 | Antithrombin Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.827 | 1553 |  0 |         0 |
| 46235717 | Delta dRVVT [Time] in Platelet poor plasma by Coagulation assay | 0.827 |  |  0 |         0 |
| 42870299 | PDGFRA gene exon 18 targeted mutation analysis in Blood or Tissue by Sequencing | 0.825 |  |  0 |         0 |
| 36304001 | Fatty acid omega-3 and omega-6 panel - Serum or Plasma | 0.824 |  |  0 |         0 |
| 40761054 | Collagen crosslinked C-telopeptide [Mass/volume] in 24 hour Urine | 0.824 |  |  0 |         0 |
| 3044942 | Collagen crosslinked N-telopeptide [Mass/volume] in Urine | 0.822 |  |  0 |         0 |
| 3035276 | FGFR1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.822 |  |  0 |         0 |
| 40763074 | Corticotropin [Moles/volume] in Plasma --baseline | 0.822 |  |  0 |         0 |
| 3015449 | Antithrombin Ag [Moles/volume] in Platelet poor plasma by Immunoassay | 0.822 |  |  0 |         0 |
| 3031076 | Corticotropin [Mass/volume] in Plasma --baseline | 0.822 |  |  0 |         0 |
| 3008152 | Bicarbonate [Moles/volume] in Arterial blood | 0.821 | 310 | 12 |   183,958 |
| 3026365 | Gamma glutamyl transferase [Enzymatic activity/volume] in Semen | 0.821 |  |  0 |         0 |
| 36032012 | Gamma glutamyl transferase [Enzymatic activity/volume] in DBS | 0.821 |  |  0 |         0 |
| 3021398 | Gamma glutamyl transferase [Enzymatic activity/volume] in Amniotic fluid | 0.819 |  |  0 |         0 |
| 3031643 | Corticotropin [Mass/volume] in Plasma --3 AM specimen | 0.818 |  |  0 |         0 |
| 3009299 | Lupus anticoagulant neutralization platelet [Time] in Platelet poor plasma by Coagulation assay | 0.817 | 811 |  0 |         0 |
| 40761633 | Corticotropin [Moles/volume] in Plasma --10 AM specimen | 0.817 |  |  0 |         0 |
| 40761662 | Corticotropin [Moles/volume] in Plasma --2 PM specimen | 0.815 |  |  0 |         0 |
| 40761632 | Corticotropin [Mass/volume] in Plasma --10 AM specimen | 0.815 |  |  0 |         0 |
| 3049123 | Corticotropin [Mass/volume] in Plasma --12 AM specimen | 0.815 |  |  0 |         0 |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.815 | 16 | 21 | 5,367,314 |
| 40757623 | Alanine aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.815 |  |  0 |         0 |
| 648623 | Mycophenolate [Measurement] in Serum or Plasma | 0.815 |  |  0 |         0 |
| 3027206 | Corticotropin [Mass/volume] in Plasma by Radioimmunoassay (RIA) | 0.814 |  |  0 |         0 |
| 40761642 | Corticotropin [Moles/volume] in Plasma --12 AM specimen | 0.814 |  |  0 |         0 |
| 3043430 | Interleukin 1 alpha [Mass/volume] in Serum or Plasma | 0.814 |  |  0 |         0 |
| 3031315 | Corticotropin [Mass/volume] in Plasma --3 PM specimen | 0.812 |  |  0 |         0 |
| 3032992 | Corticotropin [Mass/volume] in Plasma --6 PM specimen | 0.812 |  |  0 |         0 |
| 3000515 | Antithrombin actual/normal in Platelet poor plasma by Chromogenic method | 0.812 | 760 |  9 |    39,650 |
| 3052673 | Corticotropin [Mass/volume] in Plasma --4 AM specimen | 0.811 |  |  0 |         0 |
| 40761643 | Corticotropin [Moles/volume] in Plasma --12 PM specimen | 0.810 |  |  0 |         0 |
| 40761635 | Corticotropin [Moles/volume] in Plasma --10 PM specimen | 0.810 |  |  0 |         0 |
| 3042156 | PTPN11 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.810 |  |  0 |         0 |
| 1988486 | Tumor necrosis factor.alpha [Mass/volume] in Cerebral spinal fluid | 0.809 |  |  0 |         0 |
| 40761703 | Corticotropin [Moles/volume] in Plasma --4 AM specimen | 0.808 |  |  0 |         0 |
| 40761710 | Corticotropin [Moles/volume] in Plasma --6 PM specimen | 0.808 |  |  0 |         0 |
| 3033688 | Peak flow meter device panel | 0.807 |  |  0 |         0 |
| 3027995 | Electrolytes 1998 panel - Serum or Plasma | 0.803 |  |  0 |         0 |
| 3046505 | Aldolase [Enzymatic activity/volume] in Pleural fluid | 0.803 |  |  0 |         0 |
| 648872 | Transferrin [Measurement] in Serum or Plasma | 0.803 |  |  0 |         0 |
| 3003771 | Antithrombin Ag actual/normal in Platelet poor plasma by Immunoassay | 0.802 |  |  3 |        68 |
| 40757296 | Tumor necrosis factor binding protein [Units/volume] in Serum | 0.799 |  |  0 |         0 |
| 40758265 | BCR-ABL1 kinase domain mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.799 |  |  0 |         0 |
| 3047091 | Lupus anticoagulant neutralization buffer [Time] in Platelet poor plasma by Coagulation assay | 0.798 |  |  0 |         0 |
| 3008336 | Mefenamate [Mass/volume] in Serum or Plasma | 0.797 |  |  0 |         0 |
| 1175721 | Fatty acid omega-3 and omega-6 panel - Blood | 0.796 |  |  0 |         0 |
| 3046082 | Antithrombin Ag [Presence] in Platelet poor plasma by Immunoassay | 0.795 |  |  0 |         0 |
| 3015401 | Amylase [Enzymatic activity/volume] in Pleural fluid | 0.794 |  |  2 |       728 |
| 3039628 | Collagen crosslinked C-telopeptide [Mass/time] in 24 hour Urine | 0.789 |  |  0 |         0 |
| 3001804 | Interleukin 1 beta [Mass/volume] in Serum or Plasma | 0.787 |  |  0 |         0 |
| 3027184 | Lupus anticoagulant [Interpretation] in Platelet poor plasma | 0.786 |  |  0 |         0 |
| 3023017 | Iron/Transferrin [Mass Ratio] in Serum or Plasma | 0.786 |  |  0 |         0 |
| 3027627 | Lupus anticoagulant neutralization high phospholipid [Time] in Platelet poor plasma by Coagulation assay | 0.784 |  |  0 |         0 |
| 1988962 | Transferrin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.779 |  |  0 |         0 |
| 3030682 | Semen analysis post vasectomy panel | 0.777 |  |  0 |         0 |
| 44786996 | Sodium and Potassium panel [Moles/volume] - Blood | 0.775 |  |  0 |         0 |
| 3007886 | Transferrin [Mass/volume] in Urine | 0.774 |  |  0 |         0 |
| 3023542 | Coagulation normal/actual in Platelet poor plasma by Prothrombin time (PT) | 0.774 |  |  0 |         0 |
| 3011482 | Spermatozoa motility and count panel | 0.772 |  |  0 |         0 |
| 42870500 | Reptilase time actual/Normal | 0.768 | 3000 |  0 |         0 |
| 1259791 | Lupus anticoagulant aPTT screening panel - Platelet poor plasma by Coagulation assay | 0.768 |  |  0 |         0 |
| 3001122 | Ferritin [Mass/volume] in Serum or Plasma | 0.762 | 153 | 13 |   725,861 |
| 3037839 | Renal function 2000 panel - Serum or Plasma | 0.762 |  |  0 |         0 |
| 46235718 | Delta aPTT [Time] in Platelet poor plasma by Coagulation assay | 0.761 |  |  0 |         0 |
| 1988420 | Gas and electrolytes panel - Arterial blood | 0.760 |  |  0 |         0 |
| 21493451 | Spirometry panel | 0.757 |  |  0 |         0 |
| 3000288 | Sodium/Potassium [Molar ratio] in Serum or Plasma | 0.756 |  |  0 |         0 |
| 40758907 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of platelet lysate | 0.755 |  |  0 |         0 |
| 3049875 | Spermatozoa morphology panel | 0.755 |  |  0 |         0 |
| 3045669 | Fatty acid comprehensive (C8-C26) panel - Serum or Plasma | 0.754 |  |  0 |         0 |
| 40766287 | aPTT actual/normal in Platelet poor plasma by Coagulation assay | 0.753 |  |  0 |         0 |
| 3964861 | Semen and urine analysis fertility panel - Specimen | 0.752 |  |  0 |         0 |
| 3017427 | Lupus anticoagulant neutralization dilute phospholipid [Presence] in Platelet poor plasma | 0.751 | 1189 |  0 |         0 |
| 40758906 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of saline | 0.749 |  |  0 |         0 |
| 3044051 | Lupus anticoagulant neutralization high phospholipid.factor substitution [Time] in Platelet poor plasma by Coagulation assay --immediately after 1:2 addition of normal plasma | 0.748 |  |  0 |         0 |
| 3019174 | dRVVT in Platelet poor plasma by Coagulation assay | 0.747 | 759 |  1 |       485 |
| 3039047 | Heavy metals panel - Serum or Plasma | 0.747 |  |  0 |         0 |
| 1761868 | Lipid panel - Serum or Plasma | 0.745 |  |  4 |   529,561 |
| 40770913 | Hypoglycemics panel - Serum or Plasma | 0.744 |  |  0 |         0 |
| 646557 | Potassium [Measurement] in Serum or Plasma | 0.741 |  |  0 |         0 |
| 3015620 | Creatine kinase panel - Serum or Plasma | 0.740 |  |  0 |         0 |
| 3032166 | Volatiles panel - Serum or Plasma | 0.739 |  |  0 |         0 |
| 3015029 | Plasminogen activator urokinase type [Units/volume] in Urine | 0.739 |  |  0 |         0 |
| 21492381 | Fatty acid comprehensive (C8-C26) panel - Red Blood Cells | 0.735 |  |  0 |         0 |
| 3023329 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter | 0.735 |  |  0 |         0 |
| 3005353 | Prothrombin activity actual/normal in Platelet poor plasma by Coagulation assay | 0.732 |  |  3 |     1,839 |
| 3019794 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --post therapy | 0.730 |  |  0 |         0 |
| 3002681 | Prothrombin Ag actual/normal in Platelet poor plasma by Immunoassay | 0.728 |  |  0 |         0 |
| 40757584 | Semen analysis test method | 0.726 |  |  0 |         0 |
| 3013176 | Coagulation normal/actual in Platelet poor plasma by aPTT | 0.725 |  |  0 |         0 |
| 3046526 | FEV1 --5 minutes post exercise | 0.724 |  |  0 |         0 |
| 3034426 | Prothrombin time (PT) | 0.723 | 47 |  1 |     1,808 |
| 3009101 | Plasminogen activator urokinase type [Units/volume] in Platelet poor plasma | 0.719 |  |  0 |         0 |
| 3044378 | FEV1 --10 minutes post exercise | 0.717 |  |  0 |         0 |
| 36306151 | Blood pressure with exercise and post exercise panel | 0.716 |  |  0 |         0 |
| 3045930 | Fatty acid mitochondrial (C8-C18) panel - Serum or Plasma | 0.716 |  |  0 |         0 |
| 44816654 | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum | 0.715 |  |  0 |         0 |
| 3050160 | 3-Hydroxy fatty acid panel - Serum or Plasma | 0.715 |  |  0 |         0 |
| 40758360 | Electrolytes panel - Blood | 0.714 |  |  0 |         0 |
| 1091858 | Prothrombin time (PT) factor substitution [Time Ratio] in Control Platelet poor plasma by Coagulation assay --2H post incubation with 1:1 normal plasma | 0.714 |  |  0 |         0 |
| 3965213 | Electrolytes panel - Venous blood | 0.713 |  |  0 |         0 |
| 3046362 | FEV1 --15 minutes post exercise | 0.713 |  |  0 |         0 |
| 46235736 | Interleukin 2 Receptor Soluble [Mass/volume] in Serum or Plasma | 0.712 |  |  0 |         0 |
| 3046729 | Fatty acid very long chain (C22-C26) panel - Serum or Plasma | 0.708 |  |  0 |         0 |
| 36303453 | Omega-3 (EPA+DHA) index in Serum or Plasma | 0.706 |  |  0 |         0 |
| 42869550 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --pre therapy | 0.706 |  |  0 |         0 |
| 40759048 | Interleukin 1 receptor alpha chain soluble [Mass/volume] in Serum or Plasma | 0.704 |  |  0 |         0 |
| 3045149 | Reason for lab test in Semen | 0.702 |  |  0 |         0 |
| 21490868 | Fatty acid oxidation panel - Fibroblast | 0.700 |  |  0 |         0 |
| 36659643 | Aldosterone and sodium panel - 24 hour Urine | 0.697 |  |  0 |         0 |
| 42528941 | Spontaneous clot formation [Time] in Platelet poor plasma | 0.696 |  |  0 |         0 |
| 1616827 | Angiopoietin receptor 2 [Mass/volume] in Serum or Plasma | 0.694 |  |  0 |         0 |
| 37020970 | Coagulation.INR goal in Platelet poor plasma by Prothrombin time (PT) | 0.690 |  |  0 |         0 |
| 42868467 | Maximum expiratory gas flow/Predicted maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.690 |  |  0 |         0 |
| 40768507 | Time to expiratory gas flow.max | 0.689 |  |  0 |         0 |
| 3005080 | Thrombin time in Platelet poor plasma from Control by Coagulation assay | 0.689 |  |  0 |         0 |
| 1617311 | Time to thrombin peak in Platelet poor plasma by Chromogenic method | 0.688 |  |  0 |         0 |
| 21493444 | Maximum expiratory pressure Respiratory system --post bronchodilation | 0.686 |  |  0 |         0 |
| 21493450 | Pulmonary function test panel | 0.686 |  |  0 |         0 |
| 3001133 | Recalcification time in Platelet poor plasma from Control by Coagulation assay | 0.686 |  |  0 |         0 |
| 3033157 | Peak flow meter Vendor name | 0.684 |  |  0 |         0 |
| 21491705 | Aldosterone and renin concentration panel - Plasma | 0.684 |  |  0 |         0 |
| 40758532 | Asthma tracking panel | 0.683 |  |  0 |         0 |
| 40758281 | Aldosterone and renin activity panel - Plasma | 0.682 |  |  0 |         0 |
| 3035969 | Recalcification time in Platelet poor plasma by Coagulation assay | 0.682 |  |  0 |         0 |
| 42868465 | Maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.682 |  |  0 |         0 |
| 3005470 | Maximum expiratory gas flow Respiratory system airway --post therapy | 0.682 |  |  0 |         0 |
| 3008561 | Activated protein C resistance [Time Ratio] in Platelet poor plasma by Coagulation assay | 0.679 | 797 |  0 |         0 |
| 3023055 | Clot Lysis [Time] in Platelet poor plasma by Coagulation assay | 0.678 |  |  0 |         0 |
| 3019858 | Maximum voluntary ventilation [Flow] --post bronchodilator/Voluntary ventilation.maximum predicted | 0.676 |  |  0 |         0 |
| 3034996 | Type of Peak flow meter | 0.671 |  |  0 |         0 |
| 3034016 | Peak flow meter Vendor model code | 0.671 |  |  0 |         0 |
| 21490894 | Expiratory airway gas flow | 0.671 |  |  0 |         0 |
| 3004364 | Maximum voluntary ventilation [Flow] --pre bronchodilator/Voluntary ventilation.maximum predicted | 0.669 |  |  0 |         0 |
| 42868463 | Maximum expiratory gas flow Respiratory system airway Predicted | 0.669 |  |  0 |         0 |
| 42868464 | Maximum expiratory gas flow Respiratory system airway --pre bronchodilation | 0.667 |  |  0 |         0 |
| 3047332 | Spermatozoa IgA and IgG and IgM panel - Serum | 0.664 |  |  0 |         0 |
| 21493223 | Uroflowmetry panel | 0.657 |  |  0 |         0 |
| 36305632 | Microbiology CNAMTS panel - Semen | 0.646 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 339 | ab-na | mmol/l | 1125 | 0 | [130.94, 134.84, 136.62, 138.04, 139.34, 140.42, 141.09, 142.57, 144.87] |  | Arterial blood | Native preparation | Sodium [Moles/volume] in Arterial blood | FALSE |
| 340 | ap-lakt | mmol/l | 1456 | 0 | [0.68, 0.81, 0.96, 1.1, 1.28, 1.5, 1.81, 2.29, 3.25] |  |  |  | Lactate [Moles/volume] in Arterial plasma | FALSE |
| 341 | ap-lakt |  | 18 | 50 |  |  |  |  | Lactate [Moles/volume] in Arterial plasma | FALSE |
| 342 | ap-na | % | 24 | 0 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma | FALSE |
| 343 | ap-na | g/l | 6 | 0 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma | FALSE |
| 344 | ap-na | kpa | 12 | 0 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma | FALSE |
| 345 | ap-na | mmol/l | 50270 | 0 | [130.71, 133.37, 134.96, 136, 136.98, 137.95, 138.88, 139.98, 141.72] |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma | FALSE |
| 346 | ap-na | °c | 6 | 0 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma | FALSE |
| 347 | ap-na |  | 233 | 92.27 |  |  |  | Native preparation | Sodium [Moles/volume] in Arterial plasma | FALSE |
| 348 | ap-nak |  | 155 | 100 |  |  |  |  | Sodium and Potassium panel - Arterial plasma | TRUE |
| 349 | b-na | mmol/l | 59360 | 0 | [132.76, 134.99, 136.51, 137.61, 138.41, 139.21, 140.23, 141.69, 144.08] |  | Blood | Native preparation | Sodium [Moles/volume] in Blood | FALSE |
| 350 | b-na |  | 9740 | 95.39 | [132.18, 135.78, 137.16, 138.83, 139, 140, 140.41, 141, 142] |  | Blood | Native preparation | Sodium [Moles/volume] in Blood | FALSE |
| 351 | cp-na | mmol/l | 305 | 0 | [132, 134.22, 135.76, 137, 138, 139.28, 140, 141.93, 143] |  |  | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 352 | cp-na |  | 18 | 100 |  |  |  | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 353 | di-na | mmol/l | 307 | 0 |  | Di-Natrium | Dialysis fluid | Native preparation | Sodium [Moles/volume] in Dialysis fluid | FALSE |
| 354 | di-na |  | 5 | 100 |  | Di-Natrium | Dialysis fluid | Native preparation | Sodium [Moles/volume] in Dialysis fluid | FALSE |
| 355 | du-na | mmol | 2785 | 0.25 | [76.79, 98.05, 115.16, 132.8, 151.88, 170.12, 193.55, 223.43, 273.21] | dU-Natrium | 24-hour urine | Native preparation | Sodium [Moles/time] in 24 hour Urine | FALSE |
| 356 | du-na | mmol/24h | 60 | 0 |  | dU-Natrium | 24-hour urine | Native preparation | Sodium [Moles/time] in 24 hour Urine | FALSE |
| 357 | du-na |  | 1021 | 70.23 | [65.53, 84.3, 103.25, 116.92, 139.24, 156.61, 172.58, 210.59, 273.58] | dU-Natrium | 24-hour urine | Native preparation | Sodium [Moles/time] in 24 hour Urine | FALSE |
| 358 | fp-ctx | ng/l | 34 | 0 |  |  | Fasting plasma |  | Collagen type I C-telopeptide [Mass/volume] in Serum or Plasma | FALSE |
| 359 | fp-ctx | ug/l | 1281 | 0 | [0.09, 0.14, 0.2, 0.25, 0.3, 0.38, 0.48, 0.6, 0.81] |  | Fasting plasma |  | Collagen type I C-telopeptide [Mass/volume] in Serum or Plasma | FALSE |
| 360 | fp-ctx |  | 491 | 16.7 | [0.12, 0.19, 0.24, 0.31, 0.39, 0.48, 0.58, 0.71, 1] |  | Fasting plasma |  | Collagen type I C-telopeptide [Mass/volume] in Serum or Plasma | FALSE |
| 361 | fp-gt | u/l | 772 | 0 | [15.6, 19.58, 23.9, 27.61, 33.27, 39.92, 49.93, 68.82, 104.64] |  | Fasting plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 362 | fp-gt |  | 11 | 0 |  |  | Fasting plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 363 | fp-na | mmol/l | 6047 | 0 | [135.6, 137.84, 139, 139.97, 140.01, 141, 141.04, 142, 143] |  | Fasting plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 364 | fp-na |  | 18 | 11.11 |  |  | Fasting plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 365 | p-acth | ng/l | 10045 | 0.42 | [8.08, 11.12, 14.1, 17.14, 20.58, 24.79, 30.92, 40.41, 66.95] | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone [Mass/volume] in Plasma | FALSE |
| 366 | p-acth | pmol/l | 7 | 0 |  | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone [Moles/volume] in Plasma | FALSE |
| 367 | p-acth |  | 1461 | 80.01 | [9.26, 12.21, 15.18, 18.04, 23.17, 27.09, 32.96, 40.36, 61.68] | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone [Mass/volume] in Plasma | FALSE |
| 368 | p-at3 | % | 33387 | 0.01 | [54.15, 67.47, 77.12, 84.9, 91.44, 97.34, 103.31, 110.17, 119.77] | P -Antitrombiini III | Plasma |  | Antithrombin III [Arbitrary concentration] in Platelet poor plasma | FALSE |
| 369 | p-at3 | form | 18 | 0 |  | P -Antitrombiini III | Plasma |  | Antithrombin III [Arbitrary concentration] in Platelet poor plasma | FALSE |
| 370 | p-at3 |  | 750 | 50.4 | [77.41, 88.27, 92.93, 97.96, 101.75, 106.37, 110.41, 114.53, 119.94] | P -Antitrombiini III | Plasma |  | Antithrombin III [Arbitrary concentration] in Platelet poor plasma | FALSE |
| 371 | p-at3. | % | 4852 | 0 | [82.58, 90.63, 95.72, 100.18, 103.97, 107.65, 111.95, 117.06, 124.39] |  | Plasma |  | Antithrombin III [Arbitrary concentration] in Platelet poor plasma | FALSE |
| 372 | p-at3. |  | 269 | 20.45 | [87.63, 92.63, 97.23, 100.8, 104.86, 109.03, 113.28, 117.74, 123.49] |  | Plasma |  | Antithrombin III [Arbitrary concentration] in Platelet poor plasma | FALSE |
| 373 | p-efa | form | 5 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  | Essential fatty acids panel - Plasma | TRUE |
| 374 | p-efa |  | 125 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  | Essential fatty acids panel - Plasma | TRUE |
| 375 | p-fakb | g/l | 120 | 0 | [0.14, 0.17, 0.18, 0.2, 0.21, 0.21, 0.23, 0.26, 0.3] | P -Faktori B | Plasma |  | Complement factor B [Mass/volume] in Serum or Plasma | FALSE |
| 376 | p-fakb |  | 35 | 25.71 |  | P -Faktori B | Plasma |  | Complement factor B [Mass/volume] in Serum or Plasma | FALSE |
| 377 | p-fe | umol/l | 2840 | 0 | [5.52, 7.66, 9.48, 11.25, 13.18, 14.87, 16.94, 19.46, 23.35] |  | Plasma |  | Iron [Moles/volume] in Serum or Plasma | FALSE |
| 378 | p-fe |  | 740 | 33.92 | [5.15, 6.78, 8.55, 10.06, 12.18, 14.07, 16.43, 19.54, 23.49] |  | Plasma |  | Iron [Moles/volume] in Serum or Plasma | FALSE |
| 379 | p-fs | s | 319 | 0 | [28, 29.31, 30.81, 32, 33.17, 35, 36.48, 39.22, 45.08] |  | Plasma |  |  | FALSE |
| 380 | p-fs |  | 1586 | 99.87 |  |  | Plasma |  |  | FALSE |
| 381 | p-fv | % | 6911 | 0.01 | [43.78, 58.4, 69.62, 80.37, 90.29, 99.93, 110.48, 122.94, 139.52] | P -Hyytymistekijä V | Plasma |  | Coagulation factor V [Activity] in Platelet poor plasma | FALSE |
| 382 | p-fv |  | 261 | 40.23 | [68.7, 79.64, 87.53, 94.6, 99.14, 104.6, 110.72, 119.21, 132.72] | P -Hyytymistekijä V | Plasma |  | Coagulation factor V [Activity] in Platelet poor plasma | FALSE |
| 383 | p-fx | % | 916 | 0.11 | [46.06, 65.75, 76.36, 83.72, 90.83, 97.78, 104.84, 112.37, 122.61] | P -Hyytymistekijä X | Plasma |  | Coagulation factor X [Activity] in Platelet poor plasma | FALSE |
| 384 | p-fx |  | 949 | 87.46 | [66, 76.45, 83.38, 90.43, 96, 100.47, 108.88, 114, 128] | P -Hyytymistekijä X | Plasma |  | Coagulation factor X [Activity] in Platelet poor plasma | FALSE |
| 385 | p-gt | mg/ml | 8 | 0 |  | P -Glutamyylitransferaasi | Plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 386 | p-gt | u/l | 820178 | 0.02 | [14.56, 18.66, 23.05, 28.6, 36.08, 47.26, 65.76, 101.29, 195.48] | P -Glutamyylitransferaasi | Plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 387 | p-gt |  | 15977 | 100 | [15.82, 20.13, 24.14, 29.03, 35.14, 45.13, 63.31, 89.78, 161.64] | P -Glutamyylitransferaasi | Plasma |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 388 | p-hstni | ng/l | 3261 | 0 | [1, 2, 3, 4.12, 6.04, 9.1, 14.48, 27.09, 65.46] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | FALSE |
| 389 | p-k+na |  | 69230 | 100 |  |  | Plasma |  | Sodium and Potassium panel - Serum or Plasma | TRUE |
| 390 | p-k,na |  | 2518 | 100 |  |  | Plasma |  | Sodium and Potassium panel - Serum or Plasma | TRUE |
| 391 | p-k-na | mmol/l | 594 | 100 |  |  | Plasma | Native preparation | Sodium and Potassium panel - Serum or Plasma | TRUE |
| 392 | p-k-na |  | 186 | 100 |  |  | Plasma | Native preparation | Sodium and Potassium panel - Serum or Plasma | TRUE |
| 393 | p-k-pa | mmol/l | 197 | 0 | [3.53, 3.78, 3.9, 4, 4.04, 4.13, 4.3, 4.38, 4.56] |  | Plasma | Long-term / prolonged | Potassium [Moles/volume] in Serum or Plasma | FALSE |
| 394 | p-k/na |  | 321 | 100 |  |  | Plasma |  | Sodium and Potassium panel - Serum or Plasma | TRUE |
| 395 | p-ked. | mmol/l | 344 | 0 |  |  | Plasma |  |  | FALSE |
| 396 | p-kjd. | mmol/l | 160 | 0 |  |  | Plasma |  |  | FALSE |
| 397 | p-la1 | s | 1064 | 0 | [30, 31.95, 33.1, 34.81, 35.99, 37.75, 39.96, 44.96, 54.77] |  | Plasma |  | Lupus anticoagulant dRVVT screen [Time] in Platelet poor plasma | FALSE |
| 398 | p-la1 |  | 52 | 50 |  |  | Plasma |  | Lupus anticoagulant dRVVT screen [Time] in Platelet poor plasma | FALSE |
| 399 | p-la2 | s | 498 | 0 | [32, 33.41, 35.41, 36.98, 38.82, 40.9, 43.06, 47.24, 53.65] |  | Plasma |  | Lupus anticoagulant dRVVT confirm [Time] in Platelet poor plasma | FALSE |
| 400 | p-la2 |  | 1411 | 99.43 |  |  | Plasma |  | Lupus anticoagulant dRVVT confirm [Time] in Platelet poor plasma | FALSE |
| 401 | p-mypa | mg/l | 1692 | 0.06 | [0.64, 0.99, 1.33, 1.7, 2.12, 2.67, 3.43, 4.39, 6.28] | P -Mykofenolihappo | Plasma |  | Mycophenolic acid [Mass/volume] in Serum or Plasma | FALSE |
| 402 | p-mypa |  | 245 | 76.33 |  | P -Mykofenolihappo | Plasma |  | Mycophenolic acid [Mass/volume] in Serum or Plasma | FALSE |
| 403 | p-na | mmol/ | 14 | 0 |  | P -Natrium | Plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 404 | p-na | mmol/l | 7320578 | 0.03 | [133.91, 136.27, 137.98, 138.99, 139.95, 140, 141, 142, 143] | P -Natrium | Plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 405 | p-na |  | 81059 | 100 | [134.02, 137.07, 138.67, 139, 140, 141, 142, 142.8, 143] | P -Natrium | Plasma | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 406 | p-na. | mmol/l | 1467 | 0 | [134.64, 136.99, 138.3, 139.9, 140.54, 141, 142, 142.75, 144] |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 407 | p-na: | mmol/l | 621 | 0 | [131.65, 133.8, 135, 136.23, 137.85, 138.61, 139.67, 140.88, 142] |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 408 | p-naed. | mmol/l | 306 | 0 |  |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 409 | p-najd. | mmol/l | 154 | 0 |  |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 410 | p-nak |  | 259040 | 100 |  |  | Plasma |  | Sodium and Potassium panel - Serum or Plasma | TRUE |
| 411 | p-nap | mmol/l | 342 | 0 | [132.69, 135.3, 137.47, 139, 140, 140.64, 142, 143, 145] |  | Plasma |  | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 412 | p-supar | ug/l | 351 | 0 | [2.87, 3.25, 3.63, 3.92, 4.33, 4.73, 5.27, 6.37, 8.21] |  | Plasma |  | Urokinase plasminogen activator receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 413 | p-supar |  | 16 | 100 |  |  | Plasma |  | Urokinase plasminogen activator receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 414 | p-t3-v | pmol/l | 82081 | 0.04 | [3.46, 3.84, 4.11, 4.35, 4.57, 4.81, 5.08, 5.46, 6.26] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated | Triiodothyronine.free [Moles/volume] in Serum or Plasma | FALSE |
| 415 | p-t3-v |  | 921 | 100 | [3.47, 3.87, 4.08, 4.31, 4.53, 4.77, 5.02, 5.39, 6.24] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated | Triiodothyronine.free [Moles/volume] in Serum or Plasma | FALSE |
| 416 | p-t4-v | pmol/l | 1108128 | 0.01 | [11.98, 13.02, 13.95, 14.63, 15.23, 16.03, 16.92, 17.94, 19.56] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated | Thyroxine.free [Moles/volume] in Serum or Plasma | FALSE |
| 417 | p-t4-v |  | 19446 | 100 | [12, 13.8, 14.44, 15.06, 16, 16.21, 16.99, 17.6, 19] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated | Thyroxine.free [Moles/volume] in Serum or Plasma | FALSE |
| 418 | p-t4v | pmol/l | 110881 | 0 | [12.73, 13.79, 14.57, 15.27, 15.96, 16.68, 17.48, 18.48, 19.99] |  | Plasma |  | Thyroxine.free [Moles/volume] in Serum or Plasma | FALSE |
| 419 | p-t4v |  | 4743 | 100 | [12.19, 13.39, 14.21, 14.93, 15.61, 16.33, 17.17, 18.29, 20.03] |  | Plasma |  | Thyroxine.free [Moles/volume] in Serum or Plasma | FALSE |
| 420 | p-tfr | mg/l | 188406 | 0.02 | [0.81, 1.28, 2.05, 2.5, 2.87, 3.3, 3.83, 4.64, 6.21] | P -Transferriinireseptori, liukoinen | Plasma |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 421 | p-tfr |  | 15951 | 100 | [2.12, 2.53, 2.87, 3.21, 3.63, 4.15, 4.81, 5.75, 7.59] | P -Transferriinireseptori, liukoinen | Plasma |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 422 | p-tni | ng/l | 220095 | 0 | [4, 5.13, 7.13, 10.22, 15.11, 24.46, 46.82, 122.37, 829.48] | P -Troponiini I | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 423 | p-tni | ug/l | 25579 | 0 | [0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.08, 0.16, 0.78] | P -Troponiini I | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 424 | p-tni |  | 70910 | 100 | [0.05, 0.22, 2.89, 4.65, 7.45, 12.28, 24.91, 48.92, 145.81] | P -Troponiini I | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 425 | p-tni. | ng/l | 6 | 0 |  |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 426 | p-tni. | ug/l | 155 | 0 | [0, 0, 0, 0, 0, 0, 0.01, 0.02, 0.06] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 427 | p-tni. |  | 28 | 100 |  |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 428 | p-tnih | ng/l | 1974 | 0 | [4, 5.78, 7.89, 10.8, 16.52, 27.69, 54.92, 168.16, 1593.63] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | FALSE |
| 429 | p-tnih |  | 440 | 100 |  |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | FALSE |
| 430 | p-tnl | ng/l | 124 | 0 | [3, 4, 5.16, 7, 10, 12.72, 29.97, 89.8, 240.6] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 431 | p-tnl | ug/l | 179 | 0 | [0, 0, 0, 0, 0, 0.01, 0.01, 0.02, 0.05] |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 432 | p-tnl |  | 36 | 100 |  |  | Plasma |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 433 | p-tnt | ng/l | 437584 | 0.96 | [6.97, 9.13, 11.78, 15.03, 19.12, 24.8, 33.92, 51.22, 106.22] | P -Troponiini T | Plasma |  | Troponin T.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 434 | p-tnt | ug/l | 76 | 0 |  | P -Troponiini T | Plasma |  | Troponin T.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 435 | p-tnt |  | 80220 | 100 | [6.97, 8.93, 11.46, 14.61, 18.09, 22.79, 29.94, 42.37, 74.82] | P -Troponiini T | Plasma |  | Troponin T.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 436 | p-tt | % | 472003 | 0.01 | [50.44, 65.04, 74.28, 81.62, 88.26, 94.73, 101.62, 109.77, 121.26] | P -Tromboplastiiniaika | Plasma |  | Prothrombin time (PT) actual/Normal | FALSE |
| 437 | p-tt | form | 20 | 0 |  | P -Tromboplastiiniaika | Plasma |  | Prothrombin time (PT) actual/Normal | FALSE |
| 438 | p-tt |  | 4462 | 100 | [41.42, 56.72, 66.85, 77.09, 85.82, 93.79, 102.07, 112.01, 126.16] | P -Tromboplastiiniaika | Plasma |  | Prothrombin time (PT) actual/Normal | FALSE |
| 439 | p-tt- | % | 1432 | 0 | [60.12, 72.07, 78.16, 83.25, 88.78, 95.39, 102.35, 111.94, 122.43] |  | Plasma |  | Prothrombin time (PT) actual/Normal | FALSE |
| 440 | p-tt- |  | 29 | 96.55 |  |  | Plasma |  | Prothrombin time (PT) actual/Normal | FALSE |
| 441 | p-tt. | % | 5628 | 0 | [63.13, 78.7, 87.12, 93.57, 99.77, 105.67, 112.42, 119.67, 130.89] |  | Plasma |  | Prothrombin time (PT) actual/Normal | FALSE |
| 442 | p-tt. |  | 328 | 31.4 | [48, 79.63, 90.12, 98.65, 107.18, 114.33, 121.82, 130.4, 140] |  | Plasma |  | Prothrombin time (PT) actual/Normal | FALSE |
| 443 | p-ttr | % | 1114 | 0 | [50.89, 61.27, 67.88, 73.89, 78.52, 83.07, 89.29, 95.08, 100] |  | Plasma |  | Time in therapeutic range [Time Fraction] in Platelet poor plasma | FALSE |
| 444 | p-ttr |  | 89 | 89.89 |  |  | Plasma |  | Time in therapeutic range [Time Fraction] in Platelet poor plasma | FALSE |
| 445 | pdgfr |  | 461 | 100 |  |  |  |  | PDGFRA gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method | FALSE |
| 446 | peak | l/min | 12 | 0 |  |  |  |  | Expiratory flow.peak [Volume Rate] by Spirometry | FALSE |
| 447 | peak |  | 104 | 100 |  |  |  |  | Expiratory flow.peak [Volume Rate] by Spirometry | FALSE |
| 448 | pef-pa |  | 7844 | 99.92 |  | Uloshengityksen huippuvirtaus, sarjamittaus, pitkäaikaisseuranta |  | Long-term / prolonged | Peak expiratory flow monitoring panel | TRUE |
| 449 | pef-ras |  | 242 | 100 |  | Uloshengityksen huippuvirtaus, sarjamittaus, rasituskoe |  |  | Peak expiratory flow post exercise panel | TRUE |
| 450 | pf-ace | u/l | 313 | 3.19 | [6.4, 10.22, 12.78, 15.45, 17.82, 19.96, 24.1, 28.83, 37.4] | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | FALSE |
| 451 | pf-ace |  | 161 | 98.14 |  | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | FALSE |
| 452 | pf-ada | u/l | 3550 | 0.14 | [3.68, 5.14, 6.78, 8.01, 9.46, 11.17, 13.55, 17.33, 25.48] | Pf-Adenosiinideaminaasi | Pleural fluid |  | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid | FALSE |
| 453 | pf-ada |  | 365 | 90.96 |  | Pf-Adenosiinideaminaasi | Pleural fluid |  | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid | FALSE |
| 454 | pneag |  | 244 | 100 |  |  |  |  |  | FALSE |
| 455 | s-na | mmol/l | 124118 | 0 | [137.36, 138.84, 139.01, 140, 140.14, 141, 141.38, 142, 143] | S -Natrium | Serum | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 456 | s-na | mol/l | 5 | 0 |  | S -Natrium | Serum | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 457 | s-na |  | 931 | 67.35 | [137.2, 138, 139, 139, 140, 140, 141, 141, 142.37] | S -Natrium | Serum | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 458 | s-t3-v | pmol/l | 18657 | 0 | [3.72, 4.06, 4.3, 4.5, 4.69, 4.9, 5.13, 5.43, 6.06] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated | Triiodothyronine.free [Moles/volume] in Serum or Plasma | FALSE |
| 459 | s-t3-v |  | 1623 | 51.2 | [3.55, 3.8, 4.02, 4.22, 4.41, 4.6, 4.85, 5.16, 5.82] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated | Triiodothyronine.free [Moles/volume] in Serum or Plasma | FALSE |
| 460 | s-t4-v | pmol/l | 252259 | 0 | [11.09, 12, 12.88, 13.14, 13.97, 14.48, 15.15, 16.1, 17.48] | S -Tyroksiini, vapaa | Serum | Free or unconjugated | Thyroxine.free [Moles/volume] in Serum or Plasma | FALSE |
| 461 | s-t4-v |  | 9900 | 100 | [12.03, 12.98, 13.72, 14.35, 14.94, 15.68, 16.39, 17.25, 18.59] | S -Tyroksiini, vapaa | Serum | Free or unconjugated | Thyroxine.free [Moles/volume] in Serum or Plasma | FALSE |
| 462 | s-t4v | pmol/l | 1086 | 0 | [12.85, 13, 14, 14.52, 15, 15.93, 16, 17, 18] |  | Serum |  | Thyroxine.free [Moles/volume] in Serum or Plasma | FALSE |
| 463 | s-tfr | mg | 7 | 0 |  | S -Transferriinireseptori, liukoinen | Serum |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 464 | s-tfr | mg/l | 77760 | 0 | [1, 1.22, 1.5, 1.89, 2.35, 2.8, 3.34, 4.1, 5.59] | S -Transferriinireseptori, liukoinen | Serum |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 465 | s-tfr |  | 1379 | 100 | [1.84, 2.22, 2.62, 3.08, 3.57, 4.23, 5.1, 6.26, 8.15] | S -Transferriinireseptori, liukoinen | Serum |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 466 | s-tnf | ng/l | 100 | 0 | [4.65, 5.4, 6.33, 7.11, 7.81, 8.85, 10.5, 13.2, 23.25] | S -Tuumorinekroositekijä, alfa | Serum |  | Tumor necrosis factor alpha [Mass/volume] in Serum or Plasma | FALSE |
| 467 | s-tnf |  | 50 | 74 |  | S -Tuumorinekroositekijä, alfa | Serum |  | Tumor necrosis factor alpha [Mass/volume] in Serum or Plasma | FALSE |
| 468 | s-tni | ng/l | 63 | 0 | [2.98, 3.29, 4.36, 4.96, 6.38, 8.72, 14.54, 33, 54.53] | S -Troponiini I | Serum |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 469 | s-tni | ug/l | 11 | 0 |  | S -Troponiini I | Serum |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 470 | s-tni |  | 171 | 100 |  | S -Troponiini I | Serum |  | Troponin I.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 471 | s-tnt | ng/l | 149 | 0 | [40, 42, 45.21, 51.23, 64.69, 87.1, 139.39, 201.81, 358.2] | S -Troponiini T | Serum |  | Troponin T.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 472 | s-tnt |  | 7446 | 99.38 |  | S -Troponiini T | Serum |  | Troponin T.cardiac [Mass/volume] in Serum or Plasma | FALSE |
| 473 | s-tob | mg/l | 805 | 0.99 | [0.29, 0.5, 0.61, 0.8, 1.01, 1.26, 1.54, 1.91, 3.02] | S -Tobramysiini | Serum |  | Tobramycin [Mass/volume] in Serum or Plasma | FALSE |
| 474 | s-tob |  | 560 | 81.96 |  | S -Tobramysiini | Serum |  | Tobramycin [Mass/volume] in Serum or Plasma | FALSE |
| 475 | sp-pak |  | 196 | 100 |  |  | Sperm / semen |  | Semen analysis panel | TRUE |
| 476 | sp-pakd |  | 138 | 100 |  |  | Sperm / semen |  | Semen analysis panel | TRUE |
| 477 | u-na | mmol/l | 8969 | 1.33 | [24.74, 32.42, 40.4, 48.4, 57.53, 68.16, 81.75, 99.14, 129.68] | U -Natrium | Urine | Native preparation | Sodium [Moles/volume] in Urine | FALSE |
| 478 | u-na |  | 2662 | 76.37 | [27.27, 35.54, 43.11, 51.43, 60.05, 68.34, 78.15, 92.47, 111.65] | U -Natrium | Urine | Native preparation | Sodium [Moles/volume] in Urine | FALSE |
| 479 | v-na |  | 265 | 0.75 | [130.22, 134.26, 135.98, 137.59, 138.5, 139.03, 140, 141, 142] |  |  | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 480 | vp-na | mmol/l | 10896 | 0 | [132.84, 135.34, 136.96, 137.97, 138.99, 139.84, 140.33, 141.08, 142.49] |  |  | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |
| 481 | vp-na |  | 174 | 98.28 |  |  |  | Native preparation | Sodium [Moles/volume] in Serum or Plasma | FALSE |

