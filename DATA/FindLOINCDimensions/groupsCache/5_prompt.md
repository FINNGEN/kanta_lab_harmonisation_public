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
Here is group 5 of the table. Infer the LOINC axes for every row.

row_id	TEST_NAME	UNIT	n	p_missing	deciles	LongName	prefix_meaning	suffix_meaning
210	-bordetellaparapertussis,nukleiinihappo		549	100				
211	-bordetellapertussis,nukleiinihappo(kval)		368	100				
212	-chlamydiapneumoniae,nukleiinihappo(kval)		414	100				
213	-dermatofyytti(silsasieni),nukleiinihappo		101	100				
214	-humaanimetapneumovirus,nukleiinihappo(kval)		243	100				
215	-legionellapneumophila,nukleiinihappo(kval)		105	100				
216	-metapneumovirus,nukleiinihappo(kval)		785	100				
217	-mycoplasmapneumoniae,nukleiinihappo(kval)		361	100				
218	-respiratorisetmikrobit,nukleiinihappo		643	100				
219	bordetellaparapertussis,nukleiinihappo(kval)		376	100				
220	bordetellaparapertussis,nukleiinihappoosoitus		603	100				
221	bordetellaparapertussisnukle		565	100				
222	bordetellaparapertussisnukleiinihappo(kval)		177	100				
223	bordetellapertussis,nukleiin		109	100				
224	bordetellapertussis,nukleiinihaponosoit.(kval)		318	100				
225	bordetellapertussis,nukleiinihappo,(kval)		155	100				
226	bordetellapertussis,nukleiinihappoosoitus		603	100				
227	chlamydiapneumoniae,nukleiinihappo(kval)		308	100				
228	chlamydiapneumoniae,nukleiinihappoosoitus		603	100				
229	chlamydiapneumoniae,nukleiiniohaponosoitus(pcr)		309	100				
230	cryptosporidiumspp.,nukleiinihappo-osoitus		141	100				
231	cryptosporidiumspp.nukleiinihappo		319	100				
232	cyclosporacayetanensis,nukleiinihappo		319	100				
233	dermatofyytit,nukleiinihappo		246	100				
234	dermatofyytit,nukleiinihappo(kval)		192	100				
235	dientamoebafragilis,nukleiinihappo		319	100				
236	dientamoebafragilis,nukleiinihappo-osoitus		110	100				
237	entamoebahistolytica,nukleiinihappo		319	100				
238	entamoebahistolytica,nukleiinihappo-osoitus		110	100				
239	epidermophytonfloccosum,nukleiinihappo(kval)		149	100				
240	f-cryptosporidiumspp.,nukleiinihappo(kval)		346	100			Feces	
241	f-cryptosporidiumspp.nukleiinihappo(kval)		112	100			Feces	
242	f-cyclosporacayetanensis,nukleiinihappo(kval)		401	100			Feces	
243	f-dientamoebafragilis,nukleiinihappo		202	100			Feces	
244	f-eaec(enteroaggregatiivinene.coli),nukleiinihappo(kval)		398	100			Feces	
245	f-entamoebahistolytica,nukleiinihappo		330	100			Feces	
246	f-entamoebahistolytica,nukleiinihappo(kval)		345	100			Feces	
247	f-entamoebahistolytica,nukleiinihappo-osoitus		222	100			Feces	
248	f-entamoebahistolyticanukl.haponosoitus		182	100			Feces	
249	f-entamoebahistolyticanukleiinihappo(kval)		115	100			Feces	
250	f-epec(enteropatogeeninene.coli),nukleiinihappo(kval)		387	100			Feces	
251	f-giardialamblia,nukleiinihappo		293	100			Feces	
252	f-giardialamblia,nukleiinihappo(kval)		352	100			Feces	
253	f-giardialamblia,nukleiinihappo-osoitus		222	100			Feces	
254	f-giardialamblianuk.hapososoitus		182	100			Feces	
255	f-giardialamblianukleiinihappo		155	100			Feces	
256	f-giardialamblianukleiinihappo(kval)		117	100			Feces	
257	f-ulosteenparasiitit,nukleiinihappo(kval)		313	100			Feces	
258	f-vibrioparahaemolyticus,nukleiinihappo(kval)		343	100			Feces	
259	f-vibriovulnificus,nukleiinihappo(kval)		343	100			Feces	
260	f-viruspatogeenit,nukleiinihappo(kval)		804	100			Feces	
261	giardialamblia,nukleiinihappo		318	100				
262	giardialamblia,nukleiinihappo-osoitus		202	100				
263	haemophilusinfluenzae,nukleiinihappo(kval)		408	100				
264	haemophilusinfluenzaenukleiinihappo(kval)		154	100				
265	humaanimetapneumovirus,nukleiinihappo(kval)		236	100				
266	legionellapneumoniaenukleiinihappo(kval)		185	100				
267	microsporumcanis,nukleiinihappo(kval)		119	100				
268	mycoplasmapneumoniae,nukleiinihaponosoit(kval)		309	100				
269	mycoplasmapneumoniae,nukleiinihappo(kval)		407	100				
270	mycoplasmapneumoniae,nukleiinihappoosoitus		603	100				
271	p-hepatiittic,iggvasta-aineetjanukleiinihappo,(kvant)		227	100			Plasma	
272	respiratorisetmikrobit,nukleiinihappo(kval)		449	100				
273	seksivälitteisetmikrobit,nukleiinihappo(kval)		139	100				
274	streptococcuspneumoniae,nukleiinihappo(kval)		443	100				
275	streptococcuspneumoniaenukleiinihappo(kval)		154	100				
276	trichophytonrubrum,nukleiinihappo(kval)		132	100				
277	ulosteenparasiitit,nukleiinihappo(kval)		155	100				
278	ulosteenparasiitit,nukleiinihappo-osoitus		492	100				

