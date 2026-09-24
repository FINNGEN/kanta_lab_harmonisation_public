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

1. `has_component` — the analyte / substance measured (e.g. `Glucose`, `Hemoglobin`, `Transferrin`, `Thyrotropin`). The core identity of the test. Give the English LOINC-style component name.
2. `has_property` — the kind of quantity, independent of the unit. Use LOINC property abbreviations: `MCnc` (mass concentration, e.g. g/l, mg/l), `SCnc` (substance/molar concentration, e.g. mmol/l, nmol/l), `CCnc` (catalytic concentration, e.g. U/l), `NCnc` (number concentration, e.g. E9/l), `MFr` (mass fraction, %), `SFr` (substance fraction), `NFr` (number fraction, % of cells), `Titr` (titer), `PrThr` (presence or threshold, for qualitative tests), `Time`, `Temp`, `Vol`, `Len`, `Ratio`, `Type`, `Prid` (identity of an organism), `ACnc` (arbitrary concentration).
3. `has_time_aspect` — `Pt` for a point-in-time (spot) sample, or an interval such as `24H` for a 24-hour collection (`dU` prefix), `12H`, etc.
4. `has_system` — the specimen / system, LOINC style: `Ser`, `Plas`, `Ser/Plas`, `Bld`, `Urine`, `CSF`, `Stool`, `Tiss`, `RBC`, `WBC`, `^Patient`, etc. The `prefix_meaning` column maps onto this directly. Note fasting is NOT part of the system in LOINC; `fS` is still `Ser`.
5. `has_scale_type` — `Qn` (quantitative), `Ord` (ordinal / qualitative with ordered answers), `Nom` (nominal, e.g. an organism identified), `Nar` (narrative text), `Doc` (document). A `-O` suffix means `Ord` (or `Ord` for semi-quantitative). A high `p_missing` with no unit and no deciles suggests `Nar` or `Ord` rather than `Qn`.
6. `has_method` — the analytical method, **only when the method genuinely changes the clinical interpretation** (e.g. `Test strip`, `Immunoassay`, `Culture`, `NAA with probe detection`, `Automated count`). LOINC deliberately omits Method for most chemistry tests, and so should you: **leave it empty unless the code explicitly indicates a method**. Do not invent a method.

And additionally:

7. `is_panel` — `true` if the code refers to a **panel**: an order that bundles several separately reported component tests (e.g. `B-PVK` = full blood count bundling erythrocytes, hemoglobin, hematocrit, MCV, MCH, MCHC, leukocytes; or `F-BaktVi1` bundling several stool cultures). `false` for a single reportable result. A panel's own axes are usually mostly empty — that is expected and correct, since the axes describe the individual components, not the bundle.

# LOINC guidelines to follow

- The first five axes (Component, Property, Time, System, Scale) are mandatory in LOINC; **Method is optional by design** and is included only when it changes clinical interpretation. Omitting Method is the norm, not a failure.
- Property and Scale travel together in practice: a test reported as a number is `Qn` with a concentration-like property; a test reported as positive/negative is `Ord` with `PrThr`.
- Never cross quantitative and qualitative: if the row shows a real numeric distribution (`deciles` present, `p_missing` low), it is `Qn`, not `Ord`.
- Mass (`MCnc`) and substance/molar (`SCnc`) properties are distinct axes values even for the same analyte — decide from the `UNIT` and the magnitude of the `deciles`, not from the analyte name. `g/l`, `mg/l`, `ug/l` are mass; `mol/l`, `mmol/l`, `umol/l`, `nmol/l`, `pmol/l` are substance.
- A general System may be legitimately more specific in the local code, but never generalise beyond what the code says, and never substitute across unrelated systems (serum vs urine vs CSF are never interchangeable).
- `Ser/Plas` is the right answer only when the code itself is ambiguous between serum and plasma; if the prefix says `S` use `Ser`, if it says `P` use `Plas`.

# Output

Return one entry per input row, with `row_id` echoed exactly, and the seven fields above. Use empty strings for axes you cannot determine. Return an entry for EVERY row of the table, including rows you can say almost nothing about.

Additionally, return a short `reflection` (a few sentences to a short paragraph, markdown) covering: ideas to improve this process, gotchas and ambiguities you hit in THIS group, systematic problems in the data, and anything that would have helped you decide. Be concrete and specific to the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 49 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
3382	-adenag		1964	100		-Adenovirus, antigeeni		
3383	-bokaag		187	100				
3384	-coinrsv		2490	100				
3385	-inabrsv		19142	100				
3386	-infaag		10730	100		-Influenssa A -virus, antigeeni		
3387	-infabag		15107	100		-Influenssa A ja B -virus, antigeeni		
3388	-infabnh		961	100				
3389	-infah03		227	100				
3390	-infah09		488	100				
3391	-infah1		480	100				
3392	-infah3		261	100				
3393	-infavt		1271	100				
3394	-infbag		10722	100		-Influenssa B -virus, antigeeni		
3395	-infbvt		1271	100				
3396	-infl.a		220	100				
3397	-infl.b		220	100				
3398	-infrpak		1338	100				
3399	-infrsv		162	100				
3400	-ivf-et		194	100				Special technique
3401	-koroag		625	100				
3402	-metpnag		370	100				
3403	-pin1ag		1146	100		-Parainfluenssa 1 -virus, antigeeni		
3404	-pin2ag		1147	100		-Parainfluenssa 2 -virus, antigeeni		
3405	-pin3ag		1147	100		-Parainfluenssa 3 -virus, antigeeni		
3406	-pinf1ag		235	100				
3407	-pinf2ag		235	100				
3408	-pinf3ag		235	100				
3409	-pnjiag		188	100		-Pneumocystis jirovecii, antigeeni		
3410	-rvirag		3025	100		-Respiratoristen virusten antigeeni		
3411	-stpnag		4094	100		-Streptococcus pneumoniae, antigeeni		
3412	bi-inflamm		311	100			Bile	
3413	f-adenag		863	100		F -Adenovirus, antigeeni	Feces	
3414	f-giarag		218	100		F -Giardia, antigeeni	Feces	
3415	f-gicrag		163	99.39			Feces	
3416	f-noroag		1048	100			Feces	
3417	f-rotaag		886	100		F -Rotavirus, antigeeni	Feces	
3418	f-virag		489	100			Feces	
3419	li-adenabg		215	100		Li-Adenovirus, IgG-vasta-aineet	Cerebrospinal fluid	
3420	li-infaabg	eiu	40	0		Li-Influenssa A -virus, IgG-vasta-aineet	Cerebrospinal fluid	
3421	li-infaabg		240	100		Li-Influenssa A -virus, IgG-vasta-aineet	Cerebrospinal fluid	
3422	li-infbabg	eiu	18	0		Li-Influenssa B -virus, IgG-vasta-aineet	Cerebrospinal fluid	
3423	li-infbabg		258	100		Li-Influenssa B -virus, IgG-vasta-aineet	Cerebrospinal fluid	
3424	li-mypnab		614	100		Li-Mycoplasma pneumoniae, vasta-aineet	Cerebrospinal fluid	
3425	li-mypnabg	eiu	32	0		Li-Mycoplasma pneumoniae, IgG-vasta-aineet	Cerebrospinal fluid	
3426	li-mypnabg		1292	100		Li-Mycoplasma pneumoniae, IgG-vasta-aineet	Cerebrospinal fluid	
3427	li-mypnabm		1314	100		Li-Mycoplasma pneumoniae, IgM-vasta-aineet	Cerebrospinal fluid	
3428	li-pin1abg	eiu	7	0		Li-Parainfluenssa 1 -virus, IgG-vasta-aineet	Cerebrospinal fluid	
3429	li-pin1abg		161	100		Li-Parainfluenssa 1 -virus, IgG-vasta-aineet	Cerebrospinal fluid	
3430	ns-infab/r		181	100			Nasal secretion	
3431	ps-adenag		1955	100		Ps-Adenovirus, antigeeni (NPS-näyte)	Pharyngeal secretion	
3432	ps-infaag		11885	100			Pharyngeal secretion	
3433	ps-infbag		11881	100			Pharyngeal secretion	
3434	rvirag-o		340	100				Qualitative test (also semi-quantitative)
3435	s-adenabg	eiu	240	0	[29.8, 39.96, 46.52, 56.21, 66.99, 76.86, 88.44, 100.94, 123.7]	S -Adenovirus, IgG-vasta-aineet	Serum	
3436	s-adenabg		30	96.67		S -Adenovirus, IgG-vasta-aineet	Serum	
3437	s-infaabg	eiu	288	0	[44.84, 67.49, 80.03, 92.84, 100.98, 109.5, 120.03, 134.44, 150.75]	S -Influenssa A -virus, IgG-vasta-aineet	Serum	
3438	s-infaabg	u/ml	31	0		S -Influenssa A -virus, IgG-vasta-aineet	Serum	
3439	s-infaabg		46	71.74		S -Influenssa A -virus, IgG-vasta-aineet	Serum	
3440	s-infbab	eiu	84	0	[37, 45.5, 59.88, 67.83, 76.88, 87.5, 108.12, 125, 142]	S -Influenssa B -virus, vasta-aineet	Serum	
3441	s-infbab	u/ml	20	0		S -Influenssa B -virus, vasta-aineet	Serum	
3442	s-infbab		20	100		S -Influenssa B -virus, vasta-aineet	Serum	
3443	s-infbabg	eiu	202	0	[27.36, 39.2, 49.01, 55.71, 69.1, 81.14, 95.12, 117.99, 145.85]	S-Influenssa B -virus, IgG-vasta-aineet	Serum	
3444	s-infbabg	u/ml	5	0		S-Influenssa B -virus, IgG-vasta-aineet	Serum	
3445	s-infbabg		19	73.68		S-Influenssa B -virus, IgG-vasta-aineet	Serum	
3446	s-infli	mg/l	4337	0.09	[2.45, 4.22, 5.77, 7.21, 8.78, 10.55, 12.36, 14.93, 19.68]	S -Infliksimabi	Serum	
3447	s-infli	ug/l	62	0		S -Infliksimabi	Serum	
3448	s-infli	âug/ml	5	0		S -Infliksimabi	Serum	
3449	s-infli		1486	32.77	[2.05, 3.56, 5.06, 6.2, 7.59, 8.94, 10.97, 13.84, 18.03]	S -Infliksimabi	Serum	
3450	s-infliab	au/ml	413	0.73	[6.57, 14.16, 21.28, 34.4, 52.11, 73.2, 118.89, 190.88, 374.2]	S -Infliksimabi, vasta-aineet	Serum	
3451	s-infliab		4455	99.89		S -Infliksimabi, vasta-aineet	Serum	
3452	s-infliks	mg/l	951	0	[1.81, 3, 4.49, 5.55, 6.66, 8.19, 10.34, 13.5, 19.13]		Serum	
3453	s-infliks		310	30.97	[1.21, 2.24, 3.08, 4.32, 5.17, 6.19, 7.17, 7.95, 9.17]		Serum	
3454	s-inflipa		4630	100			Serum	
3455	s-micfaeg	mg/l	45	0			Serum	
3456	s-micfaeg		90	76.67			Serum	
3457	s-mypnab		19694	99.92		S -Mycoplasma pneumoniae, vasta-aineet	Serum	
3458	s-mypnabg	au/ml	2298	0	[0.52, 1.18, 1.86, 2.68, 3.78, 5.69, 8.99, 16.54, 33.76]	S -Mycoplasma pneumoniae, IgG-vasta-aineet	Serum	
3459	s-mypnabg	eiu	9577	0	[51.21, 64.99, 79.08, 95.09, 113.13, 134.88, 160.85, 200.43, 260.64]	S -Mycoplasma pneumoniae, IgG-vasta-aineet	Serum	
3460	s-mypnabg	form	53	0		S -Mycoplasma pneumoniae, IgG-vasta-aineet	Serum	
3461	s-mypnabg	ru/ml	384	0	[19.56, 23.19, 26.12, 30.65, 34.99, 40.45, 50.94, 60.03, 79.86]	S -Mycoplasma pneumoniae, IgG-vasta-aineet	Serum	
3462	s-mypnabg		4994	100	[0.53, 1.1, 1.73, 2.48, 3.76, 5.77, 9.79, 21.47, 68.82]	S -Mycoplasma pneumoniae, IgG-vasta-aineet	Serum	
3463	s-mypnabm	form	16	0		S -Mycoplasma pneumoniae, IgM-vasta-aineet	Serum	
3464	s-mypnabm	index	3618	0	[1.53, 2.22, 2.83, 3.43, 4.2, 5.16, 6.56, 8.38, 11.18]	S -Mycoplasma pneumoniae, IgM-vasta-aineet	Serum	
3465	s-mypnabm	s/co	1089	0	[0.1, 0.1, 0.2, 0.2, 0.3, 0.33, 0.47, 0.63, 1.13]	S -Mycoplasma pneumoniae, IgM-vasta-aineet	Serum	
3466	s-mypnabm		12775	100	[1.19, 1.67, 2.14, 2.58, 3.04, 3.6, 4.51, 5.78, 8.21]	S -Mycoplasma pneumoniae, IgM-vasta-aineet	Serum	
3467	s-pin1abg	eiu	209	0	[51.38, 65.97, 78.97, 87.7, 96.4, 106.81, 114.5, 126.75, 144.62]	S -Parainfluenssa 1 -virus, IgG-vasta-aineet	Serum	
3468	s-pin1abg		9	88.89		S -Parainfluenssa 1 -virus, IgG-vasta-aineet	Serum	
3469	s-scc-ag	ug/l	959	0	[0.88, 1.03, 1.2, 1.38, 1.6, 2.01, 2.55, 3.56, 6.69]	S -Squamous cell carsinoma, antigeeni	Serum	Antigen
3470	s-scc-ag		493	95.94		S -Squamous cell carsinoma, antigeeni	Serum	Antigen
3471	u-lepnag		3943	100		U -Legionella pneumophila, antigeeni	Urine	
3472	u-pneuag		2058	100			Urine	
3473	u-stpnag		2546	100		U -Streptococcus pneumoniae, antigeeni	Urine	

