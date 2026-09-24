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
Here is group 44.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Aluminum | Aluminum | 1.000 | 1 | 77 |
| Aluminum | Aluminum oxide | 0.756 | 0 | 0 |
| Aminolevulinate | Delta aminolevulinate | 0.837 | 1 | 31 |
| Amphetamines | Amphetamines | 1.000 | 2 | 50,457 |
| Amphetamines | Amphetamine | 0.870 | 0 | 0 |
| Amphetamines | Amphetamines tested for | 0.778 | 0 | 0 |
| Amphetamines | Amphetamines positive | 0.776 | 0 | 0 |
| Amphetamines | Amphetamine/Methamphetamine | 0.770 | 0 | 0 |
| Arsenic.inorganic | Arsenic.inorganic | 1.000 | 0 | 0 |
| Arsenic.inorganic | Arsenic.inorganic+methylated | 0.860 | 0 | 0 |
| Arsenic.inorganic | Arsenic.inorganic/Creatinine | 0.838 | 0 | 0 |
| Arsenic.inorganic | Arsenic organic | 0.817 | 0 | 0 |
| Arsenic.inorganic | Arsenic | 0.794 | 0 | 0 |
| Arterial blood pressure | (none scored >= 0.75) |  |  |  |
| Benzodiazepines | Benzodiazepines | 1.000 | 2 | 52,864 |
| Bilirubin | Bilirubin | 1.000 | 19 | 1,512,475 |
| Bilirubin | Bilirubin excess | 0.754 | 0 | 0 |
| Buprenorphine | Buprenorphine | 1.000 | 6 | 46,210 |
| Buprenorphine | Buprenorphine+Norbuprenorphine | 0.751 | 0 | 0 |
| Calculus (stone) analysis | (none scored >= 0.75) |  |  |  |
| Chloride | Chloride | 1.000 | 19 | 528,307 |
| Cholesterol | Cholesterol | 1.000 | 35 | 2,074,540 |
| Collagen type I N-terminal telopeptide | Collagen crosslinked N-telopeptide | 0.866 | 2 | 1,030 |
| Collagen type I N-terminal telopeptide | Procollagen type I.N-terminal propeptide | 0.841 | 2 | 3,659 |
| Collagen type I N-terminal telopeptide | Collagen crosslinked C-telopeptide | 0.837 | 3 | 1,772 |
| Collagen type I N-terminal telopeptide | Collagen crosslinked N-telopeptide/Creatinine | 0.766 | 0 | 0 |
| Collagen type I N-terminal telopeptide | Procollagen type III.N-terminal propeptide | 0.764 | 2 | 2,070 |
| Erythrocytes | Erythrocytes | 1.000 | 64 | 12,187,960 |
| Fentanyl | fentaNYL | 1.000 | 0 | 0 |
| Fentanyl | fentaNYL and Norfentanyl | 0.835 | 0 | 0 |
| Fentanyl | fentaNYL+Norfentanyl | 0.827 | 0 | 0 |
| Fentanyl | fentaNYL/Creatinine | 0.762 | 0 | 0 |
| Fentanyl | fentaNYL cutoff | 0.761 | 0 | 0 |
| Follicle stimulating hormone | (none scored >= 0.75) |  |  |  |
| Iodide | Iodide | 1.000 | 0 | 0 |
| Iodide | Iodine | 0.810 | 0 | 0 |
| Magnesium | Magnesium | 1.000 | 13 | 270,301 |
| Mercury | Mercury | 1.000 | 4 | 243 |
| Methadone | Methadone | 1.000 | 2 | 31,454 |
| Methadone | Methadone.R | 0.780 | 0 | 0 |
| Mini-Mental State Examination | Mini-Mental State Examination | 1.000 | 0 | 0 |
| Natriuretic peptide.B | Natriuretic peptide B | 0.879 | 4 | 97,925 |
| Natriuretic peptide.B | Natriuretic peptide | 0.878 | 0 | 0 |
| Natriuretic peptide.B | Natriuretic peptide.B prohormone N-Terminal | 0.827 | 59 | 390,817 |
| Natriuretic peptide.B | Natriuretic peptide.B^^adjusted for eGFR | 0.801 | 0 | 0 |
| Neuron specific enolase | Enolase.neuron specific | 0.795 | 3 | 10,290 |
| Neuron specific enolase | Enolase.neuron specific Ag | 0.794 | 0 | 0 |
| Nickel | Nickel | 1.000 | 0 | 0 |
| pH | pH | 1.000 | 92 | 2,272,494 |
| Phosphate | Phosphate | 1.000 | 14 | 378,156 |
| Phosphate | Phosphorus | 0.823 | 0 | 0 |
| Porphobilinogen | Porphobilinogen | 1.000 | 0 | 0 |
| Porphobilinogen | Porphobilinogen deaminase | 0.862 | 0 | 0 |
| Porphobilinogen | Porphobilin | 0.833 | 0 | 0 |
| Porphobilinogen | Porphobilinogen synthase | 0.827 | 0 | 0 |
| Porphobilinogen | Porphobilinogen/Creatinine | 0.825 | 0 | 0 |
| Potassium hydroxide preparation | (none scored >= 0.75) |  |  |  |
| Pyrenol | (none scored >= 0.75) |  |  |  |
| Selenium | Selenium | 1.000 | 3 | 1,141 |
| Specific gravity | Specific gravity | 1.000 | 0 | 0 |
| Tetrahydrocannabinol | Tetrahydrocannabinol | 1.000 | 0 | 0 |
| Tetrahydrocannabinol | Tetrahydrocannabivarin | 0.752 | 0 | 0 |
| Thyrotropin | Thyrotropin | 1.000 | 47 | 2,174,311 |
| Tramadol | traMADol | 1.000 | 0 | 0 |
| Urine sediment microscopy | (none scored >= 0.75) |  |  |  |
| Urobilinogen | Urobilinogen | 1.000 | 0 | 0 |
| Urobilinogen | Urobilin | 0.875 | 0 | 0 |
| Urobilinogen | Bilirubin+Urobilinogen | 0.841 | 0 | 0 |
| Vasoactive intestinal peptide | Vasoactive intestinal peptide | 1.000 | 3 | 452 |
| Vasoactive intestinal peptide | Vasoactive intestinal peptide Ag | 0.780 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Catalytic Concentration | Catalytic Concentration | 1.000 | 228 | 10,802,985 |
| Catalytic Concentration | Relative catalytic concentration | 0.848 | 9 | 39,650 |
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Narrative | (none scored >= 0.75) |  |  |  |
| pH | (none scored >= 0.75) |  |  |  |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Pressure | Pressure | 1.000 | 0 | 0 |
| Score | Score | 1.000 | 0 | 0 |
| Specific gravity | Specific gravity | 1.000 | 20 | 498,208 |
| Substance | Substance Content | 0.785 | 0 | 0 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |
| Substance Ratio | Substance Ratio | 1.000 | 9 | 237,272 |
| Substance Ratio | Entitic substance ratio | 0.795 | 0 | 0 |
| Substance Ratio | Substance Rate | 0.789 | 41 | 25,881 |
| Substance Ratio | Substance Fraction | 0.786 | 0 | 0 |
| Time | (none scored >= 0.75) |  |  |  |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Doppler | Doppler | 1.000 | 0 | 0 |
| Doppler | Doppler.measured | 0.786 | 0 | 0 |
| Microscopy.light | Microscopy | 0.756 | 0 | 0 |
| Test strip | Test strip | 1.000 | 79 | 4,294,769 |
| Test strip | Test strip manual | 0.843 | 0 | 0 |
| Test strip | Test strip automated | 0.836 | 3 | 687,408 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| ^Patient | ^Patient | 1.000 | 20 | 396,517 |
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Blood capillary | Blood capillary | 1.000 | 121 | 787,125 |
| Blood capillary | Blood capillary^Fetus | 0.763 | 0 | 0 |
| Cerebral spinal fluid | Cerebral spinal fluid | 1.000 | 150 | 183,922 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Pleural fluid | Pleural fluid | 1.000 | 95 | 67,704 |
| Pleural fluid | Pericardial fluid | 0.759 | 0 | 0 |
| Secretion | (none scored >= 0.75) |  |  |  |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Umbilical cord blood serum | (none scored >= 0.75) |  |  |  |
| Urine | Urine | 1.000 | 586 | 16,080,701 |
| Vaginal fluid | Genital fluid | 0.783 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 587 | -bil | umol/l | 433 | 0 | [8.08, 11.42, 17.8, 24.81, 35.56, 52.32, 88.15, 166.34, 422.22] | -Bilirubiini |  |  | Bilirubin | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 588 | -bil |  | 85 | 95.29 |  | -Bilirubiini |  |  | Bilirubin | Narrative |  |  | Nar | Point in time (spot) | FALSE |
| 589 | b-bio |  | 4183 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | FALSE |
| 590 | b-hg | nmol/l | 64 | 0 |  | B -Elohopea | Blood |  | Mercury | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 591 | b-hg |  | 51 | 94.12 |  | B -Elohopea | Blood |  | Mercury | Narrative |  | Blood | Nar | Point in time (spot) | FALSE |
| 592 | cb-bil | umol/l | 331 | 0 | [11.1, 19.39, 22.31, 26.36, 32.8, 45.69, 98.54, 156.29, 216.28] | cB-Bilirubiini | Capillary blood |  | Bilirubin | Substance Concentration |  | Blood capillary | Qn | Point in time (spot) | FALSE |
| 593 | cb-bil |  | 4244 | 99.98 |  | cB-Bilirubiini | Capillary blood |  | Bilirubin | Narrative |  | Blood capillary | Nar | Point in time (spot) | FALSE |
| 594 | du-mg | mmol | 580 | 0.17 | [2.07, 2.62, 3.11, 3.51, 3.97, 4.42, 4.91, 5.69, 6.98] | dU-Magnesium | 24-hour urine |  | Magnesium | Substance |  | Urine | Qn | 24 hours | FALSE |
| 595 | du-mg |  | 154 | 70.78 |  | dU-Magnesium | 24-hour urine |  | Magnesium | Narrative |  | Urine | Nar | 24 hours | FALSE |
| 596 | du-pi | mmol | 591 | 0.17 | [14.15, 19.7, 22.95, 26.88, 29.9, 33.43, 38, 43.23, 51.47] | dU-Fosfaatti, epäorgaaninen | 24-hour urine |  | Phosphate | Substance |  | Urine | Qn | 24 hours | FALSE |
| 597 | du-pi |  | 118 | 75.42 |  | dU-Fosfaatti, epäorgaaninen | 24-hour urine |  | Phosphate | Narrative |  | Urine | Nar | 24 hours | FALSE |
| 598 | fl-koh |  | 285 | 100 |  |  | Vaginal discharge |  | Potassium hydroxide preparation | Finding |  | Vaginal fluid | Nom | Point in time (spot) | FALSE |
| 599 | fp-bil | umol/l | 111 | 0 | [4.98, 6.34, 7.02, 8.69, 9.41, 10.29, 12.14, 15.18, 27.61] |  | Fasting plasma |  | Bilirubin | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 600 | fp-kol | mmol | 7 | 0 |  | fP-Kolesteroli | Fasting plasma |  | Cholesterol | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 601 | fp-kol | mmol/ | 7 | 0 |  | fP-Kolesteroli | Fasting plasma |  | Cholesterol | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 602 | fp-kol | mmol/l | 1407523 | 0 | [3.2, 3.63, 3.97, 4.28, 4.58, 4.87, 5.21, 5.6, 6.16] | fP-Kolesteroli | Fasting plasma |  | Cholesterol | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 603 | fp-kol |  | 17406 | 100 | [4.01, 4.31, 4.6, 4.91, 5.19, 5.43, 5.75, 6.21, 6.8] | fP-Kolesteroli | Fasting plasma |  | Cholesterol | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 604 | fp-vip | pmol/l | 391 | 1.53 | [6.42, 8.54, 9.99, 11.21, 13, 14.7, 16.8, 19.84, 27.89] | fP-Vasoaktiivinen intestinaalinen peptidi | Fasting plasma |  | Vasoactive intestinal peptide | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 605 | fp-vip |  | 61 | 81.97 |  | fP-Vasoaktiivinen intestinaalinen peptidi | Fasting plasma |  | Vasoactive intestinal peptide | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 606 | fs-kol | mmol/ | 7 | 0 |  | fS-Kolesteroli | Fasting serum |  | Cholesterol | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 607 | fs-kol | mmol/l | 259011 | 0 | [3.71, 4.15, 4.46, 4.76, 5.03, 5.31, 5.59, 5.95, 6.44] | fS-Kolesteroli | Fasting serum |  | Cholesterol | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 608 | fs-kol |  | 481 | 100 | [3.95, 4.3, 4.66, 4.92, 5.17, 5.39, 5.64, 6.03, 6.57] | fS-Kolesteroli | Fasting serum |  | Cholesterol | Narrative |  | Serum | Nar | Point in time (spot) | FALSE |
| 609 | li-bio |  | 161 | 100 |  |  | Cerebrospinal fluid |  |  |  |  | Cerebral spinal fluid |  |  | FALSE |
| 610 | mmse |  | 524 | 94.66 |  |  |  |  | Mini-Mental State Examination | Score |  | ^Patient | Qn | Point in time (spot) | FALSE |
| 611 | p-bil | umol/l | 1420468 | 0.09 | [5, 6, 7, 8.01, 9.15, 10.92, 12.96, 16.55, 24.99] | P -Bilirubiini | Plasma |  | Bilirubin | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 612 | p-bil |  | 51285 | 100 | [4.75, 5.95, 6.93, 7.97, 9.15, 10.81, 13.1, 17.26, 26.41] | P -Bilirubiini | Plasma |  | Bilirubin | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 613 | p-bnp | ng/l | 92283 | 0 | [19.9, 36.26, 58.02, 88.41, 132.21, 195.75, 292.04, 465.57, 902.19] | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  | Natriuretic peptide.B | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 614 | p-bnp | ng/ml | 14 | 0 |  | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  | Natriuretic peptide.B | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 615 | p-bnp |  | 5638 | 100 | [41.88, 71.98, 108.12, 145.12, 193.35, 257.89, 351.05, 510.91, 912.06] | P -Natriureettinen peptidi, B-tyypin (32-) | Plasma |  | Natriuretic peptide.B | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 616 | p-fsh | u/l | 10309 | 0 | [3.43, 4.83, 5.94, 7.2, 9.39, 15.3, 30.23, 51.8, 73.17] | P -Follikkelia stimuloiva hormoni | Plasma |  | Follicle stimulating hormone | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 617 | p-fsh |  | 155 | 100 | [3.32, 4.57, 5.74, 6.86, 8.5, 12.89, 23.84, 44.5, 70.18] | P -Follikkelia stimuloiva hormoni | Plasma |  | Follicle stimulating hormone | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 618 | p-fsl | s | 1808 | 0 | [23.6, 25, 25.97, 26.26, 27.2, 28.08, 29.24, 31.3, 34.37] |  | Plasma |  |  | Time |  | Plasma | Qn | Point in time (spot) | FALSE |
| 619 | p-fsl |  | 86 | 69.77 |  |  | Plasma |  |  | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 620 | p-kol | mmol/l | 298985 | 0 | [3.03, 3.42, 3.74, 4.03, 4.33, 4.64, 4.97, 5.37, 5.92] | P -Kolesteroli | Plasma |  | Cholesterol | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 621 | p-kol |  | 2034 | 100 | [3, 3.37, 3.67, 3.97, 4.25, 4.57, 4.92, 5.32, 5.88] | P -Kolesteroli | Plasma |  | Cholesterol | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 622 | p-mg | mmol/l | 259826 | 0.04 | [0.64, 0.7, 0.74, 0.77, 0.8, 0.83, 0.86, 0.89, 0.95] | P -Magnesium | Plasma |  | Magnesium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 623 | p-mg |  | 2225 | 100 | [0.64, 0.7, 0.74, 0.78, 0.81, 0.84, 0.86, 0.9, 0.95] | P -Magnesium | Plasma |  | Magnesium | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 624 | p-se | umol/l | 1087 | 0.09 | [0.86, 1.03, 1.1, 1.19, 1.27, 1.34, 1.41, 1.5, 1.62] | P -Seleeni | Plasma |  | Selenium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 625 | p-se |  | 55 | 43.64 | [1.17, 1.27, 1.34, 1.4, 1.46, 1.54, 1.63, 1.73, 1.94] | P -Seleeni | Plasma |  | Selenium | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 626 | p-tsh | miu/l | 32584 | 0 | [0.71, 1.13, 1.46, 1.75, 2.07, 2.43, 2.87, 3.48, 4.57] | P -Tyreotropiini | Plasma |  | Thyrotropin | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 627 | p-tsh | mlu/l | 4705 | 0 | [0.58, 1.02, 1.38, 1.7, 2.07, 2.5, 3.01, 3.68, 4.95] | P -Tyreotropiini | Plasma |  | Thyrotropin | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 628 | p-tsh | mu/l | 1660849 | 0.06 | [0.53, 0.92, 1.22, 1.5, 1.78, 2.11, 2.53, 3.11, 4.2] | P -Tyreotropiini | Plasma |  | Thyrotropin | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 629 | p-tsh |  | 53377 | 100 | [0.3, 0.81, 1.02, 1.41, 1.64, 1.91, 2.3, 2.66, 3.57] | P -Tyreotropiini | Plasma |  | Thyrotropin | Narrative |  | Plasma | Nar | Point in time (spot) | FALSE |
| 630 | pf-kol | mmol/l | 614 | 0 | [0.64, 0.93, 1.1, 1.3, 1.51, 1.75, 2.03, 2.36, 2.85] | Pf-Kolesteroli | Pleural fluid |  | Cholesterol | Substance Concentration |  | Pleural fluid | Qn | Point in time (spot) | FALSE |
| 631 | pf-kol |  | 361 | 98.06 |  | Pf-Kolesteroli | Pleural fluid |  | Cholesterol | Narrative |  | Pleural fluid | Nar | Point in time (spot) | FALSE |
| 632 | s-bil | umol/l | 15554 | 0 | [5.56, 6.89, 7.91, 8.95, 10.06, 11.55, 13.42, 16.35, 22.65] | S -Bilirubiini | Serum |  | Bilirubin | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 633 | s-bil |  | 183 | 82.51 | [5.99, 7.33, 8.34, 9.33, 10.81, 12.14, 14.24, 16.54, 22.13] | S -Bilirubiini | Serum |  | Bilirubin | Narrative |  | Serum | Nar | Point in time (spot) | FALSE |
| 634 | s-bio |  | 11283 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 635 | s-biol |  | 508 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 636 | s-fsh | iu/l | 21045 | 0 | [3.26, 4.67, 5.97, 7.58, 10.27, 17.4, 33.37, 51.85, 72.5] | S -Follikkelia stimuloiva hormoni | Serum |  | Follicle stimulating hormone | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 637 | s-fsh | u/l | 14312 | 0.62 | [3.48, 4.97, 6.16, 7.42, 9.34, 13.61, 26.1, 47.59, 73.43] | S -Follikkelia stimuloiva hormoni | Serum |  | Follicle stimulating hormone | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 638 | s-fsh |  | 1106 | 100 | [3.11, 4.58, 5.88, 7.13, 8.92, 13.11, 23.72, 44.2, 70.34] | S -Follikkelia stimuloiva hormoni | Serum |  | Follicle stimulating hormone | Narrative |  | Serum | Nar | Point in time (spot) | FALSE |
| 639 | s-kol | mg/ml | 9 | 0 |  | S -Kolesteroli | Serum |  | Cholesterol | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 640 | s-kol | mmol/l | 35285 | 0 | [3.59, 4.01, 4.33, 4.59, 4.85, 5.11, 5.39, 5.71, 6.19] | S -Kolesteroli | Serum |  | Cholesterol | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 641 | s-kol |  | 396 | 89.9 |  | S -Kolesteroli | Serum |  | Cholesterol | Narrative |  | Serum | Nar | Point in time (spot) | FALSE |
| 642 | s-mg | mmol/l | 5982 | 0 | [0.77, 0.81, 0.83, 0.85, 0.87, 0.88, 0.9, 0.92, 0.95] | S -Magnesium | Serum |  | Magnesium | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 643 | s-mg |  | 23 | 69.57 | [0.75, 0.78, 0.8, 0.82, 0.83, 0.85, 0.87, 0.89, 0.91] | S -Magnesium | Serum |  | Magnesium | Narrative |  | Serum | Nar | Point in time (spot) | FALSE |
| 644 | s-nse | ug/l | 10085 | 0.04 | [9.38, 10.96, 12, 13.1, 14.43, 16.18, 18.88, 24.33, 45.7] | S -Neuronispesifinen enolaasi | Serum |  | Neuron specific enolase | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 645 | s-nse |  | 210 | 45.24 | [8.56, 10, 10.8, 12.01, 14.24, 17, 20.25, 24.5, 29.28] | S -Neuronispesifinen enolaasi | Serum |  | Neuron specific enolase | Narrative |  | Serum | Nar | Point in time (spot) | FALSE |
| 646 | s-tsh | miu/l | 117078 | 0 | [0.56, 0.91, 1.16, 1.39, 1.62, 1.89, 2.23, 2.72, 3.61] | S -Tyreotropiini | Serum |  | Thyrotropin | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 647 | s-tsh | mlu/l | 113 | 0 | [0.33, 0.69, 1.02, 1.22, 1.42, 1.62, 2, 2.33, 2.93] | S -Tyreotropiini | Serum |  | Thyrotropin | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 648 | s-tsh | mu/l | 253056 | 0 | [0.62, 0.91, 1.15, 1.36, 1.59, 1.85, 2.18, 2.64, 3.49] | S -Tyreotropiini | Serum |  | Thyrotropin | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 649 | s-tsh | u/l | 142 | 0 | [0.52, 0.94, 1.22, 1.48, 1.73, 1.98, 2.18, 2.57, 4.01] | S -Tyreotropiini | Serum |  | Thyrotropin | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 650 | s-tsh |  | 4491 | 100 | [0.62, 0.91, 1.18, 1.45, 1.66, 1.95, 2.23, 2.72, 3.49] | S -Tyreotropiini | Serum |  | Thyrotropin | Narrative |  | Serum | Nar | Point in time (spot) | FALSE |
| 651 | se-bil | umol/l | 526 | 1.33 | [9.24, 12.96, 16.08, 20.31, 26.93, 38.21, 60.68, 119.92, 333.14] |  | Secretion |  | Bilirubin | Substance Concentration |  | Secretion | Qn | Point in time (spot) | FALSE |
| 652 | se-bil |  | 102 | 99.02 |  |  | Secretion |  | Bilirubin | Narrative |  | Secretion | Nar | Point in time (spot) | FALSE |
| 653 | u-al | umol/l | 81 | 0 | [0.1, 0.1, 0.2, 0.2, 0.22, 0.3, 0.4, 0.7, 1.7] | U -Alumiini | Urine |  | Aluminum | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 654 | u-al |  | 87 | 97.7 |  | U -Alumiini | Urine |  | Aluminum | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 655 | u-amp |  | 158 | 100 |  |  | Urine |  | Amphetamines | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 656 | u-as-i | nmol/l | 16 | 0 |  | U -Arseeni, epäorgaaninen | Urine |  | Arsenic.inorganic | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 657 | u-as-i | ug/l | 20 | 0 |  | U -Arseeni, epäorgaaninen | Urine |  | Arsenic.inorganic | Mass Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 658 | u-as-i |  | 107 | 100 |  | U -Arseeni, epäorgaaninen | Urine |  | Arsenic.inorganic | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 659 | u-bil |  | 441 | 100 |  |  | Urine |  | Bilirubin | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 660 | u-bio |  | 2387 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 661 | u-bup |  | 145 | 100 |  |  | Urine |  | Buprenorphine | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 662 | u-bzd |  | 143 | 100 |  |  | Urine |  | Benzodiazepines | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 663 | u-cl | mmol/l | 200 | 1.5 | [30.37, 49.43, 62.98, 72.55, 86.28, 96.56, 114.04, 135.66, 174.02] | U -Kloridi | Urine | Clearance | Chloride | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 664 | u-cl |  | 33 | 72.73 |  | U -Kloridi | Urine | Clearance | Chloride | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 665 | u-dala | umol/l | 111 | 0.9 | [5, 8, 10.96, 13.72, 17, 20.55, 23.93, 29.9, 40.27] | U -Delta-aminolevulinaatti | Urine |  | Aminolevulinate | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 666 | u-ds4a |  | 461 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 667 | u-ds5 |  | 133 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 668 | u-ds5b |  | 1156 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 669 | u-ds6 |  | 386 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 670 | u-ds6a |  | 1325 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 671 | u-ery |  | 3788 | 99.71 |  |  | Urine |  | Erythrocytes | Presence or Threshold | Test strip | Urine | SemiQn | Point in time (spot) | FALSE |
| 672 | u-fyl |  | 145 | 100 |  |  | Urine |  | Fentanyl | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 673 | u-hg | nmol/l | 108 | 0 |  | U -Elohopea | Urine |  | Mercury | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 674 | u-hg |  | 25 | 100 |  | U -Elohopea | Urine |  | Mercury | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 675 | u-i | ug/l | 309 | 0 | [44.03, 61.73, 78.06, 96.82, 115.33, 136.79, 163.87, 204.07, 318.14] | U -Jodidi | Urine |  | Iodide | Mass Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 676 | u-i |  | 18 | 88.89 |  | U -Jodidi | Urine |  | Iodide | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 677 | u-inf |  | 51657 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 678 | u-intp | nmol/mmol | 2098 | 0 | [16.36, 22.55, 28.43, 35.25, 42.57, 53.83, 68.67, 92.78, 154.47] | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I N-terminal telopeptide | Substance Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 679 | u-intp | nmol/mmolkr | 14 | 0 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I N-terminal telopeptide | Substance Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 680 | u-intp | ratio | 47 | 0 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I N-terminal telopeptide | Substance Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 681 | u-intp |  | 1030 | 94.47 |  | U -Kollageeni I:n aminoterminaalinen telopeptidi | Urine |  | Collagen type I N-terminal telopeptide | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 682 | u-kivi | form | 60 | 100 |  | U -Kivianalyysi | Urine |  | Calculus (stone) analysis | Finding |  | Urine | Nar | Point in time (spot) | FALSE |
| 683 | u-kivi |  | 1820 | 100 |  | U -Kivianalyysi | Urine |  | Calculus (stone) analysis | Finding |  | Urine | Nar | Point in time (spot) | FALSE |
| 684 | u-mg | mmol/l | 123 | 0.81 | [0.84, 1.34, 1.62, 1.98, 2.27, 2.78, 3.64, 4.45, 6.45] | U -Magnesium | Urine |  | Magnesium | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 685 | u-mg |  | 26 | 38.46 |  | U -Magnesium | Urine |  | Magnesium | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 686 | u-mtd |  | 144 | 100 |  |  | Urine |  | Methadone | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 687 | u-ni | form | 57 | 0 |  | U -Nikkeli | Urine |  | Nickel | Finding |  | Urine | Nar | Point in time (spot) | FALSE |
| 688 | u-ni | ug/l | 65 | 0 |  | U -Nikkeli | Urine |  | Nickel | Mass Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 689 | u-ni | umol/l | 754 | 0 | [0.01, 0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.06] | U -Nikkeli | Urine |  | Nickel | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 690 | u-ni |  | 323 | 90.71 |  | U -Nikkeli | Urine |  | Nickel | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 691 | u-pbg | umol/l | 248 | 1.61 | [1, 2, 2, 3, 3.9, 4.42, 5, 6.04, 8.79] | U -Porfobilinogeeni | Urine |  | Porphobilinogen | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 692 | u-pbg | umol/mmol | 6 | 0 |  | U -Porfobilinogeeni | Urine |  | Porphobilinogen | Substance Ratio |  | Urine | Qn | Point in time (spot) | FALSE |
| 693 | u-pbg |  | 33 | 51.52 |  | U -Porfobilinogeeni | Urine |  | Porphobilinogen | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 694 | u-pgb |  | 144 | 100 |  |  | Urine |  | Porphobilinogen | Presence or Threshold |  | Urine | Ord | Point in in time (spot) | FALSE |
| 695 | u-ph. |  | 24516 | 1.33 | [5, 5.5, 5.5, 5.87, 6, 6.26, 6.5, 6.96, 7.02] |  | Urine |  | pH | pH |  | Urine | Qn | Point in time (spot) | FALSE |
| 696 | u-phv |  | 737 | 0.27 | [5, 5.5, 5.5, 5.66, 6, 6, 6.5, 7, 7] |  | Urine |  | pH | pH |  | Urine | Qn | Point in time (spot) | FALSE |
| 697 | u-pi | mmol/l | 772 | 0.13 | [4.87, 7.61, 10.55, 13.2, 16.31, 20.1, 24.74, 31.17, 40.13] | U -Fosfaatti, epäorgaaninen | Urine |  | Phosphate | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 698 | u-pi |  | 84 | 54.76 |  | U -Fosfaatti, epäorgaaninen | Urine |  | Phosphate | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 699 | u-pyr | form | 7 | 0 |  | U -Pyrenoli (1) | Urine |  | Pyrenol | Finding |  | Urine | Nar | Point in time (spot) | FALSE |
| 700 | u-pyr | ug/l | 6 | 0 |  | U -Pyrenoli (1) | Urine |  | Pyrenol | Mass Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 701 | u-pyr |  | 88 | 100 |  | U -Pyrenoli (1) | Urine |  | Pyrenol | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 702 | u-sed |  | 2162 | 99.95 |  |  | Urine |  | Urine sediment microscopy | Finding | Microscopy.light | Urine | Nar | Point in time (spot) | FALSE |
| 703 | u-sg | kg/l | 3827 | 0 | [1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity | Specific gravity |  | Urine | Qn | Point in time (spot) | FALSE |
| 704 | u-sg |  | 75 | 100 | [1, 1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.03] |  | Urine |  | Specific gravity | Narrative |  | Urine | Nar | Point in time (spot) | FALSE |
| 705 | u-thc |  | 157 | 100 |  |  | Urine |  | Tetrahydrocannabinol | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 706 | u-tml |  | 145 | 100 |  |  | Urine |  | Tramadol | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 707 | u-ubg |  | 441 | 100 |  |  | Urine |  | Urobilinogen | Presence or Threshold | Test strip | Urine | SemiQn | Point in time (spot) | FALSE |
| 708 | us-tsh | mu/l | 415 | 0.72 | [3.59, 4.74, 5.45, 6.2, 7.04, 7.92, 9.44, 11.82, 16.59] | uS-Tyreotropiini | Umbilical (blood) serum |  | Thyrotropin | Catalytic Concentration |  | Umbilical cord blood serum | Qn | Point in time (spot) | FALSE |
| 709 | us-tsh |  | 75 | 33.33 |  | uS-Tyreotropiini | Umbilical (blood) serum |  | Thyrotropin | Narrative |  | Umbilical cord blood serum | Nar | Point in time (spot) | FALSE |
| 710 | vp-dop |  | 154 | 100 |  | Valtimopaine, dopplermittaus |  |  | Arterial blood pressure | Pressure | Doppler | ^Patient | Qn | Point in time (spot) | FALSE |

