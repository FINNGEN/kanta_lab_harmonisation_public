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
Here is group 50 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
3474	-hhpvgt		1616	100				
3475	-hhpvty		1613	100				
3476	-hmpvag		296	100				
3477	-hpv16		995	100				
3478	-hpv18		995	100				
3479	-hpvohr		993	100				
3480	-hpvpapa		1048	100				
3481	-hpvrf		302	100				
3482	-hsvag		1969	100		-Herpes simplex -virus, antigeeni		
3483	-hvag		675	100				
3484	-mpvag		253	100				
3485	-rsvag		2352	100		-RS virus, antigeeni		
3486	-vzvag		1421	100		-Vesirokkovirus, antigeeni		
3487	b-hemafc	form	50	100		B -Immunofenotyypitys, veritauti	Blood	
3488	b-hemafc		809	100		B -Immunofenotyypitys, veritauti	Blood	
3489	b-hemat		376	100			Blood	
3490	b-heparab		243	100		B -Hepariinivasta-aineet (kval)	Blood	
3491	b-heparin		106	100			Blood	
3492	b-hepartp	au/l	28	46.43		B -Hepariinitrombosytopeniatutkimus	Blood	
3493	b-hepartp	u/ml	105	0	[0, 0.02, 0.03, 0.04, 0.05, 0.07, 0.12, 0.25, 0.9]	B -Hepariinitrombosytopeniatutkimus	Blood	
3494	b-hepartp		404	98.27		B -Hepariinitrombosytopeniatutkimus	Blood	
3495	bm-hemafc	form	379	100		Bm-Immunofenotyypitys, veritauti	Bone marrow	
3496	bm-hemafc		3014	100		Bm-Immunofenotyypitys, veritauti	Bone marrow	
3497	e-hypokr	%	350	0	[0.61, 0.99, 1.25, 1.67, 2.17, 2.88, 3.78, 5.02, 7.73]		Erythrocyte	
3498	e-hypokr		17	29.41			Erythrocyte	
3499	f-hepyag		39306	100		F -Helicobacter pylori, antigeeni	Feces	
3500	hmpvag		301	100				
3501	hpvpapa		1354	100				
3502	hpvrefpapa		391	100				
3503	li-hemafc	form	62	100		Li-Leukosyyttien pintamarkkerit, likvor	Cerebrospinal fluid	
3504	li-hemafc		290	100		Li-Leukosyyttien pintamarkkerit, likvor	Cerebrospinal fluid	
3505	li-hhv6abg	eiu	14	0		Li-Human herpesvirus-6, IgG-vasta-aineet	Cerebrospinal fluid	
3506	li-hhv6abg		289	100		Li-Human herpesvirus-6, IgG-vasta-aineet	Cerebrospinal fluid	
3507	li-hhv6abm		303	100		Li-Human herpesvirus-6, IgM-vasta-aineet	Cerebrospinal fluid	
3508	li-hsv1abg	eiu	10	0		Li-Herpes simplex -virus tyyppi 1, IgG-vasta-aineet	Cerebrospinal fluid	
3509	li-hsv1abg		518	99.81		Li-Herpes simplex -virus tyyppi 1, IgG-vasta-aineet	Cerebrospinal fluid	
3510	li-hsv2abg		524	100		Li-Herpes simplex -virus tyyppi 2, IgG-vasta-aineet	Cerebrospinal fluid	
3511	li-hsvab		709	100		Li-Herpes simplex -virus, vasta-aineet	Cerebrospinal fluid	
3512	li-hsvabg	eiu	185	0	[1, 1, 1, 1.13, 2, 2, 2.27, 3.54, 5.13]	Li-Herpes simplex -virus, IgG-vasta-aineet	Cerebrospinal fluid	
3513	li-hsvabg		573	99.48		Li-Herpes simplex -virus, IgG-vasta-aineet	Cerebrospinal fluid	
3514	li-hsvabm		1304	99.85		Li-Herpes simplex -virus, IgM-vasta-aineet	Cerebrospinal fluid	
3515	li-rsvabg	eiu	10	0		Li-RS-virus, IgG-vasta-aineet	Cerebrospinal fluid	
3516	li-rsvabg		209	100		Li-RS-virus, IgG-vasta-aineet	Cerebrospinal fluid	
3517	li-vzvab		645	100		Li-Vesirokkovirus, vasta-aineet	Cerebrospinal fluid	
3518	li-vzvabg	eiu	97	0	[1, 2, 3.98, 5.05, 6, 7, 8, 9.2, 12]	Li-Vesirokkovirus, IgG-vasta-aineet	Cerebrospinal fluid	
3519	li-vzvabg		1116	100		Li-Vesirokkovirus, IgG-vasta-aineet	Cerebrospinal fluid	
3520	li-vzvabm		1207	99.92		Li-Vesirokkovirus, IgM-vasta-aineet	Cerebrospinal fluid	
3521	p-hepar10		199	100			Plasma	
3522	p-hepar5		143	100			Plasma	
3523	p-heparm		335	100			Plasma	
3524	ps-rsvag		270	100			Pharyngeal secretion	
3525	s-havab		9175	100		S -Hepatiitti A -virus, vasta-aineet	Serum	
3526	s-havabg		4154	100		S -Hepatiitti A -virus, IgG-vasta-aineet	Serum	
3527	s-havabm		9104	99.99		S -Hepatiitti A -virus, IgM-vasta-aineet	Serum	
3528	s-hbc-ab		149	100			Serum	Antibodies
3529	s-hbcab		59546	99.99		S -Hepatiitti B -virus, c-antigeeni, vasta-aineet	Serum	
3530	s-hbcabm		17017	100		S -Hepatiitti B -virus, c-antigeeni, IgM-vasta-aineet	Serum	
3531	s-hbeab		463	100		S -Hepatiitti B -virus, e-antigeeni, vasta-aineet	Serum	
3532	s-hbeag		489	100		S -Hepatiitti B -virus, e-antigeeni	Serum	
3533	s-hbs-ab	iu/l	29	0			Serum	Antibodies
3534	s-hbs-ab	miu/ml	28	0			Serum	Antibodies
3535	s-hbs-ab		99	98.99			Serum	Antibodies
3536	s-hbs-ag		1216	100			Serum	Antigen
3537	s-hbsab	form	14	0		S -Hepatiitti B -virus, s-antigeeni, vasta-aineet	Serum	
3538	s-hbsab	iu/l	1599	0	[19, 31.77, 54.35, 84.13, 122, 176.21, 262.66, 397.08, 597.7]	S -Hepatiitti B -virus, s-antigeeni, vasta-aineet	Serum	
3539	s-hbsab	miu/ml	7356	0	[18.95, 32.32, 49.92, 78.18, 122.93, 187.51, 279.59, 419.01, 639.02]	S -Hepatiitti B -virus, s-antigeeni, vasta-aineet	Serum	
3540	s-hbsab	mlu/l	54	0		S -Hepatiitti B -virus, s-antigeeni, vasta-aineet	Serum	
3541	s-hbsab	u/l	1350	6.15	[9.93, 20.72, 40.25, 72.7, 118.58, 187.38, 285.72, 440.19, 651.87]	S -Hepatiitti B -virus, s-antigeeni, vasta-aineet	Serum	
3542	s-hbsab		12550	95.41	[15.57, 27.14, 43.48, 69.4, 103.28, 154.27, 226.13, 338.05, 561.62]	S -Hepatiitti B -virus, s-antigeeni, vasta-aineet	Serum	
3543	s-hbsag		144696	100		S -Hepatiitti B -virus, s-antigeeni	Serum	
3544	s-hbvpak		24059	100			Serum	
3545	s-hcv-ab		438	100			Serum	Antibodies
3546	s-hcvab		100621	100		S -Hepatiitti C -virus, vasta-aineet	Serum	
3547	s-hdvab		143	100		S -Hepatiitti D -virus, vasta-aineet	Serum	
3548	s-hepabc		359	100			Serum	
3549	s-hepbc		328	100			Serum	
3550	s-hephiv		965	100			Serum	
3551	s-hepsid	mmol/l	17	0		S -Hepsidiini	Serum	
3552	s-hepsid	nmol/l	874	0	[0.98, 1.94, 3.01, 4.16, 5.28, 6.67, 8.4, 11.41, 16.63]	S -Hepsidiini	Serum	
3553	s-hepsid		167	72.46		S -Hepsidiini	Serum	
3554	s-hepyab	titre	8	0		S -Helicobacter pylori, vasta-aineet	Serum	
3555	s-hepyab		9548	99.99		S -Helicobacter pylori, vasta-aineet	Serum	
3556	s-hepyaba	form	31	0		S -Helicobacter pylori, IgA-vasta-aineet	Serum	
3557	s-hepyaba	responseequivalent	57	0		S -Helicobacter pylori, IgA-vasta-aineet	Serum	
3558	s-hepyaba	u/ml	4166	0	[0.18, 3.77, 9.98, 10.53, 11.11, 12.11, 13.82, 17.92, 34.55]	S -Helicobacter pylori, IgA-vasta-aineet	Serum	
3559	s-hepyaba		5753	91	[10.05, 10.89, 11.84, 13.04, 15.94, 20.68, 28.21, 44.98, 68.99]	S -Helicobacter pylori, IgA-vasta-aineet	Serum	
3560	s-hepyabg	eiu	206	0	[13.4, 14.01, 14.89, 15.13, 15.52, 16, 16.8, 17, 17.01]	S -Helicobacter pylori, IgG-vasta-aineet	Serum	
3561	s-hepyabg	form	34	0		S -Helicobacter pylori, IgG-vasta-aineet	Serum	
3562	s-hepyabg	index	1120	17.32	[0.9, 1.02, 1.22, 1.53, 2.04, 2.76, 4.07, 5.29, 6.95]	S -Helicobacter pylori, IgG-vasta-aineet	Serum	
3563	s-hepyabg	responseequivalent	58	0		S -Helicobacter pylori, IgG-vasta-aineet	Serum	
3564	s-hepyabg	ru/ml	38	0		S -Helicobacter pylori, IgG-vasta-aineet	Serum	
3565	s-hepyabg	titre	62	0		S -Helicobacter pylori, IgG-vasta-aineet	Serum	
3566	s-hepyabg	u/ml	5402	0	[0.1, 0.1, 0.4, 9.38, 10.67, 11.64, 13.81, 23.95, 82.4]	S -Helicobacter pylori, IgG-vasta-aineet	Serum	
3567	s-hepyabg		13707	100	[0.91, 2.69, 9.02, 13.64, 31.12, 78.13, 178.77, 411.46, 1645.81]	S -Helicobacter pylori, IgG-vasta-aineet	Serum	
3568	s-hevab		4256	100		S -Hepatiitti E -virus, vasta-aineet	Serum	
3569	s-hevabg	index	20	0			Serum	
3570	s-hevabg		3510	99.23			Serum	
3571	s-hevabm	index	5	0			Serum	
3572	s-hevabm		3523	99.77			Serum	
3573	s-hhv6ab		659	100		S -Human herpes -virus 6, vasta-aineet	Serum	
3574	s-hhv6abg	eiu	758	0	[27.3, 41.22, 53.01, 65.79, 78.44, 90.61, 102.22, 122.47, 145.95]	S -Human herpesvirus-6, IgG-vasta-aineet	Serum	
3575	s-hhv6abg		274	95.99		S -Human herpesvirus-6, IgG-vasta-aineet	Serum	
3576	s-hhv6abm		1034	100		S -Human herpesvirus-6, IgM-vasta-aineet	Serum	
3577	s-hivab		231	27.71	[0.07, 0.07, 0.07, 0.08, 0.08, 0.08, 0.08, 0.09, 0.09]	S -HI-virus, vasta-aineet	Serum	
3578	s-hivag		188	12.23	[0.17, 0.18, 0.19, 0.19, 0.2, 0.2, 0.21, 0.21, 0.22]	S -HI-virus, antigeeni	Serum	
3579	s-hsv1abg	au	65	0	[2.9, 8.85, 14, 22, 25.75, 29.67, 35, 43.5, 55]	S -Herpes simplex -virus tyyppi 1, IgG-vasta-aineet	Serum	
3580	s-hsv1abg	eiu	599	0	[37.79, 64.98, 88.04, 107.91, 120.93, 129.58, 134.43, 142.85, 153.52]	S -Herpes simplex -virus tyyppi 1, IgG-vasta-aineet	Serum	
3581	s-hsv1abg	index	163	0	[0.09, 0.11, 0.16, 0.33, 0.91, 4.45, 19.55, 33.49, 43.15]	S -Herpes simplex -virus tyyppi 1, IgG-vasta-aineet	Serum	
3582	s-hsv1abg	responseequivalent	38	0		S -Herpes simplex -virus tyyppi 1, IgG-vasta-aineet	Serum	
3583	s-hsv1abg	u/ml	12	0		S -Herpes simplex -virus tyyppi 1, IgG-vasta-aineet	Serum	
3584	s-hsv1abg		1877	85.14	[0.09, 0.12, 0.17, 0.27, 0.69, 4.2, 16.16, 30.2, 44.78]	S -Herpes simplex -virus tyyppi 1, IgG-vasta-aineet	Serum	
3585	s-hsv2abg	au	44	0		S -Herpes simplex -virus tyyppi 2, IgG-vasta-aineet	Serum	
3586	s-hsv2abg	eiu	296	0	[31.65, 47.88, 68.73, 86.77, 103.03, 115.89, 125.25, 138.53, 150.95]	S -Herpes simplex -virus tyyppi 2, IgG-vasta-aineet	Serum	
3587	s-hsv2abg	index	50	0		S -Herpes simplex -virus tyyppi 2, IgG-vasta-aineet	Serum	
3588	s-hsv2abg	responseequivalent	16	0		S -Herpes simplex -virus tyyppi 2, IgG-vasta-aineet	Serum	
3589	s-hsv2abg		2345	96.93		S -Herpes simplex -virus tyyppi 2, IgG-vasta-aineet	Serum	
3590	s-hsvab		3444	99.97		S -Herpes simplex -virus, vasta-aineet	Serum	
3591	s-hsvabg	eiu	515	0	[21.39, 43.72, 57.54, 70.53, 79.57, 85.04, 89.83, 93.92, 98.16]	S -Herpes simplex -virus, IgG-vasta-aineet	Serum	
3592	s-hsvabg		795	95.97		S -Herpes simplex -virus, IgG-vasta-aineet	Serum	
3593	s-hsvabm	index	64	0		S -Herpes simplex -virus, IgM-vasta-aineet	Serum	
3594	s-hsvabm	responseequivalent	5	0		S -Herpes simplex -virus, IgM-vasta-aineet	Serum	
3595	s-hsvabm		3792	97.65	[0.6, 0.69, 0.78, 0.87, 1.06, 1.19, 1.39, 1.64, 2.15]	S -Herpes simplex -virus, IgM-vasta-aineet	Serum	
3596	s-rsvab	eiu	95	0	[34, 45.5, 50.7, 55.7, 58, 64.15, 70.27, 77.1, 83]	S -RS-virus, vasta-aineet	Serum	
3597	s-rsvab		11	90.91		S -RS-virus, vasta-aineet	Serum	
3598	s-rsvabg	eiu	136	0	[38.2, 47.41, 50.26, 54.36, 60.04, 65.73, 72.76, 79.09, 88.75]		Serum	
3599	s-vzvab		8236	100		S -Vesirokkovirus, vasta-aineet	Serum	
3600	s-vzvabg	eiu	3820	0	[24.18, 37.35, 48.31, 57.13, 64.56, 71.64, 77.77, 84.51, 94.15]	S -Vesirokkovirus, IgG-vasta-aineet	Serum	
3601	s-vzvabg	index	536	0	[20, 26, 28, 30, 31.5, 33.65, 34.1, 36, 37]	S -Vesirokkovirus, IgG-vasta-aineet	Serum	
3602	s-vzvabg	iu/l	1366	0	[333.2, 482.4, 785.22, 1123.07, 1511.68, 1948.64, 2434.36, 3067.64, 3853.22]	S -Vesirokkovirus, IgG-vasta-aineet	Serum	
3603	s-vzvabg	miu/ml	1474	0	[369.94, 599.46, 803.23, 1019.75, 1274.09, 1497.16, 1736.09, 2006.74, 2432.06]	S -Vesirokkovirus, IgG-vasta-aineet	Serum	
3604	s-vzvabg	titre	9	0		S -Vesirokkovirus, IgG-vasta-aineet	Serum	
3605	s-vzvabg	u/l	57	0		S -Vesirokkovirus, IgG-vasta-aineet	Serum	
3606	s-vzvabg		1959	75.04	[14, 24, 44.23, 66.86, 242.1, 596.21, 1160.85, 1378, 1997]	S -Vesirokkovirus, IgG-vasta-aineet	Serum	
3607	s-vzvabm		8214	98.72		S -Vesirokkovirus, IgM-vasta-aineet	Serum	
3608	ts-hemafc	form	226	100		Ts-Immunofenotyypitys, veritauti	Tissue	
3609	ts-hemafc		968	100		Ts-Immunofenotyypitys, veritauti	Tissue	
3610	ts-hepyvi		1842	100		Ts-Helicobacter pylori, viljely	Tissue	
3611	vt-hbcab		168	100			Point-of-care test	
3612	vt-hbsab	iu/l	127	0	[19.4, 30.6, 48.47, 86.76, 128.56, 163.81, 270.62, 379.65, 598.18]		Point-of-care test	
3613	vt-hbsab		81	93.83			Point-of-care test	
3614	vt-hbsag		616	100			Point-of-care test	
3615	vt-hcvab		764	100			Point-of-care test	
3616	vt-hcvkomb		281	100			Point-of-care test	
3617	vt-phivab		510	100			Point-of-care test	

