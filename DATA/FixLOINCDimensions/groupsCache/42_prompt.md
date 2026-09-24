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
Here is group 42.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Adenosine deaminase | Adenosine deaminase | 1.000 | 8 | 8,599 |
| Adenosine deaminase | Adenosine deaminase binding protein | 0.830 | 0 | 0 |
| Adenosine deaminase | Adenosine monophosphate deaminase | 0.826 | 0 | 0 |
| Adrenocorticotropic hormone | Corticotropin | 0.786 | 2 | 10,007 |
| Angiotensin converting enzyme | Angiotensin converting enzyme | 1.000 | 11 | 43,074 |
| Antithrombin III | Antithrombin | 0.845 | 0 | 0 |
| Antithrombin III | Antithrombin Ag | 0.770 | 0 | 0 |
| C-terminal telopeptide of type I collagen | Collagen crosslinked C-telopeptide | 0.819 | 3 | 1,772 |
| C-terminal telopeptide of type I collagen | Collagen crosslinked N-telopeptide | 0.804 | 2 | 1,030 |
| C-terminal telopeptide of type I collagen | Procollagen type I.N-terminal propeptide | 0.751 | 2 | 3,659 |
| Coagulation factor V | Coagulation factor V | 1.000 | 0 | 0 |
| Coagulation factor V | Coagulation factor Va | 0.909 | 0 | 0 |
| Coagulation factor V | Coagulation factor V activated | 0.866 | 0 | 0 |
| Coagulation factor V | Coagulation factor V Ag | 0.859 | 0 | 0 |
| Coagulation factor V | Coagulation factor V activity | 0.848 | 0 | 0 |
| Coagulation factor X | Coagulation factor X | 1.000 | 0 | 0 |
| Coagulation factor X | Coagulation factor X Ag | 0.802 | 0 | 0 |
| Coagulation factor X | Coagulation factor XI | 0.794 | 0 | 0 |
| Coagulation factor X | Coagulation factor X activity | 0.791 | 0 | 0 |
| Coagulation factor X | Coagulation factor X activated | 0.776 | 0 | 0 |
| Complement factor B | Complement factor B | 1.000 | 3 | 154 |
| Complement factor B | Complement factor Bb | 0.895 | 0 | 0 |
| Complement factor B | Complement factor Ba | 0.812 | 0 | 0 |
| Complement factor B | Complement factor H | 0.800 | 0 | 0 |
| Complement factor B | Complement factor D | 0.761 | 0 | 0 |
| Gamma-glutamyltransferase | Gamma glutamyl transferase | 0.915 | 17 | 1,024,731 |
| Gamma-glutamyltransferase | Gamma glutamyl transferase/Aspartate aminotransferase | 0.808 | 0 | 0 |
| Gamma-glutamyltransferase | Gamma glutamyl transferase.macromolecular | 0.764 | 0 | 0 |
| Iron | Iron | 1.000 | 15 | 207,654 |
| Lactate | Lactate | 1.000 | 59 | 509,384 |
| Lactate | D-Lactate | 0.756 | 0 | 0 |
| Lupus anticoagulant | Lupus anticoagulant | 1.000 | 2 | 12,621 |
| Lupus anticoagulant | Lupus anticoagulant neutralization platelet | 0.795 | 0 | 0 |
| Lupus anticoagulant | Lupus anticoagulant neutralization dilute phospholipid | 0.785 | 0 | 0 |
| Lupus anticoagulant | Lupus anticoagulant aPTT screening panel | 0.784 | 0 | 0 |
| Lupus anticoagulant | Lupus anticoagulant neutralization high phospholipid | 0.767 | 0 | 0 |
| Mycophenolic acid | Mycophenolate | 0.784 | 3 | 1,935 |
| Peak expiratory flow | Peak expiratory flow | 1.000 | 0 | 0 |
| Peak expiratory flow | Peak expiratory flow attempt | 0.843 | 0 | 0 |
| Peak expiratory flow | Personal best peak expiratory gas flow | 0.814 | 0 | 0 |
| Peak expiratory flow | Maximum expiratory pressure | 0.766 | 0 | 0 |
| Potassium | Potassium | 1.000 | 61 | 7,976,034 |
| Prothrombin time | Prothrombin time (PT) | 0.856 | 1 | 1,808 |
| Prothrombin time | Prothrombin | 0.825 | 0 | 0 |
| Prothrombin time | Prothrombin index | 0.765 | 0 | 0 |
| Sodium | Sodium | 1.000 | 63 | 7,836,829 |
| Soluble urokinase plasminogen activator receptor | Soluble urokinase plasminogen activator receptor | 1.000 | 0 | 0 |
| Thyroxine.free | Thyroxine free | 0.904 | 28 | 1,539,345 |
| Thyroxine.free | Thyroxine.free^baseline | 0.878 | 0 | 0 |
| Thyroxine.free | Thyroxine.free.gestational | 0.836 | 0 | 0 |
| Thyroxine.free | Thyroxine and Thyroxine.free panel | 0.799 | 0 | 0 |
| Thyroxine.free | Thyroxine.albumin bound | 0.794 | 0 | 0 |
| Tobramycin | Tobramycin | 1.000 | 3 | 1,365 |
| Tobramycin | Tobramycin^random | 0.814 | 0 | 0 |
| Tobramycin | Tobramycin^trough | 0.775 | 0 | 0 |
| Tobramycin | Tobramycin^peak | 0.773 | 0 | 0 |
| Tobramycin | Tobramycin free | 0.771 | 0 | 0 |
| Transferrin receptor.soluble | Transferrin receptor.soluble | 1.000 | 15 | 285,465 |
| Transferrin receptor.soluble | Transferrin receptor.soluble/log Ferritin index | 0.818 | 0 | 0 |
| Transferrin receptor.soluble | Transferrin | 0.753 | 17 | 191,693 |
| Triiodothyronine.free | Triiodothyronine.free^baseline | 0.869 | 0 | 0 |
| Triiodothyronine.free | Triiodothyronine Free | 0.867 | 15 | 105,869 |
| Triiodothyronine.free | Triiodothyronine.free^3H post XXX challenge | 0.815 | 0 | 0 |
| Triiodothyronine.free | Triiodothyronine.free^pre or post XXX challenge | 0.809 | 0 | 0 |
| Triiodothyronine.free | Triiodothyronine.free^2H post XXX challenge | 0.795 | 0 | 0 |
| Troponin I | Troponin I.cardiac | 0.871 | 25 | 323,924 |
| Troponin I | Troponin T | 0.862 | 0 | 0 |
| Troponin I | Troponin I.cardiac panel | 0.784 | 0 | 0 |
| Troponin I | Troponin T.cardiac | 0.767 | 60 | 599,869 |
| Troponin T | Troponin T | 1.000 | 0 | 0 |
| Troponin T | Troponin T.cardiac | 0.849 | 60 | 599,869 |
| Troponin T | Troponin T.cardiac delta | 0.762 | 0 | 0 |
| Troponin T | Troponin T.cardiac panel | 0.758 | 0 | 0 |
| Troponin T | Troponin I.cardiac | 0.755 | 25 | 323,924 |
| Tumor necrosis factor alpha | Tumor necrosis factor | 0.898 | 0 | 0 |
| Tumor necrosis factor alpha | Tumor necrosis factor.alpha | 0.868 | 3 | 150 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Catalytic Concentration | Catalytic Concentration | 1.000 | 228 | 10,802,985 |
| Catalytic Concentration | Relative catalytic concentration | 0.848 | 9 | 39,650 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |
| Substance Rate | Substance Rate | 1.000 | 41 | 25,881 |
| Substance Rate | Mass or Substance Rate | 0.799 | 2 | 118 |
| Substance Rate | Substance Ratio | 0.794 | 9 | 237,272 |
| Time | (none scored >= 0.75) |  |  |  |
| Volume Rate | Volume Rate | 1.000 | 0 | 0 |
| Volume Rate | Volume Rate Ratio | 0.865 | 0 | 0 |
| Volume Rate | Volume Rate Content | 0.827 | 0 | 0 |
| Volume Rate | Volume Rate/Area | 0.778 | 84 | 6,240,111 |
| Volume Rate | Volume Ratio | 0.774 | 0 | 0 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Coagulation assay | Coagulation assay | 1.000 | 181 | 3,646,966 |
| Immunoassay | Immunoassay | 1.000 | 164 | 322,567 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| ^Patient | ^Patient | 1.000 | 20 | 396,517 |
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Blood arterial | Blood arterial | 1.000 | 102 | 4,209,123 |
| Blood arterial | Blood arterial + Blood venous | 0.791 | 0 | 0 |
| Blood arterial | Plasma arterial | 0.777 | 0 | 0 |
| Blood arterial | Blood cord arterial | 0.761 | 20 | 2,773 |
| Blood venous | Blood venous | 1.000 | 125 | 1,808,160 |
| Blood venous | Venous | 0.798 | 0 | 0 |
| Blood venous | Blood cord venous | 0.772 | 4 | 294 |
| Blood venous | Plasma venous | 0.752 | 0 | 0 |
| Blood venous | Blood central venous | 0.750 | 1 | 38,175 |
| Dialysate | Dialysis fluid | 0.827 | 0 | 0 |
| Dialysate | Dialysis fluid peritoneal | 0.750 | 21 | 8,603 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Pleural fluid | Pleural fluid | 1.000 | 95 | 67,704 |
| Pleural fluid | Pericardial fluid | 0.759 | 0 | 0 |
| Semen | Semen | 1.000 | 3 | 12,470 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Urine | Urine | 1.000 | 586 | 16,080,701 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 339 | ab-na | mmol/l | 1125 | 0 | [130.94, 134.84, 136.62, 138.04, 139.34, 140.42, 141.09, 142.57, 144.87] |  | Arterial blood | Native preparation | Sodium | Substance Concentration |  | Blood arterial | Qn | Point in time (spot) | FALSE |
| 340 | ap-lakt | mmol/l | 1456 | 0 | [0.68, 0.81, 0.96, 1.1, 1.28, 1.5, 1.81, 2.29, 3.25] |  |  |  | Lactate | Substance Concentration |  | Blood arterial | Qn | Point in time (spot) | FALSE |
| 341 | ap-lakt |  | 18 | 50 |  |  |  |  | Lactate |  |  | Plasma |  |  | FALSE |
| 342 | ap-na | % | 24 | 0 |  |  |  | Native preparation | Sodium |  |  | Plasma |  |  | FALSE |
| 343 | ap-na | g/l | 6 | 0 |  |  |  | Native preparation | Sodium | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 344 | ap-na | kpa | 12 | 0 |  |  |  | Native preparation | Sodium |  |  | Plasma |  |  | FALSE |
| 345 | ap-na | mmol/l | 50270 | 0 | [130.71, 133.37, 134.96, 136, 136.98, 137.95, 138.88, 139.98, 141.72] |  |  | Native preparation | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 346 | ap-na | °c | 6 | 0 |  |  |  | Native preparation | Sodium |  |  | Plasma |  |  | FALSE |
| 347 | ap-na |  | 233 | 92.27 |  |  |  | Native preparation | Sodium |  |  | Plasma | Nar |  | FALSE |
| 348 | ap-nak |  | 155 | 100 |  |  |  |  |  |  |  | Plasma |  |  | TRUE |
| 349 | b-na | mmol/l | 59360 | 0 | [132.76, 134.99, 136.51, 137.61, 138.41, 139.21, 140.23, 141.69, 144.08] |  | Blood | Native preparation | Sodium | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 350 | b-na |  | 9740 | 95.39 | [132.18, 135.78, 137.16, 138.83, 139, 140, 140.41, 141, 142] |  | Blood | Native preparation | Sodium | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 351 | cp-na | mmol/l | 305 | 0 | [132, 134.22, 135.76, 137, 138, 139.28, 140, 141.93, 143] |  |  | Native preparation | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 352 | cp-na |  | 18 | 100 |  |  |  | Native preparation | Sodium |  |  | Plasma |  |  | FALSE |
| 353 | di-na | mmol/l | 307 | 0 |  | Di-Natrium | Dialysis fluid | Native preparation | Sodium | Substance Concentration |  | Dialysate | Qn | Point in time (spot) | FALSE |
| 354 | di-na |  | 5 | 100 |  | Di-Natrium | Dialysis fluid | Native preparation | Sodium |  |  | Dialysate |  |  | FALSE |
| 355 | du-na | mmol | 2785 | 0.25 | [76.79, 98.05, 115.16, 132.8, 151.88, 170.12, 193.55, 223.43, 273.21] | dU-Natrium | 24-hour urine | Native preparation | Sodium | Substance Rate |  | Urine | Qn | 24 hours | FALSE |
| 356 | du-na | mmol/24h | 60 | 0 |  | dU-Natrium | 24-hour urine | Native preparation | Sodium | Substance Rate |  | Urine | Qn | 24 hours | FALSE |
| 357 | du-na |  | 1021 | 70.23 | [65.53, 84.3, 103.25, 116.92, 139.24, 156.61, 172.58, 210.59, 273.58] | dU-Natrium | 24-hour urine | Native preparation | Sodium | Substance Rate |  | Urine | Qn | 24 hours | FALSE |
| 358 | fp-ctx | ng/l | 34 | 0 |  |  | Fasting plasma |  | C-terminal telopeptide of type I collagen | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 359 | fp-ctx | ug/l | 1281 | 0 | [0.09, 0.14, 0.2, 0.25, 0.3, 0.38, 0.48, 0.6, 0.81] |  | Fasting plasma |  | C-terminal telopeptide of type I collagen | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 360 | fp-ctx |  | 491 | 16.7 | [0.12, 0.19, 0.24, 0.31, 0.39, 0.48, 0.58, 0.71, 1] |  | Fasting plasma |  | C-terminal telopeptide of type I collagen | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 361 | fp-gt | u/l | 772 | 0 | [15.6, 19.58, 23.9, 27.61, 33.27, 39.92, 49.93, 68.82, 104.64] |  | Fasting plasma |  | Gamma-glutamyltransferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 362 | fp-gt |  | 11 | 0 |  |  | Fasting plasma |  | Gamma-glutamyltransferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 363 | fp-na | mmol/l | 6047 | 0 | [135.6, 137.84, 139, 139.97, 140.01, 141, 141.04, 142, 143] |  | Fasting plasma | Native preparation | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 364 | fp-na |  | 18 | 11.11 |  |  | Fasting plasma | Native preparation | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 365 | p-acth | ng/l | 10045 | 0.42 | [8.08, 11.12, 14.1, 17.14, 20.58, 24.79, 30.92, 40.41, 66.95] | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 366 | p-acth | pmol/l | 7 | 0 |  | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone | Substance Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 367 | p-acth |  | 1461 | 80.01 | [9.26, 12.21, 15.18, 18.04, 23.17, 27.09, 32.96, 40.36, 61.68] | P -Adrenokortikotropiini | Plasma |  | Adrenocorticotropic hormone | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 368 | p-at3 | % | 33387 | 0.01 | [54.15, 67.47, 77.12, 84.9, 91.44, 97.34, 103.31, 110.17, 119.77] | P -Antitrombiini III | Plasma |  | Antithrombin III | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 369 | p-at3 | form | 18 | 0 |  | P -Antitrombiini III | Plasma |  | Antithrombin III |  |  | Plasma | Doc |  | FALSE |
| 370 | p-at3 |  | 750 | 50.4 | [77.41, 88.27, 92.93, 97.96, 101.75, 106.37, 110.41, 114.53, 119.94] | P -Antitrombiini III | Plasma |  | Antithrombin III | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 371 | p-at3. | % | 4852 | 0 | [82.58, 90.63, 95.72, 100.18, 103.97, 107.65, 111.95, 117.06, 124.39] |  | Plasma |  | Antithrombin III | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 372 | p-at3. |  | 269 | 20.45 | [87.63, 92.63, 97.23, 100.8, 104.86, 109.03, 113.28, 117.74, 123.49] |  | Plasma |  | Antithrombin III | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 373 | p-efa | form | 5 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  |  |  |  | Plasma |  |  | TRUE |
| 374 | p-efa |  | 125 | 100 |  | P -Rasvahapot, välttämättömät | Plasma |  |  |  |  | Plasma |  |  | TRUE |
| 375 | p-fakb | g/l | 120 | 0 | [0.14, 0.17, 0.18, 0.2, 0.21, 0.21, 0.23, 0.26, 0.3] | P -Faktori B | Plasma |  | Complement factor B | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 376 | p-fakb |  | 35 | 25.71 |  | P -Faktori B | Plasma |  | Complement factor B |  |  | Plasma |  |  | FALSE |
| 377 | p-fe | umol/l | 2840 | 0 | [5.52, 7.66, 9.48, 11.25, 13.18, 14.87, 16.94, 19.46, 23.35] |  | Plasma |  | Iron | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 378 | p-fe |  | 740 | 33.92 | [5.15, 6.78, 8.55, 10.06, 12.18, 14.07, 16.43, 19.54, 23.49] |  | Plasma |  | Iron | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 379 | p-fs | s | 319 | 0 | [28, 29.31, 30.81, 32, 33.17, 35, 36.48, 39.22, 45.08] |  | Plasma |  |  | Time | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 380 | p-fs |  | 1586 | 99.87 |  |  | Plasma |  |  |  |  | Plasma |  |  | FALSE |
| 381 | p-fv | % | 6911 | 0.01 | [43.78, 58.4, 69.62, 80.37, 90.29, 99.93, 110.48, 122.94, 139.52] | P -Hyytymistekijä V | Plasma |  | Coagulation factor V | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 382 | p-fv |  | 261 | 40.23 | [68.7, 79.64, 87.53, 94.6, 99.14, 104.6, 110.72, 119.21, 132.72] | P -Hyytymistekijä V | Plasma |  | Coagulation factor V | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 383 | p-fx | % | 916 | 0.11 | [46.06, 65.75, 76.36, 83.72, 90.83, 97.78, 104.84, 112.37, 122.61] | P -Hyytymistekijä X | Plasma |  | Coagulation factor X | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 384 | p-fx |  | 949 | 87.46 | [66, 76.45, 83.38, 90.43, 96, 100.47, 108.88, 114, 128] | P -Hyytymistekijä X | Plasma |  | Coagulation factor X | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 385 | p-gt | mg/ml | 8 | 0 |  | P -Glutamyylitransferaasi | Plasma |  | Gamma-glutamyltransferase | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 386 | p-gt | u/l | 820178 | 0.02 | [14.56, 18.66, 23.05, 28.6, 36.08, 47.26, 65.76, 101.29, 195.48] | P -Glutamyylitransferaasi | Plasma |  | Gamma-glutamyltransferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 387 | p-gt |  | 15977 | 100 | [15.82, 20.13, 24.14, 29.03, 35.14, 45.13, 63.31, 89.78, 161.64] | P -Glutamyylitransferaasi | Plasma |  | Gamma-glutamyltransferase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 388 | p-hstni | ng/l | 3261 | 0 | [1, 2, 3, 4.12, 6.04, 9.1, 14.48, 27.09, 65.46] |  | Plasma |  | Troponin I | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 389 | p-k+na |  | 69230 | 100 |  |  | Plasma |  |  |  |  | Plasma |  |  | TRUE |
| 390 | p-k,na |  | 2518 | 100 |  |  | Plasma |  |  |  |  | Plasma |  |  | TRUE |
| 391 | p-k-na | mmol/l | 594 | 100 |  |  | Plasma | Native preparation |  |  |  | Plasma |  |  | TRUE |
| 392 | p-k-na |  | 186 | 100 |  |  | Plasma | Native preparation |  |  |  | Plasma |  |  | TRUE |
| 393 | p-k-pa | mmol/l | 197 | 0 | [3.53, 3.78, 3.9, 4, 4.04, 4.13, 4.3, 4.38, 4.56] |  | Plasma | Long-term / prolonged | Potassium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 394 | p-k/na |  | 321 | 100 |  |  | Plasma |  |  |  |  | Plasma |  |  | TRUE |
| 395 | p-ked. | mmol/l | 344 | 0 |  |  | Plasma |  |  |  |  | Plasma |  |  | FALSE |
| 396 | p-kjd. | mmol/l | 160 | 0 |  |  | Plasma |  |  |  |  | Plasma |  |  | FALSE |
| 397 | p-la1 | s | 1064 | 0 | [30, 31.95, 33.1, 34.81, 35.99, 37.75, 39.96, 44.96, 54.77] |  | Plasma |  | Lupus anticoagulant | Time | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 398 | p-la1 |  | 52 | 50 |  |  | Plasma |  | Lupus anticoagulant | Time | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 399 | p-la2 | s | 498 | 0 | [32, 33.41, 35.41, 36.98, 38.82, 40.9, 43.06, 47.24, 53.65] |  | Plasma |  | Lupus anticoagulant | Time | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 400 | p-la2 |  | 1411 | 99.43 |  |  | Plasma |  | Lupus anticoagulant |  |  | Plasma |  |  | FALSE |
| 401 | p-mypa | mg/l | 1692 | 0.06 | [0.64, 0.99, 1.33, 1.7, 2.12, 2.67, 3.43, 4.39, 6.28] | P -Mykofenolihappo | Plasma |  | Mycophenolic acid | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 402 | p-mypa |  | 245 | 76.33 |  | P -Mykofenolihappo | Plasma |  | Mycophenolic acid |  |  | Plasma |  |  | FALSE |
| 403 | p-na | mmol/ | 14 | 0 |  | P -Natrium | Plasma | Native preparation | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 404 | p-na | mmol/l | 7320578 | 0.03 | [133.91, 136.27, 137.98, 138.99, 139.95, 140, 141, 142, 143] | P -Natrium | Plasma | Native preparation | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 405 | p-na |  | 81059 | 100 | [134.02, 137.07, 138.67, 139, 140, 141, 142, 142.8, 143] | P -Natrium | Plasma | Native preparation | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 406 | p-na. | mmol/l | 1467 | 0 | [134.64, 136.99, 138.3, 139.9, 140.54, 141, 142, 142.75, 144] |  | Plasma |  | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 407 | p-na: | mmol/l | 621 | 0 | [131.65, 133.8, 135, 136.23, 137.85, 138.61, 139.67, 140.88, 142] |  | Plasma |  | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 408 | p-naed. | mmol/l | 306 | 0 |  |  | Plasma |  | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 409 | p-najd. | mmol/l | 154 | 0 |  |  | Plasma |  | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 410 | p-nak |  | 259040 | 100 |  |  | Plasma |  |  |  |  | Plasma |  |  | TRUE |
| 411 | p-nap | mmol/l | 342 | 0 | [132.69, 135.3, 137.47, 139, 140, 140.64, 142, 143, 145] |  | Plasma |  | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 412 | p-supar | ug/l | 351 | 0 | [2.87, 3.25, 3.63, 3.92, 4.33, 4.73, 5.27, 6.37, 8.21] |  | Plasma |  | Soluble urokinase plasminogen activator receptor | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 413 | p-supar |  | 16 | 100 |  |  | Plasma |  | Soluble urokinase plasminogen activator receptor |  |  | Plasma |  |  | FALSE |
| 414 | p-t3-v | pmol/l | 82081 | 0.04 | [3.46, 3.84, 4.11, 4.35, 4.57, 4.81, 5.08, 5.46, 6.26] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated | Triiodothyronine.free | Substance Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 415 | p-t3-v |  | 921 | 100 | [3.47, 3.87, 4.08, 4.31, 4.53, 4.77, 5.02, 5.39, 6.24] | P -Trijodityroniini, vapaa | Plasma | Free or unconjugated | Triiodothyronine.free | Substance Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 416 | p-t4-v | pmol/l | 1108128 | 0.01 | [11.98, 13.02, 13.95, 14.63, 15.23, 16.03, 16.92, 17.94, 19.56] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated | Thyroxine.free | Substance Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 417 | p-t4-v |  | 19446 | 100 | [12, 13.8, 14.44, 15.06, 16, 16.21, 16.99, 17.6, 19] | P -Tyroksiini, vapaa | Plasma | Free or unconjugated | Thyroxine.free | Substance Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 418 | p-t4v | pmol/l | 110881 | 0 | [12.73, 13.79, 14.57, 15.27, 15.96, 16.68, 17.48, 18.48, 19.99] |  | Plasma |  | Thyroxine.free | Substance Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 419 | p-t4v |  | 4743 | 100 | [12.19, 13.39, 14.21, 14.93, 15.61, 16.33, 17.17, 18.29, 20.03] |  | Plasma |  | Thyroxine.free | Substance Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 420 | p-tfr | mg/l | 188406 | 0.02 | [0.81, 1.28, 2.05, 2.5, 2.87, 3.3, 3.83, 4.64, 6.21] | P -Transferriinireseptori, liukoinen | Plasma |  | Transferrin receptor.soluble | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 421 | p-tfr |  | 15951 | 100 | [2.12, 2.53, 2.87, 3.21, 3.63, 4.15, 4.81, 5.75, 7.59] | P -Transferriinireseptori, liukoinen | Plasma |  | Transferrin receptor.soluble | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 422 | p-tni | ng/l | 220095 | 0 | [4, 5.13, 7.13, 10.22, 15.11, 24.46, 46.82, 122.37, 829.48] | P -Troponiini I | Plasma |  | Troponin I | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 423 | p-tni | ug/l | 25579 | 0 | [0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.08, 0.16, 0.78] | P -Troponiini I | Plasma |  | Troponin I | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 424 | p-tni |  | 70910 | 100 | [0.05, 0.22, 2.89, 4.65, 7.45, 12.28, 24.91, 48.92, 145.81] | P -Troponiini I | Plasma |  | Troponin I | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 425 | p-tni. | ng/l | 6 | 0 |  |  | Plasma |  | Troponin I | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 426 | p-tni. | ug/l | 155 | 0 | [0, 0, 0, 0, 0, 0, 0.01, 0.02, 0.06] |  | Plasma |  | Troponin I | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 427 | p-tni. |  | 28 | 100 |  |  | Plasma |  | Troponin I |  |  | Plasma |  |  | FALSE |
| 428 | p-tnih | ng/l | 1974 | 0 | [4, 5.78, 7.89, 10.8, 16.52, 27.69, 54.92, 168.16, 1593.63] |  | Plasma |  | Troponin I | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 429 | p-tnih |  | 440 | 100 |  |  | Plasma |  | Troponin I |  |  | Plasma |  |  | FALSE |
| 430 | p-tnl | ng/l | 124 | 0 | [3, 4, 5.16, 7, 10, 12.72, 29.97, 89.8, 240.6] |  | Plasma |  | Troponin I | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 431 | p-tnl | ug/l | 179 | 0 | [0, 0, 0, 0, 0, 0.01, 0.01, 0.02, 0.05] |  | Plasma |  | Troponin I | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 432 | p-tnl |  | 36 | 100 |  |  | Plasma |  | Troponin I |  |  | Plasma |  |  | FALSE |
| 433 | p-tnt | ng/l | 437584 | 0.96 | [6.97, 9.13, 11.78, 15.03, 19.12, 24.8, 33.92, 51.22, 106.22] | P -Troponiini T | Plasma |  | Troponin T | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 434 | p-tnt | ug/l | 76 | 0 |  | P -Troponiini T | Plasma |  | Troponin T | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 435 | p-tnt |  | 80220 | 100 | [6.97, 8.93, 11.46, 14.61, 18.09, 22.79, 29.94, 42.37, 74.82] | P -Troponiini T | Plasma |  | Troponin T | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 436 | p-tt | % | 472003 | 0.01 | [50.44, 65.04, 74.28, 81.62, 88.26, 94.73, 101.62, 109.77, 121.26] | P -Tromboplastiiniaika | Plasma |  | Prothrombin time | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 437 | p-tt | form | 20 | 0 |  | P -Tromboplastiiniaika | Plasma |  | Prothrombin time |  |  | Plasma | Doc |  | FALSE |
| 438 | p-tt |  | 4462 | 100 | [41.42, 56.72, 66.85, 77.09, 85.82, 93.79, 102.07, 112.01, 126.16] | P -Tromboplastiiniaika | Plasma |  | Prothrombin time | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 439 | p-tt- | % | 1432 | 0 | [60.12, 72.07, 78.16, 83.25, 88.78, 95.39, 102.35, 111.94, 122.43] |  | Plasma |  | Prothrombin time | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 440 | p-tt- |  | 29 | 96.55 |  |  | Plasma |  | Prothrombin time |  |  | Plasma |  |  | FALSE |
| 441 | p-tt. | % | 5628 | 0 | [63.13, 78.7, 87.12, 93.57, 99.77, 105.67, 112.42, 119.67, 130.89] |  | Plasma |  | Prothrombin time | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 442 | p-tt. |  | 328 | 31.4 | [48, 79.63, 90.12, 98.65, 107.18, 114.33, 121.82, 130.4, 140] |  | Plasma |  | Prothrombin time | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 443 | p-ttr | % | 1114 | 0 | [50.89, 61.27, 67.88, 73.89, 78.52, 83.07, 89.29, 95.08, 100] |  | Plasma |  | Prothrombin time | Arbitrary Concentration | Coagulation assay | Plasma | Qn | Point in time (spot) | FALSE |
| 444 | p-ttr |  | 89 | 89.89 |  |  | Plasma |  | Prothrombin time |  |  | Plasma |  |  | FALSE |
| 445 | pdgfr |  | 461 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 446 | peak | l/min | 12 | 0 |  |  |  |  | Peak expiratory flow | Volume Rate |  | ^Patient | Qn | Point in time (spot) | FALSE |
| 447 | peak |  | 104 | 100 |  |  |  |  | Peak expiratory flow |  |  | ^Patient |  |  | FALSE |
| 448 | pef-pa |  | 7844 | 99.92 |  | Uloshengityksen huippuvirtaus, sarjamittaus, pitkäaikaisseuranta |  | Long-term / prolonged |  |  |  | ^Patient |  |  | TRUE |
| 449 | pef-ras |  | 242 | 100 |  | Uloshengityksen huippuvirtaus, sarjamittaus, rasituskoe |  |  |  |  |  | ^Patient |  |  | TRUE |
| 450 | pf-ace | u/l | 313 | 3.19 | [6.4, 10.22, 12.78, 15.45, 17.82, 19.96, 24.1, 28.83, 37.4] | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  | Angiotensin converting enzyme | Catalytic Concentration |  | Pleural fluid | Qn | Point in time (spot) | FALSE |
| 451 | pf-ace |  | 161 | 98.14 |  | Pf-Angiotensiini-1-konvertaasi | Pleural fluid |  | Angiotensin converting enzyme |  |  | Pleural fluid |  |  | FALSE |
| 452 | pf-ada | u/l | 3550 | 0.14 | [3.68, 5.14, 6.78, 8.01, 9.46, 11.17, 13.55, 17.33, 25.48] | Pf-Adenosiinideaminaasi | Pleural fluid |  | Adenosine deaminase | Catalytic Concentration |  | Pleural fluid | Qn | Point in time (spot) | FALSE |
| 453 | pf-ada |  | 365 | 90.96 |  | Pf-Adenosiinideaminaasi | Pleural fluid |  | Adenosine deaminase |  |  | Pleural fluid |  |  | FALSE |
| 454 | pneag |  | 244 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 455 | s-na | mmol/l | 124118 | 0 | [137.36, 138.84, 139.01, 140, 140.14, 141, 141.38, 142, 143] | S -Natrium | Serum | Native preparation | Sodium | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 456 | s-na | mol/l | 5 | 0 |  | S -Natrium | Serum | Native preparation | Sodium | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 457 | s-na |  | 931 | 67.35 | [137.2, 138, 139, 139, 140, 140, 141, 141, 142.37] | S -Natrium | Serum | Native preparation | Sodium | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 458 | s-t3-v | pmol/l | 18657 | 0 | [3.72, 4.06, 4.3, 4.5, 4.69, 4.9, 5.13, 5.43, 6.06] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated | Triiodothyronine.free | Substance Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 459 | s-t3-v |  | 1623 | 51.2 | [3.55, 3.8, 4.02, 4.22, 4.41, 4.6, 4.85, 5.16, 5.82] | S -Trijodityroniini, vapaa | Serum | Free or unconjugated | Triiodothyronine.free | Substance Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 460 | s-t4-v | pmol/l | 252259 | 0 | [11.09, 12, 12.88, 13.14, 13.97, 14.48, 15.15, 16.1, 17.48] | S -Tyroksiini, vapaa | Serum | Free or unconjugated | Thyroxine.free | Substance Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 461 | s-t4-v |  | 9900 | 100 | [12.03, 12.98, 13.72, 14.35, 14.94, 15.68, 16.39, 17.25, 18.59] | S -Tyroksiini, vapaa | Serum | Free or unconjugated | Thyroxine.free | Substance Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 462 | s-t4v | pmol/l | 1086 | 0 | [12.85, 13, 14, 14.52, 15, 15.93, 16, 17, 18] |  | Serum |  | Thyroxine.free | Substance Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 463 | s-tfr | mg | 7 | 0 |  | S -Transferriinireseptori, liukoinen | Serum |  | Transferrin receptor.soluble |  |  | Serum |  |  | FALSE |
| 464 | s-tfr | mg/l | 77760 | 0 | [1, 1.22, 1.5, 1.89, 2.35, 2.8, 3.34, 4.1, 5.59] | S -Transferriinireseptori, liukoinen | Serum |  | Transferrin receptor.soluble | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 465 | s-tfr |  | 1379 | 100 | [1.84, 2.22, 2.62, 3.08, 3.57, 4.23, 5.1, 6.26, 8.15] | S -Transferriinireseptori, liukoinen | Serum |  | Transferrin receptor.soluble | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 466 | s-tnf | ng/l | 100 | 0 | [4.65, 5.4, 6.33, 7.11, 7.81, 8.85, 10.5, 13.2, 23.25] | S -Tuumorinekroositekijä, alfa | Serum |  | Tumor necrosis factor alpha | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 467 | s-tnf |  | 50 | 74 |  | S -Tuumorinekroositekijä, alfa | Serum |  | Tumor necrosis factor alpha | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 468 | s-tni | ng/l | 63 | 0 | [2.98, 3.29, 4.36, 4.96, 6.38, 8.72, 14.54, 33, 54.53] | S -Troponiini I | Serum |  | Troponin I | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 469 | s-tni | ug/l | 11 | 0 |  | S -Troponiini I | Serum |  | Troponin I | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 470 | s-tni |  | 171 | 100 |  | S -Troponiini I | Serum |  | Troponin I |  |  | Serum |  |  | FALSE |
| 471 | s-tnt | ng/l | 149 | 0 | [40, 42, 45.21, 51.23, 64.69, 87.1, 139.39, 201.81, 358.2] | S -Troponiini T | Serum |  | Troponin T | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 472 | s-tnt |  | 7446 | 99.38 |  | S -Troponiini T | Serum |  | Troponin T |  |  | Serum | Nar |  | FALSE |
| 473 | s-tob | mg/l | 805 | 0.99 | [0.29, 0.5, 0.61, 0.8, 1.01, 1.26, 1.54, 1.91, 3.02] | S -Tobramysiini | Serum |  | Tobramycin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 474 | s-tob |  | 560 | 81.96 |  | S -Tobramysiini | Serum |  | Tobramycin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 475 | sp-pak |  | 196 | 100 |  |  | Sperm / semen |  |  |  |  | Semen |  |  | TRUE |
| 476 | sp-pakd |  | 138 | 100 |  |  | Sperm / semen |  |  |  |  | Semen |  |  | TRUE |
| 477 | u-na | mmol/l | 8969 | 1.33 | [24.74, 32.42, 40.4, 48.4, 57.53, 68.16, 81.75, 99.14, 129.68] | U -Natrium | Urine | Native preparation | Sodium | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 478 | u-na |  | 2662 | 76.37 | [27.27, 35.54, 43.11, 51.43, 60.05, 68.34, 78.15, 92.47, 111.65] | U -Natrium | Urine | Native preparation | Sodium | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 479 | v-na |  | 265 | 0.75 | [130.22, 134.26, 135.98, 137.59, 138.5, 139.03, 140, 141, 142] |  |  | Native preparation | Sodium | Substance Concentration |  | Blood venous | Qn | Point in time (spot) | FALSE |
| 480 | vp-na | mmol/l | 10896 | 0 | [132.84, 135.34, 136.96, 137.97, 138.99, 139.84, 140.33, 141.08, 142.49] |  |  | Native preparation | Sodium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 481 | vp-na |  | 174 | 98.28 |  |  |  | Native preparation | Sodium |  |  | Plasma |  |  | FALSE |

