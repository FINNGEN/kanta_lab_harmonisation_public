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
Here is group 9 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
485	!pak.maitoigavasta-aineet	%	131	0	[0.58, 0.82, 1.2, 1.91, 2.91, 4.04, 5.35, 9.13, 17.95]			
486	!pak.maitoigavasta-aineet		16	100				
487	!pak.maitoiggvasta-aineet	%	145	0	[0.98, 1.7, 2.32, 3.27, 4.38, 5.93, 8.46, 13.11, 27.46]			
488	-mikrobi-x,vasta-aineet		268	100				
489	allergeeni,igevasta-aineet		105	100				
490	beeta-2-glykoproteiini,iggvasta-aineet,plasma	u/ml	116	0	[1, 1, 1, 1, 2, 2, 2, 2, 3.3]			
491	beeta-2-glykoproteiini,iggvasta-aineet,plasma		91	100				
492	beeta-2-glykoproteiini,igmvasta-aineet,plasma	u/ml	47	0				
493	beeta-2-glykoproteiini,igmvasta-aineet,plasma		142	100				
494	borrelia,vasta-aineet		221	100				
495	dna,natiivi,vasta-aineet	kiu/l	113	0	[0.66, 1, 1.3, 1.95, 4.9, 8.44, 12.27, 34.2, 177.33]			
496	dna,natiivi,vasta-aineet		32	100				
497	fosfolipidi,vasta-aineet,plasma		126	100				
498	glutamaattidekarboksylaasi,vasta-aineet	iu/ml	8	0				
499	glutamaattidekarboksylaasi,vasta-aineet		94	100				
500	histidyyli-trna-syntetaasi,vasta-aineet,seerumista␤		175	100				
501	infliksimabi,vasta-aineet		105	100				
502	kardiolipiini,iggvasta-aineet,plasma	gpl	113	0	[1, 1, 1.24, 2, 2, 2, 3, 3, 7.55]			
503	kardiolipiini,iggvasta-aineet,plasma	u/ml	20	0				
504	kardiolipiini,iggvasta-aineet,plasma		74	100				
505	kardiolipiini,igmvasta-aineet,plasma	mpl	122	0	[1, 1.64, 2, 2, 2.5, 3.32, 4.19, 6, 7.9]			
506	kardiolipiini,igmvasta-aineet,plasma	u/ml	12	0				
507	kardiolipiini,igmvasta-aineet,plasma		55	100				
508	keliakiavasta-aineet		299	100				
509	myeloperoksidaasi,vasta-aine		128	100				
510	p-beeta-2-glykoproteiini,iggvasta-aine	u/ml	126	0	[1, 1, 1, 1, 1.27, 2, 2, 2.84, 4.7]		Plasma	
511	p-beeta-2-glykoproteiini,iggvasta-aine		77	97.4			Plasma	
512	p-kardiolipiini,iggvasta-aineet	u/ml	185	0	[1, 1, 1.87, 2, 2, 2, 3.07, 5, 17.78]		Plasma	
513	p-kardiolipiini,iggvasta-aineet		61	100			Plasma	
514	p-punasoluvasta-aineet		17054	100			Plasma	
515	p-tyreoideaperoksidaasi,vasta-aineet	u/ml	54	0			Plasma	
516	p-tyreoideaperoksidaasi,vasta-aineet		85	100			Plasma	
517	proteinaasi3,vasta-aineet	u/ml	7	0				
518	proteinaasi3,vasta-aineet		121	100				
519	s-borrelia,iggvasta-aineet	au/ml	106	0	[11, 15.5, 20.88, 33.53, 46.89, 59.61, 76.12, 124, 164]		Serum	
520	s-borrelia,iggvasta-aineet	responseequivalent/ml	6	0			Serum	
521	s-borrelia,iggvasta-aineet	u/ml	19	0			Serum	
522	s-borrelia,iggvasta-aineet		651	100			Serum	
523	s-borrelia,igmvasta-aineet	au/ml	71	0	[5, 7, 8.59, 9.85, 13.89, 19, 21.35, 27, 43]		Serum	
524	s-borrelia,igmvasta-aineet	responseequivalent/ml	6	0			Serum	
525	s-borrelia,igmvasta-aineet	ru/ml	14	0			Serum	
526	s-borrelia,igmvasta-aineet		604	100			Serum	
527	s-borrelia,vasta-aineet	form	8	0			Serum	
528	s-borrelia,vasta-aineet		381	100			Serum	
529	s-borrelia,vasta-aineet,lausunto		164	100			Serum	
530	s-borreliaigg,vasta-aineet	au/ml	14	0			Serum	
531	s-borreliaigg,vasta-aineet		170	100			Serum	
532	s-borreliaigm,vasta-aineet		184	100			Serum	
533	s-dna,natiivi,vasta-aineet	iu/ml	23	0			Serum	
534	s-dna,natiivi,vasta-aineet	kiu/l	324	0	[0.67, 0.89, 1.05, 1.27, 1.52, 2.09, 3.24, 6.81, 20.66]		Serum	
535	s-dna,natiivi,vasta-aineet		289	100			Serum	
536	s-endomysium,igavasta-aineet	titre	23	0			Serum	
537	s-endomysium,igavasta-aineet		903	100			Serum	
538	s-endomysium,iggvasta-aineet		170	100			Serum	
539	s-fosfolipaasi-a2-reseptori,vasta-aineet	titre	34	0			Serum	
540	s-fosfolipaasi-a2-reseptori,vasta-aineet		81	100			Serum	
541	s-francisellatularensis,vasta-aineet	titre	5	0			Serum	
542	s-francisellatularensis,vasta-aineet		106	100			Serum	
543	s-glomerulustyvikalvo,vasta-aineet		162	100			Serum	
544	s-glutamaattidekarboksylaasi(gad),vasta-aineet	iu/ml	61	0			Serum	
545	s-glutamaattidekarboksylaasi(gad),vasta-aineet		203	100			Serum	
546	s-helicobakt.vasta-ainee		227	100			Serum	
547	s-hevonen,igevasta-aineet	u/ml	20	0			Serum	
548	s-hevonen,igevasta-aineet		97	100			Serum	
549	s-histidyyli-trna-syntetaasi,vasta-aineet	u/ml	11	0			Serum	
550	s-histidyyli-trna-syntetaasi,vasta-aineet		428	100			Serum	
551	s-infliksimabi,vasta-aineet	au/ml	15	0			Serum	
552	s-infliksimabi,vasta-aineet		103	100			Serum	
553	s-kissa,igevasta-aineet	u/ml	39	0			Serum	
554	s-kissa,igevasta-aineet		78	100			Serum	
555	s-koivu,igevasta-aineet	u/ml	67	0	[0.03, 0.08, 0.23, 0.59, 1.4, 3.26, 5.01, 19.8, 33.1]		Serum	
556	s-koivu,igevasta-aineet		37	100			Serum	
557	s-kudos,vasta-aineet		375	100			Serum	
558	s-kudosvasta-aineet		224	100			Serum	
559	s-maapähkinä,igevasta-aineet	u/ml	26	0			Serum	
560	s-maapähkinä,igevasta-aineet		76	100			Serum	
561	s-maksa-jamunuaismikrosomi,vasta-aineet		105	100			Serum	
562	s-mitokondria,vasta-aineet		185	100			Serum	
563	s-mononukleoosi,vasta-aineet(kval)		122	100			Serum	
564	s-myeloperoksidaasi,iggvasta-aineet	iu/ml	18	0			Serum	
565	s-myeloperoksidaasi,iggvasta-aineet		218	100			Serum	
566	s-myeloperoksidaasi,vasta-aineet	iu/ml	17	0			Serum	
567	s-myeloperoksidaasi,vasta-aineet	kiu/l	25	0			Serum	
568	s-myeloperoksidaasi,vasta-aineet	u/ml	16	0			Serum	
569	s-myeloperoksidaasi,vasta-aineet		306	100			Serum	
570	s-myosiittitutkimus,vasta-aineet		219	100			Serum	
571	s-parvovirus,iggvasta-aineet	index	16	0			Serum	
572	s-parvovirus,iggvasta-aineet	iu/ml	12	0			Serum	
573	s-parvovirus,iggvasta-aineet		128	100			Serum	
574	s-parvovirus,igmvasta-aineet		156	98.72			Serum	
575	s-parvovirus,vasta-aineet		148	100			Serum	
576	s-proteinaasi3,vasta-aineet	iu/ml	40	0			Serum	
577	s-proteinaasi3,vasta-aineet	kiu/l	22	0			Serum	
578	s-proteinaasi3,vasta-aineet	u/ml	15	0			Serum	
579	s-proteinaasi3,vasta-aineet		617	100			Serum	
580	s-ribonukeliiniproteiini70,vasta-aineet	u/ml	181	0	[1, 1, 2, 2, 2, 2.7, 3, 3, 4]		Serum	
581	s-ribonukeliiniproteiini70,vasta-aineet		834	100			Serum	
582	s-ribonukleoproteiini,vasta-aineet	u/ml	9	0			Serum	
583	s-ribonukleoproteiini,vasta-aineet		188	100			Serum	
584	s-ribosomip-proteiini,vasta-aineet,immunoblott		174	100			Serum	
585	s-sentromeeri(cenp-b),vasta-aineet		286	100			Serum	
586	s-sentromeeri,vasta-aineet	u/ml	55	0			Serum	
587	s-sentromeeri,vasta-aineet		239	100			Serum	
588	s-sentromeerip,vasta-aineet	u/ml	47	0			Serum	
589	s-sentromeerip,vasta-aineet		1047	100			Serum	
590	s-sileälihas,vasta-aineet	titre	16	0			Serum	
591	s-sileälihas,vasta-aineet		155	99.35			Serum	
592	s-sitrulliinipeptidi,vasta-aineet	u/ml	1423	0	[0.71, 0.89, 1, 1.1, 1.24, 1.4, 1.59, 2.08, 17.92]		Serum	
593	s-sitrulliinipeptidi,vasta-aineet		1490	100			Serum	
594	s-sitrulliinipeptidi,vasta-aineet␤	u/ml	133	0			Serum	
595	s-sitrulliinipeptidi,vasta-aineet␤		6	100			Serum	
596	s-skleroderma,vasta-aineet	u/ml	43	0			Serum	
597	s-skleroderma,vasta-aineet		66	100			Serum	
598	s-skleroderma70,vasta-aineet	u/ml	31	0			Serum	
599	s-skleroderma70,vasta-aineet		614	100			Serum	
600	s-sm(smith),vasta-aineet	u/ml	52	0			Serum	
601	s-sm(smith),vasta-aineet		598	99.83			Serum	
602	s-syklinensitrullinoitupeptidi,vasta-aineet	u/ml	17	0			Serum	
603	s-syklinensitrullinoitupeptidi,vasta-aineet		465	100			Serum	
604	s-treponeemapallidum,vasta-aineet		114	100			Serum	
605	s-treponemapallidum,vasta-aineet		4461	100			Serum	
606	s-treponemapallidum,vasta-aineetosatutkimus		123	100			Serum	
607	s-tsh-reseptori,vasta-aineet	iu/l	348	0	[1.8, 2.06, 2.33, 2.68, 3.16, 3.57, 4.44, 6.54, 13.38]		Serum	
608	s-tsh-reseptori,vasta-aineet		426	100			Serum	
609	s-tsh-reseptori,vasta-aineet␤	iu/l	77	0			Serum	
610	s-tsh-reseptori,vasta-aineet␤		75	100			Serum	
611	s-tuma,vasta-aineet	titre	287	0	[160, 163.43, 294.88, 320, 320, 320, 325.33, 640, 1280]		Serum	
612	s-tuma,vasta-aineet		1361	99.78			Serum	
613	s-tyreoglobuliini,vasta-aineet	iu/ml	210	0	[12, 13, 13.17, 14.36, 16.67, 19.36, 26.25, 107.83, 195.17]		Serum	
614	s-tyreoglobuliini,vasta-aineet	u/ml	52	0			Serum	
615	s-tyreoglobuliini,vasta-aineet		426	100			Serum	
616	s-tyreoideaperoksidaasi,vasta-aineet	form	5	0			Serum	
617	s-tyreoideaperoksidaasi,vasta-aineet	iu/ml	206	0	[9, 10.66, 14.35, 27.21, 39.33, 64.83, 137.41, 208.91, 474.72]		Serum	
618	s-tyreoideaperoksidaasi,vasta-aineet	u/ml	84	0	[2, 6.9, 9.1, 29, 35.75, 65.05, 130.15, 273.6, 508]		Serum	
619	s-tyreoideaperoksidaasi,vasta-aineet		287	100			Serum	
620	s-vesirokkovirus,vasta-aineet		115	100			Serum	
621	sitruliinipeptidi,vasta-aineet	u/ml	360	0	[0.7, 0.88, 0.99, 1.08, 1.17, 1.27, 1.36, 1.5, 1.73]			
622	sitruliinipeptidi,vasta-aineet		9	100				
623	sitrulliinipeptidi,vasta-aineet	u/ml	486	0	[0.69, 0.8, 0.9, 1, 1.17, 1.3, 1.4, 1.62, 2.15]			
624	sitrulliinipeptidi,vasta-aineet		175	100				
625	sitrulliinipeptidi,vasta-aineet,seerumista␤	u/ml	602	0				
626	sitrulliinipeptidi,vasta-aineet,seerumista␤		18	100				
627	treponemapallidum,vasta-aineet		1109	100				
628	treponemapallidum,vasta-aineet,seerumista␤		202	100				
629	tsh-reseptori,vasta-aineet	iu/l	121	0	[1.65, 1.8, 2, 2.13, 2.3, 2.6, 2.97, 3.48, 4.5]			
630	tsh-reseptori,vasta-aineet		71	100				
631	tyreoideaperoksidaasi,vasta-aineet	u/ml	89	0	[16, 19.45, 25.73, 35.77, 54, 95.2, 135.15, 215.3, 349]			
632	tyreoideaperoksidaasi,vasta-aineet		155	100				
633	tyreoideaperoksidaasi,vasta-aineet,plasma	u/ml	52	0				
634	tyreoideaperoksidaasi,vasta-aineet,plasma		84	100				
635	tyroideaperoksidaasi,vasta-aineet	u/ml	443	0	[8.25, 10.81, 12.97, 16.04, 20.9, 37.49, 80.13, 164.69, 260.19]			
636	tyroideaperoksidaasi,vasta-aineet		407	100				
637	valkosolu,vasta-aineet,	titre	30	0				
638	valkosolu,vasta-aineet,		141	100				
639	veriryhmävasta-aineet		205	100				

