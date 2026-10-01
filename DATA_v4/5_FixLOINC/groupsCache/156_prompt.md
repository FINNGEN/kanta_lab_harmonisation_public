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
Here is group 156.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3001355 | Fungus identified in Sputum by Culture | 1.000 |  |
| 3002951 | Fungus identified in Skin by Culture | 1.000 | 1437 |
| 3005785 | Creatine kinase.MB [Mass/volume] in Serum or Plasma | 1.000 | 111 |
| 3009508 | Creatinine [Moles/volume] in Urine | 1.000 | 161 |
| 3020564 | Creatinine [Moles/volume] in Serum or Plasma | 1.000 | 1 |
| 3035133 | Fungus identified in Wound by Culture | 1.000 |  |
| 3039815 | Urea [Moles/volume] in Serum or Plasma --pre dialysis | 1.000 |  |
| 3042602 | Urea [Moles/volume] in Serum or Plasma --post dialysis | 1.000 |  |
| 3036535 | Thyroglobulin [Mass/volume] in Serum or Plasma | 0.973 | 610 |
| 3013742 | Prealbumin [Mass/volume] in Serum or Plasma | 0.970 | 285 |
| 3030625 | Rheumatoid factor IgG [Units/volume] in Serum | 0.968 |  |
| 3009201 | Thyrotropin [Units/volume] in Serum or Plasma | 0.967 | 105 |
| 46235076 | Creatinine [Moles/volume] in Serum, Plasma or Blood | 0.967 |  |
| 3021614 | Rheumatoid factor [Units/volume] in Serum or Plasma | 0.966 | 251 |
| 3022632 | Rheumatoid factor IgM [Units/volume] in Serum | 0.962 |  |
| 645405 | Fungus identified in Wound deep by Culture | 0.955 |  |
| 3033236 | Creatine kinase.MB [Mass/volume] in Blood | 0.954 |  |
| 3017446 | Testosterone [Moles/volume] in Serum or Plasma | 0.952 | 203 |
| 1469856 | Bacteria identified in Mother's milk by Culture | 0.951 |  |
| 3023399 | Thyrotropin [Units/volume] in Blood | 0.951 |  |
| 42529209 | Creatine kinase.MB [Mass/volume] in Serum or Plasma by Immunoassay | 0.947 |  |
| 648072 | Fungus identified in Wound shallow by Culture | 0.945 |  |
| 3008486 | Thyroxine (T4) free [Moles/volume] in Serum or Plasma | 0.944 | 133 |
| 3029790 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma | 0.942 | 374 |
| 3015688 | Rheumatoid factor [Units/volume] in Serum by Immunoassay | 0.942 |  |
| 649335 | Creatine kinase.MB [Measurement] in Serum or Plasma | 0.940 |  |
| 3015916 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma | 0.936 |  |
| 1091917 | Rheumatoid factor [Units/volume] in Specimen | 0.935 |  |
| 40771922 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood | 0.934 |  |
| 3030930 | Rheumatoid factor IgA [Units/volume] in Serum | 0.933 |  |
| 3026989 | Triiodothyronine (T3) Free [Moles/volume] in Serum or Plasma | 0.932 | 274 |
| 3024763 | Rheumatoid factor [Units/volume] in Serum by Nephelometry | 0.931 | 789 |
| 3003930 | Fungus identified in Sputum tracheal aspirate by Culture | 0.929 |  |
| 3009306 | Alpha-1-Fetoprotein [Mass/volume] in Serum or Plasma | 0.927 | 386 |
| 3043043 | IgM.monoclonal [Presence] in Serum by Immunofixation | 0.925 |  |
| 40762887 | Creatinine [Moles/volume] in Blood | 0.924 | 283 |
| 3003095 | Rheumatoid factor [Units/volume] in Synovial fluid | 0.924 |  |
| 3034104 | Urea nitrogen [Mass/volume] in Serum or Plasma --post dialysis | 0.923 | 921 |
| 3016735 | Thyrotropin Ab [Units/volume] in Serum | 0.922 |  |
| 3022164 | Urea nitrogen [Mass/volume] in Serum or Plasma --pre dialysis | 0.918 | 931 |
| 3046946 | IgG.monoclonal [Presence] in Serum by Immunofixation | 0.918 |  |
| 3014620 | Thyroxine (T4) [Moles/volume] in Serum or Plasma | 0.917 | 145 |
| 36032269 | Testosterone Free [Moles/volume] in Serum or Plasma by calculation | 0.914 |  |
| 3016102 | Rheumatoid factor IgM [Units/volume] in Serum by Immunoassay | 0.912 |  |
| 1761631 | Thyroglobulin [Mass/volume] in Body fluid | 0.912 |  |
| 46236724 | Urea [Molar ratio] in Serum or Plasma --post dialysis/pre dialysis | 0.912 |  |
| 3023800 | Rheumatoid factor [Units/volume] in Body fluid | 0.909 |  |
| 3048150 | Creatine kinase.MB [Presence] in Serum or Plasma | 0.909 |  |
| 3016723 | Creatinine [Mass/volume] in Serum or Plasma | 0.908 |  |
| 3013539 | Creatinine [Moles/volume] in 24 hour Urine | 0.908 | 1978 |
| 1260102 | Creatinine [Moles/volume] in Serum or Plasma by LC/MS/MS | 0.906 |  |
| 3018301 | Testosterone Free [Moles/volume] in Serum or Plasma | 0.905 | 325 |
| 3965683 | Creatine kinase.MB [Moles/volume] in Serum or Plasma by Immunoassay | 0.902 |  |
| 3000081 | cloZAPine [Moles/volume] in Serum or Plasma | 0.901 |  |
| 3007446 | Thyroglobulin [Moles/volume] in Serum or Plasma | 0.900 |  |
| 3024212 | Fungus identified in Bronchial specimen by Culture | 0.899 |  |
| 3027505 | Alpha-1-Fetoprotein [Units/volume] in Amniotic fluid | 0.897 | 1501 |
| 3008304 | Triiodothyronine (T3) [Moles/volume] in Serum or Plasma | 0.897 | 223 |
| 3019439 | Fungus identified in Tissue by Culture | 0.896 |  |
| 3024516 | IgM.monoclonal [Mass/volume] in Serum | 0.896 |  |
| 3008598 | Thyroxine (T4) free [Mass/volume] in Serum or Plasma | 0.895 |  |
| 1176112 | Fungus identified in Lower respiratory specimen by Culture | 0.894 |  |
| 3045958 | Alpha-1-Fetoprotein [Units/volume] in Body fluid | 0.894 |  |
| 3041735 | Creatinine [Moles/volume] in Serum or Plasma --baseline | 0.894 |  |
| 42529189 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma by Immunoassay | 0.894 |  |
| 3020779 | Urea [Moles/volume] in Serum or Plasma | 0.893 |  |
| 3009762 | IgM [Presence] in Serum by Immunofixation | 0.893 |  |
| 40764999 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (CKD-EPI) | 0.893 |  |
| 3016311 | Creatine kinase.MB/Creatine kinase.total in Serum or Plasma | 0.893 | 297 |
| 3026726 | Creatinine [Moles/volume] in Specimen | 0.893 |  |
| 46236952 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (MDRD) | 0.890 |  |
| 40758424 | Protein electrophoresis and Immunoglobulins panel - Serum | 0.890 |  |
| 3964702 | Creatinine [Moles/volume] in Venous blood | 0.888 |  |
| 3044974 | Prealbumin [Mass/volume] in Serum or Plasma by Nephelometry | 0.887 |  |
| 3017925 | Prealbumin [Mass/volume] in Serum or Plasma by Immunoassay | 0.886 |  |
| 36660257 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine and Cystatin C-based formula (CKD-EPI) | 0.886 |  |
| 3040006 | Creatinine [Moles/volume] in 12 hour Urine | 0.885 |  |
| 3034165 | Alpha-1-Fetoprotein [Mass/volume] in Body fluid | 0.885 |  |
| 37021217 | Fungus identified in Upper respiratory specimen by Culture | 0.885 |  |
| 3038911 | Alpha-1-fetoprotein.tumor marker [Units/volume] in Serum or Plasma | 0.885 |  |
| 3037459 | Creatinine [Moles/volume] in Body fluid | 0.885 | 1234 |
| 3017250 | Creatinine [Mass/volume] in Urine | 0.884 |  |
| 3026925 | Triiodothyronine (T3) Free [Mass/volume] in Serum or Plasma | 0.884 |  |
| 3006442 | Creatine [Moles/volume] in Serum or Plasma | 0.884 |  |
| 3044927 | Protein electrophoresis panel - Urine | 0.883 |  |
| 3016070 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.882 |  |
| 3021886 | Globulin [Mass/volume] in Serum | 0.882 | 83 |
| 1469485 | Fungus identified in Pus by Culture | 0.882 |  |
| 3026687 | IgG [Presence] in Serum by Immunofixation | 0.880 |  |
| 3010296 | Alpha-1-Fetoprotein [Mass/volume] in Amniotic fluid | 0.880 |  |
| 42529232 | Thyroxine (T4) free [Moles/volume] in Serum or Plasma by Immunoassay | 0.880 |  |
| 3040510 | Creatinine [Moles/time] in 1 hour Urine | 0.879 |  |
| 46237024 | Prealbumin [Moles/volume] in Serum or Plasma | 0.879 |  |
| 1617524 | Alpha-1-Fetoprotein [Units/volume] in Aspirate | 0.879 |  |
| 3030104 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (Schwartz) | 0.879 |  |
| 3017044 | Thyrotropin receptor Ab [Units/volume] in Serum | 0.879 |  |
| 3038830 | Creatinine [Moles/volume] in Urine --baseline | 0.878 |  |
| 3027700 | Thyrotropin [Units/volume] in Serum or Plasma --baseline | 0.878 |  |
| 3016782 | Immunoelectrophoresis panel - Serum | 0.878 |  |
| 40757587 | Urea reduction ratio in Serum or Plasma | 0.878 |  |
| 3004588 | Protein electrophoresis panel - Serum or Plasma | 0.878 |  |
| 40758648 | Testosterone [Moles/volume] in Serum or Plasma --baseline | 0.877 |  |
| 3020630 | Protein [Mass/volume] in Serum or Plasma | 0.877 | 22 |
| 3008832 | Norclozapine [Moles/volume] in Serum or Plasma | 0.877 |  |
| 42529255 | Triiodothyronine (T3) Free [Moles/volume] in Serum or Plasma by Immunoassay | 0.876 |  |
| 1175777 | Alpha-1-Fetoprotein Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.876 |  |
| 36305217 | Fungus identified in Pleural fluid by Culture | 0.876 |  |
| 3035161 | Testosterone [Moles/volume] in Urine | 0.876 |  |
| 40762331 | Testosterone [Moles/volume] in Body fluid | 0.876 |  |
| 3039783 | Alpha-1-fetoprotein.tumor marker [Mass/volume] in Serum or Plasma | 0.875 | 746 |
| 3045584 | IgA.monoclonal [Presence] in Serum by Immunofixation | 0.875 |  |
| 3005433 | Fungus identified in Nail by Culture | 0.874 |  |
| 3039522 | Prealbumin [Mass/volume] in Urine | 0.873 |  |
| 3018810 | IgG.monoclonal [Mass/volume] in Serum | 0.873 |  |
| 3040495 | Creatinine [Moles/volume] in Serum or Plasma --pre dialysis | 0.873 |  |
| 3003714 | Bacteria identified in Wound by Culture | 0.873 | 270 |
| 40759045 | IgM.monoclonal [Presence] in Serum by Immunoelectrophoresis | 0.871 |  |
| 42529190 | Alpha-1-Fetoprotein [Mass/volume] in Serum or Plasma by Immunoassay | 0.871 |  |
| 36303914 | Fungus identified in Bronchoalveolar lavage by Culture | 0.870 |  |
| 1091125 | Protein.monoclonal [Mass/volume] in Serum or Plasma | 0.870 |  |
| 3043203 | Urea [Moles/volume] in Dialysis fluid | 0.869 |  |
| 3048863 | Creatine kinase.MB/Creatine kinase.total [Ratio] in Serum or Plasma | 0.869 | 211 |
| 1617106 | Alpha-1-Fetoprotein [Mass/volume] in Aspirate | 0.869 |  |
| 1616911 | Urea [Moles/volume] in Dialysis fluid --1 hour specimen | 0.868 |  |
| 3966536 | Testosterone Free [Mass/volume] in Serum or Plasma by Calculation | 0.867 |  |
| 3028331 | Alpha-1-Fetoprotein [Units/volume] in Pleural fluid | 0.867 |  |
| 1091932 | Fungus identified in Throat by Culture | 0.867 |  |
| 3042803 | Cryoglobulin Rheumatoid Factor [Units/volume] in Serum | 0.866 |  |
| 42529563 | Testosterone [Moles/volume] in Serum or Plasma by Immunoassay | 0.866 |  |
| 3966641 | Thyroxine.free.gestational [Moles/volume] in Serum or Plasma by Immunoassay | 0.865 |  |
| 3050748 | Urea nitrogen [Mass/volume] in Venous blood --post dialysis | 0.865 |  |
| 3000494 | Fungus identified in Specimen by Culture | 0.864 | 328 |
| 3965919 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine, Cystatin C and Urea-based formula (CKiD) | 0.864 |  |
| 3038887 | Thyroglobulin [Mass/volume] in Tissue fine needle aspirate | 0.864 |  |
| 3004290 | Testosterone [Moles/volume] in Semen | 0.864 |  |
| 42529191 | Alpha-1-Fetoprotein [Units/volume] in Amniotic fluid by Immunoassay | 0.864 |  |
| 3030170 | Creatine kinase [Mass/volume] in Blood | 0.864 |  |
| 3009171 | Fungus identified in Blood by Culture | 0.863 | 1476 |
| 3044105 | Urea [Moles/volume] in Dialysis fluid --2 hour specimen | 0.863 |  |
| 3029859 | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum, Plasma or Blood by Cystatin C-based formula | 0.863 |  |
| 3036566 | Thyroxine binding globulin [Moles/volume] in Serum or Plasma | 0.862 |  |
| 3027828 | Triiodothyronine (T3).reverse [Moles/volume] in Serum or Plasma | 0.862 | 1057 |
| 3019025 | Thyrotropin.long acting [Units/volume] in Serum or Plasma | 0.862 |  |
| 1091523 | IgM.kappa [Presence] in Serum by Immunofixation | 0.861 |  |
| 42869913 | Glomerular filtration rate/1.73 sq M.predicted among males [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (MDRD) | 0.861 |  |
| 3024641 | Urea nitrogen [Moles/volume] in Serum or Plasma | 0.861 |  |
| 3002590 | Prealbumin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.859 |  |
| 3053158 | Urea [Moles/volume] in Dialysis fluid --overnight | 0.859 |  |
| 3016991 | Thyroxine (T4) [Mass/volume] in Serum or Plasma | 0.859 |  |
| 3049187 | Glomerular filtration rate/1.73 sq M.predicted among non-blacks [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (MDRD) | 0.859 | 29 |
| 46235781 | Urea [Moles/volume] in Serum, Plasma or Blood | 0.859 |  |
| 3019359 | Fungus identified in Hair by Culture | 0.858 |  |
| 36305551 | Protein electrophoresis panel - Body fluid | 0.858 |  |
| 3021607 | Alpha-1-Fetoprotein [Moles/volume] in Serum or Plasma | 0.858 |  |
| 36303797 | Glomerular filtration rate/1.73 sq M.predicted among non-blacks [Volume Rate/Area] in Serum, Plasma or Blood by Creatinine-based formula (CKD-EPI) | 0.857 |  |
| 3000372 | Fungus identified in Isolate by Culture | 0.856 |  |
| 3002960 | cloZAPine+Norclozapine [Moles/volume] in Serum or Plasma | 0.856 |  |
| 3042592 | Urea [Moles/volume] in 24 hour Dialysis fluid | 0.856 |  |
| 3030188 | Thyrotropin [Units/volume] in Serum or Plasma --7th specimen | 0.856 |  |
| 40759042 | IgG.monoclonal [Presence] in Serum by Immunoelectrophoresis | 0.856 |  |
| 3030198 | Thyrotropin [Units/volume] in Serum or Plasma --5th specimen | 0.855 |  |
| 40757479 | Alpha-1-Fetoprotein [Mass/volume] in Cord blood | 0.855 |  |
| 3029985 | Thyrotropin [Units/volume] in Serum or Plasma --1st specimen | 0.855 |  |
| 647466 | Prealbumin [Measurement] in Serum or Plasma | 0.855 |  |
| 3029791 | Prealbumin [Mass/volume] in Cord blood | 0.855 |  |
| 40763353 | cloZAPine [Moles/volume] in Specimen | 0.855 |  |
| 3047203 | Thyrotropin [Units/volume] in Serum or Plasma --1 hour post dose TRH | 0.854 |  |
| 3032506 | Alpha-1-Fetoprotein [Mass/volume] in Peritoneal fluid | 0.853 |  |
| 3000186 | Fungus identified in Aspirate by Culture | 0.852 |  |
| 3016857 | Urea nitrogen [Mass/volume] in Arterial blood --post dialysis | 0.852 |  |
| 1091526 | Gamma globulin [Mass/volume] in Serum or Plasma | 0.852 |  |
| 3020924 | Thyroxine binding globulin [Mass/volume] in Serum or Plasma | 0.852 |  |
| 3013751 | cloZAPine [Mass/volume] in Serum or Plasma | 0.851 |  |
| 3005427 | IgD [Presence] in Serum by Immunofixation | 0.850 |  |
| 40761932 | Thyroxine (T4) free [Mass/volume] in Serum or Plasma --baseline | 0.850 |  |
| 1091565 | IgM.lambda [Presence] in Serum by Immunofixation | 0.850 |  |
| 42529254 | Triiodothyronine (T3) [Moles/volume] in Serum or Plasma by Immunoassay | 0.849 |  |
| 3016049 | Testosterone Free [Mass/volume] in Serum or Plasma | 0.847 |  |
| 3034495 | Urea nitrogen [Mass/volume] in Venous blood --pre dialysis | 0.847 |  |
| 3010340 | Triiodothyronine (T3) [Mass/volume] in Serum or Plasma | 0.844 |  |
| 3045286 | Beta globulin+Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.844 |  |
| 42529231 | Thyroxine (T4) [Moles/volume] in Serum or Plasma by Immunoassay | 0.843 |  |
| 1091804 | Beta globulin [Mass/volume] in Serum or Plasma | 0.843 |  |
| 3038571 | Testosterone.free+weakly bound [Moles/volume] in Serum or Plasma | 0.841 |  |
| 36306097 | Fungus identified in Burn by Culture | 0.841 |  |
| 3006066 | IgA.monoclonal [Mass/volume] in Serum | 0.841 |  |
| 3008893 | Testosterone [Mass/volume] in Serum or Plasma | 0.840 |  |
| 3044688 | Urea [Moles/volume] in Dialysis fluid --4 hour specimen | 0.840 |  |
| 21494890 | Protein electrophoresis panel - 24 hour Urine | 0.838 |  |
| 36203341 | clozapine N-oxide [Mass/volume] in Serum or Plasma | 0.836 |  |
| 40759754 | Thyroglobulin IgG Ab [Units/volume] in Serum | 0.835 |  |
| 3025547 | Thyroglobulin Ab [Units/volume] in Serum or Plasma | 0.834 | 416 |
| 647113 | Triiodothyronine (T3) Free [Measurement] in Serum or Plasma | 0.832 |  |
| 3048248 | Gamma 2 globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.832 |  |
| 36031650 | Thyroglobulin [Mass/volume] in Serum or Plasma by Immunoassay --post thyroglobulin antibody neutralization | 0.831 |  |
| 3029389 | cloZAPine [Moles/volume] in Urine | 0.831 |  |
| 40761934 | Triiodothyronine (T3) Free [Mass/volume] in Serum or Plasma --baseline | 0.829 |  |
| 3037704 | Thyroxine binding globulin [Mass/volume] in Blood | 0.829 |  |
| 3010568 | Globulin [Mass/volume] in Plasma | 0.828 |  |
| 648243 | Thyroglobulin Ab [Measurement] in Serum | 0.827 |  |
| 3004268 | Protein electrophoresis panel - Cerebral spinal fluid | 0.824 |  |
| 3012984 | Norclozapine [Mass/volume] in Serum or Plasma | 0.823 |  |
| 3024561 | Albumin [Mass/volume] in Serum or Plasma | 0.822 | 20 |
| 3023465 | Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.822 | 323 |
| 3046299 | Protein.monoclonal [Mass/volume] in Serum or Plasma by Electrophoresis | 0.821 | 482 |
| 648106 | Testosterone Free [Measurement] in Serum or Plasma | 0.820 |  |
| 3052928 | Testosterone [Moles/volume] in Saliva (oral fluid) | 0.820 |  |
| 42868713 | Testosterone [Moles/volume] in Serum or Plasma by Detection limit <= 3.47 pmol/L | 0.819 | 1740 |
| 1469680 | Protein [Mass/volume] in Blood | 0.819 |  |
| 3000310 | cloZAPine+Norclozapine [Mass/volume] in Serum or Plasma | 0.818 |  |
| 3016365 | IgD.monoclonal [Mass/volume] in Serum | 0.816 |  |
| 40762310 | Testosterone [Moles/volume] in Pleural fluid | 0.815 |  |
| 3030802 | Norclozapine [Moles/volume] in Urine | 0.814 |  |
| 3036664 | Testosterone Free [Moles/volume] in Serum or Plasma by Radioimmunoassay (RIA) | 0.814 | 1710 |
| 3006210 | Bacteria identified in Milk by Aerobe culture | 0.813 |  |
| 3016363 | Thyroxine (T4) free [Units/volume] in Serum or Plasma --baseline | 0.813 |  |
| 3016520 | Beta globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.813 | 314 |
| 3046681 | Beta 2 globulin+Gamma globulin [Mass/volume] in Serum or Plasma by Electrophoresis | 0.809 |  |
| 3040542 | Beta globulin+Gamma globulin [Mass/volume] in Body fluid by Electrophoresis | 0.806 |  |
| 3036416 | Protein.monoclonal [Mass/volume] in Urine | 0.804 |  |
| 3037883 | Thyroxine (T4).albumin bound [Mass/volume] in Serum or Plasma | 0.804 |  |
| 3040680 | Triiodothyronine (T3) Free [Moles/volume] in Serum or Plasma --pre dose triple bolus | 0.802 |  |
| 3035472 | Albumin/Protein.total in Serum or Plasma | 0.802 |  |
| 3027984 | Protein [Mass/volume] in Specimen | 0.800 |  |
| 3040509 | Prealbumin [Mass/time] in 24 hour Urine | 0.798 |  |
| 3027401 | Testosterone Free/Testosterone.total in Serum or Plasma | 0.798 | 707 |
| 3008366 | Immunoelectrophoresis panel - Urine | 0.798 |  |
| 1092223 | Testosterone [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.794 |  |
| 3039818 | Protein.monoclonal [Mass/volume] in Urine by Electrophoresis | 0.791 |  |
| 42868714 | Testosterone Free [Moles/volume] in Serum or Plasma by Detection limit <= 3.47 pmol/L | 0.787 | 1753 |
| 3005029 | Protein [Mass/volume] in Body fluid | 0.786 | 704 |
| 3011901 | Tau protein [Mass/volume] in Serum | 0.785 |  |
| 3015055 | Bacteria identified in Amniotic fluid by Culture | 0.782 |  |
| 3004185 | IgE.monoclonal [Mass/volume] in Serum | 0.782 |  |
| 3029713 | Protein.monoclonal band 1 [Mass/volume] in Serum or Plasma by Electrophoresis | 0.780 |  |
| 3031190 | Immunoelectrophoresis panel - 24 hour Urine | 0.780 |  |
| 36305541 | Fungus identified in Mouth by Culture | 0.778 |  |
| 3019415 | Bacteria identified in Food by Culture | 0.778 |  |
| 3023368 | Bacteria identified in Blood by Culture | 0.775 | 131 |
| 3025941 | Bacteria identified in Stool by Culture | 0.773 | 469 |
| 1469798 | Fungus identified in Vaginal fluid by Culture | 0.773 |  |
| 3002619 | Bacteria identified in Specimen by Culture | 0.769 | 39 |
| 3038590 | Bacteria identified in Semen by Culture | 0.767 |  |
| 37020517 | Yeast identified in Upper respiratory specimen by Organism specific culture | 0.766 |  |
| 43533982 | Bacteria identified in Mouth by Culture | 0.765 |  |
| 3016727 | Bacteria identified in Body fluid by Culture | 0.760 | 1786 |
| 3037121 | Protein [Mass/volume] in Urine | 0.758 | 292 |
| 43055432 | Albumin/Protein.total [Pure mass fraction] in Serum or Plasma by Electrophoresis | 0.757 |  |
| 1470012 | Fungus identified in Urethra by Culture | 0.757 |  |
| 46235791 | Protein electrophoresis panel in Urine collected for unspecified duration | 0.754 |  |
| 1091634 | Fungus [Presence] in Specimen | 0.752 |  |
| 46235752 | Fungus identified in Nose by Culture | 0.751 |  |
| 1469478 | Fungus identified in Semen by Culture | 0.747 |  |
| 3038276 | Urea/Creatinine [Ratio] in Urine | 0.731 |  |
| 36659777 | Mycobacterial stain and culture panel - Specimen | 0.726 |  |
| 3033427 | Fungus identified in Specimen | 0.726 |  |
| 1617564 | Fungal Ab panel - Specimen by Complement fixation | 0.725 |  |
| 1761571 | Yeast and Candida sp identification panel - Specimen by Organism specific culture | 0.717 |  |
| 1616972 | Fungal Ab panel - Specimen by Immune diffusion (ID) | 0.714 |  |
| 36031450 | Fungal pathogens panel - Tissue by NAA with probe detection | 0.709 |  |
| 40762142 | Coccidioides sp IgG and IgM panel - Specimen | 0.707 |  |
| 36031894 | Fungal pathogens panel - Lower respiratory specimen by NAA with probe detection | 0.704 |  |
| 40759267 | Fungal Ab panel - Serum | 0.698 |  |
| 3044148 | Urea nitrogen/Creatinine [Mass Ratio] in Urine | 0.693 |  |
| 3018311 | Urea nitrogen/Creatinine [Mass Ratio] in Serum or Plasma | 0.690 | 55 |
| 40760116 | Urea/Creatinine [Mass Ratio] in Serum or Plasma | 0.684 |  |
| 3040431 | Urea/Creatinine [Molar ratio] in Serum or Plasma | 0.682 |  |
| 1617497 | Urea/Creatinine [Mass Ratio] in Urine | 0.679 |  |
| 3046485 | Urea nitrogen/Creatinine [Mass Ratio] in Blood | 0.677 |  |
| 3014788 | Urea nitrogen/Creatinine [Mass Ratio] in 24 hour Urine | 0.676 |  |
| 40762847 | Urea/Creatinine [Molar ratio] in Urine | 0.676 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2522 | -dialyysinjälkeen,p-urea | mmol/l | 100% | name+unit+values | 180 | 0 | [3, 3.68, 4.18, 4.49, 4.93, 5.5, 6.21, 6.87, 8.12] |  |  |  | Urea [Moles/volume] in Plasma --post dialysis |
| 2523 | -ennendialyysiä,p-urea | mmol/l | 100% | name+unit+values | 210 | 0 | [12.2, 14.25, 15.96, 17.24, 18.13, 19.3, 20.55, 22.38, 25.16] |  |  |  | Urea [Moles/volume] in Plasma --pre dialysis |
| 2524 | alfa-1-fetoproteiini,seerumista | u/ml | 74% | name+unit | 105 | 0 |  |  |  |  | Alpha fetoprotein [Units/volume] in Serum |
| 2525 | alfa-1-fetoproteiini,seerumista |  | 26% | name | 37 | 100 |  |  |  |  | Alpha fetoprotein [Mass/volume] in Serum |
| 2526 | dialyysiaedeltäväp-urea | mmol/l | 97% | name+unit | 745 | 0 |  |  |  |  | Urea [Moles/volume] in Plasma --pre dialysis |
| 2527 | dialyysiaedeltäväp-urea |  | 3% | name | 22 | 100 |  |  |  |  | Urea [Moles/volume] in Plasma --pre dialysis |
| 2528 | dialyysinjälkeinenp-urea | mmol/l | 95% | name+unit | 708 | 0 |  |  |  |  | Urea [Moles/volume] in Plasma --post dialysis |
| 2529 | dialyysinjälkeinenp-urea |  | 5% | name | 38 | 100 |  |  |  |  | Urea [Moles/volume] in Plasma --post dialysis |
| 2530 | dialyysinriittävyydensuhdeluku␤ |  | 100% | name | 117 | 100 |  |  |  |  | Urea reduction ratio [Ratio] |
| 2531 | ex-sieni,viljely,yskös |  | 100% | name | 387 | 100 |  |  | Expectorate (sputum) |  | Fungus identified in Sputum by Culture |
| 2532 | gamma-fraktio,seerumista␤ | g/l | 100% | name+unit+values | 715 | 0 | [3.62, 4.97, 6.21, 7.31, 8.18, 9.2, 10.45, 13.45, 22.31] |  |  |  | Protein.gamma globulin [Mass/volume] in Serum |
| 2533 | hiiva,viljely,limakalvo␤ |  | 100% | name | 132 | 100 |  |  |  |  | Yeast identified in Mucous membrane by Culture |
| 2534 | immunofiksaatio,seerumista |  | 100% | name | 144 | 100 |  |  |  |  | Monoclonal protein [Presence] in Serum by Immunofixation |
| 2535 | klotsapiini,seerumi | nmol/l | 96% | name+unit+values | 1152 | 0 | [634.32, 1045.65, 1268.58, 1440.03, 1585.57, 1750.83, 1951.06, 2171.02, 2657.43] |  |  |  | Clozapine [Moles/volume] in Serum |
| 2536 | klotsapiini,seerumi |  | 4% | name | 54 | 100 |  |  |  |  | Clozapine [Moles/volume] in Serum |
| 2537 | klotsapiini,seerumista␤ |  | 100% | name | 365 | 100 |  |  |  |  | Clozapine [Moles/volume] in Serum |
| 2538 | kreatiinikinaasi,mb-alayksikkö | ug/l | 100% | name+unit+values | 382 | 0 | [1.39, 1.78, 2.02, 2.34, 2.67, 2.98, 3.56, 4.2, 6.94] |  |  |  | Creatine kinase.MB [Mass/volume] in Serum or Plasma |
| 2539 | kreatiniini(4600p-krea) | umol/l | 100% | name+unit+values | 2046 | 0 | [58.69, 64.03, 68.26, 71.62, 75.78, 79.76, 84.39, 89.68, 98.13] |  |  |  | Creatinine [Moles/volume] in Plasma |
| 2540 | kreatiniini(krea) | umol/l | 95% | name+unit+values | 1301 | 0 | [59.48, 64.22, 68.11, 71.83, 75.82, 80.59, 84.79, 89.73, 96.23] |  |  |  | Creatinine [Moles/volume] in Serum or Plasma |
| 2541 | kreatiniini(krea) |  | 5% | name | 72 | 100 |  |  |  |  | Creatinine [Moles/volume] in Serum or Plasma |
| 2542 | kreatiniini(p-krea) | umol/l | 99% | name+unit+values | 1817 | 0 | [59.11, 64.24, 67.62, 71.97, 76.07, 80.59, 85.51, 90.87, 98.23] |  |  |  | Creatinine [Moles/volume] in Plasma |
| 2543 | kreatiniini(p-krea) |  | 1% | name | 16 | 100 |  |  |  |  | Creatinine [Moles/volume] in Plasma |
| 2544 | kreatiniini(u-maniposat.) | mmol/l | 97% | name+unit+values | 394 | 0 | [1.61, 2.67, 3.95, 5.52, 7.57, 9.7, 11.69, 14.28, 17.19] |  |  |  | Creatinine [Moles/volume] in Urine |
| 2545 | kreatiniini(u-maniposat.) |  | 3% | name | 13 | 100 |  |  |  |  | Creatinine [Moles/volume] in Urine |
| 2546 | kreatiniini,pika | umol/l | 100% | name+unit+values | 119 | 0 | [30.6, 43.6, 49.8, 57.13, 63.6, 68.54, 76.97, 87.02, 109.95] |  |  |  | Creatinine [Moles/volume] in Serum or Plasma |
| 2547 | kreatiniini,pikatesti | umol/l | 100% | name+unit+values | 649 | 0 | [60.09, 66.57, 72.93, 78.8, 85, 91.65, 100.3, 111.92, 128.95] |  |  |  | Creatinine [Moles/volume] in Serum or Plasma |
| 2548 | kreatiniini,plasma |  | 100% | name | 366 | 100 |  |  |  |  | Creatinine [Moles/volume] in Plasma |
| 2549 | kreatiniini,plasmasta | ml/min/173m2 | 41% | name+unit+values | 84 | 0 | [72, 79, 87.13, 91, 93.5, 99.7, 102.9, 108.05, 114] |  |  |  | Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] |
| 2550 | kreatiniini,plasmasta | umol/l | 49% | name+unit+values | 101 | 0 | [54, 59, 63.15, 67.2, 69.93, 75.22, 80.8, 90.95, 204] |  |  |  | Creatinine [Moles/volume] in Plasma |
| 2551 | kreatiniini,plasmasta |  | 10% | name | 20 | 100 |  |  |  |  | Creatinine [Moles/volume] in Plasma |
| 2552 | m-komponentti-1,seerumista | g/l | 100% | name+unit+values | 666 | 0 | [0, 0, 0, 0, 0, 1.62, 4.88, 8.98, 19.92] |  | Muscle |  | Monoclonal protein [Mass/volume] in Serum |
| 2553 | mm-hygienianäyte,viljely(äidinmaito) |  | 100% | name | 161 | 100 |  |  | Maternal milk |  | Bacteria identified in Breast milk by Culture |
| 2554 | p-kreatiinikinaasi,mb-alayksikkö,massa | ug/l | 84% | name+unit+values | 92 | 0 | [1, 2, 2, 3, 4, 5, 6.7, 10, 19] |  | Plasma |  | Creatine kinase.MB [Mass/volume] in Plasma |
| 2555 | p-kreatiinikinaasi,mb-alayksikkö,massa |  | 16% | name | 17 | 100 |  |  | Plasma |  | Creatine kinase.MB [Mass/volume] in Plasma |
| 2556 | p-kreatiniinitykslab | umol/l | 100% | name+unit+values | 933 | 0 | [55.37, 59.87, 63.05, 65.9, 68.57, 71.68, 75.55, 79.76, 85.87] |  | Plasma |  | Creatinine [Moles/volume] in Plasma |
| 2557 | p-kreatiniinitykslab(osat.) | umol/l | 100% | name+unit+values | 111 | 0 | [54.4, 59.3, 62.6, 65.76, 68.67, 70.63, 74.07, 79.3, 82.97] |  | Plasma |  | Creatinine [Moles/volume] in Plasma |
| 2558 | p-kreatiniinitykslab(sis.gfreepi) | umol/l | 100% | name+unit+values | 476 | 0 | [56.56, 60.35, 62.96, 66.42, 69.21, 72.17, 75.17, 79.22, 85.93] |  | Plasma |  | Creatinine [Moles/volume] in Plasma |
| 2559 | p-reumafaktori,määritys | iu/ml | 33% | name+unit+values | 608 | 0 | [7.09, 10.95, 12, 12.13, 13, 14, 15.89, 21.26, 46.72] |  | Plasma |  | Rheumatoid factor [Units/volume] in Plasma |
| 2560 | p-reumafaktori,määritys |  | 67% | name | 1217 | 100 |  |  | Plasma |  | Rheumatoid factor [Units/volume] in Plasma |
| 2561 | p-reumafaktori,plasmasta | iu/ml | 37% | name+unit+values | 149 | 0 | [5, 5, 6, 7, 8.31, 9.43, 11.6, 20.13, 53.77] |  | Plasma |  | Rheumatoid factor [Units/volume] in Plasma |
| 2562 | p-reumafaktori,plasmasta |  | 63% | name | 253 | 100 |  |  | Plasma |  | Rheumatoid factor [Units/volume] in Plasma |
| 2563 | p-trijodityroniini,vapaa | pmol/l | 100% | name+unit+values | 637 | 0 | [3.6, 3.91, 4.18, 4.36, 4.56, 4.7, 4.89, 5.19, 5.6] |  | Plasma |  | Triiodothyronine.free [Moles/volume] in Plasma |
| 2564 | p-trijodityroniini,vapaa,plasmasta | pmol/l | 100% | name+unit+values | 505 | 0 | [3.85, 4.19, 4.43, 4.63, 4.84, 5.05, 5.3, 5.56, 6.37] |  | Plasma |  | Triiodothyronine.free [Moles/volume] in Plasma |
| 2565 | p-tyroksiini,vapaa | pmol/l | 100% | name+unit+values | 27699 | 0.01 | [12.79, 13.84, 14.5, 15.08, 15.94, 16.5, 17.23, 18.21, 19.81] |  | Plasma |  | Thyroxine.free [Moles/volume] in Plasma |
| 2566 | p-tyroksiini,vapaa |  | 0% | name | 45 | 100 |  |  | Plasma |  | Thyroxine.free [Moles/volume] in Plasma |
| 2567 | p-tyroksiini,vapaa(ko) | pmol/l | 100% | name+unit+values | 214 | 0 | [13, 13, 14, 14.25, 15, 15.69, 16, 17, 18.16] |  | Plasma |  | Thyroxine.free [Moles/volume] in Plasma |
| 2568 | p-tyroksiini,vapaa(pi) | pmol/l | 100% | name+unit+values | 114 | 0 | [8.88, 9.2, 9.77, 10.13, 10.63, 11.11, 11.49, 12.12, 13.33] |  | Plasma |  | Thyroxine.free [Moles/volume] in Plasma |
| 2569 | p-urea,10mindialyysinjälkeen | mmol/l | 100% | name+unit | 136 | 0 |  |  | Plasma |  | Urea [Moles/volume] in Plasma --10 minutes post dialysis |
| 2570 | p-urea,ennendialyysiä | mmol/l | 100% | name+unit | 139 | 0 |  |  | Plasma |  | Urea [Moles/volume] in Plasma --pre dialysis |
| 2571 | prealbumiini,plasma | g/l | 100% | name+unit+values | 103 | 0 | [0.08, 0.1, 0.13, 0.16, 0.19, 0.21, 0.23, 0.24, 0.27] |  |  |  | Prealbumin [Mass/volume] in Plasma |
| 2572 | prealbumiini,seerumista␤ | g/l | 100% | name+unit+values | 147 | 0 | [0.1, 0.13, 0.16, 0.17, 0.19, 0.21, 0.23, 0.25, 0.29] |  |  |  | Prealbumin [Mass/volume] in Serum |
| 2573 | proteiini,fraktiot,seerumi |  | 100% | name | 262 | 100 |  |  |  |  | Protein electrophoresis panel - Serum |
| 2574 | proteiini,fraktiot,seerumista |  | 100% | name | 151 | 100 |  |  |  |  | Protein electrophoresis panel - Serum |
| 2575 | proteiini,fraktiot,seerumista␤ |  | 100% | name | 716 | 100 |  |  |  |  | Protein electrophoresis panel - Serum |
| 2576 | proteiini,ty,seerumista | g/l | 100% | name+unit+values | 663 | 0 | [56.91, 60.48, 62.84, 64.87, 66.98, 68.69, 70.61, 72.85, 80.94] |  |  |  | Protein.total [Mass/volume] in Serum |
| 2577 | reumafaktori,määritys,seerumista | kiu/l | 53% | name+unit+values | 99 | 0 | [4, 5, 5, 6, 7, 8.42, 10.72, 18.75, 43] |  |  |  | Rheumatoid factor [Units/volume] in Serum |
| 2578 | reumafaktori,määritys,seerumista |  | 47% | name | 89 | 100 |  |  |  |  | Rheumatoid factor [Units/volume] in Serum |
| 2579 | reumafaktori,plasmasta | iu/ml | 13% | name+unit | 26 | 0 |  |  |  |  | Rheumatoid factor [Units/volume] in Plasma |
| 2580 | reumafaktori,plasmasta |  | 87% | name | 171 | 100 |  |  |  |  | Rheumatoid factor [Units/volume] in Plasma |
| 2581 | s-proteiini,fraktiot,seerumi |  | 100% | name | 243 | 100 |  |  | Serum |  | Protein electrophoresis panel - Serum |
| 2582 | s-reumafaktori,määritys | iu/ml | 7% | name+unit | 32 | 0 |  |  | Serum |  | Rheumatoid factor [Units/volume] in Serum |
| 2583 | s-reumafaktori,määritys | kiu/l | 38% | name+unit+values | 173 | 0 | [4, 5, 5, 6, 6.34, 7.1, 8.76, 12.32, 25.08] |  | Serum |  | Rheumatoid factor [Units/volume] in Serum |
| 2584 | s-reumafaktori,määritys |  | 55% | name | 253 | 100 |  |  | Serum |  | Rheumatoid factor [Units/volume] in Serum |
| 2585 | s-testo,vap,laskmassasp | pmol/l | 100% | name+unit+values | 192 | 0 | [10.85, 19, 49.35, 138.06, 177.45, 207.93, 238.8, 263.47, 335.81] |  | Serum |  | Testosterone.free.calculated [Moles/volume] in Serum |
| 2586 | s-testosteroni,herkkä | nmol/l | 100% | name+unit+values | 123 | 0 | [0.5, 0.6, 0.74, 0.87, 1, 1.12, 1.3, 1.61, 10.16] |  | Serum |  | Testosterone [Moles/volume] in Serum by Ultrasensitive |
| 2587 | s-testosteroni,seerumista | nmol/l | 79% | name+unit+values | 395 | 0 | [2.6, 5.96, 8.17, 9.83, 11.94, 13.99, 16.59, 19.77, 24.44] |  | Serum |  | Testosterone [Moles/volume] in Serum |
| 2588 | s-testosteroni,seerumista |  | 21% | name | 102 | 100 |  |  | Serum |  | Testosterone [Moles/volume] in Serum |
| 2589 | s-testosteroni,vapaa,laskettu | pmol/l | 97% | name+unit+values | 3226 | 0 | [128.94, 163.03, 185.24, 206.94, 226.3, 246.5, 270.86, 300.89, 362.97] |  | Serum |  | Testosterone.free.calculated [Moles/volume] in Serum |
| 2590 | s-testosteroni,vapaa,laskettu |  | 3% | name | 109 | 100 |  |  | Serum |  | Testosterone.free.calculated [Moles/volume] in Serum |
| 2591 | s-testosteronivapaalaskettu | pmol/l | 100% | name+unit+values | 102 | 0 | [45, 133.8, 156.3, 186.43, 208.5, 230.49, 255, 283.9, 340] |  | Serum |  | Testosterone.free.calculated [Moles/volume] in Serum |
| 2592 | s-testosterooni,vapaa,lask. | pmol/l | 100% | name+unit+values | 112 | 0 | [131, 157.45, 176.5, 192.03, 211.37, 227.05, 249.87, 280.3, 365.2] |  | Serum |  | Testosterone.free.calculated [Moles/volume] in Serum |
| 2593 | s-testostervapaalaske | pmol/l | 100% | name+unit+values | 122 | 0 | [121.65, 153.9, 181.28, 195.2, 232.67, 260.6, 296.27, 367.7, 460.95] |  | Serum |  | Testosterone.free.calculated [Moles/volume] in Serum |
| 2594 | s-tyroksiini,vapaa | pmol/l | 99% | name+unit+values | 655 | 0 | [11.99, 12.87, 13.47, 14.03, 14.59, 15.27, 15.86, 16.79, 18.23] |  | Serum |  | Thyroxine.free [Moles/volume] in Serum |
| 2595 | s-tyroksiini,vapaa |  | 1% | name | 9 | 100 |  |  | Serum |  | Thyroxine.free [Moles/volume] in Serum |
| 2596 | sieni,viljely(syvänäyte) |  | 100% | name | 123 | 100 |  |  |  |  | Fungus identified in Wound by Culture |
| 2597 | sieni,viljelyjanatiivi |  | 100% | name | 169 | 100 |  |  |  |  | Fungus panel - Specimen |
| 2598 | sk-sieni,viljely(pintanäyte) |  | 100% | name | 333 | 100 |  |  | Skin |  | Fungus identified in Skin by Culture |
| 2599 | sk-sieni,viljely(pintasieni) |  | 100% | name | 106 | 100 |  |  | Skin |  | Fungus identified in Skin by Culture |
| 2600 | testosteroni,vapaalask | pmol/l | 99% | name+unit+values | 913 | 0 | [119.73, 156.24, 180.26, 202.32, 224.76, 247.29, 273.77, 325.72, 420.18] |  |  |  | Testosterone.free.calculated [Moles/volume] in Serum or Plasma |
| 2601 | testosteroni,vapaalask |  | 1% | name | 11 | 100 |  |  |  |  | Testosterone.free.calculated [Moles/volume] in Serum or Plasma |
| 2602 | testosteroni,vapaalaskettu | pmol/l | 84% | name+unit+values | 549 | 0 | [113.52, 156.92, 183.94, 206.6, 232.26, 261.25, 292.92, 350.15, 450.68] |  |  |  | Testosterone.free.calculated [Moles/volume] in Serum or Plasma |
| 2603 | testosteroni,vapaalaskettu |  | 16% | name | 103 | 100 |  |  |  |  | Testosterone.free.calculated [Moles/volume] in Serum or Plasma |
| 2604 | trijodityroniini,vapaa | pmol/l | 88% | name+unit+values | 275 | 0 | [3.41, 3.83, 4.1, 4.29, 4.49, 4.7, 4.98, 5.34, 5.71] |  |  |  | Triiodothyronine.free [Moles/volume] in Serum or Plasma |
| 2605 | trijodityroniini,vapaa |  | 12% | name | 38 | 100 |  |  |  |  | Triiodothyronine.free [Moles/volume] in Serum or Plasma |
| 2606 | trijodityroniini,vapaa(t3v) | pmol/l | 98% | name+unit+values | 459 | 0 | [3.8, 4.03, 4.24, 4.4, 4.6, 4.79, 5, 5.33, 5.86] |  |  |  | Triiodothyronine.free [Moles/volume] in Serum or Plasma |
| 2607 | trijodityroniini,vapaa(t3v) |  | 2% | name | 7 | 100 |  |  |  |  | Triiodothyronine.free [Moles/volume] in Serum or Plasma |
| 2608 | tyreoglobuliini,seerumista | ug/l | 46% | name+unit | 65 | 0 |  |  |  |  | Thyroglobulin [Mass/volume] in Serum |
| 2609 | tyreoglobuliini,seerumista |  | 54% | name | 75 | 100 |  |  |  |  | Thyroglobulin [Mass/volume] in Serum |
| 2610 | tyreotropiiniseerumista | mu/l | 100% | name+unit+values | 146 | 0 | [0.58, 0.92, 1.29, 1.57, 2.06, 2.32, 2.77, 3.3, 4.39] |  |  |  | Thyrotropin [Units/volume] in Serum |
| 2611 | tyroksiini,vapaa | pmol/l | 56% | name+unit+values | 808 | 0 | [12.62, 13.73, 14.33, 15, 15.68, 16.27, 17.12, 17.96, 19.14] |  |  |  | Thyroxine.free [Moles/volume] in Serum or Plasma |
| 2612 | tyroksiini,vapaa |  | 44% | name | 628 | 100 |  |  |  |  | Thyroxine.free [Moles/volume] in Serum or Plasma |
| 2613 | tyroksiini,vapaa(t4v) | pmol/l | 94% | name+unit+values | 782 | 0 | [12.85, 13.56, 14.3, 14.95, 15.6, 16.21, 16.98, 18.07, 19.69] |  |  |  | Thyroxine.free [Moles/volume] in Serum or Plasma |
| 2614 | tyroksiini,vapaa(t4v) |  | 6% | name | 49 | 100 |  |  |  |  | Thyroxine.free [Moles/volume] in Serum or Plasma |
| 2615 | tyroksiini,vapaa,plasmasta | pmol/l | 100% | name+unit+values | 153 | 0 | [12.28, 13.47, 13.92, 14.37, 15.17, 15.67, 16.39, 17.5, 18.88] |  |  |  | Thyroxine.free [Moles/volume] in Plasma |
| 2616 | tyroksiini,vapaaseerumista | pmol/l | 100% | name+unit+values | 102 | 0 | [12.7, 14.2, 14.98, 15.63, 16.27, 16.79, 17.48, 18.4, 20.2] |  |  |  | Thyroxine.free [Moles/volume] in Serum |
| 2617 | u-kreatiniinimmol/l(u-albkre) | mmol/l | 99% | name+unit+values | 1616 | 0 | [3.09, 4.12, 5.01, 5.82, 6.75, 7.8, 9.11, 10.7, 13.33] |  | Urine |  | Creatinine [Moles/volume] in Urine |
| 2618 | u-kreatiniinimmol/l(u-albkre) |  | 1% | name | 18 | 100 |  |  | Urine |  | Creatinine [Moles/volume] in Urine |
| 2619 | urea,dialyysinjälkee | mmol/l | 100% | name+unit | 133 | 0 |  |  |  |  | Urea [Moles/volume] in Serum or Plasma --post dialysis |
| 2620 | urea,dialyysinjälkeen,plasmasta␤ | mmol/l | 100% | name+unit | 128 | 0 |  |  |  |  | Urea [Moles/volume] in Plasma --post dialysis |
| 2621 | urea,ennendialyysia,plasmasta␤ | mmol/l | 100% | name+unit | 162 | 0 |  |  |  |  | Urea [Moles/volume] in Plasma --pre dialysis |
| 2622 | urea,ennendialyysiä | mmol/l | 100% | name+unit | 141 | 0 |  |  |  |  | Urea [Moles/volume] in Serum or Plasma --pre dialysis |

