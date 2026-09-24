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
Here is group 126.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3008799 | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose glucose | 1.000 |  |  1 |       228 |
| 3015024 | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 1.000 | 928 | 25 |     6,546 |
| 3016701 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 1.000 | 884 | 37 |     8,302 |
| 3018251 | Fasting glucose [Moles/volume] in Serum or Plasma | 1.000 | 332 | 42 | 1,996,657 |
| 3020491 | Glucose [Moles/volume] in Blood | 1.000 | 13 | 11 |     5,703 |
| 3019047 | Glucose [Moles/volume] in Serum or Plasma --2.5 hours post dose glucose | 0.971 |  |  0 |         0 |
| 3034101 | Glucose [Moles/volume] in Serum or Plasma --2.6 hours post dose glucose | 0.970 |  |  0 |         0 |
| 3036895 | Glucose [Moles/volume] in Serum or Plasma --1.5 hours post dose glucose | 0.969 |  |  0 |         0 |
| 46236950 | Fasting glucose [Moles/volume] in Serum, Plasma or Blood | 0.965 |  |  0 |         0 |
| 3006520 | Glucose [Moles/volume] in Serum or Plasma --2.3 hours post dose glucose | 0.965 |  |  0 |         0 |
| 3007619 | Glucose [Moles/volume] in Serum or Plasma --1.6 hours post dose glucose | 0.963 |  |  0 |         0 |
| 3003912 | Glucose [Moles/volume] in Serum or Plasma --1.3 hours post dose glucose | 0.962 |  |  0 |         0 |
| 3014194 | Glucose [Moles/volume] in Serum or Plasma --40 minutes post dose glucose | 0.958 |  |  0 |         0 |
| 3012413 | Glucose [Moles/volume] in Serum or Plasma --2 hours post meal | 0.955 | 1141 |  7 |     6,457 |
| 3018582 | Glucose [Moles/volume] in Serum or Plasma --20 minutes post dose glucose | 0.954 |  |  0 |         0 |
| 3023228 | Glucose [Moles/volume] in Serum or Plasma --45 minutes post dose glucose | 0.952 |  |  0 |         0 |
| 3028247 | Glucose [Mass/volume] in Serum or Plasma --30 minutes post dose glucose | 0.951 |  |  0 |         0 |
| 3040659 | Glucose [Moles/volume] in Serum or Plasma --1 hour post meal | 0.951 | 1362 |  0 |         0 |
| 3009877 | Glucose [Moles/volume] in Serum or Plasma --15 minutes post dose glucose | 0.950 |  |  0 |         0 |
| 3037432 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 100 g glucose PO | 0.950 | 872 |  0 |         0 |
| 40757389 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose insulin IV | 0.948 |  |  0 |         0 |
| 40757394 | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose insulin IV | 0.948 |  |  0 |         0 |
| 3039422 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 75 g glucose PO | 0.947 | 876 |  0 |         0 |
| 3009154 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 100 g glucose PO | 0.947 | 896 |  0 |         0 |
| 3026300 | Glucose [Mass/volume] in Serum or Plasma --2 hours post dose glucose | 0.947 |  |  0 |         0 |
| 3010300 | Glucose [Mass/volume] in Serum or Plasma --1 hour post dose glucose | 0.947 |  |  0 |         0 |
| 3017538 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 75 g glucose PO | 0.946 | 835 |  0 |         0 |
| 3020869 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 50 g glucose PO | 0.946 | 338 |  0 |         0 |
| 3001022 | Glucose [Moles/volume] in Serum or Plasma --10 minutes post dose glucose | 0.946 |  |  0 |         0 |
| 3049428 | Glucose [Moles/volume] in Serum or Plasma --5 minutes post dose glucose | 0.943 |  |  0 |         0 |
| 3037110 | Fasting glucose [Mass/volume] in Serum or Plasma | 0.926 |  |  0 |         0 |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.912 |  |  0 |         0 |
| 3040151 | Glucose [Moles/volume] in Capillary blood | 0.901 |  | 16 |    37,386 |
| 3044242 | Glucose [Moles/volume] in Arterial blood | 0.894 |  |  2 |     4,510 |
| 3038515 | Glucose [Moles/volume] in Venous blood | 0.894 |  |  5 |    28,609 |
| 46235168 | Fasting glucose [Moles/volume] in Blood | 0.893 |  |  6 |     1,021 |
| 3035729 | Glucose [Moles/volume] in Body fluid | 0.881 | 788 |  0 |         0 |
| 3966401 | Fasting glucose [Moles/volume] in Venous blood | 0.877 |  |  0 |         0 |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 0.873 | 4 | 53 | 1,339,897 |
| 3000483 | Glucose [Mass/volume] in Blood | 0.871 |  |  0 |         0 |
| 3006669 | Glucose [Moles/volume] in Serum or Plasma --pre 12 hour fast | 0.869 |  |  0 |         0 |
| 3006893 | Glucose [Moles/volume] in Specimen | 0.841 |  |  0 |         0 |
| 3041651 | Fasting glucose [Moles/volume] in Urine | 0.832 |  |  0 |         0 |
| 3037187 | Fasting glucose [Mass/volume] in Venous blood | 0.822 |  |  0 |         0 |
| 648169 | Glucose [Measurement] in Interstitial fluid | 0.757 |  |  0 |         0 |
| 1617169 | Average glucose [Mass/volume] in Interstitial fluid during Reporting Period | 0.756 |  |  0 |         0 |
| 1469878 | Time below range, low in Reporting Period Interstitial fluid by calculation | 0.735 |  |  0 |         0 |
| 1469495 | Continuous glucose monitoring time in ranges panel | 0.729 |  |  0 |         0 |
| 1989265 | Glucose [Mass/volume] in Interstitial fluid | 0.720 |  |  0 |         0 |
| 1091739 | Glucose standard deviation/Glucose mean in Reporting Period Interstitial fluid by calculation | 0.714 |  |  0 |         0 |
| 1469666 | Time below range, very low in Reporting Period Interstitial fluid by calculation | 0.708 |  |  0 |         0 |
| 1091681 | Glucose [Moles/volume] in Reporting Period mean Interstitial fluid by calculation | 0.697 |  |  0 |         0 |
| 1091284 | Glucose [Moles/volume] in Interstitial fluid | 0.673 |  |  0 |         0 |
| 1470024 | Time above range, high in Reporting Period Interstitial fluid by calculation | 0.670 |  |  0 |         0 |
| 40765155 | Glucose/Insulin [Ratio] in Serum or Plasma | 0.670 |  |  0 |         0 |
| 1617716 | Glucose measurements in range out of Total glucose measurements during reporting period | 0.668 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1710 | -gluk-tbr | % | 118 | 0 | [0, 0, 1, 1, 1, 2, 2.43, 4.38, 6.6] |  |  |  | Glucose time below range [# Ratio] in Interstitial fluid | FALSE |
| 1711 | -gluk-tir | % | 120 | 0 | [25.5, 36.83, 44.57, 51.33, 60.25, 66, 72.25, 76.73, 81.25] |  |  |  | Glucose time in range [# Ratio] in Interstitial fluid | FALSE |
| 1712 | gluk-vieri |  | 309 | 0 | [5.09, 5.42, 5.78, 6.17, 6.7, 7.14, 8, 9.04, 11.23] |  |  |  | Glucose [Moles/volume] in Blood | FALSE |
| 1713 | gluk0 | mmol/l | 143 | 0 | [4.61, 4.8, 4.96, 5.03, 5.21, 5.48, 5.8, 6.24, 6.7] |  |  |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1714 | gluk0 |  | 10 | 20 |  |  |  |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1715 | gluk0min |  | 368 | 0 | [4.92, 5.32, 5.58, 5.75, 5.88, 6, 6.19, 6.58, 7.05] |  |  |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1716 | gluk120min |  | 349 | 0 | [4.3, 5.17, 5.91, 6.49, 7.07, 7.6, 8.72, 10.59, 13.35] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | FALSE |
| 1717 | gluk1h | mmol/l | 282 | 0 | [5.36, 6.29, 6.9, 7.39, 7.93, 8.69, 9.15, 9.75, 11.47] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | FALSE |
| 1718 | gluk2h | mmol/l | 280 | 0 | [4.55, 5.28, 5.68, 6.16, 6.59, 6.99, 7.54, 8.2, 9.44] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | FALSE |
| 1719 | gluk2h |  | 6 | 100 |  |  |  |  |  | FALSE |
| 1720 | gluk30min |  | 362 | 0 | [7.03, 7.79, 8.42, 8.84, 9.36, 9.74, 10.39, 11.2, 12.52] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose glucose | FALSE |
| 1721 | gluk60min |  | 359 | 0 | [5.8, 6.9, 7.62, 8.52, 9.3, 10.21, 11.28, 12.5, 14.53] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | FALSE |
| 1722 | glukbel-vp | mmol/l | 664 | 0 | [4.52, 4.88, 5.29, 5.73, 5.99, 6.35, 6.81, 10.3, 12.64] |  |  |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1723 | glukbel-vp |  | 209 | 100 |  |  |  |  |  | FALSE |
| 1724 | glukoosi120min | mmol/l | 119 | 0 | [4.6, 5.12, 5.49, 5.84, 6.6, 7.25, 8.25, 9.68, 12.44] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | FALSE |
| 1725 | glukr-0 | mmol/l | 144 | 0 | [4.8, 5.18, 5.45, 5.64, 5.93, 6.16, 6.41, 6.64, 7.16] |  |  |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1726 | glukr-1h | mmol/l | 125 | 0 | [6.69, 7.13, 7.9, 8.73, 9.2, 10.36, 11.37, 12.79, 14.55] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | FALSE |
| 1727 | glukr-2h | mmol/l | 144 | 0 | [5.34, 5.79, 6.28, 6.91, 7.51, 8.15, 8.91, 10.16, 11.81] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | FALSE |
| 1728 | glukr0 | mmol/l | 204 | 0 | [4.5, 4.79, 4.89, 5.08, 5.2, 5.47, 5.8, 6.29, 6.89] |  |  |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1729 | glukr0-n | mmol/l | 618 | 0 | [4.67, 4.86, 5.09, 5.3, 5.57, 5.83, 6.03, 6.29, 6.69] |  |  |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1730 | glukr1h | mmol/l | 381 | 0 | [5.67, 6.21, 6.84, 7.42, 7.86, 8.3, 8.82, 9.42, 10.36] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | FALSE |
| 1731 | glukr1valm |  | 333 | 100 |  |  |  |  |  | FALSE |
| 1732 | glukr2h | mmol/l | 780 | 0 | [4.8, 5.34, 5.8, 6.21, 6.59, 7.03, 7.53, 8.19, 9.83] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | FALSE |
| 1733 | glukras-0 | mmol/l | 97 | 0 | [4.6, 4.78, 5, 5.1, 5.2, 5.43, 5.65, 5.9, 6.3] |  |  |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1734 | glukras-0 |  | 30 | 3.33 |  |  |  |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1735 | glukras120 | mmol/l | 153 | 0 | [5.1, 5.47, 5.77, 6.11, 6.54, 6.97, 7.58, 8.12, 9.26] |  |  |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | FALSE |
| 1736 | glukrvalm |  | 2563 | 100 |  |  |  |  |  | FALSE |
| 1737 | glukvieri | mmol/l | 823 | 0 | [5.3, 5.72, 6.09, 6.42, 6.92, 7.6, 8.66, 10.17, 12.3] |  |  |  | Glucose [Moles/volume] in Blood | FALSE |
| 1738 | glukvieri |  | 251 | 1.59 | [5.24, 5.55, 5.81, 6.07, 6.3, 6.79, 7.52, 8.56, 10.76] |  |  |  | Glucose [Moles/volume] in Blood | FALSE |

