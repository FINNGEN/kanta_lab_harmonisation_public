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
Here is group 121 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
10066	-ctr-d		115	100				DNA test
10067	-fishhyb	form	48	100				
10068	-fishhyb		174	100				
10069	b-apoe-d		146	100		B -Apolipoproteiini E, DNA-tutkimus	Blood	DNA test
10070	b-aso2-qd		102	100			Blood	
10071	b-atrytyd	form	7	100		B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus	Blood	
10072	b-atrytyd		283	100		B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus	Blood	
10073	b-auria10		1807	100			Blood	
10074	b-bcr-qr	form	159	100		B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant)	Blood	
10075	b-bcr-qr		1562	100		B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant)	Blood	
10076	b-blapcr		138	100			Blood	
10077	b-bo3-d		963	100			Blood	DNA test
10078	b-brcay-d		519	100			Blood	DNA test
10079	b-brovcore		356	100			Blood	
10080	b-calr-d		421	100			Blood	DNA test
10081	b-cmlpcr		553	100			Blood	
10082	b-crco		3627	100			Blood	
10083	b-crcoti		1359	100			Blood	
10084	b-dm2alld	form	19	100		B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus	Blood	
10085	b-dm2alld		149	100		B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus	Blood	
10086	b-dpyd-d	form	211	100			Blood	DNA test
10087	b-dpyd-d		3111	100			Blood	DNA test
10088	b-dpydl-d		101	100			Blood	DNA test
10089	b-exkon-d		147	100			Blood	DNA test
10090	b-extri-d		136	100			Blood	DNA test
10091	b-farma-d		594	100			Blood	DNA test
10092	b-farml-d		190	100			Blood	DNA test
10093	b-fii-d	form	138	100		B -Protrombiinigeeni, DNA-tutkimus	Blood	DNA test
10094	b-fii-d		7712	100		B -Protrombiinigeeni, DNA-tutkimus	Blood	DNA test
10095	b-finngen		736	100			Blood	
10096	b-fishhem		130	100		B -Hematologinen fluoresenssi in situ hybridisaatio, veri	Blood	
10097	b-frax-d	form	5	100		B -Fragiili-X,-FMR1-geenin DNA-tutkimus	Blood	DNA test
10098	b-frax-d		347	100		B -Fragiili-X,-FMR1-geenin DNA-tutkimus	Blood	DNA test
10099	b-fuus-mr	form	26	100			Blood	
10100	b-fuus-mr		177	100			Blood	
10101	b-fv-d	form	139	100		B -Hyytymistekijä V geeni, DNA-tutkimus	Blood	DNA test
10102	b-fv-d		8156	100		B -Hyytymistekijä V geeni, DNA-tutkimus	Blood	DNA test
10103	b-fvfii-d	form	52	100			Blood	DNA test
10104	b-fvfii-d		765	100			Blood	DNA test
10105	b-hfe-d		730	100		B -Periytyvään hemokromatoosiin liittyvien HFE-geenin valtamutaatioiden tutkimus	Blood	DNA test
10106	b-hnpcy-d		175	100		B -Periytyvä ei-polypoottinen paksusuolisyöpä (HNPCC), MLH1-, MSH2- tai MSH6-geenin yksittäisen mutaation DNA-tutkimus	Blood	DNA test
10107	b-jak2-d	form	139	100		B -JAK2-geenin mutaatio, DNA-tutkimus	Blood	DNA test
10108	b-jak2-d		5494	100		B -JAK2-geenin mutaatio, DNA-tutkimus	Blood	DNA test
10109	b-kim-d		197	100			Blood	DNA test
10110	b-kim-fd		1367	100			Blood	
10111	b-kml-qr		1809	100			Blood	
10112	b-lakt-d	form	18	77.78		B -Laktoosi-intoleranssi, DNA-tutkimus	Blood	DNA test
10113	b-lakt-d		27791	100		B -Laktoosi-intoleranssi, DNA-tutkimus	Blood	DNA test
10114	b-ldlre-4	form	53	100			Blood	
10115	b-ldlre-4		135	100			Blood	
10116	b-ldlre-d		1121	100		B -LDL-reseptorigeenin mutaatio, DNA-tutkimus	Blood	DNA test
10117	b-ngs-d		277	100			Blood	DNA test
10118	b-nphs1-d		272	100		B -Kongenitaali nefroosi (CNF), kahden NPHS1-geenin valtamutaation DNA-tutkimus	Blood	DNA test
10119	b-pgx-d		2778	100			Blood	DNA test
10120	b-sekvy-d	form	59	100			Blood	DNA test
10121	b-sekvy-d		1268	100			Blood	DNA test
10122	b-tp53-d		211	100			Blood	DNA test
10123	b-tpmt-d	form	30	100			Blood	DNA test
10124	b-tpmt-d		615	100			Blood	DNA test
10125	b-varfa-d		643	100		B -Varfariinin yksilölliseen annostukseen liittyvät VKORC1- ja CYP2C9-geenivariaatiot, DNA-tutkimus verestä	Blood	DNA test
10126	b-ykrom-d	form	7	100		B -Y-kromosomin poikkeavuuksia	Blood	DNA test
10127	b-ykrom-d		142	100		B -Y-kromosomin poikkeavuuksia	Blood	DNA test
10128	bl-bal		919	100		Bl-Bronkoalveolaarinen lavaationäyte sairaalakohtainen ryhmätutkimus, jonka sisältö vaihtelee	Bronchoalveolar lavage	
10129	bl-bal-1		3636	100		Bl-Bronkoalveolaarinen huuhtelunäyte, solututkimus	Bronchoalveolar lavage	
10130	bl-balfc		397	100			Bronchoalveolar lavage	
10131	bm-aso-qd		224	100			Bone marrow	
10132	bm-aso2-qd	form	6	100			Bone marrow	
10133	bm-aso2-qd		511	100			Bone marrow	
10134	bm-aspir		1994	98.65			Bone marrow	
10135	bm-bcr-qr		152	100		Bm-BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant)	Bone marrow	
10136	bm-blapcr		753	100			Bone marrow	
10137	bm-bpvalm		145	100			Bone marrow	
10138	bm-fish	form	48	100			Bone marrow	
10139	bm-fish		943	100			Bone marrow	
10140	bm-fish-mm		127	100			Bone marrow	
10141	bm-fish2	form	29	100			Bone marrow	
10142	bm-fish2		81	100			Bone marrow	
10143	bm-fishhem	form	7	100		Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin	Bone marrow	
10144	bm-fishhem		414	100		Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin	Bone marrow	
10145	bm-fishmm	form	28	100			Bone marrow	
10146	bm-fishmm		147	100			Bone marrow	
10147	bm-fishvar		141	100			Bone marrow	
10148	bm-flt3-d	form	9	100			Bone marrow	DNA test
10149	bm-flt3-d		138	100			Bone marrow	DNA test
10150	bm-fuus-mr	form	14	100			Bone marrow	
10151	bm-fuus-mr		268	100			Bone marrow	
10152	bm-fuus-qr	form	21	100			Bone marrow	
10153	bm-fuus-qr		81	100			Bone marrow	
10154	bm-mgg		314	100			Bone marrow	
10155	bm-mggfe	form	660	100		Bm-Luuydintutkimus, MGG- ja rautavärjäys	Bone marrow	
10156	bm-mggfe		11527	100		Bm-Luuydintutkimus, MGG- ja rautavärjäys	Bone marrow	
10157	bm-mm-ift		651	100			Bone marrow	
10158	bm-mmpcr		128	100			Bone marrow	
10159	bm-morflkl		278	100			Bone marrow	
10160	bm-mrd-all		416	100			Bone marrow	
10161	bm-mrd-vs		666	100			Bone marrow	
10162	bm-mrdmut		198	100			Bone marrow	
10163	bm-npm1-qd	form	23	100			Bone marrow	
10164	bm-npm1-qd		182	100			Bone marrow	

