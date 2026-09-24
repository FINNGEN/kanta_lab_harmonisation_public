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
Here is group 161 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
13017	b-fosfatidyylietanoli	umol/l	4792	0	[0.06, 0.1, 0.15, 0.22, 0.3, 0.44, 0.64, 0.94, 1.57]		Blood	
13018	b-fosfatidyylietanoli		4963	89.32	[0.09, 0.13, 0.17, 0.29, 0.43, 0.63, 0.85, 1.22, 1.87]		Blood	
13019	b-fosfatidyylietanoli,verestä	umol/l	1555	0	[0.06, 0.1, 0.15, 0.22, 0.29, 0.41, 0.59, 0.87, 1.44]		Blood	
13020	b-fosfatidyylietanoli,verestä		1534	97.07			Blood	
13021	b-fosfatidyylietanolivita	umol/l	43	0			Blood	
13022	b-fosfatidyylietanolivita		69	100			Blood	
13023	b-haemophilusinfluenzae		144	100			Blood	
13024	b-suuretvärjäytymättömätsolut	e9/l	171	0	[0.07, 0.09, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15, 0.18]		Blood	
13025	chlamydiapneumoniae,nukleiin		109	100				
13026	follikkeliastimuloivahormoni	u/l	138	0	[3, 4.75, 6.19, 8.24, 10, 19.35, 36.42, 56.82, 73.33]			
13027	fosfatidyylietanoli	umol/l	1540	0	[0.05, 0.09, 0.14, 0.2, 0.29, 0.43, 0.63, 0.98, 1.62]			
13028	fosfatidyylietanoli		1635	92.35	[0.09, 0.19, 0.32, 0.43, 0.64, 0.89, 1.16, 1.43, 1.78]			
13029	fosfatidyylietanoli,verestä	umol/l	3284	0	[0.06, 0.08, 0.12, 0.16, 0.22, 0.3, 0.44, 0.66, 1.2]			
13030	fosfatidyylietanoli,verestä		3273	98.93				
13031	fosfatidyylietanoli,verestätth	umol/l	35	0				
13032	fosfatidyylietanoli,verestätth		66	100				
13033	fosfatidyylietanoli,veri	umol/l	335	0	[0.06, 0.1, 0.15, 0.2, 0.28, 0.39, 0.6, 0.91, 1.55]			
13034	fosfatidyylietanoli,veri		333	91.89				
13035	haemophilusinfluenzaenukleii		459	100				
13036	humaanimetapneumovirus,nukle		109	100				
13037	humanmetapneumovirus,ag		102	100				
13038	l-suuretvärjääntymättömätsolut	%	171	0	[1.19, 1.35, 1.5, 1.62, 1.83, 1.97, 2.16, 2.45, 2.85]		Leukocyte	
13039	legionellapneumoniaenukleiin		109	100				
13040	li-haemophilusinfluenzaenukl.haponos.		119	100			Cerebrospinal fluid	
13041	mycoplasmapneumoniae,nukleii		141	100				
13042	p-follikkeliastimuloivahormoni	u/l	511	0	[2.89, 4.55, 5.71, 7.4, 9.51, 16.11, 32.21, 53.45, 77.25]		Plasma	
13043	p-glukoosi,2tuntiaaterianjälkeen	mmol/l	125	0	[6.3, 7.71, 9.12, 10.17, 11.1, 12.22, 14.28, 15.89, 18.81]		Plasma	
13044	p-glukoosi,toimintakokeissa,1h	mmol/l	126	0	[5.54, 6.18, 6.52, 7.01, 7.43, 7.82, 8.23, 9.1, 9.88]		Plasma	
13045	p-glukoosi,toimintakokeissa,2h	mmol/l	240	0	[4.47, 5.01, 5.34, 5.8, 6.31, 7.03, 7.79, 8.75, 11.07]		Plasma	
13046	p-glukoosi,toimntakokeissa0m	mmol/l	242	0	[4.3, 4.6, 4.8, 5.01, 5.22, 5.42, 5.83, 6.26, 6.93]		Plasma	
13047	p-luteinisoivahormoni	u/l	198	0	[2.79, 3.77, 4.73, 5.42, 6.66, 8.63, 10.71, 14.48, 27.26]		Plasma	
13048	p-luteinisoivahormoni		10	100			Plasma	
13049	p-omagluk,,potilasmittaringlukoosi		1376	100			Plasma	
13050	potilasmittaringlukoosi,ihopisto	mmol/l	749	0	[5.9, 6.36, 6.79, 7.19, 7.51, 7.86, 8.26, 8.85, 9.69]			
13051	potilasmittaringlukoosi,ihopisto		638	100				
13052	potilasmittaringlukoosi,sensori	mmol/l	201	0	[5.55, 6.53, 7.01, 7.7, 8.35, 9.14, 10.02, 11.7, 13.49]			
13053	potilasmittaringlukoosi,sensori		568	100				
13054	s-c-peptidi1haterianjälkeen	nmol/l	275	0	[0.5, 0.75, 0.96, 1.2, 1.4, 1.62, 1.92, 2.33, 3.08]		Serum	
13055	s-c-peptidi1haterianjälkeen		10	90			Serum	
13056	s-c-peptidiaterianjälkeen	nmol/l	150	0	[0.4, 0.65, 0.9, 1.07, 1.22, 1.49, 2.03, 2.41, 2.88]		Serum	
13057	s-follikkeliastimuloivahormoni	iu/l	416	0	[3.31, 4.85, 6.04, 7.33, 10.33, 18.46, 32.36, 54.77, 76.02]		Serum	
13058	s-follikkeliastimuloivahormoni	u/l	80	0	[3.2, 4.8, 5.65, 6.55, 7.78, 10.22, 16.95, 45.35, 68.7]		Serum	
13059	s-follikkeliastimuloivahormoni		7	100			Serum	
13060	s-kertatyydyttymättömätrasvahapot	mmol/l	263	0	[2.43, 2.7, 2.8, 2.99, 3.17, 3.35, 3.54, 3.9, 4.36]		Serum	
13061	s-luteinisoivahormoni	iu/l	178	0	[1.51, 2.37, 3.11, 3.71, 4.6, 5.61, 7.56, 11.94, 22.46]		Serum	
13062	s-luteinisoivahormoni	u/l	26	0			Serum	
13063	s-luteinisoivahormoni		14	100			Serum	
13064	s-monityydyttymättömätrasvahapot	mmol/l	255	0	[4.74, 4.99, 5.23, 5.48, 5.58, 5.7, 5.92, 6.18, 6.55]		Serum	
13065	s-monityydyttymättömätrasvahapot		11	100			Serum	
13066	s-tyydyttyneetrasvahapot	mmol/l	265	0	[3.09, 3.37, 3.58, 3.77, 3.9, 4.15, 4.36, 4.73, 5.26]		Serum	
13067	ulosteenripulivirukset,nukle		109	100				

