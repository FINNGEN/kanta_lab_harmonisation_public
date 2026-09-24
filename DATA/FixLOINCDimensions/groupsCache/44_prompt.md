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
Here is group 44.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1616780 | Bilirubin.total [Moles/volume] in Capillary blood | 1.000 |  |  0 |         0 |
| 3000764 | Benzodiazepines [Presence] in Urine | 1.000 | 196 |  1 |    52,821 |
| 3002395 | Porphobilinogen [Moles/volume] in Urine | 1.000 |  |  0 |         0 |
| 3004176 | fentaNYL [Presence] in Urine | 1.000 | 1509 |  0 |         0 |
| 3006140 | Bilirubin.total [Moles/volume] in Serum or Plasma | 1.000 | 21 | 12 | 1,506,859 |
| 3007463 | Buprenorphine [Presence] in Urine | 1.000 | 812 |  1 |     1,837 |
| 3007733 | Chloride [Moles/volume] in Urine | 1.000 | 697 |  3 |       232 |
| 3009201 | Thyrotropin [Units/volume] in Serum or Plasma | 1.000 | 105 | 44 | 2,173,821 |
| 3009708 | Mercury [Presence] in Urine | 1.000 |  |  0 |         0 |
| 3010015 | Selenium [Moles/volume] in Serum or Plasma | 1.000 | 1614 |  3 |     1,141 |
| 3010600 | Phosphate [Moles/time] in 24 hour Urine | 1.000 | 1478 |  0 |         0 |
| 3012095 | Magnesium [Moles/volume] in Serum or Plasma | 1.000 | 78 |  8 |   270,004 |
| 3013494 | Arsenic.inorganic [Mass/volume] in Urine | 1.000 |  |  0 |         0 |
| 3015736 | pH of Urine | 1.000 | 612 | 11 |   668,794 |
| 3017400 | Magnesium [Moles/volume] in Urine | 1.000 |  |  3 |       149 |
| 3017937 | Magnesium [Moles/time] in 24 hour Urine | 1.000 |  |  2 |       148 |
| 3019900 | Cholesterol [Moles/volume] in Serum or Plasma | 1.000 | 32 | 31 | 2,073,556 |
| 3022229 | Phosphate [Moles/volume] in Urine | 1.000 | 1197 |  3 |       856 |
| 3023920 | Nickel [Presence] in Urine | 1.000 |  |  0 |         0 |
| 3025766 | Phosphate [Presence] in Urine | 1.000 |  |  0 |         0 |
| 3025942 | Nickel [Mass/volume] in Urine | 1.000 |  |  0 |         0 |
| 3027114 | Cholesterol [Mass/volume] in Serum or Plasma | 1.000 |  |  1 |         9 |
| 3027944 | Amphetamines [Presence] in Urine | 1.000 | 214 |  2 |    50,457 |
| 3030458 | Arsenic.inorganic [Moles/volume] in Urine | 1.000 |  |  0 |         0 |
| 3030704 | Iodide [Mass/volume] in Urine | 1.000 |  |  0 |         0 |
| 3033543 | Specific gravity of Urine | 1.000 | 122 |  0 |         0 |
| 3034719 | Porphobilinogen [Presence] in Urine | 1.000 |  |  0 |         0 |
| 3035060 | Mercury [Moles/volume] in Blood | 1.000 | 1314 |  2 |       111 |
| 3036180 | Methadone [Presence] in Urine | 1.000 | 417 |  1 |       363 |
| 3037426 | Urobilinogen [Presence] in Urine by Test strip | 1.000 | 134 |  0 |         0 |
| 3039416 | Vasoactive intestinal peptide [Presence] in Serum or Plasma | 1.000 |  |  0 |         0 |
| 3040794 | Aluminum [Moles/volume] in Urine | 1.000 |  |  1 |        77 |
| 3041918 | Cholesterol [Moles/volume] in Pleural fluid | 1.000 |  |  3 |       975 |
| 3044316 | Mercury [Moles/volume] in Urine | 1.000 |  |  2 |       132 |
| 3044597 | Porphobilinogen/Creatinine [Molar ratio] in Urine | 1.000 |  |  0 |         0 |
| 3044943 | Nickel [Moles/volume] in Urine | 1.000 |  |  0 |         0 |
| 3045284 | traMADol [Presence] in Urine | 1.000 |  |  0 |         0 |
| 3045424 | Erythrocytes [Presence] in Urine | 1.000 | 287 |  5 |    46,066 |
| 3051252 | Vasoactive intestinal peptide [Moles/volume] in Serum or Plasma | 1.000 |  |  3 |       452 |
| 44787084 | Porphobilinogen/Creatinine [Molar ratio] in 24 hour Urine | 0.973 |  |  0 |         0 |
| 46235782 | Bilirubin.total [Moles/volume] in Serum, Plasma or Blood | 0.970 |  |  0 |         0 |
| 1091049 | Amphetamine [Presence] in Urine | 0.963 |  |  0 |         0 |
| 3022454 | Porphobilinogen/Creatinine [Mass Ratio] in Urine | 0.958 |  |  0 |         0 |
| 3031400 | Arsenic.inorganic [Mass/volume] in 24 hour Urine | 0.957 |  |  0 |         0 |
| 1091059 | Erythrocytes [Presence] in Urine sediment | 0.956 |  |  0 |         0 |
| 42870560 | Thyrotropin [Units/volume] in Cord blood | 0.956 |  |  3 |       490 |
| 3011960 | Natriuretic peptide B [Mass/volume] in Serum or Plasma | 0.955 | 204 |  4 |    97,925 |
| 3021916 | Phosphate [Moles/volume] in 24 hour Urine | 0.955 |  |  0 |         0 |
| 3025734 | Magnesium [Moles/volume] in 24 hour Urine | 0.951 |  |  0 |         0 |
| 3003738 | Nickel [Mass/volume] in 24 hour Urine | 0.950 |  |  0 |         0 |
| 3027464 | Nickel [Moles/volume] in 24 hour Urine | 0.948 |  |  0 |         0 |
| 3028054 | Vasoactive intestinal peptide [Mass/volume] in Serum or Plasma | 0.948 |  |  0 |         0 |
| 3018834 | Bilirubin.total [Presence] in Urine by Test strip | 0.944 | 64 |  2 |       908 |
| 3044592 | Porphobilinogen [Moles/volume] in 24 hour Urine | 0.943 |  |  0 |         0 |
| 3005219 | Iodine [Mass/volume] in Urine | 0.941 |  |  0 |         0 |
| 3001736 | Aluminum [Moles/volume] in 24 hour Urine | 0.941 |  |  0 |         0 |
| 3041509 | Phosphate [Moles/time] in 12 hour Urine | 0.940 |  |  0 |         0 |
| 40763806 | fentaNYL [Presence] in Specimen | 0.938 |  |  0 |         0 |
| 3044311 | Mercury [Moles/volume] in 24 hour Urine | 0.937 |  |  0 |         0 |
| 40765224 | Urobilinogen [Presence] in Urine by Automated test strip | 0.937 |  |  0 |         0 |
| 3052141 | Buprenorphine+Norbuprenorphine [Presence] in Urine | 0.937 |  |  0 |         0 |
| 3010973 | Magnesium [Moles/time] in 4 hour Urine | 0.936 |  |  0 |         0 |
| 3033364 | Cholesterol [Mass/volume] in Pleural fluid | 0.936 |  |  0 |         0 |
| 3013561 | Magnesium [Moles/time] in 2 hour Urine | 0.935 |  |  0 |         0 |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.934 |  |  0 |         0 |
| 3000566 | Arsenic [Mass/volume] in Urine | 0.934 |  |  0 |         0 |
| 3023399 | Thyrotropin [Units/volume] in Blood | 0.933 |  |  0 |         0 |
| 3032333 | Phosphate [Mass or Moles] in 24 hour Urine | 0.931 |  |  2 |       118 |
| 3028531 | Enolase.neuron specific [Mass/volume] in Serum or Plasma | 0.930 |  |  3 |    10,290 |
| 3007771 | Amphetamines [Presence] in Specimen | 0.930 |  |  0 |         0 |
| 3013542 | traMADol [Presence] in Urine by Screen method | 0.930 | 1539 |  0 |         0 |
| 3008724 | Arsenic [Moles/volume] in Urine | 0.929 |  |  0 |         0 |
| 3009672 | Porphobilinogen [Presence] in 24 hour Urine | 0.929 |  |  0 |         0 |
| 3023533 | Arsenic [Presence] in Urine | 0.929 |  |  0 |         0 |
| 36032133 | Arsenic.inorganic+methylated [Mass/volume] in Urine | 0.929 |  |  0 |         0 |
| 648579 | Nickel [Measurement] in Urine | 0.927 |  |  0 |         0 |
| 3013666 | Nickel [Mass/volume] in Urine collected for unspecified duration | 0.927 |  |  0 |         0 |
| 3012636 | Phosphate [Mass/time] in 24 hour Urine | 0.926 |  |  0 |         0 |
| 3009272 | traMADol [Presence] in Urine by Confirmatory method | 0.925 |  |  0 |         0 |
| 3030540 | Arsenic organic [Moles/volume] in Urine | 0.925 |  |  0 |         0 |
| 3008769 | Porphobilinogen [Moles/volume] in Serum or Plasma | 0.925 |  |  0 |         0 |
| 3018601 | Magnesium [Mass/time] in 24 hour Urine | 0.924 |  |  0 |         0 |
| 3008254 | Cholesterol esters [Mass/volume] in Serum or Plasma | 0.923 |  |  0 |         0 |
| 3011787 | Mercury [Presence] in 24 hour Urine | 0.922 |  |  0 |         0 |
| 40758961 | Cholesterol esters [Moles/volume] in Serum or Plasma | 0.922 |  |  0 |         0 |
| 3038918 | Arsenic organic [Mass/volume] in Urine | 0.922 |  |  0 |         0 |
| 40762735 | fentaNYL [Presence] in Urine by Screen method | 0.922 |  |  0 |         0 |
| 3015116 | Methadone [Presence] in Specimen | 0.922 |  |  0 |         0 |
| 3011450 | Thyrotropin [Presence] in Blood | 0.921 |  |  0 |         0 |
| 1260020 | traMADol [Presence] in Serum or Plasma | 0.920 |  |  0 |         0 |
| 3002752 | Chloride [Moles/volume] in 24 hour Urine | 0.920 |  |  0 |         0 |
| 3045942 | Benzodiazepines [Presence] in Specimen | 0.918 |  |  0 |         0 |
| 3019652 | Selenium [Mass/volume] in Serum or Plasma | 0.918 |  |  0 |         0 |
| 645171 | Arsenic.inorganic [Measurement] in Urine | 0.917 |  |  0 |         0 |
| 3001420 | Magnesium [Mass/volume] in Serum or Plasma | 0.917 |  |  0 |         0 |
| 647560 | Vasoactive intestinal peptide [Measurement] in Serum or Plasma | 0.916 |  |  0 |         0 |
| 3008477 | fentaNYL [Presence] in Serum or Plasma | 0.916 |  |  0 |         0 |
| 40757494 | Bilirubin.total [Moles/volume] in Blood | 0.915 |  |  3 |     4,674 |
| 3042522 | Arsenic.inorganic [Mass/time] in 24 hour Urine | 0.915 |  |  0 |         0 |
| 3017750 | Porphobilinogen [Mass/volume] in Urine | 0.914 |  |  0 |         0 |
| 3046897 | Bilirubin.total [Presence] in Specimen | 0.913 |  |  0 |         0 |
| 3010391 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in Urine | 0.913 | 1140 |  0 |         0 |
| 3019738 | Magnesium [Mass/volume] in Urine | 0.912 |  |  0 |         0 |
| 3042448 | fentaNYL [Presence] in Urine by Confirmatory method | 0.912 |  |  0 |         0 |
| 3023022 | Amphetaminil [Presence] in Urine | 0.911 |  |  0 |         0 |
| 44816594 | Magnesium [Moles/volume] in 12 hour Urine | 0.911 |  |  0 |         0 |
| 1001926 | Buprenorphine [Presence] in Urine by Screen method | 0.911 |  |  1 |    44,133 |
| 3030477 | Bilirubin.total [Presence] in Urine by Automated test strip | 0.909 |  |  0 |         0 |
| 21491252 | Selenium [Moles/volume] in Blood | 0.909 |  |  0 |         0 |
| 3001308 | Cholesterol in LDL [Moles/volume] in Serum or Plasma | 0.908 | 92 | 47 | 2,347,979 |
| 3021197 | Magnesium Ionized [Moles/volume] in Serum or Plasma | 0.908 |  |  1 |     4,652 |
| 3007070 | Cholesterol in HDL [Mass/volume] in Serum or Plasma | 0.908 |  |  0 |         0 |
| 3007110 | Nickel [Moles/time] in 24 hour Urine | 0.908 |  |  0 |         0 |
| 3044929 | Cholesterol.in chylomicrons [Mass/volume] in Serum or Plasma | 0.908 |  |  0 |         0 |
| 3024145 | Nickel [Mass/time] in 24 hour Urine | 0.908 |  |  0 |         0 |
| 647106 | Designer benzodiazepines [Presence] in Urine | 0.908 |  |  0 |         0 |
| 36031403 | Arsenic.inorganic+methylated [Mass/volume] in 24 hour Urine | 0.907 |  |  0 |         0 |
| 3029187 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma | 0.907 | 516 | 57 |   390,599 |
| 3004454 | Aluminum [Mass/volume] in Urine | 0.906 |  |  0 |         0 |
| 3030977 | Arsenic.inorganic [Moles/time] in 24 hour Urine | 0.906 |  |  0 |         0 |
| 3023602 | Cholesterol in HDL [Moles/volume] in Serum or Plasma | 0.905 | 38 | 41 | 2,024,003 |
| 3024128 | Bilirubin.total [Mass/volume] in Serum or Plasma | 0.905 |  |  0 |         0 |
| 40760458 | Chloride [Moles/volume] in 12 hour Urine | 0.904 |  |  0 |         0 |
| 3014603 | Buprenorphine [Presence] in Urine by Confirmatory method | 0.903 |  |  0 |         0 |
| 3045267 | Arsenic organic [Mass/volume] in 24 hour Urine | 0.903 |  |  0 |         0 |
| 3026729 | Phosphate [Mass/volume] in Urine | 0.903 |  |  0 |         0 |
| 3036768 | Bilirubin.total [Moles/volume] in Specimen | 0.902 |  |  0 |         0 |
| 3006843 | Mercury [Mass/volume] in Urine | 0.902 |  |  0 |         0 |
| 3044963 | Bilirubin.total [Presence] in 24 hour Urine by Test strip | 0.902 |  |  0 |         0 |
| 44787075 | Cholestanol [Moles/volume] in Serum or Plasma | 0.902 |  |  0 |         0 |
| 3020207 | Porphobilinogen [Moles/time] in 24 hour Urine | 0.902 |  |  0 |         0 |
| 3013120 | Amphetamines [Presence] in Serum or Plasma | 0.901 |  |  0 |         0 |
| 3035806 | Cholesterol.in chylomicrons [Presence] in Serum or Plasma | 0.901 |  |  0 |         0 |
| 3015768 | Cholestanol [Mass/volume] in Serum or Plasma | 0.900 |  |  0 |         0 |
| 3031569 | Natriuretic peptide B [Mass/volume] in Blood | 0.900 | 847 |  0 |         0 |
| 3028437 | Cholesterol in LDL [Mass/volume] in Serum or Plasma | 0.900 |  |  0 |         0 |
| 3052295 | Natriuretic peptide B [Moles/volume] in Serum or Plasma | 0.899 |  |  0 |         0 |
| 3016735 | Thyrotropin Ab [Units/volume] in Serum | 0.898 |  |  0 |         0 |
| 3007682 | Benzodiazepines [Presence] in Urine by Screen method | 0.898 | 1307 |  0 |         0 |
| 40757504 | Cholesterol.non-esterified [Moles/volume] in Serum or Plasma | 0.898 |  |  0 |         0 |
| 646953 | Natriuretic peptide B [Measurement] in Serum or Plasma | 0.898 |  |  0 |         0 |
| 3045767 | Arsenic [Moles/volume] in 24 hour Urine | 0.897 |  |  0 |         0 |
| 3035732 | Benzodiazepines [Presence] in Urine by Confirmatory method | 0.897 | 1915 |  0 |         0 |
| 40762260 | Phosphate [Moles/time] in 24 hour Stool | 0.896 |  |  0 |         0 |
| 645697 | fentaNYL [Measurement] in Urine | 0.896 |  |  0 |         0 |
| 3028064 | Tetrahydrocannabinol [Presence] in Urine | 0.895 | 368 |  0 |         0 |
| 3017388 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in 24 hour Urine | 0.895 |  |  0 |         0 |
| 3011884 | Cholesterol in HDL [Presence] in Serum or Plasma | 0.895 |  |  0 |         0 |
| 3044552 | Amphetamine+Methamphetamine [Presence] in Urine | 0.895 |  |  0 |         0 |
| 1175183 | Bilirubin.total [Moles/volume] in Arterial blood | 0.894 |  |  0 |         0 |
| 40760459 | Chloride [Moles/volume] in 2 hour Urine | 0.894 |  |  0 |         0 |
| 3037072 | Urobilinogen [Mass/volume] in Urine by Test strip | 0.894 |  |  0 |         0 |
| 3006363 | Amphetamines [Presence] in Urine by Confirmatory method | 0.894 |  |  0 |         0 |
| 3023596 | Amphetamines [Presence] in Urine by Screen method | 0.894 | 1508 |  0 |         0 |
| 3022487 | Cholesterol in VLDL [Moles/volume] in Serum or Plasma | 0.894 | 219 |  0 |         0 |
| 3044171 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in Urine by Immunoassay | 0.894 |  |  0 |         0 |
| 3027700 | Thyrotropin [Units/volume] in Serum or Plasma --baseline | 0.893 |  |  0 |         0 |
| 44817191 | Cholesterol sulfate [Moles/volume] in Serum or Plasma | 0.893 |  |  0 |         0 |
| 3013830 | Methadone [Presence] in Urine by Confirmatory method | 0.892 |  |  0 |         0 |
| 3016450 | Mercury [Mass/volume] in Blood | 0.892 |  |  0 |         0 |
| 3041096 | Erythrocytes [Presence] in Urine by Automated | 0.892 |  |  3 |   431,124 |
| 3025776 | Phosphate [Mass/volume] in 24 hour Urine | 0.892 |  |  0 |         0 |
| 21491001 | Cholesterol [Moles/volume] in Pericardial fluid | 0.891 |  |  0 |         0 |
| 3007755 | Magnesium [Moles/time] in 24 hour Stool | 0.891 |  |  0 |         0 |
| 3015559 | Thyrotropin.long acting [Presence] in Serum or Plasma | 0.891 |  |  0 |         0 |
| 3046030 | Erythrocytes [Presence] in Urine sediment by Light microscopy | 0.890 |  |  0 |         0 |
| 40758436 | Fungus [Presence] in Vaginal fluid by KOH preparation | 0.890 |  |  0 |         0 |
| 3006828 | Magnesium [Mass/volume] in 24 hour Urine | 0.890 |  |  0 |         0 |
| 3049873 | Cholesterol [Mass/volume] in Serum or Plasma ultracentrifugate | 0.890 |  |  0 |         0 |
| 1175191 | Bilirubin.total [Moles/volume] in Venous blood | 0.890 |  |  0 |         0 |
| 645740 | traMADol [Measurement] in Urine | 0.890 |  |  0 |         0 |
| 3031951 | Benzodiazepines [Presence] in Blood | 0.889 |  |  0 |         0 |
| 3035048 | Amphetamines [Presence] in Urine by SAMHSA screen method | 0.889 |  |  0 |         0 |
| 40760485 | Enolase.neuron specific [Mass/volume] in Serum or Plasma by Immunoassay | 0.889 |  |  0 |         0 |
| 3006567 | Chloride [Moles/time] in 24 hour Urine | 0.888 |  |  2 |        93 |
| 647250 | Thyrotropin [Measurement] in Serum or Plasma | 0.888 |  |  0 |         0 |
| 3035067 | Mercury [Moles/time] in 24 hour Urine | 0.888 |  |  0 |         0 |
| 646694 | Magnesium [Measurement] in Serum or Plasma | 0.888 |  |  0 |         0 |
| 3015548 | Cholesterol [Moles/volume] in Specimen | 0.888 |  |  0 |         0 |
| 3028707 | Methadone [Presence] in Urine by Screen method | 0.887 | 629 |  1 |    31,091 |
| 3006459 | Amphetamines [Presence] in Stool | 0.887 |  |  0 |         0 |
| 645821 | Cholesterol [Measurement] in Serum or Plasma | 0.887 |  |  0 |         0 |
| 647935 | Buprenorphine [Measurement] in Urine | 0.887 |  |  0 |         0 |
| 3045170 | Collagen crosslinked N-telopeptide/Creatinine [Ratio] in Urine | 0.887 |  |  0 |         0 |
| 3010879 | Iodine [Mass/volume] in 24 hour Urine | 0.887 |  |  0 |         0 |
| 3012728 | Benzodiazepines [Presence] in Serum or Plasma | 0.886 | 536 |  0 |         0 |
| 3015541 | Arsenic [Presence] in 24 hour Urine | 0.885 |  |  0 |         0 |
| 3043347 | Bilirubin.direct [Presence] in Serum or Plasma | 0.885 |  |  0 |         0 |
| 3028195 | Cholesterol.non-esterified [Mass/volume] in Serum or Plasma | 0.885 |  |  0 |         0 |
| 3023323 | Follitropin [Units/volume] in Serum or Plasma | 0.885 | 230 | 11 |    37,598 |
| 3032051 | Urobilinogen [Moles/volume] in Urine by Test strip | 0.884 | 117 |  0 |         0 |
| 645769 | Porphobilinogen/Creatinine [Measurement] in Urine | 0.884 |  |  0 |         0 |
| 3019025 | Thyrotropin.long acting [Units/volume] in Serum or Plasma | 0.884 |  |  0 |         0 |
| 40757502 | Cholesterol [Moles/volume] in Peritoneal fluid | 0.883 |  |  0 |         0 |
| 647156 | Mercury [Measurement] in Urine | 0.883 |  |  0 |         0 |
| 645629 | Porphobilinogen [Measurement] in Urine | 0.882 |  |  0 |         0 |
| 3033836 | Magnesium [Moles/volume] in Blood | 0.882 |  |  0 |         0 |
| 3006473 | Urobilinogen [Units/volume] in Urine by Test strip | 0.882 | 170 |  0 |         0 |
| 3004338 | Enolase.neuron specific [Units/volume] in Serum or Plasma | 0.882 |  |  0 |         0 |
| 21493398 | Phosphate [Moles/volume] in Urine collected for unspecified duration | 0.882 |  |  0 |         0 |
| 40766096 | Thyrotropin receptor Ab [Units/volume] in Cord blood | 0.881 |  |  0 |         0 |
| 3007785 | fentaNYL [Mass/volume] in Urine | 0.881 |  |  0 |         0 |
| 3042993 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in 24 hour Urine by Immunoassay | 0.881 |  |  0 |         0 |
| 3036649 | Aluminum [Moles/time] in 24 hour Urine | 0.879 |  |  0 |         0 |
| 21492215 | traMADol [Presence] in Blood by Confirmatory method | 0.879 |  |  0 |         0 |
| 3005772 | Bilirubin.conjugated [Moles/volume] in Serum or Plasma | 0.879 |  | 11 |   150,241 |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.878 |  |  0 |         0 |
| 40760482 | Magnesium [Mass/time] in 12 hour Urine | 0.878 |  |  0 |         0 |
| 1469998 | Natriuretic peptide B [Mass/volume] adjusted for eGFR in Serum or Plasma | 0.878 |  |  0 |         0 |
| 3027641 | Methadone [Presence] in Stool | 0.876 |  |  0 |         0 |
| 3034832 | Methadone [Presence] in Serum or Plasma | 0.876 |  |  0 |         0 |
| 3016360 | Urobilinogen [Presence] in Urine | 0.875 |  |  0 |         0 |
| 647235 | Benzodiazepines [Measurement] in Urine | 0.875 |  |  0 |         0 |
| 3011258 | Bilirubin.total [Presence] in Urine | 0.874 | 621 |  0 |         0 |
| 649466 | Bilirubin.total [Measurement] in Serum or Plasma | 0.873 |  |  0 |         0 |
| 3020768 | Bilirubin.delta [Moles/volume] in Serum or Plasma | 0.873 |  |  0 |         0 |
| 3052927 | Bilirubin.total [Moles/volume] in Cord blood | 0.873 |  |  0 |         0 |
| 3015021 | Porphobilinogen [Mass/volume] in 24 hour Urine | 0.873 |  |  0 |         0 |
| 3053321 | Collagen crosslinked C-telopeptide/Creatinine [Ratio] in Urine | 0.873 |  |  0 |         0 |
| 3045817 | Iodide [Mass/volume] in Specimen | 0.872 |  |  0 |         0 |
| 40761460 | Buprenorphine+Norbuprenorphine [Presence] in Urine by Screen method | 0.872 |  |  0 |         0 |
| 3029985 | Thyrotropin [Units/volume] in Serum or Plasma --1st specimen | 0.872 |  |  0 |         0 |
| 3015834 | Enolase.neuron specific [Enzymatic activity/volume] in Serum or Plasma | 0.872 |  |  0 |         0 |
| 1469798 | Fungus identified in Vaginal fluid by Culture | 0.872 |  |  0 |         0 |
| 3029052 | Nickel [Mass/volume] in Body fluid | 0.871 |  |  0 |         0 |
| 3006513 | Bilirubin.total [Mass/volume] in Urine by Test strip | 0.870 |  |  0 |         0 |
| 648856 | Aluminum [Measurement] in Urine | 0.870 |  |  0 |         0 |
| 1092378 | Norbuprenorphine [Presence] in Urine | 0.869 |  |  0 |         0 |
| 3041537 | Cholesterol [Moles/volume] in Synovial fluid | 0.869 |  |  0 |         0 |
| 42529510 | Buprenorphine [Presence] in Specimen by Screen method | 0.869 |  |  0 |         0 |
| 3004201 | Nickel [Mass/volume] in Blood | 0.869 |  |  0 |         0 |
| 3007953 | Mercury [Mass/volume] in 24 hour Urine | 0.869 |  |  0 |         0 |
| 3030198 | Thyrotropin [Units/volume] in Serum or Plasma --5th specimen | 0.869 |  |  0 |         0 |
| 3032482 | Selenium [Moles/volume] in Urine | 0.868 |  |  0 |         0 |
| 21492216 | traMADol [Presence] in Blood by Screen method | 0.868 |  |  0 |         0 |
| 3028638 | Bilirubin.direct [Moles/volume] in Serum or Plasma | 0.868 | 82 |  0 |         0 |
| 3007437 | Mercury [Moles/volume] in Serum or Plasma | 0.868 |  |  0 |         0 |
| 648045 | Methadone [Measurement] in Urine | 0.867 |  |  0 |         0 |
| 3047203 | Thyrotropin [Units/volume] in Serum or Plasma --1 hour post dose TRH | 0.866 |  |  0 |         0 |
| 3030538 | Thyrotropin [Units/volume] in Serum or Plasma --4th specimen | 0.866 |  |  0 |         0 |
| 40761480 | fentaNYL+Norfentanyl [Presence] in Urine by Screen method | 0.866 |  |  0 |         0 |
| 3037311 | Chloride [Moles/volume] in Urine collected for unspecified duration | 0.866 | 997 |  0 |         0 |
| 3008429 | Aluminum [Mass/volume] in 24 hour Urine | 0.865 |  |  0 |         0 |
| 3017733 | Nickel [Moles/volume] in Blood | 0.865 |  |  0 |         0 |
| 3046816 | Methadone [Presence] in Meconium | 0.865 |  |  0 |         0 |
| 21494503 | Aluminum [Moles/volume] in Body fluid | 0.865 |  |  0 |         0 |
| 3044908 | Iodine [Moles/volume] in Urine | 0.864 |  |  0 |         0 |
| 43533958 | fentaNYL [Presence] in Blood by Screen method | 0.864 |  |  0 |         0 |
| 3003341 | Magnesium [Presence] in Blood | 0.864 |  |  0 |         0 |
| 1469855 | Buprenorphine [Presence] in Hair | 0.863 |  |  0 |         0 |
| 1001641 | Benzodiazepines panel [Presence] - Urine by Screen method | 0.863 |  |  0 |         0 |
| 40760492 | Porphyrins/Creatinine [Molar ratio] in Urine | 0.862 |  |  0 |         0 |
| 42529224 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma by Immunoassay | 0.862 |  |  0 |         0 |
| 648637 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Immunoassay | 0.862 |  |  0 |         0 |
| 40768058 | Magnesium [Moles/volume] corrected for albumin in Serum or Plasma | 0.862 |  |  0 |         0 |
| 646976 | Magnesium [Measurement] in Urine | 0.862 |  |  0 |         0 |
| 3045256 | Bilirubin.total [Presence] in Body fluid | 0.861 |  |  0 |         0 |
| 3009024 | Chloride [Moles/volume] in Specimen | 0.860 |  |  0 |         0 |
| 3032069 | Thyrotropin Ab [Presence] in Serum | 0.860 |  |  0 |         0 |
| 40758052 | Phosphate [Mass/time] in 12 hour Urine | 0.860 |  |  0 |         0 |
| 40760460 | Chloride [Moles/time] in 12 hour Urine | 0.860 |  |  0 |         0 |
| 3034662 | Methadone+Metabolite [Presence] in Urine by Screen method | 0.860 |  |  0 |         0 |
| 3029435 | Natriuretic peptide.B prohormone N-Terminal [Moles/volume] in Serum or Plasma | 0.860 |  |  0 |         0 |
| 40768812 | fentaNYL+Norfentanyl [Presence] in Urine by Confirmatory method | 0.859 |  |  0 |         0 |
| 3041012 | Bilirubin.total [Moles/volume] in Urine by Test strip | 0.859 | 907 |  0 |         0 |
| 42528608 | Aluminum [Moles/volume] in Blood | 0.859 |  |  0 |         0 |
| 3004208 | Mercury [Presence] in Urine by Visual.Reinsch | 0.858 |  |  0 |         0 |
| 36660507 | Chloride [Moles/volume] in Urine from Fetus | 0.857 |  |  0 |         0 |
| 3030803 | Mercury [Moles/volume] in Red Blood Cells | 0.857 |  |  0 |         0 |
| 42870364 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Blood by Immunoassay | 0.857 |  |  0 |         0 |
| 3015271 | Benzodiazepines [Presence] in Stool | 0.857 |  |  0 |         0 |
| 3039169 | Iodine [Mass/volume] in Urine collected for unspecified duration | 0.856 |  |  0 |         0 |
| 3045969 | Collagen crosslinked N-telopeptide/Creatinine [Molar ratio] in Specimen by Immunoassay | 0.855 |  |  0 |         0 |
| 646713 | Arsenic organic [Measurement] in Urine | 0.854 |  |  0 |         0 |
| 3012310 | Bilirubin.total [Moles/volume] in Body fluid | 0.854 | 1909 |  0 |         0 |
| 42529215 | Follitropin [Units/volume] in Serum or Plasma by Immunoassay | 0.854 |  |  3 |    10,461 |
| 1001608 | traMADol [Presence] in Meconium by Screen method | 0.853 |  |  0 |         0 |
| 3025665 | Magnesium [Moles/volume] in Specimen | 0.852 |  |  0 |         0 |
| 1175818 | Buprenorphine-3-glucuronide [Presence] in Urine by Screen method | 0.851 |  |  0 |         0 |
| 3013294 | Phosphate [Moles/volume] in Specimen | 0.850 |  |  0 |         0 |
| 647727 | Enolase.neuron specific [Measurement] in Serum or Plasma | 0.850 |  |  0 |         0 |
| 3049473 | Enolase.neuron specific [Mass/volume] in Serum or Plasma by Radioimmunoassay (RIA) | 0.849 |  |  0 |         0 |
| 3009803 | traMADol [Mass/volume] in Urine | 0.849 |  |  0 |         0 |
| 44786767 | traMADol [Presence] in Saliva (oral fluid) by Screen method | 0.849 |  |  0 |         0 |
| 648631 | Collagen crosslinked N-telopeptide/Creatinine [Measurement] in Urine | 0.848 |  |  0 |         0 |
| 3014814 | Methamphetamine [Presence] in Urine | 0.848 | 634 |  0 |         0 |
| 3011570 | Cholesterol [Moles/volume] in Body fluid | 0.847 |  |  0 |         0 |
| 3001260 | Chloride [Moles/volume] in Stool | 0.847 |  |  0 |         0 |
| 649308 | Natriuretic peptide.B prohormone N-Terminal [Measurement] in Serum or Plasma | 0.847 |  |  0 |         0 |
| 3044637 | Erythrocytes [Presence] in Body fluid | 0.846 |  |  0 |         0 |
| 3039627 | Selenium [Moles/volume] in Red Blood Cells | 0.846 |  |  0 |         0 |
| 40761551 | Bilirubin [Presence] in Urine by Confirmatory method | 0.846 |  |  0 |         0 |
| 40762759 | Iodide [Mass/volume] in Serum or Plasma | 0.845 |  |  0 |         0 |
| 3019364 | Iodine Free [Mass/volume] in Urine | 0.845 |  |  0 |         0 |
| 40762088 | Magnesium [Mass/time] in 18 hour Urine | 0.845 |  |  0 |         0 |
| 3048773 | Triglyceride [Moles/volume] in Serum or Plasma --fasting | 0.844 |  | 17 | 1,655,520 |
| 3042811 | Magnesium Ionized [Mass/volume] in Serum or Plasma | 0.844 |  |  0 |         0 |
| 3044458 | Uroporphyrin/Creatinine [Molar ratio] in Urine | 0.844 |  |  0 |         0 |
| 3008034 | Magnesium [Moles/volume] in Stool | 0.843 |  |  0 |         0 |
| 3034884 | Cholesterol. in Lipoprotein (a) [Presence] in Serum or Plasma | 0.841 |  |  0 |         0 |
| 3043714 | Erythrocytes [Presence] in Stool | 0.841 |  |  0 |         0 |
| 3018913 | Phosphate [Moles/volume] in Blood | 0.841 |  |  0 |         0 |
| 3018479 | Urobilinogen [Presence] in Stool | 0.841 |  |  0 |         0 |
| 40762254 | Phosphate [Moles/volume] in Stool | 0.840 |  |  0 |         0 |
| 42868678 | Cholesterol non HDL [Moles/volume] in Serum or Plasma | 0.839 | 289 |  3 |    66,002 |
| 3024183 | Urobilinogen [Presence] in 24 hour Urine | 0.839 |  |  0 |         0 |
| 44787076 | Cholestanol/Cholesterol in Serum or Plasma | 0.839 |  |  0 |         0 |
| 645251 | Iodine [Measurement] in Urine | 0.837 |  |  0 |         0 |
| 40759058 | Magnesium [Moles/volume] in Serum or Plasma --post dialysis | 0.836 |  |  0 |         0 |
| 3014038 | Collagen crosslinked N-telopeptide [Moles/volume] in Urine | 0.835 | 1419 |  2 |     1,030 |
| 3034536 | Mercury [Moles/volume] in Saliva (oral fluid) | 0.835 |  |  0 |         0 |
| 40760481 | Magnesium [Mass/volume] in 12 hour Urine | 0.835 |  |  0 |         0 |
| 3029870 | Urobilinogen [Mass/volume] in Urine by Automated test strip | 0.835 |  |  0 |         0 |
| 646012 | Chloride [Measurement] in Urine | 0.835 |  |  0 |         0 |
| 1988692 | Mercury [Moles/volume] in Cerebral spinal fluid | 0.835 |  |  0 |         0 |
| 3044002 | Follitropin and Lutropin panel [Units/volume] - Serum or Plasma | 0.834 |  |  0 |         0 |
| 3032467 | Bilirubin+Urobilinogen [Presence] in Urine | 0.834 |  |  0 |         0 |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 0.833 |  |  6 | 1,393,084 |
| 3022621 | pH of Urine by Test strip | 0.833 | 59 | 17 |    92,206 |
| 3000578 | Aluminum [Moles/volume] in Serum or Plasma | 0.833 |  |  0 |         0 |
| 3037823 | Phosphate [Presence] in Stool | 0.832 |  |  0 |         0 |
| 3015597 | Iodine [Mass/time] in 24 hour Urine | 0.832 |  |  0 |         0 |
| 3026014 | Mg Ab [Presence] in Serum or Plasma | 0.832 |  |  0 |         0 |
| 3044590 | Delta aminolevulinate [Moles/volume] in Urine | 0.831 |  |  1 |        31 |
| 3049111 | Enolase.neuron specific [Mass/volume] in Body fluid | 0.831 |  |  0 |         0 |
| 3024733 | Bilirubin.total [Presence] in Stool | 0.831 |  |  0 |         0 |
| 3040519 | Bilirubin.total [Mass/volume] in Urine by Automated test strip | 0.830 |  |  0 |         0 |
| 1988603 | Mercury [Moles/volume] in Milk | 0.830 |  |  0 |         0 |
| 3041858 | Mercury [Presence] in Hair | 0.830 |  |  0 |         0 |
| 3003501 | Porphobilinogen [Mass/time] in 24 hour Urine | 0.830 |  |  0 |         0 |
| 3036941 | Urinalysis complete panel - Urine | 0.829 |  |  0 |         0 |
| 3028833 | Bilirubin.total [Mass/volume] in Blood | 0.829 |  |  0 |         0 |
| 21491387 | Aluminum [Moles/volume] in Water | 0.829 |  |  0 |         0 |
| 42529225 | Natriuretic peptide.B prohormone N-Terminal [Moles/volume] in Serum or Plasma by Immunoassay | 0.829 |  |  0 |         0 |
| 3015711 | Magnesium [Moles/volume] in Body fluid | 0.828 |  |  0 |         0 |
| 648311 | Phosphate [Measurement] in Urine | 0.828 |  |  0 |         0 |
| 3044942 | Collagen crosslinked N-telopeptide [Mass/volume] in Urine | 0.827 |  |  0 |         0 |
| 1617351 | Hexacarboxylporphyrin/Creatinine [Molar ratio] in Urine | 0.827 |  |  0 |         0 |
| 40760465 | Phosphate [Mass/volume] in 12 hour Urine | 0.825 |  |  0 |         0 |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.824 |  |  0 |         0 |
| 3034076 | Specific gravity of 24 hour Urine | 0.823 |  |  0 |         0 |
| 42528824 | Thyrotropin receptor Ab [Presence] in Serum | 0.823 |  |  0 |         0 |
| 3011306 | Selenium [Mass/volume] in Blood | 0.822 |  |  0 |         0 |
| 40760466 | Phosphate [Mass/volume] in 2 hour Urine | 0.821 |  |  0 |         0 |
| 42868673 | Bilirubin.total [Moles/volume] in Urine | 0.820 | 171 |  0 |         0 |
| 648230 | Collagen crosslinked N-telopeptide [Measurement] in Urine | 0.820 |  |  0 |         0 |
| 3035821 | Porphyrins/Creatinine [Mass Ratio] in Urine | 0.820 |  |  0 |         0 |
| 3002582 | Erythrocytes [#/volume] in Urine | 0.819 |  | 12 |   500,225 |
| 3004198 | Follitropin [Units/volume] in Serum or Plasma --baseline | 0.819 |  |  0 |         0 |
| 3019150 | Specific gravity of Urine by Refractometry | 0.819 |  | 16 |   426,435 |
| 647169 | Follitropin [Measurement] in Serum or Plasma | 0.818 |  |  0 |         0 |
| 40766095 | Thyrotropin receptor Ab [Units/volume] in Blood from Fetus | 0.818 |  |  0 |         0 |
| 3028300 | Cannabinoids [Presence] in Urine | 0.818 |  |  2 |    53,591 |
| 3031028 | Follitropin [Units/volume] in Serum or Plasma --1st specimen | 0.817 |  |  0 |         0 |
| 3009930 | Uroporphyrin/Creatinine [Molar ratio] in 24 hour Urine | 0.817 |  |  0 |         0 |
| 40762086 | Phosphate [Mass/time] in 18 hour Urine | 0.817 |  |  0 |         0 |
| 3017119 | Lipoproteins [Presence] in Serum or Plasma | 0.817 |  |  0 |         0 |
| 1469687 | pH of Urine by pH-meter | 0.817 |  |  0 |         0 |
| 3006361 | Follitropin [Units/volume] in Serum or Plasma by 2nd IRP | 0.816 |  |  0 |         0 |
| 1469712 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.816 |  |  0 |         0 |
| 3002651 | Cholesterol [Mass/volume] in Peritoneal fluid | 0.816 |  |  0 |         0 |
| 3029143 | Chylomicrons [Presence] in Pleural fluid | 0.816 |  |  0 |         0 |
| 3051266 | Erythrocytes.non-dysmorphic [Presence] in Urine sediment by Light microscopy | 0.815 |  |  0 |         0 |
| 3042779 | Enolase.neuron specific [Mass/volume] in Cerebral spinal fluid | 0.814 |  |  0 |         0 |
| 3006107 | Tetrahydrocannabinol [Presence] in Urine by SAMHSA screen method | 0.814 |  |  0 |         0 |
| 42868740 | Cholesterol in pleural fluid/Cholesterol in serum | 0.813 |  |  0 |         0 |
| 3048400 | Enolase.neuron specific [Mass/volume] in Cerebral spinal fluid by Immunoassay | 0.813 |  |  0 |         0 |
| 3029896 | Follitropin [Units/volume] in Serum or Plasma --5th specimen | 0.812 |  |  0 |         0 |
| 1092452 | Blood [Presence] in Urine | 0.812 |  |  0 |         0 |
| 3038345 | Erythrocytes.ghost cells [Presence] in Urine sediment by Light microscopy | 0.812 |  |  0 |         0 |
| 3033638 | Cholesterol in HDL [Presence] in Serum or Plasma by Electrophoresis | 0.812 |  |  0 |         0 |
| 3003071 | Tetrahydrocannabinol [Presence] in Urine by Confirmatory method | 0.812 |  |  0 |         0 |
| 646465 | Collagen crosslinked C-telopeptide [Measurement] in Urine | 0.811 |  |  0 |         0 |
| 3021973 | Delta aminolevulinate [Moles/volume] in 24 hour Urine | 0.811 |  |  0 |         0 |
| 3015962 | Follitropin.beta subunit [Moles/volume] in Serum or Plasma | 0.810 |  |  0 |         0 |
| 3011112 | Carboxy tetrahydrocannabinol [Presence] in Urine | 0.810 |  |  0 |         0 |
| 3000201 | Tetrahydrocannabinol [Presence] in Urine by Screen method | 0.810 | 933 |  0 |         0 |
| 40760031 | Cholesterol [Mass/volume] in Pericardial fluid | 0.810 |  |  0 |         0 |
| 1616626 | Enolase.neuron specific [Mass/volume] in Aspirate | 0.809 |  |  0 |         0 |
| 3012844 | Porphyrins [Presence] in Urine | 0.809 |  |  0 |         0 |
| 3025484 | Inhibin [Units/volume] in Serum or Plasma | 0.809 |  |  0 |         0 |
| 3007282 | Tetrahydrocannabinol [Presence] in Urine by SAMHSA confirm method | 0.808 |  |  0 |         0 |
| 3018646 | Tetrahydrocannabinol [Presence] in Urine by Screen method >50 ng/mL | 0.805 |  |  0 |         0 |
| 3040042 | pH of 4 hour Urine | 0.804 |  |  0 |         0 |
| 3019260 | Tetrahydrocannabinol [Presence] in Urine by Screen method >100 ng/mL | 0.803 |  |  0 |         0 |
| 3029287 | Urinalysis microscopic panel [#/volume] - Urine by Automated count | 0.803 |  |  3 |   557,289 |
| 3022817 | Tetrahydrocannabinol [Presence] in Urine by Screen method >20 ng/mL | 0.803 |  |  0 |         0 |
| 3001280 | Aluminum [Mass/time] in 24 hour Urine | 0.802 |  |  0 |         0 |
| 3041668 | Urinalysis microscopic panel [#/area] - Urine sediment by Automated count | 0.802 |  |  0 |         0 |
| 3001417 | Mercury [Mass/time] in 24 hour Urine | 0.802 |  |  0 |         0 |
| 3049183 | Collagen crosslinked C-telopeptide [Mass/volume] in Urine | 0.801 |  |  0 |         0 |
| 40758434 | Fungus [Presence] in Specimen by KOH preparation | 0.800 |  |  0 |         0 |
| 3012065 | Calcium [Presence] in Urine | 0.799 |  |  0 |         0 |
| 3019975 | Mercury [Mass/volume] in Red Blood Cells | 0.799 |  |  0 |         0 |
| 3021832 | Aluminum [Mass/volume] in Urine collected for unspecified duration | 0.798 |  |  0 |         0 |
| 43533580 | Thyroxine (T4) free [Mass/volume] in Cord blood | 0.797 |  |  0 |         0 |
| 3001560 | Silver [Moles/volume] in Serum or Plasma | 0.797 |  |  0 |         0 |
| 3013204 | Bilirubin.total [Presence] in Amniotic fluid | 0.797 |  |  0 |         0 |
| 3028612 | Thyroperoxidase Ab [Presence] in Serum or Plasma | 0.796 |  |  0 |         0 |
| 3029305 | pH of Urine by Automated test strip | 0.796 |  |  0 |         0 |
| 40758442 | Yeast [Presence] in Vaginal fluid by KOH preparation | 0.795 |  |  0 |         0 |
| 40758334 | Vasoactive intestinal peptide [Mass/volume] in Cerebral spinal fluid | 0.795 |  |  0 |         0 |
| 3035138 | Selenium [Mass/volume] in Specimen | 0.794 |  |  0 |         0 |
| 3030688 | Urinalysis panel - Urine by Automated | 0.794 |  |  0 |         0 |
| 3051822 | Thyroxine (T4) Ab [Presence] in Serum | 0.790 |  |  0 |         0 |
| 40758991 | Choriogonadotropin [Units/volume] in Cord blood | 0.790 |  |  0 |         0 |
| 3013590 | Selenium [Mass/volume] in Body fluid | 0.790 |  |  0 |         0 |
| 40761130 | Selenium [Mass/volume] in Nonbiological fluid | 0.789 |  |  0 |         0 |
| 3005711 | Thyrotropin.beta subunit [Mass/volume] in Serum or Plasma | 0.789 |  |  0 |         0 |
| 3037024 | Collagen crosslinked N-telopeptide [Moles/volume] in 24 hour Urine | 0.787 |  |  0 |         0 |
| 3018329 | Vasoactive intestinal peptide [Mass/time] in 24 hour Urine | 0.786 |  |  0 |         0 |
| 3043812 | Specific gravity of 24 hour Urine by Refractometry | 0.786 |  |  0 |         0 |
| 40761054 | Collagen crosslinked C-telopeptide [Mass/volume] in 24 hour Urine | 0.786 |  |  0 |         0 |
| 3015501 | pH of 24 hour Urine | 0.786 |  |  0 |         0 |
| 3035265 | Fatty acids [Presence] in Pleural fluid | 0.784 |  |  0 |         0 |
| 40762259 | Bilirubin.total [Moles/time] in 24 hour Stool | 0.783 |  |  0 |         0 |
| 3036187 | Delta aminolevulinate [Mass/volume] in Urine | 0.783 |  |  0 |         0 |
| 40758441 | Yeast.pseudohyphae [Presence] in Vaginal fluid by KOH preparation | 0.782 |  |  0 |         0 |
| 3003007 | Microscopic observation [Identifier] in Vaginal fluid by KOH preparation | 0.781 |  |  0 |         0 |
| 3041732 | Fungus identified in Genital specimen by Culture | 0.781 |  |  0 |         0 |
| 3004149 | Delta aminolevulinate [Moles/time] in 24 hour Urine | 0.780 |  |  0 |         0 |
| 3040160 | Chromium [Presence] in Urine | 0.780 |  |  0 |         0 |
| 40761501 | Specimen pH acceptable of Urine | 0.780 |  |  0 |         0 |
| 3044223 | Zinc [Presence] in Serum or Plasma | 0.779 |  |  0 |         0 |
| 1616488 | Thyroxine (T4) free [Moles/volume] in Cord blood | 0.779 |  |  1 |        12 |
| 1091400 | Fungus [Presence] in Tissue by KOH preparation | 0.779 |  |  0 |         0 |
| 3000330 | Specific gravity of Urine by Test strip | 0.777 | 71 |  4 |    71,773 |
| 3019091 | Magnesium [Mass/volume] in Urine collected for unspecified duration | 0.777 |  |  0 |         0 |
| 40761535 | Cells panel - Urine sediment | 0.777 |  |  5 |   111,359 |
| 3040007 | pH of 2 hour Urine | 0.775 |  |  0 |         0 |
| 3043489 | Iodine [Presence] in Serum or Plasma | 0.774 |  |  0 |         0 |
| 646354 | Mercury [Measurement] in Red Blood Cells | 0.774 |  |  0 |         0 |
| 3027465 | Chlorothiazide [Presence] in Urine | 0.774 |  |  0 |         0 |
| 3003191 | Choriogonadotropin [Presence] in Serum or Plasma | 0.773 | 615 |  3 |    28,800 |
| 3048422 | Vasoactive intestinal peptide Ag [Presence] in Tissue by Immune stain | 0.773 |  |  0 |         0 |
| 3039628 | Collagen crosslinked C-telopeptide [Mass/time] in 24 hour Urine | 0.772 |  |  0 |         0 |
| 3046619 | Specific gravity of Specimen | 0.771 |  |  0 |         0 |
| 3006772 | Delta aminolevulinate [Mass/volume] in 24 hour Urine | 0.771 |  |  0 |         0 |
| 3047703 | Bromide [Presence] in 24 hour Urine | 0.770 |  |  0 |         0 |
| 3028101 | Alanine [Moles/volume] in Urine | 0.770 |  |  0 |         0 |
| 40758433 | Fungus [Presence] in Sputum by KOH preparation | 0.769 |  |  0 |         0 |
| 3031015 | pH of 24 hour Urine by Test strip | 0.769 |  |  0 |         0 |
| 40758432 | Fungus [Presence] in Skin by KOH preparation | 0.768 |  |  0 |         0 |
| 648168 | Selenium [Measurement] in Urine | 0.768 |  |  0 |         0 |
| 3038854 | Inhibin B [Presence] in Serum or Plasma | 0.767 |  |  0 |         0 |
| 3036691 | Phosphate [Mass/volume] in Urine collected for unspecified duration | 0.766 |  |  0 |         0 |
| 3041519 | Chloride [Mass/time] in 24 hour Urine | 0.766 |  |  0 |         0 |
| 3009890 | Serine [Presence] in Serum or Plasma | 0.765 |  |  0 |         0 |
| 3022084 | Mg Ab [Presence] in Serum or Plasma from Blood product unit | 0.764 |  |  0 |         0 |
| 3037850 | Specific gravity of Body fluid | 0.763 |  |  0 |         0 |
| 3038556 | Heavy metals [Presence] in Urine | 0.762 |  |  0 |         0 |
| 3020324 | Cholesterol [Mass/volume] in Synovial fluid | 0.761 |  |  0 |         0 |
| 3009538 | Alpha aminoadipate [Moles/volume] in Urine | 0.761 |  |  0 |         0 |
| 649393 | Delta aminolevulinate [Measurement] in Urine | 0.760 |  |  0 |         0 |
| 3003972 | Lithium [Presence] in Serum or Plasma | 0.758 |  |  0 |         0 |
| 3039919 | Specific gravity of Urine by Automated test strip | 0.757 |  |  0 |         0 |
| 3003404 | hydroCHLOROthiazide [Presence] in Urine | 0.756 |  |  0 |         0 |
| 3038934 | Bilirubin.total [Presence] in Cerebral spinal fluid | 0.756 |  |  0 |         0 |
| 3044961 | Iodine.inorganic [Presence] in Serum or Plasma | 0.755 |  |  0 |         0 |
| 3041478 | Zinc [Presence] in Urine | 0.755 |  |  0 |         0 |
| 3048789 | Delta aminolevulinate [Moles/volume] in Serum | 0.754 |  |  0 |         0 |
| 3017228 | Iodine [Moles/volume] in 24 hour Urine | 0.751 |  |  0 |         0 |
| 3029991 | Specific gravity of Urine by Refractometry automated | 0.751 |  |  0 |         0 |
| 3026316 | Pyrroles [Mass/volume] in Urine | 0.751 |  |  0 |         0 |
| 3034788 | Alanine [Moles/volume] in 24 hour Urine | 0.750 |  |  0 |         0 |
| 3007745 | Inhibin A [Presence] in Serum or Plasma | 0.750 |  |  0 |         0 |
| 40758355 | Pancreatic polypeptide [Moles/volume] in Serum or Plasma | 0.749 |  |  4 |     1,603 |
| 3005123 | Arsenic [Presence] in Blood | 0.749 |  |  0 |         0 |
| 3032448 | Specific gravity of Urine by Adjustment to pH 7.4 | 0.748 |  |  0 |         0 |
| 3022851 | Hydroquinone [Mass/volume] in Urine | 0.747 |  |  0 |         0 |
| 3002176 | 4-Hydroxyphenylpyruvate [Presence] in Urine | 0.746 |  |  0 |         0 |
| 3046728 | Iron [Presence] in Serum or Plasma | 0.745 |  |  0 |         0 |
| 3009032 | Chloride [Molar amount] in Urine collected for unspecified duration | 0.745 |  |  0 |         0 |
| 3037884 | Follitropin/Lutropin [Molar ratio] in Serum or Plasma | 0.744 |  |  0 |         0 |
| 3012028 | 4-Hydroxyphenylacetate [Presence] in Urine | 0.744 |  |  0 |         0 |
| 3036188 | Follitropin.beta subunit [Mass/volume] in Serum or Plasma | 0.742 |  |  0 |         0 |
| 3022504 | Arsenic [Presence] in Serum or Plasma | 0.739 |  |  0 |         0 |
| 3025879 | Neuronal nuclear Ab [Presence] in Serum | 0.737 |  |  0 |         0 |
| 3010370 | Gastrin [Moles/volume] in Serum or Plasma | 0.735 |  |  3 |     1,342 |
| 21493544 | 4-Hydroxy 3-Nitrophenylacetate (HNPAA) [Mass/volume] in Urine | 0.730 |  |  0 |         0 |
| 3016312 | Uroporphyrin [Mass/volume] in Urine | 0.729 |  |  0 |         0 |
| 3027923 | C peptide [Moles/volume] in Serum or Plasma | 0.729 | 701 |  8 |     4,100 |
| 3032813 | Neuronal nuclear type 3 Ab [Presence] in Serum | 0.727 |  |  0 |         0 |
| 3002117 | Para nitrophenol [Mass/volume] in Urine | 0.727 |  |  0 |         0 |
| 3021497 | 2-Hydroxyphenylacetate [Presence] in Urine | 0.726 |  |  0 |         0 |
| 3045268 | 4-Hydroxybenzoate [Presence] in Urine | 0.724 |  |  0 |         0 |
| 3044720 | 4-Hydroxybenzoate [Presence] in 24 hour Urine | 0.724 |  |  0 |         0 |
| 3003347 | Nitrophenol [Presence] in Urine | 0.724 |  |  0 |         0 |
| 3037152 | Thyrotropin [Presence] in DBS | 0.724 | 3000 |  0 |         0 |
| 3001390 | Enolase.neuron specific Ag [Presence] in Tissue by Immune stain | 0.722 |  |  0 |         0 |
| 3034580 | 1-Naphthol [Mass/volume] in Urine | 0.717 |  |  0 |         0 |
| 3003290 | Para nitrophenol [Presence] in Urine | 0.717 |  |  0 |         0 |
| 3018672 | pH of Body fluid | 0.716 | 953 |  0 |         0 |
| 3007384 | Hexacarboxylporphyrin [Mass/volume] in Urine | 0.713 |  |  0 |         0 |
| 3037450 | 2-Hydroxyglutarate [Presence] in Urine | 0.712 |  |  0 |         0 |
| 40759645 | 5-Hydroxytryptophan [Mass/volume] in Urine | 0.711 |  |  0 |         0 |
| 3012954 | 3-Methoxy-4-Hydroxyphenylglycol [Mass/volume] in Urine | 0.710 |  |  0 |         0 |
| 3033331 | Uroporphyrin [Mass/volume] in 24 hour Urine | 0.710 |  |  0 |         0 |
| 3033431 | 1-Naphthol [Presence] in Urine | 0.708 |  |  0 |         0 |
| 3003880 | 4-Hydroxyphenyllactate [Presence] in Urine | 0.708 |  |  0 |         0 |
| 3004468 | Somatostatin [Presence] in Plasma | 0.693 |  |  0 |         0 |
| 3046092 | Insulin [Presence] in Serum or Plasma | 0.680 |  |  0 |         0 |
| 44787089 | Stone analysis panel | 0.677 |  |  0 |         0 |
| 3023245 | Trypsinogen [Presence] in Serum or Plasma | 0.672 |  |  0 |         0 |
| 3966464 | Crystals panel - Urine | 0.639 |  |  0 |         0 |
| 44816801 | Calcium oxalate dihydrate/Total in Stone | 0.636 |  |  0 |         0 |
| 1259860 | Renal calculus risk assessment [Likelihood] in 24 hour Urine Narrative | 0.632 |  |  0 |         0 |
| 3011937 | Urate/Total in Stone | 0.630 |  |  0 |         0 |
| 3034896 | Calcium oxalate monohydrate/Total in Stone | 0.628 |  |  0 |         0 |
| 40761534 | Crystals panel - Urine sediment | 0.623 |  |  0 |         0 |
| 3018665 | Calcium oxalate/Total in Stone | 0.619 |  |  0 |         0 |
| 3023690 | Calcium phosphate/Total in Stone | 0.612 |  |  0 |         0 |
| 3041947 | Urinalysis type of crystal panel [#/area] - Urine by Computer assisted method | 0.609 |  |  0 |         0 |
| 645117 | Mini nutritional assessment - short form 3 months Reported.MNA-SF | 0.576 |  |  0 |         0 |
| 649445 | Total score Reported.MNA-SF | 0.570 |  |  0 |         0 |
| 46236410 | Motor examination panel [UPDRS] | 0.530 |  |  0 |         0 |
| 21491091 | Applied cognitive score [AM-PAC] | 0.523 |  |  0 |         0 |
| 40765501 | PhenX - global mental status - adult protocol 130701 | 0.523 |  |  0 |         0 |
| 42528546 | Picture Sequence Memory Test - computed score [NIH Toolbox] | 0.519 |  |  0 |         0 |
| 42528548 | Picture Sequence Memory Test - raw score [NIH Toolbox] | 0.517 |  |  0 |         0 |
| 46236408 | Mentation, behavior and mood panel [UPDRS] | 0.513 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 587 | -bil | umol/l | 433 | 0 | [8.08, 11.42, 17.8, 24.81, 35.56, 52.32, 88.15, 166.34, 422.22] | -Bilirubiini |  |  | Bilirubin.total [Moles/volume] in Serum or Plasma | FALSE |
| 588 | -bil |  | 85 | 95.29 |  | -Bilirubiini |  |  | Bilirubin.total [Presence] in Serum or Plasma | FALSE |
| 589 | b-bio |  | 4183 | 100 |  |  | Blood |  |  | FALSE |
| 590 | b-hg | nmol/l | 64 | 0 |  | B -Elohopea | Blood |  | Mercury [Moles/volume] in Blood | FALSE |
| 591 | b-hg |  | 51 | 94.12 |  | B -Elohopea | Blood |  | Mercury [Presence] in Blood | FALSE |
| 592 | cb-bil | umol/l | 331 | 0 | [11.1, 19.39, 22.31, 26.36, 32.8, 45.69, 98.54, 156.29, 216.28] | cB-Bilirubiini | Capillary blood |  | Bilirubin.total [Moles/volume] in Capillary blood | FALSE |
| 593 | cb-bil |  | 4244 | 99.98 |  | cB-Bilirubiini | Capillary blood |  | Bilirubin.total [Presence] in Capillary blood | FALSE |
| 594 | du-mg | mmol | 580 | 0.17 | [2.07, 2.62, 3.11, 3.51, 3.97, 4.42, 4.91, 5.69, 6.98] | dU-Magnesium | 24-hour urine |  | Magnesium [Moles/time] in 24 hour Urine | FALSE |
| 595 | du-mg |  | 154 | 70.78 |  | dU-Magnesium | 24-hour urine |  | Magnesium [Presence] in 24 hour Urine | FALSE |
| 596 | du-pi | mmol | 591 | 0.17 | [14.15, 19.7, 22.95, 26.88, 29.9, 33.43, 38, 43.23, 51.47] | dU-Fosfaatti, epäorgaaninen | 24-hour urine |  | Phosphate [Moles/time] in 24 hour Urine | FALSE |
| 597 | du-pi |  | 118 | 75.42 |  | dU-Fosfaatti, epäorgaaninen | 24-hour urine |  | Phosphate [Presence] in 24 hour Urine | FALSE |
| 598 | fl-koh |  | 285 | 100 |  |  | Vaginal discharge |  | Fungus identified in Vaginal fluid by KOH preparation | FALSE |
| 599 | fp-bil | umol/l | 111 | 0 | [4.98, 6.34, 7.02, 8.69, 9.41, 10.29, 12.14, 15.18, 27.61] |  | Fasting plasma |  | Bilirubin.total [Moles/volume] in Serum or Plasma | FALSE |
| 600 | fp-kol | mmol | 7 | 0 |  | fP-Kolesteroli | Fasting plasma |  | Cholesterol [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 601 | fp-kol | mmol/ | 7 | 0 |  | fP-Kolesteroli | Fasting plasma |  | Cholesterol [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 602 | fp-kol | mmol/l | 1407523 | 0 | [3.2, 3.63, 3.97, 4.28, 4.58, 4.87, 5.21, 5.6, 6.16] | fP-Kolesteroli | Fasting plasma |  | Cholesterol [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 603 | fp-kol |  | 17406 | 100 | [4.01, 4.31, 4.6, 4.91, 5.19, 5.43, 5.75, 6.21, 6.8] | fP-Kolesteroli | Fasting plasma |  | Cholesterol [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 604 | fp-vip | pmol/l | 391 | 1.53 | [6.42, 8.54, 9.99, 11.21, 13, 14.7, 16.8, 19.84, 27.89] | fP-Vasoaktiivinen intestinaalinen peptidi | Fasting plasma |  | Vasoactive intestinal peptide [Moles/volume] in Serum or Plasma | FALSE |
| 605 | fp-vip |  | 61 | 81.97 |  | fP-Vasoaktiivinen intestinaalinen peptidi | Fasting plasma |  | Vasoactive intestinal peptide [Presence] in Serum or Plasma | FALSE |
| 606 | fs-kol | mmol/ | 7 | 0 |  | fS-Kolesteroli | Fasting serum |  | Cholesterol [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 607 | fs-kol | mmol/l | 259011 | 0 | [3.71, 4.15, 4.46, 4.76, 5.03, 5.31, 5.59, 5.95, 6.44] | fS-Kolesteroli | Fasting serum |  | Cholesterol [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 608 | fs-kol |  | 481 | 100 | [3.95, 4.3, 4.66, 4.92, 5.17, 5.39, 5.64, 6.03, 6.57] | fS-Kolesteroli | Fasting serum |  | Cholesterol [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 609 | li-bio |  | 161 | 100 |  |  | Cerebrospinal fluid |  |  | FALSE |
| 610 | mmse |  | 524 | 94.66 |  |  |  |  | Mini-mental state examination | FALSE |
| 611 | p-bil | umol/l | 1420468 | 0.09 | [5, 6, 7, 8.01, 9.15, 10.92, 12.96, 16.55, 24.99] | P -Bilirubiini | Plasma |  | Bilirubin.total [Moles/volume] in Serum or Plasma | FALSE |
| 612 | p-bil |  | 51285 | 100 | [4.75, 5.95, 6.93, 7.97, 9.15, 10.81, 13.1, 17.26, 26.41] | P -Bilirubiini | Plasma |  | Bilirubin.total [Presence] in Serum or Plasma | FALSE |
| 613 | p-bnp | ng/l | 92283 | 0 | [19.9, 36.26, 58.02, 88.41, 132.21, 195.75, 292.04, 465.57, 902.19] | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  | Natriuretic peptide.B [Mass/volume] in Serum or Plasma | FALSE |
| 614 | p-bnp | ng/ml | 14 | 0 |  | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  | Natriuretic peptide.B [Mass/volume] in Serum or Plasma | FALSE |
| 615 | p-bnp |  | 5638 | 100 | [41.88, 71.98, 108.12, 145.12, 193.35, 257.89, 351.05, 510.91, 912.06] | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  | Natriuretic peptide.B [Presence] in Serum or Plasma | FALSE |
| 616 | p-fsh | u/l | 10309 | 0 | [3.43, 4.83, 5.94, 7.2, 9.39, 15.3, 30.23, 51.8, 73.17] | P -Follikkelia stimuloiva hormoni | Plasma |  | Follicle stimulating hormone [Units/volume] in Serum or Plasma | FALSE |
| 617 | p-fsh |  | 155 | 100 | [3.32, 4.57, 5.74, 6.86, 8.5, 12.89, 23.84, 44.5, 70.18] | P -Follikkelia stimuloiva hormoni | Plasma |  | Follicle stimulating hormone [Presence] in Serum or Plasma | FALSE |
| 618 | p-fsl | s | 1808 | 0 | [23.6, 25, 25.97, 26.26, 27.2, 28.08, 29.24, 31.3, 34.37] |  | Plasma |  |  | FALSE |
| 619 | p-fsl |  | 86 | 69.77 |  |  | Plasma |  |  | FALSE |
| 620 | p-kol | mmol/l | 298985 | 0 | [3.03, 3.42, 3.74, 4.03, 4.33, 4.64, 4.97, 5.37, 5.92] | P -Kolesteroli | Plasma |  | Cholesterol [Moles/volume] in Serum or Plasma | FALSE |
| 621 | p-kol |  | 2034 | 100 | [3, 3.37, 3.67, 3.97, 4.25, 4.57, 4.92, 5.32, 5.88] | P -Kolesteroli | Plasma |  | Cholesterol [Presence] in Serum or Plasma | FALSE |
| 622 | p-mg | mmol/l | 259826 | 0.04 | [0.64, 0.7, 0.74, 0.77, 0.8, 0.83, 0.86, 0.89, 0.95] | P -Magnesium | Plasma |  | Magnesium [Moles/volume] in Serum or Plasma | FALSE |
| 623 | p-mg |  | 2225 | 100 | [0.64, 0.7, 0.74, 0.78, 0.81, 0.84, 0.86, 0.9, 0.95] | P -Magnesium | Plasma |  | Magnesium [Presence] in Serum or Plasma | FALSE |
| 624 | p-se | umol/l | 1087 | 0.09 | [0.86, 1.03, 1.1, 1.19, 1.27, 1.34, 1.41, 1.5, 1.62] | P -Seleeni | Plasma |  | Selenium [Moles/volume] in Serum or Plasma | FALSE |
| 625 | p-se |  | 55 | 43.64 | [1.17, 1.27, 1.34, 1.4, 1.46, 1.54, 1.63, 1.73, 1.94] | P -Seleeni | Plasma |  | Selenium [Presence] in Serum or Plasma | FALSE |
| 626 | p-tsh | miu/l | 32584 | 0 | [0.71, 1.13, 1.46, 1.75, 2.07, 2.43, 2.87, 3.48, 4.57] | P -Tyreotropiini | Plasma |  | Thyrotropin [Units/volume] in Serum or Plasma | FALSE |
| 627 | p-tsh | mlu/l | 4705 | 0 | [0.58, 1.02, 1.38, 1.7, 2.07, 2.5, 3.01, 3.68, 4.95] | P -Tyreotropiini | Plasma |  | Thyrotropin [Units/volume] in Serum or Plasma | FALSE |
| 628 | p-tsh | mu/l | 1660849 | 0.06 | [0.53, 0.92, 1.22, 1.5, 1.78, 2.11, 2.53, 3.11, 4.2] | P -Tyreotropiini | Plasma |  | Thyrotropin [Units/volume] in Serum or Plasma | FALSE |
| 629 | p-tsh |  | 53377 | 100 | [0.3, 0.81, 1.02, 1.41, 1.64, 1.91, 2.3, 2.66, 3.57] | P -Tyreotropiini | Plasma |  | Thyrotropin [Presence] in Serum or Plasma | FALSE |
| 630 | pf-kol | mmol/l | 614 | 0 | [0.64, 0.93, 1.1, 1.3, 1.51, 1.75, 2.03, 2.36, 2.85] | Pf-Kolesteroli | Pleural fluid |  | Cholesterol [Moles/volume] in Pleural fluid | FALSE |
| 631 | pf-kol |  | 361 | 98.06 |  | Pf-Kolesteroli | Pleural fluid |  | Cholesterol [Presence] in Pleural fluid | FALSE |
| 632 | s-bil | umol/l | 15554 | 0 | [5.56, 6.89, 7.91, 8.95, 10.06, 11.55, 13.42, 16.35, 22.65] | S -Bilirubiini | Serum |  | Bilirubin.total [Moles/volume] in Serum or Plasma | FALSE |
| 633 | s-bil |  | 183 | 82.51 | [5.99, 7.33, 8.34, 9.33, 10.81, 12.14, 14.24, 16.54, 22.13] | S -Bilirubiini | Serum |  | Bilirubin.total [Presence] in Serum or Plasma | FALSE |
| 634 | s-bio |  | 11283 | 100 |  |  | Serum |  |  | FALSE |
| 635 | s-biol |  | 508 | 100 |  |  | Serum |  |  | FALSE |
| 636 | s-fsh | iu/l | 21045 | 0 | [3.26, 4.67, 5.97, 7.58, 10.27, 17.4, 33.37, 51.85, 72.5] | S -Follikkelia stimuloiva hormoni | Serum |  | Follicle stimulating hormone [Units/volume] in Serum or Plasma | FALSE |
| 637 | s-fsh | u/l | 14312 | 0.62 | [3.48, 4.97, 6.16, 7.42, 9.34, 13.61, 26.1, 47.59, 73.43] | S -Follikkelia stimuloiva hormoni | Serum |  | Follicle stimulating hormone [Units/volume] in Serum or Plasma | FALSE |
| 638 | s-fsh |  | 1106 | 100 | [3.11, 4.58, 5.88, 7.13, 8.92, 13.11, 23.72, 44.2, 70.34] | S -Follikkelia stimuloiva hormoni | Serum |  | Follicle stimulating hormone [Presence] in Serum or Plasma | FALSE |
| 639 | s-kol | mg/ml | 9 | 0 |  | S -Kolesteroli | Serum |  | Cholesterol [Mass/volume] in Serum or Plasma | FALSE |
| 640 | s-kol | mmol/l | 35285 | 0 | [3.59, 4.01, 4.33, 4.59, 4.85, 5.11, 5.39, 5.71, 6.19] | S -Kolesteroli | Serum |  | Cholesterol [Moles/volume] in Serum or Plasma | FALSE |
| 641 | s-kol |  | 396 | 89.9 |  | S -Kolesteroli | Serum |  | Cholesterol [Presence] in Serum or Plasma | FALSE |
| 642 | s-mg | mmol/l | 5982 | 0 | [0.77, 0.81, 0.83, 0.85, 0.87, 0.88, 0.9, 0.92, 0.95] | S -Magnesium | Serum |  | Magnesium [Moles/volume] in Serum or Plasma | FALSE |
| 643 | s-mg |  | 23 | 69.57 | [0.75, 0.78, 0.8, 0.82, 0.83, 0.85, 0.87, 0.89, 0.91] | S -Magnesium | Serum |  | Magnesium [Presence] in Serum or Plasma | FALSE |
| 644 | s-nse | ug/l | 10085 | 0.04 | [9.38, 10.96, 12, 13.1, 14.43, 16.18, 18.88, 24.33, 45.7] | S -Neuronispesifinen enolaasi | Serum |  | Neuron specific enolase [Mass/volume] in Serum or Plasma | FALSE |
| 645 | s-nse |  | 210 | 45.24 | [8.56, 10, 10.8, 12.01, 14.24, 17, 20.25, 24.5, 29.28] | S -Neuronispesifinen enolaasi | Serum |  | Neuron specific enolase [Presence] in Serum or Plasma | FALSE |
| 646 | s-tsh | miu/l | 117078 | 0 | [0.56, 0.91, 1.16, 1.39, 1.62, 1.89, 2.23, 2.72, 3.61] | S -Tyreotropiini | Serum |  | Thyrotropin [Units/volume] in Serum or Plasma | FALSE |
| 647 | s-tsh | mlu/l | 113 | 0 | [0.33, 0.69, 1.02, 1.22, 1.42, 1.62, 2, 2.33, 2.93] | S -Tyreotropiini | Serum |  | Thyrotropin [Units/volume] in Serum or Plasma | FALSE |
| 648 | s-tsh | mu/l | 253056 | 0 | [0.62, 0.91, 1.15, 1.36, 1.59, 1.85, 2.18, 2.64, 3.49] | S -Tyreotropiini | Serum |  | Thyrotropin [Units/volume] in Serum or Plasma | FALSE |
| 649 | s-tsh | u/l | 142 | 0 | [0.52, 0.94, 1.22, 1.48, 1.73, 1.98, 2.18, 2.57, 4.01] | S -Tyreotropiini | Serum |  | Thyrotropin [Units/volume] in Serum or Plasma | FALSE |
| 650 | s-tsh |  | 4491 | 100 | [0.62, 0.91, 1.18, 1.45, 1.66, 1.95, 2.23, 2.72, 3.49] | S -Tyreotropiini | Serum |  | Thyrotropin [Presence] in Serum or Plasma | FALSE |
| 651 | se-bil | umol/l | 526 | 1.33 | [9.24, 12.96, 16.08, 20.31, 26.93, 38.21, 60.68, 119.92, 333.14] |  | Secretion |  | Bilirubin.total [Moles/volume] in Secretion | FALSE |
| 652 | se-bil |  | 102 | 99.02 |  |  | Secretion |  | Bilirubin.total [Presence] in Secretion | FALSE |
| 653 | u-al | umol/l | 81 | 0 | [0.1, 0.1, 0.2, 0.2, 0.22, 0.3, 0.4, 0.7, 1.7] | U -Alumiini | Urine |  | Aluminum [Moles/volume] in Urine | FALSE |
| 654 | u-al |  | 87 | 97.7 |  | U -Alumiini | Urine |  | Aluminum [Presence] in Urine | FALSE |
| 655 | u-amp |  | 158 | 100 |  |  | Urine |  | Amphetamines [Presence] in Urine | FALSE |
| 656 | u-as-i | nmol/l | 16 | 0 |  | U -Arseeni, epäorgaaninen | Urine |  | Arsenic.inorganic [Moles/volume] in Urine | FALSE |
| 657 | u-as-i | ug/l | 20 | 0 |  | U -Arseeni, epäorgaaninen | Urine |  | Arsenic.inorganic [Mass/volume] in Urine | FALSE |
| 658 | u-as-i |  | 107 | 100 |  | U -Arseeni, epäorgaaninen | Urine |  | Arsenic.inorganic [Presence] in Urine | FALSE |
| 659 | u-bil |  | 441 | 100 |  |  | Urine |  | Bilirubin [Presence] in Urine by Test strip | FALSE |
| 660 | u-bio |  | 2387 | 100 |  |  | Urine |  |  | FALSE |
| 661 | u-bup |  | 145 | 100 |  |  | Urine |  | Buprenorphine [Presence] in Urine | FALSE |
| 662 | u-bzd |  | 143 | 100 |  |  | Urine |  | Benzodiazepines [Presence] in Urine | FALSE |
| 663 | u-cl | mmol/l | 200 | 1.5 | [30.37, 49.43, 62.98, 72.55, 86.28, 96.56, 114.04, 135.66, 174.02] | U -Kloridi | Urine | Clearance | Chloride [Moles/volume] in Urine | FALSE |
| 664 | u-cl |  | 33 | 72.73 |  | U -Kloridi | Urine | Clearance | Chloride [Presence] in Urine | FALSE |
| 665 | u-dala | umol/l | 111 | 0.9 | [5, 8, 10.96, 13.72, 17, 20.55, 23.93, 29.9, 40.27] | U -Delta-aminolevulinaatti | Urine |  | Aminolevulinic acid [Moles/volume] in Urine | FALSE |
| 666 | u-ds4a |  | 461 | 100 |  |  | Urine |  |  | FALSE |
| 667 | u-ds5 |  | 133 | 100 |  |  | Urine |  |  | FALSE |
| 668 | u-ds5b |  | 1156 | 100 |  |  | Urine |  |  | FALSE |
| 669 | u-ds6 |  | 386 | 100 |  |  | Urine |  |  | FALSE |
| 670 | u-ds6a |  | 1325 | 100 |  |  | Urine |  |  | FALSE |
| 671 | u-ery |  | 3788 | 99.71 |  |  | Urine |  | Erythrocytes [Presence] in Urine | FALSE |
| 672 | u-fyl |  | 145 | 100 |  |  | Urine |  | Fentanyl [Presence] in Urine | FALSE |
| 673 | u-hg | nmol/l | 108 | 0 |  | U -Elohopea | Urine |  | Mercury [Moles/volume] in Urine | FALSE |
| 674 | u-hg |  | 25 | 100 |  | U -Elohopea | Urine |  | Mercury [Presence] in Urine | FALSE |
| 675 | u-i | ug/l | 309 | 0 | [44.03, 61.73, 78.06, 96.82, 115.33, 136.79, 163.87, 204.07, 318.14] | U -Jodidi | Urine |  | Iodide [Mass/volume] in Urine | FALSE |
| 676 | u-i |  | 18 | 88.89 |  | U -Jodidi | Urine |  | Iodide [Presence] in Urine | FALSE |
| 677 | u-inf |  | 51657 | 100 |  |  | Urine |  |  | FALSE |
| 678 | u-intp | nmol/mmol | 2098 | 0 | [16.36, 22.55, 28.43, 35.25, 42.57, 53.83, 68.67, 92.78, 154.47] | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I N-terminal telopeptide/Creatinine [Molar ratio] in Urine | FALSE |
| 679 | u-intp | nmol/mmolkr | 14 | 0 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I N-terminal telopeptide/Creatinine [Molar ratio] in Urine | FALSE |
| 680 | u-intp | ratio | 47 | 0 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I N-terminal telopeptide/Creatinine [Molar ratio] in Urine | FALSE |
| 681 | u-intp |  | 1030 | 94.47 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I N-terminal telopeptide [Presence] in Urine | FALSE |
| 682 | u-kivi | form | 60 | 100 |  | U -Kivianalyysi | Urine |  | Calculus analysis panel - Urinary stone | TRUE |
| 683 | u-kivi |  | 1820 | 100 |  | U -Kivianalyysi | Urine |  | Calculus analysis panel - Urinary stone | TRUE |
| 684 | u-mg | mmol/l | 123 | 0.81 | [0.84, 1.34, 1.62, 1.98, 2.27, 2.78, 3.64, 4.45, 6.45] | U -Magnesium | Urine |  | Magnesium [Moles/volume] in Urine | FALSE |
| 685 | u-mg |  | 26 | 38.46 |  | U -Magnesium | Urine |  | Magnesium [Presence] in Urine | FALSE |
| 686 | u-mtd |  | 144 | 100 |  |  | Urine |  | Methadone [Presence] in Urine | FALSE |
| 687 | u-ni | form | 57 | 0 |  | U -Nikkeli | Urine |  | Nickel [Presence] in Urine | FALSE |
| 688 | u-ni | ug/l | 65 | 0 |  | U -Nikkeli | Urine |  | Nickel [Mass/volume] in Urine | FALSE |
| 689 | u-ni | umol/l | 754 | 0 | [0.01, 0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.06] | U -Nikkeli | Urine |  | Nickel [Moles/volume] in Urine | FALSE |
| 690 | u-ni |  | 323 | 90.71 |  | U -Nikkeli | Urine |  | Nickel [Presence] in Urine | FALSE |
| 691 | u-pbg | umol/l | 248 | 1.61 | [1, 2, 2, 3, 3.9, 4.42, 5, 6.04, 8.79] | U -Porfobilinogeeni | Urine |  | Porphobilinogen [Moles/volume] in Urine | FALSE |
| 692 | u-pbg | umol/mmol | 6 | 0 |  | U -Porfobilinogeeni | Urine |  | Porphobilinogen/Creatinine [Molar ratio] in Urine | FALSE |
| 693 | u-pbg |  | 33 | 51.52 |  | U -Porfobilinogeeni | Urine |  | Porphobilinogen [Presence] in Urine | FALSE |
| 694 | u-pgb |  | 144 | 100 |  |  | Urine |  | Porphobilinogen [Presence] in Urine | FALSE |
| 695 | u-ph. |  | 24516 | 1.33 | [5, 5.5, 5.5, 5.87, 6, 6.26, 6.5, 6.96, 7.02] |  | Urine |  | pH of Urine | FALSE |
| 696 | u-phv |  | 737 | 0.27 | [5, 5.5, 5.5, 5.66, 6, 6, 6.5, 7, 7] |  | Urine |  | pH of Urine | FALSE |
| 697 | u-pi | mmol/l | 772 | 0.13 | [4.87, 7.61, 10.55, 13.2, 16.31, 20.1, 24.74, 31.17, 40.13] | U -Fosfaatti, epäorgaaninen | Urine |  | Phosphate [Moles/volume] in Urine | FALSE |
| 698 | u-pi |  | 84 | 54.76 |  | U -Fosfaatti, epäorgaaninen | Urine |  | Phosphate [Presence] in Urine | FALSE |
| 699 | u-pyr | form | 7 | 0 |  | U -Pyrenoli (1) | Urine |  | 1-Hydroxypyrene [Presence] in Urine | FALSE |
| 700 | u-pyr | ug/l | 6 | 0 |  | U -Pyrenoli (1) | Urine |  | 1-Hydroxypyrene [Mass/volume] in Urine | FALSE |
| 701 | u-pyr |  | 88 | 100 |  | U -Pyrenoli (1) | Urine |  | 1-Hydroxypyrene [Presence] in Urine | FALSE |
| 702 | u-sed |  | 2162 | 99.95 |  |  | Urine |  | Urinalysis microscopic panel - Urine | TRUE |
| 703 | u-sg | kg/l | 3827 | 0 | [1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity of Urine | FALSE |
| 704 | u-sg |  | 75 | 100 | [1, 1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.03] |  | Urine |  | Specific gravity of Urine | FALSE |
| 705 | u-thc |  | 157 | 100 |  |  | Urine |  | THC [Presence] in Urine | FALSE |
| 706 | u-tml |  | 145 | 100 |  |  | Urine |  | Tramadol [Presence] in Urine | FALSE |
| 707 | u-ubg |  | 441 | 100 |  |  | Urine |  | Urobilinogen [Presence] in Urine by Test strip | FALSE |
| 708 | us-tsh | mu/l | 415 | 0.72 | [3.59, 4.74, 5.45, 6.2, 7.04, 7.92, 9.44, 11.82, 16.59] | uS-Tyreotropiini | Umbilical (blood) serum |  | Thyrotropin [Units/volume] in Serum from Umbilical cord blood | FALSE |
| 709 | us-tsh |  | 75 | 33.33 |  | uS-Tyreotropiini | Umbilical (blood) serum |  | Thyrotropin [Presence] in Serum from Umbilical cord blood | FALSE |
| 710 | vp-dop |  | 154 | 100 |  | Valtimopaine, dopplermittaus |  |  |  | FALSE |

