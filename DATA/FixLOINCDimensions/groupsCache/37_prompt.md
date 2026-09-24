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
Here is group 37.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1002224 | Polysomnography panel | 1.000 |  |   1 |     25,006 |
| 1469525 | Bacteria identified in Pus by Culture | 1.000 |  |   0 |          0 |
| 3000348 | Leukocyte esterase [Presence] in Urine by Test strip | 1.000 | 65 |   0 |          0 |
| 3000991 | Gas panel - Venous blood | 1.000 |  |   5 |    371,862 |
| 3002032 | Base excess in Venous blood by calculation | 1.000 | 966 |   7 |    189,855 |
| 3002864 | Erythrocytes [#/volume] in Urine by Automated count | 1.000 | 246 |   0 |          0 |
| 3009261 | Glucose [Presence] in Urine by Test strip | 1.000 | 309 |  10 |    946,600 |
| 3009343 | pH of Capillary blood | 1.000 | 865 |   7 |    117,986 |
| 3009508 | Creatinine [Moles/volume] in Urine | 1.000 | 161 |  22 |    532,449 |
| 3011397 | Hemoglobin [Presence] in Urine by Test strip | 1.000 | 72 |   5 |    413,345 |
| 3012544 | pH of Venous blood | 1.000 | 519 |  16 |    197,076 |
| 3014051 | Protein [Presence] in Urine by Test strip | 1.000 | 99 |   3 |    382,676 |
| 3021447 | Carbon dioxide [Partial pressure] in Venous blood | 1.000 | 523 |   3 |    193,244 |
| 3021601 | Nitrite [Presence] in Urine by Test strip | 1.000 | 56 |  10 |    919,087 |
| 3022621 | pH of Urine by Test strip | 1.000 | 59 |  17 |     92,206 |
| 3028626 | Oxygen [Partial pressure] in Capillary blood | 1.000 |  |   4 |     51,613 |
| 3030467 | Casts [#/volume] in Urine by Automated count | 1.000 |  |  20 |    419,520 |
| 3031040 | Bacteria [#/volume] in Urine by Automated count | 1.000 |  |  12 |  1,358,321 |
| 3035350 | Ketones [Presence] in Urine by Test strip | 1.000 | 102 |  11 |    933,706 |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 1.000 |  |   6 |  1,393,084 |
| 40768804 | Tissue Pathology biopsy report | 1.000 |  |   9 |    373,531 |
| 3029187 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma | 0.975 | 516 |  57 |    390,599 |
| 1091714 | HIV 1+2 Ab+HIV1 p24 Ag [Presence] in Serum or Plasma | 0.975 |  |   0 |          0 |
| 36303442 | Epithelial cells [#/volume] in Urine by Automated | 0.974 |  |   0 |          0 |
| 40763086 | Leukocyte esterase [Presence] in Urine by Automated test strip | 0.970 |  |   3 |    687,408 |
| 3021125 | Hepatitis C virus RNA [Presence] in Serum or Plasma by NAA with probe detection | 0.966 | 740 |   1 |      4,893 |
| 3027215 | Base excess standard in Venous blood by calculation | 0.961 |  |   0 |          0 |
| 3008075 | Hepatitis C virus RNA [Presence] in Blood by NAA with probe detection | 0.960 |  |   0 |          0 |
| 3026782 | Osmolality of Urine | 0.956 | 556 |  32 |    252,736 |
| 3030758 | Nitrite [Presence] in Urine by Automated test strip | 0.952 |  |   0 |          0 |
| 648782 | Epstein Barr virus DNA [Presence] in Serum or Plasma by NAA with probe detection | 0.952 |  |   0 |          0 |
| 40760861 | Hemoglobin [Presence] in Urine by Automated test strip | 0.949 |  |   0 |          0 |
| 3012570 | Epstein Barr virus DNA [Presence] in Blood by NAA with probe detection | 0.949 |  |   0 |          0 |
| 1091414 | Leukocyte esterase [Presence] in Urine | 0.947 |  |   0 |          0 |
| 3043849 | Epstein Barr virus DNA [Units/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.945 |  |   3 |     24,736 |
| 40760844 | Ketones [Presence] in Urine by Automated test strip | 0.945 |  |   0 |          0 |
| 3004391 | Epithelial cells [#/volume] in Urine by Manual count | 0.943 |  |   0 |          0 |
| 3019077 | Protein [Presence] in 24 hour Urine by Test strip | 0.943 |  |   0 |          0 |
| 3030260 | Glucose [Presence] in Urine by Automated test strip | 0.942 |  |   0 |          0 |
| 1616796 | Gas panel - Central venous blood | 0.941 |  |   1 |     38,175 |
| 40760007 | HIV 1+2 Ab+HIV1 p24 Ag [Presence] in Serum or Plasma by Immunoassay | 0.938 |  |   1 |        776 |
| 3003327 | Ova and parasites identified in Stool by Light microscopy | 0.937 | 659 |   2 |     29,961 |
| 40760845 | Protein [Presence] in Urine by Automated test strip | 0.935 |  |   0 |          0 |
| 1001833 | Epstein Barr virus DNA [Units/volume] (viral load) in Blood by NAA with probe detection | 0.935 |  |   2 |      1,135 |
| 42870364 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Blood by Immunoassay | 0.934 |  |   0 |          0 |
| 3029435 | Natriuretic peptide.B prohormone N-Terminal [Moles/volume] in Serum or Plasma | 0.934 |  |   0 |          0 |
| 3001695 | Erythrocytes [#/volume] in Urine by Manual count | 0.933 |  |   0 |          0 |
| 3028734 | HIV 1 p24 Ag [Presence] in Serum | 0.931 |  |   0 |          0 |
| 3042804 | Leukocyte esterase+Nitrite [Presence] in Urine by Test strip | 0.931 |  |   0 |          0 |
| 649459 | Epstein Barr virus DNA [log units/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.928 |  |   0 |          0 |
| 1616922 | Base excess in Central venous blood by calculation | 0.927 |  |   0 |          0 |
| 3039402 | Gas panel - Mixed venous blood | 0.927 |  |   0 |          0 |
| 648637 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Immunoassay | 0.926 |  |   0 |          0 |
| 3029879 | Epithelial cells.squamous [#/volume] in Urine by Automated count | 0.926 |  |   3 |    227,666 |
| 3030306 | Epithelial cells.non-squamous [#/volume] in Urine by Automated count | 0.925 |  |  12 |    237,764 |
| 3015451 | Hepatitis C virus RNA [Presence] in Specimen by NAA with probe detection | 0.925 |  |   0 |          0 |
| 46236251 | Leukocyte esterase [Presence] in Body fluid by Automated test strip | 0.925 |  |   0 |          0 |
| 3020647 | HIV 1 p24 Ag [Presence] in Serum or Plasma by Immunoassay | 0.923 |  |   0 |          0 |
| 40760857 | Erythrocytes [#/volume] in Urine by Automated test strip | 0.922 |  |   0 |          0 |
| 3021513 | Carbon dioxide [Partial pressure] in Mixed venous blood | 0.921 |  |   3 |      9,226 |
| 42529224 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma by Immunoassay | 0.919 |  |   0 |          0 |
| 1616989 | Carbon dioxide [Partial pressure] in Central venous blood | 0.918 |  |   0 |          0 |
| 3014258 | Epstein Barr virus DNA [Presence] in Specimen by NAA with probe detection | 0.917 | 1832 |   0 |          0 |
| 3023001 | Base excess in Mixed venous blood by calculation | 0.917 |  |   0 |          0 |
| 1001594 | Epstein Barr virus DNA [log units/volume] (viral load) in Blood by NAA with probe detection | 0.915 |  |   0 |          0 |
| 3000850 | Epithelial cells [#/volume] in Urine | 0.915 |  |  23 |    276,843 |
| 40762866 | Epstein Barr virus DNA [Presence] in Body fluid by NAA with probe detection | 0.915 |  |   0 |          0 |
| 40760140 | CBC W Auto Differential panel - Blood | 0.914 |  |   0 |          0 |
| 3050079 | Epstein Barr virus DNA [#/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.914 |  |   0 |          0 |
| 3047166 | Epithelial cells [#/area] in Urine sediment by Automated count | 0.913 |  |   1 |      1,272 |
| 46236100 | Human papilloma virus 16 DNA [Presence] in Cervix by NAA with probe detection | 0.913 |  |   0 |          0 |
| 1469712 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.913 |  |   0 |          0 |
| 46235476 | Human papilloma virus 18+45 E6+E7 mRNA [Presence] in Cervix by NAA with probe detection | 0.913 |  |   0 |          0 |
| 3007435 | Base excess in Venous cord blood by calculation | 0.912 |  |   0 |          0 |
| 3014305 | Glucose [Presence] in Blood by Test strip | 0.912 |  |   0 |          0 |
| 42870589 | Drugs of abuse panel - Urine by Screen method | 0.911 |  |   0 |          0 |
| 3045874 | Casts [#/area] in Urine sediment by Automated count | 0.911 |  |   0 |          0 |
| 3033106 | HIV 1 p24 Ab [Presence] in Serum | 0.911 |  |   0 |          0 |
| 648911 | Epstein Barr virus DNA [Units/volume] (viral load) in Specimen by NAA with probe detection | 0.911 |  |   0 |          0 |
| 42529473 | Bone density quantitative measurement by DXA panel | 0.911 |  |   0 |          0 |
| 3028893 | Ketones [Presence] in Urine | 0.910 | 217 |   0 |          0 |
| 3042812 | Nitrite [Presence] in Urine | 0.910 |  |   0 |          0 |
| 3002574 | Fasting glucose [Presence] in Urine by Test strip | 0.910 |  |   0 |          0 |
| 42528601 | Human papilloma virus 16 E6+E7 mRNA [Presence] in Cervix by NAA with probe detection | 0.909 |  |   0 |          0 |
| 3013539 | Creatinine [Moles/volume] in 24 hour Urine | 0.908 | 1978 |   0 |          0 |
| 3020416 | Erythrocytes [#/volume] in Blood by Automated count | 0.907 | 9 |   0 |          0 |
| 1616406 | Base excess standard in Central venous blood by calculation | 0.907 |  |   0 |          0 |
| 1761893 | Epstein Barr virus DNA [Log #/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.907 |  |   0 |          0 |
| 40762887 | Creatinine [Moles/volume] in Blood | 0.907 | 283 |   1 |        449 |
| 3007921 | HIV 1 Ag [Presence] in Serum | 0.907 | 785 |   0 |          0 |
| 40761511 | CBC panel - Blood by Automated count | 0.906 |  |   5 |  6,172,064 |
| 3039401 | Hepatitis C virus RNA [Presence] in Body fluid by NAA with probe detection | 0.905 |  |   0 |          0 |
| 3037329 | Epstein Barr virus DNA [#/volume] (viral load) in Blood by NAA with probe detection | 0.905 |  |   0 |          0 |
| 3009531 | Nitrite [Mass/volume] in Urine by Test strip | 0.904 |  |   0 |          0 |
| 3041449 | Collagen crosslinked C-telopeptide [Mass/volume] in Serum or Plasma | 0.904 |  |   3 |      1,772 |
| 3011325 | HIV 1+2 Ab [Presence] in Serum | 0.904 | 442 |   2 |        231 |
| 649308 | Natriuretic peptide.B prohormone N-Terminal [Measurement] in Serum or Plasma | 0.904 |  |   0 |          0 |
| 3018613 | Epstein Barr virus DNA [Presence] in Tissue by NAA with probe detection | 0.902 |  |   0 |          0 |
| 1469767 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Body fluid by Immunoassay | 0.902 |  |   0 |          0 |
| 3029305 | pH of Urine by Automated test strip | 0.901 |  |   0 |          0 |
| 3024629 | Glucose [Mass/volume] in Urine by Test strip | 0.901 |  |   0 |          0 |
| 3002582 | Erythrocytes [#/volume] in Urine | 0.900 |  |  12 |    500,225 |
| 3018753 | Human papilloma virus 18 Ag [Presence] in Specimen | 0.900 |  |   0 |          0 |
| 3012501 | Base excess in Blood by calculation | 0.900 | 84 |   3 |     36,737 |
| 3021257 | Drugs of abuse 5 panel - Urine | 0.899 |  |   0 |          0 |
| 3003344 | Hemoglobin [Presence] in Urine | 0.899 |  |   0 |          0 |
| 1469672 | Bacteria identified in Pus by Anaerobe culture | 0.899 |  |   0 |          0 |
| 40764134 | Human papilloma virus 18 DNA [Presence] in Specimen by NAA with probe detection | 0.898 |  |   0 |          0 |
| 3031015 | pH of 24 hour Urine by Test strip | 0.898 |  |   0 |          0 |
| 3033479 | HIV 1 Ag [Presence] in Serum or Plasma by Immunoassay | 0.898 | 786 |   0 |          0 |
| 3027315 | Oxygen [Partial pressure] in Blood | 0.898 | 87 |   3 |     37,085 |
| 3040890 | HIV 1 p24 Ab [Presence] in Serum or Plasma by Immunoassay | 0.898 |  |   0 |          0 |
| 3019800 | Troponin T.cardiac [Mass/volume] in Serum or Plasma | 0.897 | 291 |  60 |    599,869 |
| 37020511 | Human papilloma virus 18 DNA [Presence] in Genital specimen by NAA with probe detection | 0.896 |  |   0 |          0 |
| 3050934 | HIV 1+Hepatitis C virus RNA [Presence] in Serum or Plasma by NAA with probe detection | 0.895 |  |   0 |          0 |
| 3028923 | Bacteria [#/area] in Urine sediment by Automated count | 0.895 |  |   0 |          0 |
| 42529225 | Natriuretic peptide.B prohormone N-Terminal [Moles/volume] in Serum or Plasma by Immunoassay | 0.895 |  |   0 |          0 |
| 1091200 | Bacteria [#/volume] in Urine | 0.895 |  |   0 |          0 |
| 3049185 | Hemoglobin [Mass/volume] in Urine by Test strip | 0.894 |  |   0 |          0 |
| 1761344 | Epstein Barr virus DNA [Log #/volume] (viral load) in Blood by NAA with probe detection | 0.894 |  |   0 |          0 |
| 649280 | Hepatitis A virus RNA [Presence] in Blood by NAA with probe detection | 0.893 |  |   0 |          0 |
| 3026726 | Creatinine [Moles/volume] in Specimen | 0.893 |  |   2 |        834 |
| 645864 | Human papilloma virus 18+45 E6+E7 mRNA [Presence] in Specimen by NAA with probe detection | 0.893 |  |   0 |          0 |
| 3007696 | Carbon dioxide [Partial pressure] in Venous cord blood | 0.893 | 1204 |   0 |          0 |
| 1469858 | Troponin T.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.893 |  |   0 |          0 |
| 648393 | HIV 1+2 Ab+HIV1 p24 Ag [Measurement] in Serum or Plasma | 0.892 |  |   0 |          0 |
| 46236101 | Human papilloma virus 18 DNA [Presence] in Cervix by NAA with probe detection | 0.891 |  |   0 |          0 |
| 3048402 | Erythrocytes [#/area] in Urine sediment by Automated count | 0.891 |  |   6 |      4,000 |
| 1469656 | Human papilloma virus 18+45 mRNA [Presence] in Vaginal fluid by NAA with probe detection | 0.889 |  |   0 |          0 |
| 3022999 | Human papilloma virus 16 Ag [Presence] in Specimen | 0.889 |  |   0 |          0 |
| 3010329 | Base excess standard in Mixed venous blood by calculation | 0.889 |  |   0 |          0 |
| 3023024 | Carbon dioxide [Partial pressure] in Capillary blood | 0.889 |  |   4 |    121,264 |
| 3003396 | Base excess in Arterial blood by calculation | 0.889 | 389 |   5 |    400,371 |
| 1616438 | pH of Central venous blood | 0.888 |  |   0 |          0 |
| 3006184 | Hemoglobin [Mass/volume] in Capillary blood | 0.888 |  |  10 |     25,042 |
| 40764133 | Human papilloma virus 16 DNA [Presence] in Specimen by NAA with probe detection | 0.888 |  |   0 |          0 |
| 3005897 | Protein [Mass/volume] in Urine by Test strip | 0.886 | 74 |   0 |          0 |
| 3036701 | Epstein Barr virus DNA [Presence] in Bone marrow by NAA with probe detection | 0.886 |  |   0 |          0 |
| 3013290 | Carbon dioxide [Partial pressure] in Blood | 0.885 | 86 |   3 |     36,789 |
| 3040006 | Creatinine [Moles/volume] in 12 hour Urine | 0.885 |  |   0 |          0 |
| 3003159 | Erythrocytes [#/volume] in Body fluid by Automated count | 0.885 | 1726 |   0 |          0 |
| 648515 | Epstein Barr virus DNA [Presence] in Urine by NAA with probe detection | 0.885 |  |   0 |          0 |
| 3037459 | Creatinine [Moles/volume] in Body fluid | 0.885 | 1234 |   0 |          0 |
| 3017250 | Creatinine [Mass/volume] in Urine | 0.884 |  |   0 |          0 |
| 37020661 | Human papilloma virus 16 DNA [Presence] in Genital specimen by NAA with probe detection | 0.884 |  |   0 |          0 |
| 3023539 | Ketones [Mass/volume] in Urine by Test strip | 0.884 |  |   0 |          0 |
| 3012388 | pH of Mixed venous blood | 0.883 |  |   0 |          0 |
| 3037185 | Protein [Presence] in Urine | 0.883 |  |   0 |          0 |
| 3040151 | Glucose [Moles/volume] in Capillary blood | 0.883 |  |  16 |     37,386 |
| 3020650 | Glucose [Presence] in Urine | 0.882 | 116 |   1 |      2,596 |
| 3008116 | Ketones [Moles/volume] in Urine by Test strip | 0.882 | 80 |   7 |      1,504 |
| 3030141 | Hepatitis C virus RNA panel (viral load) in Serum or Plasma by NAA with probe detection | 0.881 |  |   0 |          0 |
| 3019060 | Gas panel - Arterial blood | 0.881 |  |   5 |    122,222 |
| 3001501 | Glucose [Moles/volume] in Capillary blood by Glucometer | 0.881 |  |   3 |      1,900 |
| 3040510 | Creatinine [Moles/time] in 1 hour Urine | 0.879 |  |   0 |          0 |
| 3003129 | Base excess in Capillary blood by calculation | 0.879 | 1953 |   3 |     11,244 |
| 3014918 | Hepatitis C virus RNA [Presence] in Tissue by NAA with probe detection | 0.878 |  |   0 |          0 |
| 3038830 | Creatinine [Moles/volume] in Urine --baseline | 0.878 |  |   0 |          0 |
| 40769783 | Troponin T.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.878 |  |   0 |          0 |
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 0.878 | 154 | 159 |  6,802,841 |
| 3033985 | Epstein Barr virus DNA [Presence] in Mouth by NAA with probe detection | 0.878 |  |   0 |          0 |
| 645339 | Human papilloma virus 16 E6+E7 mRNA [Presence] in Specimen by NAA with probe detection | 0.877 |  |   0 |          0 |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 0.876 | 1 |  51 |  9,024,989 |
| 40768439 | Drugs of abuse 5 panel - Urine by Screen method | 0.875 |  |   0 |          0 |
| 3041849 | Gas panel - Venous cord blood | 0.875 |  |   0 |          0 |
| 3036300 | Epstein Barr virus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.875 |  |   0 |          0 |
| 1091602 | Human papilloma virus DNA [Presence] in Specimen | 0.875 |  |   0 |          0 |
| 3018447 | Hepatitis C virus RNA [Units/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.874 | 531 |   0 |          0 |
| 3006735 | Hepatitis A virus RNA [Presence] in Serum by NAA with probe detection | 0.874 |  |   0 |          0 |
| 3011960 | Natriuretic peptide B [Mass/volume] in Serum or Plasma | 0.874 | 204 |   4 |     97,925 |
| 21494814 | CD8 cells/Lymphocytes in Specimen | 0.873 |  |   1 |      3,725 |
| 1469690 | Human papilloma virus 16 mRNA [Presence] in Vaginal fluid by NAA with probe detection | 0.873 |  |   0 |          0 |
| 3003453 | Glucose [Presence] in Urine by Test strip --30 minutes post dose glucose | 0.873 |  |   0 |          0 |
| 3051593 | INR in Capillary blood by Coagulation assay | 0.873 |  |   0 |          0 |
| 3002388 | Ova and parasites identified in Stool by Parasite sedimentation | 0.873 |  |   0 |          0 |
| 3008770 | Glucose [Moles/volume] in Urine by Test strip | 0.873 | 73 |   0 |          0 |
| 1761482 | Bacteria [#/volume] in Urine by Culture | 0.872 |  |   1 |     39,881 |
| 40760950 | Erythrocytes [#/volume] in Dialysis fluid by Automated count | 0.872 |  |   0 |          0 |
| 37020002 | Multiple myeloma minimal residual disease panel - Bone marrow by Flow cytometry (FC) | 0.872 |  |   0 |          0 |
| 40760892 | CBC W Ordered Manual Differential panel - Blood | 0.872 |  |   3 |    490,892 |
| 3017921 | Human papilloma virus 16+18 Ag [Presence] in Specimen | 0.871 |  |   0 |          0 |
| 3027946 | Carbon dioxide [Partial pressure] in Arterial blood | 0.871 | 205 |   3 |    405,582 |
| 3019493 | Glucose [Presence] in Urine by Test strip --1 hour post dose glucose | 0.871 |  |   0 |          0 |
| 3046787 | Ova and parasites identified in Stool by Trichrome stain | 0.870 |  |   0 |          0 |
| 1469485 | Fungus identified in Pus by Culture | 0.870 |  |   0 |          0 |
| 40762353 | Leukocyte esterase [Presence] in Cerebral spinal fluid by Test strip | 0.870 |  |   0 |          0 |
| 3020126 | Human papilloma virus 16+18 Ag [Presence] in Genital specimen | 0.869 |  |   0 |          0 |
| 1092301 | Erythrocytes [#/volume] in Urine sediment | 0.868 |  |   0 |          0 |
| 40766103 | Ketones [Presence] in Urine by Test strip --1 hour post dose glucose | 0.868 |  |   0 |          0 |
| 42868547 | Human papilloma virus 16 and 18 DNA [Presence] in Specimen by NAA with probe detection | 0.867 |  |   0 |          0 |
| 3036839 | Oxygen [Partial pressure] in Capillary blood --pre treatment | 0.867 |  |   0 |          0 |
| 21491346 | Pathologic casts [#/volume] in Urine by Automated count | 0.867 |  |   0 |          0 |
| 3040526 | Collagen crosslinked C-telopeptide [Moles/volume] in Serum or Plasma | 0.866 |  |   0 |          0 |
| 36204250 | Human papilloma virus 16 DNA [Presence] in Tissue by NAA with probe detection | 0.866 |  |   0 |          0 |
| 42529439 | Human papilloma virus 16 and 18+45 E6+E7 mRNA [Identifier] in Cervix by NAA with probe detection | 0.866 |  |   0 |          0 |
| 36305828 | Drugs of abuse screen W Reflex confirm panel - Urine | 0.865 |  |   0 |          0 |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.865 |  |   2 |     45,357 |
| 3005518 | Ova and parasites identified in Stool by Immune stain | 0.865 |  |   0 |          0 |
| 646531 | Influenza virus A and Influenza virus B and SARS coronavirus 2 and Respiratory syncytial virus Ag panel - Nose by Rapid immunoassay | 0.865 |  |   0 |          0 |
| 36031312 | Human papilloma virus 45 DNA [Presence] in Cervix by NAA with probe detection | 0.865 |  |   0 |          0 |
| 3005589 | Glucose [Presence] in Urine by Test strip --1.5 hours post dose glucose | 0.865 |  |   0 |          0 |
| 42870592 | CBC W Differential panel, method unspecified - Blood | 0.865 |  |   0 |          0 |
| 3021337 | Troponin I.cardiac [Mass/volume] in Serum or Plasma | 0.865 | 113 |  25 |    323,924 |
| 3012744 | Ova and parasites identified in Specimen by Light microscopy | 0.863 | 527 |   0 |          0 |
| 3043614 | Bacteria identified in Aspirate by Culture | 0.863 |  |   1 |         22 |
| 3024354 | Oxygen [Partial pressure] in Venous blood | 0.862 | 665 |   3 |    139,005 |
| 3001298 | Ova and parasites identified in Stool by McMaster concentration | 0.862 |  |   0 |          0 |
| 3020389 | Ova and parasites identified in Stool by Concentration | 0.862 | 257 |   0 |          0 |
| 3027801 | Oxygen [Partial pressure] in Arterial blood | 0.861 | 193 |   3 |    404,986 |
| 648594 | Leukocyte esterase [Measurement] in Urine | 0.861 |  |   0 |          0 |
| 37020818 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with probe detection | 0.861 |  |   0 |          0 |
| 3005448 | Ova and parasites identified in Stool by Iron hematoxylin stain | 0.860 |  |   0 |          0 |
| 1469723 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.859 |  |   0 |          0 |
| 42528835 | Human papilloma virus 16+18+31+33+35+39+45+51+52+56+58+59+66+68 DNA [Presence] in Cervix by NAA with probe detection | 0.859 |  |   0 |          0 |
| 3048529 | Troponin T.cardiac [Mass/volume] in Blood | 0.857 |  |   0 |          0 |
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.857 |  |   0 |          0 |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.856 |  |   0 |          0 |
| 36032027 | Human papilloma virus 56+59+66 DNA [Presence] in Cervix by NAA with probe detection | 0.856 |  |   0 |          0 |
| 1616317 | Hemoglobin [Mass/volume] in Capillary blood by Oximetry | 0.856 |  |   0 |          0 |
| 3966546 | Human papilloma virus 16 DNA [Presence] in Urine by NAA with probe detection | 0.855 |  |   0 |          0 |
| 3006147 | Osmolality of 24 hour Urine | 0.855 |  |   0 |          0 |
| 3039904 | Epithelial cells.renal [#/volume] in Urine by Computer assisted method | 0.854 |  |   0 |          0 |
| 3004361 | Ova and parasites identified in Stool by Kinyoun iron hematoxylin stain | 0.854 |  |   0 |          0 |
| 44787055 | CBC W Differential panel - Cord blood | 0.854 |  |   0 |          0 |
| 40766104 | Ketones [Presence] in Urine by Test strip --3 hours post dose glucose | 0.853 |  |   0 |          0 |
| 3022313 | Gas panel - Capillary blood | 0.853 |  |   3 |     87,120 |
| 36661384 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.853 |  |   0 |          0 |
| 40762355 | Human papilloma virus 18 DNA [Presence] in Cervix by Probe with signal amplification | 0.853 |  |   0 |          0 |
| 1091617 | C reactive protein [Mass/volume] in Serum, Plasma or Blood | 0.853 |  |   0 |          0 |
| 3044495 | Bacteria identified in Tissue by Culture | 0.852 |  |   0 |          0 |
| 36031556 | Human papilloma virus 35+39+68 DNA [Presence] in Cervix by NAA with probe detection | 0.852 |  |   0 |          0 |
| 36031448 | Human papilloma virus 33+58 DNA [Presence] in Cervix by NAA with probe detection | 0.852 |  |   0 |          0 |
| 40768790 | Lung Pathology biopsy report | 0.852 |  |   0 |          0 |
| 3030830 | pH of Body fluid by Test strip | 0.851 |  |   0 |          0 |
| 36306105 | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.851 |  |   0 |          0 |
| 3966513 | Influenza virus A and Influenza virus B and SARS coronavirus 2 RNA panel - Nose by NAA with non-probe detection | 0.851 |  |   0 |          0 |
| 1761840 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Specimen by NAA with probe detection | 0.851 |  |   0 |          0 |
| 3003714 | Bacteria identified in Wound by Culture | 0.851 | 270 |   0 |          0 |
| 3029080 | Hemoglobin [Entitic mass] in Reticulocytes | 0.850 | 1413 |   3 |     12,422 |
| 3035968 | Oxygen [Partial pressure] in Capillary blood --post treatment | 0.850 |  |   0 |          0 |
| 40760141 | CBC W Reflex Manual Differential panel - Blood | 0.850 |  |   0 |          0 |
| 3029162 | Epithelial cells.squamous [#/area] in Urine sediment by Automated count | 0.850 |  |   0 |          0 |
| 1175426 | CD3 cells/Lymphocytes in Blood | 0.850 |  |   5 |      8,032 |
| 40766105 | Ketones [Presence] in Urine by Test strip --4 hours post dose glucose | 0.849 |  |   0 |          0 |
| 36661376 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.849 |  |   0 |          0 |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.849 |  |   0 |          0 |
| 3004097 | Oxygen content in Capillary blood | 0.849 |  |   0 |          0 |
| 46236287 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Pleural fluid by Immunoassay | 0.848 |  |   2 |        218 |
| 3029937 | Albumin [Presence] in Urine by Test strip | 0.848 |  |  10 |    532,964 |
| 3009105 | Erythrocytes [#/volume] in Urine by Test strip | 0.848 | 126 |   0 |          0 |
| 3043088 | Ketones [Presence] in 24 hour Urine | 0.847 |  |   0 |          0 |
| 21494815 | CD4 cells/Lymphocytes in Specimen | 0.847 |  |   5 |      9,464 |
| 3049183 | Collagen crosslinked C-telopeptide [Mass/volume] in Urine | 0.846 |  |   0 |          0 |
| 1988560 | Cocci bacteria [#/volume] in Urine sediment by Automated count | 0.846 |  |   0 |          0 |
| 3965853 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Blood or Marrow by Flow cytometry (FC) | 0.846 |  |   0 |          0 |
| 3000285 | Sodium [Moles/volume] in Blood | 0.846 | 129 |   4 |        967 |
| 3965306 | Troponin T.cardiac [Mass/volume] in 6 hour Serum or Plasma | 0.846 |  |   0 |          0 |
| 3030327 | pH of Capillary blood from Fetus | 0.845 |  |   0 |          0 |
| 3005833 | Gas panel - Blood | 0.845 |  |   0 |          0 |
| 3032431 | Human papilloma virus 16+18+31+33+35+39+45+51+52+56+58+59+68 DNA [Presence] in Specimen by NAA with probe detection | 0.845 |  |   0 |          0 |
| 3017553 | Oxygen [Partial pressure] (8 hour minimum) in Capillary blood | 0.844 |  |   0 |          0 |
| 1989355 | Bacilliform bacteria [#/volume] in Urine sediment by Automated count | 0.843 |  |   0 |          0 |
| 40762354 | Human papilloma virus 16 DNA [Presence] in Cervix by Probe with signal amplification | 0.843 |  |   0 |          0 |
| 3030267 | Hemoglobin [Mass/volume] in Urine by Automated test strip | 0.843 |  |   0 |          0 |
| 21493470 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with non-probe detection | 0.842 |  |   0 |          0 |
| 3006462 | Nitrate [Presence] in Urine | 0.842 |  |   1 |      5,946 |
| 3019383 | Ova and parasites identified in Stool by Baermann concentration | 0.841 |  |   0 |          0 |
| 1469828 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by High sensitivity method | 0.841 |  |   0 |          0 |
| 3022670 | pH of Venous cord blood | 0.841 | 1082 |   2 |        165 |
| 3041412 | Epithelial cells.non-squamous [#/area] in Urine sediment by Automated count | 0.841 |  |   0 |          0 |
| 3051387 | C reactive protein [Mass/volume] in Capillary blood | 0.840 |  |   9 |     30,338 |
| 3030981 | Hyaline casts [#/volume] in Urine by Automated count | 0.840 |  |   7 |     90,835 |
| 3013171 | Leukocyte esterase [Units/volume] in Urine | 0.840 |  |   0 |          0 |
| 36204252 | Human papilloma virus 18 DNA [Presence] in Tissue by NAA with probe detection | 0.840 |  |   0 |          0 |
| 3010251 | Oxygen [Partial pressure] in Body fluid | 0.840 |  |   0 |          0 |
| 40768443 | Skin Pathology biopsy report | 0.840 | 1793 |   1 |     24,633 |
| 3029490 | Free Hemoglobin [Presence] in Urine | 0.839 |  |   0 |          0 |
| 21490848 | Carbon dioxide [Partial pressure] in Pulmonary artery | 0.839 |  |   0 |          0 |
| 3041290 | Carbon dioxide [Partial pressure] adjusted to patient's actual temperature in Venous blood | 0.839 |  |   0 |          0 |
| 43533384 | Drugs of abuse panel - Blood by Screen method | 0.838 |  |   0 |          0 |
| 3023368 | Bacteria identified in Blood by Culture | 0.838 | 131 |   3 |    528,769 |
| 3010156 | C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method | 0.838 | 348 |  19 |     28,709 |
| 3019572 | Troponin T.cardiac [Mass/volume] in Venous blood | 0.836 |  |   0 |          0 |
| 40758490 | Osmolality of Urine--baseline | 0.836 |  |   0 |          0 |
| 43055234 | pH of Vaginal fluid by Test strip | 0.836 |  |   0 |          0 |
| 40761054 | Collagen crosslinked C-telopeptide [Mass/volume] in 24 hour Urine | 0.836 |  |   0 |          0 |
| 3029350 | Yeast [#/volume] in Urine by Automated count | 0.836 |  |   0 |          0 |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.835 |  |   0 |          0 |
| 40768803 | Thyroid Pathology biopsy report | 0.835 |  |   0 |          0 |
| 3039059 | Drugs of abuse 7 and Alcohol and Tricyclics panel - Urine by Screen method | 0.833 |  |   0 |          0 |
| 1175703 | Drugs of abuse panel - Body fluid | 0.833 |  |   0 |          0 |
| 3015736 | pH of Urine | 0.833 | 612 |  11 |    668,794 |
| 3008440 | Collagen crosslinked N-telopeptide [Moles/volume] in Serum | 0.833 |  |   0 |          0 |
| 40768793 | Breast Pathology biopsy report | 0.833 |  |   2 |     13,464 |
| 3005456 | Potassium [Moles/volume] in Blood | 0.832 | 106 |   0 |          0 |
| 36031949 | Influenza virus A and B and SARS-CoV+SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.832 |  |   0 |          0 |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.832 |  |   0 |          0 |
| 3024194 | Bacteria identified in Pleural fluid by Culture | 0.831 |  |   0 |          0 |
| 3050687 | CBC WO Differential panel - Cord blood | 0.831 |  |   0 |          0 |
| 36033643 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.830 |  |   0 |          0 |
| 3040799 | Casts [Presence] in Urine by Automated | 0.830 |  |   0 |          0 |
| 3035854 | CD4+CD45+ cells/100 cells in Blood | 0.829 |  |   0 |          0 |
| 3002619 | Bacteria identified in Specimen by Culture | 0.829 | 39 |   1 |      1,514 |
| 3041694 | Casts type not specified [#/volume] in Urine by Computer assisted method | 0.828 |  |   0 |          0 |
| 3038702 | Sodium [Moles/volume] in Capillary blood | 0.828 |  |   2 |         74 |
| 3020491 | Glucose [Moles/volume] in Blood | 0.828 | 13 |  11 |      5,703 |
| 3029872 | Protein [Mass/volume] in Urine by Automated test strip | 0.828 |  |   0 |          0 |
| 3966204 | Leukemia and lymphoma immunophenotyping in Specimen Document by Flow cytometry (FC) | 0.828 |  |   0 |          0 |
| 3019902 | Methicillin resistant Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.827 | 146 |   2 |    145,674 |
| 46235076 | Creatinine [Moles/volume] in Serum, Plasma or Blood | 0.826 |  |   0 |          0 |
| 3016727 | Bacteria identified in Body fluid by Culture | 0.826 | 1786 |   0 |          0 |
| 44816885 | Collagen crosslinked C-telopeptide [Z-score] in Serum or Plasma | 0.826 |  |   0 |          0 |
| 40758548 | Home drug screening panel - Urine | 0.825 |  |   0 |          0 |
| 3038950 | Acinetobacter sp multidrug resistant identified in Specimen by Organism specific culture | 0.825 |  |   0 |          0 |
| 3032172 | Bacteria [Presence] in Urine by Automated | 0.825 |  |   0 |          0 |
| 3004077 | Glucose [Mass/volume] in Capillary blood | 0.824 |  |   0 |          0 |
| 1616736 | Protein/Creatinine Qualitative in Urine by Test strip | 0.824 |  |   0 |          0 |
| 40771527 | Human papilloma virus E6+E7 mRNA [Presence] in Cervix by NAA with probe detection | 0.824 |  |   1 |      3,405 |
| 1091300 | Yersinia enterocolitica DNA [Presence] in Specimen by NAA with probe detection | 0.822 |  |   0 |          0 |
| 46235078 | Potassium [Moles/volume] in Serum, Plasma or Blood | 0.822 |  |   0 |          0 |
| 3023757 | Gas and Carbon monoxide panel - Venous blood | 0.821 |  |   0 |          0 |
| 3034962 | Glucose [Mass/volume] in Capillary blood by Glucometer | 0.820 |  |   0 |          0 |
| 648549 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.820 |  |   0 |          0 |
| 648940 | C reactive protein [Measurement] in Serum or Plasma | 0.819 |  |   0 |          0 |
| 3039628 | Collagen crosslinked C-telopeptide [Mass/time] in 24 hour Urine | 0.819 |  |   0 |          0 |
| 3040893 | Potassium [Moles/volume] in Capillary blood | 0.819 |  |   4 |        403 |
| 36660607 | Microalbumin [Presence] in Urine by Test strip | 0.817 |  |   0 |          0 |
| 648479 | CLL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.817 |  |   0 |          0 |
| 46236733 | Noninvasive prenatal fetal 18 and 21 aneuploidy panel - Plasma cell-free DNA by Sequencing | 0.817 | 3000 |   0 |          0 |
| 1469831 | Hyaline casts [#/volume] in Urine sediment by Automated count | 0.817 |  |   0 |          0 |
| 3017703 | Fasting glucose [Moles/volume] in Capillary blood by Glucometer | 0.817 |  |   0 |          0 |
| 42869451 | Hemoglobin [Entitic mass] in Reticulocytes by Automated count | 0.817 |  |   0 |          0 |
| 1091454 | Yersinia pseudotuberculosis complex DNA [Presence] in Specimen by NAA with probe detection | 0.816 |  |   0 |          0 |
| 1616954 | Amphetamines panel - Urine by Confirmatory method | 0.816 |  |   0 |          0 |
| 46234968 | Reticulocyte cellular hemoglobin distribution width [Entitic mass] in Blood by calculation | 0.816 |  |   0 |          0 |
| 3043706 | Sodium [Moles/volume] in Arterial blood | 0.816 |  |   0 |          0 |
| 1175629 | Drugs of abuse panel - Hair | 0.816 |  |   0 |          0 |
| 3044942 | Collagen crosslinked N-telopeptide [Mass/volume] in Urine | 0.815 |  |   0 |          0 |
| 46236732 | Noninvasive prenatal fetal 13 and 18 and 21 aneuploidy panel - Plasma cell-free DNA by Sequencing | 0.815 | 3000 |   0 |          0 |
| 3026340 | CD5+CD8+ cells/100 cells in Blood | 0.814 |  |   0 |          0 |
| 3051698 | Osmolality of Urine by calculation | 0.814 |  |   0 |          0 |
| 3035607 | CD8+CD56+ cells/100 cells in Blood | 0.814 |  |   0 |          0 |
| 3965536 | Acute myeloid leukemia minimal residual disease in Bone marrow by Flow cytometry (FC) Narrative | 0.812 |  |   0 |          0 |
| 3042095 | Gas panel - Arterial cord blood | 0.812 |  |   0 |          0 |
| 3036482 | CD8+CD11b+ cells/100 cells in Blood | 0.812 |  |   0 |          0 |
| 3041130 | Mixed cellular casts [#/volume] in Urine by Computer assisted method | 0.812 |  |   0 |          0 |
| 21491345 | Pathologic casts [#/area] in Urine by Automated count | 0.812 |  |   0 |          0 |
| 40768795 | Lymph node Pathology biopsy report | 0.812 |  |   2 |      5,290 |
| 43055143 | Glucose [Moles/volume] in Blood by Automated test strip | 0.811 |  |   0 |          0 |
| 647347 | Glucose [Measurement] in Capillary blood | 0.811 |  |   0 |          0 |
| 46234770 | C reactive protein [Moles/volume] in Serum or Plasma | 0.811 |  |   0 |          0 |
| 3025722 | Staphylococcus sp identified in Specimen by Organism specific culture | 0.811 |  |   0 |          0 |
| 3040501 | WBC casts [#/volume] in Urine by Computer assisted method | 0.811 |  |   0 |          0 |
| 645216 | T-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.810 |  |   0 |          0 |
| 40768792 | Brain Pathology biopsy report | 0.809 |  |   0 |          0 |
| 3034801 | CD8+HLA-DR+ cells/100 cells in Blood | 0.808 | 1735 |   0 |          0 |
| 36031212 | Human papilloma virus 31 DNA [Presence] in Cervix by NAA with probe detection | 0.808 |  |   0 |          0 |
| 648732 | Reticulocyte - RBC Hemoglobin [Entitic mass difference] in Blood | 0.808 |  |   0 |          0 |
| 3964702 | Creatinine [Moles/volume] in Venous blood | 0.808 |  |   0 |          0 |
| 40768796 | Uterus Pathology biopsy report | 0.807 |  |   0 |          0 |
| 1259531 | Human papilloma virus 31+33+52+58 DNA [Presence] in Cervix by NAA with probe detection | 0.807 |  |   0 |          0 |
| 3010169 | Leukocyte esterase [Enzymatic activity/volume] in Leukocytes | 0.807 |  |   0 |          0 |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.806 |  |   0 |          0 |
| 3010421 | pH of Blood | 0.806 | 97 |   4 |     50,330 |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.805 |  |   0 |          0 |
| 21492663 | Yersinia enterocolitica recN gene [Presence] in Stool by NAA with probe detection | 0.805 |  |   0 |          0 |
| 3000330 | Specific gravity of Urine by Test strip | 0.805 | 71 |   4 |     71,773 |
| 3014037 | CD3+CD4+ (T4 helper) cells/100 cells in Blood | 0.805 | 377 |   3 |      7,337 |
| 36032296 | Human papilloma virus 52 DNA [Presence] in Cervix by NAA with probe detection | 0.805 |  |   0 |          0 |
| 3043409 | Potassium [Moles/volume] in Arterial blood | 0.804 |  |   4 |     51,548 |
| 3040135 | pH of Capillary blood adjusted to patient's actual temperature | 0.804 |  |   0 |          0 |
| 21493361 | Gastrointestinal pathogens DNA and RNA panel - Stool by NAA with non-probe detection | 0.804 |  |   0 |          0 |
| 42870370 | Human papilloma virus 31+33+35+39+45+51+52+56+58+59+66+68 DNA [Presence] in Cervix by NAA with probe detection | 0.803 |  |   0 |          0 |
| 37020081 | Noninvasive prenatal fetal aneuploidy and microdeletion panel - Plasma cell-free DNA by Sequencing | 0.803 |  |   0 |          0 |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 0.803 | 5 |  52 |  7,821,326 |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.802 |  |   0 |          0 |
| 3028766 | C reactive protein [Titer] in Serum or Plasma | 0.802 |  |   0 |          0 |
| 3011030 | Human papilloma virus rRNA [Presence] in Specimen by NAA with probe detection | 0.802 |  |   0 |          0 |
| 3035320 | C reactive protein [Mass/volume] in Body fluid | 0.802 |  |   6 |      9,479 |
| 649098 | B-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.801 |  |   0 |          0 |
| 40768446 | Kidney Pathology biopsy report | 0.801 | 1790 |   1 |      3,432 |
| 3033688 | Peak flow meter device panel | 0.801 |  |   0 |          0 |
| 1092282 | Methadone Confirmatory panel - Urine | 0.801 |  |   0 |          0 |
| 3041354 | Potassium [Moles/volume] in Venous blood | 0.800 |  |   2 |     11,069 |
| 40760486 | Osmolality of 12 hour Urine | 0.800 |  |   0 |          0 |
| 40771046 | pH of Peritoneal fluid by Test strip | 0.800 |  |   0 |          0 |
| 1091437 | Human papilloma virus 35+39+51+56+59+66+68 DNA [Presence] in Cervix by NAA with probe detection | 0.800 |  |   0 |          0 |
| 3029361 | Urinalysis dipstick panel - Urine by Automated test strip | 0.800 |  |   0 |          0 |
| 37020245 | Staphylococcus species methicillin resistant identified in Isolate or Specimen by Molecular genetics method | 0.799 |  |   0 |          0 |
| 3001728 | CD8+CD25+ cells/100 cells in Blood | 0.799 |  |   0 |          0 |
| 40768799 | Ovary Pathology biopsy report | 0.799 |  |   0 |          0 |
| 3033173 | Hemoglobin [Presence] in Specimen | 0.798 |  |   0 |          0 |
| 3051825 | Creatinine [Mass/volume] in Blood | 0.798 |  |   0 |          0 |
| 3052990 | Drugs of abuse panel - Meconium | 0.798 |  |   0 |          0 |
| 1469687 | pH of Urine by pH-meter | 0.798 |  |   0 |          0 |
| 43533989 | Noninvasive prenatal fetal aneuploidy panel - Plasma cell-free DNA | 0.797 | 3000 |   0 |          0 |
| 3000965 | C reactive protein [Presence] in Serum or Plasma | 0.795 | 1281 |   0 |          0 |
| 646465 | Collagen crosslinked C-telopeptide [Measurement] in Urine | 0.794 |  |   0 |          0 |
| 3023103 | Potassium [Moles/volume] in Serum or Plasma | 0.794 | 3 |  45 |  7,908,182 |
| 3045592 | Acute leukemia panel - Specimen by Flow cytometry (FC) | 0.793 |  |   0 |          0 |
| 3036941 | Urinalysis complete panel - Urine | 0.792 |  |   0 |          0 |
| 1091745 | Staphylococcus sp identified in Specimen | 0.792 |  |   0 |          0 |
| 646446 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.791 |  |   0 |          0 |
| 37019628 | Gastrointestinal bacterial pathogens panel - Stool by NAA with probe detection | 0.791 |  |   1 |     17,394 |
| 3019977 | pH of Arterial blood | 0.791 | 187 |   8 |    406,844 |
| 3047142 | Chronic leukemia panel - Specimen by Flow cytometry (FC) | 0.790 |  |   0 |          0 |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 0.790 | 4 |  53 |  1,339,897 |
| 3035441 | CD4+HLA-DR+ cells/cells in Blood | 0.790 |  |   0 |          0 |
| 1091245 | Enteric bacteria panel - Stool by NAA with probe detection | 0.789 |  |   0 |          0 |
| 3026681 | Sodium [Moles/volume] in Specimen | 0.789 |  |   0 |          0 |
| 21491103 | Multiple drug resistant gram negative organism [Identifier] in Specimen by Culture | 0.787 |  |   0 |          0 |
| 3028160 | Osmolality of Specimen | 0.786 |  |   0 |          0 |
| 40757357 | Lymphoma panel - Specimen by Flow cytometry (FC) | 0.786 |  |   0 |          0 |
| 3037242 | Nitrite [Mass/volume] in Urine | 0.786 |  |   0 |          0 |
| 37020875 | Human papilloma virus 16+18+31+33+35+39+45+51+52+56+58+59+68 DNA [Presence] in Genital specimen by NAA with probe detection | 0.786 |  |   0 |          0 |
| 40758903 | Hemoglobin [Mass/volume] in Blood by Oximetry | 0.785 |  |   0 |          0 |
| 46236282 | Fetal chromosome 13+18+21+Y aneuploidy [Presence] based on dosage of chromosome-specific cell-free DNA from Maternal plasma | 0.785 |  |   0 |          0 |
| 3044552 | Amphetamine+Methamphetamine [Presence] in Urine | 0.785 |  |   0 |          0 |
| 3044242 | Glucose [Moles/volume] in Arterial blood | 0.785 |  |   2 |      4,510 |
| 3035729 | Glucose [Moles/volume] in Body fluid | 0.784 | 788 |   0 |          0 |
| 40761558 | Sulfites [Presence] in Urine by Test strip | 0.784 |  |   0 |          0 |
| 3037426 | Urobilinogen [Presence] in Urine by Test strip | 0.783 | 134 |   0 |          0 |
| 21492659 | Gastrointestinal pathogens panel - Stool by NAA with probe detection | 0.783 |  |   0 |          0 |
| 3049714 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma | 0.781 |  |   2 |      3,659 |
| 3045414 | Leukocytes [Presence] in Urine | 0.781 |  |   6 |     88,404 |
| 3006893 | Glucose [Moles/volume] in Specimen | 0.781 |  |   0 |          0 |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.780 |  |   0 |          0 |
| 3050126 | Yersinia sp DNA [Identifier] in Specimen by NAA with probe detection | 0.780 |  |   0 |          0 |
| 3034660 | CD4+CD45RO+ cells/100 cells in Blood | 0.780 |  |   0 |          0 |
| 1469562 | Drug toxicology panel - Specimen | 0.779 |  |   0 |          0 |
| 37020690 | Gram negative bacilli identified in Isolate by Organism specific culture | 0.779 |  |   0 |          0 |
| 645112 | Stenotrophomonas maltophilia.multidrug resistant [Presence] in Specimen by Organism specific culture | 0.778 |  |   0 |          0 |
| 46235160 | Noninvasive prenatal fetal aneuploidy and microdeletion panel based on Plasma cell-free+WBC DNA by Dosage of chromosome-specific circulating cell free (ccf) DNA | 0.778 | 3000 |   0 |          0 |
| 3013512 | EKG study | 0.778 |  |  10 |    506,024 |
| 648476 | Amphetamine+Methamphetamine [Measurement] in Urine | 0.778 |  |   0 |          0 |
| 46234777 | Amphetamine+Methamphetamine [Presence] in Urine by Screen method | 0.778 |  |   0 |          0 |
| 36660149 | OxyCODONE and metabolites panel - Urine by Confirmatory method | 0.778 |  |   0 |          0 |
| 647840 | CLL minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.777 |  |   0 |          0 |
| 1617363 | Noninvasive prenatal fetal aneuploidy panel - Plasma cell-free+WBC DNA by Dosage of chromosome-specific cfDNA | 0.777 |  |   0 |          0 |
| 36659811 | Staphylococcus aureus and Methicillin Resistant Staphylococcus aureus identified in Isolate or Specimen by Molecular genetics method | 0.777 |  |   0 |          0 |
| 46235498 | Fetal Chromosome 13+18+21+X+Y aneuploidy [Presence] based on Plasma cell-free DNA by Dosage of chromosome-specific cfDNA | 0.777 |  |   0 |          0 |
| 3013098 | Potassium [Moles/volume] in Specimen | 0.776 |  |   0 |          0 |
| 1260102 | Creatinine [Moles/volume] in Serum or Plasma by LC/MS/MS | 0.776 |  |   0 |          0 |
| 3050898 | Methicillin resistant Staphylococcus aureus [Presence] in Genital specimen by Organism specific culture | 0.776 |  |   2 |      4,590 |
| 37019579 | Human papilloma virus DNA [Presence] in Genital specimen by NAA with probe detection | 0.776 |  |   0 |          0 |
| 36659836 | Osmolality of Urine from Fetus | 0.775 |  |   0 |          0 |
| 37020529 | Human papilloma virus 31+33+35+39+45+51+52+56+58+59+66+68 DNA [Presence] in Genital specimen by NAA with probe detection | 0.775 |  |   0 |          0 |
| 46235811 | Reticulocyte corpuscular hemoglobin concentration mean [Mass/volume] in Blood | 0.775 |  |   0 |          0 |
| 1617152 | Noninvasive prenatal fetal aneuploidy and 22q11.2 deletion panel - Plasma cell-free+WBC DNA by Dosage of chromosome-specific cfDNA | 0.775 |  |   0 |          0 |
| 1175815 | Drugs of abuse panel - Tissue | 0.775 |  |   0 |          0 |
| 3038962 | Glucose [Mass/volume] in Capillary blood --baseline | 0.774 |  |   0 |          0 |
| 3038515 | Glucose [Moles/volume] in Venous blood | 0.773 |  |   5 |     28,609 |
| 40771543 | Amphetamines panel - Meconium by Confirmatory method | 0.773 |  |   0 |          0 |
| 3022810 | Sodium [Moles/volume] in Body fluid | 0.773 |  |   0 |          0 |
| 3041440 | Amphetamine+Methamphetamine [Presence] in Specimen | 0.773 |  |   0 |          0 |
| 647799 | T-ALL minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.773 |  |   0 |          0 |
| 46236080 | Human papilloma virus 31+33+35+39+45+51+52+56+58+59+66+68 DNA [Presence] in Specimen by NAA with probe detection | 0.772 |  |   0 |          0 |
| 40770969 | pH of Synovial fluid by Test strip | 0.772 |  |   0 |          0 |
| 36659824 | Bacteria.carbapenem resistant identified in Specimen by Organism specific culture | 0.771 |  |   0 |          0 |
| 46236725 | Fetal Chromosome 21 trisomy [Presence] based on Plasma cell-free DNA by Sequencing | 0.771 |  |   0 |          0 |
| 1259993 | Gas and Lactate panel - Venous blood | 0.771 |  |   0 |          0 |
| 36660656 | CBC W Differential panel - Stem cell product | 0.770 |  |   0 |          0 |
| 3029511 | Human papilloma virus DNA [Presence] in Specimen by NAA with probe detection | 0.770 |  |   1 |     23,809 |
| 3023300 | Diffusion capacity/Alveolar volume by Single breath.carbon monoxide+Helium | 0.770 |  |   0 |          0 |
| 1091119 | Human papilloma virus 16+18+31+33+35+39+45+51+52+56+58+59+68 DNA [Presence] in Cervix by Molecular genetics method | 0.769 |  |   0 |          0 |
| 3020210 | Human papilloma virus Ag [Presence] in Genital specimen | 0.769 |  |   0 |          0 |
| 43533757 | Human papilloma virus 26+31+33+35+39+45+51+52+53+56+58+59+66+68+73+82 DNA [Presence] in Genital specimen by NAA with probe detection | 0.769 |  |   0 |          0 |
| 3039355 | Methicillin resistant Staphylococcus aureus [Presence] in Nose by Organism specific culture | 0.768 |  |   1 |      1,512 |
| 3024461 | Microorganism identified in Specimen by Culture | 0.768 |  |   0 |          0 |
| 40766210 | Pseudomonas aeruginosa.multidrug resistant isolate [Presence] in Specimen by Organism specific culture | 0.767 |  |   0 |          0 |
| 1617021 | Hemoglobin [Mass/volume] in Central venous blood by Oximetry | 0.767 |  |   0 |          0 |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.766 |  |   0 |          0 |
| 40757358 | Lymphoma - acute screen panel - Specimen by Flow cytometry (FC) | 0.766 |  |   0 |          0 |
| 3002030 | Lymphocytes/Leukocytes in Blood | 0.766 | 45 |  65 |  1,465,459 |
| 40760842 | Osmolality of Urine--3rd specimen | 0.765 |  |   0 |          0 |
| 3006239 | Hemoglobin [Mass/volume] in Arterial blood by Oximetry | 0.765 |  |   0 |          0 |
| 3027901 | Hemoglobin [Mass/volume] in Arterial cord blood | 0.765 |  |   1 |        180 |
| 40762373 | Cardiac stress echo study | 0.765 |  |   0 |          0 |
| 42870522 | Lymphocyte proliferation antigen panel - Blood by Flow cytometry (FC) | 0.764 |  |   0 |          0 |
| 40758488 | Osmolality of Urine--1 hour post fluid fast | 0.764 |  |   0 |          0 |
| 40757359 | Lymphoma - CLL screen panel - Specimen by Flow cytometry (FC) | 0.763 |  |   0 |          0 |
| 1761484 | Gram negative bacteria.colistin resistant identified in Stool by Organism specific culture | 0.763 |  |   0 |          0 |
| 40758486 | Osmolality of Urine--3 hours post fluid fast | 0.762 |  |   0 |          0 |
| 21490733 | Potassium [Mass/volume] in Blood | 0.762 |  |   0 |          0 |
| 3041041 | Hemoglobin [Mass/volume] in Cord blood | 0.762 |  |   0 |          0 |
| 3019491 | Creatinine [Moles/volume] in Urine by Test strip | 0.762 |  |   0 |          0 |
| 3000963 | Hemoglobin [Mass/volume] in Blood | 0.760 | 2 |  57 | 11,265,093 |
| 3040705 | Amphetamine+Methamphetamine [Presence] in Serum or Plasma | 0.759 |  |   0 |          0 |
| 3031579 | Sodium [Moles/volume] in Mixed venous blood | 0.759 |  |   0 |          0 |
| 46235392 | Hemoglobin [Mass/volume] in Venous blood by Oximetry | 0.758 |  |   0 |          0 |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.758 |  |   0 |          0 |
| 3006598 | pH of Arterial cord blood | 0.755 | 1087 |   2 |        453 |
| 43533918 | Hemoglobin [Entitic substance] in Reticulocytes by Automated count | 0.755 |  |   0 |          0 |
| 3031219 | Potassium [Moles/volume] in Mixed venous blood | 0.755 |  |   0 |          0 |
| 3030688 | Urinalysis panel - Urine by Auto | 0.755 |  |   0 |          0 |
| 3036243 | Potassium [Moles/volume] in Body fluid | 0.754 |  |   0 |          0 |
| 3003338 | MCHC [Entitic Mass/volume] in Red Blood Cells | 0.753 |  |  16 |  7,331,654 |
| 40757360 | Lymphoma - T-cell screen panel - Specimen by Flow cytometry (FC) | 0.753 |  |   0 |          0 |
| 3034226 | Lambda lymphocytes/Lymphocytes in Blood | 0.752 |  |   0 |          0 |
| 3050489 | Study report Skeletal system DXA | 0.752 |  |   0 |          0 |
| 42870577 | Diffusion capacity.carbon monoxide/Alveolar volume adjusted for hemoglobin | 0.751 |  |   0 |          0 |
| 3027831 | CD3-CD16+CD56+ (Natural killer) cells/cells in Blood | 0.751 | 944 |   4 |      7,605 |
| 648527 | Amphetamines [Measurement] in Urine | 0.751 |  |   0 |          0 |
| 3029461 | Hemoglobin [Mass/volume] in Arterial cord blood by calculation | 0.751 |  |   0 |          0 |
| 3007672 | Kappa lymphocytes/Lymphocytes in Blood | 0.750 |  |   0 |          0 |
| 1091049 | Amphetamine [Presence] in Urine | 0.748 |  |   0 |          0 |
| 3008905 | Diffusion capacity.carbon monoxide | 0.748 |  |   0 |          0 |
| 648501 | Amphetamine [Measurement] in Urine | 0.748 |  |   0 |          0 |
| 3001838 | Sodium [Moles/volume] in Red Blood Cells | 0.747 |  |   0 |          0 |
| 37020799 | Gram positive bacilli identified in Isolate by Organism specific culture | 0.746 |  |   0 |          0 |
| 21494434 | Karyotype in Bone marrow | 0.746 |  |   2 |      4,295 |
| 3012323 | Lymphocytes/Leukocytes in Blood by Flow cytometry (FC) | 0.745 |  |   0 |          0 |
| 3023764 | Bacteria identified in Specimen by Respiratory culture | 0.743 |  |   0 |          0 |
| 3009203 | Cardiac echo study Procedure | 0.743 |  |   0 |          0 |
| 1988185 | Stimulants drug panel - Urine by Screen method | 0.743 |  |   0 |          0 |
| 3038999 | pH of Venous blood adjusted to patient's actual temperature | 0.743 |  |   0 |          0 |
| 3053181 | Prothrombin time (PT) in Capillary blood by Coagulation assay | 0.743 |  |   0 |          0 |
| 3005460 | CD56 cells/cells in Blood | 0.742 |  |   0 |          0 |
| 3030157 | CD56+CD57+ cells/cells in Blood | 0.741 |  |   0 |          0 |
| 3015455 | CD16+CD56+ cells/cells in Blood | 0.739 | 1406 |   0 |          0 |
| 40760138 | Urinalysis dipstick W Reflex Culture panel - Urine | 0.734 |  |   0 |          0 |
| 46235809 | Reticulocyte hemoglobin distribution width [Mass/volume] in Blood by calculation | 0.733 |  |   0 |          0 |
| 3003466 | CD3+CD56+ cells/cells in Blood | 0.732 |  |   0 |          0 |
| 3051343 | DXA Bone [Mass/Area] Bone density | 0.730 |  |   0 |          0 |
| 40758220 | CD3-CD56+ cells/cells in Blood | 0.730 |  |   0 |          0 |
| 3032080 | INR in Blood by Coagulation assay | 0.725 | 206 |  88 |  2,812,069 |
| 21493451 | Spirometry panel | 0.723 |  |   0 |          0 |
| 3049858 | Reticulocyte mean volume [Entitic volume] in Reticulocytes | 0.723 |  |   0 |          0 |
| 3007558 | Diffusion capacity.carbon monoxide adjusted for hemoglobin by Helium single breath | 0.723 |  |   0 |          0 |
| 3051314 | MCHC [Entitic Mass/volume] in Red Blood Cells from Cord blood | 0.723 |  |   0 |          0 |
| 3006400 | Diffusion capacity.carbon monoxide adjusted for hemoglobin | 0.722 |  |   0 |          0 |
| 3050583 | Platelets panel - Blood by Automated count | 0.721 |  |   0 |          0 |
| 3018418 | pH of Serum or Plasma | 0.720 | 160 |  19 |    570,372 |
| 3042605 | INR in Platelet poor plasma or blood by Coagulation assay | 0.719 |  |   0 |          0 |
| 3010322 | Cardiac catheterization study | 0.717 |  |   0 |          0 |
| 1091363 | DXA Spine [T-score] Bone density | 0.715 |  |   0 |          0 |
| 1617299 | Diffusion capacity.carbon monoxide/Predicted | 0.710 |  |   0 |          0 |
| 3027837 | Diffusion capacity adjusted to body conditions by Single breath.carbon monoxide+Helium | 0.710 |  |   0 |          0 |
| 36204417 | DXA Lumbar spine [Z-score] Bone density | 0.708 |  |   0 |          0 |
| 3049581 | DXA Calcaneus [T-score] Bone density | 0.705 |  |   0 |          0 |
| 1988764 | Electromyography panel | 0.704 |  |   0 |          0 |
| 1617225 | Diffusion capacity.carbon monoxide --pre bronchodilation | 0.703 |  |   0 |          0 |
| 3965513 | Bone DXA Calcaneus [Z-score] Bone density | 0.703 |  |   0 |          0 |
| 36203242 | DXA Humerus [Mass/Area] Bone density | 0.703 |  |   0 |          0 |
| 3021722 | DXA Femur [Mass/Area] Bone density | 0.702 |  |   0 |          0 |
| 3044045 | Cell count and Differential panel - Body fluid | 0.702 |  |   0 |          0 |
| 3002101 | DXA Radius and Ulna [Mass/Area] Bone density | 0.701 |  |   0 |          0 |
| 3015145 | Diffusion capacity.carbon monoxide Predicted | 0.700 |  |   0 |          0 |
| 3022217 | INR in Platelet poor plasma by Coagulation assay | 0.699 | 53 |   0 |          0 |
| 3014424 | Cardiac echo study Procedure stress method | 0.696 |  |   0 |          0 |
| 3027232 | Diffusion capacity/Alveolar volume | 0.688 |  |   0 |          0 |
| 3023329 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter | 0.686 |  |   0 |          0 |
| 3043821 | Protein and Glucose panel - Urine by Test strip | 0.684 |  |   0 |          0 |
| 3009544 | EKG Study overall | 0.674 |  |   0 |          0 |
| 3033157 | Peak flow meter Vendor name | 0.669 |  |   0 |          0 |
| 3003481 | Cardiac echo study Transducer site Narrative | 0.668 |  |   0 |          0 |
| 3002200 | Cardiac echo study Transducer site | 0.665 |  |   0 |          0 |
| 3015588 | Electromyogram study | 0.664 |  |   0 |          0 |
| 40765089 | Chromosome analysis panel - Blood by G-banded | 0.663 |  |   1 |      1,888 |
| 3034016 | Peak flow meter Vendor model code | 0.662 |  |   0 |          0 |
| 46235184 | Cardiac stress test EKG study Type | 0.660 |  |   0 |          0 |
| 21493450 | Pulmonary function test panel | 0.660 |  |   0 |          0 |
| 3019794 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --post therapy | 0.658 |  |   0 |          0 |
| 46235180 | Neurology study | 0.657 |  |   0 |          0 |
| 42868488 | Positive airway pressure panel | 0.657 |  |   0 |          0 |
| 42869550 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --pre therapy | 0.654 |  |   0 |          0 |
| 3034996 | Type of Peak flow meter | 0.654 |  |   0 |          0 |
| 21494435 | Karyotype in Blood or Tissue --post mitogen stimulation | 0.651 |  |   0 |          0 |
| 3034930 | Peak flow meter Vendor software version | 0.651 |  |   0 |          0 |
| 40758532 | Asthma tracking panel | 0.651 |  |   0 |          0 |
| 40758294 | Paroxysmal nocturnal panel - Blood | 0.650 |  |   0 |          0 |
| 3012667 | Hematologic+Nuclear elements.microscopic observation [Identifier] in Tissue by Giemsa stain.May-Grunwald | 0.649 |  |   0 |          0 |
| 21494996 | Respiratory assessment panel | 0.648 |  |   0 |          0 |
| 36660396 | Hematologic neoplasm chromosome analysis in Blood or Marrow by Mate pair sequencing | 0.645 |  |   0 |          0 |
| 3026358 | Preparation techniques [Type] in Cervical or vaginal smear or scraping by Cyto stain | 0.644 |  |   0 |          0 |
| 21494982 | Neurological assessment panel | 0.642 |  |   0 |          0 |
| 21491758 | Electroretinography (ERG) panel | 0.641 |  |   0 |          0 |
| 36303746 | Microscopic observation [Identifier] in Bone marrow by Giemsa stain | 0.639 |  |   0 |          0 |
| 36031935 | Sedation panel NPASS | 0.638 |  |   0 |          0 |
| 21493510 | Constitutive heterochromatin analysis in Blood or Tissue by Banding | 0.637 |  |   0 |          0 |
| 3049361 | Cytology report of Specimen Cyto stain | 0.635 |  |   0 |          0 |
| 21493275 | Clotting time of Capillary blood by Sukharev method | 0.634 |  |   0 |          0 |
| 3966104 | Acute myeloid leukemia in Blood or Tissue by FISH | 0.633 |  |   0 |          0 |
| 40763950 | INR in Platelet poor plasma from Fetus by Coagulation assay | 0.632 |  |   0 |          0 |
| 40762358 | Karyotype [Identifier] in Blood or Tissue by FISH Narrative | 0.625 |  |   0 |          0 |
| 36660048 | Chromosome region 14q32 rearrangements in Bone marrow by FISH | 0.624 |  |   0 |          0 |
| 3041830 | Coag.tissue factor induced.PIVKA sensitive actual/normal in Capillary blood by Coagulation assay | 0.622 |  |   0 |          0 |
| 3039326 | INR post heparin neutralization in Platelet poor plasma by Coagulation assay | 0.621 |  |   0 |          0 |
| 40762347 | Cytologist who read Cyto stain of Specimen | 0.591 |  |   0 |          0 |
| 3049717 | Cytology report of Urine Cyto stain | 0.590 |  |   2 |     40,944 |
| 3030078 | Cell type in Specimen | 0.578 |  |   0 |          0 |
| 3049411 | Cytology report of Body fluid Cyto stain | 0.577 |  |   0 |          0 |
| 46235082 | Evoked potential study | 0.576 |  |   0 |          0 |
| 3043109 | Cytology report of Tissue fine needle aspirate Cyto stain | 0.570 | 943 |   1 |     13,478 |
| 3052565 | Study report | 0.564 |  |   0 |          0 |
| 3030694 | Cytology report of Bronchial brush Cyto stain | 0.562 |  |   0 |          0 |
| 3013125 | Reviewing cytologist who read Cyto stain of Cervical or vaginal smear or scraping | 0.560 | 1656 |   0 |          0 |
| 3035004 | Microscopic observation [Identifier] in Urine by Cyto stain | 0.557 | 1251 |   0 |          0 |
| 3003981 | EKG Study observation overall (narrative) | 0.552 |  |   0 |          0 |
| 21494992 | Neurological assessment [Interpretation] | 0.547 |  |   0 |          0 |
| 3026936 | Central cardiovascular Study observation Narrative by US | 0.531 |  |   0 |          0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 222 | -histologinensolublokkisytologisestanäytteestä |  | 214 | 100 |  |  |  |  | Cell block preparation from Cytology specimen | FALSE |
| 223 | -humanpapillomavirusgenotyyppi16 |  | 301 | 100 |  |  |  |  | Human Papillomavirus 16 DNA [Presence] in Cervical or Vaginal specimen | FALSE |
| 224 | -humanpapillomavirusgenotyyppi18 |  | 301 | 100 |  |  |  |  | Human Papillomavirus 18 DNA [Presence] in Cervical or Vaginal specimen | FALSE |
| 225 | -humanpapillomavirusgenotyyppimuupatogeeninenhpv |  | 252 | 100 |  |  |  |  | Human Papillomavirus high risk types DNA [Presence] in Cervical or Vaginal specimen | FALSE |
| 226 | -lisämaksukiireellisenäpyydetyllenäytteelle |  | 584 | 100 |  |  |  |  |  | FALSE |
| 227 | -lisätutkimuspyyntöaiemmintutkitullenäytteelle |  | 191 | 100 |  |  |  |  |  | FALSE |
| 228 | -lisävastaus2laskutuskuitatullenäytteelle |  | 438 | 100 |  |  |  |  |  | FALSE |
| 229 | -lisävastauslaskutuskuitatullenäytteelle |  | 2865 | 100 |  |  |  |  |  | FALSE |
| 230 | -moniresistentitgram-negatiivisetsauvat,viljely |  | 122 | 100 |  |  |  |  | Gram negative bacilli.multidrug resistant identified in Specimen by Culture | FALSE |
| 231 | -moniresistentitgramnegatiivisetsauvat,viljely |  | 163 | 100 |  |  |  |  | Gram negative bacilli.multidrug resistant identified in Specimen by Culture | FALSE |
| 232 | -resistentitgramnegatiivisetsauvat,viljely |  | 314 | 100 |  |  |  |  | Gram negative bacilli.multidrug resistant identified in Specimen by Culture | FALSE |
| 233 | -staphylococcusaureus,metilliiniresist.viljely |  | 248 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Specimen by Culture | FALSE |
| 234 | -staphylococcusaureus,metisilliiniresistentti,v |  | 540 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Specimen by Culture | FALSE |
| 235 | b-glukoosi,hoitoyksikönvieritesti,kokoveri |  | 687 | 0.15 | [5.55, 5.93, 6.7, 7.42, 8.33, 9.1, 10.22, 12.18, 14.28] |  | Blood |  | Glucose [Moles/volume] in Blood by Point of care | FALSE |
| 236 | b-hematologisenpotilaanperuskaryotyypinmääritys |  | 125 | 100 |  |  | Blood |  | Karyotype for Hematologic malignancy in Blood by Giemsa stain | FALSE |
| 237 | b-kreatiniini,hoitoyksikönvieritesti,veri |  | 167 | 0 | [58.29, 69.03, 76.8, 84.73, 95.67, 105.12, 116.21, 134.79, 170] |  | Blood |  | Creatinine [Moles/volume] in Blood by Point of care | FALSE |
| 238 | bakteerit,virtsasta,partikkelinlaskijalla,osatutk. |  | 212 | 100 |  |  |  |  | Bacteria [#/volume] in Urine by Automated count | FALSE |
| 239 | bm-pahanlaatuisenveritaudinimmunofenotyypitys |  | 191 | 100 |  |  | Bone marrow |  | Leukemia or Lymphoma immunophenotyping panel by Flow cytometry (FC) in Bone marrow | TRUE |
| 240 | bm-pahanlaatuisenveritaudinimmunofenotyyppinenjäännöstautianalyysi |  | 162 | 100 |  |  | Bone marrow |  | Leukemia or Lymphoma Minimal Residual Disease panel by Flow cytometry (FC) in Bone marrow | TRUE |
| 241 | cb-hemoglobiini,vieritestihoitoyksikössä | g/l | 101 | 0 | [84.5, 92.5, 100.5, 112.5, 121.56, 127.06, 131.83, 135.83, 146] |  | Capillary blood |  | Hemoglobin [Mass/volume] in Capillary blood by Point of care | FALSE |
| 242 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä | mmol/l | 5203 | 0 | [5.2, 6.16, 6.92, 7.87, 8.89, 10.17, 11.74, 13.96, 16.77] |  |  |  | Glucose [Moles/volume] in Capillary blood by Point of care | FALSE |
| 243 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä |  | 19 | 100 | [5.33, 6.26, 7.1, 7.98, 9.1, 10.33, 11.92, 13.89, 16.96] |  |  |  | Glucose [Moles/volume] in Capillary blood by Point of care | FALSE |
| 244 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella | mg/l | 771 | 0 | [2.6, 5.17, 9.64, 14.69, 22, 32.29, 47.95, 69.4, 106.84] |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma by Point of care | FALSE |
| 245 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella |  | 192 | 85.42 |  |  |  |  | C reactive protein [Mass/volume] in Serum or Plasma by Point of care | FALSE |
| 246 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 438 | 0 | [26.9, 30, 31.94, 33, 34, 34.57, 35, 36, 37.53] |  | Erythrocyte |  | Reticulocyte hemoglobin content [Entitic mass] in Red Blood Cells | FALSE |
| 247 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 15 | 6.67 |  |  | Erythrocyte |  | Reticulocyte hemoglobin content [Entitic mass] in Red Blood Cells | FALSE |
| 248 | emäsylimäärä,laskimoverestä,pikatesti␤ | mmol/l | 373 | 0 |  |  |  |  | Base excess in Venous blood by calculation | FALSE |
| 249 | emäsylimäärä,laskimoverestä,pikatesti␤ |  | 339 | 19.47 |  |  |  |  | Base excess in Venous blood by calculation | FALSE |
| 250 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 203 | 0 | [0.2, 0.4, 0.66, 1, 1.3, 1.71, 2.47, 3.65, 8.32] |  |  |  | Epithelial cells [#/volume] in Urine by Automated count | FALSE |
| 251 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. |  | 9 | 100 |  |  |  |  | Epithelial cells [#/volume] in Urine by Automated count | FALSE |
| 252 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta | iu/ml | 24 | 0 |  |  |  |  | Epstein-Barr virus DNA [Units/volume] in Plasma by NAA with probe detection | FALSE |
| 253 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta |  | 241 | 100 |  |  |  |  | Epstein-Barr virus DNA [Presence] in Plasma by NAA with probe detection | FALSE |
| 254 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 202 | 0 | [3.19, 4.28, 5.76, 7.13, 9.35, 12.16, 16.65, 32.02, 93.76] |  |  |  | Erythrocytes [#/volume] in Urine by Automated count | FALSE |
| 255 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. |  | 10 | 100 |  |  |  |  | Erythrocytes [#/volume] in Urine by Automated count | FALSE |
| 256 | fp-kollageenii:nbeta-karboksiterminaalinentelopeptidi | ug/l | 299 | 0 | [0.08, 0.14, 0.17, 0.21, 0.26, 0.3, 0.36, 0.45, 0.63] |  | Fasting plasma |  | Collagen type I cross-linked C-telopeptide [Mass/volume] in Serum or Plasma --fasting | FALSE |
| 257 | happamusaste,kapillaariverestä,pikatesti␤ |  | 1262 | 0.24 |  |  |  |  | pH of Capillary blood | FALSE |
| 258 | happamuusaste,laskimoverestä,pikatesti␤ |  | 712 | 0.7 |  |  |  |  | pH of Venous blood | FALSE |
| 259 | happiosapaine,kapillaariverestä,pikatesti␤ | kpa | 1260 | 0 |  |  |  |  | Oxygen [Partial pressure] in Capillary blood | FALSE |
| 260 | happoemästasejahappi,laskimoverestä,pikatesti␤ |  | 643 | 100 |  |  |  |  | Gas panel - Venous blood | TRUE |
| 261 | hepatiittic-virus,nh,jatkotutkimus,plasmasta |  | 512 | 100 |  |  |  |  | Hepatitis C virus RNA [Presence] in Plasma by NAA with probe detection | FALSE |
| 262 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ | kpa | 707 | 0 |  |  |  |  | Carbon dioxide [Partial pressure] in Venous blood | FALSE |
| 263 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ |  | 5 | 100 |  |  |  |  | Carbon dioxide [Partial pressure] in Venous blood | FALSE |
| 264 | hpv-gt16aptimapanther,apututkimustulostensiirtoon |  | 149 | 100 |  |  |  |  | Human Papillomavirus 16 RNA [Presence] in Cervix by NAA | FALSE |
| 265 | hpv-gt18-45aptimapanther,apututkimustulostensiirtoon |  | 149 | 100 |  |  |  |  | Human Papillomavirus 18+45 RNA [Presence] in Cervix by NAA | FALSE |
| 266 | hpvaptimapanther,apututkimustulostensiirtoon |  | 413 | 100 |  |  |  |  | Human Papillomavirus high risk types RNA [Presence] in Cervix by NAA | FALSE |
| 267 | humanimmunodeficiencyvirus,antigeenijavasta- |  | 192 | 100 |  |  |  |  | HIV 1+2 p24 Ag+Ab [Presence] in Serum or Plasma | FALSE |
| 268 | humanimmunodeficiencyvirus,antigeenijavasta-aineet,yhd |  | 260 | 100 |  |  |  |  | HIV 1+2 p24 Ag+Ab [Presence] in Serum or Plasma | FALSE |
| 269 | huume-jalääkeainetutkimus,laaja,varmistus |  | 448 | 100 |  |  |  |  | Drugs of abuse confirmation panel - Specimen | TRUE |
| 270 | huumeseulonta,kvalitatiivinen,virtsasta␤ |  | 140 | 100 |  |  |  |  | Drugs of abuse screen panel - Urine | TRUE |
| 271 | kalium,hoitoyksikönvieritesti,veri | mmol/l | 166 | 0 | [3.34, 3.65, 3.8, 3.9, 4, 4.19, 4.3, 4.42, 4.6] |  |  |  | Potassium [Moles/volume] in Blood by Point of care | FALSE |
| 272 | kalium,hoitoyksikönvieritesti,veri |  | 290 | 0 | [3.4, 3.69, 3.8, 3.9, 4.06, 4.2, 4.4, 4.56, 5] |  |  |  | Potassium [Moles/volume] in Blood by Point of care | FALSE |
| 273 | kreatiniini,hoitoyksikönvieritesti,veri | mmol/l | 163 | 0 | [61.44, 68.7, 74.81, 78.74, 84.67, 94.44, 102.62, 112.17, 146.53] |  |  |  | Creatinine [Moles/volume] in Blood by Point of care | FALSE |
| 274 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 874 | 0 | [2.21, 3.1, 4.22, 5.54, 6.81, 8.47, 10.55, 13.18, 17.82] |  |  |  | Creatinine [Moles/volume] in Urine | FALSE |
| 275 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) |  | 6 | 66.67 |  |  |  |  | Creatinine [Moles/volume] in Urine | FALSE |
| 276 | laajahuumeseulonta,varmistustasoinen,virtsasta |  | 944 | 100 |  |  |  |  | Drugs of abuse confirmation panel - Urine | TRUE |
| 277 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 203 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.1, 0.4] |  |  |  | Casts [#/volume] in Urine by Automated count | FALSE |
| 278 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. |  | 9 | 100 |  |  |  |  | Casts [#/volume] in Urine by Automated count | FALSE |
| 279 | lisävastauslaskutuskuitatullenäytteelle |  | 214 | 100 |  |  |  |  |  | FALSE |
| 280 | luuntiheysmittaus,2kohdetta(nk6sa),lausuttuna |  | 145 | 100 |  |  |  |  | Bone density by DXA panel | TRUE |
| 281 | marevan-hoidonseur.tatesti,hoitoyksikkötekeesormenpäänäyte |  | 168 | 0 |  |  |  |  | INR in Capillary blood by Point of care | FALSE |
| 282 | moniresistentitgramnegatiivisetsauvat,viljely |  | 206 | 100 |  |  |  |  | Gram negative bacilli.multidrug resistant identified in Specimen by Culture | FALSE |
| 283 | natrium,hoitoyksikönvieritesti,veri | mmol/l | 163 | 0 | [133.07, 135, 136.54, 138, 139, 139.55, 140, 141, 142] |  |  |  | Sodium [Moles/volume] in Blood by Point of care | FALSE |
| 284 | natrium,hoitoyksikönvieritesti,veri |  | 292 | 0 | [131.17, 133.92, 135.97, 137.29, 138.69, 139.5, 140, 141, 142] |  |  |  | Sodium [Moles/volume] in Blood by Point of care | FALSE |
| 285 | natriureettinenpeptidi,b-tyypinn-terminaalinenpropeptidi,plasmasta | ng/l | 159 | 0 | [27.45, 51.56, 106.33, 265.57, 634.4, 1351.3, 2903.04, 5577.84, 11032.2] |  |  |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma | FALSE |
| 286 | nk-solujenosuus(määritettynäcd3-/cd16+/cd56+-soluina) | % | 665 | 0 | [4, 7.07, 9.79, 12.53, 14.84, 17.1, 21.25, 26.92, 36.91] |  |  |  | NK cells/Lymphocytes in Blood | FALSE |
| 287 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. | mosm/kgh2o | 203 | 0 | [331.17, 377.3, 431.74, 500.49, 539.14, 595.38, 634.62, 686.05, 750.53] |  |  |  | Osmolality in Urine | FALSE |
| 288 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. |  | 9 | 100 |  |  |  |  | Osmolality in Urine | FALSE |
| 289 | p-natriureett.peptidin-termin.propept.vieritl | ng/l | 118 | 0 | [140.45, 226.81, 316.84, 708.93, 1117.67, 1691.6, 2121.04, 3414.6, 4866.2] |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma by Point of care | FALSE |
| 290 | p-natriureett.peptidin-termin.propept.vieritl |  | 20 | 100 |  |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma by Point of care | FALSE |
| 291 | p-natriureettinenpeptidi,b-tyypinn-terminaalin | ng/l | 4682 | 0 | [86.24, 151.65, 238.65, 387.07, 653.89, 1066.35, 1771.72, 3084.52, 6142.85] |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma | FALSE |
| 292 | p-natriureettinenpeptidi,b-tyypinn-terminaalin |  | 149 | 100 |  |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma | FALSE |
| 293 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi | ng/l | 1366 | 0 | [106.15, 192.31, 311.64, 535.82, 915.89, 1456.12, 2310.73, 3820.95, 6983] |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma | FALSE |
| 294 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi |  | 107 | 100 |  |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma | FALSE |
| 295 | parasiitit,ulosteesta(alkueläintenkystat,madot,madonmunat,toukat) |  | 120 | 100 |  |  |  |  | Ova and Parasites identified in Stool by Microscopy | FALSE |
| 296 | pienikudoskoepala,enintään1-3samankokonaisuudennäytettä |  | 234 | 100 |  |  |  |  | Tissue Pathology biopsy report | FALSE |
| 297 | pika:m10inabnhp,rsvnhp,cv19nhp,yhdistelmävierit. |  | 267 | 100 |  |  |  |  | SARS-CoV-2 & Influenza virus A & B & RSV RNA panel - Nasopharynx by NAA | TRUE |
| 298 | pt-diffuusiokapasiteetti,single-breath-menetelmä,tavallinenperusmittaus |  | 3577 | 100 |  |  | Patient |  | Carbon monoxide diffusing capacity [Volume/time/Pressure] by Single breath | FALSE |
| 299 | pt-lausuntoneurofysiologisestatutkimuksesta,hälytysindikaatiot |  | 113 | 100 |  |  | Patient |  | Neurophysiology study report | FALSE |
| 300 | pt-luuntiheysmittaus,2kohdetta,ilmanlausuntoa |  | 120 | 100 |  |  | Patient |  | Bone density by DXA panel | TRUE |
| 301 | pt-sydämenkattavarakenteellinenjatoiminnallinenuä(fm1ee) |  | 177 | 100 |  |  | Patient |  | Echocardiogram study | TRUE |
| 302 | pt-uloshengityksenhuippuvirtaus,vuorokausivaihtelunseuranta |  | 474 | 100 |  |  | Patient |  | Peak expiratory flow rate monitoring panel | TRUE |
| 303 | pt-yöpolygrafia,ambulatorinen,hyvinsuppeaunirekisteröintikotona |  | 542 | 100 |  |  | Patient |  | Polysomnography panel | TRUE |
| 304 | pt-yöpolygrafia,ambulatorinen,jalkaliikerekisteröinnein |  | 102 | 100 |  |  | Patient |  | Polysomnography panel | TRUE |
| 305 | pu-aerobinenjaanaerobinenbakteerityypitysjaan |  | 147 | 100 |  |  | Pus |  | Bacteria identified in Pus by Culture | FALSE |
| 306 | resistentitgramnegatiivisetsauvat,viljely |  | 320 | 100 |  |  |  |  | Gram negative bacilli.multidrug resistant identified in Specimen by Culture | FALSE |
| 307 | retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 525 | 0 | [26.59, 29.88, 31.77, 32.87, 33.87, 34, 35, 35.95, 37] |  |  |  | Reticulocyte hemoglobin content [Entitic mass] in Red Blood Cells | FALSE |
| 308 | retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 5 | 100 |  |  |  |  | Reticulocyte hemoglobin content [Entitic mass] in Red Blood Cells | FALSE |
| 309 | s-humanimmunodeficiencyvirus,antigeenijavast |  | 1221 | 100 |  |  | Serum |  | HIV 1+2 p24 Ag+Ab [Presence] in Serum or Plasma | FALSE |
| 310 | sikiöperäisendna:ntutkimusäidinverinäytteestä |  | 104 | 100 |  |  |  |  | Fetal Aneuploidy (T21, T18, T13) and Fetal sex panel by Maternal cell-free DNA in Plasma | TRUE |
| 311 | staphylococcusaureus,metisilliiniresistenssiviljely␤ |  | 134 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Specimen by Culture | FALSE |
| 312 | staphylococcusaureus,metisilliiniresistentti(mrsa),viljely |  | 627 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Specimen by Culture | FALSE |
| 313 | t-auttajasolujenosuus(määritettynäcd3+cd4+soluina) | % | 665 | 0 | [12.24, 17.15, 20.76, 25.01, 30.99, 37.63, 47.04, 52.34, 60.07] |  | Thrombocyte |  | CD4 cells/Lymphocytes in Blood | FALSE |
| 314 | t-estäjäsolujenosuus(määritettynäcd3+cd8+soluina) | % | 665 | 0 | [14.45, 20.35, 24.03, 27.06, 32.04, 37.14, 44.33, 52.92, 66.66] |  | Thrombocyte |  | CD8 cells/Lymphocytes in Blood | FALSE |
| 315 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella | ng/l | 7 | 0 |  |  |  |  | Troponin T.cardiac [Mass/volume] in Serum or Plasma by Point of care | FALSE |
| 316 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella |  | 97 | 93.81 |  |  |  |  | Troponin T.cardiac [Mass/volume] in Serum or Plasma by Point of care | FALSE |
| 317 | ts-histologinentutkimus,1-3kudosnäytettä |  | 160 | 100 |  |  | Tissue |  | Tissue Pathology biopsy report | FALSE |
| 318 | ts-histologinentutkimus,1-3näytettä |  | 945 | 100 |  |  | Tissue |  | Tissue Pathology biopsy report | FALSE |
| 319 | työpaikanhuumeseulontajavarmistus,4yhdistettä |  | 469 | 100 |  |  |  |  | Drugs of abuse 4 panel - Urine | TRUE |
| 320 | työpaikanhuumeseulontajavarmistus,7yhdistettä |  | 312 | 100 |  |  |  |  | Drugs of abuse 7 panel - Urine | TRUE |
| 321 | täydellinennimi:pt-näytteenotto0maksu,kierronulkopuolisetnäytteet |  | 1481 | 100 |  |  |  |  |  | FALSE |
| 322 | täydellinenverenkuva,sis.perusverenkuvanjaleukosyyttienerittelylaskennan␤ |  | 9742 | 100 |  |  |  |  | CBC W Differential panel - Blood by Automated count | TRUE |
| 323 | u-amfetamiinijametamfetamiini,enantiomeerienerittely |  | 120 | 100 |  |  | Urine |  | Amphetamine and Methamphetamine enantiomers panel - Urine | TRUE |
| 324 | u-asetoniaineet,kval,vieritestihoitoyksikössä |  | 421 | 100 |  |  | Urine |  | Ketones [Presence] in Urine by Test strip | FALSE |
| 325 | u-erytrosyytit,kval,vieritestihoitoyksikössä |  | 413 | 100 |  |  | Urine |  | Hemoglobin [Presence] in Urine by Test strip | FALSE |
| 326 | u-glukoosi,kvalvieritestihoitoyksikössä |  | 423 | 100 |  |  | Urine |  | Glucose [Presence] in Urine by Test strip | FALSE |
| 327 | u-happamuusaste,vieritestihoitoyksikössä |  | 400 | 0.25 | [5.5, 5.5, 5.5, 5.9, 6, 6, 6.5, 7, 7] |  | Urine |  | pH of Urine by Test strip | FALSE |
| 328 | u-huume-jalääkeainetutkimus,laaja,varmistus |  | 175 | 100 |  |  | Urine |  | Drugs of abuse confirmation panel - Urine | TRUE |
| 329 | u-huume-jalääkeainetutkimus,semikvantitatiivinen,virtsa␤sta |  | 121 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine | TRUE |
| 330 | u-huumeseulonta,laaja(kvalitatiivinenlc-tof-ms) |  | 144 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine by Chromatography/Mass spectrometry | TRUE |
| 331 | u-kemiallinenseulonta,vieritestihoitoyksikössä |  | 104 | 100 |  |  | Urine |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 332 | u-kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 398 | 0 | [2.13, 2.88, 3.69, 4.73, 6, 7.61, 9.67, 12.44, 16.61] |  | Urine |  | Creatinine [Moles/volume] in Urine | FALSE |
| 333 | u-laajahuume-jalääkeainetutkimus,semikvantitatiivinen |  | 421 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine | TRUE |
| 334 | u-leukosyytit,kval,vieritestihoitoyksikössä |  | 429 | 100 |  |  | Urine |  | Leukocyte esterase [Presence] in Urine by Test strip | FALSE |
| 335 | u-nitriitti,kval,vieritestihoitoyksikössä |  | 421 | 100 |  |  | Urine |  | Nitrite [Presence] in Urine by Test strip | FALSE |
| 336 | u-proteiini,kval,vieritestihoitoyksikössä |  | 425 | 100 |  |  | Urine |  | Protein [Presence] in Urine by Test strip | FALSE |
| 337 | vieritestilaite(epoc)verikaasuanalyysilaskimonäytteestä |  | 162 | 100 |  |  |  |  | Gas panel - Venous blood | TRUE |
| 338 | yersinia(lajitenterocolitica,pseudotuberculosis,pestis)nho,ulosteesta␤ |  | 484 | 100 |  |  |  |  | Yersinia enterocolitica and Yersinia pseudotuberculosis DNA panel - Stool by NAA | TRUE |

