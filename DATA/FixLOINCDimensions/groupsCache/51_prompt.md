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
Here is group 51.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Adenovirus antigen | Adenovirus Ag | 0.875 | 2 | 2,822 |
| Adenovirus antigen | Adenovirus Ab | 0.847 | 0 | 0 |
| Adenovirus antigen | Adenovirus IgG | 0.793 | 0 | 0 |
| Adenovirus antigen | Adenovirus IgM | 0.785 | 0 | 0 |
| Adenovirus antigen | Adenovirus | 0.780 | 0 | 0 |
| Adenovirus IgG antibody | Adenovirus IgG | 0.972 | 0 | 0 |
| Adenovirus IgG antibody | Adenovirus IgM | 0.892 | 0 | 0 |
| Adenovirus IgG antibody | Adenovirus IgA | 0.853 | 0 | 0 |
| Adenovirus IgG antibody | Adenovirus IgG and IgM panel | 0.851 | 0 | 0 |
| Adenovirus IgG antibody | Adenovirus Ab | 0.814 | 0 | 0 |
| Bocavirus antigen | Human bocavirus Ag | 0.822 | 0 | 0 |
| Bocavirus antigen | Human bocavirus Ab | 0.769 | 0 | 0 |
| Bocavirus antigen | Human bocavirus IgG | 0.759 | 0 | 0 |
| Bocavirus antigen | Human bocavirus DNA | 0.759 | 2 | 13,049 |
| Coronavirus antigen | (none scored >= 0.75) |  |  |  |
| Embryo transfer | (none scored >= 0.75) |  |  |  |
| Giardia lamblia antigen | Giardia lamblia Ag | 0.856 | 0 | 0 |
| Giardia lamblia antigen | Giardia lamblia IgG | 0.833 | 0 | 0 |
| Giardia lamblia antigen | Giardia lamblia IgM | 0.821 | 0 | 0 |
| Giardia lamblia antigen | Giardia lamblia Ab | 0.813 | 0 | 0 |
| Giardia lamblia antigen | Giardia lamblia IgA | 0.812 | 0 | 0 |
| Giardia lamblia+Cryptosporidium antigen | Giardia lamblia+Cryptosporidium parvum Ag | 0.907 | 0 | 0 |
| Giardia lamblia+Cryptosporidium antigen | Giardia lamblia+Cryptosporidium sp Ag | 0.885 | 0 | 0 |
| Giardia lamblia+Cryptosporidium antigen | Giardia lamblia+Cryptosporidium parvum | 0.831 | 0 | 0 |
| Giardia lamblia+Cryptosporidium antigen | Giardia lamblia and Cryptosporidium parvum Ag panel | 0.830 | 0 | 0 |
| Giardia lamblia+Cryptosporidium antigen | Giardia lamblia+Cryptosporidium sp | 0.830 | 0 | 0 |
| Inflammation | (none scored >= 0.75) |  |  |  |
| Infliximab | inFLIXimab | 1.000 | 7 | 7,102 |
| Infliximab | inFLIXimab Ab | 0.765 | 2 | 4,852 |
| Infliximab antibody | inFLIXimab Ab | 0.770 | 2 | 4,852 |
| Influenza A virus | Influenza virus A | 0.931 | 0 | 0 |
| Influenza A virus | Influenza virus | 0.908 | 1 | 1,256 |
| Influenza A virus | Influenza virus A H1 | 0.856 | 0 | 0 |
| Influenza A virus | Influenza virus A H5 | 0.826 | 0 | 0 |
| Influenza A virus | Influenza virus A subtype | 0.822 | 0 | 0 |
| Influenza A virus antigen | Influenza virus A Ag | 0.868 | 2 | 22,589 |
| Influenza A virus antigen | Influenza virus Ag | 0.855 | 0 | 0 |
| Influenza A virus antigen | Influenza virus A H1 Ag | 0.839 | 0 | 0 |
| Influenza A virus antigen | Influenza virus A and B Ag | 0.817 | 0 | 0 |
| Influenza A virus antigen | Influenza virus A H7 Ag | 0.817 | 0 | 0 |
| Influenza A virus H1 antigen | Influenza virus A H1 Ag | 0.887 | 0 | 0 |
| Influenza A virus H1 antigen | Influenza virus A H1 | 0.864 | 0 | 0 |
| Influenza A virus H1 antigen | Influenza virus A H3 Ag | 0.822 | 0 | 0 |
| Influenza A virus H1 antigen | Influenza virus A H5 Ag | 0.821 | 0 | 0 |
| Influenza A virus H1 antigen | Influenza virus A H7 Ag | 0.809 | 0 | 0 |
| Influenza A virus H1N1-2009 antigen | Influenza virus A H1 2009 pandemic Ab | 0.820 | 0 | 0 |
| Influenza A virus H1N1-2009 antigen | Influenza virus A H1 2009 pandemic | 0.818 | 0 | 0 |
| Influenza A virus H1N1-2009 antigen | Influenza virus A H1 2009 pandemic RNA panel | 0.795 | 0 | 0 |
| Influenza A virus H1N1-2009 antigen | Influenza virus A and B and H1 2009 pandemic | 0.784 | 0 | 0 |
| Influenza A virus H1N1-2009 antigen | Influenza virus A H1 Ag | 0.775 | 0 | 0 |
| Influenza A virus H3 antigen | Influenza virus A H3 Ag | 0.892 | 0 | 0 |
| Influenza A virus H3 antigen | Influenza virus A H3 | 0.881 | 0 | 0 |
| Influenza A virus H3 antigen | Influenza virus A H3 Ab | 0.845 | 0 | 0 |
| Influenza A virus H3 antigen | Influenza virus A H1 Ag | 0.831 | 0 | 0 |
| Influenza A virus H3 antigen | Influenza virus A H1 | 0.803 | 0 | 0 |
| Influenza A virus IgG antibody | Influenza virus A IgG | 0.961 | 3 | 85 |
| Influenza A virus IgG antibody | Influenza virus A IgM | 0.876 | 0 | 0 |
| Influenza A virus IgG antibody | Influenza virus B IgG | 0.866 | 0 | 0 |
| Influenza A virus IgG antibody | Influenza virus A IgA | 0.850 | 0 | 0 |
| Influenza A virus IgG antibody | Influenza virus B IgM | 0.807 | 0 | 0 |
| Influenza B virus | Influenza virus B | 0.914 | 0 | 0 |
| Influenza B virus | Influenza virus B lineage | 0.818 | 0 | 0 |
| Influenza B virus | Influenza virus B RNA | 0.805 | 2 | 129,826 |
| Influenza B virus | Influenza virus B Ag | 0.803 | 2 | 22,580 |
| Influenza B virus | Influenza virus B Ab | 0.800 | 1 | 29 |
| Influenza B virus antibody | Influenza virus B Ab | 0.900 | 1 | 29 |
| Influenza B virus antibody | Influenza virus B IgG | 0.898 | 0 | 0 |
| Influenza B virus antibody | Influenza virus B IgM | 0.861 | 0 | 0 |
| Influenza B virus antibody | Influenza virus B IgA | 0.853 | 0 | 0 |
| Influenza B virus antibody | Influenza virus A and B Ab | 0.831 | 0 | 0 |
| Influenza B virus antigen | Influenza virus B Ag | 0.873 | 2 | 22,580 |
| Influenza B virus antigen | Influenza virus B | 0.834 | 0 | 0 |
| Influenza B virus antigen | Influenza virus B Ab | 0.812 | 1 | 29 |
| Influenza B virus antigen | Influenza virus A and B Ag | 0.796 | 0 | 0 |
| Influenza B virus antigen | Influenza virus B Yamagata lineage Ag | 0.792 | 0 | 0 |
| Influenza B virus IgG antibody | Influenza virus B IgG | 0.954 | 0 | 0 |
| Influenza B virus IgG antibody | Influenza virus B IgM | 0.877 | 0 | 0 |
| Influenza B virus IgG antibody | Influenza virus B IgA | 0.869 | 0 | 0 |
| Influenza B virus IgG antibody | Influenza virus A IgG | 0.866 | 3 | 85 |
| Influenza B virus IgG antibody | Influenza virus B Ab | 0.845 | 1 | 29 |
| Influenza virus A+B | Influenza virus A+B | 1.000 | 0 | 0 |
| Influenza virus A+B | Influenza virus A+B Ab | 0.893 | 0 | 0 |
| Influenza virus A+B | Influenza virus A+B+C | 0.885 | 0 | 0 |
| Influenza virus A+B | Influenza virus A+B RNA | 0.884 | 0 | 0 |
| Influenza virus A+B | Influenza virus A+B Ag | 0.882 | 1 | 15,096 |
| Influenza virus A+B antigen | Influenza virus A+B Ag | 0.922 | 1 | 15,096 |
| Influenza virus A+B antigen | Influenza virus A+B | 0.891 | 0 | 0 |
| Influenza virus A+B antigen | Influenza virus A+B Ab | 0.883 | 0 | 0 |
| Influenza virus A+B antigen | Influenza virus A+B+C Ag | 0.852 | 0 | 0 |
| Influenza virus A+B antigen | Influenza virus A and B Ag | 0.840 | 0 | 0 |
| Influenza virus A+B RNA | Influenza virus A+B RNA | 1.000 | 0 | 0 |
| Influenza virus A+B RNA | Influenza virus A and B RNA | 0.912 | 0 | 0 |
| Influenza virus A+B RNA | Influenza virus A+B | 0.884 | 0 | 0 |
| Influenza virus A+B RNA | Influenza virus A RNA | 0.871 | 3 | 142,013 |
| Influenza virus A+B RNA | Influenza virus A H1+H3+B RNA | 0.871 | 0 | 0 |
| Influenza virus A+B+Respiratory syncytial virus antigen panel | Influenza virus A and B and Respiratory syncytial virus RNA panel | 0.909 | 0 | 0 |
| Influenza virus A+B+Respiratory syncytial virus antigen panel | Influenza virus A and Influenza virus B and SARS coronavirus 2 and Respiratory syncytial virus Ag panel | 0.854 | 0 | 0 |
| Influenza virus A+B+Respiratory syncytial virus antigen panel | Influenza virus A and B Ag panel | 0.850 | 0 | 0 |
| Influenza virus A+B+Respiratory syncytial virus antigen panel | Influenza virus types A and B panel | 0.823 | 0 | 0 |
| Influenza virus A+B+Respiratory syncytial virus antigen panel | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel | 0.822 | 2 | 45,357 |
| Influenza virus+Respiratory syncytial virus | (none scored >= 0.75) |  |  |  |
| Influenza/Respiratory virus panel | Influenza virus A and B and Respiratory syncytial virus RNA panel | 0.851 | 0 | 0 |
| Influenza/Respiratory virus panel | Respiratory pathogens panel | 0.831 | 0 | 0 |
| Influenza/Respiratory virus panel | Respiratory viral pathogens DNA and RNA panel | 0.807 | 0 | 0 |
| Influenza/Respiratory virus panel | Human metapneumovirus and Respiratory syncytial virus RNA panel | 0.796 | 0 | 0 |
| Influenza/Respiratory virus panel | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel | 0.794 | 2 | 45,357 |
| Legionella pneumophila antigen | Legionella pneumophila Ag | 0.887 | 0 | 0 |
| Legionella pneumophila antigen | Legionella pneumophila 1 Ag | 0.858 | 0 | 0 |
| Legionella pneumophila antigen | Legionella pneumophila Ab | 0.849 | 0 | 0 |
| Legionella pneumophila antigen | Legionella pneumophila 2 Ab | 0.828 | 0 | 0 |
| Legionella pneumophila antigen | Legionella pneumophila 1 Ab | 0.826 | 0 | 0 |
| Metapneumovirus antigen | Human metapneumovirus Ag | 0.834 | 1 | 301 |
| Metapneumovirus antigen | Avian metapneumovirus Ab | 0.785 | 0 | 0 |
| Metapneumovirus antigen | Avian metapneumovirus C Ab | 0.782 | 0 | 0 |
| Metapneumovirus antigen | Avian metapneumovirus A Ab | 0.771 | 0 | 0 |
| Metapneumovirus antigen | Avian metapneumovirus | 0.770 | 0 | 0 |
| Mycophenolic acid glucuronide | Mycophenolate glucuronide | 0.890 | 0 | 0 |
| Mycophenolic acid glucuronide | Mycophenolate acyl-glucuronide | 0.843 | 0 | 0 |
| Mycoplasma pneumoniae antibody | Mycoplasma pneumoniae Ab | 0.902 | 2 | 20,258 |
| Mycoplasma pneumoniae antibody | Mycoplasma pneumoniae IgG | 0.878 | 4 | 10,820 |
| Mycoplasma pneumoniae antibody | Mycoplasma pneumoniae IgM | 0.872 | 3 | 16,231 |
| Mycoplasma pneumoniae antibody | Mycoplasma pneumoniae IgG+IgM | 0.848 | 0 | 0 |
| Mycoplasma pneumoniae antibody | Mycoplasma pneumoniae IgA | 0.845 | 0 | 0 |
| Mycoplasma pneumoniae IgG antibody | Mycoplasma pneumoniae IgG | 0.973 | 4 | 10,820 |
| Mycoplasma pneumoniae IgG antibody | Mycoplasma pneumoniae IgG+IgM | 0.918 | 0 | 0 |
| Mycoplasma pneumoniae IgG antibody | Mycoplasma pneumoniae IgM | 0.911 | 3 | 16,231 |
| Mycoplasma pneumoniae IgG antibody | Mycoplasma pneumoniae IgA | 0.862 | 0 | 0 |
| Mycoplasma pneumoniae IgG antibody | Mycoplasma pneumoniae Ab | 0.851 | 2 | 20,258 |
| Mycoplasma pneumoniae IgM antibody | Mycoplasma pneumoniae IgM | 0.973 | 3 | 16,231 |
| Mycoplasma pneumoniae IgM antibody | Mycoplasma pneumoniae IgG | 0.930 | 4 | 10,820 |
| Mycoplasma pneumoniae IgM antibody | Mycoplasma pneumoniae IgG+IgM | 0.917 | 0 | 0 |
| Mycoplasma pneumoniae IgM antibody | Mycoplasma pneumoniae IgA | 0.883 | 0 | 0 |
| Mycoplasma pneumoniae IgM antibody | Chlamydophila pneumoniae IgM | 0.868 | 4 | 7,678 |
| Norovirus antigen | Norovirus Ag | 0.863 | 1 | 1,048 |
| Norovirus antigen | Norovirus genogroup II Ag | 0.778 | 0 | 0 |
| Norovirus antigen | Norovirus genogroup I Ag | 0.773 | 0 | 0 |
| Norovirus antigen | Norovirus RNA | 0.766 | 1 | 17,197 |
| Parainfluenza virus 1 antigen | Parainfluenza virus 1 Ag | 0.913 | 1 | 1,146 |
| Parainfluenza virus 1 antigen | Parainfluenza virus 1+2+3 Ag | 0.859 | 0 | 0 |
| Parainfluenza virus 1 antigen | Parainfluenza virus 1 | 0.850 | 0 | 0 |
| Parainfluenza virus 1 antigen | Parainfluenza virus 1 IgG | 0.843 | 0 | 0 |
| Parainfluenza virus 1 antigen | Parainfluenza virus 1 IgM | 0.837 | 0 | 0 |
| Parainfluenza virus 1 IgG antibody | Parainfluenza virus 1 IgG | 0.977 | 0 | 0 |
| Parainfluenza virus 1 IgG antibody | Parainfluenza virus 1 IgM | 0.931 | 0 | 0 |
| Parainfluenza virus 1 IgG antibody | Parainfluenza virus 3 IgG | 0.910 | 0 | 0 |
| Parainfluenza virus 1 IgG antibody | Parainfluenza virus 2 IgG | 0.907 | 0 | 0 |
| Parainfluenza virus 1 IgG antibody | Parainfluenza virus 4 IgG | 0.906 | 0 | 0 |
| Parainfluenza virus 2 antigen | Parainfluenza virus 2 Ag | 0.873 | 1 | 1,147 |
| Parainfluenza virus 2 antigen | Canine parainfluenza virus 2 Ag | 0.848 | 0 | 0 |
| Parainfluenza virus 2 antigen | Parainfluenza virus 2 IgG | 0.842 | 0 | 0 |
| Parainfluenza virus 2 antigen | Parainfluenza virus Ag | 0.834 | 0 | 0 |
| Parainfluenza virus 2 antigen | Parainfluenza virus 2 IgM | 0.833 | 0 | 0 |
| Parainfluenza virus 3 antigen | Parainfluenza virus 3 Ag | 0.875 | 1 | 1,147 |
| Parainfluenza virus 3 antigen | Parainfluenza virus 3 | 0.855 | 0 | 0 |
| Parainfluenza virus 3 antigen | Parainfluenza virus 3 IgM | 0.842 | 0 | 0 |
| Parainfluenza virus 3 antigen | Parainfluenza virus Ag | 0.840 | 0 | 0 |
| Parainfluenza virus 3 antigen | Parainfluenza virus 3 IgG | 0.836 | 0 | 0 |
| Pneumocystis jirovecii antigen | Pneumocystis jirovecii Ag | 0.871 | 0 | 0 |
| Pneumocystis jirovecii antigen | Pneumocystis jiroveci Ag | 0.866 | 0 | 0 |
| Pneumocystis jirovecii antigen | Pneumocystis jirovecii DNA | 0.796 | 1 | 5,301 |
| Pneumocystis jirovecii antigen | Pneumocystis jirovecii | 0.784 | 0 | 0 |
| Respiratory virus antigen panel | Respiratory pathogens panel | 0.858 | 0 | 0 |
| Respiratory virus antigen panel | Respiratory viral pathogens DNA and RNA panel | 0.814 | 0 | 0 |
| Respiratory virus antigen panel | Respiratory pathogens DNA and RNA panel | 0.788 | 0 | 0 |
| Respiratory virus antigen panel | Respiratory virus Ag | 0.788 | 0 | 0 |
| Respiratory virus antigen panel | Influenza virus A and B and Respiratory syncytial virus RNA panel | 0.783 | 0 | 0 |
| Rotavirus antigen | Rotavirus Ag | 0.864 | 0 | 0 |
| Rotavirus antigen | Rotavirus A Ag | 0.851 | 0 | 0 |
| Rotavirus antigen | Rotavirus Ab | 0.820 | 0 | 0 |
| Rotavirus antigen | Rotavirus IgG | 0.803 | 0 | 0 |
| Rotavirus antigen | Rotavirus IgA | 0.796 | 0 | 0 |
| Squamous cell carcinoma antigen | Squamous cell carcinoma Ag | 0.859 | 3 | 1,450 |
| Squamous cell carcinoma antigen | Squamous cell carcinoma | 0.767 | 0 | 0 |
| Streptococcus pneumoniae antigen | Streptococcus pneumoniae Ag | 0.879 | 2 | 4,336 |
| Streptococcus pneumoniae antigen | Streptococcus pneumoniae Ab | 0.798 | 0 | 0 |
| Streptococcus pneumoniae antigen | Streptococcus pneumoniae | 0.768 | 0 | 0 |
| Streptococcus pneumoniae antigen | Streptococcus pneumoniae IgM | 0.765 | 0 | 0 |
| Streptococcus pneumoniae antigen | Streptococcus pneumoniae IgG | 0.764 | 0 | 0 |
| Virus antigen | (none scored >= 0.75) |  |  |  |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Ratio | Ratio | 1.000 | 88 | 786,172 |
| Type | Type | 1.000 | 17 | 482,606 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Immunoassay | Immunoassay | 1.000 | 164 | 322,567 |
| Nucleic acid amplification | Nucleic acid amplification with probe detection | 0.848 | 115 | 2,413,483 |
| Nucleic acid amplification | Nucleic acid amplification with non-probe detection | 0.810 | 1 | 7,786 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| ^Patient | ^Patient | 1.000 | 20 | 396,517 |
| Bile | Bile fluid | 0.784 | 0 | 0 |
| Cerebral spinal fluid | Cerebral spinal fluid | 1.000 | 150 | 183,922 |
| Nasal secretion | Nasal fluid | 0.816 | 0 | 0 |
| Pharyngeal secretion | (none scored >= 0.75) |  |  |  |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Stool | Stool | 1.000 | 42 | 537,967 |
| Stool | Stool.wet | 0.760 | 0 | 0 |
| Stool | Stool^Patient.gastrointestinal | 0.756 | 0 | 0 |
| Urine | Urine | 1.000 | 586 | 16,080,701 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 711 | -adenag |  | 1964 | 100 |  | -Adenovirus, antigeeni |  |  | Adenovirus antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 712 | -bokaag |  | 187 | 100 |  |  |  |  | Bocavirus antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 713 | -coinrsv |  | 2490 | 100 |  |  |  |  | Influenza virus+Respiratory syncytial virus | Presence or Threshold |  |  | Ord |  | FALSE |
| 714 | -inabrsv |  | 19142 | 100 |  |  |  |  | Influenza virus A+B+Respiratory syncytial virus antigen panel |  |  |  |  |  | TRUE |
| 715 | -infaag |  | 10730 | 100 |  | -Influenssa A -virus, antigeeni |  |  | Influenza A virus antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 716 | -infabag |  | 15107 | 100 |  | -Influenssa A ja B -virus, antigeeni |  |  | Influenza virus A+B antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 717 | -infabnh |  | 961 | 100 |  |  |  |  | Influenza virus A+B RNA | Presence or Threshold | Nucleic acid amplification |  | Ord |  | FALSE |
| 718 | -infah03 |  | 227 | 100 |  |  |  |  | Influenza A virus H3 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 719 | -infah09 |  | 488 | 100 |  |  |  |  | Influenza A virus H1N1-2009 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 720 | -infah1 |  | 480 | 100 |  |  |  |  | Influenza A virus H1 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 721 | -infah3 |  | 261 | 100 |  |  |  |  | Influenza A virus H3 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 722 | -infavt |  | 1271 | 100 |  |  |  |  | Influenza A virus | Type |  |  | Nom |  | FALSE |
| 723 | -infbag |  | 10722 | 100 |  | -Influenssa B -virus, antigeeni |  |  | Influenza B virus antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 724 | -infbvt |  | 1271 | 100 |  |  |  |  | Influenza B virus | Type |  |  | Nom |  | FALSE |
| 725 | -infl.a |  | 220 | 100 |  |  |  |  | Influenza A virus | Presence or Threshold |  |  | Ord |  | FALSE |
| 726 | -infl.b |  | 220 | 100 |  |  |  |  | Influenza B virus | Presence or Threshold |  |  | Ord |  | FALSE |
| 727 | -infrpak |  | 1338 | 100 |  |  |  |  | Influenza/Respiratory virus panel |  |  |  |  |  | TRUE |
| 728 | -infrsv |  | 162 | 100 |  |  |  |  | Influenza virus+Respiratory syncytial virus | Presence or Threshold |  |  | Ord |  | FALSE |
| 729 | -ivf-et |  | 194 | 100 |  |  |  | Special technique | Embryo transfer | Finding |  | ^Patient | Nar |  | FALSE |
| 730 | -koroag |  | 625 | 100 |  |  |  |  | Coronavirus antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 731 | -metpnag |  | 370 | 100 |  |  |  |  | Metapneumovirus antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 732 | -pin1ag |  | 1146 | 100 |  | -Parainfluenssa 1 -virus, antigeeni |  |  | Parainfluenza virus 1 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 733 | -pin2ag |  | 1147 | 100 |  | -Parainfluenssa 2 -virus, antigeeni |  |  | Parainfluenza virus 2 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 734 | -pin3ag |  | 1147 | 100 |  | -Parainfluenssa 3 -virus, antigeeni |  |  | Parainfluenza virus 3 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 735 | -pinf1ag |  | 235 | 100 |  |  |  |  | Parainfluenza virus 1 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 736 | -pinf2ag |  | 235 | 100 |  |  |  |  | Parainfluenza virus 2 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 737 | -pinf3ag |  | 235 | 100 |  |  |  |  | Parainfluenza virus 3 antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 738 | -pnjiag |  | 188 | 100 |  | -Pneumocystis jirovecii, antigeeni |  |  | Pneumocystis jirovecii antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 739 | -rvirag |  | 3025 | 100 |  | -Respiratoristen virusten antigeeni |  |  | Respiratory virus antigen panel |  |  |  |  |  | TRUE |
| 740 | -stpnag |  | 4094 | 100 |  | -Streptococcus pneumoniae, antigeeni |  |  | Streptococcus pneumoniae antigen | Presence or Threshold |  |  | Ord |  | FALSE |
| 741 | bi-inflamm |  | 311 | 100 |  |  | Bile |  | Inflammation | Presence or Threshold |  | Bile | Ord | Point in time (spot) | FALSE |
| 742 | f-adenag |  | 863 | 100 |  | F -Adenovirus, antigeeni | Feces |  | Adenovirus antigen | Presence or Threshold |  | Stool | Ord | Point in time (spot) | FALSE |
| 743 | f-giarag |  | 218 | 100 |  | F -Giardia, antigeeni | Feces |  | Giardia lamblia antigen | Presence or Threshold |  | Stool | Ord | Point in time (spot) | FALSE |
| 744 | f-gicrag |  | 163 | 99.39 |  |  | Feces |  | Giardia lamblia+Cryptosporidium antigen | Presence or Threshold |  | Stool | Ord | Point in time (spot) | FALSE |
| 745 | f-noroag |  | 1048 | 100 |  |  | Feces |  | Norovirus antigen | Presence or Threshold |  | Stool | Ord | Point in time (spot) | FALSE |
| 746 | f-rotaag |  | 886 | 100 |  | F -Rotavirus, antigeeni | Feces |  | Rotavirus antigen | Presence or Threshold |  | Stool | Ord | Point in time (spot) | FALSE |
| 747 | f-virag |  | 489 | 100 |  |  | Feces |  | Virus antigen | Presence or Threshold |  | Stool | Ord | Point in time (spot) | FALSE |
| 748 | li-adenabg |  | 215 | 100 |  | Li-Adenovirus, IgG-vasta-aineet | Cerebrospinal fluid |  | Adenovirus IgG antibody | Presence or Threshold |  | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 749 | li-infaabg | eiu | 40 | 0 |  | Li-Influenssa A -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza A virus IgG antibody | Arbitrary Concentration |  | Cerebral spinal fluid | Qn | Point in time (spot) | FALSE |
| 750 | li-infaabg |  | 240 | 100 |  | Li-Influenssa A -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza A virus IgG antibody | Presence or Threshold |  | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 751 | li-infbabg | eiu | 18 | 0 |  | Li-Influenssa B -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza B virus IgG antibody | Arbitrary Concentration |  | Cerebral spinal fluid | Qn | Point in time (spot) | FALSE |
| 752 | li-infbabg |  | 258 | 100 |  | Li-Influenssa B -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza B virus IgG antibody | Presence or Threshold |  | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 753 | li-mypnab |  | 614 | 100 |  | Li-Mycoplasma pneumoniae, vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae antibody | Presence or Threshold |  | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 754 | li-mypnabg | eiu | 32 | 0 |  | Li-Mycoplasma pneumoniae, IgG-vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae IgG antibody | Arbitrary Concentration |  | Cerebral spinal fluid | Qn | Point in time (spot) | FALSE |
| 755 | li-mypnabg |  | 1292 | 100 |  | Li-Mycoplasma pneumoniae, IgG-vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae IgG antibody | Presence or Threshold |  | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 756 | li-mypnabm |  | 1314 | 100 |  | Li-Mycoplasma pneumoniae, IgM-vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae IgM antibody | Presence or Threshold |  | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 757 | li-pin1abg | eiu | 7 | 0 |  | Li-Parainfluenssa 1 -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Parainfluenza virus 1 IgG antibody | Arbitrary Concentration |  | Cerebral spinal fluid | Qn | Point in time (spot) | FALSE |
| 758 | li-pin1abg |  | 161 | 100 |  | Li-Parainfluenssa 1 -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Parainfluenza virus 1 IgG antibody | Presence or Threshold |  | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 759 | ns-infab/r |  | 181 | 100 |  |  | Nasal secretion |  | Influenza virus A+B | Presence or Threshold |  | Nasal secretion | Ord | Point in time (spot) | FALSE |
| 760 | ps-adenag |  | 1955 | 100 |  | Ps-Adenovirus, antigeeni (NPS-näyte) | Pharyngeal secretion |  | Adenovirus antigen | Presence or Threshold |  | Pharyngeal secretion | Ord | Point in time (spot) | FALSE |
| 761 | ps-infaag |  | 11885 | 100 |  |  | Pharyngeal secretion |  | Influenza A virus antigen | Presence or Threshold |  | Pharyngeal secretion | Ord | Point in time (spot) | FALSE |
| 762 | ps-infbag |  | 11881 | 100 |  |  | Pharyngeal secretion |  | Influenza B virus antigen | Presence or Threshold |  | Pharyngeal secretion | Ord | Point in time (spot) | FALSE |
| 763 | rvirag-o |  | 340 | 100 |  |  |  | Qualitative test (also semi-quantitative) | Respiratory virus antigen panel |  |  |  | Ord |  | TRUE |
| 764 | s-adenabg | eiu | 240 | 0 | [29.8, 39.96, 46.52, 56.21, 66.99, 76.86, 88.44, 100.94, 123.7] | S -Adenovirus, IgG-vasta-aineet | Serum |  | Adenovirus IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 765 | s-adenabg |  | 30 | 96.67 |  | S -Adenovirus, IgG-vasta-aineet | Serum |  | Adenovirus IgG antibody | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 766 | s-infaabg | eiu | 288 | 0 | [44.84, 67.49, 80.03, 92.84, 100.98, 109.5, 120.03, 134.44, 150.75] | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  | Influenza A virus IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 767 | s-infaabg | u/ml | 31 | 0 |  | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  | Influenza A virus IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 768 | s-infaabg |  | 46 | 71.74 |  | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  | Influenza A virus IgG antibody | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 769 | s-infbab | eiu | 84 | 0 | [37, 45.5, 59.88, 67.83, 76.88, 87.5, 108.12, 125, 142] | S -Influenssa B -virus, vasta-aineet | Serum |  | Influenza B virus antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 770 | s-infbab | u/ml | 20 | 0 |  | S -Influenssa B -virus, vasta-aineet | Serum |  | Influenza B virus antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 771 | s-infbab |  | 20 | 100 |  | S -Influenssa B -virus, vasta-aineet | Serum |  | Influenza B virus antibody | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 772 | s-infbabg | eiu | 202 | 0 | [27.36, 39.2, 49.01, 55.71, 69.1, 81.14, 95.12, 117.99, 145.85] | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  | Influenza B virus IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 773 | s-infbabg | u/ml | 5 | 0 |  | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  | Influenza B virus IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 774 | s-infbabg |  | 19 | 73.68 |  | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  | Influenza B virus IgG antibody | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 775 | s-infli | mg/l | 4337 | 0.09 | [2.45, 4.22, 5.77, 7.21, 8.78, 10.55, 12.36, 14.93, 19.68] | S -Infliksimabi | Serum |  | Infliximab | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 776 | s-infli | ug/l | 62 | 0 |  | S -Infliksimabi | Serum |  | Infliximab | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 777 | s-infli | âug/ml | 5 | 0 |  | S -Infliksimabi | Serum |  | Infliximab | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 778 | s-infli |  | 1486 | 32.77 | [2.05, 3.56, 5.06, 6.2, 7.59, 8.94, 10.97, 13.84, 18.03] | S -Infliksimabi | Serum |  | Infliximab | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 779 | s-infliab | au/ml | 413 | 0.73 | [6.57, 14.16, 21.28, 34.4, 52.11, 73.2, 118.89, 190.88, 374.2] | S -Infliksimabi, vasta-aineet | Serum |  | Infliximab antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 780 | s-infliab |  | 4455 | 99.89 |  | S -Infliksimabi, vasta-aineet | Serum |  | Infliximab antibody | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 781 | s-infliks | mg/l | 951 | 0 | [1.81, 3, 4.49, 5.55, 6.66, 8.19, 10.34, 13.5, 19.13] |  | Serum |  | Infliximab | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 782 | s-infliks |  | 310 | 30.97 | [1.21, 2.24, 3.08, 4.32, 5.17, 6.19, 7.17, 7.95, 9.17] |  | Serum |  | Infliximab | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 783 | s-inflipa |  | 4630 | 100 |  |  | Serum |  | Infliximab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 784 | s-micfaeg | mg/l | 45 | 0 |  |  | Serum |  | Mycophenolic acid glucuronide | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 785 | s-micfaeg |  | 90 | 76.67 |  |  | Serum |  | Mycophenolic acid glucuronide | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 786 | s-mypnab |  | 19694 | 99.92 |  | S -Mycoplasma pneumoniae, vasta-aineet | Serum |  | Mycoplasma pneumoniae antibody | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 787 | s-mypnabg | au/ml | 2298 | 0 | [0.52, 1.18, 1.86, 2.68, 3.78, 5.69, 8.99, 16.54, 33.76] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 788 | s-mypnabg | eiu | 9577 | 0 | [51.21, 64.99, 79.08, 95.09, 113.13, 134.88, 160.85, 200.43, 260.64] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 789 | s-mypnabg | form | 53 | 0 |  | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 790 | s-mypnabg | ru/ml | 384 | 0 | [19.56, 23.19, 26.12, 30.65, 34.99, 40.45, 50.94, 60.03, 79.86] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 791 | s-mypnabg |  | 4994 | 100 | [0.53, 1.1, 1.73, 2.48, 3.76, 5.77, 9.79, 21.47, 68.82] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG antibody | Arbitrary Concentration | Immunoassay | Serum | OrdQn | Point in time (spot) | FALSE |
| 792 | s-mypnabm | form | 16 | 0 |  | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 793 | s-mypnabm | index | 3618 | 0 | [1.53, 2.22, 2.83, 3.43, 4.2, 5.16, 6.56, 8.38, 11.18] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM antibody | Ratio | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 794 | s-mypnabm | s/co | 1089 | 0 | [0.1, 0.1, 0.2, 0.2, 0.3, 0.33, 0.47, 0.63, 1.13] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM antibody | Ratio | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 795 | s-mypnabm |  | 12775 | 100 | [1.19, 1.67, 2.14, 2.58, 3.04, 3.6, 4.51, 5.78, 8.21] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM antibody | Ratio | Immunoassay | Serum | OrdQn | Point in time (spot) | FALSE |
| 796 | s-pin1abg | eiu | 209 | 0 | [51.38, 65.97, 78.97, 87.7, 96.4, 106.81, 114.5, 126.75, 144.62] | S -Parainfluenssa 1 -virus, IgG-vasta-aineet | Serum |  | Parainfluenza virus 1 IgG antibody | Arbitrary Concentration | Immunoassay | Serum | Qn | Point in time (spot) | FALSE |
| 797 | s-pin1abg |  | 9 | 88.89 |  | S -Parainfluenssa 1 -virus, IgG-vasta-aineet | Serum |  | Parainfluenza virus 1 IgG antibody | Presence or Threshold | Immunoassay | Serum | Ord | Point in time (spot) | FALSE |
| 798 | s-scc-ag | ug/l | 959 | 0 | [0.88, 1.03, 1.2, 1.38, 1.6, 2.01, 2.55, 3.56, 6.69] | S -Squamous cell carsinoma, antigeeni | Serum | Antigen | Squamous cell carcinoma antigen | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 799 | s-scc-ag |  | 493 | 95.94 |  | S -Squamous cell carsinoma, antigeeni | Serum | Antigen | Squamous cell carcinoma antigen | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 800 | u-lepnag |  | 3943 | 100 |  | U -Legionella pneumophila, antigeeni | Urine |  | Legionella pneumophila antigen | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 801 | u-pneuag |  | 2058 | 100 |  |  | Urine |  | Streptococcus pneumoniae antigen | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |
| 802 | u-stpnag |  | 2546 | 100 |  | U -Streptococcus pneumoniae, antigeeni | Urine |  | Streptococcus pneumoniae antigen | Presence or Threshold |  | Urine | Ord | Point in time (spot) | FALSE |

