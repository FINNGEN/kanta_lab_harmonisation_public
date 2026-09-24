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
Here is group 47 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
3097	-alb	g/l	89	0	[6.6, 10.91, 12.26, 13.98, 17.03, 20.17, 24.01, 27.44, 30.1]			
3098	-alb		15	66.67				
3099	-ej-ab		802	100				Antibodies
3100	-ld	u/l	104	0	[118, 149.8, 173.07, 199.52, 251, 301.96, 561.56, 1225.27, 2355]			
3101	-ld		14	57.14				
3102	-oj-ab		802	100				Antibodies
3103	ab-be	%	24	0		aBE-emäsylimäärä	Arterial blood	
3104	ab-be	g/l	9	0		aBE-emäsylimäärä	Arterial blood	
3105	ab-be	kpa	18	0		aBE-emäsylimäärä	Arterial blood	
3106	ab-be	ml	33	0		aBE-emäsylimäärä	Arterial blood	
3107	ab-be	mmol/l	383270	0	[-4.56, -2.34, -0.92, 0.19, 1, 1.86, 2.86, 4.15, 6.27]	aBE-emäsylimäärä	Arterial blood	
3108	ab-be	°c	9	0		aBE-emäsylimäärä	Arterial blood	
3109	ab-be		6940	100	[-7.25, -4.9, -3.67, -2.81, -2.17, -1.62, -1.15, -0.7, -0.3]	aBE-emäsylimäärä	Arterial blood	
3110	ab-chb	g/l	1200	0	[108.39, 116.66, 121.94, 126.8, 130.47, 135.93, 140.06, 145.4, 151.9]		Arterial blood	
3111	ab-chb		28	100			Arterial blood	
3112	ab-hb	g/l	300767	0	[87.28, 93.45, 98.67, 103.77, 109.28, 115.36, 121.97, 129.42, 139.82]		Arterial blood	
3113	ab-hb		9282	99.8			Arterial blood	
3114	ab-sbc	mmol/l	138	0	[22.53, 23.61, 24.26, 24.79, 25.6, 26.01, 26.74, 27.94, 29.39]		Arterial blood	
3115	ab-thb	%	24	0			Arterial blood	
3116	ab-thb	g/l	48641	0	[87.03, 94.57, 101.05, 107.55, 114.03, 120.66, 127.54, 136.13, 146.87]		Arterial blood	
3117	ab-thb	kpa	18	0			Arterial blood	
3118	ab-thb	mmol/l	54	0			Arterial blood	
3119	ab-thb	°c	9	0			Arterial blood	
3120	ab-thb		229	92.14			Arterial blood	
3121	ab-thb-	g/l	164	0			Arterial blood	
3122	as-alb	g/l	1146	1.31	[4.05, 5.66, 7.32, 9.54, 12.89, 15.83, 18.22, 20.9, 23.77]	As-Albumiini	Ascitic fluid	
3123	as-alb	mg/l	28	0		As-Albumiini	Ascitic fluid	
3124	as-alb		372	88.71		As-Albumiini	Ascitic fluid	
3125	as-ld	u/l	128	2.34	[39.38, 56.23, 71.22, 80.63, 96.67, 119, 149.5, 238.17, 473.38]	As-Laktaattidehydrogenaasi	Ascitic fluid	
3126	as-ld		22	68.18		As-Laktaattidehydrogenaasi	Ascitic fluid	
3127	as-ly	%	140	0	[8.62, 17.02, 23.6, 32.15, 39, 48.09, 59.59, 69.7, 84.65]		Ascitic fluid	
3128	as-ly		9	77.78			Ascitic fluid	
3129	b-be	mmol/l	36179	1.76	[0.5, 1.07, 1.65, 2.29, 3.01, 3.87, 5.03, 6.62, 9.2]		Blood	
3130	b-be		657	100	[-7.51, -5.51, -4.28, -3.35, -2.57, -1.96, -1.39, -0.87, -0.4]		Blood	
3131	b-gal	mmol/l	1067	0	[0.25, 0.3, 0.53, 0.74, 1.02, 1.36, 2.1, 2.8, 3.25]	B -Galaktoosi	Blood	
3132	b-gal		10	100		B -Galaktoosi	Blood	
3133	b-hb	e12/l	14	0		B -Hemoglobiini	Blood	
3134	b-hb	e9/l	525	0	[105.05, 112.99, 120.66, 126.61, 131.9, 137, 141.4, 146.06, 153.19]	B -Hemoglobiini	Blood	
3135	b-hb	form	34	0		B -Hemoglobiini	Blood	
3136	b-hb	g/l	10951518	0.02	[98.65, 110.23, 118.71, 125.05, 130.33, 134.98, 139.62, 144.85, 152.03]	B -Hemoglobiini	Blood	
3137	b-hb	mg/l	9	0		B -Hemoglobiini	Blood	
3138	b-hb		89285	100	[107.14, 118.09, 125.19, 130.57, 135, 139.24, 143.7, 148.9, 155.71]	B -Hemoglobiini	Blood	
3139	b-hb:	g/l	625	0	[91.67, 100.75, 109.05, 114.62, 119.62, 125.23, 131.9, 139.09, 148.2]		Blood	
3140	b-hbp	g/l	6699	0	[122.34, 128.84, 133.18, 136.43, 139.86, 143.38, 146.76, 151.24, 157.69]		Blood	
3141	b-hbp		10	100			Blood	
3142	b-hbs	%	154	0		B -Hemoglobiini S, osuus	Blood	
3143	b-hhb	%	580	0	[0.38, 0.85, 1.32, 1.89, 2.49, 3.4, 4.56, 6.17, 9.24]		Blood	
3144	b-hhb		44	4.55			Blood	
3145	b-la	form	155	0	[2, 2, 3, 4.75, 5.86, 7, 8.62, 13, 16.33]	B -Lasko	Blood	
3146	b-la	mm	62	0		B -Lasko	Blood	
3147	b-la	mm/h	1389512	0.01	[2, 3.64, 5, 6.97, 8.81, 12.15, 16.49, 24.43, 37.82]	B -Lasko	Blood	
3148	b-la	mm/l	9	0		B -Lasko	Blood	
3149	b-la	mmol	365	0	[3.04, 5.89, 7, 9.61, 11.08, 14.57, 21.11, 26.25, 39.92]	B -Lasko	Blood	
3150	b-la		18699	100	[2, 3.97, 5.45, 6.97, 8.53, 11.51, 14.63, 20.39, 33.72]	B -Lasko	Blood	
3151	b-lap	mm/h	2727	0	[2, 3.02, 4.7, 5.05, 6.79, 8.07, 10.15, 14.47, 22.74]		Blood	
3152	b-lt	e9/l	1315	0	[1.92, 2.35, 2.73, 3.11, 3.51, 3.9, 4.43, 5.26, 6.63]		Blood	
3153	b-ly	%	20882	0	[18.14, 22.54, 25.67, 28.15, 30.52, 32.89, 35.44, 38.54, 43.23]	B -Lymfosyytit	Blood	
3154	b-ly	e9/l	1121029	0	[0.88, 1.16, 1.37, 1.56, 1.74, 1.94, 2.17, 2.47, 2.94]	B -Lymfosyytit	Blood	
3155	b-ly		8120	100	[0.35, 1.05, 1.3, 1.55, 1.79, 2.03, 2.27, 2.72, 3.93]	B -Lymfosyytit	Blood	
3156	b-ly-s		166	100		B -Lymfosyytit, stimulaatiokoe	Blood	Stimulation, stimulated
3157	b-lym	%	2560	0	[15.82, 19.59, 23.06, 26.46, 29.23, 32.02, 35.59, 39.74, 45.65]		Blood	
3158	b-lym	e9/l	2469	0	[0.98, 1.22, 1.42, 1.62, 1.82, 2.05, 2.32, 2.66, 3.23]		Blood	
3159	b-lym		13	0			Blood	
3160	b-lyp	%	174	0	[17.5, 22.11, 26.31, 29.51, 32.87, 35.82, 38.98, 42.56, 46.33]		Blood	
3161	b-ly␤	e9/l	293	0			Blood	
3162	b-nil		4576	100			Blood	
3163	b-pb	ug/l	30	0		B -Lyijy	Blood	
3164	b-pb	umol/l	207	0	[0.07, 0.09, 0.12, 0.14, 0.16, 0.19, 0.26, 0.44, 0.86]	B -Lyijy	Blood	
3165	b-pb		379	98.68		B -Lyijy	Blood	
3166	b-tb1	iu/ml	10	0			Blood	
3167	b-tb1		4742	100			Blood	
3168	b-tb2	iu/ml	10	0			Blood	
3169	b-tb2		4743	100			Blood	
3170	b-thb	g/l	11963	2.4	[93.27, 103.64, 112.18, 119.83, 126.7, 133.17, 139.64, 146.36, 155.86]		Blood	
3171	b-thb		192	93.23			Blood	
3172	b-ti	ug/l	599	0	[2.2, 2.3, 2.47, 2.61, 2.82, 3.2, 3.72, 4.38, 6.57]	B -Titaani	Blood	
3173	b-ti		947	97.89	[2.1, 2.29, 2.47, 2.69, 2.96, 3.21, 3.59, 4.21, 5.62]	B -Titaani	Blood	
3174	bl-alb	mg/l	81	0	[10, 21.6, 32.4, 48.75, 57.13, 78.12, 92, 145, 348.5]		Bronchoalveolar lavage	
3175	bl-alb		37	16.22			Bronchoalveolar lavage	
3176	bla	%	4767	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]			
3177	bla		6	100	[0, 0, 0, 0, 0, 0, 0, 0, 0]			
3178	bodypl		319	100		Bodyplethysmografia		
3179	brdil		423	99.76		Bronkodilaatiokoe, spirometria tai PEF		
3180	cb-be	mmol/l	100517	0	[-2.78, -0.21, 0.65, 1.3, 2, 2.79, 3.8, 5.21, 7.71]	cBE-emäsylimäärä	Capillary blood	
3181	cb-be		1256	100	[-6.67, -4.64, -3.33, -2.4, -1.64, -0.99, -0.58, -0.19, 2.15]	cBE-emäsylimäärä	Capillary blood	
3182	cb-chb	g/l	262	0	[108.49, 116.85, 123.64, 127, 132.85, 139.24, 143.58, 152, 160.14]		Capillary blood	
3183	cb-chb		16	100			Capillary blood	
3184	cb-hb	g/l	16424	0	[97.59, 107.14, 114.8, 121.52, 127.83, 134.1, 140.36, 147.36, 157.23]		Capillary blood	
3185	cb-hb		2532	100	[92.56, 101.33, 108.18, 114.57, 120.84, 126.31, 132.07, 139.56, 149.8]		Capillary blood	
3186	cb-sbc	mmol/l	461	0	[17.87, 19.1, 20.07, 21.07, 21.89, 22.87, 23.66, 24.81, 26.29]		Capillary blood	
3187	cu-alb	ug/min	7167	0	[3.78, 6.42, 10.51, 17.58, 29.07, 49.07, 84.18, 162.62, 430]	cU-Albumiini	Collected urine	
3188	cu-alb		6738	100	[3.02, 5.18, 8.57, 15.14, 26.33, 47.05, 85.22, 170.28, 422.86]	cU-Albumiini	Collected urine	
3189	du-alb	mg	1210	0	[6.96, 10.01, 16.41, 32.97, 57.55, 104.7, 173.89, 375.88, 1231.9]	dU-Albumiini	24-hour urine	
3190	du-alb	mg/24h	64	0		dU-Albumiini	24-hour urine	
3191	du-alb		480	83.75	[8, 17, 41.3, 82.8, 136, 251.4, 381.93, 652, 1303]	dU-Albumiini	24-hour urine	
3192	ej-ab		1338	100				Antibodies
3193	f-hhb	ug/g	363	0	[15.48, 17.09, 19.71, 22.48, 27.94, 36.06, 52.26, 77.55, 120.81]	F -Hemoglobiini, ihmisen (kvant)	Feces	
3194	f-hhb		5539	99.95		F -Hemoglobiini, ihmisen (kvant)	Feces	
3195	l-ly	%	142328	0	[13, 18.15, 22.01, 25.33, 28.32, 31.37, 34.68, 38.7, 44.94]		Leukocyte	
3196	l-ly	e9/l	4253	0	[1.11, 1.33, 1.52, 1.69, 1.84, 2, 2.2, 2.48, 2.92]		Leukocyte	
3197	l-ly		4310	100	[1.08, 1.41, 1.65, 1.84, 2.02, 2.22, 2.54, 2.93, 13.04]		Leukocyte	
3198	l-lym	%	167	0	[18.29, 23.62, 26.49, 28.7, 30.36, 32.99, 35.77, 39.85, 44.08]		Leukocyte	
3199	l-ly␤	%	1080	0			Leukocyte	
3200	l-ly␤		65	4.62			Leukocyte	
3201	li-ly	%	341	0	[5.92, 11.12, 18.39, 29.28, 44.89, 62.35, 74.18, 86.06, 91.15]		Cerebrospinal fluid	
3202	li-ly		224	100			Cerebrospinal fluid	
3203	li-lzm	mg/l	165	0.61	[0.02, 0.02, 0.03, 0.03, 0.04, 0.04, 0.05, 0.06, 0.1]	Li-Lysotsyymi	Cerebrospinal fluid	
3204	li-lzm		36	97.22		Li-Lysotsyymi	Cerebrospinal fluid	
3205	mb-be	mmol/l	2347	0	[0.01, 0.32, 0.63, 0.97, 1.37, 1.83, 2.48, 3.23, 4.35]			
3206	mb-be		794	12.97	[-5.12, -3.49, -2.7, -2.17, -1.71, -1.32, -1.02, -0.66, -0.4]			
3207	mb-hb	g/l	3080	0	[90.39, 95.45, 99.86, 103.58, 106.95, 110.5, 114.28, 119.46, 126.85]			
3208	mb-hb		105	100				
3209	nu-alb	ug/min	1954	0	[3.15, 6.47, 8.51, 11.66, 14.65, 17.96, 26.62, 76.95, 187.42]		Night (morning) urine	
3210	nu-alb		1723	100	[1.48, 2.49, 4.2, 8.53, 19.33, 34.44, 55.11, 101.57, 233.51]		Night (morning) urine	
3211	oj-ab		1337	100				Antibodies
3212	p-alb	g/l	922759	0.01	[24.72, 28.89, 31.9, 33.92, 35.38, 36.98, 38.03, 39.47, 41.07]	P -Albumiini	Plasma	
3213	p-alb		26273	100	[30.25, 33.46, 35, 36.01, 37, 37.92, 38.28, 39, 40.98]	P -Albumiini	Plasma	
3214	p-hb	g/l	34	0		P -Hemoglobiini	Plasma	
3215	p-hb	mg/l	8510	0.12	[30.87, 39.65, 46.44, 52.83, 60.45, 68.8, 79.76, 96.29, 133.45]	P -Hemoglobiini	Plasma	
3216	p-hb		824	53.03	[109.18, 118.7, 127.38, 134.78, 140.4, 145.95, 149.76, 154.35, 160.1]	P -Hemoglobiini	Plasma	
3217	p-ld	u/l	221648	0.04	[166.3, 183.82, 198.01, 211.69, 226.22, 244.13, 269.01, 310.07, 413.93]	P -Laktaattidehydrogenaasi	Plasma	
3218	p-ld		2953	100	[161.83, 180.17, 192.94, 205.06, 220.7, 240.56, 259.25, 311.25, 389.3]	P -Laktaattidehydrogenaasi	Plasma	
3219	p-lh	u/l	4779	0	[2.72, 4, 5.03, 6.01, 7.22, 8.74, 11.35, 16.9, 31.3]	P -Luteinisoiva hormoni	Plasma	
3220	p-lh		1068	18.91	[2.74, 3.88, 4.93, 5.73, 6.87, 8.26, 10.38, 15.33, 27.39]	P -Luteinisoiva hormoni	Plasma	
3221	pd-ly	%	151	0			Peritoneal dialysis fluid	
3222	pd-ly		6	100			Peritoneal dialysis fluid	
3223	pf-alb	g/l	413	0.97	[8.18, 10.48, 12.74, 15, 17.54, 20.15, 22.34, 24.35, 27.01]	Pf-Albumiini	Pleural fluid	
3224	pf-alb	mg/l	9	0		Pf-Albumiini	Pleural fluid	
3225	pf-alb		41	95.12		Pf-Albumiini	Pleural fluid	
3226	pf-ld	u/l	4785	0.17	[73.14, 95.27, 121.48, 152.81, 193.16, 248.79, 336.37, 491.14, 875.24]	Pf-Laktaattidehydrogenaasi	Pleural fluid	
3227	pf-ld		337	90.8		Pf-Laktaattidehydrogenaasi	Pleural fluid	
3228	pf-ly	%	490	0	[9.01, 19.16, 32.74, 47.68, 58.07, 69.92, 77.91, 87.4, 92.94]		Pleural fluid	
3229	pf-ly		14	92.86			Pleural fluid	
3230	pf-lzm	mg/l	380	0.53	[1.06, 1.43, 2.16, 6.83, 9.43, 11.17, 13, 15.54, 19.9]	Pf-Lysotsyymi	Pleural fluid	
3231	pf-lzm		28	85.71		Pf-Lysotsyymi	Pleural fluid	
3232	s-alb	%	12	0		S -Albumiini	Serum	
3233	s-alb	g/l	24325	0	[33.85, 36.65, 38.02, 39.05, 40.03, 41.01, 42.02, 43.16, 44.95]	S -Albumiini	Serum	
3234	s-alb	mg/g	7	0		S -Albumiini	Serum	
3235	s-alb		167	100	[31.82, 34.76, 36.27, 37.4, 38.35, 39.31, 40.66, 42.03, 43.83]	S -Albumiini	Serum	
3236	s-ld	u/l	5177	0	[143.48, 158.5, 170.01, 181.21, 192.56, 206.29, 223.72, 247.14, 306.88]	S -Laktaattidehydrogenaasi	Serum	
3237	s-ld	u/ml	8	0		S -Laktaattidehydrogenaasi	Serum	
3238	s-ld		37	81.08		S -Laktaattidehydrogenaasi	Serum	
3239	s-lh	iu/l	8500	0	[1.4, 2.2, 2.87, 3.57, 4.35, 5.35, 6.95, 10.67, 21.28]	S -Luteinisoiva hormoni	Serum	
3240	s-lh	u/l	7219	1.77	[2.14, 3.16, 3.98, 4.77, 5.68, 6.78, 8.31, 11.14, 20.21]	S -Luteinisoiva hormoni	Serum	
3241	s-lh		2083	67.21	[1.85, 2.92, 3.86, 4.89, 6, 7.78, 10.11, 15.24, 24.89]	S -Luteinisoiva hormoni	Serum	
3242	s-li	mmol/l	38227	0.03	[0.39, 0.49, 0.54, 0.6, 0.68, 0.71, 0.8, 0.88, 1]	S -Litium	Serum	
3243	s-li		1638	100	[0.4, 0.5, 0.57, 0.61, 0.7, 0.73, 0.8, 0.9, 1]	S -Litium	Serum	
3244	s-lzm	mg/l	25727	0.02	[1.83, 8.01, 10.02, 11.13, 12.2, 13.35, 14.73, 16.22, 19.22]	S -Lysotsyymi	Serum	
3245	s-lzm		301	100	[5.25, 7.5, 8.71, 9.97, 10.96, 12.01, 13.32, 15.16, 18.43]	S -Lysotsyymi	Serum	
3246	sy-ly	%	1170	0	[2, 4.15, 6.74, 10.67, 17.08, 25.7, 37.99, 54.24, 74.6]	Sy-Lymfosyytit	Synovial fluid	
3247	sy-ly		169	36.69	[2, 3, 5.97, 10.53, 16.33, 21.8, 28.77, 47.8, 71]	Sy-Lymfosyytit	Synovial fluid	
3248	u-alb	mg/l	301208	0.25	[3.59, 4.97, 6.33, 8.83, 13.1, 21.67, 42.84, 104.11, 340.4]	U -Albumiini	Urine	
3249	u-alb		156359	100	[3.69, 4.64, 5.71, 7.02, 9.01, 12.39, 19.56, 36.01, 91.71]	U -Albumiini	Urine	
3250	u-hb	mg/l	6	0		U -Hemoglobiini	Urine	
3251	u-hb		97	91.75		U -Hemoglobiini	Urine	
3252	ua-be	mmol/l	119	0	[-7.1, -5.29, -3.83, -2.48, -1.1, -0.1, 0.28, 0.61, 1.56]		Umbilical artery blood	
3253	ua-be		329	2.74	[-8.26, -6.75, -5.76, -4.56, -3.73, -2.83, -2.18, -1.65, -0.95]		Umbilical artery blood	
3254	ua-hb	g/l	180	0	[140.5, 147.35, 154.8, 161.12, 164.85, 169.44, 175.08, 180.14, 187]		Umbilical artery blood	
3255	uv-be	mmol/l	39	0			Umbilical venous blood	
3256	uv-be		125	4	[-7.8, -6.3, -4.84, -3.9, -3.42, -2.98, -2.29, -1.45, -0.93]		Umbilical venous blood	
3257	v-hb		253	17	[109, 119.3, 126.47, 133.15, 136.67, 143, 150.27, 155.87, 163.67]			
3258	vb-be	mmol/l	173549	0	[-3.32, -0.95, 0.32, 0.98, 1.65, 2.35, 3.14, 4.19, 5.91]	vBE-emäsylimäärä	Venous blood	
3259	vb-be		1935	100	[0.8, 1.35, 2, 2.9, 3.73, 5.52, 6.6, 8.3, 10]	vBE-emäsylimäärä	Venous blood	
3260	vb-hb	g/l	61616	0	[88.71, 96.2, 102.39, 108.71, 115.54, 123.28, 131.86, 140.6, 151.28]		Venous blood	
3261	vb-hb		2868	96.13	[113, 121, 128.85, 131.29, 135.17, 137.78, 140.15, 145.6, 154]		Venous blood	
3262	vb-thb	g/l	31104	0	[95.85, 106.03, 114.04, 121.36, 128.03, 134.48, 140.62, 147.28, 155.77]		Venous blood	
3263	vb-thb		297	79.46			Venous blood	
3264	zb-be	mmol/l	4875	0	[0.35, 0.78, 1.2, 1.75, 2.28, 2.96, 3.79, 5.01, 7.48]		Central blood	
3265	zb-be		694	100	[-6.05, -4.14, -3.17, -2.59, -2.03, -1.55, -1.15, -0.74, -0.4]		Central blood	

