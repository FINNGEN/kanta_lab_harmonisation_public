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
Here is group 73.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 37019589 | Parainfluenza virus 1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |       0 |
| 37019613 | Parainfluenza virus 2 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |       0 |
| 37020003 | Rhinovirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |       0 |
| 37020335 | Parainfluenza virus 4 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |       0 |
| 37020635 | Influenza virus A RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |       0 |
| 37021252 | Influenza virus B RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |       0 |
| 37021465 | Parainfluenza virus 3 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 0 |       0 |
| 3965803 | Influenza virus A+B RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.977 |  | 0 |       0 |
| 3966116 | Influenza virus A H1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.969 |  | 0 |       0 |
| 3038297 | Parainfluenza virus 4 RNA [Presence] in Specimen by NAA with probe detection | 0.960 |  | 1 |   4,034 |
| 3038288 | Influenza virus B RNA [Presence] in Specimen by NAA with probe detection | 0.959 |  | 1 |  95,225 |
| 36203322 | Influenza virus B RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.959 |  | 0 |       0 |
| 37019984 | Parainfluenza virus 4 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.958 |  | 0 |       0 |
| 37019747 | Rhinovirus RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.957 |  | 0 |       0 |
| 1091113 | Influenza virus B RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.957 |  | 0 |       0 |
| 3012158 | Parainfluenza virus 2 RNA [Presence] in Specimen by NAA with probe detection | 0.957 |  | 1 |   4,036 |
| 3964727 | Influenza virus A H3 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.957 |  | 0 |       0 |
| 3965820 | Human Rhinovirus 1 and 2 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.956 |  | 0 |       0 |
| 3965123 | Human Rhinovirus 2 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.956 |  | 0 |       0 |
| 37021346 | Parainfluenza virus 2 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.954 |  | 0 |       0 |
| 40764126 | Parainfluenza virus RNA [Presence] in Specimen by NAA with probe detection | 0.954 |  | 1 |   5,001 |
| 37020881 | Parainfluenza virus 1 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.953 |  | 0 |       0 |
| 3025634 | Parainfluenza virus 1 RNA [Presence] in Specimen by NAA with probe detection | 0.953 |  | 1 |   4,037 |
| 3006262 | Parainfluenza virus 3 RNA [Presence] in Specimen by NAA with probe detection | 0.953 |  | 1 |   4,036 |
| 3025023 | Rhinovirus RNA [Presence] in Specimen by NAA with probe detection | 0.953 |  | 1 |   7,393 |
| 37019976 | Parainfluenza virus 3 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.953 |  | 0 |       0 |
| 36203321 | Influenza virus A RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.951 |  | 0 |       0 |
| 37019554 | Parainfluenza virus RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.950 |  | 0 |       0 |
| 36304919 | Influenza virus B RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.949 |  | 0 |       0 |
| 36304298 | Parainfluenza virus 4 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.949 |  | 0 |       0 |
| 36305681 | Parainfluenza virus 1 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.949 |  | 0 |       0 |
| 1091251 | Parainfluenza virus 4 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.948 |  | 0 |       0 |
| 36304319 | Parainfluenza virus 2 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.947 |  | 0 |       0 |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.947 |  | 0 |       0 |
| 40770419 | Parainfluenza virus 4a RNA [Presence] in Specimen by NAA with probe detection | 0.947 |  | 0 |       0 |
| 40770420 | Parainfluenza virus 4b RNA [Presence] in Specimen by NAA with probe detection | 0.947 |  | 0 |       0 |
| 3044938 | Influenza virus A RNA [Presence] in Specimen by NAA with probe detection | 0.946 |  | 3 | 142,013 |
| 36304620 | Parainfluenza virus RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.946 |  | 0 |       0 |
| 1091967 | Parainfluenza virus 2 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.945 |  | 0 |       0 |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.944 |  | 0 |       0 |
| 1091332 | Parainfluenza virus 1 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.943 |  | 0 |       0 |
| 36303784 | Parainfluenza virus 3 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.943 |  | 0 |       0 |
| 1092023 | Parainfluenza virus 3 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.942 |  | 0 |       0 |
| 1091443 | Influenza virus A RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.940 |  | 0 |       0 |
| 36305662 | Influenza virus A RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.939 |  | 0 |       0 |
| 1091557 | Rhinovirus RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.939 |  | 0 |       0 |
| 21494892 | Influenza virus types A and B and subtypes RNA panel - Respiratory system specimen by NAA with probe detection | 0.938 |  | 0 |       0 |
| 1092106 | Parainfluenza virus RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.937 |  | 0 |       0 |
| 37021109 | Influenza virus B RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.936 |  | 0 |       0 |
| 646127 | Influenza virus B RNA [Presence] in Specimen by NAA with non-probe detection | 0.935 |  | 0 |       0 |
| 36660164 | Parainfluenza virus 1 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.934 |  | 0 |       0 |
| 1616605 | Rhinovirus+Enterovirus A+B+C RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.934 |  | 0 |       0 |
| 649299 | Parainfluenza virus 1 RNA [Presence] in Specimen by NAA with non-probe detection | 0.933 |  | 0 |       0 |
| 1175203 | Rhinovirus RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.932 |  | 0 |       0 |
| 36659829 | Parainfluenza virus 3 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.931 |  | 0 |       0 |
| 645627 | Parainfluenza virus 2 RNA [Presence] in Specimen by NAA with non-probe detection | 0.930 |  | 0 |       0 |
| 1988089 | Influenza virus A N1 RNA [Presence] in Specimen by NAA with probe detection | 0.930 |  | 0 |       0 |
| 36660052 | Parainfluenza virus 2 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.929 |  | 0 |       0 |
| 647882 | Parainfluenza virus 3 RNA [Presence] in Specimen by NAA with non-probe detection | 0.927 |  | 0 |       0 |
| 1091221 | Influenza virus B RNA [Presence] in Sputum by NAA with probe detection | 0.926 |  | 0 |       0 |
| 1092357 | Rhinovirus RNA [Presence] in Sputum by NAA with probe detection | 0.925 |  | 0 |       0 |
| 46236735 | Rhinovirus RNA [Presence] in Nasopharynx by NAA with probe detection | 0.919 |  | 0 |       0 |
| 37020181 | Influenza virus types A and B panel - Upper respiratory specimen by NAA with probe detection | 0.918 |  | 0 |       0 |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.907 |  | 2 |  45,357 |
| 36304096 | Influenza virus types A and B panel - Lower respiratory specimen by NAA with probe detection | 0.897 |  | 0 |       0 |
| 1617384 | Influenza virus types A and B and subtypes RNA panel - Specimen by NAA with probe detection | 0.896 |  | 0 |       0 |
| 40765199 | Influenza virus A+B RNA [Presence] in Specimen by NAA with probe detection | 0.896 |  | 0 |       0 |
| 36661376 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.894 |  | 0 |       0 |
| 21493425 | Influenza virus A H7 Eurasia RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.893 |  | 0 |       0 |
| 36661384 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.875 |  | 0 |       0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1104 | -hinfnho |  | 311 | 100 |  |  |  |  |  | FALSE |
| 1105 | -hinnho |  | 3618 | 100 |  |  |  |  |  | FALSE |
| 1106 | -inabnho |  | 4313 | 100 |  | -Influenssa A ja B-virus, nukleiinihappo (kval) |  |  | Influenza virus A+B RNA panel - Respiratory system specimen by NAA with probe detection | TRUE |
| 1107 | -inabnhoho |  | 387 | 100 |  |  |  |  |  | FALSE |
| 1108 | -inabrsnho |  | 432 | 100 |  |  |  |  | Influenza virus A+B+Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | TRUE |
| 1109 | -inanho |  | 356 | 100 |  |  |  |  | Influenza virus A RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1110 | -inanhoho |  | 409 | 100 |  |  |  |  |  | FALSE |
| 1111 | -inbnho |  | 356 | 100 |  |  |  |  | Influenza virus B RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1112 | -inbnhoho |  | 411 | 100 |  |  |  |  |  | FALSE |
| 1113 | -infanho |  | 122873 | 100 |  | -Influenssa A -virus, nukleiinihappo (kval) |  |  | Influenza virus A RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1114 | -infbnho |  | 95902 | 100 |  | -Influenssa B-virus, nukleiinihappo (kval) |  |  | Influenza virus B RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1115 | -infvnho |  | 1260 | 100 |  | -Influenssa A-virus, variantti, nukleiinihappo (kval) |  |  | Influenza virus A variant [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1116 | -pin1nho |  | 9246 | 100 |  | -Parainfluenssa 1-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1117 | -pin2nho |  | 9244 | 100 |  | -Parainfluenssa 2-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 2 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1118 | -pin3nho |  | 9240 | 100 |  | -Parainfluenssa 3-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 3 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1119 | -pin4nho |  | 9240 | 100 |  | -Parainfluenssa 4-virus, nukleiinihappo (kval) |  |  | Parainfluenza virus 4 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1120 | -pinfnho |  | 5018 | 100 |  |  |  |  | Parainfluenza virus RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1121 | -rinonho |  | 7403 | 100 |  | -Rinovirus, nukleiinihappo (kval) |  |  | Rhinovirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1122 | -tintnho |  | 595 | 100 |  |  |  |  |  | FALSE |
| 1123 | hinflnho |  | 745 | 100 |  |  |  |  |  | FALSE |
| 1124 | inanho |  | 7494 | 100 |  |  |  |  | Influenza virus A RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1125 | inbnho |  | 7494 | 100 |  |  |  |  | Influenza virus B RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1126 | infanho |  | 12417 | 100 |  |  |  |  | Influenza virus A RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1127 | infbnho |  | 34660 | 100 |  |  |  |  | Influenza virus B RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1128 | infnho |  | 766 | 100 |  |  |  |  |  | FALSE |
| 1129 | pin1nho |  | 4037 | 100 |  |  |  |  | Parainfluenza virus 1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1130 | pin2nho |  | 4036 | 100 |  |  |  |  | Parainfluenza virus 2 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1131 | pin3nho |  | 4036 | 100 |  |  |  |  | Parainfluenza virus 3 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1132 | pin4nho |  | 4034 | 100 |  |  |  |  | Parainfluenza virus 4 RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1133 | rinonho |  | 245 | 100 |  |  |  |  | Rhinovirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |

