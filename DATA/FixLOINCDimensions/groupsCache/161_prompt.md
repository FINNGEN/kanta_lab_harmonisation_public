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
Here is group 161.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| C-peptide | C peptide | 0.915 | 8 | 4,100 |
| C-peptide | C peptide^post meal | 0.791 | 13 | 6,005 |
| C-peptide | C peptide^baseline | 0.773 | 0 | 0 |
| C-peptide | C peptide^2nd specimen | 0.764 | 0 | 0 |
| C-peptide | C peptide^5H post meal | 0.763 | 0 | 0 |
| Chlamydia pneumoniae | Chlamydophila pneumoniae | 0.919 | 0 | 0 |
| Chlamydia pneumoniae | Chlamydophila pneumoniae Ab | 0.800 | 0 | 0 |
| Chlamydia pneumoniae | Mycoplasma pneumoniae | 0.773 | 0 | 0 |
| Chlamydia pneumoniae | Chlamydophila pneumoniae+Chlamydophila psittaci | 0.770 | 0 | 0 |
| Chlamydia pneumoniae | Chlamydophila pneumoniae Ag | 0.768 | 0 | 0 |
| Follicle stimulating hormone | (none scored >= 0.75) |  |  |  |
| Glucose | Glucose | 1.000 | 116 | 2,411,012 |
| Haemophilus influenzae | Haemophilus influenzae | 1.000 | 0 | 0 |
| Human metapneumovirus | Human metapneumovirus | 1.000 | 0 | 0 |
| Human metapneumovirus | Human metapneumovirus B | 0.768 | 0 | 0 |
| Human metapneumovirus | Human metapneumovirus A | 0.756 | 0 | 0 |
| Large unstained cells | Large unstained cells | 1.000 | 0 | 0 |
| Large unstained cells | Large unstained cells/Leukocytes | 0.853 | 0 | 0 |
| Large unstained cells | Large unstained cells/100 leukocytes | 0.806 | 0 | 0 |
| Large unstained cells/Leukocytes | Large unstained cells/Leukocytes | 1.000 | 0 | 0 |
| Large unstained cells/Leukocytes | Large unstained cells | 0.881 | 0 | 0 |
| Large unstained cells/Leukocytes | Large unstained cells/100 leukocytes | 0.834 | 0 | 0 |
| Large unstained cells/Leukocytes | Unidentified cells/leukocytes | 0.766 | 0 | 0 |
| Legionella pneumophila | Legionella pneumophila | 1.000 | 0 | 0 |
| Legionella pneumophila | Legionella pneumophila 1 | 0.776 | 0 | 0 |
| Legionella pneumophila | Legionella pneumophila 2 | 0.774 | 0 | 0 |
| Legionella pneumophila | Legionella pneumophila 4 | 0.767 | 0 | 0 |
| Legionella pneumophila | Legionella pneumophila 3 | 0.766 | 0 | 0 |
| Luteinizing hormone | (none scored >= 0.75) |  |  |  |
| Monounsaturated fatty acids | Monounsaturated fatty acids | 1.000 | 0 | 0 |
| Mycoplasma pneumoniae | Mycoplasma pneumoniae | 1.000 | 0 | 0 |
| Mycoplasma pneumoniae | Mycoplasma pneumoniae Ab | 0.805 | 2 | 20,258 |
| Mycoplasma pneumoniae | Mycoplasma pneumoniae IgM | 0.790 | 3 | 16,231 |
| Mycoplasma pneumoniae | Chlamydophila pneumoniae | 0.781 | 0 | 0 |
| Mycoplasma pneumoniae | Mycoplasma pneumoniae IgG+IgM | 0.773 | 0 | 0 |
| Phosphatidylethanol | Phosphatidylethanol | 1.000 | 3 | 36,977 |
| Phosphatidylethanol | Phosphatidylethanol panel | 0.823 | 0 | 0 |
| Phosphatidylethanol | Phosphoethanolamine | 0.779 | 0 | 0 |
| Phosphatidylethanol | Phosphatidylethanolamine | 0.760 | 0 | 0 |
| Phosphatidylethanol | Phosphoethanolamine Ab | 0.756 | 0 | 0 |
| Polyunsaturated fatty acids | Polyunsaturated fatty acids | 1.000 | 0 | 0 |
| Saturated fatty acids | Saturated fatty acids | 1.000 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Number Concentration | Number Concentration | 1.000 | 507 | 49,434,956 |
| Number Fraction | Number Fraction | 1.000 | 482 | 8,246,054 |
| Number Fraction | Decimal number fraction | 0.787 | 1 | 6,152 |
| Number Fraction | Time Fraction | 0.765 | 0 | 0 |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Automated count | Automated count | 1.000 | 103 | 11,606,924 |
| Immunoassay | Immunoassay | 1.000 | 164 | 322,567 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with probe detection | 1.000 | 115 | 2,413,483 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with non-probe detection | 0.864 | 1 | 7,786 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5a | 0.770 | 0 | 0 |
| Nucleic acid amplification with probe detection | Probe with amplification | 0.759 | 2 | 14,699 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5b | 0.754 | 0 | 0 |
| Test strip | Test strip | 1.000 | 79 | 4,294,769 |
| Test strip | Test strip manual | 0.843 | 0 | 0 |
| Test strip | Test strip automated | 0.836 | 3 | 687,408 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Blood capillary | Blood capillary | 1.000 | 121 | 787,125 |
| Blood capillary | Blood capillary^Fetus | 0.763 | 0 | 0 |
| Cerebral spinal fluid | Cerebral spinal fluid | 1.000 | 150 | 183,922 |
| Interstitial fluid | Interstitial fluid | 1.000 | 0 | 0 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Stool | Stool | 1.000 | 42 | 537,967 |
| Stool | Stool.wet | 0.760 | 0 | 0 |
| Stool | Stool^Patient.gastrointestinal | 0.756 | 0 | 0 |
| White Blood Cells | White blood cells | 1.000 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1790 | b-fosfatidyylietanoli | umol/l | 4792 | 0 | [0.06, 0.1, 0.15, 0.22, 0.3, 0.44, 0.64, 0.94, 1.57] |  | Blood |  | Phosphatidylethanol | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1791 | b-fosfatidyylietanoli |  | 4963 | 89.32 | [0.09, 0.13, 0.17, 0.29, 0.43, 0.63, 0.85, 1.22, 1.87] |  | Blood |  | Phosphatidylethanol | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1792 | b-fosfatidyylietanoli,verestä | umol/l | 1555 | 0 | [0.06, 0.1, 0.15, 0.22, 0.29, 0.41, 0.59, 0.87, 1.44] |  | Blood |  | Phosphatidylethanol | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1793 | b-fosfatidyylietanoli,verestä |  | 1534 | 97.07 |  |  | Blood |  | Phosphatidylethanol | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1794 | b-fosfatidyylietanolivita | umol/l | 43 | 0 |  |  | Blood |  | Phosphatidylethanol | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1795 | b-fosfatidyylietanolivita |  | 69 | 100 |  |  | Blood |  | Phosphatidylethanol | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1796 | b-haemophilusinfluenzae |  | 144 | 100 |  |  | Blood |  | Haemophilus influenzae | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1797 | b-suuretvärjäytymättömätsolut | e9/l | 171 | 0 | [0.07, 0.09, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15, 0.18] |  | Blood |  | Large unstained cells | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1798 | chlamydiapneumoniae,nukleiin |  | 109 | 100 |  |  |  |  | Chlamydia pneumoniae | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1799 | follikkeliastimuloivahormoni | u/l | 138 | 0 | [3, 4.75, 6.19, 8.24, 10, 19.35, 36.42, 56.82, 73.33] |  |  |  | Follicle stimulating hormone | Arbitrary Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1800 | fosfatidyylietanoli | umol/l | 1540 | 0 | [0.05, 0.09, 0.14, 0.2, 0.29, 0.43, 0.63, 0.98, 1.62] |  |  |  | Phosphatidylethanol | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1801 | fosfatidyylietanoli |  | 1635 | 92.35 | [0.09, 0.19, 0.32, 0.43, 0.64, 0.89, 1.16, 1.43, 1.78] |  |  |  | Phosphatidylethanol | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1802 | fosfatidyylietanoli,verestä | umol/l | 3284 | 0 | [0.06, 0.08, 0.12, 0.16, 0.22, 0.3, 0.44, 0.66, 1.2] |  |  |  | Phosphatidylethanol | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1803 | fosfatidyylietanoli,verestä |  | 3273 | 98.93 |  |  |  |  | Phosphatidylethanol | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1804 | fosfatidyylietanoli,verestätth | umol/l | 35 | 0 |  |  |  |  | Phosphatidylethanol | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1805 | fosfatidyylietanoli,verestätth |  | 66 | 100 |  |  |  |  | Phosphatidylethanol | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1806 | fosfatidyylietanoli,veri | umol/l | 335 | 0 | [0.06, 0.1, 0.15, 0.2, 0.28, 0.39, 0.6, 0.91, 1.55] |  |  |  | Phosphatidylethanol | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1807 | fosfatidyylietanoli,veri |  | 333 | 91.89 |  |  |  |  | Phosphatidylethanol | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1808 | haemophilusinfluenzaenukleii |  | 459 | 100 |  |  |  |  | Haemophilus influenzae | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1809 | humaanimetapneumovirus,nukle |  | 109 | 100 |  |  |  |  | Human metapneumovirus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1810 | humanmetapneumovirus,ag |  | 102 | 100 |  |  |  |  | Human metapneumovirus | Presence or Threshold | Immunoassay |  | Ord | Point in time (spot) | FALSE |
| 1811 | l-suuretvärjääntymättömätsolut | % | 171 | 0 | [1.19, 1.35, 1.5, 1.62, 1.83, 1.97, 2.16, 2.45, 2.85] |  | Leukocyte |  | Large unstained cells/Leukocytes | Number Fraction | Automated count | White Blood Cells | Qn | Point in time (spot) | FALSE |
| 1812 | legionellapneumoniaenukleiin |  | 109 | 100 |  |  |  |  | Legionella pneumophila | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1813 | li-haemophilusinfluenzaenukl.haponos. |  | 119 | 100 |  |  | Cerebrospinal fluid |  | Haemophilus influenzae | Presence or Threshold | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 1814 | mycoplasmapneumoniae,nukleii |  | 141 | 100 |  |  |  |  | Mycoplasma pneumoniae | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1815 | p-follikkeliastimuloivahormoni | u/l | 511 | 0 | [2.89, 4.55, 5.71, 7.4, 9.51, 16.11, 32.21, 53.45, 77.25] |  | Plasma |  | Follicle stimulating hormone | Arbitrary Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1816 | p-glukoosi,2tuntiaaterianjälkeen | mmol/l | 125 | 0 | [6.3, 7.71, 9.12, 10.17, 11.1, 12.22, 14.28, 15.89, 18.81] |  | Plasma |  | Glucose | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1817 | p-glukoosi,toimintakokeissa,1h | mmol/l | 126 | 0 | [5.54, 6.18, 6.52, 7.01, 7.43, 7.82, 8.23, 9.1, 9.88] |  | Plasma |  | Glucose | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1818 | p-glukoosi,toimintakokeissa,2h | mmol/l | 240 | 0 | [4.47, 5.01, 5.34, 5.8, 6.31, 7.03, 7.79, 8.75, 11.07] |  | Plasma |  | Glucose | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1819 | p-glukoosi,toimntakokeissa0m | mmol/l | 242 | 0 | [4.3, 4.6, 4.8, 5.01, 5.22, 5.42, 5.83, 6.26, 6.93] |  | Plasma |  | Glucose | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1820 | p-luteinisoivahormoni | u/l | 198 | 0 | [2.79, 3.77, 4.73, 5.42, 6.66, 8.63, 10.71, 14.48, 27.26] |  | Plasma |  | Luteinizing hormone | Arbitrary Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1821 | p-luteinisoivahormoni |  | 10 | 100 |  |  | Plasma |  | Luteinizing hormone | Presence or Threshold |  | Plasma | Ord | Point in time (spot) | FALSE |
| 1822 | p-omagluk,,potilasmittaringlukoosi |  | 1376 | 100 |  |  | Plasma |  | Glucose |  |  | Plasma | Nar | Point in time (spot) | FALSE |
| 1823 | potilasmittaringlukoosi,ihopisto | mmol/l | 749 | 0 | [5.9, 6.36, 6.79, 7.19, 7.51, 7.86, 8.26, 8.85, 9.69] |  |  |  | Glucose | Substance Concentration | Test strip | Blood capillary | Qn | Point in time (spot) | FALSE |
| 1824 | potilasmittaringlukoosi,ihopisto |  | 638 | 100 |  |  |  |  | Glucose |  | Test strip | Blood capillary | Nar | Point in time (spot) | FALSE |
| 1825 | potilasmittaringlukoosi,sensori | mmol/l | 201 | 0 | [5.55, 6.53, 7.01, 7.7, 8.35, 9.14, 10.02, 11.7, 13.49] |  |  |  | Glucose | Substance Concentration |  | Interstitial fluid | Qn | Point in time (spot) | FALSE |
| 1826 | potilasmittaringlukoosi,sensori |  | 568 | 100 |  |  |  |  | Glucose |  |  | Interstitial fluid | Nar | Point in time (spot) | FALSE |
| 1827 | s-c-peptidi1haterianjälkeen | nmol/l | 275 | 0 | [0.5, 0.75, 0.96, 1.2, 1.4, 1.62, 1.92, 2.33, 3.08] |  | Serum |  | C-peptide | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1828 | s-c-peptidi1haterianjälkeen |  | 10 | 90 |  |  | Serum |  | C-peptide | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1829 | s-c-peptidiaterianjälkeen | nmol/l | 150 | 0 | [0.4, 0.65, 0.9, 1.07, 1.22, 1.49, 2.03, 2.41, 2.88] |  | Serum |  | C-peptide | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1830 | s-follikkeliastimuloivahormoni | iu/l | 416 | 0 | [3.31, 4.85, 6.04, 7.33, 10.33, 18.46, 32.36, 54.77, 76.02] |  | Serum |  | Follicle stimulating hormone | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1831 | s-follikkeliastimuloivahormoni | u/l | 80 | 0 | [3.2, 4.8, 5.65, 6.55, 7.78, 10.22, 16.95, 45.35, 68.7] |  | Serum |  | Follicle stimulating hormone | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1832 | s-follikkeliastimuloivahormoni |  | 7 | 100 |  |  | Serum |  | Follicle stimulating hormone | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1833 | s-kertatyydyttymättömätrasvahapot | mmol/l | 263 | 0 | [2.43, 2.7, 2.8, 2.99, 3.17, 3.35, 3.54, 3.9, 4.36] |  | Serum |  | Monounsaturated fatty acids | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1834 | s-luteinisoivahormoni | iu/l | 178 | 0 | [1.51, 2.37, 3.11, 3.71, 4.6, 5.61, 7.56, 11.94, 22.46] |  | Serum |  | Luteinizing hormone | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1835 | s-luteinisoivahormoni | u/l | 26 | 0 |  |  | Serum |  | Luteinizing hormone | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1836 | s-luteinisoivahormoni |  | 14 | 100 |  |  | Serum |  | Luteinizing hormone | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1837 | s-monityydyttymättömätrasvahapot | mmol/l | 255 | 0 | [4.74, 4.99, 5.23, 5.48, 5.58, 5.7, 5.92, 6.18, 6.55] |  | Serum |  | Polyunsaturated fatty acids | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1838 | s-monityydyttymättömätrasvahapot |  | 11 | 100 |  |  | Serum |  | Polyunsaturated fatty acids |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 1839 | s-tyydyttyneetrasvahapot | mmol/l | 265 | 0 | [3.09, 3.37, 3.58, 3.77, 3.9, 4.15, 4.36, 4.73, 5.26] |  | Serum |  | Saturated fatty acids | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1840 | ulosteenripulivirukset,nukle |  | 109 | 100 |  |  |  |  |  |  | Nucleic acid amplification with probe detection | Stool |  |  | TRUE |

