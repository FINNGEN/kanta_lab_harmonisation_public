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
Here is group 129.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 21493451 | Spirometry panel | 1.000 |  |  0 |       0 |
| 3008607 | Semen analysis panel | 1.000 |  |  0 |       0 |
| 40757362 | Semen analysis fertility panel | 0.896 |  |  0 |       0 |
| 3013512 | EKG study | 0.778 |  | 10 | 506,024 |
| 3030682 | Semen analysis post vasectomy panel | 0.777 |  |  0 |       0 |
| 3011482 | Spermatozoa motility and count panel | 0.772 |  |  0 |       0 |
| 21493450 | Pulmonary function test panel | 0.770 |  |  0 |       0 |
| 40762373 | Cardiac stress echo study | 0.765 |  |  0 |       0 |
| 3049875 | Spermatozoa morphology panel | 0.755 |  |  0 |       0 |
| 40758532 | Asthma tracking panel | 0.753 |  |  0 |       0 |
| 3964861 | Semen and urine analysis fertility panel - Specimen | 0.752 |  |  0 |       0 |
| 21494996 | Respiratory assessment panel | 0.751 |  |  0 |       0 |
| 3009203 | Cardiac echo study Procedure | 0.743 |  |  0 |       0 |
| 3000492 | Spirometry study | 0.727 |  |  5 |  69,533 |
| 40757584 | Semen analysis test method | 0.726 |  |  0 |       0 |
| 36031657 | Pulmonary vasodilator test panel | 0.723 |  |  0 |       0 |
| 3010322 | Cardiac catheterization study | 0.717 |  |  0 |       0 |
| 21493223 | Uroflowmetry panel | 0.708 |  |  0 |       0 |
| 3033688 | Peak flow meter device panel | 0.703 |  |  0 |       0 |
| 3045149 | Reason for lab test in Semen | 0.702 |  |  0 |       0 |
| 3014424 | Cardiac echo study Procedure stress method | 0.696 |  |  0 |       0 |
| 3009544 | EKG Study overall | 0.674 |  |  0 |       0 |
| 1002224 | Polysomnography panel | 0.670 |  |  1 |  25,006 |
| 3003481 | Cardiac echo study Transducer site Narrative | 0.668 |  |  0 |       0 |
| 3002200 | Cardiac echo study Transducer site | 0.665 |  |  0 |       0 |
| 3034937 | Oxygen saturation device panel | 0.665 |  |  0 |       0 |
| 3015588 | Electromyogram study | 0.664 |  |  0 |       0 |
| 3047332 | Spermatozoa IgA and IgG and IgM panel - Serum | 0.664 |  |  0 |       0 |
| 46235184 | Cardiac stress test EKG study Type | 0.660 |  |  0 |       0 |
| 3023550 | FEV1 --post bronchodilation | 0.658 |  |  0 |       0 |
| 3022830 | FEV1 Predicted --post bronchodilation | 0.657 |  |  0 |       0 |
| 42868462 | FEF 25-75% --post bronchodilation | 0.655 |  |  0 |       0 |
| 3005025 | FEV1 --pre bronchodilation | 0.653 |  |  0 |       0 |
| 3019480 | FEV1 Predicted --pre bronchodilation | 0.652 |  |  0 |       0 |
| 36305632 | Microbiology CNAMTS panel - Semen | 0.646 |  |  0 |       0 |
| 3039856 | Temperature of Skin | 0.594 |  |  0 |       0 |
| 3043501 | Temperature of Skin palpation | 0.567 |  |  0 |       0 |
| 3016946 | Physical findings sensation | 0.563 |  |  0 |       0 |
| 21490584 | Finger temperature | 0.554 |  |  0 |       0 |
| 1988377 | Body temperature - Hand surface | 0.549 |  |  0 |       0 |
| 21490591 | Skin temperature --in microenvironment | 0.545 |  |  0 |       0 |
| 21490788 | Temperature difference | 0.540 |  |  0 |       0 |
| 21490585 | Toe temperature | 0.534 |  |  0 |       0 |
| 21490688 | Body surface temperature | 0.532 |  |  0 |       0 |
| 3020891 | Body temperature | 0.520 | 138 |  9 |  93,063 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1739 | pt-fvsirod |  | 396 | 100 |  |  | Patient |  |  | FALSE |
| 1740 | pt-fvspdo6 |  | 226 | 100 |  |  | Patient |  |  | FALSE |
| 1741 | pt-fvspid |  | 451 | 100 |  |  | Patient |  | Spirometry panel | TRUE |
| 1742 | pt-fvspidl |  | 4654 | 100 |  |  | Patient |  | Spirometry panel | TRUE |
| 1743 | pt-fvspido |  | 17640 | 98.28 | [1, 1, 1, 1, 1, 1, 1, 1, 1] |  | Patient |  | Spirometry panel | TRUE |
| 1744 | pt-fvspio |  | 1411 | 100 |  |  | Patient |  | Spirometry panel | TRUE |
| 1745 | pt-fvspird | form | 18 | 100 | [30622, 77088.15, 106752.5, 134032.5, 166516.57, 190349.45, 230673.1, 250553.8, 270325] |  | Patient |  | Spirometry W bronchodilator panel | TRUE |
| 1746 | pt-fvspird |  | 7795 | 100 |  |  | Patient |  | Spirometry W bronchodilator panel | TRUE |
| 1747 | pt-fvspiro | form | 26 | 100 |  |  | Patient |  | Spirometry W bronchodilator panel | TRUE |
| 1748 | pt-fvspiro |  | 1641 | 82.39 | [1, 1, 1, 1, 1, 1, 1, 1, 1] |  | Patient |  | Spirometry W bronchodilator panel | TRUE |
| 1749 | pt-sper-1 | u/nke | 5 | 0 |  | Pt-Siemennestetutkimus, suppea | Patient |  | Semen analysis panel | TRUE |
| 1750 | pt-sper-1 |  | 714 | 98.74 |  | Pt-Siemennestetutkimus, suppea | Patient |  | Semen analysis panel | TRUE |
| 1751 | pt-sper-2 | form | 39 | 100 |  | Pt-Siemennestetutkimus, laaja | Patient |  | Semen analysis panel | TRUE |
| 1752 | pt-sper-2 |  | 480 | 100 |  | Pt-Siemennestetutkimus, laaja | Patient |  | Semen analysis panel | TRUE |
| 1753 | pt-sper-3 |  | 663 | 100 |  | Pt-Siemennestetutkimus, laaja lisätutkimuksin | Patient |  | Semen analysis panel | TRUE |
| 1754 | pt-sperma |  | 159 | 100 |  |  | Patient |  | Semen analysis panel | TRUE |
| 1755 | pt-spird-x |  | 8902 | 100 |  |  | Patient |  |  | FALSE |
| 1756 | pt-spirlau |  | 493 | 100 |  |  | Patient |  |  | FALSE |
| 1757 | pt-spiro-x |  | 775 | 100 |  |  | Patient |  |  | FALSE |
| 1758 | pt-spirob, |  | 746 | 100 |  |  | Patient |  |  | FALSE |
| 1759 | pt-spirob,tk |  | 986 | 100 |  |  | Patient |  |  | FALSE |
| 1760 | pt-spirom |  | 814 | 100 |  |  | Patient |  | Spirometry W bronchodilator panel | TRUE |
| 1761 | pt-spiromd |  | 547 | 100 |  |  | Patient |  | Spirometry W bronchodilator panel | TRUE |
| 1762 | pt-sppesu |  | 141 | 100 |  |  | Patient |  |  | FALSE |
| 1763 | pt-st-temp |  | 111 | 100 |  | Pt-Terminen tuntokynnysmittaus | Patient |  | Temperature sensation study | TRUE |
| 1764 | pt-sydperg |  | 117 | 100 |  |  | Patient |  |  | FALSE |
| 1765 | pt-sydperq |  | 923 | 100 |  |  | Patient |  |  | FALSE |
| 1766 | pt-sydrasq |  | 197 | 100 |  |  | Patient |  |  | FALSE |
| 1767 | pt-sydrtuä |  | 139 | 100 |  |  | Patient |  |  | FALSE |
| 1768 | pt-sydänuä |  | 3154 | 100 |  |  | Patient |  | Echocardiogram study | TRUE |

