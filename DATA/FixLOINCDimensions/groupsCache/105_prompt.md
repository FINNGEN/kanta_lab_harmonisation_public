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
Here is group 105.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Basophils/leukocytes | Basophils/leukocytes | 1.000 | 48 | 1,446,628 |
| Basophils/leukocytes | Basophils/Cells | 0.869 | 0 | 0 |
| Basophils/leukocytes | Basophils+Mast cells/Leukocytes | 0.844 | 0 | 0 |
| Basophils/leukocytes | Basophils.immature/Leukocytes | 0.813 | 0 | 0 |
| Basophils/leukocytes | Basophils.band form/Leukocytes | 0.806 | 0 | 0 |
| Eosinophils/leukocytes | Eosinophils/leukocytes | 1.000 | 54 | 1,434,138 |
| Eosinophils/leukocytes | Eosinophils/Cells | 0.869 | 0 | 0 |
| Eosinophils/leukocytes | Eosinophils.immature/Leukocytes | 0.817 | 0 | 0 |
| Eosinophils/leukocytes | Eosinophils/100 leukocytes | 0.789 | 0 | 0 |
| Eosinophils/leukocytes | Epithelial cells/Leukocytes | 0.789 | 0 | 0 |
| Erythrocyte distribution width | Erythrocyte distribution width | 1.000 | 0 | 0 |
| Erythrocyte distribution width | Reticulocyte distribution width | 0.874 | 0 | 0 |
| Erythrocyte distribution width | Hemoglobin distribution width | 0.816 | 0 | 0 |
| Erythrocyte distribution width | Platelet distribution width | 0.801 | 0 | 0 |
| Erythrocyte distribution width | Reticulocyte hemoglobin distribution width | 0.784 | 0 | 0 |
| Erythrocyte mean corpuscular hemoglobin | Erythrocyte mean corpuscular hemoglobin | 1.000 | 0 | 0 |
| Erythrocyte mean corpuscular hemoglobin | Erythrocyte mean corpuscular hemoglobin concentration | 0.933 | 0 | 0 |
| Erythrocyte mean corpuscular hemoglobin | Erythrocyte mean corpuscular volume | 0.856 | 0 | 0 |
| Erythrocyte mean corpuscular hemoglobin | Erythrocyte mean corpuscular diameter | 0.829 | 0 | 0 |
| Erythrocyte mean corpuscular hemoglobin concentration | Erythrocyte mean corpuscular hemoglobin concentration | 1.000 | 0 | 0 |
| Erythrocyte mean corpuscular hemoglobin concentration | Erythrocyte mean corpuscular hemoglobin | 0.933 | 0 | 0 |
| Erythrocyte mean corpuscular hemoglobin concentration | Erythrocyte mean corpuscular volume | 0.834 | 0 | 0 |
| Erythrocyte mean corpuscular hemoglobin concentration | Erythrocyte mean corpuscular diameter | 0.811 | 0 | 0 |
| Erythrocyte mean corpuscular hemoglobin concentration | Reticulocyte corpuscular hemoglobin concentration mean | 0.783 | 0 | 0 |
| Erythrocyte mean volume | Erythrocyte mean corpuscular volume | 0.873 | 0 | 0 |
| Erythrocyte mean volume | Reticulocyte mean volume | 0.804 | 0 | 0 |
| Erythrocyte mean volume | Erythrocyte volume deviation | 0.763 | 0 | 0 |
| Erythrocyte mean volume | Erythrocyte mean corpuscular diameter | 0.757 | 0 | 0 |
| Erythrocytes | Erythrocytes | 1.000 | 64 | 12,187,960 |
| Granulocytes/leukocytes | Granulocytes/leukocytes | 1.000 | 39 | 44,978 |
| Granulocytes/leukocytes | Granulocytes | 0.844 | 7 | 30,146 |
| Granulocytes/leukocytes | Neutrophils/leukocytes | 0.827 | 62 | 1,413,613 |
| Granulocytes/leukocytes | Granulocytic cells/Cells | 0.791 | 0 | 0 |
| Granulocytes/leukocytes | Granulocytes.immature/Leukocytes | 0.790 | 0 | 0 |
| Hematocrit | Hematocrit | 1.000 | 0 | 0 |
| Hematocrit | Hematocrit/Hemoglobin | 0.797 | 0 | 0 |
| Hematocrit | Hematocrit^Baseline | 0.750 | 0 | 0 |
| Hemoglobin | Hemoglobin | 1.000 | 130 | 30,658,802 |
| Immature granulocytes/leukocytes | Immature granulocytes | 0.896 | 0 | 0 |
| Immature granulocytes/leukocytes | Granulocytes.immature/Leukocytes | 0.819 | 0 | 0 |
| Immature granulocytes/leukocytes | Immature cells/Leukocytes | 0.813 | 0 | 0 |
| Immature granulocytes/leukocytes | Neutrophils.immature/Leukocytes | 0.790 | 0 | 0 |
| Immature granulocytes/leukocytes | Granulocytes.immature/100 leukocytes | 0.774 | 0 | 0 |
| Leukocytes | Leukocytes | 1.000 | 126 | 12,024,159 |
| Leukocytes | Leukocytes other | 0.773 | 0 | 0 |
| Leukocytes | Abnormal leukocytes | 0.759 | 0 | 0 |
| Lymphocytes/leukocytes | Lymphocytes/leukocytes | 1.000 | 92 | 1,475,101 |
| Lymphocytes/leukocytes | Lymphocytes/Cells | 0.848 | 0 | 0 |
| Lymphocytes/leukocytes | Lymphoblasts/Leukocytes | 0.843 | 0 | 0 |
| Lymphocytes/leukocytes | Lymphoma cells/Leukocytes | 0.831 | 0 | 0 |
| Lymphocytes/leukocytes | Lymphocytes.immature/Leukocytes | 0.800 | 0 | 0 |
| Monocytes/leukocytes | Monocytes/leukocytes | 1.000 | 51 | 1,452,186 |
| Monocytes/leukocytes | Monocytes+Macrophages/leukocytes | 0.872 | 0 | 0 |
| Monocytes/leukocytes | Monocytes/Cells | 0.872 | 0 | 0 |
| Monocytes/leukocytes | Monocytoid cells/Leukocytes | 0.835 | 0 | 0 |
| Monocytes/leukocytes | Monocytes.abnormal/Leukocytes | 0.835 | 0 | 0 |
| Neutrophils/leukocytes | Neutrophils/leukocytes | 1.000 | 62 | 1,413,613 |
| Neutrophils/leukocytes | Neutrophils/Cells | 0.874 | 0 | 0 |
| Neutrophils/leukocytes | Granulocytes/leukocytes | 0.831 | 39 | 44,978 |
| Neutrophils/leukocytes | Heterophils/Leukocytes | 0.812 | 0 | 0 |
| Neutrophils/leukocytes | Neutrophils.immature/Leukocytes | 0.803 | 0 | 0 |
| Platelets | Platelets | 1.000 | 19 | 11,196,211 |
| Platelets | Platelet | 0.879 | 0 | 0 |
| Platelets | Platelets Small | 0.777 | 0 | 0 |
| Platelets | Platelets agranular | 0.753 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Mass | Mass | 1.000 | 5 | 10,152 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Number Concentration | Number Concentration | 1.000 | 507 | 49,434,956 |
| Number Fraction | Number Fraction | 1.000 | 482 | 8,246,054 |
| Number Fraction | Decimal number fraction | 0.787 | 1 | 6,152 |
| Number Fraction | Time Fraction | 0.765 | 0 | 0 |
| Ratio | Ratio | 1.000 | 88 | 786,172 |
| Volume | Volume | 1.000 | 20 | 17,488 |
| Volume Fraction | Volume Fraction | 1.000 | 44 | 11,697,579 |
| Volume Fraction | Volume Fraction Difference | 0.830 | 0 | 0 |
| Volume Fraction | Volume Ratio | 0.805 | 0 | 0 |
| Volume Fraction | Decimal volume fraction | 0.798 | 0 | 0 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Automated count | Automated count | 1.000 | 103 | 11,606,924 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1305 | b-pvk | % | 1036 | 0 | [12.98, 13, 13, 13, 13.02, 14, 14, 14, 14.9] | B -Perusverenkuva | Blood |  | Erythrocyte distribution width | Ratio |  | Blood | Qn | Point in time (spot) | FALSE |
| 1306 | b-pvk | e12/l | 180 | 0 |  | B -Perusverenkuva | Blood |  | Erythrocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1307 | b-pvk | e9/l | 180 | 0 |  | B -Perusverenkuva | Blood |  |  | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1308 | b-pvk | fl | 191 | 0 |  | B -Perusverenkuva | Blood |  | Erythrocyte mean volume | Volume |  | Blood | Qn | Point in time (spot) | FALSE |
| 1309 | b-pvk | form | 6 | 0 |  | B -Perusverenkuva | Blood |  |  |  |  | Blood |  | Point in time (spot) | FALSE |
| 1310 | b-pvk | g/l | 371 | 0 | [130.49, 135.97, 140.17, 143.56, 146.5, 149.94, 154.99, 161.16, 169.87] | B -Perusverenkuva | Blood |  | Hemoglobin | Mass Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1311 | b-pvk | paketti | 261 | 0 | [31329.79, 60496.46, 87166.96, 116360.34, 146168.26, 177141.71, 213025.07, 240401.38, 278743.21] | B -Perusverenkuva | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1312 | b-pvk | pg | 191 | 0 |  | B -Perusverenkuva | Blood |  | Erythrocyte mean corpuscular hemoglobin | Mass |  | Blood | Qn | Point in time (spot) | FALSE |
| 1313 | b-pvk |  | 1084645 | 100 |  | B -Perusverenkuva | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1314 | b-pvk(pi) |  | 994 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1315 | b-pvk+eo |  | 1355 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1316 | b-pvk+kd |  | 335 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1317 | b-pvk+ne |  | 301325 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1318 | b-pvk+ner |  | 551 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1319 | b-pvk+t | % | 16337 | 0 | [8.54, 11.43, 12.73, 13.01, 14.63, 21.66, 27.29, 34.08, 48.89] | B -Perusverenkuva ja trombosyytit | Blood |  |  | Number Fraction |  | Blood | Qn | Point in time (spot) | FALSE |
| 1320 | b-pvk+t | %g | 229 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Granulocytes/leukocytes | Number Fraction |  | Blood | Qn | Point in time (spot) | FALSE |
| 1321 | b-pvk+t | %l | 229 | 0 | [15.3, 18.86, 20.93, 24.39, 26.09, 27.9, 29.48, 31.36, 37.88] | B -Perusverenkuva ja trombosyytit | Blood |  | Lymphocytes/leukocytes | Number Fraction |  | Blood | Qn | Point in time (spot) | FALSE |
| 1322 | b-pvk+t | %m | 229 | 0 | [9, 10, 10.3, 10.73, 11, 11.47, 11.97, 12.55, 13.3] | B -Perusverenkuva ja trombosyytit | Blood |  | Monocytes/leukocytes | Number Fraction |  | Blood | Qn | Point in time (spot) | FALSE |
| 1323 | b-pvk+t | e12/l | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Erythrocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1324 | b-pvk+t | e9/l | 4647 | 0 | [0, 0, 0, 0, 0, 0, 2.04, 5.2, 8.91] | B -Perusverenkuva ja trombosyytit | Blood |  | Leukocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1325 | b-pvk+t | fl | 8 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Erythrocyte mean volume | Volume |  | Blood | Qn | Point in time (spot) | FALSE |
| 1326 | b-pvk+t | form | 361 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.89, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |  |  |  | Blood | Qn | Point in time (spot) | FALSE |
| 1327 | b-pvk+t | g/l | 2746 | 0 | [312.86, 315.11, 317.96, 319.16, 327.56, 334.19, 340.53, 346.44, 355.56] | B -Perusverenkuva ja trombosyytit | Blood |  | Erythrocyte mean corpuscular hemoglobin concentration | Mass Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1328 | b-pvk+t | l/l | 6 | 0 |  | B -Perusverenkuva ja trombosyytit | Blood |  | Hematocrit | Volume Fraction |  | Blood | Qn | Point in time (spot) | FALSE |
| 1329 | b-pvk+t | paketti | 269 | 0 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1330 | b-pvk+t | pg | 2769 | 0 | [29, 29.58, 30, 30.35, 31, 31.07, 32, 32.99, 34.11] | B -Perusverenkuva ja trombosyytit | Blood |  | Erythrocyte mean corpuscular hemoglobin | Mass |  | Blood | Qn | Point in time (spot) | FALSE |
| 1331 | b-pvk+t |  | 4547373 | 100 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva ja trombosyytit | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1332 | b-pvk+t+e |  | 1491 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1333 | b-pvk+t+n |  | 20012 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1334 | b-pvk+t+ne |  | 1150 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1335 | b-pvk+t+r |  | 713 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1336 | b-pvk+tk |  | 466 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1337 | b-pvk+tkd | % | 567 | 0 | [10.52, 11.98, 22.28, 26.53, 30.21, 32.92, 36.29, 39.43, 43.1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |  | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1338 | b-pvk+tkd | e9/l | 5 | 0 |  | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |  | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1339 | b-pvk+tkd |  | 347141 | 99.77 | [1, 1, 1, 1, 1, 1, 1, 1, 1] | B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1340 | b-pvk+tkd,baso | % | 4387 | 0 | [0.13, 0.2, 0.3, 0.34, 0.4, 0.5, 0.59, 0.7, 0.91] |  | Blood |  | Basophils/leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1341 | b-pvk+tkd,baso | e9/l | 4345 | 0 | [0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.05, 0.06] |  | Blood |  | Basophils/leukocytes | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1342 | b-pvk+tkd,baso |  | 28 | 96.43 |  |  | Blood |  | Basophils/leukocytes |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1343 | b-pvk+tkd,eo | % | 4389 | 0 | [0.28, 0.95, 1.44, 1.88, 2.38, 2.9, 3.5, 4.34, 5.77] |  | Blood |  | Eosinophils/leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1344 | b-pvk+tkd,eo | e9/l | 4355 | 0 | [0.02, 0.07, 0.1, 0.13, 0.16, 0.2, 0.24, 0.3, 0.39] |  | Blood |  | Eosinophils/leukocytes | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1345 | b-pvk+tkd,eo |  | 35 | 77.14 |  |  | Blood |  | Eosinophils/leukocytes |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1346 | b-pvk+tkd,eryt | e12/l | 4432 | 0 | [3.69, 4.01, 4.19, 4.32, 4.47, 4.6, 4.71, 4.86, 5.08] |  | Blood |  | Erythrocytes | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1347 | b-pvk+tkd,eryt |  | 28 | 82.14 |  |  | Blood |  | Erythrocytes |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1348 | b-pvk+tkd,hb | g/l | 4431 | 0 | [109.63, 119.87, 125.6, 130.31, 134.35, 137.72, 141.31, 145.38, 151.58] |  | Blood |  | Hemoglobin | Mass Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1349 | b-pvk+tkd,hb |  | 28 | 82.14 |  |  | Blood |  | Hemoglobin |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1350 | b-pvk+tkd,hkr | osuus | 4430 | 0 | [0.34, 0.36, 0.38, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45] |  | Blood |  | Hematocrit | Volume Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1351 | b-pvk+tkd,hkr |  | 28 | 82.14 |  |  | Blood |  | Hematocrit |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1352 | b-pvk+tkd,ig | % | 4380 | 0 | [0, 0.1, 0.18, 0.2, 0.2, 0.24, 0.3, 0.4, 0.66] |  | Blood |  | Immature granulocytes/leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1353 | b-pvk+tkd,ig | e9/l | 4329 | 0 | [0, 0.01, 0.01, 0.01, 0.01, 0.02, 0.02, 0.03, 0.06] |  | Blood |  | Immature granulocytes/leukocytes | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1354 | b-pvk+tkd,ig |  | 27 | 100 |  |  | Blood |  | Immature granulocytes/leukocytes |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1355 | b-pvk+tkd,leuk | e9/l | 4441 | 0 | [4.64, 5.29, 5.87, 6.47, 7.06, 7.73, 8.41, 9.34, 10.91] |  | Blood |  | Leukocytes | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1356 | b-pvk+tkd,leuk |  | 23 | 100 | [4.39, 5.06, 5.62, 6.11, 6.7, 7.36, 7.96, 8.73, 10.19] |  | Blood |  | Leukocytes |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1357 | b-pvk+tkd,lymph | % | 4402 | 0 | [14.51, 18.87, 22.17, 24.95, 27.85, 30.77, 33.85, 37.68, 42.79] |  | Blood |  | Lymphocytes/leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1358 | b-pvk+tkd,lymph | e9/l | 4366 | 0 | [1.07, 1.3, 1.5, 1.68, 1.87, 2.05, 2.28, 2.59, 3.03] |  | Blood |  | Lymphocytes/leukocytes | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1359 | b-pvk+tkd,lymph |  | 39 | 71.79 |  |  | Blood |  | Lymphocytes/leukocytes |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1360 | b-pvk+tkd,mch | pg | 4427 | 0 | [27.35, 28.81, 29.01, 30, 30, 30.98, 31, 31.99, 32.41] |  | Blood |  | Erythrocyte mean corpuscular hemoglobin | Mass | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1361 | b-pvk+tkd,mch |  | 26 | 88.46 |  |  | Blood |  | Erythrocyte mean corpuscular hemoglobin |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1362 | b-pvk+tkd,mchc | g/l | 4422 | 0 | [316.84, 322.97, 327.09, 330.49, 333.34, 336.5, 339.82, 343.59, 348.74] |  | Blood |  | Erythrocyte mean corpuscular hemoglobin concentration | Mass Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1363 | b-pvk+tkd,mchc |  | 27 | 85.19 |  |  | Blood |  | Erythrocyte mean corpuscular hemoglobin concentration |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1364 | b-pvk+tkd,mcv | fl | 4432 | 0 | [83.81, 86.19, 87.9, 89.02, 90.1, 91.52, 92.95, 94.05, 96.04] |  | Blood |  | Erythrocyte mean volume | Volume | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1365 | b-pvk+tkd,mcv |  | 25 | 92 |  |  | Blood |  | Erythrocyte mean volume |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1366 | b-pvk+tkd,mono | % | 4397 | 0 | [6.39, 7.45, 8.16, 8.78, 9.38, 10.01, 10.67, 11.64, 13.06] |  | Blood |  | Monocytes/leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1367 | b-pvk+tkd,mono | e9/l | 4364 | 0 | [0.41, 0.48, 0.54, 0.59, 0.65, 0.7, 0.78, 0.88, 1.03] |  | Blood |  | Monocytes/leukocytes | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1368 | b-pvk+tkd,mono |  | 32 | 84.38 |  |  | Blood |  | Monocytes/leukocytes |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1369 | b-pvk+tkd,neut | % | 4407 | 0 | [43.3, 48.04, 51.9, 55.37, 58.56, 61.78, 65.36, 69.3, 74.25] |  | Blood |  | Neutrophils/leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1370 | b-pvk+tkd,neut | e9/l | 4373 | 0 | [2.18, 2.67, 3.11, 3.55, 4, 4.52, 5.12, 5.94, 7.37] |  | Blood |  | Neutrophils/leukocytes | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1371 | b-pvk+tkd,neut |  | 34 | 82.35 |  |  | Blood |  | Neutrophils/leukocytes |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1372 | b-pvk+tkd,rdw | % | 4298 | 0 | [12.5, 12.85, 13.17, 13.49, 13.79, 14.12, 14.57, 15.17, 16.52] |  | Blood |  | Erythrocyte distribution width | Ratio | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1373 | b-pvk+tkd,rdw |  | 30 | 76.67 |  |  | Blood |  | Erythrocyte distribution width |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1374 | b-pvk+tkd,trom | eg/l | 4413 | 0 | [163.91, 190.28, 209.92, 228.62, 246.86, 267.53, 293.03, 326.64, 371.27] |  | Blood |  | Platelets | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1375 | b-pvk+tkd,trom |  | 31 | 74.19 |  |  | Blood |  | Platelets |  | Automated count | Blood |  | Point in time (spot) | FALSE |
| 1376 | b-pvk+tmd | % | 108 | 0 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  |  | Number Fraction |  | Blood | Qn | Point in time (spot) | FALSE |
| 1377 | b-pvk+tmd |  | 31394 | 99.96 |  | B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää) | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1378 | b-pvk-päi |  | 120 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1379 | b-pvk-t |  | 1651 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1380 | b-pvk-tkd |  | 5227 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1381 | b-pvkt |  | 540592 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1382 | b-pvkt+re |  | 3032 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1383 | b-pvktkdr |  | 6444 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1384 | b-pvktmdl |  | 275 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1385 | b-pvktmdp |  | 1012 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1386 | b-pvktnee |  | 9809 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1387 | b-pvktp |  | 5212 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1388 | b-tvk | % | 505 | 0 | [0, 0, 0, 0, 1, 2.55, 12.33, 37.94, 62.13] | B -Täydellinen verenkuva | Blood |  |  | Number Fraction |  | Blood | Qn | Point in time (spot) | FALSE |
| 1389 | b-tvk | e9/l | 368 | 0 | [0.03, 0.03, 0.04, 0.04, 0.05, 0.05, 0.06, 0.07, 0.09] | B -Täydellinen verenkuva | Blood |  |  | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1390 | b-tvk | fl | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  | Erythrocyte mean volume | Volume |  | Blood | Qn | Point in time (spot) | FALSE |
| 1391 | b-tvk | form | 11 | 0 |  | B -Täydellinen verenkuva | Blood |  |  |  |  | Blood |  | Point in time (spot) | FALSE |
| 1392 | b-tvk | g/l | 19 | 0 |  | B -Täydellinen verenkuva | Blood |  |  | Mass Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1393 | b-tvk | paketti | 22 | 0 |  | B -Täydellinen verenkuva | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1394 | b-tvk | pg | 17 | 0 |  | B -Täydellinen verenkuva | Blood |  | Erythrocyte mean corpuscular hemoglobin | Mass |  | Blood | Qn | Point in time (spot) | FALSE |
| 1395 | b-tvk |  | 466809 | 100 |  | B -Täydellinen verenkuva | Blood |  |  |  |  | Blood |  |  | TRUE |
| 1396 | b-tvk+r |  | 465 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |

