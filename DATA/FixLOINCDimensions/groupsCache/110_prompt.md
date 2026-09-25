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
Here is group 110.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3019724 | CD34 cells [#/volume] in Blood | 0.983 |  |
| 3011412 | CD3 cells [#/volume] in Blood | 0.954 | 427 |
| 3020358 | CD16+CD56+ cells [#/volume] in Blood | 0.945 | 1410 |
| 3012302 | CD16C+CD56+ cells [#/volume] in Blood | 0.939 |  |
| 3010503 | CD19 cells [#/volume] in Blood | 0.939 | 1127 |
| 36303864 | CD3+CD45+ cells [#/volume] in Blood | 0.931 |  |
| 36305673 | CD3-CD45+ cells [#/volume] in Blood | 0.921 |  |
| 3032382 | CD3+TCR alpha beta+ cells [#/volume] in Blood | 0.914 |  |
| 3028167 | CD3+CD4+ (T4 helper) cells [#/volume] in Blood | 0.913 | 515 |
| 3025271 | CD3-CD16+CD56+ (Natural killer) cells [#/volume] in Blood | 0.910 |  |
| 44816730 | CD34 cells [#/volume] in Specimen | 0.907 |  |
| 3045389 | CD34 cells [#/volume] in Blood from Blood product unit | 0.906 |  |
| 40757349 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Blood | 0.905 | 362 |
| 1469655 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bronchoalveolar lavage by Flow cytometry (FC) | 0.905 |  |
| 36304682 | CD19+IgM+ cells [#/volume] in Blood | 0.904 |  |
| 3032842 | CD3+CD16+CD56+ cells [#/volume] in Blood | 0.903 |  |
| 36305810 | CD19+CD27+IgD+IgM+ cells [#/volume] in Blood | 0.901 |  |
| 3019424 | CD4+CD45+ cells [#/volume] in Blood | 0.900 |  |
| 3013936 | CD3+HLA-DR+ cells [#/volume] in Blood | 0.899 |  |
| 36304345 | CD19+21- cells [#/volume] in Blood | 0.899 |  |
| 3029962 | CD19+Lambda+ cells [#/volume] in Blood | 0.896 |  |
| 36303647 | CD19+CD27+IgD-IgM- cells [#/volume] in Blood | 0.896 |  |
| 36305872 | CD19+CD27+IgD-IgM+ cells [#/volume] in Blood | 0.895 |  |
| 40762032 | CD34 cells [#/volume] in Body fluid | 0.894 |  |
| 3029900 | CD19+Kappa+ cells [#/volume] in Blood | 0.892 |  |
| 36303696 | CD19+CD27+ cells [#/volume] in Blood | 0.891 |  |
| 3043219 | CD3 cells/CD4 cells [# Ratio] in Specimen | 0.891 |  |
| 3023256 | CD34 cells/cells in Blood | 0.888 |  |
| 36303232 | CD19+CD38+IgM- cells [#/volume] in Blood | 0.885 |  |
| 3026471 | CD8+CD11b+ cells [#/volume] in Blood | 0.885 |  |
| 21494814 | CD8 cells/Lymphocytes in Specimen | 0.885 |  |
| 3000713 | CD3+IL2R1+ cells [#/volume] in Blood | 0.883 |  |
| 1175635 | Transferrin.carbohydrate deficient.trisialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.882 |  |
| 40762014 | CD4+CD45RO+ cells/CD3+CD4+ (T4 helper) cells [# Ratio] in Blood | 0.879 |  |
| 3035120 | CD16 cells [#/volume] in Blood | 0.878 |  |
| 3026757 | CD56 cells [#/volume] in Blood | 0.877 |  |
| 3034238 | Transferrin.carbohydrate deficient.disialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.877 |  |
| 3018500 | CD3-CD16+ cells [#/volume] in Blood | 0.876 |  |
| 40763883 | CD8-CD57+ cells [#/volume] in Blood | 0.875 |  |
| 3006178 | CD8+CD25+ cells [#/volume] in Blood | 0.875 |  |
| 3016761 | CD8+CD57+ cells [#/volume] in Blood | 0.875 |  |
| 3002234 | CD8+HLA-DR+ cells [#/volume] in Blood | 0.875 |  |
| 36203592 | CD3+CD4+CD45RO+ cells [#/volume] in Blood | 0.874 |  |
| 36032071 | CD34 cells [#] in Blood product unit | 0.871 |  |
| 3020073 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Specimen | 0.871 |  |
| 3019203 | CD3+CD26+ cells [#/volume] in Blood | 0.870 |  |
| 3017295 | CD8+CD38+ cells [#/volume] in Blood | 0.869 |  |
| 3015455 | CD16+CD56+ cells/cells in Blood | 0.869 | 1406 |
| 3003048 | CD16+CD56+ cells [#/volume] in Specimen | 0.869 |  |
| 21494815 | CD4 cells/Lymphocytes in Specimen | 0.869 |  |
| 3019082 | CD3+CD56+ cells [#/volume] in Blood | 0.869 |  |
| 3039219 | CD3-CD56+ cells [#/volume] in Blood | 0.866 |  |
| 3035479 | CD8+CD95+ cells [#/volume] in Blood | 0.865 |  |
| 3024672 | CD33 cells [#/volume] in Blood | 0.863 |  |
| 3046399 | Transferrin.carbohydrate deficient.monosialo/Transferrin.carbohydrate deficient.disialo [Mass Ratio] in Serum or Plasma | 0.862 |  |
| 3036413 | Transferrin.carbohydrate deficient.asialo/Transferrin.carbohydrate deficient.tetrasialo [Mass Ratio] in Serum or Plasma | 0.862 |  |
| 3043266 | Transferrin.carbohydrate deficient.asialo/Transferrin.carbohydrate deficient.disialo [Mass Ratio] in Serum or Plasma | 0.862 |  |
| 36203590 | CD3+CD8+CD45RO+ cells [#/volume] in Blood | 0.861 |  |
| 3034458 | CD4+CD45RA+ cells/CD8 Cells [# Ratio] in Blood | 0.861 |  |
| 3003410 | CD8+CD28+ cells [#/volume] in Blood | 0.860 |  |
| 3026022 | CD4+HLA-DR+ cells [#/volume] in Blood | 0.856 |  |
| 3045776 | CD4+CD45RO+ cells [#/volume] in Blood | 0.856 |  |
| 3001405 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Blood | 0.856 | 441 |
| 3019198 | Lymphocytes [#/volume] in Blood | 0.849 | 70 |
| 3025059 | Transferrin.carbohydrate deficient [Mass/volume] in Serum or Plasma | 0.848 |  |
| 1175426 | CD3 cells/Lymphocytes in Blood | 0.846 |  |
| 3045450 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bronchial specimen | 0.844 |  |
| 3010993 | CD3 cells [#/volume] in Specimen | 0.841 |  |
| 3025183 | CD4+CD25+ cells [#/volume] in Blood | 0.840 |  |
| 3011211 | CD41 cells [#/volume] in Blood | 0.840 |  |
| 3023834 | CD24 cells [#/volume] in Blood | 0.839 |  |
| 37021413 | CD3+CD4+ (T4 helper) cells [#/volume] in Blood by Rapid immunoassay | 0.838 |  |
| 1092118 | CD19 cells/Lymphocytes in Blood | 0.837 |  |
| 3035166 | CD4+CD95+ cells [#/volume] in Blood | 0.837 |  |
| 1470025 | CD3+CD4+ (T4 helper) cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.836 |  |
| 3045740 | CD56 cells/CD38 Cells [# Ratio] in Blood | 0.835 |  |
| 3009722 | CD16C+CD56+ cells/cells in Blood | 0.834 |  |
| 3014859 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Body fluid | 0.831 |  |
| 3001694 | CD3+CD4+ (T4 helper) cells [#/volume] in Specimen | 0.826 | 602 |
| 1091820 | CD3+HLA-DR+ cells/Lymphocytes in Bronchoalveolar lavage | 0.825 |  |
| 3030044 | CD34 cells/100 cells in Blood from Blood product unit | 0.825 |  |
| 3041326 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Tissue | 0.825 |  |
| 3037816 | CD4+CD8+ cells/cells in Blood | 0.819 |  |
| 1470003 | CD3 cells [#/volume] in Hematopoietic progenitor cells from Blood product unit | 0.819 |  |
| 647458 | Viable cells.CD34 [#] in Blood product unit | 0.818 |  |
| 36032412 | CD3 cells [#] in Blood product unit | 0.815 |  |
| 3047843 | CD2+CD3+ cells [#/volume] in Specimen | 0.813 |  |
| 3005268 | Transferrin.carbohydrate deficient [Units/volume] in Serum or Plasma | 0.809 |  |
| 3026696 | CD34 cells/cells in Specimen | 0.809 |  |
| 3049541 | CD25+CD127Low cells/CD4 cells [# Ratio] in Specimen | 0.808 |  |
| 3052708 | Transferrin.carbohydrate deficient/Transferrin.total in Serum or Plasma | 0.806 |  |
| 3046367 | CD3+HLA-DR+ cells [#/volume] in Specimen | 0.804 |  |
| 3014686 | CD3 cells/100 cells in Specimen | 0.803 |  |
| 40763402 | Viable CD34 cells [#/volume] in Body fluid | 0.802 |  |
| 3005533 | CD34+DR+ cells/100 cells in Blood | 0.802 |  |
| 3965484 | CD3 cells [#/volume] in Blood from Donor | 0.802 |  |
| 3047764 | CD33+CD34+ cells/100 cells in Blood | 0.801 |  |
| 1092254 | CD3+CD25+ cells/Lymphocytes in Bronchoalveolar lavage | 0.801 |  |
| 646278 | CD3 cells/Lymphocytes in Specimen by Flow cytometry (FC) | 0.800 |  |
| 1469914 | CD3 cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.799 |  |
| 3011065 | CD19+Lambda+ cells/100 cells in Blood | 0.798 | 1634 |
| 1091665 | Lymphocytes [#/volume] in Specimen | 0.796 |  |
| 46236971 | CD34 dose in hematopoietic progenitor cell transfusion [#/mass] per recipient body mass | 0.796 |  |
| 1469804 | Lymphocytes/Cells in Bronchoalveolar lavage | 0.796 |  |
| 3015209 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Bone marrow | 0.795 |  |
| 3016228 | CD19 cells/100 cells in Blood | 0.795 | 868 |
| 1469794 | CD3+CD8+ (T8 suppressor) cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.793 |  |
| 3027831 | CD3-CD16+CD56+ (Natural killer) cells/100 cells in Blood | 0.790 | 944 |
| 3038211 | CD3+CD8+ (T8 suppressor) cells [#/volume] in Specimen | 0.788 |  |
| 3000739 | CD3+CD4+ (T4 helper) cells/cells in Specimen | 0.788 |  |
| 3003031 | Transferrin.carbohydrate deficient.disialo/Transferrin.total in Serum or Plasma | 0.786 |  |
| 46236877 | CD8+CD3- cells/100 cells in Specimen | 0.786 |  |
| 37020917 | Transferrin.carbohydrate deficient.disialo/Transferrin.total standardized per IFCC-RMP for CDT in Serum or Plasma | 0.785 |  |
| 1616698 | CD3+CD4+ (T4 helper) cells/CD3+CD8+ (T8 suppressor cells) cells [# Ratio] in Lower respiratory specimen by Flow cytometry (FC) | 0.784 |  |
| 40760572 | Activated T cells lymphocytes/100 lymphocytes.small in Bronchoalveolar lavage | 0.767 |  |
| 3022312 | CD3+CD25+ cells [#/volume] in Blood | 0.765 |  |
| 44816733 | CD8+CD57+ cells/cells in Specimen | 0.765 |  |
| 21493667 | Viable CD34 cells/CD34 cells in Hematopoietic progenitor cells from Blood product unit | 0.757 |  |
| 36660486 | Leukocytes [#/volume] in Stem cell product | 0.752 |  |
| 3012292 | CD4+CD29+ cells [#/volume] in Blood | 0.749 |  |
| 3040697 | CD3+CD4+ (T4 helper) cells [#/volume] in Tissue | 0.744 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1469 | b-b-cd19 | e6/l | 20% | name+unit+values | 913 | 0 | [10.41, 31.05, 55.36, 87.14, 120.42, 155.29, 201.58, 263.7, 407.08] |  | Blood |  | CD19+ B-lymphocytes [#/volume] in Blood |
| 1470 | b-b-cd19 | e9/l | 68% | name+unit+values | 3083 | 0 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.29, 0.48] |  | Blood |  | CD19+ B-lymphocytes [#/volume] in Blood |
| 1471 | b-b-cd19 |  | 12% | name+values | 569 | 89.28 | [0, 0, 0, 0.02, 0.06, 0.13, 0.2, 0.31, 0.47] |  | Blood |  | CD19+ B-lymphocytes [#/volume] in Blood |
| 1472 | b-cd16/56 | e6/l | 0% | name+unit | 12 | 0 |  |  | Blood |  | CD16+56+ NK cells [#/volume] in Blood |
| 1473 | b-cd16/56 | e9/l | 96% | name+unit+values | 2606 | 0.65 | [0.06, 0.09, 0.12, 0.15, 0.18, 0.22, 0.26, 0.33, 0.44] |  | Blood |  | CD16+56+ NK cells [#/volume] in Blood |
| 1474 | b-cd16/56 |  | 4% | name | 108 | 84.26 |  |  | Blood |  | CD16+56+ NK cells [#/volume] in Blood |
| 1475 | b-cd16/cd56 | e9/l | 95% | name+unit+values | 263 | 0 | [0.09, 0.12, 0.15, 0.17, 0.21, 0.24, 0.3, 0.36, 0.44] |  | Blood |  | CD16+56+ NK cells [#/volume] in Blood |
| 1476 | b-cd16/cd56 |  | 5% | name | 15 | 100 |  |  | Blood |  | CD16+56+ NK cells [#/volume] in Blood |
| 1477 | b-cd19 | e6/l | 56% | name+unit+values | 3891 | 0 | [0, 1.97, 16.17, 41.05, 70.27, 108.04, 158.42, 221.57, 336.97] |  | Blood |  | CD19+ B-lymphocytes [#/volume] in Blood |
| 1478 | b-cd19 | e9/l | 41% | name+unit+values | 2870 | 0.59 | [0, 0, 0.01, 0.03, 0.06, 0.09, 0.14, 0.19, 0.29] |  | Blood |  | CD19+ B-lymphocytes [#/volume] in Blood |
| 1479 | b-cd19 |  | 3% | name | 175 | 66.29 |  |  | Blood |  | CD19+ B-lymphocytes [#/volume] in Blood |
| 1480 | b-cd3 | e6/l | 56% | name+unit | 3892 | 0 |  |  | Blood |  | CD3+ T-lymphocytes [#/volume] in Blood |
| 1481 | b-cd3 | e9/l | 41% | name+unit | 2868 | 0.59 |  |  | Blood |  | CD3+ T-lymphocytes [#/volume] in Blood |
| 1482 | b-cd3 |  | 3% | name | 204 | 71.57 |  |  | Blood |  | CD3+ T-lymphocytes [#/volume] in Blood |
| 1483 | b-cd34 | e6/l | 88% | name+unit+values | 193 | 0 | [5.27, 13.75, 20.31, 28.86, 37.69, 50.47, 63.07, 93.98, 156.93] |  | Blood |  | CD34+ cells [#/volume] in Blood |
| 1484 | b-cd34 |  | 12% | name | 27 | 29.63 |  |  | Blood |  | CD34+ cells [#/volume] in Blood |
| 1485 | b-cd4 | e6/l | 56% | name+unit+values | 3893 | 0 | [134.07, 213.38, 284.14, 381.8, 505.45, 647.7, 819.98, 1038.04, 1335.05] |  | Blood |  | CD4+ T-lymphocytes [#/volume] in Blood |
| 1486 | b-cd4 | e9/l | 41% | name+unit+values | 2870 | 0.59 | [0.14, 0.2, 0.25, 0.32, 0.4, 0.51, 0.63, 0.8, 1.07] |  | Blood |  | CD4+ T-lymphocytes [#/volume] in Blood |
| 1487 | b-cd4 |  | 2% | name | 172 | 66.28 |  |  | Blood |  | CD4+ T-lymphocytes [#/volume] in Blood |
| 1488 | b-cd8 | e6/l | 56% | name+unit+values | 3892 | 0 | [117.75, 200.41, 277.17, 351.98, 433.16, 541.85, 672.5, 850.74, 1214.03] |  | Blood |  | CD8+ T-lymphocytes [#/volume] in Blood |
| 1489 | b-cd8 | e9/l | 41% | name+unit+values | 2870 | 0.59 | [0.11, 0.16, 0.23, 0.29, 0.36, 0.46, 0.57, 0.73, 1] |  | Blood |  | CD8+ T-lymphocytes [#/volume] in Blood |
| 1490 | b-cd8 |  | 2% | name | 172 | 66.28 |  |  | Blood |  | CD8+ T-lymphocytes [#/volume] in Blood |
| 1491 | b-lcd34 | e6/l | 32% | name+unit+values | 251 | 0 | [3, 7.11, 11.11, 14.14, 17.55, 23.82, 31.86, 44, 64.2] | B -Leukosyytit, CD34 alaluokka | Blood |  | CD34+ cells [#/volume] in Blood |
| 1492 | b-lcd34 | e9/l | 60% | name+unit+values | 475 | 0 | [0, 0.01, 0.02, 0.03, 0.03, 0.04, 0.06, 0.09, 0.13] | B -Leukosyytit, CD34 alaluokka | Blood |  | CD34+ cells [#/volume] in Blood |
| 1493 | b-lcd34 |  | 8% | name | 66 | 100 |  | B -Leukosyytit, CD34 alaluokka | Blood |  | CD34+ cells [#/volume] in Blood |
| 1494 | b-lycd4 |  | 100% | name | 496 | 100 |  | B -Lymfosyytti CD4-alaluokka | Blood |  | CD4+ T-lymphocytes [#/volume] in Blood |
| 1495 | b-t-cd3 | e6/l | 28% | name+unit | 1174 | 0 |  |  | Blood |  | CD3+ T-lymphocytes [#/volume] in Blood |
| 1496 | b-t-cd3 | e9/l | 65% | name+unit | 2692 | 0 |  |  | Blood |  | CD3+ T-lymphocytes [#/volume] in Blood |
| 1497 | b-t-cd3 |  | 7% | name | 304 | 81.91 |  |  | Blood |  | CD3+ T-lymphocytes [#/volume] in Blood |
| 1498 | b-t-cd4 | e6/l | 20% | name+unit+values | 1609 | 0 | [168.06, 247.56, 335.09, 433.05, 551.26, 672.04, 816.88, 957.34, 1254.62] |  | Blood |  | CD4+ T-lymphocytes [#/volume] in Blood |
| 1499 | b-t-cd4 | e9/l | 75% | name+unit+values | 6105 | 0 | [0.16, 0.25, 0.34, 0.43, 0.52, 0.64, 0.79, 0.96, 1.28] |  | Blood |  | CD4+ T-lymphocytes [#/volume] in Blood |
| 1500 | b-t-cd4 |  | 6% | name+values | 475 | 69.89 | [0.2, 0.26, 0.34, 0.42, 0.55, 0.68, 0.8, 0.95, 1.29] |  | Blood |  | CD4+ T-lymphocytes [#/volume] in Blood |
| 1501 | b-t-cd8 | e6/l | 28% | name+unit+values | 1174 | 0 | [141.94, 210.82, 289.62, 366.11, 450.98, 530.13, 639.55, 796.16, 1179.47] |  | Blood |  | CD8+ T-lymphocytes [#/volume] in Blood |
| 1502 | b-t-cd8 | e9/l | 65% | name+unit+values | 2753 | 0 | [0.14, 0.21, 0.27, 0.35, 0.43, 0.52, 0.65, 0.83, 1.1] |  | Blood |  | CD8+ T-lymphocytes [#/volume] in Blood |
| 1503 | b-t-cd8 |  | 7% | name | 311 | 79.42 |  |  | Blood |  | CD8+ T-lymphocytes [#/volume] in Blood |
| 1504 | bl-cd4/cd8 | form | 32% | name+unit | 42 | 100 |  |  | Bronchoalveolar lavage |  | CD4+ T-lymphocytes/CD8+ T-lymphocytes [# Ratio] in Bronchoalveolar lavage |
| 1505 | bl-cd4/cd8 |  | 68% | name | 91 | 100 |  |  | Bronchoalveolar lavage |  | CD4+ T-lymphocytes/CD8+ T-lymphocytes [# Ratio] in Bronchoalveolar lavage |
| 1506 | cd4/cd8 |  | 100% | name+values | 3940 | 0.23 | [0.29, 0.47, 0.68, 0.91, 1.2, 1.57, 1.94, 2.45, 3.26] |  |  |  | CD4+ T-lymphocytes/CD8+ T-lymphocytes [# Ratio] in Blood |
| 1507 | l-cd34 | % | 92% | name+unit+values | 481 | 0 | [0.05, 0.08, 0.1, 0.13, 0.16, 0.2, 0.25, 0.32, 0.61] |  | Leukocyte |  | CD34+ cells/Leukocytes [# Ratio] in Blood |
| 1508 | l-cd34 |  | 8% | name | 41 | 100 |  |  | Leukocyte |  | CD34+ cells/Leukocytes [# Ratio] in Blood |
| 1509 | la-cd34 | e6/kg | 28% | name+unit+values | 156 | 0 | [0.6, 0.9, 1.18, 1.41, 1.69, 2.1, 2.53, 3.4, 4.94] |  |  |  | CD34+ cells [#/Mass] in Apheresis product |
| 1510 | la-cd34 | e9/l | 72% | name+unit+values | 393 | 0 | [0.41, 0.56, 0.72, 0.84, 1.03, 1.27, 1.77, 2.36, 3.2] |  |  |  | CD34+ cells [#/volume] in Apheresis product |
| 1511 | la-cd34-ks |  | 100% | name | 395 | 100 |  |  |  |  | CD34+ cells [#] in Apheresis product |
| 1512 | la-cd34-os | % | 100% | name+unit+values | 393 | 0 | [0.22, 0.3, 0.39, 0.49, 0.59, 0.69, 0.84, 1.12, 1.67] |  |  |  | CD34+ cells/Nucleated cells [# Ratio] in Apheresis product |
| 1513 | la-t-cd3 | e9/l | 96% | name+unit | 149 | 0 |  |  |  |  | CD3+ T-lymphocytes [#/volume] in Apheresis product |
| 1514 | la-t-cd3 |  | 4% | name | 6 | 16.67 |  |  |  |  | CD3+ T-lymphocytes [#/volume] in Apheresis product |
| 1515 | la-t-cd4 | e9/l | 96% | name+unit | 149 | 0 |  |  |  |  | CD4+ T-lymphocytes [#/volume] in Apheresis product |
| 1516 | la-t-cd4 |  | 4% | name | 6 | 16.67 |  |  |  |  | CD4+ T-lymphocytes [#/volume] in Apheresis product |
| 1517 | la-t-cd8 | e9/l | 96% | name+unit | 149 | 0 |  |  |  |  | CD8+ T-lymphocytes [#/volume] in Apheresis product |
| 1518 | la-t-cd8 |  | 4% | name | 6 | 16.67 |  |  |  |  | CD8+ T-lymphocytes [#/volume] in Apheresis product |
| 1519 | ly-b-cd19 | % | 61% | name+unit+values | 1504 | 0 | [0, 0, 0.45, 2.91, 5.54, 7.86, 10.24, 13.34, 18.94] |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1520 | ly-b-cd19 |  | 39% | name | 950 | 99.05 |  |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1521 | ly-cd16/56 | % | 97% | name+unit+values | 3462 | 0.49 | [5.28, 8.01, 10.25, 12.46, 15.08, 18.07, 21.55, 26.37, 33.4] |  | Lymphocyte |  | CD16+56+ NK cells/Lymphocytes [# Ratio] in Blood |
| 1522 | ly-cd16/56 |  | 3% | name | 107 | 86.92 |  |  | Lymphocyte |  | CD16+56+ NK cells/Lymphocytes [# Ratio] in Blood |
| 1523 | ly-cd16/cd56 | % | 95% | name+unit+values | 262 | 0 | [5.52, 8.16, 10.06, 12.71, 14.93, 17.65, 20.63, 27.5, 36.58] |  | Lymphocyte |  | CD16+56+ NK cells/Lymphocytes [# Ratio] in Blood |
| 1524 | ly-cd16/cd56 |  | 5% | name | 15 | 100 |  |  | Lymphocyte |  | CD16+56+ NK cells/Lymphocytes [# Ratio] in Blood |
| 1525 | ly-cd19 | % | 97% | name+unit+values | 3462 | 0.49 | [0, 0, 1.17, 3.24, 5.55, 8.08, 10.86, 14.11, 20.27] |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1526 | ly-cd19 |  | 3% | name | 107 | 85.98 |  |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1527 | ly-cd19-b | % | 99% | name+unit+values | 2507 | 0 | [0, 0, 1, 3.95, 7.56, 10.5, 13.61, 17.58, 25.6] |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1528 | ly-cd19-b |  | 1% | name | 19 | 100 |  |  | Lymphocyte |  | CD19+ B-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1529 | ly-cd3 | % | 97% | name+unit+values | 3726 | 0.46 | [52.12, 61.25, 67.07, 71.15, 74.98, 78.39, 81.66, 85.36, 89.48] |  | Lymphocyte |  | CD3+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1530 | ly-cd3 |  | 3% | name | 122 | 87.7 |  |  | Lymphocyte |  | CD3+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1531 | ly-cd4 | % | 97% | name+unit+values | 3726 | 0.46 | [16.32, 22.56, 27.91, 32.59, 37.02, 41.75, 46.47, 51.76, 58.99] |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1532 | ly-cd4 |  | 3% | name | 122 | 87.7 |  |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1533 | ly-cd4+8+ | % | 35% | name+unit | 41 | 41.46 |  |  | Lymphocyte |  | CD4+CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1534 | ly-cd4+8+ |  | 65% | name | 75 | 100 |  |  | Lymphocyte |  | CD4+CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1535 | ly-cd4-8- | % | 73% | name+unit+values | 207 | 8.21 | [7, 8, 8, 8.88, 9.82, 10.9, 12, 14, 16] |  | Lymphocyte |  | CD4-CD8- cells/Lymphocytes [# Ratio] in Blood |
| 1536 | ly-cd4-8- |  | 27% | name | 77 | 100 |  |  | Lymphocyte |  | CD4-CD8- cells/Lymphocytes [# Ratio] in Blood |
| 1537 | ly-cd4-t | % | 96% | name+unit+values | 4576 | 0 | [15.23, 21.8, 27.31, 31.42, 35.47, 39.26, 43.26, 48.23, 54.7] |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1538 | ly-cd4-t |  | 4% | name+values | 170 | 22.94 | [17.53, 21.58, 24.78, 29.15, 33.2, 38.25, 41.67, 47.37, 52.57] |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1539 | ly-cd4/cd8 |  | 100% | name+values | 2752 | 4.18 | [0.37, 0.55, 0.75, 0.96, 1.18, 1.48, 1.83, 2.29, 3.23] | Ly-Auttaja- ja tappajasolujen suhde, immunofenotyypitys | Lymphocyte |  | CD4+ T-lymphocytes/CD8+ T-lymphocytes [# Ratio] in Blood |
| 1540 | ly-cd4/cd8suhde |  | 100% | name+values | 278 | 5.4 | [0.5, 0.76, 1.02, 1.29, 1.66, 1.95, 2.26, 2.73, 3.97] |  | Lymphocyte |  | CD4+ T-lymphocytes/CD8+ T-lymphocytes [# Ratio] in Blood |
| 1541 | ly-cd8 | % | 97% | name+unit+values | 3725 | 0.46 | [14.46, 19.13, 22.75, 26.46, 30.35, 34.98, 40.06, 46.74, 56.02] |  | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1542 | ly-cd8 |  | 3% | name | 122 | 87.7 |  |  | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1543 | ly-t-cd3 | % | 94% | name+unit+values | 3926 | 0 | [56.23, 64.92, 70.33, 74.35, 77.57, 80.54, 84.02, 87.72, 92.04] |  | Lymphocyte |  | CD3+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1544 | ly-t-cd3 |  | 6% | name | 264 | 98.48 |  |  | Lymphocyte |  | CD3+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1545 | ly-t-cd4 | % | 34% | name+unit+values | 2006 | 0 | [18.72, 24.57, 29.84, 34.47, 38.67, 43.22, 47.75, 52.18, 58.04] | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1546 | ly-t-cd4 |  | 66% | name | 3875 | 99.92 |  | Ly-Lymfosyytit, T-auttajasolujen osuus | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1547 | ly-t-cd4. | % | 98% | name+unit+values | 1462 | 0 | [18.57, 26.32, 32.42, 36.77, 41.27, 46.47, 51.47, 56.35, 63.05] |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1548 | ly-t-cd4. |  | 2% | name | 36 | 72.22 |  |  | Lymphocyte |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1549 | ly-t-cd4/8 | ratio | 89% | name+unit+values | 1816 | 0 | [0.6, 0.8, 0.99, 1.23, 1.56, 1.85, 2.06, 2.47, 3.19] |  | Lymphocyte |  | CD4+ T-lymphocytes/CD8+ T-lymphocytes [# Ratio] in Blood |
| 1550 | ly-t-cd4/8 |  | 11% | name+values | 224 | 100 | [0.48, 0.79, 1.06, 1.31, 1.55, 1.83, 2.13, 2.62, 3.69] |  | Lymphocyte |  | CD4+ T-lymphocytes/CD8+ T-lymphocytes [# Ratio] in Blood |
| 1551 | ly-t-cd8 | % | 92% | name+unit+values | 2895 | 0 | [14.95, 19.45, 23.24, 27.01, 30.29, 33.79, 38.05, 43.59, 52.29] | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1552 | ly-t-cd8 |  | 8% | name | 245 | 99.59 |  | Ly-Lymfosyytit, T-estäjäsolujen osuus | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1553 | ly-tcd4/8. |  | 100% | name+values | 2179 | 0.83 | [0.48, 0.75, 1, 1.21, 1.42, 1.69, 2, 2.51, 3.27] |  | Lymphocyte |  | CD4+ T-lymphocytes/CD8+ T-lymphocytes [# Ratio] in Blood |
| 1554 | ly-tt-cd8 | % | 100% | name+unit+values | 1219 | 0 | [13.33, 17.86, 21.01, 24.35, 28, 31.32, 36.22, 42.56, 52.88] |  | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1555 | ly-tt-cd8 |  | 0% | name | 5 | 40 |  |  | Lymphocyte |  | CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Blood |
| 1556 | s-gt-cdt | % | 0% | name+unit | 13 | 0 |  |  | Serum |  | Carbohydrate deficient transferrin/Transferrin [Mass Ratio] in Serum |
| 1557 | s-gt-cdt |  | 100% | name+values | 2807 | 3.35 | [2.6, 2.87, 3.04, 3.25, 3.47, 3.7, 3.96, 4.27, 4.86] |  | Serum |  | Carbohydrate deficient transferrin/Transferrin [Mass Ratio] in Serum |
| 1558 | so-t-cd3 | % | 96% | name+unit+values | 149 | 0 | [16.66, 19.73, 21.87, 23.49, 24.84, 27.82, 29.85, 33.41, 49.51] |  |  |  | CD3+ T-lymphocytes/Lymphocytes [# Ratio] in Specimen |
| 1559 | so-t-cd3 |  | 4% | name | 6 | 16.67 |  |  |  |  | CD3+ T-lymphocytes/Lymphocytes [# Ratio] in Specimen |
| 1560 | so-t-cd4 | % | 96% | name+unit+values | 149 | 0 | [9.42, 10.93, 12.3, 13.53, 14.67, 15.99, 17.4, 19.67, 23.42] |  |  |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Specimen |
| 1561 | so-t-cd4 |  | 4% | name | 6 | 16.67 |  |  |  |  | CD4+ T-lymphocytes/Lymphocytes [# Ratio] in Specimen |
| 1562 | so-t-cd8 | % | 96% | name+unit+values | 149 | 0 | [5.87, 7, 7.83, 8.57, 9.8, 10.57, 12.18, 14.02, 21.4] |  |  |  | CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Specimen |
| 1563 | so-t-cd8 |  | 4% | name | 6 | 16.67 |  |  |  |  | CD8+ T-lymphocytes/Lymphocytes [# Ratio] in Specimen |

