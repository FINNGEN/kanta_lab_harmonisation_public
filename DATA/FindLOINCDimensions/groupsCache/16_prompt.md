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
Here is group 16 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1089	b-tromboplastiiniaika,pikamittaus,inr		114	4.39	[1, 1, 1, 1, 1, 1.1, 1.1, 1.16, 1.3]		Blood	
1090	cp-tromboplastiiniaika,ihopistosnäyte,vieritesti		367	0				
1091	koriongonadotropiini,b-alayksikkö,vapaa	ug/l	238	0	[20.8, 29.68, 37.17, 45.05, 53.52, 60.9, 76.7, 92, 128.51]			
1092	koriongonadotropiini,ihmisen,plasma	u/l	260	0	[3.31, 15.13, 48.78, 179.29, 409.62, 1283.88, 4468.73, 12092.44, 26695.9]			
1093	koriongonadotropiini,ihmisen,plasma		322	100				
1094	koriongonadotropiini,totaali,plasmasta	u/l	51	0				
1095	koriongonadotropiini,totaali,plasmasta		80	100				
1096	koriongonadotropiinib-alayks.vapaa	ug/l	183	0	[19.16, 29.13, 36.65, 46.35, 53, 59.46, 70.07, 87.23, 113.79]			
1097	p-alaniiniaminotransferaasi,paikallisanalytiikka,kuivakemia	u/l	508	0	[12.04, 14.16, 16, 19.06, 21.95, 25.02, 29.64, 33.96, 49.14]		Plasma	
1098	p-alaniiniaminotransferaasi,paikallisanalytiikka,kuivakemia		44	100			Plasma	
1099	p-alkalinenfosfataasi,paikallisanalytiikka,kuivakemia	u/l	332	0	[48.45, 56.63, 66.04, 71.83, 80.63, 88.08, 97.07, 112.52, 170.2]		Plasma	
1100	p-amylaasi,paikallisanalytiikka,kuivakemia	u/l	250	0	[31.3, 38.58, 46.93, 53.56, 60.28, 68.24, 76.33, 86.52, 107.32]		Plasma	
1101	p-glukoosi,paikallisanalytiikka,kuivakemia	mmol/l	165	0	[5.42, 5.81, 6.07, 6.3, 6.5, 6.99, 7.75, 8.77, 11.6]		Plasma	
1102	p-glutamyyliransferaasi,paikallisanalytiikka,kuivakemia	u/l	168	0	[15.4, 19.36, 22.3, 26.32, 31.49, 41.71, 57.4, 84.77, 183.06]		Plasma	
1103	p-glutamyyliransferaasi,paikallisanalytiikka,kuivakemia		6	100			Plasma	
1104	p-kalium,paikallisanalytiikka,kuivakemia	mmol/l	2353	0	[3.46, 3.68, 3.81, 3.92, 4.04, 4.17, 4.3, 4.43, 4.7]		Plasma	
1105	p-koriongonadotropiini,ihmisen	u/l	272	0	[0, 0, 2.47, 10.82, 148.71, 698.13, 2470.41, 7994.32, 36003.93]		Plasma	
1106	p-koriongonadotropiini,ihmisen		360	100			Plasma	
1107	p-koriongonadotropiini,totaali	iu/l	95	0			Plasma	
1108	p-koriongonadotropiini,totaali		262	100			Plasma	
1109	p-kreatiniini,paikallisanalytiikka,kuivakemia	umol/l	1411	0	[47.66, 54, 59.17, 63.69, 68.93, 74.65, 83.11, 96.3, 119.93]		Plasma	
1110	p-kreatiniini,paikallisanalytiikka,kuivakemiap-kreatiniini,paikallisanalytiikka,kuivakemia	umol/l	760	0	[47.29, 54.91, 60.08, 65.66, 72.04, 82.86, 96.74, 122.68, 179.25]		Plasma	
1111	p-natrium,paikallisanalytiikka,kuivakemia	mmol/l	2325	0	[133.91, 136.92, 138.89, 139.98, 140.99, 141.95, 142.79, 143.51, 144.96]		Plasma	
1112	p-tromboblastiiniaika	%	559	0	[50.13, 63.09, 71.28, 78.72, 85.87, 92.81, 100.24, 109.39, 120.34]		Plasma	
1113	p-tromboplastiiniaika	%	2769	0	[54.83, 66.89, 74.64, 80.83, 87.01, 93.48, 99.94, 107.38, 117.53]		Plasma	
1114	p-tromboplastiiniaika		417	12.71	[1.17, 1.81, 2, 2.2, 2.34, 2.5, 2.68, 2.9, 3.34]		Plasma	
1115	p-tromboplastiiniaika,aktivoitu,partiaalinen	s	1686	0	[24, 25, 26, 26.9, 27.9, 29.01, 30.88, 32.96, 36.72]		Plasma	
1116	p-tromboplastiiniaika,aktivoitu,partiaalinen		22	100			Plasma	
1117	p-tromboplastiiniaika,inr	1	23	0			Plasma	
1118	p-tromboplastiiniaika,inr	inr	45	0			Plasma	
1119	p-tromboplastiiniaika,inr		266	0.75	[1.19, 1.72, 2, 2.21, 2.4, 2.58, 2.78, 3.01, 3.45]		Plasma	
1120	p-tromboplastiiniaika,inr,tt		9529	0.7	[1.12, 1.57, 1.98, 2.19, 2.35, 2.51, 2.7, 2.93, 3.31]		Plasma	
1121	p-tromboplastiiniaika,inr-tulos	1	13965	0	[1.82, 2.04, 2.2, 2.34, 2.49, 2.62, 2.81, 3.01, 3.37]		Plasma	
1122	p-tromboplastiiniaika,inr-tulos	inr	6341	0	[1, 1.07, 1.11, 1.35, 1.9, 2.19, 2.41, 2.67, 3.06]		Plasma	
1123	p-tromboplastiiniaika,inr-tulos		121	100	[1.74, 2.02, 2.2, 2.33, 2.48, 2.62, 2.81, 3.04, 3.42]		Plasma	
1124	p-tromboplastiiniaika,inr-tulostus	1	64	0			Plasma	
1125	p-tromboplastiiniaika,inr-tulostus	inr	38474	0			Plasma	
1126	p-tromboplastiiniaika,inr-tulostus		142	100	[1.09, 1.36, 1.91, 2.14, 2.31, 2.48, 2.68, 2.9, 3.27]		Plasma	
1127	p-tromboplastiiniaika,inr-tulostus,vieritutkimus	inr	112	0	[1, 1, 1, 1, 1.1, 1.1, 1.2, 1.24, 2.02]		Plasma	
1128	p-tromboplastiiniaika,inr-tulostus,vieritutkimus		171	4.68			Plasma	
1129	p-tromboplastiiniaika,inrtulostus		201	0			Plasma	
1130	p-tromboplastiiniaika-pika,inrpika-tulos		338	2.07	[1, 1, 1, 1, 1.1, 1.13, 1.2, 1.45, 1.98]		Plasma	
1131	s-koriongonadotropiini,vapaa-b-ketju	ug/l	114	0	[25.51, 31.71, 40.79, 51.3, 61.57, 74.11, 91.5, 115.15, 154.08]		Serum	
1132	s-koriongonadotropiini-b-alayksikkö,ihm.vap	ug/l	309	0	[21.65, 28.99, 34.44, 41.96, 50.94, 60.22, 67.89, 84, 110.47]		Serum	
1133	s-koriongonadotropiini-b-alayksikkö,ihmisen,vapaa	pmol/l	7	0			Serum	
1134	s-koriongonadotropiini-b-alayksikkö,ihmisen,vapaa	ug/l	369	0	[20.26, 27.65, 34.39, 42.67, 51.57, 61, 72.6, 88.05, 118.59]		Serum	
1135	s-koriongonadotropiini-b-alayksikkö,ihmisen,vapaa		18	100			Serum	
1136	s-koriongonadotropiini-b-alayksikkö,ihmisen,vapaa(kasvainmerkkiaine)	ug/l	110	0	[23.5, 29, 40, 46.83, 53.67, 62, 79.47, 110, 135]		Serum	
1137	s-koriongonadotropiini-b-alayksikkö,ihmisen,vapaa(kasvainmerkkiaine)		5	100			Serum	
1138	s-koriongonadotropiini-b-alayksikkö,vapaa	ug/l	136	0	[22.42, 35.1, 43.56, 50.45, 61.86, 68.23, 86.2, 99.41, 133.31]		Serum	
1139	s-koriongonadotropiini-b-alayksikkö,vapaa1.trimesterinseula	ug/l	462	0	[22.43, 29.82, 36.68, 43.43, 50.5, 58.52, 69.2, 89.03, 117.92]		Serum	
1140	s-koriongonadotropiini-b-alayksikkö,vapaaxmom,down-seulassa	mom	308	0	[0.47, 0.55, 0.69, 0.81, 0.96, 1.14, 1.33, 1.54, 2.03]		Serum	
1141	tromboplastiiniaika	%	148	0	[70, 81.7, 88.56, 93.9, 99.5, 105.76, 113.69, 119.28, 129.2]			
1142	tromboplastiiniaika		11	9.09				
1143	tromboplastiiniaika,aktivoitu,partiaalinen,plasma	s	406	0	[29, 30, 31, 32, 33.37, 34.99, 36.76, 38.86, 43.28]			
1144	tromboplastiiniaika,aktivoitu,partiaalinen,plasma		7	100				
1145	tromboplastiiniaika,aktivoitu,partiaalinen.plasma	s	752	0	[26.93, 28.04, 29.39, 30.29, 31, 32, 33.74, 35, 39.05]			
1146	tromboplastiiniaika,aktivoitu,partiaalinen.plasma		18	100				
1147	tromboplastiiniaika,inr-tulos	inr	2713	0	[1.1, 1.71, 1.98, 2.17, 2.35, 2.54, 2.73, 2.97, 3.34]			
1148	tromboplastiiniaika,inr-tulos		183	100				
1149	tromboplastiiniaika,inr-tulostu	inr	494	0				
1150	tromboplastiiniaika,inr-tulostu		5	100				
1151	tromboplastiiniaika,inr-tulostus	inr	9382	0	[1, 1.09, 1.22, 1.68, 2.05, 2.29, 2.51, 2.77, 3.17]			
1152	tromboplastiiniaika,inr-tulostus		129	97.67				
1153	tromboplastiiniaika,inr-tulostus,kapillaariverestä		607	0.82	[1.73, 2, 2.19, 2.3, 2.5, 2.68, 2.88, 3.1, 3.5]			
1154	tromboplastiiniaika,inr-tulostus,laaduntarkkailu	inr	127	0				
1155	tromboplastiiniaika,inr-tulostus,laaduntarkkailu		8	100				
1156	tromboplastiiniaika,inr-tulostus,plasma	inr	11740	0	[0.99, 1, 1.1, 1.14, 1.3, 1.71, 2.21, 2.57, 3.07]			
1157	tromboplastiiniaika,inr-tulostus,plasma		216	88.89				
1158	tromboplastiiniaika,inr-tulostus,plasmasta	1	15	0				
1159	tromboplastiiniaika,inr-tulostus,plasmasta		1331	1.58	[1, 1.1, 1.19, 1.54, 1.98, 2.23, 2.43, 2.7, 3.03]			
1160	tromboplastiiniaika,inr-tulostus,plasmasta␤	inr	15979	0				
1161	tromboplastiiniaika,inr-tulostus,plasmasta␤		58	100				
1162	tromboplastiiniaika,pikamääritys,plasmasta␤	inr	128	0				
1163	tromboplastiiniaika,pikatesti,veri	inr	206	0	[1, 1, 1, 1, 1, 1.1, 1.1, 1.1, 1.2]			
1164	tromboplastiiniaika,pikatesti,veri		91	62.64				
1165	tromboplastiiniaika,plasma	%	676	0	[59.55, 72.86, 81.47, 88.69, 96.37, 103.04, 108.92, 116.32, 128.3]			
1166	tromboplastiiniaika,plasma		22	100				
1167	u-koriongonadotropiini,ihmisen(kval)		124	100			Urine	

