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
Here is group 14 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
965	b-c-reaktiivinenproteiini	mg/l	29	0			Blood	
966	b-c-reaktiivinenproteiini		262	44.27	[6, 7.5, 10.67, 13.8, 18.67, 27.69, 37.44, 56, 84]		Blood	
967	b-c-reaktiivinenproteiinipika		300	37	[7, 10.22, 14.84, 20.3, 29.2, 37.52, 52.47, 75.48, 99.1]		Blood	
968	b-c-resktiivinenproteiini	mg/l	1201	0	[6, 8.11, 11.16, 14.7, 19.67, 26.61, 38.65, 58.3, 91.79]		Blood	
969	b-c-resktiivinenproteiini		802	92.39			Blood	
970	c-reaktiivinenproteiini	1	925	0	[6.19, 8.89, 11.99, 16.88, 23.76, 35.33, 49.12, 74.41, 108.21]			
971	c-reaktiivinenproteiini	mg/l	7963	0	[4.01, 6.22, 9.5, 14.46, 23.15, 35.25, 51.85, 77.94, 126.36]			
972	c-reaktiivinenproteiini		7083	90.23	[6.55, 8.84, 11.73, 17.15, 24.37, 37.67, 52.72, 72.92, 107.1]			
973	c-reaktiivinenproteiini(4594p-crp)	mg/l	143	0	[1, 1.79, 2, 2, 3, 4, 5, 6, 12.8]			
974	c-reaktiivinenproteiini(4594p-crp)		74	100				
975	c-reaktiivinenproteiini(crp)	mg/l	381	0	[1.23, 1.51, 1.92, 2.62, 3.36, 4.75, 6.13, 9.98, 21.06]			
976	c-reaktiivinenproteiini(crp)		250	100				
977	c-reaktiivinenproteiini(p-crp)	mg/l	500	0	[1, 2, 2, 2.85, 3.14, 4.26, 5.94, 8.93, 19.54]			
978	c-reaktiivinenproteiini(p-crp)		261	100				
979	c-reaktiivinenproteiini,herkkä	mg/l	254	0	[0.22, 0.41, 0.57, 0.84, 1.15, 1.65, 2.42, 3.86, 6.33]			
980	c-reaktiivinenproteiini,herkkä		18	94.44				
981	c-reaktiivinenproteiini,herkkä,seerumista	mg/l	7396	0	[0.28, 0.41, 0.6, 0.78, 1.03, 1.34, 1.83, 2.72, 4.64]			
982	c-reaktiivinenproteiini,herkkä,seerumista		36	83.33				
983	c-reaktiivinenproteiini,pika	mg/l	111	0	[5, 5.05, 6.2, 8.27, 11.67, 14.3, 22.37, 36.1, 57]			
984	c-reaktiivinenproteiini,pika		49	100				
985	c-reaktiivinenproteiini,pika,tehdäänitse	mg/l	997	0	[5, 5, 6.35, 8.12, 10.93, 14.99, 21.14, 34.44, 53.73]			
986	c-reaktiivinenproteiini,pika,tehdäänitse		820	99.27				
987	c-reaktiivinenproteiini,pikatesti,veri	mg/l	174	0	[6, 7, 8.95, 10.5, 16.42, 22.45, 35.5, 53.5, 98.67]			
988	c-reaktiivinenproteiini,pikatesti,veri		1656	42.69	[6.55, 9.61, 13.21, 19.27, 27.67, 39.17, 52.81, 73.29, 109.39]			
989	c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt)	mg/l	803	0	[4.99, 5.34, 7.17, 9.24, 13.4, 18.77, 28.88, 45.54, 76.31]			
990	c-reaktiivinenproteiini,pikatesti,veri(23318b-crp-pt)		240	100				
991	c-reaktiivinenproteiini,pikatutkimus	mg/l	106	0	[7, 12, 15.43, 21.6, 30.72, 39.4, 56.9, 87, 115.33]			
992	c-reaktiivinenproteiini,pikatutkimus		66	100				
993	c-reaktiivinenproteiini,plasmasta,vieritesti	mg/l	699	0	[5.17, 7.91, 10.75, 16.58, 23.68, 33.24, 48.01, 64.98, 99.29]			
994	c-reaktiivinenproteiini,plasmasta,vieritesti		274	94.89				
995	c-reaktiivinenproteiini,tk:ntekemä		1605	13.4	[2.23, 4.3, 7.78, 12.46, 19.91, 29.72, 46.58, 66.7, 98.89]			
996	c-reaktiivinenproteiini,vieritesti	mg/l	47	0				
997	c-reaktiivinenproteiini,vieritesti		944	23.62	[3.08, 5.45, 7.93, 11.11, 14.9, 20.87, 29.7, 49.04, 81.9]			
998	c-reaktiivinenproteiini,vieritutkimus	mg/l	525	0	[5, 6.72, 8.66, 12.22, 15.93, 22.09, 35.26, 59.08, 89.7]			
999	c-reaktiivinenproteiini,vieritutkimus		631	58.8	[6.41, 9.32, 15.53, 22.99, 35.64, 49.47, 62.97, 81.83, 113.06]			
1000	c-reaktiivinenproteiini,vieritutkimus,plasmasta	mg/l	1205	0				
1001	c-reaktiivinenproteiini,vieritutkimus,plasmasta		318	100	[4.71, 7.37, 11.52, 16.21, 23.22, 31.65, 45.13, 65.98, 97.07]			
1002	c-reaktiivinenproteiini,vieritutkimusnordlab	mg/l	92	0	[5, 6, 8, 10.7, 12.75, 16.2, 21, 31.5, 47]			
1003	c-reaktiivinenproteiini,vieritutkimusnordlab		99	100				
1004	c-reaktiivinenproteiini-pika(4594crp-pika)	mg/l	136	0	[5, 5.32, 7, 9, 11.15, 14.57, 19, 33.2, 47.3]			
1005	c-reaktiivinenproteiini-pika(4594crp-pika)		47	100				
1006	c-reaktiivinenproteiini-pika(crp-pika)	mg/l	1488	0	[5, 6.88, 7, 7.34, 10.21, 14.71, 21.39, 32, 54.73]			
1007	c-reaktiivinenproteiini-pika(crp-pika)		505	99.8				
1008	cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä	mg/l	1826	0	[1.75, 3.02, 5.68, 9.52, 14.27, 22.77, 34.19, 57.29, 89.46]			
1009	cp-c-reaktiivinenproteiini,ihopiston,hoitoyksikössä		497	46.88	[1.2, 1.53, 2.21, 2.84, 3.97, 4.8, 6.15, 7.51, 9.1]			
1010	fs-c-reaktiivinenproteiini	mg/l	241	0			Fasting serum	
1011	fs-c-reaktiivinenproteiini		184	100			Fasting serum	
1012	p-c-reaktiininenproteiini,vieritutkimus	mg/l	258	0	[5.85, 8.85, 11.14, 17.24, 24.49, 35.17, 49.34, 67.54, 96.38]		Plasma	
1013	p-c-reaktiininenproteiini,vieritutkimus		224	100			Plasma	
1014	p-c-reaktiivinenproteiini	mg/l	41046	0	[4.18, 7.12, 11.73, 18.09, 27.46, 40.11, 58.4, 87.78, 141.39]		Plasma	
1015	p-c-reaktiivinenproteiini		24714	99.73			Plasma	
1016	p-c-reaktiivinenproteiini(kval)	mg/l	187	0	[6.14, 9.01, 13.88, 18.86, 24.62, 33.54, 47.21, 67.37, 102.4]		Plasma	
1017	p-c-reaktiivinenproteiini(kval)		142	100			Plasma	
1018	p-c-reaktiivinenproteiini(kval)␤	mg/l	111	0			Plasma	
1019	p-c-reaktiivinenproteiini(kval)␤		130	100			Plasma	
1020	p-c-reaktiivinenproteiini(pikanäyte)	mg/l	6	0			Plasma	
1021	p-c-reaktiivinenproteiini(pikanäyte)		352	17.33	[1.52, 2.59, 4.86, 7.54, 12.38, 20.91, 32.04, 56.93, 83.62]		Plasma	
1022	p-c-reaktiivinenproteiini,crp	mg/l	110	0			Plasma	
1023	p-c-reaktiivinenproteiini,crp		8	62.5			Plasma	
1024	p-c-reaktiivinenproteiini,hoitoyksikkö	1	40	0			Plasma	
1025	p-c-reaktiivinenproteiini,hoitoyksikkö	alle	5	0			Plasma	
1026	p-c-reaktiivinenproteiini,hoitoyksikkö	mg/l	81	0	[8, 11, 13, 16.2, 22.25, 33.7, 48, 64, 131]		Plasma	
1027	p-c-reaktiivinenproteiini,hoitoyksikkö		156	63.46	[6, 8, 12, 14, 26, 32, 40, 60, 120]		Plasma	
1028	p-c-reaktiivinenproteiini,pikatesti	mg/l	190	0			Plasma	
1029	p-c-reaktiivinenproteiini,pikatesti		3095	41.23	[6.43, 8.8, 12.04, 15.76, 21.17, 29.16, 41.93, 63.64, 96.9]		Plasma	
1030	p-c-reaktiivinenproteiini,vieritutkimus	mg/l	53	0			Plasma	
1031	p-c-reaktiivinenproteiini,vieritutkimus		122	50.82			Plasma	
1032	p-c-reaktiivinenproteiini,vieritutkimus,plasmasta	mg/l	202	0	[4.03, 6.98, 10.47, 16.6, 21.86, 29.42, 49.79, 68.66, 100]		Plasma	
1033	p-c-reaktiivinenproteiini,vieritutkimus,plasmasta		120	71.67			Plasma	
1034	p-c-reaktiivinenproteiini.pika		316	20.25	[3.75, 6.98, 11.68, 15.55, 24.24, 38.44, 58.74, 89.38, 117.91]		Plasma	
1035	p-c-reaktiivinenproteiinipikahoitoyksiköt	mg/l	4601	0	[5.2, 7.99, 12.13, 17.43, 25.81, 37.54, 54.45, 78.12, 113.86]		Plasma	
1036	p-c-reaktiivinenproteiinipikahoitoyksiköt		1925	80.52	[1.18, 1.4, 1.83, 2.44, 3.17, 4.31, 5.83, 6.68, 8.76]		Plasma	
1037	p-c-reaktiivinenproteiinipikamittari		399	36.09	[7, 9.06, 12.92, 21.23, 28.43, 42.17, 58.76, 81.22, 122.07]		Plasma	
1038	pikatesti,c-reaktiivinenproteiini	mg/l	315	0	[6, 7.85, 10.56, 14.36, 20.22, 31.25, 44.62, 61.43, 91.59]			
1039	pikatesti,c-reaktiivinenproteiini		386	100				
1040	plasmanc-reaktiivinenproteiiniosoitus	1	36	0				
1041	plasmanc-reaktiivinenproteiiniosoitus	mg/l	3255	0	[6.24, 8.99, 12.45, 17.72, 25.65, 35.96, 50.8, 70.36, 106.56]			
1042	plasmanc-reaktiivinenproteiiniosoitus		2589	98.42				
1043	s-c-reaktiivinenproteiini	mg/l	773	0	[0.4, 0.73, 1.08, 1.43, 1.93, 2.88, 4.71, 7.16, 16.64]		Serum	
1044	s-c-reaktiivinenproteiini		121	100			Serum	
1045	s-c-reaktiivinenproteiini,herkkä	mg/l	813	0	[0.39, 0.59, 0.83, 1.22, 1.67, 2.46, 3.62, 5.63, 9.01]		Serum	
1046	s-c-reaktiivinenproteiini,herkkä		34	100			Serum	
1047	s-c-reaktiivinenproteiini,pika	mg/l	77	0	[8, 10, 12.4, 14.7, 17, 20.05, 27.4, 35, 48]		Serum	
1048	s-c-reaktiivinenproteiini,pika		199	75.88			Serum	
1049	s-c-reaktiivinenproteiini/	mg/l	191	0	[0.31, 0.5, 0.7, 0.96, 1.46, 2.27, 3.04, 4.65, 10.16]		Serum	
1050	s-c-reaktiivinenproteiini/		5	100			Serum	

