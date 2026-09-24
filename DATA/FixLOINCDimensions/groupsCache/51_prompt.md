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
Here is group 51.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1259853 | Infliximab and Infliximab Ab Panel - Serum or Plasma | 1.000 |  | 0 |       0 |
| 3002823 | Mycoplasma pneumoniae IgG Ab [Units/volume] in Cerebral spinal fluid | 1.000 |  | 1 |   1,286 |
| 3004762 | Giardia lamblia Ag [Presence] in Stool | 1.000 |  | 0 |       0 |
| 3005411 | Squamous cell carcinoma Ag [Mass/volume] in Serum or Plasma | 1.000 |  | 3 |   1,450 |
| 3011363 | Streptococcus pneumoniae Ag [Presence] in Urine | 1.000 |  | 1 |   4,092 |
| 3020393 | Adenovirus Ag [Presence] in Stool | 1.000 |  | 1 |     863 |
| 3042299 | inFLIXimab [Mass/volume] in Serum or Plasma | 1.000 |  | 7 |   7,102 |
| 3052347 | Giardia lamblia+Cryptosporidium sp Ag [Presence] in Stool | 1.000 |  | 0 |       0 |
| 3052592 | Norovirus Ag [Presence] in Stool | 1.000 |  | 1 |   1,048 |
| 3965803 | Influenza virus A+B RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |       0 |
| 3010959 | Adenovirus IgG Ab [Units/volume] in Serum | 0.983 |  | 0 |       0 |
| 3035523 | Parainfluenza virus 1 IgG Ab [Units/volume] in Serum | 0.981 |  | 0 |       0 |
| 3018387 | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum | 0.981 |  | 3 |   9,534 |
| 3034468 | Parainfluenza virus 1 IgG Ab [Presence] in Serum | 0.981 |  | 0 |       0 |
| 3015147 | Influenza virus A IgG Ab [Units/volume] in Serum | 0.979 |  | 3 |      85 |
| 3018940 | Influenza virus B Ab [Units/volume] in Serum | 0.979 |  | 0 |       0 |
| 3016955 | Mycoplasma pneumoniae IgM Ab [Units/volume] in Cerebral spinal fluid | 0.979 |  | 0 |       0 |
| 3042885 | Influenza virus A IgG Ab [Presence] in Serum | 0.978 |  | 0 |       0 |
| 43055457 | inFLIXimab Ab [Mass/volume] in Serum or Plasma | 0.978 |  | 0 |       0 |
| 37020635 | Influenza virus A RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.977 |  | 0 |       0 |
| 3045344 | Influenza virus B IgG Ab [Presence] in Serum | 0.977 |  | 0 |       0 |
| 3040947 | Adenovirus IgG Ab [Presence] in Serum | 0.977 |  | 0 |       0 |
| 3016413 | Influenza virus B IgG Ab [Units/volume] in Serum | 0.977 |  | 0 |       0 |
| 3042988 | Influenza virus B Ab [Presence] in Serum | 0.976 |  | 0 |       0 |
| 3021082 | Mycoplasma pneumoniae IgM Ab [Presence] in Serum | 0.975 |  | 0 |       0 |
| 3046684 | Mycoplasma pneumoniae IgG Ab [Presence] in Serum | 0.975 |  | 0 |       0 |
| 3051042 | Giardia lamblia+Cryptosporidium parvum Ag [Presence] in Stool | 0.973 |  | 0 |       0 |
| 3035420 | Mycoplasma pneumoniae Ab [Presence] in Serum | 0.973 |  | 0 |       0 |
| 3015828 | Influenza virus B Ab [Units/volume] in Cerebral spinal fluid | 0.971 |  | 0 |       0 |
| 3008284 | Rotavirus Ag [Presence] in Stool | 0.970 |  | 0 |       0 |
| 3048901 | Influenza virus B IgG Ab [Mass/volume] in Cerebral spinal fluid | 0.965 |  | 0 |       0 |
| 3035929 | Mycoplasma pneumoniae Ab [Units/volume] in Cerebral spinal fluid | 0.964 |  | 1 |     612 |
| 3035162 | Adenovirus Ag [Presence] in Nasopharynx | 0.963 |  | 0 |       0 |
| 3036072 | Legionella pneumophila 1 Ag [Presence] in Urine | 0.962 |  | 0 |       0 |
| 3044141 | Influenza virus A Ag [Presence] in Nasopharynx | 0.962 |  | 0 |       0 |
| 3029458 | Influenza virus A+B Ag [Presence] in Nasopharynx | 0.960 |  | 0 |       0 |
| 3035919 | Mycoplasma pneumoniae IgG+IgM Ab [Units/volume] in Serum | 0.958 |  | 0 |       0 |
| 3003551 | Influenza virus A Ag [Presence] in Throat | 0.958 |  | 0 |       0 |
| 3022193 | Influenza virus A+B Ag [Presence] in Throat | 0.957 |  | 0 |       0 |
| 3038516 | Parainfluenza virus 1 IgG Ab [Presence] in Serum by Immunoassay | 0.956 |  | 0 |       0 |
| 36305253 | inFLIXimab [Mass/volume] in Serum or Plasma by Immunoassay | 0.956 |  | 0 |       0 |
| 3052509 | Influenza virus A IgG Ab [Units/volume] in Serum by Immunoassay | 0.956 |  | 0 |       0 |
| 3000836 | Parainfluenza virus 1 IgM Ab [Presence] in Serum | 0.954 |  | 0 |       0 |
| 3048553 | Influenza virus A IgG Ab [Mass/volume] in Cerebral spinal fluid | 0.954 |  | 0 |       0 |
| 3041248 | Adenovirus IgG Ab [Units/volume] in Serum by Immunoassay | 0.954 |  | 0 |       0 |
| 3008417 | Mycoplasma pneumoniae IgM Ab [Units/volume] in Serum | 0.954 |  | 0 |       0 |
| 36304214 | Influenza virus B IgG Ab [Presence] in Serum by Immunoassay | 0.953 |  | 0 |       0 |
| 40765199 | Influenza virus A+B RNA [Presence] in Specimen by NAA with probe detection | 0.953 |  | 0 |       0 |
| 3003479 | Legionella pneumophila Ag [Presence] in Urine | 0.953 |  | 0 |       0 |
| 3051600 | Influenza virus B IgG Ab [Units/volume] in Serum by Immunoassay | 0.953 |  | 0 |       0 |
| 3005534 | Adenovirus Ag [Presence] in Throat | 0.952 |  | 0 |       0 |
| 3005293 | Parainfluenza virus 1 IgM Ab [Units/volume] in Serum | 0.951 |  | 0 |       0 |
| 36204256 | Influenza virus A IgG Ab [Presence] in Serum by Immunoassay | 0.949 |  | 0 |       0 |
| 3014742 | Influenza virus A Ab [Units/volume] in Cerebral spinal fluid | 0.948 |  | 0 |       0 |
| 40763480 | Human metapneumovirus Ag [Presence] in Specimen | 0.948 |  | 1 |     301 |
| 3010464 | Parainfluenza virus 1 Ag [Presence] in Specimen | 0.948 |  | 1 |   1,146 |
| 3024072 | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum by Immunoassay | 0.947 | 1563 | 0 |       0 |
| 3966116 | Influenza virus A H1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.947 |  | 0 |       0 |
| 3031286 | Influenza virus B Ab [Presence] in Serum by Immunoassay | 0.947 |  | 0 |       0 |
| 3014008 | Giardia sp Ag [Presence] in Stool | 0.947 |  | 0 |       0 |
| 3016636 | Influenza virus B IgM Ab [Units/volume] in Serum | 0.946 |  | 0 |       0 |
| 3040912 | Adenovirus IgG Ab [Presence] in Serum by Immunoassay | 0.946 |  | 0 |       0 |
| 3005880 | Parainfluenza virus 3 Ag [Presence] in Specimen | 0.946 |  | 1 |   1,147 |
| 3021578 | Parainfluenza virus 2 Ag [Presence] in Specimen | 0.946 |  | 1 |   1,147 |
| 37021252 | Influenza virus B RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.946 |  | 0 |       0 |
| 3003221 | Pneumocystis jirovecii Ag [Presence] in Specimen | 0.945 |  | 0 |       0 |
| 3051730 | Giardia lamblia+Cryptosporidium sp Ag [Presence] in Stool by Immunoassay | 0.945 |  | 0 |       0 |
| 3021514 | Adenovirus Ag [Presence] in Stool by Immunoassay | 0.944 |  | 0 |       0 |
| 3010672 | Adenovirus IgM Ab [Units/volume] in Serum | 0.944 |  | 0 |       0 |
| 3006264 | Giardia lamblia Ag [Presence] in Specimen | 0.943 |  | 0 |       0 |
| 3003306 | Rotavirus Ag [Presence] in Stool by Agglutination | 0.943 |  | 0 |       0 |
| 3053332 | Influenza virus B IgA Ab [Mass/volume] in Cerebral spinal fluid | 0.942 |  | 0 |       0 |
| 1091605 | Influenza virus A+B RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.942 |  | 0 |       0 |
| 3046180 | Influenza virus B IgA Ab [Presence] in Serum | 0.941 |  | 0 |       0 |
| 3014762 | Squamous cell carcinoma Ag [Moles/volume] in Serum or Plasma | 0.941 |  | 0 |       0 |
| 3047318 | Adenovirus Ab [Presence] in Cerebral spinal fluid | 0.941 |  | 0 |       0 |
| 3007625 | Streptococcus pneumoniae Ag [Presence] in Specimen | 0.941 |  | 1 |     244 |
| 3053225 | Giardia lamblia+Cryptosporidium sp Ag [Presence] in Stool by Immunofluorescence | 0.940 |  | 0 |       0 |
| 3036242 | Adenovirus IgM Ab [Presence] in Serum | 0.940 |  | 0 |       0 |
| 3045494 | Influenza virus B Ab [Units/volume] in Specimen | 0.940 |  | 0 |       0 |
| 3013870 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma | 0.939 |  | 0 |       0 |
| 40761876 | Mycoplasma pneumoniae IgM Ab [Units/volume] in Cerebral spinal fluid by Immunoassay | 0.939 |  | 0 |       0 |
| 3042770 | Influenza virus B IgM Ab [Presence] in Serum | 0.938 |  | 0 |       0 |
| 3045068 | Mycoplasma pneumoniae IgG Ab [Presence] in Serum by Immunoassay | 0.938 |  | 0 |       0 |
| 3009488 | Squamous cell carcinoma Ag [Units/volume] in Serum or Plasma | 0.938 |  | 0 |       0 |
| 3010521 | Mycoplasma pneumoniae IgM Ab [Presence] in Serum by Immunoassay | 0.938 |  | 2 |  14,920 |
| 3042911 | Influenza virus A Ab [Presence] in Cerebral spinal fluid | 0.937 |  | 0 |       0 |
| 40758297 | Mycoplasma sp Ab [Presence] in Cerebral spinal fluid | 0.937 |  | 0 |       0 |
| 723477 | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.936 |  | 0 |       0 |
| 3049879 | Influenza virus B IgM Ab [Mass/volume] in Cerebral spinal fluid | 0.935 |  | 0 |       0 |
| 3003330 | Adenovirus Ag [Presence] in Specimen | 0.935 |  | 0 |       0 |
| 3007936 | Chlamydophila pneumoniae IgG Ab [Units/volume] in Cerebral spinal fluid | 0.935 |  | 0 |       0 |
| 3964727 | Influenza virus A H3 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.935 |  | 0 |       0 |
| 3003740 | Influenza virus B Ag [Presence] in Specimen | 0.934 |  | 1 |  10,720 |
| 3028849 | Mycoplasma pneumoniae Ab [Titer] in Cerebral spinal fluid | 0.934 |  | 0 |       0 |
| 3008907 | Influenza virus A IgM Ab [Units/volume] in Serum | 0.933 |  | 0 |       0 |
| 3024891 | Influenza virus A+B Ag [Presence] in Specimen | 0.933 | 1991 | 1 |  15,096 |
| 3012107 | Adenovirus Ag [Presence] in Stool by Immunofluorescence | 0.933 |  | 0 |       0 |
| 3033391 | Mycoplasma pneumoniae IgG Ab [Titer] in Cerebral spinal fluid | 0.933 |  | 0 |       0 |
| 3002523 | Influenza virus A Ag [Presence] in Specimen | 0.933 |  | 1 |  10,727 |
| 3014352 | Rotavirus Ag [Presence] in Stool by Immunoassay | 0.932 | 1185 | 0 |       0 |
| 3037677 | Mycoplasma pneumoniae IgM Ab [Titer] in Cerebral spinal fluid | 0.932 |  | 1 |   1,311 |
| 3008140 | Giardia lamblia Ag [Presence] in Stool by Immunoassay | 0.932 | 819 | 0 |       0 |
| 649481 | Mycoplasma pneumoniae IgM Ab [Measurement] in Cerebral spinal fluid | 0.932 |  | 0 |       0 |
| 3043038 | Influenza virus B Ag [Presence] in Bronchial specimen | 0.931 |  | 0 |       0 |
| 3007522 | Mycoplasma pneumoniae Ab [Units/volume] in Serum | 0.931 |  | 0 |       0 |
| 36203321 | Influenza virus A RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.931 |  | 0 |       0 |
| 42529122 | Norovirus Ag [Presence] in Stool by Rapid immunoassay | 0.931 |  | 0 |       0 |
| 36304486 | inFLIXimab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.931 |  | 0 |       0 |
| 21491012 | Adenovirus Ag [Presence] in Stool by Rapid immunoassay | 0.930 |  | 0 |       0 |
| 3002438 | Parainfluenza virus 2 IgG Ab [Presence] in Serum | 0.930 |  | 0 |       0 |
| 3023510 | Pneumocystis jirovecii Ag [Presence] in Bronchial specimen | 0.929 |  | 0 |       0 |
| 1259627 | Norovirus Ag [Presence] in Specimen | 0.929 |  | 0 |       0 |
| 3043248 | Influenza virus A IgM Ab [Presence] in Serum | 0.928 |  | 0 |       0 |
| 3019430 | Parainfluenza virus 3 IgG Ab [Presence] in Serum | 0.928 |  | 0 |       0 |
| 43055230 | Influenza virus B IgA Ab [Units/volume] in Serum by Immunoassay | 0.927 |  | 0 |       0 |
| 3027545 | Mycoplasma pneumoniae Ab [Presence] in Serum by Immunoassay | 0.927 |  | 1 |  19,646 |
| 3033152 | Legionella pneumophila 1 Ag [Presence] in Urine by Immunoassay | 0.927 | 1169 | 0 |       0 |
| 648118 | Squamous cell carcinoma Ag [Measurement] in Serum or Plasma | 0.927 |  | 0 |       0 |
| 3022052 | Chlamydophila pneumoniae IgM Ab [Units/volume] in Cerebral spinal fluid | 0.927 |  | 0 |       0 |
| 3019407 | Mycoplasma pneumoniae IgA Ab [Units/volume] in Serum | 0.926 |  | 0 |       0 |
| 3046861 | Legionella sp Ag [Presence] in Urine | 0.926 |  | 1 |     304 |
| 3044938 | Influenza virus A RNA [Presence] in Specimen by NAA with probe detection | 0.926 |  | 3 | 142,013 |
| 3023210 | Influenza virus A+B+C Ag [Presence] in Throat | 0.926 |  | 0 |       0 |
| 3025861 | Parainfluenza virus 1 Ab [Units/volume] in Serum | 0.926 |  | 0 |       0 |
| 647751 | Mycoplasma pneumoniae IgG Ab [Measurement] in Cerebral spinal fluid | 0.925 |  | 0 |       0 |
| 3024605 | Mycoplasma pneumoniae IgM Ab [Units/volume] in Serum by Immunoassay | 0.925 | 1556 | 0 |       0 |
| 1091244 | Influenza virus A+B RNA [Presence] in Sputum by NAA with probe detection | 0.925 |  | 0 |       0 |
| 3035217 | Parainfluenza virus 2 IgG Ab [Units/volume] in Serum | 0.923 |  | 0 |       0 |
| 648979 | Mycoplasma pneumoniae Ab [Measurement] in Cerebral spinal fluid | 0.923 |  | 0 |       0 |
| 3052846 | Influenza virus B IgM Ab [Units/volume] in Serum by Immunoassay | 0.923 |  | 0 |       0 |
| 43054917 | Rotavirus Ag [Presence] in Stool by Rapid immunoassay | 0.922 |  | 0 |       0 |
| 3045609 | Influenza virus A+B Ag [Presence] in Bronchial specimen | 0.922 |  | 0 |       0 |
| 40761802 | Mycoplasma pneumoniae IgM Ab [Presence] in Serum by Immunofluorescence | 0.921 |  | 0 |       0 |
| 3040191 | Adenovirus IgM Ab [Units/volume] in Serum by Immunoassay | 0.921 |  | 0 |       0 |
| 3032138 | Parainfluenza virus 4 IgG Ab [Presence] in Serum | 0.920 |  | 0 |       0 |
| 3051390 | Giardia lamblia+Cryptosporidium parvum Ag [Presence] in Stool by Immunoassay | 0.920 |  | 0 |       0 |
| 3044408 | Influenza virus A+B Ag [Presence] in Nose | 0.920 |  | 0 |       0 |
| 3000304 | Giardia lamblia Ag [Presence] in Stool by Immunofluorescence | 0.919 |  | 0 |       0 |
| 3020438 | Influenza virus B Ab [Titer] in Cerebral spinal fluid | 0.919 |  | 0 |       0 |
| 3016357 | Mycoplasma pneumoniae IgA Ab [Presence] in Serum | 0.919 |  | 0 |       0 |
| 36204260 | Influenza virus B IgM Ab [Presence] in Serum by Immunoassay | 0.919 |  | 0 |       0 |
| 3043239 | Influenza virus A IgA Ab [Presence] in Serum | 0.918 |  | 0 |       0 |
| 3009662 | Adenovirus Ab [Units/volume] in Serum | 0.918 |  | 0 |       0 |
| 43055231 | Influenza virus A IgA Ab [Units/volume] in Serum by Immunoassay | 0.917 |  | 0 |       0 |
| 21493666 | Mycophenolate acyl-glucuronide [Mass/volume] in Serum or Plasma | 0.917 |  | 0 |       0 |
| 3050350 | Influenza virus A IgM Ab [Units/volume] in Serum by Immunoassay | 0.917 |  | 0 |       0 |
| 3049833 | Influenza virus A IgA Ab [Mass/volume] in Cerebral spinal fluid | 0.916 |  | 0 |       0 |
| 646703 | Parainfluenza virus 1 IgG Ab [Measurement] in Serum | 0.916 |  | 0 |       0 |
| 3051094 | Squamous cell carcinoma Ag [Mass/volume] in Body fluid | 0.916 |  | 0 |       0 |
| 3021573 | Parainfluenza virus 3 IgG Ab [Units/volume] in Serum | 0.916 |  | 0 |       0 |
| 3049481 | Giardia lamblia+Cryptosporidium parvum Ag [Presence] in Stool by Immunofluorescence | 0.916 |  | 0 |       0 |
| 3046808 | Parainfluenza virus 1 Ab [Titer] in Cerebral spinal fluid | 0.916 |  | 0 |       0 |
| 37020366 | Giardia lamblia Ag [Presence] in Stool by Rapid immunoassay | 0.916 |  | 0 |       0 |
| 3047276 | Influenza virus A Ag [Presence] in Bronchial specimen | 0.916 |  | 0 |       0 |
| 3050404 | Influenza virus A IgM Ab [Mass/volume] in Cerebral spinal fluid | 0.915 |  | 0 |       0 |
| 3027774 | Influenza virus A Ab [Units/volume] in Serum | 0.915 |  | 0 |       0 |
| 1091210 | Legionella pneumophila 1 Ag [Presence] in Specimen | 0.915 |  | 0 |       0 |
| 36304216 | Parainfluenza virus 1 Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.914 |  | 0 |       0 |
| 3039859 | Parainfluenza virus 2 IgG Ab [Presence] in Serum by Immunoassay | 0.913 |  | 0 |       0 |
| 46236341 | Streptococcus pneumoniae Ag [Presence] in Urine by Rapid immunoassay | 0.913 |  | 0 |       0 |
| 36304243 | Parainfluenza virus 2 Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.912 |  | 0 |       0 |
| 3005443 | Influenza virus B IgG Ab [Titer] in Serum | 0.912 |  | 0 |       0 |
| 36305893 | Parainfluenza virus 3 Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.912 |  | 0 |       0 |
| 757685 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.911 |  | 0 |       0 |
| 3021309 | Pneumocystis jirovecii Ag [Presence] in Sputum | 0.911 |  | 0 |       0 |
| 3044430 | Adenovirus Ab [Presence] in Serum | 0.911 |  | 0 |       0 |
| 3026753 | Influenza virus A+B Ag [Presence] in Throat by Immunofluorescence | 0.911 |  | 0 |       0 |
| 3000425 | Parainfluenza virus Ag [Presence] in Specimen | 0.910 |  | 0 |       0 |
| 3043891 | Influenza virus A Ag [Presence] in Nose | 0.910 |  | 0 |       0 |
| 3002031 | Adenovirus 40+41 Ag [Presence] in Stool | 0.910 |  | 0 |       0 |
| 36303582 | Influenza virus B Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.910 |  | 0 |       0 |
| 3005001 | Parainfluenza virus 2 IgM Ab [Presence] in Serum | 0.910 |  | 0 |       0 |
| 3047583 | Parainfluenza virus 1+2+3 Ab [Presence] in Serum | 0.910 |  | 0 |       0 |
| 3042986 | Parainfluenza virus 2 Ab [Units/volume] in Cerebral spinal fluid | 0.909 |  | 0 |       0 |
| 3016669 | Influenza virus A Ab [Presence] in Serum | 0.909 |  | 0 |       0 |
| 3011852 | Influenza virus A+B Ag [Presence] in Throat by Immunoassay | 0.909 |  | 0 |       0 |
| 36203757 | Adenovirus IgM Ab [Presence] in Serum by Immunoassay | 0.909 |  | 0 |       0 |
| 3028162 | Influenza virus A Ag [Presence] in Throat by Immunofluorescence | 0.909 |  | 0 |       0 |
| 3034339 | Parainfluenza virus 2 IgG Ab [Units/volume] in Serum by Immunoassay | 0.908 |  | 0 |       0 |
| 647335 | Influenza virus B IgG Ab [Measurement] in Serum | 0.908 |  | 0 |       0 |
| 40757371 | Influenza virus Ag [Presence] in Specimen | 0.908 |  | 0 |       0 |
| 37021271 | Adenovirus Ag [Presence] in Upper respiratory specimen by Immunoassay | 0.908 |  | 0 |       0 |
| 3004484 | Streptococcus pneumoniae Ag [Presence] in Sputum | 0.908 |  | 0 |       0 |
| 3002623 | Legionella pneumophila Ag [Presence] in Urine by Latex agglutination | 0.907 |  | 0 |       0 |
| 3043286 | Influenza virus B Ab [Presence] in Body fluid | 0.907 |  | 0 |       0 |
| 3019247 | Parainfluenza virus 1 Ag [Presence] in Specimen by Immunofluorescence | 0.907 | 1906 | 0 |       0 |
| 1259611 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen | 0.907 |  | 0 |       0 |
| 37020098 | Human bocavirus Ag [Presence] in Upper respiratory specimen by Immunofluorescence | 0.906 |  | 0 |       0 |
| 3035716 | Adenovirus IgG Ab [Titer] in Serum | 0.906 |  | 0 |       0 |
| 3027146 | Parainfluenza virus 1+2+3 Ag [Presence] in Specimen | 0.905 |  | 0 |       0 |
| 3045936 | Influenza virus A Ag [Presence] in Nasopharynx by Immunofluorescence | 0.905 |  | 0 |       0 |
| 3011115 | Influenza virus A+B Ab [Units/volume] in Serum | 0.905 |  | 0 |       0 |
| 36204257 | Influenza virus A IgM Ab [Presence] in Serum by Immunoassay | 0.905 |  | 0 |       0 |
| 37021263 | Human metapneumovirus Ag [Presence] in Upper respiratory specimen by Immunofluorescence | 0.905 |  | 0 |       0 |
| 40758928 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.905 |  | 0 |       0 |
| 3046524 | Influenza virus A Ag [Presence] in Nasopharynx by Immunoassay | 0.905 | 1201 | 1 |  11,862 |
| 21492989 | Influenza virus B Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.905 |  | 0 |       0 |
| 3026784 | Influenza virus A Ag [Presence] in Throat by Immunoassay | 0.905 |  | 0 |       0 |
| 3026360 | Chlamydophila pneumoniae IgA Ab [Units/volume] in Cerebral spinal fluid | 0.905 |  | 0 |       0 |
| 1175556 | inFLIXimab Ab [Units/volume] in Serum by Immunoassay | 0.905 |  | 2 |   4,852 |
| 3023613 | Influenza virus A IgG Ab [Titer] in Serum | 0.904 |  | 0 |       0 |
| 3043538 | Influenza virus A+B Ab [Presence] in Serum | 0.904 |  | 0 |       0 |
| 3040740 | Influenza virus B Ab [Units/volume] in Serum by Hemagglutination inhibition | 0.904 |  | 0 |       0 |
| 1469880 | Parainfluenza virus 1+2+3+4 IgG Ab [Units/volume] in Serum by Immunoassay | 0.904 |  | 0 |       0 |
| 3021320 | Legionella pneumophila Ag [Presence] in Urine by Immunoassay | 0.904 |  | 0 |       0 |
| 42868411 | Adenovirus IgA Ab [Presence] in Serum by Immunoassay | 0.903 |  | 0 |       0 |
| 647586 | Influenza virus B Ab [Measurement] in Serum | 0.902 |  | 0 |       0 |
| 3026121 | Parainfluenza virus 2 Ag [Presence] in Specimen by Immunofluorescence | 0.902 |  | 0 |       0 |
| 3010448 | Parainfluenza virus 2 IgM Ab [Units/volume] in Serum | 0.902 |  | 0 |       0 |
| 3042756 | Influenza virus B Ag [Presence] in Bronchial specimen by Immunofluorescence | 0.901 |  | 0 |       0 |
| 3040380 | Adenovirus+Rotavirus Ag [Presence] in Stool | 0.901 |  | 0 |       0 |
| 3042198 | Norovirus genogroup I Ag [Presence] in Stool | 0.901 |  | 0 |       0 |
| 3043318 | Adenovirus Ag [Presence] in Nose | 0.901 |  | 0 |       0 |
| 46236374 | Legionella pneumophila 1 Ag [Presence] in Urine by Rapid immunoassay | 0.901 |  | 0 |       0 |
| 37019896 | Adenovirus Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.900 |  | 0 |       0 |
| 3007979 | Giardia lamblia 65 Ag [Presence] in Stool | 0.900 |  | 0 |       0 |
| 37019857 | Pneumocystis jirovecii Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.900 |  | 0 |       0 |
| 3043593 | Parainfluenza virus 3 Ab [Presence] in Cerebral spinal fluid | 0.900 |  | 0 |       0 |
| 36304868 | Influenza virus A Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.900 |  | 0 |       0 |
| 646225 | Influenza virus A IgG Ab [Measurement] in Serum | 0.899 |  | 0 |       0 |
| 37020808 | Human metapneumovirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.899 |  | 0 |       0 |
| 3003733 | Legionella pneumophila Ag [Presence] in Specimen | 0.899 |  | 0 |       0 |
| 3013437 | Mycoplasma pneumoniae IgA Ab [Presence] in Serum by Immunoassay | 0.898 |  | 0 |       0 |
| 648510 | Giardia lamblia+Cryptosporidium sp Ag [Measurement] in Stool | 0.898 |  | 0 |       0 |
| 645226 | Adenovirus IgG Ab [Measurement] in Serum | 0.898 |  | 0 |       0 |
| 21492988 | Influenza virus A Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.897 |  | 0 |       0 |
| 3021705 | Mycoplasma pneumoniae Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.897 |  | 0 |       0 |
| 3015977 | Adenovirus Ag [Presence] in Throat by Immunoassay | 0.896 |  | 0 |       0 |
| 3009449 | Parainfluenza virus 3 Ag [Presence] in Specimen by Immunofluorescence | 0.896 |  | 0 |       0 |
| 3012621 | Mycoplasma pneumoniae IgG Ab [Titer] in Serum | 0.896 |  | 0 |       0 |
| 3011688 | Influenza virus B Ag [Presence] in Specimen by Immunoassay | 0.896 | 796 | 0 |       0 |
| 37021514 | Human metapneumovirus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.896 |  | 0 |       0 |
| 3036198 | Mycoplasma pneumoniae IgM Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.895 |  | 0 |       0 |
| 3009705 | Mycoplasma pneumoniae IgG Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.895 |  | 0 |       0 |
| 3004440 | Adenovirus Ag [Presence] in Urine | 0.895 |  | 0 |       0 |
| 36305905 | Adenovirus Ag [Presence] in Lower respiratory specimen by Immunoassay | 0.895 |  | 0 |       0 |
| 36304782 | Adenovirus Ag [Presence] in Cerebral spinal fluid by Immunoassay | 0.894 |  | 0 |       0 |
| 3009771 | Influenza virus A Ab [Titer] in Cerebral spinal fluid | 0.894 |  | 0 |       0 |
| 36303237 | Adenovirus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.894 |  | 0 |       0 |
| 3044569 | Mycoplasma pneumoniae Ab [Presence] in Body fluid | 0.894 |  | 0 |       0 |
| 37020125 | Adenovirus Ag [Presence] in Lower respiratory specimen by Rapid immunoassay | 0.893 |  | 0 |       0 |
| 3002233 | Pneumocystis jirovecii Ag [Presence] in Serum | 0.893 |  | 0 |       0 |
| 647204 | Mycoplasma pneumoniae IgG Ab [Measurement] in Serum | 0.893 |  | 0 |       0 |
| 37021256 | Human bocavirus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.893 |  | 0 |       0 |
| 648021 | Adenovirus Ag [Measurement] in Stool | 0.893 |  | 0 |       0 |
| 3001533 | Legionella pneumophila Ag [Presence] in Urine by Immunofluorescence | 0.893 |  | 0 |       0 |
| 646705 | Influenza virus A Ab [Measurement] in Cerebral spinal fluid | 0.892 |  | 0 |       0 |
| 3009629 | Parainfluenza virus 1 Ag [Presence] in Throat | 0.892 |  | 0 |       0 |
| 3006433 | Cryptosporidium sp Ag [Presence] in Stool | 0.892 |  | 0 |       0 |
| 3008787 | Adenovirus Ag [Presence] in Throat by Immunofluorescence | 0.892 |  | 0 |       0 |
| 3013704 | Influenza virus B Ag [Presence] in Specimen by Immunofluorescence | 0.891 |  | 0 |       0 |
| 3039848 | Human metapneumovirus Ag [Presence] in Specimen by Immunofluorescence | 0.891 |  | 0 |       0 |
| 36032419 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Immunoassay | 0.891 |  | 3 |  32,724 |
| 3023444 | Influenza virus A+B+C Ag [Presence] in Specimen | 0.891 |  | 0 |       0 |
| 37019613 | Parainfluenza virus 2 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.891 |  | 0 |       0 |
| 1091110 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Specimen | 0.891 |  | 0 |       0 |
| 3004319 | Pneumocystis jirovecii Ag [Presence] in Urine | 0.891 |  | 0 |       0 |
| 3022602 | Parainfluenza virus 3 Ag [Presence] in Throat | 0.890 |  | 0 |       0 |
| 3012646 | Influenza virus A+B Ag [Presence] in Specimen by Immunoassay | 0.890 | 1992 | 0 |       0 |
| 1259564 | Norovirus genogroup II Ag [Presence] in Stool | 0.890 |  | 0 |       0 |
| 3016196 | Parainfluenza virus 2 Ag [Presence] in Throat | 0.889 |  | 0 |       0 |
| 3044357 | Adenovirus Ag [Presence] in Nasopharynx by Immunofluorescence | 0.889 |  | 0 |       0 |
| 3000251 | Influenza virus B Ag [Presence] in Throat | 0.889 |  | 0 |       0 |
| 3010633 | Mycoplasma sp Ab [Presence] in Serum | 0.888 |  | 0 |       0 |
| 36304958 | Adenovirus Ag [Presence] in Nasopharynx by Immunoassay | 0.888 |  | 0 |       0 |
| 3010064 | Influenza virus A+B Ag [Presence] in Specimen by Immunofluorescence | 0.888 |  | 0 |       0 |
| 40762313 | Squamous cell carcinoma Ag [Mass/volume] in Pleural fluid | 0.887 |  | 0 |       0 |
| 647182 | Rotavirus Ag [Presence] in Specimen by Immunoassay | 0.887 |  | 0 |       0 |
| 3024400 | Influenza virus A Ag [Presence] in Specimen by Immunofluorescence | 0.887 | 1296 | 0 |       0 |
| 3026395 | Mycoplasma pneumoniae Ab [Titer] in Serum | 0.887 |  | 0 |       0 |
| 3028459 | Influenza virus A Ag [Presence] in Specimen by Immunoassay | 0.886 | 728 | 0 |       0 |
| 3007023 | Streptococcus pneumoniae Ag [Presence] in Serum | 0.886 |  | 0 |       0 |
| 3045194 | Adenovirus Ab [Titer] in Cerebral spinal fluid | 0.885 |  | 0 |       0 |
| 3049806 | Human bocavirus Ag [Presence] in Specimen by Immunofluorescence | 0.884 |  | 0 |       0 |
| 3042763 | Influenza virus A Ag [Presence] in Bronchial specimen by Immunofluorescence | 0.884 |  | 0 |       0 |
| 3043512 | Parainfluenza virus 1 Ab [Titer] in Cerebral spinal fluid by Complement fixation | 0.883 |  | 0 |       0 |
| 3017558 | Chlamydophila pneumoniae IgM Ab [Presence] in Serum | 0.883 |  | 0 |       0 |
| 3015211 | Giardia lamblia Ag [Presence] in Specimen by Immunoassay | 0.883 |  | 0 |       0 |
| 40763479 | Parainfluenza virus 4 Ag [Presence] in Specimen | 0.882 |  | 0 |       0 |
| 37019589 | Parainfluenza virus 1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.881 |  | 0 |       0 |
| 1092044 | Influenza virus A RNA [Presence] in Specimen | 0.881 |  | 0 |       0 |
| 3011647 | Adenovirus Ag [Presence] in Specimen by Immunoassay | 0.880 |  | 0 |       0 |
| 36033641 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.880 |  | 1 |  15,478 |
| 3051190 | Parainfluenza virus 1 Ag [Presence] in Nasopharynx by Immunofluorescence | 0.880 |  | 0 |       0 |
| 3046648 | Adenovirus Ag [Presence] in Bronchial specimen by Immunofluorescence | 0.879 |  | 0 |       0 |
| 3020161 | Adenovirus Ag [Presence] in Conjunctival specimen | 0.879 |  | 0 |       0 |
| 3006237 | Chlamydophila pneumoniae IgG Ab [Units/volume] in Serum | 0.879 |  | 0 |       0 |
| 37021465 | Parainfluenza virus 3 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.878 |  | 0 |       0 |
| 3045831 | Influenza virus B Ag [Presence] in Nasopharynx | 0.877 |  | 0 |       0 |
| 3002261 | Adenovirus 40+41 Ag [Presence] in Stool by Immunoassay | 0.875 |  | 0 |       0 |
| 46236092 | Parainfluenza virus 2 Ag [Presence] in Nasopharynx by Immunofluorescence | 0.873 |  | 0 |       0 |
| 46236093 | Parainfluenza virus 3 Ag [Presence] in Nasopharynx by Immunofluorescence | 0.872 |  | 0 |       0 |
| 706163 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.871 |  | 2 | 961,920 |
| 1092017 | Rotavirus A RNA [Presence] in Specimen | 0.870 |  | 0 |       0 |
| 3045856 | Influenza virus B Ag [Presence] in Nose | 0.869 |  | 0 |       0 |
| 3009486 | Mycoplasma pneumoniae Ab [Titer] in Cerebral spinal fluid by Complement fixation | 0.869 |  | 0 |       0 |
| 3010092 | Mycoplasma pneumoniae IgM Ab [Titer] in Serum | 0.868 |  | 0 |       0 |
| 3010871 | Adenovirus IgM Ab [Titer] in Serum | 0.868 |  | 0 |       0 |
| 648236 | Rotavirus Ag [Measurement] in Stool | 0.866 |  | 0 |       0 |
| 43054998 | Influenza virus A+B Ag [Presence] in Nose by Rapid immunoassay | 0.866 |  | 0 |       0 |
| 36304052 | Adalimumab Ab [Units/volume] in Serum or Plasma | 0.865 |  | 3 |   2,402 |
| 3009873 | Streptococcus pneumoniae Ag [Presence] in Specimen by Latex agglutination | 0.865 |  | 0 |       0 |
| 647536 | Adenovirus Ab [Measurement] in Cerebral spinal fluid | 0.865 |  | 0 |       0 |
| 1092430 | Influenza virus A H1 RNA [Presence] in Specimen | 0.863 |  | 0 |       0 |
| 3047351 | Parainfluenza virus 3 Ab [Presence] in Cerebral spinal fluid by Complement fixation | 0.863 |  | 0 |       0 |
| 37021321 | Human bocavirus 1+2+3 DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.863 |  | 0 |       0 |
| 21493425 | Influenza virus A H7 Eurasia RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.862 |  | 0 |       0 |
| 40762316 | Squamous cell carcinoma Ag [Mass/volume] in Peritoneal fluid | 0.862 |  | 0 |       0 |
| 36031238 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with non-probe detection | 0.861 |  | 0 |       0 |
| 3015683 | Streptococcus pneumoniae Ag [Presence] in Specimen by Immunofluorescence | 0.858 |  | 0 |       0 |
| 36660200 | Influenza virus A H1 2009 pandemic RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.858 |  | 0 |       0 |
| 3027653 | Mycophenolate [Mass/volume] in Serum or Plasma | 0.857 |  | 3 |   1,935 |
| 36203322 | Influenza virus B RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.857 |  | 0 |       0 |
| 3029009 | Influenza virus A H3 Ag [Presence] in Isolate by Immunofluorescence | 0.857 |  | 0 |       0 |
| 36660307 | Influenza virus A H3 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.856 |  | 0 |       0 |
| 37020058 | Rotavirus A RNA [Presence] in Stool by NAA with probe detection | 0.856 |  | 0 |       0 |
| 37021392 | Influenza virus A H3 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.856 |  | 0 |       0 |
| 36305650 | Human metapneumovirus Ag [Presence] in Nasopharynx by Immunofluorescence | 0.855 |  | 0 |       0 |
| 3022580 | Parainfluenza virus 3 IgM Ab [Units/volume] in Serum | 0.855 |  | 0 |       0 |
| 3044123 | Influenza virus A Ag [Presence] in Nose by Immunofluorescence | 0.853 |  | 0 |       0 |
| 3009134 | Squamous cell carcinoma Ag [Units/volume] in Pleural fluid | 0.853 |  | 0 |       0 |
| 646282 | Mycoplasma pneumoniae IgM Ab [Measurement] in Serum | 0.853 |  | 0 |       0 |
| 36661377 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by Sequencing | 0.853 |  | 0 |       0 |
| 21493480 | Rotavirus A RNA [Presence] in Stool by NAA with non-probe detection | 0.852 |  | 0 |       0 |
| 723465 | SARS-CoV-2 (COVID-19) S gene [Presence] in Respiratory system specimen by NAA with probe detection | 0.852 |  | 0 |       0 |
| 3050423 | Human bocavirus IgG Ab [Presence] in Specimen | 0.852 |  | 0 |       0 |
| 3008909 | Norovirus RNA [Presence] in Stool by NAA with probe detection | 0.851 |  | 1 |  17,197 |
| 3021630 | Parainfluenza virus 1 Ab [Units/volume] in Body fluid | 0.849 |  | 0 |       0 |
| 3046445 | Influenza virus B Ag [Presence] in Nose by Immunofluorescence | 0.848 |  | 0 |       0 |
| 3001684 | Respiratory syncytial virus Ag [Presence] in Specimen | 0.848 |  | 1 |   2,352 |
| 37020057 | Human metapneumovirus RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.848 |  | 0 |       0 |
| 36304919 | Influenza virus B RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.847 |  | 0 |       0 |
| 3037758 | Squamous cell carcinoma Ag [Moles/volume] in Pleural fluid | 0.847 |  | 0 |       0 |
| 3042194 | Human metapneumovirus RNA [Presence] in Specimen by NAA with probe detection | 0.846 |  | 2 |  18,405 |
| 3031540 | Cytomegalovirus IgG Ab [Presence] in Cerebral spinal fluid | 0.846 |  | 0 |       0 |
| 1091603 | Influenza virus A H1 2009 pandemic RNA [Presence] in Specimen by Molecular genetics method | 0.844 |  | 0 |       0 |
| 1091752 | Human metapneumovirus RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.843 |  | 0 |       0 |
| 40770421 | Human metapneumovirus A RNA [Presence] in Specimen by NAA with probe detection | 0.843 |  | 0 |       0 |
| 36305655 | Human bocavirus DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.842 |  | 0 |       0 |
| 40758594 | Influenza virus A H1 2009 pandemic RNA [Presence] in Specimen by NAA with probe detection | 0.842 |  | 0 |       0 |
| 3014286 | Streptococcus pneumoniae Ag [Presence] in Cerebral spinal fluid | 0.842 |  | 0 |       0 |
| 647461 | Rotavirus RNA [Presence] in Stool by NAA with probe detection | 0.842 |  | 0 |       0 |
| 646316 | Squamous cell carcinoma Ag [Measurement] in Pleural fluid | 0.841 |  | 0 |       0 |
| 3035112 | Parainfluenza virus 3 IgM Ab [Presence] in Serum | 0.839 |  | 0 |       0 |
| 3012734 | Streptococcus pneumoniae Ag [Presence] in Sputum by Immunofluorescence | 0.838 |  | 0 |       0 |
| 3038217 | Adenovirus Ab [Units/volume] in Cerebral spinal fluid | 0.837 |  | 0 |       0 |
| 37020998 | Streptococcus pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.836 |  | 0 |       0 |
| 3044571 | Measles virus IgG Ab [Presence] in Cerebral spinal fluid | 0.836 |  | 0 |       0 |
| 3043257 | Herpes virus 6 IgG Ab [Presence] in Cerebral spinal fluid | 0.833 |  | 1 |     287 |
| 40758927 | Mycophenolate [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.832 |  | 0 |       0 |
| 36304315 | Certolizumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.832 |  | 3 |      74 |
| 3015162 | Norovirus [Presence] in Stool by Electron microscopy | 0.832 |  | 0 |       0 |
| 1259587 | Human bocavirus DNA [Presence] in Upper respiratory specimen by NAA with non-probe detection | 0.832 |  | 0 |       0 |
| 3045300 | Herpes simplex virus IgG Ab [Presence] in Cerebral spinal fluid | 0.831 |  | 0 |       0 |
| 36303776 | Human bocavirus DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.830 |  | 0 |       0 |
| 1175645 | Adalimumab Ab [Units/volume] in Serum by Immunoassay | 0.829 |  | 0 |       0 |
| 3965476 | Ustekinumab and Ustekinumab Ab panel - Serum or Plasma | 0.829 |  | 0 |       0 |
| 645278 | Influenza virus A H1 2009 pandemic RNA [Presence] in Specimen by NAA with non-probe detection | 0.829 |  | 0 |       0 |
| 44786774 | Adalimumab [Mass/volume] in Serum or Plasma | 0.829 |  | 7 |   3,981 |
| 36306063 | Golimumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.828 |  | 1 |     706 |
| 43533710 | Streptococcus pneumoniae Ag [Presence] in Isolate by Latex agglutination | 0.827 |  | 0 |       0 |
| 40765161 | Human bocavirus DNA [Presence] in Specimen by NAA with probe detection | 0.824 |  | 2 |  13,049 |
| 3049750 | Human bocavirus IgG Ab [Presence] in Specimen by Immunoassay | 0.823 |  | 0 |       0 |
| 36305036 | Ustekinumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.819 |  | 0 |       0 |
| 36304617 | Golimumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.818 |  | 3 |     940 |
| 36304759 | Respiratory syncytial virus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.817 |  | 0 |       0 |
| 1989156 | Adalimumab and Adalimumab Ab panel - Serum or Plasma by Immunoassay | 0.816 |  | 0 |       0 |
| 3005444 | Respiratory syncytial virus Ag [Presence] in Specimen by Immunofluorescence | 0.815 | 1674 | 0 |       0 |
| 1091638 | Risankizumab Ab panel - Serum or Plasma | 0.813 |  | 0 |       0 |
| 40758035 | Norovirus genogroup I RNA [Presence] in Stool by NAA with probe detection | 0.812 |  | 0 |       0 |
| 21493479 | Norovirus genogroup I+II RNA [Presence] in Stool by NAA with non-probe detection | 0.811 |  | 0 |       0 |
| 3965617 | Respiratory syncytial virus A RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.809 |  | 0 |       0 |
| 43055501 | Mycophenolate [Mass/volume] in Serum or Plasma --trough | 0.808 |  | 0 |       0 |
| 40761116 | Natalizumab Ab [Presence] in Serum | 0.807 |  | 0 |       0 |
| 42868685 | Mycophenolate [Moles/volume] in Serum or Plasma | 0.804 | 1787 | 0 |       0 |
| 706162 | Respiratory viral pathogens DNA and RNA panel - Respiratory system specimen Qualitative by NAA with probe detection | 0.801 |  | 0 |       0 |
| 37021212 | Respiratory pathogens DNA and RNA panel - Respiratory system specimen by NAA with probe detection | 0.801 |  | 0 |       0 |
| 44786773 | Adalimumab Ab [Mass/volume] in Serum or Plasma | 0.798 |  | 0 |       0 |
| 42528612 | riTUXimab [Mass/volume] in Serum or Plasma by Immunoassay | 0.798 |  | 0 |       0 |
| 3032518 | Natalizumab Ab [Presence] in Serum by Immunoassay | 0.787 |  | 0 |       0 |
| 21492987 | Influenza virus A and B Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.786 |  | 0 |       0 |
| 43533705 | Mycophenolate [Mass/volume] in Serum or Plasma --peak | 0.783 |  | 0 |       0 |
| 36303341 | Mycophenolate and mycophenolate glucuronide panel - Serum or Plasma | 0.775 |  | 0 |       0 |
| 648623 | Mycophenolate [Measurement] in Serum or Plasma | 0.774 |  | 0 |       0 |
| 36031949 | Influenza virus A and B and SARS-CoV+SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.772 |  | 0 |       0 |
| 40757376 | Respiratory virus Ag [Identifier] in Specimen by Immunofluorescence | 0.770 |  | 0 |       0 |
| 36033643 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.769 |  | 0 |       0 |
| 36659876 | Respiratory viral pathogens DNA and RNA panel - Lower respiratory specimen by NAA with probe detection | 0.769 |  | 0 |       0 |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.767 |  | 0 |       0 |
| 3966315 | Systemic lupus Ab panel - Serum or Plasma | 0.767 |  | 0 |       0 |
| 1091483 | SP100 and GP210 Ab.IgG panel - Serum or Plasma | 0.765 |  | 0 |       0 |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.765 |  | 2 |  45,357 |
| 46235394 | Respiratory pathogens RNA 8 panel - Specimen by NAA with probe detection | 0.764 |  | 0 |       0 |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.761 |  | 0 |       0 |
| 36659953 | Connective tissue autoimmune IgG panel - Serum or Plasma | 0.761 |  | 0 |       0 |
| 36303490 | Coccidioides immitis IgG and IgM panel - Serum or Plasma | 0.758 |  | 0 |       0 |
| 40758231 | Respiratory pathogens panel - Specimen by Organism specific culture | 0.758 |  | 0 |       0 |
| 649422 | Adalimumab Ab [Measurement] in Serum or Plasma | 0.756 |  | 0 |       0 |
| 706158 | SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.756 |  | 0 |       0 |
| 37020688 | Human metapneumovirus and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.756 |  | 0 |       0 |
| 37020812 | Human metapneumovirus and Respiratory syncytial virus RNA panel - Lower respiratory specimen by NAA with probe detection | 0.752 |  | 0 |       0 |
| 3037738 | Interferon beta Ab [Presence] in Serum or Plasma | 0.751 |  | 0 |       0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 711 | -adenag |  | 1964 | 100 |  | -Adenovirus, antigeeni |  |  | Adenovirus Ag [Presence] in Respiratory system specimen | FALSE |
| 712 | -bokaag |  | 187 | 100 |  |  |  |  | Human bocavirus Ag [Presence] in Respiratory system specimen | FALSE |
| 713 | -coinrsv |  | 2490 | 100 |  |  |  |  |  | FALSE |
| 714 | -inabrsv |  | 19142 | 100 |  |  |  |  | Influenza virus A+Influenza virus B+Respiratory syncytial virus Ag [Presence] in Respiratory system specimen | FALSE |
| 715 | -infaag |  | 10730 | 100 |  | -Influenssa A -virus, antigeeni |  |  | Influenza virus A Ag [Presence] in Respiratory system specimen | FALSE |
| 716 | -infabag |  | 15107 | 100 |  | -Influenssa A ja B -virus, antigeeni |  |  | Influenza virus A+B Ag [Presence] in Respiratory system specimen | FALSE |
| 717 | -infabnh |  | 961 | 100 |  |  |  |  | Influenza virus A+B RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 718 | -infah03 |  | 227 | 100 |  |  |  |  |  | FALSE |
| 719 | -infah09 |  | 488 | 100 |  |  |  |  | Influenza virus A H1N1 2009 Ag [Presence] in Respiratory system specimen | FALSE |
| 720 | -infah1 |  | 480 | 100 |  |  |  |  | Influenza virus A H1 Ag [Presence] in Respiratory system specimen | FALSE |
| 721 | -infah3 |  | 261 | 100 |  |  |  |  | Influenza virus A H3 Ag [Presence] in Respiratory system specimen | FALSE |
| 722 | -infavt |  | 1271 | 100 |  |  |  |  |  | FALSE |
| 723 | -infbag |  | 10722 | 100 |  | -Influenssa B -virus, antigeeni |  |  | Influenza virus B Ag [Presence] in Respiratory system specimen | FALSE |
| 724 | -infbvt |  | 1271 | 100 |  |  |  |  |  | FALSE |
| 725 | -infl.a |  | 220 | 100 |  |  |  |  | Influenza virus A [Presence] in Respiratory system specimen | FALSE |
| 726 | -infl.b |  | 220 | 100 |  |  |  |  | Influenza virus B [Presence] in Respiratory system specimen | FALSE |
| 727 | -infrpak |  | 1338 | 100 |  |  |  |  | Respiratory virus panel - Respiratory system specimen | TRUE |
| 728 | -infrsv |  | 162 | 100 |  |  |  |  | Influenza virus+Respiratory syncytial virus Ag [Presence] in Respiratory system specimen | FALSE |
| 729 | -ivf-et |  | 194 | 100 |  |  |  | Special technique |  | FALSE |
| 730 | -koroag |  | 625 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen | FALSE |
| 731 | -metpnag |  | 370 | 100 |  |  |  |  | Human metapneumovirus Ag [Presence] in Respiratory system specimen | FALSE |
| 732 | -pin1ag |  | 1146 | 100 |  | -Parainfluenssa 1 -virus, antigeeni |  |  | Parainfluenza virus 1 Ag [Presence] in Respiratory system specimen | FALSE |
| 733 | -pin2ag |  | 1147 | 100 |  | -Parainfluenssa 2 -virus, antigeeni |  |  | Parainfluenza virus 2 Ag [Presence] in Respiratory system specimen | FALSE |
| 734 | -pin3ag |  | 1147 | 100 |  | -Parainfluenssa 3 -virus, antigeeni |  |  | Parainfluenza virus 3 Ag [Presence] in Respiratory system specimen | FALSE |
| 735 | -pinf1ag |  | 235 | 100 |  |  |  |  | Parainfluenza virus 1 Ag [Presence] in Respiratory system specimen | FALSE |
| 736 | -pinf2ag |  | 235 | 100 |  |  |  |  | Parainfluenza virus 2 Ag [Presence] in Respiratory system specimen | FALSE |
| 737 | -pinf3ag |  | 235 | 100 |  |  |  |  | Parainfluenza virus 3 Ag [Presence] in Respiratory system specimen | FALSE |
| 738 | -pnjiag |  | 188 | 100 |  | -Pneumocystis jirovecii, antigeeni |  |  | Pneumocystis jirovecii Ag [Presence] in Respiratory system specimen | FALSE |
| 739 | -rvirag |  | 3025 | 100 |  | -Respiratoristen virusten antigeeni |  |  | Respiratory virus Ag panel - Respiratory system specimen | TRUE |
| 740 | -stpnag |  | 4094 | 100 |  | -Streptococcus pneumoniae, antigeeni |  |  | Streptococcus pneumoniae Ag [Presence] in Respiratory system specimen | FALSE |
| 741 | bi-inflamm |  | 311 | 100 |  |  | Bile |  |  | FALSE |
| 742 | f-adenag |  | 863 | 100 |  | F -Adenovirus, antigeeni | Feces |  | Adenovirus Ag [Presence] in Stool | FALSE |
| 743 | f-giarag |  | 218 | 100 |  | F -Giardia, antigeeni | Feces |  | Giardia lamblia Ag [Presence] in Stool | FALSE |
| 744 | f-gicrag |  | 163 | 99.39 |  |  | Feces |  | Giardia lamblia+Cryptosporidium sp Ag [Presence] in Stool | FALSE |
| 745 | f-noroag |  | 1048 | 100 |  |  | Feces |  | Norovirus Ag [Presence] in Stool | FALSE |
| 746 | f-rotaag |  | 886 | 100 |  | F -Rotavirus, antigeeni | Feces |  | Rotavirus A Ag [Presence] in Stool | FALSE |
| 747 | f-virag |  | 489 | 100 |  |  | Feces |  |  | FALSE |
| 748 | li-adenabg |  | 215 | 100 |  | Li-Adenovirus, IgG-vasta-aineet | Cerebrospinal fluid |  | Adenovirus IgG Ab [Presence] in Cerebral spinal fluid | FALSE |
| 749 | li-infaabg | eiu | 40 | 0 |  | Li-Influenssa A -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza virus A IgG Ab [Units/volume] in Cerebral spinal fluid | FALSE |
| 750 | li-infaabg |  | 240 | 100 |  | Li-Influenssa A -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza virus A IgG Ab [Presence] in Cerebral spinal fluid | FALSE |
| 751 | li-infbabg | eiu | 18 | 0 |  | Li-Influenssa B -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza virus B IgG Ab [Units/volume] in Cerebral spinal fluid | FALSE |
| 752 | li-infbabg |  | 258 | 100 |  | Li-Influenssa B -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza virus B IgG Ab [Presence] in Cerebral spinal fluid | FALSE |
| 753 | li-mypnab |  | 614 | 100 |  | Li-Mycoplasma pneumoniae, vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae Ab [Presence] in Cerebral spinal fluid | FALSE |
| 754 | li-mypnabg | eiu | 32 | 0 |  | Li-Mycoplasma pneumoniae, IgG-vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae IgG Ab [Units/volume] in Cerebral spinal fluid | FALSE |
| 755 | li-mypnabg |  | 1292 | 100 |  | Li-Mycoplasma pneumoniae, IgG-vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae IgG Ab [Presence] in Cerebral spinal fluid | FALSE |
| 756 | li-mypnabm |  | 1314 | 100 |  | Li-Mycoplasma pneumoniae, IgM-vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae IgM Ab [Presence] in Cerebral spinal fluid | FALSE |
| 757 | li-pin1abg | eiu | 7 | 0 |  | Li-Parainfluenssa 1 -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Parainfluenza virus 1 IgG Ab [Units/volume] in Cerebral spinal fluid | FALSE |
| 758 | li-pin1abg |  | 161 | 100 |  | Li-Parainfluenssa 1 -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Parainfluenza virus 1 IgG Ab [Presence] in Cerebral spinal fluid | FALSE |
| 759 | ns-infab/r |  | 181 | 100 |  |  | Nasal secretion |  | Influenza virus A+B [Presence] in Nasal mucosa | FALSE |
| 760 | ps-adenag |  | 1955 | 100 |  | Ps-Adenovirus, antigeeni (NPS-näyte) | Pharyngeal secretion |  | Adenovirus Ag [Presence] in Pharynx | FALSE |
| 761 | ps-infaag |  | 11885 | 100 |  |  | Pharyngeal secretion |  | Influenza virus A Ag [Presence] in Pharynx | FALSE |
| 762 | ps-infbag |  | 11881 | 100 |  |  | Pharyngeal secretion |  | Influenza virus A+B Ag [Presence] in Pharynx | FALSE |
| 763 | rvirag-o |  | 340 | 100 |  |  |  | Qualitative test (also semi-quantitative) | Respiratory virus Ag panel - Respiratory system specimen | TRUE |
| 764 | s-adenabg | eiu | 240 | 0 | [29.8, 39.96, 46.52, 56.21, 66.99, 76.86, 88.44, 100.94, 123.7] | S -Adenovirus, IgG-vasta-aineet | Serum |  | Adenovirus IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 765 | s-adenabg |  | 30 | 96.67 |  | S -Adenovirus, IgG-vasta-aineet | Serum |  | Adenovirus IgG Ab [Presence] in Serum or Plasma | FALSE |
| 766 | s-infaabg | eiu | 288 | 0 | [44.84, 67.49, 80.03, 92.84, 100.98, 109.5, 120.03, 134.44, 150.75] | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  | Influenza virus A IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 767 | s-infaabg | u/ml | 31 | 0 |  | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  | Influenza virus A IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 768 | s-infaabg |  | 46 | 71.74 |  | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  | Influenza virus A IgG Ab [Presence] in Serum or Plasma | FALSE |
| 769 | s-infbab | eiu | 84 | 0 | [37, 45.5, 59.88, 67.83, 76.88, 87.5, 108.12, 125, 142] | S -Influenssa B -virus, vasta-aineet | Serum |  | Influenza virus B Ab [Units/volume] in Serum or Plasma | FALSE |
| 770 | s-infbab | u/ml | 20 | 0 |  | S -Influenssa B -virus, vasta-aineet | Serum |  | Influenza virus B Ab [Units/volume] in Serum or Plasma | FALSE |
| 771 | s-infbab |  | 20 | 100 |  | S -Influenssa B -virus, vasta-aineet | Serum |  | Influenza virus B Ab [Presence] in Serum or Plasma | FALSE |
| 772 | s-infbabg | eiu | 202 | 0 | [27.36, 39.2, 49.01, 55.71, 69.1, 81.14, 95.12, 117.99, 145.85] | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  | Influenza virus B IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 773 | s-infbabg | u/ml | 5 | 0 |  | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  | Influenza virus B IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 774 | s-infbabg |  | 19 | 73.68 |  | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  | Influenza virus B IgG Ab [Presence] in Serum or Plasma | FALSE |
| 775 | s-infli | mg/l | 4337 | 0.09 | [2.45, 4.22, 5.77, 7.21, 8.78, 10.55, 12.36, 14.93, 19.68] | S -Infliksimabi | Serum |  | Infliximab [Mass/volume] in Serum or Plasma | FALSE |
| 776 | s-infli | ug/l | 62 | 0 |  | S -Infliksimabi | Serum |  | Infliximab [Mass/volume] in Serum or Plasma | FALSE |
| 777 | s-infli | âug/ml | 5 | 0 |  | S -Infliksimabi | Serum |  | Infliximab [Mass/volume] in Serum or Plasma | FALSE |
| 778 | s-infli |  | 1486 | 32.77 | [2.05, 3.56, 5.06, 6.2, 7.59, 8.94, 10.97, 13.84, 18.03] | S -Infliksimabi | Serum |  | Infliximab [Mass/volume] in Serum or Plasma | FALSE |
| 779 | s-infliab | au/ml | 413 | 0.73 | [6.57, 14.16, 21.28, 34.4, 52.11, 73.2, 118.89, 190.88, 374.2] | S -Infliksimabi, vasta-aineet | Serum |  | Infliximab Ab [Units/volume] in Serum or Plasma | FALSE |
| 780 | s-infliab |  | 4455 | 99.89 |  | S -Infliksimabi, vasta-aineet | Serum |  | Infliximab Ab [Presence] in Serum or Plasma | FALSE |
| 781 | s-infliks | mg/l | 951 | 0 | [1.81, 3, 4.49, 5.55, 6.66, 8.19, 10.34, 13.5, 19.13] |  | Serum |  | Infliximab [Mass/volume] in Serum or Plasma | FALSE |
| 782 | s-infliks |  | 310 | 30.97 | [1.21, 2.24, 3.08, 4.32, 5.17, 6.19, 7.17, 7.95, 9.17] |  | Serum |  | Infliximab [Mass/volume] in Serum or Plasma | FALSE |
| 783 | s-inflipa |  | 4630 | 100 |  |  | Serum |  | Infliximab and Infliximab Ab panel - Serum or Plasma | TRUE |
| 784 | s-micfaeg | mg/l | 45 | 0 |  |  | Serum |  | Mycophenolic acid glucuronide [Mass/volume] in Serum or Plasma | FALSE |
| 785 | s-micfaeg |  | 90 | 76.67 |  |  | Serum |  | Mycophenolic acid glucuronide [Mass/volume] in Serum or Plasma | FALSE |
| 786 | s-mypnab |  | 19694 | 99.92 |  | S -Mycoplasma pneumoniae, vasta-aineet | Serum |  | Mycoplasma pneumoniae Ab [Presence] in Serum or Plasma | FALSE |
| 787 | s-mypnabg | au/ml | 2298 | 0 | [0.52, 1.18, 1.86, 2.68, 3.78, 5.69, 8.99, 16.54, 33.76] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 788 | s-mypnabg | eiu | 9577 | 0 | [51.21, 64.99, 79.08, 95.09, 113.13, 134.88, 160.85, 200.43, 260.64] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 789 | s-mypnabg | form | 53 | 0 |  | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Presence] in Serum or Plasma | FALSE |
| 790 | s-mypnabg | ru/ml | 384 | 0 | [19.56, 23.19, 26.12, 30.65, 34.99, 40.45, 50.94, 60.03, 79.86] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 791 | s-mypnabg |  | 4994 | 100 | [0.53, 1.1, 1.73, 2.48, 3.76, 5.77, 9.79, 21.47, 68.82] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Presence] in Serum or Plasma | FALSE |
| 792 | s-mypnabm | form | 16 | 0 |  | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM Ab [Presence] in Serum or Plasma | FALSE |
| 793 | s-mypnabm | index | 3618 | 0 | [1.53, 2.22, 2.83, 3.43, 4.2, 5.16, 6.56, 8.38, 11.18] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM Ab [Ratio] in Serum or Plasma | FALSE |
| 794 | s-mypnabm | s/co | 1089 | 0 | [0.1, 0.1, 0.2, 0.2, 0.3, 0.33, 0.47, 0.63, 1.13] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM Ab [Ratio] in Serum or Plasma | FALSE |
| 795 | s-mypnabm |  | 12775 | 100 | [1.19, 1.67, 2.14, 2.58, 3.04, 3.6, 4.51, 5.78, 8.21] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM Ab [Presence] in Serum or Plasma | FALSE |
| 796 | s-pin1abg | eiu | 209 | 0 | [51.38, 65.97, 78.97, 87.7, 96.4, 106.81, 114.5, 126.75, 144.62] | S -Parainfluenssa 1 -virus, IgG-vasta-aineet | Serum |  | Parainfluenza virus 1 IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 797 | s-pin1abg |  | 9 | 88.89 |  | S -Parainfluenssa 1 -virus, IgG-vasta-aineet | Serum |  | Parainfluenza virus 1 IgG Ab [Presence] in Serum or Plasma | FALSE |
| 798 | s-scc-ag | ug/l | 959 | 0 | [0.88, 1.03, 1.2, 1.38, 1.6, 2.01, 2.55, 3.56, 6.69] | S -Squamous cell carsinoma, antigeeni | Serum | Antigen | Squamous cell carcinoma Ag [Mass/volume] in Serum or Plasma | FALSE |
| 799 | s-scc-ag |  | 493 | 95.94 |  | S -Squamous cell carsinoma, antigeeni | Serum | Antigen | Squamous cell carcinoma Ag [Mass/volume] in Serum or Plasma | FALSE |
| 800 | u-lepnag |  | 3943 | 100 |  | U -Legionella pneumophila, antigeeni | Urine |  | Legionella pneumophila serogroup 1 Ag [Presence] in Urine | FALSE |
| 801 | u-pneuag |  | 2058 | 100 |  |  | Urine |  | Streptococcus pneumoniae Ag [Presence] in Urine | FALSE |
| 802 | u-stpnag |  | 2546 | 100 |  | U -Streptococcus pneumoniae, antigeeni | Urine |  | Streptococcus pneumoniae Ag [Presence] in Urine | FALSE |

