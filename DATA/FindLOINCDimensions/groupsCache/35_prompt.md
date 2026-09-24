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
Here is group 35 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1836	-glutamyylitransferaasi-desialotransferriini-indeksi		728	1.1	[2.5, 2.78, 3, 3.2, 3.38, 3.66, 3.98, 4.31, 4.71]			
1837	:glutamyylitransferaasi-desialotransferriini-indeksi		270	0.74	[2.4, 2.7, 2.89, 3.08, 3.29, 3.46, 3.75, 4.04, 4.56]			
1838	glutamyylitransferaasi-desialotransferriini,seerumista	u/l	15	0				
1839	glutamyylitransferaasi-desialotransferriini,seerumista		116	5.17				
1840	glutamyylitransferaasi-desialotransferriini-indeks		162	2.47	[2.73, 3.14, 3.43, 3.77, 4.01, 4.28, 4.54, 4.85, 5.33]			
1841	glutamyylitransferaasi-desialotransferriini-indeksi	1	9	0				
1842	glutamyylitransferaasi-desialotransferriini-indeksi		273	0.73	[2.62, 3.02, 3.33, 3.61, 3.8, 4.09, 4.39, 4.71, 5.2]			
1843	ikäriski/sikiönkehityshäiriöidenseulonta		415	100				
1844	middleeastrespiratorysyndromecoronavirus(mers-cov		104	100				
1845	middleeastrespiratorysyndromecoronavirus(mers-cov)		217	100				
1846	omega3-rasvahappojenkokonaismäärä	%	315	0	[4.06, 4.46, 4.93, 5.34, 5.87, 6.31, 6.91, 7.95, 9.45]			
1847	omega6-rasvahappojenkokonaismäärä	%	315	0	[32.44, 34.61, 35.84, 37.14, 38.6, 39.74, 40.81, 42.17, 43.96]			
1848	s-dokosaheksaeenihaponsuhdekokonaisrasvahappoih	%	255	0	[2.1, 2.28, 2.39, 2.48, 2.6, 2.7, 2.83, 2.98, 3.2]		Serum	
1849	s-dokosaheksaeenihaponsuhdekokonaisrasvahappoih		10	100			Serum	
1850	s-glutamyylitransferaasi-desialotransferriini		493	48.48	[2.78, 3.01, 3.2, 3.4, 3.55, 3.77, 3.9, 4.13, 4.69]		Serum	
1851	s-kertatyydyttymättömienrasvahappojensuhdekoko	%	263	0	[22.37, 23.29, 23.9, 24.4, 24.87, 25.48, 26.05, 26.85, 28.31]		Serum	
1852	s-monityydyttymättömienrasvahappojensuhdekerta		265	4.15	[1.41, 1.57, 1.65, 1.71, 1.78, 1.85, 1.91, 1.99, 2.11]		Serum	
1853	s-monityydyttymättömienrasvahappojensuhdekokon	%	255	0	[39.1, 41.69, 42.87, 43.69, 44.37, 44.93, 45.55, 46.5, 47.41]		Serum	
1854	s-monityydyttymättömienrasvahappojensuhdekokon		10	100			Serum	
1855	s-omega-3-rasvahappojensuhdekokonaisrasvahappoi	%	264	0	[3.56, 4.09, 4.33, 4.54, 4.85, 5.11, 5.48, 5.88, 6.76]		Serum	
1856	s-omega-6-rasvahappojensuhdekokonaisrasvahappoi	%	258	0	[34.2, 36.53, 37.8, 38.75, 39.54, 39.97, 40.65, 41.31, 42.02]		Serum	
1857	s-omega-6-rasvahappojensuhdekokonaisrasvahappoi		7	100			Serum	
1858	s-omega-6-rasvahappojensuhdenomega-3-rasvahappo		265	2.64	[5.49, 6.36, 6.98, 7.54, 7.98, 8.51, 9.08, 9.79, 11.09]		Serum	
1859	s-sikiönkehityshäiriäidenseulonta,ensimmäinen		311	100			Serum	
1860	s-sikiönkehityshäiriöidenseul,ensim.trimesteri		112	100			Serum	
1861	s-sikiönkehityshäiriöidenseulonnat,1.trimesteri		216	100			Serum	
1862	s-sikiönkehityshäiriöidenseulonta,1.trimesteri		403	100			Serum	
1863	s-sikiönkehityshäiriöidenseulonta,ensim.trimesteri		464	100			Serum	
1864	s-sikiönkehityshäiriöidenseulonta,ensimmäinen		174	100			Serum	
1865	s-tyydyttyneidenrasvahappojensuhdekokonaisrasv	%	264	0	[29.01, 29.77, 30.1, 30.62, 31.04, 31.46, 31.82, 32.3, 33.34]		Serum	
1866	sikiönkehityshäiriöidenseuranta,1.trimesteri,hormonit		423	100				
1867	sikiönkehityshäiriöidenseuranta,1.trimesteri,seerumista␤		102	100				

