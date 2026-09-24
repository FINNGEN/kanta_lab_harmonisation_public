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
Here is group 162.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| 25-Hydroxyvitamin D | 25-hydroxyvitamin D3 | 0.939 | 0 | 0 |
| 25-Hydroxyvitamin D | 25-hydroxyvitamin D2 | 0.866 | 2 | 575 |
| 25-Hydroxyvitamin D | 1,25-Dihydroxyvitamin D | 0.787 | 0 | 0 |
| 25-Hydroxyvitamin D | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 | 0.756 | 28 | 509,831 |
| 25-Hydroxyvitamin D2+D3 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 | 0.914 | 28 | 509,831 |
| 25-Hydroxyvitamin D2+D3 | 25-hydroxyvitamin D2 | 0.874 | 2 | 575 |
| 25-Hydroxyvitamin D2+D3 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2/24,25-dihydroxyvitamin D3+24,25-dihydroxyvitamin D2 | 0.849 | 0 | 0 |
| 25-Hydroxyvitamin D2+D3 | 25-hydroxyvitamin D3 | 0.832 | 0 | 0 |
| 25-Hydroxyvitamin D2+D3 | 24,25-dihydroxyvitamin D3+24,25-dihydroxyvitamin D2 | 0.819 | 0 | 0 |
| Air conduction hearing vs Bone conduction hearing | (none scored >= 0.75) |  |  |  |
| Alkaline phosphatase | Alkaline phosphatase | 1.000 | 13 | 2,756,532 |
| Alkaline phosphatase | Alkaline phosphatase isoenzyme | 0.864 | 0 | 0 |
| Alkaline phosphatase | Alkaline phosphatase.bone | 0.829 | 13 | 5,731 |
| Alkaline phosphatase | Alkaline phosphatase isoenzymes | 0.817 | 2 | 9,116 |
| Alkaline phosphatase | Alkaline phosphatase.liver | 0.815 | 3 | 3,451 |
| Angiotensin converting enzyme | Angiotensin converting enzyme | 1.000 | 11 | 43,074 |
| Basophils/100 leukocytes | Basophils/100 leukocytes | 1.000 | 0 | 0 |
| Basophils/100 leukocytes | Basophils/100 cells | 0.934 | 0 | 0 |
| Basophils/100 leukocytes | Basophils+Mast cells/100 leukocytes | 0.868 | 0 | 0 |
| Basophils/100 leukocytes | Basophils.band form/100 leukocytes | 0.854 | 0 | 0 |
| Basophils/100 leukocytes | Basophils.immature/100 leukocytes | 0.811 | 0 | 0 |
| Bicarbonate | Bicarbonate | 1.000 | 60 | 580,127 |
| Bicarbonate.standard | Bicarbonate^^standard | 0.911 | 27 | 462,530 |
| Bicarbonate.standard | Bicarbonate | 0.788 | 60 | 580,127 |
| Bilirubin.direct | Bilirubin | 0.756 | 19 | 1,512,475 |
| CD4/CD8 | CD4-CD8- | 0.870 | 0 | 0 |
| CD4/CD8 | CD4+CD8+ | 0.816 | 0 | 0 |
| CD4/CD8 | CD4/CD8 ratio | 0.792 | 0 | 0 |
| CD4/CD8 | Cells.CD4/Cells.CD8 | 0.769 | 0 | 0 |
| CD4/CD8 | CD4+CD8+ cells | 0.759 | 0 | 0 |
| Cells | Cells | 1.000 | 1 | 1,262 |
| Creatine kinase | Creatine kinase | 1.000 | 12 | 297,958 |
| Creatine kinase | Creatine kinase.BB | 0.843 | 3 | 313 |
| Creatine kinase | Creatine kinase.MiMi | 0.822 | 0 | 0 |
| Creatine kinase | Creatine kinase.MM | 0.821 | 3 | 217 |
| Creatine kinase | Creatine kinase isoenzymes | 0.820 | 1 | 324 |
| EKG study | EKG study | 1.000 | 10 | 506,024 |
| EKG study | EEG study | 0.785 | 0 | 0 |
| EKG study | Cardiac stress EKG study | 0.767 | 0 | 0 |
| Eosinophils/100 leukocytes | Eosinophils/100 leukocytes | 1.000 | 0 | 0 |
| Eosinophils/100 leukocytes | Eosinophils/100 cells | 0.904 | 0 | 0 |
| Eosinophils/100 leukocytes | Eosinophils.immature/100 leukocytes | 0.818 | 0 | 0 |
| Eosinophils/100 leukocytes | Neutrophils/100 leukocytes | 0.809 | 0 | 0 |
| Eosinophils/100 leukocytes | Eosinophils.band form/100 cells | 0.803 | 0 | 0 |
| Erythroblasts | Erythroblasts early | 0.848 | 0 | 0 |
| Erythroblasts | Erythroblasts mid | 0.837 | 0 | 0 |
| Erythroblasts | Erythroid cells | 0.831 | 0 | 0 |
| Erythroblasts | Erythroblasts late | 0.815 | 0 | 0 |
| Erythroblasts | Erythrocytes | 0.764 | 64 | 12,187,960 |
| Erythrocyte distribution width | Erythrocyte distribution width | 1.000 | 0 | 0 |
| Erythrocyte distribution width | Reticulocyte distribution width | 0.874 | 0 | 0 |
| Erythrocyte distribution width | Hemoglobin distribution width | 0.816 | 0 | 0 |
| Erythrocyte distribution width | Platelet distribution width | 0.801 | 0 | 0 |
| Erythrocyte distribution width | Reticulocyte hemoglobin distribution width | 0.784 | 0 | 0 |
| Folate | Folate | 1.000 | 22 | 338,797 |
| Fungus | Fungus | 1.000 | 4 | 80,804 |
| Glycoprotein acetylation | (none scored >= 0.75) |  |  |  |
| Inhalation therapy | (none scored >= 0.75) |  |  |  |
| Kt/V | (none scored >= 0.75) |  |  |  |
| Lactate dehydrogenase | Lactate dehydrogenase | 1.000 | 12 | 238,282 |
| Lactate dehydrogenase | Lactate dehydrogenase 3 | 0.839 | 0 | 0 |
| Lactate dehydrogenase | Lactate dehydrogenase 1 | 0.835 | 0 | 0 |
| Lactate dehydrogenase | Lactate dehydrogenase 2 | 0.826 | 0 | 0 |
| Lactate dehydrogenase | Lactate dehydrogenase 4 | 0.824 | 0 | 0 |
| Lupus anticoagulant | Lupus anticoagulant | 1.000 | 2 | 12,621 |
| Lupus anticoagulant | Lupus anticoagulant neutralization platelet | 0.795 | 0 | 0 |
| Lupus anticoagulant | Lupus anticoagulant neutralization dilute phospholipid | 0.785 | 0 | 0 |
| Lupus anticoagulant | Lupus anticoagulant aPTT screening panel | 0.784 | 0 | 0 |
| Lupus anticoagulant | Lupus anticoagulant neutralization high phospholipid | 0.767 | 0 | 0 |
| Lymphocytes/100 leukocytes | Lymphocytes/100 leukocytes | 1.000 | 0 | 0 |
| Lymphocytes/100 leukocytes | Lymphocytes/100 cells | 0.930 | 0 | 0 |
| Lymphocytes/100 leukocytes | Lymphoblasts/100 leukocytes | 0.877 | 0 | 0 |
| Lymphocytes/100 leukocytes | Lymphoma cells/100 leukocytes | 0.851 | 0 | 0 |
| Lymphocytes/100 leukocytes | Prolymphocytes/100 leukocytes | 0.837 | 0 | 0 |
| Monocytes/100 leukocytes | Monocytes/100 leukocytes | 1.000 | 0 | 0 |
| Monocytes/100 leukocytes | Monocytes/100 cells | 0.945 | 0 | 0 |
| Monocytes/100 leukocytes | Monocytes+Macrophages/100 leukocytes | 0.916 | 0 | 0 |
| Monocytes/100 leukocytes | Monocyte+Macrophage/100 leukocytes | 0.866 | 0 | 0 |
| Monocytes/100 leukocytes | Monocytoid cells/100 leukocytes | 0.844 | 0 | 0 |
| Neuron specific enolase | Enolase.neuron specific | 0.795 | 3 | 10,290 |
| Neuron specific enolase | Enolase.neuron specific Ag | 0.794 | 0 | 0 |
| Neutrophils/100 leukocytes | Neutrophils/100 leukocytes | 1.000 | 0 | 0 |
| Neutrophils/100 leukocytes | Neutrophils/100 cells | 0.899 | 0 | 0 |
| Neutrophils/100 leukocytes | Granulocytes/100 leukocytes | 0.870 | 0 | 0 |
| Neutrophils/100 leukocytes | Polymorphonuclear cells/100 leukocytes | 0.863 | 0 | 0 |
| Neutrophils/100 leukocytes | Neutrophils/100 round cells | 0.857 | 0 | 0 |
| Oxidative stress | (none scored >= 0.75) |  |  |  |
| Parathyrin.intact | Parathyrin.intact | 1.000 | 4 | 167,377 |
| Parathyrin.intact | Parathyrin.intact^baseline | 0.893 | 0 | 0 |
| Parathyrin.intact | Parathyrin.intact^post excision | 0.884 | 0 | 0 |
| Parathyrin.intact | Parathyrin.intact^3rd specimen | 0.870 | 0 | 0 |
| Parathyrin.intact | Parathyrin.intact^1st specimen | 0.867 | 0 | 0 |
| Phosphate | Phosphate | 1.000 | 14 | 378,156 |
| Phosphate | Phosphorus | 0.823 | 0 | 0 |
| Prostate specific Ag.free/Prostate specific Ag.total | Prostate specific Ag.free/Prostate specific Ag.total | 1.000 | 47 | 441,698 |
| Prostate specific Ag.free/Prostate specific Ag.total | Prostate Specific Ag Free | 0.785 | 17 | 236,561 |
| Prostate specific Ag.free/Prostate specific Ag.total | Prostate specific Ag.protein bound | 0.760 | 0 | 0 |
| Prostate specific Ag.free/Prostate specific Ag.total | Prostate Specific Ag | 0.755 | 0 | 0 |
| Renin | Renin | 1.000 | 21 | 10,814 |
| Renin | Renin^supine | 0.797 | 3 | 99 |
| Renin | Renin^upright | 0.791 | 3 | 1,125 |
| Renin | Renin^baseline | 0.784 | 0 | 0 |
| SARS-CoV-2 Ag | SARS-CoV-2 Ag | 1.000 | 0 | 0 |
| SARS-CoV-2 Ag | SARS-CoV-2 (COVID-19) Ag | 0.930 | 4 | 48,202 |
| SARS-CoV-2 Ag | SARS-CoV+SARS-CoV-2 (COVID-19) Ag | 0.873 | 0 | 0 |
| SARS-CoV-2 Ag | Influenza virus A & Influenza virus B & SARS coronavirus 2 Ag | 0.759 | 0 | 0 |
| Specialist consultation | (none scored >= 0.75) |  |  |  |
| Temperature | Temperature | 1.000 | 0 | 0 |
| Thymidine kinase | Thymidine kinase | 1.000 | 3 | 2,079 |
| Urea recirculation | (none scored >= 0.75) |  |  |  |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Arbitrary Concentration | Arbitrary Concentration | 1.000 | 998 | 4,231,921 |
| Arbitrary Concentration | Relative Arbitrary Concentration | 0.841 | 3 | 1,539 |
| Catalytic Concentration | Catalytic Concentration | 1.000 | 228 | 10,802,985 |
| Catalytic Concentration | Relative catalytic concentration | 0.848 | 9 | 39,650 |
| Mass Concentration | Mass Concentration | 1.000 | 1,215 | 26,086,908 |
| Mass Concentration | Mass concentration difference | 0.839 | 0 | 0 |
| Mass Concentration | Mass Concentration Squared | 0.776 | 0 | 0 |
| Mass Concentration | Mass or Substance Concentration | 0.774 | 0 | 0 |
| Mass Fraction | Mass fraction | 1.000 | 229 | 4,683,692 |
| Number Concentration | Number Concentration | 1.000 | 507 | 49,434,956 |
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
| Temperature | Temperature | 1.000 | 9 | 93,063 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Automated count | Automated count | 1.000 | 103 | 11,606,924 |
| Calculated | Calculated | 1.000 | 89 | 12,276,393 |
| Coagulation assay | Coagulation assay | 1.000 | 181 | 3,646,966 |
| Test strip | Test strip | 1.000 | 79 | 4,294,769 |
| Test strip | Test strip manual | 0.843 | 0 | 0 |
| Test strip | Test strip automated | 0.836 | 3 | 687,408 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| ^Patient | ^Patient | 1.000 | 20 | 396,517 |
| Blood | Blood | 1.000 | 1,135 | 91,968,350 |
| Blood arterial | Blood arterial | 1.000 | 102 | 4,209,123 |
| Blood arterial | Blood arterial + Blood venous | 0.791 | 0 | 0 |
| Blood arterial | Plasma arterial | 0.777 | 0 | 0 |
| Blood arterial | Blood cord arterial | 0.761 | 20 | 2,773 |
| Blood capillary | Blood capillary | 1.000 | 121 | 787,125 |
| Blood capillary | Blood capillary^Fetus | 0.763 | 0 | 0 |
| Blood venous | Blood venous | 1.000 | 125 | 1,808,160 |
| Blood venous | Venous | 0.798 | 0 | 0 |
| Blood venous | Blood cord venous | 0.772 | 4 | 294 |
| Blood venous | Plasma venous | 0.752 | 0 | 0 |
| Blood venous | Blood central venous | 0.750 | 1 | 38,175 |
| Plasma | Plasma | 1.000 | 41 | 58,727 |
| Plasma | Plasma or Blood | 0.752 | 0 | 0 |
| Platelet poor plasma | Platelet poor plasma | 1.000 | 180 | 1,076,490 |
| Platelet poor plasma | Platelet poor plasma or blood | 0.848 | 0 | 0 |
| Platelet poor plasma | Platelet poor plasma^Control | 0.818 | 0 | 0 |
| Platelet poor plasma | Platelet poor plasma^Fetus | 0.772 | 0 | 0 |
| Red Blood Cells | Red Blood Cells | 1.000 | 100 | 38,219,166 |
| Serum | Serum | 1.000 | 995 | 2,593,077 |
| Urine | Urine | 1.000 | 586 | 16,080,701 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1841 | -cd4-solujensuhdecd8-soluihin |  | 667 | 0.3 | [0.26, 0.37, 0.55, 0.73, 1, 1.35, 1.81, 2.32, 3.03] |  |  |  | CD4/CD8 | Ratio |  | Blood | Qn | Point in time (spot) | FALSE |
| 1842 | -kt/v,daugirdaksenkaava |  | 176 | 0 | [1.13, 1.23, 1.29, 1.33, 1.39, 1.43, 1.46, 1.5, 1.57] |  |  |  | Kt/V | Ratio | Calculated | ^Patient | Qn | Point in time (spot) | FALSE |
| 1843 | -sieni,natiivivalmiste |  | 244 | 100 |  |  |  |  | Fungus | Presence or Identity |  |  | Nar | Point in time (spot) | FALSE |
| 1844 | ab-aktuaalibikarbonaatti | mmol/l | 14354 | 0 | [18.76, 21.02, 22.57, 23.76, 24.73, 25.7, 26.99, 28.55, 31.59] |  | Arterial blood |  | Bicarbonate | Substance Concentration |  | Blood arterial | Qn | Point in time (spot) | FALSE |
| 1845 | ab-aktuaalibikarbonaatti |  | 47 | 100 |  |  | Arterial blood |  | Bicarbonate |  |  | Blood arterial |  |  | FALSE |
| 1846 | ab-lämpötila(he-tase) | aste | 418 | 0 | [36.38, 36.95, 37, 37, 37, 37, 37.01, 37.48, 38.01] |  | Arterial blood |  | Temperature | Temperature |  | Blood arterial | Qn | Point in time (spot) | FALSE |
| 1847 | ab-standardibikarbonaatti | mmol/l | 4434 | 0 | [19.73, 21.71, 22.89, 23.76, 24.46, 25.22, 26.01, 27.04, 28.87] |  | Arterial blood |  | Bicarbonate.standard | Substance Concentration | Calculated | Blood arterial | Qn | Point in time (spot) | FALSE |
| 1848 | ab-standardibikarbonaatti |  | 20 | 100 |  |  | Arterial blood |  | Bicarbonate.standard |  |  | Blood arterial |  |  | FALSE |
| 1849 | alkalinenfosfataasi | u/l | 4090 | 0 | [51.93, 59.73, 66.52, 72.54, 78.85, 86.09, 95.45, 111.37, 142.22] |  |  |  | Alkaline phosphatase | Catalytic Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1850 | alkalinenfosfataasi |  | 409 | 100 |  |  |  |  | Alkaline phosphatase |  |  |  |  |  | FALSE |
| 1851 | angiotensiini-1-konvertaasi | u/l | 286 | 0 | [21.5, 28.51, 36.37, 41.21, 48.76, 54.44, 63.62, 70.94, 80.3] |  |  |  | Angiotensin converting enzyme | Catalytic Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1852 | angiotensiini-1-konvertaasi |  | 20 | 100 |  |  |  |  | Angiotensin converting enzyme |  |  |  |  |  | FALSE |
| 1853 | b-diffi,erittelylaskenta,klooni |  | 142 | 100 |  |  | Blood |  |  |  |  |  |  |  | TRUE |
| 1854 | cb-standardibikarbonaatti | mmol/l | 10798 | 0 | [20.28, 22.23, 23.36, 24.16, 24.9, 25.66, 26.58, 27.89, 30.19] |  | Capillary blood |  | Bicarbonate.standard | Substance Concentration | Calculated | Blood capillary | Qn | Point in time (spot) | FALSE |
| 1855 | cb-standardibikarbonaatti |  | 90 | 50 |  |  | Capillary blood |  | Bicarbonate.standard | Substance Concentration | Calculated | Blood capillary | Qn | Point in time (spot) | FALSE |
| 1856 | d-vitamiini-25-oh,d3-jad2-muodot | nmol/l | 219 | 0 | [48.54, 55.58, 61.96, 68.73, 74.1, 79.27, 84.22, 89.91, 106.45] |  |  |  | 25-Hydroxyvitamin D2+D3 | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1857 | d-vitamiini-25-oh,plasmasta | nmol/l | 694 | 0 | [44.59, 53.15, 59, 64.66, 69.89, 76.01, 82.54, 92.02, 105.7] |  |  |  | 25-Hydroxyvitamin D | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1858 | e-punasolujenkokojakaum | % | 55570 | 0 | [12.19, 12.59, 12.95, 13.26, 13.67, 14.09, 14.51, 14.98, 15.71] |  | Erythrocyte |  | Erythrocyte distribution width | Ratio |  | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 1859 | e-punasolujenkokojakaum |  | 7 | 71.43 |  |  | Erythrocyte |  | Erythrocyte distribution width |  |  | Red Blood Cells |  |  | FALSE |
| 1860 | e-punasolujenkokojakauma | % | 196935 | 0 | [12, 13, 13, 13, 13.69, 14, 14.05, 15, 16.37] |  | Erythrocyte |  | Erythrocyte distribution width | Ratio |  | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 1861 | e-punasolujenkokojakauma |  | 1688 | 46.92 | [15, 15, 15.98, 16, 16, 16.41, 17, 18, 19.59] |  | Erythrocyte |  | Erythrocyte distribution width | Ratio |  | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 1862 | e-rdw,punasolujenkokojakauma | % | 25929 | 0 | [12.08, 13, 13, 13.03, 14, 14, 15, 15.7, 17.03] |  | Erythrocyte |  | Erythrocyte distribution width | Ratio |  | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 1863 | e-rdw,punasolujenkokojakauma |  | 76 | 100 |  |  | Erythrocyte |  | Erythrocyte distribution width |  |  | Red Blood Cells |  |  | FALSE |
| 1864 | ekg,hoitoyksikönottama |  | 213 | 100 |  |  |  |  | EKG study |  |  | ^Patient | Doc |  | FALSE |
| 1865 | ekgasiakkaanottama |  | 257 | 100 |  |  |  |  | EKG study |  |  | ^Patient | Doc |  | FALSE |
| 1866 | erikoislääkärinkonsultaatio |  | 118 | 100 |  |  |  |  | Specialist consultation |  |  | ^Patient | Nar |  | FALSE |
| 1867 | folaatti(fe-folaat) | nmol/l | 320 | 0 | [1456.69, 1642.98, 1740.68, 1864.47, 2021, 2152.9, 2311.39, 2519.36, 2775.52] |  |  |  | Folate | Substance Concentration |  | Red Blood Cells | Qn | Point in time (spot) | FALSE |
| 1868 | folaatti(fe-folaat) |  | 12 | 100 |  |  |  |  | Folate |  |  | Red Blood Cells |  |  | FALSE |
| 1869 | fosfaatti,epäorgaaninen | mmol/l | 275 | 0 | [0.83, 0.93, 0.99, 1.05, 1.1, 1.15, 1.23, 1.36, 1.64] |  |  |  | Phosphate | Substance Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1870 | fosfaatti,epäorgaaninen |  | 13 | 100 |  |  |  |  | Phosphate |  |  |  |  |  | FALSE |
| 1871 | fp-fosfaatti,epäorgaaninen | mmol/l | 1537 | 0 | [0.81, 0.94, 1.04, 1.12, 1.21, 1.31, 1.45, 1.64, 2] |  | Fasting plasma |  | Phosphate | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1872 | fp-fosfaatti,epäorgaaninen |  | 7 | 100 |  |  | Fasting plasma |  | Phosphate |  |  | Plasma |  |  | FALSE |
| 1873 | fp-parathormoni(intakti) | ng/l | 167 | 0 | [34.58, 43.28, 53.6, 64.34, 75.77, 88.59, 106.04, 128.88, 166.07] |  | Fasting plasma |  | Parathyrin.intact | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1874 | fp-parathormoni,intakti | ng/l | 443 | 0 | [42.85, 55.73, 66.85, 78.78, 88.68, 102.07, 115.78, 136.81, 193.49] |  | Fasting plasma |  | Parathyrin.intact | Mass Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1875 | fp-parathormoni,intakti | pmol/l | 213 | 0 | [5.11, 7.29, 9.06, 12.26, 16.48, 21.96, 29.55, 41.46, 57.9] |  | Fasting plasma |  | Parathyrin.intact | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1876 | fp-parathormoni,intakti |  | 5 | 60 |  |  | Fasting plasma |  | Parathyrin.intact |  |  | Plasma |  |  | FALSE |
| 1877 | fp-reniini,konsentraatio | mu/l | 275 | 0 | [1.9, 3.7, 5.72, 9.15, 13.8, 21.38, 36.23, 69.29, 149] |  | Fasting plasma |  | Renin | Arbitrary Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1878 | fp-reniini,konsentraatio |  | 9 | 100 |  |  | Fasting plasma |  | Renin |  |  | Plasma |  |  | FALSE |
| 1879 | fras,oksidatiivinenstressi |  | 508 | 100 |  |  |  |  | Oxidative stress |  |  |  | Nar |  | FALSE |
| 1880 | fs-alkalinenfosfataasi | u/l | 114 | 0 |  |  | Fasting serum |  | Alkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1881 | fs-angiotensiini-1-konvertaasi | u/l | 168 | 0 | [21.95, 28.78, 36.13, 43.17, 50.38, 57.02, 63.03, 69.31, 88.3] |  | Fasting serum |  | Angiotensin converting enzyme | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1882 | fs-angiotensiini-1-konvertaasi |  | 17 | 100 |  |  | Fasting serum |  | Angiotensin converting enzyme |  |  | Serum |  |  | FALSE |
| 1883 | fs-monikanava4-7tthperuspaketti |  | 125 | 100 |  |  | Fasting serum |  |  |  |  |  |  |  | TRUE |
| 1884 | fs-työterveyshuollonperuspaketti |  | 141 | 100 |  |  | Fasting serum |  |  |  |  |  |  |  | TRUE |
| 1885 | ilmajohtotarv.luujohto |  | 785 | 100 |  |  |  |  | Air conduction hearing vs Bone conduction hearing |  |  | ^Patient | Nar |  | FALSE |
| 1886 | korona-rs-influenssa,pcrpikatesti |  | 6428 | 100 |  |  |  |  |  |  |  |  |  |  | TRUE |
| 1887 | kreatiinikinaasi | u/l | 821 | 0 | [51.45, 67.28, 78.98, 91.33, 108.19, 125.74, 161.13, 224.43, 350.78] |  |  |  | Creatine kinase | Catalytic Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1888 | l-basofiilit,automaatio | % | 10670 | 0 | [0, 0, 0.5, 1, 1, 1, 1, 1, 1] |  | Leukocyte |  | Basophils/100 leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1889 | l-eosinofiilit,automaatio | % | 10670 | 0 | [0.35, 1, 1.93, 2, 2.74, 3, 3.97, 4.81, 6.33] |  | Leukocyte |  | Eosinophils/100 leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1890 | l-lymfosyytit,automaatio | % | 19279 | 0 | [15.56, 20.42, 24.04, 26.95, 29.66, 32.37, 35.21, 38.75, 43.79] |  | Leukocyte |  | Lymphocytes/100 leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1891 | l-lymfosyytit,automaatio |  | 23 | 100 |  |  | Leukocyte |  | Lymphocytes/100 leukocytes |  | Automated count | Blood |  |  | FALSE |
| 1892 | l-monosyytit,automaatio | % | 19276 | 0 | [5.94, 6.98, 7.19, 8, 8.78, 9.04, 10, 11, 12.64] |  | Leukocyte |  | Monocytes/100 leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1893 | l-monosyytit,automaatio |  | 23 | 100 |  |  | Leukocyte |  | Monocytes/100 leukocytes |  | Automated count | Blood |  |  | FALSE |
| 1894 | l-neutrofiilit,automaatio | % | 19277 | 0 | [41.43, 47.16, 50.99, 54.23, 57.08, 59.98, 63.15, 67.08, 72.76] |  | Leukocyte |  | Neutrophils/100 leukocytes | Number Fraction | Automated count | Blood | Qn | Point in time (spot) | FALSE |
| 1895 | l-neutrofiilit,automaatio |  | 23 | 100 |  |  | Leukocyte |  | Neutrophils/100 leukocytes |  | Automated count | Blood |  |  | FALSE |
| 1896 | laktaattidehydrogenaasi | u/l | 112 | 0 | [166.9, 176.25, 189.57, 200, 217.89, 228.73, 246.21, 285.8, 336.3] |  |  |  | Lactate dehydrogenase | Catalytic Concentration |  |  | Qn | Point in time (spot) | FALSE |
| 1897 | p-aktuaalinenbikarbonaatti | mmol/l | 1258 | 0 | [20.16, 23.03, 24.56, 25.84, 26.91, 27.87, 28.97, 30.03, 32.38] |  | Plasma |  | Bicarbonate | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1898 | p-alkaalinenfosfataasi | u/l | 218 | 0 | [54.87, 64.51, 69.29, 74.44, 80.78, 89.02, 97.67, 107.93, 128.13] |  | Plasma |  | Alkaline phosphatase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1899 | p-alkaalinenfosfataasi |  | 6 | 16.67 |  |  | Plasma |  | Alkaline phosphatase |  |  | Plasma |  |  | FALSE |
| 1900 | p-alkalinenfosfataasi | u/l | 26335 | 0 | [51.5, 59.65, 66.46, 73.03, 79.94, 87.78, 97.91, 113.11, 149.16] |  | Plasma |  | Alkaline phosphatase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1901 | p-alkalinenfosfataasi |  | 74 | 91.89 |  |  | Plasma |  | Alkaline phosphatase |  |  | Plasma |  |  | FALSE |
| 1902 | p-bilirubiinikonjugaatit | umol/l | 1839 | 0 | [2.92, 3, 3.32, 4, 4.89, 5.93, 7.57, 10.11, 21.15] |  | Plasma |  | Bilirubin.direct | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1903 | p-bilirubiinikonjugaatit |  | 168 | 100 |  |  | Plasma |  | Bilirubin.direct |  |  | Plasma |  |  | FALSE |
| 1904 | p-fosfaatti,epäorgaaninen | mmol/l | 436 | 0 | [0.89, 0.99, 1.06, 1.13, 1.2, 1.27, 1.36, 1.47, 1.66] |  | Plasma |  | Phosphate | Substance Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1905 | p-kreatiinikinaasi | u/l | 2765 | 0 | [43.61, 57.48, 70.52, 85.33, 100.93, 124.44, 165.61, 239.04, 491.32] |  | Plasma |  | Creatine kinase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1906 | p-kreatiinikinaasi |  | 21 | 95.24 |  |  | Plasma |  | Creatine kinase |  |  | Plasma |  |  | FALSE |
| 1907 | p-laktaattidehydrogenaasi | u/l | 3272 | 0 | [163.71, 178.57, 190.98, 203.43, 216.38, 231.67, 254.03, 288.21, 372.84] |  | Plasma |  | Lactate dehydrogenase | Catalytic Concentration |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1908 | p-laktaattidehydrogenaasi |  | 29 | 96.55 |  |  | Plasma |  | Lactate dehydrogenase |  |  | Plasma |  |  | FALSE |
| 1909 | p-lupusantikoagulantti |  | 220 | 100 |  |  | Plasma |  | Lupus anticoagulant | Presence or Threshold | Coagulation assay | Platelet poor plasma | Ord | Point in time (spot) | FALSE |
| 1910 | p-psavapaanosuustotaalista | % | 719 | 0 | [10.55, 13.9, 16.1, 18.77, 21.1, 23.88, 26.7, 30.17, 36.09] |  | Plasma |  | Prostate specific Ag.free/Prostate specific Ag.total | Mass Fraction |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1911 | p-urea,resirkulaatio | mmol/l | 200 | 0 | [4.65, 12.03, 14.2, 15.66, 16.84, 18.43, 19.52, 21.22, 23.14] |  | Plasma |  | Urea recirculation | Ratio |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1912 | psa-vapaa/totaali-suhde,plasmasta | % | 1183 | 0 | [8.11, 11.04, 13.43, 15.83, 18.18, 20.89, 24.81, 29.88, 39.78] |  |  |  | Prostate specific Ag.free/Prostate specific Ag.total | Mass Fraction |  | Plasma | Qn | Point in time (spot) | FALSE |
| 1913 | psa-vapaa/totaali-suhde,plasmasta |  | 3428 | 100 |  |  |  |  | Prostate specific Ag.free/Prostate specific Ag.total |  |  | Plasma |  |  | FALSE |
| 1914 | psavapaanjatotaalinsuhde | % | 62 | 0 |  |  |  |  | Prostate specific Ag.free/Prostate specific Ag.total | Mass Fraction |  |  | Qn | Point in time (spot) | FALSE |
| 1915 | psavapaanjatotaalinsuhde |  | 180 | 97.78 |  |  |  |  | Prostate specific Ag.free/Prostate specific Ag.total |  |  |  |  |  | FALSE |
| 1916 | pt-vaativainhalaatiohoito |  | 114 | 100 |  |  | Patient |  | Inhalation therapy |  |  | ^Patient | Nar |  | FALSE |
| 1917 | punasolojenkokojakauma | % | 1068 | 0 | [12, 12.05, 13, 13, 13, 13, 13.97, 14, 14.47] |  |  |  | Erythrocyte distribution width | Ratio |  |  | Qn | Point in time (spot) | FALSE |
| 1918 | punasolojenkokojakauma |  | 7 | 100 |  |  |  |  | Erythrocyte distribution width |  |  |  |  |  | FALSE |
| 1919 | punasolujenerittelylaskenta | % | 41 | 0 |  |  |  |  |  |  |  |  |  |  | TRUE |
| 1920 | punasolujenerittelylaskenta |  | 433 | 6 | [12, 12, 12.18, 13, 13, 13, 13, 13.97, 14] |  |  |  |  |  |  |  |  |  | TRUE |
| 1921 | punasolujenesiasteet(erytroblastit) | e9/l | 1040 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  | Erythroblasts | Number Concentration |  | Blood | Qn | Point in time (spot) | FALSE |
| 1922 | punasolujenesiasteet(erytroblastit) |  | 24 | 100 |  |  |  |  | Erythroblasts |  |  | Blood |  |  | FALSE |
| 1923 | punasolujenkokojakauma | % | 155883 | 0 | [12.28, 13, 13, 13.02, 14, 14, 15, 15.9, 17] |  |  |  | Erythrocyte distribution width | Ratio |  |  | Qn | Point in time (spot) | FALSE |
| 1924 | punasolujenkokojakauma |  | 2478 | 99.48 |  |  |  |  | Erythrocyte distribution width |  |  |  |  |  | FALSE |
| 1925 | punasolujenkokojakautuma | % | 683 | 0 | [13, 13, 13, 13, 13, 14, 14, 14, 14.95] |  |  |  | Erythrocyte distribution width | Ratio |  |  | Qn | Point in time (spot) | FALSE |
| 1926 | punasolujenkoonvaihtelu | % | 2031 | 0 | [12.51, 12.91, 13.17, 13.34, 13.62, 13.91, 14.31, 14.86, 15.92] |  |  |  | Erythrocyte distribution width | Ratio |  |  | Qn | Point in time (spot) | FALSE |
| 1927 | punasolut,kokojakauma | % | 121 | 0 | [13, 13, 13, 13, 14, 14, 14, 14, 15] |  |  |  | Erythrocyte distribution width | Ratio |  |  | Qn | Point in time (spot) | FALSE |
| 1928 | s-alkalinenfosfataasi | u/l | 368 | 0 | [52.79, 63.98, 76.35, 87.37, 103.68, 118.86, 131.06, 146.22, 181.47] |  | Serum |  | Alkaline phosphatase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1929 | s-alkalinenfosfataasi,isoentsyymit |  | 318 | 100 |  |  | Serum |  |  |  |  |  |  |  | TRUE |
| 1930 | s-glykoproteiininasetylaatio | mmol/l | 265 | 0 | [0.75, 0.79, 0.81, 0.83, 0.85, 0.88, 0.9, 0.94, 1] |  | Serum |  | Glycoprotein acetylation | Substance Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1931 | s-neuronispesifinenenolaasi | ug/l | 105 | 0 |  |  | Serum |  | Neuron specific enolase | Mass Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1932 | s-nightingale-mittaus |  | 265 | 100 |  |  | Serum |  |  |  |  |  |  |  | TRUE |
| 1933 | s-psavapaanjatotaalinsuhde | % | 106 | 0 | [11, 13, 14.4, 16.35, 19, 21, 23.87, 27, 31.9] |  | Serum |  | Prostate specific Ag.free/Prostate specific Ag.total | Mass Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 1934 | s-psavapaanjatotaalinsuhde |  | 264 | 100 |  |  | Serum |  | Prostate specific Ag.free/Prostate specific Ag.total |  |  | Serum |  |  | FALSE |
| 1935 | s-tymidiinikinaasi | u/l | 237 | 0 | [3.92, 4.79, 5.63, 6.48, 7.24, 8.95, 10.78, 13.93, 39.38] |  | Serum |  | Thymidine kinase | Catalytic Concentration |  | Serum | Qn | Point in time (spot) | FALSE |
| 1936 | s-vapaanjakokonais-psa:nsuhde | % | 643 | 0 | [11.89, 14.35, 17.11, 19.53, 21.76, 24, 27.79, 31.6, 36.6] |  | Serum |  | Prostate specific Ag.free/Prostate specific Ag.total | Mass Fraction |  | Serum | Qn | Point in time (spot) | FALSE |
| 1937 | s-vapaanjakokonais-psa:nsuhde |  | 1561 | 100 |  |  | Serum |  | Prostate specific Ag.free/Prostate specific Ag.total |  |  | Serum |  |  | FALSE |
| 1938 | sars-cov-2,influenssaa,bja |  | 161 | 100 |  |  |  |  |  |  |  |  |  |  | TRUE |
| 1939 | sars-cov-2-antigeenitesti,pikatesti |  | 101 | 100 |  |  |  |  | SARS-CoV-2 Ag | Presence or Threshold | Test strip |  | Ord | Point in time (spot) | FALSE |
| 1940 | tth-pakettia(ilmanpaastoa) |  | 1079 | 100 |  |  |  |  |  |  |  |  |  |  | TRUE |
| 1941 | tth:ssavirtsanprotjagluk |  | 294 | 100 |  |  |  |  |  |  |  |  |  |  | TRUE |
| 1942 | u-solut,peruslaskenta |  | 1772 | 100 |  |  | Urine |  |  |  |  |  |  |  | TRUE |
| 1943 | vb-aktuaalibikarbonaatti | mmol/l | 1612 | 0 | [16.94, 19.74, 21.93, 23.14, 24.18, 25.06, 26.96, 28.44, 30.92] |  | Venous blood |  | Bicarbonate | Substance Concentration |  | Blood venous | Qn | Point in time (spot) | FALSE |
| 1944 | vb-aktuaalibikarbonaatti |  | 185 | 17.3 | [20.1, 23.3, 24.38, 25.39, 26.05, 26.8, 27.78, 28.4, 29.7] |  | Venous blood |  | Bicarbonate | Substance Concentration |  | Blood venous | Qn | Point in time (spot) | FALSE |
| 1945 | vb-standardibikarbonaatti | mmol/l | 13754 | 0 | [20.04, 21.93, 23.08, 23.95, 24.68, 25.36, 26.13, 27.07, 28.82] |  | Venous blood |  | Bicarbonate.standard | Substance Concentration | Calculated | Blood venous | Qn | Point in time (spot) | FALSE |
| 1946 | vb-standardibikarbonaatti |  | 44 | 100 |  |  | Venous blood |  | Bicarbonate.standard |  |  | Blood venous |  |  | FALSE |
| 1947 | virtsansolujenhl7-siirtoon | e6/l | 5551 | 0 | [0.1, 0.37, 0.65, 1.07, 1.65, 2.44, 3.88, 6.78, 14.04] |  |  |  | Cells | Number Concentration |  | Urine | Qn | Point in time (spot) | FALSE |
| 1948 | virtsansolujenhl7-siirtoon |  | 353 | 11.05 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  | Cells |  |  | Urine |  |  | FALSE |
| 1949 | zb-aktuaalibikarbonaatti | mmol/l | 394 | 0 | [22, 23, 23.94, 24, 25, 26, 27, 27.8, 29.78] |  | Central blood |  | Bicarbonate | Substance Concentration |  | Blood venous | Qn | Point in time (spot) | FALSE |

