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
Here is group 126.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Glucose | Glucose | 1.000 | 116 | 2,411,012 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Mass Fraction | Mass fraction | 1.000 | 229 | 4,683,692 |
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
| ^Patient | ^Patient | 1.000 | 20 | 396,517 |
| Blood capillary | Blood capillary | 1.000 | 121 | 787,125 |
| Blood capillary | Blood capillary^Fetus | 0.763 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1710 | -gluk-tbr | % | 118 | 0 | [0, 0, 1, 1, 1, 2, 2.43, 4.38, 6.6] |  |  |  |  | Mass Fraction |  |  | Qn | Point in time (spot) | FALSE |
| 1711 | -gluk-tir | % | 120 | 0 | [25.5, 36.83, 44.57, 51.33, 60.25, 66, 72.25, 76.73, 81.25] |  |  |  |  | Mass Fraction |  |  | Qn | Point in time (spot) | FALSE |
| 1712 | gluk-vieri |  | 309 | 0 | [5.09, 5.42, 5.78, 6.17, 6.7, 7.14, 8, 9.04, 11.23] |  |  |  | Glucose | Substance Concentration | Test strip | Blood capillary | Qn | Point in time (spot) | FALSE |
| 1713 | gluk0 | mmol/l | 143 | 0 | [4.61, 4.8, 4.96, 5.03, 5.21, 5.48, 5.8, 6.24, 6.7] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1714 | gluk0 |  | 10 | 20 |  |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1715 | gluk0min |  | 368 | 0 | [4.92, 5.32, 5.58, 5.75, 5.88, 6, 6.19, 6.58, 7.05] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1716 | gluk120min |  | 349 | 0 | [4.3, 5.17, 5.91, 6.49, 7.07, 7.6, 8.72, 10.59, 13.35] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1717 | gluk1h | mmol/l | 282 | 0 | [5.36, 6.29, 6.9, 7.39, 7.93, 8.69, 9.15, 9.75, 11.47] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1718 | gluk2h | mmol/l | 280 | 0 | [4.55, 5.28, 5.68, 6.16, 6.59, 6.99, 7.54, 8.2, 9.44] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1719 | gluk2h |  | 6 | 100 |  |  |  |  | Glucose | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1720 | gluk30min |  | 362 | 0 | [7.03, 7.79, 8.42, 8.84, 9.36, 9.74, 10.39, 11.2, 12.52] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1721 | gluk60min |  | 359 | 0 | [5.8, 6.9, 7.62, 8.52, 9.3, 10.21, 11.28, 12.5, 14.53] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1722 | glukbel-vp | mmol/l | 664 | 0 | [4.52, 4.88, 5.29, 5.73, 5.99, 6.35, 6.81, 10.3, 12.64] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1723 | glukbel-vp |  | 209 | 100 |  |  |  |  | Glucose | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1724 | glukoosi120min | mmol/l | 119 | 0 | [4.6, 5.12, 5.49, 5.84, 6.6, 7.25, 8.25, 9.68, 12.44] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1725 | glukr-0 | mmol/l | 144 | 0 | [4.8, 5.18, 5.45, 5.64, 5.93, 6.16, 6.41, 6.64, 7.16] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1726 | glukr-1h | mmol/l | 125 | 0 | [6.69, 7.13, 7.9, 8.73, 9.2, 10.36, 11.37, 12.79, 14.55] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1727 | glukr-2h | mmol/l | 144 | 0 | [5.34, 5.79, 6.28, 6.91, 7.51, 8.15, 8.91, 10.16, 11.81] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1728 | glukr0 | mmol/l | 204 | 0 | [4.5, 4.79, 4.89, 5.08, 5.2, 5.47, 5.8, 6.29, 6.89] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1729 | glukr0-n | mmol/l | 618 | 0 | [4.67, 4.86, 5.09, 5.3, 5.57, 5.83, 6.03, 6.29, 6.69] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1730 | glukr1h | mmol/l | 381 | 0 | [5.67, 6.21, 6.84, 7.42, 7.86, 8.3, 8.82, 9.42, 10.36] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1731 | glukr1valm |  | 333 | 100 |  |  |  |  |  | Finding |  | ^Patient | Nar |  | FALSE |
| 1732 | glukr2h | mmol/l | 780 | 0 | [4.8, 5.34, 5.8, 6.21, 6.59, 7.03, 7.53, 8.19, 9.83] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1733 | glukras-0 | mmol/l | 97 | 0 | [4.6, 4.78, 5, 5.1, 5.2, 5.43, 5.65, 5.9, 6.3] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1734 | glukras-0 |  | 30 | 3.33 |  |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1735 | glukras120 | mmol/l | 153 | 0 | [5.1, 5.47, 5.77, 6.11, 6.54, 6.97, 7.58, 8.12, 9.26] |  |  |  | Glucose | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1736 | glukrvalm |  | 2563 | 100 |  |  |  |  |  | Finding |  | ^Patient | Nar |  | FALSE |
| 1737 | glukvieri | mmol/l | 823 | 0 | [5.3, 5.72, 6.09, 6.42, 6.92, 7.6, 8.66, 10.17, 12.3] |  |  |  | Glucose | Substance Concentration | Test strip | Blood capillary | Qn | Point in time (spot) | FALSE |
| 1738 | glukvieri |  | 251 | 1.59 | [5.24, 5.55, 5.81, 6.07, 6.3, 6.79, 7.52, 8.56, 10.76] |  |  |  | Glucose | Substance Concentration | Test strip | Blood capillary | Qn | Point in time (spot) | FALSE |

