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
Here is group 70.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3003709 | Acetaminophen [Presence] in Serum or Plasma | 1.000 | 829 |  0 |         0 |
| 3006120 | Parvovirus B19 IgG Ab [Units/volume] in Serum | 1.000 | 1457 |  0 |         0 |
| 3006410 | Parvovirus B19 IgG Ab [Presence] in Serum | 1.000 | 1744 |  0 |         0 |
| 3008321 | Parvovirus B19 IgM Ab [Presence] in Serum | 1.000 | 1746 |  0 |         0 |
| 3009550 | Parvovirus B19 IgG Ab [Titer] in Serum | 1.000 | 1729 |  3 |     2,615 |
| 3011268 | Mumps virus IgM Ab [Presence] in Serum | 1.000 |  |  0 |         0 |
| 3015883 | Cotinine [Presence] in Urine | 1.000 |  |  0 |         0 |
| 3016894 | Varicella zoster virus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  1 |     2,631 |
| 3018359 | Ovary Ab [Presence] in Serum | 1.000 |  |  0 |         0 |
| 3018867 | Mumps virus IgG Ab [Units/volume] in Serum | 1.000 | 754 |  0 |         0 |
| 3018980 | carBAMazepine [Moles/volume] in Serum or Plasma | 1.000 | 671 |  3 |     4,575 |
| 3020485 | Acetaminophen [Moles/volume] in Serum or Plasma | 1.000 | 402 |  3 |     5,169 |
| 3021583 | Cardiolipin Ab [Presence] in Serum | 1.000 |  |  0 |         0 |
| 3024981 | Mumps virus IgG Ab [Titer] in Serum | 1.000 |  |  0 |         0 |
| 3027159 | OXcarbazepine [Moles/volume] in Serum or Plasma | 1.000 | 1659 |  0 |         0 |
| 3028498 | Mumps virus IgG Ab [Presence] in Serum | 1.000 | 1007 |  0 |         0 |
| 3032080 | INR in Blood by Coagulation assay | 1.000 | 206 | 88 | 2,812,069 |
| 3033658 | Prothrombin time (PT) actual/Normal | 1.000 | 3000 | 17 |   484,673 |
| 3035544 | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma | 1.000 |  |  3 |     1,674 |
| 3035903 | Mumps virus Ab [Presence] in Serum | 1.000 |  |  0 |         0 |
| 3037492 | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma | 1.000 |  |  0 |         0 |
| 3038458 | Plasmodium sp [Presence] in Blood by Light microscopy | 1.000 |  |  0 |         0 |
| 3044640 | Blood type and Crossmatch panel - Blood | 1.000 |  |  1 |   354,396 |
| 3044866 | Ovary Ab [Titer] in Serum | 1.000 |  |  0 |         0 |
| 3048469 | 10-Hydroxycarbazepine [Moles/volume] in Serum or Plasma | 1.000 | 1473 |  4 |     5,002 |
| 3048689 | Calprotectin [Mass/mass] in Stool | 1.000 |  |  5 |   164,242 |
| 40768804 | Tissue Pathology biopsy report | 1.000 |  |  9 |   373,531 |
| 42529010 | Calprotectin [Mass/volume] in Stool | 1.000 |  |  0 |         0 |
| 3014435 | Carbamazepine 10,11-Epoxide [Moles/volume] in Serum or Plasma | 0.988 |  |  0 |         0 |
| 3021584 | Pregnancy associated plasma protein A [Units/volume] in Serum or Plasma | 0.977 | 767 |  5 |    44,381 |
| 3028027 | Mumps virus IgM Ab [Titer] in Serum | 0.977 |  |  0 |         0 |
| 21493354 | Varicella zoster virus DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.976 |  |  0 |         0 |
| 3002715 | Mumps virus IgG+IgM Ab [Units/volume] in Serum | 0.973 |  |  0 |         0 |
| 3014183 | Mumps virus IgM Ab [Units/volume] in Serum | 0.972 |  |  0 |         0 |
| 3048406 | Carbamazepine 10,11-epoxide free [Moles/volume] in Serum or Plasma | 0.967 |  |  0 |         0 |
| 3024338 | Parvovirus B19 IgG+IgM Ab [Units/volume] in Serum | 0.966 |  |  0 |         0 |
| 3028333 | Cardiolipin IgG Ab [Presence] in Serum | 0.965 |  |  0 |         0 |
| 3011781 | Mumps virus IgG Ab [Presence] in Serum by Immunoassay | 0.962 | 1008 |  0 |         0 |
| 3025709 | Mumps virus IgG Ab [Units/volume] in Serum by Immunoassay | 0.961 | 1789 |  0 |         0 |
| 3020457 | Parvovirus B19 IgG Ab [Units/volume] in Serum by Immunoassay | 0.960 | 1014 |  0 |         0 |
| 3008560 | Mumps virus IgM Ab [Presence] in Serum by Immunoassay | 0.958 |  |  0 |         0 |
| 3027119 | Mumps virus Ab [Titer] in Serum | 0.958 |  |  0 |         0 |
| 3020259 | Cardiolipin IgG Ab [Titer] in Serum | 0.956 |  |  0 |         0 |
| 3015064 | Parvovirus B19 IgM Ab [Titer] in Serum | 0.953 | 1462 |  0 |         0 |
| 3022758 | Parvovirus B19 IgG Ab [Presence] in Serum by Immunoassay | 0.953 | 1745 |  0 |         0 |
| 3003196 | Cardiolipin IgA Ab [Units/volume] in Serum or Plasma | 0.953 |  |  0 |         0 |
| 3001139 | carBAMazepine free [Moles/volume] in Serum or Plasma | 0.953 |  |  0 |         0 |
| 3028639 | carBAMazepine [Mass/volume] in Serum or Plasma | 0.952 |  |  0 |         0 |
| 3001365 | Mumps virus Ab [Presence] in Serum by Immunoassay | 0.951 |  |  0 |         0 |
| 3016754 | Carbamazepine 10,11-Epoxide [Mass/volume] in Serum or Plasma | 0.949 |  |  0 |         0 |
| 3018027 | Mumps virus Ab [Units/volume] in Serum | 0.947 |  |  0 |         0 |
| 3043961 | Parvovirus B19 IgM Ab [Presence] in Serum by Immunoassay | 0.946 | 1747 |  0 |         0 |
| 3015813 | Cardiolipin IgM Ab [Units/volume] in Serum by Immunoassay | 0.945 | 505 |  0 |         0 |
| 3009466 | Valproate [Moles/volume] in Serum or Plasma | 0.944 | 408 |  4 |    37,442 |
| 3007221 | Parvovirus B19 Ab [Units/volume] in Serum | 0.943 |  |  0 |         0 |
| 3026515 | Parvovirus B19 IgM Ab [Units/volume] in Serum | 0.943 | 1280 |  1 |     2,963 |
| 1617628 | carBAMazepine [Moles/volume] in Serum or Plasma --trough | 0.942 |  |  0 |         0 |
| 3040735 | Parvovirus B19 IgG Ab [Presence] in Serum by Immunofluorescence | 0.941 |  |  0 |         0 |
| 3009273 | Parvovirus B19 IgG Ab [Titer] in Serum by Immunofluorescence | 0.940 |  |  0 |         0 |
| 3033882 | Carnitine [Moles/volume] in Serum or Plasma | 0.939 | 1409 |  2 |       343 |
| 3038866 | Parvovirus B19 IgM Ab [Presence] in Serum by Immunofluorescence | 0.939 |  |  0 |         0 |
| 3009041 | Cardiolipin IgG Ab [Units/volume] in Serum by Immunoassay | 0.939 | 504 |  5 |     9,604 |
| 3012932 | Hazelnut IgE Ab [Units/volume] in Serum | 0.938 | 1241 |  3 |        63 |
| 3015036 | Mumps virus IgG Ab [Titer] in Serum by Immunofluorescence | 0.936 |  |  0 |         0 |
| 3005839 | 10-Hydroxycarbazepine [Mass/volume] in Serum or Plasma | 0.936 |  |  0 |         0 |
| 3034972 | Bordetella parapertussis DNA [Presence] in Nasopharynx by NAA with probe detection | 0.935 |  |  0 |         0 |
| 3018589 | Mumps virus Ag [Presence] in Serum | 0.935 |  |  0 |         0 |
| 36304546 | Varicella zoster virus DNA [Presence] in Body fluid by NAA with probe detection | 0.935 |  |  0 |         0 |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.934 |  |  0 |         0 |
| 3003388 | Carnitine [Presence] in Serum or Plasma | 0.934 |  |  0 |         0 |
| 3003461 | Cardiolipin Ab [Units/volume] in Serum | 0.933 |  |  0 |         0 |
| 36303754 | OXcarbazepine [Moles/volume] in Serum or Plasma --trough | 0.933 |  |  0 |         0 |
| 3014002 | Cardiolipin IgM Ab [Titer] in Serum | 0.933 |  |  0 |         0 |
| 3051741 | Pregnancy associated plasma protein A [Mass/volume] in Serum or Plasma | 0.932 |  |  0 |         0 |
| 3037875 | Bordetella parapertussis DNA [Presence] in Specimen by NAA with probe detection | 0.932 |  |  1 |     3,745 |
| 3006441 | Cardiolipin IgM Ab [Presence] in Serum by Immunoassay | 0.932 |  |  2 |     1,671 |
| 1617081 | carBAMazepine [Moles/volume] in Serum or Plasma --peak | 0.931 |  |  0 |         0 |
| 1469897 | Bordetella parapertussis DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.930 |  |  0 |         0 |
| 3028110 | Bile acid [Moles/volume] in Serum or Plasma | 0.930 |  |  0 |         0 |
| 3034274 | Bile acid [Moles/volume] in Serum --fasting | 0.929 |  |  6 |    17,221 |
| 3012794 | Mumps virus IgG Ab [Units/volume] in Body fluid | 0.929 |  |  0 |         0 |
| 3026253 | Mumps virus IgM Ab [Units/volume] in Serum by Immunoassay | 0.929 |  |  0 |         0 |
| 37021002 | Bordetella parapertussis DNA [Presence] in Throat by NAA with probe detection | 0.928 |  |  0 |         0 |
| 3001982 | Cardiolipin IgA Ab [Presence] in Serum | 0.927 |  |  0 |         0 |
| 3007766 | Cardiolipin IgG Ab [Presence] in Serum by Immunoassay | 0.927 |  |  0 |         0 |
| 3036148 | OXcarbazepine [Mass/volume] in Serum or Plasma | 0.926 |  |  0 |         0 |
| 648388 | Mumps virus IgG Ab [Measurement] in Serum | 0.926 |  |  0 |         0 |
| 3051272 | Parvovirus B19 IgG Ab [Units/volume] in Body fluid | 0.926 |  |  0 |         0 |
| 3043792 | Cardiolipin Ab [Presence] in Serum by Immunoassay | 0.926 |  |  0 |         0 |
| 3002617 | Acetaminophen [Mass/volume] in Serum or Plasma | 0.926 |  |  0 |         0 |
| 3022915 | Valproate Free [Moles/volume] in Serum or Plasma | 0.925 |  |  0 |         0 |
| 40758717 | OXcarbazepine + 10-Hydroxycarbazepine [Moles/volume] in Serum or Plasma | 0.924 |  |  0 |         0 |
| 3012494 | Peanut IgE Ab [Units/volume] in Serum | 0.924 | 611 |  6 |     1,644 |
| 1761414 | Alkaline phosphatase.macromolecular [Presence] in Serum or Plasma | 0.924 |  |  0 |         0 |
| 3001936 | Carbamazepine 10,11-epoxide free [Mass/volume] in Serum or Plasma | 0.923 |  |  0 |         0 |
| 3000722 | Carnitine free (C0) [Moles/volume] in Serum or Plasma | 0.922 | 1418 |  2 |       347 |
| 3014661 | Parvovirus B19 IgM Ab [Presence] in Serum by Immunoblot | 0.920 |  |  0 |         0 |
| 3026190 | Carbamazepine 10,11-Epoxide.bound [Mass/volume] in Serum or Plasma | 0.920 |  |  0 |         0 |
| 3000384 | Varicella zoster virus DNA [Presence] in Serum by NAA with probe detection | 0.919 |  |  0 |         0 |
| 3035891 | Mumps virus soluble Ab [Titer] in Serum | 0.919 |  |  0 |         0 |
| 3026325 | Ovary Ab [Titer] in Serum by Immunofluorescence | 0.918 |  |  0 |         0 |
| 649057 | Parvovirus B19 IgG Ab [Measurement] in Serum | 0.918 |  |  0 |         0 |
| 3013478 | Mumps virus soluble Ab [Units/volume] in Serum | 0.918 |  |  0 |         0 |
| 3005197 | Varicella zoster virus DNA [Presence] in Blood by NAA with probe detection | 0.918 |  |  0 |         0 |
| 3010054 | Hazelnut Pollen IgE Ab [Units/volume] in Serum | 0.916 | 1650 |  0 |         0 |
| 36204312 | Varicella zoster virus DNA [Presence] in Amniotic fluid by NAA with probe detection | 0.915 |  |  0 |         0 |
| 3007015 | Cashew nut IgE Ab [Units/volume] in Serum | 0.915 | 1084 |  0 |         0 |
| 37021179 | Bordetella parapertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.914 |  |  0 |         0 |
| 3006451 | Walnut IgE Ab [Units/volume] in Serum | 0.914 | 922 |  0 |         0 |
| 3013573 | Cardiolipin IgA Ab [Titer] in Serum | 0.914 |  |  0 |         0 |
| 1761458 | Varicella zoster virus DNA [Log #/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.914 |  |  0 |         0 |
| 36305298 | Varicella zoster virus DNA [Presence] in Aspirate by NAA with probe detection | 0.914 |  |  0 |         0 |
| 3052840 | Varicella zoster virus DNA [#/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.914 |  |  0 |         0 |
| 645719 | Mumps virus Ab [Measurement] in Serum | 0.913 |  |  0 |         0 |
| 40763381 | OXcarbazepine [Moles/volume] in Specimen | 0.912 |  |  0 |         0 |
| 3016120 | Mumps virus IgM Ab [Titer] in Serum by Immunofluorescence | 0.912 |  |  0 |         0 |
| 3004446 | Plasmodium sp identified in Blood by Light microscopy | 0.912 |  |  1 |     1,366 |
| 1091800 | Bordetella parapertussis DNA [Presence] in Bronchoalveolar lavage by NAA with probe detection | 0.912 |  |  0 |         0 |
| 3020147 | Parvovirus B19 IgM Ab [Units/volume] in Serum by Immunoassay | 0.912 | 1013 |  0 |         0 |
| 3011841 | English Walnut IgE Ab [Units/volume] in Serum | 0.912 |  |  3 |       634 |
| 3012202 | Varicella zoster virus DNA [Presence] in Specimen by NAA with probe detection | 0.911 |  |  1 |     2,880 |
| 3035995 | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 0.910 | 23 | 13 | 2,756,532 |
| 3027569 | carBAMazepine.bound [Mass/volume] in Serum or Plasma | 0.909 |  |  0 |         0 |
| 3019271 | Carnitine free (C0) [Presence] in Serum or Plasma | 0.909 |  |  0 |         0 |
| 3013094 | Hepatic function 2000 panel - Serum or Plasma | 0.909 |  |  0 |         0 |
| 3010630 | Parvovirus B19 Ab [Units/volume] in Serum by Immunoassay | 0.908 |  |  0 |         0 |
| 37019602 | Bordetella parapertussis DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.907 |  |  0 |         0 |
| 645926 | Mumps virus IgM Ab [Measurement] in Serum | 0.907 |  |  0 |         0 |
| 3011766 | Ovary Ab [Presence] in Serum by Immunofluorescence | 0.907 |  |  0 |         0 |
| 3011592 | Carotene [Moles/volume] in Serum or Plasma | 0.907 |  |  0 |         0 |
| 646897 | carBAMazepine [Measurement] in Serum or Plasma | 0.905 |  |  0 |         0 |
| 3009118 | Cardiolipin IgA Ab [Units/volume] in Serum by Immunoassay | 0.904 | 887 |  0 |         0 |
| 645763 | Pecan nut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.904 |  |  0 |         0 |
| 3025587 | Parvovirus B19 IgM Ab [Titer] in Serum by Immunofluorescence | 0.903 |  |  0 |         0 |
| 3044690 | Nicotine+Cotinine [Presence] in Urine | 0.903 |  |  0 |         0 |
| 40762708 | Cotinine [Presence] in Urine by Screen method | 0.901 |  |  0 |         0 |
| 1091764 | Bordetella parapertussis DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.900 |  |  0 |         0 |
| 3005398 | Coconut IgE Ab [Units/volume] in Serum | 0.899 | 1916 |  0 |         0 |
| 3035798 | Bile acid.dihydroxy [Moles/volume] in Serum or Plasma | 0.899 |  |  0 |         0 |
| 645154 | Ovary Ab [Measurement] in Serum | 0.899 |  |  0 |         0 |
| 1469600 | Bordetella pertussis DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.898 |  |  0 |         0 |
| 645361 | Hazelnut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.898 |  |  0 |         0 |
| 3047117 | Bordetella pertussis DNA [Presence] in Nasopharynx by NAA with probe detection | 0.898 |  |  0 |         0 |
| 3014431 | Cardiolipin Ab [Units/volume] in Serum by Immunoassay | 0.898 |  |  0 |         0 |
| 3042891 | Cardiolipin IgM Ab [Mass/volume] in Serum | 0.898 |  |  0 |         0 |
| 3043821 | Protein and Glucose panel - Urine by Test strip | 0.898 |  |  0 |         0 |
| 648931 | Acetaminophen [Measurement] in Serum or Plasma | 0.897 |  |  0 |         0 |
| 3034898 | Cotinine [Presence] in Urine by Confirmatory method | 0.897 |  |  0 |         0 |
| 44816864 | carBAMazepine [Mass/volume] in Serum or Plasma --trough | 0.897 |  |  0 |         0 |
| 3023985 | carBAMazepine free [Mass/volume] in Serum or Plasma | 0.897 |  |  0 |         0 |
| 40763889 | Cotinine [Presence] in Serum or Plasma | 0.896 |  |  0 |         0 |
| 3028415 | carBAMazepine [Presence] in Serum or Plasma | 0.896 |  |  0 |         0 |
| 42868672 | Acetaminophen [Moles/volume] in Serum or Plasma by Screen method | 0.896 | 1819 |  0 |         0 |
| 646891 | Cardiolipin Ab [Measurement] in Serum | 0.894 |  |  0 |         0 |
| 3014064 | Pregnancy associated plasma protein A [Multiple of the median] in Serum or Plasma | 0.894 |  |  1 |       461 |
| 3044476 | Bile acid [Presence] in Serum | 0.894 |  |  0 |         0 |
| 3017215 | Carnitine esters [Moles/volume] in Serum or Plasma | 0.894 | 1632 |  0 |         0 |
| 3016201 | Valproate [Mass/volume] in Serum or Plasma | 0.894 |  |  0 |         0 |
| 3023289 | California Walnut IgE Ab [Units/volume] in Serum | 0.891 |  |  0 |         0 |
| 40763007 | OXcarbazepine [Moles/volume] in Urine | 0.891 |  |  0 |         0 |
| 3046159 | Cardiolipin IgG Ab [Mass/volume] in Serum | 0.890 |  |  0 |         0 |
| 649561 | Cotinine [Measurement] in Urine | 0.889 |  |  0 |         0 |
| 3013226 | Pecan or Hickory Nut IgE Ab [Units/volume] in Serum | 0.888 | 1096 |  0 |         0 |
| 3036648 | Ovary Ab [Units/volume] in Serum | 0.888 |  |  0 |         0 |
| 3034882 | Bile acid.trihydroxy [Moles/volume] in Serum or Plasma | 0.887 |  |  0 |         0 |
| 647057 | Hazelnut Pollen IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.886 |  |  0 |         0 |
| 3020846 | Acetaminophen [Moles/volume] in Specimen | 0.886 |  |  0 |         0 |
| 3035400 | Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma | 0.885 | 1919 |  3 |     3,451 |
| 3021600 | Valproate Free [Mass/volume] in Serum or Plasma | 0.884 |  |  0 |         0 |
| 648099 | Peanut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.884 |  |  0 |         0 |
| 3024774 | Black Walnut IgE Ab [Units/volume] in Serum | 0.883 |  |  0 |         0 |
| 46235831 | Pregnancy associated plasma protein A [Multiple of the median] adjusted in Serum or Plasma | 0.883 |  |  2 |    21,810 |
| 3004874 | Cardiolipin IgM Ab [Interpretation] in Serum | 0.882 | 1588 |  0 |         0 |
| 3025355 | Hazelnut IgG Ab [Units/volume] in Serum | 0.880 |  |  0 |         0 |
| 646711 | Parvovirus B19 IgM Ab [Measurement] in Serum | 0.880 |  |  0 |         0 |
| 3026744 | English Walnut Pollen IgE Ab [Units/volume] in Serum | 0.880 |  |  0 |         0 |
| 3965143 | Calprotectin [Mass/volume] in Serum or Plasma | 0.879 |  |  0 |         0 |
| 3024418 | Acetaminophen [Presence] in Specimen | 0.878 |  |  0 |         0 |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.878 |  |  0 |         0 |
| 46235077 | Alkaline phosphatase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.876 |  |  0 |         0 |
| 43055493 | OXcarbazepine [Mass/volume] in Serum or Plasma --trough | 0.876 |  |  0 |         0 |
| 645568 | Cardiolipin IgG Ab [Measurement] in Serum | 0.874 |  |  0 |         0 |
| 647643 | Cashew nut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.874 |  |  0 |         0 |
| 3044715 | Alkaline phosphatase.liver [Presence] in Serum or Plasma | 0.872 |  |  0 |         0 |
| 646486 | English Walnut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.871 |  |  0 |         0 |
| 3007315 | Brazil Nut IgE Ab [Units/volume] in Serum | 0.871 | 1401 |  0 |         0 |
| 3046129 | Acetaminophen+Codeine [Presence] in Serum or Plasma | 0.871 |  |  0 |         0 |
| 3043730 | California Walnut Pollen IgE Ab [Units/volume] in Serum | 0.871 |  |  0 |         0 |
| 40763094 | 10-Hydroxycarbazepine [Mass/volume] in Blood | 0.870 |  |  0 |         0 |
| 646492 | Carnitine [Measurement] in Serum or Plasma | 0.869 |  |  0 |         0 |
| 3020013 | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum or Plasma | 0.868 |  |  9 |     4,096 |
| 3018499 | Cardiolipin IgG Ab [Interpretation] in Serum | 0.868 | 1590 |  0 |         0 |
| 3026863 | Hepatic function 1996 panel - Serum or Plasma | 0.868 |  |  0 |         0 |
| 3001526 | Acetaminophen [Presence] in Urine | 0.868 | 742 |  0 |         0 |
| 3030988 | Plasmodium sp Ag [Presence] in Blood | 0.868 |  |  0 |         0 |
| 3027716 | Peanut IgG Ab [Units/volume] in Serum | 0.867 |  |  0 |         0 |
| 42870499 | Thrombin time actual/Normal | 0.867 | 3000 |  0 |         0 |
| 3015103 | White Alder IgE Ab [Units/volume] in Serum | 0.867 |  |  0 |         0 |
| 3041289 | Cotinine [Presence] in Meconium | 0.865 |  |  0 |         0 |
| 3002214 | Alkaline phosphatase.renal [Enzymatic activity/volume] in Serum or Plasma | 0.864 |  |  0 |         0 |
| 3005080 | Thrombin time in Platelet poor plasma from Control by Coagulation assay | 0.864 |  |  0 |         0 |
| 3003860 | Alkaline phosphatase.regan [Enzymatic activity/volume] in Serum or Plasma | 0.864 |  |  0 |         0 |
| 3007970 | Alkaline phosphatase.bile [Enzymatic activity/volume] in Serum or Plasma | 0.864 |  |  0 |         0 |
| 3025911 | Cotinine [Mass/volume] in Urine | 0.863 | 674 |  0 |         0 |
| 3008076 | Acetaminophen [Presence] in Body fluid | 0.863 |  |  0 |         0 |
| 3016088 | Carotene.alpha [Moles/volume] in Plasma | 0.863 |  |  0 |         0 |
| 3044182 | Acetaminophen+oxyCODONE [Presence] in Serum or Plasma | 0.863 |  |  0 |         0 |
| 3028993 | Alkaline phosphatase.macro/Alkaline phosphatase.total in Serum or Plasma | 0.862 |  |  0 |         0 |
| 3025365 | Pea IgE Ab [Units/volume] in Serum | 0.862 |  |  0 |         0 |
| 3001599 | Carotene [Mass/volume] in Serum or Plasma | 0.862 |  |  0 |         0 |
| 40758694 | Phenacetin [Moles/volume] in Serum or Plasma | 0.862 |  |  0 |         0 |
| 3041451 | Hazelnut IgE Ab/IgE total in Serum | 0.862 |  |  0 |         0 |
| 3025612 | Black Western Walnut IgE Ab [Units/volume] in Serum | 0.861 |  |  0 |         0 |
| 1259873 | Carbamazepine 10,11-Epoxide [Mass/volume] in Urine | 0.861 |  |  0 |         0 |
| 3043181 | Beta 2 glycoprotein 1 IgM Ab [Presence] in Serum | 0.861 |  |  0 |         0 |
| 3966068 | Hazelnut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.861 |  |  0 |         0 |
| 3026187 | Black Walnut Pollen IgE Ab [Units/volume] in Serum | 0.860 |  |  0 |         0 |
| 3028136 | Grey Alder IgE Ab [Units/volume] in Serum | 0.859 |  |  0 |         0 |
| 3040624 | Acetaminophen [Moles/volume] in Urine | 0.857 |  |  0 |         0 |
| 3001467 | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum or Plasma | 0.857 | 1850 | 12 |     5,701 |
| 3000235 | Alkaline phosphatase.placental [Enzymatic activity/volume] in Serum or Plasma | 0.857 |  |  0 |         0 |
| 3051607 | IgM Ab [Presence] in Serum or Plasma | 0.857 |  |  0 |         0 |
| 3965766 | Hazelnut Pollen IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.854 |  |  0 |         0 |
| 3016664 | Ovary IgG Ab [Titer] in Serum by Immunofluorescence | 0.854 |  |  0 |         0 |
| 645515 | Pecan nut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.854 |  |  0 |         0 |
| 3010354 | Pecan or Hickory Tree IgE Ab [Units/volume] in Serum | 0.854 | 1615 |  0 |         0 |
| 3035062 | Alkaline phosphatase.liver 1 [Enzymatic activity/volume] in Serum or Plasma | 0.853 |  | 16 |     2,842 |
| 3031879 | Bile acid fractions panel [Moles/volume] - Serum or Plasma | 0.853 |  |  0 |         0 |
| 3051593 | INR in Capillary blood by Coagulation assay | 0.853 |  |  0 |         0 |
| 3006157 | Reagin Ab [Titer] in Cerebral spinal fluid by VDRL | 0.853 |  |  0 |         0 |
| 3038974 | Carnitine esters/Carnitine.free (C0) [Molar ratio] in Serum or Plasma | 0.853 |  |  0 |         0 |
| 40768790 | Lung Pathology biopsy report | 0.852 |  |  0 |         0 |
| 3042479 | Alkaline phosphatase.bone [Presence] in Serum or Plasma | 0.851 |  |  0 |         0 |
| 3000978 | Cashew nut IgG Ab [Units/volume] in Serum | 0.851 |  |  0 |         0 |
| 1988395 | Hazelnut Pollen IgG Ab [Mass/volume] in Serum | 0.851 |  |  0 |         0 |
| 3036185 | Alkaline phosphatase.liver 2 [Enzymatic activity/volume] in Serum or Plasma | 0.850 |  | 18 |     2,833 |
| 40763008 | OXcarbazepine [Moles/volume] in Gastric fluid | 0.850 |  |  0 |         0 |
| 3045355 | Beta 2 glycoprotein 1 IgG Ab [Presence] in Serum | 0.848 |  |  0 |         0 |
| 40767665 | Peanut recombinant (rAra h) 9 IgE Ab [Units/volume] in Serum | 0.848 |  |  3 |       584 |
| 648629 | Hazelnut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.847 |  |  0 |         0 |
| 3023456 | Valproate Free/Valproate.total in Serum or Plasma | 0.847 |  |  0 |         0 |
| 3964949 | Hazelnut IgG Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.846 |  |  0 |         0 |
| 40768453 | Hazelnut native (nCor a) 9 IgE Ab [Units/volume] in Serum | 0.846 |  |  3 |       524 |
| 40765812 | Hazelnut IgG Ab [Mass/volume] in Serum | 0.846 |  |  0 |         0 |
| 3021905 | Carnitine free (C0)/Carnitine.total in Serum or Plasma | 0.845 |  |  0 |         0 |
| 3966719 | English Walnut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.845 |  |  0 |         0 |
| 3052099 | Cashew nut IgE Ab/IgE total in Serum | 0.844 |  |  0 |         0 |
| 3002446 | Reagin Ab [Presence] in Cerebral spinal fluid by VDRL | 0.844 | 1142 |  0 |         0 |
| 21492784 | Miscellaneous allergen IgE Ab [Units/volume] in Serum | 0.844 |  |  0 |         0 |
| 3045730 | Cotinine [Moles/volume] in Urine | 0.844 |  |  0 |         0 |
| 3041778 | Walnut IgE Ab/IgE total in Serum | 0.843 |  |  0 |         0 |
| 21493397 | A IgG Ab [Presence] in Serum or Plasma | 0.843 |  |  0 |         0 |
| 3019027 | Nicotine [Presence] in Urine | 0.843 |  |  0 |         0 |
| 40768458 | Peanut native (nAra h) 2 IgE Ab [Units/volume] in Serum | 0.843 |  |  0 |         0 |
| 3012731 | Oxazepam [Moles/volume] in Serum or Plasma | 0.843 |  |  0 |         0 |
| 3008517 | Red Alder IgE Ab [Units/volume] in Serum | 0.843 |  |  0 |         0 |
| 3047120 | Alkaline phosphatase.liver+bone [Presence] in Serum or Plasma | 0.843 |  |  0 |         0 |
| 3966731 | Cashew nut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.842 |  |  0 |         0 |
| 3038191 | Carnitine [Moles/volume] in Urine | 0.842 |  |  0 |         0 |
| 21494219 | Acetaminophen free [Mass/volume] in Serum or Plasma | 0.841 |  |  0 |         0 |
| 40760885 | Valproate.free and Valproate panel - Serum or Plasma | 0.841 |  |  0 |         0 |
| 40768459 | Peanut native (nAra h) 3 IgE Ab [Units/volume] in Serum | 0.840 |  |  0 |         0 |
| 3005050 | Acylcarnitine [Moles/volume] in Serum or Plasma | 0.840 |  |  0 |         0 |
| 3033536 | Pecan or Hickory Nut IgG Ab [Units/volume] in Serum | 0.840 |  |  0 |         0 |
| 37019529 | Parasite [Presence] in Blood by Light microscopy | 0.840 |  |  0 |         0 |
| 3016031 | Almond IgE Ab [Units/volume] in Serum | 0.840 | 1024 |  3 |       453 |
| 3965857 | Walnut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.840 |  |  0 |         0 |
| 3014591 | Smooth Alder IgE Ab [Units/volume] in Serum | 0.840 |  |  1 |       131 |
| 40768443 | Skin Pathology biopsy report | 0.840 | 1793 |  1 |    24,633 |
| 3028606 | Oxazepam [Presence] in Serum or Plasma | 0.839 |  |  0 |         0 |
| 3964953 | Coconut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.839 |  |  0 |         0 |
| 40761872 | Peanut recombinant (rAra h) 2 IgE Ab [Units/volume] in Serum | 0.839 |  |  3 |     1,227 |
| 3032298 | Plasmodium stage [Identifier] in Blood by Light microscopy | 0.839 |  |  0 |         0 |
| 40764040 | English Walnut IgE Ab/IgE total in Serum | 0.839 |  |  0 |         0 |
| 3003711 | Beta 2 glycoprotein 1 Ab [Presence] in Serum | 0.839 |  |  0 |         0 |
| 42870305 | Alkaline phosphatase.intestinal 2 [Enzymatic activity/volume] in Serum or Plasma | 0.839 |  |  0 |         0 |
| 3015266 | Ovary IgG Ab [Units/volume] in Serum | 0.838 |  |  0 |         0 |
| 3012689 | House dust Allergopharma IgE Ab [Units/volume] in Serum | 0.838 |  |  0 |         0 |
| 647241 | Brazil Nut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.838 |  |  0 |         0 |
| 3043524 | Pregnancy associated plasma protein A multiple of the median [Percentile] | 0.837 |  |  0 |         0 |
| 3044539 | Alkaline phosphatase.intestinal [Presence] in Serum or Plasma | 0.837 |  |  0 |         0 |
| 42870307 | Alkaline phosphatase.placental 2 [Enzymatic activity/volume] in Serum or Plasma | 0.837 |  |  0 |         0 |
| 40767662 | Cashew nut recombinant (rAna o) 2 IgE Ab [Units/volume] in Serum | 0.836 |  |  0 |         0 |
| 3041601 | Coconut IgE Ab/IgE total in Serum | 0.836 |  |  0 |         0 |
| 3022620 | Valproate [Mass/volume] in Serum or Plasma --trough | 0.836 |  |  0 |         0 |
| 649058 | Ovary IgG Ab [Measurement] in Serum | 0.835 |  |  0 |         0 |
| 40758329 | Carnitine [Moles/volume] in Body fluid | 0.835 |  |  0 |         0 |
| 3034356 | Lactoferrin [Mass/volume] in Stool | 0.835 |  |  0 |         0 |
| 3002670 | Multiple inhalant allergen IgE Ab [Units/volume] in Serum | 0.835 |  |  2 |     4,192 |
| 40768803 | Thyroid Pathology biopsy report | 0.835 |  |  0 |         0 |
| 3038205 | Alternaria alternata IgE Ab [Units/volume] in Serum | 0.834 | 652 |  3 |       151 |
| 3027148 | Coconut IgG Ab [Units/volume] in Serum | 0.833 |  |  0 |         0 |
| 3026217 | Bile acid [Mass/volume] in Serum | 0.833 |  |  0 |         0 |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 0.833 |  |  6 | 1,393,084 |
| 3006046 | Bile acid [Moles/volume] in Serum --2 hours post meal | 0.833 |  |  0 |         0 |
| 40768793 | Breast Pathology biopsy report | 0.833 |  |  2 |    13,464 |
| 40759788 | Carotene.alpha [Mass/volume] in Serum | 0.832 |  |  0 |         0 |
| 40758651 | Acetazolamide [Moles/volume] in Serum or Plasma | 0.832 |  |  0 |         0 |
| 3034550 | Alkaline phosphatase.macrohepatic/Alkaline phosphatase.total in Serum or Plasma | 0.832 |  |  0 |         0 |
| 42528717 | Cashew nut recombinant (rAna o) 3 IgE Ab [Units/volume] in Serum | 0.832 |  |  3 |       635 |
| 3038812 | Alkaline phosphatase.liver 1 [Presence] in Serum or Plasma | 0.831 |  |  0 |         0 |
| 40763980 | Peanut IgE Ab/IgE total in Serum | 0.831 |  |  0 |         0 |
| 3046937 | Carnitine/Acylcarnitine [Molar ratio] in Serum or Plasma | 0.831 |  |  0 |         0 |
| 36659620 | Liver diseases autoimmune Ab panel - Serum or Plasma | 0.830 |  |  0 |         0 |
| 3036941 | Urinalysis complete panel - Urine | 0.829 |  |  0 |         0 |
| 3023949 | Allscale IgE Ab [Units/volume] in Serum | 0.829 |  |  0 |         0 |
| 3045684 | Alkaline phosphatase.other fractions [Enzymatic activity/volume] in Serum or Plasma | 0.829 |  |  3 |     3,363 |
| 3023930 | Acylcarnitine [Presence] in Serum or Plasma | 0.829 |  |  0 |         0 |
| 3001690 | Carnitine free (C0) [Moles/volume] in Urine | 0.828 |  |  0 |         0 |
| 3965181 | English Walnut Pollen IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.828 |  |  0 |         0 |
| 3047319 | Plasmodium sp Ag [Presence] in Blood by Immunoassay | 0.828 |  |  0 |         0 |
| 3013860 | IgM [Presence] in 24 hour Urine by Immunoelectrophoresis | 0.827 |  |  0 |         0 |
| 3019631 | Plasmodium sp identified in Blood by Thick film | 0.826 |  |  0 |         0 |
| 3041117 | Carnitine free (C0) [Moles/volume] in Amniotic fluid | 0.825 |  |  0 |         0 |
| 1001530 | Calprotectin [Mass/volume] in Synovial fluid | 0.824 |  |  0 |         0 |
| 3965196 | Pecan or Hickory Nut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.824 |  |  0 |         0 |
| 3042572 | Alkaline phosphatase.liver 2 [Presence] in Serum or Plasma | 0.824 |  |  0 |         0 |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.824 |  |  0 |         0 |
| 3024473 | Bile acid.dihydroxy [Mass/volume] in Serum or Plasma | 0.823 |  |  0 |         0 |
| 40767667 | Black Alder recombinant (rAln g) 1 IgE Ab [Units/volume] in Serum | 0.823 |  |  0 |         0 |
| 43533747 | Bile acid [Moles/volume] in Urine | 0.823 |  |  0 |         0 |
| 646845 | Carnitine free (C0) [Measurement] in Serum or Plasma | 0.823 |  |  0 |         0 |
| 40761535 | Cells panel - Urine sediment | 0.823 |  |  5 |   111,359 |
| 36306212 | Acetaminophen [Presence] in Blood by Screen method | 0.822 |  |  0 |         0 |
| 3966408 | Brazil Nut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.822 |  |  0 |         0 |
| 42868409 | Thrombin time.high dose in Platelet poor plasma by Coagulation assay | 0.822 |  |  0 |         0 |
| 3965920 | Peanut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.822 |  |  0 |         0 |
| 3039563 | Pecan or Hickory Nut IgE Ab/IgE total in Serum | 0.822 |  |  0 |         0 |
| 3026138 | Bile acid.trihydroxy [Mass/volume] in Serum or Plasma | 0.821 |  |  0 |         0 |
| 647626 | Cashew nut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.820 |  |  0 |         0 |
| 3029954 | Bile acid [Moles/volume] in Body fluid | 0.819 |  |  0 |         0 |
| 3021959 | Cocoa IgE Ab [Units/volume] in Serum | 0.818 |  |  0 |         0 |
| 3040951 | Alkaline phosphatase.placental [Presence] in Serum or Plasma | 0.818 |  |  0 |         0 |
| 40759045 | IgM.monoclonal [Presence] in Serum by Immunoelectrophoresis | 0.818 |  |  0 |         0 |
| 40761533 | Casts panel - Urine sediment | 0.818 |  |  0 |         0 |
| 40766108 | Lactoferrin [Presence] in Stool | 0.818 |  |  0 |         0 |
| 3045820 | Cotinine/Creatinine [Mass Ratio] in Urine | 0.816 |  |  0 |         0 |
| 3014714 | Pregnancy specific protein 1 [Mass/volume] in Serum | 0.816 |  |  0 |         0 |
| 40761831 | Parvovirus B19 IgG and IgM [Interpretation] in Serum | 0.816 |  |  0 |         0 |
| 46235718 | Delta aPTT [Time] in Platelet poor plasma by Coagulation assay | 0.815 |  |  0 |         0 |
| 3964687 | Black Walnut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.815 |  |  0 |         0 |
| 3964683 | Hazelnut recombinant (rCor a) 14 IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.814 |  |  0 |         0 |
| 3011580 | Brazil Nut IgG Ab [Units/volume] in Serum | 0.813 |  |  0 |         0 |
| 3002978 | Plasmodium sp identified in Blood by Thin film | 0.813 |  |  0 |         0 |
| 3966621 | Coconut IgG Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.812 |  |  0 |         0 |
| 40768795 | Lymph node Pathology biopsy report | 0.812 |  |  2 |     5,290 |
| 3018279 | Valproate.protein bound [Mass/volume] in Serum or Plasma | 0.811 |  |  0 |         0 |
| 43533702 | Valproate [Mass/volume] in Serum or Plasma --peak | 0.810 |  |  0 |         0 |
| 3028089 | Alkaline phosphatase isoenzyme [Units/volume] in Serum or Plasma | 0.810 |  |  0 |         0 |
| 40767663 | Brazil Nut recombinant (rBer e) 1 IgE Ab [Units/volume] in Serum | 0.810 |  |  1 |       431 |
| 3044925 | Food Allergen Mix 27 (Hazelnut+Codfish+Soybean+Wheat) IgE Ab [Presence] in Serum by Multidisk | 0.810 |  |  0 |         0 |
| 40768792 | Brain Pathology biopsy report | 0.809 |  |  0 |         0 |
| 3029390 | Protein.monoclonal [Mass/volume] in 24 hour Urine by Electrophoresis | 0.809 |  |  0 |         0 |
| 3966323 | Hazelnut native (nCor a) 9 IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.808 |  |  0 |         0 |
| 3031114 | Protein.monoclonal/Protein.total in 24 hour Urine by Electrophoresis | 0.808 | 1348 |  0 |         0 |
| 3042605 | INR in Platelet poor plasma or blood by Coagulation assay | 0.808 |  |  0 |         0 |
| 40768796 | Uterus Pathology biopsy report | 0.807 |  |  0 |         0 |
| 3008543 | Brazilian Rubber Tree IgE Ab [Units/volume] in Serum | 0.807 |  |  0 |         0 |
| 647838 | Coconut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.807 |  |  0 |         0 |
| 42528738 | Food Allergen Mix 76 (Brazil nut+Coconut+Hazelnut+Almond) IgE Ab [Presence] in Serum by Multidisk | 0.807 |  |  0 |         0 |
| 3011773 | Food Allergen Mix 18 (Peanut+Soybean+Peas) IgE Ab [Presence] in Serum by Multidisk | 0.807 |  |  0 |         0 |
| 3033796 | Food Allergen Mix 22 (Cashew+Pecan or Hickory nut+Walnut+Pistachio) IgE Ab [Presence] in Serum by Multidisk | 0.806 |  |  0 |         0 |
| 3965214 | White Alder IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.806 |  |  0 |         0 |
| 42527969 | Liver diseases autoimmune IgG panel - Serum or Plasma by Line blot | 0.806 |  |  0 |         0 |
| 3012424 | Food Allergen Mix 8 (Brazil nut+Orange+Hazelnut+Apple+Cocoa) IgE Ab [Presence] in Serum by Multidisk | 0.805 |  |  0 |         0 |
| 37021290 | Reagin Ab [Titer] in Cerebral spinal fluid by RPR | 0.805 |  |  0 |         0 |
| 3966550 | California Walnut Pollen IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.804 |  |  0 |         0 |
| 40760081 | Ovary IgG Ab [Presence] in Serum by Immunofluorescence | 0.803 |  |  0 |         0 |
| 3965602 | Peanut IgG Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.803 |  |  0 |         0 |
| 3029287 | Urinalysis microscopic panel [#/volume] - Urine by Automated count | 0.803 |  |  3 |   557,289 |
| 42528739 | Food Allergen Mix 76 (Brazil nut+Coconut+Hazelnut+Almond) IgE Ab RAST class [Presence] in Serum by Multidisk | 0.803 |  |  0 |         0 |
| 3044788 | Reagin Ab [Titer] in Cerebral spinal fluid | 0.803 |  |  0 |         0 |
| 3020368 | Nut Allergen Mix (Cashew+Pecan or Hickory nut+English walnut) IgE Ab [Presence] in Serum by Multidisk | 0.803 |  |  0 |         0 |
| 3041668 | Urinalysis microscopic panel [#/area] - Urine sediment by Automated count | 0.802 |  |  0 |         0 |
| 40761536 | Microorganisms panel - Urine sediment | 0.802 |  |  1 |   144,188 |
| 36031200 | Hepatocellular carcinoma risk panel - Serum or Plasma | 0.802 |  |  0 |         0 |
| 3039364 | Plasmodium sp lactate dehydrogenase [Presence] in Blood | 0.802 |  |  0 |         0 |
| 3007893 | Nutmeg IgE Ab [Units/volume] in Serum | 0.802 |  |  0 |         0 |
| 40768446 | Kidney Pathology biopsy report | 0.801 | 1790 |  1 |     3,432 |
| 3036489 | Thrombin time | 0.801 | 705 | 12 |    40,633 |
| 3965417 | Grey Alder IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.801 |  |  0 |         0 |
| 3020233 | Acid phosphatase [Enzymatic activity/volume] in Serum or Plasma | 0.801 |  |  0 |         0 |
| 40759348 | Coconut IgG4 Ab [Mass/volume] in Serum | 0.800 |  |  0 |         0 |
| 3014366 | Food Allergen Mix 1 (Peanut+Brazil nut+Coconut+Hazelnut+Almond) IgE Ab [Presence] in Serum by Multidisk | 0.799 |  |  0 |         0 |
| 3042333 | Brazil Nut IgE Ab/IgE total in Serum | 0.799 |  |  0 |         0 |
| 40768799 | Ovary Pathology biopsy report | 0.799 |  |  0 |         0 |
| 40765816 | Coconut IgG Ab [Mass/volume] in Serum | 0.798 |  |  0 |         0 |
| 42528740 | Food Allergen Mix 76 (Brazil nut+Coconut+Hazelnut+Almond) IgE Ab [Units/volume] in Serum by Multidisk | 0.798 |  |  0 |         0 |
| 40763973 | Grey Alder IgE Ab/IgE total in Serum | 0.798 |  |  0 |         0 |
| 3044922 | Food Allergen Mix 26 (Peanut+Cow milk+Egg white+Mustard) IgE Ab [Presence] in Serum by Multidisk | 0.798 |  |  0 |         0 |
| 21493052 | Food Allergen Mix 22 (Cashew+Pecan or Hickory nut+Walnut+Pistachio) IgE Ab RAST class [Presence] in Serum by Multidisk | 0.798 |  |  0 |         0 |
| 21492952 | Food Allergen Mix 8 (Brazil nut+Orange+Hazelnut+Apple+Cocoa) IgE Ab RAST class [Presence] in Serum by Multidisk | 0.797 |  |  0 |         0 |
| 3043544 | IgE [Presence] in Serum | 0.797 |  |  0 |         0 |
| 3045239 | IgM [Presence] in 24 hour Urine by Immunofixation | 0.797 |  |  0 |         0 |
| 42528741 | Food Allergen Mix 77 (Kiwi+Cashew nut+Hazel nut+Tomato+Sesame seed) IgE Ab [Presence] in Serum by Multidisk | 0.797 |  |  0 |         0 |
| 42868537 | Multiple inhalant allergen IgE Ab [Presence] in Serum by Immunoassay | 0.796 |  |  0 |         0 |
| 40759329 | Cashew nut IgG4 Ab [Mass/volume] in Serum | 0.796 |  |  0 |         0 |
| 40759042 | IgG.monoclonal [Presence] in Serum by Immunoelectrophoresis | 0.796 |  |  0 |         0 |
| 3039686 | IgE Ab [Presence] in Serum or Plasma | 0.795 |  |  0 |         0 |
| 3027963 | IgG [Presence] in 24 hour Urine by Immunoelectrophoresis | 0.795 |  |  0 |         0 |
| 3028622 | Alkaline phosphatase.lung [Enzymatic activity/volume] in Serum or Plasma | 0.795 |  |  0 |         0 |
| 3048415 | Thrombin time after addition of heparinase in Platelet poor plasma by Coagulation assay | 0.795 |  |  0 |         0 |
| 3017316 | IgM [Presence] in Serum by Immunoelectrophoresis | 0.795 |  |  0 |         0 |
| 3966319 | Peanut recombinant (rAra h) 1 IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.794 |  |  0 |         0 |
| 3030688 | Urinalysis panel - Urine by Automated | 0.794 |  |  0 |         0 |
| 3966031 | Peanut recombinant (rAra h) 5 IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.794 |  |  0 |         0 |
| 3044181 | Bile acid [Presence] in Urine | 0.793 |  |  0 |         0 |
| 3034655 | Protein.monoclonal [Mass/time] in 24 hour Urine by Electrophoresis | 0.793 |  |  0 |         0 |
| 40761534 | Crystals panel - Urine sediment | 0.793 |  |  0 |         0 |
| 3028297 | Cotinine [Mass/volume] in Specimen | 0.793 |  |  0 |         0 |
| 43055646 | Cotinine [Mass/volume] in Urine by Screen method | 0.792 |  |  0 |         0 |
| 3020155 | Valproate Free [Mass/volume] in Saliva (oral fluid) | 0.792 |  |  0 |         0 |
| 3019923 | Valproate [Mass/volume] in Urine | 0.792 |  |  0 |         0 |
| 43055077 | 3-Hydroxysuberate [Moles/volume] in Serum or Plasma | 0.792 |  |  0 |         0 |
| 648128 | Coconut milk IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.792 |  |  0 |         0 |
| 3009194 | Reagin Ab [Presence] in Cerebral spinal fluid | 0.791 |  |  0 |         0 |
| 1617567 | Carnitine free and total and acylcarnitine panel - Serum or Plasma | 0.791 |  |  0 |         0 |
| 40765841 | Cashew nut IgG Ab [Mass/volume] in Serum | 0.791 |  |  0 |         0 |
| 40765840 | Pecan or Hickory Nut IgG Ab [Mass/volume] in Serum | 0.791 |  |  0 |         0 |
| 3966447 | Pecan or Hickory Tree IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.790 |  |  0 |         0 |
| 3019960 | Reagin Ab [Units/volume] in Cerebral spinal fluid by VDRL | 0.790 |  |  0 |         0 |
| 3050655 | Plasmodium sp DNA [Presence] in Blood by NAA with probe detection | 0.789 |  |  0 |         0 |
| 3029371 | Treponema pallidum Ab [Titer] in Cerebral spinal fluid | 0.788 |  |  0 |         0 |
| 3037666 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay | 0.788 |  |  0 |         0 |
| 21492928 | Food Allergen Mix 1 (Peanut+Brazil nut+Coconut+Hazelnut+Almond) IgE Ab RAST class [Presence] in Serum by Multidisk | 0.784 |  |  0 |         0 |
| 3965614 | Smooth Alder IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.784 |  |  0 |         0 |
| 3965040 | Brazil Nut recombinant (rBer e) 1 IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.784 |  |  0 |         0 |
| 3019779 | Phenytoin [Moles/volume] in Serum or Plasma | 0.784 | 356 |  3 |     1,716 |
| 43533749 | Bile acid dihydroxy and trihydroxy panel - Serum or Plasma | 0.783 |  |  0 |         0 |
| 3022515 | Vigabatrin [Moles/volume] in Serum or Plasma | 0.783 |  |  0 |         0 |
| 3036955 | Alkaline phosphatase.liver/Alkaline phosphatase.total in Serum or Plasma | 0.782 | 1664 |  2 |       176 |
| 3043231 | Bile acid [Presence] in Bile fluid | 0.782 |  |  0 |         0 |
| 3036275 | Valproate.bound/Valproate.total in Serum or Plasma | 0.781 |  |  0 |         0 |
| 3026025 | Cotinine cutoff [Mass/volume] in Urine | 0.780 |  |  0 |         0 |
| 3046520 | Rubella virus IgG Ab [Titer] in Cerebral spinal fluid | 0.780 |  |  0 |         0 |
| 3039361 | Rubella virus IgG Ab avidity [Ratio] in Serum by Immunoassay | 0.779 |  |  0 |         0 |
| 3002069 | Alkaline phosphatase.bone/Alkaline phosphatase.total in Serum or Plasma | 0.779 | 1666 |  0 |         0 |
| 3046799 | Rubella virus IgM Ab [Titer] in Cerebral spinal fluid | 0.779 |  |  0 |         0 |
| 3042545 | Alkaline phosphatase.bile/Alkaline phosphatase.total in Serum or Plasma | 0.779 |  |  0 |         0 |
| 3964987 | Alternaria alternata IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.778 |  |  0 |         0 |
| 3011531 | Valproate [Mass/volume] in Body fluid | 0.777 |  |  0 |         0 |
| 3003322 | Carotene [Mass/volume] in Blood | 0.777 |  |  0 |         0 |
| 3048777 | Rickettsia typhi IgG Ab [Titer] in Cerebral spinal fluid | 0.776 |  |  0 |         0 |
| 3039568 | Lactoferrin [Presence] in Stool by Immunoassay | 0.776 |  |  0 |         0 |
| 1617354 | Protein.monoclonal band 1 [Mass/volume] in 24 hour Urine by Electrophoresis | 0.776 |  |  0 |         0 |
| 3051707 | Protein [Mass/volume] in Stool | 0.775 |  |  0 |         0 |
| 3040175 | Thrombin time.factor substitution immediately after addition of XXX in Platelet poor plasma by Coagulation assay | 0.775 |  |  0 |         0 |
| 37020287 | Cotinine [Mass/volume] in Urine by Confirmatory method | 0.774 |  |  0 |         0 |
| 40761135 | Treponema pallidum IgG Ab [Presence] in Cerebral spinal fluid | 0.774 |  |  0 |         0 |
| 3023542 | Coagulation normal/actual in Platelet poor plasma by Prothrombin time (PT) | 0.774 |  |  0 |         0 |
| 647403 | OXcarbazepine [Measurement] in Urine | 0.773 |  |  0 |         0 |
| 21492622 | carBAMazepine free and total trough and 10,11-Epoxide panel - Serum or Plasma | 0.773 |  |  0 |         0 |
| 36659896 | Hepatitis C virus Ab panel - Serum or Plasma | 0.772 |  |  0 |         0 |
| 3044503 | IgG [Presence] in 24 hour Urine by Immunofixation | 0.772 |  |  0 |         0 |
| 3011954 | Neutrophils [Presence] in Stool | 0.771 |  |  0 |         0 |
| 40763346 | carBAMazepine [Presence] in Specimen | 0.771 |  |  0 |         0 |
| 3022217 | INR in Platelet poor plasma by Coagulation assay | 0.771 | 53 |  0 |         0 |
| 3033891 | Prothrombin time (PT) in Platelet poor plasma from Control by Coagulation assay | 0.770 |  |  0 |         0 |
| 3050383 | Rickettsia typhi IgM Ab [Titer] in Cerebral spinal fluid | 0.770 |  |  0 |         0 |
| 1091886 | OXcarbazepine [Presence] in Urine by Confirmatory method | 0.770 |  |  0 |         0 |
| 1761868 | Lipid panel - Serum or Plasma | 0.769 |  |  4 |   529,561 |
| 3049710 | Thrombin time.factor substitution immediately after addition of bovine thrombin in Platelet poor plasma by Coagulation assay | 0.769 |  |  0 |         0 |
| 3044649 | Blood type and Indirect antibody screen panel - Blood | 0.769 |  |  0 |         0 |
| 3030503 | Protein.monoclonal band 2 [Mass/volume] in 24 hour Urine by Electrophoresis | 0.768 |  |  0 |         0 |
| 3013466 | aPTT in Blood by Coagulation assay | 0.768 | 77 |  5 |       334 |
| 42870500 | Reptilase time actual/Normal | 0.768 | 3000 |  0 |         0 |
| 44816535 | Protein.monoclonal band 2 [Mass/time] in 24 hour Urine by Electrophoresis | 0.768 |  |  0 |         0 |
| 3021595 | Phenytoin [Presence] in Serum or Plasma | 0.768 |  |  0 |         0 |
| 3966606 | Prenatal hepatitis B and C panel - Serum or Plasma | 0.767 |  |  0 |         0 |
| 1259476 | Pregabalin [Presence] in Serum or Plasma | 0.767 |  |  0 |         0 |
| 1259794 | Measles virus IgG Ab avidity [Ratio] in Serum by Immunoassay | 0.766 |  |  0 |         0 |
| 3033545 | Rheumatoid factor [Presence] in Cerebral spinal fluid | 0.766 |  |  0 |         0 |
| 1617311 | Time to thrombin peak in Platelet poor plasma by Chromogenic method | 0.765 |  |  0 |         0 |
| 1989080 | Zonulin [Mass/volume] in Stool | 0.765 |  |  0 |         0 |
| 3037839 | Renal function 2000 panel - Serum or Plasma | 0.765 |  |  0 |         0 |
| 3008257 | IgM.monoclonal [Presence] in Serum | 0.765 |  |  0 |         0 |
| 3019603 | Treponema pallidum Ab [Presence] in Cerebral spinal fluid | 0.765 |  |  0 |         0 |
| 3011628 | Adrenal Ab [Presence] in Serum | 0.764 |  |  0 |         0 |
| 3040085 | Rubella virus IgG Ab [Presence] in Cerebral spinal fluid | 0.761 |  |  0 |         0 |
| 3048564 | Hepatitis C virus FibroSURE panel - Serum or Plasma | 0.761 |  |  0 |         0 |
| 1175909 | Lipoprotein metabolism panel - Serum or Plasma | 0.760 |  |  0 |         0 |
| 3017219 | Rubella virus IgM Ab [Presence] in Cerebral spinal fluid | 0.760 |  |  0 |         0 |
| 3965298 | Cocoa IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.759 |  |  0 |         0 |
| 3004702 | Lambda light chains [Presence] in Serum by Electrophoresis | 0.758 |  |  0 |         0 |
| 36660011 | Hepatitis B virus surface Ag panel - Serum or Plasma | 0.758 |  |  0 |         0 |
| 1469682 | Chromosome analysis in Blood by Microarray | 0.757 |  |  0 |         0 |
| 3043043 | IgM.monoclonal [Presence] in Serum by Immunofixation | 0.757 |  |  0 |         0 |
| 648574 | Lactoferrin [Measurement] in Stool | 0.756 |  |  0 |         0 |
| 36304575 | Protein and creatinine panel - Urine | 0.755 |  |  0 |         0 |
| 3006486 | P Ab [Presence] in Serum or Plasma | 0.755 |  |  0 |         0 |
| 3002417 | Prothrombin time (PT) in Blood by Coagulation assay | 0.754 |  |  0 |         0 |
| 3008613 | IgG [Presence] in Serum by Immunoelectrophoresis | 0.754 |  |  0 |         0 |
| 40766287 | aPTT actual/normal in Platelet poor plasma by Coagulation assay | 0.753 |  |  0 |         0 |
| 3013547 | Lactoferrin [Presence] in Stool by Latex agglutination | 0.753 |  |  0 |         0 |
| 3022400 | Rubella virus Ag [Presence] in Cerebral spinal fluid | 0.753 |  |  0 |         0 |
| 40759022 | IgA.monoclonal [Presence] in Serum by Immunoelectrophoresis | 0.752 |  |  0 |         0 |
| 3042300 | Rubella virus Ab [Presence] in Cerebral spinal fluid | 0.752 |  |  0 |         0 |
| 3042044 | Coproporphyrin [Mass/mass] in Stool | 0.751 |  |  0 |         0 |
| 3015916 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma | 0.750 |  |  2 |    18,403 |
| 3009762 | IgM [Presence] in Serum by Immunofixation | 0.750 |  |  0 |         0 |
| 40759632 | Porphyrins [Mass/mass] in Stool | 0.750 |  |  1 |        53 |
| 40759024 | IgD.monoclonal [Presence] in Serum by Immunoelectrophoresis | 0.748 |  |  0 |         0 |
| 40762025 | Protoporphyrin [Mass/mass] in Stool | 0.747 |  |  0 |         0 |
| 3044630 | ABO and Rh group panel - Blood | 0.747 |  |  0 |         0 |
| 1616347 | PCA-Tr Ab [Presence] in Serum | 0.746 |  |  0 |         0 |
| 40757377 | Protein and Glucose panel [Mass/volume] - Body fluid | 0.746 |  |  0 |         0 |
| 1175300 | Liver cancer antibodies and AFP panel - Serum or Plasma by Immunoassay | 0.746 |  |  0 |         0 |
| 40765089 | Chromosome analysis panel - Blood by G-banded | 0.745 |  |  1 |     1,888 |
| 3022295 | Zinc [Mass/mass] in Stool | 0.744 |  |  0 |         0 |
| 3005692 | Protoporphyrin [Mass/volume] in Stool | 0.743 |  |  0 |         0 |
| 21493510 | Constitutive heterochromatin analysis in Blood or Tissue by Banding | 0.743 |  |  0 |         0 |
| 36659717 | Hepatitis A virus IgM panel - Serum | 0.743 |  |  0 |         0 |
| 3005803 | Carotene [Mass/volume] in Serum --post 15000 U carotene QDx3 for 3 day poly | 0.742 |  |  0 |         0 |
| 3050932 | Hepatitis A virus Ab panel - Serum | 0.740 |  |  0 |         0 |
| 3009652 | Porphyrins [Mass/volume] in Stool | 0.739 |  |  0 |         0 |
| 3044927 | Protein electrophoresis panel - Urine | 0.739 |  |  1 |     4,606 |
| 3025053 | Alpha-1-Fetoprotein [Presence] in Serum or Plasma | 0.739 |  |  0 |         0 |
| 3035602 | Porphyrins [Presence] in Stool | 0.738 |  |  0 |         0 |
| 42529056 | Liver cytosol IgG Ab [Presence] in Serum by Line blot | 0.733 |  |  0 |         0 |
| 42868442 | PCA-1 IgG Ab [Presence] in Serum by Immunoassay | 0.733 |  |  0 |         0 |
| 3005353 | Prothrombin activity actual/normal in Platelet poor plasma by Coagulation assay | 0.732 |  |  3 |     1,839 |
| 3046513 | Cardiolipin IgA and IgG and IgM panel - Serum | 0.732 |  |  0 |         0 |
| 36303714 | Connective tissue autoimmune Ab panel - Serum | 0.731 |  |  0 |         0 |
| 3002681 | Prothrombin Ag actual/normal in Platelet poor plasma by Immunoassay | 0.728 |  |  0 |         0 |
| 3012487 | Cardiolipin IgG and IgM panel - Serum | 0.728 |  |  0 |         0 |
| 40758523 | Protein and Glucose panel - Cerebral spinal fluid | 0.728 |  |  0 |         0 |
| 42529189 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma by Immunoassay | 0.726 |  |  0 |         0 |
| 3013176 | Coagulation normal/actual in Platelet poor plasma by aPTT | 0.725 |  |  0 |         0 |
| 1002070 | Acarboxyprothrombin [Units/volume] in Serum or Plasma | 0.725 |  |  0 |         0 |
| 3038141 | Acute hepatitis 2000 panel - Serum | 0.725 |  |  0 |         0 |
| 3034965 | Elastase.pancreatic [Presence] in Stool | 0.724 |  |  0 |         0 |
| 3015075 | Pear IgG Ab [Units/volume] in Serum | 0.724 |  |  0 |         0 |
| 3034426 | Prothrombin time (PT) | 0.723 | 47 |  1 |     1,808 |
| 3007308 | Glucose [Presence] in 24 hour Urine | 0.723 |  |  0 |         0 |
| 1002418 | Chromosome analysis in Blood or Tissue by Microarray | 0.722 |  |  0 |         0 |
| 3016290 | aPTT in Blood from Control by Coagulation assay | 0.720 |  |  0 |         0 |
| 3030180 | Alpha-1-Fetoprotein [Multiple of the median] adjusted for multiple gestations in Serum or Plasma | 0.720 |  |  0 |         0 |
| 1002448 | ABO and Rh group panel - Blood from Blood product unit | 0.718 |  |  0 |         0 |
| 3013005 | Retinol [Moles/volume] in Serum or Plasma | 0.717 | 942 |  3 |     4,735 |
| 3029645 | Glucose screen gestational panel - Urine and Serum or Plasma | 0.716 |  |  0 |         0 |
| 645854 | Glucose [Measurement] in Urine | 0.716 |  |  0 |         0 |
| 3009261 | Glucose [Presence] in Urine by Test strip | 0.715 | 309 | 10 |   946,600 |
| 3024370 | Alpha-1-Fetoprotein [Multiple of the median] in Serum or Plasma | 0.714 | 1109 |  0 |         0 |
| 1091858 | Prothrombin time (PT) factor substitution [Time Ratio] in Control Platelet poor plasma by Coagulation assay --2H post incubation with 1:1 normal plasma | 0.714 |  |  0 |         0 |
| 3003169 | Glucose tolerance 2 hours gestational panel - Urine and Serum or Plasma | 0.712 |  |  0 |         0 |
| 40758476 | Coagulation ecarin induced in Blood by Coagulation assay | 0.712 |  |  0 |         0 |
| 3024597 | Carnosine [Moles/volume] in Serum or Plasma | 0.712 |  |  0 |         0 |
| 46236024 | Chromosome analysis basic associated observations panel - Blood or Tissue by Cytogenetics | 0.708 |  |  0 |         0 |
| 3016670 | Alpha-1-Fetoprotein [Multiple of the median] adjusted in Serum or Plasma | 0.708 | 609 |  0 |         0 |
| 40762271 | Insulin [Moles/volume] in Serum or Plasma --fasting | 0.704 |  |  0 |         0 |
| 44816799 | Beta sitosterol [Moles/volume] in Serum or Plasma | 0.698 |  |  0 |         0 |
| 1001651 | Rh antigens and K Ag panel - Blood | 0.697 |  |  0 |         0 |
| 40763950 | INR in Platelet poor plasma from Fetus by Coagulation assay | 0.697 |  |  0 |         0 |
| 1001606 | ABO and Rh group post transfusion reaction panel - Blood | 0.697 |  |  0 |         0 |
| 1002100 | ABO and Rh group post hematopoietic stem cell transplant panel - Blood | 0.696 |  |  0 |         0 |
| 3053181 | Prothrombin time (PT) in Capillary blood by Coagulation assay | 0.695 |  |  0 |         0 |
| 3046154 | Alpha-1-Fetoprotein [Multiple of the median] adjusted for diabetes in Serum or Plasma | 0.695 |  |  0 |         0 |
| 1001763 | ABO and Rh group panel - Cord blood | 0.695 |  |  0 |         0 |
| 1001526 | Blood group antigens panel - Red Blood Cells | 0.694 |  |  0 |         0 |
| 3025864 | Chromosome 21 trisomy [Presence] in Blood or Tissue by Cytogenetics | 0.693 |  |  0 |         0 |
| 40765085 | Chromosome analysis.metaphase panel - Blood by FISH | 0.691 |  |  0 |         0 |
| 40765096 | Chromosome analysis panel by Banding | 0.690 |  |  2 |     1,425 |
| 1002410 | Rh antigens and K Ag panel - Blood from Blood product unit | 0.688 |  |  0 |         0 |
| 3049559 | Karyotype [Identifier] in Blood or Tissue by High resolution Nominal | 0.688 |  |  0 |         0 |
| 40765090 | Chromosome analysis panel - Blood from Fetus by G-banded | 0.687 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 948 | -calpro | mg/l | 368 | 0 | [0.1, 0.31, 0.88, 2.86, 7.72, 16.73, 36.68, 74.3, 206.67] |  |  |  | Calprotectin [Mass/volume] in Stool | FALSE |
| 949 | -calpro | ug/g | 37 | 0 |  |  |  |  | Calprotectin [Mass/mass] in Stool | FALSE |
| 950 | -calpro |  | 23 | 21.74 |  |  |  |  | Calprotectin [Presence] in Stool | FALSE |
| 951 | 4184sk-padihot |  | 107 | 100 |  |  |  |  | Tissue Pathology biopsy report | FALSE |
| 952 | b-karyot |  | 686 | 100 |  |  | Blood |  | Karyotype in Blood by Constitutional chromosomal analysis | FALSE |
| 953 | b-malarv |  | 127 | 100 |  |  | Blood |  | Plasmodium sp [Presence] in Blood by Light microscopy | FALSE |
| 954 | b-nakkrea |  | 424 | 100 |  |  | Blood |  |  | FALSE |
| 955 | b-pakk-e |  | 249 | 100 |  |  | Blood |  |  | FALSE |
| 956 | b-vara |  | 254 | 100 |  |  | Blood |  | Blood type and Crossmatch panel - Blood | TRUE |
| 957 | b-varaspr |  | 331 | 99.7 |  |  | Blood |  | Blood type and Crossmatch panel - Blood | TRUE |
| 958 | b.parapert |  | 619 | 100 |  |  |  |  | Bordetella parapertussis DNA [Presence] in Blood by NAA with probe detection | FALSE |
| 959 | du-parprot |  | 369 | 100 |  |  | 24-hour urine |  | Protein M-spike [Presence] in 24 hour Urine by Electrophoresis | FALSE |
| 960 | f-calpro | ug/g | 144892 | 0.48 | [13.78, 23.28, 35.55, 53.95, 82, 128.24, 215.34, 397.8, 911.98] | F -Kalprotektiini; F -Calprotectin | Feces |  | Calprotectin [Mass/mass] in Stool | FALSE |
| 961 | f-calpro |  | 17874 | 100 | [23.61, 33.46, 47.58, 74.67, 119.83, 157.1, 290.01, 478.43, 993.36] | F -Kalprotektiini; F -Calprotectin | Feces |  | Calprotectin [Presence] in Stool | FALSE |
| 962 | f-calpro2 | ug/g | 395 | 0 | [28.88, 40.5, 54.65, 82.87, 126.54, 220.92, 330.47, 583.74, 1304.77] |  | Feces |  | Calprotectin [Mass/mass] in Stool | FALSE |
| 963 | f-calpro2 |  | 97 | 100 |  |  | Feces |  | Calprotectin [Presence] in Stool | FALSE |
| 964 | fs-bkarot | nmol/l | 18 | 0 |  | fS-Beetakaroteeni | Fasting serum |  | Carotene.beta [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 965 | fs-bkarot | umol/l | 318 | 0 | [0.25, 0.45, 0.6, 0.75, 0.87, 1.06, 1.29, 1.57, 2.19] | fS-Beetakaroteeni | Fasting serum |  | Carotene.beta [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 966 | fs-sappih | umol/l | 5416 | 0.04 | [1.58, 2, 2.4, 3, 3.74, 4.45, 5.67, 7.59, 13.61] |  | Fasting serum |  | Bile acids.total [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 967 | fs-sappih |  | 686 | 100 | [2, 2.48, 3.02, 3.91, 4.81, 5.88, 6.86, 8.3, 12.54] |  | Fasting serum |  | Bile acids.total [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 968 | fs-sappihapot | umol/l | 198 | 0 | [1.41, 1.79, 2.06, 2.5, 3.2, 3.97, 4.98, 6.66, 11.59] |  | Fasting serum |  | Bile acids.total [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 969 | fs-sappihapot |  | 30 | 100 |  |  | Fasting serum |  | Bile acids.total [Presence] in Serum or Plasma --fasting | FALSE |
| 970 | li-kardab | titre | 7 | 14.29 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  | VDRL [Titer] in Cerebral spinal fluid | FALSE |
| 971 | li-kardab |  | 204 | 100 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  | VDRL [Presence] in Cerebral spinal fluid | FALSE |
| 972 | li-varlikv |  | 111 | 100 |  |  | Cerebrospinal fluid |  | Varicella zoster virus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 973 | p-kardabg | gpl | 1101 | 6.99 | [1, 1, 1.61, 2, 2, 3, 5.05, 7.62, 12.35] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 974 | p-kardabg | u/ml | 4443 | 0 | [1, 1, 1.08, 2, 2, 2.64, 3.48, 5.89, 13.12] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 975 | p-kardabg |  | 4985 | 95.25 | [1, 1.14, 2, 2, 3.36, 5, 5.97, 9.03, 19.8] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  | Cardiolipin IgG Ab [Presence] in Serum or Plasma | FALSE |
| 976 | p-kardabm | mpl | 1111 | 5.04 | [1, 2, 2, 2.88, 3, 4.6, 7.59, 12.86, 20.09] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma | FALSE |
| 977 | p-kardabm | u/ml | 11 | 0 |  | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma | FALSE |
| 978 | p-kardabm |  | 724 | 89.09 | [1, 1, 1.45, 2, 2, 3, 4, 6, 15] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  | Cardiolipin IgM Ab [Presence] in Serum or Plasma | FALSE |
| 979 | p-pakk-si |  | 260 | 100 |  |  | Plasma |  |  | FALSE |
| 980 | p-varainr |  | 8332 | 99.99 |  |  | Plasma |  | INR in Blood by Coagulation assay | FALSE |
| 981 | p-varmtr | s | 1488 | 0 | [17.02, 18, 18.87, 19, 19.98, 20, 21, 21.93, 23] |  | Plasma |  | Thrombin time [Time] in Platelet poor plasma | FALSE |
| 982 | p-varmtr |  | 111 | 100 |  |  | Plasma |  | Thrombin time [Time] in Platelet poor plasma | FALSE |
| 983 | p-varmtt | % | 1494 | 0 | [41.91, 74.69, 84.09, 92.24, 98.54, 104.26, 111.28, 119.13, 131.18] |  | Plasma |  | Prothrombin time (PT) actual/Normal | FALSE |
| 984 | p-varmtt |  | 105 | 100 |  |  | Plasma |  | Prothrombin time (PT) actual/Normal | FALSE |
| 985 | s-afmakro | u/l | 2842 | 0 | [3.98, 5.01, 6.23, 7.94, 10.06, 14.01, 21.13, 33.22, 62.9] |  | Serum |  | Alkaline phosphatase.macro [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 986 | s-afmakro |  | 523 | 59.85 | [4, 5, 6, 7.5, 10, 15.29, 22.33, 30.86, 49.44] |  | Serum |  | Alkaline phosphatase.macro [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 987 | s-afmaks1 | u/l | 199 | 0 | [25.36, 33.2, 41.05, 48.96, 56.78, 64.23, 71.62, 84.6, 112.64] |  | Serum |  | Alkaline phosphatase macroenzyme fraction 1 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 988 | s-afmaks1 |  | 13 | 0 |  |  | Serum |  | Alkaline phosphatase macroenzyme fraction 1 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 989 | s-afmaks2 | u/l | 205 | 0 | [3.2, 4.72, 5.48, 6.4, 7, 8.07, 11.08, 16.5, 34.56] |  | Serum |  | Alkaline phosphatase macroenzyme fraction 2 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 990 | s-afmaks2 |  | 7 | 14.29 |  |  | Serum |  | Alkaline phosphatase macroenzyme fraction 2 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 991 | s-afmaksa | % | 94 | 0 | [39.9, 51.85, 57.9, 64.48, 69.3, 73.65, 78.41, 84.08, 89.4] |  | Serum |  | Alkaline phosphatase.macro/Alkaline phosphatase.total [Enzymatic activity ratio] in Serum | FALSE |
| 992 | s-afmaksa | u/l | 2958 | 0 | [25.04, 37.52, 47.03, 56.68, 67.64, 79.81, 95.37, 125.6, 201.78] |  | Serum |  | Alkaline phosphatase.macro [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 993 | s-afmaksa |  | 489 | 65.03 | [32.9, 45.51, 57.63, 71.86, 79.96, 85.36, 96.57, 123.73, 246.45] |  | Serum |  | Alkaline phosphatase.macro [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 994 | s-caspähe | u/ml | 895 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.04, 0.13, 1.71] |  | Serum |  | Allergen.f202 Cashew nut IgE Ab [Units/volume] in Serum | FALSE |
| 995 | s-caspähe |  | 106 | 80.19 |  |  | Serum |  | Allergen.f202 Cashew nut IgE Ab [Presence] in Serum | FALSE |
| 996 | s-haspähe | u/ml | 683 | 0.15 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  | Allergen.f17 Hazelnut IgE Ab [Units/volume] in Serum | FALSE |
| 997 | s-haspähe |  | 162 | 73.46 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  | Allergen.f17 Hazelnut IgE Ab [Presence] in Serum | FALSE |
| 998 | s-hasspäe | u/ml | 476 | 1.05 | [0, 0.01, 0.03, 0.29, 1.1, 3.4, 6.79, 13.75, 30.06] |  | Serum |  | Allergen.f17 Hazelnut IgE Ab [Units/volume] in Serum | FALSE |
| 999 | s-hasspäe |  | 72 | 54.17 |  |  | Serum |  | Allergen.f17 Hazelnut IgE Ab [Presence] in Serum | FALSE |
| 1000 | s-karba | umol/l | 3476 | 0.06 | [18.5, 22.32, 25.2, 27.69, 29.91, 32.56, 35.34, 38.81, 44.25] | S -Karbamatsepiini | Serum |  | Carbamazepine [Moles/volume] in Serum or Plasma | FALSE |
| 1001 | s-karba |  | 1101 | 59.49 | [18.42, 22.33, 25.59, 27.84, 29.91, 31.7, 34.15, 37.84, 41.83] | S -Karbamatsepiini | Serum |  | Carbamazepine [Moles/volume] in Serum or Plasma | FALSE |
| 1002 | s-karbae | umol/l | 88 | 0 |  | S -Karbamatsepiiniepoksidi | Serum |  | Carbamazepine-10,11-epoxide [Moles/volume] in Serum or Plasma | FALSE |
| 1003 | s-karbae |  | 21 | 100 |  | S -Karbamatsepiiniepoksidi | Serum |  | Carbamazepine-10,11-epoxide [Presence] in Serum or Plasma | FALSE |
| 1004 | s-kardab | titre | 1640 | 0 | [0, 1, 1.58, 2, 2.38, 4, 8.71, 19.26, 62.28] | S -Kardiolipiini, vasta-aineet | Serum |  | Cardiolipin Ab [Titer] in Serum | FALSE |
| 1005 | s-kardab |  | 14614 | 99.49 |  | S -Kardiolipiini, vasta-aineet | Serum |  | Cardiolipin Ab [Presence] in Serum | FALSE |
| 1006 | s-kardabg | gpl | 222 | 29.28 | [6, 7, 8, 9, 11, 14.4, 18.14, 24.7, 40.7] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 1007 | s-kardabg | u/ml | 83 | 0 | [1, 1, 2, 2, 2.25, 3, 4, 7.3, 23] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 1008 | s-kardabg |  | 1591 | 94.97 | [1, 2, 2, 4.55, 7, 8, 9, 11, 27] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  | Cardiolipin IgG Ab [Presence] in Serum or Plasma | FALSE |
| 1009 | s-kardabm | mpl | 359 | 18.11 | [10, 11.36, 12, 13.78, 15, 17.69, 23.08, 30.86, 52.98] | S -Kardiolipiini, IgM-vasta-aineet | Serum |  | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma | FALSE |
| 1010 | s-kardabm |  | 1672 | 96.29 |  | S -Kardiolipiini, IgM-vasta-aineet | Serum |  | Cardiolipin IgM Ab [Presence] in Serum or Plasma | FALSE |
| 1011 | s-karni | umol/l | 328 | 0 | [17.78, 24.87, 29.09, 33.28, 36.28, 39.87, 43.86, 49.4, 55.76] | S -Karnitiini | Serum |  | Carnitine.total [Moles/volume] in Serum or Plasma | FALSE |
| 1012 | s-karni |  | 16 | 100 |  | S -Karnitiini | Serum |  | Carnitine.total [Presence] in Serum or Plasma | FALSE |
| 1013 | s-karni-v | umol/l | 342 | 0 | [11.86, 16.35, 19.2, 22.24, 25.07, 27.94, 30.82, 35, 41.74] | S -Karnitiini, vapaa | Serum | Free or unconjugated | Carnitine.free [Moles/volume] in Serum or Plasma | FALSE |
| 1014 | s-karni-v |  | 7 | 85.71 |  | S -Karnitiini, vapaa | Serum | Free or unconjugated | Carnitine.free [Presence] in Serum or Plasma | FALSE |
| 1015 | s-koopähe | u/ml | 83 | 0 | [0.02, 0.02, 0.03, 0.04, 0.06, 0.11, 0.2, 0.31, 0.85] | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  | Allergen.f36 Coconut IgE Ab [Units/volume] in Serum | FALSE |
| 1016 | s-koopähe |  | 65 | 78.46 |  | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  | Allergen.f36 Coconut IgE Ab [Presence] in Serum | FALSE |
| 1017 | s-leppäe | u/ml | 196 | 0.51 | [0, 0.01, 0.01, 0.02, 0.06, 0.22, 0.9, 2.7, 6.69] | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  | Allergen.t2 Alder IgE Ab [Units/volume] in Serum | FALSE |
| 1018 | s-leppäe |  | 167 | 86.23 |  | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  | Allergen.t2 Alder IgE Ab [Presence] in Serum | FALSE |
| 1019 | s-maapähe | u/ml | 1974 | 0.81 | [0.01, 0.02, 0.05, 0.1, 0.19, 0.37, 0.71, 1.55, 5.76] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  | Allergen.f13 Peanut IgE Ab [Units/volume] in Serum | FALSE |
| 1020 | s-maapähe |  | 2541 | 94.14 | [0.04, 0.11, 0.15, 0.24, 0.38, 0.57, 1.12, 1.88, 3.68] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  | Allergen.f13 Peanut IgE Ab [Presence] in Serum | FALSE |
| 1021 | s-maksa |  | 108 | 100 |  |  | Serum |  | Alkaline phosphatase.macro [Presence] in Serum or Plasma | FALSE |
| 1022 | s-maksa-1 | u/l | 115 | 0 | [31.15, 42.45, 51.29, 60.72, 65.7, 69.64, 79.3, 87.8, 100.66] |  | Serum |  | Alkaline phosphatase macroenzyme fraction 1 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1023 | s-maksa-1 |  | 6 | 16.67 |  |  | Serum |  | Alkaline phosphatase macroenzyme fraction 1 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1024 | s-maksa-2 | u/l | 110 | 0 | [3.95, 4.95, 5.9, 6.88, 7.37, 8.14, 9.54, 13.38, 18.4] |  | Serum |  | Alkaline phosphatase macroenzyme fraction 2 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1025 | s-maksa-2 |  | 12 | 8.33 |  |  | Serum |  | Alkaline phosphatase macroenzyme fraction 2 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1026 | s-maksa1 | u/l | 134 | 0 | [36.7, 43.4, 53.05, 58.95, 67.89, 79.32, 89.06, 98.11, 147.2] |  | Serum |  | Alkaline phosphatase macroenzyme fraction 1 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1027 | s-maksa1 |  | 9 | 66.67 |  |  | Serum |  | Alkaline phosphatase macroenzyme fraction 1 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1028 | s-maksa2 | u/l | 132 | 0 | [4, 5, 6, 7.35, 9, 10.85, 14.35, 21.6, 43.05] |  | Serum |  | Alkaline phosphatase macroenzyme fraction 2 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1029 | s-maksa2 |  | 11 | 81.82 |  |  | Serum |  | Alkaline phosphatase macroenzyme fraction 2 [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 1030 | s-maksaab |  | 1108 | 100 |  |  | Serum |  | Liver autoantibodies panel - Serum | TRUE |
| 1031 | s-maksap |  | 147 | 100 |  |  | Serum |  | Hepatic function panel - Serum or Plasma | TRUE |
| 1032 | s-makspak |  | 778 | 100 |  |  | Serum |  | Hepatic function panel - Serum or Plasma | TRUE |
| 1033 | s-ohkarba | umol/l | 4080 | 0.02 | [27.1, 35.97, 41.95, 47.99, 54.61, 61.42, 68.9, 80.34, 98.86] | S -Hydroksikarbatsepiini (10-) | Serum |  | 10-Hydroxycarbazepine [Moles/volume] in Serum or Plasma | FALSE |
| 1034 | s-ohkarba |  | 797 | 53.58 | [25.02, 33.78, 40.6, 47.36, 53.64, 59.31, 68.63, 83.49, 103.17] | S -Hydroksikarbatsepiini (10-) | Serum |  | 10-Hydroxycarbazepine [Moles/volume] in Serum or Plasma | FALSE |
| 1035 | s-okarba | umol/l | 163 | 10.43 | [0.4, 0.4, 0.8, 0.8, 0.8, 1, 1.2, 2, 2.28] | S -Okskarbatsepiini | Serum |  | Oxcarbazepine [Moles/volume] in Serum or Plasma | FALSE |
| 1036 | s-okarba |  | 168 | 92.26 |  | S -Okskarbatsepiini | Serum |  | Oxcarbazepine [Presence] in Serum or Plasma | FALSE |
| 1037 | s-ovarab | titre | 22 | 9.09 |  | S -Munasarja, vasta-aineet | Serum |  | Ovary Ab [Titer] in Serum | FALSE |
| 1038 | s-ovarab |  | 250 | 99.2 |  | S -Munasarja, vasta-aineet | Serum |  | Ovary Ab [Presence] in Serum | FALSE |
| 1039 | s-pakast5 |  | 880 | 100 |  |  | Serum |  |  | FALSE |
| 1040 | s-pakast7 |  | 106 | 100 |  |  | Serum |  |  | FALSE |
| 1041 | s-pakaste |  | 345 | 100 |  |  | Serum |  |  | FALSE |
| 1042 | s-pakkas |  | 1423 | 100 |  |  | Serum |  |  | FALSE |
| 1043 | s-pakkase |  | 262 | 100 |  |  | Serum |  |  | FALSE |
| 1044 | s-pakkask |  | 1061 | 100 |  |  | Serum |  |  | FALSE |
| 1045 | s-pakkasl |  | 919 | 100 |  |  | Serum |  |  | FALSE |
| 1046 | s-pakkasn |  | 563 | 100 |  |  | Serum |  |  | FALSE |
| 1047 | s-pakkasv |  | 357 | 100 |  |  | Serum |  |  | FALSE |
| 1048 | s-papp-a | mu/l | 533 | 0 | [227.4, 357.69, 452.41, 562.07, 709.24, 895.85, 1154.59, 1409.1, 2163.11] |  | Serum |  | Pregnancy-associated plasma protein A [Units/volume] in Serum | FALSE |
| 1049 | s-papp-a |  | 338 | 2.37 | [167.71, 318.34, 452.63, 572.23, 702.5, 894.09, 1122.57, 1356.65, 1789.1] |  | Serum |  | Pregnancy-associated plasma protein A [Units/volume] in Serum | FALSE |
| 1050 | s-pappa | form | 136 | 0 | [318.92, 443.67, 549.54, 657.05, 734.74, 894.71, 1259.38, 1647.76, 2113.41] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  | Pregnancy-associated plasma protein A [Units/volume] in Serum | FALSE |
| 1051 | s-pappa | mu/l | 41976 | 0 | [274.01, 424.82, 564.51, 708.65, 861.85, 1046.47, 1281.47, 1624.11, 2236.83] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  | Pregnancy-associated plasma protein A [Units/volume] in Serum | FALSE |
| 1052 | s-pappa |  | 357 | 100 | [254.51, 396.2, 527.37, 666.3, 821.3, 1003.01, 1225.19, 1551.35, 2139.86] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  | Pregnancy-associated plasma protein A [Presence] in Serum | FALSE |
| 1053 | s-pappmom | mom | 461 | 0 | [0.48, 0.64, 0.76, 0.89, 1.03, 1.22, 1.42, 1.67, 2.13] |  | Serum |  | Pregnancy-associated plasma protein A [MoM] in Serum | FALSE |
| 1054 | s-parapäe | u/ml | 829 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.02, 0.06, 0.35] |  | Serum |  | Allergen.f18 Brazil nut IgE Ab [Units/volume] in Serum | FALSE |
| 1055 | s-parapäe |  | 34 | 61.76 |  |  | Serum |  | Allergen.f18 Brazil nut IgE Ab [Presence] in Serum | FALSE |
| 1056 | s-paras | umol/l | 2680 | 3.1 | [16.09, 27.95, 44.46, 65.68, 102.63, 158.13, 258.09, 473.45, 862.14] | S -Parasetamoli | Serum |  | Acetaminophen [Moles/volume] in Serum or Plasma | FALSE |
| 1057 | s-paras |  | 2490 | 99.24 |  | S -Parasetamoli | Serum |  | Acetaminophen [Presence] in Serum or Plasma | FALSE |
| 1058 | s-paroab |  | 212 | 100 |  | S -Sikotautivirus, vasta-aineet | Serum |  | Mumps virus Ab [Presence] in Serum | FALSE |
| 1059 | s-paroabg | au/ml | 72 | 0 | [14.1, 32.2, 47.68, 60.86, 78.93, 100.49, 117, 176, 216] | S -Sikotautivirus, IgG-vasta-aineet | Serum |  | Mumps virus IgG Ab [Units/volume] in Serum | FALSE |
| 1060 | s-paroabg | titre | 45 | 0 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  | Mumps virus IgG Ab [Titer] in Serum | FALSE |
| 1061 | s-paroabg |  | 172 | 91.86 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  | Mumps virus IgG Ab [Presence] in Serum | FALSE |
| 1062 | s-paroabm |  | 197 | 98.98 |  | S -Sikotautivirus, IgM-vasta-aineet | Serum |  | Mumps virus IgM Ab [Presence] in Serum | FALSE |
| 1063 | s-parprot |  | 1578 | 100 |  |  | Serum |  | Protein M-spike [Presence] in Serum by Electrophoresis | FALSE |
| 1064 | s-parpäh | u/ml | 67 | 0 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  | Allergen.f18 Brazil nut IgE Ab [Units/volume] in Serum | FALSE |
| 1065 | s-parpäh |  | 184 | 96.2 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  | Allergen.f18 Brazil nut IgE Ab [Presence] in Serum | FALSE |
| 1066 | s-parvab |  | 3096 | 100 |  | S -Parvovirus, vasta-aineet | Serum |  | Parvovirus B19 Ab [Presence] in Serum | FALSE |
| 1067 | s-parvabg | eiu | 67 | 0 | [10, 35, 50, 61, 71.88, 80.25, 90, 90, 100] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Units/volume] in Serum | FALSE |
| 1068 | s-parvabg | ie/ml | 5 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Units/volume] in Serum | FALSE |
| 1069 | s-parvabg | index | 250 | 0 | [10.1, 15.96, 22.67, 26.36, 30.21, 33.04, 36.98, 39.69, 42.76] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Index] in Serum | FALSE |
| 1070 | s-parvabg | iu/ml | 57 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Units/volume] in Serum | FALSE |
| 1071 | s-parvabg | titre | 558 | 0 | [200, 400, 800, 800, 800, 1555.56, 1600, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Titer] in Serum | FALSE |
| 1072 | s-parvabg |  | 2056 | 91.73 | [4.91, 11.45, 38.67, 122.23, 400, 800, 800, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Presence] in Serum | FALSE |
| 1073 | s-parvabm |  | 2965 | 99.46 |  | S -Parvovirus, IgM-vasta-aineet | Serum |  | Parvovirus B19 IgM Ab [Presence] in Serum | FALSE |
| 1074 | s-parvavi | % | 13 | 0 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  | Parvovirus B19 IgG Ab avidity [Percent] in Serum | FALSE |
| 1075 | s-parvavi |  | 600 | 95.33 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  | Parvovirus B19 IgG Ab avidity [Presence] in Serum | FALSE |
| 1076 | s-pekpähe | u/ml | 31 | 0 |  |  | Serum |  | Allergen.f201 Pecan nut IgE Ab [Units/volume] in Serum | FALSE |
| 1077 | s-pekpähe |  | 77 | 96.1 |  |  | Serum |  | Allergen.f201 Pecan nut IgE Ab [Presence] in Serum | FALSE |
| 1078 | s-sakspäe | u/ml | 883 | 0 | [0, 0, 0, 0.01, 0.01, 0.03, 0.07, 0.21, 1.55] |  | Serum |  | Allergen.f256 Walnut IgE Ab [Units/volume] in Serum | FALSE |
| 1079 | s-sakspäe |  | 95 | 74.74 |  |  | Serum |  | Allergen.f256 Walnut IgE Ab [Presence] in Serum | FALSE |
| 1080 | s-sappih | umol/l | 9172 | 0.36 | [2, 2.87, 3.49, 4.45, 5.83, 7.59, 10.65, 16.77, 32.84] | S -Sappihapot | Serum |  | Bile acids.total [Moles/volume] in Serum or Plasma | FALSE |
| 1081 | s-sappih |  | 1955 | 50.33 | [2, 3, 3, 4, 4.4, 5.33, 7.05, 9.69, 18.19] | S -Sappihapot | Serum |  | Bile acids.total [Moles/volume] in Serum or Plasma | FALSE |
| 1082 | s-valpr | % | 33 | 0 |  | S -Valproaatti | Serum |  | Valproic acid [Mass Fraction] in Serum or Plasma | FALSE |
| 1083 | s-valpr | umol/l | 35853 | 0.05 | [220.39, 285.23, 332.16, 372.59, 408.92, 446.56, 486.81, 533.22, 600.78] | S -Valproaatti | Serum |  | Valproic acid [Moles/volume] in Serum or Plasma | FALSE |
| 1084 | s-valpr |  | 1583 | 100 | [195.88, 257.11, 300.41, 340.81, 382.77, 422.91, 465.76, 516.34, 588.53] | S -Valproaatti | Serum |  | Valproic acid [Presence] in Serum or Plasma | FALSE |
| 1085 | s-valpr-v | umol/l | 818 | 0 | [25.49, 29.94, 35.24, 39.88, 44.93, 50.41, 57.45, 67.85, 86.45] | S -Valproaatti, vapaa | Serum | Free or unconjugated | Valproic acid.free [Moles/volume] in Serum or Plasma | FALSE |
| 1086 | s-valpr-v |  | 221 | 80.54 |  | S -Valproaatti, vapaa | Serum | Free or unconjugated | Valproic acid.free [Presence] in Serum or Plasma | FALSE |
| 1087 | s-valpro | umol/l | 171 | 0 |  |  | Serum |  | Valproic acid [Moles/volume] in Serum or Plasma | FALSE |
| 1088 | s-valpro |  | 5 | 100 |  |  | Serum |  | Valproic acid [Presence] in Serum or Plasma | FALSE |
| 1089 | s-vara |  | 340 | 100 |  |  | Serum |  |  | FALSE |
| 1090 | s-varah |  | 253 | 100 |  |  | Serum |  |  | FALSE |
| 1091 | sappihapot | umol/l | 161 | 0 |  |  |  |  | Bile acids.total [Moles/volume] in Serum or Plasma | FALSE |
| 1092 | sappihapot |  | 14 | 100 |  |  |  |  | Bile acids.total [Presence] in Serum or Plasma | FALSE |
| 1093 | sk-padihot |  | 24730 | 100 |  | Sk-Ihottumanäytteen histologinen tutkimus | Skin |  | Tissue Pathology biopsy report | FALSE |
| 1094 | tupakka | u/24h | 599 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 8.55] |  |  |  | Cotinine [Units/time] in 24 hour Urine | FALSE |
| 1095 | tupakka |  | 104 | 100 |  |  |  |  | Cotinine [Presence] in Urine | FALSE |
| 1096 | u-gluprot |  | 2097 | 100 |  |  | Urine |  | Glucose and Protein panel - Urine | TRUE |
| 1097 | u-partik |  | 14759 | 100 |  |  | Urine |  | Urinalysis microscopic panel - Urine | TRUE |
| 1098 | u-partikk |  | 5466 | 100 |  |  | Urine |  | Urinalysis microscopic panel - Urine | TRUE |
| 1099 | u-rakkoai | h | 373 | 0 | [2.84, 4, 4, 4.03, 5, 6, 6.66, 7.87, 8.33] |  | Urine |  |  | FALSE |
| 1100 | u-rakkoai |  | 5 | 100 |  |  | Urine |  |  | FALSE |
| 1101 | u-sakka |  | 2736 | 100 |  |  | Urine |  | Urine sediment microscopy panel - Urine | TRUE |
| 1102 | u-valvott |  | 1125 | 100 |  |  | Urine |  |  | FALSE |
| 1103 | u-varabak |  | 206 | 100 |  |  | Urine |  |  | FALSE |

