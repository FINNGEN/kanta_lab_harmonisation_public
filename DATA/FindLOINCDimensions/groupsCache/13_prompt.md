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
Here is group 13 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
845	-albumiini,seerumi,elektroforeesifraktio(g/l)	g/l	750	0	[31.43, 34.23, 35.65, 36.93, 37.92, 39.06, 40.53, 42.1, 44.38]			
846	-albumiini,seerumi,elektroforeesifraktio(g/l)		6	16.67				
847	-alfa-1-globuliini,seerumi,elektroforeesifraktio	g/l	752	0	[1.56, 1.72, 2.01, 2.39, 2.64, 2.85, 3.08, 3.34, 3.81]			
848	-alfa-2-globuliini,seerumi,elektroforeesifraktio	g/l	753	0	[5.3, 5.81, 6.14, 6.52, 6.88, 7.27, 7.69, 8.34, 9.33]			
849	-beta-1-globuliini,seerumi,elektroforeesifraktio	g/l	754	0	[3.23, 3.49, 3.69, 3.8, 3.98, 4.1, 4.29, 4.48, 4.8]			
850	-beta-2-globuliini,seerumi,elektroforeesifraktio	g/l	754	0	[1.81, 2.04, 2.2, 2.39, 2.6, 2.76, 2.99, 3.28, 3.79]			
851	-gammaglobuliini,seerumi,elektroforeesifraktio	g/l	750	0	[2.99, 3.64, 4.54, 6.04, 7.45, 8.88, 10.65, 13.48, 17.75]			
852	-gammaglobuliini,seerumi,elektroforeesifraktio		6	16.67				
853	-m-komponentti-1,seerumi,elektroforeesifraktio(g/l)	g/l	235	0				
854	ab-happikyllästeisyys(hemoglobiini)	%	281	0	[85.16, 88.89, 91.63, 93, 94.66, 96, 96.99, 98, 99.72]		Arterial blood	
855	ab-happikyllästeisyys(hemoglobiini),eitilattava	%	9564	0	[94.52, 96.47, 97.33, 98, 98.68, 99, 99.02, 99.76, 100]		Arterial blood	
856	ab-happikyllästeisyys(hemoglobiini),eitilattava		22	100			Arterial blood	
857	ab-hemoglobiini,hiilimonoksidi	%	418	0	[0.88, 1, 1.17, 1.3, 1.46, 1.66, 1.87, 2.17, 3.22]		Arterial blood	
858	ab-hemoglobiini,hiilimonoksidi		6	83.33			Arterial blood	
859	ab-hemoglobiini,kokonais-	g/l	169	0	[92.84, 102.04, 108.76, 114.39, 119.74, 124.86, 131.01, 143.44, 154.07]		Arterial blood	
860	ab-kokonaishemoglobiini,verikaasuanalysaattorista	g/l	3736	0	[90.38, 98.41, 105.83, 113.01, 119.81, 125.77, 131.75, 138.7, 148.74]		Arterial blood	
861	ab-kokonaishemoglobiini,verikaasuanalysaattorista		11	100			Arterial blood	
862	albumiini,seerumi,elektroforeesifraktio(g/l),osatutk.2522	g/l	151	0				
863	alfa1-globuliini,seerumi,elektroforeesifraktio,osatutk.2522	g/l	151	0				
864	alfa2-globuliini,seerumi,elektroforeesifraktio,osatutk.2522	g/l	151	0				
865	b-hemoglobiini,poc-tutkimus	g/l	449	0	[113.93, 126.71, 131.95, 134.57, 137.48, 140.52, 143.63, 147.39, 154.01]		Blood	
866	b-hemoglobiini,vieritutkimus	g/l	53	0			Blood	
867	b-hemoglobiini,vieritutkimus		364	0.27	[98.15, 108.85, 118.23, 125.83, 131.08, 135.2, 142.29, 148.24, 158.27]		Blood	
868	b-hemoglobiini-a1c,(mmol/mol)pika,hoitoyksiköt	mmol/mol	272	0	[46.74, 51.39, 53.29, 55.95, 58.7, 62.41, 67.83, 74.46, 85.79]		Blood	
869	b-hemoglobiini-a1c,glykoitunut	%	455	0	[5.16, 5.3, 5.4, 5.5, 5.6, 5.7, 5.89, 6.05, 6.49]		Blood	
870	b-hemoglobiini-a1c,glykoitunut	mmol/mol	271	0	[32, 34, 35.13, 36, 37.91, 39.06, 40.89, 42.96, 49.04]		Blood	
871	b-hemoglobiini-a1c,glykoitunut		82	86.59			Blood	
872	b-hemoglobiini-a1c,verestä	mmol/m	87	0	[33, 35, 36.02, 38, 39.75, 42.05, 45.98, 49, 58]		Blood	
873	b-hemoglobiini-a1c,verestä	mmol/mol	84	0			Blood	
874	b-hemoglobiini-a1c,vieritesti	mmol/mol	143	0	[41, 43.3, 45.11, 47, 50.25, 54.18, 57.64, 61.4, 73]		Blood	
875	b-hemoglobiini-a1c,vieritesti		149	0.67	[44, 48.32, 52.33, 55.06, 58.12, 60.91, 64.78, 70.23, 80]		Blood	
876	b-hemoglobiinipvk:nosana	g/l	336	0	[128, 131.94, 134.89, 137.09, 139.43, 142.64, 145.52, 149.46, 155.11]		Blood	
877	beta1-globuliini,seerumi,elektroforeesifraktio,osatutk.2522	g/l	151	0				
878	beta2-globuliini,seerumi,elektroforeesifraktio,osatutk.2522	g/l	151	0				
879	cb-happikyllästeisyys(hemoglobiinin,osuustoiminnallisestahb:sta)	%	125	0	[84.67, 89.5, 91.13, 93, 94, 94.87, 96, 96.87, 97.75]		Capillary blood	
880	e-hemoglobiini(massa)	pg	79896	0	[27.99, 29, 29.93, 30, 30.83, 31, 31.71, 32, 33]		Erythrocyte	
881	e-hemoglobiini(massa)		39	100			Erythrocyte	
882	e-hemoglobiini(massakonsentraatio)	g/l	30325	0	[313.54, 319.46, 323.3, 326.38, 329.1, 331.89, 334.57, 338.13, 343.18]		Erythrocyte	
883	e-hemoglobiini(massakonsentraatio)		20	100			Erythrocyte	
884	e-hemoglobiini,keskimassa	pg	57843	0	[27.91, 28.98, 29.17, 30, 30.05, 30.99, 31, 31.99, 32.69]		Erythrocyte	
885	e-hemoglobiini,keskimassa	pg/u	723	0	[28.02, 28.9, 29.44, 29.9, 30.28, 30.72, 31.2, 31.67, 32.26]		Erythrocyte	
886	e-hemoglobiini,keskimassa		196	94.39			Erythrocyte	
887	e-hemoglobiini,keskimassa,poc-tutkimus	pg	448	0	[28.16, 28.97, 29.43, 29.89, 30.36, 30.76, 31.28, 31.82, 32.32]		Erythrocyte	
888	e-hemoglobiini,keskimassakonsentraatio	g/l	111249	0	[315.57, 321.3, 324.91, 327.97, 330.64, 333.04, 336.12, 339.38, 344.16]		Erythrocyte	
889	e-hemoglobiini,keskimassakonsentraatio		236	98.73	[311, 315, 316, 317, 317.38, 318, 319, 340, 360]		Erythrocyte	
890	e-hemoglobiini,keskimassakonsentraatiopoc-tutkimus	g/l	448	0	[318.8, 322.98, 325.17, 327.99, 330.55, 332.99, 335.81, 339.19, 342.62]		Erythrocyte	
891	e-hemoglobiinikeskimassa	pg	165	0	[28, 29, 29, 30, 30, 30, 31, 31.1, 32]		Erythrocyte	
892	f-hemoglobiini(kval)(ko)		113	100			Feces	
893	f-hemoglobiini,ihmisen(kval)		631	100			Feces	
894	f-hemoglobiini,ihmisen(kvant)		969	100			Feces	
895	f-hemoglobiini,uloste(kvant)		167	100			Feces	
896	gamma-globuliini,seerumi,elektroforeesifraktio,osatutk.2522	g/l	151	0				
897	happikyllästeisyys(hemoglobiini),kapillaariverestä,pikatesti␤	%	1260	0				
898	happikyllästeisyys(hemoglobiini),kapillaariveri	%	187	0	[83.49, 86.92, 88.8, 90.18, 91.45, 92.51, 93.85, 94.81, 95.79]			
899	happikyllästeisyys(hemoglobiini),kapillaariveri		55	100				
900	happikyllästeisyys(hemoglobiini),koneveri	%	493	0				
901	happikyllästeisyys(hemoglobiini),koneveri		7	100				
902	happikyllästeisyys(hemoglobiini),laskimoveri	%	1127	0	[25.96, 35.36, 42.78, 49.75, 56.48, 62.43, 69.42, 76.99, 87.36]			
903	happikyllästeisyys(hemoglobiini),laskimoveri		82	100				
904	hemoglobiini(kval)ulosteesta(f-hhb-o)		124	100				
905	hemoglobiini(totaali),kapill	g/l	3140	0	[95.53, 104.63, 112.12, 119.73, 126.55, 132.74, 139.97, 148.21, 158.33]			
906	hemoglobiini(totaali),kapill		157	100				
907	hemoglobiini(totaali),kapillaariveri	g/l	1664	0	[102.9, 111.8, 119.15, 125.69, 131.91, 138.18, 144.73, 151.95, 161.1]			
908	hemoglobiini(totaali),kapillaariveri		143	100				
909	hemoglobiini(totaali),koneveri	g/l	497	0				
910	hemoglobiini(totaali),laskim	g/l	145	0	[105.62, 116, 121.59, 126.25, 131.6, 134.5, 140.33, 151, 163.75]			
911	hemoglobiini(totaali),laskim		54	100				
912	hemoglobiini(totaali),laskimoveri	g/l	3479	0	[97.47, 108.83, 116.63, 123.24, 129, 134.66, 140.21, 146.17, 154.28]			
913	hemoglobiini(totaali),laskimoveri		173	100				
914	hemoglobiini(totaali),valtim	g/l	586	0	[86.41, 92.13, 98.96, 106.25, 112.48, 121.12, 131.9, 143.78, 154.54]			
915	hemoglobiini(totaali),valtim		77	100				
916	hemoglobiini(totaali),valtimoveri	g/l	817	0	[95.28, 105.39, 113.12, 120.87, 127.13, 132.32, 137.75, 144.13, 154.08]			
917	hemoglobiini(totaali),valtimoveri		49	100				
918	hemoglobiini,hiilimonoksidi,	%	329	0	[0.69, 0.89, 1, 1.1, 1.2, 1.31, 1.45, 1.6, 2.11]			
919	hemoglobiini,hiilimonoksidi,		45	100				
920	hemoglobiini,hiilimonoksidi,veri	%	3801	0	[0.85, 1, 1.09, 1.19, 1.28, 1.37, 1.5, 1.69, 2.05]			
921	hemoglobiini,hiilimonoksidi,veri		183	94.54				
922	hemoglobiini,ihmisen(kval),uloste		187	100				
923	hemoglobiini,ihmisen(kval),ulosteesta␤		129	100				
924	hemoglobiini,keskimassa	pg	1359	0	[28, 29, 29.59, 30, 30, 31, 31, 32, 32.37]			
925	hemoglobiini,pikatesti,veri	g/l	402	0	[112.43, 121.27, 127.7, 132.53, 136.47, 140.92, 144.6, 149.76, 155.79]			
926	hemoglobiini,pikatesti,veri		106	2.83	[87, 98.8, 106.85, 114.79, 119.6, 123.89, 128.52, 136.43, 143]			
927	hemoglobiini,pikatesti␤	g/l	470	0				
928	hemoglobiini,verestä,vieritesti	g/l	546	0	[87.08, 98.02, 108.97, 117.36, 123.51, 129.06, 134.56, 141.76, 151.9]			
929	hemoglobiini,vieritutkimus	g/l	176	0	[97.05, 108.05, 119.77, 126.94, 135.33, 139.81, 143.82, 148.66, 156.26]			
930	hemoglobiini,vieritutkimus		48	0				
931	hemoglobiini-a1c,glykoitunut(6128b-hba1c)	mmol/mol	754	0	[34, 35.81, 37, 38, 39.04, 40.16, 41.87, 43.89, 47.74]			
932	hemoglobiini-a1c,glykoitunut(b-hba1c)	mmol/mol	1452	0	[33, 34.7, 35.98, 37.02, 38.05, 39.38, 41.03, 43.55, 49.43]			
933	hemoglobiini-a1c,glykoitunut(b-hba1c)		31	100				
934	hemoglobiini-a1c,verestä	mmol/m	440	0	[33.21, 35, 36.14, 38, 39.58, 42.74, 46.05, 50.27, 61.27]			
935	immunoglobuliini,kevyetketjut,kappa-lambda-suhde,osatutk.		144	2.78				
936	immunoglobuliini,kevyetketjut,vapaat,seerumi		134	100				
937	immunoglobuliini,kevyetketjut,vapaat,seerumista		143	100				
938	immunoglobuliini,kevyetketjut,vapaat,seerumista␤		579	100				
939	immunoglobuliinie,perusseulonta,seerumista␤		168	100				
940	s-immunoglobuliini,kev.ketjut,vapaat,kappa	mg/l	118	0	[11.33, 14.61, 18.87, 24.22, 31.93, 38.89, 51.13, 59.57, 87.83]		Serum	
941	s-immunoglobuliini,kev.ketjut,vapaat,kappa		9	100			Serum	
942	s-immunoglobuliini,kev.ketjut,vapaat,lambda	mg/l	120	0	[4.45, 14.21, 18.93, 25.51, 32.35, 40, 46.7, 70.2, 114.55]		Serum	
943	s-immunoglobuliini,kev.ketjut,vapaat,lambda		7	100			Serum	
944	s-immunoglobuliini,kev.ketjutvap.kappa/lambda	ratio	183	0	[0.4, 0.63, 0.73, 0.82, 0.93, 1.01, 1.2, 3.27, 7.3]		Serum	
945	s-immunoglobuliini,kev.ketjutvap.kappa/lambda		10	100			Serum	
946	s-immunoglobuliini,kevyetketjut,kappa-lambda-suhde		781	94.24			Serum	
947	s-immunoglobuliini,kevyetketjut,vapaat		338	100			Serum	
948	s-immunoglobuliini,kevyetketjut,vapaat,kappa-	ratio	249	0			Serum	
949	s-immunoglobuliini,kevyetketjut,vapaat,kappa-lambda-suhde		2617	1.95	[0.18, 0.62, 0.77, 0.89, 1.03, 1.22, 1.54, 2.78, 10.49]		Serum	
950	s-immunoglobuliini,kevytketjut,kappa,vapaat	mg/l	579	0	[5.08, 9.18, 13.16, 17.94, 22.32, 29.65, 41.92, 82.08, 122.79]		Serum	
951	s-immunoglobuliini,kevytketjut,kappa,vapaat		6	100			Serum	
952	s-immunoglobuliini,kevytketjut,kappa-lambdasu		584	1.88	[0.25, 0.83, 1.04, 1.22, 1.39, 1.54, 1.8, 2.91, 8.41]		Serum	
953	s-immunoglobuliini,kevytketjut,lambda,vapaat	mg/l	581	0	[4.46, 6.67, 10.37, 15.39, 18.89, 22.64, 29.03, 40.28, 93.69]		Serum	
954	s-immunoglobuliini,kevytketjut,lambda,vapaat		5	100			Serum	
955	s-immunoglobuliini,kevytketjut,vapaat		1354	100			Serum	
956	u-hemoglobiini(kval)		12598	99.72			Urine	
957	vb-happikyllästeisyys(hemoglobiini)	%	1075	0	[22.59, 30.61, 38.73, 47.95, 56.57, 64.56, 71.96, 77.97, 85.94]		Venous blood	
958	vb-happikyllästeisyys(hemoglobiinin,osuustoimin	%	263	0	[32.6, 42.8, 51.66, 59.4, 68.52, 77.16, 84.06, 91.35, 96.86]		Venous blood	
959	vb-hemoglobiini(totaali),laskimoveri	g/l	95	0			Venous blood	
960	vb-hemoglobiini(totaali),laskimoveri		8	100			Venous blood	
961	vb-hemoglobiini,hiilimonoksidi	%	633	0	[0.64, 0.8, 0.93, 1.08, 1.2, 1.3, 1.47, 1.71, 2.37]		Venous blood	
962	vb-kokonaishemoglobiini,verikaasuanalysaattorista	g/l	11985	0	[95.34, 106.08, 114.94, 122.26, 128.98, 135.03, 141.42, 148.28, 156.97]		Venous blood	
963	vb-kokonaishemoglobiini,verikaasuanalysaattorista		23	100			Venous blood	
964	zb-happikyllästeisyys(hemoglobiini)	%	394	0	[58.47, 65.41, 69.39, 72.28, 75.61, 78.49, 81.02, 84.04, 87.87]		Central blood	

