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
Here is group 37.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000285 | Sodium [Moles/volume] in Blood | 1.000 | 129 |
| 3000348 | Leukocyte esterase [Presence] in Urine by Test strip | 1.000 | 65 |
| 3002864 | Erythrocytes [#/volume] in Urine by Automated count | 1.000 | 246 |
| 3005456 | Potassium [Moles/volume] in Blood | 1.000 | 106 |
| 3006184 | Hemoglobin [Mass/volume] in Capillary blood | 1.000 |  |
| 3009261 | Glucose [Presence] in Urine by Test strip | 1.000 | 309 |
| 3009343 | pH of Capillary blood | 1.000 | 865 |
| 3009508 | Creatinine [Moles/volume] in Urine | 1.000 | 161 |
| 3011397 | Hemoglobin [Presence] in Urine by Test strip | 1.000 | 72 |
| 3012544 | pH of Venous blood | 1.000 | 519 |
| 3014051 | Protein [Presence] in Urine by Test strip | 1.000 | 99 |
| 3020491 | Glucose [Moles/volume] in Blood | 1.000 | 13 |
| 3021447 | Carbon dioxide [Partial pressure] in Venous blood | 1.000 | 523 |
| 3021601 | Nitrite [Presence] in Urine by Test strip | 1.000 | 56 |
| 3022621 | pH of Urine by Test strip | 1.000 | 59 |
| 3028626 | Oxygen [Partial pressure] in Capillary blood | 1.000 |  |
| 3030467 | Casts [#/volume] in Urine by Automated count | 1.000 |  |
| 3031040 | Bacteria [#/volume] in Urine by Automated count | 1.000 |  |
| 3035350 | Ketones [Presence] in Urine by Test strip | 1.000 | 102 |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 1.000 |  |
| 3040151 | Glucose [Moles/volume] in Capillary blood | 1.000 |  |
| 40762887 | Creatinine [Moles/volume] in Blood | 1.000 | 283 |
| 46236101 | Human papilloma virus 18 DNA [Presence] in Cervix by NAA with probe detection | 0.994 |  |
| 46236100 | Human papilloma virus 16 DNA [Presence] in Cervix by NAA with probe detection | 0.991 |  |
| 40760007 | HIV 1+2 Ab+HIV1 p24 Ag [Presence] in Serum or Plasma by Immunoassay | 0.976 |  |
| 36303442 | Epithelial cells [#/volume] in Urine by Automated | 0.974 |  |
| 3029187 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma | 0.973 | 516 |
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 0.973 | 154 |
| 37020818 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with probe detection | 0.971 |  |
| 42870589 | Drugs of abuse panel - Urine by Screen method | 0.970 |  |
| 40763086 | Leukocyte esterase [Presence] in Urine by Automated test strip | 0.970 |  |
| 3011173 | Microscopic observation [Identifier] in Tissue by Hematoxylin and eosin stain | 0.970 |  |
| 3021125 | Hepatitis C virus RNA [Presence] in Serum or Plasma by NAA with probe detection | 0.966 | 740 |
| 3008075 | Hepatitis C virus RNA [Presence] in Blood by NAA with probe detection | 0.960 |  |
| 3020647 | HIV 1 p24 Ag [Presence] in Serum or Plasma by Immunoassay | 0.957 |  |
| 1091714 | HIV 1+2 Ab+HIV1 p24 Ag [Presence] in Serum or Plasma | 0.955 |  |
| 3030758 | Nitrite [Presence] in Urine by Automated test strip | 0.952 |  |
| 40764134 | Human papilloma virus 18 DNA [Presence] in Specimen by NAA with probe detection | 0.952 |  |
| 648782 | Epstein Barr virus DNA [Presence] in Serum or Plasma by NAA with probe detection | 0.952 |  |
| 40760861 | Hemoglobin [Presence] in Urine by Automated test strip | 0.949 |  |
| 3012570 | Epstein Barr virus DNA [Presence] in Blood by NAA with probe detection | 0.949 |  |
| 40764133 | Human papilloma virus 16 DNA [Presence] in Specimen by NAA with probe detection | 0.947 |  |
| 1091414 | Leukocyte esterase [Presence] in Urine | 0.947 |  |
| 3043849 | Epstein Barr virus DNA [Units/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.945 |  |
| 3001977 | Microscopic observation [Identifier] in Tissue by Hematoxylin-eosin-Mayers progressive stain | 0.945 |  |
| 40760844 | Ketones [Presence] in Urine by Automated test strip | 0.945 |  |
| 3004391 | Epithelial cells [#/volume] in Urine by Manual count | 0.943 |  |
| 3019077 | Protein [Presence] in 24 hour Urine by Test strip | 0.943 |  |
| 3030260 | Glucose [Presence] in Urine by Automated test strip | 0.942 |  |
| 3040890 | HIV 1 p24 Ab [Presence] in Serum or Plasma by Immunoassay | 0.941 |  |
| 37020511 | Human papilloma virus 18 DNA [Presence] in Genital specimen by NAA with probe detection | 0.940 |  |
| 3019800 | Troponin T.cardiac [Mass/volume] in Serum or Plasma | 0.940 | 291 |
| 1091617 | C reactive protein [Mass/volume] in Serum, Plasma or Blood | 0.939 |  |
| 21493470 | Yersinia enterocolitica DNA [Presence] in Stool by NAA with non-probe detection | 0.939 |  |
| 3036910 | Microscopic observation [Identifier] in Tissue by Trichrome stain | 0.938 | 894 |
| 3003327 | Ova and parasites identified in Stool by Light microscopy | 0.937 | 659 |
| 36204252 | Human papilloma virus 18 DNA [Presence] in Tissue by NAA with probe detection | 0.936 |  |
| 40760845 | Protein [Presence] in Urine by Automated test strip | 0.935 |  |
| 37020661 | Human papilloma virus 16 DNA [Presence] in Genital specimen by NAA with probe detection | 0.935 |  |
| 1001833 | Epstein Barr virus DNA [Units/volume] (viral load) in Blood by NAA with probe detection | 0.935 |  |
| 36031312 | Human papilloma virus 45 DNA [Presence] in Cervix by NAA with probe detection | 0.934 |  |
| 36204250 | Human papilloma virus 16 DNA [Presence] in Tissue by NAA with probe detection | 0.934 |  |
| 3001695 | Erythrocytes [#/volume] in Urine by Manual count | 0.933 |  |
| 3037998 | Microscopic observation [Identifier] in Specimen by Hematoxylin and eosin stain | 0.933 |  |
| 36031212 | Human papilloma virus 31 DNA [Presence] in Cervix by NAA with probe detection | 0.933 |  |
| 3033479 | HIV 1 Ag [Presence] in Serum or Plasma by Immunoassay | 0.932 | 786 |
| 3029435 | Natriuretic peptide.B prohormone N-Terminal [Moles/volume] in Serum or Plasma | 0.932 |  |
| 42870364 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Blood by Immunoassay | 0.932 |  |
| 3006864 | Microscopic observation [Identifier] in Tissue by Tetrachrome stain | 0.931 |  |
| 3024198 | Microscopic observation [Identifier] in Tissue by Giemsa stain | 0.931 |  |
| 36031949 | Influenza virus A and B and SARS-CoV+SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.931 |  |
| 3035962 | HIV 1+2 Ab [Presence] in Serum or Plasma by Immunoassay | 0.931 | 324 |
| 3042804 | Leukocyte esterase+Nitrite [Presence] in Urine by Test strip | 0.931 |  |
| 46235076 | Creatinine [Moles/volume] in Serum, Plasma or Blood | 0.930 |  |
| 40768439 | Drugs of abuse 5 panel - Urine by Screen method | 0.930 |  |
| 42528601 | Human papilloma virus 16 E6+E7 mRNA [Presence] in Cervix by NAA with probe detection | 0.928 |  |
| 649459 | Epstein Barr virus DNA [log units/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.928 |  |
| 42868547 | Human papilloma virus 16 and 18 DNA [Presence] in Specimen by NAA with probe detection | 0.928 |  |
| 40762355 | Human papilloma virus 18 DNA [Presence] in Cervix by Probe with signal amplification | 0.927 |  |
| 36032027 | Human papilloma virus 56+59+66 DNA [Presence] in Cervix by NAA with probe detection | 0.926 |  |
| 40760140 | CBC W Auto Differential panel - Blood | 0.926 |  |
| 3029879 | Epithelial cells.squamous [#/volume] in Urine by Automated count | 0.926 |  |
| 3021339 | Microscopic observation [Identifier] in Tissue by Wright Giemsa stain | 0.926 |  |
| 3030306 | Epithelial cells.non-squamous [#/volume] in Urine by Automated count | 0.925 |  |
| 3015451 | Hepatitis C virus RNA [Presence] in Specimen by NAA with probe detection | 0.925 |  |
| 46236251 | Leukocyte esterase [Presence] in Body fluid by Automated test strip | 0.925 |  |
| 648637 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Immunoassay | 0.925 |  |
| 42528835 | Human papilloma virus 16+18+31+33+35+39+45+51+52+56+58+59+66+68 DNA [Presence] in Cervix by NAA with probe detection | 0.924 |  |
| 646531 | Influenza virus A and Influenza virus B and SARS coronavirus 2 and Respiratory syncytial virus Ag panel - Nose by Rapid immunoassay | 0.923 |  |
| 40760857 | Erythrocytes [#/volume] in Urine by Automated test strip | 0.922 |  |
| 36033643 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.921 |  |
| 3021513 | Carbon dioxide [Partial pressure] in Mixed venous blood | 0.921 |  |
| 1469672 | Bacteria identified in Pus by Anaerobe culture | 0.921 |  |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.920 |  |
| 46235078 | Potassium [Moles/volume] in Serum, Plasma or Blood | 0.919 |  |
| 1091300 | Yersinia enterocolitica DNA [Presence] in Specimen by NAA with probe detection | 0.918 |  |
| 1616989 | Carbon dioxide [Partial pressure] in Central venous blood | 0.918 |  |
| 3039234 | HIV 1+2 IgG Ab [Presence] in Serum or Plasma by Immunoassay | 0.918 |  |
| 3014258 | Epstein Barr virus DNA [Presence] in Specimen by NAA with probe detection | 0.917 | 1832 |
| 42529224 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma by Immunoassay | 0.917 |  |
| 3023376 | Microscopic observation [Identifier] in Tissue by Hematoxylin-eosin-Harris regressive stain | 0.916 |  |
| 1001594 | Epstein Barr virus DNA [log units/volume] (viral load) in Blood by NAA with probe detection | 0.915 |  |
| 3000850 | Epithelial cells [#/volume] in Urine | 0.915 |  |
| 3028734 | HIV 1 p24 Ag [Presence] in Serum | 0.915 |  |
| 40762866 | Epstein Barr virus DNA [Presence] in Body fluid by NAA with probe detection | 0.915 |  |
| 3050079 | Epstein Barr virus DNA [#/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.914 |  |
| 3043706 | Sodium [Moles/volume] in Arterial blood | 0.914 |  |
| 3021269 | Microscopic observation [Identifier] in Tissue by Other stain | 0.914 |  |
| 3047166 | Epithelial cells [#/area] in Urine sediment by Automated count | 0.913 |  |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.912 |  |
| 3966568 | Human papilloma virus 18 DNA [Presence] in Urine by NAA with probe detection | 0.912 |  |
| 3014305 | Glucose [Presence] in Blood by Test strip | 0.912 |  |
| 1469712 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.911 |  |
| 46236096 | Human papilloma virus 18 DNA [Presence] in Anorectal by NAA with probe detection | 0.911 |  |
| 3045874 | Casts [#/area] in Urine sediment by Automated count | 0.911 |  |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.911 |  |
| 648911 | Epstein Barr virus DNA [Units/volume] (viral load) in Specimen by NAA with probe detection | 0.911 |  |
| 3019634 | Microscopic observation [Identifier] in Tissue by Wright stain | 0.910 |  |
| 3028893 | Ketones [Presence] in Urine | 0.910 | 217 |
| 3001501 | Glucose [Moles/volume] in Capillary blood by Glucometer | 0.910 |  |
| 3042812 | Nitrite [Presence] in Urine | 0.910 |  |
| 40761994 | HIV 1+2 Ab+HIV1 p24 Ag [Units/volume] in Serum or Plasma by Immunoassay | 0.910 |  |
| 3002574 | Fasting glucose [Presence] in Urine by Test strip | 0.910 |  |
| 3964702 | Creatinine [Moles/volume] in Venous blood | 0.910 |  |
| 46235476 | Human papilloma virus 18+45 E6+E7 mRNA [Presence] in Cervix by NAA with probe detection | 0.909 |  |
| 3051593 | INR in Capillary blood by Coagulation assay | 0.909 |  |
| 3043409 | Potassium [Moles/volume] in Arterial blood | 0.909 |  |
| 3013539 | Creatinine [Moles/volume] in 24 hour Urine | 0.908 | 1978 |
| 3020416 | Erythrocytes [#/volume] in Blood by Automated count | 0.907 | 9 |
| 1761893 | Epstein Barr virus DNA [Log #/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.907 |  |
| 3041354 | Potassium [Moles/volume] in Venous blood | 0.906 |  |
| 3039401 | Hepatitis C virus RNA [Presence] in Body fluid by NAA with probe detection | 0.905 |  |
| 3021337 | Troponin I.cardiac [Mass/volume] in Serum or Plasma | 0.905 | 113 |
| 3037329 | Epstein Barr virus DNA [#/volume] (viral load) in Blood by NAA with probe detection | 0.905 |  |
| 3009531 | Nitrite [Mass/volume] in Urine by Test strip | 0.904 |  |
| 3004077 | Glucose [Mass/volume] in Capillary blood | 0.904 |  |
| 21492663 | Yersinia enterocolitica recN gene [Presence] in Stool by NAA with probe detection | 0.904 |  |
| 3033106 | HIV 1 p24 Ab [Presence] in Serum | 0.904 |  |
| 1616317 | Hemoglobin [Mass/volume] in Capillary blood by Oximetry | 0.903 |  |
| 3018613 | Epstein Barr virus DNA [Presence] in Tissue by NAA with probe detection | 0.902 |  |
| 649308 | Natriuretic peptide.B prohormone N-Terminal [Measurement] in Serum or Plasma | 0.902 |  |
| 43533384 | Drugs of abuse panel - Blood by Screen method | 0.901 |  |
| 3029305 | pH of Urine by Automated test strip | 0.901 |  |
| 3024629 | Glucose [Mass/volume] in Urine by Test strip | 0.901 |  |
| 3017675 | HIV 1 Ab [Presence] in Serum or Plasma by Immunoassay | 0.901 | 1177 |
| 1469767 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Body fluid by Immunoassay | 0.900 |  |
| 3002582 | Erythrocytes [#/volume] in Urine | 0.900 |  |
| 3021257 | Drugs of abuse 5 panel - Urine | 0.899 |  |
| 3003344 | Hemoglobin [Presence] in Urine | 0.899 |  |
| 3031015 | pH of 24 hour Urine by Test strip | 0.898 |  |
| 1469525 | Bacteria identified in Pus by Culture | 0.898 |  |
| 3027315 | Oxygen [Partial pressure] in Blood | 0.898 | 87 |
| 3038702 | Sodium [Moles/volume] in Capillary blood | 0.895 |  |
| 3050934 | HIV 1+Hepatitis C virus RNA [Presence] in Serum or Plasma by NAA with probe detection | 0.895 |  |
| 3028923 | Bacteria [#/area] in Urine sediment by Automated count | 0.895 |  |
| 3026782 | Osmolality of Urine | 0.895 | 556 |
| 1091200 | Bacteria [#/volume] in Urine | 0.895 |  |
| 3011325 | HIV 1+2 Ab [Presence] in Serum | 0.894 | 442 |
| 3044242 | Glucose [Moles/volume] in Arterial blood | 0.894 |  |
| 40764141 | Human papilloma virus 45 DNA [Presence] in Specimen by NAA with probe detection | 0.894 |  |
| 3049185 | Hemoglobin [Mass/volume] in Urine by Test strip | 0.894 |  |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 0.894 | 1 |
| 46234770 | C reactive protein [Moles/volume] in Serum or Plasma | 0.894 |  |
| 3038515 | Glucose [Moles/volume] in Venous blood | 0.894 |  |
| 42529225 | Natriuretic peptide.B prohormone N-Terminal [Moles/volume] in Serum or Plasma by Immunoassay | 0.894 |  |
| 1761344 | Epstein Barr virus DNA [Log #/volume] (viral load) in Blood by NAA with probe detection | 0.894 |  |
| 3022810 | Sodium [Moles/volume] in Body fluid | 0.893 |  |
| 3037459 | Creatinine [Moles/volume] in Body fluid | 0.893 | 1234 |
| 649280 | Hepatitis A virus RNA [Presence] in Blood by NAA with probe detection | 0.893 |  |
| 3026726 | Creatinine [Moles/volume] in Specimen | 0.893 |  |
| 3007696 | Carbon dioxide [Partial pressure] in Venous cord blood | 0.893 | 1204 |
| 3048402 | Erythrocytes [#/area] in Urine sediment by Automated count | 0.891 |  |
| 3023024 | Carbon dioxide [Partial pressure] in Capillary blood | 0.889 |  |
| 36031556 | Human papilloma virus 35+39+68 DNA [Presence] in Cervix by NAA with probe detection | 0.889 |  |
| 1616438 | pH of Central venous blood | 0.888 |  |
| 3048529 | Troponin T.cardiac [Mass/volume] in Blood | 0.888 |  |
| 36031448 | Human papilloma virus 33+58 DNA [Presence] in Cervix by NAA with probe detection | 0.888 |  |
| 1259531 | Human papilloma virus 31+33+52+58 DNA [Presence] in Cervix by NAA with probe detection | 0.887 |  |
| 1091454 | Yersinia pseudotuberculosis complex DNA [Presence] in Specimen by NAA with probe detection | 0.887 |  |
| 3005897 | Protein [Mass/volume] in Urine by Test strip | 0.886 | 74 |
| 3036701 | Epstein Barr virus DNA [Presence] in Bone marrow by NAA with probe detection | 0.886 |  |
| 36032296 | Human papilloma virus 52 DNA [Presence] in Cervix by NAA with probe detection | 0.886 |  |
| 3013290 | Carbon dioxide [Partial pressure] in Blood | 0.885 | 86 |
| 3040006 | Creatinine [Moles/volume] in 12 hour Urine | 0.885 |  |
| 3003159 | Erythrocytes [#/volume] in Body fluid by Automated count | 0.885 | 1726 |
| 648515 | Epstein Barr virus DNA [Presence] in Urine by NAA with probe detection | 0.885 |  |
| 3023103 | Potassium [Moles/volume] in Serum or Plasma | 0.885 | 3 |
| 3017250 | Creatinine [Mass/volume] in Urine | 0.884 |  |
| 3051825 | Creatinine [Mass/volume] in Blood | 0.884 |  |
| 3010156 | C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method | 0.884 | 348 |
| 3023539 | Ketones [Mass/volume] in Urine by Test strip | 0.884 |  |
| 3012388 | pH of Mixed venous blood | 0.883 |  |
| 3037185 | Protein [Presence] in Urine | 0.883 |  |
| 3020650 | Glucose [Presence] in Urine | 0.882 | 116 |
| 3008116 | Ketones [Moles/volume] in Urine by Test strip | 0.882 | 80 |
| 3041449 | Collagen crosslinked C-telopeptide [Mass/volume] in Serum or Plasma | 0.882 |  |
| 3036243 | Potassium [Moles/volume] in Body fluid | 0.881 |  |
| 3002032 | Base excess in Venous blood by calculation | 0.881 | 966 |
| 3030141 | Hepatitis C virus RNA panel (viral load) in Serum or Plasma by NAA with probe detection | 0.881 |  |
| 3035729 | Glucose [Moles/volume] in Body fluid | 0.881 | 788 |
| 3019902 | Methicillin resistant Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.881 | 146 |
| 3040510 | Creatinine [Moles/time] in 1 hour Urine | 0.879 |  |
| 44787055 | CBC W Differential panel - Cord blood | 0.879 |  |
| 40769783 | Troponin T.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.879 |  |
| 3014918 | Hepatitis C virus RNA [Presence] in Tissue by NAA with probe detection | 0.878 |  |
| 3038830 | Creatinine [Moles/volume] in Urine --baseline | 0.878 |  |
| 3050126 | Yersinia sp DNA [Identifier] in Specimen by NAA with probe detection | 0.878 |  |
| 3033985 | Epstein Barr virus DNA [Presence] in Mouth by NAA with probe detection | 0.878 |  |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 0.878 | 5 |
| 1091437 | Human papilloma virus 35+39+51+56+59+66+68 DNA [Presence] in Cervix by NAA with probe detection | 0.878 |  |
| 3040893 | Potassium [Moles/volume] in Capillary blood | 0.877 |  |
| 3036300 | Epstein Barr virus DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.875 |  |
| 3965306 | Troponin T.cardiac [Mass/volume] in 6 hour Serum or Plasma | 0.875 |  |
| 42870592 | CBC W Differential panel, method unspecified - Blood | 0.875 |  |
| 42870370 | Human papilloma virus 31+33+35+39+45+51+52+56+58+59+66+68 DNA [Presence] in Cervix by NAA with probe detection | 0.875 |  |
| 3018447 | Hepatitis C virus RNA [Units/volume] (viral load) in Serum or Plasma by NAA with probe detection | 0.874 | 531 |
| 3006735 | Hepatitis A virus RNA [Presence] in Serum by NAA with probe detection | 0.874 |  |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 0.873 | 4 |
| 3003453 | Glucose [Presence] in Urine by Test strip --30 minutes post dose glucose | 0.873 |  |
| 3029080 | Hemoglobin [Entitic mass] in Reticulocytes | 0.873 | 1413 |
| 3002388 | Ova and parasites identified in Stool by Parasite sedimentation | 0.873 |  |
| 3008770 | Glucose [Moles/volume] in Urine by Test strip | 0.873 | 73 |
| 3011960 | Natriuretic peptide B [Mass/volume] in Serum or Plasma | 0.873 | 204 |
| 1761482 | Bacteria [#/volume] in Urine by Culture | 0.872 |  |
| 40760950 | Erythrocytes [#/volume] in Dialysis fluid by Automated count | 0.872 |  |
| 648940 | C reactive protein [Measurement] in Serum or Plasma | 0.872 |  |
| 3027946 | Carbon dioxide [Partial pressure] in Arterial blood | 0.871 | 205 |
| 3000483 | Glucose [Mass/volume] in Blood | 0.871 |  |
| 3019493 | Glucose [Presence] in Urine by Test strip --1 hour post dose glucose | 0.871 |  |
| 1469858 | Troponin T.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.870 |  |
| 46235168 | Fasting glucose [Moles/volume] in Blood | 0.870 |  |
| 3046787 | Ova and parasites identified in Stool by Trichrome stain | 0.870 |  |
| 40762353 | Leukocyte esterase [Presence] in Cerebral spinal fluid by Test strip | 0.870 |  |
| 46234833 | Bacteria identified in Abscess by Anaerobe+Aerobe culture | 0.869 |  |
| 1092301 | Erythrocytes [#/volume] in Urine sediment | 0.868 |  |
| 3027215 | Base excess standard in Venous blood by calculation | 0.868 |  |
| 40766103 | Ketones [Presence] in Urine by Test strip --1 hour post dose glucose | 0.868 |  |
| 1002224 | Polysomnography panel | 0.867 |  |
| 3036839 | Oxygen [Partial pressure] in Capillary blood --pre treatment | 0.867 |  |
| 21491346 | Pathologic casts [#/volume] in Urine by Automated count | 0.867 |  |
| 3025722 | Staphylococcus sp identified in Specimen by Organism specific culture | 0.866 |  |
| 1469649 | Campylobacter sp DNA [Presence] in Stool by NAA with probe detection | 0.866 |  |
| 36305828 | Drugs of abuse screen W Reflex confirm panel - Urine | 0.865 |  |
| 3005518 | Ova and parasites identified in Stool by Immune stain | 0.865 |  |
| 3005589 | Glucose [Presence] in Urine by Test strip --1.5 hours post dose glucose | 0.865 |  |
| 43055557 | Base excess.100% oxygenated [Moles/volume] standard in Venous blood by calculation | 0.864 |  |
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.864 |  |
| 3012744 | Ova and parasites identified in Specimen by Light microscopy | 0.863 | 527 |
| 3966671 | Aeromonas sp DNA [Presence] in Stool by NAA with probe detection | 0.863 |  |
| 3024354 | Oxygen [Partial pressure] in Venous blood | 0.862 | 665 |
| 3001298 | Ova and parasites identified in Stool by McMaster concentration | 0.862 |  |
| 3020389 | Ova and parasites identified in Stool by Concentration | 0.862 | 257 |
| 3050687 | CBC WO Differential panel - Cord blood | 0.861 |  |
| 3027801 | Oxygen [Partial pressure] in Arterial blood | 0.861 | 193 |
| 648594 | Leukocyte esterase [Measurement] in Urine | 0.861 |  |
| 21490733 | Potassium [Mass/volume] in Blood | 0.860 |  |
| 3005448 | Ova and parasites identified in Stool by Iron hematoxylin stain | 0.860 |  |
| 3000963 | Hemoglobin [Mass/volume] in Blood | 0.858 | 2 |
| 3019572 | Troponin T.cardiac [Mass/volume] in Venous blood | 0.858 |  |
| 3966163 | Shigella sp DNA [Presence] in Stool by NAA with probe detection | 0.858 |  |
| 1616933 | Salmonella sp DNA [Presence] in Stool by NAA with probe detection | 0.856 |  |
| 648732 | Reticulocyte - RBC Hemoglobin [Entitic mass difference] in Blood | 0.856 |  |
| 3051387 | C reactive protein [Mass/volume] in Capillary blood | 0.856 |  |
| 3033745 | Troponin I.cardiac [Mass/volume] in Blood | 0.855 |  |
| 3039904 | Epithelial cells.renal [#/volume] in Urine by Computer assisted method | 0.854 |  |
| 3004361 | Ova and parasites identified in Stool by Kinyoun iron hematoxylin stain | 0.854 |  |
| 40766104 | Ketones [Presence] in Urine by Test strip --3 hours post dose glucose | 0.853 |  |
| 3001838 | Sodium [Moles/volume] in Red Blood Cells | 0.853 |  |
| 3044552 | Amphetamine+Methamphetamine [Presence] in Urine | 0.853 |  |
| 3004559 | Base deficit in Venous blood | 0.853 | 1187 |
| 3028766 | C reactive protein [Titer] in Serum or Plasma | 0.852 |  |
| 3030830 | pH of Body fluid by Test strip | 0.851 |  |
| 3003181 | Sodium [Moles/volume] in Urine | 0.851 | 412 |
| 3002173 | Hemoglobin [Mass/volume] in Arterial blood | 0.850 | 188 |
| 3035968 | Oxygen [Partial pressure] in Capillary blood --post treatment | 0.850 |  |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.850 |  |
| 3029162 | Epithelial cells.squamous [#/area] in Urine sediment by Automated count | 0.850 |  |
| 40766105 | Ketones [Presence] in Urine by Test strip --4 hours post dose glucose | 0.849 |  |
| 3035320 | C reactive protein [Mass/volume] in Body fluid | 0.849 |  |
| 3966498 | Troponin T. cardiac [Mass/volume] in 2 hour 5th generation Serum or Plasma | 0.849 |  |
| 3004097 | Oxygen content in Capillary blood | 0.849 |  |
| 1616406 | Base excess standard in Central venous blood | 0.848 |  |
| 3029937 | Albumin [Presence] in Urine by Test strip | 0.848 |  |
| 3009105 | Erythrocytes [#/volume] in Urine by Test strip | 0.848 | 126 |
| 3043088 | Ketones [Presence] in 24 hour Urine | 0.847 |  |
| 1988560 | Cocci bacteria [#/volume] in Urine sediment by Automated count | 0.846 |  |
| 36306105 | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.846 |  |
| 3030327 | pH of Capillary blood from Fetus | 0.845 |  |
| 3040526 | Collagen crosslinked C-telopeptide [Moles/volume] in Serum or Plasma | 0.845 |  |
| 3013823 | Potassium [Moles/volume] in Red Blood Cells | 0.845 |  |
| 3017553 | Oxygen [Partial pressure] (8 hour minimum) in Capillary blood | 0.844 |  |
| 3016038 | Potassium [Moles/volume] in Urine | 0.844 | 493 |
| 1092449 | Base excess in Venous cord blood | 0.843 |  |
| 3026681 | Sodium [Moles/volume] in Specimen | 0.843 |  |
| 36661384 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.843 |  |
| 1989355 | Bacilliform bacteria [#/volume] in Urine sediment by Automated count | 0.843 |  |
| 3049183 | Collagen crosslinked C-telopeptide [Mass/volume] in Urine | 0.843 |  |
| 3030267 | Hemoglobin [Mass/volume] in Urine by Automated test strip | 0.843 |  |
| 3000965 | C reactive protein [Presence] in Serum or Plasma | 0.843 | 1281 |
| 40760892 | CBC W Ordered Manual Differential panel - Blood | 0.842 |  |
| 3006462 | Nitrate [Presence] in Urine | 0.842 |  |
| 647699 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag [Identifier] in Nose by Rapid immunoassay | 0.841 |  |
| 3019383 | Ova and parasites identified in Stool by Baermann concentration | 0.841 |  |
| 3006893 | Glucose [Moles/volume] in Specimen | 0.841 |  |
| 3022670 | pH of Venous cord blood | 0.841 | 1082 |
| 3041412 | Epithelial cells.non-squamous [#/area] in Urine sediment by Automated count | 0.841 |  |
| 3011797 | Bacteria identified in Abscess by Aerobe culture | 0.840 |  |
| 3030981 | Hyaline casts [#/volume] in Urine by Automated count | 0.840 |  |
| 3013171 | Leukocyte esterase [Units/volume] in Urine | 0.840 |  |
| 3010251 | Oxygen [Partial pressure] in Body fluid | 0.840 |  |
| 3029490 | Free Hemoglobin [Presence] in Urine | 0.839 |  |
| 3038950 | Acinetobacter sp multidrug resistant identified in Specimen by Organism specific culture | 0.839 |  |
| 21490848 | Carbon dioxide [Partial pressure] in Pulmonary artery | 0.839 |  |
| 3039059 | Drugs of abuse 7 and Alcohol and Tricyclics panel - Urine by Screen method | 0.839 |  |
| 1988185 | Stimulants drug panel - Urine by Screen method | 0.839 |  |
| 3041290 | Carbon dioxide [Partial pressure] adjusted to patient's actual temperature in Venous blood | 0.839 |  |
| 1470002 | Bacteria identified in Abscess by Anaerobe culture | 0.838 |  |
| 21492987 | Influenza virus A and B Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.838 |  |
| 43055234 | pH of Vaginal fluid by Test strip | 0.836 |  |
| 3029350 | Yeast [#/volume] in Urine by Automated count | 0.836 |  |
| 36661376 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.835 |  |
| 647347 | Glucose [Measurement] in Capillary blood | 0.835 |  |
| 1175703 | Drugs of abuse panel - Body fluid | 0.833 |  |
| 3015736 | pH of Urine | 0.833 | 612 |
| 3004119 | Hemoglobin [Mass/volume] in Venous blood | 0.833 | 1986 |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.832 |  |
| 3040799 | Casts [Presence] in Urine by Automated | 0.830 |  |
| 1259993 | Gas and Lactate panel - Venous blood | 0.829 |  |
| 3027969 | Bacteria identified in Wound by Anaerobe culture | 0.829 |  |
| 3041694 | Casts type not specified [#/volume] in Urine by Computer assisted method | 0.828 |  |
| 40761054 | Collagen crosslinked C-telopeptide [Mass/volume] in 24 hour Urine | 0.828 |  |
| 3029872 | Protein [Mass/volume] in Urine by Automated test strip | 0.828 |  |
| 648479 | CLL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.828 |  |
| 1761840 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Specimen by NAA with probe detection | 0.826 |  |
| 42869451 | Hemoglobin [Entitic mass] in Reticulocytes by Automated count | 0.826 |  |
| 40758548 | Home drug screening panel - Urine | 0.825 |  |
| 649098 | B-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.825 |  |
| 1616922 | Base excess in Central venous blood by calculation | 0.825 |  |
| 3032172 | Bacteria [Presence] in Urine by Automated | 0.825 |  |
| 3000991 | Gas panel - Venous blood | 0.824 |  |
| 1616736 | Protein/Creatinine Qualitative in Urine by Test strip | 0.824 |  |
| 43533989 | Noninvasive prenatal fetal aneuploidy panel - Plasma cell-free DNA | 0.822 | 3000 |
| 36032057 | Opioids panel - Urine by Screen method | 0.822 |  |
| 3043688 | Hemoglobin [Mass/volume] in Body fluid | 0.821 |  |
| 1469937 | Drugs tested for in Urine by Screen method | 0.820 |  |
| 40760141 | CBC W Reflex Manual Differential panel - Blood | 0.819 |  |
| 3965536 | Acute myeloid leukemia minimal residual disease in Bone marrow by Flow cytometry (FC) Narrative | 0.819 |  |
| 46234834 | Bacteria identified in Bone by Anaerobe+Aerobe culture | 0.819 |  |
| 3008440 | Collagen crosslinked N-telopeptide [Moles/volume] in Serum | 0.818 |  |
| 3044942 | Collagen crosslinked N-telopeptide [Mass/volume] in Urine | 0.818 |  |
| 1091581 | Methicillin resistant Staphylococcus aureus [Presence] in Skin by Organism specific culture | 0.817 |  |
| 36660607 | Microalbumin [Presence] in Urine by Test strip | 0.817 |  |
| 1469831 | Hyaline casts [#/volume] in Urine sediment by Automated count | 0.817 |  |
| 3027005 | Bacteria identified in Tissue by Aerobe culture | 0.816 |  |
| 3024447 | Bacteria identified in Specimen by Anaerobe+Aerobe culture | 0.816 | 1062 |
| 3016437 | Bacteria identified in Aspirate by Anaerobe culture | 0.816 |  |
| 1175629 | Drugs of abuse panel - Hair | 0.816 |  |
| 37020002 | Multiple myeloma minimal residual disease panel - Bone marrow by Flow cytometry (FC) | 0.815 |  |
| 3019198 | Lymphocytes [#/volume] in Blood | 0.814 | 70 |
| 3023001 | Base excess in Mixed venous blood by calculation | 0.813 |  |
| 46234777 | Amphetamine+Methamphetamine [Presence] in Urine by Screen method | 0.813 |  |
| 3041130 | Mixed cellular casts [#/volume] in Urine by Computer assisted method | 0.812 |  |
| 21491345 | Pathologic casts [#/area] in Urine by Automated count | 0.812 |  |
| 3039355 | Methicillin resistant Staphylococcus aureus [Presence] in Nose by Organism specific culture | 0.812 |  |
| 40758903 | Hemoglobin [Mass/volume] in Blood by Oximetry | 0.812 |  |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.811 |  |
| 1091049 | Amphetamine [Presence] in Urine | 0.811 |  |
| 3040501 | WBC casts [#/volume] in Urine by Computer assisted method | 0.811 |  |
| 3007435 | Base excess in Venous cord blood by calculation | 0.810 |  |
| 3966454 | Gas and electrolytes panel - Venous blood | 0.809 |  |
| 21491103 | Multiple drug resistant gram negative organism [Identifier] in Specimen by Culture | 0.808 |  |
| 3011288 | Drugs identified in Urine by Screen method | 0.808 | 1071 |
| 3050898 | Methicillin resistant Staphylococcus aureus [Presence] in Genital specimen by Organism specific culture | 0.808 |  |
| 3027901 | Hemoglobin [Mass/volume] in Arterial cord blood | 0.807 |  |
| 3045592 | Acute leukemia panel - Specimen by Flow cytometry (FC) | 0.807 |  |
| 1469682 | Chromosome analysis in Blood by Microarray | 0.807 |  |
| 3010169 | Leukocyte esterase [Enzymatic activity/volume] in Leukocytes | 0.807 |  |
| 3010421 | pH of Blood | 0.806 | 97 |
| 3039628 | Collagen crosslinked C-telopeptide [Mass/time] in 24 hour Urine | 0.805 |  |
| 3000330 | Specific gravity of Urine by Test strip | 0.805 | 71 |
| 3040135 | pH of Capillary blood adjusted to patient's actual temperature | 0.804 |  |
| 37020245 | Staphylococcus species methicillin resistant identified in Isolate or Specimen by Molecular genetics method | 0.804 |  |
| 3965853 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Blood or Marrow by Flow cytometry (FC) | 0.803 |  |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.802 |  |
| 36659824 | Bacteria.carbapenem resistant identified in Specimen by Organism specific culture | 0.802 |  |
| 3041041 | Hemoglobin [Mass/volume] in Cord blood | 0.802 |  |
| 645216 | T-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.802 |  |
| 3041440 | Amphetamine+Methamphetamine [Presence] in Specimen | 0.801 |  |
| 1092282 | Methadone Confirmatory panel - Urine | 0.801 |  |
| 3053028 | Streptococcus sp identified in Specimen by Organism specific culture | 0.801 |  |
| 46234968 | Reticulocyte cellular hemoglobin distribution width [Entitic mass] in Blood by calculation | 0.800 |  |
| 40771046 | pH of Peritoneal fluid by Test strip | 0.800 |  |
| 3027484 | Hemoglobin [Mass/volume] in Blood by calculation | 0.800 |  |
| 3029361 | Urinalysis dipstick panel - Urine by Automated test strip | 0.800 |  |
| 3049714 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma | 0.800 |  |
| 3040705 | Amphetamine+Methamphetamine [Presence] in Serum or Plasma | 0.799 |  |
| 3027944 | Amphetamines [Presence] in Urine | 0.799 | 214 |
| 3023300 | Diffusion capacity/Alveolar volume by Single breath.carbon monoxide+Helium | 0.799 |  |
| 3033173 | Hemoglobin [Presence] in Specimen | 0.798 |  |
| 3002619 | Bacteria identified in Specimen by Culture | 0.798 | 39 |
| 3052990 | Drugs of abuse panel - Meconium | 0.798 |  |
| 1469687 | pH of Urine by pH-meter | 0.798 |  |
| 1761890 | Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.798 |  |
| 3014814 | Methamphetamine [Presence] in Urine | 0.798 | 634 |
| 3047142 | Chronic leukemia panel - Specimen by Flow cytometry (FC) | 0.796 |  |
| 44816885 | Collagen crosslinked C-telopeptide [Z-score] in Serum or Plasma | 0.795 |  |
| 46235760 | Methicillin resistant Staphylococcus aureus [Presence] in Pharynx by Organism specific culture | 0.794 |  |
| 3036941 | Urinalysis complete panel - Urine | 0.792 |  |
| 648549 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.792 |  |
| 42870522 | Lymphocyte proliferation antigen panel - Blood by Flow cytometry (FC) | 0.792 |  |
| 648844 | B-ALL minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.792 |  |
| 3019977 | pH of Arterial blood | 0.791 | 187 |
| 3003017 | Amphetamine [Presence] in Urine by Confirmatory method | 0.790 |  |
| 3006147 | Osmolality of 24 hour Urine | 0.788 |  |
| 46236733 | Noninvasive prenatal fetal 18 and 21 aneuploidy panel - Plasma cell-free DNA by Sequencing | 0.788 | 3000 |
| 647840 | CLL minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.787 |  |
| 3000144 | Amphetamine [Presence] in Urine by Screen method | 0.787 | 656 |
| 3023757 | Gas and Carbon monoxide panel - Venous blood | 0.786 |  |
| 3037242 | Nitrite [Mass/volume] in Urine | 0.786 |  |
| 37020081 | Noninvasive prenatal fetal aneuploidy and microdeletion panel - Plasma cell-free DNA by Sequencing | 0.785 |  |
| 648476 | Amphetamine+Methamphetamine [Measurement] in Urine | 0.785 |  |
| 3001405 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood | 0.784 | 441 |
| 3016901 | Lambda lymphocytes [#/volume] in Blood | 0.784 |  |
| 3007558 | Diffusion capacity.carbon monoxide adjusted for hemoglobin by Helium single breath | 0.784 |  |
| 40761558 | Sulfites [Presence] in Urine by Test strip | 0.784 |  |
| 3037426 | Urobilinogen [Presence] in Urine by Test strip | 0.783 | 134 |
| 1616796 | Gas panel - Central venous blood | 0.783 |  |
| 3027837 | Diffusion capacity adjusted to body conditions by Single breath.carbon monoxide+Helium | 0.782 |  |
| 3964699 | Gas and electrolytes point of care panel - Venous blood | 0.781 |  |
| 3045414 | Leukocytes [Presence] in Urine | 0.781 |  |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.780 |  |
| 46236732 | Noninvasive prenatal fetal 13 and 18 and 21 aneuploidy panel - Plasma cell-free DNA by Sequencing | 0.779 | 3000 |
| 36660149 | OxyCODONE and metabolites panel - Urine by Confirmatory method | 0.778 |  |
| 3032360 | Lymphocytes+Monocytes [#/volume] in Blood | 0.777 |  |
| 3027247 | Bacteria identified in Specimen | 0.777 |  |
| 46236075 | Procollagen type I.N-terminal propeptide [Mass/volume] in Serum or Plasma by Immunoassay | 0.776 |  |
| 40758490 | Osmolality of Urine--baseline | 0.775 |  |
| 43533918 | Hemoglobin [Entitic substance] in Reticulocytes by Automated count | 0.773 |  |
| 645112 | Stenotrophomonas maltophilia.multidrug resistant [Presence] in Specimen by Organism specific culture | 0.772 |  |
| 40770969 | pH of Synovial fluid by Test strip | 0.772 |  |
| 3028167 | CD3+CD4+ (T4 helper) cells [#/volume] in Blood | 0.771 | 515 |
| 3039402 | Gas panel - Mixed venous blood | 0.770 |  |
| 3023764 | Bacteria identified in Specimen by Respiratory culture | 0.769 |  |
| 3051698 | Osmolality of Urine by calculation | 0.769 |  |
| 3008905 | Diffusion capacity.carbon monoxide | 0.768 |  |
| 40765089 | Chromosome analysis panel - Blood by G-banded | 0.767 |  |
| 646446 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.766 |  |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.766 |  |
| 3003137 | Variant lymphocytes [#/volume] in Blood | 0.766 |  |
| 3008320 | Kappa lymphocytes [#/volume] in Blood | 0.766 |  |
| 36660656 | CBC W Differential panel - Stem cell product | 0.765 |  |
| 3046647 | Bacteria # 4 identified in Specimen by Culture | 0.764 |  |
| 3966204 | Leukemia and lymphoma immunophenotyping in Specimen Document by Flow cytometry (FC) | 0.763 |  |
| 648522 | CD3 cells/Lymphocytes in Bone marrow by Flow cytometry (FC) | 0.763 |  |
| 3045058 | Bacteria # 3 identified in Specimen by Culture | 0.763 |  |
| 40766210 | Pseudomonas aeruginosa.multidrug resistant isolate [Presence] in Specimen by Organism specific culture | 0.762 |  |
| 3044481 | Immunodeficiency panel - Blood by Flow cytometry (FC) | 0.762 |  |
| 645594 | Blasts assessment in Bone marrow by Flow cytometry (FC) Narrative | 0.760 |  |
| 40761511 | CBC panel - Blood by Automated count | 0.760 |  |
| 647524 | CD19-CD3-CD56+ (NK)/Cells in Bone marrow by Flow cytometry (FC) | 0.760 |  |
| 1002418 | Chromosome analysis in Blood or Tissue by Microarray | 0.759 |  |
| 3025271 | CD3-CD16+CD56+ (Natural killer) cells [#/volume] in Blood | 0.758 |  |
| 1002351 | Plasma cell DNA content and proliferation panel - Bone marrow by Flow cytometry (FC) | 0.758 |  |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.758 |  |
| 3045467 | Natural killer cell function [Units/volume] in Blood | 0.757 |  |
| 3006598 | pH of Arterial cord blood | 0.755 | 1087 |
| 3030688 | Urinalysis panel - Urine by Auto | 0.755 |  |
| 3000060 | B lymphocytes [#/volume] in Blood | 0.753 |  |
| 3965213 | Electrolytes panel - Venous blood | 0.752 |  |
| 3007449 | CD3+CD8+ (T8 suppressor) cells/cells in Blood | 0.752 | 397 |
| 1175815 | Drugs of abuse panel - Tissue | 0.750 |  |
| 3003467 | Lymphocytes [#/volume] in Body fluid | 0.748 |  |
| 3036304 | CD45 (Lymphs) cells [#/volume] in Blood | 0.747 | 2006 |
| 3026710 | Lymphocytes [#/volume] in Blood by Flow cytometry (FC) | 0.746 |  |
| 3025183 | CD4+CD25+ cells [#/volume] in Blood | 0.746 |  |
| 3029318 | Maternal screen for fetal abnormalities such as Open Neural Tube Defects, Trisomy 21 or Trisomy 18 panel - Serum or Plasma | 0.744 |  |
| 3038999 | pH of Venous blood adjusted to patient's actual temperature | 0.743 |  |
| 3004327 | Lymphocytes [#/volume] in Blood by Automated count | 0.743 | 35 |
| 40760486 | Osmolality of 12 hour Urine | 0.742 |  |
| 3042009 | Drugs identified in Urine by Confirmatory method | 0.742 | 1711 |
| 3031729 | Lymphocytes Immunoblastic [#/volume] in Blood | 0.741 |  |
| 36031493 | Protein/Osmolality [Ratio] in Urine | 0.741 |  |
| 1988420 | Gas and electrolytes panel - Arterial blood | 0.740 |  |
| 3019060 | Gas panel - Arterial blood | 0.739 |  |
| 3026757 | CD56 cells [#/volume] in Blood | 0.738 |  |
| 1617363 | Noninvasive prenatal fetal aneuploidy panel - Plasma cell-free+WBC DNA by Dosage of chromosome-specific cfDNA | 0.737 |  |
| 3028160 | Osmolality of Specimen | 0.736 |  |
| 42870588 | Differential panel, method unspecified - Blood | 0.735 |  |
| 3006400 | Diffusion capacity.carbon monoxide adjusted for hemoglobin | 0.734 |  |
| 40760138 | Urinalysis dipstick W Reflex Culture panel - Urine | 0.734 |  |
| 3032080 | INR in Blood by Coagulation assay | 0.733 | 206 |
| 3051365 | Ferritin [Entitic mass] in Red Blood Cells | 0.730 |  |
| 3015145 | Diffusion capacity.carbon monoxide Predicted | 0.730 |  |
| 40760842 | Osmolality of Urine--3rd specimen | 0.729 |  |
| 3053181 | Prothrombin time (PT) in Capillary blood by Coagulation assay | 0.727 |  |
| 46235157 | Noninvasive prenatal testing overall interpretation Qualitative | 0.727 |  |
| 3041141 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Tissue | 0.726 |  |
| 3050087 | Osmolality.urine/Osmolality.serum | 0.725 |  |
| 40765086 | Chromosome analysis.interphase panel - Blood by FISH | 0.724 |  |
| 40760841 | Osmolality of Urine--2nd specimen | 0.723 |  |
| 1617152 | Noninvasive prenatal fetal aneuploidy and 22q11.2 deletion panel - Plasma cell-free+WBC DNA by Dosage of chromosome-specific cfDNA | 0.722 |  |
| 40765085 | Chromosome analysis.metaphase panel - Blood by FISH | 0.721 |  |
| 1761703 | CD3+CD8+ (T8 suppressor) cells/cells in Blood mononuclear cells | 0.720 |  |
| 3018418 | pH of Serum or Plasma | 0.720 | 160 |
| 1617225 | Diffusion capacity.carbon monoxide --pre bronchodilation | 0.720 |  |
| 40760142 | Auto Differential panel - Blood | 0.719 |  |
| 1617299 | Diffusion capacity.carbon monoxide/Predicted | 0.719 |  |
| 21494992 | Neurological assessment [Interpretation] | 0.718 |  |
| 3038211 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Specimen | 0.718 |  |
| 3003338 | MCHC [Entitic Mass/volume] in Red Blood Cells | 0.714 |  |
| 46235811 | Reticulocyte corpuscular hemoglobin concentration mean [Mass/volume] in Blood | 0.713 |  |
| 40765090 | Chromosome analysis panel - Blood from Fetus by G-banded | 0.712 |  |
| 46236024 | Chromosome analysis basic associated observations panel - Blood or Tissue by Cytogenetics | 0.711 |  |
| 3049858 | Reticulocyte mean volume [Entitic volume] in Reticulocytes | 0.710 |  |
| 46235160 | Noninvasive prenatal fetal aneuploidy and microdeletion panel based on Plasma cell-free+WBC DNA by Dosage of chromosome-specific circulating cell free (ccf) DNA | 0.704 | 3000 |
| 3048886 | First and Second trimester integrated maternal screen panel | 0.702 |  |
| 1616566 | Diffusion capacity.carbon monoxide --post bronchodilation | 0.702 |  |
| 42870577 | Diffusion capacity.carbon monoxide/Alveolar volume adjusted for hemoglobin | 0.700 |  |
| 40765096 | Chromosome analysis panel by Banding | 0.699 |  |
| 3023329 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter | 0.698 |  |
| 3031723 | Peak flow measure duration Respiratory system airway by Peak flow meter | 0.697 |  |
| 1616954 | Amphetamines panel - Urine by Confirmatory method | 0.696 |  |
| 46235809 | Reticulocyte hemoglobin distribution width [Mass/volume] in Blood by calculation | 0.694 |  |
| 3050489 | Study report Skeletal system DXA | 0.693 |  |
| 3019794 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --post therapy | 0.692 |  |
| 42869550 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --pre therapy | 0.691 |  |
| 42528767 | Chromosome painting analysis in Blood or Tissue by FISH | 0.691 |  |
| 3042605 | INR in Platelet poor plasma or blood by Coagulation assay | 0.691 |  |
| 3043821 | Protein and Glucose panel - Urine by Test strip | 0.684 |  |
| 42529473 | Bone density quantitative measurement by DXA panel | 0.683 |  |
| 3030728 | Chromosome analysis.interphase [Interpretation] in Blood by FISH Narrative | 0.681 |  |
| 3044933 | Cardiac 2D echo panel | 0.669 |  |
| 3022217 | INR in Platelet poor plasma by Coagulation assay | 0.668 | 53 |
| 1259654 | Diagnostic multisection transesophageal and cardioversion panel Heart | 0.665 |  |
| 42528497 | Personal best peak expiratory gas flow Respiratory system airway | 0.658 |  |
| 1091430 | CT Femur [T-score] Multisection for bone density | 0.652 |  |
| 21493275 | Clotting time of Capillary blood by Sukharev method | 0.651 |  |
| 46235180 | Neurology study | 0.650 |  |
| 1092363 | CT Hip [T-score] Multisection for bone density | 0.643 |  |
| 1988764 | Electromyography panel | 0.641 |  |
| 646943 | Cough peak flow Respiratory system airway | 0.639 |  |
| 3002101 | DXA Radius and Ulna [Mass/Area] Bone density | 0.636 |  |
| 1092172 | CT Femur [Mass/volume] Multisection for bone density | 0.634 |  |
| 1091532 | CT Femur [Z-score] Multisection for bone density | 0.633 |  |
| 42868465 | Maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.632 |  |
| 3965004 | Bone DXA Calcaneus [T-score] Bone density | 0.631 |  |
| 1091772 | CT Hip [Z-score] Multisection for bone density | 0.630 |  |
| 3026358 | Preparation techniques [Type] in Cervical or vaginal smear or scraping by Cyto stain | 0.628 |  |
| 1091637 | CT Femur [Mass/Area] Multisection for bone density | 0.627 |  |
| 3041830 | Coag.tissue factor induced.PIVKA sensitive actual/normal in Capillary blood by Coagulation assay | 0.626 |  |
| 40765359 | PhenX - respiratory - peak expiratory flow rate - PEFR protocol 090801 | 0.624 |  |
| 42868466 | Maximum expiratory gas flow/Predicted maximum expiratory gas flow Respiratory system airway --pre bronchodilation | 0.624 |  |
| 3012944 | Respiratory rate 24 hour | 0.621 |  |
| 3042392 | Coag.tissue factor induced.PIVKA insensitive actual/normal in Capillary blood by Coagulation assay | 0.620 |  |
| 3049273 | DXA Radius and Ulna [T-score] Bone density | 0.617 |  |
| 21494098 | DXA Radius and Ulna [Z-score] Bone density | 0.611 |  |
| 3965513 | Bone DXA Calcaneus [Z-score] Bone density | 0.611 |  |
| 3049581 | DXA Calcaneus [T-score] Bone density | 0.609 |  |
| 1259652 | Left ventricular Ejection fraction by US.3D.A2C+Estimated | 0.608 |  |
| 3003481 | Cardiac echo study Transducer site Narrative | 0.607 |  |
| 42868479 | Apnea hypopnea index 24 hour | 0.607 |  |
| 42868488 | Positive airway pressure panel | 0.606 |  |
| 3023119 | Cardiac echo imaging device Class | 0.604 |  |
| 1002325 | Heart Left ventricular outflow tract/Maximum blood flow aortic valve by US.doppler | 0.597 |  |
| 36203319 | US Heart Transesophageal | 0.597 |  |
| 3003891 | Specimen preparation [Type] | 0.597 |  |
| 1259877 | Left ventricular Ejection fraction by US.3D.A4C+Estimated | 0.595 |  |
| 3009203 | Cardiac echo study Procedure | 0.595 |  |
| 40758294 | Paroxysmal nocturnal panel - Blood | 0.593 |  |
| 1988411 | Permanent pacemaker panel | 0.590 |  |
| 21494996 | Respiratory assessment panel | 0.585 |  |
| 3015588 | Electromyogram study | 0.582 |  |
| 36031935 | Sedation panel NPASS | 0.580 |  |
| 21493450 | Pulmonary function test panel | 0.579 |  |
| 3044016 | Orthostatic blood pressure panel | 0.579 |  |
| 3020855 | Comparison study [Interpretation] by EKG | 0.574 |  |
| 21491904 | Overall study interpretation Left retina by EOG | 0.573 |  |
| 21491925 | Overall study interpretation Left retina by ERG | 0.568 |  |
| 21491903 | Overall study interpretation Right retina by EOG | 0.567 |  |
| 46235082 | Evoked potential study | 0.565 |  |
| 3016825 | Microscopic observation [Identifier] in Body fluid by Cyto stain | 0.555 |  |
| 21491924 | Overall study interpretation Right retina by ERG | 0.552 |  |
| 3030078 | Cell type in Specimen | 0.550 |  |
| 3049361 | Cytology report of Specimen Cyto stain | 0.549 |  |
| 3010479 | Ambulatory cardiac rhythm monitor (Holter) study | 0.548 |  |
| 36660247 | Specimen Processing comment | 0.547 |  |
| 3025986 | Microscopic observation [Identifier] in Specimen by Cyto stain | 0.544 | 1498 |
| 3022667 | Microscopic observation [Identifier] in Cervix by Wet preparation | 0.542 |  |
| 1988318 | Temporary pacemaker panel | 0.542 |  |
| 3036843 | Microscopic observation [Identifier] in Soft tissue fine needle aspirate by Cyto stain | 0.542 |  |
| 3025378 | Microscopic observation [Identifier] in Cervix by Cyto stain | 0.541 | 484 |
| 3050453 | Amino acid pattern [Interpretation] in Cerebral spinal fluid Narrative | 0.539 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 218 | -histologinensolublokkisytologisestanäytteestä |  | 100% | name | 214 | 100 |  |  |  |  | Cell block preparation [Process] in Cytology material |
| 219 | -humanpapillomavirusgenotyyppi16 |  | 100% | name | 301 | 100 |  |  |  |  | Human papillomavirus 16 DNA [Presence] in Cervix by NAA with probe detection |
| 220 | -humanpapillomavirusgenotyyppi18 |  | 100% | name | 301 | 100 |  |  |  |  | Human papillomavirus 18 DNA [Presence] in Cervix by NAA with probe detection |
| 221 | -humanpapillomavirusgenotyyppimuupatogeeninenhpv |  | 100% | name | 252 | 100 |  |  |  |  | Human papillomavirus high risk types DNA [Presence] in Cervix by NAA with probe detection |
| 222 | -lisämaksukiireellisenäpyydetyllenäytteelle |  | 100% | name | 584 | 100 |  |  |  |  |  |
| 223 | -lisätutkimuspyyntöaiemmintutkitullenäytteelle |  | 100% | name | 191 | 100 |  |  |  |  |  |
| 224 | -lisävastaus2laskutuskuitatullenäytteelle |  | 100% | name | 438 | 100 |  |  |  |  |  |
| 225 | -lisävastauslaskutuskuitatullenäytteelle |  | 100% | name | 2865 | 100 |  |  |  |  |  |
| 226 | -moniresistentitgram-negatiivisetsauvat,viljely |  | 100% | name | 122 | 100 |  |  |  |  | Bacteria gram negative multidrug resistant identified in Specimen by Culture |
| 227 | -moniresistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 163 | 100 |  |  |  |  | Bacteria gram negative multidrug resistant identified in Specimen by Culture |
| 228 | -resistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 314 | 100 |  |  |  |  | Bacteria gram negative multidrug resistant identified in Specimen by Culture |
| 229 | -staphylococcusaureus,metilliiniresist.viljely |  | 100% | name | 248 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Specimen by Organism specific culture |
| 230 | -staphylococcusaureus,metisilliiniresistentti,v |  | 100% | name | 540 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Specimen by Organism specific culture |
| 231 | b-glukoosi,hoitoyksikönvieritesti,kokoveri |  | 100% | name+values | 687 | 100 | [5.67, 6.19, 6.85, 7.42, 8.13, 9, 9.86, 11.05, 13.55] |  | Blood |  | Glucose [Moles/volume] in Blood |
| 232 | b-hematologisenpotilaanperuskaryotyypinmääritys |  | 100% | name | 125 | 100 |  |  | Blood |  | Chromosome analysis.Karyotype in Blood |
| 233 | b-kreatiniini,hoitoyksikönvieritesti,veri |  | 100% | name+values | 167 | 100 | [57.92, 69.09, 76.79, 84.4, 95.96, 104.83, 115.95, 134.6, 169.03] |  | Blood |  | Creatinine [Moles/volume] in Blood |
| 234 | bakteerit,virtsasta,partikkelinlaskijalla,osatutk. |  | 100% | name | 212 | 100 |  |  |  |  | Bacteria [#/volume] in Urine by Automated count |
| 235 | bm-pahanlaatuisenveritaudinimmunofenotyypitys |  | 100% | name | 191 | 100 |  |  | Bone marrow |  | Leukocyte immunophenotyping panel by Flow cytometry (FC) - Bone marrow |
| 236 | bm-pahanlaatuisenveritaudinimmunofenotyyppinenjäännöstautianalyysi |  | 100% | name | 162 | 100 |  |  | Bone marrow |  | Minimal residual disease in Bone marrow by Flow cytometry (FC) |
| 237 | cb-hemoglobiini,vieritestihoitoyksikössä | g/l | 100% | name+unit+values | 101 | 0 | [85, 92.1, 99, 112.31, 121.33, 126.93, 131.68, 135.77, 146] |  | Capillary blood |  | Hemoglobin [Mass/volume] in Capillary blood |
| 238 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä | mmol/l | 100% | name+unit+values | 5203 | 0 | [5.29, 6.24, 7.08, 7.99, 9.06, 10.25, 11.87, 13.98, 17.04] |  |  |  | Glucose [Moles/volume] in Capillary blood |
| 239 | cp-glukoosi,ihopistosn,vieritestihoitoyksikössä |  | 0% | name | 19 | 100 |  |  |  |  | Glucose [Moles/volume] in Capillary blood |
| 240 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella | mg/l | 80% | name+unit+values | 771 | 0 | [2.64, 5.11, 9.64, 14.77, 21.85, 32.33, 47.97, 68.93, 107.02] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 241 | crp-pitoisuus,hoitoyksikkömittaavieritestilaitteella |  | 20% | name | 192 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 242 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 97% | name+unit+values | 438 | 0 | [26.94, 29.96, 31.93, 33, 34, 34.57, 35, 36, 37.55] |  | Erythrocyte |  | Reticulocyte.hemoglobin [Entitic mass] in Red Blood Cells |
| 243 | e-retikulosyyttienkeskimääräinenhemoglobiininmäärä |  | 3% | name | 15 | 100 |  |  | Erythrocyte |  | Reticulocyte.hemoglobin [Entitic mass] in Red Blood Cells |
| 244 | emäsylimäärä,laskimoverestä,pikatesti␤ | mmol/l | 52% | name+unit+values | 373 | 0 | [0, 0.83, 1, 1.91, 2, 3, 4, 5.5, 7.33] |  |  |  | Base excess [Moles/volume] in Venous blood |
| 245 | emäsylimäärä,laskimoverestä,pikatesti␤ |  | 48% | name+values | 339 | 100 | [-10.27, -7.62, -6, -5, -4, -3.15, -3, -2.01, -2] |  |  |  | Base excess [Moles/volume] in Venous blood |
| 246 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 96% | name+unit+values | 203 | 0 | [0.2, 0.4, 0.66, 1, 1.3, 1.74, 2.5, 3.68, 8.22] |  |  |  | Epithelial cells [#/volume] in Urine by Automated count |
| 247 | epiteelisolut,virtsasta,partikkelinlaskijalla,osatutk. |  | 4% | name | 9 | 100 |  |  |  |  | Epithelial cells [#/volume] in Urine by Automated count |
| 248 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta | iu/ml | 9% | name+unit | 24 | 0 |  |  |  |  | Epstein-Barr virus DNA [Units/volume] in Plasma by NAA with probe detection |
| 249 | epstein-barrvirus(ebv),nhkvantitatiivinen,plasmasta |  | 91% | name | 241 | 100 |  |  |  |  | Epstein-Barr virus DNA [Presence] in Plasma by NAA with probe detection |
| 250 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 95% | name+unit+values | 202 | 0 | [3.17, 4.33, 5.71, 7.18, 9.35, 12.21, 16.76, 32.31, 99.28] |  |  |  | Erythrocytes [#/volume] in Urine by Automated count |
| 251 | erytrosyytit,virtsasta,partikkelinlaskijalla,osatutk. |  | 5% | name | 10 | 100 |  |  |  |  | Erythrocytes [#/volume] in Urine by Automated count |
| 252 | fp-kollageenii:nbeta-karboksiterminaalinentelopeptidi | ug/l | 100% | name+unit+values | 299 | 0 | [0.08, 0.14, 0.17, 0.21, 0.26, 0.3, 0.36, 0.45, 0.62] |  | Fasting plasma |  | Collagen type I cross-linked C-telopeptide.beta [Mass/volume] in Fasting Plasma |
| 253 | happamusaste,kapillaariverestä,pikatesti␤ |  | 100% | name+values | 1262 | 100 | [7.35, 7.38, 7.39, 7.4, 7.41, 7.42, 7.44, 7.45, 7.47] |  |  |  | pH of Capillary blood |
| 254 | happamuusaste,laskimoverestä,pikatesti␤ |  | 100% | name+values | 712 | 100 | [7.29, 7.33, 7.36, 7.37, 7.39, 7.4, 7.41, 7.43, 7.45] |  |  |  | pH of Venous blood |
| 255 | happiosapaine,kapillaariverestä,pikatesti␤ | kpa | 100% | name+unit+values | 1260 | 0 | [5.69, 6, 6.94, 7, 7.32, 8, 8.07, 9, 10] |  |  |  | Oxygen [Partial pressure] in Capillary blood |
| 256 | happoemästasejahappi,laskimoverestä,pikatesti␤ |  | 100% | name | 643 | 100 |  |  |  |  | Blood gas panel - Venous blood |
| 257 | hepatiittic-virus,nh,jatkotutkimus,plasmasta |  | 100% | name | 512 | 100 |  |  |  |  | Hepatitis C virus RNA [Presence] in Plasma by NAA with probe detection |
| 258 | hiilidioksidiosapaine,laskimoverestä,pikatesti␤ | kpa | 100% | name+unit+values | 707 | 0 | [4.3, 4.68, 4.95, 5.18, 5.49, 5.73, 6.01, 6.38, 7.01] |  |  |  | Carbon dioxide [Partial pressure] in Venous blood |
| 259 | hpv-gt16aptimapanther,apututkimustulostensiirtoon |  | 100% | name | 149 | 100 |  |  |  |  | Human papillomavirus 16 DNA [Presence] in Cervix by NAA with probe detection |
| 260 | hpv-gt18-45aptimapanther,apututkimustulostensiirtoon |  | 100% | name | 149 | 100 |  |  |  |  | Human papillomavirus 18 & 45 DNA [Presence] in Cervix by NAA with probe detection |
| 261 | hpvaptimapanther,apututkimustulostensiirtoon |  | 100% | name | 413 | 100 |  |  |  |  | Human papillomavirus high risk types DNA [Presence] in Cervix by NAA with probe detection |
| 262 | humanimmunodeficiencyvirus,antigeenijavasta- |  | 100% | name | 192 | 100 |  |  |  |  | HIV 1+2 p24 Ag+Ab [Presence] in Serum or Plasma by Immunoassay |
| 263 | humanimmunodeficiencyvirus,antigeenijavasta-aineet,yhd |  | 100% | name | 260 | 100 |  |  |  |  | HIV 1+2 p24 Ag+Ab [Presence] in Serum or Plasma by Immunoassay |
| 264 | huume-jalääkeainetutkimus,laaja,varmistus |  | 100% | name | 448 | 100 |  |  |  |  | Drugs of abuse confirmation panel |
| 265 | huumeseulonta,kvalitatiivinen,virtsasta␤ |  | 100% | name | 140 | 100 |  |  |  |  | Drugs of abuse screen panel - Urine |
| 266 | kalium,hoitoyksikönvieritesti,veri | mmol/l | 36% | name+unit+values | 166 | 0 | [3.34, 3.66, 3.8, 3.9, 4.01, 4.19, 4.3, 4.4, 4.6] |  |  |  | Potassium [Moles/volume] in Blood |
| 267 | kalium,hoitoyksikönvieritesti,veri |  | 64% | name+values | 290 | 100 | [3.37, 3.6, 3.72, 3.89, 4, 4.19, 4.3, 4.49, 4.83] |  |  |  | Potassium [Moles/volume] in Blood |
| 268 | kreatiniini,hoitoyksikönvieritesti,veri | mmol/l | 100% | name+unit+values | 163 | 0 | [61.15, 69.04, 74.66, 78.71, 84.6, 94.36, 102.3, 112.64, 146.9] |  |  |  | Creatinine [Moles/volume] in Blood |
| 269 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 99% | name+unit+values | 874 | 0 | [2.19, 3.1, 4.19, 5.55, 6.81, 8.5, 10.54, 13.16, 17.83] |  |  |  | Creatinine [Moles/volume] in Urine |
| 270 | kreatiniini,virtsasta(huumeseulonnanyhteydessä) |  | 1% | name | 6 | 100 |  |  |  |  | Creatinine [Moles/volume] in Urine |
| 271 | laajahuumeseulonta,varmistustasoinen,virtsasta |  | 100% | name | 944 | 100 |  |  |  |  | Drugs of abuse confirmation panel - Urine |
| 272 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. | e6/l | 96% | name+unit+values | 203 | 0 | [0, 0, 0, 0, 0, 0, 0, 0.1, 0.4] |  |  |  | Casts [#/volume] in Urine by Automated count |
| 273 | lieriöt,virtsasta,partikkelinlaskijalla,osatutk. |  | 4% | name | 9 | 100 |  |  |  |  | Casts [#/volume] in Urine by Automated count |
| 274 | lisävastauslaskutuskuitatullenäytteelle |  | 100% | name | 214 | 100 |  |  |  |  |  |
| 275 | luuntiheysmittaus,2kohdetta(nk6sa),lausuttuna |  | 100% | name | 145 | 100 |  |  |  |  | Bone density study, 2 sites with interpretation |
| 276 | marevan-hoidonseur.tatesti,hoitoyksikkötekeesormenpäänäyte |  | 100% | name | 168 | 100 |  |  |  |  | INR in Capillary blood |
| 277 | moniresistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 206 | 100 |  |  |  |  | Bacteria gram negative multidrug resistant identified in Specimen by Culture |
| 278 | natrium,hoitoyksikönvieritesti,veri | mmol/l | 36% | name+unit+values | 163 | 0 | [132.82, 135, 136.55, 138, 138.97, 139.52, 140, 141, 142.23] |  |  |  | Sodium [Moles/volume] in Blood |
| 279 | natrium,hoitoyksikönvieritesti,veri |  | 64% | name+values | 292 | 100 | [131.15, 133.89, 135.97, 137.34, 138.73, 139.47, 140, 141, 142] |  |  |  | Sodium [Moles/volume] in Blood |
| 280 | natriureettinenpeptidi,b-tyypinn-terminaalinenpropeptidi,plasmasta | ng/l | 100% | name+unit+values | 159 | 0 | [27.23, 51.68, 104.13, 291.48, 592.33, 1344.4, 2902.92, 5512.78, 11171.35] |  |  |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma |
| 281 | nk-solujenosuus(määritettynäcd3-/cd16+/cd56+-soluina) | % | 100% | name+unit+values | 665 | 0 | [4, 6.9, 9.82, 12.42, 14.78, 17.15, 21.39, 27.07, 37.23] |  |  |  | NK cells/Lymphocytes [Volume Fraction] in Blood |
| 282 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. | mosm/kgh2o | 96% | name+unit+values | 203 | 0 | [331.07, 376.3, 432.78, 501.52, 539.44, 595.89, 633.34, 686.56, 750.67] |  |  |  | Osmolality [Osmolality] in Urine |
| 283 | osmolaliteetti,virtsasta,partikkelinlaskijalla,osatutk. |  | 4% | name | 9 | 100 |  |  |  |  | Osmolality [Osmolality] in Urine |
| 284 | p-natriureett.peptidin-termin.propept.vieritl | ng/l | 86% | name+unit+values | 118 | 0 | [137, 226.57, 313.72, 706.7, 1152, 1687.1, 2121.1, 3414.67, 4894.4] |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma |
| 285 | p-natriureett.peptidin-termin.propept.vieritl |  | 14% | name | 20 | 100 |  |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma |
| 286 | p-natriureettinenpeptidi,b-tyypinn-terminaalin | ng/l | 97% | name+unit+values | 4682 | 0 | [86.78, 151.71, 238.42, 386.57, 654.19, 1074.93, 1786.88, 3080.95, 6168.61] |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma |
| 287 | p-natriureettinenpeptidi,b-tyypinn-terminaalin |  | 3% | name | 149 | 100 |  |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma |
| 288 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi | ng/l | 93% | name+unit+values | 1366 | 0 | [104.73, 192.2, 313.28, 532.11, 917.12, 1448.3, 2324.68, 3800.52, 7047.17] |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma |
| 289 | p-natriureettinenpeptidi,b-tyypn-term.propeptidi |  | 7% | name | 107 | 100 |  |  | Plasma |  | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Plasma |
| 290 | parasiitit,ulosteesta(alkueläintenkystat,madot,madonmunat,toukat) |  | 100% | name | 120 | 100 |  |  |  |  | Ova and Parasites identified in Stool by Microscopy |
| 291 | pienikudoskoepala,enintään1-3samankokonaisuudennäytettä |  | 100% | name | 234 | 100 |  |  |  |  | Microscopic observation [Identifier] in Tissue by H&E stain |
| 292 | pika:m10inabnhp,rsvnhp,cv19nhp,yhdistelmävierit. |  | 100% | name | 267 | 100 |  |  |  |  | Influenza virus A+B & Respiratory syncytial virus & SARS-CoV-2 (COVID-19) Ag panel - Nasopharynx by Rapid immunoassay |
| 293 | pt-diffuusiokapasiteetti,single-breath-menetelmä,tavallinenperusmittaus |  | 100% | name | 3577 | 100 |  |  | Patient |  | Carbon monoxide diffusing capacity in Lung by Single breath |
| 294 | pt-lausuntoneurofysiologisestatutkimuksesta,hälytysindikaatiot |  | 100% | name | 113 | 100 |  |  | Patient |  | Neurophysiology study [Interpretation] |
| 295 | pt-luuntiheysmittaus,2kohdetta,ilmanlausuntoa |  | 100% | name | 120 | 100 |  |  | Patient |  | Bone density study, 2 sites |
| 296 | pt-sydämenkattavarakenteellinenjatoiminnallinenuä(fm1ee) |  | 100% | name | 177 | 100 |  |  | Patient |  | Echocardiogram.Doppler+color flow+2D.complete - Heart |
| 297 | pt-uloshengityksenhuippuvirtaus,vuorokausivaihtelunseuranta |  | 100% | name | 474 | 100 |  |  | Patient |  | Expiratory peak flow during 24 hour |
| 298 | pt-yöpolygrafia,ambulatorinen,hyvinsuppeaunirekisteröintikotona |  | 100% | name | 542 | 100 |  |  | Patient |  | Polysomnography panel.ambulatory limited |
| 299 | pt-yöpolygrafia,ambulatorinen,jalkaliikerekisteröinnein |  | 100% | name | 102 | 100 |  |  | Patient |  | Polysomnography panel.ambulatory with leg movement |
| 300 | pu-aerobinenjaanaerobinenbakteerityypitysjaan |  | 100% | name | 147 | 100 |  |  | Pus |  | Bacteria identified in Pus by Aerobic and Anaerobic culture |
| 301 | resistentitgramnegatiivisetsauvat,viljely |  | 100% | name | 320 | 100 |  |  |  |  | Bacteria gram negative multidrug resistant identified in Specimen by Culture |
| 302 | retikulosyyttienkeskimääräinenhemoglobiininmäärä | pg | 100% | name+unit+values | 525 | 0 | [26.55, 29.82, 31.74, 32.87, 33.78, 34, 35, 35.94, 37] |  |  |  | Reticulocyte.hemoglobin [Entitic mass] in Red Blood Cells |
| 303 | s-humanimmunodeficiencyvirus,antigeenijavast |  | 100% | name | 1221 | 100 |  |  | Serum |  | HIV 1+2 p24 Ag+Ab [Presence] in Serum by Immunoassay |
| 304 | sikiöperäisendna:ntutkimusäidinverinäytteestä |  | 100% | name | 104 | 100 |  |  |  |  | Non-invasive prenatal testing panel - Maternal blood |
| 305 | staphylococcusaureus,metisilliiniresistenssiviljely␤ |  | 100% | name | 134 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Specimen by Organism specific culture |
| 306 | staphylococcusaureus,metisilliiniresistentti(mrsa),viljely |  | 100% | name | 627 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant identified in Specimen by Organism specific culture |
| 307 | t-auttajasolujenosuus(määritettynäcd3+cd4+soluina) | % | 100% | name+unit+values | 665 | 0 | [12.27, 17.13, 20.74, 25.08, 31.09, 37.49, 46.86, 52.29, 60.29] |  | Thrombocyte |  | T-helper cells/Lymphocytes [Volume Fraction] in Blood |
| 308 | t-estäjäsolujenosuus(määritettynäcd3+cd8+soluina) | % | 100% | name+unit+values | 665 | 0 | [14.47, 20.34, 23.97, 27.07, 31.95, 36.95, 44.67, 52.96, 66.49] |  | Thrombocyte |  | T-suppressor cells/Lymphocytes [Volume Fraction] in Blood |
| 309 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella | ng/l | 7% | name+unit | 7 | 0 |  |  |  |  | Troponin T [Mass/volume] in Serum or Plasma |
| 310 | troponiini-t-pit.hoitoyksikkötekeevieritestilaitteella |  | 93% | name | 97 | 100 |  |  |  |  | Troponin T [Mass/volume] in Serum or Plasma |
| 311 | ts-histologinentutkimus,1-3kudosnäytettä |  | 100% | name | 160 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by H&E stain |
| 312 | ts-histologinentutkimus,1-3näytettä |  | 100% | name | 945 | 100 |  |  | Tissue |  | Microscopic observation [Identifier] in Tissue by H&E stain |
| 313 | työpaikanhuumeseulontajavarmistus,4yhdistettä |  | 100% | name | 469 | 100 |  |  |  |  | Workplace drugs of abuse screen and confirmation panel |
| 314 | työpaikanhuumeseulontajavarmistus,7yhdistettä |  | 100% | name | 312 | 100 |  |  |  |  | Workplace drugs of abuse screen and confirmation panel |
| 315 | täydellinennimi:pt-näytteenotto0maksu,kierronulkopuolisetnäytteet |  | 100% | name | 1481 | 100 |  |  |  |  |  |
| 316 | täydellinenverenkuva,sis.perusverenkuvanjaleukosyyttienerittelylaskennan␤ |  | 100% | name | 9742 | 100 |  |  |  |  | CBC with Differential panel - Blood |
| 317 | u-amfetamiinijametamfetamiini,enantiomeerienerittely |  | 100% | name | 120 | 100 |  |  | Urine |  | Amphetamine & Methamphetamine enantiomers [Presence] in Urine by Chromatography |
| 318 | u-asetoniaineet,kval,vieritestihoitoyksikössä |  | 100% | name | 421 | 100 |  |  | Urine |  | Ketones [Presence] in Urine by Test strip |
| 319 | u-erytrosyytit,kval,vieritestihoitoyksikössä |  | 100% | name | 413 | 100 |  |  | Urine |  | Hemoglobin [Presence] in Urine by Test strip |
| 320 | u-glukoosi,kvalvieritestihoitoyksikössä |  | 100% | name | 423 | 100 |  |  | Urine |  | Glucose [Presence] in Urine by Test strip |
| 321 | u-happamuusaste,vieritestihoitoyksikössä |  | 100% | name+values | 400 | 100 | [5.5, 5.5, 5.5, 5.9, 6, 6, 6.5, 6.95, 7] |  | Urine |  | pH of Urine by Test strip |
| 322 | u-huume-jalääkeainetutkimus,laaja,varmistus |  | 100% | name | 175 | 100 |  |  | Urine |  | Drugs of abuse confirmation panel - Urine |
| 323 | u-huume-jalääkeainetutkimus,semikvantitatiivinen,virtsa␤sta |  | 100% | name | 121 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 324 | u-huumeseulonta,laaja(kvalitatiivinenlc-tof-ms) |  | 100% | name | 144 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine by Screen method |
| 325 | u-kemiallinenseulonta,vieritestihoitoyksikössä |  | 100% | name | 104 | 100 |  |  | Urine |  | Urinalysis macro (dipstick) panel - Urine |
| 326 | u-kreatiniini,virtsasta(huumeseulonnanyhteydessä) | mmol/l | 100% | name+unit+values | 398 | 0 | [2.12, 2.87, 3.64, 4.69, 6, 7.64, 9.64, 12.49, 16.58] |  | Urine |  | Creatinine [Moles/volume] in Urine |
| 327 | u-laajahuume-jalääkeainetutkimus,semikvantitatiivinen |  | 100% | name | 421 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine |
| 328 | u-leukosyytit,kval,vieritestihoitoyksikössä |  | 100% | name | 429 | 100 |  |  | Urine |  | Leukocyte esterase [Presence] in Urine by Test strip |
| 329 | u-nitriitti,kval,vieritestihoitoyksikössä |  | 100% | name | 421 | 100 |  |  | Urine |  | Nitrite [Presence] in Urine by Test strip |
| 330 | u-proteiini,kval,vieritestihoitoyksikössä |  | 100% | name | 425 | 100 |  |  | Urine |  | Protein [Presence] in Urine by Test strip |
| 331 | vieritestilaite(epoc)verikaasuanalyysilaskimonäytteestä |  | 100% | name | 162 | 100 |  |  |  |  | Blood gas panel - Venous blood |
| 332 | yersinia(lajitenterocolitica,pseudotuberculosis,pestis)nho,ulosteesta␤ |  | 100% | name | 484 | 100 |  |  |  |  | Yersinia sp DNA [Presence] in Stool by NAA with probe detection |

