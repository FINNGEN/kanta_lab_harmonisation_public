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
Here is group 162 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
13068	-cd4-solujensuhdecd8-soluihin		667	0.3	[0.26, 0.37, 0.55, 0.73, 1, 1.35, 1.81, 2.32, 3.03]			
13069	-kt/v,daugirdaksenkaava		176	0	[1.13, 1.23, 1.29, 1.33, 1.39, 1.43, 1.46, 1.5, 1.57]			
13070	-sieni,natiivivalmiste		244	100				
13071	ab-aktuaalibikarbonaatti	mmol/l	14354	0	[18.76, 21.02, 22.57, 23.76, 24.73, 25.7, 26.99, 28.55, 31.59]		Arterial blood	
13072	ab-aktuaalibikarbonaatti		47	100			Arterial blood	
13073	ab-lämpötila(he-tase)	aste	418	0	[36.38, 36.95, 37, 37, 37, 37, 37.01, 37.48, 38.01]		Arterial blood	
13074	ab-standardibikarbonaatti	mmol/l	4434	0	[19.73, 21.71, 22.89, 23.76, 24.46, 25.22, 26.01, 27.04, 28.87]		Arterial blood	
13075	ab-standardibikarbonaatti		20	100			Arterial blood	
13076	alkalinenfosfataasi	u/l	4090	0	[51.93, 59.73, 66.52, 72.54, 78.85, 86.09, 95.45, 111.37, 142.22]			
13077	alkalinenfosfataasi		409	100				
13078	angiotensiini-1-konvertaasi	u/l	286	0	[21.5, 28.51, 36.37, 41.21, 48.76, 54.44, 63.62, 70.94, 80.3]			
13079	angiotensiini-1-konvertaasi		20	100				
13080	b-diffi,erittelylaskenta,klooni		142	100			Blood	
13081	cb-standardibikarbonaatti	mmol/l	10798	0	[20.28, 22.23, 23.36, 24.16, 24.9, 25.66, 26.58, 27.89, 30.19]		Capillary blood	
13082	cb-standardibikarbonaatti		90	50			Capillary blood	
13083	d-vitamiini-25-oh,d3-jad2-muodot	nmol/l	219	0	[48.54, 55.58, 61.96, 68.73, 74.1, 79.27, 84.22, 89.91, 106.45]			
13084	d-vitamiini-25-oh,plasmasta	nmol/l	694	0	[44.59, 53.15, 59, 64.66, 69.89, 76.01, 82.54, 92.02, 105.7]			
13085	e-punasolujenkokojakaum	%	55570	0	[12.19, 12.59, 12.95, 13.26, 13.67, 14.09, 14.51, 14.98, 15.71]		Erythrocyte	
13086	e-punasolujenkokojakaum		7	71.43			Erythrocyte	
13087	e-punasolujenkokojakauma	%	196935	0	[12, 13, 13, 13, 13.69, 14, 14.05, 15, 16.37]		Erythrocyte	
13088	e-punasolujenkokojakauma		1688	46.92	[15, 15, 15.98, 16, 16, 16.41, 17, 18, 19.59]		Erythrocyte	
13089	e-rdw,punasolujenkokojakauma	%	25929	0	[12.08, 13, 13, 13.03, 14, 14, 15, 15.7, 17.03]		Erythrocyte	
13090	e-rdw,punasolujenkokojakauma		76	100			Erythrocyte	
13091	ekg,hoitoyksikönottama		213	100				
13092	ekgasiakkaanottama		257	100				
13093	erikoislääkärinkonsultaatio		118	100				
13094	folaatti(fe-folaat)	nmol/l	320	0	[1456.69, 1642.98, 1740.68, 1864.47, 2021, 2152.9, 2311.39, 2519.36, 2775.52]			
13095	folaatti(fe-folaat)		12	100				
13096	fosfaatti,epäorgaaninen	mmol/l	275	0	[0.83, 0.93, 0.99, 1.05, 1.1, 1.15, 1.23, 1.36, 1.64]			
13097	fosfaatti,epäorgaaninen		13	100				
13098	fp-fosfaatti,epäorgaaninen	mmol/l	1537	0	[0.81, 0.94, 1.04, 1.12, 1.21, 1.31, 1.45, 1.64, 2]		Fasting plasma	
13099	fp-fosfaatti,epäorgaaninen		7	100			Fasting plasma	
13100	fp-parathormoni(intakti)	ng/l	167	0	[34.58, 43.28, 53.6, 64.34, 75.77, 88.59, 106.04, 128.88, 166.07]		Fasting plasma	
13101	fp-parathormoni,intakti	ng/l	443	0	[42.85, 55.73, 66.85, 78.78, 88.68, 102.07, 115.78, 136.81, 193.49]		Fasting plasma	
13102	fp-parathormoni,intakti	pmol/l	213	0	[5.11, 7.29, 9.06, 12.26, 16.48, 21.96, 29.55, 41.46, 57.9]		Fasting plasma	
13103	fp-parathormoni,intakti		5	60			Fasting plasma	
13104	fp-reniini,konsentraatio	mu/l	275	0	[1.9, 3.7, 5.72, 9.15, 13.8, 21.38, 36.23, 69.29, 149]		Fasting plasma	
13105	fp-reniini,konsentraatio		9	100			Fasting plasma	
13106	fras,oksidatiivinenstressi		508	100				
13107	fs-alkalinenfosfataasi	u/l	114	0			Fasting serum	
13108	fs-angiotensiini-1-konvertaasi	u/l	168	0	[21.95, 28.78, 36.13, 43.17, 50.38, 57.02, 63.03, 69.31, 88.3]		Fasting serum	
13109	fs-angiotensiini-1-konvertaasi		17	100			Fasting serum	
13110	fs-monikanava4-7tthperuspaketti		125	100			Fasting serum	
13111	fs-työterveyshuollonperuspaketti		141	100			Fasting serum	
13112	ilmajohtotarv.luujohto		785	100				
13113	korona-rs-influenssa,pcrpikatesti		6428	100				
13114	kreatiinikinaasi	u/l	821	0	[51.45, 67.28, 78.98, 91.33, 108.19, 125.74, 161.13, 224.43, 350.78]			
13115	l-basofiilit,automaatio	%	10670	0	[0, 0, 0.5, 1, 1, 1, 1, 1, 1]		Leukocyte	
13116	l-eosinofiilit,automaatio	%	10670	0	[0.35, 1, 1.93, 2, 2.74, 3, 3.97, 4.81, 6.33]		Leukocyte	
13117	l-lymfosyytit,automaatio	%	19279	0	[15.56, 20.42, 24.04, 26.95, 29.66, 32.37, 35.21, 38.75, 43.79]		Leukocyte	
13118	l-lymfosyytit,automaatio		23	100			Leukocyte	
13119	l-monosyytit,automaatio	%	19276	0	[5.94, 6.98, 7.19, 8, 8.78, 9.04, 10, 11, 12.64]		Leukocyte	
13120	l-monosyytit,automaatio		23	100			Leukocyte	
13121	l-neutrofiilit,automaatio	%	19277	0	[41.43, 47.16, 50.99, 54.23, 57.08, 59.98, 63.15, 67.08, 72.76]		Leukocyte	
13122	l-neutrofiilit,automaatio		23	100			Leukocyte	
13123	laktaattidehydrogenaasi	u/l	112	0	[166.9, 176.25, 189.57, 200, 217.89, 228.73, 246.21, 285.8, 336.3]			
13124	p-aktuaalinenbikarbonaatti	mmol/l	1258	0	[20.16, 23.03, 24.56, 25.84, 26.91, 27.87, 28.97, 30.03, 32.38]		Plasma	
13125	p-alkaalinenfosfataasi	u/l	218	0	[54.87, 64.51, 69.29, 74.44, 80.78, 89.02, 97.67, 107.93, 128.13]		Plasma	
13126	p-alkaalinenfosfataasi		6	16.67			Plasma	
13127	p-alkalinenfosfataasi	u/l	26335	0	[51.5, 59.65, 66.46, 73.03, 79.94, 87.78, 97.91, 113.11, 149.16]		Plasma	
13128	p-alkalinenfosfataasi		74	91.89			Plasma	
13129	p-bilirubiinikonjugaatit	umol/l	1839	0	[2.92, 3, 3.32, 4, 4.89, 5.93, 7.57, 10.11, 21.15]		Plasma	
13130	p-bilirubiinikonjugaatit		168	100			Plasma	
13131	p-fosfaatti,epäorgaaninen	mmol/l	436	0	[0.89, 0.99, 1.06, 1.13, 1.2, 1.27, 1.36, 1.47, 1.66]		Plasma	
13132	p-kreatiinikinaasi	u/l	2765	0	[43.61, 57.48, 70.52, 85.33, 100.93, 124.44, 165.61, 239.04, 491.32]		Plasma	
13133	p-kreatiinikinaasi		21	95.24			Plasma	
13134	p-laktaattidehydrogenaasi	u/l	3272	0	[163.71, 178.57, 190.98, 203.43, 216.38, 231.67, 254.03, 288.21, 372.84]		Plasma	
13135	p-laktaattidehydrogenaasi		29	96.55			Plasma	
13136	p-lupusantikoagulantti		220	100			Plasma	
13137	p-psavapaanosuustotaalista	%	719	0	[10.55, 13.9, 16.1, 18.77, 21.1, 23.88, 26.7, 30.17, 36.09]		Plasma	
13138	p-urea,resirkulaatio	mmol/l	200	0	[4.65, 12.03, 14.2, 15.66, 16.84, 18.43, 19.52, 21.22, 23.14]		Plasma	
13139	psa-vapaa/totaali-suhde,plasmasta	%	1183	0	[8.11, 11.04, 13.43, 15.83, 18.18, 20.89, 24.81, 29.88, 39.78]			
13140	psa-vapaa/totaali-suhde,plasmasta		3428	100				
13141	psavapaanjatotaalinsuhde	%	62	0				
13142	psavapaanjatotaalinsuhde		180	97.78				
13143	pt-vaativainhalaatiohoito		114	100			Patient	
13144	punasolojenkokojakauma	%	1068	0	[12, 12.05, 13, 13, 13, 13, 13.97, 14, 14.47]			
13145	punasolojenkokojakauma		7	100				
13146	punasolujenerittelylaskenta	%	41	0				
13147	punasolujenerittelylaskenta		433	6	[12, 12, 12.18, 13, 13, 13, 13, 13.97, 14]			
13148	punasolujenesiasteet(erytroblastit)	e9/l	1040	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]			
13149	punasolujenesiasteet(erytroblastit)		24	100				
13150	punasolujenkokojakauma	%	155883	0	[12.28, 13, 13, 13.02, 14, 14, 15, 15.9, 17]			
13151	punasolujenkokojakauma		2478	99.48				
13152	punasolujenkokojakautuma	%	683	0	[13, 13, 13, 13, 13, 14, 14, 14, 14.95]			
13153	punasolujenkoonvaihtelu	%	2031	0	[12.51, 12.91, 13.17, 13.34, 13.62, 13.91, 14.31, 14.86, 15.92]			
13154	punasolut,kokojakauma	%	121	0	[13, 13, 13, 13, 14, 14, 14, 14, 15]			
13155	s-alkalinenfosfataasi	u/l	368	0	[52.79, 63.98, 76.35, 87.37, 103.68, 118.86, 131.06, 146.22, 181.47]		Serum	
13156	s-alkalinenfosfataasi,isoentsyymit		318	100			Serum	
13157	s-glykoproteiininasetylaatio	mmol/l	265	0	[0.75, 0.79, 0.81, 0.83, 0.85, 0.88, 0.9, 0.94, 1]		Serum	
13158	s-neuronispesifinenenolaasi	ug/l	105	0			Serum	
13159	s-nightingale-mittaus		265	100			Serum	
13160	s-psavapaanjatotaalinsuhde	%	106	0	[11, 13, 14.4, 16.35, 19, 21, 23.87, 27, 31.9]		Serum	
13161	s-psavapaanjatotaalinsuhde		264	100			Serum	
13162	s-tymidiinikinaasi	u/l	237	0	[3.92, 4.79, 5.63, 6.48, 7.24, 8.95, 10.78, 13.93, 39.38]		Serum	
13163	s-vapaanjakokonais-psa:nsuhde	%	643	0	[11.89, 14.35, 17.11, 19.53, 21.76, 24, 27.79, 31.6, 36.6]		Serum	
13164	s-vapaanjakokonais-psa:nsuhde		1561	100			Serum	
13165	sars-cov-2,influenssaa,bja		161	100				
13166	sars-cov-2-antigeenitesti,pikatesti		101	100				
13167	tth-pakettia(ilmanpaastoa)		1079	100				
13168	tth:ssavirtsanprotjagluk		294	100				
13169	u-solut,peruslaskenta		1772	100			Urine	
13170	vb-aktuaalibikarbonaatti	mmol/l	1612	0	[16.94, 19.74, 21.93, 23.14, 24.18, 25.06, 26.96, 28.44, 30.92]		Venous blood	
13171	vb-aktuaalibikarbonaatti		185	17.3	[20.1, 23.3, 24.38, 25.39, 26.05, 26.8, 27.78, 28.4, 29.7]		Venous blood	
13172	vb-standardibikarbonaatti	mmol/l	13754	0	[20.04, 21.93, 23.08, 23.95, 24.68, 25.36, 26.13, 27.07, 28.82]		Venous blood	
13173	vb-standardibikarbonaatti		44	100			Venous blood	
13174	virtsansolujenhl7-siirtoon	e6/l	5551	0	[0.1, 0.37, 0.65, 1.07, 1.65, 2.44, 3.88, 6.78, 14.04]			
13175	virtsansolujenhl7-siirtoon		353	11.05	[0, 0, 0, 0, 0, 0, 0, 0, 0]			
13176	zb-aktuaalibikarbonaatti	mmol/l	394	0	[22, 23, 23.94, 24, 25, 26, 27, 27.8, 29.78]		Central blood	

