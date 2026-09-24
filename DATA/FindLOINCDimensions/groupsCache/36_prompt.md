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
Here is group 36 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
1868	-histologinensolublokkisytologisestanäytteestä		214	100				
1869	-humanpapillomavirusgenotyyppi16		301	100				
1870	-humanpapillomavirusgenotyyppi18		301	100				
1871	-humanpapillomavirusgenotyyppimuupatogeeninenhpv		252	100				
1872	-lisämaksukiireellisenäpyydetyllenäytteelle		584	100				
1873	-lisätutkimuspyyntöaiemmintutkitullenäytteelle		191	100				
1874	-lisävastaus2laskutuskuitatullenäytteelle		438	100				
1875	-lisävastauslaskutuskuitatullenäytteelle		2865	100				
1876	-moniresistentitgram-negatiivisetsauvat,viljely		122	100				
1877	-moniresistentitgramnegatiivisetsauvat,viljely		163	100				
1878	-resistentitgramnegatiivisetsauvat,viljely		314	100				
1879	-staphylococcusaureus,metilliiniresist.viljely		248	100				
1880	-staphylococcusaureus,metisilliiniresistentti,v		540	100				
1881	b-glukoosi,hoitoyksikönvieritesti,kokoveri		687	0.15	[5.55, 5.93, 6.7, 7.42, 8.33, 9.1, 10.22, 12.18, 14.28]		Blood	
1882	b-hematologisenpotilaanperuskaryotyypinmääritys		125	100			Blood	
1883	b-kreatiniini,hoitoyksikönvieritesti,veri		167	0	[58.29, 69.03, 76.8, 84.73, 95.67, 105.12, 116.21, 134.79, 170]		Blood	
1884	bakteerit,virtsasta,partikkelinlaskijalla,osatutk.		212	100				
1885	bm-pahanlaatuisenveritaudinimmunofenotyypitys		191	100			Bone marrow	
1886	bm-pahanlaatuisenveritaudinimmunofenotyyppinenjäännöstautianalyysi		162	100			Bone marrow	
1887	cb-hemoglobiini,vieritestihoitoyksikössä	g/l	101	0	[84.5, 92.5, 100.5, 112.5, 121.56, 127.06, 131.83, 135.83, 146]		Capillary blood	
1888	cp-glukoosi,ihopistosn,vieritestihoitoyksikössä	mmol/l	5203	0	[5.2, 6.16, 6.92, 7.87, 8.89, 10.17, 11.74, 13.96, 16.77]			
1889	cp-glukoosi,ihopistosn,vieritestihoitoyksikössä		19	100	[5.33, 6.26, 7.1, 7.98, 9.1, 10.33, 11.92, 13.89, 16.96]			
1890	crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella	mg/l	771	0	[2.6, 5.17, 9.64, 14.69, 22, 32.29, 47.95, 69.4, 106.84]			
1891	crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella		192	85.42				
1892	e-retikulosyyttienkeskimääräinenhemoglobiininmäärä	pg	438	0	[26.9, 30, 31.94, 33, 34, 34.57, 35, 36, 37.53]		Erythrocyte	
1893	e-retikulosyyttienkeskimääräinenhemoglobiininmäärä		15	6.67			Erythrocyte	
1894	emäsylimäärä,laskimoverestä,pikatesti␤	mmol/l	373	0				
1895	emäsylimäärä,laskimoverestä,pikatesti␤		339	19.47				
1896	epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk.	e6/l	203	0	[0.2, 0.4, 0.66, 1, 1.3, 1.71, 2.47, 3.65, 8.32]			
1897	epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk.		9	100				
1898	epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta	iu/ml	24	0				
1899	epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta		241	100				
1900	erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk.	e6/l	202	0	[3.19, 4.28, 5.76, 7.13, 9.35, 12.16, 16.65, 32.02, 93.76]			
1901	erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk.		10	100				
1902	fp-kollageenii:nbeta-karboksiterminaalinentelopeptidi	ug/l	299	0	[0.08, 0.14, 0.17, 0.21, 0.26, 0.3, 0.36, 0.45, 0.63]		Fasting plasma	
1903	happamusaste,kapillaariverestä,pikatesti␤		1262	0.24				
1904	happamuusaste,laskimoverestä,pikatesti␤		712	0.7				
1905	happiosapaine,kapillaariverestä,pikatesti␤	kpa	1260	0				
1906	happoemästasejahappi,laskimoverestä,pikatesti␤		643	100				
1907	hepatiittic-virus,nh,jatkotutkimus,plasmasta		512	100				
1908	hiilidioksidiosapaine,laskimoverestä,pikatesti␤	kpa	707	0				
1909	hiilidioksidiosapaine,laskimoverestä,pikatesti␤		5	100				
1910	hpv-gt16aptimapanther,apututkimustulostensiirtoon		149	100				
1911	hpv-gt18-45aptimapanther,apututkimustulostensiirtoon		149	100				
1912	hpvaptimapanther,apututkimustulostensiirtoon		413	100				
1913	humanimmunodeficiencyvirus,antigeenijavasta-		192	100				
1914	humanimmunodeficiencyvirus,antigeenijavasta-aineet,yhd		260	100				
1915	huume-jalääkeainetutkimus,laaja,varmistus		448	100				
1916	huumeseulonta,kvalitatiivinen,virtsasta␤		140	100				
1917	kalium,hoitoyksikönvieritesti,veri	mmol/l	166	0	[3.34, 3.65, 3.8, 3.9, 4, 4.19, 4.3, 4.42, 4.6]			
1918	kalium,hoitoyksikönvieritesti,veri		290	0	[3.4, 3.69, 3.8, 3.9, 4.06, 4.2, 4.4, 4.56, 5]			
1919	kreatiniini,hoitoyksikönvieritesti,veri	mmol/l	163	0	[61.44, 68.7, 74.81, 78.74, 84.67, 94.44, 102.62, 112.17, 146.53]			
1920	kreatiniini,virtsasta(huumeseulonnanyhteydessä)	mmol/l	874	0	[2.21, 3.1, 4.22, 5.54, 6.81, 8.47, 10.55, 13.18, 17.82]			
1921	kreatiniini,virtsasta(huumeseulonnanyhteydessä)		6	66.67				
1922	laajahuumeseulonta,varmistustasoinen,virtsasta		944	100				
1923	lieriöt,virtsasta,partikkelinlaskijalla,osatutk.	e6/l	203	0	[0, 0, 0, 0, 0, 0, 0, 0.1, 0.4]			
1924	lieriöt,virtsasta,partikkelinlaskijalla,osatutk.		9	100				
1925	lisävastauslaskutuskuitatullenäytteelle		214	100				
1926	luuntiheysmittaus,2kohdetta(nk6sa),lausuttuna		145	100				
1927	marevan-hoidonseur.tatesti,hoitoyksikkötekeesormenpäänäyte		168	0				
1928	moniresistentitgramnegatiivisetsauvat,viljely		206	100				
1929	natrium,hoitoyksikönvieritesti,veri	mmol/l	163	0	[133.07, 135, 136.54, 138, 139, 139.55, 140, 141, 142]			
1930	natrium,hoitoyksikönvieritesti,veri		292	0	[131.17, 133.92, 135.97, 137.29, 138.69, 139.5, 140, 141, 142]			
1931	natriureettinenpeptidi,b-tyypinn-terminaalinenpropeptidi,plasmasta	ng/l	159	0	[27.45, 51.56, 106.33, 265.57, 634.4, 1351.3, 2903.04, 5577.84, 11032.2]			
1932	nk-solujenosuus(määritettynäcd3-/cd16+/cd56+-soluina)	%	665	0	[4, 7.07, 9.79, 12.53, 14.84, 17.1, 21.25, 26.92, 36.91]			
1933	osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk.	mosm/kgh2o	203	0	[331.17, 377.3, 431.74, 500.49, 539.14, 595.38, 634.62, 686.05, 750.53]			
1934	osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk.		9	100				
1935	p-natriureett.peptidin-termin.propept.vieritl	ng/l	118	0	[140.45, 226.81, 316.84, 708.93, 1117.67, 1691.6, 2121.04, 3414.6, 4866.2]		Plasma	
1936	p-natriureett.peptidin-termin.propept.vieritl		20	100			Plasma	
1937	p-natriureettinenpeptidi,b-tyypinn-terminaalin	ng/l	4682	0	[86.24, 151.65, 238.65, 387.07, 653.89, 1066.35, 1771.72, 3084.52, 6142.85]		Plasma	
1938	p-natriureettinenpeptidi,b-tyypinn-terminaalin		149	100			Plasma	
1939	p-natriureettinenpeptidi,b-tyypn-term.propeptidi	ng/l	1366	0	[106.15, 192.31, 311.64, 535.82, 915.89, 1456.12, 2310.73, 3820.95, 6983]		Plasma	
1940	p-natriureettinenpeptidi,b-tyypn-term.propeptidi		107	100			Plasma	
1941	parasiitit,ulosteesta(alkueläintenkystat,madot,madonmunat,toukat)		120	100				
1942	pienikudoskoepala,enintään1-3samankokonaisuudennäytettä		234	100				
1943	pika:m10inabnhp,rsvnhp,cv19nhp,yhdistelmävierit.		267	100				
1944	pt-diffuusiokapasiteetti,single-breath-menetelmä,tavallinenperusmittaus		3577	100			Patient	
1945	pt-lausuntoneurofysiologisestatutkimuksesta,hälytysindikaatiot		113	100			Patient	
1946	pt-luuntiheysmittaus,2kohdetta,ilmanlausuntoa		120	100			Patient	
1947	pt-sydämenkattavarakenteellinenjatoiminnallinenuä(fm1ee)		177	100			Patient	
1948	pt-uloshengityksenhuippuvirtaus,vuorokausivaihtelunseuranta		474	100			Patient	
1949	pt-yöpolygrafia,ambulatorinen,hyvinsuppeaunirekisteröintikotona		542	100			Patient	
1950	pt-yöpolygrafia,ambulatorinen,jalkaliikerekisteröinnein		102	100			Patient	
1951	pu-aerobinenjaanaerobinenbakteerityypitysjaan		147	100			Pus	
1952	resistentitgramnegatiivisetsauvat,viljely		320	100				
1953	retikulosyyttienkeskimääräinenhemoglobiininmäärä	pg	525	0	[26.59, 29.88, 31.77, 32.87, 33.87, 34, 35, 35.95, 37]			
1954	retikulosyyttienkeskimääräinenhemoglobiininmäärä		5	100				
1955	s-humanimmunodeficiencyvirus,antigeenijavast		1221	100			Serum	
1956	sikiöperäisendna:ntutkimusäidinverinäytteestä		104	100				
1957	staphylococcusaureus,metisilliiniresistenssiviljely␤		134	100				
1958	staphylococcusaureus,metisilliiniresistentti(mrsa),viljely		627	100				
1959	t-auttajasolujenosuus(määritettynäcd3+cd4+soluina)	%	665	0	[12.24, 17.15, 20.76, 25.01, 30.99, 37.63, 47.04, 52.34, 60.07]		Thrombocyte	
1960	t-estäjäsolujenosuus(määritettynäcd3+cd8+soluina)	%	665	0	[14.45, 20.35, 24.03, 27.06, 32.04, 37.14, 44.33, 52.92, 66.66]		Thrombocyte	
1961	troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella	ng/l	7	0				
1962	troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella		97	93.81				
1963	ts-histologinentutkimus,1-3kudosnäytettä		160	100			Tissue	
1964	ts-histologinentutkimus,1-3näytettä		945	100			Tissue	
1965	työpaikanhuumeseulontajavarmistus,4yhdistettä		469	100				
1966	työpaikanhuumeseulontajavarmistus,7yhdistettä		312	100				
1967	täydellinennimi:pt-näytteenotto0maksu,kierronulkopuolisetnäytteet		1481	100				
1968	täydellinenverenkuva,sis.perusverenkuvanjaleukosyyttienerittelylaskennan␤		9742	100				
1969	u-amfetamiinijametamfetamiini,enantiomeerienerittely		120	100			Urine	
1970	u-asetoniaineet,kval,vieritestihoitoyksikössä		421	100			Urine	
1971	u-erytrosyytit,kval,vieritestihoitoyksikössä		413	100			Urine	
1972	u-glukoosi,kvalvieritestihoitoyksikössä		423	100			Urine	
1973	u-happamuusaste,vieritestihoitoyksikössä		400	0.25	[5.5, 5.5, 5.5, 5.9, 6, 6, 6.5, 7, 7]		Urine	
1974	u-huume-jalääkeainetutkimus,laaja,varmistus		175	100			Urine	
1975	u-huume-jalääkeainetutkimus,semikvantitatiivinen,virtsa␤sta		121	100			Urine	
1976	u-huumeseulonta,laaja(kvalitatiivinenlc-tof-ms)		144	100			Urine	
1977	u-kemiallinenseulonta,vieritestihoitoyksikössä		104	100			Urine	
1978	u-kreatiniini,virtsasta(huumeseulonnanyhteydessä)	mmol/l	398	0	[2.13, 2.88, 3.69, 4.73, 6, 7.61, 9.67, 12.44, 16.61]		Urine	
1979	u-laajahuume-jalääkeainetutkimus,semikvantitatiivinen		421	100			Urine	
1980	u-leukosyytit,kval,vieritestihoitoyksikössä		429	100			Urine	
1981	u-nitriitti,kval,vieritestihoitoyksikössä		421	100			Urine	
1982	u-proteiini,kval,vieritestihoitoyksikössä		425	100			Urine	
1983	vieritestilaite(epoc)verikaasuanalyysilaskimonäytteestä		162	100				
1984	yersinia(lajitenterocolitica,pseudotuberculosis,pestis)nho,ulosteesta␤		484	100				

