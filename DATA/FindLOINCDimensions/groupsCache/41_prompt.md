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
Here is group 41 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
2468	as-pmn	%	152	0	[4.03, 7, 9.77, 13.3, 17.45, 22.63, 27.87, 41.47, 57.4]		Ascitic fluid	
2469	as-pmn		36	69.44			Ascitic fluid	
2470	cu-vm	ml	2761	0	[296.91, 377.4, 450.18, 523.54, 603.43, 681.2, 782.6, 907.85, 1100.68]		Collected urine	
2471	cu-vm		828	11.47	[282, 374.85, 449.75, 514.72, 593.37, 672.1, 789.94, 935.7, 1146.7]		Collected urine	
2472	du-moma	umol	76	0	[13, 17, 18.77, 21, 22, 24.3, 27.1, 29, 34]	dU-Metoksihydroksimandelaatti	24-hour urine	
2473	du-moma	umol/24h	20	0		dU-Metoksihydroksimandelaatti	24-hour urine	
2474	du-moma		64	20.31		dU-Metoksihydroksimandelaatti	24-hour urine	
2475	du-vm	ml	866	0	[1064.54, 1323.82, 1548.76, 1748.4, 1932.43, 2156.79, 2398.38, 2665.24, 3016.19]		24-hour urine	
2476	du-vm		72	54.17			24-hour urine	
2477	du-vmml	ml	257	0	[728.84, 1145, 1475, 1656.45, 1874.29, 2088.17, 2358, 2597.08, 2899.64]		24-hour urine	
2478	du-vmml		76	6.58			24-hour urine	
2479	gamma	g/l	902	0	[4.38, 6.08, 7.16, 8.27, 9.67, 11.43, 13.44, 17.14, 23.8]			
2480	happi	%	838	0				
2481	happi	l	132	0				
2482	happi	l/min	6	0				
2483	happi		774	93.54				
2484	hcgbvkmom		21725	5.24	[0.49, 0.63, 0.75, 0.89, 1.03, 1.2, 1.41, 1.7, 2.22]			
2485	igg-summa	g/l	106	0	[7.38, 7.99, 9.07, 9.73, 10.31, 11.11, 12.4, 13.44, 15.65]			
2486	j-papa		183	100				
2487	ntkmom		21817	5.25	[0.66, 0.75, 0.81, 0.88, 0.94, 1, 1.07, 1.17, 1.33]			
2488	p-pc	%	7171	0.01	[82.12, 95.5, 103.17, 110.11, 116.57, 123.18, 129.89, 139.01, 152.28]	P -Proteiini C	Plasma	
2489	p-pc	form	12	0		P -Proteiini C	Plasma	
2490	p-pc		763	22.67	[85.75, 97.71, 105.06, 110.08, 116.66, 123.09, 130.7, 139.67, 156.01]	P -Proteiini C	Plasma	
2491	p-pct	ng/ml	1499	0	[0.1, 0.1, 0.2, 0.28, 0.4, 0.64, 1.19, 2.72, 9.11]	P -Prokalsitoniini	Plasma	
2492	p-pct	ug/l	25253	0.93	[0.07, 0.1, 0.14, 0.19, 0.28, 0.43, 0.73, 1.54, 5.58]	P -Prokalsitoniini	Plasma	
2493	p-pct		1082	100	[0.05, 0.07, 0.09, 0.11, 0.14, 0.18, 0.28, 0.51, 1.32]	P -Prokalsitoniini	Plasma	
2494	p-pi	mmol/l	186393	0	[0.74, 0.87, 0.96, 1.05, 1.13, 1.23, 1.35, 1.51, 1.79]	P -Fosfaatti, epäorgaaninen	Plasma	
2495	p-pi		2732	100	[0.69, 0.81, 0.9, 0.98, 1.05, 1.14, 1.23, 1.37, 1.61]	P -Fosfaatti, epäorgaaninen	Plasma	
2496	p-prl	mu/l	10459	0	[138.43, 184.84, 223.63, 260.82, 305.8, 360.39, 438.1, 574.71, 949.72]	P -Prolaktiini	Plasma	
2497	p-prl	nmol/l	16	0		P -Prolaktiini	Plasma	
2498	p-prl		162	100	[148.58, 185.42, 222.14, 261.49, 305.43, 363.33, 440.54, 555.02, 793.59]	P -Prolaktiini	Plasma	
2499	p-ps	%	1651	0.06	[65.08, 76.67, 83.58, 89.86, 95.83, 100.96, 108.58, 116.29, 129.66]	P -Proteiini S	Plasma	Basic screening
2500	p-ps		443	28.67	[67.14, 77.97, 87.63, 93.49, 99.86, 106.07, 111.87, 120.09, 130.13]	P -Proteiini S	Plasma	Basic screening
2501	p-psa	ug/l	440363	0.2	[0.25, 0.52, 0.82, 1.21, 1.75, 2.56, 3.84, 5.94, 10.7]	P -Prostataspesifinen antigeeni	Plasma	
2502	p-psa		61308	100	[0.42, 0.63, 0.86, 1.19, 1.5, 1.95, 2.54, 3.82, 5.94]	P -Prostataspesifinen antigeeni	Plasma	
2503	p-pt	s	184	0			Plasma	
2504	papa		1138	99.74				
2505	pappakmom		21814	5.25	[0.49, 0.65, 0.78, 0.91, 1.06, 1.23, 1.45, 1.75, 2.23]			
2506	pf-pmn	%	562	0	[2, 3, 4.86, 7.97, 11.19, 15.95, 24.78, 38.94, 63.87]		Pleural fluid	
2507	pf-pmn		46	67.39			Pleural fluid	
2508	pipelle		428	100				
2509	pt-apri		975	4.51	[0.2, 0.2, 0.3, 0.3, 0.4, 0.5, 0.68, 0.95, 1.49]		Patient	
2510	pt-ar-r		167	100			Patient	Exercise / functional test
2511	pt-bmi	kg/m2	325	0	[22.05, 23.61, 25.44, 26.71, 28.2, 29.77, 31.34, 33.43, 35.91]		Patient	
2512	pt-brdil		1175	100			Patient	
2513	pt-ekg		14768	100			Patient	
2514	pt-enmg		132	100			Patient	
2515	pt-icsi		108	100			Patient	
2516	pt-lis		259	100			Patient	
2517	pt-neni		146	100			Patient	
2518	pt-pef	form	91	0	[348, 402.5, 430, 458.75, 475, 508.75, 582.5, 618.33, 695]		Patient	
2519	pt-pef	l/min	24	0			Patient	
2520	pt-pef		126	99.21			Patient	
2521	pt-pol		125	100		Pt-Yöpolygrafia unilaboratoriossa	Patient	
2522	pt-psg		396	100		Pt-Unipolygrafia unilaboratoriossa	Patient	
2523	pt-rr		226	100			Patient	
2524	pt-rr-pa		373	100			Patient	Long-term / prolonged
2525	pt-sep	mg/l	12	0		Pt-Somatosensorinen herätevastetutkimus (SEP), yksi hermo molemmin puolin	Patient	
2526	pt-sep		187	63.64		Pt-Somatosensorinen herätevastetutkimus (SEP), yksi hermo molemmin puolin	Patient	
2527	pt-sik		244	100			Patient	
2528	pt-spr		751	99.87			Patient	
2529	pt-syke	times/min	159	0	[55.48, 60.47, 62.73, 66.7, 71.1, 74.1, 78.05, 82.8, 89.12]		Patient	
2530	pt-syn		947	99.79			Patient	
2531	pt-säil		172	100			Patient	
2532	pt-uvb		831	100			Patient	
2533	pt-vp-ple		102	100			Patient	
2534	pt-vscr		832	100			Patient	
2535	pt-warm		282	100			Patient	
2536	pujo	mm	40	0				
2537	pujo	u/ml	120	0	[0.05, 0.36, 0.45, 0.56, 0.83, 1.19, 1.72, 4.65, 7.75]			
2538	pujo		649	81.51	[0, 0.4, 0.49, 0.64, 0.82, 1, 1.48, 2.25, 4]			
2539	pujoe	u/ml	214	0	[0, 0.01, 0.02, 0.05, 0.12, 0.25, 0.52, 1.01, 1.65]			
2540	pujoe		107	82.24				
2541	rauta	umol/l	2589	0	[5.07, 7.57, 9.48, 11.03, 12.66, 14.38, 16.32, 18.74, 23.01]			
2542	rauta		138	31.88	[3, 4.24, 4.85, 5.53, 6.12, 7.18, 7.95, 8.56, 8.9]			
2543	reuma		265	100				
2544	rr-pa		1590	100		Verenpaine, pitkäaikaisrekisteröinti (24 h)		Long-term / prolonged
2545	s-gamma	%	11	0			Serum	
2546	s-gamma	g/l	31257	0	[4.45, 6.28, 7.46, 8.5, 9.48, 10.46, 11.72, 13.46, 17.36]		Serum	
2547	s-gamma		74	100	[5.61, 6.71, 7.52, 8.31, 9.25, 10.18, 11.22, 12.77, 16.04]		Serum	
2548	s-ntmom	mom	769	0	[0.79, 0.88, 0.95, 1.02, 1.09, 1.16, 1.21, 1.31, 1.44]		Serum	
2549	s-prl	miu/l	1647	0	[99.08, 122.5, 142.4, 160.32, 182.26, 206.85, 241.78, 297.2, 455.24]	S -Prolaktiini	Serum	
2550	s-prl	mu/l	31229	0.13	[114.01, 152.37, 185.56, 220.27, 261.7, 314.38, 389.96, 523.9, 846.46]	S -Prolaktiini	Serum	
2551	s-prl	mul/l	6	0		S -Prolaktiini	Serum	
2552	s-prl	nmol/l	58	0		S -Prolaktiini	Serum	
2553	s-prl		718	100	[136.58, 180.08, 218.92, 259.99, 307.74, 369.71, 452.83, 591.84, 902.7]	S -Prolaktiini	Serum	
2554	s-psa	mg/l	7	0		S -Prostataspesifinen antigeeni	Serum	
2555	s-psa	ug/l	91718	0	[0.39, 0.57, 0.75, 0.97, 1.25, 1.64, 2.26, 3.31, 5.42]	S -Prostataspesifinen antigeeni	Serum	
2556	s-psa		4826	100	[0.41, 0.6, 0.75, 0.94, 1.18, 1.4, 1.81, 2.77, 4.3]	S -Prostataspesifinen antigeeni	Serum	
2557	s-pujoe	u/ml	4828	0.02	[0.01, 0.02, 0.03, 0.07, 0.12, 0.21, 0.38, 0.79, 2.03]	S -Pujon siitepöly (w6), IgE-vasta-aineet	Serum	
2558	s-pujoe	ucor	507	0	[2103.51, 2246.09, 2326.4, 2397.68, 2478.52, 2556.83, 2627.97, 2744.25, 2962.25]	S -Pujon siitepöly (w6), IgE-vasta-aineet	Serum	
2559	s-pujoe		5135	91.24	[0, 0.02, 0.07, 0.15, 0.27, 0.42, 0.69, 1.24, 3.17]	S -Pujon siitepöly (w6), IgE-vasta-aineet	Serum	
2560	s-pujospe	u/ml	641	12.95	[0.01, 0.02, 0.04, 0.1, 0.16, 0.29, 0.52, 1.01, 2.34]		Serum	
2561	s-pujospe		304	82.57			Serum	
2562	se-pmn	%	79	0			Secretion	
2563	se-pmn		76	100			Secretion	
2564	strep-a		1498	99.93				
2565	strepa		406	99.75				
2566	sy-mn	%	43	0			Synovial fluid	
2567	sy-mn		114	27.19	[10, 14.65, 19, 21.6, 35, 48.5, 64.57, 82.3, 95]		Synovial fluid	
2568	sy-pmn	%	1206	0	[7.9, 18.75, 33.07, 48.63, 62.18, 73.14, 80.98, 87.34, 91.98]		Synovial fluid	
2569	sy-pmn		331	75.23	[5, 18, 37.13, 51.75, 65, 78.1, 81.58, 86, 93]		Synovial fluid	
2570	trik-od		384	79.17				
2571	trop-t	ng/l	53	0				
2572	trop-t		393	100				
2573	tropo		244	100				
2574	trpaab		5456	100				
2575	trpaab.		351	100				
2576	ttpaasto		104	100				
2577	vp-ple		725	100		Valtimopaine ja verenvirtaus, pletysmografi		

