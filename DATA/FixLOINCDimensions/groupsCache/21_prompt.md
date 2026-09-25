[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

**Those guesses exist only to fetch the candidate list. They have already done their job, and they carry no authority over your decision.** The earlier pass was told to write a name whenever the code gave it anything at all to work with, because a near-miss still retrieves the right neighbourhood of concepts while silence retrieves nothing. So a guess may be a careful reading or a shot in the dark, and nothing marks which. Use it as a pointer to where in the vocabulary to look, never as an answer to confirm. **Decide from the row's own `TEST_NAME`, `LongName`, `UNIT` and `deciles`.** When the row's evidence and the guess disagree, the row wins.

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

**The rows table** — one row per local lab test/unit combination:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty, and may be wrong.
- `unit_share` — what percentage of this `TEST_NAME`'s records carry this row's `UNIT`.
- `n` — number of records.
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess, which is what the search was run on. A search query, not a hypothesis you owe any deference to: it was written under instructions to guess rather than stay silent, so its confidence is not calibrated and a fluent name may rest on very little. When it is a panel name, the earlier pass judged the code to order a bundle rather than report one result — check that against the code yourself.

# How to read the evidence

A row is one **`TEST_NAME` + `UNIT`** combination, and that pair is what you are naming. Two rows of the same code with different units are two different observations and may well belong to two different LOINC concepts. Decide each row on its own.

**The name is the source of truth.** `prefix_meaning` and `suffix_meaning` were derived from the `TEST_NAME` string by an earlier step, so when a name is misspelled, truncated or locally invented, the decoded prefix and suffix are wrong in exactly the same way. Treat them as extra information that can confirm what the name says — never as something that outranks it. The specimen in particular is often spelled out as a Finnish word rather than carried by a prefix: `veri` = blood, `seerumi` = serum, `plasma` = plasma, `virtsa` = urine, `likvori` = cerebrospinal fluid, `uloste` = feces, `sylki` = saliva. `c-reaktiivinenproteiini,pikatesti,veri` names blood and has no decoded prefix at all — and its leading `c-` is the start of "C-reactive", not a specimen code.

**Missing values are not evidence.** `p_missing` describes this extract, not the laboratory test: a row with no values is a row where the numbers were not recorded or not carried through. Never conclude "no numbers, therefore qualitative". A test is qualitative when the CODE says so — the `-O` suffix, a `LongName` naming a qualitative or screening test, a component only ever reported as detected/not-detected.

**Never borrow from another row.** The rows are grouped by string similarity of `TEST_NAME`, so a group is a bag of codes that merely look alike. A neighbouring row's unit is not evidence about this row, and the same code can also appear in another group carrying units you cannot see here — so the units visible around you are not the units this code uses. Do not take a unit, a quantity or an answer from a sibling row, not even from a row whose `TEST_NAME` is identical.

**What you may conclude depends on what the row actually has.** The `evidence_level` column states it. Every row has a name; the label says what is there *in addition*:

| `evidence_level` | what the row has | what you may do |
|---|---|---|
| `name+unit+values` | a unit and a value distribution | The strongest case. If the values contradict the unit, distrust the **unit** — units are typed by hand at hundreds of source systems and are often wrong, especially at a low `unit_share` — and decide as if the unit were absent. |
| `name+unit` | a unit, no values | Trust the unit. It is the only quantity evidence there is, and it is usually right. |
| `name+values` | values, no unit | Read the quantity off the magnitudes. Creatinine at 60-110 is µmol/l and takes `[Moles/volume]`; the same analyte at 0.6-1.2 is mg/dl and takes `[Mass/volume]`. |
| `name` | neither | **You cannot fix the quantity.** Do not guess one and do not copy a sibling. Choose a concept only when the name alone settles it — a panel, which carries no property at all, or an analyte that has exactly one LOINC form. Otherwise **leave `omop_concept_id` empty**. An honest gap is worth more than a concept resting on nothing. |

**Some units are ratios, not concentrations.** `mmol/mol` is HbA1c IFCC, a substance ratio. `mg/mmol` is an albumin/creatinine ratio. `ml/min/173m2` is eGFR, a rate per body surface area. `%` is ambiguous by nature: it may be a fraction of a cell population, a fraction of a total mass, or activity as a percentage of normal.

**A repeated lowest decile is a detection limit, not a measurement.** When the first deciles are the same round number — `[5, 5, 6.2, 8.3, ...]` — the assay is censored at that floor and everything below was reported as "<5". Read the floor as the assay's sensitivity rather than the population's real low end: a CRP censored at 5 mg/l is an ordinary CRP, while a high-sensitivity assay reads down to about 0.1 mg/l, so that floor argues *against* a high-sensitivity concept.

# How to decide

For each row:

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
2. **Pick the candidate that matches that reading**, and return its `omop_concept_id`. The unit and the values decide between candidates that differ only in property: `mmol/l` takes `[Moles/volume]`, `g/l` takes `[Mass/volume]`, `U/l` takes `[Enzymatic activity/volume]`. The specimen comes from the name — a decoded prefix where there is one, a Finnish specimen word otherwise; LOINC's `Serum or Plasma` is the right term for most routine chemistry, and fasting is not part of the specimen (`fS` is still serum).
3. **Precision must be earned by the name.** LOINC holds both a plain and a qualified concept for most tests. Take the **more precise** candidate whenever the row's name positively states the qualifier — `-Vi` really does say culture, `pikatesti` really does say a rapid test, `dU` really does say a 24-hour collection, `herkka` really does say high sensitivity. Take the plainer candidate when the name does not state it.

   The error to avoid is **inventing** a qualifier, not being specific. Measured against the curated Finnish mappings, this step added a method the reference leaves blank 59 times (usually `Automated count` on a bare blood-count code), took `--trough` variants for plain drug levels, and narrowed `Serum or Plasma` to `Capillary blood` on codes that said no such thing. Of every qualifier you are about to accept, ask: **which characters of this code say so?** If you cannot point at them, take the plainer concept.
4. **A guess that is itself a real concept is weak evidence, never an instruction.** If `loinc_name_guess` appears in the candidate table as an exact name at a score of 1.000, the earlier pass — reading this same row — happened to write the exact name of a concept that exists. That is mildly reassuring and nothing more: the earlier pass writes a name for almost every code it can read anything out of, so landing on a real name can be recognition or coincidence. Never adopt a candidate *because* it equals the guess. Take a different candidate, including a more precise one, whenever the row's own name, unit and values support it better — and take none at all if none fits, however well the guess matched.
5. **When two or more candidates still fit equally well**, prefer a candidate with a `top2000` rank. That list is LOINC's own recommendation for what laboratories should map to, so a concept on it is the intended target and a near-duplicate off it usually is not. It breaks ties and nothing more: a top-2000 concept in the wrong specimen or the wrong units is still the wrong answer.
6. **Leave `omop_concept_id` empty when no candidate is right.** That is a correct, useful answer — it says "this code has no match in what the search returned", which is a fact the next iteration can act on. Common reasons: the code is too truncated or garbled to identify; it is a local administrative or non-laboratory code; or the search simply did not return the concept you know is right.
7. **Never return an id that is not in the candidate table.** Not one you remember, not one you derive from a LOINC code, not a plausible-looking number. Ids that are not in the table are discarded and the row is logged as unanswered, so inventing one only loses the row.

Specific things to watch:

- **A panel is not its components.** If the code orders a bundle, the answer is a panel concept, not one of the bundled analytes: `B-PVK` (perusverenkuva, the basic blood count) and `B-TVK` (taydellinen verenkuva, the complete count with differential) are panels, not hemoglobin. Match the panel's breadth to the code: a basic count is not the same concept as a count with a differential. Conversely, do not map a single reported result to a panel concept just because a panel candidate scored well.
- **Deprecated near-duplicates are already filtered out** of the candidate list — every candidate is a standard, current concept — so you never need to judge validity, only fit.
- **The group is a bag of look-alike codes, not a set of equivalent ones.** It was built by string similarity, so it mixes genuinely different tests whose names happen to resemble each other. Answer every row from its own name, unit and values; never give rows one id because they sit together.
- **A row whose guess was empty can still be mapped** — the pooled list may hold the concept its own name points to. Map it on that row's own evidence, though, never because a neighbouring row was mapped there.

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `omop_concept_id` — the chosen concept's id, copied from the candidate table. Empty if no candidate is right.
- `omop_concept_name` — that candidate's `omop_concept_name`, copied verbatim. Used only to cross-check that the id you copied is the concept you meant; leave it empty when the id is empty.

Then justify and grade what you chose:

- `reasoning` — why each part of the name you chose is right, as **one clause per part, separated by ` ; `**. Each clause names the part and then the evidence it rests on, pointing at the specific characters of the row that carry it. Cover the component, the bracketed property, the specimen, and the method when the name has one. Keep it terse — this is a justification trail, not prose:

      <component> bcs <evidence> ; <[property]> bcs <evidence> ; in <system> bcs <evidence> ; by <method> bcs <evidence>

  Where a part rests on nothing in the row, say that instead of inventing a reason — "no specimen stated in the code" is a useful thing for a reader to find here.

  **When you choose no concept, `reasoning` still matters — it is the only thing you leave behind.** Say what blocked you, specifically: the code is too garbled to identify; it is not a laboratory test; the search returned nothing for this analyte; the candidates were all the wrong specimen; the evidence cannot settle the quantity. "Nothing fitted" is not an answer. A reader must be able to tell a code that is unidentifiable from one the search simply failed on, because those need opposite fixes.
- `certainty` — `high`, `medium` or `low`: how sure you are, on all the evidence together, that this concept is the right one for this row. Weigh the parts by what a wrong answer would cost: a doubtful analyte makes the mapping useless, while an unstated method is a smaller error. A row whose `evidence_level` is `name` should rarely be `high`, since nothing fixes its quantity. Use `low` freely — these are read downstream to decide which mappings can be trusted without review, so a `high` you cannot defend is worse than an honest `low`. Leave it empty when you chose no concept.

Return an entry for EVERY row, including ones you leave unmapped.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which rows you could map and which you could not, where the candidate list was missing the concept you knew was right, where the earlier pass's guess sent the search astray, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 21.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3015399 | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | 0.941 |  |
| 3046569 | Transferrin receptor.soluble [Moles/volume] in Serum or Plasma | 0.901 |  |
| 3004789 | Transferrin [Mass/volume] in Serum or Plasma | 0.853 | 809 |
| 44816699 | Transferrin receptor.soluble/log Ferritin index [Mass Ratio] in Serum or Plasma | 0.841 |  |
| 40763571 | Iron/Transferrin [Ratio] in Serum or Plasma | 0.825 |  |
| 3023017 | Iron/Transferrin [Mass Ratio] in Serum or Plasma | 0.823 |  |
| 3002903 | Transferrin [Moles/volume] in Serum or Plasma | 0.820 | 809 |
| 648872 | Transferrin [Measurement] in Serum or Plasma | 0.807 |  |
| 3009814 | Iron saturation [Molar fraction] in Serum or Plasma | 0.800 | 192 |
| 3000185 | Iron saturation [Mass Fraction] in Serum or Plasma | 0.782 |  |
| 3001122 | Ferritin [Mass/volume] in Serum or Plasma | 0.775 | 153 |
| 46235736 | Interleukin 2 Receptor Soluble [Mass/volume] in Serum or Plasma | 0.760 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 155 | fp-transferriininrautakyllästeisyys | % | 100% | name+unit+values | 3193 | 0 | [8.97, 13, 16.76, 20.1, 23.32, 26.3, 29.57, 33.75, 41.18] |  | Fasting plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 156 | fp-transferriininrautakyllästeisyys |  | 0% | name | 13 | 84.62 |  |  | Fasting plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 157 | fp-transferriininrautasaturaatio | % | 100% | name+unit+values | 401 | 0 | [8.17, 12.08, 15.12, 17.38, 20.04, 22.98, 27.38, 31.01, 39.99] |  | Fasting plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 158 | fs-transferiininrautakyllästeisyys |  | 100% | name+values | 2368 | 65.54 | [0.08, 0.13, 0.16, 0.19, 0.23, 0.26, 0.3, 0.34, 0.41] |  | Fasting serum |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 159 | fs-transferiininrautakyllästeisyys,paastotilassa |  | 100% | name+values | 139 | 0 | [0.07, 0.12, 0.15, 0.19, 0.22, 0.24, 0.28, 0.33, 0.39] |  | Fasting serum |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 160 | fs-transferriininrautakyllästeisyys | % | 39% | name+unit+values | 144 | 0 | [5.6, 8.49, 12.38, 16.94, 20.5, 24.07, 26.84, 31.55, 40] |  | Fasting serum |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 161 | fs-transferriininrautakyllästeisyys |  | 61% | name+values | 230 | 1.74 | [6.96, 10.51, 13.75, 17.95, 20.84, 24.42, 28.14, 32.22, 47.21] |  | Fasting serum |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 162 | p-transferriininrautakyllästeisyys | % | 100% | name+unit+values | 288 | 0 | [7.78, 11.72, 15.31, 18.47, 21.76, 25.36, 29.49, 34.05, 40.39] |  | Plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 163 | p-transferriininrautakyllästeisyys,fp-fe/tr,fp-fe/tran,fp-fe/trans | % | 100% | name+unit+values | 628 | 0 | [9.32, 12.95, 14.99, 17.87, 20.98, 23.9, 27.48, 31.74, 38.07] |  | Plasma |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 164 | p-transferriinireseptori | mg/l | 89% | name+unit+values | 1449 | 0 | [0.64, 0.72, 0.81, 0.91, 1.01, 1.14, 1.3, 1.54, 1.97] |  | Plasma |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 165 | p-transferriinireseptori |  | 11% | name | 176 | 100 |  |  | Plasma |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 166 | p-transferriinireseptori,liukoinen | mg/l | 97% | name+unit+values | 1328 | 0 | [0.8, 1.04, 1.37, 1.95, 2.49, 2.95, 3.61, 4.4, 5.84] |  | Plasma |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 167 | p-transferriinireseptori,liukoinen |  | 3% | name | 42 | 100 |  |  | Plasma |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 168 | s-transferriinireseptori | mg/l | 100% | name+unit+values | 1934 | 0 | [2.3, 2.61, 2.91, 3.22, 3.51, 3.93, 4.43, 5.22, 6.84] |  | Serum |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 169 | s-transferriinireseptori,liukoinen | mg/l | 100% | name+unit+values | 129 | 0 | [0.91, 1.1, 1.18, 1.23, 1.33, 1.45, 1.78, 2.23, 3.16] |  | Serum |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 170 | transferiininrautakyllästeisyys,seerumista,paastotilassa | osuus | 52% | name+unit+values | 236 | 0 | [0.09, 0.15, 0.19, 0.22, 0.25, 0.29, 0.31, 0.35, 0.44] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 171 | transferiininrautakyllästeisyys,seerumista,paastotilassa | paketti | 4% | name+unit | 16 | 0 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 172 | transferiininrautakyllästeisyys,seerumista,paastotilassa |  | 45% | name+values | 205 | 3.41 | [0.1, 0.13, 0.16, 0.18, 0.22, 0.26, 0.29, 0.33, 0.41] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 173 | transferriininrautakyllästeisyys | % | 98% | name+unit+values | 1179 | 0 | [8.18, 11.78, 15.27, 18.31, 21.03, 24.15, 27.59, 31.86, 39.21] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 174 | transferriininrautakyllästeisyys |  | 2% | name | 26 | 100 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 175 | transferriininrautakyllästeisyys(fp-) | % | 97% | name+unit+values | 596 | 0 | [10.58, 15.04, 18.08, 21, 24.94, 28.56, 32.22, 37.06, 43.51] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 176 | transferriininrautakyllästeisyys(fp-) |  | 3% | name | 16 | 100 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 177 | transferriininrautakyllästeisyys␤ | % | 100% | name+unit | 1453 | 0 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 178 | transferriininrautakyllästeisyys␤ |  | 0% | name | 5 | 100 |  |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 179 | transferriinirautakyllästeisyys | % | 100% | name+unit+values | 233 | 0 | [8.52, 13.59, 16.32, 21.55, 25.9, 28.62, 32.3, 36.31, 42.32] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |
| 180 | transferriinireseptori,liukoinen | mg/l | 80% | name+unit+values | 196 | 0 | [1.64, 2.13, 2.4, 2.6, 2.79, 2.98, 3.16, 3.56, 4.22] |  |  |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 181 | transferriinireseptori,liukoinen |  | 20% | name | 48 | 100 |  |  |  |  | Soluble transferrin receptor [Mass/volume] in Serum or Plasma |
| 182 | transferriinisaturaatio | % | 100% | name+unit+values | 292 | 0 | [6.88, 9.89, 12.73, 16.14, 19.09, 22.3, 26.09, 32.09, 39.32] |  |  |  | Transferrin saturation [Molar ratio] in Serum or Plasma |

