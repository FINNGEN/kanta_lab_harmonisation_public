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
Here is group 167 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
13496	b-erybla,osatutkimus(19978b-erybla)	e9/l	1575	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Blood	
13497	b-erybla,osatutkimus(b-erybla)	e9/l	3732	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Blood	
13498	b-erybla,osatutkimus(b-erybla)		8	75			Blood	
13499	b-neut,osatutkimus(689b-neut)	e9/l	114	0	[2.36, 2.69, 3.03, 3.4, 3.69, 4.15, 4.59, 5.12, 5.88]		Blood	
13500	basofiilit,absol.arvot,osatutkimus(40b-baso)	e9/l	114	0	[0.02, 0.03, 0.03, 0.04, 0.04, 0.05, 0.06, 0.06, 0.08]			
13501	basofiilit,konediffi(),osatutk.b-diffi	%	1040	0	[0.2, 0.35, 0.48, 0.57, 0.68, 0.78, 0.9, 1.09, 1.35]			
13502	basofiilit,osatutkimus(692l-baso)	%	128	0	[0, 0, 0.88, 1, 1, 1, 1, 1, 1]			
13503	e-rdw,osatutkimus(19976e-rdw)	%	1577	0	[12, 12.98, 13, 13, 13, 13, 13.6, 14, 14.04]		Erythrocyte	
13504	e-rdw,osatutkimus(e-rdw)	%	3731	0	[12, 12.05, 13, 13, 13, 13, 13, 14, 14.04]		Erythrocyte	
13505	e-rdw,osatutkimus(e-rdw)		8	100			Erythrocyte	
13506	eosinofiilit,absol.arvot,osatutkimus(39b-eos)	e9/l	114	0	[0.06, 0.09, 0.12, 0.16, 0.18, 0.2, 0.23, 0.28, 0.33]			
13507	eosinofiilit,konediffi(),osatutk.b-diffi	%	1041	0	[0.08, 1.13, 1.71, 2.33, 2.85, 3.43, 4.13, 5.02, 6.83]			
13508	eosinofiilit,osatutkimus(690l-eos)	%	114	0	[1, 1.43, 2, 2, 3, 3, 3.11, 4, 5]			
13509	eosinofiilitabs,konediffi,osatutk.b-diffi	e9/l	1041	0	[0.01, 0.07, 0.1, 0.14, 0.17, 0.22, 0.27, 0.33, 0.46]			
13510	kalsium,osatutkimus(p-ca)	mmol/l	167	0	[2.26, 2.3, 2.32, 2.34, 2.37, 2.38, 2.41, 2.43, 2.47]			
13511	l-neut,osatutkimus(688l-neut)	%	114	0	[46.1, 51, 53.29, 55, 56.87, 59, 62, 66.13, 71.3]		Leukocyte	
13512	lymfosyytit,absol.arvot,osatutkimus(43b-lymf)	e9/l	114	0	[1.2, 1.42, 1.67, 1.84, 1.94, 2.02, 2.22, 2.46, 2.71]			
13513	lymfosyytit,konediffi(),osatutk.b-diffi	%	1041	0	[14.77, 18.39, 21, 24.27, 27.4, 30.54, 33.61, 37.23, 41.49]			
13514	lymfosyytit,osatutkimus(46l-lymf)	%	114	0	[17.98, 23.4, 26.71, 28, 31, 32.84, 34.76, 36, 40.42]			
13515	monosyytit,absol.arvot,osatutkimus(42b-monos)	e9/l	114	0	[0.36, 0.42, 0.44, 0.49, 0.53, 0.58, 0.62, 0.67, 0.77]			
13516	monosyytit,konediffi(),osatutk.b-diffi	%	1041	0	[6.01, 6.87, 7.49, 8.19, 8.74, 9.45, 10.43, 11.69, 13.27]			
13517	monosyytit,osatutkimus(693l-monos)	%	114	0	[6, 6.9, 7, 8, 8, 9, 9, 10, 11]			
13518	neutrofiiliset,konediffi(),osatutk.b-diffi	%	1041	0	[43.33, 48.08, 51.94, 55.59, 58.77, 61.59, 65.14, 69.9, 74.47]			
13519	neutrofiilitabs,konediffi,osatutk.b-diffi	e9/l	1041	0	[1.86, 2.39, 2.82, 3.25, 3.63, 4.11, 4.7, 5.54, 6.96]			
13520	s-albumiini,osatutkimuss-prot-fr	g/l	109	0	[31.62, 35.39, 37.28, 38.52, 39.57, 40.75, 41.75, 43.12, 44]		Serum	Fractions
13521	s-alfa-1-globuliini,osatutkimuss-prot-fr	g/l	109	0	[2.3, 2.4, 2.54, 2.7, 2.89, 3.08, 3.35, 3.6, 4.2]		Serum	Fractions
13522	s-alfa-2-globuliini,osatutkimuss-prot-fr	g/l	109	0	[5.63, 6, 6.24, 6.66, 7.47, 7.93, 8.35, 9.06, 9.9]		Serum	Fractions
13523	s-beta-1-globuliini,osatutkimuss-prot-fr	g/l	109	0	[3.5, 3.7, 3.85, 4.04, 4.14, 4.31, 4.42, 4.7, 4.9]		Serum	Fractions
13524	s-beta-2-globuliini,osatutkimuss-prot-fr	g/l	109	0	[2.8, 3.09, 3.44, 3.86, 4.01, 4.31, 4.58, 4.8, 5.27]		Serum	Fractions
13525	s-gamma-globuliini,osatutkimuss-prot-fr	g/l	109	0	[6.61, 7.97, 8.64, 9.16, 9.73, 10.36, 11, 11.66, 12.99]		Serum	Fractions
13526	s-m-komponentti-1(valetietues-prot-fr)	g/l	135	0	[0, 0, 0, 1.3, 2.13, 3.83, 5.42, 7.84, 12.97]		Serum	
13527	s-m-komponentti-1(valetietues-prot-fr)		93	100			Serum	
13528	s-m-komponentti-2(valetietues-prot-fr)	g/l	82	0	[0, 0, 0, 0, 0, 0, 0, 0, 1]		Serum	
13529	s-m-komponentti-2(valetietues-prot-fr)		133	100			Serum	
13530	s-m-komponentti-3(valetietues-prot-fr)		131	100			Serum	

