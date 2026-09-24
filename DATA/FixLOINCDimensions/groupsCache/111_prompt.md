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
Here is group 111.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Complement C1q antibody.IgG | Complement C1q Ab | 0.819 | 3 | 282 |
| Complement C1q antibody.IgG | Complement C1q | 0.814 | 0 | 0 |
| Complement C1q antibody.IgG | Complement C1q Ag | 0.789 | 0 | 0 |
| Complement C1q antibody.IgG | Complement C1q binding | 0.761 | 0 | 0 |
| SARS-CoV-2 | SARS-CoV-2 | 1.000 | 0 | 0 |
| SARS-CoV-2 | SARS-CoV-2 (COVID-19) | 0.889 | 0 | 0 |
| SARS-CoV-2 | SARS-CoV+SARS-CoV-2 (COVID-19) | 0.803 | 0 | 0 |
| SARS-CoV-2 | SARS coronavirus | 0.783 | 0 | 0 |
| SARS-CoV-2 | SARS-CoV-2 (COVID-19) RNA | 0.780 | 6 | 996,958 |
| SARS-CoV-2 & Influenza virus A & Influenza virus B & Respiratory syncytial virus RNA | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel | 0.832 | 2 | 45,357 |
| SARS-CoV-2 & Influenza virus A & Influenza virus B & Respiratory syncytial virus RNA | Influenza virus A and B and SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel | 0.804 | 0 | 0 |
| SARS-CoV-2 & Influenza virus A & Influenza virus B & Respiratory syncytial virus RNA | Influenza virus A and B and SARS-CoV-2 (COVID-19) | 0.803 | 0 | 0 |
| SARS-CoV-2 & Influenza virus A & Influenza virus B & Respiratory syncytial virus RNA | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel | 0.797 | 0 | 0 |
| SARS-CoV-2 & Influenza virus A & Influenza virus B & Respiratory syncytial virus RNA | Influenza virus A and Influenza virus B and SARS coronavirus 2 and Respiratory syncytial virus Ag panel | 0.792 | 0 | 0 |
| SARS-CoV-2 antibody | SARS-CoV-2 (COVID-19) neutralizing antibody | 0.797 | 0 | 0 |
| SARS-CoV-2 antibody | SARS-CoV-2 (COVID-19) IgG | 0.787 | 1 | 1,259 |
| SARS-CoV-2 antibody | SARS-CoV-2 (COVID-19) Ab | 0.768 | 0 | 0 |
| SARS-CoV-2 antibody | SARS-CoV-2 (COVID-19) IgA | 0.752 | 1 | 270 |
| SARS-CoV-2 antibody | SARS coronavirus IgG | 0.751 | 0 | 0 |
| SARS-CoV-2 antigen | SARS-CoV-2 Ag | 0.864 | 0 | 0 |
| SARS-CoV-2 antigen | SARS-CoV-2 (COVID-19) Ag | 0.818 | 4 | 48,202 |
| SARS-CoV-2 antigen | SARS-CoV+SARS-CoV-2 (COVID-19) Ag | 0.767 | 0 | 0 |
| SARS-CoV-2 IgA antibody | SARS-CoV-2 (COVID-19) IgA | 0.933 | 1 | 270 |
| SARS-CoV-2 IgA antibody | SARS-CoV-2 (COVID-19) IgA+IgM | 0.855 | 0 | 0 |
| SARS-CoV-2 IgA antibody | SARS-CoV-2 (COVID-19) IgG | 0.785 | 1 | 1,259 |
| SARS-CoV-2 IgA antibody | SARS-CoV-2 (COVID-19) IgM | 0.766 | 0 | 0 |
| SARS-CoV-2 IgA antibody | SARS coronavirus IgG | 0.753 | 0 | 0 |
| SARS-CoV-2 IgG antibody | SARS-CoV-2 (COVID-19) IgG | 0.896 | 1 | 1,259 |
| SARS-CoV-2 IgG antibody | SARS coronavirus IgG | 0.859 | 0 | 0 |
| SARS-CoV-2 IgG antibody | SARS-CoV-2 (COVID-19) IgG+IgM | 0.833 | 0 | 0 |
| SARS-CoV-2 IgG antibody | SARS-CoV-2 (COVID-19) IgM | 0.802 | 0 | 0 |
| SARS-CoV-2 IgG antibody | SARS-CoV-2 (COVID-19) IgA | 0.795 | 1 | 270 |
| SARS-CoV-2 IgM antibody | SARS-CoV-2 (COVID-19) IgM | 0.896 | 0 | 0 |
| SARS-CoV-2 IgM antibody | SARS Coronavirus IgM | 0.856 | 0 | 0 |
| SARS-CoV-2 IgM antibody | SARS-CoV-2 (COVID-19) IgG | 0.818 | 1 | 1,259 |
| SARS-CoV-2 IgM antibody | SARS-CoV-2 (COVID-19) IgA+IgM | 0.808 | 0 | 0 |
| SARS-CoV-2 IgM antibody | SARS-CoV-2 (COVID-19) IgG+IgM | 0.804 | 0 | 0 |
| SARS-CoV-2 RNA | SARS-CoV-2 (COVID-19) RNA | 0.945 | 6 | 996,958 |
| SARS-CoV-2 RNA | SARS-CoV-2 (COVID-19) and SARS-related CoV RNA | 0.864 | 0 | 0 |
| SARS-CoV-2 RNA | SARS coronavirus RNA | 0.853 | 0 | 0 |
| SARS-CoV-2 RNA | SARS-related coronavirus RNA | 0.838 | 0 | 0 |
| SARS-CoV-2 RNA | SARS-CoV-2 (COVID-19) RNA panel | 0.826 | 0 | 0 |
| SARS-CoV-2 spike protein antibody | SARS coronavirus 2 spike protein Ab.IgG | 0.804 | 0 | 0 |
| SARS-CoV-2 spike protein antibody | SARS-CoV-2 (COVID-19) spike protein receptor binding domain (RBD) neutralizing antibody | 0.781 | 0 | 0 |
| SARS-CoV-2 spike protein antibody | SARS-CoV-2 (COVID-19) spike protein | 0.778 | 0 | 0 |
| SARS-CoV-2 spike protein antibody | SARS-CoV-2 (COVID-19) neutralizing antibody | 0.768 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Catalytic Concentration | Catalytic Concentration | 1.000 | 228 | 10,802,985 |
| Catalytic Concentration | Relative catalytic concentration | 0.848 | 9 | 39,650 |
| Mass | Mass | 1.000 | 5 | 10,152 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Number Concentration | Number Concentration | 1.000 | 507 | 49,434,956 |
| Number Fraction | Number Fraction | 1.000 | 482 | 8,246,054 |
| Number Fraction | Decimal number fraction | 0.787 | 1 | 6,152 |
| Number Fraction | Time Fraction | 0.765 | 0 | 0 |
| Presence or Identity | Presence or Identity | 1.000 | 79 | 1,946,967 |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |
| Volume | Volume | 1.000 | 20 | 17,488 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Immunoassay | Immunoassay | 1.000 | 164 | 322,567 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with probe detection | 1.000 | 115 | 2,413,483 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with non-probe detection | 0.864 | 1 | 7,786 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5a | 0.770 | 0 | 0 |
| Nucleic acid amplification with probe detection | Probe with amplification | 0.759 | 2 | 14,699 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5b | 0.754 | 0 | 0 |
| Sequencing | Sequencing | 1.000 | 3 | 15,218 |
| Test strip | Test strip | 1.000 | 79 | 4,294,769 |
| Test strip | Test strip manual | 0.843 | 0 | 0 |
| Test strip | Test strip automated | 0.836 | 3 | 687,408 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1564 | -c19agvt |  | 139 | 100 |  |  |  |  | SARS-CoV-2 antigen | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1565 | -covidjt |  | 396 | 100 |  |  |  |  | SARS-CoV-2 | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1566 | -cv19ag | % | 13 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Number Fraction |  |  | Qn | Point in time (spot) | FALSE |
| 1567 | -cv19ag | e12/l | 7 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Number Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1568 | -cv19ag | e9/l | 19 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Number Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1569 | -cv19ag | fl | 8 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Volume |  |  | Qn | Point in time (spot) | FALSE |
| 1570 | -cv19ag | g/l | 15 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Mass Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1571 | -cv19ag | mmol/l | 25 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1572 | -cv19ag | pg | 8 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Mass |  |  | Qn | Point in time (spot) | FALSE |
| 1573 | -cv19ag | u/l | 5 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Catalytic Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1574 | -cv19ag | ug/l | 6 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Mass Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1575 | -cv19ag | umol/l | 6 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1576 | -cv19ag |  | 11991 | 99.09 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 antigen | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1577 | -cv19ag0 |  | 3845 | 100 |  | Panbio COVID-19 Ag Rapid Test, Abbott Rapid Diagnostics |  |  | SARS-CoV-2 antigen | Presence or Threshold | Test strip |  | Ord | Point in time (spot) | FALSE |
| 1578 | -cv19ag1 |  | 504 | 100 |  | Flowflex SARS-CoV-2 Antigen rapid test, ACON Laboratories, Inc |  |  | SARS-CoV-2 antigen | Presence or Threshold | Test strip |  | Ord | Point in time (spot) | FALSE |
| 1579 | -cv19ag2 |  | 204 | 100 |  | mariPOC SARS-CoV-2, ArcDia International Ltd |  |  | SARS-CoV-2 antigen | Presence or Threshold | Immunoassay |  | Ord | Point in time (spot) | FALSE |
| 1580 | -cv19ag3 |  | 270 | 100 |  | mariPOC Quick Flu+ , ArcDia International Ltd |  |  | SARS-CoV-2 antigen | Presence or Threshold | Immunoassay |  | Ord | Point in time (spot) | FALSE |
| 1581 | -cv19ag4 |  | 20852 | 100 |  | STANDARD Q COVID-19 Ag, SD BIONSENSOR Inc |  |  | SARS-CoV-2 antigen | Presence or Threshold | Test strip |  | Ord | Point in time (spot) | FALSE |
| 1582 | -cv19ag5 |  | 15481 | 100 |  | SARS-CoV-2 Antigen Rapid Test, Roche (SD BIOSENSOR) |  |  | SARS-CoV-2 antigen | Presence or Threshold | Test strip |  | Ord | Point in time (spot) | FALSE |
| 1583 | -cv19agj |  | 1370 | 100 |  |  |  |  | SARS-CoV-2 antigen | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1584 | -cv19agl |  | 391 | 100 |  |  |  |  | SARS-CoV-2 antigen | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1585 | -cv19nho |  | 891531 | 100 |  | -COVID-19-koronavirustauti, nukleiinihappo (kval) |  |  | SARS-CoV-2 RNA | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1586 | -cv19pika |  | 8349 | 99.95 |  |  |  |  | SARS-CoV-2 antigen | Presence or Threshold | Test strip |  | Ord | Point in time (spot) | FALSE |
| 1587 | -cv19vt |  | 1271 | 100 |  |  |  |  | SARS-CoV-2 | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1588 | b-cv19ab-o |  | 325 | 100 |  |  | Blood | Qualitative test (also semi-quantitative) | SARS-CoV-2 antibody | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1589 | b-cv19abg |  | 232 | 100 |  | B -COVID-19 -koronavirustauti, IgG-vasta-aineet | Blood |  | SARS-CoV-2 IgG antibody | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1590 | b-cv19abm |  | 233 | 100 |  | B -COVID-19 -koronavirustauti, IgM-vasta-aineet | Blood |  | SARS-CoV-2 IgM antibody | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 1591 | cldinho |  | 111 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 1592 | covid-19aghoi |  | 476 | 100 |  |  |  |  | SARS-CoV-2 antigen | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1593 | cv19ag |  | 985 | 100 |  |  |  |  | SARS-CoV-2 antigen | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1594 | cv19infrs |  | 7932 | 100 |  |  |  |  | SARS-CoV-2 & Influenza virus A & Influenza virus B & Respiratory syncytial virus RNA |  |  |  |  |  | TRUE |
| 1595 | cv19nho |  | 71412 | 100 |  |  |  |  | SARS-CoV-2 RNA | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1596 | cv19nhopth |  | 159 | 100 |  |  |  |  | SARS-CoV-2 RNA | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1597 | cv19sekv |  | 120 | 100 |  |  |  |  | SARS-CoV-2 RNA | Presence or Identity | Sequencing |  | Nom | Point in time (spot) | FALSE |
| 1598 | oma-covid-o |  | 1391 | 100 |  |  |  | Qualitative test (also semi-quantitative) | SARS-CoV-2 antigen | Presence or Threshold | Test strip |  | Ord | Point in time (spot) | FALSE |
| 1599 | p-c1qabg | u/ml | 88 | 0 |  | P-Komplementti C1q, IgG-vasta-aineet | Plasma |  | Complement C1q antibody.IgG | Arbitrary Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1600 | p-c1qabg |  | 195 | 95.38 |  | P-Komplementti C1q, IgG-vasta-aineet | Plasma |  | Complement C1q antibody.IgG | Presence or Threshold |  | Plasma | Ord | Point in time (spot) | FALSE |
| 1601 | pika-covid-19ag |  | 290 | 100 |  |  |  |  | SARS-CoV-2 antigen | Presence or Threshold | Test strip |  | Ord | Point in time (spot) | FALSE |
| 1602 | s-cv19ab | au/ml | 36 | 100 |  | S -COVID-19 -koronavirustauti, vasta-aineet | Serum |  | SARS-CoV-2 antibody | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1603 | s-cv19ab |  | 3692 | 100 |  | S -COVID-19 -koronavirustauti, vasta-aineet | Serum |  | SARS-CoV-2 antibody | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1604 | s-cv19aba |  | 270 | 100 |  | S -COVID-19 -koronavirustauti, IgA-vasta-aineet | Serum |  | SARS-CoV-2 IgA antibody | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1605 | s-cv19abg |  | 1259 | 100 |  | S -COVID-19 -koronavirustauti, IgG-vasta-aineet | Serum |  | SARS-CoV-2 IgG antibody | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1606 | s-cv19abm |  | 101 | 100 |  | S -COVID-19 -koronavirustauti, IgM- vasta-aineet | Serum |  | SARS-CoV-2 IgM antibody | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1607 | s-cv19abp |  | 153 | 100 |  |  | Serum |  | SARS-CoV-2 antibody | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1608 | s-cv19sab | au/ml | 149 | 0 | [1.48, 3.94, 139.34, 691.66, 1561.95, 3317.2, 5543.63, 12999.61, 20746] | S -COVID-19-koronavirustauti, piikkiproteiini, vasta-aineet | Serum |  | SARS-CoV-2 spike protein antibody | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1609 | s-cv19sab | u/ml | 15 | 0 |  | S -COVID-19-koronavirustauti, piikkiproteiini, vasta-aineet | Serum |  | SARS-CoV-2 spike protein antibody | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1610 | s-cv19sab |  | 106 | 100 |  | S -COVID-19-koronavirustauti, piikkiproteiini, vasta-aineet | Serum |  | SARS-CoV-2 spike protein antibody | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |

