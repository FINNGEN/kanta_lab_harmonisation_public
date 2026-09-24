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
Here is group 2 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
68	-covid-19-koronavirustauti,antigeeni		394	100				
69	-covid-19-koronavirustauti,nho(kval)		1824	100				
70	-covid-19-koronavirustauti,nho-pikatesti(kval)		882	100				
71	-covid-19-koronavirustauti,nukleiinihappo(kval)		4805	100				
72	-cv19nho-covid-19koronavirustauti,nukleiinihappo(kval)		389	100				
73	-influenssaa,b,rs-virusjacovid-19-koronavirustauti,nukl.ihaponoso.		304	100				
74	-influenssaa,b,rs-virusjacovid-19-koronavirustauti,nukleiinihaponosoitus		2569	100				
75	-influenssaa,b,rs-virusjacv19,nukleiinihappo(kval)		289	100				
76	-influenssaa,b,rsvjacovid-19nukleiinihappo(kval)		5134	100				
77	-influenssaa,bjarsv-virus,nukleiinihappo		186	100				
78	-influenssaa-rna-osoitus		371	100				
79	-influenssaa-virus(a/h-2009),variantti,nho(kval)		926	100				
80	-influenssaa-virus(a/h3),variantti,nho(kval)		926	100				
81	-influenssaa-virus,nukeliinihapon(kval)		573	100				
82	-influenssaa-virus,nukl.happo(kval)		445	100				
83	-influenssaa-virus,nukleiinihappo(kval)		624	100				
84	-influenssaa/b,rsvjacovid-19-koronav,poc-nukl		1895	100				
85	-influenssaa/b,rsvjacovid-19-koronavirus,poc-nukl		598	100				
86	-influenssaa/b,rsvjacovid-19-koronavirus,poc-nukleiinihaponosoitus(kval)		276	100				
87	-influenssaah1nho(kval)		926	100				
88	-influenssaavirus,nukleiinihappo(kval)		3105	100				
89	-influenssab-virus,nukeliinihapon(kval)		573	100				
90	-influenssab-virus,nukleiinihappo(kval)		7125	100				
91	-influenssabvirus,nukleiinihappo(kval)		2729	100				
92	-parainfluenssa1-virus,nukleiinihappo		691	100				
93	-parainfluenssa1virus,nukleiinihappo(kval)		231	100				
94	-parainfluenssa2virus,nukleiinihappo(kval)		231	100				
95	-parainfluenssa3virus,nukleiinihappo(kval)		231	100				
96	-parainfluenssa4virus,nukleiinihappo(kval)		231	100				
97	-parainfluenssavirus4,nukleiinihappo(kval)		691	100				
98	-parinfluenssa2-virus,nukleiinihappo		691	100				
99	-parinfluenssa3-virus,nukleiinihappo		690	100				
100	covid-19-koronavirustauti,nhovtm10,vieritutkimus		271	100				
101	covid-19-koronavirustauti,nuk		268	100				
102	covid-19-koronavirustauti,nukleiinihappo		1940	100				
103	covid-19-koronavirustauti,nukleiinihappo(kval)		1271	100				
104	covid-19-koronavirustauti,nukleiinihappo,osatutkimus		938	100				
105	covid-19-koronavirustauti,poistettukäytöstä1.11.2023		293	100				
106	covid-19koronavirus,2019-ncov,pcr-tutkimus		5798	100				
107	influenssaa,b,rsv,sars-cov-2,		1345	100				
108	influenssaa,b,rsv,sars-cov-2,(kval),hoitoyks.vieritesti		529	100				
109	influenssaa,b,rsv,sars-cov-2,(kval)hoitoyks.vieritesti		296	100				
110	influenssaa,b,rsvjacovid-19nukleiinihappo(kval)		274	100				
111	influenssaa-virus,nukleiinih		435	100				
112	influenssaa-virus,nukleiinihappo(kval)		4276	100				
113	influenssaajab,cv19jarsvantigeeni(kval)		178	100				
114	influenssaajabjarsvjacovid-19nukleiinihappo(kval)		217	100				
115	influenssaavirus,nukleiinih		1347	100				
116	influenssaavirus,nukleiinihappo		292	100				
117	influenssaavirus,nukleiinihappo(kval)		1196	100				
118	influenssab-virus,nukleiinih		281	100				
119	influenssab-virus,nukleiinihappo(kval)		2575	100				
120	influenssabvirus,nukeliinihappo(kval)		537	100				
121	influenssabvirus,nukleiinih		1341	100				
122	influenssabvirus,nukleiinihappo		292	100				
123	li-varicella-zostervirus,nukleiinihappo(kval)		122	100			Cerebrospinal fluid	
124	parainfluenssavirus,nukleiini		544	100				
125	parainfluenssavirus,nukleiinihappo(kval)		209	100				
126	s-covid-19-koronavirustauti,iga-vasta-aineet		2502	100			Serum	
127	s-covid-19-koronavirustauti,igg-vasta-aineet		2516	100			Serum	
128	sars-cov-2,influenssaa,bjarsv,nukleiinihappo(kval)		732	100				
129	sars-cov-2influenssaa,bjarsvnukleiinihappo(kval)		508	100				

