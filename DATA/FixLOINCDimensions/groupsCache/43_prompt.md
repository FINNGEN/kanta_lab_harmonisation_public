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
Here is group 43.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3003191 | Choriogonadotropin [Presence] in Serum or Plasma | 1.000 | 615 |  3 |    28,800 |
| 3004248 | Sex hormone binding globulin [Moles/volume] in Serum or Plasma | 1.000 | 681 |  5 |    29,702 |
| 3004616 | Nuclear Ab [Presence] in Serum | 1.000 | 208 |  2 |     7,678 |
| 3005715 | Vancomycin [Mass/volume] in Serum or Plasma | 1.000 | 2009 |  3 |    38,617 |
| 3015171 | Extractable nuclear Ab [Units/volume] in Serum | 1.000 |  |  8 |    23,094 |
| 3018171 | Choriogonadotropin [Units/volume] in Serum or Plasma | 1.000 | 252 | 12 |    54,905 |
| 3018308 | Bromide [Moles/volume] in Serum or Plasma | 1.000 |  |  0 |         0 |
| 3018954 | Choriogonadotropin [Presence] in Urine | 1.000 | 184 |  0 |         0 |
| 3019603 | Treponema pallidum Ab [Presence] in Cerebral spinal fluid | 1.000 |  |  0 |         0 |
| 3019832 | Treponema pallidum Ab [Presence] in Serum | 1.000 | 962 |  5 |   108,068 |
| 3021236 | Streptolysin O Ab [Units/volume] in Serum or Plasma | 1.000 | 744 |  2 |     2,450 |
| 3023511 | Choriogonadotropin [Units/volume] in Urine | 1.000 |  |  2 |    15,027 |
| 3029075 | Extractable nuclear Ab panel - Serum | 1.000 |  |  4 |     3,253 |
| 3034780 | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 730 |  6 |    39,648 |
| 3035510 | Gentamicin [Mass/volume] in Serum or Plasma | 1.000 | 1092 |  3 |       712 |
| 3036152 | Amikacin [Mass/volume] in Serum or Plasma | 1.000 |  |  0 |         0 |
| 3037522 | Nuclear Ab [Titer] in Serum | 1.000 | 890 | 21 |    91,824 |
| 3052649 | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma | 1.000 |  |  3 |     4,406 |
| 40758310 | Human epididymis protein 4 [Moles/volume] in Serum or Plasma | 1.000 |  |  8 |    14,218 |
| 42869548 | Treponema pallidum Ab [Titer] in Serum or Plasma by Agglutination | 0.982 |  |  0 |         0 |
| 3024172 | Erythropoietin (EPO) [Units/volume] in Serum or Plasma | 0.980 | 838 |  9 |     9,513 |
| 3015916 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma | 0.977 |  |  2 |    18,403 |
| 3029759 | Cold agglutinin [Presence] in Serum or Plasma | 0.975 |  |  0 |         0 |
| 3035947 | Staphylolysin Ab [Units/volume] in Serum | 0.975 |  |  4 |     2,520 |
| 3033818 | Extractable nuclear Ab [Units/volume] in Serum by Immunoassay | 0.972 |  |  0 |         0 |
| 3014339 | Estrone (E1) [Moles/volume] in Serum or Plasma | 0.971 | 1123 |  3 |       153 |
| 3031591 | Treponema pallidum Ab [Titer] in Cerebral spinal fluid by Hemagglutination | 0.970 |  |  0 |         0 |
| 3009306 | Alpha-1-Fetoprotein [Mass/volume] in Serum or Plasma | 0.969 | 386 |  1 |     2,510 |
| 3001686 | Cold agglutinin [Titer] in Serum or Plasma | 0.968 |  |  2 |       999 |
| 3028050 | Streptolysin O Ab [Titer] in Serum | 0.967 | 1851 |  1 |         7 |
| 3007932 | Treponema pallidum Ab [Titer] in Serum by Latex agglutination | 0.966 |  |  0 |         0 |
| 3027880 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Serum or Plasma | 0.960 | 833 |  0 |         0 |
| 3029371 | Treponema pallidum Ab [Titer] in Cerebral spinal fluid | 0.959 |  |  0 |         0 |
| 3019539 | Treponema pallidum Ab [Titer] in Serum by Hemagglutination | 0.959 |  |  3 |    11,457 |
| 3009461 | 5-Hydroxyindoleacetate [Moles/time] in 24 hour Urine | 0.959 | 1449 |  1 |       150 |
| 3026725 | Estradiol (E2) [Moles/volume] in Serum or Plasma | 0.959 | 231 |  5 |    12,778 |
| 3016616 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in Serum or Plasma | 0.956 | 468 |  3 |     4,116 |
| 40761135 | Treponema pallidum IgG Ab [Presence] in Cerebral spinal fluid | 0.955 |  |  0 |         0 |
| 3025393 | Cold agglutinin [Presence] in Serum or Plasma by Agglutination | 0.954 |  |  0 |         0 |
| 3016103 | Fatty acids [Moles/volume] in Serum or Plasma | 0.950 |  |  0 |         0 |
| 3026383 | Bromide [Mass/volume] in Serum or Plasma | 0.950 |  |  0 |         0 |
| 3030136 | 5-Hydroxyindoleacetate [Moles/volume] in Serum or Plasma | 0.949 |  |  3 |    10,452 |
| 42529203 | Choriogonadotropin [Units/volume] in Serum or Plasma by Immunoassay | 0.949 |  |  0 |         0 |
| 3036309 | 5-Hydroxyindoleacetate [Moles/volume] in Urine | 0.948 |  |  0 |         0 |
| 3040662 | Nuclear Ab [Titer] in Serum by Immunoassay | 0.947 |  |  0 |         0 |
| 36031680 | Human epididymis protein 4 [Mass/volume] in Serum or Plasma | 0.947 |  |  0 |         0 |
| 42868681 | Estrogen [Moles/volume] in Serum or Plasma | 0.947 | 920 |  0 |         0 |
| 3010055 | Treponema pallidum Ab [Titer] in Serum | 0.944 |  |  0 |         0 |
| 1617619 | Treponema pallidum Ab [Presence] in Cerebral spinal fluid by Immunoassay | 0.943 |  |  0 |         0 |
| 3014044 | Treponema pallidum Ab [Presence] in Cerebral spinal fluid by Immunofluorescence | 0.941 |  |  0 |         0 |
| 3011520 | Treponema pallidum Ab [Presence] in Serum by Immunoassay | 0.940 |  |  0 |         0 |
| 3004786 | Treponema pallidum Ab [Presence] in Serum by Agglutination | 0.939 | 1818 |  0 |         0 |
| 3050002 | Nuclear Ab [Presence] in Serum by Immunoassay | 0.939 | 1546 |  0 |         0 |
| 3031166 | Choriogonadotropin [Mass/volume] in Serum or Plasma | 0.937 |  |  0 |         0 |
| 3036988 | Choriogonadotropin.intact [Units/volume] in Serum or Plasma | 0.936 | 834 |  0 |         0 |
| 3010935 | Vancomycin [Moles/volume] in Serum or Plasma | 0.936 | 2009 |  0 |         0 |
| 3026531 | Cold agglutinin [Titer] in Serum or Plasma by Agglutination | 0.936 |  |  0 |         0 |
| 3011981 | Treponema pallidum IgG Ab [Presence] in Serum | 0.932 | 562 |  0 |         0 |
| 1989578 | Choriogonadotropin [Mass/volume] in Urine | 0.931 |  |  0 |         0 |
| 42529189 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma by Immunoassay | 0.930 |  |  0 |         0 |
| 3029103 | Nuclear Ab [Presence] in Serum by Immunofluorescence | 0.930 |  |  0 |         0 |
| 3029998 | Treponema pallidum Ab [Presence] in Cerebral spinal fluid by Hemagglutination | 0.929 |  |  0 |         0 |
| 3002971 | Nuclear Ab [Titer] in Serum by Immunofluorescence | 0.928 | 345 |  0 |         0 |
| 3009960 | Adenosine deaminase [Enzymatic activity/volume] in Blood | 0.928 |  |  0 |         0 |
| 3009471 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma | 0.926 |  |  1 |       518 |
| 3024286 | Treponema pallidum Ab [Presence] in Serum by Immobilization | 0.925 |  |  0 |         0 |
| 646451 | Extractable nuclear Ab [Measurement] in Serum | 0.925 |  |  0 |         0 |
| 3022237 | Choriogonadotropin [Moles/volume] in Urine | 0.923 |  |  0 |         0 |
| 3007061 | Streptolysin O Ab [Units/volume] in Serum by Latex agglutination | 0.923 |  |  0 |         0 |
| 3037123 | Amikacin [Mass/volume] in Serum or Plasma --trough | 0.923 |  |  0 |         0 |
| 3018920 | Vancomycin [Mass/volume] in Serum or Plasma --trough | 0.923 | 382 |  0 |         0 |
| 3053140 | Gentamicin [Moles/volume] in Serum or Plasma | 0.923 | 1092 |  0 |         0 |
| 3004624 | Choriogonadotropin.intact [Presence] in Serum or Plasma | 0.921 |  |  0 |         0 |
| 3002091 | Choriogonadotropin [Moles/volume] in Serum or Plasma | 0.921 |  |  0 |         0 |
| 40766119 | Extractable nuclear Ab [Units/volume] in Body fluid by Immunoassay | 0.921 |  |  0 |         0 |
| 3016254 | Gentamicin [Mass/volume] in Serum or Plasma --trough | 0.920 | 871 |  0 |         0 |
| 3028061 | Treponema pallidum Ab [Presence] in Serum by Hemagglutination | 0.920 |  |  0 |         0 |
| 3014854 | Endomysium Ab [Presence] in Serum | 0.920 |  |  0 |         0 |
| 3016278 | Endomysium IgA Ab [Presence] in Serum | 0.920 | 547 |  0 |         0 |
| 42869135 | Cold agglutinin [Presence] in Serum by 28 degree C incubation | 0.920 |  |  0 |         0 |
| 40759747 | Amikacin [Moles/volume] in Serum or Plasma | 0.920 |  |  0 |         0 |
| 3016587 | Treponema sp Ab [Presence] in Serum | 0.919 |  |  0 |         0 |
| 3015128 | Streptolysin O Ab [Units/volume] in Body fluid | 0.918 |  |  0 |         0 |
| 3016921 | Smith extractable nuclear Ab [Units/volume] in Serum | 0.918 | 560 | 10 |    17,352 |
| 3038911 | Alpha-1-fetoprotein.tumor marker [Units/volume] in Serum or Plasma | 0.918 |  |  0 |         0 |
| 3011099 | Sex hormone binding globulin [Mass/volume] in Serum or Plasma | 0.918 |  |  0 |         0 |
| 42869134 | Cold agglutinin [Presence] in Serum by 22 degree C incubation | 0.918 |  |  0 |         0 |
| 3010801 | 5-Hydroxyindoleacetate [Moles/volume] in 24 hour Urine | 0.918 |  |  1 |        25 |
| 3005148 | 5-Hydroxyindoleacetate [Mass/time] in 24 hour Urine | 0.917 |  |  0 |         0 |
| 3045488 | Treponema pallidum Ab [Titer] in Serum by Immunofluorescence | 0.917 |  |  0 |         0 |
| 3023640 | Estrone (E1) [Mass/volume] in Serum or Plasma | 0.917 |  |  0 |         0 |
| 42869133 | Cold agglutinin [Presence] in Serum by 18 degree C incubation | 0.916 |  |  0 |         0 |
| 3036335 | Angiotensin converting enzyme [Enzymatic activity/volume] in Blood | 0.916 | 1299 |  0 |         0 |
| 1616967 | Treponema pallidum IgG Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.916 |  |  0 |         0 |
| 3004772 | Treponema pallidum Ab [Presence] in Serum by Immunofluorescence | 0.915 | 1016 |  0 |         0 |
| 40761845 | Treponema pallidum IgG Ab [Presence] in Cerebral spinal fluid by Immunofluorescence | 0.914 |  |  0 |         0 |
| 3018358 | Nuclear Ab [Titer] in Body fluid | 0.914 |  |  0 |         0 |
| 3042164 | Endomysium IgG Ab [Presence] in Serum | 0.913 |  |  0 |         0 |
| 3005886 | Vancomycin Free [Mass/volume] in Serum or Plasma | 0.913 |  |  0 |         0 |
| 40760151 | Treponema pallidum Ab [Presence] in Serum by Immunoblot | 0.912 |  |  0 |         0 |
| 3036065 | Streptolysin O Ab [Titer] in Serum by Latex agglutination | 0.912 |  |  0 |         0 |
| 42529190 | Alpha-1-Fetoprotein [Mass/volume] in Serum or Plasma by Immunoassay | 0.911 |  |  0 |         0 |
| 3048833 | Staphylolysin Ab [Units/volume] in Body fluid | 0.911 |  |  0 |         0 |
| 645783 | Treponema pallidum Ab [Measurement] in Cerebral spinal fluid | 0.908 |  |  0 |         0 |
| 1175777 | Alpha-1-Fetoprotein Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.908 |  |  0 |         0 |
| 649009 | Nuclear Ab [Measurement] in Serum | 0.907 |  |  0 |         0 |
| 3032397 | Treponema pallidum Ab [Units/volume] in Cerebral spinal fluid by Hemagglutination | 0.907 |  |  0 |         0 |
| 3030077 | Nuclear Ab [Titer] in Serum by Hep2 substrate | 0.907 |  |  0 |         0 |
| 21492990 | Choriogonadotropin [Presence] in Urine by Rapid immunoassay | 0.907 |  |  0 |         0 |
| 3039783 | Alpha-1-fetoprotein.tumor marker [Mass/volume] in Serum or Plasma | 0.906 | 746 |  0 |         0 |
| 3046268 | Streptolysin O Ab [Mass/volume] in Serum | 0.906 |  |  0 |         0 |
| 3021106 | 5-Hydroxyindoleacetate [Mass/volume] in Serum or Plasma | 0.904 |  |  0 |         0 |
| 3011461 | Vancomycin [Mass/volume] in Serum or Plasma --peak | 0.904 | 937 |  0 |         0 |
| 3046743 | Choriogonadotropin [Presence] in Control Serum | 0.904 |  |  0 |         0 |
| 3011089 | Cold agglutinin [Titer] in Serum or Plasma by Cord RBC agglutination | 0.903 |  |  0 |         0 |
| 3036184 | Bromide [Moles/volume] in Blood | 0.903 |  |  0 |         0 |
| 3009917 | Gentamicin [Mass/volume] in Serum or Plasma --peak | 0.903 | 965 |  0 |         0 |
| 3029054 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --5th specimen fasting | 0.903 |  |  0 |         0 |
| 3032218 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --3rd specimen fasting | 0.902 |  |  0 |         0 |
| 3029555 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --1st specimen fasting | 0.901 |  |  0 |         0 |
| 1616334 | Vancomycin [Mass/volume] in Serum or Plasma --2 hours post dose | 0.901 |  |  0 |         0 |
| 3010487 | Treponema pallidum Ab [Units/volume] in Serum by Latex agglutination | 0.901 |  |  0 |         0 |
| 21494226 | Gentamicin free [Mass/volume] in Serum or Plasma | 0.901 |  |  0 |         0 |
| 648716 | Choriogonadotropin [Measurement] in Serum or Plasma | 0.900 |  |  0 |         0 |
| 3021607 | Alpha-1-Fetoprotein [Moles/volume] in Serum or Plasma | 0.900 |  |  0 |         0 |
| 3010554 | Cold agglutinin [Titer] in Serum or Plasma by Adult RBC Agglutination | 0.900 |  |  0 |         0 |
| 3002225 | Fatty acids [Mass/volume] in Serum or Plasma | 0.900 |  |  0 |         0 |
| 3041672 | Baker's yeast Ab [Presence] in Serum | 0.900 |  |  1 |       315 |
| 1617505 | Treponema pallidum IgM Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.899 |  |  0 |         0 |
| 40761580 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --6th specimen fasting | 0.899 |  |  0 |         0 |
| 3008977 | Amikacin [Mass/volume] in Serum or Plasma --peak | 0.899 |  |  0 |         0 |
| 3009417 | Choriogonadotropin.beta subunit [Presence] in Urine | 0.898 | 1227 |  0 |         0 |
| 21494227 | Amikacin free [Mass/volume] in Serum or Plasma | 0.898 |  |  3 |       602 |
| 40765159 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --10th specimen fasting | 0.898 |  |  0 |         0 |
| 3003927 | Nuclear Ab [Titer] in Synovial fluid | 0.898 |  |  0 |         0 |
| 3038136 | Choriogonadotropin.beta subunit [Units/volume] in Serum or Plasma | 0.897 | 364 |  0 |         0 |
| 3011149 | Choriogonadotropin.beta subunit [Presence] in Serum or Plasma | 0.896 | 477 |  0 |         0 |
| 3032697 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --4th specimen fasting | 0.896 |  |  0 |         0 |
| 40761579 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --7th specimen fasting | 0.896 |  |  0 |         0 |
| 1616440 | Treponema pallidum IgG Ab [Presence] in Cerebral spinal fluid by Immunoblot | 0.895 |  |  0 |         0 |
| 648034 | Choriogonadotropin [Measurement] in Urine | 0.895 |  |  0 |         0 |
| 21492226 | Cold agglutinin [Titer] in Serum by 4 deg C incubation --1 hour post incubation | 0.895 |  |  0 |         0 |
| 40765157 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --8th specimen fasting | 0.894 |  |  0 |         0 |
| 3045792 | Smith extractable nuclear Ab [Units/volume] in Serum by Immunoassay | 0.894 | 2017 |  0 |         0 |
| 3017683 | Nuclear Ab [Presence] in Body fluid | 0.894 |  |  0 |         0 |
| 3027505 | Alpha-1-Fetoprotein [Units/volume] in Amniotic fluid | 0.893 | 1501 |  1 |        73 |
| 3021385 | 5-Hydroxyindoleacetate [Mass/volume] in Urine | 0.892 |  |  0 |         0 |
| 647790 | Streptolysin O Ab [Measurement] in Serum | 0.891 |  |  0 |         0 |
| 3004536 | Choriogonadotropin [Interpretation] in Serum or Plasma | 0.890 |  |  0 |         0 |
| 21492991 | Choriogonadotropin [Presence] in Serum by Rapid immunoassay | 0.890 |  |  0 |         0 |
| 3045958 | Alpha-1-Fetoprotein [Units/volume] in Body fluid | 0.890 |  |  0 |         0 |
| 646220 | Cold agglutinin [Measurement] in Serum | 0.890 |  |  0 |         0 |
| 3046839 | Endomysium IgA Ab [Presence] in Serum by Immunofluorescence | 0.889 |  |  0 |         0 |
| 3038624 | Choriogonadotropin.tumor marker [Units/volume] in Serum or Plasma | 0.889 |  |  0 |         0 |
| 3027536 | Estrone sulfate [Mass/volume] in Serum or Plasma | 0.887 |  |  0 |         0 |
| 3046071 | Choriogonadotropin.intact+Beta subunit [Units/volume] in Serum or Plasma | 0.887 |  |  0 |         0 |
| 42529214 | Estradiol (E2) [Moles/volume] in Serum or Plasma by Immunoassay | 0.887 |  |  0 |         0 |
| 40762162 | Nuclear Ab [Presence] in Serum by Hep2 substrate | 0.887 |  |  0 |         0 |
| 21492225 | Cold agglutinin [Titer] in Serum by 22 degree C incubation --1 hour post incubation | 0.887 |  |  0 |         0 |
| 40766122 | Extractable nuclear Ab [Presence] in Serum by Immunoassay | 0.886 |  |  0 |         0 |
| 3023122 | Fatty acids.very long chain [Moles/volume] in Serum or Plasma | 0.886 | 1826 |  0 |         0 |
| 3037641 | Choriogonadotropin [Units/volume] in Body fluid | 0.885 |  |  0 |         0 |
| 40759269 | Smith extractable nuclear Ab and Ribonucleoprotein extractable nuclear Ab panel - Serum | 0.885 |  |  0 |         0 |
| 3034165 | Alpha-1-Fetoprotein [Mass/volume] in Body fluid | 0.884 |  |  0 |         0 |
| 3023191 | Choriogonadotropin.alpha subunit [Presence] in Serum or Plasma | 0.884 |  |  0 |         0 |
| 3018904 | Nuclear Ab [Titer] in Pleural fluid | 0.883 |  |  0 |         0 |
| 3037437 | Adenosine deaminase [Enzymatic activity/volume] in Body fluid | 0.883 |  |  0 |         0 |
| 1176189 | Extractable nuclear antigen Ab.IgG panel - Serum | 0.883 |  |  0 |         0 |
| 3013293 | Extractable nuclear Ab [Presence] in Serum | 0.881 |  |  1 |        20 |
| 3005831 | Streptolysin O Ab [Units/volume] in Synovial fluid | 0.881 |  |  0 |         0 |
| 3025285 | Estradiol (E2) [Mass/volume] in Serum or Plasma | 0.881 |  |  0 |         0 |
| 648067 | Alpha-1-Fetoprotein [Measurement] in Serum or Plasma | 0.881 |  |  0 |         0 |
| 3022000 | Dehydroepiandrosterone (DHEA) [Mass/volume] in Serum or Plasma | 0.881 |  |  0 |         0 |
| 3005135 | Extractable nuclear Ab [Identifier] in Serum | 0.880 |  |  0 |         0 |
| 40758605 | Estradiol (E2) [Moles/volume] in Serum or Plasma --baseline | 0.880 |  |  0 |         0 |
| 1617524 | Alpha-1-Fetoprotein [Units/volume] in Aspirate | 0.880 |  |  0 |         0 |
| 21492227 | Cold agglutinin [Titer] in Serum by 4 deg C incubation --24 hour post incubation | 0.880 |  |  0 |         0 |
| 3015884 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma | 0.880 |  |  0 |         0 |
| 42868435 | Treponema pallidum IgM Ab [Presence] in Cerebral spinal fluid by Immunoblot | 0.879 |  |  0 |         0 |
| 1091389 | Endomysium IgG Ab [Presence] in Serum by Immunofluorescence | 0.879 |  |  0 |         0 |
| 3002924 | Fatty acids.nonesterified [Mass/volume] in Serum or Plasma | 0.879 |  |  0 |         0 |
| 21492224 | Cold agglutinin [Titer] in Serum by 37 degree C incubation --1 hour post incubation | 0.879 |  |  0 |         0 |
| 3005574 | Amikacin [Mass/volume] in Serum or Plasma --trough post extended interval dosing | 0.879 |  |  0 |         0 |
| 40758603 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Serum or Plasma --baseline | 0.879 |  |  0 |         0 |
| 3000502 | Smith extractable nuclear Ab [Units/volume] in Serum by Immunofluorescence | 0.878 |  |  0 |         0 |
| 3012631 | Estriol (E3) [Moles/volume] in Serum or Plasma | 0.878 | 1565 |  0 |         0 |
| 3010296 | Alpha-1-Fetoprotein [Mass/volume] in Amniotic fluid | 0.877 |  |  0 |         0 |
| 3043496 | Extractable nuclear Ab [Interpretation] in Serum | 0.877 |  |  0 |         0 |
| 3008080 | Adenosine monophosphate deaminase [Enzymatic activity/volume] in Serum | 0.877 |  |  0 |         0 |
| 3019258 | Amikacin [Mass/volume] in Body fluid | 0.877 |  |  0 |         0 |
| 3018680 | Endomysium Ab [Presence] in Serum by Immunofluorescence | 0.876 |  |  0 |         0 |
| 43534046 | Estradiol (E2) [Moles/volume] in Serum or Plasma by High sensitivity method | 0.876 |  |  6 |     1,408 |
| 3052820 | Kanamycin [Mass/volume] in Serum or Plasma | 0.874 |  |  0 |         0 |
| 3052507 | Netilmicin [Mass/volume] in Serum or Plasma | 0.874 |  |  0 |         0 |
| 40762469 | Amikacin [Mass/volume] in Serum or Plasma --post dialysis | 0.873 |  |  0 |         0 |
| 3023028 | 5-Hydroxyindoleacetate [Mass/volume] in 24 hour Urine | 0.872 |  |  0 |         0 |
| 3015760 | Choriogonadotropin [Presence] in Body fluid | 0.871 |  |  0 |         0 |
| 3039257 | Vancomycin [Moles/volume] in Serum or Plasma --trough | 0.871 | 382 |  0 |         0 |
| 3035509 | Tobramycin [Mass/volume] in Serum or Plasma | 0.870 | 1858 |  3 |     1,365 |
| 42529191 | Alpha-1-Fetoprotein [Units/volume] in Amniotic fluid by Immunoassay | 0.870 |  |  0 |         0 |
| 1617106 | Alpha-1-Fetoprotein [Mass/volume] in Aspirate | 0.869 |  |  0 |         0 |
| 3018337 | Streptolysin O Ab [Presence] in Serum | 0.869 |  |  0 |         0 |
| 3026429 | Gentamicin [Mass/volume] in Serum or Plasma --trough post extended interval dosing | 0.869 |  |  0 |         0 |
| 3008692 | Estrone (E1) [Moles/volume] in Urine | 0.868 |  |  0 |         0 |
| 3032897 | Saturated fatty acids [Moles/volume] in Serum or Plasma | 0.868 |  |  0 |         0 |
| 40762472 | Vancomycin [Mass/volume] in Serum or Plasma --post dialysis | 0.867 |  |  0 |         0 |
| 3002412 | Gentamicin [Moles/volume] in Serum or Plasma --trough | 0.866 | 871 |  0 |         0 |
| 648828 | Cold agglutinin [Measurement] in Serum or Plasma | 0.866 |  |  0 |         0 |
| 3011339 | Nuclear IgG Ab [Presence] in Serum | 0.866 |  |  0 |         0 |
| 3051055 | Staphylolysin Ab [Titer] in Serum | 0.865 |  |  0 |         0 |
| 3051403 | 5-Hydroxyindoleacetate [Moles/volume] in Cerebral spinal fluid | 0.865 |  |  0 |         0 |
| 3009623 | Estrone (E1).unconjugated [Mass/volume] in Serum or Plasma | 0.864 |  |  0 |         0 |
| 647414 | Erythropoietin (EPO) [Measurement] in Serum or Plasma | 0.863 |  |  0 |         0 |
| 3003099 | Streptolysin O Ab [Units/volume] in Serum --1st specimen | 0.863 |  |  0 |         0 |
| 3019257 | Choriogonadotropin.beta subunit [Moles/volume] in Urine | 0.862 |  |  0 |         0 |
| 3016906 | Vancomycin [Mass/volume] in Body fluid | 0.862 |  |  0 |         0 |
| 40760543 | Extractable nuclear Ab [Presence] in Serum by Immunoblot | 0.861 |  |  3 |     2,898 |
| 3041244 | Adenosine deaminase [Enzymatic activity/volume] in Synovial fluid | 0.861 |  |  0 |         0 |
| 3027646 | Estrogen [Mass/volume] in Serum or Plasma | 0.860 |  |  0 |         0 |
| 40759782 | 5-Hydroxytryptophan [Moles/time] in 24 hour Urine | 0.858 |  |  0 |         0 |
| 3038531 | Vancomycin [Moles/volume] in Serum or Plasma --peak | 0.858 | 937 |  0 |         0 |
| 40768055 | Sex hormone binding globulin [Moles/volume] in Serum or Plasma --pre or post XXX challenge | 0.857 |  |  0 |         0 |
| 3013960 | Nuclear Ab [Presence] in Synovial fluid | 0.857 |  |  0 |         0 |
| 3036168 | 5-Hydroxyindoleacetate [Presence] in 24 hour Urine | 0.856 |  |  0 |         0 |
| 3045640 | Choriogonadotropin [Units/volume] in Amniotic fluid | 0.856 |  |  0 |         0 |
| 3015881 | Streptolysin O Ab [Units/volume] in Serum --2nd specimen | 0.855 |  |  0 |         0 |
| 3037371 | Bromide [Moles/volume] in Urine | 0.855 |  |  0 |         0 |
| 3003581 | Estrone (E1).bioavailable [Mass/volume] in Serum or Plasma | 0.852 |  |  0 |         0 |
| 3031814 | Bromide [Mass/volume] in Blood | 0.851 |  |  0 |         0 |
| 3036428 | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid | 0.851 |  |  3 |     3,914 |
| 3032707 | 5-Hydroxytryptophan [Moles/volume] in Urine | 0.850 |  |  0 |         0 |
| 3028955 | 5-Hydroxytryptophan [Moles/volume] in Serum or Plasma | 0.849 |  |  0 |         0 |
| 3015004 | Erythrocytes [Presence] in Amniotic fluid | 0.846 | 1731 |  0 |         0 |
| 3038038 | Choriogonadotropin [Units/volume] in Semen | 0.846 |  |  0 |         0 |
| 3045218 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Urine | 0.844 |  |  0 |         0 |
| 3044334 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in Urine | 0.843 |  |  0 |         0 |
| 3034552 | Adenosine deaminase [Enzymatic activity/volume] in Cerebral spinal fluid | 0.843 |  |  2 |       279 |
| 3011229 | Endomysium Ab [Titer] in Serum | 0.843 | 1279 |  0 |         0 |
| 44816667 | 5-Hydroxyindoleacetate [Moles/volume] in Platelet rich plasma | 0.841 |  |  0 |         0 |
| 646173 | Estrone (E1) [Measurement] in Serum or Plasma | 0.840 |  |  0 |         0 |
| 647620 | Estrogen [Measurement] in Serum or Plasma | 0.838 |  |  0 |         0 |
| 3037750 | Candida albicans Ab [Presence] in Serum | 0.838 |  |  0 |         0 |
| 40758972 | Androstenediol [Moles/volume] in Serum or Plasma | 0.836 |  |  0 |         0 |
| 3014670 | 5-Hydroxyindoleacetate [Mass/volume] in Cerebral spinal fluid | 0.836 |  |  0 |         0 |
| 3023428 | Smith extractable nuclear Ab [Presence] in Serum | 0.836 |  |  0 |         0 |
| 44816943 | Adenosine deaminase [Enzymatic activity/volume] in DBS | 0.835 |  |  0 |         0 |
| 3047826 | Mullerian inhibiting substance [Mass/volume] in Serum or Plasma | 0.835 | 1599 |  3 |    10,872 |
| 646438 | 5-Hydroxyindoleacetate [Measurement] in Urine | 0.835 |  |  0 |         0 |
| 3022795 | Bromazepam [Moles/volume] in Serum or Plasma | 0.833 |  |  0 |         0 |
| 3001740 | Acetylcholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.833 |  |  0 |         0 |
| 3029213 | Adenosine deaminase [Enzymatic activity/volume] in Pericardial fluid | 0.833 |  |  0 |         0 |
| 3033252 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal fluid | 0.832 |  |  0 |         0 |
| 3051057 | 5-Hydroxyindoleacetate/Creatinine [Molar ratio] in 24 hour Urine | 0.831 |  |  0 |         0 |
| 21493418 | Baker's yeast IgG Ab [Presence] in Serum by Immunoassay | 0.830 |  |  0 |         0 |
| 3052277 | 11-Hydroxyandrostenedione [Moles/volume] in Serum or Plasma | 0.829 |  |  0 |         0 |
| 3040491 | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | 0.829 |  |  2 |       471 |
| 3021133 | Inter alpha trypsin inhibitor [Mass/volume] in Serum | 0.829 |  |  0 |         0 |
| 3036566 | Thyroxine binding globulin [Moles/volume] in Serum or Plasma | 0.828 |  |  1 |        12 |
| 3009695 | 17-Hydroxypregnenolone [Moles/volume] in Serum or Plasma | 0.828 |  |  0 |         0 |
| 3010774 | Pregnenolone [Moles/volume] in Serum or Plasma | 0.828 | 1374 |  0 |         0 |
| 3044096 | 5-Hydroxyindoleacetate panel - 24 hour Urine | 0.826 |  |  0 |         0 |
| 3020961 | Endomysium IgA Ab [Titer] in Serum | 0.826 | 1349 |  3 |    26,862 |
| 21492304 | Cold agglutinin panel - Serum | 0.824 |  |  0 |         0 |
| 648952 | Baker's yeast Ab [Measurement] in Serum | 0.821 |  |  0 |         0 |
| 3024445 | Bromide [Mass/volume] in Specimen | 0.820 |  |  0 |         0 |
| 649388 | Endomysium Ab [Measurement] in Serum | 0.819 |  |  0 |         0 |
| 3033680 | Candida sp Ab [Presence] in Serum | 0.818 |  |  0 |         0 |
| 3007370 | Saccharopolyspora rectivirgula Ab [Presence] in Serum | 0.818 | 1901 |  0 |         0 |
| 40758655 | Brompheniramine [Moles/volume] in Serum or Plasma | 0.818 |  |  0 |         0 |
| 3010866 | Cholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.817 |  |  0 |         0 |
| 3032773 | Endomysium IgG Ab [Titer] in Serum | 0.815 |  |  3 |     5,197 |
| 40759672 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma --baseline | 0.814 |  |  0 |         0 |
| 40760527 | Baker's yeast IgA Ab [Presence] in Serum by Immunoassay | 0.812 |  |  0 |         0 |
| 648351 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.811 |  |  0 |         0 |
| 3044342 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in 24 hour Urine | 0.810 |  |  0 |         0 |
| 3009991 | Angiotensin converting enzyme [Enzymatic activity/volume] in Cerebral spinal fluid | 0.810 |  |  3 |     2,955 |
| 3051263 | Dihydroxycholestanoate [Moles/volume] in Serum or Plasma | 0.810 |  |  0 |         0 |
| 3039179 | Angiotensin converting enzyme [Enzymatic activity/volume] in Peritoneal fluid | 0.809 |  |  0 |         0 |
| 3012673 | Bromide [Mass/volume] in Urine | 0.808 |  |  0 |         0 |
| 3037275 | Staphylococcus aureus Ab [Units/volume] in Serum | 0.807 |  |  0 |         0 |
| 3018595 | Inhibin A [Mass/volume] in Serum or Plasma | 0.806 | 702 |  0 |         0 |
| 40766065 | Baker's yeast IgG Ab [Presence] in Serum by Immunofluorescence | 0.806 |  |  0 |         0 |
| 3024732 | Candida albicans Ag [Presence] in Serum | 0.805 |  |  0 |         0 |
| 3039356 | Boron [Moles/volume] in Serum or Plasma | 0.805 |  |  0 |         0 |
| 40759904 | Baker's yeast Ab [Units/volume] in Serum | 0.801 |  |  0 |         0 |
| 42529221 | Mullerian inhibiting substance [Mass/volume] in Serum or Plasma by Immunoassay | 0.801 |  |  0 |         0 |
| 3007808 | Renin [Enzymatic activity/volume] in Plasma | 0.798 | 822 |  0 |         0 |
| 3017446 | Testosterone [Moles/volume] in Serum or Plasma | 0.797 | 203 | 11 |    93,098 |
| 3035485 | Oxytocin [Units/volume] in Serum or Plasma | 0.797 |  |  0 |         0 |
| 3049799 | Mullerian inhibiting substance [Moles/volume] in Serum or Plasma | 0.796 |  |  0 |         0 |
| 3020811 | Streptococcus sp Ab [Presence] in Serum | 0.795 |  |  0 |         0 |
| 3049189 | Streptococcus sp exoenzyme Ab [Units/volume] in Serum | 0.786 |  |  0 |         0 |
| 3012620 | Inhibin [Mass/volume] in Serum or Plasma | 0.786 |  |  0 |         0 |
| 3030073 | Trypsin [Mass/volume] in Serum or Plasma | 0.785 |  |  0 |         0 |
| 3045781 | Inhibin B [Mass/volume] in Serum or Plasma | 0.782 |  |  2 |     2,979 |
| 3031441 | Tripeptide aminopeptidase [Enzymatic activity/volume] in Serum or Plasma | 0.781 |  |  0 |         0 |
| 3036969 | Erythropoietin (EPO) given [Units/volume] of Dose | 0.779 |  |  0 |         0 |
| 3010356 | Uroporphyrin [Moles/volume] in Serum or Plasma | 0.779 |  |  0 |         0 |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.778 | 16 | 21 | 5,367,314 |
| 3025283 | Somatotropin binding protein [Moles/volume] in Serum or Plasma | 0.778 |  |  0 |         0 |
| 645118 | Mullerian inhibiting substance [Measurement] in Serum or Plasma | 0.776 |  |  0 |         0 |
| 3017363 | Streptococcal hyaluronidase Ab [Presence] in Serum | 0.775 |  |  0 |         0 |
| 3021387 | Prolactin [Units/volume] in Serum or Plasma | 0.773 |  |  4 |    33,582 |
| 3013495 | Streptokinase Ab [Units/volume] in Serum | 0.773 |  |  0 |         0 |
| 3008019 | Hyaluronidase Ab [Units/volume] in Serum | 0.772 |  |  0 |         0 |
| 3020924 | Thyroxine binding globulin [Mass/volume] in Serum or Plasma | 0.771 |  |  0 |         0 |
| 42529222 | Mullerian inhibiting substance [Moles/volume] in Serum or Plasma by Immunoassay | 0.771 |  |  0 |         0 |
| 3003351 | S Ab [Presence] in Serum or Plasma | 0.771 |  |  0 |         0 |
| 3035828 | Inhibin A [Multiple of the median] in Serum or Plasma | 0.770 |  |  0 |         0 |
| 44786755 | Endothelin [Moles/volume] in Serum or Plasma | 0.769 |  |  0 |         0 |
| 3013055 | A Ab [Presence] in Serum or Plasma | 0.768 |  |  0 |         0 |
| 3003084 | Osteocalcin [Moles/volume] in Serum or Plasma | 0.767 |  |  0 |         0 |
| 44786758 | Tissue inhibitor of metalloproteinases 1 [Mass/volume] in Serum or Plasma by Immunoassay | 0.767 |  |  0 |         0 |
| 3016598 | A1 Ab [Presence] in Serum or Plasma | 0.767 |  |  0 |         0 |
| 3025484 | Inhibin [Units/volume] in Serum or Plasma | 0.766 |  |  0 |         0 |
| 3052662 | Ceruloplasmin [Moles/volume] in Serum or Plasma | 0.766 |  |  0 |         0 |
| 3016244 | Insulin [Units/volume] in Serum or Plasma | 0.765 |  |  6 |    10,580 |
| 3009947 | Choriogonadotropin.beta subunit [Units/volume] in Amniotic fluid | 0.764 |  |  0 |         0 |
| 3022948 | Iron [Moles/volume] in Serum or Plasma | 0.764 | 140 | 15 |   207,654 |
| 3021925 | Trypsin+Trypsinogen [Mass/volume] in Serum or Plasma | 0.764 |  |  0 |         0 |
| 3005346 | Estradiol (E2) [Mass/volume] in Amniotic fluid | 0.763 |  |  0 |         0 |
| 3012260 | Yt sup(a) Ab [Presence] in Serum or Plasma | 0.763 |  |  0 |         0 |
| 3023763 | Trypsinogen [Mass/volume] in Serum or Plasma | 0.758 |  |  0 |         0 |
| 3009201 | Thyrotropin [Units/volume] in Serum or Plasma | 0.755 | 105 | 44 | 2,173,821 |
| 3010173 | Endothelin [Units/volume] in Serum or Plasma | 0.755 |  |  0 |         0 |
| 3044689 | Choriogonadotropin.intact [Units/volume] in Amniotic fluid | 0.750 |  |  0 |         0 |
| 46236055 | Erythropoietin (EPO) Ab [Presence] in Serum | 0.750 |  |  0 |         0 |
| 3009150 | Pregnanediol [Mass/volume] in Amniotic fluid | 0.747 |  |  0 |         0 |
| 3018301 | Testosterone Free [Moles/volume] in Serum or Plasma | 0.747 | 325 |  7 |     4,653 |
| 3013770 | Testosterone [Mass/volume] adjusted for sex hormone binding globulin in Serum or Plasma | 0.745 |  |  0 |         0 |
| 3000275 | Trypsinogen I Free [Mass/volume] in Serum or Plasma | 0.739 |  |  0 |         0 |
| 3042818 | Melanoma inhibitory activity protein [Mass/volume] in Serum or Plasma | 0.736 |  |  0 |         0 |
| 3024028 | Trypsin [Enzymatic activity/volume] in Serum or Plasma | 0.734 |  |  0 |         0 |
| 3019561 | Hemoglobin F [Presence] in Amniotic fluid | 0.733 |  |  0 |         0 |
| 3042084 | Tryptase [Moles/volume] in Serum or Plasma | 0.733 |  |  0 |         0 |
| 3019420 | Tryptase [Mass/volume] in Serum or Plasma | 0.733 | 1562 |  5 |     4,407 |
| 3027056 | Estriol (E3) [Mass/volume] in Amniotic fluid | 0.731 |  |  0 |         0 |
| 3023986 | Choriomammotropin [Mass/volume] in Amniotic fluid | 0.728 |  |  0 |         0 |
| 40758900 | Erythrocytes [#/volume] in Amniotic fluid | 0.719 |  |  0 |         0 |
| 3002776 | Chymotrypsin [Mass/volume] in Serum or Plasma | 0.718 |  |  0 |         0 |
| 3044397 | Alpha-1-Fetoprotein [Presence] in Amniotic fluid | 0.716 |  |  0 |         0 |
| 3030860 | Tumor necrosis factor.alpha [Moles/volume] in Serum or Plasma | 0.712 |  |  0 |         0 |
| 3014625 | Acetylcholinesterase [Presence] in Amniotic fluid | 0.711 |  |  0 |         0 |
| 1002333 | Tauroursodeoxycholate [Moles/volume] in Serum or Plasma | 0.706 |  |  0 |         0 |
| 3027923 | C peptide [Moles/volume] in Serum or Plasma | 0.706 | 701 |  8 |     4,100 |
| 3964936 | Triamcinolone [Moles/volume] in Serum or Plasma | 0.705 |  |  0 |         0 |
| 3029400 | C peptide [Moles/volume] in Serum or Plasma --4th specimen | 0.704 |  |  0 |         0 |
| 3007675 | Apolipoprotein E [Mass/volume] in Serum or Plasma | 0.702 |  |  0 |         0 |
| 40758355 | Pancreatic polypeptide [Moles/volume] in Serum or Plasma | 0.702 |  |  4 |     1,603 |
| 3004390 | Estrogen receptor [Interpretation] in Tissue | 0.700 |  |  0 |         0 |
| 3020806 | Estrogen binding protein [Mass/volume] in Serum or Plasma | 0.695 |  |  0 |         0 |
| 40758664 | ePHEDrine [Moles/volume] in Serum or Plasma | 0.693 |  |  0 |         0 |
| 43055059 | 4-Hydroxyphenylpyruvate [Moles/volume] in Serum or Plasma | 0.691 |  |  0 |         0 |
| 3032660 | Eicosapentaenoate (C20:5w3) [Moles/volume] in Serum or Plasma | 0.690 |  |  0 |         0 |
| 3003289 | Progesterone receptor [Interpretation] in Tissue | 0.689 |  |  0 |         0 |
| 3032603 | Hemoglobin S [Presence] in Amniotic fluid | 0.687 |  |  0 |         0 |
| 3041343 | Estrogen receptor Ag [Presence] in Tissue by Immune stain | 0.668 |  |  0 |         0 |
| 3966100 | ESR1 gene mutation panel - Tissue by Molecular genetics method | 0.660 |  |  0 |         0 |
| 43055014 | HER2 Ag [Presence] in Tissue by Immunoassay | 0.655 |  |  0 |         0 |
| 3000481 | Estrogen+Progesterone receptor Ag [Presence] in Tissue by Immune stain | 0.645 |  |  0 |         0 |
| 3016794 | Cells.estrogen receptor/cells in Tissue by Immune stain | 0.640 |  |  0 |         0 |
| 3965229 | Thyroglobulin and Thyroglobulin Ab panel - Tissue fine needle aspirate | 0.638 |  |  0 |         0 |
| 3039417 | Platelet distribution width [Ratio] in Blood | 0.635 |  |  0 |         0 |
| 3032783 | Androgen receptor Ag [Presence] in Tissue by Immune stain | 0.634 |  |  0 |         0 |
| 3031298 | 2-Hydroxyestrone and 16-Alpha hydroxyestrone panel - Serum or Plasma | 0.633 |  |  0 |         0 |
| 3030369 | Platelet associated IgG Ab/IgM Ab [Ratio] in Blood | 0.631 |  |  0 |         0 |
| 3009713 | Pulmonary vascular Resistance index | 0.629 |  |  0 |         0 |
| 21493869 | von Willebrand factor (vWf) ristocetin cofactor/von Willebrand factor (vWf) Ag [Ratio] in Platelet poor plasma | 0.629 |  |  0 |         0 |
| 21491244 | Platelet aggregation [Units/volume] in Blood by adenosine diphosphate+prostaglandin E1 induced | 0.620 |  |  0 |         0 |
| 646418 | von Willebrand factor activity.GPIbM/von Willebrand factor (vWf) Ag [Ratio] in Platelet poor plasma by Turbidimetry | 0.619 |  |  0 |         0 |
| 21491243 | Platelet aggregation [Units/volume] in Blood by thrombin receptor activating peptide-6 induced | 0.619 |  |  0 |         0 |
| 36204154 | AST to platelet ratio index in Serum and Blood by calculation | 0.614 |  |  0 |         0 |
| 3036475 | Plasminogen activator inhibitor 1 Ag [Mass/volume] in Platelet poor plasma by Immunoassay | 0.609 |  |  0 |         0 |
| 3013833 | Plasminogen activator inhibitor 2 Ag [Mass/volume] in Platelet poor plasma by Immunoassay | 0.607 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 482 | -ana | titre | 21 | 14.29 |  | -Tuma, vasta-aineet |  |  | Nuclear Ab [Titer] in Serum | FALSE |
| 483 | -ana |  | 169 | 100 |  | -Tuma, vasta-aineet |  |  | Nuclear Ab [Presence] in Serum | FALSE |
| 484 | am-epo | iu/l | 76 | 0 |  | Am-Erytropoietiini | Amniotic fluid |  | Erythropoietin [Units/volume] in Amniotic fluid | FALSE |
| 485 | am-epo | u/l | 267 | 0.75 | [2.67, 3.48, 4.24, 4.97, 5.92, 7.13, 8.38, 10.84, 21.7] | Am-Erytropoietiini | Amniotic fluid |  | Erythropoietin [Units/volume] in Amniotic fluid | FALSE |
| 486 | am-epo |  | 31 | 45.16 |  | Am-Erytropoietiini | Amniotic fluid |  | Erythropoietin [Presence] in Amniotic fluid | FALSE |
| 487 | b-adp | auc | 28 | 0 |  |  | Blood |  |  | FALSE |
| 488 | b-adp |  | 340 | 100 |  |  | Blood |  |  | FALSE |
| 489 | b-aspi | auc | 28 | 0 |  |  | Blood |  |  | FALSE |
| 490 | b-aspi |  | 340 | 100 |  |  | Blood |  |  | FALSE |
| 491 | b-vasp | % | 165 | 0 | [15.56, 23.85, 29.41, 35.04, 41.24, 50.14, 56.77, 61.91, 75.84] |  | Blood |  | Vasodilator-stimulated phosphoprotein phosphorylation platelet reactivity index [Ratio] in Blood | FALSE |
| 492 | b-vasp |  | 67 | 61.19 |  |  | Blood |  |  | FALSE |
| 493 | du-5hiaa | umol | 332 | 1.51 | [14.87, 17.89, 19.97, 21.96, 24, 26.85, 29.92, 35.9, 54.08] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid [Moles/time] in 24 hour Urine | FALSE |
| 494 | du-5hiaa | umol/24h | 175 | 0 | [13.31, 17.22, 20.27, 23.53, 25.81, 31.1, 37.11, 45.94, 66.13] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid [Moles/time] in 24 hour Urine | FALSE |
| 495 | du-5hiaa | umol/l | 25 | 0 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid [Moles/volume] in Urine | FALSE |
| 496 | du-5hiaa |  | 147 | 66.67 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | 5-Hydroxyindoleacetic acid [Moles/time] in 24 hour Urine | FALSE |
| 497 | fs-ace | u/l | 33401 | 0.05 | [20.1, 26.68, 31.86, 36.8, 41.71, 47.15, 53.87, 62.77, 76.91] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 498 | fs-ace |  | 3291 | 89.58 | [11.62, 22.24, 28.9, 33.73, 39.48, 44.52, 50.34, 61.92, 75.37] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 499 | fs-apot |  | 258 | 100 |  |  | Fasting serum |  |  | FALSE |
| 500 | fs-ffa | mmol/l | 170 | 0.59 | [0.17, 0.25, 0.3, 0.38, 0.42, 0.5, 0.56, 0.69, 0.91] | fS-Rasvahapot, vapaat | Fasting serum |  | Fatty acids.free [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 501 | fs-ffa |  | 19 | 36.84 |  | fS-Rasvahapot, vapaat | Fasting serum |  | Fatty acids.free [Moles/volume] in Serum or Plasma --fasting | FALSE |
| 502 | fs-tp-1 |  | 1698 | 100 |  |  | Fasting serum |  |  | FALSE |
| 503 | fs-tp-3 |  | 867 | 100 |  |  | Fasting serum |  |  | FALSE |
| 504 | fs-tp-4 |  | 926 | 100 |  |  | Fasting serum |  |  | FALSE |
| 505 | fs-tp-7 |  | 400 | 100 |  |  | Fasting serum |  |  | FALSE |
| 506 | li-tpha | titre | 12 | 0 |  | Li-Treponema pallidum, hemagglutinaatio | Cerebrospinal fluid |  | Treponema pallidum Ab [Titer] in Cerebral spinal fluid by Agglutination | FALSE |
| 507 | li-tpha |  | 526 | 100 |  | Li-Treponema pallidum, hemagglutinaatio | Cerebrospinal fluid |  | Treponema pallidum Ab [Presence] in Cerebral spinal fluid | FALSE |
| 508 | p-hae |  | 461 | 100 |  |  | Plasma |  |  | FALSE |
| 509 | p-hcg | iu/l | 858 | 0 | [3.54, 10.48, 27.87, 72.06, 203.74, 526.1, 1525.11, 5507.31, 17831.23] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin [Units/volume] in Serum or Plasma | FALSE |
| 510 | p-hcg | u/l | 13156 | 11.71 | [0, 1.5, 5.06, 22.75, 97.57, 335.38, 1102.09, 3696.05, 18876.19] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin [Units/volume] in Serum or Plasma | FALSE |
| 511 | p-hcg |  | 15471 | 94.78 | [2.42, 12.44, 35.69, 103.11, 288.41, 866.82, 2866.35, 7636.68, 32545.17] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin [Presence] in Serum or Plasma | FALSE |
| 512 | p-he4 | pmol/l | 2505 | 0.12 | [38.55, 42.76, 46.82, 51.17, 55.95, 62.75, 72.7, 92.45, 146.15] | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  | Human epididymis protein 4 [Moles/volume] in Serum or Plasma | FALSE |
| 513 | p-he4 |  | 6 | 100 |  | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  | Human epididymis protein 4 [Moles/volume] in Serum or Plasma | FALSE |
| 514 | p-hepg |  | 107 | 100 |  |  | Plasma |  |  | FALSE |
| 515 | p-hok |  | 397 | 100 |  |  | Plasma |  |  | FALSE |
| 516 | p-shbg | nmol/l | 791 | 0 | [18.37, 23.23, 26.61, 30.13, 34.18, 38.05, 43.25, 50.43, 63.9] |  | Plasma |  | Sex hormone binding globulin [Moles/volume] in Serum or Plasma | FALSE |
| 517 | p-shbg |  | 758 | 4.09 | [17.37, 21.68, 26.35, 30.87, 35.48, 41.39, 46.88, 56, 72.07] |  | Plasma |  | Sex hormone binding globulin [Moles/volume] in Serum or Plasma | FALSE |
| 518 | s-5hiaa | nmol/l | 10313 | 0.07 | [44.23, 52.73, 60.93, 69.76, 80.1, 94.8, 122.35, 200.37, 540.74] | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  | 5-Hydroxyindoleacetic acid [Moles/volume] in Serum or Plasma | FALSE |
| 519 | s-5hiaa |  | 153 | 79.74 |  | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  | 5-Hydroxyindoleacetic acid [Moles/volume] in Serum or Plasma | FALSE |
| 520 | s-ace | u/l | 2203 | 0.18 | [19.48, 28.37, 33.74, 38.42, 43.02, 48.21, 54.09, 61.63, 75.23] |  | Serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 521 | s-ace |  | 769 | 20.68 | [21.02, 30.36, 34.97, 38.52, 42.83, 46.55, 51.62, 57.68, 65.53] |  | Serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 522 | s-ada | u/l | 4147 | 1.33 | [7, 8.05, 9.23, 10.37, 11.69, 12.94, 14.77, 17.12, 21.32] | S -Adenosiinideaminaasi | Serum |  | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 523 | s-ada |  | 259 | 84.56 |  | S -Adenosiinideaminaasi | Serum |  | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma | FALSE |
| 524 | s-afp | u/ml | 18186 | 1.26 | [1.8, 2.08, 2.61, 3.01, 3.6, 4.33, 5.57, 7.77, 24.79] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-fetoprotein [Units/volume] in Serum or Plasma | FALSE |
| 525 | s-afp | ug/l | 2515 | 0 | [2, 2.23, 3, 3.96, 4.22, 5.38, 6.93, 9.7, 20.37] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-fetoprotein [Mass/volume] in Serum or Plasma | FALSE |
| 526 | s-afp |  | 4026 | 80.55 | [2, 2.01, 3, 3, 3.99, 4, 5, 6.41, 9.69] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-fetoprotein [Mass/volume] in Serum or Plasma | FALSE |
| 527 | s-afp/d | u/ml | 234 | 0 | [15.11, 17.44, 19.7, 22.07, 23.9, 26.33, 29.33, 33.17, 39.24] |  | Serum |  | Alpha-fetoprotein [Units/volume] in Serum or Plasma | FALSE |
| 528 | s-afp/d |  | 49 | 12.24 |  |  | Serum |  | Alpha-fetoprotein [Units/volume] in Serum or Plasma | FALSE |
| 529 | s-amh | ug/l | 9545 | 0.43 | [0.42, 0.85, 1.31, 1.75, 2.24, 2.87, 3.63, 4.76, 7.13] | S -Anti-Muller hormoni | Serum |  | Anti-Mullerian hormone [Mass/volume] in Serum or Plasma | FALSE |
| 530 | s-amh |  | 1328 | 93.45 | [0.62, 1.11, 1.66, 2.28, 2.8, 3.57, 4.21, 5.32, 7.88] | S -Anti-Muller hormoni | Serum |  | Anti-Mullerian hormone [Mass/volume] in Serum or Plasma | FALSE |
| 531 | s-ami | mg/l | 294 | 0 | [1.3, 1.49, 1.7, 2.28, 2.76, 3.41, 4.52, 6.36, 11.32] | S -Amikasiini | Serum |  | Amikacin [Mass/volume] in Serum or Plasma | FALSE |
| 532 | s-ami |  | 308 | 95.13 |  | S -Amikasiini | Serum |  | Amikacin [Mass/volume] in Serum or Plasma | FALSE |
| 533 | s-ana | titre | 21493 | 1.69 | [80, 121.94, 160, 299.08, 320, 320, 399.84, 831.19, 1349.55] | S -Tuma, vasta-aineet | Serum |  | Nuclear Ab [Titer] in Serum | FALSE |
| 534 | s-ana |  | 62781 | 100 | [80, 160, 320, 320, 320, 320, 640, 762.94, 1891.15] | S -Tuma, vasta-aineet | Serum |  | Nuclear Ab [Titer] in Serum | FALSE |
| 535 | s-apot |  | 754 | 100 |  |  | Serum |  |  | FALSE |
| 536 | s-asca | u/ml | 89 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  | Saccharomyces cerevisiae Ab [Presence] in Serum | FALSE |
| 537 | s-asca |  | 316 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  | Saccharomyces cerevisiae Ab [Presence] in Serum | FALSE |
| 538 | s-ast | iu/ml | 2404 | 0 | [49.92, 65.92, 77.55, 92.42, 111.12, 137.94, 173.28, 237.31, 396.71] | S -Antistreptolysiini | Serum |  | Streptolysin O Ab [Units/volume] in Serum or Plasma | FALSE |
| 539 | s-ast | titre | 7 | 0 |  | S -Antistreptolysiini | Serum |  | Streptolysin O Ab [Titer] in Serum or Plasma | FALSE |
| 540 | s-ast | u/ml | 408 | 4.17 | [30.71, 40.63, 53.38, 70.53, 94.49, 133.41, 202.61, 384.67, 783.66] | S -Antistreptolysiini | Serum |  | Streptolysin O Ab [Units/volume] in Serum or Plasma | FALSE |
| 541 | s-ast |  | 2603 | 94.05 | [60.92, 74.22, 90.53, 107.5, 145.19, 198.62, 261.7, 407.28, 740.72] | S -Antistreptolysiini | Serum |  | Streptolysin O Ab [Units/volume] in Serum or Plasma | FALSE |
| 542 | s-asta | iu/ml | 256 | 16.41 | [2, 2, 2, 2, 3.02, 4, 4.64, 6, 8] | S -Antistafylolysiini | Serum |  | Staphylolysin Ab [Units/volume] in Serum or Plasma | FALSE |
| 543 | s-asta | u/ml | 10 | 0 |  | S -Antistafylolysiini | Serum |  | Staphylolysin Ab [Units/volume] in Serum or Plasma | FALSE |
| 544 | s-asta |  | 2266 | 99.29 |  | S -Antistafylolysiini | Serum |  | Staphylolysin Ab [Presence] in Serum or Plasma | FALSE |
| 545 | s-br | mmol/l | 130 | 0 |  | S -Bromidi | Serum |  | Bromide [Moles/volume] in Serum or Plasma | FALSE |
| 546 | s-dhea | nmol/l | 398 | 0 | [2.68, 4.23, 5.8, 8.33, 11.06, 14.2, 18.42, 22.5, 33.54] | S -Dehydroepiandrosteroni | Serum |  | Dehydroepiandrosterone [Moles/volume] in Serum or Plasma | FALSE |
| 547 | s-dhea |  | 74 | 68.92 |  | S -Dehydroepiandrosteroni | Serum |  | Dehydroepiandrosterone [Moles/volume] in Serum or Plasma | FALSE |
| 548 | s-dheas | umol/l | 3797 | 0.03 | [1.05, 1.87, 2.83, 3.75, 4.58, 5.54, 6.67, 8.05, 10.29] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  | Dehydroepiandrosterone sulfate [Moles/volume] in Serum or Plasma | FALSE |
| 549 | s-dheas |  | 331 | 53.47 | [1.45, 2.24, 2.88, 3.59, 4.26, 5.13, 5.94, 7.34, 8.82] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  | Dehydroepiandrosterone sulfate [Moles/volume] in Serum or Plasma | FALSE |
| 550 | s-e1 | pmol/l | 123 | 0 | [70, 112.9, 136.88, 181.46, 224.33, 282.87, 347.03, 435.1, 621.18] | S -Estroni | Serum |  | Estrone [Moles/volume] in Serum or Plasma | FALSE |
| 551 | s-e1 |  | 30 | 76.67 |  | S -Estroni | Serum |  | Estrone [Moles/volume] in Serum or Plasma | FALSE |
| 552 | s-e2 | nmol/l | 10351 | 2.69 | [0.07, 0.1, 0.13, 0.16, 0.2, 0.27, 0.38, 0.55, 0.99] | S -Estradioli | Serum |  | Estradiol [Moles/volume] in Serum or Plasma | FALSE |
| 553 | s-e2 |  | 2381 | 83.75 | [0.06, 0.08, 0.1, 0.12, 0.15, 0.19, 0.25, 0.35, 0.58] | S -Estradioli | Serum |  | Estradiol [Moles/volume] in Serum or Plasma | FALSE |
| 554 | s-ema |  | 2245 | 99.96 |  | S -Endomysium, vasta-aineet | Serum |  | Endomysial Ab [Presence] in Serum | FALSE |
| 555 | s-ena |  | 1469 | 62.22 | [0.1, 0.1, 0.1, 0.19, 0.2, 0.22, 0.3, 0.47, 1.12] |  | Serum |  | Extractable nuclear Ab [Units/volume] in Serum | FALSE |
| 556 | s-enal |  | 832 | 100 |  |  | Serum |  | Extractable nuclear Ab panel - Serum | TRUE |
| 557 | s-epo | iu/l | 2353 | 0.38 | [4.95, 7.08, 8.93, 10.78, 12.99, 15.54, 19.77, 28.75, 48.4] | S -Erytropoietiini | Serum |  | Erythropoietin [Units/volume] in Serum or Plasma | FALSE |
| 558 | s-epo | pmol/l | 44 | 0 |  | S -Erytropoietiini | Serum |  | Erythropoietin [Moles/volume] in Serum or Plasma | FALSE |
| 559 | s-epo | u/l | 5380 | 0 | [4.44, 6.44, 8.09, 9.88, 11.93, 14.55, 19.01, 29.55, 62.33] | S -Erytropoietiini | Serum |  | Erythropoietin [Units/volume] in Serum or Plasma | FALSE |
| 560 | s-epo |  | 1209 | 20.35 | [4.6, 6.64, 8.47, 10.2, 11.81, 13.76, 17.07, 22.59, 40.53] | S -Erytropoietiini | Serum |  | Erythropoietin [Units/volume] in Serum or Plasma | FALSE |
| 561 | s-ffa | mmol/l | 518 | 0 | [0.03, 0.04, 0.07, 0.13, 0.19, 0.28, 0.44, 0.57, 0.75] |  | Serum |  | Fatty acids.free [Moles/volume] in Serum or Plasma | FALSE |
| 562 | s-gen | mg/l | 373 | 0.54 | [0.5, 0.65, 0.75, 0.89, 0.99, 1.17, 1.48, 2.04, 3.94] | S -Gentamysiini | Serum |  | Gentamicin [Mass/volume] in Serum or Plasma | FALSE |
| 563 | s-gen |  | 339 | 85.55 |  | S -Gentamysiini | Serum |  | Gentamicin [Mass/volume] in Serum or Plasma | FALSE |
| 564 | s-hae |  | 751 | 100 |  |  | Serum |  |  | FALSE |
| 565 | s-hbe |  | 347 | 100 |  |  | Serum |  |  | FALSE |
| 566 | s-hcg | iu/l | 2181 | 0 | [2.11, 4.62, 15.8, 53.63, 166.71, 442, 1018.25, 2912.42, 12003.73] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin [Units/volume] in Serum or Plasma | FALSE |
| 567 | s-hcg | u/l | 5914 | 0 | [5.67, 20.66, 67.43, 172.44, 366.74, 677.25, 1513.49, 4378.78, 17452.46] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin [Units/volume] in Serum or Plasma | FALSE |
| 568 | s-hcg |  | 16592 | 96.23 | [8.29, 17.67, 40.08, 108.43, 306.84, 912.85, 3181.52, 10206.39, 38671.9] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin [Presence] in Serum or Plasma | FALSE |
| 569 | s-he4 | pmol/l | 11193 | 0 | [31.87, 37.18, 41.94, 46.96, 53.02, 60.99, 73.42, 98.24, 181.66] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  | Human epididymis protein 4 [Moles/volume] in Serum or Plasma | FALSE |
| 570 | s-he4 |  | 420 | 43.57 | [28.77, 32.37, 35.15, 39.84, 42.92, 45.83, 51.37, 61.13, 81.8] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  | Human epididymis protein 4 [Moles/volume] in Serum or Plasma | FALSE |
| 571 | s-kem |  | 1473 | 100 |  |  | Serum |  |  | FALSE |
| 572 | s-kyhemag | titre | 180 | 1.67 | [8, 11.41, 16, 18.4, 42.5, 146.59, 256, 870.4, 2048] | S -Kylmähemagglutiniinit | Serum |  | Cold agglutinin [Titer] in Serum | FALSE |
| 573 | s-kyhemag |  | 826 | 99.39 |  | S -Kylmähemagglutiniinit | Serum |  | Cold agglutinin [Presence] in Serum | FALSE |
| 574 | s-shbg | nmol/l | 29338 | 0 | [16.96, 21.37, 25.29, 29.19, 33.26, 37.98, 43.62, 51.6, 65.13] | S -Sukupuolihormoneja sitova globuliini | Serum |  | Sex hormone binding globulin [Moles/volume] in Serum or Plasma | FALSE |
| 575 | s-shbg |  | 614 | 100 | [15.22, 19.74, 24.23, 28.3, 32.4, 37.12, 43.41, 51.5, 64.44] | S -Sukupuolihormoneja sitova globuliini | Serum |  | Sex hormone binding globulin [Moles/volume] in Serum or Plasma | FALSE |
| 576 | s-tati | nmol/l | 551 | 0 | [1.3, 1.49, 1.61, 1.81, 2.08, 2.38, 2.74, 3.44, 6.09] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor-associated trypsin inhibitor [Moles/volume] in Serum or Plasma | FALSE |
| 577 | s-tati | ug/l | 446 | 0 | [6.71, 8.1, 9.03, 9.98, 11, 12.24, 13.98, 16.99, 30.9] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor-associated trypsin inhibitor [Mass/volume] in Serum or Plasma | FALSE |
| 578 | s-tati |  | 86 | 24.42 |  | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor-associated trypsin inhibitor [Mass/volume] in Serum or Plasma | FALSE |
| 579 | s-tpha | titre | 1665 | 0 | [158.37, 304.61, 391.53, 640, 1034.44, 1338.85, 3168.84, 4985.37, 6432.72] | S -Treponema pallidum, hemagglutinaatio | Serum |  | Treponema pallidum Ab [Titer] in Serum by Agglutination | FALSE |
| 580 | s-tpha |  | 9799 | 99.67 |  | S -Treponema pallidum, hemagglutinaatio | Serum |  | Treponema pallidum Ab [Presence] in Serum | FALSE |
| 581 | s-van | mg/l | 36935 | 0.09 | [6.84, 8.59, 9.97, 11.16, 12.39, 13.69, 15.03, 16.85, 19.72] | S -Vankomysiini | Serum |  | Vancomycin [Mass/volume] in Serum or Plasma | FALSE |
| 582 | s-van |  | 1695 | 100 | [7.35, 9.11, 10.49, 11.71, 12.89, 14.15, 15.61, 17.74, 21.29] | S -Vankomysiini | Serum |  | Vancomycin [Mass/volume] in Serum or Plasma | FALSE |
| 583 | ts-res |  | 1353 | 100 |  | Ts-Reseptoritutkimus | Tissue |  | Hormone receptor panel - Tissue | TRUE |
| 584 | u-hcg | iu/l | 93 | 0 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin [Units/volume] in Urine | FALSE |
| 585 | u-hcg | u/l | 15 | 0 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin [Units/volume] in Urine | FALSE |
| 586 | u-hcg |  | 227 | 97.8 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin [Presence] in Urine | FALSE |

