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
Here is group 30 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1695	fp-kolesteroli,highdensitylipoproteiinit	mmol/l	15536	0	[0.98, 1.1, 1.2, 1.3, 1.4, 1.5, 1.62, 1.78, 2.01]		Fasting plasma	
1696	fp-kolesteroli,highdensitylipoproteiinit		196	98.98			Fasting plasma	
1697	fp-kolesteroli,highdensitylipoprotein,plasmasta	mmol/l	736	0	[1.03, 1.15, 1.25, 1.34, 1.43, 1.54, 1.64, 1.82, 2.02]		Fasting plasma	
1698	fp-kolesteroli,lowdensitylipoproteiinit	mmol/l	4851	0	[1.25, 1.51, 1.76, 2.01, 2.3, 2.63, 2.98, 3.4, 3.98]		Fasting plasma	
1699	fp-kolesteroli,lowdensitylipoproteiinit		65	63.08	[3.07, 3.3, 3.5, 3.7, 3.8, 3.98, 4.16, 4.4, 4.88]		Fasting plasma	
1700	fp-kolesteroli,lowdensitylipoproteiinit,paastotilassa	mmol/l	249	0	[1.3, 1.58, 1.74, 1.98, 2.2, 2.54, 2.88, 3.21, 3.79]		Fasting plasma	
1701	fp-kolesteroli,lowdensitylipoproteiinit,suora	mmol/l	1652	0	[1.2, 1.44, 1.7, 1.91, 2.17, 2.45, 2.8, 3.18, 3.69]		Fasting plasma	
1702	fp-kolesteroli,lowdensitylipoprotein	mmol/l	7970	0	[1.36, 1.65, 1.89, 2.14, 2.4, 2.69, 3, 3.36, 3.89]		Fasting plasma	
1703	fp-kolesteroli,lowdensitylipoprotein		27	100			Fasting plasma	
1704	fs-kolesteroli,highdensitylipoproteiinit	mmol/l	3702	0	[1.06, 1.2, 1.3, 1.38, 1.48, 1.57, 1.69, 1.81, 2.04]		Fasting serum	
1705	fs-kolesteroli,highdensitylipoproteiinit		16	56.25			Fasting serum	
1706	fs-kolesteroli,lowdensitylipoproteiinit	mmol/l	3671	0	[2.04, 2.39, 2.64, 2.89, 3.12, 3.35, 3.59, 3.88, 4.31]		Fasting serum	
1707	fs-kolesteroli,lowdensitylipoproteiinit		50	44			Fasting serum	
1708	fs-kolestroli,highdensitylipoproteiini	mmol/l	201	0	[0.99, 1.11, 1.26, 1.37, 1.5, 1.61, 1.74, 1.87, 2.2]		Fasting serum	
1709	fs-kolestroli,lowdensitylipoproteiini	mmol/l	198	0	[1.41, 1.7, 1.99, 2.23, 2.48, 2.84, 3.15, 3.55, 3.95]		Fasting serum	
1710	kolesteroli,hdl/lipidit,osatutkimus(4516fp-hdl-kol)osatutkimus	mmol/l	201	0	[0.97, 1.12, 1.19, 1.27, 1.38, 1.49, 1.61, 1.79, 1.95]			
1711	kolesteroli,highdensitylipoproteiinit	mmol/l	8629	0	[1, 1.14, 1.24, 1.34, 1.42, 1.52, 1.64, 1.8, 2.02]			
1712	kolesteroli,highdensitylipoproteiinit		54	87.04				
1713	kolesteroli,highdensitylipoproteiinit,plasmasta	mmol/l	711	0	[1.09, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.87, 2.1]			
1714	kolesteroli,highdensitylipoproteiinit/lipidit	mmol/l	2911	0	[0.97, 1.1, 1.2, 1.3, 1.39, 1.49, 1.61, 1.76, 2.01]			
1715	kolesteroli,highdensitylipoproteiinit/lipidit		6	100				
1716	kolesteroli,highdensitylipoproteiinit/lipiditosatutkimus	mmol/l	1186	0	[0.96, 1.07, 1.16, 1.25, 1.34, 1.43, 1.57, 1.71, 1.95]			
1717	kolesteroli,highdensitylipoprotein,plasmasta,paastotilassa(fp-kol-hdl)	mmol/l	3523	0	[1.01, 1.18, 1.31, 1.44, 1.58, 1.72, 1.86, 2.03, 2.28]			
1718	kolesteroli,lowdensitylipoproteiinit	mmol/l	5017	0	[1.39, 1.71, 2, 2.28, 2.55, 2.82, 3.13, 3.48, 4]			
1719	kolesteroli,lowdensitylipoproteiinit		67	88.06				
1720	kolesteroli,lowdensitylipoproteiinit(ldl)/lipidit	mmol/l	2757	0	[2.05, 2.36, 2.63, 2.87, 3.1, 3.35, 3.59, 3.87, 4.34]			
1721	kolesteroli,lowdensitylipoproteiinit(ldl)/lipidit		20	30				
1722	kolesteroli,lowdensitylipoproteiinit(ldl)/lipidit(4599fp-kol-ldl/lipidit),osatutkimus	mmol/l	258	0	[1.81, 2.3, 2.51, 2.7, 2.9, 3.15, 3.39, 3.66, 4.16]			
1723	kolesteroli,lowdensitylipoproteiinit(ldl)/lipiditosatutkimus	mmol/l	1185	0	[1.79, 2.17, 2.4, 2.66, 2.88, 3.1, 3.35, 3.65, 4.11]			
1724	kolesteroli,lowdensitylipoproteiinit/lipidit	mmol/l	134	0	[1.86, 2.31, 2.49, 2.68, 2.96, 3.21, 3.48, 3.8, 4.2]			
1725	kolesteroli,lowdensitylipoproteiniit,plasmasta	mmol/l	704	0	[2.09, 2.45, 2.72, 2.94, 3.19, 3.33, 3.59, 3.88, 4.23]			
1726	kolesteroli/lipidit,osatutkimus(4515fp-kol/lipidit)	mmol/l	190	0	[3.68, 4.13, 4.43, 4.64, 4.95, 5.19, 5.4, 5.63, 6.23]			
1727	p-kolesteroli,highdensitylipoproteiinit	mmol/l	3597	0	[1.03, 1.15, 1.26, 1.36, 1.45, 1.56, 1.67, 1.82, 2.04]		Plasma	
1728	p-kolesteroli,highdensitylipoproteiinit		7	100			Plasma	
1729	p-kolesteroli,lowdensitylipoproteiinit	mmol/l	7255	0	[1.25, 1.51, 1.74, 1.96, 2.2, 2.47, 2.79, 3.17, 3.71]		Plasma	
1730	p-kolesteroli,lowdensitylipoproteiinit		18	94.44			Plasma	
1731	s-kolesteroli,lowdensitylipoproteiinit	mmol/l	248	0	[1.83, 2.22, 2.58, 2.84, 3.09, 3.35, 3.7, 4.06, 4.39]		Serum	
1732	s-kolesteroli,osatutkimushighdensitylipoproteiinit	mmol/l	161	0	[0.93, 1.12, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 2]		Serum	

