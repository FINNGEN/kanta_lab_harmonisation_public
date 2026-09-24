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
Here is group 25 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1435	adalimumabi,pitoisuusjavasta-aine-paketti		101	100				
1436	b-erytroblastit,absoluuttiset,automaattidiffi	e9/l	6511	0	[0, 0, 0, 0, 0, 0, 0, 0, 0]		Blood	
1437	b-erytroblastit,absoluuttiset,automaattidiffi		221	99.55			Blood	
1438	b-lymfosyyttienimmunofenotyypitys,suppea		672	100			Blood	
1439	b-non-invasiivinenprenataalitutkimus,seulonta		699	100			Blood	
1440	b-punasoluvasta-aineidentunnistus(neuvola)		110	100			Blood	
1441	b-sikiönrhd-veriryhmäsuojaustavarten		385	100			Blood	
1442	b-sopivuuskoelaskutustavarten		257	100			Blood	
1443	biopankkinäyte,veri,helsinginbiobankki		699	100				
1444	biopankkinäyte,veri,helsinginbiopankki		255	100				
1445	crp(vo:nyhteydessäotettu),tth	mg/l	1425	0	[5, 5, 5, 6, 8, 8.93, 13.45, 17.96, 38.7]			
1446	crp(vo:nyhteydessäotettu),tth		96	100	[5, 5, 5.18, 7.78, 8, 8.56, 13.29, 22.3, 42.89]			
1447	e-abo-jarh-veriryhmämääritys,neuvolanäyte		272	100			Erythrocyte	
1448	ekg,24hrekisteröinti		672	100				
1449	ekg,pitkäaikaisrekisteröinti		152	100				
1450	elektroneuromyografia,rannekanava		171	0.58	[2.25, 5.62, 8.66, 11.41, 14.57, 17.02, 19.82, 22.79, 27.28]			
1451	fibriinind-dimeerit,pikatesti,veri	mg/l	234	0	[0.16, 0.2, 0.25, 0.3, 0.39, 0.46, 0.58, 0.76, 1.28]			
1452	fibriinind-dimeerit,pikatesti,veri		47	100				
1453	fs-lipidit,paketti(kol,hdl,trigly,ldl)		395	100			Fasting serum	
1454	hemoglobiini(vo:nyhteydessäotettu),tth	g/l	21	0				
1455	hemoglobiini(vo:nyhteydessäotettu),tth		119	0.84	[117.9, 125.18, 128.85, 133.05, 138.11, 143, 148.55, 152.76, 157.25]			
1456	ikär.paketti(lipa,s-gt,s-alat,fs-gluk,pvk)		145	100				
1457	insuliininkaltainenkasvutekijä1	nmol/l	142	0	[6.8, 9.37, 11.79, 13.6, 15.95, 17.82, 20.84, 24.13, 29.8]			
1458	insuliininkaltainenkasvutekijä1,sd-score,seerumi		104	1.92				
1459	kappa-lambda-suhde,kevytketju	ratio	718	0	[0.11, 0.48, 0.68, 0.8, 0.88, 0.99, 1.19, 1.73, 6.17]			
1460	kappa-lambda-suhde,kevytketju		5	100				
1461	kappa/lambda-suhde,kevytketjut,vapaat	ratio	124	0				
1462	kappa/lambda-suhde,kevytketjut,vapaat		7	100				
1463	krooninenmunuaistenvajaatoimintariski		16625	100				
1464	lupusantikoagulantti,drvvt,plasma	ratio	44	0				
1465	lupusantikoagulantti,drvvt,plasma		65	1.54				
1466	lupusantikoagulantti,ptt,plasma	ratio	44	0				
1467	lupusantikoagulantti,ptt,plasma		65	1.54				
1468	metanefriinijanormetanefriini,seerumi		143	100				
1469	mononukleaarisetsolut,peritoneaalidialyysineste	%	96	0				
1470	mononukleaarisetsolut,peritoneaalidialyysineste		66	100				
1471	muutsolut,peritoneaalidialyysineste		127	100				
1472	natrium,kalium,glukoosijakreatiniini,pikatesti		320	100				
1473	neulanpistopaketti(kohde)pyydäerikseenp-alat		437	100				
1474	non-invasiivinenprenataalitutkimus,seulonta		169	100				
1475	normaaliekgrekisteröinti,osastollaotettava␤		623	100				
1476	p-antifactorix-aktiivisuus(hep.estovaikutusak	iu/ml	94	0			Plasma	
1477	p-antifactorix-aktiivisuus(hep.estovaikutusak		28	100			Plasma	
1478	p-fibriinind-dimeerit,laskimon.vierit.lab:ssa	mg/l	96	0	[0.2, 0.3, 0.3, 0.5, 0.55, 0.64, 0.8, 1.05, 1.9]		Plasma	
1479	p-fibriinind-dimeerit,laskimon.vierit.lab:ssa		7	100			Plasma	
1480	p-fibriinind-dimeeritpika,hoitoyksiköt	mg/l	86	0	[0.16, 0.19, 0.29, 0.35, 0.38, 0.44, 0.67, 0.92, 1.25]		Plasma	
1481	p-fibriinind-dimeeritpika,hoitoyksiköt		65	16.92			Plasma	
1482	p-lupusantikoagulantti,aptt,varm.		113	100			Plasma	
1483	p-lupusantikoagulantti,aptt,varmistus		119	100			Plasma	
1484	p-lupusantikoagulantti,drvv,varmistus		119	100			Plasma	
1485	p-lupusantikoagulantti,drvvt,varm.		118	100			Plasma	
1486	p-plasmanneurofilamentti,kevytketju	ng/l	15	0			Plasma	
1487	p-plasmanneurofilamentti,kevytketju		94	6.38	[10.6, 12.51, 14, 16.16, 19.4, 22.2, 28.17, 33.72, 47.7]		Plasma	
1488	p-prokalsitoniini,kvantitatiivinen	ug/l	107	0	[0.09, 0.12, 0.18, 0.22, 0.31, 0.44, 0.71, 1.36, 3.78]		Plasma	
1489	p-prokalsitoniini,kvantitatiivinen		5	100			Plasma	
1490	p-sukupuolihormonejasitovaglobuliini	nmol/l	153	0	[16, 21.76, 24.35, 28.27, 33.74, 41.04, 51.31, 62.57, 81.4]		Plasma	
1491	p-troponiinit,kvantitatiivinen	ng/l	1302	0	[5.34, 7.51, 9.74, 12.67, 16.42, 21.02, 28.87, 45.13, 106.34]		Plasma	
1492	p-troponiinit,kvantitatiivinen		42	100			Plasma	
1493	ps-streptokokki,viljely,nielu		314	100			Pharyngeal secretion	
1494	ps-streptokokkia,antigeeni,hoitoyksiköt		349	100			Pharyngeal secretion	
1495	pt-down,trisomianmääritettyriskisuhde		308	100			Patient	
1496	pt-down,äidiniänmukainenriskisuhde		308	100			Patient	
1497	pt-ekg,pitkäaikaisrekisteröinti		212	100			Patient	
1498	pt-glukoosi-koe,raskaudenaikainen		133	100			Patient	
1499	pt-kliininenrasituskoe,spiroergometria		213	100			Patient	
1500	pt-kliininenrasituskoe,työjohteinen,pyöräergometria		125	100			Patient	
1501	pt-lisälausuntoilmanlaboratoriotyötä		215	100			Patient	
1502	pt-potilastapkliinispat.käsitt.kokous,eilisälau		119	100			Patient	
1503	pt-verenpaine,pitkäaikaisrekisteröinti(24h)		218	100			Patient	
1504	pt-yöpolygrafia,suppea,ambulatorinen		152	100			Patient	
1505	raskaudenaikaineninfektioseula,seerumista␤		244	100				
1506	s-anca,perinukleaarinenvärjäytymiskuvio	titre	8	0			Serum	
1507	s-anca,perinukleaarinenvärjäytymiskuvio		287	100			Serum	
1508	s-anca,sytoplasminenvärjäytymiskuvio		293	100			Serum	
1509	s-apututkimusneuvolalletr1seulvarten		165	100			Serum	
1510	s-haaraketjuistenaminohappojen(leusiini+isole	mmol/l	264	0	[0.33, 0.35, 0.37, 0.39, 0.41, 0.43, 0.45, 0.49, 0.55]		Serum	
1511	s-infektioseulonta,raskaudenaikainen		437	100			Serum	
1512	s-infliksimabi,pitoisuusjavasta-aine-paketti		125	100			Serum	
1513	s-kappa-lambda-suhde,kevytketjut,vapaa	ratio	420	0	[0.08, 0.59, 0.72, 0.83, 0.95, 1.09, 1.39, 4.1, 12.92]		Serum	
1514	s-kappa-lambda-suhde,kevytketjut,vapaa		17	82.35			Serum	
1515	s-leukosyyttivasta-aineet,elinsiirtoaodottava		242	100			Serum	
1516	s-raskaudenaikaisetinfektioseulonnat		117	100			Serum	
1517	s-sukupuolihormonejasitovaglobuliini	nmol/l	362	0	[15.94, 21.21, 27.09, 29.96, 33.17, 37.8, 43.96, 51.98, 66.54]		Serum	
1518	s-äitiysneuvoloideninfektioseulontapaketti		579	100			Serum	
1519	seeruminkokonais-iga-pitoisuusphadiaprimella		1918	100				
1520	seeruminkokonaisiga-pitoisuusphadiaprimella		120	100				
1521	solut,peritoneaalidialyysineste	e6/l	161	0				
1522	solut,peritoneaalidialyysineste		24	100				
1523	spirometria,tavall.dyn.aikatilavuusmittaus		111	100				
1524	streptokokki,viljely,nielueritteestä␤		616	100				
1525	streptokokkiviljelynielusta		567	100				
1526	sukupuolihormonejasitovaglobuliini	nmol/l	178	0	[15.92, 21.6, 25.64, 29.49, 34.33, 37.75, 44.28, 49.37, 58.64]			
1527	sukupuolihormonejasitovaglobuliini		7	71.43				
1528	tehtyposantutk.rek.siirtoavarten	ug/l	128	0	[0.4, 0.6, 0.76, 0.86, 1, 1.19, 1.31, 1.66, 2.16]			
1529	triglyseridit(trigly)/lipidit	mmol/l	2759	0	[0.66, 0.78, 0.91, 1.06, 1.2, 1.37, 1.61, 1.92, 2.5]			
1530	triglyseridit(trigly)/lipidit		20	30				
1531	triglyseridit(trigly)/lipiditosatutkimus	mmol/l	1185	0	[0.68, 0.81, 0.94, 1.07, 1.22, 1.39, 1.6, 1.93, 2.51]			
1532	triglyseridit/lipidit,osatutkimus(4568trigly)	mmol/l	191	0	[0.68, 0.82, 0.93, 1.06, 1.21, 1.39, 1.59, 1.79, 2.26]			
1533	tromboositaipumuksenselvittely,veri		111	100				
1534	ts-kolonoskopianäyte,suolisto-syöpäseulonta		467	100			Tissue	
1535	ts-kolonoskopianäyte,suolistosyöpäseulonta		150	100			Tissue	
1536	u-bakteerit,virtsatieinfektionseulonta	e6/l	1096	0	[0.98, 1.83, 4.77, 7.55, 15.13, 40.86, 154.39, 1536.97, 17022.59]		Urine	
1537	u-bakteerit,virtsatieinfektionseulonta		72	100			Urine	
1538	u-buprenorfiini,kvalitatiivinen		108	100			Urine	
1539	u-huumeseulonta,kvalitatiivinen		121	100			Urine	
1540	u-leukosyytit,virtsatieinfektionseulonta	e6/l	1103	0	[1, 1.42, 2.64, 4.38, 8.73, 18.87, 44.47, 146.04, 693.4]		Urine	
1541	u-leukosyytit,virtsatieinfektionseulonta		65	98.46			Urine	
1542	u-metyleenidioksimetamfetamiini(kval)		180	100			Urine	
1543	u-partikkelienperuslaskenta,koneellinen		8653	100			Urine	
1544	u-pneumokokki,antigeeninosoitus		570	100			Urine	
1545	u-pregabaliini,kvalitatiivinen		294	100			Urine	
1546	u-solut,partikkelienperuslaskenta=u-sakka		101	100			Urine	
1547	u-virtsanominaispainohuumemäärityksissä		216	5.09	[1, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02]		Urine	
1548	verensopivuuskoe(vainlaboratorionkäyttöön)		268	100				
1549	virtsanpartikkelienlaskenta(solut)		2117	100				
1550	virtsanpartikkelienperuslaskenta		7795	100				
1551	virtsatutkimus(vo:nyhteydessäotettu),tth		108	99.07				
1552	äitiysneuvoloidenseulontatutkimus		653	100				

