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
Here is group 39 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
2191	-lymph	%	1159	0	[0.17, 0.22, 0.25, 0.27, 0.3, 0.32, 0.35, 0.38, 0.43]			
2192	-mda5		839	100				
2193	-mi-2a		839	100				
2194	-mi-2b		839	100				
2195	-tif1y		839	100				
2196	amp300		507	100				
2197	b-mcv	fl	1253	0	[84.82, 86.45, 87.96, 89, 90, 91, 92, 93.17, 95]		Blood	
2198	b-mpadp	u	874	0.46	[15.09, 19.7, 24.88, 29.52, 36.77, 43.72, 52.21, 64.6, 79.59]		Blood	
2199	b-mpadp		29	44.83			Blood	
2200	b-muubat	%	126	0	[1.3, 1.7, 1.76, 2, 2.12, 2.43, 2.9, 3.56, 4.1]		Blood	
2201	b-muubat		65	24.62			Blood	
2202	b-muut	e9/l	3089	0	[0.25, 0.3, 0.4, 0.42, 0.5, 0.54, 0.6, 0.7, 0.84]		Blood	
2203	b-mxa	ug/l	434	0.92	[37.35, 102.65, 210.12, 310.9, 413.82, 497.34, 584, 655.31, 728.74]	B -MxA -proteiini	Blood	
2204	b-mxa		357	97.48		B -MxA -proteiini	Blood	
2205	b-mxd	%	437	0	[0.08, 0.09, 0.1, 0.1, 0.11, 0.12, 0.14, 7.69, 10.4]		Blood	
2206	b-mxd	e9/l	3612	0	[0.49, 0.53, 0.6, 0.7, 0.72, 0.8, 0.9, 1, 1.2]		Blood	
2207	b-mxd		6	100			Blood	
2208	b-mxdp	%	183	0	[4.76, 6.02, 7.3, 8, 9, 10, 11, 12, 14.49]		Blood	
2209	bzd300		506	100				
2210	coc300		507	100				
2211	dmpak		141	100				
2212	dmvuk		109	100				
2213	e-mch	e9/l	6	0		E -Hemoglobiini, keskimassa	Erythrocyte	
2214	e-mch	fl	322	0	[29, 29, 30, 30, 30.2, 31, 31, 32, 32]	E -Hemoglobiini, keskimassa	Erythrocyte	
2215	e-mch	form	34	0		E -Hemoglobiini, keskimassa	Erythrocyte	
2216	e-mch	g/l	118	0	[27.6, 28.51, 28.94, 29.78, 30.24, 30.62, 31.05, 31.5, 263.36]	E -Hemoglobiini, keskimassa	Erythrocyte	
2217	e-mch	osuus	7	0		E -Hemoglobiini, keskimassa	Erythrocyte	
2218	e-mch	pg	10891948	0.03	[27.78, 29, 29.01, 30, 30, 31, 31.01, 32, 33]	E -Hemoglobiini, keskimassa	Erythrocyte	
2219	e-mch	pg/cell	21286	0	[27.4, 28.6, 29.24, 29.82, 30.17, 30.67, 31.06, 31.66, 32.42]	E -Hemoglobiini, keskimassa	Erythrocyte	
2220	e-mch		90356	100	[28, 29, 29.18, 30, 30, 30.98, 31, 31.85, 32.32]	E -Hemoglobiini, keskimassa	Erythrocyte	
2221	e-mchc	%	8	0		E -Hemoglobiini, keskimassakonsentraatio	Erythrocyte	
2222	e-mchc	e9/l	80	0	[189, 204, 221.12, 246.5, 258.38, 272, 295.5, 312, 349]	E -Hemoglobiini, keskimassakonsentraatio	Erythrocyte	
2223	e-mchc	form	34	0		E -Hemoglobiini, keskimassakonsentraatio	Erythrocyte	
2224	e-mchc	g/l	7123092	0	[314.69, 320.67, 324.6, 327.8, 330.89, 333.47, 336.89, 340.48, 345.7]	E -Hemoglobiini, keskimassakonsentraatio	Erythrocyte	
2225	e-mchc	gil	5	0		E -Hemoglobiini, keskimassakonsentraatio	Erythrocyte	
2226	e-mchc	pg	17	0		E -Hemoglobiini, keskimassakonsentraatio	Erythrocyte	
2227	e-mchc		64048	100	[318.04, 323.73, 327.95, 331.31, 333.66, 336.22, 339.07, 342.77, 347.81]	E -Hemoglobiini, keskimassakonsentraatio	Erythrocyte	
2228	e-mchcp	g/l	1281	0	[314.67, 319.19, 322.05, 324.4, 326.58, 329.18, 332.64, 335.86, 340.4]		Erythrocyte	
2229	e-mchcp		6	100			Erythrocyte	
2230	e-mchp	pg	1279	0	[27.54, 28.45, 28.89, 29.39, 29.8, 30.28, 30.7, 31.29, 32.07]		Erythrocyte	
2231	e-mchp		6	100			Erythrocyte	
2232	e-mcv	%	3139	0	[12.24, 12.59, 12.82, 13, 13.17, 13.34, 13.64, 14, 14.59]	E -Erytrosyytit, keskitilavuus	Erythrocyte	
2233	e-mcv	e12/l	189	0		E -Erytrosyytit, keskitilavuus	Erythrocyte	
2234	e-mcv	e9/l	9	0		E -Erytrosyytit, keskitilavuus	Erythrocyte	
2235	e-mcv	fl	10892044	0.03	[84.77, 86.99, 88.78, 90, 91.06, 92.71, 94.02, 95.93, 98.65]	E -Erytrosyytit, keskitilavuus	Erythrocyte	
2236	e-mcv	form	34	0		E -Erytrosyytit, keskitilavuus	Erythrocyte	
2237	e-mcv	g/l	6	0		E -Erytrosyytit, keskitilavuus	Erythrocyte	
2238	e-mcv	l/l	172	0	[0.32, 0.35, 0.36, 0.37, 0.38, 0.4, 0.4, 0.41, 0.43]	E -Erytrosyytit, keskitilavuus	Erythrocyte	
2239	e-mcv	nmol/l	8	0		E -Erytrosyytit, keskitilavuus	Erythrocyte	
2240	e-mcv	pg	323	0	[86.82, 88, 89, 90, 91.09, 92.05, 93, 94.46, 96.17]	E -Erytrosyytit, keskitilavuus	Erythrocyte	
2241	e-mcv		89779	100	[84.55, 86.38, 87.98, 89.05, 90.26, 91.71, 93, 94.46, 96.72]	E -Erytrosyytit, keskitilavuus	Erythrocyte	
2242	e-mcvp	fl	1282	0	[85.02, 86.91, 88.4, 89.45, 90.63, 92.02, 93.15, 94.53, 97.11]		Erythrocyte	
2243	e-mcvp		6	100			Erythrocyte	
2244	hoicrp	mg/l	235	0				
2245	hoicrp		3458	45.26	[6.8, 8.84, 12.42, 17.15, 23.04, 31.5, 42.71, 59.53, 94.47]			
2246	hoiekg		747	99.87				
2247	hoihb	g/l	6	0				
2248	hoihb		410	0	[90.77, 103.64, 112.84, 118.62, 123.8, 130.23, 136.2, 142.85, 150]			
2249	hoiinr		436	0				
2250	iga	g/l	156	0	[1.12, 1.44, 1.72, 1.94, 2.1, 2.35, 2.64, 3.12, 3.82]			
2251	immi		183	100				
2252	immii		118	100				
2253	immuno		386	100				
2254	kipa		129	100				
2255	kissa	mm	40	0				
2256	kissa	u/ml	151	0	[0.39, 0.76, 1.25, 1.6, 2.18, 3.65, 6.38, 9.55, 19.5]			
2257	kissa		638	77.27	[0.19, 0.44, 0.81, 1.25, 2.07, 3.08, 4.83, 6.86, 14.75]			
2258	kissae	u/ml	205	0	[0, 0, 0.02, 0.09, 0.25, 0.72, 1.41, 2.72, 9.42]			
2259	kissae		80	68.75				
2260	koivu	mm	31	0				
2261	koivu	u/ml	204	0	[0.44, 0.77, 1.34, 2.43, 3.79, 6.53, 10.84, 17.96, 29.85]			
2262	koivu		647	67.7	[0.42, 0.81, 1.47, 2.58, 3.87, 5.83, 9.31, 19.26, 36.4]			
2263	koivue	u/ml	206	0	[0, 0.01, 0.06, 0.27, 0.7, 1.78, 4.67, 10.07, 30.23]			
2264	koivue		83	83.13				
2265	konsulf		125	100		Kliinisen fysiologian konsultaatio		
2266	l-mdx	%	125	0	[4.36, 5.4, 7, 8, 9, 10, 11, 12.27, 15.25]		Leukocyte	
2267	l-mid	%	1593	0	[4, 5, 5.57, 6, 7, 7.88, 8.91, 10, 11.89]		Leukocyte	
2268	l-muut	%	3167	0	[4.04, 5.57, 6.66, 7.29, 8.04, 9, 10, 11.19, 13.02]		Leukocyte	
2269	l-muut		8	75			Leukocyte	
2270	l-muuta		106	92.45			Leukocyte	
2271	l-mxd	%	848	0	[5.75, 7.03, 8.02, 8.97, 9.81, 10.68, 11.85, 13.24, 15.15]		Leukocyte	
2272	l-mxd	e9/l	634	0	[0.4, 0.5, 0.5, 0.6, 0.69, 0.71, 0.8, 0.9, 1.1]		Leukocyte	
2273	l-mxd		7	85.71			Leukocyte	
2274	li-muut	%	5	0			Cerebrospinal fluid	
2275	li-muut	e6/l	43	4.65			Cerebrospinal fluid	
2276	li-muut		172	98.84			Cerebrospinal fluid	
2277	ly	%	10737	0	[13.31, 17.79, 21.4, 24.56, 27.43, 30.35, 33.46, 36.92, 41.91]			
2278	ly	e9/l	6	0				
2279	ly		35	80				
2280	ly-nk	%	3894	0	[3.98, 6.02, 7.7, 9.49, 11.44, 13.62, 16.82, 20.97, 28.61]		Lymphocyte	
2281	ly-nk		250	97.2			Lymphocyte	
2282	lym	%	687	0	[18.88, 22.46, 27.13, 29.77, 32.72, 36.16, 39.74, 43.85, 48.23]			
2283	lym	e9/l	690	0	[1.19, 1.4, 1.6, 1.79, 2.02, 2.39, 2.86, 3.22, 3.66]			
2284	lym		6	100				
2285	lymf	%	60704	0	[12.74, 17.74, 21.54, 24.75, 27.72, 30.6, 33.72, 37.37, 42.83]			
2286	lymf	e9/l	20594	0	[1.07, 1.34, 1.51, 1.68, 1.84, 2.03, 2.23, 2.5, 2.92]			
2287	lymf		269	100	[11.75, 16.73, 22.55, 27.71, 31.98, 36.45, 41.46, 55.49, 74.12]			
2288	lymfo	%	7681	0	[16.59, 21.24, 24.58, 27.37, 29.96, 32.54, 35.32, 38.46, 42.84]			
2289	lymfo		26	19.23				
2290	lymfos	%	18423	0	[20.98, 24.78, 27.56, 29.96, 32.13, 34.34, 36.67, 39.47, 43.62]			
2291	lymfos		220	20.91				
2292	lymph	%	7959	0	[16.57, 21.59, 25.18, 27.99, 30.63, 33.22, 36.02, 39.5, 44.56]			
2293	lymph	e9/l	4349	0	[1.17, 1.42, 1.61, 1.8, 1.99, 2.2, 2.41, 2.71, 3.16]			
2294	lymph		72	0				
2295	lymängd	e9/l	10721	0	[1.01, 1.28, 1.49, 1.67, 1.85, 2.04, 2.26, 2.56, 3.03]			
2296	lymängd		27	100				
2297	lämpöt.	°c	103	0	[37, 37, 37, 37, 37, 37, 37, 37, 37]			
2298	lääkmää	mg/24h	436	0				
2299	lääkmää		949	100				
2300	mda5		1337	100				
2301	mdma		181	100				
2302	met300		507	100				
2303	mi-2a		1386	100				
2304	mi-2b		1337	100				
2305	mor/opi300		507	100				
2306	mtd300		507	100				
2307	oxy100		507	100				
2308	s-mi-2	u/ml	80	0	[1, 1, 1, 2, 2, 2, 2.88, 9, 14.5]		Serum	
2309	s-mi-2		203	99.51			Serum	
2310	s-mta	nmol/l	1041	43.52	[0.1, 0.1, 0.1, 0.1, 0.1, 0.2, 0.2, 0.33, 0.66]	S -Metoksityramiini (3-) seerumista	Serum	
2311	s-mta		7641	99.69		S -Metoksityramiini (3-) seerumista	Serum	
2312	s-mtx	umol/l	4865	0.66	[0.09, 0.12, 0.16, 0.24, 0.4, 0.72, 1.14, 2.05, 7.86]	S -Metotreksaatti	Serum	
2313	s-mtx		675	82.22		S -Metotreksaatti	Serum	
2314	s-s100	ug/l	276	0.72	[0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.11, 0.16, 0.27]	S -Proteiini S100	Serum	
2315	s-s100		17	88.24		S -Proteiini S100	Serum	
2316	sy-muut	%	18	0			Synovial fluid	
2317	sy-muut		126	97.62			Synovial fluid	
2318	temp		162	0.62				
2319	tif1y		1337	100				
2320	tml100		507	100				
2321	u-muuta	u/field	120	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Urine	
2322	u-muuta		140	97.86			Urine	
2323	vymp	cm	181	0	[78.8, 86.1, 90.34, 96.1, 100.23, 103.6, 108.62, 113.77, 118.8]			
2324	xtc/mdm500		495	100				

