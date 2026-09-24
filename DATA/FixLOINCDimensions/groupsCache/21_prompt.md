[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

Your task: for each row, decide **which real OMOP concept the code actually maps to**, choosing from a list of genuine LOINC concepts retrieved for this group, and return that concept's `omop_concept_id`.

You are the step that turns a plausible-sounding name into a real, usable identifier. Nothing downstream can tell a confidently wrong concept id from a correct one, so an id you are not willing to defend is worse than no id at all.

# The Finnish laboratory coding system

Each national lab test has a 4-digit running number code and a short mnemonic abbreviation of at most 10 characters, built as:

    <system prefix> - <test abbreviation> [<suffix>]

- The **system prefix** is a 1-2 letter code for the specimen the sample came from, mostly from English words: `S` = serum, `P` = plasma, `B` = blood, `U` = urine, `Li` = cerebrospinal fluid, `F` = feces, `Ts` = tissue, `Pt` = patient (a whole-patient investigation), `fS`/`fP`/`fB` = fasting serum/plasma/blood, `dU` = 24-hour urine, `E` = erythrocyte, `L` = leukocyte.
- The **test abbreviation** is a mnemonic of the test's long Finnish name, occasionally an established international one (`CRP`, `TSH`).
- The optional **suffix** qualifies the result type or method: `-O` (qualitative/semi-quantitative), `-Ab` (antibodies), `-Ag` (antigen), `-Vi` (culture), `-Nh` (nucleic acid), `-Ion` (ionized), `-V` (free/unconjugated).

Finnish compounds run together: "transferriininrautakyllästeisyys" = transferrin iron saturation.

# What you are given

**The candidate table** — real OMOP LOINC concepts, found by running every guessed name in this group through a semantic search over the LOINC vocabulary and pooling the results. The candidates are pooled and deduplicated **across the whole group**, so a concept retrieved by one row's guess is offered to every row: sibling codes in a group are near-identical strings, and the right concept for one row is often the one another row's guess found. Columns:

- `omop_concept_id` — the id to return. Copy it digit for digit.
- `omop_concept_name` — the concept's real LOINC Long Common Name, as OMOP spells it today.
- `score` — how semantically close this concept was to the closest guess in the group, 0 to 1. **A high score only means the guess and the concept read alike.** The guess itself may have been wrong, so a 0.95 candidate for a misread code is a confident route to the wrong concept. Treat `score` as "the search found this", never as "this is correct".
- `top2000` — the concept's rank in the **LOINC Top 2000+ Lab Observations (SI edition)**: the ~2000 codes Regenstrief publishes as the recommended mapping targets, covering ~99.8% of the test volume of three large laboratory organisations. The SI edition is the relevant one here, since Finland reports in molar/SI units. Empty means the concept is not on the list.
- `n_codes` / `n_events` — how many curated Finnish lab codes already map to this concept, and how many records those codes cover. This is usage in Finland.

**The rows table** — one row per local lab test/unit combination:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty.
- `n` — number of records.
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available. The strongest single piece of evidence for what a test really measures and in which units: a "sodium" code whose deciles read 0.32-0.40 is not sodium in mmol/l.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess. A hypothesis to test against the row's own evidence, not an instruction.
- `is_panel` — whether the earlier pass judged the code to order a bundle of tests rather than report one result.

# How to decide

For each row:

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
2. **Pick the candidate that matches that reading**, and return its `omop_concept_id`. The unit and the deciles decide between candidates that differ only in property: `mmol/l` takes `[Moles/volume]`, `g/l` takes `[Mass/volume]`, `U/l` takes `[Enzymatic activity/volume]`. The prefix decides the specimen; remember that LOINC's `Serum or Plasma` is the right term for most routine chemistry, and that fasting is not part of the specimen (`fS` is still serum).
3. **When two or more candidates fit the evidence equally well**, break the tie in this order:
   1. **Prefer a candidate with a `top2000` rank.** That list is LOINC's own recommendation for what laboratories should map to, so a concept on it is the intended target and a near-duplicate off it usually is not.
   2. **Then prefer the higher `n_codes` / `n_events`.** Finland already maps real codes to that concept; matching established national usage keeps this data joinable with what exists.

   These break ties. They never override the row's own evidence: a top-2000 concept in the wrong specimen or the wrong units is still the wrong answer.
4. **Leave `omop_concept_id` empty when no candidate is right.** That is a correct, useful answer — it says "this code has no match in what the search returned", which is a fact the next iteration can act on. Common reasons: the code is too truncated or garbled to identify; it is a local administrative or non-laboratory code; or the search simply did not return the concept you know is right.
5. **Never return an id that is not in the candidate table.** Not one you remember, not one you derive from a LOINC code, not a plausible-looking number. Ids that are not in the table are discarded and the row is logged as unanswered, so inventing one only loses the row.

Specific things to watch:

- **A panel is not its components.** If the code orders a bundle (`B-PVK` = full blood count, `U-KemSeul` = urine dipstick screen), the answer is the panel concept (`CBC panel - Blood by Automated count`), not hemoglobin. Conversely, do not map a single reported result to a panel concept just because a panel candidate scored well.
- **Deprecated near-duplicates are already filtered out** of the candidate list — every candidate is a standard, current concept — so you never need to judge validity, only fit.
- **The same local code recurs in a group with different `UNIT`s**, and those rows are often genuinely different LOINC concepts. Answer each row from its own unit and deciles; do not give every row of a group the same id out of consistency.
- **Rows whose guess was empty still deserve an answer.** The earlier pass could not name them, but the group's pooled candidates may still contain the right concept.

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `omop_concept_id` — the chosen concept's id, copied from the candidate table. Empty if no candidate is right.
- `omop_concept_name` — that candidate's `omop_concept_name`, copied verbatim. Used only to cross-check that the id you copied is the concept you meant; leave it empty when the id is empty.
- `is_panel` — carried through from the input row unless the row is plainly contradictory.

Return an entry for EVERY row, including ones you leave unmapped.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which rows you could map and which you could not, where the candidate list was missing the concept you knew was right, where the earlier pass's guess sent the search astray, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 21.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3015399 | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | 1.000 |  | 15 | 285,465 |
| 3046569 | Transferrin receptor.soluble [Moles/volume] in Serum or Plasma | 0.945 |  |  0 |       0 |
| 3004789 | Transferrin [Mass/volume] in Serum or Plasma | 0.870 | 809 | 17 | 191,693 |
| 44816699 | Transferrin receptor.soluble/log Ferritin index [Mass Ratio] in Serum or Plasma | 0.864 |  |  0 |       0 |
| 3002903 | Transferrin [Moles/volume] in Serum or Plasma | 0.826 | 809 |  0 |       0 |
| 40763571 | Iron/Transferrin [Ratio] in Serum or Plasma | 0.825 |  | 38 | 180,828 |
| 3023017 | Iron/Transferrin [Mass Ratio] in Serum or Plasma | 0.823 |  |  0 |       0 |
| 648872 | Transferrin [Measurement] in Serum or Plasma | 0.803 |  |  0 |       0 |
| 3009814 | Iron saturation [Molar fraction] in Serum or Plasma | 0.800 | 192 |  0 |       0 |
| 3000185 | Iron saturation [Mass Fraction] in Serum or Plasma | 0.782 |  |  0 |       0 |
| 1988962 | Transferrin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.779 |  |  0 |       0 |
| 3007886 | Transferrin [Mass/volume] in Urine | 0.774 |  |  0 |       0 |
| 3001122 | Ferritin [Mass/volume] in Serum or Plasma | 0.762 | 153 | 13 | 725,861 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 155 | fp-transferriininrautakyllästeisyys | % | 3193 | 0 | [8.97, 13, 16.76, 20.1, 23.32, 26.3, 29.57, 33.75, 41.18] |  | Fasting plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 156 | fp-transferriininrautakyllästeisyys |  | 13 | 84.62 |  |  | Fasting plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 157 | fp-transferriininrautasaturaatio | % | 401 | 0 | [8.17, 12.08, 15.12, 17.38, 20.04, 22.98, 27.38, 31.01, 39.99] |  | Fasting plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 158 | fs-transferiininrautakyllästeisyys |  | 2368 | 65.54 | [0.08, 0.13, 0.16, 0.19, 0.23, 0.26, 0.3, 0.34, 0.41] |  | Fasting serum |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 159 | fs-transferiininrautakyllästeisyys,paastotilassa |  | 139 | 0 | [0.07, 0.12, 0.15, 0.19, 0.22, 0.24, 0.28, 0.33, 0.39] |  | Fasting serum |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 160 | fs-transferriininrautakyllästeisyys | % | 144 | 0 | [5.6, 8.49, 12.38, 16.94, 20.5, 24.07, 26.84, 31.55, 40] |  | Fasting serum |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 161 | fs-transferriininrautakyllästeisyys |  | 230 | 1.74 | [6.96, 10.51, 13.75, 17.95, 20.84, 24.42, 28.14, 32.22, 47.21] |  | Fasting serum |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 162 | p-transferriininrautakyllästeisyys | % | 288 | 0 | [7.78, 11.72, 15.31, 18.47, 21.76, 25.36, 29.49, 34.05, 40.39] |  | Plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 163 | p-transferriininrautakyllästeisyys,fp-fe/tr,fp-fe/tran,fp-fe/trans | % | 628 | 0 | [9.32, 12.95, 14.99, 17.87, 20.98, 23.9, 27.48, 31.74, 38.07] |  | Plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 164 | p-transferriinireseptori | mg/l | 1449 | 0 | [0.64, 0.72, 0.81, 0.91, 1.01, 1.14, 1.3, 1.54, 1.97] |  | Plasma |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 165 | p-transferriinireseptori |  | 176 | 100 |  |  | Plasma |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 166 | p-transferriinireseptori,liukoinen | mg/l | 1328 | 0 | [0.8, 1.04, 1.37, 1.95, 2.49, 2.95, 3.61, 4.4, 5.84] |  | Plasma |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 167 | p-transferriinireseptori,liukoinen |  | 42 | 100 |  |  | Plasma |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 168 | s-transferriinireseptori | mg/l | 1934 | 0 | [2.3, 2.61, 2.91, 3.22, 3.51, 3.93, 4.43, 5.22, 6.84] |  | Serum |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 169 | s-transferriinireseptori,liukoinen | mg/l | 129 | 0 | [0.91, 1.1, 1.18, 1.23, 1.33, 1.45, 1.78, 2.23, 3.16] |  | Serum |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 170 | transferiininrautakyllästeisyys,seerumista,paastotilassa | osuus | 236 | 0 | [0.09, 0.15, 0.19, 0.22, 0.25, 0.29, 0.31, 0.35, 0.44] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 171 | transferiininrautakyllästeisyys,seerumista,paastotilassa | paketti | 16 | 0 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 172 | transferiininrautakyllästeisyys,seerumista,paastotilassa |  | 205 | 3.41 | [0.1, 0.13, 0.16, 0.18, 0.22, 0.26, 0.29, 0.33, 0.41] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 173 | transferriininrautakyllästeisyys | % | 1179 | 0 | [8.18, 11.78, 15.27, 18.31, 21.03, 24.15, 27.59, 31.86, 39.21] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 174 | transferriininrautakyllästeisyys |  | 26 | 100 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 175 | transferriininrautakyllästeisyys(fp-) | % | 596 | 0 | [10.58, 15.04, 18.08, 21, 24.94, 28.56, 32.22, 37.06, 43.51] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 176 | transferriininrautakyllästeisyys(fp-) |  | 16 | 100 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 177 | transferriininrautakyllästeisyys␤ | % | 1453 | 0 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 178 | transferriininrautakyllästeisyys␤ |  | 5 | 100 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 179 | transferriinirautakyllästeisyys | % | 233 | 0 | [8.52, 13.59, 16.32, 21.55, 25.9, 28.62, 32.3, 36.31, 42.32] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |
| 180 | transferriinireseptori,liukoinen | mg/l | 196 | 0 | [1.64, 2.13, 2.4, 2.6, 2.79, 2.98, 3.16, 3.56, 4.22] |  |  |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 181 | transferriinireseptori,liukoinen |  | 48 | 100 |  |  |  |  | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | FALSE |
| 182 | transferriinisaturaatio | % | 292 | 0 | [6.88, 9.89, 12.73, 16.14, 19.09, 22.3, 26.09, 32.09, 39.32] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma | FALSE |

