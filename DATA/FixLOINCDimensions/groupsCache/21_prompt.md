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
Here is group 21.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Soluble transferrin receptor | Transferrin receptor.soluble | 0.859 | 15 | 285,465 |
| Soluble transferrin receptor | Transferrin receptor.soluble/log Ferritin index | 0.761 | 0 | 0 |
| Transferrin saturation | Transferrin saturation | 1.000 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Mass Fraction | Mass fraction | 1.000 | 229 | 4,683,692 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 155 | fp-transferriininrautakyllästeisyys | % | 3193 | 0 | [8.97, 13, 16.76, 20.1, 23.32, 26.3, 29.57, 33.75, 41.18] |  | Fasting plasma |  | Transferrin saturation | Mass Fraction |  | Plasma | Qn | Point in time (spot) | FALSE |
| 156 | fp-transferriininrautakyllästeisyys |  | 13 | 84.62 |  |  | Fasting plasma |  | Transferrin saturation |  |  | Plasma | Nar | Point in time (spot) | FALSE |
| 157 | fp-transferriininrautasaturaatio | % | 401 | 0 | [8.17, 12.08, 15.12, 17.38, 20.04, 22.98, 27.38, 31.01, 39.99] |  | Fasting plasma |  | Transferrin saturation | Mass Fraction |  | Plasma | Qn | Point in time (spot) | FALSE |
| 158 | fs-transferiininrautakyllästeisyys |  | 2368 | 65.54 | [0.08, 0.13, 0.16, 0.19, 0.23, 0.26, 0.3, 0.34, 0.41] |  | Fasting serum |  | Transferrin saturation | Mass Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 159 | fs-transferiininrautakyllästeisyys,paastotilassa |  | 139 | 0 | [0.07, 0.12, 0.15, 0.19, 0.22, 0.24, 0.28, 0.33, 0.39] |  | Fasting serum |  | Transferrin saturation | Mass Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 160 | fs-transferriininrautakyllästeisyys | % | 144 | 0 | [5.6, 8.49, 12.38, 16.94, 20.5, 24.07, 26.84, 31.55, 40] |  | Fasting serum |  | Transferrin saturation | Mass Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 161 | fs-transferriininrautakyllästeisyys |  | 230 | 1.74 | [6.96, 10.51, 13.75, 17.95, 20.84, 24.42, 28.14, 32.22, 47.21] |  | Fasting serum |  | Transferrin saturation | Mass Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 162 | p-transferriininrautakyllästeisyys | % | 288 | 0 | [7.78, 11.72, 15.31, 18.47, 21.76, 25.36, 29.49, 34.05, 40.39] |  | Plasma |  | Transferrin saturation | Mass Fraction |  | Plasma | Qn | Point in time (spot) | FALSE |
| 163 | p-transferriininrautakyllästeisyys,fp-fe/tr,fp-fe/tran,fp-fe/trans | % | 628 | 0 | [9.32, 12.95, 14.99, 17.87, 20.98, 23.9, 27.48, 31.74, 38.07] |  | Plasma |  | Transferrin saturation | Mass Fraction |  | Plasma | Qn | Point in time (spot) | FALSE |
| 164 | p-transferriinireseptori | mg/l | 1449 | 0 | [0.64, 0.72, 0.81, 0.91, 1.01, 1.14, 1.3, 1.54, 1.97] |  | Plasma |  | Soluble transferrin receptor | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 165 | p-transferriinireseptori |  | 176 | 100 |  |  | Plasma |  | Soluble transferrin receptor |  |  | Plasma | Nar | Point in time (spot) | FALSE |
| 166 | p-transferriinireseptori,liukoinen | mg/l | 1328 | 0 | [0.8, 1.04, 1.37, 1.95, 2.49, 2.95, 3.61, 4.4, 5.84] |  | Plasma |  | Soluble transferrin receptor | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 167 | p-transferriinireseptori,liukoinen |  | 42 | 100 |  |  | Plasma |  | Soluble transferrin receptor |  |  | Plasma | Nar | Point in time (spot) | FALSE |
| 168 | s-transferriinireseptori | mg/l | 1934 | 0 | [2.3, 2.61, 2.91, 3.22, 3.51, 3.93, 4.43, 5.22, 6.84] |  | Serum |  | Soluble transferrin receptor | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 169 | s-transferriinireseptori,liukoinen | mg/l | 129 | 0 | [0.91, 1.1, 1.18, 1.23, 1.33, 1.45, 1.78, 2.23, 3.16] |  | Serum |  | Soluble transferrin receptor | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 170 | transferiininrautakyllästeisyys,seerumista,paastotilassa | osuus | 236 | 0 | [0.09, 0.15, 0.19, 0.22, 0.25, 0.29, 0.31, 0.35, 0.44] |  |  |  | Transferrin saturation | Mass Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 171 | transferiininrautakyllästeisyys,seerumista,paastotilassa | paketti | 16 | 0 |  |  |  |  |  |  |  |  |  |  | TRUE |
| 172 | transferiininrautakyllästeisyys,seerumista,paastotilassa |  | 205 | 3.41 | [0.1, 0.13, 0.16, 0.18, 0.22, 0.26, 0.29, 0.33, 0.41] |  |  |  | Transferrin saturation | Mass Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 173 | transferriininrautakyllästeisyys | % | 1179 | 0 | [8.18, 11.78, 15.27, 18.31, 21.03, 24.15, 27.59, 31.86, 39.21] |  |  |  | Transferrin saturation | Mass Fraction |  |  | Qn | Point in time (spot) | FALSE |
| 174 | transferriininrautakyllästeisyys |  | 26 | 100 |  |  |  |  | Transferrin saturation |  |  |  | Nar | Point in time (spot) | FALSE |
| 175 | transferriininrautakyllästeisyys(fp-) | % | 596 | 0 | [10.58, 15.04, 18.08, 21, 24.94, 28.56, 32.22, 37.06, 43.51] |  |  |  | Transferrin saturation | Mass Fraction |  | Plasma | Qn | Point in time (spot) | FALSE |
| 176 | transferriininrautakyllästeisyys(fp-) |  | 16 | 100 |  |  |  |  | Transferrin saturation |  |  | Plasma | Nar | Point in time (spot) | FALSE |
| 177 | transferriininrautakyllästeisyys␤ | % | 1453 | 0 |  |  |  |  | Transferrin saturation | Mass Fraction |  |  | Qn | Point in time (spot) | FALSE |
| 178 | transferriininrautakyllästeisyys␤ |  | 5 | 100 |  |  |  |  | Transferrin saturation |  |  |  | Nar | Point in time (spot) | FALSE |
| 179 | transferriinirautakyllästeisyys | % | 233 | 0 | [8.52, 13.59, 16.32, 21.55, 25.9, 28.62, 32.3, 36.31, 42.32] |  |  |  | Transferrin saturation | Mass Fraction |  |  | Qn | Point in time (spot) | FALSE |
| 180 | transferriinireseptori,liukoinen | mg/l | 196 | 0 | [1.64, 2.13, 2.4, 2.6, 2.79, 2.98, 3.16, 3.56, 4.22] |  |  |  | Soluble transferrin receptor | Mass Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 181 | transferriinireseptori,liukoinen |  | 48 | 100 |  |  |  |  | Soluble transferrin receptor |  |  |  | Nar | Point in time (spot) | FALSE |
| 182 | transferriinisaturaatio | % | 292 | 0 | [6.88, 9.89, 12.73, 16.14, 19.09, 22.3, 26.09, 32.09, 39.32] |  |  |  | Transferrin saturation | Mass Fraction |  |  | Qn | Point in time (spot) | FALSE |

