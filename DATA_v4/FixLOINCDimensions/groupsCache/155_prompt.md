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
Here is group 155.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 1761868 | Lipid panel - Serum or Plasma | 1.000 |  |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 16 |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 1.000 | 4 |
| 3018010 | Neutrophils/Leukocytes in Blood | 1.000 | 76 |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 1.000 | 1 |
| 3023602 | Cholesterol in HDL [Moles/volume] in Serum or Plasma | 1.000 | 38 |
| 3025839 | Triglyceride [Moles/volume] in Serum or Plasma | 1.000 | 36 |
| 3026493 | Urate [Moles/volume] in Serum or Plasma | 1.000 | 142 |
| 3026910 | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 190 |
| 3038988 | Cholesterol in LDL [Moles/volume] in Serum or Plasma by calculation | 1.000 | 63 |
| 3044889 | 12 lead EKG panel | 1.000 |  |
| 40761509 | Erythrocyte morphology panel - Blood | 1.000 |  |
| 46236949 | Alanine aminotransferase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.975 |  |
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 0.973 | 154 |
| 46235076 | Creatinine [Moles/volume] in Serum, Plasma or Blood | 0.967 |  |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.963 |  |
| 3029187 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma | 0.953 | 516 |
| 3028288 | Cholesterol in LDL [Mass/volume] in Serum or Plasma by calculation | 0.942 |  |
| 1091617 | C reactive protein [Mass/volume] in Serum, Plasma or Blood | 0.939 |  |
| 3020189 | Cholesterol in HDL 2 [Moles/volume] in Serum or Plasma | 0.939 |  |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.937 |  |
| 46235106 | Alanine aminotransferase [Enzymatic activity/volume] in Blood | 0.933 |  |
| 36660394 | Lipid and glucose panel - Serum or Plasma | 0.930 |  |
| 3005561 | Cholesterol in HDL 3 [Moles/volume] in Serum or Plasma | 0.930 |  |
| 3011960 | Natriuretic peptide B [Mass/volume] in Serum or Plasma | 0.928 | 204 |
| 40768809 | Cholesterol in VLDL [Moles/volume] in Serum or Plasma by calculation | 0.928 | 68 |
| 3022192 | Triglyceride [Mass/volume] in Serum or Plasma | 0.926 |  |
| 3048773 | Triglyceride [Moles/volume] in Serum or Plasma --fasting | 0.925 |  |
| 3037556 | Urate [Mass/volume] in Serum or Plasma | 0.921 |  |
| 40760140 | CBC W Auto Differential panel - Blood | 0.920 |  |
| 3019900 | Cholesterol [Moles/volume] in Serum or Plasma | 0.917 | 32 |
| 3020416 | Erythrocytes [#/volume] in Blood by Automated count | 0.916 | 9 |
| 3015182 | Erythrocyte distribution width [Entitic volume] by Automated count | 0.914 |  |
| 40762155 | Lipoprofile panel - Serum or Plasma | 0.913 |  |
| 3000330 | Specific gravity of Urine by Test strip | 0.912 | 71 |
| 648637 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Immunoassay | 0.909 |  |
| 3052018 | Alanine aminotransferase.macromolecular [Enzymatic activity/volume] in Serum or Plasma | 0.908 |  |
| 3016723 | Creatinine [Mass/volume] in Serum or Plasma | 0.908 |  |
| 3007070 | Cholesterol in HDL [Mass/volume] in Serum or Plasma | 0.907 |  |
| 3005755 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma by With P-5'-P | 0.907 |  |
| 1260102 | Creatinine [Moles/volume] in Serum or Plasma by LC/MS/MS | 0.906 |  |
| 3004501 | Glucose [Mass/volume] in Serum or Plasma | 0.905 |  |
| 42529224 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum or Plasma by Immunoassay | 0.905 |  |
| 3029435 | Natriuretic peptide.B prohormone N-Terminal [Moles/volume] in Serum or Plasma | 0.904 |  |
| 40759253 | Cholesterol in HDL 2a [Moles/volume] in Serum or Plasma | 0.904 |  |
| 40760809 | Lipid panel with direct LDL - Serum or Plasma | 0.904 |  |
| 3007821 | Glucose [Moles/volume] in Serum or Plasma --baseline | 0.903 |  |
| 40762499 | Oxygen saturation in Arterial blood by Pulse oximetry | 0.903 | 1874 |
| 3013721 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 0.903 | 19 |
| 1469712 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.899 |  |
| 3010946 | Lipid 1996 panel - Serum or Plasma | 0.899 |  |
| 3006669 | Glucose [Moles/volume] in Serum or Plasma --pre 12 hour fast | 0.899 |  |
| 3038920 | Triglyceride in VLDL [Moles/volume] in Serum or Plasma | 0.898 |  |
| 3001308 | Cholesterol in LDL [Moles/volume] in Serum or Plasma | 0.897 | 92 |
| 42870364 | Natriuretic peptide.B prohormone N-Terminal [Mass/volume] in Blood by Immunoassay | 0.895 |  |
| 44787051 | Middle East respiratory syndrome coronavirus (MERS-CoV) RNA panel - Specimen | 0.895 |  |
| 3041735 | Creatinine [Moles/volume] in Serum or Plasma --baseline | 0.894 |  |
| 3019038 | Triglyceride [Moles/volume] in Serum or Plasma --12 hours fasting | 0.894 |  |
| 40759254 | Cholesterol in HDL 2b [Moles/volume] in Serum or Plasma | 0.894 |  |
| 40762887 | Creatinine [Moles/volume] in Blood | 0.894 | 283 |
| 46234770 | C reactive protein [Moles/volume] in Serum or Plasma | 0.894 |  |
| 1175909 | Lipoprotein metabolism panel - Serum or Plasma | 0.893 |  |
| 42868692 | Triglyceride [Moles/volume] in Blood | 0.892 | 1592 |
| 646953 | Natriuretic peptide B [Measurement] in Serum or Plasma | 0.891 |  |
| 3019056 | Alanine aminotransferase/Aspartate aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.890 |  |
| 3031203 | Blood pressure panel | 0.888 |  |
| 3028465 | Gamma glutamyl transferase [Enzymatic activity/volume] in Body fluid | 0.888 |  |
| 3012789 | Triglyceride [Moles/volume] in Specimen | 0.887 |  |
| 3028566 | Urate [Moles/volume] in Specimen | 0.886 |  |
| 3013502 | Oxygen saturation in Blood | 0.884 | 426 |
| 3000784 | Alanine aminotransferase [Enzymatic activity/volume] in Body fluid | 0.884 |  |
| 42870592 | CBC W Differential panel, method unspecified - Blood | 0.884 |  |
| 3006442 | Creatine [Moles/volume] in Serum or Plasma | 0.884 |  |
| 3007238 | Nucleated erythrocytes [#/volume] in Blood by Automated count | 0.884 | 1247 |
| 3026726 | Creatinine [Moles/volume] in Specimen | 0.884 |  |
| 3010156 | C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method | 0.884 | 348 |
| 3050630 | Triglyceride in HDL 3 [Moles/volume] in Serum or Plasma | 0.883 |  |
| 645672 | Alanine aminotransferase [Measurement] in Serum or Plasma | 0.883 |  |
| 40763620 | Respiratory pathogens DNA and RNA 12b panel - Specimen by NAA with probe detection | 0.881 |  |
| 3043536 | Glucose [Moles/volume] in Serum or Plasma --12 AM specimen | 0.880 |  |
| 3052295 | Natriuretic peptide B [Moles/volume] in Serum or Plasma | 0.880 |  |
| 46235394 | Respiratory pathogens RNA 8 panel - Specimen by NAA with probe detection | 0.879 |  |
| 3028515 | Gamma glutamyl transferase [Enzymatic activity/volume] in Urine | 0.879 |  |
| 44787055 | CBC W Differential panel - Cord blood | 0.878 |  |
| 42528762 | Erythrocytes [#/volume] in Bone marrow by Automated count | 0.878 |  |
| 3029826 | Respiratory pathogens DNA and RNA 12a panel - Specimen by NAA with probe detection | 0.878 |  |
| 3027388 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma by No addition of P-5'-P | 0.878 |  |
| 3035933 | Granulocytes/Leukocytes in Blood | 0.878 |  |
| 649308 | Natriuretic peptide.B prohormone N-Terminal [Measurement] in Serum or Plasma | 0.877 |  |
| 40762876 | Glucose [Moles/volume] in Serum or Plasma --3 PM specimen | 0.877 |  |
| 3009508 | Creatinine [Moles/volume] in Urine | 0.876 | 161 |
| 3022487 | Cholesterol in VLDL [Moles/volume] in Serum or Plasma | 0.875 | 219 |
| 3045291 | Glucose [Moles/volume] in Serum or Plasma --12 PM specimen | 0.874 |  |
| 3018251 | Fasting glucose [Moles/volume] in Serum or Plasma | 0.874 | 332 |
| 3027874 | Urate [Moles/volume] in Urine | 0.874 | 1405 |
| 3051698 | Osmolality of Urine by calculation | 0.874 |  |
| 3020491 | Glucose [Moles/volume] in Blood | 0.873 | 13 |
| 3040495 | Creatinine [Moles/volume] in Serum or Plasma --pre dialysis | 0.873 |  |
| 3000850 | Epithelial cells [#/volume] in Urine | 0.873 |  |
| 40757349 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Blood | 0.872 | 362 |
| 648940 | C reactive protein [Measurement] in Serum or Plasma | 0.872 |  |
| 3034739 | Osmolality of Serum or Plasma by calculation | 0.872 | 1585 |
| 3030792 | Cholesterol in HDL [Moles/volume] in Body fluid | 0.871 |  |
| 37021212 | Respiratory pathogens DNA and RNA panel - Respiratory system specimen by NAA with probe detection | 0.871 |  |
| 647936 | Urate [Measurement] in Serum or Plasma | 0.870 |  |
| 3002385 | Erythrocyte distribution width [Ratio] | 0.869 |  |
| 36031267 | Cholesterol in LDL [Moles/volume] in Serum or Plasma by Calculated by Martin-Hopkins | 0.869 |  |
| 3014502 | Neutrophils/Leukocytes in Body fluid | 0.869 | 954 |
| 645112 | Stenotrophomonas maltophilia.multidrug resistant [Presence] in Specimen by Organism specific culture | 0.869 |  |
| 647875 | Respiratory pathogens DNA and RNA panel - Specimen by NAA with non-probe detection | 0.867 |  |
| 40766210 | Pseudomonas aeruginosa.multidrug resistant isolate [Presence] in Specimen by Organism specific culture | 0.867 |  |
| 3009596 | Cholesterol in VLDL [Mass/volume] in Serum or Plasma by calculation | 0.866 |  |
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.864 |  |
| 3010307 | Gamma glutamyl transferase/Aspartate aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.864 |  |
| 3965814 | Lung cancer panel | 0.863 |  |
| 3050687 | CBC WO Differential panel - Cord blood | 0.860 |  |
| 3026101 | Triglyceride [Moles/volume] in Body fluid | 0.859 |  |
| 42870529 | Cholesterol in LDL [Moles/volume] in Serum or Plasma by Direct assay | 0.858 | 249 |
| 3008520 | Urate [Moles/volume] in Body fluid | 0.858 |  |
| 3040324 | Triglyceride in HDL 2 [Moles/volume] in Serum or Plasma | 0.858 |  |
| 40757504 | Cholesterol.non-esterified [Moles/volume] in Serum or Plasma | 0.857 |  |
| 42868678 | Cholesterol non HDL [Moles/volume] in Serum or Plasma | 0.856 | 289 |
| 3051387 | C reactive protein [Mass/volume] in Capillary blood | 0.856 |  |
| 3033543 | Specific gravity of Urine | 0.855 | 122 |
| 40758961 | Cholesterol esters [Moles/volume] in Serum or Plasma | 0.854 |  |
| 36660039 | Respiratory pathogens DNA and RNA panel - Lower respiratory specimen by NAA with probe detection | 0.853 |  |
| 3028766 | C reactive protein [Titer] in Serum or Plasma | 0.852 |  |
| 3003159 | Erythrocytes [#/volume] in Body fluid by Automated count | 0.851 | 1726 |
| 40763528 | Reticulocytes [#/volume] in Blood by Automated count | 0.851 |  |
| 3039919 | Specific gravity of Urine by Automated test strip | 0.851 |  |
| 3026782 | Osmolality of Urine | 0.850 | 556 |
| 3035320 | C reactive protein [Mass/volume] in Body fluid | 0.849 |  |
| 3034458 | CD4+CD45RA+ cells/CD8 Cells [# Ratio] in Blood | 0.849 |  |
| 40758231 | Respiratory pathogens panel - Specimen by Organism specific culture | 0.848 |  |
| 40765001 | Erythrocytes [#/volume] in Blood from Fetus by Automated count | 0.847 |  |
| 3008342 | Neutrophils/Leukocytes in Blood by Automated count | 0.847 | 25 |
| 3002888 | Erythrocyte distribution width [Entitic volume] | 0.845 |  |
| 3050452 | Leukogram panel - Blood | 0.845 |  |
| 3020779 | Urea [Moles/volume] in Serum or Plasma | 0.845 |  |
| 1469858 | Troponin T.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.845 |  |
| 40760892 | CBC W Ordered Manual Differential panel - Blood | 0.844 |  |
| 40765008 | Erythrocyte distribution width [Ratio] in Blood from Fetus by Automated count | 0.844 |  |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.844 |  |
| 3016087 | Cholesterol.total/Cholesterol in HDL [Molar ratio] in Serum or Plasma | 0.843 | 91 |
| 3000965 | C reactive protein [Presence] in Serum or Plasma | 0.843 | 1281 |
| 21491816 | Respiratory pathogens DNA and RNA panel - Nasopharynx by NAA with probe detection | 0.842 |  |
| 1175889 | Cholesterol in LDL 1 [Moles/volume] in Serum or Plasma | 0.840 |  |
| 37021437 | Respiratory pathogens DNA and RNA panel - Lower respiratory specimen by NAA with non-probe detection | 0.840 |  |
| 3027368 | Neutrophils/Leukocytes in Blood by Manual count | 0.838 | 1191 |
| 40761507 | Platelet morphology panel - Blood | 0.838 |  |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.837 |  |
| 1175998 | Cholesterol in LDL 2 [Moles/volume] in Serum or Plasma | 0.837 |  |
| 37021116 | Middle East respiratory syndrome coronavirus (MERS-CoV) RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.836 |  |
| 36659876 | Respiratory viral pathogens DNA and RNA panel - Lower respiratory specimen by NAA with probe detection | 0.836 |  |
| 46236739 | Respiratory pathogens DNA and RNA 14 panel - Nasopharynx by NAA with probe detection | 0.835 |  |
| 3040005 | Erythroid cells [#/volume] in Blood or Marrow | 0.835 |  |
| 3019800 | Troponin T.cardiac [Mass/volume] in Serum or Plasma | 0.834 | 291 |
| 40765009 | Nucleated erythrocytes [#/volume] in Blood from Fetus by Automated count | 0.834 |  |
| 3012713 | Urate [Moles/volume] in 24 hour Urine | 0.833 |  |
| 3022979 | Gamma glutamyl cysteine synthetase [Enzymatic activity/volume] in Serum | 0.833 |  |
| 3027114 | Cholesterol [Mass/volume] in Serum or Plasma | 0.833 |  |
| 40762014 | CD4+CD45RO+ cells/CD3+CD4+ (T4 helper) cells [# Ratio] in Blood | 0.832 |  |
| 3027017 | Erythrocytes [#/volume] in Blood by Manual count | 0.832 |  |
| 3026514 | Neutrophils/Leukocytes in Sputum | 0.832 |  |
| 1988420 | Gas and electrolytes panel - Arterial blood | 0.831 |  |
| 3015548 | Cholesterol [Moles/volume] in Specimen | 0.830 |  |
| 706164 | Middle East respiratory syndrome coronavirus (MERS-CoV) RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.828 |  |
| 3042301 | Urate [Moles/volume] in Synovial fluid | 0.828 |  |
| 21491327 | Allopurinol [Moles/volume] in Serum or Plasma | 0.828 |  |
| 42869448 | Hematopoietic progenitor cells [#/volume] in Blood by Automated count | 0.828 |  |
| 3017354 | Segmented neutrophils/Leukocytes in Blood | 0.828 |  |
| 40765163 | Bordetella sp DNA panel - Specimen by NAA with probe detection | 0.827 |  |
| 40769783 | Troponin T.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.826 |  |
| 706162 | Respiratory viral pathogens DNA and RNA panel - Respiratory system specimen Qualitative by NAA with probe detection | 0.826 |  |
| 3004391 | Epithelial cells [#/volume] in Urine by Manual count | 0.825 |  |
| 36303442 | Epithelial cells [#/volume] in Urine by Automated | 0.824 |  |
| 43054874 | Cells [#/volume] in Body fluid | 0.823 |  |
| 37020753 | Middle East respiratory syndrome coronavirus (MERS-CoV) RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.823 |  |
| 40760141 | CBC W Reflex Manual Differential panel - Blood | 0.822 |  |
| 40758546 | Short blood pressure panel | 0.822 |  |
| 3026365 | Gamma glutamyl transferase [Enzymatic activity/volume] in Semen | 0.821 |  |
| 36032012 | Gamma glutamyl transferase [Enzymatic activity/volume] in DBS | 0.821 |  |
| 36305830 | Middle East respiratory syndrome coronavirus (MERS-CoV) RNA [Presence] in Aspirate by NAA with probe detection | 0.820 |  |
| 3021398 | Gamma glutamyl transferase [Enzymatic activity/volume] in Amniotic fluid | 0.819 |  |
| 40761535 | Cells panel - Urine sediment | 0.818 |  |
| 1469591 | Tubular cells [#/volume] in Urine sediment | 0.818 |  |
| 44787116 | Middle East respiratory syndrome coronavirus (MERS-CoV) N2 gene RNA [Presence] in Specimen by NAA with probe detection | 0.818 |  |
| 3002736 | Platelet distribution width [Entitic volume] in Blood by Automated count | 0.817 | 1233 |
| 3966093 | Adenovirus DNA and Human Metapneumovirus and Rhinovirus RNA panel - Respiratory specimen by NAA with probe detection | 0.817 |  |
| 3049383 | Erythrocyte distribution width [Ratio] in Cord blood | 0.817 |  |
| 3002582 | Erythrocytes [#/volume] in Urine | 0.816 |  |
| 3965527 | Cardiovascular risk panel - Serum or Plasma | 0.815 |  |
| 40761533 | Casts panel - Urine sediment | 0.815 |  |
| 1469723 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.814 |  |
| 40758360 | Electrolytes panel - Blood | 0.814 |  |
| 40761508 | Leukocyte morphology panel - Blood | 0.814 |  |
| 3004410 | Hemoglobin A1c/Hemoglobin.total in Blood | 0.813 | 81 |
| 44787115 | Middle East respiratory syndrome coronavirus (MERS-CoV) N3 gene RNA [Presence] in Specimen by NAA with probe detection | 0.813 |  |
| 37021547 | Middle East respiratory syndrome coronavirus (MERS-CoV) RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.813 |  |
| 40761534 | Crystals panel - Urine sediment | 0.810 |  |
| 3013166 | Neutrophils/Leukocytes in Synovial fluid | 0.810 |  |
| 36304167 | Respiratory pathogens panel - Nasopharynx by Immunofluorescence | 0.810 |  |
| 3005673 | Hemoglobin A1c/Hemoglobin.total in Blood by HPLC | 0.809 | 215 |
| 3021337 | Troponin I.cardiac [Mass/volume] in Serum or Plasma | 0.806 | 113 |
| 36303657 | Middle East respiratory syndrome coronavirus (MERS-CoV) RNA [Presence] in Nasopharynx by NAA with probe detection | 0.805 |  |
| 40762501 | Oxygen saturation in Arterial blood by Pulse oximetry --on room air | 0.805 |  |
| 647635 | Middle East respiratory syndrome coronavirus (MERS-CoV) RNA [Presence] in Specimen by NAA with non-probe detection | 0.804 |  |
| 3042527 | Neutrophils.immature/Leukocytes in Blood | 0.804 |  |
| 3006504 | Eosinophils/Leukocytes in Blood | 0.804 | 49 |
| 3037816 | CD4+CD8+ cells/100 cells in Blood | 0.804 |  |
| 3966454 | Gas and electrolytes panel - Venous blood | 0.799 |  |
| 3038950 | Acinetobacter sp multidrug resistant identified in Specimen by Organism specific culture | 0.799 |  |
| 3022036 | Colony count [#/volume] in Urine | 0.798 |  |
| 3041326 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Tissue | 0.798 |  |
| 3036941 | Urinalysis complete panel - Urine | 0.798 |  |
| 36306105 | Troponin I.cardiac [Mass/volume] in Serum or Plasma by High sensitivity method | 0.797 |  |
| 3019902 | Methicillin resistant Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.795 | 146 |
| 3014859 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Body fluid | 0.795 |  |
| 40758528 | Diabetes tracking panel | 0.795 |  |
| 21491103 | Multiple drug resistant gram negative organism [Identifier] in Specimen by Culture | 0.795 |  |
| 40762508 | Oxygen saturation in Arterial blood by Pulse oximetry --resting | 0.795 | 1647 |
| 3048529 | Troponin T.cardiac [Mass/volume] in Blood | 0.793 |  |
| 3965306 | Troponin T.cardiac [Mass/volume] in 6 hour Serum or Plasma | 0.792 |  |
| 40762498 | Oxygen saturation in Blood Preductal by Pulse oximetry | 0.792 | 3000 |
| 40770913 | Hypoglycemics panel - Serum or Plasma | 0.791 |  |
| 46235808 | Reticulocyte distribution width [Ratio] in Blood by calculation | 0.791 |  |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.790 |  |
| 3007263 | Hemoglobin A1c/Hemoglobin.total in Blood by calculation | 0.790 |  |
| 3034022 | Lactate dehydrogenase panel - Serum or Plasma | 0.790 |  |
| 1469828 | Troponin I.cardiac [Mass/volume] in Serum, Plasma or Blood by High sensitivity method | 0.788 |  |
| 3008295 | Osmolality of Serum or Plasma | 0.787 | 329 |
| 1091200 | Bacteria [#/volume] in Urine | 0.787 |  |
| 40761536 | Microorganisms panel - Urine sediment | 0.786 |  |
| 42869630 | Hemoglobin A1c/Hemoglobin.total [Pure mass fraction] in Blood | 0.786 |  |
| 3966498 | Troponin T. cardiac [Mass/volume] in 2 hour 5th generation Serum or Plasma | 0.784 |  |
| 3044045 | Cell count and Differential panel - Body fluid | 0.784 |  |
| 40762506 | Oxygen saturation in Arterial blood by Pulse oximetry --pre physiotherapy | 0.783 |  |
| 1092301 | Erythrocytes [#/volume] in Urine sediment | 0.782 |  |
| 3001695 | Erythrocytes [#/volume] in Urine by Manual count | 0.782 |  |
| 37019495 | Oxysterols panel - Serum or Plasma | 0.782 |  |
| 3019897 | Erythrocyte [DistWidth] in Blood by Automated count | 0.780 | 24 |
| 3020073 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Specimen | 0.780 |  |
| 3015209 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bone marrow | 0.780 |  |
| 3030688 | Urinalysis panel - Urine by Automated | 0.779 |  |
| 3964699 | Gas and electrolytes point of care panel - Venous blood | 0.777 |  |
| 3048885 | Erythrogram panel - Blood | 0.776 |  |
| 3019150 | Specific gravity of Urine by Refractometry | 0.776 |  |
| 3041668 | Urinalysis microscopic panel [#/area] - Urine sediment by Automated count | 0.775 |  |
| 44787095 | Platelet distribution width [Entitic volume] in Cord blood by Automated count | 0.775 |  |
| 3016502 | Oxygen saturation in Arterial blood | 0.775 | 451 |
| 40762509 | Oxygen saturation in Blood Postductal by Pulse oximetry | 0.774 | 3000 |
| 3005446 | Hemoglobin A1/Hemoglobin.total in Blood | 0.772 | 836 |
| 3031750 | Smear morphology panel - Blood | 0.772 |  |
| 1617179 | Oxygen saturation in 12 hour mean Arterial blood by Pulse oximetry | 0.771 |  |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 0.769 |  |
| 40761511 | CBC panel - Blood by Automated count | 0.768 |  |
| 3012898 | Urea [Moles/volume] in Urine | 0.767 |  |
| 3021901 | Oxygen saturation in Capillary blood | 0.766 |  |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.766 |  |
| 40758548 | Home drug screening panel - Urine | 0.765 |  |
| 36660656 | CBC W Differential panel - Stem cell product | 0.764 |  |
| 1469476 | Anti-hypertensive drug panel - Urine | 0.764 |  |
| 1001509 | Gas and Carbon monoxide and Electrolytes panel - Arterial blood | 0.764 |  |
| 3003181 | Sodium [Moles/volume] in Urine | 0.762 | 412 |
| 3964676 | Basic metabolic and hematocrit panel - Blood | 0.761 |  |
| 1260092 | Basic metabolic with hemoglobin and hematocrit panel - Blood | 0.760 |  |
| 3023601 | Vancomycin resistant enterococcus [Presence] in Specimen by Organism specific culture | 0.757 |  |
| 3045740 | CD56 cells/CD38 Cells [# Ratio] in Blood | 0.757 |  |
| 3003309 | Hemoglobin A1c/Hemoglobin.total in Blood by Electrophoresis | 0.753 |  |
| 1989140 | Red blood cell membrane evaluation panel - Red Blood Cells | 0.753 |  |
| 3029361 | Urinalysis dipstick panel - Urine by Automated test strip | 0.752 |  |
| 3965213 | Electrolytes panel - Venous blood | 0.751 |  |
| 1761484 | Gram negative bacteria.colistin resistant identified in Stool by Organism specific culture | 0.750 |  |
| 3965452 | Osmolality of Arterial blood by calculation | 0.750 |  |
| 36659824 | Bacteria.carbapenem resistant identified in Specimen by Organism specific culture | 0.749 |  |
| 3024629 | Glucose [Mass/volume] in Urine by Test strip | 0.748 |  |
| 42869632 | Hemoglobin A/Hemoglobin.total [Pure mass fraction] in Blood by HPLC | 0.747 |  |
| 42870589 | Drugs of abuse panel - Urine by Screen method | 0.745 |  |
| 3039417 | Platelet distribution width [Ratio] in Blood | 0.745 |  |
| 3031973 | Hemoglobin A/Hemoglobin.total in Blood by HPLC | 0.744 |  |
| 3044282 | Cell count and Differential panel - Pleural fluid | 0.744 |  |
| 3043075 | Burkholderia sp [Presence] in Specimen by Organism specific culture | 0.743 |  |
| 3012764 | Erythrocyte morphology finding [Identifier] in Blood | 0.743 | 132 |
| 3041230 | Basic metabolic panel - Blood | 0.742 |  |
| 1761890 | Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.741 |  |
| 40762352 | Hemoglobin A1c/Hemoglobin.total standardized per IFCC-RMP for CDT in Blood | 0.740 |  |
| 3964627 | Osmolality of Venous blood by calculation | 0.739 |  |
| 3031639 | Reticulocytes panel - Blood | 0.738 |  |
| 3023329 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter | 0.738 |  |
| 36032094 | Hemoglobin A1c/Hemoglobin.total in DBS | 0.738 |  |
| 40758490 | Osmolality of Urine--baseline | 0.737 |  |
| 3045777 | Cell count and Differential panel - Synovial fluid | 0.737 |  |
| 36032270 | Cell count and Differential panel - Sputum by Manual count | 0.736 |  |
| 3034076 | Specific gravity of 24 hour Urine | 0.736 |  |
| 3021223 | Hemogram without Platelets and with Manual Differential panel - Blood | 0.736 |  |
| 3044298 | Cell count and Differential panel - Cerebral spinal fluid | 0.735 |  |
| 3006147 | Osmolality of 24 hour Urine | 0.734 |  |
| 43055246 | Days in therapeutic INR range/Days INR result determined [Ratio] | 0.733 |  |
| 1259511 | Gas and Lactate panel - Arterial blood | 0.732 |  |
| 3043812 | Specific gravity of 24 hour Urine by Refractometry | 0.731 |  |
| 42870588 | Differential panel, method unspecified - Blood | 0.730 |  |
| 21494996 | Respiratory assessment panel | 0.729 |  |
| 40761809 | Adulterants panel - Urine | 0.726 |  |
| 36031493 | Protein/Osmolality [Ratio] in Urine | 0.725 |  |
| 3011493 | Urea nitrogen [Moles/volume] in Urine | 0.725 |  |
| 3029991 | Specific gravity of Urine by Refractometry automated | 0.725 |  |
| 3044016 | Orthostatic blood pressure panel | 0.721 |  |
| 648159 | Density [Mass/volume] in Urine | 0.721 |  |
| 3019794 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --post therapy | 0.721 |  |
| 3008770 | Glucose [Moles/volume] in Urine by Test strip | 0.720 | 73 |
| 3001204 | Oxalate [Moles/volume] in Urine | 0.719 | 1876 |
| 3022621 | pH of Urine by Test strip | 0.719 | 59 |
| 3051257 | Erythrocyte morphology [Interpretation] in Urine sediment by Light microscopy Narrative | 0.718 |  |
| 3018163 | Specimen specific gravity acceptable [Presence] in Urine | 0.718 |  |
| 36660531 | Glycerol [Moles/volume] in Serum by calculation | 0.717 |  |
| 3025742 | Calcium/Osmolality [Ratio] in Serum or Plasma | 0.716 |  |
| 3041983 | Urinalysis type of crystal panel - Urine by Computer assisted method | 0.715 |  |
| 3046619 | Specific gravity of Specimen | 0.715 |  |
| 40768507 | Time to expiratory gas flow.max | 0.711 |  |
| 1259993 | Gas and Lactate panel - Venous blood | 0.710 |  |
| 3037072 | Urobilinogen [Mass/volume] in Urine by Test strip | 0.710 |  |
| 3028846 | Blood pressure device panel | 0.709 |  |
| 1989577 | Hemolytic anemia panel | 0.709 |  |
| 36203185 | Blood pressure panel with all children optional | 0.706 |  |
| 1616739 | Blood pressure panel 24 hour mean | 0.706 |  |
| 42869550 | Maximum expiratory gas flow Respiratory system airway by Peak flow meter --pre therapy | 0.706 |  |
| 3023227 | Gas and Carbon monoxide panel - Blood | 0.706 |  |
| 40760142 | Auto Differential panel - Blood | 0.706 |  |
| 3013885 | Electrolytes 3 panel - Body fluid | 0.702 |  |
| 3022035 | Basic metabolic 2000 panel - Serum or Plasma | 0.700 |  |
| 21491691 | Coronary artery disease risk factor panel | 0.698 |  |
| 3043216 | Cardiovascular physiologic and EKG assessment panel | 0.695 |  |
| 21490894 | Expiratory airway gas flow | 0.694 |  |
| 21491692 | Cardiovascular disease history panel | 0.692 |  |
| 21494970 | Cardiovascular physiologic assessment panel | 0.690 |  |
| 3032448 | Specific gravity of Urine by Adjustment to pH 7.4 | 0.689 |  |
| 21493451 | Spirometry panel | 0.684 |  |
| 3023075 | Type of EKG leads | 0.684 |  |
| 36031928 | Blood pressure panel mean systolic and mean diastolic | 0.679 |  |
| 1091477 | Lung cancer screening [Presence] based on Plasma cell-free DNA by Sequencing | 0.679 |  |
| 42868465 | Maximum expiratory gas flow Respiratory system airway --post bronchodilation | 0.673 |  |
| 42528497 | Personal best peak expiratory gas flow Respiratory system airway | 0.673 |  |
| 40758532 | Asthma tracking panel | 0.667 |  |
| 3007733 | Chloride [Moles/volume] in Urine | 0.667 | 697 |
| 42868466 | Maximum expiratory gas flow/Predicted maximum expiratory gas flow Respiratory system airway --pre bronchodilation | 0.666 |  |
| 42868463 | Maximum expiratory gas flow Respiratory system airway Predicted | 0.666 |  |
| 36305974 | Lung cancer antibody panel - Serum or Plasma by Immunoassay | 0.665 |  |
| 42869549 | Maximum expiratory gas flow Respiratory system airway --pre therapy | 0.664 |  |
| 1988764 | Electromyography panel | 0.654 |  |
| 37019864 | Opioid risk tool panel | 0.652 |  |
| 1259654 | Diagnostic multisection transesophageal and cardioversion panel Heart | 0.652 |  |
| 40758534 | Heart failure tracking panel | 0.650 |  |
| 36303949 | Wells pulmonary embolism risk calculator panel | 0.650 |  |
| 36306151 | Blood pressure with exercise and post exercise panel | 0.649 |  |
| 21493450 | Pulmonary function test panel | 0.648 |  |
| 36032043 | Adrenal cancer risk assessment and urine steroid fractions panel | 0.647 |  |
| 1988411 | Permanent pacemaker panel | 0.642 |  |
| 44816766 | Metabolic disorder therapy monitoring panel - DBS | 0.642 |  |
| 3044933 | Cardiac 2D echo panel | 0.641 |  |
| 3013512 | EKG study | 0.638 |  |
| 1616370 | Osteoporosis Index of Risk panel | 0.635 |  |
| 1091078 | Diabetes mellitus type 1 autoimmune panel - Serum or Plasma | 0.633 |  |
| 1988318 | Temporary pacemaker panel | 0.628 |  |
| 3044671 | QRS duration {Electrocardiograph lead} | 0.625 |  |
| 3029340 | Insulin XXX challenge panel - Serum | 0.624 |  |
| 3964661 | Solitary lung nod malignancy risk [Scale] Qualitative by Calculated.Nodify XL2 | 0.615 |  |
| 36659996 | Revised Pretransplant Assessment of Mortality (PAM) Score panel | 0.613 |  |
| 3965967 | Solitary lung nod malignancy risk [Scale] Qualitative by Calculated.Nodify CDT | 0.611 |  |
| 3033145 | Hemoglobin A1c measurement device panel | 0.594 |  |
| 21494068 | Projected heparin concentration to reach target ACT [Units/volume] in Blood by calculation | 0.581 |  |
| 3011740 | Phenytoin.total/Phenytoin.free [Mass Ratio] in Serum or Plasma | 0.570 |  |
| 43533840 | Percent heparin inhibition [Ratio] in Serum | 0.568 |  |
| 21493274 | Glucose meter to reference method correlation [Ratio] in Serum, Plasma or Blood by calculation | 0.555 |  |
| 3008561 | Activated protein C resistance [Time Ratio] in Platelet poor plasma by Coagulation assay | 0.548 | 797 |
| 1470024 | Time above range, high in Reporting Period Interstitial fluid by calculation | 0.543 |  |
| 3035353 | Method for calculating time interval of first course of treatment | 0.535 |  |
| 1761456 | Vitamin A/Retinol binding protein [Ratio] in Serum or Plasma | 0.530 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2403 | -cd4-solujensuhdecd8-soluihin |  | 100% | name+values | 667 | 100 | [0.26, 0.36, 0.55, 0.72, 0.99, 1.35, 1.81, 2.33, 3] |  |  |  | CD4/CD8 [# Ratio] in Blood |
| 2404 | -respiratoristenmikrobientutkimus |  | 100% | name | 915 | 100 |  |  |  |  | Respiratory pathogens panel - Respiratory specimen |
| 2405 | aikuistyypindiabetes,vuosikontrolli |  | 100% | name | 120 | 100 |  |  |  |  | Diabetes mellitus follow-up panel |
| 2406 | b-diffi,erittelylaskenta,klooni |  | 100% | name | 142 | 100 |  |  | Blood |  | Leukocyte differential count panel - Blood |
| 2407 | b-talteen.kttutkimusnäytteille |  | 100% | name | 108 | 100 |  |  | Blood |  |  |
| 2408 | b-täydellinenverenkuva |  | 100% | name | 22505 | 100 |  |  | Blood |  | CBC with differential panel - Blood |
| 2409 | b-täydellinenverenkuva(pi) |  | 100% | name | 226 | 100 |  |  | Blood |  | CBC with differential panel - Blood |
| 2410 | e-punasolujenkokojakaum | % | 100% | name+unit+values | 55570 | 0 | [12.19, 12.59, 12.95, 13.26, 13.67, 14.09, 14.51, 14.98, 15.7] |  | Erythrocyte |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2411 | e-punasolujenkokojakaum |  | 0% | name | 7 | 100 |  |  | Erythrocyte |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2412 | e-punasolujenkokojakauma | % | 99% | name+unit+values | 196935 | 0 | [12.01, 13, 13, 13, 13.68, 14, 14.06, 15, 16.36] |  | Erythrocyte |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2413 | e-punasolujenkokojakauma |  | 1% | name+values | 1688 | 100 | [15, 15, 15.97, 16, 16, 16.48, 17, 18, 19.67] |  | Erythrocyte |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2414 | e-rdw,punasolujenkokojakauma | % | 100% | name+unit+values | 25929 | 0 | [12.09, 13, 13, 13.03, 14, 14, 14.99, 15.72, 17.05] |  | Erythrocyte |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2415 | e-rdw,punasolujenkokojakauma |  | 0% | name | 76 | 100 |  |  | Erythrocyte |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2416 | happisaturaatiovastaanotolla |  | 100% | name | 231 | 100 |  |  |  |  | Oxygen saturation in Blood by Pulse oximetry |
| 2417 | hba1cvieritestipoliklinikoille | mmol/mol | 100% | name+unit+values | 151 | 0 | [44, 47.52, 51.65, 54.55, 57.33, 61.17, 67.73, 72, 82.12] |  |  |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood by Point-of-care test |
| 2418 | kemiallinenseulonta |  | 100% | name | 5053 | 100 |  |  |  |  | Urinalysis chemical screen panel - Urine |
| 2419 | kemiallinenseulonta,virtsasta |  | 100% | name | 635 | 100 |  |  |  |  | Urinalysis chemical screen panel - Urine |
| 2420 | kemiallinenseulonta,virtsasta␤ |  | 100% | name | 13236 | 100 |  |  |  |  | Urinalysis chemical screen panel - Urine |
| 2421 | keuhkoahtaumatautiriski(tupakoivilla) |  | 100% | name | 16624 | 100 |  |  |  |  | COPD risk assessment panel |
| 2422 | keuhkosyöpäriski(tupakoivilla) |  | 100% | name | 16625 | 100 |  |  |  |  | Lung cancer risk assessment panel |
| 2423 | konsultaatiopyyntöerikoislääkärille |  | 100% | name | 404 | 100 |  |  |  |  |  |
| 2424 | l-liuskatumaisetneutrofiilit␤ | % | 100% | name+unit+values | 1196 | 0 | [13.15, 25.85, 35.73, 42.46, 47.74, 54.3, 62, 69.63, 78.9] |  | Leukocyte |  | Neutrophils/Leukocytes in Blood |
| 2425 | liuskatumaisetneutrofiilit | % | 100% | name+unit+values | 178 | 0 | [43.43, 49.11, 52.65, 55.28, 57.46, 60.28, 63.81, 67.35, 72.68] |  |  |  | Neutrophils/Leukocytes in Blood |
| 2426 | middleeastrespiratorysyndro |  | 100% | name | 107 | 100 |  |  |  |  | Middle East respiratory syndrome coronavirus NAA panel - Respiratory specimen |
| 2427 | mittaustulos(mg/l) |  | 100% | name+values | 467 | 100 | [62.77, 79.74, 112.23, 155.86, 234.07, 345.39, 553.16, 970.25, 2054.43] |  |  |  |  |
| 2428 | mittaustulos(mmol/l) |  | 100% | name+values | 727 | 100 | [1.3, 1.99, 2.48, 3.01, 3.85, 5.13, 9.36, 30.82, 61.62] |  |  |  |  |
| 2429 | moniresistentitgramnegatiivis |  | 100% | name | 141 | 100 |  |  |  |  | Gram negative bacteria.multidrug resistant [Presence] in Specimen by Organism specific culture |
| 2430 | n-terminaalinenpro-bnp(nt-probnp) | ng/l | 99% | name+unit+values | 2053 | 0 | [69.55, 126.49, 216.69, 368.97, 703.13, 1221.6, 2011.38, 3140.89, 5892.21] |  |  |  | Natriuretic peptide B.N-terminal pro [Mass/volume] in Serum or Plasma |
| 2431 | n-terminaalinenpro-bnp(nt-probnp) |  | 1% | name | 19 | 100 |  |  |  |  | Natriuretic peptide B.N-terminal pro [Mass/volume] in Serum or Plasma |
| 2432 | näyteenlaatu,lipehemoikte,advia |  | 100% | name | 142 | 100 |  |  |  |  |  |
| 2433 | näytteenotto(nordlab) |  | 100% | name | 605 | 100 |  |  |  |  |  |
| 2434 | näytteenottoislab |  | 100% | name | 549 | 100 |  |  |  |  |  |
| 2435 | näytteenottomaksu |  | 100% | name | 177 | 100 |  |  |  |  |  |
| 2436 | osmolaliteetinestimaatti | mosm/kgh2o | 95% | name+unit+values | 5740 | 0 | [191.37, 245.31, 290.83, 332.27, 376.47, 424.83, 483.94, 560.86, 671.32] |  |  |  | Osmolality.calculated [Moles/mass] in Serum or Plasma by calculation |
| 2437 | osmolaliteetinestimaatti |  | 5% | name | 320 | 100 |  |  |  |  | Osmolality.calculated [Moles/mass] in Serum or Plasma by calculation |
| 2438 | osmolaliteetti,virtsa | mosm/kgh2o | 97% | name+unit+values | 310 | 0 | [180.62, 228.94, 270.61, 303.35, 343.48, 383.68, 433.88, 523.42, 615.38] |  |  |  | Osmolality [Moles/mass] in Urine |
| 2439 | osmolaliteetti,virtsa |  | 3% | name | 11 | 100 |  |  |  |  | Osmolality [Moles/mass] in Urine |
| 2440 | osmolaliteetti,virtsasta␤ | mosm/kgh2o | 100% | name+unit+values | 150 | 0 | [160, 215.89, 248, 281.67, 311.7, 350.56, 394.33, 486.67, 588.25] |  |  |  | Osmolality [Moles/mass] in Urine |
| 2441 | osmolaliteettiestimoitu | mosm/kgh2o | 81% | name+unit+values | 212 | 0 | [410.43, 480, 536.25, 622.18, 682.22, 742.52, 843.5, 919, 1000] |  |  |  | Osmolality.calculated [Moles/mass] in Urine by calculation |
| 2442 | osmolaliteettiestimoitu | mosm/l | 19% | name+unit | 51 | 0 |  |  |  |  | Osmolarity.calculated [Moles/volume] in Urine by calculation |
| 2443 | otettujenpurkkien/putkienlkm | u | 100% | name+unit+values | 36443 | 0 | [1, 1, 1, 1, 1, 1.91, 2.75, 3.05, 4] |  |  |  |  |
| 2444 | p-talteen.kttutkimusnäytteille |  | 100% | name | 228 | 100 |  |  | Plasma |  |  |
| 2445 | p-uraatti,plasma(umol/l) | umol/l | 100% | name+unit+values | 182 | 0 | [240.76, 275.03, 305.52, 328.86, 351.75, 381.77, 409.12, 446.27, 490.77] |  | Plasma |  | Urate [Moles/volume] in Serum or Plasma |
| 2446 | patologianlaskutus,päijät-häme |  | 100% | name | 167 | 100 |  |  |  |  |  |
| 2447 | patologiannäytteenkäsittely |  | 100% | name | 120 | 100 |  |  |  |  |  |
| 2448 | pef-seurantavastaanotolla |  | 100% | name | 182 | 100 |  |  |  |  | Expiratory peak flow [Volume/time] in Exhaled gas |
| 2449 | perusterveyspakettialat | u/l | 100% | name+unit+values | 259 | 0 | [16.28, 19.92, 22.99, 26.3, 30.01, 33.76, 39.55, 46.02, 53.72] |  |  |  | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| 2450 | perusterveyspakettigluk | mmol/l | 100% | name+unit+values | 258 | 0 | [5.02, 5.2, 5.39, 5.54, 5.69, 5.89, 6.18, 6.43, 6.82] |  |  |  | Glucose [Moles/volume] in Serum or Plasma |
| 2451 | perusterveyspakettigt | u/l | 100% | name+unit+values | 258 | 0 | [14.26, 16.76, 18.89, 21.68, 25.38, 28.56, 34.56, 41.52, 62.84] |  |  |  | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma |
| 2452 | perusterveyspakettihdl-kol | mmol/l | 100% | name+unit+values | 259 | 0 | [1.06, 1.23, 1.38, 1.53, 1.65, 1.73, 1.88, 2.01, 2.28] |  |  |  | Cholesterol in HDL [Moles/volume] in Serum or Plasma |
| 2453 | perusterveyspakettikol | mmol/l | 100% | name+unit+values | 259 | 0 | [4.42, 4.8, 5.09, 5.31, 5.62, 5.83, 6.17, 6.58, 7.19] |  |  |  | Cholesterol.total [Moles/volume] in Serum or Plasma |
| 2454 | perusterveyspakettikrea | umol/l | 100% | name+unit+values | 258 | 0 | [65.81, 72.28, 75.59, 78.42, 82.06, 85.51, 87.86, 92.35, 99.45] |  |  |  | Creatinine [Moles/volume] in Serum or Plasma |
| 2455 | perusterveyspakettilowdensitylipoprot | mmol/l | 100% | name+unit+values | 256 | 0 | [2.2, 2.62, 2.89, 3.09, 3.39, 3.69, 3.91, 4.3, 4.82] |  |  |  | Cholesterol in LDL [Moles/volume] in Serum or Plasma by calculation |
| 2456 | perusterveyspakettitrigly | mmol/l | 100% | name+unit+values | 260 | 0 | [0.58, 0.71, 0.84, 0.97, 1.07, 1.23, 1.45, 1.79, 2.43] |  |  |  | Triglyceride [Moles/volume] in Serum or Plasma |
| 2457 | pika-crptyöterveysasemalla |  | 100% | name+values | 251 | 100 | [8, 8, 8.18, 10.8, 15, 18.9, 24.17, 33.72, 56.7] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 2458 | pt-ekg,tavallinen12kytkentää |  | 100% | name | 1482 | 100 |  |  | Patient |  | 12 lead EKG panel |
| 2459 | pt-näytteenotto,normaali |  | 100% | name | 4946 | 100 |  |  | Patient |  |  |
| 2460 | pt-näytteenotto,päivystys |  | 100% | name | 302 | 100 |  |  | Patient |  |  |
| 2461 | pt-näytteenottomaksu(oletus) |  | 100% | name | 37757 | 100 |  |  | Patient |  |  |
| 2462 | pt-näytteensaapuminenjakäsittely |  | 100% | name | 1323 | 100 |  |  | Patient |  |  |
| 2463 | punasolojenkokojakauma | % | 99% | name+unit+values | 1068 | 0 | [12, 12.09, 13, 13, 13, 13, 13.95, 14, 14.52] |  |  |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2464 | punasolojenkokojakauma |  | 1% | name | 7 | 100 |  |  |  |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2465 | punasolujenerittelylaskenta | % | 9% | name+unit | 41 | 0 |  |  |  |  | Erythrocyte morphology panel - Blood |
| 2466 | punasolujenerittelylaskenta |  | 91% | name+values | 433 | 100 | [12, 12, 12.16, 13, 13, 13, 13, 13.93, 14] |  |  |  | Erythrocyte morphology panel - Blood |
| 2467 | punasolujenesiasteet(erytroblastit) | e9/l | 98% | name+unit+values | 1040 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  | Erythroblasts [#/volume] in Blood by Automated count |
| 2468 | punasolujenesiasteet(erytroblastit) |  | 2% | name | 24 | 100 |  |  |  |  | Erythroblasts [#/volume] in Blood by Automated count |
| 2469 | punasolujenkokojakauma | % | 98% | name+unit+values | 155883 | 0 | [12.35, 13, 13, 13.02, 14, 14, 15, 15.82, 17] |  |  |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2470 | punasolujenkokojakauma |  | 2% | name | 2478 | 100 |  |  |  |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2471 | punasolujenkokojakautuma | % | 100% | name+unit+values | 683 | 0 | [13, 13, 13, 13, 13, 14, 14, 14, 14.94] |  |  |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2472 | punasolujenkoonvaihtelu | % | 100% | name+unit+values | 2031 | 0 | [12.51, 12.91, 13.17, 13.34, 13.62, 13.91, 14.31, 14.86, 15.92] |  |  |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2473 | punasolut,kokojakauma | % | 100% | name+unit+values | 121 | 0 | [13, 13, 13, 13, 14, 14, 14, 14, 15] |  |  |  | Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count |
| 2474 | rasvapaketti(6027fp-lipidit) |  | 100% | name | 1232 | 100 |  |  |  |  | Lipid panel - Serum or Plasma |
| 2475 | rasvapaketti(fp-lipidit) |  | 100% | name | 1715 | 100 |  |  |  |  | Lipid panel - Serum or Plasma |
| 2476 | rasvapaketti(lipidit) | paketti | 1% | name+unit | 9 | 0 |  |  |  |  | Lipid panel - Serum or Plasma |
| 2477 | rasvapaketti(lipidit) |  | 99% | name | 1205 | 100 |  |  |  |  | Lipid panel - Serum or Plasma |
| 2478 | respiratorisetbakteerit,nukl |  | 100% | name | 453 | 100 |  |  |  |  | Respiratory bacteria DNA panel - Respiratory specimen by NAA |
| 2479 | respiratorisetmikrobit,nukle |  | 100% | name | 108 | 100 |  |  |  |  | Respiratory pathogens NAA panel - Respiratory specimen |
| 2480 | respiratorisetvirukset,nukle |  | 100% | name | 431 | 100 |  |  |  |  | Respiratory viruses NAA panel - Respiratory specimen |
| 2481 | s-näytteenotto,veriviljely |  | 100% | name | 863 | 100 |  |  | Serum |  |  |
| 2482 | s-talteen.kttutkimusnäytteille |  | 100% | name | 222 | 100 |  |  | Serum |  |  |
| 2483 | seerumisilmätippojennäytteenottoja-käsittely |  | 100% | name | 205 | 100 |  |  |  |  |  |
| 2484 | suhteellinentiheys | ratio | 8% | name+unit | 17 | 0 |  |  |  |  | Specific gravity of Urine [Specific gravity] in Urine |
| 2485 | suhteellinentiheys |  | 92% | name+values | 184 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02] |  |  |  | Specific gravity of Urine [Specific gravity] in Urine |
| 2486 | suhteellinentiheys(kval) |  | 100% | name+values | 306 | 100 | [1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02, 1.03, 1.03] |  |  |  | Specific gravity of Urine [Specific gravity] in Urine by Test strip |
| 2487 | suhteellinentiheys,virtsasta |  | 100% | name+values | 1901 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02] |  |  |  | Specific gravity of Urine [Specific gravity] in Urine |
| 2488 | suhteellinentiheys,virtsasta,osatutk. |  | 100% | name+values | 587 | 100 | [1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.03] |  |  |  | Specific gravity of Urine [Specific gravity] in Urine |
| 2489 | suhteellinentiheys,virtsasta,vieritesti |  | 100% | name+values | 448 | 100 | [1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02] |  |  |  | Specific gravity of Urine [Specific gravity] in Urine by Test strip |
| 2490 | talteen(plasma,kts.näytteenotto-ohje) |  | 100% | name | 117 | 100 |  |  |  |  |  |
| 2491 | talteen(seerumi,kts.näytteenotto-ohje) |  | 100% | name | 108 | 100 |  |  |  |  |  |
| 2492 | timeintherapeuticrange(sis.inr:n) | % | 73% | name+unit+values | 1521 | 0 | [46.66, 56.63, 65.49, 71.45, 75.46, 80.93, 84.62, 88.53, 95.43] |  |  |  | Time in therapeutic range [Ratio] in Patient by calculation |
| 2493 | timeintherapeuticrange(sis.inr:n) |  | 27% | name | 554 | 100 |  |  |  |  | Time in therapeutic range [Ratio] in Patient by calculation |
| 2494 | tntvieritesti,terveyskeskuksille | ug/l | 14% | name+unit | 16 | 0 |  |  |  |  | Troponin T [Mass/volume] in Serum or Plasma by Point-of-care test |
| 2495 | tntvieritesti,terveyskeskuksille |  | 86% | name | 98 | 100 |  |  |  |  | Troponin T [Mass/volume] in Serum or Plasma by Point-of-care test |
| 2496 | täydellinenverenkuva |  | 100% | name | 17721 | 100 |  |  |  |  | CBC with differential panel - Blood |
| 2497 | u-kemiallinenseulonta |  | 100% | name | 34309 | 100 |  |  | Urine |  | Urinalysis chemical screen panel - Urine |
| 2498 | u-kemiallinenseulonta,otsikko,osatutk |  | 100% | name | 149 | 100 |  |  | Urine |  | Urinalysis chemical screen panel - Urine |
| 2499 | u-kemiallinenseulontatykslab |  | 100% | name | 151 | 100 |  |  | Urine |  | Urinalysis chemical screen panel - Urine |
| 2500 | u-kemseul,kemiallisetosoituskokeet |  | 100% | name | 418 | 100 |  |  | Urine |  | Urinalysis chemical screen panel - Urine |
| 2501 | u-osmolaliteetti,estimoitu | mosm/kgh2o | 90% | name+unit+values | 217 | 0 | [388.07, 452.89, 497.57, 542.8, 595.77, 640.56, 706.28, 793.37, 912.77] |  | Urine |  | Osmolality.calculated [Moles/mass] in Urine by calculation |
| 2502 | u-osmolaliteetti,estimoitu |  | 10% | name | 23 | 100 |  |  | Urine |  | Osmolality.calculated [Moles/mass] in Urine by calculation |
| 2503 | u-osmolaliteettilaskennallinenosatutkuf1000 | mosm/kgh2o | 100% | name+unit+values | 110 | 0 | [320.5, 356, 418.5, 456.77, 490.5, 543.17, 613.5, 662, 733] |  | Urine |  | Osmolality.calculated [Moles/mass] in Urine by calculation |
| 2504 | u-solut,peruslaskenta |  | 100% | name | 1772 | 100 |  |  | Urine |  | Urinalysis sediment microscopy panel - Urine |
| 2505 | u-suhteellinentiheys | 1 | 94% | name+unit+values | 17812 | 0 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.03] |  | Urine |  | Specific gravity of Urine [Specific gravity] in Urine |
| 2506 | u-suhteellinentiheys | kg/l | 0% | name+unit | 72 | 5.56 |  |  | Urine |  | Specific gravity of Urine [Specific gravity] in Urine |
| 2507 | u-suhteellinentiheys |  | 5% | name | 1020 | 100 |  |  | Urine |  | Specific gravity of Urine [Specific gravity] in Urine |
| 2508 | u-suhteellinentiheys,kval |  | 100% | name+values | 2800 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity of Urine [Specific gravity] in Urine by Test strip |
| 2509 | u-suhteellinentiheys,kval,vierit.hoitoyksikös |  | 100% | name+values | 389 | 100 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity of Urine [Specific gravity] in Urine by Test strip |
| 2510 | u-suhteellinentiheyskg/l |  | 100% | name+values | 1472 | 100 | [1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02, 1.03] |  | Urine |  | Specific gravity of Urine [Specific gravity] in Urine |
| 2511 | u-suhteellinentiheysstix |  | 100% | name+values | 1515 | 100 | [1, 1.01, 1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02] |  | Urine |  | Specific gravity of Urine [Specific gravity] in Urine by Test strip |
| 2512 | ultramaxtutkimusvastaanotolla |  | 100% | name | 1028 | 100 |  |  |  |  |  |
| 2513 | verenpainetauti,erotusdiagnostiikka |  | 100% | name | 106 | 100 |  |  |  |  | Hypertension panel |
| 2514 | verenpainetauti,laajakontrolli |  | 100% | name | 178 | 100 |  |  |  |  | Hypertension follow-up panel |
| 2515 | verikaasut,elektrolyytitym., |  | 100% | name | 377 | 100 |  |  |  |  | Blood gas and Electrolyte panel - Blood |
| 2516 | verikaasut,metaboliititym., |  | 100% | name | 756 | 100 |  |  |  |  | Blood gas and Metabolite panel - Blood |
| 2517 | virtsankemiallinenseulonta |  | 100% | name | 12406 | 100 |  |  |  |  | Urinalysis chemical screen panel - Urine |
| 2518 | virtsansolujenhl7-siirtoon | e6/l | 94% | name+unit+values | 5551 | 0 | [0.1, 0.31, 0.54, 0.84, 1.34, 2.1, 3.37, 5.95, 12.57] |  |  |  | Cells [#/volume] in Urine |
| 2519 | virtsansolujenhl7-siirtoon |  | 6% | name+values | 353 | 100 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  |  |  | Cells [#/volume] in Urine |
| 2520 | virtsansuhteellinentiheys | kg/l | 49% | name+unit+values | 90 | 0 | [1.01, 1.01, 1.01, 1.01, 1.02, 1.02, 1.02, 1.02, 1.03] |  |  |  | Specific gravity of Urine [Specific gravity] in Urine |
| 2521 | virtsansuhteellinentiheys |  | 51% | name | 95 | 100 |  |  |  |  | Specific gravity of Urine [Specific gravity] in Urine |

