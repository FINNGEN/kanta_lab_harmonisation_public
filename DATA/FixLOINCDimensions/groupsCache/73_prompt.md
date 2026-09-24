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
Here is group 73.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Influenza virus | Influenza virus | 1.000 | 1 | 1,256 |
| Influenza virus | Influenza virus A | 0.883 | 0 | 0 |
| Influenza virus | Influenza virus RNA | 0.808 | 0 | 0 |
| Influenza virus | Influenza virus A H1 | 0.807 | 0 | 0 |
| Influenza virus | Influenza virus A and B | 0.785 | 0 | 0 |
| Influenza virus A | Influenza virus A | 1.000 | 0 | 0 |
| Influenza virus A | Influenza virus | 0.883 | 1 | 1,256 |
| Influenza virus A | Influenza virus A H1 | 0.876 | 0 | 0 |
| Influenza virus A | Influenza virus A H3 | 0.849 | 0 | 0 |
| Influenza virus A | Influenza virus A and B | 0.846 | 0 | 0 |
| Influenza virus A variant | Influenza virus A | 0.832 | 0 | 0 |
| Influenza virus A variant | Influenza virus A subtype | 0.816 | 0 | 0 |
| Influenza virus A variant | Influenza virus A N7 | 0.789 | 0 | 0 |
| Influenza virus A variant | Influenza virus A identified | 0.789 | 0 | 0 |
| Influenza virus A variant | Influenza virus A H1 | 0.782 | 0 | 0 |
| Influenza virus A+B | Influenza virus A+B | 1.000 | 0 | 0 |
| Influenza virus A+B | Influenza virus A+B Ab | 0.893 | 0 | 0 |
| Influenza virus A+B | Influenza virus A+B+C | 0.885 | 0 | 0 |
| Influenza virus A+B | Influenza virus A+B RNA | 0.884 | 0 | 0 |
| Influenza virus A+B | Influenza virus A+B Ag | 0.882 | 1 | 15,096 |
| Influenza virus B | Influenza virus B | 1.000 | 0 | 0 |
| Influenza virus B | Influenza virus B lineage | 0.862 | 0 | 0 |
| Influenza virus B | Influenza virus B RNA | 0.837 | 2 | 129,826 |
| Influenza virus B | Influenza virus B Ab | 0.837 | 1 | 29 |
| Influenza virus B | Influenza virus B Ag | 0.835 | 2 | 22,580 |
| Parainfluenza virus | Parainfluenza virus | 1.000 | 0 | 0 |
| Parainfluenza virus | Parainfluenza virus A | 0.881 | 0 | 0 |
| Parainfluenza virus | Parainfluenza virus 2 | 0.868 | 0 | 0 |
| Parainfluenza virus | Parainfluenza virus 1 | 0.867 | 0 | 0 |
| Parainfluenza virus | Parainfluenza virus 4 | 0.866 | 0 | 0 |
| Parainfluenza virus 1 | Parainfluenza virus 1 | 1.000 | 0 | 0 |
| Parainfluenza virus 1 | Parainfluenza virus 1 RNA | 0.878 | 1 | 4,037 |
| Parainfluenza virus 1 | Parainfluenza virus 1+2+3 | 0.867 | 0 | 0 |
| Parainfluenza virus 1 | Parainfluenza virus | 0.867 | 0 | 0 |
| Parainfluenza virus 1 | Parainfluenza virus 3 | 0.864 | 0 | 0 |
| Parainfluenza virus 2 | Parainfluenza virus 2 | 1.000 | 0 | 0 |
| Parainfluenza virus 2 | Canine parainfluenza virus 2 | 0.902 | 0 | 0 |
| Parainfluenza virus 2 | Parainfluenza virus 4 | 0.876 | 0 | 0 |
| Parainfluenza virus 2 | Parainfluenza virus 2 RNA | 0.871 | 1 | 4,036 |
| Parainfluenza virus 2 | Parainfluenza virus | 0.868 | 0 | 0 |
| Parainfluenza virus 3 | Parainfluenza virus 3 | 1.000 | 0 | 0 |
| Parainfluenza virus 3 | Parainfluenza virus 4 | 0.884 | 0 | 0 |
| Parainfluenza virus 3 | Parainfluenza virus 3 RNA | 0.869 | 1 | 4,036 |
| Parainfluenza virus 3 | Parainfluenza virus 2 | 0.867 | 0 | 0 |
| Parainfluenza virus 3 | Parainfluenza virus 1 | 0.864 | 0 | 0 |
| Parainfluenza virus 4 | Parainfluenza virus 4 | 1.000 | 0 | 0 |
| Parainfluenza virus 4 | Parainfluenza virus 4b | 0.951 | 0 | 0 |
| Parainfluenza virus 4 | Parainfluenza virus 4a | 0.942 | 0 | 0 |
| Parainfluenza virus 4 | Parainfluenza virus 3 | 0.884 | 0 | 0 |
| Parainfluenza virus 4 | Parainfluenza virus 4 RNA | 0.878 | 1 | 4,034 |
| Rhinovirus | Rhinovirus | 1.000 | 0 | 0 |
| Rhinovirus | Human Rhinovirus 2 | 0.793 | 0 | 0 |
| Rhinovirus | Rhinovirus/enterovirus | 0.792 | 0 | 0 |
| Rhinovirus | Rhinovirus RNA | 0.780 | 1 | 7,393 |
| Rhinovirus | Rhinovirus Ag | 0.766 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Nucleic acid amplification with probe detection | Nucleic acid amplification with probe detection | 1.000 | 115 | 2,413,483 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with non-probe detection | 0.864 | 1 | 7,786 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5a | 0.770 | 0 | 0 |
| Nucleic acid amplification with probe detection | Probe with amplification | 0.759 | 2 | 14,699 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5b | 0.754 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1104 | -hinfnho |  | 311 | 100 |  |  |  |  | Influenza virus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1105 | -hinnho |  | 3618 | 100 |  |  |  |  |  | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1106 | -inabnho |  | 4313 | 100 |  | -Influenssa A ja B-virus, nukleiinihappo (kval) |  |  | Influenza virus A+B | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1107 | -inabnhoho |  | 387 | 100 |  |  |  |  | Influenza virus A+B | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1108 | -inabrsnho |  | 432 | 100 |  |  |  |  |  |  |  |  |  |  | TRUE |
| 1109 | -inanho |  | 356 | 100 |  |  |  |  | Influenza virus A | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1110 | -inanhoho |  | 409 | 100 |  |  |  |  | Influenza virus A | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1111 | -inbnho |  | 356 | 100 |  |  |  |  | Influenza virus B | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1112 | -inbnhoho |  | 411 | 100 |  |  |  |  | Influenza virus B | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1113 | -infanho |  | 122873 | 100 |  | -Influenssa A -virus, nukleiinihappo (kval) |  |  | Influenza virus A | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1114 | -infbnho |  | 95902 | 100 |  | -Influenssa B-virus, nukleiinihappo (kval) |  |  | Influenza virus B | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1115 | -infvnho |  | 1260 | 100 |  | -Influenssa A-virus, variantti, nukleiinihappo (kval) |  |  | Influenza virus A variant | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1116 | -pin1nho |  | 9246 | 100 |  | -Parainfluenssa 1-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 1 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1117 | -pin2nho |  | 9244 | 100 |  | -Parainfluenssa 2-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 2 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1118 | -pin3nho |  | 9240 | 100 |  | -Parainfluenssa 3-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 3 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1119 | -pin4nho |  | 9240 | 100 |  | -Parainfluenssa 4-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 4 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1120 | -pinfnho |  | 5018 | 100 |  |  |  |  | Parainfluenza virus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1121 | -rinonho |  | 7403 | 100 |  | -Rinovirus, nukleiinihappo (kval) |  |  | Rhinovirus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1122 | -tintnho |  | 595 | 100 |  |  |  |  |  | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1123 | hinflnho |  | 745 | 100 |  |  |  |  | Influenza virus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1124 | inanho |  | 7494 | 100 |  |  |  |  | Influenza virus A | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1125 | inbnho |  | 7494 | 100 |  |  |  |  | Influenza virus B | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1126 | infanho |  | 12417 | 100 |  |  |  |  | Influenza virus A | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1127 | infbnho |  | 34660 | 100 |  |  |  |  | Influenza virus B | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1128 | infnho |  | 766 | 100 |  |  |  |  | Influenza virus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in in time (spot) | FALSE |
| 1129 | pin1nho |  | 4037 | 100 |  |  |  |  | Parainfluenza virus 1 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1130 | pin2nho |  | 4036 | 100 |  |  |  |  | Parainfluenza virus 2 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1131 | pin3nho |  | 4036 | 100 |  |  |  |  | Parainfluenza virus 3 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1132 | pin4nho |  | 4034 | 100 |  |  |  |  | Parainfluenza virus 4 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1133 | rinonho |  | 245 | 100 |  |  |  |  | Rhinovirus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |

