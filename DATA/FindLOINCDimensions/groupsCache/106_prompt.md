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
Here is group 106 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
8649	-bakt-he		111	100				Antibiotic sensitivity
8650	-bakt-lm		545	100				Species identification
8651	-baktvi		1515	100		-Bakteeri, viljely		
8652	-baktvr		22025	100		-Bakteeri, värjäys		
8653	af-baktvi		262	100			Aspiration fluid	
8654	as-baktvr		252	100			Ascitic fluid	
8655	b-bakt-vi		1757	100			Blood	Culture
8656	b-baktjvi		28084	100		B -Bakteeri, jatkoviljely	Blood	
8657	b-baktsvi		6514	100			Blood	
8658	b-baktvi		506538	100		B -Bakteeri, viljely	Blood	
8659	b-baktvi.		2240	100			Blood	
8660	b-baktvij		1818	100			Blood	
8661	bakteerit		6114	100				
8662	baktlm		897	100				
8663	baktvr		339	100				
8664	bl-baktvi		303	100			Bronchoalveolar lavage	
8665	bo-baktvi		312	100			Bone	
8666	ca-baktvi		1564	100		Ca-Bakteeri, viljely suonikanyylista		
8667	d-baktvi		120	100				
8668	ex-baktvi		14096	100		Ex-Bakteeri, viljely	Expectorate (sputum)	
8669	ex-baktvr		3217	100			Expectorate (sputum)	
8670	f-baktjvi		281	100			Feces	
8671	f-baktvi1		32771	100		F -Bakteeri, viljely 1 (Salmonella, Shigella, Yersinia, Campylobacter)	Feces	
8672	f-baktvi2		739	100		F -Bakteeri, viljely 2 (Clostridium difficile, Staphylococcus aureus, candida)	Feces	
8673	f-baktvi3		1380	100		F -Bakteeri, viljely 3 (viljely 1 + Bacillus cereus, Clostridium perfringens, Staphylococcus aureus)	Feces	
8674	f-baktvip		17284	100			Feces	
8675	fl-baktna		154	100			Vaginal discharge	
8676	fl-baktvr		11637	100		Fl-Bakteeri, värjäys	Vaginal discharge	
8677	li-baktvi		7020	100		Li-Bakteeri, viljely	Cerebrospinal fluid	
8678	li-baktvr		3747	100		Li-Bakteeri, värjäys	Cerebrospinal fluid	
8679	pd-baktvi		917	100		Pd-Bakteeri, viljely peritoneaalidialyysinesteestä	Peritoneal dialysis fluid	
8680	pf-baktvr		258	100			Pleural fluid	
8681	pp-baktnh		445	100		Pp-Bakteeri, nukleiinihappo (kvant), ientasku	Periodontal pocket	
8682	ps-baktvi		3894	99.97		Ps-Bakteeri, viljely	Pharyngeal secretion	
8683	pu-baktvi1		132179	100		Pu-Bakteeri, viljely 1 (anaerobi + aerobiviljely, syvämärkä)	Pus	
8684	pu-baktvi2		97752	100		Pu-Bakteeri, viljely 2 (aerobiviljely, pintamärkä)	Pus	
8685	sy-baktvr		1225	100			Synovial fluid	
8686	u-bact		4570	19.15	[1.88, 4.41, 7.11, 12.12, 22.01, 65.08, 182.99, 478.65, 3425.04]		Urine	
8687	u-bakt	e6/l	12886	0	[0.99, 1.98, 3.85, 6.56, 13.19, 31.1, 95.22, 562.86, 5560.98]		Urine	
8688	u-bakt	estimate	14084	99.66			Urine	
8689	u-bakt	u/field	11	0			Urine	
8690	u-bakt		377251	99.78	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Urine	
8691	u-bakt-vi		14923	100	[10000, 10000, 10000, 10000, 1e+05, 1e+05, 1e+05, 1e+06, 1e+06]		Urine	Culture
8692	u-bakt.	/sunf	514	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Urine	
8693	u-bakt.	/sunfält	40	0			Urine	
8694	u-bakt.		1617	100			Urine	
8695	u-baktalv		2258	99.42		U -Bakteeri, aluslasiviljely	Urine	
8696	u-baktb		210	4.29	[1.72, 5.76, 11.77, 19.42, 30.15, 66.2, 213.28, 2129.49, 11056.23]		Urine	
8697	u-baktbv	e6/l	3962	0	[0.82, 1.8, 3.97, 7.16, 16.23, 44.68, 171.24, 1315.3, 12976.36]		Urine	
8698	u-baktbv		93	100			Urine	
8699	u-bakteeri		1711	100			Urine	
8700	u-bakteerit	e6/l	1692	0	[1, 3.34, 6.78, 15.13, 44.47, 159.79, 845.2, 5975.08, 24980.83]		Urine	
8701	u-bakteerit		16840	99.96			Urine	
8702	u-baktevi		18799	99.99		U -Bakteeri, erikoisviljely	Urine	
8703	u-baktjvi		390824	100		U -Bakteeri, jatkoviljely	Urine	
8704	u-baktjvi.		11570	100			Urine	
8705	u-baktla		4577	100			Urine	
8706	u-baktlm		1437	100			Urine	
8707	u-baktnim		111	100			Urine	
8708	u-bakts		1045	100			Urine	
8709	u-baktseu		39886	99.99			Urine	
8710	u-baktsjvi		539	100			Urine	
8711	u-bakttun		653	100			Urine	
8712	u-baktv		1154	100			Urine	
8713	u-baktvi	e6	45	0		U -Bakteeri, viljely	Urine	
8714	u-baktvi	e6/l	60	0		U -Bakteeri, viljely	Urine	
8715	u-baktvi	form	10	0		U -Bakteeri, viljely	Urine	
8716	u-baktvi		1324678	99.99	[106.83, 10000, 1e+05, 754545.45, 1e+06, 1e+07, 1e+08, 1e+08, 1e+08]	U -Bakteeri, viljely	Urine	
8717	u-baktvi/		562	100			Urine	
8718	u-baktvi/oma		629	100			Urine	
8719	u-baktvi2		283	100			Urine	
8720	u-baktvtk		1637	100			Urine	

