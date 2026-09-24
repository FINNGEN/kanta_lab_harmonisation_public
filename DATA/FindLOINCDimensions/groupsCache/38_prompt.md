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
Here is group 38 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
2099	-dpyd		2593	100				
2100	-jo-1		802	100				
2101	-nxp2		839	100				
2102	-sae1		839	100				
2103	-srp		802	100				
2104	-tpmt		2594	100				
2105	ab-k	mmol/l	1089	0	[3.4, 3.63, 3.8, 3.9, 4, 4.1, 4.25, 4.45, 4.82]		Arterial blood	
2106	ab-k		38	2.63			Arterial blood	
2107	ab-t	°c	3430	0	[36.28, 36.54, 36.82, 37, 37, 37.02, 37.28, 37.52, 38.04]		Arterial blood	
2108	ab-t		76	100	[36.18, 36.47, 36.69, 36.92, 37, 37, 37.13, 37.41, 37.81]		Arterial blood	
2109	alb-o		8369	100				Qualitative test (also semi-quantitative)
2110	album	%	20	0				
2111	album	g/l	346	0	[35.22, 38.1, 39.14, 40.4, 41.37, 42.67, 43.87, 45.72, 47.37]			
2112	album	mg/l	113	0				
2113	album		7	28.57				
2114	ap-k	%	24	0				
2115	ap-k	g/l	6	0				
2116	ap-k	kpa	12	0				
2117	ap-k	mmol/l	50274	0	[3.39, 3.58, 3.7, 3.8, 3.9, 4.01, 4.14, 4.31, 4.62]			
2118	ap-k	°c	6	0				
2119	ap-k		219	91.78				
2120	b-k	mmol/l	59422	0	[3.43, 3.6, 3.75, 3.87, 3.99, 4.1, 4.24, 4.43, 4.8]		Blood	
2121	b-k		9739	95.36	[3.58, 3.72, 3.89, 4, 4.09, 4.17, 4.3, 4.41, 4.6]		Blood	
2122	b-nk	e6/l	5955	0	[62.76, 102.11, 137.42, 170.47, 206.55, 246.54, 297.57, 369.07, 511.2]	B -NK-solut	Blood	
2123	b-nk	e9/l	2657	0	[0.06, 0.09, 0.12, 0.15, 0.19, 0.23, 0.28, 0.36, 0.5]	B -NK-solut	Blood	
2124	b-nk		368	72.83		B -NK-solut	Blood	
2125	bup		568	100				
2126	bup10		507	100				
2127	ca++	mmol/l	16710	0	[1.13, 1.16, 1.19, 1.2, 1.22, 1.23, 1.25, 1.27, 1.3]			
2128	ca++		154	95.45				
2129	cerad		262	100				
2130	cp-k	mmol/l	307	0	[3.7, 3.9, 4.08, 4.2, 4.38, 4.51, 4.68, 4.89, 5.2]			
2131	cp-k		18	100				
2132	crp	mg/l	7276	0				
2133	crp		4454	100	[6.33, 8.62, 12.13, 16.34, 21.86, 30.08, 41.76, 58.39, 89.84]			
2134	crp-p	mg/l	1051	0	[6.96, 10.75, 15.42, 21.35, 27.71, 36.11, 49.26, 68.78, 104.31]			Upright (standing)
2135	crp-p		364	100				Upright (standing)
2136	crp-vt		273	25.27	[8.27, 12.35, 16.7, 23.72, 32.56, 45.95, 62.14, 91.02, 118.08]			
2137	du-k	mmol	2083	0.38	[39.08, 49.58, 58.9, 67.76, 76.63, 85.49, 94.91, 108.28, 132.94]	dU-Kalium	24-hour urine	
2138	du-k	mmol/24h	19	0		dU-Kalium	24-hour urine	
2139	du-k		823	74.24	[41.76, 50.17, 57.17, 66.66, 77.31, 88.62, 102.92, 113.9, 131.13]	dU-Kalium	24-hour urine	
2140	fp-k	mmol/l	4399	0	[3.6, 3.76, 3.89, 3.93, 4, 4.1, 4.2, 4.31, 4.5]		Fasting plasma	
2141	gra	%	687	0	[45.93, 50.45, 54.15, 58.32, 61.67, 64.62, 68.13, 72.86, 76.92]			
2142	gra	e9/l	685	0	[2.32, 2.87, 3.33, 3.73, 4.11, 4.49, 4.95, 5.49, 6.39]			
2143	gra		6	100				
2144	gran	%	206	0	[25.16, 33.29, 41.29, 46.14, 51.43, 56.27, 61.52, 67.15, 73.26]			
2145	hb-o		3798	100			Hemoglobin	Qualitative test (also semi-quantitative)
2146	jak1		117	100				
2147	jo-1	u/ml	36	0				
2148	jo-1		1413	100				
2149	jäku		825	100				
2150	leuc		286	100				
2151	leuk	e6	13	0				
2152	leuk	e6/l	7397	0	[0.49, 0.94, 1.25, 2, 3.34, 5.7, 10.85, 24.95, 68.66]			
2153	leuk	u/field	9	0				
2154	leuk		2152	99.91				
2155	leuk-o		8377	100				Qualitative test (also semi-quantitative)
2156	no/an		164	99.39				
2157	nor90		461	100				
2158	nxp2		1337	100				
2159	oxy		221	100				
2160	p-k	mmol/l	7443357	0.03	[3.5, 3.69, 3.8, 3.9, 4, 4.1, 4.2, 4.35, 4.57]	P -Kalium	Plasma	
2161	p-k	mmol/mol	148	0	[3.3, 3.56, 3.73, 3.84, 3.9, 4, 4.1, 4.3, 4.53]	P -Kalium	Plasma	
2162	p-k		95660	100	[3.59, 3.77, 3.9, 4, 4.01, 4.18, 4.3, 4.43, 4.61]	P -Kalium	Plasma	
2163	p-k.	mmol/l	1513	0	[3.51, 3.7, 3.8, 3.93, 4.02, 4.12, 4.21, 4.4, 4.58]		Plasma	
2164	p-k:	mmol/l	625	0	[3.54, 3.7, 3.9, 4, 4.15, 4.29, 4.46, 4.6, 4.94]		Plasma	
2165	p-kp	mmol/l	346	0	[3.42, 3.59, 3.7, 3.8, 3.9, 4, 4.13, 4.3, 4.59]		Plasma	
2166	pad		414	100				
2167	pad1		2805	100				
2168	pax6	u/ml	17	0				
2169	pax6		84	2.38	[0, 0, 0, 0, 0, 0, 0, 0, 0]			
2170	prom	%	5957	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]			
2171	prom		5	100	[0, 0, 0, 0, 0, 0, 0, 0, 0]			
2172	rp11		461	100				
2173	rp155		461	100				
2174	s-k	mmol/l	140164	0	[3.84, 4, 4.1, 4.19, 4.2, 4.3, 4.4, 4.5, 4.61]	S -Kalium	Serum	
2175	s-k		1177	70.77	[3.94, 4.09, 4.1, 4.2, 4.29, 4.35, 4.46, 4.59, 4.7]	S -Kalium	Serum	
2176	sae1		1337	100				
2177	sao2	%	159	0				
2178	sao2		2620	22.82	[93.95, 95.44, 96.03, 97, 97.93, 98, 98, 98, 99]			
2179	srp		1338	100				
2180	tark1		1834	100				
2181	tark2		4295	100				
2182	tark2b		16327	100				
2183	tark4		427	100				
2184	trim		179	100				
2185	u-k	mmol/l	3543	0.37	[12.45, 16.99, 21.48, 26.58, 31.78, 37.57, 44.19, 53.53, 70.78]	U -Kalium	Urine	
2186	u-k		460	23.04	[12.73, 17, 20.65, 23.88, 28.37, 33.93, 38.91, 48.79, 60.27]	U -Kalium	Urine	
2187	u-oxy		145	100			Urine	
2188	v-k		265	0.75	[3.39, 3.62, 3.75, 3.89, 4, 4.1, 4.2, 4.35, 4.64]			
2189	vp-k	mmol/l	10893	0	[3.58, 3.77, 3.9, 4, 4.1, 4.2, 4.31, 4.48, 4.72]			
2190	vp-k		176	98.3				

