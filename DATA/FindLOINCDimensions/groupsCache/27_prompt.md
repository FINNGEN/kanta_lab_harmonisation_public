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
Here is group 27 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1573	glomerulussuodosnopeus	ml/min/173m2	109	0	[63.93, 70, 75.29, 78.91, 82, 87.53, 92.83, 96, 101]			
1574	glomerulussuodosnopeus,estimo	ml/min/173m2	69944	0	[31.96, 48.4, 59.73, 68.93, 77.12, 83.8, 89.36, 95.68, 105.3]			
1575	glomerulussuodosnopeus,estimo		1109	100				
1576	glomerulussuodosnopeus,estimoitu	ml/min/173m2	46730	0	[33.6, 47.71, 57.74, 66, 73.46, 80.3, 86, 91.75, 100.04]			
1577	glomerulussuodosnopeus,estimoitu		341	100				
1578	glomerulussuodosnopeus,estimoitu(6354pt-gfre)	ml/min/173m2	2051	0	[70.05, 75.88, 80.89, 85.1, 90.3, 94.5, 98.82, 103.2, 109.81]			
1579	glomerulussuodosnopeus,estimoitu(pt-gfre)	ml/min/173m2	3424	0	[70.4, 77.68, 83.16, 87.93, 92.43, 96.02, 99.57, 103.88, 110.14]			
1580	glomerulussuodosnopeus,estimoitu(pt-gfre)		8	100				
1581	glomerulussuodosnopeus,estimoitu,ckd-epi-kaava	ml/min/173m2	59443	0	[38.93, 53.35, 62.85, 70.68, 77.72, 83.55, 88.51, 94.22, 102.99]			
1582	glomerulussuodosnopeus,estimoitu,ckd-epi-kaava		506	97.23				
1583	glomerulussuodosnopeus,estimoitu,ckd-epi-kaava,osatutk.	ml/min/173m2	3089	0	[26.08, 34.84, 41.15, 45.83, 50.38, 54.19, 57.55, 63.85, 71.6]			
1584	glomerulussuodosnopeus,estimoitu,ckd-epi-kaava,osatutk.		7211	99.99				
1585	glomerulussuodosnopeus,estimoitu,ckd-epi-kaavalla	ml/min/173m2	168	0	[65.06, 71.08, 75.76, 81.38, 86.92, 91.25, 95.45, 100.53, 106.04]			
1586	glomerulussuodosnopeus,estimoitu,kreatiniini-kystatiinic	ml/min/173m2	105	0	[31, 37.6, 44.52, 49, 56.11, 64.13, 71.9, 82.9, 95]			
1587	glomerulussuodosnopeus,estimoitu,kreatiniini-kystatiinic		29	100				
1588	glomerulussuodosnopeus,estimoitu,kreatiniini-kystatiinic-kaava	ml/min/173m2	920	0	[13.93, 18.74, 22.19, 27.37, 34.14, 40.84, 47.15, 59.94, 78.63]			
1589	glomerulussuodosnopeus,estimoitu,kreatiniini-kystatiinic-kaava		29	100				
1590	glomerulussuodosnopeus,estimoitu,kystatiini	ml/min/173m2	462	0	[15.23, 20.55, 27.39, 34.01, 42.88, 53.37, 62.18, 75.19, 91.19]			
1591	glomerulussuodosnopeus,estimoitu,kystatiini		9	100				
1592	glomerulussuodosnopeus,estimoitukystatiinic:stä	ml/min/173m2	130	0	[12, 16.5, 22.33, 28.53, 33.53, 40.97, 55.5, 74.93, 94.5]			
1593	glomerulussuodosnopeus,estimoitukystatiinic:stä		17	100				
1594	pt-glomerolussuodosnopeus,estimoitu,ckd-epi-kaava	ml/min/173m2	19	0			Patient	
1595	pt-glomerolussuodosnopeus,estimoitu,ckd-epi-kaava		170	81.76			Patient	
1596	pt-glomerulussuodatusnopeus		154	0	[49.1, 60.8, 67.9, 75.91, 81, 85.63, 90.06, 95.72, 101.45]		Patient	
1597	pt-glomerulussuodatusnopeus,estimoitu,ckd-epi-kaava	ml/min/173m2	334	0	[71.35, 77.6, 82.21, 87.2, 92.03, 95.18, 98.03, 101.88, 105.8]		Patient	
1598	pt-glomerulussuodosnopeus	ml/min/173m2	46	0			Patient	
1599	pt-glomerulussuodosnopeus		201	0	[72.02, 77.62, 82.9, 86.13, 90.39, 94.05, 97.96, 102.09, 108.92]		Patient	
1600	pt-glomerulussuodosnopeus,ckd-epi-kaava	form	12	0			Patient	
1601	pt-glomerulussuodosnopeus,ckd-epi-kaava	ml/min/173m2	26884	0	[37.99, 49.09, 57.83, 65.17, 72.03, 78.86, 84.25, 88.74, 95.42]		Patient	
1602	pt-glomerulussuodosnopeus,ckd-epi-kaava		156	100	[36.75, 50.17, 59.82, 68.27, 75.71, 82.14, 87.76, 93.72, 102.33]		Patient	
1603	pt-glomerulussuodosnopeus,estimoitu	ml/min/173m2	95166	0	[40.58, 54.64, 64.84, 72.76, 79.39, 84.76, 89.6, 94.5, 101.63]		Patient	
1604	pt-glomerulussuodosnopeus,estimoitu		30	93.33			Patient	
1605	pt-glomerulussuodosnopeus,estimoitu,ckd-ep	ml/min/173m2	1488	0	[66.84, 73.84, 79.57, 84.05, 88.42, 92.9, 96.66, 101.04, 107.5]		Patient	
1606	pt-glomerulussuodosnopeus,estimoitu,ckd-epi-kaav	ml/min/173m2	5281	0	[44.92, 55.66, 62.91, 68.92, 74.67, 80.31, 85.34, 90.17, 97.28]		Patient	
1607	pt-glomerulussuodosnopeus,estimoitu,ckd-epi-kaav		9	44.44			Patient	
1608	pt-glomerulussuodosnopeus,estimoitu,ckd-epi-kaava	1	389	0	[25.09, 35.32, 40.66, 44.62, 48.33, 52.52, 55.94, 59.62, 66.62]		Patient	
1609	pt-glomerulussuodosnopeus,estimoitu,ckd-epi-kaava	ml/min/173m2	210242	0	[34.02, 48.37, 58.88, 67.64, 75.41, 82.14, 87.42, 93.03, 101.14]		Patient	
1610	pt-glomerulussuodosnopeus,estimoitu,ckd-epi-kaava		8059	100	[27.33, 36.67, 44.46, 49.57, 54.09, 57.7, 63.63, 70.76, 81.87]		Patient	
1611	pt-glomerulussuodosnopeus,estimoitu,ckd-epi-kaava(p-kreaosatutkimus)	ml/min/173m2	10	0			Patient	
1612	pt-glomerulussuodosnopeus,estimoitu,ckd-epi-kaava(p-kreaosatutkimus)		171	0	[73.84, 78.86, 83.97, 87.58, 91.71, 94.84, 98.64, 103.46, 110.99]		Patient	
1613	pt-glomerulussuodosnopeus,estimoitu,ckd-epi-kaava(pt-gfre-3osatutkimus)	ml/min/173m2	61771	0	[37.8, 52.85, 63.26, 71.36, 78.3, 84.12, 89.13, 94.66, 103.19]		Patient	
1614	pt-glomerulussuodosnopeus,estimoitu,ckd-epi-kaava(pt-gfre-3osatutkimus)		571	100			Patient	
1615	pt-glomerulussuodosnopeus,estimoitu,ckd-epikaava		392	76.02			Patient	
1616	pt-glomerulussuodosnopeus,estimoitu,kystatiinic-kaava	ml/min/173m2	1128	0	[13.38, 17.28, 21.32, 25.26, 30.92, 37.46, 46.04, 59.35, 78.51]		Patient	
1617	pt-glomerulussuodosnopeus,estimoitu,kystatiinic-kaava		9	100			Patient	
1618	pt-glomerulussuodosnopeus,estimoitu,mdrd-kaava	ml/min/173m2	102	0	[47, 52.85, 61.3, 66.9, 71.83, 75.79, 83, 87.6, 95]		Patient	
1619	pt-glomerulussuodosnopeus,estimoituckd-epi-kaava	ml/min/173m2	3485	0	[61.77, 69.45, 74.52, 78.52, 82.77, 87.58, 92.59, 97.81, 104.92]		Patient	
1620	pt-glomerulussuodosnopeus,estimoituckd-epi-kaava		8	100			Patient	
1621	pt-glomerulussuodosnopeus,estimoituckd-epikaava	1	29	0			Patient	
1622	pt-glomerulussuodosnopeus,estimoituckd-epikaava	ml/min/173m2	17	0			Patient	
1623	pt-glomerulussuodosnopeus,estimoituckd-epikaava		133	80.45			Patient	
1624	pt-glomerulussuodosnopeus,estimoituckd-epikaavallakystatiinic:stä	ml/min/173m2	131	0	[30.4, 40.44, 52.53, 62.15, 66.22, 72.13, 78.87, 84, 92.45]		Patient	
1625	pt-glomerulussuodosnopeus,estimoituckd-epikaavallakystatiinic:stä		149	0	[32.8, 40.11, 46.58, 53.63, 56.8, 62.05, 69.24, 77.46, 88]		Patient	
1626	pt-glomerulussuodosnopeus,estimoitukystatiinic:stä	ml/min/173m2	73	0			Patient	
1627	pt-glomerulussuodosnopeus,estimoitukystatiinic:stä		45	100			Patient	
1628	pt-glomerulussuodosnopeus,pt-gfreepiestimoitu,ckd-epi-kaava	ml/min/173m2	7100	0	[69.69, 76.62, 81.72, 86.27, 90.49, 94.66, 98.39, 103.04, 109.83]		Patient	
1629	pt-glomerulussuodusnopeus,estimoitu,ckd-epi-kaava	ml/min/173m2	15425	0	[39.52, 49.82, 57.98, 65.15, 71.46, 77.82, 83.45, 88.33, 94.79]		Patient	
1630	pt-glomerulustensuodatusnopeudenmittaus	ml/min/173m2	254	0	[38.63, 48.15, 56.12, 63, 69.42, 75.47, 81.04, 86.71, 91.95]		Patient	
1631	pt-glomerulustensuodatusnopeus,estimoitu,ckd-epi-kaava	ml/min/173m2	30449	0	[41.38, 54.1, 63.07, 70.49, 77.05, 82.5, 87.32, 92.43, 99.39]		Patient	
1632	pt-glomerulustensuodatusnopeus,estimoitu,ckd-epi-kaava		5	100			Patient	
1633	pt-glomerulustensuodatusnopeus,estimoitu,mdrd-kaava	ml/min/173m2	39	0			Patient	
1634	pt-glomerulustensuodatusnopeus,estimoitu,mdrd-kaava		246	0	[47.3, 56.48, 62.58, 67.17, 71.01, 76.05, 79.78, 86.85, 97.66]		Patient	
1635	pt-glumerulussuodosnopeus,estimoitu,cjd-epikaava	ml/min/173m2	6297	0	[39.99, 51.01, 59.64, 66.13, 72.11, 77.8, 83.04, 88.14, 94.32]		Patient	

