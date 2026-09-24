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
Here is group 12 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
745	-bakteeriviljely,aerobi		4363	100				
746	-bakteeriviljely,anaerobi		4354	100				
747	-mycobacterium,viljelyjavärjäys		115	100				
748	-mycobacteriumtuberculosis,nukleiinihaponosoitus		141	100				
749	-mycobacteriumtuberculosis,nukleiinihappo(kval)		147	100				
750	-mycobacteriumtuberculosis,pikavärjäys		219	100				
751	-mycobacteriumtuberculosis,viljely		199	100				
752	-mycobacteriumtuberculosis,värjäys		117	100				
753	-mycobacteriumtuberculossis,värjäys		354	100				
754	-s.aureus-viljely,nenästä		154	100				
755	-tuberkuloosibakteeri,viljely(sisältääainamyös		104	100				
756	-tuberkuloosibakteeri,värjäysjaviljely		112	100				
757	b-bakteeri,jatkotutkimus,nho		143	100			Blood	
758	b-bakteeri,jatkoviljely(verestä),seulottunäyte␤		599	100			Blood	
759	b-bakteeri,jatkoviljely,seulottunäyte		730	100			Blood	
760	b-bakteeri,veriviljely,seulonta		442	100			Blood	
761	b-bakteeri,viljely,seulonta		5420	100			Blood	
762	b-bakteeri,viljelyverestä		3944	100			Blood	
763	b-m.tuberculosis-herkistyneetsolut,gammainterferoni,eritys		134	100			Blood	
764	b-mycobacteriumtuberculosis-herkistyneetsolut,gammainterferoni,eritys	iu/ml	373	0	[0, 0, 0, 0, 0.01, 0.01, 0.02, 0.02, 0.06]		Blood	
765	b-mycobacteriumtuberculosis-herkistyneetsolut,gammainterferoni,eritys		185	100			Blood	
766	bakteeri,jatkoviljelyvirtsasta		4187	100				
767	bakteeri,jatkoviljelyvirtsastakäytössä		850	100				
768	bakteeri,maljaviljely,virtsasta␤		835	100				
769	bakteeri,seulontajaviljely␤		9920	100				
770	bakteeri,seulontaviljely,steriilitnestemäisetnäytteet		112	100				
771	bakteeri,seulontavirtsasta		187	100				
772	bakteeri,viljely(1:aerobitjaanaerobitsyvänäytteestä),märkäeritteestä		224	100				
773	bakteeri,viljely(verestä)		3588	100				
774	bakteeri,viljely(virtsasta)		6659	100				
775	bakteeri,viljely(ysköksestä,sisältäävärjäyksen)		128	100				
776	bakteeri,viljely,verestä		205	100				
777	bakteeri,viljely,verestä␤		5422	100				
778	bakteeri,viljely,virtsasta		2172	100				
779	bakteeri,viljely,ysköksestä		172	100				
780	bakteeri,viljely1(anaerobi-sekäaerobiviljelysekävärjäys)		938	100				
781	bakteeri,viljely1(salmonella,shigella,yersinia,campylobacter)		135	100				
782	bakteeri,viljely1,syvämärkänäyte(anaerobi+aerobi)␤		850	100				
783	bakteeri,viljely2(aerobiviljely)		423	100				
784	bakteeri,viljely2,pinnallinenmärkänäyte(aerobi)␤		745	100				
785	bakteeri,viljelyjanuk		114	100				
786	bakteeri,viljelyvirtsasta		10088	100				
787	bakteeriulosteviljelyjanho		506	100				
788	bakteeriviljely,virtsasta		452	100				
789	bakteeriviljelyverestä		506	100				
790	ex-bakteeri,viljely(ysköksestä,sisältäävärjäyksen)		106	100			Expectorate (sputum)	
791	ex-mycobacteriumtuberculosis,viljelyjavärjäys		115	100			Expectorate (sputum)	
792	ex-tuberkuloosibakteeri,värjäysjaviljely		168	100			Expectorate (sputum)	
793	f-bakt.viljelyjanho		391	100			Feces	
794	f-bakteeri,viljelyjanukleiinihappoulosteesta		181	100			Feces	
795	fl-bakteeri,värjäys(jorvinpyyntö)		335	100			Vaginal discharge	
796	m.tuberculosis-herkistyneetsolut,gammainterferoni,eritys,verestä(igra)␤		190	100				
797	mycobacterium,viljelyjavärjäys		275	100				
798	mycobacterium,viljelyjavärjäys,yskös		267	100				
799	mycobacterium,värjäysjaviljely,punktionäytteetjakudospalat		171	100				
800	mycobacteriumtuberculosis,nuklh.os.(kval)		144	100				
801	mycobacteriumtuberculosis,värjäys		205	100				
802	mycobacteriumtuberculosis-herkistyn.solut,tb1antigeeni	iu/ml	6	0				
803	mycobacteriumtuberculosis-herkistyn.solut,tb1antigeeni		171	100				
804	mycobacteriumtuberculosis-herkistyn.solut,tb2antigeeni	iu/ml	7	0				
805	mycobacteriumtuberculosis-herkistyn.solut,tb2antigeeni		171	100				
806	mycobacteriumtuberculosis-herkistyneetsolut,gammainterferoni,eritys		162	100				
807	mycobakteriumtuberculosis-her	iu/ml	15	0				
808	mycobakteriumtuberculosis-her		719	100				
809	ps-streptokokki,jatkoviljely(seulottunäyte)		125	100			Pharyngeal secretion	
810	pu-bakteeri,viljely(aerobiviljely,pintamärkä)		198	100			Pus	
811	pu-bakteeri,viljely1(aerobitjaanaerobitsyvän		132	100			Pus	
812	pu-bakteeri,viljely1(anaerobi+aerobiviljely,		1135	100			Pus	
813	pu-bakteeri,viljely1(anaerobi-jaaerobiviljelysekävärjäys)		634	100			Pus	
814	pu-bakteeri,viljely1(punk,kudos,ymsyvät)		438	100			Pus	
815	pu-bakteeri,viljely1(punktio-,kudos-,syvänäyt		125	100			Pus	
816	pu-bakteeri,viljely1anaerobi+aerobi(syvämärkä,		163	100			Pus	
817	pu-bakteeri,viljely2(aerobitpintamärästä)		205	100			Pus	
818	pu-bakteeri,viljely2(aerobiviljely)␤		405	100			Pus	
819	pu-bakteeri,viljely2(aerobiviljely,pintamärkä)		1727	100			Pus	
820	pu-bakteeri,viljely2(pintamärkä,iho,ym)		409	100			Pus	
821	pu-bakteeri,viljely2(pintamärkä,ihoyms.)		302	100			Pus	
822	pu-bakteeri,viljely2aerobiviljely(pintamärkä,		114	100			Pus	
823	sieni,viljely(syväsieniviljely,sisältääväräjyksen)		109	100				
824	sienvi,viljely(pintasieniviljely,sisältäävärjäyksen)		375	100				
825	sk-sieni,viljely(pintasieniviljely,sisältäävärjäyksen)		356	100			Skin	
826	tuberkuloosibakteeri,värjäysjaviljely,muunäyte		190	100				
827	tuberkuloosibakteeri,värjäysjaviljely,ysköksestä		229	100				
828	u-bakteeri,jatkoviljely,herkkyydet		557	100			Urine	
829	u-bakteeri,jatkoviljely,seulottun{yt		175	100			Urine	
830	u-bakteeri,jatkoviljely,seulottunäyt		116	100			Urine	
831	u-bakteeri,jatkoviljely,seulottunäyte		9001	100			Urine	
832	u-bakteeri,jatkoviljelyseulottunäyte		666	100			Urine	
833	u-bakteeri,partikkelilask.jatko		4958	100			Urine	
834	u-bakteeri,viljely(virtsa)		1056	100			Urine	
835	u-bakteeri,viljely,seulottupositiivinen		108	100			Urine	
836	u-bakteeri,viljely,virtsa		353	100			Urine	
837	u-bakteeri,viljelytk(suupohja,kuusiokunnat,jik)		1024	100			Urine	
838	u-bakteeri,viljelyvirtsasta		5504	100			Urine	
839	u-bakteeri,virtsanäytteenjatkoviljely		3562	100			Urine	
840	u-bakteerijatkoviljely,seulottunäyte		4721	100			Urine	
841	u-bakteerintunnistusjaherkkyys		104	100			Urine	
842	u-bakteeriviljely,seulottunäyte,jatkoviljely		162	100			Urine	
843	virtsanbakteeriviljely,erikoisviljely		337	100				
844	virtsanjatkoviljely,seulottunäyte		183	100				

