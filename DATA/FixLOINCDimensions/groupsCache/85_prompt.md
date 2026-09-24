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
Here is group 85.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3020710 | Acetone [Moles/volume] in Serum or Plasma | 1.000 | 1019 |  0 |       0 |
| 3022859 | Acetone [Presence] in Serum or Plasma | 1.000 |  |  0 |       0 |
| 3026470 | Cobalt [Mass/volume] in Blood | 1.000 |  |  4 |   4,913 |
| 3026493 | Urate [Moles/volume] in Serum or Plasma | 1.000 | 142 | 17 | 314,502 |
| 3964787 | Human coronavirus HKU1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  |  0 |       0 |
| 3965395 | Human coronavirus NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  |  0 |       0 |
| 3965970 | Human coronavirus 229E RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  |  0 |       0 |
| 3966673 | Human coronavirus OC43 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  |  0 |       0 |
| 40768804 | Tissue Pathology biopsy report | 1.000 |  |  9 | 373,531 |
| 3005136 | Cladosporium herbarum IgE Ab [Units/volume] in Serum | 0.980 | 718 |  8 |   7,686 |
| 37020776 | Human coronavirus 229E+NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.971 |  |  0 |       0 |
| 37019802 | Human coronavirus HKU1+OC43 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.967 |  |  0 |       0 |
| 1259564 | Norovirus genogroup II Ag [Presence] in Stool | 0.965 |  |  0 |       0 |
| 3042198 | Norovirus genogroup I Ag [Presence] in Stool | 0.963 |  |  0 |       0 |
| 36305676 | Human coronavirus HKU1 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.960 |  |  0 |       0 |
| 3041642 | Human coronavirus 229E RNA [Presence] in Specimen by NAA with probe detection | 0.956 |  |  1 |   5,974 |
| 36304464 | Human coronavirus OC43 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.956 |  |  0 |       0 |
| 40765160 | Human coronavirus HKU1 RNA [Presence] in Specimen by NAA with probe detection | 0.953 |  |  0 |       0 |
| 3038546 | Human coronavirus OC43 RNA [Presence] in Specimen by NAA with probe detection | 0.952 |  |  1 |   5,976 |
| 36304601 | Human coronavirus 229E RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.951 |  |  0 |       0 |
| 36304548 | Human coronavirus NL63 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.950 |  |  0 |       0 |
| 40759848 | Cladosporium cladosporioides IgE Ab [Units/volume] in Serum | 0.949 |  |  0 |       0 |
| 3040359 | Human coronavirus NL63 RNA [Presence] in Specimen by NAA with probe detection | 0.948 |  |  1 |   5,974 |
| 3042514 | Cladosporium sp IgE Ab [Units/volume] in Serum | 0.947 |  |  0 |       0 |
| 36305349 | Human coronavirus HKU1 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.946 |  |  0 |       0 |
| 3009466 | Valproate [Moles/volume] in Serum or Plasma | 0.944 | 408 |  4 |  37,442 |
| 3042123 | Cladosporium herbarum IgG Ab [Presence] in Serum | 0.944 |  |  0 |       0 |
| 1092421 | Human coronavirus OC43 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.943 |  |  0 |       0 |
| 3006832 | Cladosporium herbarum IgG Ab [Units/volume] in Serum | 0.943 |  |  0 |       0 |
| 36304330 | Human coronavirus 229E RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.942 |  |  0 |       0 |
| 1091709 | Human coronavirus NL63 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.942 |  |  0 |       0 |
| 3019084 | Cladosporium sphaerospermum IgE Ab [Units/volume] in Serum | 0.941 | 1809 |  0 |       0 |
| 36305656 | Human coronavirus NL63 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.941 |  |  0 |       0 |
| 3045260 | Cladosporium sp IgE Ab [Presence] in Serum | 0.939 |  |  0 |       0 |
| 36304961 | Human coronavirus OC43 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.938 |  |  0 |       0 |
| 646724 | Human coronavirus 229E RNA [Presence] in Specimen by NAA with non-probe detection | 0.938 |  |  0 |       0 |
| 647567 | Cladosporium herbarum IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.936 |  |  0 |       0 |
| 36660491 | Human coronavirus 229E RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.935 |  |  0 |       0 |
| 36660364 | Human coronavirus OC43 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.935 |  |  0 |       0 |
| 36659667 | Human coronavirus HKU1 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.935 |  |  0 |       0 |
| 645895 | Human coronavirus HKU1 RNA [Presence] in Specimen by NAA with non-probe detection | 0.935 |  |  0 |       0 |
| 36660329 | Human coronavirus NL63 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.932 |  |  0 |       0 |
| 3025848 | Cobalt [Moles/volume] in Blood | 0.932 |  |  0 |       0 |
| 645449 | Human coronavirus OC43 RNA [Presence] in Specimen by NAA with non-probe detection | 0.932 |  |  0 |       0 |
| 3038057 | Cladosporium herbarum IgM Ab [Units/volume] in Serum | 0.931 |  |  0 |       0 |
| 1091342 | Human coronavirus HKU1 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.929 |  |  0 |       0 |
| 3023355 | Cladosporium herbarum IgG4 Ab [Units/volume] in Serum | 0.928 |  |  0 |       0 |
| 1091933 | Human coronavirus OC43 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.928 |  |  0 |       0 |
| 3019531 | Acetone [Mass/volume] in Serum or Plasma | 0.926 |  |  0 |       0 |
| 646769 | Human coronavirus NL63 RNA [Presence] in Specimen by NAA with non-probe detection | 0.923 |  |  0 |       0 |
| 1091866 | Human coronavirus NL63 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.923 |  |  0 |       0 |
| 40764010 | Cladosporium herbarum IgE Ab/IgE total in Serum | 0.921 |  |  0 |       0 |
| 3037556 | Urate [Mass/volume] in Serum or Plasma | 0.921 |  |  0 |       0 |
| 36305386 | Human coronavirus HKU1 RNA [Presence] in Aspirate by NAA with probe detection | 0.915 |  |  0 |       0 |
| 36303607 | Human coronavirus 229E RNA [Presence] in Aspirate by NAA with probe detection | 0.910 |  |  0 |       0 |
| 40767678 | Cladosporium herbarum recombinant (rCla h) 8 IgE Ab [Units/volume] in Serum | 0.910 |  |  0 |       0 |
| 40763125 | Cobalt [Mass/volume] in Red Blood Cells | 0.910 |  |  0 |       0 |
| 21493147 | Human coronavirus 229E RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.909 |  |  0 |       0 |
| 3031825 | Cladosporium sp IgG Ab [Presence] in Serum | 0.903 |  |  0 |       0 |
| 3037286 | Acetone [Presence] in Serum or Plasma by Screen method | 0.900 | 1801 |  0 |       0 |
| 646956 | Acetone [Measurement] in Serum or Plasma | 0.898 |  |  0 |       0 |
| 3042090 | Cladosporium cladosporioides IgG Ab [Presence] in Serum | 0.898 |  |  0 |       0 |
| 3035526 | Acetoacetate [Moles/volume] in Serum or Plasma | 0.897 |  |  0 |       0 |
| 3031021 | Cobalt [Mass/volume] in Body fluid | 0.897 |  |  0 |       0 |
| 3028447 | Cobalt [Mass/volume] in Serum or Plasma | 0.896 |  |  0 |       0 |
| 3965635 | Cladosporium herbarum IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.894 |  |  0 |       0 |
| 3016201 | Valproate [Mass/volume] in Serum or Plasma | 0.892 |  |  0 |       0 |
| 1091339 | Norovirus genogroup I+II RNA [Presence] in Specimen | 0.888 |  |  0 |       0 |
| 37019810 | Chlamydia trachomatis and Neisseria gonorrhoeae and Trichomonas vaginalis DNA panel - Urine by NAA with probe detection | 0.888 |  |  0 |       0 |
| 3028566 | Urate [Moles/volume] in Specimen | 0.886 |  |  0 |       0 |
| 42868635 | Chlamydia trachomatis and Neisseria gonorrhoeae rRNA panel - Urine by NAA with probe detection | 0.886 |  |  0 |       0 |
| 46236265 | Chlamydia trachomatis and Neisseria gonorrhoeae DNA panel - Urethra by NAA with probe detection | 0.885 |  |  0 |       0 |
| 647936 | Urate [Measurement] in Serum or Plasma | 0.884 |  |  0 |       0 |
| 40758035 | Norovirus genogroup I RNA [Presence] in Stool by NAA with probe detection | 0.879 |  |  0 |       0 |
| 40758036 | Norovirus genogroup II RNA [Presence] in Stool by NAA with probe detection | 0.879 |  |  0 |       0 |
| 3964590 | Cladosporium herbarum IgG4 Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.877 |  |  0 |       0 |
| 3024085 | Cobalt [Mass/volume] in Urine | 0.876 |  |  0 |       0 |
| 3001791 | Acetoacetate [Presence] in Serum or Plasma | 0.875 |  |  0 |       0 |
| 37019702 | Norovirus genogroup I+II RNA [Presence] in Stool by NAA with probe detection | 0.875 |  |  0 |       0 |
| 3022915 | Valproate Free [Moles/volume] in Serum or Plasma | 0.875 |  |  0 |       0 |
| 3027874 | Urate [Moles/volume] in Urine | 0.874 | 1405 |  4 |     183 |
| 3033714 | Cladosporium herbarum IgG Ab [Mass/volume] in Serum | 0.873 |  |  0 |       0 |
| 21493479 | Norovirus genogroup I+II RNA [Presence] in Stool by NAA with non-probe detection | 0.872 |  |  0 |       0 |
| 3046994 | Cladosporium herbarum Ab [Presence] in Serum by Immune diffusion (ID) | 0.870 |  |  0 |       0 |
| 46234794 | Acetone [Moles/volume] in Blood | 0.866 |  |  0 |       0 |
| 3044280 | Acetone [Presence] in Blood | 0.865 |  |  0 |       0 |
| 43055688 | Chlamydia trachomatis and Neisseria gonorrhoeae DNA panel - Specimen | 0.864 |  |  0 |       0 |
| 3004527 | Acetone [Presence] in Specimen | 0.861 |  |  0 |       0 |
| 3008520 | Urate [Moles/volume] in Body fluid | 0.858 |  |  0 |       0 |
| 42868636 | Chlamydia trachomatis and Neisseria gonorrhoeae rRNA panel - Urethra by NAA with probe detection | 0.858 |  |  0 |       0 |
| 3002322 | Acetone [Moles/volume] in Specimen | 0.857 |  |  0 |       0 |
| 3019205 | Cobalt [Mass/volume] in Specimen | 0.856 |  |  0 |       0 |
| 3022033 | Acetone [Presence] in Body fluid | 0.856 |  |  0 |       0 |
| 36031325 | Chlamydia trachomatis and Neisseria gonorrhoeae and Trichomonas vaginalis DNA panel - Specimen by NAA with probe detection | 0.855 |  |  0 |       0 |
| 3029311 | Acetone [Moles/volume] in Body fluid | 0.855 |  |  0 |       0 |
| 3035132 | Ketones [Presence] in Serum or Plasma | 0.853 | 1276 |  0 |       0 |
| 40768790 | Lung Pathology biopsy report | 0.852 |  |  0 |       0 |
| 21492666 | Norovirus genogroup I+II orf1-orf2 junction region [Presence] in Stool by NAA with probe detection | 0.851 |  |  0 |       0 |
| 42870622 | 2-Methylacetoacetate [Moles/volume] in Serum or Plasma | 0.851 |  |  0 |       0 |
| 3029348 | Methyl ethyl ketone [Moles/volume] in Serum or Plasma | 0.851 |  |  0 |       0 |
| 3019518 | Acetone [Presence] in Urine | 0.850 | 473 |  0 |       0 |
| 3020779 | Urea [Moles/volume] in Serum or Plasma | 0.845 |  | 17 | 315,788 |
| 3029886 | Cobalt [Moles/volume] in Red Blood Cells | 0.844 |  |  0 |       0 |
| 3021311 | Cobalt [Moles/volume] in Serum or Plasma | 0.844 |  |  0 |       0 |
| 3052592 | Norovirus Ag [Presence] in Stool | 0.843 |  |  1 |   1,048 |
| 46235167 | Norovirus genogroup I and II RNA [Identifier] in Stool by NAA with probe detection | 0.843 |  |  0 |       0 |
| 1616915 | Norovirus genogroup II RNA [Presence] in Specimen by NAA with probe detection | 0.841 |  |  0 |       0 |
| 1616677 | Norovirus genogroup I RNA [Presence] in Specimen by NAA with probe detection | 0.840 |  |  0 |       0 |
| 40768443 | Skin Pathology biopsy report | 0.840 | 1793 |  1 |  24,633 |
| 40761050 | Cobalt [Mass/volume] in Cerebral spinal fluid | 0.838 |  |  0 |       0 |
| 37021472 | Chlamydia trachomatis and Neisseria gonorrhoeae and Trichomonas vaginalis DNA panel - Genital specimen by NAA with probe detection | 0.836 |  |  0 |       0 |
| 3022620 | Valproate [Mass/volume] in Serum or Plasma --trough | 0.836 |  |  0 |       0 |
| 40766734 | Chlamydia trachomatis and Neisseria gonorrhoeae rRNA panel - Specimen by NAA with probe detection | 0.835 |  |  0 |       0 |
| 40768803 | Thyroid Pathology biopsy report | 0.835 |  |  0 |       0 |
| 3012713 | Urate [Moles/volume] in 24 hour Urine | 0.833 |  |  0 |       0 |
| 40768793 | Breast Pathology biopsy report | 0.833 |  |  2 |  13,464 |
| 42868638 | Chlamydia trachomatis and Neisseria gonorrhoeae rRNA panel - Vaginal fluid by NAA with probe detection | 0.832 | 3000 |  0 |       0 |
| 1091701 | Chlamydia trachomatis and Neisseria gonorrhoeae and Trichomonas vaginalis rRNA panel - Vagina by NAA with probe detection | 0.829 |  |  0 |       0 |
| 3042301 | Urate [Moles/volume] in Synovial fluid | 0.828 |  |  3 |      83 |
| 21491327 | Allopurinol [Moles/volume] in Serum or Plasma | 0.828 |  |  0 |       0 |
| 3021600 | Valproate Free [Mass/volume] in Serum or Plasma | 0.822 |  |  0 |       0 |
| 40768795 | Lymph node Pathology biopsy report | 0.812 |  |  2 |   5,290 |
| 43533702 | Valproate [Mass/volume] in Serum or Plasma --peak | 0.810 |  |  0 |       0 |
| 40768792 | Brain Pathology biopsy report | 0.809 |  |  0 |       0 |
| 40768796 | Uterus Pathology biopsy report | 0.807 |  |  0 |       0 |
| 40768446 | Kidney Pathology biopsy report | 0.801 | 1790 |  1 |   3,432 |
| 40758651 | Acetazolamide [Moles/volume] in Serum or Plasma | 0.801 |  |  0 |       0 |
| 40768799 | Ovary Pathology biopsy report | 0.799 |  |  0 |       0 |
| 3020485 | Acetaminophen [Moles/volume] in Serum or Plasma | 0.785 | 402 |  3 |   5,169 |
| 40759345 | Cladosporium herbarum IgG4 Ab [Mass/volume] in Serum | 0.784 |  |  0 |       0 |
| 3019779 | Phenytoin [Moles/volume] in Serum or Plasma | 0.784 | 356 |  3 |   1,716 |
| 3022515 | Vigabatrin [Moles/volume] in Serum or Plasma | 0.783 |  |  0 |       0 |
| 646011 | Cladosporium herbarum IgG Ab [Measurement] in Serum | 0.774 |  |  0 |       0 |
| 647909 | Urate [Measurement] in Urine | 0.773 |  |  0 |       0 |
| 3041618 | Xanthurenate [Presence] in Serum or Plasma | 0.766 |  |  0 |       0 |
| 3006087 | Urate [Presence] in Stone | 0.762 |  |  0 |       0 |
| 1989097 | Urate [Mass/volume] in Blood | 0.760 |  |  0 |       0 |
| 3014223 | Ornithine [Presence] in Serum or Plasma | 0.755 |  |  0 |       0 |
| 3033526 | Urate [Mass/volume] in Urine | 0.754 |  |  0 |       0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1241 | -aerobivi |  | 314 | 100 |  |  |  |  |  | FALSE |
| 1242 | -anaerobi |  | 320 | 100 |  |  |  |  |  | FALSE |
| 1243 | -omactgc |  | 591 | 100 |  |  |  |  |  | FALSE |
| 1244 | annosvoim |  | 182 | 65.93 |  |  |  |  |  | FALSE |
| 1245 | b-koboltti | ug/l | 157 | 0 | [0.5, 0.72, 0.96, 1.18, 1.68, 2.2, 3.97, 6.08, 10.46] |  | Blood |  | Cobalt [Mass/volume] in Blood | FALSE |
| 1246 | cand-odl. |  | 542 | 89.67 |  |  |  |  |  | FALSE |
| 1247 | cand.nativ |  | 286 | 100 |  |  |  |  |  | FALSE |
| 1248 | cladosp.he | mm | 11 | 0 |  |  |  |  | Cladosporium herbarum IgE Ab response to skin test | FALSE |
| 1249 | cladosp.he | u/ml | 69 | 0 | [0, 0.01, 0.01, 0.04, 0.13, 0.41, 0.5, 0.87, 4.4] |  |  |  | Cladosporium herbarum Ab.IgE [Units/volume] in Serum | FALSE |
| 1250 | cladosp.he |  | 680 | 93.82 |  |  |  |  | Cladosporium herbarum Ab.IgE [Presence] in Serum | FALSE |
| 1251 | corona229e |  | 619 | 100 |  |  |  |  | Human coronavirus 229E RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1252 | coronahku1 |  | 619 | 100 |  |  |  |  | Human coronavirus HKU1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1253 | coronanl63 |  | 619 | 100 |  |  |  |  | Human coronavirus NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1254 | coronaoc43 |  | 619 | 100 |  |  |  |  | Human coronavirus OC43 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1255 | f-norogi |  | 261 | 100 |  |  | Feces |  | Norovirus genogroup I [Presence] in Stool | FALSE |
| 1256 | f-norogii |  | 261 | 100 |  |  | Feces |  | Norovirus genogroup II [Presence] in Stool | FALSE |
| 1257 | f-projekti |  | 469 | 100 |  |  | Feces |  |  | FALSE |
| 1258 | hpvpapctgc |  | 116 | 100 |  |  |  |  |  | FALSE |
| 1259 | hpvrefctgc |  | 135 | 100 |  |  |  |  |  | FALSE |
| 1260 | norogi |  | 139 | 100 |  |  |  |  |  | FALSE |
| 1261 | norogii |  | 139 | 100 |  |  |  |  |  | FALSE |
| 1262 | p-asetoni | mmol/l | 171 | 0 | [0, 0, 0, 0, 0, 0, 0.99, 1.7, 3.4] |  | Plasma |  | Acetone [Moles/volume] in Serum or Plasma | FALSE |
| 1263 | p-asetoni |  | 305 | 100 |  |  | Plasma |  | Acetone [Presence] in Serum or Plasma | FALSE |
| 1264 | p-uraatti | umol/l | 6902 | 0 | [234.14, 271.61, 301.37, 327.94, 355.71, 383.49, 416.66, 458.38, 518.94] |  | Plasma |  | Urate [Moles/volume] in Serum or Plasma | FALSE |
| 1265 | p-uraatti |  | 32 | 87.5 |  |  | Plasma |  | Urate [Presence] in Serum or Plasma | FALSE |
| 1266 | projekti1 |  | 160 | 100 |  |  |  |  |  | FALSE |
| 1267 | s-asetoni | mmol/l | 42 | 0 |  | S -Asetoni | Serum |  | Acetone [Moles/volume] in Serum or Plasma | FALSE |
| 1268 | s-asetoni |  | 414 | 100 |  | S -Asetoni | Serum |  | Acetone [Presence] in Serum or Plasma | FALSE |
| 1269 | s-uraatti | umol/l | 621 | 0 | [231.75, 257.74, 279.08, 298.35, 317.34, 343.64, 366.52, 401.97, 449.54] |  | Serum |  | Urate [Moles/volume] in Serum or Plasma | FALSE |
| 1270 | s-uraatti |  | 38 | 100 |  |  | Serum |  | Urate [Presence] in Serum or Plasma | FALSE |
| 1271 | s-valproaatti | umol/l | 431 | 0 | [243.85, 308.03, 356.19, 396.72, 425.61, 467.25, 503.69, 550.21, 628.49] |  | Serum |  | Valproic acid [Moles/volume] in Serum or Plasma | FALSE |
| 1272 | s-valproaatti |  | 16 | 87.5 |  |  | Serum |  | Valproic acid [Moles/volume] in Serum or Plasma | FALSE |
| 1273 | ts-abortti |  | 315 | 100 |  | Ts-Aborttikudoksen dissektiotutkimus | Tissue |  | Tissue Pathology biopsy report | FALSE |
| 1274 | u-omactgc |  | 480 | 100 |  |  | Urine |  | Chlamydia trachomatis and Neisseria gonorrhoeae DNA and RNA panel - Urine | TRUE |
| 1275 | uraatti | umol/l | 3560 | 0 | [230.56, 267.35, 298.53, 325.87, 354.19, 383.04, 414.66, 454.9, 512.27] |  |  |  | Urate [Moles/volume] in Serum or Plasma | FALSE |
| 1276 | uraatti |  | 19 | 100 |  |  |  |  | Urate [Presence] in Serum or Plasma | FALSE |

