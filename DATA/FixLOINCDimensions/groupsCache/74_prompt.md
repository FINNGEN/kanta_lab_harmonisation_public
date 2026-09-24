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
Here is group 74.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Aspergillus sp | Aspergillus sp | 1.000 | 0 | 0 |
| Aspergillus sp | Aspergillus sp Ag | 0.869 | 0 | 0 |
| Aspergillus sp | Aspergillus sp identified | 0.840 | 0 | 0 |
| Aspergillus sp | Aspergillus sp Ab | 0.839 | 1 | 1,942 |
| Aspergillus sp | Aspergillus fumigatus | 0.796 | 0 | 0 |
| Bacteria | Bacteria | 1.000 | 32 | 3,027,518 |
| Bordetella parapertussis | Bordetella parapertussis | 1.000 | 0 | 0 |
| Bordetella parapertussis | Bordetella parapertussis Ab | 0.806 | 0 | 0 |
| Bordetella parapertussis | Bordetella parapertussis Ag | 0.793 | 0 | 0 |
| Bordetella parapertussis | Bordetella parapertussis IgG | 0.758 | 0 | 0 |
| Bordetella parapertussis | Bordetella parapertussis DNA | 0.758 | 1 | 3,745 |
| Bordetella pertussis | Bordetella pertussis | 1.000 | 0 | 0 |
| Bordetella pertussis+parapertussis | Bordetella pertussis+parapertussis | 1.000 | 0 | 0 |
| Bordetella pertussis+parapertussis | Bordetella pertussis+parapertussis+bronchiseptica | 0.923 | 0 | 0 |
| Bordetella pertussis+parapertussis | Bordetella parapertussis | 0.794 | 0 | 0 |
| Bordetella pertussis+parapertussis | Bordetella pertussis+Bordetella parapertussis.filamentous hemagglutinin IgG | 0.780 | 0 | 0 |
| Bordetella pertussis+parapertussis | Bordetella parapertussis Ag | 0.765 | 0 | 0 |
| Borrelia sp | Borrelia sp | 1.000 | 0 | 0 |
| Borrelia sp | Borreliella sp | 0.914 | 0 | 0 |
| Borrelia sp | Borrelia sp Ab | 0.866 | 0 | 0 |
| Borrelia sp | Borrelia sp Ag | 0.847 | 0 | 0 |
| Borrelia sp | Borrelia sp identified | 0.845 | 0 | 0 |
| Coronavirus 229E | Human coronavirus 229E | 0.931 | 0 | 0 |
| Coronavirus 229E | Human coronavirus 229E+NL63 | 0.820 | 0 | 0 |
| Coronavirus 229E | Human coronavirus 229E RNA | 0.819 | 1 | 5,974 |
| Coronavirus 229E | Human coronavirus 229E Ag | 0.818 | 0 | 0 |
| Coronavirus 229E | Human coronavirus 229E Ab | 0.799 | 0 | 0 |
| Coronavirus HKU1 | Human coronavirus HKU1 | 0.900 | 0 | 0 |
| Coronavirus HKU1 | Human coronavirus HKU1 RNA | 0.798 | 0 | 0 |
| Coronavirus HKU1 | Human coronavirus HKU1+OC43 | 0.757 | 0 | 0 |
| Coronavirus NL63 | Human coronavirus NL63 | 0.895 | 0 | 0 |
| Coronavirus NL63 | Human coronavirus NL63 RNA | 0.813 | 1 | 5,974 |
| Coronavirus NL63 | Human coronavirus NL63 IgG | 0.769 | 0 | 0 |
| Coronavirus NL63 | Human coronavirus NL63 Ab | 0.762 | 0 | 0 |
| Coronavirus OC43 | Human coronavirus OC43 | 0.922 | 0 | 0 |
| Coronavirus OC43 | Human coronavirus OC43 Ab | 0.835 | 0 | 0 |
| Coronavirus OC43 | Human coronavirus OC43 Ag | 0.808 | 0 | 0 |
| Coronavirus OC43 | Human coronavirus OC43 RNA | 0.802 | 1 | 5,976 |
| Coronavirus OC43 | Human coronavirus OC43 IgG | 0.792 | 0 | 0 |
| Human bocavirus | Human bocavirus | 1.000 | 0 | 0 |
| Parvovirus B19 | Parvovirus B19 | 1.000 | 0 | 0 |
| Parvovirus B19 | Parvovirus B19 Ab | 0.832 | 0 | 0 |
| Parvovirus B19 | Parvovirus B19 IgM | 0.830 | 1 | 2,963 |
| Parvovirus B19 | Parvovirus B19 DNA | 0.824 | 1 | 207 |
| Parvovirus B19 | Parvovirus B19 IgG | 0.814 | 3 | 2,615 |
| Salmonella sp | Salmonella sp | 1.000 | 3 | 41,500 |
| Salmonella sp | Salmonella sp serovar | 0.879 | 0 | 0 |
| Salmonella sp | Salmonella spp | 0.865 | 0 | 0 |
| Salmonella sp | Salmonella sp serotype | 0.860 | 0 | 0 |
| Salmonella sp | Salmonella sp Ag | 0.850 | 0 | 0 |
| Sapovirus | Sapovirus | 1.000 | 0 | 0 |
| Sapovirus | Sapovirus genogroup V | 0.809 | 0 | 0 |
| Sapovirus | Sapovirus RNA | 0.800 | 0 | 0 |

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

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Cerebral spinal fluid | Cerebral spinal fluid | 1.000 | 150 | 183,922 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Stool | Stool | 1.000 | 42 | 537,967 |
| Stool | Stool.wet | 0.760 | 0 | 0 |
| Stool | Stool^Patient.gastrointestinal | 0.756 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1134 | -aspenho |  | 680 | 100 |  | -Aspergillus, nukleiinihappo (kval) |  |  | Aspergillus sp | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1135 | -baktnho |  | 14771 | 100 |  | -Bakteeri, nukleiinihappo (kval) |  |  | Bacteria | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1136 | -bocanho |  | 1008 | 100 |  |  |  |  | Human bocavirus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1137 | -bokanho |  | 13005 | 100 |  | -Bokavirus, nukleiinihappo (kval) |  |  | Human bocavirus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1138 | -bopanho |  | 1739 | 100 |  |  |  |  |  | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1139 | -bopenho |  | 12052 | 100 |  | -Bordetella pertussis, nukleiinihappo (kval) |  |  | Bordetella pertussis | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1140 | -bopenho. |  | 1314 | 100 |  |  |  |  | Bordetella pertussis | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1141 | -boppnho |  | 3753 | 100 |  |  |  |  | Bordetella pertussis+parapertussis | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1142 | -borrnho |  | 1762 | 100 |  | -Borrelia, nukleiinihappo (kval) |  |  | Borrelia sp | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1143 | -bparnho |  | 314 | 100 |  |  |  |  | Bordetella parapertussis | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1144 | -rbaktnho |  | 4646 | 100 |  |  |  |  |  |  |  |  |  |  | TRUE |
| 1145 | baktnho |  | 328 | 100 |  |  |  |  | Bacteria | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1146 | bokanho |  | 222 | 100 |  |  |  |  | Human bocavirus | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1147 | bopenho |  | 608 | 100 |  |  |  |  | Bordetella pertussis | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1148 | bparanho |  | 1650 | 100 |  |  |  |  | Bordetella parapertussis | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1149 | f-baktnho |  | 17469 | 100 |  |  | Feces |  | Bacteria | Presence or Threshold | Nucleic acid amplification with probe detection | Stool | Ord | Point in time (spot) | FALSE |
| 1150 | f-paranho |  | 14240 | 99.99 |  | F -Parasiitit, nukleiinihappo (kval) | Feces |  |  |  |  | Stool |  |  | TRUE |
| 1151 | f-salmnho |  | 2354 | 100 |  | F -Salmonella, nukleiinihappo (kval) | Feces |  | Salmonella sp | Presence or Threshold | Nucleic acid amplification with probe detection | Stool | Ord | Point in time (spot) | FALSE |
| 1152 | f-saponho |  | 4057 | 100 |  | F -Sapovirus, nukleiinihappo (kval) | Feces |  | Sapovirus | Presence or Threshold | Nucleic acid amplification with probe detection | Stool | Ord | Point in time (spot) | FALSE |
| 1153 | kv229enho |  | 5976 | 100 |  |  |  |  | Coronavirus 229E | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1154 | kvhku1nho |  | 537 | 100 |  |  |  |  | Coronavirus HKU1 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1155 | kvnl63nho |  | 5975 | 100 |  |  |  |  | Coronavirus NL63 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1156 | kvoc43nho |  | 5977 | 100 |  |  |  |  | Coronavirus OC43 | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |
| 1157 | li-baktnho |  | 268 | 100 |  | Li-Bakteeri, nukleiinihappo (kval) | Cerebrospinal fluid |  | Bacteria | Presence or Threshold | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 1158 | resbaktnho |  | 770 | 100 |  |  |  |  |  |  |  |  |  |  | TRUE |
| 1159 | s-parvnho |  | 208 | 99.04 |  | S -Parvovirus, nukleiinihappo (kval) | Serum |  | Parvovirus B19 | Presence or Threshold | Nucleic acid amplification with probe detection | Serum | Ord | Point in time (spot) | FALSE |
| 1160 | salmnho |  | 8183 | 100 |  |  |  |  | Salmonella sp | Presence or Threshold | Nucleic acid amplification with probe detection |  | Ord | Point in time (spot) | FALSE |

