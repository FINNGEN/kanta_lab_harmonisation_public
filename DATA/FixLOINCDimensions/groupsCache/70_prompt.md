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
Here is group 70.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| 10-Hydroxycarbazepine | 10-Hydroxycarbazepine | 1.000 | 4 | 5,002 |
| 10-Hydroxycarbazepine | 10-Hydroxycarbazepine/Creatinine | 0.846 | 0 | 0 |
| 10-Hydroxycarbazepine | 10-Hydroxycarbazepine^trough | 0.830 | 0 | 0 |
| 10-Hydroxycarbazepine | OXcarbazepine + 10-Hydroxycarbazepine | 0.811 | 0 | 0 |
| Acetaminophen | Acetaminophen | 1.000 | 3 | 5,169 |
| Alder IgE Ab | Alder Ab.IgE | 0.924 | 0 | 0 |
| Alder IgE Ab | Alder Ab.IgE.RAST class | 0.846 | 0 | 0 |
| Alder IgE Ab | Alder Ab.IgG | 0.833 | 0 | 0 |
| Alder IgE Ab | IgE Ab | 0.803 | 0 | 0 |
| Alder IgE Ab | Japanese alder Ab.IgE | 0.798 | 0 | 0 |
| Beta carotene | (none scored >= 0.75) |  |  |  |
| Bile acids.total | Chenodeoxycholate+Cholate/Bile acid.total | 0.834 | 0 | 0 |
| Bile acids.total | Bile acid panel | 0.763 | 0 | 0 |
| Bile acids.total | Bile acid | 0.758 | 0 | 0 |
| Bile acids.total | Alkaline phosphatase.bile/Alkaline phosphatase.total | 0.751 | 0 | 0 |
| Bordetella parapertussis | Bordetella parapertussis | 1.000 | 0 | 0 |
| Bordetella parapertussis | Bordetella parapertussis Ab | 0.806 | 0 | 0 |
| Bordetella parapertussis | Bordetella parapertussis Ag | 0.793 | 0 | 0 |
| Bordetella parapertussis | Bordetella parapertussis IgG | 0.758 | 0 | 0 |
| Bordetella parapertussis | Bordetella parapertussis DNA | 0.758 | 1 | 3,745 |
| Brazil nut IgE Ab | Brazil Nut (Bertholletia excelsa) IgE | 0.899 | 0 | 0 |
| Brazil nut IgE Ab | Brazil Nut (Bertholletia excelsa) IgG4 | 0.871 | 0 | 0 |
| Brazil nut IgE Ab | Brazil Nut (Bertholletia excelsa) recombinant (rBer e) 1 IgE | 0.863 | 1 | 431 |
| Brazil nut IgE Ab | Brazil Nut (Bertholletia excelsa) IgG | 0.858 | 0 | 0 |
| Brazil nut IgE Ab | Brazilian Rubber Tree IgE | 0.825 | 0 | 0 |
| Calprotectin | Calprotectin | 1.000 | 5 | 164,242 |
| Carbamazepine | carBAMazepine | 1.000 | 3 | 4,575 |
| Carbamazepine | carBAMazepine.bound | 0.895 | 0 | 0 |
| Carbamazepine | carBAMazepine free | 0.889 | 0 | 0 |
| Carbamazepine | carBAMazepine^peak | 0.858 | 0 | 0 |
| Carbamazepine | carBAMazepine IgE | 0.850 | 0 | 0 |
| Carbamazepine 10,11-epoxide | Carbamazepine 10,11-Epoxide | 1.000 | 0 | 0 |
| Carbamazepine 10,11-epoxide | Carbamazepine 10,11-Epoxide.bound | 0.886 | 0 | 0 |
| Carbamazepine 10,11-epoxide | Carbamazepine 10,11-epoxide free | 0.872 | 0 | 0 |
| Carbamazepine 10,11-epoxide | carbamazepine 10,11-Epoxide^trough | 0.848 | 0 | 0 |
| Cardiolipin Ab | Cardiolipin Ab | 1.000 | 0 | 0 |
| Cardiolipin Ab | Cardiolipin IgG | 0.839 | 8 | 11,278 |
| Cardiolipin Ab | Cardiolipin | 0.830 | 0 | 0 |
| Cardiolipin Ab | Cardiolipin IgM | 0.801 | 2 | 1,671 |
| Cardiolipin Ab | Cardiolipin IgA | 0.789 | 0 | 0 |
| Cardiolipin IgG Ab | Cardiolipin IgG | 0.948 | 8 | 11,278 |
| Cardiolipin IgG Ab | Cardiolipin Ab | 0.905 | 0 | 0 |
| Cardiolipin IgG Ab | Cardiolipin IgM | 0.868 | 2 | 1,671 |
| Cardiolipin IgG Ab | Cardiolipin IgA | 0.834 | 0 | 0 |
| Cardiolipin IgG Ab | Cardiolipin IgG and IgM panel | 0.816 | 0 | 0 |
| Cardiolipin IgM Ab | Cardiolipin IgM | 0.949 | 2 | 1,671 |
| Cardiolipin IgM Ab | Cardiolipin Ab | 0.872 | 0 | 0 |
| Cardiolipin IgM Ab | Cardiolipin IgG | 0.868 | 8 | 11,278 |
| Cardiolipin IgM Ab | Cardiolipin IgA | 0.822 | 0 | 0 |
| Cardiolipin IgM Ab | Cardiolipin IgM B2GP1 dependent | 0.797 | 0 | 0 |
| Carnitine | Carnitine | 1.000 | 2 | 343 |
| Carnitine | Carnitine (C0) | 0.824 | 0 | 0 |
| Carnitine | Carnitine/Creatinine | 0.777 | 0 | 0 |
| Carnitine | Carnitine esters | 0.776 | 0 | 0 |
| Carnitine | Carnitine/Acylcarnitine | 0.772 | 0 | 0 |
| Carnitine.free | Carnitine esters/Carnitine.free (C0) | 0.799 | 0 | 0 |
| Carnitine.free | Carnitine.free (C0)/Creatinine | 0.786 | 0 | 0 |
| Carnitine.free | Carnitine | 0.785 | 2 | 343 |
| Carnitine.free | Carnitine free (C0) | 0.777 | 2 | 347 |
| Carnitine.free | Carnitine.free (C0)/Carnitine.total | 0.772 | 0 | 0 |
| Cashew nut IgE Ab | Cashew nut (Anacardium occidentale) IgE | 0.904 | 0 | 0 |
| Cashew nut IgE Ab | Cashew nut (Anacardium occidentale) IgG | 0.878 | 0 | 0 |
| Cashew nut IgE Ab | Cashew nut (Anacardium occidentale) IgG4 | 0.871 | 0 | 0 |
| Cashew nut IgE Ab | Cashew nut (Anacardium occidentale) recombinant (rAna o) 2 IgE | 0.835 | 0 | 0 |
| Cashew nut IgE Ab | Nut Allergen Mix (Cashew+Pecan or Hickory nut+English walnut) IgE | 0.783 | 0 | 0 |
| Coconut IgE Ab | Coconut (Cocos nucifera) IgE | 0.873 | 0 | 0 |
| Coconut IgE Ab | Coconut (Cocos nucifera) IgG | 0.862 | 0 | 0 |
| Coconut IgE Ab | Coconut (Cocos nucifera) IgG4 | 0.843 | 0 | 0 |
| Coconut IgE Ab | Coconut (Cocos nucifera) basophil bound Ab | 0.829 | 0 | 0 |
| Coconut IgE Ab | Cocos nucifera Ab.IgE/IgE.total | 0.825 | 0 | 0 |
| Cotinine | Cotinine | 1.000 | 0 | 0 |
| Cotinine | Cotinine/Creatinine | 0.842 | 0 | 0 |
| Cotinine | Norcotinine | 0.811 | 0 | 0 |
| Cotinine | Cotinine cutoff | 0.803 | 0 | 0 |
| Cotinine | Nicotine+Cotinine | 0.767 | 0 | 0 |
| Hazelnut IgE Ab | Hazelnut Pollen Ab.IgG | 0.856 | 0 | 0 |
| Hazelnut IgE Ab | Hazelnut (Corylus avellana) IgE | 0.854 | 3 | 63 |
| Hazelnut IgE Ab | Hazelnut (Corylus avellana) basophil bound Ab | 0.849 | 0 | 0 |
| Hazelnut IgE Ab | Hazelnut (Corylus avellana) IgG4 | 0.842 | 0 | 0 |
| Hazelnut IgE Ab | Hazelnut (Corylus avellana) IgG | 0.835 | 0 | 0 |
| Histology | Histology | 1.000 | 0 | 0 |
| Histology | Histology type | 0.805 | 0 | 0 |
| Karyotype | Karyotype | 1.000 | 2 | 4,295 |
| Macroalkaline phosphatase | Alkaline phosphatase | 0.834 | 13 | 2,756,532 |
| Macroalkaline phosphatase | Alkaline phosphatase.macro | 0.789 | 0 | 0 |
| Macroalkaline phosphatase | Alkaline phosphatase.macromolecular | 0.787 | 0 | 0 |
| Macroalkaline phosphatase | Alkaline phosphatase isoenzyme | 0.768 | 0 | 0 |
| Macroalkaline phosphatase.fraction 1 | Alkaline phosphatase.other fractions | 0.836 | 3 | 3,363 |
| Macroalkaline phosphatase.fraction 2 | Alkaline phosphatase.other fractions | 0.825 | 3 | 3,363 |
| Macroalkaline phosphatase.fraction 2 | Alkaline phosphatase.intestinal 2 | 0.756 | 0 | 0 |
| Macroalkaline phosphatase/Alkaline phosphatase.total | Alkaline phosphatase.macro/Alkaline phosphatase.total | 0.868 | 0 | 0 |
| Macroalkaline phosphatase/Alkaline phosphatase.total | Alkaline phosphatase.bone/Alkaline phosphatase.total | 0.839 | 0 | 0 |
| Macroalkaline phosphatase/Alkaline phosphatase.total | Alkaline phosphatase.regan/Alkaline phosphatase.total | 0.839 | 0 | 0 |
| Macroalkaline phosphatase/Alkaline phosphatase.total | Alkaline phosphatase.intestinal/Alkaline phosphatase.total | 0.830 | 0 | 0 |
| Macroalkaline phosphatase/Alkaline phosphatase.total | Alkaline phosphatase.heat stable/Alkaline phosphatase.total | 0.829 | 0 | 0 |
| Mumps virus IgG Ab | Mumps virus IgG | 0.967 | 0 | 0 |
| Mumps virus IgG Ab | Mumps virus IgG+IgM | 0.926 | 0 | 0 |
| Mumps virus IgG Ab | Mumps virus Ab | 0.915 | 0 | 0 |
| Mumps virus IgG Ab | Mumps virus IgG and IgM | 0.909 | 0 | 0 |
| Mumps virus IgG Ab | Mumps virus IgM | 0.902 | 0 | 0 |
| Mumps virus IgM Ab | Mumps virus IgM | 0.961 | 0 | 0 |
| Mumps virus IgM Ab | Mumps virus IgG | 0.923 | 0 | 0 |
| Mumps virus IgM Ab | Mumps virus IgG+IgM | 0.923 | 0 | 0 |
| Mumps virus IgM Ab | Mumps virus Ab | 0.919 | 0 | 0 |
| Mumps virus IgM Ab | Mumps virus IgG and IgM | 0.901 | 0 | 0 |
| Ovary Ab | Ovary Ab | 1.000 | 0 | 0 |
| Oxcarbazepine | OXcarbazepine | 1.000 | 0 | 0 |
| Oxcarbazepine | OXcarbazepine + 10-Hydroxycarbazepine | 0.807 | 0 | 0 |
| Oxcarbazepine | OXcarbazepine^trough | 0.796 | 0 | 0 |
| Paraprotein | (none scored >= 0.75) |  |  |  |
| Parvovirus B19 IgG Ab | Parvovirus B19 IgG | 0.971 | 3 | 2,615 |
| Parvovirus B19 IgG Ab | Parvovirus B19 Ab | 0.926 | 0 | 0 |
| Parvovirus B19 IgG Ab | Parvovirus B19 IgG+IgM | 0.911 | 0 | 0 |
| Parvovirus B19 IgG Ab | Parvovirus B19 IgG and IgM | 0.886 | 0 | 0 |
| Parvovirus B19 IgG Ab | Parvovirus B19 IgM | 0.882 | 1 | 2,963 |
| Parvovirus B19 IgG Ab avidity | Rubella virus IgG Avidity | 0.830 | 0 | 0 |
| Parvovirus B19 IgG Ab avidity | Parvovirus B19 IgG | 0.812 | 3 | 2,615 |
| Parvovirus B19 IgG Ab avidity | Measles virus Ab.IgG avidity | 0.810 | 0 | 0 |
| Parvovirus B19 IgG Ab avidity | Parvovirus B19 IgG+IgM | 0.808 | 0 | 0 |
| Parvovirus B19 IgG Ab avidity | Parvovirus B19 IgG and IgM | 0.807 | 0 | 0 |
| Parvovirus B19 IgM Ab | Parvovirus B19 IgM | 0.954 | 1 | 2,963 |
| Parvovirus B19 IgM Ab | Parvovirus B19 Ab | 0.921 | 0 | 0 |
| Parvovirus B19 IgM Ab | Parvovirus B19 IgG | 0.903 | 3 | 2,615 |
| Parvovirus B19 IgM Ab | Parvovirus B19 IgG+IgM | 0.902 | 0 | 0 |
| Parvovirus B19 IgM Ab | Parvovirus B19 IgG and IgM | 0.890 | 0 | 0 |
| Peanut IgE Ab | Peanut (Arachis hypogaea) IgE | 0.869 | 6 | 1,644 |
| Peanut IgE Ab | Peanut (Arachis hypogaea) basophil bound Ab | 0.829 | 0 | 0 |
| Peanut IgE Ab | Peanut (Arachis hypogaea) IgG | 0.827 | 0 | 0 |
| Peanut IgE Ab | Peanut (Arachis hypogaea) IgG4 | 0.823 | 0 | 0 |
| Peanut IgE Ab | Peanut components allergen IgE panel | 0.804 | 0 | 0 |
| Pecan IgE Ab | Pecan or Hickory Nut (Carya illinoinensis nut) IgE | 0.807 | 0 | 0 |
| Pecan IgE Ab | Pecan or Hickory Nut (Carya illinoinensis nut) IgG | 0.802 | 0 | 0 |
| Pecan IgE Ab | Pecan or Hickory Tree (Carya illinoinensis tree) IgE | 0.797 | 0 | 0 |
| Pecan IgE Ab | Carya illinoensis Ab.IgE | 0.789 | 0 | 0 |
| Pecan IgE Ab | Pecan or Hickory Tree (Carya illinoinensis tree) IgG | 0.789 | 0 | 0 |
| Plasmodium | Plasmodium sp | 0.880 | 1 | 1,366 |
| Plasmodium | Plasmodium falciparum | 0.790 | 0 | 0 |
| Plasmodium | Plasmodium stage | 0.759 | 0 | 0 |
| Plasmodium | Plasmodium sp Ag | 0.754 | 0 | 0 |
| Plasmodium | Plasmodium sp Ab | 0.754 | 1 | 50 |
| Pregnancy-associated plasma protein A | Pregnancy associated plasma protein A | 0.986 | 6 | 44,842 |
| Pregnancy-associated plasma protein A | Pregnancy associated plasma protein A^^adjusted | 0.841 | 2 | 21,810 |
| Pregnancy-associated plasma protein A | Pregnancy specific protein 1 | 0.799 | 0 | 0 |
| Pregnancy-associated plasma protein A | Pregnancy associated plasma protein A multiple of the median | 0.790 | 0 | 0 |
| Prothrombin | Prothrombin | 1.000 | 0 | 0 |
| Prothrombin | Prothrombin Ag | 0.765 | 0 | 0 |
| Thrombin time | Thrombin time | 1.000 | 12 | 40,633 |
| Thrombin time | Thrombin time.high dose | 0.795 | 0 | 0 |
| Thrombin time | Thrombin time.factor substitution | 0.773 | 0 | 0 |
| Thrombin time | Clotting time | 0.753 | 0 | 0 |
| Time | Time | 1.000 | 0 | 0 |
| Time | Timing | 0.796 | 0 | 0 |
| Valproate | Valproate | 1.000 | 4 | 37,442 |
| Valproate | Valproate^peak | 0.776 | 0 | 0 |
| Valproate | Valproate.bound | 0.770 | 0 | 0 |
| Valproate | Valproate Free | 0.764 | 0 | 0 |
| Valproate.free | Valproate Free | 0.917 | 0 | 0 |
| Valproate.free | Valproate.free/Valproate.total | 0.835 | 0 | 0 |
| Valproate.free | Valproate.free and Valproate panel | 0.819 | 0 | 0 |
| Valproate.free | Valproate | 0.808 | 4 | 37,442 |
| Valproate.free | Valproate.bound | 0.800 | 0 | 0 |
| Valproate.free/Valproate.total | Valproate.free/Valproate.total | 1.000 | 0 | 0 |
| Valproate.free/Valproate.total | Valproate.bound/Valproate.total | 0.861 | 0 | 0 |
| Valproate.free/Valproate.total | Valproate.free and Valproate panel | 0.828 | 0 | 0 |
| Valproate.free/Valproate.total | Valproate Free | 0.819 | 0 | 0 |
| Walnut IgE Ab | Walnut (Juglans spp) IgE | 0.861 | 0 | 0 |
| Walnut IgE Ab | Black Western Walnut IgE | 0.854 | 0 | 0 |
| Walnut IgE Ab | Walnut (Juglans spp) basophil bound Ab | 0.848 | 0 | 0 |
| Walnut IgE Ab | Walnut (Juglans spp) IgG4 | 0.843 | 0 | 0 |
| Walnut IgE Ab | Walnut (Juglans spp) IgG | 0.834 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Arbitrary Rate | Arbitrary Rate | 1.000 | 0 | 0 |
| Catalytic Concentration | Catalytic Concentration | 1.000 | 228 | 10,802,985 |
| Catalytic Concentration | Relative catalytic concentration | 0.848 | 9 | 39,650 |
| Catalytic Fraction | Catalytic Fraction | 1.000 | 14 | 842 |
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Mass content | Mass Content | 1.000 | 11 | 184,195 |
| Mass Fraction | Mass fraction | 1.000 | 229 | 4,683,692 |
| Number Fraction | Number Fraction | 1.000 | 482 | 8,246,054 |
| Number Fraction | Decimal number fraction | 0.787 | 1 | 6,152 |
| Number Fraction | Time Fraction | 0.765 | 0 | 0 |
| Presence or Identity | Presence or Identity | 1.000 | 79 | 1,946,967 |
| Presence or Threshold | Presence or Threshold | 1.000 | 382 | 10,296,466 |
| Ratio | Ratio | 1.000 | 88 | 786,172 |
| Substance Concentration | Substance Concentration | 1.000 | 1,643 | 51,490,057 |
| Substance Concentration | Substance Concentration Squared | 0.845 | 0 | 0 |
| Substance Concentration | Substance concentration difference | 0.841 | 0 | 0 |
| Substance Concentration | Mass or Substance Concentration | 0.837 | 0 | 0 |
| Substance Concentration | Mass Concentration | 0.772 | 1,215 | 26,086,908 |
| Substance Fraction | Substance Fraction | 1.000 | 0 | 0 |
| Substance Fraction | Substance Ratio | 0.786 | 9 | 237,272 |
| Time | (none scored >= 0.75) |  |  |  |
| Titer | Titer | 1.000 | 146 | 279,254 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Calculated | Calculated | 1.000 | 89 | 12,276,393 |
| Coagulation assay | Coagulation assay | 1.000 | 181 | 3,646,966 |
| Cytogenetics | Cytogenetics | 1.000 | 0 | 0 |
| Electrophoresis | Electrophoresis | 1.000 | 91 | 336,860 |
| Histology | (none scored >= 0.75) |  |  |  |
| Stain | Other stain | 0.858 | 0 | 0 |
| VDRL | VDRL | 1.000 | 3 | 16,230 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| ^Patient | ^Patient | 1.000 | 20 | 396,517 |
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Cerebral spinal fluid | Cerebral spinal fluid | 1.000 | 150 | 183,922 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Platelet poor plasma | Platelet poor plasma | 1.000 | 180 | 1,076,490 |
| Platelet poor plasma | Platelet poor plasma or blood | 0.848 | 0 | 0 |
| Platelet poor plasma | Platelet poor plasma^Control | 0.818 | 0 | 0 |
| Platelet poor plasma | Platelet poor plasma^Fetus | 0.772 | 0 | 0 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Skin | Skin | 1.000 | 3 | 121,968 |
| Stool | Stool | 1.000 | 42 | 537,967 |
| Stool | Stool.wet | 0.760 | 0 | 0 |
| Stool | Stool^Patient.gastrointestinal | 0.756 | 0 | 0 |
| Urine | Urine | 1.000 | 586 | 16,080,701 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 948 | -calpro | mg/l | 368 | 0 | [0.1, 0.31, 0.88, 2.86, 7.72, 16.73, 36.68, 74.3, 206.67] |  |  |  | Calprotectin | Mass Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 949 | -calpro | ug/g | 37 | 0 |  |  |  |  | Calprotectin | Mass content |  |  | Qn | Point in time (spot) | FALSE |
| 950 | -calpro |  | 23 | 21.74 |  |  |  |  | Calprotectin |  |  |  |  | Point in time (spot) | FALSE |
| 951 | 4184sk-padihot |  | 107 | 100 |  |  |  |  | Histology | Finding | Histology | Skin | Nar | Point in time (spot) | FALSE |
| 952 | b-karyot |  | 686 | 100 |  |  | Blood |  | Karyotype | Finding | Cytogenetics | Blood | Nom | Point in time (spot) | FALSE |
| 953 | b-malarv |  | 127 | 100 |  |  | Blood |  | Plasmodium | Presence or Identity | Stain | Blood | Nom | Point in time (spot) | FALSE |
| 954 | b-nakkrea |  | 424 | 100 |  |  | Blood |  |  |  |  | Blood |  | Point in time (spot) | FALSE |
| 955 | b-pakk-e |  | 249 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | TRUE |
| 956 | b-vara |  | 254 | 100 |  |  | Blood |  |  |  |  | Blood |  |  | FALSE |
| 957 | b-varaspr |  | 331 | 99.7 |  |  | Blood |  |  |  |  | Blood |  |  | FALSE |
| 958 | b.parapert |  | 619 | 100 |  |  |  |  | Bordetella parapertussis | Presence or Threshold |  | Blood | Ord | Point in time (spot) | FALSE |
| 959 | du-parprot |  | 369 | 100 |  |  | 24-hour urine |  | Paraprotein | Presence or Identity | Electrophoresis | Urine | Ord | 24 hours | FALSE |
| 960 | f-calpro | ug/g | 144892 | 0.48 | [13.78, 23.28, 35.55, 53.95, 82, 128.24, 215.34, 397.8, 911.98] | F -Kalprotektiini; F -Calprotectin | Feces |  | Calprotectin | Mass content |  | Stool | Qn | Point in time (spot) | FALSE |
| 961 | f-calpro |  | 17874 | 100 | [23.61, 33.46, 47.58, 74.67, 119.83, 157.1, 290.01, 478.43, 993.36] | F -Kalprotektiini; F -Calprotectin | Feces |  | Calprotectin | Finding |  | Stool | Nar | Point in time (spot) | FALSE |
| 962 | f-calpro2 | ug/g | 395 | 0 | [28.88, 40.5, 54.65, 82.87, 126.54, 220.92, 330.47, 583.74, 1304.77] |  | Feces |  | Calprotectin | Mass content |  | Stool | Qn | Point in time (spot) | FALSE |
| 963 | f-calpro2 |  | 97 | 100 |  |  | Feces |  | Calprotectin | Finding |  | Stool | Nar | Point in time (spot) | FALSE |
| 964 | fs-bkarot | nmol/l | 18 | 0 |  | fS-Beetakaroteeni | Fasting serum |  | Beta carotene | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 965 | fs-bkarot | umol/l | 318 | 0 | [0.25, 0.45, 0.6, 0.75, 0.87, 1.06, 1.29, 1.57, 2.19] | fS-Beetakaroteeni | Fasting serum |  | Beta carotene | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 966 | fs-sappih | umol/l | 5416 | 0.04 | [1.58, 2, 2.4, 3, 3.74, 4.45, 5.67, 7.59, 13.61] |  | Fasting serum |  | Bile acids.total | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 967 | fs-sappih |  | 686 | 100 | [2, 2.48, 3.02, 3.91, 4.81, 5.88, 6.86, 8.3, 12.54] |  | Fasting serum |  | Bile acids.total | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 968 | fs-sappihapot | umol/l | 198 | 0 | [1.41, 1.79, 2.06, 2.5, 3.2, 3.97, 4.98, 6.66, 11.59] |  | Fasting serum |  | Bile acids.total | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 969 | fs-sappihapot |  | 30 | 100 |  |  | Fasting serum |  | Bile acids.total | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 970 | li-kardab | titre | 7 | 14.29 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  | Cardiolipin Ab | Titer | VDRL | Cerebral spinal fluid | SemiQn | Point in time (spot) | FALSE |
| 971 | li-kardab |  | 204 | 100 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  | Cardiolipin Ab | Presence or Threshold | VDRL | Cerebral spinal fluid | Ord | Point in time (spot) | FALSE |
| 972 | li-varlikv |  | 111 | 100 |  |  | Cerebrospinal fluid |  |  |  |  | Cerebral spinal fluid |  |  | FALSE |
| 973 | p-kardabg | gpl | 1101 | 6.99 | [1, 1, 1.61, 2, 2, 3, 5.05, 7.62, 12.35] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  | Cardiolipin IgG Ab | Arbitrary Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 974 | p-kardabg | u/ml | 4443 | 0 | [1, 1, 1.08, 2, 2, 2.64, 3.48, 5.89, 13.12] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  | Cardiolipin IgG Ab | Arbitrary Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 975 | p-kardabg |  | 4985 | 95.25 | [1, 1.14, 2, 2, 3.36, 5, 5.97, 9.03, 19.8] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  | Cardiolipin IgG Ab | Presence or Threshold |  | Plasma | Ord | Point in time (spot) | FALSE |
| 976 | p-kardabm | mpl | 1111 | 5.04 | [1, 2, 2, 2.88, 3, 4.6, 7.59, 12.86, 20.09] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  | Cardiolipin IgM Ab | Arbitrary Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 977 | p-kardabm | u/ml | 11 | 0 |  | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  | Cardiolipin IgM Ab | Arbitrary Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 978 | p-kardabm |  | 724 | 89.09 | [1, 1, 1.45, 2, 2, 3, 4, 6, 15] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  | Cardiolipin IgM Ab | Presence or Threshold |  | Plasma | Ord | Point in time (spot) | FALSE |
| 979 | p-pakk-si |  | 260 | 100 |  |  | Plasma |  |  |  |  | Plasma |  |  | TRUE |
| 980 | p-varainr |  | 8332 | 99.99 |  |  | Plasma |  |  |  |  | Plasma |  |  | FALSE |
| 981 | p-varmtr | s | 1488 | 0 | [17.02, 18, 18.87, 19, 19.98, 20, 21, 21.93, 23] |  | Plasma |  | Thrombin time | Time | Coagulation assay | Platelet poor plasma | Qn | Point in time (spot) | FALSE |
| 982 | p-varmtr |  | 111 | 100 |  |  | Plasma |  | Thrombin time | Finding | Coagulation assay | Platelet poor plasma | Ord | Point in time (spot) | FALSE |
| 983 | p-varmtt | % | 1494 | 0 | [41.91, 74.69, 84.09, 92.24, 98.54, 104.26, 111.28, 119.13, 131.18] |  | Plasma |  | Prothrombin | Mass Fraction | Coagulation assay | Platelet poor plasma | Qn | Point in time (spot) | FALSE |
| 984 | p-varmtt |  | 105 | 100 |  |  | Plasma |  | Prothrombin | Finding | Coagulation assay | Platelet poor plasma | Ord | Point in time (spot) | FALSE |
| 985 | s-afmakro | u/l | 2842 | 0 | [3.98, 5.01, 6.23, 7.94, 10.06, 14.01, 21.13, 33.22, 62.9] |  | Serum |  | Macroalkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 986 | s-afmakro |  | 523 | 59.85 | [4, 5, 6, 7.5, 10, 15.29, 22.33, 30.86, 49.44] |  | Serum |  | Macroalkaline phosphatase | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 987 | s-afmaks1 | u/l | 199 | 0 | [25.36, 33.2, 41.05, 48.96, 56.78, 64.23, 71.62, 84.6, 112.64] |  | Serum |  | Macroalkaline phosphatase.fraction 1 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 988 | s-afmaks1 |  | 13 | 0 |  |  | Serum |  | Macroalkaline phosphatase.fraction 1 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 989 | s-afmaks2 | u/l | 205 | 0 | [3.2, 4.72, 5.48, 6.4, 7, 8.07, 11.08, 16.5, 34.56] |  | Serum |  | Macroalkaline phosphatase.fraction 2 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 990 | s-afmaks2 |  | 7 | 14.29 |  |  | Serum |  | Macroalkaline phosphatase.fraction 2 | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 991 | s-afmaksa | % | 94 | 0 | [39.9, 51.85, 57.9, 64.48, 69.3, 73.65, 78.41, 84.08, 89.4] |  | Serum |  | Macroalkaline phosphatase/Alkaline phosphatase.total | Catalytic Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 992 | s-afmaksa | u/l | 2958 | 0 | [25.04, 37.52, 47.03, 56.68, 67.64, 79.81, 95.37, 125.6, 201.78] |  | Serum |  | Macroalkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 993 | s-afmaksa |  | 489 | 65.03 | [32.9, 45.51, 57.63, 71.86, 79.96, 85.36, 96.57, 123.73, 246.45] |  | Serum |  | Macroalkaline phosphatase | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 994 | s-caspähe | u/ml | 895 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.04, 0.13, 1.71] |  | Serum |  | Cashew nut IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 995 | s-caspähe |  | 106 | 80.19 |  |  | Serum |  | Cashew nut IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 996 | s-haspähe | u/ml | 683 | 0.15 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  | Hazelnut IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 997 | s-haspähe |  | 162 | 73.46 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  | Hazelnut IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 998 | s-hasspäe | u/ml | 476 | 1.05 | [0, 0.01, 0.03, 0.29, 1.1, 3.4, 6.79, 13.75, 30.06] |  | Serum |  | Hazelnut IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 999 | s-hasspäe |  | 72 | 54.17 |  |  | Serum |  | Hazelnut IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1000 | s-karba | umol/l | 3476 | 0.06 | [18.5, 22.32, 25.2, 27.69, 29.91, 32.56, 35.34, 38.81, 44.25] | S -Karbamatsepiini | Serum |  | Carbamazepine | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1001 | s-karba |  | 1101 | 59.49 | [18.42, 22.33, 25.59, 27.84, 29.91, 31.7, 34.15, 37.84, 41.83] | S -Karbamatsepiini | Serum |  | Carbamazepine | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 1002 | s-karbae | umol/l | 88 | 0 |  | S -Karbamatsepiiniepoksidi | Serum |  | Carbamazepine 10,11-epoxide | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1003 | s-karbae |  | 21 | 100 |  | S -Karbamatsepiiniepoksidi | Serum |  | Carbamazepine 10,11-epoxide | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1004 | s-kardab | titre | 1640 | 0 | [0, 1, 1.58, 2, 2.38, 4, 8.71, 19.26, 62.28] | S -Kardiolipiini, vasta-aineet | Serum |  | Cardiolipin Ab | Titer |  | Serum | SemiQn | Point in time (spot) | FALSE |
| 1005 | s-kardab |  | 14614 | 99.49 |  | S -Kardiolipiini, vasta-aineet | Serum |  | Cardiolipin Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1006 | s-kardabg | gpl | 222 | 29.28 | [6, 7, 8, 9, 11, 14.4, 18.14, 24.7, 40.7] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  | Cardiolipin IgG Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1007 | s-kardabg | u/ml | 83 | 0 | [1, 1, 2, 2, 2.25, 3, 4, 7.3, 23] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  | Cardiolipin IgG Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1008 | s-kardabg |  | 1591 | 94.97 | [1, 2, 2, 4.55, 7, 8, 9, 11, 27] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  | Cardiolipin IgG Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1009 | s-kardabm | mpl | 359 | 18.11 | [10, 11.36, 12, 13.78, 15, 17.69, 23.08, 30.86, 52.98] | S -Kardiolipiini, IgM-vasta-aineet | Serum |  | Cardiolipin IgM Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1010 | s-kardabm |  | 1672 | 96.29 |  | S -Kardiolipiini, IgM-vasta-aineet | Serum |  | Cardiolipin IgM Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1011 | s-karni | umol/l | 328 | 0 | [17.78, 24.87, 29.09, 33.28, 36.28, 39.87, 43.86, 49.4, 55.76] | S -Karnitiini | Serum |  | Carnitine | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1012 | s-karni |  | 16 | 100 |  | S -Karnitiini | Serum |  | Carnitine | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1013 | s-karni-v | umol/l | 342 | 0 | [11.86, 16.35, 19.2, 22.24, 25.07, 27.94, 30.82, 35, 41.74] | S -Karnitiini, vapaa | Serum | Free or unconjugated | Carnitine.free | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1014 | s-karni-v |  | 7 | 85.71 |  | S -Karnitiini, vapaa | Serum | Free or unconjugated | Carnitine.free | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1015 | s-koopähe | u/ml | 83 | 0 | [0.02, 0.02, 0.03, 0.04, 0.06, 0.11, 0.2, 0.31, 0.85] | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  | Coconut IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1016 | s-koopähe |  | 65 | 78.46 |  | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  | Coconut IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1017 | s-leppäe | u/ml | 196 | 0.51 | [0, 0.01, 0.01, 0.02, 0.06, 0.22, 0.9, 2.7, 6.69] | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  | Alder IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1018 | s-leppäe |  | 167 | 86.23 |  | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  | Alder IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1019 | s-maapähe | u/ml | 1974 | 0.81 | [0.01, 0.02, 0.05, 0.1, 0.19, 0.37, 0.71, 1.55, 5.76] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  | Peanut IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1020 | s-maapähe |  | 2541 | 94.14 | [0.04, 0.11, 0.15, 0.24, 0.38, 0.57, 1.12, 1.88, 3.68] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  | Peanut IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1021 | s-maksa |  | 108 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | TRUE |
| 1022 | s-maksa-1 | u/l | 115 | 0 | [31.15, 42.45, 51.29, 60.72, 65.7, 69.64, 79.3, 87.8, 100.66] |  | Serum |  |  | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1023 | s-maksa-1 |  | 6 | 16.67 |  |  | Serum |  |  | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1024 | s-maksa-2 | u/l | 110 | 0 | [3.95, 4.95, 5.9, 6.88, 7.37, 8.14, 9.54, 13.38, 18.4] |  | Serum |  |  | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1025 | s-maksa-2 |  | 12 | 8.33 |  |  | Serum |  |  | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1026 | s-maksa1 | u/l | 134 | 0 | [36.7, 43.4, 53.05, 58.95, 67.89, 79.32, 89.06, 98.11, 147.2] |  | Serum |  |  | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1027 | s-maksa1 |  | 9 | 66.67 |  |  | Serum |  |  | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 1028 | s-maksa2 | u/l | 132 | 0 | [4, 5, 6, 7.35, 9, 10.85, 14.35, 21.6, 43.05] |  | Serum |  |  | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1029 | s-maksa2 |  | 11 | 81.82 |  |  | Serum |  |  | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 1030 | s-maksaab |  | 1108 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | TRUE |
| 1031 | s-maksap |  | 147 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | TRUE |
| 1032 | s-makspak |  | 778 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | TRUE |
| 1033 | s-ohkarba | umol/l | 4080 | 0.02 | [27.1, 35.97, 41.95, 47.99, 54.61, 61.42, 68.9, 80.34, 98.86] | S -Hydroksikarbatsepiini (10-) | Serum |  | 10-Hydroxycarbazepine | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1034 | s-ohkarba |  | 797 | 53.58 | [25.02, 33.78, 40.6, 47.36, 53.64, 59.31, 68.63, 83.49, 103.17] | S -Hydroksikarbatsepiini (10-) | Serum |  | 10-Hydroxycarbazepine | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 1035 | s-okarba | umol/l | 163 | 10.43 | [0.4, 0.4, 0.8, 0.8, 0.8, 1, 1.2, 2, 2.28] | S -Okskarbatsepiini | Serum |  | Oxcarbazepine | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1036 | s-okarba |  | 168 | 92.26 |  | S -Okskarbatsepiini | Serum |  | Oxcarbazepine | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1037 | s-ovarab | titre | 22 | 9.09 |  | S -Munasarja, vasta-aineet | Serum |  | Ovary Ab | Titer |  | Serum | SemiQn | Point in time (spot) | FALSE |
| 1038 | s-ovarab |  | 250 | 99.2 |  | S -Munasarja, vasta-aineet | Serum |  | Ovary Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1039 | s-pakast5 |  | 880 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1040 | s-pakast7 |  | 106 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1041 | s-pakaste |  | 345 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1042 | s-pakkas |  | 1423 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1043 | s-pakkase |  | 262 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1044 | s-pakkask |  | 1061 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1045 | s-pakkasl |  | 919 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1046 | s-pakkasn |  | 563 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1047 | s-pakkasv |  | 357 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1048 | s-papp-a | mu/l | 533 | 0 | [227.4, 357.69, 452.41, 562.07, 709.24, 895.85, 1154.59, 1409.1, 2163.11] |  | Serum |  | Pregnancy-associated plasma protein A | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1049 | s-papp-a |  | 338 | 2.37 | [167.71, 318.34, 452.63, 572.23, 702.5, 894.09, 1122.57, 1356.65, 1789.1] |  | Serum |  | Pregnancy-associated plasma protein A | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1050 | s-pappa | form | 136 | 0 | [318.92, 443.67, 549.54, 657.05, 734.74, 894.71, 1259.38, 1647.76, 2113.41] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  | Pregnancy-associated plasma protein A | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1051 | s-pappa | mu/l | 41976 | 0 | [274.01, 424.82, 564.51, 708.65, 861.85, 1046.47, 1281.47, 1624.11, 2236.83] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  | Pregnancy-associated plasma protein A | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1052 | s-pappa |  | 357 | 100 | [254.51, 396.2, 527.37, 666.3, 821.3, 1003.01, 1225.19, 1551.35, 2139.86] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  | Pregnancy-associated plasma protein A | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 1053 | s-pappmom | mom | 461 | 0 | [0.48, 0.64, 0.76, 0.89, 1.03, 1.22, 1.42, 1.67, 2.13] |  | Serum |  | Pregnancy-associated plasma protein A | Ratio | Calculated | Serum | Qn | Point in time (spot) | FALSE |
| 1054 | s-parapäe | u/ml | 829 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.02, 0.06, 0.35] |  | Serum |  | Brazil nut IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1055 | s-parapäe |  | 34 | 61.76 |  |  | Serum |  | Brazil nut IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1056 | s-paras | umol/l | 2680 | 3.1 | [16.09, 27.95, 44.46, 65.68, 102.63, 158.13, 258.09, 473.45, 862.14] | S -Parasetamoli | Serum |  | Acetaminophen | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1057 | s-paras |  | 2490 | 99.24 |  | S -Parasetamoli | Serum |  | Acetaminophen | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1058 | s-paroab |  | 212 | 100 |  | S -Sikotautivirus, vasta-aineet | Serum |  |  |  |  | Serum |  |  | TRUE |
| 1059 | s-paroabg | au/ml | 72 | 0 | [14.1, 32.2, 47.68, 60.86, 78.93, 100.49, 117, 176, 216] | S -Sikotautivirus, IgG-vasta-aineet | Serum |  | Mumps virus IgG Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1060 | s-paroabg | titre | 45 | 0 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  | Mumps virus IgG Ab | Titer |  | Serum | SemiQn | Point in time (spot) | FALSE |
| 1061 | s-paroabg |  | 172 | 91.86 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  | Mumps virus IgG Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1062 | s-paroabm |  | 197 | 98.98 |  | S -Sikotautivirus, IgM-vasta-aineet | Serum |  | Mumps virus IgM Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1063 | s-parprot |  | 1578 | 100 |  |  | Serum |  | Paraprotein | Presence or Identity | Electrophoresis | Serum | Ord | Point in time (spot) | FALSE |
| 1064 | s-parpäh | u/ml | 67 | 0 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  | Brazil nut IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1065 | s-parpäh |  | 184 | 96.2 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  | Brazil nut IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1066 | s-parvab |  | 3096 | 100 |  | S -Parvovirus, vasta-aineet | Serum |  |  |  |  | Serum |  |  | TRUE |
| 1067 | s-parvabg | eiu | 67 | 0 | [10, 35, 50, 61, 71.88, 80.25, 90, 90, 100] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1068 | s-parvabg | ie/ml | 5 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1069 | s-parvabg | index | 250 | 0 | [10.1, 15.96, 22.67, 26.36, 30.21, 33.04, 36.98, 39.69, 42.76] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab | Ratio |  | Serum | Qn | Point in time (spot) | FALSE |
| 1070 | s-parvabg | iu/ml | 57 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1071 | s-parvabg | titre | 558 | 0 | [200, 400, 800, 800, 800, 1555.56, 1600, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab | Titer |  | Serum | SemiQn | Point in time (spot) | FALSE |
| 1072 | s-parvabg |  | 2056 | 91.73 | [4.91, 11.45, 38.67, 122.23, 400, 800, 800, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1073 | s-parvabm |  | 2965 | 99.46 |  | S -Parvovirus, IgM-vasta-aineet | Serum |  | Parvovirus B19 IgM Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1074 | s-parvavi | % | 13 | 0 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  | Parvovirus B19 IgG Ab avidity | Number Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 1075 | s-parvavi |  | 600 | 95.33 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  | Parvovirus B19 IgG Ab avidity | Finding |  | Serum | Ord | Point in time (spot) | FALSE |
| 1076 | s-pekpähe | u/ml | 31 | 0 |  |  | Serum |  | Pecan IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1077 | s-pekpähe |  | 77 | 96.1 |  |  | Serum |  | Pecan IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1078 | s-sakspäe | u/ml | 883 | 0 | [0, 0, 0, 0.01, 0.01, 0.03, 0.07, 0.21, 1.55] |  | Serum |  | Walnut IgE Ab | Arbitrary Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1079 | s-sakspäe |  | 95 | 74.74 |  |  | Serum |  | Walnut IgE Ab | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1080 | s-sappih | umol/l | 9172 | 0.36 | [2, 2.87, 3.49, 4.45, 5.83, 7.59, 10.65, 16.77, 32.84] | S -Sappihapot | Serum |  | Bile acids.total | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1081 | s-sappih |  | 1955 | 50.33 | [2, 3, 3, 4, 4.4, 5.33, 7.05, 9.69, 18.19] | S -Sappihapot | Serum |  | Bile acids.total | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 1082 | s-valpr | % | 33 | 0 |  | S -Valproaatti | Serum |  | Valproate.free/Valproate.total | Substance Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 1083 | s-valpr | umol/l | 35853 | 0.05 | [220.39, 285.23, 332.16, 372.59, 408.92, 446.56, 486.81, 533.22, 600.78] | S -Valproaatti | Serum |  | Valproate | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1084 | s-valpr |  | 1583 | 100 | [195.88, 257.11, 300.41, 340.81, 382.77, 422.91, 465.76, 516.34, 588.53] | S -Valproaatti | Serum |  | Valproate | Finding |  | Serum | Nar | Point in time (spot) | FALSE |
| 1085 | s-valpr-v | umol/l | 818 | 0 | [25.49, 29.94, 35.24, 39.88, 44.93, 50.41, 57.45, 67.85, 86.45] | S -Valproaatti, vapaa | Serum | Free or unconjugated | Valproate.free | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1086 | s-valpr-v |  | 221 | 80.54 |  | S -Valproaatti, vapaa | Serum | Free or unconjugated | Valproate.free | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1087 | s-valpro | umol/l | 171 | 0 |  |  | Serum |  | Valproate | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1088 | s-valpro |  | 5 | 100 |  |  | Serum |  | Valproate | Presence or Threshold |  | Serum | Ord | Point in time (spot) | FALSE |
| 1089 | s-vara |  | 340 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1090 | s-varah |  | 253 | 100 |  |  | Serum |  |  |  |  | Serum |  |  | FALSE |
| 1091 | sappihapot | umol/l | 161 | 0 |  |  |  |  | Bile acids.total | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1092 | sappihapot |  | 14 | 100 |  |  |  |  | Bile acids.total | Presence or Threshold |  |  | Ord | Point in time (spot) | FALSE |
| 1093 | sk-padihot |  | 24730 | 100 |  | Sk-Ihottumanäytteen histologinen tutkimus | Skin |  | Histology | Finding | Histology | Skin | Nar | Point in time (spot) | FALSE |
| 1094 | tupakka | u/24h | 599 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 8.55] |  |  |  | Cotinine | Arbitrary Rate |  | Urine | Qn | 24 hours | FALSE |
| 1095 | tupakka |  | 104 | 100 |  |  |  |  | Cotinine | Presence or Threshold |  | Urine | Ord | 24 hours | FALSE |
| 1096 | u-gluprot |  | 2097 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | TRUE |
| 1097 | u-partik |  | 14759 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | TRUE |
| 1098 | u-partikk |  | 5466 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | TRUE |
| 1099 | u-rakkoai | h | 373 | 0 | [2.84, 4, 4, 4.03, 5, 6, 6.66, 7.87, 8.33] |  | Urine |  | Time | Time |  | ^Patient | Qn | Procedure duration | FALSE |
| 1100 | u-rakkoai |  | 5 | 100 |  |  | Urine |  | Time | Finding |  | ^Patient | Nar | Procedure duration | FALSE |
| 1101 | u-sakka |  | 2736 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | TRUE |
| 1102 | u-valvott |  | 1125 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |
| 1103 | u-varabak |  | 206 | 100 |  |  | Urine |  |  |  |  | Urine |  |  | FALSE |

