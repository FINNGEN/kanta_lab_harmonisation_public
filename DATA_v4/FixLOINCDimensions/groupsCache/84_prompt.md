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
Here is group 84.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3025037 | Bacteria identified in Peritoneal fluid by Culture | 1.000 |  |
| 3048821 | Cortisol [Moles/volume] in Serum or Plasma --post 1 mg dexamethasone PO overnight | 0.970 |  |
| 3042973 | Cortisol [Moles/volume] in Serum or Plasma --post dose dexamethasone | 0.953 |  |
| 40771922 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood | 0.951 |  |
| 3007195 | Cortisol [Moles/volume] in Serum or Plasma --pre 1 mg dexamethasone PO overnight | 0.945 |  |
| 3027865 | Cortisol [Moles/volume] in Serum or Plasma --24 hours post 1 mg dexamethasone PO overnight | 0.936 |  |
| 3043338 | Cortisol [Moles/volume] in Serum or Plasma --pre dose dexamethasone | 0.936 |  |
| 3051408 | Cortisol [Mass/volume] in Serum or Plasma --post 1 mg dexamethasone PO overnight | 0.934 |  |
| 3006092 | Cortisol [Moles/volume] in Serum or Plasma --10 hours post 1 mg dexamethasone PO overnight | 0.931 |  |
| 40757342 | Cortisol [Moles/volume] in Serum or Plasma --24 hours post dose dexamethasone | 0.930 |  |
| 1175816 | Bacteria identified in Peritoneal fluid by Aerobe culture | 0.923 |  |
| 40763091 | Bacteria identified in Peritoneal dialysis fluid by Culture | 0.923 |  |
| 46236952 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (MDRD) | 0.921 |  |
| 40764999 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (CKD-EPI) | 0.921 |  |
| 36305372 | Bacteria identified in Peritoneal fluid by Anaerobe culture | 0.921 |  |
| 1617625 | Cortisol [Moles/volume] in Serum or Plasma --post dose dexamethasone PO overnight | 0.920 |  |
| 3000943 | Bacteria # 2 identified in Peritoneal fluid by Culture | 0.918 |  |
| 3026486 | Cortisol [Moles/volume] in Serum or Plasma --17 hours post 1 mg dexamethasone PO overnight | 0.917 |  |
| 36660257 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine and Cystatin C-based formula (CKD-EPI) | 0.913 |  |
| 3030104 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (Schwartz) | 0.912 |  |
| 3016528 | Bacteria # 4 identified in Peritoneal fluid by Culture | 0.912 |  |
| 3011761 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 50 g lactose PO | 0.911 |  |
| 3016160 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 50 g lactose PO | 0.911 |  |
| 3021618 | Bacteria # 5 identified in Peritoneal fluid by Culture | 0.909 |  |
| 3010799 | Bacteria # 3 identified in Peritoneal fluid by Culture | 0.908 |  |
| 3015980 | Glucose [Moles/volume] in Serum or Plasma --30 minutes post 50 g lactose PO | 0.906 |  |
| 3029859 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Cystatin C-based formula | 0.906 |  |
| 3036375 | Glucose [Moles/volume] in Serum or Plasma --1.5 hours post 50 g lactose PO | 0.905 |  |
| 3022889 | Bacteria # 6 identified in Peritoneal fluid by Culture | 0.903 |  |
| 3040655 | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose lactose PO | 0.903 |  |
| 42868432 | Glucose [Moles/volume] in Serum or Plasma --20 minutes post 50 g lactose PO | 0.900 |  |
| 3040908 | Glucose [Moles/volume] in Serum or Plasma --30 minutes post dose lactose PO | 0.898 |  |
| 3043514 | Glucose [Moles/volume] in Serum or Plasma --2.5 hours post 50 g lactose PO | 0.896 |  |
| 3041638 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose lactose PO | 0.895 |  |
| 44786741 | Glucose [Moles/volume] in Serum or Plasma --15 minutes post 50 g lactose PO | 0.894 |  |
| 3965919 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine, Cystatin C and Urea-based formula (CKiD) | 0.893 |  |
| 42869913 | Glomerular filtration rate/1.73 sq M.predicted among males [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (MDRD) | 0.892 |  |
| 1619025 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (CKD-EPI 2021) | 0.889 |  |
| 3029829 | Glomerular filtration rate/1.73 sq M.predicted among females [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (MDRD) | 0.886 |  |
| 1175346 | Bacteria identified in Peritoneal dialysis fluid by Anaerobe culture | 0.880 |  |
| 3005353 | Prothrombin activity actual/normal in Platelet poor plasma by Coagulation assay | 0.872 |  |
| 3005080 | Thrombin time in Platelet poor plasma from Control by Coagulation assay | 0.864 |  |
| 46237003 | Prothrombin activity [Units/volume] in Platelet poor plasma by Coagulation assay --immediately after addition of factor II depleted plasma | 0.859 |  |
| 3032080 | INR in Blood by Coagulation assay | 0.842 | 206 |
| 3025315 | Body weight | 0.835 | 593 |
| 1616554 | Liver fibrosis score in Serum Calculated by FIB4 | 0.824 |  |
| 3036428 | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid | 0.823 |  |
| 42868409 | Thrombin time.high dose in Platelet poor plasma by Coagulation assay | 0.822 |  |
| 40758528 | Diabetes tracking panel | 0.818 |  |
| 46235718 | Delta aPTT [Time] in Platelet poor plasma by Coagulation assay | 0.815 |  |
| 1616617 | Liver fibrosis score panel by Calculated by FIB4 | 0.814 |  |
| 3021977 | Prothrombin Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.812 |  |
| 42870554 | Lactose tolerance panel [Mass/volume] in Serum or Plasma | 0.809 |  |
| 3002681 | Prothrombin Ag actual/normal in Platelet poor plasma by Immunoassay | 0.806 |  |
| 40768546 | Cardiovascular disease 10Y risk [#] SCORE.PC.Conroy 2003 | 0.802 |  |
| 40768547 | Cardiovascular disease 10Y risk [#] SCORE.Quick.Conroy 2003 | 0.801 |  |
| 3036489 | Thrombin time | 0.801 | 705 |
| 3048415 | Thrombin time after addition of heparinase in Platelet poor plasma by Coagulation assay | 0.795 |  |
| 21494738 | Vitamin intake panel | 0.794 |  |
| 3037666 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay | 0.788 |  |
| 646647 | Antithrombin Ag [Measurement] in Platelet poor plasma | 0.786 |  |
| 3034238 | Transferrin.carbohydrate deficient.disialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.784 |  |
| 1175635 | Transferrin.carbohydrate deficient.trisialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.784 |  |
| 42870553 | Lactose tolerance panel [Moles/volume] in Serum or Plasma | 0.784 |  |
| 3033891 | Prothrombin time (PT) in Platelet poor plasma from Control by Coagulation assay | 0.783 |  |
| 37019871 | Corticotropin post CRH stimulation panel - Plasma | 0.783 |  |
| 3004409 | Coagulation factor X activity actual/normal in Platelet poor plasma by Coagulation assay | 0.782 | 1896 |
| 3005757 | Coagulation factor V activity actual/normal in Platelet poor plasma by Coagulation assay | 0.780 | 1703 |
| 3040175 | Thrombin time.factor substitution immediately after addition of XXX in Platelet poor plasma by Coagulation assay | 0.775 |  |
| 3043266 | Transferrin.carbohydrate deficient.asialo/Transferrin.carbohydrate deficient.disialo [Mass Ratio] in Serum or Plasma | 0.772 |  |
| 3025317 | Coagulation factor VII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.771 |  |
| 3041250 | Core respiratory allergens panel - Serum | 0.771 |  |
| 3016005 | Antithrombin Ag [Mass/volume] in Platelet poor plasma by Immunoassay | 0.771 |  |
| 3002348 | Coagulation factor XII activity actual/normal in Platelet poor plasma by Coagulation assay | 0.770 |  |
| 3018676 | Antithrombin [Units/volume] in Platelet poor plasma by Chromogenic method | 0.770 | 1235 |
| 3050153 | Food allergen panel - Serum | 0.770 |  |
| 3049710 | Thrombin time.factor substitution immediately after addition of bovine thrombin in Platelet poor plasma by Coagulation assay | 0.769 |  |
| 3036413 | Transferrin.carbohydrate deficient.asialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.769 |  |
| 3022519 | Antithrombin [Interpretation] in Platelet poor plasma | 0.769 | 1117 |
| 3013762 | Body weight Measured | 0.769 | 1170 |
| 3008009 | Antithrombin Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.768 | 1553 |
| 3051593 | INR in Capillary blood by Coagulation assay | 0.766 |  |
| 3046399 | Transferrin.carbohydrate deficient.monosialo/Transferrin.carbohydrate deficient.disialo [Mass Ratio] in Serum or Plasma | 0.766 |  |
| 1617311 | Time to thrombin peak in Platelet poor plasma by Chromogenic method | 0.765 |  |
| 3014914 | Antithrombin [Moles/volume] in Platelet poor plasma by Chromogenic method | 0.760 |  |
| 40766216 | Nut allergen panel - Serum | 0.759 |  |
| 36031523 | Indoor respiratory allergen IgE panel - Serum | 0.758 |  |
| 3015449 | Antithrombin Ag [Moles/volume] in Platelet poor plasma by Immunoassay | 0.755 |  |
| 3046082 | Antithrombin Ag [Presence] in Platelet poor plasma by Immunoassay | 0.753 |  |
| 3010307 | Gamma glutamyl transferase/Aspartate aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.752 |  |
| 3029366 | Lactose challenge (hydrogen breath test) panel - Exhaled gas | 0.749 |  |
| 43055246 | Days in therapeutic INR range/Days INR result determined [Ratio] | 0.744 |  |
| 1091875 | Lactose challenge (methane breath test) panel - Exhaled gas | 0.742 |  |
| 3045515 | ACTH stimulation test using IV corticosteroids in Serum or Plasma | 0.741 |  |
| 3000515 | Antithrombin actual/normal in Platelet poor plasma by Chromogenic method | 0.740 | 760 |
| 3005268 | Transferrin.carbohydrate deficient [Units/volume] in Serum or Plasma | 0.739 |  |
| 3029213 | Adenosine deaminase [Enzymatic activity/volume] in Pericardial fluid | 0.738 |  |
| 3052708 | Transferrin.carbohydrate deficient/Transferrin.total in Serum or Plasma | 0.738 |  |
| 36659625 | Delayed hypersensitivity anergy intradermal panel | 0.737 |  |
| 3023166 | Body weight Stated | 0.737 |  |
| 36659912 | Diabetes risk [Score] Calculated | 0.736 |  |
| 3006336 | Allergens tested for in Serum | 0.735 |  |
| 1988260 | Cardiovascular disease 10Y risk [Likelihood] | 0.734 |  |
| 3050426 | Respiratory allergen panel, US - Southern Florida - Serum | 0.732 |  |
| 37020917 | Transferrin.carbohydrate deficient.disialo/Transferrin.total standardized per IFCC-RMP for CDT in Serum or Plasma | 0.731 |  |
| 3003771 | Antithrombin Ag actual/normal in Platelet poor plasma by Immunoassay | 0.731 |  |
| 1002224 | Polysomnography panel | 0.730 |  |
| 3049219 | Respiratory allergen panel, US - Central Florida - Serum | 0.730 |  |
| 3033252 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal fluid | 0.729 |  |
| 3025059 | Transferrin.carbohydrate deficient [Mass/volume] in Serum or Plasma | 0.728 |  |
| 3048238 | Respiratory allergen panel, US - California central valley - Serum | 0.725 |  |
| 3045503 | ACTH stimulation test using IM corticosteroids in Serum or Plasma | 0.722 |  |
| 3048273 | Respiratory allergen panel, US - Arid southwest - Serum | 0.722 |  |
| 3018502 | Galactose renal clearance in 24 hour Urine and Serum or Plasma | 0.720 |  |
| 3041244 | Adenosine deaminase [Enzymatic activity/volume] in Synovial fluid | 0.715 |  |
| 21492787 | Cardiovascular disease 10Y risk [Likelihood] ACC-AHA Pooled Cohort by Goff 2013 | 0.714 |  |
| 3037437 | Adenosine deaminase [Enzymatic activity/volume] in Body fluid | 0.714 |  |
| 44816686 | Lactulose challenge (hydrogen breath test) panel - Exhaled gas | 0.713 |  |
| 3042605 | INR in Platelet poor plasma or blood by Coagulation assay | 0.710 |  |
| 42870552 | Lactose tolerance [Interpretation] in Serum or Plasma Narrative | 0.708 |  |
| 3052649 | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma | 0.705 |  |
| 1761797 | Liver fibrosis score in Serum or Plasma by Calculated.Agile4 | 0.702 |  |
| 3038553 | Body mass index (BMI) [Ratio] | 0.701 |  |
| 1988411 | Permanent pacemaker panel | 0.699 |  |
| 3019481 | Coccidioides reaction wheal [Diameter] | 0.699 |  |
| 3032488 | Lactate dehydrogenase in pleural fluid/Lactate dehydrogenase in serum | 0.695 |  |
| 1988318 | Temporary pacemaker panel | 0.695 |  |
| 36660701 | Reaction wheal [Diameter] --1 day post dose control intradermal | 0.695 |  |
| 3022978 | HLA-DR3 [Presence] | 0.695 |  |
| 3009960 | Adenosine deaminase [Enzymatic activity/volume] in Blood | 0.694 |  |
| 3965442 | 17-Hydroxypregnenolone and 17-Hydroxyprogesterone p corticotropin stim panel - Serum or Plasma | 0.694 |  |
| 1091298 | Lactose challenge panel-hydrogen - Exhaled gas | 0.694 |  |
| 36659744 | Cortisol.free post corticotropin stimulation panel - Serum or Plasma | 0.693 |  |
| 40762116 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal dialysis fluid | 0.693 |  |
| 3037839 | Renal function 2000 panel - Serum or Plasma | 0.693 |  |
| 3011732 | Aspartate aminotransferase [Enzymatic activity/volume] in Pleural fluid | 0.692 |  |
| 1989451 | Pacemaker type | 0.691 |  |
| 3966709 | Cortisol and 17-Hydroxyprogesterone post corticotropin stimulation panel - Serum or Plasma | 0.691 |  |
| 3038284 | Candida albicans reaction wheal [Diameter] --1 day post Candida albicans intradermal | 0.690 |  |
| 36660603 | Reaction wheal [Diameter] --2 day post dose control intradermal | 0.690 |  |
| 1616470 | Cortisol, glucose, and somatotropin post arginine stimulation panel - Serum or Plasma | 0.689 |  |
| 43533987 | Body muscle mass/Body weight Measured | 0.689 |  |
| 3020623 | Galactose [Mass/time] in 5 hour Urine --post 40 g dose PO | 0.687 |  |
| 3012831 | HLA-DR2 [Presence] | 0.686 |  |
| 3006687 | Galactose [Mass/volume] in Serum or Plasma | 0.685 |  |
| 46236279 | Liver fibrosis score in Serum or Plasma Calculated by FibroMeter | 0.685 |  |
| 1761552 | Liver fibrosis score in Serum or Plasma by Calculated.Agile3+ | 0.684 |  |
| 1989465 | Continuous renal replacement therapy panel | 0.683 |  |
| 3011054 | Body weight Measured --without clothes | 0.683 |  |
| 3022217 | INR in Platelet poor plasma by Coagulation assay | 0.682 | 53 |
| 3020650 | Glucose [Presence] in Urine | 0.682 | 116 |
| 46234683 | Body weight - Reported --usual | 0.680 |  |
| 3026560 | Insulin Ab [Presence] in Serum | 0.680 |  |
| 43533733 | Body fat [Mass] Calculated | 0.679 |  |
| 3000219 | Insulin receptor Ab [Presence] in Serum | 0.678 |  |
| 3044031 | Creatinine 24H renal clearance panel | 0.678 |  |
| 3039510 | HLA-DQ8 [Presence] | 0.677 |  |
| 3043630 | Candida albicans reaction wheal [Diameter] --2 days post Candida albicans intradermal | 0.676 |  |
| 3022227 | Pathologist review of Blood tests | 0.676 | 1595 |
| 3965705 | ACTH heterophile Ab interference panel - Plasma | 0.675 |  |
| 3010220 | Body weight Measured --with clothes | 0.674 |  |
| 36305723 | Liver fibrosis score in Serum by Calculated by ELF | 0.673 |  |
| 21491255 | Liver fibrosis score panel - Serum or Plasma Calculated by FibroMeter | 0.673 |  |
| 3024770 | Candida albicans reaction wheal [Diameter] --1 day post 50 ug Candida albicans intradermal | 0.672 |  |
| 3026600 | Body weight Estimated | 0.672 |  |
| 1617534 | Cardiovascular [Score] SOFA | 0.672 |  |
| 36031274 | Cardiovascular disease 10Y risk goal based on ACC-AHA Pooled Cohort by Goff 2013 | 0.671 |  |
| 21491594 | Liver fibrosis score in Serum or Plasma Calculated by HepaScore | 0.669 |  |
| 3028693 | Candida albicans reaction wheal [Diameter] --3 days post 50 ug Candida albicans intradermal | 0.668 |  |
| 3024513 | Pacing interval Pacemaker | 0.668 |  |
| 3000826 | HLA-DQ1 [Presence] | 0.668 |  |
| 3013543 | Candida albicans reaction wheal [Diameter] --2 days post 50 ug Candida albicans intradermal | 0.667 |  |
| 3031203 | Blood pressure panel | 0.666 |  |
| 1617190 | Total risk score FINDRISC | 0.664 |  |
| 21491254 | Liver fibrosis score panel - Serum or Plasma Calculated by HepaScore | 0.664 |  |
| 3042240 | HLA-DQB1*2 [Presence] | 0.664 |  |
| 3024868 | Candida albicans reaction wheal [Diameter] --2 days post 0.1 mL Candida albicans intradermal | 0.664 |  |
| 1989527 | Pacemaker rate | 0.663 |  |
| 646017 | Liver fibrosis progression [Interpretation] in Serum or Blood by Calculated by FIB4 Narrative | 0.662 |  |
| 3010316 | Galactose [Moles/volume] in Serum or Plasma | 0.662 |  |
| 3965511 | Cortisol post arginine stimulation panel - Serum or Plasma | 0.661 |  |
| 3966140 | 17-Hydroxyprogesterone post corticotropin stimulation panel - Serum or Plasma | 0.660 |  |
| 3012946 | Galactose [Moles/time] in 24 hour Urine | 0.659 |  |
| 3042187 | Mumps reaction wheal [Diameter] --1 day post dose mumps intradermal | 0.658 |  |
| 40762528 | Pathologist review of results | 0.657 |  |
| 1259993 | Gas and Lactate panel - Venous blood | 0.657 |  |
| 3026058 | HLA-DR4 [Presence] | 0.656 |  |
| 3025791 | Fasting glucose [Presence] in Urine | 0.656 |  |
| 3038185 | Pathologist review of serum or plasma results | 0.655 |  |
| 21494398 | Lactose intake 24 hour Measured | 0.653 |  |
| 3023638 | Glucose [Presence] in Urine by Test strip --30 minutes post 50 g lactose PO | 0.652 |  |
| 36032156 | Cardiovascular disease lifetime risk [Likelihood] ACC-AHA Pooled Cohort by Goff 2013 | 0.652 |  |
| 36032050 | Renal clearance and Renal plasma flow panel - Urine and Serum or Plasma | 0.651 |  |
| 3964942 | Vitamin B3 and metabolites panel - Serum or Plasma by LC/MS/MS | 0.651 |  |
| 3037627 | Pedometer device panel | 0.650 |  |
| 3965146 | Synthetic glucocorticoid panel - Serum or Plasma | 0.650 |  |
| 1989388 | Pacemaker mode | 0.649 |  |
| 3029645 | Glucose screen gestational panel - Urine and Serum or Plasma | 0.649 |  |
| 3004468 | Somatostatin [Presence] in Plasma | 0.648 |  |
| 21493650 | Physical activity panel | 0.647 |  |
| 1617208 | Cobalamin (Vitamin B12) and folate panel - Serum | 0.647 |  |
| 1002267 | Genetic risk score for coronary heart disease | 0.647 |  |
| 40758546 | Short blood pressure panel | 0.645 |  |
| 1988463 | Pacemaker Atrial electrical activity captured | 0.642 |  |
| 3014305 | Glucose [Presence] in Blood by Test strip | 0.642 |  |
| 1091078 | Diabetes mellitus type 1 autoimmune panel - Serum or Plasma | 0.640 |  |
| 36303616 | 1,25-Dihydroxyvitamin D and 1,25-Dihydroxyvitamin D2 and 1,25-Dihydroxyvitamin D3 panel - Serum or Plasma | 0.639 |  |
| 3035644 | Style Pacemaker lead by EKG | 0.639 |  |
| 647808 | Glycolate [Measurement] in Serum or Plasma | 0.638 |  |
| 3965042 | Cortisol and Cortisone panel - 24 hour Urine | 0.637 |  |
| 3966492 | External Steroid panel Serum or Plasma | 0.637 |  |
| 3017530 | Somatostatin Ag [Presence] in Tissue by Immune stain | 0.637 |  |
| 40761192 | Glucose-6-Phosphate dehydrogenase newborn screen panel | 0.637 |  |
| 36660493 | Keratometry panel | 0.636 |  |
| 3036520 | Type of Pacemaker by EKG | 0.636 |  |
| 3029340 | Insulin XXX challenge panel - Serum | 0.636 |  |
| 3004684 | Galactose [Presence] in Blood | 0.635 |  |
| 1989390 | Right cornea Type of Analysis method by Specular microscopy | 0.635 |  |
| 1988306 | Pacemaker Atrial electrical activity sensed | 0.634 |  |
| 1259667 | Ethyl glucuronide [Presence] in Serum or Plasma | 0.633 |  |
| 647340 | Galactose [Measurement] in Urine | 0.629 |  |
| 3010023 | Pathologist interpretation of Blood tests | 0.629 | 631 |
| 3033145 | Hemoglobin A1c measurement device panel | 0.628 |  |
| 3029132 | Heart rate device panel | 0.627 |  |
| 36032166 | Retinol and Alpha tocopherol panel - Serum or Plasma | 0.626 |  |
| 3051560 | Endocrine newborn screening panel | 0.626 |  |
| 36660707 | Vitamin B6 and metabolites panel - Serum or Plasma | 0.626 |  |
| 3036259 | Galactose [Mass/volume] in Blood --1.5 hours post 40 g galactose PO | 0.625 |  |
| 1761394 | Routine prenatal assessment panel | 0.624 |  |
| 3964712 | Hypoglycemia evaluation panel - Serum or Plasma | 0.624 |  |
| 3027074 | Cholesterol [Presence] in Blood by Test strip | 0.623 |  |
| 3965142 | Cortisol and Cortisone panel - Urine | 0.622 |  |
| 3013466 | aPTT in Blood by Coagulation assay | 0.620 | 77 |
| 3041989 | Carnitine newborn screen panel | 0.620 |  |
| 21491197 | Riboflavin and flavin mononucleotide and flavin adenine dinucleotide panel - Serum or Plasma | 0.620 |  |
| 21494629 | Micronutrient intake panel | 0.619 |  |
| 40763950 | INR in Platelet poor plasma from Fetus by Coagulation assay | 0.619 |  |
| 21490962 | Left cornea Corneal curvature by Keratometry | 0.619 |  |
| 40758542 | Pedometer tracking panel | 0.619 |  |
| 40757366 | Cortisol challenge panel - Saliva (oral fluid) | 0.618 |  |
| 1989195 | Left cornea Type of Analysis method by Specular microscopy | 0.618 |  |
| 40760610 | 11-Deoxycortisol [Moles/volume] in Serum or Plasma --2 days post dose dexamethasone | 0.618 |  |
| 3053181 | Prothrombin time (PT) in Capillary blood by Coagulation assay | 0.616 |  |
| 21490961 | Right cornea Corneal curvature by Keratometry | 0.615 |  |
| 40763621 | Comprehensive pathology report panel | 0.614 |  |
| 3002417 | Prothrombin time (PT) in Blood by Coagulation assay | 0.614 |  |
| 21493450 | Pulmonary function test panel | 0.613 |  |
| 42528781 | Wearable device external physiologic monitoring panel | 0.613 |  |
| 40758281 | Aldosterone and renin activity panel - Plasma | 0.613 |  |
| 21491758 | Electroretinography (ERG) panel | 0.612 |  |
| 21494068 | Projected heparin concentration to reach target ACT [Units/volume] in Blood by calculation | 0.609 |  |
| 3030243 | Pathologist interpretation of Specimen tests | 0.603 |  |
| 3052678 | Hematocrit [Volume Fraction] of Dialysis fluid by calculation | 0.600 |  |
| 3032833 | Metabolism measurement device panel | 0.594 |  |
| 40765154 | PhenX - wt loss - gain protocol 021401 | 0.593 |  |
| 21491705 | Aldosterone and renin concentration panel - Plasma | 0.593 |  |
| 40758556 | Seizure disorder tracking panel | 0.592 |  |
| 3010039 | Pathologist interpretation of Body fluid tests | 0.586 |  |
| 3014348 | Right cornea Sagittal radius.temporal by Keratometry | 0.583 |  |
| 645163 | Somatostatin [Measurement] in Plasma | 0.580 |  |
| 3000812 | Left cornea Sagittal radius.temporal by Keratometry | 0.580 |  |
| 36203455 | Kidney failure 2-year and 5-year risk panel by KFRE | 0.578 |  |
| 3022673 | Creatinine [Mass/volume] in Dialysis fluid | 0.578 |  |
| 36304044 | Isotopic Tubular extraction rate/1.73 sq M [Volume Rate/Area] in Serum or Blood | 0.577 |  |
| 3004060 | Somatotropin Ag [Presence] in Tissue by Immune stain | 0.574 |  |
| 43533840 | Percent heparin inhibition [Ratio] in Serum | 0.573 |  |
| 43055529 | Erythrocyte enzyme panel - Red Blood Cells | 0.573 |  |
| 21493274 | Glucose meter to reference method correlation [Ratio] in Serum, Plasma or Blood by calculation | 0.572 |  |
| 3011740 | Phenytoin.total/Phenytoin.free [Mass Ratio] in Serum or Plasma | 0.572 |  |
| 1616355 | Renal [Score] SOFA | 0.572 |  |
| 3033655 | Right cornea Steep refractive power by Keratometry | 0.571 |  |
| 3022777 | Left eye Cylinder Autorefractor.sciascopy | 0.570 |  |
| 36660683 | Cylinder mode by Keratometry | 0.569 |  |
| 42868454 | Clinical cytogeneticist review of results | 0.568 |  |
| 40762529 | Hematologist review of results | 0.568 |  |
| 3017575 | Referral lab test results | 0.567 | 104 |
| 46235808 | Reticulocyte distribution width [Ratio] in Blood by calculation | 0.558 |  |
| 3008561 | Activated protein C resistance [Time Ratio] in Platelet poor plasma by Coagulation assay | 0.555 | 797 |
| 1470024 | Time above range, high in Reporting Period Interstitial fluid by calculation | 0.552 |  |
| 43533394 | Triiodothyronine (T3)/Thyroxine (T4) [Mass Ratio] in Serum or Plasma | 0.547 |  |
| 44816692 | Thyroid hormone binding ratio (THBR) in Serum or Plasma | 0.546 |  |
| 3012154 | Abnormal Prion Protein [Presence] in Brain by Electron microscopy | 0.533 |  |
| 3035182 | Abnormal Prion Protein [Presence] in Brain by Immunoassay | 0.519 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1276 | gt-cdt-ind |  | 100% | name+values | 8671 | 100 | [2.7, 3.02, 3.27, 3.52, 3.77, 4.04, 4.34, 4.72, 5.26] |  |  | Index | Gamma-glutamyltransferase/Carbohydrate deficient transferrin [Ratio] in Serum or Plasma |
| 1277 | p-at3-spr | % | 73% | name+unit+values | 330 | 0 | [86.92, 91.6, 95.11, 97.89, 99.97, 102.97, 106.49, 109.7, 115.54] |  | Plasma |  | Antithrombin III [Activity] in Plasma |
| 1278 | p-at3-spr |  | 27% | name+values | 124 | 100 | [91.42, 95.11, 98.49, 101, 103.88, 105.86, 108, 111.89, 116] |  | Plasma |  | Antithrombin III [Activity] in Plasma |
| 1279 | p-traispr | s | 20% | name+unit | 110 | 0 |  |  | Plasma |  | Thrombin time [Time] in Platelet poor plasma |
| 1280 | p-traispr |  | 80% | name | 448 | 100 |  |  | Plasma |  | Thrombin time [Time] in Platelet poor plasma |
| 1281 | p-tt-spa | % | 79% | name+unit+values | 450 | 0 | [61.6, 74.33, 80.55, 86.92, 91.78, 97.31, 102.37, 109.68, 121.76] |  | Plasma |  | Prothrombin [Activity] in Platelet poor plasma |
| 1282 | p-tt-spa |  | 21% | name+values | 123 | 100 | [76.4, 84, 88.55, 95.06, 100.62, 106.53, 112.4, 120.3, 128.2] |  | Plasma |  | Prothrombin [Activity] in Platelet poor plasma |
| 1283 | p-tt-spr | % | 84% | name+unit+values | 511 | 0 | [71.66, 80.46, 86.05, 90.09, 94.9, 100.49, 106.6, 112.1, 123.79] |  | Plasma |  | Prothrombin [Activity] in Platelet poor plasma |
| 1284 | p-tt-spr |  | 16% | name+values | 99 | 100 | [65, 81.47, 86.4, 93.7, 99, 103.7, 111.13, 117.4, 123] |  | Plasma |  | Prothrombin [Activity] in Platelet poor plasma |
| 1285 | pd-bavikäs |  | 100% | name | 196 | 100 |  |  | Peritoneal dialysis fluid |  | Bacteria identified in Peritoneal fluid by Culture |
| 1286 | pf-ada/s-ada |  | 100% | name+values | 123 | 100 | [0.3, 0.4, 0.5, 0.64, 0.77, 0.81, 1, 1.32, 1.74] |  | Pleural fluid |  | Adenosine deaminase.pleural fluid/Adenosine deaminase.serum [Ratio] |
| 1287 | pt-abiras |  | 100% | name | 244 | 100 |  |  | Patient |  |  |
| 1288 | pt-acth-r1 |  | 100% | name | 726 | 100 |  | Pt-Adrenokortikotropiini-koe, lyhyt | Patient |  | ACTH stimulation test panel |
| 1289 | pt-acth-ro |  | 100% | name | 107 | 100 |  |  | Patient |  | ACTH stimulation test panel |
| 1290 | pt-acthrma |  | 100% | name | 217 | 100 |  |  | Patient |  | ACTH stimulation test panel |
| 1291 | pt-acthrmk |  | 100% | name | 332 | 100 |  |  | Patient |  | ACTH stimulation test panel |
| 1292 | pt-ada-ind |  | 100% | name+values | 626 | 100 | [0.3, 0.48, 0.6, 0.76, 0.9, 1, 1.2, 1.5, 2.31] |  | Patient | Index | Adenosine deaminase.pleural fluid/Adenosine deaminase.serum [Ratio] |
| 1293 | pt-aiv-pet |  | 100% | name | 106 | 100 |  |  | Patient |  | Brain [Presence] by PET |
| 1294 | pt-aktig |  | 100% | name | 176 | 100 |  | Pt-Liikeativiteettirekisteröinti, aktigrafia | Patient |  | Actigraphy panel |
| 1295 | pt-aktig-2 |  | 100% | name | 154 | 100 |  | Pt-Liikeaktiviteettirekisteröinti, aktigrafia, vaativa | Patient |  | Actigraphy panel |
| 1296 | pt-angirtg |  | 100% | name | 364 | 100 |  |  | Patient |  | Angiography |
| 1297 | pt-cert |  | 100% | name | 315 | 100 |  |  | Patient |  |  |
| 1298 | pt-diabet |  | 100% | name | 135 | 100 |  |  | Patient |  | Diabetes [Presence] |
| 1299 | pt-diascr |  | 100% | name | 527 | 100 |  |  | Patient |  | Diabetes screen panel |
| 1300 | pt-dxm-r1 | nmol/l | 1% | name+unit+values | 76 | 0 | [14, 17, 19, 21.2, 25, 27.2, 32.47, 39, 68] | Pt-Deksametasoni-koe, lyhyt | Patient |  | Cortisol [Moles/volume] in Serum or Plasma --post 1 mg dexamethasone |
| 1301 | pt-dxm-r1 |  | 99% | name | 6248 | 100 |  | Pt-Deksametasoni-koe, lyhyt | Patient |  | Dexamethasone suppression test panel |
| 1302 | pt-erist |  | 100% | name | 848 | 100 |  |  | Patient |  | Patient isolation [Status] |
| 1303 | pt-fdg-pet |  | 100% | name | 2426 | 100 |  |  | Patient |  | Whole body [Presence] by FDG-PET |
| 1304 | pt-fdgvpet |  | 100% | name | 736 | 100 |  |  | Patient |  | Whole body [Presence] by FDG-PET |
| 1305 | pt-fib-4 |  | 100% | name+values | 10764 | 100 | [0.55, 0.74, 0.9, 1.05, 1.2, 1.38, 1.59, 1.9, 2.38] |  | Patient |  | FIB-4 score [Score] by Calculation |
| 1306 | pt-gal-r3 | min | 19% | name+unit | 36 | 0 |  | Pt-Galaktoosi-koe, puoliintumisaika | Patient |  | Galactose elimination capacity [Time] in Serum or Plasma |
| 1307 | pt-gal-r3 |  | 81% | name | 150 | 100 |  | Pt-Galaktoosi-koe, puoliintumisaika | Patient |  | Galactose elimination capacity [Time] in Serum or Plasma |
| 1308 | pt-galt1/2 | min | 100% | name+unit+values | 184 | 0 | [9, 10.34, 11.82, 13, 14.89, 17.65, 23.89, 32.76, 46.25] |  | Patient |  | Galactose elimination capacity [Time] in Serum or Plasma |
| 1309 | pt-glomfr |  | 100% | name | 357 | 100 |  |  | Patient |  | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum or Plasma by calculation |
| 1310 | pt-hertta |  | 100% | name | 152 | 100 |  |  | Patient |  | Cardiovascular disease risk score [Score] |
| 1311 | pt-iho-r1 | mm | 40% | name+unit | 115 | 0 |  | Pt-Ihokoe 1, suppea, 1-5 antigeenia | Patient |  | Allergen wheal [Length] in Skin |
| 1312 | pt-iho-r1 |  | 60% | name | 173 | 100 |  | Pt-Ihokoe 1, suppea, 1-5 antigeenia | Patient |  | Allergy skin test panel |
| 1313 | pt-iho-r3 |  | 100% | name | 1244 | 100 |  | Pt-Ihokoe 3, laaja, 6-20 antigeenia | Patient |  | Allergy skin test panel |
| 1314 | pt-kauvduä |  | 100% | name | 312 | 100 |  |  | Patient |  |  |
| 1315 | pt-kt/v |  | 100% | name+values | 2372 | 100 | [1.18, 1.28, 1.32, 1.36, 1.39, 1.41, 1.45, 1.49, 1.53] |  | Patient |  | Kt/V [Ratio] by calculation |
| 1316 | pt-kt/v1 |  | 100% | name+values | 5747 | 100 | [1.09, 1.27, 1.39, 1.48, 1.56, 1.65, 1.74, 1.85, 2.02] |  | Patient |  | Kt/V [Ratio] by calculation |
| 1317 | pt-laihdu |  | 100% | name | 149 | 100 |  |  | Patient |  | Weight loss [Finding] |
| 1318 | pt-lakt-r1 | mmol/l | 6% | name+unit | 14 | 0 |  | Pt-Laktoosi-koe | Patient |  | Glucose [Moles/volume] in Serum or Plasma --post lactose challenge |
| 1319 | pt-lakt-r1 |  | 94% | name | 214 | 100 |  | Pt-Laktoosi-koe | Patient |  | Lactose tolerance test panel |
| 1320 | pt-meet2 |  | 100% | name | 110 | 100 |  |  | Patient |  | Clinical pathology consultation |
| 1321 | pt-meetin |  | 100% | name | 189 | 100 |  |  | Patient |  | Clinical pathology consultation |
| 1322 | pt-meeting |  | 100% | name | 12544 | 100 |  | Pt-Potilastapauksen kliinispatologinen käsittely | Patient |  | Clinical pathology consultation |
| 1323 | pt-miesl |  | 100% | name | 889 | 100 |  |  | Patient |  |  |
| 1324 | pt-miesp |  | 100% | name | 260 | 100 |  |  | Patient |  |  |
| 1325 | pt-miestp |  | 100% | name | 152 | 100 |  |  | Patient |  |  |
| 1326 | pt-munfung |  | 100% | name | 310 | 100 |  |  | Patient |  | Renal function panel |
| 1327 | pt-nainenl |  | 100% | name | 716 | 100 |  |  | Patient |  |  |
| 1328 | pt-nainenp |  | 100% | name | 310 | 100 |  |  | Patient |  |  |
| 1329 | pt-naistp |  | 100% | name | 117 | 100 |  |  | Patient |  |  |
| 1330 | pt-paino | kg | 95% | name+unit+values | 2695 | 0.15 | [60.61, 67.01, 71.85, 75.49, 79.69, 83.26, 87.24, 92.77, 102.78] |  | Patient |  | Body weight [Mass] |
| 1331 | pt-paino |  | 5% | name+values | 153 | 100 | [59.8, 65.06, 69.62, 73.7, 78, 81.97, 85.17, 91.96, 99.6] |  | Patient |  | Body weight [Mass] |
| 1332 | pt-pentaca |  | 100% | name | 425 | 100 |  |  | Patient |  | Corneal topography by instrument |
| 1333 | pt-psmapet |  | 100% | name | 509 | 100 |  |  | Patient |  | Whole body [Presence] by PSMA-PET |
| 1334 | pt-punktio |  | 100% | name | 213 | 100 |  |  | Patient |  | Puncture procedure |
| 1335 | pt-selvit |  | 100% | name | 506 | 100 |  |  | Patient |  |  |
| 1336 | pt-som-pet |  | 100% | name | 448 | 100 |  |  | Patient |  | Whole body [Presence] by Somatostatin receptor-PET |
| 1337 | pt-spr/thl |  | 100% | name | 164 | 100 |  |  | Patient |  |  |
| 1338 | pt-syd-pet |  | 100% | name | 270 | 100 |  |  | Patient |  | Heart [Presence] by PET |
| 1339 | pt-tahdist |  | 100% | name | 203 | 100 |  |  | Patient |  | Pacemaker evaluation |
| 1340 | pt-taksim1 |  | 100% | name | 255 | 100 |  |  | Patient |  |  |
| 1341 | pt-taksim3 |  | 100% | name | 109 | 100 |  |  | Patient |  |  |
| 1342 | pt-terta |  | 100% | name | 456 | 100 |  |  | Patient |  |  |
| 1343 | pt-tthscr1 |  | 100% | name | 145 | 100 |  |  | Patient |  |  |
| 1344 | pt-ttlaite |  | 100% | name | 526 | 100 |  |  | Patient |  | INR in Blood by Coagulation test strip |
| 1345 | pt-ttr+inr | % | 76% | name+unit+values | 1974 | 0 | [36.34, 51.51, 59.83, 67.58, 73.4, 78.22, 83.44, 90.53, 99.05] |  | Patient |  | Time in therapeutic range [Ratio] by Calculation |
| 1346 | pt-ttr+inr |  | 24% | name | 609 | 100 |  |  | Patient |  | Time in therapeutic range [Ratio] by Calculation |
| 1347 | pt-vai-tk |  | 100% | name | 397 | 100 |  |  | Patient |  |  |
| 1348 | pt-valtim |  | 100% | name | 106 | 100 |  |  | Patient |  |  |
| 1349 | pt-valvot |  | 100% | name | 349 | 100 |  |  | Patient |  |  |
| 1350 | pt-vartig |  | 100% | name | 2815 | 100 |  |  | Patient |  |  |
| 1351 | pt-vartspq |  | 100% | name | 144 | 100 |  |  | Patient |  | Whole body SPECT |
| 1352 | pt-vitascr |  | 100% | name | 521 | 100 |  |  | Patient |  | Vitamin screen panel |
| 1353 | pt-vitrif |  | 100% | name | 276 | 100 |  |  | Patient |  | Vitrification procedure |

