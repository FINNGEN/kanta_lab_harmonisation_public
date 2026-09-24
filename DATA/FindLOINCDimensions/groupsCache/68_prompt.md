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
Here is group 68 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
5245	-amyl	u/l	4274	0	[40.79, 91.13, 163.85, 262.6, 433.78, 741.28, 1310.78, 2709.64, 7550.04]			
5246	-amyl		352	99.15				
5247	alfa-1	g/l	903	0	[1.23, 1.5, 1.79, 2.22, 2.48, 2.68, 2.88, 3.11, 3.51]			
5248	alfa-2	g/l	907	0	[5.21, 5.83, 6.26, 6.53, 6.88, 7.18, 7.58, 8.1, 8.87]			
5249	amylaasi	u/l	1380	0	[29.91, 37.05, 43.3, 48.81, 54.92, 61.3, 69.75, 79.02, 95.18]			
5250	amylaasi		28	100				
5251	as-amyl	u/l	277	0	[7.29, 10.51, 15.56, 18.22, 24.01, 33.76, 50.6, 245.04, 2494.39]	As-Amylaasi	Ascitic fluid	
5252	as-amyl		47	87.23		As-Amylaasi	Ascitic fluid	
5253	du-aldos	nmol	1126	1.15	[10.3, 15.49, 20, 24.81, 30.39, 36.32, 42.97, 53.97, 73.23]	dU-Aldosteroni	24-hour urine	
5254	du-aldos	nmol/24h	31	0		dU-Aldosteroni	24-hour urine	
5255	du-aldos	nmol/l	25	0		dU-Aldosteroni	24-hour urine	
5256	du-aldos	ug/24h	12	0		dU-Aldosteroni	24-hour urine	
5257	du-aldos		191	49.21	[8, 15.27, 20, 24.32, 29.5, 36, 48.62, 70.25, 89]	dU-Aldosteroni	24-hour urine	
5258	fp-afos	u/l	595	0	[48.33, 55.25, 59.57, 63.86, 67.6, 73.77, 82.28, 90.12, 106.03]		Fasting plasma	
5259	fp-aldos	pmol/l	759	0	[99.71, 178.79, 234.24, 287.4, 344.18, 414.36, 481.84, 606.93, 836.03]	fP-Aldosteroni	Fasting plasma	
5260	fp-aldos		70	70		fP-Aldosteroni	Fasting plasma	
5261	fp-amyl	u/l	166	0	[38.7, 46.83, 53.52, 59.77, 65.17, 71.18, 77.02, 86.88, 100.9]		Fasting plasma	
5262	p-afos	u/l	2633385	0.01	[49.38, 57.42, 63.93, 70.22, 76.89, 84.76, 95, 111.35, 151.36]	P -Alkalinen fosfataasi	Plasma	
5263	p-afos		28410	100	[47.41, 55.11, 61.31, 67.35, 73.68, 80.95, 90.67, 106.27, 134.65]	P -Alkalinen fosfataasi	Plasma	
5264	p-aldos	pmol/l	978	0	[88.37, 146.16, 190.71, 235.98, 287.48, 347.26, 419.69, 540.86, 783.53]	P -Aldosteroni	Plasma	
5265	p-aldos		71	88.73		P -Aldosteroni	Plasma	
5266	p-amyl	u/l	368852	0.02	[26.2, 33.98, 40.36, 46.26, 52.37, 59.2, 67.68, 79.78, 104.76]	P -Amylaasi	Plasma	
5267	p-amyl		5758	100	[29, 36.73, 43, 48.41, 54.21, 60.53, 68.18, 78.9, 100.7]	P -Amylaasi	Plasma	
5268	p-amylaasi	u/l	1560	0	[28.07, 35.77, 41.54, 47.32, 52.57, 59.03, 66.78, 77.77, 99.14]		Plasma	
5269	p-amylaasi		28	89.29			Plasma	
5270	p-amylp	u/l	96538	0	[14.27, 20, 23.24, 26.43, 29.95, 34.28, 40.26, 51.17, 86.4]	P -Amylaasi, haimaperäinen	Plasma	
5271	p-amylp		16102	100	[12.88, 17.77, 21.4, 24.41, 27.47, 31.02, 35.38, 42.83, 60.62]	P -Amylaasi, haimaperäinen	Plasma	
5272	p-sldl	mmol/l	2968	0	[1.54, 1.82, 2.07, 2.32, 2.6, 2.9, 3.19, 3.53, 4.07]		Plasma	
5273	p-sldl		282	86.52			Plasma	
5274	pa-amyl	u/l	181	0	[6, 8.3, 13.62, 23.54, 38.11, 86.55, 532.84, 2066.13, 14410]	Pa-Amylaasi	Pancreatic juice	
5275	pa-amyl		13	100		Pa-Amylaasi	Pancreatic juice	
5276	pf-amyl	u/l	512	0	[11.47, 15.64, 19.01, 23.1, 27.84, 32.18, 37.92, 46.58, 62.15]	Pf-Amylaasi	Pleural fluid	
5277	pf-amyl		216	100		Pf-Amylaasi	Pleural fluid	
5278	s-aaldos	pmol/l	125	0.8	[506.75, 663.13, 772.54, 837.76, 918.5, 1062, 1146, 1442.2, 2247]		Serum	
5279	s-adali	mg/l	1092	0.37	[4.24, 6.27, 7.87, 9.1, 10.33, 11.83, 13.14, 14.95, 17.6]	S -Adalimumabi	Serum	
5280	s-adali		600	16.67	[3.21, 5.15, 6.89, 8.21, 9.3, 11.07, 13.15, 15.09, 18]	S -Adalimumabi	Serum	
5281	s-adaliab	au/ml	257	1.17	[4.47, 14.51, 21.55, 36.22, 43.39, 60.38, 104.64, 181.31, 370.6]	S -Adalimumabi, vasta-aineet	Serum	
5282	s-adaliab		2149	99.3		S -Adalimumabi, vasta-aineet	Serum	
5283	s-adalimu	mg/l	2004	0	[3.43, 5.38, 6.89, 8.1, 9.37, 10.76, 12.24, 13.87, 16.85]		Serum	
5284	s-adalimu		271	52.03	[2.22, 3.86, 5.11, 6.02, 6.96, 7.78, 8.44, 9.23, 10.15]		Serum	
5285	s-adalip		274	100			Serum	
5286	s-adalipa		1304	100			Serum	
5287	s-afluu	%	92	0	[10.3, 14.1, 19.33, 22.23, 25.37, 32.17, 35.52, 40.85, 45.6]		Serum	
5288	s-afluu	u/l	80	0	[17.5, 21, 25.5, 29.5, 33.5, 38.75, 50, 58.5, 97.5]		Serum	
5289	s-afluu		9	77.78			Serum	
5290	s-afluust	u/l	3036	0	[23.45, 30.5, 36.88, 43.03, 49.77, 57.33, 66.23, 80.75, 107.75]		Serum	
5291	s-afluust		488	63.73	[22.65, 29.23, 35.8, 41.92, 49.43, 57.83, 64.94, 75.26, 91.6]		Serum	
5292	s-afmuut	u/l	1555	0	[0, 0, 0, 0.56, 2.03, 4.33, 8.12, 14.99, 30.62]		Serum	
5293	s-afmuut		316	96.2			Serum	
5294	s-afos	iu/l	240	0	[47.27, 53.32, 59.23, 65.05, 70.65, 75.95, 84.63, 98.48, 130]	S -Alkalinen fosfataasi	Serum	
5295	s-afos	u/l	62976	0	[49.01, 56.54, 62.55, 68.34, 74.46, 81.49, 90.44, 104.36, 129.97]	S -Alkalinen fosfataasi	Serum	
5296	s-afos		986	36	[88.65, 108.98, 118.14, 127.37, 135.4, 144.04, 157.28, 186.3, 252.69]	S -Alkalinen fosfataasi	Serum	
5297	s-afos-is	u/l	70	0		S -Alkalinen fosfataasi, isoentsyymit	Serum	Isoenzymes
5298	s-afos-is		9083	99.98		S -Alkalinen fosfataasi, isoentsyymit	Serum	Isoenzymes
5299	s-afosluu	u/l	106	0	[25.67, 31, 35.33, 39.5, 42, 50.37, 59.67, 72.5, 100]	S -Alkalinen fosfataasi, luuspesifinen	Serum	
5300	s-afosluu	ug/l	30	0		S -Alkalinen fosfataasi, luuspesifinen	Serum	
5301	s-afosluu		35	11.43		S -Alkalinen fosfataasi, luuspesifinen	Serum	
5302	s-afospit	u/l	177	0	[96.72, 105.51, 113.04, 119.21, 129.13, 139.98, 153.3, 187.04, 317.98]		Serum	
5303	s-afospit		8	37.5			Serum	
5304	s-afsuol1	u/l	1064	0	[0, 0, 0, 0, 0, 0.97, 2.27, 4.95, 11.83]		Serum	
5305	s-afsuol1		158	1.27	[0, 0, 0, 0, 0.17, 1.4, 3, 6.28, 16.75]		Serum	
5306	s-afsuol2	u/l	1070	0	[0, 0, 0, 0, 0, 0.76, 2.02, 4.43, 8.94]		Serum	
5307	s-afsuol2		156	0.64	[0, 0, 0, 0, 0, 1.25, 3, 4.75, 8]		Serum	
5308	s-afsuol3	u/l	1075	0	[0, 0, 0, 0, 0, 0, 0, 1, 1.91]		Serum	
5309	s-afsuol3		157	0.64	[0, 0, 0, 0, 0, 0, 0, 1, 1]		Serum	
5310	s-afsuoli	%	53	0			Serum	
5311	s-afsuoli	u/l	189	0	[1, 2.2, 4.12, 5.94, 7, 9.07, 12.69, 23.37, 34.67]		Serum	
5312	s-afsuoli		182	96.15			Serum	
5313	s-albind	g/l	815	0	[34.39, 37.6, 39.38, 40.81, 42.07, 43.01, 44.01, 45.22, 47.08]		Serum	
5314	s-albind		155	25.81	[33.15, 36.46, 38.93, 39.99, 41.28, 41.98, 42.86, 43.61, 45.95]		Serum	
5315	s-albu	g/l	554	0	[34.76, 36.69, 38.29, 39.83, 40.76, 41.89, 43.25, 44.88, 46.93]		Serum	
5316	s-albu		12	33.33			Serum	
5317	s-album	g/l	27997	0	[31.02, 34.31, 36.21, 37.6, 38.74, 39.81, 40.91, 42.12, 43.69]		Serum	
5318	s-album		49	100	[31.46, 35.04, 37.29, 38.99, 40.3, 41.52, 42.95, 44.52, 46.29]		Serum	
5319	s-aldol	u/l	3331	0.03	[3.03, 3.84, 4, 4.87, 5, 5.94, 6.21, 7.11, 9.71]	S -Aldolaasi	Serum	
5320	s-aldol		603	75.79	[2.92, 3.62, 4.18, 4.48, 5.37, 5.7, 6.13, 7.21, 9.7]	S -Aldolaasi	Serum	
5321	s-aldos	pmol/l	5247	0.88	[80.92, 114.8, 152.73, 192.44, 237.39, 292.55, 361.76, 461.2, 667.49]	S -Aldosteroni	Serum	
5322	s-aldos		1207	72.49	[89.4, 124.94, 166.83, 212.25, 274.25, 349.09, 455.92, 585.04, 869.75]	S -Aldosteroni	Serum	
5323	s-aldos-m	pmol/l	88	0	[47, 57.1, 78.9, 115.83, 136, 213.63, 263.1, 334.4, 926]	S -Aldosteroni, makuu	Serum	Supine (lying down)
5324	s-aldos-m		66	68.18		S -Aldosteroni, makuu	Serum	Supine (lying down)
5325	s-aldos-p	pmol/l	824	0	[77.23, 114.1, 153.16, 191.49, 236.83, 292.92, 363.97, 474.9, 659.05]	S -Aldosteroni, pysty	Serum	Upright (standing)
5326	s-aldos-p		329	21.88	[79.42, 123.32, 172.77, 232.62, 283.29, 334.05, 403.83, 552.65, 812.7]	S -Aldosteroni, pysty	Serum	Upright (standing)
5327	s-alfa-1	%	11	0			Serum	
5328	s-alfa-1	g/l	30281	0	[2.19, 2.42, 2.6, 2.72, 2.88, 3.03, 3.24, 3.54, 4.08]		Serum	
5329	s-alfa-1		50	100	[1.5, 1.7, 1.88, 2.13, 2.38, 2.62, 2.88, 3.19, 3.81]		Serum	
5330	s-alfa-2	%	11	0			Serum	
5331	s-alfa-2	g/l	30219	0	[5.45, 5.93, 6.31, 6.66, 7.01, 7.39, 7.84, 8.42, 9.36]		Serum	
5332	s-alfa-2		50	100	[5.71, 6.15, 6.53, 6.83, 7.14, 7.51, 7.91, 8.44, 9.39]		Serum	
5333	s-alfa1	g/l	1708	0	[1.45, 1.6, 1.7, 1.8, 1.95, 2.11, 2.38, 2.65, 3.03]		Serum	
5334	s-alfa1		92	25			Serum	
5335	s-alfa2	g/l	1768	0	[5.73, 6.28, 6.69, 6.98, 7.28, 7.59, 8.04, 8.57, 9.36]		Serum	
5336	s-alfa2		92	25			Serum	
5337	s-allige	mg/l	14	0		S -Allergeeni, IgE-vasta-aineet	Serum	
5338	s-allige	u/ml	1753	0	[0.12, 0.19, 0.31, 0.51, 0.83, 1.39, 2.4, 4.64, 12.35]	S -Allergeeni, IgE-vasta-aineet	Serum	
5339	s-allige		2748	99.71		S -Allergeeni, IgE-vasta-aineet	Serum	
5340	s-amyl	u/l	10387	0	[33.31, 39.8, 44.99, 49.81, 54.67, 59.75, 66.53, 75.22, 91.12]	S -Amylaasi	Serum	
5341	s-amyl		129	20.16	[35, 42.3, 49.52, 56.4, 62.75, 71, 94.2, 128.3, 161]	S -Amylaasi	Serum	
5342	s-amyl-is	form	15	100		S -Amylaasi, isoentsyymit	Serum	Isoenzymes
5343	s-amyl-is		434	100		S -Amylaasi, isoentsyymit	Serum	Isoenzymes
5344	s-amylp	u/l	280	0	[14.92, 20.3, 25.89, 30.35, 36.7, 44.3, 55.25, 69.52, 135.91]	S -Amylaasi, haimaperäinen	Serum	
5345	s-amylp		66	16.67		S -Amylaasi, haimaperäinen	Serum	
5346	s-amyls	u/l	256	0	[12.25, 18.54, 23.94, 28.43, 34.44, 44.93, 63.37, 81.22, 120.05]	S -Amylaasi, sylkiperäinen	Serum	
5347	s-amyls		61	18.03		S -Amylaasi, sylkiperäinen	Serum	
5348	s-dmklots	nmol/l	15078	0.19	[349.72, 488.38, 603.51, 717.55, 840.77, 973.75, 1127.96, 1320.3, 1616.71]	S -Desmetyyliklotsapiini	Serum	
5349	s-dmklots	umol/l	9051	0	[0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.95, 1.16, 1.45]	S -Desmetyyliklotsapiini	Serum	
5350	s-dmklots	âumol/l	32	0		S -Desmetyyliklotsapiini	Serum	
5351	s-dmklots		1117	100	[0.79, 1.17, 292.49, 521.2, 721.89, 874.92, 1051.9, 1273.86, 1599.85]	S -Desmetyyliklotsapiini	Serum	
5352	s-gliade	u/ml	23	60.87			Serum	
5353	s-gliade		84	98.81			Serum	
5354	s-gliadie	u/ml	531	0	[0, 0, 0, 0, 0.01, 0.01, 0.02, 0.07, 0.24]		Serum	
5355	s-gliadie		118	5.93	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Serum	
5356	s-hladsa		847	100			Serum	
5357	s-kalatue		132	100			Serum	
5358	s-kolaige	u/ml	14	100			Serum	
5359	s-kolaige		181	100			Serum	
5360	s-kudosab		1042	100			Serum	
5361	s-ngmuut		16771	100			Serum	
5362	s-oaldos	pmol/l	200	1.5	[636.2, 2117.22, 7632.17, 17219.7, 36953.33, 62851.67, 87233.33, 130744.44, 214222.22]		Serum	
5363	s-olants	nmol/l	4003	0.07	[53.03, 76.26, 97.99, 119.12, 141.44, 165.86, 195.39, 234.91, 291.91]	S -Olantsapiini	Serum	
5364	s-olants		595	31.43	[58.73, 86.04, 110.31, 132.4, 158.88, 189.03, 219.38, 262.18, 324.46]	S -Olantsapiini	Serum	
5365	s-ovalbue	u/ml	86	1.16	[0, 0.02, 0.03, 0.1, 0.23, 0.56, 2, 8.02, 21.8]		Serum	
5366	s-ovalbue		16	81.25			Serum	
5367	s-salis	mmol/l	56	0		S -Salisylaatit	Serum	
5368	s-salis	umol/l	87	5.75		S -Salisylaatit	Serum	
5369	s-salis		121	97.52		S -Salisylaatit	Serum	
5370	s-scl-t		833	100			Serum	
5371	s-sfit1	ng/l	135	0	[1994, 2524.58, 3215, 3792.29, 4608.29, 5445.5, 7105.78, 9372.28, 11496.33]	S -Endoteelikasvutekijän liukoinen reseptori	Serum	
5372	s-sflt-1	ng/l	318	0	[1291.87, 1667.24, 2344.04, 3006.81, 3762.57, 4805.39, 6029.95, 7158.88, 9214.96]		Serum	
5373	s-sldl	mmol/l	2207	0	[1.75, 2.1, 2.37, 2.68, 2.95, 3.22, 3.51, 3.8, 4.25]		Serum	
5374	s-sldl		177	98.87			Serum	
5375	s-suoli	u/l	115	0	[0, 0, 0, 0.27, 2.83, 5.44, 7.47, 12.05, 21.01]		Serum	
5376	s-suoli		10	30			Serum	
5377	s-suolist	u/l	81	0	[2, 3.1, 5.23, 9, 10.88, 13, 15, 20.35, 28]		Serum	
5378	s-suolist		63	96.83			Serum	
5379	s-valdos	pmol/l	157	0.64	[3435.33, 10631.9, 19753.33, 29394.05, 44768.33, 65139.29, 87875, 118200, 193300]		Serum	
5380	s-vedol	mg/l	1566	0	[10.87, 14.08, 17.75, 20.76, 23.95, 27.59, 31.95, 37.11, 43.61]	S -Vedolitsumabi	Serum	
5381	s-vedol		221	12.22	[5.88, 9.27, 13.22, 17.42, 21.48, 25.78, 28.81, 33.33, 39.06]	S -Vedolitsumabi	Serum	
5382	saline		946	3.38	[0, 0, 0, 0, 0, 0, 0, 0, 0]			
5383	se-amyl	u/l	1679	0.83	[7.84, 14.57, 24.16, 42.2, 81.52, 202.31, 555.29, 1833.05, 9919.76]	Se-Amylaasi	Secretion	
5384	se-amyl		248	97.98		Se-Amylaasi	Secretion	
5385	sp-suld		262	100			Sperm / semen	
5386	u-amyl	u/l	2762	0.04	[40.07, 60.75, 84.23, 110.48, 142.21, 184.16, 244.01, 332.59, 547.07]	U -Amylaasi	Urine	
5387	u-amyl		192	49.48	[46, 98.65, 135.92, 161.9, 205.44, 269.5, 358.67, 597.35, 1056]	U -Amylaasi	Urine	
5388	u-amylp	u/l	106	0	[29, 44.7, 68.1, 90.36, 112.17, 155.8, 214.47, 337.6, 546]	U -Amylaasi, haimaperäinen	Urine	
5389	u-amylp		15	20		U -Amylaasi, haimaperäinen	Urine	

