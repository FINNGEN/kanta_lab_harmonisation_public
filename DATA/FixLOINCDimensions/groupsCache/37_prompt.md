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
Here is group 37.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Amphetamine and Methamphetamine enantiomers | (none scored >= 0.75) |  |  |  |
| Bacteria | Bacteria | 1.000 | 32 | 3,027,518 |
| Base excess | Base excess | 1.000 | 21 | 638,655 |
| Base excess | Base excess^^standard | 0.806 | 0 | 0 |
| Bone density study | Bone density | 0.809 | 0 | 0 |
| Bone density study | Bone density quantitative ultrasound study | 0.800 | 0 | 0 |
| C reactive protein | C reactive protein | 1.000 | 197 | 6,881,941 |
| Carbon dioxide | Carbon dioxide | 1.000 | 19 | 766,557 |
| Casts | Casts | 1.000 | 20 | 419,520 |
| Casts | Casts panel | 0.809 | 0 | 0 |
| Casts | Casts type not specified | 0.758 | 0 | 0 |
| CD4+ T-lymphocytes/T-lymphocytes | (none scored >= 0.75) |  |  |  |
| CD8+ T-lymphocytes/T-lymphocytes | CD8 cells | 0.754 | 0 | 0 |
| Chromosome analysis | Chromosome analysis | 1.000 | 0 | 0 |
| Chromosome analysis | Chromosome analysis panel | 0.855 | 4 | 3,505 |
| Chromosome analysis | Chromosome painting analysis | 0.805 | 0 | 0 |
| Chromosome analysis | Chromosome analysis.metaphase panel | 0.801 | 0 | 0 |
| Chromosome analysis | Chromosome analysis.interphase | 0.792 | 1 | 927 |
| Collagen type I beta-carboxyterminal telopeptide | Collagen crosslinked C-telopeptide | 0.811 | 3 | 1,772 |
| Collagen type I beta-carboxyterminal telopeptide | Collagen crosslinked N-telopeptide | 0.795 | 2 | 1,030 |
| Collagen type I beta-carboxyterminal telopeptide | Procollagen type I.N-terminal propeptide | 0.785 | 2 | 3,659 |
| Creatinine | Creatinine | 1.000 | 80 | 9,559,920 |
| Echocardiography study | Cardiac stress echo study | 0.767 | 0 | 0 |
| Epithelial cells | Epithelial cells | 1.000 | 24 | 278,115 |
| Epithelial cells | Epithelial cells/Cells | 0.887 | 0 | 0 |
| Epithelial cells | Epithelial cells.squamous | 0.792 | 4 | 227,680 |
| Epithelial cells | Epithelial cells.squamous/Cells | 0.790 | 0 | 0 |
| Epithelial cells | Epithelial cells.ciliated | 0.775 | 0 | 0 |
| Epstein-Barr virus DNA | Epstein-Barr Virus DNA | 1.000 | 0 | 0 |
| Epstein-Barr virus DNA | Epstein Barr virus DNA | 0.966 | 5 | 25,871 |
| Epstein-Barr virus DNA | Epstein Barr virus DNA panel | 0.816 | 0 | 0 |
| Epstein-Barr virus DNA | Cytomegalovirus+Epstein Barr virus DNA | 0.814 | 0 | 0 |
| Epstein-Barr virus DNA | Epstein-Barr Virus | 0.806 | 0 | 0 |
| Erythrocytes | Erythrocytes | 1.000 | 64 | 12,187,960 |
| Fetal DNA | Cell-free DNA.fetal | 0.804 | 0 | 0 |
| Fetal DNA | Cell-free DNA | 0.797 | 0 | 0 |
| Glucose | Glucose | 1.000 | 116 | 2,411,012 |
| Gram negative rod multi-drug resistant | Multiple drug resistant gram negative organism | 0.807 | 0 | 0 |
| Gram negative rod resistant | Gram negative bacterial resistance panel | 0.775 | 0 | 0 |
| Hemoglobin | Hemoglobin | 1.000 | 130 | 30,658,802 |
| Hemoglobin/Reticulocyte | Reticulocyte - RBC Hemoglobin | 0.823 | 0 | 0 |
| Hemoglobin/Reticulocyte | Reticulocytes/Erythrocytes | 0.762 | 3 | 135,278 |
| Hepatitis C virus RNA | Hepatitis C virus RNA | 1.000 | 7 | 9,029 |
| Hepatitis C virus RNA | Hepatitis C virus rRNA | 0.901 | 0 | 0 |
| Hepatitis C virus RNA | Hepatitis C virus DNA | 0.886 | 0 | 0 |
| Hepatitis C virus RNA | Hepatitis A virus RNA | 0.856 | 0 | 0 |
| Hepatitis C virus RNA | Hepatitis B virus RNA | 0.851 | 0 | 0 |
| Histology study | Histology | 0.817 | 0 | 0 |
| Histology study | Histology type | 0.753 | 0 | 0 |
| HIV 1+2 Ag+Ab | HIV 1+2 Ab | 0.929 | 2 | 231 |
| HIV 1+2 Ag+Ab | HIV 1+2 Ab+HIV1 p24 Ag | 0.927 | 1 | 776 |
| HIV 1+2 Ag+Ab | HIV 1 Ab+Ag | 0.903 | 0 | 0 |
| HIV 1+2 Ag+Ab | HIV 1+2 | 0.902 | 0 | 0 |
| HIV 1+2 Ag+Ab | HIV 1+2 Ab and HIV1 p24 Ag | 0.900 | 0 | 0 |
| Human papillomavirus 16 DNA | Human papilloma virus 16 DNA | 0.988 | 0 | 0 |
| Human papillomavirus 16 DNA | Human papilloma virus 16 and 18 DNA | 0.886 | 0 | 0 |
| Human papillomavirus 16 DNA | Human papilloma virus 16+18 DNA | 0.882 | 0 | 0 |
| Human papillomavirus 16 DNA | Human papilloma virus 16 | 0.877 | 0 | 0 |
| Human papillomavirus 16 DNA | Human papilloma virus 16+18+31+33+35+45+51+52+56 DNA | 0.851 | 0 | 0 |
| Human papillomavirus 18 DNA | Human papilloma virus 18 DNA | 0.986 | 0 | 0 |
| Human papillomavirus 18 DNA | Human papilloma virus 18 | 0.881 | 0 | 0 |
| Human papillomavirus 18 DNA | Human papilloma virus 16 and 18 DNA | 0.860 | 0 | 0 |
| Human papillomavirus 18 DNA | Human papilloma virus 16+18 DNA | 0.858 | 0 | 0 |
| Human papillomavirus 18 DNA | Human papilloma virus 58 DNA | 0.847 | 0 | 0 |
| Human papillomavirus high risk types other than 16 and 18 DNA | Human papilloma virus 16 and 18 and 31+33+35+39+45+51+52+56+58+59+66+68 DNA | 0.778 | 0 | 0 |
| Human papillomavirus high risk types other than 16 and 18 DNA | Human papilloma virus 16+18+31+33+35+39+45+51+52+56+58+59+68+70 DNA | 0.778 | 0 | 0 |
| Human papillomavirus high risk types other than 16 and 18 DNA | Human papilloma virus 16+18+31+33+35+39+45+51+52+56+58+68+70 DNA | 0.778 | 0 | 0 |
| Human papillomavirus high risk types other than 16 and 18 DNA | Human papilloma virus 16+18+31+33+35+39+45+51+52+56+58+59+68 DNA | 0.775 | 0 | 0 |
| Human papillomavirus high risk types other than 16 and 18 DNA | Human papilloma virus 16 and 18 DNA | 0.775 | 0 | 0 |
| Immunophenotyping | Immunophenotyping | 1.000 | 0 | 0 |
| Immunophenotyping | Immunophenotyping study | 0.876 | 0 | 0 |
| Immunophenotyping | Leukemia and lymphoma immunophenotyping | 0.787 | 0 | 0 |
| INR | INR | 1.000 | 88 | 2,812,069 |
| Ketones | Ketones | 1.000 | 18 | 935,210 |
| Leukocytes | Leukocytes | 1.000 | 126 | 12,024,159 |
| Leukocytes | Leukocytes other | 0.773 | 0 | 0 |
| Leukocytes | Abnormal leukocytes | 0.759 | 0 | 0 |
| Minimal residual disease | Measurable residual disease analysis | 0.801 | 0 | 0 |
| Minimal residual disease | Acute myeloid leukemia minimal residual disease | 0.779 | 0 | 0 |
| Minimal residual disease | CLL minimal residual disease detection | 0.766 | 0 | 0 |
| Minimal residual disease | Multiple myeloma minimal residual disease analysis | 0.756 | 0 | 0 |
| Natriuretic peptide.B N-Terminal Prohormone | Natriuretic peptide.B prohormone N-Terminal | 0.964 | 59 | 390,817 |
| Natriuretic peptide.B N-Terminal Prohormone | Natriuretic peptide B | 0.858 | 4 | 97,925 |
| Natriuretic peptide.B N-Terminal Prohormone | Natriuretic peptide | 0.825 | 0 | 0 |
| Neurophysiology study | Neurology study | 0.781 | 0 | 0 |
| Nitrite | Nitrite | 1.000 | 10 | 919,087 |
| Nitrite | Nitrate | 0.826 | 1 | 5,946 |
| Nitrite | Nitrate+Nitrite | 0.801 | 0 | 0 |
| NK cells/Leukocytes | (none scored >= 0.75) |  |  |  |
| Osmolality | Osmolality | 1.000 | 0 | 0 |
| Osmolality | Osmolarity | 0.908 | 0 | 0 |
| Osmolality | Osmolality^baseline | 0.792 | 0 | 0 |
| Osmolality | Osmolality.urine | 0.777 | 0 | 0 |
| Osmolality | Protein/Osmolality | 0.755 | 0 | 0 |
| Oxygen | Oxygen | 1.000 | 18 | 641,307 |
| Peak expiratory flow monitoring | Peak expiratory flow | 0.838 | 0 | 0 |
| Peak expiratory flow monitoring | Peak expiratory flow attempt | 0.795 | 0 | 0 |
| pH | pH | 1.000 | 92 | 2,272,494 |
| Potassium | Potassium | 1.000 | 61 | 7,976,034 |
| Protein | Protein | 1.000 | 36 | 586,844 |
| Pulmonary function test study | Pulmonary function study | 0.891 | 0 | 0 |
| Pulmonary function test study | Pulmonary studies | 0.786 | 0 | 0 |
| Pulmonary function test study | Pulmonary Function Tests | 0.785 | 0 | 0 |
| Pulmonary function test study | Pulmonary function test method | 0.774 | 0 | 0 |
| Sleep study | Polysomnography study | 0.793 | 5 | 69,533 |
| Sodium | Sodium | 1.000 | 63 | 7,836,829 |
| Staphylococcus aureus methicillin resistant | Staphylococcus species methicillin resistant | 0.895 | 0 | 0 |
| Staphylococcus aureus methicillin resistant | Methicillin resistant Staphylococcus aureus | 0.879 | 6 | 153,221 |
| Staphylococcus aureus methicillin resistant | Staphylococcus species methicillin resistant identified | 0.801 | 0 | 0 |
| Staphylococcus aureus methicillin resistant | Methicillin susceptible Staphylococcus aureus | 0.791 | 0 | 0 |
| Staphylococcus aureus methicillin resistant | Staphylococcus aureus and Methicillin Resistant Staphylococcus aureus | 0.777 | 0 | 0 |
| Troponin T | Troponin T | 1.000 | 0 | 0 |
| Troponin T | Troponin T.cardiac | 0.849 | 60 | 599,869 |
| Troponin T | Troponin T.cardiac delta | 0.762 | 0 | 0 |
| Troponin T | Troponin T.cardiac panel | 0.758 | 0 | 0 |
| Troponin T | Troponin I.cardiac | 0.755 | 25 | 323,924 |
| Yersinia species DNA | Yersinia sp DNA | 0.949 | 0 | 0 |
| Yersinia species DNA | Yersinia enterocolitica DNA | 0.912 | 0 | 0 |
| Yersinia species DNA | Yersinia pseudotuberculosis complex DNA | 0.850 | 0 | 0 |
| Yersinia species DNA | Yersinia pestis DNA | 0.817 | 0 | 0 |
| Yersinia species DNA | Yersina pestis DNA | 0.797 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Logarithmic scale | (none scored >= 0.75) |  |  |  |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Mass content | Mass Content | 1.000 | 11 | 184,195 |
| Number Concentration | Number Concentration | 1.000 | 507 | 49,434,956 |
| Number Fraction | Number Fraction | 1.000 | 482 | 8,246,054 |
| Number Fraction | Decimal number fraction | 0.787 | 1 | 6,152 |
| Number Fraction | Time Fraction | 0.765 | 0 | 0 |
| Osmolality | Osmolality | 1.000 | 42 | 260,031 |
| Osmolality | Osmolarity | 0.908 | 0 | 0 |
| Partial pressure | Partial pressure | 1.000 | 44 | 1,505,621 |
| Presence or Identity | Presence or Identity | 1.000 | 79 | 1,946,967 |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Relative time | Relative time | 1.000 | 144 | 3,365,485 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Automated count | Automated count | 1.000 | 103 | 11,606,924 |
| Cell block | (none scored >= 0.75) |  |  |  |
| Chromatography | (none scored >= 0.75) |  |  |  |
| Chromatography/Mass spectrometry | (none scored >= 0.75) |  |  |  |
| Coagulation assay | Coagulation assay | 1.000 | 181 | 3,646,966 |
| Dual-energy X-ray absorptiometry | Dual Energy X-ray Absorptiometry | 0.965 | 0 | 0 |
| Dual-energy X-ray absorptiometry | Dual Energy X-ray Absorptiometry (DXA) | 0.902 | 0 | 0 |
| Flow cytometry (FC) | Flow cytometry (FC) | 1.000 | 1 | 650 |
| Immunoassay | Immunoassay | 1.000 | 164 | 322,567 |
| Karyotype | (none scored >= 0.75) |  |  |  |
| Microscopy | Microscopy | 1.000 | 0 | 0 |
| Microscopy | Light microscopy | 0.815 | 13 | 53,782 |
| Molecular genetics | Molecular genetics | 1.000 | 33 | 56,293 |
| Molecular genetics | Medical genetics | 0.765 | 0 | 0 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with probe detection | 1.000 | 115 | 2,413,483 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with non-probe detection | 0.864 | 1 | 7,786 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5a | 0.770 | 0 | 0 |
| Nucleic acid amplification with probe detection | Probe with amplification | 0.759 | 2 | 14,699 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5b | 0.754 | 0 | 0 |
| Organism specific culture | Organism specific culture | 1.000 | 33 | 505,882 |
| Test strip | Test strip | 1.000 | 79 | 4,294,769 |
| Test strip | Test strip manual | 0.843 | 0 | 0 |
| Test strip | Test strip automated | 0.836 | 3 | 687,408 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| ^Patient | ^Patient | 1.000 | 20 | 396,517 |
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Blood capillary | Blood capillary | 1.000 | 121 | 787,125 |
| Blood capillary | Blood capillary^Fetus | 0.763 | 0 | 0 |
| Blood venous | Blood venous | 1.000 | 125 | 1,808,160 |
| Blood venous | Venous | 0.798 | 0 | 0 |
| Blood venous | Blood cord venous | 0.772 | 4 | 294 |
| Blood venous | Plasma venous | 0.752 | 0 | 0 |
| Blood venous | Blood central venous | 0.750 | 1 | 38,175 |
| Bone marrow | Bone marrow | 1.000 | 18 | 26,597 |
| Nasopharynx | Nasopharynx | 1.000 | 7 | 93,361 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Plasma capillary | Blood capillary | 0.751 | 121 | 787,125 |
| Pus | Pus | 1.000 | 0 | 0 |
| Red Blood Cells | Red Blood Cells | 1.000 | 100 | 38,219,166 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Serum or Plasma | Serum or Plasma | 1.000 | 2,776 | 78,327,842 |
| Serum or Plasma | Serum or Plasma or Urine | 0.832 | 0 | 0 |
| Serum or Plasma | Serum and Plasma | 0.819 | 0 | 0 |
| Serum or Plasma | Serum, Plasma or Blood | 0.816 | 84 | 6,240,111 |
| Serum or Plasma | Serum or Plasma and CSF | 0.792 | 4 | 1,187 |
| Stool | Stool | 1.000 | 42 | 537,967 |
| Stool | Stool.wet | 0.760 | 0 | 0 |
| Stool | Stool^Patient.gastrointestinal | 0.756 | 0 | 0 |
| Tissue | Tissue | 1.000 | 0 | 0 |
| Urine | Urine | 1.000 | 586 | 16,080,701 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 222 | -histologinensolublokkisytologisestanäytteestä |  | 214 | 100 |  |  |  |  | Histology study | Finding | Cell block | Tissue | Nar | Point in time (spot) | TRUE |
| 223 | -humanpapillomavirusgenotyyppi16 |  | 301 | 100 |  |  |  |  | Human papillomavirus 16 DNA | Presence or Identity | Molecular genetics |  | Ord | Point in time (spot) | FALSE |
| 224 | -humanpapillomavirusgenotyyppi18 |  | 301 | 100 |  |  |  |  | Human papillomavirus 18 DNA | Presence or Identity | Molecular genetics |  | Ord | Point in time (spot) | FALSE |
| 225 | -humanpapillomavirusgenotyyppimuupatogeeninenhpv |  | 252 | 100 |  |  |  |  | Human papillomavirus high risk types other than 16 and 18 DNA | Presence or Identity | Molecular genetics |  | Ord | Point in time (spot) | FALSE |
| 226 | -lisämaksukiireellisenäpyydetyllenäytteelle |  | 584 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 227 | -lisätutkimuspyyntöaiemmintutkitullenäytteelle |  | 191 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 228 | -lisävastaus2laskutuskuitatullenäytteelle |  | 438 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 229 | -lisävastauslaskutuskuitatullenäytteelle |  | 2865 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 230 | -moniresistentitgram-negatiivisetsauvat,viljely |  | 122 | 100 |  |  |  |  | Gram negative rod multi-drug resistant | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 231 | -moniresistentitgramnegatiivisetsauvat,viljely |  | 163 | 100 |  |  |  |  | Gram negative rod multi-drug resistant | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 232 | -resistentitgramnegatiivisetsauvat,viljely |  | 314 | 100 |  |  |  |  | Gram negative rod resistant | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 233 | -staphylococcusaureus,metilliiniresist.viljely |  | 248 | 100 |  |  |  |  | Staphylococcus aureus methicillin resistant | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 234 | -staphylococcusaureus,metisilliiniresistentti,v |  | 540 | 100 |  |  |  |  | Staphylococcus aureus methicillin resistant | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 235 | b-glukoosi,hoitoyksikönvieritesti,kokoveri |  | 687 | 0.15 | [5.55, 5.93, 6.7, 7.42, 8.33, 9.1, 10.22, 12.18, 14.28] |  | Blood |  | Glucose | Substance Concentration | Test strip | Blood | Qn | Point in time (spot) | FALSE |
| 236 | b-hematologisenpotilaanperuskaryotyypinmääritys |  | 125 | 100 |  |  | Blood |  | Chromosome analysis | Finding | Karyotype | Blood | Nar | Point in time (spot) | FALSE |
| 237 | b-kreatiniini,hoitoyksikönvieritesti,veri |  | 167 | 0 | [58.29, 69.03, 76.8, 84.73, 95.67, 105.12, 116.21, 134.79, 170] |  | Blood |  | Creatinine | Substance Concentration | Test strip | Blood | Qn | Point in time (spot) | FALSE |
| 238 | bakteerit,virtsasta,partikkelinlaskijalla,osatutk. |  | 212 | 100 |  |  |  |  | Bacteria | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 239 | bm-pahanlaatuisenveritaudinimmunofenotyypitys |  | 191 | 100 |  |  | Bone marrow |  | Immunophenotyping | Finding | Flow cytometry (FC) | Bone marrow | Nar | Point in time (spot) | TRUE |
| 240 | bm-pahanlaatuisenveritaudinimmunofenotyyppinenjäännöstautianalyysi |  | 162 | 100 |  |  | Bone marrow |  | Minimal residual disease | Finding | Flow cytometry (FC) | Bone marrow | Nar | Point in time (spot) | FALSE |
| 241 | cb-hemoglobiini,vieritestihoitoyksikössä | g/l | 101 | 0 | [84.5, 92.5, 100.5, 112.5, 121.56, 127.06, 131.83, 135.83, 146] |  | Capillary blood |  | Hemoglobin | Mass Concentration | Test strip | Blood capillary | Qn | Point in time (spot) | FALSE |
| 242 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä | mmol/l | 5203 | 0 | [5.2, 6.16, 6.92, 7.87, 8.89, 10.17, 11.74, 13.96, 16.77] |  |  |  | Glucose | Substance Concentration | Test strip | Plasma capillary | Qn | Point in time (spot) | FALSE |
| 243 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä |  | 19 | 100 | [5.33, 6.26, 7.1, 7.98, 9.1, 10.33, 11.92, 13.89, 16.96] |  |  |  | Glucose | Substance Concentration | Test strip | Plasma capillary | Qn | Point in time (spot) | FALSE |
| 244 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella | mg/l | 771 | 0 | [2.6, 5.17, 9.64, 14.69, 22, 32.29, 47.95, 69.4, 106.84] |  |  |  | C reactive protein | Mass Concentration | Immunoassay | Serum or Plasma | Qn | Point in time (spot) | FALSE |
| 245 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella |  | 192 | 85.42 |  |  |  |  | C reactive protein | Mass Concentration | Immunoassay | Serum or Plasma | Qn | Point in time (spot) | FALSE |
| 246 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 438 | 0 | [26.9, 30, 31.94, 33, 34, 34.57, 35, 36, 37.53] |  | Erythrocyte |  | Hemoglobin/Reticulocyte | Mass content | Automated count | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 247 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 15 | 6.67 |  |  | Erythrocyte |  | Hemoglobin/Reticulocyte | Mass content | Automated count | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 248 | emäsylimäärä,laskimoverestä,pikatesti␤ | mmol/l | 373 | 0 |  |  |  |  | Base excess | Substance Concentration |  | Blood venous | Qn | Point in time (spot) | FALSE |
| 249 | emäsylimäärä,laskimoverestä,pikatesti␤ |  | 339 | 19.47 |  |  |  |  | Base excess | Substance Concentration |  | Blood venous | Qn | Point in time (spot) | FALSE |
| 250 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 203 | 0 | [0.2, 0.4, 0.66, 1, 1.3, 1.71, 2.47, 3.65, 8.32] |  |  |  | Epithelial cells | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 251 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. |  | 9 | 100 |  |  |  |  | Epithelial cells | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 252 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta | iu/ml | 24 | 0 |  |  |  |  | Epstein-Barr virus DNA | Arbitrary Concentration | Nucleic acid amplification with probe detection | Plasma | Qn | Point in time (spot) | FALSE |
| 253 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta |  | 241 | 100 |  |  |  |  | Epstein-Barr virus DNA | Arbitrary Concentration | Nucleic acid amplification with probe detection | Plasma | Qn | Point in time (spot) | FALSE |
| 254 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 202 | 0 | [3.19, 4.28, 5.76, 7.13, 9.35, 12.16, 16.65, 32.02, 93.76] |  |  |  | Erythrocytes | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 255 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. |  | 10 | 100 |  |  |  |  | Erythrocytes | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 256 | fp-kollageenii:nbeta-karboksiterminaalinentelopeptidi | ug/l | 299 | 0 | [0.08, 0.14, 0.17, 0.21, 0.26, 0.3, 0.36, 0.45, 0.63] |  | Fasting plasma |  | Collagen type I beta-carboxyterminal telopeptide | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 257 | happamusaste,kapillaariverestä,pikatesti␤ |  | 1262 | 0.24 |  |  |  |  | pH | Logarithmic scale |  | Blood capillary | Qn | Point in time (spot) | FALSE |
| 258 | happamuusaste,laskimoverestä,pikatesti␤ |  | 712 | 0.7 |  |  |  |  | pH | Logarithmic scale |  | Blood venous | Qn | Point in time (spot) | FALSE |
| 259 | happiosapaine,kapillaariverestä,pikatesti␤ | kpa | 1260 | 0 |  |  |  |  | Oxygen | Partial pressure |  | Blood capillary | Qn | Point in time (spot) | FALSE |
| 260 | happoemästasejahappi,laskimoverestä,pikatesti␤ |  | 643 | 100 |  |  |  |  |  |  |  | Blood venous |  |  | TRUE |
| 261 | hepatiittic-virus,nh,jatkotutkimus,plasmasta |  | 512 | 100 |  |  |  |  | Hepatitis C virus RNA | Presence or Identity | Nucleic acid amplification with probe detection | Plasma | Ord | Point in time (spot) | FALSE |
| 262 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ | kpa | 707 | 0 |  |  |  |  | Carbon dioxide | Partial pressure |  | Blood venous | Qn | Point in time (spot) | FALSE |
| 263 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ |  | 5 | 100 |  |  |  |  | Carbon dioxide | Partial pressure |  | Blood venous | Qn | Point in time (spot) | FALSE |
| 264 | hpv-gt16aptimapanther,apututkimustulostensiirtoon |  | 149 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 265 | hpv-gt18-45aptimapanther,apututkimustulostensiirtoon |  | 149 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 266 | hpvaptimapanther,apututkimustulostensiirtoon |  | 413 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 267 | humanimmunodeficiencyvirus,antigeenijavasta- |  | 192 | 100 |  |  |  |  | HIV 1+2 Ag+Ab | Presence or Threshold | Immunoassay | Serum or Plasma | Ord | Point in time (spot) | FALSE |
| 268 | humanimmunodeficiencyvirus,antigeenijavasta-aineet,yhd |  | 260 | 100 |  |  |  |  | HIV 1+2 Ag+Ab | Presence or Threshold | Immunoassay | Serum or Plasma | Ord | Point in time (spot) | FALSE |
| 269 | huume-jalääkeainetutkimus,laaja,varmistus |  | 448 | 100 |  |  |  |  |  |  | Chromatography | Urine |  |  | TRUE |
| 270 | huumeseulonta,kvalitatiivinen,virtsasta␤ |  | 140 | 100 |  |  |  |  |  |  |  | Urine |  |  | TRUE |
| 271 | kalium,hoitoyksikönvieritesti,veri | mmol/l | 166 | 0 | [3.34, 3.65, 3.8, 3.9, 4, 4.19, 4.3, 4.42, 4.6] |  |  |  | Potassium | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 272 | kalium,hoitoyksikönvieritesti,veri |  | 290 | 0 | [3.4, 3.69, 3.8, 3.9, 4.06, 4.2, 4.4, 4.56, 5] |  |  |  | Potassium | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 273 | kreatiniini,hoitoyksikönvieritesti,veri | mmol/l | 163 | 0 | [61.44, 68.7, 74.81, 78.74, 84.67, 94.44, 102.62, 112.17, 146.53] |  |  |  | Creatinine | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 274 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 874 | 0 | [2.21, 3.1, 4.22, 5.54, 6.81, 8.47, 10.55, 13.18, 17.82] |  |  |  | Creatinine | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 275 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) |  | 6 | 66.67 |  |  |  |  | Creatinine | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 276 | laajahuumeseulonta,varmistustasoinen,virtsasta |  | 944 | 100 |  |  |  |  |  |  | Chromatography | Urine |  |  | TRUE |
| 277 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 203 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.1, 0.4] |  |  |  | Casts | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 278 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. |  | 9 | 100 |  |  |  |  | Casts | Number Concentration | Automated count | Urine | Qn | Point in time (spot) | FALSE |
| 279 | lisävastauslaskutuskuitatullenäytteelle |  | 214 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 280 | luuntiheysmittaus,2kohdetta(nk6sa),lausuttuna |  | 145 | 100 |  |  |  |  | Bone density study | Finding | Dual-energy X-ray absorptiometry | ^Patient | Nar | Point in time (spot) | TRUE |
| 281 | marevan-hoidonseur.tatesti,hoitoyksikkötekeesormenpäänäyte |  | 168 | 0 |  |  |  |  | INR | Relative time | Coagulation assay | Blood capillary | Qn | Point in time (spot) | FALSE |
| 282 | moniresistentitgramnegatiivisetsauvat,viljely |  | 206 | 100 |  |  |  |  | Gram negative rod multi-drug resistant | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 283 | natrium,hoitoyksikönvieritesti,veri | mmol/l | 163 | 0 | [133.07, 135, 136.54, 138, 139, 139.55, 140, 141, 142] |  |  |  | Sodium | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 284 | natrium,hoitoyksikönvieritesti,veri |  | 292 | 0 | [131.17, 133.92, 135.97, 137.29, 138.69, 139.5, 140, 141, 142] |  |  |  | Sodium | Substance Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 285 | natriureettinenpeptidi,b-tyypinn-terminaalinenpropeptidi,plasmasta | ng/l | 159 | 0 | [27.45, 51.56, 106.33, 265.57, 634.4, 1351.3, 2903.04, 5577.84, 11032.2] |  |  |  | Natriuretic peptide.B N-Terminal Prohormone | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 286 | nk-solujenosuus(määritettynäcd3-/cd16+/cd56+-soluina) | % | 665 | 0 | [4, 7.07, 9.79, 12.53, 14.84, 17.1, 21.25, 26.92, 36.91] |  |  |  | NK cells/Leukocytes | Number Fraction | Flow cytometry (FC) | Blood | Qn | Point in time (spot) | FALSE |
| 287 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. | mosm/kgh2o | 203 | 0 | [331.17, 377.3, 431.74, 500.49, 539.14, 595.38, 634.62, 686.05, 750.53] |  |  |  | Osmolality | Osmolality |  | Urine | Qn | Point in time (spot) | FALSE |
| 288 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. |  | 9 | 100 |  |  |  |  | Osmolality | Osmolality |  | Urine | Qn | Point in time (spot) | FALSE |
| 289 | p-natriureett.peptidin-termin.propept.vieritl | ng/l | 118 | 0 | [140.45, 226.81, 316.84, 708.93, 1117.67, 1691.6, 2121.04, 3414.6, 4866.2] |  | Plasma |  | Natriuretic peptide.B N-Terminal Prohormone | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 290 | p-natriureett.peptidin-termin.propept.vieritl |  | 20 | 100 |  |  | Plasma |  | Natriuretic peptide.B N-Terminal Prohormone | Mass Concentration | Immunoassay | Plasma | Qn | Point in time (spot) | FALSE |
| 291 | p-natriureettinenpeptidi,b-tyypinn-terminaalin | ng/l | 4682 | 0 | [86.24, 151.65, 238.65, 387.07, 653.89, 1066.35, 1771.72, 3084.52, 6142.85] |  | Plasma |  | Natriuretic peptide.B N-Terminal Prohormone | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 292 | p-natriureettinenpeptidi,b-tyypinn-terminaalin |  | 149 | 100 |  |  | Plasma |  | Natriuretic peptide.B N-Terminal Prohormone | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 293 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi | ng/l | 1366 | 0 | [106.15, 192.31, 311.64, 535.82, 915.89, 1456.12, 2310.73, 3820.95, 6983] |  | Plasma |  | Natriuretic peptide.B N-Terminal Prohormone | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 294 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi |  | 107 | 100 |  |  | Plasma |  | Natriuretic peptide.B N-Terminal Prohormone | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 295 | parasiitit,ulosteesta(alkueläintenkystat,madot,madonmunat,toukat) |  | 120 | 100 |  |  |  |  |  |  | Microscopy | Stool |  |  | TRUE |
| 296 | pienikudoskoepala,enintään1-3samankokonaisuudennäytettä |  | 234 | 100 |  |  |  |  | Histology study | Finding |  | Tissue | Nar | Point in time (spot) | TRUE |
| 297 | pika:m10inabnhp,rsvnhp,cv19nhp,yhdistelmävierit. |  | 267 | 100 |  |  |  |  |  |  |  | Nasopharynx |  |  | TRUE |
| 298 | pt-diffuusiokapasiteetti,single-breath-menetelmä,tavallinenperusmittaus |  | 3577 | 100 |  |  | Patient |  | Pulmonary function test study | Finding |  | ^Patient | Nar | Point in time (spot) | TRUE |
| 299 | pt-lausuntoneurofysiologisestatutkimuksesta,hälytysindikaatiot |  | 113 | 100 |  |  | Patient |  | Neurophysiology study | Finding |  | ^Patient | Nar | Point in time (spot) | TRUE |
| 300 | pt-luuntiheysmittaus,2kohdetta,ilmanlausuntoa |  | 120 | 100 |  |  | Patient |  | Bone density study | Finding | Dual-energy X-ray absorptiometry | ^Patient | Nar | Point in time (spot) | TRUE |
| 301 | pt-sydämenkattavarakenteellinenjatoiminnallinenuä(fm1ee) |  | 177 | 100 |  |  | Patient |  | Echocardiography study | Finding |  | ^Patient | Nar | Point in time (spot) | TRUE |
| 302 | pt-uloshengityksenhuippuvirtaus,vuorokausivaihtelunseuranta |  | 474 | 100 |  |  | Patient |  | Peak expiratory flow monitoring | Finding |  | ^Patient | Nar | Point in time (spot) | TRUE |
| 303 | pt-yöpolygrafia,ambulatorinen,hyvinsuppeaunirekisteröintikotona |  | 542 | 100 |  |  | Patient |  | Sleep study | Finding |  | ^Patient | Nar | Night time | TRUE |
| 304 | pt-yöpolygrafia,ambulatorinen,jalkaliikerekisteröinnein |  | 102 | 100 |  |  | Patient |  | Sleep study | Finding |  | ^Patient | Nar | Night time | TRUE |
| 305 | pu-aerobinenjaanaerobinenbakteerityypitysjaan |  | 147 | 100 |  |  | Pus |  |  |  | Organism specific culture | Pus |  |  | TRUE |
| 306 | resistentitgramnegatiivisetsauvat,viljely |  | 320 | 100 |  |  |  |  | Gram negative rod resistant | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 307 | retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 525 | 0 | [26.59, 29.88, 31.77, 32.87, 33.87, 34, 35, 35.95, 37] |  |  |  | Hemoglobin/Reticulocyte | Mass content | Automated count | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 308 | retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 5 | 100 |  |  |  |  | Hemoglobin/Reticulocyte | Mass content | Automated count | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 309 | s-humanimmunodeficiencyvirus,antigeenijavast |  | 1221 | 100 |  |  | Serum |  | HIV 1+2 Ag+Ab | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 310 | sikiöperäisendna:ntutkimusäidinverinäytteestä |  | 104 | 100 |  |  |  |  | Fetal DNA | Finding | Molecular genetics | Plasma | Nar | Point in time (spot) | TRUE |
| 311 | staphylococcusaureus,metisilliiniresistenssiviljely␤ |  | 134 | 100 |  |  |  |  | Staphylococcus aureus methicillin resistant | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 312 | staphylococcusaureus,metisilliiniresistentti(mrsa),viljely |  | 627 | 100 |  |  |  |  | Staphylococcus aureus methicillin resistant | Presence or Identity | Organism specific culture |  | Nom | Point in time (spot) | FALSE |
| 313 | t-auttajasolujenosuus(määritettynäcd3+cd4+soluina) | % | 665 | 0 | [12.24, 17.15, 20.76, 25.01, 30.99, 37.63, 47.04, 52.34, 60.07] |  | Thrombocyte |  | CD4+ T-lymphocytes/T-lymphocytes | Number Fraction | Flow cytometry (FC) | Blood | Qn | Point in time (spot) | FALSE |
| 314 | t-estäjäsolujenosuus(määritettynäcd3+cd8+soluina) | % | 665 | 0 | [14.45, 20.35, 24.03, 27.06, 32.04, 37.14, 44.33, 52.92, 66.66] |  | Thrombocyte |  | CD8+ T-lymphocytes/T-lymphocytes | Number Fraction | Flow cytometry (FC) | Blood | Qn | Point in time (spot) | FALSE |
| 315 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella | ng/l | 7 | 0 |  |  |  |  | Troponin T | Mass Concentration | Immunoassay | Serum or Plasma | Qn | Point in time (spot) | FALSE |
| 316 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella |  | 97 | 93.81 |  |  |  |  | Troponin T | Mass Concentration | Immunoassay | Serum or Plasma | Qn | Point in time (spot) | FALSE |
| 317 | ts-histologinentutkimus,1-3kudosnäytettä |  | 160 | 100 |  |  | Tissue |  |  |  |  |  |  |  |  |
| 318 | ts-histologinentutkimus,1-3näytettä |  | 945 | 100 |  |  | Tissue |  | Histology study | Finding |  | Tissue | Nar | Point in time (spot) | TRUE |
| 319 | työpaikanhuumeseulontajavarmistus,4yhdistettä |  | 469 | 100 |  |  |  |  |  |  | Chromatography | Urine |  |  | TRUE |
| 320 | työpaikanhuumeseulontajavarmistus,7yhdistettä |  | 312 | 100 |  |  |  |  |  |  | Chromatography | Urine |  |  | TRUE |
| 321 | täydellinennimi:pt-näytteenotto0maksu,kierronulkopuolisetnäytteet |  | 1481 | 100 |  |  |  |  |  |  |  |  |  |  | FALSE |
| 322 | täydellinenverenkuva,sis.perusverenkuvanjaleukosyyttienerittelylaskennan␤ |  | 9742 | 100 |  |  |  |  |  |  |  | Blood |  |  | TRUE |
| 323 | u-amfetamiinijametamfetamiini,enantiomeerienerittely |  | 120 | 100 |  |  | Urine |  | Amphetamine and Methamphetamine enantiomers | Presence or Identity | Chromatography | Urine | Nom | Point in time (spot) | FALSE |
| 324 | u-asetoniaineet,kval,vieritestihoitoyksikössä |  | 421 | 100 |  |  | Urine |  | Ketones | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 325 | u-erytrosyytit,kval,vieritestihoitoyksikössä |  | 413 | 100 |  |  | Urine |  | Erythrocytes | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 326 | u-glukoosi,kvalvieritestihoitoyksikössä |  | 423 | 100 |  |  | Urine |  | Glucose | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 327 | u-happamuusaste,vieritestihoitoyksikössä |  | 400 | 0.25 | [5.5, 5.5, 5.5, 5.9, 6, 6, 6.5, 7, 7] |  | Urine |  | pH | Logarithmic scale | Test strip | Urine | Qn | Point in time (spot) | FALSE |
| 328 | u-huume-jalääkeainetutkimus,laaja,varmistus |  | 175 | 100 |  |  | Urine |  |  |  | Chromatography | Urine |  |  | TRUE |
| 329 | u-huume-jalääkeainetutkimus,semikvantitatiivinen,virtsa␤sta |  | 121 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | TRUE |
| 330 | u-huumeseulonta,laaja(kvalitatiivinenlc-tof-ms) |  | 144 | 100 |  |  | Urine |  |  |  | Chromatography/Mass spectrometry | Urine |  |  | TRUE |
| 331 | u-kemiallinenseulonta,vieritestihoitoyksikössä |  | 104 | 100 |  |  | Urine |  |  |  | Test strip | Urine |  |  | TRUE |
| 332 | u-kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 398 | 0 | [2.13, 2.88, 3.69, 4.73, 6, 7.61, 9.67, 12.44, 16.61] |  | Urine |  | Creatinine | Substance Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 333 | u-laajahuume-jalääkeainetutkimus,semikvantitatiivinen |  | 421 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | TRUE |
| 334 | u-leukosyytit,kval,vieritestihoitoyksikössä |  | 429 | 100 |  |  | Urine |  | Leukocytes | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 335 | u-nitriitti,kval,vieritestihoitoyksikössä |  | 421 | 100 |  |  | Urine |  | Nitrite | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 336 | u-proteiini,kval,vieritestihoitoyksikössä |  | 425 | 100 |  |  | Urine |  | Protein | Presence or Threshold | Test strip | Urine | Ord | Point in time (spot) | FALSE |
| 337 | vieritestilaite(epoc)verikaasuanalyysilaskimonäytteestä |  | 162 | 100 |  |  |  |  |  |  |  | Blood venous |  |  | TRUE |
| 338 | yersinia(lajitenterocolitica,pseudotuberculosis,pestis)nho,ulosteesta␤ |  | 484 | 100 |  |  |  |  | Yersinia species DNA | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Ord | Point in time (spot) | FALSE |

