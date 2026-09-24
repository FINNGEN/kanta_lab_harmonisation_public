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
Here is group 129.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Cardiac stress test | Cardiac stress EKG study | 0.824 | 0 | 0 |
| Cardiac stress test | Cardiac stress echo study | 0.803 | 0 | 0 |
| Echocardiography | (none scored >= 0.75) |  |  |  |
| Myocardial perfusion study | (none scored >= 0.75) |  |  |  |
| Semen analysis | Semen analysis | 1.000 | 0 | 0 |
| Semen analysis | Semen analysis panel | 0.851 | 0 | 0 |
| Semen analysis | Semen analysis fertility panel | 0.827 | 0 | 0 |
| Semen analysis | Semen/urine analysis fertility panel | 0.768 | 0 | 0 |
| Semen analysis | Semen and urine analysis fertility panel | 0.763 | 0 | 0 |
| Spirometry | Spirometry panel | 0.762 | 0 | 0 |
| Spirometry with bronchodilator | (none scored >= 0.75) |  |  |  |
| Thermal sensory testing | (none scored >= 0.75) |  |  |  |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| ^Patient | ^Patient | 1.000 | 20 | 396,517 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1739 | pt-fvsirod |  | 396 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1740 | pt-fvspdo6 |  | 226 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1741 | pt-fvspid |  | 451 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1742 | pt-fvspidl |  | 4654 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1743 | pt-fvspido |  | 17640 | 98.28 | [1, 1, 1, 1, 1, 1, 1, 1, 1] |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1744 | pt-fvspio |  | 1411 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1745 | pt-fvspird | form | 18 | 100 | [30622, 77088.15, 106752.5, 134032.5, 166516.57, 190349.45, 230673.1, 250553.8, 270325] |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1746 | pt-fvspird |  | 7795 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1747 | pt-fvspiro | form | 26 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1748 | pt-fvspiro |  | 1641 | 82.39 | [1, 1, 1, 1, 1, 1, 1, 1, 1] |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1749 | pt-sper-1 | u/nke | 5 | 0 |  | Pt-Siemennestetutkimus, suppea | Patient |  | Semen analysis |  |  | ^Patient |  |  | TRUE |
| 1750 | pt-sper-1 |  | 714 | 98.74 |  | Pt-Siemennestetutkimus, suppea | Patient |  | Semen analysis |  |  | ^Patient |  |  | TRUE |
| 1751 | pt-sper-2 | form | 39 | 100 |  | Pt-Siemennestetutkimus, laaja | Patient |  | Semen analysis |  |  | ^Patient |  |  | TRUE |
| 1752 | pt-sper-2 |  | 480 | 100 |  | Pt-Siemennestetutkimus, laaja | Patient |  | Semen analysis |  |  | ^Patient |  |  | TRUE |
| 1753 | pt-sper-3 |  | 663 | 100 |  | Pt-Siemennestetutkimus, laaja lisätutkimuksin | Patient |  | Semen analysis |  |  | ^Patient |  |  | TRUE |
| 1754 | pt-sperma |  | 159 | 100 |  |  | Patient |  | Semen analysis |  |  | ^Patient |  |  | TRUE |
| 1755 | pt-spird-x |  | 8902 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1756 | pt-spirlau |  | 493 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1757 | pt-spiro-x |  | 775 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1758 | pt-spirob, |  | 746 | 100 |  |  | Patient |  | Spirometry with bronchodilator |  |  | ^Patient | Doc |  | TRUE |
| 1759 | pt-spirob,tk |  | 986 | 100 |  |  | Patient |  | Spirometry with bronchodilator |  |  | ^Patient | Doc |  | TRUE |
| 1760 | pt-spirom |  | 814 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1761 | pt-spiromd |  | 547 | 100 |  |  | Patient |  | Spirometry |  |  | ^Patient | Doc |  | TRUE |
| 1762 | pt-sppesu |  | 141 | 100 |  |  | Patient |  |  |  |  | ^Patient |  |  | FALSE |
| 1763 | pt-st-temp |  | 111 | 100 |  | Pt-Terminen tuntokynnysmittaus | Patient |  | Thermal sensory testing |  |  | ^Patient |  |  | TRUE |
| 1764 | pt-sydperg |  | 117 | 100 |  |  | Patient |  | Myocardial perfusion study |  |  | ^Patient | Doc |  | TRUE |
| 1765 | pt-sydperq |  | 923 | 100 |  |  | Patient |  | Myocardial perfusion study |  |  | ^Patient | Doc |  | TRUE |
| 1766 | pt-sydrasq |  | 197 | 100 |  |  | Patient |  | Cardiac stress test |  |  | ^Patient | Doc |  | TRUE |
| 1767 | pt-sydrtuä |  | 139 | 100 |  |  | Patient |  | Echocardiography |  |  | ^Patient | Doc |  | TRUE |
| 1768 | pt-sydänuä |  | 3154 | 100 |  |  | Patient |  | Echocardiography |  |  | ^Patient | Doc |  | TRUE |

