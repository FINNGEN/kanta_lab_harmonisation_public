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
Here is group 167.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Albumin | Albumin | 1.000 | 80 | 2,081,573 |
| Albumin | Albumin in serum | 0.779 | 0 | 0 |
| Albumin | Albumin ug | 0.752 | 0 | 0 |
| Alpha 1 globulin | Alpha 1 globulin | 1.000 | 13 | 41,700 |
| Alpha 1 globulin | Alpha 2 globulin | 0.908 | 10 | 39,833 |
| Alpha 1 globulin | Alpha globulin | 0.869 | 0 | 0 |
| Alpha 1 globulin | Alpha 1 globulin/Protein.total | 0.837 | 0 | 0 |
| Alpha 1 globulin | Beta 1 globulin | 0.800 | 11 | 39,801 |
| Alpha 2 globulin | Alpha 2 globulin | 1.000 | 10 | 39,833 |
| Alpha 2 globulin | Alpha 1 globulin | 0.913 | 13 | 41,700 |
| Alpha 2 globulin | Alpha globulin | 0.858 | 0 | 0 |
| Alpha 2 globulin | Alpha 2 globulin/Protein.total | 0.831 | 0 | 0 |
| Alpha 2 globulin | Beta 2 globulin | 0.794 | 11 | 39,732 |
| Basophils | Basophils | 1.000 | 26 | 1,519,691 |
| Basophils | Basophils/Cells | 0.808 | 0 | 0 |
| Basophils | Basophils/leukocytes | 0.792 | 48 | 1,446,628 |
| Basophils/Leukocytes | Basophils/leukocytes | 1.000 | 48 | 1,446,628 |
| Basophils/Leukocytes | Basophils/Cells | 0.869 | 0 | 0 |
| Basophils/Leukocytes | Basophils+Mast cells/Leukocytes | 0.844 | 0 | 0 |
| Basophils/Leukocytes | Basophils.immature/Leukocytes | 0.813 | 0 | 0 |
| Basophils/Leukocytes | Basophils.band form/Leukocytes | 0.806 | 0 | 0 |
| Beta 1 globulin | Beta 1 globulin | 1.000 | 11 | 39,801 |
| Beta 1 globulin | Beta 2 globulin | 0.938 | 11 | 39,732 |
| Beta 1 globulin | Beta globulin | 0.852 | 0 | 0 |
| Beta 1 globulin | Beta 1 globulin/Protein.total | 0.840 | 0 | 0 |
| Beta 1 globulin | Beta 2 globulin+Gamma globulin | 0.823 | 0 | 0 |
| Beta 2 globulin | Beta 2 globulin | 1.000 | 11 | 39,732 |
| Beta 2 globulin | Beta 1 globulin | 0.938 | 11 | 39,801 |
| Beta 2 globulin | Beta 2 globulin+Gamma globulin | 0.875 | 0 | 0 |
| Beta 2 globulin | Beta globulin | 0.863 | 0 | 0 |
| Beta 2 globulin | Gamma globulin/Beta globulin | 0.831 | 0 | 0 |
| Calcium | Calcium | 1.000 | 33 | 540,872 |
| Eosinophils | Eosinophils | 1.000 | 35 | 1,618,391 |
| Eosinophils | Eosinophils/Cells | 0.815 | 0 | 0 |
| Eosinophils | Eosinophils/leukocytes | 0.777 | 54 | 1,434,138 |
| Eosinophils/Leukocytes | Eosinophils/leukocytes | 1.000 | 54 | 1,434,138 |
| Eosinophils/Leukocytes | Eosinophils/Cells | 0.869 | 0 | 0 |
| Eosinophils/Leukocytes | Eosinophils.immature/Leukocytes | 0.817 | 0 | 0 |
| Eosinophils/Leukocytes | Eosinophils/100 leukocytes | 0.789 | 0 | 0 |
| Eosinophils/Leukocytes | Epithelial cells/Leukocytes | 0.789 | 0 | 0 |
| Erythroblasts | Erythroblasts early | 0.848 | 0 | 0 |
| Erythroblasts | Erythroblasts mid | 0.837 | 0 | 0 |
| Erythroblasts | Erythroid cells | 0.831 | 0 | 0 |
| Erythroblasts | Erythroblasts late | 0.815 | 0 | 0 |
| Erythroblasts | Erythrocytes | 0.764 | 64 | 12,187,960 |
| Erythrocyte distribution width | Erythrocyte distribution width | 1.000 | 0 | 0 |
| Erythrocyte distribution width | Reticulocyte distribution width | 0.874 | 0 | 0 |
| Erythrocyte distribution width | Hemoglobin distribution width | 0.816 | 0 | 0 |
| Erythrocyte distribution width | Platelet distribution width | 0.801 | 0 | 0 |
| Erythrocyte distribution width | Reticulocyte hemoglobin distribution width | 0.784 | 0 | 0 |
| Gamma globulin | Gamma globulin | 1.000 | 4 | 34,144 |
| Gamma globulin | Gamma 2 globulin | 0.852 | 0 | 0 |
| Gamma globulin | Gamma globulin/Beta globulin | 0.833 | 0 | 0 |
| Gamma globulin | Globulin | 0.804 | 0 | 0 |
| Gamma globulin | Beta globulin | 0.791 | 0 | 0 |
| Lymphocytes | Lymphocytes | 1.000 | 42 | 1,557,267 |
| Lymphocytes | Lymphocyte | 0.908 | 0 | 0 |
| Lymphocytes | Lymphocytes/Cells | 0.818 | 0 | 0 |
| Lymphocytes | Lambda lymphocytes | 0.817 | 0 | 0 |
| Lymphocytes | Lymphocytes/leukocytes | 0.800 | 92 | 1,475,101 |
| Lymphocytes/Leukocytes | Lymphocytes/leukocytes | 1.000 | 92 | 1,475,101 |
| Lymphocytes/Leukocytes | Lymphocytes/Cells | 0.848 | 0 | 0 |
| Lymphocytes/Leukocytes | Lymphoblasts/Leukocytes | 0.843 | 0 | 0 |
| Lymphocytes/Leukocytes | Lymphoma cells/Leukocytes | 0.831 | 0 | 0 |
| Lymphocytes/Leukocytes | Lymphocytes.immature/Leukocytes | 0.800 | 0 | 0 |
| M-protein | (none scored >= 0.75) |  |  |  |
| Monocytes | Monocytes | 1.000 | 29 | 1,513,142 |
| Monocytes | Monocytes/Cells | 0.814 | 0 | 0 |
| Monocytes | Monocytes+Macrophages | 0.784 | 0 | 0 |
| Monocytes | Monocytes/leukocytes | 0.782 | 51 | 1,452,186 |
| Monocytes | Immature monocytes | 0.771 | 0 | 0 |
| Monocytes/Leukocytes | Monocytes/leukocytes | 1.000 | 51 | 1,452,186 |
| Monocytes/Leukocytes | Monocytes+Macrophages/leukocytes | 0.872 | 0 | 0 |
| Monocytes/Leukocytes | Monocytes/Cells | 0.872 | 0 | 0 |
| Monocytes/Leukocytes | Monocytoid cells/Leukocytes | 0.835 | 0 | 0 |
| Monocytes/Leukocytes | Monocytes.abnormal/Leukocytes | 0.835 | 0 | 0 |
| Neutrophils | Neutrophils | 1.000 | 48 | 2,694,055 |
| Neutrophils | Neutrophil | 0.853 | 0 | 0 |
| Neutrophils | Neutrophils/Cells | 0.812 | 0 | 0 |
| Neutrophils | Neutrophils/leukocytes | 0.761 | 62 | 1,413,613 |
| Neutrophils/Leukocytes | Neutrophils/leukocytes | 1.000 | 62 | 1,413,613 |
| Neutrophils/Leukocytes | Neutrophils/Cells | 0.874 | 0 | 0 |
| Neutrophils/Leukocytes | Granulocytes/leukocytes | 0.831 | 39 | 44,978 |
| Neutrophils/Leukocytes | Heterophils/Leukocytes | 0.812 | 0 | 0 |
| Neutrophils/Leukocytes | Neutrophils.immature/Leukocytes | 0.803 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Number Concentration | Number Concentration | 1.000 | 507 | 49,434,956 |
| Number Fraction | Number Fraction | 1.000 | 482 | 8,246,054 |
| Number Fraction | Decimal number fraction | 0.787 | 1 | 6,152 |
| Number Fraction | Time Fraction | 0.765 | 0 | 0 |
| Presence or Identity | Presence or Identity | 1.000 | 79 | 1,946,967 |
| Ratio | Ratio | 1.000 | 88 | 786,172 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Automated count | Automated count | 1.000 | 103 | 11,606,924 |
| Electrophoresis | Electrophoresis | 1.000 | 91 | 336,860 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Red Blood Cells | Red Blood Cells | 1.000 | 100 | 38,219,166 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| White Blood Cells | White blood cells | 1.000 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1950 | b-erybla,osatutkimus(19978b-erybla) | e9/l | 1575 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  | Erythroblasts | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1951 | b-erybla,osatutkimus(b-erybla) | e9/l | 3732 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  | Erythroblasts | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1952 | b-erybla,osatutkimus(b-erybla) |  | 8 | 75 |  |  | Blood |  | Erythroblasts | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1953 | b-neut,osatutkimus(689b-neut) | e9/l | 114 | 0 | [2.36, 2.69, 3.03, 3.4, 3.69, 4.15, 4.59, 5.12, 5.88] |  | Blood |  | Neutrophils | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1954 | basofiilit,absol.arvot,osatutkimus(40b-baso) | e9/l | 114 | 0 | [0.02, 0.03, 0.03, 0.04, 0.04, 0.05, 0.06, 0.06, 0.08] |  |  |  | Basophils | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1955 | basofiilit,konediffi(),osatutk.b-diffi | % | 1040 | 0 | [0.2, 0.35, 0.48, 0.57, 0.68, 0.78, 0.9, 1.09, 1.35] |  |  |  | Basophils/Leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1956 | basofiilit,osatutkimus(692l-baso) | % | 128 | 0 | [0, 0, 0.88, 1, 1, 1, 1, 1, 1] |  |  |  | Basophils/Leukocytes | Number Fraction |  | White Blood Cells | Qn | Point in time (spot) | FALSE |
| 1957 | e-rdw,osatutkimus(19976e-rdw) | % | 1577 | 0 | [12, 12.98, 13, 13, 13, 13, 13.6, 14, 14.04] |  | Erythrocyte |  | Erythrocyte distribution width | Ratio | Automated count | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 1958 | e-rdw,osatutkimus(e-rdw) | % | 3731 | 0 | [12, 12.05, 13, 13, 13, 13, 13, 14, 14.04] |  | Erythrocyte |  | Erythrocyte distribution width | Ratio | Automated count | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 1959 | e-rdw,osatutkimus(e-rdw) |  | 8 | 100 |  |  | Erythrocyte |  | Erythrocyte distribution width |  |  | Red Blood Cells | Nar | Point in time (spot) | FALSE |
| 1960 | eosinofiilit,absol.arvot,osatutkimus(39b-eos) | e9/l | 114 | 0 | [0.06, 0.09, 0.12, 0.16, 0.18, 0.2, 0.23, 0.28, 0.33] |  |  |  | Eosinophils | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1961 | eosinofiilit,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [0.08, 1.13, 1.71, 2.33, 2.85, 3.43, 4.13, 5.02, 6.83] |  |  |  | Eosinophils/Leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1962 | eosinofiilit,osatutkimus(690l-eos) | % | 114 | 0 | [1, 1.43, 2, 2, 3, 3, 3.11, 4, 5] |  |  |  | Eosinophils/Leukocytes | Number Fraction |  | White Blood Cells | Qn | Point in time (spot) | FALSE |
| 1963 | eosinofiilitabs,konediffi,osatutk.b-diffi | e9/l | 1041 | 0 | [0.01, 0.07, 0.1, 0.14, 0.17, 0.22, 0.27, 0.33, 0.46] |  |  |  | Eosinophils | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1964 | kalsium,osatutkimus(p-ca) | mmol/l | 167 | 0 | [2.26, 2.3, 2.32, 2.34, 2.37, 2.38, 2.41, 2.43, 2.47] |  |  |  | Calcium | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1965 | l-neut,osatutkimus(688l-neut) | % | 114 | 0 | [46.1, 51, 53.29, 55, 56.87, 59, 62, 66.13, 71.3] |  | Leukocyte |  | Neutrophils/Leukocytes | Number Fraction |  | White Blood Cells | Qn | Point in time (spot) | FALSE |
| 1966 | lymfosyytit,absol.arvot,osatutkimus(43b-lymf) | e9/l | 114 | 0 | [1.2, 1.42, 1.67, 1.84, 1.94, 2.02, 2.22, 2.46, 2.71] |  |  |  | Lymphocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1967 | lymfosyytit,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [14.77, 18.39, 21, 24.27, 27.4, 30.54, 33.61, 37.23, 41.49] |  |  |  | Lymphocytes/Leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1968 | lymfosyytit,osatutkimus(46l-lymf) | % | 114 | 0 | [17.98, 23.4, 26.71, 28, 31, 32.84, 34.76, 36, 40.42] |  |  |  | Lymphocytes/Leukocytes | Number Fraction |  | White Blood Cells | Qn | Point in time (spot) | FALSE |
| 1969 | monosyytit,absol.arvot,osatutkimus(42b-monos) | e9/l | 114 | 0 | [0.36, 0.42, 0.44, 0.49, 0.53, 0.58, 0.62, 0.67, 0.77] |  |  |  | Monocytes | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1970 | monosyytit,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [6.01, 6.87, 7.49, 8.19, 8.74, 9.45, 10.43, 11.69, 13.27] |  |  |  | Monocytes/Leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1971 | monosyytit,osatutkimus(693l-monos) | % | 114 | 0 | [6, 6.9, 7, 8, 8, 9, 9, 10, 11] |  |  |  | Monocytes/Leukocytes | Number Fraction |  | White Blood Cells | Qn | Point in time (spot) | FALSE |
| 1972 | neutrofiiliset,konediffi(),osatutk.b-diffi | % | 1041 | 0 | [43.33, 48.08, 51.94, 55.59, 58.77, 61.59, 65.14, 69.9, 74.47] |  |  |  | Neutrophils/Leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1973 | neutrofiilitabs,konediffi,osatutk.b-diffi | e9/l | 1041 | 0 | [1.86, 2.39, 2.82, 3.25, 3.63, 4.11, 4.7, 5.54, 6.96] |  |  |  | Neutrophils | Number Concentration | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1974 | s-albumiini,osatutkimuss-prot-fr | g/l | 109 | 0 | [31.62, 35.39, 37.28, 38.52, 39.57, 40.75, 41.75, 43.12, 44] |  | Serum | Fractions | Albumin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 1975 | s-alfa-1-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [2.3, 2.4, 2.54, 2.7, 2.89, 3.08, 3.35, 3.6, 4.2] |  | Serum | Fractions | Alpha 1 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 1976 | s-alfa-2-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [5.63, 6, 6.24, 6.66, 7.47, 7.93, 8.35, 9.06, 9.9] |  | Serum | Fractions | Alpha 2 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 1977 | s-beta-1-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [3.5, 3.7, 3.85, 4.04, 4.14, 4.31, 4.42, 4.7, 4.9] |  | Serum | Fractions | Beta 1 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 1978 | s-beta-2-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [2.8, 3.09, 3.44, 3.86, 4.01, 4.31, 4.58, 4.8, 5.27] |  | Serum | Fractions | Beta 2 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 1979 | s-gamma-globuliini,osatutkimuss-prot-fr | g/l | 109 | 0 | [6.61, 7.97, 8.64, 9.16, 9.73, 10.36, 11, 11.66, 12.99] |  | Serum | Fractions | Gamma globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 1980 | s-m-komponentti-1(valetietues-prot-fr) | g/l | 135 | 0 | [0, 0, 0, 1.3, 2.13, 3.83, 5.42, 7.84, 12.97] |  | Serum |  | M-protein | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 1981 | s-m-komponentti-1(valetietues-prot-fr) |  | 93 | 100 |  |  | Serum |  | M-protein | Presence or Identity | Electrophoresis | Serum | Nar | Point in time (spot) | FALSE |
| 1982 | s-m-komponentti-2(valetietues-prot-fr) | g/l | 82 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 1] |  | Serum |  | M-protein | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 1983 | s-m-komponentti-2(valetietues-prot-fr) |  | 133 | 100 |  |  | Serum |  | M-protein | Presence or Identity | Electrophoresis | Serum | Nar | Point in time (spot) | FALSE |
| 1984 | s-m-komponentti-3(valetietues-prot-fr) |  | 131 | 100 |  |  | Serum |  | M-protein | Presence or Identity | Electrophoresis | Serum | Nar | Point in time (spot) | FALSE |

