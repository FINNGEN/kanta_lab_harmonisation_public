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
Here is group 45 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
2844	-aldrc		147	100				
2845	-c3d		313	100				
2846	-cdt	mg/l	173	0	[32.2, 35.22, 38.99, 42.23, 45.22, 48.35, 53.31, 60.79, 80.75]			
2847	-cdt		292	1.37	[30.62, 33.67, 36.54, 38.79, 40.49, 42.47, 44.96, 47.99, 58.93]			
2848	-cea	ug/l	86	4.65	[3.1, 9.87, 23.18, 47.35, 90.88, 239.06, 434.92, 1210.15, 2504]	-Karsinoembryonaalinen antigeeni		
2849	-cea		53	92.45		-Karsinoembryonaalinen antigeeni		
2850	-ckdrc		147	100				
2851	-copdrc		147	100				
2852	-cvdrc		147	100				
2853	-fibrc		132	100				
2854	-lcrc		147	100				
2855	-mikrx		1661	100				
2856	-mirc		148	100				
2857	-pocabrc		33861	100				
2858	-t2drc		147	100				
2859	ab-cl	mmol/l	1123	0	[96.64, 99.82, 102.03, 103.89, 105.04, 106.49, 107.98, 109, 111.24]		Arterial blood	Clearance
2860	ap-cl	mmol/l	271	0	[96.28, 101.75, 104, 105.96, 106.88, 108.5, 109.98, 111, 113.99]			Clearance
2861	ap-cl		84	100				Clearance
2862	b-cl	mmol/l	51262	0	[99.38, 101.96, 103.79, 105, 106, 107.03, 108.25, 109.83, 112.06]		Blood	Clearance
2863	b-cl		8059	100			Blood	Clearance
2864	b-co	ug/l	4244	0.02	[0.6, 0.8, 1.01, 1.32, 1.78, 2.65, 4.13, 6.51, 11.14]	B -Koboltti	Blood	
2865	b-co		508	82.87	[1, 1.19, 1.45, 1.85, 2.39, 3.11, 4.09, 5.65, 8.64]	B -Koboltti	Blood	
2866	b-cr	ug/l	3775	0.03	[0.7, 0.95, 1.16, 1.4, 1.71, 2.11, 2.73, 3.67, 5.66]	B -Kromi	Blood	
2867	b-cr		980	91.22	[1, 1.19, 1.33, 1.58, 1.87, 2.23, 2.84, 3.42, 5.01]	B -Kromi	Blood	
2868	b-crp	mg/l	5716	0	[6, 7.48, 9.51, 12.91, 18.13, 24.65, 35.56, 55.24, 90.26]		Blood	
2869	b-crp		4859	100	[5.01, 6.82, 9.01, 11.69, 15.82, 22.6, 34.13, 52.08, 90.51]		Blood	
2870	b-crpp	mg/l	6755	0	[6, 7.29, 9.3, 12.04, 16.05, 22.16, 31.16, 46.34, 77.03]		Blood	
2871	b-crpp		5630	99.98			Blood	
2872	b-cya	ug/l	25550	0.15	[60.96, 72.44, 81.82, 90.5, 100.01, 112.12, 131.37, 164.52, 225.26]	B -Syklosporiini A	Blood	
2873	b-cya		1477	75.83	[60.31, 72.57, 77.23, 85.15, 92.33, 100.16, 109.26, 128.53, 176.67]	B -Syklosporiini A	Blood	
2874	b-qr-crp	mg/l	1850	0	[6.99, 9.73, 12.78, 17.34, 23.64, 33.34, 46.59, 64.41, 89.34]		Blood	
2875	b-qr-crp		1779	77.97	[8.87, 10.54, 12.84, 17.04, 23.92, 31.93, 44.9, 64.37, 94.35]		Blood	
2876	b-trap	auc	28	0			Blood	
2877	b-trap		340	100			Blood	
2878	cb-crp	mg/l	5	0			Capillary blood	
2879	cb-crp		5411	37.63	[6.16, 8.54, 11.97, 16.56, 22.99, 33.39, 45.96, 68.35, 100.73]		Capillary blood	
2880	cp-crp	mg/l	2411	0	[6.38, 9.55, 14.09, 19.39, 27.21, 37.87, 52.13, 71.4, 106.91]			
2881	cp-crp		820	100				
2882	du-ca	*sai	6	0		dU-Kalsium	24-hour urine	
2883	du-ca	mmol	13639	0.06	[1.77, 2.75, 3.63, 4.5, 5.36, 6.29, 7.38, 8.74, 10.75]	dU-Kalsium	24-hour urine	
2884	du-ca	mmol/24h	199	0	[1.71, 2.95, 3.67, 4.41, 5.52, 6.56, 7.77, 8.93, 10.86]	dU-Kalsium	24-hour urine	
2885	du-ca		1693	100	[1.69, 2.79, 3.74, 4.57, 5.63, 6.6, 7.64, 8.78, 10.3]	dU-Kalsium	24-hour urine	
2886	du-cl	mmol	411	0	[82.14, 104.56, 124.17, 140.04, 160.81, 175.19, 203.53, 248.22, 312.26]	dU-Kloridi	24-hour urine	Clearance
2887	du-cl		94	44.68		dU-Kloridi	24-hour urine	Clearance
2888	du-cu	umol	94	0		dU-Kupari	24-hour urine	
2889	du-cu	umol/24h	127	0	[0.13, 0.17, 0.18, 0.22, 0.28, 0.36, 0.72, 3.45, 9.31]	dU-Kupari	24-hour urine	
2890	du-cu		154	89.61		dU-Kupari	24-hour urine	
2891	fp-ca	mmol/l	61661	0	[2.19, 2.25, 2.29, 2.33, 2.35, 2.38, 2.42, 2.45, 2.51]	fP-Kalsium	Fasting plasma	
2892	fp-ca		407	100	[2.26, 2.29, 2.33, 2.35, 2.39, 2.42, 2.46, 2.49, 2.53]	fP-Kalsium	Fasting plasma	
2893	fp-cga	nmol/l	10003	0	[0.72, 1.15, 1.84, 2.33, 2.82, 3.49, 4.63, 7.85, 20.09]	fP-Kromograniini A	Fasting plasma	
2894	fp-cga		571	74.96	[1.98, 2.34, 2.56, 2.88, 3.18, 3.8, 4.45, 5.57, 8.14]	fP-Kromograniini A	Fasting plasma	
2895	fp-crp	mg/l	518	0	[13.64, 18.47, 26.19, 35.26, 45.86, 56.38, 75.09, 108.99, 155.56]		Fasting plasma	
2896	fp-crp		1249	100			Fasting plasma	
2897	fs-ca	mmol/l	1580	0	[2.25, 2.3, 2.33, 2.36, 2.39, 2.41, 2.44, 2.47, 2.52]		Fasting serum	
2898	fs-ca		9	22.22			Fasting serum	
2899	fs-cga	nmol/l	6208	0.23	[0.71, 0.95, 1.19, 1.46, 1.91, 2.48, 3.38, 5.31, 12.89]	fS-Kromograniini A	Fasting serum	
2900	fs-cga	ug/l	11	0		fS-Kromograniini A	Fasting serum	
2901	fs-cga		331	31.72	[1, 1, 1, 1.15, 2, 2.14, 3.27, 4.77, 10.46]	fS-Kromograniini A	Fasting serum	
2902	mb-cl	mmol/l	2504	0				Clearance
2903	mb-cl		105	100				Clearance
2904	p-c3	g/l	14303	0.05	[0.75, 0.87, 0.95, 1.02, 1.1, 1.18, 1.26, 1.35, 1.49]	P -Komplementti C3	Plasma	
2905	p-c3		748	8.42	[0.79, 0.88, 0.96, 1.02, 1.09, 1.15, 1.23, 1.33, 1.47]	P -Komplementti C3	Plasma	
2906	p-c4	g/l	13926	0.24	[0.1, 0.13, 0.16, 0.18, 0.2, 0.22, 0.24, 0.27, 0.31]	P -Komplementti C4	Plasma	
2907	p-c4		953	31.58	[0.1, 0.14, 0.16, 0.18, 0.2, 0.23, 0.25, 0.28, 0.32]	P -Komplementti C4	Plasma	
2908	p-ca	mmol/l	424377	0.01	[2.21, 2.27, 2.31, 2.34, 2.37, 2.4, 2.44, 2.48, 2.53]	P -Kalsium	Plasma	
2909	p-ca		5509	100	[2.2, 2.23, 2.27, 2.29, 2.31, 2.34, 2.37, 2.4, 2.45]	P -Kalsium	Plasma	
2910	p-cea	ug/l	53825	2.82	[1.63, 2.05, 2.4, 2.84, 3.45, 4.35, 5.97, 10.26, 33.4]	P -Karsinoembryonaalinen antigeeni	Plasma	
2911	p-cea		10275	100	[1.18, 1.71, 2, 2.15, 2.91, 3.11, 4, 4.96, 6.64]	P -Karsinoembryonaalinen antigeeni	Plasma	
2912	p-ck	u/l	278981	0.04	[42.75, 57.91, 71.4, 86.48, 104.42, 129.43, 169.81, 254.45, 558.07]	P -Kreatiinikinaasi	Plasma	
2913	p-ck		4344	100	[45.31, 61.56, 74.99, 90.09, 107.94, 132.54, 170.8, 244.09, 411.72]	P -Kreatiinikinaasi	Plasma	
2914	p-cl	%	24	0		P -Kloridi	Plasma	Clearance
2915	p-cl	g/l	6	0		P -Kloridi	Plasma	Clearance
2916	p-cl	kpa	12	0		P -Kloridi	Plasma	Clearance
2917	p-cl	mmol/l	441381	0	[97.97, 100.96, 102.96, 104, 105.31, 106.53, 107.89, 109, 111]	P -Kloridi	Plasma	Clearance
2918	p-cl	°c	6	0		P -Kloridi	Plasma	Clearance
2919	p-cl		2019	75.09	[97.62, 101, 102.9, 104, 105, 106, 107, 108, 109.96]	P -Kloridi	Plasma	Clearance
2920	p-crp	mg/l	4268518	0.67	[2.92, 4.96, 8.11, 13.13, 21.43, 33.56, 52.29, 80.78, 133.6]	P -C-reaktiivinen proteiini	Plasma	
2921	p-crp	mg/ml	16	0		P -C-reaktiivinen proteiini	Plasma	
2922	p-crp		1815991	100	[6.82, 10.29, 14.39, 20.52, 28.92, 40.14, 52.53, 72.49, 108.3]	P -C-reaktiivinen proteiini	Plasma	
2923	p-crp.	mg/l	761	0	[1.79, 4.45, 8.67, 13.03, 19.65, 27.34, 39.42, 61.2, 104.76]		Plasma	
2924	p-crp.		275	100			Plasma	
2925	p-cu	umol/l	362	0.55	[11.79, 13.28, 14.23, 15.3, 16.25, 16.79, 17.73, 19.17, 21.08]	P -Kupari	Plasma	
2926	p-cu		81	24.69		P -Kupari	Plasma	
2927	p-hs-crp	mg/l	1315	0	[0.3, 0.48, 0.71, 1, 1.28, 1.81, 2.55, 3.83, 6.31]		Plasma	
2928	p-hs-crp		66	81.82			Plasma	
2929	pf-c3	g/l	143	0	[0.16, 0.25, 0.28, 0.33, 0.37, 0.43, 0.53, 0.59, 0.66]	Pf-Komplementti C3	Pleural fluid	
2930	pf-c3		33	100		Pf-Komplementti C3	Pleural fluid	
2931	pf-c4	g/l	129	2.33	[0.02, 0.03, 0.04, 0.05, 0.07, 0.08, 0.08, 0.1, 0.12]	Pf-Komplementti C4	Pleural fluid	
2932	pf-c4		55	87.27		Pf-Komplementti C4	Pleural fluid	
2933	pf-cea	ug/l	765	4.97	[0.7, 1.09, 1.26, 1.53, 1.94, 2.46, 4.71, 26.33, 287.42]	Pf-Karsinoembryonaalinen antigeeni	Pleural fluid	
2934	pf-cea		670	96.72		Pf-Karsinoembryonaalinen antigeeni	Pleural fluid	
2935	pocabrc		158	100				
2936	ps-crp		669	27.2	[2.78, 5.27, 7.19, 10.25, 13.91, 20.1, 30.64, 44.78, 70.53]		Pharyngeal secretion	
2937	s-c3	g/l	10697	0	[0.77, 0.9, 0.98, 1.06, 1.13, 1.22, 1.3, 1.41, 1.56]	S -Komplementti C3	Serum	
2938	s-c3		394	43.91	[0.84, 0.95, 1.01, 1.07, 1.15, 1.23, 1.3, 1.39, 1.57]	S -Komplementti C3	Serum	
2939	s-c4	g/l	10528	0	[0.1, 0.14, 0.17, 0.2, 0.22, 0.24, 0.27, 0.3, 0.34]	S -Komplementti C4	Serum	
2940	s-c4		506	57.11	[0.12, 0.15, 0.18, 0.2, 0.21, 0.24, 0.25, 0.27, 0.3]	S -Komplementti C4	Serum	
2941	s-ca	g/l	8	0		S -Kalsium	Serum	
2942	s-ca	mmol/l	20957	0	[2.23, 2.27, 2.3, 2.33, 2.36, 2.38, 2.41, 2.44, 2.49]	S -Kalsium	Serum	
2943	s-ca		114	36.84	[2.05, 2.21, 2.24, 2.28, 2.32, 2.35, 2.4, 2.42, 2.48]	S -Kalsium	Serum	
2944	s-cdt	%	102065	0.03	[0.77, 1.07, 1.3, 1.4, 1.5, 1.6, 1.7, 1.87, 2.29]	S -Desialotransferriini	Serum	
2945	s-cdt	u/l	35	0		S -Desialotransferriini	Serum	
2946	s-cdt		2936	100	[0.6, 0.7, 0.82, 0.91, 1.27, 1.5, 1.62, 1.8, 2.1]	S -Desialotransferriini	Serum	
2947	s-cea	ug/l	90194	0	[1.12, 1.4, 1.7, 2.03, 2.46, 3.05, 4.08, 6.39, 18.29]	S -Karsinoembryonaalinen antigeeni	Serum	
2948	s-cea		23960	100	[1.1, 1.33, 1.57, 1.87, 2.25, 2.74, 3.48, 4.65, 7.43]	S -Karsinoembryonaalinen antigeeni	Serum	
2949	s-cic	ugeq/ml	728	0	[2, 2.92, 3.02, 4, 5.8, 7, 9.84, 13.31, 21.56]	S -Immunokompleksit, kiertävät	Serum	
2950	s-cic		36	83.33		S -Immunokompleksit, kiertävät	Serum	
2951	s-ck	u/l	11560	0	[54.99, 68.55, 80.64, 93.92, 109.3, 128.03, 153.58, 196.75, 289.34]	S -Kreatiinikinaasi	Serum	
2952	s-ck		102	47.06		S -Kreatiinikinaasi	Serum	
2953	s-cl	mmol/l	194	0	[97.64, 100, 101, 102, 103, 104, 104.97, 106, 107]	S -Kloridi	Serum	Clearance
2954	s-crp	form	43	0		S -C-reaktiivinen proteiini	Serum	
2955	s-crp	mg/l	154758	0	[0.94, 2.08, 4.59, 6.9, 10.12, 14.11, 20.45, 32.5, 58.74]	S -C-reaktiivinen proteiini	Serum	
2956	s-crp	mg/ml	7	0		S -C-reaktiivinen proteiini	Serum	
2957	s-crp		130844	100	[2.21, 5.98, 7.05, 9.81, 12.95, 16.16, 21.56, 31.91, 52.33]	S -C-reaktiivinen proteiini	Serum	
2958	s-cu	umol/l	1531	0	[11.52, 13.1, 14.03, 15.01, 15.95, 16.9, 18.09, 19.59, 22.2]	S -Kupari	Serum	
2959	s-cu		119	31.93	[12, 13.72, 14.88, 15.5, 16.79, 17.39, 18.6, 20.95, 24.6]	S -Kupari	Serum	
2960	s-hcrp	mg/l	6474	0	[0.5, 0.74, 1.03, 1.38, 1.78, 2.32, 3.11, 4.46, 7.35]		Serum	
2961	s-hcrp		5999	100			Serum	
2962	s-hs-crp	mg/l	8489	0.04	[0.31, 0.5, 0.73, 1, 1.39, 1.95, 2.83, 4.5, 8.22]		Serum	
2963	s-hs-crp		518	74.9	[0.32, 0.51, 0.81, 1.07, 1.44, 1.81, 2.86, 4.23, 9.8]		Serum	
2964	s-hscrp	mg/l	676	0	[0.31, 0.5, 0.77, 1.01, 1.32, 1.66, 2.35, 3.75, 6.64]	S -C-reaktiivinen proteiini, herkkä menetelmä	Serum	
2965	s-hscrp		32	90.62		S -C-reaktiivinen proteiini, herkkä menetelmä	Serum	
2966	s-ictp	ug/l	801	0	[2.67, 3.25, 3.83, 4.39, 4.93, 5.79, 6.69, 8.24, 11.65]	S -Kollageeni I:n karboksiterminaalinen telopeptidi	Serum	
2967	s-ictp	âug/l	11	0		S -Kollageeni I:n karboksiterminaalinen telopeptidi	Serum	
2968	s-ictp		75	92		S -Kollageeni I:n karboksiterminaalinen telopeptidi	Serum	
2969	s-pct	ug/l	4418	0	[0.06, 0.09, 0.12, 0.16, 0.23, 0.34, 0.54, 1.02, 3.09]	S -Prokalsitoniini	Serum	
2970	s-pct		1380	91.52	[1.39, 2.18, 9.31, 12.06, 16.11, 22.8, 28.57, 42.01, 68.41]	S -Prokalsitoniini	Serum	
2971	s-ucrp	mg/l	3232	0	[0.41, 0.65, 0.99, 1.43, 1.96, 2.84, 4.14, 6.33, 10.18]		Serum	
2972	s-ucrp		418	46.41	[1, 1, 1, 2, 2, 3, 3.96, 5, 7]		Serum	
2973	ts-cc		582	100			Tissue	
2974	u-ca	mmol/l	2045	0	[0.73, 1.17, 1.57, 2.02, 2.49, 3.06, 3.75, 4.64, 6.35]	U -Kalsium	Urine	
2975	u-ca		184	66.3	[1.03, 1.34, 1.77, 1.9, 2.01, 2.25, 2.9, 4.1, 4.72]	U -Kalsium	Urine	
2976	u-co	form	15	0		U -Koboltti	Urine	
2977	u-co	nmol/l	197	0	[3.88, 5.68, 8.56, 15.21, 25.09, 42.05, 60.13, 93.37, 175.12]	U -Koboltti	Urine	
2978	u-co	ug/l	13	0		U -Koboltti	Urine	
2979	u-co		62	90.32		U -Koboltti	Urine	
2980	u-cot	ng/ml	23	0		U -Kotiniini	Urine	
2981	u-cot	ug/l	95	0	[50, 228.5, 354.33, 567.5, 741.12, 970.67, 1237.62, 1651.33, 2426]	U -Kotiniini	Urine	
2982	u-cot		422	100		U -Kotiniini	Urine	
2983	u-cr	form	8	0		U -Kromi	Urine	
2984	u-cr	ug/l	25	0		U -Kromi	Urine	
2985	u-cr	umol/l	211	0	[0.01, 0.01, 0.01, 0.02, 0.02, 0.03, 0.05, 0.06, 0.09]	U -Kromi	Urine	
2986	u-cr		259	93.82		U -Kromi	Urine	
2987	v-hct		258	1.16	[0.33, 0.36, 0.38, 0.4, 0.41, 0.42, 0.45, 0.46, 0.49]			
2988	v-ica		294	0.68	[1.08, 1.12, 1.15, 1.17, 1.19, 1.2, 1.22, 1.24, 1.27]			
2989	vp-cl	mmol/l	10892	0	[99.58, 102.16, 103.98, 105.09, 106.05, 107.05, 108.18, 109.56, 111.27]			Clearance
2990	vp-cl		175	98.29				Clearance

