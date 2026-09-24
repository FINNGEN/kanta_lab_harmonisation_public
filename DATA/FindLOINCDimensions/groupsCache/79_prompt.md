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
Here is group 79 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
6250	cu-alb-mi	ug/min	7258	0	[2, 3.03, 4.27, 6.2, 9.73, 17, 34.68, 78.84, 221.36]	cU-Albumiini, mikroalbuminuria	Collected urine	Micro
6251	cu-alb-mi		1830	100	[2, 3.76, 5.36, 7.63, 12.69, 25, 48.21, 105.09, 287.3]	cU-Albumiini, mikroalbuminuria	Collected urine	Micro
6252	nu-alb-mi	mg/12h	12	0		nU-Albumiini, mikroalbuminuria	Night (morning) urine	Micro
6253	nu-alb-mi	ug/min	155	0	[5, 8.88, 19.76, 34.34, 70.38, 107.14, 173.45, 320, 537.6]	nU-Albumiini, mikroalbuminuria	Night (morning) urine	Micro
6254	nu-alb-mi		157	68.15		nU-Albumiini, mikroalbuminuria	Night (morning) urine	Micro
6255	nu-albkre	mg/mmol	438	0	[0.3, 0.49, 0.65, 0.9, 1.28, 2, 4.09, 8.45, 23.14]		Night (morning) urine	
6256	nu-albkre		2191	62.12	[0.39, 0.5, 0.69, 0.87, 1.2, 1.82, 2.88, 6.31, 19.04]		Night (morning) urine	
6257	nu-albkrea	mg/mmol	20929	0	[0.33, 0.49, 0.66, 0.9, 1.32, 2.09, 3.79, 8.38, 27.64]		Night (morning) urine	
6258	nu-albkrea		26197	100	[0.21, 0.36, 0.51, 0.7, 1.05, 1.62, 2.84, 6.09, 18.42]		Night (morning) urine	
6259	u-a1mikre		113	12.39	[1, 2.43, 3.5, 6.91, 9.03, 11.18, 14.78, 18.06, 35.1]		Urine	
6260	u-alb-0		992	100			Urine	
6261	u-alb-lb	mg/l	70	0			Urine	
6262	u-alb-lb		50	98			Urine	
6263	u-alb-mi	mg/l	7488	0	[3.01, 4.02, 5.51, 7.59, 11.17, 18.74, 35.95, 87.24, 325.25]		Urine	Micro
6264	u-alb-mi		3031	100	[1.94, 3, 4.21, 6.03, 8.61, 11.71, 20.86, 50.08, 291.2]		Urine	Micro
6265	u-alb-o	estimate	161670	2.95	[0, 0, 0, 0, 0, 0, 0, 0, 0]	U -Albumiini (kval)	Urine	Qualitative test (also semi-quantitative)
6266	u-alb-o	form	287	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]	U -Albumiini (kval)	Urine	Qualitative test (also semi-quantitative)
6267	u-alb-o		312867	100	[0, 0, 0, 0, 0, 0, 0, 0, 0]	U -Albumiini (kval)	Urine	Qualitative test (also semi-quantitative)
6268	u-alb/kre	g/mol	142	0	[1.78, 3.02, 3.92, 5.37, 8.28, 16.58, 32.75, 51.54, 140.31]		Urine	
6269	u-alb/kre	mg/mmol	2591	0	[0.3, 0.42, 0.6, 0.84, 1.25, 2.07, 3.99, 8.87, 30.32]		Urine	
6270	u-alb/kre		2491	96.87			Urine	
6271	u-alb/kre,u-alb		247	39.27	[6.13, 7.52, 9.27, 12.32, 15.29, 19.26, 37.25, 66.2, 187.73]		Urine	
6272	u-alb/kre,u-alb/krea	mg/mmol	148	0	[0.59, 0.74, 0.99, 1.41, 1.89, 3.03, 5.25, 10.21, 22.45]		Urine	
6273	u-alb/kre,u-alb/krea		99	96.97			Urine	
6274	u-alb/kre,u-krea		247	0.81	[3.67, 4.76, 5.83, 6.76, 7.67, 8.61, 9.82, 10.75, 12.92]		Urine	
6275	u-alb/krea	g/mol	49	0			Urine	
6276	u-alb/krea	mg/mmol	879	0	[0.29, 0.4, 0.52, 0.73, 1.06, 1.82, 2.87, 5.79, 14.42]		Urine	
6277	u-alb/krea		812	100			Urine	
6278	u-albkre	g/mol	10	0		U -Albumiinin ja kreatiniinin suhde	Urine	
6279	u-albkre	mg/mmol	294883	0.26	[0.31, 0.5, 0.7, 1.03, 1.68, 3, 6.29, 16.55, 61.66]	U -Albumiinin ja kreatiniinin suhde	Urine	
6280	u-albkre		200553	100	[0.3, 0.4, 0.59, 0.81, 1.18, 1.92, 3.44, 7.04, 20.74]	U -Albumiinin ja kreatiniinin suhde	Urine	
6281	u-albkrea	mg/mmol	10590	0	[0.3, 0.44, 0.59, 0.73, 0.97, 1.31, 1.85, 3.03, 9.45]		Urine	
6282	u-albkrea	mg/mmol/l	81	0			Urine	
6283	u-albkrea		15486	73.32	[0.4, 0.65, 1.06, 1.98, 3.39, 4.96, 7.85, 14.4, 37.26]		Urine	
6284	u-alvhu4a		760	100			Urine	
6285	u-alvhu5b		912	100			Urine	
6286	u-alvhu6a		1273	100			Urine	
6287	u-cakre		106	48.11			Urine	
6288	u-happamuus		204	0.49	[6.5, 6.5, 7, 7, 7, 7, 7.5, 7.5, 8]		Urine	
6289	u-prokre	g/mol	973	0.41	[5.03, 6.97, 8.99, 11.1, 14.55, 19.47, 27.35, 52.28, 161.87]	U -Proteiinin ja kreatiniinin suhde	Urine	
6290	u-prokre	mg/mmol	1813	0	[9.66, 12.56, 16.16, 21.33, 30.42, 49.33, 102.26, 292.89, 1027.72]	U -Proteiinin ja kreatiniinin suhde	Urine	
6291	u-prokre		646	99.85		U -Proteiinin ja kreatiniinin suhde	Urine	
6292	u-protkre	mg/mmol	121	0			Urine	
6293	u-protkre		9	100			Urine	
6294	u-sakka,bakt		330	99.39			Urine	
6295	u-sakka,epit		1251	71.3	[0, 0, 0, 0, 0, 0, 0.33, 1, 2]		Urine	
6296	u-sakka,eryt	u/field	1247	0	[0, 1, 1, 1, 1, 2, 2.67, 4, 7]		Urine	
6297	u-sakka,eryt		121	100	[0, 0, 0, 0, 0.62, 1, 2, 3.04, 7.71]		Urine	
6298	u-sakka,leuk	u/field	1087	0	[0, 0, 0, 0, 0, 1, 1, 2.25, 5]		Urine	
6299	u-sakka,leuk		261	100	[0, 0, 0, 0, 0, 0.98, 2, 4.88, 11.66]		Urine	
6300	u-sakka,lier		367	5.72	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Urine	
6301	u-sakka,makrof		367	4.63	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Urine	
6302	u-sakka,muuta		456	25.88	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Urine	
6303	u-solut,muut		136	88.24			Urine	

