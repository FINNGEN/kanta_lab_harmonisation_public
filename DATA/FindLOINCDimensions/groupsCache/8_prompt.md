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
Here is group 8 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
386	cladosporiumherbarum(m2),ige-vasta-aineet	u/ml	14	0				
387	cladosporiumherbarum(m2),ige-vasta-aineet		87	100				
388	hepatiitticvirus,vasta-aineet		354	100				
389	s-allige,cladosporiumherbarum,home/mögel	u/ml	27	0			Serum	
390	s-allige,cladosporiumherbarum,home/mögel		559	99.82			Serum	
391	s-bordetellapertussis,igavasta-aineet	iu/ml	22	0			Serum	
392	s-bordetellapertussis,igavasta-aineet		111	100			Serum	
393	s-bordetellapertussis,iggvasta-aineet	iu/ml	32	0			Serum	
394	s-bordetellapertussis,iggvasta-aineet		79	100			Serum	
395	s-bordetellapertussis,vasta-aineet		122	100			Serum	
396	s-chlamydiapneumoniae,iggvasta-aineet	au/ml	49	0			Serum	
397	s-chlamydiapneumoniae,iggvasta-aineet	bu/ml	12	0			Serum	
398	s-chlamydiapneumoniae,iggvasta-aineet	eiu	55	0			Serum	
399	s-chlamydiapneumoniae,iggvasta-aineet	u/ml	10	0			Serum	
400	s-chlamydiapneumoniae,iggvasta-aineet		72	83.33			Serum	
401	s-chlamydiapneumoniae,igmvasta-aineet	index	6	0			Serum	
402	s-chlamydiapneumoniae,igmvasta-aineet		112	83.93			Serum	
403	s-cladosporiumherbarum(m2),ige-vasta-aineet	u/ml	157	0	[0, 0, 0.01, 0.01, 0.01, 0.01, 0.02, 0.03, 0.07]		Serum	
404	s-cladosporiumherbarum(m2),ige-vasta-aineet		33	100			Serum	
405	s-cladosporiumherbarum,igevasta-aineet	u/ml	145	0	[0, 0, 0.01, 0.01, 0.01, 0.01, 0.02, 0.06, 0.23]		Serum	
406	s-cladosporiumherbarum,igevasta-aineet		365	100			Serum	
407	s-cytomegalovirus,iggvasta-aineet	au/ml	19	0			Serum	
408	s-cytomegalovirus,iggvasta-aineet	eiu	73	0			Serum	
409	s-cytomegalovirus,iggvasta-aineet	u/ml	58	0			Serum	
410	s-cytomegalovirus,iggvasta-aineet		113	100			Serum	
411	s-cytomegalovirus,igmvasta-aineet		258	100			Serum	
412	s-cytomegalovirus,vasta-aineet		197	100			Serum	
413	s-dermatophagoidespteronyssinus,igevasta-aineet	u/ml	164	0	[0.02, 0.03, 0.05, 0.1, 0.24, 0.49, 0.83, 1.79, 3.57]		Serum	
414	s-dermatophagoidespteronyssinus,igevasta-aineet		236	100			Serum	
415	s-epstein-barrinvirus,vasta-aineet		110	100			Serum	
416	s-epstein-barrvirus,iggvasta-aineet	u/ml	75	0	[47, 98, 133.25, 160, 192.38, 246, 426.88, 539.5, 670]		Serum	
417	s-epstein-barrvirus,iggvasta-aineet		56	100			Serum	
418	s-epstein-barrvirus,igmvasta-aineet		133	100			Serum	
419	s-epstein-barrvirus,vasta-aineet		156	100			Serum	
420	s-gliadiinipeptidit,deamidoidut,iga-vasta-aineet	u/ml	304	0	[0.3, 0.49, 0.58, 0.7, 0.8, 1, 1.24, 1.66, 2.4]		Serum	
421	s-gliadiinipeptidit,deamidoidut,iga-vasta-aineet		5	60			Serum	
422	s-gliadiinipeptidit,deamidoidut,igg-vasta-aineet	u/ml	95	0	[0.5, 0.5, 0.5, 0.6, 0.7, 0.78, 0.99, 1.4, 2.9]		Serum	
423	s-gliadiinipeptidit,deamidoidut,igg-vasta-aineet		220	99.55			Serum	
424	s-hepatiittia-virus,igmvasta-aineet		174	100			Serum	
425	s-hepatiittia-virus,vasta-aineet		189	100			Serum	
426	s-hepatiittiavirus,kokonaisvasta-aineet		125	100			Serum	
427	s-hepatiittic-virus,iggvasta-aineet		475	100			Serum	
428	s-hepatiittic-virus,vasta-aineet		1340	100			Serum	
429	s-hepatiittie-virus,igg-vasta-aineet		302	100			Serum	
430	s-hepatiittie-virus,igm-vasta-aineet		295	100			Serum	
431	s-hepatitisavirus,igmvasta-aineet		236	100			Serum	
432	s-hepatitisavirus,vasta-aineet		333	100			Serum	
433	s-hepatitisc-virus,vasta-aineet		138	100			Serum	
434	s-hepatitiscvirus,vasta-aineet		945	100			Serum	
435	s-hevosenhilse(e3),igevasta-aineet	u/ml	109	0	[0.01, 0.01, 0.02, 0.03, 0.07, 0.18, 0.34, 0.88, 2.13]		Serum	
436	s-hevosenhilse(e3),igevasta-aineet		76	100			Serum	
437	s-hevosenhilse,igevasta-aineet	u/ml	151	0	[0, 0.01, 0.01, 0.02, 0.03, 0.17, 0.73, 2.15, 4.62]		Serum	
438	s-hevosenhilse,igevasta-aineet		295	100			Serum	
439	s-kissanhilse(e1),ige-vasta-aineet	u/ml	135	0	[0, 0.01, 0.02, 0.04, 0.09, 0.38, 1.27, 2.29, 6.85]		Serum	
440	s-kissanhilse(e1),ige-vasta-aineet		19	100			Serum	
441	s-kissanhilse,igevasta-aineet	u/ml	149	0	[0.01, 0.06, 0.5, 0.86, 1.3, 2.2, 3.32, 6.87, 11.68]		Serum	
442	s-kissanhilse,igevasta-aineet		244	100			Serum	
443	s-koiranhilse(e5),ige-vasta-aineet	u/ml	192	0	[0.01, 0.03, 0.04, 0.06, 0.11, 0.27, 0.62, 1.76, 3.86]		Serum	
444	s-koiranhilse(e5),ige-vasta-aineet		12	100			Serum	
445	s-koiranhilse,igevasta-aineet	u/ml	198	0	[0.01, 0.03, 0.09, 0.19, 0.44, 0.88, 1.61, 3.81, 11.48]		Serum	
446	s-koiranhilse,igevasta-aineet		239	100			Serum	
447	s-koivunsiitepöly(t3),igevasta-aineet	u/ml	124	0	[0.02, 0.03, 0.13, 0.33, 0.77, 2.07, 3.66, 8.07, 20.03]		Serum	
448	s-koivunsiitepöly(t3),igevasta-aineet		17	100			Serum	
449	s-koivunsiitepöly,igevasta-aineet	u/ml	293	0	[0.01, 0.03, 0.08, 0.55, 1.1, 2.22, 3.98, 9.74, 23.71]		Serum	
450	s-koivunsiitepöly,igevasta-aineet		230	100			Serum	
451	s-mycoplasmapneumoniae,iggvasta-aineet	eiu	292	0	[38.55, 55.61, 70.84, 87.4, 101.82, 120.14, 142.69, 167.66, 224.06]		Serum	
452	s-mycoplasmapneumoniae,iggvasta-aineet		94	97.87			Serum	
453	s-mycoplasmapneumoniae,igmvasta-aineet	s/co	94	0	[0.1, 0.2, 0.2, 0.28, 0.3, 0.4, 0.5, 0.71, 1]		Serum	
454	s-mycoplasmapneumoniae,igmvasta-aineet		328	99.7			Serum	
455	s-mycoplasmapneumoniae,vasta-aineet		306	100			Serum	
456	s-mycoplasmapneumoniae,vasta-aineet,lausunto		146	100			Serum	
457	s-mykoplasmapneumoniae,iggvasta-aineet	au/ml	8	0			Serum	
458	s-mykoplasmapneumoniae,iggvasta-aineet	eiu	40	0			Serum	
459	s-mykoplasmapneumoniae,iggvasta-aineet		58	67.24			Serum	
460	s-pujonsiitepöly(w6),igevasta-aineet	u/ml	64	0	[0.01, 0.01, 0.02, 0.05, 0.07, 0.14, 0.21, 0.64, 1.4]		Serum	
461	s-pujonsiitepöly(w6),igevasta-aineet		38	100			Serum	
462	s-pujonsiitepöly,igevasta-aineet	u/ml	206	0	[0, 0.01, 0.01, 0.03, 0.1, 0.29, 0.5, 0.85, 1.88]		Serum	
463	s-pujonsiitepöly,igevasta-aineet		305	100			Serum	
464	s-puumalavirus,iggvasta-aineet		153	98.69			Serum	
465	s-puumalavirus,igmpikatesti		177	100			Serum	
466	s-puumalavirus,igmvasta-aineet		137	98.54			Serum	
467	s-puumalavirus,vasta-aineet		155	100			Serum	
468	s-pölyerittely(phadiatop),igevasta-aineet	u/ml	249	0	[0.13, 0.25, 0.55, 1.13, 1.79, 3.13, 5.22, 8.41, 20.35]		Serum	
469	s-pölyerittely(phadiatop),igevasta-aineet		188	100			Serum	
470	s-pölyerittely,ige-vasta-aineet	u/ml	133	0	[0.02, 0.03, 0.04, 0.07, 0.13, 0.25, 0.91, 3.32, 9.84]		Serum	
471	s-pölyerittely,ige-vasta-aineet		12	100			Serum	
472	s-pölyerittely,igevasta-aineet	u/ml	539	0	[0.02, 0.03, 0.04, 0.06, 0.11, 0.23, 0.84, 2.4, 7.46]		Serum	
473	s-pölyerittely,igevasta-aineet		134	100			Serum	
474	s-ruoka-aine-erittely(fx5),igevasta-aineet	u/ml	61	0	[0.02, 0.04, 0.07, 0.1, 0.13, 0.15, 0.19, 0.27, 0.64]		Serum	
475	s-ruoka-aine-erittely(fx5),igevasta-aineet		50	100			Serum	
476	s-timoteinsiitepöly(g6),igevasta-aineet	u/ml	120	0	[0.01, 0.03, 0.12, 0.3, 0.59, 1.19, 1.92, 3.57, 6.47]		Serum	
477	s-timoteinsiitepöly(g6),igevasta-aineet		25	100			Serum	
478	s-timoteinsiitepöly,igevasta-aineet	u/ml	256	0	[0.01, 0.04, 0.36, 0.69, 1.17, 2.14, 3.76, 6.61, 12.37]		Serum	
479	s-timoteinsiitepöly,igevasta-aineet		223	100			Serum	
480	s-varicella-zostervirus,iggvasta-aineet	eiu	23	0			Serum	
481	s-varicella-zostervirus,iggvasta-aineet	iu/l	47	0			Serum	
482	s-varicella-zostervirus,iggvasta-aineet	miu/ml	7	0			Serum	
483	s-varicella-zostervirus,iggvasta-aineet		54	100			Serum	
484	s-varizella-zostervirus,vasta-aineet,lausunto		103	100			Serum	

