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
Here is group 37 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1985	-nt	mm	16796	0	[0.88, 1, 1.1, 1.19, 1.27, 1.34, 1.47, 1.6, 1.83]			
1986	-nt		965	100	[0.79, 0.9, 1, 1.08, 1.16, 1.23, 1.34, 1.5, 1.74]			
1987	NA	%	6666	0				
1988	NA	e12/l	2192	0				
1989	NA	e6/l	213	0				
1990	NA	e9/l	6742	0				
1991	NA	eiu	15	0				
1992	NA	fl	2362	0				
1993	NA	g/l	5079	0				
1994	NA	iu/l	28	0				
1995	NA	iu/ml	43	0				
1996	NA	mg	17	0				
1997	NA	mg/l	1610	0				
1998	NA	mg/mmol	148	0				
1999	NA	ml/min/173m2	19	0				
2000	NA	mm/h	359	0				
2001	NA	mmol	5	0				
2002	NA	mmol/l	8633	0				
2003	NA	mmol/m	662	0				
2004	NA	mosm/k	76	0				
2005	NA	mu/l	1133	0				
2006	NA	ng/l	158	0				
2007	NA	nmol/l	172	0				
2008	NA	pg	2333	0				
2009	NA	pmol/l	835	0				
2010	NA	s	12	0				
2011	NA	titre	13	0				
2012	NA	u/l	2435	0				
2013	NA	u/ml	47	0				
2014	NA	ug/g	27	0				
2015	NA	ug/l	580	0				
2016	NA	umol/l	2399	0				
2017	NA		11399	69.66				
2018	acl		217	100				
2019	amp		160	100				
2020	cd4	%	1036	0	[16.43, 20.4, 25.06, 31.52, 37.8, 43.85, 48.79, 54.06, 60.81]			
2021	cd4	%/lumf	1920	0	[13.65, 19.4, 24.92, 29.69, 35.31, 40.77, 46.19, 51.33, 58.39]			
2022	cd4		132	65.91				
2023	coc		122	100				
2024	cpd		179	100				
2025	ekg		1931	92.96	[3916519.15, 7000419.24, 9162873.91, 11368907.08, 13647732.14, 16151160.41, 19924416.24, 23767350.87, 27255268.62]			
2026	eo		116	0	[1.09, 1.4, 1.9, 2.29, 2.8, 3.42, 4.02, 5.34, 7.39]			
2027	eos	%	64249	0	[0.01, 1, 1.84, 2, 2.89, 3, 4, 4.95, 6.42]			
2028	eos	e9/l	4350	0	[0, 0, 0.01, 0.07, 0.11, 0.16, 0.21, 0.28, 0.41]			
2029	eos		217	100	[0, 1, 1, 1.5, 2, 2, 3, 3.92, 5]			
2030	fev		178	41.01	[55.33, 62.75, 69, 71.73, 74, 75.27, 78, 80.67, 84]			
2031	fev1	%	30	0				
2032	fev1	l	23	0				
2033	fev1		217	51.61	[49, 58.83, 70.38, 74.47, 78.67, 84.25, 87, 93, 103.33]			
2034	fvc	l	24	0				
2035	fvc		198	46.46	[63.73, 72.7, 78.2, 82.6, 86.27, 91.72, 95.66, 101, 107]			
2036	fyl		223	100				
2037	hb	g/l	17	0				
2038	hb		963	0.62	[101.82, 112.11, 119.68, 124.64, 129.13, 134.37, 138.45, 143.37, 149.11]			
2039	hcov		102	100				
2040	hct	%	3086	0	[0.34, 0.36, 0.38, 0.39, 0.4, 0.42, 0.43, 0.44, 0.46]			
2041	hct		87	5.75	[0.32, 0.35, 0.36, 0.38, 0.4, 0.41, 0.44, 18.05, 39]			
2042	hgb	g/l	3106	0	[113.81, 122.39, 127.59, 131.39, 135.33, 139.35, 143.58, 148.07, 154.59]			
2043	kef		179	100				
2044	kt/v		1964	0.36	[1.14, 1.26, 1.32, 1.37, 1.42, 1.46, 1.51, 1.56, 1.64]			
2045	l-nlt	%	9569	0	[24.72, 37.74, 46.27, 53.05, 59.05, 64.98, 70.33, 76.47, 83.27]		Leukocyte	
2046	l-nlt		27	100	[15.33, 30.3, 39.59, 44.18, 49.62, 55.18, 60.75, 68.27, 76.6]		Leukocyte	
2047	l-nst	%	9085	0	[0, 0, 0, 0, 0.99, 1, 1.28, 2.37, 4.8]		Leukocyte	
2048	l-nst		144	100	[0, 1, 1, 1.98, 2.11, 3, 4.11, 6, 8.96]		Leukocyte	
2049	mch	pg	32	0				
2050	mch		70	0	[28.55, 29, 29.9, 30, 30.4, 31, 31.23, 32, 32]			
2051	mchc	g/l	101	0	[324, 329.8, 333, 335.84, 337.93, 340.12, 342, 345.43, 349]			
2052	mchc		143	1.4	[314.38, 323.15, 326.48, 330.6, 332.89, 336.29, 339, 341.18, 345]			
2053	mes		179	100				
2054	met		179	100				
2055	mns	%	204	0	[28.05, 33.04, 38.87, 43.95, 48.83, 53.98, 58.74, 66.86, 74.84]			
2056	mpd		314	100				
2057	mtd		147	100				
2058	muut	%	8051	0	[3.99, 4, 4.99, 5, 5.42, 6, 6.98, 8.34, 11.8]			
2059	muut		111	87.39				
2060	mxd	%	14329	0	[6.67, 8.18, 9.34, 10.26, 11.17, 12.1, 13.16, 14.52, 16.69]			
2061	mxd		26	100				
2062	myel	%	5976	0	[0, 0, 0, 0, 0, 0.01, 1, 1.41, 2.93]			
2063	myel		5	100	[0, 0, 0, 0, 0, 0, 0, 0.61, 2]			
2064	neut	%	74099	0	[43.39, 48.8, 52.52, 55.82, 58.78, 61.95, 65.39, 69.49, 75.45]			
2065	neut	e9/l	4350	0	[1.91, 2.48, 2.97, 3.45, 3.92, 4.45, 5.11, 5.91, 7.29]			
2066	neut		274	100	[38.87, 47.31, 50.3, 53.18, 55.36, 59.26, 61.66, 66.07, 74.74]			
2067	nlt	%	5883	0	[25, 40.22, 47.63, 52.72, 57.61, 62.03, 67.09, 72.69, 80.33]			
2068	nlt		9	100	[21.08, 33.74, 42.02, 48.46, 52.86, 57.31, 62.41, 68.36, 74.63]			
2069	nst	%	4682	0	[0, 0, 0, 0, 0.71, 1, 1.39, 2.27, 4.95]			
2070	nst		7	100	[0, 0, 0, 0, 0, 1, 1, 1.91, 3.21]			
2071	nt-		3322	4.36	[0.87, 1, 1.04, 1.11, 1.21, 1.3, 1.4, 1.55, 1.78]			
2072	pef	l/min	5	0		Uloshengityksen huippuvirtaus		
2073	pef	ml	10	0		Uloshengityksen huippuvirtaus		
2074	pef		847	96.46		Uloshengityksen huippuvirtaus		
2075	pgb		280	100				
2076	ph	form	10	0				
2077	ph		165614	0.64	[7.33, 7.35, 7.36, 7.37, 7.38, 7.39, 7.41, 7.42, 7.44]			
2078	plt	e9/l	3107	0	[172.85, 195.73, 212.7, 228.04, 243.51, 260.84, 279.95, 305.12, 350.81]			
2079	pt-v		903	100			Patient	Free or unconjugated
2080	rdw	%	6273	0	[12, 12.9, 13, 13, 13, 13, 13.99, 14, 14.86]			
2081	rdw		119	10.92	[12.73, 13, 13, 13, 13, 13, 13.93, 14, 14]			
2082	rr	mmhg	9	0		Verenpaine		
2083	rr		7436	100		Verenpaine		
2084	s-gt	iu/l	216	0	[12.9, 16, 17.77, 20, 22.48, 27.81, 33.78, 46.38, 95.18]	S -Glutamyylitransferaasi	Serum	
2085	s-gt	u/i	5	0		S -Glutamyylitransferaasi	Serum	
2086	s-gt	u/l	178336	0	[12.76, 15.82, 18.85, 22.34, 26.84, 32.64, 41.22, 55.38, 86.26]	S -Glutamyylitransferaasi	Serum	
2087	s-gt		1233	43.96	[11.98, 15.46, 18.56, 21.71, 25.52, 30.12, 38.87, 53.85, 83.88]	S -Glutamyylitransferaasi	Serum	
2088	s-nt	mm	769	0	[1, 1.15, 1.26, 1.33, 1.42, 1.5, 1.62, 1.76, 1.91]		Serum	
2089	tb1	iu/ml	121	0	[0.42, 0.51, 0.59, 0.7, 0.93, 1.35, 2.21, 3.13, 5.04]			
2090	tb1		5810	98.24	[0.43, 0.61, 0.76, 0.89, 1.31, 1.87, 2.77, 3.86, 6.35]			
2091	tb2	iu/ml	133	0	[0.42, 0.48, 0.58, 0.67, 0.81, 1.16, 1.88, 3.21, 4.86]			
2092	tb2		5755	98.07	[0.4, 0.47, 0.6, 0.89, 1.24, 1.78, 2.74, 3.86, 5.57]			
2093	th/to		461	100				
2094	thc		217	100				
2095	thc50		507	100				
2096	tir		168	0.6				
2097	tml		255	100				
2098	työt		534	100				

