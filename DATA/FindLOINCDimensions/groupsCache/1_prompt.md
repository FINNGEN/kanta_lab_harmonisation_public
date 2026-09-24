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
Here is group 1 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1	-chl.trach.janeisser.gonorrh,nukl.hapon(kval)		688	100				
2	-chlamydiatrachomatis,nukleiinihaponosoittaminen		140	100				
3	-chlamydiatrachomatis,nukleiinihaponosoitus		1033	100				
4	-chlamydiatrachomatis,nukleiinihappo(kval)		3008	100				
5	-chlamydiatrachomatis,nukleiinihappokotona		4816	100				
6	-chlamydiatrachomatis,osoittaminennukleiinihap		1010	100				
7	-chlamydiatrachomatisjaneisseriagonorrhoea,		581	100				
8	-chlamydiatrachomatisjaneisseriagonorrhoeae,n		578	100				
9	-chlamydiatrachomatisjaneisseriagonorrhoeae,nukleiinihappo(kval)		2312	100				
10	-chlamydiatrachomatisjaneisseriagonorrhoeae,nukleiinihappo(kval),klamydia		107	100				
11	-chlamydiatrachomatisjaneisseriagonorrhoeae,nukleiinihappokotona(kval)		6639	100				
12	-neisseriagonnorrhoeae,nukleiinihappo(kval)		867	100				
13	-neisseriagonorrhoea,nukleiinihaponosoittaminen		135	100				
14	-neisseriagonorrhoeae(gonokokki),nukleiiihapp		514	100				
15	-neisseriagonorrhoeae,nukleiinihaponosoittaminen		646	100				
16	-neisseriagonorrhoeae,nukleiinihappo(kval)		2116	100				
17	-neisseriagonorrhoeae,nukleiinihappo/kauklahti		1007	100				
18	-neisseriagonorrhoeae,nukleiinihappokotona(kval)		4817	100				
19	..-chlamydiatrachomatis,nukl.haponos.(kval)		403	100				
20	..-gonokokki/neisserea,nukl.haponos.(kval),pcr		403	100				
21	c.trachomatisjan.gonnorreae,nukeliinihappomuistanäytteistä		288	100				
22	c.trachomatisjan.gonorrhoeae,nukleiinihappovirtsasta		184	100				
23	chl.trachom.jan.gonorrhoeae,nukleiinihappo(		235	100				
24	chl.trachom.jan.gonorrhoeae,nukleiinihappo(kval)		242	100				
25	chl.trachomatisjan.gonorrhoenukleiinihappo(kval		164	100				
26	chlamydiatrachom.janeissgono(kval)		1008	100				
27	chlamydiatrachom.nho		312	100				
28	chlamydiatrachomatis,nhosoitus		531	100				
29	chlamydiatrachomatis,nukeliinihappo(kval)		288	100				
30	chlamydiatrachomatis,nukleiinihaponos.,osatutk.1738		122	100				
31	chlamydiatrachomatis,nukleiinihaponos.,virtsasta,osatutk.4816		104	100				
32	chlamydiatrachomatis,nukleiinihaponosoittaminen		143	100				
33	chlamydiatrachomatis,nukleiinihappo(kval)		853	100				
34	chlamydiatrachomatis,nukleiinihappovirtsasta		218	100				
35	chlamydiatrachomatisjan.gonorrhoeae,nukleiinihaponos.,virtsasta		104	100				
36	chlamydiatrachomatisjaneisseriagonorrhoeae,nho,limakalvoilta␤		531	100				
37	chlamydiatrachomatisjaneisseriagonorrhoeae,nho,virtsasta␤		845	100				
38	chlamydiatrachomatisjaneisseriagonorrhoeae,nukl.happo(kval)limakalvolta		118	100				
39	chlamydiatrachomatisjaneisseriagonorrhoeae,nukleiinihappo(kval)		2462	100				
40	chlamydiatrachomatisjaneisseriagonorrhoeae,nukleiinihappo(kval),virtsasta		115	100				
41	klamydia,tippuri.chlamydiatrachomatisjaneisseriagonorrhoeae,nukleiinihappo(kval)		675	100				
42	neisseriagononorrhoeae,nukleiinihappo(kval)		288	100				
43	neisseriagonorr.nho		312	100				
44	neisseriagonorrhoea,nukleiinihaponos.,osatutk.1738		122	100				
45	neisseriagonorrhoea,nukleiinihaponos.,virtsasta,osatutk.4816		104	100				
46	neisseriagonorrhoeae,nho		525	100				
47	neisseriagonorrhoeae,nukleiinihappo(kval)		762	100				
48	neisseriagonorrhoeaevirtsasta		240	100				
49	u-chl.trach.janeisser.gonorrh.nukl.happo(kval)		139	100			Urine	
50	u-chlam.trachomatisjaneisseriagonorr,nukleiinihappo(kval)		867	100			Urine	
51	u-chlamydiatrachomatis+neisseriagonorrhoeae,nu		219	100			Urine	
52	u-chlamydiatrachomatis,nho(kval)		845	100			Urine	
53	u-chlamydiatrachomatis,nukleiinihaponosoitus		119	100			Urine	
54	u-chlamydiatrachomatis,nukleiinihappo		1389	100			Urine	
55	u-chlamydiatrachomatis,nukleiinihappo(kval)		2812	100			Urine	
56	u-chlamydiatrachomatis,nukleiinihappokotona(kval)		1889	100			Urine	
57	u-chlamydiatrachomatis,virtsasta,osnukleiinihappo		868	100			Urine	
58	u-chlamydiatrachomatisjaneisseriagonorrhoeae,		564	100			Urine	
59	u-chlamydiatrachomatisjaneisseriagonorrhoeae,nukleiinihappo(kval)		1624	100			Urine	
60	u-chlamydiatrachomatisjaneisseriagonorrhoeaennukleiinihappo(kval),virtsa		119	100			Urine	
61	u-chlamydiatrachomatisjaneisseriagonorrhoeanukleiinihappo		137	100			Urine	
62	u-neisseriagonorrhoeae,nho(kval)		845	100			Urine	
63	u-neisseriagonorrhoeae,nukl.os.(kval)		116	100			Urine	
64	u-neisseriagonorrhoeae,nukleiinihaponosoitus		119	100			Urine	
65	u-neisseriagonorrhoeae,nukleiinihappo(kval)		5319	100			Urine	
66	u-neisseriagonorrhoeae,nukleiinihappokotona(kval)		1890	100			Urine	
67	␤␤␤␤␤chlamydiatrachomatis,nukleiinihappo(kval)		275	100				

