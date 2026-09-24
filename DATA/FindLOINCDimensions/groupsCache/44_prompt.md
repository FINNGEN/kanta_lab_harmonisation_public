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
Here is group 44 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
2735	-bil	umol/l	433	0	[8.08, 11.42, 17.8, 24.81, 35.56, 52.32, 88.15, 166.34, 422.22]	-Bilirubiini		
2736	-bil		85	95.29		-Bilirubiini		
2737	b-bio		4183	100			Blood	
2738	b-hg	nmol/l	64	0		B -Elohopea	Blood	
2739	b-hg		51	94.12		B -Elohopea	Blood	
2740	cb-bil	umol/l	331	0	[11.1, 19.39, 22.31, 26.36, 32.8, 45.69, 98.54, 156.29, 216.28]	cB-Bilirubiini	Capillary blood	
2741	cb-bil		4244	99.98		cB-Bilirubiini	Capillary blood	
2742	du-mg	mmol	580	0.17	[2.07, 2.62, 3.11, 3.51, 3.97, 4.42, 4.91, 5.69, 6.98]	dU-Magnesium	24-hour urine	
2743	du-mg		154	70.78		dU-Magnesium	24-hour urine	
2744	du-pi	mmol	591	0.17	[14.15, 19.7, 22.95, 26.88, 29.9, 33.43, 38, 43.23, 51.47]	dU-Fosfaatti, epäorgaaninen	24-hour urine	
2745	du-pi		118	75.42		dU-Fosfaatti, epäorgaaninen	24-hour urine	
2746	fl-koh		285	100			Vaginal discharge	
2747	fp-bil	umol/l	111	0	[4.98, 6.34, 7.02, 8.69, 9.41, 10.29, 12.14, 15.18, 27.61]		Fasting plasma	
2748	fp-kol	mmol	7	0		fP-Kolesteroli	Fasting plasma	
2749	fp-kol	mmol/	7	0		fP-Kolesteroli	Fasting plasma	
2750	fp-kol	mmol/l	1407523	0	[3.2, 3.63, 3.97, 4.28, 4.58, 4.87, 5.21, 5.6, 6.16]	fP-Kolesteroli	Fasting plasma	
2751	fp-kol		17406	100	[4.01, 4.31, 4.6, 4.91, 5.19, 5.43, 5.75, 6.21, 6.8]	fP-Kolesteroli	Fasting plasma	
2752	fp-vip	pmol/l	391	1.53	[6.42, 8.54, 9.99, 11.21, 13, 14.7, 16.8, 19.84, 27.89]	fP-Vasoaktiivinen intestinaalinen peptidi	Fasting plasma	
2753	fp-vip		61	81.97		fP-Vasoaktiivinen intestinaalinen peptidi	Fasting plasma	
2754	fs-kol	mmol/	7	0		fS-Kolesteroli	Fasting serum	
2755	fs-kol	mmol/l	259011	0	[3.71, 4.15, 4.46, 4.76, 5.03, 5.31, 5.59, 5.95, 6.44]	fS-Kolesteroli	Fasting serum	
2756	fs-kol		481	100	[3.95, 4.3, 4.66, 4.92, 5.17, 5.39, 5.64, 6.03, 6.57]	fS-Kolesteroli	Fasting serum	
2757	li-bio		161	100			Cerebrospinal fluid	
2758	mmse		524	94.66				
2759	p-bil	umol/l	1420468	0.09	[5, 6, 7, 8.01, 9.15, 10.92, 12.96, 16.55, 24.99]	P -Bilirubiini	Plasma	
2760	p-bil		51285	100	[4.75, 5.95, 6.93, 7.97, 9.15, 10.81, 13.1, 17.26, 26.41]	P -Bilirubiini	Plasma	
2761	p-bnp	ng/l	92283	0	[19.9, 36.26, 58.02, 88.41, 132.21, 195.75, 292.04, 465.57, 902.19]	P -Natriureettinen peptidi, B-tyypin (32-)	Plasma	
2762	p-bnp	ng/ml	14	0		P -Natriureettinen peptidi, B-tyypin (32-)	Plasma	
2763	p-bnp		5638	100	[41.88, 71.98, 108.12, 145.12, 193.35, 257.89, 351.05, 510.91, 912.06]	P -Natriureettinen peptidi, B-tyypin (32-)	Plasma	
2764	p-fsh	u/l	10309	0	[3.43, 4.83, 5.94, 7.2, 9.39, 15.3, 30.23, 51.8, 73.17]	P -Follikkelia stimuloiva hormoni	Plasma	
2765	p-fsh		155	100	[3.32, 4.57, 5.74, 6.86, 8.5, 12.89, 23.84, 44.5, 70.18]	P -Follikkelia stimuloiva hormoni	Plasma	
2766	p-fsl	s	1808	0	[23.6, 25, 25.97, 26.26, 27.2, 28.08, 29.24, 31.3, 34.37]		Plasma	
2767	p-fsl		86	69.77			Plasma	
2768	p-kol	mmol/l	298985	0	[3.03, 3.42, 3.74, 4.03, 4.33, 4.64, 4.97, 5.37, 5.92]	P -Kolesteroli	Plasma	
2769	p-kol		2034	100	[3, 3.37, 3.67, 3.97, 4.25, 4.57, 4.92, 5.32, 5.88]	P -Kolesteroli	Plasma	
2770	p-mg	mmol/l	259826	0.04	[0.64, 0.7, 0.74, 0.77, 0.8, 0.83, 0.86, 0.89, 0.95]	P -Magnesium	Plasma	
2771	p-mg		2225	100	[0.64, 0.7, 0.74, 0.78, 0.81, 0.84, 0.86, 0.9, 0.95]	P -Magnesium	Plasma	
2772	p-se	umol/l	1087	0.09	[0.86, 1.03, 1.1, 1.19, 1.27, 1.34, 1.41, 1.5, 1.62]	P -Seleeni	Plasma	
2773	p-se		55	43.64	[1.17, 1.27, 1.34, 1.4, 1.46, 1.54, 1.63, 1.73, 1.94]	P -Seleeni	Plasma	
2774	p-tsh	miu/l	32584	0	[0.71, 1.13, 1.46, 1.75, 2.07, 2.43, 2.87, 3.48, 4.57]	P -Tyreotropiini	Plasma	
2775	p-tsh	mlu/l	4705	0	[0.58, 1.02, 1.38, 1.7, 2.07, 2.5, 3.01, 3.68, 4.95]	P -Tyreotropiini	Plasma	
2776	p-tsh	mu/l	1660849	0.06	[0.53, 0.92, 1.22, 1.5, 1.78, 2.11, 2.53, 3.11, 4.2]	P -Tyreotropiini	Plasma	
2777	p-tsh		53377	100	[0.3, 0.81, 1.02, 1.41, 1.64, 1.91, 2.3, 2.66, 3.57]	P -Tyreotropiini	Plasma	
2778	pf-kol	mmol/l	614	0	[0.64, 0.93, 1.1, 1.3, 1.51, 1.75, 2.03, 2.36, 2.85]	Pf-Kolesteroli	Pleural fluid	
2779	pf-kol		361	98.06		Pf-Kolesteroli	Pleural fluid	
2780	s-bil	umol/l	15554	0	[5.56, 6.89, 7.91, 8.95, 10.06, 11.55, 13.42, 16.35, 22.65]	S -Bilirubiini	Serum	
2781	s-bil		183	82.51	[5.99, 7.33, 8.34, 9.33, 10.81, 12.14, 14.24, 16.54, 22.13]	S -Bilirubiini	Serum	
2782	s-bio		11283	100			Serum	
2783	s-biol		508	100			Serum	
2784	s-fsh	iu/l	21045	0	[3.26, 4.67, 5.97, 7.58, 10.27, 17.4, 33.37, 51.85, 72.5]	S -Follikkelia stimuloiva hormoni	Serum	
2785	s-fsh	u/l	14312	0.62	[3.48, 4.97, 6.16, 7.42, 9.34, 13.61, 26.1, 47.59, 73.43]	S -Follikkelia stimuloiva hormoni	Serum	
2786	s-fsh		1106	100	[3.11, 4.58, 5.88, 7.13, 8.92, 13.11, 23.72, 44.2, 70.34]	S -Follikkelia stimuloiva hormoni	Serum	
2787	s-kol	mg/ml	9	0		S -Kolesteroli	Serum	
2788	s-kol	mmol/l	35285	0	[3.59, 4.01, 4.33, 4.59, 4.85, 5.11, 5.39, 5.71, 6.19]	S -Kolesteroli	Serum	
2789	s-kol		396	89.9		S -Kolesteroli	Serum	
2790	s-mg	mmol/l	5982	0	[0.77, 0.81, 0.83, 0.85, 0.87, 0.88, 0.9, 0.92, 0.95]	S -Magnesium	Serum	
2791	s-mg		23	69.57	[0.75, 0.78, 0.8, 0.82, 0.83, 0.85, 0.87, 0.89, 0.91]	S -Magnesium	Serum	
2792	s-nse	ug/l	10085	0.04	[9.38, 10.96, 12, 13.1, 14.43, 16.18, 18.88, 24.33, 45.7]	S -Neuronispesifinen enolaasi	Serum	
2793	s-nse		210	45.24	[8.56, 10, 10.8, 12.01, 14.24, 17, 20.25, 24.5, 29.28]	S -Neuronispesifinen enolaasi	Serum	
2794	s-tsh	miu/l	117078	0	[0.56, 0.91, 1.16, 1.39, 1.62, 1.89, 2.23, 2.72, 3.61]	S -Tyreotropiini	Serum	
2795	s-tsh	mlu/l	113	0	[0.33, 0.69, 1.02, 1.22, 1.42, 1.62, 2, 2.33, 2.93]	S -Tyreotropiini	Serum	
2796	s-tsh	mu/l	253056	0	[0.62, 0.91, 1.15, 1.36, 1.59, 1.85, 2.18, 2.64, 3.49]	S -Tyreotropiini	Serum	
2797	s-tsh	u/l	142	0	[0.52, 0.94, 1.22, 1.48, 1.73, 1.98, 2.18, 2.57, 4.01]	S -Tyreotropiini	Serum	
2798	s-tsh		4491	100	[0.62, 0.91, 1.18, 1.45, 1.66, 1.95, 2.23, 2.72, 3.49]	S -Tyreotropiini	Serum	
2799	se-bil	umol/l	526	1.33	[9.24, 12.96, 16.08, 20.31, 26.93, 38.21, 60.68, 119.92, 333.14]		Secretion	
2800	se-bil		102	99.02			Secretion	
2801	u-al	umol/l	81	0	[0.1, 0.1, 0.2, 0.2, 0.22, 0.3, 0.4, 0.7, 1.7]	U -Alumiini	Urine	
2802	u-al		87	97.7		U -Alumiini	Urine	
2803	u-amp		158	100			Urine	
2804	u-as-i	nmol/l	16	0		U -Arseeni, epäorgaaninen	Urine	
2805	u-as-i	ug/l	20	0		U -Arseeni, epäorgaaninen	Urine	
2806	u-as-i		107	100		U -Arseeni, epäorgaaninen	Urine	
2807	u-bil		441	100			Urine	
2808	u-bio		2387	100			Urine	
2809	u-bup		145	100			Urine	
2810	u-bzd		143	100			Urine	
2811	u-cl	mmol/l	200	1.5	[30.37, 49.43, 62.98, 72.55, 86.28, 96.56, 114.04, 135.66, 174.02]	U -Kloridi	Urine	Clearance
2812	u-cl		33	72.73		U -Kloridi	Urine	Clearance
2813	u-dala	umol/l	111	0.9	[5, 8, 10.96, 13.72, 17, 20.55, 23.93, 29.9, 40.27]	U -Delta-aminolevulinaatti	Urine	
2814	u-ds4a		461	100			Urine	
2815	u-ds5		133	100			Urine	
2816	u-ds5b		1156	100			Urine	
2817	u-ds6		386	100			Urine	
2818	u-ds6a		1325	100			Urine	
2819	u-ery		3788	99.71			Urine	
2820	u-fyl		145	100			Urine	
2821	u-hg	nmol/l	108	0		U -Elohopea	Urine	
2822	u-hg		25	100		U -Elohopea	Urine	
2823	u-i	ug/l	309	0	[44.03, 61.73, 78.06, 96.82, 115.33, 136.79, 163.87, 204.07, 318.14]	U -Jodidi	Urine	
2824	u-i		18	88.89		U -Jodidi	Urine	
2825	u-inf		51657	100			Urine	
2826	u-intp	nmol/mmol	2098	0	[16.36, 22.55, 28.43, 35.25, 42.57, 53.83, 68.67, 92.78, 154.47]	U -Kollageeni I:n aminoterminaalinen telopeptidi	Urine	
2827	u-intp	nmol/mmolkr	14	0		U -Kollageeni I:n aminoterminaalinen telopeptidi	Urine	
2828	u-intp	ratio	47	0		U -Kollageeni I:n aminoterminaalinen telopeptidi	Urine	
2829	u-intp		1030	94.47		U -Kollageeni I:n aminoterminaalinen telopeptidi	Urine	
2830	u-kivi	form	60	100		U -Kivianalyysi	Urine	
2831	u-kivi		1820	100		U -Kivianalyysi	Urine	
2832	u-mg	mmol/l	123	0.81	[0.84, 1.34, 1.62, 1.98, 2.27, 2.78, 3.64, 4.45, 6.45]	U -Magnesium	Urine	
2833	u-mg		26	38.46		U -Magnesium	Urine	
2834	u-mtd		144	100			Urine	
2835	u-ni	form	57	0		U -Nikkeli	Urine	
2836	u-ni	ug/l	65	0		U -Nikkeli	Urine	
2837	u-ni	umol/l	754	0	[0.01, 0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.04, 0.06]	U -Nikkeli	Urine	
2838	u-ni		323	90.71		U -Nikkeli	Urine	
2839	u-pbg	umol/l	248	1.61	[1, 2, 2, 3, 3.9, 4.42, 5, 6.04, 8.79]	U -Porfobilinogeeni	Urine	
2840	u-pbg	umol/mmol	6	0		U -Porfobilinogeeni	Urine	
2841	u-pbg		33	51.52		U -Porfobilinogeeni	Urine	
2842	u-pgb		144	100			Urine	
2843	u-ph.		24516	1.33	[5, 5.5, 5.5, 5.87, 6, 6.26, 6.5, 6.96, 7.02]		Urine	
2844	u-phv		737	0.27	[5, 5.5, 5.5, 5.66, 6, 6, 6.5, 7, 7]		Urine	
2845	u-pi	mmol/l	772	0.13	[4.87, 7.61, 10.55, 13.2, 16.31, 20.1, 24.74, 31.17, 40.13]	U -Fosfaatti, epäorgaaninen	Urine	
2846	u-pi		84	54.76		U -Fosfaatti, epäorgaaninen	Urine	
2847	u-pyr	form	7	0		U -Pyrenoli (1)	Urine	
2848	u-pyr	ug/l	6	0		U -Pyrenoli (1)	Urine	
2849	u-pyr		88	100		U -Pyrenoli (1)	Urine	
2850	u-sed		2162	99.95			Urine	
2851	u-sg	kg/l	3827	0	[1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02]		Urine	
2852	u-sg		75	100	[1, 1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.03]		Urine	
2853	u-thc		157	100			Urine	
2854	u-tml		145	100			Urine	
2855	u-ubg		441	100			Urine	
2856	us-tsh	mu/l	415	0.72	[3.59, 4.74, 5.45, 6.2, 7.04, 7.92, 9.44, 11.82, 16.59]	uS-Tyreotropiini	Umbilical (blood) serum	
2857	us-tsh		75	33.33		uS-Tyreotropiini	Umbilical (blood) serum	
2858	vp-dop		154	100		Valtimopaine, dopplermittaus		

