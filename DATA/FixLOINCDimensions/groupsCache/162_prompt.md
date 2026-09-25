[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

**Those guesses exist only to fetch the candidate list. They have already done their job, and they carry no authority over your decision.** The earlier pass was told to write a name whenever the code gave it anything at all to work with, because a near-miss still retrieves the right neighbourhood of concepts while silence retrieves nothing. So a guess may be a careful reading or a shot in the dark, and nothing marks which. Use it as a pointer to where in the vocabulary to look, never as an answer to confirm. **Decide from the row's own `TEST_NAME`, `LongName`, `UNIT` and `deciles`.** When the row's evidence and the guess disagree, the row wins.

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
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess, which is what the search was run on. A search query, not a hypothesis you owe any deference to: it was written under instructions to guess rather than stay silent, so its confidence is not calibrated and a fluent name may rest on very little. When it is a panel name, the earlier pass judged the code to order a bundle rather than report one result — check that against the code yourself.

# How to read the evidence

A row is one **`TEST_NAME` + `UNIT`** combination, and that pair is what you are naming. Two rows of the same code with different units are two different observations and may well belong to two different LOINC concepts. Decide each row on its own.

**The name is the source of truth.** `prefix_meaning` and `suffix_meaning` were derived from the `TEST_NAME` string by an earlier step, so when a name is misspelled, truncated or locally invented, the decoded prefix and suffix are wrong in exactly the same way. Treat them as extra information that can confirm what the name says — never as something that outranks it. The specimen in particular is often spelled out as a Finnish word rather than carried by a prefix: `veri` = blood, `seerumi` = serum, `plasma` = plasma, `virtsa` = urine, `likvori` = cerebrospinal fluid, `uloste` = feces, `sylki` = saliva. `c-reaktiivinenproteiini,pikatesti,veri` names blood and has no decoded prefix at all — and its leading `c-` is the start of "C-reactive", not a specimen code.

**Missing values are not evidence.** `p_missing` describes this extract, not the laboratory test: a row with no values is a row where the numbers were not recorded or not carried through. Never conclude "no numbers, therefore qualitative". A test is qualitative when the CODE says so — the `-O` suffix, a `LongName` naming a qualitative or screening test, a component only ever reported as detected/not-detected.

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

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
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
| 1616794 | Bicarbonate [Moles/volume] in Central venous blood | 1.000 |  |
| 3003458 | Phosphate [Moles/volume] in Serum or Plasma | 1.000 | 69 |
| 3007220 | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 90 |
| 3008152 | Bicarbonate [Moles/volume] in Arterial blood | 1.000 | 310 |
| 3008342 | Neutrophils/Leukocytes in Blood by Automated count | 1.000 | 25 |
| 3010457 | Eosinophils/Leukocytes in Blood by Automated count | 1.000 | 43 |
| 3011948 | Monocytes/Leukocytes in Blood by Automated count | 1.000 | 44 |
| 3011985 | Renin [Units/volume] in Plasma | 1.000 |  |
| 3013869 | Basophils/Leukocytes in Blood by Automated count | 1.000 | 42 |
| 3016436 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 156 |
| 3019309 | Folate [Moles/volume] in Red Blood Cells | 1.000 | 743 |
| 3027273 | Bicarbonate [Moles/volume] in Venous blood | 1.000 | 781 |
| 3034780 | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 730 |
| 3035995 | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 23 |
| 3037511 | Lymphocytes/Leukocytes in Blood by Automated count | 1.000 | 41 |
| 3044889 | 12 lead EKG panel | 1.000 |  |
| 3045066 | Thymidine kinase [Enzymatic activity/volume] in Serum | 1.000 |  |
| 3000067 | Parathyrin.intact [Mass/volume] in Serum or Plasma | 0.979 | 240 |
| 3010566 | Parathyrin.intact [Moles/volume] in Serum or Plasma | 0.976 | 240 |
| 3007628 | Bicarbonate [Moles/volume] standard in Venous blood | 0.973 |  |
| 3014218 | Bicarbonate [Moles/volume] standard in Arterial blood | 0.968 |  |
| 3005772 | Bilirubin.conjugated [Moles/volume] in Serum or Plasma | 0.967 |  |
| 3004490 | Bicarbonate [Moles/volume] standard in Capillary blood | 0.966 |  |
| 3005783 | Lactate dehydrogenase 1 [Enzymatic activity/volume] in Serum or Plasma | 0.964 |  |
| 46235077 | Alkaline phosphatase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.960 |  |
| 3017861 | Lactate dehydrogenase 2 [Enzymatic activity/volume] in Serum or Plasma | 0.959 |  |
| 3001110 | Alkaline phosphatase [Enzymatic activity/volume] in Blood | 0.952 |  |
| 723477 | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.952 |  |
| 3006769 | Lactate dehydrogenase 3 [Enzymatic activity/volume] in Serum or Plasma | 0.949 |  |
| 3020779 | Urea [Moles/volume] in Serum or Plasma | 0.947 |  |
| 3015956 | Eosinophils/Leukocytes in Blood by Manual count | 0.946 | 229 |
| 3025124 | Lactate dehydrogenase 4 [Enzymatic activity/volume] in Serum or Plasma | 0.945 |  |
| 3022250 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma by Lactate to pyruvate reaction | 0.944 |  |
| 3036335 | Angiotensin converting enzyme [Enzymatic activity/volume] in Blood | 0.943 | 1299 |
| 3027010 | Lactate dehydrogenase 5 [Enzymatic activity/volume] in Serum or Plasma | 0.942 |  |
| 1617100 | Bicarbonate [Moles/volume] standard in Central venous blood | 0.942 |  |
| 3009797 | Basophils/Leukocytes in Blood by Manual count | 0.941 | 235 |
| 40762896 | Parathyrin.intact [Mass/volume] in Body fluid | 0.940 |  |
| 42868453 | Bicarbonate [Moles/volume] standard in Plasma | 0.937 |  |
| 36033641 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.936 |  |
| 3022407 | Monocytes/Leukocytes in Blood by Manual count | 0.934 | 225 |
| 3043821 | Protein and Glucose panel - Urine by Test strip | 0.934 |  |
| 1175563 | Parathyrin.intact [Mass/volume] in Serum or Plasma by Immunoassay | 0.933 |  |
| 3037310 | Renin [Mass/volume] in Plasma | 0.932 |  |
| 3033973 | Parathyrin.intact [Mass/volume] in Serum or Plasma --baseline | 0.931 |  |
| 3029790 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma | 0.931 | 374 |
| 3035400 | Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma | 0.930 | 1919 |
| 3016293 | Bicarbonate [Moles/volume] in Serum or Plasma | 0.930 |  |
| 3005225 | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma by Pyruvate to lactate reaction | 0.929 |  |
| 40771025 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma | 0.929 |  |
| 3018913 | Phosphate [Moles/volume] in Blood | 0.928 |  |
| 3035569 | Folate [Mass/volume] in Red Blood Cells | 0.928 |  |
| 3052240 | Parathyrin.intact [Moles/volume] in Serum or Plasma --baseline | 0.928 |  |
| 3015235 | Bicarbonate [Moles/volume] in Capillary blood | 0.928 | 1086 |
| 37021550 | Renin [Units/volume] in Plasma --upright | 0.926 |  |
| 1616938 | Parathyrin.intact [Moles/volume] in Body fluid | 0.926 |  |
| 3029315 | Leukocytes [#/volume] in Urine by Automated count | 0.925 |  |
| 3027368 | Neutrophils/Leukocytes in Blood by Manual count | 0.925 | 1191 |
| 43534077 | Urea [Moles/volume] in Blood | 0.925 |  |
| 37019676 | Renin [Units/volume] in Plasma --supine | 0.923 |  |
| 36031886 | Parathyrin.intact [Moles/volume] in Serum or Plasma by Immunoassay | 0.923 |  |
| 757685 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.923 |  |
| 3002385 | Erythrocyte distribution width [Ratio] | 0.922 |  |
| 3015531 | Creatine kinase.macromolecular [Enzymatic activity/volume] in Serum or Plasma | 0.919 |  |
| 3020013 | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum or Plasma | 0.918 |  |
| 46235781 | Urea [Moles/volume] in Serum, Plasma or Blood | 0.918 |  |
| 3007869 | Lactate dehydrogenase [Enzymatic activity/volume] in Specimen | 0.917 |  |
| 3024390 | 25-hydroxyvitamin D3 [Moles/volume] in Serum or Plasma | 0.916 | 127 |
| 3007808 | Renin [Enzymatic activity/volume] in Plasma | 0.915 | 822 |
| 3033622 | Lymphocytes/Leukocytes in Specimen by Automated count | 0.914 |  |
| 3050084 | Parathyrin.intact [Mass/volume] in Serum or Plasma --pre dose calcium | 0.914 |  |
| 3028531 | Enolase.neuron specific [Mass/volume] in Serum or Plasma | 0.914 |  |
| 3007970 | Alkaline phosphatase.bile [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |
| 43055372 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.913 |  |
| 3020233 | Acid phosphatase [Enzymatic activity/volume] in Serum or Plasma | 0.913 |  |
| 3006576 | Bicarbonate [Moles/volume] in Blood | 0.912 | 120 |
| 645314 | Parathyrin.intact [Measurement] in Serum or Plasma | 0.911 |  |
| 3001467 | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum or Plasma | 0.911 | 1850 |
| 3038058 | Lymphocytes/Leukocytes in Blood by Manual count | 0.911 | 186 |
| 3011185 | Granulocytes/Leukocytes in Blood by Automated count | 0.910 |  |
| 3051659 | 25-hydroxyvitamin D2 [Moles/volume] in Serum or Plasma | 0.910 | 661 |
| 3011904 | Phosphate [Mass/volume] in Serum or Plasma | 0.909 |  |
| 36032419 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Immunoassay | 0.908 |  |
| 3001077 | Alkaline phosphatase [Enzymatic activity/volume] in Urine | 0.907 |  |
| 36303407 | Parathyrin.intact goal [Mass/volume] Serum or Plasma | 0.906 |  |
| 43055373 | Basophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.906 |  |
| 3002214 | Alkaline phosphatase.renal [Enzymatic activity/volume] in Serum or Plasma | 0.905 |  |
| 3027184 | Lupus anticoagulant [Interpretation] in Platelet poor plasma | 0.905 |  |
| 3028961 | Parathyrin.intact [Mass/volume] in Serum or Plasma --5th specimen | 0.904 |  |
| 3003860 | Alkaline phosphatase.regan [Enzymatic activity/volume] in Serum or Plasma | 0.903 |  |
| 3017427 | Lupus anticoagulant neutralization dilute phospholipid [Presence] in Platelet poor plasma | 0.903 | 1189 |
| 40765008 | Erythrocyte distribution width [Ratio] in Blood from Fetus by Automated count | 0.902 |  |
| 3016213 | Lactate dehydrogenase 2 [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.902 |  |
| 3024641 | Urea nitrogen [Moles/volume] in Serum or Plasma | 0.900 |  |
| 3030413 | Parathyrin.intact [Mass/volume] in Serum or Plasma --4th specimen | 0.900 |  |
| 1761840 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Specimen by NAA with probe detection | 0.900 |  |
| 3005090 | Alkaline phosphatase [Enzymatic activity/volume] in Body fluid | 0.899 |  |
| 1091634 | Fungus [Presence] in Specimen | 0.898 |  |
| 3006538 | Bicarbonate [Moles/volume] standard in Mixed venous blood | 0.898 |  |
| 3046609 | Cholecalciferol (Vit D3) [Moles/volume] in Serum or Plasma | 0.897 |  |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.895 |  |
| 3018650 | Bicarbonate [Moles/volume] in Venous cord blood | 0.895 | 1213 |
| 36661376 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.894 |  |
| 36661384 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.894 |  |
| 43055370 | Monocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.894 |  |
| 3038697 | Lupus anticoagulant neutralization platelet [Presence] in Platelet poor plasma by Coagulation assay | 0.893 |  |
| 43055369 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Automated count | 0.893 |  |
| 3038245 | Bilirubin.conjugated [Moles/volume] in Body fluid | 0.893 |  |
| 3025817 | Bicarbonate [Moles/volume] in Mixed venous blood | 0.892 |  |
| 3017809 | Bicarbonate [Moles/volume] in Arterial cord blood | 0.892 | 1229 |
| 3023980 | Creatine kinase [Enzymatic activity/volume] in Body fluid | 0.892 |  |
| 3040005 | Erythroid cells [#/volume] in Blood or Marrow | 0.891 |  |
| 1469740 | 24,25-dihydroxyvitamin D3+24,25-dihydroxyvitamin D2 [Moles/volume] in Serum or Plasma | 0.890 |  |
| 3006270 | Folate [Moles/volume] in Blood | 0.890 | 1465 |
| 43055371 | Lymphocytes/Leukocytes [Pure number fraction] in Blood by Automated count | 0.889 |  |
| 43534101 | Urea [Moles/volume] in Arterial blood | 0.888 |  |
| 3003139 | Lactate dehydrogenase [Enzymatic activity/volume] in Red Blood Cells | 0.887 |  |
| 3004327 | Lymphocytes [#/volume] in Blood by Automated count | 0.886 | 35 |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.885 |  |
| 3051595 | Calciferol (Vit D2) [Moles/volume] in Serum or Plasma | 0.885 | 391 |
| 3012898 | Urea [Moles/volume] in Urine | 0.884 |  |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.883 |  |
| 43055367 | Eosinophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.883 |  |
| 3040637 | Bicarbonate [Moles/volume] standard in Venous cord blood | 0.883 |  |
| 3001784 | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma | 0.883 | 532 |
| 43534100 | Urea [Moles/volume] in Venous blood | 0.882 |  |
| 3041008 | Bicarbonate [Moles/volume] standard in Arterial cord blood | 0.881 |  |
| 3024574 | Basophils/Leukocytes in Specimen by Manual count | 0.881 |  |
| 42529188 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Moles/volume] in Serum or Plasma by Immunoassay | 0.880 |  |
| 3052201 | Parathyrin.intact [Moles/volume] in Serum or Plasma --5 minutes post excision | 0.880 |  |
| 36303442 | Epithelial cells [#/volume] in Urine by Automated | 0.880 |  |
| 3028615 | Eosinophils [#/volume] in Blood by Automated count | 0.880 | 50 |
| 3031368 | Variant lymphocytes/Leukocytes in Blood by Automated count | 0.879 |  |
| 3014594 | Urea [Moles/volume] in Body fluid | 0.876 |  |
| 3043995 | Bilirubin.conjugated+indirect [Moles/volume] in Serum or Plasma | 0.876 |  |
| 3012608 | Segmented neutrophils/Leukocytes in Blood by Automated count | 0.876 |  |
| 3049383 | Erythrocyte distribution width [Ratio] in Cord blood | 0.875 |  |
| 3049149 | Renin [Mass/volume] in Plasma --upright | 0.874 |  |
| 40758434 | Fungus [Presence] in Specimen by KOH preparation | 0.874 |  |
| 3002733 | Renin [Enzymatic activity/volume] in Plasma --baseline | 0.874 |  |
| 3026361 | Erythrocytes [#/volume] in Blood | 0.874 |  |
| 40765040 | 25-Hydroxyvitamin D3+25-Hydroxyvitamin D2 [Mass/volume] in Serum or Plasma | 0.874 | 632 |
| 648850 | Renin [Measurement] in Plasma | 0.874 |  |
| 3013429 | Basophils [#/volume] in Blood by Automated count | 0.873 | 27 |
| 3001620 | Renin [Enzymatic activity/volume] in Plasma --supine | 0.872 |  |
| 40757349 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Blood | 0.872 | 362 |
| 3025262 | Renin [Mass/volume] in Plasma --supine | 0.872 |  |
| 3013149 | Basophils+Eosinophils+Monocytes/Leukocytes in Blood by Automated count | 0.872 |  |
| 3013294 | Phosphate [Moles/volume] in Specimen | 0.871 |  |
| 40763547 | Calcidiol+Calciferol [Moles/volume] in Serum or Plasma | 0.871 |  |
| 40760485 | Enolase.neuron specific [Mass/volume] in Serum or Plasma by Immunoassay | 0.870 |  |
| 3008994 | Creatine kinase.BB [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.869 |  |
| 43055368 | Basophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.869 |  |
| 3013942 | Lymphocytes/Leukocytes in Synovial fluid by Automated count | 0.869 |  |
| 3002864 | Erythrocytes [#/volume] in Urine by Automated count | 0.868 | 246 |
| 3026160 | Phosphate [Moles/volume] in Body fluid | 0.868 |  |
| 3016070 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.867 |  |
| 3019676 | Bilirubin.conjugated [Mass/volume] in Serum or Plasma | 0.867 |  |
| 3016913 | Creatine kinase.MM [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.866 |  |
| 3022231 | Eosinophils/Leukocytes in Body fluid by Manual count | 0.866 | 1824 |
| 3008839 | Basophils/Leukocytes in Body fluid by Manual count | 0.866 | 447 |
| 3034204 | Urea [Mass/volume] in Serum or Plasma | 0.864 |  |
| 3028622 | Alkaline phosphatase.lung [Enzymatic activity/volume] in Serum or Plasma | 0.864 |  |
| 3005785 | Creatine kinase.MB [Mass/volume] in Serum or Plasma | 0.863 | 111 |
| 43055365 | Monocytes/Leukocytes [Pure number fraction] in Blood by Manual count | 0.863 |  |
| 3051014 | Leukocytes [#/area] in Urine sediment by Automated count | 0.862 |  |
| 3004411 | Monocytes/Leukocytes in Body fluid by Manual count | 0.862 |  |
| 3004338 | Enolase.neuron specific [Units/volume] in Serum or Plasma | 0.861 |  |
| 3015182 | Erythrocyte distribution width [Entitic volume] by Automated count | 0.861 |  |
| 3028895 | Lymphoblasts/Leukocytes in Blood by Manual count | 0.860 |  |
| 40762632 | Urea nitrogen [Moles/volume] in Blood | 0.859 |  |
| 3019402 | Monocytes Abnormal/Leukocytes in Blood by Manual count | 0.859 |  |
| 3001490 | Nucleated erythrocytes [#/volume] in Blood | 0.858 |  |
| 40761510 | Other cells/Leukocytes in Blood by Automated count | 0.858 |  |
| 40761899 | Leukocytes [#/volume] in Urine by Automated test strip | 0.857 |  |
| 43055364 | Neutrophils/Leukocytes [Pure number fraction] in Blood by Manual count | 0.857 |  |
| 36033643 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.857 |  |
| 3011391 | Calcitriol [Moles/volume] in Serum or Plasma | 0.857 | 503 |
| 36031949 | Influenza virus A and B and SARS-CoV+SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.856 |  |
| 40759093 | Phosphate [Moles/volume] in Serum or Plasma --post dialysis | 0.856 |  |
| 649431 | Phosphate [Measurement] in Serum or Plasma | 0.855 |  |
| 3021589 | Normoblasts [#/volume] in Blood | 0.855 |  |
| 3005489 | Leukocytes [#/volume] in Urine by Manual count | 0.854 |  |
| 3014152 | Creatine kinase [Enzymatic activity/volume] in Cerebral spinal fluid | 0.854 |  |
| 43055410 | Prostate Specific Ag Free/Prostate specific Ag.total [Pure mass fraction] in Serum or Plasma | 0.852 |  |
| 3006504 | Eosinophils/Leukocytes in Blood | 0.851 | 49 |
| 3004391 | Epithelial cells [#/volume] in Urine by Manual count | 0.851 |  |
| 3049111 | Enolase.neuron specific [Mass/volume] in Body fluid | 0.851 |  |
| 3966513 | Influenza virus A and Influenza virus B and SARS coronavirus 2 RNA panel - Nose by NAA with non-probe detection | 0.850 |  |
| 3013650 | Neutrophils [#/volume] in Blood by Automated count | 0.850 | 46 |
| 3024655 | Bicarbonate [Moles/volume] in Body fluid | 0.849 |  |
| 3034458 | CD4+CD45RA+ cells/CD8 Cells [# Ratio] in Blood | 0.849 |  |
| 3020688 | Eosinophils/Leukocytes in Sputum by Manual count | 0.849 |  |
| 3029707 | Crystals [#/volume] in Urine by Automated count | 0.848 |  |
| 646531 | Influenza virus A and Influenza virus B and SARS coronavirus 2 and Respiratory syncytial virus Ag panel - Nose by Rapid immunoassay | 0.847 |  |
| 3031040 | Bacteria [#/volume] in Urine by Automated count | 0.847 |  |
| 3015834 | Enolase.neuron specific [Enzymatic activity/volume] in Serum or Plasma | 0.846 |  |
| 3030170 | Creatine kinase [Mass/volume] in Blood | 0.846 |  |
| 3040491 | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | 0.845 |  |
| 3033575 | Monocytes [#/volume] in Blood by Automated count | 0.845 | 52 |
| 3006044 | Creatine kinase.total/Creatine kinase.MB [Enzymatic activity ratio] in Serum or Plasma | 0.844 |  |
| 3028564 | Alkaline phosphatase isoenz panel - Serum or Plasma | 0.844 |  |
| 3006140 | Bilirubin.total [Moles/volume] in Serum or Plasma | 0.843 | 21 |
| 3014886 | Neutrophils [#/volume] in Urine by Automated count | 0.842 |  |
| 46235808 | Reticulocyte distribution width [Ratio] in Blood by calculation | 0.842 |  |
| 3019069 | Monocytes/Leukocytes in Blood | 0.839 | 40 |
| 3049473 | Enolase.neuron specific [Mass/volume] in Serum or Plasma by Radioimmunoassay (RIA) | 0.838 |  |
| 3042779 | Enolase.neuron specific [Mass/volume] in Cerebral spinal fluid | 0.838 |  |
| 3009991 | Angiotensin converting enzyme [Enzymatic activity/volume] in Cerebral spinal fluid | 0.838 |  |
| 3040014 | Creatine kinase [Enzymatic activity/volume] in Dialysis fluid | 0.837 |  |
| 3022229 | Phosphate [Moles/volume] in Urine | 0.837 | 1197 |
| 3000905 | Leukocytes [#/volume] in Blood by Automated count | 0.837 | 15 |
| 3026844 | Monocytes+Macrophages/Leukocytes in Specimen by Manual count | 0.836 |  |
| 3030306 | Epithelial cells.non-squamous [#/volume] in Urine by Automated count | 0.834 |  |
| 3006696 | Leukocytes [#/volume] in Specimen by Automated count | 0.833 |  |
| 3001740 | Acetylcholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.833 |  |
| 3035173 | Hydrogen ion [Moles/volume] in Arterial blood | 0.833 |  |
| 40762014 | CD4+CD45RO+ cells/CD3+CD4+ (T4 helper) cells [# Ratio] in Blood | 0.832 |  |
| 3027389 | Bicarbonate [Moles/volume] in Red Blood Cells | 0.832 |  |
| 3029287 | Urinalysis microscopic panel [#/volume] - Urine by Automated count | 0.832 |  |
| 3037520 | Pronormoblasts [#/volume] in Blood | 0.831 |  |
| 3039179 | Angiotensin converting enzyme [Enzymatic activity/volume] in Peritoneal fluid | 0.831 |  |
| 36032352 | SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.830 |  |
| 1616626 | Enolase.neuron specific [Mass/volume] in Aspirate | 0.829 |  |
| 3031248 | Chloride [Moles/volume] in Arterial blood | 0.829 |  |
| 3004706 | Phosphoserine [Moles/volume] in Serum or Plasma | 0.828 |  |
| 3029879 | Epithelial cells.squamous [#/volume] in Urine by Automated count | 0.827 |  |
| 3048400 | Enolase.neuron specific [Mass/volume] in Cerebral spinal fluid by Immunoassay | 0.827 |  |
| 3035960 | Phosphate [Moles/volume] in Red Blood Cells | 0.826 |  |
| 1091110 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Specimen | 0.826 |  |
| 3021960 | Folate [Moles/volume] in Serum or Plasma | 0.825 | 181 |
| 3002112 | Folate [Mass/volume] in Blood | 0.825 |  |
| 3052191 | Erythrocytes [#/volume] in Cord blood | 0.824 |  |
| 3014637 | Bicarbonate [Moles/volume] in Specimen | 0.824 |  |
| 3032724 | Siderocytes [#/volume] in Blood | 0.822 |  |
| 3051257 | Erythrocyte morphology [Interpretation] in Urine sediment by Light microscopy Narrative | 0.821 |  |
| 3046121 | Yeast.hyphae [Presence] in Specimen by Wet preparation | 0.820 |  |
| 40765038 | 1,25-Dihydroxyvitamin D [Mass/volume] in Serum or Plasma | 0.820 |  |
| 3018095 | Leukocytes [#/volume] in Urine | 0.819 | 201 |
| 3011510 | Bicarbonate [Moles/volume] in Water | 0.819 |  |
| 3030908 | Bilirubin.conjugated [Mass/volume] in Body fluid | 0.819 |  |
| 3040517 | Leukocytes [Presence] in Urine by Automated | 0.819 |  |
| 3010866 | Cholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.817 |  |
| 46235782 | Bilirubin.total [Moles/volume] in Serum, Plasma or Blood | 0.817 |  |
| 3029794 | Leukocyte clumps [#/volume] in Urine by Automated count | 0.816 | 608 |
| 1091400 | Fungus [Presence] in Tissue by KOH preparation | 0.815 |  |
| 40760678 | 25-hydroxyvitamin D3 [Moles/volume] in Serum or Plasma --pre dose calcium | 0.815 |  |
| 36661369 | SARS-CoV-2 (COVID-19) Ab [Presence] in Serum, Plasma or Blood by Rapid immunoassay | 0.814 |  |
| 3028638 | Bilirubin.direct [Moles/volume] in Serum or Plasma | 0.814 | 82 |
| 40760681 | 25-hydroxyvitamin D3 [Moles/volume] in Serum or Plasma --1 hour post dose calcium | 0.814 |  |
| 3015377 | Calcium [Moles/volume] in Serum or Plasma | 0.814 | 12 |
| 3005013 | Prostate Specific Ag Free [Mass/volume] in Serum or Plasma | 0.814 | 554 |
| 3039189 | Lupus anticoagulant neutralization dilute phospholipid [Time] in Platelet poor plasma | 0.813 |  |
| 36031238 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with non-probe detection | 0.813 |  |
| 3020149 | 25-hydroxyvitamin D3 [Mass/volume] in Serum or Plasma | 0.812 |  |
| 706163 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.812 |  |
| 3009299 | Lupus anticoagulant neutralization platelet [Time] in Platelet poor plasma by Coagulation assay | 0.811 | 811 |
| 40762329 | Prostate Specific Ag Free/Prostate specific Ag.total in Body fluid | 0.811 |  |
| 3039417 | Platelet distribution width [Ratio] in Blood | 0.811 |  |
| 3024232 | Phosphate [Mass/volume] in Blood | 0.810 |  |
| 3001138 | Prostate Specific Ag Free [Units/volume] in Serum or Plasma | 0.809 | 1854 |
| 40757494 | Bilirubin.total [Moles/volume] in Blood | 0.809 |  |
| 3040249 | Reticulocytes.mature [#/volume] in Blood | 0.809 |  |
| 3047178 | Yeast [Presence] in Specimen by Wet preparation | 0.808 | 874 |
| 3030573 | Phosphate [Moles/volume] in Dialysis fluid | 0.808 |  |
| 3023520 | Reticulocytes [#/volume] in Blood | 0.808 | 555 |
| 3038738 | Fungus [Presence] in Specimen by Organism specific culture | 0.807 |  |
| 40771480 | Enolase.neuron specific [Mass/volume] in Pleural fluid | 0.806 |  |
| 3007242 | Bilirubin.indirect [Moles/volume] in Serum or Plasma | 0.806 | 125 |
| 1259611 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen | 0.806 |  |
| 3010910 | Erythrocytes [#/volume] in Body fluid | 0.805 | 435 |
| 649172 | Prostate Specific Ag Free [Measurement] in Serum or Plasma | 0.805 |  |
| 3006729 | Transketolase [Enzymatic activity/volume] in Serum | 0.805 |  |
| 3008966 | Adenylate kinase [Enzymatic activity/volume] in Serum | 0.804 |  |
| 3037816 | CD4+CD8+ cells/100 cells in Blood | 0.804 |  |
| 3002131 | Prostate specific Ag [Units/volume] in Serum or Plasma | 0.802 |  |
| 706180 | SARS-CoV-2 (COVID-19) IgM Ab [Presence] in Serum, Plasma or Blood by Rapid immunoassay | 0.801 |  |
| 3013603 | Prostate specific Ag [Mass/volume] in Serum or Plasma | 0.801 | 124 |
| 3023451 | Erythrocytes [Morphology] in Blood by Automated count | 0.799 |  |
| 3041326 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Tissue | 0.798 |  |
| 3014859 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Body fluid | 0.795 |  |
| 40758447 | Fungus [Presence] in Bronchial specimen by KOH preparation | 0.794 |  |
| 646862 | Prostate specific Ag [Measurement] in Serum or Plasma | 0.792 |  |
| 1001548 | Glycocholate [Moles/volume] in Serum or Plasma | 0.791 |  |
| 40758436 | Fungus [Presence] in Vaginal fluid by KOH preparation | 0.791 |  |
| 42528887 | GlycA [Moles/volume] in Serum or Plasma | 0.789 |  |
| 40758433 | Fungus [Presence] in Sputum by KOH preparation | 0.789 |  |
| 40758432 | Fungus [Presence] in Skin by KOH preparation | 0.788 |  |
| 42529562 | Prostate Specific Ag Free [Mass/volume] in Serum or Plasma by Immunoassay | 0.787 |  |
| 3029361 | Urinalysis dipstick panel - Urine by Automated test strip | 0.786 |  |
| 3027627 | Lupus anticoagulant neutralization high phospholipid [Time] in Platelet poor plasma by Coagulation assay | 0.786 |  |
| 40762328 | Prostate Specific Ag Free/Prostate specific Ag.total in Pleural fluid | 0.785 |  |
| 1259791 | Lupus anticoagulant aPTT screening panel - Platelet poor plasma by Coagulation assay | 0.785 |  |
| 3046082 | Antithrombin Ag [Presence] in Platelet poor plasma by Immunoassay | 0.784 |  |
| 3033295 | Lupus anticoagulant neutralization dilute phospholipid actual/normal in Platelet poor plasma by Coagulation assay | 0.783 |  |
| 3031441 | Tripeptide aminopeptidase [Enzymatic activity/volume] in Serum or Plasma | 0.781 |  |
| 3020073 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Specimen | 0.780 |  |
| 3002736 | Platelet distribution width [Entitic volume] in Blood by Automated count | 0.780 | 1233 |
| 3015209 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bone marrow | 0.780 |  |
| 3014942 | Protein kinase [Enzymatic activity/volume] in Serum | 0.778 |  |
| 3009059 | Enolase [Enzymatic activity/volume] in Serum | 0.778 |  |
| 3037908 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma | 0.778 |  |
| 3002888 | Erythrocyte distribution width [Entitic volume] | 0.778 |  |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.778 | 16 |
| 3015823 | Fibrin D-dimer [Presence] in Platelet poor plasma | 0.776 |  |
| 3036987 | Folate [Mass/volume] in Serum or Plasma | 0.775 |  |
| 3019897 | Erythrocyte [DistWidth] in Blood by Automated count | 0.773 | 24 |
| 3021543 | Triosephosphate isomerase [Enzymatic activity/volume] in Serum | 0.773 |  |
| 3030296 | Molybdenum [Moles/volume] in Red Blood Cells | 0.771 |  |
| 21493858 | Methotrexate monoglutamate [Moles/volume] in Red Blood Cells | 0.769 |  |
| 40762327 | Prostate Specific Ag Free/Prostate specific Ag.total in Peritoneal fluid | 0.768 |  |
| 3042793 | Prostate specific Ag.protein bound [Mass/volume] in Serum or Plasma | 0.766 |  |
| 44816949 | Thymidine phosphorylase [Enzymatic activity/volume] in DBS | 0.766 |  |
| 3008455 | Magnesium [Moles/volume] in Red Blood Cells | 0.763 | 1697 |
| 3965527 | Cardiovascular risk panel - Serum or Plasma | 0.762 |  |
| 37019495 | Oxysterols panel - Serum or Plasma | 0.760 |  |
| 3013088 | Calcium [Moles/volume] in Red Blood Cells | 0.759 |  |
| 3030030 | Alpha-1-acid glycoprotein [Moles/volume] in Serum or Plasma | 0.759 |  |
| 3032166 | Volatiles panel - Serum or Plasma | 0.759 |  |
| 3006791 | Alpha naphthylesterase [Enzymatic activity/volume] in Serum | 0.759 |  |
| 3045740 | CD56 cells/CD38 Cells [# Ratio] in Blood | 0.757 |  |
| 3012764 | Erythrocyte morphology finding [Identifier] in Blood | 0.756 | 132 |
| 3014029 | Erythrocyte shape [Morphology] in Blood | 0.755 |  |
| 3039047 | Heavy metals panel - Serum or Plasma | 0.754 |  |
| 1002116 | Glycohyodeoxycholate [Moles/volume] in Serum or Plasma | 0.752 |  |
| 40761509 | Erythrocyte morphology panel - Blood | 0.752 |  |
| 21490950 | Glycylproline [Moles/volume] in Serum or Plasma | 0.751 |  |
| 3966389 | Mitochondrial metabolites panel - Serum or Plasma | 0.750 |  |
| 3008575 | Glycine [Moles/volume] in Serum or Plasma | 0.749 | 1885 |
| 3014780 | Pyrimidine-5'-Nucleotidase [Enzymatic activity/volume] in Blood | 0.748 |  |
| 1091592 | Copper panel - Serum or Plasma | 0.747 |  |
| 44816954 | Glycerate [Moles/volume] in Serum or Plasma | 0.747 |  |
| 40760845 | Protein [Presence] in Urine by Automated test strip | 0.745 |  |
| 3013721 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.744 | 19 |
| 3010316 | Galactose [Moles/volume] in Serum or Plasma | 0.743 |  |
| 3003511 | Phosphoglycerate kinase [Enzymatic activity/volume] in Serum | 0.743 |  |
| 3049181 | Alkaline phosphatase isoenzymes [Interpretation] in Serum or Plasma Narrative | 0.741 |  |
| 3009261 | Glucose [Presence] in Urine by Test strip | 0.739 | 309 |
| 3014051 | Protein [Presence] in Urine by Test strip | 0.738 | 99 |
| 44787095 | Platelet distribution width [Entitic volume] in Cord blood by Automated count | 0.738 |  |
| 3044175 | Glycerol [Moles/volume] in Serum or Plasma | 0.738 |  |
| 1001795 | Glycodeoxycholate [Moles/volume] in Serum or Plasma | 0.736 |  |
| 3043435 | Alkaline phosphatase isoenzymes [Enzymatic activity/volume] in Serum or Plasma by Levamisole inhibition | 0.736 |  |
| 44816912 | OLANZapine panel - Serum or Plasma | 0.736 |  |
| 3966606 | Prenatal hepatitis B and C panel - Serum or Plasma | 0.734 |  |
| 3004588 | Protein electrophoresis panel - Serum or Plasma | 0.733 |  |
| 3016782 | Immunoelectrophoresis panel - Serum | 0.733 |  |
| 3964942 | Vitamin B3 and metabolites panel - Serum or Plasma by LC/MS/MS | 0.733 |  |
| 3030260 | Glucose [Presence] in Urine by Automated test strip | 0.733 |  |
| 40758348 | Antioxidants [Moles/volume] in Serum or Plasma | 0.731 |  |
| 36031364 | Hyperoxaluria panel - Serum or Plasma | 0.731 |  |
| 40761066 | Erythrocytes [Morphology] in Body fluid by Light microscopy | 0.731 |  |
| 40770913 | Hypoglycemics panel - Serum or Plasma | 0.731 |  |
| 3022525 | Erythrocyte size [Morphology] in Blood | 0.730 |  |
| 3030688 | Urinalysis panel - Urine by Automated | 0.730 |  |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 0.729 |  |
| 3021952 | Alkaline phosphatase isoenzymes [Enzymatic activity/volume] in Serum or Plasma by Heat stability | 0.719 |  |
| 3024629 | Glucose [Mass/volume] in Urine by Test strip | 0.715 |  |
| 3028089 | Alkaline phosphatase isoenzyme [Units/volume] in Serum or Plasma | 0.711 |  |
| 3011368 | Poikilocytosis [Presence] in Blood by Light microscopy | 0.706 | 302 |
| 3023802 | Normoblasts Orthochromic/cells in Bone marrow by Manual count | 0.705 |  |
| 21492520 | Carnitine biosynthesis intermediates panel - Serum or Plasma | 0.703 |  |
| 3026023 | Comprehensive metabolic 2000 panel - Serum or Plasma | 0.701 |  |
| 40758424 | Protein electrophoresis and Immunoglobulins panel - Serum | 0.700 |  |
| 3010114 | Amylase isoenzyme 7 panel - Serum | 0.698 |  |
| 3043216 | Cardiovascular physiologic and EKG assessment panel | 0.695 |  |
| 21493004 | Occupational exposure information panel | 0.691 |  |
| 3009876 | Amylase isoenzyme 3 panel - Serum or Plasma | 0.690 |  |
| 3016261 | Variant lymphocytes/cells in Bone marrow by Manual count | 0.684 |  |
| 3023075 | Type of EKG leads | 0.684 |  |
| 3003879 | Plasma cells/cells in Bone marrow by Manual count | 0.677 |  |
| 21492522 | Carnitine biosynthesis intermediates panel - Urine | 0.676 |  |
| 3035163 | Hypersensitivity pneumonitis panel - Serum | 0.673 |  |
| 3050153 | Food allergen panel - Serum | 0.673 |  |
| 3050943 | Newborn hearing screening panel | 0.670 |  |
| 21492521 | Carnitine biosynthesis intermediates panel - Cerebral spinal fluid | 0.668 |  |
| 3033521 | Obstetric 1996 panel - Serum and Blood | 0.668 |  |
| 21492790 | Plasma cells/Leukocytes in Blood by Manual count | 0.667 |  |
| 21492519 | Carnitine biosynthesis intermediates panel - DBS | 0.664 |  |
| 36660707 | Vitamin B6 and metabolites panel - Serum or Plasma | 0.664 |  |
| 3037023 | Hydrocarbon and Oxygenated Volatiles panel - Serum or Plasma | 0.664 |  |
| 3010241 | Lymphoma cells/Leukocytes in Blood by Manual count | 0.663 |  |
| 1260006 | Clonal cells rearrangements/Cells counted in Specimen by Molecular genetics method | 0.661 |  |
| 3031004 | Mononuclear cells/Leukocytes in Blood by Manual count | 0.661 |  |
| 3007867 | Hepatitis 1996 panel - Serum | 0.661 |  |
| 3022035 | Basic metabolic 2000 panel - Serum or Plasma | 0.660 |  |
| 3016263 | Hairy cells/Leukocytes in Blood by Manual count | 0.659 |  |
| 36659635 | Variant lymphocytes/Leukocytes in Stem cell product by Manual count | 0.659 |  |
| 3037234 | Variant lymphocytes/Leukocytes in Blood by Manual count | 0.658 | 167 |
| 3038141 | Acute hepatitis 2000 panel - Serum | 0.656 |  |
| 44816766 | Metabolic disorder therapy monitoring panel - DBS | 0.655 |  |
| 1988764 | Electromyography panel | 0.654 |  |
| 3006773 | TORCH 1996 panel - Serum | 0.654 |  |
| 40757516 | Dehydroascorbate/Ascorbate in Serum or Plasma | 0.652 |  |
| 1259654 | Diagnostic multisection transesophageal and cardioversion panel Heart | 0.652 |  |
| 1617160 | Diagnostic audiology results panel | 0.643 |  |
| 40757517 | Dehydroascorbate [Moles/volume] in Serum or Plasma | 0.642 |  |
| 40757482 | Ascorbate+Dehydroascorbate [Mass/volume] in Serum or Plasma | 0.642 |  |
| 1988411 | Permanent pacemaker panel | 0.642 |  |
| 3044933 | Cardiac 2D echo panel | 0.641 |  |
| 3046728 | Iron [Presence] in Serum or Plasma | 0.639 |  |
| 3013512 | EKG study | 0.638 |  |
| 3027476 | Ascorbate [Mass/volume] in Serum or Plasma | 0.635 |  |
| 3013702 | Oxygen [Partial pressure] adjusted to patient's actual temperature in Blood | 0.635 | 619 |
| 3022504 | Arsenic [Presence] in Serum or Plasma | 0.634 |  |
| 3013558 | Glutathione [Mass/volume] in Serum or Plasma | 0.633 |  |
| 3019240 | Oxygen [Partial pressure] adjusted to patient's actual temperature in Capillary blood | 0.631 |  |
| 3032025 | Acetaldehyde [Presence] in Serum or Plasma | 0.631 |  |
| 44816972 | Aconitate [Moles/volume] in Serum or Plasma | 0.630 |  |
| 3022803 | Oxygen [Partial pressure] adjusted to patient's actual temperature in Arterial blood | 0.630 |  |
| 1988318 | Temporary pacemaker panel | 0.628 |  |
| 36305393 | Pure tone air conduction threshold audiometry panel | 0.627 |  |
| 3044671 | QRS duration {Electrocardiograph lead} | 0.625 |  |
| 3020891 | Body temperature | 0.622 | 138 |
| 3042212 | Oral assessment panel | 0.620 |  |
| 3016055 | Body temperature from Pediatric incubator | 0.614 |  |
| 3022673 | Creatinine [Mass/volume] in Dialysis fluid | 0.613 |  |
| 3966684 | Body temperature 1 hour --at admission | 0.611 |  |
| 3019464 | Oxygen [Partial pressure] adjusted to patient's actual temperature in Mixed venous blood | 0.610 |  |
| 43533765 | Newborn hearing screen panel of Ear - left | 0.607 |  |
| 3052598 | Oxygen [Partial pressure] adjusted to patient's actual temperature in Cord blood | 0.606 |  |
| 43533768 | Newborn hearing screen panel of Ear - right | 0.606 |  |
| 3030091 | pH of Blood adjusted to patient's actual temperature | 0.604 | 1223 |
| 1617238 | Oxygen [Partial pressure] adjusted to patient's actual temperature in Central venous blood | 0.604 |  |
| 3032462 | Creatinine dialysis fluid clearance/1.73 sq M | 0.602 |  |
| 3023665 | Volume of Dialysis fluid | 0.595 |  |
| 3052678 | Hematocrit [Volume Fraction] of Dialysis fluid by calculation | 0.594 |  |
| 3007196 | Creatinine [Moles/volume] in Dialysis fluid | 0.593 |  |
| 1616467 | Auditory brainstem response panel | 0.593 |  |
| 1761861 | Pure tone bone conduction threshold audiometry panel | 0.593 |  |
| 3041197 | Creatinine [Moles/volume] in 24 hour Dialysis fluid | 0.592 |  |
| 21494472 | Pupil assessment panel | 0.592 |  |
| 3006563 | Creatinine dialysis fluid clearance | 0.591 | 398 |
| 3042571 | Creatinine [Moles/time] in 24 hour Dialysis fluid | 0.591 |  |
| 648312 | Creatinine [Measurement] in Dialysis fluid | 0.590 |  |
| 1989068 | Visual acuity panel | 0.581 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1841 | -cd4-solujensuhdecd8-soluihin |  | 100% | name+values | 667 | 0.3 | [0.26, 0.37, 0.55, 0.73, 1, 1.35, 1.81, 2.32, 3.03] |  |  |  | CD4/CD8 [# Ratio] in Blood |
| 1842 | -kt/v,daugirdaksenkaava |  | 100% | name+values | 176 | 0 | [1.13, 1.23, 1.29, 1.33, 1.39, 1.43, 1.46, 1.5, 1.57] |  |  |  | Kt/V dialysis adequacy [Ratio] by Daugirdas formula |
| 1843 | -sieni,natiivivalmiste |  | 100% | name | 244 | 100 |  |  |  |  | Fungus [Presence] in Specimen by Wet mount |
| 1844 | ab-aktuaalibikarbonaatti | mmol/l | 100% | name+unit+values | 14354 | 0 | [18.76, 21.02, 22.57, 23.76, 24.73, 25.7, 26.99, 28.55, 31.59] |  | Arterial blood |  | Bicarbonate [Moles/volume] in Arterial blood |
| 1845 | ab-aktuaalibikarbonaatti |  | 0% | name | 47 | 100 |  |  | Arterial blood |  | Bicarbonate [Moles/volume] in Arterial blood |
| 1846 | ab-lämpötila(he-tase) | aste | 100% | name+unit+values | 418 | 0 | [36.38, 36.95, 37, 37, 37, 37, 37.01, 37.48, 38.01] |  | Arterial blood |  | Temperature [Temperature] of Patient |
| 1847 | ab-standardibikarbonaatti | mmol/l | 100% | name+unit+values | 4434 | 0 | [19.73, 21.71, 22.89, 23.76, 24.46, 25.22, 26.01, 27.04, 28.87] |  | Arterial blood |  | Bicarbonate.standard [Moles/volume] in Arterial blood |
| 1848 | ab-standardibikarbonaatti |  | 0% | name | 20 | 100 |  |  | Arterial blood |  | Bicarbonate.standard [Moles/volume] in Arterial blood |
| 1849 | alkalinenfosfataasi | u/l | 91% | name+unit+values | 4090 | 0 | [51.93, 59.73, 66.52, 72.54, 78.85, 86.09, 95.45, 111.37, 142.22] |  |  |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 1850 | alkalinenfosfataasi |  | 9% | name | 409 | 100 |  |  |  |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 1851 | angiotensiini-1-konvertaasi | u/l | 93% | name+unit+values | 286 | 0 | [21.5, 28.51, 36.37, 41.21, 48.76, 54.44, 63.62, 70.94, 80.3] |  |  |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma |
| 1852 | angiotensiini-1-konvertaasi |  | 7% | name | 20 | 100 |  |  |  |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma |
| 1853 | b-diffi,erittelylaskenta,klooni |  | 100% | name | 142 | 100 |  |  | Blood |  | Clonality study [Interpretation] in Blood by Manual count |
| 1854 | cb-standardibikarbonaatti | mmol/l | 99% | name+unit+values | 10798 | 0 | [20.28, 22.23, 23.36, 24.16, 24.9, 25.66, 26.58, 27.89, 30.19] |  | Capillary blood |  | Bicarbonate.standard [Moles/volume] in Capillary blood |
| 1855 | cb-standardibikarbonaatti |  | 1% | name | 90 | 50 |  |  | Capillary blood |  | Bicarbonate.standard [Moles/volume] in Capillary blood |
| 1856 | d-vitamiini-25-oh,d3-jad2-muodot | nmol/l | 100% | name+unit+values | 219 | 0 | [48.54, 55.58, 61.96, 68.73, 74.1, 79.27, 84.22, 89.91, 106.45] |  |  |  | Hydroxyvitamin D3+D2 [Moles/volume] in Serum or Plasma |
| 1857 | d-vitamiini-25-oh,plasmasta | nmol/l | 100% | name+unit+values | 694 | 0 | [44.59, 53.15, 59, 64.66, 69.89, 76.01, 82.54, 92.02, 105.7] |  |  |  | Hydroxyvitamin D (25) [Moles/volume] in Plasma |
| 1858 | e-punasolujenkokojakaum | % | 100% | name+unit+values | 55570 | 0 | [12.19, 12.59, 12.95, 13.26, 13.67, 14.09, 14.51, 14.98, 15.71] |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1859 | e-punasolujenkokojakaum |  | 0% | name | 7 | 71.43 |  |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1860 | e-punasolujenkokojakauma | % | 99% | name+unit+values | 196935 | 0 | [12, 13, 13, 13, 13.69, 14, 14.05, 15, 16.37] |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1861 | e-punasolujenkokojakauma |  | 1% | name+values | 1688 | 46.92 | [15, 15, 15.98, 16, 16, 16.41, 17, 18, 19.59] |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1862 | e-rdw,punasolujenkokojakauma | % | 100% | name+unit+values | 25929 | 0 | [12.08, 13, 13, 13.03, 14, 14, 15, 15.7, 17.03] |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1863 | e-rdw,punasolujenkokojakauma |  | 0% | name | 76 | 100 |  |  | Erythrocyte |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1864 | ekg,hoitoyksikönottama |  | 100% | name | 213 | 100 |  |  |  |  | 12 lead EKG panel |
| 1865 | ekgasiakkaanottama |  | 100% | name | 257 | 100 |  |  |  |  | 12 lead EKG panel |
| 1866 | erikoislääkärinkonsultaatio |  | 100% | name | 118 | 100 |  |  |  |  |  |
| 1867 | folaatti(fe-folaat) | nmol/l | 96% | name+unit+values | 320 | 0 | [1456.69, 1642.98, 1740.68, 1864.47, 2021, 2152.9, 2311.39, 2519.36, 2775.52] |  |  |  | Folate [Moles/volume] in Red Blood Cells |
| 1868 | folaatti(fe-folaat) |  | 4% | name | 12 | 100 |  |  |  |  | Folate [Moles/volume] in Red Blood Cells |
| 1869 | fosfaatti,epäorgaaninen | mmol/l | 95% | name+unit+values | 275 | 0 | [0.83, 0.93, 0.99, 1.05, 1.1, 1.15, 1.23, 1.36, 1.64] |  |  |  | Phosphate [Moles/volume] in Serum or Plasma |
| 1870 | fosfaatti,epäorgaaninen |  | 5% | name | 13 | 100 |  |  |  |  | Phosphate [Moles/volume] in Serum or Plasma |
| 1871 | fp-fosfaatti,epäorgaaninen | mmol/l | 100% | name+unit+values | 1537 | 0 | [0.81, 0.94, 1.04, 1.12, 1.21, 1.31, 1.45, 1.64, 2] |  | Fasting plasma |  | Phosphate [Moles/volume] in Plasma |
| 1872 | fp-fosfaatti,epäorgaaninen |  | 0% | name | 7 | 100 |  |  | Fasting plasma |  | Phosphate [Moles/volume] in Plasma |
| 1873 | fp-parathormoni(intakti) | ng/l | 100% | name+unit+values | 167 | 0 | [34.58, 43.28, 53.6, 64.34, 75.77, 88.59, 106.04, 128.88, 166.07] |  | Fasting plasma |  | Parathyrin.intact [Mass/volume] in Plasma |
| 1874 | fp-parathormoni,intakti | ng/l | 67% | name+unit+values | 443 | 0 | [42.85, 55.73, 66.85, 78.78, 88.68, 102.07, 115.78, 136.81, 193.49] |  | Fasting plasma |  | Parathyrin.intact [Mass/volume] in Plasma |
| 1875 | fp-parathormoni,intakti | pmol/l | 32% | name+unit+values | 213 | 0 | [5.11, 7.29, 9.06, 12.26, 16.48, 21.96, 29.55, 41.46, 57.9] |  | Fasting plasma |  | Parathyrin.intact [Moles/volume] in Plasma |
| 1876 | fp-parathormoni,intakti |  | 1% | name | 5 | 60 |  |  | Fasting plasma |  | Parathyrin.intact [Mass/volume] in Plasma |
| 1877 | fp-reniini,konsentraatio | mu/l | 97% | name+unit+values | 275 | 0 | [1.9, 3.7, 5.72, 9.15, 13.8, 21.38, 36.23, 69.29, 149] |  | Fasting plasma |  | Renin [Units/volume] in Plasma |
| 1878 | fp-reniini,konsentraatio |  | 3% | name | 9 | 100 |  |  | Fasting plasma |  | Renin [Units/volume] in Plasma |
| 1879 | fras,oksidatiivinenstressi |  | 100% | name | 508 | 100 |  |  |  |  | Free radicals [Arbitrary Concentration] in Serum or Plasma |
| 1880 | fs-alkalinenfosfataasi | u/l | 100% | name+unit | 114 | 0 |  |  | Fasting serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum |
| 1881 | fs-angiotensiini-1-konvertaasi | u/l | 91% | name+unit+values | 168 | 0 | [21.95, 28.78, 36.13, 43.17, 50.38, 57.02, 63.03, 69.31, 88.3] |  | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum |
| 1882 | fs-angiotensiini-1-konvertaasi |  | 9% | name | 17 | 100 |  |  | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum |
| 1883 | fs-monikanava4-7tthperuspaketti |  | 100% | name | 125 | 100 |  |  | Fasting serum |  | Occupational health panel - Serum |
| 1884 | fs-työterveyshuollonperuspaketti |  | 100% | name | 141 | 100 |  |  | Fasting serum |  | Occupational health panel - Serum |
| 1885 | ilmajohtotarv.luujohto |  | 100% | name | 785 | 100 |  |  |  |  | Hearing evaluation panel |
| 1886 | korona-rs-influenssa,pcrpikatesti |  | 100% | name | 6428 | 100 |  |  |  |  | SARS-CoV-2 & Influenza virus & Respiratory syncytial virus RNA panel - Respiratory specimen by NAA |
| 1887 | kreatiinikinaasi | u/l | 100% | name+unit+values | 821 | 0 | [51.45, 67.28, 78.98, 91.33, 108.19, 125.74, 161.13, 224.43, 350.78] |  |  |  | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma |
| 1888 | l-basofiilit,automaatio | % | 100% | name+unit+values | 10670 | 0 | [0, 0, 0.5, 1, 1, 1, 1, 1, 1] |  | Leukocyte |  | Basophils/Leukocytes in Blood by Automated count |
| 1889 | l-eosinofiilit,automaatio | % | 100% | name+unit+values | 10670 | 0 | [0.35, 1, 1.93, 2, 2.74, 3, 3.97, 4.81, 6.33] |  | Leukocyte |  | Eosinophils/Leukocytes in Blood by Automated count |
| 1890 | l-lymfosyytit,automaatio | % | 100% | name+unit+values | 19279 | 0 | [15.56, 20.42, 24.04, 26.95, 29.66, 32.37, 35.21, 38.75, 43.79] |  | Leukocyte |  | Lymphocytes/Leukocytes in Blood by Automated count |
| 1891 | l-lymfosyytit,automaatio |  | 0% | name | 23 | 100 |  |  | Leukocyte |  | Lymphocytes/Leukocytes in Blood by Automated count |
| 1892 | l-monosyytit,automaatio | % | 100% | name+unit+values | 19276 | 0 | [5.94, 6.98, 7.19, 8, 8.78, 9.04, 10, 11, 12.64] |  | Leukocyte |  | Monocytes/Leukocytes in Blood by Automated count |
| 1893 | l-monosyytit,automaatio |  | 0% | name | 23 | 100 |  |  | Leukocyte |  | Monocytes/Leukocytes in Blood by Automated count |
| 1894 | l-neutrofiilit,automaatio | % | 100% | name+unit+values | 19277 | 0 | [41.43, 47.16, 50.99, 54.23, 57.08, 59.98, 63.15, 67.08, 72.76] |  | Leukocyte |  | Neutrophils/Leukocytes in Blood by Automated count |
| 1895 | l-neutrofiilit,automaatio |  | 0% | name | 23 | 100 |  |  | Leukocyte |  | Neutrophils/Leukocytes in Blood by Automated count |
| 1896 | laktaattidehydrogenaasi | u/l | 100% | name+unit+values | 112 | 0 | [166.9, 176.25, 189.57, 200, 217.89, 228.73, 246.21, 285.8, 336.3] |  |  |  | Lactate dehydrogenase [Enzymatic activity/volume] in Serum or Plasma |
| 1897 | p-aktuaalinenbikarbonaatti | mmol/l | 100% | name+unit+values | 1258 | 0 | [20.16, 23.03, 24.56, 25.84, 26.91, 27.87, 28.97, 30.03, 32.38] |  | Plasma |  | Bicarbonate [Moles/volume] in Plasma |
| 1898 | p-alkaalinenfosfataasi | u/l | 97% | name+unit+values | 218 | 0 | [54.87, 64.51, 69.29, 74.44, 80.78, 89.02, 97.67, 107.93, 128.13] |  | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 1899 | p-alkaalinenfosfataasi |  | 3% | name | 6 | 16.67 |  |  | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 1900 | p-alkalinenfosfataasi | u/l | 100% | name+unit+values | 26335 | 0 | [51.5, 59.65, 66.46, 73.03, 79.94, 87.78, 97.91, 113.11, 149.16] |  | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 1901 | p-alkalinenfosfataasi |  | 0% | name | 74 | 91.89 |  |  | Plasma |  | Alkaline phosphatase [Enzymatic activity/volume] in Plasma |
| 1902 | p-bilirubiinikonjugaatit | umol/l | 92% | name+unit+values | 1839 | 0 | [2.92, 3, 3.32, 4, 4.89, 5.93, 7.57, 10.11, 21.15] |  | Plasma |  | Bilirubin.conjugated [Moles/volume] in Plasma |
| 1903 | p-bilirubiinikonjugaatit |  | 8% | name | 168 | 100 |  |  | Plasma |  | Bilirubin.conjugated [Moles/volume] in Plasma |
| 1904 | p-fosfaatti,epäorgaaninen | mmol/l | 100% | name+unit+values | 436 | 0 | [0.89, 0.99, 1.06, 1.13, 1.2, 1.27, 1.36, 1.47, 1.66] |  | Plasma |  | Phosphate [Moles/volume] in Plasma |
| 1905 | p-kreatiinikinaasi | u/l | 99% | name+unit+values | 2765 | 0 | [43.61, 57.48, 70.52, 85.33, 100.93, 124.44, 165.61, 239.04, 491.32] |  | Plasma |  | Creatine kinase [Enzymatic activity/volume] in Plasma |
| 1906 | p-kreatiinikinaasi |  | 1% | name | 21 | 95.24 |  |  | Plasma |  | Creatine kinase [Enzymatic activity/volume] in Plasma |
| 1907 | p-laktaattidehydrogenaasi | u/l | 99% | name+unit+values | 3272 | 0 | [163.71, 178.57, 190.98, 203.43, 216.38, 231.67, 254.03, 288.21, 372.84] |  | Plasma |  | Lactate dehydrogenase [Enzymatic activity/volume] in Plasma |
| 1908 | p-laktaattidehydrogenaasi |  | 1% | name | 29 | 96.55 |  |  | Plasma |  | Lactate dehydrogenase [Enzymatic activity/volume] in Plasma |
| 1909 | p-lupusantikoagulantti |  | 100% | name | 220 | 100 |  |  | Plasma |  | Lupus anticoagulant [Presence] in Platelet poor plasma |
| 1910 | p-psavapaanosuustotaalista | % | 100% | name+unit+values | 719 | 0 | [10.55, 13.9, 16.1, 18.77, 21.1, 23.88, 26.7, 30.17, 36.09] |  | Plasma |  | Prostate specific Ag.free/Prostate specific Ag.total [Ratio] in Plasma |
| 1911 | p-urea,resirkulaatio | mmol/l | 100% | name+unit+values | 200 | 0 | [4.65, 12.03, 14.2, 15.66, 16.84, 18.43, 19.52, 21.22, 23.14] |  | Plasma |  | Urea [Moles/volume] in Plasma |
| 1912 | psa-vapaa/totaali-suhde,plasmasta | % | 26% | name+unit+values | 1183 | 0 | [8.11, 11.04, 13.43, 15.83, 18.18, 20.89, 24.81, 29.88, 39.78] |  |  |  | Prostate specific Ag.free/Prostate specific Ag.total [Ratio] in Plasma |
| 1913 | psa-vapaa/totaali-suhde,plasmasta |  | 74% | name | 3428 | 100 |  |  |  |  | Prostate specific Ag.free/Prostate specific Ag.total [Ratio] in Plasma |
| 1914 | psavapaanjatotaalinsuhde | % | 26% | name+unit | 62 | 0 |  |  |  |  | Prostate specific Ag.free/Prostate specific Ag.total [Ratio] in Serum or Plasma |
| 1915 | psavapaanjatotaalinsuhde |  | 74% | name | 180 | 97.78 |  |  |  |  | Prostate specific Ag.free/Prostate specific Ag.total [Ratio] in Serum or Plasma |
| 1916 | pt-vaativainhalaatiohoito |  | 100% | name | 114 | 100 |  |  | Patient |  |  |
| 1917 | punasolojenkokojakauma | % | 99% | name+unit+values | 1068 | 0 | [12, 12.05, 13, 13, 13, 13, 13.97, 14, 14.47] |  |  |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1918 | punasolojenkokojakauma |  | 1% | name | 7 | 100 |  |  |  |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1919 | punasolujenerittelylaskenta | % | 9% | name+unit | 41 | 0 |  |  |  |  | Erythrocyte morphology [Interpretation] in Blood by Manual count |
| 1920 | punasolujenerittelylaskenta |  | 91% | name+values | 433 | 6 | [12, 12, 12.18, 13, 13, 13, 13, 13.97, 14] |  |  |  | Erythrocyte morphology [Interpretation] in Blood by Manual count |
| 1921 | punasolujenesiasteet(erytroblastit) | e9/l | 98% | name+unit+values | 1040 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  | Erythroblasts [#/volume] in Blood |
| 1922 | punasolujenesiasteet(erytroblastit) |  | 2% | name | 24 | 100 |  |  |  |  | Erythroblasts [#/volume] in Blood |
| 1923 | punasolujenkokojakauma | % | 98% | name+unit+values | 155883 | 0 | [12.28, 13, 13, 13.02, 14, 14, 15, 15.9, 17] |  |  |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1924 | punasolujenkokojakauma |  | 2% | name | 2478 | 99.48 |  |  |  |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1925 | punasolujenkokojakautuma | % | 100% | name+unit+values | 683 | 0 | [13, 13, 13, 13, 13, 14, 14, 14, 14.95] |  |  |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1926 | punasolujenkoonvaihtelu | % | 100% | name+unit+values | 2031 | 0 | [12.51, 12.91, 13.17, 13.34, 13.62, 13.91, 14.31, 14.86, 15.92] |  |  |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1927 | punasolut,kokojakauma | % | 100% | name+unit+values | 121 | 0 | [13, 13, 13, 13, 14, 14, 14, 14, 15] |  |  |  | Erythrocyte distribution width [Ratio] in Blood by Automated count |
| 1928 | s-alkalinenfosfataasi | u/l | 100% | name+unit+values | 368 | 0 | [52.79, 63.98, 76.35, 87.37, 103.68, 118.86, 131.06, 146.22, 181.47] |  | Serum |  | Alkaline phosphatase [Enzymatic activity/volume] in Serum |
| 1929 | s-alkalinenfosfataasi,isoentsyymit |  | 100% | name | 318 | 100 |  |  | Serum |  | Alkaline phosphatase isoenzymes panel - Serum by Electrophoresis |
| 1930 | s-glykoproteiininasetylaatio | mmol/l | 100% | name+unit+values | 265 | 0 | [0.75, 0.79, 0.81, 0.83, 0.85, 0.88, 0.9, 0.94, 1] |  | Serum |  | Glycoprotein.acetyls [Moles/volume] in Serum |
| 1931 | s-neuronispesifinenenolaasi | ug/l | 100% | name+unit | 105 | 0 |  |  | Serum |  | Neuron specific enolase [Mass/volume] in Serum |
| 1932 | s-nightingale-mittaus |  | 100% | name | 265 | 100 |  |  | Serum |  | Metabolites panel - Serum by NMR |
| 1933 | s-psavapaanjatotaalinsuhde | % | 29% | name+unit+values | 106 | 0 | [11, 13, 14.4, 16.35, 19, 21, 23.87, 27, 31.9] |  | Serum |  | Prostate specific Ag.free/Prostate specific Ag.total [Ratio] in Serum |
| 1934 | s-psavapaanjatotaalinsuhde |  | 71% | name | 264 | 100 |  |  | Serum |  | Prostate specific Ag.free/Prostate specific Ag.total [Ratio] in Serum |
| 1935 | s-tymidiinikinaasi | u/l | 100% | name+unit+values | 237 | 0 | [3.92, 4.79, 5.63, 6.48, 7.24, 8.95, 10.78, 13.93, 39.38] |  | Serum |  | Thymidine kinase [Enzymatic activity/volume] in Serum |
| 1936 | s-vapaanjakokonais-psa:nsuhde | % | 29% | name+unit+values | 643 | 0 | [11.89, 14.35, 17.11, 19.53, 21.76, 24, 27.79, 31.6, 36.6] |  | Serum |  | Prostate specific Ag.free/Prostate specific Ag.total [Ratio] in Serum |
| 1937 | s-vapaanjakokonais-psa:nsuhde |  | 71% | name | 1561 | 100 |  |  | Serum |  | Prostate specific Ag.free/Prostate specific Ag.total [Ratio] in Serum |
| 1938 | sars-cov-2,influenssaa,bja |  | 100% | name | 161 | 100 |  |  |  |  | SARS-CoV-2 & Influenza virus A & Influenza virus B RNA panel - Respiratory specimen by NAA |
| 1939 | sars-cov-2-antigeenitesti,pikatesti |  | 100% | name | 101 | 100 |  |  |  |  | SARS-CoV-2 Ag [Presence] in Respiratory specimen by Rapid immunoassay |
| 1940 | tth-pakettia(ilmanpaastoa) |  | 100% | name | 1079 | 100 |  |  |  |  | Occupational health panel - Serum or Plasma |
| 1941 | tth:ssavirtsanprotjagluk |  | 100% | name | 294 | 100 |  |  |  |  | Urinalysis protein and glucose panel - Urine by Test strip |
| 1942 | u-solut,peruslaskenta |  | 100% | name | 1772 | 100 |  |  | Urine |  | Leukocytes+Erythrocytes [#/volume] in Urine by Automated count |
| 1943 | vb-aktuaalibikarbonaatti | mmol/l | 90% | name+unit+values | 1612 | 0 | [16.94, 19.74, 21.93, 23.14, 24.18, 25.06, 26.96, 28.44, 30.92] |  | Venous blood |  | Bicarbonate [Moles/volume] in Venous blood |
| 1944 | vb-aktuaalibikarbonaatti |  | 10% | name+values | 185 | 17.3 | [20.1, 23.3, 24.38, 25.39, 26.05, 26.8, 27.78, 28.4, 29.7] |  | Venous blood |  | Bicarbonate [Moles/volume] in Venous blood |
| 1945 | vb-standardibikarbonaatti | mmol/l | 100% | name+unit+values | 13754 | 0 | [20.04, 21.93, 23.08, 23.95, 24.68, 25.36, 26.13, 27.07, 28.82] |  | Venous blood |  | Bicarbonate.standard [Moles/volume] in Venous blood |
| 1946 | vb-standardibikarbonaatti |  | 0% | name | 44 | 100 |  |  | Venous blood |  | Bicarbonate.standard [Moles/volume] in Venous blood |
| 1947 | virtsansolujenhl7-siirtoon | e6/l | 94% | name+unit+values | 5551 | 0 | [0.1, 0.37, 0.65, 1.07, 1.65, 2.44, 3.88, 6.78, 14.04] |  |  |  | Cells [#/volume] in Urine by Automated count |
| 1948 | virtsansolujenhl7-siirtoon |  | 6% | name+values | 353 | 11.05 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  | Cells [#/volume] in Urine by Automated count |
| 1949 | zb-aktuaalibikarbonaatti | mmol/l | 100% | name+unit+values | 394 | 0 | [22, 23, 23.94, 24, 25, 26, 27, 27.8, 29.78] |  | Central blood |  | Bicarbonate [Moles/volume] in Central venous blood |

