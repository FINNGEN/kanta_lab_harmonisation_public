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
Here is group 31 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1733	p-prostataspesifantigeeni,sms-viestillätulos	ug/l	344	0	[0.07, 0.12, 0.17, 0.23, 0.3, 0.41, 0.59, 1.29, 4.88]		Plasma	
1734	p-prostataspesifantigeeni,sms-viestillätulos		207	100			Plasma	
1735	p-prostataspesifinenantigeeni	ug/l	5957	0	[0.23, 0.44, 0.67, 0.95, 1.3, 1.82, 2.66, 4.14, 7.42]		Plasma	
1736	p-prostataspesifinenantigeeni		603	98.51			Plasma	
1737	p-prostataspesifinenantigeeni,kokonais	ug/l	726	0	[0.03, 0.3, 0.6, 0.93, 1.35, 1.9, 2.65, 3.96, 6.75]		Plasma	
1738	p-prostataspesifinenantigeeni,suh.sis.paketin	%	20	0			Plasma	
1739	p-prostataspesifinenantigeeni,suh.sis.paketin		111	100			Plasma	
1740	p-prostataspesifinenantigeeni,suhde	%	1190	0	[10.27, 13.22, 16.02, 18.81, 21.71, 24.6, 27.53, 31.28, 38.46]		Plasma	
1741	p-prostataspesifinenantigeeni,suhde		1161	99.74			Plasma	
1742	p-prostataspesifinenantigeeni,suhde,plasmasta	%	306	0	[12.73, 16.78, 20.98, 23.56, 26.75, 30.67, 33.91, 38.07, 45.37]		Plasma	
1743	p-prostataspesifinenantigeeni,suhde,plasmasta		761	100			Plasma	
1744	p-prostataspesifinenantigeeni,vapaa	ug/l	844	0	[0.34, 0.5, 0.6, 0.7, 0.8, 0.93, 1.1, 1.31, 1.68]		Plasma	
1745	p-prostataspesifinenantigeeni,vapaa		1223	100			Plasma	
1746	p-prostataspesifinenantigeeni,vapaa,osuus	%	204	0	[11.98, 16.23, 19, 21.79, 24.86, 27.66, 31.64, 35.9, 42.37]		Plasma	
1747	p-prostataspesifinenantigeeni,vapaa,osuus		429	100			Plasma	
1748	p-prostataspesifinenantigeenivapaa/kokonais-suh		653	100			Plasma	
1749	p-prostataspesifinenantigeenivapaanjakok.psa:	%	185	0	[9, 11.25, 13.89, 16, 18.6, 21.82, 25.12, 28.17, 34.22]		Plasma	
1750	prostataspesifinenantigeeni	ug/l	2969	0	[0.34, 0.57, 0.81, 1.08, 1.44, 1.91, 2.54, 3.51, 5.41]			
1751	prostataspesifinenantigeeni		220	100				
1752	prostataspesifinenantigeeni,kokonais	ug/l	178	0	[0.48, 0.6, 0.75, 0.91, 1.11, 1.39, 1.75, 2.69, 4.32]			
1753	prostataspesifinenantigeeni,kokonais		8	100				
1754	prostataspesifinenantigeeni,osuus	%	108	0				
1755	prostataspesifinenantigeeni,suhde	%	1497	0	[11.32, 14.96, 17.27, 19.84, 22.37, 25.13, 28.18, 32.11, 38.22]			
1756	prostataspesifinenantigeeni,suhde		1026	100				
1757	prostataspesifinenantigeeni,totaali	ug/l	109	0	[0.5, 0.69, 0.77, 0.8, 0.97, 1.14, 1.37, 1.95, 3.3]			
1758	prostataspesifinenantigeeni,vapaa	%	20	0				
1759	prostataspesifinenantigeeni,vapaa	ug/l	289	0	[0.24, 0.3, 0.4, 0.5, 0.58, 0.7, 0.79, 0.91, 1.22]			
1760	prostataspesifinenantigeeni,vapaa		83	89.16				
1761	prostataspesifinenantigeeni,vapaa(p-psa-v)	ug/l	113	0	[0.4, 0.5, 0.5, 0.6, 0.6, 0.7, 0.8, 0.9, 1.29]			
1762	prostataspesifinenantigeeni,vapaa,osuus,seerumista		1501	99.93				
1763	prostataspesifinenantigeeni,vapaa/kokonais-suhde,osatutk.4637eikiinnit.	%	156	0	[9.16, 12.73, 15.43, 17.1, 19.75, 23.23, 27.12, 31.1, 36.35]			
1764	prostataspesifinenantigeeni,vapaanosuus(vainlaboratorionkäytössä)	%	1293	0	[10.04, 13.36, 16.08, 18.85, 21.21, 23.95, 26.02, 29.25, 35.73]			
1765	prostataspesifinenantigeeni,vapaanosuus(vainlaboratorionkäytössä)		7	100				
1766	prostataspesifinenantigeenivapaa/kokonaispitois	%	144	0	[10.77, 13.72, 16.37, 20.21, 22.12, 23.69, 27.12, 32.53, 38.12]			
1767	s-prostataspesifinenantigeeni	ug/l	97	0	[0.5, 0.72, 0.83, 0.95, 1.08, 1.3, 1.65, 2.24, 3.2]		Serum	
1768	s-prostataspesifinenantigeeni		195	14.36	[0.4, 0.56, 0.8, 1.06, 1.36, 1.69, 2.1, 2.89, 4.92]		Serum	
1769	s-prostataspesifinenantigeeni,kokonais	ug/l	5067	0	[0.3, 0.54, 0.83, 1.15, 1.62, 2.33, 3.4, 5.29, 8.45]		Serum	
1770	s-prostataspesifinenantigeeni,kokonais		918	94.99			Serum	
1771	s-prostataspesifinenantigeeni,vapaa	ug/l	1170	0	[0.38, 0.49, 0.59, 0.68, 0.8, 0.94, 1.11, 1.31, 1.76]		Serum	
1772	s-prostataspesifinenantigeeni,vapaa		81	93.83			Serum	
1773	s-prostataspesifinenantigeeni,vapaa,osuus	%	14	0			Serum	
1774	s-prostataspesifinenantigeeni,vapaa,osuus		2529	100			Serum	
1775	s-prostataspesifinenantigeeni,vapaa,osuus(ko)		268	100			Serum	
1776	s-prostataspesifinenantigeeni,vapaa/kokonais-su	%	471	0	[12.91, 15.74, 18.47, 20.97, 24.1, 27.26, 30.75, 34.12, 40.61]		Serum	
1777	s-prostataspesifinenantigeeni,vapaa/kokonais-suhde	%	1148	0	[9.99, 12.9, 14.91, 17.33, 19.9, 23.19, 25.99, 30.56, 36.21]		Serum	
1778	s-prostataspesifinenantigeeni,vapaa/kokonais-suhde		52	26.92			Serum	
1779	s-prostataspesifinenantigeeni,vapaa/totaali	%	4124	0	[7.95, 10.72, 13.28, 15.51, 18.09, 20.83, 23.88, 27.98, 34.07]		Serum	
1780	s-prostataspesifinenantigeeni,vapaa/totaali		7	100			Serum	
1781	s-prostataspesifinenantigeeni,vapaansuhde	%	30	0			Serum	
1782	s-prostataspesifinenantigeeni,vapaansuhde		119	100			Serum	
1783	s-prostataspesifinenantigeenivap/tot-suhde	%	280	0	[9.62, 12.38, 14.88, 16.91, 19.36, 21.92, 26.09, 30.67, 36.38]		Serum	
1784	s-prostatspesifinenantigeeni,kokonais	ug/l	98	0	[0.3, 0.5, 0.6, 0.96, 1.2, 1.39, 1.6, 2.12, 3.1]		Serum	
1785	s-prostatspesifinenantigeeni,kokonais		34	52.94			Serum	

