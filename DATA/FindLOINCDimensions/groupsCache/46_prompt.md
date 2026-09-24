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
Here is group 46 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
2991	-ph		2628	0.72	[7.33, 7.36, 7.38, 7.4, 7.42, 7.45, 7.5, 7.5, 7.69]			
2992	-pl-12		832	100				
2993	-pl-7		832	100				
2994	ab-ph	%	24	0		aB-Happamuusaste	Arterial blood	
2995	ab-ph	form	1072	0	[7.37, 7.4, 7.41, 7.42, 7.43, 7.44, 7.46, 7.47, 7.49]	aB-Happamuusaste	Arterial blood	
2996	ab-ph	g/l	9	0		aB-Happamuusaste	Arterial blood	
2997	ab-ph	kpa	18	0		aB-Happamuusaste	Arterial blood	
2998	ab-ph	mmol/l	54	0		aB-Happamuusaste	Arterial blood	
2999	ab-ph	ph	383652	0	[7.37, 7.39, 7.41, 7.42, 7.43, 7.44, 7.45, 7.47, 7.48]	aB-Happamuusaste	Arterial blood	
3000	ab-ph	°c	9	0		aB-Happamuusaste	Arterial blood	
3001	ab-ph		18331	100	[7.34, 7.37, 7.39, 7.41, 7.43, 7.44, 7.45, 7.47, 7.49]	aB-Happamuusaste	Arterial blood	
3002	ap-ph		263	1.9	[7.34, 7.38, 7.4, 7.42, 7.43, 7.44, 7.45, 7.47, 7.49]			
3003	b-ph	ph	39803	1.65	[7.35, 7.38, 7.4, 7.41, 7.42, 7.43, 7.44, 7.46, 7.48]		Blood	
3004	b-ph		699	100	[7.3, 7.33, 7.36, 7.37, 7.39, 7.4, 7.42, 7.43, 7.46]		Blood	
3005	b-zn	umol/l	460	0		B -Sinkki	Blood	
3006	b-zn		7	100		B -Sinkki	Blood	
3007	cb-ph	ph	114490	0	[7.35, 7.37, 7.39, 7.41, 7.42, 7.43, 7.44, 7.46, 7.48]	cB-Happamuusaste	Capillary blood	
3008	cb-ph		1606	100	[7.35, 7.38, 7.39, 7.41, 7.42, 7.43, 7.44, 7.45, 7.47]	cB-Happamuusaste	Capillary blood	
3009	cfp-10	tpl	76	0	[0, 0, 0, 0, 0, 0, 0.3, 1, 4]			
3010	cfp-10	täplää	7	0				
3011	cfp-10		23	86.96				
3012	cp-ph		204	0.49	[7.38, 7.39, 7.4, 7.4, 7.41, 7.42, 7.43, 7.44, 7.45]			
3013	dcos-b1		4737	100		Diffuusiokapasiteetti, single-breath-menetelmä, tavallinen perusmittaus		
3014	di-ph		458	0.66		Di-Happamuusaste	Dialysis fluid	
3015	fl-ph		126	3.97	[4, 4, 4.4, 4.4, 4.7, 4.7, 5, 5.18, 5.8]		Vaginal discharge	
3016	fp-fe	umol/l	153451	0.03	[5.05, 7.07, 8.78, 10.33, 11.89, 13.55, 15.47, 17.95, 21.93]	fP-Rauta	Fasting plasma	
3017	fp-fe		945	100	[5.59, 7.84, 8.98, 10.51, 12.94, 14.86, 16.88, 20.32, 25.63]	fP-Rauta	Fasting plasma	
3018	fp-ph		1028	0.39	[7.33, 7.35, 7.36, 7.37, 7.38, 7.39, 7.4, 7.41, 7.43]		Fasting plasma	
3019	fp-pi	mmol/l	184053	0.09	[0.78, 0.9, 0.99, 1.07, 1.16, 1.25, 1.38, 1.56, 1.85]	fP-Fosfaatti, epäorgaaninen	Fasting plasma	
3020	fp-pi		1397	100	[0.8, 0.9, 0.98, 1.03, 1.1, 1.15, 1.22, 1.32, 1.55]	fP-Fosfaatti, epäorgaaninen	Fasting plasma	
3021	fp-pth	ng/l	133295	0	[34.85, 50.93, 66.53, 84.08, 105.67, 135.56, 179.07, 252.72, 409.81]	fP-Parathormoni	Fasting plasma	
3022	fp-pth	pmol/l	30493	0.25	[3.7, 5.09, 6.52, 8.26, 10.54, 13.68, 18.68, 27.18, 43.49]	fP-Parathormoni	Fasting plasma	
3023	fp-pth		3799	100	[31.32, 46.63, 59.95, 75.31, 93.25, 117.48, 159.35, 231.87, 406.11]	fP-Parathormoni	Fasting plasma	
3024	fp-pthint	ng/l	23	0			Fasting plasma	
3025	fp-pthint	pmol/l	1198	0	[4.22, 6.01, 8.2, 10.41, 13.62, 18.75, 25.82, 37.85, 60.31]		Fasting plasma	
3026	fp-pthint		5	100			Fasting plasma	
3027	fp-rf	iu/ml	35	0			Fasting plasma	
3028	fp-rf		130	95.38			Fasting plasma	
3029	fp-tth		164	100			Fasting plasma	
3030	fp-zn	umol/l	173	0	[8.7, 9.69, 10.49, 11.07, 11.92, 12.4, 13.03, 14.22, 15.81]	fP-Sinkki	Fasting plasma	
3031	fp-zn		33	15.15		fP-Sinkki	Fasting plasma	
3032	fs-ct	pmol/l	611	2.62	[1.47, 3.71, 7.83, 16.31, 37.51, 75.65, 158.42, 260.26, 776.83]	fS-Kalsitoniini	Fasting serum	Confirmation, confirmatory test
3033	fs-ct		423	94.09		fS-Kalsitoniini	Fasting serum	Confirmation, confirmatory test
3034	fs-fe	umol/l	41767	0	[5.04, 7.4, 9.33, 11.05, 12.95, 14.86, 16.98, 19.74, 23.76]	fS-Rauta	Fasting serum	
3035	fs-fe		1139	55.22	[4.59, 6.34, 8.28, 9.96, 11.53, 13.18, 15.02, 17.7, 22.5]	fS-Rauta	Fasting serum	
3036	fs-gh	mlu/l	6	0		fS-Kasvuhormoni	Fasting serum	
3037	fs-gh	mu/l	232	0	[0.42, 0.61, 0.85, 1.19, 1.64, 2.58, 3.61, 5.29, 18.5]	fS-Kasvuhormoni	Fasting serum	
3038	fs-gh	ug/l	4313	1.53	[0.11, 0.2, 0.33, 0.52, 0.79, 1.19, 1.8, 2.93, 5.08]	fS-Kasvuhormoni	Fasting serum	
3039	fs-gh		531	83.99	[0.12, 0.18, 0.32, 0.47, 0.72, 0.99, 1.72, 3.12, 5.18]	fS-Kasvuhormoni	Fasting serum	
3040	fs-ph	ph	31412	0	[7.38, 7.4, 7.41, 7.42, 7.43, 7.43, 7.44, 7.45, 7.47]		Fasting serum	
3041	fs-ph		84	100	[7.34, 7.36, 7.38, 7.39, 7.4, 7.4, 7.42, 7.43, 7.45]		Fasting serum	
3042	fs-pi	mmol/l	2721	0	[0.9, 0.99, 1.05, 1.1, 1.15, 1.19, 1.24, 1.31, 1.4]	fS-Fosfaatti, epäorgaaninen	Fasting serum	
3043	fs-pp	pmol/l	1167	0.34	[17.48, 24.55, 31.61, 40, 49.62, 64.67, 81, 112.71, 163.35]	fS-Haimaperäinen peptidi	Fasting serum	
3044	fs-pp		346	97.98		fS-Haimaperäinen peptidi	Fasting serum	
3045	fs-pt		238	100			Fasting serum	
3046	fs-pth	ng/l	1065	0	[30.17, 41.93, 53.8, 66, 89.35, 116.58, 157.83, 234.71, 407.87]	fS-Parathormoni	Fasting serum	
3047	fs-pth	pmol/l	5	0		fS-Parathormoni	Fasting serum	
3048	fs-pth		475	5.05	[35.06, 48.51, 61.6, 74.15, 86.09, 99.67, 117.47, 135.89, 182.62]	fS-Parathormoni	Fasting serum	
3049	fs-rf	iu/ml	1088	0	[7.49, 9, 10.02, 12.06, 14.88, 18.32, 25.47, 41.13, 108.85]		Fasting serum	
3050	fs-rf	kiu/l	98	0	[5, 5.37, 6.27, 7.94, 9, 10, 11.4, 14.3, 29]		Fasting serum	
3051	fs-rf		3875	91.02	[6, 7.36, 8, 9, 9, 10, 11.84, 17.29, 28.89]		Fasting serum	
3052	fs-tth		1093	100			Fasting serum	
3053	fyl10		507	100				
3054	gds-15		136	83.09				
3055	mb-ph	ph	3723	0	[7.31, 7.34, 7.36, 7.37, 7.38, 7.4, 7.41, 7.42, 7.44]			
3056	mb-ph		124	100	[7.3, 7.33, 7.35, 7.36, 7.38, 7.39, 7.41, 7.42, 7.44]			
3057	no-ex	form	15	0		Uloshengityskaasun typpioksidi		
3058	no-ex	ppb	282	0		Uloshengityskaasun typpioksidi		
3059	no-ex		2491	99.4		Uloshengityskaasun typpioksidi		
3060	p-ph		8006	4.71	[7.33, 7.35, 7.37, 7.38, 7.39, 7.4, 7.41, 7.42, 7.45]		Plasma	
3061	p-pthrp	pmol/l	124	15.32	[0.66, 0.76, 0.9, 1.13, 1.34, 1.86, 2.77, 3.35, 6.5]	P -Parathormonin kaltainen peptidi	Plasma	
3062	p-pthrp		744	97.45		P -Parathormonin kaltainen peptidi	Plasma	
3063	p-rf	iu/ml	17589	4.5	[7.27, 10.08, 11.06, 12.58, 14.81, 18.96, 27.11, 48.63, 104.48]	P -Reumafaktori, määritys	Plasma	
3064	p-rf	u/ml	823	0	[10, 11, 12.84, 15.16, 19.75, 26.71, 41.27, 74.96, 141.54]	P -Reumafaktori, määritys	Plasma	
3065	p-rf		38099	100	[5.01, 6.02, 7.28, 9.03, 11.04, 14.09, 19.95, 34.46, 87.31]	P -Reumafaktori, määritys	Plasma	
3066	p-zn	umol/l	3640	0.05	[8.69, 9.76, 10.41, 11.02, 11.79, 12.24, 13.01, 14, 15.74]	P -Sinkki	Plasma	
3067	p-zn		251	35.06	[7.73, 9.08, 10.07, 10.98, 11.58, 12, 12.88, 13.59, 15.59]	P -Sinkki	Plasma	
3068	pco-ex		340	100		Uloshengityskaasun hiilimonoksidipitoisuus		
3069	pf-ph	ph	29	0			Pleural fluid	
3070	pf-ph		2712	9.14	[7.22, 7.32, 7.38, 7.41, 7.44, 7.47, 7.5, 7.52, 7.57]		Pleural fluid	
3071	pf-rf	iu/ml	127	19.69	[0, 0, 3.4, 4.81, 6.75, 8.59, 16.3, 26.55, 57]		Pleural fluid	
3072	pf-rf		218	100			Pleural fluid	
3073	pl-12		1152	100			Placenta	
3074	pl-7		1152	100			Placenta	
3075	s-gh	ug/l	221	0	[0.11, 0.2, 0.41, 0.63, 0.96, 1.3, 1.79, 2.48, 3.31]		Serum	
3076	s-gh		83	71.08			Serum	
3077	s-ph	1	396621	0	[7.36, 7.38, 7.39, 7.4, 7.4, 7.42, 7.42, 7.43, 7.45]		Serum	
3078	s-ph	ph	28	0			Serum	
3079	s-ph		10375	100	[7.34, 7.36, 7.38, 7.39, 7.4, 7.41, 7.42, 7.43, 7.45]		Serum	
3080	s-rf	iu/l	9	0		S -Reumafaktori, määritys	Serum	
3081	s-rf	iu/ml	12552	0	[7.82, 9, 9.96, 10.88, 11.32, 12.12, 14, 20.84, 53.07]	S -Reumafaktori, määritys	Serum	
3082	s-rf	kiu/l	4039	0	[4.1, 5.09, 6.09, 8.12, 9, 10, 11.76, 16.34, 33.01]	S -Reumafaktori, määritys	Serum	
3083	s-rf	u/ml	2097	0	[5, 6, 7, 8, 8.93, 10, 11.06, 16.06, 37.52]	S -Reumafaktori, määritys	Serum	
3084	s-rf		24472	100	[5.04, 6.11, 7.01, 8, 8.97, 9.87, 11.12, 15.53, 39.95]	S -Reumafaktori, määritys	Serum	
3085	s-zn	umol/l	584	0	[10, 10.53, 11, 11.78, 12, 13, 13, 14, 15]		Serum	
3086	s-zn		113	42.48	[10, 10, 11, 12, 12, 12, 13, 13.2, 15]		Serum	
3087	u-ph	form	633899	0	[5, 5, 5.06, 5.5, 6, 6, 6.5, 7, 7]	U -Happamuusaste	Urine	
3088	u-ph	ph	229	0	[5, 5.5, 5.5, 5.5, 5.63, 6, 6, 6.5, 7]	U -Happamuusaste	Urine	
3089	u-ph		19369	100	[5.33, 5.5, 6, 6, 6.5, 6.82, 7, 7.2, 7.55]	U -Happamuusaste	Urine	
3090	ua-ph		453	2.43	[7.15, 7.19, 7.23, 7.25, 7.27, 7.29, 7.32, 7.34, 7.37]		Umbilical artery blood	
3091	uv-ph		165	3.64	[7.19, 7.27, 7.31, 7.33, 7.35, 7.36, 7.38, 7.39, 7.41]		Umbilical venous blood	
3092	vb-ph	form	6	0		vB-Happamuusaste	Venous blood	
3093	vb-ph	ph	175722	0	[7.31, 7.34, 7.36, 7.37, 7.38, 7.39, 7.4, 7.42, 7.44]	vB-Happamuusaste	Venous blood	
3094	vb-ph		3633	100	[7.3, 7.33, 7.35, 7.37, 7.38, 7.39, 7.41, 7.42, 7.44]	vB-Happamuusaste	Venous blood	
3095	vp-ph		5130	1.38	[7.27, 7.3, 7.32, 7.33, 7.35, 7.36, 7.37, 7.39, 7.42]			
3096	zb-ph		5775	24.09	[7.29, 7.32, 7.34, 7.35, 7.37, 7.38, 7.39, 7.41, 7.44]	zB-Happamuusaste	Central blood	

