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
Here is group 74.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1092116 | Bacteria DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  | 0 |      0 |
| 1616933 | Salmonella sp DNA [Presence] in Stool by NAA with probe detection | 1.000 |  | 0 |      0 |
| 3015822 | Parvovirus B19 DNA [Presence] in Serum by NAA with probe detection | 1.000 |  | 1 |    207 |
| 3032674 | Salmonella sp DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  | 0 |      0 |
| 3033060 | Aspergillus sp DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  | 0 |      0 |
| 37020160 | Bordetella pertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |      0 |
| 37021179 | Bordetella parapertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |      0 |
| 3028372 | Borrelia burgdorferi DNA [Presence] in Specimen by NAA with probe detection | 0.971 | 1877 | 0 |      0 |
| 3032435 | Parvovirus B19 DNA [Presence] in Blood by NAA with probe detection | 0.969 |  | 0 |      0 |
| 3965970 | Human coronavirus 229E RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.967 |  | 0 |      0 |
| 40765215 | Aspergillus fumigatus DNA [Presence] in Specimen by NAA with probe detection | 0.966 |  | 0 |      0 |
| 40764131 | Salmonella enterica DNA [Presence] in Specimen by NAA with probe detection | 0.962 |  | 0 |      0 |
| 3966673 | Human coronavirus OC43 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.962 |  | 0 |      0 |
| 3964787 | Human coronavirus HKU1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.961 |  | 0 |      0 |
| 37021321 | Human bocavirus 1+2+3 DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.958 |  | 0 |      0 |
| 1091614 | Aspergillus clavatus DNA [Presence] in Specimen by NAA with probe detection | 0.958 |  | 0 |      0 |
| 37019602 | Bordetella parapertussis DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.955 |  | 0 |      0 |
| 36305655 | Human bocavirus DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.955 |  | 0 |      0 |
| 3037875 | Bordetella parapertussis DNA [Presence] in Specimen by NAA with probe detection | 0.954 |  | 1 |  3,745 |
| 1469897 | Bordetella parapertussis DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.953 |  | 0 |      0 |
| 42869862 | Sapovirus RNA [Presence] in Specimen by NAA with probe detection | 0.953 |  | 0 |      0 |
| 3009121 | Parvovirus B19 DNA [Presence] in Specimen by NAA with probe detection | 0.952 |  | 0 |      0 |
| 1469600 | Bordetella pertussis DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.951 |  | 0 |      0 |
| 3965395 | Human coronavirus NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.951 |  | 0 |      0 |
| 3012477 | Bordetella pertussis DNA [Presence] in Specimen by NAA with probe detection | 0.951 |  | 1 | 12,026 |
| 40765161 | Human bocavirus DNA [Presence] in Specimen by NAA with probe detection | 0.949 |  | 2 | 13,049 |
| 37020862 | Bordetella pertussis DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.949 |  | 0 |      0 |
| 3965131 | Sapovirus genogroup V RNA [Presence] in Stool by NAA with probe detection | 0.949 |  | 0 |      0 |
| 3023950 | Parvovirus B19 RNA [Presence] in Blood by NAA with probe detection | 0.947 |  | 0 |      0 |
| 648686 | Borrelia sp DNA [Presence] in Specimen by NAA with probe detection | 0.944 |  | 0 |      0 |
| 1091764 | Bordetella parapertussis DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.942 |  | 0 |      0 |
| 37020776 | Human coronavirus 229E+NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.942 |  | 0 |      0 |
| 1761619 | Aspergillus sp DNA [Presence] in Blood by NAA with probe detection | 0.940 |  | 0 |      0 |
| 36303776 | Human bocavirus DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.939 |  | 0 |      0 |
| 1176020 | Aspergillus sp DNA [Presence] in Tissue by NAA with probe detection | 0.939 |  | 0 |      0 |
| 36659767 | Bordetella pertussis DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.938 |  | 0 |      0 |
| 1259587 | Human bocavirus DNA [Presence] in Upper respiratory specimen by NAA with non-probe detection | 0.938 |  | 0 |      0 |
| 1091413 | Aspergillus flavus DNA [Presence] in Specimen by NAA with probe detection | 0.937 |  | 0 |      0 |
| 1176455 | Aspergillus sp DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.937 |  | 0 |      0 |
| 1469496 | Human bocavirus DNA [Presence] in Sputum by NAA with probe detection | 0.933 |  | 0 |      0 |
| 3029274 | Parvovirus B19 DNA [Presence] in Body fluid by NAA with probe detection | 0.933 |  | 0 |      0 |
| 40765216 | Aspergillus terreus DNA [Presence] in Specimen by NAA with probe detection | 0.931 |  | 0 |      0 |
| 3964934 | Sapovirus genogroups I+II+IV RNA [Presence] in Stool by NAA with probe detection | 0.930 |  | 0 |      0 |
| 646396 | Aspergillus sp DNA [#/volume] in Specimen by NAA with probe detection | 0.930 |  | 0 |      0 |
| 3034972 | Bordetella parapertussis DNA [Presence] in Nasopharynx by NAA with probe detection | 0.929 |  | 0 |      0 |
| 37019802 | Human coronavirus HKU1+OC43 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.928 |  | 0 |      0 |
| 36304464 | Human coronavirus OC43 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.927 |  | 0 |      0 |
| 3041642 | Human coronavirus 229E RNA [Presence] in Specimen by NAA with probe detection | 0.926 |  | 1 |  5,974 |
| 1092055 | Human bocavirus DNA [Presence] in Nasopharynx by NAA with probe detection | 0.925 |  | 0 |      0 |
| 21493467 | Salmonella enterica+bongori DNA [Presence] in Stool by NAA with non-probe detection | 0.924 |  | 0 |      0 |
| 37020957 | Sapovirus genogroups I+II+IV+V RNA [Presence] in Stool by NAA with probe detection | 0.924 |  | 1 |  3,731 |
| 36304601 | Human coronavirus 229E RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.923 |  | 0 |      0 |
| 1091135 | Borreliella sp DNA [Presence] in Specimen by NAA with probe detection | 0.922 |  | 0 |      0 |
| 3025310 | Parvovirus B19 RNA [Presence] in Specimen by NAA with probe detection | 0.922 |  | 0 |      0 |
| 3032785 | Parvovirus B19 DNA [Presence] in Bone marrow by NAA with probe detection | 0.922 |  | 0 |      0 |
| 21492661 | Salmonella sp rpoD gene [Presence] in Stool by NAA with probe detection | 0.921 |  | 0 |      0 |
| 3038546 | Human coronavirus OC43 RNA [Presence] in Specimen by NAA with probe detection | 0.921 |  | 1 |  5,976 |
| 3028977 | Parvovirus B19 DNA [Presence] in Urine by NAA with probe detection | 0.920 |  | 0 |      0 |
| 3047117 | Bordetella pertussis DNA [Presence] in Nasopharynx by NAA with probe detection | 0.920 |  | 0 |      0 |
| 1091349 | Aspergillus niger DNA [Presence] in Specimen by NAA with probe detection | 0.919 |  | 0 |      0 |
| 36305676 | Human coronavirus HKU1 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.917 |  | 0 |      0 |
| 37020168 | Bordetella pertussis DNA [Presence] in Throat by NAA with probe detection | 0.917 |  | 0 |      0 |
| 36304330 | Human coronavirus 229E RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.917 |  | 0 |      0 |
| 3024482 | Parvovirus B19 RNA [Presence] in Tissue by NAA with probe detection | 0.917 |  | 0 |      0 |
| 36204249 | Human bocavirus DNA [Presence] in Tissue by NAA with probe detection | 0.916 |  | 0 |      0 |
| 3966166 | Staphylococcus aureus DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.915 |  | 0 |      0 |
| 1092421 | Human coronavirus OC43 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.915 |  | 0 |      0 |
| 21493559 | Salmonella sp invA+fliC genes [Presence] in Stool by NAA with probe detection | 0.911 |  | 0 |      0 |
| 21493481 | Sapovirus genogroups I+II+IV+V RNA [Presence] in Stool by NAA with non-probe detection | 0.911 |  | 0 |      0 |
| 3007217 | Salmonella pullorum DNA [Presence] in Specimen by NAA with probe detection | 0.911 |  | 0 |      0 |
| 40765160 | Human coronavirus HKU1 RNA [Presence] in Specimen by NAA with probe detection | 0.911 |  | 0 |      0 |
| 36304548 | Human coronavirus NL63 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.910 |  | 0 |      0 |
| 36304961 | Human coronavirus OC43 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.910 |  | 0 |      0 |
| 36305656 | Human coronavirus NL63 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.909 |  | 0 |      0 |
| 36660491 | Human coronavirus 229E RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.909 |  | 0 |      0 |
| 1001596 | Salmonella sp DNA [Presence] by NAA with probe detection in Positive blood culture | 0.908 |  | 0 |      0 |
| 21493883 | Salmonella sp spaO gene [Presence] in Stool by NAA with probe detection | 0.908 |  | 0 |      0 |
| 1091951 | Staphylococcus sp DNA [Presence] in Specimen by NAA with probe detection | 0.907 |  | 0 |      0 |
| 36305349 | Human coronavirus HKU1 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.907 |  | 0 |      0 |
| 36660364 | Human coronavirus OC43 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.906 |  | 0 |      0 |
| 46234881 | Bacterial 16S rRNA [Presence] in Specimen by NAA with probe detection | 0.906 |  | 0 |      0 |
| 646724 | Human coronavirus 229E RNA [Presence] in Specimen by NAA with non-probe detection | 0.905 |  | 0 |      0 |
| 3015220 | Salmonella gallinarum DNA [Presence] in Specimen by NAA with probe detection | 0.904 |  | 0 |      0 |
| 3040359 | Human coronavirus NL63 RNA [Presence] in Specimen by NAA with probe detection | 0.903 |  | 1 |  5,974 |
| 645449 | Human coronavirus OC43 RNA [Presence] in Specimen by NAA with non-probe detection | 0.902 |  | 0 |      0 |
| 1091185 | Human bocavirus 1+2+3+4 DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.902 |  | 0 |      0 |
| 3008909 | Norovirus RNA [Presence] in Stool by NAA with probe detection | 0.902 |  | 1 | 17,197 |
| 1091709 | Human coronavirus NL63 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.902 |  | 0 |      0 |
| 46235156 | Parvovirus B19 DNA [Presence] in Plasma from Donor by NAA with probe detection | 0.900 |  | 0 |      0 |
| 3044820 | Borrelia burgdorferi DNA [Presence] in Blood by NAA with probe detection | 0.900 |  | 0 |      0 |
| 36660329 | Human coronavirus NL63 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.900 |  | 0 |      0 |
| 40764159 | Escherichia coli DNA [Presence] in Specimen by NAA with probe detection | 0.899 |  | 0 |      0 |
| 37020998 | Streptococcus pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.899 |  | 0 |      0 |
| 1091933 | Human coronavirus OC43 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.898 |  | 0 |      0 |
| 36659667 | Human coronavirus HKU1 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.898 |  | 0 |      0 |
| 3966163 | Shigella sp DNA [Presence] in Stool by NAA with probe detection | 0.897 |  | 0 |      0 |
| 40764165 | Staphylococcus aureus DNA [Presence] in Specimen by NAA with probe detection | 0.897 |  | 0 |      0 |
| 1988730 | Neisseria meningitidis DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.895 |  | 0 |      0 |
| 36305477 | Microsporidia DNA [Presence] in Stool by NAA with probe detection | 0.895 |  | 0 |      0 |
| 645895 | Human coronavirus HKU1 RNA [Presence] in Specimen by NAA with non-probe detection | 0.895 |  | 0 |      0 |
| 3966671 | Aeromonas sp DNA [Presence] in Stool by NAA with probe detection | 0.895 |  | 0 |      0 |
| 37020598 | Moraxella catarrhalis DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.894 |  | 0 |      0 |
| 37020300 | Entamoeba histolytica DNA [Presence] in Stool by NAA with probe detection | 0.892 |  | 1 |  2,336 |
| 36032369 | Salmonella sp DNA [Presence] by NAA with non-probe detection in Positive blood culture | 0.892 |  | 0 |      0 |
| 1469493 | Salmonella sp DNA [Presence] in Body fluid by NAA with non-probe detection | 0.892 |  | 0 |      0 |
| 1259661 | Salmonella paratyphi DNA [Presence] in Isolate by NAA with probe detection | 0.891 |  | 0 |      0 |
| 1091342 | Human coronavirus HKU1 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.891 |  | 0 |      0 |
| 36304443 | Parechovirus RNA [Presence] in Stool by NAA with probe detection | 0.890 |  | 0 |      0 |
| 1988643 | Escherichia coli K1 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.889 |  | 0 |      0 |
| 3030429 | Borrelia sp DNA [Identifier] in Specimen by NAA with probe detection | 0.888 |  | 1 |  1,758 |
| 42868767 | Plesiomonas shigelloides DNA [Presence] in Stool by NAA with probe detection | 0.888 |  | 0 |      0 |
| 3035492 | Borrelia burgdorferi DNA [Presence] in Tissue by NAA with probe detection | 0.888 |  | 0 |      0 |
| 1260098 | Salmonella typhi DNA [Presence] in Isolate by NAA with probe detection | 0.888 |  | 0 |      0 |
| 1092209 | Streptococcus sp DNA [Presence] in Specimen by NAA with probe detection | 0.887 |  | 0 |      0 |
| 1988894 | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.887 |  | 0 |      0 |
| 706165 | SARS-related coronavirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.886 |  | 0 |      0 |
| 21493148 | Human coronavirus OC43 RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.886 |  | 0 |      0 |
| 3035833 | XXX microorganism DNA [Presence] in Specimen by NAA with probe detection | 0.884 | 279 | 0 |      0 |
| 37020262 | Human coronavirus 229E+HKU1+NL63+OC43 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.884 |  | 0 |      0 |
| 1091866 | Human coronavirus NL63 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.883 |  | 0 |      0 |
| 3001391 | Mycobacterium sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.883 |  | 0 |      0 |
| 36031318 | Borrelia sp DNA [Presence] in Blood by NAA with probe detection | 0.883 |  | 0 |      0 |
| 1259851 | Entamoeba coli DNA [Presence] in Stool by NAA with probe detection | 0.882 |  | 0 |      0 |
| 37020058 | Rotavirus A RNA [Presence] in Stool by NAA with probe detection | 0.882 |  | 0 |      0 |
| 1469649 | Campylobacter sp DNA [Presence] in Stool by NAA with probe detection | 0.881 |  | 0 |      0 |
| 3000499 | Borrelia burgdorferi DNA [Presence] in Urine by NAA with probe detection | 0.881 |  | 0 |      0 |
| 3028815 | Burkholderia sp DNA [Presence] in Specimen by NAA with probe detection | 0.881 |  | 0 |      0 |
| 1259863 | Entamoeba hartmanni DNA [Presence] in Stool by NAA with probe detection | 0.881 |  | 0 |      0 |
| 3029113 | Borrelia burgdorferi DNA [Presence] in Tick by NAA with probe detection | 0.881 |  | 0 |      0 |
| 1091141 | Micrococcus luteus DNA [Presence] in Specimen by NAA with probe detection | 0.881 |  | 0 |      0 |
| 647461 | Rotavirus RNA [Presence] in Stool by NAA with probe detection | 0.880 |  | 0 |      0 |
| 40764162 | Pseudomonas aeruginosa DNA [Presence] in Specimen by NAA with probe detection | 0.880 |  | 0 |      0 |
| 3027858 | Mycobacterium tuberculosis DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.880 |  | 0 |      0 |
| 646769 | Human coronavirus NL63 RNA [Presence] in Specimen by NAA with non-probe detection | 0.879 |  | 0 |      0 |
| 37020818 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with probe detection | 0.879 |  | 0 |      0 |
| 3964818 | Klebsiella pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.879 |  | 0 |      0 |
| 1988744 | Listeria monocytogenes DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.879 |  | 0 |      0 |
| 3965358 | Campylobacter coli DNA [Presence] in Stool by NAA with probe detection | 0.879 |  | 0 |      0 |
| 21493475 | Entamoeba histolytica DNA [Presence] in Stool by NAA with non-probe detection | 0.878 |  | 0 |      0 |
| 36305771 | Cryptosporidium sp DNA [Presence] in Stool by NAA with probe detection | 0.878 |  | 1 |  4,105 |
| 37019853 | Mycoplasma pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.878 |  | 0 |      0 |
| 1988899 | Streptococcus pneumoniae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.878 |  | 0 |      0 |
| 37020445 | Astrovirus RNA [Presence] in Stool by NAA with probe detection | 0.878 |  | 1 |  2,767 |
| 1616599 | Cyclospora cayetanensis DNA [Presence] in Stool by NAA with probe detection | 0.876 |  | 0 |      0 |
| 1469822 | Escherichia coli shiga-like toxin DNA [Presence] in Stool by NAA with probe detection | 0.875 |  | 0 |      0 |
| 37020101 | Chlamydophila pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.875 |  | 0 |      0 |
| 1617136 | Vibrio parahaemolyticus DNA [Presence] in Stool by NAA with probe detection | 0.875 |  | 0 |      0 |
| 1616308 | Escherichia coli enteropathogenic DNA [Presence] in Stool by NAA with probe detection | 0.875 |  | 0 |      0 |
| 40766195 | Brucella sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.875 |  | 0 |      0 |
| 3037610 | Borrelia burgdorferi DNA [Presence] in Body fluid by NAA with probe detection | 0.875 |  | 0 |      0 |
| 3031996 | Naegleria fowleri DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.875 |  | 0 |      0 |
| 1989596 | Streptococcus pyogenes DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.874 |  | 0 |      0 |
| 21493330 | Human coronavirus HKU1 RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.873 |  | 0 |      0 |
| 36305386 | Human coronavirus HKU1 RNA [Presence] in Aspirate by NAA with probe detection | 0.872 |  | 0 |      0 |
| 1175392 | Giardia sp DNA [Presence] in Stool by NAA with probe detection | 0.871 |  | 0 |      0 |
| 1092075 | Human bocavirus 1+2+3+4 DNA [Presence] in Bronchoalveolar lavage by NAA with probe detection | 0.871 |  | 0 |      0 |
| 36659989 | Staphylococcus aureus DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.866 |  | 0 |      0 |
| 42868763 | Blastocystis hominis DNA [Presence] in Stool by NAA with probe detection | 0.866 |  | 0 |      0 |
| 37020338 | Haemophilus influenzae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.865 |  | 0 |      0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1134 | -aspenho |  | 680 | 100 |  | -Aspergillus, nukleiinihappo (kval) |  |  | Aspergillus sp DNA [Presence] in Specimen by NAA with probe detection | FALSE |
| 1135 | -baktnho |  | 14771 | 100 |  | -Bakteeri, nukleiinihappo (kval) |  |  | Bacteria DNA [Presence] in Specimen by NAA with probe detection | FALSE |
| 1136 | -bocanho |  | 1008 | 100 |  |  |  |  | Human bocavirus DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1137 | -bokanho |  | 13005 | 100 |  | -Bokavirus, nukleiinihappo (kval) |  |  | Human bocavirus DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1138 | -bopanho |  | 1739 | 100 |  |  |  |  | Bordetella parapertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1139 | -bopenho |  | 12052 | 100 |  | -Bordetella pertussis, nukleiinihappo (kval) |  |  | Bordetella pertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1140 | -bopenho. |  | 1314 | 100 |  |  |  |  | Bordetella pertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1141 | -boppnho |  | 3753 | 100 |  |  |  |  | Bordetella pertussis+Bordetella parapertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1142 | -borrnho |  | 1762 | 100 |  | -Borrelia, nukleiinihappo (kval) |  |  | Borrelia burgdorferi group DNA [Presence] in Specimen by NAA with probe detection | FALSE |
| 1143 | -bparnho |  | 314 | 100 |  |  |  |  | Bordetella parapertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1144 | -rbaktnho |  | 4646 | 100 |  |  |  |  | Bacteria DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1145 | baktnho |  | 328 | 100 |  |  |  |  | Bacteria DNA [Presence] in Specimen by NAA with probe detection | FALSE |
| 1146 | bokanho |  | 222 | 100 |  |  |  |  | Human bocavirus DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1147 | bopenho |  | 608 | 100 |  |  |  |  | Bordetella pertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1148 | bparanho |  | 1650 | 100 |  |  |  |  | Bordetella parapertussis DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1149 | f-baktnho |  | 17469 | 100 |  |  | Feces |  | Bacteria DNA [Presence] in Stool by NAA with probe detection | FALSE |
| 1150 | f-paranho |  | 14240 | 99.99 |  | F -Parasiitit, nukleiinihappo (kval) | Feces |  | Protozoa DNA [Presence] in Stool by NAA with probe detection | FALSE |
| 1151 | f-salmnho |  | 2354 | 100 |  | F -Salmonella, nukleiinihappo (kval) | Feces |  | Salmonella sp DNA [Presence] in Stool by NAA with probe detection | FALSE |
| 1152 | f-saponho |  | 4057 | 100 |  | F -Sapovirus, nukleiinihappo (kval) | Feces |  | Sapovirus RNA [Presence] in Stool by NAA with probe detection | FALSE |
| 1153 | kv229enho |  | 5976 | 100 |  |  |  |  | Coronavirus 229E RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1154 | kvhku1nho |  | 537 | 100 |  |  |  |  | Coronavirus HKU1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1155 | kvnl63nho |  | 5975 | 100 |  |  |  |  | Coronavirus NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1156 | kvoc43nho |  | 5977 | 100 |  |  |  |  | Coronavirus OC43 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1157 | li-baktnho |  | 268 | 100 |  | Li-Bakteeri, nukleiinihappo (kval) | Cerebrospinal fluid |  | Bacteria DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 1158 | resbaktnho |  | 770 | 100 |  |  |  |  | Bacteria DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1159 | s-parvnho |  | 208 | 99.04 |  | S -Parvovirus, nukleiinihappo (kval) | Serum |  | Parvovirus B19 DNA [Presence] in Serum by NAA with probe detection | FALSE |
| 1160 | salmnho |  | 8183 | 100 |  |  |  |  | Salmonella sp DNA [Presence] in Specimen by NAA with probe detection | FALSE |

