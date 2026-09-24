[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

Your task: for each row of the table given below, infer the six LOINC axes and whether the code refers to a panel, using only the information in that row.

# The Finnish laboratory coding system

Each national lab test has a 4-digit running number code and a short mnemonic abbreviation of at most 10 characters, built as:

    <system prefix> - <test abbreviation> [<suffix>]

- The **system prefix** is a 1-2 letter code for the specimen / system the sample was taken from, mostly derived from English words: `S` = serum, `P` = plasma, `B` = blood, `U` = urine, `Li` = cerebrospinal fluid, `F` = feces, `Ts` = tissue, `Pt` = patient (a whole-patient investigation, not a specimen), `fS`/`fP`/`fB` = fasting serum/plasma/blood, `dU` = 24-hour urine, `cU` = collected urine, `E` = erythrocyte, `L` = leukocyte, `Sy` = synovial fluid, and so on.
- The **test abbreviation** is a mnemonic of the test's long Finnish name (occasionally an established international abbreviation instead, e.g. `CEA`, `TSH`, `CRP`).
- The optional **suffix** (takaliite) qualifies the result type or method, attached directly or after a hyphen. The most important is `-O`, used for ALL qualitative and semi-quantitative tests. Others include `-Ab` (antibodies), `-Ag` (antigen), `-Vi` (culture, viljely), `-Vr` (staining), `-Nh` (nucleic acid), `-D` (DNA test), `-Ion` (ionized), `-V` (free/unconjugated), `-Fr` (fractions), `-Ind` (index), `-R` (exercise / functional test), `-Ps`/`-Ss` (screening), `-Ty` (typing), `-Tc` (transcutaneous), `-M` (lying down), `-P` (upright).

Finnish long names are largely descriptive; note that Finnish compound words run together, e.g. "transferriininrautakyllästeisyys" = transferrin iron saturation.

# The table columns

Each row is one observed local lab test/unit combination:

- `row_id` — a unique integer identifying the row. **Echo it back exactly**; it is the only key used to join your answer to the table.
- `TEST_NAME` — the local test code, lowercased with spaces removed. Normally the Finnish abbreviation described above, but see the caveats below.
- `UNIT` — the measurement unit as recorded locally (e.g. `mmol/l`, `g/l`, `%`, `U/l`, `E9/l`). May be empty.
- `n` — how many result records exist for this test/unit combination.
- `p_missing` — percentage (0-100) of those records with no numeric value. A high `p_missing` together with an empty `UNIT` suggests a non-quantitative (qualitative / narrative) test.
- `deciles` — the 9 deciles of the observed numeric values, when available. Use these to sanity-check the property and the unit (e.g. values around 0.1-0.5 with no unit next to a sibling row in `%` with values 8-40 indicates a fraction vs a percentage).
- `LongName` — the official Finnish long name from the national code table, when the code could be matched. Often empty.
- `prefix_meaning` — the decoded system prefix (e.g. "Serum", "Fasting plasma", "Urine"), when recognised. This is derived from the code text, so treat it as a strong but not infallible hint.
- `suffix_meaning` — the decoded suffix (e.g. "Qualitative test (also semi-quantitative)", "Antibodies", "Culture"), when recognised.

# Important caveats about this data

- These codes are collected from MANY different Finnish healthcare source systems over decades. They are **not** clean national codes: they may be locally invented, abbreviated differently, truncated, concatenated with several alternative spellings separated by commas, contain typos, or be a bare number that was never resolved to an abbreviation.
- Columns are frequently empty. An empty column means "unknown", never "not applicable".
- **When the information for a given axis is not knowable from the row, leave that axis empty.** An empty value is a correct and useful answer. A plausible-sounding guess is worse than an empty field, because downstream code cannot tell a guess from a fact. Do not infer an axis from convention alone when the row itself does not support it.
- The rows have been **grouped by string similarity** of `TEST_NAME`, so that near-identical codes appear together. Use the group as context: sibling rows often disambiguate a truncated or misspelled code, and reveal whether two similar codes are genuinely the same test or deliberately different (e.g. differing specimen, fasting state, or unit). Do not assume all rows in a group are the same test.

# The six LOINC axes

Assign, per row:

**Write every axis as the full OMOP concept name, never as a LOINC abbreviation.** These values are matched against the OMOP vocabulary's own attribute names, which are spelled out in full: write `Substance Concentration`, not `SCnc`; `Point in time (spot)`, not `Pt`; `Serum or Plasma`, not `Ser/Plas`; `Nucleic acid amplification with probe detection`, not `NAA+probe`. The single exception is `has_scale_type`, which OMOP itself stores abbreviated (`Qn`, `Ord`, ...) — see below.

The value lists below are the **most frequent real values** for each axis, measured on Finnish lab codes that have already been mapped to OMOP concepts. Prefer a value from these lists whenever one fits; use another full OMOP attribute name only when none of them does.

1. `has_component` — the analyte / substance measured. The core identity of the test. Give the English LOINC-style component name, e.g. `C reactive protein`, `Hemoglobin`, `Leukocytes`, `Glucose`, `Creatinine`, `Albumin`, `pH`, `Lymphocytes/leukocytes`, `Hemoglobin A1c/Hemoglobin.total`, `INR`, `Glomerular filtration rate`. Components are free text, so there is no closed list — but match the LOINC spelling where you know it (note `C reactive protein`, no hyphen).
2. `has_property` — the kind of quantity, independent of the unit. Most common: `Substance Concentration` (molar units: mol/l, mmol/l, umol/l, nmol/l, pmol/l), `Mass Concentration` (mass units: g/l, mg/l, ug/l), `Arbitrary Concentration` (arbitrary/IU units), `Number Concentration` (counts per volume, e.g. E9/l), `Number Fraction` (% of cells), `Presence or Threshold` (qualitative detected/not-detected), `Mass fraction` (%), `Catalytic Concentration` (enzyme activity, e.g. U/l), `Titer`, `Relative time`. Others include `Presence or Identity`, `Ratio`, `Volume`, `Time`, `Temperature`, `Length`, `Susceptibility (microorganisms)`, `Finding`.
3. `has_time_aspect` — almost always `Point in time (spot)`. Use `24 hours` for a 24-hour collection (the `dU` prefix), and the matching interval (`12 hours`, `1 hour`, `8 hours`, ...) for other timed collections. `Unspecified` exists but prefer leaving the axis empty over using it.
4. `has_system` — the specimen / system. Most common: `Serum or Plasma`, `Blood`, `Serum`, `Urine`, `Platelet poor plasma`, `Cerebral spinal fluid`, `Blood venous`, `Blood capillary`, `Blood arterial`, `Red Blood Cells`. Others include `Plasma`, `Stool`, `Tissue`, `White Blood Cells`, `^Patient` (a whole-patient measure such as eGFR or a body measurement). The `prefix_meaning` column maps onto this directly. Note fasting is NOT part of the system in LOINC: `fS` is still `Serum`. Do not use the placeholder values `XXX` or `-`; leave the axis empty instead.
5. `has_scale_type` — **the one abbreviated axis**, because OMOP stores it abbreviated: `Qn` (quantitative), `Ord` (ordinal / qualitative with ordered answers), `SemiQn` (semi-quantitative, e.g. graded `1+`/`2+`/`3+`), `Nom` (nominal, e.g. an organism identified), `Nar` (narrative text), `Doc` (document), `OrdQn` (reportable either ordinally or quantitatively). A `-O` suffix means `Ord`, or `SemiQn` when the result is graded. A high `p_missing` with no unit and no deciles suggests `Nar` or `Ord` rather than `Qn`.
6. `has_method` — the analytical method, **only when the method genuinely changes the clinical interpretation**. Most common: `Coagulation assay`, `Immunoassay`, `Nucleic acid amplification with probe detection`, `Automated count`, `Electrophoresis`, `Calculated`, `Test strip`, `Creatinine-based formula (CKD-EPI)/1.73 sq M`, `Immunoblot`, `Immunofluorescence (IF)`. Others include `Organism specific culture`, `Flow cytometry (FC)`, `Molecular genetics`, `Confirm`. LOINC deliberately omits Method for most chemistry tests, and so should you: **leave it empty unless the code explicitly indicates a method**. Do not invent a method.

And additionally:

7. `is_panel` — `true` if the code refers to a **panel**: an order that bundles several separately reported component tests (e.g. `B-PVK` = full blood count bundling erythrocytes, hemoglobin, hematocrit, MCV, MCH, MCHC, leukocytes; or `F-BaktVi1` bundling several stool cultures). `false` for a single reportable result. A panel's own axes are usually mostly empty — that is expected and correct, since the axes describe the individual components, not the bundle.

# LOINC guidelines to follow

- The first five axes (Component, Property, Time, System, Scale) are mandatory in LOINC; **Method is optional by design** and is included only when it changes clinical interpretation. Omitting Method is the norm, not a failure.
- Property and Scale travel together in practice: a test reported as a number is `Qn` with a concentration-like property; a test reported as positive/negative is `Ord` with `Presence or Threshold`.
- Never cross quantitative and qualitative: if the row shows a real numeric distribution (`deciles` present, `p_missing` low), it is `Qn`, not `Ord`.
- `Mass Concentration` and `Substance Concentration` are distinct values even for the same analyte — decide from the `UNIT` and the magnitude of the `deciles`, not from the analyte name. `g/l`, `mg/l`, `ug/l` are mass; `mol/l`, `mmol/l`, `umol/l`, `nmol/l`, `pmol/l` are substance.
- A general System may be legitimately more specific in the local code, but never generalise beyond what the code says, and never substitute across unrelated systems (serum vs urine vs CSF are never interchangeable).
- `Serum or Plasma` is the right answer only when the code itself is ambiguous between serum and plasma; if the prefix says `S` use `Serum`, if it says `P` use `Plasma`.

# Output

Return one entry per input row, with `row_id` echoed exactly, and the seven fields above. Use empty strings for axes you cannot determine. Return an entry for EVERY row of the table, including rows you can say almost nothing about.

Additionally, return a short `reflection` (a few sentences to a short paragraph, markdown) covering: ideas to improve this process, gotchas and ambiguities you hit in THIS group, systematic problems in the data, and anything that would have helped you decide. Be concrete and specific to the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 110 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
8999	b-b-cd19	e6/l	913	0	[10.41, 31.05, 55.36, 87.14, 120.42, 155.29, 201.58, 263.7, 407.08]		Blood	
9000	b-b-cd19	e9/l	3083	0	[0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.29, 0.48]		Blood	
9001	b-b-cd19		569	89.28	[0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.31, 0.47]		Blood	
9002	b-cd16/56	e6/l	12	0			Blood	
9003	b-cd16/56	e9/l	2606	0.65	[0.06, 0.09, 0.12, 0.15, 0.18, 0.22, 0.26, 0.33, 0.44]		Blood	
9004	b-cd16/56		108	84.26			Blood	
9005	b-cd16/cd56	e9/l	263	0	[0.09, 0.12, 0.15, 0.17, 0.21, 0.24, 0.3, 0.36, 0.44]		Blood	
9006	b-cd16/cd56		15	100			Blood	
9007	b-cd19	e6/l	3891	0	[0, 1.97, 16.17, 41.05, 70.27, 108.04, 158.42, 221.57, 336.97]		Blood	
9008	b-cd19	e9/l	2870	0.59	[0, 0, 0.01, 0.03, 0.06, 0.09, 0.14, 0.19, 0.29]		Blood	
9009	b-cd19		175	66.29			Blood	
9010	b-cd3	e6/l	3892	0			Blood	
9011	b-cd3	e9/l	2868	0.59			Blood	
9012	b-cd3		204	71.57			Blood	
9013	b-cd34	e6/l	193	0	[5.27, 13.75, 20.31, 28.86, 37.69, 50.47, 63.07, 93.98, 156.93]		Blood	
9014	b-cd34		27	29.63			Blood	
9015	b-cd4	e6/l	3893	0	[134.07, 213.38, 284.14, 381.8, 505.45, 647.7, 819.98, 1038.04, 1335.05]		Blood	
9016	b-cd4	e9/l	2870	0.59	[0.14, 0.2, 0.25, 0.32, 0.4, 0.51, 0.63, 0.8, 1.07]		Blood	
9017	b-cd4		172	66.28			Blood	
9018	b-cd8	e6/l	3892	0	[117.75, 200.41, 277.17, 351.98, 433.16, 541.85, 672.5, 850.74, 1214.03]		Blood	
9019	b-cd8	e9/l	2870	0.59	[0.11, 0.16, 0.23, 0.29, 0.36, 0.46, 0.57, 0.73, 1]		Blood	
9020	b-cd8		172	66.28			Blood	
9021	b-lcd34	e6/l	251	0	[3, 7.11, 11.11, 14.14, 17.55, 23.82, 31.86, 44, 64.2]	B -Leukosyytit, CD34 alaluokka	Blood	
9022	b-lcd34	e9/l	475	0	[0, 0.01, 0.02, 0.03, 0.03, 0.04, 0.06, 0.09, 0.13]	B -Leukosyytit, CD34 alaluokka	Blood	
9023	b-lcd34		66	100		B -Leukosyytit, CD34 alaluokka	Blood	
9024	b-lycd4		496	100		B -Lymfosyytti CD4-alaluokka	Blood	
9025	b-t-cd3	e6/l	1174	0			Blood	
9026	b-t-cd3	e9/l	2692	0			Blood	
9027	b-t-cd3		304	81.91			Blood	
9028	b-t-cd4	e6/l	1609	0	[168.06, 247.56, 335.09, 433.05, 551.26, 672.04, 816.88, 957.34, 1254.62]		Blood	
9029	b-t-cd4	e9/l	6105	0	[0.16, 0.25, 0.34, 0.43, 0.52, 0.64, 0.79, 0.96, 1.28]		Blood	
9030	b-t-cd4		475	69.89	[0.2, 0.26, 0.34, 0.42, 0.55, 0.68, 0.8, 0.95, 1.29]		Blood	
9031	b-t-cd8	e6/l	1174	0	[141.94, 210.82, 289.62, 366.11, 450.98, 530.13, 639.55, 796.16, 1179.47]		Blood	
9032	b-t-cd8	e9/l	2753	0	[0.14, 0.21, 0.27, 0.35, 0.43, 0.52, 0.65, 0.83, 1.1]		Blood	
9033	b-t-cd8		311	79.42			Blood	
9034	bl-cd4/cd8	form	42	100			Bronchoalveolar lavage	
9035	bl-cd4/cd8		91	100			Bronchoalveolar lavage	
9036	cd4/cd8		3940	0.23	[0.29, 0.47, 0.68, 0.91, 1.2, 1.57, 1.94, 2.45, 3.26]			
9037	l-cd34	%	481	0	[0.05, 0.08, 0.1, 0.13, 0.16, 0.2, 0.25, 0.32, 0.61]		Leukocyte	
9038	l-cd34		41	100			Leukocyte	
9039	la-cd34	e6/kg	156	0	[0.6, 0.9, 1.18, 1.41, 1.69, 2.1, 2.53, 3.4, 4.94]			
9040	la-cd34	e9/l	393	0	[0.41, 0.56, 0.72, 0.84, 1.03, 1.27, 1.77, 2.36, 3.2]			
9041	la-cd34-ks		395	100				
9042	la-cd34-os	%	393	0	[0.22, 0.3, 0.39, 0.49, 0.59, 0.69, 0.84, 1.12, 1.67]			
9043	la-t-cd3	e9/l	149	0				
9044	la-t-cd3		6	16.67				
9045	la-t-cd4	e9/l	149	0				
9046	la-t-cd4		6	16.67				
9047	la-t-cd8	e9/l	149	0				
9048	la-t-cd8		6	16.67				
9049	ly-b-cd19	%	1504	0	[0, 0, 0.45, 2.91, 5.54, 7.86, 10.24, 13.34, 18.94]		Lymphocyte	
9050	ly-b-cd19		950	99.05			Lymphocyte	
9051	ly-cd16/56	%	3462	0.49	[5.28, 8.01, 10.25, 12.46, 15.08, 18.07, 21.55, 26.37, 33.4]		Lymphocyte	
9052	ly-cd16/56		107	86.92			Lymphocyte	
9053	ly-cd16/cd56	%	262	0	[5.52, 8.16, 10.06, 12.71, 14.93, 17.65, 20.63, 27.5, 36.58]		Lymphocyte	
9054	ly-cd16/cd56		15	100			Lymphocyte	
9055	ly-cd19	%	3462	0.49	[0, 0, 1.17, 3.24, 5.55, 8.08, 10.86, 14.11, 20.27]		Lymphocyte	
9056	ly-cd19		107	85.98			Lymphocyte	
9057	ly-cd19-b	%	2507	0	[0, 0, 1, 3.95, 7.56, 10.5, 13.61, 17.58, 25.6]		Lymphocyte	
9058	ly-cd19-b		19	100			Lymphocyte	
9059	ly-cd3	%	3726	0.46	[52.12, 61.25, 67.07, 71.15, 74.98, 78.39, 81.66, 85.36, 89.48]		Lymphocyte	
9060	ly-cd3		122	87.7			Lymphocyte	
9061	ly-cd4	%	3726	0.46	[16.32, 22.56, 27.91, 32.59, 37.02, 41.75, 46.47, 51.76, 58.99]		Lymphocyte	
9062	ly-cd4		122	87.7			Lymphocyte	
9063	ly-cd4+8+	%	41	41.46			Lymphocyte	
9064	ly-cd4+8+		75	100			Lymphocyte	
9065	ly-cd4-8-	%	207	8.21	[7, 8, 8, 8.88, 9.82, 10.9, 12, 14, 16]		Lymphocyte	
9066	ly-cd4-8-		77	100			Lymphocyte	
9067	ly-cd4-t	%	4576	0	[15.23, 21.8, 27.31, 31.42, 35.47, 39.26, 43.26, 48.23, 54.7]		Lymphocyte	
9068	ly-cd4-t		170	22.94	[17.53, 21.58, 24.78, 29.15, 33.2, 38.25, 41.67, 47.37, 52.57]		Lymphocyte	
9069	ly-cd4/cd8		2752	4.18	[0.37, 0.55, 0.75, 0.96, 1.18, 1.48, 1.83, 2.29, 3.23]	Ly-Auttaja- ja tappajasolujen suhde, immunofenotyypitys	Lymphocyte	
9070	ly-cd4/cd8suhde		278	5.4	[0.5, 0.76, 1.02, 1.29, 1.66, 1.95, 2.26, 2.73, 3.97]		Lymphocyte	
9071	ly-cd8	%	3725	0.46	[14.46, 19.13, 22.75, 26.46, 30.35, 34.98, 40.06, 46.74, 56.02]		Lymphocyte	
9072	ly-cd8		122	87.7			Lymphocyte	
9073	ly-t-cd3	%	3926	0	[56.23, 64.92, 70.33, 74.35, 77.57, 80.54, 84.02, 87.72, 92.04]		Lymphocyte	
9074	ly-t-cd3		264	98.48			Lymphocyte	
9075	ly-t-cd4	%	2006	0	[18.72, 24.57, 29.84, 34.47, 38.67, 43.22, 47.75, 52.18, 58.04]	Ly-Lymfosyytit, T-auttajasolujen osuus	Lymphocyte	
9076	ly-t-cd4		3875	99.92		Ly-Lymfosyytit, T-auttajasolujen osuus	Lymphocyte	
9077	ly-t-cd4.	%	1462	0	[18.57, 26.32, 32.42, 36.77, 41.27, 46.47, 51.47, 56.35, 63.05]		Lymphocyte	
9078	ly-t-cd4.		36	72.22			Lymphocyte	
9079	ly-t-cd4/8	ratio	1816	0	[0.6, 0.8, 0.99, 1.23, 1.56, 1.85, 2.06, 2.47, 3.19]		Lymphocyte	
9080	ly-t-cd4/8		224	100	[0.48, 0.79, 1.06, 1.31, 1.55, 1.83, 2.13, 2.62, 3.69]		Lymphocyte	
9081	ly-t-cd8	%	2895	0	[14.95, 19.45, 23.24, 27.01, 30.29, 33.79, 38.05, 43.59, 52.29]	Ly-Lymfosyytit, T-estäjäsolujen osuus	Lymphocyte	
9082	ly-t-cd8		245	99.59		Ly-Lymfosyytit, T-estäjäsolujen osuus	Lymphocyte	
9083	ly-tcd4/8.		2179	0.83	[0.48, 0.75, 1, 1.21, 1.42, 1.69, 2, 2.51, 3.27]		Lymphocyte	
9084	ly-tt-cd8	%	1219	0	[13.33, 17.86, 21.01, 24.35, 28, 31.32, 36.22, 42.56, 52.88]		Lymphocyte	
9085	ly-tt-cd8		5	40			Lymphocyte	
9086	s-gt-cdt	%	13	0			Serum	
9087	s-gt-cdt		2807	3.35	[2.6, 2.87, 3.04, 3.25, 3.47, 3.7, 3.96, 4.27, 4.86]		Serum	
9088	so-t-cd3	%	149	0	[16.66, 19.73, 21.87, 23.49, 24.84, 27.82, 29.85, 33.41, 49.51]			
9089	so-t-cd3		6	16.67				
9090	so-t-cd4	%	149	0	[9.42, 10.93, 12.3, 13.53, 14.67, 15.99, 17.4, 19.67, 23.42]			
9091	so-t-cd4		6	16.67				
9092	so-t-cd8	%	149	0	[5.87, 7, 7.83, 8.57, 9.8, 10.57, 12.18, 14.02, 21.4]			
9093	so-t-cd8		6	16.67				

