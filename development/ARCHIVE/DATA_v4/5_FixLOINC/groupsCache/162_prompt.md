[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

**Those guesses exist only to fetch the candidate list. They have already done their job, and they carry no authority over your decision.** The earlier pass was told to write a name whenever the code gave it anything at all to work with, because a near-miss still retrieves the right neighbourhood of concepts while silence retrieves nothing. So a guess may be a careful reading or a shot in the dark, and nothing marks which. Use it as a pointer to where in the vocabulary to look, never as an answer to confirm. **Decide from the row's own `TEST_NAME`, `LongName`, `UNIT` and `value_deciles`.** When the row's evidence and the guess disagree, the row wins.

Your task: for each row, decide **which real OMOP concept the code actually maps to**, choosing from a list of genuine LOINC concepts retrieved for this group, and return that concept's `omop_concept_id`.

You are the step that turns a plausible-sounding name into a real, usable identifier. Nothing downstream can tell a confidently wrong concept id from a correct one, so an id you are not willing to defend is worse than no id at all.

# The Finnish laboratory coding system

Each national lab test has a 4-digit running number code and a short mnemonic abbreviation of at most 10 characters, built as:

    <system prefix> - <test abbreviation> [<suffix>]

- The **system prefix** is a 1-2 letter code for the specimen the sample came from, mostly from English words: `S` = serum, `P` = plasma, `B` = blood, `U` = urine, `Li` = cerebrospinal fluid, `F` = feces, `Ts` = tissue, `Pt` = patient (a whole-patient investigation), `fS`/`fP`/`fB` = fasting serum/plasma/blood, `dU` = 24-hour urine, `E` = erythrocyte, `L` = leukocyte.
- The **test abbreviation** is a mnemonic of the test's long Finnish name, occasionally an established international one (`CRP`, `TSH`).
- The optional **suffix** qualifies the result type or method: `-O` (qualitative/semi-quantitative), `-Ab` (antibodies), `-Ag` (antigen), `-Vi` (culture), `-Nh` (nucleic acid), `-Ion` (ionized), `-V` (free/unconjugated).

Finnish compounds run together: "transferriininrautakyllästeisyys" = transferrin iron saturation.

# What you are given

**The candidate table** — real OMOP LOINC concepts, found by running every guessed name in this group through a semantic search over the LOINC vocabulary and pooling the results. The candidates are pooled and deduplicated **across the whole group**, so a concept retrieved by one row's guess is offered to every row: sibling codes in a group are near-identical strings, and the right concept for one row is often the one another row's guess found. Columns:

- `omop_concept_id` — the id to return. Copy it digit for digit.
- `omop_concept_name` — the concept's real LOINC Long Common Name, as OMOP spells it today.
- `score` — how semantically close this concept was to the closest guess in the group, 0 to 1. **A high score only means the guess and the concept read alike.** The guess itself may have been wrong, so a 0.95 candidate for a misread code is a confident route to the wrong concept. Treat `score` as "the search found this", never as "this is correct".
- `top2000` — the concept's rank in the **LOINC Top 2000+ Lab Observations (SI edition)**: the ~2000 codes Regenstrief publishes as the recommended mapping targets, covering ~99.8% of the test volume of three large laboratory organisations. The SI edition is the relevant one here, since Finland reports in molar/SI units. Empty means the concept is not on the list.

**The rows table** — one row per local lab test/unit combination:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty, and may be wrong.
- `unit_share` — what percentage of this `TEST_NAME`'s records carry this row's `UNIT`.
- `n` — number of records.
- `value_missing_p` — percentage (0-100) of records with no numeric value.
- `value_deciles` — the 9 deciles of observed values, when available.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess, which is what the search was run on. A search query, not a hypothesis you owe any deference to: it was written under instructions to guess rather than stay silent, so its confidence is not calibrated and a fluent name may rest on very little. When it is a panel name, the earlier pass judged the code to order a bundle rather than report one result — check that against the code yourself.

# How to read the evidence

A row is one **`TEST_NAME` + `UNIT`** combination, and that pair is what you are naming. Two rows of the same code with different units are two different observations and may well belong to two different LOINC concepts. Decide each row on its own.

**The name is the source of truth.** `prefix_meaning` and `suffix_meaning` were derived from the `TEST_NAME` string by an earlier step, so when a name is misspelled, truncated or locally invented, the decoded prefix and suffix are wrong in exactly the same way. Treat them as extra information that can confirm what the name says — never as something that outranks it. The specimen in particular is often spelled out as a Finnish word rather than carried by a prefix: `veri` = blood, `seerumi` = serum, `plasma` = plasma, `virtsa` = urine, `likvori` = cerebrospinal fluid, `uloste` = feces, `sylki` = saliva. `c-reaktiivinenproteiini,pikatesti,veri` names blood and has no decoded prefix at all — and its leading `c-` is the start of "C-reactive", not a specimen code.

**Missing values are not evidence.** `value_missing_p` describes this extract, not the laboratory test: a row with no values is a row where the numbers were not recorded or not carried through. Never conclude "no numbers, therefore qualitative". A test is qualitative when the CODE says so — the `-O` suffix, a `LongName` naming a qualitative or screening test, a component only ever reported as detected/not-detected.

**Never borrow from another row.** The rows are grouped by string similarity of `TEST_NAME`, so a group is a bag of codes that merely look alike. A neighbouring row's unit is not evidence about this row, and the same code can also appear in another group carrying units you cannot see here — so the units visible around you are not the units this code uses. Do not take a unit, a quantity or an answer from a sibling row, not even from a row whose `TEST_NAME` is identical.

**What you may conclude depends on what the row actually has.** The `evidence_level` column states it. Every row has a name; the label says what is there *in addition*:

| `evidence_level` | what the row has | what you may do |
|---|---|---|
| `name+unit+values` | a unit and a value distribution | The strongest case. If the values contradict the unit, distrust the **unit** — units are typed by hand at hundreds of source systems and are often wrong, especially at a low `unit_share` — and decide as if the unit were absent. |
| `name+unit` | a unit, no values | Trust the unit. It is the only quantity evidence there is, and it is usually right. |
| `name+values` | values, no unit | Read the quantity off the magnitudes. Creatinine at 60-110 is µmol/l and takes `[Moles/volume]`; the same analyte at 0.6-1.2 is mg/dl and takes `[Mass/volume]`. |
| `name` | neither | **You cannot fix the quantity.** Do not guess one and do not copy a sibling. Choose a concept only when the name alone settles it — a panel, which carries no property at all, or an analyte that has exactly one LOINC form. Otherwise **leave `omop_concept_id` empty**. An honest gap is worth more than a concept resting on nothing. |

**Some units are ratios, not concentrations.** `mmol/mol` is HbA1c IFCC, a substance ratio. `mg/mmol` is an albumin/creatinine ratio. `ml/min/173m2` is eGFR, a rate per body surface area. `%` is ambiguous by nature: it may be a fraction of a cell population, a fraction of a total mass, or activity as a percentage of normal.

**A repeated lowest decile is a detection limit, not a measurement.** When the first deciles are the same round number — `[5, 5, 6.2, 8.3, ...]` — the assay is censored at that floor and everything below was reported as "<5". Read the floor as the assay's sensitivity rather than the population's real low end: a CRP censored at 5 mg/l is an ordinary CRP, while a high-sensitivity assay reads down to about 0.1 mg/l, so that floor argues *against* a high-sensitivity concept.

# How to decide

For each row:

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `value_deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
2. **Pick the candidate that matches that reading**, and return its `omop_concept_id`. The unit and the values decide between candidates that differ only in property: `mmol/l` takes `[Moles/volume]`, `g/l` takes `[Mass/volume]`, `U/l` takes `[Enzymatic activity/volume]`. The specimen comes from the name — a decoded prefix where there is one, a Finnish specimen word otherwise; LOINC's `Serum or Plasma` is the right term for most routine chemistry, and fasting is not part of the specimen (`fS` is still serum).
3. **Precision must be earned by the name.** LOINC holds both a plain and a qualified concept for most tests. Take the **more precise** candidate whenever the row's name positively states the qualifier — `-Vi` really does say culture, `pikatesti` really does say a rapid test, `dU` really does say a 24-hour collection, `herkka` really does say high sensitivity. Take the plainer candidate when the name does not state it.

   The error to avoid is **inventing** a qualifier, not being specific. Measured against the curated Finnish mappings, this step added a method the reference leaves blank 59 times (usually `Automated count` on a bare blood-count code), took `--trough` variants for plain drug levels, and narrowed `Serum or Plasma` to `Capillary blood` on codes that said no such thing. Of every qualifier you are about to accept, ask: **which characters of this code say so?** If you cannot point at them, take the plainer concept.
4. **A guess that is itself a real concept is weak evidence, never an instruction.** If `loinc_name_guess` appears in the candidate table as an exact name at a score of 1.000, the earlier pass — reading this same row — happened to write the exact name of a concept that exists. That is mildly reassuring and nothing more: the earlier pass writes a name for almost every code it can read anything out of, so landing on a real name can be recognition or coincidence. Never adopt a candidate *because* it equals the guess. Take a different candidate, including a more precise one, whenever the row's own name, unit and values support it better — and take none at all if none fits, however well the guess matched.
5. **When two or more candidates still fit equally well**, prefer a candidate with a `top2000` rank. That list is LOINC's own recommendation for what laboratories should map to, so a concept on it is the intended target and a near-duplicate off it usually is not. It breaks ties and nothing more: a top-2000 concept in the wrong specimen or the wrong units is still the wrong answer.
6. **Leave `omop_concept_id` empty when no candidate is right.** That is a correct, useful answer — it says "this code has no match in what the search returned", which is a fact the next iteration can act on. Common reasons: the code is too truncated or garbled to identify; it is a local administrative or non-laboratory code; or the search simply did not return the concept you know is right.
7. **Never return an id that is not in the candidate table.** Not one you remember, not one you derive from a LOINC code, not a plausible-looking number. Ids that are not in the table are discarded and the row is logged as unanswered, so inventing one only loses the row.

Specific things to watch:

- **A panel is not its components.** If the code orders a bundle, the answer is a panel concept, not one of the bundled analytes: `B-PVK` (perusverenkuva, the basic blood count) and `B-TVK` (taydellinen verenkuva, the complete count with differential) are panels, not hemoglobin. Match the panel's breadth to the code: a basic count is not the same concept as a count with a differential. Conversely, do not map a single reported result to a panel concept just because a panel candidate scored well.
- **Deprecated near-duplicates are already filtered out** of the candidate list — every candidate is a standard, current concept — so you never need to judge validity, only fit.
- **The group is a bag of look-alike codes, not a set of equivalent ones.** It was built by string similarity, so it mixes genuinely different tests whose names happen to resemble each other. Answer every row from its own name, unit and values; never give rows one id because they sit together.
- **A row whose guess was empty can still be mapped** — the pooled list may hold the concept its own name points to. Map it on that row's own evidence, though, never because a neighbouring row was mapped there.

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `omop_concept_id` — the chosen concept's id, copied from the candidate table. Empty if no candidate is right.
- `omop_concept_name` — that candidate's `omop_concept_name`, copied verbatim. Used only to cross-check that the id you copied is the concept you meant; leave it empty when the id is empty.

Then justify and grade what you chose:

- `reasoning` — why each part of the name you chose is right, as **one clause per part, separated by ` ; `**. Each clause names the part and then the evidence it rests on, pointing at the specific characters of the row that carry it. Cover the component, the bracketed property, the specimen, and the method when the name has one. Keep it terse — this is a justification trail, not prose:

      <component> bcs <evidence> ; <[property]> bcs <evidence> ; in <system> bcs <evidence> ; by <method> bcs <evidence>

  Where a part rests on nothing in the row, say that instead of inventing a reason — "no specimen stated in the code" is a useful thing for a reader to find here.

  **When you choose no concept, `reasoning` still matters — it is the only thing you leave behind.** Say what blocked you, specifically: the code is too garbled to identify; it is not a laboratory test; the search returned nothing for this analyte; the candidates were all the wrong specimen; the evidence cannot settle the quantity. "Nothing fitted" is not an answer. A reader must be able to tell a code that is unidentifiable from one the search simply failed on, because those need opposite fixes.
- `certainty` — `high`, `medium` or `low`: how sure you are, on all the evidence together, that this concept is the right one for this row. Weigh the parts by what a wrong answer would cost: a doubtful analyte makes the mapping useless, while an unstated method is a smaller error. A row whose `evidence_level` is `name` should rarely be `high`, since nothing fixes its quantity. Use `low` freely — these are read downstream to decide which mappings can be trusted without review, so a `high` you cannot defend is worse than an honest `low`. Leave it empty when you chose no concept.

Return an entry for EVERY row, including ones you leave unmapped.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which rows you could map and which you could not, where the candidate list was missing the concept you knew was right, where the earlier pass's guess sent the search astray, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 162.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3001490 | Nucleated erythrocytes [#/volume] in Blood | 1.000 |  |
| 3011325 | HIV 1+2 Ab [Presence] in Serum | 1.000 | 442 |
| 3013115 | Eosinophils [#/volume] in Blood | 1.000 | 67 |
| 3014051 | Protein [Presence] in Urine by Test strip | 1.000 | 99 |
| 3017732 | Neutrophils [#/volume] in Blood | 1.000 | 57 |
| 3023383 | Lactate [Moles/volume] in Pleural fluid | 1.000 |  |
| 3035350 | Ketones [Presence] in Urine by Test strip | 1.000 | 102 |
| 3047181 | Lactate [Moles/volume] in Blood | 1.000 | 475 |
| 3034979 | HIV 1+2 IgG Ab [Presence] in Serum | 0.975 |  |
| 3046555 | Borrelia burgdorferi Ab [Units/volume] in Serum by Immunoblot | 0.971 |  |
| 3046976 | DPYD gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.962 |  |
| 3009055 | F5 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.958 | 428 |
| 3013906 | HIV 1 Ab [Presence] in Serum | 0.958 | 1611 |
| 36303442 | Epithelial cells [#/volume] in Urine by Automated | 0.955 |  |
| 40760844 | Ketones [Presence] in Urine by Automated test strip | 0.945 |  |
| 3019077 | Protein [Presence] in 24 hour Urine by Test strip | 0.943 |  |
| 3047166 | Epithelial cells [#/area] in Urine sediment by Automated count | 0.943 |  |
| 3003974 | HIV 1 IgG Ab [Presence] in Serum | 0.942 |  |
| 3035695 | Borrelia burgdorferi IgM Ab [Units/volume] in Serum by Immunoassay | 0.941 | 528 |
| 3001463 | Borrelia burgdorferi IgG Ab [Units/volume] in Serum by Immunoassay | 0.940 | 1968 |
| 3016888 | Borrelia burgdorferi IgG Ab [Units/volume] in Serum | 0.938 | 1967 |
| 3008230 | Borrelia burgdorferi IgM Ab [Units/volume] in Serum | 0.938 |  |
| 3046498 | JAK2 gene p.Val617Phe [Presence] in Blood or Tissue by Molecular genetics method | 0.938 | 1692 |
| 40760845 | Protein [Presence] in Urine by Automated test strip | 0.935 |  |
| 3004391 | Epithelial cells [#/volume] in Urine by Manual count | 0.933 |  |
| 3035962 | HIV 1+2 Ab [Presence] in Serum or Plasma by Immunoassay | 0.931 | 324 |
| 3032287 | HIV 1+2 Ab [Presence] in Specimen | 0.929 |  |
| 3029879 | Epithelial cells.squamous [#/volume] in Urine by Automated count | 0.928 |  |
| 1091714 | HIV 1+2 Ab+HIV1 p24 Ag [Presence] in Serum or Plasma | 0.928 |  |
| 3028129 | Nucleated erythrocytes [#/volume] in Body fluid | 0.923 |  |
| 3002385 | Erythrocyte distribution width [Ratio] | 0.922 |  |
| 3044883 | Borrelia burgdorferi IgG+IgM Ab [Units/volume] in Serum | 0.921 | 410 |
| 3053246 | HIV 1+O+2 Ab [Presence] in Serum or Plasma | 0.921 | 202 |
| 3030306 | Epithelial cells.non-squamous [#/volume] in Urine by Automated count | 0.919 |  |
| 1616424 | Nucleated erythrocytes [#/volume] in Cord blood | 0.918 |  |
| 3028615 | Eosinophils [#/volume] in Blood by Automated count | 0.917 | 50 |
| 3039234 | HIV 1+2 IgG Ab [Presence] in Serum or Plasma by Immunoassay | 0.917 |  |
| 3009932 | Eosinophils [#/volume] in Blood by Manual count | 0.914 |  |
| 3007238 | Nucleated erythrocytes [#/volume] in Blood by Automated count | 0.913 | 1247 |
| 42870589 | Drugs of abuse panel - Urine by Screen method | 0.911 |  |
| 3033106 | HIV 1 p24 Ab [Presence] in Serum | 0.911 |  |
| 3000850 | Epithelial cells [#/volume] in Urine | 0.911 |  |
| 3028893 | Ketones [Presence] in Urine | 0.910 | 217 |
| 40761539 | Cells [Type] in Urine sediment by Light microscopy | 0.910 |  |
| 3045857 | Borrelia burgdorferi IgM Ab [Units/volume] in Cerebral spinal fluid by Immunoblot | 0.909 |  |
| 3006135 | Nucleated erythrocytes [#/volume] in Blood by Manual count | 0.908 | 501 |
| 3028271 | Lactate [Moles/volume] in Capillary blood | 0.907 |  |
| 3003645 | Borrelia burgdorferi Ab [Units/volume] in Serum by Immunoassay | 0.907 |  |
| 3013650 | Neutrophils [#/volume] in Blood by Automated count | 0.906 | 46 |
| 3038774 | Borrelia burgdorferi 49736 IgG Ab [Units/volume] in Serum by Immunoassay | 0.905 |  |
| 3039950 | Borrelia burgdorferi 49736 IgM Ab [Units/volume] in Serum by Immunoassay | 0.903 |  |
| 3008037 | Lactate [Moles/volume] in Venous blood | 0.903 |  |
| 3018405 | Lactate [Moles/volume] in Arterial blood | 0.902 | 1277 |
| 40765008 | Erythrocyte distribution width [Ratio] in Blood from Fetus by Automated count | 0.902 |  |
| 3044453 | Borrelia burgdorferi IgA Ab [Units/volume] in Serum by Immunofluorescence | 0.900 |  |
| 3021257 | Drugs of abuse 5 panel - Urine | 0.899 |  |
| 3021182 | F7 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.899 |  |
| 3011836 | F2 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.899 | 1056 |
| 3025090 | Borrelia burgdorferi Ab [Units/volume] in Serum | 0.899 |  |
| 3038346 | JAK2 gene.p.Val617Phe mutant/Normal in Blood or Tissue by Molecular genetics method | 0.898 |  |
| 3000535 | Borrelia burgdorferi IgG Ab [Presence] in Serum by Immunoblot | 0.895 |  |
| 3004825 | Lactate [Moles/volume] in Body fluid | 0.894 |  |
| 40762125 | Lactate [Mass/volume] in Blood | 0.893 |  |
| 3031042 | Nucleated cells [#/volume] in Blood | 0.893 |  |
| 3029162 | Epithelial cells.squamous [#/area] in Urine sediment by Automated count | 0.893 |  |
| 3032084 | Eosinophils [#/volume] in Body fluid | 0.892 |  |
| 3041491 | F9 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.892 |  |
| 3014111 | Lactate [Moles/volume] in Serum or Plasma | 0.890 | 346 |
| 43054967 | JAK2 gene p.Val617Phe [Presence] in Bone marrow by Molecular genetics method | 0.889 |  |
| 3000330 | Specific gravity of Urine by Test strip | 0.889 | 71 |
| 3032917 | Immature eosinophils [#/volume] in Blood | 0.887 |  |
| 3020059 | Calcium [Moles/volume] corrected for albumin in Serum or Plasma | 0.887 | 237 |
| 3005897 | Protein [Mass/volume] in Urine by Test strip | 0.886 | 74 |
| 3017501 | Neutrophils [#/volume] in Blood by Manual count | 0.886 |  |
| 3015338 | F8 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.886 |  |
| 3015586 | Segmented neutrophils [#/volume] in Blood | 0.884 |  |
| 3023539 | Ketones [Mass/volume] in Urine by Test strip | 0.884 |  |
| 40761064 | DPYD2A gene targeted mutation analysis [Presence] in Blood or Tissue by Molecular genetics method | 0.884 |  |
| 3004064 | Calcium [Moles/volume] corrected for total protein in Serum or Plasma | 0.883 |  |
| 3037185 | Protein [Presence] in Urine | 0.883 |  |
| 3008116 | Ketones [Moles/volume] in Urine by Test strip | 0.882 | 80 |
| 3046321 | Neutrophils [#/volume] in Body fluid | 0.878 |  |
| 3041412 | Epithelial cells.non-squamous [#/area] in Urine sediment by Automated count | 0.878 |  |
| 3020410 | Lactate [Moles/volume] in Arterial plasma | 0.877 |  |
| 3035715 | Granulocytes [#/volume] in Blood | 0.876 | 2002 |
| 3049383 | Erythrocyte distribution width [Ratio] in Cord blood | 0.875 |  |
| 40768439 | Drugs of abuse 5 panel - Urine by Screen method | 0.875 |  |
| 40759053 | Lactate [Moles/volume] in Cord blood | 0.874 |  |
| 40765176 | Nucleated erythrocytes [#/volume] in Body fluid by Automated count | 0.872 |  |
| 3009179 | Lactate [Moles/volume] in Peritoneal fluid | 0.872 |  |
| 44787047 | Eosinophils [#/volume] in Cord blood | 0.871 |  |
| 3030905 | Polymorphonuclear cells [#/volume] in Blood | 0.871 |  |
| 40766103 | Ketones [Presence] in Urine by Test strip --1 hour post dose glucose | 0.868 |  |
| 3005491 | Lactate [Moles/volume] in Plasma venous | 0.868 | 1070 |
| 1091265 | DPYD gene.c.1236G>A [Presence] in Blood or Tissue by Molecular genetics method | 0.866 |  |
| 40765009 | Nucleated erythrocytes [#/volume] in Blood from Fetus by Automated count | 0.865 |  |
| 3026361 | Erythrocytes [#/volume] in Blood | 0.865 |  |
| 3006032 | Nucleated erythrocytes [#/volume] in Body fluid by Manual count | 0.864 | 991 |
| 1091601 | Epithelial cells [#/area] in Urine sediment | 0.863 |  |
| 1259496 | DPYD gene.c.2846A>T [Presence] in Blood or Tissue by Molecular genetics method | 0.862 |  |
| 1259714 | DPYD gene.c.1679T>G [Presence] in Blood or Tissue by Molecular genetics method | 0.862 |  |
| 3010813 | Leukocytes [#/volume] in Blood | 0.861 | 33 |
| 3015182 | Erythrocyte distribution width [Entitic volume] by Automated count | 0.861 |  |
| 3001019 | Free T4 and TSH panel - Serum or Plasma | 0.860 |  |
| 46236300 | FUS gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.859 |  |
| 3005176 | Neutrophils [#/volume] in Urine | 0.857 |  |
| 3028886 | FANCC gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.857 |  |
| 3016347 | F5 gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.856 |  |
| 1259589 | DPYD gene.c.1905+1G>A [Presence] in Blood or Tissue by Molecular genetics method | 0.856 |  |
| 3047107 | Calcium [Mass/volume] corrected for albumin in Serum or Plasma | 0.855 |  |
| 1001873 | DPYD gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.855 |  |
| 3046841 | FBN2 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.854 |  |
| 40766104 | Ketones [Presence] in Urine by Test strip --3 hours post dose glucose | 0.853 |  |
| 43534057 | CYP2E1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.852 |  |
| 3015816 | F5 gene p.Arg506Gln [Presence] in Blood or Tissue by Molecular genetics method | 0.852 |  |
| 40762031 | LCT gene mutations found [Type] in Blood or Tissue by Molecular genetics method | 0.852 |  |
| 3039904 | Epithelial cells.renal [#/volume] in Urine by Computer assisted method | 0.850 |  |
| 3015774 | Calcium.ionized [Moles/volume] in Serum or Plasma by calculation | 0.850 |  |
| 40766105 | Ketones [Presence] in Urine by Test strip --4 hours post dose glucose | 0.849 |  |
| 3018199 | Band form neutrophils [#/volume] in Blood | 0.848 | 199 |
| 3029937 | Albumin [Presence] in Urine by Test strip | 0.848 |  |
| 3043088 | Ketones [Presence] in 24 hour Urine | 0.847 |  |
| 3038720 | Eosinophils [#/volume] in Body fluid by Manual count | 0.847 |  |
| 3006315 | Basophils [#/volume] in Blood | 0.846 | 121 |
| 36303968 | JAK2 gene.p.Val617Phe mutant/Normal in Bone marrow by Molecular genetics method | 0.846 |  |
| 648345 | JAK2 gene.p.Val617Phe mutant/Normal in Specimen by Molecular genetics method | 0.844 |  |
| 43534055 | UGT2B15 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.844 |  |
| 3009261 | Glucose [Presence] in Urine by Test strip | 0.843 | 309 |
| 3048870 | JAK2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.843 |  |
| 3030597 | Calcium [Mass/volume] corrected for total protein in Serum or Plasma | 0.843 |  |
| 40758430 | JAK2 gene exon 13 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.843 |  |
| 46235808 | Reticulocyte distribution width [Ratio] in Blood by calculation | 0.842 |  |
| 21494670 | JAK2 gene exon 14 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.840 |  |
| 40758429 | JAK2 gene exon 12 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.839 |  |
| 43533384 | Drugs of abuse panel - Blood by Screen method | 0.838 |  |
| 3002431 | Phytonadione [Mass/volume] in Serum or Plasma | 0.838 |  |
| 44786662 | ABCB1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.838 |  |
| 3040873 | UGT1A1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.838 |  |
| 3009015 | Lactate [Moles/volume] in Synovial fluid | 0.837 |  |
| 3049410 | CYP2D6 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.837 |  |
| 3032072 | Eosinophils [#/volume] in Pleural fluid | 0.836 |  |
| 3005089 | MTHFR gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.836 | 1341 |
| 3015377 | Calcium [Moles/volume] in Serum or Plasma | 0.836 | 12 |
| 3043107 | Immature eosinophils [#/volume] in Blood by Manual count | 0.836 |  |
| 36305828 | Drugs of abuse screen W Reflex confirm panel - Urine | 0.835 |  |
| 3030676 | VKORC1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.835 |  |
| 3010908 | Cytology study comment Cervical or vaginal smear or scraping Cyto stain | 0.835 | 945 |
| 3001099 | RB1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.835 |  |
| 3039264 | MT-TK gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.834 |  |
| 3966445 | Human papilloma virus cytology and high-risk genotypes panel - Cervix | 0.834 |  |
| 1175703 | Drugs of abuse panel - Body fluid | 0.833 |  |
| 3016220 | Menadione [Mass/volume] in Serum or Plasma | 0.833 |  |
| 40762018 | LCT gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.833 |  |
| 3039919 | Specific gravity of Urine by Automated test strip | 0.832 |  |
| 36660277 | F2 gene.c.20210G>A and c.1691G>A panel - Blood or Tissue by Molecular genetics method | 0.829 |  |
| 3029872 | Protein [Mass/volume] in Urine by Automated test strip | 0.828 |  |
| 1175900 | Thyroxine and Thyroxine.free panel - Serum or Plasma | 0.825 |  |
| 40758548 | Home drug screening panel - Urine | 0.825 |  |
| 3033521 | Obstetric 1996 panel - Serum and Blood | 0.824 |  |
| 1616736 | Protein/Creatinine Qualitative in Urine by Test strip | 0.824 |  |
| 3049461 | Calcium [Moles/volume] corrected for total protein in Blood | 0.824 |  |
| 3025008 | F2 gene c.20210G>A [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.823 | 470 |
| 1259630 | DPYD gene.c.1679T>G [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.821 |  |
| 1259665 | DPYD gene.c.2846A>T [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.820 |  |
| 1091308 | DNMT3A gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.819 |  |
| 36660607 | Microalbumin [Presence] in Urine by Test strip | 0.817 |  |
| 3030784 | F13A1 gene p.Val34Leu [Presence] in Blood or Tissue by Molecular genetics method | 0.816 |  |
| 1175629 | Drugs of abuse panel - Hair | 0.816 |  |
| 40766152 | JAK2 gene exon 12 mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.815 |  |
| 40757581 | CYP2C9 and VKORC1 panel - Blood or Tissue by Molecular genetics method | 0.815 |  |
| 40762140 | F5 gene p.His1299Arg [Presence] in Blood or Tissue by Molecular genetics method | 0.815 |  |
| 3039049 | Pharmacogenetic DNA analysis panel | 0.813 |  |
| 3050380 | Cytology report of Cervical or vaginal smear or scraping Cyto stain | 0.813 | 798 |
| 3039417 | Platelet distribution width [Ratio] in Blood | 0.811 |  |
| 3033110 | Human papilloma virus high and Low risk DNA panel - Cervix | 0.809 |  |
| 3043090 | Cervical AndOr vaginal cytology study | 0.804 |  |
| 3039059 | Drugs of abuse 7 and Alcohol and Tricyclics panel - Urine by Screen method | 0.804 |  |
| 3035999 | Lactate [Moles/volume] in Cerebral spinal fluid | 0.800 |  |
| 43534060 | CYP2D6 gene and CYP2C19 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.800 |  |
| 3050129 | First trimester maternal screen panel - Serum or Plasma | 0.799 |  |
| 3006906 | Calcium [Mass/volume] in Serum or Plasma | 0.798 |  |
| 3052990 | Drugs of abuse panel - Meconium | 0.798 |  |
| 3040757 | Calcium [Moles/volume] in Serum or Plasma --baseline | 0.795 |  |
| 37020870 | LPA gene.c.3947+467T>C [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.794 |  |
| 40761887 | Phytonadione [Moles/volume] in Serum or Plasma | 0.793 |  |
| 46236486 | CLRN1 gene c.144T>G [Presence] in Blood or Tissue by Molecular genetics method | 0.792 |  |
| 3966606 | Prenatal hepatitis B and C panel - Serum or Plasma | 0.792 |  |
| 3009762 | IgM [Presence] in Serum by Immunofixation | 0.788 |  |
| 3038231 | PYGM gene p.Arg50Ter+Gly205Ser [Presence] in Blood or Tissue by Molecular genetics method | 0.788 |  |
| 21493868 | CYP3A4 and CYP3A5 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.788 |  |
| 3043948 | Calcium [Moles/volume] in Serum or Plasma --pre XXX challenge | 0.786 |  |
| 36031337 | Human papilloma virus high-risk genotypes panel - Cervix by NAA with probe detection | 0.785 |  |
| 42868527 | FSHB gene c.-211G>T [Presence] in Blood or Tissue by Molecular genetics method | 0.785 |  |
| 3053322 | Second trimester quad maternal screen panel - Serum or Plasma | 0.782 |  |
| 3024865 | Alpha tocopherol [Mass/volume] in Serum or Plasma | 0.781 |  |
| 3048538 | Cryoglobulin type [Identifier] in Serum by Immunofixation | 0.781 |  |
| 3002736 | Platelet distribution width [Entitic volume] in Blood by Automated count | 0.780 | 1233 |
| 3049518 | Second trimester penta maternal screen panel - Serum or Plasma | 0.779 |  |
| 3007561 | Coenzyme Q10 [Mass/volume] in Serum or Plasma | 0.779 | 1181 |
| 40760890 | Thyroglobulin and Thyroglobulin Ab panel - Serum or Plasma | 0.778 |  |
| 3002888 | Erythrocyte distribution width [Entitic volume] | 0.778 |  |
| 43055134 | VKORC1 gene c.1173C>T [Presence] in Blood or Tissue by Molecular genetics method | 0.777 |  |
| 1002327 | Warfarin response genotype panel - Blood or Tissue by Molecular genetics method | 0.776 |  |
| 36305197 | Thyroglobulin and thyroperoxidase Ab panel - Serum or Plasma | 0.775 |  |
| 1091523 | IgM.kappa [Presence] in Serum by Immunofixation | 0.774 |  |
| 3026898 | HFE gene.p.Cys282Tyr [Presence] in Blood or Tissue by Molecular genetics method | 0.774 | 1479 |
| 3019897 | Erythrocyte [DistWidth] in Blood by Automated count | 0.773 | 24 |
| 3049793 | Tocopherols [Mass/volume] in Serum or Plasma | 0.773 |  |
| 3051704 | Genechip kit panel - Blood or Tissue by Molecular genetics method | 0.772 |  |
| 3033543 | Specific gravity of Urine | 0.772 | 122 |
| 46235518 | HTR2C gene c.-759C>T [Presence] in Blood or Tissue by Molecular genetics method | 0.770 |  |
| 3043043 | IgM.monoclonal [Presence] in Serum by Immunofixation | 0.769 |  |
| 3039275 | MT-TL1 gene m.3291T>C [Presence] in Blood or Tissue by Molecular genetics method | 0.768 |  |
| 3038534 | MT-ND6 gene m.14484T>C [Presence] in Blood or Tissue by Molecular genetics method | 0.768 |  |
| 42528602 | Human papilloma virus 16 and 18+45 E6+E7 mRNA panel - Cervix by NAA with probe detection | 0.767 |  |
| 3041626 | MT-TL1 gene m.3271T>C [Presence] in Blood or Tissue by Molecular genetics method | 0.767 |  |
| 3042593 | MT-TL1 gene m.3252T>C [Presence] in Blood or Tissue by Molecular genetics method | 0.766 |  |
| 1002160 | HTR2C gene c.-759C>T [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.766 |  |
| 44816563 | Monoclonal band observed [Identifier] in Serum or Plasma by Immunofixation | 0.766 |  |
| 21492686 | Pharmacogenomic analysis basic associated observations panel - Blood or Tissue | 0.766 |  |
| 3032628 | Second trimester triple maternal screen panel - Serum or Plasma | 0.766 |  |
| 1175464 | Levothyroxine absorption panel - Serum or Plasma | 0.765 |  |
| 3049172 | Sequence variation panel - Blood or Tissue by Molecular genetics method | 0.765 |  |
| 3011422 | Epithelial cells [Presence] in Urine sediment by Light microscopy | 0.763 | 151 |
| 36659869 | Psychotropic medication pharmacogenomic analysis in Blood or Tissue by Molecular genetics method | 0.762 |  |
| 46234830 | Other cells [#/volume] in Pleural fluid by Manual count | 0.762 |  |
| 3049122 | Sequencing methodology panel - Blood or Tissue by Molecular genetics method | 0.760 |  |
| 46234832 | Other cells/Leukocytes in Pleural fluid by Manual count | 0.760 |  |
| 3018425 | Cells [#/volume] in Pleural fluid by Manual count | 0.760 |  |
| 1091565 | IgM.lambda [Presence] in Serum by Immunofixation | 0.760 |  |
| 3019150 | Specific gravity of Urine by Refractometry | 0.758 |  |
| 36032166 | Retinol and Alpha tocopherol panel - Serum or Plasma | 0.758 |  |
| 3051971 | Cytology report of Cervical or vaginal smear or scraping Cyto stain.thin prep | 0.757 | 85 |
| 3046946 | IgG.monoclonal [Presence] in Serum by Immunofixation | 0.757 |  |
| 3024120 | Thiamine [Mass/volume] in Serum or Plasma | 0.753 | 1439 |
| 1092033 | Epithelial cells [Presence] in Urine sediment | 0.753 |  |
| 3026687 | IgG [Presence] in Serum by Immunofixation | 0.752 |  |
| 36305936 | Inhibin A and B panel - Serum or Plasma | 0.752 |  |
| 3042800 | 7-Dehydrocholesterol [Mass/volume] in Serum or Plasma | 0.750 |  |
| 3004030 | Dicoumarol [Mass/volume] in Serum or Plasma | 0.749 |  |
| 3032939 | Phenprocoumon [Mass/volume] in Serum or Plasma | 0.749 |  |
| 44816564 | Monoclonal band observed [Identifier] in Urine by Immunofixation | 0.749 |  |
| 40766218 | Epithelial cells.ciliated [Presence] in Bronchoalveolar lavage | 0.748 |  |
| 648148 | Epithelial cells [Presence] in Bronchial specimen by Light microscopy | 0.747 |  |
| 3006615 | Calciferol (Vit D2) [Mass/volume] in Serum or Plasma | 0.746 |  |
| 3028475 | Transitional cells [Presence] in Urine sediment by Light microscopy | 0.745 | 1317 |
| 3020508 | IgA [Presence] in Serum by Immunofixation | 0.745 |  |
| 3004588 | Protein electrophoresis panel - Serum or Plasma | 0.745 |  |
| 1988986 | Epithelial cells [Presence] in Bronchoalveolar lavage by Light microscopy | 0.745 |  |
| 3035191 | Cells Counted Total [#] in Pleural fluid | 0.744 |  |
| 40758283 | Biotinidase panel - Serum or Plasma | 0.743 |  |
| 646357 | Human papilloma virus 16 panel - Plasma cell-free DNA | 0.742 |  |
| 37019579 | Human papilloma virus DNA [Presence] in Genital specimen by NAA with probe detection | 0.742 |  |
| 3000593 | Cobalamin (Vitamin B12) [Mass/volume] in Serum or Plasma | 0.741 |  |
| 3026593 | Cytologist who read Cyto stain of Cervical or vaginal smear or scraping | 0.741 | 109 |
| 3044806 | Columnar cells/cells in Bronchial specimen | 0.740 |  |
| 3029511 | Human papilloma virus DNA [Presence] in Specimen by NAA with probe detection | 0.740 |  |
| 40761557 | Bladder cells [Presence] in Urine sediment by Light microscopy | 0.740 |  |
| 44787095 | Platelet distribution width [Entitic volume] in Cord blood by Automated count | 0.738 |  |
| 40766217 | Epithelial cells.squamous [Presence] in Bronchoalveolar lavage | 0.736 |  |
| 40761537 | Casts [Type] in Urine sediment by Light microscopy | 0.736 |  |
| 3043606 | Malignant cells/cells in Pleural fluid by Manual count | 0.735 |  |
| 3047355 | Malignant cells [#/volume] in Pleural fluid | 0.734 |  |
| 3040311 | Epithelial cells.non-squamous [Presence] in Urine sediment by Light microscopy | 0.733 |  |
| 40761535 | Cells panel - Urine sediment | 0.733 |  |
| 3032928 | Mesothelial cells [#/volume] in Pleural fluid | 0.732 |  |
| 37020529 | Human papilloma virus 31+33+35+39+45+51+52+56+58+59+66+68 DNA [Presence] in Genital specimen by NAA with probe detection | 0.731 |  |
| 3008325 | Epithelial cells.squamous [Presence] in Urine sediment by Light microscopy | 0.730 | 261 |
| 44816941 | Coenzyme Q10 [Moles/volume] in Serum or Plasma | 0.730 |  |
| 3032978 | Calcidiol and Calciferol panel - Serum or Plasma | 0.730 |  |
| 1259531 | Human papilloma virus 31+33+52+58 DNA [Presence] in Cervix by NAA with probe detection | 0.729 |  |
| 46236080 | Human papilloma virus 31+33+35+39+45+51+52+56+58+59+66+68 DNA [Presence] in Specimen by NAA with probe detection | 0.729 |  |
| 3032934 | Unidentified cells [#/volume] in Pleural fluid | 0.729 |  |
| 40758359 | Immunophenotyping study | 0.727 |  |
| 3037334 | Vitamin D+Metabolites [Mass/volume] in Serum or Plasma | 0.726 | 500 |
| 3009799 | Methylmalonate [Mass/volume] in Serum or Plasma | 0.726 |  |
| 21494138 | Phytanate and pristanate panel - Serum or Plasma | 0.725 |  |
| 3008486 | Thyroxine (T4) free [Moles/volume] in Serum or Plasma | 0.725 | 133 |
| 3008598 | Thyroxine (T4) free [Mass/volume] in Serum or Plasma | 0.724 |  |
| 3027361 | Cholecalciferol (Vit D3) [Mass/volume] in Serum or Plasma | 0.723 | 390 |
| 3028949 | Nucleated cells [#/volume] in Bronchial specimen by Manual count | 0.723 |  |
| 3024629 | Glucose [Mass/volume] in Urine by Test strip | 0.721 |  |
| 1259598 | Other cells/Leukocytes in Bronchoalveolar lavage by Manual count | 0.721 |  |
| 3029991 | Specific gravity of Urine by Refractometry automated | 0.719 |  |
| 646156 | Thyroxine (T4) free [Measurement] in Serum or Plasma | 0.718 |  |
| 36203795 | Cancer pathology panel - Breast cancer specimen by CAP cancer protocols | 0.718 |  |
| 3030649 | Epithelial cells.squamous/cells in Bronchial specimen by Light microscopy | 0.717 |  |
| 36032396 | Epithelial cells.squamous [#/volume] in Bronchial specimen by Manual count | 0.717 |  |
| 3015620 | Creatine kinase panel - Serum or Plasma | 0.715 |  |
| 42529232 | Thyroxine (T4) free [Moles/volume] in Serum or Plasma by Immunoassay | 0.713 |  |
| 40761932 | Thyroxine (T4) free [Mass/volume] in Serum or Plasma --baseline | 0.712 |  |
| 36660707 | Vitamin B6 and metabolites panel - Serum or Plasma | 0.712 |  |
| 3043812 | Specific gravity of 24 hour Urine by Refractometry | 0.712 |  |
| 3032166 | Volatiles panel - Serum or Plasma | 0.710 |  |
| 3048545 | Microorganism identified in Cervical or vaginal smear or scraping by Cyto stain | 0.709 |  |
| 42529420 | Cytokines panel - Serum or Plasma | 0.709 |  |
| 21494652 | Pterins panel - Serum or Plasma | 0.709 |  |
| 3013125 | Reviewing cytologist who read Cyto stain of Cervical or vaginal smear or scraping | 0.707 | 1656 |
| 3027343 | Pathologist who read Cyto stain of Cervical or vaginal smear or scraping | 0.701 | 115 |
| 3003447 | Creatinine [Mass/volume] in Urine by Test strip | 0.700 |  |
| 3035113 | Reducing substances [Units/volume] in Urine by Test strip | 0.699 |  |
| 1469700 | Breast cancer molecular subtype in Tissue by Prosigna Nominal | 0.699 |  |
| 3021450 | Screening techniques [Identifier] in Cervical or vaginal smear or scraping by Cyto stain | 0.698 |  |
| 46236490 | Tumor morphology panel Cancer | 0.696 |  |
| 3032411 | Platelet function (closure time) [Interpretation] in Blood Narrative | 0.688 |  |
| 40758358 | Immune stain study | 0.684 |  |
| 3052985 | von Willebrand evaluation [Interpretation] in Platelet poor plasma | 0.684 |  |
| 42527794 | Cancer pathology panel - Prostate cancer | 0.680 |  |
| 3007405 | General categories [Interpretation] of Cervical or vaginal smear or scraping by Cyto stain | 0.680 |  |
| 3022519 | Antithrombin [Interpretation] in Platelet poor plasma | 0.676 | 1117 |
| 1001826 | Large B-cell lymphoma classification panel - Tissue | 0.675 |  |
| 3038323 | Breast Cancer Ag 225 [Presence] in Tissue by Immune stain | 0.675 |  |
| 3020174 | Platelet aggregation [Interpretation] in Platelet poor plasma | 0.667 | 1864 |
| 1259975 | Breast Cancer recurrence risk multigene analysis [Presence] in Tissue by Molecular genetics method | 0.666 |  |
| 36660133 | Platelet aggregation [Interpretation] in Platelet rich plasma | 0.665 |  |
| 21493988 | Microsatellite instability marker panel - Cancer specimen | 0.662 |  |
| 3965876 | Thrombin generation test [Interpretation] in Platelet poor plasma Narrative | 0.662 |  |
| 1617408 | Cancer pathology panel - Endometrial cancer specimen | 0.657 |  |
| 3047126 | Platelet crossmatch [Interpretation] | 0.653 |  |
| 40771570 | Coagulation specialist review of results | 0.644 |  |
| 3031335 | Mixing studies [Interpretation] in Platelet poor plasma Narrative | 0.643 |  |
| 3010023 | Pathologist interpretation of Blood tests | 0.643 | 631 |
| 3046857 | Flow cytometry study | 0.641 | 1054 |
| 44786878 | Immunohistochemical stains in Bone marrow Narrative | 0.619 |  |
| 1001943 | Phosphohistone H3 [Presence] in Tissue by Immune stain | 0.599 |  |
| 3029042 | MSH-6 Ag [Presence] in Tissue by Immune stain | 0.594 |  |
| 3028769 | P53 protein Ag/cells in Tissue by Immune stain | 0.593 |  |
| 42527894 | PD-L1 by clone SP142 in Tissue by Immune stain Report | 0.588 |  |
| 3049069 | Cancer Ag 72-4 [Presence] in Tissue by Immune stain | 0.587 |  |
| 3049355 | Cytoketatin HMW Ag [Presence] in Tissue by Immune stain | 0.585 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2623 | b-eosinofiilit,b-diffiosatutkimus | e9/l | 95% | name+unit+values | 776 | 0 | [0.05, 0.09, 0.12, 0.15, 0.18, 0.21, 0.25, 0.31, 0.41] |  | Blood |  | Eosinophils [#/volume] in Blood |
| 2624 | b-eosinofiilit,b-diffiosatutkimus |  | 5% | name | 38 | 100 |  |  | Blood |  | Eosinophils [#/volume] in Blood |
| 2625 | b-erybla(19978b-erybla),osatutkimus | e9/l | 100% | name+unit+values | 162 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Blood |  | Nucleated erythrocytes [#/volume] in Blood |
| 2626 | b-hyytymistekijävgeeni,dna-tutkimus |  | 100% | name | 145 | 100 |  |  | Blood |  | F5 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method |
| 2627 | b-jak2-geeninmutaatio,dna-tutkimus |  | 100% | name | 141 | 100 |  |  | Blood |  | JAK2 gene p.V617F mutation [Presence] in Blood or Tissue by Molecular genetics method |
| 2628 | b-laktaatti,päivystystutkimus | mmol/l | 100% | name+unit+values | 11297 | 0 | [0.6, 0.73, 0.85, 0.99, 1.13, 1.3, 1.56, 1.95, 2.72] |  | Blood |  | Lactate [Moles/volume] in Blood |
| 2629 | b-laktaatti,päivystystutkimus |  | 0% | name | 53 | 100 |  |  | Blood |  | Lactate [Moles/volume] in Blood |
| 2630 | b-laktoosi-intoleranssi,dna-tutkimus |  | 100% | name | 396 | 100 |  |  | Blood |  | LCT gene -13910 T>C [Genotype] in Blood or Tissue by Molecular genetics method |
| 2631 | b-laktoosimalabsorptioonliityvägeenimuutos,dna |  | 100% | name | 146 | 100 |  |  | Blood |  | LCT gene -13910 T>C [Genotype] in Blood or Tissue by Molecular genetics method |
| 2632 | b-neutrofiili,erillistutkimuksena | e9/l | 100% | name+unit+values | 26946 | 0 | [1.15, 1.77, 2.31, 2.83, 3.4, 4.06, 4.87, 6.13, 8.46] |  | Blood |  | Neutrophils [#/volume] in Blood |
| 2633 | b-neutrofiili,erillistutkimuksena |  | 0% | name | 90 | 100 |  |  | Blood |  | Neutrophils [#/volume] in Blood |
| 2634 | b-neutrofiilit,b-diffiosatutkimus | e9/l | 100% | name+unit+values | 813 | 0 | [1.98, 2.53, 3.01, 3.43, 3.8, 4.31, 4.86, 5.59, 6.82] |  | Blood |  | Neutrophils [#/volume] in Blood |
| 2635 | b-neutrofiilit,erillistutkimuksena | e9/l | 95% | name+unit+values | 1653 | 0 | [2.1, 2.62, 3.09, 3.44, 3.76, 4.24, 4.87, 5.59, 7.23] |  | Blood |  | Neutrophils [#/volume] in Blood |
| 2636 | b-neutrofiilit,erillistutkimuksena |  | 5% | name | 80 | 100 |  |  | Blood |  | Neutrophils [#/volume] in Blood |
| 2637 | b-neutrofiiliterillistutkimuksena | e9/l | 100% | name+unit+values | 555 | 0 | [1.8, 2.41, 2.88, 3.29, 3.66, 4.13, 4.71, 5.54, 7.13] |  | Blood |  | Neutrophils [#/volume] in Blood |
| 2638 | b-protrombiinigeeni,dna-tutkimus |  | 100% | name | 135 | 100 |  |  | Blood |  | F2 gene p.G20210A mutation [Presence] in Blood or Tissue by Molecular genetics method |
| 2639 | bf-bronkuseritteenirtosolututkimus |  | 100% | name | 121 | 100 |  |  | Bronchial fluid |  | Cells [Type] in Bronchial fluid by Cytology |
| 2640 | bronkuseritteenirtosolututkimus |  | 100% | name | 145 | 100 |  |  |  |  | Cells [Type] in Bronchial fluid by Cytology |
| 2641 | cyp2d6-geeninvariaatiot,dna-tutkimus |  | 100% | name | 560 | 100 |  |  |  |  | CYP2D6 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method |
| 2642 | dpyd-geeninvarianttientutkimusverestä |  | 100% | name | 381 | 100 |  |  |  |  | DPYD gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method |
| 2643 | e-rdw(19976e-rdw),osatutkimus | % | 100% | name+unit+values | 161 | 0 | [12, 12.3, 13, 13, 13, 13, 13, 14, 15] |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 2644 | farmakogeneettinenpaneeli,dna-tutkimusverestä |  | 100% | name | 307 | 100 |  |  |  |  | Pharmacogenetics panel - Blood by Molecular genetics method |
| 2645 | farmakogeneettinenpaneelitutkimus |  | 100% | name | 238 | 100 |  |  |  |  | Pharmacogenetics panel - Blood by Molecular genetics method |
| 2646 | gynegologinenirtosolututkimus |  | 100% | name | 143 | 100 |  |  |  |  | Cytology study of Cervical or vaginal smear or scraping |
| 2647 | gynekologinenirtosolunäyte,hpvnho+tarvnestepapa |  | 100% | name | 156 | 100 |  |  |  |  | Human papillomavirus DNA and Cytology panel - Cervical or vaginal specimen |
| 2648 | gynekologinenirtosolututkimus |  | 100% | name | 1964 | 100 |  |  |  |  | Cytology study of Cervical or vaginal smear or scraping |
| 2649 | gynekologinenirtosolututkimus,seulonta |  | 100% | name | 2320 | 100 |  |  |  |  | Cytology study of Cervical or vaginal smear or scraping |
| 2650 | hyytymistekijävgeeni,dna-tutkimus |  | 100% | name | 105 | 100 |  |  |  |  | F5 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method |
| 2651 | immunohistokemiallinentutkimus |  | 100% | name | 124 | 100 |  |  |  |  | Immunohistochemistry study |
| 2652 | k-vitamiinitk1jak2,pakettitutkimus |  | 100% | name | 211 | 100 |  |  |  |  | Vitamin K1 and K2 panel - Serum or Plasma |
| 2653 | k1-vitamiini(fyllokinoni)osatutkimus | ug/l | 95% | name+unit+values | 195 | 0 | [0.15, 0.22, 0.28, 0.36, 0.43, 0.52, 0.7, 0.9, 1.6] |  |  |  | Phylloquinone [Mass/volume] in Serum or Plasma |
| 2654 | k1-vitamiini(fyllokinoni)osatutkimus |  | 5% | name | 11 | 100 |  |  |  |  | Phylloquinone [Mass/volume] in Serum or Plasma |
| 2655 | k2-vitamiini,menakinoni-4(mk4)osatutkimus | ug/l | 94% | name+unit+values | 203 | 0 | [0.14, 0.16, 0.2, 0.23, 0.26, 0.3, 0.34, 0.44, 0.58] |  |  |  | Menaquinone-4 [Mass/volume] in Serum or Plasma |
| 2656 | k2-vitamiini,menakinoni-4(mk4)osatutkimus |  | 6% | name | 14 | 100 |  |  |  |  | Menaquinone-4 [Mass/volume] in Serum or Plasma |
| 2657 | k2-vitamiini,menakinoni-7(mk7)osatutkimus | ug/l | 85% | name+unit+values | 185 | 0 | [0.13, 0.16, 0.2, 0.24, 0.32, 0.43, 0.71, 1.38, 2.6] |  |  |  | Menaquinone-7 [Mass/volume] in Serum or Plasma |
| 2658 | k2-vitamiini,menakinoni-7(mk7)osatutkimus |  | 15% | name | 32 | 100 |  |  |  |  | Menaquinone-7 [Mass/volume] in Serum or Plasma |
| 2659 | laktaatti,päivystystutkimus,verestä | mmol/l | 100% | name+unit+values | 353 | 0 | [0.77, 0.9, 1.04, 1.2, 1.46, 1.74, 2.08, 2.47, 3.11] |  |  |  | Lactate [Moles/volume] in Blood |
| 2660 | laktoosi-intoleranssi,dna-tutkimus |  | 100% | name | 168 | 100 |  |  |  |  | LCT gene -13910 T>C [Genotype] in Blood or Tissue by Molecular genetics method |
| 2661 | laktoosi-intoleranssi,dna-tutkimus,verestä␤ |  | 100% | name | 151 | 100 |  |  |  |  | LCT gene -13910 T>C [Genotype] in Blood or Tissue by Molecular genetics method |
| 2662 | lausunto,hemostaasi-jatrombosyyttitutkimukset |  | 100% | name | 337 | 100 |  |  |  |  | Hemostasis and Thrombocyte studies interpretation |
| 2663 | mikrobiologianerikoistutkimuk |  | 100% | name | 105 | 100 |  |  |  |  |  |
| 2664 | neuvola1,äitiysneuvolatutkimukset |  | 100% | name | 337 | 100 |  |  |  |  | Obstetric panel - Serum or Plasma and Blood |
| 2665 | p-ca-albk(laskennallinentutkimus) | mmol/l | 100% | name+unit+values | 161 | 0 | [2.31, 2.35, 2.39, 2.41, 2.43, 2.45, 2.47, 2.5, 2.53] |  | Plasma |  | Calcium.corrected [Moles/volume] in Serum or Plasma by calculation |
| 2666 | pf-laktaatti,päivystystutkimus | mmol/l | 100% | name+unit+values | 117 | 0 | [1.1, 1.2, 1.33, 1.5, 1.9, 2.39, 3.19, 4.1, 7.87] |  | Pleural fluid |  | Lactate [Moles/volume] in Pleural fluid |
| 2667 | pleuranesteenirtosolututkimus |  | 100% | name | 157 | 100 |  |  |  |  | Cells [Type] in Pleural fluid by Cytology |
| 2668 | pt-gynegologinenirtosolututkimus␤ |  | 100% | name | 463 | 100 |  |  | Patient |  | Cytology study of Cervical or vaginal smear or scraping |
| 2669 | pt-gynekologinenirtosolututkimus |  | 100% | name | 1912 | 100 |  |  | Patient |  | Cytology study of Cervical or vaginal smear or scraping |
| 2670 | pt-gynekologinenirtosolututkimus,seulonta |  | 100% | name | 483 | 100 |  |  | Patient |  | Cytology study of Cervical or vaginal smear or scraping |
| 2671 | s-borrelia,vasta-aineetiggvarmistustutkimus | au/ml | 38% | name+unit+values | 202 | 0 | [8.73, 12.59, 17.76, 25.48, 39, 57.84, 89.45, 117.05, 176.45] |  | Serum |  | Borrelia burgdorferi IgG Ab [Units/volume] in Serum by Immunoblot |
| 2672 | s-borrelia,vasta-aineetiggvarmistustutkimus |  | 62% | name | 325 | 100 |  |  | Serum |  | Borrelia burgdorferi IgG Ab [Units/volume] in Serum by Immunoblot |
| 2673 | s-borrelia,vasta-aineetigmvarmistustutkimus | au/ml | 78% | name+unit+values | 411 | 0 | [3.99, 6, 7.64, 9.37, 11.83, 15.83, 21.24, 27.61, 48.27] |  | Serum |  | Borrelia burgdorferi IgM Ab [Units/volume] in Serum by Immunoblot |
| 2674 | s-borrelia,vasta-aineetigmvarmistustutkimus |  | 22% | name | 117 | 100 |  |  | Serum |  | Borrelia burgdorferi IgM Ab [Units/volume] in Serum by Immunoblot |
| 2675 | s-hi-virus,vasta-aineet,päivystystutkimus |  | 100% | name | 151 | 100 |  |  | Serum |  | HIV 1+2 Ab [Presence] in Serum |
| 2676 | s-immunofiksaatiotutkimus |  | 100% | name | 406 | 100 |  |  | Serum |  | M-protein [Identifier] in Serum by Immunofixation |
| 2677 | sytologinenirtosolututkimus,virtsasta |  | 100% | name | 534 | 100 |  |  |  |  | Cells [Type] in Urine sediment by Cytology |
| 2678 | ts-rintasyövänennustekijätutkimus |  | 100% | name | 164 | 100 |  |  | Tissue |  | Breast cancer prognostic markers panel - Tissue |
| 2679 | tyreotropiinirefleksointitutkimus |  | 100% | name | 1372 | 100 |  |  |  |  | Thyrotropin.reflex to Free T4 panel - Serum or Plasma |
| 2680 | u-asetoniaineet(kval),osatutkimus |  | 100% | name | 151 | 100 |  |  | Urine |  | Ketones [Presence] in Urine by Test strip |
| 2681 | u-epiteelisolut,osatutkimus | e6/l | 91% | name+unit+values | 116 | 0 | [0.19, 0.3, 0.51, 1, 1.4, 2.09, 3.19, 5.3, 10.87] |  | Urine |  | Epithelial cells [#/volume] in Urine sediment by Automated count |
| 2682 | u-epiteelisolut,osatutkimus |  | 9% | name | 11 | 100 |  |  | Urine |  | Epithelial cells [#/volume] in Urine sediment by Automated count |
| 2683 | u-laajahuume-jalääkeainetutkimus |  | 100% | name | 374 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 2684 | u-proteiini(kval),osatutkimus |  | 100% | name | 151 | 100 |  |  | Urine |  | Protein [Presence] in Urine by Test strip |
| 2685 | u-suhteellinentiheys,osatutkimus |  | 100% | name+values | 154 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.03] |  | Urine |  | Specific gravity [RelDensity] in Urine by Test strip |
| 2686 | u-virtsanirtosolututkimus |  | 100% | name | 802 | 100 |  |  | Urine |  | Cells [Type] in Urine sediment by Cytology |
| 2687 | virtsanirtosolututkimus |  | 100% | name | 1078 | 100 |  |  |  |  | Cells [Type] in Urine sediment by Cytology |

