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
Here is group 84.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Collection method | Collection method | 1.000 | 0 | 0 |
| Collection method | Collection duration | 0.788 | 6 | 5,190 |
| Collection method | Collection setting | 0.784 | 0 | 0 |
| Collection method | Collection procedure comment | 0.775 | 0 | 0 |
| Collection method | Collection time | 0.771 | 0 | 0 |
| Specimen collection procedure | Specimen collection | 0.921 | 0 | 0 |
| Specimen collection procedure | Specimen collection problem | 0.784 | 0 | 0 |
| Specimen processing | Specimen preparation | 0.797 | 0 | 0 |
| Specimen processing | Specimen collection | 0.793 | 0 | 0 |
| Specimen transport | (none scored >= 0.75) |  |  |  |
| Time | Time | 1.000 | 0 | 0 |
| Time | Timing | 0.796 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Time | (none scored >= 0.75) |  |  |  |
| Type | Type | 1.000 | 17 | 482,606 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Bone marrow | Bone marrow | 1.000 | 18 | 26,597 |
| Urine | Urine | 1.000 | 586 | 16,080,701 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1215 | alvhuumott |  | 120 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1216 | bm-notto |  | 364 | 100 |  |  | Bone marrow |  | Specimen collection procedure | Finding |  | Bone marrow | Nar | Point in time (spot) | FALSE |
| 1217 | gyn.notto |  | 1682 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1218 | huumn.otto |  | 1041 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1219 | n-otto |  | 165 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1220 | n.otto |  | 258 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1221 | notto |  | 4008 | 99.88 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1222 | notto,neuv |  | 634 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1223 | notto,tyks |  | 416 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1224 | notto/eris |  | 444 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1225 | nottocovid |  | 1700 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1226 | nottopkl |  | 3516 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1227 | nottoverikoe |  | 1735 | 100 |  |  |  |  | Specimen collection procedure | Finding |  | Blood | Nar | Point in time (spot) | FALSE |
| 1228 | näyt.käsit |  | 520 | 100 |  |  |  |  | Specimen processing | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1229 | näyt.ot-1 |  | 174 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1230 | näyt.ot. |  | 10018 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1231 | näyt.otto |  | 5060 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1232 | näytekulje |  | 408 | 100 |  |  |  |  | Specimen transport | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1233 | näytt.otto |  | 7199 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1234 | näytteenot |  | 600 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1235 | näytteenotto |  | 1441 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |
| 1236 | ottotapa | h | 452 | 0 | [2, 2.94, 3.78, 4, 4, 5, 5.83, 6.78, 8] |  |  |  | Time | Time |  |  | Qn | Point in time (spot) | FALSE |
| 1237 | ottotapa |  | 73358 | 100 |  |  |  |  | Collection method | Type |  |  | Nar | Point in time (spot) | FALSE |
| 1238 | u-ottotap |  | 363 | 100 |  |  | Urine |  | Collection method | Type |  | Urine | Nar | Point in time (spot) | FALSE |
| 1239 | u-tutk/ottotapa |  | 5714 | 100 |  |  | Urine |  | Collection method | Type |  | Urine | Nar | Point in time (spot) | FALSE |
| 1240 | valv.notto |  | 502 | 100 |  |  |  |  | Specimen collection procedure | Finding |  |  | Nar | Point in time (spot) | FALSE |

