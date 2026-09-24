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
Here is group 106.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1092251 | Bacteria identified in Bronchoalveolar lavage by Culture | 1.000 |  |  0 |         0 |
| 1469525 | Bacteria identified in Pus by Culture | 1.000 |  |  0 |         0 |
| 1761482 | Bacteria [#/volume] in Urine by Culture | 1.000 |  |  1 |    39,881 |
| 3009986 | Bacteria identified in Catheter tip by Culture | 1.000 | 946 |  0 |         0 |
| 3012475 | Bacteria identified in Throat by Culture | 1.000 | 638 |  0 |         0 |
| 3016727 | Bacteria identified in Body fluid by Culture | 1.000 | 1786 |  0 |         0 |
| 3016914 | Bacteria identified in Cerebral spinal fluid by Culture | 1.000 | 561 |  1 |     6,996 |
| 3023368 | Bacteria identified in Blood by Culture | 1.000 | 131 |  3 |   528,769 |
| 3023419 | Bacteria identified in Sputum by Culture | 1.000 | 1768 |  1 |    14,036 |
| 3025941 | Bacteria identified in Stool by Culture | 1.000 | 469 |  1 |    32,658 |
| 3026008 | Bacteria identified in Urine by Culture | 1.000 | 93 |  3 |   420,379 |
| 3031040 | Bacteria [#/volume] in Urine by Automated count | 1.000 |  | 12 | 1,358,321 |
| 36304419 | Bacteria [Presence] in Urine | 1.000 |  |  2 |   390,903 |
| 3013146 | Bacteria identified in Wound by Aerobe culture | 0.974 |  |  0 |         0 |
| 3025255 | Bacteria [#/area] in Urine sediment by Microscopy high power field | 0.955 | 89 |  0 |         0 |
| 40763091 | Bacteria identified in Peritoneal dialysis fluid by Culture | 0.947 |  |  1 |       914 |
| 3025099 | Bacteria identified in Sputum by Respiratory culture | 0.945 | 275 |  0 |         0 |
| 3024362 | Bacteria identified in Dialysis fluid by Culture | 0.941 | 982 |  0 |         0 |
| 3045360 | Bacteria identified in Bronchoalveolar lavage by Aerobe culture | 0.938 | 1695 |  0 |         0 |
| 3018368 | Bacteria identified in Wound deep by Aerobe culture | 0.929 |  |  0 |         0 |
| 1176221 | Bacteria identified in Catheter tip by Aerobe culture | 0.926 |  |  0 |         0 |
| 1092248 | Bacteria [#/area] in Urine sediment by Microscopy | 0.924 |  |  0 |         0 |
| 1175370 | Bacteria identified in Catheter tip by Anaerobe culture | 0.922 |  |  0 |         0 |
| 3025233 | Bacteria identified in Sputum by Aerobe culture | 0.921 |  |  0 |         0 |
| 3014137 | Bacteria identified in Wound shallow by Aerobe culture | 0.919 |  |  0 |         0 |
| 3003714 | Bacteria identified in Wound by Culture | 0.918 | 270 |  0 |         0 |
| 3009451 | Bacteria identified in 24 hour Urine by Culture | 0.916 |  |  0 |         0 |
| 1091200 | Bacteria [#/volume] in Urine | 0.913 |  |  0 |         0 |
| 3023470 | Bacteria # 2 identified in Stool by Culture | 0.913 |  |  0 |         0 |
| 40763313 | Bacteria identified in Bone marrow by Culture | 0.912 |  |  0 |         0 |
| 3014398 | Bacteria identified in Bone by Aerobe culture | 0.909 |  |  0 |         0 |
| 36305419 | Bacteria identified in Cerebral spinal fluid by Aerobe culture | 0.908 |  |  0 |         0 |
| 3012927 | Fungus identified in Stool by Culture | 0.906 |  |  0 |         0 |
| 3035740 | Bacteria identified in Throat by Aerobe culture | 0.905 | 526 |  0 |         0 |
| 3027969 | Bacteria identified in Wound by Anaerobe culture | 0.904 |  |  0 |         0 |
| 3002619 | Bacteria identified in Specimen by Culture | 0.902 | 39 |  1 |     1,514 |
| 3042936 | Bacteria identified in Isolate by Culture | 0.902 |  |  1 |   131,106 |
| 3016114 | Bacteria identified in Body fluid by Aerobe culture | 0.901 | 479 |  0 |         0 |
| 3003776 | Bacteria # 4 identified in Stool by Culture | 0.899 |  |  0 |         0 |
| 1469672 | Bacteria identified in Pus by Anaerobe culture | 0.899 |  |  0 |         0 |
| 3019415 | Bacteria identified in Food by Culture | 0.898 |  |  0 |         0 |
| 3019479 | Bacteria # 2 identified in Urine by Culture | 0.896 |  |  0 |         0 |
| 3000521 | Bacteria # 3 identified in Stool by Culture | 0.896 |  |  0 |         0 |
| 3028923 | Bacteria [#/area] in Urine sediment by Automated count | 0.895 |  |  0 |         0 |
| 3000455 | Bacteria identified in Stool by Anaerobe culture | 0.894 |  |  0 |         0 |
| 3014320 | Bacteria identified in Urethra by Culture | 0.893 |  |  0 |         0 |
| 3002687 | Bacteria # 5 identified in Stool by Culture | 0.893 |  |  0 |         0 |
| 3001028 | Bacteria # 6 identified in Stool by Culture | 0.891 |  |  0 |         0 |
| 3053320 | Bacteria # 2 identified in Blood by Culture | 0.891 |  |  0 |         0 |
| 1092049 | Bacteria identified in Bronchial specimen by Culture | 0.889 |  |  0 |         0 |
| 1091309 | Bacteria [#/area] in Urine sediment | 0.889 |  |  0 |         0 |
| 3003392 | Bacteria # 4 identified in Urine by Culture | 0.885 |  |  0 |         0 |
| 1091323 | Fungus identified in Catheter tip by Culture | 0.884 |  |  0 |         0 |
| 46234834 | Bacteria identified in Bone by Anaerobe+Aerobe culture | 0.884 |  |  1 |       312 |
| 3025037 | Bacteria identified in Peritoneal fluid by Culture | 0.884 |  |  0 |         0 |
| 1175982 | Bacteria identified in Peritoneal dialysis fluid by Aerobe culture | 0.882 |  |  0 |         0 |
| 1092182 | Bacteria [Presence] in Urine sediment by Microscopy | 0.881 |  |  0 |         0 |
| 3017227 | Bacteria identified in Wound deep by Anaerobe culture | 0.881 |  |  0 |         0 |
| 3044495 | Bacteria identified in Tissue by Culture | 0.880 |  |  0 |         0 |
| 1091465 | Bacteria # 2 identified in Catheter tip by Aerobe culture | 0.880 |  |  0 |         0 |
| 3046484 | Bacteria # 8 identified in Urine by Culture | 0.879 |  |  0 |         0 |
| 1092302 | Bacteria identified in Surgical wound by Culture | 0.879 |  |  0 |         0 |
| 36303545 | Bacteria identified in Cerebral spinal fluid by Anaerobe culture | 0.879 |  |  0 |         0 |
| 3045335 | Bacteria # 7 identified in Urine by Culture | 0.879 |  |  0 |         0 |
| 3014990 | Bacteria identified in Specimen by Sterile body fluid culture | 0.878 |  |  0 |         0 |
| 3003113 | Bacteria # 5 identified in Urine by Culture | 0.878 |  |  0 |         0 |
| 3019001 | Bacteria identified in Body fluid by Anaerobe culture | 0.877 |  |  0 |         0 |
| 3024194 | Bacteria identified in Pleural fluid by Culture | 0.877 |  |  0 |         0 |
| 3005024 | Bacteria # 3 identified in Urine by Culture | 0.877 |  |  0 |         0 |
| 3005745 | Bacteria identified in Blood by Aerobe culture | 0.876 |  |  0 |         0 |
| 3002013 | Bacteria # 6 identified in Urine by Culture | 0.876 |  |  0 |         0 |
| 3035734 | Bacteria # 2 identified in Wound deep by Aerobe culture | 0.875 |  |  0 |         0 |
| 1091909 | Bacteria # 2 identified in Catheter tip by Anaerobe culture | 0.875 |  |  0 |         0 |
| 3045873 | Bacteria identified in Nasopharynx by Culture | 0.875 |  |  0 |         0 |
| 3040138 | Bacteria identified in Sputum tracheal aspirate by Culture | 0.875 |  |  0 |         0 |
| 36304569 | Bacteria identified in Bronchoalveolar lavage by Anaerobe culture | 0.875 |  |  0 |         0 |
| 3036465 | Bacteria # 4 identified in Wound deep by Aerobe culture | 0.874 |  |  0 |         0 |
| 3049876 | Bacteria # 3 identified in Blood by Culture | 0.872 |  |  0 |         0 |
| 1469485 | Fungus identified in Pus by Culture | 0.870 |  |  0 |         0 |
| 3036247 | Bacteria # 3 identified in Wound deep by Aerobe culture | 0.869 |  |  0 |         0 |
| 3004761 | Bacteria identified in Water by Culture | 0.868 |  |  0 |         0 |
| 36303914 | Fungus identified in Bronchoalveolar lavage by Culture | 0.868 |  |  0 |         0 |
| 3012809 | Bacteria # 2 identified in Bone by Aerobe culture | 0.867 |  |  0 |         0 |
| 1091623 | Bacteria # 3 identified in Catheter tip by Anaerobe culture | 0.866 |  |  0 |         0 |
| 1092431 | Bacteria # 3 identified in Catheter tip by Aerobe culture | 0.866 |  |  0 |         0 |
| 1175346 | Bacteria identified in Peritoneal dialysis fluid by Anaerobe culture | 0.866 |  |  0 |         0 |
| 3000686 | Virus identified in Throat by Culture | 0.864 |  |  0 |         0 |
| 3043614 | Bacteria identified in Aspirate by Culture | 0.863 |  |  1 |        22 |
| 3032172 | Bacteria [Presence] in Urine by Automated | 0.862 |  |  0 |         0 |
| 3013301 | Bacteria # 4 identified in Bone by Aerobe culture | 0.862 |  |  0 |         0 |
| 1092057 | Bacteria [#/volume] in Semen by Culture | 0.862 |  |  0 |         0 |
| 3002996 | Fungus identified in Cerebral spinal fluid by Culture | 0.859 |  |  0 |         0 |
| 1259518 | Bacterial vaginosis RNA [Presence] in Vagina by Probe with amplification | 0.859 |  |  0 |         0 |
| 3000448 | Bacteria # 2 identified in Sputum by Aerobe culture | 0.858 |  |  0 |         0 |
| 3027326 | Bacteria # 3 identified in Bone by Aerobe culture | 0.857 |  |  0 |         0 |
| 42870564 | Atopobium vaginae DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.856 |  |  0 |         0 |
| 3014365 | Bacteria # 6 identified in Bone by Aerobe culture | 0.855 |  |  0 |         0 |
| 3036266 | Bacteria # 2 identified in Throat by Aerobe culture | 0.854 |  |  0 |         0 |
| 3010729 | Bacteria # 5 identified in Bone by Aerobe culture | 0.853 |  |  0 |         0 |
| 3004562 | Bacteria [Presence] in Urine sediment by Light microscopy | 0.852 | 514 |  0 |         0 |
| 3023764 | Bacteria identified in Specimen by Respiratory culture | 0.852 |  |  0 |         0 |
| 3002611 | Bacteria # 4 identified in Sputum by Aerobe culture | 0.851 |  |  0 |         0 |
| 3010897 | Bacteria # 2 identified in Body fluid by Aerobe culture | 0.851 |  |  0 |         0 |
| 40770955 | Bacteria identified in Blood product unit by Culture | 0.850 |  |  0 |         0 |
| 3020072 | Bacteria # 6 identified in Sputum by Aerobe culture | 0.850 |  |  0 |         0 |
| 3035949 | Bacteria identified in Bone marrow by Aerobe culture | 0.850 | 1425 |  0 |         0 |
| 3019101 | Bacteria # 6 identified in Throat by Aerobe culture | 0.849 |  |  0 |         0 |
| 3001248 | Bacteria # 5 identified in Throat by Aerobe culture | 0.849 |  |  0 |         0 |
| 3001521 | Bacteria # 5 identified in Sputum by Aerobe culture | 0.849 |  |  0 |         0 |
| 3009602 | Bacteria # 4 identified in Body fluid by Aerobe culture | 0.848 |  |  0 |         0 |
| 3002416 | Bacteria # 4 identified in Throat by Aerobe culture | 0.847 |  |  0 |         0 |
| 3000088 | Virus identified in Cerebral spinal fluid by Culture | 0.847 |  |  0 |         0 |
| 1988560 | Cocci bacteria [#/volume] in Urine sediment by Automated count | 0.846 |  |  0 |         0 |
| 3006761 | Bacteria identified in Synovial fluid by Culture | 0.846 |  |  0 |         0 |
| 1092116 | Bacteria DNA [Presence] in Specimen by NAA with probe detection | 0.844 |  |  0 |         0 |
| 1989355 | Bacilliform bacteria [#/volume] in Urine sediment by Automated count | 0.843 |  |  0 |         0 |
| 43533982 | Bacteria identified in Mouth by Culture | 0.842 |  |  0 |         0 |
| 3006673 | Bacteria identified in Blood by Anaerobe culture | 0.842 |  |  0 |         0 |
| 3027689 | Bacteria # 3 identified in Body fluid by Aerobe culture | 0.842 |  |  0 |         0 |
| 3015532 | Bacteria identified in Bronchial specimen by Aerobe culture | 0.841 |  |  0 |         0 |
| 1092021 | Bacteria [#/volume] in Bronchoalveolar lavage by Culture | 0.840 |  |  0 |         0 |
| 3010121 | Bacteria # 5 identified in Body fluid by Aerobe culture | 0.840 |  |  0 |         0 |
| 3027247 | Bacteria identified in Specimen | 0.840 |  |  0 |         0 |
| 3029151 | Bacteria identified in Bronchial specimen | 0.840 |  |  0 |         0 |
| 3003509 | Bacteria # 3 identified in Throat by Aerobe culture | 0.839 |  |  0 |         0 |
| 3040827 | Bacteria identified in Anal by Culture | 0.839 |  |  0 |         0 |
| 1469941 | Gardnerella vaginalis DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.839 |  |  0 |         0 |
| 3021618 | Bacteria # 5 identified in Peritoneal fluid by Culture | 0.837 |  |  0 |         0 |
| 3039448 | Bacteria identified in Bile fluid by Culture | 0.837 |  |  0 |         0 |
| 42870565 | Bacterial vaginosis associated bacterium 2 DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.837 |  |  0 |         0 |
| 3029350 | Yeast [#/volume] in Urine by Automated count | 0.836 |  |  0 |         0 |
| 46235131 | Bacteria identified in Cerebral spinal fluid by Latex agglutination | 0.835 |  |  0 |         0 |
| 21492393 | Bacteria identified in Implanted device by Culture | 0.833 |  |  0 |         0 |
| 3016528 | Bacteria # 4 identified in Peritoneal fluid by Culture | 0.832 |  |  0 |         0 |
| 3000943 | Bacteria # 2 identified in Peritoneal fluid by Culture | 0.832 |  |  0 |         0 |
| 3010799 | Bacteria # 3 identified in Peritoneal fluid by Culture | 0.832 |  |  0 |         0 |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.832 |  |  0 |         0 |
| 1091856 | Ureaplasma urealyticum DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.831 |  |  0 |         0 |
| 3039187 | Neisseria gonorrhoeae rRNA [Presence] in Vaginal fluid by NAA with probe detection | 0.831 | 3000 |  0 |         0 |
| 3022889 | Bacteria # 6 identified in Peritoneal fluid by Culture | 0.831 |  |  0 |         0 |
| 3042736 | Bacteria [Presence] in Specimen | 0.829 |  |  0 |         0 |
| 3031246 | Bacteria identified in Isolate | 0.826 | 1461 |  0 |         0 |
| 1175573 | Streptococcus agalactiae DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.824 |  |  0 |         0 |
| 3000796 | Bacteria identified in Pleural fluid by Aerobe culture | 0.823 |  |  0 |         0 |
| 36660107 | Lactobacillus crispatus+gasseri+jensenii + Gardnerella vaginalis + Atopobium vaginae rRNA [Presence] in Vaginal fluid by NAA with probe detection | 0.821 |  |  0 |         0 |
| 42870561 | Candida albicans DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.820 |  |  0 |         0 |
| 36305372 | Bacteria identified in Peritoneal fluid by Anaerobe culture | 0.820 |  |  0 |         0 |
| 645382 | Bacteria [Measurement] in Urine | 0.816 |  |  0 |         0 |
| 1092178 | Bacteria [Presence] in Urine by Computer assisted method | 0.815 |  |  0 |         0 |
| 1175816 | Bacteria identified in Peritoneal fluid by Aerobe culture | 0.814 |  |  0 |         0 |
| 3015055 | Bacteria identified in Amniotic fluid by Culture | 0.811 |  |  0 |         0 |
| 3016298 | Mycobacterium sp identified in Cerebral spinal fluid by Organism specific culture | 0.809 |  |  0 |         0 |
| 3041413 | Bacterial casts [#/area] in Urine sediment by Microscopy low power field | 0.804 |  |  0 |         0 |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.802 |  |  0 |         0 |
| 3037244 | Yeast [#/area] in Urine sediment by Microscopy high power field | 0.801 | 643 |  0 |         0 |
| 3032846 | Bacteria [Presence] in Peritoneal fluid by Light microscopy | 0.800 |  |  0 |         0 |
| 3032566 | Bacteria [Presence] in Pleural fluid by Light microscopy | 0.800 |  |  0 |         0 |
| 3033386 | Bacteria [Presence] in Cerebral spinal fluid by Light microscopy | 0.797 |  |  1 |     3,745 |
| 3026950 | Bacteria [#/area] in Synovial fluid by Microscopy high power field | 0.795 |  |  0 |         0 |
| 3035583 | Leukocytes [#/area] in Urine sediment by Microscopy high power field | 0.794 | 79 |  0 |         0 |
| 3006581 | Other Antibiotic [Susceptibility] | 0.784 | 123 |  0 |         0 |
| 36304920 | Bacteria identified in Synovial fluid by Anaerobe culture | 0.783 |  |  0 |         0 |
| 1175669 | Bacteria identified in Synovial fluid by Aerobe culture | 0.783 |  |  0 |         0 |
| 36303793 | Bacteria identified in Pleural fluid by Anaerobe culture | 0.783 |  |  0 |         0 |
| 46234951 | Bacterial 16S rRNA [#/volume] in XXX.body fluid by NAA with probe detection | 0.774 |  |  0 |         0 |
| 3024572 | Bacteria identified in Sputum by Cystic fibrosis respiratory culture | 0.773 |  |  0 |         0 |
| 3003703 | Bacteria # 3 identified in Sputum by Aerobe culture | 0.771 |  |  0 |         0 |
| 3028269 | Bacteria identified in Vaginal fluid by Aerobe culture | 0.771 | 1225 |  0 |         0 |
| 648891 | Bacteria [Measurement] in Urine sediment | 0.771 |  |  0 |         0 |
| 3001886 | Microscopic observation [Identifier] in Cerebral spinal fluid by Gram stain | 0.766 |  |  0 |         0 |
| 3022036 | Colony count [#/volume] in Urine | 0.764 |  |  0 |         0 |
| 3031354 | Microscopic observation [Identifier] in Cerebral spinal fluid by Cyto stain | 0.763 |  |  0 |         0 |
| 3043867 | Bacteria # 8 identified in Specimen by Culture | 0.757 |  |  0 |         0 |
| 3023143 | Ciprofloxacin [Susceptibility] | 0.756 | 317 |  0 |         0 |
| 46234891 | Bacterial 16S rRNA [#/mass] in XXX.tissue by NAA with probe detection | 0.756 |  |  0 |         0 |
| 3046136 | Bacteria # 7 identified in Specimen by Culture | 0.756 |  |  0 |         0 |
| 3005384 | Microscopic observation [Identifier] in Pleural fluid by Gram stain | 0.754 |  |  0 |         0 |
| 3031505 | Bacteria [Presence] in Synovial fluid by Light microscopy | 0.754 |  |  0 |         0 |
| 3045058 | Bacteria # 3 identified in Specimen by Culture | 0.752 |  |  0 |         0 |
| 3012625 | Microscopic observation [Identifier] in Cerebral spinal fluid by Acid fast stain | 0.749 |  |  0 |         0 |
| 40758731 | Microscopic observation [Identifier] in Pleural fluid by Cyto stain | 0.746 |  |  0 |         0 |
| 3025242 | Penicillin [Susceptibility] | 0.746 | 453 |  0 |         0 |
| 40759834 | Bacteria identified in Pericardial fluid by Culture | 0.746 |  |  0 |         0 |
| 3012339 | Bacteria identified in Semen | 0.744 |  |  0 |         0 |
| 3026402 | Cephalexin [Susceptibility] | 0.742 |  |  0 |         0 |
| 3034838 | Amoxicillin [Susceptibility] | 0.739 |  |  0 |         0 |
| 1091892 | Aggregatibacter aphrophilus DNA [Presence] in Specimen by NAA with probe detection | 0.738 |  |  0 |         0 |
| 3042086 | Cefuroxime [Susceptibility] | 0.737 | 837 |  0 |         0 |
| 3027141 | Cefotaxime [Susceptibility] | 0.736 | 404 |  0 |         0 |
| 3026005 | Bacteria identified in Cervix by Anaerobe culture | 0.735 |  |  0 |         0 |
| 3045330 | Bacteria identified in Cervix by Culture | 0.734 |  |  0 |         0 |
| 3009403 | Ampicillin [Susceptibility] | 0.733 | 331 |  0 |         0 |
| 3033805 | Cefdinir [Susceptibility] | 0.730 |  |  0 |         0 |
| 1091056 | Aggregatibacter actinomycetemcomitans DNA [Presence] in Specimen by NAA with probe detection | 0.728 |  |  0 |         0 |
| 3000855 | Microscopic observation [Identifier] in Vaginal fluid by Gram stain | 0.727 |  |  1 |    10,447 |
| 1092003 | Prevotella buccae DNA [Presence] in Specimen by NAA with probe detection | 0.727 |  |  0 |         0 |
| 3002389 | Microscopic observation [Identifier] in Synovial fluid by Gram stain | 0.726 |  |  0 |         0 |
| 36203640 | Lawsonia intracellularis RNA [#/volume] in Specimen by NAA with probe detection | 0.723 |  |  0 |         0 |
| 3022087 | Bacteria identified in Cervix by Aerobe culture | 0.723 |  |  0 |         0 |
| 44816565 | Atopobium vaginae DNA [Log #/volume] in Vaginal fluid by NAA with probe detection | 0.722 |  |  0 |         0 |
| 44816566 | Gardnerella vaginalis DNA [Log #/volume] in Vaginal fluid by NAA with probe detection | 0.722 |  |  0 |         0 |
| 40758732 | Microscopic observation [Identifier] in Synovial fluid by Cyto stain | 0.720 |  |  0 |         0 |
| 44816567 | Lactobacillus sp DNA [Log #/volume] in Vaginal fluid by NAA with probe detection | 0.717 |  |  0 |         0 |
| 647359 | Yeast [Presence] in Vaginal fluid by Gram stain | 0.709 |  |  0 |         0 |
| 1469731 | Bacteria identified in Penis by Culture | 0.708 |  |  0 |         0 |
| 3048545 | Microorganism identified in Cervical or vaginal smear or scraping by Cyto stain | 0.708 |  |  0 |         0 |
| 3002444 | Fungus identified in Synovial fluid by Culture | 0.708 |  |  0 |         0 |
| 37019773 | Bacteria identified in Genital specimen by Anaerobe culture | 0.703 |  |  0 |         0 |
| 37020690 | Gram negative bacilli identified in Isolate by Organism specific culture | 0.702 |  |  0 |         0 |
| 3008193 | Fungus identified in Specimen by Fungus stain | 0.700 | 825 |  0 |         0 |
| 1176508 | Bacteria identified in Semen by Anaerobe culture | 0.698 |  |  0 |         0 |
| 3028855 | Bacteria [Presence] in Body fluid by Light microscopy | 0.552 |  |  0 |         0 |
| 3018384 | Bacteria [Presence] in Nose by Light microscopy | 0.548 |  |  0 |         0 |
| 36659740 | Bacteria [Presence] in Bronchoalveolar lavage by Light microscopy | 0.541 |  |  0 |         0 |
| 3046346 | Bacteria [Presence] in Eye by Light microscopy | 0.541 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1397 | -bakt-he |  | 111 | 100 |  |  |  | Antibiotic sensitivity | Bacteria identified [Susceptibility] | FALSE |
| 1398 | -bakt-lm |  | 545 | 100 |  |  |  | Species identification | Bacteria identified | FALSE |
| 1399 | -baktvi |  | 1515 | 100 |  | -Bakteeri, viljely |  |  | Bacteria identified by Culture | FALSE |
| 1400 | -baktvr |  | 22025 | 100 |  | -Bakteeri, värjäys |  |  | Bacteria identified by Stain | FALSE |
| 1401 | af-baktvi |  | 262 | 100 |  |  | Aspiration fluid |  | Bacteria identified in Body fluid by Culture | FALSE |
| 1402 | as-baktvr |  | 252 | 100 |  |  | Ascitic fluid |  | Bacteria identified in Peritoneal fluid by Stain | FALSE |
| 1403 | b-bakt-vi |  | 1757 | 100 |  |  | Blood | Culture | Bacteria identified in Blood by Culture | FALSE |
| 1404 | b-baktjvi |  | 28084 | 100 |  | B -Bakteeri, jatkoviljely | Blood |  | Bacteria identified in Blood by Culture | FALSE |
| 1405 | b-baktsvi |  | 6514 | 100 |  |  | Blood |  | Bacteria identified in Blood by Culture | FALSE |
| 1406 | b-baktvi |  | 506538 | 100 |  | B -Bakteeri, viljely | Blood |  | Bacteria identified in Blood by Culture | FALSE |
| 1407 | b-baktvi. |  | 2240 | 100 |  |  | Blood |  | Bacteria identified in Blood by Culture | FALSE |
| 1408 | b-baktvij |  | 1818 | 100 |  |  | Blood |  | Bacteria identified in Blood by Culture | FALSE |
| 1409 | bakteerit |  | 6114 | 100 |  |  |  |  | Bacteria | FALSE |
| 1410 | baktlm |  | 897 | 100 |  |  |  |  | Bacteria identified | FALSE |
| 1411 | baktvr |  | 339 | 100 |  |  |  |  | Bacteria identified by Stain | FALSE |
| 1412 | bl-baktvi |  | 303 | 100 |  |  | Bronchoalveolar lavage |  | Bacteria identified in Bronchoalveolar lavage by Culture | FALSE |
| 1413 | bo-baktvi |  | 312 | 100 |  |  | Bone |  | Bacteria identified in Bone by Culture | FALSE |
| 1414 | ca-baktvi |  | 1564 | 100 |  | Ca-Bakteeri, viljely suonikanyylista |  |  | Bacteria identified in Catheter tip by Culture | FALSE |
| 1415 | d-baktvi |  | 120 | 100 |  |  |  |  |  | FALSE |
| 1416 | ex-baktvi |  | 14096 | 100 |  | Ex-Bakteeri, viljely | Expectorate (sputum) |  | Bacteria identified in Sputum by Culture | FALSE |
| 1417 | ex-baktvr |  | 3217 | 100 |  |  | Expectorate (sputum) |  | Bacteria identified in Sputum by Stain | FALSE |
| 1418 | f-baktjvi |  | 281 | 100 |  |  | Feces |  | Bacteria identified in Stool by Culture | FALSE |
| 1419 | f-baktvi1 |  | 32771 | 100 |  | F -Bakteeri, viljely 1 (Salmonella, Shigella, Yersinia, Campylobacter) | Feces |  | Bacteria identified in Stool by Culture | FALSE |
| 1420 | f-baktvi2 |  | 739 | 100 |  | F -Bakteeri, viljely 2 (Clostridium difficile, Staphylococcus aureus, candida) | Feces |  | Bacteria and Fungus identified in Stool by Culture | FALSE |
| 1421 | f-baktvi3 |  | 1380 | 100 |  | F -Bakteeri, viljely 3 (viljely 1 + Bacillus cereus, Clostridium perfringens, Staphylococcus aureus) | Feces |  | Bacteria identified in Stool by Culture | FALSE |
| 1422 | f-baktvip |  | 17284 | 100 |  |  | Feces |  | Bacteria identified in Stool by Culture | FALSE |
| 1423 | fl-baktna |  | 154 | 100 |  |  | Vaginal discharge |  | Bacteria RNA/DNA [Presence] in Vagina by NAA with probe detection | FALSE |
| 1424 | fl-baktvr |  | 11637 | 100 |  | Fl-Bakteeri, värjäys | Vaginal discharge |  | Bacteria identified in Vagina by Gram stain | FALSE |
| 1425 | li-baktvi |  | 7020 | 100 |  | Li-Bakteeri, viljely | Cerebrospinal fluid |  | Bacteria identified in Cerebral spinal fluid by Culture | FALSE |
| 1426 | li-baktvr |  | 3747 | 100 |  | Li-Bakteeri, värjäys | Cerebrospinal fluid |  | Bacteria identified in Cerebral spinal fluid by Stain | FALSE |
| 1427 | pd-baktvi |  | 917 | 100 |  | Pd-Bakteeri, viljely peritoneaalidialyysinesteestä | Peritoneal dialysis fluid |  | Bacteria identified in Dialysis fluid (peritoneal) by Culture | FALSE |
| 1428 | pf-baktvr |  | 258 | 100 |  |  | Pleural fluid |  | Bacteria identified in Pleural fluid by Stain | FALSE |
| 1429 | pp-baktnh |  | 445 | 100 |  | Pp-Bakteeri, nukleiinihappo (kvant), ientasku | Periodontal pocket |  | Bacteria RNA/DNA [#/volume] in Subgingival plaque by NAA with probe detection | FALSE |
| 1430 | ps-baktvi |  | 3894 | 99.97 |  | Ps-Bakteeri, viljely | Pharyngeal secretion |  | Bacteria identified in Throat by Culture | FALSE |
| 1431 | pu-baktvi1 |  | 132179 | 100 |  | Pu-Bakteeri, viljely 1 (anaerobi + aerobiviljely, syvämärkä) | Pus |  | Bacteria identified in Pus by Culture | FALSE |
| 1432 | pu-baktvi2 |  | 97752 | 100 |  | Pu-Bakteeri, viljely 2 (aerobiviljely, pintamärkä) | Pus |  | Bacteria identified in Wound by Aerobic culture | FALSE |
| 1433 | sy-baktvr |  | 1225 | 100 |  |  | Synovial fluid |  | Bacteria identified in Synovial fluid by Stain | FALSE |
| 1434 | u-bact |  | 4570 | 19.15 | [1.88, 4.41, 7.11, 12.12, 22.01, 65.08, 182.99, 478.65, 3425.04] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count | FALSE |
| 1435 | u-bakt | e6/l | 12886 | 0 | [0.99, 1.98, 3.85, 6.56, 13.19, 31.1, 95.22, 562.86, 5560.98] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count | FALSE |
| 1436 | u-bakt | estimate | 14084 | 99.66 |  |  | Urine |  | Bacteria [Presence] in Urine | FALSE |
| 1437 | u-bakt | u/field | 11 | 0 |  |  | Urine |  | Bacteria [#/area] in Urine sediment by Microscopy high power | FALSE |
| 1438 | u-bakt |  | 377251 | 99.78 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Bacteria [Presence] in Urine | FALSE |
| 1439 | u-bakt-vi |  | 14923 | 100 | [10000, 10000, 10000, 10000, 1e+05, 1e+05, 1e+05, 1e+06, 1e+06] |  | Urine | Culture | Bacteria [#/volume] in Urine by Culture | FALSE |
| 1440 | u-bakt. | /sunf | 514 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Bacteria [#/area] in Urine sediment by Microscopy high power | FALSE |
| 1441 | u-bakt. | /sunfält | 40 | 0 |  |  | Urine |  | Bacteria [#/area] in Urine sediment by Microscopy high power | FALSE |
| 1442 | u-bakt. |  | 1617 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine | FALSE |
| 1443 | u-baktalv |  | 2258 | 99.42 |  | U -Bakteeri, aluslasiviljely | Urine |  | Bacteria [#/volume] in Urine by Culture | FALSE |
| 1444 | u-baktb |  | 210 | 4.29 | [1.72, 5.76, 11.77, 19.42, 30.15, 66.2, 213.28, 2129.49, 11056.23] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count | FALSE |
| 1445 | u-baktbv | e6/l | 3962 | 0 | [0.82, 1.8, 3.97, 7.16, 16.23, 44.68, 171.24, 1315.3, 12976.36] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count | FALSE |
| 1446 | u-baktbv |  | 93 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine | FALSE |
| 1447 | u-bakteeri |  | 1711 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine | FALSE |
| 1448 | u-bakteerit | e6/l | 1692 | 0 | [1, 3.34, 6.78, 15.13, 44.47, 159.79, 845.2, 5975.08, 24980.83] |  | Urine |  | Bacteria [#/volume] in Urine by Automated count | FALSE |
| 1449 | u-bakteerit |  | 16840 | 99.96 |  |  | Urine |  | Bacteria [Presence] in Urine | FALSE |
| 1450 | u-baktevi |  | 18799 | 99.99 |  | U -Bakteeri, erikoisviljely | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1451 | u-baktjvi |  | 390824 | 100 |  | U -Bakteeri, jatkoviljely | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1452 | u-baktjvi. |  | 11570 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1453 | u-baktla |  | 4577 | 100 |  |  | Urine |  |  | FALSE |
| 1454 | u-baktlm |  | 1437 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1455 | u-baktnim |  | 111 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1456 | u-bakts |  | 1045 | 100 |  |  | Urine |  | Bacteria [Presence] in Urine | FALSE |
| 1457 | u-baktseu |  | 39886 | 99.99 |  |  | Urine |  | Bacteria [Presence] in Urine | FALSE |
| 1458 | u-baktsjvi |  | 539 | 100 |  |  | Urine |  |  | FALSE |
| 1459 | u-bakttun |  | 653 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1460 | u-baktv |  | 1154 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1461 | u-baktvi | e6 | 45 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria [#/volume] in Urine by Culture | FALSE |
| 1462 | u-baktvi | e6/l | 60 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria [#/volume] in Urine by Culture | FALSE |
| 1463 | u-baktvi | form | 10 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1464 | u-baktvi |  | 1324678 | 99.99 | [106.83, 10000, 1e+05, 754545.45, 1e+06, 1e+07, 1e+08, 1e+08, 1e+08] | U -Bakteeri, viljely | Urine |  | Bacteria [#/volume] in Urine by Culture | FALSE |
| 1465 | u-baktvi/ |  | 562 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1466 | u-baktvi/oma |  | 629 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1467 | u-baktvi2 |  | 283 | 100 |  |  | Urine |  | Bacteria identified in Urine by Culture | FALSE |
| 1468 | u-baktvtk |  | 1637 | 100 |  |  | Urine |  |  | FALSE |

