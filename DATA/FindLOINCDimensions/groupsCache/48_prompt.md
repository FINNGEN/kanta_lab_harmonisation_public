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
Here is group 48 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
3266	-dnaex		2688	100		-DNA, eristys		
3267	3990ts-fnab		124	100				
3268	angap		175	0.57	[14.85, 15.92, 16.89, 17.73, 18.42, 19.06, 19.77, 20.81, 22.33]			
3269	b-angap	mmol/l	51115	0	[6.69, 8, 9, 10, 10.99, 11.88, 12.82, 13.99, 16.06]		Blood	
3270	b-angap		8172	98.31			Blood	
3271	b-anionivaje	mmol/l	9473	0	[7.5, 9.23, 10.69, 11.71, 12.52, 13.27, 14.22, 15.85, 17.88]		Blood	
3272	b-anionivaje		60	83.33			Blood	
3273	b-dnabpg		104	100			Blood	
3274	b-dnaex	form	420	100			Blood	
3275	b-dnaex		767	100			Blood	
3276	b-dnamut	form	581	100			Blood	
3277	b-dnamut		1586	100			Blood	
3278	b-rna.kt		166	100			Blood	
3279	bm-cd138ex		345	100			Bone marrow	
3280	bm-dnaex	form	45	100			Bone marrow	
3281	bm-dnaex		139	100			Bone marrow	
3282	bm-dnamut	form	33	100			Bone marrow	
3283	bm-dnamut		120	100			Bone marrow	
3284	c-anca	titre	6	0				
3285	c-anca		204	100				
3286	dnaex	form	31	100				
3287	dnaex		70	100				
3288	e-anti-c3d		171	100			Erythrocyte	
3289	e-anti-igg		171	100			Erythrocyte	
3290	f-antitry	ug/g	536	0.93	[46.14, 71.73, 99.84, 124.79, 149.61, 181.17, 224, 290.92, 448.27]	F -Alfa-1-antitrypsiini	Feces	
3291	f-antitry		135	98.52		F -Alfa-1-antitrypsiini	Feces	
3292	kannab		107	100				
3293	p-anca	titre	14	0			Plasma	
3294	p-anca		196	100			Plasma	
3295	p-angap	mmol/l	4593	0	[6, 7, 7.97, 8.14, 9, 9.81, 10.22, 11.25, 13.52]	P -Anionivaje	Plasma	
3296	p-angap		234	99.15		P -Anionivaje	Plasma	
3297	p-antifxa	iu/ml	22497	0		P -Antifactori X-aktiivisuus (hepariinin estovaikutus aktivoituneeseen hyytymistekijä X)	Plasma	
3298	p-antifxa	u/ml	13200	1.46		P -Antifactori X-aktiivisuus (hepariinin estovaikutus aktivoituneeseen hyytymistekijä X)	Plasma	
3299	p-antifxa	umol/l	15	0		P -Antifactori X-aktiivisuus (hepariinin estovaikutus aktivoituneeseen hyytymistekijä X)	Plasma	
3300	p-antifxa		11624	100		P -Antifactori X-aktiivisuus (hepariinin estovaikutus aktivoituneeseen hyytymistekijä X)	Plasma	
3301	p-antitro	%	48	0			Plasma	
3302	p-antitro		79	1.27	[85, 94, 96.8, 102, 104, 108, 110.45, 114, 120]		Plasma	
3303	pt-vainaja		1675	100			Patient	
3304	s-adeabcf	titre	53	0			Serum	
3305	s-adeabcf		79	91.14			Serum	
3306	s-adencf	titre	486	0	[8, 8, 8, 9.27, 16, 16, 32, 32, 61.45]		Serum	
3307	s-adencf		563	92.18			Serum	
3308	s-ana(ait)	titre	114	0	[200, 200, 200, 200, 400, 400, 400, 1600, 6400]		Serum	
3309	s-ana(ait)		148	100			Serum	
3310	s-ana-ab	titre	35	0			Serum	Antibodies
3311	s-ana-ab		264	87.5			Serum	Antibodies
3312	s-ana-ib		333	100			Serum	
3313	s-ana-ty	u/ml	16	0		S -Tuma, vasta-aineet, tyypitys	Serum	Typing
3314	s-ana-ty		7772	100		S -Tuma, vasta-aineet, tyypitys	Serum	Typing
3315	s-anaab-a		1785	100			Serum	
3316	s-anaabbl		2553	100			Serum	
3317	s-anaty-jt		273	100			Serum	Follow-up test
3318	s-anca		14067	100		S -Neutrofiilien sytoplasma-antigeeni, vasta-aineet	Serum	
3319	s-anca-t		5077	100			Serum	
3320	s-ancabk		422	100			Serum	
3321	s-ancak		258	100			Serum	
3322	s-ancatut		579	100			Serum	
3323	s-ancif	titre	76	100			Serum	
3324	s-ancif		592	100			Serum	
3325	s-antitry	g/l	6556	0.03	[1.12, 1.23, 1.3, 1.39, 1.45, 1.51, 1.61, 1.74, 1.97]	S -Alfa-1-antitrypsiini	Serum	
3326	s-antitry		624	12.98	[0.99, 1.16, 1.29, 1.3, 1.4, 1.5, 1.6, 1.81, 2]	S -Alfa-1-antitrypsiini	Serum	
3327	s-c-anca	titre	307	0	[20, 20, 40, 40, 80, 147.56, 160, 160, 454.4]		Serum	
3328	s-c-anca		9115	99.69			Serum	
3329	s-c-ancab		281	100			Serum	
3330	s-c-ancif	titre	185	0	[20, 43.36, 50, 50, 50, 200, 200, 200, 1280]		Serum	
3331	s-c-ancif		4511	99.8			Serum	
3332	s-c-def		1357	100		S -Komplementti, puutostutkimus	Serum	
3333	s-c3nef		163	100		S -C3-Nefriittitekijä	Serum	
3334	s-envabcf	titre	46	0			Serum	
3335	s-envabcf		84	100			Serum	
3336	s-inaabcf	titre	44	0			Serum	
3337	s-inaabcf		94	92.55			Serum	
3338	s-inbabcf	titre	68	0			Serum	
3339	s-inbabcf		70	91.43			Serum	
3340	s-infacf	titre	321	0	[8, 8, 8, 8, 8, 8, 16, 16, 28.44]		Serum	
3341	s-infacf		741	96.09			Serum	
3342	s-infbcf	titre	595	0	[8, 8, 8, 8, 8, 16, 16, 19.59, 32]		Serum	
3343	s-infbcf		453	89.62			Serum	
3344	s-mpnabcf	titre	14	0			Serum	
3345	s-mpnabcf		110	99.09			Serum	
3346	s-myplcf	titre	111	0	[8, 8, 8, 8, 16, 16, 32, 32, 128]		Serum	
3347	s-myplcf		976	99.59			Serum	
3348	s-p-anca	titre	893	0	[40, 62.5, 80, 80, 136.68, 160, 160, 320, 640]		Serum	
3349	s-p-anca		8530	99.21			Serum	
3350	s-p-ancab	titre	31	0			Serum	
3351	s-p-ancab		277	100			Serum	
3352	s-p-ancif	titre	1211	0	[20, 40.83, 50, 50, 50, 200, 200, 200, 800.06]		Serum	
3353	s-p-ancif		3497	99.03			Serum	
3354	s-pigf	ng/l	164	0	[54.7, 69.85, 87.5, 110.43, 131.4, 154.41, 196.98, 259.73, 391.79]	S -Plasentaalinen kasvutekijä	Serum	
3355	s-pincf	titre	710	0	[8, 8, 11.23, 16, 16, 16, 32, 32, 60.38]		Serum	
3356	s-pincf		336	84.23			Serum	
3357	s-pinfabcf	titre	89	0	[8, 8, 8, 8, 16, 16, 16, 32, 64]		Serum	
3358	s-pinfabcf		48	83.33			Serum	
3359	s-plgf	ng/l	289	0	[58.56, 79.17, 105.84, 126.29, 158.94, 206.43, 290.3, 409.86, 646.78]		Serum	
3360	s-qfevcf	titre	16	0			Serum	
3361	s-qfevcf		211	100			Serum	
3362	s-rsvabcf	titre	77	0	[8, 8, 8, 8, 8, 12.4, 16, 16, 32]		Serum	
3363	s-rsvabcf		61	93.44			Serum	
3364	s-rsvcf	titre	604	0	[8, 8, 8, 8, 8, 16, 16, 19.67, 32]		Serum	
3365	s-rsvcf		446	90.81			Serum	
3366	s-vancom	mg/l	138	0			Serum	
3367	s-vancom		5	40			Serum	
3368	ts-dnafc	form	35	100		Ts-DNA, virtaussytometria	Tissue	
3369	ts-dnafc		466	100		Ts-DNA, virtaussytometria	Tissue	
3370	ts-dnaflow		349	100			Tissue	
3371	ts-dnamut	form	104	100			Tissue	
3372	ts-dnamut		321	100			Tissue	
3373	ts-fnab		13544	100		Ts-Ohutneulabiopsiatutkimus	Tissue	
3374	ts-fnab-p		220	100			Tissue	Upright (standing)
3375	u-annat	/sunf	104	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Urine	
3376	u-annat		2048	100			Urine	
3377	u-canna-o	estimate	206	100		U -Kannabis (kval)	Urine	Qualitative test (also semi-quantitative)
3378	u-canna-o		53007	100		U -Kannabis (kval)	Urine	Qualitative test (also semi-quantitative)
3379	u-cannact	form	7	100		U -Kannabis, varmistus	Urine	
3380	u-cannact		654	100		U -Kannabis, varmistus	Urine	
3381	vainaja		148	100				

