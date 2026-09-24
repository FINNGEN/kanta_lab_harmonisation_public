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
Here is group 106.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Bacteria | Bacteria | 1.000 | 32 | 3,027,518 |
| Bacteria identified | Bacteria identified | 1.000 | 0 | 0 |
| Bacteria identified | Bacteria identified^^^8 | 0.840 | 0 | 0 |
| Bacteria identified | Bacteria identified^^^3 | 0.838 | 0 | 0 |
| Bacteria identified | Bacteria identified^^^7 | 0.836 | 0 | 0 |
| Bacteria identified | Bacteria identified^^^5 | 0.832 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Number Concentration | Number Concentration | 1.000 | 507 | 49,434,956 |
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
| Automated count | Automated count | 1.000 | 103 | 11,606,924 |
| Culture | Culture | 1.000 | 20 | 1,273,557 |
| Gram stain | Gram stain | 1.000 | 2 | 32,302 |
| Microscopy | Microscopy | 1.000 | 0 | 0 |
| Microscopy | Light microscopy | 0.815 | 13 | 53,782 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with probe detection | 1.000 | 115 | 2,413,483 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with non-probe detection | 0.864 | 1 | 7,786 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5a | 0.770 | 0 | 0 |
| Nucleic acid amplification with probe detection | Probe with amplification | 0.759 | 2 | 14,699 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5b | 0.754 | 0 | 0 |
| Organism specific culture | Organism specific culture | 1.000 | 33 | 505,882 |
| Test strip | Test strip | 1.000 | 79 | 4,294,769 |
| Test strip | Test strip manual | 0.843 | 0 | 0 |
| Test strip | Test strip automated | 0.836 | 3 | 687,408 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Aspirate | Aspirate | 1.000 | 1 | 22 |
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Bone | Bone | 1.000 | 1 | 312 |
| Bone | Bones | 0.751 | 0 | 0 |
| Bronchoalveolar lavage fluid | Bronchoalveolar lavage | 0.891 | 0 | 0 |
| Bronchoalveolar lavage fluid | Bronchoalveolar aspirate | 0.795 | 0 | 0 |
| Catheter tip | Catheter tip | 1.000 | 0 | 0 |
| Cerebral spinal fluid | Cerebral spinal fluid | 1.000 | 150 | 183,922 |
| Dialysis fluid.peritoneal | Dialysis fluid peritoneal | 0.922 | 21 | 8,603 |
| Dialysis fluid.peritoneal | Dialysis fluid | 0.864 | 0 | 0 |
| Dialysis fluid.peritoneal | Dialysis fluid peritoneal + Serum or Plasma | 0.769 | 0 | 0 |
| Gingival crevicular fluid | (none scored >= 0.75) |  |  |  |
| Peritoneal fluid | Peritoneal fluid | 1.000 | 41 | 16,617 |
| Peritoneal fluid | Spun Peritoneal fluid | 0.755 | 0 | 0 |
| Peritoneal fluid | Peritoneal fluid and serum or plasma | 0.751 | 0 | 0 |
| Pleural fluid | Pleural fluid | 1.000 | 95 | 67,704 |
| Pleural fluid | Pericardial fluid | 0.759 | 0 | 0 |
| Pus | Pus | 1.000 | 0 | 0 |
| Sputum | Sputum | 1.000 | 2 | 29,931 |
| Sputum | Sputum or Bronchial | 0.774 | 0 | 0 |
| Stool | Stool | 1.000 | 42 | 537,967 |
| Stool | Stool.wet | 0.760 | 0 | 0 |
| Stool | Stool^Patient.gastrointestinal | 0.756 | 0 | 0 |
| Synovial fluid | Synovial fluid | 1.000 | 82 | 91,594 |
| Throat | Throat | 1.000 | 6 | 254,143 |
| Throat | Throat and Neck | 0.784 | 0 | 0 |
| Urine | Urine | 1.000 | 586 | 16,080,701 |
| Vaginal fluid | Genital fluid | 0.783 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1397 | -bakt-he |  | 111 | 100 |  |  |  | Antibiotic sensitivity |  |  |  |  |  |  | TRUE |
| 1398 | -bakt-lm |  | 545 | 100 |  |  |  | Species identification | Bacteria identified | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 1399 | -baktvi |  | 1515 | 100 |  | -Bakteeri, viljely |  |  | Bacteria | Presence or Identity | Culture |  | Nom | Point in time (spot) | FALSE |
| 1400 | -baktvr |  | 22025 | 100 |  | -Bakteeri, värjäys |  |  | Bacteria | Finding | Gram stain |  | Nar | Point in time (spot) | FALSE |
| 1401 | af-baktvi |  | 262 | 100 |  |  | Aspiration fluid |  | Bacteria | Presence or Identity | Culture | Aspirate | Nom | Point in time (spot) | FALSE |
| 1402 | as-baktvr |  | 252 | 100 |  |  | Ascitic fluid |  | Bacteria | Finding | Gram stain | Peritoneal fluid | Nar | Point in time (spot) | FALSE |
| 1403 | b-bakt-vi |  | 1757 | 100 |  |  | Blood | Culture | Bacteria | Presence or Identity | Culture | Blood | Nom | Point in time (spot) | FALSE |
| 1404 | b-baktjvi |  | 28084 | 100 |  | B -Bakteeri, jatkoviljely | Blood |  | Bacteria | Presence or Identity | Culture | Blood | Nom | Point in time (spot) | FALSE |
| 1405 | b-baktsvi |  | 6514 | 100 |  |  | Blood |  | Bacteria | Presence or Threshold | Culture | Blood | Ord | Point in time (spot) | FALSE |
| 1406 | b-baktvi |  | 506538 | 100 |  | B -Bakteeri, viljely | Blood |  | Bacteria | Presence or Identity | Culture | Blood | Nom | Point in time (spot) | FALSE |
| 1407 | b-baktvi. |  | 2240 | 100 |  |  | Blood |  | Bacteria | Presence or Identity | Culture | Blood | Nom | Point in time (spot) | FALSE |
| 1408 | b-baktvij |  | 1818 | 100 |  |  | Blood |  | Bacteria | Presence or Identity | Culture | Blood | Nom | Point in time (spot) | FALSE |
| 1409 | bakteerit |  | 6114 | 100 |  |  |  |  | Bacteria | Presence or Threshold |  |  | Ord |  | FALSE |
| 1410 | baktlm |  | 897 | 100 |  |  |  |  | Bacteria identified | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 1411 | baktvr |  | 339 | 100 |  |  |  |  | Bacteria | Finding | Gram stain |  | Nar | Point in time (spot) | FALSE |
| 1412 | bl-baktvi |  | 303 | 100 |  |  | Bronchoalveolar lavage |  | Bacteria | Presence or Identity | Culture | Bronchoalveolar lavage fluid | Nom | Point in time (spot) | FALSE |
| 1413 | bo-baktvi |  | 312 | 100 |  |  | Bone |  | Bacteria | Presence or Identity | Culture | Bone | Nom | Point in time (spot) | FALSE |
| 1414 | ca-baktvi |  | 1564 | 100 |  | Ca-Bakteeri, viljely suonikanyylista |  |  | Bacteria | Presence or Identity | Culture | Catheter tip | Nom | Point in time (spot) | FALSE |
| 1415 | d-baktvi |  | 120 | 100 |  |  |  |  | Bacteria | Presence or Identity | Culture |  | Nom | Point in time (spot) | FALSE |
| 1416 | ex-baktvi |  | 14096 | 100 |  | Ex-Bakteeri, viljely | Expectorate (sputum) |  | Bacteria | Presence or Identity | Culture | Sputum | Nom | Point in time (spot) | FALSE |
| 1417 | ex-baktvr |  | 3217 | 100 |  |  | Expectorate (sputum) |  | Bacteria | Finding | Gram stain | Sputum | Nar | Point in time (spot) | FALSE |
| 1418 | f-baktjvi |  | 281 | 100 |  |  | Feces |  | Bacteria | Presence or Identity | Culture | Stool | Nom | Point in time (spot) | FALSE |
| 1419 | f-baktvi1 |  | 32771 | 100 |  | F -Bakteeri, viljely 1 (Salmonella, Shigella, Yersinia, Campylobacter) | Feces |  |  |  |  | Stool |  |  | TRUE |
| 1420 | f-baktvi2 |  | 739 | 100 |  | F -Bakteeri, viljely 2 (Clostridium difficile, Staphylococcus aureus, candida) | Feces |  |  |  |  | Stool |  |  | TRUE |
| 1421 | f-baktvi3 |  | 1380 | 100 |  | F -Bakteeri, viljely 3 (viljely 1 + Bacillus cereus, Clostridium perfringens, Staphylococcus aureus) | Feces |  |  |  |  | Stool |  |  | TRUE |
| 1422 | f-baktvip |  | 17284 | 100 |  |  | Feces |  | Bacteria | Presence or Identity | Culture | Stool | Nom | Point in time (spot) | FALSE |
| 1423 | fl-baktna |  | 154 | 100 |  |  | Vaginal discharge |  | Bacteria | Presence or Threshold | Nucleic acid amplification with probe detection | Vaginal fluid | Ord | Point in time (spot) | FALSE |
| 1424 | fl-baktvr |  | 11637 | 100 |  | Fl-Bakteeri, värjäys | Vaginal discharge |  | Bacteria | Finding | Gram stain | Vaginal fluid | Nar | Point in time (spot) | FALSE |
| 1425 | li-baktvi |  | 7020 | 100 |  | Li-Bakteeri, viljely | Cerebrospinal fluid |  | Bacteria | Presence or Identity | Culture | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 1426 | li-baktvr |  | 3747 | 100 |  | Li-Bakteeri, värjäys | Cerebrospinal fluid |  | Bacteria | Finding | Gram stain | Cerebral spinal fluid | Nar | Point in time (spot) | FALSE |
| 1427 | pd-baktvi |  | 917 | 100 |  | Pd-Bakteeri, viljely peritoneaalidialyysinesteestä | Peritoneal dialysis fluid |  | Bacteria | Presence or Identity | Culture | Dialysis fluid.peritoneal | Nom | Point in time (spot) | FALSE |
| 1428 | pf-baktvr |  | 258 | 100 |  |  | Pleural fluid |  | Bacteria | Finding | Gram stain | Pleural fluid | Nar | Point in time (spot) | FALSE |
| 1429 | pp-baktnh |  | 445 | 100 |  | Pp-Bakteeri, nukleiinihappo (kvant), ientasku | Periodontal pocket |  | Bacteria | Substance Concentration | Nucleic acid amplification with probe detection | Gingival crevicular fluid | Qn | Point in time (spot) | FALSE |
| 1430 | ps-baktvi |  | 3894 | 99.97 |  | Ps-Bakteeri, viljely | Pharyngeal secretion |  | Bacteria | Presence or Identity | Culture | Throat | Nom | Point in time (spot) | FALSE |
| 1431 | pu-baktvi1 |  | 132179 | 100 |  | Pu-Bakteeri, viljely 1 (anaerobi + aerobiviljely, syvämärkä) | Pus |  | Bacteria | Presence or Identity | Culture | Pus | Nom | Point in time (spot) | FALSE |
| 1432 | pu-baktvi2 |  | 97752 | 100 |  | Pu-Bakteeri, viljely 2 (aerobiviljely, pintamärkä) | Pus |  | Bacteria | Presence or Identity | Culture | Pus | Nom | Point in time (spot) | FALSE |
| 1433 | sy-baktvr |  | 1225 | 100 |  |  | Synovial fluid |  | Bacteria | Finding | Gram stain | Synovial fluid | Nar | Point in time (spot) | FALSE |
| 1434 | u-bact |  | 4570 | 19.15 | [1.88, 4.41, 7.11, 12.12, 22.01, 65.08, 182.99, 478.65, 3425.04] |  | Urine |  | Bacteria | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 1435 | u-bakt | e6/l | 12886 | 0 | [0.99, 1.98, 3.85, 6.56, 13.19, 31.1, 95.22, 562.86, 5560.98] |  | Urine |  | Bacteria | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 1436 | u-bakt | estimate | 14084 | 99.66 |  |  | Urine |  | Bacteria | Arbitrary Concentration | Microscopy | Urine | SemiQn | Point in time (spot) | FALSE |
| 1437 | u-bakt | u/field | 11 | 0 |  |  | Urine |  | Bacteria | Arbitrary Concentration | Microscopy | Urine | SemiQn | Point in time (spot) | FALSE |
| 1438 | u-bakt |  | 377251 | 99.78 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Bacteria | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 1439 | u-bakt-vi |  | 14923 | 100 | [10000, 10000, 10000, 10000, 1e+05, 1e+05, 1e+05, 1e+06, 1e+06] |  | Urine | Culture | Bacteria | Number Concentration | Culture | Urine | Qn | Point in time (spot) | FALSE |
| 1440 | u-bakt. | /sunf | 514 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Urine |  | Bacteria | Number Concentration | Microscopy | Urine | Qn | Point in time (spot) | FALSE |
| 1441 | u-bakt. | /sunfält | 40 | 0 |  |  | Urine |  | Bacteria | Number Concentration | Microscopy | Urine | Qn | Point in time (spot) | FALSE |
| 1442 | u-bakt. |  | 1617 | 100 |  |  | Urine |  | Bacteria | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 1443 | u-baktalv |  | 2258 | 99.42 |  | U -Bakteeri, aluslasiviljely | Urine |  | Bacteria | Arbitrary Concentration | Culture | Urine | SemiQn | Point in time (spot) | FALSE |
| 1444 | u-baktb |  | 210 | 4.29 | [1.72, 5.76, 11.77, 19.42, 30.15, 66.2, 213.28, 2129.49, 11056.23] |  | Urine |  | Bacteria | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 1445 | u-baktbv | e6/l | 3962 | 0 | [0.82, 1.8, 3.97, 7.16, 16.23, 44.68, 171.24, 1315.3, 12976.36] |  | Urine |  | Bacteria | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 1446 | u-baktbv |  | 93 | 100 |  |  | Urine |  | Bacteria | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 1447 | u-bakteeri |  | 1711 | 100 |  |  | Urine |  | Bacteria | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 1448 | u-bakteerit | e6/l | 1692 | 0 | [1, 3.34, 6.78, 15.13, 44.47, 159.79, 845.2, 5975.08, 24980.83] |  | Urine |  | Bacteria | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 1449 | u-bakteerit |  | 16840 | 99.96 |  |  | Urine |  | Bacteria | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 1450 | u-baktevi |  | 18799 | 99.99 |  | U -Bakteeri, erikoisviljely | Urine |  | Bacteria | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |
| 1451 | u-baktjvi |  | 390824 | 100 |  | U -Bakteeri, jatkoviljely | Urine |  | Bacteria | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |
| 1452 | u-baktjvi. |  | 11570 | 100 |  |  | Urine |  | Bacteria | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |
| 1453 | u-baktla |  | 4577 | 100 |  |  | Urine |  | Bacteria | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 1454 | u-baktlm |  | 1437 | 100 |  |  | Urine |  | Bacteria identified | Presence or Identity | Organism specific culture | Urine | Nom | Point in time (spot) | FALSE |
| 1455 | u-baktnim |  | 111 | 100 |  |  | Urine |  | Bacteria identified | Presence or Identity | Organism specific culture | Urine | Nom | Point in time (spot) | FALSE |
| 1456 | u-bakts |  | 1045 | 100 |  |  | Urine |  | Bacteria | Presence or Threshold | Microscopy | Urine | Ord | Point in time (spot) | FALSE |
| 1457 | u-baktseu |  | 39886 | 99.99 |  |  | Urine |  | Bacteria | Presence or Threshold | Culture | Urine | Ord | Point in time (spot) | FALSE |
| 1458 | u-baktsjvi |  | 539 | 100 |  |  | Urine |  | Bacteria | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |
| 1459 | u-bakttun |  | 653 | 100 |  |  | Urine |  | Bacteria identified | Presence or Identity | Organism specific culture | Urine | Nom | Point in time (spot) | FALSE |
| 1460 | u-baktv |  | 1154 | 100 |  |  | Urine |  | Bacteria | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |
| 1461 | u-baktvi | e6 | 45 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria | Number Concentration | Culture | Urine | Qn | Point in time (spot) | FALSE |
| 1462 | u-baktvi | e6/l | 60 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria | Number Concentration | Culture | Urine | Qn | Point in time (spot) | FALSE |
| 1463 | u-baktvi | form | 10 | 0 |  | U -Bakteeri, viljely | Urine |  | Bacteria identified | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |
| 1464 | u-baktvi |  | 1324678 | 99.99 | [106.83, 10000, 1e+05, 754545.45, 1e+06, 1e+07, 1e+08, 1e+08, 1e+08] | U -Bakteeri, viljely | Urine |  | Bacteria | Number Concentration | Culture | Urine | OrdQn | Point in time (spot) | FALSE |
| 1465 | u-baktvi/ |  | 562 | 100 |  |  | Urine |  | Bacteria | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |
| 1466 | u-baktvi/oma |  | 629 | 100 |  |  | Urine |  | Bacteria | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |
| 1467 | u-baktvi2 |  | 283 | 100 |  |  | Urine |  | Bacteria | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |
| 1468 | u-baktvtk |  | 1637 | 100 |  |  | Urine |  | Bacteria | Presence or Identity | Culture | Urine | Nom | Point in time (spot) | FALSE |

