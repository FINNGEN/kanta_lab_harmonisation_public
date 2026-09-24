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
Here is group 105 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
8557	b-pvk	%	1036	0	[12.98, 13, 13, 13, 13.02, 14, 14, 14, 14.9]	B -Perusverenkuva	Blood	
8558	b-pvk	e12/l	180	0		B -Perusverenkuva	Blood	
8559	b-pvk	e9/l	180	0		B -Perusverenkuva	Blood	
8560	b-pvk	fl	191	0		B -Perusverenkuva	Blood	
8561	b-pvk	form	6	0		B -Perusverenkuva	Blood	
8562	b-pvk	g/l	371	0	[130.49, 135.97, 140.17, 143.56, 146.5, 149.94, 154.99, 161.16, 169.87]	B -Perusverenkuva	Blood	
8563	b-pvk	paketti	261	0	[31329.79, 60496.46, 87166.96, 116360.34, 146168.26, 177141.71, 213025.07, 240401.38, 278743.21]	B -Perusverenkuva	Blood	
8564	b-pvk	pg	191	0		B -Perusverenkuva	Blood	
8565	b-pvk		1084645	100		B -Perusverenkuva	Blood	
8566	b-pvk(pi)		994	100			Blood	
8567	b-pvk+eo		1355	100			Blood	
8568	b-pvk+kd		335	100			Blood	
8569	b-pvk+ne		301325	100			Blood	
8570	b-pvk+ner		551	100			Blood	
8571	b-pvk+t	%	16337	0	[8.54, 11.43, 12.73, 13.01, 14.63, 21.66, 27.29, 34.08, 48.89]	B -Perusverenkuva ja trombosyytit	Blood	
8572	b-pvk+t	%g	229	0		B -Perusverenkuva ja trombosyytit	Blood	
8573	b-pvk+t	%l	229	0	[15.3, 18.86, 20.93, 24.39, 26.09, 27.9, 29.48, 31.36, 37.88]	B -Perusverenkuva ja trombosyytit	Blood	
8574	b-pvk+t	%m	229	0	[9, 10, 10.3, 10.73, 11, 11.47, 11.97, 12.55, 13.3]	B -Perusverenkuva ja trombosyytit	Blood	
8575	b-pvk+t	e12/l	8	0		B -Perusverenkuva ja trombosyytit	Blood	
8576	b-pvk+t	e9/l	4647	0	[0, 0, 0, 0, 0, 0, 2.04, 5.2, 8.91]	B -Perusverenkuva ja trombosyytit	Blood	
8577	b-pvk+t	fl	8	0		B -Perusverenkuva ja trombosyytit	Blood	
8578	b-pvk+t	form	361	0	[0, 0, 0, 0, 0, 0, 0, 0.89, 1]	B -Perusverenkuva ja trombosyytit	Blood	
8579	b-pvk+t	g/l	2746	0	[312.86, 315.11, 317.96, 319.16, 327.56, 334.19, 340.53, 346.44, 355.56]	B -Perusverenkuva ja trombosyytit	Blood	
8580	b-pvk+t	l/l	6	0		B -Perusverenkuva ja trombosyytit	Blood	
8581	b-pvk+t	paketti	269	0	[1, 1, 1, 1, 1, 1, 1, 1, 1]	B -Perusverenkuva ja trombosyytit	Blood	
8582	b-pvk+t	pg	2769	0	[29, 29.58, 30, 30.35, 31, 31.07, 32, 32.99, 34.11]	B -Perusverenkuva ja trombosyytit	Blood	
8583	b-pvk+t		4547373	100	[1, 1, 1, 1, 1, 1, 1, 1, 1]	B -Perusverenkuva ja trombosyytit	Blood	
8584	b-pvk+t+e		1491	100			Blood	
8585	b-pvk+t+n		20012	100			Blood	
8586	b-pvk+t+ne		1150	100			Blood	
8587	b-pvk+t+r		713	100			Blood	
8588	b-pvk+tk		466	100			Blood	
8589	b-pvk+tkd	%	567	0	[10.52, 11.98, 22.28, 26.53, 30.21, 32.92, 36.29, 39.43, 43.1]	B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit	Blood	
8590	b-pvk+tkd	e9/l	5	0		B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit	Blood	
8591	b-pvk+tkd		347141	99.77	[1, 1, 1, 1, 1, 1, 1, 1, 1]	B -Perusverenkuva, leukosyyttien erittelylaskenta koneella, solujakauma, trombosyytit	Blood	
8592	b-pvk+tkd,baso	%	4387	0	[0.13, 0.2, 0.3, 0.34, 0.4, 0.5, 0.59, 0.7, 0.91]		Blood	
8593	b-pvk+tkd,baso	e9/l	4345	0	[0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.05, 0.06]		Blood	
8594	b-pvk+tkd,baso		28	96.43			Blood	
8595	b-pvk+tkd,eo	%	4389	0	[0.28, 0.95, 1.44, 1.88, 2.38, 2.9, 3.5, 4.34, 5.77]		Blood	
8596	b-pvk+tkd,eo	e9/l	4355	0	[0.02, 0.07, 0.1, 0.13, 0.16, 0.2, 0.24, 0.3, 0.39]		Blood	
8597	b-pvk+tkd,eo		35	77.14			Blood	
8598	b-pvk+tkd,eryt	e12/l	4432	0	[3.69, 4.01, 4.19, 4.32, 4.47, 4.6, 4.71, 4.86, 5.08]		Blood	
8599	b-pvk+tkd,eryt		28	82.14			Blood	
8600	b-pvk+tkd,hb	g/l	4431	0	[109.63, 119.87, 125.6, 130.31, 134.35, 137.72, 141.31, 145.38, 151.58]		Blood	
8601	b-pvk+tkd,hb		28	82.14			Blood	
8602	b-pvk+tkd,hkr	osuus	4430	0	[0.34, 0.36, 0.38, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45]		Blood	
8603	b-pvk+tkd,hkr		28	82.14			Blood	
8604	b-pvk+tkd,ig	%	4380	0	[0, 0.1, 0.18, 0.2, 0.2, 0.24, 0.3, 0.4, 0.66]		Blood	
8605	b-pvk+tkd,ig	e9/l	4329	0	[0, 0.01, 0.01, 0.01, 0.01, 0.02, 0.02, 0.03, 0.06]		Blood	
8606	b-pvk+tkd,ig		27	100			Blood	
8607	b-pvk+tkd,leuk	e9/l	4441	0	[4.64, 5.29, 5.87, 6.47, 7.06, 7.73, 8.41, 9.34, 10.91]		Blood	
8608	b-pvk+tkd,leuk		23	100	[4.39, 5.06, 5.62, 6.11, 6.7, 7.36, 7.96, 8.73, 10.19]		Blood	
8609	b-pvk+tkd,lymph	%	4402	0	[14.51, 18.87, 22.17, 24.95, 27.85, 30.77, 33.85, 37.68, 42.79]		Blood	
8610	b-pvk+tkd,lymph	e9/l	4366	0	[1.07, 1.3, 1.5, 1.68, 1.87, 2.05, 2.28, 2.59, 3.03]		Blood	
8611	b-pvk+tkd,lymph		39	71.79			Blood	
8612	b-pvk+tkd,mch	pg	4427	0	[27.35, 28.81, 29.01, 30, 30, 30.98, 31, 31.99, 32.41]		Blood	
8613	b-pvk+tkd,mch		26	88.46			Blood	
8614	b-pvk+tkd,mchc	g/l	4422	0	[316.84, 322.97, 327.09, 330.49, 333.34, 336.5, 339.82, 343.59, 348.74]		Blood	
8615	b-pvk+tkd,mchc		27	85.19			Blood	
8616	b-pvk+tkd,mcv	fl	4432	0	[83.81, 86.19, 87.9, 89.02, 90.1, 91.52, 92.95, 94.05, 96.04]		Blood	
8617	b-pvk+tkd,mcv		25	92			Blood	
8618	b-pvk+tkd,mono	%	4397	0	[6.39, 7.45, 8.16, 8.78, 9.38, 10.01, 10.67, 11.64, 13.06]		Blood	
8619	b-pvk+tkd,mono	e9/l	4364	0	[0.41, 0.48, 0.54, 0.59, 0.65, 0.7, 0.78, 0.88, 1.03]		Blood	
8620	b-pvk+tkd,mono		32	84.38			Blood	
8621	b-pvk+tkd,neut	%	4407	0	[43.3, 48.04, 51.9, 55.37, 58.56, 61.78, 65.36, 69.3, 74.25]		Blood	
8622	b-pvk+tkd,neut	e9/l	4373	0	[2.18, 2.67, 3.11, 3.55, 4, 4.52, 5.12, 5.94, 7.37]		Blood	
8623	b-pvk+tkd,neut		34	82.35			Blood	
8624	b-pvk+tkd,rdw	%	4298	0	[12.5, 12.85, 13.17, 13.49, 13.79, 14.12, 14.57, 15.17, 16.52]		Blood	
8625	b-pvk+tkd,rdw		30	76.67			Blood	
8626	b-pvk+tkd,trom	eg/l	4413	0	[163.91, 190.28, 209.92, 228.62, 246.86, 267.53, 293.03, 326.64, 371.27]		Blood	
8627	b-pvk+tkd,trom		31	74.19			Blood	
8628	b-pvk+tmd	%	108	0		B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää)	Blood	
8629	b-pvk+tmd		31394	99.96		B -Perusverenkuva, minidiffi, trombosyytit (erytrosyytit, Hb, leukosyytit, 2-3 leukosyyttiryhmää)	Blood	
8630	b-pvk-päi		120	100			Blood	
8631	b-pvk-t		1651	100			Blood	
8632	b-pvk-tkd		5227	100			Blood	
8633	b-pvkt		540592	100			Blood	
8634	b-pvkt+re		3032	100			Blood	
8635	b-pvktkdr		6444	100			Blood	
8636	b-pvktmdl		275	100			Blood	
8637	b-pvktmdp		1012	100			Blood	
8638	b-pvktnee		9809	100			Blood	
8639	b-pvktp		5212	100			Blood	
8640	b-tvk	%	505	0	[0, 0, 0, 0, 1, 2.55, 12.33, 37.94, 62.13]	B -Täydellinen verenkuva	Blood	
8641	b-tvk	e9/l	368	0	[0.03, 0.03, 0.04, 0.04, 0.05, 0.05, 0.06, 0.07, 0.09]	B -Täydellinen verenkuva	Blood	
8642	b-tvk	fl	17	0		B -Täydellinen verenkuva	Blood	
8643	b-tvk	form	11	0		B -Täydellinen verenkuva	Blood	
8644	b-tvk	g/l	19	0		B -Täydellinen verenkuva	Blood	
8645	b-tvk	paketti	22	0		B -Täydellinen verenkuva	Blood	
8646	b-tvk	pg	17	0		B -Täydellinen verenkuva	Blood	
8647	b-tvk		466809	100		B -Täydellinen verenkuva	Blood	
8648	b-tvk+r		465	100			Blood	

