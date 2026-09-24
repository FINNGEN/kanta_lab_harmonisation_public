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
Here is group 79.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Albumin | Albumin | 1.000 | 80 | 2,081,573 |
| Albumin | Albumin in serum | 0.779 | 0 | 0 |
| Albumin | Albumin ug | 0.752 | 0 | 0 |
| Albumin/Creatinine | Albumin/Creatinine | 1.000 | 31 | 588,386 |
| Albumin/Creatinine | Microalbumin/Creatinine ratio panel | 0.782 | 0 | 0 |
| Albumin/Creatinine | Alpha-1-Microglobulin/Creatinine | 0.766 | 0 | 0 |
| Albumin/Creatinine | Alpha aminobutyrate/Creatinine | 0.756 | 0 | 0 |
| Bacteria | Bacteria | 1.000 | 32 | 3,027,518 |
| Calcium/Creatinine | Calcium/Creatinine | 1.000 | 1 | 76 |
| Calcium/Creatinine | Creatinine/Calcium | 0.872 | 0 | 0 |
| Calcium/Creatinine | Citrate/Creatinine | 0.796 | 0 | 0 |
| Calcium/Creatinine | Chloride/Creatinine | 0.795 | 0 | 0 |
| Calcium/Creatinine | Oxalate/Creatinine | 0.793 | 0 | 0 |
| Casts | Casts | 1.000 | 20 | 419,520 |
| Casts | Casts panel | 0.809 | 0 | 0 |
| Casts | Casts type not specified | 0.758 | 0 | 0 |
| Cells.other | (none scored >= 0.75) |  |  |  |
| Creatinine | Creatinine | 1.000 | 80 | 9,559,920 |
| Epithelial cells | Epithelial cells | 1.000 | 24 | 278,115 |
| Epithelial cells | Epithelial cells/Cells | 0.887 | 0 | 0 |
| Epithelial cells | Epithelial cells.squamous | 0.792 | 4 | 227,680 |
| Epithelial cells | Epithelial cells.squamous/Cells | 0.790 | 0 | 0 |
| Epithelial cells | Epithelial cells.ciliated | 0.775 | 0 | 0 |
| Erythrocytes | Erythrocytes | 1.000 | 64 | 12,187,960 |
| Leukocytes | Leukocytes | 1.000 | 126 | 12,024,159 |
| Leukocytes | Leukocytes other | 0.773 | 0 | 0 |
| Leukocytes | Abnormal leukocytes | 0.759 | 0 | 0 |
| Macrophages | Macrophages | 1.000 | 3 | 226 |
| Macrophages | Macrophages/Cells | 0.820 | 0 | 0 |
| Macrophages | Macrophages/leukocytes | 0.750 | 2 | 43 |
| Other | Other | 1.000 | 0 | 0 |
| Other | Others | 0.861 | 0 | 0 |
| pH | pH | 1.000 | 92 | 2,272,494 |
| Protein/Creatinine | Protein/Creatinine | 1.000 | 3 | 3,428 |
| Protein/Creatinine | Creatinine/Protein | 0.881 | 0 | 0 |
| Protein/Creatinine | Proline/Creatinine | 0.799 | 0 | 0 |
| Protein/Creatinine | Potassium/Creatinine | 0.789 | 0 | 0 |
| Protein/Creatinine | Phosphate/Creatinine | 0.784 | 1 | 40 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Mass Rate | Mass Rate | 1.000 | 32 | 47,943 |
| Mass Rate | Mass Rate Range | 0.843 | 0 | 0 |
| Mass Rate | Mass or Substance Rate | 0.778 | 2 | 118 |
| Number Concentration | Number Concentration | 1.000 | 507 | 49,434,956 |
| pH | (none scored >= 0.75) |  |  |  |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Ratio | Ratio | 1.000 | 88 | 786,172 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Test strip | Test strip | 1.000 | 79 | 4,294,769 |
| Test strip | Test strip manual | 0.843 | 0 | 0 |
| Test strip | Test strip automated | 0.836 | 3 | 687,408 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Urine | Urine | 1.000 | 586 | 16,080,701 |
| Urine sediment | Urine sediment | 1.000 | 40 | 269,519 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1161 | cu-alb-mi | ug/min | 7258 | 0 | [2, 3.03, 4.27, 6.2, 9.73, 17, 34.68, 78.84, 221.36] | cU-Albumiini, mikroalbuminuria | Collected urine | Micro | Albumin | Mass Rate |  | Urine | Qn |  | FALSE |
| 1162 | cu-alb-mi |  | 1830 | 100 | [2, 3.76, 5.36, 7.63, 12.69, 25, 48.21, 105.09, 287.3] | cU-Albumiini, mikroalbuminuria | Collected urine | Micro | Albumin | Mass Rate |  | Urine | Qn |  | FALSE |
| 1163 | nu-alb-mi | mg/12h | 12 | 0 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin | Mass Rate |  | Urine | Qn | 12 hours | FALSE |
| 1164 | nu-alb-mi | ug/min | 155 | 0 | [5, 8.88, 19.76, 34.34, 70.38, 107.14, 173.45, 320, 537.6] | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin | Mass Rate |  | Urine | Qn | Night time | FALSE |
| 1165 | nu-alb-mi |  | 157 | 68.15 |  | nU-Albumiini, mikroalbuminuria | Night (morning) urine | Micro | Albumin | Mass Rate |  | Urine | Qn | Night time | FALSE |
| 1166 | nu-albkre | mg/mmol | 438 | 0 | [0.3, 0.49, 0.65, 0.9, 1.28, 2, 4.09, 8.45, 23.14] |  | Night (morning) urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Night time | FALSE |
| 1167 | nu-albkre |  | 2191 | 62.12 | [0.39, 0.5, 0.69, 0.87, 1.2, 1.82, 2.88, 6.31, 19.04] |  | Night (morning) urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Night time | FALSE |
| 1168 | nu-albkrea | mg/mmol | 20929 | 0 | [0.33, 0.49, 0.66, 0.9, 1.32, 2.09, 3.79, 8.38, 27.64] |  | Night (morning) urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Night time | FALSE |
| 1169 | nu-albkrea |  | 26197 | 100 | [0.21, 0.36, 0.51, 0.7, 1.05, 1.62, 2.84, 6.09, 18.42] |  | Night (morning) urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Night time | FALSE |
| 1170 | u-a1mikre |  | 113 | 12.39 | [1, 2.43, 3.5, 6.91, 9.03, 11.18, 14.78, 18.06, 35.1] |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1171 | u-alb-0 |  | 992 | 100 |  |  | Urine |  | Albumin | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 1172 | u-alb-lb | mg/l | 70 | 0 |  |  | Urine |  | Albumin | Mass Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 1173 | u-alb-lb |  | 50 | 98 |  |  | Urine |  | Albumin | Mass Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 1174 | u-alb-mi | mg/l | 7488 | 0 | [3.01, 4.02, 5.51, 7.59, 11.17, 18.74, 35.95, 87.24, 325.25] |  | Urine | Micro | Albumin | Mass Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 1175 | u-alb-mi |  | 3031 | 100 | [1.94, 3, 4.21, 6.03, 8.61, 11.71, 20.86, 50.08, 291.2] |  | Urine | Micro | Albumin | Mass Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 1176 | u-alb-o | estimate | 161670 | 2.95 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 1177 | u-alb-o | form | 287 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 1178 | u-alb-o |  | 312867 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] | U -Albumiini (kval) | Urine | Qualitative test (also semi-quantitative) | Albumin | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 1179 | u-alb/kre | g/mol | 142 | 0 | [1.78, 3.02, 3.92, 5.37, 8.28, 16.58, 32.75, 51.54, 140.31] |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1180 | u-alb/kre | mg/mmol | 2591 | 0 | [0.3, 0.42, 0.6, 0.84, 1.25, 2.07, 3.99, 8.87, 30.32] |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1181 | u-alb/kre |  | 2491 | 96.87 |  |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1182 | u-alb/kre,u-alb |  | 247 | 39.27 | [6.13, 7.52, 9.27, 12.32, 15.29, 19.26, 37.25, 66.2, 187.73] |  | Urine |  | Albumin | Mass Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 1183 | u-alb/kre,u-alb/krea | mg/mmol | 148 | 0 | [0.59, 0.74, 0.99, 1.41, 1.89, 3.03, 5.25, 10.21, 22.45] |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1184 | u-alb/kre,u-alb/krea |  | 99 | 96.97 |  |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1185 | u-alb/kre,u-krea |  | 247 | 0.81 | [3.67, 4.76, 5.83, 6.76, 7.67, 8.61, 9.82, 10.75, 12.92] |  | Urine |  | Creatinine | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 1186 | u-alb/krea | g/mol | 49 | 0 |  |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1187 | u-alb/krea | mg/mmol | 879 | 0 | [0.29, 0.4, 0.52, 0.73, 1.06, 1.82, 2.87, 5.79, 14.42] |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1188 | u-alb/krea |  | 812 | 100 |  |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1189 | u-albkre | g/mol | 10 | 0 |  | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1190 | u-albkre | mg/mmol | 294883 | 0.26 | [0.31, 0.5, 0.7, 1.03, 1.68, 3, 6.29, 16.55, 61.66] | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1191 | u-albkre |  | 200553 | 100 | [0.3, 0.4, 0.59, 0.81, 1.18, 1.92, 3.44, 7.04, 20.74] | U -Albumiinin ja kreatiniinin suhde | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1192 | u-albkrea | mg/mmol | 10590 | 0 | [0.3, 0.44, 0.59, 0.73, 0.97, 1.31, 1.85, 3.03, 9.45] |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1193 | u-albkrea | mg/mmol/l | 81 | 0 |  |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1194 | u-albkrea |  | 15486 | 73.32 | [0.4, 0.65, 1.06, 1.98, 3.39, 4.96, 7.85, 14.4, 37.26] |  | Urine |  | Albumin/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1195 | u-alvhu4a |  | 760 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 1196 | u-alvhu5b |  | 912 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 1197 | u-alvhu6a |  | 1273 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 1198 | u-cakre |  | 106 | 48.11 |  |  | Urine |  | Calcium/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1199 | u-happamuus |  | 204 | 0.49 | [6.5, 6.5, 7, 7, 7, 7, 7.5, 7.5, 8] |  | Urine |  | pH | pH |  | Urine | Qn | Point in time (spot) | FALSE |
| 1200 | u-prokre | g/mol | 973 | 0.41 | [5.03, 6.97, 8.99, 11.1, 14.55, 19.47, 27.35, 52.28, 161.87] | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1201 | u-prokre | mg/mmol | 1813 | 0 | [9.66, 12.56, 16.16, 21.33, 30.42, 49.33, 102.26, 292.89, 1027.72] | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1202 | u-prokre |  | 646 | 99.85 |  | U -Proteiinin ja kreatiniinin suhde | Urine |  | Protein/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1203 | u-protkre | mg/mmol | 121 | 0 |  |  | Urine |  | Protein/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1204 | u-protkre |  | 9 | 100 |  |  | Urine |  | Protein/Creatinine | Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 1205 | u-sakka,bakt |  | 330 | 99.39 |  |  | Urine |  | Bacteria | Presence or Threshold |  | Urine sediment | Ord | Point in time (spot) | FALSE |
| 1206 | u-sakka,epit |  | 1251 | 71.3 | [0, 0, 0, 0, 0, 0, 0.33, 1, 2] |  | Urine |  | Epithelial cells | Number Concentration |  | Urine sediment | SemiQn | Point in time (spot) | FALSE |
| 1207 | u-sakka,eryt | u/field | 1247 | 0 | [0, 1, 1, 1, 1, 2, 2.67, 4, 7] |  | Urine |  | Erythrocytes | Number Concentration |  | Urine sediment | SemiQn | Point in time (spot) | FALSE |
| 1208 | u-sakka,eryt |  | 121 | 100 | [0, 0, 0, 0, 0.62, 1, 2, 3.04, 7.71] |  | Urine |  | Erythrocytes | Number Concentration |  | Urine sediment | SemiQn | Point in time (spot) | FALSE |
| 1209 | u-sakka,leuk | u/field | 1087 | 0 | [0, 0, 0, 0, 0, 1, 1, 2.25, 5] |  | Urine |  | Leukocytes | Number Concentration |  | Urine sediment | SemiQn | Point in time (spot) | FALSE |
| 1210 | u-sakka,leuk |  | 261 | 100 | [0, 0, 0, 0, 0, 0.98, 2, 4.88, 11.66] |  | Urine |  | Leukocytes | Number Concentration |  | Urine sediment | SemiQn | Point in time (spot) | FALSE |
| 1211 | u-sakka,lier |  | 367 | 5.72 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Casts | Number Concentration |  | Urine sediment | SemiQn | Point in time (spot) | FALSE |
| 1212 | u-sakka,makrof |  | 367 | 4.63 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Macrophages | Number Concentration |  | Urine sediment | SemiQn | Point in time (spot) | FALSE |
| 1213 | u-sakka,muuta |  | 456 | 25.88 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Other | Finding |  | Urine sediment | Nar | Point in time (spot) | FALSE |
| 1214 | u-solut,muut |  | 136 | 88.24 |  |  | Urine |  | Cells.other | Finding |  | Urine | Nar | Point in time (spot) | FALSE |

