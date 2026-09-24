[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass already inferred the six LOINC axes for each of these local Finnish lab codes. Your task is **not** to redo that work. It is to **correct the axis labels so they are real OMOP vocabulary terms**, using a shortlist of genuine candidates retrieved for each value.

# Why this pass exists

The earlier pass wrote each axis as free text. Measured against curated Finnish mappings, most values were real OMOP terms but the wrong one, and `has_component` in particular drifted off the controlled vocabulary entirely — roughly three quarters of its mismatches were near-miss paraphrases that do not exist anywhere in OMOP, e.g. `Transglutaminase IgA Ab` where OMOP has `Tissue Transglutaminase IgA`, or `gamma-Glutamyl transferase` where OMOP has `Gamma glutamyl transferase`.

A label that is one character off is worthless downstream: the mapping joins on exact axis values, so a near-miss fails just as hard as nonsense. Your job is to land each axis on the exact OMOP string.

# The Finnish laboratory coding system

Each national lab test has a 4-digit running number code and a short mnemonic abbreviation of at most 10 characters, built as:

    <system prefix> - <test abbreviation> [<suffix>]

- The **system prefix** is a 1-2 letter code for the specimen the sample came from, mostly from English words: `S` = serum, `P` = plasma, `B` = blood, `U` = urine, `Li` = cerebrospinal fluid, `F` = feces, `Ts` = tissue, `Pt` = patient (a whole-patient investigation), `fS`/`fP`/`fB` = fasting serum/plasma/blood, `dU` = 24-hour urine, `E` = erythrocyte, `L` = leukocyte.
- The **test abbreviation** is a mnemonic of the test's long Finnish name, occasionally an established international one (`CRP`, `TSH`).
- The optional **suffix** qualifies the result type or method: `-O` (qualitative/semi-quantitative), `-Ab` (antibodies), `-Ag` (antigen), `-Vi` (culture), `-Nh` (nucleic acid), `-Ion` (ionized), `-V` (free/unconjugated).

Finnish compounds run together: "transferriininrautakyllästeisyys" = transferrin iron saturation.

# What you are given

**The group table** — a markdown table, one row per local lab test/unit combination, with the columns:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty.
- `n` — number of records.
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available. The strongest single evidence for what a test really measures: a "sodium" code whose deciles read 0.32-0.40 is not sodium.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `has_component`, `has_property`, `has_method`, `has_system` — the **current, possibly wrong** axis values from the earlier pass.
- `has_scale_type`, `has_time_aspect`, `is_panel` — already drawn from closed lists in the earlier pass. Carry them through unchanged unless a row is plainly contradictory.

**The candidate tables** — one markdown table per free-text axis, listing for each distinct current value in this group the closest real OMOP terms from a semantic search over the LOINC vocabulary. Columns:

- `current` — the value the earlier pass produced. It repeats down the rows: every row with the same `current` is an alternative for that one value.
- `possible fix` — a real OMOP term you may replace it with. `(none scored >= ...)` means the search found nothing close enough, so that value has no suggested replacement.
- `score` — semantic similarity between `current` and `possible fix`, 0 to 1. **A score of 1.000 does NOT mean the two strings are identical** — the search is case-insensitive, so `Mass Fraction` scores 1.000 against the real OMOP term `Mass fraction`. Always compare the two strings character for character yourself.
- `n_codes` / `n_events` — how many curated Finnish lab codes use that term, and how many records they cover. **This is usage in Finland, not correctness.** Use it only to break ties between candidates that fit the evidence equally well; never to override what the row's own evidence says.

# How to decide

For each row and each of the four axes:

1. **If `possible fix` is character-for-character identical to `current`, keep it.** It is already an exact OMOP term; do not "improve" it. But if a row scores 1.000 while the two strings differ in any way — capitalisation, punctuation, spacing — **take the `possible fix`**: that column holds the real OMOP spelling and `current` does not. `Mass Fraction` must become `Mass fraction`.
2. **Otherwise pick the candidate that the row's own evidence supports** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix/suffix meanings. Prefer the exact OMOP spelling of the concept the code actually denotes.
3. **Where two candidates fit equally**, prefer the one with higher `n_codes`/`n_events` — Finland's established usage.
4. **If no candidate is right, leave the axis empty.** An empty axis is a correct, useful answer: it says "not knowable". A confidently wrong exact term is worse than nothing, because downstream code cannot tell it from a verified one.
5. **Never invent a value that is not in the candidate list.** The whole point of this pass is that only real OMOP terms survive. The one exception: if an axis is currently empty and the evidence genuinely supports no value, leave it empty.

Specific things to watch:

- **`has_system` was the worst axis in the earlier pass** (about 29% agreement). The recurring error is splitting `Serum or Plasma` into a bare `Serum` or `Plasma`. LOINC uses the combined `Serum or Plasma` for most chemistry, and only a genuinely serum-specific or plasma-specific test takes the narrow term. Let the code decide: an explicit `S` prefix means serum, `P` means plasma, and an ambiguous or absent prefix on a routine chemistry test usually means `Serum or Plasma`. Fasting is not part of the system: `fS` is still serum.
- **`has_component` drifts most.** Take the candidate's exact spelling, including its capitalisation and word order (`Gamma glutamyl transferase`, not `gamma-Glutamyl transferase`).
- **`has_method` is optional by design** and empty for most chemistry. If the earlier pass invented a method the code does not state, clear it.
- **`has_property`** follows the unit and the decile magnitude, not the analyte name: `g/l`, `mg/l`, `ug/l` are `Mass Concentration`; `mol/l`, `mmol/l`, `umol/l`, `nmol/l` are `Substance Concentration`; `U/l` is `Catalytic Concentration`.
- Never use the OMOP placeholder values `-`, `*` or `XXX`; leave the axis empty instead.

# Output

Return one entry per input row, with `row_id` echoed exactly and all seven fields. Return an entry for EVERY row, including ones you change nothing on — carrying a value through unchanged is a valid answer.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which corrections you made and why, where the candidate lists were unhelpful or missing the right term, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 110.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| CD16+56+ NK cells | CD16+CD56+ cells | 0.904 | 0 | 0 |
| CD16+56+ NK cells | CD16C+CD56+ cells | 0.894 | 0 | 0 |
| CD16+56+ NK cells | CD3+CD16+CD56+ cells | 0.829 | 0 | 0 |
| CD16+56+ NK cells | CD16 cells | 0.826 | 0 | 0 |
| CD16+56+ NK cells | CD16-CD57+ cells | 0.823 | 0 | 0 |
| CD16+56+ NK cells/Lymphocytes | CD16+CD56+ cells | 0.854 | 0 | 0 |
| CD16+56+ NK cells/Lymphocytes | CD16C+CD56+ cells | 0.847 | 0 | 0 |
| CD16+56+ NK cells/Lymphocytes | Cells.CD3-CD16+CD56+/Lymphocytes | 0.839 | 0 | 0 |
| CD16+56+ NK cells/Lymphocytes | Cells.CD16+CD56+/Cells | 0.833 | 0 | 0 |
| CD16+56+ NK cells/Lymphocytes | Cells.CD16+CD56+/100 cells | 0.829 | 0 | 0 |
| CD19+ B-lymphocytes | CD19 cells | 0.863 | 4 | 6,933 |
| CD19+ B-lymphocytes | CD19+CD20+ cells | 0.849 | 0 | 0 |
| CD19+ B-lymphocytes | CD19+IgM+ cells | 0.837 | 0 | 0 |
| CD19+ B-lymphocytes | CD19+IgG+ cells | 0.833 | 0 | 0 |
| CD19+ B-lymphocytes | CD19+CD43+ cells | 0.830 | 0 | 0 |
| CD19+ B-lymphocytes/Lymphocytes | Cells.CD19/100 lymphocytes | 0.824 | 0 | 0 |
| CD19+ B-lymphocytes/Lymphocytes | CD19+Lambda+ cells | 0.808 | 0 | 0 |
| CD19+ B-lymphocytes/Lymphocytes | Cells.CD19/Lymphocytes | 0.808 | 0 | 0 |
| CD19+ B-lymphocytes/Lymphocytes | CD19 cells | 0.806 | 4 | 6,933 |
| CD19+ B-lymphocytes/Lymphocytes | CD19+CD20+ cells | 0.802 | 0 | 0 |
| CD3+ T-lymphocytes | CD3 cells | 0.869 | 8 | 11,121 |
| CD3+ T-lymphocytes | CD3+TCR cells | 0.857 | 0 | 0 |
| CD3+ T-lymphocytes | CD3-CD4+ cells | 0.848 | 0 | 0 |
| CD3+ T-lymphocytes | CD3+CD45+ cells | 0.845 | 0 | 0 |
| CD3+ T-lymphocytes | CD3-CD45+ cells | 0.842 | 0 | 0 |
| CD3+ T-lymphocytes/Lymphocytes | Cells.CD3+HLA-DR+/Lymphocytes | 0.833 | 0 | 0 |
| CD3+ T-lymphocytes/Lymphocytes | Cells.CD3+HLA DR+/Lymphocytes | 0.829 | 0 | 0 |
| CD3+ T-lymphocytes/Lymphocytes | Cells.CD3/Lymphocytes | 0.818 | 5 | 8,032 |
| CD3+ T-lymphocytes/Lymphocytes | Cells.CD3+CD19- (T cells)/Lymphocytes | 0.816 | 0 | 0 |
| CD3+ T-lymphocytes/Lymphocytes | CD3+CD45+ cells | 0.810 | 0 | 0 |
| CD34+ cells | CD34 cells | 0.973 | 0 | 0 |
| CD34+ cells | CD34+HLA-DR+ cells | 0.894 | 0 | 0 |
| CD34+ cells | CD33+CD34+ cells | 0.883 | 0 | 0 |
| CD34+ cells | CD34 | 0.877 | 0 | 0 |
| CD34+ cells | CD16-CD34+ cells | 0.854 | 0 | 0 |
| CD34+ cells/Leukocytes | CD34 cells | 0.858 | 0 | 0 |
| CD34+ cells/Leukocytes | Cells.CD34/100 cells | 0.827 | 0 | 0 |
| CD34+ cells/Leukocytes | Cells.CD34+DR+/100 cells | 0.817 | 0 | 0 |
| CD34+ cells/Leukocytes | Cells.CD34+DR+/Cells | 0.814 | 0 | 0 |
| CD34+ cells/Leukocytes | Cells.CD34/Cells | 0.809 | 1 | 52 |
| CD4-CD8- T-lymphocytes/Lymphocytes | CD4-CD8- | 0.798 | 0 | 0 |
| CD4-CD8- T-lymphocytes/Lymphocytes | Cells.CD8/Lymphocytes | 0.786 | 1 | 3,725 |
| CD4-CD8- T-lymphocytes/Lymphocytes | Cells.CD8/100 lymphocytes | 0.768 | 0 | 0 |
| CD4/CD8 | CD4-CD8- | 0.870 | 0 | 0 |
| CD4/CD8 | CD4+CD8+ | 0.816 | 0 | 0 |
| CD4/CD8 | CD4/CD8 ratio | 0.792 | 0 | 0 |
| CD4/CD8 | Cells.CD4/Cells.CD8 | 0.769 | 0 | 0 |
| CD4/CD8 | CD4+CD8+ cells | 0.759 | 0 | 0 |
| CD4+ T-lymphocytes | CD4 cells | 0.817 | 0 | 0 |
| CD4+ T-lymphocytes | CD3-CD4+ cells | 0.804 | 0 | 0 |
| CD4+ T-lymphocytes | CD3+CD4+ (T4 helper) cells | 0.794 | 4 | 8,143 |
| CD4+ T-lymphocytes | CD3+CD4+ cells | 0.791 | 0 | 0 |
| CD4+ T-lymphocytes | CD4 | 0.785 | 0 | 0 |
| CD4+ T-lymphocytes/Lymphocytes | Cells.CD4/Lymphocytes | 0.816 | 5 | 9,464 |
| CD4+ T-lymphocytes/Lymphocytes | Cells.CD4/100 lymphocytes | 0.801 | 0 | 0 |
| CD4+ T-lymphocytes/Lymphocytes | Cells.CD3+CD4+/Lymphocytes | 0.794 | 0 | 0 |
| CD4+ T-lymphocytes/Lymphocytes | Cells.CD3+CD4+/100 lymphocytes | 0.754 | 0 | 0 |
| CD4+CD8+ T-lymphocytes/Lymphocytes | CD4+CD8+ cells | 0.816 | 0 | 0 |
| CD4+CD8+ T-lymphocytes/Lymphocytes | CD4+CD8+ | 0.812 | 0 | 0 |
| CD4+CD8+ T-lymphocytes/Lymphocytes | Cells.CD3+CD8+/Lymphocytes | 0.773 | 0 | 0 |
| CD4+CD8+ T-lymphocytes/Lymphocytes | Cells.CD3+CD4-CD8-CD45+/Cells | 0.771 | 0 | 0 |
| CD4+CD8+ T-lymphocytes/Lymphocytes | Cells.CD4+CD8+/Cells | 0.765 | 0 | 0 |
| CD8+ T-lymphocytes | CD8 cells | 0.826 | 0 | 0 |
| CD8+ T-lymphocytes | CD8+HLA-DR+ cells | 0.765 | 0 | 0 |
| CD8+ T-lymphocytes | CD8+CD11b+ cells | 0.764 | 0 | 0 |
| CD8+ T-lymphocytes | CD8 | 0.756 | 0 | 0 |
| CD8+ T-lymphocytes | CD8+CD3- cells | 0.750 | 0 | 0 |
| CD8+ T-lymphocytes/Lymphocytes | Cells.CD8/Lymphocytes | 0.815 | 1 | 3,725 |
| CD8+ T-lymphocytes/Lymphocytes | Cells.CD8/100 lymphocytes | 0.797 | 0 | 0 |
| CD8+ T-lymphocytes/Lymphocytes | Cells.CD3+CD8+/Lymphocytes | 0.787 | 0 | 0 |
| CD8+ T-lymphocytes/Lymphocytes | Cells.CD8-CD57+/Lymphocytes | 0.779 | 0 | 0 |
| CD8+ T-lymphocytes/Lymphocytes | Cells.CD8-CD57+/100 lymphocytes | 0.765 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Number Concentration | Number Concentration | 1.000 | 507 | 49,434,956 |
| Number Fraction | Number Fraction | 1.000 | 482 | 8,246,054 |
| Number Fraction | Decimal number fraction | 0.787 | 1 | 6,152 |
| Number Fraction | Time Fraction | 0.765 | 0 | 0 |
| Number per Mass | (none scored >= 0.75) |  |  |  |
| Ratio | Ratio | 1.000 | 88 | 786,172 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Bronchoalveolar lavage | Bronchoalveolar lavage | 1.000 | 0 | 0 |
| Bronchoalveolar lavage | Bronchoalveolar aspirate | 0.829 | 0 | 0 |
| Lymphocytes | (none scored >= 0.75) |  |  |  |
| White Blood Cells | White blood cells | 1.000 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1469 | b-b-cd19 | e6/l | 913 | 0 | [10.41, 31.05, 55.36, 87.14, 120.42, 155.29, 201.58, 263.7, 407.08] |  | Blood |  | CD19+ B-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1470 | b-b-cd19 | e9/l | 3083 | 0 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.29, 0.48] |  | Blood |  | CD19+ B-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1471 | b-b-cd19 |  | 569 | 89.28 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.31, 0.47] |  | Blood |  | CD19+ B-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1472 | b-cd16/56 | e6/l | 12 | 0 |  |  | Blood |  | CD16+56+ NK cells | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1473 | b-cd16/56 | e9/l | 2606 | 0.65 | [0.06, 0.09, 0.12, 0.15, 0.18, 0.22, 0.26, 0.33, 0.44] |  | Blood |  | CD16+56+ NK cells | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1474 | b-cd16/56 |  | 108 | 84.26 |  |  | Blood |  | CD16+56+ NK cells | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1475 | b-cd16/cd56 | e9/l | 263 | 0 | [0.09, 0.12, 0.15, 0.17, 0.21, 0.24, 0.3, 0.36, 0.44] |  | Blood |  | CD16+56+ NK cells | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1476 | b-cd16/cd56 |  | 15 | 100 |  |  | Blood |  | CD16+56+ NK cells | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1477 | b-cd19 | e6/l | 3891 | 0 | [0, 1.97, 16.17, 41.05, 70.27, 108.04, 158.42, 221.57, 336.97] |  | Blood |  | CD19+ B-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1478 | b-cd19 | e9/l | 2870 | 0.59 | [0, 0, 0.01, 0.03, 0.06, 0.09, 0.14, 0.19, 0.29] |  | Blood |  | CD19+ B-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1479 | b-cd19 |  | 175 | 66.29 |  |  | Blood |  | CD19+ B-lymphocytes | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1480 | b-cd3 | e6/l | 3892 | 0 |  |  | Blood |  | CD3+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1481 | b-cd3 | e9/l | 2868 | 0.59 |  |  | Blood |  | CD3+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1482 | b-cd3 |  | 204 | 71.57 |  |  | Blood |  | CD3+ T-lymphocytes | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1483 | b-cd34 | e6/l | 193 | 0 | [5.27, 13.75, 20.31, 28.86, 37.69, 50.47, 63.07, 93.98, 156.93] |  | Blood |  | CD34+ cells | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1484 | b-cd34 |  | 27 | 29.63 |  |  | Blood |  | CD34+ cells | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1485 | b-cd4 | e6/l | 3893 | 0 | [134.07, 213.38, 284.14, 381.8, 505.45, 647.7, 819.98, 1038.04, 1335.05] |  | Blood |  | CD4+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1486 | b-cd4 | e9/l | 2870 | 0.59 | [0.14, 0.2, 0.25, 0.32, 0.4, 0.51, 0.63, 0.8, 1.07] |  | Blood |  | CD4+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1487 | b-cd4 |  | 172 | 66.28 |  |  | Blood |  | CD4+ T-lymphocytes | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1488 | b-cd8 | e6/l | 3892 | 0 | [117.75, 200.41, 277.17, 351.98, 433.16, 541.85, 672.5, 850.74, 1214.03] |  | Blood |  | CD8+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1489 | b-cd8 | e9/l | 2870 | 0.59 | [0.11, 0.16, 0.23, 0.29, 0.36, 0.46, 0.57, 0.73, 1] |  | Blood |  | CD8+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1490 | b-cd8 |  | 172 | 66.28 |  |  | Blood |  | CD8+ T-lymphocytes | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1491 | b-lcd34 | e6/l | 251 | 0 | [3, 7.11, 11.11, 14.14, 17.55, 23.82, 31.86, 44, 64.2] | B -Leukosyytit, CD34 alaluokka | Blood |  | CD34+ cells | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1492 | b-lcd34 | e9/l | 475 | 0 | [0, 0.01, 0.02, 0.03, 0.03, 0.04, 0.06, 0.09, 0.13] | B -Leukosyytit, CD34 alaluokka | Blood |  | CD34+ cells | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1493 | b-lcd34 |  | 66 | 100 |  | B -Leukosyytit, CD34 alaluokka | Blood |  | CD34+ cells | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1494 | b-lycd4 |  | 496 | 100 |  | B -Lymfosyytti CD4-alaluokka | Blood |  | CD4+ T-lymphocytes | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1495 | b-t-cd3 | e6/l | 1174 | 0 |  |  | Blood |  | CD3+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1496 | b-t-cd3 | e9/l | 2692 | 0 |  |  | Blood |  | CD3+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1497 | b-t-cd3 |  | 304 | 81.91 |  |  | Blood |  | CD3+ T-lymphocytes | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1498 | b-t-cd4 | e6/l | 1609 | 0 | [168.06, 247.56, 335.09, 433.05, 551.26, 672.04, 816.88, 957.34, 1254.62] |  | Blood |  | CD4+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1499 | b-t-cd4 | e9/l | 6105 | 0 | [0.16, 0.25, 0.34, 0.43, 0.52, 0.64, 0.79, 0.96, 1.28] |  | Blood |  | CD4+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1500 | b-t-cd4 |  | 475 | 69.89 | [0.2, 0.26, 0.34, 0.42, 0.55, 0.68, 0.8, 0.95, 1.29] |  | Blood |  | CD4+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1501 | b-t-cd8 | e6/l | 1174 | 0 | [141.94, 210.82, 289.62, 366.11, 450.98, 530.13, 639.55, 796.16, 1179.47] |  | Blood |  | CD8+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1502 | b-t-cd8 | e9/l | 2753 | 0 | [0.14, 0.21, 0.27, 0.35, 0.43, 0.52, 0.65, 0.83, 1.1] |  | Blood |  | CD8+ T-lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1503 | b-t-cd8 |  | 311 | 79.42 |  |  | Blood |  | CD8+ T-lymphocytes | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1504 | bl-cd4/cd8 | form | 42 | 100 |  |  | Bronchoalveolar lavage |  | CD4/CD8 | Ratio |  | Bronchoalveolar lavage | Qn | Point in time (spot) | FALSE |
| 1505 | bl-cd4/cd8 |  | 91 | 100 |  |  | Bronchoalveolar lavage |  | CD4/CD8 | Ratio |  | Bronchoalveolar lavage | Qn | Point in time (spot) | FALSE |
| 1506 | cd4/cd8 |  | 3940 | 0.23 | [0.29, 0.47, 0.68, 0.91, 1.2, 1.57, 1.94, 2.45, 3.26] |  |  |  | CD4/CD8 | Ratio |  |  | Qn |  | FALSE |
| 1507 | l-cd34 | % | 481 | 0 | [0.05, 0.08, 0.1, 0.13, 0.16, 0.2, 0.25, 0.32, 0.61] |  | Leukocyte |  | CD34+ cells/Leukocytes | Number Fraction |  | White Blood Cells | Qn | Point in time (spot) | FALSE |
| 1508 | l-cd34 |  | 41 | 100 |  |  | Leukocyte |  | CD34+ cells/Leukocytes | Finding |  | White Blood Cells | Nar | Point in time (spot) | FALSE |
| 1509 | la-cd34 | e6/kg | 156 | 0 | [0.6, 0.9, 1.18, 1.41, 1.69, 2.1, 2.53, 3.4, 4.94] |  |  |  | CD34+ cells | Number per Mass |  |  | Qn |  | FALSE |
| 1510 | la-cd34 | e9/l | 393 | 0 | [0.41, 0.56, 0.72, 0.84, 1.03, 1.27, 1.77, 2.36, 3.2] |  |  |  | CD34+ cells | Number Concentration |  |  | Qn |  | FALSE |
| 1511 | la-cd34-ks |  | 395 | 100 |  |  |  |  | CD34+ cells | Finding |  |  | Nar |  | FALSE |
| 1512 | la-cd34-os | % | 393 | 0 | [0.22, 0.3, 0.39, 0.49, 0.59, 0.69, 0.84, 1.12, 1.67] |  |  |  | CD34+ cells | Number Fraction |  |  | Qn |  | FALSE |
| 1513 | la-t-cd3 | e9/l | 149 | 0 |  |  |  |  | CD3+ T-lymphocytes | Number Concentration |  |  | Qn |  | FALSE |
| 1514 | la-t-cd3 |  | 6 | 16.67 |  |  |  |  | CD3+ T-lymphocytes | Finding |  |  | Nar |  | FALSE |
| 1515 | la-t-cd4 | e9/l | 149 | 0 |  |  |  |  | CD4+ T-lymphocytes | Number Concentration |  |  | Qn |  | FALSE |
| 1516 | la-t-cd4 |  | 6 | 16.67 |  |  |  |  | CD4+ T-lymphocytes | Finding |  |  | Nar |  | FALSE |
| 1517 | la-t-cd8 | e9/l | 149 | 0 |  |  |  |  | CD8+ T-lymphocytes | Number Concentration |  |  | Qn |  | FALSE |
| 1518 | la-t-cd8 |  | 6 | 16.67 |  |  |  |  | CD8+ T-lymphocytes | Finding |  |  | Nar |  | FALSE |
| 1519 | ly-b-cd19 | % | 1504 | 0 | [0, 0, 0.45, 2.91, 5.54, 7.86, 10.24, 13.34, 18.94] |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1520 | ly-b-cd19 |  | 950 | 99.05 |  |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1521 | ly-cd16/56 | % | 3462 | 0.49 | [5.28, 8.01, 10.25, 12.46, 15.08, 18.07, 21.55, 26.37, 33.4] |  | Lymphocyte |  | CD16+56+ NK cells/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1522 | ly-cd16/56 |  | 107 | 86.92 |  |  | Lymphocyte |  | CD16+56+ NK cells/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1523 | ly-cd16/cd56 | % | 262 | 0 | [5.52, 8.16, 10.06, 12.71, 14.93, 17.65, 20.63, 27.5, 36.58] |  | Lymphocyte |  | CD16+56+ NK cells/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1524 | ly-cd16/cd56 |  | 15 | 100 |  |  | Lymphocyte |  | CD16+56+ NK cells/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1525 | ly-cd19 | % | 3462 | 0.49 | [0, 0, 1.17, 3.24, 5.55, 8.08, 10.86, 14.11, 20.27] |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1526 | ly-cd19 |  | 107 | 85.98 |  |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1527 | ly-cd19-b | % | 2507 | 0 | [0, 0, 1, 3.95, 7.56, 10.5, 13.61, 17.58, 25.6] |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1528 | ly-cd19-b |  | 19 | 100 |  |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1529 | ly-cd3 | % | 3726 | 0.46 | [52.12, 61.25, 67.07, 71.15, 74.98, 78.39, 81.66, 85.36, 89.48] |  | Lymphocyte |  | CD3+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1530 | ly-cd3 |  | 122 | 87.7 |  |  | Lymphocyte |  | CD3+ T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1531 | ly-cd4 | % | 3726 | 0.46 | [16.32, 22.56, 27.91, 32.59, 37.02, 41.75, 46.47, 51.76, 58.99] |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1532 | ly-cd4 |  | 122 | 87.7 |  |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1533 | ly-cd4+8+ | % | 41 | 41.46 |  |  | Lymphocyte |  | CD4+CD8+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1534 | ly-cd4+8+ |  | 75 | 100 |  |  | Lymphocyte |  | CD4+CD8+ T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1535 | ly-cd4-8- | % | 207 | 8.21 | [7, 8, 8, 8.88, 9.82, 10.9, 12, 14, 16] |  | Lymphocyte |  | CD4-CD8- T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1536 | ly-cd4-8- |  | 77 | 100 |  |  | Lymphocyte |  | CD4-CD8- T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1537 | ly-cd4-t | % | 4576 | 0 | [15.23, 21.8, 27.31, 31.42, 35.47, 39.26, 43.26, 48.23, 54.7] |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1538 | ly-cd4-t |  | 170 | 22.94 | [17.53, 21.58, 24.78, 29.15, 33.2, 38.25, 41.67, 47.37, 52.57] |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1539 | ly-cd4/cd8 |  | 2752 | 4.18 | [0.37, 0.55, 0.75, 0.96, 1.18, 1.48, 1.83, 2.29, 3.23] | Ly-Auttaja- ja tappajasolujen suhde, immunofenotyypitys | Lymphocyte |  | CD4/CD8 | Ratio |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1540 | ly-cd4/cd8suhde |  | 278 | 5.4 | [0.5, 0.76, 1.02, 1.29, 1.66, 1.95, 2.26, 2.73, 3.97] |  | Lymphocyte |  | CD4/CD8 | Ratio |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1541 | ly-cd8 | % | 3725 | 0.46 | [14.46, 19.13, 22.75, 26.46, 30.35, 34.98, 40.06, 46.74, 56.02] |  | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1542 | ly-cd8 |  | 122 | 87.7 |  |  | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1543 | ly-t-cd3 | % | 3926 | 0 | [56.23, 64.92, 70.33, 74.35, 77.57, 80.54, 84.02, 87.72, 92.04] |  | Lymphocyte |  | CD3+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1544 | ly-t-cd3 |  | 264 | 98.48 |  |  | Lymphocyte |  | CD3+ T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1545 | ly-t-cd4 | % | 2006 | 0 | [18.72, 24.57, 29.84, 34.47, 38.67, 43.22, 47.75, 52.18, 58.04] | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1546 | ly-t-cd4 |  | 3875 | 99.92 |  | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1547 | ly-t-cd4. | % | 1462 | 0 | [18.57, 26.32, 32.42, 36.77, 41.27, 46.47, 51.47, 56.35, 63.05] |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1548 | ly-t-cd4. |  | 36 | 72.22 |  |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1549 | ly-t-cd4/8 | ratio | 1816 | 0 | [0.6, 0.8, 0.99, 1.23, 1.56, 1.85, 2.06, 2.47, 3.19] |  | Lymphocyte |  | CD4/CD8 | Ratio |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1550 | ly-t-cd4/8 |  | 224 | 100 | [0.48, 0.79, 1.06, 1.31, 1.55, 1.83, 2.13, 2.62, 3.69] |  | Lymphocyte |  | CD4/CD8 | Ratio |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1551 | ly-t-cd8 | % | 2895 | 0 | [14.95, 19.45, 23.24, 27.01, 30.29, 33.79, 38.05, 43.59, 52.29] | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1552 | ly-t-cd8 |  | 245 | 99.59 |  | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in time (spot) | FALSE |
| 1553 | ly-tcd4/8. |  | 2179 | 0.83 | [0.48, 0.75, 1, 1.21, 1.42, 1.69, 2, 2.51, 3.27] |  | Lymphocyte |  | CD4/CD8 | Ratio |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1554 | ly-tt-cd8 | % | 1219 | 0 | [13.33, 17.86, 21.01, 24.35, 28, 31.32, 36.22, 42.56, 52.88] |  | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes | Number Fraction |  | Lymphocytes | Qn | Point in time (spot) | FALSE |
| 1555 | ly-tt-cd8 |  | 5 | 40 |  |  | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes | Finding |  | Lymphocytes | Nar | Point in a time (spot) | FALSE |
| 1556 | s-gt-cdt | % | 13 | 0 |  |  | Serum |  |  |  |  |  |  |  |  |
| 1557 | s-gt-cdt |  | 2807 | 3.35 | [2.6, 2.87, 3.04, 3.25, 3.47, 3.7, 3.96, 4.27, 4.86] |  | Serum |  |  |  |  |  |  |  |  |
| 1558 | so-t-cd3 | % | 149 | 0 | [16.66, 19.73, 21.87, 23.49, 24.84, 27.82, 29.85, 33.41, 49.51] |  |  |  | CD3+ T-lymphocytes/Lymphocytes | Number Fraction |  |  | Qn |  | FALSE |
| 1559 | so-t-cd3 |  | 6 | 16.67 |  |  |  |  | CD3+ T-lymphocytes/Lymphocytes | Finding |  |  | Nar |  | FALSE |
| 1560 | so-t-cd4 | % | 149 | 0 | [9.42, 10.93, 12.3, 13.53, 14.67, 15.99, 17.4, 19.67, 23.42] |  |  |  | CD4+ T-lymphocytes/Lymphocytes | Number Fraction |  |  | Qn |  | FALSE |
| 1561 | so-t-cd4 |  | 6 | 16.67 |  |  |  |  | CD4+ T-lymphocytes/Lymphocytes | Finding |  |  | Nar |  | FALSE |
| 1562 | so-t-cd8 | % | 149 | 0 | [5.87, 7, 7.83, 8.57, 9.8, 10.57, 12.18, 14.02, 21.4] |  |  |  | CD8+ T-lymphocytes/Lymphocytes | Number Fraction |  |  | Qn |  | FALSE |
| 1563 | so-t-cd8 |  | 6 | 16.67 |  |  |  |  | CD8+ T-lymphocytes/Lymphocytes | Finding |  |  | Nar |  | FALSE |

