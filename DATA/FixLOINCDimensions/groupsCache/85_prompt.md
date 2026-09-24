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
Here is group 85.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Acetone | Acetone | 1.000 | 0 | 0 |
| Bacteria | Bacteria | 1.000 | 32 | 3,027,518 |
| Candida | Candida sp | 0.793 | 1 | 9,451 |
| Candida | Candida albicans | 0.775 | 0 | 0 |
| Cladosporium herbarum | Cladosporium herbarum | 1.000 | 0 | 0 |
| Cladosporium herbarum | Cladosporium sp | 0.835 | 0 | 0 |
| Cladosporium herbarum | Cladosporium herbarum Ab | 0.825 | 0 | 0 |
| Cladosporium herbarum | Cladosporium cladosporioides | 0.804 | 0 | 0 |
| Cladosporium herbarum | Cladosporium sphaerospermum | 0.799 | 0 | 0 |
| Cladosporium herbarum Ab.IgE | Cladosporium herbarum IgE | 0.949 | 8 | 7,686 |
| Cladosporium herbarum Ab.IgE | Cladosporium herbarum Ab.IgE/IgE.total | 0.938 | 0 | 0 |
| Cladosporium herbarum Ab.IgE | Cladosporium herbarum Ab.IgE.RAST class | 0.922 | 0 | 0 |
| Cladosporium herbarum Ab.IgE | Cladosporium herbarum IgG | 0.895 | 0 | 0 |
| Cladosporium herbarum Ab.IgE | Cladosporium cladosporioides IgE | 0.894 | 0 | 0 |
| Cobalt | Cobalt | 1.000 | 6 | 5,167 |
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
| Gross pathology | Gross morphology | 0.821 | 0 | 0 |
| Human papillomavirus | Human papilloma virus | 0.892 | 1 | 14,516 |
| Norovirus genogroup I | Norovirus genogroup I | 1.000 | 0 | 0 |
| Norovirus genogroup I | Norovirus genogroup I+II | 0.814 | 0 | 0 |
| Norovirus genogroup I | Norovirus genogroup I RNA | 0.812 | 0 | 0 |
| Norovirus genogroup I | Norovirus genogroup I and II | 0.810 | 0 | 0 |
| Norovirus genogroup I | Norovirus genogroup II | 0.804 | 0 | 0 |
| Norovirus genogroup II | Norovirus genogroup II | 1.000 | 0 | 0 |
| Norovirus genogroup II | Norovirus genogroup I and II | 0.915 | 0 | 0 |
| Norovirus genogroup II | Norovirus genogroup I+II | 0.906 | 0 | 0 |
| Norovirus genogroup II | Norovirus genogroup II RNA | 0.905 | 0 | 0 |
| Norovirus genogroup II | Norovirus genogroup I | 0.893 | 0 | 0 |
| Urate | Urate | 1.000 | 26 | 314,859 |
| Urate | Sodium urate | 0.793 | 0 | 0 |
| Urate | Urate/Total | 0.770 | 0 | 0 |
| Urate | Urate dihydrate | 0.767 | 0 | 0 |
| Valproate | Valproate | 1.000 | 4 | 37,442 |
| Valproate | Valproate^peak | 0.776 | 0 | 0 |
| Valproate | Valproate.bound | 0.770 | 0 | 0 |
| Valproate | Valproate Free | 0.764 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Length | Length | 1.000 | 3 | 17,755 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Presence or Identity | Presence or Identity | 1.000 | 79 | 1,946,967 |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Dissection | (none scored >= 0.75) |  |  |  |
| Immunoassay | Immunoassay | 1.000 | 164 | 322,567 |
| Microscopy | Microscopy | 1.000 | 0 | 0 |
| Microscopy | Light microscopy | 0.815 | 13 | 53,782 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with probe detection | 1.000 | 115 | 2,413,483 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with non-probe detection | 0.864 | 1 | 7,786 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5a | 0.770 | 0 | 0 |
| Nucleic acid amplification with probe detection | Probe with amplification | 0.759 | 2 | 14,699 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5b | 0.754 | 0 | 0 |
| Organism specific culture | Organism specific culture | 1.000 | 33 | 505,882 |
| Skin test | (none scored >= 0.75) |  |  |  |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Cervical specimen | (none scored >= 0.75) |  |  |  |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Respiratory specimen | Respiratory specimen | 1.000 | 0 | 0 |
| Respiratory specimen | Respiratory system specimen | 0.919 | 5 | 1,010,529 |
| Respiratory specimen | Lower respiratory specimen | 0.910 | 0 | 0 |
| Respiratory specimen | Upper respiratory specimen | 0.879 | 4 | 48,202 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Serum or Plasma | Serum or Plasma | 1.000 | 2,776 | 78,327,842 |
| Serum or Plasma | Serum or Plasma or Urine | 0.832 | 0 | 0 |
| Serum or Plasma | Serum and Plasma | 0.819 | 0 | 0 |
| Serum or Plasma | Serum, Plasma or Blood | 0.816 | 84 | 6,240,111 |
| Serum or Plasma | Serum or Plasma and CSF | 0.792 | 4 | 1,187 |
| Skin | Skin | 1.000 | 3 | 121,968 |
| Stool | Stool | 1.000 | 42 | 537,967 |
| Stool | Stool.wet | 0.760 | 0 | 0 |
| Stool | Stool^Patient.gastrointestinal | 0.756 | 0 | 0 |
| Tissue | Tissue | 1.000 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1241 | -aerobivi |  | 314 | 100 |  |  |  |  | Bacteria | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 1242 | -anaerobi |  | 320 | 100 |  |  |  |  | Bacteria | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 1243 | -omactgc |  | 591 | 100 |  |  |  |  |  |  |  |  | Nar |  | FALSE |
| 1244 | annosvoim |  | 182 | 65.93 |  |  |  |  |  |  |  |  | Nar |  | FALSE |
| 1245 | b-koboltti | ug/l | 157 | 0 | [0.5, 0.72, 0.96, 1.18, 1.68, 2.2, 3.97, 6.08, 10.46] |  | Blood |  | Cobalt | Mass Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1246 | cand-odl. |  | 542 | 89.67 |  |  |  |  | Candida | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 1247 | cand.nativ |  | 286 | 100 |  |  |  |  | Candida | Presence or Identity | Microscopy |  | Nom | Point in time (spot) | FALSE |
| 1248 | cladosp.he | mm | 11 | 0 |  |  |  |  | Cladosporium herbarum | Length | Skin test | Skin | Qn | Point in time (spot) | FALSE |
| 1249 | cladosp.he | u/ml | 69 | 0 | [0, 0.01, 0.01, 0.04, 0.13, 0.41, 0.5, 0.87, 4.4] |  |  |  | Cladosporium herbarum Ab.IgE | Arbitrary Concentration | Immunoassay | Serum or Plasma | Qn | Point in time (spot) | FALSE |
| 1250 | cladosp.he |  | 680 | 93.82 |  |  |  |  | Cladosporium herbarum Ab.IgE | Presence or Threshold | Immunoassay | Serum or Plasma | Ord | Point in time (spot) | FALSE |
| 1251 | corona229e |  | 619 | 100 |  |  |  |  | Coronavirus 229E | Presence or Identity | Nucleic acid amplification with probe detection | Respiratory specimen | Nom | Point in time (spot) | FALSE |
| 1252 | coronahku1 |  | 619 | 100 |  |  |  |  | Coronavirus HKU1 | Presence or Identity | Nucleic acid amplification with probe detection | Respiratory specimen | Nom | Point in time (spot) | FALSE |
| 1253 | coronanl63 |  | 619 | 100 |  |  |  |  | Coronavirus NL63 | Presence or Identity | Nucleic acid amplification with probe detection | Respiratory specimen | Nom | Point in time (spot) | FALSE |
| 1254 | coronaoc43 |  | 619 | 100 |  |  |  |  | Coronavirus OC43 | Presence or Identity | Nucleic acid amplification with probe detection | Respiratory specimen | Nom | Point in time (spot) | FALSE |
| 1255 | f-norogi |  | 261 | 100 |  |  | Feces |  | Norovirus genogroup I | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 1256 | f-norogii |  | 261 | 100 |  |  | Feces |  | Norovirus genogroup II | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 1257 | f-projekti |  | 469 | 100 |  |  | Feces |  |  |  |  | Stool | Nar |  | FALSE |
| 1258 | hpvpapctgc |  | 116 | 100 |  |  |  |  | Human papillomavirus | Presence or Identity | Nucleic acid amplification with probe detection | Cervical specimen | Nom | Point in time (spot) | FALSE |
| 1259 | hpvrefctgc |  | 135 | 100 |  |  |  |  | Human papillomavirus | Presence or Identity | Nucleic acid amplification with probe detection | Cervical specimen | Nom | Point in time (spot) | FALSE |
| 1260 | norogi |  | 139 | 100 |  |  |  |  | Norovirus genogroup I | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 1261 | norogii |  | 139 | 100 |  |  |  |  | Norovirus genogroup II | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 1262 | p-asetoni | mmol/l | 171 | 0 | [0, 0, 0, 0, 0, 0, 0.99, 1.7, 3.4] |  | Plasma |  | Acetone | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1263 | p-asetoni |  | 305 | 100 |  |  | Plasma |  | Acetone | Presence or Threshold |  | Plasma | Ord | Point in time (spot) | FALSE |
| 1264 | p-uraatti | umol/l | 6902 | 0 | [234.14, 271.61, 301.37, 327.94, 355.71, 383.49, 416.66, 458.38, 518.94] |  | Plasma |  | Urate | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1265 | p-uraatti |  | 32 | 87.5 |  |  | Plasma |  | Urate | Presence or Threshold |  | Plasma | Ord | Point in time (spot) | FALSE |
| 1266 | projekti1 |  | 160 | 100 |  |  |  |  |  |  |  |  | Nar |  | FALSE |
| 1267 | s-asetoni | mmol/l | 42 | 0 |  | S -Asetoni | Serum |  | Acetone | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1268 | s-asetoni |  | 414 | 100 |  | S -Asetoni | Serum |  | Acetone | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1269 | s-uraatti | umol/l | 621 | 0 | [231.75, 257.74, 279.08, 298.35, 317.34, 343.64, 366.52, 401.97, 449.54] |  | Serum |  | Urate | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1270 | s-uraatti |  | 38 | 100 |  |  | Serum |  | Urate | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1271 | s-valproaatti | umol/l | 431 | 0 | [243.85, 308.03, 356.19, 396.72, 425.61, 467.25, 503.69, 550.21, 628.49] |  | Serum |  | Valproate | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1272 | s-valproaatti |  | 16 | 87.5 |  |  | Serum |  | Valproate |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 1273 | ts-abortti |  | 315 | 100 |  | Ts-Aborttikudoksen dissektiotutkimus | Tissue |  | Gross pathology | Finding | Dissection | Tissue | Nar | Point in time (spot) | FALSE |
| 1274 | u-omactgc |  | 480 | 100 |  |  | Urine |  |  |  |  |  |  |  | TRUE |
| 1275 | uraatti | umol/l | 3560 | 0 | [230.56, 267.35, 298.53, 325.87, 354.19, 383.04, 414.66, 454.9, 512.27] |  |  |  | Urate | Substance Concentration |  | Serum or Plasma | Qn | Point in time (spot) | FALSE |
| 1276 | uraatti |  | 19 | 100 |  |  |  |  | Urate | Presence or Threshold |  | Serum or Plasma | Ord | Point in time (spot) | FALSE |

