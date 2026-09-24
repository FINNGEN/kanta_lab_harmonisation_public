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
Here is group 20.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1469649 | Campylobacter sp DNA [Presence] in Stool by NAA with probe detection | 1.000 |  |  0 |         0 |
| 1616933 | Salmonella sp DNA [Presence] in Stool by NAA with probe detection | 1.000 |  |  0 |         0 |
| 1988730 | Neisseria meningitidis DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  0 |         0 |
| 1988744 | Listeria monocytogenes DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  0 |         0 |
| 1988894 | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  0 |         0 |
| 1988899 | Streptococcus pneumoniae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  0 |         0 |
| 3011927 | Cytomegalovirus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  0 |         0 |
| 3016894 | Varicella zoster virus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  1 |     2,631 |
| 3023671 | Herpes simplex virus 1 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  0 |         0 |
| 3033564 | Herpes simplex virus 2 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  0 |         0 |
| 3044889 | 12 lead EKG panel | 1.000 |  |  2 | 1,163,408 |
| 37020818 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with probe detection | 1.000 |  |  0 |         0 |
| 42868767 | Plesiomonas shigelloides DNA [Presence] in Stool by NAA with probe detection | 1.000 |  |  0 |         0 |
| 3008733 | Herpes simplex virus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.989 |  |  1 |     2,923 |
| 3002781 | Herpes simplex virus 1+2 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.981 |  |  0 |         0 |
| 21493357 | Herpes simplex virus 2 DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.978 |  |  0 |         0 |
| 21493350 | Listeria monocytogenes DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.977 |  |  0 |         0 |
| 21493354 | Varicella zoster virus DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.976 |  |  0 |         0 |
| 21493351 | Neisseria meningitidis DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.975 |  |  0 |         0 |
| 21493352 | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.973 |  |  0 |         0 |
| 21493356 | Herpes simplex virus 1 DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.972 |  |  0 |         0 |
| 21493353 | Streptococcus pneumoniae DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.970 |  |  0 |         0 |
| 42870368 | Campylobacter sp DNA.diarrheagenic [Presence] in Stool by NAA with probe detection | 0.970 |  |  0 |         0 |
| 21493466 | Plesiomonas shigelloides DNA [Presence] in Stool by NAA with non-probe detection | 0.969 |  |  1 |     7,786 |
| 21493470 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with non-probe detection | 0.968 |  |  0 |         0 |
| 3966289 | Campylobacter jejuni DNA [Presence] in Stool by NAA with probe detection | 0.967 |  |  0 |         0 |
| 21493355 | Cytomegalovirus DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.965 |  |  0 |         0 |
| 3965358 | Campylobacter coli DNA [Presence] in Stool by NAA with probe detection | 0.960 |  |  0 |         0 |
| 1988643 | Escherichia coli K1 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.957 |  |  0 |         0 |
| 1469726 | Herpes virus 7 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.953 |  |  0 |         0 |
| 3966224 | Campylobacter upsaliensis DNA [Presence] in Stool by NAA with probe detection | 0.950 |  |  0 |         0 |
| 1469822 | Escherichia coli shiga-like toxin DNA [Presence] in Stool by NAA with probe detection | 0.948 |  |  0 |         0 |
| 1092255 | Campylobacter sp DNA [Identifier] in Stool by NAA with probe detection | 0.948 |  |  0 |         0 |
| 40765218 | Herpes virus 6A DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.946 |  |  0 |         0 |
| 3046896 | Herpes virus 6 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.945 |  |  2 |     1,738 |
| 1091300 | Yersinia enterocolitica DNA [Presence] in Specimen by NAA with probe detection | 0.940 |  |  0 |         0 |
| 1092359 | Campylobacter sp DNA [Presence] in Specimen by NAA with probe detection | 0.940 |  |  0 |         0 |
| 1988916 | Cryptococcus gattii+neoformans DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.940 |  |  0 |         0 |
| 21492665 | Escherichia coli Stx2 toxin stx2 gene [Presence] in Stool by NAA with probe detection | 0.938 |  |  0 |         0 |
| 40765219 | Herpes virus 6B DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.938 |  |  0 |         0 |
| 1616645 | Escherichia coli enteroaggregative DNA [Presence] in Stool by NAA with probe detection | 0.938 |  |  0 |         0 |
| 1616308 | Escherichia coli enteropathogenic DNA [Presence] in Stool by NAA with probe detection | 0.937 |  |  0 |         0 |
| 21493348 | Escherichia coli K1 DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.936 |  |  0 |         0 |
| 21492664 | Escherichia coli Stx1 toxin stx1 gene [Presence] in Stool by NAA with probe detection | 0.936 |  |  0 |         0 |
| 1616367 | Campylobacter coli+jejuni+upsaliensis DNA [Presence] in Stool by NAA with probe detection | 0.935 |  |  0 |         0 |
| 36304546 | Varicella zoster virus DNA [Presence] in Body fluid by NAA with probe detection | 0.935 |  |  0 |         0 |
| 3032674 | Salmonella sp DNA [Presence] in Specimen by NAA with probe detection | 0.933 |  |  0 |         0 |
| 42868716 | Shigella species+EIEC invasion plasmid antigen H ipaH gene [Presence] in Stool by NAA with probe detection | 0.929 |  |  1 |     8,148 |
| 3042515 | Neisseria meningitidis DNA [Presence] in Blood by NAA with probe detection | 0.928 |  |  0 |         0 |
| 21493558 | Escherichia coli enterotoxigenic eltA+estB genes [Presence] in Stool by NAA with probe detection | 0.928 |  |  0 |         0 |
| 1175408 | Cryptococcus sp rRNA gene [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.926 |  |  0 |         0 |
| 21493560 | Escherichia coli Stx1 and Stx2 toxin stx1+stx2 genes [Presence] in Stool by NAA with probe detection | 0.925 |  |  0 |         0 |
| 21493467 | Salmonella enterica+bongori DNA [Presence] in Stool by NAA with non-probe detection | 0.924 |  |  0 |         0 |
| 21492663 | Yersinia enterocolitica recN gene [Presence] in Stool by NAA with probe detection | 0.922 |  |  0 |         0 |
| 3965777 | Cryptococcus neoformans DNA [Presence] in Specimen by NAA with probe detection | 0.922 |  |  0 |         0 |
| 1989596 | Streptococcus pyogenes DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.922 |  |  0 |         0 |
| 21492661 | Salmonella sp rpoD gene [Presence] in Stool by NAA with probe detection | 0.921 |  |  0 |         0 |
| 3030388 | Neisseria meningitidis DNA [Presence] in Specimen by NAA with probe detection | 0.921 |  |  0 |         0 |
| 3966163 | Shigella sp DNA [Presence] in Stool by NAA with probe detection | 0.921 |  |  0 |         0 |
| 649062 | Plesiomonas shigelloides and aeromonas sp DNA [Identifier] in Stool by NAA with probe detection | 0.920 |  |  0 |         0 |
| 3000384 | Varicella zoster virus DNA [Presence] in Serum by NAA with probe detection | 0.919 |  |  0 |         0 |
| 3005197 | Varicella zoster virus DNA [Presence] in Blood by NAA with probe detection | 0.918 |  |  0 |         0 |
| 36303825 | Escherichia coli eaeA gene [Presence] in Stool by NAA with probe detection | 0.916 |  |  0 |         0 |
| 36204312 | Varicella zoster virus DNA [Presence] in Amniotic fluid by NAA with probe detection | 0.915 |  |  0 |         0 |
| 1761458 | Varicella zoster virus DNA [Log #/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.914 |  |  0 |         0 |
| 3038874 | Streptococcus pneumoniae DNA [Presence] in Blood by NAA with probe detection | 0.914 |  |  0 |         0 |
| 1617228 | Escherichia coli enterotoxigenic DNA [Presence] in Stool by NAA with probe detection | 0.914 |  |  0 |         0 |
| 36305298 | Varicella zoster virus DNA [Presence] in Aspirate by NAA with probe detection | 0.914 |  |  0 |         0 |
| 3052840 | Varicella zoster virus DNA [#/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.914 |  |  0 |         0 |
| 21493362 | Campylobacter coli+jejuni+upsaliensis DNA [Presence] in Stool by NAA with non-probe detection | 0.913 |  |  0 |         0 |
| 21493559 | Salmonella sp invA+fliC genes [Presence] in Stool by NAA with probe detection | 0.911 |  |  0 |         0 |
| 3012202 | Varicella zoster virus DNA [Presence] in Specimen by NAA with probe detection | 0.911 |  |  1 |     2,880 |
| 1469633 | Shigella species+EIEC DNA [Presence] in Stool by NAA with probe detection | 0.909 |  |  0 |         0 |
| 21492844 | Shigella species+EIEC invasion plasmid antigen H ipaH gene [Presence] in Stool by NAA with non-probe detection | 0.908 |  |  0 |         0 |
| 21493883 | Salmonella sp spaO gene [Presence] in Stool by NAA with probe detection | 0.908 |  |  0 |         0 |
| 40764129 | Campylobacter jejuni DNA [Presence] in Specimen by NAA with probe detection | 0.907 |  |  0 |         0 |
| 21492842 | Escherichia coli enteropathogenic eae gene [Presence] in Stool by NAA with non-probe detection | 0.907 |  |  0 |         0 |
| 21493347 | Cryptococcus gattii+neoformans DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.906 |  |  0 |         0 |
| 3966743 | Escherichia coli enteroinvasive DNA [Presence] in Stool by NAA with probe detection | 0.905 |  |  0 |         0 |
| 21492845 | Escherichia coli enterotoxigenic ltA+st1a+st1b genes [Presence] in Stool by NAA with non-probe detection | 0.905 |  |  0 |         0 |
| 1617150 | Escherichia coli O157 DNA [Presence] in Stool by NAA with probe detection | 0.904 |  |  0 |         0 |
| 1091086 | Streptococcus pneumoniae DNA [Presence] in Nasopharynx by NAA with probe detection | 0.904 |  |  0 |         0 |
| 1259931 | Blastomyces sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.903 |  |  0 |         0 |
| 3032699 | Streptococcus pneumoniae DNA [Presence] in Specimen by NAA with probe detection | 0.903 |  |  1 |     3,940 |
| 1002168 | Neisseria meningitidis DNA [Presence] by NAA with probe detection in Positive blood culture | 0.903 |  |  0 |         0 |
| 1617136 | Vibrio parahaemolyticus DNA [Presence] in Stool by NAA with probe detection | 0.902 |  |  0 |         0 |
| 40764131 | Salmonella enterica DNA [Presence] in Specimen by NAA with probe detection | 0.902 |  |  0 |         0 |
| 37020459 | Cryptococcus neoformans DNA [Presence] by NAA with probe detection in Positive blood culture | 0.901 |  |  0 |         0 |
| 1470026 | Neisseria meningitidis DNA [Presence] in Body fluid by NAA with non-probe detection | 0.900 |  |  0 |         0 |
| 1259979 | Histoplasma sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.900 |  |  0 |         0 |
| 3043907 | Cytomegalovirus DNA [#/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.900 |  |  0 |         0 |
| 1617553 | Streptococcus pneumoniae DNA [Presence] in Synovial fluid by NAA with non-probe detection | 0.898 |  |  0 |         0 |
| 3048882 | Streptococcus agalactiae DNA [Presence] in Specimen by NAA with probe detection | 0.895 | 1156 |  0 |         0 |
| 3966671 | Aeromonas sp DNA [Presence] in Stool by NAA with probe detection | 0.895 |  |  0 |         0 |
| 40764130 | Listeria monocytogenes DNA [Presence] in Specimen by NAA with probe detection | 0.894 |  |  0 |         0 |
| 37020998 | Streptococcus pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.894 |  |  0 |         0 |
| 648359 | Cytomegalovirus DNA [Log #/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.894 |  |  0 |         0 |
| 647508 | Cytomegalovirus DNA [log units/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.894 |  |  0 |         0 |
| 3965246 | Cytomegalovirus DNA [Units/volume] (viral load) in Cerebral spinal fluid by NAA with probe detection | 0.893 |  |  0 |         0 |
| 36303809 | Escherichia coli enterotoxigenic heat-labile toxin DNA [Presence] in Isolate by NAA with probe detection | 0.892 |  |  0 |         0 |
| 1259632 | Coccidioides sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.892 |  |  0 |         0 |
| 3031469 | Cytomegalovirus DNA [Presence] in Amniotic fluid by NAA with probe detection | 0.891 |  |  0 |         0 |
| 37020949 | Neisseria meningitidis DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.891 |  |  0 |         0 |
| 36305353 | Listeria monocytogenes DNA [Presence] in Blood by NAA with probe detection | 0.890 |  |  0 |         0 |
| 37021509 | Streptococcus agalactiae DNA [Presence] by NAA with probe detection in Positive blood culture | 0.890 |  |  0 |         0 |
| 1175573 | Streptococcus agalactiae DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.887 |  |  0 |         0 |
| 1091454 | Yersinia pseudotuberculosis complex DNA [Presence] in Specimen by NAA with probe detection | 0.887 |  |  0 |         0 |
| 1091287 | Listeria sp DNA [Presence] in Specimen by NAA with probe detection | 0.887 |  |  0 |         0 |
| 36203226 | Neisseria meningitidis DNA [Presence] by NAA with non-probe detection in Positive blood culture | 0.885 |  |  0 |         0 |
| 44817210 | Neisseria meningitidis serogroup C DNA [Presence] in Specimen by NAA with probe detection | 0.882 |  |  0 |         0 |
| 3966738 | Aeromonas hydrophila DNA [Presence] in Stool by NAA with probe detection | 0.882 |  |  0 |         0 |
| 21492843 | Escherichia coli enteroaggregative pAA plasmid aggR+aatA genes [Presence] in Stool by NAA with non-probe detection | 0.881 |  |  0 |         0 |
| 3965696 | Yersinia enterocolitica DNA [Presence] in Wound by NAA with probe detection | 0.877 |  |  0 |         0 |
| 36305431 | Escherichia coli enterotoxigenic sta gene [Presence] in Isolate by NAA with probe detection | 0.872 |  |  0 |         0 |
| 37020933 | Listeria monocytogenes DNA [Presence] by NAA with probe detection in Positive blood culture | 0.871 |  |  0 |         0 |
| 3001391 | Mycobacterium sp DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.861 |  |  0 |         0 |
| 1175359 | Enterovirus RNA [Presence] in Stool by NAA with probe detection | 0.861 |  |  0 |         0 |
| 1259880 | Pneumocystis jirovecii DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.861 |  |  0 |         0 |
| 1091127 | Escherichia coli enterotoxigenic ltA+st1a+st1b genes [Presence] in Stool | 0.853 |  |  0 |         0 |
| 3004245 | Escherichia coli K1 Ag [Presence] in Cerebral spinal fluid | 0.847 |  |  0 |         0 |
| 3046567 | Escherichia coli O157:H7 Ag [Presence] in Stool | 0.842 |  |  0 |         0 |
| 3006574 | Escherichia coli verotoxin 1 [Presence] in Stool | 0.829 |  |  0 |         0 |
| 3025564 | Escherichia coli verotoxin 2 [Presence] in Stool | 0.827 |  |  0 |         0 |
| 3005925 | Escherichia coli K1 Ag [Presence] in Cerebral spinal fluid by Latex agglutination | 0.819 |  |  0 |         0 |
| 1091794 | Escherichia coli Stx1 and Stx2 toxin stx1+stx2 genes [Presence] in Stool | 0.801 |  |  0 |         0 |
| 3040222 | Escherichia coli shiga-like toxin 2 [Presence] in Stool by Immunoassay | 0.800 |  |  0 |         0 |
| 3041798 | Escherichia coli shiga-like toxin 1 [Presence] in Stool by Immunoassay | 0.800 |  |  0 |         0 |
| 3020489 | Escherichia coli shiga-like toxin [Presence] in Stool by Immunoassay | 0.796 | 589 |  0 |         0 |
| 3038330 | Escherichia coli enteroinvasive [Presence] in Isolate | 0.793 |  |  0 |         0 |
| 42529409 | Escherichia coli O157 [Presence] in Stool by Culture | 0.785 |  |  0 |         0 |
| 42529406 | Shigella sp [Presence] in Stool by Culture | 0.781 |  |  1 |    14,828 |
| 3023207 | Escherichia coli O157:H7 [Presence] in Stool by Organism specific culture | 0.775 |  |  0 |         0 |
| 42529405 | Escherichia coli shiga-like toxin 1+2 [Presence] in Stool by Immunoassay | 0.762 |  |  0 |         0 |
| 3022318 | Heart rate rhythm | 0.761 |  |  0 |         0 |
| 3007355 | Rhythm segment [Interpretation] by EKG | 0.748 |  |  0 |         0 |
| 1091029 | Shigella species+EIEC invasion plasmid antigen H ipaH gene [Presence] in Specimen | 0.740 |  |  0 |         0 |
| 3020434 | Escherichia coli enteroinvasive identified in Stool by Organism specific culture | 0.733 |  |  0 |         0 |
| 21490782 | Paced heart rate by EKG | 0.731 |  |  0 |         0 |
| 3013078 | R-R interval by EKG | 0.728 |  |  0 |         0 |
| 3016075 | Rhythm segment [Interpretation] Narrative by EKG | 0.726 |  |  0 |         0 |
| 21490872 | Heart rate.beat-to-beat by EKG | 0.724 |  |  0 |         0 |
| 3044421 | Heart rate rhythm palpation | 0.702 |  |  0 |         0 |
| 3043216 | Cardiovascular physiologic and EKG assessment panel | 0.695 |  |  0 |         0 |
| 3036311 | QRS complex Ventricles by EKG | 0.691 |  |  0 |         0 |
| 3036520 | Type of Pacemaker by EKG | 0.689 |  |  0 |         0 |
| 3023075 | Type of EKG leads | 0.684 |  |  0 |         0 |
| 3035644 | Style Pacemaker lead by EKG | 0.680 |  |  0 |         0 |
| 1988764 | Electromyography panel | 0.654 |  |  0 |         0 |
| 1259654 | Diagnostic multisection transesophageal and cardioversion panel Heart | 0.652 |  |  0 |         0 |
| 1988411 | Permanent pacemaker panel | 0.642 |  |  0 |         0 |
| 3044933 | Cardiac 2D echo panel | 0.641 |  |  0 |         0 |
| 3013512 | EKG study | 0.638 |  | 10 |   506,024 |
| 1988318 | Temporary pacemaker panel | 0.628 |  |  0 |         0 |
| 3044671 | QRS duration {Electrocardiograph lead} | 0.625 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 109 | ehec(enterohemorraaginene.coli) |  | 1317 | 100 |  |  |  |  | Escherichia coli.enterohemorrhagic [Presence] in Stool | FALSE |
| 110 | ekg,12kytkentäälevossa |  | 6937 | 99.99 |  |  |  |  | 12 lead EKG panel | TRUE |
| 111 | ekg,12kytkentäälevossa(asi |  | 8872 | 100 |  |  |  |  | 12 lead EKG panel | TRUE |
| 112 | ekg,12kytkentäälevossa(asiakkaanottama) |  | 2232 | 100 |  |  |  |  | 12 lead EKG panel | TRUE |
| 113 | ekg,12kytkentäälevossa(asiakkanottama) |  | 1287 | 100 |  |  |  |  | 12 lead EKG panel | TRUE |
| 114 | ekg-12kytkentäälevossa |  | 2227 | 100 |  |  |  |  | 12 lead EKG panel | TRUE |
| 115 | enteroaggregatiivinene.colinho |  | 229 | 100 |  |  |  |  | Escherichia coli.enteroaggregative RNA+DNA [Presence] in Stool by NAA with probe detection | FALSE |
| 116 | enterohemorraginene.colinho |  | 383 | 100 |  |  |  |  | Escherichia coli.enterohemorrhagic shiga-like toxin gene [Presence] in Stool by NAA with probe detection | FALSE |
| 117 | enteropatogeeninene.colinho |  | 229 | 100 |  |  |  |  | Escherichia coli.enteropathogenic RNA+DNA [Presence] in Stool by NAA with probe detection | FALSE |
| 118 | enterotoksigeeninene.colinho |  | 383 | 100 |  |  |  |  | Escherichia coli.enterotoxigenic heat-labile+heat-stable enterotoxin gene [Presence] in Stool by NAA with probe detection | FALSE |
| 119 | etec(enterotoksigeeninene.coli) |  | 1317 | 100 |  |  |  |  | Escherichia coli.enterotoxigenic [Presence] in Stool | FALSE |
| 120 | f-campylobacterspp.(jejuni&coli)nukl.haponos |  | 607 | 100 |  |  | Feces |  | Campylobacter sp DNA [Presence] in Stool by NAA with probe detection | FALSE |
| 121 | f-ehec(enterohemorraaginene.coli)nukl.haponos |  | 607 | 100 |  |  | Feces |  | Escherichia coli.enterohemorrhagic shiga-like toxin gene [Presence] in Stool by NAA with probe detection | FALSE |
| 122 | f-etec(enterotoksigeeninene.coli)nukl.haponos |  | 607 | 100 |  |  | Feces |  | Escherichia coli.enterotoxigenic heat-labile+heat-stable enterotoxin gene [Presence] in Stool by NAA with probe detection | FALSE |
| 123 | f-plesiomonasshigelloidesnukl.haponos. |  | 607 | 100 |  |  | Feces |  | Plesiomonas shigelloides DNA [Presence] in Stool by NAA with probe detection | FALSE |
| 124 | f-salmonellaspp.nukl.haponos |  | 607 | 100 |  |  | Feces |  | Salmonella sp DNA [Presence] in Stool by NAA with probe detection | FALSE |
| 125 | f-shigellaspp./eiec(enteroinvasiivinene.coli)nukl.haponos |  | 616 | 100 |  |  | Feces |  | Shigella sp+Escherichia coli.enteroinvasive ipaH gene [Presence] in Stool by NAA with probe detection | FALSE |
| 126 | f-yersiniaenterocoliticanukl.haponos. |  | 607 | 100 |  |  | Feces |  | Yersinia enterocolitica DNA [Presence] in Stool by NAA with probe detection | FALSE |
| 127 | li-cryptococcusneoformans,nukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Cryptococcus neoformans DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 128 | li-cytomegalovirusnukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Cytomegalovirus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 129 | li-escherichiacolik1nukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Escherichia coli K1 antigen gene [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 130 | li-herpessimplex1,nukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Herpes simplex virus 1 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 131 | li-herpessimplex2,nukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Herpes simplex virus 2 DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 132 | li-l.monocytogenesnukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Listeria monocytogenes DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 133 | li-neisseriameningitidisnukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Neisseria meningitidis DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 134 | li-streptococcusagalactiaenukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 135 | li-streptococcuspneumoniaenukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Streptococcus pneumoniae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 136 | li-varicella-zosternukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Varicella zoster virus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 137 | pt-ekg,12kytkentälevossa |  | 243 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 138 | pt-ekg,12kytkentää6tk |  | 368 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 139 | pt-ekg,12kytkentääep-terveyskeskus |  | 206 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 140 | pt-ekg,12kytkentäälevossa | 1 | 55 | 0 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 141 | pt-ekg,12kytkentäälevossa |  | 54957 | 99.91 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 142 | pt-ekg,12kytkentäälevossa(k-pks:n)(ko) |  | 272 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 143 | pt-ekg,12kytkentäälevossa(ot.tk:ssa) |  | 210 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 144 | pt-ekg,12kytkentäälevossa,omarekisteröintimuseen |  | 2847 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 145 | pt-ekg,12kytkentäälevossaosastolla |  | 193 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 146 | pt-ekg,12kytkentäälevossa␤ |  | 2419 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 147 | pt-ekg,eteisvärinänseulonta,valvontamonitori-ekg |  | 477 | 100 |  |  | Patient |  | Rhythm EKG | TRUE |
| 148 | pt-ekg,eteisvärinänseulonta,valvontamonitori-ekg,lisätallenne |  | 625 | 100 |  |  | Patient |  | Rhythm EKG | TRUE |
| 149 | pt-ekg,sisältäentietokoneanalyysin |  | 8257 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 150 | pt-ekg,sisältäentietokoneanalyysin(malmin)(pi) |  | 226 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 151 | pt-ekg,sisältäätietokoneanalyysin |  | 4178 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 152 | pt-ekgsis[lt[entietokoneanalyysin |  | 305 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 153 | pt-ekgsisältäentietokoneanalyysin |  | 347 | 100 |  |  | Patient |  | 12 lead EKG panel | TRUE |
| 154 | shigella/eiec(enteroinvasiivinene.coli) |  | 1318 | 100 |  |  |  |  | Shigella sp+Escherichia coli.enteroinvasive [Presence] in Stool | FALSE |

