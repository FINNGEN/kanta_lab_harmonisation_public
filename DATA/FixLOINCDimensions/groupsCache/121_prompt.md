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
Here is group 121.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3048879 | Bone marrow aspiration report | 0.948 |  | 1 |  1,994 |
| 36303746 | Microscopic observation [Identifier] in Bone marrow by Giemsa stain | 0.938 |  | 0 |      0 |
| 3026001 | HFE gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.935 |  | 0 |      0 |
| 3044589 | NPHS1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.933 |  | 0 |      0 |
| 40763542 | NPHS2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.925 |  | 0 |      0 |
| 3014837 | Microscopic observation [Identifier] in Bone marrow by Wright Giemsa stain | 0.921 | 1579 | 0 |      0 |
| 1001873 | DPYD gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.919 |  | 0 |      0 |
| 40757578 | FLT3 gene targeted mutation analysis in Bone marrow by Molecular genetics method | 0.918 |  | 1 |    138 |
| 3020720 | BRCA1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.918 |  | 0 |      0 |
| 40757581 | CYP2C9 and VKORC1 panel - Blood or Tissue by Molecular genetics method | 0.918 |  | 0 |      0 |
| 3048642 | BRCA2 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.910 |  | 0 |      0 |
| 40761064 | DPYD2A gene targeted mutation analysis [Presence] in Blood or Tissue by Molecular genetics method | 0.908 |  | 0 |      0 |
| 3047340 | FMR1 gene allele 1 CGG repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.906 |  | 0 |      0 |
| 3046498 | JAK2 gene p.Val617Phe [Presence] in Blood or Tissue by Molecular genetics method | 0.903 | 1692 | 0 |      0 |
| 3025788 | FMR1 gene CGG repeats [Presence] in Blood or Tissue by Molecular genetics method | 0.897 |  | 0 |      0 |
| 3044596 | NPHS1 gene targeted mutation analysis in Body fluid by Molecular genetics method | 0.895 |  | 0 |      0 |
| 42528716 | CALR gene exon 9 full mutation analysis in Blood or Tissue by Molecular genetics method | 0.894 |  | 0 |      0 |
| 1259990 | TP53 gene full mutation analysis in Blood or Tissue by Molecular genetics method | 0.894 |  | 0 |      0 |
| 36304954 | Microscopic observation [Identifier] in Bone marrow by Gram stain | 0.894 |  | 0 |      0 |
| 3011668 | Microscopic observation [Identifier] in Bone marrow by Myeloperoxidase stain | 0.893 |  | 0 |      0 |
| 3031465 | APOE gene allele 1 [Identifier] in Blood or Tissue by Molecular genetics method | 0.891 |  | 0 |      0 |
| 21493421 | Microscopic observation [Identifier] in Bone marrow by Toluidine blue O stain | 0.891 |  | 0 |      0 |
| 3037060 | TPMT gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.891 | 1635 | 0 |      0 |
| 3046976 | DPYD gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.890 |  | 0 |      0 |
| 43054967 | JAK2 gene p.Val617Phe [Presence] in Bone marrow by Molecular genetics method | 0.887 |  | 0 |      0 |
| 3042168 | TPMT gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.884 |  | 0 |      0 |
| 3043025 | FMR1 gene allele 2 CGG repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.882 |  | 0 |      0 |
| 3049135 | FLT3 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.881 |  | 0 |      0 |
| 3009106 | TP53 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.879 |  | 0 |      0 |
| 36303378 | Microscopic observation [Identifier] in Bone marrow by Acid fast stain | 0.878 |  | 0 |      0 |
| 46237016 | CALR gene exon 9 mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.877 |  | 0 |      0 |
| 3038346 | JAK2 gene.p.Val617Phe mutant/Normal in Blood or Tissue by Molecular genetics method | 0.877 |  | 0 |      0 |
| 3032354 | APOE gene allele 2 [Identifier] in Blood or Tissue by Molecular genetics method | 0.876 |  | 0 |      0 |
| 3003648 | SERPINA1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.876 |  | 0 |      0 |
| 3041464 | NPHS1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.873 |  | 0 |      0 |
| 21494429 | FMR1 gene CGG repeat analysis in Blood or Tissue by Molecular genetics method | 0.872 |  | 1 |    345 |
| 3049056 | t(9;22)(q34.1;q11)(ABL1,BCR) fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.870 |  | 0 |      0 |
| 1617608 | TP53 gene deletion and duplication mutation analysis [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.870 |  | 0 |      0 |
| 3051274 | Microscopic observation [Identifier] in Bone marrow by Rhodamine-auramine fluorochrome stain | 0.869 |  | 0 |      0 |
| 40759280 | LDLR gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.869 |  | 0 |      0 |
| 1002341 | TPMT gene and NUDT15 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.868 |  | 0 |      0 |
| 42868452 | t(9;22)(q34.1;q11)(ABL1,BCR) e1a2 fusion transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.868 |  | 1 |    144 |
| 42527977 | FLT3 gene internal tandem duplication [Presence] in Bone marrow by Molecular genetics method | 0.864 |  | 0 |      0 |
| 21493422 | Microscopic observation [Identifier] in Bone marrow by Oil red O stain | 0.863 |  | 0 |      0 |
| 3049939 | SERPINA1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.863 |  | 0 |      0 |
| 1259496 | DPYD gene.c.2846A>T [Presence] in Blood or Tissue by Molecular genetics method | 0.863 |  | 0 |      0 |
| 1091265 | DPYD gene.c.1236G>A [Presence] in Blood or Tissue by Molecular genetics method | 0.861 |  | 0 |      0 |
| 43054969 | NPM1 gene c.956dupTCTG transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.859 |  | 0 |      0 |
| 1092197 | Hereditary nonpolyposis colorectal cancer multigene analysis in Blood or Tissue by Molecular genetics method | 0.859 |  | 0 |      0 |
| 1259589 | DPYD gene.c.1905+1G>A [Presence] in Blood or Tissue by Molecular genetics method | 0.859 |  | 0 |      0 |
| 1259714 | DPYD gene.c.1679T>G [Presence] in Blood or Tissue by Molecular genetics method | 0.857 |  | 0 |      0 |
| 3041559 | t(9;22)(q34.1;q11)(ABL1,BCR) b3a2 fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.857 |  | 0 |      0 |
| 36659909 | DPYD gene full mutation analysis in Blood or Tissue by Sequencing | 0.857 |  | 0 |      0 |
| 36303968 | JAK2 gene.p.Val617Phe mutant/Normal in Bone marrow by Molecular genetics method | 0.856 |  | 0 |      0 |
| 3039381 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2 fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.856 |  | 0 |      0 |
| 3042391 | t(9;22)(q34.1;q11)(ABL1,BCR) e1a2 fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.855 |  | 1 |  1,560 |
| 36304173 | Microscopic observation [Identifier] in Aspirate by Giemsa stain | 0.854 |  | 0 |      0 |
| 3032512 | TPMT gene c.460G>A [Presence] in Blood or Tissue by Molecular genetics method | 0.854 |  | 0 |      0 |
| 3001453 | SERPINA1 gene p.Glu342Lys [Presence] in Blood or Tissue by Molecular genetics method | 0.853 |  | 0 |      0 |
| 648345 | JAK2 gene.p.Val617Phe mutant/Normal in Specimen by Molecular genetics method | 0.852 |  | 0 |      0 |
| 40771901 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2+b3a2 fusion transcript/control transcript (International Scale) [# Ratio] in Blood or Tissue by Molecular genetics method | 0.851 |  | 1 |  1,803 |
| 3019707 | SERPINA1 gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.850 |  | 0 |      0 |
| 43054968 | NPM1 gene c.960insCATG transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.850 |  | 0 |      0 |
| 42529041 | t(9;22)(q34.1;q11)(ABL1,BCR) fusion transcript/control transcript [Log Number Ratio] in Bone marrow by Molecular genetics method | 0.850 |  | 0 |      0 |
| 3026226 | HBB gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.849 |  | 0 |      0 |
| 43054970 | NPM1 gene c.960insCCTG transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.849 |  | 0 |      0 |
| 42870546 | LDLR gene mutation analysis limited to known familial mutations in Blood or Tissue by Molecular genetics method | 0.849 |  | 0 |      0 |
| 42870298 | TPMT gene c.238G>C+460G>A+719A>G [Identifier] in Blood or Tissue by Molecular genetics method Narrative | 0.849 |  | 1 |    613 |
| 40758277 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2+b3a2 fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.848 |  | 0 |      0 |
| 3017994 | Microscopic observation [Identifier] in Bone marrow by Butyrate esterase stain | 0.843 |  | 0 |      0 |
| 3033015 | TPMT gene c.238G>C [Presence] in Blood or Tissue by Molecular genetics method | 0.843 |  | 0 |      0 |
| 42870303 | Y chromosome AZFc region deletion [Identifier] in Blood or Tissue by Molecular genetics method Narrative | 0.841 |  | 0 |      0 |
| 42870301 | Y chromosome AZFa region deletion [Identifier] in Blood or Tissue by Molecular genetics method Narrative | 0.841 |  | 0 |      0 |
| 3002554 | SERPINA1 gene p.Glu264Val [Presence] in Blood or Tissue by Molecular genetics method | 0.840 |  | 0 |      0 |
| 40766184 | TPMT gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.840 |  | 0 |      0 |
| 40771884 | SERPINA10 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.840 |  | 0 |      0 |
| 3048224 | HFE gene c.187G>C [Presence] in Blood or Tissue by Molecular genetics method | 0.839 |  | 0 |      0 |
| 3029271 | t(9;22)(q34.1;q11)(ABL1,BCR) fusion transcript/control transcript [Log Number Ratio] in Blood or Tissue by Molecular genetics method | 0.838 |  | 0 |      0 |
| 3030112 | TPMT gene c.719A>G [Presence] in Blood or Tissue by Molecular genetics method | 0.838 |  | 0 |      0 |
| 1761632 | TPMT gene c.460G>A and c.719A>G [Presence] in Blood by Molecular genetics method | 0.837 |  | 0 |      0 |
| 42870302 | Y chromosome AZFb region deletion [Identifier] in Blood or Tissue by Molecular genetics method Narrative | 0.835 |  | 0 |      0 |
| 1469500 | CALR gene exon 9 mutations found [Identifier] in Blood or Tissue by Sequencing Nominal | 0.834 |  | 0 |      0 |
| 1176451 | LDLR gene full mutation analysis in Blood or Tissue by Sequencing | 0.833 |  | 0 |      0 |
| 21492353 | FLT3 gene internal tandem duplication [Presence] in Blood or Tissue by Molecular genetics method | 0.832 |  | 0 |      0 |
| 3024563 | HBA1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.830 |  | 0 |      0 |
| 21493707 | TPMT gene mutations found [Identifier] in Blood or Tissue by Sequencing Nominal | 0.830 |  | 0 |      0 |
| 40763541 | NPHP1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.826 |  | 0 |      0 |
| 40771486 | SERPINA10 gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.826 |  | 0 |      0 |
| 3029139 | APOE gene alleles e2 and e3 and e4 [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.826 |  | 0 |      0 |
| 36660126 | TP53 gene deletion+duplication and full mutation analysis in Blood or Tissue by Molecular genetics method | 0.825 |  | 0 |      0 |
| 3042030 | NPHS1 gene mutations found [Identifier] in Body fluid by Molecular genetics method Nominal | 0.825 |  | 0 |      0 |
| 3000360 | BRCA1 gene c.5382insC [Presence] in Blood or Tissue by Molecular genetics method | 0.824 |  | 0 |      0 |
| 37019932 | FLT3 gene p.Asp835 mutations [Presence] in Blood or Tissue by Molecular genetics method | 0.824 |  | 0 |      0 |
| 1259665 | DPYD gene.c.2846A>T [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.824 |  | 0 |      0 |
| 3034599 | Y chromosome deletion [Identifier] in Blood or Tissue Nominal | 0.823 |  | 0 |      0 |
| 1259630 | DPYD gene.c.1679T>G [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.823 |  | 0 |      0 |
| 3047555 | MLH1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.822 |  | 0 |      0 |
| 43055147 | FLT3 gene.p.Asp835+Ile836 mutations [Presence] in Blood or Tissue by Molecular genetics method | 0.821 |  | 0 |      0 |
| 3038782 | SERPINE1 gene c.-844A>G [Presence] in Blood or Tissue by Molecular genetics method | 0.821 |  | 0 |      0 |
| 3013421 | HFE gene p.His63Asp [Presence] in Blood or Tissue by Molecular genetics method | 0.821 |  | 0 |      0 |
| 3014662 | BRCA2 gene c.6174delT [Presence] in Blood or Tissue by Molecular genetics method | 0.820 |  | 0 |      0 |
| 43055276 | NPM1 gene c.956dupTCTG transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.819 |  | 0 |      0 |
| 3011498 | APOE gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.818 | 1404 | 0 |      0 |
| 646099 | t(9;22)(q34.1;q11)(ABL1,BCR) fusion transcript/control transcript [Log Number Ratio] in Specimen by Molecular genetics method | 0.816 |  | 0 |      0 |
| 3029984 | BRCA1+BRCA2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.816 |  | 0 |      0 |
| 3005580 | BRCA1 gene.c.185 del AG [presence] in Blood or Tissue by Molecular genetics method | 0.816 |  | 0 |      0 |
| 3001745 | CBS gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.816 |  | 0 |      0 |
| 3026898 | HFE gene.p.Cys282Tyr [Presence] in Blood or Tissue by Molecular genetics method | 0.815 | 1479 | 0 |      0 |
| 43534060 | CYP2D6 gene and CYP2C19 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.815 |  | 0 |      0 |
| 3014186 | FRAXE gene CGG repeats [Presence] in Blood or Tissue by Molecular genetics method | 0.814 | 1557 | 0 |      0 |
| 40758279 | BCR-ABL1 e1a2 fusion protein [Presence] in Blood or Tissue by Molecular genetics method | 0.813 |  | 0 |      0 |
| 3045461 | Apolipoprotein E phenotype [Identifier] in Blood | 0.813 |  | 0 |      0 |
| 46236293 | HBB gene mutations found [Identifier] in Blood or Tissue by Sequencing Nominal | 0.812 |  | 0 |      0 |
| 43055275 | NPM1 gene c.960insCATG transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.811 |  | 0 |      0 |
| 40758430 | JAK2 gene exon 13 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.809 |  | 0 |      0 |
| 3039791 | MLH1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.809 |  | 0 |      0 |
| 3049576 | HFE gene.p.Ser65Cys [Presence] in Blood or Tissue by Molecular genetics method | 0.809 |  | 0 |      0 |
| 21494670 | JAK2 gene exon 14 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.808 |  | 1 |  5,490 |
| 3045142 | Bone marrow Pathology biopsy report | 0.808 | 1159 | 1 |  6,303 |
| 40769530 | FMR1 gene premutation/premutation+full mutation in Blood by Molecular genetics method | 0.808 |  | 0 |      0 |
| 3041037 | FMR1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.807 |  | 0 |      0 |
| 3033006 | BCR-ABL1 e1a1 fusion protein [Presence] in Blood or Tissue by Molecular genetics method | 0.807 |  | 0 |      0 |
| 43055274 | NPM1 gene c.960insCCTG transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.806 |  | 0 |      0 |
| 3027955 | HFE gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.806 |  | 1 |    646 |
| 3041818 | SERPINE1 gene c.-675 4G+5G [Presence] in Blood or Tissue by Molecular genetics method | 0.806 |  | 0 |      0 |
| 40762134 | BRCA1+BRCA2 gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.806 |  | 0 |      0 |
| 40763092 | PIK3CA gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.806 |  | 0 |      0 |
| 1092115 | Hereditary thrombosis disorders multigene analysis in Blood by Molecular genetics method | 0.806 |  | 0 |      0 |
| 36659930 | SERPINA1 gene full mutation analysis in Blood or Tissue by Sequencing | 0.806 |  | 0 |      0 |
| 3048870 | JAK2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.805 |  | 0 |      0 |
| 3040149 | CFH gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.805 |  | 0 |      0 |
| 40758429 | JAK2 gene exon 12 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.805 |  | 0 |      0 |
| 1989116 | Hereditary thrombocytopenia multigene analysis in Blood or Tissue by Molecular genetics method | 0.803 |  | 0 |      0 |
| 40757582 | CYP2C9 and VKORC1 [Interpretation] in Blood or Tissue by Molecular genetics method Narrative | 0.799 |  | 0 |      0 |
| 21494295 | HGD gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.799 |  | 0 |      0 |
| 3036151 | HNPCC genes mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.798 |  | 0 |      0 |
| 3039049 | Pharmacogenetic DNA analysis panel | 0.798 |  | 0 |      0 |
| 21494671 | JAK2 gene exon 14 targeted mutation analysis in Bone marrow by Molecular genetics method | 0.798 |  | 1 |     38 |
| 40759871 | APOB gene+LDLR gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.796 |  | 0 |      0 |
| 40771054 | APOB+LDLR+PCSK9 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.796 |  | 0 |      0 |
| 3036403 | TP73L gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.795 |  | 0 |      0 |
| 1469914 | CD3 cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.795 |  | 0 |      0 |
| 21493868 | CYP3A4 and CYP3A5 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.792 |  | 0 |      0 |
| 1617545 | FLT3 gene.p.Asp835+Ile836 mutations/Normal in Blood or Tissue by Molecular genetics method | 0.791 |  | 0 |      0 |
| 44816925 | NPM1 gene mutations found [Identifier] in Bone marrow by Molecular genetics method Nominal | 0.791 |  | 0 |      0 |
| 42870547 | LDLR gene deletion and duplication mutation analysis in Blood or Tissue by MLPA | 0.788 |  | 0 |      0 |
| 21492686 | Pharmacogenomic analysis basic associated observations panel - Blood or Tissue | 0.787 |  | 0 |      0 |
| 3966642 | COL4A3 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.787 |  | 0 |      0 |
| 1002327 | Warfarin response genotype panel - Blood or Tissue by Molecular genetics method | 0.786 |  | 0 |      0 |
| 43055139 | VKORC1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.786 |  | 0 |      0 |
| 37020111 | FLT3 gene internal tandem duplication/Normal [Ratio] in Blood or Tissue by Molecular genetics method | 0.786 |  | 0 |      0 |
| 40762031 | LCT gene mutations found [Type] in Blood or Tissue by Molecular genetics method | 0.785 |  | 0 |      0 |
| 40763093 | PIK3CA gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.785 |  | 0 |      0 |
| 3052594 | NCF2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.783 |  | 0 |      0 |
| 40769529 | FMR1 gene methylation/methylated+unmethylated in Blood by Molecular genetics method | 0.782 |  | 0 |      0 |
| 40768802 | Bone marrow Pathology biopsy report Narrative | 0.782 |  | 0 |      0 |
| 3052805 | MSH2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.781 |  | 0 |      0 |
| 645775 | Hypercholesterolemia multigene analysis in Blood or Tissue by Molecular genetics method | 0.779 |  | 0 |      0 |
| 3051704 | Genechip kit panel - Blood or Tissue by Molecular genetics method | 0.779 |  | 0 |      0 |
| 36303911 | Respiratory pathogens panel - Bronchoalveolar lavage by Immunofluorescence | 0.779 |  | 0 |      0 |
| 3038834 | MUTYH gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.779 |  | 0 |      0 |
| 21493567 | CYP2C9 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.778 |  | 0 |      0 |
| 3050631 | PLOD1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.778 |  | 0 |      0 |
| 40769528 | FMR1 gene activation in Blood by Molecular genetics method | 0.778 |  | 0 |      0 |
| 1616360 | FLT3 gene internal tandem duplication length [#] in Blood or Tissue by Molecular genetics method | 0.777 |  | 0 |      0 |
| 645830 | Hereditary gastrointestinal cancer multigene analysis in Blood or Tissue by Molecular genetics method | 0.777 |  | 0 |      0 |
| 1616537 | Hereditary cancer multigene analysis in Blood or Tissue by Molecular genetics method | 0.775 |  | 0 |      0 |
| 3042350 | MSH6 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.775 |  | 0 |      0 |
| 3030719 | HTT gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.774 |  | 0 |      0 |
| 1470025 | CD3+CD4+ (T4 helper) cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.773 |  | 0 |      0 |
| 1761781 | IDH1 gene exon 4 targeted mutation analysis [Presence] in Blood or Marrow by Molecular genetics method | 0.773 |  | 0 |      0 |
| 21493621 | Subtelomere analysis in Bone marrow by FISH | 0.773 |  | 0 |      0 |
| 40765085 | Chromosome analysis.metaphase panel - Blood by FISH | 0.773 |  | 0 |      0 |
| 1260013 | Apolipoprotein E phenotype [Identifier] in Plasma by LC/MS/MS | 0.773 |  | 0 |      0 |
| 40758363 | Alpha thalassemia gene panel - Blood by Molecular genetics method | 0.772 |  | 0 |      0 |
| 40758369 | HBB gene c.251G>A [Presence] in Blood by Molecular genetics method | 0.772 |  | 0 |      0 |
| 40758370 | HBB gene c.19G>A [Presence] in Blood by Molecular genetics method | 0.772 |  | 0 |      0 |
| 1259869 | HIF2A gene targeted mutation analysis in Blood by Molecular genetics method | 0.771 |  | 0 |      0 |
| 3039264 | MT-TK gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.771 |  | 0 |      0 |
| 43055134 | VKORC1 gene c.1173C>T [Presence] in Blood or Tissue by Molecular genetics method | 0.770 |  | 0 |      0 |
| 1091607 | Hereditary platelet function defect multigene analysis in Blood by Molecular genetics method | 0.770 |  | 0 |      0 |
| 37020002 | Multiple myeloma minimal residual disease panel - Bone marrow by Flow cytometry (FC) | 0.770 |  | 0 |      0 |
| 1761572 | NUDT15 gene c.52G>A [Presence] in Blood by Molecular genetics method | 0.769 |  | 0 |      0 |
| 3052934 | PTEN gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.769 |  | 0 |      0 |
| 21493179 | Pharmacogenomics result panel | 0.768 |  | 0 |      0 |
| 40765086 | Chromosome analysis.interphase panel - Blood by FISH | 0.767 |  | 0 |      0 |
| 3038980 | VWF gene.p.Thr791Met [Presence] in Blood by Molecular genetics method | 0.766 |  | 0 |      0 |
| 1091377 | Hereditary platelet disorders multigene analysis in Blood or Tissue by Molecular genetics method | 0.764 |  | 0 |      0 |
| 40758371 | HBB gene c.20A>T [Presence] in Blood by Molecular genetics method | 0.764 |  | 0 |      0 |
| 3049122 | Sequencing methodology panel - Blood or Tissue by Molecular genetics method | 0.763 |  | 0 |      0 |
| 40758367 | HBA2 gene c.429A>T [Presence] in Blood by Molecular genetics method | 0.763 |  | 0 |      0 |
| 3043969 | HADHA gene c.1528G>C [Presence] in Blood or Tissue by Molecular genetics method | 0.763 |  | 0 |      0 |
| 1989594 | Thrombotic microangiopathy multigene analysis in Blood or Tissue by Molecular genetics method | 0.761 |  | 0 |      0 |
| 3034581 | FMR1 gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.761 |  | 0 |      0 |
| 36659869 | Psychotropic medication pharmacogenomic analysis in Blood or Tissue by Molecular genetics method | 0.760 |  | 0 |      0 |
| 40758377 | HBB gene c.79G>A [Presence] in Blood by Molecular genetics method | 0.759 |  | 0 |      0 |
| 1761633 | HBA2 gene.c.377T>C [Presence] in Blood by Molecular genetics method | 0.759 |  | 0 |      0 |
| 40759888 | Lymphocytes/Leukocytes in Bronchial specimen by Flow cytometry (FC) | 0.756 |  | 0 |      0 |
| 42529039 | t(15;17)(q24.1;q21.1)(PML,RARA) fusion transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.755 |  | 1 |     49 |
| 3044798 | 18q chromosome deletion [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.755 |  | 0 |      0 |
| 3029715 | Chromosome analysis.interphase [Interpretation] in Bone marrow by FISH Narrative | 0.754 |  | 1 |    927 |
| 3045008 | CASR gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.752 |  | 0 |      0 |
| 40762018 | LCT gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.752 |  | 0 |      0 |
| 46236301 | C9orf72 gene GGGGCC repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.751 |  | 0 |      0 |
| 3030784 | F13A1 gene p.Val34Leu [Presence] in Blood or Tissue by Molecular genetics method | 0.750 |  | 0 |      0 |
| 1469794 | CD3+CD8+ (T8 suppressor) cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.750 |  | 0 |      0 |
| 3964769 | Acute myeloid leukemia panel - Blood or Tissue by FISH | 0.750 |  | 0 |      0 |
| 1092066 | VWF and GP1BA gene mutation analysis in Specimen by Molecular genetics method | 0.749 |  | 0 |      0 |
| 3040040 | HTT gene mutation panel - Blood or Tissue by Molecular genetics method | 0.748 |  | 0 |      0 |
| 40757579 | NPM1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.748 |  | 0 |      0 |
| 36303264 | APOB gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.748 |  | 0 |      0 |
| 1616983 | Plasma cell proliferation analysis in Bone marrow by FISH | 0.748 |  | 0 |      0 |
| 3051038 | Chromosome [Identifier] in Blood or Tissue by Molecular genetics method | 0.747 |  | 0 |      0 |
| 21493139 | C9orf72 gene GGGGCC repeat analysis in Blood or Tissue by Molecular genetics method | 0.746 |  | 0 |      0 |
| 3050912 | CILD2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.746 |  | 0 |      0 |
| 40760429 | SRY gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.746 |  | 0 |      0 |
| 42870522 | Lymphocyte proliferation antigen panel - Blood by Flow cytometry (FC) | 0.745 |  | 0 |      0 |
| 3040586 | VWF gene.p.Arg854Gln [Presence] in Blood or Tissue by Molecular genetics method | 0.745 |  | 0 |      0 |
| 3044481 | Immunodeficiency panel - Blood by Flow cytometry (FC) | 0.744 |  | 0 |      0 |
| 3041430 | GLA gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.744 |  | 0 |      0 |
| 1469804 | Lymphocytes/Cells in Bronchoalveolar lavage | 0.744 |  | 0 |      0 |
| 43054955 | t(15;17)(q24.1;q21.1)(PML,RARA) bcr1 fusion transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.742 |  | 0 |      0 |
| 3028927 | DYS gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.740 |  | 0 |      0 |
| 40759279 | PCSK9 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.739 |  | 0 |      0 |
| 3041893 | Gene XXX mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.737 |  | 0 |      0 |
| 40769150 | CYP2C19 gene targeted mutation analysis in Blood by Molecular genetics method | 0.736 |  | 0 |      0 |
| 21494571 | CNBP gene CCTG repeat analysis in Blood or Tissue by Molecular genetics method | 0.736 |  | 0 |      0 |
| 1616714 | Lymphocyte T-cell and B-cell and Natural killer subsets panel - Lower respiratory specimen by Flow cytometry (FC) | 0.736 |  | 0 |      0 |
| 40758373 | HPFH-6 gene [Presence] in Blood by Molecular genetics method | 0.733 |  | 0 |      0 |
| 1259598 | Other cells/Leukocytes in Bronchoalveolar lavage by Manual count | 0.733 |  | 0 |      0 |
| 3034564 | CLA2 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.733 |  | 0 |      0 |
| 3035309 | COL3A1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.733 |  | 0 |      0 |
| 1176291 | B-cell phenotyping panel - Blood | 0.732 |  | 0 |      0 |
| 37020870 | LPA gene.c.3947+467T>C [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.732 |  | 0 |      0 |
| 3015816 | F5 gene p.Arg506Gln [Presence] in Blood or Tissue by Molecular genetics method | 0.732 |  | 1 |  8,102 |
| 43533772 | APOB gene p.Arg3500Gln and p.Arg3500Trp [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.731 |  | 0 |      0 |
| 40762140 | F5 gene p.His1299Arg [Presence] in Blood or Tissue by Molecular genetics method | 0.731 |  | 0 |      0 |
| 43534045 | MCM6 gene c.-13910C>T and -13915T>G [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.729 |  | 1 | 27,787 |
| 3033034 | Cytology report of Bronchoalveolar lavage Cyto stain | 0.729 |  | 0 |      0 |
| 1616318 | PALB2 gene deletion and duplication mutation analysis [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.729 |  | 0 |      0 |
| 40759889 | Neutrophils/Leukocytes in Bronchial specimen by Flow cytometry (FC) | 0.728 |  | 0 |      0 |
| 46236486 | CLRN1 gene c.144T>G [Presence] in Blood or Tissue by Molecular genetics method | 0.728 |  | 0 |      0 |
| 1469835 | Neutrophils/Cells in Bronchoalveolar lavage | 0.728 |  | 0 |      0 |
| 3965536 | Acute myeloid leukemia minimal residual disease in Bone marrow by Flow cytometry (FC) Narrative | 0.727 |  | 0 |      0 |
| 46236487 | DLD gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.727 |  | 0 |      0 |
| 44786878 | Immunohistochemical stains in Bone marrow Narrative | 0.725 |  | 0 |      0 |
| 46235490 | CYP1A2 gene c.5090C>T [Presence] in Blood or Tissue by Molecular genetics method | 0.725 |  | 0 |      0 |
| 40758366 | HBA2 gene c.427T>C [Presence] in Blood by Molecular genetics method | 0.725 |  | 0 |      0 |
| 46235518 | HTR2C gene c.-759C>T [Presence] in Blood or Tissue by Molecular genetics method | 0.723 |  | 0 |      0 |
| 3041491 | F9 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.723 |  | 0 |      0 |
| 40765108 | Chromosome analysis panel by FISH | 0.723 |  | 0 |      0 |
| 3040425 | VWF gene p.Arg816Trp [Presence] in Blood or Tissue by Molecular genetics method | 0.722 |  | 0 |      0 |
| 40757356 | Immune response panel - Specimen by Flow cytometry (FC) | 0.722 |  | 0 |      0 |
| 40762358 | Karyotype [Identifier] in Blood or Tissue by FISH Narrative | 0.720 |  | 0 |      0 |
| 3029862 | FXN gene allele 1.GAA repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.717 |  | 0 |      0 |
| 1001565 | NOP56 gene GGCCTG repeats [Presence] in Blood or Tissue by Molecular genetics method | 0.717 |  | 0 |      0 |
| 1988274 | Cells Counted Total [#] in Bronchoalveolar lavage | 0.717 |  | 0 |      0 |
| 3007532 | FXN gene GAA repeats [Presence] in Blood or Tissue by Molecular genetics method | 0.714 |  | 0 |      0 |
| 3028968 | FXN gene allele 2.GAA repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.714 |  | 0 |      0 |
| 3965853 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Blood or Marrow by Flow cytometry (FC) | 0.711 |  | 0 |      0 |
| 36660048 | Chromosome region 14q32 rearrangements in Bone marrow by FISH | 0.711 |  | 0 |      0 |
| 40765112 | FISH probe locus [Identifier] in Laboratory device | 0.711 |  | 0 |      0 |
| 1469867 | Monocytes/Cells in Bronchoalveolar lavage | 0.711 |  | 0 |      0 |
| 3965372 | Myeloid sarcoma analysis in Blood or Tissue by FISH | 0.711 |  | 0 |      0 |
| 1761610 | FCGR3A gene.p.Phe176Val [Presence] in Blood or Tissue by Molecular genetics method | 0.711 |  | 0 |      0 |
| 645216 | T-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.710 |  | 0 |      0 |
| 44786887 | Cellularity assessment in Bone marrow Narrative | 0.709 |  | 0 |      0 |
| 648549 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.708 |  | 0 |      0 |
| 3049538 | Subtelomere analysis [Identifier] in Blood or Tissue by FISH Nominal | 0.708 |  | 0 |      0 |
| 21492572 | FISH probe target gene [Identifier] in Laboratory device | 0.708 |  | 0 |      0 |
| 1259483 | Plasma cell myeloma multigene analysis in Bone marrow by Molecular genetics method | 0.707 |  | 0 |      0 |
| 1259666 | TCL-1A gene rearrangements in Bone marrow by FISH | 0.705 |  | 0 |      0 |
| 3051861 | Differential panel - Bone marrow | 0.705 |  | 0 |      0 |
| 649098 | B-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.704 |  | 0 |      0 |
| 1469516 | Myelodysplastic neoplasm chromosome analysis in Blood or Marrow by FISH | 0.704 |  | 0 |      0 |
| 1002351 | Plasma cell DNA content and proliferation panel - Bone marrow by Flow cytometry (FC) | 0.704 |  | 0 |      0 |
| 1469497 | Basophils/Cells in Bronchoalveolar lavage | 0.703 |  | 0 |      0 |
| 40759151 | Karyotype [Identifier] in Urine by FISH Narrative | 0.703 |  | 0 |      0 |
| 1469942 | Alveolar macrophages/cells in Bronchoalveolar lavage | 0.703 |  | 0 |      0 |
| 1001970 | Monotypic plasma cell identification and risk stratification panel - Bone marrow by Molecular genetics method | 0.703 |  | 0 |      0 |
| 3964908 | in Blood or Tissue by FISH | 0.702 |  | 0 |      0 |
| 3029944 | CD15 Ag [Presence] in Bone marrow by Immune stain | 0.701 |  | 0 |      0 |
| 1259729 | D13S319 deletion in Bone marrow by FISH | 0.700 |  | 0 |      0 |
| 3029572 | Lymphoblasts/Leukocytes in Bone marrow by Manual count | 0.698 |  | 0 |      0 |
| 36304552 | Cytomegalovirus Ag [Presence] in Bone marrow by Immunofluorescence | 0.697 |  | 0 |      0 |
| 3966104 | Acute myeloid leukemia in Blood or Tissue by FISH | 0.694 |  | 0 |      0 |
| 21492681 | FISH probe target locus [Identifier] in Laboratory device | 0.693 |  | 0 |      0 |
| 40765111 | FISH probe gene name [Identifier] in Laboratory device | 0.693 |  | 0 |      0 |
| 40765089 | Chromosome analysis panel - Blood by G-banded | 0.693 |  | 1 |  1,888 |
| 3964901 | B-cell acute lymphoblastic leukemia in Blood or Tissue by FISH | 0.693 |  | 0 |      0 |
| 1260094 | TRCA+TCRD gene rearrangements in Bone marrow by FISH | 0.693 |  | 0 |      0 |
| 3964606 | B-cell acute lymphocytic leukemia in Blood or Tissue by FISH | 0.692 |  | 0 |      0 |
| 40765113 | FISH probe vendor [Identifier] in Laboratory device | 0.689 |  | 0 |      0 |
| 44786888 | Blasts assessment in Bone marrow Narrative | 0.689 |  | 0 |      0 |
| 3966274 | FUS gene rearrangements in Blood or Tissue by FISH | 0.688 |  | 0 |      0 |
| 43055187 | t(12;21)(p13;q22.3)(ETV6,RUNX1) fusion transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.688 |  | 1 |     24 |
| 44786882 | Other observations in Bone marrow Narrative | 0.687 |  | 0 |      0 |
| 1988760 | Siderocytes panel - Blood or Marrow by Prussian blue stain | 0.685 |  | 0 |      0 |
| 36305535 | Cytomegalovirus DNA [Presence] in Bone marrow by NAA with probe detection | 0.684 |  | 0 |      0 |
| 1260006 | Clonal cells rearrangements/Cells counted in Specimen by Molecular genetics method | 0.683 |  | 0 |      0 |
| 36305433 | Neutrophil cytoplasmic Ab panel - Serum by Immunofluorescence | 0.682 |  | 0 |      0 |
| 40762143 | Chromosome analysis.interphase [Interpretation] in Specimen by FISH Narrative | 0.678 |  | 0 |      0 |
| 645931 | Lymphocytes [#/volume] in Bone marrow by Flow cytometry (FC) | 0.677 |  | 0 |      0 |
| 44786883 | Myelopoiesis assessment in Bone marrow Narrative | 0.677 |  | 0 |      0 |
| 21492682 | Vendor FISH product name [Identifier] in Blood or Tissue | 0.677 |  | 0 |      0 |
| 44786880 | Cytochemical stains in Bone marrow Narrative | 0.675 |  | 0 |      0 |
| 40760874 | Microscopic exam [Interpretation] of Bone marrow by Cytology | 0.674 |  | 0 |      0 |
| 3044056 | CD20+FMC7+ cells [#/volume] in Bone marrow | 0.673 |  | 0 |      0 |
| 44786886 | Erythropoiesis assessment in Bone marrow Narrative | 0.672 |  | 0 |      0 |
| 1091032 | Multiple myeloma minimal residual disease analysis [Presence] in Bone marrow by NAA with non-probe detection | 0.672 |  | 0 |      0 |
| 40768791 | Bone Pathology biopsy report | 0.672 |  | 0 |      0 |
| 3029966 | CD117 Ag [Presence] in Bone marrow by Immune stain | 0.672 |  | 0 |      0 |
| 3019193 | t(2;5)(p23;q35.1)(ALK,NPM1) cells/Cells.total in Blood or Tissue by Molecular genetics method | 0.670 |  | 0 |      0 |
| 43054954 | t(15;17)(q24.1;q21.1)(PML,RARA) bcr2 fusion transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.664 |  | 0 |      0 |
| 3029831 | Pneumocystis jirovecii DNA [#/volume] in Bone marrow by NAA with probe detection | 0.659 |  | 0 |      0 |
| 3018543 | Iron.microscopic observation [Identifier] in Bone marrow by Potassium ferrocyanide stain | 0.655 |  | 0 |      0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1611 | -ctr-d |  | 115 | 100 |  |  |  | DNA test |  | FALSE |
| 1612 | -fishhyb | form | 48 | 100 |  |  |  |  | FISH analysis [Identifier] in Unspecified specimen | FALSE |
| 1613 | -fishhyb |  | 174 | 100 |  |  |  |  | FISH analysis [Identifier] in Unspecified specimen | FALSE |
| 1614 | b-apoe-d |  | 146 | 100 |  | B -Apolipoproteiini E, DNA-tutkimus | Blood | DNA test | Apolipoprotein E gene [Identifier] in Blood by Molecular genetics method | FALSE |
| 1615 | b-aso2-qd |  | 102 | 100 |  |  | Blood |  |  | FALSE |
| 1616 | b-atrytyd | form | 7 | 100 |  | B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus | Blood |  | SERPINA1 gene [Identifier] in Blood by Molecular genetics method | FALSE |
| 1617 | b-atrytyd |  | 283 | 100 |  | B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus | Blood |  | SERPINA1 gene [Identifier] in Blood by Molecular genetics method | FALSE |
| 1618 | b-auria10 |  | 1807 | 100 |  |  | Blood |  |  | FALSE |
| 1619 | b-bcr-qr | form | 159 | 100 |  | B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Blood |  | BCR-ABL1 fusion gene/Control gene [# Ratio] in Blood by NAA with probe detection | FALSE |
| 1620 | b-bcr-qr |  | 1562 | 100 |  | B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Blood |  | BCR-ABL1 fusion gene/Control gene [# Ratio] in Blood by NAA with probe detection | FALSE |
| 1621 | b-blapcr |  | 138 | 100 |  |  | Blood |  |  | FALSE |
| 1622 | b-bo3-d |  | 963 | 100 |  |  | Blood | DNA test |  | FALSE |
| 1623 | b-brcay-d |  | 519 | 100 |  |  | Blood | DNA test | BRCA1+BRCA2 gene mutations found [Identifier] in Blood by Molecular genetics method | TRUE |
| 1624 | b-brovcore |  | 356 | 100 |  |  | Blood |  |  | FALSE |
| 1625 | b-calr-d |  | 421 | 100 |  |  | Blood | DNA test | CALR gene mutation analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1626 | b-cmlpcr |  | 553 | 100 |  |  | Blood |  | BCR-ABL1 fusion gene/Control gene [# Ratio] in Blood by NAA with probe detection | FALSE |
| 1627 | b-crco |  | 3627 | 100 |  |  | Blood |  |  | FALSE |
| 1628 | b-crcoti |  | 1359 | 100 |  |  | Blood |  |  | FALSE |
| 1629 | b-dm2alld | form | 19 | 100 |  | B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus | Blood |  | ZNF9 gene repeat analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1630 | b-dm2alld |  | 149 | 100 |  | B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus | Blood |  | ZNF9 gene repeat analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1631 | b-dpyd-d | form | 211 | 100 |  |  | Blood | DNA test | DPYD gene mutation analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1632 | b-dpyd-d |  | 3111 | 100 |  |  | Blood | DNA test | DPYD gene mutation analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1633 | b-dpydl-d |  | 101 | 100 |  |  | Blood | DNA test | DPYD gene mutation analysis panel - Blood by Molecular genetics method | TRUE |
| 1634 | b-exkon-d |  | 147 | 100 |  |  | Blood | DNA test |  | FALSE |
| 1635 | b-extri-d |  | 136 | 100 |  |  | Blood | DNA test |  | FALSE |
| 1636 | b-farma-d |  | 594 | 100 |  |  | Blood | DNA test | Pharmacogenomic panel - Blood by Molecular genetics method | TRUE |
| 1637 | b-farml-d |  | 190 | 100 |  |  | Blood | DNA test | Pharmacogenomic panel - Blood by Molecular genetics method | TRUE |
| 1638 | b-fii-d | form | 138 | 100 |  | B -Protrombiinigeeni, DNA-tutkimus | Blood | DNA test | Coagulation factor II gene.G20210A mutation [Presence] in Blood by Molecular genetics method | FALSE |
| 1639 | b-fii-d |  | 7712 | 100 |  | B -Protrombiinigeeni, DNA-tutkimus | Blood | DNA test | Coagulation factor II gene.G20210A mutation [Presence] in Blood by Molecular genetics method | FALSE |
| 1640 | b-finngen |  | 736 | 100 |  |  | Blood |  |  | FALSE |
| 1641 | b-fishhem |  | 130 | 100 |  | B -Hematologinen fluoresenssi in situ hybridisaatio, veri | Blood |  | FISH for hematologic disorders panel - Blood | TRUE |
| 1642 | b-frax-d | form | 5 | 100 |  | B -Fragiili-X,-FMR1-geenin DNA-tutkimus | Blood | DNA test | FMR1 gene CGG repeat number [Identifier] in Blood by Molecular genetics method | FALSE |
| 1643 | b-frax-d |  | 347 | 100 |  | B -Fragiili-X,-FMR1-geenin DNA-tutkimus | Blood | DNA test | FMR1 gene CGG repeat number [Identifier] in Blood by Molecular genetics method | FALSE |
| 1644 | b-fuus-mr | form | 26 | 100 |  |  | Blood |  |  | FALSE |
| 1645 | b-fuus-mr |  | 177 | 100 |  |  | Blood |  |  | FALSE |
| 1646 | b-fv-d | form | 139 | 100 |  | B -Hyytymistekijä V geeni, DNA-tutkimus | Blood | DNA test | Coagulation factor V gene.Leiden mutation [Presence] in Blood by Molecular genetics method | FALSE |
| 1647 | b-fv-d |  | 8156 | 100 |  | B -Hyytymistekijä V geeni, DNA-tutkimus | Blood | DNA test | Coagulation factor V gene.Leiden mutation [Presence] in Blood by Molecular genetics method | FALSE |
| 1648 | b-fvfii-d | form | 52 | 100 |  |  | Blood | DNA test | Thrombophilia DNA mutation analysis panel - Blood by Molecular genetics method | TRUE |
| 1649 | b-fvfii-d |  | 765 | 100 |  |  | Blood | DNA test | Thrombophilia DNA mutation analysis panel - Blood by Molecular genetics method | TRUE |
| 1650 | b-hfe-d |  | 730 | 100 |  | B -Periytyvään hemokromatoosiin liittyvien HFE-geenin valtamutaatioiden tutkimus | Blood | DNA test | HFE gene mutations found [Identifier] in Blood by Molecular genetics method | FALSE |
| 1651 | b-hnpcy-d |  | 175 | 100 |  | B -Periytyvä ei-polypoottinen paksusuolisyöpä (HNPCC), MLH1-, MSH2- tai MSH6-geenin yksittäisen mutaation DNA-tutkimus | Blood | DNA test | Hereditary nonpolyposis colon cancer gene targeted mutation analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1652 | b-jak2-d | form | 139 | 100 |  | B -JAK2-geenin mutaatio, DNA-tutkimus | Blood | DNA test | JAK2 gene.V617F mutation [Presence] in Blood by Molecular genetics method | FALSE |
| 1653 | b-jak2-d |  | 5494 | 100 |  | B -JAK2-geenin mutaatio, DNA-tutkimus | Blood | DNA test | JAK2 gene.V617F mutation [Presence] in Blood by Molecular genetics method | FALSE |
| 1654 | b-kim-d |  | 197 | 100 |  |  | Blood | DNA test |  | FALSE |
| 1655 | b-kim-fd |  | 1367 | 100 |  |  | Blood |  |  | FALSE |
| 1656 | b-kml-qr |  | 1809 | 100 |  |  | Blood |  | BCR-ABL1 fusion gene/Control gene [# Ratio] in Blood by NAA with probe detection | FALSE |
| 1657 | b-lakt-d | form | 18 | 77.78 |  | B -Laktoosi-intoleranssi, DNA-tutkimus | Blood | DNA test | Lactase gene.C-13910T [Identifier] in Blood by Molecular genetics method | FALSE |
| 1658 | b-lakt-d |  | 27791 | 100 |  | B -Laktoosi-intoleranssi, DNA-tutkimus | Blood | DNA test | Lactase gene.C-13910T [Identifier] in Blood by Molecular genetics method | FALSE |
| 1659 | b-ldlre-4 | form | 53 | 100 |  |  | Blood |  |  | FALSE |
| 1660 | b-ldlre-4 |  | 135 | 100 |  |  | Blood |  |  | FALSE |
| 1661 | b-ldlre-d |  | 1121 | 100 |  | B -LDL-reseptorigeenin mutaatio, DNA-tutkimus | Blood | DNA test | LDLR gene mutation analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1662 | b-ngs-d |  | 277 | 100 |  |  | Blood | DNA test |  | FALSE |
| 1663 | b-nphs1-d |  | 272 | 100 |  | B -Kongenitaali nefroosi (CNF), kahden NPHS1-geenin valtamutaation DNA-tutkimus | Blood | DNA test | NPHS1 gene targeted mutation analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1664 | b-pgx-d |  | 2778 | 100 |  |  | Blood | DNA test | Pharmacogenomic panel - Blood by Molecular genetics method | TRUE |
| 1665 | b-sekvy-d | form | 59 | 100 |  |  | Blood | DNA test |  | FALSE |
| 1666 | b-sekvy-d |  | 1268 | 100 |  |  | Blood | DNA test |  | FALSE |
| 1667 | b-tp53-d |  | 211 | 100 |  |  | Blood | DNA test | TP53 gene mutation analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1668 | b-tpmt-d | form | 30 | 100 |  |  | Blood | DNA test | TPMT gene mutation analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1669 | b-tpmt-d |  | 615 | 100 |  |  | Blood | DNA test | TPMT gene mutation analysis [Identifier] in Blood by Molecular genetics method | FALSE |
| 1670 | b-varfa-d |  | 643 | 100 |  | B -Varfariinin yksilölliseen annostukseen liittyvät VKORC1- ja CYP2C9-geenivariaatiot, DNA-tutkimus verestä | Blood | DNA test | CYP2C9 gene and VKORC1 gene panel - Blood by Molecular genetics method | TRUE |
| 1671 | b-ykrom-d | form | 7 | 100 |  | B -Y-kromosomin poikkeavuuksia | Blood | DNA test | Y chromosome microdeletions found [Identifier] in Blood by Molecular genetics method | FALSE |
| 1672 | b-ykrom-d |  | 142 | 100 |  | B -Y-kromosomin poikkeavuuksia | Blood | DNA test | Y chromosome microdeletions found [Identifier] in Blood by Molecular genetics method | FALSE |
| 1673 | bl-bal |  | 919 | 100 |  | Bl-Bronkoalveolaarinen lavaationäyte sairaalakohtainen ryhmätutkimus, jonka sisältö vaihtelee | Bronchoalveolar lavage |  | Bronchoalveolar lavage cell analysis panel - Bronchoalveolar lavage | TRUE |
| 1674 | bl-bal-1 |  | 3636 | 100 |  | Bl-Bronkoalveolaarinen huuhtelunäyte, solututkimus | Bronchoalveolar lavage |  | Bronchoalveolar lavage cell analysis panel - Bronchoalveolar lavage | TRUE |
| 1675 | bl-balfc |  | 397 | 100 |  |  | Bronchoalveolar lavage |  | Immunophenotyping panel - Bronchoalveolar lavage by Flow cytometry (FC) | TRUE |
| 1676 | bm-aso-qd |  | 224 | 100 |  |  | Bone marrow |  | Neoplastic cells.clone specific marker [# Ratio] in Bone marrow by NAA with probe detection | FALSE |
| 1677 | bm-aso2-qd | form | 6 | 100 |  |  | Bone marrow |  | Neoplastic cells.clone specific marker [# Ratio] in Bone marrow by NAA with probe detection | FALSE |
| 1678 | bm-aso2-qd |  | 511 | 100 |  |  | Bone marrow |  | Neoplastic cells.clone specific marker [# Ratio] in Bone marrow by NAA with probe detection | FALSE |
| 1679 | bm-aspir |  | 1994 | 98.65 |  |  | Bone marrow |  | Bone marrow aspirate report | FALSE |
| 1680 | bm-bcr-qr |  | 152 | 100 |  | Bm-BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Bone marrow |  | BCR-ABL1 fusion gene/Control gene [# Ratio] in Bone marrow by NAA with probe detection | FALSE |
| 1681 | bm-blapcr |  | 753 | 100 |  |  | Bone marrow |  |  | FALSE |
| 1682 | bm-bpvalm |  | 145 | 100 |  |  | Bone marrow |  |  | FALSE |
| 1683 | bm-fish | form | 48 | 100 |  |  | Bone marrow |  | FISH analysis [Identifier] in Bone marrow | FALSE |
| 1684 | bm-fish |  | 943 | 100 |  |  | Bone marrow |  | FISH analysis [Identifier] in Bone marrow | FALSE |
| 1685 | bm-fish-mm |  | 127 | 100 |  |  | Bone marrow |  | FISH for multiple myeloma panel - Bone marrow | TRUE |
| 1686 | bm-fish2 | form | 29 | 100 |  |  | Bone marrow |  | FISH analysis [Identifier] in Bone marrow | FALSE |
| 1687 | bm-fish2 |  | 81 | 100 |  |  | Bone marrow |  | FISH analysis [Identifier] in Bone marrow | FALSE |
| 1688 | bm-fishhem | form | 7 | 100 |  | Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin | Bone marrow |  | FISH for hematologic disorders panel - Bone marrow | TRUE |
| 1689 | bm-fishhem |  | 414 | 100 |  | Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin | Bone marrow |  | FISH for hematologic disorders panel - Bone marrow | TRUE |
| 1690 | bm-fishmm | form | 28 | 100 |  |  | Bone marrow |  | FISH for multiple myeloma panel - Bone marrow | TRUE |
| 1691 | bm-fishmm |  | 147 | 100 |  |  | Bone marrow |  | FISH for multiple myeloma panel - Bone marrow | TRUE |
| 1692 | bm-fishvar |  | 141 | 100 |  |  | Bone marrow |  |  | FALSE |
| 1693 | bm-flt3-d | form | 9 | 100 |  |  | Bone marrow | DNA test | FLT3 gene mutation analysis [Identifier] in Bone marrow by Molecular genetics method | FALSE |
| 1694 | bm-flt3-d |  | 138 | 100 |  |  | Bone marrow | DNA test | FLT3 gene mutation analysis [Identifier] in Bone marrow by Molecular genetics method | FALSE |
| 1695 | bm-fuus-mr | form | 14 | 100 |  |  | Bone marrow |  |  | FALSE |
| 1696 | bm-fuus-mr |  | 268 | 100 |  |  | Bone marrow |  |  | FALSE |
| 1697 | bm-fuus-qr | form | 21 | 100 |  |  | Bone marrow |  |  | FALSE |
| 1698 | bm-fuus-qr |  | 81 | 100 |  |  | Bone marrow |  |  | FALSE |
| 1699 | bm-mgg |  | 314 | 100 |  |  | Bone marrow |  | Microscopic observation [Identifier] in Bone marrow aspirate by MGG stain | FALSE |
| 1700 | bm-mggfe | form | 660 | 100 |  | Bm-Luuydintutkimus, MGG- ja rautavärjäys | Bone marrow |  | Bone marrow aspirate MGG and Iron stain panel - Bone marrow | TRUE |
| 1701 | bm-mggfe |  | 11527 | 100 |  | Bm-Luuydintutkimus, MGG- ja rautavärjäys | Bone marrow |  | Bone marrow aspirate MGG and Iron stain panel - Bone marrow | TRUE |
| 1702 | bm-mm-ift |  | 651 | 100 |  |  | Bone marrow |  | Immunophenotyping panel - Bone marrow by Immunofluorescence | TRUE |
| 1703 | bm-mmpcr |  | 128 | 100 |  |  | Bone marrow |  | Neoplastic cells.clone specific marker [# Ratio] in Bone marrow by NAA with probe detection | FALSE |
| 1704 | bm-morflkl |  | 278 | 100 |  |  | Bone marrow |  | Microscopic observation [Identifier] in Bone marrow aspirate by MGG stain | FALSE |
| 1705 | bm-mrd-all |  | 416 | 100 |  |  | Bone marrow |  | Leukemia, Acute lymphoblastic cells [# Ratio] in Bone marrow by Minimal residual disease method | FALSE |
| 1706 | bm-mrd-vs |  | 666 | 100 |  |  | Bone marrow |  |  | FALSE |
| 1707 | bm-mrdmut |  | 198 | 100 |  |  | Bone marrow |  | Neoplastic cells.clone specific marker [# Ratio] in Bone marrow by NAA with probe detection | FALSE |
| 1708 | bm-npm1-qd | form | 23 | 100 |  |  | Bone marrow |  | NPM1 gene mutation [# Ratio] in Bone marrow by NAA with probe detection | FALSE |
| 1709 | bm-npm1-qd |  | 182 | 100 |  |  | Bone marrow |  | NPM1 gene mutation [# Ratio] in Bone marrow by NAA with probe detection | FALSE |

