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
Here is group 160.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Alanine aminotransferase | Alanine aminotransferase | 1.000 | 21 | 5,367,314 |
| Alanine aminotransferase | Alanine aminotransferase/Aspartate aminotransferase | 0.852 | 0 | 0 |
| Alanine aminotransferase | Aspartate aminotransferase/Alanine aminotransferase | 0.775 | 0 | 0 |
| Aspartate aminotransferase | Aspartate aminotransferase | 1.000 | 14 | 513,305 |
| Aspartate aminotransferase | Aspartate aminotransferase/Alanine aminotransferase | 0.834 | 0 | 0 |
| Aspartate aminotransferase | Alanine aminotransferase | 0.762 | 21 | 5,367,314 |
| Aspartate aminotransferase | Aspartate aminotransferase.macromolecular | 0.760 | 0 | 0 |
| gamma-Glutamyl transferase | Gamma glutamyl transferase | 0.908 | 17 | 1,024,731 |
| gamma-Glutamyl transferase | Gamma glutamyl transferase/Aspartate aminotransferase | 0.811 | 0 | 0 |
| gamma-Glutamyl transferase | Gamma glutamyl transferase.macromolecular | 0.751 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Catalytic Concentration | Catalytic Concentration | 1.000 | 228 | 10,802,985 |
| Catalytic Concentration | Relative catalytic concentration | 0.848 | 9 | 39,650 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Serum or Plasma | Serum or Plasma | 1.000 | 2,776 | 78,327,842 |
| Serum or Plasma | Serum or Plasma or Urine | 0.832 | 0 | 0 |
| Serum or Plasma | Serum and Plasma | 0.819 | 0 | 0 |
| Serum or Plasma | Serum, Plasma or Blood | 0.816 | 84 | 6,240,111 |
| Serum or Plasma | Serum or Plasma and CSF | 0.792 | 4 | 1,187 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1769 | alaniiniaminotransferaasi | u/l | 17127 | 0 | [12.62, 15.78, 18.15, 20.52, 23.07, 26.12, 30.2, 36.33, 48.64] |  |  |  | Alanine aminotransferase | Catalytic Concentration |  | Serum or Plasma | Qn | Point in time (spot) | FALSE |
| 1770 | alaniiniaminotransferaasi |  | 1818 | 100 |  |  |  |  | Alanine aminotransferase | Catalytic Concentration |  | Serum or Plasma |  | Point in time (spot) | FALSE |
| 1771 | alaniiniaminotransferaasi,plasmasta | u/l | 97 | 0 |  |  |  |  | Alanine aminotransferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1772 | alaniiniaminotransferaasi,plasmasta |  | 5 | 100 |  |  |  |  | Alanine aminotransferase | Catalytic Concentration |  | Plasma |  | Point in time (spot) | FALSE |
| 1773 | aspartaattiaminotransferaasi | u/l | 333 | 0 | [19.85, 22, 24.14, 26.95, 28.65, 30.8, 35.68, 40.73, 58.73] |  |  |  | Aspartate aminotransferase | Catalytic Concentration |  | Serum or Plasma | Qn | Point in time (spot) | FALSE |
| 1774 | aspartaattiaminotransferaasi |  | 112 | 100 |  |  |  |  | Aspartate aminotransferase | Catalytic Concentration |  | Serum or Plasma |  | Point in time (spot) | FALSE |
| 1775 | fp-glutamyylitransferaasi | u/l | 102 | 0 |  |  | Fasting plasma |  | gamma-Glutamyl transferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1776 | fs-alaniiniaminotransferaasi | u/l | 404 | 0 | [11.41, 13.71, 16.19, 18.73, 21, 23.96, 27.89, 34.83, 48.11] |  | Fasting serum |  | Alanine aminotransferase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1777 | glutamyylitransferaasi | u/l | 1299 | 0 | [14.5, 18.98, 23.64, 30.47, 38.92, 48.36, 63.75, 98.88, 196.17] |  |  |  | gamma-Glutamyl transferase | Catalytic Concentration |  | Serum or Plasma | Qn | Point in time (spot) | FALSE |
| 1778 | glutamyylitransferaasi |  | 147 | 100 |  |  |  |  | gamma-Glutamyl transferase | Catalytic Concentration |  | Serum or Plasma |  | Point in time (spot) | FALSE |
| 1779 | p-alaniiniaminotransferaasi | u/l | 56170 | 0 | [12.86, 15.74, 18.08, 20.57, 23.4, 26.77, 31.35, 38.67, 54.12] |  | Plasma |  | Alanine aminotransferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1780 | p-alaniiniaminotransferaasi |  | 2147 | 74.66 | [38.23, 41.83, 47.86, 52.69, 56.94, 62.72, 70.64, 84.04, 118.17] |  | Plasma |  | Alanine aminotransferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1781 | p-aspartaattiaminotransferaasi | u/l | 7811 | 0 | [14.52, 17.19, 19.38, 21.57, 23.85, 26.51, 30.27, 36.73, 53.86] |  | Plasma |  | Aspartate aminotransferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1782 | p-aspartaattiaminotransferaasi |  | 129 | 90.7 |  |  | Plasma |  | Aspartate aminotransferase | Catalytic Concentration |  | Plasma |  | Point in time (spot) | FALSE |
| 1783 | p-glutamyylitransferaasi | u/l | 5844 | 0 | [14.78, 18.46, 22.33, 27.68, 34.27, 44.18, 62.47, 93.97, 172.3] |  | Plasma |  | gamma-Glutamyl transferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1784 | p-glutamyylitransferaasi |  | 33 | 84.85 |  |  | Plasma |  | gamma-Glutamyl transferase | Catalytic Concentration |  | Plasma |  | Point in time (spot) | FALSE |
| 1785 | s-alaniiniaminotransferaasi | u/l | 1811 | 0 | [14.14, 17.04, 20.11, 22.99, 25.82, 29.58, 34.38, 41.48, 55.32] |  | Serum |  | Alanine aminotransferase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1786 | s-alaniiniaminotransferaasi |  | 52 | 100 |  |  | Serum |  | Alanine aminotransferase | Catalytic Concentration |  | Serum |  | Point in time (spot) | FALSE |
| 1787 | s-aspartaattiaminotransferaasi | u/l | 554 | 0 | [18, 19.97, 21.87, 23, 25, 27, 29.85, 33.06, 40.22] |  | Serum |  | Aspartate aminotransferase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1788 | s-aspartaattiaminotransferaasi |  | 8 | 87.5 |  |  | Serum |  | Aspartate aminotransferase | Catalytic Concentration |  | Serum |  | Point in time (spot) | FALSE |
| 1789 | s-glutamyylitransferaasi | u/l | 861 | 0 | [11.96, 14.7, 17.37, 19.9, 24.16, 28.75, 37.06, 51.26, 84.05] |  | Serum |  | gamma-Glutamyl transferase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |

