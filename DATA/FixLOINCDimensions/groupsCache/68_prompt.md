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
Here is group 68.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1091762 | Alpha 1 globulin [Mass/volume] in Serum or Plasma | 1.000 |  |  0 |         0 |
| 1092292 | Alpha 2 globulin [Mass/volume] in Serum or Plasma | 1.000 |  |  0 |         0 |
| 3000690 | Aldosterone [Moles/time] in 24 hour Urine | 1.000 |  |  1 |        31 |
| 3000998 | Ovalbumin IgE Ab [Units/volume] in Serum | 1.000 |  |  0 |         0 |
| 3001788 | Aldosterone [Moles/volume] in Serum or Plasma | 1.000 | 774 |  9 |     8,537 |
| 3003171 | Aldosterone [Moles/volume] in Serum or Plasma --upright | 1.000 |  |  3 |     1,153 |
| 3004280 | Aldosterone [Moles/volume] in Serum or Plasma --supine | 1.000 |  |  3 |       154 |
| 3005685 | Amylase.salivary [Enzymatic activity/volume] in Serum or Plasma | 1.000 |  |  3 |       317 |
| 3008691 | Amylase [Enzymatic activity/volume] in Peritoneal fluid | 1.000 |  |  2 |       319 |
| 3015401 | Amylase [Enzymatic activity/volume] in Pleural fluid | 1.000 |  |  2 |       728 |
| 3016417 | Amylase.pancreatic [Enzymatic activity/volume] in Serum or Plasma | 1.000 |  | 10 |   113,228 |
| 3016771 | Amylase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 152 | 14 |   391,242 |
| 3017315 | Amylase [Enzymatic activity/volume] in Urine | 1.000 |  |  3 |     2,954 |
| 3019396 | Amylase.pancreatic [Enzymatic activity/volume] in Urine | 1.000 |  |  2 |       118 |
| 3019677 | Aldosterone [Mass/time] in 24 hour Urine | 1.000 |  |  0 |         0 |
| 3019985 | Aldosterone [Moles/volume] in 24 hour Urine | 1.000 |  |  0 |         0 |
| 3024561 | Albumin [Mass/volume] in Serum or Plasma | 1.000 | 20 | 21 | 1,016,464 |
| 3035995 | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 23 | 13 | 2,756,532 |
| 3040370 | OLANZapine [Moles/volume] in Serum or Plasma | 1.000 |  |  3 |     4,596 |
| 36304052 | Adalimumab Ab [Units/volume] in Serum or Plasma | 1.000 |  |  3 |     2,402 |
| 44786774 | Adalimumab [Mass/volume] in Serum or Plasma | 1.000 |  |  7 |     3,981 |
| 44816654 | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum | 0.984 |  |  0 |         0 |
| 3005309 | Salicylates [Presence] in Serum or Plasma | 0.982 | 832 |  0 |         0 |
| 3017950 | Salicylates [Moles/volume] in Serum or Plasma | 0.979 | 464 |  3 |       262 |
| 3020990 | Alkaline phosphatase.intestinal/Alkaline phosphatase.total in Serum or Plasma | 0.966 | 1783 |  0 |         0 |
| 46236951 | Amylase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.965 |  |  0 |         0 |
| 3018910 | Alkaline phosphatase.bone [Mass/volume] in Serum or Plasma | 0.964 |  |  1 |        30 |
| 3024457 | Aldosterone [Mass/volume] in 24 hour Urine | 0.964 |  |  0 |         0 |
| 36031415 | Gliadin IgE Ab [Units/volume] in Serum | 0.963 |  |  0 |         0 |
| 3044539 | Alkaline phosphatase.intestinal [Presence] in Serum or Plasma | 0.963 |  |  0 |         0 |
| 44786773 | Adalimumab Ab [Mass/volume] in Serum or Plasma | 0.962 |  |  0 |         0 |
| 3027953 | Aldolase [Enzymatic activity/volume] in Serum or Plasma | 0.961 | 695 |  3 |     3,930 |
| 46235077 | Alkaline phosphatase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.960 |  |  0 |         0 |
| 3001467 | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum or Plasma | 0.959 | 1850 | 12 |     5,701 |
| 3020013 | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum or Plasma | 0.959 |  |  9 |     4,096 |
| 42868730 | Amylase.pancreatic [Enzymatic activity/volume] in Peritoneal fluid | 0.956 |  |  0 |         0 |
| 3007225 | Aldosterone free [Mass/time] in 24 hour Urine | 0.956 |  |  0 |         0 |
| 42868742 | Amylase.pancreatic [Enzymatic activity/volume] in Pleural fluid | 0.954 |  |  0 |         0 |
| 3000831 | Aldosterone [Mass/volume] in Serum or Plasma --upright | 0.954 |  |  0 |         0 |
| 3014133 | Dog dander IgE Ab [Units/volume] in Serum | 0.954 | 1077 | 10 |     9,242 |
| 36305075 | Vedolizumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.951 |  |  3 |     1,787 |
| 3005294 | Aldosterone [Mass/volume] in Serum or Plasma --supine | 0.950 |  |  0 |         0 |
| 36303365 | Adalimumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.944 |  |  0 |         0 |
| 1175645 | Adalimumab Ab [Units/volume] in Serum by Immunoassay | 0.939 |  |  0 |         0 |
| 3041069 | Gliadin Ab [Presence] in Serum | 0.939 |  |  0 |         0 |
| 3039488 | Alkaline phosphatase.intestinal 2/Alkaline phosphatase.total in Serum or Plasma | 0.936 |  |  0 |         0 |
| 3021494 | OLANZapine [Mass/volume] in Serum or Plasma | 0.935 |  |  0 |         0 |
| 3039730 | Alkaline phosphatase.intestinal 3/Alkaline phosphatase.total in Serum or Plasma | 0.935 |  |  0 |         0 |
| 3014729 | Amylase.P1 [Enzymatic activity/volume] in Serum or Plasma | 0.935 |  |  0 |         0 |
| 36305882 | Vedolizumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.934 |  |  0 |         0 |
| 3011337 | Aldosterone [Mass/volume] in Serum or Plasma | 0.934 |  |  0 |         0 |
| 3017726 | Gliadin Ab [Units/volume] in Serum | 0.933 | 1663 |  0 |         0 |
| 3016625 | Amylase S1 [Enzymatic activity/volume] in Serum or Plasma | 0.933 |  |  0 |         0 |
| 3003966 | Gliadin IgG Ab [Units/volume] in Serum | 0.933 | 1637 |  0 |         0 |
| 3016848 | Dog dander IgG Ab [Units/volume] in Serum | 0.932 |  |  0 |         0 |
| 1617569 | Cholesterol.in LDL.small dense [Moles/volume] in Serum or Plasma | 0.931 |  |  0 |         0 |
| 3035400 | Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma | 0.930 | 1919 |  3 |     3,451 |
| 42870306 | Alkaline phosphatase.intestinal 3 [Enzymatic activity/volume] in Serum or Plasma | 0.929 |  |  0 |         0 |
| 3004541 | Aldosterone [Moles/volume] in Urine | 0.928 |  |  1 |        25 |
| 40759832 | Dog dander+Dog epithelium IgE Ab [Units/volume] in Serum | 0.928 |  |  0 |         0 |
| 42870305 | Alkaline phosphatase.intestinal 2 [Enzymatic activity/volume] in Serum or Plasma | 0.928 |  |  0 |         0 |
| 3017830 | Gliadin IgG Ab [Presence] in Serum | 0.927 |  |  1 |        11 |
| 3037820 | Gliadin IgA Ab [Units/volume] in Serum | 0.926 | 878 |  0 |         0 |
| 40761804 | Gliadin peptide IgG Ab [Units/volume] in Serum | 0.925 |  |  0 |         0 |
| 40761803 | Gliadin peptide IgA Ab [Units/volume] in Serum | 0.925 |  |  0 |         0 |
| 36304805 | Adalimumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.924 |  |  0 |         0 |
| 3010114 | Amylase isoenzyme 7 panel - Serum | 0.924 |  |  0 |         0 |
| 3004155 | Amylase S2 [Enzymatic activity/volume] in Serum or Plasma | 0.924 |  |  0 |         0 |
| 3009876 | Amylase isoenzyme 3 panel - Serum or Plasma | 0.923 |  |  1 |       432 |
| 3015322 | Alpha 1 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.922 | 315 |  9 |    38,126 |
| 3017317 | Gliadin IgA Ab [Presence] in Serum | 0.921 |  |  0 |         0 |
| 3001415 | Amylase [Enzymatic activity/volume] in 24 hour Urine | 0.921 |  |  0 |         0 |
| 3005229 | Alpha 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.919 | 316 | 10 |    39,833 |
| 3001110 | Alkaline phosphatase [Enzymatic activity/volume] in Blood | 0.918 |  |  0 |         0 |
| 3009039 | Amylase.P2 [Enzymatic activity/volume] in Serum or Plasma | 0.916 |  |  0 |         0 |
| 3001660 | Gliadin IgM Ab [Units/volume] in Serum | 0.916 |  |  0 |         0 |
| 3015468 | Gliadin IgG Ab [Units/volume] in Serum by Immunoassay | 0.916 | 653 |  0 |         0 |
| 40771878 | Amylase [Enzymatic activity/volume] in Serum or Plasma --fasting | 0.915 |  |  0 |         0 |
| 3000787 | Salicylates [Mass/volume] in Serum or Plasma | 0.915 |  |  0 |         0 |
| 40766189 | Gliadin peptide IgG Ab [Units/volume] in Serum by Immunoassay | 0.914 |  |  5 |    14,056 |
| 3015174 | Gliadin IgA Ab [Units/volume] in Serum by Immunoassay | 0.914 | 694 |  0 |         0 |
| 40758706 | Salicylamide [Moles/volume] in Serum or Plasma | 0.913 |  |  0 |         0 |
| 3007970 | Alkaline phosphatase.bile [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |  0 |         0 |
| 3014599 | Egg white IgE Ab [Units/volume] in Serum | 0.913 | 799 |  6 |     3,697 |
| 3020233 | Acid phosphatase [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |  0 |         0 |
| 3001308 | Cholesterol in LDL [Moles/volume] in Serum or Plasma | 0.912 | 92 | 47 | 2,347,979 |
| 21492517 | Salicylurate [Moles/volume] in Serum or Plasma | 0.912 |  |  0 |         0 |
| 3003633 | Ovomucoid IgE Ab [Units/volume] in Serum | 0.911 |  |  3 |       521 |
| 1175553 | Vedolizumab and Vedolizumab Ab panel [Mass/volume] - Serum or Plasma | 0.911 |  |  1 |     1,625 |
| 649422 | Adalimumab Ab [Measurement] in Serum or Plasma | 0.910 |  |  0 |         0 |
| 3032449 | Aldolase [Enzymatic activity/volume] in Body fluid | 0.910 |  |  0 |         0 |
| 3037597 | Macroamylase [Enzymatic activity/volume] in Serum or Plasma | 0.910 |  |  0 |         0 |
| 40762132 | Amylase [Enzymatic activity/volume] in Peritoneal dialysis fluid | 0.908 |  |  0 |         0 |
| 3018352 | Whole Egg IgE Ab [Units/volume] in Serum | 0.907 | 891 |  0 |         0 |
| 43055428 | Alpha 1 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.906 |  |  0 |         0 |
| 3002214 | Alkaline phosphatase.renal [Enzymatic activity/volume] in Serum or Plasma | 0.905 |  |  0 |         0 |
| 3001151 | Sole IgE Ab [Units/volume] in Serum | 0.905 |  |  0 |         0 |
| 3040995 | Amylase [Enzymatic activity/volume] in 12 hour Urine | 0.904 |  |  0 |         0 |
| 3043544 | IgE [Presence] in Serum | 0.904 |  |  0 |         0 |
| 3036705 | Amylase [Enzymatic activity/volume] in 2 hour Urine | 0.904 |  |  0 |         0 |
| 3003860 | Alkaline phosphatase.regan [Enzymatic activity/volume] in Serum or Plasma | 0.903 |  |  0 |         0 |
| 1617227 | Adalimumab [Mass/volume] in Serum or Plasma --trough | 0.903 |  |  0 |         0 |
| 3015123 | Egg yolk IgE Ab [Units/volume] in Serum | 0.903 | 1080 |  0 |         0 |
| 3028564 | Alkaline phosphatase isoenz panel - Serum or Plasma | 0.902 |  |  0 |         0 |
| 3048601 | Amylase.pancreatic [Enzymatic activity/volume] in Body fluid | 0.902 |  |  0 |         0 |
| 1175847 | Vedolizumab [Mass/volume] in Serum or Plasma by LC/MS/MS --trough | 0.902 |  |  0 |         0 |
| 3965168 | Ovalbumin IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.901 |  |  0 |         0 |
| 3050371 | Gliadin peptide IgG Ab [Presence] in Serum by Immunoassay | 0.901 |  |  0 |         0 |
| 43055424 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.900 |  |  0 |         0 |
| 3035654 | Conalbumin IgE Ab [Units/volume] in Serum | 0.900 |  |  0 |         0 |
| 3024989 | Salicylates [Presence] in Blood | 0.899 |  |  0 |         0 |
| 40765809 | Dog dander IgG Ab [Mass/volume] in Serum | 0.898 |  |  0 |         0 |
| 40757478 | Albumin [Moles/volume] in Serum or Plasma | 0.898 |  |  0 |         0 |
| 40763380 | OLANZapine [Moles/volume] in Specimen | 0.897 |  |  0 |         0 |
| 43533877 | Aldosterone-18-glucuronide [Moles/time] in 24 hour Urine | 0.897 |  |  0 |         0 |
| 43533876 | Aldosterone-18-glucuronide [Moles/volume] in 24 hour Urine | 0.896 |  |  0 |         0 |
| 649070 | Salicylates [Measurement] in Serum or Plasma | 0.896 |  |  0 |         0 |
| 3005166 | Alpha 1 globulin [Mass/volume] in Urine | 0.896 |  |  0 |         0 |
| 3039686 | IgE Ab [Presence] in Serum or Plasma | 0.896 |  |  0 |         0 |
| 3043739 | Amylase [Enzymatic activity/volume] in Pericardial fluid | 0.895 |  |  0 |         0 |
| 3002670 | Multiple inhalant allergen IgE Ab [Units/volume] in Serum | 0.894 |  |  2 |     4,192 |
| 3002538 | Oyster IgE Ab [Units/volume] in Serum | 0.893 | 1690 |  0 |         0 |
| 21492784 | Miscellaneous allergen IgE Ab [Units/volume] in Serum | 0.893 |  |  0 |         0 |
| 3048403 | Gliadin peptide IgA Ab [Presence] in Serum by Immunoassay | 0.893 |  |  0 |         0 |
| 3965752 | Albumin [Mass/volume] in Serum or Plasma by Nephelometry | 0.893 |  |  0 |         0 |
| 3023949 | Allscale IgE Ab [Units/volume] in Serum | 0.893 |  |  0 |         0 |
| 3016585 | Aldosterone [Mass/volume] in Serum or Plasma --baseline | 0.892 |  |  0 |         0 |
| 40758600 | Aldosterone [Moles/volume] in Serum or Plasma --1 hour post dose corticotropin | 0.892 |  |  0 |         0 |
| 3024218 | Fig IgE Ab [Units/volume] in Serum | 0.891 |  |  0 |         0 |
| 3044478 | Alkaline phosphatase.intestinal+renal [Presence] in Serum or Plasma | 0.891 |  |  0 |         0 |
| 40759369 | Dog dander IgG4 Ab [Mass/volume] in Serum | 0.890 |  |  0 |         0 |
| 42868690 | Salicylates [Moles/volume] in Serum or Plasma by Screen method | 0.889 | 870 |  0 |         0 |
| 3002000 | Albumin [Mass/volume] in Specimen | 0.889 |  |  0 |         0 |
| 3022487 | Cholesterol in VLDL [Moles/volume] in Serum or Plasma | 0.888 | 219 |  0 |         0 |
| 3010541 | Alpha 2 globulin [Mass/volume] in Urine | 0.888 |  |  0 |         0 |
| 3013765 | Hay IgE Ab [Units/volume] in Serum | 0.888 |  |  0 |         0 |
| 646542 | Albumin [Measurement] in Serum or Plasma | 0.888 |  |  0 |         0 |
| 3015877 | Amylase.P3 [Enzymatic activity/volume] in Serum or Plasma | 0.888 |  |  0 |         0 |
| 3019406 | Latex IgE Ab [Units/volume] in Serum | 0.887 | 1426 |  0 |         0 |
| 1175324 | Salicylcarnitine [Moles/volume] in Serum or Plasma | 0.887 |  |  0 |         0 |
| 3021476 | Amylase [Enzymatic activity/volume] in Duodenal fluid | 0.887 |  |  0 |         0 |
| 3014955 | Aldosterone [Mass/volume] in Urine | 0.886 |  |  0 |         0 |
| 44816899 | Dog native (nCan f) 1 IgE Ab [Units/volume] in Serum | 0.885 |  |  0 |         0 |
| 3030968 | Amylase [Enzymatic activity/volume] in Urine collected for unspecified duration | 0.884 |  |  0 |         0 |
| 1988210 | Ovalbumin IgG Ab [Mass/volume] in Serum | 0.884 |  |  0 |         0 |
| 648209 | Aldosterone [Measurement] in Serum or Plasma | 0.884 |  |  0 |         0 |
| 3001329 | Acetylsalicylate [Presence] in Serum or Plasma | 0.883 |  |  0 |         0 |
| 40764094 | Dog dander IgE Ab/IgE total in Serum | 0.883 |  |  0 |         0 |
| 3033031 | Aldosterone [Moles/volume] in Serum or Plasma --post XXX challenge | 0.883 |  |  0 |         0 |
| 1260115 | Albumin [Mass/volume] in Serum by Immunoassay | 0.882 |  |  0 |         0 |
| 3016604 | IgE [Mass/volume] in Serum | 0.882 |  |  0 |         0 |
| 3021162 | Amylase [Enzymatic activity/volume] in Specimen | 0.882 |  |  2 |     1,924 |
| 3009827 | Alpha-2-Macroglobulin [Mass/volume] in Serum or Plasma | 0.882 |  |  0 |         0 |
| 3030162 | Aldosterone [Moles/volume] in Serum or Plasma --pre or post XXX challenge | 0.881 |  |  0 |         0 |
| 3027320 | Salicylates [Moles/volume] in Specimen | 0.881 |  |  0 |         0 |
| 3018519 | Aldolase [Enzymatic activity/volume] in Red Blood Cells | 0.879 |  |  0 |         0 |
| 3013708 | Smelt IgE Ab [Units/volume] in Serum | 0.879 |  |  0 |         0 |
| 3049683 | HLA Ab panel - Serum | 0.877 |  |  0 |         0 |
| 3008832 | Norclozapine [Moles/volume] in Serum or Plasma | 0.877 |  |  5 |    47,586 |
| 36305571 | Albumin goal [Mass/volume] Serum or Plasma | 0.877 |  |  0 |         0 |
| 3020874 | Milk IgE Ab [Units/volume] in Serum | 0.876 | 1442 |  5 |     3,854 |
| 3018001 | Oat IgE Ab [Units/volume] in Serum | 0.876 | 1486 |  3 |       384 |
| 40767673 | Dog recombinant 5 IgE Ab [Units/volume] in Serum | 0.876 |  |  0 |         0 |
| 3005322 | IgE [Units/volume] in Serum or Plasma | 0.876 | 466 | 10 |    43,220 |
| 3031804 | Salicylates [Presence] in Specimen | 0.876 |  |  0 |         0 |
| 3012133 | Amylase [Enzymatic activity/volume] in Body fluid | 0.875 | 771 |  0 |         0 |
| 645478 | OLANZapine [Measurement] in Serum or Plasma | 0.874 |  |  0 |         0 |
| 3026285 | Alpha 1 antitrypsin [Mass/volume] in Serum or Plasma | 0.873 | 854 |  3 |     7,178 |
| 3029321 | OLANZapine [Moles/volume] in Urine | 0.873 |  |  0 |         0 |
| 3049125 | Alpha-1-Microglobulin [Mass/volume] in Serum or Plasma | 0.873 |  |  0 |         0 |
| 3039654 | Egg white IgG Ab [Presence] in Serum | 0.872 |  |  0 |         0 |
| 3045996 | Lipase [Enzymatic activity/volume] in Peritoneal fluid | 0.871 |  |  0 |         0 |
| 46235169 | Amylase [Enzymatic activity/volume] in Blood | 0.871 |  |  0 |         0 |
| 3028286 | Albumin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.869 | 313 |  4 |     3,222 |
| 3043944 | Alkaline phosphatase [Enzymatic activity/volume] in Peritoneal fluid | 0.869 |  |  0 |         0 |
| 3040652 | Amylase [Units/volume] in 24 hour Urine | 0.869 |  |  0 |         0 |
| 3023430 | Cat dander IgE Ab [Units/volume] in Serum | 0.868 | 715 |  6 |     8,711 |
| 36303626 | Amylase.pancreatic [Enzymatic activity/volume] in Peritoneal dialysis fluid | 0.867 |  |  0 |         0 |
| 44786740 | Norolanzapine [Moles/volume] in Serum or Plasma | 0.866 |  |  0 |         0 |
| 36660596 | Dog recombinant 6 IgE Ab [Units/volume] in Serum | 0.865 |  |  0 |         0 |
| 648474 | Amylase [Measurement] in Urine | 0.865 |  |  0 |         0 |
| 3045829 | Aldosterone/Creatinine [Mass Ratio] in 24 hour Urine | 0.864 |  |  0 |         0 |
| 3023602 | Cholesterol in HDL [Moles/volume] in Serum or Plasma | 0.862 | 38 | 41 | 2,024,003 |
| 647232 | Aldosterone [Measurement] in Urine | 0.861 |  |  0 |         0 |
| 3025313 | Albumin [Mass/volume] in Body fluid | 0.861 | 1032 |  0 |         0 |
| 1175998 | Cholesterol in LDL 2 [Moles/volume] in Serum or Plasma | 0.861 |  |  0 |         0 |
| 3004142 | Amylase [Enzymatic activity/volume] in Synovial fluid | 0.860 |  |  0 |         0 |
| 43055511 | Salicylates [Mass/volume] in Serum or Plasma --trough | 0.860 |  |  0 |         0 |
| 40766151 | Gliadin peptide+tissue transglutaminase IgA+IgG Ab [Presence] in Serum by Immunoassay | 0.860 |  |  0 |         0 |
| 3021643 | Salicylamide [Mass/volume] in Serum or Plasma | 0.859 |  |  0 |         0 |
| 1176311 | Cholesterol.in LDL.small dense [Mass/volume] in Serum or Plasma | 0.859 |  |  0 |         0 |
| 1175617 | Cholesterol in LDL 5 [Moles/volume] in Serum or Plasma | 0.859 |  |  0 |         0 |
| 3008877 | Alpha-1-acid glycoprotein [Mass/volume] in Serum or Plasma | 0.859 |  |  0 |         0 |
| 3048752 | Lipase [Enzymatic activity/volume] in Pleural fluid | 0.859 |  |  0 |         0 |
| 40763956 | Albumin [Mass/volume] in Serum or Plasma from Fetus | 0.859 |  |  0 |         0 |
| 3009059 | Enolase [Enzymatic activity/volume] in Serum | 0.858 |  |  0 |         0 |
| 3046505 | Aldolase [Enzymatic activity/volume] in Pleural fluid | 0.858 |  |  0 |         0 |
| 3016801 | Amylase [Enzymatic activity/volume] in Gastric fluid | 0.857 |  |  0 |         0 |
| 3965996 | Dog dander IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.856 |  |  0 |         0 |
| 1175889 | Cholesterol in LDL 1 [Moles/volume] in Serum or Plasma | 0.856 |  |  0 |         0 |
| 3036955 | Alkaline phosphatase.liver/Alkaline phosphatase.total in Serum or Plasma | 0.853 | 1664 |  2 |       176 |
| 3012633 | Alpha 1 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.852 |  |  0 |         0 |
| 42868537 | Multiple inhalant allergen IgE Ab [Presence] in Serum by Immunoassay | 0.852 |  |  0 |         0 |
| 1175571 | Cholesterol in LDL 3 [Moles/volume] in Serum or Plasma | 0.851 |  |  0 |         0 |
| 40757622 | Alanine aminotransferase [Enzymatic activity/volume] in Peritoneal fluid | 0.851 |  |  0 |         0 |
| 3024800 | Alpha 1 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.851 |  |  0 |         0 |
| 43055427 | Alpha 1 globulin/Protein.total [Pure mass fraction] in Urine by Electrophoresis | 0.851 |  |  0 |         0 |
| 3019900 | Cholesterol [Moles/volume] in Serum or Plasma | 0.851 | 32 | 31 | 2,073,556 |
| 3042545 | Alkaline phosphatase.bile/Alkaline phosphatase.total in Serum or Plasma | 0.850 |  |  0 |         0 |
| 3033598 | Amylase isoenzymes [Interpretation] in Serum or Plasma | 0.850 |  |  0 |         0 |
| 3040682 | Aldosterone [Molar amount] in Urine collected for unspecified duration | 0.850 |  |  0 |         0 |
| 3006330 | Alpha 2 globulin/Protein.total in Serum or Plasma by Electrophoresis | 0.849 |  |  0 |         0 |
| 3017341 | Amylase [Enzymatic activity/volume] in Amniotic fluid | 0.848 |  |  0 |         0 |
| 3026848 | Alpha subunit [Mass/volume] in Serum or Plasma | 0.848 |  |  0 |         0 |
| 3002069 | Alkaline phosphatase.bone/Alkaline phosphatase.total in Serum or Plasma | 0.848 | 1666 |  0 |         0 |
| 3964946 | Ovomucoid IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.847 |  |  0 |         0 |
| 44816883 | Amylase [Enzymatic activity/volume] in Saliva (oral fluid) | 0.847 |  |  0 |         0 |
| 1091804 | Beta globulin [Mass/volume] in Serum or Plasma | 0.847 |  |  0 |         0 |
| 645900 | Alkaline phosphatase.bone [Measurement] in Serum or Plasma | 0.846 |  |  0 |         0 |
| 3005090 | Alkaline phosphatase [Enzymatic activity/volume] in Body fluid | 0.846 |  |  0 |         0 |
| 3010043 | Alpha 2 globulin [Mass/volume] in Body fluid by Electrophoresis | 0.845 |  |  0 |         0 |
| 3001077 | Alkaline phosphatase [Enzymatic activity/volume] in Urine | 0.844 |  |  0 |         0 |
| 3022361 | Alpha 1 globulin [Mass/volume] in Urine by Electrophoresis | 0.843 |  |  0 |         0 |
| 43055426 | Alpha 1 globulin/Protein.total [Pure mass fraction] in 24 hour Urine by Electrophoresis | 0.843 |  |  0 |         0 |
| 3965215 | Dog dander+Dog epithelium IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.843 |  |  0 |         0 |
| 43055423 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Urine by Electrophoresis | 0.843 |  |  0 |         0 |
| 3046951 | IgE [Mass/volume] in Specimen | 0.841 |  |  0 |         0 |
| 3021222 | Alkaline phosphatase.renal/Alkaline phosphatase.total in Serum or Plasma | 0.841 |  |  0 |         0 |
| 3003057 | Salicylates [Presence] in Urine | 0.841 |  |  0 |         0 |
| 3000081 | cloZAPine [Moles/volume] in Serum or Plasma | 0.841 |  |  7 |    66,864 |
| 44816655 | Soluble fms-like tyrosine kinase-1/placental growth factor [Ratio] in Serum | 0.840 |  |  0 |         0 |
| 1617584 | Ovalbumin IgG4 Ab [Mass/volume] in Serum | 0.840 |  |  0 |         0 |
| 40763164 | OLANZapine [Mass/volume] in Blood | 0.840 |  |  0 |         0 |
| 3021886 | Globulin [Mass/volume] in Serum | 0.839 | 83 |  0 |         0 |
| 40757623 | Alanine aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.838 |  |  0 |         0 |
| 3036255 | Didesmethylcitalopram [Moles/volume] in Serum or Plasma | 0.836 |  |  0 |         0 |
| 40763006 | OLANZapine [Moles/volume] in Gastric fluid | 0.836 |  |  0 |         0 |
| 3004185 | IgE.monoclonal [Mass/volume] in Serum | 0.835 |  |  0 |         0 |
| 648378 | Gliadin IgG Ab [Measurement] in Serum | 0.834 |  |  0 |         0 |
| 3037039 | Alpha 2 globulin [Mass/volume] in Urine by Electrophoresis | 0.834 |  |  0 |         0 |
| 43055422 | Alpha 2 globulin/Protein.total [Pure mass fraction] in 24 hour Urine by Electrophoresis | 0.834 |  |  0 |         0 |
| 40758725 | Goose feather IgE Ab [Presence] in Serum | 0.833 |  |  0 |         0 |
| 645268 | Gliadin peptide IgG Ab [Measurement] in Serum | 0.832 |  |  0 |         0 |
| 3042299 | inFLIXimab [Mass/volume] in Serum or Plasma | 0.832 |  |  7 |     7,102 |
| 646096 | Gliadin peptide IgA Ab [Measurement] in Serum | 0.830 |  |  0 |         0 |
| 3020579 | Amylase [Enzymatic activity/time] in 24 hour Urine | 0.830 |  |  0 |         0 |
| 3037908 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma | 0.830 |  |  0 |         0 |
| 43055429 | Alpha 1 globulin/Protein.total [Pure mass fraction] in Cerebral spinal fluid by Electrophoresis | 0.830 |  |  0 |         0 |
| 46234773 | IgE [Mass/volume] in Serum or Plasma by Immunoassay | 0.829 |  |  0 |         0 |
| 3965305 | Dog recombinant 5 IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.828 |  |  0 |         0 |
| 3964850 | Sole IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.826 |  |  0 |         0 |
| 36304617 | Golimumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.826 |  |  3 |       940 |
| 3037466 | Alkaline phosphatase.placental/Alkaline phosphatase.total in Serum or Plasma | 0.826 |  |  0 |         0 |
| 43055425 | Alpha 2 globulin/Protein.total [Pure mass fraction] in Cerebral spinal fluid by Electrophoresis | 0.826 |  |  0 |         0 |
| 3966178 | Dog epithelium IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.825 |  |  0 |         0 |
| 3044715 | Alkaline phosphatase.liver [Presence] in Serum or Plasma | 0.825 |  |  0 |         0 |
| 3042479 | Alkaline phosphatase.bone [Presence] in Serum or Plasma | 0.825 |  |  0 |         0 |
| 3002960 | cloZAPine+Norclozapine [Moles/volume] in Serum or Plasma | 0.824 |  |  0 |         0 |
| 3028993 | Alkaline phosphatase.macro/Alkaline phosphatase.total in Serum or Plasma | 0.824 |  |  0 |         0 |
| 3037712 | Alkaline phosphatase.regan/Alkaline phosphatase.total in Serum or Plasma | 0.823 |  |  0 |         0 |
| 3966239 | Fig IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.822 |  |  0 |         0 |
| 3013407 | Alcohol dehydrogenase [Enzymatic activity/volume] in Serum | 0.822 |  |  0 |         0 |
| 3018657 | Pigeon serum IgE Ab [Presence] in Serum | 0.822 |  |  0 |         0 |
| 21494218 | Salicylates free [Mass/volume] in Serum or Plasma | 0.821 |  |  0 |         0 |
| 1091897 | Risankizumab [Mass/volume] in Serum or Plasma | 0.821 |  |  0 |         0 |
| 3027159 | OXcarbazepine [Moles/volume] in Serum or Plasma | 0.818 | 1659 |  0 |         0 |
| 43055489 | Aldolase [Enzymatic activity/mass] in Red Blood Cells | 0.817 |  |  0 |         0 |
| 3048480 | O-desmethylvenlafaxine [Moles/volume] in Serum or Plasma | 0.817 |  |  0 |         0 |
| 3019891 | Alpha 1 globulin/Protein.total in Body fluid by Electrophoresis | 0.816 |  |  0 |         0 |
| 3965207 | Elder IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.816 |  |  0 |         0 |
| 40758658 | Clopenthixol [Moles/volume] in Serum or Plasma | 0.815 |  |  0 |         0 |
| 3966196 | Vanilla IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.814 |  |  0 |         0 |
| 3966278 | Miscellaneous allergen IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.813 |  |  0 |         0 |
| 3015383 | N-desalkylflurazepam [Moles/volume] in Serum or Plasma | 0.813 |  |  0 |         0 |
| 3003650 | Alkaline phosphatase [Mass/volume] in Body fluid | 0.812 |  |  0 |         0 |
| 1989156 | Adalimumab and Adalimumab Ab panel - Serum or Plasma by Immunoassay | 0.811 |  |  0 |         0 |
| 3008764 | Glyceraldehyde 3 phosphate dehydrogenase [Enzymatic activity/volume] in Serum | 0.811 |  |  0 |         0 |
| 3012984 | Norclozapine [Mass/volume] in Serum or Plasma | 0.810 |  |  0 |         0 |
| 36304315 | Certolizumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.810 |  |  3 |        74 |
| 3042394 | European house dust mite IgG Ab [Presence] in Serum | 0.809 |  |  0 |         0 |
| 1175178 | Eculizumab [Mass/volume] in Serum | 0.808 |  |  0 |         0 |
| 3016436 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | 0.808 | 156 |  2 |     5,209 |
| 36305036 | Ustekinumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.806 |  |  0 |         0 |
| 3048259 | Amylase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.806 |  |  0 |         0 |
| 3015359 | Malate dehydrogenase [Enzymatic activity/volume] in Serum | 0.806 |  |  0 |         0 |
| 44816887 | Alkaline phosphatase.bone [Z-score] in Serum or Plasma | 0.806 |  |  0 |         0 |
| 3005504 | Alpha 2 globulin/Protein.total in Body fluid by Electrophoresis | 0.806 |  |  0 |         0 |
| 44816662 | Soluble fms-like tyrosine kinase-1 and placental growth factor panel - Serum or Plasma | 0.805 |  |  0 |         0 |
| 36303722 | Certolizumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.803 |  |  2 |       117 |
| 3002555 | Alkaline phosphatase [Mass/volume] in Urine | 0.798 |  |  0 |         0 |
| 3015483 | Nefazodone [Moles/volume] in Serum or Plasma | 0.793 |  |  0 |         0 |
| 3013751 | cloZAPine [Mass/volume] in Serum or Plasma | 0.792 |  |  0 |         0 |
| 43055237 | Amylase and triacylglycerol lipase panel - Serum or Plasma | 0.792 |  |  0 |         0 |
| 646132 | HLA-A and B and C (class I) and HLA-DP and DQ and DR (class II) Ab.IgG donor specific [Identifier] in Serum or Plasma | 0.791 |  |  0 |         0 |
| 3049181 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.790 |  |  0 |         0 |
| 3043889 | HLA Ab in Serum | 0.786 |  |  0 |         0 |
| 1616853 | HLA-A and B and C (class I) IgG donor specific [Identifier] in Serum or Plasma | 0.784 |  |  0 |         0 |
| 647081 | HLA-A and B and C (class I) and HLA-DP and DQ and DR (class II) Ab.IgG donor specific [Presence] in Serum or Plasma | 0.776 |  |  0 |         0 |
| 3028089 | Alkaline phosphatase isoenzyme [Units/volume] in Serum or Plasma | 0.774 |  |  0 |         0 |
| 40761116 | Natalizumab Ab [Presence] in Serum | 0.773 |  |  0 |         0 |
| 1616483 | HLA-DP and DQ and DR (class II) IgG donor specific [Identifier] in Serum or Plasma | 0.771 |  |  0 |         0 |
| 3966146 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Serum or Plasma | 0.764 |  |  0 |         0 |
| 3039358 | Amylase isoenzymes [Interpretation] in Body fluid Narrative | 0.763 |  |  0 |         0 |
| 3047120 | Alkaline phosphatase.liver+bone [Presence] in Serum or Plasma | 0.762 |  |  0 |         0 |
| 3043435 | Alkaline phosphatase isoenzymes [Enzymatic activity/volume] in Serum or Plasma by Levamisole inhibition | 0.755 |  |  0 |         0 |
| 46235359 | Vascular endothelial growth factor A [Mass/volume] in Serum or Plasma | 0.752 |  |  0 |         0 |
| 3965350 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Plasma | 0.748 |  |  0 |         0 |
| 3037841 | Amylase.P2/Amylase.total in Serum or Plasma | 0.746 |  |  0 |         0 |
| 3031767 | Vascular endothelial growth factor [Mass/volume] in Serum or Plasma | 0.746 |  |  0 |         0 |
| 3023712 | Amylase.P1/Amylase.total in Serum or Plasma | 0.742 |  |  0 |         0 |
| 3038143 | Amylase.P3/Amylase.total in Serum or Plasma | 0.742 |  |  0 |         0 |
| 1259656 | HLA-DPB1+DPA1 Typing panel - Blood or Tissue from Donor | 0.739 |  |  0 |         0 |
| 1259800 | HLA-ABDR typing panel - Blood or Tissue from Donor | 0.736 |  |  0 |         0 |
| 3965684 | Tumor necrosis factor ligand superfamily member 10 [Mass/volume] in Serum, Plasma or Blood | 0.734 |  |  0 |         0 |
| 3021952 | Alkaline phosphatase isoenzymes [Enzymatic activity/volume] in Serum or Plasma by Heat stability | 0.732 |  |  2 |     9,116 |
| 42529047 | Vascular endothelial growth factor D [Mass/volume] in Serum or Plasma | 0.732 |  |  0 |         0 |
| 3042733 | HLA Ab [Presence] in Serum | 0.731 |  |  1 |     8,109 |
| 3048411 | HLA-DP+DQ+DR (class II) Ab in Serum | 0.729 | 1094 |  0 |         0 |
| 1616827 | Angiopoietin receptor 2 [Mass/volume] in Serum or Plasma | 0.727 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 803 | -amyl | u/l | 4274 | 0 | [40.79, 91.13, 163.85, 262.6, 433.78, 741.28, 1310.78, 2709.64, 7550.04] |  |  |  |  | FALSE |
| 804 | -amyl |  | 352 | 99.15 |  |  |  |  |  | FALSE |
| 805 | alfa-1 | g/l | 903 | 0 | [1.23, 1.5, 1.79, 2.22, 2.48, 2.68, 2.88, 3.11, 3.51] |  |  |  | Alpha 1 globulin [Mass/volume] in Serum or Plasma | FALSE |
| 806 | alfa-2 | g/l | 907 | 0 | [5.21, 5.83, 6.26, 6.53, 6.88, 7.18, 7.58, 8.1, 8.87] |  |  |  | Alpha 2 globulin [Mass/volume] in Serum or Plasma | FALSE |
| 807 | amylaasi | u/l | 1380 | 0 | [29.91, 37.05, 43.3, 48.81, 54.92, 61.3, 69.75, 79.02, 95.18] |  |  |  | Amylase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 808 | amylaasi |  | 28 | 100 |  |  |  |  |  | FALSE |
| 809 | as-amyl | u/l | 277 | 0 | [7.29, 10.51, 15.56, 18.22, 24.01, 33.76, 50.6, 245.04, 2494.39] | As-Amylaasi | Ascitic fluid |  | Amylase [Enzymatic activity/volume] in Peritoneal fluid | FALSE |
| 810 | as-amyl |  | 47 | 87.23 |  | As-Amylaasi | Ascitic fluid |  | Amylase [Enzymatic activity/volume] in Peritoneal fluid | FALSE |
| 811 | du-aldos | nmol | 1126 | 1.15 | [10.3, 15.49, 20, 24.81, 30.39, 36.32, 42.97, 53.97, 73.23] | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/time] in 24 hour Urine | FALSE |
| 812 | du-aldos | nmol/24h | 31 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/time] in 24 hour Urine | FALSE |
| 813 | du-aldos | nmol/l | 25 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/volume] in 24 hour Urine | FALSE |
| 814 | du-aldos | ug/24h | 12 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Mass/time] in 24 hour Urine | FALSE |
| 815 | du-aldos |  | 191 | 49.21 | [8, 15.27, 20, 24.32, 29.5, 36, 48.62, 70.25, 89] | dU-Aldosteroni | 24-hour urine |  | Aldosterone [Moles/time] in 24 hour Urine | FALSE |
| 816 | fp-afos | u/l | 595 | 0 | [48.33, 55.25, 59.57, 63.86, 67.6, 73.77, 82.28, 90.12, 106.03] |  | Fasting plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 817 | fp-aldos | pmol/l | 759 | 0 | [99.71, 178.79, 234.24, 287.4, 344.18, 414.36, 481.84, 606.93, 836.03] | fP-Aldosteroni | Fasting plasma |  | Aldosterone [Moles/volume] in Serum or Plasma | FALSE |
| 818 | fp-aldos |  | 70 | 70 |  | fP-Aldosteroni | Fasting plasma |  | Aldosterone [Moles/volume] in Serum or Plasma | FALSE |
| 819 | fp-amyl | u/l | 166 | 0 | [38.7, 46.83, 53.52, 59.77, 65.17, 71.18, 77.02, 86.88, 100.9] |  | Fasting plasma |  | Amylase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 820 | p-afos | u/l | 2633385 | 0.01 | [49.38, 57.42, 63.93, 70.22, 76.89, 84.76, 95, 111.35, 151.36] | P -Alkalinen fosfataasi | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 821 | p-afos |  | 28410 | 100 | [47.41, 55.11, 61.31, 67.35, 73.68, 80.95, 90.67, 106.27, 134.65] | P -Alkalinen fosfataasi | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 822 | p-aldos | pmol/l | 978 | 0 | [88.37, 146.16, 190.71, 235.98, 287.48, 347.26, 419.69, 540.86, 783.53] | P -Aldosteroni | Plasma |  | Aldosterone [Moles/volume] in Serum or Plasma | FALSE |
| 823 | p-aldos |  | 71 | 88.73 |  | P -Aldosteroni | Plasma |  | Aldosterone [Moles/volume] in Serum or Plasma | FALSE |
| 824 | p-amyl | u/l | 368852 | 0.02 | [26.2, 33.98, 40.36, 46.26, 52.37, 59.2, 67.68, 79.78, 104.76] | P -Amylaasi | Plasma |  | Amylase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 825 | p-amyl |  | 5758 | 100 | [29, 36.73, 43, 48.41, 54.21, 60.53, 68.18, 78.9, 100.7] | P -Amylaasi | Plasma |  | Amylase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 826 | p-amylaasi | u/l | 1560 | 0 | [28.07, 35.77, 41.54, 47.32, 52.57, 59.03, 66.78, 77.77, 99.14] |  | Plasma |  | Amylase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 827 | p-amylaasi |  | 28 | 89.29 |  |  | Plasma |  | Amylase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 828 | p-amylp | u/l | 96538 | 0 | [14.27, 20, 23.24, 26.43, 29.95, 34.28, 40.26, 51.17, 86.4] | P -Amylaasi, haimaperäinen | Plasma |  | Amylase.pancreatic [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 829 | p-amylp |  | 16102 | 100 | [12.88, 17.77, 21.4, 24.41, 27.47, 31.02, 35.38, 42.83, 60.62] | P -Amylaasi, haimaperäinen | Plasma |  | Amylase.pancreatic [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 830 | p-sldl | mmol/l | 2968 | 0 | [1.54, 1.82, 2.07, 2.32, 2.6, 2.9, 3.19, 3.53, 4.07] |  | Plasma |  | Cholesterol in small dense LDL [Moles/volume] in Serum or Plasma | FALSE |
| 831 | p-sldl |  | 282 | 86.52 |  |  | Plasma |  | Cholesterol in small dense LDL [Moles/volume] in Serum or Plasma | FALSE |
| 832 | pa-amyl | u/l | 181 | 0 | [6, 8.3, 13.62, 23.54, 38.11, 86.55, 532.84, 2066.13, 14410] | Pa-Amylaasi | Pancreatic juice |  | Amylase [Enzymatic activity/volume] in Pancreatic fluid | FALSE |
| 833 | pa-amyl |  | 13 | 100 |  | Pa-Amylaasi | Pancreatic juice |  | Amylase [Enzymatic activity/volume] in Pancreatic fluid | FALSE |
| 834 | pf-amyl | u/l | 512 | 0 | [11.47, 15.64, 19.01, 23.1, 27.84, 32.18, 37.92, 46.58, 62.15] | Pf-Amylaasi | Pleural fluid |  | Amylase [Enzymatic activity/volume] in Pleural fluid | FALSE |
| 835 | pf-amyl |  | 216 | 100 |  | Pf-Amylaasi | Pleural fluid |  | Amylase [Enzymatic activity/volume] in Pleural fluid | FALSE |
| 836 | s-aaldos | pmol/l | 125 | 0.8 | [506.75, 663.13, 772.54, 837.76, 918.5, 1062, 1146, 1442.2, 2247] |  | Serum |  |  | FALSE |
| 837 | s-adali | mg/l | 1092 | 0.37 | [4.24, 6.27, 7.87, 9.1, 10.33, 11.83, 13.14, 14.95, 17.6] | S -Adalimumabi | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma | FALSE |
| 838 | s-adali |  | 600 | 16.67 | [3.21, 5.15, 6.89, 8.21, 9.3, 11.07, 13.15, 15.09, 18] | S -Adalimumabi | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma | FALSE |
| 839 | s-adaliab | au/ml | 257 | 1.17 | [4.47, 14.51, 21.55, 36.22, 43.39, 60.38, 104.64, 181.31, 370.6] | S -Adalimumabi, vasta-aineet | Serum |  | Adalimumab Ab [Units/volume] in Serum or Plasma | FALSE |
| 840 | s-adaliab |  | 2149 | 99.3 |  | S -Adalimumabi, vasta-aineet | Serum |  | Adalimumab Ab [Presence] in Serum or Plasma | FALSE |
| 841 | s-adalimu | mg/l | 2004 | 0 | [3.43, 5.38, 6.89, 8.1, 9.37, 10.76, 12.24, 13.87, 16.85] |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma | FALSE |
| 842 | s-adalimu |  | 271 | 52.03 | [2.22, 3.86, 5.11, 6.02, 6.96, 7.78, 8.44, 9.23, 10.15] |  | Serum |  | Adalimumab [Mass/volume] in Serum or Plasma | FALSE |
| 843 | s-adalip |  | 274 | 100 |  |  | Serum |  |  | FALSE |
| 844 | s-adalipa |  | 1304 | 100 |  |  | Serum |  |  | FALSE |
| 845 | s-afluu | % | 92 | 0 | [10.3, 14.1, 19.33, 22.23, 25.37, 32.17, 35.52, 40.85, 45.6] |  | Serum |  |  | FALSE |
| 846 | s-afluu | u/l | 80 | 0 | [17.5, 21, 25.5, 29.5, 33.5, 38.75, 50, 58.5, 97.5] |  | Serum |  |  | FALSE |
| 847 | s-afluu |  | 9 | 77.78 |  |  | Serum |  |  | FALSE |
| 848 | s-afluust | u/l | 3036 | 0 | [23.45, 30.5, 36.88, 43.03, 49.77, 57.33, 66.23, 80.75, 107.75] |  | Serum |  |  | FALSE |
| 849 | s-afluust |  | 488 | 63.73 | [22.65, 29.23, 35.8, 41.92, 49.43, 57.83, 64.94, 75.26, 91.6] |  | Serum |  |  | FALSE |
| 850 | s-afmuut | u/l | 1555 | 0 | [0, 0, 0, 0.56, 2.03, 4.33, 8.12, 14.99, 30.62] |  | Serum |  |  | FALSE |
| 851 | s-afmuut |  | 316 | 96.2 |  |  | Serum |  |  | FALSE |
| 852 | s-afos | iu/l | 240 | 0 | [47.27, 53.32, 59.23, 65.05, 70.65, 75.95, 84.63, 98.48, 130] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 853 | s-afos | u/l | 62976 | 0 | [49.01, 56.54, 62.55, 68.34, 74.46, 81.49, 90.44, 104.36, 129.97] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 854 | s-afos |  | 986 | 36 | [88.65, 108.98, 118.14, 127.37, 135.4, 144.04, 157.28, 186.3, 252.69] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 855 | s-afos-is | u/l | 70 | 0 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes | Alkaline phosphatase isoenzymes panel - Serum | TRUE |
| 856 | s-afos-is |  | 9083 | 99.98 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes | Alkaline phosphatase isoenzymes panel - Serum | TRUE |
| 857 | s-afosluu | u/l | 106 | 0 | [25.67, 31, 35.33, 39.5, 42, 50.37, 59.67, 72.5, 100] | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum | FALSE |
| 858 | s-afosluu | ug/l | 30 | 0 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone [Mass/volume] in Serum | FALSE |
| 859 | s-afosluu |  | 35 | 11.43 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  |  | FALSE |
| 860 | s-afospit | u/l | 177 | 0 | [96.72, 105.51, 113.04, 119.21, 129.13, 139.98, 153.3, 187.04, 317.98] |  | Serum |  |  | FALSE |
| 861 | s-afospit |  | 8 | 37.5 |  |  | Serum |  |  | FALSE |
| 862 | s-afsuol1 | u/l | 1064 | 0 | [0, 0, 0, 0, 0, 0.97, 2.27, 4.95, 11.83] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 863 | s-afsuol1 |  | 158 | 1.27 | [0, 0, 0, 0, 0.17, 1.4, 3, 6.28, 16.75] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 864 | s-afsuol2 | u/l | 1070 | 0 | [0, 0, 0, 0, 0, 0.76, 2.02, 4.43, 8.94] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 865 | s-afsuol2 |  | 156 | 0.64 | [0, 0, 0, 0, 0, 1.25, 3, 4.75, 8] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 866 | s-afsuol3 | u/l | 1075 | 0 | [0, 0, 0, 0, 0, 0, 0, 1, 1.91] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 867 | s-afsuol3 |  | 157 | 0.64 | [0, 0, 0, 0, 0, 0, 0, 1, 1] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 868 | s-afsuoli | % | 53 | 0 |  |  | Serum |  | Alkaline phosphatase.intestinal/Alkaline phosphatase.total in Serum | FALSE |
| 869 | s-afsuoli | u/l | 189 | 0 | [1, 2.2, 4.12, 5.94, 7, 9.07, 12.69, 23.37, 34.67] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 870 | s-afsuoli |  | 182 | 96.15 |  |  | Serum |  | Alkaline phosphatase.intestinal [Presence] in Serum | FALSE |
| 871 | s-albind | g/l | 815 | 0 | [34.39, 37.6, 39.38, 40.81, 42.07, 43.01, 44.01, 45.22, 47.08] |  | Serum |  | Albumin [Mass/volume] in Serum or Plasma | FALSE |
| 872 | s-albind |  | 155 | 25.81 | [33.15, 36.46, 38.93, 39.99, 41.28, 41.98, 42.86, 43.61, 45.95] |  | Serum |  | Albumin [Mass/volume] in Serum or Plasma | FALSE |
| 873 | s-albu | g/l | 554 | 0 | [34.76, 36.69, 38.29, 39.83, 40.76, 41.89, 43.25, 44.88, 46.93] |  | Serum |  | Albumin [Mass/volume] in Serum or Plasma | FALSE |
| 874 | s-albu |  | 12 | 33.33 |  |  | Serum |  | Albumin [Mass/volume] in Serum or Plasma | FALSE |
| 875 | s-album | g/l | 27997 | 0 | [31.02, 34.31, 36.21, 37.6, 38.74, 39.81, 40.91, 42.12, 43.69] |  | Serum |  | Albumin [Mass/volume] in Serum or Plasma | FALSE |
| 876 | s-album |  | 49 | 100 | [31.46, 35.04, 37.29, 38.99, 40.3, 41.52, 42.95, 44.52, 46.29] |  | Serum |  | Albumin [Mass/volume] in Serum or Plasma | FALSE |
| 877 | s-aldol | u/l | 3331 | 0.03 | [3.03, 3.84, 4, 4.87, 5, 5.94, 6.21, 7.11, 9.71] | S -Aldolaasi | Serum |  | Aldolase [Enzymatic activity/volume] in Serum | FALSE |
| 878 | s-aldol |  | 603 | 75.79 | [2.92, 3.62, 4.18, 4.48, 5.37, 5.7, 6.13, 7.21, 9.7] | S -Aldolaasi | Serum |  | Aldolase [Enzymatic activity/volume] in Serum | FALSE |
| 879 | s-aldos | pmol/l | 5247 | 0.88 | [80.92, 114.8, 152.73, 192.44, 237.39, 292.55, 361.76, 461.2, 667.49] | S -Aldosteroni | Serum |  | Aldosterone [Moles/volume] in Serum or Plasma | FALSE |
| 880 | s-aldos |  | 1207 | 72.49 | [89.4, 124.94, 166.83, 212.25, 274.25, 349.09, 455.92, 585.04, 869.75] | S -Aldosteroni | Serum |  | Aldosterone [Moles/volume] in Serum or Plasma | FALSE |
| 881 | s-aldos-m | pmol/l | 88 | 0 | [47, 57.1, 78.9, 115.83, 136, 213.63, 263.1, 334.4, 926] | S -Aldosteroni, makuu | Serum | Supine (lying down) | Aldosterone [Moles/volume] in Serum or Plasma --supine | FALSE |
| 882 | s-aldos-m |  | 66 | 68.18 |  | S -Aldosteroni, makuu | Serum | Supine (lying down) | Aldosterone [Moles/volume] in Serum or Plasma --supine | FALSE |
| 883 | s-aldos-p | pmol/l | 824 | 0 | [77.23, 114.1, 153.16, 191.49, 236.83, 292.92, 363.97, 474.9, 659.05] | S -Aldosteroni, pysty | Serum | Upright (standing) | Aldosterone [Moles/volume] in Serum or Plasma --upright | FALSE |
| 884 | s-aldos-p |  | 329 | 21.88 | [79.42, 123.32, 172.77, 232.62, 283.29, 334.05, 403.83, 552.65, 812.7] | S -Aldosteroni, pysty | Serum | Upright (standing) | Aldosterone [Moles/volume] in Serum or Plasma --upright | FALSE |
| 885 | s-alfa-1 | % | 11 | 0 |  |  | Serum |  | Alpha 1 globulin/Protein.total [Mass Fraction] in Serum | FALSE |
| 886 | s-alfa-1 | g/l | 30281 | 0 | [2.19, 2.42, 2.6, 2.72, 2.88, 3.03, 3.24, 3.54, 4.08] |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum | FALSE |
| 887 | s-alfa-1 |  | 50 | 100 | [1.5, 1.7, 1.88, 2.13, 2.38, 2.62, 2.88, 3.19, 3.81] |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum | FALSE |
| 888 | s-alfa-2 | % | 11 | 0 |  |  | Serum |  | Alpha 2 globulin/Protein.total [Mass Fraction] in Serum | FALSE |
| 889 | s-alfa-2 | g/l | 30219 | 0 | [5.45, 5.93, 6.31, 6.66, 7.01, 7.39, 7.84, 8.42, 9.36] |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum | FALSE |
| 890 | s-alfa-2 |  | 50 | 100 | [5.71, 6.15, 6.53, 6.83, 7.14, 7.51, 7.91, 8.44, 9.39] |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum | FALSE |
| 891 | s-alfa1 | g/l | 1708 | 0 | [1.45, 1.6, 1.7, 1.8, 1.95, 2.11, 2.38, 2.65, 3.03] |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum | FALSE |
| 892 | s-alfa1 |  | 92 | 25 |  |  | Serum |  | Alpha 1 globulin [Mass/volume] in Serum | FALSE |
| 893 | s-alfa2 | g/l | 1768 | 0 | [5.73, 6.28, 6.69, 6.98, 7.28, 7.59, 8.04, 8.57, 9.36] |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum | FALSE |
| 894 | s-alfa2 |  | 92 | 25 |  |  | Serum |  | Alpha 2 globulin [Mass/volume] in Serum | FALSE |
| 895 | s-allige | mg/l | 14 | 0 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab [Mass/volume] in Serum | FALSE |
| 896 | s-allige | u/ml | 1753 | 0 | [0.12, 0.19, 0.31, 0.51, 0.83, 1.39, 2.4, 4.64, 12.35] | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab [Units/volume] in Serum | FALSE |
| 897 | s-allige |  | 2748 | 99.71 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab [Presence] in Serum | FALSE |
| 898 | s-amyl | u/l | 10387 | 0 | [33.31, 39.8, 44.99, 49.81, 54.67, 59.75, 66.53, 75.22, 91.12] | S -Amylaasi | Serum |  | Amylase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 899 | s-amyl |  | 129 | 20.16 | [35, 42.3, 49.52, 56.4, 62.75, 71, 94.2, 128.3, 161] | S -Amylaasi | Serum |  | Amylase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 900 | s-amyl-is | form | 15 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes | Amylase isoenzymes panel - Serum | TRUE |
| 901 | s-amyl-is |  | 434 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes | Amylase isoenzymes panel - Serum | TRUE |
| 902 | s-amylp | u/l | 280 | 0 | [14.92, 20.3, 25.89, 30.35, 36.7, 44.3, 55.25, 69.52, 135.91] | S -Amylaasi, haimaperäinen | Serum |  | Amylase.pancreatic [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 903 | s-amylp |  | 66 | 16.67 |  | S -Amylaasi, haimaperäinen | Serum |  | Amylase.pancreatic [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 904 | s-amyls | u/l | 256 | 0 | [12.25, 18.54, 23.94, 28.43, 34.44, 44.93, 63.37, 81.22, 120.05] | S -Amylaasi, sylkiperäinen | Serum |  | Amylase.salivary [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 905 | s-amyls |  | 61 | 18.03 |  | S -Amylaasi, sylkiperäinen | Serum |  | Amylase.salivary [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 906 | s-dmklots | nmol/l | 15078 | 0.19 | [349.72, 488.38, 603.51, 717.55, 840.77, 973.75, 1127.96, 1320.3, 1616.71] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma | FALSE |
| 907 | s-dmklots | umol/l | 9051 | 0 | [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.95, 1.16, 1.45] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma | FALSE |
| 908 | s-dmklots | âumol/l | 32 | 0 |  | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma | FALSE |
| 909 | s-dmklots |  | 1117 | 100 | [0.79, 1.17, 292.49, 521.2, 721.89, 874.92, 1051.9, 1273.86, 1599.85] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine [Moles/volume] in Serum or Plasma | FALSE |
| 910 | s-gliade | u/ml | 23 | 60.87 |  |  | Serum |  | Gliadin deamidated Ab [Units/volume] in Serum | FALSE |
| 911 | s-gliade |  | 84 | 98.81 |  |  | Serum |  | Gliadin deamidated Ab [Presence] in Serum | FALSE |
| 912 | s-gliadie | u/ml | 531 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.02, 0.07, 0.24] |  | Serum |  | Gliadin deamidated IgE Ab [Units/volume] in Serum | FALSE |
| 913 | s-gliadie |  | 118 | 5.93 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Serum |  | Gliadin deamidated IgE Ab [Presence] in Serum | FALSE |
| 914 | s-hladsa |  | 847 | 100 |  |  | Serum |  | HLA donor specific Ab panel - Serum | TRUE |
| 915 | s-kalatue |  | 132 | 100 |  |  | Serum |  |  | FALSE |
| 916 | s-kolaige | u/ml | 14 | 100 |  |  | Serum |  | Dog (Canis familiaris) dander IgE Ab [Units/volume] in Serum | FALSE |
| 917 | s-kolaige |  | 181 | 100 |  |  | Serum |  | Dog (Canis familiaris) dander IgE Ab [Presence] in Serum | FALSE |
| 918 | s-kudosab |  | 1042 | 100 |  |  | Serum |  |  | FALSE |
| 919 | s-ngmuut |  | 16771 | 100 |  |  | Serum |  |  | FALSE |
| 920 | s-oaldos | pmol/l | 200 | 1.5 | [636.2, 2117.22, 7632.17, 17219.7, 36953.33, 62851.67, 87233.33, 130744.44, 214222.22] |  | Serum |  |  | FALSE |
| 921 | s-olants | nmol/l | 4003 | 0.07 | [53.03, 76.26, 97.99, 119.12, 141.44, 165.86, 195.39, 234.91, 291.91] | S -Olantsapiini | Serum |  | Olanzapine [Moles/volume] in Serum or Plasma | FALSE |
| 922 | s-olants |  | 595 | 31.43 | [58.73, 86.04, 110.31, 132.4, 158.88, 189.03, 219.38, 262.18, 324.46] | S -Olantsapiini | Serum |  | Olanzapine [Moles/volume] in Serum or Plasma | FALSE |
| 923 | s-ovalbue | u/ml | 86 | 1.16 | [0, 0.02, 0.03, 0.1, 0.23, 0.56, 2, 8.02, 21.8] |  | Serum |  | Ovalbumin IgE Ab [Units/volume] in Serum | FALSE |
| 924 | s-ovalbue |  | 16 | 81.25 |  |  | Serum |  | Ovalbumin IgE Ab [Presence] in Serum | FALSE |
| 925 | s-salis | mmol/l | 56 | 0 |  | S -Salisylaatit | Serum |  | Salicylate [Moles/volume] in Serum or Plasma | FALSE |
| 926 | s-salis | umol/l | 87 | 5.75 |  | S -Salisylaatit | Serum |  | Salicylate [Moles/volume] in Serum or Plasma | FALSE |
| 927 | s-salis |  | 121 | 97.52 |  | S -Salisylaatit | Serum |  | Salicylate [Presence] in Serum or Plasma | FALSE |
| 928 | s-scl-t |  | 833 | 100 |  |  | Serum |  |  | FALSE |
| 929 | s-sfit1 | ng/l | 135 | 0 | [1994, 2524.58, 3215, 3792.29, 4608.29, 5445.5, 7105.78, 9372.28, 11496.33] | S -Endoteelikasvutekijän liukoinen reseptori | Serum |  | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum or Plasma | FALSE |
| 930 | s-sflt-1 | ng/l | 318 | 0 | [1291.87, 1667.24, 2344.04, 3006.81, 3762.57, 4805.39, 6029.95, 7158.88, 9214.96] |  | Serum |  | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum or Plasma | FALSE |
| 931 | s-sldl | mmol/l | 2207 | 0 | [1.75, 2.1, 2.37, 2.68, 2.95, 3.22, 3.51, 3.8, 4.25] |  | Serum |  | Cholesterol in small dense LDL [Moles/volume] in Serum or Plasma | FALSE |
| 932 | s-sldl |  | 177 | 98.87 |  |  | Serum |  | Cholesterol in small dense LDL [Moles/volume] in Serum or Plasma | FALSE |
| 933 | s-suoli | u/l | 115 | 0 | [0, 0, 0, 0.27, 2.83, 5.44, 7.47, 12.05, 21.01] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 934 | s-suoli |  | 10 | 30 |  |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 935 | s-suolist | u/l | 81 | 0 | [2, 3.1, 5.23, 9, 10.88, 13, 15, 20.35, 28] |  | Serum |  | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | FALSE |
| 936 | s-suolist |  | 63 | 96.83 |  |  | Serum |  | Alkaline phosphatase.intestinal [Presence] in Serum | FALSE |
| 937 | s-valdos | pmol/l | 157 | 0.64 | [3435.33, 10631.9, 19753.33, 29394.05, 44768.33, 65139.29, 87875, 118200, 193300] |  | Serum |  |  | FALSE |
| 938 | s-vedol | mg/l | 1566 | 0 | [10.87, 14.08, 17.75, 20.76, 23.95, 27.59, 31.95, 37.11, 43.61] | S -Vedolitsumabi | Serum |  | Vedolizumab [Mass/volume] in Serum or Plasma | FALSE |
| 939 | s-vedol |  | 221 | 12.22 | [5.88, 9.27, 13.22, 17.42, 21.48, 25.78, 28.81, 33.33, 39.06] | S -Vedolitsumabi | Serum |  | Vedolizumab [Mass/volume] in Serum or Plasma | FALSE |
| 940 | saline |  | 946 | 3.38 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |  | FALSE |
| 941 | se-amyl | u/l | 1679 | 0.83 | [7.84, 14.57, 24.16, 42.2, 81.52, 202.31, 555.29, 1833.05, 9919.76] | Se-Amylaasi | Secretion |  | Amylase [Enzymatic activity/volume] in Secretion | FALSE |
| 942 | se-amyl |  | 248 | 97.98 |  | Se-Amylaasi | Secretion |  | Amylase [Enzymatic activity/volume] in Secretion | FALSE |
| 943 | sp-suld |  | 262 | 100 |  |  | Sperm / semen |  |  | FALSE |
| 944 | u-amyl | u/l | 2762 | 0.04 | [40.07, 60.75, 84.23, 110.48, 142.21, 184.16, 244.01, 332.59, 547.07] | U -Amylaasi | Urine |  | Amylase [Enzymatic activity/volume] in Urine | FALSE |
| 945 | u-amyl |  | 192 | 49.48 | [46, 98.65, 135.92, 161.9, 205.44, 269.5, 358.67, 597.35, 1056] | U -Amylaasi | Urine |  | Amylase [Enzymatic activity/volume] in Urine | FALSE |
| 946 | u-amylp | u/l | 106 | 0 | [29, 44.7, 68.1, 90.36, 112.17, 155.8, 214.47, 337.6, 546] | U -Amylaasi, haimaperäinen | Urine |  | Amylase.pancreatic [Enzymatic activity/volume] in Urine | FALSE |
| 947 | u-amylp |  | 15 | 20 |  | U -Amylaasi, haimaperäinen | Urine |  | Amylase.pancreatic [Enzymatic activity/volume] in Urine | FALSE |

