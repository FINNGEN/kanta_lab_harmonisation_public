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
Here is group 24 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1402	albumiininjakreatiininsuhde(virtsa)	mg/mmol	691	0	[0.2, 0.3, 0.4, 0.47, 0.59, 0.75, 0.98, 1.61, 4.34]			
1403	albumiininjakreatiininsuhde(virtsa)		457	100				
1404	albumiininjakreatiniininsuh	mg/mmol	235	0	[0.98, 1.89, 3.78, 7.29, 10.86, 21.58, 45.13, 73.54, 175.37]			
1405	albumiininjakreatiniininsuh		48	100				
1406	albumiininjakreatiniininsuhde	mg/mmol	382	0	[0.3, 0.44, 0.63, 0.88, 1.31, 2, 3.27, 7.24, 33.06]			
1407	albumiininjakreatiniininsuhde		789	99.87				
1408	albumiininjakreatiniininsuhde,virtsasta		143	44.06	[0.35, 0.4, 0.6, 0.7, 1.1, 1.68, 3.38, 10.65, 38]			
1409	plasmaproteiinia,raskauteenliittyvä	mu/l	315	0	[218.72, 337.21, 454.8, 600.22, 713.04, 893.08, 1115.24, 1439.51, 1939.77]			
1410	s-b12-vitamiini,transkobalamiiniii:eensit.	pmol/l	81	0	[47.3, 62.16, 72, 79.85, 91.39, 103.24, 114.62, 129.79, 137.5]		Serum	
1411	s-b12-vitamiini,transkobalamiiniii:eensit.		151	100			Serum	
1412	s-b12-vitamiini,transkobalamiiniii:eensitoutun	pmol/l	1737	0	[50.45, 65.12, 77.15, 87.79, 98.95, 108.08, 117.21, 125.93, 136.19]		Serum	
1413	s-b12-vitamiini,transkobalamiiniii:eensitoutun		2693	100			Serum	
1414	s-b12-vitamiini,transkobalamiiniii:eensitoutunut,seerumista	pmol/l	75	0	[67, 81.9, 90.5, 98.33, 105.46, 114.43, 120.75, 136, 139]		Serum	
1415	s-b12-vitamiini,transkobalamiiniii:eensitoutunut,seerumista		76	100			Serum	
1416	s-b12-vitamiini,transkobalamiiniii:nsitoutunut	pmol/l	1049	0	[50.97, 64.02, 74.77, 83.62, 91.67, 100.67, 110.52, 121.84, 134.79]		Serum	
1417	s-b12-vitamiini,transkobalamiiniii:nsitoutunut		580	100			Serum	
1418	s-plasmaproteiinia,raskauteenliittyvä	mu/l	1756	0	[236.45, 380.36, 501.78, 639.75, 792.61, 971.99, 1203.78, 1522.83, 2129.89]		Serum	
1419	s-plasmaproteiinia,raskauteenliittyvä		5	100			Serum	
1420	s-plasmaproteiinia,raskauteenliittyvä(sikiöseula)	mu/l	183	0	[341.16, 416.3, 518.97, 623.15, 761.97, 967.03, 1298.99, 1601.72, 2186.09]		Serum	
1421	s-proteiinifraktioidenalbumiinifraktio	g/l	244	0	[31.06, 33.87, 35.56, 36.73, 38.38, 39.36, 40.69, 41.88, 44.06]		Serum	
1422	s-proteiinifraktioidenalfa-1-fraktio	g/l	244	0	[1.51, 1.87, 2.12, 2.3, 2.49, 2.69, 2.9, 3.19, 3.54]		Serum	
1423	s-proteiinifraktioidenalfa-2-fraktio	g/l	244	0	[4.76, 5.41, 5.89, 6.2, 6.47, 6.78, 7, 7.36, 8.3]		Serum	
1424	s-proteiinifraktioidenbeeta-1-fraktio	g/l	244	0	[3.2, 3.39, 3.64, 3.8, 4, 4.15, 4.3, 4.5, 4.84]		Serum	
1425	s-proteiinifraktioidenbeeta-2-fraktio	g/l	244	0	[1.7, 1.98, 2.22, 2.5, 2.75, 3, 3.24, 3.52, 4.1]		Serum	
1426	s-proteiinifraktioidengammafraktio	g/l	244	0	[6.23, 7.49, 8.2, 9.32, 10.74, 11.77, 13.82, 18.94, 32.4]		Serum	
1427	s-proteiinifraktioidenm-komponentti1	g/l	108	0			Serum	
1428	u-albumiini-kreatiniini-suhde,osatutk.		351	40.74	[0.3, 0.4, 0.52, 0.7, 1.02, 1.84, 2.95, 5.11, 12.31]		Urine	
1429	u-albumiinimikroalbuminuriamg/l(u-albkre)	mg/l	1114	0	[3.73, 4.69, 6.34, 8.24, 11.46, 18.56, 33.03, 72.86, 244.16]		Urine	
1430	u-albumiinimikroalbuminuriamg/l(u-albkre)		529	100			Urine	
1431	u-albumiininjakreatiniininsuhde	mg/mmol	4773	0	[0.38, 0.52, 0.71, 0.96, 1.36, 2.13, 3.7, 8, 24.11]		Urine	
1432	u-albumiininjakreatiniininsuhde		3582	99.92			Urine	
1433	u-albumiininjakreatiniininsuhde(mikroalbumiini)	mg/mmol	20	0			Urine	
1434	u-albumiininjakreatiniininsuhde(mikroalbumiini)		518	100			Urine	

