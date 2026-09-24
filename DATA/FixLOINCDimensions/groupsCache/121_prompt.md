[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass already inferred the six LOINC axes for each of these local Finnish lab codes. Your task is **not** to redo that work. It is to **correct the axis labels so they are real OMOP vocabulary terms**, using a shortlist of genuine candidates retrieved for each value.

# Why this pass exists

The earlier pass wrote each axis as free text. Measured against curated Finnish mappings, most values were real OMOP terms but the wrong one, and `has_component` in particular drifted off the controlled vocabulary entirely — roughly three quarters of its mismatches were near-miss paraphrases that do not exist anywhere in OMOP, e.g. `Transglutaminase IgA Ab` where OMOP has `Tissue Transglutaminase IgA`, or `gamma-Glutamyl transferase` where OMOP has `Gamma glutamyl transferase`.

A label that is one character off is worthless downstream: the mapping joins on exact axis values, so a near-miss fails just as hard as nonsense. Your job is to land each axis on the exact OMOP string.

# The Finnish laboratory coding system

Each national lab test has a 4-digit running number code and a short mnemonic abbreviation of at most 10 characters, built as:

    <system prefix> - <test abbreviation> [<suffix>]

- The **system prefix** is a 1-2 letter code for the specimen the sample came from, mostly from English words: `S` = serum, `P` = plasma, `B` = blood, `U` = urine, `Li` = cerebrospinal fluid, `F` = feces, `Ts` = tissue, `Pt` = patient (a whole-patient investigation), `fS`/`fP`/`fB` = fasting serum/plasma/blood, `dU` = 24-hour urine, `E` = erythrocyte, `L` = leukocyte.
- The **test abbreviation** is a mnemonic of the test's long Finnish name, occasionally an established international one (`CRP`, `TSH`).
- The optional **suffix** qualifies the result type or method: `-O` (qualitative/semi-quantitative), `-Ab` (antibodies), `-Ag` (antigen), `-Vi` (culture), `-Nh` (nucleic acid), `-Ion` (ionized), `-V` (free/unconjugated).

Finnish compounds run together: "transferriininrautakyllästeisyys" = transferrin iron saturation.

# What you are given

**The group table** — a markdown table, one row per local lab test/unit combination, with the columns:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty.
- `n` — number of records.
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available. The strongest single evidence for what a test really measures: a "sodium" code whose deciles read 0.32-0.40 is not sodium.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `has_component`, `has_property`, `has_method`, `has_system` — the **current, possibly wrong** axis values from the earlier pass.
- `has_scale_type`, `has_time_aspect`, `is_panel` — already drawn from closed lists in the earlier pass. Carry them through unchanged unless a row is plainly contradictory.

**The candidate tables** — one markdown table per free-text axis, listing for each distinct current value in this group the closest real OMOP terms from a semantic search over the LOINC vocabulary. Columns:

- `current` — the value the earlier pass produced. It repeats down the rows: every row with the same `current` is an alternative for that one value.
- `possible fix` — a real OMOP term you may replace it with. `(none scored >= ...)` means the search found nothing close enough, so that value has no suggested replacement.
- `score` — semantic similarity between `current` and `possible fix`, 0 to 1. **A score of 1.000 does NOT mean the two strings are identical** — the search is case-insensitive, so `Mass Fraction` scores 1.000 against the real OMOP term `Mass fraction`. Always compare the two strings character for character yourself.
- `n_codes` / `n_events` — how many curated Finnish lab codes use that term, and how many records they cover. **This is usage in Finland, not correctness.** Use it only to break ties between candidates that fit the evidence equally well; never to override what the row's own evidence says.

# How to decide

For each row and each of the four axes:

1. **If `possible fix` is character-for-character identical to `current`, keep it.** It is already an exact OMOP term; do not "improve" it. But if a row scores 1.000 while the two strings differ in any way — capitalisation, punctuation, spacing — **take the `possible fix`**: that column holds the real OMOP spelling and `current` does not. `Mass Fraction` must become `Mass fraction`.
2. **Otherwise pick the candidate that the row's own evidence supports** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix/suffix meanings. Prefer the exact OMOP spelling of the concept the code actually denotes.
3. **Where two candidates fit equally**, prefer the one with higher `n_codes`/`n_events` — Finland's established usage.
4. **If no candidate is right, leave the axis empty.** An empty axis is a correct, useful answer: it says "not knowable". A confidently wrong exact term is worse than nothing, because downstream code cannot tell it from a verified one.
5. **Never invent a value that is not in the candidate list.** The whole point of this pass is that only real OMOP terms survive. The one exception: if an axis is currently empty and the evidence genuinely supports no value, leave it empty.

Specific things to watch:

- **`has_system` was the worst axis in the earlier pass** (about 29% agreement). The recurring error is splitting `Serum or Plasma` into a bare `Serum` or `Plasma`. LOINC uses the combined `Serum or Plasma` for most chemistry, and only a genuinely serum-specific or plasma-specific test takes the narrow term. Let the code decide: an explicit `S` prefix means serum, `P` means plasma, and an ambiguous or absent prefix on a routine chemistry test usually means `Serum or Plasma`. Fasting is not part of the system: `fS` is still serum.
- **`has_component` drifts most.** Take the candidate's exact spelling, including its capitalisation and word order (`Gamma glutamyl transferase`, not `gamma-Glutamyl transferase`).
- **`has_method` is optional by design** and empty for most chemistry. If the earlier pass invented a method the code does not state, clear it.
- **`has_property`** follows the unit and the decile magnitude, not the analyte name: `g/l`, `mg/l`, `ug/l` are `Mass Concentration`; `mol/l`, `mmol/l`, `umol/l`, `nmol/l` are `Substance Concentration`; `U/l` is `Catalytic Concentration`.
- Never use the OMOP placeholder values `-`, `*` or `XXX`; leave the axis empty instead.

# Output

Return one entry per input row, with `row_id` echoed exactly and all seven fields. Return an entry for EVERY row, including ones you change nothing on — carrying a value through unchanged is a valid answer.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which corrections you made and why, where the candidate lists were unhelpful or missing the right term, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 121.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Alpha-1-antitrypsin gene | Alpha 1 antitrypsin | 0.846 | 5 | 7,846 |
| Alpha-1-antitrypsin gene | Alpha 1 antitrypsin Ag | 0.781 | 0 | 0 |
| Alpha-1-antitrypsin gene | Alpha 1 antitrypsin phenotype | 0.771 | 0 | 0 |
| Alpha-1-antitrypsin gene | Alpha 1 antitrypsin SS | 0.754 | 0 | 0 |
| Alpha-1-antitrypsin gene | Alpha-1-Antichymotrypsin | 0.754 | 0 | 0 |
| Apolipoprotein E gene | APOE gene | 0.913 | 0 | 0 |
| Apolipoprotein E gene | Apolipoprotein E | 0.873 | 0 | 0 |
| Apolipoprotein E gene | APOE gene gentoype | 0.808 | 0 | 0 |
| Apolipoprotein E gene | Apolipoprotein E4 | 0.792 | 0 | 0 |
| Apolipoprotein E gene | APOE gene allele 3 | 0.773 | 0 | 0 |
| BCR-ABL1 gene fusion transcript | BCR-ABL1 b2a2+b3a2 fusion transcript | 0.911 | 0 | 0 |
| BCR-ABL1 gene fusion transcript | BCR-ABL1 e1a2 fusion protein | 0.872 | 0 | 0 |
| BCR-ABL1 gene fusion transcript | BCR-ABL1 b2a2 fusion protein | 0.870 | 0 | 0 |
| BCR-ABL1 gene fusion transcript | BCR-ABL1 e1a1 fusion protein | 0.863 | 0 | 0 |
| BCR-ABL1 gene fusion transcript | BCR-ABL1 b3a2 fusion protein | 0.862 | 0 | 0 |
| Bone marrow aspirate cells | (none scored >= 0.75) |  |  |  |
| Bone marrow aspirate morphologic evaluation | Bone marrow aspiration report | 0.772 | 1 | 1,994 |
| BRCA1 and BRCA2 genes | BRCA2 gene | 0.817 | 0 | 0 |
| BRCA1 and BRCA2 genes | BRCA1 gene | 0.791 | 0 | 0 |
| BRCA1 and BRCA2 genes | BRCA1+BRCA2 gene | 0.779 | 0 | 0 |
| Bronchoalveolar lavage fluid analysis | (none scored >= 0.75) |  |  |  |
| CALR gene | CALR gene | 1.000 | 0 | 0 |
| CALR gene | CALR gene exon 9 | 0.851 | 0 | 0 |
| CALR gene | CALR gene exon 9 full mutation analysis | 0.802 | 0 | 0 |
| CALR gene | CALR gene exon 9 targeted mutation analysis | 0.799 | 0 | 0 |
| Cells | Cells | 1.000 | 1 | 1,262 |
| Coagulation factor II gene | (none scored >= 0.75) |  |  |  |
| Coagulation factor V gene | Coagulation factor V | 0.857 | 0 | 0 |
| Coagulation factor V gene | Coagulation factor V Ag | 0.786 | 0 | 0 |
| Coagulation factor V gene | Coagulation factor V activity | 0.764 | 0 | 0 |
| Coagulation factor V gene and Coagulation factor II gene | (none scored >= 0.75) |  |  |  |
| DPYD gene | DPYD gene | 1.000 | 0 | 0 |
| DPYD gene | DPYD2A gene | 0.943 | 0 | 0 |
| DPYD gene | DPYD gene.c.1236G>A | 0.848 | 0 | 0 |
| DPYD gene | DPYD gene.c.2846A>T | 0.839 | 0 | 0 |
| DPYD gene | DPYD gene.c.1679T>G | 0.836 | 0 | 0 |
| FLT3 gene | FLT3 gene | 1.000 | 0 | 0 |
| FLT3 gene | FLT3 gene internal tandem | 0.876 | 0 | 0 |
| FLT3 gene | FLT3 gene internal tandem duplication | 0.814 | 0 | 0 |
| FLT3 gene | FLT3 gene targeted mutation analysis | 0.813 | 1 | 138 |
| FLT3 gene | FLT3 gene p.Asp835 | 0.791 | 0 | 0 |
| FMR1 gene | FMR1 gene | 1.000 | 0 | 0 |
| FMR1 gene | FMR1 gene CGG | 0.881 | 0 | 0 |
| FMR1 gene | FMR1 gene methylation | 0.841 | 0 | 0 |
| FMR1 gene | FMR1 gene activation | 0.839 | 0 | 0 |
| FMR1 gene | FMR1 gene premutation | 0.824 | 0 | 0 |
| Fusion gene | (none scored >= 0.75) |  |  |  |
| Hematologic disorder associated gene panel | Hematologic malignancy gene fusion panel | 0.781 | 0 | 0 |
| HFE gene | HFE gene | 1.000 | 0 | 0 |
| HFE gene | HFE gene.p.Ser65Cys | 0.820 | 0 | 0 |
| HFE gene | HFE gene mutations tested for | 0.819 | 1 | 646 |
| HFE gene | HFE gene.p.Cys282Tyr | 0.816 | 0 | 0 |
| HFE gene | HFE gene c.187G>C | 0.814 | 0 | 0 |
| JAK2 gene | JAK2 gene | 1.000 | 0 | 0 |
| JAK2 gene | JAK3 gene | 0.873 | 0 | 0 |
| JAK2 gene | JAK2 gene exon 12 | 0.831 | 0 | 0 |
| JAK2 gene | JAK2 gene rearrangements | 0.828 | 0 | 0 |
| JAK2 gene | JAK2 gene exon 13 | 0.820 | 0 | 0 |
| LCT gene | LCT gene | 1.000 | 0 | 0 |
| LCT gene | LCT gene mutations tested for | 0.811 | 0 | 0 |
| LCT gene | LCT gene targeted mutation analysis | 0.789 | 0 | 0 |
| LDLR gene | LDLR gene | 1.000 | 0 | 0 |
| LDLR gene | LDLR gene full mutation analysis | 0.790 | 0 | 0 |
| LDLR gene | LDLR gene targeted mutation analysis | 0.787 | 0 | 0 |
| LDLR gene | APOB gene+LDLR gene | 0.766 | 0 | 0 |
| LDLR gene | LDLR gene deletion+duplication | 0.759 | 0 | 0 |
| Leukemia, Acute lymphoblastic.minimal residual disease | Acute myeloid leukemia minimal residual disease | 0.848 | 0 | 0 |
| Leukemia, Acute lymphoblastic.minimal residual disease | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection | 0.792 | 0 | 0 |
| Leukemia, Acute lymphoblastic.minimal residual disease | B-ALL minimal residual disease detection | 0.780 | 0 | 0 |
| Leukemia, Acute lymphoblastic.minimal residual disease | T-ALL minimal residual disease detection | 0.776 | 0 | 0 |
| Leukocyte panel | Leukogram panel | 0.847 | 0 | 0 |
| Leukocyte panel | Leukocyte morphology panel | 0.791 | 0 | 0 |
| Minimal residual disease | Measurable residual disease analysis | 0.801 | 0 | 0 |
| Minimal residual disease | Acute myeloid leukemia minimal residual disease | 0.779 | 0 | 0 |
| Minimal residual disease | CLL minimal residual disease detection | 0.766 | 0 | 0 |
| Minimal residual disease | Multiple myeloma minimal residual disease analysis | 0.756 | 0 | 0 |
| MLH1 or MSH2 or MSH6 gene | MLH1 gene | 0.867 | 0 | 0 |
| MLH1 or MSH2 or MSH6 gene | MLH1+MSH2+MSH6+PMS2 gene | 0.841 | 0 | 0 |
| MLH1 or MSH2 or MSH6 gene | MSH2 gene+MLH1 gene+MSH6 gene | 0.798 | 0 | 0 |
| MLH1 or MSH2 or MSH6 gene | MSH2 gene+MLH1 gene | 0.795 | 0 | 0 |
| MLH1 or MSH2 or MSH6 gene | MLH1 gene methylation | 0.770 | 0 | 0 |
| Multiple myeloma associated antigens | (none scored >= 0.75) |  |  |  |
| Multiple myeloma associated gene panel | Plasma cell myeloma multigene analysis | 0.790 | 0 | 0 |
| Multiple myeloma associated gene panel | Multiple myeloma minimal residual disease panel | 0.785 | 0 | 0 |
| NPHS1 gene | NPHS1 gene | 1.000 | 0 | 0 |
| NPHS1 gene | NPHS2 gene | 0.950 | 0 | 0 |
| NPHS1 gene | NPHS1 gene targeted mutation analysis | 0.788 | 0 | 0 |
| NPHS1 gene | NPHS2 gene targeted mutation analysis | 0.769 | 0 | 0 |
| NPM1 gene | NPM1 gene | 1.000 | 0 | 0 |
| NPM1 gene | NPM1 gene targeted mutation analysis | 0.819 | 0 | 0 |
| NPM1 gene | NPM1 gene c.956dupTCTG transcript | 0.809 | 0 | 0 |
| NPM1 gene | NPM1 gene.c.956dupTCTG transcript/control transcript | 0.787 | 0 | 0 |
| NPM1 gene | NPM1 gene c.960insCATG transcript | 0.786 | 0 | 0 |
| Pharmacogenomics panel | Pharmacogenomics result panel | 0.873 | 0 | 0 |
| Pharmacogenomics panel | Pharmacogenetic DNA analysis panel | 0.869 | 0 | 0 |
| Pharmacogenomics panel | Pharmacogenomic analysis basic associated observations panel | 0.824 | 0 | 0 |
| Pharmacogenomics panel | Pharmacogenomics section | 0.763 | 0 | 0 |
| Pharmacogenomics panel | Pharmacogenomics | 0.760 | 0 | 0 |
| TP53 gene | TP53 gene | 1.000 | 0 | 0 |
| TP53 gene | TP53 gene full mutation analysis | 0.786 | 0 | 0 |
| TP53 gene | p53 | 0.778 | 0 | 0 |
| TP53 gene | TP53 gene targeted mutation analysis | 0.775 | 0 | 0 |
| TP53 gene | P53 protein | 0.759 | 0 | 0 |
| TPMT gene | TPMT gene | 1.000 | 0 | 0 |
| TPMT gene | TPMT gene mutations tested for | 0.861 | 0 | 0 |
| TPMT gene | TPMT gene and NUDT15 gene | 0.850 | 0 | 0 |
| TPMT gene | TPMT gene targeted mutation analysis | 0.829 | 0 | 0 |
| TPMT gene | TPMT gene c.719A>G | 0.812 | 0 | 0 |
| Warfarin response genotype panel | Warfarin response genotype panel | 1.000 | 0 | 0 |
| Warfarin response genotype panel | CYP2C9 and VKORC1 panel | 0.767 | 0 | 0 |
| Y chromosome | Y chromosome | 1.000 | 0 | 0 |
| ZNF9 gene | (none scored >= 0.75) |  |  |  |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Cell count | (none scored >= 0.75) |  |  |  |
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Genotype | Genotype | 1.000 | 1 | 6,001 |
| Number Ratio | Number Ratio | 1.000 | 11 | 10,432 |
| Number Ratio | Relative Ratio | 0.783 | 9 | 5,970 |
| Number Ratio | Time Ratio | 0.769 | 0 | 0 |
| Presence or Identity | Presence or Identity | 1.000 | 79 | 1,946,967 |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Flow cytometry (FC) | Flow cytometry (FC) | 1.000 | 1 | 650 |
| Fluorescence in situ hybridization (FISH) | Fluorescent in situ hybridization (FISH) | 0.991 | 5 | 7,149 |
| Immunofluorescence (IF) | Immunofluorescence (IF) | 1.000 | 37 | 44,647 |
| Manual count | Manual count | 1.000 | 12 | 12,702 |
| May-Grunwald Giemsa stain | Giemsa stain.May-Grunwald | 0.850 | 0 | 0 |
| May-Grunwald Giemsa stain | Giemsa stain | 0.841 | 0 | 0 |
| May-Grunwald Giemsa stain | Wright Giemsa stain | 0.818 | 0 | 0 |
| May-Grunwald Giemsa stain | Modified Giemsa stain | 0.775 | 0 | 0 |
| Molecular genetics | Molecular genetics | 1.000 | 33 | 56,293 |
| Molecular genetics | Medical genetics | 0.765 | 0 | 0 |
| Nucleic acid amplification | Nucleic acid amplification with probe detection | 0.848 | 115 | 2,413,483 |
| Nucleic acid amplification | Nucleic acid amplification with non-probe detection | 0.810 | 1 | 7,786 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with probe detection | 1.000 | 115 | 2,413,483 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with non-probe detection | 0.864 | 1 | 7,786 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5a | 0.770 | 0 | 0 |
| Nucleic acid amplification with probe detection | Probe with amplification | 0.759 | 2 | 14,699 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5b | 0.754 | 0 | 0 |
| Sequencing | Sequencing | 1.000 | 3 | 15,218 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Bone marrow | Bone marrow | 1.000 | 18 | 26,597 |
| Bronchoalveolar lavage fluid | Bronchoalveolar lavage | 0.891 | 0 | 0 |
| Bronchoalveolar lavage fluid | Bronchoalveolar aspirate | 0.795 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1611 | -ctr-d |  | 115 | 100 |  |  |  | DNA test |  | Finding | Molecular genetics |  | Nar |  | FALSE |
| 1612 | -fishhyb | form | 48 | 100 |  |  |  |  |  | Finding | Fluorescence in situ hybridization (FISH) |  | Nar |  | FALSE |
| 1613 | -fishhyb |  | 174 | 100 |  |  |  |  |  | Finding | Fluorescence in situ hybridization (FISH) |  | Nar |  | FALSE |
| 1614 | b-apoe-d |  | 146 | 100 |  | B -Apolipoproteiini E, DNA-tutkimus | Blood | DNA test | Apolipoprotein E gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1615 | b-aso2-qd |  | 102 | 100 |  |  | Blood |  |  |  |  | Blood | Nar | Point in time (spot) | FALSE |
| 1616 | b-atrytyd | form | 7 | 100 |  | B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus | Blood |  | Alpha-1-antitrypsin gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1617 | b-atrytyd |  | 283 | 100 |  | B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus | Blood |  | Alpha-1-antitrypsin gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1618 | b-auria10 |  | 1807 | 100 |  |  | Blood |  |  |  |  | Blood |  | Point in time (spot) | TRUE |
| 1619 | b-bcr-qr | form | 159 | 100 |  | B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Blood |  | BCR-ABL1 gene fusion transcript | Number Ratio | Nucleic acid amplification with probe detection | Blood | OrdQn | Point in time (spot) | FALSE |
| 1620 | b-bcr-qr |  | 1562 | 100 |  | B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Blood |  | BCR-ABL1 gene fusion transcript | Number Ratio | Nucleic acid amplification with probe detection | Blood | OrdQn | Point in time (spot) | FALSE |
| 1621 | b-blapcr |  | 138 | 100 |  |  | Blood |  |  | Presence or Identity | Nucleic acid amplification | Blood | Nom | Point in time (spot) | FALSE |
| 1622 | b-bo3-d |  | 963 | 100 |  |  | Blood | DNA test |  | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1623 | b-brcay-d |  | 519 | 100 |  |  | Blood | DNA test | BRCA1 and BRCA2 genes | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | TRUE |
| 1624 | b-brovcore |  | 356 | 100 |  |  | Blood |  |  |  |  | Blood | Nar | Point in time (spot) | FALSE |
| 1625 | b-calr-d |  | 421 | 100 |  |  | Blood | DNA test | CALR gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1626 | b-cmlpcr |  | 553 | 100 |  |  | Blood |  |  | Presence or Identity | Nucleic acid amplification | Blood | Nom | Point in time (spot) | FALSE |
| 1627 | b-crco |  | 3627 | 100 |  |  | Blood |  |  |  |  | Blood | Nar | Point in time (spot) | FALSE |
| 1628 | b-crcoti |  | 1359 | 100 |  |  | Blood |  |  |  |  | Blood | Nar | Point in time (spot) | FALSE |
| 1629 | b-dm2alld | form | 19 | 100 |  | B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus | Blood |  | ZNF9 gene | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1630 | b-dm2alld |  | 149 | 100 |  | B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus | Blood |  | ZNF9 gene | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1631 | b-dpyd-d | form | 211 | 100 |  |  | Blood | DNA test | DPYD gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1632 | b-dpyd-d |  | 3111 | 100 |  |  | Blood | DNA test | DPYD gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1633 | b-dpydl-d |  | 101 | 100 |  |  | Blood | DNA test | DPYD gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | TRUE |
| 1634 | b-exkon-d |  | 147 | 100 |  |  | Blood | DNA test |  | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1635 | b-extri-d |  | 136 | 100 |  |  | Blood | DNA test |  | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1636 | b-farma-d |  | 594 | 100 |  |  | Blood | DNA test | Pharmacogenomics panel |  | Molecular genetics | Blood |  | Point in time (spot) | TRUE |
| 1637 | b-farml-d |  | 190 | 100 |  |  | Blood | DNA test | Pharmacogenomics panel |  | Molecular genetics | Blood |  | Point in time (spot) | TRUE |
| 1638 | b-fii-d | form | 138 | 100 |  | B -Protrombiinigeeni, DNA-tutkimus | Blood | DNA test | Coagulation factor II gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1639 | b-fii-d |  | 7712 | 100 |  | B -Protrombiinigeeni, DNA-tutkimus | Blood | DNA test | Coagulation factor II gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1640 | b-finngen |  | 736 | 100 |  |  | Blood |  |  |  |  | Blood |  | Point in time (spot) | TRUE |
| 1641 | b-fishhem |  | 130 | 100 |  | B -Hematologinen fluoresenssi in situ hybridisaatio, veri | Blood |  | Hematologic disorder associated gene panel |  | Fluorescence in situ hybridization (FISH) | Blood |  | Point in time (spot) | TRUE |
| 1642 | b-frax-d | form | 5 | 100 |  | B -Fragiili-X,-FMR1-geenin DNA-tutkimus | Blood | DNA test | FMR1 gene | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1643 | b-frax-d |  | 347 | 100 |  | B -Fragiili-X,-FMR1-geenin DNA-tutkimus | Blood | DNA test | FMR1 gene | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1644 | b-fuus-mr | form | 26 | 100 |  |  | Blood |  | Fusion gene | Presence or Identity |  | Blood | Nom | Point in time (spot) | FALSE |
| 1645 | b-fuus-mr |  | 177 | 100 |  |  | Blood |  | Fusion gene | Presence or Identity |  | Blood | Nom | Point in time (spot) | FALSE |
| 1646 | b-fv-d | form | 139 | 100 |  | B -Hyytymistekijä V geeni, DNA-tutkimus | Blood | DNA test | Coagulation factor V gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1647 | b-fv-d |  | 8156 | 100 |  | B -Hyytymistekijä V geeni, DNA-tutkimus | Blood | DNA test | Coagulation factor V gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1648 | b-fvfii-d | form | 52 | 100 |  |  | Blood | DNA test | Coagulation factor V gene and Coagulation factor II gene |  | Molecular genetics | Blood |  | Point in time (spot) | TRUE |
| 1649 | b-fvfii-d |  | 765 | 100 |  |  | Blood | DNA test | Coagulation factor V gene and Coagulation factor II gene |  | Molecular genetics | Blood |  | Point in time (spot) | TRUE |
| 1650 | b-hfe-d |  | 730 | 100 |  | B -Periytyvään hemokromatoosiin liittyvien HFE-geenin valtamutaatioiden tutkimus | Blood | DNA test | HFE gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1651 | b-hnpcy-d |  | 175 | 100 |  | B -Periytyvä ei-polypoottinen paksusuolisyöpä (HNPCC), MLH1-, MSH2- tai MSH6-geenin yksittäisen mutaation DNA-tutkimus | Blood | DNA test | MLH1 or MSH2 or MSH6 gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1652 | b-jak2-d | form | 139 | 100 |  | B -JAK2-geenin mutaatio, DNA-tutkimus | Blood | DNA test | JAK2 gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1653 | b-jak2-d |  | 5494 | 100 |  | B -JAK2-geenin mutaatio, DNA-tutkimus | Blood | DNA test | JAK2 gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1654 | b-kim-d |  | 197 | 100 |  |  | Blood | DNA test |  | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1655 | b-kim-fd |  | 1367 | 100 |  |  | Blood |  |  |  |  | Blood | Nar | Point in time (spot) | FALSE |
| 1656 | b-kml-qr |  | 1809 | 100 |  |  | Blood |  | BCR-ABL1 gene fusion transcript | Number Ratio | Nucleic acid amplification with probe detection | Blood | OrdQn | Point in time (spot) | FALSE |
| 1657 | b-lakt-d | form | 18 | 77.78 |  | B -Laktoosi-intoleranssi, DNA-tutkimus | Blood | DNA test | LCT gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1658 | b-lakt-d |  | 27791 | 100 |  | B -Laktoosi-intoleranssi, DNA-tutkimus | Blood | DNA test | LCT gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1659 | b-ldlre-4 | form | 53 | 100 |  |  | Blood |  | LDLR gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1660 | b-ldlre-4 |  | 135 | 100 |  |  | Blood |  | LDLR gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1661 | b-ldlre-d |  | 1121 | 100 |  | B -LDL-reseptorigeenin mutaatio, DNA-tutkimus | Blood | DNA test | LDLR gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1662 | b-ngs-d |  | 277 | 100 |  |  | Blood | DNA test |  |  | Sequencing | Blood |  | Point in time (spot) | TRUE |
| 1663 | b-nphs1-d |  | 272 | 100 |  | B -Kongenitaali nefroosi (CNF), kahden NPHS1-geenin valtamutaation DNA-tutkimus | Blood | DNA test | NPHS1 gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1664 | b-pgx-d |  | 2778 | 100 |  |  | Blood | DNA test | Pharmacogenomics panel |  | Molecular genetics | Blood |  | Point in time (spot) | TRUE |
| 1665 | b-sekvy-d | form | 59 | 100 |  |  | Blood | DNA test |  | Finding | Sequencing | Blood | Nar | Point in time (spot) | FALSE |
| 1666 | b-sekvy-d |  | 1268 | 100 |  |  | Blood | DNA test |  | Finding | Sequencing | Blood | Nar | Point in time (spot) | FALSE |
| 1667 | b-tp53-d |  | 211 | 100 |  |  | Blood | DNA test | TP53 gene | Finding | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1668 | b-tpmt-d | form | 30 | 100 |  |  | Blood | DNA test | TPMT gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1669 | b-tpmt-d |  | 615 | 100 |  |  | Blood | DNA test | TPMT gene | Genotype | Molecular genetics | Blood | Nom | Point in time (spot) | FALSE |
| 1670 | b-varfa-d |  | 643 | 100 |  | B -Varfariinin yksilölliseen annostukseen liittyvät VKORC1- ja CYP2C9-geenivariaatiot, DNA-tutkimus verestä | Blood | DNA test | Warfarin response genotype panel |  | Molecular genetics | Blood |  | Point in time (spot) | TRUE |
| 1671 | b-ykrom-d | form | 7 | 100 |  | B -Y-kromosomin poikkeavuuksia | Blood | DNA test | Y chromosome | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1672 | b-ykrom-d |  | 142 | 100 |  | B -Y-kromosomin poikkeavuuksia | Blood | DNA test | Y chromosome | Finding | Molecular genetics | Blood | Nar | Point in time (spot) | FALSE |
| 1673 | bl-bal |  | 919 | 100 |  | Bl-Bronkoalveolaarinen lavaationäyte sairaalakohtainen ryhmätutkimus, jonka sisältö vaihtelee | Bronchoalveolar lavage |  | Bronchoalveolar lavage fluid analysis |  |  | Bronchoalveolar lavage fluid |  | Point in time (spot) | TRUE |
| 1674 | bl-bal-1 |  | 3636 | 100 |  | Bl-Bronkoalveolaarinen huuhtelunäyte, solututkimus | Bronchoalveolar lavage |  | Cells |  | Manual count | Bronchoalveolar lavage fluid |  | Point in time (spot) | TRUE |
| 1675 | bl-balfc |  | 397 | 100 |  |  | Bronchoalveolar lavage |  | Leukocyte panel |  | Flow cytometry (FC) | Bronchoalveolar lavage fluid |  | Point in time (spot) | TRUE |
| 1676 | bm-aso-qd |  | 224 | 100 |  |  | Bone marrow |  |  |  |  | Bone marrow | Nar | Point in time (spot) | FALSE |
| 1677 | bm-aso2-qd | form | 6 | 100 |  |  | Bone marrow |  |  |  |  | Bone marrow | Nar | Point in time (spot) | FALSE |
| 1678 | bm-aso2-qd |  | 511 | 100 |  |  | Bone marrow |  |  |  |  | Bone marrow | Nar | Point in time (spot) | FALSE |
| 1679 | bm-aspir |  | 1994 | 98.65 |  |  | Bone marrow |  | Bone marrow aspirate morphologic evaluation |  |  | Bone marrow | Nar | Point in time (spot) | TRUE |
| 1680 | bm-bcr-qr |  | 152 | 100 |  | Bm-BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Bone marrow |  | BCR-ABL1 gene fusion transcript | Number Ratio | Nucleic acid amplification with probe detection | Bone marrow | OrdQn | Point in time (spot) | FALSE |
| 1681 | bm-blapcr |  | 753 | 100 |  |  | Bone marrow |  |  | Presence or Identity | Nucleic acid amplification | Bone marrow | Nom | Point in time (spot) | FALSE |
| 1682 | bm-bpvalm |  | 145 | 100 |  |  | Bone marrow |  |  |  |  | Bone marrow | Nar | Point in time (spot) | FALSE |
| 1683 | bm-fish | form | 48 | 100 |  |  | Bone marrow |  |  |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1684 | bm-fish |  | 943 | 100 |  |  | Bone marrow |  |  |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1685 | bm-fish-mm |  | 127 | 100 |  |  | Bone marrow |  | Multiple myeloma associated gene panel |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1686 | bm-fish2 | form | 29 | 100 |  |  | Bone marrow |  |  |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1687 | bm-fish2 |  | 81 | 100 |  |  | Bone marrow |  |  |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1688 | bm-fishhem | form | 7 | 100 |  | Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin | Bone marrow |  | Hematologic disorder associated gene panel |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1689 | bm-fishhem |  | 414 | 100 |  | Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin | Bone marrow |  | Hematologic disorder associated gene panel |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1690 | bm-fishmm | form | 28 | 100 |  |  | Bone marrow |  | Multiple myeloma associated gene panel |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1691 | bm-fishmm |  | 147 | 100 |  |  | Bone marrow |  | Multiple myeloma associated gene panel |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1692 | bm-fishvar |  | 141 | 100 |  |  | Bone marrow |  |  |  | Fluorescence in situ hybridization (FISH) | Bone marrow |  | Point in time (spot) | TRUE |
| 1693 | bm-flt3-d | form | 9 | 100 |  |  | Bone marrow | DNA test | FLT3 gene | Finding | Molecular genetics | Bone marrow | Nom | Point in time (spot) | FALSE |
| 1694 | bm-flt3-d |  | 138 | 100 |  |  | Bone marrow | DNA test | FLT3 gene | Finding | Molecular genetics | Bone marrow | Nom | Point in time (spot) | FALSE |
| 1695 | bm-fuus-mr | form | 14 | 100 |  |  | Bone marrow |  | Fusion gene | Presence or Identity |  | Bone marrow | Nom | Point in time (spot) | FALSE |
| 1696 | bm-fuus-mr |  | 268 | 100 |  |  | Bone marrow |  | Fusion gene | Presence or Identity |  | Bone marrow | Nom | Point in time (spot) | FALSE |
| 1697 | bm-fuus-qr | form | 21 | 100 |  |  | Bone marrow |  | Fusion gene | Number Ratio | Nucleic acid amplification | Bone marrow | OrdQn | Point in time (spot) | FALSE |
| 1698 | bm-fuus-qr |  | 81 | 100 |  |  | Bone marrow |  | Fusion gene | Number Ratio | Nucleic acid amplification | Bone marrow | OrdQn | Point in time (spot) | FALSE |
| 1699 | bm-mgg |  | 314 | 100 |  |  | Bone marrow |  | Bone marrow aspirate cells | Cell count | May-Grunwald Giemsa stain | Bone marrow | Nar | Point in time (spot) | TRUE |
| 1700 | bm-mggfe | form | 660 | 100 |  | Bm-Luuydintutkimus, MGG- ja rautavärjäys | Bone marrow |  | Bone marrow aspirate morphologic evaluation |  |  | Bone marrow |  | Point in time (spot) | TRUE |
| 1701 | bm-mggfe |  | 11527 | 100 |  | Bm-Luuydintutkimus, MGG- ja rautavärjäys | Bone marrow |  | Bone marrow aspirate morphologic evaluation |  |  | Bone marrow |  | Point in time (spot) | TRUE |
| 1702 | bm-mm-ift |  | 651 | 100 |  |  | Bone marrow |  | Multiple myeloma associated antigens |  | Immunofluorescence (IF) | Bone marrow |  | Point in time (spot) | TRUE |
| 1703 | bm-mmpcr |  | 128 | 100 |  |  | Bone marrow |  |  | Presence or Identity | Nucleic acid amplification | Bone marrow | Nom | Point in time (spot) | FALSE |
| 1704 | bm-morflkl |  | 278 | 100 |  |  | Bone marrow |  |  |  | Manual count | Bone marrow | Nar | Point in time (spot) | TRUE |
| 1705 | bm-mrd-all |  | 416 | 100 |  |  | Bone marrow |  | Leukemia, Acute lymphoblastic.minimal residual disease | Presence or Threshold |  | Bone marrow | Ord | Point in time (spot) | FALSE |
| 1706 | bm-mrd-vs |  | 666 | 100 |  |  | Bone marrow |  | Minimal residual disease | Presence or Threshold |  | Bone marrow | Ord | Point in time (spot) | FALSE |
| 1707 | bm-mrdmut |  | 198 | 100 |  |  | Bone marrow |  | Minimal residual disease | Finding | Molecular genetics | Bone marrow | Nom | Point in time (spot) | FALSE |
| 1708 | bm-npm1-qd | form | 23 | 100 |  |  | Bone marrow |  | NPM1 gene | Number Ratio | Nucleic acid amplification | Bone marrow | OrdQn | Point in time (spot) | FALSE |
| 1709 | bm-npm1-qd |  | 182 | 100 |  |  | Bone marrow |  | NPM1 gene | Number Ratio | Nucleic acid amplification | Bone marrow | OrdQn | Point in time (spot) | FALSE |

