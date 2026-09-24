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
Here is group 43 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
2630	-ana	titre	21	14.29		-Tuma, vasta-aineet		
2631	-ana		169	100		-Tuma, vasta-aineet		
2632	am-epo	iu/l	76	0		Am-Erytropoietiini	Amniotic fluid	
2633	am-epo	u/l	267	0.75	[2.67, 3.48, 4.24, 4.97, 5.92, 7.13, 8.38, 10.84, 21.7]	Am-Erytropoietiini	Amniotic fluid	
2634	am-epo		31	45.16		Am-Erytropoietiini	Amniotic fluid	
2635	b-adp	auc	28	0			Blood	
2636	b-adp		340	100			Blood	
2637	b-aspi	auc	28	0			Blood	
2638	b-aspi		340	100			Blood	
2639	b-vasp	%	165	0	[15.56, 23.85, 29.41, 35.04, 41.24, 50.14, 56.77, 61.91, 75.84]		Blood	
2640	b-vasp		67	61.19			Blood	
2641	du-5hiaa	umol	332	1.51	[14.87, 17.89, 19.97, 21.96, 24, 26.85, 29.92, 35.9, 54.08]	dU-Hydroksi-indolyyliasetaatti (5-)	24-hour urine	
2642	du-5hiaa	umol/24h	175	0	[13.31, 17.22, 20.27, 23.53, 25.81, 31.1, 37.11, 45.94, 66.13]	dU-Hydroksi-indolyyliasetaatti (5-)	24-hour urine	
2643	du-5hiaa	umol/l	25	0		dU-Hydroksi-indolyyliasetaatti (5-)	24-hour urine	
2644	du-5hiaa		147	66.67		dU-Hydroksi-indolyyliasetaatti (5-)	24-hour urine	
2645	fs-ace	u/l	33401	0.05	[20.1, 26.68, 31.86, 36.8, 41.71, 47.15, 53.87, 62.77, 76.91]	fS-Angiotensiini-1-konvertaasi	Fasting serum	
2646	fs-ace		3291	89.58	[11.62, 22.24, 28.9, 33.73, 39.48, 44.52, 50.34, 61.92, 75.37]	fS-Angiotensiini-1-konvertaasi	Fasting serum	
2647	fs-apot		258	100			Fasting serum	
2648	fs-ffa	mmol/l	170	0.59	[0.17, 0.25, 0.3, 0.38, 0.42, 0.5, 0.56, 0.69, 0.91]	fS-Rasvahapot, vapaat	Fasting serum	
2649	fs-ffa		19	36.84		fS-Rasvahapot, vapaat	Fasting serum	
2650	fs-tp-1		1698	100			Fasting serum	
2651	fs-tp-3		867	100			Fasting serum	
2652	fs-tp-4		926	100			Fasting serum	
2653	fs-tp-7		400	100			Fasting serum	
2654	li-tpha	titre	12	0		Li-Treponema pallidum, hemagglutinaatio	Cerebrospinal fluid	
2655	li-tpha		526	100		Li-Treponema pallidum, hemagglutinaatio	Cerebrospinal fluid	
2656	p-hae		461	100			Plasma	
2657	p-hcg	iu/l	858	0	[3.54, 10.48, 27.87, 72.06, 203.74, 526.1, 1525.11, 5507.31, 17831.23]	P -Koriongonadotropiini	Plasma	
2658	p-hcg	u/l	13156	11.71	[0, 1.5, 5.06, 22.75, 97.57, 335.38, 1102.09, 3696.05, 18876.19]	P -Koriongonadotropiini	Plasma	
2659	p-hcg		15471	94.78	[2.42, 12.44, 35.69, 103.11, 288.41, 866.82, 2866.35, 7636.68, 32545.17]	P -Koriongonadotropiini	Plasma	
2660	p-he4	pmol/l	2505	0.12	[38.55, 42.76, 46.82, 51.17, 55.95, 62.75, 72.7, 92.45, 146.15]	P -Epididymaalinen antigeeni 4 (HE4)	Plasma	
2661	p-he4		6	100		P -Epididymaalinen antigeeni 4 (HE4)	Plasma	
2662	p-hepg		107	100			Plasma	
2663	p-hok		397	100			Plasma	
2664	p-shbg	nmol/l	791	0	[18.37, 23.23, 26.61, 30.13, 34.18, 38.05, 43.25, 50.43, 63.9]		Plasma	
2665	p-shbg		758	4.09	[17.37, 21.68, 26.35, 30.87, 35.48, 41.39, 46.88, 56, 72.07]		Plasma	
2666	s-5hiaa	nmol/l	10313	0.07	[44.23, 52.73, 60.93, 69.76, 80.1, 94.8, 122.35, 200.37, 540.74]	S-Hydroksi-indolyyliasetaatti (5-)	Serum	
2667	s-5hiaa		153	79.74		S-Hydroksi-indolyyliasetaatti (5-)	Serum	
2668	s-ace	u/l	2203	0.18	[19.48, 28.37, 33.74, 38.42, 43.02, 48.21, 54.09, 61.63, 75.23]		Serum	
2669	s-ace		769	20.68	[21.02, 30.36, 34.97, 38.52, 42.83, 46.55, 51.62, 57.68, 65.53]		Serum	
2670	s-ada	u/l	4147	1.33	[7, 8.05, 9.23, 10.37, 11.69, 12.94, 14.77, 17.12, 21.32]	S -Adenosiinideaminaasi	Serum	
2671	s-ada		259	84.56		S -Adenosiinideaminaasi	Serum	
2672	s-afp	u/ml	18186	1.26	[1.8, 2.08, 2.61, 3.01, 3.6, 4.33, 5.57, 7.77, 24.79]	S -Alfa-1-fetoproteiini	Serum	
2673	s-afp	ug/l	2515	0	[2, 2.23, 3, 3.96, 4.22, 5.38, 6.93, 9.7, 20.37]	S -Alfa-1-fetoproteiini	Serum	
2674	s-afp		4026	80.55	[2, 2.01, 3, 3, 3.99, 4, 5, 6.41, 9.69]	S -Alfa-1-fetoproteiini	Serum	
2675	s-afp/d	u/ml	234	0	[15.11, 17.44, 19.7, 22.07, 23.9, 26.33, 29.33, 33.17, 39.24]		Serum	
2676	s-afp/d		49	12.24			Serum	
2677	s-amh	ug/l	9545	0.43	[0.42, 0.85, 1.31, 1.75, 2.24, 2.87, 3.63, 4.76, 7.13]	S -Anti-Muller hormoni	Serum	
2678	s-amh		1328	93.45	[0.62, 1.11, 1.66, 2.28, 2.8, 3.57, 4.21, 5.32, 7.88]	S -Anti-Muller hormoni	Serum	
2679	s-ami	mg/l	294	0	[1.3, 1.49, 1.7, 2.28, 2.76, 3.41, 4.52, 6.36, 11.32]	S -Amikasiini	Serum	
2680	s-ami		308	95.13		S -Amikasiini	Serum	
2681	s-ana	titre	21493	1.69	[80, 121.94, 160, 299.08, 320, 320, 399.84, 831.19, 1349.55]	S -Tuma, vasta-aineet	Serum	
2682	s-ana		62781	100	[80, 160, 320, 320, 320, 320, 640, 762.94, 1891.15]	S -Tuma, vasta-aineet	Serum	
2683	s-apot		754	100			Serum	
2684	s-asca	u/ml	89	100		S -Saccharomyces cerevisiae, vasta-aineet	Serum	
2685	s-asca		316	100		S -Saccharomyces cerevisiae, vasta-aineet	Serum	
2686	s-ast	iu/ml	2404	0	[49.92, 65.92, 77.55, 92.42, 111.12, 137.94, 173.28, 237.31, 396.71]	S -Antistreptolysiini	Serum	
2687	s-ast	titre	7	0		S -Antistreptolysiini	Serum	
2688	s-ast	u/ml	408	4.17	[30.71, 40.63, 53.38, 70.53, 94.49, 133.41, 202.61, 384.67, 783.66]	S -Antistreptolysiini	Serum	
2689	s-ast		2603	94.05	[60.92, 74.22, 90.53, 107.5, 145.19, 198.62, 261.7, 407.28, 740.72]	S -Antistreptolysiini	Serum	
2690	s-asta	iu/ml	256	16.41	[2, 2, 2, 2, 3.02, 4, 4.64, 6, 8]	S -Antistafylolysiini	Serum	
2691	s-asta	u/ml	10	0		S -Antistafylolysiini	Serum	
2692	s-asta		2266	99.29		S -Antistafylolysiini	Serum	
2693	s-br	mmol/l	130	0		S -Bromidi	Serum	
2694	s-dhea	nmol/l	398	0	[2.68, 4.23, 5.8, 8.33, 11.06, 14.2, 18.42, 22.5, 33.54]	S -Dehydroepiandrosteroni	Serum	
2695	s-dhea		74	68.92		S -Dehydroepiandrosteroni	Serum	
2696	s-dheas	umol/l	3797	0.03	[1.05, 1.87, 2.83, 3.75, 4.58, 5.54, 6.67, 8.05, 10.29]	S -Dehydroepiandrosteroni, sulfaatti	Serum	
2697	s-dheas		331	53.47	[1.45, 2.24, 2.88, 3.59, 4.26, 5.13, 5.94, 7.34, 8.82]	S -Dehydroepiandrosteroni, sulfaatti	Serum	
2698	s-e1	pmol/l	123	0	[70, 112.9, 136.88, 181.46, 224.33, 282.87, 347.03, 435.1, 621.18]	S -Estroni	Serum	
2699	s-e1		30	76.67		S -Estroni	Serum	
2700	s-e2	nmol/l	10351	2.69	[0.07, 0.1, 0.13, 0.16, 0.2, 0.27, 0.38, 0.55, 0.99]	S -Estradioli	Serum	
2701	s-e2		2381	83.75	[0.06, 0.08, 0.1, 0.12, 0.15, 0.19, 0.25, 0.35, 0.58]	S -Estradioli	Serum	
2702	s-ema		2245	99.96		S -Endomysium, vasta-aineet	Serum	
2703	s-ena		1469	62.22	[0.1, 0.1, 0.1, 0.19, 0.2, 0.22, 0.3, 0.47, 1.12]		Serum	
2704	s-enal		832	100			Serum	
2705	s-epo	iu/l	2353	0.38	[4.95, 7.08, 8.93, 10.78, 12.99, 15.54, 19.77, 28.75, 48.4]	S -Erytropoietiini	Serum	
2706	s-epo	pmol/l	44	0		S -Erytropoietiini	Serum	
2707	s-epo	u/l	5380	0	[4.44, 6.44, 8.09, 9.88, 11.93, 14.55, 19.01, 29.55, 62.33]	S -Erytropoietiini	Serum	
2708	s-epo		1209	20.35	[4.6, 6.64, 8.47, 10.2, 11.81, 13.76, 17.07, 22.59, 40.53]	S -Erytropoietiini	Serum	
2709	s-ffa	mmol/l	518	0	[0.03, 0.04, 0.07, 0.13, 0.19, 0.28, 0.44, 0.57, 0.75]		Serum	
2710	s-gen	mg/l	373	0.54	[0.5, 0.65, 0.75, 0.89, 0.99, 1.17, 1.48, 2.04, 3.94]	S -Gentamysiini	Serum	
2711	s-gen		339	85.55		S -Gentamysiini	Serum	
2712	s-hae		751	100			Serum	
2713	s-hbe		347	100			Serum	
2714	s-hcg	iu/l	2181	0	[2.11, 4.62, 15.8, 53.63, 166.71, 442, 1018.25, 2912.42, 12003.73]	S -Koriongonadotropiini	Serum	
2715	s-hcg	u/l	5914	0	[5.67, 20.66, 67.43, 172.44, 366.74, 677.25, 1513.49, 4378.78, 17452.46]	S -Koriongonadotropiini	Serum	
2716	s-hcg		16592	96.23	[8.29, 17.67, 40.08, 108.43, 306.84, 912.85, 3181.52, 10206.39, 38671.9]	S -Koriongonadotropiini	Serum	
2717	s-he4	pmol/l	11193	0	[31.87, 37.18, 41.94, 46.96, 53.02, 60.99, 73.42, 98.24, 181.66]	S -Epididymaalinen antigeeni 4 (HE4)	Serum	
2718	s-he4		420	43.57	[28.77, 32.37, 35.15, 39.84, 42.92, 45.83, 51.37, 61.13, 81.8]	S -Epididymaalinen antigeeni 4 (HE4)	Serum	
2719	s-kem		1473	100			Serum	
2720	s-kyhemag	titre	180	1.67	[8, 11.41, 16, 18.4, 42.5, 146.59, 256, 870.4, 2048]	S -Kylmähemagglutiniinit	Serum	
2721	s-kyhemag		826	99.39		S -Kylmähemagglutiniinit	Serum	
2722	s-shbg	nmol/l	29338	0	[16.96, 21.37, 25.29, 29.19, 33.26, 37.98, 43.62, 51.6, 65.13]	S -Sukupuolihormoneja sitova globuliini	Serum	
2723	s-shbg		614	100	[15.22, 19.74, 24.23, 28.3, 32.4, 37.12, 43.41, 51.5, 64.44]	S -Sukupuolihormoneja sitova globuliini	Serum	
2724	s-tati	nmol/l	551	0	[1.3, 1.49, 1.61, 1.81, 2.08, 2.38, 2.74, 3.44, 6.09]	S -Tuumoriin liittyvä trypsiini-inhibiittori	Serum	
2725	s-tati	ug/l	446	0	[6.71, 8.1, 9.03, 9.98, 11, 12.24, 13.98, 16.99, 30.9]	S -Tuumoriin liittyvä trypsiini-inhibiittori	Serum	
2726	s-tati		86	24.42		S -Tuumoriin liittyvä trypsiini-inhibiittori	Serum	
2727	s-tpha	titre	1665	0	[158.37, 304.61, 391.53, 640, 1034.44, 1338.85, 3168.84, 4985.37, 6432.72]	S -Treponema pallidum, hemagglutinaatio	Serum	
2728	s-tpha		9799	99.67		S -Treponema pallidum, hemagglutinaatio	Serum	
2729	s-van	mg/l	36935	0.09	[6.84, 8.59, 9.97, 11.16, 12.39, 13.69, 15.03, 16.85, 19.72]	S -Vankomysiini	Serum	
2730	s-van		1695	100	[7.35, 9.11, 10.49, 11.71, 12.89, 14.15, 15.61, 17.74, 21.29]	S -Vankomysiini	Serum	
2731	ts-res		1353	100		Ts-Reseptoritutkimus	Tissue	
2732	u-hcg	iu/l	93	0		U -Koriongonadotropiini	Urine	
2733	u-hcg	u/l	15	0		U -Koriongonadotropiini	Urine	
2734	u-hcg		227	97.8		U -Koriongonadotropiini	Urine	

