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
Here is group 40 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
2325	ab-na	mmol/l	1125	0	[130.94, 134.84, 136.62, 138.04, 139.34, 140.42, 141.09, 142.57, 144.87]		Arterial blood	Native preparation
2326	ap-lakt	mmol/l	1456	0	[0.68, 0.81, 0.96, 1.1, 1.28, 1.5, 1.81, 2.29, 3.25]			
2327	ap-lakt		18	50				
2328	ap-na	%	24	0				Native preparation
2329	ap-na	g/l	6	0				Native preparation
2330	ap-na	kpa	12	0				Native preparation
2331	ap-na	mmol/l	50270	0	[130.71, 133.37, 134.96, 136, 136.98, 137.95, 138.88, 139.98, 141.72]			Native preparation
2332	ap-na	°c	6	0				Native preparation
2333	ap-na		233	92.27				Native preparation
2334	ap-nak		155	100				
2335	b-na	mmol/l	59360	0	[132.76, 134.99, 136.51, 137.61, 138.41, 139.21, 140.23, 141.69, 144.08]		Blood	Native preparation
2336	b-na		9740	95.39	[132.18, 135.78, 137.16, 138.83, 139, 140, 140.41, 141, 142]		Blood	Native preparation
2337	cp-na	mmol/l	305	0	[132, 134.22, 135.76, 137, 138, 139.28, 140, 141.93, 143]			Native preparation
2338	cp-na		18	100				Native preparation
2339	di-na	mmol/l	307	0		Di-Natrium	Dialysis fluid	Native preparation
2340	di-na		5	100		Di-Natrium	Dialysis fluid	Native preparation
2341	du-na	mmol	2785	0.25	[76.79, 98.05, 115.16, 132.8, 151.88, 170.12, 193.55, 223.43, 273.21]	dU-Natrium	24-hour urine	Native preparation
2342	du-na	mmol/24h	60	0		dU-Natrium	24-hour urine	Native preparation
2343	du-na		1021	70.23	[65.53, 84.3, 103.25, 116.92, 139.24, 156.61, 172.58, 210.59, 273.58]	dU-Natrium	24-hour urine	Native preparation
2344	fp-ctx	ng/l	34	0			Fasting plasma	
2345	fp-ctx	ug/l	1281	0	[0.09, 0.14, 0.2, 0.25, 0.3, 0.38, 0.48, 0.6, 0.81]		Fasting plasma	
2346	fp-ctx		491	16.7	[0.12, 0.19, 0.24, 0.31, 0.39, 0.48, 0.58, 0.71, 1]		Fasting plasma	
2347	fp-gt	u/l	772	0	[15.6, 19.58, 23.9, 27.61, 33.27, 39.92, 49.93, 68.82, 104.64]		Fasting plasma	
2348	fp-gt		11	0			Fasting plasma	
2349	fp-na	mmol/l	6047	0	[135.6, 137.84, 139, 139.97, 140.01, 141, 141.04, 142, 143]		Fasting plasma	Native preparation
2350	fp-na		18	11.11			Fasting plasma	Native preparation
2351	p-acth	ng/l	10045	0.42	[8.08, 11.12, 14.1, 17.14, 20.58, 24.79, 30.92, 40.41, 66.95]	P -Adrenokortikotropiini	Plasma	
2352	p-acth	pmol/l	7	0		P -Adrenokortikotropiini	Plasma	
2353	p-acth		1461	80.01	[9.26, 12.21, 15.18, 18.04, 23.17, 27.09, 32.96, 40.36, 61.68]	P -Adrenokortikotropiini	Plasma	
2354	p-at3	%	33387	0.01	[54.15, 67.47, 77.12, 84.9, 91.44, 97.34, 103.31, 110.17, 119.77]	P -Antitrombiini III	Plasma	
2355	p-at3	form	18	0		P -Antitrombiini III	Plasma	
2356	p-at3		750	50.4	[77.41, 88.27, 92.93, 97.96, 101.75, 106.37, 110.41, 114.53, 119.94]	P -Antitrombiini III	Plasma	
2357	p-at3.	%	4852	0	[82.58, 90.63, 95.72, 100.18, 103.97, 107.65, 111.95, 117.06, 124.39]		Plasma	
2358	p-at3.		269	20.45	[87.63, 92.63, 97.23, 100.8, 104.86, 109.03, 113.28, 117.74, 123.49]		Plasma	
2359	p-efa	form	5	100		P -Rasvahapot, välttämättömät	Plasma	
2360	p-efa		125	100		P -Rasvahapot, välttämättömät	Plasma	
2361	p-fakb	g/l	120	0	[0.14, 0.17, 0.18, 0.2, 0.21, 0.21, 0.23, 0.26, 0.3]	P -Faktori B	Plasma	
2362	p-fakb		35	25.71		P -Faktori B	Plasma	
2363	p-fe	umol/l	2840	0	[5.52, 7.66, 9.48, 11.25, 13.18, 14.87, 16.94, 19.46, 23.35]		Plasma	
2364	p-fe		740	33.92	[5.15, 6.78, 8.55, 10.06, 12.18, 14.07, 16.43, 19.54, 23.49]		Plasma	
2365	p-fs	s	319	0	[28, 29.31, 30.81, 32, 33.17, 35, 36.48, 39.22, 45.08]		Plasma	
2366	p-fs		1586	99.87			Plasma	
2367	p-fv	%	6911	0.01	[43.78, 58.4, 69.62, 80.37, 90.29, 99.93, 110.48, 122.94, 139.52]	P -Hyytymistekijä V	Plasma	
2368	p-fv		261	40.23	[68.7, 79.64, 87.53, 94.6, 99.14, 104.6, 110.72, 119.21, 132.72]	P -Hyytymistekijä V	Plasma	
2369	p-fx	%	916	0.11	[46.06, 65.75, 76.36, 83.72, 90.83, 97.78, 104.84, 112.37, 122.61]	P -Hyytymistekijä X	Plasma	
2370	p-fx		949	87.46	[66, 76.45, 83.38, 90.43, 96, 100.47, 108.88, 114, 128]	P -Hyytymistekijä X	Plasma	
2371	p-gt	mg/ml	8	0		P -Glutamyylitransferaasi	Plasma	
2372	p-gt	u/l	820178	0.02	[14.56, 18.66, 23.05, 28.6, 36.08, 47.26, 65.76, 101.29, 195.48]	P -Glutamyylitransferaasi	Plasma	
2373	p-gt		15977	100	[15.82, 20.13, 24.14, 29.03, 35.14, 45.13, 63.31, 89.78, 161.64]	P -Glutamyylitransferaasi	Plasma	
2374	p-hstni	ng/l	3261	0	[1, 2, 3, 4.12, 6.04, 9.1, 14.48, 27.09, 65.46]		Plasma	
2375	p-k+na		69230	100			Plasma	
2376	p-k,na		2518	100			Plasma	
2377	p-k-na	mmol/l	594	100			Plasma	Native preparation
2378	p-k-na		186	100			Plasma	Native preparation
2379	p-k-pa	mmol/l	197	0	[3.53, 3.78, 3.9, 4, 4.04, 4.13, 4.3, 4.38, 4.56]		Plasma	Long-term / prolonged
2380	p-k/na		321	100			Plasma	
2381	p-ked.	mmol/l	344	0			Plasma	
2382	p-kjd.	mmol/l	160	0			Plasma	
2383	p-la1	s	1064	0	[30, 31.95, 33.1, 34.81, 35.99, 37.75, 39.96, 44.96, 54.77]		Plasma	
2384	p-la1		52	50			Plasma	
2385	p-la2	s	498	0	[32, 33.41, 35.41, 36.98, 38.82, 40.9, 43.06, 47.24, 53.65]		Plasma	
2386	p-la2		1411	99.43			Plasma	
2387	p-mypa	mg/l	1692	0.06	[0.64, 0.99, 1.33, 1.7, 2.12, 2.67, 3.43, 4.39, 6.28]	P -Mykofenolihappo	Plasma	
2388	p-mypa		245	76.33		P -Mykofenolihappo	Plasma	
2389	p-na	mmol/	14	0		P -Natrium	Plasma	Native preparation
2390	p-na	mmol/l	7320578	0.03	[133.91, 136.27, 137.98, 138.99, 139.95, 140, 141, 142, 143]	P -Natrium	Plasma	Native preparation
2391	p-na		81059	100	[134.02, 137.07, 138.67, 139, 140, 141, 142, 142.8, 143]	P -Natrium	Plasma	Native preparation
2392	p-na.	mmol/l	1467	0	[134.64, 136.99, 138.3, 139.9, 140.54, 141, 142, 142.75, 144]		Plasma	
2393	p-na:	mmol/l	621	0	[131.65, 133.8, 135, 136.23, 137.85, 138.61, 139.67, 140.88, 142]		Plasma	
2394	p-naed.	mmol/l	306	0			Plasma	
2395	p-najd.	mmol/l	154	0			Plasma	
2396	p-nak		259040	100			Plasma	
2397	p-nap	mmol/l	342	0	[132.69, 135.3, 137.47, 139, 140, 140.64, 142, 143, 145]		Plasma	
2398	p-supar	ug/l	351	0	[2.87, 3.25, 3.63, 3.92, 4.33, 4.73, 5.27, 6.37, 8.21]		Plasma	
2399	p-supar		16	100			Plasma	
2400	p-t3-v	pmol/l	82081	0.04	[3.46, 3.84, 4.11, 4.35, 4.57, 4.81, 5.08, 5.46, 6.26]	P -Trijodityroniini, vapaa	Plasma	Free or unconjugated
2401	p-t3-v		921	100	[3.47, 3.87, 4.08, 4.31, 4.53, 4.77, 5.02, 5.39, 6.24]	P -Trijodityroniini, vapaa	Plasma	Free or unconjugated
2402	p-t4-v	pmol/l	1108128	0.01	[11.98, 13.02, 13.95, 14.63, 15.23, 16.03, 16.92, 17.94, 19.56]	P -Tyroksiini, vapaa	Plasma	Free or unconjugated
2403	p-t4-v		19446	100	[12, 13.8, 14.44, 15.06, 16, 16.21, 16.99, 17.6, 19]	P -Tyroksiini, vapaa	Plasma	Free or unconjugated
2404	p-t4v	pmol/l	110881	0	[12.73, 13.79, 14.57, 15.27, 15.96, 16.68, 17.48, 18.48, 19.99]		Plasma	
2405	p-t4v		4743	100	[12.19, 13.39, 14.21, 14.93, 15.61, 16.33, 17.17, 18.29, 20.03]		Plasma	
2406	p-tfr	mg/l	188406	0.02	[0.81, 1.28, 2.05, 2.5, 2.87, 3.3, 3.83, 4.64, 6.21]	P -Transferriinireseptori, liukoinen	Plasma	
2407	p-tfr		15951	100	[2.12, 2.53, 2.87, 3.21, 3.63, 4.15, 4.81, 5.75, 7.59]	P -Transferriinireseptori, liukoinen	Plasma	
2408	p-tni	ng/l	220095	0	[4, 5.13, 7.13, 10.22, 15.11, 24.46, 46.82, 122.37, 829.48]	P -Troponiini I	Plasma	
2409	p-tni	ug/l	25579	0	[0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.08, 0.16, 0.78]	P -Troponiini I	Plasma	
2410	p-tni		70910	100	[0.05, 0.22, 2.89, 4.65, 7.45, 12.28, 24.91, 48.92, 145.81]	P -Troponiini I	Plasma	
2411	p-tni.	ng/l	6	0			Plasma	
2412	p-tni.	ug/l	155	0	[0, 0, 0, 0, 0, 0, 0.01, 0.02, 0.06]		Plasma	
2413	p-tni.		28	100			Plasma	
2414	p-tnih	ng/l	1974	0	[4, 5.78, 7.89, 10.8, 16.52, 27.69, 54.92, 168.16, 1593.63]		Plasma	
2415	p-tnih		440	100			Plasma	
2416	p-tnl	ng/l	124	0	[3, 4, 5.16, 7, 10, 12.72, 29.97, 89.8, 240.6]		Plasma	
2417	p-tnl	ug/l	179	0	[0, 0, 0, 0, 0, 0.01, 0.01, 0.02, 0.05]		Plasma	
2418	p-tnl		36	100			Plasma	
2419	p-tnt	ng/l	437584	0.96	[6.97, 9.13, 11.78, 15.03, 19.12, 24.8, 33.92, 51.22, 106.22]	P -Troponiini T	Plasma	
2420	p-tnt	ug/l	76	0		P -Troponiini T	Plasma	
2421	p-tnt		80220	100	[6.97, 8.93, 11.46, 14.61, 18.09, 22.79, 29.94, 42.37, 74.82]	P -Troponiini T	Plasma	
2422	p-tt	%	472003	0.01	[50.44, 65.04, 74.28, 81.62, 88.26, 94.73, 101.62, 109.77, 121.26]	P -Tromboplastiiniaika	Plasma	
2423	p-tt	form	20	0		P -Tromboplastiiniaika	Plasma	
2424	p-tt		4462	100	[41.42, 56.72, 66.85, 77.09, 85.82, 93.79, 102.07, 112.01, 126.16]	P -Tromboplastiiniaika	Plasma	
2425	p-tt-	%	1432	0	[60.12, 72.07, 78.16, 83.25, 88.78, 95.39, 102.35, 111.94, 122.43]		Plasma	
2426	p-tt-		29	96.55			Plasma	
2427	p-tt.	%	5628	0	[63.13, 78.7, 87.12, 93.57, 99.77, 105.67, 112.42, 119.67, 130.89]		Plasma	
2428	p-tt.		328	31.4	[48, 79.63, 90.12, 98.65, 107.18, 114.33, 121.82, 130.4, 140]		Plasma	
2429	p-ttr	%	1114	0	[50.89, 61.27, 67.88, 73.89, 78.52, 83.07, 89.29, 95.08, 100]		Plasma	
2430	p-ttr		89	89.89			Plasma	
2431	pdgfr		461	100				
2432	peak	l/min	12	0				
2433	peak		104	100				
2434	pef-pa		7844	99.92		Uloshengityksen huippuvirtaus, sarjamittaus, pitkäaikaisseuranta		Long-term / prolonged
2435	pef-ras		242	100		Uloshengityksen huippuvirtaus, sarjamittaus, rasituskoe		
2436	pf-ace	u/l	313	3.19	[6.4, 10.22, 12.78, 15.45, 17.82, 19.96, 24.1, 28.83, 37.4]	Pf-Angiotensiini-1-konvertaasi	Pleural fluid	
2437	pf-ace		161	98.14		Pf-Angiotensiini-1-konvertaasi	Pleural fluid	
2438	pf-ada	u/l	3550	0.14	[3.68, 5.14, 6.78, 8.01, 9.46, 11.17, 13.55, 17.33, 25.48]	Pf-Adenosiinideaminaasi	Pleural fluid	
2439	pf-ada		365	90.96		Pf-Adenosiinideaminaasi	Pleural fluid	
2440	pneag		244	100				
2441	s-na	mmol/l	124118	0	[137.36, 138.84, 139.01, 140, 140.14, 141, 141.38, 142, 143]	S -Natrium	Serum	Native preparation
2442	s-na	mol/l	5	0		S -Natrium	Serum	Native preparation
2443	s-na		931	67.35	[137.2, 138, 139, 139, 140, 140, 141, 141, 142.37]	S -Natrium	Serum	Native preparation
2444	s-t3-v	pmol/l	18657	0	[3.72, 4.06, 4.3, 4.5, 4.69, 4.9, 5.13, 5.43, 6.06]	S -Trijodityroniini, vapaa	Serum	Free or unconjugated
2445	s-t3-v		1623	51.2	[3.55, 3.8, 4.02, 4.22, 4.41, 4.6, 4.85, 5.16, 5.82]	S -Trijodityroniini, vapaa	Serum	Free or unconjugated
2446	s-t4-v	pmol/l	252259	0	[11.09, 12, 12.88, 13.14, 13.97, 14.48, 15.15, 16.1, 17.48]	S -Tyroksiini, vapaa	Serum	Free or unconjugated
2447	s-t4-v		9900	100	[12.03, 12.98, 13.72, 14.35, 14.94, 15.68, 16.39, 17.25, 18.59]	S -Tyroksiini, vapaa	Serum	Free or unconjugated
2448	s-t4v	pmol/l	1086	0	[12.85, 13, 14, 14.52, 15, 15.93, 16, 17, 18]		Serum	
2449	s-tfr	mg	7	0		S -Transferriinireseptori, liukoinen	Serum	
2450	s-tfr	mg/l	77760	0	[1, 1.22, 1.5, 1.89, 2.35, 2.8, 3.34, 4.1, 5.59]	S -Transferriinireseptori, liukoinen	Serum	
2451	s-tfr		1379	100	[1.84, 2.22, 2.62, 3.08, 3.57, 4.23, 5.1, 6.26, 8.15]	S -Transferriinireseptori, liukoinen	Serum	
2452	s-tnf	ng/l	100	0	[4.65, 5.4, 6.33, 7.11, 7.81, 8.85, 10.5, 13.2, 23.25]	S -Tuumorinekroositekijä, alfa	Serum	
2453	s-tnf		50	74		S -Tuumorinekroositekijä, alfa	Serum	
2454	s-tni	ng/l	63	0	[2.98, 3.29, 4.36, 4.96, 6.38, 8.72, 14.54, 33, 54.53]	S -Troponiini I	Serum	
2455	s-tni	ug/l	11	0		S -Troponiini I	Serum	
2456	s-tni		171	100		S -Troponiini I	Serum	
2457	s-tnt	ng/l	149	0	[40, 42, 45.21, 51.23, 64.69, 87.1, 139.39, 201.81, 358.2]	S -Troponiini T	Serum	
2458	s-tnt		7446	99.38		S -Troponiini T	Serum	
2459	s-tob	mg/l	805	0.99	[0.29, 0.5, 0.61, 0.8, 1.01, 1.26, 1.54, 1.91, 3.02]	S -Tobramysiini	Serum	
2460	s-tob		560	81.96		S -Tobramysiini	Serum	
2461	sp-pak		196	100			Sperm / semen	
2462	sp-pakd		138	100			Sperm / semen	
2463	u-na	mmol/l	8969	1.33	[24.74, 32.42, 40.4, 48.4, 57.53, 68.16, 81.75, 99.14, 129.68]	U -Natrium	Urine	Native preparation
2464	u-na		2662	76.37	[27.27, 35.54, 43.11, 51.43, 60.05, 68.34, 78.15, 92.47, 111.65]	U -Natrium	Urine	Native preparation
2465	v-na		265	0.75	[130.22, 134.26, 135.98, 137.59, 138.5, 139.03, 140, 141, 142]			Native preparation
2466	vp-na	mmol/l	10896	0	[132.84, 135.34, 136.96, 137.97, 138.99, 139.84, 140.33, 141.08, 142.49]			Native preparation
2467	vp-na		174	98.28				Native preparation

