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
Here is group 68.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Adalimumab | Adalimumab | 1.000 | 7 | 3,981 |
| Adalimumab | Adalimumab Ab | 0.858 | 3 | 2,402 |
| Adalimumab | Adalimumab Ab.Neut | 0.777 | 0 | 0 |
| Adalimumab | Adalimumab^trough | 0.762 | 0 | 0 |
| Adalimumab Ab | Adalimumab Ab | 1.000 | 3 | 2,402 |
| Adalimumab Ab | Adalimumab | 0.858 | 7 | 3,981 |
| Adalimumab Ab | Adalimumab Ab.Neut | 0.836 | 0 | 0 |
| Adalimumab Ab | Golimumab Ab | 0.786 | 1 | 706 |
| Adalimumab Ab | Ustekinumab Ab | 0.778 | 0 | 0 |
| Albumin | Albumin | 1.000 | 80 | 2,081,573 |
| Albumin | Albumin in serum | 0.779 | 0 | 0 |
| Albumin | Albumin ug | 0.752 | 0 | 0 |
| Aldolase | Aldolase | 1.000 | 3 | 3,930 |
| Aldolase | Transaldolase | 0.755 | 0 | 0 |
| Aldosterone | Aldosterone | 1.000 | 11 | 8,593 |
| Aldosterone | Aldosterone free | 0.778 | 0 | 0 |
| Aldosterone | Aldosterone receptors | 0.771 | 0 | 0 |
| Aldosterone | Aldosterone^upright | 0.761 | 3 | 1,153 |
| Aldosterone | Aldosterone/Renin | 0.758 | 0 | 0 |
| Alkaline phosphatase | Alkaline phosphatase | 1.000 | 13 | 2,756,532 |
| Alkaline phosphatase | Alkaline phosphatase isoenzyme | 0.864 | 0 | 0 |
| Alkaline phosphatase | Alkaline phosphatase.bone | 0.829 | 13 | 5,731 |
| Alkaline phosphatase | Alkaline phosphatase isoenzymes | 0.817 | 2 | 9,116 |
| Alkaline phosphatase | Alkaline phosphatase.liver | 0.815 | 3 | 3,451 |
| Alkaline phosphatase.bone | Alkaline phosphatase.bone | 1.000 | 13 | 5,731 |
| Alkaline phosphatase.bone | Alkaline phosphatase.liver+bone | 0.869 | 0 | 0 |
| Alkaline phosphatase.bone | Alkaline phosphatase.bone/Alkaline phosphatase.total | 0.842 | 0 | 0 |
| Alkaline phosphatase.bone | Alkaline phosphatase.bile | 0.831 | 0 | 0 |
| Alkaline phosphatase.bone | Alkaline phosphatase | 0.829 | 13 | 2,756,532 |
| Alkaline phosphatase.bone/Alkaline phosphatase.total | Alkaline phosphatase.bone/Alkaline phosphatase.total | 1.000 | 0 | 0 |
| Alkaline phosphatase.bone/Alkaline phosphatase.total | Alkaline phosphatase.liver/Alkaline phosphatase.total | 0.879 | 2 | 176 |
| Alkaline phosphatase.bone/Alkaline phosphatase.total | Alkaline phosphatase.bile/Alkaline phosphatase.total | 0.879 | 0 | 0 |
| Alkaline phosphatase.bone/Alkaline phosphatase.total | Alkaline phosphatase.renal/Alkaline phosphatase.total | 0.867 | 0 | 0 |
| Alkaline phosphatase.bone/Alkaline phosphatase.total | Alkaline phosphatase.intestinal/Alkaline phosphatase.total | 0.850 | 0 | 0 |
| Alkaline phosphatase.intestinal | Alkaline phosphatase.intestinal | 1.000 | 9 | 4,096 |
| Alkaline phosphatase.intestinal | Alkaline phosphatase.intestinal 3 | 0.924 | 0 | 0 |
| Alkaline phosphatase.intestinal | Alkaline phosphatase.intestinal 2 | 0.924 | 0 | 0 |
| Alkaline phosphatase.intestinal | Alkaline phosphatase.intestinal+renal | 0.876 | 0 | 0 |
| Alkaline phosphatase.intestinal | Alkaline phosphatase.intestinal/Alkaline phosphatase.total | 0.858 | 0 | 0 |
| Alkaline phosphatase.intestinal 1 | Alkaline phosphatase.intestinal 2 | 0.927 | 0 | 0 |
| Alkaline phosphatase.intestinal 1 | Alkaline phosphatase.intestinal | 0.916 | 9 | 4,096 |
| Alkaline phosphatase.intestinal 1 | Alkaline phosphatase.intestinal 3 | 0.911 | 0 | 0 |
| Alkaline phosphatase.intestinal 1 | Alkaline phosphatase.intestinal+renal | 0.833 | 0 | 0 |
| Alkaline phosphatase.intestinal 1 | Alkaline phosphatase.intestinal 2/Alkaline phosphatase.total | 0.815 | 0 | 0 |
| Alkaline phosphatase.intestinal 2 | Alkaline phosphatase.intestinal 2 | 1.000 | 0 | 0 |
| Alkaline phosphatase.intestinal 2 | Alkaline phosphatase.intestinal 3 | 0.927 | 0 | 0 |
| Alkaline phosphatase.intestinal 2 | Alkaline phosphatase.intestinal | 0.924 | 9 | 4,096 |
| Alkaline phosphatase.intestinal 2 | Alkaline phosphatase.intestinal 2/Alkaline phosphatase.total | 0.883 | 0 | 0 |
| Alkaline phosphatase.intestinal 2 | Alkaline phosphatase.intestinal+renal | 0.847 | 0 | 0 |
| Alkaline phosphatase.intestinal 3 | Alkaline phosphatase.intestinal 3 | 1.000 | 0 | 0 |
| Alkaline phosphatase.intestinal 3 | Alkaline phosphatase.intestinal 2 | 0.927 | 0 | 0 |
| Alkaline phosphatase.intestinal 3 | Alkaline phosphatase.intestinal | 0.924 | 9 | 4,096 |
| Alkaline phosphatase.intestinal 3 | Alkaline phosphatase.intestinal 3/Alkaline phosphatase.total | 0.896 | 0 | 0 |
| Alkaline phosphatase.intestinal 3 | Alkaline phosphatase.intestinal+renal | 0.838 | 0 | 0 |
| Alkaline phosphatase.intestinal/Alkaline phosphatase.total | Alkaline phosphatase.intestinal/Alkaline phosphatase.total | 1.000 | 0 | 0 |
| Alkaline phosphatase.intestinal/Alkaline phosphatase.total | Alkaline phosphatase.intestinal 3/Alkaline phosphatase.total | 0.956 | 0 | 0 |
| Alkaline phosphatase.intestinal/Alkaline phosphatase.total | Alkaline phosphatase.intestinal 2/Alkaline phosphatase.total | 0.956 | 0 | 0 |
| Alkaline phosphatase.intestinal/Alkaline phosphatase.total | Alkaline phosphatase.liver/Alkaline phosphatase.total | 0.866 | 2 | 176 |
| Alkaline phosphatase.intestinal/Alkaline phosphatase.total | Alkaline phosphatase.intestinal | 0.858 | 9 | 4,096 |
| Alkaline phosphatase.other | Alkaline phosphatase.other fractions | 0.861 | 3 | 3,363 |
| Alkaline phosphatase.other | Alkaline phosphatase | 0.817 | 13 | 2,756,532 |
| Alkaline phosphatase.other | Alkaline phosphatase.bone | 0.807 | 13 | 5,731 |
| Alkaline phosphatase.other | Alkaline phosphatase.renal | 0.785 | 0 | 0 |
| Alkaline phosphatase.other | Alkaline phosphatase.bile | 0.785 | 0 | 0 |
| Allergen specific IgE Ab | IgE Ab | 0.853 | 0 | 0 |
| Allergen specific IgE Ab | Total IgE | 0.757 | 0 | 0 |
| Alpha 1 globulin | Alpha 1 globulin | 1.000 | 13 | 41,700 |
| Alpha 1 globulin | Alpha 2 globulin | 0.908 | 10 | 39,833 |
| Alpha 1 globulin | Alpha globulin | 0.869 | 0 | 0 |
| Alpha 1 globulin | Alpha 1 globulin/Protein.total | 0.837 | 0 | 0 |
| Alpha 1 globulin | Beta 1 globulin | 0.800 | 11 | 39,801 |
| Alpha 1 globulin/Protein.total | Alpha 1 globulin/Protein.total | 1.000 | 0 | 0 |
| Alpha 1 globulin/Protein.total | Alpha 2 globulin/Protein.total | 0.951 | 0 | 0 |
| Alpha 1 globulin/Protein.total | Beta 1 globulin/Protein.total | 0.872 | 0 | 0 |
| Alpha 1 globulin/Protein.total | Beta globulin/Protein.total | 0.863 | 0 | 0 |
| Alpha 1 globulin/Protein.total | Alpha-1-Acid glycoprotein/Protein.total | 0.856 | 0 | 0 |
| Alpha 2 globulin | Alpha 2 globulin | 1.000 | 10 | 39,833 |
| Alpha 2 globulin | Alpha 1 globulin | 0.913 | 13 | 41,700 |
| Alpha 2 globulin | Alpha globulin | 0.858 | 0 | 0 |
| Alpha 2 globulin | Alpha 2 globulin/Protein.total | 0.831 | 0 | 0 |
| Alpha 2 globulin | Beta 2 globulin | 0.794 | 11 | 39,732 |
| Alpha 2 globulin/Protein.total | Alpha 2 globulin/Protein.total | 1.000 | 0 | 0 |
| Alpha 2 globulin/Protein.total | Alpha 1 globulin/Protein.total | 0.951 | 0 | 0 |
| Alpha 2 globulin/Protein.total | Beta 2 globulin/Protein.total | 0.870 | 0 | 0 |
| Alpha 2 globulin/Protein.total | Alpha-2-Macroglobulin/Protein.total | 0.861 | 0 | 0 |
| Alpha 2 globulin/Protein.total | Beta globulin/Protein.total | 0.861 | 0 | 0 |
| Amylase | Amylase | 1.000 | 23 | 397,167 |
| Amylase | Amylase.P1 | 0.816 | 0 | 0 |
| Amylase | Amylase.P2 | 0.814 | 0 | 0 |
| Amylase | Amylase.P3 | 0.809 | 0 | 0 |
| Amylase | Macroamylase | 0.772 | 0 | 0 |
| Amylase.pancreatic | Amylase.pancreatic | 1.000 | 12 | 113,346 |
| Amylase.pancreatic | Amylase.pancreatic/Creatinine | 0.805 | 0 | 0 |
| Amylase.pancreatic | Amylase.salivary | 0.804 | 3 | 317 |
| Amylase.pancreatic | Amylase.pancreatic/Amylase.total | 0.778 | 0 | 0 |
| Amylase.pancreatic | Amylase | 0.756 | 23 | 397,167 |
| Amylase.salivary | Amylase.salivary | 1.000 | 3 | 317 |
| Amylase.salivary | Amylase.pancreatic | 0.804 | 12 | 113,346 |
| Amylase.salivary | Amylase.salivary/Amylase.total | 0.797 | 0 | 0 |
| Amylase.salivary | Amylase | 0.768 | 23 | 397,167 |
| Amylase.salivary | Amylase.P1 | 0.750 | 0 | 0 |
| Cholesterol in small dense LDL | Cholesterol.in LDL.small dense | 0.890 | 0 | 0 |
| Cholesterol in small dense LDL | Cholesterol in LDL | 0.837 | 47 | 2,347,979 |
| Cholesterol in small dense LDL | Cholesterol in LDL.narrow density | 0.776 | 0 | 0 |
| Cholesterol in small dense LDL | Cholesterol in VLDL | 0.762 | 0 | 0 |
| Cholesterol in small dense LDL | Cholesterol in LDL pattern A | 0.756 | 0 | 0 |
| Deamidated gliadin peptide Ab | Gliadin peptide Ab | 0.841 | 0 | 0 |
| Deamidated gliadin peptide Ab | Gliadin peptide Ab IgA+IgG | 0.812 | 0 | 0 |
| Deamidated gliadin peptide Ab | Gliadin Ab | 0.801 | 0 | 0 |
| Deamidated gliadin peptide Ab | Gliadin peptide IgG | 0.788 | 5 | 14,056 |
| Deamidated gliadin peptide Ab | Gliadin peptide+tissue transglutaminase Ab | 0.786 | 0 | 0 |
| Desmethylclozapine | Desmethylclomipramine | 0.755 | 0 | 0 |
| Dog (Canis familiaris) dander IgE Ab | Dog dander IgE | 0.887 | 10 | 9,242 |
| Dog (Canis familiaris) dander IgE Ab | Dog dander IgG | 0.867 | 0 | 0 |
| Dog (Canis familiaris) dander IgE Ab | Dog dander IgG4 | 0.857 | 0 | 0 |
| Dog (Canis familiaris) dander IgE Ab | Dog dander Ab.IgE/IgE.total | 0.843 | 0 | 0 |
| Dog (Canis familiaris) dander IgE Ab | Dog dander Ab.IgE.RAST class | 0.832 | 0 | 0 |
| Olanzapine | OLANZapine | 1.000 | 3 | 4,596 |
| Ovalbumin IgE Ab | Ovalbumin IgE | 0.957 | 0 | 0 |
| Ovalbumin IgE Ab | Ovalbumin Ab.IgG | 0.894 | 0 | 0 |
| Ovalbumin IgE Ab | Ovalbumin Ab.IgG4 | 0.886 | 0 | 0 |
| Ovalbumin IgE Ab | Ovalbumin Ab.IgE.RAST class | 0.884 | 0 | 0 |
| Ovalbumin IgE Ab | Ovomucoid IgE | 0.815 | 3 | 521 |
| Salicylate | Salicylates | 0.909 | 3 | 262 |
| Salicylate | Sodium salicylate | 0.812 | 0 | 0 |
| Salicylate | Salicylates^trough | 0.779 | 0 | 0 |
| Salicylate | Acetylsalicylate | 0.767 | 0 | 0 |
| Salicylate | Salicylurate | 0.762 | 0 | 0 |
| Scleroderma-70 Ab | Systemic sclerosis Ab panel | 0.796 | 0 | 0 |
| Scleroderma-70 Ab | SCL-70 extractable nuclear Ab | 0.760 | 20 | 19,685 |
| Soluble fms-like tyrosine kinase 1 | Soluble fms-like tyrosine kinase-1 | 0.979 | 0 | 0 |
| Soluble fms-like tyrosine kinase 1 | Soluble fms-like tyrosine kinase-1/placental growth factor | 0.892 | 0 | 0 |
| Soluble fms-like tyrosine kinase 1 | Soluble fms-like tyrosine kinase-1 and placental growth factor panel | 0.755 | 0 | 0 |
| Vedolizumab | Vedolizumab | 1.000 | 3 | 1,787 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Catalytic Activity Fraction | Catalytic Fraction | 0.830 | 14 | 842 |
| Catalytic Activity Fraction | Catalytic Activity | 0.791 | 0 | 0 |
| Catalytic Concentration | Catalytic Concentration | 1.000 | 228 | 10,802,985 |
| Catalytic Concentration | Relative catalytic concentration | 0.848 | 9 | 39,650 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Mass Fraction | Mass fraction | 1.000 | 229 | 4,683,692 |
| Mass Rate | Mass Rate | 1.000 | 32 | 47,943 |
| Mass Rate | Mass Rate Range | 0.843 | 0 | 0 |
| Mass Rate | Mass or Substance Rate | 0.778 | 2 | 118 |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |
| Substance Rate | Substance Rate | 1.000 | 41 | 25,881 |
| Substance Rate | Mass or Substance Rate | 0.799 | 2 | 118 |
| Substance Rate | Substance Ratio | 0.794 | 9 | 237,272 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Electrophoresis | Electrophoresis | 1.000 | 91 | 336,860 |
| Immunoassay | Immunoassay | 1.000 | 164 | 322,567 |
| Immunofluorescence (IF) | Immunofluorescence (IF) | 1.000 | 37 | 44,647 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Ascitic fluid | Peritoneal fluid | 0.772 | 41 | 16,617 |
| Pancreatic fluid | (none scored >= 0.75) |  |  |  |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Pleural fluid | Pleural fluid | 1.000 | 95 | 67,704 |
| Pleural fluid | Pericardial fluid | 0.759 | 0 | 0 |
| Secretion | (none scored >= 0.75) |  |  |  |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Sperm | Spermatozoa | 0.806 | 0 | 0 |
| Urine | Urine | 1.000 | 586 | 16,080,701 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 803 | -amyl | u/l | 4274 | 0 | [40.79, 91.13, 163.85, 262.6, 433.78, 741.28, 1310.78, 2709.64, 7550.04] |  |  |  | Amylase | Catalytic Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 804 | -amyl |  | 352 | 99.15 |  |  |  |  | Amylase |  |  |  | Nar | Point in time (spot) | FALSE |
| 805 | alfa-1 | g/l | 903 | 0 | [1.23, 1.5, 1.79, 2.22, 2.48, 2.68, 2.88, 3.11, 3.51] |  |  |  | Alpha 1 globulin | Mass Concentration | Electrophoresis |  | Qn | Point in time (spot) | FALSE |
| 806 | alfa-2 | g/l | 907 | 0 | [5.21, 5.83, 6.26, 6.53, 6.88, 7.18, 7.58, 8.1, 8.87] |  |  |  | Alpha 2 globulin | Mass Concentration | Electrophoresis |  | Qn | Point in time (spot) | FALSE |
| 807 | amylaasi | u/l | 1380 | 0 | [29.91, 37.05, 43.3, 48.81, 54.92, 61.3, 69.75, 79.02, 95.18] |  |  |  | Amylase | Catalytic Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 808 | amylaasi |  | 28 | 100 |  |  |  |  | Amylase |  |  |  | Nar | Point in time (spot) | FALSE |
| 809 | as-amyl | u/l | 277 | 0 | [7.29, 10.51, 15.56, 18.22, 24.01, 33.76, 50.6, 245.04, 2494.39] | As-Amylaasi | Ascitic fluid |  | Amylase | Catalytic Concentration |  | Ascitic fluid | Qn | Point in time (spot) | FALSE |
| 810 | as-amyl |  | 47 | 87.23 |  | As-Amylaasi | Ascitic fluid |  | Amylase |  |  | Ascitic fluid | Nar | Point in time (spot) | FALSE |
| 811 | du-aldos | nmol | 1126 | 1.15 | [10.3, 15.49, 20, 24.81, 30.39, 36.32, 42.97, 53.97, 73.23] | dU-Aldosteroni | 24-hour urine |  | Aldosterone | Substance Rate |  | Urine | Qn | 24 hours | FALSE |
| 812 | du-aldos | nmol/24h | 31 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone | Substance Rate |  | Urine | Qn | 24 hours | FALSE |
| 813 | du-aldos | nmol/l | 25 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone | Substance Concentration |  | Urine | Qn | 24 hours | FALSE |
| 814 | du-aldos | ug/24h | 12 | 0 |  | dU-Aldosteroni | 24-hour urine |  | Aldosterone | Mass Rate |  | Urine | Qn | 24 hours | FALSE |
| 815 | du-aldos |  | 191 | 49.21 | [8, 15.27, 20, 24.32, 29.5, 36, 48.62, 70.25, 89] | dU-Aldosteroni | 24-hour urine |  | Aldosterone | Substance Rate |  | Urine | Qn | 24 hours | FALSE |
| 816 | fp-afos | u/l | 595 | 0 | [48.33, 55.25, 59.57, 63.86, 67.6, 73.77, 82.28, 90.12, 106.03] |  | Fasting plasma |  | Alkaline phosphatase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 817 | fp-aldos | pmol/l | 759 | 0 | [99.71, 178.79, 234.24, 287.4, 344.18, 414.36, 481.84, 606.93, 836.03] | fP-Aldosteroni | Fasting plasma |  | Aldosterone | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 818 | fp-aldos |  | 70 | 70 |  | fP-Aldosteroni | Fasting plasma |  | Aldosterone |  |  | Plasma | Nar | Point in time (spot) | FALSE |
| 819 | fp-amyl | u/l | 166 | 0 | [38.7, 46.83, 53.52, 59.77, 65.17, 71.18, 77.02, 86.88, 100.9] |  | Fasting plasma |  | Amylase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 820 | p-afos | u/l | 2633385 | 0.01 | [49.38, 57.42, 63.93, 70.22, 76.89, 84.76, 95, 111.35, 151.36] | P -Alkalinen fosfataasi | Plasma |  | Alkaline phosphatase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 821 | p-afos |  | 28410 | 100 | [47.41, 55.11, 61.31, 67.35, 73.68, 80.95, 90.67, 106.27, 134.65] | P -Alkalinen fosfataasi | Plasma |  | Alkaline phosphatase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 822 | p-aldos | pmol/l | 978 | 0 | [88.37, 146.16, 190.71, 235.98, 287.48, 347.26, 419.69, 540.86, 783.53] | P -Aldosteroni | Plasma |  | Aldosterone | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 823 | p-aldos |  | 71 | 88.73 |  | P -Aldosteroni | Plasma |  | Aldosterone |  |  | Plasma | Nar | Point in time (spot) | FALSE |
| 824 | p-amyl | u/l | 368852 | 0.02 | [26.2, 33.98, 40.36, 46.26, 52.37, 59.2, 67.68, 79.78, 104.76] | P -Amylaasi | Plasma |  | Amylase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 825 | p-amyl |  | 5758 | 100 | [29, 36.73, 43, 48.41, 54.21, 60.53, 68.18, 78.9, 100.7] | P -Amylaasi | Plasma |  | Amylase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 826 | p-amylaasi | u/l | 1560 | 0 | [28.07, 35.77, 41.54, 47.32, 52.57, 59.03, 66.78, 77.77, 99.14] |  | Plasma |  | Amylase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 827 | p-amylaasi |  | 28 | 89.29 |  |  | Plasma |  | Amylase |  |  | Plasma | Nar | Point in time (spot) | FALSE |
| 828 | p-amylp | u/l | 96538 | 0 | [14.27, 20, 23.24, 26.43, 29.95, 34.28, 40.26, 51.17, 86.4] | P -Amylaasi, haimaperäinen | Plasma |  | Amylase.pancreatic | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 829 | p-amylp |  | 16102 | 100 | [12.88, 17.77, 21.4, 24.41, 27.47, 31.02, 35.38, 42.83, 60.62] | P -Amylaasi, haimaperäinen | Plasma |  | Amylase.pancreatic | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 830 | p-sldl | mmol/l | 2968 | 0 | [1.54, 1.82, 2.07, 2.32, 2.6, 2.9, 3.19, 3.53, 4.07] |  | Plasma |  | Cholesterol in small dense LDL | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 831 | p-sldl |  | 282 | 86.52 |  |  | Plasma |  | Cholesterol in small dense LDL |  |  | Plasma | Nar | Point in time (spot) | FALSE |
| 832 | pa-amyl | u/l | 181 | 0 | [6, 8.3, 13.62, 23.54, 38.11, 86.55, 532.84, 2066.13, 14410] | Pa-Amylaasi | Pancreatic juice |  | Amylase | Catalytic Concentration |  | Pancreatic fluid | Qn | Point in time (spot) | FALSE |
| 833 | pa-amyl |  | 13 | 100 |  | Pa-Amylaasi | Pancreatic juice |  | Amylase |  |  | Pancreatic fluid | Nar | Point in time (spot) | FALSE |
| 834 | pf-amyl | u/l | 512 | 0 | [11.47, 15.64, 19.01, 23.1, 27.84, 32.18, 37.92, 46.58, 62.15] | Pf-Amylaasi | Pleural fluid |  | Amylase | Catalytic Concentration |  | Pleural fluid | Qn | Point in time (spot) | FALSE |
| 835 | pf-amyl |  | 216 | 100 |  | Pf-Amylaasi | Pleural fluid |  | Amylase |  |  | Pleural fluid | Nar | Point in time (spot) | FALSE |
| 836 | s-aaldos | pmol/l | 125 | 0.8 | [506.75, 663.13, 772.54, 837.76, 918.5, 1062, 1146, 1442.2, 2247] |  | Serum |  | Aldosterone | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 837 | s-adali | mg/l | 1092 | 0.37 | [4.24, 6.27, 7.87, 9.1, 10.33, 11.83, 13.14, 14.95, 17.6] | S -Adalimumabi | Serum |  | Adalimumab | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 838 | s-adali |  | 600 | 16.67 | [3.21, 5.15, 6.89, 8.21, 9.3, 11.07, 13.15, 15.09, 18] | S -Adalimumabi | Serum |  | Adalimumab | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 839 | s-adaliab | au/ml | 257 | 1.17 | [4.47, 14.51, 21.55, 36.22, 43.39, 60.38, 104.64, 181.31, 370.6] | S -Adalimumabi, vasta-aineet | Serum |  | Adalimumab Ab | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 840 | s-adaliab |  | 2149 | 99.3 |  | S -Adalimumabi, vasta-aineet | Serum |  | Adalimumab Ab | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 841 | s-adalimu | mg/l | 2004 | 0 | [3.43, 5.38, 6.89, 8.1, 9.37, 10.76, 12.24, 13.87, 16.85] |  | Serum |  | Adalimumab | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 842 | s-adalimu |  | 271 | 52.03 | [2.22, 3.86, 5.11, 6.02, 6.96, 7.78, 8.44, 9.23, 10.15] |  | Serum |  | Adalimumab | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 843 | s-adalip |  | 274 | 100 |  |  | Serum |  |  |  | Immunoassay | Serum |  |  | TRUE |
| 844 | s-adalipa |  | 1304 | 100 |  |  | Serum |  |  |  | Immunoassay | Serum |  |  | TRUE |
| 845 | s-afluu | % | 92 | 0 | [10.3, 14.1, 19.33, 22.23, 25.37, 32.17, 35.52, 40.85, 45.6] |  | Serum |  | Alkaline phosphatase.bone/Alkaline phosphatase.total | Catalytic Activity Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 846 | s-afluu | u/l | 80 | 0 | [17.5, 21, 25.5, 29.5, 33.5, 38.75, 50, 58.5, 97.5] |  | Serum |  | Alkaline phosphatase.bone | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 847 | s-afluu |  | 9 | 77.78 |  |  | Serum |  | Alkaline phosphatase.bone |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 848 | s-afluust | u/l | 3036 | 0 | [23.45, 30.5, 36.88, 43.03, 49.77, 57.33, 66.23, 80.75, 107.75] |  | Serum |  | Alkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 849 | s-afluust |  | 488 | 63.73 | [22.65, 29.23, 35.8, 41.92, 49.43, 57.83, 64.94, 75.26, 91.6] |  | Serum |  | Alkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 850 | s-afmuut | u/l | 1555 | 0 | [0, 0, 0, 0.56, 2.03, 4.33, 8.12, 14.99, 30.62] |  | Serum |  | Alkaline phosphatase.other | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 851 | s-afmuut |  | 316 | 96.2 |  |  | Serum |  | Alkaline phosphatase.other |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 852 | s-afos | iu/l | 240 | 0 | [47.27, 53.32, 59.23, 65.05, 70.65, 75.95, 84.63, 98.48, 130] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 853 | s-afos | u/l | 62976 | 0 | [49.01, 56.54, 62.55, 68.34, 74.46, 81.49, 90.44, 104.36, 129.97] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 854 | s-afos |  | 986 | 36 | [88.65, 108.98, 118.14, 127.37, 135.4, 144.04, 157.28, 186.3, 252.69] | S -Alkalinen fosfataasi | Serum |  | Alkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 855 | s-afos-is | u/l | 70 | 0 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes |  |  | Electrophoresis | Serum |  |  | TRUE |
| 856 | s-afos-is |  | 9083 | 99.98 |  | S -Alkalinen fosfataasi, isoentsyymit | Serum | Isoenzymes |  |  | Electrophoresis | Serum |  |  | TRUE |
| 857 | s-afosluu | u/l | 106 | 0 | [25.67, 31, 35.33, 39.5, 42, 50.37, 59.67, 72.5, 100] | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone | Catalytic Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 858 | s-afosluu | ug/l | 30 | 0 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 859 | s-afosluu |  | 35 | 11.43 |  | S -Alkalinen fosfataasi, luuspesifinen | Serum |  | Alkaline phosphatase.bone |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 860 | s-afospit | u/l | 177 | 0 | [96.72, 105.51, 113.04, 119.21, 129.13, 139.98, 153.3, 187.04, 317.98] |  | Serum |  | Alkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 861 | s-afospit |  | 8 | 37.5 |  |  | Serum |  | Alkaline phosphatase |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 862 | s-afsuol1 | u/l | 1064 | 0 | [0, 0, 0, 0, 0, 0.97, 2.27, 4.95, 11.83] |  | Serum |  | Alkaline phosphatase.intestinal 1 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 863 | s-afsuol1 |  | 158 | 1.27 | [0, 0, 0, 0, 0.17, 1.4, 3, 6.28, 16.75] |  | Serum |  | Alkaline phosphatase.intestinal 1 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 864 | s-afsuol2 | u/l | 1070 | 0 | [0, 0, 0, 0, 0, 0.76, 2.02, 4.43, 8.94] |  | Serum |  | Alkaline phosphatase.intestinal 2 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 865 | s-afsuol2 |  | 156 | 0.64 | [0, 0, 0, 0, 0, 1.25, 3, 4.75, 8] |  | Serum |  | Alkaline phosphatase.intestinal 2 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 866 | s-afsuol3 | u/l | 1075 | 0 | [0, 0, 0, 0, 0, 0, 0, 1, 1.91] |  | Serum |  | Alkaline phosphatase.intestinal 3 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 867 | s-afsuol3 |  | 157 | 0.64 | [0, 0, 0, 0, 0, 0, 0, 1, 1] |  | Serum |  | Alkaline phosphatase.intestinal 3 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 868 | s-afsuoli | % | 53 | 0 |  |  | Serum |  | Alkaline phosphatase.intestinal/Alkaline phosphatase.total | Catalytic Activity Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 869 | s-afsuoli | u/l | 189 | 0 | [1, 2.2, 4.12, 5.94, 7, 9.07, 12.69, 23.37, 34.67] |  | Serum |  | Alkaline phosphatase.intestinal | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 870 | s-afsuoli |  | 182 | 96.15 |  |  | Serum |  | Alkaline phosphatase.intestinal |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 871 | s-albind | g/l | 815 | 0 | [34.39, 37.6, 39.38, 40.81, 42.07, 43.01, 44.01, 45.22, 47.08] |  | Serum |  | Albumin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 872 | s-albind |  | 155 | 25.81 | [33.15, 36.46, 38.93, 39.99, 41.28, 41.98, 42.86, 43.61, 45.95] |  | Serum |  | Albumin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 873 | s-albu | g/l | 554 | 0 | [34.76, 36.69, 38.29, 39.83, 40.76, 41.89, 43.25, 44.88, 46.93] |  | Serum |  | Albumin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 874 | s-albu |  | 12 | 33.33 |  |  | Serum |  | Albumin |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 875 | s-album | g/l | 27997 | 0 | [31.02, 34.31, 36.21, 37.6, 38.74, 39.81, 40.91, 42.12, 43.69] |  | Serum |  | Albumin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 876 | s-album |  | 49 | 100 | [31.46, 35.04, 37.29, 38.99, 40.3, 41.52, 42.95, 44.52, 46.29] |  | Serum |  | Albumin | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 877 | s-aldol | u/l | 3331 | 0.03 | [3.03, 3.84, 4, 4.87, 5, 5.94, 6.21, 7.11, 9.71] | S -Aldolaasi | Serum |  | Aldolase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 878 | s-aldol |  | 603 | 75.79 | [2.92, 3.62, 4.18, 4.48, 5.37, 5.7, 6.13, 7.21, 9.7] | S -Aldolaasi | Serum |  | Aldolase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 879 | s-aldos | pmol/l | 5247 | 0.88 | [80.92, 114.8, 152.73, 192.44, 237.39, 292.55, 361.76, 461.2, 667.49] | S -Aldosteroni | Serum |  | Aldosterone | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 880 | s-aldos |  | 1207 | 72.49 | [89.4, 124.94, 166.83, 212.25, 274.25, 349.09, 455.92, 585.04, 869.75] | S -Aldosteroni | Serum |  | Aldosterone | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 881 | s-aldos-m | pmol/l | 88 | 0 | [47, 57.1, 78.9, 115.83, 136, 213.63, 263.1, 334.4, 926] | S -Aldosteroni, makuu | Serum | Supine (lying down) | Aldosterone | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 882 | s-aldos-m |  | 66 | 68.18 |  | S -Aldosteroni, makuu | Serum | Supine (lying down) | Aldosterone |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 883 | s-aldos-p | pmol/l | 824 | 0 | [77.23, 114.1, 153.16, 191.49, 236.83, 292.92, 363.97, 474.9, 659.05] | S -Aldosteroni, pysty | Serum | Upright (standing) | Aldosterone | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 884 | s-aldos-p |  | 329 | 21.88 | [79.42, 123.32, 172.77, 232.62, 283.29, 334.05, 403.83, 552.65, 812.7] | S -Aldosteroni, pysty | Serum | Upright (standing) | Aldosterone | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 885 | s-alfa-1 | % | 11 | 0 |  |  | Serum |  | Alpha 1 globulin/Protein.total | Mass Fraction | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 886 | s-alfa-1 | g/l | 30281 | 0 | [2.19, 2.42, 2.6, 2.72, 2.88, 3.03, 3.24, 3.54, 4.08] |  | Serum |  | Alpha 1 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 887 | s-alfa-1 |  | 50 | 100 | [1.5, 1.7, 1.88, 2.13, 2.38, 2.62, 2.88, 3.19, 3.81] |  | Serum |  | Alpha 1 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 888 | s-alfa-2 | % | 11 | 0 |  |  | Serum |  | Alpha 2 globulin/Protein.total | Mass Fraction | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 889 | s-alfa-2 | g/l | 30219 | 0 | [5.45, 5.93, 6.31, 6.66, 7.01, 7.39, 7.84, 8.42, 9.36] |  | Serum |  | Alpha 2 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 890 | s-alfa-2 |  | 50 | 100 | [5.71, 6.15, 6.53, 6.83, 7.14, 7.51, 7.91, 8.44, 9.39] |  | Serum |  | Alpha 2 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 891 | s-alfa1 | g/l | 1708 | 0 | [1.45, 1.6, 1.7, 1.8, 1.95, 2.11, 2.38, 2.65, 3.03] |  | Serum |  | Alpha 1 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 892 | s-alfa1 |  | 92 | 25 |  |  | Serum |  | Alpha 1 globulin |  | Electrophoresis | Serum | Nar | Point in time (spot) | FALSE |
| 893 | s-alfa2 | g/l | 1768 | 0 | [5.73, 6.28, 6.69, 6.98, 7.28, 7.59, 8.04, 8.57, 9.36] |  | Serum |  | Alpha 2 globulin | Mass Concentration | Electrophoresis | Serum | Qn | Point in time (spot) | FALSE |
| 894 | s-alfa2 |  | 92 | 25 |  |  | Serum |  | Alpha 2 globulin |  | Electrophoresis | Serum | Nar | Point in time (spot) | FALSE |
| 895 | s-allige | mg/l | 14 | 0 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 896 | s-allige | u/ml | 1753 | 0 | [0.12, 0.19, 0.31, 0.51, 0.83, 1.39, 2.4, 4.64, 12.35] | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 897 | s-allige |  | 2748 | 99.71 |  | S -Allergeeni, IgE-vasta-aineet | Serum |  | Allergen specific IgE Ab | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 898 | s-amyl | u/l | 10387 | 0 | [33.31, 39.8, 44.99, 49.81, 54.67, 59.75, 66.53, 75.22, 91.12] | S -Amylaasi | Serum |  | Amylase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 899 | s-amyl |  | 129 | 20.16 | [35, 42.3, 49.52, 56.4, 62.75, 71, 94.2, 128.3, 161] | S -Amylaasi | Serum |  | Amylase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 900 | s-amyl-is | form | 15 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes |  |  | Electrophoresis | Serum |  |  | TRUE |
| 901 | s-amyl-is |  | 434 | 100 |  | S -Amylaasi, isoentsyymit | Serum | Isoenzymes |  |  | Electrophoresis | Serum |  |  | TRUE |
| 902 | s-amylp | u/l | 280 | 0 | [14.92, 20.3, 25.89, 30.35, 36.7, 44.3, 55.25, 69.52, 135.91] | S -Amylaasi, haimaperäinen | Serum |  | Amylase.pancreatic | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 903 | s-amylp |  | 66 | 16.67 |  | S -Amylaasi, haimaperäinen | Serum |  | Amylase.pancreatic |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 904 | s-amyls | u/l | 256 | 0 | [12.25, 18.54, 23.94, 28.43, 34.44, 44.93, 63.37, 81.22, 120.05] | S -Amylaasi, sylkiperäinen | Serum |  | Amylase.salivary | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 905 | s-amyls |  | 61 | 18.03 |  | S -Amylaasi, sylkiperäinen | Serum |  | Amylase.salivary |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 906 | s-dmklots | nmol/l | 15078 | 0.19 | [349.72, 488.38, 603.51, 717.55, 840.77, 973.75, 1127.96, 1320.3, 1616.71] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 907 | s-dmklots | umol/l | 9051 | 0 | [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.95, 1.16, 1.45] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 908 | s-dmklots | âumol/l | 32 | 0 |  | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 909 | s-dmklots |  | 1117 | 100 | [0.79, 1.17, 292.49, 521.2, 721.89, 874.92, 1051.9, 1273.86, 1599.85] | S -Desmetyyliklotsapiini | Serum |  | Desmethylclozapine |  |  | Serum | Qn | Point in time (spot) | FALSE |
| 910 | s-gliade | u/ml | 23 | 60.87 |  |  | Serum |  | Deamidated gliadin peptide Ab | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 911 | s-gliade |  | 84 | 98.81 |  |  | Serum |  | Deamidated gliadin peptide Ab | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 912 | s-gliadie | u/ml | 531 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.02, 0.07, 0.24] |  | Serum |  | Deamidated gliadin peptide Ab | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 913 | s-gliadie |  | 118 | 5.93 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Serum |  | Deamidated gliadin peptide Ab | Arbitrary Concentration | Immunoassay | Serum | SemiQn | Point in time (spot) | FALSE |
| 914 | s-hladsa |  | 847 | 100 |  |  | Serum |  |  |  | Immunoassay | Serum |  |  | TRUE |
| 915 | s-kalatue |  | 132 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | TRUE |
| 916 | s-kolaige | u/ml | 14 | 100 |  |  | Serum |  | Dog (Canis familiaris) dander IgE Ab | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 917 | s-kolaige |  | 181 | 100 |  |  | Serum |  | Dog (Canis familiaris) dander IgE Ab | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 918 | s-kudosab |  | 1042 | 100 |  |  | Serum |  |  |  | Immunofluorescence (IF) | Serum |  |  | TRUE |
| 919 | s-ngmuut |  | 16771 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 920 | s-oaldos | pmol/l | 200 | 1.5 | [636.2, 2117.22, 7632.17, 17219.7, 36953.33, 62851.67, 87233.33, 130744.44, 214222.22] |  | Serum |  |  | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 921 | s-olants | nmol/l | 4003 | 0.07 | [53.03, 76.26, 97.99, 119.12, 141.44, 165.86, 195.39, 234.91, 291.91] | S -Olantsapiini | Serum |  | Olanzapine | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 922 | s-olants |  | 595 | 31.43 | [58.73, 86.04, 110.31, 132.4, 158.88, 189.03, 219.38, 262.18, 324.46] | S -Olantsapiini | Serum |  | Olanzapine | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 923 | s-ovalbue | u/ml | 86 | 1.16 | [0, 0.02, 0.03, 0.1, 0.23, 0.56, 2, 8.02, 21.8] |  | Serum |  | Ovalbumin IgE Ab | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 924 | s-ovalbue |  | 16 | 81.25 |  |  | Serum |  | Ovalbumin IgE Ab |  | Immunoassay | Serum | Nar | Point in time (spot) | FALSE |
| 925 | s-salis | mmol/l | 56 | 0 |  | S -Salisylaatit | Serum |  | Salicylate | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 926 | s-salis | umol/l | 87 | 5.75 |  | S -Salisylaatit | Serum |  | Salicylate | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 927 | s-salis |  | 121 | 97.52 |  | S -Salisylaatit | Serum |  | Salicylate |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 928 | s-scl-t |  | 833 | 100 |  |  | Serum |  | Scleroderma-70 Ab | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 929 | s-sfit1 | ng/l | 135 | 0 | [1994, 2524.58, 3215, 3792.29, 4608.29, 5445.5, 7105.78, 9372.28, 11496.33] | S -Endoteelikasvutekijän liukoinen reseptori | Serum |  | Soluble fms-like tyrosine kinase 1 | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 930 | s-sflt-1 | ng/l | 318 | 0 | [1291.87, 1667.24, 2344.04, 3006.81, 3762.57, 4805.39, 6029.95, 7158.88, 9214.96] |  | Serum |  | Soluble fms-like tyrosine kinase 1 | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 931 | s-sldl | mmol/l | 2207 | 0 | [1.75, 2.1, 2.37, 2.68, 2.95, 3.22, 3.51, 3.8, 4.25] |  | Serum |  | Cholesterol in small dense LDL | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 932 | s-sldl |  | 177 | 98.87 |  |  | Serum |  | Cholesterol in small dense LDL |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 933 | s-suoli | u/l | 115 | 0 | [0, 0, 0, 0.27, 2.83, 5.44, 7.47, 12.05, 21.01] |  | Serum |  | Alkaline phosphatase.intestinal | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 934 | s-suoli |  | 10 | 30 |  |  | Serum |  | Alkaline phosphatase.intestinal |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 935 | s-suolist | u/l | 81 | 0 | [2, 3.1, 5.23, 9, 10.88, 13, 15, 20.35, 28] |  | Serum |  | Alkaline phosphatase.intestinal | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 936 | s-suolist |  | 63 | 96.83 |  |  | Serum |  | Alkaline phosphatase.intestinal |  |  | Serum | Nar | Point in time (spot) | FALSE |
| 937 | s-valdos | pmol/l | 157 | 0.64 | [3435.33, 10631.9, 19753.33, 29394.05, 44768.33, 65139.29, 87875, 118200, 193300] |  | Serum |  |  | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 938 | s-vedol | mg/l | 1566 | 0 | [10.87, 14.08, 17.75, 20.76, 23.95, 27.59, 31.95, 37.11, 43.61] | S -Vedolitsumabi | Serum |  | Vedolizumab | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 939 | s-vedol |  | 221 | 12.22 | [5.88, 9.27, 13.22, 17.42, 21.48, 25.78, 28.81, 33.33, 39.06] | S -Vedolitsumabi | Serum |  | Vedolizumab | Mass Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 940 | saline |  | 946 | 3.38 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  |  |  |  |  |  |  | FALSE |
| 941 | se-amyl | u/l | 1679 | 0.83 | [7.84, 14.57, 24.16, 42.2, 81.52, 202.31, 555.29, 1833.05, 9919.76] | Se-Amylaasi | Secretion |  | Amylase | Catalytic Concentration |  | Secretion | Qn | Point in time (spot) | FALSE |
| 942 | se-amyl |  | 248 | 97.98 |  | Se-Amylaasi | Secretion |  | Amylase |  |  | Secretion | Nar | Point in time (spot) | FALSE |
| 943 | sp-suld |  | 262 | 100 |  |  | Sperm / semen |  |  |  |  | Sperm |  |  | FALSE |
| 944 | u-amyl | u/l | 2762 | 0.04 | [40.07, 60.75, 84.23, 110.48, 142.21, 184.16, 244.01, 332.59, 547.07] | U -Amylaasi | Urine |  | Amylase | Catalytic Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 945 | u-amyl |  | 192 | 49.48 | [46, 98.65, 135.92, 161.9, 205.44, 269.5, 358.67, 597.35, 1056] | U -Amylaasi | Urine |  | Amylase | Catalytic Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 946 | u-amylp | u/l | 106 | 0 | [29, 44.7, 68.1, 90.36, 112.17, 155.8, 214.47, 337.6, 546] | U -Amylaasi, haimaperäinen | Urine |  | Amylase.pancreatic | Catalytic Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 947 | u-amylp |  | 15 | 20 |  | U -Amylaasi, haimaperäinen | Urine |  | Amylase.pancreatic |  |  | Urine | Nar | Point in time (spot) | FALSE |

