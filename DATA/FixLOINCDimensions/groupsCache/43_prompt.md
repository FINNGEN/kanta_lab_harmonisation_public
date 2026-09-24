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
Here is group 43.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| 5-Hydroxyindoleacetic acid | 5-Hydroxyindoleacetate | 0.890 | 5 | 10,627 |
| 5-Hydroxyindoleacetic acid | 5-Hydroxyindoleacetate panel | 0.793 | 0 | 0 |
| 5-Hydroxyindoleacetic acid | 5-Hydroxyindoleacetate/Creatinine | 0.790 | 0 | 0 |
| 5-Hydroxyindoleacetic acid | 5-Hydroxyindoleacetate and Creatinine | 0.776 | 0 | 0 |
| Adenosine deaminase | Adenosine deaminase | 1.000 | 8 | 8,599 |
| Adenosine deaminase | Adenosine deaminase binding protein | 0.830 | 0 | 0 |
| Adenosine deaminase | Adenosine monophosphate deaminase | 0.826 | 0 | 0 |
| Alpha-1-Fetoprotein | Alpha-1-Fetoprotein | 1.000 | 4 | 20,986 |
| Alpha-1-Fetoprotein | Alpha-1-Fetoprotein Ab | 0.918 | 0 | 0 |
| Alpha-1-Fetoprotein | Alpha-1-fetoprotein Ag | 0.901 | 0 | 0 |
| Alpha-1-Fetoprotein | Alpha-1-Fetoprotein panel | 0.866 | 0 | 0 |
| Alpha-1-Fetoprotein | Alpha-1-fetoprotein.tumor marker | 0.843 | 0 | 0 |
| Amikacin | Amikacin | 1.000 | 0 | 0 |
| Angiotensin converting enzyme | Angiotensin converting enzyme | 1.000 | 11 | 43,074 |
| Anti-Mullerian hormone | (none scored >= 0.75) |  |  |  |
| Bromide | Bromide | 1.000 | 0 | 0 |
| Choriogonadotropin | Choriogonadotropin | 1.000 | 17 | 98,732 |
| Choriogonadotropin | Choriogonadotropin Ag | 0.848 | 0 | 0 |
| Choriogonadotropin | Choriomammotropin | 0.813 | 0 | 0 |
| Choriogonadotropin | Choriogonadotropin (pregnancy test) | 0.789 | 0 | 0 |
| Choriogonadotropin | Choriogonadotropin^^adjusted | 0.757 | 2 | 21,721 |
| Cold agglutinin | Cold agglutinin | 1.000 | 2 | 999 |
| Cold agglutinin | Cold agglutinin^24H post incubation | 0.821 | 0 | 0 |
| Cold agglutinin | Cold agglutinin^1H post incubation | 0.821 | 0 | 0 |
| Cold agglutinin | Cold agglutinin panel | 0.819 | 0 | 0 |
| Dehydroepiandrosterone (DHEA) | Dehydroepiandrosterone | 0.899 | 0 | 0 |
| Dehydroepiandrosterone (DHEA) | Dehydroepiandrosterone sulfate | 0.760 | 3 | 4,116 |
| Dehydroepiandrosterone sulfate (DHEA-S) | Dehydroepiandrosterone sulfate | 0.891 | 3 | 4,116 |
| Dehydroepiandrosterone sulfate (DHEA-S) | Dehydroepiandrosterone sulfate/cortisol | 0.819 | 0 | 0 |
| Dehydroepiandrosterone sulfate (DHEA-S) | Dehydroepiandrosterone | 0.786 | 0 | 0 |
| Dehydroepiandrosterone sulfate (DHEA-S) | Dehydroepiandrosterone sulfate/Creatinine | 0.779 | 0 | 0 |
| Dehydroepiandrosterone sulfate (DHEA-S) | Dehydroepiandrosterone sulfate^baseline | 0.768 | 0 | 0 |
| Endomysial Ab | Endomysium Ab | 0.863 | 0 | 0 |
| Endomysial Ab | Endomysium Ab.IgM | 0.834 | 0 | 0 |
| Endomysial Ab | Endomysium IgG | 0.780 | 3 | 5,197 |
| Erythropoietin | Erythropoietin | 1.000 | 9 | 9,513 |
| Erythropoietin | Erythropoietin Ab | 0.780 | 0 | 0 |
| Estradiol | Estradiol | 1.000 | 11 | 14,186 |
| Estradiol | Estrone | 0.813 | 3 | 153 |
| Estradiol | Estrogen | 0.808 | 0 | 0 |
| Estradiol | Estriol | 0.780 | 0 | 0 |
| Estradiol | Estrone sulfate | 0.778 | 0 | 0 |
| Estrone | Estrone | 1.000 | 3 | 153 |
| Estrone | Estradiol | 0.789 | 11 | 14,186 |
| Estrone | Estrone sulfate | 0.758 | 0 | 0 |
| Extractable nuclear Ab | Extractable nuclear Ab | 1.000 | 12 | 26,012 |
| Extractable nuclear Ab | Extractable nuclear Ab identified | 0.919 | 0 | 0 |
| Extractable nuclear Ab | Extractable nuclear Ab panel | 0.894 | 4 | 3,253 |
| Extractable nuclear Ab | Smith extractable nuclear Ab | 0.882 | 12 | 21,948 |
| Extractable nuclear Ab | Unidentified extractable nuclear Ab | 0.857 | 0 | 0 |
| Fatty acids.free | Fatty acids | 0.784 | 0 | 0 |
| Fatty acids.free | Fatty acids.nonesterified | 0.778 | 1 | 518 |
| Fatty acids.free | Fatty acids.long chain | 0.771 | 0 | 0 |
| Fatty acids.free | Fatty acids.esterified | 0.765 | 0 | 0 |
| Gentamicin | Gentamicin | 1.000 | 3 | 712 |
| Gentamicin | Gentamicin.high potency | 0.752 | 0 | 0 |
| Hepatitis B virus e Ag | Hepatitis B virus e Ag | 1.000 | 1 | 488 |
| Hepatitis B virus e Ag | Hepatitis B virus e Ab | 0.942 | 1 | 462 |
| Hepatitis B virus e Ag | Hepatitis B virus e | 0.849 | 0 | 0 |
| Hepatitis B virus e Ag | Hepatitis B virus e IgG | 0.843 | 0 | 0 |
| Hepatitis B virus e Ag | Hepatitis B virus surface Ag | 0.800 | 2 | 147,462 |
| Human epididymis protein 4 | Human epididymis protein 4 | 1.000 | 8 | 14,218 |
| Nuclear Ab | Nuclear Ab | 1.000 | 23 | 99,502 |
| Nuclear Ab | Nuclear Ab pattern | 0.822 | 0 | 0 |
| Nuclear Ab | Extractable nuclear Ab | 0.764 | 12 | 26,012 |
| Nuclear Ab | Nuclear Ab.histone reactive | 0.755 | 0 | 0 |
| Platelet aggregation ADP induced | Platelet aggregation ADP induced | 1.000 | 0 | 0 |
| Platelet aggregation ADP induced | Platelet aggregation ADP induced ATP secretion | 0.863 | 0 | 0 |
| Platelet aggregation ADP induced | Platelet aggregation thrombin induced | 0.854 | 0 | 0 |
| Platelet aggregation ADP induced | Platelet aggregation arachidonate induced | 0.854 | 0 | 0 |
| Platelet aggregation ADP induced | Platelet aggregation adenosine diphosphate+prostaglandin E1 induced | 0.841 | 0 | 0 |
| Platelet aggregation arachidonic acid induced | Platelet aggregation arachidonate induced | 0.971 | 0 | 0 |
| Platelet aggregation arachidonic acid induced | Platelet aggregation.arachidonate induced^500 ug/mL | 0.888 | 0 | 0 |
| Platelet aggregation arachidonic acid induced | Platelet aggregation.arachidonate induced^1.6 mmol/L | 0.879 | 0 | 0 |
| Platelet aggregation arachidonic acid induced | Platelet aggregation.arachidonate induced^500 umol/L | 0.878 | 0 | 0 |
| Platelet aggregation arachidonic acid induced | Platelet aggregation arachidonate induced ATP secretion | 0.870 | 0 | 0 |
| Saccharomyces cerevisiae Ab | Baker's yeast (Saccharomyces cerevisiae) Ab | 0.871 | 1 | 315 |
| Saccharomyces cerevisiae Ab | Sacccaromyces cerevisiae Ab.IgG | 0.826 | 0 | 0 |
| Saccharomyces cerevisiae Ab | Brewer's yeast Ab | 0.770 | 0 | 0 |
| Sex hormone binding globulin | Sex hormone binding globulin | 1.000 | 5 | 29,702 |
| Staphylolysin Ab | Staphylolysin Ab | 1.000 | 4 | 2,520 |
| Staphylolysin Ab | Staphylolysin | 0.830 | 0 | 0 |
| Streptolysin O Ab | Streptolysin O Ab | 1.000 | 3 | 2,457 |
| Streptolysin O Ab | Streptolysin O | 0.902 | 0 | 0 |
| Streptolysin O Ab | Streptolysin O Ab^2nd specimen | 0.828 | 0 | 0 |
| Streptolysin O Ab | Streptolysin O Ab^1st specimen | 0.828 | 0 | 0 |
| Treponema pallidum Ab | Treponema pallidum Ab | 1.000 | 8 | 119,525 |
| Treponema pallidum Ab | Treponema pallidum Ag | 0.894 | 0 | 0 |
| Treponema pallidum Ab | Treponema pallidum IgG | 0.862 | 0 | 0 |
| Treponema pallidum Ab | Treponema sp Ab | 0.842 | 0 | 0 |
| Treponema pallidum Ab | Treponema pallidum Ab.IgG band 15 | 0.816 | 0 | 0 |
| Tumor-associated trypsin inhibitor | (none scored >= 0.75) |  |  |  |
| Vancomycin | Vancomycin | 1.000 | 4 | 44,276 |
| Vancomycin | Vancomycin^random | 0.790 | 0 | 0 |
| Vasodilator-stimulated phosphoprotein phosphorylation | (none scored >= 0.75) |  |  |  |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Arbitrary unit | (none scored >= 0.75) |  |  |  |
| Catalytic Concentration | Catalytic Concentration | 1.000 | 228 | 10,802,985 |
| Catalytic Concentration | Relative catalytic concentration | 0.848 | 9 | 39,650 |
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Ratio | Ratio | 1.000 | 88 | 786,172 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |
| Substance Rate | Substance Rate | 1.000 | 41 | 25,881 |
| Substance Rate | Mass or Substance Rate | 0.799 | 2 | 118 |
| Substance Rate | Substance Ratio | 0.794 | 9 | 237,272 |
| Titer | Titer | 1.000 | 146 | 279,254 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Agglutination | Agglutination | 1.000 | 2 | 110 |
| Agglutination | Hemagglutination | 0.771 | 4 | 11,584 |
| Agglutination | Ring agglutination | 0.767 | 0 | 0 |
| Flow cytometry (FC) | Flow cytometry (FC) | 1.000 | 1 | 650 |
| Hemagglutination | Hemagglutination | 1.000 | 4 | 11,584 |
| Hemagglutination | Agglutination | 0.770 | 2 | 110 |
| Immunoassay | Immunoassay | 1.000 | 164 | 322,567 |
| Immunofluorescence (IF) | Immunofluorescence (IF) | 1.000 | 37 | 44,647 |
| Platelet aggregation | Platelet aggregation | 1.000 | 0 | 0 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Amniotic fluid | Amniotic fluid | 1.000 | 1 | 73 |
| Amniotic fluid | Amniotic fluid space | 0.775 | 0 | 0 |
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Cerebral spinal fluid | Cerebral spinal fluid | 1.000 | 150 | 183,922 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Tissue | Tissue | 1.000 | 0 | 0 |
| Urine | Urine | 1.000 | 586 | 16,080,701 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 482 | -ana | titre | 21 | 14.29 |  | -Tuma, vasta-aineet |  |  | Nuclear Ab | Titer | Immunofluorescence (IF) |  | SemiQn | Point in time (spot) | FALSE |
| 483 | -ana |  | 169 | 100 |  | -Tuma, vasta-aineet |  |  | Nuclear Ab | Presence or Threshold | Immunofluorescence (IF) |  | Ord | Point in time (spot) | FALSE |
| 484 | am-epo | iu/l | 76 | 0 |  | Am-Erytropoietiini | Amniotic fluid |  | Erythropoietin | Arbitrary Concentration |  | Amniotic fluid | Qn | Point in time (spot) | FALSE |
| 485 | am-epo | u/l | 267 | 0.75 | [2.67, 3.48, 4.24, 4.97, 5.92, 7.13, 8.38, 10.84, 21.7] | Am-Erytropoietiini | Amniotic fluid |  | Erythropoietin | Arbitrary Concentration |  | Amniotic fluid | Qn | Point in time (spot) | FALSE |
| 486 | am-epo |  | 31 | 45.16 |  | Am-Erytropoietiini | Amniotic fluid |  | Erythropoietin | Arbitrary Concentration |  | Amniotic fluid | Qn | Point in time (spot) | FALSE |
| 487 | b-adp | auc | 28 | 0 |  |  | Blood |  | Platelet aggregation ADP induced | Arbitrary unit | Platelet aggregation | Blood | Qn | Point in time (spot) | FALSE |
| 488 | b-adp |  | 340 | 100 |  |  | Blood |  | Platelet aggregation ADP induced | Finding | Platelet aggregation | Blood | Nar | Point in time (spot) | FALSE |
| 489 | b-aspi | auc | 28 | 0 |  |  | Blood |  | Platelet aggregation arachidonic acid induced | Arbitrary unit | Platelet aggregation | Blood | Qn | Point in time (spot) | FALSE |
| 490 | b-aspi |  | 340 | 100 |  |  | Blood |  | Platelet aggregation arachidonic acid induced | Finding | Platelet aggregation | Blood | Nar | Point in time (spot) | FALSE |
| 491 | b-vasp | % | 165 | 0 | [15.56, 23.85, 29.41, 35.04, 41.24, 50.14, 56.77, 61.91, 75.84] |  | Blood |  | Vasodilator-stimulated phosphoprotein phosphorylation | Ratio | Flow cytometry (FC) | Blood | Qn | Point in time (spot) | FALSE |
| 492 | b-vasp |  | 67 | 61.19 |  |  | Blood |  | Vasodilator-stimulated phosphoprotein phosphorylation | Ratio | Flow cytometry (FC) | Blood | Qn | Point in time (spot) | FALSE |
| 493 | du-5hiaa | umol | 332 | 1.51 | [14.87, 17.89, 19.97, 21.96, 24, 26.85, 29.92, 35.9, 54.08] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid | Substance Rate |  | Urine | Qn | 24 hours | FALSE |
| 494 | du-5hiaa | umol/24h | 175 | 0 | [13.31, 17.22, 20.27, 23.53, 25.81, 31.1, 37.11, 45.94, 66.13] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid | Substance Rate |  | Urine | Qn | 24 hours | FALSE |
| 495 | du-5hiaa | umol/l | 25 | 0 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid | Substance Concentration |  | Urine | Qn | 24 hours | FALSE |
| 496 | du-5hiaa |  | 147 | 66.67 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid | Substance Rate |  | Urine | Qn | 24 hours | FALSE |
| 497 | fs-ace | u/l | 33401 | 0.05 | [20.1, 26.68, 31.86, 36.8, 41.71, 47.15, 53.87, 62.77, 76.91] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  | Angiotensin converting enzyme | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 498 | fs-ace |  | 3291 | 89.58 | [11.62, 22.24, 28.9, 33.73, 39.48, 44.52, 50.34, 61.92, 75.37] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  | Angiotensin converting enzyme | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 499 | fs-apot |  | 258 | 100 |  |  | Fasting serum |  |  |  |  | Serum |  |  | TRUE |
| 500 | fs-ffa | mmol/l | 170 | 0.59 | [0.17, 0.25, 0.3, 0.38, 0.42, 0.5, 0.56, 0.69, 0.91] | fS-Rasvahapot, vapaat | Fasting serum |  | Fatty acids.free | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 501 | fs-ffa |  | 19 | 36.84 |  | fS-Rasvahapot, vapaat | Fasting serum |  | Fatty acids.free | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 502 | fs-tp-1 |  | 1698 | 100 |  |  | Fasting serum |  |  |  |  | Serum |  |  | TRUE |
| 503 | fs-tp-3 |  | 867 | 100 |  |  | Fasting serum |  |  |  |  | Serum |  |  | TRUE |
| 504 | fs-tp-4 |  | 926 | 100 |  |  | Fasting serum |  |  |  |  | Serum |  |  | TRUE |
| 505 | fs-tp-7 |  | 400 | 100 |  |  | Fasting serum |  |  |  |  | Serum |  |  | TRUE |
| 506 | li-tpha | titre | 12 | 0 |  | Li-Treponema pallidum, hemagglutinaatio | Cerebrospinal fluid |  | Treponema pallidum Ab | Titer | Hemagglutination | Cerebral spinal fluid | SemiQn | Point in time (spot) | FALSE |
| 507 | li-tpha |  | 526 | 100 |  | Li-Treponema pallidum, hemagglutinaatio | Cerebrospinal fluid |  | Treponema pallidum Ab | Presence or Threshold | Hemagglutination | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 508 | p-hae |  | 461 | 100 |  |  | Plasma |  |  |  |  | Plasma |  |  | TRUE |
| 509 | p-hcg | iu/l | 858 | 0 | [3.54, 10.48, 27.87, 72.06, 203.74, 526.1, 1525.11, 5507.31, 17831.23] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin | Arbitrary Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 510 | p-hcg | u/l | 13156 | 11.71 | [0, 1.5, 5.06, 22.75, 97.57, 335.38, 1102.09, 3696.05, 18876.19] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin | Arbitrary Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 511 | p-hcg |  | 15471 | 94.78 | [2.42, 12.44, 35.69, 103.11, 288.41, 866.82, 2866.35, 7636.68, 32545.17] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin | Arbitrary Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 512 | p-he4 | pmol/l | 2505 | 0.12 | [38.55, 42.76, 46.82, 51.17, 55.95, 62.75, 72.7, 92.45, 146.15] | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  | Human epididymis protein 4 | Substance Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 513 | p-he4 |  | 6 | 100 |  | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  | Human epididymis protein 4 | Finding | Immunoassay | Plasma | Nar | Point in time (spot) | FALSE |
| 514 | p-hepg |  | 107 | 100 |  |  | Plasma |  |  |  |  | Plasma |  |  | FALSE |
| 515 | p-hok |  | 397 | 100 |  |  | Plasma |  |  |  |  | Plasma |  |  | FALSE |
| 516 | p-shbg | nmol/l | 791 | 0 | [18.37, 23.23, 26.61, 30.13, 34.18, 38.05, 43.25, 50.43, 63.9] |  | Plasma |  | Sex hormone binding globulin | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 517 | p-shbg |  | 758 | 4.09 | [17.37, 21.68, 26.35, 30.87, 35.48, 41.39, 46.88, 56, 72.07] |  | Plasma |  | Sex hormone binding globulin | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 518 | s-5hiaa | nmol/l | 10313 | 0.07 | [44.23, 52.73, 60.93, 69.76, 80.1, 94.8, 122.35, 200.37, 540.74] | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  | 5-Hydroxyindoleacetic acid | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 519 | s-5hiaa |  | 153 | 79.74 |  | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  | 5-Hydroxyindoleacetic acid | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 520 | s-ace | u/l | 2203 | 0.18 | [19.48, 28.37, 33.74, 38.42, 43.02, 48.21, 54.09, 61.63, 75.23] |  | Serum |  | Angiotensin converting enzyme | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 521 | s-ace |  | 769 | 20.68 | [21.02, 30.36, 34.97, 38.52, 42.83, 46.55, 51.62, 57.68, 65.53] |  | Serum |  | Angiotensin converting enzyme | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 522 | s-ada | u/l | 4147 | 1.33 | [7, 8.05, 9.23, 10.37, 11.69, 12.94, 14.77, 17.12, 21.32] | S -Adenosiinideaminaasi | Serum |  | Adenosine deaminase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 523 | s-ada |  | 259 | 84.56 |  | S -Adenosiinideaminaasi | Serum |  | Adenosine deaminase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 524 | s-afp | u/ml | 18186 | 1.26 | [1.8, 2.08, 2.61, 3.01, 3.6, 4.33, 5.57, 7.77, 24.79] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-1-Fetoprotein | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 525 | s-afp | ug/l | 2515 | 0 | [2, 2.23, 3, 3.96, 4.22, 5.38, 6.93, 9.7, 20.37] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-1-Fetoprotein | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 526 | s-afp |  | 4026 | 80.55 | [2, 2.01, 3, 3, 3.99, 4, 5, 6.41, 9.69] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-1-Fetoprotein | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 527 | s-afp/d | u/ml | 234 | 0 | [15.11, 17.44, 19.7, 22.07, 23.9, 26.33, 29.33, 33.17, 39.24] |  | Serum |  | Alpha-1-Fetoprotein | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 528 | s-afp/d |  | 49 | 12.24 |  |  | Serum |  | Alpha-1-Fetoprotein | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 529 | s-amh | ug/l | 9545 | 0.43 | [0.42, 0.85, 1.31, 1.75, 2.24, 2.87, 3.63, 4.76, 7.13] | S -Anti-Muller hormoni | Serum |  | Anti-Mullerian hormone | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 530 | s-amh |  | 1328 | 93.45 | [0.62, 1.11, 1.66, 2.28, 2.8, 3.57, 4.21, 5.32, 7.88] | S -Anti-Muller hormoni | Serum |  | Anti-Mullerian hormone | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 531 | s-ami | mg/l | 294 | 0 | [1.3, 1.49, 1.7, 2.28, 2.76, 3.41, 4.52, 6.36, 11.32] | S -Amikasiini | Serum |  | Amikacin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 532 | s-ami |  | 308 | 95.13 |  | S -Amikasiini | Serum |  | Amikacin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 533 | s-ana | titre | 21493 | 1.69 | [80, 121.94, 160, 299.08, 320, 320, 399.84, 831.19, 1349.55] | S -Tuma, vasta-aineet | Serum |  | Nuclear Ab | Titer | Immunofluorescence (IF) | Serum | SemiQn | Point in time (spot) | FALSE |
| 534 | s-ana |  | 62781 | 100 | [80, 160, 320, 320, 320, 320, 640, 762.94, 1891.15] | S -Tuma, vasta-aineet | Serum |  | Nuclear Ab | Presence or Threshold | Immunofluorescence (IF) | Serum | Ord | Point in time (spot) | FALSE |
| 535 | s-apot |  | 754 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | TRUE |
| 536 | s-asca | u/ml | 89 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  | Saccharomyces cerevisiae Ab | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 537 | s-asca |  | 316 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  | Saccharomyces cerevisiae Ab | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 538 | s-ast | iu/ml | 2404 | 0 | [49.92, 65.92, 77.55, 92.42, 111.12, 137.94, 173.28, 237.31, 396.71] | S -Antistreptolysiini | Serum |  | Streptolysin O Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 539 | s-ast | titre | 7 | 0 |  | S -Antistreptolysiini | Serum |  | Streptolysin O Ab | Titer |  | Serum | SemiQn | Point in time (spot) | FALSE |
| 540 | s-ast | u/ml | 408 | 4.17 | [30.71, 40.63, 53.38, 70.53, 94.49, 133.41, 202.61, 384.67, 783.66] | S -Antistreptolysiini | Serum |  | Streptolysin O Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 541 | s-ast |  | 2603 | 94.05 | [60.92, 74.22, 90.53, 107.5, 145.19, 198.62, 261.7, 407.28, 740.72] | S -Antistreptolysiini | Serum |  | Streptolysin O Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 542 | s-asta | iu/ml | 256 | 16.41 | [2, 2, 2, 2, 3.02, 4, 4.64, 6, 8] | S -Antistafylolysiini | Serum |  | Staphylolysin Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 543 | s-asta | u/ml | 10 | 0 |  | S -Antistafylolysiini | Serum |  | Staphylolysin Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 544 | s-asta |  | 2266 | 99.29 |  | S -Antistafylolysiini | Serum |  | Staphylolysin Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 545 | s-br | mmol/l | 130 | 0 |  | S -Bromidi | Serum |  | Bromide | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 546 | s-dhea | nmol/l | 398 | 0 | [2.68, 4.23, 5.8, 8.33, 11.06, 14.2, 18.42, 22.5, 33.54] | S -Dehydroepiandrosteroni | Serum |  | Dehydroepiandrosterone (DHEA) | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 547 | s-dhea |  | 74 | 68.92 |  | S -Dehydroepiandrosteroni | Serum |  | Dehydroepiandrosterone (DHEA) | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 548 | s-dheas | umol/l | 3797 | 0.03 | [1.05, 1.87, 2.83, 3.75, 4.58, 5.54, 6.67, 8.05, 10.29] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  | Dehydroepiandrosterone sulfate (DHEA-S) | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 549 | s-dheas |  | 331 | 53.47 | [1.45, 2.24, 2.88, 3.59, 4.26, 5.13, 5.94, 7.34, 8.82] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  | Dehydroepiandrosterone sulfate (DHEA-S) | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 550 | s-e1 | pmol/l | 123 | 0 | [70, 112.9, 136.88, 181.46, 224.33, 282.87, 347.03, 435.1, 621.18] | S -Estroni | Serum |  | Estrone | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 551 | s-e1 |  | 30 | 76.67 |  | S -Estroni | Serum |  | Estrone | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 552 | s-e2 | nmol/l | 10351 | 2.69 | [0.07, 0.1, 0.13, 0.16, 0.2, 0.27, 0.38, 0.55, 0.99] | S -Estradioli | Serum |  | Estradiol | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 553 | s-e2 |  | 2381 | 83.75 | [0.06, 0.08, 0.1, 0.12, 0.15, 0.19, 0.25, 0.35, 0.58] | S -Estradioli | Serum |  | Estradiol | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 554 | s-ema |  | 2245 | 99.96 |  | S -Endomysium, vasta-aineet | Serum |  | Endomysial Ab | Presence or Threshold | Immunofluorescence (IF) | Serum | Ord | Point in time (spot) | FALSE |
| 555 | s-ena |  | 1469 | 62.22 | [0.1, 0.1, 0.1, 0.19, 0.2, 0.22, 0.3, 0.47, 1.12] |  | Serum |  | Extractable nuclear Ab | Ratio | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 556 | s-enal |  | 832 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | TRUE |
| 557 | s-epo | iu/l | 2353 | 0.38 | [4.95, 7.08, 8.93, 10.78, 12.99, 15.54, 19.77, 28.75, 48.4] | S -Erytropoietiini | Serum |  | Erythropoietin | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 558 | s-epo | pmol/l | 44 | 0 |  | S -Erytropoietiini | Serum |  | Erythropoietin | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 559 | s-epo | u/l | 5380 | 0 | [4.44, 6.44, 8.09, 9.88, 11.93, 14.55, 19.01, 29.55, 62.33] | S -Erytropoietiini | Serum |  | Erythropoietin | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 560 | s-epo |  | 1209 | 20.35 | [4.6, 6.64, 8.47, 10.2, 11.81, 13.76, 17.07, 22.59, 40.53] | S -Erytropoietiini | Serum |  | Erythropoietin | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 561 | s-ffa | mmol/l | 518 | 0 | [0.03, 0.04, 0.07, 0.13, 0.19, 0.28, 0.44, 0.57, 0.75] |  | Serum |  | Fatty acids.free | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 562 | s-gen | mg/l | 373 | 0.54 | [0.5, 0.65, 0.75, 0.89, 0.99, 1.17, 1.48, 2.04, 3.94] | S -Gentamysiini | Serum |  | Gentamicin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 563 | s-gen |  | 339 | 85.55 |  | S -Gentamysiini | Serum |  | Gentamicin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 564 | s-hae |  | 751 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | TRUE |
| 565 | s-hbe |  | 347 | 100 |  |  | Serum |  | Hepatitis B virus e Ag | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 566 | s-hcg | iu/l | 2181 | 0 | [2.11, 4.62, 15.8, 53.63, 166.71, 442, 1018.25, 2912.42, 12003.73] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 567 | s-hcg | u/l | 5914 | 0 | [5.67, 20.66, 67.43, 172.44, 366.74, 677.25, 1513.49, 4378.78, 17452.46] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 568 | s-hcg |  | 16592 | 96.23 | [8.29, 17.67, 40.08, 108.43, 306.84, 912.85, 3181.52, 10206.39, 38671.9] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 569 | s-he4 | pmol/l | 11193 | 0 | [31.87, 37.18, 41.94, 46.96, 53.02, 60.99, 73.42, 98.24, 181.66] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  | Human epididymis protein 4 | Substance Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 570 | s-he4 |  | 420 | 43.57 | [28.77, 32.37, 35.15, 39.84, 42.92, 45.83, 51.37, 61.13, 81.8] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  | Human epididymis protein 4 | Substance Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 571 | s-kem |  | 1473 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | TRUE |
| 572 | s-kyhemag | titre | 180 | 1.67 | [8, 11.41, 16, 18.4, 42.5, 146.59, 256, 870.4, 2048] | S -Kylmähemagglutiniinit | Serum |  | Cold agglutinin | Titer | Agglutination | Serum | SemiQn | Point in time (spot) | FALSE |
| 573 | s-kyhemag |  | 826 | 99.39 |  | S -Kylmähemagglutiniinit | Serum |  | Cold agglutinin | Presence or Threshold | Agglutination | Serum | Ord | Point in time (spot) | FALSE |
| 574 | s-shbg | nmol/l | 29338 | 0 | [16.96, 21.37, 25.29, 29.19, 33.26, 37.98, 43.62, 51.6, 65.13] | S -Sukupuolihormoneja sitova globuliini | Serum |  | Sex hormone binding globulin | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 575 | s-shbg |  | 614 | 100 | [15.22, 19.74, 24.23, 28.3, 32.4, 37.12, 43.41, 51.5, 64.44] | S -Sukupuolihormoneja sitova globuliini | Serum |  | Sex hormone binding globulin | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 576 | s-tati | nmol/l | 551 | 0 | [1.3, 1.49, 1.61, 1.81, 2.08, 2.38, 2.74, 3.44, 6.09] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor-associated trypsin inhibitor | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 577 | s-tati | ug/l | 446 | 0 | [6.71, 8.1, 9.03, 9.98, 11, 12.24, 13.98, 16.99, 30.9] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor-associated trypsin inhibitor | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 578 | s-tati |  | 86 | 24.42 |  | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor-associated trypsin inhibitor | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 579 | s-tpha | titre | 1665 | 0 | [158.37, 304.61, 391.53, 640, 1034.44, 1338.85, 3168.84, 4985.37, 6432.72] | S -Treponema pallidum, hemagglutinaatio | Serum |  | Treponema pallidum Ab | Titer | Hemagglutination | Serum | SemiQn | Point in time (spot) | FALSE |
| 580 | s-tpha |  | 9799 | 99.67 |  | S -Treponema pallidum, hemagglutinaatio | Serum |  | Treponema pallidum Ab | Presence or Threshold | Hemagglutination | Serum | Ord | Point in time (spot) | FALSE |
| 581 | s-van | mg/l | 36935 | 0.09 | [6.84, 8.59, 9.97, 11.16, 12.39, 13.69, 15.03, 16.85, 19.72] | S -Vankomysiini | Serum |  | Vancomycin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 582 | s-van |  | 1695 | 100 | [7.35, 9.11, 10.49, 11.71, 12.89, 14.15, 15.61, 17.74, 21.29] | S -Vankomysiini | Serum |  | Vancomycin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 583 | ts-res |  | 1353 | 100 |  | Ts-Reseptoritutkimus | Tissue |  |  |  |  | Tissue |  |  | TRUE |
| 584 | u-hcg | iu/l | 93 | 0 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin | Arbitrary Concentration | Immunoassay | Urine | Qn | Point in time (spot) | FALSE |
| 585 | u-hcg | u/l | 15 | 0 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin | Arbitrary Concentration | Immunoassay | Urine | Qn | Point in time (spot) | FALSE |
| 586 | u-hcg |  | 227 | 97.8 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin | Presence or Threshold | Immunoassay | Urine | Ord | Point in time (spot) | FALSE |

