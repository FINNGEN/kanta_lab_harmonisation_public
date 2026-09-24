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
Here is group 6 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
279	-adenovirus,nukleiinihappo(kval)		235	100				
280	-bakteeri,nukleiinihappo-osoitus		151	100				
281	-bocavirus,nukleenihappo		840	100				
282	-gardnerellavaginalis,nukleiinihappo		270	100				
283	-herpessimplex-virus1,nukleiinihappo		125	100				
284	-herpessimplex2,nukleiinihappo		125	100				
285	-herpessimplexvirus,nukleiinihappo(kval)		151	100				
286	-jc-virusnukleiinihappo(kvant)		340	100				
287	-koronavirus,nukleiinihappo(kval)		233	100				
288	-koronavirus229e,nukleiinihappo		568	100				
289	-koronavirushku1,nukleiinihappo		640	100				
290	-koronavirusnl63,nukleiinihappo		568	100				
291	-koronavirusoc43,nukleiinihappo		568	100				
292	-papilloomavirus(hpv),nukleiinihappo(kval)		179	100				
293	-papilloomavirus(hpv),nukleiinihappo(kval),suu		351	100				
294	-papilloomavirus(hpv),suurenriskin,dna-osoitus		1187	100				
295	-papilloomavirus,muukorkeanriskintyyppi		320	100				
296	-papilloomavirus,muusuurenriskintyyppi,nuklei		173	100				
297	-papilloomavirus,tyyppi16,nukleiinihappo(kval)		172	100				
298	-papilloomavirus,tyyppi18,nukleiinihappo(kval)		172	100				
299	-polyomavirus(jcv,bkv),nukleiinihaponos.(pcr)kvant.		119	100				
300	-polyomavirus,nukleiinihappo(kvant)		221	100				
301	-rino-/enterovirus,nukleiinihappo(kval)		233	100				
302	-rino/enterovirus,nukleiinihappo		638	100				
303	-rs-virus,nukeliinihapon(kval)		574	100				
304	-rs-virus,nukleiinihappo(kav)		381	100				
305	-rs-virus,nukleiinihappo(kva)		356	100				
306	-rs-virus,nukleiinihappo(kval)		3637	100				
307	-sieninukleiinihappo		203	100				
308	adenovirus,nukeliinihappo(kval)␤		307	100				
309	adenovirus,nukleiinihappo(kv		544	100				
310	adenovirus,nukleiinihappo(kval)		225	100				
311	bakteeri,nukleiinihaponosoittaminen(kval)␤		173	100				
312	bakteeri,nukleiinihappo(kval)		118	100				
313	bakteerit,nukleiinihappo(kva		502	100				
314	bakteerit,nukleiinihappo(kval),uloste		1132	100				
315	bk-virus,nukleiinihappo		151	100				
316	bk-virus,nukleiinihappo(kvant)		280	100				
317	blastocystishominis,nukleiinihappo		319	100				
318	bokavirus,nukleiinihappo(kva		109	100				
319	bokavirus,nukleiinihappo(kval)		213	100				
320	covid-19,nukleiinihappo		1651	100				
321	cytomegalovirus,nukleiinihappo	iu/ml	26	0				
322	cytomegalovirus,nukleiinihappo		447	100				
323	cytomegalovirus,nukleiinihappo(kvant),plasmasta␤	iu/ml	118	0				
324	cytomegalovirus,nukleiinihappo(kvant),plasmasta␤		554	100				
325	epstein-barrvirus,nukleiinihappo(kvant)	iu/ml	15	0				
326	epstein-barrvirus,nukleiinihappo(kvant)		311	100				
327	f-adenovirus,nukleiinihappo(kval)		986	100			Feces	
328	f-mikrobit,nukleiinihaponosoitus(kval)ulosteesta		373	100			Feces	
329	f-norovirus,nukleiinihappo(kval)		1793	100			Feces	
330	f-rotavirus,nukleiinihappo		847	100			Feces	
331	f-rotavirus,nukleiinihappo(kval)		985	100			Feces	
332	f-sapovirus,nukleiinihappo(kval)		985	100			Feces	
333	jc-virus,nukleiinihappo		151	100				
334	jc-virus,nukleiinihappo(kvant)		280	100				
335	koronavirus,nukleiinihappo(k		109	100				
336	koronavirus,nukleiinihappo(kval)		209	100				
337	mikrobit,nukleiinihappo(kval),uloste		133	100				
338	norovirus,nukleiinihappo(kval)		300	100				
339	p-bk-virus,nukleiinihappo(kvant)	iu/ml	56	0			Plasma	
340	p-bk-virus,nukleiinihappo(kvant)		47	100			Plasma	
341	p-cytomegalovirus,nukleiinihappo(kvant)	iu/ml	49	0			Plasma	
342	p-cytomegalovirus,nukleiinihappo(kvant)		203	100			Plasma	
343	p-cytomegalovirus,nukleiinihappo,(kvant)	iu/ml	102	0			Plasma	
344	p-cytomegalovirus,nukleiinihappo,(kvant)		242	100			Plasma	
345	p-cytomegalovirus,nukleiinihappo,kvantitatiivi	iu/ml	95	0			Plasma	
346	p-cytomegalovirus,nukleiinihappo,kvantitatiivi		278	100			Plasma	
347	p-sytomegalovirus,nukleiinihappo(kvant)	iu/ml	29	0			Plasma	
348	p-sytomegalovirus,nukleiinihappo(kvant)		125	100			Plasma	
349	papillomavirus,nukleiinihappo(kval)		580	100				
350	papilloomavirus(hpv),nukleiinihappo(kval)		470	100				
351	papilloomavirus(hpv),suurenriskin,mrna-osoitus␤		396	100				
352	pikornavirus,nukleiinihappo		109	100				
353	pikornavirus,nukleiinihappo(kval)		249	100				
354	polyomavirus,nukleiinihappo(kvant)␤		237	100				
355	polyoomavirus,nukleiinihappo		335	100				
356	rino7enterovirus,nukleiinihappoosoitus		603	100				
357	rs-virus,nukleiinihappo		1647	100				
358	rs-virus,nukleiinihappo(kval		281	100				
359	rs-virus,nukleiinihappo(kval)		1827	100				
360	rsvnukleiinihappo(kval)		332	100				
361	ulosteenadenovirus,nukleiinihappo		912	100				
362	ulosteenastrovirus,nukleiinihappo		912	100				
363	ulosteensapovirus,nukleiinihappo		899	100				

