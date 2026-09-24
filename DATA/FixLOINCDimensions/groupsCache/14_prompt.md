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
Here is group 14.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| C reactive protein | C reactive protein | 1.000 | 197 | 6,881,941 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Immunoassay | Immunoassay | 1.000 | 164 | 322,567 |
| Rapid immunoassay | Rapid immunoassay | 1.000 | 1 | 15,478 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Blood capillary | Blood capillary | 1.000 | 121 | 787,125 |
| Blood capillary | Blood capillary^Fetus | 0.763 | 0 | 0 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 23 | b-c-reaktiivinenproteiini | mg/l | 29 | 0 |  |  | Blood |  | C reactive protein | Mass Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 24 | b-c-reaktiivinenproteiini |  | 262 | 44.27 | [6, 7.5, 10.67, 13.8, 18.67, 27.69, 37.44, 56, 84] |  | Blood |  | C reactive protein | Mass Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 25 | b-c-reaktiivinenproteiinipika |  | 300 | 37 | [7, 10.22, 14.84, 20.3, 29.2, 37.52, 52.47, 75.48, 99.1] |  | Blood |  | C reactive protein | Mass Concentration | Rapid immunoassay | Blood | Qn | Point in time (spot) | FALSE |
| 26 | b-c-resktiivinenproteiini | mg/l | 1201 | 0 | [6, 8.11, 11.16, 14.7, 19.67, 26.61, 38.65, 58.3, 91.79] |  | Blood |  | C reactive protein | Mass Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 27 | b-c-resktiivinenproteiini |  | 802 | 92.39 |  |  | Blood |  | C reactive protein |  |  | Blood |  | Point in time (spot) | FALSE |
| 28 | c-reaktiivinenproteiini | 1 | 925 | 0 | [6.19, 8.89, 11.99, 16.88, 23.76, 35.33, 49.12, 74.41, 108.21] |  |  |  | C reactive protein | Mass Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 29 | c-reaktiivinenproteiini | mg/l | 7963 | 0 | [4.01, 6.22, 9.5, 14.46, 23.15, 35.25, 51.85, 77.94, 126.36] |  |  |  | C reactive protein | Mass Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 30 | c-reaktiivinenproteiini |  | 7083 | 90.23 | [6.55, 8.84, 11.73, 17.15, 24.37, 37.67, 52.72, 72.92, 107.1] |  |  |  | C reactive protein | Mass Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 31 | c-reaktiivinenproteiini(4594p-crp) | mg/l | 143 | 0 | [1, 1.79, 2, 2, 3, 4, 5, 6, 12.8] |  |  |  | C reactive protein | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 32 | c-reaktiivinenproteiini(4594p-crp) |  | 74 | 100 |  |  |  |  | C reactive protein |  |  | Plasma |  | Point in time (spot) | FALSE |
| 33 | c-reaktiivinenproteiini(crp) | mg/l | 381 | 0 | [1.23, 1.51, 1.92, 2.62, 3.36, 4.75, 6.13, 9.98, 21.06] |  |  |  | C reactive protein | Mass Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 34 | c-reaktiivinenproteiini(crp) |  | 250 | 100 |  |  |  |  | C reactive protein |  |  |  |  | Point in time (spot) | FALSE |
| 35 | c-reaktiivinenproteiini(p-crp) | mg/l | 500 | 0 | [1, 2, 2, 2.85, 3.14, 4.26, 5.94, 8.93, 19.54] |  |  |  | C reactive protein | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 36 | c-reaktiivinenproteiini(p-crp) |  | 261 | 100 |  |  |  |  | C reactive protein |  |  | Plasma |  | Point in time (spot) | FALSE |
| 37 | c-reaktiivinenproteiini,herkkä | mg/l | 254 | 0 | [0.22, 0.41, 0.57, 0.84, 1.15, 1.65, 2.42, 3.86, 6.33] |  |  |  | C reactive protein | Mass Concentration | Immunoassay |  | Qn | Point in time (spot) | FALSE |
| 38 | c-reaktiivinenproteiini,herkkä |  | 18 | 94.44 |  |  |  |  | C reactive protein |  | Immunoassay |  |  | Point in time (spot) | FALSE |
| 39 | c-reaktiivinenproteiini,herkkä,seerumista | mg/l | 7396 | 0 | [0.28, 0.41, 0.6, 0.78, 1.03, 1.34, 1.83, 2.72, 4.64] |  |  |  | C reactive protein | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 40 | c-reaktiivinenproteiini,herkkä,seerumista |  | 36 | 83.33 |  |  |  |  | C reactive protein |  | Immunoassay | Serum |  | Point in time (spot) | FALSE |
| 41 | c-reaktiivinenproteiini,pika | mg/l | 111 | 0 | [5, 5.05, 6.2, 8.27, 11.67, 14.3, 22.37, 36.1, 57] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 42 | c-reaktiivinenproteiini,pika |  | 49 | 100 |  |  |  |  | C reactive protein |  | Rapid immunoassay |  |  | Point in time (spot) | FALSE |
| 43 | c-reaktiivinenproteiini,pika,tehdäänitse | mg/l | 997 | 0 | [5, 5, 6.35, 8.12, 10.93, 14.99, 21.14, 34.44, 53.73] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 44 | c-reaktiivinenproteiini,pika,tehdäänitse |  | 820 | 99.27 |  |  |  |  | C reactive protein |  | Rapid immunoassay |  |  | Point in time (spot) | FALSE |
| 45 | c-reaktiivinenproteiini,pikatesti,veri | mg/l | 174 | 0 | [6, 7, 8.95, 10.5, 16.42, 22.45, 35.5, 53.5, 98.67] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay | Blood | Qn | Point in time (spot) | FALSE |
| 46 | c-reaktiivinenproteiini,pikatesti,veri |  | 1656 | 42.69 | [6.55, 9.61, 13.21, 19.27, 27.67, 39.17, 52.81, 73.29, 109.39] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay | Blood | Qn | Point in time (spot) | FALSE |
| 47 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) | mg/l | 803 | 0 | [4.99, 5.34, 7.17, 9.24, 13.4, 18.77, 28.88, 45.54, 76.31] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay | Blood | Qn | Point in time (spot) | FALSE |
| 48 | c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt) |  | 240 | 100 |  |  |  |  | C reactive protein |  | Rapid immunoassay | Blood |  | Point in time (spot) | FALSE |
| 49 | c-reaktiivinenproteiini,pikatutkimus | mg/l | 106 | 0 | [7, 12, 15.43, 21.6, 30.72, 39.4, 56.9, 87, 115.33] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 50 | c-reaktiivinenproteiini,pikatutkimus |  | 66 | 100 |  |  |  |  | C reactive protein |  | Rapid immunoassay |  |  | Point in time (spot) | FALSE |
| 51 | c-reaktiivinenproteiini,plasmasta,vieritesti | mg/l | 699 | 0 | [5.17, 7.91, 10.75, 16.58, 23.68, 33.24, 48.01, 64.98, 99.29] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 52 | c-reaktiivinenproteiini,plasmasta,vieritesti |  | 274 | 94.89 |  |  |  |  | C reactive protein |  | Rapid immunoassay | Plasma |  | Point in time (spot) | FALSE |
| 53 | c-reaktiivinenproteiini,tk:ntekemä |  | 1605 | 13.4 | [2.23, 4.3, 7.78, 12.46, 19.91, 29.72, 46.58, 66.7, 98.89] |  |  |  | C reactive protein | Mass Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 54 | c-reaktiivinenproteiini,vieritesti | mg/l | 47 | 0 |  |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 55 | c-reaktiivinenproteiini,vieritesti |  | 944 | 23.62 | [3.08, 5.45, 7.93, 11.11, 14.9, 20.87, 29.7, 49.04, 81.9] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 56 | c-reaktiivinenproteiini,vieritutkimus | mg/l | 525 | 0 | [5, 6.72, 8.66, 12.22, 15.93, 22.09, 35.26, 59.08, 89.7] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 57 | c-reaktiivinenproteiini,vieritutkimus |  | 631 | 58.8 | [6.41, 9.32, 15.53, 22.99, 35.64, 49.47, 62.97, 81.83, 113.06] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 58 | c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 1205 | 0 |  |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 59 | c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 318 | 100 | [4.71, 7.37, 11.52, 16.21, 23.22, 31.65, 45.13, 65.98, 97.07] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 60 | c-reaktiivinenproteiini,vieritutkimusnordlab | mg/l | 92 | 0 | [5, 6, 8, 10.7, 12.75, 16.2, 21, 31.5, 47] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 61 | c-reaktiivinenproteiini,vieritutkimusnordlab |  | 99 | 100 |  |  |  |  | C reactive protein |  | Rapid immunoassay |  |  | Point in time (spot) | FALSE |
| 62 | c-reaktiivinenproteiini-pika(4594crp-pika) | mg/l | 136 | 0 | [5, 5.32, 7, 9, 11.15, 14.57, 19, 33.2, 47.3] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 63 | c-reaktiivinenproteiini-pika(4594crp-pika) |  | 47 | 100 |  |  |  |  | C reactive protein |  | Rapid immunoassay |  |  | Point in time (spot) | FALSE |
| 64 | c-reaktiivinenproteiini-pika(crp-pika) | mg/l | 1488 | 0 | [5, 6.88, 7, 7.34, 10.21, 14.71, 21.39, 32, 54.73] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 65 | c-reaktiivinenproteiini-pika(crp-pika) |  | 505 | 99.8 |  |  |  |  | C reactive protein |  | Rapid immunoassay |  |  | Point in time (spot) | FALSE |
| 66 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä | mg/l | 1826 | 0 | [1.75, 3.02, 5.68, 9.52, 14.27, 22.77, 34.19, 57.29, 89.46] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay | Blood capillary | Qn | Point in time (spot) | FALSE |
| 67 | cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä |  | 497 | 46.88 | [1.2, 1.53, 2.21, 2.84, 3.97, 4.8, 6.15, 7.51, 9.1] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay | Blood capillary | Qn | Point in time (spot) | FALSE |
| 68 | fs-c-reaktiivinenproteiini | mg/l | 241 | 0 |  |  | Fasting serum |  | C reactive protein | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 69 | fs-c-reaktiivinenproteiini |  | 184 | 100 |  |  | Fasting serum |  | C reactive protein |  |  | Serum |  | Point in time (spot) | FALSE |
| 70 | p-c-reaktiininenproteiini,vieritutkimus | mg/l | 258 | 0 | [5.85, 8.85, 11.14, 17.24, 24.49, 35.17, 49.34, 67.54, 96.38] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 71 | p-c-reaktiininenproteiini,vieritutkimus |  | 224 | 100 |  |  | Plasma |  | C reactive protein |  | Rapid immunoassay | Plasma |  | Point in time (spot) | FALSE |
| 72 | p-c-reaktiivinenproteiini | mg/l | 41046 | 0 | [4.18, 7.12, 11.73, 18.09, 27.46, 40.11, 58.4, 87.78, 141.39] |  | Plasma |  | C reactive protein | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 73 | p-c-reaktiivinenproteiini |  | 24714 | 99.73 |  |  | Plasma |  | C reactive protein |  |  | Plasma |  | Point in time (spot) | FALSE |
| 74 | p-c-reaktiivinenproteiini(kval) | mg/l | 187 | 0 | [6.14, 9.01, 13.88, 18.86, 24.62, 33.54, 47.21, 67.37, 102.4] |  | Plasma |  | C reactive protein | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 75 | p-c-reaktiivinenproteiini(kval) |  | 142 | 100 |  |  | Plasma |  | C reactive protein |  |  | Plasma |  | Point in time (spot) | FALSE |
| 76 | p-c-reaktiivinenproteiini(kval)␤ | mg/l | 111 | 0 |  |  | Plasma |  | C reactive protein | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 77 | p-c-reaktiivinenproteiini(kval)␤ |  | 130 | 100 |  |  | Plasma |  | C reactive protein |  |  | Plasma |  | Point in time (spot) | FALSE |
| 78 | p-c-reaktiivinenproteiini(pikanäyte) | mg/l | 6 | 0 |  |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 79 | p-c-reaktiivinenproteiini(pikanäyte) |  | 352 | 17.33 | [1.52, 2.59, 4.86, 7.54, 12.38, 20.91, 32.04, 56.93, 83.62] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 80 | p-c-reaktiivinenproteiini,crp | mg/l | 110 | 0 |  |  | Plasma |  | C reactive protein | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 81 | p-c-reaktiivinenproteiini,crp |  | 8 | 62.5 |  |  | Plasma |  | C reactive protein |  |  | Plasma |  | Point in time (spot) | FALSE |
| 82 | p-c-reaktiivinenproteiini,hoitoyksikkö | 1 | 40 | 0 |  |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 83 | p-c-reaktiivinenproteiini,hoitoyksikkö | alle | 5 | 0 |  |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | SemiQn | Point in time (spot) | FALSE |
| 84 | p-c-reaktiivinenproteiini,hoitoyksikkö | mg/l | 81 | 0 | [8, 11, 13, 16.2, 22.25, 33.7, 48, 64, 131] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 85 | p-c-reaktiivinenproteiini,hoitoyksikkö |  | 156 | 63.46 | [6, 8, 12, 14, 26, 32, 40, 60, 120] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 86 | p-c-reaktiivinenproteiini,pikatesti | mg/l | 190 | 0 |  |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 87 | p-c-reaktiivinenproteiini,pikatesti |  | 3095 | 41.23 | [6.43, 8.8, 12.04, 15.76, 21.17, 29.16, 41.93, 63.64, 96.9] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 88 | p-c-reaktiivinenproteiini,vieritutkimus | mg/l | 53 | 0 |  |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 89 | p-c-reaktiivinenproteiini,vieritutkimus |  | 122 | 50.82 |  |  | Plasma |  | C reactive protein |  | Rapid immunoassay | Plasma |  | Point in time (spot) | FALSE |
| 90 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta | mg/l | 202 | 0 | [4.03, 6.98, 10.47, 16.6, 21.86, 29.42, 49.79, 68.66, 100] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 91 | p-c-reaktiivinenproteiini,vieritutkimus,plasmasta |  | 120 | 71.67 |  |  | Plasma |  | C reactive protein |  | Rapid immunoassay | Plasma |  | Point in time (spot) | FALSE |
| 92 | p-c-reaktiivinenproteiini.pika |  | 316 | 20.25 | [3.75, 6.98, 11.68, 15.55, 24.24, 38.44, 58.74, 89.38, 117.91] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 93 | p-c-reaktiivinenproteiinipikahoitoyksiköt | mg/l | 4601 | 0 | [5.2, 7.99, 12.13, 17.43, 25.81, 37.54, 54.45, 78.12, 113.86] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 94 | p-c-reaktiivinenproteiinipikahoitoyksiköt |  | 1925 | 80.52 | [1.18, 1.4, 1.83, 2.44, 3.17, 4.31, 5.83, 6.68, 8.76] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 95 | p-c-reaktiivinenproteiinipikamittari |  | 399 | 36.09 | [7, 9.06, 12.92, 21.23, 28.43, 42.17, 58.76, 81.22, 122.07] |  | Plasma |  | C reactive protein | Mass Concentration | Rapid immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 96 | pikatesti,c-reaktiivinenproteiini | mg/l | 315 | 0 | [6, 7.85, 10.56, 14.36, 20.22, 31.25, 44.62, 61.43, 91.59] |  |  |  | C reactive protein | Mass Concentration | Rapid immunoassay |  | Qn | Point in time (spot) | FALSE |
| 97 | pikatesti,c-reaktiivinenproteiini |  | 386 | 100 |  |  |  |  | C reactive protein |  | Rapid immunoassay |  |  | Point in time (spot) | FALSE |
| 98 | plasmanc-reaktiivinenproteiiniosoitus | 1 | 36 | 0 |  |  |  |  | C reactive protein | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 99 | plasmanc-reaktiivinenproteiiniosoitus | mg/l | 3255 | 0 | [6.24, 8.99, 12.45, 17.72, 25.65, 35.96, 50.8, 70.36, 106.56] |  |  |  | C reactive protein | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 100 | plasmanc-reaktiivinenproteiiniosoitus |  | 2589 | 98.42 |  |  |  |  | C reactive protein |  |  | Plasma |  | Point in time (spot) | FALSE |
| 101 | s-c-reaktiivinenproteiini | mg/l | 773 | 0 | [0.4, 0.73, 1.08, 1.43, 1.93, 2.88, 4.71, 7.16, 16.64] |  | Serum |  | C reactive protein | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 102 | s-c-reaktiivinenproteiini |  | 121 | 100 |  |  | Serum |  | C reactive protein |  |  | Serum |  | Point in time (spot) | FALSE |
| 103 | s-c-reaktiivinenproteiini,herkkä | mg/l | 813 | 0 | [0.39, 0.59, 0.83, 1.22, 1.67, 2.46, 3.62, 5.63, 9.01] |  | Serum |  | C reactive protein | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 104 | s-c-reaktiivinenproteiini,herkkä |  | 34 | 100 |  |  | Serum |  | C reactive protein |  | Immunoassay | Serum |  | Point in time (spot) | FALSE |
| 105 | s-c-reaktiivinenproteiini,pika | mg/l | 77 | 0 | [8, 10, 12.4, 14.7, 17, 20.05, 27.4, 35, 48] |  | Serum |  | C reactive protein | Mass Concentration | Rapid immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 106 | s-c-reaktiivinenproteiini,pika |  | 199 | 75.88 |  |  | Serum |  | C reactive protein |  | Rapid immunoassay | Serum |  | Point in time (spot) | FALSE |
| 107 | s-c-reaktiivinenproteiini/ | mg/l | 191 | 0 | [0.31, 0.5, 0.7, 0.96, 1.46, 2.27, 3.04, 4.65, 10.16] |  | Serum |  | C reactive protein | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 108 | s-c-reaktiivinenproteiini/ |  | 5 | 100 |  |  | Serum |  | C reactive protein |  |  | Serum |  | Point in time (spot) | FALSE |

